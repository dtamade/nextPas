unit nextpas.core.ssh.session;

{** nextpas.core.ssh - 会话编排：连接 → 版本交换 → KEX → 主机密钥校验 →
 * 认证 → exec。
 *
 * 两条使用路径：
 *  - 高层：门面 SshClient fluent builder 或 SshConnect，一步到位；
 *  - 细粒度：自建 IReadWriteCloser（如测试内存管道）传入 CreateInternal，
 *    再依次调用 AuthenticateWithXxx。
 *
 * 主机密钥策略：签名必须验证通过；提供 KnownHostsFile 时按条目匹配，
 * StrictHostKeyChecking 开启时未知/不匹配即拒绝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport;

type
  { 已建立的 SSH 会话（阻塞式）}
  ISshSession = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000004}']
    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;

    { 密码认证。失败抛 ESSHError(sekAuth)。}
    procedure AuthenticateWithPassword(const AUser, APassword: string);

    { 公钥认证：openssh-key-v1 未加密容器内容（当前支持 ed25519）。}
    procedure AuthenticateWithPrivateKeyData(const AContent: string);

    { 执行一次性命令并收集输出。需已认证。}
    function Exec(const ACommand: string): TSshExecResult;

    procedure Close;

    property Connected: Boolean read GetConnected;
    property ServerVersion: string read GetServerVersion;
    property ServerHostKeyFingerprint: string read GetServerHostKeyFingerprint;
  end;

  { Fluent 连接构造器（COM 引用计数自动释放）}
  ISshClientBuilder = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000005}']
    function Host(const AValue: string): ISshClientBuilder;
    function Port(AValue: Word): ISshClientBuilder;
    function User(const AValue: string): ISshClientBuilder;
    function Password(const AValue: string): ISshClientBuilder;
    function PrivateKeyData(const AValue: string): ISshClientBuilder;
    function KnownHostsFile(const AValue: string): ISshClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshClientBuilder;
    { 建立 TCP、完成握手并按已填选项认证 }
    function Connect: ISshSession;
  end;

{ 拨号 + 握手 + 认证一步到位 }
function SshConnect(const AOptions: TSshConnectOptions): ISshSession;

{ 细粒度入口：在自建 IO（如测试内存管道）上完成握手与认证。
  认证方式由 AOptions 决定，语义同 SshConnect；不拨号。}
function SshConnectOn(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions): ISshSession;

{ Fluent 构造器入口 }
function SshClient: ISshClientBuilder;

implementation

uses
  nextpas.core.crypto.random,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.hash,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.auth,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.kex.curve25519;

const
  DISCONNECT_BY_APPLICATION = 11;
  SSH_ALG_ED25519 = 'ssh-ed25519';

function InByteList(AValue: Byte; const AList: array of Byte): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if AList[I] = AValue then
      Exit(True);
  Result := False;
end;

function SingleBytePayload(AMsg: Byte): TBytes;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := AMsg;
end;

type
  TSshSession = class(TInterfacedObject, ISshSession)
  private
    FIO: IReadWriteCloser;
    FTransport: TSshClientTransport;
    FOptions: TSshConnectOptions;
    FActiveUser: string;
    FSessionId: TBytes;
    FHandshaken: Boolean;
    FAuthenticated: Boolean;
    FClosed: Boolean;
    FHostKeyInfo: TSshHostKeyInfo;
    FHostKeyBlob: TBytes;
    FHostKeyFingerprint: string;
    FKnownHosts: TSshKnownHosts;
    FKnownHostsLoaded: Boolean;

    procedure EnsureHandshaken;
    procedure EnsureAuthenticated;
    procedure DoHandshake;
    procedure DoServiceRequest;
    procedure VerifyHostKey(const ASigAlg: string; const AH, ASigBlob: TBytes);
    procedure LoadKnownHostsIfNeeded;
    function ExpectOneOf(const AAcceptable: array of Byte): TBytes;
    procedure DeriveAndApplyNewKeys(const ANegotiated: TSshNegotiated;
      const AK, AH: TBytes);
  public
    constructor CreateInternal(const AIO: IReadWriteCloser;
      const AOptions: TSshConnectOptions);
    destructor Destroy; override;

    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;
    procedure AuthenticateWithPassword(const AUser, APassword: string);
    procedure AuthenticateWithPrivateKeyData(const AContent: string);
    function Exec(const ACommand: string): TSshExecResult;
    procedure Close;
  end;

  TSshClientBuilder = class(TInterfacedObject, ISshClientBuilder)
  private
    FOptions: TSshConnectOptions;
  public
    constructor Create;
    function Host(const AValue: string): ISshClientBuilder;
    function Port(AValue: Word): ISshClientBuilder;
    function User(const AValue: string): ISshClientBuilder;
    function Password(const AValue: string): ISshClientBuilder;
    function PrivateKeyData(const AValue: string): ISshClientBuilder;
    function KnownHostsFile(const AValue: string): ISshClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshClientBuilder;
    function Connect: ISshSession;
  end;

{ TSshSession }

constructor TSshSession.CreateInternal(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions);
begin
  inherited Create;
  FIO := AIO;
  FOptions := AOptions;
  FTransport := TSshClientTransport.Create(AIO);
  FKnownHosts := nil;
  FKnownHostsLoaded := False;
end;

destructor TSshSession.Destroy;
begin
  Close;
  FreeAndNil(FTransport);
  FreeAndNil(FKnownHosts);
  inherited Destroy;
end;

function TSshSession.GetConnected: Boolean;
begin
  Result := (not FClosed) and FAuthenticated;
end;

function TSshSession.GetServerVersion: string;
begin
  if FTransport <> nil then
    Result := FTransport.ServerIdent
  else
    Result := '';
end;

function TSshSession.GetServerHostKeyFingerprint: string;
begin
  Result := FHostKeyFingerprint;
end;

procedure TSshSession.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    if FTransport <> nil then
      FTransport.Disconnect(DISCONNECT_BY_APPLICATION, 'client closing');
  end;
end;

function TSshSession.ExpectOneOf(const AAcceptable: array of Byte): TBytes;
begin
  while True do
  begin
    Result := PumpMessage(FTransport);
    if InByteList(Result[0], AAcceptable) then
      Exit;
  end;
end;

procedure TSshSession.EnsureHandshaken;
begin
  if FClosed then
    raise ESSHError.Create(sekIO, 'ssh session: closed');
  if not FHandshaken then
    DoHandshake;
end;

procedure TSshSession.EnsureAuthenticated;
begin
  EnsureHandshaken;
  if not FAuthenticated then
    raise ESSHError.Create(sekAuth, 'ssh session: not authenticated');
end;

procedure TSshSession.LoadKnownHostsIfNeeded;
begin
  if FKnownHostsLoaded then
    Exit;
  FKnownHostsLoaded := True;
  if FOptions.KnownHostsFile <> '' then
  begin
    FKnownHosts := TSshKnownHosts.Create;
    FKnownHosts.LoadFromFile(FOptions.KnownHostsFile);
  end;
end;

procedure TSshSession.VerifyHostKey(const ASigAlg: string;
  const AH, ASigBlob: TBytes);
var
  LInFile: Boolean;
begin
  { 第一步：密码学签名必须有效 }
  if not SshVerifyHostSignature(FHostKeyInfo, ASigAlg, AH, ASigBlob) then
    raise ESSHError.Create(sekHostKey,
      'ssh session: host key signature invalid (' +
      SshFingerprintSHA256(FHostKeyBlob) + ')');

  { 第二步：known_hosts 策略（未配置文件则只验签名）}
  LoadKnownHostsIfNeeded;
  if FKnownHosts <> nil then
  begin
    LInFile := FKnownHosts.ContainsKey(FOptions.Host, FOptions.Port, FHostKeyBlob);
    if (not LInFile) and FOptions.StrictHostKeyChecking then
      raise ESSHError.Create(sekHostKey,
        'ssh session: host key not in known_hosts (' +
        FOptions.Host + ':' + IntToStr(FOptions.Port) + ', ' +
        FHostKeyFingerprint + ')');
  end;
end;

procedure TSshSession.DoHandshake;
var
  LCookie, LMyInit, LPeerInit, LReply: TBytes;
  LPeer: TSshPeerKexInit;
  LNeg: TSshNegotiated;
  LKex: TSshKexCurve25519;
  LK, LH, LHostBlob, LSigBlob: TBytes;
begin
  FTransport.ExchangeVersions;

  LCookie := GenerateSecureRandomBytes(16);
  LMyInit := FTransport.SendKexInit(LCookie);

  LPeerInit := ExpectOneOf([SSH_MSG_KEXINIT]);
  LPeer := SshParseKexInit(LPeerInit);
  LNeg := SshNegotiate(LPeer);

  LKex := TSshKexCurve25519.Create;
  try
    FTransport.SendPacket(LKex.BuildInitPayload);
    LReply := ExpectOneOf([SSH_MSG_KEX_ECDH_REPLY]);
    LKex.ProcessReply(LReply, SSH_PROTOCOL_VERSION, FTransport.ServerIdent,
      LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
  finally
    LKex.Free;
  end;

  FHostKeyBlob := LHostBlob;
  if not SshParseHostKey(LHostBlob, FHostKeyInfo) then
    raise ESSHError.Create(sekHostKey, 'ssh session: unsupported host key blob');
  VerifyHostKey(LNeg.HostKeyAlg, LH, LSigBlob);
  FHostKeyFingerprint := SshFingerprintSHA256(LHostBlob);

  FSessionId := LH;  { 首次 KEX：session_id = H }
  DeriveAndApplyNewKeys(LNeg, LK, LH);
  DoServiceRequest;
  FHandshaken := True;
end;

procedure TSshSession.DeriveAndApplyNewKeys(const ANegotiated: TSshNegotiated;
  const AK, AH: TBytes);
var
  LW: TsshWriter;
  LKmpint, LIvCs, LIvSc, LKeyCs, LKeySc, LMacCs, LMacSc: TBytes;
begin
  LW := TsshWriter.Create(80);
  try
    LW.PutMPInt(AK);
    LKmpint := LW.ToBytes;
  finally
    LW.Free;
  end;

  LIvCs := SshKdfSha256(LKmpint, AH, Ord('A'), FSessionId,
    SshCipherIvSize(ANegotiated.EncCs));
  LIvSc := SshKdfSha256(LKmpint, AH, Ord('B'), FSessionId,
    SshCipherIvSize(ANegotiated.EncSc));
  LKeyCs := SshKdfSha256(LKmpint, AH, Ord('C'), FSessionId,
    SshCipherKeySize(ANegotiated.EncCs));
  LKeySc := SshKdfSha256(LKmpint, AH, Ord('D'), FSessionId,
    SshCipherKeySize(ANegotiated.EncSc));
  LMacCs := SshKdfSha256(LKmpint, AH, Ord('E'), FSessionId,
    SshMacKeySize(ANegotiated.MacCs));
  LMacSc := SshKdfSha256(LKmpint, AH, Ord('F'), FSessionId,
    SshMacKeySize(ANegotiated.MacSc));

  FTransport.SendPacket(SingleBytePayload(SSH_MSG_NEWKEYS));
  ExpectOneOf([SSH_MSG_NEWKEYS]);
  FTransport.ApplyNewKeys(ANegotiated,
    LIvCs, LKeyCs, LMacCs, LIvSc, LKeySc, LMacSc);
end;

procedure TSshSession.DoServiceRequest;
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(32);
  try
    LW.PutByte(SSH_MSG_SERVICE_REQUEST);
    LW.PutStringText(SSH_SERVICE_USERAUTH);
    FTransport.SendPacket(LW.ToBytes);
  finally
    LW.Free;
  end;
  ExpectOneOf([SSH_MSG_SERVICE_ACCEPT]);
end;

procedure TSshSession.AuthenticateWithPassword(const AUser, APassword: string);
var
  LR: TsshReader;
  LMsg: TBytes;
begin
  EnsureHandshaken;
  FActiveUser := AUser;

  FTransport.SendPacket(SshBuildAuthPassword(AUser, APassword));

  LMsg := ExpectOneOf([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
  if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    FAuthenticated := True
  else
  begin
    LR := TsshReader.Create(LMsg);
    try
      LR.ReadByte;
      LR.ReadStringText;  { 可继续尝试的方法列表 }
    finally
      LR.Free;
    end;
    raise ESSHError.Create(sekAuth,
      'ssh session: password rejected for user "' + AUser + '"');
  end;
end;

procedure TSshSession.AuthenticateWithPrivateKeyData(const AContent: string);
var
  LR: TsshReader;
  LMsg: TBytes;
  LKey: TSshPrivateKey;
  LPubBlob, LSignedData, LSig64, LSigBlob: TBytes;
begin
  EnsureHandshaken;

  if not SshLoadPrivateKey(AContent, LKey, LPubBlob) then
    raise ESSHError.Create(sekKeyFormat, 'ssh session: private key parse failed');
  if LKey.Kind <> hkEd25519 then
    raise ESSHError.Create(sekUnsupported,
      'ssh session: only unencrypted ed25519 private keys supported');

  LSignedData := SshAuthSignedData(FSessionId, FActiveUser, SSH_ALG_ED25519, LPubBlob);
  if not Ed25519Sign(LKey.Ed25519Seed, LSignedData, LSig64) then
    raise ESSHError.Create(sekCrypto, 'ssh session: ed25519 sign failed');
  LSigBlob := SshBuildEd25519SigBlob(LSig64);
  FTransport.SendPacket(
    SshBuildAuthPubKeySigned(FActiveUser, SSH_ALG_ED25519, LPubBlob, LSigBlob));

  LMsg := ExpectOneOf([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
  if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    FAuthenticated := True
  else
  begin
    LR := TsshReader.Create(LMsg);
    try
      LR.ReadByte;
      LR.ReadStringText;
    finally
      LR.Free;
    end;
    raise ESSHError.Create(sekAuth, 'ssh session: publickey rejected');
  end;
end;

function TSshSession.Exec(const ACommand: string): TSshExecResult;
begin
  EnsureAuthenticated;
  Result := SshRunExec(FTransport, ACommand,
    FOptions.InitialWindowSize, FOptions.MaxPacket, FOptions.ExecTimeoutMs);
end;

{ TSshClientBuilder }

constructor TSshClientBuilder.Create;
begin
  inherited Create;
  FOptions := DefaultSshConnectOptions('');
end;

function TSshClientBuilder.Host(const AValue: string): ISshClientBuilder;
begin
  FOptions.Host := AValue;
  Result := Self;
end;

function TSshClientBuilder.Port(AValue: Word): ISshClientBuilder;
begin
  FOptions.Port := AValue;
  Result := Self;
end;

function TSshClientBuilder.User(const AValue: string): ISshClientBuilder;
begin
  FOptions.User := AValue;
  Result := Self;
end;

function TSshClientBuilder.Password(const AValue: string): ISshClientBuilder;
begin
  FOptions.Password := AValue;
  Result := Self;
end;

function TSshClientBuilder.PrivateKeyData(const AValue: string): ISshClientBuilder;
begin
  FOptions.PrivateKeyData := AValue;
  Result := Self;
end;

function TSshClientBuilder.KnownHostsFile(const AValue: string): ISshClientBuilder;
begin
  FOptions.KnownHostsFile := AValue;
  Result := Self;
end;

function TSshClientBuilder.StrictHostKey(AValue: Boolean): ISshClientBuilder;
begin
  FOptions.StrictHostKeyChecking := AValue;
  Result := Self;
end;

function TSshClientBuilder.ExecTimeoutMs(AValue: Integer): ISshClientBuilder;
begin
  FOptions.ExecTimeoutMs := AValue;
  Result := Self;
end;

function TSshClientBuilder.Connect: ISshSession;
begin
  if FOptions.Host = '' then
    raise ESSHError.Create(sekProtocol, 'ssh client: host is required');
  if FOptions.User = '' then
    raise ESSHError.Create(sekProtocol, 'ssh client: user is required');
  Result := SshConnect(FOptions);
end;

{ 入口函数 }

procedure RunAuthentication(const ASession: TSshSession;
  const AOptions: TSshConnectOptions);
begin
  if AOptions.User = '' then
    raise ESSHError.Create(sekProtocol, 'ssh connect: user is required');
  ASession.FActiveUser := AOptions.User;
  if AOptions.PrivateKeyData <> '' then
    ASession.AuthenticateWithPrivateKeyData(AOptions.PrivateKeyData)
  else
    ASession.AuthenticateWithPassword(AOptions.User, AOptions.Password);
end;

function SshConnect(const AOptions: TSshConnectOptions): ISshSession;
var
  LTcp: ITcpStream;
  LSession: TSshSession;
begin
  if AOptions.Host = '' then
    raise ESSHError.Create(sekProtocol, 'ssh connect: host is required');
  LTcp := TcpConnect(AOptions.Host, AOptions.Port);
  try
    LSession := TSshSession.CreateInternal(LTcp, AOptions);
    try
      RunAuthentication(LSession, AOptions);
      Result := LSession;
    except
      LSession.Free;
      raise;
    end;
  except
    LTcp := nil;
    raise;
  end;
end;

function SshClient: ISshClientBuilder;
begin
  Result := TSshClientBuilder.Create;
end;

function SshConnectOn(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions): ISshSession;
var
  LSession: TSshSession;
begin
  LSession := TSshSession.CreateInternal(AIO, AOptions);
  try
    RunAuthentication(LSession, AOptions);
    Result := LSession;
  except
    LSession.Free;
    raise;
  end;
end;

end.
