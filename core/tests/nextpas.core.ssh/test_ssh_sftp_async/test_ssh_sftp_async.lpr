program test_ssh_sftp_async;

{$I nextpas.core.settings.inc}

{ S17 gate: async SFTP via TAsyncLoop + loopback TCP.
  Reuses nextpas.core.bytes.ops,
  session_asyc's loopback host key/kex/cipher, server adds
  subsystem sftp handling (INIT/VERSION + FXP_* dispatch).
  Covers RealPath/Stat/ListDir/ReadFile/WriteFile/Remove lifecycle + status mapping. }

uses
  cthreads,
  Classes, SysUtils,
  nextpas.core.system.sysutils,
  nextpas.core.bytes.ops,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.tcp,
  nextpas.core.async.loop,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.sftp,
  nextpas.core.ssh.sftp.async,
  nextpas.core.ssh.session.async,
  nextpas.core.ssh.transport.async,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.random,
  nextpas.core.ssh.compress,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.test;

function StringToBytes(const AText: string): TBytes;
begin Result:=nil; SetLength(Result, Length(AText)); if Length(AText)>0 then Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText))); end;
function BytesToText(const AData: TBytes): string;
begin Result:=''; SetLength(Result, Length(AData)); if Length(AData)>0 then Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData))); end;
function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin Result:=nil; SetLength(Result, ACount); if ACount>0 then FillChar(Result[0], SizeUInt(ACount), APattern); end;
function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes;
var LW: TsshWriter; begin LW:=TsshWriter.Create(128); try LW.PutStringText(AAlgName); LW.PutStringBytes(ARawSig); Result:=LW.ToBytes; finally LW.Free; end; end;
function SingleBytePayloadOf(AMsg: Byte): TBytes; begin Result:=nil; SetLength(Result,1); Result[0]:=AMsg; end;
function Ed25519PubBlob(const APub: TBytes): TBytes;
var LW: TsshWriter; begin LW:=TsshWriter.Create(64); try LW.PutStringText('ssh-ed25519'); LW.PutStringBytes(APub); Result:=LW.ToBytes; finally LW.Free; end; end;
function RespPkt(AType: Byte; AId: UInt32; const ATail: TBytes): TBytes;
var LW: TsshWriter; begin LW:=TsshWriter.Create(8+Length(ATail)); try LW.PutByte(AType); LW.PutUInt32(AId); LW.PutRaw(ATail); Result:=LW.ToBytes; finally LW.Free; end; end;
function StatusPkt(AId: UInt32; ACode: UInt32; const AMsg: string): TBytes;
var LW: TsshWriter; begin LW:=TsshWriter.Create(32); try LW.PutUInt32(ACode); LW.PutStringText(AMsg); LW.PutStringText('en'); Result:=RespPkt(SSH_FXP_STATUS, AId, LW.ToBytes); finally LW.Free; end; end;
function AttrsWithSizeAndPerms(ASize: UInt64; APerms: UInt32): TSftpAttrs;
begin Result:=Default(TSftpAttrs); Result.Flags:=SSH_FILEXFER_ATTR_SIZE or SSH_FILEXFER_ATTR_PERMISSIONS; Result.Size:=ASize; Result.Permissions:=APerms; end;

const CHACHA_ALG='chacha20-poly1305@openssh.com'; SERVER_IDENT='SSH-2.0-NextPas-LoopServer'; SRV_CHANNEL_ID=7; SRV_RECV_WINDOW=2097152;

type PSshLoopSftpScenario=^TSshLoopSftpScenario;
  TSshLoopSftpScenario=record HostSeed:TBytes; Done:Boolean; Failed:Boolean; FailMsg:string; FileData:TBytes; FileName:string; end;

  TAsyncLoopThread = class(TThread)
  private FLoop: TAsyncLoop;
  protected procedure Execute; override;
  public constructor Create(ALoop: TAsyncLoop);
  end;

  TAsyncSftpServerThread = class(TThread)
  private FListener: ITcpListener; FSc: PSshLoopSftpScenario;
  protected procedure Execute; override;
  public constructor Create(AListener: ITcpListener; ASc: PSshLoopSftpScenario);
  end;

  TSshLoopSftpServer=class
  private
    FStream:IReadWriteCloser; FSc:PSshLoopSftpScenario;
    FClientChannelId:UInt32; FRecvSeq,FSendSeq:UInt32; FRecv:ISshPacketReceiver; FSend:ISshPacketSender;
    FEncrypted:Boolean; FSessionId:TBytes; FBuf:TBytes;
    FSftpHandle:TBytes; FSftpHandles:array of TBytes; FSftpDirPos:Integer;
    procedure Fail(const AMsg:string);
    procedure SendPlainPayload(const APayload:TBytes);
    function RecvRaw(out AData:TBytes; ATimeoutMs:Integer):Boolean;
    function ReadPlainFrameBody:TBytes;
    function ReadAnyPayload:TBytes;
    procedure ReplyPayload(const APayload:TBytes);
    procedure Handshake;
    procedure ServeApp;
    procedure HandleSftpPacket(const APkt:TBytes);
    procedure SendSftpReply(const APkt:TBytes);
  public constructor Create(AStream:IReadWriteCloser; ASc:PSshLoopSftpScenario); procedure Run; end;

constructor TAsyncLoopThread.Create(ALoop: TAsyncLoop); begin inherited Create(True); FreeOnTerminate:=False; FLoop:=ALoop; end;
procedure TAsyncLoopThread.Execute; begin FLoop.Run; end;

constructor TAsyncSftpServerThread.Create(AListener: ITcpListener; ASc: PSshLoopSftpScenario);
begin inherited Create(True); FreeOnTerminate:=False; FListener:=AListener; FSc:=ASc; end;
procedure TAsyncSftpServerThread.Execute;
var LConn: ITcpStream; Srv: TSshLoopSftpServer;
begin
  try
    LConn:=FListener.Accept;
    Srv:=TSshLoopSftpServer.Create(LConn as IReadWriteCloser, FSc);
    try Srv.Run; finally Srv.Free; end;
  except end;
end;

constructor TSshLoopSftpServer.Create(AStream:IReadWriteCloser; ASc:PSshLoopSftpScenario); begin inherited Create; FStream:=AStream; FSc:=ASc; FEncrypted:=False; SetLength(FBuf,0); FSftpHandle:=BytesOf('hdl1'); end;
procedure TSshLoopSftpServer.Fail(const AMsg:string); begin if not FSc^.Failed then begin FSc^.Failed:=True; FSc^.FailMsg:=AMsg; end; end;
procedure TSshLoopSftpServer.SendPlainPayload(const APayload:TBytes);
var LW:TsshWriter; LPad,I:Integer; LWire:TBytes; begin LPad:=8-((4+1+Length(APayload)) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8); LW:=TsshWriter.Create(64+Length(APayload)); try LW.PutUInt32(UInt32(1+Length(APayload)+SizeUInt(LPad))); LW.PutByte(Byte(LPad)); LW.PutRaw(APayload); for I:=1 to LPad do LW.PutByte($30); LWire:=LW.ToBytes; FStream.Write(LWire[0], SizeUInt(Length(LWire))); finally LW.Free; end; end;
function TSshLoopSftpServer.RecvRaw(out AData:TBytes; ATimeoutMs:Integer):Boolean;
var LChunk:array[0..4095] of Byte; LGot:SizeUInt; LDeadline:TDeadline; begin AData:=nil; if Length(FBuf)>0 then begin AData:=FBuf; FBuf:=nil; Exit(True); end; LDeadline:=TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)); if FStream is ITcpStream then (FStream as ITcpStream).SetReadDeadline(LDeadline); try LGot:=FStream.Read(LChunk[0], SizeUInt(Length(LChunk))); if LGot=0 then Exit(False); SetLength(AData, LGot); Move(LChunk[0], AData[0], LGot); Result:=True; finally if FStream is ITcpStream then (FStream as ITcpStream).SetReadDeadline(TDeadline.Infinite); end; end;
function TSshLoopSftpServer.ReadPlainFrameBody:TBytes;
var LWire,LMore:TBytes; LLen,LPadLen:UInt32; begin Result:=nil; if not RecvRaw(LWire,8000) then Exit; while Length(LWire)<4 do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LWire,LMore); end; LLen:=(UInt32(LWire[0]) shl 24) or (UInt32(LWire[1]) shl 16) or (UInt32(LWire[2]) shl 8) or UInt32(LWire[3]); while SizeUInt(Length(LWire))<4+LLen do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LWire,LMore); end; if SizeUInt(Length(LWire))>4+LLen then begin FBuf:=Copy(LWire,4+Integer(LLen), Length(LWire)-4-Integer(LLen)); SetLength(LWire,4+Integer(LLen)); end; LPadLen:=LWire[4]; SetLength(Result, LLen-1-LPadLen); if Length(Result)>0 then Move(LWire[5], Result[0], Length(Result)); end;
function TSshLoopSftpServer.ReadAnyPayload:TBytes;
var LBuf,LHeader,LTrailer,LPacket,LBody:TBytes; LBodyLen:UInt32; LPadLen:Byte; LMore:TBytes; begin Result:=nil; if not FEncrypted then begin Result:=ReadPlainFrameBody; Exit; end; if Length(FBuf)>=4 then begin LHeader:=Copy(FBuf,0,4); FBuf:=Copy(FBuf,4,Length(FBuf)-4); end else begin if not RecvRaw(LBuf,8000) then Exit; LHeader:=LBuf; if Length(FBuf)>0 then begin LHeader:=BytesConcat(FBuf,LHeader); FBuf:=nil; end; while Length(LHeader)<4 do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LHeader,LMore); end; if Length(LHeader)>4 then begin FBuf:=Copy(LHeader,4,Length(LHeader)-4); LHeader:=Copy(LHeader,0,4); end; end; LBodyLen:=FRecv.BodyLengthFromHeader(FRecvSeq, LHeader); SetLength(LTrailer, FRecv.TrailerSize(LBodyLen)); LBuf:=nil; if Length(FBuf)>0 then begin LBuf:=FBuf; FBuf:=nil; end; while SizeUInt(Length(LBuf))<SizeUInt(Length(LTrailer)) do begin if not RecvRaw(LMore,8000) then Exit; BytesAppend(LBuf,LMore); end; if SizeUInt(Length(LBuf))>SizeUInt(Length(LTrailer)) then begin FBuf:=Copy(LBuf, Length(LTrailer), Length(LBuf)-Length(LTrailer)); SetLength(LBuf, Length(LTrailer)); end; LTrailer:=LBuf; SetLength(LPacket,4+Length(LTrailer)); Move(LHeader[0], LPacket[0],4); if Length(LTrailer)>0 then Move(LTrailer[0], LPacket[4], SizeUInt(Length(LTrailer))); LBody:=FRecv.Unprotect(FRecvSeq, LPacket); Inc(FRecvSeq); if Length(LBody)<1 then Exit; LPadLen:=LBody[0]; if UInt32(LPadLen)>=LBodyLen then Exit; SetLength(Result, LBodyLen-1-LPadLen); if Length(Result)>0 then Move(LBody[1], Result[0], Length(Result)); end;
procedure TSshLoopSftpServer.ReplyPayload(const APayload:TBytes);
var LWire,LBody:TBytes; LPad,I:Integer; LW:TsshWriter; LOut:TBytes; begin if FEncrypted then begin LOut:=APayload; LPad:=8-((4+1+SizeUInt(Length(LOut))) mod 8); if LPad<SSH_MIN_PADDING then Inc(LPad,8); LW:=TsshWriter.Create(8+Length(LOut)); try LW.PutByte(Byte(LPad)); LW.PutRaw(LOut); for I:=1 to LPad do LW.PutByte($30); LBody:=LW.ToBytes; finally LW.Free; end; LWire:=FSend.Protect(LBody, FSendSeq); Inc(FSendSeq); FStream.Write(LWire[0], SizeUInt(Length(LWire))); end else SendPlainPayload(APayload); end;
procedure TSshLoopSftpServer.SendSftpReply(const APkt:TBytes);
var LW:TsshWriter; LOuter:TBytes; begin LW:=TsshWriter.Create(4+Length(APkt)); try LW.PutUInt32(UInt32(Length(APkt))); LW.PutRaw(APkt); LOuter:=LW.ToBytes; finally LW.Free; end; LW:=TsshWriter.Create(16+Length(LOuter)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LOuter))); LW.PutRaw(LOuter); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
procedure TSshLoopSftpServer.HandleSftpPacket(const APkt:TBytes);
var LR:TsshReader; LType:Byte; LId:UInt32; LPath,LOld, LNew:string; LHandle:TBytes; LOff:UInt64; LLen:UInt32; LW:TsshWriter; LStatus, LDataPkt:TBytes;
begin
  if Length(APkt)<5 then Exit;
  LR:=TsshReader.Create(APkt);
  try
    LType:=LR.ReadByte; LId:=LR.ReadUInt32;
    if LType=SSH_FXP_INIT then begin LW:=TsshWriter.Create(8); try LW.PutByte(SSH_FXP_VERSION); LW.PutUInt32(3); LStatus:=LW.ToBytes; finally LW.Free; end; SendSftpReply(LStatus); Exit; end;
  finally LR.Free; end;
  // Re-parse correctly without nesting confusion: do separate
  LR:=TsshReader.Create(APkt);
  try
    LType:=LR.ReadByte; LId:=LR.ReadUInt32;
    case LType of
      SSH_FXP_INIT: ; // already handled
      SSH_FXP_REALPATH:
        begin
          LPath:=LR.ReadStringText;
          LW:=TsshWriter.Create(64); try LW.PutByte(SSH_FXP_NAME); LW.PutUInt32(LId); LW.PutUInt32(1); LW.PutStringText('/resolved'+LPath); LW.PutStringText('drwxr-xr-x'); PutAttrs(LW, Default(TSftpAttrs)); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        end;
      SSH_FXP_STAT, SSH_FXP_LSTAT:
        begin
          LPath:=LR.ReadStringText;
          if Pos('notfound', LPath)>0 then begin
            LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_NO_SUCH_FILE); LW.PutStringText('not found'); LW.PutStringText('en'); LStatus:=LW.ToBytes; finally LW.Free; end;
            LW:=TsshWriter.Create(4+Length(LStatus)); try LW.PutUInt32(UInt32(Length(LStatus))); LW.PutRaw(LStatus); LStatus:=LW.ToBytes; finally LW.Free; end;
            LW:=TsshWriter.Create(16+Length(LStatus)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LStatus))); LW.PutRaw(LStatus); ReplyPayload(LW.ToBytes); finally LW.Free; end;
          end else begin
            LW:=TsshWriter.Create(64); try LW.PutByte(SSH_FXP_ATTRS); LW.PutUInt32(LId); PutAttrs(LW, AttrsWithSizeAndPerms(1234, $81A4)); LDataPkt:=LW.ToBytes; finally LW.Free; end;
            LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
            LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
          end;
        end;
      SSH_FXP_OPENDIR:
        begin
          LR.ReadStringText; // path
          LW:=TsshWriter.Create(16); try LW.PutByte(SSH_FXP_HANDLE); LW.PutUInt32(LId); LW.PutStringBytes(FSftpHandle); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
          FSftpDirPos:=0;
        end;
      SSH_FXP_READDIR:
        begin
          LHandle:=LR.ReadStringBytes;
          if FSftpDirPos=0 then begin
            LW:=TsshWriter.Create(128); try LW.PutByte(SSH_FXP_NAME); LW.PutUInt32(LId); LW.PutUInt32(2); LW.PutStringText('a.txt'); LW.PutStringText('-rw'); PutAttrs(LW, AttrsWithSizeAndPerms(10,$81A4)); LW.PutStringText('sub'); LW.PutStringText('drwx'); PutAttrs(LW, AttrsWithSizeAndPerms(4096,$41ED)); LDataPkt:=LW.ToBytes; finally LW.Free; end;
            Inc(FSftpDirPos);
          end else begin
            LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_EOF); LW.PutStringText(''); LW.PutStringText('en'); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        end;
      SSH_FXP_OPEN:
        begin
          LPath:=LR.ReadStringText; LR.ReadUInt32; // pflags
          // consume attrs
          try ReadAttrs(LR); except end;
          LW:=TsshWriter.Create(16); try LW.PutByte(SSH_FXP_HANDLE); LW.PutUInt32(LId); LW.PutStringBytes(FSftpHandle); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        end;
      SSH_FXP_READ:
        begin
          LHandle:=LR.ReadStringBytes; LOff:=LR.ReadUInt64; LLen:=LR.ReadUInt32;
          if LOff=0 then begin
            LW:=TsshWriter.Create(16+Length(FSc^.FileData)); try LW.PutByte(SSH_FXP_DATA); LW.PutUInt32(LId); LW.PutStringBytes(FSc^.FileData); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          end else begin
            LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_EOF); LW.PutStringText(''); LW.PutStringText('en'); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        end;
      SSH_FXP_WRITE, SSH_FXP_CLOSE, SSH_FXP_REMOVE, SSH_FXP_MKDIR, SSH_FXP_RMDIR, SSH_FXP_RENAME:
        begin
          // consume remaining payload as needed
          LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_OK); LW.PutStringText(''); LW.PutStringText('en'); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(4+Length(LDataPkt)); try LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); LDataPkt:=LW.ToBytes; finally LW.Free; end;
          LW:=TsshWriter.Create(16+Length(LDataPkt)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LDataPkt))); LW.PutRaw(LDataPkt); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        end;
    end;
  finally LR.Free; end;
end;

procedure TSshLoopSftpServer.Handshake;
var LLine,LVc,LMyInit,LClientInit,LInit,LMsg,LReply:TBytes; LR:TsshReader; LEphemeral,LShared,LKmpint,LH,LSig64,LSigBlob:TBytes; LXErr:AnsiString; LHostPub:TBytes; LXPriv,XPub:TBytes; LIvCs,LIvSc,LKeyCs,LKeySc,LMacCs,LMacSc:TBytes; LW:TsshWriter; LText:string; LNl:Integer;
begin
  LLine:=StringToBytes(SERVER_IDENT+#13#10); FStream.Write(LLine[0], SizeUInt(Length(LLine))); LVc:=nil;
  repeat if not RecvRaw(LLine,8000) then begin Fail('no version'); Exit; end; LText:=BytesToText(LLine); LNl:=Pos(#10, LText); if LNl>0 then begin if SizeUInt(Length(LLine))>SizeUInt(LNl) then FBuf:=BytesConcat(Copy(LLine,LNl,Length(LLine)-LNl), FBuf); LText:=Trim(Copy(LText,1,LNl)); if Copy(LText,1,4)='SSH-' then LVc:=StringToBytes(LText); end; until Length(LVc)>0;
  LClientInit:=ReadPlainFrameBody; if (Length(LClientInit)=0) or (LClientInit[0]<>SSH_MSG_KEXINIT) then begin Fail('expected KEXINIT'); Exit; end;
  LMyInit:=SshBuildKexInitPayload(PatternBytes($EE,16)); SendPlainPayload(LMyInit);
  LInit:=ReadPlainFrameBody; if (Length(LInit)=0) or (LInit[0]<>SSH_MSG_KEX_ECDH_INIT) then begin Fail('expected KEX INIT'); Exit; end;
  LHostPub:=Ed25519PublicKeyFromPrivate(FSc^.HostSeed); LR:=TsshReader.Create(LInit); try LR.ReadByte; LEphemeral:=LR.ReadStringBytes; finally LR.Free; end; GenerateX25519KeyPair(LXPriv, XPub); if not TryX25519ComputeSharedSecret(LXPriv, LEphemeral, LShared, LXErr) then begin Fail('x25519'); Exit; end;
  LW:=TsshWriter.Create(80); try LW.PutMPInt(LShared); LKmpint:=LW.ToBytes; finally LW.Free; end;
  LH:=SHA256(SshBuildCurve25519HashInput(BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit, Ed25519PubBlob(LHostPub), LEphemeral, XPub, LShared));
  FSessionId:=LH; if not Ed25519Sign(FSc^.HostSeed, LH, LSig64) then begin Fail('host sign'); Exit; end; LSigBlob:=SigBlobOf('ssh-ed25519', LSig64);
  LW:=TsshWriter.Create(512); try LW.PutByte(SSH_MSG_KEX_ECDH_REPLY); LW.PutStringBytes(Ed25519PubBlob(LHostPub)); LW.PutStringBytes(XPub); LW.PutStringBytes(LSigBlob); LReply:=LW.ToBytes; SendPlainPayload(LReply); finally LW.Free; end;
  LMsg:=ReadPlainFrameBody; if Length(LMsg)=0 then Exit; if LMsg[0]<>SSH_MSG_NEWKEYS then begin Fail('expected NEWKEYS'); Exit; end; SendPlainPayload(SingleBytePayloadOf(SSH_MSG_NEWKEYS));
  LIvCs:=SshKdfSha256(LKmpint, LH, Ord('A'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LIvSc:=SshKdfSha256(LKmpint, LH, Ord('B'), FSessionId, SshCipherIvSize(CHACHA_ALG)); LKeyCs:=SshKdfSha256(LKmpint, LH, Ord('C'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LKeySc:=SshKdfSha256(LKmpint, LH, Ord('D'), FSessionId, SshCipherKeySize(CHACHA_ALG)); LMacCs:=SshKdfSha256(LKmpint, LH, Ord('E'), FSessionId, SshMacKeySize('')); LMacSc:=SshKdfSha256(LKmpint, LH, Ord('F'), FSessionId, SshMacKeySize(''));
  FRecv:=CreateSshPacketReceiver(CHACHA_ALG,'',LKeyCs, LIvCs, LMacCs); FSend:=CreateSshPacketSender(CHACHA_ALG,'',LKeySc, LIvSc, LMacSc); FRecvSeq:=3; FSendSeq:=3; FEncrypted:=True;
end;

procedure TSshLoopSftpServer.ServeApp;
var LMsg:TBytes; LR:TsshReader; LUser,LMethod,LPass,LReqName:string; LPassOk,LWantReply:Boolean; LRid:UInt32; LW:TsshWriter; LSftpBuf:TBytes; LChunk:TBytes; LLen2:UInt32; Pkt2:TBytes;
begin
  // auth & channel open
  while True do begin
    LMsg:=ReadAnyPayload; if Length(LMsg)=0 then Exit;
    case LMsg[0] of
      SSH_MSG_DISCONNECT: Exit;
      SSH_MSG_SERVICE_REQUEST: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_SERVICE_ACCEPT); LW.PutStringText(SSH_SERVICE_USERAUTH); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_USERAUTH_REQUEST: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LUser:=LR.ReadStringText; LR.ReadStringText; LMethod:=LR.ReadStringText; LPassOk:=False; if LMethod='password' then begin LR.ReadBoolean; LPass:=LR.ReadStringText; LPassOk:=(LPass='testpass'); end; finally LR.Free; end; if LPassOk then ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS)) else begin LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_USERAUTH_FAILURE); LW.PutStringText('password'); LW.PutBoolean(False); ReplyPayload(LW.ToBytes); finally LW.Free; end; end; end;
      SSH_MSG_CHANNEL_OPEN: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadStringText; LRid:=LR.ReadUInt32; FClientChannelId:=LRid; finally LR.Free; end; LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION); LW.PutUInt32(LRid); LW.PutUInt32(SRV_CHANNEL_ID); LW.PutUInt32(SRV_RECV_WINDOW); LW.PutUInt32(32768); ReplyPayload(LW.ToBytes); finally LW.Free; end; end;
      SSH_MSG_CHANNEL_REQUEST: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LReqName:=LR.ReadStringText; LWantReply:=LR.ReadBoolean; if LReqName=SSH_REQ_SUBSYSTEM then begin if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, True)) else; // wait for sftp init
      end else if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, False)); finally LR.Free; end; end;
      SSH_MSG_CHANNEL_DATA:
        begin
          // sftp data: extract inner and dispatch
          LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LChunk:=LR.ReadStringBytes; finally LR.Free; end;
          // LChunk is sftp outer stream: may contain multiple? For simplicity, assume one packet per channel data
          // but client sends one outer per data, so parse one
          if Length(LChunk)>=4 then begin
            LLen2:=(UInt32(LChunk[0]) shl 24) or (UInt32(LChunk[1]) shl 16) or (UInt32(LChunk[2]) shl 8) or UInt32(LChunk[3]);
            if SizeUInt(Length(LChunk))>=4+LLen2 then begin
              SetLength(Pkt2, LLen2); if LLen2>0 then Move(LChunk[4], Pkt2[0], LLen2);
              HandleSftpPacket(Pkt2);
            end;
          end;
        end;
      SSH_MSG_CHANNEL_CLOSE: Exit;
      SSH_MSG_CHANNEL_WINDOW_ADJUST, SSH_MSG_GLOBAL_REQUEST: ;
    end;
  end;
end;
procedure TSshLoopSftpServer.Run; begin try Handshake; if not FSc^.Failed then ServeApp; except on E:Exception do Fail(E.Message); end; FSc^.Done:=True; end;

type PAsyncSftpTestState=^TAsyncSftpTestState;
  TAsyncSftpTestState=record Session:ISshAsyncSession; Fs:ISshAsyncFileSystem; Err:ESSHError; FsErr:ESSHError; Done:Boolean; FsDone:Boolean; Event:PRTLEvent; PathResult:string; Attrs:TSftpAttrs; Dir:TSftpDirEntryArray; Data:TBytes; end;
var GState:TAsyncSftpTestState;

procedure OnConnect(ASession:ISshAsyncSession; AErr:ESSHError; AContext:Pointer); begin GState.Session:=ASession; GState.Err:=AErr; GState.Done:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnSftpOpen(AFs:ISshAsyncFileSystem; AErr:ESSHError; AContext:Pointer); begin GState.Fs:=AFs; GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnRealPath(const APath:string; AErr:ESSHError; AContext:Pointer); begin GState.PathResult:=APath; GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnStat(const AAttrs:TSftpAttrs; AErr:ESSHError; AContext:Pointer); begin GState.Attrs:=AAttrs; GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnDir(const AEntries:TSftpDirEntryArray; AErr:ESSHError; AContext:Pointer); begin GState.Dir:=AEntries; GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnData(const AData:TBytes; AErr:ESSHError; AContext:Pointer); begin GState.Data:=AData; GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
procedure OnVoid(AErr:ESSHError; AContext:Pointer); begin GState.FsErr:=AErr; GState.FsDone:=True; if GState.Event<>nil then RTLeventSetEvent(GState.Event); end;
function WaitForFlag(var ADone:Boolean; AEvent:PRTLEvent; ATimeoutMs:Integer):Boolean; var LStart:QWord; begin LStart:=GetTickCount64; while not ADone do begin if GetTickCount64-LStart>UInt64(ATimeoutMs) then Exit(False); RTLeventWaitFor(AEvent,20); end; Result:=True; end;

function RunSftpScenario(const AHostSeed:TBytes; const AOp:string; out APathRes:string; out AAttrs:TSftpAttrs; out ADir:TSftpDirEntryArray; out AData:TBytes; out AErrKind:TSshErrorKind):Boolean;
var LListener:ITcpListener; LPort:Word; LSc:PSshLoopSftpScenario; LServerThread:TThread; LLoop:TAsyncLoop; LLoopThread:TThread; LOpts:TSshConnectOptions;
begin
  Result:=False; AErrKind:=sekIO; APathRes:=''; AData:=nil; ADir:=nil;
  LServerThread:=nil; LLoop:=nil; LLoopThread:=nil; LListener:=nil;
  LOpts:=Default(TSshConnectOptions);
  New(LSc); LSc^:=Default(TSshLoopSftpScenario); LSc^.HostSeed:=AHostSeed; LSc^.FileData:=BytesOf('hello sftp async'); LSc^.FileName:='/tmp/test';
  LListener:=NetTcpListen('127.0.0.1',0);
  try
    LPort:=LListener.LocalAddr.Port;
    LServerThread:=TAsyncSftpServerThread.Create(LListener, LSc);
    LServerThread.Start;
    LLoop:=TAsyncLoop.Create(64);
    try
      if GState.Session<>nil then GState.Session:=nil; if GState.Err<>nil then FreeAndNil(GState.Err); if GState.FsErr<>nil then FreeAndNil(GState.FsErr); GState:=Default(TAsyncSftpTestState); GState.Event:=RTLEventCreate;
      try
        LLoopThread:=TAsyncLoopThread.Create(LLoop); LLoopThread.Start;
        LOpts:=DefaultSshConnectOptions('127.0.0.1'); LOpts.Host:='127.0.0.1'; LOpts.Port:=LPort; LOpts.User:='testuser'; LOpts.Password:='testpass'; LOpts.ExecTimeoutMs:=5000; LOpts.ConnectTimeoutMs:=3000;
        if not SshAsyncConnect(LLoop, LOpts, @OnConnect, nil) then begin GState.Err:=ESSHError.Create(sekIO,'dial submit failed'); GState.Done:=True; end;
        if not WaitForFlag(GState.Done, GState.Event, 15000) then begin AErrKind:=sekTimeout; Exit; end;
        if GState.Err<>nil then begin AErrKind:=GState.Err.Kind; FreeAndNil(GState.Err); Exit; end;
        if GState.Session=nil then Exit;
        GState.FsDone:=False; RTLeventResetEvent(GState.Event);
        if not SshAsyncOpenSftp(GState.Session, @OnSftpOpen, nil) then begin AErrKind:=sekIO; Exit; end;
        if not WaitForFlag(GState.FsDone, GState.Event, 15000) then begin AErrKind:=sekTimeout; Exit; end;
        if GState.FsErr<>nil then begin AErrKind:=GState.FsErr.Kind; FreeAndNil(GState.FsErr); Exit; end;
        if GState.Fs=nil then Exit;
        // dispatch op
        GState.FsDone:=False; RTLeventResetEvent(GState.Event); FreeAndNil(GState.FsErr);
        if AOp='realpath' then GState.Fs.RealPathAsync('/foo', @OnRealPath, nil)
        else if AOp='stat' then GState.Fs.StatAsync('/file', @OnStat, nil)
        else if AOp='stat-notfound' then GState.Fs.StatAsync('/notfound', @OnStat, nil)
        else if AOp='listdir' then GState.Fs.ListDirAsync('/dir', @OnDir, nil)
        else if AOp='read' then GState.Fs.ReadFileAsync('/tmp/test', @OnData, nil)
        else if AOp='write' then GState.Fs.WriteFileAsync('/tmp/out', BytesOf('payload'), @OnVoid, nil)
        else if AOp='remove' then GState.Fs.RemoveAsync('/tmp/x', @OnVoid, nil)
        else Exit;
        if not WaitForFlag(GState.FsDone, GState.Event, 15000) then begin AErrKind:=sekTimeout; Exit; end;
        if AOp='stat-notfound' then begin if GState.FsErr=nil then Exit; AErrKind:=GState.FsErr.Kind; FreeAndNil(GState.FsErr); // expect sftp error -> treat as not success but we still want to report kind
          Result:=False; Exit; end;
        if GState.FsErr<>nil then begin AErrKind:=GState.FsErr.Kind; FreeAndNil(GState.FsErr); Exit; end;
        APathRes:=GState.PathResult; AAttrs:=GState.Attrs; ADir:=GState.Dir; AData:=GState.Data; Result:=True;
        try GState.Fs.Close; except end;
        try GState.Session.Close; except end;
        Sleep(200);
      finally RTLeventDestroy(GState.Event); GState.Event:=nil; if Assigned(LLoop) then LLoop.Stop; if Assigned(LLoopThread) then begin LLoopThread.WaitFor; LLoopThread.Free; end; Sleep(50); end;
    finally if GState.Session<>nil then begin GState.Session.Close; GState.Session:=nil; end; if GState.Err<>nil then FreeAndNil(GState.Err); if GState.FsErr<>nil then FreeAndNil(GState.FsErr); GState.Fs:=nil; SetLength(GState.Data,0); SetLength(GState.Dir,0); SetLength(GState.PathResult,0); if Assigned(LLoop) then LLoop.Free; end;
    if Assigned(LServerThread) then begin LServerThread.WaitFor; LServerThread.Free; end;
  finally Finalize(LOpts); if Assigned(LListener) then LListener.Close; SetLength(LSc^.FileData,0); SetLength(LSc^.HostSeed,0); Finalize(LSc^); Dispose(LSc); end;
end;

var GSeed:TBytes; GRunner:TSuiteRunner; GSuite:TTestSuite;
begin
  GSeed:=PatternBytes($11,32);
  GSuite:=TTestSuite.Create('ssh sftp async');
  GSuite.Test('realpath async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'realpath',P,A,D,Da,K); CheckTrue(Ok,'realpath ok'); CheckEqual('/resolved/foo',P,'path'); end);
  GSuite.Test('stat async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'stat',P,A,D,Da,K); CheckTrue(Ok,'stat ok'); CheckEqual(UInt64(1234), A.Size,'size'); CheckTrue(A.IsRegular,'regular'); end);
  GSuite.Test('stat notfound maps sekSftp', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'stat-notfound',P,A,D,Da,K); CheckTrue(not Ok,'should fail'); CheckEqual(Ord(sekSftp), Ord(K),'kind'); end);
  GSuite.Test('listdir async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'listdir',P,A,D,Da,K); CheckTrue(Ok,'listdir ok'); CheckEqual(2, Length(D),'entries'); CheckEqual('a.txt', D[0].Name); end);
  GSuite.Test('readfile async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'read',P,A,D,Da,K); CheckTrue(Ok,'read ok'); CheckEqual('hello sftp async', BytesToText(Da),'data'); end);
  GSuite.Test('writefile async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'write',P,A,D,Da,K); CheckTrue(Ok,'write ok'); end);
  GSuite.Test('remove async', procedure var P:string; A:TSftpAttrs; D:TSftpDirEntryArray; Da:TBytes; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunSftpScenario(GSeed,'remove',P,A,D,Da,K); CheckTrue(Ok,'remove ok'); end);
  GRunner:=TSuiteRunner.Create('nextpas.core.ssh.sftp.async');
  GRunner.Add(GSuite); GRunner.RunAll; GRunner.Summary;
  ClearBigIntCache; // heaptrc 0: BigNat Montgomery 单源收敛，终局清零
  if not GRunner.AllPassed then Halt(1);
  GState:=Default(TAsyncSftpTestState); SetLength(GSeed,0); GSuite:=Default(TTestSuite); GRunner:=Default(TSuiteRunner);
end.
