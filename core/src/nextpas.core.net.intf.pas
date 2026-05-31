unit nextpas.core.net.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.time.deadline,
  nextpas.core.net.base;

type
  ITcpStream = interface(IStream)
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000001}']
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
  end;

  ITcpListener = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000002}']
    function Accept: ITcpStream;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

  IUdpSocket = interface
    ['{C1D2E3F4-A5B6-7890-ABCD-300000000003}']
    function SendTo(const ABuf; const ACount: SizeUInt;
      const AAddr: TNetAddress): SizeUInt;
    function RecvFrom(var ABuf; const ACount: SizeUInt;
      out AAddr: TNetAddress): SizeUInt;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

implementation

end.
