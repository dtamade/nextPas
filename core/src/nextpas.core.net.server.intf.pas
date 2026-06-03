unit nextpas.core.net.server.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base;

type
  ITcpServerHandler = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000001}']
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
  end;

  ITcpServer = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000002}']
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

implementation

end.
