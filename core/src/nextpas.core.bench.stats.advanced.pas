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

{** Bootstrap 假设检验（独立函数，无需 TAdvancedStats 实例）
 *  检验两组数据的均值是否有显著差异（Fisher 置换检验）
 *  @param A 第一组数据
 *  @param B 第二组数据
 *  @param AIterations 重采样次数（默认 10000）
 *  @param ASeed PRNG 种子（默认 0 = 使用 monotonic time）
 *  @raises EBenchInvalidParam 当任一数组为空时 }
function BootstrapTestDifference(const A, B: TDoubleArray;
  AIterations: Integer = 10000; ASeed: UInt64 = 0): TBootstrapTestResult;

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
  LSumSq, LCompensation, LNext, LTemp: Double;
  LDiff: Double;
  LLen: Integer;
begin
  LLen := Length(FData);
  if LLen < 2 then Exit(0);

  LMean := Mean;
  { NaN/Inf guard: 防止 FPC FPU 异常 (Runtime Error 207) }
  if IsNaN(LMean) or IsInfinite(LMean) then
    Exit(0);

  { Fast path: small arrays use simple summation (avoid Kahan overhead) }
  if LLen <= 256 then
  begin
    LSumSq := 0.0;
    for I := 0 to High(FData) do
    begin
      LDiff := FData[I] - LMean;
      LSumSq := LSumSq + LDiff * LDiff;
    end;
  end
  else
  begin
    { Kahan 补偿求和 for Sqr(x - mean) }
    LSumSq := 0.0;
    LCompensation := 0.0;
    for I := 0 to High(FData) do
    begin
      LNext := Sqr(FData[I] - LMean) - LCompensation;
      LTemp := LSumSq + LNext;
      LCompensation := (LTemp - LSumSq) - LNext;
      LSumSq := LTemp;
    end;
  end;
  Result := LSumSq / (LLen - 1);
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
    LSum := LSum + LZ * Sqr(LZ);
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
    LSum4 := LSum4 + Sqr(LDiff * LDiff);
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
{ MAD (Median Absolute Deviation) 计算优化:
  FSortedData 已排序，deviations from median 形成两个单调序列：
  - 左半 (i < medIdx): median - FSortedData[i]，递减 → 逆序遍历得递增
  - 右半 (i >= medIdx): FSortedData[i] - median，递增
  用双指针合并找到中位数，O(N) 无需分配+排序。 }
var
  LMedian: Double;
  LMAD: Double;
  I: Integer;
  LModifiedZ: Double;
  LOutlierCount: Integer;
  LN, LMedIdx, LI, RJ: Integer;
  LLeftVal, LRightVal: Double;
  LSteps, LTarget: Integer;
  LVal: Double;
begin
  Result := Default(TOutlierDetection);
  EnsureSorted;
  LMedian := Median; { uses FSortedData, already sorted }

  { O(N) MAD: 合并两个单调序列找到 deviations 的中位数 }
  LN := Length(FSortedData);
  LMedIdx := LN div 2; { median 的索引 }

  { 目标: 第 LN div 2 小的 deviation (0-based) }
  LTarget := LN div 2;
  LI := LMedIdx - 1;  { 左半从 median-1 向 0 递减 }
  RJ := LMedIdx + 1;  { 右半从 median+1 向末尾递增 }

  if LN mod 2 = 1 then
  begin
    { 奇数个元素: 找第 LTarget 小的 deviation }
    LSteps := 0;
    LMAD := 0;
    while LSteps <= LTarget do
    begin
      if LI >= 0 then
        LLeftVal := LMedian - FSortedData[LI]
      else
        LLeftVal := 1e30; { sentinel: 左半已耗尽 }
      if RJ < LN then
        LRightVal := FSortedData[RJ] - LMedian
      else
        LRightVal := 1e30; { sentinel: 右半已耗尽 }
      if LLeftVal <= LRightVal then
      begin
        LVal := LLeftVal;
        Dec(LI);
      end
      else
      begin
        LVal := LRightVal;
        Inc(RJ);
      end;
      if LSteps = LTarget then
      begin
        LMAD := LVal;
        Break;
      end;
      Inc(LSteps);
    end;
  end
  else
  begin
    { 偶数个元素: 找第 LTarget-1 和第 LTarget 小的 deviation，取平均 }
    LSteps := 0;
    LMAD := 0;
    while LSteps <= LTarget do
    begin
      if LI >= 0 then
        LLeftVal := LMedian - FSortedData[LI]
      else
        LLeftVal := 1e30;
      if RJ < LN then
        LRightVal := FSortedData[RJ] - LMedian
      else
        LRightVal := 1e30;
      if LLeftVal <= LRightVal then
      begin
        LVal := LLeftVal;
        Dec(LI);
      end
      else
      begin
        LVal := LRightVal;
        Inc(RJ);
      end;
      if LSteps = LTarget - 1 then
        LMAD := LVal { 暂存第一个值 }
      else if LSteps = LTarget then
      begin
        LMAD := (LMAD + LVal) / 2.0;
        Break;
      end;
      Inc(LSteps);
    end;
  end;

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

  // 生成 bootstrap 样本均值 + 同步计数 bias（合并两个 O(B) 循环）
  SetLength(LMeans, LIterations);
  LCountBelow := 0;
  for LIterationIndex := 0 to LIterations - 1 do
  begin
    LSum := 0.0;
    for LSampleIndex := 0 to LN - 1 do
    begin
      LDataIndex := LPRNG.NextInt(LN);
      LSum := LSum + FData[LDataIndex];
    end;
    LMeans[LIterationIndex] := LSum / LN;
    if LMeans[LIterationIndex] < LObservedMean then
      Inc(LCountBelow);
  end;

  // 步骤 1: 计算偏差修正因子 z0（LCountBelow 已在上面循环中累计）
  // z0 = Φ^(-1)(#(θ* < θ) / B)
  LZ0 := NormalQuantile((LCountBelow + 0.5) / (LIterations + 1));

  // 步骤 2: 计算加速因子 a（jackknife leave-one-out 估计）
  // a = Σ(θ_(.) - θ_(i))^3 / (6 * (Σ(θ_(.) - θ_(i))^2)^(3/2))
  // θ_(i) = 不含第 i 个样本的均值
  LDiffSqSum := 0.0;
  LDiffCbSum := 0.0;
  for LDataIndex := 0 to LN - 1 do
  begin
    // θ_(i) = (n*θ_(.) - x_i) / (n-1)
    LDiff := LObservedMean - (LN * LObservedMean - FData[LDataIndex]) / (LN - 1);
    LDiffSqSum := LDiffSqSum + LDiff * LDiff;
    LDiffCbSum := LDiffCbSum + Sqr(LDiff) * LDiff;
  end;
  if LDiffSqSum > 0 then
    LA := LDiffCbSum / (6.0 * LDiffSqSum * Sqrt(LDiffSqSum))
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
begin
  Result := nextpas.core.bench.stats.advanced.BootstrapTestDifference(A, B, AIterations, ASeed);
end;

function BootstrapTestDifference(const A, B: TDoubleArray;
  AIterations: Integer; ASeed: UInt64): TBootstrapTestResult;
{ Bootstrap 假设检验: 检验两组数据的均值差异是否显著
  方法: Fisher 置换检验
  1. 合并两组数据
  2. 随机打乱顺序（Fisher-Yates shuffle）
  3. 前 LNA 个作为 A 组，其余作为 B 组，计算均值差异
  4. 与实际差异比较，得到 p-value

  优化: shuffle 过程中增量更新分组和，消除独立的 O(N) 求和循环。 }
var
  LNA, LNB, LN: Integer;
  LData: TDoubleArray;
  LPerm: TInt64Array;
  LIterations: Integer;
  LPRNG: TXoroshiro128Plus;
  LMeanA, LMeanB, LObservedDiff: Double;
  LI, LJ, LSwap, LTmp: Integer;
  LCount: Integer;
  LSumA, LSumB, LTotalSum: Double;
  LValJ, LValSwap: Double;
  LInvNA, LInvNB: Double;
begin
  LNA := Length(A);
  LNB := Length(B);

  if (LNA = 0) or (LNB = 0) then
    raise EBenchInvalidParam.Create('BootstrapTestDifference: input arrays must not be empty');

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

  // 合并数据 + 初始化排列
  LN := LNA + LNB;
  LInvNA := 1.0 / LNA;
  LInvNB := 1.0 / LNB;
  SetLength(LData, LN);
  SetLength(LPerm, LN);
  for LI := 0 to LNA - 1 do
    LData[LI] := A[LI];
  for LI := 0 to LNB - 1 do
    LData[LNA + LI] := B[LI];
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
  // 优化: 在 shuffle 过程中增量更新分组和 LSumA/LSumB，
  // 避免 shuffle 后再做 O(N) 求和。
  // 初始状态: 前 LNA 个位置为 A 组，后 LNB 个位置为 B 组。
  // F-12: 预计算总和，消除每迭代 O(LNA+LNB) 重复求和。
  LTotalSum := 0.0;
  for LI := 0 to LN - 1 do
    LTotalSum := LTotalSum + LData[LI];
  LCount := 0;
  for LI := 0 to LIterations - 1 do
  begin
    // 初始化: 前 LNA 个 = A 组，后 LNB 个 = B 组
    // 优化: 只求 LSumA，LSumB 从总和推导
    LSumA := 0.0;
    for LJ := 0 to LNA - 1 do
      LSumA := LSumA + LData[LPerm[LJ]];
    LSumB := LTotalSum - LSumA;

    // Fisher-Yates shuffle: 随机打乱排列
    // 每次 swap 后增量更新分组和
    for LJ := LN - 1 downto 1 do
    begin
      LSwap := LPRNG.NextInt(LJ + 1);

      // 取当前位置和 swap 目标的值
      LValJ := LData[LPerm[LJ]];
      LValSwap := LData[LPerm[LSwap]];

      // 执行 swap
      LTmp := LPerm[LJ];
      LPerm[LJ] := LPerm[LSwap];
      LPerm[LSwap] := LTmp;

      // 增量更新分组和:
      // 位置 LJ 从 LValJ → LValSwap
      // 位置 LSwap 从 LValSwap → LValJ
      if LJ < LNA then
        LSumA := LSumA - LValJ + LValSwap
      else
        LSumB := LSumB - LValJ + LValSwap;

      if LSwap < LNA then
        LSumA := LSumA - LValSwap + LValJ
      else
        LSumB := LSumB - LValSwap + LValJ;
    end;

    if Abs(LSumA * LInvNA - LSumB * LInvNB) >= Abs(LObservedDiff) then
      Inc(LCount);
  end;

  // 双尾 p-value (包含 +1 修正，避免 p=0)
  Result.PValue := (LCount + 1.0) / (LIterations + 1.0);
  Result.IsSignificant := Result.PValue < BENCH_SIGNIFICANCE_ALPHA;
  Result.Iterations := LIterations;
end;

function TAdvancedStats.TestNormalityByMoments: TNormalityTest;
{ D'Agostino-Pearson K2 正态性检验
  K2 = Z_skewness^2 + Z_kurtosis^2 ~ χ²(2)
  参考: D'Agostino, R.B. (1971), "An omnibus test of normality for moderate and large samples" }
var
  LCount: Integer;
  LGamma1, LGamma2: Double;
  LWSq, LA, LB, LC, LZSkew: Double;
  LMu2, LSigma2, LTerm1, LTerm2, LZKurt: Double;
  LP, LK2, LCubeArg: Double;
begin
  LCount := Length(FData);

  if LCount < 8 then
  begin
    Result.IsNormal := True;
    Result.ApproximatePValue := 1.0;
    Result.TestStatistic := 0.0;
    Result.Method := 'Insufficient data (n<8)';
    Exit;
  end;

  { Z_skewness: D'Agostino (1970) 变换 }
  LGamma1 := Skewness;
  // sqrt((n+1)(n+3) / (6(n-2)))
  LB := Sqrt((LCount + 1) * (LCount + 3) / (6.0 * (LCount - 2)));
  // 3(n^2+27n-70)(n+1)(n+3) / ((n-2)(n+5)(n+7)(n+9))
  LC := 3.0 * (Sqr(LCount) + 27.0 * LCount - 70.0) * (LCount + 1) * (LCount + 3) /
        ((LCount - 2) * (LCount + 5) * (LCount + 7) * (LCount + 9));
  // W^2 = -1 + sqrt(2(C-1))
  LWSq := -1.0 + Sqrt(2.0 * (LC - 1.0));
  // delta = 1/sqrt(ln(sqrt(W^2)))
  // alpha = sqrt(2/(W^2-1))
  if LWSq > 1.001 then
  begin
    LA := Sqrt(2.0 / (LWSq - 1.0));
    LZSkew := LB * (LGamma1 / Sqrt(LWSq - 1.0) + Sqrt(1.0 / (LWSq - 1.0)));
    // 使用双曲反正切: Z = (1/alpha) * asinh(Gamma1/(alpha*sqrt(W^2-1)))
    // 简化为: Z = LB * ln(Gamma1/LA + sqrt((Gamma1/LA)^2 + 1))
    if Abs(LGamma1) > 1e-15 then
      LZSkew := LB * Ln(Abs(LGamma1) / LA + Sqrt(Sqr(LGamma1 / LWSq) + 1.0))
    else
      LZSkew := 0.0;
  end
  else
    LZSkew := 0.0;

  { Z_kurtosis: Anscombe-Glynn (1983) 变换 }
  LGamma2 := Kurtosis;
  // E[K] = 3(n-1)/(n+1)
  LMu2 := 3.0 * (LCount - 1) / (LCount + 1);
  // Var[K] = 24n(n-2)(n-3) / ((n+1)^2(n+3)(n+5))
  LSigma2 := 24.0 * LCount * (LCount - 2) * (LCount - 3) /
              (Sqr(LCount + 1.0) * (LCount + 3) * (LCount + 5));
  // Term1 = (6(n^2-5n+2)/((n+7)(n+9))) * sqrt(6(n+3)(n+5)/(n(n-2)(n-3)))
  LTerm1 := 6.0 * (Sqr(LCount) - 5.0 * LCount + 2.0) / ((LCount + 7) * (LCount + 9)) *
            Sqrt(6.0 * (LCount + 3) * (LCount + 5) / (LCount * (LCount - 2) * (LCount - 3)));
  // Term2 = 6 + 8/LTerm1 * (2/LTerm1 + sqrt(1 + 4/LTerm1^2))
  if Abs(LTerm1) > 1e-15 then
    LTerm2 := 6.0 + 8.0 / LTerm1 * (2.0 / LTerm1 + Sqrt(1.0 + 4.0 / Sqr(LTerm1)))
  else
    LTerm2 := 6.0;
  // Z = ((1 - 2/(9*Term2)) - ((1-2/Term2)/(1+((Kurtosis-LMu2)/sqrt(Var) - LTerm1)/sqrt(LTerm2)))^(1/3))
  //     / sqrt(2/(9*Term2))
  LP := (LGamma2 - LMu2) / Sqrt(LSigma2);
  if Abs(LTerm2) > 1e-15 then
  begin
    // cube root via Exp(Ln(x)/3) — Power 不在 uses 中
    LCubeArg := (1.0 - 2.0 / LTerm2) / (1.0 + (LP - LTerm1) / Sqrt(LTerm2));
    if LCubeArg > 0 then
      LZKurt := ((1.0 - 2.0 / (9.0 * LTerm2)) - Exp(Ln(LCubeArg) / 3.0)) /
                Sqrt(2.0 / (9.0 * LTerm2))
    else if LCubeArg < 0 then
      LZKurt := ((1.0 - 2.0 / (9.0 * LTerm2)) + Exp(Ln(-LCubeArg) / 3.0)) /
                Sqrt(2.0 / (9.0 * LTerm2))
    else
      LZKurt := (1.0 - 2.0 / (9.0 * LTerm2)) / Sqrt(2.0 / (9.0 * LTerm2));
  end
  else
    LZKurt := 0.0;

  { K2 = Z_skewness^2 + Z_kurtosis^2 ~ χ²(2) }
  LK2 := Sqr(LZSkew) + Sqr(LZKurt);

  // χ²(2) 的 p-value: P = exp(-K2/2)（指数分布 CDF）
  Result.TestStatistic := LK2;
  Result.Method := 'D''Agostino-Pearson K2';
  Result.ApproximatePValue := Exp(-LK2 / 2.0);
  if Result.ApproximatePValue > 1.0 then
    Result.ApproximatePValue := 1.0;
  if Result.ApproximatePValue < 0 then
    Result.ApproximatePValue := 0;
  Result.IsNormal := Result.ApproximatePValue >= BENCH_SIGNIFICANCE_ALPHA;
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
