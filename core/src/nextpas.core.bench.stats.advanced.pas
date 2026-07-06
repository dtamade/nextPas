{**
 * 高级统计分析器
 *
 * 提供高级统计分析功能，
 * 包括异常值检测、正态性检验、置信区间等。
 *}
unit nextpas.core.bench.stats.advanced;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.platform;

type
  {** TConfidenceInterval is now in nextpas.core.bench.base }

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
   * 高级统计分析器 (DS-06: class 避免 record 隐式拷贝共享缓存)
   *}
  TAdvancedStats = class
  private
    FData: TDoubleArray;
    FSortedData: TDoubleArray;
    FSorted: Boolean;
    FCachedMean: Double;
    FMeanCached: Boolean;
    procedure EnsureSorted;
    {** PF-04: compute mean + variance of external array in a single pass }
    class procedure ComputeMeanVariance(const AData: TDoubleArray;
      out AMean, AVariance: Double); static;
  public
    {**
     * 创建统计分析器
     *}
    constructor Create(const AData: TDoubleArray);

    {**
     * 释放资源
     *}
    destructor Destroy; override;

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
     * Bootstrap 置信区间
     *  @param AIterations 重采样次数（默认 10000）
     *  @param ALevel 置信水平（默认 0.95）
     *  @param ASeed PRNG 种子（默认 0 = 使用 monotonic time，>0 = 固定种子用于可重现测试）
     *}
    function BootstrapCI(AIterations: Integer = 10000;
      ALevel: Double = 0.95; ASeed: UInt64 = 0): TConfidenceInterval;

    {**
     * BCa Bootstrap 置信区间 (Phase B.2)
     *  Bias-Corrected and Accelerated 方法，比百分位数法更精确
     *  @param AIterations 重采样次数（默认 10000）
     *  @param ALevel 置信水平（默认 0.95）
     *  @param ASeed PRNG 种子（默认 0 = 使用 monotonic time）
     *}
    function BootstrapCI_BCa(AIterations: Integer = 10000;
      ALevel: Double = 0.95; ASeed: UInt64 = 0): TConfidenceInterval;

    {**
     * Bootstrap 假设检验 (Phase B.3)
     *  检验两组数据的均值是否有显著差异
     *  @param A 第一组数据
     *  @param B 第二组数据
     *  @param AIterations 重采样次数（默认 10000）
     *  @param ASeed PRNG 种子（默认 0 = 使用 monotonic time）
     *}
    function BootstrapTestDifference(const A, B: TDoubleArray;
      AIterations: Integer = 10000; ASeed: UInt64 = 0): TBootstrapTestResult;

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
  nextpas.core.math.scalar,
  nextpas.core.time.cpu,
  nextpas.core.bench.intf; { PF-06: for EBenchInvalidParam }

{** F-12: 全局计数器，防止 BootstrapCI 快速连续调用时种子碰撞 }
var
  GBootstrapCallCount: UInt64 = 0;

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

constructor TAdvancedStats.Create(const AData: TDoubleArray);
begin
  inherited Create;
  FData := Copy(AData);
  FSorted := False;
  FMeanCached := False;
end;

destructor TAdvancedStats.Destroy;
begin
  SetLength(FData, 0);
  SetLength(FSortedData, 0);
  inherited Destroy;
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
  LCompensation: Double;
  LDiff: Double;
  LTemp: Double;
begin
  if Length(FData) < 2 then Exit(0);

  LMean := Mean;
  { NaN/Inf guard: 防止 FPC FPU 异常 (Runtime Error 207) }
  if IsNaN(LMean) or IsInfinite(LMean) then
    Exit(0);

  { F-09: Kahan 补偿求和，减少大数组浮点累积误差 }
  LSum := 0;
  LCompensation := 0;
  for I := 0 to High(FData) do
  begin
    LDiff := Sqr(FData[I] - LMean);
    LTemp := LSum + LDiff;
    if Abs(LSum) >= Abs(LDiff) then
      LCompensation := LCompensation + ((LSum - LTemp) + LDiff)
    else
      LCompensation := LCompensation + ((LDiff - LTemp) + LSum);
    LSum := LTemp;
  end;
  Result := (LSum + LCompensation) / (Length(FData) - 1);
end;

function TAdvancedStats.Skewness: Double;
var
  I: Integer;
  LMean: Double;
  LStdDev: Double;
  LSum: Double;
  LCount: Integer;
  LZ: Double;
begin
  LCount := Length(FData);
  if LCount < 3 then Exit(0);

  LMean := Mean;
  LStdDev := StdDev;
  { NaN/Inf guard: 防止 FPC FPU 异常 (Runtime Error 207) }
  if IsNaN(LMean) or IsInfinite(LMean) or IsNaN(LStdDev) or IsInfinite(LStdDev) then
    Exit(0);
  if LStdDev = 0 then Exit(0);

  LSum := 0;
  for I := 0 to High(FData) do
  begin
    LZ := (FData[I] - LMean) / LStdDev;
    LSum := LSum + LZ * LZ * LZ;
  end;

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
  LSum2: Double;
  LSum4: Double;
  LDiff: Double;
  LCount: Integer;
  Lk2: Double;
  Lk4: Double;
  LRatio: Double;
begin
  LCount := Length(FData);
  if LCount < 4 then Exit(0);

  LMean := Mean;
  { NaN/Inf guard: 防止 FPC FPU 异常 (Runtime Error 207) }
  if IsNaN(LMean) or IsInfinite(LMean) then
    Exit(0);

  LSum2 := 0;
  LSum4 := 0;
  for I := 0 to High(FData) do
  begin
    LDiff := FData[I] - LMean;
    LSum2 := LSum2 + LDiff * LDiff;
    LSum4 := LSum4 + LDiff * LDiff * LDiff * LDiff;
  end;

  if LSum2 = 0 then Exit(0);

  // Population central moments
  Lk2 := LSum2 / LCount;
  Lk4 := LSum4 / LCount;
  LRatio := Lk4 / (Lk2 * Lk2);

  // Unbiased sample excess kurtosis (Fisher's G2)
  Result := (LCount - 1) * ((LCount + 1) * LRatio - 3 * (LCount - 1))
            / ((LCount - 2) * (LCount - 3));
end;

function TAdvancedStats.Percentile(APercentile: Double): Double;
begin
  { PF-06: range validation — reject out-of-range percentiles }
  if (APercentile < 0.0) or (APercentile > 100.0) then
    raise EBenchInvalidParam.CreateFmt(
      'TAdvancedStats.Percentile: APercentile must be in [0, 100], got %.2f', [APercentile]);
  EnsureSorted;
  Result := PercentileSorted(FSortedData, APercentile);
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
  Result := Default(TOutlierDetection);
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
  Result := Default(TOutlierDetection);
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
begin
  Result := Default(TOutlierDetection);
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
    // DS-05: <90% level has no lookup table; conservatively use 95% critical value.
    // This gives a wider interval than requested, which is safe (not anti-conservative).
    // Callers needing precise <90% CIs should use BootstrapCI instead.
    LTCritical := TInvLookup(LCount - 1, TINV95_DATA, 1.96);

  LMargin := LTCritical * (LStdDev / Sqrt(LCount));
  Result.Lower := LMean - LMargin;
  Result.Upper := LMean + LMargin;
  Result.Level := ALevel;
end;

function TAdvancedStats.BootstrapCI(AIterations: Integer;
  ALevel: Double; ASeed: UInt64): TConfidenceInterval;
var
  LN: Integer;
  LIterations: Integer;
  LMeans: TDoubleArray;
  LIterationIndex: Integer;
  LSampleIndex: Integer;
  LSum: Double;
  LDataIndex: Integer;
  LLowerIndex: Integer;
  LUpperIndex: Integer;
  LAlpha: Double;
  LPRNG: TXoroshiro128Plus;
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

  // F-20: 可选种子，ASeed=0 时使用 monotonic time，>0 时固定种子用于可重现测试
  // F-12: 种子混合全局计数器，防止快速连续调用时种子碰撞
  if ASeed > 0 then
    LPRNG.Init(ASeed)
  else
  begin
    Inc(GBootstrapCallCount);
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount shl 32));
  end;

  SetLength(LMeans, LIterations);
  for LIterationIndex := 0 to LIterations - 1 do
  begin
    LSum := 0.0;
    for LSampleIndex := 0 to LN - 1 do
    begin
      LDataIndex := LPRNG.NextInt(LN);
      LSum := LSum + FData[LDataIndex];
    end;
    LMeans[LIterationIndex] := LSum / LN;
  end;

  SortDoubleArray(LMeans);

  LAlpha := (1.0 - ALevel) / 2.0;
  LLowerIndex := Trunc(LAlpha * LIterations);
  LUpperIndex := Trunc((1.0 - LAlpha) * LIterations) - 1;
  if LLowerIndex < 0 then
    LLowerIndex := 0;
  if LUpperIndex >= LIterations then
    LUpperIndex := LIterations - 1;
  if LUpperIndex < LLowerIndex then
    LUpperIndex := LLowerIndex;

  Result.Lower := LMeans[LLowerIndex];
  Result.Upper := LMeans[LUpperIndex];
  Result.Level := ALevel;
end;

function TAdvancedStats.BootstrapCI_BCa(AIterations: Integer;
  ALevel: Double; ASeed: UInt64): TConfidenceInterval;
{ BCa (Bias-Corrected and Accelerated) Bootstrap 置信区间
  算法:
  1. 计算偏差修正因子 z0 = Φ^(-1)(#(θ* < θ) / B)
  2. 计算加速因子 a = Σ(θ_(.) - θ_(i))^3 / (6 * (Σ(θ_(.) - θ_(i))^2)^(3/2))
  3. 调整百分位数: α1 = Φ(z0 + (z0 + zα)/(1 - a(z0 + zα)))
                   α2 = Φ(z0 + (z0 + z(1-α))/(1 - a(z0 + z(1-α)))) }
var
  LN, LIterations: Integer;
  LMeans: TDoubleArray;
  LIterationIndex, LSampleIndex, LDataIndex: Integer;
  LSum, LObservedMean: Double;
  LPRNG: TXoroshiro128Plus;
  LCountBelow: Integer;
  LZ0, LA: Double;
  LAlpha, LAlpha1, LAlpha2: Double;
  LLowerIndex, LUpperIndex: Integer;
  LDiff, LDiffSqSum, LDiffCbSum: Double;
  LZAlpha, LZAlpha1m: Double;
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

  // 初始化 PRNG
  if ASeed > 0 then
    LPRNG.Init(ASeed)
  else
  begin
    Inc(GBootstrapCallCount);
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount shl 32));
  end;

  // 计算观测均值
  LSum := 0.0;
  for LDataIndex := 0 to LN - 1 do
    LSum := LSum + FData[LDataIndex];
  LObservedMean := LSum / LN;

  // 生成 bootstrap 样本均值
  SetLength(LMeans, LIterations);
  for LIterationIndex := 0 to LIterations - 1 do
  begin
    LSum := 0.0;
    for LSampleIndex := 0 to LN - 1 do
    begin
      LDataIndex := LPRNG.NextInt(LN);
      LSum := LSum + FData[LDataIndex];
    end;
    LMeans[LIterationIndex] := LSum / LN;
  end;

  // 步骤 1: 计算偏差修正因子 z0
  LCountBelow := 0;
  for LIterationIndex := 0 to LIterations - 1 do
    if LMeans[LIterationIndex] < LObservedMean then
      Inc(LCountBelow);
  // z0 = Φ^(-1)(#(θ* < θ) / B)
  LZ0 := NormalQuantile((LCountBelow + 0.5) / (LIterations + 1));

  // 步骤 2: 计算加速因子 a
  // a = Σ(θ_(.) - θ_(i))^3 / (6 * (Σ(θ_(.) - θ_(i))^2)^(3/2))
  // 使用 jackknife 估计
  LDiffSqSum := 0.0;
  LDiffCbSum := 0.0;
  for LIterationIndex := 0 to LIterations - 1 do
  begin
    LDiff := LObservedMean - LMeans[LIterationIndex];
    LDiffSqSum := LDiffSqSum + LDiff * LDiff;
    LDiffCbSum := LDiffCbSum + LDiff * LDiff * LDiff;
  end;
  if LDiffSqSum > 0 then
    LA := LDiffCbSum / (6.0 * Power(LDiffSqSum, 1.5))
  else
    LA := 0.0;

  // 步骤 3: 调整百分位数
  LAlpha := (1.0 - ALevel) / 2.0;
  // zα = Φ^(-1)(α)
  LZAlpha := NormalQuantile(LAlpha);
  LZAlpha1m := NormalQuantile(1.0 - LAlpha);

  // α1 = Φ(z0 + (z0 + zα)/(1 - a(z0 + zα)))
  LAlpha1 := NormalCDF(LZ0 + (LZ0 + LZAlpha) / (1.0 - LA * (LZ0 + LZAlpha)));
  // α2 = Φ(z0 + (z0 + z(1-α))/(1 - a(z0 + z(1-α))))
  LAlpha2 := NormalCDF(LZ0 + (LZ0 + LZAlpha1m) / (1.0 - LA * (LZ0 + LZAlpha1m)));

  SortDoubleArray(LMeans);

  LLowerIndex := Trunc(LAlpha1 * LIterations);
  LUpperIndex := Trunc(LAlpha2 * LIterations) - 1;
  if LLowerIndex < 0 then LLowerIndex := 0;
  if LUpperIndex >= LIterations then LUpperIndex := LIterations - 1;
  if LUpperIndex < LLowerIndex then LUpperIndex := LLowerIndex;

  Result.Lower := LMeans[LLowerIndex];
  Result.Upper := LMeans[LUpperIndex];
  Result.Level := ALevel;
end;

function TAdvancedStats.BootstrapTestDifference(const A, B: TDoubleArray;
  AIterations: Integer; ASeed: UInt64): TBootstrapTestResult;
{ Bootstrap 假设检验: 检验两组数据的均值差异是否显著
  方法: Fisher 置换检验
  1. 合并两组数据
  2. 随机打乱顺序（Fisher-Yates shuffle）
  3. 前 LNA 个作为 A 组，其余作为 B 组，计算均值差异
  4. 与实际差异比较，得到 p-value }
var
  LNA, LNB, LN: Integer;
  LMerged: TDoubleArray;
  LPerm: TInt64Array;
  LIterations: Integer;
  LPRNG: TXoroshiro128Plus;
  LMeanA, LMeanB, LObservedDiff: Double;
  LI, LJ, LSwap, LIdx: Integer;
  LCount: Integer;
  LSumA, LSumB: Double;
  LPermutedDiff: Double;
begin
  LNA := Length(A);
  LNB := Length(B);

  if (LNA = 0) or (LNB = 0) then
  begin
    Result.ObservedDiff := 0.0;
    Result.PValue := 1.0;
    Result.IsSignificant := False;
    Result.Iterations := 0;
    Exit;
  end;

  // 计算观测差异
  LMeanA := 0.0;
  for LI := 0 to LNA - 1 do
    LMeanA := LMeanA + A[LI];
  LMeanA := LMeanA / LNA;

  LMeanB := 0.0;
  for LI := 0 to LNB - 1 do
    LMeanB := LMeanB + B[LI];
  LMeanB := LMeanB / LNB;

  LObservedDiff := LMeanA - LMeanB;
  Result.ObservedDiff := LObservedDiff;

  // 合并数据
  LN := LNA + LNB;
  SetLength(LMerged, LN);
  for LI := 0 to LNA - 1 do
    LMerged[LI] := A[LI];
  for LI := 0 to LNB - 1 do
    LMerged[LNA + LI] := B[LI];

  // 初始化排列索引
  SetLength(LPerm, LN);
  for LI := 0 to LN - 1 do
    LPerm[LI] := LI;

  // 初始化 PRNG
  if ASeed > 0 then
    LPRNG.Init(ASeed)
  else
  begin
    Inc(GBootstrapCallCount);
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount shl 32));
  end;

  LIterations := AIterations;
  if LIterations <= 0 then
    LIterations := 1;

  // Fisher permutation test
  LCount := 0;
  for LI := 0 to LIterations - 1 do
  begin
    // Fisher-Yates shuffle: 随机打乱排列
    for LJ := LN - 1 downto 1 do
    begin
      LSwap := LPRNG.NextInt(LJ + 1);
      LIdx := LPerm[LJ];
      LPerm[LJ] := LPerm[LSwap];
      LPerm[LSwap] := LIdx;
    end;

    // 计算前 LNA 个元素的和（A 组）和后 LNB 个元素的和（B 组）
    LSumA := 0.0;
    for LJ := 0 to LNA - 1 do
      LSumA := LSumA + LMerged[LPerm[LJ]];
    LSumB := 0.0;
    for LJ := LNA to LN - 1 do
      LSumB := LSumB + LMerged[LPerm[LJ]];

    LPermutedDiff := (LSumA / LNA) - (LSumB / LNB);
    if Abs(LPermutedDiff) >= Abs(LObservedDiff) then
      Inc(LCount);
  end;

  // 双尾 p-value (包含 +1 修正，避免 p=0)
  Result.PValue := (LCount + 1.0) / (LIterations + 1.0);
  Result.IsSignificant := Result.PValue < BENCH_SIGNIFICANCE_ALPHA;
  Result.Iterations := LIterations;
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

{** PF-04: compute mean + variance of external data array.
 *  Two-pass algorithm: first pass for mean, second for sum-of-squared-deviations.
 *  More numerically stable than single-pass sum-of-squares formula. }
class procedure TAdvancedStats.ComputeMeanVariance(const AData: TDoubleArray;
  out AMean, AVariance: Double);
var
  LCount: Integer;
  LSum, LSumSq, LDiff: Double;
  I: Integer;
begin
  LCount := Length(AData);
  if LCount = 0 then
  begin
    AMean := 0;
    AVariance := 0;
    Exit;
  end;

  LSum := 0;
  for I := 0 to High(AData) do
    LSum := LSum + AData[I];
  AMean := LSum / LCount;

  if LCount > 1 then
  begin
    LSumSq := 0;
    for I := 0 to High(AData) do
    begin
      LDiff := AData[I] - AMean;
      LSumSq := LSumSq + LDiff * LDiff;
    end;
    AVariance := LSumSq / (LCount - 1);
  end
  else
    AVariance := 0;
end;

function TAdvancedStats.ApproximateWelchTScore(const AOther: TDoubleArray): Double;
var
  LMean1: Double;
  LVar1: Double;
  LN1: Integer;
  LN2: Integer;
  LSE: Double;
  LMean2, LVar2: Double;
begin
  LN1 := Length(FData);
  LN2 := Length(AOther);

  LMean1 := Mean;
  LVar1 := Variance;

  { PF-04: compute mean + variance of AOther in a single pass }
  ComputeMeanVariance(AOther, LMean2, LVar2);

  // Welch's t-test
  if (LN1 > 0) and (LN2 > 0) then
  begin
    LSE := Sqrt(LVar1 / LN1 + LVar2 / LN2);
    if LSE > 0 then
      Result := (LMean1 - LMean2) / LSE
    else
      Result := 0;
  end
  else
    Result := 0;
end;

function TAdvancedStats.EffectSize(const AOther: TDoubleArray): Double;
var
  LMean1: Double;
  LVar1: Double;
  LPooledStdDev: Double;
  LMean2, LVar2: Double;
begin
  LMean1 := Mean;
  LVar1 := Variance;

  { PF-04: compute mean + variance of AOther in a single pass }
  ComputeMeanVariance(AOther, LMean2, LVar2);

  // Cohen's d — weighted pooled stddev (PF-05)
  if (Length(FData) > 1) and (Length(AOther) > 1) then
    LPooledStdDev := Sqrt(((Length(FData) - 1) * LVar1 + (Length(AOther) - 1) * LVar2) /
                          (Length(FData) + Length(AOther) - 2))
  else if LVar1 > 0 then
    LPooledStdDev := Sqrt(LVar1)
  else
    LPooledStdDev := Sqrt(LVar2);
  if LPooledStdDev > 0 then
    Result := (LMean1 - LMean2) / LPooledStdDev
  else
    Result := 0;
end;

function TAdvancedStats.GetData: TDoubleArray;
begin
  Result := Copy(FData);
end;

function TAdvancedStats.Count: Integer;
begin
  Result := Length(FData);
end;

end.
