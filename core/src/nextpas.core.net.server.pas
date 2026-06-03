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
  TTcpServerPollResult = nextpas.core.net.server.intf.TTcpServerPollResult;
  TTcpServerOptions = nextpas.core.net.server.base.TTcpServerOptions;
  TTcpServerFactory = function(const AOptions: TTcpServerOptions): ITcpServer;
  ITcpServerWork = nextpas.core.net.server.intf.ITcpServerWork;
  ITcpServerWorkCompletion = nextpas.core.net.server.intf.ITcpServerWorkCompletion;
  ITcpServerWorkerHandoff = nextpas.core.net.server.intf.ITcpServerWorkerHandoff;
  ITcpServerSessionContext = nextpas.core.net.server.intf.ITcpServerSessionContext;
  ITcpServerSession = nextpas.core.net.server.intf.ITcpServerSession;
  ITcpServerPollDrivenSession = nextpas.core.net.server.intf.ITcpServerPollDrivenSession;
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
  TCP_SERVER_POLL_WAIT = nextpas.core.net.server.intf.tsprWait;
  TCP_SERVER_POLL_DONE = nextpas.core.net.server.intf.tsprDone;

procedure RegisterTcpServerFactory(const ABackend: TTcpServerBackend;
  const AFactory: TTcpServerFactory);
procedure UnregisterTcpServerFactory(const ABackend: TTcpServerBackend);
function HasTcpServerFactory(const ABackend: TTcpServerBackend): Boolean;
function TryGetTcpServerFactory(const ABackend: TTcpServerBackend;
  out AFactory: TTcpServerFactory): Boolean;
function ResolveTcpServer(const AOptions: TTcpServerOptions): ITcpServer;
function NewTcpServer: ITcpServer; overload; inline;
function NewTcpServer(const AOptions: TTcpServerOptions): ITcpServer; overload;

implementation

uses
  nextpas.core.errors;

var
  GServerFactories: array[TTcpServerBackend] of TTcpServerFactory;

procedure RegisterTcpServerFactory(const ABackend: TTcpServerBackend;
  const AFactory: TTcpServerFactory);
begin
  if not Assigned(AFactory) then
    raise EArgumentError.Create('tcp server factory must not be nil');
  GServerFactories[ABackend] := AFactory;
end;

procedure UnregisterTcpServerFactory(const ABackend: TTcpServerBackend);
begin
  GServerFactories[ABackend] := nil;
end;

function HasTcpServerFactory(const ABackend: TTcpServerBackend): Boolean;
begin
  Result := Assigned(GServerFactories[ABackend]);
end;

function TryGetTcpServerFactory(const ABackend: TTcpServerBackend;
  out AFactory: TTcpServerFactory): Boolean;
begin
  AFactory := GServerFactories[ABackend];
  Result := Assigned(AFactory);
end;

function ResolveTcpServer(const AOptions: TTcpServerOptions): ITcpServer;
var
  LFactory: TTcpServerFactory;
begin
  if not TryGetTcpServerFactory(AOptions.Backend, LFactory) then
    raise ENotSupportedError.Create('tcp server backend not implemented yet');
  Result := LFactory(AOptions);
end;

function NewTcpServer: ITcpServer;
begin
  Result := NewTcpServer(TTcpServerOptions.Default);
end;

function NewTcpServer(const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := ResolveTcpServer(AOptions);
end;

procedure RegisterBuiltins;
begin
  RegisterTcpServerFactory(tsbThreaded,
    @nextpas.core.net.server.threaded.NewTcpThreadedServer);
  {$IFDEF NEXTPAS_LINUX}
  RegisterTcpServerFactory(tsbEpoll,
    @nextpas.core.net.server.epoll.NewTcpEpollServer);
  {$ENDIF}
end;

initialization
  RegisterBuiltins;

end.
