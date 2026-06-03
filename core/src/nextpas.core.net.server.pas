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
  nextpas.core.net.server.threaded;

type
  TTcpServerBackend = nextpas.core.net.server.base.TTcpServerBackend;
  TTcpServerConnOwnership = nextpas.core.net.server.base.TTcpServerConnOwnership;
  TTcpServerOptions = nextpas.core.net.server.base.TTcpServerOptions;
  ITcpServerHandler = nextpas.core.net.server.intf.ITcpServerHandler;
  ITcpServer = nextpas.core.net.server.intf.ITcpServer;

const
  TCP_SERVER_BACKEND_THREADED = nextpas.core.net.server.base.tsbThreaded;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.net.server.base.tsbEpoll;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.net.server.base.tsbKqueue;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.net.server.base.tsbIocp;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.net.server.base.tscoServer;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.net.server.base.tscoHandler;

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
  else
    raise ENotSupportedError.Create('tcp server backend not implemented yet');
  end;
end;

end.
