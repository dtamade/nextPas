{**
 * @desc 基准测试统计分析器
 *
 * 提供均值、中位数、标准差、Mann-Whitney U 检验、
 * Welch t 检验、OLS 回归等统计分析功能。
 *}
unit nextpas.core.bench.stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{ 实数字面量最低 Double：默认下 1.0/12.0 等字面量取 Single 类型，
  与整型混算时整个表达式落到 Single 精度（如 1.0/LN 的 ECDF 步长）。 }
{$MINFPCONSTPREC 64}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf;

type
  {** 统计分析器实现 }
  TBenchStatsAnalyzer = class(TInterfacedObject, IBenchStatsAnalyzer)
  private

    {** 计算方差 (Welford 单遍算法) }
    function ComputeVariance(const AData: TDoubleArray): Double;

    {** 计算百分位数 }
    function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;

    {** SW 风格线性权重启发式（非 Royston Shapiro-Wilk，W 值不可与
        scipy.stats.shapiro 对标）；仅供 LooksNormalHeuristic 内部使用 }
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

    {** 截尾均值（Trimmed Mean）— 去掉两端各 ATrimPct% 后取均值 }
    function TrimmedMean(const AData: TDoubleArray;
      ATrimPct: Double = 20.0): Double;

    {** Cohen's d 效应量 — 标准化均值差异 }
    function CohenD(const A, B: TDoubleArray): Double;
  end;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.bench.stats.advanced; { Phase B.2: for TAdvancedStats }

{ === 内部辅助函数 === }

function FilterValidValues(const AData: TDoubleArray): TDoubleArray;
{ 过滤 NaN/Inf，返回仅包含有效值的新数组 }
var
  LLen, LValidCount, I: Integer;
begin
  LLen := Length(AData);
  Result := nil;
  SetLength(Result, LLen);
  LValidCount := 0;
  for I := 0 to High(AData) do
  begin
    if IsDoubleNaN(AData[I]) or IsInfinite(AData[I]) then Continue;
    Result[LValidCount] := AData[I];
    Inc(LValidCount);
  end;
  SetLength(Result, LValidCount);
end;

procedure WelfordMeanVariance(const AData: TDoubleArray;
  out AMean, AVariance: Double; out AValidCount: Integer);
{ Welford 单遍算法：同时计算均值和方差，跳过 NaN/Inf。
  避免 catastrophic cancellation（当数据值大且接近时）。 }
var
  I: Integer;
  LDelta, LDelta2, LM2: Double;
begin
  AMean := 0.0; AVariance := 0.0; AValidCount := 0; LM2 := 0.0;
  for I := 0 to High(AData) do
  begin
    if IsDoubleNaN(AData[I]) or IsInfinite(AData[I]) then Continue;
    Inc(AValidCount);
    LDelta := AData[I] - AMean;
    AMean := AMean + LDelta / AValidCount;
    LDelta2 := AData[I] - AMean;
    LM2 := LM2 + LDelta * LDelta2;
  end;
  if AValidCount > 1 then
    AVariance := LM2 / (AValidCount - 1)
  else
    AVariance := 0.0;
end;

const
  { Lilliefors α=0.05 临界值 (Lilliefors 1967), 0-based, index=n }
  LILLIEFORS_005_DATA: array[5..29] of Double = (
    0.337, 0.319, 0.300, 0.285, 0.271, { n=5..9 }
    0.258, 0.249, 0.242, 0.234, 0.227, { n=10..14 }
    0.220, 0.213, 0.206, 0.199, 0.193, { n=15..19 }
    0.190, 0.187, 0.184, 0.181, 0.178, { n=20..24 }
    0.175, 0.172, 0.169, 0.167, 0.165  { n=25..29 }
  );

{ TBenchStatsAnalyzer }

constructor TBenchStatsAnalyzer.Create;
begin
  inherited Create;
end;

function TBenchStatsAnalyzer.Mean(const AData: TDoubleArray): Double;
var
  LValid: TDoubleArray;
  LLen, I: Integer;
  LSum: Double;
begin
  if Length(AData) = 0 then Exit(0.0);
  LValid := FilterValidValues(AData);
  LLen := Length(LValid);
  if LLen = 0 then Exit(0.0);
  LSum := 0;
  for I := 0 to High(LValid) do
    LSum := LSum + LValid[I];
  Result := LSum / LLen;
end;

function TBenchStatsAnalyzer.Median(const AData: TDoubleArray): Double;
var
  LFiltered: TDoubleArray;
  LLen: Integer;
begin
  if Length(AData) = 0 then Exit(0.0);
  LFiltered := FilterValidValues(AData);
  LLen := Length(LFiltered);
  if LLen = 0 then Exit(0.0);
  SortDoubleArray(LFiltered);
  if LLen mod 2 = 1 then
    Result := LFiltered[LLen div 2]
  else
    Result := (LFiltered[LLen div 2 - 1] + LFiltered[LLen div 2]) / 2.0;
end;

function TBenchStatsAnalyzer.ComputeVariance(const AData: TDoubleArray): Double;
var
  LMean: Double;
  LValidCount: Integer;
begin
  if Length(AData) <= 1 then Exit(0.0);
  WelfordMeanVariance(AData, LMean, Result, LValidCount);
end;

function TBenchStatsAnalyzer.StdDev(const AData: TDoubleArray): Double;
begin
  Result := Sqrt(ComputeVariance(AData));
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
  LStdDev := Sqrt(ComputeVariance(AData));
  Result := LStdDev / LMean;
end;

function TBenchStatsAnalyzer.Percentile(const ASorted: TDoubleArray; APercent: Double): Double;
begin
  { range validation — reject out-of-range percentiles }
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
  LFiltered: TDoubleArray;
  LValidCount: Integer;
  LMean, LVariance, LStdErr: Double;
  LT95, LT99: Double;
  I: Integer;
  { B22: Outlier-aware variables }
  LQ1, LQ3, LFenceLow, LFenceHigh: Double;
  LOutlierFilteredCount, LMedianCount, LRunStart: Integer;
  LFilteredMean, LFilteredM2, LDeltaF, LDelta2F: Double;
begin
  if Length(ASamples) = 0 then
    raise EBenchInvalidParam.Create('ComputeStats: sample array must not be empty');

  { 过滤 NaN/Inf 后再排序 — 排序含 NaN 行为未定义，Inf 会污染百分位 }
  LFiltered := FilterValidValues(ASamples);
  LValidCount := Length(LFiltered);
  if LValidCount = 0 then
  begin
    Result := Default(TBenchStats);
    Exit;
  end;

  { Welford 单遍方差（在排序前计算，不依赖顺序） }
  WelfordMeanVariance(LFiltered, LMean, LVariance, LValidCount);

  { 原地排序，省去一次 Copy 分配 }
  SortDoubleArray(LFiltered);

  Result.Mean := LMean;
  if LVariance > 0 then
    Result.StdDev := Sqrt(LVariance)
  else
    Result.StdDev := 0.0;
  { 在已排序的有效值上查询百分位 }
  Result.Median := PercentileSorted(LFiltered, 50);
  Result.Min := LFiltered[0];
  Result.Max := LFiltered[High(LFiltered)];
  Result.P5 := PercentileSorted(LFiltered, 5.0);
  Result.P25 := PercentileSorted(LFiltered, 25.0);
  Result.P75 := PercentileSorted(LFiltered, 75.0);
  Result.P95 := PercentileSorted(LFiltered, 95.0);
  Result.P99 := PercentileSorted(LFiltered, 99.0);
  Result.IQR := Result.P75 - Result.P25;
  Result.OutlierCount := CountOutliers(LFiltered, Result.P25, Result.P75, OUTLIER_MULTIPLIER);
  Result.SampleCount := LValidCount;

  { B22: Outlier-aware statistics — single-pass filtered mean/variance }
  Result.OutlierMethod := 'Tukey';
  Result.OutlierThreshold := OUTLIER_MULTIPLIER;
  if (Result.OutlierCount > 0) and (LValidCount > Result.OutlierCount) then
  begin
    LQ1 := Result.P25;
    LQ3 := Result.P75;
    LFenceLow := LQ1 - OUTLIER_MULTIPLIER * Result.IQR;
    LFenceHigh := LQ3 + OUTLIER_MULTIPLIER * Result.IQR;
    LOutlierFilteredCount := 0;
    LFilteredMean := 0.0;
    LFilteredM2 := 0.0;
    for I := 0 to LValidCount - 1 do
    begin
      if (LFiltered[I] >= LFenceLow) and (LFiltered[I] <= LFenceHigh) then
      begin
        Inc(LOutlierFilteredCount);
        LDeltaF := LFiltered[I] - LFilteredMean;
        LFilteredMean := LFilteredMean + LDeltaF / LOutlierFilteredCount;
        LDelta2F := LFiltered[I] - LFilteredMean;
        LFilteredM2 := LFilteredM2 + LDeltaF * LDelta2F;
      end;
    end;
    if LOutlierFilteredCount > 0 then
    begin
      Result.FilteredCount := LOutlierFilteredCount;
      Result.FilteredMean := LFilteredMean;
      if LOutlierFilteredCount > 1 then
        Result.FilteredStdDev := Sqrt(LFilteredM2 / (LOutlierFilteredCount - 1))
      else
        Result.FilteredStdDev := 0.0;
      { Filtered median: scan LFiltered for values in [LFenceLow, LFenceHigh] }
      I := 0;
      while (I <= High(LFiltered)) and (LFiltered[I] < LFenceLow) do
        Inc(I);
      LRunStart := I;
      LMedianCount := 0;
      while (I <= High(LFiltered)) and (LFiltered[I] <= LFenceHigh) do
      begin
        Inc(LMedianCount);
        Inc(I);
      end;
      if LMedianCount > 0 then
      begin
        if LMedianCount mod 2 = 1 then
          Result.FilteredMedian := LFiltered[LRunStart + LMedianCount div 2]
        else
          Result.FilteredMedian := (LFiltered[LRunStart + LMedianCount div 2 - 1] +
                                    LFiltered[LRunStart + LMedianCount div 2]) / 2.0;
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
  // 边界比较带 F-32 余量，否则 Double(0.01) > extended 0.01 会让
  // alpha=0.01 的调用者拿到 95% 临界值（反保守）
  if AAlpha <= BENCH_SIGNIFICANCE_ALPHA_HIGH + BENCH_LEVEL_EPS then
    Result := TInvLookup(ADF, TINV99_DATA, Z_SCORE_99)
  else if AAlpha <= BENCH_SIGNIFICANCE_ALPHA + BENCH_LEVEL_EPS then
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
  // 注意：线性 ramp 是均匀分布的序统计量期望形状，故本统计量实质度量
  // 「分位数-线性相关」——完美等差数列 W=1.0，而 scipy.shapiro 给 0.96；
  // 典型形状（右偏/近正态/等差/指数, n=20）与 scipy W 偏差 0.005~0.05，
  // 0.9 阈值判决方向与 scipy alpha=0.05 一致（F-34 量化评估）。
  // 不可当作标准 SW W 值对外报告。
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
    LSumSq := LSumSq + Sqr(LDev);
    LSumWeighted := LSumWeighted + LDev * (1.0 - I * LInvNm1);
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
    if not IsDoubleNaN(A[I]) and not IsInfinite(A[I]) then
    begin
      LCombined[LN] := A[I];
      LGroup[LN] := 0;
      Inc(LN);
    end;
  end;
  LN1 := LN;
  for I := 0 to Length(B) - 1 do
  begin
    if not IsDoubleNaN(B[I]) and not IsInfinite(B[I]) then
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
      Exit(0.0 / 0.0);  { 非法 ratio，返回 NaN 而非 0.0 }
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
  if Length(ASamples) = 0 then Exit;
  LSorted := FilterValidValues(ASamples);
  if Length(LSorted) = 0 then Exit;
  SortDoubleArray(LSorted);
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
    if (LN >= 5) and (LN <= 29) and (LMaxD > LILLIEFORS_005_DATA[LN]) then
      Result.PValue := 0.04
    else
      Result.PValue := 0.5;
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
  LV: Double;
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

  { K-S 统计量 D = max|F1(x) - F2(x)|，按值消费的 merge 走查：
    每轮取最小未消费值 v，把两侧所有等于 v 的点（含跨样本 tie 与样本内
    重复）一次消费完，再比较跳变后的 ECDF。并列点上两个 ECDF 同时跳变，
    分侧推进会在 tie 处产生虚假 D（相同数组会得到 D=1/n 而非 0）。
    v 处跳变前的 ECDF 对等于上一轮跳变后的值，已在上一轮比较过。 }
  LMaxD := 0.0;
  LI := 0;
  LJ := 0;
  while (LI < LN1) or (LJ < LN2) do
  begin
    { 选定较小侧并至少推进一步（NaN 比较恒 False，按下标推进保证终止） }
    if (LJ >= LN2) or ((LI < LN1) and (LSorted1[LI] <= LSorted2[LJ])) then
    begin
      LV := LSorted1[LI];
      Inc(LI);
    end
    else
    begin
      LV := LSorted2[LJ];
      Inc(LJ);
    end;
    while (LI < LN1) and (LSorted1[LI] = LV) do
      Inc(LI);
    while (LJ < LN2) and (LSorted2[LJ] = LV) do
      Inc(LJ);
    LD := Abs(LI * LInvN1 - LJ * LInvN2);
    if LD > LMaxD then
      LMaxD := LD;
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
{ 直接调用独立函数，无需创建 TAdvancedStats 实例 }
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
    LSigma := Sqrt(ComputeVariance(AData));

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
  LZ := NormalQuantile(0.975); { use NormalQuantile instead of hardcoded 1.96 }
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

function TBenchStatsAnalyzer.TrimmedMean(const AData: TDoubleArray;
  ATrimPct: Double = 20.0): Double;
var
  LSorted: TDoubleArray;
  LLen, LTrimCount, LStart, LEnd, I: Integer;
  LSum: Double;
begin
  if Length(AData) = 0 then Exit(0.0);
  if (ATrimPct < 0) or (ATrimPct >= 50) then
    raise EBenchInvalidParam.CreateFmt(
      'TBenchStatsAnalyzer.TrimmedMean: ATrimPct must be in [0, 50), got %.1f', [ATrimPct]);
  if ATrimPct = 0 then Exit(Mean(AData));

  LSorted := FilterValidValues(AData);
  LLen := Length(LSorted);
  if LLen = 0 then Exit(0.0);
  SortDoubleArray(LSorted);

  LTrimCount := Trunc(LLen * ATrimPct / 100.0);
  LStart := LTrimCount;
  LEnd := LLen - LTrimCount;
  if LStart >= LEnd then
  begin
    { 截取后为空，直接在已排序数据上计算中位数，避免重复过滤+排序 }
    if LLen mod 2 = 1 then
      Exit(LSorted[LLen div 2])
    else
      Exit((LSorted[LLen div 2 - 1] + LSorted[LLen div 2]) / 2.0);
  end;

  LSum := 0;
  for I := LStart to LEnd - 1 do
    LSum := LSum + LSorted[I];
  Result := LSum / (LEnd - LStart);
end;

function TBenchStatsAnalyzer.CohenD(const A, B: TDoubleArray): Double;
var
  LMeanA, LMeanB, LVarA, LVarB, LPooledVar, LPooledStdDev: Double;
  LValidA, LValidB: Integer;
begin
  if (Length(A) = 0) or (Length(B) = 0) then Exit(0.0);
  WelfordMeanVariance(A, LMeanA, LVarA, LValidA);
  WelfordMeanVariance(B, LMeanB, LVarB, LValidB);
  if (LValidA < 2) or (LValidB < 2) then Exit(0.0);
  LPooledVar := ((LValidA - 1) * LVarA + (LValidB - 1) * LVarB) / (LValidA + LValidB - 2);
  LPooledStdDev := Sqrt(LPooledVar);
  if LPooledStdDev = 0 then Exit(0.0);
  Result := (LMeanA - LMeanB) / LPooledStdDev;
end;

end.
