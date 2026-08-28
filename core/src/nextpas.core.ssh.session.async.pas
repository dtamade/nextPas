unit nextpas.core.ssh.session.async;

{** nextpas.core.ssh - 异步会话 (TAsyncLoop + AsyncTcpDial)。
 *
 * 事件化重放同步会话的 DoHandshake/Derive/DoService/Auth 链,
 * 零拷贝复用 cipher/kex/hostkey/compress 逻辑,
 * 仅 I/O 经 TAsyncSshTransport 事件化, 序列号/压缩状态与同步完全一致。
 *
 * 对外: SshAsyncConnect + ISshAsyncSession.ExecAsync + SshAsyncClientBuilder.
 * 取消: DialOptions.Token / 握手期 Close 触发 poller TryCancelByContext。
 * 线程模型: 单线程事件循环所有权, 回调均在 loop 线程。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport.async;

type
  ISshAsyncSession = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000010}']
    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;
    function GetLoop: TAsyncLoop;
    function GetTransport: TAsyncSshTransport;
    function ExecAsync(const ACommand: string; ACallback: TProcSshExecResult): Boolean;
    procedure Close;
    property Connected: Boolean read GetConnected;
    property ServerVersion: string read GetServerVersion;
    property ServerHostKeyFingerprint: string read GetServerHostKeyFingerprint;
    property Loop: TAsyncLoop read GetLoop;
    property Transport: TAsyncSshTransport read GetTransport;
  end;

  TSshAsyncConnectCb = procedure(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer);

  ISshAsyncClientBuilder = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000011}']
    function Host(const AValue: string): ISshAsyncClientBuilder;
    function Port(AValue: Word): ISshAsyncClientBuilder;
    function User(const AValue: string): ISshAsyncClientBuilder;
    function Password(const AValue: string): ISshAsyncClientBuilder;
    function PrivateKeyData(const AValue: string): ISshAsyncClientBuilder;
    function PrivateKeyPassphrase(const AValue: string): ISshAsyncClientBuilder;
    function AgentSocketPath(const AValue: string): ISshAsyncClientBuilder;
    function KnownHostsFile(const AValue: string): ISshAsyncClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshAsyncClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshAsyncClientBuilder;
    function Compress(AValue: Boolean): ISshAsyncClientBuilder;
    function DialOptions(const AValue: TAsyncTcpDialOptions): ISshAsyncClientBuilder;
    function AsyncConnect(const ALoop: TAsyncLoop; ACallback: TSshAsyncConnectCb; AContext: Pointer = nil): Boolean;
  end;

function SshAsyncConnect(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions;
  ACallback: TSshAsyncConnectCb; AContext: Pointer = nil): Boolean; overload;
function SshAsyncConnect(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions;
  const ADialOptions: TAsyncTcpDialOptions; ACallback: TSshAsyncConnectCb; AContext: Pointer = nil): Boolean; overload;

function SshAsyncClient: ISshAsyncClientBuilder;

implementation

uses
  SysUtils,
  nextpas.core.system.sysutils,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.crypto.random,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.rsa,
  nextpas.core.ssh.auth,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.kex.dhgroup14,
  nextpas.core.ssh.channel.async;

type
  TAsyncExpectHandler = procedure(const APayload: TBytes; AErr: ESSHError) of object;
  TAsyncSshSession = class;
  TAsyncConnector = class;

  TAsyncSshSession = class(TInterfacedObject, ISshAsyncSession)
  private
    FLoop: TAsyncLoop;
    FTransport: TAsyncSshTransport;
    FOptions: TSshConnectOptions;
    FActiveUser: string;
    FSessionId: TBytes;
    FHostKeyInfo: TSshHostKeyInfo;
    FHostKeyBlob: TBytes;
    FHostKeyFingerprint: string;
    FKnownHosts: TSshKnownHosts;
    FKnownHostsLoaded: Boolean;
    FNegotiated: TSshNegotiated;
    FAuthenticated: Boolean;
    FClosed: Boolean;
    procedure LoadKnownHostsIfNeeded;
    procedure VerifyHostKey(const ASigAlg: string; const AH, ASigBlob: TBytes);
    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;
    function GetLoop: TAsyncLoop;
    function GetTransport: TAsyncSshTransport;
  public
    constructor Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AOptions: TSshConnectOptions);
    destructor Destroy; override;
    function ExecAsync(const ACommand: string; ACallback: TProcSshExecResult): Boolean;
    procedure Close;
  end;

  TAsyncConnector = class
  private
    FLoop: TAsyncLoop;
    FOptions: TSshConnectOptions;
    FDialOptions: TAsyncTcpDialOptions;
    FUserCb: TSshAsyncConnectCb;
    FUserCtx: Pointer;
    FTransport: TAsyncSshTransport;
    FSession: TAsyncSshSession;
    FMyKexInit: TBytes;
    FPeerKexInit: TBytes;
    FNeg: TSshNegotiated;
    FK, FH, FHostBlob, FSigBlob: TBytes;
    FHostKeyInfo: TSshHostKeyInfo;
    FHostKeyFingerprint: string;
    FSessionId: TBytes;
    FKexCurve: TSshKexCurve25519;
    FKexDH: TSshKexDHGroup14;
    // agent
    FAgentClient: TSshAgentClient;
    FAgentIds: TSshAgentIdentityArray;
    FAgentIdx: Integer;
    FCurrentAgentBlob: TBytes;
    FCurrentAgentAlg: string;
    // expect helper
    FExpectAccept: array of Byte;
    FExpectCb: TAsyncExpectHandler;
    procedure Fail(AErr: ESSHError);
    procedure Succeed;
    // dial
    procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
    // version
    procedure OnVersionDone(const AIdent: string; AErr: ESSHError; AContext: Pointer);
    // kex
    procedure OnKexInitSent(AErr: ESSHError; AContext: Pointer);
    procedure OnKexInitRecv(const APayload: TBytes; AErr: ESSHError);
    procedure OnKexInitReplySent(AErr: ESSHError; AContext: Pointer);
    procedure OnKexReplyRecv(const APayload: TBytes; AErr: ESSHError);
    procedure OnNewKeysSent(AErr: ESSHError; AContext: Pointer);
    procedure OnPeerNewKeys(const APayload: TBytes; AErr: ESSHError);
    procedure OnServiceSent(AErr: ESSHError; AContext: Pointer);
    procedure OnServiceAccept(const APayload: TBytes; AErr: ESSHError);
    procedure DoAuth;
    procedure OnAuthPasswordResult(const APayload: TBytes; AErr: ESSHError);
    procedure OnAuthPubkeyProbeResult(const APayload: TBytes; AErr: ESSHError);
    procedure OnAuthPubkeyResult(const APayload: TBytes; AErr: ESSHError);
    procedure OnAgentProbeResult(const APayload: TBytes; AErr: ESSHError);
    procedure OnAgentSignResult(const APayload: TBytes; AErr: ESSHError);
    // auth helpers
    procedure AuthWithPassword;
    procedure AuthWithPrivateKey;
    procedure AuthWithAgent;
    procedure TryNextAgentIdentity;
    procedure TryEnableDelayedAndSucceed;
    // expect helper
    function ExpectOneOfAsync(const AAccept: array of Byte; const AHandler: TAsyncExpectHandler): Boolean;
    procedure HandleExpectPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
    procedure DeriveAndApplyKeys;
  public
    constructor Create(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions; const ADialOptions: TAsyncTcpDialOptions; ACallback: TSshAsyncConnectCb; AContext: Pointer);
    procedure Start;
  end;

// free dispatchers for transport callbacks (plain -> method)
procedure SshAsync_OnVersionDone(const AIdent: string; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnKexInitSent(AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnKexInitRecv(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnKexInitReplySent(AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnKexReplyRecv(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnNewKeysSent(AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnPeerNewKeys(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnServiceSent(AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnServiceAccept(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsync_OnExpectPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer); forward;
procedure SshAsyncDialCb(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer); forward;

{ Helpers }

function InByteList(AValue: Byte; const AList: array of Byte): Boolean;
var I: Integer;
begin
  for I := 0 to High(AList) do if AList[I] = AValue then Exit(True);
  Result := False;
end;

function SingleBytePayload(AMsg: Byte): TBytes;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := AMsg;
end;

{ TAsyncSshSession }

constructor TAsyncSshSession.Create(const ALoop: TAsyncLoop; const ATransport: TAsyncSshTransport; const AOptions: TSshConnectOptions);
begin
  inherited Create;
  FLoop := ALoop;
  FTransport := ATransport;
  FOptions := AOptions;
end;

destructor TAsyncSshSession.Destroy;
begin
  Close;
  FreeAndNil(FTransport);
  FreeAndNil(FKnownHosts);
  inherited;
end;

type
  PExecPost = ^TExecPost;
  TExecPost = record
    Transport: TAsyncSshTransport;
    Command: string;
    InitialWindow: UInt32;
    MaxPacket: UInt32;
    TimeoutMs: Integer;
    Callback: TProcSshExecResult;
    Context: Pointer;
  end;

procedure ExecPostCb(AContext: Pointer); forward;
procedure ExecPostDiscard(AContext: Pointer); forward;

function TAsyncSshSession.GetConnected: Boolean;
begin
  Result := (not FClosed) and FAuthenticated;
end;

function TAsyncSshSession.GetServerVersion: string;
begin
  if FTransport <> nil then Result := FTransport.ServerIdent else Result := '';
end;

function TAsyncSshSession.GetServerHostKeyFingerprint: string;
begin
  Result := FHostKeyFingerprint;
end;

function TAsyncSshSession.GetLoop: TAsyncLoop;
begin Result:=FLoop; end;

function TAsyncSshSession.GetTransport: TAsyncSshTransport;
begin Result:=FTransport; end;

procedure TAsyncSshSession.LoadKnownHostsIfNeeded;
begin
  if FKnownHostsLoaded then Exit;
  FKnownHostsLoaded := True;
  if FOptions.KnownHostsFile <> '' then
  begin
    FKnownHosts := TSshKnownHosts.Create;
    FKnownHosts.LoadFromFile(FOptions.KnownHostsFile);
  end;
end;

procedure TAsyncSshSession.VerifyHostKey(const ASigAlg: string; const AH, ASigBlob: TBytes);
var LInFile: Boolean;
begin
  if not SshVerifyHostSignature(FHostKeyInfo, ASigAlg, AH, ASigBlob) then
    raise ESSHError.Create(sekHostKey, 'ssh session: host key signature invalid (' + SshFingerprintSHA256(FHostKeyBlob) + ')');
  LoadKnownHostsIfNeeded;
  if FKnownHosts <> nil then
  begin
    LInFile := FKnownHosts.ContainsKey(FOptions.Host, FOptions.Port, FHostKeyBlob);
    if (not LInFile) and FOptions.StrictHostKeyChecking then
      raise ESSHError.Create(sekHostKey, 'ssh session: host key not in known_hosts (' + FOptions.Host + ':' + IntToStr(FOptions.Port) + ', ' + FHostKeyFingerprint + ')');
  end;
end;

procedure TAsyncSshSession.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    if FTransport <> nil then
      FTransport.Close;
  end;
end;

procedure ExecPostCb(AContext: Pointer);
var P: PExecPost;
begin
  P := PExecPost(AContext);
  try
    SshAsyncRunExec(P^.Transport, P^.Command, P^.InitialWindow, P^.MaxPacket, P^.TimeoutMs, P^.Callback, P^.Context);
  finally
    Dispose(P);
  end;
end;

procedure ExecPostDiscard(AContext: Pointer);
var P: PExecPost;
begin
  P := PExecPost(AContext);
  if Assigned(P^.Callback) then
    P^.Callback(Default(TSshExecResult), ESSHError.Create(sekIO, 'ssh session: loop closed before exec'), P^.Context);
  Dispose(P);
end;

function TAsyncSshSession.ExecAsync(const ACommand: string; ACallback: TProcSshExecResult): Boolean;
var P: PExecPost;
begin
  if not FAuthenticated then
  begin
    if Assigned(ACallback) then
      ACallback(Default(TSshExecResult), ESSHError.Create(sekAuth, 'ssh session: not authenticated'), nil);
    Exit(False);
  end;
  if FClosed then
  begin
    if Assigned(ACallback) then
      ACallback(Default(TSshExecResult), ESSHError.Create(sekIO,'ssh session: closed'), nil);
    Exit(False);
  end;
  if (FLoop = nil) or (FTransport = nil) then
  begin
    if Assigned(ACallback) then
      ACallback(Default(TSshExecResult), ESSHError.Create(sekIO,'ssh session: invalid state'), nil);
    Exit(False);
  end;
  New(P);
  P^.Transport := FTransport;
  P^.Command := ACommand;
  P^.InitialWindow := FOptions.InitialWindowSize;
  P^.MaxPacket := FOptions.MaxPacket;
  P^.TimeoutMs := FOptions.ExecTimeoutMs;
  P^.Callback := ACallback;
  P^.Context := nil;
  try
    FLoop.PostEx(@ExecPostCb, P, @ExecPostDiscard);
    Result := True;
  except
    Dispose(P);
    if Assigned(ACallback) then
      ACallback(Default(TSshExecResult), ESSHError.Create(sekIO,'ssh session: post exec failed'), nil);
    Result := False;
  end;
end;

{ TAsyncConnector }

constructor TAsyncConnector.Create(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions; const ADialOptions: TAsyncTcpDialOptions; ACallback: TSshAsyncConnectCb; AContext: Pointer);
begin
  inherited Create;
  FLoop := ALoop;
  FOptions := AOptions;
  FDialOptions := ADialOptions;
  FUserCb := ACallback;
  FUserCtx := AContext;
end;

procedure TAsyncConnector.Fail(AErr: ESSHError);
var Cb: TSshAsyncConnectCb; Ctx: Pointer;
begin
  Cb := FUserCb; Ctx := FUserCtx;
  FUserCb := nil;
  FreeAndNil(FAgentClient);
  FreeAndNil(FKexCurve);
  FreeAndNil(FKexDH);
  if FSession <> nil then
  begin
    // session owns transport after OnDial; avoid double free
    FSession.FTransport := nil;
    FreeAndNil(FSession);
  end;
  if FTransport <> nil then FreeAndNil(FTransport);
  if Assigned(Cb) then Cb(nil, AErr, Ctx) else if AErr <> nil then AErr.Free;
  Free;
end;

procedure TAsyncConnector.Succeed;
var Cb: TSshAsyncConnectCb; Ctx: Pointer; Sess: ISshAsyncSession;
begin
  Cb := FUserCb; Ctx := FUserCtx;
  FUserCb := nil;
  FreeAndNil(FAgentClient);
  FreeAndNil(FKexCurve);
  FreeAndNil(FKexDH);
  Sess := FSession as ISshAsyncSession;
  FTransport := nil; // owned by session
  if Assigned(Cb) then Cb(Sess, nil, Ctx);
  Free;
end;

procedure TAsyncConnector.Start;
begin
  if FLoop = nil then begin Fail(ESSHError.Create(sekProtocol, 'async connect: nil loop')); Exit; end;
  if FOptions.Host = '' then begin Fail(ESSHError.Create(sekProtocol, 'ssh connect: host is required')); Exit; end;
  if FOptions.User = '' then begin Fail(ESSHError.Create(sekProtocol, 'ssh connect: user is required')); Exit; end;
  if not AsyncTcpDial(FLoop, FOptions.Host, FOptions.Port, FDialOptions, @SshAsyncDialCb, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async dial: submit failed'));
end;

procedure TAsyncConnector.OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  if AError <> 0 then begin Fail(ESSHError.Create(sekIO, 'ssh async dial failed (' + IntToStr(AError) + ')')); Exit; end;
  if AStream = nil then begin Fail(ESSHError.Create(sekIO, 'ssh async dial: nil stream')); Exit; end;
  FTransport := TAsyncSshTransport.Create(FLoop, AStream);
  FSession := TAsyncSshSession.Create(FLoop, FTransport, FOptions);
  FSession.FActiveUser := FOptions.User;
  if not FTransport.AsyncExchangeVersions(@SshAsync_OnVersionDone, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async version exchange submit failed'));
end;

procedure TAsyncConnector.OnVersionDone(const AIdent: string; AErr: ESSHError; AContext: Pointer);
var LCookie: TBytes;
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  LCookie := GenerateSecureRandomBytes(16);
  if not FTransport.AsyncSendKexInitEx(LCookie, FOptions.Compress, @SshAsync_OnKexInitSent, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async kexinit send submit failed'));
end;

procedure TAsyncConnector.OnKexInitSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  FMyKexInit := FTransport.MyKexInitPayload;
  if not ExpectOneOfAsync([SSH_MSG_KEXINIT], @OnKexInitRecv) then
    Fail(ESSHError.Create(sekIO, 'ssh async expect kexinit submit failed'));
end;

procedure TAsyncConnector.OnKexInitRecv(const APayload: TBytes; AErr: ESSHError);
var LPeer: TSshPeerKexInit; LInit: TBytes;
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  FPeerKexInit := APayload;
  LPeer := SshParseKexInit(APayload);
  try
    FNeg := SshNegotiateEx(LPeer, FOptions.Compress);
  except
    on E: ESSHError do begin Fail(E); Exit; end;
    on E: Exception do begin Fail(ESSHError.Create(sekNegotiation, E.Message)); Exit; end;
  end;
  FSession.FNegotiated := FNeg;
  // Build and send KEX init according to negotiated alg
  if FNeg.KexAlg = 'diffie-hellman-group14-sha256' then
  begin
    FKexDH := TSshKexDHGroup14.Create;
    LInit := FKexDH.BuildInitPayload;
  end
  else
  begin
    FKexCurve := TSshKexCurve25519.Create;
    LInit := FKexCurve.BuildInitPayload;
  end;
  if not FTransport.AsyncSendPacket(LInit, @SshAsync_OnKexInitReplySent, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async kex init send failed'));
end;

procedure TAsyncConnector.OnKexInitReplySent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  if not ExpectOneOfAsync([SSH_MSG_KEX_ECDH_REPLY], @OnKexReplyRecv) then
    Fail(ESSHError.Create(sekIO, 'ssh async expect kex reply submit failed'));
end;

procedure TAsyncConnector.OnKexReplyRecv(const APayload: TBytes; AErr: ESSHError);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  try
    if Assigned(FKexDH) then
      FKexDH.ProcessReply(APayload, SSH_PROTOCOL_VERSION, FTransport.ServerIdent,
        FMyKexInit, FPeerKexInit, FK, FH, FHostBlob, FSigBlob)
    else if Assigned(FKexCurve) then
      FKexCurve.ProcessReply(APayload, SSH_PROTOCOL_VERSION, FTransport.ServerIdent,
        FMyKexInit, FPeerKexInit, FK, FH, FHostBlob, FSigBlob)
    else
      raise ESSHError.Create(sekProtocol, 'ssh async: no kex instance');
  except
    on E: ESSHError do begin Fail(E); Exit; end;
    on E: Exception do begin Fail(ESSHError.Create(sekProtocol, E.Message)); Exit; end;
  end;
  // hostkey verify
  FHostBlob := FHostBlob; // keep
  if not SshParseHostKey(FHostBlob, FHostKeyInfo) then
  begin Fail(ESSHError.Create(sekHostKey, 'ssh session: unsupported host key blob')); Exit; end;
  FSession.FHostKeyInfo := FHostKeyInfo;
  FSession.FHostKeyBlob := FHostBlob;
  FHostKeyFingerprint := SshFingerprintSHA256(FHostBlob);
  FSession.FHostKeyFingerprint := FHostKeyFingerprint;
  try
    FSession.VerifyHostKey(FNeg.HostKeyAlg, FH, FSigBlob);
  except
    on E: ESSHError do begin Fail(E); Exit; end;
  end;
  FSessionId := FH; // session_id = H first
  FSession.FSessionId := FH;
  DeriveAndApplyKeys;
end;

procedure TAsyncConnector.DeriveAndApplyKeys;
begin
  // NEWKEYS exchange will trigger SetNegotiatedCompression + ApplyNewKeys after peer reply.
  // Keeping KDF lazy until peer NEWKEYS reduces live allocations.
  // save derived keys in fields to apply later? create closure via storing in FSession?
  // Simplest: store in session temporarily
  // Use session's transport apply after peer NEWKEYS, keep keys in connector vars via captued locals?
  // We will store keys in FSession fields for now via dynamic: use FSession.FHostKeyBlob reuse? Better add fields.
  // Quick: stash in connector's FH etc already, we will keep keys in local variables via instance fields
  // Add private fields for keys? For MVP we apply immediately before peer NEWKEYS but also need to keep for later ApplyNewKeys.
  // We'll store in FSession as borrowed: use FSession.FSessionId already, we add storage in connector with extra fields.
  if not FTransport.AsyncSendPacket(SingleBytePayload(SSH_MSG_NEWKEYS), @SshAsync_OnNewKeysSent, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async send NEWKEYS failed'));
end;

procedure TAsyncConnector.OnNewKeysSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  if not ExpectOneOfAsync([SSH_MSG_NEWKEYS], @OnPeerNewKeys) then
    Fail(ESSHError.Create(sekIO, 'ssh async expect NEWKEYS failed'));
end;

procedure TAsyncConnector.OnPeerNewKeys(const APayload: TBytes; AErr: ESSHError);
var
  LW: TsshWriter;
  LKmpint, LIvCs, LIvSc, LKeyCs, LKeySc, LMacCs, LMacSc: TBytes;
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  // derive again and apply
  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(FK);
    LKmpint := LW.ToBytes;
  finally LW.Free; end;
  LIvCs := SshKdfSha256(LKmpint, FH, Ord('A'), FSessionId, SshCipherIvSize(FNeg.EncCs));
  LIvSc := SshKdfSha256(LKmpint, FH, Ord('B'), FSessionId, SshCipherIvSize(FNeg.EncSc));
  LKeyCs := SshKdfSha256(LKmpint, FH, Ord('C'), FSessionId, SshCipherKeySize(FNeg.EncCs));
  LKeySc := SshKdfSha256(LKmpint, FH, Ord('D'), FSessionId, SshCipherKeySize(FNeg.EncSc));
  LMacCs := SshKdfSha256(LKmpint, FH, Ord('E'), FSessionId, SshMacKeySize(FNeg.MacCs));
  LMacSc := SshKdfSha256(LKmpint, FH, Ord('F'), FSessionId, SshMacKeySize(FNeg.MacSc));
  FTransport.SetNegotiatedCompression(FNeg);
  try
    FTransport.ApplyNewKeys(FNeg, LIvCs, LKeyCs, LMacCs, LIvSc, LKeySc, LMacSc);
  except
    on E: ESSHError do begin Fail(E); Exit; end;
  end;
  // service request
  LW := TsshWriter.Create(32);
  try
    LW.PutByte(SSH_MSG_SERVICE_REQUEST);
    LW.PutStringText(SSH_SERVICE_USERAUTH);
    if not FTransport.AsyncSendPacket(LW.ToBytes, @SshAsync_OnServiceSent, Self) then
      Fail(ESSHError.Create(sekIO, 'ssh async service request send failed'));
  finally LW.Free; end;
end;

procedure TAsyncConnector.OnServiceSent(AErr: ESSHError; AContext: Pointer);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  if not ExpectOneOfAsync([SSH_MSG_SERVICE_ACCEPT], @OnServiceAccept) then
    Fail(ESSHError.Create(sekIO, 'ssh async expect SERVICE_ACCEPT failed'));
end;

procedure TAsyncConnector.OnServiceAccept(const APayload: TBytes; AErr: ESSHError);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  DoAuth;
end;

procedure TAsyncConnector.DoAuth;
begin
  if FOptions.AgentSocketPath <> '' then
    AuthWithAgent
  else if FOptions.PrivateKeyData <> '' then
    AuthWithPrivateKey
  else if FOptions.Password <> '' then
    AuthWithPassword
  else
    Fail(ESSHError.Create(sekAuth, 'ssh async: no auth method configured'));
end;

procedure DoAuthPasswordSendDone(AErr: ESSHError; AContext: Pointer); forward;
procedure DoAuthPubkeySendDone(AErr: ESSHError; AContext: Pointer); forward;
procedure DoAgentProbeSendDone(AErr: ESSHError; AContext: Pointer); forward;
procedure DoAgentSignedSendDone(AErr: ESSHError; AContext: Pointer); forward;

procedure TAsyncConnector.AuthWithPassword;
begin
  if not FTransport.AsyncSendPacket(SshBuildAuthPassword(FOptions.User, FOptions.Password), @DoAuthPasswordSendDone, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async password send failed'));
end;

procedure TAsyncConnector.AuthWithPrivateKey;
var
  LKey: TSshPrivateKey;
  LPubBlob, LSignedData, LSig64, LSigRaw, LSigBlob: TBytes;
  LAlgName: string;
  LOk: Boolean;
begin
  LOk := SshLoadPrivateKey(FOptions.PrivateKeyData, LKey, LPubBlob, FOptions.PrivateKeyPassphrase);
  if not LOk then begin Fail(ESSHError.Create(sekKeyFormat, 'ssh session: private key parse failed')); Exit; end;
  case LKey.Kind of
    hkEd25519:
      begin
        LAlgName := 'ssh-ed25519';
        LSignedData := SshAuthSignedData(FSessionId, FOptions.User, LAlgName, LPubBlob);
        if not Ed25519Sign(LKey.Ed25519Seed, LSignedData, LSig64) then
        begin Fail(ESSHError.Create(sekCrypto, 'ssh session: ed25519 sign failed')); Exit; end;
        LSigBlob := SshBuildEd25519SigBlob(LSig64);
      end;
    hkRsa:
      begin
        LAlgName := SSH_RSA_SIG_SHA512;
        LSignedData := SshAuthSignedData(FSessionId, FOptions.User, LAlgName, LPubBlob);
        if LKey.RsaHasCrt then
        begin
          if not RsaSignPkcs1v15Crt(LKey.RsaN, LKey.RsaD, LKey.RsaP, LKey.RsaQ, LKey.RsaIqmp, SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw) then
            if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw) then
            begin Fail(ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed')); Exit; end;
        end
        else
          if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw) then
          begin Fail(ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed')); Exit; end;
        LSigBlob := SshBuildRsaSigBlob(LSigRaw, LAlgName);
      end;
  else
    Fail(ESSHError.Create(sekUnsupported, 'ssh session: unsupported private key kind')); Exit;
  end;
  if not FTransport.AsyncSendPacket(SshBuildAuthPubKeySigned(FOptions.User, LAlgName, LPubBlob, LSigBlob), @DoAuthPubkeySendDone, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async pubkey send failed'));
end;

procedure TAsyncConnector.AuthWithAgent;
var LOk: Boolean;
begin
  try
    FAgentClient := SshAgentConnect(FOptions.AgentSocketPath);
  except
    on E: ESSHError do begin Fail(E); Exit; end;
    on E: Exception do begin Fail(ESSHError.Create(sekIO, E.Message)); Exit; end;
  end;
  LOk := False;
  try
    LOk := FAgentClient.ListIdentities(FAgentIds);
  except
    on E: ESSHError do begin Fail(E); Exit; end;
    on E: Exception do begin Fail(ESSHError.Create(sekIO, E.Message)); Exit; end;
  end;
  if not LOk then begin Fail(ESSHError.Create(sekAuth, 'ssh async: agent list failed')); Exit; end;
  if Length(FAgentIds)=0 then
  begin
    if FOptions.PrivateKeyData<>'' then begin FreeAndNil(FAgentClient); AuthWithPrivateKey; Exit; end;
    if FOptions.Password<>'' then begin FreeAndNil(FAgentClient); AuthWithPassword; Exit; end;
    Fail(ESSHError.Create(sekAuth, 'ssh async: agent has no identities')); Exit;
  end;
  FAgentIdx := 0;
  TryNextAgentIdentity;
end;

procedure TAsyncConnector.TryNextAgentIdentity;
var LBlob: TBytes; LAlg: string;
begin
  while FAgentIdx < Length(FAgentIds) do
  begin
    LBlob := FAgentIds[FAgentIdx].Blob;
    LAlg := FAgentIds[FAgentIdx].AlgName;
    if LAlg='' then begin Inc(FAgentIdx); Continue; end;
    FCurrentAgentBlob := LBlob;
    FCurrentAgentAlg := LAlg;
    if not FTransport.AsyncSendPacket(SshBuildAuthPubKeyProbe(FOptions.User, LAlg, LBlob), @DoAgentProbeSendDone, Self) then
      Fail(ESSHError.Create(sekIO, 'ssh async agent probe send failed'));
    Exit;
  end;
  // exhausted
  if FOptions.PrivateKeyData<>'' then begin FreeAndNil(FAgentClient); AuthWithPrivateKey; Exit; end;
  if FOptions.Password<>'' then begin FreeAndNil(FAgentClient); AuthWithPassword; Exit; end;
  Fail(ESSHError.Create(sekAuth, 'ssh async: agent publickey rejected'));
end;

// To keep handshake simple, we implement explicit Expect callbacks for auth results
procedure TAsyncConnector.OnAuthPasswordResult(const APayload: TBytes; AErr: ESSHError);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol, 'ssh async: empty auth reply')); Exit; end;
  if APayload[0]=SSH_MSG_USERAUTH_SUCCESS then
  begin
    TryEnableDelayedAndSucceed;
  end
  else
    Fail(ESSHError.Create(sekAuth, 'ssh session: password rejected for user "' + FOptions.User + '"'));
end;

procedure TAsyncConnector.OnAuthPubkeyProbeResult(const APayload: TBytes; AErr: ESSHError);
begin
  // not used (direct signed path)
end;

procedure TAsyncConnector.OnAuthPubkeyResult(const APayload: TBytes; AErr: ESSHError);
begin
  if AErr <> nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol, 'ssh async: empty auth reply')); Exit; end;
  if APayload[0]=SSH_MSG_USERAUTH_SUCCESS then
    TryEnableDelayedAndSucceed
  else
    Fail(ESSHError.Create(sekAuth, 'ssh session: publickey rejected'));
end;

procedure TAsyncConnector.OnAgentProbeResult(const APayload: TBytes; AErr: ESSHError);
var LFlags: UInt32; LSignedData, LSigBlob: TBytes;
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol,'ssh async: empty agent probe reply')); Exit; end;
  case APayload[0] of
    SSH_MSG_USERAUTH_SUCCESS:
      begin FreeAndNil(FAgentClient); TryEnableDelayedAndSucceed; Exit; end;
    SSH_MSG_USERAUTH_FAILURE:
      begin Inc(FAgentIdx); TryNextAgentIdentity; Exit; end;
    SSH_MSG_USERAUTH_PK_OK:
      begin
        LFlags := SshAgentKeyBlobToSignFlags(FCurrentAgentBlob);
        LSignedData := SshAuthSignedData(FSessionId, FOptions.User, FCurrentAgentAlg, FCurrentAgentBlob);
        try
          if not FAgentClient.Sign(FCurrentAgentBlob, LSignedData, LFlags, LSigBlob) then
          begin Inc(FAgentIdx); TryNextAgentIdentity; Exit; end;
        except
          on E: ESSHError do begin Inc(FAgentIdx); TryNextAgentIdentity; Exit; end;
        end;
        if not FTransport.AsyncSendPacket(SshBuildAuthPubKeySigned(FOptions.User, FCurrentAgentAlg, FCurrentAgentBlob, LSigBlob), @DoAgentSignedSendDone, Self) then
          Fail(ESSHError.Create(sekIO,'ssh async agent signed send failed'));
        Exit;
      end;
  else
    Inc(FAgentIdx); TryNextAgentIdentity;
  end;
end;

procedure TAsyncConnector.OnAgentSignResult(const APayload: TBytes; AErr: ESSHError);
begin
  if AErr<>nil then begin Fail(AErr); Exit; end;
  if Length(APayload)=0 then begin Fail(ESSHError.Create(sekProtocol,'ssh async: empty agent sign reply')); Exit; end;
  if APayload[0]=SSH_MSG_USERAUTH_SUCCESS then
  begin FreeAndNil(FAgentClient); TryEnableDelayedAndSucceed; end
  else
  begin Inc(FAgentIdx); TryNextAgentIdentity; end;
end;

procedure TAsyncConnector.TryEnableDelayedAndSucceed;
begin
  if SshCompressionIsDelayed(FNeg.CompCs) or SshCompressionIsDelayed(FNeg.CompSc) then
    FTransport.EnableCompression;
  FSession.FAuthenticated := True;
  FSession.FNegotiated := FNeg;
  FSession.FSessionId := FSessionId;
  FreeAndNil(FAgentClient);
  Succeed;
end;

function TAsyncConnector.ExpectOneOfAsync(const AAccept: array of Byte; const AHandler: TAsyncExpectHandler): Boolean;
var I: Integer;
begin
  SetLength(FExpectAccept, Length(AAccept));
  for I := 0 to High(AAccept) do FExpectAccept[I] := AAccept[I];
  FExpectCb := AHandler;
  Result := FTransport.AsyncReadPacket(@SshAsync_OnExpectPacket, Self);
end;

procedure TAsyncConnector.HandleExpectPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
var LType: Byte;
begin
  if AErr <> nil then
  begin
    if Assigned(FExpectCb) then begin FExpectCb(nil, AErr); FExpectCb := nil; end;
    Exit;
  end;
  if Length(APayload)=0 then
  begin
    if not FTransport.AsyncReadPacket(@SshAsync_OnExpectPacket, Self) then
      Fail(ESSHError.Create(sekIO, 'ssh async expect re-read failed'));
    Exit;
  end;
  LType := APayload[0];
  if InByteList(LType, FExpectAccept) then
  begin
    if Assigned(FExpectCb) then begin FExpectCb(APayload, nil); FExpectCb := nil; end;
    Exit;
  end;
  // Transparent messages: ignore/debug/unimplemented/ext_info/banner - skip
  if LType in [SSH_MSG_IGNORE, SSH_MSG_DEBUG, SSH_MSG_UNIMPLEMENTED, SSH_MSG_EXT_INFO, SSH_MSG_USERAUTH_BANNER] then
  begin
    if not FTransport.AsyncReadPacket(@SshAsync_OnExpectPacket, Self) then
      Fail(ESSHError.Create(sekIO, 'ssh async expect re-read failed'));
    Exit;
  end;
  if LType = SSH_MSG_DISCONNECT then
  begin
    Fail(ESSHError.Create(sekDisconnect, 'ssh: disconnected by peer'));
    Exit;
  end;
  // Unexpected but not transparent - retry (covers channel noise during kex)
  if not FTransport.AsyncReadPacket(@SshAsync_OnExpectPacket, Self) then
    Fail(ESSHError.Create(sekIO, 'ssh async expect re-read failed'));
end;

procedure DoAuthPasswordSendDone(AErr: ESSHError; AContext: Pointer);
var Self: TAsyncConnector;
begin
  Self := TAsyncConnector(AContext);
  if AErr <> nil then begin Self.Fail(AErr); Exit; end;
  if not Self.ExpectOneOfAsync([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE], @Self.OnAuthPasswordResult) then
    Self.Fail(ESSHError.Create(sekIO, 'ssh async expect auth result failed'));
end;

procedure DoAuthPubkeySendDone(AErr: ESSHError; AContext: Pointer);
var Self: TAsyncConnector;
begin
  Self := TAsyncConnector(AContext);
  if AErr <> nil then begin Self.Fail(AErr); Exit; end;
  if not Self.ExpectOneOfAsync([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE], @Self.OnAuthPubkeyResult) then
    Self.Fail(ESSHError.Create(sekIO, 'ssh async expect auth result failed'));
end;

procedure DoAgentProbeSendDone(AErr: ESSHError; AContext: Pointer);
var Self: TAsyncConnector;
begin
  Self := TAsyncConnector(AContext);
  if AErr <> nil then begin Self.Fail(AErr); Exit; end;
  if not Self.ExpectOneOfAsync([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE, SSH_MSG_USERAUTH_PK_OK], @Self.OnAgentProbeResult) then
    Self.Fail(ESSHError.Create(sekIO, 'ssh async expect agent probe result failed'));
end;

procedure DoAgentSignedSendDone(AErr: ESSHError; AContext: Pointer);
var Self: TAsyncConnector;
begin
  Self := TAsyncConnector(AContext);
  if AErr <> nil then begin Self.Fail(AErr); Exit; end;
  if not Self.ExpectOneOfAsync([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE], @Self.OnAgentSignResult) then
    Self.Fail(ESSHError.Create(sekIO, 'ssh async expect agent signed result failed'));
end;

function SshAsyncConnect(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions; ACallback: TSshAsyncConnectCb; AContext: Pointer): Boolean;
var Opts: TAsyncTcpDialOptions;
begin
  Opts := DefaultAsyncTcpDialOptions;
  if AOptions.ConnectTimeoutMs > 0 then
    Opts.OverallDeadline := TDeadline.After(TDuration.FromMilliseconds(AOptions.ConnectTimeoutMs));
  Result := SshAsyncConnect(ALoop, AOptions, Opts, ACallback, AContext);
end;

function SshAsyncConnect(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions; const ADialOptions: TAsyncTcpDialOptions; ACallback: TSshAsyncConnectCb; AContext: Pointer): Boolean;
var C: TAsyncConnector;
begin
  if (ALoop = nil) or not Assigned(ACallback) then Exit(False);
  C := TAsyncConnector.Create(ALoop, AOptions, ADialOptions, ACallback, AContext);
  C.Start;
  Result := True;
end;

{ Builder }

type
  TAsyncClientBuilder = class(TInterfacedObject, ISshAsyncClientBuilder)
  private
    FOptions: TSshConnectOptions;
    FDialOptions: TAsyncTcpDialOptions;
    FHasDialOptions: Boolean;
  public
    constructor Create;
    function Host(const AValue: string): ISshAsyncClientBuilder;
    function Port(AValue: Word): ISshAsyncClientBuilder;
    function User(const AValue: string): ISshAsyncClientBuilder;
    function Password(const AValue: string): ISshAsyncClientBuilder;
    function PrivateKeyData(const AValue: string): ISshAsyncClientBuilder;
    function PrivateKeyPassphrase(const AValue: string): ISshAsyncClientBuilder;
    function AgentSocketPath(const AValue: string): ISshAsyncClientBuilder;
    function KnownHostsFile(const AValue: string): ISshAsyncClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshAsyncClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshAsyncClientBuilder;
    function Compress(AValue: Boolean): ISshAsyncClientBuilder;
    function DialOptions(const AValue: TAsyncTcpDialOptions): ISshAsyncClientBuilder;
    function AsyncConnect(const ALoop: TAsyncLoop; ACallback: TSshAsyncConnectCb; AContext: Pointer = nil): Boolean;
  end;

constructor TAsyncClientBuilder.Create;
begin
  inherited Create;
  FOptions := DefaultSshConnectOptions('');
  FDialOptions := DefaultAsyncTcpDialOptions;
  FHasDialOptions := False;
end;

function TAsyncClientBuilder.Host(const AValue: string): ISshAsyncClientBuilder; begin FOptions.Host := AValue; Result := Self; end;
function TAsyncClientBuilder.Port(AValue: Word): ISshAsyncClientBuilder; begin FOptions.Port := AValue; Result := Self; end;
function TAsyncClientBuilder.User(const AValue: string): ISshAsyncClientBuilder; begin FOptions.User := AValue; Result := Self; end;
function TAsyncClientBuilder.Password(const AValue: string): ISshAsyncClientBuilder; begin FOptions.Password := AValue; Result := Self; end;
function TAsyncClientBuilder.PrivateKeyData(const AValue: string): ISshAsyncClientBuilder; begin FOptions.PrivateKeyData := AValue; Result := Self; end;
function TAsyncClientBuilder.PrivateKeyPassphrase(const AValue: string): ISshAsyncClientBuilder; begin FOptions.PrivateKeyPassphrase := AValue; Result := Self; end;
function TAsyncClientBuilder.AgentSocketPath(const AValue: string): ISshAsyncClientBuilder; begin FOptions.AgentSocketPath := AValue; Result := Self; end;
function TAsyncClientBuilder.KnownHostsFile(const AValue: string): ISshAsyncClientBuilder; begin FOptions.KnownHostsFile := AValue; Result := Self; end;
function TAsyncClientBuilder.StrictHostKey(AValue: Boolean): ISshAsyncClientBuilder; begin FOptions.StrictHostKeyChecking := AValue; Result := Self; end;
function TAsyncClientBuilder.ExecTimeoutMs(AValue: Integer): ISshAsyncClientBuilder; begin FOptions.ExecTimeoutMs := AValue; Result := Self; end;
function TAsyncClientBuilder.Compress(AValue: Boolean): ISshAsyncClientBuilder; begin FOptions.Compress := AValue; Result := Self; end;
function TAsyncClientBuilder.DialOptions(const AValue: TAsyncTcpDialOptions): ISshAsyncClientBuilder; begin FDialOptions := AValue; FHasDialOptions := True; Result := Self; end;
function TAsyncClientBuilder.AsyncConnect(const ALoop: TAsyncLoop; ACallback: TSshAsyncConnectCb; AContext: Pointer): Boolean;
begin
  if FOptions.Host = '' then begin if Assigned(ACallback) then ACallback(nil, ESSHError.Create(sekProtocol, 'ssh client: host is required'), AContext); Exit(False); end;
  if FOptions.User = '' then begin if Assigned(ACallback) then ACallback(nil, ESSHError.Create(sekProtocol, 'ssh client: user is required'), AContext); Exit(False); end;
  if FHasDialOptions then
    Result := SshAsyncConnect(ALoop, FOptions, FDialOptions, ACallback, AContext)
  else
    Result := SshAsyncConnect(ALoop, FOptions, ACallback, AContext);
end;

function SshAsyncClient: ISshAsyncClientBuilder;
begin
  Result := TAsyncClientBuilder.Create;
end;

{ ---- free dispatchers ---- }

procedure SshAsyncDialCb(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
var Self: TAsyncConnector;
begin
  Self := TAsyncConnector(AContext);
  Self.OnDial(AStream, AError, nil);
end;

procedure SshAsync_OnVersionDone(const AIdent: string; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnVersionDone(AIdent, AErr, nil);
end;

procedure SshAsync_OnKexInitSent(AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnKexInitSent(AErr, nil);
end;

procedure SshAsync_OnKexInitRecv(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnKexInitRecv(APayload, AErr);
end;

procedure SshAsync_OnKexInitReplySent(AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnKexInitReplySent(AErr, nil);
end;

procedure SshAsync_OnKexReplyRecv(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnKexReplyRecv(APayload, AErr);
end;

procedure SshAsync_OnNewKeysSent(AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnNewKeysSent(AErr, nil);
end;

procedure SshAsync_OnPeerNewKeys(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnPeerNewKeys(APayload, AErr);
end;

procedure SshAsync_OnServiceSent(AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnServiceSent(AErr, nil);
end;

procedure SshAsync_OnServiceAccept(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).OnServiceAccept(APayload, AErr);
end;

procedure SshAsync_OnExpectPacket(const APayload: TBytes; AErr: ESSHError; AContext: Pointer);
begin
  TAsyncConnector(AContext).HandleExpectPacket(APayload, AErr, nil);
end;

end.
