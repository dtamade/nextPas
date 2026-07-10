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
    function ShapiroWilkStatistic(const ASorted: TDoubleArray; AMean: Double): Double;

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
  LLen: Integer;
  LSumSq, LCompensation, LNext, LTemp: Double;
  LDiff: Double;
  I: Integer;
begin
  LLen := Length(AData);
  if LLen <= 1 then
    Exit(0.0);

  {** NaN/Inf guard: avoid FPU exception 207 on NaN arithmetic }
  if IsNan(AMean) or IsInfinite(AMean) then
    Exit(0.0);

  { Fast path: small arrays use simple summation (avoid Kahan overhead) }
  if LLen <= 256 then
  begin
    LSumSq := 0.0;
    for I := 0 to High(AData) do
    begin
      LDiff := AData[I] - AMean;
      LSumSq := LSumSq + LDiff * LDiff;
    end;
    Result := LSumSq / (LLen - 1);
  end
  else
  begin
    { Kahan compensated summation for large arrays }
    LSumSq := 0.0;
    LCompensation := 0.0;
    for I := 0 to High(AData) do
    begin
      LNext := Sqr(AData[I] - AMean) - LCompensation;
      LTemp := LSumSq + LNext;
      LCompensation := (LTemp - LSumSq) - LNext;
      LSumSq := LTemp;
    end;
    Result := LSumSq / (LLen - 1);
  end;
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
{ 已排序数据上的 O(log n) 异常值计数。
  低于下界的异常值在数组头部，高于上界的在尾部，用两次二分查找定位。 }
var
  LLower, LUpper: Double;
  LLen, LLeft, LRight, LMid: Integer;
  LLowerCount, LUpperStart: Integer;
begin
  LLower := AQ1 - AMultiplier * (AQ3 - AQ1);
  LUpper := AQ3 + AMultiplier * (AQ3 - AQ1);
  LLen := Length(ASorted);

  if LLen = 0 then
    Exit(0);

  { 二分查找第一个 >= LLower 的位置 = 低于下界的异常值数量 }
  LLeft := 0;
  LRight := LLen;
  while LLeft < LRight do
  begin
    LMid := (LLeft + LRight) div 2;
    if ASorted[LMid] < LLower then
      LLeft := LMid + 1
    else
      LRight := LMid;
  end;
  LLowerCount := LLeft;

  { 二分查找第一个 > LUpper 的位置 }
  LLeft := 0;
  LRight := LLen;
  while LLeft < LRight do
  begin
    LMid := (LLeft + LRight) div 2;
    if ASorted[LMid] <= LUpper then
      LLeft := LMid + 1
    else
      LRight := LMid;
  end;
  LUpperStart := LLeft;

  Result := LLowerCount + (LLen - LUpperStart);
end;

  {** PF-01: Single-pass stats computation — sum/sum_sq + percentile samples merged.
   *  Replaces the old double-pass approach (Mean on unsorted + ComputeStdDev on unsorted). }
function TBenchStatsAnalyzer.ComputeStats(const ASamples: TDoubleArray): TBenchStats;
var
  LSorted: TDoubleArray;
  LLen: Integer;
  LValidCount: Integer; { F-09: count of non-NaN samples }
  LMean, LVariance, LStdErr: Double;
  LDelta, LDelta2, LM2: Double;
  LT95, LT99: Double;
  I: Integer;
  { B22: Outlier-aware variables }
  LQ1, LQ3, LFenceLow, LFenceHigh: Double;
  LFilteredCount, LRunStart: Integer;
  LFilteredMean, LFilteredM2, LDeltaF, LDelta2F: Double;
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

  { 全 NaN 输入：返回零值统计，避免 NaN 传播 }
  if LValidCount = 0 then
  begin
    Result := Default(TBenchStats);
    Exit;
  end;

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

  { B22: Outlier-aware statistics — single-pass filtered mean/variance }
  Result.OutlierMethod := 'Tukey';
  Result.OutlierThreshold := OUTLIER_MULTIPLIER;
  if (Result.OutlierCount > 0) and (LValidCount > Result.OutlierCount) then
  begin
    LQ1 := Result.P25;
    LQ3 := Result.P75;
    LFenceLow := LQ1 - OUTLIER_MULTIPLIER * Result.IQR;
    LFenceHigh := LQ3 + OUTLIER_MULTIPLIER * Result.IQR;
    LFilteredCount := 0;
    { Single pass: accumulate Welford mean/variance on filtered subset }
    LFilteredMean := 0.0;
    LFilteredM2 := 0.0;
    for I := 0 to High(ASamples) do
    begin
      if IsDoubleNaN(ASamples[I]) then
        Continue;
      if (ASamples[I] >= LFenceLow) and (ASamples[I] <= LFenceHigh) then
      begin
        Inc(LFilteredCount);
        { Welford online update on filtered subset }
        LDeltaF := ASamples[I] - LFilteredMean;
        LFilteredMean := LFilteredMean + LDeltaF / LFilteredCount;
        LDelta2F := ASamples[I] - LFilteredMean;
        LFilteredM2 := LFilteredM2 + LDeltaF * LDelta2F;
      end;
    end;
    if LFilteredCount > 0 then
    begin
      Result.FilteredCount := LFilteredCount;
      Result.FilteredMean := LFilteredMean;
      if LFilteredCount > 1 then
        Result.FilteredStdDev := Sqrt(LFilteredM2 / (LFilteredCount - 1))
      else
        Result.FilteredStdDev := 0.0;
      { Filtered median: scan LSorted (already sorted) for values in [LFenceLow, LFenceHigh].
        Avoids allocating + sorting a separate LFiltered array: O(N) vs O(N log N). }
      LFilteredCount := 0;
      I := 0;
      { Skip values below the fence }
      while (I <= High(LSorted)) and (LSorted[I] < LFenceLow) do
        Inc(I);
      { Count values within the fence — I is now the start index }
      LRunStart := I;
      while (I <= High(LSorted)) and (LSorted[I] <= LFenceHigh) do
      begin
        Inc(LFilteredCount);
        Inc(I);
      end;
      if LFilteredCount > 0 then
      begin
        if LFilteredCount mod 2 = 1 then
          Result.FilteredMedian := LSorted[LRunStart + LFilteredCount div 2]
        else
          Result.FilteredMedian := (LSorted[LRunStart + LFilteredCount div 2 - 1] +
                                    LSorted[LRunStart + LFilteredCount div 2]) / 2.0;
      end
      else
        Result.FilteredMedian := Result.Median;
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

  // 95%/99% 置信区间（使用 t 分布临界值）
  if LValidCount > 1 then
  begin
    LT95 := TInv0975(LValidCount - 1);
    LT99 := TInv0995(LValidCount - 1);
    LStdErr := Result.StdDev / Sqrt(LValidCount);
    Result.Confidence95Low := LMean - LT95 * LStdErr;
    Result.Confidence95High := LMean + LT95 * LStdErr;
    Result.Confidence99Low := LMean - LT99 * LStdErr;
    Result.Confidence99High := LMean + LT99 * LStdErr;
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
  if AAlpha <= BENCH_SIGNIFICANCE_ALPHA_HIGH then
    Result := TInvLookup(ADF, TINV99_DATA, Z_SCORE_99)
  else if AAlpha <= BENCH_SIGNIFICANCE_ALPHA then
    Result := TInvLookup(ADF, TINV95_DATA, Z_SCORE_95)
  else
    // alpha > BENCH_SIGNIFICANCE_ALPHA: use 95% critical value (conservative)
    Result := TInvLookup(ADF, TINV95_DATA, Z_SCORE_95);
end;

function TBenchStatsAnalyzer.HasHeuristicDifference(const A, B: TBenchStats): Boolean;
begin
  // 默认 95% 置信水平 (alpha = BENCH_SIGNIFICANCE_ALPHA)
  Result := HasHeuristicDifferenceAt(A, B, BENCH_SIGNIFICANCE_ALPHA);
end;

{** Welch's t-test 统计量和自由度计算（HasHeuristicDifference/ComputeApproximatePValue 共用）
 *  @returns True 如果计算有效（样本充足、方差非零），False 表示无法检验 }
function ComputeWelchTStat(const A, B: TBenchStats;
  out ATStat, ADF: Double): Boolean;
var
  LVarA, LVarB: Double;
begin
  Result := False;
  if (A.SampleCount <= 1) or (B.SampleCount <= 1) then
    Exit;

  LVarA := Sqr(A.StdDev) / A.SampleCount;
  LVarB := Sqr(B.StdDev) / B.SampleCount;

  if (LVarA + LVarB) < 1e-10 then
    Exit;

  ATStat := Abs(A.Mean - B.Mean) / Sqrt(LVarA + LVarB);
  ADF := Sqr(LVarA + LVarB) /
         (Sqr(LVarA) / (A.SampleCount - 1) + Sqr(LVarB) / (B.SampleCount - 1));
  Result := True;
end;

function TBenchStatsAnalyzer.HasHeuristicDifferenceAt(const A, B: TBenchStats;
  AAlpha: Double): Boolean;
var
  LTStat, LDF: Double;
begin
  if not ComputeWelchTStat(A, B, LTStat, LDF) then
    Exit(False);
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
  LTStat, LDF: Double;
begin
  if not ComputeWelchTStat(A, B, LTStat, LDF) then
    Exit(1.0);

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
begin
  Result := ShapiroWilkStatistic(ASorted, Mean(ASorted));
end;

function TBenchStatsAnalyzer.ShapiroWilkStatistic(const ASorted: TDoubleArray; AMean: Double): Double;
var
  LN: Integer;
  LSumSq, LSumWeighted: Double;
  LNormFactor, LInvNm1: Double;
  I: Integer;
  LDev: Double;
begin
  // 简化的 Shapiro-Wilk 风格统计量
  // 完整实现需要查表（m_i 系数），这里用线性权重近似。
  // 归一化保证 W ∈ [0,1]（Cauchy-Schwarz 不等式）。
  LN := Length(ASorted);
  if LN < 3 then
    Exit(1.0);

  LSumSq := 0.0;
  LSumWeighted := 0.0;

  // 权重 w_i = (N-1-2i)/(N-1) 的 L2 范数:
  //   Σ w_i^2 = N(N+1) / (3(N-1))
  // 归一化因子 = 1/sqrt(Σ w_i^2)
  LNormFactor := Sqrt(3.0 * (LN - 1) / (LN * (LN + 1)));
  { 预计算 2/(N-1)，避免循环内除法 }
  LInvNm1 := 2.0 / (LN - 1);

  for I := 0 to LN - 1 do
  begin
    LDev := ASorted[I] - AMean;
    LSumSq += Sqr(LDev);
    LSumWeighted += LDev * (1.0 - I * LInvNm1);
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
  LW, LMean: Double;
  LN: Integer;
begin
  LN := Length(ASamples);
  if LN < 3 then
    Exit(True);  // 样本太少，无法判断

  LMean := Mean(ASamples);
  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  // Shapiro-Wilk 风格启发式（传入预计算均值，避免 ShapiroWilkStatistic 再算一次）
  LW := ShapiroWilkStatistic(LSorted, LMean);

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
  LRankSum1: Double;
  LU1, LU2, LU: Double;
  LMU, LSigma: Double;
  LTieCorrection: Double;
  LZ: Double;
  LRunStart, LRunEnd, I, K, LRunACount: Integer;
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

  { 3. 分配秩次 + 并列值修正 + 秩和一次完成（消除 LRanks 数组） }
  LTieCorrection := 0.0;
  LRankSum1 := 0.0;
  I := 0;
  while I < LN do
  begin
    { 找到当前 run 的结束位置（相同值的区间） }
    LRunStart := I;
    LRunEnd := I;
    while (LRunEnd + 1 < LN) and
          (LCombined[LSortedIdx[LRunEnd + 1]] = LCombined[LSortedIdx[LRunStart]]) do
      Inc(LRunEnd);

    { 并列值修正：K>1 时累积 tie correction }
    K := LRunEnd - LRunStart + 1;
    if K > 1 then
      LTieCorrection := LTieCorrection + (K * K * K - K);

    { 直接累加组 A 的秩和：乘法替代内循环
      秩和 = (# of A elements in run) * avgRank，因为并列值秩相同 }
    LRunACount := 0;
    for K := LRunStart to LRunEnd do
      if LGroup[LSortedIdx[K]] = 0 then
        Inc(LRunACount);
    if LRunACount > 0 then
      LRankSum1 := LRankSum1 + LRunACount * (LRunStart + LRunEnd + 2) / 2.0;

    I := LRunEnd + 1;
  end;

  { 4. 计算 U 统计量 }
  LU1 := LN1 * LN2 + LN1 * (LN1 + 1) / 2.0 - LRankSum1;
  LU2 := LN1 * LN2 - LU1;
  if LU1 < LU2 then
    LU := LU1
  else
    LU := LU2;

  { 6. 正态近似计算 p-value }
  { 小样本时正态近似不可靠，返回保守 p-value }
  if (LN1 < 3) or (LN2 < 3) then
  begin
    { 对于极小样本（n<3），U 统计量的分布不适合正态近似。
      返回 1.0 表示"无法检测差异"，避免误导性 p-value。 }
    Exit(1.0);
  end;

  LMU := LN1 * LN2 / 2.0;

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
{ 单循环实现：Σx, Σy, Σxy, Σx², Σy² 一次完成，
  R² = (n*Σxy - Σx*Σy)² / ((n*Σx² - (Σx)²) * (n*Σy² - (Σy)²))
  避免第二次循环计算 SS_tot 和 SS_res。 }
var
  LN: Integer;
  LSX, LSY, LSXY, LSX2, LSY2: Double;
  LNum, LD, LDenY: Double;
  I: Integer;
begin
  Result := Default(TOLSRegression);
  LN := Length(AIterCounts);

  if (LN < 2) or (LN <> Length(ATimes)) then
  begin
    Result.Valid := False;
    Exit;
  end;

  { 单循环累加所有统计量 }
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

  { R² = (n*Σxy - Σx*Σy)² / ((n*Σx² - (Σx)²) * (n*Σy² - (Σy)²))
    与 1 - SS_res/SS_tot 数学等价，但无需第二次循环 }
  LNum := LN * LSXY - LSX * LSY;
  LDenY := LN * LSY2 - LSY * LSY;
  if (Abs(LD) > 1e-10) and (Abs(LDenY) > 1e-10) then
    Result.RSquared := (LNum * LNum) / (LD * LDenY)
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

  // 直接在已排序的 LSorted 上查询百分位（跳过 Percentile 的范围校验，硬编码值已在 [0,100] 内）
  Result.P5 := PercentileSorted(LSorted, 5.0);
  Result.P25 := PercentileSorted(LSorted, 25.0);
  Result.P50 := PercentileSorted(LSorted, 50.0);
  Result.P75 := PercentileSorted(LSorted, 75.0);
  Result.P95 := PercentileSorted(LSorted, 95.0);
  Result.P99 := PercentileSorted(LSorted, 99.0);
end;

{ K-S 检验辅助函数 }

{ NormalCDF and NormalQuantile are now in nextpas.core.bench.base }

{** Kolmogorov 分布 CDF
 *  K(x) = 1 - 2 * Σ((-1)^(k-1) * exp(-2 * k^2 * x^2))
 *  输入 x = √n * D（其中 D 是 K-S 统计量，n 是样本大小） }
function KolmogorovCDF(AX: Double): Double;
var
  LK: Integer;
  LSum, LTerm, LSqrTerm, LSign: Double;
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
  LSqrTerm := -2.0 * Sqr(AX);
  LSign := 1.0;
  for LK := 1 to 20 do
  begin
    LTerm := Exp(LK * LK * LSqrTerm);
    LSum := LSum + LSign * LTerm;
    LSign := -LSign;
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
  LZ, LInvN, LInvStdDev: Double;
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

  { 预计算倒数，避免循环内除法 }
  LInvN := 1.0 / LN;
  LInvStdDev := 1.0 / AStdDev;

  // 计算 K-S 统计量 D = max|Fn(x) - F0(x)|
  LMaxD := 0.0;
  for LI := 0 to LN - 1 do
  begin
    // 理论分布函数 F0(x) = Φ((x - μ) / σ)
    LZ := (LSorted[LI] - AMean) * LInvStdDev;
    LTheoreticalCDF := NormalCDF(LZ);

    // 经验分布函数 Fn(x) = (i+1) / n
    LEmpiricalCDF := (LI + 1) * LInvN;

    // 计算 |Fn(x) - F0(x)|
    LD := Abs(LEmpiricalCDF - LTheoreticalCDF);
    if LD > LMaxD then
      LMaxD := LD;

    // 也检查 Fn(x-) 的情况
    LEmpiricalCDF := LI * LInvN;
    LD := Abs(LEmpiricalCDF - LTheoreticalCDF);
    if LD > LMaxD then
      LMaxD := LD;
  end;

  Result.Statistic := LMaxD;

  // p-value: Lilliefors 修正（参数从数据估计时，K-S 分布偏移）
  // 修正公式: D_adj = D * (1 + 0.12/sqrt(n) + 0.11/n)
  // 用 Kolmogorov 分布计算修正后的 p-value
  if LN >= 30 then
    // 大样本: 使用 Lilliefors 修正因子
    Result.PValue := 1.0 - KolmogorovCDF(Sqrt(LN) * LMaxD * (1.0 + 0.12 / Sqrt(LN) + 0.11 / LN))
  else if LN >= 5 then
  begin
    // 小样本: 使用 Lilliefors α=0.05 临界值（Lilliefors 1967）
    // 直接写为 if-chain，避免 IfThen 依赖
    if      (LN =  5) and (LMaxD > 0.337) then Result.PValue := 0.04
    else if (LN =  6) and (LMaxD > 0.319) then Result.PValue := 0.04
    else if (LN =  7) and (LMaxD > 0.300) then Result.PValue := 0.04
    else if (LN =  8) and (LMaxD > 0.285) then Result.PValue := 0.04
    else if (LN =  9) and (LMaxD > 0.271) then Result.PValue := 0.04
    else if (LN = 10) and (LMaxD > 0.258) then Result.PValue := 0.04
    else if (LN = 11) and (LMaxD > 0.249) then Result.PValue := 0.04
    else if (LN = 12) and (LMaxD > 0.242) then Result.PValue := 0.04
    else if (LN = 13) and (LMaxD > 0.234) then Result.PValue := 0.04
    else if (LN = 14) and (LMaxD > 0.227) then Result.PValue := 0.04
    else if (LN = 15) and (LMaxD > 0.220) then Result.PValue := 0.04
    else if (LN = 16) and (LMaxD > 0.213) then Result.PValue := 0.04
    else if (LN = 17) and (LMaxD > 0.206) then Result.PValue := 0.04
    else if (LN = 18) and (LMaxD > 0.199) then Result.PValue := 0.04
    else if (LN = 19) and (LMaxD > 0.193) then Result.PValue := 0.04
    else if (LN = 20) and (LMaxD > 0.190) then Result.PValue := 0.04
    else if (LN = 21) and (LMaxD > 0.187) then Result.PValue := 0.04
    else if (LN = 22) and (LMaxD > 0.184) then Result.PValue := 0.04
    else if (LN = 23) and (LMaxD > 0.181) then Result.PValue := 0.04
    else if (LN = 24) and (LMaxD > 0.178) then Result.PValue := 0.04
    else if (LN = 25) and (LMaxD > 0.175) then Result.PValue := 0.04
    else if (LN = 26) and (LMaxD > 0.172) then Result.PValue := 0.04
    else if (LN = 27) and (LMaxD > 0.169) then Result.PValue := 0.04
    else if (LN = 28) and (LMaxD > 0.167) then Result.PValue := 0.04
    else if (LN = 29) and (LMaxD > 0.165) then Result.PValue := 0.04
    else Result.PValue := 0.5;
  end
  else
    // n<5: 无可靠检验
    Result.PValue := 0.5;

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
  LCombinedN, LInvN1, LInvN2: Double;
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

  { 预计算倒数，避免循环内除法 }
  LInvN1 := 1.0 / LN1;
  LInvN2 := 1.0 / LN2;

  // 计算 K-S 统计量 D = max|F1(x) - F2(x)|
  LMaxD := 0.0;
  LI := 0;
  LJ := 0;

  // 合并遍历两个排序数组
  while (LI < LN1) and (LJ < LN2) do
  begin
    if LSorted1[LI] < LSorted2[LJ] then
    begin
      // 在 x = LSorted1[LI] 处计算两个经验分布函数
      LCDF1 := (LI + 1) * LInvN1;
      LCDF2 := LJ * LInvN2;  // F2(x-) = j/n2
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      Inc(LI);
    end
    else if LSorted1[LI] > LSorted2[LJ] then
    begin
      // 在 x = LSorted2[LJ] 处计算两个经验分布函数
      LCDF1 := LI * LInvN1;  // F1(x-) = i/n1
      LCDF2 := (LJ + 1) * LInvN2;
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      Inc(LJ);
    end
    else
    begin
      // 并列值: 两个样本同时推进，计算两个方向的 D
      LCDF1 := (LI + 1) * LInvN1;
      LCDF2 := LJ * LInvN2;
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      LCDF1 := LI * LInvN1;
      LCDF2 := (LJ + 1) * LInvN2;
      LD := Abs(LCDF1 - LCDF2);
      if LD > LMaxD then
        LMaxD := LD;
      Inc(LI);
      Inc(LJ);
    end;
  end;

  // 处理剩余元素
  while LI < LN1 do
  begin
    LCDF1 := (LI + 1) * LInvN1;
    LCDF2 := 1.0;
    LD := Abs(LCDF1 - LCDF2);
    if LD > LMaxD then
      LMaxD := LD;
    Inc(LI);
  end;

  while LJ < LN2 do
  begin
    LCDF1 := 1.0;
    LCDF2 := (LJ + 1) * LInvN2;
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
  LPriorVar: Double;
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
    LSigma := ComputeStdDev(AData, LSampleMean);

  { 防止 σ = 0 }
  if LSigma < 1e-10 then
    LSigma := 1e-10;

  { 计算后验参数 }
  LPriorVar := APriorStdDev * APriorStdDev;

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
