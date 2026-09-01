unit nextpas.core.ssh.keepalive.scheduler;

{** nextpas.core.ssh.keepalive.scheduler - KeepAlive 调度器独立模块（S27′ 晋升）。
 *
 *  将散落在 session.async 的 TAsyncLoop.ScheduleMethod 周期心跳抽离为
 *  可复用调度器，供 TLS/QUIC 定时心跳复用。形态：record + IAsyncLoop 缝隙。
 *  单源：委托 nextpas.core.ssh.keepalive.TKeepAlivePolicy；bytes/文本零复用。
 *  perf: inline ShouldSend/Schedule/Cancel 薄转发，调度仅 ScheduleMethod/CancelTimer
 *        单次注册，零轮询，零堆分配，Won't inline 膨胀（回调外联）。
 *  stability: Cancel/Close 幂等，FHandle.IsValid 守卫 + try/except 吞 Close 竞态，
 *            loop 侧 Wake 保证 10ms 内唤醒，无泄漏。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.ssh.keepalive;

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

procedure TKeepAliveScheduler.Init(AIntervalMs: Integer; ALoop: TAsyncLoop);
begin
  FIntervalMs := AIntervalMs;
  FLoop := ALoop;
  FHandle := Default(TAsyncTimerHandle);
  FActive := False;
  FPolicy.Init(AIntervalMs);
end;

procedure TKeepAliveScheduler.Reset;
begin
  FPolicy.Reset;
end;

function TKeepAliveScheduler.ShouldSend: Boolean;
begin
  Result := FPolicy.ShouldSend;
end;

procedure TKeepAliveScheduler.Schedule(ACallback: TAsyncCallbackMethod; AContext: Pointer);
begin
  if (FIntervalMs <= 0) or (FLoop = nil) then Exit;
  if not Assigned(ACallback) then Exit;
  if not FLoop.IsValid then Exit;
  if FActive then
  begin
    // 周期重调度：已触发句柄 Cancel 返回 False 无害，幂等清状态后重注册
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

procedure TKeepAliveScheduler.Cancel;
begin
  if not FActive then Exit;
  FActive := False;
  if FHandle.IsValid and (FLoop <> nil) and FLoop.IsValid then
    try
      FLoop.CancelTimer(FHandle);
    except
      // 幂等：loop 已 Close 时 CancelTimer 抛异常，吞掉保证资源释放不丢
    end;
  FHandle := Default(TAsyncTimerHandle);
end;

end.
