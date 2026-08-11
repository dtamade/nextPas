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
    { WorkerPoolSize: worker 池规模（handler handoff + conn workers）。
      0 = auto（= platform_cpu_count，默认，保持既有行为）；>0 覆盖池规模，
      用于放开「流式并发上界 = worker 池规模」的伸缩上限（token888 已知差距
      #2，wiki/testing.md）：默认池规模 = 逻辑 CPU 数，超出后同连接数级排队
      （无背压丢弃，语义安全）。过大只徒增线程上下文切换，谨慎显式配置。 }
    WorkerPoolSize: Integer;
    class function Default: TTcpServerOptions; static;
  end;

implementation

class function TTcpServerOptions.Default: TTcpServerOptions;
begin
  Result.Backend := tsbThreaded;
  Result.ShutdownTimeoutNs := 0;
  Result.WorkerPoolSize := 0;
end;

end.
