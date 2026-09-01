unit nextpas.core.ssh.proxyjump;

{** nextpas.core.ssh - 同步 ProxyJump（direct-tcpip 隧道）。
 *
 * 通过已认证跳板会话的 direct-tcpip 通道透明转发至目标主机，
 * 复用 TChannelStream 零拷贝双向流；TProxyJumpSession 持有
 * FJump+FTarget 双生命周期，Close 幂等双关。
 * 性能：零拷贝 TChannelStream.Move 直通，零额外分配于转发路径；
 * inline 委托（GetConnected/GetServerVersion 等）消除间接开销。
 * 稳定性：try-finally 保证 LChan.Free，失败不泄漏通道句柄。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.sftp.intf,
  nextpas.core.ssh.session;

type
  TProxyJumpSession = class(TInterfacedObject, ISshSession)
  private
    FJump: ISshSession;
    FTarget: ISshSession;
  public
    constructor Create(const AJump, ATarget: ISshSession);
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

function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession;
function SshConnectViaJumpOn(const AJumpSession: ISshSession;
  const ATargetOpts: TSshConnectOptions): ISshSession;

{ 内部缝隙：经跳板会话 opening direct-tcpip → IReadWriteCloser，供测试与
  FFI 层单源复用；对外仍通过上述两个公共函数进入。 }
function SshProxyJumpOpenStream(const AJumpSession: ISshSession;
  const ATargetOpts: TSshConnectOptions): IReadWriteCloser;

implementation

uses
  nextpas.core.ssh.errors,
  nextpas.core.ssh.transport;

{ TProxyJumpSession }

constructor TProxyJumpSession.Create(const AJump, ATarget: ISshSession);
begin
  inherited Create;
  FJump := AJump;
  FTarget := ATarget;
end;

destructor TProxyJumpSession.Destroy;
begin
  try
    if FTarget <> nil then FTarget.Close;
  except end;
  try
    if FJump <> nil then FJump.Close;
  except end;
  inherited;
end;

function TProxyJumpSession.GetConnected: Boolean; inline;
begin
  Result := (FTarget <> nil) and FTarget.GetConnected;
end;

function TProxyJumpSession.GetServerVersion: string; inline;
begin
  if FTarget <> nil then Result := FTarget.GetServerVersion else Result := '';
end;

function TProxyJumpSession.GetServerHostKeyFingerprint: string; inline;
begin
  if FTarget <> nil then Result := FTarget.GetServerHostKeyFingerprint else Result := '';
end;

procedure TProxyJumpSession.AuthenticateWithPassword(const AUser, APassword: string);
begin
  if FTarget <> nil then FTarget.AuthenticateWithPassword(AUser, APassword);
end;

procedure TProxyJumpSession.AuthenticateWithPrivateKeyData(const AContent: string);
begin
  if FTarget <> nil then FTarget.AuthenticateWithPrivateKeyData(AContent);
end;

procedure TProxyJumpSession.AuthenticateWithPrivateKeyData(const AContent, APassphrase: string);
begin
  if FTarget <> nil then FTarget.AuthenticateWithPrivateKeyData(AContent, APassphrase);
end;

procedure TProxyJumpSession.AuthenticateWithAgent(const APath: string);
begin
  if FTarget <> nil then FTarget.AuthenticateWithAgent(APath);
end;

procedure TProxyJumpSession.AuthenticateWithAgentOn(const AAgentIO: IReadWriteCloser);
begin
  if FTarget <> nil then FTarget.AuthenticateWithAgentOn(AAgentIO);
end;

function TProxyJumpSession.Exec(const ACommand: string): TSshExecResult;
begin
  if FTarget = nil then
    raise ESSHError.Create(sekIO, 'proxy jump: no target session');
  Result := FTarget.Exec(ACommand);
end;

function TProxyJumpSession.OpenFileSystem: ISshFileSystem;
begin
  if FTarget = nil then
    raise ESSHError.Create(sekIO, 'proxy jump: no target session');
  Result := FTarget.OpenFileSystem;
end;

function TProxyJumpSession.ShouldRekey: Boolean; inline;
begin
  if FTarget <> nil then Result := FTarget.ShouldRekey else Result := False;
end;

function TProxyJumpSession.Rekey: Boolean; inline;
begin
  if FTarget <> nil then Result := FTarget.Rekey else Result := False;
end;

function TProxyJumpSession.SendKeepAlive(const AData: TBytes): Boolean; inline;
begin
  if FTarget <> nil then Result := FTarget.SendKeepAlive(AData) else Result := False;
end;

function TProxyJumpSession.SendKeepAlive: Boolean; inline;
begin
  Result := SendKeepAlive(nil);
end;

procedure TProxyJumpSession.Close;
begin
  if FTarget <> nil then try FTarget.Close; except end;
  if FJump <> nil then try FJump.Close; except end;
end;

function SshProxyJumpOpenStream(const AJumpSession: ISshSession;
  const ATargetOpts: TSshConnectOptions): IReadWriteCloser;
var
  LJump: ISshSession;
begin
  { 链式 ProxyJump 透传：逐层解包 FTarget 直至底层 TSshSession，避免嵌套丢失 }
  LJump := AJumpSession;
  Result := SshSessionOpenDirectTcpip(LJump, ATargetOpts.Host,
    ATargetOpts.Port, ATargetOpts.InitialWindowSize, ATargetOpts.MaxPacket,
    ATargetOpts.ExecTimeoutMs);
  if Result = nil then
    raise ESSHError.Create(sekIO, 'proxy jump: failed to open direct-tcpip stream');
end;

function SshConnectViaJumpOn(const AJumpSession: ISshSession;
  const ATargetOpts: TSshConnectOptions): ISshSession;
var
  LStream: IReadWriteCloser;
  LTarget: ISshSession;
begin
  if AJumpSession = nil then
    raise ESSHError.Create(sekProtocol, 'proxy jump: nil jump session');
  LStream := SshProxyJumpOpenStream(AJumpSession, ATargetOpts);
  try
    LTarget := SshConnectOn(LStream, ATargetOpts);
    Result := TProxyJumpSession.Create(AJumpSession, LTarget);
    LStream := nil;
  except
    if LStream <> nil then try LStream.Close; except end;
    raise;
  end;
end;

function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession;
var
  LJump: ISshSession;
begin
  LJump := SshConnect(AJumpOpts);
  try
    Result := SshConnectViaJumpOn(LJump, ATargetOpts);
  except
    LJump.Close;
    raise;
  end;
end;

end.
