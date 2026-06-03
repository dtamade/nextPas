unit nextpas.core.net.server.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base;

type
  ITcpServerWork = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000005}']
    function Execute: TTcpServerConnOwnership;
  end;

  ITcpServerWorkCompletion = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000006}']
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  ITcpServerWorkerHandoff = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000007}']
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  ITcpServerSessionContext = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000008}']
    function WorkerHandoff: ITcpServerWorkerHandoff;
  end;

  ITcpServerSession = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000003}']
    function Run: TTcpServerConnOwnership;
  end;

  ITcpServerSessionFactory = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000004}']
    function NewSession(const AConn: ITcpStream): ITcpServerSession;
  end;

  ITcpServerSessionFactoryWithContext = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000009}']
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;

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
