unit nextpas.core.net.async;
{**
 * @desc 异步网络子门面：聚合 async.tcp/udp/resolve/dial/cancel/pool/backpressure。
 *       由 nextpas.core.net 顶层门面 re-export，满足门面体积与聚合指引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.base,
  nextpas.core.net.intf,
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
