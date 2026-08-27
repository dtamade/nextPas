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
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.base.utils,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.sftp;

type
  { 已建立的 SSH 会话（阻塞式）}
  ISshSession = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000004}']
    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;

    { 密码认证。失败抛 ESSHError(sekAuth)。}
    procedure AuthenticateWithPassword(const AUser, APassword: string);

    { 公钥认证：openssh-key-v1 容器内容（未加密或 aes256-ctr+bcrypt 加密）。
      未加密时 APassphrase 被忽略。}
    procedure AuthenticateWithPrivateKeyData(const AContent: string); overload;
    procedure AuthenticateWithPrivateKeyData(const AContent, APassphrase: string); overload;

    { ssh-agent 认证：通过 Unix socket 与 agent 通信，枚举身份并逐一探测。}
    procedure AuthenticateWithAgent(const APath: string);
    { 测试缝隙：直接注入已连通的 agent IO（内存管道），避免文件系统依赖。}
    procedure AuthenticateWithAgentOn(const AAgentIO: IReadWriteCloser);

    { 执行一次性命令并收集输出。需已认证。}
    function Exec(const ACommand: string): TSshExecResult;

    { 打开 sftp 子系统并完成版本握手，返回文件操作面。
      需已认证；同一会话可多次调用（各自独立通道）。}
    function OpenFileSystem: ISshFileSystem;

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
    function PrivateKeyPassphrase(const AValue: string): ISshClientBuilder;
    function AgentSocketPath(const AValue: string): ISshClientBuilder;
    function KnownHostsFile(const AValue: string): ISshClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshClientBuilder;
    function Compress(AValue: Boolean): ISshClientBuilder;
    { 建立 TCP、完成握手并按已填选项认证 }
    function Connect: ISshSession;
  end;

{ 拨号 + 握手 + 认证一步到位 }
function SshConnect(const AOptions: TSshConnectOptions): ISshSession;

{ 细粒度入口：在自建 IO（如测试内存管道）上完成握手与认证。
  认证方式由 AOptions 决定，语义同 SshConnect；不拨号。}
function SshConnectOn(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions): ISshSession;

{ 创建未认证会话，供 AuthenticateWithXxx/AuthenticateWithAgentOn 手动驱动
  （测试缝隙；不拨号，不触发 RunAuthentication）。}
function SshCreateSession(const AIO: IReadWriteCloser;
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
  nextpas.core.ssh.rsa,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.kex.dhgroup14;

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
    FNegotiated: TSshNegotiated;

    procedure EnsureHandshaken;
    procedure EnsureAuthenticated;
    procedure DoHandshake;
    procedure DoServiceRequest;
    procedure VerifyHostKey(const ASigAlg: string; const AH, ASigBlob: TBytes);
    procedure LoadKnownHostsIfNeeded;
    function ExpectOneOf(const AAcceptable: array of Byte): TBytes;
    procedure DeriveAndApplyNewKeys(const ANegotiated: TSshNegotiated;
      const AK, AH: TBytes);
    procedure AuthenticateWithAgentClient(const AAgent: TSshAgentClient);
    procedure TryEnableDelayedCompression;
  public
    constructor CreateInternal(const AIO: IReadWriteCloser;
      const AOptions: TSshConnectOptions);
    destructor Destroy; override;

    function GetConnected: Boolean;
    function GetServerVersion: string;
    function GetServerHostKeyFingerprint: string;
    procedure AuthenticateWithPassword(const AUser, APassword: string);
    procedure AuthenticateWithPrivateKeyData(const AContent: string); overload;
    procedure AuthenticateWithPrivateKeyData(const AContent, APassphrase: string); overload;
    procedure AuthenticateWithAgent(const APath: string);
    procedure AuthenticateWithAgentOn(const AAgentIO: IReadWriteCloser);
    function Exec(const ACommand: string): TSshExecResult;
    function OpenFileSystem: ISshFileSystem;
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
    function PrivateKeyPassphrase(const AValue: string): ISshClientBuilder;
    function AgentSocketPath(const AValue: string): ISshClientBuilder;
    function KnownHostsFile(const AValue: string): ISshClientBuilder;
    function StrictHostKey(AValue: Boolean): ISshClientBuilder;
    function ExecTimeoutMs(AValue: Integer): ISshClientBuilder;
    function Compress(AValue: Boolean): ISshClientBuilder;
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
      try
        FTransport.Disconnect(DISCONNECT_BY_APPLICATION, 'client closing');
      except
        { 关闭路径的断连失败不影响调用方；底层流仍会被释放 }
      end;
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

procedure TSshSession.TryEnableDelayedCompression;
begin
  if FAuthenticated and (SshCompressionIsDelayed(FNegotiated.CompCs)
    or SshCompressionIsDelayed(FNegotiated.CompSc)) then
    FTransport.EnableCompression;
end;

procedure TSshSession.DoHandshake;
var
  LCookie, LMyInit, LPeerInit, LReply: TBytes;
  LPeer: TSshPeerKexInit;
  LNeg: TSshNegotiated;
  LK, LH, LHostBlob, LSigBlob: TBytes;
  LKexCurve: TSshKexCurve25519;
  LKexDH: TSshKexDHGroup14;
begin
  FTransport.ExchangeVersions;

  LCookie := GenerateSecureRandomBytes(16);
  LMyInit := FTransport.SendKexInitEx(LCookie, FOptions.Compress);

  LPeerInit := ExpectOneOf([SSH_MSG_KEXINIT]);
  LPeer := SshParseKexInit(LPeerInit);
  LNeg := SshNegotiateEx(LPeer, FOptions.Compress);
  FNegotiated := LNeg;

  if LNeg.KexAlg = 'diffie-hellman-group14-sha256' then
  begin
    LKexDH := TSshKexDHGroup14.Create;
    try
      FTransport.SendPacket(LKexDH.BuildInitPayload);
      LReply := ExpectOneOf([SSH_MSG_KEX_ECDH_REPLY]);
      LKexDH.ProcessReply(LReply, SSH_PROTOCOL_VERSION, FTransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally
      LKexDH.Free;
    end;
  end
  else
  begin
    LKexCurve := TSshKexCurve25519.Create;
    try
      FTransport.SendPacket(LKexCurve.BuildInitPayload);
      LReply := ExpectOneOf([SSH_MSG_KEX_ECDH_REPLY]);
      LKexCurve.ProcessReply(LReply, SSH_PROTOCOL_VERSION, FTransport.ServerIdent,
        LMyInit, LPeerInit, LK, LH, LHostBlob, LSigBlob);
    finally
      LKexCurve.Free;
    end;
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
  FTransport.SetNegotiatedCompression(ANegotiated);
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
  begin
    FAuthenticated := True;
    TryEnableDelayedCompression;
  end
  else
  begin
    LR := TsshReader.Create(LMsg);
    try
      LR.ReadByte;
      LR.ReadStringText;
    finally
      LR.Free;
    end;
    raise ESSHError.Create(sekAuth,
      'ssh session: password rejected for user "' + AUser + '"');
  end;
end;

procedure TSshSession.AuthenticateWithPrivateKeyData(const AContent: string); overload;
begin
  AuthenticateWithPrivateKeyData(AContent, FOptions.PrivateKeyPassphrase);
end;

procedure TSshSession.AuthenticateWithPrivateKeyData(const AContent, APassphrase: string); overload;
var
  LR: TsshReader;
  LMsg: TBytes;
  LKey: TSshPrivateKey;
  LPubBlob, LSignedData, LSig64, LSigRaw, LSigBlob: TBytes;
  LAlgName: string;

  { USERAUTH 回复收口：SUCCESS 置位；FAILURE 抛 sekAuth（带可继续方法表）}
  procedure AwaitSuccessOrRaise(const AWhat: string);
  begin
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
      raise ESSHError.Create(sekAuth, 'ssh session: ' + AWhat + ' rejected');
    end;
  end;

begin
  EnsureHandshaken;

  if not SshLoadPrivateKey(AContent, LKey, LPubBlob, APassphrase) then
    raise ESSHError.Create(sekKeyFormat, 'ssh session: private key parse failed');

  case LKey.Kind of
    hkEd25519:
      begin
        LAlgName := SSH_ALG_ED25519;
        LSignedData := SshAuthSignedData(FSessionId, FActiveUser, LAlgName, LPubBlob);
        if not Ed25519Sign(LKey.Ed25519Seed, LSignedData, LSig64) then
          raise ESSHError.Create(sekCrypto, 'ssh session: ed25519 sign failed');
        LSigBlob := SshBuildEd25519SigBlob(LSig64);
      end;
    hkRsa:
      begin
        { rsa-sha2-512 与 rsa-sha2-256 同版本引入且被一切接受 RSA 的服务端
          支持；选最强档，单次尝试不做降级。优先走 CRT（p/q/iqmp 存在时约 4x
          加速），失败则回退到朴素模幂以兼顾非法 CRT 容器/测试哑数据。}
        LAlgName := SSH_RSA_SIG_SHA512;
        LSignedData := SshAuthSignedData(FSessionId, FActiveUser, LAlgName, LPubBlob);
        if LKey.RsaHasCrt then
        begin
          if not RsaSignPkcs1v15Crt(LKey.RsaN, LKey.RsaD, LKey.RsaP, LKey.RsaQ,
            LKey.RsaIqmp, SHA512(LSignedData), DIGEST_INFO_SHA512, LSigRaw) then
            if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData),
              DIGEST_INFO_SHA512, LSigRaw) then
              raise ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed');
        end
        else
          if not RsaSignPkcs1v15(LKey.RsaN, LKey.RsaD, SHA512(LSignedData),
            DIGEST_INFO_SHA512, LSigRaw) then
            raise ESSHError.Create(sekCrypto, 'ssh session: rsa sign failed');
        LSigBlob := SshBuildRsaSigBlob(LSigRaw, LAlgName);
      end;
  else
    raise ESSHError.Create(sekUnsupported,
      'ssh session: unsupported private key kind');
  end;

  FTransport.SendPacket(
    SshBuildAuthPubKeySigned(FActiveUser, LAlgName, LPubBlob, LSigBlob));
  AwaitSuccessOrRaise('publickey');
  TryEnableDelayedCompression;
end;

procedure TSshSession.AuthenticateWithAgent(const APath: string);
var
  LAgent: TSshAgentClient;
begin
  EnsureHandshaken;
  if APath = '' then
    raise ESSHError.Create(sekIO, 'ssh session: agent socket path empty');
  LAgent := SshAgentConnect(APath);
  try
    AuthenticateWithAgentClient(LAgent);
  finally
    LAgent.Free;
  end;
end;

procedure TSshSession.AuthenticateWithAgentOn(const AAgentIO: IReadWriteCloser);
var
  LAgent: TSshAgentClient;
begin
  EnsureHandshaken;
  LAgent := TSshAgentClient.Create(AAgentIO);
  try
    AuthenticateWithAgentClient(LAgent);
  finally
    LAgent.Free;
  end;
end;

procedure TSshSession.AuthenticateWithAgentClient(const AAgent: TSshAgentClient);
var
  LIds: TSshAgentIdentityArray;
  I: Integer;
  LAlgName: string;
  LSignedData, LSigBlob: TBytes;
  LFlags: UInt32;
  LMsg: TBytes;
begin
  if not AAgent.ListIdentities(LIds) then
    raise ESSHError.Create(sekAuth, 'ssh session: agent list failed');
  if Length(LIds) = 0 then
    raise ESSHError.Create(sekAuth, 'ssh session: agent has no identities');
  for I := 0 to High(LIds) do
  begin
    LAlgName := LIds[I].AlgName;
    if LAlgName = '' then Continue;
    FTransport.SendPacket(SshBuildAuthPubKeyProbe(FActiveUser, LAlgName, LIds[I].Blob));
    LMsg := ExpectOneOf([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE, SSH_MSG_USERAUTH_PK_OK]);
    if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    begin
      FAuthenticated := True;
      TryEnableDelayedCompression;
      Exit;
    end;
    if LMsg[0] = SSH_MSG_USERAUTH_FAILURE then Continue;
    LFlags := SshAgentKeyBlobToSignFlags(LIds[I].Blob);
    LSignedData := SshAuthSignedData(FSessionId, FActiveUser, LAlgName, LIds[I].Blob);
    if not AAgent.Sign(LIds[I].Blob, LSignedData, LFlags, LSigBlob) then Continue;
    FTransport.SendPacket(SshBuildAuthPubKeySigned(FActiveUser, LAlgName, LIds[I].Blob, LSigBlob));
    LMsg := ExpectOneOf([SSH_MSG_USERAUTH_SUCCESS, SSH_MSG_USERAUTH_FAILURE]);
    if LMsg[0] = SSH_MSG_USERAUTH_SUCCESS then
    begin
      FAuthenticated := True;
      TryEnableDelayedCompression;
      Exit;
    end;
    // else try next identity
  end;
  raise ESSHError.Create(sekAuth, 'ssh session: agent publickey rejected');
end;

function TSshSession.Exec(const ACommand: string): TSshExecResult;
begin
  EnsureAuthenticated;
  Result := SshRunExec(FTransport, ACommand,
    FOptions.InitialWindowSize, FOptions.MaxPacket, FOptions.ExecTimeoutMs);
end;

function TSshSession.OpenFileSystem: ISshFileSystem;
begin
  EnsureAuthenticated;
  Result := SftpOpenOnTransport(FTransport, FOptions.InitialWindowSize,
    FOptions.MaxPacket, FOptions.ExecTimeoutMs);
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

function TSshClientBuilder.PrivateKeyPassphrase(const AValue: string): ISshClientBuilder;
begin
  FOptions.PrivateKeyPassphrase := AValue;
  Result := Self;
end;

function TSshClientBuilder.AgentSocketPath(const AValue: string): ISshClientBuilder;
begin
  FOptions.AgentSocketPath := AValue;
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

function TSshClientBuilder.Compress(AValue: Boolean): ISshClientBuilder;
begin
  FOptions.Compress := AValue;
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
var
  LAgentOk: Boolean;
begin
  if AOptions.User = '' then
    raise ESSHError.Create(sekProtocol, 'ssh connect: user is required');
  ASession.FActiveUser := AOptions.User;
  if AOptions.AgentSocketPath <> '' then
  begin
    LAgentOk := False;
    try
      ASession.AuthenticateWithAgent(AOptions.AgentSocketPath);
      LAgentOk := True;
    except
      on E: ESSHError do
      begin
        if E.Kind in [sekAuth, sekIO] then
        begin
          if (AOptions.PrivateKeyData = '') and (AOptions.Password = '') then
            raise;
        end
        else
          raise;
      end;
    end;
    if LAgentOk then Exit;
  end;
  if AOptions.PrivateKeyData <> '' then
    ASession.AuthenticateWithPrivateKeyData(AOptions.PrivateKeyData,
      AOptions.PrivateKeyPassphrase)
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

function SshCreateSession(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions): ISshSession;
begin
  Result := TSshSession.CreateInternal(AIO, AOptions);
end;

end.
