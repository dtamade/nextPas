unit nextpas.core.net.server.kqueue;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpKqueueServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  nextpas.core.net.server.readiness;

function NewTcpKqueueServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := NewTcpReadinessServer(AOptions);
end;

end.
