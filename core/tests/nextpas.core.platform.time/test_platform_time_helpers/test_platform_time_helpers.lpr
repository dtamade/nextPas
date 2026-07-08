program test_platform_time_helpers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.platform.time.base,
  nextpas.core.platform.time;

var
  T: TTestSuite;

procedure TestQpcToNsBasic;
begin
  CheckEqual(Int64(1000000000), Int64(platform_qpc_to_ns(10000000, 10000000)), '1 sec at 10MHz');
  CheckEqual(Int64(500000000), Int64(platform_qpc_to_ns(5000000, 10000000)), '0.5 sec at 10MHz');
  CheckEqual(Int64(0), Int64(platform_qpc_to_ns(0, 10000000)), 'zero counter');
end;

procedure TestQpcToNsHighCounter;
var
  LCounter: UInt64;
  LResult: UInt64;
begin
  LCounter := UInt64(High(Int64));
  LResult := platform_qpc_to_ns(LCounter, 10000000);
  Check(LResult > 0, 'High(Int64) counter at 10MHz should not overflow');
  Check(LResult > UInt64(900000000) * UInt64(1000000000), 'should be > 900 billion ns');
end;

procedure TestQpcToNsHugeFrequencyFraction;
var
  LResult: UInt64;
begin
  LResult := platform_qpc_to_ns(High(UInt64) div 2, High(UInt64));
  CheckEqual(Int64(499999999), Int64(LResult), 'huge frequency fractional conversion should stay exact');
end;

procedure TestQpcToNsSaturatesOnUnrepresentableValue;
var
  LResult: UInt64;
begin
  LResult := platform_qpc_to_ns(High(UInt64), 1);
  CheckEqual(Int64(-1), Int64(LResult), 'unrepresentable qpc conversion should saturate');
end;

procedure TestQpcToNsZeroFrequency;
var
  LResult: UInt64;
begin
  LResult := platform_qpc_to_ns(1000, 0);
  Check(LResult > 0, 'zero frequency should be handled safely');
end;

procedure TestResolutionFromFrequencyUsesCeil;
begin
  CheckEqual(Int64(334), Int64(platform_resolution_from_frequency_ns(3000000)), '3MHz resolution should ceil 333.333ns');
  CheckEqual(Int64(1), Int64(platform_resolution_from_frequency_ns(0)), 'zero frequency should fall back to 1ns');
  CheckEqual(Int64(1), Int64(platform_resolution_from_frequency_ns(2000000000)), 'sub-ns frequencies should report at least 1ns');
end;

procedure TestTimespecToNsBasic;
begin
  CheckEqual(Int64(1000000000), Int64(platform_timespec_to_ns(1, 0)), '1 sec');
  CheckEqual(Int64(999999999), Int64(platform_timespec_to_ns(0, 999999999)), 'max nsec');
  CheckEqual(Int64(1999999999), Int64(platform_timespec_to_ns(1, 999999999)), '1 sec + max nsec');
  CheckEqual(Int64(0), Int64(platform_timespec_to_ns(0, 0)), 'zero');
end;

procedure TestTimespecToNsClampsInvalidInput;
begin
  CheckEqual(Int64(0), Int64(platform_timespec_to_ns(-1, 0)), 'negative seconds should clamp to zero');
  CheckEqual(Int64(0), Int64(platform_timespec_to_ns(0, -1)), 'negative nanoseconds should clamp to zero');
  CheckEqual(Int64(-1), Int64(platform_timespec_to_ns(High(Int64), 999999999)), 'overflow should saturate');
end;

procedure TestMonotonicNeverGoesBackward;
var
  LPrev, LCurr: UInt64;
  LIdx: Integer;
begin
  LPrev := platform_monotonic_ns;
  for LIdx := 1 to 1000 do
  begin
    LCurr := platform_monotonic_ns;
    Check(LCurr >= LPrev, 'monotonic clock went backward at iteration ' + IntToStr(LIdx));
    LPrev := LCurr;
  end;
end;

procedure TestRealtimeClockAvailable;
var
  LRealtime: UInt64;
begin
  LRealtime := platform_realtime_ns;
  Check(LRealtime > 0, 'realtime clock should be available');
end;

procedure TestMonotonicResolutionAvailable;
var
  LResolution: UInt64;
begin
  LResolution := platform_monotonic_resolution_ns;
  Check(LResolution >= 1, 'monotonic resolution must be at least 1ns');
end;

procedure TestBreakdownEpochZero;
var
  LResult: TPlatformTimeBreakdown;
begin
  platform_time_breakdown_utc(0, LResult);
  CheckEqual(Int64(1970), Int64(LResult.Year), 'epoch year');
  CheckEqual(Int64(1), Int64(LResult.Month), 'epoch month');
  CheckEqual(Int64(1), Int64(LResult.Day), 'epoch day');
  CheckEqual(Int64(0), Int64(LResult.Hour), 'epoch hour');
  CheckEqual(Int64(0), Int64(LResult.Minute), 'epoch minute');
  CheckEqual(Int64(0), Int64(LResult.Second), 'epoch second');
  CheckEqual(Int64(0), Int64(LResult.Millisecond), 'epoch ms');
end;

procedure TestBreakdownKnownTimestamp;
var
  LResult: TPlatformTimeBreakdown;
begin
  { 2024-01-15 12:30:45.123 UTC = 1705321845.123 * 1e9 }
  platform_time_breakdown_utc(UInt64(1705321845) * 1000000000 + 123000000, LResult);
  CheckEqual(Int64(2024), Int64(LResult.Year), '2024 year');
  CheckEqual(Int64(1), Int64(LResult.Month), 'jan');
  CheckEqual(Int64(15), Int64(LResult.Day), '15th');
  CheckEqual(Int64(12), Int64(LResult.Hour), '12h');
  CheckEqual(Int64(30), Int64(LResult.Minute), '30m');
  CheckEqual(Int64(45), Int64(LResult.Second), '45s');
  CheckEqual(Int64(123), Int64(LResult.Millisecond), '123ms');
end;

procedure TestBreakdownLeapYear;
var
  LResult: TPlatformTimeBreakdown;
begin
  { 2024-02-29 00:00:00 UTC = 1709164800 * 1e9 }
  platform_time_breakdown_utc(UInt64(1709164800) * 1000000000, LResult);
  CheckEqual(Int64(2024), Int64(LResult.Year), 'leap year');
  CheckEqual(Int64(2), Int64(LResult.Month), 'feb');
  CheckEqual(Int64(29), Int64(LResult.Day), 'leap day');
end;

procedure TestBreakdownEndOfDay;
var
  LResult: TPlatformTimeBreakdown;
begin
  { 1970-01-01 23:59:59.999 UTC = 86399.999 * 1e9 }
  platform_time_breakdown_utc(UInt64(86399) * 1000000000 + 999000000, LResult);
  CheckEqual(Int64(1970), Int64(LResult.Year), 'year');
  CheckEqual(Int64(1), Int64(LResult.Month), 'month');
  CheckEqual(Int64(1), Int64(LResult.Day), 'day');
  CheckEqual(Int64(23), Int64(LResult.Hour), '23h');
  CheckEqual(Int64(59), Int64(LResult.Minute), '59m');
  CheckEqual(Int64(59), Int64(LResult.Second), '59s');
  CheckEqual(Int64(999), Int64(LResult.Millisecond), '999ms');
end;

procedure TestUtcOffsetReasonable;
var
  LOffset: Int32;
begin
  LOffset := platform_utc_offset_seconds;
  { UTC offset must be between -12h and +14h }
  Check(LOffset >= -43200, 'offset >= -12h');
  Check(LOffset <= 50400, 'offset <= +14h');
  { Must be aligned to 15-minute boundaries (900s) for all real timezones }
  Check(LOffset mod 900 = 0, 'offset aligned to 15min');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.time.helpers');
  T.Test('QPC to ns basic', @TestQpcToNsBasic);
  T.Test('QPC to ns high counter (no overflow)', @TestQpcToNsHighCounter);
  T.Test('QPC to ns huge frequency fraction', @TestQpcToNsHugeFrequencyFraction);
  T.Test('QPC to ns saturates unrepresentable values', @TestQpcToNsSaturatesOnUnrepresentableValue);
  T.Test('QPC to ns zero frequency', @TestQpcToNsZeroFrequency);
  T.Test('Resolution from frequency uses ceil', @TestResolutionFromFrequencyUsesCeil);
  T.Test('Timespec to ns basic', @TestTimespecToNsBasic);
  T.Test('Timespec to ns clamps invalid input', @TestTimespecToNsClampsInvalidInput);
  T.Test('Monotonic never goes backward (1000 calls)', @TestMonotonicNeverGoesBackward);
  T.Test('Realtime clock is available', @TestRealtimeClockAvailable);
  T.Test('Monotonic resolution is available', @TestMonotonicResolutionAvailable);
  T.Test('Breakdown epoch zero', @TestBreakdownEpochZero);
  T.Test('Breakdown known timestamp (2024-01-15)', @TestBreakdownKnownTimestamp);
  T.Test('Breakdown leap year (2024-02-29)', @TestBreakdownLeapYear);
  T.Test('Breakdown end of day (23:59:59.999)', @TestBreakdownEndOfDay);
  T.Test('UTC offset reasonable', @TestUtcOffsetReasonable);
  if not T.Run then Halt(1);
end.
