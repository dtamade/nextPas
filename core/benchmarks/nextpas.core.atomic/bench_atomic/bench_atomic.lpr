program bench_atomic;
{$I nextpas.core.settings.inc}
uses SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.atomic, nextpas.core.platform.info;

const ITERS = 1000000;

var
  GSink32: Int32 = 0;
  GSinkUInt32: UInt32 = 0;

procedure BenchPlainIncrement(const ACtx: IBenchContext);
var
  LValue: Int32;
  LI: Int32;
begin
  LValue := 0;
  for LI := 1 to ITERS do
    LValue := LValue + Int32((LI and 1) + 1);
  GSink32 := LValue;
end;

procedure BenchAtomicLoadStore32(const ACtx: IBenchContext);
var
  LValue: Int32;
  LSink: Int32;
  LI: Int32;
begin
  LValue := 0;
  for LI := 1 to ITERS do
  begin
    LSink := AtomicLoad32(LValue, moRelaxed);
    AtomicStore32(LValue, LSink + 1, moRelaxed);
  end;
  GSink32 := LValue;
end;

procedure BenchFetchAdd32(const ACtx: IBenchContext);
var
  LValue: Int32;
  LI: Int32;
begin
  LValue := 0;
  for LI := 1 to ITERS do
    AtomicFetchAdd32(LValue, 1, moRelaxed);
  GSink32 := LValue;
end;

procedure BenchCompareExchange32(const ACtx: IBenchContext);
var
  LValue: Int32;
  LExpected: Int32;
  LI: Int32;
begin
  LValue := 0;
  for LI := 1 to ITERS do
  begin
    LExpected := LValue;
    AtomicCompareExchange32(LValue, LExpected, LExpected + 1, moSeqCst);
  end;
  GSink32 := LValue;
end;

procedure BenchAtomicUInt32(const ACtx: IBenchContext);
var
  LCounter: TAtomicUInt32;
  LI: Int32;
begin
  LCounter := TAtomicUInt32.Create(0);
  for LI := 1 to ITERS do
    LCounter.Increment;
  GSinkUInt32 := LCounter.Load;
end;

var
  LResults: IBenchResults;
begin
  WriteLn('Platform: ', OSName, ' / ', CPUName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32');
  WriteLn('Baselines: plain local variable operations for single-thread overhead context; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  LResults := TBenchSuite.Create('atomic')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('atomic/PlainIncrement', @BenchPlainIncrement)
    .Add('atomic/LoadStore32', @BenchAtomicLoadStore32)
    .Add('atomic/FetchAdd32', @BenchFetchAdd32)
    .Add('atomic/CompareExchange32', @BenchCompareExchange32)
    .Add('atomic/TAtomicUInt32', @BenchAtomicUInt32)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-atomic.json');
end.
