unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

procedure TestClockReset;
procedure TestClockSetOverflowRegression(const ABaseMs, ARegressionMs, AAdvanceMs: UInt64);
function TestClockCallCount: SizeUInt;

function platform_realtime_ns: UInt64;

implementation

const
  OVERFLOW_REGRESSION_READ_CALL = SizeUInt(4098);

var
  GBaseMs: UInt64 = 5000;
  GRegressionMs: UInt64 = 4999;
  GAdvanceMs: UInt64 = 5001;
  GCallCount: SizeUInt = 0;

procedure TestClockReset;
begin
  GBaseMs := 5000;
  GRegressionMs := 4999;
  GAdvanceMs := 5001;
  GCallCount := 0;
end;

procedure TestClockSetOverflowRegression(const ABaseMs, ARegressionMs, AAdvanceMs: UInt64);
begin
  GBaseMs := ABaseMs;
  GRegressionMs := ARegressionMs;
  GAdvanceMs := AAdvanceMs;
  GCallCount := 0;
end;

function TestClockCallCount: SizeUInt;
begin
  Result := GCallCount;
end;

function platform_realtime_ns: UInt64;
var
  LMs: UInt64;
begin
  Inc(GCallCount);
  if GCallCount < OVERFLOW_REGRESSION_READ_CALL then
    LMs := GBaseMs
  else if GCallCount = OVERFLOW_REGRESSION_READ_CALL then
    LMs := GRegressionMs
  else
    LMs := GAdvanceMs;
  Result := LMs * 1000000;
end;

end.
