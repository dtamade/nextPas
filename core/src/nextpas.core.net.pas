unit nextpas.core.net;
{**
 * @desc TCP/UDP 网络模块门面。提供 TCP 监听/连接、UDP 绑定、DNS 解析。
 *       消费方只需 uses nextpas.core.net 即可获得完整网络能力。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.base,
  nextpas.core.net.errors,
  nextpas.core.net.intf,
  nextpas.core.net.cancel,
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.udp,
  nextpas.core.net.async.resolve,
  nextpas.core.net.async.dial,
  nextpas.core.net.async.cancel,
  nextpas.core.net.async.pool,
  nextpas.core.net.async.backpressure,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

type
  TNetAddress = nextpas.core.net.base.TNetAddress;
  TNetErrorKind = nextpas.core.net.errors.TNetErrorKind;
  TNetErrorClass = nextpas.core.net.errors.TNetErrorClass;
  TTcpStreamIOResult = nextpas.core.net.intf.TTcpStreamIOResult;
  TTcpAcceptResult = nextpas.core.net.intf.TTcpAcceptResult;
  INetCancelToken = nextpas.core.net.intf.INetCancelToken;
  INetCancelController = nextpas.core.net.intf.INetCancelController;
  INetCancelWaitable = nextpas.core.net.intf.INetCancelWaitable;
  ITcpSocketRuntime = nextpas.core.net.intf.ITcpSocketRuntime;
  ITcpStreamRuntime = nextpas.core.net.intf.ITcpStreamRuntime;
  ITcpListenerRuntime = nextpas.core.net.intf.ITcpListenerRuntime;
  ITcpStream = nextpas.core.net.intf.ITcpStream;
  ITcpListener = nextpas.core.net.intf.ITcpListener;
  IUdpSocket = nextpas.core.net.intf.IUdpSocket;
  IAsyncTcpStream = nextpas.core.net.async.tcp.IAsyncTcpStream;
  IAsyncTcpListener = nextpas.core.net.async.tcp.IAsyncTcpListener;
  IAsyncUdpSocket = nextpas.core.net.async.udp.IAsyncUdpSocket;
  TAsyncUdpRecvCallback = nextpas.core.net.async.udp.TAsyncUdpRecvCallback;
  TAsyncUdpSendCallback = nextpas.core.net.async.udp.TAsyncUdpSendCallback;
  TAsyncTcpDialOptions = nextpas.core.net.async.dial.TAsyncTcpDialOptions;
  TAsyncTcpDialCallback = nextpas.core.net.async.dial.TAsyncTcpDialCallback;
  TAsyncTcpDialAddressFamily = nextpas.core.net.async.dial.TAsyncTcpDialAddressFamily;
  TAsyncTcpDialControl = nextpas.core.net.async.dial.TAsyncTcpDialControl;
  TAsyncTcpDialResolve = nextpas.core.net.async.dial.TAsyncTcpDialResolve;
  TAsyncTcpDialAttemptStart = nextpas.core.net.async.dial.TAsyncTcpDialAttemptStart;
  TAsyncTcpDialAttemptResult = nextpas.core.net.async.dial.TAsyncTcpDialAttemptResult;
  IAsyncTcpDialDnsFeed = nextpas.core.net.async.dial.IAsyncTcpDialDnsFeed;
  TDnsResult = nextpas.core.net.async.resolve.TDnsResult;
  TDnsCallback = nextpas.core.net.async.resolve.TDnsCallback;
  TDnsCallbackRef = nextpas.core.net.async.resolve.TDnsCallbackRef;
  TBackpressureState = nextpas.core.net.async.backpressure.TBackpressureState;
  TBackpressureConfig = nextpas.core.net.async.backpressure.TBackpressureConfig;
  TBackpressureCallback = nextpas.core.net.async.backpressure.TBackpressureCallback;
  IBackpressureController = nextpas.core.net.async.backpressure.IBackpressureController;
  TConnectionPoolConfig = nextpas.core.net.async.pool.TConnectionPoolConfig;
  TAcquireAsyncCallback = nextpas.core.net.async.pool.TAcquireAsyncCallback;
  IConnectionPool = nextpas.core.net.async.pool.IConnectionPool;

const
  { TTcpAcceptResult 枚举值 alias（facade 完整性：调用方 switch 需引用值）}
  tarAccepted = nextpas.core.net.intf.tarAccepted;
  tarWouldBlock = nextpas.core.net.intf.tarWouldBlock;
  tarTimeout = nextpas.core.net.intf.tarTimeout;

function TcpListen(const AAddr: string; const APort: UInt16;
  const ABacklog: Int32 = nextpas.core.net.base.NET_DEFAULT_BACKLOG): ITcpListener; inline;
function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream; inline;
{ AF_UNIX 域 socket 监听/连接（Unix 平台；Windows 抛 ENetworkError unsupported）。
  UnixListen 创建 0600 权限 socket 文件（bind 前 unlink 旧文件）。 }
function UnixListen(const APath: string): ITcpListener; inline;
function UnixConnect(const APath: string): ITcpStream; inline;
{ ATimeoutMs > 0 bounds OS connect(); <= 0 is unbounded blocking connect. }
function TcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream; inline;
function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket; inline;
function Resolve(const AHost: string): TNetAddress; inline;
function StripHostBrackets(const AHost: string): string; inline;
function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean; overload; inline;
function TryParseIPv4(const AIP: string; out AOctets: TBytes): Boolean; overload; inline;
function TryParseIPv6(const AIP: string; out AOctets: TBytes): Boolean; overload; inline;
function TryParseIPv6(const AIP: string; AAddr: PByte): Boolean; overload; inline;
function IsIPv4Literal(const AHost: string): Boolean; inline;
function IsIPv6Literal(const AHost: string): Boolean; inline;
function HostIsIpLiteral(const AHost: string): Boolean; inline;
function FormatIPv4(ANet: UInt32): string; inline;
function FormatIPv6(AAddr: PByte): string; inline;
function SplitHostPort(const AText: string; ADefaultPort: UInt16;
  out AHost: string; out APort: UInt16): Boolean; inline;
function SplitHostPort(const AText: string; out AHost: string;
  out APort: UInt16): Boolean; inline;
function JoinHostPort(const AHost: string; APort: UInt16): string; inline;
function NewNetCancelToken: INetCancelController; inline;

function CreateBackpressureController(
  const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController; overload; inline;
function CreateBackpressureController(
  const ALoop: TAsyncLoop): IBackpressureController; overload; inline;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions; inline;
function AsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer = nil): Boolean; inline;
function AsyncTcpDialAddrs(const ALoop: TAsyncLoop;
  const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer = nil): Boolean; inline;
function AsyncTcpDialWithDnsFeed(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer; out AFeed: IAsyncTcpDialDnsFeed): Boolean; inline;

{ Go-like error classification for dial/IO result codes (negative or positive). }
function ClassifyNetError(ACode: Int32): TNetErrorClass; inline;
function NetErrorKindName(AKind: TNetErrorKind): string; inline;

{ Q14: async cancel → waitable net cancel (blocking IO). }
function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController; inline;
procedure TcpStreamBindAsyncCancel(const AStream: ITcpStream;
  const AToken: IAsyncCancellationToken); inline;

function AsyncUdpBind(const ALoop: TAsyncLoop; const AAddr: string;
  APort: UInt16): IAsyncUdpSocket; inline;

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool; overload; inline;
function CreateConnectionPool: IConnectionPool; overload; inline;
function CreateConnectionPool(const ALoop: TAsyncLoop;
  const AConfig: TConnectionPoolConfig): IConnectionPool; overload; inline;
function CreateConnectionPool(const ALoop: TAsyncLoop): IConnectionPool;
  overload; inline;

implementation

function TcpListen(const AAddr: string; const APort: UInt16;
  const ABacklog: Int32): ITcpListener;
begin
  Result := nextpas.core.net.tcp.NetTcpListen(AAddr, APort, ABacklog);
end;

function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
begin
  Result := nextpas.core.net.tcp.NetTcpConnect(AAddr, APort);
end;

function UnixListen(const APath: string): ITcpListener;
begin
  Result := nextpas.core.net.tcp.NetUnixListen(APath);
end;

function UnixConnect(const APath: string): ITcpStream;
begin
  Result := nextpas.core.net.tcp.NetUnixConnect(APath);
end;

function TcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream;
begin
  Result := nextpas.core.net.tcp.NetTcpConnect(AAddr, APort, ATimeoutMs);
end;

function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
begin
  Result := nextpas.core.net.udp.NetUdpBind(AAddr, APort);
end;

function Resolve(const AHost: string): TNetAddress;
begin
  Result := nextpas.core.net.resolve.NetResolve(AHost);
end;

function StripHostBrackets(const AHost: string): string;
begin
  Result := nextpas.core.net.resolve.StripHostBrackets(AHost);
end;

function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv4(AIP, ANet);
end;

function TryParseIPv4(const AIP: string; out AOctets: TBytes): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv4(AIP, AOctets);
end;

function TryParseIPv6(const AIP: string; out AOctets: TBytes): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv6(AIP, AOctets);
end;

function TryParseIPv6(const AIP: string; AAddr: PByte): Boolean;
begin
  Result := nextpas.core.net.resolve.TryParseIPv6(AIP, AAddr);
end;

function IsIPv4Literal(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.resolve.IsIPv4Literal(AHost);
end;

function IsIPv6Literal(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.resolve.IsIPv6Literal(AHost);
end;

function HostIsIpLiteral(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.resolve.HostIsIpLiteral(AHost);
end;

function FormatIPv4(ANet: UInt32): string;
begin
  Result := nextpas.core.net.resolve.FormatIPv4(ANet);
end;

function FormatIPv6(AAddr: PByte): string;
begin
  Result := nextpas.core.net.resolve.FormatIPv6(AAddr);
end;

function SplitHostPort(const AText: string; ADefaultPort: UInt16;
  out AHost: string; out APort: UInt16): Boolean;
begin
  Result := nextpas.core.net.resolve.SplitHostPort(AText, ADefaultPort, AHost, APort);
end;

function SplitHostPort(const AText: string; out AHost: string;
  out APort: UInt16): Boolean;
begin
  Result := nextpas.core.net.resolve.SplitHostPort(AText, AHost, APort);
end;

function JoinHostPort(const AHost: string; APort: UInt16): string;
begin
  Result := nextpas.core.net.resolve.JoinHostPort(AHost, APort);
end;

function NewNetCancelToken: INetCancelController;
begin
  Result := nextpas.core.net.cancel.NewNetCancelToken;
end;

function CreateBackpressureController(
  const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController;
begin
  Result := nextpas.core.net.async.backpressure.CreateBackpressureController(
    ALoop, AConfig);
end;

function CreateBackpressureController(
  const ALoop: TAsyncLoop): IBackpressureController;
begin
  Result := nextpas.core.net.async.backpressure.CreateBackpressureController(ALoop);
end;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions;
begin
  Result := nextpas.core.net.async.dial.DefaultAsyncTcpDialOptions;
end;

function AsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDial(ALoop, AHost, APort,
    AOptions, ACallback, AContext);
end;

function AsyncTcpDialAddrs(const ALoop: TAsyncLoop;
  const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDialAddrs(ALoop, AAddrs, APort,
    AOptions, ACallback, AContext);
end;

function AsyncTcpDialWithDnsFeed(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer; out AFeed: IAsyncTcpDialDnsFeed): Boolean;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDialWithDnsFeed(ALoop, APort,
    AOptions, ACallback, AContext, AFeed);
end;

function ClassifyNetError(ACode: Int32): TNetErrorClass;
begin
  Result := nextpas.core.net.errors.ClassifyNetError(ACode);
end;

function NetErrorKindName(AKind: TNetErrorKind): string;
begin
  Result := nextpas.core.net.errors.NetErrorKindName(AKind);
end;

function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;
begin
  Result := nextpas.core.net.async.cancel.NetCancelFromAsync(AAsync);
end;

procedure TcpStreamBindAsyncCancel(const AStream: ITcpStream;
  const AToken: IAsyncCancellationToken);
begin
  nextpas.core.net.async.cancel.TcpStreamBindAsyncCancel(AStream, AToken);
end;

function AsyncUdpBind(const ALoop: TAsyncLoop; const AAddr: string;
  APort: UInt16): IAsyncUdpSocket;
begin
  Result := nextpas.core.net.async.udp.AsyncUdpBind(ALoop, AAddr, APort);
end;

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := nextpas.core.net.async.pool.CreateConnectionPool(AConfig);
end;

function CreateConnectionPool: IConnectionPool;
begin
  Result := nextpas.core.net.async.pool.CreateConnectionPool;
end;

function CreateConnectionPool(const ALoop: TAsyncLoop;
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := nextpas.core.net.async.pool.CreateConnectionPool(ALoop, AConfig);
end;

function CreateConnectionPool(const ALoop: TAsyncLoop): IConnectionPool;
begin
  Result := nextpas.core.net.async.pool.CreateConnectionPool(ALoop);
end;

end.
