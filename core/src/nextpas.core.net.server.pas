unit nextpas.core.net.server;
{**
 * @desc TCP server foundation facade.
 *       Exposes reusable server runtime contracts so protocol modules can
 *       consume a shared listener/accept/runtime ownership model.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.runtime,
  {$IFDEF NEXTPAS_LINUX}
  nextpas.core.net.server.epoll,
  {$ENDIF}
  nextpas.core.net.server.threaded;

type
  TTcpServerBackend = nextpas.core.net.server.base.TTcpServerBackend;
  TTcpServerConnOwnership = nextpas.core.net.server.base.TTcpServerConnOwnership;
  TTcpServerHandoffResult = nextpas.core.net.server.base.TTcpServerHandoffResult;
  TTcpServerWorkOutcome = nextpas.core.net.server.base.TTcpServerWorkOutcome;
  TTcpServerOptions = nextpas.core.net.server.base.TTcpServerOptions;
  ITcpServerWork = nextpas.core.net.server.intf.ITcpServerWork;
  ITcpServerWorkCompletion = nextpas.core.net.server.intf.ITcpServerWorkCompletion;
  ITcpServerWorkerHandoff = nextpas.core.net.server.intf.ITcpServerWorkerHandoff;
  ITcpServerSessionContext = nextpas.core.net.server.intf.ITcpServerSessionContext;
  ITcpServerSession = nextpas.core.net.server.intf.ITcpServerSession;
  ITcpServerSessionFactory = nextpas.core.net.server.intf.ITcpServerSessionFactory;
  ITcpServerSessionFactoryWithContext = nextpas.core.net.server.intf.ITcpServerSessionFactoryWithContext;
  ITcpServerHandler = nextpas.core.net.server.intf.ITcpServerHandler;
  ITcpServer = nextpas.core.net.server.intf.ITcpServer;

const
  TCP_SERVER_BACKEND_THREADED = nextpas.core.net.server.base.tsbThreaded;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.net.server.base.tsbEpoll;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.net.server.base.tsbKqueue;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.net.server.base.tsbIocp;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.net.server.base.tscoServer;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.net.server.base.tscoHandler;
  TCP_SERVER_HANDOFF_ACCEPTED = nextpas.core.net.server.base.tshrAccepted;
  TCP_SERVER_HANDOFF_REJECTED = nextpas.core.net.server.base.tshrRejected;
  TCP_SERVER_HANDOFF_SHUTTING_DOWN = nextpas.core.net.server.base.tshrShuttingDown;
  TCP_SERVER_WORK_COMPLETED = nextpas.core.net.server.base.tswoCompleted;
  TCP_SERVER_WORK_FAILED = nextpas.core.net.server.base.tswoFailed;

function NewTcpServer: ITcpServer; overload; inline;
function NewTcpServer(const AOptions: TTcpServerOptions): ITcpServer; overload;

implementation

uses
  nextpas.core.errors;

function NewTcpServer: ITcpServer;
begin
  Result := NewTcpServer(TTcpServerOptions.Default);
end;

function NewTcpServer(const AOptions: TTcpServerOptions): ITcpServer;
begin
  case AOptions.Backend of
    tsbThreaded:
      Result := nextpas.core.net.server.threaded.NewTcpThreadedServer(AOptions);
    {$IFDEF NEXTPAS_LINUX}
    tsbEpoll:
      Result := nextpas.core.net.server.epoll.NewTcpEpollServer(AOptions);
    {$ENDIF}
  else
    raise ENotSupportedError.Create('tcp server backend not implemented yet');
  end;
end;

end.
