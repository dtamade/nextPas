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

    {** 计算四分位距 }
    function ComputeIQR(const ASorted: TDoubleArray): Double;

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
  i: Integer;
begin
  LSum := 0.0;
  LCompensation := 0.0;

  for i := 0 to High(AData) do
  begin
    LNext := AData[i] - LCompensation;
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
  i: Integer;
begin
  if Length(AData) <= 1 then
    Exit(0.0);

  // Kahan compensated summation for Sqr(x - mean)
  LSumSq := 0.0;
  LCompensation := 0.0;
  for i := 0 to High(AData) do
  begin
    LNext := Sqr(AData[i] - AMean) - LCompensation;
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

function TBenchStatsAnalyzer.ComputeIQR(const ASorted: TDoubleArray): Double;
begin
  Result := Percentile(ASorted, 75) - Percentile(ASorted, 25);
end;

function TBenchStatsAnalyzer.CountOutliers(const ASorted: TDoubleArray;
  AQ1, AQ3, AMultiplier: Double): Integer;
var
  LLower, LUpper: Double;
  i: Integer;
begin
  LLower := AQ1 - AMultiplier * (AQ3 - AQ1);
  LUpper := AQ3 + AMultiplier * (AQ3 - AQ1);

  Result := 0;
  for i := 0 to High(ASorted) do
  begin
    if (ASorted[i] < LLower) or (ASorted[i] > LUpper) then
      Inc(Result);
  end;
end;

function TBenchStatsAnalyzer.ComputeStats(const ASamples: TDoubleArray): TBenchStats;
var
  LSorted: TDoubleArray;
  LMean: Double;
  LT95, LT99: Double;
begin
  if Length(ASamples) = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  LMean := Mean(ASamples);

  Result.Mean := LMean;
  Result.StdDev := ComputeStdDev(ASamples, LMean);
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
  Result.SampleCount := Length(ASamples);

  // 95% 置信区间（使用 t 分布临界值）
  if Length(ASamples) > 1 then
  begin
    LT95 := TInv0975(Length(ASamples) - 1);
    LT99 := TInv0995(Length(ASamples) - 1);
    Result.Confidence95Low := LMean - LT95 * Result.StdDev / Sqrt(Length(ASamples));
    Result.Confidence95High := LMean + LT95 * Result.StdDev / Sqrt(Length(ASamples));
    Result.Confidence99Low := LMean - LT99 * Result.StdDev / Sqrt(Length(ASamples));
    Result.Confidence99High := LMean + LT99 * Result.StdDev / Sqrt(Length(ASamples));
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
  i: Integer;
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
  for i := 0 to LN - 1 do
  begin
    LSumSq += Sqr(ASorted[i] - LMean);
    // 简化的权重计算（近似正态分布的顺序统计量期望）
    LSumWeighted += (ASorted[i] - LMean) * (LN - 1 - 2 * i) / (LN - 1);
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

end.
