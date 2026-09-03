unit nextpas.core.net.maintenance.keepalive;

{** nextpas.core.net.maintenance.keepalive - 通用 KeepAlive 策略（L1）。
 *
 *  从 `nextpas.core.ssh.keepalive.TKeepAlivePolicy` 抽离：
 *  周期心跳基于单调时钟 `TInstant.Elapsed`，`IntervalMs<=0` 表示禁用。
 *  复用：ssh keepalive（SSH_MSG_IGNORE）、http PING、tls/quic 心跳。
 *  单源：ShouldSend 单点，Scheduler 侧委托此策略，不自实现时钟。
 *  性能：record 零堆，Init/Reset/ShouldSend 全 inline。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  TKeepAlivePolicy = record
  private
    FIntervalMs: Integer;
    FLast: TInstant;
  public
    procedure Init(AIntervalMs: Integer); inline;
    procedure Reset; inline;
    function ShouldSend: Boolean; inline;
    property IntervalMs: Integer read FIntervalMs;
  end;

implementation

procedure TKeepAlivePolicy.Init(AIntervalMs: Integer); inline;
begin
  FIntervalMs := AIntervalMs;
  FLast := TInstant.Now;
end;

procedure TKeepAlivePolicy.Reset; inline;
begin
  FLast := TInstant.Now;
end;

function TKeepAlivePolicy.ShouldSend: Boolean; inline;
begin
  Result := False;
  if FIntervalMs <= 0 then Exit;
  if FLast.Elapsed.AsMilliseconds >= Int64(FIntervalMs) then Exit(True);
end;

end.
