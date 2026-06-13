program test_platform_time_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.time;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. Monotonic clock must never go backward under Wine Windows QPC }
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

{ 2. Realtime clock returns a positive, non-zero value under Wine }
procedure TestRealtimeIsReasonable;
var
  LRealtime: UInt64;
begin
  LRealtime := platform_realtime_ns;
  Check(LRealtime > 0, 'realtime clock should return a positive value');
end;

{ 3. Monotonic resolution is at least 1ns }
procedure TestMonotonicResolutionIsPositive;
var
  LResolution: UInt64;
begin
  LResolution := platform_monotonic_resolution_ns;
  Check(LResolution >= 1, 'monotonic resolution must be at least 1ns');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

{ 4. QPC to ns conversion correctness - pure math, no OS dependencies }
procedure TestQpcToNsBasic;
begin
  CheckEqual(Int64(1000000000), Int64(platform_qpc_to_ns(10000000, 10000000)), '1 sec at 10MHz');
  CheckEqual(Int64(500000000), Int64(platform_qpc_to_ns(5000000, 10000000)), '0.5 sec at 10MHz');
  CheckEqual(Int64(0), Int64(platform_qpc_to_ns(0, 10000000)), 'zero counter');
end;

{ 5. Resolution from frequency conversion - pure math, no OS dependencies }
procedure TestResolutionFromFrequencyBasic;
begin
  CheckEqual(Int64(334), Int64(platform_resolution_from_frequency_ns(3000000)), '3MHz resolution should ceil 333.333ns');
  CheckEqual(Int64(1), Int64(platform_resolution_from_frequency_ns(0)), 'zero frequency should fall back to 1ns');
  CheckEqual(Int64(1), Int64(platform_resolution_from_frequency_ns(2000000000)), 'sub-ns frequencies should report at least 1ns');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('monotonic never goes backward (1000 calls)', @TestMonotonicNeverGoesBackward);
  T.Run('realtime clock returns reasonable value', @TestRealtimeIsReasonable);
  T.Run('monotonic resolution is positive', @TestMonotonicResolutionIsPositive);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Run('QPC to ns basic conversion', @TestQpcToNsBasic);
  T.Run('resolution from frequency basic', @TestResolutionFromFrequencyBasic);
  T.Summary;
end.