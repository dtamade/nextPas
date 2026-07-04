program bench_stopwatch;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time, nextpas.core.time.base, nextpas.core.stopwatch, nextpas.core.stopwatch.tick,
  nextpas.core.stopwatch.tick.unix, nextpas.core.stopwatch.tick.x86_64;
var GSink: UInt64 = 0;
procedure BenchStopwatchOverhead(const ACtx: IBenchContext);
var LSw: TStopwatch;
begin LSw := TStopwatch.StartNew; LSw.Stop; GSink := GSink xor LSw.ElapsedTicks; end;
procedure BenchFpcGetTickCount64(const ACtx: IBenchContext);
begin GSink := GSink xor GetTickCount64; end;
procedure BenchInstantNow(const ACtx: IBenchContext);
var LI: TInstant;
begin LI := TInstant.Now; GSink := GSink xor UInt64(LI.AsNanoseconds); end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('stopwatch');
  LSuite.Add('StartNew+Stop', @BenchStopwatchOverhead).Add('GetTickCount64', @BenchFpcGetTickCount64).Add('InstantNow', @BenchInstantNow);
  WriteLn(LSuite.Run.PrintToConsole);
end.
