{**
 * 高级统计分析器
 *
 * 提供高级统计分析功能，
 * 包括异常值检测、正态性检验、置信区间等。
 *}
unit nextpas.core.bench.stats.advanced;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{ 实数字面量最低 Double，防止与整型混算落到 Single 精度（见 stats 同注） }
{$MINFPCONSTPREC 64}

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
  nextpas.core.bench.intf, { for EBenchInvalidParam }
  nextpas.core.atomic.types; { P0-2: 线程安全的原子计数器 }

{** F-12: 全局计数器，防止 BootstrapCI 快速连续调用时种子碰撞 }
var
  GBootstrapCallCount: TAtomicUInt64;

{ === 内部辅助函数 === }

procedure WelfordMeanVariance(const AData: TDoubleArray;
  out AMean, AVariance: Double; out AValidCount: Integer);
{ Welford 单遍算法：同时计算均值和方差，跳过 NaN/Inf。 }
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
  I, LValidCount: Integer;
  LSum: Double;
begin
  if FMeanCached then
    Exit(FCachedMean);
  if Length(FData) = 0 then
    Exit(0);

  { NaN/Inf guard: 与 Variance 行为一致 }
  LSum := 0;
  LValidCount := 0;
  for I := 0 to High(FData) do
  begin
    if IsDoubleNaN(FData[I]) or IsInfinite(FData[I]) then
      Continue;
    Inc(LValidCount);
    LSum := LSum + FData[I];
  end;

  if LValidCount = 0 then
    FCachedMean := 0
  else
    FCachedMean := LSum / LValidCount;
  FMeanCached := True;
  Result := FCachedMean;
end;

function TAdvancedStats.Median: Double;
var
  LCount, LValidCount: Integer;
  I: Integer;
begin
  LCount := Length(FData);
  if LCount = 0 then Exit(0);

  EnsureSorted;

  { FSortedData 通过 SortDoubleArray 排序，NaN/Inf 已在末尾；计算有效元素数量 }
  LValidCount := LCount;
  for I := LCount - 1 downto 0 do
  begin
    if IsDoubleNaN(FSortedData[I]) or IsInfinite(FSortedData[I]) then
      Dec(LValidCount)
    else
      Break;
  end;

  if LValidCount = 0 then Exit(0);

  if LValidCount mod 2 = 0 then
    Result := (FSortedData[LValidCount div 2 - 1] + FSortedData[LValidCount div 2]) / 2
  else
    Result := FSortedData[LValidCount div 2];
end;

function TAdvancedStats.StdDev: Double;
begin
  Result := Sqrt(Variance);
end;

function TAdvancedStats.Variance: Double;
var
  LMean: Double;
  LValidCount: Integer;
begin
  if Length(FData) < 2 then Exit(0);
  WelfordMeanVariance(FData, LMean, Result, LValidCount);
end;

function TAdvancedStats.Skewness: Double;
{ Welford for mean+variance, then single pass for 3rd moment. }
var
  I, LValidCount: Integer;
  LMean, LVariance, LStdDev, LSum, LZ: Double;
begin
  if Length(FData) < 3 then Exit(0);
  WelfordMeanVariance(FData, LMean, LVariance, LValidCount);
  if IsDoubleNaN(LMean) or IsInfinite(LMean) then Exit(0);
  if LValidCount < 3 then Exit(0);
  LStdDev := Sqrt(LVariance);
  if LStdDev = 0 then Exit(0);
  LSum := 0;
  for I := 0 to High(FData) do
  begin
    if IsDoubleNaN(FData[I]) or IsInfinite(FData[I]) then Continue;
    LZ := (FData[I] - LMean) / LStdDev;
    LSum := LSum + LZ * Sqr(LZ);
  end;
  { Fisher-Pearson 调整 G1。LZ 用的是样本标准差 (ddof=1)，故
    LSum = n * m3 / s³，G1 = n²/((n-1)(n-2)) * m3/s³ = n * LSum / ((n-1)(n-2))。
    旧式 (LSum/n)*sqrt(n(n-1))/(n-2) 把总体矩版调整因子套在样本矩上，
    结果偏低 ((n-1)/n)^1.5（n=20 时约 -7.4%）；scipy.stats.skew(bias=False)
    金标见 test_bench_stats_advanced。 }
  Result := (LSum * LValidCount) /
    ((LValidCount - 1.0) * (LValidCount - 2.0));
end;

function TAdvancedStats.Kurtosis: Double;
{ Welford for mean, then single pass for 2nd/4th moments. }
var
  I, LValidCount: Integer;
  LMean, LVariance, LSum2, LSum4, LDiff, Lk2, Lk4, LRatio: Double;
begin
  if Length(FData) < 4 then Exit(0);
  WelfordMeanVariance(FData, LMean, LVariance, LValidCount);
  if IsDoubleNaN(LMean) or IsInfinite(LMean) then Exit(0);
  if LValidCount < 4 then Exit(0);
  LSum2 := 0; LSum4 := 0;
  for I := 0 to High(FData) do
  begin
    if IsDoubleNaN(FData[I]) or IsInfinite(FData[I]) then Continue;
    LDiff := FData[I] - LMean;
    LSum2 := LSum2 + LDiff * LDiff;
    LSum4 := LSum4 + Sqr(LDiff * LDiff);
  end;
  if LSum2 = 0 then Exit(0);
  Lk2 := LSum2 / LValidCount;
  Lk4 := LSum4 / LValidCount;
  LRatio := Lk4 / (Lk2 * Lk2);
  { Unbiased sample excess kurtosis (Fisher's G2) }
  Result := (LValidCount - 1) * ((LValidCount + 1) * LRatio - 3 * (LValidCount - 1))
            / ((LValidCount - 2) * (LValidCount - 3));
end;

function TAdvancedStats.Percentile(APercentile: Double): Double;
begin
  { range validation — reject out-of-range percentiles }
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
    { 奇数个元素: 归并流不含 median 自身的 0 偏差（全集最小值），
      全集第 LTarget 小在流中是第 LTarget-1 小 (F-31)；
      n=1 时 LTarget 变 -1，循环不执行，LMAD=0 走无异常值路径 }
    Dec(LTarget);
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
    { 偶数个元素: 右半必须从 LMedIdx 起——S[LMedIdx] 的偏差非零且属于全集，
      从 LMedIdx+1 起会整个漏掉它 (F-31)；找第 LTarget-1/LTarget 小取平均 }
    RJ := LMedIdx;
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

  // 使用 t 分布临界值（小样本更准确）；边界比较带 F-32 余量，
  // 否则 Double(0.95) < extended 0.95 会让请求 95% 的调用者拿到 90% 表
  if ALevel >= 0.99 - BENCH_LEVEL_EPS then
    LTCritical := TInvLookup(LCount - 1, TINV99_DATA, 2.576)
  else if ALevel >= 0.95 - BENCH_LEVEL_EPS then
    LTCritical := TInvLookup(LCount - 1, TINV95_DATA, 1.96)
  else if ALevel >= 0.90 - BENCH_LEVEL_EPS then
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
    GBootstrapCallCount.Increment;
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount.Load shl 32));
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
    GBootstrapCallCount.Increment;
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount.Load shl 32));
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
  LSumA, LTotalSum: Double;
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
    GBootstrapCallCount.Increment;
    LPRNG.Init(platform_monotonic_ns xor (GBootstrapCallCount.Load shl 32));
  end;

  LIterations := AIterations;
  if LIterations <= 0 then
    LIterations := 1;

  // Fisher permutation test
  // 优化: 在 shuffle 过程中增量更新 LSumA，LSumB 从 LTotalSum - LSumA 推导
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
    LSumA := 0.0;
    for LJ := 0 to LNA - 1 do
      LSumA := LSumA + LData[LPerm[LJ]];

    // Fisher-Yates shuffle: 随机打乱排列
    // 每次 swap 后增量更新 LSumA，LSumB 统一从 LTotalSum - LSumA 推导
    for LJ := LN - 1 downto 1 do
    begin
      LSwap := LPRNG.NextInt(LJ + 1);

      LValJ := LData[LPerm[LJ]];
      LValSwap := LData[LPerm[LSwap]];

      LTmp := LPerm[LJ];
      LPerm[LJ] := LPerm[LSwap];
      LPerm[LSwap] := LTmp;

      if LJ < LNA then
        LSumA := LSumA - LValJ + LValSwap;
      if LSwap < LNA then
        LSumA := LSumA - LValSwap + LValJ;
    end;

    if Abs(LSumA * LInvNA - (LTotalSum - LSumA) * LInvNB) >= Abs(LObservedDiff) then
      Inc(LCount);
  end;

  { 双尾 p-value: +1 修正是 Fisher 置换检验标准做法，保证 p-value > 0 }
  Result.PValue := (LCount + 1.0) / (LIterations + 1.0);
  Result.IsSignificant := Result.PValue < BENCH_SIGNIFICANCE_ALPHA;
  Result.Iterations := LIterations;
end;

function TAdvancedStats.TestNormalityByMoments: TNormalityTest;
{ D'Agostino-Pearson K2 正态性检验，逐式对齐 scipy.stats.normaltest。
  K2 = Z_skew^2 + Z_kurt^2 ~ χ²(2)；p = exp(-K2/2) 即 chi2(2).sf 精确式。
  两个变换的输入都是有偏样本矩（除以 n）：
    Z_skew (D'Agostino 1970) 吃 √b1 = m3/m2^1.5，再乘标准化因子得 Y；
    Z_kurt (Anscombe-Glynn 1983) 吃 b2 = m4/m2²（期望 3(n-1)/(n+1)≈3），
    不能喂 Fisher G2（0 中心无偏超额峰度）——口径混用会让近正态数据
    的 K2 爆炸、偏斜数据的 K2 被压平（F-33，双向误判）。
  金标: test_bench_stats_advanced Golden_Normality_WelchEffect。 }
var
  I, LValidCount: Integer;
  LMean, LVariance: Double;
  LDiff, LD2, LSum2, LSum3, LSum4, LM2, LM3, LM4: Double;
  LB1, LY, LBeta2, LWSq, LDelta, LAlpha, LYA, LZSkew: Double;
  LB2, LE, LVarB2, LX, LSqrtB1, LA, LDenom, LTerm2, LZKurt: Double;
  LK2: Double;
begin
  Result.Method := 'D''Agostino-Pearson K2';
  WelfordMeanVariance(FData, LMean, LVariance, LValidCount);

  if LValidCount < 8 then
  begin
    Result.IsNormal := True;
    Result.ApproximatePValue := 1.0;
    Result.TestStatistic := 0.0;
    Result.Method := 'Insufficient data (n<8)';
    Exit;
  end;

  { 有偏样本矩 m2/m3/m4（除以 n；与 Kurtosis 的 G2 口径刻意不同） }
  LSum2 := 0.0; LSum3 := 0.0; LSum4 := 0.0;
  for I := 0 to High(FData) do
  begin
    if IsDoubleNaN(FData[I]) or IsInfinite(FData[I]) then Continue;
    LDiff := FData[I] - LMean;
    LD2 := LDiff * LDiff;
    LSum2 := LSum2 + LD2;
    LSum3 := LSum3 + LD2 * LDiff;
    LSum4 := LSum4 + LD2 * LD2;
  end;
  if LSum2 = 0 then
  begin
    { 常数序列：矩检验无定义，按无证据拒绝处理 }
    Result.IsNormal := True;
    Result.ApproximatePValue := 1.0;
    Result.TestStatistic := 0.0;
    Exit;
  end;
  LM2 := LSum2 / LValidCount;
  LM3 := LSum3 / LValidCount;
  LM4 := LSum4 / LValidCount;
  LB1 := LM3 / Sqrt(LM2 * LM2 * LM2);
  LB2 := LM4 / (LM2 * LM2);

  { Z_skew: D'Agostino (1970)。Y = √b1 · sqrt((n+1)(n+3)/(6(n-2)))，
    Z = delta·asinh(Y/alpha)，带符号（n 整型算术全程提升为浮点防溢出） }
  LY := LB1 * Sqrt((LValidCount + 1.0) * (LValidCount + 3.0) /
    (6.0 * (LValidCount - 2.0)));
  LBeta2 := 3.0 * (Sqr(LValidCount + 0.0) + 27.0 * LValidCount - 70.0) *
    (LValidCount + 1.0) * (LValidCount + 3.0) /
    ((LValidCount - 2.0) * (LValidCount + 5.0) * (LValidCount + 7.0) *
     (LValidCount + 9.0));
  LWSq := -1.0 + Sqrt(2.0 * (LBeta2 - 1.0));
  { n>=8 时 β2(√b1)>3 → W²>1 → Ln(W²)>0 }
  LDelta := 1.0 / Sqrt(0.5 * Ln(LWSq));
  LAlpha := Sqrt(2.0 / (LWSq - 1.0));
  if LY <> 0 then
  begin
    LYA := LY / LAlpha;
    LZSkew := LDelta * Ln(LYA + Sqrt(LYA * LYA + 1.0));
  end
  else
    LZSkew := 0.0;

  { Z_kurt: Anscombe-Glynn (1983)。x = (b2 - E[b2])/sqrt(Var[b2])，
    Z = ((1-2/(9A)) - sign(denom)·cbrt((1-2/A)/|denom|)) / sqrt(2/(9A)) }
  LE := 3.0 * (LValidCount - 1.0) / (LValidCount + 1.0);
  LVarB2 := 24.0 * LValidCount * (LValidCount - 2.0) * (LValidCount - 3.0) /
    (Sqr(LValidCount + 1.0) * (LValidCount + 3.0) * (LValidCount + 5.0));
  LX := (LB2 - LE) / Sqrt(LVarB2);
  LSqrtB1 := 6.0 * (Sqr(LValidCount + 0.0) - 5.0 * LValidCount + 2.0) /
    ((LValidCount + 7.0) * (LValidCount + 9.0)) *
    Sqrt(6.0 * (LValidCount + 3.0) * (LValidCount + 5.0) /
      (LValidCount * (LValidCount - 2.0) * (LValidCount - 3.0)));
  LA := 6.0 + 8.0 / LSqrtB1 *
    (2.0 / LSqrtB1 + Sqrt(1.0 + 4.0 / Sqr(LSqrtB1)));
  LDenom := 1.0 + LX * Sqrt(2.0 / (LA - 4.0));
  if LDenom <> 0 then
  begin
    { n>=8 时 A>4 → cbrt 实参 (1-2/A)/|denom| > 0；cbrt 用 Exp(Ln/3) }
    LTerm2 := Exp(Ln((1.0 - 2.0 / LA) / Abs(LDenom)) / 3.0);
    if LDenom < 0 then
      LTerm2 := -LTerm2;
    LZKurt := ((1.0 - 2.0 / (9.0 * LA)) - LTerm2) / Sqrt(2.0 / (9.0 * LA));
  end
  else
    LZKurt := 0.0;

  LK2 := Sqr(LZSkew) + Sqr(LZKurt);
  Result.TestStatistic := LK2;
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
  LValidCount: Integer;
begin
  if Length(AData) = 0 then begin AMean := 0; AVariance := 0; Exit; end;
  WelfordMeanVariance(AData, AMean, AVariance, LValidCount);
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

  { compute mean + variance of AOther in a single pass }
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

  { compute mean + variance of AOther in a single pass }
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
