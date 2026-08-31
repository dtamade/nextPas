unit nextpas.core.ssh.keepalive;

{** nextpas.core.ssh - KeepAlive 策略（可复用）。
 *
 * 周期心跳基于单调时钟或外部调度器；transport 层不感知，
 * 由 session 层按 KeepAliveIntervalMs 触发 SendIgnore。
 * 复用 TInstant 单调时钟，零 SysUtils 直连。 *}

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
    procedure Init(AIntervalMs: Integer);
    procedure Reset;
    function ShouldSend: Boolean;
    property IntervalMs: Integer read FIntervalMs;
  end;

implementation

procedure TKeepAlivePolicy.Init(AIntervalMs: Integer);
begin
  FIntervalMs := AIntervalMs;
  FLast := TInstant.Now;
end;

procedure TKeepAlivePolicy.Reset;
begin
  FLast := TInstant.Now;
end;

function TKeepAlivePolicy.ShouldSend: Boolean;
begin
  Result := False;
  if FIntervalMs <= 0 then Exit;
  if FLast.Elapsed.AsMilliseconds >= Int64(FIntervalMs) then Exit(True);
end;

end.
