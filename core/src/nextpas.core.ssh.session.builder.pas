unit nextpas.core.ssh.session.builder;

{** nextpas.core.ssh - Fluent 客户端构造器（会话参数 → 拨号认证）。
 *
 * 薄包装 nextpas.core.ssh.session 的 SshConnect，实现 ISshClientBuilder
 * 链式 API。单职责：参数收集 + 校验 + 委托握手/认证。
 * 零拷贝：FOptions 记录值语义，Host/User 等为 string 托管，Connect 直通
 * session.SshConnect 无额外分配；方法均 inline 薄转发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.session;

type
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
    function RekeyBytes(AValue: UInt64): ISshClientBuilder;
    function RekeyIntervalMs(AValue: Integer): ISshClientBuilder;
    function KeepAliveIntervalMs(AValue: Integer): ISshClientBuilder;
    function Connect: ISshSession;
  end;

function SshClient: ISshClientBuilder;

implementation

uses
  nextpas.core.ssh.session;

type
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
    function RekeyBytes(AValue: UInt64): ISshClientBuilder;
    function RekeyIntervalMs(AValue: Integer): ISshClientBuilder;
    function KeepAliveIntervalMs(AValue: Integer): ISshClientBuilder;
    function Connect: ISshSession;
  end;

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

function TSshClientBuilder.RekeyBytes(AValue: UInt64): ISshClientBuilder;
begin
  FOptions.RekeyBytes := AValue;
  Result := Self;
end;

function TSshClientBuilder.RekeyIntervalMs(AValue: Integer): ISshClientBuilder;
begin
  FOptions.RekeyIntervalMs := AValue;
  Result := Self;
end;

function TSshClientBuilder.KeepAliveIntervalMs(AValue: Integer): ISshClientBuilder;
begin
  FOptions.KeepAliveIntervalMs := AValue;
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

function SshClient: ISshClientBuilder;
begin
  Result := TSshClientBuilder.Create;
end;

end.
