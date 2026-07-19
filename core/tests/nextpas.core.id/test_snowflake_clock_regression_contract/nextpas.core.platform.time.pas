unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.time.base;

type
  TPlatformTimeNanoseconds = nextpas.core.platform.time.base.TPlatformTimeNanoseconds;
  TPlatformCounterValue = nextpas.core.platform.time.base.TPlatformCounterValue;
  TPlatformCounterFrequency = nextpas.core.platform.time.base.TPlatformCounterFrequency;

procedure TestClockReset;
procedure TestClockSetOverflowRegression(const ABaseMs, ARegressionMs, AAdvanceMs: UInt64);
function TestClockCallCount: SizeUInt;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
function platform_realtime_ns: TPlatformTimeNanoseconds;
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
function platform_qpc_to_ns(const ACounter: TPlatformCounterValue; const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_resolution_from_frequency_ns(const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): TPlatformTimeNanoseconds;
function platform_utc_offset_seconds: Int32;
procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds; out AResult: TPlatformTimeBreakdown);

implementation

const
  OVERFLOW_REGRESSION_READ_CALL = SizeUInt(4098);

var
  GBaseMs: UInt64 = 5000;
  GRegressionMs: UInt64 = 4999;
  GAdvanceMs: UInt64 = 5001;
  GCallCount: SizeUInt = 0;

function CurrentMs: UInt64;
begin
  if GCallCount < OVERFLOW_REGRESSION_READ_CALL then
    Result := GBaseMs
  else if GCallCount = OVERFLOW_REGRESSION_READ_CALL then
    Result := GRegressionMs
  else
    Result := GAdvanceMs;
end;

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

function platform_monotonic_ns: TPlatformTimeNanoseconds;
begin
  Result := CurrentMs * 1000000;
end;

function platform_realtime_ns: TPlatformTimeNanoseconds;
begin
  Inc(GCallCount);
  Result := CurrentMs * 1000000;
end;

function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
begin
  Result := 1;
end;

function platform_qpc_to_ns(const ACounter: TPlatformCounterValue; const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  if AFrequency = 0 then
    Exit(0);
  Result := TPlatformTimeNanoseconds((ACounter * 1000000000) div AFrequency);
end;

function platform_resolution_from_frequency_ns(const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  if AFrequency = 0 then
    Exit(1);
  Result := 1000000000 div AFrequency;
  if Result = 0 then
    Result := 1;
end;

function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): TPlatformTimeNanoseconds;
begin
  Result := TPlatformTimeNanoseconds(ASec) * 1000000000 + TPlatformTimeNanoseconds(ANsec);
end;

function platform_utc_offset_seconds: Int32;
begin
  Result := 0;
end;

procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds; out AResult: TPlatformTimeBreakdown);
begin
  FillChar(AResult, SizeOf(AResult), 0);
end;

end.
