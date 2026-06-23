unit nextpas.core.bench.runner;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.time.base,
  nextpas.core.platform.time;

type
  {** 基准上下文实现 }
  TBenchContext = class(TInterfacedObject, IBenchContext)
  private
    FIterations: Int64;
    FBytesPerOp: Int64;
    FAllocsPerOp: Int64;
    FStartNs: UInt64;
    FElapsedNs: UInt64;
    FSkipped: Boolean;
    FSkipReason: string;
    FName: string; { ST-03: benchmark name }

  public
    constructor Create;

    {** IBenchContext 实现 }
    procedure SetBytes(ABytes: Int64);
    procedure SetAllocs(AAllocs: Int64);
    procedure AddBytes(ABytes: Int64); { DS-14 }
    procedure AddAllocs(AAllocs: Int64); { DS-14 }
    procedure ResetTimer;
    procedure Skip(const AReason: string);
    function GetIterations: Int64;
    function GetElapsed: TDuration;
    function GetBytesPerOp: Int64;
    function GetAllocsPerOp: Int64;
    function GetName: string; { ST-03 }

    {** 内部方法 }
    procedure Reset;
    procedure IncrementIterations;
    procedure SetIterations(AValue: Int64);
    procedure SetName(const AName: string); { ST-03 }
    function IsSkipped: Boolean;
    function GetSkipReason: string;
    function GetStartNs: UInt64;

    {** 记录并获取经过的时间（纳秒）—— CR-10: 并行桥接逐线程计时 }
    procedure RecordElapsed;
    function GetElapsedNs: UInt64;
  end;

  {** 基准执行器 }
  TBenchRunner = class
  private
    FConfig: TBenchConfig;
    FFilter: string;
    FFilterLower: string; { PF-08: cached lowercase filter }
    FStatsAnalyzer: IBenchStatsAnalyzer;
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FResultCapacity: Integer;
    FParallelBridgeFunc: TBenchFunc;
    FParallelContexts: array of IBenchContext;
    FParallelContextsInitialized: Boolean;

    {** 热身 }
    procedure WarmupEntry(const AEntry: TBenchEntry);

    {** 采集多个样本 }
    function CollectEntrySamples(const AEntry: TBenchEntry; AIters: Int64;
      out AFirstSample: TBenchResult): TDoubleArray;

    {** 构建简单条目 }
    function BuildEntry(const AName: string; AFunc: TBenchFunc): TBenchEntry;

    {** 执行单个条目一次 }
    function ExecuteEntry(const AEntry: TBenchEntry; AIters: Int64;
      ATrackMemory: Boolean): TBenchResult;

    {** 校准条目迭代次数 }
    function CalibrateEntryIterations(const AEntry: TBenchEntry): Int64;

    {** 计算单次操作时间（纳秒） }
    function ComputeNsPerOp(ATotalNs: UInt64; AIters: Int64): Double;

    {** 计算每秒操作数 }
    function ComputeOpsPerSec(ANsPerOp: Double): Double;

    {** 检查是否应该运行 }
    function ShouldRun(const AName: string): Boolean;

    {** 添加结果 }
    procedure AddResult(const AResult: TBenchResult);

    {** 从环境变量加载配置 }
    procedure LoadConfigFromEnv;
    procedure InitParallelContexts(AThreadCount: Integer);
    procedure FinalizeParallelContexts;

  public
    constructor Create;
    destructor Destroy; override;

    {** 测量函数执行时间 }
    function MeasureNs(AFunc: TBenchFunc; AIters: Int64): UInt64;

    {** 校准迭代次数 }
    function CalibrateIterations(AFunc: TBenchFunc): Int64;

    {** 运行单个基准测试 }
    function RunOne(const AName: string; AFunc: TBenchFunc): TBenchResult;
    function RunOne(const AEntry: TBenchEntry): TBenchResult; overload;

    {** 运行多个基准测试 }
    procedure RunAll(const AEntries: array of TBenchEntry);

    {** 获取所有结果 }
    function GetResults: TBenchResultArray;

    {** 获取结果数量 }
    function GetResultCount: Integer;

    {** 清空结果 }
    procedure ClearResults;

    {** 配置方法 }
    procedure SetConfig(const AConfig: TBenchConfig);
    function GetConfig: TBenchConfig;
    procedure SetFilter(const AFilter: string);

    {** 属性访问 }
    property Config: TBenchConfig read GetConfig write SetConfig;
    property Filter: string read FFilter write SetFilter;
    property ResultCount: Integer read GetResultCount;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.bench.memtrack,
  nextpas.core.bench.parallel;

type
  TParallelBridgeData = record
    Runner: TBenchRunner;
    Func: TBenchFunc;
    ParamFunc: TBenchParamFunc;
    ParamValue: Int64;
  end;

{** 并行基准桥接数据（全局单例）
 *  约束：同一时刻只能有一个 TBenchSuite.Run 在执行。
 *  当前设计中 TBenchSuite.Run 顺序遍历 entries，不存在并发 suite 调用。
 *  WaitFor 隐含内存屏障，保证 worker 线程写入对主线程可见。
 *  若未来支持并发 suite 执行，需将此数据移入 TBenchRunner 实例。 }
var
  GBridgeData: TParallelBridgeData;

{** 并行基准桥接函数
 *
 *  CR-10 修复：记录线程起始/结束时间（通过 RecordElapsed），
 *  并传播到 FParallelContexts 以便 RunOne 计算精确的 NsPerOp。 }
procedure ParallelBenchBridge(AThreadId: Integer; AIterations: Int64);
var
  LContext: IBenchContext;
  LContextObj: TBenchContext;
  LIteration: Int64;
  LRunner: TBenchRunner;
begin
  LRunner := GBridgeData.Runner;
  if (LRunner = nil) or
     ((not Assigned(GBridgeData.Func)) and (not Assigned(GBridgeData.ParamFunc))) then
    Exit;

  LContext := TBenchContext.Create;
  LContextObj := LContext as TBenchContext;
  for LIteration := 1 to AIterations do
  begin
    LContextObj.SetIterations(LIteration);
    if Assigned(GBridgeData.ParamFunc) then
      GBridgeData.ParamFunc(LContext, GBridgeData.ParamValue)
    else
      GBridgeData.Func(LContext);
    if LContextObj.IsSkipped then
      Break;
  end;

  // CR-10: Record wall-clock elapsed time for this thread
  LContextObj.RecordElapsed;

  if LRunner.FParallelContextsInitialized and
     (AThreadId >= 0) and
     (AThreadId < Length(LRunner.FParallelContexts)) then
  begin
    LRunner.FParallelContexts[AThreadId] := TBenchContext.Create;
    (LRunner.FParallelContexts[AThreadId] as TBenchContext).SetIterations(LContextObj.GetIterations);
    (LRunner.FParallelContexts[AThreadId] as TBenchContext).SetBytes(LContextObj.GetBytesPerOp);
    (LRunner.FParallelContexts[AThreadId] as TBenchContext).SetAllocs(LContextObj.GetAllocsPerOp);
    if LContextObj.IsSkipped then
      (LRunner.FParallelContexts[AThreadId] as TBenchContext).Skip(LContextObj.GetSkipReason);
    // CR-10: Propagate elapsed ns from bridge context to parallel context
    (LRunner.FParallelContexts[AThreadId] as TBenchContext).FElapsedNs := LContextObj.GetElapsedNs;
  end;
end;

{ TBenchContext }

constructor TBenchContext.Create;
begin
  inherited Create;
  FIterations := 0;
  FBytesPerOp := 0;
  FAllocsPerOp := 0;
  FStartNs := platform_monotonic_ns;
  FElapsedNs := 0;
  FSkipped := False;
  FSkipReason := '';
end;

procedure TBenchContext.SetBytes(ABytes: Int64);
begin
  FBytesPerOp := ABytes;
end;

procedure TBenchContext.SetAllocs(AAllocs: Int64);
begin
  FAllocsPerOp := AAllocs;
end;

procedure TBenchContext.AddBytes(ABytes: Int64);
begin
  Inc(FBytesPerOp, ABytes);
end;

procedure TBenchContext.AddAllocs(AAllocs: Int64);
begin
  Inc(FAllocsPerOp, AAllocs);
end;

procedure TBenchContext.ResetTimer;
begin
  FStartNs := platform_monotonic_ns;
end;

procedure TBenchContext.Skip(const AReason: string);
begin
  FSkipped := True;
  FSkipReason := AReason;
end;

function TBenchContext.GetIterations: Int64;
begin
  Result := FIterations;
end;

function TBenchContext.GetElapsed: TDuration;
var
  LCurrentNs: UInt64;
begin
  LCurrentNs := platform_monotonic_ns;
  if LCurrentNs < FStartNs then
    Exit(TDuration.FromNanoseconds(0));
  Result := TDuration.FromNanoseconds(LCurrentNs - FStartNs);
end;

function TBenchContext.GetBytesPerOp: Int64;
begin
  Result := FBytesPerOp;
end;

function TBenchContext.GetAllocsPerOp: Int64;
begin
  Result := FAllocsPerOp;
end;

function TBenchContext.GetName: string;
begin
  Result := FName;
end;

procedure TBenchContext.SetName(const AName: string);
begin
  FName := AName;
end;

procedure TBenchContext.Reset;
begin
  FIterations := 0;
  FBytesPerOp := 0;
  FAllocsPerOp := 0;
  FStartNs := platform_monotonic_ns;
  FElapsedNs := 0;
  FSkipped := False;
  FSkipReason := '';
end;

procedure TBenchContext.IncrementIterations;
begin
  Inc(FIterations);
end;

procedure TBenchContext.SetIterations(AValue: Int64);
begin
  FIterations := AValue;
end;

function TBenchContext.IsSkipped: Boolean;
begin
  Result := FSkipped;
end;

function TBenchContext.GetSkipReason: string;
begin
  Result := FSkipReason;
end;

function TBenchContext.GetStartNs: UInt64;
begin
  Result := FStartNs;
end;

procedure TBenchContext.RecordElapsed;
var
  LCurrentNs: UInt64;
begin
  LCurrentNs := platform_monotonic_ns;
  if LCurrentNs >= FStartNs then
    FElapsedNs := LCurrentNs - FStartNs
  else
    FElapsedNs := 0;
end;

function TBenchContext.GetElapsedNs: UInt64;
begin
  Result := FElapsedNs;
end;

{ TBenchRunner }

constructor TBenchRunner.Create;
begin
  inherited Create;
  FStatsAnalyzer := TBenchStatsAnalyzer.Create;
  FResultCount := 0;
  FResultCapacity := 0;
  FParallelBridgeFunc := nil;
  FParallelContextsInitialized := False;
  SetLength(FResults, 0);
  SetLength(FParallelContexts, 0);
  LoadConfigFromEnv;
end;

destructor TBenchRunner.Destroy;
begin
  FinalizeParallelContexts;
  SetLength(FResults, 0);
  inherited Destroy;
end;

procedure TBenchRunner.InitParallelContexts(AThreadCount: Integer);
var
  LIndex: Integer;
begin
  SetLength(FParallelContexts, AThreadCount);
  for LIndex := 0 to AThreadCount - 1 do
    FParallelContexts[LIndex] := nil;
  FParallelContextsInitialized := True;
end;

procedure TBenchRunner.FinalizeParallelContexts;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FParallelContexts) do
    FParallelContexts[LIndex] := nil;
  SetLength(FParallelContexts, 0);
  FParallelContextsInitialized := False;
end;

procedure TBenchRunner.LoadConfigFromEnv;
var
  LValue: string;
  LTmp: Int64;
begin
  // 加载默认配置
  FConfig.MinDurationNs := BENCH_DEFAULT_MIN_DURATION_NS;
  FConfig.MaxIterations := BENCH_DEFAULT_MAX_ITERATIONS;
  FConfig.MinSamples := BENCH_DEFAULT_MIN_SAMPLES;
  FConfig.WarmupIterations := BENCH_DEFAULT_WARMUP_ITERATIONS;
  FConfig.EnableMemoryTracking := True;
  FConfig.EnableParallel := False;
  FConfig.ParallelThreads := BENCH_DEFAULT_PARALLEL_THREADS;
  FConfig.CollectRawSamples := False;
  FConfig.Quiet := False;

  // DS-09/DS-10: unified TryStrToInt64 parsing with range validation

  LValue := GetEnvironmentVariable(BENCH_ENV_MAX_ITERS);
  if (LValue <> '') and TryStrToInt64(LValue, LTmp) then
  begin
    if LTmp < 100 then LTmp := 100;
    FConfig.MaxIterations := LTmp;
  end;

  LValue := GetEnvironmentVariable(BENCH_ENV_MIN_DURATION);
  if (LValue <> '') and TryStrToInt64(LValue, LTmp) then
  begin
    if LTmp < 1 then LTmp := 1;
    FConfig.MinDurationNs := UInt64(LTmp);
  end;

  LValue := GetEnvironmentVariable(BENCH_ENV_MIN_SAMPLES);
  if (LValue <> '') and TryStrToInt64(LValue, LTmp) then
  begin
    if LTmp < 1 then LTmp := 1;
    if LTmp > 100000 then LTmp := 100000;
    FConfig.MinSamples := Integer(LTmp);
  end;

  LValue := GetEnvironmentVariable(BENCH_ENV_WARMUP);
  if (LValue <> '') and TryStrToInt64(LValue, LTmp) then
  begin
    if LTmp < 0 then LTmp := 0;
    if LTmp > 100000 then LTmp := 100000;
    FConfig.WarmupIterations := Integer(LTmp);
  end;

  LValue := GetEnvironmentVariable(BENCH_ENV_QUIET);
  if LValue <> '' then
    if (LValue = '1') or (LowerCase(LValue) = 'true') or (LowerCase(LValue) = 'yes') then
      FConfig.Quiet := True;

  LValue := GetEnvironmentVariable(BENCH_ENV_NO_MEMTRACK);
  if LValue <> '' then
    if (LValue = '1') or (LowerCase(LValue) = 'true') or (LowerCase(LValue) = 'yes') then
      FConfig.EnableMemoryTracking := False;

  FFilter := GetEnvironmentVariable(BENCH_ENV_FILTER);
  FFilterLower := LowerCase(FFilter); { PF-08 }
end;

function TBenchRunner.MeasureNs(AFunc: TBenchFunc; AIters: Int64): UInt64;
begin
  Result := ExecuteEntry(BuildEntry('', AFunc), AIters, False).TotalNs;
end;

function TBenchRunner.CalibrateIterations(AFunc: TBenchFunc): Int64;
begin
  Result := CalibrateEntryIterations(BuildEntry('', AFunc));
end;

function TBenchRunner.BuildEntry(const AName: string; AFunc: TBenchFunc): TBenchEntry;
begin
  Result := Default(TBenchEntry);
  Result.Name := AName;
  Result.Func := AFunc;
  Result.Condition := True;
end;

function TBenchRunner.ExecuteEntry(const AEntry: TBenchEntry; AIters: Int64;
  ATrackMemory: Boolean): TBenchResult;
var
  LContext: IBenchContext;
  LContextObj: TBenchContext;
  LMemoryStats: TMemoryStats;
  LParallelResult: TParallelBenchResult;
  LPerThreadIterations: Int64;
  LMaxThreadElapsedNs: UInt64;
  I: Int64;
begin
  Result := Default(TBenchResult);
  Result.Executed := True;
  Result.Name := AEntry.Name;

  if AIters <= 0 then
    Exit;

  { CR-13 Known Limitation: Loop path (TBenchLoopFunc) does not support IBenchContext.
  *  TBenchLoopFunc takes only (AIters: Int64) — no context parameter is available.
  *  Therefore, loop benchmarks cannot use SetBytes/SetAllocs/Skip/ResetTimer.
  *  Use the regular TBenchFunc path if context operations are needed. }
  if AEntry.IsLoop and Assigned(AEntry.LoopFunc) then
  begin
    LContext := TBenchContext.Create;
    LContextObj := LContext as TBenchContext;
    LContextObj.SetName(AEntry.Name); { ST-03 }
    try
      if ATrackMemory then
      begin
        EnableGlobalMemoryTracking;
        ResetGlobalMemoryTracker;
      end;
      try
        LContextObj.Reset;
        LContextObj.SetIterations(AIters);
        AEntry.LoopFunc(AIters);

        Result.Iterations := AIters;
        Result.TotalNs := platform_monotonic_ns - LContextObj.GetStartNs;
        Result.Skipped := LContextObj.IsSkipped;
        Result.SkipReason := LContextObj.GetSkipReason;

        if ATrackMemory then
        begin
          LMemoryStats := GetGlobalMemoryStats;
          if Result.Iterations > 0 then
          begin
            // PF-12: unconditional assignment (BytesPerOp/AllocsPerOp always 0 at this point)
            Result.BytesPerOp := Ceil(LMemoryStats.AllocBytes / Result.Iterations);
            Result.AllocsPerOp := Ceil(LMemoryStats.AllocCount / Result.Iterations);
          end;
        end;
      finally
        if ATrackMemory then
          DisableGlobalMemoryTracking;
      end;
    finally
      LContext := nil;
    end;
    Exit;
  end;

  if AEntry.EnableParallel and (AEntry.ParallelThreads > 1) then
  begin
    // 并行基准自动跳过内存跟踪
    if ATrackMemory and (not FConfig.Quiet) then
      WriteLn('  WARNING: Memory tracking disabled for parallel benchmark "', AEntry.Name, '"');
    ATrackMemory := False;

    LPerThreadIterations := AIters div AEntry.ParallelThreads;
    if (AIters mod AEntry.ParallelThreads) <> 0 then
      Inc(LPerThreadIterations);
    if LPerThreadIterations < 1 then
      LPerThreadIterations := 1;

    // 初始化并行上下文收集
    InitParallelContexts(AEntry.ParallelThreads);
    try
      FParallelBridgeFunc := AEntry.Func;
      GBridgeData.Runner := Self;
      GBridgeData.Func := FParallelBridgeFunc;
      GBridgeData.ParamFunc := AEntry.ParamFunc;
      GBridgeData.ParamValue := AEntry.ParamValue;
      try
        LParallelResult := RunParallelBench(@ParallelBenchBridge,
          AEntry.ParallelThreads, LPerThreadIterations);
      finally
        GBridgeData.Func := nil;
        GBridgeData.ParamFunc := nil;
        GBridgeData.ParamValue := 0;
        GBridgeData.Runner := nil;
        FParallelBridgeFunc := nil;
      end;

      // 聚合并行上下文数据
      Result.Iterations := LPerThreadIterations * AEntry.ParallelThreads;
      Result.TotalNs := LParallelResult.TotalNs;

      // CR-10: 从并行上下文聚合逐线程耗时，使用最大值
      LMaxThreadElapsedNs := 0;
      for I := 0 to High(FParallelContexts) do
      begin
        if Assigned(FParallelContexts[I]) then
        begin
          if (FParallelContexts[I] as TBenchContext).GetElapsedNs > LMaxThreadElapsedNs then
            LMaxThreadElapsedNs := (FParallelContexts[I] as TBenchContext).GetElapsedNs;
          if (FParallelContexts[I] as TBenchContext).GetBytesPerOp > Result.BytesPerOp then
            Result.BytesPerOp := (FParallelContexts[I] as TBenchContext).GetBytesPerOp;
          if (FParallelContexts[I] as TBenchContext).GetAllocsPerOp > Result.AllocsPerOp then
            Result.AllocsPerOp := (FParallelContexts[I] as TBenchContext).GetAllocsPerOp;
        end;
      end;

      // 检查是否有任何线程跳过了
      for I := 0 to High(FParallelContexts) do
      begin
        if Assigned(FParallelContexts[I]) and (FParallelContexts[I] as TBenchContext).IsSkipped then
        begin
          Result.Skipped := True;
          Result.SkipReason := (FParallelContexts[I] as TBenchContext).GetSkipReason;
          Result.Iterations := (FParallelContexts[I] as TBenchContext).GetIterations * AEntry.ParallelThreads;
          Break;
        end;
      end;
    finally
      FinalizeParallelContexts;
    end;
    Exit;
  end;

  // 通过接口创建，refcount 正确管理
  LContext := TBenchContext.Create;
  LContextObj := LContext as TBenchContext;
  LContextObj.SetName(AEntry.Name); { ST-03 }
  try
    if ATrackMemory then
    begin
      EnableGlobalMemoryTracking;
      ResetGlobalMemoryTracker;
    end;
    try
      LContextObj.Reset;
      for I := 1 to AIters do
      begin
        LContextObj.SetIterations(I);
        if Assigned(AEntry.ParamFunc) then
          AEntry.ParamFunc(LContext, AEntry.ParamValue)
        else
          AEntry.Func(LContext);
        if LContextObj.IsSkipped then
          Break;
      end;

      Result.Iterations := LContextObj.GetIterations;
      Result.TotalNs := platform_monotonic_ns - LContextObj.GetStartNs;
      Result.BytesPerOp := LContextObj.GetBytesPerOp;
      Result.AllocsPerOp := LContextObj.GetAllocsPerOp;
      Result.Skipped := LContextObj.IsSkipped;
      Result.SkipReason := LContextObj.GetSkipReason;

      if ATrackMemory then
      begin
        LMemoryStats := GetGlobalMemoryStats;
        if (Result.Iterations > 0) and (Result.BytesPerOp = 0) then
          Result.BytesPerOp := Ceil(LMemoryStats.AllocBytes / Result.Iterations);
        if (Result.Iterations > 0) and (Result.AllocsPerOp = 0) then
          Result.AllocsPerOp := Ceil(LMemoryStats.AllocCount / Result.Iterations);
      end;
    finally
      if ATrackMemory then
        DisableGlobalMemoryTracking;
    end;
  finally
    LContext := nil;
  end;
end;

function TBenchRunner.CalibrateEntryIterations(const AEntry: TBenchEntry): Int64;
var
  LElapsed: UInt64;
  LIters: Int64;
  LMaxIters: Int64;
  LTargetNs: UInt64;
  LProbe: TBenchResult;
  LProjectedIters: Double;
  LReachedMaxIters: Boolean;
  function ScaleIterationsByTen(const AValue, AMaxValue: Int64;
    out AReachedMaxValue: Boolean): Int64;
  begin
    if AValue >= AMaxValue then
    begin
      Result := AMaxValue;
      AReachedMaxValue := True;
      Exit;
    end;

    if AValue > (AMaxValue div 10) then
    begin
      Result := AMaxValue;
      AReachedMaxValue := True;
      Exit;
    end;

    Result := AValue * 10;
    AReachedMaxValue := False;
  end;
begin
  LTargetNs := FConfig.MinDurationNs;
  LMaxIters := FConfig.MaxIterations;

  WarmupEntry(AEntry);

  LIters := 100;
  repeat
    LProbe := ExecuteEntry(AEntry, LIters, False);
    if LProbe.Skipped then
      Exit(Max(LProbe.Iterations, 1));
    LElapsed := LProbe.TotalNs;

    if LElapsed = 0 then
    begin
      LIters := ScaleIterationsByTen(LIters, LMaxIters, LReachedMaxIters);
      if LReachedMaxIters then
        Break;
    end
    else if LElapsed < LTargetNs div 10 then
    begin
      LIters := ScaleIterationsByTen(LIters, LMaxIters, LReachedMaxIters);
      if LReachedMaxIters then
        Break;
    end
    else if LElapsed < LTargetNs then
    begin
      LProjectedIters := (Double(LIters) * Double(LTargetNs)) / Double(LElapsed);
      if LProjectedIters >= Double(LMaxIters) then
      begin
        LIters := LMaxIters;
        Break;
      end;
      LIters := Int64(LProjectedIters);
    end
    else
      Break;

    if LIters > LMaxIters then
    begin
      LIters := LMaxIters;
      Break;
    end;
    if LIters < 100 then
      LIters := 100;
  until False;

  Result := LIters;
end;

procedure TBenchRunner.WarmupEntry(const AEntry: TBenchEntry);
var
  i: Integer;
begin
  for i := 1 to FConfig.WarmupIterations do
    ExecuteEntry(AEntry, 1, False);
end;

function TBenchRunner.CollectEntrySamples(const AEntry: TBenchEntry; AIters: Int64;
  out AFirstSample: TBenchResult): TDoubleArray;
var
  LSamples: TDoubleArray;
  LMeasurement: TBenchResult;
  LMinSamples: Integer;
  i: Integer;
begin
  AFirstSample := Default(TBenchResult);

  // PF-17: enforce MinSamples >= 1 to prevent empty arrays
  LMinSamples := FConfig.MinSamples;
  if LMinSamples < 1 then
    LMinSamples := 1;

  SetLength(LSamples, LMinSamples);

  for i := 0 to LMinSamples - 1 do
  begin
    LMeasurement := ExecuteEntry(AEntry, AIters, FConfig.EnableMemoryTracking and (i = 0));
    if i = 0 then
      AFirstSample := LMeasurement;

    if LMeasurement.Iterations > 0 then
      LSamples[i] := Double(LMeasurement.TotalNs) / Double(LMeasurement.Iterations)
    else
      LSamples[i] := 0.0;

    if LMeasurement.Skipped then
    begin
      SetLength(LSamples, i + 1);
      Break;
    end;
  end;

  Result := LSamples;
end;

function TBenchRunner.ComputeNsPerOp(ATotalNs: UInt64; AIters: Int64): Double;
begin
  if AIters > 0 then
    Result := Double(ATotalNs) / Double(AIters)
  else
    Result := 0.0;
end;

function TBenchRunner.ComputeOpsPerSec(ANsPerOp: Double): Double;
begin
  if ANsPerOp > 0 then
    Result := 1000000000.0 / ANsPerOp
  else
    Result := 0.0;
end;

function TBenchRunner.ShouldRun(const AName: string): Boolean;
begin
  Result := (FFilterLower = '') or
    (Pos(FFilterLower, LowerCase(AName)) > 0); { PF-08: use cached lowercase }
end;

procedure TBenchRunner.AddResult(const AResult: TBenchResult);
begin
  if FResultCount >= FResultCapacity then
  begin
    if FResultCapacity = 0 then
      FResultCapacity := 8
    else
      FResultCapacity := FResultCapacity * 2;
    SetLength(FResults, FResultCapacity);
  end;
  FResults[FResultCount] := AResult;
  Inc(FResultCount);
end;

function TBenchRunner.RunOne(const AName: string; AFunc: TBenchFunc): TBenchResult;
begin
  Result := RunOne(BuildEntry(AName, AFunc));
end;

function TBenchRunner.RunOne(const AEntry: TBenchEntry): TBenchResult;
var
  LEntry: TBenchEntry;
  LSetupData: Pointer;
  LIters: Int64;
  LSamples: TDoubleArray;
  LStats: TBenchStats;
  LMeasurement: TBenchResult;
begin
  LEntry := AEntry;
  Result := Default(TBenchResult);
  Result.Name := LEntry.Name;

  if not ShouldRun(LEntry.Name) then
  begin
    Exit;
  end;

  Result.Executed := True;
  LSetupData := nil;
  if Assigned(LEntry.Setup) then
    LSetupData := LEntry.Setup();
  try
    LIters := CalibrateEntryIterations(LEntry);

    LSamples := CollectEntrySamples(LEntry, LIters, LMeasurement);
    if LMeasurement.Skipped then
    begin
      Result.Iterations := LMeasurement.Iterations;
      Result.TotalNs := LMeasurement.TotalNs;
      Result.BytesPerOp := LMeasurement.BytesPerOp;
      Result.AllocsPerOp := LMeasurement.AllocsPerOp;
      Result.Skipped := True;
      Result.SkipReason := LMeasurement.SkipReason;
      AddResult(Result);
      Exit;
    end;

    LStats := FStatsAnalyzer.ComputeStats(LSamples);

    Result.Iterations := LIters;
    Result.TotalNs := UInt64(Round(LStats.Mean * LIters));
    Result.NsPerOp := LStats.Mean;
    Result.OpsPerSec := ComputeOpsPerSec(LStats.Mean);
    Result.BytesPerOp := LMeasurement.BytesPerOp;
    Result.AllocsPerOp := LMeasurement.AllocsPerOp;
    Result.StdDev := LStats.StdDev;
    Result.Median := LStats.Median;
    Result.P95 := LStats.P95;
    Result.P99 := LStats.P99;
    Result.Outliers := LStats.OutlierCount;
    Result.SampleCount := LStats.SampleCount;
    if FConfig.CollectRawSamples then
      Result.RawSamples := LSamples;

    AddResult(Result);

    if not FConfig.Quiet then
      WriteLn('  ', LEntry.Name:40, LIters:12, ' iters',
        LStats.Mean:10:1, ' ns/op',
        Result.OpsPerSec:14:0, ' ops/s',
        LStats.StdDev:10:1, ' stddev');
  finally
    if Assigned(LEntry.Teardown) then
      LEntry.Teardown(LSetupData);
  end;
end;

procedure TBenchRunner.RunAll(const AEntries: array of TBenchEntry);
var
  i: Integer;
begin
  if not FConfig.Quiet then
  begin
    WriteLn('=== nextpas.core.bench v1.0 ===');
    WriteLn;
  end;

  for i := 0 to High(AEntries) do
  begin
    if AEntries[i].Condition then
      RunOne(AEntries[i]);
  end;

  if not FConfig.Quiet then
  begin
    WriteLn;
    WriteLn('=== Summary ===');
    for i := 0 to FResultCount - 1 do
    begin
      WriteLn('  ', FResults[i].Name:40,
        FResults[i].NsPerOp:10:1, ' ns/op',
        FResults[i].OpsPerSec:14:0, ' ops/s');
    end;
  end;
end;

function TBenchRunner.GetResults: TBenchResultArray;
begin
  Result := FResults;
end;

function TBenchRunner.GetResultCount: Integer;
begin
  Result := FResultCount;
end;

procedure TBenchRunner.ClearResults;
begin
  FResultCount := 0;
  FResultCapacity := 0;
  SetLength(FResults, 0);
end;

procedure TBenchRunner.SetConfig(const AConfig: TBenchConfig);
begin
  FConfig := AConfig;
end;

function TBenchRunner.GetConfig: TBenchConfig;
begin
  Result := FConfig;
end;

procedure TBenchRunner.SetFilter(const AFilter: string);
begin
  FFilter := AFilter;
  FFilterLower := LowerCase(AFilter); { PF-08: cache lowercase }
end;

end.
