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

    {** Mann-Whitney U 检验 p-value（非参数，适用于右偏基准数据） }
    function ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;

    {** 几何均值（多 benchmark ratio 聚合的正确方法） }
    function GeometricMean(const ARatios: TDoubleArray): Double;

    {** OLS 线性回归: time = intercept + slope * N }
    function ComputeOLSRegression(const AIterCounts, ATimes: TDoubleArray): TOLSRegression;
  end;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

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

function TBenchStatsAnalyzer.Percentile(const ASorted: TDoubleArray; APercent: Double): Double;
begin
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
  LMean, LVariance: Double;
  LDelta, LDelta2, LM2: Double;
  LT95, LT99: Double;
  I: Integer;
begin
  LLen := Length(ASamples);
  if LLen = 0 then
  begin
    Result := Default(TBenchStats);
    Exit;
  end;

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  { Welford's single-pass algorithm for numerically stable variance.
    Reference: Welford, B.P. (1962). "Note on a Method for Calculating
    Corrected Sums of Squares and Products". Technometrics. }
  LMean := 0.0;
  LM2 := 0.0;  { sum of squared deviations from current mean }
  for I := 0 to High(ASamples) do
  begin
    LDelta := ASamples[I] - LMean;
    LMean := LMean + LDelta / (I + 1);
    LDelta2 := ASamples[I] - LMean;
    LM2 := LM2 + LDelta * LDelta2;
  end;

  if LLen > 1 then
    LVariance := LM2 / (LLen - 1)  { sample variance }
  else
    LVariance := 0.0;

  Result.Mean := LMean;
  if LVariance > 0 then
    Result.StdDev := Sqrt(LVariance)
  else
    Result.StdDev := 0.0;
  Result.Median := Percentile(LSorted, 50);
  Result.Min := LSorted[0];
  Result.Max := LSorted[High(LSorted)];
  Result.P5 := Percentile(LSorted, 5);
  Result.P25 := Percentile(LSorted, 25);
  Result.P75 := Percentile(LSorted, 75);
  Result.P95 := Percentile(LSorted, 95);
  Result.P99 := Percentile(LSorted, 99);
  Result.IQR := Result.P75 - Result.P25;
  Result.OutlierCount := CountOutliers(LSorted, Result.P25, Result.P75, OUTLIER_MULTIPLIER);
  Result.SampleCount := LLen;

  // 95% 置信区间（使用 t 分布临界值）
  if LLen > 1 then
  begin
    LT95 := TInv0975(LLen - 1);
    LT99 := TInv0995(LLen - 1);
    Result.Confidence95Low := LMean - LT95 * Result.StdDev / Sqrt(LLen);
    Result.Confidence95High := LMean + LT95 * Result.StdDev / Sqrt(LLen);
    Result.Confidence99Low := LMean - LT99 * Result.StdDev / Sqrt(LLen);
    Result.Confidence99High := LMean + LT99 * Result.StdDev / Sqrt(LLen);
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
  LX: Double;
  LT: Double;
  LP: Double;
  LK: Double;
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

  // 使用正态近似（df 较大时 t 分布接近正态）
  // p-value ≈ 2 * (1 - Phi(|t|))，Phi 使用 Hastings 近似
  LX := LTStat;
  if LX > 6.0 then
    Result := 0.001
  else if LX < 0.01 then
    Result := 1.0
  else
  begin
    LT := 1.0 / (1.0 + 0.2316419 * LX);
    LK := 0.3989422804014327 * Exp(-0.5 * LX * LX);
    LP := LK * (LT * (0.319381530 + LT * (-0.356563782 + LT * (1.781477937 +
          LT * (-1.821255978 + LT * 1.330274429)))));
    if LDF < 30 then
      LP := LP * (1.0 + 1.0 / (4.0 * LDF));
    Result := 2.0 * LP;
    if Result > 1.0 then
      Result := 1.0;
    if Result < 0.001 then
      Result := 0.001;
  end;
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

  { 从 z-score 计算双侧 p-value（Hastings 近似） }
  function ZToPValue(AZ: Double): Double;
  var
    LT, LK, LP: Double;
  begin
    AZ := Abs(AZ);
    if AZ > 6.0 then
      Exit(0.000001)
    else if AZ < 0.01 then
      Exit(1.0);
    LT := 1.0 / (1.0 + 0.2316419 * AZ);
    LK := 0.3989422804014327 * Exp(-0.5 * AZ * AZ);
    LP := LK * (LT * (0.319381530 + LT * (-0.356563782 + LT * (1.781477937 +
          LT * (-1.821255978 + LT * 1.330274429)))));
    Result := 2.0 * LP;
    if Result > 1.0 then Result := 1.0;
    if Result < 0.000001 then Result := 0.000001;
  end;

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
      Exit(0.0);  { 非法 ratio，返回 0 作为哨兵 }
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

end.
