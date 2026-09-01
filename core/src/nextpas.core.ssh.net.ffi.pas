unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * 同步经 ISshDialer/ISshAgentDialer，异步经 IAsyncTcpStream re-export + inline 转发；
 * session/agent/transport.async 仅依赖 ssh.intf/net.ffi 缝隙，零直连 net。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.loop,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

  // async 单缝隙 re-export：net.async.tcp/dial 唯一拉取点收口于此 ffi，零额外抽象 inline 零拷贝转发
  IAsyncTcpStream = nextpas.core.net.async.tcp.IAsyncTcpStream;
  IAsyncTcpListener = nextpas.core.net.async.tcp.IAsyncTcpListener;
  TAsyncTcpDialOptions = nextpas.core.net.async.dial.TAsyncTcpDialOptions;
  TAsyncTcpDialCallback = nextpas.core.net.async.dial.TAsyncTcpDialCallback;
  // 同步类型单缝隙 re-export：供 proxyjump.async 等经 ffi 间接使用，避免直连 net.base/intf
  ITcpStream = nextpas.core.net.intf.ITcpStream;
  ITcpListener = nextpas.core.net.intf.ITcpListener;
  IUdpSocket = nextpas.core.net.intf.IUdpSocket;
  TNetAddress = nextpas.core.net.base.TNetAddress;
  TTcpStreamIOResult = nextpas.core.net.intf.TTcpStreamIOResult;
  INetCancelToken = nextpas.core.net.intf.INetCancelToken;

const
  tsiorOk = nextpas.core.net.intf.tsiorOk;
  tsiorWouldBlock = nextpas.core.net.intf.tsiorWouldBlock;
  tsiorClosed = nextpas.core.net.intf.tsiorClosed;
  tsiorTimeout = nextpas.core.net.intf.tsiorTimeout;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;
function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
function SshDefaultAsyncTcpDialOptions: TAsyncTcpDialOptions; inline;
function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16; const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer = nil): Boolean; inline;

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

function SshDefaultAsyncTcpDialOptions: TAsyncTcpDialOptions; inline;
begin
  Result := nextpas.core.net.async.dial.DefaultAsyncTcpDialOptions;
end;

function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16; const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer): Boolean; inline;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDial(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

end.
