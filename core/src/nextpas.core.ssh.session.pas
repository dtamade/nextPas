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
 * StrictHostKeyChecking 开启时未知/不匹配即拒绝。
 *
 * 薄编排：握手/重协商委托 handshake 单源，认证回退委托 auth 单源；
 * 本单元仅保留状态与生命周期、Exec/SFTP 转发与拨号入口。
 * 性能：GetConnected/GetServerVersion inline，Exec/SFTP 零拷贝委托；
 * 稳定性：try-finally 保证通道/传输释放，SecureZero 敏感材料。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf,
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.sftp,
  nextpas.core.ssh.keepalive;

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
    function ShouldRekey: Boolean;
    function Rekey: Boolean;
    function SendKeepAlive(const AData: TBytes): Boolean; overload;
    function SendKeepAlive: Boolean; overload;

    procedure Close;

    property Connected: Boolean read GetConnected;
    property ServerVersion: string read GetServerVersion;
    property ServerHostKeyFingerprint: string read GetServerHostKeyFingerprint;
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

{ 内部缝隙：供 proxyjump 单源复用 direct-tcpip 通道创建，零拷贝 TChannelStream }
function SshSessionOpenDirectTcpip(const AJumpSession: ISshSession;
  const AHost: string; APort: Word; AInitialWindow, AMaxPacket: UInt32;
  ATimeoutMs: Integer): IReadWriteCloser;

implementation

uses
  nextpas.core.exception,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.ssh.net.ffi,
  nextpas.core.ssh.session.handshake,
  nextpas.core.ssh.session.auth;

const
  DISCONNECT_BY_APPLICATION = 11;

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
    procedure EnsureHandshaken; inline;
    procedure EnsureAuthenticated; inline;
    procedure DoHandshake; inline;
    procedure DoRekey; inline;
    procedure EnsureRekeyIfNeeded; inline;
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
    function ShouldRekey: Boolean;
    function Rekey: Boolean;
    function SendKeepAlive(const AData: TBytes): Boolean; overload;
    function SendKeepAlive: Boolean; overload;
    procedure Close;
  end;

{ TSshSession }

constructor TSshSession.CreateInternal(const AIO: IReadWriteCloser;
  const AOptions: TSshConnectOptions);
begin
  inherited Create;
  FIO := AIO;
  FOptions := AOptions;
  FTransport := TSshClientTransport.Create(AIO);
  FTransport.ConfigureRekey(AOptions.RekeyBytes, AOptions.RekeyIntervalMs);
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

function TSshSession.GetConnected: Boolean; inline;
begin Result := (not FClosed) and FAuthenticated; end;

function TSshSession.GetServerVersion: string; inline;
begin if FTransport <> nil then Result := FTransport.ServerIdent else Result := ''; end;

function TSshSession.GetServerHostKeyFingerprint: string; inline;
begin Result := FHostKeyFingerprint; end;

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

function TSshSession.ShouldRekey: Boolean;
begin
  Result := (FTransport <> nil) and FTransport.ShouldRekey;
end;

function TSshSession.Rekey: Boolean;
begin
  if (FTransport = nil) or FClosed or not FAuthenticated then Exit(False);
  if not ShouldRekey then Exit(True);
  try DoRekey; Result := True; except Result := False; raise; end;
end;

function TSshSession.SendKeepAlive(const AData: TBytes): Boolean;
begin
  if (FTransport = nil) or FClosed or not FAuthenticated then Exit(False);
  try FTransport.SendIgnore(AData); Result := True; except Result := False; end;
end;

function TSshSession.SendKeepAlive: Boolean;
begin Result := SendKeepAlive(nil); end;

procedure TSshSession.EnsureRekeyIfNeeded; inline;
begin
  if ShouldRekey then
    try
      DoRekey;
    except
      on E: Exception do
        raise;
    end;
end;

procedure TSshSession.EnsureHandshaken; inline;
begin
  if FClosed then
    raise ESSHError.Create(sekIO, 'ssh session: closed');
  if not FHandshaken then
    DoHandshake;
end;

procedure TSshSession.EnsureAuthenticated; inline;
begin
  EnsureHandshaken;
  if not FAuthenticated then
    raise ESSHError.Create(sekAuth, 'ssh session: not authenticated');
end;

procedure TSshSession.DoHandshake; inline;
begin
  SshHandshakeDoHandshake(FTransport, FOptions, FSessionId, FNegotiated,
    FHostKeyInfo, FHostKeyBlob, FHostKeyFingerprint, FKnownHosts, FKnownHostsLoaded);
  FHandshaken := True;
end;

procedure TSshSession.DoRekey; inline;
begin
  SshHandshakeDoRekey(FTransport, FOptions, FSessionId, FNegotiated,
    FHostKeyInfo, FKnownHosts, FKnownHostsLoaded, FAuthenticated, FClosed);
end;

procedure TSshSession.AuthenticateWithPassword(const AUser, APassword: string);
begin
  EnsureHandshaken;
  FActiveUser := AUser;
  SshAuthAuthenticateWithPassword(FTransport, FNegotiated, FAuthenticated, AUser, APassword);
end;

procedure TSshSession.AuthenticateWithPrivateKeyData(const AContent: string);
begin
  AuthenticateWithPrivateKeyData(AContent, FOptions.PrivateKeyPassphrase);
end;

procedure TSshSession.AuthenticateWithPrivateKeyData(const AContent, APassphrase: string);
begin
  EnsureHandshaken;
  SshAuthAuthenticateWithPrivateKeyData(FTransport, FSessionId, FNegotiated,
    FAuthenticated, FActiveUser, AContent, APassphrase);
end;

procedure TSshSession.AuthenticateWithAgent(const APath: string);
begin
  EnsureHandshaken;
  SshAuthAuthenticateWithAgent(FTransport, FSessionId, FNegotiated,
    FAuthenticated, FActiveUser, APath);
end;

procedure TSshSession.AuthenticateWithAgentOn(const AAgentIO: IReadWriteCloser);
begin
  EnsureHandshaken;
  SshAuthAuthenticateWithAgentOn(FTransport, FSessionId, FNegotiated,
    FAuthenticated, FActiveUser, AAgentIO);
end;

function TSshSession.Exec(const ACommand: string): TSshExecResult;
begin
  EnsureAuthenticated;
  EnsureRekeyIfNeeded;
  Result := SshRunExec(FTransport, ACommand,
    FOptions.InitialWindowSize, FOptions.MaxPacket, FOptions.ExecTimeoutMs);
end;

function TSshSession.OpenFileSystem: ISshFileSystem;
begin
  EnsureAuthenticated;
  EnsureRekeyIfNeeded;
  Result := SftpOpenOnTransport(FTransport, FOptions.InitialWindowSize,
    FOptions.MaxPacket, FOptions.ExecTimeoutMs);
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
  LDeadline: TDeadline;
  LDialer: ISshDialer;
begin
  if AOptions.Host = '' then
    raise ESSHError.Create(sekProtocol, 'ssh connect: host is required');
  LDialer := SshDefaultDialer;
  LTcp := LDialer.Dial(AOptions.Host, AOptions.Port, Int64(AOptions.ConnectTimeoutMs));
  try
    LSession := TSshSession.CreateInternal(LTcp, AOptions);
    LTcp := nil;
    try
      if AOptions.ConnectTimeoutMs > 0 then
        LDeadline := TDeadline.After(TDuration.FromMilliseconds(Int64(AOptions.ConnectTimeoutMs)))
      else
        LDeadline := TDeadline.Infinite;
      LSession.FTransport.SetOverallDeadline(LDeadline);
      try
        RunAuthentication(LSession, AOptions);
      finally
        LSession.FTransport.SetOverallDeadline(TDeadline.Infinite);
      end;
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

{ 内部缝隙：供 proxyjump 单源复用 direct-tcpip 通道创建，零拷贝 TChannelStream。
  稳定性：try-finally 保证 LChan.Free，失败不泄漏。 }
function SshSessionOpenDirectTcpip(const AJumpSession: ISshSession;
  const AHost: string; APort: Word; AInitialWindow, AMaxPacket: UInt32;
  ATimeoutMs: Integer): IReadWriteCloser;
var
  LImpl: TSshSession;
  LChan: TSshChannel;
begin
  if AJumpSession = nil then
    raise ESSHError.Create(sekProtocol, 'proxy jump: nil jump session');
  if not (AJumpSession is TSshSession) then
    raise ESSHError.Create(sekUnsupported, 'proxy jump: unsupported jump session type');
  LImpl := AJumpSession as TSshSession;
  if LImpl.FTransport = nil then
    raise ESSHError.Create(sekIO, 'proxy jump: jump transport nil');
  LChan := TSshChannel.Create(LImpl.FTransport, AInitialWindow, AMaxPacket, ATimeoutMs);
  try
    LChan.OpenDirectTcpip(AHost, APort);
    Result := TChannelStream.Create(LChan);
    LChan := nil;
  except
    LChan.Free;
    raise;
  end;
end;

end.
