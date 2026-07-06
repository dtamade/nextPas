program test_bench_parallel_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.test;

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

procedure BenchSimple(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for I := 1 to 100 do
    LSum := LSum + I;
end;

procedure BenchWithContext(const ACtx: IBenchContext);
begin
  if ACtx <> nil then
  begin
    ACtx.SetBytes(64);
    ACtx.SetAllocs(1);
  end;
end;

{ Test 1: parallel observed concurrency (original) }
procedure TestParallelObserved;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GActiveParallelCalls := 0;
  GMaxParallelCalls := 0;

  LSuite := TBenchSuite.Create('ParallelLeakCheck')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(32)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('ParallelObserved', @BenchParallelObserved, 4);

  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'Expected 1 benchmark result');
  Check(GMaxParallelCalls > 1, 'Expected concurrent parallel calls > 1');

  LResults := nil;
  LSuite := nil;
end;

{ Test 2: parallel no memory leak (heaptrc auto-detects) }
procedure TestParallelNoLeak;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('ParallelNoLeak')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('Simple', @BenchSimple, 2);

  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'NoLeak: 1 result');
  Check(LResults.GetByName('Simple').NsPerOp > 0, 'NoLeak: NsPerOp > 0');

  LResults := nil;
  LSuite := nil;
end;

{ Test 3: mixed serial + parallel entries }
procedure TestMixedEntries;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('Mixed')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.Add('Serial', @BenchSimple);
  LSuite.AddParallel('Parallel', @BenchSimple, 2);

  LResults := LSuite.Run;
  Check(LResults.Count = 2, 'Mixed: 2 results');
  Check(LResults.GetByName('Serial').NsPerOp > 0, 'Mixed: Serial NsPerOp > 0');
  Check(LResults.GetByName('Parallel').NsPerOp > 0, 'Mixed: Parallel NsPerOp > 0');

  LResults := nil;
  LSuite := nil;
end;

{ Test 4: parallel with context (bytes/allocs propagated) }
procedure TestParallelWithContext;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: nextpas.core.bench.base.TBenchResult;
begin
  LSuite := TBenchSuite.Create('ParallelCtx')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('WithCtx', @BenchWithContext, 2);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('WithCtx');
  Check(LResult.BytesPerOp = 64, 'ParallelCtx: BytesPerOp = 64');
  Check(LResult.AllocsPerOp = 1, 'ParallelCtx: AllocsPerOp = 1');

  LResults := nil;
  LSuite := nil;
end;

{ Test 5: parallel with one thread (equivalent to serial) }
procedure TestParallelOneThread;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('ParallelOne')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1);
  LSuite.AddParallel('OneThread', @BenchSimple, 1);

  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'OneThread: 1 result');
  Check(LResults.GetByName('OneThread').NsPerOp > 0, 'OneThread: NsPerOp > 0');

  LResults := nil;
  LSuite := nil;
end;

var
  T: TTestSuite;
begin
  GParallelLock := TMutex.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.parallel.heaptrc');
    T.Test('parallel observed concurrency', @TestParallelObserved);
    T.Test('parallel no leak', @TestParallelNoLeak);
    T.Test('mixed serial + parallel entries', @TestMixedEntries);
    T.Test('parallel with context', @TestParallelWithContext);
    T.Test('parallel one thread', @TestParallelOneThread);
    T.Run;
    T.Summary;

    if not T.AllPassed then
      Halt(1);
  finally
    GParallelLock.Free;
  end;
end.
