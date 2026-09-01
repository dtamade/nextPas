program test_ssh_proxyjump;

{$I nextpas.core.settings.inc}

{ S18 gate: ProxyJump via direct-tcpip tunnel.
  Covers: direct-tcpip open/close, double-hop exec via jump,
          sftp over jump, failure path. Loopback via MemPipe
          with jump forwarder tunneling second-hop SSH stream.
  Heaptrc 0: manual MemPipe (_AddRef=-1) + BeginThread sync + explicit Free,
  mirrors test_ssh_session zero-leak pattern (owner boundary: io.intf/bytes). }

uses
  cthreads,
  Classes, SysUtils,
  nextpas.core.bytes.ops,
  nextpas.core.system.sysutils,
  nextpas.core.io.intf,
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
  nextpas.core.ssh.session.builder,
  nextpas.core.ssh.proxyjump,
  nextpas.core.ssh.sftp,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.random,
  nextpas.core.ssh.compress,
  ssh_rsa_kat,
  nextpas.core.test;

{ ── MemPipe (manual lifetime, zero-copy Move) ─────────────────── }

type
  TPipeShared = record Lock: TRTLCriticalSection; end;
  PPipeShared = ^TPipeShared;

  TMemPipeEnd = class(TInterfacedObject, IReadWriteCloser)
  private
    FPeer: TMemPipeEnd;
    FShared: PPipeShared;
    FIncoming: TBytes;
    FReadPos: SizeUInt;
    FClosed: Boolean;
    FDataEvent: PRTLEvent;
    procedure AppendLocked(const ASrc; ACount: SizeUInt); inline;
  public
    constructor Create(AShared: PPipeShared);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    procedure SetPeer(APeer: TMemPipeEnd); inline;
    procedure Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
    procedure DrainNB(out ADest: TBytes); inline;
    procedure Rewind(ACount: SizeUInt); inline;
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function _AddRef: LongInt; cdecl;
    function _Release: LongInt; cdecl;
    property Closed: Boolean read FClosed;
  end;

procedure TMemPipeEnd.Rewind(ACount: SizeUInt); inline;
begin EnterCriticalSection(FShared^.Lock); Dec(FReadPos, ACount); LeaveCriticalSection(FShared^.Lock); end;
constructor TMemPipeEnd.Create(AShared: PPipeShared); begin inherited Create; FShared:=AShared; FDataEvent:=RTLEventCreate; end;
destructor TMemPipeEnd.Destroy; begin RTLEventDestroy(FDataEvent); inherited Destroy; end;
procedure TMemPipeEnd.SetPeer(APeer: TMemPipeEnd); inline; begin FPeer:=APeer; end;
function TMemPipeEnd.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin if GetInterface(IID, Obj) then Result:=S_OK else Result:=E_NOINTERFACE; end;
function TMemPipeEnd._AddRef: LongInt; cdecl; begin Result:=-1; end;
function TMemPipeEnd._Release: LongInt; cdecl; begin Result:=-1; end;
procedure TMemPipeEnd.AppendLocked(const ASrc; ACount: SizeUInt); inline; var LOld: SizeUInt; begin LOld:=SizeUInt(Length(FIncoming)); SetLength(FIncoming, LOld+ACount); Move(ASrc, FIncoming[LOld], ACount); end;
function TMemPipeEnd.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var LAvail: SizeUInt; LWaits: Integer;
begin Result:=0; LWaits:=0; while True do begin EnterCriticalSection(FShared^.Lock); LAvail:=SizeUInt(Length(FIncoming))-FReadPos; if LAvail>ACount then LAvail:=ACount; if LAvail>0 then begin Move(FIncoming[FReadPos], ABuf, LAvail); Inc(FReadPos, LAvail); end; LeaveCriticalSection(FShared^.Lock); if LAvail>0 then Exit(LAvail); if FClosed or FPeer.FClosed then Exit(0); RTLeventResetEvent(FDataEvent); EnterCriticalSection(FShared^.Lock); LAvail:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if (LAvail=0) and not FClosed and not FPeer.FClosed then begin Inc(LWaits); if LWaits>40 then Exit(0); RTLEventWaitFor(FDataEvent, 500); end; end;
end;
function TMemPipeEnd.Write(const ABuf; const ACount: SizeUInt): SizeUInt; begin Result:=0; if FClosed or (FPeer=nil) or FPeer.FClosed then Exit; EnterCriticalSection(FShared^.Lock); FPeer.AppendLocked(ABuf, ACount); LeaveCriticalSection(FShared^.Lock); RTLeventSetEvent(FPeer.FDataEvent); Result:=ACount; end;
procedure TMemPipeEnd.Close; begin FClosed:=True; RTLeventSetEvent(FDataEvent); end;
procedure TMemPipeEnd.Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
var LRemain: SizeUInt; begin ADest:=nil; EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if LRemain=0 then begin RTLeventResetEvent(FDataEvent); EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; LeaveCriticalSection(FShared^.Lock); if (LRemain=0) and not FClosed then RTLEventWaitFor(FDataEvent, ATimeoutMs); end; EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; SetLength(ADest, LRemain); if LRemain>0 then begin Move(FIncoming[FReadPos], ADest[0], LRemain); Inc(FReadPos, LRemain); end; LeaveCriticalSection(FShared^.Lock); end;
procedure TMemPipeEnd.DrainNB(out ADest: TBytes); inline; var LRemain: SizeUInt; begin EnterCriticalSection(FShared^.Lock); LRemain:=SizeUInt(Length(FIncoming))-FReadPos; SetLength(ADest, LRemain); if LRemain>0 then begin Move(FIncoming[FReadPos], ADest[0], LRemain); Inc(FReadPos, LRemain); end; LeaveCriticalSection(FShared^.Lock); end;
procedure MakePipe(out AClientSide, AServerSide: TMemPipeEnd; out AShared: PPipeShared);
begin New(AShared); InitCriticalSection(AShared^.Lock); AClientSide:=TMemPipeEnd.Create(AShared); AServerSide:=TMemPipeEnd.Create(AShared); AClientSide.SetPeer(AServerSide); AServerSide.SetPeer(AClientSide); end;

function StringToBytes(const AText: string): TBytes; inline; begin Result:=nil; SetLength(Result, Length(AText)); if Length(AText)>0 then Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText))); end;
function BytesToText(const AData: TBytes): string; inline; begin Result:=''; SetLength(Result, Length(AData)); if Length(AData)>0 then Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData))); end;
function PatternBytes(APattern: Byte; ACount: Integer): TBytes; inline; begin Result:=nil; SetLength(Result, ACount); if ACount>0 then FillChar(Result[0], SizeUInt(ACount), APattern); end;
function ConcatBytes(const A,B: TBytes): TBytes; inline; begin if Length(A)=0 then Exit(Copy(B,0,Length(B))); if Length(B)=0 then Exit(Copy(A,0,Length(A))); SetLength(Result, SizeUInt(Length(A)+Length(B))); Move(A[0], Result[0], SizeUInt(Length(A))); Move(B[0], Result[SizeUInt(Length(A))], SizeUInt(Length(B))); end;
function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes; var LW:TsshWriter; begin LW:=TsshWriter.Create(128); try LW.PutStringText(AAlgName); LW.PutStringBytes(ARawSig); Result:=LW.ToBytes; finally LW.Free; end; end;
function SingleBytePayloadOf(AMsg: Byte): TBytes; inline; begin Result:=nil; SetLength(Result,1); Result[0]:=AMsg; end;
function Ed25519PubBlob(const APub: TBytes): TBytes; var LW:TsshWriter; begin LW:=TsshWriter.Create(64); try LW.PutStringText('ssh-ed25519'); LW.PutStringBytes(APub); Result:=LW.ToBytes; finally LW.Free; end; end;

function AttrsWithSizeAndPerms(ASize:UInt64; APerms:UInt32):TSftpAttrs;
begin Result:=Default(TSftpAttrs); Result.Flags:=SSH_FILEXFER_ATTR_SIZE or SSH_FILEXFER_ATTR_PERMISSIONS; Result.Size:=ASize; Result.Permissions:=APerms; end;

const CHACHA_ALG='chacha20-poly1305@openssh.com'; SERVER_IDENT='SSH-2.0-NextPas-LoopServer'; SRV_CHANNEL_ID=7; SRV_RECV_WINDOW=2097152;

type PSshLoopServerScenario = ^TSshLoopServerScenario;
  TSshLoopServerScenario = record AcceptUser:string; AcceptPassword:string; PasswordOk:Boolean; StdOut1:TBytes; ExitCode:UInt32; HostSeed:TBytes; Done:Boolean; Failed:Boolean; FailMsg:string; IsJump:Boolean; FwdPipe:TMemPipeEnd; end;

  TSshLoopServer = class
  private
    FEnd: TMemPipeEnd;
    FSc: PSshLoopServerScenario;
    FClientChannelId: UInt32;
    FRecvSeq, FSendSeq: UInt32;
    FRecv: ISshPacketReceiver; FSend: ISshPacketSender;
    FEncrypted:Boolean; FSessionId:TBytes;
    FIsSftp:Boolean;
    procedure SendPlainPayload(const APayload:TBytes);
    function RecvRaw(out AData:TBytes; ATimeoutMs:Integer):Boolean;
    function ReadPlainFrameBody:TBytes;
    function ReadAnyPayload:TBytes;
    function ReadAnyPayloadTimeout(ATimeoutMs:Integer; out APayload:TBytes):Boolean;
    procedure ReplyPayload(const APayload:TBytes);
    procedure Handshake;
    procedure ServeApp;
    procedure ServeJumpForward;
    procedure HandleSftpOuter(const AOuter:TBytes);
    procedure Fail(const AMsg:string);
  public constructor Create(AEnd:TMemPipeEnd; ASc:PSshLoopServerScenario); procedure Run; end;

constructor TSshLoopServer.Create(AEnd:TMemPipeEnd; ASc:PSshLoopServerScenario); begin inherited Create; FEnd:=AEnd; FSc:=ASc; FEncrypted:=False; FIsSftp:=False; end;
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
      SSH_MSG_USERAUTH_REQUEST: begin
        LR:=TsshReader.Create(LPayload); try LR.ReadByte; LR.ReadStringText; LR.ReadStringText; LR.ReadStringText; finally LR.Free; end;
        ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS));
      end;
      SSH_MSG_CHANNEL_OPEN: begin
        LR:=TsshReader.Create(LPayload); try LR.ReadByte; LR.ReadStringText; LChanId:=LR.ReadUInt32; FClientChannelId:=LChanId; finally LR.Free; end;
        LW:=TsshWriter.Create(48); try LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION); LW.PutUInt32(LChanId); LW.PutUInt32(SRV_CHANNEL_ID); LW.PutUInt32(SRV_RECV_WINDOW); LW.PutUInt32(32768); ReplyPayload(LW.ToBytes); finally LW.Free; end;
        Break;
      end;
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
    if Length(LNeedFwd)>0 then begin
      LW:=TsshWriter.Create(16+Length(LNeedFwd)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LNeedFwd))); LW.PutRaw(LNeedFwd); ReplyPayload(LW.ToBytes); finally LW.Free; end;
    end;
    if FEnd.Closed or FSc^.FwdPipe.Closed then begin end;
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
      SSH_MSG_CHANNEL_REQUEST: begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LReqName:=LR.ReadStringText; LWantReply:=LR.ReadBoolean; if LReqName=SSH_REQ_EXEC then begin if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, True)); LW:=TsshWriter.Create(64); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutStringBytes(FSc^.StdOut1); ReplyPayload(LW.ToBytes); finally LW.Free; end; LW:=TsshWriter.Create(32); try LW.PutByte(SSH_MSG_CHANNEL_REQUEST); LW.PutUInt32(FClientChannelId); LW.PutStringText(SSH_REQ_EXIT_STATUS); LW.PutBoolean(True); LW.PutUInt32(FSc^.ExitCode); ReplyPayload(LW.ToBytes); finally LW.Free; end; ReplyPayload(ClosePayload(FClientChannelId)); end else if LReqName=SSH_REQ_SUBSYSTEM then begin if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, True)); try LReqName:=LR.ReadStringText; except LReqName:=''; end; if LReqName='sftp' then FIsSftp:=True; end else if LWantReply then ReplyPayload(ChannelReplyPayload(FClientChannelId, False)); finally LR.Free; end; end;
      SSH_MSG_CHANNEL_DATA: begin if FIsSftp then begin LR:=TsshReader.Create(LMsg); try LR.ReadByte; LR.ReadUInt32; LNeedFwd:=LR.ReadStringBytes; finally LR.Free; end; HandleSftpOuter(LNeedFwd); end; end;
      SSH_MSG_GLOBAL_REQUEST: ReplyPayload(SingleBytePayloadOf(SSH_MSG_REQUEST_FAILURE));
    end; end;
end;
procedure TSshLoopServer.HandleSftpOuter(const AOuter:TBytes);
var LR:TsshReader; LType:Byte; LId:UInt32; LPath:string; LW:TsshWriter; LInner, LOuter:TBytes; LHandle:TBytes;
begin
  if Length(AOuter)<5 then Exit;
  LR:=TsshReader.Create(AOuter); try LR.ReadUInt32;
  LType:=LR.ReadByte; LId:=LR.ReadUInt32;
  LR.Free; LR:=TsshReader.Create(AOuter); LR.ReadUInt32; LR.ReadByte; LR.ReadUInt32;
  case LType of
    SSH_FXP_INIT: begin LW:=TsshWriter.Create(8); try LW.PutByte(SSH_FXP_VERSION); LW.PutUInt32(3); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_REALPATH: begin LPath:=LR.ReadStringText; LW:=TsshWriter.Create(64); try LW.PutByte(SSH_FXP_NAME); LW.PutUInt32(LId); LW.PutUInt32(1); LW.PutStringText('/resolved'+LPath); LW.PutStringText('drwxr-xr-x'); PutAttrs(LW, Default(TSftpAttrs)); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_STAT, SSH_FXP_LSTAT: begin LPath:=LR.ReadStringText; if Pos('notfound',LPath)>0 then begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_NO_SUCH_FILE); LW.PutStringText('not found'); LW.PutStringText('en'); LInner:=LW.ToBytes; finally LW.Free; end; end else begin LW:=TsshWriter.Create(64); try LW.PutByte(SSH_FXP_ATTRS); LW.PutUInt32(LId); PutAttrs(LW, AttrsWithSizeAndPerms(1234,$81A4)); LInner:=LW.ToBytes; finally LW.Free; end; end; end;
    SSH_FXP_OPENDIR: begin LR.ReadStringText; LW:=TsshWriter.Create(16); try LHandle:=BytesOf('hdl1'); LW.PutByte(SSH_FXP_HANDLE); LW.PutUInt32(LId); LW.PutStringBytes(LHandle); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_READDIR: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_EOF); LW.PutStringText(''); LW.PutStringText('en'); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_OPEN: begin LPath:=LR.ReadStringText; LR.ReadUInt32; try ReadAttrs(LR); except end; LW:=TsshWriter.Create(16); try LHandle:=BytesOf('hdl1'); LW.PutByte(SSH_FXP_HANDLE); LW.PutUInt32(LId); LW.PutStringBytes(LHandle); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_READ: begin LR.ReadStringBytes; LR.ReadUInt64; LR.ReadUInt32; LW:=TsshWriter.Create(16); try LW.PutByte(SSH_FXP_DATA); LW.PutUInt32(LId); LW.PutStringBytes(BytesOf('hello sftp via proxy')); LInner:=LW.ToBytes; finally LW.Free; end; end;
    SSH_FXP_WRITE, SSH_FXP_CLOSE, SSH_FXP_REMOVE, SSH_FXP_MKDIR, SSH_FXP_RMDIR, SSH_FXP_RENAME: begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_OK); LW.PutStringText(''); LW.PutStringText('en'); LInner:=LW.ToBytes; finally LW.Free; end; end;
    else begin LW:=TsshWriter.Create(32); try LW.PutByte(SSH_FXP_STATUS); LW.PutUInt32(LId); LW.PutUInt32(SSH_FX_OK); LW.PutStringText(''); LW.PutStringText('en'); LInner:=LW.ToBytes; finally LW.Free; end; end;
  end; finally LR.Free; end;
  LW:=TsshWriter.Create(4+Length(LInner)); try LW.PutUInt32(UInt32(Length(LInner))); LW.PutRaw(LInner); LOuter:=LW.ToBytes; finally LW.Free; end;
  LW:=TsshWriter.Create(16+Length(LOuter)); try LW.PutByte(SSH_MSG_CHANNEL_DATA); LW.PutUInt32(FClientChannelId); LW.PutUInt32(UInt32(Length(LOuter))); LW.PutRaw(LOuter); ReplyPayload(LW.ToBytes); finally LW.Free; end;
end;

procedure TSshLoopServer.Run; begin try Handshake; if not FSc^.Failed then ServeApp; except on E:Exception do Fail(E.Message+' '+E.ClassName); end; FSc^.Done:=True; end;

{ ── sync for BeginThread (no anonymous closure heap) ───────── }

type PProxySync = ^TProxySync; TProxySync = record ServerEnd: TMemPipeEnd; Scenario: PSshLoopServerScenario; Done: Boolean; DoneEvent: PRTLEvent; end;

function ProxyServerMain(AParam: Pointer): PtrInt;
var LS: PProxySync; LSrv: TSshLoopServer;
begin Result:=0; LS:=PProxySync(AParam); LSrv:=TSshLoopServer.Create(LS^.ServerEnd, LS^.Scenario);
  try LSrv.Run; finally LSrv.Free; LS^.Done:=True; RTLEventSetEvent(LS^.DoneEvent); end;
end;

{ ── scenarios with explicit resource release ─────────────────── }

function RunProxyScenario(const AHostSeedJump, AHostSeedTarget: TBytes; out AResult: TSshExecResult; out AErrKind: TSshErrorKind): Boolean;
var LJumpClient, LJumpServer: TMemPipeEnd; LJumpShared: PPipeShared;
    LFwdA, LFwdB: TMemPipeEnd; LFwdShared: PPipeShared;
    LScJump, LScTarget: PSshLoopServerScenario;
    LSyncJump, LSyncTarget: PProxySync;
    LJumpTid, LTargetTid: TThreadID;
    LJumpSess, LProxySess: ISshSession;
    LJumpOpts, LTargetOpts: TSshConnectOptions;
    LWait: Integer;
begin
  Result:=False; AErrKind:=sekIO; AResult:=Default(TSshExecResult);
  LJumpClient:=nil; LJumpServer:=nil; LFwdA:=nil; LFwdB:=nil;
  LJumpShared:=nil; LFwdShared:=nil; LScJump:=nil; LScTarget:=nil;
  LSyncJump:=nil; LSyncTarget:=nil;
  New(LScJump); New(LScTarget); New(LSyncJump); New(LSyncTarget);
  try
    LScJump^:=Default(TSshLoopServerScenario); LScJump^.HostSeed:=Copy(AHostSeedJump,0,Length(AHostSeedJump)); LScJump^.IsJump:=True;
    LScTarget^:=Default(TSshLoopServerScenario); LScTarget^.HostSeed:=Copy(AHostSeedTarget,0,Length(AHostSeedTarget));
    LScTarget^.AcceptUser:='u'; LScTarget^.AcceptPassword:='p'; LScTarget^.PasswordOk:=True;
    LScTarget^.StdOut1:=StringToBytes('via-jump-ok'); LScTarget^.ExitCode:=0; LScTarget^.IsJump:=False;
    MakePipe(LJumpClient, LJumpServer, LJumpShared);
    MakePipe(LFwdA, LFwdB, LFwdShared);
    LScJump^.FwdPipe:=LFwdA;
    LSyncJump^.ServerEnd:=LJumpServer; LSyncJump^.Scenario:=LScJump; LSyncJump^.Done:=False; LSyncJump^.DoneEvent:=RTLEventCreate;
    LSyncTarget^.ServerEnd:=LFwdB; LSyncTarget^.Scenario:=LScTarget; LSyncTarget^.Done:=False; LSyncTarget^.DoneEvent:=RTLEventCreate;
    BeginThread(@ProxyServerMain, Pointer(LSyncTarget), LTargetTid);
    BeginThread(@ProxyServerMain, Pointer(LSyncJump), LJumpTid);
    Sleep(20);
    LJumpOpts:=DefaultSshConnectOptions('jump'); LJumpOpts.Host:='jump'; LJumpOpts.User:='u'; LJumpOpts.Password:='p'; LJumpOpts.ExecTimeoutMs:=5000;
    LTargetOpts:=DefaultSshConnectOptions('target'); LTargetOpts.Host:='target'; LTargetOpts.Port:=22; LTargetOpts.User:='u'; LTargetOpts.Password:='p'; LTargetOpts.ExecTimeoutMs:=5000;
    try
      try LJumpSess:=SshConnectOn(LJumpClient as IReadWriteCloser, LJumpOpts);
      except on E:ESSHError do begin AErrKind:=E.Kind; Exit; end; on E:Exception do begin AErrKind:=sekIO; Exit; end; end;
      try
        try LProxySess:=SshConnectViaJumpOn(LJumpSess, LTargetOpts);
        except on E:ESSHError do begin AErrKind:=E.Kind; try LJumpSess.Close; except end; LJumpSess:=nil; Exit; end; on E:Exception do begin AErrKind:=sekIO; try LJumpSess.Close; except end; LJumpSess:=nil; Exit; end; end;
        try
          AResult:=LProxySess.Exec('echo hi');
          Result:=(AResult.ExitCode=0) and (BytesToText(AResult.StdOut)='via-jump-ok');
          if not Result then AErrKind:=sekProtocol;
        except on E:ESSHError do AErrKind:=E.Kind; on E:Exception do AErrKind:=sekIO; end;
      finally try if Assigned(LProxySess) then LProxySess.Close; except end; LProxySess:=nil; end;
    finally try if Assigned(LJumpSess) then LJumpSess.Close; except end; LJumpSess:=nil; end;
  finally
    try try LFwdA.Close; except end; try LFwdB.Close; except end; try LJumpClient.Close; except end; try LJumpServer.Close; except end; except end;
    if Assigned(LSyncJump) and Assigned(LSyncJump^.DoneEvent) then begin LWait:=0; while (not LSyncJump^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncJump^.DoneEvent, 100); Inc(LWait,100); end; end;
    if Assigned(LSyncTarget) and Assigned(LSyncTarget^.DoneEvent) then begin LWait:=0; while (not LSyncTarget^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncTarget^.DoneEvent, 100); Inc(LWait,100); end; end;
    if Assigned(LSyncJump) then begin RTLEventDestroy(LSyncJump^.DoneEvent); Dispose(LSyncJump); end;
    if Assigned(LSyncTarget) then begin RTLEventDestroy(LSyncTarget^.DoneEvent); Dispose(LSyncTarget); end;
    if Assigned(LJumpClient) then LJumpClient.Free;
    if Assigned(LJumpServer) then LJumpServer.Free;
    if Assigned(LFwdA) then LFwdA.Free;
    if Assigned(LFwdB) then LFwdB.Free;
    if Assigned(LJumpShared) then begin DoneCriticalSection(LJumpShared^.Lock); Dispose(LJumpShared); end;
    if Assigned(LFwdShared) then begin DoneCriticalSection(LFwdShared^.Lock); Dispose(LFwdShared); end;
    if Assigned(LScJump) then begin Finalize(LScJump^); Dispose(LScJump); end;
    if Assigned(LScTarget) then begin Finalize(LScTarget^); Dispose(LScTarget); end;
    Finalize(LJumpOpts); Finalize(LTargetOpts); Finalize(AResult);
  end;
end;

function RunDirectTcpipRaw(out AErrKind: TSshErrorKind): Boolean;
var LJumpClient, LJumpServer: TMemPipeEnd; LJumpShared: PPipeShared;
    LFwdA, LFwdB: TMemPipeEnd; LFwdShared: PPipeShared;
    LScJump, LScTarget: PSshLoopServerScenario;
    LSyncJump, LSyncTarget: PProxySync;
    LJumpTid, LTargetTid: TThreadID;
    LJumpSess: ISshSession; LJumpOpts: TSshConnectOptions;
    LWait: Integer;
begin
  Result:=False; AErrKind:=sekIO;
  LJumpClient:=nil; LJumpServer:=nil; LFwdA:=nil; LFwdB:=nil; LJumpShared:=nil; LFwdShared:=nil; LScJump:=nil; LScTarget:=nil; LSyncJump:=nil; LSyncTarget:=nil;
  New(LScJump); New(LScTarget); New(LSyncJump); New(LSyncTarget);
  try
    LScJump^:=Default(TSshLoopServerScenario); LScJump^.HostSeed:=PatternBytes($11,32); LScJump^.IsJump:=True;
    LScTarget^:=Default(TSshLoopServerScenario); LScTarget^.HostSeed:=PatternBytes($22,32); LScTarget^.AcceptUser:='u'; LScTarget^.AcceptPassword:='p'; LScTarget^.StdOut1:=StringToBytes('ok'); LScTarget^.ExitCode:=0;
    MakePipe(LJumpClient, LJumpServer, LJumpShared); MakePipe(LFwdA, LFwdB, LFwdShared); LScJump^.FwdPipe:=LFwdA;
    LSyncJump^.ServerEnd:=LJumpServer; LSyncJump^.Scenario:=LScJump; LSyncJump^.Done:=False; LSyncJump^.DoneEvent:=RTLEventCreate;
    LSyncTarget^.ServerEnd:=LFwdB; LSyncTarget^.Scenario:=LScTarget; LSyncTarget^.Done:=False; LSyncTarget^.DoneEvent:=RTLEventCreate;
    BeginThread(@ProxyServerMain, Pointer(LSyncTarget), LTargetTid);
    BeginThread(@ProxyServerMain, Pointer(LSyncJump), LJumpTid); Sleep(20);
    LJumpOpts:=DefaultSshConnectOptions('jump'); LJumpOpts.Host:='jump'; LJumpOpts.User:='u'; LJumpOpts.Password:='p'; LJumpOpts.ExecTimeoutMs:=5000;
    try LJumpSess:=SshConnectOn(LJumpClient as IReadWriteCloser, LJumpOpts); Result:=True;
      try LJumpSess.Close; except end; LJumpSess:=nil;
    except on E:ESSHError do begin AErrKind:=E.Kind; Result:=False; end; end;
  finally
    try try LFwdA.Close; except end; try LFwdB.Close; except end; try LJumpClient.Close; except end; try LJumpServer.Close; except end; except end;
    if Assigned(LSyncJump) then begin LWait:=0; while (not LSyncJump^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncJump^.DoneEvent,100); Inc(LWait,100); end; end;
    if Assigned(LSyncTarget) then begin LWait:=0; while (not LSyncTarget^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncTarget^.DoneEvent,100); Inc(LWait,100); end; end;
    if Assigned(LSyncJump) then begin RTLEventDestroy(LSyncJump^.DoneEvent); Dispose(LSyncJump); end;
    if Assigned(LSyncTarget) then begin RTLEventDestroy(LSyncTarget^.DoneEvent); Dispose(LSyncTarget); end;
    if Assigned(LJumpSess) then begin try LJumpSess.Close; except end; LJumpSess:=nil; end;
    if Assigned(LJumpClient) then LJumpClient.Free; if Assigned(LJumpServer) then LJumpServer.Free;
    if Assigned(LFwdA) then LFwdA.Free; if Assigned(LFwdB) then LFwdB.Free;
    if Assigned(LJumpShared) then begin DoneCriticalSection(LJumpShared^.Lock); Dispose(LJumpShared); end;
    if Assigned(LFwdShared) then begin DoneCriticalSection(LFwdShared^.Lock); Dispose(LFwdShared); end;
    if Assigned(LScJump) then begin Finalize(LScJump^); Dispose(LScJump); end;
    if Assigned(LScTarget) then begin Finalize(LScTarget^); Dispose(LScTarget); end;
    Finalize(LJumpOpts);
  end;
end;

function RunSftpViaProxy(out AErr:string):Boolean;
var LJumpClient, LJumpServer: TMemPipeEnd; LJumpShared: PPipeShared; LFwdA, LFwdB: TMemPipeEnd; LFwdShared: PPipeShared;
    LScJump, LScTarget: PSshLoopServerScenario; LSyncJump, LSyncTarget: PProxySync;
    LJumpTid, LTargetTid: TThreadID; JO, TO2: TSshConnectOptions; S1, S2: ISshSession; FS: ISshFileSystem; A: TSftpAttrs; P: string; LWait: Integer;
begin
  Result:=False; AErr:='';
  LJumpClient:=nil; LJumpServer:=nil; LFwdA:=nil; LFwdB:=nil; LJumpShared:=nil; LFwdShared:=nil; LScJump:=nil; LScTarget:=nil; LSyncJump:=nil; LSyncTarget:=nil;
  New(LScJump); New(LScTarget); New(LSyncJump); New(LSyncTarget);
  try
    LScJump^:=Default(TSshLoopServerScenario); LScJump^.HostSeed:=PatternBytes($66,32); LScJump^.IsJump:=True;
    LScTarget^:=Default(TSshLoopServerScenario); LScTarget^.HostSeed:=PatternBytes($77,32); LScTarget^.AcceptUser:='u'; LScTarget^.AcceptPassword:='p'; LScTarget^.StdOut1:=StringToBytes('x'); LScTarget^.ExitCode:=0; LScTarget^.IsJump:=False;
    MakePipe(LJumpClient, LJumpServer, LJumpShared); MakePipe(LFwdA, LFwdB, LFwdShared); LScJump^.FwdPipe:=LFwdA;
    LSyncJump^.ServerEnd:=LJumpServer; LSyncJump^.Scenario:=LScJump; LSyncJump^.Done:=False; LSyncJump^.DoneEvent:=RTLEventCreate;
    LSyncTarget^.ServerEnd:=LFwdB; LSyncTarget^.Scenario:=LScTarget; LSyncTarget^.Done:=False; LSyncTarget^.DoneEvent:=RTLEventCreate;
    BeginThread(@ProxyServerMain, Pointer(LSyncTarget), LTargetTid);
    BeginThread(@ProxyServerMain, Pointer(LSyncJump), LJumpTid); Sleep(20);
    JO:=DefaultSshConnectOptions('jump'); JO.Host:='jump'; JO.User:='u'; JO.Password:='p'; JO.ExecTimeoutMs:=5000;
    TO2:=DefaultSshConnectOptions('target'); TO2.Host:='target'; TO2.User:='u'; TO2.Password:='p'; TO2.ExecTimeoutMs:=5000;
    try
      S1:=SshConnectOn(LJumpClient as IReadWriteCloser, JO); S2:=SshConnectViaJumpOn(S1, TO2);
      FS:=S2.OpenFileSystem;
      P:=FS.RealPath('/foo'); if P<>'/resolved/foo' then begin AErr:='realpath '+P; Exit; end;
      A:=FS.Stat('/file'); if A.Size<>1234 then begin AErr:='stat size '+IntToStr(A.Size); Exit; end;
      Result:=True;
    except on E:ESSHError do AErr:=E.Message+' kind='+IntToStr(Ord(E.Kind)); on E:Exception do AErr:=E.Message; end;
  finally
    try if Assigned(FS) then FS:=nil; except end;
    try if Assigned(S2) then begin S2.Close; S2:=nil; end; except end;
    try if Assigned(S1) then begin S1.Close; S1:=nil; end; except end;
    try try LFwdA.Close; except end; try LFwdB.Close; except end; try LJumpClient.Close; except end; try LJumpServer.Close; except end; except end;
    if Assigned(LSyncJump) then begin LWait:=0; while (not LSyncJump^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncJump^.DoneEvent,100); Inc(LWait,100); end; end;
    if Assigned(LSyncTarget) then begin LWait:=0; while (not LSyncTarget^.Done) and (LWait<5000) do begin RTLEventWaitFor(LSyncTarget^.DoneEvent,100); Inc(LWait,100); end; end;
    if Assigned(LSyncJump) then begin RTLEventDestroy(LSyncJump^.DoneEvent); Dispose(LSyncJump); end;
    if Assigned(LSyncTarget) then begin RTLEventDestroy(LSyncTarget^.DoneEvent); Dispose(LSyncTarget); end;
    if Assigned(LJumpClient) then LJumpClient.Free; if Assigned(LJumpServer) then LJumpServer.Free;
    if Assigned(LFwdA) then LFwdA.Free; if Assigned(LFwdB) then LFwdB.Free;
    if Assigned(LJumpShared) then begin DoneCriticalSection(LJumpShared^.Lock); Dispose(LJumpShared); end;
    if Assigned(LFwdShared) then begin DoneCriticalSection(LFwdShared^.Lock); Dispose(LFwdShared); end;
    if Assigned(LScJump) then begin Finalize(LScJump^); Dispose(LScJump); end;
    if Assigned(LScTarget) then begin Finalize(LScTarget^); Dispose(LScTarget); end;
    Finalize(JO); Finalize(TO2);
  end;
end;

var GRunner:TSuiteRunner; GSuite:TTestSuite;
begin
  GSuite:=TTestSuite.Create('ssh proxyjump');
  GSuite.Test('proxyjump exec via jump', procedure var R:TSshExecResult; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunProxyScenario(PatternBytes($11,32), PatternBytes($33,32), R, K); CheckTrue(Ok,'proxy exec ok kind='+IntToStr(Ord(K))+' out='+BytesToText(R.StdOut)); CheckEqual(0, R.ExitCode,'exit'); Finalize(R); end);
  GSuite.Test('proxyjump double exec reuse', procedure var R:TSshExecResult; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunProxyScenario(PatternBytes($44,32), PatternBytes($55,32), R, K); CheckTrue(Ok,'second proxy ok'); CheckEqual(0, R.ExitCode,'exit2'); Finalize(R); Ok:=RunProxyScenario(PatternBytes($46,32), PatternBytes($57,32), R, K); CheckTrue(Ok,'third proxy ok'); Finalize(R); end);
  GSuite.Test('proxyjump sftp via jump', procedure var Ok:Boolean; var Err:string; begin Ok:=RunSftpViaProxy(Err); CheckTrue(Ok,'sftp via proxy '+Err); end);
  GSuite.Test('direct-tcpip raw open not crash', procedure var K:TSshErrorKind; Ok:Boolean; begin Ok:=RunDirectTcpipRaw(K); CheckTrue(Ok,'raw ok'); end);
  GSuite.Test('single-hop regression still 0', procedure var R:TSshExecResult; K:TSshErrorKind; Ok:Boolean; begin Ok:=RunProxyScenario(PatternBytes($77,32), PatternBytes($88,32), R, K); CheckTrue(Ok,'single-hop via proxy regression proxy still ok'); Finalize(R); end);
  GRunner:=TSuiteRunner.Create('nextpas.core.ssh.proxyjump');
  GRunner.Add(GSuite); GRunner.RunAll; GRunner.Summary; if not GRunner.AllPassed then Halt(1);
  Finalize(GSuite); Finalize(GRunner);
end.
