program test_bench_parallel_memtrack_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.test,
  nextpas.core.bench;

var
  GParallelLock: TMutex;
  GActiveParallelCalls: Integer;
  GMaxParallelCalls: Integer;

procedure BenchParallelObserved(const ACtx: IBenchContext);
begin
  GParallelLock.Acquire;
  try
    Inc(GActiveParallelCalls);
    if GActiveParallelCalls > GMaxParallelCalls then
      GMaxParallelCalls := GActiveParallelCalls;
  finally
    GParallelLock.Release;
  end;

  TSleep.ForDuration(TDuration.FromMilliseconds(1));

  GParallelLock.Acquire;
  try
    Dec(GActiveParallelCalls);
  finally
    GParallelLock.Release;
  end;
end;

procedure BenchAllocatesMemory(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GetMem(64);
  try
    PByte(LPtr)^ := 42;
  finally
    FreeMem(LPtr);
  end;
end;

procedure TestParallelObserved;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GMaxParallelCalls := 0;
  GActiveParallelCalls := 0;

  LSuite := TBenchSuite.Create('ParallelFirst')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(32)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('ParallelObserved', @BenchParallelObserved, 4);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'expected exactly 1 benchmark result');
  CheckTrue(GMaxParallelCalls > 1, 'expected parallel calls > 1');
end;

procedure TestMemtrackAllocOneBlock;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('MemtrackSecond')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking;
  LSuite.Add('AllocOneBlock', @BenchAllocatesMemory);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'expected exactly 1 benchmark result');
  Check(LResults.GetByName('AllocOneBlock').AllocsPerOp >= 1,
    'expected AllocsPerOp >= 1');
end;

var
  T: TTestSuite;
begin
  GParallelLock := TMutex.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.parallel.memtrack.heaptrc');
    T.Test('parallel observed', @TestParallelObserved);
    T.Test('memtrack alloc one block', @TestMemtrackAllocOneBlock);
    T.Run;
    T.Summary;
  finally
    GParallelLock.Free;
  end;
end.
