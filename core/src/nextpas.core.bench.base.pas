unit nextpas.core.bench.base;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

type
  {** 双精度浮点数组 }
  TDoubleArray = array of Double;

  {** 整数数组 }
  TInt64Array = array of Int64;

  {** 基准结果 - 单个基准测试的完整结果 }
  TBenchResult = record
    Name: string;
    Executed: Boolean;
    Skipped: Boolean;
    SkipReason: string;
    Iterations: Int64;
    TotalNs: UInt64;
    NsPerOp: Double;
    OpsPerSec: Double;
    BytesPerOp: Int64;
    AllocsPerOp: Int64;
    StdDev: Double;
    Median: Double;
    P95: Double;
    P99: Double;
    Outliers: Integer;
    SampleCount: Integer;
    RawSamples: TDoubleArray;
  end;

  {** 统计摘要 - 完整的统计分析结果 }
  TBenchStats = record
    Mean: Double;
    StdDev: Double;
    Median: Double;
    Min: Double;
    Max: Double;
    P5: Double;
    P25: Double;
    P75: Double;
    P95: Double;
    P99: Double;
    IQR: Double;
    OutlierCount: Integer;
    Confidence95Low: Double;
    Confidence95High: Double;
    Confidence99Low: Double;
    Confidence99High: Double;
    SampleCount: Integer;
  end;

  {** 基线对比 - 与基线性能的对比结果 }
  TBenchComparison = record
    BaselineName: string;
    BaselineNsPerOp: Double;
    CurrentNsPerOp: Double;
    Ratio: Double;
    HasStatisticalTest: Boolean;
    DifferenceHeuristic: Boolean;
    ApproximatePValue: Double;
  end;

  {** 环境信息 - 运行环境描述 }
  TBenchEnvironment = record
    OS: string;
    CPU: string;
    Cores: Integer;
    FPCVersion: string;
    Timestamp: string;
  end;

  {** 基准配置 - 基准运行参数 }
  TBenchConfig = record
    MinDurationNs: UInt64;
    MaxIterations: Int64;
    MinSamples: Integer;
    WarmupIterations: Integer;
    EnableMemoryTracking: Boolean;
    EnableParallel: Boolean;
    ParallelThreads: Integer;
    CollectRawSamples: Boolean;
    Quiet: Boolean;
  end;

  {** 基准结果数组 }
  TBenchResultArray = array of TBenchResult;

  {** 基准比较数组 }
  TBenchComparisonArray = array of TBenchComparison;

  {** 基线数据 }
  TBenchBaseline = record
    Name: string;
    NsPerOp: Double;
  end;

  {** 基线数组 }
  TBenchBaselineArray = array of TBenchBaseline;

const
  {** 默认配置值 }
  BENCH_DEFAULT_MIN_DURATION_NS = 1000000000;  // 1 秒
  BENCH_DEFAULT_MAX_ITERATIONS = 1000000;
  BENCH_DEFAULT_MIN_SAMPLES = 30;
  BENCH_DEFAULT_WARMUP_ITERATIONS = 5;
  BENCH_DEFAULT_PARALLEL_THREADS = 4;

  {** 环境变量名 }
  BENCH_ENV_FILTER = 'NEXTPAS_BENCH_FILTER';
  BENCH_ENV_MAX_ITERS = 'NEXTPAS_BENCH_MAX_ITERS';
  BENCH_ENV_MIN_DURATION = 'NEXTPAS_BENCH_MIN_DURATION';
  BENCH_ENV_MIN_SAMPLES = 'NEXTPAS_BENCH_MIN_SAMPLES';
  BENCH_ENV_WARMUP = 'NEXTPAS_BENCH_WARMUP';
  BENCH_ENV_QUIET = 'NEXTPAS_BENCH_QUIET';
  BENCH_ENV_NO_MEMTRACK = 'NEXTPAS_BENCH_NO_MEMTRACK';

  {** 统计常量 }
  Z_SCORE_95 = 1.96;
  Z_SCORE_99 = 2.576;
  OUTLIER_MULTIPLIER = 1.5;  // Tukey's Fences

{** 对双精度浮点数组原地排序（IntroSort：小数组插入排序 + 大数组 QuickSort） }
procedure SortDoubleArray(var AData: TDoubleArray);

implementation

const
  INSERTION_SORT_THRESHOLD = 16;

{ 插入排序 - 对小数组更快 }
procedure DoInsertionSort(var AData: TDoubleArray; ALeft, ARight: Integer);
var
  I, J: Integer;
  LKey: Double;
begin
  for I := ALeft + 1 to ARight do
  begin
    LKey := AData[I];
    J := I - 1;
    while (J >= ALeft) and (AData[J] > LKey) do
    begin
      AData[J + 1] := AData[J];
      Dec(J);
    end;
    AData[J + 1] := LKey;
  end;
end;

{ 三数取中选择 pivot }
function MedianOfThree(const AData: TDoubleArray; ALeft, ARight: Integer): Double;
var
  LMid: Integer;
begin
  LMid := (ALeft + ARight) div 2;
  if AData[ALeft] > AData[LMid] then
  begin
    if AData[LMid] > AData[ARight] then
      Result := AData[LMid]
    else if AData[ALeft] > AData[ARight] then
      Result := AData[ARight]
    else
      Result := AData[ALeft];
  end
  else
  begin
    if AData[ALeft] > AData[ARight] then
      Result := AData[ALeft]
    else if AData[LMid] > AData[ARight] then
      Result := AData[ARight]
    else
      Result := AData[LMid];
  end;
end;

procedure DoQuickSort(var AData: TDoubleArray; ALeft, ARight: Integer; ADepthLimit: Integer);
var
  LPivot, LTmp: Double;
  I, J: Integer;
begin
  // 小数组使用插入排序
  if (ARight - ALeft + 1) < INSERTION_SORT_THRESHOLD then
  begin
    DoInsertionSort(AData, ALeft, ARight);
    Exit;
  end;

  // 深度限制，退化为堆排序（这里简化为插入排序）
  if ADepthLimit <= 0 then
  begin
    DoInsertionSort(AData, ALeft, ARight);
    Exit;
  end;

  // 三数取中 pivot
  LPivot := MedianOfThree(AData, ALeft, ARight);
  I := ALeft;
  J := ARight;
  while I <= J do
  begin
    while AData[I] < LPivot do Inc(I);
    while AData[J] > LPivot do Dec(J);
    if I <= J then
    begin
      LTmp := AData[I];
      AData[I] := AData[J];
      AData[J] := LTmp;
      Inc(I);
      Dec(J);
    end;
  end;
  if ALeft < J then
    DoQuickSort(AData, ALeft, J, ADepthLimit - 1);
  if I < ARight then
    DoQuickSort(AData, I, ARight, ADepthLimit - 1);
end;

procedure SortDoubleArray(var AData: TDoubleArray);
var
  LLen: Integer;
begin
  LLen := Length(AData);
  if LLen > 1 then
    DoQuickSort(AData, 0, High(AData), 2 * LLen);  // IntroSort depth limit
end;

end.
