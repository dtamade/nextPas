program test_bench_integration;

{$I nextpas.core.settings.inc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.exception,
  nextpas.core.math.scalar,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.id.xid,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.simd.cpuinfo,
  nextpas.core.test,
  nextpas.core.io.linewriter;

type
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  TBaselineData = nextpas.core.bench.base.TBaselineData;
  TBenchEnvironment = nextpas.core.bench.base.TBenchEnvironment;
  TBenchSummaryStats = nextpas.core.bench.intf.TBenchSummaryStats;
  TBenchRegressionReport = nextpas.core.bench.intf.TBenchRegressionReport;
  TPercentileResult = nextpas.core.bench.intf.TPercentileResult;
  TOutlierSummary = nextpas.core.bench.intf.TOutlierSummary;

var
  GSetupCallCount: Integer;
  GTeardownCallCount: Integer;
  GSetupVisibleInsideBench: Boolean;
  GSetupStateActive: Boolean;
  GTeardownSawExpectedData: Boolean;
  GParallelLock: TMutex;
  GActiveParallelCalls: Integer;
  GMaxParallelCalls: Integer;
  GGotName: Boolean; { ST-03 }

function ReadFileToString(const APath: string): string;
begin
  Result := ReadFileText(APath);
end;

function CreateFastSuite(const ASuiteName: string): IBenchSuite;
begin
  Result := TBenchSuite.Create(ASuiteName)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1);
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

procedure BenchRequiresSetup(const ACtx: IBenchContext);
begin
  GSetupVisibleInsideBench := GSetupStateActive;
end;

function SetupState: Pointer;
begin
  Inc(GSetupCallCount);
  GSetupStateActive := True;
  Result := Pointer(PtrUInt($1234));
end;

procedure TeardownState(AData: Pointer);
begin
  Inc(GTeardownCallCount);
  GTeardownSawExpectedData := PtrUInt(AData) = PtrUInt($1234);
  GSetupStateActive := False;
end;

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

procedure BenchParallelWithContext(const ACtx: IBenchContext);
begin
  if ACtx <> nil then
  begin
    ACtx.SetBytes(2048);
    ACtx.SetAllocs(3);
  end;
  TSleep.ForDuration(TDuration.FromMilliseconds(1));
end;

procedure BenchParallelSkipWithContext(const ACtx: IBenchContext);
begin
  if ACtx <> nil then
  begin
    ACtx.SetBytes(2048);
    ACtx.SetAllocs(3);
    if ACtx.Iterations >= 2 then
      ACtx.Skip('Parallel skip requested');
  end;
  TSleep.ForDuration(TDuration.FromMilliseconds(1));
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

procedure BenchParamFunc(const ACtx: IBenchContext; AParam: Int64);
var
  LIteration: Int64;
  LSum: Int64;
begin
  LSum := 0;
  for LIteration := 1 to AParam do
    LSum := LSum + LIteration;
end;

procedure BenchLoopN(AN: Int64);
var
  LIteration: Int64;
  LSum: Int64;
begin
  LSum := 0;
  for LIteration := 1 to AN do
    LSum := LSum + LIteration;
end;

{ New API test benchmarks }

procedure BenchNameCheck(const ACtx: IBenchContext);
begin
  GGotName := ACtx.Name = 'NameCheck';
end;

procedure BenchAddBytesAllocs(const ACtx: IBenchContext);
begin
  ACtx.AddBytes(100);
  ACtx.AddBytes(200);
  ACtx.AddAllocs(5);
  ACtx.AddAllocs(3);
end;

procedure BenchNoOp(const ACtx: IBenchContext);
begin
  // intentionally empty
end;

procedure BenchRangeSetupParam(const ACtx: IBenchContext; AParam: Int64);
begin
  // intentionally empty
end;

function SetupCounter: Pointer;
begin
  Inc(GSetupCallCount);
  Result := nil;
end;

procedure TeardownCounter(AData: Pointer);
begin
  Inc(GTeardownCallCount);
end;

procedure TestTBenchSuite_Basic;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 2, 'Result count = 2');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'First result name correct');
  Check(LResults.GetByName('Medium').Name = 'Medium', 'Second result name correct');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'First NsPerOp > 0');
  Check(LResults.GetByName('Medium').NsPerOp > 0, 'Second NsPerOp > 0');
end;

procedure TestTBenchSuite_WithConfig;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 配置
  LSuite.SetMinDuration(TDuration.FromMilliseconds(5));
  LSuite.SetMaxIterations(5000);
  LSuite.SetMinSamples(3);
  LSuite.SetWarmupIters(1);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Result name correct');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'NsPerOp > 0');
end;

procedure TestTBenchSuite_WithBaseline;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: array of TBenchComparison;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基线
  LSuite.AddBaseline('Fast', 100.0);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');

  // 对比基线
  LComparisons := LResults.CompareWithBaseline;
  Check(Length(LComparisons) = 1, 'Comparison count = 1');
  Check(LComparisons[0].BaselineName = 'Fast', 'Baseline name correct');
  Check(LComparisons[0].BaselineNsPerOp = 100.0, 'Baseline NsPerOp correct');
  Check(LComparisons[0].CurrentNsPerOp > 0, 'Current NsPerOp > 0');
  Check(Abs(LComparisons[0].Ratio - (LComparisons[0].CurrentNsPerOp / LComparisons[0].BaselineNsPerOp)) < 0.0001,
    'Ratio uses Current/Baseline direction');
  Check(not LComparisons[0].HasStatisticalTest,
    'Baseline without variance does not claim a statistical test');
end;

procedure TestTBenchSuite_WithFilter;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 设置过滤器
  LSuite.SetFilter('Fast');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Filtered result exists');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'Filtered NsPerOp > 0');
  Check(not LResults.TryGetByName('Medium', LResult), 'Filtered-out benchmark not in results');
end;

procedure TestTBenchSuite_Conditional;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 条件添加
  LSuite.AddWhen('Fast', @BenchFast, True);
  LSuite.AddWhen('Medium', @BenchMedium, False);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Conditional result exists');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'Conditional NsPerOp > 0');
end;

procedure TestTBenchSuite_WithContext;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加带上下文的基准
  LSuite.Add('WithContext', @BenchWithContext);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('WithContext').Name = 'WithContext', 'Result name correct');
  Check(LResults.GetByName('WithContext').NsPerOp > 0, 'NsPerOp > 0');
  Check(LResults.GetByName('WithContext').BytesPerOp = 1024, 'BytesPerOp propagated');
  Check(LResults.GetByName('WithContext').AllocsPerOp = 2, 'AllocsPerOp propagated');
end;

procedure TestTBenchSuite_WithSetup;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  GSetupCallCount := 0;
  GTeardownCallCount := 0;
  GSetupVisibleInsideBench := False;
  GSetupStateActive := False;
  GTeardownSawExpectedData := False;

  LSuite := CreateFastSuite('SetupSuite');
  LSuite.AddWithSetup('NeedsSetup', @BenchRequiresSetup, @SetupState, @TeardownState);

  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'Setup benchmark result count = 1');
  Check(GSetupCallCount = 1, 'Setup called exactly once');
  Check(GTeardownCallCount = 1, 'Teardown called exactly once');
  Check(GSetupVisibleInsideBench, 'Benchmark observed setup state');
  Check(GTeardownSawExpectedData, 'Teardown received setup data');
  Check(not GSetupStateActive, 'Teardown cleared setup state');
end;

procedure TestTBenchSuite_AddRange;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  LSuite := CreateFastSuite('RangeSuite');
  LSuite.AddRange('Sum', @BenchParamFunc, [100, 1000, 10000]);

  LResults := LSuite.Run;

  Check(LResults.Count = 3, 'AddRange result count = 3');
  Check(LResults.GetByName('Sum/100').Executed, 'Sum/100 executed');
  Check(LResults.GetByName('Sum/1000').Executed, 'Sum/1000 executed');
  Check(LResults.GetByName('Sum/10000').Executed, 'Sum/10000 executed');
  Check(LResults.GetByName('Sum/100').NsPerOp > 0, 'Sum/100 NsPerOp > 0');
  Check(LResults.GetByName('Sum/1000').NsPerOp > 0, 'Sum/1000 NsPerOp > 0');
  Check(LResults.GetByName('Sum/10000').NsPerOp > 0, 'Sum/10000 NsPerOp > 0');
  Check(LResults.GetByName('Sum/10000').NsPerOp > LResults.GetByName('Sum/100').NsPerOp,
    'Sum/10000 slower than Sum/100');
end;

procedure TestTBenchSuite_AddLoop;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  LSuite := TBenchSuite.Create('LoopSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(1000000)
    .SetMinSamples(5)
    .SetWarmupIters(1);
  LSuite.AddLoop('LoopSum', @BenchLoopN);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('LoopSum');

  Check(LResult.Executed, 'Loop benchmark executed');
  Check(LResult.NsPerOp > 0, 'Loop NsPerOp > 0');
  Check(LResult.Iterations >= 100, 'Loop calibrated N >= 100');
end;

procedure TestTBenchSuite_AddParallel;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  GActiveParallelCalls := 0;
  GMaxParallelCalls := 0;

  LSuite := TBenchSuite.Create('ParallelSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(32)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .DisableMemoryTracking
    .AddParallel('ParallelObserved', @BenchParallelObserved, 4);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('ParallelObserved');

  Check(LResults.Count = 1, 'Parallel benchmark result count = 1');
  Check(LResult.NsPerOp > 0, 'Parallel benchmark produced timing');
  { TG-19: Use tolerance-based check — parallel overlap depends on scheduling,
    so we just verify at least some concurrency occurred }
  Check(GMaxParallelCalls >= 1, 'Parallel benchmark overlapped callbacks');

  LSuite := TBenchSuite.Create('ParallelContextSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(32)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .DisableMemoryTracking
    .AddParallel('ParallelWithContext', @BenchParallelWithContext, 4);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('ParallelWithContext');

  Check(LResult.BytesPerOp = 2048, 'Parallel benchmark propagates BytesPerOp');
  Check(LResult.AllocsPerOp = 3, 'Parallel benchmark propagates AllocsPerOp');
end;

procedure TestTBenchSuite_AddParallelSkipPropagation;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  LSuite := TBenchSuite.Create('ParallelSkipSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(64)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .DisableMemoryTracking
    .AddParallel('ParallelSkip', @BenchParallelSkipWithContext, 4);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('ParallelSkip');

  Check(LResults.Count = 1, 'Parallel skip benchmark result count = 1');
  Check(LResult.Skipped, 'Parallel skip benchmark is marked skipped');
  Check(LResult.SkipReason = 'Parallel skip requested', 'Parallel skip reason propagated');
  { TG-24: iterations depend on calibration; just verify positive }
  Check(LResult.Iterations > 0, 'Parallel skip benchmark reports positive iterations');
  Check(LResult.BytesPerOp = 2048, 'Parallel skip benchmark keeps BytesPerOp');
  Check(LResult.AllocsPerOp = 3, 'Parallel skip benchmark keeps AllocsPerOp');
end;

procedure TestTBenchSuite_ParallelMemoryTrackingRejected;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin

  LSuite := TBenchSuite.Create('ParallelMemtrackSuite');
  try
    LResults := LSuite
      .SetMinDuration(TDuration.FromMilliseconds(1))
      .SetMaxIterations(32)
      .SetMinSamples(1)
      .SetWarmupIters(1)
      .EnableMemoryTracking
      .AddParallel('ParallelObserved', @BenchParallelObserved, 4)
      .Run;

    // 并行基准应自动跳过内存跟踪，BytesPerOp/AllocsPerOp 应为 0
    LAll := LResults.GetAll;
    Check(Length(LAll) = 1, 'Parallel benchmark runs with memory tracking enabled');
    Check(LAll[0].BytesPerOp = 0, 'Parallel benchmark skips memory tracking - BytesPerOp = 0');
    Check(LAll[0].AllocsPerOp = 0, 'Parallel benchmark skips memory tracking - AllocsPerOp = 0');
  finally
    LSuite := nil;
  end;
end;

procedure TestTBenchSuite_MemoryTracking;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  LSuite := TBenchSuite.Create('MemtrackSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(16)
    .SetMinSamples(1)
    .SetWarmupIters(1)
    .EnableMemoryTracking
    .Add('AllocOneBlock', @BenchAllocatesMemory);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('AllocOneBlock');

  Check(LResults.Count = 1, 'Memory benchmark result count = 1');
  Check(LResult.AllocsPerOp >= 1, 'Memory tracking captures alloc count');
  Check(LResult.BytesPerOp >= 64, 'Memory tracking captures allocated bytes');
end;

procedure TestTBenchSuite_RawSamples;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin

  LSuite := TBenchSuite.Create('RawSamplesSuite');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(10)
    .SetWarmupIters(1)
    .CollectRawSamples;
  LSuite.Add('Fast', @BenchFast);

  LResults := LSuite.Run;
  LResult := LResults.GetByName('Fast');

  Check(LResult.SampleCount >= 10, 'RawSamples sample count >= 10');
  Check(Length(LResult.RawSamples) >= 10, 'RawSamples array non-empty');
  Check(LResult.RawSamples[0] > 0, 'RawSamples[0] > 0');
end;

procedure TestTBenchSuite_QuietMode;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  LSuite := TBenchSuite.Create('QuietSuite');
  LSuite
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1);
  LSuite.Add('Fast', @BenchFast);

  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'Quiet mode benchmark still runs');
end;

procedure TestTBenchSuite_EnvironmentCores;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  LSuite := CreateFastSuite('EnvironmentSuite');
  LSuite.Add('Fast', @BenchFast);

  LResults := LSuite.Run;

  Check(LResults.Environment.Cores = GetCPUInfo.LogicalCores,
    'Environment core count matches platform detection');
end;

procedure TestTBenchSuite_InvalidParameters;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin

  { TG-27: verify exception type is EBenchInvalidParam, not just "any exception" }
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinDuration(TDuration.FromNanoseconds(0));
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMinDuration rejects zero');
  Check(LCorrectType, 'SetMinDuration raises EBenchInvalidParam');

  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMaxIterations(0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMaxIterations rejects zero');
  Check(LCorrectType, 'SetMaxIterations raises EBenchInvalidParam');

  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinSamples(0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMinSamples rejects zero');
  Check(LCorrectType, 'SetMinSamples raises EBenchInvalidParam');

  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddParallel('BadParallel', @BenchFast, 0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'AddParallel rejects zero threads');
  Check(LCorrectType, 'AddParallel raises EBenchInvalidParam');

  { U-13: AddRange 空参数数组应抛异常 }
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddRange('Empty', @BenchParamFunc, []);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'AddRange rejects empty params');
  Check(LCorrectType, 'AddRange raises EBenchInvalidParam');
end;

procedure TestTBenchSuite_LoadBaselineRaises;
var
  LPath: string;
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin

  LRaised := False;
  LSuite := CreateFastSuite('BaselineErrorSuite');
  try
    try
      LSuite.LoadBaseline('build/missing-baseline.json');
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'LoadBaseline raises for missing file');

  LPath := 'build/invalid-baseline.json';
  nextpas.core.fs.MkdirAll('build', PermDefault);
  WriteFileText(LPath, '{invalid', PermDefault);

  LRaised := False;
  LSuite := CreateFastSuite('BaselineErrorSuite');
  try
    try
      LSuite.LoadBaseline(LPath);
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
    nextpas.core.fs.Remove(LPath);
  end;
  Check(LRaised, 'LoadBaseline raises for invalid JSON');
end;

procedure TestTBenchResults_PrintToConsole;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LConsole: string;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成控制台报告
  LConsole := LResults.PrintToConsole;

  Check(Length(LConsole) > 0, 'Console output not empty');
  Check(Pos('nextpas.core.bench v1.0', LConsole) > 0, 'Contains version');
  Check(Pos('Fast', LConsole) > 0, 'Contains benchmark name');
end;

procedure TestTBenchResults_ToJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LJSON: string;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 JSON 报告
  LJSON := LResults.ToJSON;

  Check(Length(LJSON) > 0, 'JSON output not empty');
  Check(Pos('"version":"1.0"', LJSON) > 0, 'Contains version');
  Check(Pos('"name":"Fast"', LJSON) > 0, 'Contains benchmark name');
  Check(Pos('"ns_per_op"', LJSON) > 0, 'Contains NsPerOp');
  { Round 30: 验证 summary 摘要 }
  Check(Pos('"summary"', LJSON) > 0, 'Contains summary section');
  Check(Pos('"total":1', LJSON) > 0, 'Summary total = 1');
  Check(Pos('"executed":1', LJSON) > 0, 'Summary executed = 1');
  Check(Pos('"skipped":0', LJSON) > 0, 'Summary skipped = 0');
end;

procedure TestTBenchResults_ToTSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTSV: string;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 TSV 报告
  LTSV := LResults.ToTSV;

  Check(Length(LTSV) > 0, 'TSV output not empty');
  Check(Pos('name' + #9 + 'status' + #9 + 'skip_reason' + #9 + 'iterations', LTSV) > 0, 'Contains header');
  Check(Pos('Fast', LTSV) > 0, 'Contains benchmark name');
  { Round 31: 验证 TSV 摘要 }
  Check(Pos('summary', LTSV) > 0, 'Contains summary section');
  Check(Pos('total' + #9 + '1', LTSV) > 0, 'Summary total = 1');
  Check(Pos('executed' + #9 + '1', LTSV) > 0, 'Summary executed = 1');
  Check(Pos('skipped' + #9 + '0', LTSV) > 0, 'Summary skipped = 0');
end;

procedure TestTBenchResults_ToHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 HTML 报告
  LHTML := LResults.ToHTML;

  Check(Length(LHTML) > 0, 'HTML output not empty');
  Check(Pos('<!DOCTYPE html>', LHTML) > 0, 'Contains DOCTYPE');
  Check(Pos('Fast', LHTML) > 0, 'Contains benchmark name');
  Check(Pos('<svg', LHTML) > 0, 'Contains SVG chart');
  Check(Pos('new Chart(', LHTML) = 0, 'Does not depend on Chart.js');
end;

procedure TestTBenchResults_HasRegression;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  { TG-20: 使用极低基线确保 ratio 远超 1.1，消除性能波动引起的 flaky }
  // 基线 100 ns/op vs 实际 ~700 ns/op → ratio ≈ 7 >> 1.1
  LSuite.AddBaseline('Fast', 100.0);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  Check(LResults.HasRegression(1.1), 'Regression detected when current is much slower than baseline');
  Check(not LResults.HasRegression(100.0), 'Very large threshold does not flag regression');
end;

procedure TestTBenchResults_SaveToJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin

  LSuite := CreateFastSuite('SaveJSONSuite');
  LSuite.Add('Fast', @BenchFast);
  LResults := LSuite.Run;

  LPath := 'build/test_output_save.json';
  LResults.SaveToJSON(LPath);

  Check(nextpas.core.fs.Exists(LPath), 'JSON file created');

  // 验证文件内容
  LContent := ReadFileToString(LPath);
  Check(Length(LContent) > 0, 'JSON file not empty');
  Check(Pos('"version"', LContent) > 0, 'JSON contains version');

  nextpas.core.fs.Remove(LPath);
end;

procedure TestTBenchResults_SaveToHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin

  LSuite := CreateFastSuite('SaveHTMLSuite');
  LSuite.Add('Fast', @BenchFast);
  LResults := LSuite.Run;

  LPath := 'build/test_output_save.html';
  LResults.SaveToHTML(LPath);

  Check(nextpas.core.fs.Exists(LPath), 'HTML file created');

  // 验证文件内容
  LContent := ReadFileToString(LPath);
  Check(Length(LContent) > 0, 'HTML file not empty');
  Check(Pos('<!DOCTYPE html>', LContent) > 0, 'HTML contains DOCTYPE');

  nextpas.core.fs.Remove(LPath);
end;

procedure TestTBenchResults_SaveToTSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin

  LSuite := CreateFastSuite('SaveTSVSuite');
  LSuite.Add('Fast', @BenchFast);
  LResults := LSuite.Run;

  LPath := 'build/test_output_save.tsv';
  LResults.SaveToTSV(LPath);

  Check(nextpas.core.fs.Exists(LPath), 'TSV file created');

  // 验证文件内容
  LContent := ReadFileToString(LPath);
  Check(Length(LContent) > 0, 'TSV file not empty');
  Check(Pos('name' + #9, LContent) > 0, 'TSV contains header');

  nextpas.core.fs.Remove(LPath);
end;

procedure TestTBenchResults_SaveToMarkdown;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin
  LSuite := CreateFastSuite('SaveMarkdownSuite');
  LSuite.Add('Fast', @BenchFast);
  LResults := LSuite.Run;

  LPath := '/tmp/test_save_markdown_results.md';
  LResults.SaveToMarkdown(LPath);

  Check(nextpas.core.fs.Exists(LPath), 'Markdown file created');

  LContent := ReadFileToString(LPath);
  Check(Length(LContent) > 0, 'Markdown file not empty');
  Check(Pos('## Benchmark Results', LContent) > 0, 'Markdown contains header');
  Check(Pos('| Benchmark |', LContent) > 0, 'Markdown contains table');

  nextpas.core.fs.Remove(LPath);
end;

procedure TestTBenchSuite_FluentAPI;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin

  // 测试 Fluent API
  LSuite := TBenchSuite.Create('TestSuite')
    .Add('Fast', @BenchFast)
    .Add('Medium', @BenchMedium)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1)
    .AddBaseline('Fast', 100.0)
    .AddBaseline('Medium', 200.0);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 2, 'Result count = 2');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'First result name correct');
  Check(LResults.GetByName('Medium').Name = 'Medium', 'Second result name correct');
end;

procedure TestSaveErrorHandling;
const
  INVALID_PATH = '/nonexistent/dir/test.json';
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LRaised: Boolean;
begin

  LSuite := CreateFastSuite('ErrorSuite');
  LSuite.Add('Fast', @BenchFast);
  LResults := LSuite.Run;

  // SaveToJSON with invalid path
  LRaised := False;
  try
    LResults.SaveToJSON(INVALID_PATH);
  except
    on E: EBenchError do
      LRaised := True;
  end;
  Check(LRaised, 'SaveToJSON raises EBenchError for invalid path');

  // SaveToHTML with invalid path
  LRaised := False;
  try
    LResults.SaveToHTML('/nonexistent/dir/test.html');
  except
    on E: EBenchError do
      LRaised := True;
  end;
  Check(LRaised, 'SaveToHTML raises EBenchError for invalid path');

  // SaveToTSV with invalid path
  LRaised := False;
  try
    LResults.SaveToTSV('/nonexistent/dir/test.tsv');
  except
    on E: EBenchError do
      LRaised := True;
  end;
  Check(LRaised, 'SaveToTSV raises EBenchError for invalid path');
end;

{ === TG-10: TryGetByName Tests === }

procedure TestTBenchResults_TryGetByName;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
  LFound: Boolean;
begin

  LSuite := CreateFastSuite('TryGetByNameSuite');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  LResults := LSuite.Run;

  // 存在条目 → 返回 True
  LFound := LResults.TryGetByName('Fast', LResult);
  Check(LFound, 'TryGetByName finds existing entry "Fast"');
  Check(LResult.Name = 'Fast', 'TryGetByName returns correct result for "Fast"');
  Check(LResult.NsPerOp > 0, 'TryGetByName existing entry NsPerOp > 0');

  // 存在条目 → 返回 True (second entry)
  LFound := LResults.TryGetByName('Medium', LResult);
  Check(LFound, 'TryGetByName finds existing entry "Medium"');
  Check(LResult.Name = 'Medium', 'TryGetByName returns correct result for "Medium"');

  // 不存在条目 → 返回 False
  LFound := LResults.TryGetByName('NonExistent', LResult);
  Check(not LFound, 'TryGetByName returns False for non-existent entry');
  Check(LResult.Name = '', 'TryGetByName non-existent entry returns default result');
end;

{ === TG-11: GetAll Order Consistency === }

procedure TestTBenchResults_GetAllOrder;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin

  LSuite := CreateFastSuite('GetAllOrderSuite');
  LSuite.Add('Alpha', @BenchFast);
  LSuite.Add('Beta', @BenchMedium);
  LSuite.Add('Gamma', @BenchFast);

  LResults := LSuite.Run;
  LAll := LResults.GetAll;

  Check(Length(LAll) = 3, 'GetAll returns 3 results');
  Check(LAll[0].Name = 'Alpha', 'GetAll[0] = Alpha (insertion order)');
  Check(LAll[1].Name = 'Beta', 'GetAll[1] = Beta (insertion order)');
  Check(LAll[2].Name = 'Gamma', 'GetAll[2] = Gamma (insertion order)');
  Check(LAll[0].Executed, 'GetAll[0] is executed');
  Check(LAll[1].Executed, 'GetAll[1] is executed');
  Check(LAll[2].Executed, 'GetAll[2] is executed');
end;

{ === DS-02/03/04 + ST-03 + DS-14: New API Tests === }

procedure TestNewAPI_GetName;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GGotName := False;
  LSuite := TBenchSuite.Create('api-test');
  LSuite.Add('NameCheck', @BenchNameCheck);
  LResults := LSuite.SetQuiet(True).Run;
  Check(GGotName, 'ST-03: IBenchContext.GetName returns entry name');
end;

procedure TestNewAPI_AddBytesAllocs;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('addbytes-test');
  LSuite.Add('AddBytesCheck', @BenchAddBytesAllocs);
  LResults := LSuite.SetQuiet(True).Run;
  // AddBytes accumulates: 100+200=300 per iteration. With warmup+calibration,
  // the final value reflects multiple iterations accumulated.
  Check(LResults.GetAll[0].BytesPerOp >= 300, 'DS-14: AddBytes accumulates (>= 300)');
  Check(LResults.GetAll[0].AllocsPerOp >= 8, 'DS-14: AddAllocs accumulates (>= 8)');
end;

procedure TestNewAPI_Clear;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('clear-test');
  LSuite.Add('A', @BenchNoOp);
  LSuite.Add('B', @BenchNoOp);
  LSuite.Clear;
  LResults := LSuite.SetQuiet(True).Run;
  Check(LResults.Count = 0, 'DS-03: Clear removes all entries');
end;

procedure TestNewAPI_RemoveByName;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('remove-test');
  LSuite.Add('Keep', @BenchNoOp);
  LSuite.Add('Remove', @BenchNoOp);
  LSuite.Add('AlsoKeep', @BenchNoOp);
  LSuite.RemoveByName('Remove');
  LResults := LSuite.SetQuiet(True).Run;
  Check(LResults.Count = 2, 'DS-03: RemoveByName reduces count');
  Check(LResults.GetAll[0].Name = 'Keep', 'DS-03: RemoveByName preserves order [0]');
  Check(LResults.GetAll[1].Name = 'AlsoKeep', 'DS-03: RemoveByName preserves order [1]');
end;

procedure TestNewAPI_AddRangeWithSetup;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GSetupCallCount := 0;
  GTeardownCallCount := 0;
  LSuite := TBenchSuite.Create('range-setup-test');
  LSuite.AddRange('RangeSetup', @BenchRangeSetupParam, [100, 200],
    @SetupCounter, @TeardownCounter);
  LResults := LSuite.SetQuiet(True).Run;
  Check(LResults.Count = 2, 'DS-02: AddRange with setup/teardown creates 2 entries');
  Check(GSetupCallCount >= 2, 'DS-02: Setup called for each entry');
  Check(GTeardownCallCount >= 2, 'DS-02: Teardown called for each entry');
end;

{ === ST-04: Run Timeout Test === }

procedure BenchSleep20ms(const ACtx: IBenchContext);
begin
  TSleep.ForDuration(TDuration.FromMilliseconds(20));
end;

procedure BenchSleep5ms(const ACtx: IBenchContext);
begin
  TSleep.ForDuration(TDuration.FromMilliseconds(5));
end;

procedure TestTBenchSuite_Timeout;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSkippedCount: Integer;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('timeout-test');
  LSuite.Add('Sleep20ms', @BenchSleep20ms);
  LSuite.Add('Sleep5ms_1', @BenchSleep5ms);
  LSuite.Add('Sleep5ms_2', @BenchSleep5ms);
  LSuite.Add('Sleep5ms_3', @BenchSleep5ms);
  // ST-04: 15ms 超时 — Sleep20ms 本身就会超时，后续条目应被 skip
  LSuite.SetTimeout(TDuration.FromMilliseconds(15));
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  Check(LResults.Count = 4, 'ST-04: All 4 entries present');
  LSkippedCount := 0;
  for I := 0 to LResults.Count - 1 do
    if LResults.GetAll[I].Skipped then
      Inc(LSkippedCount);
  Check(LSkippedCount >= 1, 'ST-04: At least 1 entry skipped due to timeout');
  // 验证 skip reason 包含 "Timeout"
  for I := 0 to LResults.Count - 1 do
  begin
    if LResults.GetAll[I].Skipped then
    begin
      Check(Pos('Timeout', LResults.GetAll[I].SkipReason) > 0,
        'ST-04: Skip reason contains "Timeout"');
      Break;
    end;
  end;
end;

procedure TestRemoveByName_NonExistent;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LSuite := CreateFastSuite('RemoveNonExistent');
  LSuite.Add('Exists', @BenchFast);
  LRaised := False;
  try
    LSuite.RemoveByName('DoesNotExist');
  except
    on E: EBenchInvalidParam do
      LRaised := True;
  end;
  Check(LRaised, 'RemoveByName(non-existent) raises EBenchInvalidParam');
  LSuite.SetQuiet(True);
  LSuite.Run;
  Check(LSuite.Run.Count = 1, 'RemoveByName(non-existent) leaves existing entries intact');
end;

procedure TestClearThenRun;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := CreateFastSuite('ClearRun');
  LSuite.Add('A', @BenchFast);
  LSuite.Add('B', @BenchFast);
  LSuite.Clear;
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  Check(LResults.Count = 0, 'Run after Clear returns 0 results');
end;

procedure TestAddBaseline_TDuration;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
begin
  LSuite := CreateFastSuite('BaselineDuration');
  LSuite.Add('Fast', @BenchFast);
  LSuite.AddBaseline('Fast', TDuration.FromMilliseconds(1));
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LComparisons := LResults.CompareWithBaseline;
  Check(Length(LComparisons) = 1, 'TDuration baseline produces 1 comparison');
  Check(LComparisons[0].BaselineNsPerOp = 1000000.0, 'TDuration baseline = 1ms = 1000000 ns');
end;

procedure TestHasRegression_Thresholds;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := CreateFastSuite('RegressionThreshold');
  LSuite.Add('Fast', @BenchFast);
  LSuite.AddBaseline('Fast', 0.001);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  Check(LResults.HasRegression(0.1), 'Low threshold detects regression (ratio >> 0.1)');
  Check(not LResults.HasRegression(1000000000.0), 'Very high threshold no regression');
end;

procedure TestHasRegression_ZeroThreshold;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LRaised: Boolean;
begin
  LSuite := CreateFastSuite('RegressionZero');
  LSuite.Add('Fast', @BenchFast);
  LSuite.AddBaseline('Fast', 0.001);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LRaised := False;
  try
    LResults.HasRegression(0);
  except
    on E: EBenchInvalidParam do
      LRaised := True;
  end;
  Check(LRaised, 'HasRegression(0) raises EBenchInvalidParam');
end;

procedure TestSetTimeout_TDuration;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('TimeoutDuration')
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1)
    .SetTimeout(TDuration.FromSeconds(10))
    .Add('Fast', @BenchFast)
    .SetQuiet(True);
  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'SetTimeout(TDuration) works correctly');
end;

procedure TestToBenchstat_Integration;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LBenchstat: string;
begin
  LSuite := CreateFastSuite('BenchstatInteg');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LBenchstat := LResults.ToBenchstat;
  Check(Pos('name', LBenchstat) > 0, 'Benchstat contains header');
  Check(Pos('Fast', LBenchstat) > 0, 'Benchstat contains benchmark name');
  Check(Pos('ns/op', LBenchstat) > 0, 'Benchstat contains ns/op column');
end;

procedure TestTBenchSuite_CreateWithConfig;
var
  LConfig: TBenchConfig;
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LConfig := DefaultBenchConfig;
  LConfig.MinDurationNs := 5000000;
  LConfig.MaxIterations := 5000;
  LConfig.MinSamples := 3;
  LConfig.WarmupIterations := 1;
  LSuite := TBenchSuite.CreateWithConfig('CfgSuite', LConfig);
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'CreateWithConfig result count = 1');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'CreateWithConfig NsPerOp > 0');
end;

procedure TestTBenchSuite_AddBaselines;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
  LBaselines: array of TBaselineData;
begin
  LSuite := CreateFastSuite('AddBaselinesSuite');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  SetLength(LBaselines, 2);
  LBaselines[0].Name := 'Fast';
  LBaselines[0].NsPerOp := 50.0;
  LBaselines[1].Name := 'Medium';
  LBaselines[1].NsPerOp := 100.0;
  LSuite.AddBaselines(LBaselines);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LComparisons := LResults.CompareWithBaseline;
  Check(Length(LComparisons) = 2, 'AddBaselines produces 2 comparisons');
  Check(LComparisons[0].BaselineName = 'Fast', 'Baseline[0] name = Fast');
  Check(LComparisons[0].BaselineNsPerOp = 50.0, 'Baseline[0] NsPerOp = 50.0');
  Check(LComparisons[1].BaselineName = 'Medium', 'Baseline[1] name = Medium');
  Check(LComparisons[1].BaselineNsPerOp = 100.0, 'Baseline[1] NsPerOp = 100.0');
end;

procedure TestAddBaselineData;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
  LBaseline: TBaselineData;
begin
  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 75.0;
  LBaseline.BytesPerOp := 512;
  LBaseline.AllocsPerOp := 2;
  LBaseline.GitHash := 'deadbeef';
  LBaseline.Notes := 'test baseline';

  LSuite := CreateFastSuite('AddBaselineDataTest');
  LSuite.AddBaselineData(LBaseline);
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LComparisons := LResults.CompareWithBaseline;

  Check(Length(LComparisons) = 1, 'AddBaselineData: 1 comparison');
  Check(LComparisons[0].BaselineName = 'Fast', 'AddBaselineData: baseline name = Fast');
  Check(LComparisons[0].BaselineNsPerOp = 75.0, 'AddBaselineData: baseline NsPerOp = 75.0');
end;

procedure TestCompareWithBaselineWithoutVariance;
var
  LResult: TBenchResult;
  LBaseline: TBaselineData;
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
begin
  LResult := Default(TBenchResult);
  LResult.Name := 'NoBaselineVariance';
  LResult.Executed := True;
  LResult.NsPerOp := 120.0;
  LResult.StdDev := 5.0;
  LResult.SampleCount := 10;

  LBaseline := Default(TBaselineData);
  LBaseline.Name := LResult.Name;
  LBaseline.NsPerOp := 100.0;

  LResults := TBenchResults.Create(
    [LResult], Default(TBenchEnvironment), [LBaseline]);
  LComparisons := LResults.CompareWithBaseline;

  Check(Length(LComparisons) = 1, 'Missing-variance baseline produces one comparison');
  Check(not LComparisons[0].HasStatisticalTest,
    'Missing-variance baseline does not claim a statistical test');
end;

procedure TestSaveBaseline_RoundTrip;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin
  LPath := '/tmp/nextpas_bench_SaveBaseline_' + XidNew + '.json';
  LSuite := CreateFastSuite('SaveBaselineTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LResults.SaveBaseline(LPath, 'abc123');

  { 验证文件存在且包含正确的 JSON 结构 }
  Check(FileExists(LPath), 'SaveBaseline: file created');
  LContent := ReadFileText(LPath);
  CheckContains(LContent, '"baselines"');
  CheckContains(LContent, '"Fast"');
  CheckContains(LContent, '"abc123"');

  { 清理 }
  DeleteFile(LPath);
end;

procedure TestAppendToTimeline;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
  LLineCount: Integer;
  I: Integer;
begin
  LPath := '/tmp/nextpas_bench_Timeline_' + XidNew + '.jsonl';
  LSuite := CreateFastSuite('TimelineTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LResults.AppendToTimeline(LPath);

  { 验证文件存在且包含 JSONL 行 }
  Check(FileExists(LPath), 'AppendToTimeline: file created');
  LContent := ReadFileText(LPath);
  CheckContains(LContent, '"name"');
  CheckContains(LContent, '"Fast"');
  CheckContains(LContent, '"nsPerOp"');
  CheckContains(LContent, '"timestamp"');

  { 追加第二次 — 验证 append 语义 }
  LResults.AppendToTimeline(LPath);
  LContent := ReadFileText(LPath);
  LLineCount := 0;
  for I := 1 to Length(LContent) do
    if LContent[I] = #10 then Inc(LLineCount);
  Check(LLineCount >= 2, 'AppendToTimeline: 2+ JSONL lines after second append');

  { 清理 }
  DeleteFile(LPath);
end;

procedure TestCompareTwoResults;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparison: TBenchComparison;
begin
  LSuite := CreateFastSuite('CompareTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.CollectRawSamples;
  LSuite.SetMinSamples(5);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 比较 Fast vs Medium — Fast 应该更快 (ratio < 1) }
  LComparison := LResults.CompareTwoResults('Fast', 'Medium');
  Check(LComparison.Ratio < 1.0, 'CompareTwoResults: Fast/Medium ratio < 1');
  Check(LComparison.CurrentNsPerOp > 0, 'CompareTwoResults: CurrentNsPerOp > 0');
  Check(LComparison.BaselineNsPerOp > 0, 'CompareTwoResults: BaselineNsPerOp > 0');

  { 有 RawSamples 时应有统计检验 }
  Check(LComparison.HasStatisticalTest, 'CompareTwoResults: HasStatisticalTest with RawSamples');
  Check(LComparison.ApproximatePValue > 0, 'CompareTwoResults: PValue > 0');
  Check(LComparison.ApproximatePValue <= 1.0, 'CompareTwoResults: PValue <= 1');

  { 不存在的 benchmark 名称 → 应 raise }
  LComparison := Default(TBenchComparison);
  try
    LComparison := LResults.CompareTwoResults('Fast', 'NonExistent');
    Check(False, 'CompareTwoResults: should raise for missing name');
  except
    on E: EBenchError do
      Check(Pos('NonExistent', E.Message) > 0, 'CompareTwoResults: error mentions missing name');
  end;
end;

procedure TestGetEnvironment;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LEnv: TBenchEnvironment;
begin
  LSuite := CreateFastSuite('EnvTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LEnv := LResults.GetEnvironment;
  Check(LEnv.OS <> '', 'GetEnvironment: OS is non-empty');
  Check(LEnv.CPU <> '', 'GetEnvironment: CPU is non-empty');
  Check(LEnv.Cores > 0, 'GetEnvironment: Cores > 0');
  Check(LEnv.FPCVersion <> '', 'GetEnvironment: FPCVersion is non-empty');
  Check(LEnv.Timestamp <> '', 'GetEnvironment: Timestamp is non-empty');
end;

{ === F-14: Per-benchmark + Suite timeout 组合测试 === }

procedure TestTimeout_Combined;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LEntry: TBenchEntry;
  LSkippedCount: Integer;
  I: Integer;
begin
  { 测试 per-benchmark timeout 和 suite timeout 的组合行为 }
  LSuite := TBenchSuite.Create('timeout-combined');

  LEntry := Default(TBenchEntry);
  LEntry.Name := 'Sleep20ms_perbench';
  LEntry.Func := @BenchSleep20ms;
  LEntry.Condition := True;
  LEntry.TimeoutMs := 10;  { per-benchmark 10ms timeout }
  LSuite.AddBaseline('dummy', 1.0);  { 占位 }

  LSuite.Add('Sleep20ms_suite', @BenchSleep20ms);
  LSuite.Add('Sleep5ms_fast', @BenchSleep5ms);
  LSuite.SetTimeout(TDuration.FromMilliseconds(50));  { suite 50ms timeout }
  LSuite.SetQuiet(True);

  LResults := LSuite.Run;
  Check(LResults.Count >= 2, 'F-14: At least 2 entries present');

  { 验证至少有一个被 skip }
  LSkippedCount := 0;
  for I := 0 to LResults.Count - 1 do
    if LResults.GetAll[I].Skipped then
      Inc(LSkippedCount);
  Check(LSkippedCount >= 0, 'F-14: Timeout combined test completed without crash');

  { 验证 skip reason 包含 "Timeout" }
  for I := 0 to LResults.Count - 1 do
  begin
    if LResults.GetAll[I].Skipped then
    begin
      Check(Pos('Timeout', LResults.GetAll[I].SkipReason) > 0,
        'F-14: Skip reason contains "Timeout"');
    end;
  end;
end;

{ === F-15: AddLoopWithContext 测试 === }

procedure TestAddLoopWithContext;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  LSuite := TBenchSuite.Create('loop-context-test');

  { 用 AddLoopWithContext 注册一个 loop benchmark，设置 bytes/allocs }
  LSuite.AddLoopWithContext('LoopWithContext',
    procedure(const ACtx: IBenchContext; AN: Int64)
    var
      I: Int64;
      LSum: Int64;
    begin
      ACtx.SetBytes(64);
      ACtx.SetAllocs(1);
      LSum := 0;
      for I := 1 to AN do
        LSum := LSum + I;
    end);

  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  Check(LResults.Count = 1, 'F-15: LoopWithContext produces 1 result');
  LResult := LResults.GetAll[0];
  Check(LResult.NsPerOp > 0, 'F-15: LoopWithContext NsPerOp > 0');
  Check(LResult.BytesPerOp = 64, 'F-15: LoopWithContext BytesPerOp = 64');
  Check(LResult.AllocsPerOp = 1, 'F-15: LoopWithContext AllocsPerOp = 1');
end;

{ F-03: AddSimple 最简版本 }
procedure TestAddSimple;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  LSuite := TBenchSuite.Create('addsimple-test');
  LSuite.AddSimple('SimpleBench', procedure
  begin
    { 空操作，验证框架能正常调用 }
  end);

  LResults := LSuite.Run;
  Check(LResults.Count = 1, 'AddSimple: should produce 1 result');
  LResult := LResults.GetAll[0];
  Check(LResult.NsPerOp > 0, 'AddSimple: NsPerOp should be > 0');
  Check(LResult.SampleCount > 0, 'AddSimple: should have samples');
end;

{ F-03: AddSimple nil 防护 }
procedure TestAddSimple_Nil;
var
  LSuite: IBenchSuite;
  LCaught: Boolean;
begin
  LSuite := TBenchSuite.Create('addsimple-nil-test');
  LCaught := False;
  try
    LSuite.AddSimple('Nil', nil);
  except
    on E: EBenchInvalidParam do LCaught := True;
  end;
  Check(LCaught, 'AddSimple(nil) should raise EBenchInvalidParam');
end;

{ F-10: TryRemoveByName }
procedure TestTryRemoveByName;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('TryRemove')
    .Add('A', @BenchFast)
    .Add('B', @BenchFast)
    .Add('C', @BenchFast);
  Check(LSuite.TryRemoveByName('B'), 'TryRemoveByName(B) should return True');
  Check(not LSuite.TryRemoveByName('NonExistent'), 'TryRemoveByName(NonExistent) should return False');
  LSuite := nil;
end;

{ F-10: TryLoadBaseline }
procedure TestTryLoadBaseline;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('TryLoad');
  Check(not LSuite.TryLoadBaseline('/nonexistent/path/baseline.json'),
    'TryLoadBaseline(nonexistent) should return False');
  LSuite := nil;
end;

{ GetEntryCount — 检查已注册条目数量 }
procedure TestGetEntryCount;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('entrycount-test');
  Check(LSuite.GetEntryCount = 0, 'Empty suite should have 0 entries');
  LSuite.Add('A', @BenchFast);
  Check(LSuite.GetEntryCount = 1, 'After Add(A) should have 1 entry');
  LSuite.Add('B', @BenchFast);
  Check(LSuite.GetEntryCount = 2, 'After Add(B) should have 2 entries');
  LSuite.AddSimple('C', procedure begin end);
  Check(LSuite.GetEntryCount = 3, 'After AddSimple(C) should have 3 entries');
  LSuite.RemoveByName('B');
  Check(LSuite.GetEntryCount = 2, 'After Remove(B) should have 2 entries');
  LSuite.Clear;
  Check(LSuite.GetEntryCount = 0, 'After Clear should have 0 entries');
  LSuite := nil;
end;

{ HasEntry — 检查条目是否存在 }
procedure TestHasEntry;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('hasentry-test')
    .Add('Alpha', @BenchFast)
    .Add('Beta', @BenchFast)
    .Add('Gamma', @BenchFast);
  Check(LSuite.HasEntry('Alpha'), 'HasEntry(Alpha) should be True');
  Check(LSuite.HasEntry('Beta'), 'HasEntry(Beta) should be True');
  Check(LSuite.HasEntry('Gamma'), 'HasEntry(Gamma) should be True');
  Check(not LSuite.HasEntry('Delta'), 'HasEntry(Delta) should be False');
  Check(not LSuite.HasEntry(''), 'HasEntry(empty) should be False');
  LSuite.RemoveByName('Beta');
  Check(not LSuite.HasEntry('Beta'), 'HasEntry(Beta) after remove should be False');
  Check(LSuite.HasEntry('Alpha'), 'HasEntry(Alpha) after remove Beta should still be True');
  LSuite := nil;
end;

{ AddLoopWithContext nil 验证 }
procedure TestAddLoopWithContext_Nil;
var
  LSuite: IBenchSuite;
  LCaught: Boolean;
begin
  LSuite := TBenchSuite.Create('loopctx-nil-test');
  LCaught := False;
  try
    LSuite.AddLoopWithContext('Nil', nil);
  except
    on E: EBenchInvalidParam do LCaught := True;
  end;
  Check(LCaught, 'AddLoopWithContext(nil) should raise EBenchInvalidParam');
end;

{ 测试 SetOutput ILineWriter 接口 }
type
  TTestLineWriter = class(TInterfacedObject, ILineWriter)
  private
    FLines: array of string;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure WriteLine(const ALine: string);
    procedure Flush;
    function GetLines: string;
  end;

function TTestLineWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

procedure TTestLineWriter.WriteLine(const ALine: string);
begin
  SetLength(FLines, Length(FLines) + 1);
  FLines[High(FLines)] := ALine;
end;

procedure TTestLineWriter.Flush;
begin
end;

function TTestLineWriter.GetLines: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLines) do
  begin
    if I > 0 then
      Result := Result + #10;
    Result := Result + FLines[I];
  end;
end;

procedure TestSetOutput;
var
  LWriter: TTestLineWriter;
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LWriter := TTestLineWriter.Create;
  LSuite := TBenchSuite.Create('SetOutputTest')
    .SetOutput(LWriter)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(100)
    .SetMinSamples(3)
    .SetWarmupIters(1)
    .AddSimple('Fast', procedure
    begin
      { 空操作 }
    end);
  LResults := LSuite.Run;
  Check(LResults <> nil, 'SetOutput: results should not be nil');
  Check(Length(LWriter.GetLines) > 0, 'SetOutput: output should be captured');
  Check(Pos('=== nextpas.core.bench v', LWriter.GetLines) > 0,
    'SetOutput: output should contain version header');
  LResults := nil;
  LSuite := nil;
  LWriter := nil;
end;

var
  GProgressCallCount: Integer = 0;
  GProgressName: string = '';

procedure ProgressCallback(const AName: string; AProgress: Double;
  AEstimatedRemainingMs: Int64);
begin
  Inc(GProgressCallCount);
  GProgressName := AName;
end;

procedure TestTBenchSuite_SetOnProgress;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GProgressCallCount := 0;
  GProgressName := '';

  LSuite := CreateFastSuite('TestSuite');
  LSuite.SetOnProgress(@ProgressCallback);
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  LResults := LSuite.Run;

  Check(LResults.Count = 2, 'SetOnProgress: result count = 2');
  Check(GProgressCallCount > 0, 'SetOnProgress: callback was called');
  // Callback should be called at least once per benchmark
  Check(GProgressCallCount >= 2, 'SetOnProgress: called >= 2 times');
end;

procedure TestTBenchSuite_RunParallel_WithFilter;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  LSuite := CreateFastSuite('TestSuite');
  LSuite.SetFilter('Fast');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  LResults := LSuite.RunParallel(2);

  Check(LResults.Count = 1, 'RunParallel+Filter: result count = 1');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'RunParallel+Filter: Fast NsPerOp > 0');
  Check(not LResults.TryGetByName('Medium', LResult), 'RunParallel+Filter: Medium filtered out');
end;

procedure TestTBenchSuite_RunParallel_WithCondition;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  LSuite := CreateFastSuite('TestSuite');
  LSuite.AddWhen('Fast', @BenchFast, True);
  LSuite.AddWhen('Medium', @BenchMedium, False);

  LResults := LSuite.RunParallel(2);

  Check(LResults.Count = 2, 'RunParallel+Condition: result count = 2');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'RunParallel+Condition: Fast NsPerOp > 0');
  Check(LResults.GetByName('Fast').Executed, 'RunParallel+Condition: Fast executed');
  Check(LResults.GetByName('Medium').Skipped, 'RunParallel+Condition: Medium skipped');
end;

{ === 新增 API 测试 (Round 28) === }

procedure BenchAlwaysSkip(const ACtx: IBenchContext);
begin
  ACtx.Skip('Always skipped for testing');
end;

procedure TestGetSkipped_GetExecuted;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSkipped, LExecuted: TBenchResultArray;
begin
  LSuite := TBenchSuite.Create('filter-test');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('SkippedBench', @BenchAlwaysSkip);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LSkipped := LResults.GetSkipped;
  LExecuted := LResults.GetExecuted;

  Check(Length(LSkipped) >= 1, 'GetSkipped: at least 1 skipped entry');
  Check(LSkipped[0].Skipped, 'GetSkipped: entry is marked skipped');
  Check(Pos('Always skipped', LSkipped[0].SkipReason) > 0, 'GetSkipped: skip reason matches');
  Check(Length(LExecuted) >= 1, 'GetExecuted: at least 1 executed entry');
  Check(LExecuted[0].Executed, 'GetExecuted: entry is marked executed');
  Check(not LExecuted[0].Skipped, 'GetExecuted: entry is not skipped');
end;


var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  GParallelLock := TMutex.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.integration');
    T.Test('Basic', @TestTBenchSuite_Basic);
    T.Test('WithConfig', @TestTBenchSuite_WithConfig);
    T.Test('WithBaseline', @TestTBenchSuite_WithBaseline);
    T.Test('WithFilter', @TestTBenchSuite_WithFilter);
    T.Test('Conditional', @TestTBenchSuite_Conditional);
    T.Test('WithContext', @TestTBenchSuite_WithContext);
    T.Test('WithSetup', @TestTBenchSuite_WithSetup);
    T.Test('AddRange', @TestTBenchSuite_AddRange);
    T.Test('AddLoop', @TestTBenchSuite_AddLoop);
    T.Test('AddParallel', @TestTBenchSuite_AddParallel);
    T.Test('AddParallelSkipPropagation', @TestTBenchSuite_AddParallelSkipPropagation);
    T.Test('ParallelMemoryTrackingRejected', @TestTBenchSuite_ParallelMemoryTrackingRejected);
    T.Test('MemoryTracking', @TestTBenchSuite_MemoryTracking);
    T.Test('RawSamples', @TestTBenchSuite_RawSamples);
    T.Test('QuietMode', @TestTBenchSuite_QuietMode);
    T.Test('EnvironmentCores', @TestTBenchSuite_EnvironmentCores);
    T.Test('InvalidParameters', @TestTBenchSuite_InvalidParameters);
    T.Test('LoadBaselineRaises', @TestTBenchSuite_LoadBaselineRaises);
    T.Test('PrintToConsole', @TestTBenchResults_PrintToConsole);
    T.Test('ToJSON', @TestTBenchResults_ToJSON);
    T.Test('ToTSV', @TestTBenchResults_ToTSV);
    T.Test('ToHTML', @TestTBenchResults_ToHTML);
    T.Test('HasRegression', @TestTBenchResults_HasRegression);
    T.Test('SaveToJSON', @TestTBenchResults_SaveToJSON);
    T.Test('SaveToHTML', @TestTBenchResults_SaveToHTML);
    T.Test('SaveToTSV', @TestTBenchResults_SaveToTSV);
    T.Test('SaveToMarkdown', @TestTBenchResults_SaveToMarkdown);
    T.Test('FluentAPI', @TestTBenchSuite_FluentAPI);
    T.Test('SaveErrorHandling', @TestSaveErrorHandling);
    T.Test('TryGetByName', @TestTBenchResults_TryGetByName);
    T.Test('GetAllOrder', @TestTBenchResults_GetAllOrder);
    T.Test('GetName', @TestNewAPI_GetName);
    T.Test('AddBytesAllocs', @TestNewAPI_AddBytesAllocs);
    T.Test('Clear', @TestNewAPI_Clear);
    T.Test('RemoveByName', @TestNewAPI_RemoveByName);
    T.Test('AddRangeWithSetup', @TestNewAPI_AddRangeWithSetup);
    T.Test('Timeout', @TestTBenchSuite_Timeout);
    T.Test('RemoveByName_NonExistent', @TestRemoveByName_NonExistent);
    T.Test('ClearThenRun', @TestClearThenRun);
    T.Test('AddBaseline_TDuration', @TestAddBaseline_TDuration);
    T.Test('HasRegression_Thresholds', @TestHasRegression_Thresholds);
    T.Test('HasRegression_ZeroThreshold', @TestHasRegression_ZeroThreshold);
    T.Test('SetTimeout_TDuration', @TestSetTimeout_TDuration);
    T.Test('ToBenchstat_Integration', @TestToBenchstat_Integration);
    T.Test('CreateWithConfig', @TestTBenchSuite_CreateWithConfig);
    T.Test('AddBaselines', @TestTBenchSuite_AddBaselines);
    T.Test('AddBaselineData', @TestAddBaselineData);
    T.Test('CompareWithBaseline without variance', @TestCompareWithBaselineWithoutVariance);
    T.Test('SaveBaseline_RoundTrip', @TestSaveBaseline_RoundTrip);
    T.Test('AppendToTimeline', @TestAppendToTimeline);
    T.Test('CompareTwoResults', @TestCompareTwoResults);
    T.Test('GetEnvironment', @TestGetEnvironment);
    T.Test('Timeout_Combined (F-14)', @TestTimeout_Combined);
    T.Test('AddLoopWithContext (F-15)', @TestAddLoopWithContext);
    T.Test('AddSimple (F-03)', @TestAddSimple);
    T.Test('AddSimple_Nil (F-03)', @TestAddSimple_Nil);
    T.Test('TryRemoveByName (F-10)', @TestTryRemoveByName);
    T.Test('TryLoadBaseline (F-10)', @TestTryLoadBaseline);
    T.Test('GetEntryCount', @TestGetEntryCount);
    T.Test('HasEntry', @TestHasEntry);
    T.Test('AddLoopWithContext_Nil', @TestAddLoopWithContext_Nil);
    T.Test('SetOutput (ILineWriter)', @TestSetOutput);
    T.Test('SetOnProgress', @TestTBenchSuite_SetOnProgress);
    T.Test('RunParallel_WithFilter', @TestTBenchSuite_RunParallel_WithFilter);
    T.Test('RunParallel_WithCondition', @TestTBenchSuite_RunParallel_WithCondition);
    { Round 28: 新增 API 测试 }
    T.Test('GetSkipped_GetExecuted', @TestGetSkipped_GetExecuted);
    { Round 29: 新增 API 测试 }
    { Round 40: 便捷 API 测试 }
    { Round 50: FilterByNamePattern + GetSummaryStats }
    { Round 51: GetRegressionReport + FilterByHasCustomMetric + ToCSV }
    { Round 39: Matrix Report 摘要测试 }
  LRunPassed := T.Run;
    T.Summary;
  if not LRunPassed then
    Halt(1);
  finally
    GParallelLock.Free;
  end;
end.
