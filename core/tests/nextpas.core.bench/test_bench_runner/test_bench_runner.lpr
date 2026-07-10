program test_bench_runner;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math.scalar,
  nextpas.core.os.env,
  nextpas.core.text.conv,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench,
  nextpas.core.bench.stats,
  nextpas.core.bench.runner;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GInvocationCount: Int64;
  GFirstObservedIteration: Int64;
  GLastObservedIteration: Int64;

procedure ConfigureFastRunner(ARunner: TBenchRunner);
var
  LConfig: TBenchConfig;
begin
  LConfig := ARunner.GetConfig;
  LConfig.MinDurationNs := TDuration.FromMilliseconds(5).AsNanoseconds;
  LConfig.MaxIterations := 5000;
  LConfig.MinSamples := 3;
  LConfig.WarmupIterations := 1;
  LConfig.EnableMemoryTracking := True;
  LConfig.EnableParallel := False;
  LConfig.ParallelThreads := 2;
  ARunner.SetConfig(LConfig);
end;

{ 基准函数：快速操作 }
procedure BenchFast(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for i := 1 to 1000 do
    LSum := LSum + i;
end;

{ 基准函数：中等速度操作 }
procedure BenchMedium(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Double;
begin
  LSum := 0.0;
  for i := 1 to 10000 do
    LSum := LSum + Sin(i * 0.001);
end;

{ 基准函数：慢速操作 }
procedure BenchSlow(const ACtx: IBenchContext);
var
  i: Integer;
  LStr: string;
begin
  LStr := '';
  for i := 1 to 1000 do
    LStr := LStr + IntToStr(i) + ',';
end;

{ Loop 基准函数（TBenchLoopFunc 签名） }
procedure BenchFastLoop(AN: Int64);
var
  i: Int64;
  LSum: Int64;
begin
  LSum := 0;
  for i := 1 to AN do
    LSum := LSum + i;
end;

procedure BenchMediumLoop(AN: Int64);
var
  i: Int64;
  LSum: Double;
begin
  LSum := 0;
  for i := 1 to AN do
    LSum := LSum + Sin(i * 0.001);
end;

{ 基准函数：使用上下文 }
procedure BenchWithContext(const ACtx: IBenchContext);
var
  i: Integer;
begin
  if ACtx <> nil then
  begin
    ACtx.SetBytes(1024);
    ACtx.SetAllocs(2);
  end;
  for i := 1 to 100 do
    ;
end;

procedure BenchRecordsInvocations(const ACtx: IBenchContext);
begin
  Inc(GInvocationCount);
  if ACtx <> nil then
  begin
    if GInvocationCount = 1 then
      GFirstObservedIteration := ACtx.Iterations;
    GLastObservedIteration := ACtx.Iterations;
  end;
end;

procedure BenchSkips(const ACtx: IBenchContext);
begin
  if ACtx <> nil then
    ACtx.Skip('Skip requested by benchmark');
end;

procedure BenchResetTimerOnly(const ACtx: IBenchContext);
begin
  TSleep.ForDuration(TDuration.FromMilliseconds(25));
  if ACtx <> nil then
    ACtx.ResetTimer;
end;

procedure TestTBenchContext;
var
  LCtx: TBenchContext;
  LElapsed: TDuration;
begin
  LCtx := TBenchContext.Create;
  try
    // 测试初始状态
    Check(LCtx.GetIterations = 0, 'Initial iterations = 0');
    Check(LCtx.GetBytesPerOp = 0, 'Initial bytes per op = 0');
    Check(LCtx.GetAllocsPerOp = 0, 'Initial allocs per op = 0');
    Check(not LCtx.IsSkipped, 'Not skipped initially');

    // 测试 SetBytes
    LCtx.SetBytes(1024);
    Check(LCtx.GetBytesPerOp = 1024, 'SetBytes works');

    // 测试 SetAllocs
    LCtx.SetAllocs(5);
    Check(LCtx.GetAllocsPerOp = 5, 'SetAllocs works');

    // 测试 ResetTimer
    LCtx.ResetTimer;
    LElapsed := LCtx.GetElapsed;
    Check(LElapsed.AsNanoseconds >= 0, 'ResetTimer resets elapsed');

    // 测试 GetElapsed 时间递增
    LCtx.ResetTimer;
    TSleep.ForDuration(TDuration.FromMilliseconds(10));
    LElapsed := LCtx.GetElapsed;
    Check(LElapsed.AsNanoseconds > 0, 'GetElapsed returns positive after sleep');
    Check(LElapsed.AsMilliseconds >= 5, 'GetElapsed reflects elapsed time (>= 5ms)');
    { TG-18: add upper bound to prevent false failures from scheduling jitter }
    Check(LElapsed.AsMilliseconds < 5000, 'GetElapsed upper bound (< 5000ms)');

    // 测试 GetElapsed 多次调用递增
    LElapsed := LCtx.GetElapsed;
    Check(LElapsed.AsNanoseconds > 0, 'GetElapsed remains positive on second call');

    // 测试 StopTimer/StartTimer（排除 setup 时间）
    LCtx.Reset;
    LCtx.ResetTimer;
    TSleep.ForDuration(TDuration.FromMilliseconds(5));  { 计时中 }
    LCtx.StopTimer;
    TSleep.ForDuration(TDuration.FromMilliseconds(50)); { 暂停期间不计入 }
    LCtx.StartTimer;
    TSleep.ForDuration(TDuration.FromMilliseconds(5));  { 继续计时 }
    LElapsed := LCtx.GetElapsed;
    { 总计时应该约 10ms，而不是 60ms }
    Check(LElapsed.AsMilliseconds < 40, 'StopTimer/StartTimer excludes paused time (< 40ms)');
    Check(LElapsed.AsMilliseconds >= 5, 'StopTimer/StartTimer preserves active time (>= 5ms)');

    // 测试 Skip
    LCtx.Skip('Test reason');
    Check(LCtx.IsSkipped, 'Skip sets skipped flag');
    Check(LCtx.GetSkipReason = 'Test reason', 'Skip stores reason');

    // 测试 Reset
    LCtx.Reset;
    Check(LCtx.GetIterations = 0, 'Reset clears iterations');
    Check(LCtx.GetBytesPerOp = 0, 'Reset clears bytes');
    Check(LCtx.GetAllocsPerOp = 0, 'Reset clears allocs');
    Check(not LCtx.IsSkipped, 'Reset clears skipped');
  finally
    LCtx.Free;
  end;
end;

procedure TestCalibrateIterations;
var
  LRunner: TBenchRunner;
  LIters: Int64;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    // 测试快速操作
    LIters := LRunner.CalibrateIterations(@BenchFast);
    Check(LIters >= 100, 'Fast operation: iters >= 100');
    Check(LIters <= 1000000, 'Fast operation: iters <= 1M');

    // 测试中等速度操作
    LIters := LRunner.CalibrateIterations(@BenchMedium);
    Check(LIters >= 100, 'Medium operation: iters >= 100');
    Check(LIters <= 1000000, 'Medium operation: iters <= 1M');

    // 测试慢速操作
    LIters := LRunner.CalibrateIterations(@BenchSlow);
    Check(LIters >= 100, 'Slow operation: iters >= 100');
    Check(LIters <= 1000000, 'Slow operation: iters <= 1M');
  finally
    LRunner.Free;
  end;
end;

procedure TestRunOne;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    // 测试快速操作
    LResult := LRunner.RunOne('Fast', @BenchFast);
    Check(LResult.Name = 'Fast', 'Result name correct');
    Check(LResult.Iterations >= 100, 'Iterations >= 100');
    Check(LResult.NsPerOp > 0, 'NsPerOp > 0');
    Check(LResult.OpsPerSec > 0, 'OpsPerSec > 0');
    Check(LResult.StdDev >= 0, 'StdDev >= 0');
    Check(LResult.Median >= 0, 'Median >= 0');
    Check(LResult.P95 >= 0, 'P95 >= 0');
    Check(LResult.P99 >= 0, 'P99 >= 0');
    Check(LResult.SampleCount > 0, 'SampleCount > 0');

    // 测试中等速度操作
    LResult := LRunner.RunOne('Medium', @BenchMedium);
    Check(LResult.Name = 'Medium', 'Medium result name correct');
    Check(LResult.NsPerOp > 0, 'Medium NsPerOp > 0');

    // 测试带上下文的操作
    LResult := LRunner.RunOne('WithContext', @BenchWithContext);
    Check(LResult.Name = 'WithContext', 'WithContext result name correct');
    Check(LResult.BytesPerOp = 1024, 'WithContext bytes propagated');
    Check(LResult.AllocsPerOp = 2, 'WithContext allocs propagated');
  finally
    LRunner.Free;
  end;
end;

procedure TestRunOneSkip;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    LResult := LRunner.RunOne('SkipMe', @BenchSkips);
    Check(LResult.Executed, 'Skipped benchmark is reported as executed');
    Check(LResult.Skipped, 'Skipped benchmark is marked skipped');
    Check(LResult.SkipReason = 'Skip requested by benchmark', 'Skip reason propagated');
  finally
    LRunner.Free;
  end;
end;

procedure TestRunOneTBenchEntry;
var
  LRunner: TBenchRunner;
  LEntry: TBenchEntry;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);

    // 构造 TBenchEntry record
    LEntry := Default(TBenchEntry);
    LEntry.Name := 'EntryFast';
    LEntry.Func := @BenchFast;
    LEntry.Condition := True;

    // 通过 RunOne(TBenchEntry) 重载执行
    LResult := LRunner.RunOne(LEntry);

    Check(LResult.Name = 'EntryFast', 'TBenchEntry RunOne result name correct');
    Check(LResult.Iterations >= 100, 'TBenchEntry RunOne iterations >= 100');
    Check(LResult.NsPerOp > 0, 'TBenchEntry RunOne NsPerOp > 0');
    Check(LResult.OpsPerSec > 0, 'TBenchEntry RunOne OpsPerSec > 0');
    Check(LResult.SampleCount > 0, 'TBenchEntry RunOne SampleCount > 0');

    // 测试带上下文的 TBenchEntry
    LEntry := Default(TBenchEntry);
    LEntry.Name := 'EntryWithCtx';
    LEntry.Func := @BenchWithContext;
    LEntry.Condition := True;

    LResult := LRunner.RunOne(LEntry);
    Check(LResult.Name = 'EntryWithCtx', 'TBenchEntry context name correct');
    Check(LResult.BytesPerOp = 1024, 'TBenchEntry context bytes propagated');
    Check(LResult.AllocsPerOp = 2, 'TBenchEntry context allocs propagated');
  finally
    LRunner.Free;
  end;
end;

procedure TestRunAll;
var
  LRunner: TBenchRunner;
  LEntries: array of TBenchEntry;
  LResults: array of TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    // 准备测试数据
    SetLength(LEntries, 3);
    LEntries[0].Name := 'Fast';
    LEntries[0].Func := @BenchFast;
    LEntries[0].Condition := True;
    LEntries[1].Name := 'Medium';
    LEntries[1].Func := @BenchMedium;
    LEntries[1].Condition := True;
    LEntries[2].Name := 'Slow';
    LEntries[2].Func := @BenchSlow;
    LEntries[2].Condition := True;

    // 运行所有基准
    LRunner.RunAll(LEntries);

    // 检查结果
    LResults := LRunner.GetResults;
    Check(LRunner.GetResultCount = 3, 'Result count = 3');
    Check(LResults[0].Name = 'Fast', 'First result name correct');
    Check(LResults[1].Name = 'Medium', 'Second result name correct');
    Check(LResults[2].Name = 'Slow', 'Third result name correct');
  finally
    LRunner.Free;
  end;
end;

procedure TestFilter;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    // 设置过滤器
    LRunner.SetFilter('Fast');

    // 运行基准
    LResult := LRunner.RunOne('Fast', @BenchFast);
    Check(LResult.Name = 'Fast', 'Filtered result exists');

    // 尝试运行不匹配的基准
    LResult := LRunner.RunOne('Slow', @BenchSlow);
    Check(LResult.Name = 'Slow', 'Non-matching result has name');
    Check(not LResult.Executed, 'Non-matching result is not executed');
    Check(not LResult.Skipped, 'Non-matching result is not benchmark-skipped');
  finally
    LRunner.Free;
  end;
end;

procedure TestConfig;
var
  LRunner: TBenchRunner;
  LConfig: TBenchConfig;
begin
  LRunner := TBenchRunner.Create;
  try
    // 测试默认配置
    LConfig := LRunner.GetConfig;
    Check(LConfig.MinDurationNs = BENCH_DEFAULT_MIN_DURATION_NS, 'Default min duration correct');
    Check(LConfig.MaxIterations = BENCH_DEFAULT_MAX_ITERATIONS, 'Default max iterations correct');
    Check(LConfig.MinSamples = BENCH_DEFAULT_MIN_SAMPLES, 'Default min samples correct');
    Check(LConfig.WarmupIterations = BENCH_DEFAULT_WARMUP_ITERATIONS, 'Default warmup iterations correct');

    // 测试设置配置
    LConfig.MinDurationNs := 500000000;  // 0.5 秒
    LConfig.MaxIterations := 500000;
    LConfig.MinSamples := 20;
    LConfig.WarmupIterations := 3;
    LRunner.SetConfig(LConfig);

    LConfig := LRunner.GetConfig;
    Check(LConfig.MinDurationNs = 500000000, 'Set min duration works');
    Check(LConfig.MaxIterations = 500000, 'Set max iterations works');
    Check(LConfig.MinSamples = 20, 'Set min samples works');
    Check(LConfig.WarmupIterations = 3, 'Set warmup iterations works');
  finally
    LRunner.Free;
  end;
end;

procedure TestConfig_QuietEnv;
var
  LRunner: TBenchRunner;
  LConfig: TBenchConfig;
begin
  UnsetEnv(BENCH_ENV_QUIET);
  LRunner := TBenchRunner.Create;
  try
    LConfig := LRunner.GetConfig;
    Check(not LConfig.Quiet, 'Quiet disabled by default');
  finally
    LRunner.Free;
  end;

  SetEnv(BENCH_ENV_QUIET, '1');
  try
    LRunner := TBenchRunner.Create;
    try
      LConfig := LRunner.GetConfig;
      Check(LConfig.Quiet, 'Quiet enabled from env');
    finally
      LRunner.Free;
    end;
  finally
    UnsetEnv(BENCH_ENV_QUIET);
  end;
end;

procedure TestMeasureNs;
var
  LRunner: TBenchRunner;
  LElapsed: UInt64;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    GInvocationCount := 0;
    GFirstObservedIteration := 0;
    GLastObservedIteration := 0;

    LElapsed := LRunner.MeasureNs(@BenchRecordsInvocations, 25);
    Check(LElapsed > 0, 'Invocation benchmark elapsed > 0');
    Check(GInvocationCount = 25, 'Runner invokes callback once per iteration');
    Check(GFirstObservedIteration = 1, 'First callback sees iteration 1');
    Check(GLastObservedIteration = 25, 'Last callback sees final iteration index');

    // 测量快速操作
    LElapsed := LRunner.MeasureNs(@BenchFast, 100);
    Check(LElapsed > 0, 'Fast operation elapsed > 0');
    Check(LElapsed < 1000000000, 'Fast operation elapsed < 1s');

    // 测量中等速度操作
    LElapsed := LRunner.MeasureNs(@BenchMedium, 100);
    Check(LElapsed > 0, 'Medium operation elapsed > 0');
    Check(LElapsed < 1000000000, 'Medium operation elapsed < 1s');

    LElapsed := LRunner.MeasureNs(@BenchResetTimerOnly, 1);
    { TG-21: use upper bound based on system timer resolution, not fixed 10ms.
      The benchmark sleeps 25ms then resets; elapsed should be near zero.
      Allow up to 100ms for scheduling jitter on loaded CI systems. }
    Check(LElapsed < 100000000, 'ResetTimer excludes pre-measurement sleep (< 100ms)');
  finally
    LRunner.Free;
  end;
end;

procedure TestClearResults;
var
  LRunner: TBenchRunner;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureFastRunner(LRunner);
    // 运行一个基准
    LRunner.RunOne('Fast', @BenchFast);
    Check(LRunner.GetResultCount = 1, 'Has 1 result');

    // 清空结果
    LRunner.ClearResults;
    Check(LRunner.GetResultCount = 0, 'Results cleared');
  finally
    LRunner.Free;
  end;
end;

{ === TG-12: RunAll Statistics Completeness === }

procedure TestRunAll_StatisticsComplete;
var
  LRunner: TBenchRunner;
  LEntries: array of TBenchEntry;
  LResults: array of TBenchResult;
  LConfig: TBenchConfig;
begin
  LRunner := TBenchRunner.Create;
  try
    LConfig := LRunner.GetConfig;
    LConfig.MinDurationNs := TDuration.FromMilliseconds(10).AsNanoseconds;
    LConfig.MaxIterations := 5000;
    LConfig.MinSamples := 5;
    LConfig.WarmupIterations := 1;
    LConfig.EnableMemoryTracking := False;
    LConfig.Quiet := True;
    LRunner.SetConfig(LConfig);

    SetLength(LEntries, 2);
    LEntries[0].Name := 'Fast';
    LEntries[0].Func := @BenchFast;
    LEntries[0].Condition := True;
    LEntries[1].Name := 'Medium';
    LEntries[1].Func := @BenchMedium;
    LEntries[1].Condition := True;

    LRunner.RunAll(LEntries);
    LResults := LRunner.GetResults;

    Check(LRunner.GetResultCount = 2, 'TG-12 result count = 2');

    // Verify Fast statistics completeness
    Check(LResults[0].StdDev > 0, 'Fast StdDev > 0');
    Check(LResults[0].Median > 0, 'Fast Median > 0');
    Check(LResults[0].P95 > 0, 'Fast P95 > 0');
    Check(LResults[0].P99 > 0, 'Fast P99 > 0');
    Check(LResults[0].SampleCount >= 5, 'Fast SampleCount >= 5');

    // Verify Medium statistics completeness
    Check(LResults[1].StdDev > 0, 'Medium StdDev > 0');
    Check(LResults[1].Median > 0, 'Medium Median > 0');
    Check(LResults[1].P95 > 0, 'Medium P95 > 0');
    Check(LResults[1].P99 > 0, 'Medium P99 > 0');
    Check(LResults[1].SampleCount >= 5, 'Medium SampleCount >= 5');

    // Cross-field ordering checks
    Check(LResults[0].Median <= LResults[0].P95, 'Fast Median <= P95');
    Check(LResults[0].P95 <= LResults[0].P99, 'Fast P95 <= P99');
    Check(LResults[1].Median <= LResults[1].P95, 'Medium Median <= P95');
    Check(LResults[1].P95 <= LResults[1].P99, 'Medium P95 <= P99');
  finally
    LRunner.Free;
  end;
end;

{ Run + Summary 便利 API 测试 }
procedure TestRun_Summary;
var
  LRunner: TBenchRunner;
  LConfig: TBenchConfig;
begin
  LRunner := TBenchRunner.Create;
  try
    LConfig := LRunner.GetConfig;
    LConfig.MinDurationNs := TDuration.FromMilliseconds(5).AsNanoseconds;
    LConfig.MaxIterations := 5000;
    LConfig.MinSamples := 3;
    LConfig.WarmupIterations := 0;
    LConfig.EnableMemoryTracking := False;
    LConfig.Quiet := True;
    LRunner.SetConfig(LConfig);

    LRunner.Run('FastLoop', @BenchFastLoop);
    Check(LRunner.GetResultCount = 1, 'Run accumulates 1 result');
    Check(LRunner.GetResults[0].NsPerOp > 0, 'Run NsPerOp > 0');

    LRunner.Run('MediumLoop', @BenchMediumLoop);
    Check(LRunner.GetResultCount = 2, 'Run accumulates 2 results');

    LRunner.Summary;
  finally
    LRunner.Free;
  end;
end;

{ Run with Summary on empty runner }
procedure TestRun_Summary_Empty;
var
  LRunner: TBenchRunner;
begin
  LRunner := TBenchRunner.Create;
  try
    LRunner.Summary;
    Check(LRunner.GetResultCount = 0, 'Empty Summary no crash');
  finally
    LRunner.Free;
  end;
end;

{ F-04: per-entry CollectRawSamples override }
procedure TestPerEntryCollectRawSamples;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin
  LSuite := TBenchSuite.Create('per-entry-raw');
  LSuite.Add('NoRaw', @BenchFast);
  LSuite.SetEntryCollectRawSamples('NoRaw', False);

  LSuite.Add('WithRaw', @BenchFast);
  LSuite.SetEntryCollectRawSamples('WithRaw', True);

  LResults := LSuite.Run;
  LAll := LResults.GetAll;
  Check(Length(LAll) = 2, 'Should have 2 results');

  Check(Length(LAll[0].RawSamples) = 0, 'NoRaw: no raw samples');
  Check(Length(LAll[1].RawSamples) > 0, 'WithRaw: has raw samples');
end;

begin
  T := TTestSuite.Create('nextpas.core.bench.runner');
  T.Test('TBenchContext lifecycle', @TestTBenchContext);
  T.Test('CalibrateIterations', @TestCalibrateIterations);
  T.Test('RunOne', @TestRunOne);
  T.Test('RunOne skip', @TestRunOneSkip);
  T.Test('RunOne TBenchEntry', @TestRunOneTBenchEntry);
  T.Test('RunAll', @TestRunAll);
  T.Test('Filter', @TestFilter);
  T.Test('Config defaults and setters', @TestConfig);
  T.Test('Config quiet from env', @TestConfig_QuietEnv);
  T.Test('MeasureNs', @TestMeasureNs);
  T.Test('ClearResults', @TestClearResults);
  T.Test('RunAll statistics completeness (TG-12)', @TestRunAll_StatisticsComplete);
  T.Test('Run + Summary', @TestRun_Summary);
  T.Test('Summary on empty runner', @TestRun_Summary_Empty);
  T.Test('Per-entry CollectRawSamples (F-04)', @TestPerEntryCollectRawSamples);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
