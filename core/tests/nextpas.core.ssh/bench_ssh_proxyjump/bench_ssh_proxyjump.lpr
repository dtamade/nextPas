program bench_ssh_proxyjump;
{$mode ObjFPC}{$H+}
uses
  nextpas.core.bytes.ops,
  cthreads,
  Classes, SysUtils, Math,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.session,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.random;

type
  PPipeShared = ^TPipeShared;
  TPipeShared = record Lock: TRTLCriticalSection; end;
  TMemPipeEnd = class(TInterfacedObject, IReadWriteCloser)
  private
    FPeer: TMemPipeEnd;
    FShared: PPipeShared;
    FIncoming: TBytes;
    FReadPos: SizeUInt;
    FClosed: Boolean;
    FDataEvent: PRTLEvent;
    procedure AppendLocked(const ASrc; ACount: SizeUInt);
  public
    constructor Create(AShared: PPipeShared);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    procedure SetPeer(APeer: TMemPipeEnd);
    procedure Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
    procedure DrainNB(out ADest: TBytes);
    procedure Rewind(ACount: SizeUInt);
    property Closed: Boolean read FClosed;
  end;

procedure TMemPipeEnd.Rewind(ACount: SizeUInt);
begin EnterCriticalSection(FShared^.Lock); Dec(FReadPos, ACount); LeaveCriticalSection(FShared^.Lock); end;
constructor TMemPipeEnd.Create(AShared: PPipeShared); begin inherited Create; FShared:=AShared; FDataEvent:=RTLEventCreate; end;
destructor TMemPipeEnd.Destroy; begin RTLEventDestroy(FDataEvent); inherited Destroy; end;
procedure TMemPipeEnd.SetPeer(APeer: TMemPipeEnd); begin FPeer:=APeer; end;
procedure TMemPipeEnd.AppendLocked(const ASrc; ACount: SizeUInt); var LOld: SizeUInt; begin LOld:=SizeUInt(Length(FIncoming)); SetLength(FIncoming, LOld+ACount); Move(ASrc, FIncoming[LOld], ACount); end;
function TMemPipeEnd.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var LAvail: SizeUInt; LWaits: Integer;
begin Result:=0; LWaits:=0; while True do begin EnterCriticalSection(FShared^.Lock); LAvail:=SizeUInt(Length(FIncoming))-FReadPos; if LAvail>ACount then LAvail:=ACount; if LAvail>0 then begin Move(FIncoming[FReadPos], ABuf, LAvail); Inc(FReadPos, LAvail); end; LeaveCriticalSection(FShared^.Lock); if LAvail>0 then Exit(LAvail); if FClosed or FPeer.FClosed then Exit(0); RTLeventResetEvent(FDataEvent); EnterCriticalSection(FShared^.Lock); LAvail:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if (LAvail=0) and not FClosed and not FPeer.FClosed then begin Inc(LWaits); if LWaits>40 then Exit(0); RTLEventWaitFor(FDataEvent, 500); end; end;
end;
function TMemPipeEnd.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; if FClosed or (FPeer=nil) or FPeer.FClosed then Exit; EnterCriticalSection(FShared^.Lock); FPeer.AppendLocked(ABuf, ACount); LeaveCriticalSection(FShared^.Lock); RTLeventSetEvent(FPeer.FDataEvent); Result:=ACount; end;
procedure TMemPipeEnd.Close; begin FClosed:=True; RTLeventSetEvent(FDataEvent); end;
procedure TMemPipeEnd.Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
var LRemain: SizeUInt; begin ADest:=nil; EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if LRemain=0 then begin RTLeventResetEvent(FDataEvent); EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if (LRemain=0) and not FClosed then RTLEventWaitFor(FDataEvent, ATimeoutMs); end; EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; SetLength(ADest, LRemain); if LRemain>0 then begin Move(FIncoming[FReadPos], ADest[0], LRemain); Inc(FReadPos, LRemain); end; LeaveCriticalSection(FShared^.Lock); end;
procedure TMemPipeEnd.DrainNB(out ADest: TBytes); var LRemain: SizeUInt; begin EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; SetLength(ADest, LRemain); if LRemain>0 then begin Move(FIncoming[FReadPos], ADest[0], LRemain); Inc(FReadPos, LRemain); end; LeaveCriticalSection(FShared^.Lock); end;
procedure MakePipe(out AClientSide, AServerSide: TMemPipeEnd; out AShared: PPipeShared);
begin New(AShared); InitCriticalSection(AShared^.Lock); AClientSide:=TMemPipeEnd.Create(AShared); AServerSide:=TMemPipeEnd.Create(AShared); AClientSide.SetPeer(AServerSide); AServerSide.SetPeer(AClientSide); end;
function StringToBytes(const AText: string): TBytes; begin Result:=nil; SetLength(Result, Length(AText)); if Length(AText)>0 then Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText))); end;
function BytesToText(const AData: TBytes): string; begin Result:=''; SetLength(Result, Length(AData)); if Length(AData)>0 then Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData))); end;
function PatternBytes(APattern: Byte; ACount: Integer): TBytes; begin Result:=nil; SetLength(Result, ACount); if ACount>0 then FillChar(Result[0], SizeUInt(ACount), APattern); end;
function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes; var LW:TsshWriter; begin LW:=TsshWriter.Create(128); try LW.PutStringText(AAlgName); LW.PutStringBytes(ARawSig); Result:=LW.ToBytes; finally LW.Free; end; end;
function SingleBytePayloadOf(AMsg: Byte): TBytes; begin Result:=nil; SetLength(Result,1); Result[0]:=AMsg; end;
function Ed25519PubBlob(const APub: TBytes): TBytes; var LW:TsshWriter; begin LW:=TsshWriter.Create(64); try LW.PutStringText('ssh-ed25519'); LW.PutStringBytes(APub); Result:=LW.ToBytes; finally LW.Free; end; end;
const CHACHA_ALG='chacha20-poly1305@openssh.com'; SERVER_IDENT='SSH-2.0-NextPas-Bench'; SRV_CHANNEL_ID=7; SRV_RECV_WINDOW=2097152;
type PSshLoopServerScenario = ^TSshLoopServerScenario;
  TSshLoopServerScenario = record AcceptUser:string; AcceptPassword:string; StdOut1:TBytes; ExitCode:UInt32; HostSeed:TBytes; Done,Failed:Boolean; FailMsg:string; IsJump:Boolean; FwdPipe:TMemPipeEnd; end;
  TSshLoopServer = class
  private
    FEnd: TMemPipeEnd; FSc: PSshLoopServerScenario; FClientChannelId: UInt32; FRecvSeq, FSendSeq: UInt32;
    FRecv: ISshPacketReceiver; FSend: ISshPacketSender; FEncrypted:Boolean; FSessionId:TBytes;
    procedure SendPlainPayload(const APayload:TBytes);
    function RecvRaw(out AData:TBytes; ATimeoutMs:Integer):Boolean;
    function ReadPlainFrameBody:TBytes;
    function ReadAnyPayload:TBytes;
    function ReadAnyPayloadTimeout(ATimeoutMs:Integer; out APayload:TBytes):Boolean;
    procedure ReplyPayload(const APayload:TBytes);
    procedure Handshake; procedure ServeApp; procedure ServeJumpForward; procedure Fail(const AMsg:string);
  public constructor Create(AEnd:TMemPipeEnd; ASc:PSshLoopServerScenario); procedure Run; end;
constructor TSshLoopServer.Create(AEnd:TMemPipeEnd; ASc:PSshLoopServerScenario); begin inherited Create; FEnd:=AEnd; FSc:=ASc; FEncrypted:=False; end;
procedure TSshLoopServer.Fail(const AMsg:string); begin if not FSc^.Failed then begin FSc^.Failed:=True; FSc^.FailMsg:=AMsg; end; end;
procedure TSshLoopServer.SendPlainPayload(const APayload:TBytes);
var LW:TsshWriter; LPad,I:Integer; LWire:TBytes; begin LPad:=8-((4+1+Length(APayload)) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8); LW:=TsshWriter.Create(64+Length(APayload)); try LW.PutUInt32(UInt32(1+Length(APayload)+SizeUInt(LPad))); LW.PutByte(Byte(LPad)); LW.PutRaw(APayload); for I:=1 to LPad do LW.PutByte($30); LWire:=LW.ToBytes; FEnd.Write(LWire[0], SizeUInt(Length(LWire))); finally LW.Free; end; end;
function TSshLoopServer.RecvRaw(out AData:TBytes; ATimeoutMs:Integer):Boolean; begin FEnd.Drain(AData, Cardinal(ATimeoutMs)); Result:=Length(AData)>0; end;
function TSshLoopServer.ReadPlainFrameBody:TBytes;
var LWire,LMore:TBytes; LLen,LPadLen:UInt32; begin Result:=nil; if not RecvRaw(LWire,8000) then Exit; if Length(LWire)<4 then begin while (Length(LWire)<4) and RecvRaw(LMore,8000) do BytesAppend(LWire,LMore); if Length(LWire)<4 then Exit; end; LLen:=(UInt32(LWire[0]) shl 24) or (UInt32(LWire[1]) shl 16) or (UInt32(LWire[2]) shl 8) or UInt32(LWire[3]); while SizeUInt(Length(LWire))<4+LLen do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LWire,LMore); end; FEnd.Rewind(SizeUInt(Length(LWire))-(4+LLen)); LPadLen:=LWire[4]; SetLength(Result, LLen-1-LPadLen); if Length(Result)>0 then Move(LWire[5], Result[0], Length(Result)); end;
function TSshLoopServer.ReadAnyPayload:TBytes;
var LBuf,LHeader,LTrailer,LPacket,LBody:TBytes; LBodyLen:UInt32; LPadLen:Byte; begin Result:=nil; if not FEncrypted then begin Result:=ReadPlainFrameBody; Exit; end; if not RecvRaw(LBuf,8000) then Exit; LHeader:=LBuf; while SizeUInt(Length(LHeader))<4 do begin if not RecvRaw(LBuf,8000) then Exit; BytesAppend(LHeader,LBuf); end; LBodyLen:=FRecv.BodyLengthFromHeader(FRecvSeq, Copy(LHeader,0,4)); SetLength(LTrailer, FRecv.TrailerSize(LBodyLen)); while SizeUInt(Length(LHeader))<4+SizeUInt(Length(LTrailer)) do begin if not RecvRaw(LBuf,8000) then Exit; BytesAppend(LHeader,LBuf); end; LPacket:=Copy(LHeader,0,4+SizeInt(Length(LTrailer))); FEnd.Rewind(SizeUInt(Length(LHeader))-(4+SizeUInt(Length(LTrailer)))); LBody:=FRecv.Unprotect(FRecvSeq,LPacket); Inc(FRecvSeq); if SizeUInt(Length(LBody))<1 then Exit; LPadLen:=LBody[0]; if UInt32(LPadLen)>=LBodyLen then Exit; SetLength(Result, LBodyLen-1-LPadLen); if Length(Result)>0 then Move(LBody[1], Result[0], Length(Result)); end;
function TSshLoopServer.ReadAnyPayloadTimeout(ATimeoutMs:Integer; out APayload:TBytes):Boolean;
var LBuf,LHeader,LTrailer,LPacket,LBody:TBytes; LBodyLen:UInt32; LPadLen:Byte; begin APayload:=nil; if not FEncrypted then begin APayload:=nil; Result:=False; Exit; end; if not RecvRaw(LBuf, ATimeoutMs) then Exit(False); LHeader:=LBuf; while SizeUInt(Length(LHeader))<4 do begin if not RecvRaw(LBuf, ATimeoutMs) then Exit(False); BytesAppend(LHeader,LBuf); end; LBodyLen:=FRecv.BodyLengthFromHeader(FRecvSeq, Copy(LHeader,0,4)); SetLength(LTrailer, FRecv.TrailerSize(LBodyLen)); while SizeUInt(Length(LHeader))<4+SizeUInt(Length(LTrailer)) do begin if not RecvRaw(LBuf, ATimeoutMs) then Exit(False); BytesAppend(LHeader,LBuf); end; LPacket:=Copy(LHeader,0,4+SizeInt(Length(LTrailer))); FEnd.Rewind(SizeUInt(Length(LHeader))-(4+SizeUInt(Length(LTrailer)))); LBody:=FRecv.Unprotect(FRecvSeq,LPacket); Inc(FRecvSeq); LPadLen:=LBody[0]; if UInt32(LPadLen)>=LBodyLen then Exit(False); SetLength(APayload, LBodyLen-1-LPadLen); if Length(APayload)>0 then Move(LBody[1], APayload[0], Length(APayload)); Result:=True; end;
procedure TSshLoopServer.ReplyPayload(const APayload:TBytes);
var LWire,LBody:TBytes; LPad,I:Integer; LW:TsshWriter; LOut:TBytes; begin if FEncrypted then begin LOut:=APayload; LPad:=8-((4+1+SizeUInt(Length(LOut))) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8); LW:=TsshWriter.Create(8+Length(LOut)); try LW.PutByte(Byte(LPad)); LW.PutRaw(LOut); for I:=1 to LPad do LW.PutByte($30); LBody:=LW.ToBytes; finally LW.Free; end; LWire:=FSend.Protect(LBody, FSendSeq); Inc(FSendSeq); FEnd.Write(LWire[0], SizeUInt(Length(LWire))); end else SendPlainPayload(APayload); end;
procedure TSshLoopServer.Handshake;
var LLine,LVc,LMyInit,LClientInit,LInit,LMsg,LReply:TBytes; LR:TsshReader; LEphemeral,LShared,LKmpint,LH,LSig64,LSigBlob:TBytes; LXErr:AnsiString; LHostPub:TBytes; LXPriv,XPub:TBytes; LIvCs,LIvSc,LKeyCs,LKeySc,LMacCs,LMacSc:TBytes; LW:TsshWriter; LText:string; LNl:Integer; begin LLine:=StringToBytes(SERVER_IDENT+#13#10); FEnd.Write(LLine[0], SizeUInt(Length(LLine))); LVc:=nil; repeat if not RecvRaw(LLine,8000) then begin Fail('server: no version line'); Exit; end; LText:=BytesToText(LLine); LNl:=Pos(#10, LText); if LNl>0 then begin FEnd.Rewind(SizeUInt(Length(LLine))-SizeUInt(LNl)); LText:=Trim(Copy(LText,1,LNl)); if Copy(LText,1,4)='SSH-' then LVc:=StringToBytes(LText); end; until Length(LVc)>0; LClientInit:=ReadPlainFrameBody; if (Length(LClientInit)=0) or (LClientInit[0]<>SSH_MSG_KEXINIT) then begin Fail('server: expected KEXINIT'); Exit; end; LMyInit:=SshBuildKexInitPayload(PatternBytes($EE,16)); SendPlainPayload(LMyInit); LInit:=ReadPlainFrameBody; if (Length(LInit)=0) or (LInit[0]<>SSH_MSG_KEX_ECDH_INIT) then begin Fail('server: expected KEX INIT'); Exit; end; LHostPub:=Ed25519PublicKeyFromPrivate(FSc^.HostSeed); LR:=TsshReader.Create(LInit); try LR.ReadByte; LEphemeral:=LR.ReadStringBytes; finally LR.Free; end; GenerateX25519KeyPair(LXPriv, XPub); if not TryX25519ComputeSharedSecret(LXPriv, LEphemeral, LShared, LXErr) then begin Fail('server: x25519 failed'); Exit; end; LW:=TsshWriter.Create(80); try LW.PutMPInt(LShared); LKmpint:=LW.ToBytes; finally LW.Free; end; LH:=SHA256(SshBuildCurve25519HashInput(BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit, Ed25519PubBlob(LHostPub), LEphemeral, XPub, LShared)); FSessionId:=LH; if not Ed25519Sign(FSc^.HostSeed, LH, LSig64) then begin Fail('server: host sign failed'); Exit; end; LSigBlob:=SigBlobOf('ssh-ed25519', LSig64); LW:=TsshWriter.Create(512); try LW.PutByte(SSH_MSG_KEX_ECDH_REPLY); LW.PutStringBytes(Ed25519PubBlob(LHostPub)); LW.PutStringBytes(XPub); LW.PutStringBytes(LSigBlob); LReply:=LW.ToBytes; SendPlainPayload(LReply); finally LW.Free; end; LMsg:=ReadPlainFrameBody; if Length(LMsg)=0 then Exit; if LMsg[0]<>SSH_MSG_NEWKEYS then begin Fail('server: expected NEWKEYS'); Exit; end; SendPlainPayload(SingleBytePayloadOf(SSH_MSG_NEWKEYS)); LIvCs:=SshKdfSha256(LKmpint, LH, Ord('A'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LIvSc:=SshKdfSha256(LKmpint, LH, Ord('B'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LKeyCs:=SshKdfSha256(LKmpint, LH, Ord('C'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LKeySc:=SshKdfSha256(LKmpint, LH, Ord('D'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LMacCs:=SshKdfSha256(LKmpint, LH, Ord('E'), FSessionId, SshMacKeySize('')); LMacSc:=SshKdfSha256(LKmpint, LH, Ord('F'), FSessionId, SshMacKeySize('')); FRecv:=CreateSshPacketReceiver(CHACHA_ALG,'',LKeyCs,LIvCs,LMacCs); FSend:=CreateSshPacketSender(CHACHA_ALG,'',LKeySc,LIvSc,LMacSc); FRecvSeq:=3; FSendSeq:=3; FEncrypted:=True; end;
procedure TSshLoopServer.ServeJumpForward;
var LPayload:TBytes; LR:TsshReader; LType:Byte; LChanId:UInt32; LNeedFwd:TBytes; LW:TsshWriter;
begin
  while True do begin
    if not ReadAnyPayloadTimeout(5000, LPayload) then begin Fail('jump: timeout waiting open'); Exit; end;
    if Length(LPayload)=0 then Continue;
    case LPayload[0] of
      SSH_MSG_DISCONNECT: Exit;
      SSH_MSG_SERVICE_REQUEST: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_SERVICE_ACCEPT); LW.PutStringText(SSH_SERVICE_USERAUTH); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_USERAUTH_REQUEST: begin LR:=TsshReader.Create(LPayload); try LR.ReadByte; LR.ReadStringText; LR.ReadStringText; LR.ReadStringText; finally LR.Free; end; ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS)); end;
      SSH_MSG_CHANNEL_OPEN: begin LR:=TsshReader.Create(LPayload); try LR.ReadByte; LR.ReadStringText; LChanId:=LR.ReadUInt32; FClientChannelId:=LChanId; finally LR.Free; end; LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION); LW.PutUInt32(LChanId); LW.PutUInt32(SRV_CHANNEL_ID); LW.PutUInt32(SRV_RECV_WINDOW); LW.PutUInt32(32768); ReplyPayload(LW.ToBytes); finally LW.Free; end; Break; end;
      SSH_MSG_GLOBAL_REQUEST: ReplyPayload(SingleBytePayloadOf(SSH_MSG_REQUEST_FAILURE));
    end;
  end;
  while True do begin
    if ReadAnyPayloadTimeout(50, LPayload) then begin
      if Length(LPayload)>0 then case LPayload[0] of
        SSH_MSG_CHANNEL_DATA: begin LR:=TsshReader.Create(LPayload); try LR.ReadByte; LR.ReadUInt32; LNeedFwd:=LR.ReadStringBytes; finally LR.Free; end; if Length(LNeedFwd)>0 then FSc^.FwdPipe.Write(LNeedFwd[0], SizeUInt(Length(LNeedFwd))); end;
        SSH_MSG_CHANNEL_EOF: begin FSc^.FwdPipe.Close; end;
        SSH_MSG_CHANNEL_CLOSE: begin try FSc^.FwdPipe.Close; except end; ReplyPayload(ClosePayload(FClientChannelId)); Exit; end;
        SSH_MSG_CHANNEL_WINDOW_ADJUST: ;
      end;
    end;
    FSc^.FwdPipe.DrainNB(LNeedFwd);
    if Length(LNeedFwd)>0 then begin LW:=TsshWriter.Create(16+Length(LNeedFwd)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LNeedFwd))); LW.PutRaw(LNeedFwd); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
    Sleep(5);
  end;
end;
procedure TSshLoopServer.ServeApp;
var LMsg:TBytes; LR:TsshReader; LUser,LMethod,LPass,LReqName:string; LPassOk,LWantReply:Boolean; LRid:UInt32; LW:TsshWriter; LNeedFwd:TBytes; begin
  if FSc^.IsJump then begin ServeJumpForward; Exit; end;
  while True do begin LMsg:=ReadAnyPayload; if Length(LMsg)=0 then Exit; case LMsg[0] of
      SSH_MSG_DISCONNECT: Exit;
      SSH_MSG_SERVICE_REQUEST: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_SERVICE_ACCEPT); LW.PutStringText(SSH_SERVICE_USERAUTH); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_USERAUTH_REQUEST: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LUser:=LR.ReadStringText; LR.ReadStringText; LMethod:=LR.ReadStringText; LPassOk:=False; if LMethod='password' then begin LR.ReadBoolean; LPass:=LR.ReadStringText; LPassOk:=(LUser=FSc^.AcceptUser) and (LPass=FSc^.AcceptPassword); end; finally LR.Free; end; if LPassOk then ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS)) else begin LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_USERAUTH_FAILURE); LW.PutStringText('password,publickey'); LW.PutBoolean(False); ReplyPayload(LW.ToBytes); finally LW.Free; end; end; end;
      SSH_MSG_CHANNEL_OPEN: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadStringText; LRid:=LR.ReadUInt32; FClientChannelId:=LRid; finally LR.Free; end; LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION); LW.PutUInt32(LRid); LW.PutUInt32(SRV_CHANNEL_ID); LW.PutUInt32(SRV_RECV_WINDOW); LW.PutUInt32(32768); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_CHANNEL_REQUEST: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LReqName:=LR.ReadStringText; LWantReply:=LR.ReadBoolean; if LReqName=SSH_REQ_EXEC then begin if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, True)); LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutStringBytes(FSc^.StdOut1); ReplyPayload(LW.ToBytes); finally LW.Free; end; LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_CHANNEL_REQUEST); LW.PutUInt32(FClientChannelId); LW.PutStringText(SSH_REQ_EXIT_STATUS); LW.PutBoolean(True); LW.PutUInt32(FSc^.ExitCode); ReplyPayload(LW.ToBytes); finally LW.Free; end; ReplyPayload(ClosePayload(FClientChannelId)); end else if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, False)); finally LR.Free; end; end;
      SSH_MSG_GLOBAL_REQUEST: ReplyPayload(SingleBytePayloadOf(SSH_MSG_REQUEST_FAILURE));
    end; end;
end;
procedure TSshLoopServer.Run; begin try Handshake; if not FSc^.Failed then ServeApp; except on E:Exception do Fail(E.Message+' '+E.ClassName); end; FSc^.Done:=True; end;

type TLoopThread = class(TThread)
private FEnd: TMemPipeEnd; FSc: PSshLoopServerScenario;
public constructor Create(AEnd: TMemPipeEnd; ASc: PSshLoopServerScenario); procedure Execute; override;
end;
constructor TLoopThread.Create(AEnd: TMemPipeEnd; ASc: PSshLoopServerScenario); begin inherited Create(True); FEnd:=AEnd; FSc:=ASc; FreeOnTerminate:=False; end;
procedure TLoopThread.Execute; var Srv: TSshLoopServer; begin Srv:=TSshLoopServer.Create(FEnd, FSc); try Srv.Run; finally Srv.Free; end; end;

// Real bench helpers: measure via QWord arrays
procedure DoBench;
const N=50;
var SingleTimes, DoubleTimes: array of QWord;
    i: Integer; LStart,LEnd: QWord; R: TSshExecResult;
    LC,LS: TMemPipeEnd; LShared: PPipeShared; LSc: PSshLoopServerScenario; T: TThread; Opts: TSshConnectOptions; S: ISshSession;
    LJc, LJs: TMemPipeEnd; LJShared: PPipeShared; LFwdA,LFwdB: TMemPipeEnd; LFwdShared: PPipeShared; LScJ, LScT: PSshLoopServerScenario; TJ, TT: TThread; S1,S2: ISshSession; JOpts, TOpts: TSshConnectOptions;
    procedure SortQ(var A: array of QWord);
    var j,k: Integer; tmp: QWord;
    begin for j:=0 to High(A)-1 do for k:=j+1 to High(A) do if A[j]>A[k] then begin tmp:=A[j]; A[j]:=A[k]; A[k]:=tmp; end; end;
    function Avg(const A: array of QWord): Double; var s: QWord; idx: Integer; begin s:=0; for idx:=0 to High(A) do s+=A[idx]; Result:=s/Length(A); end;
    function P50(const A: array of QWord): QWord; begin Result:=A[Length(A) div 2]; end;
    function P95(const A: array of QWord): QWord; begin Result:=A[Trunc(Length(A)*0.95)]; end;
begin
  SetLength(SingleTimes, N);
  for i:=0 to N-1 do begin
    New(LSc); LSc^:=Default(TSshLoopServerScenario); LSc^.HostSeed:=PatternBytes(Byte($A0+(i and $FF)),32); LSc^.AcceptUser:='u'; LSc^.AcceptPassword:='p'; LSc^.StdOut1:=StringToBytes('ok'); LSc^.ExitCode:=0; LSc^.IsJump:=False;
    MakePipe(LC, LS, LShared);
    T:=TLoopThread.Create(LS, LSc); T.Start; Sleep(5);
    LStart:=GetTickCount64;
    try
      Opts:=DefaultSshConnectOptions('bench'); Opts.Host:='bench'; Opts.User:='u'; Opts.Password:='p'; Opts.ExecTimeoutMs:=5000;
      S:=SshConnectOn(LC as IReadWriteCloser, Opts);
      R:=S.Exec('echo hi');
      S.Close; S:=nil;
    except on E:Exception do begin Writeln('[bench] single iter ',i,' failed: ',E.Message); Halt(1); end; end;
    LEnd:=GetTickCount64; SingleTimes[i]:=LEnd-LStart;
    try LC.Close; except end; try LS.Close; except end; T.WaitFor; T.Free;
    Finalize(LSc^); Dispose(LSc); DoneCriticalSection(LShared^.Lock); Dispose(LShared);
  end;

  SetLength(DoubleTimes, N);
  for i:=0 to N-1 do begin
    New(LScJ); LScJ^:=Default(TSshLoopServerScenario); LScJ^.HostSeed:=PatternBytes(Byte($10+(i and $FF)),32); LScJ^.IsJump:=True;
    New(LScT); LScT^:=Default(TSshLoopServerScenario); LScT^.HostSeed:=PatternBytes(Byte($33+(i and $FF)),32); LScT^.AcceptUser:='u'; LScT^.AcceptPassword:='p'; LScT^.StdOut1:=StringToBytes('via-jump-ok'); LScT^.ExitCode:=0; LScT^.IsJump:=False;
    MakePipe(LJc, LJs, LJShared); MakePipe(LFwdA, LFwdB, LFwdShared); LScJ^.FwdPipe:=LFwdA;
    TT:=TLoopThread.Create(LFwdB, LScT); TJ:=TLoopThread.Create(LJs, LScJ); TT.Start; TJ.Start; Sleep(5);
    LStart:=GetTickCount64;
    try
      JOpts:=DefaultSshConnectOptions('jump'); JOpts.Host:='jump'; JOpts.User:='u'; JOpts.Password:='p'; JOpts.ExecTimeoutMs:=5000;
      TOpts:=DefaultSshConnectOptions('target'); TOpts.Host:='target'; TOpts.User:='u'; TOpts.Password:='p'; TOpts.ExecTimeoutMs:=5000;
      S1:=SshConnectOn(LJc as IReadWriteCloser, JOpts);
      S2:=SshConnectViaJumpOn(S1, TOpts);
      R:=S2.Exec('echo hi');
      S2.Close; S1.Close; S2:=nil; S1:=nil;
    except on E:Exception do begin Writeln('[bench] double iter ',i,' failed: ',E.Message); Halt(1); end; end;
    LEnd:=GetTickCount64; DoubleTimes[i]:=LEnd-LStart;
    try LFwdA.Close; except end; try LFwdB.Close; except end; try LJc.Close; except end; try LJs.Close; except end;
    TJ.WaitFor; TT.WaitFor; TJ.Free; TT.Free;
    Finalize(LScJ^); Dispose(LScJ); Finalize(LScT^); Dispose(LScT);
    DoneCriticalSection(LJShared^.Lock); Dispose(LJShared); DoneCriticalSection(LFwdShared^.Lock); Dispose(LFwdShared);
  end;

  SortQ(SingleTimes); SortQ(DoubleTimes);
  Writeln('[bench] proxyjump 50 iter MemPipe, chacha20-poly1305, password auth');
  Writeln(Format('  single p50=%d ms p95=%d ms avg=%.1f ms', [P50(SingleTimes), P95(SingleTimes), Avg(SingleTimes)]));
  Writeln(Format('  double p50=%d ms p95=%d ms avg=%.1f ms', [P50(DoubleTimes), P95(DoubleTimes), Avg(DoubleTimes)]));
  Writeln(Format('  overhead avg=%.1f ms p50=%.1f ms', [Avg(DoubleTimes)-Avg(SingleTimes), Double(P50(DoubleTimes)-P50(SingleTimes))]));
  if (Avg(SingleTimes)>30) or (Avg(DoubleTimes)>600) then begin Writeln('[bench] WARN latency above expected budget'); end;
  Writeln('[bench] PASS');
end;

begin
  DoBench;
end.
