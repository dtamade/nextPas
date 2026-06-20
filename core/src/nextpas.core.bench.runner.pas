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
    FSkipped: Boolean;
    FSkipReason: string;

  public
    constructor Create;

    {** IBenchContext 实现 }
    procedure SetBytes(ABytes: Int64);
    procedure SetAllocs(AAllocs: Int64);
    procedure ResetTimer;
    procedure Skip(const AReason: string);
    function GetIterations: Int64;
    function GetElapsed: TDuration;
    function GetBytesPerOp: Int64;
    function GetAllocsPerOp: Int64;

    {** 内部方法 }
    procedure Reset;
    procedure IncrementIterations;
    procedure SetIterations(AValue: Int64);
    function IsSkipped: Boolean;
    function GetSkipReason: string;
    function GetStartNs: UInt64;
  end;

  {** 基准执行器 }
  TBenchRunner = class
  private
    FConfig: TBenchConfig;
    FFilter: string;
    FStatsAnalyzer: IBenchStatsAnalyzer;
    FResults: array of TBenchResult;
    FResultCount: Integer;

    {** 测量函数执行时间 }
    function MeasureNs(AFunc: TBenchFunc; AIters: Int64): UInt64;

    {** 校准迭代次数 }
    function CalibrateIterations(AFunc: TBenchFunc): Int64;

    {** 热身 }
    procedure Warmup(AFunc: TBenchFunc);

    {** 采集多个样本 }
    function CollectSamples(AFunc: TBenchFunc; AIters: Int64): TDoubleArray;

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

  public
    constructor Create;
    destructor Destroy; override;

    {** 运行单个基准测试 }
    function RunOne(const AName: string; AFunc: TBenchFunc): TBenchResult;

    {** 运行多个基准测试 }
    procedure RunAll(const AEntries: array of TBenchEntry);

    {** 获取所有结果 }
    function GetResults: array of TBenchResult;

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
  SysUtils, Math;

{ TBenchContext }

constructor TBenchContext.Create;
begin
  inherited Create;
  FIterations := 0;
  FBytesPerOp := 0;
  FAllocsPerOp := 0;
  FStartNs := platform_monotonic_ns;
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

procedure TBenchContext.Reset;
begin
  FIterations := 0;
  FBytesPerOp := 0;
  FAllocsPerOp := 0;
  FStartNs := platform_monotonic_ns;
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

{ TBenchRunner }

constructor TBenchRunner.Create;
begin
  inherited Create;
  FStatsAnalyzer := TBenchStatsAnalyzer.Create;
  FResultCount := 0;
  SetLength(FResults, 0);
  LoadConfigFromEnv;
end;

destructor TBenchRunner.Destroy;
begin
  SetLength(FResults, 0);
  inherited Destroy;
end;

procedure TBenchRunner.LoadConfigFromEnv;
var
  LValue: string;
begin
  // 加载配置
  FConfig.MinDurationNs := BENCH_DEFAULT_MIN_DURATION_NS;
  FConfig.MaxIterations := BENCH_DEFAULT_MAX_ITERATIONS;
  FConfig.MinSamples := BENCH_DEFAULT_MIN_SAMPLES;
  FConfig.WarmupIterations := BENCH_DEFAULT_WARMUP_ITERATIONS;
  FConfig.EnableMemoryTracking := True;
  FConfig.EnableParallel := False;
  FConfig.ParallelThreads := BENCH_DEFAULT_PARALLEL_THREADS;

  // 从环境变量覆盖
  LValue := GetEnvironmentVariable(BENCH_ENV_MAX_ITERS);
  if (LValue <> '') and TryStrToInt64(LValue, FConfig.MaxIterations) then
    if FConfig.MaxIterations < 100 then
      FConfig.MaxIterations := 100;

  LValue := GetEnvironmentVariable(BENCH_ENV_MIN_DURATION);
  if (LValue <> '') then
    FConfig.MinDurationNs := StrToInt64Def(LValue, BENCH_DEFAULT_MIN_DURATION_NS);

  LValue := GetEnvironmentVariable(BENCH_ENV_MIN_SAMPLES);
  if (LValue <> '') then
    FConfig.MinSamples := StrToIntDef(LValue, BENCH_DEFAULT_MIN_SAMPLES);

  LValue := GetEnvironmentVariable(BENCH_ENV_WARMUP);
  if (LValue <> '') then
    FConfig.WarmupIterations := StrToIntDef(LValue, BENCH_DEFAULT_WARMUP_ITERATIONS);

  FFilter := GetEnvironmentVariable(BENCH_ENV_FILTER);
end;

function TBenchRunner.MeasureNs(AFunc: TBenchFunc; AIters: Int64): UInt64;
var
  LCtx: TBenchContext;
  LStartNs, LEndNs: UInt64;
begin
  LCtx := TBenchContext.Create;
  try
    LCtx.SetIterations(AIters);
    LStartNs := platform_monotonic_ns;
    AFunc(LCtx);
    LEndNs := platform_monotonic_ns;
    Result := LEndNs - LStartNs;
  finally
    LCtx.Free;
  end;
end;

function TBenchRunner.CalibrateIterations(AFunc: TBenchFunc): Int64;
var
  LElapsed: UInt64;
  LIters: Int64;
  LMaxIters: Int64;
  LTargetNs: UInt64;
begin
  LTargetNs := FConfig.MinDurationNs;
  LMaxIters := FConfig.MaxIterations;

  // 热身
  Warmup(AFunc);

  // 初始小批量
  LIters := 100;
  repeat
    LElapsed := MeasureNs(AFunc, LIters);

    // 如果太快，指数增长
    if LElapsed < LTargetNs div 10 then
      LIters := LIters * 10
    // 如果接近目标，线性外推
    else if LElapsed < LTargetNs then
      LIters := Int64((Double(LIters) * Double(LTargetNs)) / Double(LElapsed))
    // 达到目标
    else
      Break;

    // 安全上限
    if LIters > LMaxIters then
    begin
      LIters := LMaxIters;
      Break;
    end;

    // 最小迭代次数
    if LIters < 100 then
      LIters := 100;
  until False;

  Result := LIters;
end;

procedure TBenchRunner.Warmup(AFunc: TBenchFunc);
var
  i: Integer;
begin
  for i := 1 to FConfig.WarmupIterations do
    AFunc(nil);  // 热身时不使用正式上下文
end;

function TBenchRunner.CollectSamples(AFunc: TBenchFunc; AIters: Int64): TDoubleArray;
var
  LSamples: TDoubleArray;
  i: Integer;
  LTotalNs: UInt64;
begin
  SetLength(LSamples, FConfig.MinSamples);

  for i := 0 to FConfig.MinSamples - 1 do
  begin
    LTotalNs := MeasureNs(AFunc, AIters);
    LSamples[i] := Double(LTotalNs) / Double(AIters);
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
  Result := (FFilter = '') or
    (Pos(LowerCase(FFilter), LowerCase(AName)) > 0);
end;

procedure TBenchRunner.AddResult(const AResult: TBenchResult);
begin
  Inc(FResultCount);
  SetLength(FResults, FResultCount);
  FResults[FResultCount - 1] := AResult;
end;

function TBenchRunner.RunOne(const AName: string; AFunc: TBenchFunc): TBenchResult;
var
  LIters: Int64;
  LSamples: TDoubleArray;
  LStats: TBenchStats;
  LTotalNs: UInt64;
  LCtx: TBenchContext;
begin
  if not ShouldRun(AName) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Name := AName;
    Exit;
  end;

  // 校准迭代次数
  LIters := CalibrateIterations(AFunc);

  // 采集样本
  LSamples := CollectSamples(AFunc, LIters);

  // 计算统计信息
  LStats := FStatsAnalyzer.ComputeStats(LSamples);

  // 计算总时间
  LTotalNs := UInt64(LStats.Mean * LIters);

  // 填充结果
  Result.Name := AName;
  Result.Iterations := LIters;
  Result.TotalNs := LTotalNs;
  Result.NsPerOp := LStats.Mean;
  Result.OpsPerSec := ComputeOpsPerSec(LStats.Mean);
  Result.BytesPerOp := 0;  // 需要从上下文获取
  Result.AllocsPerOp := 0;  // 需要从上下文获取
  Result.StdDev := LStats.StdDev;
  Result.Median := LStats.Median;
  Result.P95 := LStats.P95;
  Result.P99 := LStats.P99;
  Result.Outliers := LStats.OutlierCount;
  Result.SampleCount := LStats.SampleCount;

  AddResult(Result);

  // 输出到控制台
  WriteLn('  ', AName:40, LIters:12, ' iters',
    LStats.Mean:10:1, ' ns/op',
    Result.OpsPerSec:14:0, ' ops/s',
    LStats.StdDev:10:1, ' stddev');
end;

procedure TBenchRunner.RunAll(const AEntries: array of TBenchEntry);
var
  i: Integer;
begin
  WriteLn('=== nextpas.core.bench v1.0 ===');
  WriteLn;

  for i := 0 to High(AEntries) do
  begin
    if AEntries[i].Condition then
      RunOne(AEntries[i].Name, AEntries[i].Func);
  end;

  WriteLn;
  WriteLn('=== Summary ===');
  for i := 0 to FResultCount - 1 do
  begin
    WriteLn('  ', FResults[i].Name:40,
      FResults[i].NsPerOp:10:1, ' ns/op',
      FResults[i].OpsPerSec:14:0, ' ops/s');
  end;
end;

function TBenchRunner.GetResults: array of TBenchResult;
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
end;

end.
