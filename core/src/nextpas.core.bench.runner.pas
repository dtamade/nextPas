{**
 * @desc 基准测试执行引擎
 *
 * 提供 TBenchContext 测量上下文和 TBenchRunner 执行器，
 * 实现自适应迭代、预热、统计收集等核心测量逻辑。
 *}
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
    FPausedNs: UInt64;  { StopTimer 记录暂停时刻 }
    FCustomMetrics: TCustomMetricArray;

  public
    constructor Create;

    {** IBenchContext 实现 }
    procedure SetBytes(ABytes: Int64);
    procedure SetAllocs(AAllocs: Int64);
    procedure AddBytes(ABytes: Int64); { DS-14 }
    procedure AddAllocs(AAllocs: Int64); { DS-14 }
    procedure ResetTimer;
    procedure StopTimer;
    procedure StartTimer;
    procedure Skip(const AReason: string);
    function GetIterations: Int64;
    function GetElapsed: TDuration;
    function GetBytesPerOp: Int64;
    function GetAllocsPerOp: Int64;
    function GetName: string; { ST-03 }
    procedure SetCustomMetric(const AName: string; AValue: Double);
    function GetCustomMetrics: TCustomMetricArray;

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

  {** 基准执行器
   *
   *  DS-13 Thread Safety Constraint:
   *  TBenchRunner is NOT thread-safe. It contains mutable state (FResults,
   *  FConfig, FParallelContexts, FBridgeFunc) with no internal synchronization.
   *  All methods must be called from a single owning thread.
   *
   *  Parallel benchmarks are handled by delegating to TParallelBenchmark
   *  (in nextpas.core.bench.parallel), which manages its own thread pool.
   *  The parallel bridge communicates back through the instance's FBridgeFunc
   *  and FParallelContexts, but only after the WaitFor barrier ensures all
   *  worker threads have completed.
   *
   *  If concurrent suite execution is needed in the future, each suite
   *  must own its own TBenchRunner instance. }
  TBenchRunner = class
  private
    FConfig: TBenchConfig;
    FFilter: string;
    FFilterLower: string; { PF-08: cached lowercase filter }
    FFilterIsGlob: Boolean; { 预计算：filter 是否含 glob 字符 }
    FStatsAnalyzer: IBenchStatsAnalyzer;
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FResultCapacity: Integer;
    FParallelBridgeFunc: TBenchFunc;
    FParallelContexts: array of IBenchContext;
    FParallelContextsInitialized: Boolean;
    { F-01: bridge data as instance fields (was file-scope GBridgeData global) }
    FBridgeFunc: TBenchFunc;
    FBridgeParamFunc: TBenchParamFunc;
    FBridgeSimpleFunc: TBenchSimpleFunc;
    FBridgeParamValue: Int64;
    {** 公共初始化逻辑（Create/CreateNoEnv 共用） }
    procedure InitDefaults;

    {** 热身 }
    procedure WarmupEntry(const AEntry: TBenchEntry);

    {** 采集多个样本 }
    function CollectEntrySamples(const AEntry: TBenchEntry; AIters: Int64;
      out AFirstSample: TBenchResult;
      ATimeoutMs: Int64 = 0; ATimeoutStartNs: UInt64 = 0): TDoubleArray;

    {** 构建简单条目 }
    function BuildEntry(const AName: string; AFunc: TBenchFunc): TBenchEntry;

    {** 执行单个条目一次 }
    function ExecuteEntry(const AEntry: TBenchEntry; AIters: Int64;
      ATrackMemory: Boolean): TBenchResult;

    {** PF-11: ExecuteEntry 拆分为三个独立路径 }
    function ExecuteLoopEntry(const AEntry: TBenchEntry; AIters: Int64;
      ATrackMemory: Boolean): TBenchResult;
    function ExecuteParallelEntry(const AEntry: TBenchEntry; AIters: Int64;
      ATrackMemory: Boolean): TBenchResult;
    function ExecuteSequentialEntry(const AEntry: TBenchEntry; AIters: Int64;
      ATrackMemory: Boolean): TBenchResult;

    {** 校准条目迭代次数 }
    function CalibrateEntryIterations(const AEntry: TBenchEntry): Int64;

    {** 从上下文和内存统计填充结果（公共逻辑） }
    procedure PopulateResult(var AResult: TBenchResult;
      const AContext: TBenchContext; ATrackMemory: Boolean);

    {** 计算单操作时间（纳秒） }
    function ComputeNsPerOp(ATotalNs: UInt64; AIters: Int64): Double;

    {** 计算每秒操作数 }
    function ComputeOpsPerSec(ANsPerOp: Double): Double;

    {** 检查是否应该运行（ALowerName 为预计算的小写名称） }
    function ShouldRun(const AName: string; const ALowerName: string): Boolean;

    {** 添加结果 }
    procedure AddResult(const AResult: TBenchResult);

    {** 输出一行 — 通过 Output ILineWriter }
    procedure EmitLine(const ALine: string);
    procedure EmitLineStdErr(const ALine: string);

    {** 从环境变量加载配置 }
    procedure LoadConfigFromEnv;
    procedure InitParallelContexts(AThreadCount: Integer);
    procedure FinalizeParallelContexts;

  public
    constructor Create;
    {** 跳过环境变量加载（CreateWithConfig 内部使用） }
    constructor CreateNoEnv;
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

    {** B21: 启用自适应预热 }
    procedure SetAdaptiveWarmup(AEnabled: Boolean;
      ACVThreshold: Double = BENCH_DEFAULT_WARMUP_CV_THRESHOLD;
      AMaxIterations: Integer = BENCH_DEFAULT_WARMUP_MAX_ITERATIONS);

    {** 便利方法：运行单个基准并累积结果（旧 API 兼容）。
     *  AFunc 是 TBenchLoopFunc，内部循环由框架控制。 }
    procedure Run(const AName: string; AFunc: TBenchLoopFunc);

    {** 便利方法：打印所有已累积结果的摘要 }
    procedure Summary;

    {** 属性访问 }
    property Config: TBenchConfig read GetConfig write SetConfig;
    property Filter: string read FFilter write SetFilter;
    property ResultCount: Integer read GetResultCount;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.utils,
  nextpas.core.os.env,
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.bench.memtrack,
  nextpas.core.bench.parallel,
  nextpas.core.io.linewriter;

{** F-01: GBridgeRunner is file-scope because ParallelBenchBridge's callback
 *  signature does not allow user data. Safe under DS-13 (single-runner). }
var
  GBridgeRunner: TBenchRunner;
  {** F-16: CAS flag to detect concurrent RunOne calls }
  GBridgeBusy: Integer = 0;

{** 并行基准桥接函数
 *
 *  CR-10 修复：记录线程起始/结束时间（通过 RecordElapsed），
 *  并传播到 FParallelContexts 以便 RunOne 计算精确的 NsPerOp。
 *
 *  F-01：桥接数据从 GBridgeRunner 实例字段读取。 }
procedure ParallelBenchBridge(AThreadId: Integer; AIterations: Int64);
var
  LContext: IBenchContext;
  LContextObj: TBenchContext;
  LIteration: Int64;
  LRunner: TBenchRunner;
  LTargetCtx: TBenchContext;
begin
  { F-01: runner instance accessed via file-scope GBridgeRunner }
  LRunner := GBridgeRunner;
  if (LRunner = nil) or
     ((not Assigned(LRunner.FBridgeFunc)) and
      (not Assigned(LRunner.FBridgeParamFunc)) and
      (not Assigned(LRunner.FBridgeSimpleFunc))) then
    Exit;

  LContext := TBenchContext.Create;
  LContextObj := LContext as TBenchContext;
  for LIteration := 1 to AIterations do
  begin
    LContextObj.SetIterations(LIteration);
    if Assigned(LRunner.FBridgeSimpleFunc) then
      LRunner.FBridgeSimpleFunc
    else if Assigned(LRunner.FBridgeParamFunc) then
      LRunner.FBridgeParamFunc(LContext, LRunner.FBridgeParamValue)
    else
      LRunner.FBridgeFunc(LContext);
    if LContextObj.IsSkipped then
      Break;
  end;

  // CR-10: Record wall-clock elapsed time for this thread
  LContextObj.RecordElapsed;

  if LRunner.FParallelContextsInitialized and
     (AThreadId >= 0) and
     (AThreadId < Length(LRunner.FParallelContexts)) and
     Assigned(LRunner.FParallelContexts[AThreadId]) then
  begin
    { F-01: write to pre-created context instead of creating new one }
    LTargetCtx := LRunner.FParallelContexts[AThreadId] as TBenchContext;
    LTargetCtx.SetIterations(LContextObj.GetIterations);
    LTargetCtx.SetBytes(LContextObj.GetBytesPerOp);
    LTargetCtx.SetAllocs(LContextObj.GetAllocsPerOp);
    if LContextObj.IsSkipped then
      LTargetCtx.Skip(LContextObj.GetSkipReason);
    // CR-10: Propagate elapsed ns from bridge context to parallel context
    LTargetCtx.FElapsedNs := LContextObj.GetElapsedNs;
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

procedure TBenchContext.StopTimer;
begin
  FPausedNs := platform_monotonic_ns;
end;

procedure TBenchContext.StartTimer;
var
  LNow: UInt64;
  LPausedDuration: UInt64;
begin
  if FPausedNs = 0 then
    Exit;  { StopTimer 未调用，忽略 }
  LNow := platform_monotonic_ns;
  LPausedDuration := LNow - FPausedNs;
  { 将 start 时间向前推移，等效扣除暂停时间 }
  FStartNs := FStartNs + LPausedDuration;
  FPausedNs := 0;
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

procedure TBenchContext.SetCustomMetric(const AName: string; AValue: Double);
var
  LLen: Integer;
  I: Integer;
begin
  { 查找是否已存在 }
  for I := 0 to High(FCustomMetrics) do
  begin
    if FCustomMetrics[I].Name = AName then
    begin
      FCustomMetrics[I].Value := AValue;
      Exit;
    end;
  end;

  { 新增 }
  LLen := Length(FCustomMetrics);
  SetLength(FCustomMetrics, LLen + 1);
  FCustomMetrics[LLen].Name := AName;
  FCustomMetrics[LLen].Value := AValue;
end;

function TBenchContext.GetCustomMetrics: TCustomMetricArray;
begin
  Result := FCustomMetrics;
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
  FPausedNs := 0;
  { 注意：不重置 FCustomMetrics，因为指标在多次迭代中累积 }
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

procedure TBenchRunner.InitDefaults;
begin
  FStatsAnalyzer := TBenchStatsAnalyzer.Create;
  FResultCount := 0;
  FResultCapacity := 0;
  FParallelBridgeFunc := nil;
  FParallelContextsInitialized := False;
  SetLength(FResults, 0);
  SetLength(FParallelContexts, 0);
end;

constructor TBenchRunner.Create;
begin
  inherited Create;
  InitDefaults;
  LoadConfigFromEnv;
end;

constructor TBenchRunner.CreateNoEnv;
begin
  inherited Create;
  InitDefaults;
  FConfig := DefaultBenchConfig;
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
  { F-01: pre-create all TBenchContext objects in main thread to avoid
    concurrent object creation in worker threads. }
  for LIndex := 0 to AThreadCount - 1 do
    FParallelContexts[LIndex] := TBenchContext.Create;
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
  LLower: string;
  LTmp: Int64;
begin
  // 加载默认配置
  FConfig := DefaultBenchConfig;

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
  begin
    LLower := LowerCase(LValue);
    if (LValue = '1') or (LLower = 'true') or (LLower = 'yes') or (LLower = 'on') then
      FConfig.Quiet := True;
  end;

  { DS-08: BENCH_ENV_MEMTRACK with positive semantics (1=yes, 0=no) }
  LValue := GetEnvironmentVariable(BENCH_ENV_MEMTRACK);
  if LValue <> '' then
  begin
    LLower := LowerCase(LValue);
    if (LValue = '0') or (LLower = 'false') or (LLower = 'no') then
      FConfig.EnableMemoryTracking := False;
  end;

  FFilter := GetEnvironmentVariable(BENCH_ENV_FILTER);
  FFilterLower := LowerCase(FFilter); { PF-08 }
  FFilterIsGlob := (Pos('*', FFilter) > 0) or (Pos('?', FFilter) > 0);
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
begin
  Result := Default(TBenchResult);
  Result.Executed := True;
  Result.Name := AEntry.Name;

  if AIters <= 0 then
    Exit;

  { F-01: LoopFunc (no context) or LoopContextFunc (with context) }
  if AEntry.IsLoop and (Assigned(AEntry.LoopFunc) or Assigned(AEntry.LoopContextFunc)) then
    Result := ExecuteLoopEntry(AEntry, AIters, ATrackMemory)
  else if AEntry.EnableParallel and (AEntry.ParallelThreads > 1) then
    Result := ExecuteParallelEntry(AEntry, AIters, ATrackMemory)
  else
    Result := ExecuteSequentialEntry(AEntry, AIters, ATrackMemory);
end;

procedure TBenchRunner.PopulateResult(var AResult: TBenchResult;
  const AContext: TBenchContext; ATrackMemory: Boolean);
var
  LMemoryStats: TMemoryStats;
begin
  AResult.Iterations := AContext.GetIterations;
  AResult.TotalNs := platform_monotonic_ns - AContext.GetStartNs;
  AResult.BytesPerOp := AContext.GetBytesPerOp;
  AResult.AllocsPerOp := AContext.GetAllocsPerOp;
  AResult.Skipped := AContext.IsSkipped;
  AResult.SkipReason := AContext.GetSkipReason;

  if ATrackMemory then
  begin
    LMemoryStats := GetGlobalMemoryStats;
    if (AResult.Iterations > 0) and (AResult.BytesPerOp = 0) then
      AResult.BytesPerOp := Ceil(LMemoryStats.AllocBytes / AResult.Iterations);
    if (AResult.Iterations > 0) and (AResult.AllocsPerOp = 0) then
      AResult.AllocsPerOp := Ceil(LMemoryStats.AllocCount / AResult.Iterations);
  end;

  AResult.CustomMetrics := AContext.GetCustomMetrics;
end;

function TBenchRunner.ExecuteLoopEntry(const AEntry: TBenchEntry; AIters: Int64;
  ATrackMemory: Boolean): TBenchResult;
var
  LContext: IBenchContext;
  LContextObj: TBenchContext;
begin
  Result := Default(TBenchResult);
  Result.Executed := True;
  Result.Name := AEntry.Name;

  LContext := TBenchContext.Create;
  LContextObj := LContext as TBenchContext;
  LContextObj.SetName(AEntry.Name);
  try
    if ATrackMemory then
    begin
      EnableGlobalMemoryTracking;
      ResetGlobalMemoryTracker;
    end;
    try
      LContextObj.Reset;
      LContextObj.SetIterations(AIters);
      { F-01: dispatch to LoopContextFunc (with context) or LoopFunc (without) }
      if Assigned(AEntry.LoopContextFunc) then
        AEntry.LoopContextFunc(LContext, AIters)
      else
        AEntry.LoopFunc(AIters);

      PopulateResult(Result, LContextObj, ATrackMemory);
    finally
      if ATrackMemory then
        DisableGlobalMemoryTracking;
    end;
  finally
    LContext := nil;
  end;
end;

function TBenchRunner.ExecuteParallelEntry(const AEntry: TBenchEntry; AIters: Int64;
  ATrackMemory: Boolean): TBenchResult;
var
  LParallelResult: TParallelBenchResult;
  LPerThreadIterations: Int64;
  I: SizeInt;
  LCtx: TBenchContext;
begin
  Result := Default(TBenchResult);
  Result.Executed := True;
  Result.Name := AEntry.Name;

  // 并行基准自动跳过内存跟踪
  if ATrackMemory and (not FConfig.Quiet) then
    EmitLineStdErr('  WARNING: Memory tracking disabled for parallel benchmark "' + AEntry.Name + '"');

  LPerThreadIterations := AIters div AEntry.ParallelThreads;
  if (AIters mod AEntry.ParallelThreads) <> 0 then
    Inc(LPerThreadIterations);
  if LPerThreadIterations < 1 then
    LPerThreadIterations := 1;

  InitParallelContexts(AEntry.ParallelThreads);
  try
    FParallelBridgeFunc := AEntry.Func;
    { F-01: bridge data stored in instance fields, not file-scope global }
    FBridgeFunc := FParallelBridgeFunc;
    FBridgeParamFunc := AEntry.ParamFunc;
    FBridgeSimpleFunc := AEntry.SimpleFunc;
    FBridgeParamValue := AEntry.ParamValue;
    { F-16: 并发断言 — 检测是否已有另一个 RunOne 在执行并行 benchmark }
    if InterlockedCompareExchange(GBridgeBusy, 1, 0) <> 0 then
      raise EBenchError.Create(
        'TBenchRunner: concurrent parallel benchmark execution detected. ' +
        'Each TBenchSuite must Run() from a single thread.');
    GBridgeRunner := Self;
    try
      LParallelResult := RunParallelBench(@ParallelBenchBridge,
        AEntry.ParallelThreads, LPerThreadIterations);
    finally
      FBridgeFunc := nil;
      FBridgeParamFunc := nil;
      FBridgeSimpleFunc := nil;
      FBridgeParamValue := 0;
      GBridgeRunner := nil;
      GBridgeBusy := 0;
      FParallelBridgeFunc := nil;
    end;

    Result.Iterations := LPerThreadIterations * AEntry.ParallelThreads;
    Result.TotalNs := LParallelResult.TotalNs;

    // CR-10: 从并行上下文聚合 BytesPerOp/AllocsPerOp
    for I := 0 to High(FParallelContexts) do
    begin
      if Assigned(FParallelContexts[I]) then
      begin
        LCtx := FParallelContexts[I] as TBenchContext;
        if LCtx.GetBytesPerOp > Result.BytesPerOp then
          Result.BytesPerOp := LCtx.GetBytesPerOp;
        if LCtx.GetAllocsPerOp > Result.AllocsPerOp then
          Result.AllocsPerOp := LCtx.GetAllocsPerOp;
      end;
    end;

    // 检查是否有任何线程跳过了
    for I := 0 to High(FParallelContexts) do
    begin
      if Assigned(FParallelContexts[I]) then
      begin
        LCtx := FParallelContexts[I] as TBenchContext;
        if LCtx.IsSkipped then
        begin
          Result.Skipped := True;
          Result.SkipReason := LCtx.GetSkipReason;
          Result.Iterations := LCtx.GetIterations * AEntry.ParallelThreads;
          Break;
        end;
      end;
    end;
  finally
    FinalizeParallelContexts;
  end;
end;

function TBenchRunner.ExecuteSequentialEntry(const AEntry: TBenchEntry; AIters: Int64;
  ATrackMemory: Boolean): TBenchResult;
var
  LContext: IBenchContext;
  LContextObj: TBenchContext;
  LIter: Int64;
begin
  Result := Default(TBenchResult);
  Result.Executed := True;
  Result.Name := AEntry.Name;

  LContextObj := TBenchContext.Create;
  LContext := LContextObj;

  LContextObj.SetName(AEntry.Name);
  try
    if ATrackMemory then
    begin
      EnableGlobalMemoryTracking;
      ResetGlobalMemoryTracker;
    end;
    try
      LContextObj.Reset;
      { PF-13: set iterations on context each time for user-visible correctness.
        The virtual dispatch overhead of SetIterations is minimal (field setter). }
      for LIter := 1 to AIters do
      begin
        LContextObj.SetIterations(LIter);
        if Assigned(AEntry.SimpleFunc) then
          AEntry.SimpleFunc
        else if Assigned(AEntry.ParamFunc) then
          AEntry.ParamFunc(LContext, AEntry.ParamValue)
        else
          AEntry.Func(LContext);
        if LContextObj.IsSkipped then
          Break;
      end;

      PopulateResult(Result, LContextObj, ATrackMemory);
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
      { PF-18: guard against unbounded growth when timer resolution is too coarse.
        If LIters already >= MaxIters, break immediately. ScaleIterationsByTen
        also caps at MaxIters, but add explicit check here for the LElapsed=0 loop. }
      if LIters >= LMaxIters then
        Break;
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
      { BUG-FIX: two problems with original `Int64(LProjectedIters)`:
        1. FPC Int64() on Double does bitwise reinterpretation, not numeric truncation.
           e.g. Int64(118.90) = 4638067362024458516 (IEEE 754 bit pattern of 118.90).
        2. Even with correct Trunc(), rounding to same value creates infinite loop.
           e.g. LIters=125, LProjectedIters=125.48 → Trunc=125 → no progress.
        Fix: use Trunc() for conversion, Inc() to guarantee forward progress. }
      if Trunc(LProjectedIters) <= LIters then
        Inc(LIters)
      else
        LIters := Trunc(LProjectedIters);
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
  I, LMaxIters: Integer;
  LResult: TBenchResult;
  { Welford online algorithm for CV }
  LCount: Integer;
  LMean, LM2, LDelta, LDelta2, LCV: Double;
begin
  { B21: Adaptive warmup - measure CV and stop when variance stabilizes }
  if FConfig.AdaptiveWarmup then
  begin
    LMaxIters := FConfig.WarmupMaxIterations;
    if LMaxIters <= 0 then
      LMaxIters := BENCH_DEFAULT_WARMUP_MAX_ITERATIONS;

    LMean := 0.0;
    LM2 := 0.0;
    LCount := 0;

    for I := 1 to LMaxIters do
    begin
      LResult := ExecuteEntry(AEntry, 1, False);
      if LResult.Skipped then
        Break;

      { Welford online update }
      Inc(LCount);
      LDelta := LResult.NsPerOp - LMean;
      LMean := LMean + LDelta / LCount;
      LDelta2 := LResult.NsPerOp - LMean;
      LM2 := LM2 + LDelta * LDelta2;

      { Need at least 5 samples before checking CV }
      if (LCount >= 5) and (LMean > 0) then
      begin
        LCV := Sqrt(LM2 / (LCount - 1)) / LMean;
        if LCV < FConfig.WarmupCVThreshold then
          Break;
      end;
    end;
  end
  else
  begin
    { Fixed warmup iterations (original behavior) }
    for I := 1 to FConfig.WarmupIterations do
    begin
      LResult := ExecuteEntry(AEntry, 1, False);
      { F-06: if warmup is skipped, stop early }
      if LResult.Skipped then
        Break;
    end;
  end;
end;

function TBenchRunner.CollectEntrySamples(const AEntry: TBenchEntry; AIters: Int64;
  out AFirstSample: TBenchResult;
  ATimeoutMs: Int64; ATimeoutStartNs: UInt64): TDoubleArray;
var
  LSamples: TDoubleArray;
  LMeasurement: TBenchResult;
  LMinSamples, LSampleCount: Integer;
  LProbeNsPerOp: Double;
  LTargetNs: UInt64;
  LTimeoutNs: UInt64;
  I: Integer;
begin
  AFirstSample := Default(TBenchResult);

  // PF-17: enforce MinSamples >= 1 to prevent empty arrays
  LMinSamples := FConfig.MinSamples;
  if LMinSamples < 1 then
    LMinSamples := 1;

  { P1-7 自适应测量：用首次采样估算每样本耗时，自动决定采样数。
    目标：总测量时间 ≈ 1s，但不少于 MinSamples，不超过 1000。
    这是 Rust criterion 的核心方法：预热后自动校准采样数量。 }
  LSampleCount := LMinSamples;

  { 先做一次探测采样 }
  LMeasurement := ExecuteEntry(AEntry, AIters, FConfig.EnableMemoryTracking);
  AFirstSample := LMeasurement;

  if LMeasurement.Skipped then
  begin
    SetLength(LSamples, 1);
    LSamples[0] := 0.0;
    Exit(LSamples);
  end;

  if LMeasurement.Iterations > 0 then
    LProbeNsPerOp := Double(LMeasurement.TotalNs) / Double(LMeasurement.Iterations)
  else
    LProbeNsPerOp := 0.0;

  { 自适应：如果探测到每样本时间，计算最优采样数 }
  if LProbeNsPerOp > 0 then
  begin
    LTargetNs := FConfig.MinDurationNs;  { 使用 MinDuration 作为总测量时间目标 }
    LSampleCount := Max(LMinSamples,
      Min(1000, Integer(Trunc(Double(LTargetNs) / (LProbeNsPerOp * AIters)))));
  end;

  if LSampleCount < LMinSamples then
    LSampleCount := LMinSamples;

  SetLength(LSamples, LSampleCount);
  LSamples[0] := LProbeNsPerOp;  { 第一个样本已在探测中获得 }

  { F-11: 预计算超时阈值 }
  if (ATimeoutMs > 0) and (ATimeoutStartNs > 0) then
    LTimeoutNs := UInt64(ATimeoutMs) * 1000000
  else
    LTimeoutNs := 0;

  for I := 1 to LSampleCount - 1 do
  begin
    { F-11: 采样前检查 timeout }
    if (LTimeoutNs > 0) and
       (platform_monotonic_ns - ATimeoutStartNs >= LTimeoutNs) then
    begin
      SetLength(LSamples, I);
      LSamples[I - 1] := 0.0;  { 标记最后一个样本为无效 }
      AFirstSample.Skipped := True;
      AFirstSample.SkipReason := 'Per-benchmark timeout exceeded during sampling';
      Break;
    end;

    { F-11: 在最后一次采样时启用内存追踪，而非仅第二次 }
    LMeasurement := ExecuteEntry(AEntry, AIters,
      FConfig.EnableMemoryTracking and (I = LSampleCount - 1));

    if LMeasurement.Iterations > 0 then
      LSamples[I] := Double(LMeasurement.TotalNs) / Double(LMeasurement.Iterations)
    else
      LSamples[I] := 0.0;

    if LMeasurement.Skipped then
    begin
      SetLength(LSamples, I + 1);
      Break;
    end;
  end;

  Result := LSamples;
end;

function TBenchRunner.ComputeNsPerOp(ATotalNs: UInt64; AIters: Int64): Double;
begin
  if AIters > 0 then
  begin
    { Guard: Double has 53-bit mantissa. When ATotalNs > 2^53, convert
      after division to preserve low-order digits. }
    if ATotalNs > 9007199254740992 then
      Result := Double(ATotalNs div UInt64(AIters))
    else
      Result := Double(ATotalNs) / Double(AIters);
  end
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

function TBenchRunner.ShouldRun(const AName: string; const ALowerName: string): Boolean;
begin
  if FFilterLower = '' then
    Exit(True);
  if FFilterIsGlob then
    Result := GlobMatch(FFilterLower, ALowerName)
  else
    Result := Pos(FFilterLower, ALowerName) > 0; { PF-08: 子串匹配 }
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

procedure TBenchRunner.EmitLine(const ALine: string);
begin
  FConfig.Output.WriteLine(ALine);
end;

procedure TBenchRunner.EmitLineStdErr(const ALine: string);
begin
  { 注意：当前统一使用 Output，不再区分 stderr }
  FConfig.Output.WriteLine(ALine);
end;

function TBenchRunner.RunOne(const AName: string; AFunc: TBenchFunc): TBenchResult;
begin
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.CreateFmt('TBenchRunner.RunOne: function must not be nil (name="%s")', [AName]);
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
  LStartNs: UInt64;
  LTimeoutMs: Int64;
  LLowerName: string;
begin
  LEntry := AEntry;
  Result := Default(TBenchResult);
  Result.Name := LEntry.Name;

  LLowerName := LowerCase(LEntry.Name);
  if not ShouldRun(LEntry.Name, LLowerName) then
  begin
    Exit;
  end;

  Result.Executed := True;
  LSetupData := nil;

  { F-10: per-benchmark timeout 检查 }
  LTimeoutMs := LEntry.TimeoutMs;
  if LTimeoutMs > 0 then
    LStartNs := platform_monotonic_ns
  else
    LStartNs := 0;
  if Assigned(LEntry.Setup) then
    LSetupData := LEntry.Setup();
  try
    LIters := CalibrateEntryIterations(LEntry);

    { F-10: 校准后检查 timeout，避免白跑采样 }
    if (LTimeoutMs > 0) and
       (platform_monotonic_ns - LStartNs >= UInt64(LTimeoutMs) * 1000000) then
    begin
      Result.Skipped := True;
      Result.SkipReason := 'Per-benchmark timeout exceeded';
      AddResult(Result);
      Exit;
    end;

    LSamples := CollectEntrySamples(LEntry, LIters, LMeasurement,
      LTimeoutMs, LStartNs);
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
    { PF-09: use actual measured total from first sample instead of mean*iters }
    Result.TotalNs := LMeasurement.TotalNs;
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
    { B22: Outlier-aware statistics }
    Result.OutlierMethod := LStats.OutlierMethod;
    Result.OutlierThreshold := LStats.OutlierThreshold;
    Result.FilteredMean := LStats.FilteredMean;
    Result.FilteredStdDev := LStats.FilteredStdDev;
    Result.FilteredMedian := LStats.FilteredMedian;
    Result.FilteredCount := LStats.FilteredCount;
    if FConfig.CollectRawSamples or LEntry.CollectRawSamples then
      Result.RawSamples := LSamples;

    { 复制自定义指标 }
    Result.CustomMetrics := LMeasurement.CustomMetrics;

    AddResult(Result);

    if not FConfig.Quiet then
      EmitLine('  ' + PadRight(LEntry.Name, 40) +
        IntToStr(LIters) + ' iters' +
        FormatFloat('0.0', LStats.Mean) + ' ns/op' +
        FormatFloat('0', Result.OpsPerSec) + ' ops/s' +
        FormatFloat('0.0', LStats.StdDev) + ' stddev');
  finally
    if Assigned(LEntry.Teardown) then
      LEntry.Teardown(LSetupData);
  end;
end;

procedure TBenchRunner.RunAll(const AEntries: array of TBenchEntry);
var
  I, LTotal: Integer;
  LProgress: Double;
  LStartNs, LNowNs, LEstRemainingMs: UInt64;
begin
  if not FConfig.Quiet then
    EmitLine('=== nextpas.core.bench v' + BENCH_VERSION + ' ===');

  LTotal := Length(AEntries);
  if Assigned(FConfig.OnProgress) and (LTotal > 0) then
    LStartNs := platform_monotonic_ns;

  for I := 0 to High(AEntries) do
  begin
    { B23: Call progress callback before each benchmark }
    if Assigned(FConfig.OnProgress) and (LTotal > 0) then
    begin
      LProgress := I / LTotal;
      LNowNs := platform_monotonic_ns;
      if I > 0 then
        LEstRemainingMs := ((LNowNs - LStartNs) * (LTotal - I)) div (I * 1000000)
      else
        LEstRemainingMs := 0;
      FConfig.OnProgress(AEntries[I].Name, LProgress, LEstRemainingMs);
    end;

    if AEntries[I].Condition then
      RunOne(AEntries[I]);
  end;

  { B23: Final progress callback }
  if Assigned(FConfig.OnProgress) and (LTotal > 0) then
    FConfig.OnProgress('', 1.0, 0);

  if not FConfig.Quiet then
    Summary;
end;

function TBenchRunner.GetResults: TBenchResultArray;
begin
  Result := Copy(FResults, 0, FResultCount);
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
  { 确保 Output 已初始化 }
  if FConfig.Output = nil then
    FConfig.Output := CreateConsoleWriter;
end;

function TBenchRunner.GetConfig: TBenchConfig;
begin
  Result := FConfig;
end;

procedure TBenchRunner.SetFilter(const AFilter: string);
begin
  FFilter := AFilter;
  FFilterLower := LowerCase(AFilter); { PF-08: cache lowercase }
  FFilterIsGlob := (Pos('*', AFilter) > 0) or (Pos('?', AFilter) > 0);
end;

procedure TBenchRunner.SetAdaptiveWarmup(AEnabled: Boolean;
  ACVThreshold: Double; AMaxIterations: Integer);
begin
  FConfig.AdaptiveWarmup := AEnabled;
  if ACVThreshold > 0 then
    FConfig.WarmupCVThreshold := ACVThreshold;
  if AMaxIterations > 0 then
    FConfig.WarmupMaxIterations := AMaxIterations;
end;

procedure TBenchRunner.Run(const AName: string; AFunc: TBenchLoopFunc);
var
  LEntry: TBenchEntry;
begin
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.LoopFunc := AFunc;
  LEntry.IsLoop := True;
  LEntry.Condition := True;
  RunOne(LEntry);
end;

procedure TBenchRunner.Summary;
var
  I: Integer;
begin
  if FResultCount = 0 then
    Exit;

  EmitLine('');
  EmitLine('=== Summary ===');
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Skipped then
      EmitLine('  ' + PadRight(FResults[I].Name, 40) +
        '  SKIPPED: ' + FResults[I].SkipReason)
    else
      EmitLine('  ' + PadRight(FResults[I].Name, 40) +
        FormatFloat('0.0', FResults[I].NsPerOp) + ' ns/op' +
        FormatFloat('0', FResults[I].OpsPerSec) + ' ops/s');
  end;
end;

end.
