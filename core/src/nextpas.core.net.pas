unit nextpas.core.net;
{**
 * @desc TCP/UDP 网络顶层门面。聚合 sync/async 子门面，消费方只需 uses nextpas.core.net。
 *       拆分子门面后顶层仅 re-export + inline 转发，满足门面体积与单源聚合约束。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.net.base,
  nextpas.core.net.sync,
  nextpas.core.net.async,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

type
  TNetAddress = nextpas.core.net.sync.TNetAddress;
  TNetErrorKind = nextpas.core.net.sync.TNetErrorKind;
  TNetErrorClass = nextpas.core.net.sync.TNetErrorClass;
  TTcpStreamIOResult = nextpas.core.net.sync.TTcpStreamIOResult;
  TTcpAcceptResult = nextpas.core.net.sync.TTcpAcceptResult;
  INetCancelToken = nextpas.core.net.sync.INetCancelToken;
  INetCancelController = nextpas.core.net.sync.INetCancelController;
  INetCancelWaitable = nextpas.core.net.sync.INetCancelWaitable;
  ITcpSocketRuntime = nextpas.core.net.sync.ITcpSocketRuntime;
  ITcpStreamRuntime = nextpas.core.net.sync.ITcpStreamRuntime;
  ITcpListenerRuntime = nextpas.core.net.sync.ITcpListenerRuntime;
  ITcpStream = nextpas.core.net.sync.ITcpStream;
  ITcpListener = nextpas.core.net.sync.ITcpListener;
  IUdpSocket = nextpas.core.net.sync.IUdpSocket;
  IAsyncTcpStream = nextpas.core.net.async.IAsyncTcpStream;
  IAsyncTcpListener = nextpas.core.net.async.IAsyncTcpListener;
  IAsyncUdpSocket = nextpas.core.net.async.IAsyncUdpSocket;
  TAsyncUdpRecvCallback = nextpas.core.net.async.TAsyncUdpRecvCallback;
  TAsyncUdpSendCallback = nextpas.core.net.async.TAsyncUdpSendCallback;
  TAsyncTcpDialOptions = nextpas.core.net.async.TAsyncTcpDialOptions;
  TAsyncTcpDialCallback = nextpas.core.net.async.TAsyncTcpDialCallback;
  TAsyncTcpDialAddressFamily = nextpas.core.net.async.TAsyncTcpDialAddressFamily;
  TAsyncTcpDialControl = nextpas.core.net.async.TAsyncTcpDialControl;
  TAsyncTcpDialResolve = nextpas.core.net.async.TAsyncTcpDialResolve;
  TAsyncTcpDialAttemptStart = nextpas.core.net.async.TAsyncTcpDialAttemptStart;
  TAsyncTcpDialAttemptResult = nextpas.core.net.async.TAsyncTcpDialAttemptResult;
  IAsyncTcpDialDnsFeed = nextpas.core.net.async.IAsyncTcpDialDnsFeed;
  TDnsResult = nextpas.core.net.async.TDnsResult;
  TDnsCallback = nextpas.core.net.async.TDnsCallback;
  TDnsCallbackRef = nextpas.core.net.async.TDnsCallbackRef;
  TBackpressureState = nextpas.core.net.async.TBackpressureState;
  TBackpressureConfig = nextpas.core.net.async.TBackpressureConfig;
  TBackpressureCallback = nextpas.core.net.async.TBackpressureCallback;
  IBackpressureController = nextpas.core.net.async.IBackpressureController;
  TConnectionPoolConfig = nextpas.core.net.async.TConnectionPoolConfig;
  TAcquireAsyncCallback = nextpas.core.net.async.TAcquireAsyncCallback;
  IConnectionPool = nextpas.core.net.async.IConnectionPool;

const
  tarAccepted = nextpas.core.net.sync.tarAccepted;
  tarWouldBlock = nextpas.core.net.sync.tarWouldBlock;
  tarTimeout = nextpas.core.net.sync.tarTimeout;

function TcpListen(const AAddr: string; const APort: UInt16;
  const ABacklog: Int32 = nextpas.core.net.base.NET_DEFAULT_BACKLOG): ITcpListener; inline;
function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream; inline;
function UnixListen(const APath: string): ITcpListener; inline;
function UnixConnect(const APath: string): ITcpStream; inline;
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

function AsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
function AsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;

function ClassifyNetError(ACode: Int32): TNetErrorClass; inline;
function NetErrorKindName(AKind: TNetErrorKind): string; inline;

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
  Result := nextpas.core.net.sync.TcpListen(AAddr, APort, ABacklog);
end;

function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
begin
  Result := nextpas.core.net.sync.TcpConnect(AAddr, APort);
end;

function UnixListen(const APath: string): ITcpListener;
begin
  Result := nextpas.core.net.sync.UnixListen(APath);
end;

function UnixConnect(const APath: string): ITcpStream;
begin
  Result := nextpas.core.net.sync.UnixConnect(APath);
end;

function TcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream;
begin
  Result := nextpas.core.net.sync.TcpConnect(AAddr, APort, ATimeoutMs);
end;

function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
begin
  Result := nextpas.core.net.sync.UdpBind(AAddr, APort);
end;

function Resolve(const AHost: string): TNetAddress;
begin
  Result := nextpas.core.net.sync.Resolve(AHost);
end;

function StripHostBrackets(const AHost: string): string;
begin
  Result := nextpas.core.net.sync.StripHostBrackets(AHost);
end;

function TryParseIPv4(const AIP: string; out ANet: UInt32): Boolean;
begin
  Result := nextpas.core.net.sync.TryParseIPv4(AIP, ANet);
end;

function TryParseIPv4(const AIP: string; out AOctets: TBytes): Boolean;
begin
  Result := nextpas.core.net.sync.TryParseIPv4(AIP, AOctets);
end;

function TryParseIPv6(const AIP: string; out AOctets: TBytes): Boolean;
begin
  Result := nextpas.core.net.sync.TryParseIPv6(AIP, AOctets);
end;

function TryParseIPv6(const AIP: string; AAddr: PByte): Boolean;
begin
  Result := nextpas.core.net.sync.TryParseIPv6(AIP, AAddr);
end;

function IsIPv4Literal(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.sync.IsIPv4Literal(AHost);
end;

function IsIPv6Literal(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.sync.IsIPv6Literal(AHost);
end;

function HostIsIpLiteral(const AHost: string): Boolean;
begin
  Result := nextpas.core.net.sync.HostIsIpLiteral(AHost);
end;

function FormatIPv4(ANet: UInt32): string;
begin
  Result := nextpas.core.net.sync.FormatIPv4(ANet);
end;

function FormatIPv6(AAddr: PByte): string;
begin
  Result := nextpas.core.net.sync.FormatIPv6(AAddr);
end;

function SplitHostPort(const AText: string; ADefaultPort: UInt16;
  out AHost: string; out APort: UInt16): Boolean;
begin
  Result := nextpas.core.net.sync.SplitHostPort(AText, ADefaultPort, AHost, APort);
end;

function SplitHostPort(const AText: string; out AHost: string;
  out APort: UInt16): Boolean;
begin
  Result := nextpas.core.net.sync.SplitHostPort(AText, AHost, APort);
end;

function JoinHostPort(const AHost: string; APort: UInt16): string;
begin
  Result := nextpas.core.net.sync.JoinHostPort(AHost, APort);
end;

function NewNetCancelToken: INetCancelController;
begin
  Result := nextpas.core.net.sync.NewNetCancelToken;
end;

function CreateBackpressureController(
  const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController;
begin
  Result := nextpas.core.net.async.CreateBackpressureController(ALoop, AConfig);
end;

function CreateBackpressureController(
  const ALoop: TAsyncLoop): IBackpressureController;
begin
  Result := nextpas.core.net.async.CreateBackpressureController(ALoop);
end;

function DefaultAsyncTcpDialOptions: TAsyncTcpDialOptions;
begin
  Result := nextpas.core.net.async.DefaultAsyncTcpDialOptions;
end;

function AsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.AsyncTcpDial(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

function AsyncTcpDialAddrs(const ALoop: TAsyncLoop;
  const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer): Boolean;
begin
  Result := nextpas.core.net.async.AsyncTcpDialAddrs(ALoop, AAddrs, APort, AOptions, ACallback, AContext);
end;

function AsyncTcpDialWithDnsFeed(const ALoop: TAsyncLoop; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback;
  AContext: Pointer; out AFeed: IAsyncTcpDialDnsFeed): Boolean;
begin
  Result := nextpas.core.net.async.AsyncTcpDialWithDnsFeed(ALoop, APort, AOptions, ACallback, AContext, AFeed);
end;

function AsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream;
begin
  Result := nextpas.core.net.async.AsyncTcpStreamAdopt(ALoop, AStream);
end;

function AsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream;
begin
  Result := nextpas.core.net.async.AsyncTcpConnect(ALoop, AAddr, APort);
end;

function ClassifyNetError(ACode: Int32): TNetErrorClass;
begin
  Result := nextpas.core.net.sync.ClassifyNetError(ACode);
end;

function NetErrorKindName(AKind: TNetErrorKind): string;
begin
  Result := nextpas.core.net.sync.NetErrorKindName(AKind);
end;

function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;
begin
  Result := nextpas.core.net.async.NetCancelFromAsync(AAsync);
end;

procedure TcpStreamBindAsyncCancel(const AStream: ITcpStream;
  const AToken: IAsyncCancellationToken);
begin
  nextpas.core.net.async.TcpStreamBindAsyncCancel(AStream, AToken);
end;

function AsyncUdpBind(const ALoop: TAsyncLoop; const AAddr: string;
  APort: UInt16): IAsyncUdpSocket;
begin
  Result := nextpas.core.net.async.AsyncUdpBind(ALoop, AAddr, APort);
end;

function CreateConnectionPool(
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := nextpas.core.net.async.CreateConnectionPool(AConfig);
end;

function CreateConnectionPool: IConnectionPool;
begin
  Result := nextpas.core.net.async.CreateConnectionPool;
end;

function CreateConnectionPool(const ALoop: TAsyncLoop;
  const AConfig: TConnectionPoolConfig): IConnectionPool;
begin
  Result := nextpas.core.net.async.CreateConnectionPool(ALoop, AConfig);
end;

function CreateConnectionPool(const ALoop: TAsyncLoop): IConnectionPool;
begin
  Result := nextpas.core.net.async.CreateConnectionPool(ALoop);
end;

end.
