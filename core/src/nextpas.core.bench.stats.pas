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

    {** 计算近似 p-value（简化版本） }
    function ComputeApproximatePValue(const A, B: TBenchStats): Double;

    {** 正态性启发式（近似 Shapiro-Wilk） }
    function LooksNormalHeuristic(const ASamples: TDoubleArray): Boolean;

    {** 计算均值 }
    function Mean(const AData: TDoubleArray): Double;

    {** 计算中位数 }
    function Median(var AData: TDoubleArray): Double;

    {** 计算标准差 }
    function StdDev(const AData: TDoubleArray): Double;

    {** 排序数组 }
    procedure Sort(var AData: TDoubleArray);
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

function TBenchStatsAnalyzer.Median(var AData: TDoubleArray): Double;
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
  LSumSq: Double;
  i: Integer;
begin
  if Length(AData) <= 1 then
    Exit(0.0);

  LSumSq := 0.0;
  for i := 0 to High(AData) do
    LSumSq += Sqr(AData[i] - AMean);

  Result := LSumSq / (Length(AData) - 1);  // 样本方差（除以 n-1）
end;

function TBenchStatsAnalyzer.ComputeStdDev(const AData: TDoubleArray; AMean: Double): Double;
begin
  Result := Sqrt(ComputeVariance(AData, AMean));
end;

function TBenchStatsAnalyzer.StdDev(const AData: TDoubleArray): Double;
var
  LLen: Integer;
  LSum, LSumSq, LMean, LVariance: Double;
  I: Integer;
  LVal: Double;
begin
  LLen := Length(AData);
  if LLen <= 1 then
    Exit(0.0);

  // 单次遍历计算均值和方差
  LSum := 0;
  LSumSq := 0;
  for I := 0 to High(AData) do
  begin
    LVal := AData[I];
    LSum += LVal;
    LSumSq += LVal * LVal;
  end;

  LMean := LSum / LLen;
  // 样本方差（除以 n-1）
  LVariance := (LSumSq - LLen * LMean * LMean) / (LLen - 1);

  // 防止浮点误差导致负方差
  if LVariance < 0 then
    LVariance := 0;

  Result := Sqrt(LVariance);
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
const
  TINV_TABLE: array[1..30] of Double = (
    12.706, 4.303, 3.182, 2.776, 2.571,
    2.447, 2.365, 2.306, 2.262, 2.228,
    2.201, 2.179, 2.160, 2.145, 2.131,
    2.120, 2.110, 2.101, 2.093, 2.086,
    2.080, 2.074, 2.069, 2.064, 2.060,
    2.056, 2.052, 2.048, 2.045, 2.042
  );
var
  LDF: Integer;
begin
  if ADF < 1.0 then
    Result := TINV_TABLE[1]
  else if ADF >= 30.0 then
    Result := Z_SCORE_95
  else
  begin
    LDF := Round(ADF);
    if LDF < 1 then
      LDF := 1;
    if LDF > 30 then
      LDF := 30;
    Result := TINV_TABLE[LDF];
  end;
end;

function TBenchStatsAnalyzer.TInv0995(ADF: Double): Double;
const
  TINV99_TABLE: array[1..30] of Double = (
    63.657, 9.925, 5.841, 4.604, 4.032,
    3.707, 3.499, 3.355, 3.250, 3.169,
    3.106, 3.055, 3.012, 2.977, 2.947,
    2.921, 2.898, 2.878, 2.861, 2.845,
    2.831, 2.819, 2.807, 2.797, 2.787,
    2.779, 2.771, 2.763, 2.756, 2.750
  );
var
  LDF: Integer;
begin
  if ADF < 1.0 then
    Result := TINV99_TABLE[1]
  else if ADF >= 30.0 then
    Result := Z_SCORE_99
  else
  begin
    LDF := Round(ADF);
    if LDF < 1 then
      LDF := 1;
    if LDF > 30 then
      LDF := 30;
    Result := TINV99_TABLE[LDF];
  end;
end;

function TBenchStatsAnalyzer.HasHeuristicDifference(const A, B: TBenchStats): Boolean;
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

  // 比较 t 统计量与近似临界值
  Result := LTStat > TInv0975(LDF);
end;

function TBenchStatsAnalyzer.ComputeApproximatePValue(const A, B: TBenchStats): Double;
var
  LTStat: Double;
  LVarA, LVarB: Double;
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

  // 简化的 p-value 计算（近似）
  // 对于大样本，t 分布接近正态分布
  if LTStat < 1.0 then
    Result := 0.5
  else if LTStat < 2.0 then
    Result := 0.1
  else if LTStat < 2.5 then
    Result := 0.05
  else if LTStat < 3.0 then
    Result := 0.01
  else
    Result := 0.001;
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

procedure TBenchStatsAnalyzer.Sort(var AData: TDoubleArray);
begin
  SortDoubleArray(AData);
end;

end.
