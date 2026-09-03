unit nextpas.core.ssh.net;

{** nextpas.core.ssh - 网络拨号桥接（唯一拉取 nextpas.core.net 的单元）。
 *
 *  原 nextpas.core.ssh.net.ffi 仅封装 TcpConnect/UnixConnect 的 Pascal 调用
 *  而无 cdecl external，与“FFI仅含 cdecl external”规范不符；已按四件套
 *  更名为本普通实现单元（非 FFI）。session/agent 仅依赖 ssh.intf，运行时
 *  注入此实现的 ISshDialer。
 *
 *  性能：SshDefaultDialer/SshDefaultAgentDialer 为 inline 薄转发，零额外调用；
 *  零拷贝：直接透传 ITcpStream/IReadWriteCloser 接口句柄，无中间 TBytes 缓冲拷贝；
 *  稳定性：接口引用计数自动释放，Dial 失败不持有半初始化句柄。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream;
    function DialAgent(const APath: string): IReadWriteCloser;
  end;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

implementation

uses
  nextpas.core.net;

function TSshDefaultDialer.Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream;
begin
  Result := TcpConnect(AHost, APort, ATimeoutMs);
end;

function TSshDefaultDialer.DialAgent(const APath: string): IReadWriteCloser;
begin
  Result := UnixConnect(APath);
end;

function SshDefaultDialer: ISshDialer;
begin
  Result := TSshDefaultDialer.Create;
end;

function SshDefaultAgentDialer: ISshAgentDialer;
begin
  Result := TSshDefaultDialer.Create;
end;

end.
