program test_bench_integration;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.math.scalar,
  nextpas.core.sync.mutex,
  nextpas.core.time.sleep,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.simd.cpuinfo;

var
  GTestCount: Integer;
  GPassCount: Integer;
  GFailCount: Integer;
  GSetupCallCount: Integer;
  GTeardownCallCount: Integer;
  GSetupVisibleInsideBench: Boolean;
  GSetupStateActive: Boolean;
  GTeardownSawExpectedData: Boolean;
  GParallelLock: TMutex;
  GActiveParallelCalls: Integer;
  GMaxParallelCalls: Integer;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  ✗ ', ATestName);
  end;
end;

function ReadFileToString(const APath: string): string;
var
  LFile: TextFile;
  LLine: string;
begin
  Result := '';
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      if Result <> '' then
        Result := Result + LineEnding + LLine
      else
        Result := LLine;
    end;
  finally
    CloseFile(LFile);
  end;
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

procedure TestTBenchSuite_Basic;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_Basic:');

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
  WriteLn('TestTBenchSuite_WithConfig:');

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
  WriteLn('TestTBenchSuite_WithBaseline:');

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
    'Scalar baseline does not claim statistical significance');
end;

procedure TestTBenchSuite_WithFilter;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_WithFilter:');

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
  Check(not LResults.GetByName('Medium').Executed, 'Filtered-out benchmark not executed');
end;

procedure TestTBenchSuite_Conditional;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_Conditional:');

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
  WriteLn('TestTBenchSuite_WithContext:');

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
  WriteLn('TestTBenchSuite_WithSetup:');

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
  WriteLn('TestTBenchSuite_AddRange:');

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
  WriteLn('TestTBenchSuite_AddLoop:');

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
  WriteLn('TestTBenchSuite_AddParallel:');

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
  Check(GMaxParallelCalls > 1, 'Parallel benchmark overlapped callbacks');

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
  WriteLn('TestTBenchSuite_AddParallelSkipPropagation:');

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
  Check(LResult.Iterations = 8, 'Parallel skip benchmark reports actual iterations');
  Check(LResult.BytesPerOp = 2048, 'Parallel skip benchmark keeps BytesPerOp');
  Check(LResult.AllocsPerOp = 3, 'Parallel skip benchmark keeps AllocsPerOp');
end;

procedure TestTBenchSuite_ParallelMemoryTrackingRejected;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin
  WriteLn('TestTBenchSuite_ParallelMemoryTrackingRejected:');

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
  WriteLn('TestTBenchSuite_MemoryTracking:');

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
  WriteLn('TestTBenchSuite_RawSamples:');

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
  WriteLn('TestTBenchSuite_QuietMode:');

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
  WriteLn('TestTBenchSuite_EnvironmentCores:');

  LSuite := CreateFastSuite('EnvironmentSuite');
  LSuite.Add('Fast', @BenchFast);

  LResults := LSuite.Run;

  Check(LResults.Environment.Cores = GetCPUInfo.LogicalCores,
    'Environment core count matches platform detection');
end;

procedure TestTBenchSuite_InvalidParameters;
var
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  WriteLn('TestTBenchSuite_InvalidParameters:');

  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinDuration(TDuration.FromNanoseconds(0));
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMinDuration rejects zero');

  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMaxIterations(0);
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMaxIterations rejects zero');

  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinSamples(0);
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'SetMinSamples rejects zero');

  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddParallel('BadParallel', @BenchFast, 0);
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;
  Check(LRaised, 'AddParallel rejects zero threads');
end;

procedure TestTBenchSuite_LoadBaselineRaises;
var
  LFile: TextFile;
  LPath: string;
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  WriteLn('TestTBenchSuite_LoadBaselineRaises:');

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
  AssignFile(LFile, LPath);
  Rewrite(LFile);
  try
    Write(LFile, '{invalid');
  finally
    CloseFile(LFile);
  end;

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

procedure TestTBenchResults_ToConsole;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LConsole: string;
begin
  WriteLn('TestTBenchResults_ToConsole:');

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成控制台报告
  LConsole := LResults.ToConsole;

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
  WriteLn('TestTBenchResults_ToJSON:');

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 JSON 报告
  LJSON := LResults.ToJSON;

  Check(Length(LJSON) > 0, 'JSON output not empty');
  Check(Pos('"version": "1.0"', LJSON) > 0, 'Contains version');
  Check(Pos('"name": "Fast"', LJSON) > 0, 'Contains benchmark name');
  Check(Pos('"ns_per_op"', LJSON) > 0, 'Contains NsPerOp');
end;

procedure TestTBenchResults_ToTSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTSV: string;
begin
  WriteLn('TestTBenchResults_ToTSV:');

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
end;

procedure TestTBenchResults_ToHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
begin
  WriteLn('TestTBenchResults_ToHTML:');

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
  WriteLn('TestTBenchResults_HasRegression:');

  // 创建套件
  LSuite := CreateFastSuite('TestSuite');

  // 添加基线（比当前快）- 基线是 500 ns/op，当前是 ~700 ns/op
  // Ratio = Current/Baseline = 700/500 = 1.4 > 1.1
  LSuite.AddBaseline('Fast', 500.0);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  Check(LResults.HasRegression(1.1), 'Regression detected when current is slower than 1.1x baseline');
  Check(not LResults.HasRegression(10.0), 'Large threshold does not flag regression');
end;

procedure TestTBenchResults_SaveToJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LContent: string;
begin
  WriteLn('TestTBenchResults_SaveToJSON:');

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
  WriteLn('TestTBenchResults_SaveToHTML:');

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
  WriteLn('TestTBenchResults_SaveToTSV:');

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

procedure TestTBenchSuite_FluentAPI;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_FluentAPI:');

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

begin
  WriteLn('=== nextpas.core.bench Integration Tests ===');
  WriteLn;

  GTestCount := 0;
  GPassCount := 0;
  GFailCount := 0;
  GParallelLock := TMutex.Create;
  try
    TestTBenchSuite_Basic;
    WriteLn;
    TestTBenchSuite_WithConfig;
    WriteLn;
    TestTBenchSuite_WithBaseline;
    WriteLn;
    TestTBenchSuite_WithFilter;
    WriteLn;
    TestTBenchSuite_Conditional;
    WriteLn;
    TestTBenchSuite_WithContext;
    WriteLn;
    TestTBenchSuite_WithSetup;
    WriteLn;
    TestTBenchSuite_AddRange;
    WriteLn;
    TestTBenchSuite_AddLoop;
    WriteLn;
    TestTBenchSuite_AddParallel;
    WriteLn;
    TestTBenchSuite_AddParallelSkipPropagation;
    WriteLn;
    TestTBenchSuite_ParallelMemoryTrackingRejected;
    WriteLn;
    TestTBenchSuite_MemoryTracking;
    WriteLn;
    TestTBenchSuite_RawSamples;
    WriteLn;
    TestTBenchSuite_QuietMode;
    WriteLn;
    TestTBenchSuite_EnvironmentCores;
    WriteLn;
    TestTBenchSuite_InvalidParameters;
    WriteLn;
    TestTBenchSuite_LoadBaselineRaises;
    WriteLn;
    TestTBenchResults_ToConsole;
    WriteLn;
    TestTBenchResults_ToJSON;
    WriteLn;
    TestTBenchResults_ToTSV;
    WriteLn;
    TestTBenchResults_ToHTML;
    WriteLn;
    TestTBenchResults_HasRegression;
    WriteLn;
    TestTBenchResults_SaveToJSON;
    WriteLn;
    TestTBenchResults_SaveToHTML;
    WriteLn;
    TestTBenchResults_SaveToTSV;
    WriteLn;
    TestTBenchSuite_FluentAPI;
  finally
    GParallelLock.Free;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
  begin
    WriteLn;
    WriteLn('✗ ', GFailCount, ' test(s) failed!');
    Halt(1);
  end
  else
  begin
    WriteLn;
    WriteLn('✓ All tests passed!');
  end;
end.
