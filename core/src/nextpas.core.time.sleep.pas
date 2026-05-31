unit nextpas.core.time.sleep;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline;

type
  TSleep = record
  public
    class procedure ForDuration(const ADuration: TDuration); static;
    class procedure Until_(const ADeadline: TDeadline); static;
  end;

implementation

uses
  nextpas.core.platform.thread;

{ TSleep }

class procedure TSleep.ForDuration(const ADuration: TDuration);
begin
  if ADuration.AsNanoseconds <= 0 then
    Exit;
  platform_thread_sleep_ns(UInt64(ADuration.AsNanoseconds));
end;

class procedure TSleep.Until_(const ADeadline: TDeadline);
var
  LRemaining: TDuration;
begin
  if ADeadline.IsInfinite then
  begin
    { Sleep in 1-hour chunks to avoid overflow issues }
    while True do
      platform_thread_sleep_ns(UInt64(3600) * 1000000000);
  end;

  LRemaining := ADeadline.Remaining;
  if LRemaining.AsNanoseconds <= 0 then
    Exit;
  platform_thread_sleep_ns(UInt64(LRemaining.AsNanoseconds));
end;

end.
