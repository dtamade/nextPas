program test_platform_time_helpers;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.time;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.time.helpers');
  T.Run('QPC to ns basic', @TestQpcToNsBasic);
  T.Run('QPC to ns high counter (no overflow)', @TestQpcToNsHighCounter);
  T.Run('QPC to ns huge frequency fraction', @TestQpcToNsHugeFrequencyFraction);
  T.Run('QPC to ns saturates unrepresentable values', @TestQpcToNsSaturatesOnUnrepresentableValue);
  T.Run('QPC to ns zero frequency', @TestQpcToNsZeroFrequency);
  T.Run('Resolution from frequency uses ceil', @TestResolutionFromFrequencyUsesCeil);
  T.Run('Timespec to ns basic', @TestTimespecToNsBasic);
  T.Run('Timespec to ns clamps invalid input', @TestTimespecToNsClampsInvalidInput);
  T.Run('Monotonic never goes backward (1000 calls)', @TestMonotonicNeverGoesBackward);
  T.Run('Realtime clock is available', @TestRealtimeClockAvailable);
  T.Run('Monotonic resolution is available', @TestMonotonicResolutionAvailable);
  T.Summary;
end.
