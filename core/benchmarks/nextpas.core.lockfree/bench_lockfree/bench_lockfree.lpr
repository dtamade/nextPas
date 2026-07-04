program bench_lockfree;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.thread.init, nextpas.core.atomic, nextpas.core.lockfree,
  nextpas.core.lockfree.ebr, nextpas.core.lockfree.spsc, nextpas.core.lockfree.mpmc,
  nextpas.core.thread.channel, nextpas.core.platform.thread, nextpas.core.platform.info;
type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;
var GSpsc: TIntSpsc; GMpmc: TIntMpmc; GSeg: TIntSegQueue; GSpmc: TIntSpmc; GBenchSink: Int64;
procedure BenchSpscTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSpsc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchMpmcTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GMpmc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchSegTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSeg.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchSpmcTryDequeue(const ACtx: IBenchContext);
var LV: Integer;
begin if GSpmc.TryDequeue(LV) then GBenchSink := GBenchSink + LV; end;
procedure BenchEbrRetire(const ACtx: IBenchContext);
var LP: Pointer;
begin GetMem(LP, 64); EbrRetire(LP); end;
var LSuite: IBenchSuite;
begin
  WriteLn('Platform: ', BenchmarkPlatformName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T');
  WriteLn('Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  GSpsc := TIntSpsc.Create(1024); GMpmc := TIntMpmc.Create(1024);
  GSeg := TIntSegQueue.Create; GSpmc := TIntSpmc.Create(1024);
  GBenchSink := 0;
  LSuite := TBenchSuite.Create('lockfree');
  LSuite.Add('SPSC/TryDequeue', @BenchSpscTryDequeue).Add('MPMC/TryDequeue', @BenchMpmcTryDequeue)
    .Add('SegQueue/TryDequeue', @BenchSegTryDequeue).Add('SPMC/TryDequeue', @BenchSpmcTryDequeue).Add('EBR/Retire', @BenchEbrRetire);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('Sink: ', GBenchSink);
  GSpsc.Free; GMpmc.Free; GSeg.Free; GSpmc.Free;
end.
