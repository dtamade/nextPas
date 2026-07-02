program test_bench_parallel_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.bench,
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

var
  T: TTestSuite;
begin
  GParallelLock := TMutex.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.parallel.heaptrc');
    T.Test('parallel observed concurrency', @TestParallelObserved);
    T.Run;
    T.Summary;

    if not T.AllPassed then
      Halt(1);
  finally
    GParallelLock.Free;
  end;
end.
