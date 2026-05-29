unit nextpas.core.net;

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
