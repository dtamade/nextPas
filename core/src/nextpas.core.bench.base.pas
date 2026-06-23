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
    NsPerOp: Double;        // 纳秒/操作
    OpsPerSec: Double;      // 操作/秒
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
    {** DS-01: 保留用于 suite 级默认并行配置。当前并行由 AddParallel 在 entry 级别设置。 }
    EnableParallel: Boolean;
    ParallelThreads: Integer;
    CollectRawSamples: Boolean;
    Quiet: Boolean;
    SuiteName: string;
  end;

  {** 基准结果数组 }
  TBenchResultArray = array of TBenchResult;

  {** 基准比较数组 }
  TBenchComparisonArray = array of TBenchComparison;

  {** 基线数据（统一类型，替代原 TBenchBaseline） }
  TBaselineData = record
    Name: string;
    NsPerOp: Double;        // 纳秒/操作
    BytesPerOp: Int64;
    AllocsPerOp: Int64;
    TimestampNs: UInt64;
    GitHash: string;
    CompilerVersion: string;
    Notes: string;
  end;

  {** 基线数组 }
  TBaselineArray = array of TBaselineData;

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

  {** t 分布临界值查找表 (0-based, df=1..30) }
  TINV95_DATA: array[0..29] of Double = (
    12.706, 4.303, 3.182, 2.776, 2.571,
    2.447, 2.365, 2.306, 2.262, 2.228,
    2.201, 2.179, 2.160, 2.145, 2.131,
    2.120, 2.110, 2.101, 2.093, 2.086,
    2.080, 2.074, 2.069, 2.064, 2.060,
    2.056, 2.052, 2.048, 2.045, 2.042
  );

  TINV99_DATA: array[0..29] of Double = (
    63.657, 9.925, 5.841, 4.604, 4.032,
    3.707, 3.499, 3.355, 3.250, 3.169,
    3.106, 3.055, 3.012, 2.977, 2.947,
    2.921, 2.898, 2.878, 2.861, 2.845,
    2.831, 2.819, 2.807, 2.797, 2.787,
    2.779, 2.771, 2.763, 2.756, 2.750
  );

{** 从查找表获取 t 临界值（通用 helper，0-based 表，df 1-based） }
function TInvLookup(ADF: Double; const ATable: array of Double; AZScore: Double): Double;

{** 对双精度浮点数组原地排序（IntroSort：小数组插入排序 + 大数组 QuickSort） }
procedure SortDoubleArray(var AData: TDoubleArray);

implementation

function TInvLookup(ADF: Double; const ATable: array of Double; AZScore: Double): Double;
var
  LDF: Integer;
begin
  if ADF < 1.0 then
    Result := ATable[0]
  else if ADF >= 30.0 then
    Result := AZScore
  else
  begin
    LDF := Round(ADF);
    if LDF < 1 then LDF := 1;
    if LDF > 30 then LDF := 30;
    Result := ATable[LDF - 1];  // 0-based table, LDF is 1-based
  end;
end;

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

{ 整数 log2，用于 IntroSort 深度限制 }
function IntLog2(AValue: Integer): Integer;
begin
  Result := 0;
  while AValue > 1 do
  begin
    AValue := AValue shr 1;
    Inc(Result);
  end;
end;

{ HeapSort - 深度耗尽时的 O(n log n) 保底排序 }
procedure DoHeapSort(var AData: TDoubleArray; ALeft, ARight: Integer);

  procedure SiftDown(AStart, AEnd: Integer);
  var
    LRoot, LChild: Integer;
    LVal: Double;
  begin
    LRoot := AStart;
    while True do
    begin
      LChild := 2 * LRoot + 1;
      if LChild > AEnd then Break;
      if (LChild + 1 <= AEnd) and (AData[LChild] < AData[LChild + 1]) then
        Inc(LChild);
      if AData[LRoot] < AData[LChild] then
      begin
        LVal := AData[LRoot];
        AData[LRoot] := AData[LChild];
        AData[LChild] := LVal;
        LRoot := LChild;
      end
      else
        Break;
    end;
  end;

var
  I: Integer;
  LVal: Double;
begin
  for I := (ALeft + ARight) div 2 downto ALeft do
    SiftDown(I, ARight);
  for I := ARight downto ALeft + 1 do
  begin
    LVal := AData[ALeft];
    AData[ALeft] := AData[I];
    AData[I] := LVal;
    SiftDown(ALeft, I - 1);
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

  // 深度耗尽，退化为 HeapSort（O(n log n) 保底）
  if ADepthLimit <= 0 then
  begin
    DoHeapSort(AData, ALeft, ARight);
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
    DoQuickSort(AData, 0, High(AData), 2 * IntLog2(LLen));  // IntroSort depth limit
end;

end.
