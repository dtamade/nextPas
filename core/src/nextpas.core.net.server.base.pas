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
    { ShutdownTimeoutNs: max nanoseconds to wait for in-flight requests
      during graceful shutdown. 0 = wait forever (default). }
    ShutdownTimeoutNs: Int64;
    class function Default: TTcpServerOptions; static;
  end;

implementation

class function TTcpServerOptions.Default: TTcpServerOptions;
begin
  Result.Backend := tsbThreaded;
  Result.ShutdownTimeoutNs := 0;
end;

end.
