unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * session/agent 仅依赖 ssh.intf，运行时注入此实现的 ISshDialer。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

implementation

uses
  nextpas.core.net;

function TSshDefaultDialer.Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
begin
  Result := TcpConnect(AHost, APort, ATimeoutMs);
end;

function TSshDefaultDialer.DialAgent(const APath: string): IReadWriteCloser; inline;
begin
  Result := UnixConnect(APath);
end;

function SshDefaultDialer: ISshDialer; inline;
begin
  Result := TSshDefaultDialer.Create;
end;

function SshDefaultAgentDialer: ISshAgentDialer; inline;
begin
  Result := TSshDefaultDialer.Create;
end;

end.
