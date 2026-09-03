{**
 * @desc 基准测试基础类型
 *
 * 定义 TBenchResult、TBenchStats、TBenchConfig、
 * TBenchEntry 等核心数据结构和常量。
 *}
unit nextpas.core.bench.base;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
{ 实数字面量最低 Double，防止与整型混算落到 Single 精度（见 stats 同注） }
{$MINFPCONSTPREC 64}

interface

uses
  nextpas.core.exception,
  nextpas.core.io.linewriter,
  nextpas.core.time.base;

type
  {** 双精度浮点数组 }
  TDoubleArray = array of Double;

  {** 整数数组 }
  TInt64Array = array of Int64;

  {** 字符串数组 }
  TStringArray = array of string;

  {** 自定义指标键值对 }
  TCustomMetric = record
    Name: string;
    Value: Double;
  end;

  {** 自定义指标数组 }
  TCustomMetricArray = array of TCustomMetric;

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
    {** 自定义指标 }
    CustomMetrics: TCustomMetricArray;
    {** B22: Outlier-aware statistics
     *  当前始终为 'Tukey'/1.5，未来可扩展 ZScore/ModifiedZScore }
    OutlierMethod: string;
    OutlierThreshold: Double;
    FilteredMean: Double;
    FilteredStdDev: Double;
    FilteredMedian: Double;
    FilteredCount: Integer;

    {** 获取 NsPerOp 的 TDuration 表示（类型安全的便捷方法）。
     *  当 NsPerOp <= 0 时返回 TDuration.Zero。 }
    function NsPerOpDuration: TDuration;

    {** 获取 StdDev 的 TDuration 表示（类型安全的便捷方法）。
     *  当 StdDev <= 0 时返回 TDuration.Zero。 }
    function StdDevDuration: TDuration;
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
    {** B22: Outlier-aware statistics }
    OutlierMethod: string;       // e.g., 'Tukey', 'ZScore', 'ModifiedZScore'
    OutlierThreshold: Double;    // e.g., 1.5 for Tukey, 3.0 for ZScore
    FilteredMean: Double;        // Mean excluding outliers
    FilteredStdDev: Double;      // StdDev excluding outliers
    FilteredMedian: Double;      // Median excluding outliers
    FilteredCount: Integer;      // Sample count excluding outliers
  end;

  {** 基线对比 - 与基线性能的对比结果 }
  TBenchComparison = record
    BaselineName: string;
    BaselineNsPerOp: Double;
    CurrentNsPerOp: Double;
    Ratio: Double;
    HasStatisticalTest: Boolean;
    IsSignificant: Boolean;
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

  {** OLS 线性回归结果 (P1-1: 去除固定开销) }
  TOLSRegression = record
    Slope: Double;       { 每次迭代的时间（纳秒） }
    Intercept: Double;   { 固定开销（纳秒） }
    RSquared: Double;    { 拟合度 (0-1)，越接近 1 越好 }
    Valid: Boolean;      { 回归是否有效 }
  end;

  {** B23: Progress callback procedure type }
  TBenchProgressCallback = procedure(
    const AName: string;       // Current benchmark name
    AProgress: Double;         // Progress 0.0..1.0
    AEstimatedRemainingMs: Int64  // Estimated remaining time in ms
  );

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
    {** ST-04: suite 级整体超时（毫秒），0=不超时。超时后跳过剩余条目。 }
    TimeoutMs: Int64;
    {** 启用并行执行（需配合 TParallelBenchmark） }
    EnableParallel: Boolean;
    {** 并行线程数，0=自动检测 CPU 核心数 }
    ParallelThreads: Integer;
    {** B21: 启用自适应预热（根据方差自动停止） }
    AdaptiveWarmup: Boolean;
    {** B21: 自适应预热 CV 阈值（默认 5%），当 StdDev/Mean < Threshold 时停止 }
    WarmupCVThreshold: Double;
    {** B21: 自适应预热最大迭代次数（防止死循环） }
    WarmupMaxIterations: Integer;
    {** B23: Progress callback }
    OnProgress: TBenchProgressCallback;
    {** 输出写入器 — 替代裸 WriteLn，nil 时自动创建控制台写入器 }
    Output: ILineWriter;
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

  {** K-S 检验结果 (Phase A: Kolmogorov-Smirnov) }
  TKSTestResult = record
    Statistic: Double;      // K-S 统计量 D
    PValue: Double;         // p-value
    IsSignificant: Boolean; // 在 α=0.05 水平下是否显著
    SampleSize1: Integer;   // 第一个样本大小
    SampleSize2: Integer;   // 第二个样本大小（单样本检验时为 0）
  end;

  {** Xoroshiro128+ 伪随机数生成器 (Phase B.1)
   *  周期 2^128-1，统计质量优于 PCG-LCG。
   *  参考: Blackman & Vigna (2018), "Scrambled Linear Pseudorandom Number Generators" }
  TXoroshiro128Plus = record
    S0, S1: UInt64;
    {** 用种子初始化状态（SplitMix64 扩展种子） }
    procedure Init(ASeed: UInt64);
    {** 生成下一个 UInt64 随机数 }
    function Next: UInt64;
    {** 生成 [0, AMaxExclusive) 范围内的随机整数 }
    function NextInt(AMaxExclusive: Integer): Integer;
  end;

  {** Bootstrap 假设检验结果 (Phase B.3) }
  TBootstrapTestResult = record
    ObservedDiff: Double;     // 观测到的差异（均值差）
    PValue: Double;           // bootstrap p-value
    IsSignificant: Boolean;   // 在 α=0.05 水平下是否显著
    Iterations: Integer;      // bootstrap 迭代次数
  end;

  {** 置信区间 (Phase B.2: moved from stats.advanced) }
  TConfidenceInterval = record
    Lower: Double;
    Upper: Double;
    Level: Double; // e.g., 0.95 for 95%
  end;

  {** 贝叶斯估计结果 (Phase C) }
  TBayesianEstimate = record
    PriorMean: Double;        // 先验均值
    PriorStdDev: Double;      // 先验标准差
    PosteriorMean: Double;    // 后验均值
    PosteriorStdDev: Double;  // 后验标准差
    SampleMean: Double;       // 样本均值
    SampleSize: Integer;      // 样本大小
    CredibleLower: Double;    // 可信区间下界
    CredibleUpper: Double;    // 可信区间上界
    CredibleLevel: Double;    // 可信水平
  end;

  {** 多基线对比矩阵 — 超越 Go/Rust 的独有能力 }

  {** 矩阵单元格：一个 benchmark 对一个 baseline 的对比。
   *  注意：IsSignificant 基于阈值启发式（非统计检验），因为 baseline 无原始样本。
   *  Ratio 超过 BENCH_MATRIX_DIFF_THRESHOLD 时视为 significant。 }
  TMatrixCell = record
    BaselineNsPerOp: Double;
    Ratio: Double;              // current / baseline
    IsSignificant: Boolean;     // 阈值启发式：|Ratio-1| > BENCH_MATRIX_DIFF_THRESHOLD
    SignificanceThreshold: Double; { heuristic threshold — not a real p-value }
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
  {** B21: 自适应预热常量 }
  BENCH_DEFAULT_ADAPTIVE_WARMUP = False;
  BENCH_DEFAULT_WARMUP_CV_THRESHOLD = 0.05;  // 5%
  BENCH_DEFAULT_WARMUP_MAX_ITERATIONS = 100;

  {** 统一显著性阈值常量 }
  BENCH_SIGNIFICANCE_ALPHA = 0.05;       // 统计检验 alpha 水平 (Mann-Whitney/Welch's t)
  BENCH_SIGNIFICANCE_ALPHA_HIGH = 0.01;  // 高显著性 alpha 水平 (99% 置信)
  BENCH_MATRIX_DIFF_THRESHOLD = 0.05;    // ratio 启发式阈值 (baseline 无原始样本时)
  { F-32: level/alpha 表选择边界比较必须带余量。0.95/0.99/0.05/0.01 等常用值
    在 Double 与 extended 精度字面量间表示不一致（如 Double(0.95) < extended 0.95），
    裸比较会让调用者恰好落在边界外拿到错误的临界值表；1e-6 同时覆盖
    Single 精度来源的调用值（偏差 ~1.2e-8），且远小于相邻档位间距（>= 0.04）。 }
  BENCH_LEVEL_EPS = 1e-6;

  {** 时间单位常量 }
  NANOSECONDS_PER_SECOND = 1000000000;

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
  {** 整体超时环境变量（毫秒），0=不超时 }
  BENCH_ENV_TIMEOUT = 'NEXTPAS_BENCH_TIMEOUT';

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

  TINV90_DATA: array[0..29] of Double = (
    6.314, 2.920, 2.353, 2.132, 2.015,
    1.943, 1.895, 1.860, 1.833, 1.812,
    1.796, 1.782, 1.771, 1.761, 1.753,
    1.746, 1.740, 1.734, 1.729, 1.725,
    1.721, 1.717, 1.714, 1.711, 1.708,
    1.706, 1.703, 1.701, 1.699, 1.697
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

{ Glob 模式匹配 - 单源 L1 text.strings.GlobMatch }
function GlobMatch(const APattern, AStr: string): Boolean; inline;

{** IEEE 754 NaN 检测: exponent=全1 且 mantissa≠0 }
function IsDoubleNaN(const AValue: Double): Boolean; inline;

{** Percentile 线性插值（输入必须已排序） }
function PercentileSorted(const ASorted: TDoubleArray; APercent: Double): Double;

{** 标准正态分布 CDF (Abramowitz & Stegun 近似，精度 ~1.5e-7) }
function NormalCDF(X: Double): Double;

{** 标准正态分位数函数（逆 CDF，Peter Acklam 逼近，精度 ~1.15e-9） }
function NormalQuantile(AP: Double): Double;

{** z-score 转双侧 p-value（Hastings 近似，精度 ~1e-5）
 *  用于 Mann-Whitney U、Welch t-test 等场景。 }
function ZToPValue(AZ: Double): Double;

{** 防优化 sink（对标 criterion black_box / Go KeepAlive）
 *  将值混入全局 sink，阻止编译器消除“无副作用”计算。
 *  基准热路径末尾调用，勿用于业务逻辑。 }
procedure BenchBlackBoxInt64(AValue: Int64);
procedure BenchBlackBoxPtr(APtr: Pointer);
procedure BenchBlackBoxBytes(const AData; ALen: Integer);
{** 读取当前 sink（测试 / 调试）；热路径不需要 }
function BenchBlackBoxSink: PtrUInt;
{** 重置 sink（仅测试） }
procedure BenchBlackBoxReset;

implementation

uses
  nextpas.core.math.scalar,
  nextpas.core.text.strings;

{ ===== TBenchResult 便捷方法 ===== }

function TBenchResult.NsPerOpDuration: TDuration;
begin
  if NsPerOp > 0 then
    Result := TDuration.FromNanoseconds(Round(NsPerOp))
  else
    Result := TDuration.Zero;
end;

function TBenchResult.StdDevDuration: TDuration;
begin
  if StdDev > 0 then
    Result := TDuration.FromNanoseconds(Round(StdDev))
  else
    Result := TDuration.Zero;
end;

{ ===== Xoroshiro128+ PRNG (Phase B.1) ===== }

procedure TXoroshiro128Plus.Init(ASeed: UInt64);
{ SplitMix64: 从单个 64 位种子扩展出两个 64 位状态 }
{$PUSH}{$Q-}{$R-}  { SplitMix64 依赖无符号回绕语义 }
var
  LZ: UInt64;
begin
  LZ := ASeed + $9E3779B97F4A7C15;
  LZ := (LZ xor (LZ shr 30)) * $BF58476D1CE4E5B9;
  LZ := (LZ xor (LZ shr 27)) * $94D049BB133111EB;
  S0 := LZ xor (LZ shr 31);
  LZ := S0 + $9E3779B97F4A7C15;
  LZ := (LZ xor (LZ shr 30)) * $BF58476D1CE4E5B9;
  LZ := (LZ xor (LZ shr 27)) * $94D049BB133111EB;
  S1 := LZ xor (LZ shr 31);
  { 防止全零状态 }
  if (S0 = 0) and (S1 = 0) then
    S1 := 1;
end;
{$POP}

function TXoroshiro128Plus.Next: UInt64;
{ 参考: https://prng.di.unimi.it/xoroshiro128plus.c }
var
  LResult: UInt64;
begin
  LResult := S0 + S1;
  S1 := S1 xor S0;
  S0 := ((S0 shl 24) or (S0 shr 40)) xor S1 xor (S1 shl 16);
  S1 := (S1 shl 37) or (S1 shr 27);
  Result := LResult;
end;

function TXoroshiro128Plus.NextInt(AMaxExclusive: Integer): Integer;
{ Lemire's fast rejection method: 无偏映射 UInt64 → [0, AMaxExclusive) }
var
  LRange, LBound, LRemainder: UInt64;
  LVal: UInt64;
begin
  if AMaxExclusive <= 0 then
    raise EIndexOutOfRangeError.CreateFmt('TXoroshiro128Plus.NextInt: AMaxExclusive must be > 0, got %d', [AMaxExclusive]);
  LRange := UInt64(AMaxExclusive);
  LVal := Next;
  LRemainder := LVal mod LRange;
  LBound := (not LRange + 1) mod LRange; { = (-LRange) mod LRange = 2^64 mod LRange }
  while LVal < LBound do
  begin
    LVal := Next;
    LRemainder := LVal mod LRange;
  end;
  Result := Integer(LRemainder);
end;

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
      LChild := ALeft + 2 * (LRoot - ALeft) + 1;
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
  { 尾递归优化，与 DoQuickSortIndirect 一致 }
  while ARight - ALeft >= INSERTION_SORT_THRESHOLD do
  begin
    if ADepthLimit <= 0 then
    begin
      DoHeapSort(AData, ALeft, ARight);
      Exit;
    end;
    Dec(ADepthLimit);

    // 三数取中 pivot
    LPivot := MedianOfThree(AData, ALeft, ARight);
    I := ALeft;
    J := ARight;
    repeat
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
    until I > J;

    // 尾递归：只递归较短的一半，较长的一半用循环处理
    if J - ALeft < ARight - I then
    begin
      DoQuickSort(AData, ALeft, J, ADepthLimit);
      ALeft := I;
    end
    else
    begin
      DoQuickSort(AData, I, ARight, ADepthLimit);
      ARight := J;
    end;
  end;
  DoInsertionSort(AData, ALeft, ARight);
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

{ ===== 标准正态分布函数 (Phase A/B) ===== }

function NormalCDF(X: Double): Double;
const
  LInvSqrt2 = 0.7071067811865475244; { 1/Sqrt(2) }
var
  LAbsX: Double;
  LT, LResult: Double;
  LA1, LA2, LA3, LA4, LA5: Double;
  LP: Double;
begin
  // Abramowitz & Stegun 近似公式
  LA1 := 0.254829592;
  LA2 := -0.284496736;
  LA3 := 1.421413741;
  LA4 := -1.453152027;
  LA5 := 1.061405429;
  LP := 0.3275911;

  // 计算 erf(x / sqrt(2))
  LAbsX := Abs(X) * LInvSqrt2;
  LT := 1.0 / (1.0 + LP * LAbsX);
  LResult := 1.0 - (((((LA5 * LT + LA4) * LT) + LA3) * LT + LA2) * LT + LA1) * LT * Exp(-Sqr(LAbsX));

  // 转换为 CDF
  if X >= 0 then
    Result := 0.5 * (1.0 + LResult)
  else
    Result := 0.5 * (1.0 - LResult);
end;

function NormalQuantile(AP: Double): Double;
const
  LA1 = -3.969683028665376e+01;
  LA2 =  2.209460984245205e+02;
  LA3 = -2.759285104469687e+02;
  LA4 =  1.383577518672690e+02;
  LA5 = -3.066479806614716e+01;
  LA6 =  2.506628277459239e+00;
  LB1 = -5.447609879822406e+01;
  LB2 =  1.615858368580409e+02;
  LB3 = -1.556989798598866e+02;
  LB4 =  6.680131188771972e+01;
  LB5 = -1.328068155288572e+01;
  LC1 = -7.784894002430293e-03;
  LC2 = -3.223964580411365e-01;
  LC3 = -2.400758277161838e+00;
  LC4 = -2.549732539343734e+00;
  LC5 =  4.374664141464968e+00;
  LC6 =  2.938163982698783e+00;
  LD1 =  7.784695709041462e-03;
  LD2 =  3.224671290700398e-01;
  LD3 =  2.445134137142996e+00;
  LD4 =  3.754408661907416e+00;
  LP_LOW  = 0.02425;
  LP_HIGH = 1.0 - LP_LOW;
var
  LQ, LR: Double;
begin
  if AP <= 0.0 then Exit(-1e30);
  if AP >= 1.0 then Exit(1e30);
  if AP = 0.5 then Exit(0.0);

  if AP < LP_LOW then
  begin
    LQ := Sqrt(-2.0 * Ln(AP));
    Result := (((((LC1 * LQ + LC2) * LQ + LC3) * LQ + LC4) * LQ + LC5) * LQ + LC6) /
              ((((LD1 * LQ + LD2) * LQ + LD3) * LQ + LD4) * LQ + 1.0);
  end
  else if AP <= LP_HIGH then
  begin
    LQ := AP - 0.5;
    LR := LQ * LQ;
    Result := (((((LA1 * LR + LA2) * LR + LA3) * LR + LA4) * LR + LA5) * LR + LA6) * LQ /
              (((((LB1 * LR + LB2) * LR + LB3) * LR + LB4) * LR + LB5) * LR + 1.0);
  end
  else
  begin
    LQ := Sqrt(-2.0 * Ln(1.0 - AP));
    Result := -(((((LC1 * LQ + LC2) * LQ + LC3) * LQ + LC4) * LQ + LC5) * LQ + LC6) /
               ((((LD1 * LQ + LD2) * LQ + LD3) * LQ + LD4) * LQ + 1.0);
  end;
end;

function ZToPValue(AZ: Double): Double;
{ Hastings 近似: p ≈ 2 * (1 - Φ(|z|))，双侧检验 }
var
  LT, LK, LP: Double;
begin
  AZ := Abs(AZ);
  if AZ > 6.0 then
    Exit(0.000001)
  else if AZ < BENCH_SIGNIFICANCE_ALPHA_HIGH then
    Exit(1.0);
  LT := 1.0 / (1.0 + 0.2316419 * AZ);
  LK := 0.3989422804014327 * Exp(-0.5 * AZ * AZ);
  LP := LK * (LT * (0.319381530 + LT * (-0.356563782 + LT * (1.781477937 +
        LT * (-1.821255978 + LT * 1.330274429)))));
  Result := 2.0 * LP;
  if Result > 1.0 then Result := 1.0;
  if Result < 0.000001 then Result := 0.000001;
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
  { B21: 自适应预热默认值 }
  Result.AdaptiveWarmup := BENCH_DEFAULT_ADAPTIVE_WARMUP;
  Result.WarmupCVThreshold := BENCH_DEFAULT_WARMUP_CV_THRESHOLD;
  Result.WarmupMaxIterations := BENCH_DEFAULT_WARMUP_MAX_ITERATIONS;
  { P1-14: Output 默认由调用方初始化（Create/CreateNoEnv），此处不设 }
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

{ Glob 模式匹配 - 单源 L1 text.strings.GlobMatch inline 转发 }
function GlobMatch(const APattern, AStr: string): Boolean; inline;
begin
  Result := nextpas.core.text.strings.GlobMatch(APattern, AStr);
end;

{ ===== BenchBlackBox (anti-DCE) ===== }

var
  GBenchBlackBoxSink: PtrUInt = 0;

procedure BenchBlackBoxInt64(AValue: Int64);
begin
  { 混入高低半字，避免纯常量折叠抹掉写入 }
  GBenchBlackBoxSink := GBenchBlackBoxSink xor PtrUInt(AValue)
    xor PtrUInt(AValue shr 32) xor 1;
end;

procedure BenchBlackBoxPtr(APtr: Pointer);
begin
  GBenchBlackBoxSink := GBenchBlackBoxSink xor PtrUInt(APtr) xor 1;
end;

procedure BenchBlackBoxBytes(const AData; ALen: Integer);
var
  LBytes: PByte;
  LI: Integer;
  LAcc: PtrUInt;
begin
  if (ALen <= 0) then
  begin
    GBenchBlackBoxSink := GBenchBlackBoxSink xor 1;
    Exit;
  end;
  LBytes := @AData;
  LAcc := 0;
  for LI := 0 to ALen - 1 do
    LAcc := LAcc + LBytes[LI] + PtrUInt(LI);
  GBenchBlackBoxSink := GBenchBlackBoxSink xor LAcc xor PtrUInt(ALen) xor 1;
end;

function BenchBlackBoxSink: PtrUInt;
begin
  Result := GBenchBlackBoxSink;
end;

procedure BenchBlackBoxReset;
begin
  GBenchBlackBoxSink := 0;
end;

end.
