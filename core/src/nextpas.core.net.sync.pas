unit nextpas.core.net.sync;
{**
 * @desc 同步网络子门面：聚合 tcp/udp/resolve/cancel 基础能力。
 *       由 nextpas.core.net 顶层门面 re-export，满足四件套聚合与门面体积指引。
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
  nextpas.core.net.resolve;

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

const
  tarAccepted = nextpas.core.net.intf.tarAccepted;
  tarWouldBlock = nextpas.core.net.intf.tarWouldBlock;
  tarTimeout = nextpas.core.net.intf.tarTimeout;

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
function ClassifyNetError(ACode: Int32): TNetErrorClass; inline;
function NetErrorKindName(AKind: TNetErrorKind): string; inline;

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

function ClassifyNetError(ACode: Int32): TNetErrorClass;
begin
  Result := nextpas.core.net.errors.ClassifyNetError(ACode);
end;

function NetErrorKindName(AKind: TNetErrorKind): string;
begin
  Result := nextpas.core.net.errors.NetErrorKindName(AKind);
end;

end.
