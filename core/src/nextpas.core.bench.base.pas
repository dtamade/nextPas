{**
 * @desc 基准测试基础类型
 *
 * 定义 TBenchResult、TBenchStats、TBenchConfig、
 * TBenchEntry 等核心数据结构和常量。
 *}
unit nextpas.core.bench.base;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

type
  {** 双精度浮点数组 }
  TDoubleArray = array of Double;

  {** 整数数组 }
  TInt64Array = array of Int64;

  {** 异常值严重度分级 }
  TOutlierSeverity = (
    osNone,      // 非异常值
    osMild,      // 1.5-3x IQR
    osModerate,  // 3-10x IQR
    osSevere     // >10x IQR
  );

  {** 基准结果 - 单个基准测试的完整结果 }
  TBenchResult = record
    Name: string;
    Executed: Boolean;
    Skipped: Boolean;
    SkipReason: string;
    {** ST-07: Iterations kept as Int64 (not UInt64) because FPC for-loops
     *  require ordinal types and UInt64 is not supported as loop variable.
     *  Runtime validation ensures non-negative values. }
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
    IsSignificant: Boolean; { ST-10: renamed from DifferenceHeuristic for clarity }
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
    CollectRawSamples: Boolean;
    Quiet: Boolean;
    {** PrintToConsole 统计详情最大显示数量（默认 5），0=不显示详情 }
    MaxDetailCount: Integer;
    SuiteName: string;
    {** ST-04: 整体超时（毫秒），0=不超时。超时后跳过剩余 benchmark。 }
    TimeoutMs: Cardinal;
    {** 启用并行执行（需配合 TParallelBenchmark） }
    EnableParallel: Boolean;
    {** 并行线程数，0=自动检测 CPU 核心数 }
    ParallelThreads: Integer;
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

  {** 多基线对比矩阵 — 超越 Go/Rust 的独有能力 }

  {** 矩阵单元格：一个 benchmark 对一个 baseline 的对比。
   *  注意：IsSignificant 基于阈值启发式（非统计检验），因为 baseline 无原始样本。
   *  Ratio 超过 BENCH_MATRIX_DIFF_THRESHOLD 时视为 significant。 }
  TMatrixCell = record
    BaselineNsPerOp: Double;
    Ratio: Double;              // current / baseline
    IsSignificant: Boolean;     // 阈值启发式：|Ratio-1| > BENCH_MATRIX_DIFF_THRESHOLD
    SignificanceThreshold: Double; { F-014: was PValue, renamed for clarity (not a real p-value) }
  end;

  {** 矩阵行：一个 benchmark 对所有 baselines 的对比 }
  TMatrixRow = record
    Name: string;
    CurrentNsPerOp: Double;
    CurrentStdDev: Double;
    CurrentBytesPerOp: Int64;
    CurrentAllocsPerOp: Int64;
    Cells: array of TMatrixCell;
  end;

  {** 多基线对比矩阵结果 }
  TMatrixResult = record
    BaselineNames: array of string;
    Rows: array of TMatrixRow;
    GeometricMeanRatios: array of Double;  // 每个 baseline 列的几何均值
  end;

const
  {** 默认配置值 }
  BENCH_DEFAULT_MIN_DURATION_NS = 1000000000;  // 1 秒
  BENCH_DEFAULT_MAX_ITERATIONS = 1000000;
  BENCH_DEFAULT_MIN_SAMPLES = 30;
  BENCH_DEFAULT_WARMUP_ITERATIONS = 5;
  BENCH_DEFAULT_PARALLEL_THREADS = 4;

  {** 统一显著性阈值常量 }
  BENCH_SIGNIFICANCE_ALPHA = 0.05;       // 统计检验 alpha 水平 (Mann-Whitney/Welch's t)
  BENCH_MATRIX_DIFF_THRESHOLD = 0.05;    // ratio 启发式阈值 (baseline 无原始样本时)

  {** 环境变量名 }
  BENCH_ENV_FILTER = 'NEXTPAS_BENCH_FILTER';
  BENCH_ENV_MAX_ITERS = 'NEXTPAS_BENCH_MAX_ITERS';
  BENCH_ENV_MIN_DURATION = 'NEXTPAS_BENCH_MIN_DURATION';
  BENCH_ENV_MIN_SAMPLES = 'NEXTPAS_BENCH_MIN_SAMPLES';
  BENCH_ENV_WARMUP = 'NEXTPAS_BENCH_WARMUP';
  BENCH_ENV_QUIET = 'NEXTPAS_BENCH_QUIET';
  {** DS-08: 正向命名的内存跟踪环境变量。
   *  设置 =1 / true / yes 时启用内存跟踪（默认启用）。
   *  设置 =0 / false / no 时禁用内存跟踪。 }
  BENCH_ENV_MEMTRACK = 'NEXTPAS_BENCH_MEMTRACK';

  {** 元数据常量
   *  F-013: 手动维护版本号。语义化版本: MAJOR.MINOR。
   *  递增策略: MAJOR = API 不兼容变更, MINOR = 新功能/修复。
   *  构建脚本可覆盖此值 (通过 -dBENCH_VERSION=X.Y.Z)。 }
  BENCH_VERSION = '1.0';

  {** 统计常量 }
  Z_SCORE_95 = 1.96;
  Z_SCORE_99 = 2.576;
  OUTLIER_MULTIPLIER = 1.5;  // Tukey's Fences

  {** 异常值严重度分级（criterion 风格） }
  OUTLIER_MILD_THRESHOLD = 1.5;   // 1.5x IQR: mild outlier
  OUTLIER_MODERATE_THRESHOLD = 3.0; // 3x IQR: moderate outlier
  OUTLIER_SEVERE_THRESHOLD = 10.0;  // 10x IQR: severe outlier

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

{** 间接排序：对索引数组排序，比较依据是 AData[AIndices[i]] }
procedure SortIndirect(var AIndices: TInt64Array; const AData: TDoubleArray);

{** 创建默认基准配置 }
function DefaultBenchConfig: TBenchConfig;

{** 分类异常值严重度（criterion 风格：mild/moderate/severe） }
function ClassifyOutlierSeverity(AValue, AQ1, AQ3: Double): TOutlierSeverity;

{** Glob 模式匹配（* 匹配任意字符，? 匹配单个字符） }
function GlobMatch(const APattern, AStr: string): Boolean;

{** IEEE 754 NaN 检测: exponent=全1 且 mantissa≠0 }
function IsDoubleNaN(const AValue: Double): Boolean; inline;

{** Percentile 线性插值（输入必须已排序） }
function PercentileSorted(const ASorted: TDoubleArray; APercent: Double): Double;

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

function IsDoubleNaN(const AValue: Double): Boolean; inline;
var
  LBits: UInt64 absolute AValue;
begin
  Result := ((LBits and $7FF0000000000000) = $7FF0000000000000)
        and ((LBits and $000FFFFFFFFFFFFF) <> 0);
end;

function PercentileSorted(const ASorted: TDoubleArray; APercent: Double): Double;
var
  LIndex: Double;
  LLower, LUpper: Integer;
  LCount: Integer;
begin
  LCount := Length(ASorted);
  if LCount = 0 then Exit(0.0);
  if LCount = 1 then Exit(ASorted[0]);
  if APercent <= 0 then Exit(ASorted[0]);
  if APercent >= 100 then Exit(ASorted[High(ASorted)]);

  LIndex := (APercent / 100.0) * (LCount - 1);
  LLower := Trunc(LIndex);
  LUpper := LLower + 1;
  if LUpper >= LCount then
    Exit(ASorted[High(ASorted)]);
  Result := ASorted[LLower] + (LIndex - LLower) * (ASorted[LUpper] - ASorted[LLower]);
end;

{ NaN 安全分区: 将 NaN 值移到数组末尾，返回非 NaN 元素个数 }
function PartitionNaNsToTail(var AData: TDoubleArray): Integer;
var
  LHead, LTail: Integer;
  LTmp: Double;
begin
  LHead := 0;
  LTail := High(AData);
  while LHead <= LTail do
  begin
    if IsDoubleNaN(AData[LTail]) then
      Dec(LTail)
    else if IsDoubleNaN(AData[LHead]) then
    begin
      LTmp := AData[LHead];
      AData[LHead] := AData[LTail];
      AData[LTail] := LTmp;
      Inc(LHead);
      Dec(LTail);
    end
    else
      Inc(LHead);
  end;
  Result := LTail + 1;  { 非 NaN 元素的个数 }
end;

procedure SortDoubleArray(var AData: TDoubleArray);
var
  LLen, LNonNaN: Integer;
begin
  LLen := Length(AData);
  if LLen > 1 then
  begin
    LNonNaN := PartitionNaNsToTail(AData);
    if LNonNaN > 1 then
      DoQuickSort(AData, 0, LNonNaN - 1, 2 * IntLog2(LNonNaN));
  end;
end;

{ ---- Indirect sort (sort indices by data values) ---- }

procedure InsertionSortIndirect(var AIndices: TInt64Array;
  const AData: TDoubleArray; ALeft, ARight: Integer);
var
  I, J: Integer;
  LKey: Int64;
begin
  for I := ALeft + 1 to ARight do
  begin
    LKey := AIndices[I];
    J := I - 1;
    while (J >= ALeft) and (AData[AIndices[J]] > AData[LKey]) do
    begin
      AIndices[J + 1] := AIndices[J];
      Dec(J);
    end;
    AIndices[J + 1] := LKey;
  end;
end;

function MedianOfThreeIndirect(const AIndices: TInt64Array;
  const AData: TDoubleArray; ALeft, ARight: Integer): Double;
var
  LMid: Integer;
begin
  LMid := (ALeft + ARight) div 2;
  if AData[AIndices[ALeft]] > AData[AIndices[LMid]] then
  begin
    if AData[AIndices[LMid]] > AData[AIndices[ARight]] then
      Result := AData[AIndices[LMid]]
    else if AData[AIndices[ALeft]] > AData[AIndices[ARight]] then
      Result := AData[AIndices[ARight]]
    else
      Result := AData[AIndices[ALeft]];
  end
  else
  begin
    if AData[AIndices[ALeft]] > AData[AIndices[ARight]] then
      Result := AData[AIndices[ALeft]]
    else if AData[AIndices[LMid]] > AData[AIndices[ARight]] then
      Result := AData[AIndices[ARight]]
    else
      Result := AData[AIndices[LMid]];
  end;
end;

procedure SiftDownIndirect(var AIndices: TInt64Array; const AData: TDoubleArray;
  AStart, AEnd: Integer);
var
  LRoot, LChild, LSwap: Integer;
  LTmp: Int64;
begin
  LRoot := AStart;
  while True do
  begin
    LChild := 2 * LRoot - AStart + 1;
    if LChild > AEnd then Break;
    LSwap := LRoot;
    if AData[AIndices[LChild]] > AData[AIndices[LSwap]] then
      LSwap := LChild;
    Inc(LChild);
    if (LChild <= AEnd) and (AData[AIndices[LChild]] > AData[AIndices[LSwap]]) then
      LSwap := LChild;
    if LSwap = LRoot then Break;
    LTmp := AIndices[LRoot];
    AIndices[LRoot] := AIndices[LSwap];
    AIndices[LSwap] := LTmp;
    LRoot := LSwap;
  end;
end;

procedure HeapSortIndirect(var AIndices: TInt64Array; const AData: TDoubleArray;
  ALeft, ARight: Integer);
var
  I: Integer;
  LTmp: Int64;
begin
  for I := (ALeft + ARight) div 2 downto ALeft do
    SiftDownIndirect(AIndices, AData, I, ARight);
  for I := ARight downto ALeft + 1 do
  begin
    LTmp := AIndices[ALeft];
    AIndices[ALeft] := AIndices[I];
    AIndices[I] := LTmp;
    SiftDownIndirect(AIndices, AData, ALeft, I - 1);
  end;
end;

procedure DoQuickSortIndirect(var AIndices: TInt64Array;
  const AData: TDoubleArray; ALeft, ARight: Integer; ADepthLimit: Integer);
var
  LPivot: Double;
  LTmp: Int64;
  I, J: Integer;
begin
  while ARight - ALeft >= 16 do
  begin
    if ADepthLimit = 0 then
    begin
      HeapSortIndirect(AIndices, AData, ALeft, ARight);
      Exit;
    end;
    Dec(ADepthLimit);
    LPivot := MedianOfThreeIndirect(AIndices, AData, ALeft, ARight);
    I := ALeft;
    J := ARight;
    repeat
      while AData[AIndices[I]] < LPivot do Inc(I);
      while AData[AIndices[J]] > LPivot do Dec(J);
      if I <= J then
      begin
        LTmp := AIndices[I];
        AIndices[I] := AIndices[J];
        AIndices[J] := LTmp;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if J - ALeft < ARight - I then
    begin
      DoQuickSortIndirect(AIndices, AData, ALeft, J, ADepthLimit);
      ALeft := I;
    end
    else
    begin
      DoQuickSortIndirect(AIndices, AData, I, ARight, ADepthLimit);
      ARight := J;
    end;
  end;
  InsertionSortIndirect(AIndices, AData, ALeft, ARight);
end;

procedure SortIndirect(var AIndices: TInt64Array; const AData: TDoubleArray);
var
  LLen: Integer;
begin
  LLen := Length(AIndices);
  if LLen > 1 then
    DoQuickSortIndirect(AIndices, AData, 0, LLen - 1, 2 * IntLog2(LLen));
end;

function DefaultBenchConfig: TBenchConfig;
begin
  Result := Default(TBenchConfig);
  Result.MinDurationNs := BENCH_DEFAULT_MIN_DURATION_NS;
  Result.MaxIterations := BENCH_DEFAULT_MAX_ITERATIONS;
  Result.MinSamples := BENCH_DEFAULT_MIN_SAMPLES;
  Result.WarmupIterations := BENCH_DEFAULT_WARMUP_ITERATIONS;
  Result.EnableMemoryTracking := True;
  Result.CollectRawSamples := False;
  Result.Quiet := False;
  Result.MaxDetailCount := 5;
end;

function ClassifyOutlierSeverity(AValue, AQ1, AQ3: Double): TOutlierSeverity;
var
  LIQR, LDist: Double;
begin
  LIQR := AQ3 - AQ1;
  if LIQR <= 0 then
    Exit(osNone);

  { 计算值到最近的 fence 的距离（以 IQR 为单位） }
  if AValue < AQ1 then
    LDist := (AQ1 - AValue) / LIQR
  else if AValue > AQ3 then
    LDist := (AValue - AQ3) / LIQR
  else
    Exit(osNone);  { 在 Q1-Q3 之间，不是异常值 }

  if LDist > OUTLIER_SEVERE_THRESHOLD then
    Result := osSevere
  else if LDist > OUTLIER_MODERATE_THRESHOLD then
    Result := osModerate
  else if LDist > OUTLIER_MILD_THRESHOLD then
    Result := osMild
  else
    Result := osNone;
end;

{** Glob 模式匹配实现
 *
 *  支持:
 *    * — 匹配任意字符序列（包括空）
 *    ? — 匹配单个字符
 *    其他字符按字面匹配（大小写敏感）
 *
 *  F-03: 迭代实现（双指针 + 回溯），避免递归堆分配。
 *  O(n*m) 最坏情况，基准名称通常很短，无性能问题。
 }
function GlobMatch(const APattern, AStr: string): Boolean;
var
  LP, LS, LStarP, LStarS: PChar;
begin
  if APattern = '' then
    Exit(AStr = '');

  LP := PChar(APattern);
  LS := PChar(AStr);
  LStarP := nil;
  LStarS := nil;

  while LS^ <> #0 do
  begin
    if (LP^ = '*') then
    begin
      { 记录回溯点：模式和字符串的当前位置 }
      LStarP := LP;
      LStarS := LS;
      Inc(LP);
    end
    else if (LP^ = '?') or (LP^ = LS^) then
    begin
      Inc(LP);
      Inc(LS);
    end
    else if LStarP <> nil then
    begin
      { 回溯：* 多匹配一个字符 }
      Inc(LStarS);
      LP := LStarP + 1;  { 跳过 * }
      LS := LStarS;
    end
    else
      Exit(False);
  end;

  { 跳过尾部的 * }
  while LP^ = '*' do
    Inc(LP);

  Result := LP^ = #0;
end;

end.
