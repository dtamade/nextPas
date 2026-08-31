program test_ssh_session_async;

{$I nextpas.core.settings.inc}

{ S16.5 gate: async session via TAsyncLoop + real TCP loopback.
  Reuses nextpas.core.bytes.ops,
  crypto primitives, runs TSshLoopServer on blocking ITcpStream
  in a server thread, client via SshAsyncConnect/ExecAsync on TAsyncLoop.
  Covers password/compress/dh + keepalive. Heaptrc 0 via named TThread. }

uses
  cthreads,
  Classes, SysUtils,
  nextpas.core.system.sysutils,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.tcp,
  nextpas.core.async.loop,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.auth,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.session,
  nextpas.core.ssh.session.async,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.random,
  nextpas.core.ssh.kex.dhgroup14,
  nextpas.core.ssh.compress,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.test;

function StringToBytes(const AText: string): TBytes;
begin
  Result:=nil;
  SetLength(Result, Length(AText));
  if Length(AText)>0 then Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesToText(const AData: TBytes): string;
begin
  Result:='';
  SetLength(Result, Length(AData));
  if Length(AData)>0 then Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData)));
end;

function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result:=nil;
  SetLength(Result, ACount);
  if ACount>0 then FillChar(Result[0], SizeUInt(ACount), APattern);
end;

function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes;
var LW: TsshWriter;
begin
  Result:=nil;
  LW:=TsshWriter.Create(128);
  try LW.PutStringText(AAlgName); LW.PutStringBytes(ARawSig); Result:=LW.ToBytes; finally LW.Free; end;
end;

function SingleBytePayloadOf(AMsg: Byte): TBytes;
begin
  Result:=nil; SetLength(Result,1); Result[0]:=AMsg;
end;

function Ed25519PubBlob(const APub: TBytes): TBytes;
var LW: TsshWriter;
begin
  Result:=nil; LW:=TsshWriter.Create(64);
  try LW.PutStringText('ssh-ed25519'); LW.PutStringBytes(APub); Result:=LW.ToBytes; finally LW.Free; end;
end;

const
  CHACHA_ALG = 'chacha20-poly1305@openssh.com';
  SERVER_IDENT = 'SSH-2.0-NextPas-LoopServer';
  SRV_CHANNEL_ID = 7;
  SRV_RECV_WINDOW = 2097152;

type
  PSshLoopServerScenario = ^TSshLoopServerScenario;
  TSshLoopServerScenario = record
    AcceptUser: string; AcceptPassword: string; PasswordOk: Boolean; PubKeyOk: Boolean;
    StdOut1: TBytes; StdOut2: TBytes; StdErr: TBytes; ExitCode: UInt32;
    HostSeed: TBytes; ForceDH: Boolean; ForceCompress: Boolean;
    Failed: Boolean; FailMsg: string; Done: Boolean; MsgCount: Integer; Msg1Type: Byte; Msg1Len: Integer;
    IgnoreCount: Integer;
  end;

  TAsyncLoopThread = class(TThread)
  private FLoop: TAsyncLoop;
  protected procedure Execute; override;
  public constructor Create(ALoop: TAsyncLoop);
  end;

  TAsyncServerThread = class(TThread)
  private FListener: ITcpListener; FSc: PSshLoopServerScenario;
  protected procedure Execute; override;
  public constructor Create(AListener: ITcpListener; ASc: PSshLoopServerScenario);
  end;

  TSshLoopServer = class
  private
    FStream: IReadWriteCloser; FSc: PSshLoopServerScenario;
    FClientChannelId: UInt32; FRecvSeq, FSendSeq: UInt32;
    FRecv: ISshPacketReceiver; FSend: ISshPacketSender;
    FEncrypted: Boolean; FSessionId: TBytes;
    FComp: ISshCompressor; FCompEnabled: Boolean; FNegCompCs, FNegCompSc: string; FBuf: TBytes;
    procedure Fail(const AMsg: string);
    procedure SendPlainPayload(const APayload: TBytes);
    function RecvRaw(out AData: TBytes; ATimeoutMs: Integer): Boolean;
    function ReadPlainFrameBody: TBytes;
    function ReadAnyPayload: TBytes;
    procedure ReplyPayload(const APayload: TBytes);
    procedure Handshake;
    procedure ServeApp;
  public
    constructor Create(AStream: IReadWriteCloser; ASc: PSshLoopServerScenario);
    procedure Run;
  end;

constructor TAsyncLoopThread.Create(ALoop: TAsyncLoop);
begin inherited Create(True); FreeOnTerminate:=False; FLoop:=ALoop; end;
procedure TAsyncLoopThread.Execute; begin FLoop.Run; end;

constructor TAsyncServerThread.Create(AListener: ITcpListener; ASc: PSshLoopServerScenario);
begin inherited Create(True); FreeOnTerminate:=False; FListener:=AListener; FSc:=ASc; end;
procedure TAsyncServerThread.Execute;
var LConn: ITcpStream; Srv: TSshLoopServer;
begin
  try
    LConn:=FListener.Accept;
    Srv:=TSshLoopServer.Create(LConn as IReadWriteCloser, FSc);
    try Srv.Run; finally Srv.Free; end;
  except end;
end;

constructor TSshLoopServer.Create(AStream: IReadWriteCloser; ASc: PSshLoopServerScenario);
begin inherited Create; FStream:=AStream; FSc:=ASc; FEncrypted:=False; SetLength(FBuf,0); end;
procedure TSshLoopServer.Fail(const AMsg: string); begin if not FSc^.Failed then begin FSc^.Failed:=True; FSc^.FailMsg:=AMsg; end; end;
procedure TSshLoopServer.SendPlainPayload(const APayload: TBytes);
var LW: TsshWriter; LPad,I: Integer; LWire: TBytes;
begin
  LPad:=8 - ((4+1+Length(APayload)) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8);
  LW:=TsshWriter.Create(64+Length(APayload));
  try LW.PutUInt32(UInt32(1+Length(APayload)+SizeUInt(LPad))); LW.PutByte(Byte(LPad)); LW.PutRaw(APayload); for I:=1 to LPad do LW.PutByte($30); LWire:=LW.ToBytes; FStream.Write(LWire[0], SizeUInt(Length(LWire))); finally LW.Free; end;
end;
function TSshLoopServer.RecvRaw(out AData: TBytes; ATimeoutMs: Integer): Boolean;
var LChunk: array[0..4095] of Byte; LGot: SizeUInt; LDeadline: TDeadline;
begin
  AData:=nil;
  if Length(FBuf)>0 then begin AData:=FBuf; FBuf:=nil; Exit(True); end;
  LDeadline:=TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
  if FStream is ITcpStream then (FStream as ITcpStream).SetReadDeadline(LDeadline);
  try LGot:=FStream.Read(LChunk[0], SizeUInt(Length(LChunk))); if LGot=0 then Exit(False); SetLength(AData, LGot); Move(LChunk[0], AData[0], LGot); Result:=True;
  finally if FStream is ITcpStream then (FStream as ITcpStream).SetReadDeadline(TDeadline.Infinite); end;
end;
function TSshLoopServer.ReadPlainFrameBody: TBytes;
var LWire, LMore: TBytes; LLen, LPadLen: UInt32;
begin
  Result:=nil; if not RecvRaw(LWire,8000) then Exit;
  while Length(LWire)<4 do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LWire, LMore); end;
  LLen:=(UInt32(LWire[0]) shl 24) or (UInt32(LWire[1]) shl 16) or (UInt32(LWire[2]) shl 8) or UInt32(LWire[3]);
  while SizeUInt(Length(LWire)) < 4+LLen do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LWire, LMore); end;
  if SizeUInt(Length(LWire)) > 4+LLen then begin FBuf:=Copy(LWire, 4+Integer(LLen), Length(LWire)-4-Integer(LLen)); SetLength(LWire, 4+Integer(LLen)); end;
  LPadLen:=LWire[4]; SetLength(Result, LLen-1-LPadLen); if Length(Result)>0 then Move(LWire[5], Result[0], Length(Result));
end;
function TSshLoopServer.ReadAnyPayload: TBytes;
var LBuf, LHeader, LTrailer, LPacket, LBody: TBytes; LBodyLen: UInt32; LPadLen: Byte; LMore: TBytes;
begin
  Result:=nil;
  if not FEncrypted then begin Result:=ReadPlainFrameBody; Exit; end;
  if Length(FBuf)>=4 then begin LHeader:=Copy(FBuf,0,4); FBuf:=Copy(FBuf,4,Length(FBuf)-4); end
  else begin if not RecvRaw(LBuf,8000) then Exit; LHeader:=LBuf; if Length(FBuf)>0 then begin LHeader:=BytesConcat(FBuf, LHeader); FBuf:=nil; end; while Length(LHeader)<4 do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LHeader, LMore); end; if Length(LHeader)>4 then begin FBuf:=Copy(LHeader,4,Length(LHeader)-4); LHeader:=Copy(LHeader,0,4); end; end;
  LBodyLen:=FRecv.BodyLengthFromHeader(FRecvSeq, LHeader);
  SetLength(LTrailer, FRecv.TrailerSize(LBodyLen));
  LBuf:=nil; if Length(FBuf)>0 then begin LBuf:=FBuf; FBuf:=nil; end;
  while SizeUInt(Length(LBuf)) < SizeUInt(Length(LTrailer)) do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LBuf, LMore); end;
  if SizeUInt(Length(LBuf)) > SizeUInt(Length(LTrailer)) then begin FBuf:=Copy(LBuf, Length(LTrailer), Length(LBuf)-Length(LTrailer)); SetLength(LBuf, Length(LTrailer)); end;
  LTrailer:=LBuf; SetLength(LPacket, 4+Length(LTrailer)); Move(LHeader[0], LPacket[0],4); if Length(LTrailer)>0 then Move(LTrailer[0], LPacket[4], SizeUInt(Length(LTrailer)));
  LBody:=FRecv.Unprotect(FRecvSeq, LPacket); Inc(FRecvSeq); if Length(LBody)<1 then Exit; LPadLen:=LBody[0]; if UInt32(LPadLen)>=LBodyLen then Exit; SetLength(Result, LBodyLen-1-LPadLen); if Length(Result)>0 then Move(LBody[1], Result[0], Length(Result)); if FCompEnabled and (FComp<>nil) and SshCompressionIsZlib(FNegCompSc) then Result:=FComp.Decompress(Result);
end;
procedure TSshLoopServer.ReplyPayload(const APayload: TBytes);
var LWire,LBody: TBytes; LPad,I: Integer; LW: TsshWriter; LOut: TBytes;
begin
  if FEncrypted then
  begin LOut:=APayload; if FCompEnabled and (FComp<>nil) and SshCompressionIsZlib(FNegCompCs) then LOut:=FComp.Compress(APayload); LPad:=8 - ((4+1+SizeUInt(Length(LOut))) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8); LW:=TsshWriter.Create(8+Length(LOut)); try LW.PutByte(Byte(LPad)); LW.PutRaw(LOut); for I:=1 to LPad do LW.PutByte($30); LBody:=LW.ToBytes; finally LW.Free; end; LWire:=FSend.Protect(LBody, FSendSeq); Inc(FSendSeq); FStream.Write(LWire[0], SizeUInt(Length(LWire))); end else SendPlainPayload(APayload);
end;
procedure TSshLoopServer.Handshake;
var LLine, LVc, LMyInit, LClientInit, LInit, LMsg, LReply: TBytes;
  LR: TsshReader; LEphemeral, LShared, LKmpint, LH, LSig64, LSigBlob: TBytes;
  LXErr: AnsiString; LHostPub: TBytes; LXPriv, LXPub: TBytes;
  LIvCs, LIvSc, LKeyCs, LKeySc, LMacCs, LMacSc: TBytes;
  LW: TsshWriter; LText: string; LNl: Integer; LIsDH: Boolean;
  LPrime, LGen, LSrvPriv: TBytes; LErr: string; LClientE: TBytes;
begin
  LLine:=StringToBytes(SERVER_IDENT+#13#10); FStream.Write(LLine[0], SizeUInt(Length(LLine))); LVc:=nil;
  repeat if not RecvRaw(LLine,8000) then begin Fail('server: no version line'); Exit; end; LText:=BytesToText(LLine); LNl:=Pos(#10, LText); if LNl>0 then begin if SizeUInt(Length(LLine)) > SizeUInt(LNl) then FBuf:=BytesConcat(Copy(LLine, LNl, Length(LLine)-LNl), FBuf); LText:=Trim(Copy(LText,1,LNl)); if Copy(LText,1,4)='SSH-' then LVc:=StringToBytes(LText); end; until Length(LVc)>0;
  LClientInit:=ReadPlainFrameBody; if (Length(LClientInit)=0) or (LClientInit[0]<>SSH_MSG_KEXINIT) then begin Fail('server: expected KEXINIT'); Exit; end;
  if FSc^.ForceDH or FSc^.ForceCompress then
  begin LW:=TsshWriter.Create(512); try LW.PutByte(SSH_MSG_KEXINIT); LW.PutRaw(PatternBytes($EE,16)); if FSc^.ForceDH then LW.PutNameList(['diffie-hellman-group14-sha256']) else LW.PutNameList(['curve25519-sha256','curve25519-sha256@libssh.org','diffie-hellman-group14-sha256']); LW.PutNameList(['ssh-ed25519']); LW.PutNameList(['chacha20-poly1305@openssh.com']); LW.PutNameList(['chacha20-poly1305@openssh.com']); LW.PutNameList([]); LW.PutNameList([]); if FSc^.ForceCompress then begin LW.PutNameList(['zlib@openssh.com','zlib','none']); LW.PutNameList(['zlib@openssh.com','zlib','none']); end else begin LW.PutNameList(['none']); LW.PutNameList(['none']); end; LW.PutStringText(''); LW.PutStringText(''); LW.PutBoolean(False); LW.PutUInt32(0); LMyInit:=LW.ToBytes; finally LW.Free; end;
  end else LMyInit:=SshBuildKexInitPayload(PatternBytes($EE,16));
  SendPlainPayload(LMyInit);
  LInit:=ReadPlainFrameBody; if (Length(LInit)=0) or (LInit[0]<>SSH_MSG_KEX_ECDH_INIT) then begin Fail('server: expected KEX INIT'); Exit; end;
  LHostPub:=Ed25519PublicKeyFromPrivate(FSc^.HostSeed); LIsDH:=FSc^.ForceDH;
  if LIsDH then begin LR:=TsshReader.Create(LInit); try LR.ReadByte; LClientE:=LR.ReadMPInt; finally LR.Free; end; LPrime:=SshDHGroup14Prime; LGen:=SshDHGroup14Generator; LSrvPriv:=GenerateSecureRandomBytes(32); if not TryBigIntModExpFromUnsignedBytes(LGen, LSrvPriv, LPrime, LXPub, LErr) then begin Fail('server: dh pub failed: '+LErr); Exit; end; if not TryBigIntModExpFromUnsignedBytes(LClientE, LSrvPriv, LPrime, LShared, LErr) then begin Fail('server: dh shared failed: '+LErr); Exit; end; LEphemeral:=LClientE; end else begin LR:=TsshReader.Create(LInit); try LR.ReadByte; LEphemeral:=LR.ReadStringBytes; finally LR.Free; end; GenerateX25519KeyPair(LXPriv, LXPub); if not TryX25519ComputeSharedSecret(LXPriv, LEphemeral, LShared, LXErr) then begin Fail('server: x25519 failed'); Exit; end; end;
  LW:=TsshWriter.Create(80); try LW.PutMPInt(LShared); LKmpint:=LW.ToBytes; finally LW.Free; end;
  if LIsDH then LH:=SHA256(SshBuildDHGroup14HashInput(BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit, Ed25519PubBlob(LHostPub), LEphemeral, LXPub, LShared)) else LH:=SHA256(SshBuildCurve25519HashInput(BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit, Ed25519PubBlob(LHostPub), LEphemeral, LXPub, LShared));
  FSessionId:=LH; if not Ed25519Sign(FSc^.HostSeed, LH, LSig64) then begin Fail('server: host sign failed'); Exit; end; LSigBlob:=SigBlobOf('ssh-ed25519', LSig64);
  LW:=TsshWriter.Create(512); try LW.PutByte(SSH_MSG_KEX_ECDH_REPLY); LW.PutStringBytes(Ed25519PubBlob(LHostPub)); if LIsDH then LW.PutMPInt(LXPub) else LW.PutStringBytes(LXPub); LW.PutStringBytes(LSigBlob); LReply:=LW.ToBytes; SendPlainPayload(LReply); finally LW.Free; end;
  LMsg:=ReadPlainFrameBody; if Length(LMsg)=0 then Exit; if LMsg[0]=SSH_MSG_DISCONNECT then Exit; if LMsg[0]<>SSH_MSG_NEWKEYS then begin Fail('server: expected NEWKEYS'); Exit; end; SendPlainPayload(SingleBytePayloadOf(SSH_MSG_NEWKEYS));
  LIvCs:=SshKdfSha256(LKmpint, LH, Ord('A'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LIvSc:=SshKdfSha256(LKmpint, LH, Ord('B'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LKeyCs:=SshKdfSha256(LKmpint, LH, Ord('C'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LKeySc:=SshKdfSha256(LKmpint, LH, Ord('D'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LMacCs:=SshKdfSha256(LKmpint, LH, Ord('E'), FSessionId, SshMacKeySize('')); LMacSc:=SshKdfSha256(LKmpint, LH, Ord('F'), FSessionId, SshMacKeySize(''));
  FRecv:=CreateSshPacketReceiver(CHACHA_ALG,'',LKeyCs, LIvCs, LMacCs); FSend:=CreateSshPacketSender(CHACHA_ALG,'',LKeySc, LIvSc, LMacSc); FRecvSeq:=3; FSendSeq:=3; FEncrypted:=True;
  if FSc^.ForceCompress then begin FNegCompCs:=SSH_COMP_ZLIB_OPENSSH; FNegCompSc:=SSH_COMP_ZLIB_OPENSSH; FComp:=CreateSshZlibCompressor; FCompEnabled:=False; end else begin FNegCompCs:=SSH_COMP_NONE; FNegCompSc:=SSH_COMP_NONE; end;
end;
procedure TSshLoopServer.ServeApp;
var LMsg: TBytes; LR: TsshReader; LUser, LMethod, LPass, LAlg, LReqName: string;
  LPassOk, LWantReply, LHasSig: Boolean; LPubBlob, LSigBlob, LSigRaw, LSignedData: TBytes;
  LRid: UInt32; LRAlg: TsshReader; LW: TsshWriter;
begin
  while True do
  begin
    LMsg:=ReadAnyPayload; if Length(LMsg)=0 then Exit; Inc(FSc^.MsgCount); if FSc^.MsgCount=1 then begin FSc^.Msg1Type:=LMsg[0]; FSc^.Msg1Len:=Length(LMsg); end;
    case LMsg[0] of
      SSH_MSG_IGNORE: Inc(FSc^.IgnoreCount);
      SSH_MSG_DISCONNECT: Exit;
      SSH_MSG_SERVICE_REQUEST: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_SERVICE_ACCEPT); LW.PutStringText(SSH_SERVICE_USERAUTH); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_USERAUTH_REQUEST:
        begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LUser:=LR.ReadStringText; LR.ReadStringText; LMethod:=LR.ReadStringText; LPassOk:=False; if LMethod='password' then begin LR.ReadBoolean; LPass:=LR.ReadStringText; LPassOk:=(LUser=FSc^.AcceptUser) and FSc^.PasswordOk and (LPass=FSc^.AcceptPassword); end else if LMethod='publickey' then begin LHasSig:=LR.ReadBoolean; LAlg:=LR.ReadStringText; LPubBlob:=LR.ReadStringBytes; if not LHasSig then begin if FSc^.PubKeyOk then begin LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_USERAUTH_PK_OK); LW.PutStringText(LAlg); LW.PutStringBytes(LPubBlob); ReplyPayload(LW.ToBytes); finally LW.Free; end; end else begin LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_USERAUTH_FAILURE); LW.PutStringText('password,publickey'); LW.PutBoolean(False); ReplyPayload(LW.ToBytes); finally LW.Free; end; end; Continue; end; LSigBlob:=LR.ReadStringBytes; if FSc^.PubKeyOk and (LAlg='ssh-ed25519') and (Length(LSigBlob)>0) then begin LSigRaw:=nil; LRAlg:=TsshReader.Create(LSigBlob); try LRAlg.ReadStringText; LSigRaw:=LRAlg.ReadStringBytes; finally LRAlg.Free; end; LSignedData:=SshAuthSignedData(FSessionId, LUser, 'ssh-ed25519', LPubBlob); LPassOk:=Ed25519Verify(Copy(LPubBlob, Length(LPubBlob)-32,32), LSignedData, LSigRaw); end; end; finally LR.Free; end; if LPassOk then begin ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS)); if SshCompressionIsDelayed(FNegCompSc) or SshCompressionIsDelayed(FNegCompCs) then FCompEnabled:=True; end else begin LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_USERAUTH_FAILURE); LW.PutStringText('password,publickey'); LW.PutBoolean(False); ReplyPayload(LW.ToBytes); finally LW.Free; end; end; end;
      SSH_MSG_CHANNEL_OPEN: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadStringText; LRid:=LR.ReadUInt32; FClientChannelId:=LRid; finally LR.Free; end; LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION); LW.PutUInt32(LRid); LW.PutUInt32(SRV_CHANNEL_ID); LW.PutUInt32(SRV_RECV_WINDOW); LW.PutUInt32(32768); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_CHANNEL_REQUEST:
        begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LReqName:=LR.ReadStringText; LWantReply:=LR.ReadBoolean; if LReqName=SSH_REQ_EXEC then begin if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, True)); LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutStringBytes(FSc^.StdOut1); ReplyPayload(LW.ToBytes); finally LW.Free; end; LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutStringBytes(FSc^.StdOut2); ReplyPayload(LW.ToBytes); finally LW.Free; end; LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_CHANNEL_EXTENDED_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(SSH_EXTENDED_DATA_STDERR); LW.PutStringBytes(FSc^.StdErr); ReplyPayload(LW.ToBytes); finally LW.Free; end; LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_CHANNEL_REQUEST); LW.PutUInt32(FClientChannelId); LW.PutStringText(SSH_REQ_EXIT_STATUS); LW.PutBoolean(True); LW.PutUInt32(FSc^.ExitCode); ReplyPayload(LW.ToBytes); finally LW.Free; end; ReplyPayload(ClosePayload(FClientChannelId)); end else if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, False)); finally LR.Free; end; end;
      SSH_MSG_CHANNEL_DATA, SSH_MSG_CHANNEL_WINDOW_ADJUST, SSH_MSG_CHANNEL_EOF, SSH_MSG_CHANNEL_CLOSE, SSH_MSG_GLOBAL_REQUEST, SSH_MSG_CHANNEL_EXTENDED_DATA, SSH_MSG_CHANNEL_SUCCESS, SSH_MSG_CHANNEL_FAILURE: ;
    end;
  end;
end;
procedure TSshLoopServer.Run; begin try Handshake; if not FSc^.Failed then ServeApp; except on E: Exception do Fail(E.Message); end; FSc^.Done:=True; end;

type
  PAsyncTestState = ^TAsyncTestState;
  TAsyncTestState = record
    Session: ISshAsyncSession; Err: ESSHError; Done: Boolean;
    ExecResult: TSshExecResult; ExecErr: ESSHError; ExecDone: Boolean;
    Event: PRTLEvent;
  end;

var GAsyncState: TAsyncTestState;

procedure OnAsyncConnect(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer);
begin
  GAsyncState.Session:=ASession; GAsyncState.Err:=AErr; GAsyncState.Done:=True;
  if GAsyncState.Event<>nil then RTLeventSetEvent(GAsyncState.Event);
end;

procedure OnAsyncExec(const AResult: TSshExecResult; AErr: ESSHError; AContext: Pointer);
begin
  GAsyncState.ExecResult:=AResult; GAsyncState.ExecErr:=AErr; GAsyncState.ExecDone:=True;
  if GAsyncState.Event<>nil then RTLeventSetEvent(GAsyncState.Event);
end;

function WaitForFlag(var ADone: Boolean; AEvent: PRTLEvent; ATimeoutMs: Integer): Boolean;
var LStart: QWord;
begin
  LStart:=GetTickCount64;
  while not ADone do
  begin
    if GetTickCount64 - LStart > UInt64(ATimeoutMs) then Exit(False);
    RTLeventWaitFor(AEvent, 20);
  end;
  Result:=True;
end;

function RunAsyncScenario(const AHostSeed: TBytes; AUser, APass: string; APassOk, APubOk: Boolean; AForceDH, AForceComp: Boolean; ACommand: string; out ARes: TSshExecResult; out AErrKind: TSshErrorKind): Boolean;
var
  LListener: ITcpListener; LPort: Word; LSc: PSshLoopServerScenario;
  LServerThread: TThread; LLoop: TAsyncLoop; LLoopThread: TThread;
  LOpts: TSshConnectOptions;
begin
  Result:=False; ARes:=Default(TSshExecResult); AErrKind:=sekIO;
  LServerThread:=nil; LLoop:=nil; LLoopThread:=nil; LListener:=nil;
  LOpts:=Default(TSshConnectOptions);
  New(LSc); LSc^:=Default(TSshLoopServerScenario);
  LSc^.AcceptUser:='testuser'; LSc^.AcceptPassword:='testpass'; LSc^.PasswordOk:=APassOk; LSc^.PubKeyOk:=APubOk;
  LSc^.StdOut1:=StringToBytes('hello-'); LSc^.StdOut2:=StringToBytes('world'); LSc^.StdErr:=StringToBytes('err-'); LSc^.ExitCode:=42;
  LSc^.HostSeed:=AHostSeed; LSc^.ForceDH:=AForceDH; LSc^.ForceCompress:=AForceComp;
  LListener:=NetTcpListen('127.0.0.1',0);
  try
    LPort:=LListener.LocalAddr.Port;
    LServerThread:=TAsyncServerThread.Create(LListener, LSc);
    LServerThread.Start;
    LLoop:=TAsyncLoop.Create(64);
    try
      if GAsyncState.Session<>nil then GAsyncState.Session:=nil;
      if GAsyncState.Err<>nil then FreeAndNil(GAsyncState.Err);
      if GAsyncState.ExecErr<>nil then FreeAndNil(GAsyncState.ExecErr);
      GAsyncState:=Default(TAsyncTestState);
      GAsyncState.Event:=RTLEventCreate;
      try
        LLoopThread:=TAsyncLoopThread.Create(LLoop);
        LLoopThread.Start;
        LOpts:=DefaultSshConnectOptions('127.0.0.1'); LOpts.Host:='127.0.0.1'; LOpts.Port:=LPort; LOpts.User:=AUser; LOpts.Password:=APass; LOpts.Compress:=AForceComp; LOpts.ExecTimeoutMs:=5000; LOpts.ConnectTimeoutMs:=3000;
        if not SshAsyncConnect(LLoop, LOpts, @OnAsyncConnect, nil) then begin GAsyncState.Err:=ESSHError.Create(sekIO,'dial submit failed'); GAsyncState.Done:=True; end;
        if not WaitForFlag(GAsyncState.Done, GAsyncState.Event, 8000) then begin AErrKind:=sekTimeout; Exit; end;
        if GAsyncState.Err<>nil then begin AErrKind:=GAsyncState.Err.Kind; FreeAndNil(GAsyncState.Err); Exit; end;
        if GAsyncState.Session=nil then Exit;
        GAsyncState.ExecDone:=False; RTLeventResetEvent(GAsyncState.Event);
        if not GAsyncState.Session.ExecAsync(ACommand, @OnAsyncExec) then begin AErrKind:=sekIO; Exit; end;
        if not WaitForFlag(GAsyncState.ExecDone, GAsyncState.Event, 8000) then begin AErrKind:=sekTimeout; Exit; end;
        if GAsyncState.ExecErr<>nil then begin AErrKind:=GAsyncState.ExecErr.Kind; FreeAndNil(GAsyncState.ExecErr); Exit; end;
        ARes:=GAsyncState.ExecResult; Result:=True;
        try GAsyncState.Session.Close; except end;
        Sleep(200);
      finally RTLeventDestroy(GAsyncState.Event); GAsyncState.Event:=nil; if Assigned(LLoop) then LLoop.Stop; if Assigned(LLoopThread) then begin LLoopThread.WaitFor; LLoopThread.Free; end; Sleep(50); Finalize(GAsyncState); GAsyncState:=Default(TAsyncTestState); end;
    finally
      if GAsyncState.Session<>nil then begin try GAsyncState.Session.Close; except end; GAsyncState.Session:=nil; end;
      if GAsyncState.Err<>nil then FreeAndNil(GAsyncState.Err);
      if GAsyncState.ExecErr<>nil then FreeAndNil(GAsyncState.ExecErr);
      SetLength(GAsyncState.ExecResult.StdOut,0); SetLength(GAsyncState.ExecResult.StdErr,0);
      Finalize(GAsyncState); GAsyncState:=Default(TAsyncTestState);
      if Assigned(LLoop) then begin try LLoop.Free; except end; end;
    end;
  finally
    if Assigned(LServerThread) then begin LServerThread.WaitFor; LServerThread.Free; end;
    Finalize(LOpts);
    if Assigned(LListener) then LListener.Close;
    LSc^.AcceptUser:=''; LSc^.AcceptPassword:='';
    SetLength(LSc^.StdOut1,0); SetLength(LSc^.StdOut2,0); SetLength(LSc^.StdErr,0);
    SetLength(LSc^.HostSeed,0);
    Finalize(LSc^); Dispose(LSc);
  end;
end;

function RunAsyncScenarioWithKeepAlive(const AHostSeed: TBytes; AKeepAliveMs: Integer; out AIgnoreCount: Integer; out ARes: TSshExecResult; out AErrKind: TSshErrorKind): Boolean;
var
  LListener: ITcpListener; LPort: Word; LSc: PSshLoopServerScenario;
  LServerThread: TThread; LLoop: TAsyncLoop; LLoopThread: TThread;
  LOpts: TSshConnectOptions;
begin
  Result:=False; AIgnoreCount:=0; ARes:=Default(TSshExecResult); AErrKind:=sekIO;
  LServerThread:=nil; LLoop:=nil; LLoopThread:=nil; LListener:=nil;
  LOpts:=Default(TSshConnectOptions);
  New(LSc); LSc^:=Default(TSshLoopServerScenario);
  LSc^.AcceptUser:='testuser'; LSc^.AcceptPassword:='testpass'; LSc^.PasswordOk:=True;
  LSc^.StdOut1:=StringToBytes('hello-'); LSc^.StdOut2:=StringToBytes('world'); LSc^.StdErr:=StringToBytes('err-'); LSc^.ExitCode:=42;
  LSc^.HostSeed:=AHostSeed;
  LListener:=NetTcpListen('127.0.0.1',0);
  try
    LPort:=LListener.LocalAddr.Port;
    LServerThread:=TAsyncServerThread.Create(LListener, LSc);
    LServerThread.Start;
    LLoop:=TAsyncLoop.Create(64);
    try
      if GAsyncState.Session<>nil then GAsyncState.Session:=nil;
      if GAsyncState.Err<>nil then FreeAndNil(GAsyncState.Err);
      if GAsyncState.ExecErr<>nil then FreeAndNil(GAsyncState.ExecErr);
      GAsyncState:=Default(TAsyncTestState);
      GAsyncState.Event:=RTLEventCreate;
      try
        LLoopThread:=TAsyncLoopThread.Create(LLoop);
        LLoopThread.Start;
        LOpts:=DefaultSshConnectOptions('127.0.0.1'); LOpts.Host:='127.0.0.1'; LOpts.Port:=LPort; LOpts.User:='testuser'; LOpts.Password:='testpass';
        LOpts.KeepAliveIntervalMs:=AKeepAliveMs; LOpts.ExecTimeoutMs:=5000; LOpts.ConnectTimeoutMs:=3000;
        if not SshAsyncConnect(LLoop, LOpts, @OnAsyncConnect, nil) then begin GAsyncState.Err:=ESSHError.Create(sekIO,'dial submit failed'); GAsyncState.Done:=True; end;
        if not WaitForFlag(GAsyncState.Done, GAsyncState.Event, 8000) then begin AErrKind:=sekTimeout; Exit; end;
        if GAsyncState.Err<>nil then begin AErrKind:=GAsyncState.Err.Kind; FreeAndNil(GAsyncState.Err); Exit; end;
        if GAsyncState.Session=nil then Exit;
        Sleep(350);
        AIgnoreCount:=LSc^.IgnoreCount;
        GAsyncState.ExecDone:=False; RTLeventResetEvent(GAsyncState.Event);
        if not GAsyncState.Session.ExecAsync('echo hi', @OnAsyncExec) then begin AErrKind:=sekIO; Exit; end;
        if not WaitForFlag(GAsyncState.ExecDone, GAsyncState.Event, 8000) then begin AErrKind:=sekTimeout; Exit; end;
        if GAsyncState.ExecErr<>nil then begin AErrKind:=GAsyncState.ExecErr.Kind; FreeAndNil(GAsyncState.ExecErr); Exit; end;
        ARes:=GAsyncState.ExecResult; Result:=True;
        try GAsyncState.Session.Close; except end;
        Sleep(200);
      finally RTLeventDestroy(GAsyncState.Event); GAsyncState.Event:=nil; if Assigned(LLoop) then LLoop.Stop; if Assigned(LLoopThread) then begin LLoopThread.WaitFor; LLoopThread.Free; end; Sleep(50); Finalize(GAsyncState); GAsyncState:=Default(TAsyncTestState); end;
    finally
      if GAsyncState.Session<>nil then begin try GAsyncState.Session.Close; except end; GAsyncState.Session:=nil; end;
      if GAsyncState.Err<>nil then FreeAndNil(GAsyncState.Err);
      if GAsyncState.ExecErr<>nil then FreeAndNil(GAsyncState.ExecErr);
      SetLength(GAsyncState.ExecResult.StdOut,0); SetLength(GAsyncState.ExecResult.StdErr,0);
      Finalize(GAsyncState); GAsyncState:=Default(TAsyncTestState);
      if Assigned(LLoop) then begin try LLoop.Free; except end; end;
    end;
  finally
    if Assigned(LServerThread) then begin LServerThread.WaitFor; LServerThread.Free; end;
    Finalize(LOpts);
    if Assigned(LListener) then LListener.Close;
    LSc^.AcceptUser:=''; LSc^.AcceptPassword:='';
    SetLength(LSc^.StdOut1,0); SetLength(LSc^.StdOut2,0); SetLength(LSc^.StdErr,0);
    SetLength(LSc^.HostSeed,0);
    Finalize(LSc^); Dispose(LSc);
  end;
end;

var GSeed: TBytes; GRunner: TSuiteRunner; GSuite: TTestSuite;
begin
  GSeed:=PatternBytes($11,32);
  GSuite:=TTestSuite.Create('ssh session async');
  GSuite.Test('password auth async loopback', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; begin Ok:=RunAsyncScenario(GSeed, 'testuser','testpass', True, False, False, False, 'echo hi', R, K); CheckTrue(Ok, 'password ok'); CheckEqual('hello-world', BytesToText(R.StdOut), 'stdout'); CheckEqual('err-', BytesToText(R.StdErr), 'stderr'); CheckEqual(Int64(42), Int64(R.ExitCode), 'exit'); end);
  GSuite.Test('wrong password rejected async', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; begin Ok:=RunAsyncScenario(GSeed, 'testuser','wrong', True, False, False, False, 'echo hi', R, K); CheckTrue(not Ok, 'wrong should fail'); CheckEqual(Ord(sekAuth), Ord(K), 'kind auth'); end);
  GSuite.Test('compress delayed async', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; begin Ok:=RunAsyncScenario(GSeed, 'testuser','testpass', True, False, False, True, 'echo hi', R, K); CheckTrue(Ok, 'compress ok'); CheckEqual('hello-world', BytesToText(R.StdOut), 'stdout compress'); end);
  GSuite.Test('dh fallback async', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; begin Ok:=RunAsyncScenario(GSeed, 'testuser','testpass', True, False, True, False, 'echo hi', R, K); CheckTrue(Ok, 'dh ok'); CheckEqual('hello-world', BytesToText(R.StdOut), 'stdout dh'); end);
  GSuite.Test('dh+compress async', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; begin Ok:=RunAsyncScenario(GSeed, 'testuser','testpass', True, False, True, True, 'echo hi', R, K); CheckTrue(Ok, 'dh+compress ok'); CheckEqual('hello-world', BytesToText(R.StdOut), 'stdout dh+compress'); end);
  GSuite.Test('keepalive 100ms idle does not break exec', procedure var R: TSshExecResult; K: TSshErrorKind; Ok: Boolean; IC: Integer; begin Ok:=RunAsyncScenarioWithKeepAlive(GSeed, 100, IC, R, K); CheckTrue(Ok, 'keepalive exec ok'); CheckTrue(IC>=1, 'at least one IGNORE received (got '+IntToStr(IC)+')'); CheckEqual('hello-world', BytesToText(R.StdOut), 'stdout after keepalive'); end);
  GRunner:=TSuiteRunner.Create('nextpas.core.ssh.session.async');
  GRunner.Add(GSuite);
  GRunner.RunAll;
  GRunner.Summary;
  if not GRunner.AllPassed then Halt(1);
  Finalize(GAsyncState); GAsyncState:=Default(TAsyncTestState);
  SetLength(GSeed,0);
  Finalize(GSuite); GSuite:=Default(TTestSuite);
  Finalize(GRunner); GRunner:=Default(TSuiteRunner);
end.
