unit nextpas.core.net.maintenance.scheduler;

{** nextpas.core.net.maintenance.scheduler - 通用 KeepAlive 调度器（L2）。
 *
 *  从 `nextpas.core.ssh.keepalive.scheduler.TKeepAliveScheduler` 抽离：
 *  `record + IAsyncLoop` 缝隙，委托 `TKeepAlivePolicy` 单源，不自实现时钟。
 *  复用：ssh 异步心跳、tls/quic 定时心跳、http PING 调度。
 *  单源：ShouldSend 委托策略；Schedule/Cancel 仅注册 `ScheduleMethod/CancelTimer` 单次，无轮询、无堆分配。
 *  性能：ShouldSend/Schedule/Cancel 薄转发 inline；调度回调外联，防 I-Cache 膨胀。
 *  稳定性：Cancel 幂等，FHandle.IsValid 守卫 + try/except 吞 Close 竞态，FActive 状态机防重注册泄漏。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.maintenance.keepalive;

type
  TKeepAliveScheduler = record
  private
    FPolicy: TKeepAlivePolicy;
    FLoop: TAsyncLoop;
    FHandle: TAsyncTimerHandle;
    FIntervalMs: Integer;
    FActive: Boolean;
  public
    procedure Init(AIntervalMs: Integer; ALoop: TAsyncLoop); inline;
    procedure Reset; inline;
    function ShouldSend: Boolean; inline;
    procedure Schedule(ACallback: TAsyncCallbackMethod; AContext: Pointer); inline;
    procedure Cancel; inline;
    property IntervalMs: Integer read FIntervalMs;
    property Active: Boolean read FActive;
    property Handle: TAsyncTimerHandle read FHandle;
  end;

implementation

procedure TKeepAliveScheduler.Init(AIntervalMs: Integer; ALoop: TAsyncLoop); inline;
begin
  FIntervalMs := AIntervalMs;
  FLoop := ALoop;
  FHandle := Default(TAsyncTimerHandle);
  FActive := False;
  FPolicy.Init(AIntervalMs);
end;

procedure TKeepAliveScheduler.Reset; inline;
begin
  FPolicy.Reset;
end;

function TKeepAliveScheduler.ShouldSend: Boolean; inline;
begin
  Result := FPolicy.ShouldSend;
end;

procedure TKeepAliveScheduler.Schedule(ACallback: TAsyncCallbackMethod; AContext: Pointer); inline;
begin
  if (FIntervalMs <= 0) or (FLoop = nil) then Exit;
  if not Assigned(ACallback) then Exit;
  if not FLoop.IsValid then Exit;
  if FActive then
  begin
    try
      if FHandle.IsValid then
        FLoop.CancelTimer(FHandle);
    except
    end;
    FHandle := Default(TAsyncTimerHandle);
    FActive := False;
  end;
  FHandle := FLoop.ScheduleMethod(TDuration.FromMilliseconds(Int64(FIntervalMs)), ACallback, AContext);
  FActive := True;
end;

procedure TKeepAliveScheduler.Cancel; inline;
begin
  if not FActive then Exit;
  FActive := False;
  if FHandle.IsValid and (FLoop <> nil) and FLoop.IsValid then
    try
      FLoop.CancelTimer(FHandle);
    except
    end;
  FHandle := Default(TAsyncTimerHandle);
end;

end.
