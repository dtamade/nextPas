program bench_platform_time_clock;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.platform.time;
var GSink: UInt64 = 0;
procedure BenchMonotonic(const ACtx: IBenchContext);
begin GSink := GSink xor platform_monotonic_ns; end;
procedure BenchRealtime(const ACtx: IBenchContext);
begin GSink := GSink xor platform_realtime_ns; end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('platform-time');
  LSuite.Add('Monotonic', @BenchMonotonic).Add('Realtime', @BenchRealtime);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('sink=', GSink);
end.
