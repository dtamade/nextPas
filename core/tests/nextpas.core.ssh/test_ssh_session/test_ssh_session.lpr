program test_ssh_session;

{$I nextpas.core.settings.inc}

{ S4 gate：全栈回环。
 * 测试内实现最小 SSH 服务端（独立服务端逻辑路径：版本交换 → KEXINIT →
 * curve25519 ECDH + ed25519 签名 REPLY → NEWKEYS 切换 → service/userauth →
 * channel open/exec/data/exit-status/close），与真实客户端实现在内存管道上
 * 跑完 握手→认证→exec→关闭 全流程。
 * 覆盖：密码认证正/负路径、publickey 签名认证、known_hosts 策略（严格模式
 * 未知拒绝 / 文件命中放行）、窗口回补帧容忍、stdout/stderr/exit-code 收集。}

uses
  cthreads,
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
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.bcrypt_pbkdf,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.random,
  nextpas.core.ssh.kex.dhgroup14,
  nextpas.core.encoding.base64,
  nextpas.core.platform.files.text,
  nextpas.core.ssh.rsa,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.compress,
  ssh_rsa_kat,
  nextpas.core.test;

{ ── 线程安全阻塞内存管道 ───────────────────────────────────────── }

type
  TPipeShared = record
    Lock: TRTLCriticalSection;
  end;
  PPipeShared = ^TPipeShared;

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
    { 阻塞等待数据后取走全部已到达字节；无数据最多等 ATimeoutMs }
    procedure Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
    { 回退读位置 ACount 字节（粘包场景）}
    procedure Rewind(ACount: SizeUInt);
    { 非引用计数生命周期：由测试手工管理 }
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function _AddRef: LongInt; cdecl;
    function _Release: LongInt; cdecl;
    property Closed: Boolean read FClosed;
  end;

procedure TMemPipeEnd.Rewind(ACount: SizeUInt);
begin
  EnterCriticalSection(FShared^.Lock);
  Dec(FReadPos, ACount);
  LeaveCriticalSection(FShared^.Lock);
end;

constructor TMemPipeEnd.Create(AShared: PPipeShared);
begin
  inherited Create;
  FShared := AShared;
  FDataEvent := RTLEventCreate;
end;

destructor TMemPipeEnd.Destroy;
begin
  RTLEventDestroy(FDataEvent);
  inherited Destroy;
end;

function TMemPipeEnd.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TMemPipeEnd._AddRef: LongInt; cdecl;
begin
  Result := -1;
end;

function TMemPipeEnd._Release: LongInt; cdecl;
begin
  Result := -1;
end;

procedure TMemPipeEnd.SetPeer(APeer: TMemPipeEnd);
begin
  FPeer := APeer;
end;

procedure TMemPipeEnd.AppendLocked(const ASrc; ACount: SizeUInt);
var
  LOld: SizeUInt;
begin
  LOld := SizeUInt(Length(FIncoming));
  SetLength(FIncoming, LOld + ACount);
  Move(ASrc, FIncoming[LOld], ACount);
end;

function TMemPipeEnd.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeUInt;
  LWaits: Integer;
begin
  Result := 0;
  LWaits := 0;
  while True do
  begin
    EnterCriticalSection(FShared^.Lock);
    LAvail := SizeUInt(Length(FIncoming)) - FReadPos;
    if LAvail > ACount then
      LAvail := ACount;
    if LAvail > 0 then
    begin
      Move(FIncoming[FReadPos], ABuf, LAvail);
      Inc(FReadPos, LAvail);
    end;
    LeaveCriticalSection(FShared^.Lock);
    if LAvail > 0 then
      Exit(LAvail);
    { 阻塞流语义：自身或对端已关闭且无数据 → EOF }
    if FClosed or FPeer.FClosed then
      Exit(0);
    RTLeventResetEvent(FDataEvent);
    { 双检避免信号丢失 }
    EnterCriticalSection(FShared^.Lock);
    LAvail := SizeUInt(Length(FIncoming)) - FReadPos;
    LeaveCriticalSection(FShared^.Lock);
    if (LAvail = 0) and not FClosed and not FPeer.FClosed then
    begin
      Inc(LWaits);
      if LWaits > 40 then            { ~20s 静默按 EOF，避免测试挂死 }
        Exit(0);
      RTLEventWaitFor(FDataEvent, 500);
    end;
  end;
end;

function TMemPipeEnd.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  if FClosed or (FPeer = nil) or FPeer.FClosed then
    Exit;
  EnterCriticalSection(FShared^.Lock);
  FPeer.AppendLocked(ABuf, ACount);
  LeaveCriticalSection(FShared^.Lock);
  RTLeventSetEvent(FPeer.FDataEvent);
  Result := ACount;
end;

procedure TMemPipeEnd.Close;
begin
  FClosed := True;
  RTLeventSetEvent(FDataEvent);
end;

procedure TMemPipeEnd.Drain(out ADest: TBytes; ATimeoutMs: Cardinal);
var
  LRemain: SizeUInt;
begin
  ADest := nil;
  EnterCriticalSection(FShared^.Lock);
  LRemain := SizeUInt(Length(FIncoming)) - FReadPos;
  LeaveCriticalSection(FShared^.Lock);
  if LRemain = 0 then
  begin
    RTLeventResetEvent(FDataEvent);
    { 双检避免信号丢失 }
    EnterCriticalSection(FShared^.Lock);
    LRemain := SizeUInt(Length(FIncoming)) - FReadPos;
    LeaveCriticalSection(FShared^.Lock);
    if (LRemain = 0) and not FClosed then
      RTLEventWaitFor(FDataEvent, ATimeoutMs);
  end;
  EnterCriticalSection(FShared^.Lock);
  LRemain := SizeUInt(Length(FIncoming)) - FReadPos;
  SetLength(ADest, LRemain);
  if LRemain > 0 then
  begin
    Move(FIncoming[FReadPos], ADest[0], LRemain);
    Inc(FReadPos, LRemain);
  end;
  LeaveCriticalSection(FShared^.Lock);
end;

procedure MakePipe(out AClientSide, AServerSide: TMemPipeEnd;
  out AShared: PPipeShared);
begin
  New(AShared);
  InitCriticalSection(AShared^.Lock);
  AClientSide := TMemPipeEnd.Create(AShared);
  AServerSide := TMemPipeEnd.Create(AShared);
  AClientSide.SetPeer(AServerSide);
  AServerSide.SetPeer(AClientSide);
end;

{ ── 小工具 ───────────────────────────────────────────────────── }

function StringToBytes(const AText: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(PByte(PChar(AText))^, Result[0], SizeUInt(Length(AText)));
end;

function BytesToText(const AData: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], PByte(PChar(Result))^, SizeUInt(Length(AData)));
end;

function PatternBytes(APattern: Byte; ACount: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[0], SizeUInt(ACount), APattern);
end;

function ConcatAll(const AParts: array of TBytes): TBytes;
var
  I: Integer;
  LTot, LPos: SizeUInt;
begin
  Result := nil;
  LTot := 0;
  for I := 0 to High(AParts) do
    Inc(LTot, SizeUInt(Length(AParts[I])));
  SetLength(Result, LTot);
  LPos := 0;
  for I := 0 to High(AParts) do
    if Length(AParts[I]) > 0 then
    begin
      Move(AParts[I][0], Result[LPos], SizeUInt(Length(AParts[I])));
      Inc(LPos, SizeUInt(Length(AParts[I])));
    end;
end;

function ConcatBytes(const A, B: TBytes): TBytes;
begin
  Result := ConcatAll([A, B]);
end;

function SigBlobOf(const AAlgName: string; const ARawSig: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(128);
  try
    LW.PutStringText(AAlgName);
    LW.PutStringBytes(ARawSig);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function SingleBytePayloadOf(AMsg: Byte): TBytes;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := AMsg;
end;

function Ed25519PubBlob(const APub: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(64);
  try
    LW.PutStringText('ssh-ed25519');
    LW.PutStringBytes(APub);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

const
  CHACHA_ALG = 'chacha20-poly1305@openssh.com';
  SERVER_IDENT = 'SSH-2.0-NextPas-LoopServer';
  CLIENT_HOST_NAME = 'loopback.local';
  SRV_CHANNEL_ID = 7;
  SRV_RECV_WINDOW = 2097152;
  SRV_READ_TIMEOUT_MS = 8000;

type
  { 服务端场景配置与结果（堆上分配，主线程与服务线程共享）}
  PSshLoopServerScenario = ^TSshLoopServerScenario;
  TSshLoopServerScenario = record
    AcceptUser: string;
    AcceptPassword: string;
    PasswordOk: Boolean;
    PubKeyOk: Boolean;
    StdOut1: TBytes;
    StdOut2: TBytes;
    StdErr: TBytes;
    ExitCode: UInt32;
    HostSeed: TBytes;
    ForceDH: Boolean;
    ForceCompress: Boolean;
    Failed: Boolean;
    FailMsg: string;
    Done: Boolean;
    { 竞争诊断：服务端收包计数与首包形态 }
    MsgCount: Integer;
    Msg1Type: Byte;
    Msg1Len: Integer;
    IgnoreCount: Integer;
  end;

  { 独立服务端逻辑路径 }
  TSshLoopServer = class
  private
    FEnd: TMemPipeEnd;
    FSc: PSshLoopServerScenario;
    FClientChannelId: UInt32;
    FRecvSeq, FSendSeq: UInt32;
    FRecv: ISshPacketReceiver;
    FSend: ISshPacketSender;
    FEncrypted: Boolean;
    FSessionId: TBytes;
    FComp: ISshCompressor;
    FCompEnabled: Boolean;
    FNegCompCs, FNegCompSc: string;
    procedure SendPlainPayload(const APayload: TBytes);
    function RecvRaw(out AData: TBytes): Boolean;
    function ReadPlainFrameBody: TBytes;
    function ReadAnyPayload: TBytes;
    procedure ReplyPayload(const APayload: TBytes);
    procedure Handshake;
    procedure ServeApp;
    procedure Fail(const AMsg: string);
  public
    constructor Create(AEnd: TMemPipeEnd; ASc: PSshLoopServerScenario);
    procedure Run;
  end;

constructor TSshLoopServer.Create(AEnd: TMemPipeEnd; ASc: PSshLoopServerScenario);
begin
  inherited Create;
  FEnd := AEnd;
  FSc := ASc;
  FEncrypted := False;
end;

procedure TSshLoopServer.Fail(const AMsg: string);
begin
  if not FSc^.Failed then
  begin
    FSc^.Failed := True;
    FSc^.FailMsg := AMsg;
  end;
end;

procedure TSshLoopServer.SendPlainPayload(const APayload: TBytes);
var
  LW: TsshWriter;
  LPad, I: Integer;
  LWire: TBytes;
begin
  LPad := 8 - ((4 + 1 + Length(APayload)) mod 8);
  if LPad < SSH_MIN_PADDING then
    Inc(LPad, 8);
  LW := TsshWriter.Create(64 + Length(APayload));
  try
    LW.PutUInt32(UInt32(1 + Length(APayload) + SizeUInt(LPad)));
    LW.PutByte(Byte(LPad));
    LW.PutRaw(APayload);
    for I := 1 to LPad do
      LW.PutByte($30);
    LWire := LW.ToBytes;
    FEnd.Write(LWire[0], SizeUInt(Length(LWire)));
  finally
    LW.Free;
  end;
end;

function TSshLoopServer.RecvRaw(out AData: TBytes): Boolean;
begin
  FEnd.Drain(AData, SRV_READ_TIMEOUT_MS);
  Result := Length(AData) > 0;
end;

{ 未加密阶段：读一帧并返回未加密载荷；对端消失返回 nil }
function TSshLoopServer.ReadPlainFrameBody: TBytes;
var
  LWire, LMore: TBytes;
  LLen, LPadLen: UInt32;
begin
  Result := nil;
  if not RecvRaw(LWire) then
    Exit;
  if Length(LWire) < 4 then
  begin
    while (Length(LWire) < 4) and RecvRaw(LMore) do
      LWire := ConcatBytes(LWire, LMore);
    if Length(LWire) < 4 then
      Exit;
  end;
  LLen := (UInt32(LWire[0]) shl 24) or (UInt32(LWire[1]) shl 16)
    or (UInt32(LWire[2]) shl 8) or UInt32(LWire[3]);
  while SizeUInt(Length(LWire)) < 4 + LLen do
  begin
    if not RecvRaw(LMore) then
      Exit;
    LWire := ConcatBytes(LWire, LMore);
  end;
  { 帧内可能粘包：只消费本帧，剩余留给下一次（回退读位置）}
  FEnd.Rewind(SizeUInt(Length(LWire)) - (4 + LLen));
  LPadLen := LWire[4];
  SetLength(Result, LLen - 1 - LPadLen);
  if Length(Result) > 0 then
    Move(LWire[5], Result[0], Length(Result));
end;

{ 加密阶段读一帧载荷 }
{ 加密阶段读一帧载荷：解密并剥离 padlen，返回纯载荷 }
function TSshLoopServer.ReadAnyPayload: TBytes;
var
  LBuf, LHeader, LTrailer, LPacket, LBody: TBytes;
  LBodyLen: UInt32;
  LPadLen: Byte;
begin
  Result := nil;
  if not FEncrypted then
  begin
    Result := ReadPlainFrameBody;
    Exit;
  end;
  if not RecvRaw(LBuf) then
    Exit;
  LHeader := LBuf;
  while SizeUInt(Length(LHeader)) < 4 do
  begin
    if not RecvRaw(LBuf) then
      Exit;
    LHeader := ConcatBytes(LHeader, LBuf);
  end;
  LBodyLen := FRecv.BodyLengthFromHeader(FRecvSeq, Copy(LHeader, 0, 4));
  SetLength(LTrailer, FRecv.TrailerSize(LBodyLen));
  while SizeUInt(Length(LHeader)) < 4 + SizeUInt(Length(LTrailer)) do
  begin
    if not RecvRaw(LBuf) then
      Exit;
    LHeader := ConcatBytes(LHeader, LBuf);
  end;
  LPacket := Copy(LHeader, 0, 4 + SizeInt(Length(LTrailer)));
  FEnd.Rewind(SizeUInt(Length(LHeader))
    - (4 + SizeUInt(Length(LTrailer))));
  { codec 契约：Unprotect 返回完整 body（padlen ‖ 载荷 ‖ 填充）}
  LBody := FRecv.Unprotect(FRecvSeq, LPacket);
  Inc(FRecvSeq);
  if SizeUInt(Length(LBody)) < 1 then
    Exit;
  LPadLen := LBody[0];
  if UInt32(LPadLen) >= LBodyLen then
    Exit;
  SetLength(Result, LBodyLen - 1 - LPadLen);
  if Length(Result) > 0 then
    Move(LBody[1], Result[0], Length(Result));
  if FCompEnabled and (FComp <> nil) and SshCompressionIsZlib(FNegCompSc) then
    Result := FComp.Decompress(Result);
end;

procedure TSshLoopServer.ReplyPayload(const APayload: TBytes);
var
  LWire, LBody: TBytes;
  LPad, I: Integer;
  LW: TsshWriter;
  LOut: TBytes;
begin
  if FEncrypted then
  begin
    LOut := APayload;
    if FCompEnabled and (FComp <> nil) and SshCompressionIsZlib(FNegCompCs) then
      LOut := FComp.Compress(APayload);
    { 与 transport.SendPacket 同构：body = padlen ‖ 载荷 ‖ 填充 }
    LPad := 8 - ((4 + 1 + SizeUInt(Length(LOut))) mod 8);
    if LPad < SSH_MIN_PADDING then
      Inc(LPad, 8);
    LW := TsshWriter.Create(8 + Length(LOut));
    try
      LW.PutByte(Byte(LPad));
      LW.PutRaw(LOut);
      for I := 1 to LPad do
        LW.PutByte($30);
      LBody := LW.ToBytes;
    finally
      LW.Free;
    end;
    LWire := FSend.Protect(LBody, FSendSeq);
    Inc(FSendSeq);
    FEnd.Write(LWire[0], SizeUInt(Length(LWire)));
  end
  else
  begin
    SendPlainPayload(APayload);
  end;
end;

procedure TSshLoopServer.Handshake;
var
  LLine, LVc, LMyInit, LClientInit, LInit, LMsg, LReply: TBytes;
  LR: TsshReader;
  LEphemeral, LShared, LKmpint, LH, LSig64, LSigBlob: TBytes;
  LXErr: AnsiString;
  LHostPub: TBytes;
  LXPriv, LXPub: TBytes;
  LIvCs, LIvSc, LKeyCs, LKeySc, LMacCs, LMacSc: TBytes;
  LW: TsshWriter;
  LText: string;
  LNl: Integer;
  LIsDH: Boolean;
  LPrime, LGen, LSrvPriv: TBytes;
  LErr: string;
  LClientE: TBytes;
begin
  { 版本串是裸文本，不走二进制帧 }
  LLine := StringToBytes(SERVER_IDENT + #13#10);
  FEnd.Write(LLine[0], SizeUInt(Length(LLine)));
  LVc := nil;
  repeat
    if not RecvRaw(LLine) then
    begin
      Fail('server: no version line');
      Exit;
    end;
    LText := BytesToText(LLine);
    LNl := Pos(#10, LText);
    if LNl > 0 then
    begin
      { 关键：同一 Drain 可能带入后续帧的首批字节，必须退回管道 }
      FEnd.Rewind(SizeUInt(Length(LLine)) - SizeUInt(LNL));
      LText := Trim(Copy(LText, 1, LNl));
      if Copy(LText, 1, 4) = 'SSH-' then
        LVc := StringToBytes(LText);
    end;
  until Length(LVc) > 0;

  LClientInit := ReadPlainFrameBody;
  if (Length(LClientInit) = 0) or (LClientInit[0] <> SSH_MSG_KEXINIT) then
  begin
    Fail('server: expected KEXINIT');
    Exit;
  end;

  if FSc^.ForceDH or FSc^.ForceCompress then
  begin
    LW := TsshWriter.Create(512);
    try
      LW.PutByte(SSH_MSG_KEXINIT);
      LW.PutRaw(PatternBytes($EE, 16));
      if FSc^.ForceDH then
        LW.PutNameList(['diffie-hellman-group14-sha256'])
      else
        LW.PutNameList(['curve25519-sha256', 'curve25519-sha256@libssh.org', 'diffie-hellman-group14-sha256']);
      LW.PutNameList(['ssh-ed25519']);
      LW.PutNameList(['chacha20-poly1305@openssh.com']);
      LW.PutNameList(['chacha20-poly1305@openssh.com']);
      LW.PutNameList([]);
      LW.PutNameList([]);
      if FSc^.ForceCompress then
      begin
        LW.PutNameList(['zlib@openssh.com', 'zlib', 'none']);
        LW.PutNameList(['zlib@openssh.com', 'zlib', 'none']);
      end
      else
      begin
        LW.PutNameList(['none']);
        LW.PutNameList(['none']);
      end;
      LW.PutStringText('');
      LW.PutStringText('');
      LW.PutBoolean(False);
      LW.PutUInt32(0);
      LMyInit := LW.ToBytes;
    finally
      LW.Free;
    end;
  end
  else
    LMyInit := SshBuildKexInitPayload(PatternBytes($EE, 16));
  SendPlainPayload(LMyInit);

  LInit := ReadPlainFrameBody;
  if (Length(LInit) = 0) or (LInit[0] <> SSH_MSG_KEX_ECDH_INIT) then
  begin
    Fail('server: expected KEX INIT');
    Exit;
  end;

  LHostPub := Ed25519PublicKeyFromPrivate(FSc^.HostSeed);
  LIsDH := FSc^.ForceDH;

  if LIsDH then
  begin
    LR := TsshReader.Create(LInit);
    try
      LR.ReadByte;
      LClientE := LR.ReadMPInt;
    finally
      LR.Free;
    end;
    LPrime := SshDHGroup14Prime;
    LGen := SshDHGroup14Generator;
    LSrvPriv := GenerateSecureRandomBytes(32);
    if not TryBigIntModExpFromUnsignedBytes(LGen, LSrvPriv, LPrime, LXPub, LErr) then
    begin
      Fail('server: dh pub failed: ' + LErr);
      Exit;
    end;
    if not TryBigIntModExpFromUnsignedBytes(LClientE, LSrvPriv, LPrime, LShared, LErr) then
    begin
      Fail('server: dh shared failed: ' + LErr);
      Exit;
    end;
    LEphemeral := LClientE;
  end
  else
  begin
    LR := TsshReader.Create(LInit);
    try
      LR.ReadByte;
      LEphemeral := LR.ReadStringBytes;
    finally
      LR.Free;
    end;
    GenerateX25519KeyPair(LXPriv, LXPub);
    if not TryX25519ComputeSharedSecret(LXPriv, LEphemeral, LShared, LXErr) then
    begin
      Fail('server: x25519 failed');
      Exit;
    end;
  end;

  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(LShared);
    LKmpint := LW.ToBytes;
  finally
    LW.Free;
  end;

  if LIsDH then
    LH := SHA256(SshBuildDHGroup14HashInput(
      BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit,
      Ed25519PubBlob(LHostPub), LEphemeral, LXPub, LShared))
  else
    LH := SHA256(SshBuildCurve25519HashInput(
      BytesToText(LVc), SERVER_IDENT, LClientInit, LMyInit,
      Ed25519PubBlob(LHostPub), LEphemeral, LXPub, LShared));
  FSessionId := LH;

  if not Ed25519Sign(FSc^.HostSeed, LH, LSig64) then
  begin
    Fail('server: host sign failed');
    Exit;
  end;
  LSigBlob := SigBlobOf('ssh-ed25519', LSig64);

  LW := TsshWriter.Create(512);
  try
    LW.PutByte(SSH_MSG_KEX_ECDH_REPLY);
    LW.PutStringBytes(Ed25519PubBlob(LHostPub));
    if LIsDH then
      LW.PutMPInt(LXPub)
    else
      LW.PutStringBytes(LXPub);
    LW.PutStringBytes(LSigBlob);
    LReply := LW.ToBytes;
    SendPlainPayload(LReply);
  finally
    LW.Free;
  end;

  { NEWKEYS 往返（均为明文帧）}
  LMsg := ReadPlainFrameBody;
  if Length(LMsg) = 0 then
    Exit;
  if LMsg[0] = SSH_MSG_DISCONNECT then
    Exit;                          { 对端主动放弃（如主机密钥策略拒绝）}
  if LMsg[0] <> SSH_MSG_NEWKEYS then
  begin
    Fail('server: expected NEWKEYS');
    Exit;
  end;
  SendPlainPayload(SingleBytePayloadOf(SSH_MSG_NEWKEYS));

  { RFC 4253 §7.2：服务端方向取 Sc 字母 }
  LIvCs := SshKdfSha256(LKmpint, LH, Ord('A'), FSessionId, SshCipherIvSize(CHACHA_ALG));
  LIvSc := SshKdfSha256(LKmpint, LH, Ord('B'), FSessionId, SshCipherIvSize(CHACHA_ALG));
  LKeyCs := SshKdfSha256(LKmpint, LH, Ord('C'), FSessionId, SshCipherKeySize(CHACHA_ALG));
  LKeySc := SshKdfSha256(LKmpint, LH, Ord('D'), FSessionId, SshCipherKeySize(CHACHA_ALG));
  LMacCs := SshKdfSha256(LKmpint, LH, Ord('E'), FSessionId, SshMacKeySize(''));
  LMacSc := SshKdfSha256(LKmpint, LH, Ord('F'), FSessionId, SshMacKeySize(''));

  FRecv := CreateSshPacketReceiver(CHACHA_ALG, '', LKeyCs, LIvCs, LMacCs);
  FSend := CreateSshPacketSender(CHACHA_ALG, '', LKeySc, LIvSc, LMacSc);
  { RFC 4253 §6.4：序列号跨 NEWKEYS 连续，不清零。
    本端已收客户端明文帧 ×3（KEXINIT/ECDH_INIT/NEWKEYS），
    已发明文帧 ×3（KEXINIT/REPLY/NEWKEYS）。}
  FRecvSeq := 3;
  FSendSeq := 3;
  FEncrypted := True;
  if FSc^.ForceCompress then
  begin
    FNegCompCs := SSH_COMP_ZLIB_OPENSSH;
    FNegCompSc := SSH_COMP_ZLIB_OPENSSH;
    FComp := CreateSshZlibCompressor;
    FCompEnabled := False; { delayed: USERAUTH_SUCCESS 后启用 }
  end
  else
  begin
    FNegCompCs := SSH_COMP_NONE;
    FNegCompSc := SSH_COMP_NONE;
  end;
end;

procedure TSshLoopServer.ServeApp;
var
  LMsg: TBytes;
  LR: TsshReader;
  LUser, LMethod, LPass, LAlg, LReqName: string;
  LPassOk, LWantReply, LHasSig: Boolean;
  LPubBlob, LSigBlob, LSigRaw, LSignedData: TBytes;
  LRsaE, LRsaN: TBytes;
  LRid: UInt32;
  LRAlg: TsshReader;
  LW: TsshWriter;
begin
  while True do
  begin
    LMsg := ReadAnyPayload;
    if Length(LMsg) = 0 then
      Exit;
    Inc(FSc^.MsgCount);
    if FSc^.MsgCount = 1 then
    begin
      FSc^.Msg1Type := LMsg[0];
      FSc^.Msg1Len := Length(LMsg);
    end;
    case LMsg[0] of
      SSH_MSG_IGNORE:
        Inc(FSc^.IgnoreCount);
      SSH_MSG_DISCONNECT:
        Exit;

      SSH_MSG_SERVICE_REQUEST:
        begin
          LW := TsshWriter.Create(32);
          try
            LW.PutByte(SSH_MSG_SERVICE_ACCEPT);
            LW.PutStringText(SSH_SERVICE_USERAUTH);
            ReplyPayload(LW.ToBytes);
          finally
            LW.Free;
          end;
        end;

      SSH_MSG_USERAUTH_REQUEST:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LUser := LR.ReadStringText;
            LR.ReadStringText;                 { service }
            LMethod := LR.ReadStringText;
            LPassOk := False;
            if LMethod = 'password' then
            begin
              LR.ReadBoolean;                  { 不改密标志 }
              LPass := LR.ReadStringText;
              LPassOk := (LUser = FSc^.AcceptUser)
                and FSc^.PasswordOk and (LPass = FSc^.AcceptPassword);
            end
            else if LMethod = 'publickey' then
            begin
              LPassOk := False;
              begin
                // RFC 4252 §7: first packet has hasSig=false (probe), second hasSig=true+sig
                // We must branch: probe → PK_OK or FAILURE, signed → verify then SUCCESS/FAILURE
                LHasSig := LR.ReadBoolean;
                LAlg := LR.ReadStringText;
                LPubBlob := LR.ReadStringBytes;
                if not LHasSig then
                begin
                  // Probe: no signature blob to read
                  if FSc^.PubKeyOk then
                  begin
                    LW := TsshWriter.Create(64);
                    try
                      LW.PutByte(SSH_MSG_USERAUTH_PK_OK);
                      LW.PutStringText(LAlg);
                      LW.PutStringBytes(LPubBlob);
                      ReplyPayload(LW.ToBytes);
                    finally
                      LW.Free;
                    end;
                  end
                  else
                  begin
                    LW := TsshWriter.Create(48);
                    try
                      LW.PutByte(SSH_MSG_USERAUTH_FAILURE);
                      LW.PutStringText('password,publickey');
                      LW.PutBoolean(False);
                      ReplyPayload(LW.ToBytes);
                    finally
                      LW.Free;
                    end;
                  end;
                  Continue;
                end;
                // Signed request
                LSigBlob := LR.ReadStringBytes;
                if FSc^.PubKeyOk and (LAlg = 'ssh-ed25519')
                  and (Length(LSigBlob) > 0) then
                begin
                  LSigRaw := nil;
                  LRAlg := TsshReader.Create(LSigBlob);
                  try
                    LRAlg.ReadStringText;
                    LSigRaw := LRAlg.ReadStringBytes;
                  finally
                    LRAlg.Free;
                  end;
                  LSignedData := SshAuthSignedData(FSessionId, LUser,
                    'ssh-ed25519', LPubBlob);
                  LPassOk := Ed25519Verify(Copy(LPubBlob,
                    Length(LPubBlob) - 32, 32), LSignedData, LSigRaw);
                end
                else if FSc^.PubKeyOk and (Length(LSigBlob) > 0)
                  and ((LAlg = 'rsa-sha2-512') or (LAlg = 'rsa-sha2-256')) then
                begin
                  LSigRaw := nil;
                  LRAlg := TsshReader.Create(LSigBlob);
                  try
                    LRAlg.ReadStringText;
                    LSigRaw := LRAlg.ReadStringBytes;
                  finally
                    LRAlg.Free;
                  end;
                  LRAlg := TsshReader.Create(LPubBlob);
                  try
                    LRAlg.ReadStringText;
                    LRsaE := LRAlg.ReadMPInt;
                    LRsaN := LRAlg.ReadMPInt;
                  finally
                    LRAlg.Free;
                  end;
                  LSignedData := SshAuthSignedData(FSessionId, LUser, LAlg, LPubBlob);
                  if LAlg = 'rsa-sha2-512' then
                    LPassOk := RsaVerifyPkcs1v15(LRsaE, LRsaN,
                      SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw)
                  else
                    LPassOk := RsaVerifyPkcs1v15(LRsaE, LRsaN,
                      SHA256(LSignedData), DIGEST_INFO_SHA256, LSigRaw);
                end;
              end;
            end;
          finally
            LR.Free;
          end;
          if LPassOk then
          begin
            ReplyPayload(SingleBytePayloadOf(SSH_MSG_USERAUTH_SUCCESS));
            if SshCompressionIsDelayed(FNegCompSc) or SshCompressionIsDelayed(FNegCompCs) then
              FCompEnabled := True;
          end
          else
          begin
            LW := TsshWriter.Create(48);
            try
              LW.PutByte(SSH_MSG_USERAUTH_FAILURE);
              LW.PutStringText('password,publickey');
              LW.PutBoolean(False);
              ReplyPayload(LW.ToBytes);
            finally
              LW.Free;
            end;
          end;
        end;

      SSH_MSG_CHANNEL_OPEN:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LR.ReadStringText;                 { 'session' }
            LRid := LR.ReadUInt32;
            FClientChannelId := LRid;
          finally
            LR.Free;
          end;
          LW := TsshWriter.Create(48);
          try
            LW.PutByte(SSH_MSG_CHANNEL_OPEN_CONFIRMATION);
            LW.PutUInt32(LRid);
            LW.PutUInt32(SRV_CHANNEL_ID);
            LW.PutUInt32(SRV_RECV_WINDOW);
            LW.PutUInt32(32768);
            ReplyPayload(LW.ToBytes);
          finally
            LW.Free;
          end;
        end;

      SSH_MSG_CHANNEL_REQUEST:
        begin
          LR := TsshReader.Create(LMsg);
          try
            LR.ReadByte;
            LR.ReadUInt32;
            LReqName := LR.ReadStringText;
            LWantReply := LR.ReadBoolean;
            if LReqName = SSH_REQ_EXEC then
            begin
              if LWantReply then
                ReplyPayload(ChannelReplyPayload(FClientChannelId, True));
              { 推送输出计划：两段 stdout、一段 stderr、exit-status }
              LW := TsshWriter.Create(64);
              try
                LW.PutByte(SSH_MSG_CHANNEL_DATA);
                LW.PutUInt32(FClientChannelId);
                LW.PutStringBytes(FSc^.StdOut1);
                ReplyPayload(LW.ToBytes);
              finally
                LW.Free;
              end;
              LW := TsshWriter.Create(64);
              try
                LW.PutByte(SSH_MSG_CHANNEL_DATA);
                LW.PutUInt32(FClientChannelId);
                LW.PutStringBytes(FSc^.StdOut2);
                ReplyPayload(LW.ToBytes);
              finally
                LW.Free;
              end;
              LW := TsshWriter.Create(64);
              try
                LW.PutByte(SSH_MSG_CHANNEL_EXTENDED_DATA);
                LW.PutUInt32(FClientChannelId);
                LW.PutUInt32(SSH_EXTENDED_DATA_STDERR);
                LW.PutStringBytes(FSc^.StdErr);
                ReplyPayload(LW.ToBytes);
              finally
                LW.Free;
              end;
              LW := TsshWriter.Create(32);
              try
                LW.PutByte(SSH_MSG_CHANNEL_REQUEST);
                LW.PutUInt32(FClientChannelId);
                LW.PutStringText(SSH_REQ_EXIT_STATUS);
                LW.PutBoolean(True);
                LW.PutUInt32(FSc^.ExitCode);
                ReplyPayload(LW.ToBytes);
              finally
                LW.Free;
              end;
              { OpenSSH 语义：命令结束即关闭通道；CLOSE 同样带 recipient }
              ReplyPayload(ClosePayload(FClientChannelId));
            end
            else if LWantReply then
              ReplyPayload(ChannelReplyPayload(FClientChannelId, False));
          finally
            LR.Free;
          end;
        end;

      SSH_MSG_CHANNEL_WINDOW_ADJUST, SSH_MSG_CHANNEL_EOF, SSH_MSG_CHANNEL_SUCCESS:
        ;                                { 回补/EOF/exit-ack 帧容忍 }

      SSH_MSG_CHANNEL_CLOSE:
        begin
          ReplyPayload(ClosePayload(FClientChannelId));
          Exit;
        end;
    end;
  end;
end;

procedure TSshLoopServer.Run;
begin
  try
    Handshake;
    if FEncrypted then
      ServeApp;
  except
    on E: Exception do
      Fail(E.Message);
  end;
  FSc^.Done := True;
end;

{ ── 场景驱动 ─────────────────────────────────────────────────── }

type
  PSync = ^TSync;
  TSync = record
    Scenario: PSshLoopServerScenario;
    ServerEnd: TMemPipeEnd;
    ThreadDone: Boolean;
    DoneEvent: PRTLEvent;
  end;

function ServerThreadMain(AParam: Pointer): PtrInt;
var
  LSrv: TSshLoopServer;
begin
  Result := 0;
  LSrv := TSshLoopServer.Create(PSync(AParam)^.ServerEnd, PSync(AParam)^.Scenario);
  try
    LSrv.Run;
  finally
    LSrv.Free;
    PSync(AParam)^.ThreadDone := True;
    RTLEventSetEvent(PSync(AParam)^.DoneEvent);
  end;
end;

const
  CLIENT_USER = 'alice';
  CLIENT_PASSWORD = 's3cret!';
  HOST_SEED_HEX = 'e7d3f1a209c84b5b6d2e8a70913c4455aabbccddeeff01233455667788990011';

{ ── 客户端私钥 PEM（openssh-key-v1 未加密 ed25519，与 test_ssh_keys 同构）── }

{ 私段：checkint x2 || string(keytype) || string(pub) || string(seed||pub) || comment }
function MakePrivSection(const AKeyType: string; ACheck: UInt32;
  const APub, ASeed: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(256);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText(AKeyType);
    LW.PutStringBytes(Copy(APub, 0, 32));
    LW.PutStringBytes(ConcatBytes(ASeed, Copy(APub, 0, 32)));
    LW.PutStringText('loop client key');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ 容器：magic || cipher || kdf || kdfoptions || nkeys || pubkey || privsection }
function CraftContainer(const APubBlob, APrivSection: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(512);
  try
    LW.PutRaw(StringToBytes('openssh-key-v1'));
    LW.PutByte(0);
    LW.PutStringText('none');
    LW.PutStringText('none');
    LW.PutStringText('');
    LW.PutUInt32(1);
    LW.PutStringBytes(APubBlob);
    LW.PutStringBytes(APrivSection);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ RSA 公钥 wire blob：string("ssh-rsa") || mpint e || mpint n }
function RsaPubBlob(const AE, AN: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(64);
  try
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AE);
    LW.PutMPInt(AN);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ RSA 私段：checkint x2 || string(type) || mpint n,e,d,iqmp,p,q || comment }
function MakeRsaPrivSection(ACheck: UInt32; const AN, AE, AD: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(512);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AN);
    LW.PutMPInt(AE);
    LW.PutMPInt(AD);
    LW.PutMPInt(PatternBytes($AA, 128));
    LW.PutMPInt(PatternBytes($BB, 128));
    LW.PutMPInt(PatternBytes($CC, 128));
    LW.PutStringText('loop client key');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function MakeRsaPrivSectionCrt(ACheck: UInt32; const AN, AE, AD, AP, AQ, AIqmp: TBytes): TBytes;
var
  LW: TsshWriter;
begin
  Result := nil;
  LW := TsshWriter.Create(768);
  try
    LW.PutUInt32(ACheck);
    LW.PutUInt32(ACheck);
    LW.PutStringText('ssh-rsa');
    LW.PutMPInt(AN);
    LW.PutMPInt(AE);
    LW.PutMPInt(AD);
    LW.PutMPInt(AIqmp);
    LW.PutMPInt(AP);
    LW.PutMPInt(AQ);
    LW.PutStringText('loop client key crt');
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

function Base64Chunked(const AData: TBytes): string;
var
  LB64: string;
  I: Integer;
begin
  LB64 := Base64Encode(AData);
  Result := '';
  for I := 1 to Length(LB64) do
  begin
    Result := Result + LB64[I];
    if (I mod 70) = 0 then
      Result := Result + #10;
  end;
end;

function PemOf(const AContainer: TBytes): string;
begin
  Result := '-----BEGIN OPENSSH PRIVATE KEY-----' + #10
    + Base64Chunked(AContainer)
    + '-----END OPENSSH PRIVATE KEY-----' + #10;
end;

function PadTo16(const AData: TBytes): TBytes;
var
  LPad, I: Integer;
begin
  Result := Copy(AData, 0, Length(AData));
  LPad := (16 - (Length(Result) mod 16)) mod 16;
  for I := 1 to LPad do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Byte(I);
  end;
end;

function CraftEncryptedContainer(const APass, ASalt: string; ARounds: Cardinal;
  const APubBlob, APrivRaw: TBytes): TBytes;
var
  LPw, LSaltBytes, LDerived, LAesKey, LAiv, LPadded, LEnc, LKdfOpt: TBytes;
  LW: TsshWriter;
  LErr: string;
begin
  LPw := StringToBytes(APass);
  LSaltBytes := StringToBytes(ASalt);
  if not TryBcryptPbkdf(LPw, LSaltBytes, 48, ARounds, LDerived, LErr) then
    raise Exception.Create('craft encrypted: pbkdf failed: ' + LErr);
  SetLength(LAesKey, 32);
  SetLength(LAiv, 16);
  Move(LDerived[0], LAesKey[0], 32);
  Move(LDerived[32], LAiv[0], 16);
  LPadded := PadTo16(APrivRaw);
  LEnc := SshAesCtrCrypt(LAesKey, LAiv, LPadded);
  LW := TsshWriter.Create(64);
  try
    LW.PutStringBytes(LSaltBytes);
    LW.PutUInt32(ARounds);
    LKdfOpt := LW.ToBytes;
  finally
    LW.Free;
  end;
  LW := TsshWriter.Create(512);
  try
    LW.PutRaw(StringToBytes('openssh-key-v1'));
    LW.PutByte(0);
    LW.PutStringText('aes256-ctr');
    LW.PutStringText('bcrypt');
    LW.PutStringBytes(LKdfOpt);
    LW.PutUInt32(1);
    LW.PutStringBytes(APubBlob);
    LW.PutStringBytes(LEnc);
    Result := LW.ToBytes;
  finally
    LW.Free;
  end;
end;

{ ── 回环驱动 ─────────────────────────────────────────────────── }

const
  LOOP_PASSWORD = 0;
  LOOP_PUBKEY = 1;
  LOOP_PUBKEY_RSA = 2;
  LOOP_PUBKEY_ENCRYPTED = 3;
  LOOP_PUBKEY_RSA_CRT = 4;
  KH_PATH = '/tmp/nextpas_ssh_session_known_hosts';
  ENC_PASSPHRASE = 's3cret-pass-42';
  ENC_SALT = 'salty12345678901';
  ENC_ROUNDS = 16;

type
  TLoopResult = record
    ClientFailed: Boolean;
    ClientErrKind: TSshErrorKind;
    ClientErrMsg: string;
    ServerFailed: Boolean;
    ServerErrMsg: string;
    ServerMsgCount: Integer;
    ServerMsg1Type: Byte;
    ServerMsg1Len: Integer;
    ServerVersion: string;
    Fingerprint: string;
    Exec: TSshExecResult;
  end;

{ 起服务线程，跑一轮真实客户端：握手 → 认证 → exec → 关闭 }
function RunLoopback(AMode: Integer; APasswordOk, APubKeyOk: Boolean;
  const AKnownHostsFile: string; AStrictHostKey: Boolean;
  AForceDH: Boolean = False; AForceCompress: Boolean = False): TLoopResult;
var
  LSc: PSshLoopServerScenario;
  LSync: PSync;
  LShared: PPipeShared;
  LClientEnd, LServerEnd: TMemPipeEnd;
  LThreadId: TThreadID;
  LOpts: TSshConnectOptions;
  LSession: ISshSession;
  LSeed, LPub, LContainer: TBytes;
  LWaitMs: Integer;
begin
  Result := Default(TLoopResult);
  LClientEnd := nil;
  LServerEnd := nil;
  LShared := nil;
  New(LSc);
  New(LSync);
  try
    LSc^.AcceptUser := CLIENT_USER;
    LSc^.AcceptPassword := CLIENT_PASSWORD;
    LSc^.PasswordOk := APasswordOk;
    LSc^.PubKeyOk := APubKeyOk;
    LSc^.StdOut1 := StringToBytes('stdout-part-one|');
    LSc^.StdOut2 := StringToBytes('stdout-part-two!');
    LSc^.StdErr := StringToBytes('warn: loop stderr');
    LSc^.ExitCode := 7;
    LSc^.HostSeed := PatternBytes($E7, 32);
    LSc^.ForceDH := AForceDH;
    LSc^.ForceCompress := AForceCompress;
    LSc^.Failed := False;
    LSc^.FailMsg := '';
    LSc^.Done := False;
    LSc^.MsgCount := 0;
    LSc^.Msg1Type := 0;
    LSc^.Msg1Len := 0;

    LSync^.Scenario := LSc;
    LSync^.ServerEnd := nil;
    LSync^.ThreadDone := False;
    LSync^.DoneEvent := RTLEventCreate;
    try
      MakePipe(LClientEnd, LServerEnd, LShared);
      LSync^.ServerEnd := LServerEnd;
      BeginThread(@ServerThreadMain, Pointer(LSync), LThreadId);

      LOpts := DefaultSshConnectOptions(CLIENT_HOST_NAME);
      LOpts.User := CLIENT_USER;
      if AMode = LOOP_PASSWORD then
        LOpts.Password := CLIENT_PASSWORD
      else if AMode = LOOP_PUBKEY_RSA then
      begin
        LOpts.PrivateKeyData := PemOf(CraftContainer(
          RsaPubBlob(HexToBytesKat(KAT_E_HEX), KatN),
          MakeRsaPrivSection($A1B2C3D4, KatN,
            HexToBytesKat(KAT_E_HEX), KatD)));
      end
      else if AMode = LOOP_PUBKEY_RSA_CRT then
      begin
        { 真实 CRT 路径：服务端同样走 PKCS#1 验签，客户端优先走 CRT }
        LOpts.PrivateKeyData := PemOf(CraftContainer(
          RsaPubBlob(HexToBytesKat(KAT_E_HEX), CrtKatN),
          MakeRsaPrivSectionCrt($A1B2C3D4, CrtKatN, HexToBytesKat(KAT_E_HEX),
            CrtKatD, CrtKatP, CrtKatQ, CrtKatIqmp)));
      end
      else if AMode = LOOP_PUBKEY_ENCRYPTED then
      begin
        LSeed := PatternBytes($3D, 32);
        LPub := Ed25519PublicKeyFromPrivate(LSeed);
        LContainer := CraftEncryptedContainer(ENC_PASSPHRASE, ENC_SALT, ENC_ROUNDS,
          Ed25519PubBlob(LPub),
          MakePrivSection('ssh-ed25519', $A1B2C3D4, LPub, LSeed));
        LOpts.PrivateKeyData := PemOf(LContainer);
        LOpts.PrivateKeyPassphrase := ENC_PASSPHRASE;
      end
      else
      begin
        LSeed := PatternBytes($3D, 32);
        LPub := Ed25519PublicKeyFromPrivate(LSeed);
        LContainer := CraftContainer(
          Ed25519PubBlob(LPub),
          MakePrivSection('ssh-ed25519', $A1B2C3D4, LPub, LSeed));
        LOpts.PrivateKeyData := PemOf(LContainer);
      end;
      LOpts.KnownHostsFile := AKnownHostsFile;
      LOpts.StrictHostKeyChecking := AStrictHostKey;
      LOpts.Compress := AForceCompress;
      LOpts.ExecTimeoutMs := 30000;
      LOpts.InitialWindowSize := 16;   { 迫使客户端发送 WINDOW_ADJUST }

      try
        LSession := SshConnectOn(LClientEnd, LOpts);
        try
          Result.ServerVersion := LSession.ServerVersion;
          Result.Fingerprint := LSession.ServerHostKeyFingerprint;
          Result.Exec := LSession.Exec('echo loop');
        finally
          LSession.Close;
          LSession := nil;
        end;
      except
        on E: ESSHError do
        begin
          Result.ClientFailed := True;
          Result.ClientErrKind := E.Kind;
          Result.ClientErrMsg := E.Message;
        end;
        on E: Exception do
        begin
          Result.ClientFailed := True;
          Result.ClientErrMsg := E.ClassName + ': ' + E.Message;
        end;
      end;

      { 等服务线程收尾（最长 20s）}
      LWaitMs := 0;
      while (not LSync^.ThreadDone) and (LWaitMs < 20000) do
      begin
        RTLEventWaitFor(LSync^.DoneEvent, 100);
        Inc(LWaitMs, 100);
      end;
      Result.ServerFailed := LSc^.Failed;
      Result.ServerErrMsg := LSc^.FailMsg;
      Result.ServerMsgCount := LSc^.MsgCount;
      Result.ServerMsg1Type := LSc^.Msg1Type;
      Result.ServerMsg1Len := LSc^.Msg1Len;
    finally
      RTLEventDestroy(LSync^.DoneEvent);
      LClientEnd.Free;
      LServerEnd.Free;
      if LShared <> nil then
      begin
        DoneCriticalSection(LShared^.Lock);
        Dispose(LShared);
      end;
      Dispose(LSync);
    end;
  finally
    Dispose(LSc);
  end;
end;

{ ── agent 回环驱动（S14） ───────────────────────────────────── }

type
  TFakeAgentLoop = class
  private
    FEnd: TMemPipeEnd;
    FEdSeed, FEdPub, FEdBlob: TBytes;
    FRsaN, FRsaE, FRsaD, FRsaP, FRsaQ, FRsaIqmp, FRsaBlob: TBytes;
    FHasEd, FHasRsa: Boolean;
    function ReadMsg(out APayload: TBytes): Boolean;
    procedure WriteMsg(const APayload: TBytes);
  public
    constructor Create(AEnd: TMemPipeEnd; AHasEd, AHasRsa: Boolean);
    procedure Run;
  end;

  PAgentLoopSync = ^TAgentLoopSync;
  TAgentLoopSync = record
    AgentEnd: TMemPipeEnd;
    HasEd, HasRsa: Boolean;
    Done: Boolean;
    DoneEvent: PRTLEvent;
  end;

constructor TFakeAgentLoop.Create(AEnd: TMemPipeEnd; AHasEd, AHasRsa: Boolean);
begin
  inherited Create;
  FEnd := AEnd;
  FHasEd := AHasEd;
  FHasRsa := AHasRsa;
  if FHasEd then
  begin
    FEdSeed := PatternBytes($3D, 32);
    FEdPub := Ed25519PublicKeyFromPrivate(FEdSeed);
    FEdBlob := Ed25519PubBlob(FEdPub);
  end;
  if FHasRsa then
  begin
    FRsaN := CrtKatN();
    FRsaE := CrtKatE();
    FRsaD := CrtKatD();
    FRsaP := CrtKatP();
    FRsaQ := CrtKatQ();
    FRsaIqmp := CrtKatIqmp();
    FRsaBlob := RsaPubBlob(FRsaE, FRsaN);
  end;
end;

function TFakeAgentLoop.ReadMsg(out APayload: TBytes): Boolean;
var
  LLenBytes: array[0..3] of Byte;
  LLen: UInt32;
  LBuf: TBytes;
  LGot: SizeUInt;
begin
  Result := False;
  APayload := nil;
  SetLength(LBuf, 4);
  LGot := 0;
  while LGot < 4 do
  begin
    LGot := LGot + FEnd.Read(LBuf[LGot], 4 - LGot);
    if LGot = 0 then Exit;
  end;
  LLenBytes[0] := LBuf[0]; LLenBytes[1] := LBuf[1]; LLenBytes[2] := LBuf[2]; LLenBytes[3] := LBuf[3];
  LLen := (UInt32(LLenBytes[0]) shl 24) or (UInt32(LLenBytes[1]) shl 16) or (UInt32(LLenBytes[2]) shl 8) or UInt32(LLenBytes[3]);
  if LLen > 1024 * 1024 then Exit;
  SetLength(APayload, LLen);
  LGot := 0;
  while LGot < LLen do
  begin
    LGot := LGot + FEnd.Read(APayload[LGot], LLen - LGot);
    if LGot = 0 then Exit;
  end;
  Result := True;
end;

procedure TFakeAgentLoop.WriteMsg(const APayload: TBytes);
var
  LW2: TsshWriter;
  LFrame: TBytes;
begin
  LW2 := TsshWriter.Create(4 + Length(APayload));
  try
    LW2.PutUInt32(UInt32(Length(APayload)));
    if Length(APayload) > 0 then LW2.PutRaw(APayload);
    LFrame := LW2.ToBytes;
  finally
    LW2.Free;
  end;
  FEnd.Write(LFrame[0], SizeUInt(Length(LFrame)));
end;

procedure TFakeAgentLoop.Run;
var
  LReq, LResp: TBytes;
  LR2: TsshReader;
  LW2: TsshWriter;
  LBlob, LData: TBytes;
  LFlags: UInt32;
  LSig64, LSigRaw, LSigBlob: TBytes;
begin
  while ReadMsg(LReq) do
  begin
    if Length(LReq) = 0 then Break;
    case LReq[0] of
      SSH_AGENTC_REQUEST_IDENTITIES:
        begin
          LW2 := TsshWriter.Create(128);
          try
            LW2.PutByte(SSH_AGENT_IDENTITIES_ANSWER);
            if FHasEd and FHasRsa then
            begin LW2.PutUInt32(2); LW2.PutStringBytes(FEdBlob); LW2.PutStringText('ed25519 fake'); LW2.PutStringBytes(FRsaBlob); LW2.PutStringText('rsa fake'); end
            else if FHasEd then
            begin LW2.PutUInt32(1); LW2.PutStringBytes(FEdBlob); LW2.PutStringText('ed25519 fake'); end
            else if FHasRsa then
            begin LW2.PutUInt32(1); LW2.PutStringBytes(FRsaBlob); LW2.PutStringText('rsa fake'); end
            else LW2.PutUInt32(0);
            LResp := LW2.ToBytes;
          finally LW2.Free; end;
          WriteMsg(LResp);
        end;
      SSH_AGENTC_SIGN_REQUEST:
        begin
          LR2 := TsshReader.Create(LReq);
          try LR2.ReadByte; LBlob := LR2.ReadStringBytes; LData := LR2.ReadStringBytes; LFlags := LR2.ReadUInt32; finally LR2.Free; end;
          LSigBlob := nil;
          if FHasEd and (Length(LBlob) = Length(FEdBlob)) and CompareMem(@LBlob[0], @FEdBlob[0], Length(LBlob)) then
          begin
            if not Ed25519Sign(FEdSeed, LData, LSig64) then
            begin LW2 := TsshWriter.Create(1); try LW2.PutByte(SSH_AGENT_FAILURE); LResp := LW2.ToBytes; finally LW2.Free; end; WriteMsg(LResp); Continue; end;
            LSigBlob := SshBuildEd25519SigBlob(LSig64);
          end
          else if FHasRsa and (Length(LBlob) = Length(FRsaBlob)) and CompareMem(@LBlob[0], @FRsaBlob[0], Length(LBlob)) then
          begin
            if LFlags = SSH_AGENT_RSA_SHA2_256 then
            begin if not RsaSignPkcs1v15(FRsaN, FRsaD, SHA256(LData), DIGEST_INFO_SHA256, LSigRaw) then begin LW2 := TsshWriter.Create(1); try LW2.PutByte(SSH_AGENT_FAILURE); LResp := LW2.ToBytes; finally LW2.Free; end; WriteMsg(LResp); Continue; end; LSigBlob := SshBuildRsaSigBlob(LSigRaw, 'rsa-sha2-256'); end
            else
            begin if not RsaSignPkcs1v15Crt(FRsaN, FRsaD, FRsaP, FRsaQ, FRsaIqmp, SHA512(LData), DIGEST_INFO_SHA512, LSigRaw) then if not RsaSignPkcs1v15(FRsaN, FRsaD, SHA512(LData), DIGEST_INFO_SHA512, LSigRaw) then begin LW2 := TsshWriter.Create(1); try LW2.PutByte(SSH_AGENT_FAILURE); LResp := LW2.ToBytes; finally LW2.Free; end; WriteMsg(LResp); Continue; end; LSigBlob := SshBuildRsaSigBlob(LSigRaw, 'rsa-sha2-512'); end;
          end
          else
          begin LW2 := TsshWriter.Create(1); try LW2.PutByte(SSH_AGENT_FAILURE); LResp := LW2.ToBytes; finally LW2.Free; end; WriteMsg(LResp); Continue; end;
          LW2 := TsshWriter.Create(128);
          try LW2.PutByte(SSH_AGENT_SIGN_RESPONSE); LW2.PutStringBytes(LSigBlob); LResp := LW2.ToBytes; finally LW2.Free; end;
          WriteMsg(LResp);
        end;
      else
        begin LW2 := TsshWriter.Create(1); try LW2.PutByte(SSH_AGENT_FAILURE); LResp := LW2.ToBytes; finally LW2.Free; end; WriteMsg(LResp); end;
    end;
  end;
end;

function AgentLoopThreadMain(AParam: Pointer): PtrInt;
var
  L: TFakeAgentLoop;
  S: PAgentLoopSync;
begin
  Result := 0;
  S := PAgentLoopSync(AParam);
  L := TFakeAgentLoop.Create(S^.AgentEnd, S^.HasEd, S^.HasRsa);
  try L.Run; finally L.Free; S^.Done := True; RTLEventSetEvent(S^.DoneEvent); end;
end;

function RunLoopbackAgent(AHasEd, AHasRsa: Boolean; AServerAccept: Boolean; AForceDH: Boolean = False; AForceCompress: Boolean = False): TLoopResult;
var
  LSc: PSshLoopServerScenario;
  LSyncSsh: PSync;
  LSharedSsh, LSharedAgent: PPipeShared;
  LClientEnd, LServerEnd: TMemPipeEnd;
  LAgentClient, LAgentServer: TMemPipeEnd;
  LThreadSsh: TThreadID;
  LSyncAgent: PAgentLoopSync;
  LAgentThread: TThreadID;
  LOpts: TSshConnectOptions;
  LSession: ISshSession;
  LWait: Integer;
begin
  Result := Default(TLoopResult);
  LClientEnd := nil; LServerEnd := nil; LSharedSsh := nil;
  LAgentClient := nil; LAgentServer := nil; LSharedAgent := nil;
  New(LSc); New(LSyncSsh); GetMem(LSyncAgent, SizeOf(TAgentLoopSync));
  try
    LSc^.AcceptUser := CLIENT_USER;
    LSc^.AcceptPassword := CLIENT_PASSWORD;
    LSc^.PasswordOk := False;
    LSc^.PubKeyOk := AServerAccept;
    LSc^.StdOut1 := StringToBytes('agent-stdout|');
    LSc^.StdOut2 := StringToBytes('ok!');
    LSc^.StdErr := StringToBytes('');
    LSc^.ExitCode := 7;
    LSc^.HostSeed := PatternBytes($E7, 32);
    LSc^.ForceDH := AForceDH;
    LSc^.ForceCompress := AForceCompress;
    LSc^.Failed := False; LSc^.FailMsg := ''; LSc^.Done := False;
    LSc^.MsgCount := 0; LSc^.Msg1Type := 0; LSc^.Msg1Len := 0;
    LSyncSsh^.Scenario := LSc; LSyncSsh^.ServerEnd := nil; LSyncSsh^.ThreadDone := False; LSyncSsh^.DoneEvent := RTLEventCreate;
    LSyncAgent^.HasEd := AHasEd; LSyncAgent^.HasRsa := AHasRsa; LSyncAgent^.Done := False; LSyncAgent^.DoneEvent := RTLEventCreate;
    try
      MakePipe(LClientEnd, LServerEnd, LSharedSsh);
      MakePipe(LAgentClient, LAgentServer, LSharedAgent);
      LSyncSsh^.ServerEnd := LServerEnd;
      LSyncAgent^.AgentEnd := LAgentServer;
      BeginThread(@AgentLoopThreadMain, Pointer(LSyncAgent), LAgentThread);
      BeginThread(@ServerThreadMain, Pointer(LSyncSsh), LThreadSsh);

      LOpts := DefaultSshConnectOptions(CLIENT_HOST_NAME);
      LOpts.User := CLIENT_USER;
      LOpts.Compress := AForceCompress;
      LOpts.ExecTimeoutMs := 30000;
      LOpts.InitialWindowSize := 16;

      try
        LSession := SshCreateSession(LClientEnd, LOpts);
        try
          LSession.AuthenticateWithAgentOn(LAgentClient);
          Result.ServerVersion := LSession.ServerVersion;
          Result.Fingerprint := LSession.ServerHostKeyFingerprint;
          Result.Exec := LSession.Exec('echo agent');
        finally
          LSession.Close;
          LSession := nil;
        end;
      except
        on E: ESSHError do
        begin Result.ClientFailed := True; Result.ClientErrKind := E.Kind; Result.ClientErrMsg := E.Message; end;
        on E: Exception do
        begin Result.ClientFailed := True; Result.ClientErrMsg := E.ClassName + ': ' + E.Message; end;
      end;

      LWait := 0;
      while (not LSyncSsh^.ThreadDone) and (LWait < 20000) do
      begin RTLEventWaitFor(LSyncSsh^.DoneEvent, 100); Inc(LWait, 100); end;
      Result.ServerFailed := LSc^.Failed;
      Result.ServerErrMsg := LSc^.FailMsg;
      Result.ServerMsgCount := LSc^.MsgCount;
      // tear down agent
      LAgentClient.Close;
      LAgentServer.Close;
      LWait := 0;
      while (not LSyncAgent^.Done) and (LWait < 2000) do
      begin RTLEventWaitFor(LSyncAgent^.DoneEvent, 100); Inc(LWait, 100); end;
    finally
      RTLEventDestroy(LSyncSsh^.DoneEvent);
      RTLEventDestroy(LSyncAgent^.DoneEvent);
      LClientEnd.Free; LServerEnd.Free;
      LAgentClient.Free; LAgentServer.Free;
      if LSharedSsh <> nil then begin DoneCriticalSection(LSharedSsh^.Lock); Dispose(LSharedSsh); end;
      if LSharedAgent <> nil then begin DoneCriticalSection(LSharedAgent^.Lock); Dispose(LSharedAgent); end;
      Dispose(LSyncSsh);
    end;
  finally
    Dispose(LSc);
    FreeMem(LSyncAgent);
  end;
end;

var
  GRunner: TSuiteRunner;
  GSuite: TTestSuite;

begin
  GSuite := TTestSuite.Create('ssh session');

  { 场景一：密码认证正路径全栈回环 }
  GSuite.Test('password auth loopback: exec collects stdout/stderr/exit-code', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PASSWORD, True, False, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckTrue(Pos('NextPas-LoopServer', LR.ServerVersion) > 0,
      'server version observed: "' + LR.ServerVersion + '"');
    CheckTrue(Copy(LR.Fingerprint, 1, 7) = 'SHA256:',
      'fingerprint shape: ' + LR.Fingerprint);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    CheckEqual('stdout-part-one|stdout-part-two!', LR.Exec.StdOutText, 'stdout');
    CheckEqual('warn: loop stderr', LR.Exec.StdErrText, 'stderr');
  end);

  { 场景二：密码被拒 → sekAuth，服务端优雅走 DISCONNECT }
  GSuite.Test('wrong password rejected as sekAuth', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PASSWORD, False, False, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(LR.ClientFailed, 'client must fail');
    CheckEqual(Ord(sekAuth), Ord(LR.ClientErrKind), 'error kind');
  end);

  { 场景三：publickey 签名认证全栈回环 }
  GSuite.Test('publickey auth loopback', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY, True, True, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  { 场景三b：RSA 私钥（rsa-sha2-512）publickey 认证全栈回环。
    客户端走 SshLoadPrivateKey→RsaSignPkcs1v15 真实签名路径，
    服务端解析 blob 后按算法哈希做 PKCS#1 v1.5 验签。}
  GSuite.Test('publickey rsa auth loopback', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY_RSA, True, True, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('publickey rsa CRT auth loopback', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY_RSA_CRT, True, True, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('publickey encrypted ed25519 auth loopback', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY_ENCRYPTED, True, True, '', False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  { 场景四：严格模式 + known_hosts 未命中 → sekHostKey }
  GSuite.Test('strict host key rejects unknown server', procedure
  var
    LR: TLoopResult;
    LOtherPub: TBytes;
  begin
    { 合法的其他主机密钥：确保拒绝原因是"未收录"而非"条目坏" }
    LOtherPub := Ed25519PublicKeyFromPrivate(PatternBytes($99, 32));
    FileWriteAllText(KH_PATH, 'loopback.otherhost ssh-ed25519 '
      + Base64Encode(Ed25519PubBlob(LOtherPub)) + #10);
    try
      LR := RunLoopback(LOOP_PASSWORD, True, False, KH_PATH, True);
      CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
      CheckTrue(LR.ClientFailed, 'client must fail');
      CheckEqual(Ord(sekHostKey), Ord(LR.ClientErrKind), 'error kind');
    finally
      DeleteFile(KH_PATH);
    end;
  end);

  { 场景五：known_hosts 命中后严格模式放行 }
  GSuite.Test('strict host key passes on known_hosts hit', procedure
  var
    LR: TLoopResult;
    LPub: TBytes;
  begin
    LPub := Ed25519PublicKeyFromPrivate(PatternBytes($E7, 32));
    FileWriteAllText(KH_PATH, CLIENT_HOST_NAME + ' ssh-ed25519 '
      + Base64Encode(Ed25519PubBlob(LPub)) + #10);
    try
      LR := RunLoopback(LOOP_PASSWORD, True, False, KH_PATH, True);
      CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
      CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
      CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    finally
      DeleteFile(KH_PATH);
    end;
  end);

  { S13：服务端仅提供 group14 时客户端回退 DH，完成握手→认证→exec }
  GSuite.Test('dh group14 fallback loopback (password)', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PASSWORD, True, False, '', False, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    CheckEqual('stdout-part-one|stdout-part-two!', LR.Exec.StdOutText, 'stdout');
  end);

  GSuite.Test('dh group14 fallback loopback (publickey)', procedure
  var
    LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY, True, True, '', False, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  { S14：agent 回环（内存管道双链路：ssh + agent Unix-socket 语义）}
  GSuite.Test('agent ed25519 auth loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(True, False, True, False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    CheckEqual('agent-stdout|ok!', LR.Exec.StdOutText, 'stdout');
  end);

  GSuite.Test('agent rsa auth loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(False, True, True, False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('agent multiple identities loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(True, True, True, False);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('agent no identities rejected as sekAuth', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(False, False, True, False);
    CheckTrue(LR.ClientFailed, 'client must fail');
    CheckEqual(Ord(sekAuth), Ord(LR.ClientErrKind), 'error kind');
  end);

  GSuite.Test('agent dh fallback loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(True, False, True, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  { S15：压缩延迟激活回环 — 客户端与服务端同时协商 zlib@openssh.com，
    认证后启用压缩，exec 通道往返仍正确（含高度可压缩载荷验证有状态压缩有效）}
  GSuite.Test('compress delayed loopback (password)', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PASSWORD, True, False, '', False, False, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    CheckEqual('stdout-part-one|stdout-part-two!', LR.Exec.StdOutText, 'stdout');
  end);

  GSuite.Test('compress delayed loopback (publickey)', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PUBKEY, True, True, '', False, False, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('compress delayed + dh fallback loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopback(LOOP_PASSWORD, True, False, '', False, True, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
  end);

  GSuite.Test('compress delayed agent loopback', procedure
  var LR: TLoopResult;
  begin
    LR := RunLoopbackAgent(True, False, True, False, True);
    CheckTrue(not LR.ServerFailed, 'server ok: ' + LR.ServerErrMsg);
    CheckTrue(not LR.ClientFailed, 'client ok: ' + LR.ClientErrMsg);
    CheckEqual(Int64(7), Int64(LR.Exec.ExitCode), 'exit code');
    CheckEqual('agent-stdout|ok!', LR.Exec.StdOutText, 'stdout');
  end);

  GSuite.Test('rekey builder fluent + defaults', procedure
  var O: TSshConnectOptions;
  begin
    SshClient.Host('h').User('u').Password('p').RekeyBytes(1024).RekeyIntervalMs(100).KeepAliveIntervalMs(50);
    O:=DefaultSshConnectOptions('h');
    CheckEqual(Int64(SSH_REKEY_BYTES), Int64(O.RekeyBytes), 'default rekey bytes 1GiB');
    CheckEqual(Int64(SSH_REKEY_INTERVAL_MS), Int64(O.RekeyIntervalMs), 'default rekey interval 1h');
    CheckEqual(Int64(0), Int64(O.KeepAliveIntervalMs), 'default keepalive 0');
  end);

  GRunner := TSuiteRunner.Create('nextpas.core.ssh.session');
  GRunner.Add(GSuite);
  GRunner.RunAll;
  GRunner.Summary;
  if not GRunner.AllPassed then Halt(1);
end.
