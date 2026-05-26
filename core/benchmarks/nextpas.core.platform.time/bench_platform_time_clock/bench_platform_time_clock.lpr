program bench_platform_time_clock;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time;

const
  ITERATIONS = 200000;

var
  GSink: UInt64;

procedure ReportMetric(const AName: string; const AElapsedNs: UInt64);
begin
  WriteLn(AName, '-iterations=', ITERATIONS);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if ITERATIONS > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div ITERATIONS);
end;

procedure BenchMonotonicClock;
var
  LStart: UInt64;
  LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    GSink := GSink xor platform_monotonic_ns;
  LFinish := platform_monotonic_ns;
  if LFinish < LStart then
    Halt(1);
  ReportMetric('platform-time-monotonic', LFinish - LStart);
end;

procedure BenchRealtimeClock;
var
  LStart: UInt64;
  LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    GSink := GSink xor platform_realtime_ns;
  LFinish := platform_monotonic_ns;
  if LFinish < LStart then
    Halt(1);
  ReportMetric('platform-time-realtime', LFinish - LStart);
end;

begin
  WriteLn('platform-time-bench=running');
  BenchMonotonicClock;
  BenchRealtimeClock;
  WriteLn('platform-time-bench-sink=', GSink);
  WriteLn('platform-time-bench-status=pass');
end.
