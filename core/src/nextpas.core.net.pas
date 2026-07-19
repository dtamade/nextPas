unit nextpas.core.net;
{**
 * @desc TCP/UDP 网络模块门面。提供 TCP 监听/连接、UDP 绑定、DNS 解析。
 *       消费方只需 uses nextpas.core.net 即可获得完整网络能力。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.cancel,
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.resolve,
  nextpas.core.net.async.backpressure,
  nextpas.core.async.loop;

type
  TNetAddress = nextpas.core.net.base.TNetAddress;
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
  TDnsResult = nextpas.core.net.async.resolve.TDnsResult;
  TDnsCallback = nextpas.core.net.async.resolve.TDnsCallback;
  TDnsCallbackRef = nextpas.core.net.async.resolve.TDnsCallbackRef;
  TBackpressureState = nextpas.core.net.async.backpressure.TBackpressureState;
  TBackpressureConfig = nextpas.core.net.async.backpressure.TBackpressureConfig;
  TBackpressureCallback = nextpas.core.net.async.backpressure.TBackpressureCallback;
  IBackpressureController = nextpas.core.net.async.backpressure.IBackpressureController;

function TcpListen(const AAddr: string; const APort: UInt16): ITcpListener; inline;
function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream; inline;
{ ATimeoutMs > 0 bounds OS connect(); <= 0 is unbounded blocking connect. }
function TcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream; inline;
function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket; inline;
function Resolve(const AHost: string): TNetAddress; inline;
function NewNetCancelToken: INetCancelController; inline;

function CreateBackpressureController(
  const ALoop: TAsyncLoop;
  const AConfig: TBackpressureConfig): IBackpressureController; overload; inline;
function CreateBackpressureController(
  const ALoop: TAsyncLoop): IBackpressureController; overload; inline;

implementation

function TcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
begin
  Result := nextpas.core.net.tcp.NetTcpListen(AAddr, APort);
end;

function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
begin
  Result := nextpas.core.net.tcp.NetTcpConnect(AAddr, APort);
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

end.
