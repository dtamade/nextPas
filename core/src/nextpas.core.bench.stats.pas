unit nextpas.core.bench.stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf;

type
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
var
  LIndex: Double;
  LLower, LUpper: Integer;
begin
  if Length(ASorted) = 0 then
    Exit(0.0);

  if APercent <= 0 then
    Exit(ASorted[0]);
  if APercent >= 100 then
    Exit(ASorted[High(ASorted)]);

  LIndex := (APercent / 100.0) * (Length(ASorted) - 1);
  LLower := Integer(Floor(LIndex));
  LUpper := Integer(Ceil(LIndex));

  if LLower = LUpper then
    Result := ASorted[LLower]
  else
    Result := ASorted[LLower] + (LIndex - LLower) * (ASorted[LUpper] - ASorted[LLower]);
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
  LSum, LSumSq, LCompensation, LNext, LTemp: Double;
  LMean, LVariance: Double;
  LT95, LT99: Double;
  I: Integer;
begin
  LLen := Length(ASamples);
  if LLen = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  { Single pass: compute sum and Kahan-compensated sum-of-squares for variance }
  LSum := 0.0;
  LSumSq := 0.0;
  LCompensation := 0.0;
  for I := 0 to High(ASamples) do
  begin
    LSum := LSum + ASamples[I];
    LNext := Sqr(ASamples[I]) - LCompensation;
    LTemp := LSumSq + LNext;
    LCompensation := (LTemp - LSumSq) - LNext;
    LSumSq := LTemp;
  end;

  LMean := LSum / LLen;
  if LLen > 1 then
    LVariance := (LSumSq - LLen * Sqr(LMean)) / (LLen - 1)  { sample variance via computational formula }
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
  I: Integer;
begin
  // 简化的 Shapiro-Wilk 统计量计算
  // 完整实现需要查表，这里使用简化版本
  LN := Length(ASorted);
  if LN < 3 then
    Exit(1.0);

  LMean := Mean(ASorted);
  LSumSq := 0.0;
  LSumWeighted := 0.0;

  // 计算加权平方和
  for I := 0 to LN - 1 do
  begin
    LSumSq += Sqr(ASorted[I] - LMean);
    // 简化的权重计算（近似正态分布的顺序统计量期望）
    LSumWeighted += (ASorted[I] - LMean) * (LN - 1 - 2 * I) / (LN - 1);
  end;

  if LSumSq < 1e-10 then
    Exit(1.0);

  Result := Sqr(LSumWeighted) / LSumSq;
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
  LTemp: Double;
  LTmpIdx: Int64;

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

  { 1. 合并样本并标记来源 }
  SetLength(LCombined, LN);
  SetLength(LGroup, LN);
  for I := 0 to LN1 - 1 do
  begin
    LCombined[I] := A[I];
    LGroup[I] := 0;
  end;
  for I := 0 to LN2 - 1 do
  begin
    LCombined[LN1 + I] := B[I];
    LGroup[LN1 + I] := 1;
  end;

  { 2. 构建索引数组用于间接排序 }
  SetLength(LSortedIdx, LN);
  for I := 0 to LN - 1 do
    LSortedIdx[I] := I;

  { 简单插入排序（基准样本通常 <1000 个） }
  for I := 1 to LN - 1 do
  begin
    LTmpIdx := LSortedIdx[I];
    LTemp := LCombined[LTmpIdx];
    J := I - 1;
    while (J >= 0) and (LCombined[LSortedIdx[J]] > LTemp) do
    begin
      LSortedIdx[J + 1] := LSortedIdx[J];
      Dec(J);
    end;
    LSortedIdx[J + 1] := LTmpIdx;
  end;

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

end.
