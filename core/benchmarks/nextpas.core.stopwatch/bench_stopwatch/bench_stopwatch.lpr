program bench_stopwatch;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time, nextpas.core.time.base, nextpas.core.stopwatch,
  nextpas.core.platform.time;
var GSink: UInt64 = 0;
procedure BenchStopwatchOverhead(const ACtx: IBenchContext);
var LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  LSw.Stop;
  GSink := GSink xor UInt64(LSw.ElapsedNs);
end;
procedure BenchMonotonicNs(const ACtx: IBenchContext);
begin
  GSink := GSink xor platform_monotonic_ns;
end;
procedure BenchInstantNow(const ACtx: IBenchContext);
var LI, LZero: TInstant;
begin
  LZero := Default(TInstant);
  LI := TInstant.Now;
  GSink := GSink xor UInt64(LI.DurationSince(LZero).AsNanoseconds);
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('stopwatch');
  LSuite.Add('StartNew+Stop', @BenchStopwatchOverhead)
    .Add('platform_monotonic_ns', @BenchMonotonicNs)
    .Add('InstantNow', @BenchInstantNow);
  WriteLn(LSuite.Run.PrintToConsole);
end.
