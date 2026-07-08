{**
 * @desc 基准测试统计分析器
 *
 * 提供均值、中位数、标准差、Mann-Whitney U 检验、
 * Welch t 检验、OLS 回归等统计分析功能。
 *}
unit nextpas.core.bench.stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf;

type
  {** OLS 线性回归结果 (P1-1: 去除固定开销) }
  TOLSRegression = record
    Slope: Double;       { 每次迭代的时间（纳秒） }
    Intercept: Double;   { 固定开销（纳秒） }
    RSquared: Double;    { 拟合度 (0-1)，越接近 1 越好 }
    Valid: Boolean;      { 回归是否有效 }
  end;

  {** 统计分析器实现 }
  TBenchStatsAnalyzer = class(TInterfacedObject, IBenchStatsAnalyzer)
  private

    {** Kahan 求和（减少浮点数累积误差） }
    function KahanSum(const AData: TDoubleArray): Double;

    {** 计算方差 }
    function ComputeVariance(const AData: TDoubleArray; AMean: Double): Double;

    {** 计算标准差 }
    function ComputeStdDev(const AData: TDoubleArray; AMean: Double): Double;

    {** 计算百分位数 }
    function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;

    {** Shapiro-Wilk 正态性检验辅助函数 }
    function ShapiroWilkStatistic(const ASorted: TDoubleArray): Double;

    {** 计算 t 分布的临界值（95%，双侧） }
    function TInv0975(ADF: Double): Double;

    {** 计算 t 分布的临界值（99%，双侧） }
    function TInv0995(ADF: Double): Double;

    {** 计算 t 分布的临界值（自定义 alpha，双侧） (DS-04) }
    function TInvAlpha(ADF, AAlpha: Double): Double;

  public
    {** 构造函数 }
    constructor Create;

    {** 计算统计摘要 }
    function ComputeStats(const ASamples: TDoubleArray): TBenchStats;

    {** 检测异常值 }
    function CountOutliers(const ASorted: TDoubleArray;
      AQ1, AQ3, AMultiplier: Double): Integer;

    {** 检测回归启发式（不是正式显著性检验） }
    function HasHeuristicDifference(const A, B: TBenchStats): Boolean;

    {** 检测回归启发式（自定义显著性水平） (DS-04) }
    function HasHeuristicDifferenceAt(const A, B: TBenchStats; AAlpha: Double): Boolean;

    {** 计算近似 p-value（简化版本） }
    function ComputeApproximatePValue(const A, B: TBenchStats): Double;

    {** 正态性启发式（近似 Shapiro-Wilk） }
    function LooksNormalHeuristic(const ASamples: TDoubleArray): Boolean;

    {** 计算均值 }
    function Mean(const AData: TDoubleArray): Double;

    {** 计算中位数 }
    function Median(const AData: TDoubleArray): Double;

    {** 计算标准差 }
    function StdDev(const AData: TDoubleArray): Double;

    {** 变异系数 CV = StdDev / Mean（用于自适应预热收敛判断）
     *  @returns CV 值；Mean <= 0 时返回 0 }
    function CoefficientOfVariation(const AData: TDoubleArray): Double;

    {** Mann-Whitney U 检验 p-value（非参数，适用于右偏基准数据） }
    function ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;

    {** 几何均值（多 benchmark ratio 聚合的正确方法）
     *  @edge 空数组返回 1.0；非正 ratio 返回 NaN（调用方应检查 IsDoubleNaN） }
    function GeometricMean(const ARatios: TDoubleArray): Double;

    {** OLS 线性回归: time = intercept + slope * N }
    function ComputeOLSRegression(const AIterCounts, ATimes: TDoubleArray): TOLSRegression;

    {** 批量计算百分位（一次排序，多次查询）
     *  E03: 避免在同一数据上重复排序 }
    function ComputePercentiles(const ASamples: TDoubleArray): TPercentileResult;

    {** 单样本 K-S 检验：检验数据是否来自正态分布 N(AMean, AStdDev²) }
    function KolmogorovSmirnovNormalTest(const AData: TDoubleArray;
      AMean, AStdDev: Double): TKSTestResult;

    {** 两样本 K-S 检验：检验两个样本是否来自同一分布 }
    function KolmogorovSmirnovTwoSampleTest(const A, B: TDoubleArray): TKSTestResult;

    {** Bootstrap 假设检验 (Phase B.3) }
    function BootstrapTestDifference(const A, B: TDoubleArray;
      AIterations: Integer = 10000; ASeed: UInt64 = 0): TBootstrapTestResult;

    {** 贝叶斯估计 (Phase C.1) }
    function BayesianEstimate(const AData: TDoubleArray;
      APriorMean, APriorStdDev: Double;
      ASigma: Double = 0): TBayesianEstimate;

    {** 贝叶斯可信区间 (Phase C.2) }
    function BayesianCredibleInterval(const AData: TDoubleArray;
      APriorMean, APriorStdDev: Double;
      ALevel: Double = 0.95; ASigma: Double = 0): TConfidenceInterval;
  end;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.bench.stats.advanced; { Phase B.2: for TAdvancedStats }

{ TBenchStatsAnalyzer }

constructor TBenchStatsAnalyzer.Create;
begin
  inherited Create;
end;

function TBenchStatsAnalyzer.KahanSum(const AData: TDoubleArray): Double;
var
  LSum, LCompensation, LNext, LTemp: Double;
  I: Integer;
begin
  LSum := 0.0;
  LCompensation := 0.0;

  for I := 0 to High(AData) do
  begin
    LNext := AData[I] - LCompensation;
    LTemp := LSum + LNext;
    LCompensation := (LTemp - LSum) - LNext;
    LSum := LTemp;
  end;

  Result := LSum;
end;

function TBenchStatsAnalyzer.Mean(const AData: TDoubleArray): Double;
var
  LLen: Integer;
  LSum: Double;
  I: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(0.0);

  // 快速路径：小数组使用简单求和（避免 KahanSum 开销）
  // 阈值设为 256，覆盖常见基准测试场景 (100, 1000)
  if LLen <= 256 then
  begin
    LSum := 0;
    for I := 0 to High(AData) do
      LSum += AData[I];
    Result := LSum / LLen;
  end
  else
    // 大数组使用 Kahan 求和保证精度
    Result := KahanSum(AData) / LLen;
end;

function TBenchStatsAnalyzer.Median(const AData: TDoubleArray): Double;
var
  LSorted: TDoubleArray;
  LLen: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit(0.0);

  LSorted := Copy(AData);
  SortDoubleArray(LSorted);

  if LLen mod 2 = 1 then
    Result := LSorted[LLen div 2]
  else
    Result := (LSorted[LLen div 2 - 1] + LSorted[LLen div 2]) / 2.0;
end;

function TBenchStatsAnalyzer.ComputeVariance(const AData: TDoubleArray; AMean: Double): Double;
var
  LSumSq, LCompensation, LNext, LTemp: Double;
  I: Integer;
begin
  if Length(AData) <= 1 then
    Exit(0.0);

  {** NaN/Inf guard: avoid FPU exception 207 on NaN arithmetic }
  if IsNan(AMean) or IsInfinite(AMean) then
    Exit(0.0);

  // Kahan compensated summation for Sqr(x - mean)
  LSumSq := 0.0;
  LCompensation := 0.0;
  for I := 0 to High(AData) do
  begin
    LNext := Sqr(AData[I] - AMean) - LCompensation;
    LTemp := LSumSq + LNext;
    LCompensation := (LTemp - LSumSq) - LNext;
    LSumSq := LTemp;
  end;

  Result := LSumSq / (Length(AData) - 1);  // 样本方差（除以 n-1）
end;

function TBenchStatsAnalyzer.ComputeStdDev(const AData: TDoubleArray; AMean: Double): Double;
begin
  Result := Sqrt(ComputeVariance(AData, AMean));
end;

function TBenchStatsAnalyzer.StdDev(const AData: TDoubleArray): Double;
var
  LMean: Double;
begin
  if Length(AData) <= 1 then
    Exit(0.0);
  LMean := Mean(AData);
  Result := ComputeStdDev(AData, LMean);
end;

function TBenchStatsAnalyzer.CoefficientOfVariation(const AData: TDoubleArray): Double;
var
  LMean, LStdDev: Double;
begin
  if Length(AData) < 2 then
    Exit(0.0);
  LMean := Mean(AData);
  if LMean <= 0 then
    Exit(0.0);
  LStdDev := ComputeStdDev(AData, LMean);
  Result := LStdDev / LMean;
end;

function TBenchStatsAnalyzer.Percentile(const ASorted: TDoubleArray; APercent: Double): Double;
begin
  { PF-06: range validation — reject out-of-range percentiles }
  if (APercent < 0.0) or (APercent > 100.0) then
    raise EBenchInvalidParam.CreateFmt(
      'TBenchStatsAnalyzer.Percentile: APercent must be in [0, 100], got %.2f', [APercent]);
  Result := PercentileSorted(ASorted, APercent);
end;

function TBenchStatsAnalyzer.CountOutliers(const ASorted: TDoubleArray;
  AQ1, AQ3, AMultiplier: Double): Integer;
var
  LLower, LUpper: Double;
  I: Integer;
begin
  LLower := AQ1 - AMultiplier * (AQ3 - AQ1);
  LUpper := AQ3 + AMultiplier * (AQ3 - AQ1);

  Result := 0;
  for I := 0 to High(ASorted) do
  begin
    if (ASorted[I] < LLower) or (ASorted[I] > LUpper) then
      Inc(Result);
  end;
end;

  {** PF-01: Single-pass stats computation — sum/sum_sq + percentile samples merged.
   *  Replaces the old double-pass approach (Mean on unsorted + ComputeStdDev on unsorted). }
function TBenchStatsAnalyzer.ComputeStats(const ASamples: TDoubleArray): TBenchStats;
var
  LSorted: TDoubleArray;
  LLen: Integer;
  LValidCount: Integer; { F-09: count of non-NaN samples }
  LMean, LVariance: Double;
  LDelta, LDelta2, LM2: Double;
  LT95, LT99: Double;
  I: Integer;
  { B22: Outlier-aware variables }
  LFiltered: TDoubleArray;
  LQ1, LQ3, LFenceLow, LFenceHigh: Double;
  LFilteredCount: Integer;
begin
  LLen := Length(ASamples);
  if LLen = 0 then
    raise EBenchInvalidParam.Create('ComputeStats: sample array must not be empty');

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  { Welford's single-pass algorithm for numerically stable variance.
    Reference: Welford, B.P. (1962). "Note on a Method for Calculating
    Corrected Sums of Squares and Products". Technometrics.
    F-09: Skip NaN samples to prevent NaN propagation. }
  LMean := 0.0;
  LM2 := 0.0;  { sum of squared deviations from current mean }
  LValidCount := 0;
  for I := 0 to High(ASamples) do
  begin
    if IsDoubleNaN(ASamples[I]) then
      Continue;  { F-09: skip NaN samples }
    Inc(LValidCount);
    LDelta := ASamples[I] - LMean;
    LMean := LMean + LDelta / LValidCount;
    LDelta2 := ASamples[I] - LMean;
    LM2 := LM2 + LDelta * LDelta2;
  end;

  if LValidCount > 1 then
    LVariance := LM2 / (LValidCount - 1)  { sample variance, F-09: use valid count }
  else
    LVariance := 0.0;

  Result.Mean := LMean;
  if LVariance > 0 then
    Result.StdDev := Sqrt(LVariance)
  else
    Result.StdDev := 0.0;
  { 直接在已排序的 LSorted 上查询百分位，避免 ComputePercentiles 再次排序 }
  Result.Median := PercentileSorted(LSorted, 50);
  Result.Min := LSorted[0];
  Result.Max := LSorted[High(LSorted)];
  Result.P5 := PercentileSorted(LSorted, 5.0);
  Result.P25 := PercentileSorted(LSorted, 25.0);
  Result.P75 := PercentileSorted(LSorted, 75.0);
  Result.P95 := PercentileSorted(LSorted, 95.0);
  Result.P99 := PercentileSorted(LSorted, 99.0);
  Result.IQR := Result.P75 - Result.P25;
  Result.OutlierCount := CountOutliers(LSorted, Result.P25, Result.P75, OUTLIER_MULTIPLIER);
  Result.SampleCount := LValidCount; { F-09: report valid sample count }

  { B22: Outlier-aware statistics - compute filtered stats excluding outliers }
  Result.OutlierMethod := 'Tukey';
  Result.OutlierThreshold := OUTLIER_MULTIPLIER;
  if (Result.OutlierCount > 0) and (LValidCount > Result.OutlierCount) then
  begin
    LQ1 := Result.P25;
    LQ3 := Result.P75;
    LFenceLow := LQ1 - OUTLIER_MULTIPLIER * Result.IQR;
    LFenceHigh := LQ3 + OUTLIER_MULTIPLIER * Result.IQR;
    SetLength(LFiltered, LValidCount);
    LFilteredCount := 0;
    for I := 0 to High(ASamples) do
    begin
      if IsDoubleNaN(ASamples[I]) then
        Continue;
      if (ASamples[I] >= LFenceLow) and (ASamples[I] <= LFenceHigh) then
      begin
        LFiltered[LFilteredCount] := ASamples[I];
        Inc(LFilteredCount);
      end;
    end;
    SetLength(LFiltered, LFilteredCount);
    if LFilteredCount > 0 then
    begin
      Result.FilteredCount := LFilteredCount;
      Result.FilteredMean := Mean(LFiltered);
      Result.FilteredStdDev := StdDev(LFiltered);
      SortDoubleArray(LFiltered);
      Result.FilteredMedian := Percentile(LFiltered, 50);
    end
    else
    begin
      Result.FilteredMean := LMean;
      Result.FilteredStdDev := Result.StdDev;
      Result.FilteredMedian := Result.Median;
      Result.FilteredCount := LValidCount;
    end;
  end
  else
  begin
    Result.FilteredMean := LMean;
    Result.FilteredStdDev := Result.StdDev;
    Result.FilteredMedian := Result.Median;
    Result.FilteredCount := LValidCount;
  end;

  // 95% 置信区间（使用 t 分布临界值）
  if LValidCount > 1 then
  begin
    LT95 := TInv0975(LValidCount - 1);
    LT99 := TInv0995(LValidCount - 1);
    Result.Confidence95Low := LMean - LT95 * Result.StdDev / Sqrt(LValidCount);
    Result.Confidence95High := LMean + LT95 * Result.StdDev / Sqrt(LValidCount);
    Result.Confidence99Low := LMean - LT99 * Result.StdDev / Sqrt(LValidCount);
    Result.Confidence99High := LMean + LT99 * Result.StdDev / Sqrt(LValidCount);
  end
  else
  begin
    Result.Confidence95Low := LMean;
    Result.Confidence95High := LMean;
    Result.Confidence99Low := LMean;
    Result.Confidence99High := LMean;
  end;
end;

function TBenchStatsAnalyzer.TInv0975(ADF: Double): Double;
begin
  Result := TInvLookup(ADF, TINV95_DATA, Z_SCORE_95);
end;

function TBenchStatsAnalyzer.TInv0995(ADF: Double): Double;
begin
  Result := TInvLookup(ADF, TINV99_DATA, Z_SCORE_99);
end;

function TBenchStatsAnalyzer.TInvAlpha(ADF, AAlpha: Double): Double;
begin
  // DS-04: map common alpha values to lookup tables; fallback to 95%
  if AAlpha <= 0.01 then
    Result := TInvLookup(ADF, TINV99_DATA, Z_SCORE_99)
  else if AAlpha <= 0.05 then
    Result := TInvLookup(ADF, TINV95_DATA, Z_SCORE_95)
  else
    // alpha > 0.05: use 95% critical value (conservative)
    Result := TInvLookup(ADF, TINV95_DATA, Z_SCORE_95);
end;

function TBenchStatsAnalyzer.HasHeuristicDifference(const A, B: TBenchStats): Boolean;
begin
  // 默认 95% 置信水平 (alpha = 0.05)
  Result := HasHeuristicDifferenceAt(A, B, 0.05);
end;

function TBenchStatsAnalyzer.HasHeuristicDifferenceAt(const A, B: TBenchStats;
  AAlpha: Double): Boolean;
var
  LTStat: Double;
  LDF: Double;
  LVarA, LVarB: Double;
begin
  if (A.SampleCount <= 1) or (B.SampleCount <= 1) then
    Exit(False);

  LVarA := Sqr(A.StdDev) / A.SampleCount;
  LVarB := Sqr(B.StdDev) / B.SampleCount;

  // 避免除以零
  if (LVarA + LVarB) < 1e-10 then
    Exit(False);

  // Welch's t-test 风格统计量，用于启发式比较
  LTStat := Abs(A.Mean - B.Mean) / Sqrt(LVarA + LVarB);

  // Welch-Satterthwaite 自由度
  LDF := Sqr(LVarA + LVarB) /
         (Sqr(LVarA) / (A.SampleCount - 1) + Sqr(LVarB) / (B.SampleCount - 1));

  // 比较 t 统计量与指定 alpha 的临界值
  Result := LTStat > TInvAlpha(LDF, AAlpha);
end;

{** 近似 p-value 评级（非精确统计检验）
 *
 *  使用正态近似 + t 分布修正，返回粗略的显著性评级：
 *  - < 0.001: 高度显著
 *  - 0.001-0.01: 显著
 *  - 0.01-0.05: 边缘显著
 *  - > 0.05: 不显著
 *
 *  注意：这是启发式评级，非精确 p-value。小样本时误差可达 10%+。
 *  精确检验请使用 Mann-Whitney U（非参数，不依赖分布假设）。 }
function TBenchStatsAnalyzer.ComputeApproximatePValue(const A, B: TBenchStats): Double;
var
  LTStat: Double;
  LVarA, LVarB: Double;
  LDF: Double;
begin
  if (A.SampleCount <= 1) or (B.SampleCount <= 1) then
    Exit(1.0);

  LVarA := Sqr(A.StdDev) / A.SampleCount;
  LVarB := Sqr(B.StdDev) / B.SampleCount;

  // 避免除以零
  if (LVarA + LVarB) < 1e-10 then
    Exit(1.0);

  // Welch's t-test 风格统计量，用于近似评级
  LTStat := Abs(A.Mean - B.Mean) / Sqrt(LVarA + LVarB);

  // Welch-Satterthwaite 自由度
  LDF := Sqr(LVarA + LVarB) /
         (Sqr(LVarA) / (A.SampleCount - 1) + Sqr(LVarB) / (B.SampleCount - 1));

  // 使用正态近似 + 小样本 t 分布修正
  Result := ZToPValue(LTStat);
  if LDF < 30 then
    Result := Result * (1.0 + 1.0 / (4.0 * LDF));
  if Result > 1.0 then
    Result := 1.0;
  if Result < 0.001 then
    Result := 0.001;
end;

function TBenchStatsAnalyzer.ShapiroWilkStatistic(const ASorted: TDoubleArray): Double;
var
  LN: Integer;
  LMean: Double;
  LSumSq, LSumWeighted: Double;
  LNormFactor: Double;
  I: Integer;
begin
  // 简化的 Shapiro-Wilk 风格统计量
  // 完整实现需要查表（m_i 系数），这里用线性权重近似。
  // 归一化保证 W ∈ [0,1]（Cauchy-Schwarz 不等式）。
  LN := Length(ASorted);
  if LN < 3 then
    Exit(1.0);

  LMean := Mean(ASorted);
  LSumSq := 0.0;
  LSumWeighted := 0.0;

  // 权重 w_i = (N-1-2i)/(N-1) 的 L2 范数:
  //   Σ w_i^2 = N(N+1) / (3(N-1))
  // 归一化因子 = 1/sqrt(Σ w_i^2)
  LNormFactor := Sqrt(3.0 * (LN - 1) / (LN * (LN + 1)));

  for I := 0 to LN - 1 do
  begin
    LSumSq += Sqr(ASorted[I] - LMean);
    LSumWeighted += (ASorted[I] - LMean) * (LN - 1 - 2 * I) / (LN - 1);
  end;

  if LSumSq < 1e-10 then
    Exit(1.0);

  // W = (Σ w̃_i * (x_i - mean))^2 / Σ (x_i - mean)^2, where w̃ are L2-normalized
  // By Cauchy-Schwarz: W ∈ [0,1]. W close to 1 → normal-like.
  Result := Sqr(LSumWeighted * LNormFactor) / LSumSq;
end;

function TBenchStatsAnalyzer.LooksNormalHeuristic(const ASamples: TDoubleArray): Boolean;
var
  LSorted: TDoubleArray;
  LW: Double;
  LN: Integer;
begin
  LN := Length(ASamples);
  if LN < 3 then
    Exit(True);  // 样本太少，无法判断

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  // Shapiro-Wilk 风格启发式
  LW := ShapiroWilkStatistic(LSorted);

  // 简化的判断阈值（完整实现需要查表）
  // W 接近 1 表示正态分布
  Result := LW > 0.9;
end;

{** Mann-Whitney U 检验实现
 *
 * 非参数秩和检验，不要求数据正态分布。
 * 基准数据通常右偏（偶尔的 GC、缓存抖动导致长尾），
 * t-test 的正态假设不成立，Mann-Whitney U 更可靠。
 *
 * 算法：
 *   1. 合并两组样本，按值排序分配秩次
 *   2. 平均秩处理并列值（ties）
 *   3. U1 = n1*n2 + n1*(n1+1)/2 - R1
 *   4. 大样本 (n>20) 用正态近似计算 z-score 和 p-value
 *   5. 小样本用精确分布（查表/递推）
 }
function TBenchStatsAnalyzer.ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;
var
  LN1, LN2, LN: Integer;
  LCombined: TDoubleArray;
  LGroup: TInt64Array;   // 0=A, 1=B
  LSortedIdx: TInt64Array;
  LRanks: TDoubleArray;
  LRankSum1: Double;
  LU1, LU2, LU: Double;
  LMU, LSigma: Double;
  LTieCorrection: Double;
  LZ: Double;
  LRunStart, LRunEnd, I, J, K: Integer;
  LAvgRank: Double;

begin
  LN1 := Length(A);
  LN2 := Length(B);
  LN := LN1 + LN2;

  if (LN1 = 0) or (LN2 = 0) then
    Exit(1.0);
  if LN = 1 then
    Exit(1.0);

  { 1. 合并样本并标记来源，过滤 NaN }
  SetLength(LCombined, LN);
  SetLength(LGroup, LN);
  LN := 0;
  for I := 0 to LN1 - 1 do
  begin
    if not IsDoubleNaN(A[I]) then
    begin
      LCombined[LN] := A[I];
      LGroup[LN] := 0;
      Inc(LN);
    end;
  end;
  LN1 := LN;
  for I := 0 to Length(B) - 1 do
  begin
    if not IsDoubleNaN(B[I]) then
    begin
      LCombined[LN] := B[I];
      LGroup[LN] := 1;
      Inc(LN);
    end;
  end;
  LN2 := LN - LN1;

  if (LN1 = 0) or (LN2 = 0) then
    Exit(1.0);
  if LN = 1 then
    Exit(1.0);

  SetLength(LCombined, LN);
  SetLength(LGroup, LN);

  { 2. 构建索引数组用于间接排序 }
  SetLength(LSortedIdx, LN);
  for I := 0 to LN - 1 do
    LSortedIdx[I] := I;

  { IntroSort 间接排序（替换原插入排序，处理大样本更高效） }
  SortIndirect(LSortedIdx, LCombined);

  { 3. 分配秩次（并列值取平均秩） }
  SetLength(LRanks, LN);
  I := 0;
  while I < LN do
  begin
    { 找到当前 run 的结束位置（相同值的区间） }
    LRunStart := I;
    LRunEnd := I;
    while (LRunEnd + 1 < LN) and
          (LCombined[LSortedIdx[LRunEnd + 1]] = LCombined[LSortedIdx[LRunStart]]) do
      Inc(LRunEnd);

    { 平均秩 = (run 开始位置 + run 结束位置 + 2) / 2
      位置从 0 开始，秩从 1 开始 }
    LAvgRank := (LRunStart + LRunEnd + 2) / 2.0;
    for K := LRunStart to LRunEnd do
      LRanks[LSortedIdx[K]] := LAvgRank;

    I := LRunEnd + 1;
  end;

  { 4. 计算样本 A 的秩和 }
  LRankSum1 := 0.0;
  for I := 0 to LN - 1 do
    if LGroup[I] = 0 then
      LRankSum1 := LRankSum1 + LRanks[I];

  { 5. 计算 U 统计量 }
  LU1 := LN1 * LN2 + LN1 * (LN1 + 1) / 2.0 - LRankSum1;
  LU2 := LN1 * LN2 - LU1;
  if LU1 < LU2 then
    LU := LU1
  else
    LU := LU2;

  { 6. 正态近似计算 p-value }
  LMU := LN1 * LN2 / 2.0;

  { 并列值修正（tie correction） }
  LTieCorrection := 0.0;
  I := 0;
  while I < LN do
  begin
    LRunStart := I;
    LRunEnd := I;
    while (LRunEnd + 1 < LN) and
          (LCombined[LSortedIdx[LRunEnd + 1]] = LCombined[LSortedIdx[LRunStart]]) do
      Inc(LRunEnd);
    K := LRunEnd - LRunStart + 1;
    if K > 1 then
      LTieCorrection := LTieCorrection + (K * K * K - K);
    I := LRunEnd + 1;
  end;

  LSigma := Sqrt(LN1 * LN2 / 12.0 *
    (LN + 1 - LTieCorrection / (LN * (LN - 1))));

  if LSigma < 1e-10 then
    Exit(1.0);

  LZ := (LU - LMU) / LSigma;
  Result := ZToPValue(LZ);
end;

{** 几何均值实现
 *
 * 几何均值 = (r1 * r2 * ... * rn) ^ (1/n)
 *           = exp(1/n * sum(ln(ri)))
 *
 * 为什么用几何均值而不是算术均值：
 *   Ratio = 1.2 表示慢 20%，ratio = 0.8 表示快 20%。
 *   算术均值 (1.2 + 0.8) / 2 = 1.0 → 看起来没变化
 *   但实际是: 先慢 20% 再快 20% = 0.96 → 几何均值 = sqrt(1.2*0.8) = 0.9798
 *   几何均值正确反映了倍率的"平均"含义。
 *
 * Go benchstat v2 使用几何均值聚合多 benchmark 的 ratio。
 }
function TBenchStatsAnalyzer.GeometricMean(const ARatios: TDoubleArray): Double;
var
  LLen: Integer;
  LSumLn: Double;
  I: Integer;
begin
  LLen := Length(ARatios);
  if LLen = 0 then
    Exit(1.0);

  { 所有 ratio 必须为正数 }
  LSumLn := 0.0;
  for I := 0 to LLen - 1 do
  begin
    if ARatios[I] <= 0.0 then
      Exit(0.0 / 0.0);  { F-13: 非法 ratio，返回 NaN 而非 0.0 }
    LSumLn := LSumLn + Ln(ARatios[I]);
  end;

  Result := Exp(LSumLn / LLen);
end;

{** OLS 线性回归实现
 *
 *  给定 N 个数据点 (x_i, y_i)，求 y = intercept + slope * x 的最小二乘解。
 *
 *  公式:
 *    slope = (n * Σxy - Σx * Σy) / (n * Σx² - (Σx)²)
 *    intercept = (Σy - slope * Σx) / n
 *    R² = 1 - SS_res / SS_tot
 *
 *  应用: Rust criterion 用此方法分离每次迭代的固定开销和可变开销。
 *  在多个迭代次数 N 上运行 benchmark，回归 total_time = α + β*N，
 *  β 就是每次迭代的真实时间，α 是固定开销。
 }
function TBenchStatsAnalyzer.ComputeOLSRegression(
  const AIterCounts, ATimes: TDoubleArray): TOLSRegression;
var
  LN: Integer;
  LSX, LSY, LSXY, LSX2, LSY2: Double;
  LMeanY, LSStot, SSres: Double;
  LD: Double;
  I: Integer;
begin
  Result := Default(TOLSRegression);
  LN := Length(AIterCounts);

  if (LN < 2) or (LN <> Length(ATimes)) then
  begin
    Result.Valid := False;
    Exit;
  end;

  { 累加统计量 }
  LSX := 0; LSY := 0; LSXY := 0; LSX2 := 0; LSY2 := 0;
  for I := 0 to LN - 1 do
  begin
    LSX := LSX + AIterCounts[I];
    LSY := LSY + ATimes[I];
    LSXY := LSXY + AIterCounts[I] * ATimes[I];
    LSX2 := LSX2 + AIterCounts[I] * AIterCounts[I];
    LSY2 := LSY2 + ATimes[I] * ATimes[I];
  end;

  { 分母 = n*Σx² - (Σx)² }
  LD := LN * LSX2 - LSX * LSX;
  if Abs(LD) < 1e-10 then
  begin
    Result.Valid := False;
    Exit;
  end;

  Result.Slope := (LN * LSXY - LSX * LSY) / LD;
  Result.Intercept := (LSY - Result.Slope * LSX) / LN;

  { R² = 1 - SS_res / SS_tot }
  LMeanY := LSY / LN;
  LSStot := 0;
  SSres := 0;
  for I := 0 to LN - 1 do
  begin
    LSStot := LSStot + Sqr(ATimes[I] - LMeanY);
    SSres := SSres + Sqr(ATimes[I] - (Result.Intercept + Result.Slope * AIterCounts[I]));
  end;

  if LSStot > 1e-10 then
    Result.RSquared := 1.0 - SSres / LSStot
  else
    Result.RSquared := 1.0; { 所有 y 相同 → 完美拟合 }

  Result.Valid := True;
end;

function TBenchStatsAnalyzer.ComputePercentiles(
  const ASamples: TDoubleArray): TPercentileResult;
var
  LSorted: TDoubleArray;
begin
  Result := Default(TPercentileResult);

  if Length(ASamples) = 0 then
    Exit;

  // E03: 一次排序，多次查询
  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  Result.P5 := Percentile(LSorted, 5.0);
  Result.P25 := Percentile(LSorted, 25.0);
  Result.P50 := Percentile(LSorted, 50.0);
  Result.P75 := Percentile(LSorted, 75.0);
  Result.P95 := Percentile(LSorted, 95.0);
  Result.P99 := Percentile(LSorted, 99.0);
end;

{ K-S 检验辅助函数 }

{ NormalCDF and NormalQuantile are now in nextpas.core.bench.base }

{** Kolmogorov 分布 CDF
 *  K(x) = 1 - 2 * Σ((-1)^(k-1) * exp(-2 * k^2 * x^2))
 *  输入 x = √n * D（其中 D 是 K-S 统计量，n 是样本大小） }
function KolmogorovCDF(AX: Double): Double;
var
  LK: Integer;
  LSum, LTerm: Double;
  LK2: Double;
begin
  if AX <= 0 then
  begin
    Result := 0.0;
    Exit;
  end;

  // 对于 x > 2，CDF 接近 1
  if AX > 2.0 then
  begin
    Result := 1.0;
    Exit;
  end;

  // Kolmogorov 分布: K(x) = 1 - 2 * Σ((-1)^(k-1) * exp(-2 * k^2 * x^2))
  // 使用前 20 项求和（足够精确）
  LSum := 0.0;
  for LK := 1 to 20 do
  begin
    LK2 := LK * LK;
    LTerm := Exp(-2.0 * LK2 * AX * AX);
    if LK mod 2 = 1 then
      LSum := LSum + LTerm
    else
      LSum := LSum - LTerm;
  end;

  Result := 1.0 - 2.0 * LSum;
  if Result < 0 then
    Result := 0;
  if Result > 1 then
    Result := 1;
end;

function TBenchStatsAnalyzer.KolmogorovSmirnovNormalTest(
  const AData: TDoubleArray; AMean, AStdDev: Double): TKSTestResult;
var
  LN: Integer;
  LSorted: TDoubleArray;
  LI: Integer;
  LEmpiricalCDF: Double;
  LTheoreticalCDF: Double;
  LD, LMaxD: Double;
  LZ: Double;
begin
  Result := Default(TKSTestResult);

  LN := Length(AData);
  Result.SampleSize1 := LN;
  Result.SampleSize2 := 0;

  // 边界条件
  if LN = 0 then
  begin
    Result.Statistic := 0.0;
    Result.PValue := 1.0;
    Result.IsSignificant := False;
    Exit;
  end;

  if LN = 1 then
  begin
    Result.Statistic := 0.0;
    Result.PValue := 1.0;
    Result.IsSignificant := False;
    Exit;
  end;

  // 标准差为 0 时无法检验
  if AStdDev <= 0 then
  begin
    Result.Statistic := 0.0;
    Result.PValue := 1.0;
    Result.IsSignificant := False;
    Exit;
  end;

  // 排序数据
  LSorted := Copy(AData);
  SortDoubleArray(LSorted);

  // 计算 K-S 统计量 D = max|Fn(x) - F0(x)|
  LMaxD := 0.0;
  for LI := 0 to LN - 1 do
  begin
    // 经验分布函数 Fn(x) = (i+1) / n
    LEmpiricalCDF := (LI + 1) / LN;

    // 理论分布函数 F0(x) = Φ((x - μ) / σ)
    LZ := (LSorted[LI] - AMean) / AStdDev;
    LTheoreticalCDF := NormalCDF(LZ);

    // 计算 |Fn(x) - F0(x)|
    LD := Abs(LEmpiricalCDF - LTheoreticalCDF);
    if LD > LMaxD then
      LMaxD := LD;

    // 也检查 Fn(x-) 的情况
    LEmpiricalCDF := LI / LN;
    LD := Abs(LEmpiricalCDF - LTheoreticalCDF);
    if LD > LMaxD then
      LMaxD := LD;
  end;

  Result.Statistic := LMaxD;

  // 计算 p-value（使用渐近分布）
  // 对于大样本，√n * D 服从 Kolmogorov 分布
  Result.PValue := 1.0 - KolmogorovCDF(Sqrt(LN) * LMaxD);

  // 判断是否显著（α=0.05）
  Result.IsSignificant := Result.PValue < 0.05;
end;

function TBenchStatsAnalyzer.KolmogorovSmirnovTwoSampleTest(
  const A, B: TDoubleArray): TKSTestResult;
var
  LN1, LN2: Integer;
  LSorted1, LSorted2: TDoubleArray;
  LI, LJ: Integer;
  LCDF1, LCDF2: Double;
  LD, LMaxD: Double;
  LCombinedN: Double;
begin
  Result := Default(TKSTestResult);

  LN1 := Length(A);
  LN2 := Length(B);
  Result.SampleSize1 := LN1;
  Result.SampleSize2 := LN2;

  // 边界条件
  if (LN1 = 0) or (LN2 = 0) then
  begin
    Result.Statistic := 0.0;
    Result.PValue := 1.0;
    Result.IsSignificant := False;
    Exit;
  end;

  // 排序两个样本
  LSorted1 := Copy(A);
  LSorted2 := Copy(B);
  SortDoubleArray(LSorted1);
  SortDoubleArray(LSorted2);

  // 计算 K-S 统计量 D = max|F1(x) - F2(x)|
  LMaxD := 0.0;
  LI := 0;
  LJ := 0;

  // 合并遍历两个排序数组
  while (LI < LN1) and (LJ < LN2) do
  begin
    if LSorted1[LI] <= LSorted2[LJ] then
    begin
      // 在 x = LSorted1[LI] 处计算两个经验分布函数
      LCDF1 := (LI + 1) / LN1;
      LCDF2 := LJ / LN2;  // F2(x-) = j/n2
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      Inc(LI);
    end
    else
    begin
      // 在 x = LSorted2[LJ] 处计算两个经验分布函数
      LCDF1 := LI / LN1;  // F1(x-) = i/n1
      LCDF2 := (LJ + 1) / LN2;
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      Inc(LJ);
    end;
  end;

  // 处理剩余元素
  while LI < LN1 do
  begin
    LCDF1 := (LI + 1) / LN1;
    LCDF2 := 1.0;
    LD := Abs(LCDF1 - LCDF2);
    if LD > LMaxD then
      LMaxD := LD;
    Inc(LI);
  end;

  while LJ < LN2 do
  begin
    LCDF1 := 1.0;
    LCDF2 := (LJ + 1) / LN2;
    LD := Abs(LCDF1 - LCDF2);
    if LD > LMaxD then
      LMaxD := LD;
    Inc(LJ);
  end;

  Result.Statistic := LMaxD;

  // 计算 p-value（使用渐近分布）
  // 有效样本大小: n_eff = (n1 * n2) / (n1 + n2)
  LCombinedN := (LN1 * LN2) / (LN1 + LN2);
  Result.PValue := 1.0 - KolmogorovCDF(Sqrt(LCombinedN) * LMaxD);

  // 判断是否显著（α=0.05）
  Result.IsSignificant := Result.PValue < 0.05;
end;

function TBenchStatsAnalyzer.BootstrapTestDifference(const A, B: TDoubleArray;
  AIterations: Integer; ASeed: UInt64): TBootstrapTestResult;
{ F-09: 直接调用独立函数，无需创建 TAdvancedStats 实例 }
begin
  Result := nextpas.core.bench.stats.advanced.BootstrapTestDifference(A, B, AIterations, ASeed);
end;

{ ===== 贝叶斯估计 (Phase C) ===== }

function TBenchStatsAnalyzer.BayesianEstimate(const AData: TDoubleArray;
  APriorMean, APriorStdDev: Double; ASigma: Double): TBayesianEstimate;
{ 正态-正态共轭模型
  先验: μ ~ N(μ0, σ0²)
  似然: x_i ~ N(μ, σ²)
  后验: μ|x ~ N(μ_n, σ_n²)

  σ_n² = 1 / (1/σ0² + n/σ²)
  μ_n = σ_n² * (μ0/σ0² + n*x̄/σ²) }
var
  LN: Integer;
  LSampleMean: Double;
  LSigma: Double;
  LPriorVar, LDataVar: Double;
  LPosteriorVar: Double;
  LZ: Double;
begin
  LN := Length(AData);

  Result.PriorMean := APriorMean;
  Result.PriorStdDev := APriorStdDev;
  Result.SampleSize := LN;

  if LN = 0 then
  begin
    { 无数据：后验 = 先验 }
    Result.PosteriorMean := APriorMean;
    Result.PosteriorStdDev := APriorStdDev;
    Result.SampleMean := 0;
    Result.CredibleLower := APriorMean - 1.96 * APriorStdDev;
    Result.CredibleUpper := APriorMean + 1.96 * APriorStdDev;
    Result.CredibleLevel := 0.95;
    Exit;
  end;

  { 计算样本均值 }
  LSampleMean := Mean(AData);
  Result.SampleMean := LSampleMean;

  { 确定 σ }
  if ASigma > 0 then
    LSigma := ASigma
  else
    LSigma := StdDev(AData);

  { 防止 σ = 0 }
  if LSigma < 1e-10 then
    LSigma := 1e-10;

  { 计算后验参数 }
  LPriorVar := APriorStdDev * APriorStdDev;
  LDataVar := LSigma * LSigma / LN; { σ²/n }

  { σ_n² = 1 / (1/σ0² + n/σ²) }
  LPosteriorVar := 1.0 / (1.0 / LPriorVar + LN / (LSigma * LSigma));
  Result.PosteriorStdDev := Sqrt(LPosteriorVar);

  { μ_n = σ_n² * (μ0/σ0² + n*x̄/σ²) }
  Result.PosteriorMean := LPosteriorVar * (APriorMean / LPriorVar + LN * LSampleMean / (LSigma * LSigma));

  { 95% 可信区间 }
  LZ := NormalQuantile(0.975); { F-03: use NormalQuantile instead of hardcoded 1.96 }
  Result.CredibleLower := Result.PosteriorMean - LZ * Result.PosteriorStdDev;
  Result.CredibleUpper := Result.PosteriorMean + LZ * Result.PosteriorStdDev;
  Result.CredibleLevel := 0.95;
end;

function TBenchStatsAnalyzer.BayesianCredibleInterval(const AData: TDoubleArray;
  APriorMean, APriorStdDev: Double; ALevel: Double; ASigma: Double): TConfidenceInterval;
var
  LEstimate: TBayesianEstimate;
  LZ: Double;
begin
  LEstimate := BayesianEstimate(AData, APriorMean, APriorStdDev, ASigma);

  { 使用正态分位数函数计算指定水平的 z 值 }
  LZ := NormalQuantile(1.0 - (1.0 - ALevel) / 2.0);

  Result.Lower := LEstimate.PosteriorMean - LZ * LEstimate.PosteriorStdDev;
  Result.Upper := LEstimate.PosteriorMean + LZ * LEstimate.PosteriorStdDev;
  Result.Level := ALevel;
end;

end.
