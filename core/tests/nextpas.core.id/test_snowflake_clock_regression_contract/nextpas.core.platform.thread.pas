unit nextpas.core.platform.thread;

{$I nextpas.core.settings.inc}

interface

procedure TestThreadReset;
function TestThreadYieldCount: SizeUInt;

procedure platform_thread_yield;

implementation

uses
  nextpas.core.errors;

const
  MAX_TEST_YIELDS = 8;

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
  if GYieldCount > MAX_TEST_YIELDS then
    raise EInvalidOperationError.Create('snowflake clock wait did not make progress');
end;

end.
