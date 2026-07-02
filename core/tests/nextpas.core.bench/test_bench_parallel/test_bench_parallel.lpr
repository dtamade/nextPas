program test_bench_parallel;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.text.conv,
  nextpas.core.sync.mutex,
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.parallel;

var
  GCounter: Integer = 0;
  GCounterLock: TMutex;

{ Test benchmark functions }

procedure BenchSimple(AThreadId: Integer; AIterations: Int64);
var
  I: Int64;
  LSum: Int64;
begin
  LSum := 0;
  for I := 1 to AIterations do
    Inc(LSum, I);
end;

procedure BenchSharedCounter(AThreadId: Integer; AIterations: Int64);
var
  I: Int64;
begin
  for I := 1 to AIterations do
  begin
    GCounterLock.Acquire;
    try
      Inc(GCounter);
    finally
      GCounterLock.Release;
    end;
  end;
end;

{ === TParallelBenchmark Tests === }

procedure Test_Create;
var
  LBench: TParallelBenchmark;
  LResult: TParallelBenchResult;
begin
  LBench := TParallelBenchmark.Create(@BenchSimple, 4, 1000, 100);
  { Create 应初始化配置 — 通过 Execute 后的 Config 验证 }
  LResult := LBench.Execute;
  Check(LResult.Config.ThreadCount = 4, 'Create: ThreadCount = 4');
  Check(LResult.Config.IterationsPerThread = 1000, 'Create: IterationsPerThread = 1000');
  Check(LResult.Config.WarmupIterations = 100, 'Create: WarmupIterations = 100');
  Check(LResult.TotalNs > 0, 'Create: TotalNs > 0 after Execute');
end;

procedure Test_Execute_Simple;
var
  LResult: TParallelBenchResult;
begin
  LResult := RunParallelBench(@BenchSimple, 2, 10000);

  Check(LResult.Config.ThreadCount = 2, 'ThreadCount = 2');
  Check(LResult.Config.IterationsPerThread = 10000, 'IterationsPerThread = 10000');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
  Check(LResult.NsPerOp > 0, 'NsPerOp > 0');
  Check(LResult.OpsPerSec > 0, 'OpsPerSec > 0');
  Check(Length(LResult.ThreadResults) = 2, 'ThreadResults count = 2');
end;

procedure Test_Execute_ThreadResults;
var
  LResult: TParallelBenchResult;
  I: Integer;
begin
  LResult := RunParallelBench(@BenchSimple, 3, 5000);

  Check(Length(LResult.ThreadResults) = 3, 'ThreadResults count = 3');

  for I := 0 to High(LResult.ThreadResults) do
  begin
    Check(LResult.ThreadResults[I].ThreadId = I, 'ThreadId = ' + nextpas.core.text.conv.IntToStr(I));
    Check(LResult.ThreadResults[I].Iterations = 5000, 'Iterations = 5000');
    // ElapsedNs might be 0 if execution is too fast for timer resolution
    Check(LResult.ThreadResults[I].ElapsedNs >= 0, 'ElapsedNs >= 0');
    Check(LResult.ThreadResults[I].NsPerOp >= 0, 'NsPerOp >= 0');
  end;
end;

procedure Test_Execute_Speedup;
var
  LResult1: TParallelBenchResult;
  LResult2: TParallelBenchResult;
begin
  LResult1 := RunParallelBench(@BenchSimple, 1, 100000);
  LResult2 := RunParallelBench(@BenchSimple, 2, 100000);

  // TG-28: tighter range assertions for speedup
  Check(LResult2.Speedup >= 0, 'Speedup >= 0');
  Check(LResult2.Speedup <= LResult2.Config.ThreadCount * 2.0, 'Speedup <= 2x thread count');
  Check(LResult2.Efficiency >= 0, 'Efficiency >= 0');
end;

procedure Test_Execute_SharedCounter;
var
  LResult: TParallelBenchResult;
begin
  GCounter := 0;
  LResult := RunParallelBench(@BenchSharedCounter, 4, 10000);

  // With more iterations and proper locking, we should see the expected count
  // Default warmup = 1000, so total = 4 threads x (10000 + 1000 warmup) = 44000
  Check(GCounter = 44000, 'Counter = 44000 (4 threads x 11000 including warmup)');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
end;

procedure Test_Execute_Warmup;
var
  LResult: TParallelBenchResult;
  I: Integer;
begin
  LResult := RunParallelBench(@BenchSimple, 2, 10000);

  Check(LResult.TotalNs > 0, 'Warmup: TotalNs > 0');
  Check(Length(LResult.ThreadResults) = 2, 'Warmup: 2 thread results');
  for I := 0 to High(LResult.ThreadResults) do
  begin
    Check(LResult.ThreadResults[I].Iterations = 10000,
      'Warmup: thread ' + nextpas.core.text.conv.IntToStr(I) + ' iterations = 10000');
    Check(LResult.ThreadResults[I].ThreadId = I,
      'Warmup: thread ' + nextpas.core.text.conv.IntToStr(I) + ' ThreadId correct');
  end;
end;

procedure Test_Execute_ZeroIterations;
var
  LResult: TParallelBenchResult;
begin
  LResult := RunParallelBench(@BenchSimple, 2, 0);

  Check(LResult.TotalNs >= 0, 'TotalNs >= 0');
  Check(LResult.NsPerOp = 0, 'NsPerOp = 0');
  Check(LResult.OpsPerSec = 0, 'OpsPerSec = 0');
end;

procedure Test_Execute_SingleThread;
var
  LResult: TParallelBenchResult;
begin
  LResult := RunParallelBench(@BenchSimple, 1, 10000);

  Check(LResult.Config.ThreadCount = 1, 'ThreadCount = 1');
  Check(Length(LResult.ThreadResults) = 1, 'ThreadResults count = 1');
  Check(LResult.Speedup >= 0, 'Speedup >= 0');
  Check(LResult.Efficiency >= 0, 'Efficiency >= 0');
end;

procedure Test_Execute_ManyThreads;
var
  LResult: TParallelBenchResult;
begin
  LResult := RunParallelBench(@BenchSimple, 8, 1000);

  Check(LResult.Config.ThreadCount = 8, 'ThreadCount = 8');
  Check(Length(LResult.ThreadResults) = 8, 'ThreadResults count = 8');
  Check(LResult.TotalNs > 0, 'TotalNs > 0');
end;

procedure Test_Execute_HeavyWorkload;
var
  LResult: TParallelBenchResult;
  I: Integer;
  LTotalIterations: Int64;
begin
  LResult := RunParallelBench(@BenchSimple, 4, 100000);

  Check(LResult.TotalNs > 0, 'HeavyWorkload: TotalNs > 0');
  Check(LResult.NsPerOp > 0, 'HeavyWorkload: NsPerOp > 0');
  Check(LResult.OpsPerSec > 0, 'HeavyWorkload: OpsPerSec > 0');
  Check(Length(LResult.ThreadResults) = 4, 'HeavyWorkload: 4 thread results');

  { 验证所有线程的迭代次数总和 }
  LTotalIterations := 0;
  for I := 0 to High(LResult.ThreadResults) do
  begin
    Check(LResult.ThreadResults[I].Iterations = 100000,
      'HeavyWorkload: thread ' + nextpas.core.text.conv.IntToStr(I) + ' iterations = 100000');
    Inc(LTotalIterations, LResult.ThreadResults[I].Iterations);
  end;
  Check(LTotalIterations = 4 * 100000, 'HeavyWorkload: total iterations = 400000');
end;

procedure Test_GetResults;
var
  LBench: TParallelBenchmark;
  LExecResult, LStoredResult: TParallelBenchResult;
begin
  LBench := TParallelBenchmark.Create(@BenchSimple, 2, 100, 1);
  LExecResult := LBench.Execute;
  LStoredResult := LBench.GetResults;
  Check(LStoredResult.TotalNs = LExecResult.TotalNs, 'GetResults matches Execute TotalNs');
  Check(LStoredResult.NsPerOp = LExecResult.NsPerOp, 'GetResults matches Execute NsPerOp');
  Check(LStoredResult.Config.ThreadCount = 2, 'GetResults ThreadCount = 2');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.parallel');

  GCounterLock := TMutex.Create;

  T.Test('Create', @Test_Create);
  T.Test('ExecuteSimple', @Test_Execute_Simple);
  T.Test('ExecuteThreadResults', @Test_Execute_ThreadResults);
  T.Test('ExecuteSpeedup', @Test_Execute_Speedup);
  T.Test('ExecuteSharedCounter', @Test_Execute_SharedCounter);
  T.Test('ExecuteWarmup', @Test_Execute_Warmup);
  T.Test('ExecuteZeroIterations', @Test_Execute_ZeroIterations);
  T.Test('ExecuteSingleThread', @Test_Execute_SingleThread);
  T.Test('ExecuteManyThreads', @Test_Execute_ManyThreads);
  T.Test('ExecuteHeavyWorkload', @Test_Execute_HeavyWorkload);
  T.Test('GetResults', @Test_GetResults);

  T.Run;
  T.Summary;

  GCounterLock.Free;
end.
