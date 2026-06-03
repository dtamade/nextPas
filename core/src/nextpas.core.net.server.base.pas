unit nextpas.core.net.server.base;

{$I nextpas.core.settings.inc}

interface

type
  TTcpServerBackend = (
    tsbThreaded,
    tsbEpoll,
    tsbKqueue,
    tsbIocp
  );

  TTcpServerConnOwnership = (
    tscoServer,
    tscoHandler
  );

  TTcpServerHandoffResult = (
    tshrAccepted,
    tshrRejected,
    tshrShuttingDown
  );

  TTcpServerWorkOutcome = (
    tswoCompleted,
    tswoFailed
  );

  TTcpServerOptions = record
    Backend: TTcpServerBackend;
    class function Default: TTcpServerOptions; static;
  end;

implementation

class function TTcpServerOptions.Default: TTcpServerOptions;
begin
  Result.Backend := tsbThreaded;
end;

end.
