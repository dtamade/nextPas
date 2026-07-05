program bench_atomic;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.atomic, nextpas.core.platform.info;

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
  LCounter.Init;
  for LI := 1 to ITERS do
    LCounter.Increment;
  GSinkUInt32 := LCounter.Load;
  LCounter.Free;
end;

var
  LSuite: IBenchSuite;
begin
  WriteLn('Platform: ', BenchmarkPlatformName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32');
  WriteLn('Baselines: plain local variable operations for single-thread overhead context; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  LSuite := TBenchSuite.Create('atomic');
  LSuite.Add('PlainIncrement', @BenchPlainIncrement)
    .Add('AtomicLoadStore32', @BenchAtomicLoadStore32)
    .Add('FetchAdd32', @BenchFetchAdd32)
    .Add('CompareExchange32', @BenchCompareExchange32)
    .Add('TAtomicUInt32', @BenchAtomicUInt32);
  WriteLn(LSuite.Run.PrintToConsole);
end.
