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
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve;

type
  TNetAddress = nextpas.core.net.base.TNetAddress;
  TTcpStreamIOResult = nextpas.core.net.intf.TTcpStreamIOResult;
  TTcpAcceptResult = nextpas.core.net.intf.TTcpAcceptResult;
  ITcpSocketRuntime = nextpas.core.net.intf.ITcpSocketRuntime;
  ITcpStreamRuntime = nextpas.core.net.intf.ITcpStreamRuntime;
  ITcpListenerRuntime = nextpas.core.net.intf.ITcpListenerRuntime;
  ITcpStream = nextpas.core.net.intf.ITcpStream;
  ITcpListener = nextpas.core.net.intf.ITcpListener;
  IUdpSocket = nextpas.core.net.intf.IUdpSocket;

function TcpListen(const AAddr: string; const APort: UInt16): ITcpListener; inline;
function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream; inline;
function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket; inline;
function Resolve(const AHost: string): TNetAddress; inline;

implementation

function TcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
begin
  Result := nextpas.core.net.tcp.NetTcpListen(AAddr, APort);
end;

function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
begin
  Result := nextpas.core.net.tcp.NetTcpConnect(AAddr, APort);
end;

function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
begin
  Result := nextpas.core.net.udp.NetUdpBind(AAddr, APort);
end;

function Resolve(const AHost: string): TNetAddress;
begin
  Result := nextpas.core.net.resolve.NetResolve(AHost);
end;

end.
