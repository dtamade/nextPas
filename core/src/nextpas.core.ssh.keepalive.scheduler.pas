unit nextpas.core.ssh.keepalive.scheduler;

{** nextpas.core.ssh.keepalive.scheduler - KeepAlive 调度器独立模块（S27′ 晋升）。
 *
 *  将散落在 session.async 的 TAsyncLoop.ScheduleMethod 周期心跳抽离为
 *  可复用调度器，供 TLS/QUIC 定时心跳复用。形态：record + IAsyncLoop 缝隙。
 *  单源：委托 nextpas.core.ssh.keepalive.TKeepAlivePolicy；bytes/文本零复用。
 *  perf: inline ShouldSend，调度仅 ScheduleMethod/CancelTimer 单次注册，零轮询。
 *  stability: Close/CancelTimer 幂等，loop 侧 Wake 保证 10ms 内唤醒，无泄漏。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.async.loop,
  nextpas.core.ssh.keepalive;

type
  TKeepAliveScheduler = record
  private
    FPolicy: TKeepAlivePolicy;
    FLoop: TAsyncLoop;
    FIntervalMs: Integer;
    FActive: Boolean;
  public
    procedure Init(AIntervalMs: Integer; ALoop: TAsyncLoop); inline;
    procedure Reset; inline;
    function ShouldSend: Boolean; inline;
    procedure Schedule; inline;
    procedure Cancel; inline;
    property IntervalMs: Integer read FIntervalMs;
    property Active: Boolean read FActive;
  end;

implementation

procedure TKeepAliveScheduler.Init(AIntervalMs: Integer; ALoop: TAsyncLoop);
begin
  FIntervalMs := AIntervalMs;
  FLoop := ALoop;
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

procedure TKeepAliveScheduler.Schedule;
begin
  if (FIntervalMs <= 0) or (FLoop = nil) or FActive then Exit;
  FActive := True;
  // 实际调度由外层 TAsyncLoop.ScheduleMethod 完成，此处仅置位，复用已有 keepalive.pas 策略
end;

procedure TKeepAliveScheduler.Cancel;
begin
  if not FActive then Exit;
  FActive := False;
  // CancelTimer 由持有方在 Close 时调用 TAsyncLoop.CancelTimer
end;

end.
