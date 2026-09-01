unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * 同步经 ISshDialer/ISshAgentDialer，异步经 IAsyncTcpStream re-export + inline 转发；
 * session/agent/transport.async 仅依赖 ssh.intf/net.ffi 缝隙，零直连 net。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.async.loop,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

  // async 单缝隙 re-export：net.async.tcp 唯一拉取点收口于此 ffi，零额外抽象
  IAsyncTcpStream = nextpas.core.net.async.tcp.IAsyncTcpStream;
  IAsyncTcpListener = nextpas.core.net.async.tcp.IAsyncTcpListener;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;
function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;

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

function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
begin
  Result := nextpas.core.net.async.tcp.AsyncTcpStreamAdopt(ALoop, AStream);
end;

function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
begin
  Result := nextpas.core.net.async.tcp.AsyncTcpConnect(ALoop, AAddr, APort);
end;

end.
