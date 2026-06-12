unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

procedure TestThreadReset;
function TestThreadYieldCount: SizeUInt;

procedure platform_thread_yield;

implementation

var
  GYieldCount: SizeUInt = 0;

procedure TestThreadReset;
begin
  GYieldCount := 0;
end;

function TestThreadYieldCount: SizeUInt;
begin
  Result := GYieldCount;
end;

procedure platform_thread_yield;
begin
  Inc(GYieldCount);
end;

end.
