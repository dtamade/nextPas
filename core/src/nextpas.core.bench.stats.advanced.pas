{**
 * @desc 高级统计分析器
 *
 * 提供高级统计分析功能，
 * 包括异常值检测、正态性检验、置信区间等。
 *}
unit nextpas.core.bench.stats.advanced;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base;

type
  {**
   * 置信区间
   *}
  TConfidenceInterval = record
    Lower: Double;
    Upper: Double;
    Level: Double; // e.g., 0.95 for 95%
  end;

  {**
   * 正态性检验结果
   *}
  TNormalityTest = record
    IsNormal: Boolean;
    ApproximatePValue: Double;
    TestStatistic: Double;
    Method: string; // e.g., 'Shapiro-Wilk-like heuristic'
  end;

  {**
   * 异常值检测方法
   *}
  TOutlierMethod = (omTukey, omZScore, omModifiedZScore);

  {**
   * 异常值检测结果
   *}
  TOutlierDetection = record
    Outliers: TDoubleArray;
    OutlierIndices: TInt64Array;
    Method: TOutlierMethod;
    Threshold: Double;
  end;

  {**
   * 高级统计分析器
   *}
  TAdvancedStats = record
  private
    FData: TDoubleArray;
    FSortedData: TDoubleArray;
    FSorted: Boolean;
    FCachedMean: Double;
    FMeanCached: Boolean;
    procedure EnsureSorted;
  public
    {**
     * 创建统计分析器
     *}
    class function Create(const AData: TDoubleArray): TAdvancedStats; static;

    {**
     * 计算均值
     *}
    function Mean: Double;

    {**
     * 计算中位数
     *}
    function Median: Double;

    {**
     * 计算标准差
     *}
    function StdDev: Double;

    {**
     * 计算方差
     *}
    function Variance: Double;

    {**
     * 计算偏度
     *}
    function Skewness: Double;

    {**
     * 计算峰度
     *}
    function Kurtosis: Double;

    {**
     * 计算百分位数
     *}
    function Percentile(APercentile: Double): Double;

    {**
     * 计算四分位距
     *}
    function IQR: Double;

    {**
     * 检测异常值 (Tukey's Fences)
     *}
    function DetectOutliers_Tukey(AFenceFactor: Double = 1.5): TOutlierDetection;

    {**
     * 检测异常值 (Z-Score)
     *}
    function DetectOutliers_ZScore(AThreshold: Double = 3.0): TOutlierDetection;

    {**
     * 检测异常值 (Modified Z-Score)
     *}
    function DetectOutliers_ModifiedZScore(AThreshold: Double = 3.5): TOutlierDetection;

    {**
     * 计算置信区间
     *}
    function ConfidenceInterval(ALevel: Double = 0.95): TConfidenceInterval;

    {**
     * Bootstrap confidence interval
     *}
    function BootstrapCI(AIterations: Integer = 10000;
      ALevel: Double = 0.95): TConfidenceInterval;

    {**
     * 正态性启发式 (Shapiro-Wilk-like 简化版)
     *}
    function TestNormalityByMoments: TNormalityTest;

    {**
     * 比较两个数据集 (Welch's t-style heuristic)
     *}
    function ApproximateWelchTScore(const AOther: TDoubleArray): Double;

    {**
     * 计算效应大小 (Cohen's d)
     *}
    function EffectSize(const AOther: TDoubleArray): Double;

    {**
     * 获取数据
     *}
    function GetData: TDoubleArray;

    {**
     * 获取数据点数量
     *}
    function Count: Integer;
  end;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

const
  TINV90_DATA: array[0..29] of Double = (
    6.314, 2.920, 2.353, 2.132, 2.015,
    1.943, 1.895, 1.860, 1.833, 1.812,
    1.796, 1.782, 1.771, 1.761, 1.753,
    1.746, 1.740, 1.734, 1.729, 1.725,
    1.721, 1.717, 1.714, 1.711, 1.708,
    1.706, 1.703, 1.701, 1.699, 1.697
  );

{ TAdvancedStats }

class function TAdvancedStats.Create(const AData: TDoubleArray): TAdvancedStats;
begin
  Result.FData := Copy(AData);
  Result.FSorted := False;
  Result.FMeanCached := False;
end;

procedure TAdvancedStats.EnsureSorted;
begin
  if FSorted then Exit;

  FSortedData := Copy(FData);
  SortDoubleArray(FSortedData);
  FSorted := True;
end;

function TAdvancedStats.Mean: Double;
var
  I: Integer;
  LSum: Double;
begin
  if FMeanCached then
    Exit(FCachedMean);
  if Length(FData) = 0 then
    Exit(0);

  LSum := 0;
  for I := 0 to High(FData) do
    LSum := LSum + FData[I];
  FCachedMean := LSum / Length(FData);
  FMeanCached := True;
  Result := FCachedMean;
end;

function TAdvancedStats.Median: Double;
var
  LCount: Integer;
begin
  LCount := Length(FData);
  if LCount = 0 then Exit(0);

  EnsureSorted;

  if LCount mod 2 = 0 then
    Result := (FSortedData[LCount div 2 - 1] + FSortedData[LCount div 2]) / 2
  else
    Result := FSortedData[LCount div 2];
end;

function TAdvancedStats.StdDev: Double;
begin
  Result := Sqrt(Variance);
end;

function TAdvancedStats.Variance: Double;
var
  I: Integer;
  LMean: Double;
  LSum: Double;
begin
  if Length(FData) < 2 then Exit(0);

  LMean := Mean;
  LSum := 0;
  for I := 0 to High(FData) do
    LSum := LSum + Sqr(FData[I] - LMean);
  Result := LSum / (Length(FData) - 1);
end;

function TAdvancedStats.Skewness: Double;
var
  I: Integer;
  LMean: Double;
  LStdDev: Double;
  LSum: Double;
  LCount: Integer;
begin
  LCount := Length(FData);
  if LCount < 3 then Exit(0);

  LMean := Mean;
  LStdDev := StdDev;
  if LStdDev = 0 then Exit(0);

  LSum := 0;
  for I := 0 to High(FData) do
    LSum := LSum + Power((FData[I] - LMean) / LStdDev, 3);

  // Fisher's g1: unbiased estimator
  if LCount > 2 then
    Result := (LSum / LCount) * Sqrt(LCount * (LCount - 1)) / (LCount - 2)
  else
    Result := LSum / LCount;
end;

function TAdvancedStats.Kurtosis: Double;
var
  I: Integer;
  LMean: Double;
  LStdDev: Double;
  LSum: Double;
  LCount: Integer;
  LRaw: Double;
begin
  LCount := Length(FData);
  if LCount < 4 then Exit(0);

  LMean := Mean;
  LStdDev := StdDev;
  if LStdDev = 0 then Exit(0);

  LSum := 0;
  for I := 0 to High(FData) do
    LSum := LSum + Power((FData[I] - LMean) / LStdDev, 4);

  LRaw := LSum / LCount;
  // Unbiased excess kurtosis correction
  if (LCount > 3) and (LCount > 2) then
    Result := ((LCount - 1) * ((LCount + 1) * LRaw - 3 * (LCount - 1)) / (LCount - 2) / (LCount - 3))
  else
    Result := LRaw - 3;
end;

function TAdvancedStats.Percentile(APercentile: Double): Double;
var
  LIndex: Double;
  LFloor: Integer;
  LCeil: Integer;
  LCount: Integer;
begin
  LCount := Length(FData);
  if LCount = 0 then Exit(0);

  EnsureSorted;

  LIndex := (APercentile / 100) * (LCount - 1);
  LFloor := Floor(LIndex);
  LCeil := Ceil(LIndex);

  if LFloor = LCeil then
    Result := FSortedData[LFloor]
  else
    Result := FSortedData[LFloor] + (FSortedData[LCeil] - FSortedData[LFloor]) * (LIndex - LFloor);
end;

function TAdvancedStats.IQR: Double;
begin
  Result := Percentile(75) - Percentile(25);
end;

function TAdvancedStats.DetectOutliers_Tukey(AFenceFactor: Double): TOutlierDetection;
var
  LQ1: Double;
  LQ3: Double;
  LIQR: Double;
  LLower: Double;
  LUpper: Double;
  I: Integer;
  LOutlierCount: Integer;
begin
  LQ1 := Percentile(25);
  LQ3 := Percentile(75);
  LIQR := LQ3 - LQ1;
  LLower := LQ1 - AFenceFactor * LIQR;
  LUpper := LQ3 + AFenceFactor * LIQR;

  LOutlierCount := 0;
  SetLength(Result.Outliers, Length(FData));
  SetLength(Result.OutlierIndices, Length(FData));
  Result.Method := omTukey;
  Result.Threshold := AFenceFactor;

  // 使用原始数据检测异常值
  for I := 0 to High(FData) do
  begin
    if (FData[I] < LLower) or (FData[I] > LUpper) then
    begin
      Result.Outliers[LOutlierCount] := FData[I];
      Result.OutlierIndices[LOutlierCount] := I;
      Inc(LOutlierCount);
    end;
  end;
  SetLength(Result.Outliers, LOutlierCount);
  SetLength(Result.OutlierIndices, LOutlierCount);
end;

function TAdvancedStats.DetectOutliers_ZScore(AThreshold: Double): TOutlierDetection;
var
  LMean: Double;
  LStdDev: Double;
  I: Integer;
  LZScore: Double;
  LOutlierCount: Integer;
begin
  LMean := Mean;
  LStdDev := StdDev;

  LOutlierCount := 0;
  SetLength(Result.Outliers, Length(FData));
  SetLength(Result.OutlierIndices, Length(FData));
  Result.Method := omZScore;
  Result.Threshold := AThreshold;

  if LStdDev = 0 then
  begin
    SetLength(Result.Outliers, 0);
    SetLength(Result.OutlierIndices, 0);
    Exit;
  end;

  for I := 0 to High(FData) do
  begin
    LZScore := Abs(FData[I] - LMean) / LStdDev;
    if LZScore > AThreshold then
    begin
      Result.Outliers[LOutlierCount] := FData[I];
      Result.OutlierIndices[LOutlierCount] := I;
      Inc(LOutlierCount);
    end;
  end;
  SetLength(Result.Outliers, LOutlierCount);
  SetLength(Result.OutlierIndices, LOutlierCount);
end;

function TAdvancedStats.DetectOutliers_ModifiedZScore(AThreshold: Double): TOutlierDetection;
var
  LMedian: Double;
  LMAD: Double;
  I: Integer;
  LModifiedZ: Double;
  LOutlierCount: Integer;
  LDeviations: TDoubleArray;
  LTemp: Double;
  J: Integer;
begin
  LMedian := Median;

  // Calculate MAD (Median Absolute Deviation)
  SetLength(LDeviations, Length(FData));
  for I := 0 to High(FData) do
    LDeviations[I] := Abs(FData[I] - LMedian);

  // 使用 QuickSort 排序偏差
  SortDoubleArray(LDeviations);

  if Length(LDeviations) mod 2 = 0 then
    LMAD := (LDeviations[Length(LDeviations) div 2 - 1] +
             LDeviations[Length(LDeviations) div 2]) / 2
  else
    LMAD := LDeviations[Length(LDeviations) div 2];

  LOutlierCount := 0;
  SetLength(Result.Outliers, Length(FData));
  SetLength(Result.OutlierIndices, Length(FData));
  Result.Method := omModifiedZScore;
  Result.Threshold := AThreshold;

  if LMAD = 0 then
  begin
    SetLength(Result.Outliers, 0);
    SetLength(Result.OutlierIndices, 0);
    Exit;
  end;

  for I := 0 to High(FData) do
  begin
    LModifiedZ := 0.6745 * (FData[I] - LMedian) / LMAD;
    if Abs(LModifiedZ) > AThreshold then
    begin
      Result.Outliers[LOutlierCount] := FData[I];
      Result.OutlierIndices[LOutlierCount] := I;
      Inc(LOutlierCount);
    end;
  end;
  SetLength(Result.Outliers, LOutlierCount);
  SetLength(Result.OutlierIndices, LOutlierCount);
end;

function TAdvancedStats.ConfidenceInterval(ALevel: Double): TConfidenceInterval;
var
  LMean: Double;
  LStdDev: Double;
  LCount: Integer;
  LTCritical: Double;
  LMargin: Double;
begin
  LMean := Mean;
  LStdDev := StdDev;
  LCount := Length(FData);

  if LCount <= 1 then
  begin
    Result.Lower := LMean;
    Result.Upper := LMean;
    Result.Level := ALevel;
    Exit;
  end;

  // 使用 t 分布临界值（小样本更准确）
  if ALevel >= 0.99 then
    LTCritical := TInvLookup(LCount - 1, TINV99_DATA, 2.576)
  else if ALevel >= 0.95 then
    LTCritical := TInvLookup(LCount - 1, TINV95_DATA, 1.96)
  else if ALevel >= 0.90 then
    LTCritical := TInvLookup(LCount - 1, TINV90_DATA, 1.645)
  else
    LTCritical := TInvLookup(LCount - 1, TINV95_DATA, 1.96);

  LMargin := LTCritical * (LStdDev / Sqrt(LCount));
  Result.Lower := LMean - LMargin;
  Result.Upper := LMean + LMargin;
  Result.Level := ALevel;
end;

function TAdvancedStats.BootstrapCI(AIterations: Integer;
  ALevel: Double): TConfidenceInterval;
var
  LN: Integer;
  LIterations: Integer;
  LMeans: TDoubleArray;
  LSortedMeans: TDoubleArray;
  LIterationIndex: Integer;
  LSampleIndex: Integer;
  LSeed: QWord;
  LSum: Double;
  LDataIndex: Integer;
  LLowerIndex: Integer;
  LUpperIndex: Integer;
  LAlpha: Double;
begin
  LN := Length(FData);
  if LN = 0 then
  begin
    Result.Lower := 0.0;
    Result.Upper := 0.0;
    Result.Level := ALevel;
    Exit;
  end;

  if LN = 1 then
  begin
    Result.Lower := FData[0];
    Result.Upper := FData[0];
    Result.Level := ALevel;
    Exit;
  end;

  LIterations := AIterations;
  if LIterations <= 0 then
    LIterations := 1;

  // 使用固定种子保证可复现性（类似 scipy.stats.bootstrap 的 random_state）。
  // 真正的 bootstrap 质量取决于迭代次数，而非种子随机性。
  LSeed := 12345;
  // 预分配 bootstrap 均值数组，避免循环内重新分配
  SetLength(LMeans, LIterations);
  for LIterationIndex := 0 to LIterations - 1 do
  begin
    LSum := 0.0;
    for LSampleIndex := 0 to LN - 1 do
    begin
      LSeed := LSeed * 6364136223846793005 + 1442695040888963407;
      LDataIndex := Integer((LSeed shr 33) mod QWord(LN));
      LSum := LSum + FData[LDataIndex];
    end;
    LMeans[LIterationIndex] := LSum / LN;
  end;

  // 预分配排序数组，避免 SortDoubleArray 内部 realloc
  SetLength(LSortedMeans, LIterations);
  for LIterationIndex := 0 to LIterations - 1 do
    LSortedMeans[LIterationIndex] := LMeans[LIterationIndex];
  SortDoubleArray(LSortedMeans);

  LAlpha := (1.0 - ALevel) / 2.0;
  LLowerIndex := Trunc(LAlpha * LIterations);
  LUpperIndex := Trunc((1.0 - LAlpha) * LIterations) - 1;
  if LLowerIndex < 0 then
    LLowerIndex := 0;
  if LUpperIndex >= LIterations then
    LUpperIndex := LIterations - 1;
  if LUpperIndex < LLowerIndex then
    LUpperIndex := LLowerIndex;

  Result.Lower := LSortedMeans[LLowerIndex];
  Result.Upper := LSortedMeans[LUpperIndex];
  Result.Level := ALevel;
end;

function TAdvancedStats.TestNormalityByMoments: TNormalityTest;
var
  LCount: Integer;
  LNormalityScore: Double;
begin
  LCount := Length(FData);

  // 简化的正态性启发式检验（基于偏度和峰度）
  // 注意：这不是真正的 Shapiro-Wilk 检验，而是一个简化的启发式方法
  if LCount < 3 then
  begin
    Result.IsNormal := True;
    Result.ApproximatePValue := 1.0;
    Result.TestStatistic := 1.0;
    Result.Method := 'Insufficient data';
    Exit;
  end;

  // 基于偏度和峰度的简化评分
  // 理想的正态分布：偏度=0，峰度=0
  LNormalityScore := 1.0 - (Abs(Skewness) + Abs(Kurtosis)) / 2;

  Result.TestStatistic := LNormalityScore;
  Result.Method := 'Moments-based heuristic (skewness+kurtosis)';

  // 简化的决策规则
  if LNormalityScore > 0.8 then
  begin
    Result.IsNormal := True;
    Result.ApproximatePValue := 0.5;
  end
  else if LNormalityScore > 0.6 then
  begin
    Result.IsNormal := True;
    Result.ApproximatePValue := 0.1;
  end
  else
  begin
    Result.IsNormal := False;
    Result.ApproximatePValue := 0.01;
  end;
end;

function TAdvancedStats.ApproximateWelchTScore(const AOther: TDoubleArray): Double;
var
  LMean1: Double;
  LMean2: Double;
  LVar1: Double;
  LVar2: Double;
  LN1: Integer;
  LN2: Integer;
  LSE: Double;
  LTStat: Double;
  I: Integer;
  LSum: Double;
begin
  LMean1 := Mean;
  LMean2 := 0;
  if Length(AOther) > 0 then
  begin
    for I := 0 to High(AOther) do
      LMean2 := LMean2 + AOther[I];
    LMean2 := LMean2 / Length(AOther);
  end;

  LVar1 := Variance;
  LVar2 := 0;
  if Length(AOther) > 1 then
  begin
    LSum := 0.0;
    for I := 0 to High(AOther) do
      LSum := LSum + Sqr(AOther[I] - LMean2);
    LVar2 := LSum / (Length(AOther) - 1);
  end;

  LN1 := Length(FData);
  LN2 := Length(AOther);

  // Welch's t-test
  if (LN1 > 0) and (LN2 > 0) then
  begin
    LSE := Sqrt(LVar1 / LN1 + LVar2 / LN2);
    if LSE > 0 then
      LTStat := (LMean1 - LMean2) / LSE
    else
      LTStat := 0;
  end
  else
    LTStat := 0;

  Result := LTStat;
end;

function TAdvancedStats.EffectSize(const AOther: TDoubleArray): Double;
var
  LMean1: Double;
  LMean2: Double;
  LVar1: Double;
  LVar2: Double;
  LPooledStdDev: Double;
  I: Integer;
  LSum: Double;
begin
  LMean1 := Mean;
  LMean2 := 0;
  if Length(AOther) > 0 then
  begin
    for I := 0 to High(AOther) do
      LMean2 := LMean2 + AOther[I];
    LMean2 := LMean2 / Length(AOther);
  end;

  LVar1 := Variance;
  LVar2 := 0;
  if Length(AOther) > 1 then
  begin
    LSum := 0.0;
    for I := 0 to High(AOther) do
      LSum := LSum + Sqr(AOther[I] - LMean2);
    LVar2 := LSum / (Length(AOther) - 1);
  end;

  // Cohen's d
  LPooledStdDev := Sqrt((LVar1 + LVar2) / 2);
  if LPooledStdDev > 0 then
    Result := (LMean1 - LMean2) / LPooledStdDev
  else
    Result := 0;
end;

function TAdvancedStats.GetData: TDoubleArray;
begin
  Result := FData;
end;

function TAdvancedStats.Count: Integer;
begin
  Result := Length(FData);
end;

end.
