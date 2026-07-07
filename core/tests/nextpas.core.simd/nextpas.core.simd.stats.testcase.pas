{
   nextpas.core.simd.stats.testcase - Statistics 单元专用测试
   覆盖加权统计、协方差、相关性、百分位、直方图等
}
unit nextpas.core.simd.stats.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  nextpas.core.test, nextpas.core.simd.stats;

{$M+}
type
  TTestCase_SimdStats = class(TTestFixture)
  published
    procedure Test_WeightedSum_Basic;
    procedure Test_WeightedMean_Basic;
    procedure Test_Covariance_Basic;
    procedure Test_Correlation_Perfect;
    procedure Test_Correlation_Negative;
    procedure Test_Variance_Sample;
    procedure Test_Variance_Population;
    procedure Test_StdDev_Basic;
    procedure Test_Percentile_Basic;
    procedure Test_Median_Basic;
    procedure Test_MovingAverage_Basic;
    procedure Test_ExponentialMovingAverage_Basic;
    procedure Test_MinMaxNormalize_Basic;
    procedure Test_ZScoreNormalize_Basic;
    procedure Test_CosineSimilarity_Same;
    procedure Test_CosineSimilarity_Orthogonal;
    procedure Test_Histogram_Basic;
    procedure Test_OnlineStats_Add;
    procedure Test_OnlineStats_Batch;
    procedure Test_OnlineStats_Merge;
    // F64 variants
    procedure Test_VarianceF64_Basic;
    procedure Test_StdDevF64_Basic;
    procedure Test_CovarianceF64_Basic;
    procedure Test_CorrelationF64_Perfect;
    procedure Test_CosineSimilarityF64_Same;
    procedure Test_WeightedSumF64_Basic;
    procedure Test_WeightedMeanF64_Basic;
    procedure Test_MinMaxNormalizeF64_Basic;
    procedure Test_ZScoreNormalizeF64_Basic;
    procedure Test_NilSafety;
  end;

implementation

const
  EPS = 1E-4;

function NearEqual(A, B, AEps: Single): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

function NearEqualF64(A, B, AEps: Double): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

{ ============================================================================
  Weighted Operations
  ============================================================================ }

procedure TTestCase_SimdStats.Test_WeightedSum_Basic;
var
  LValues: array[0..2] of Single = (1.0, 2.0, 3.0);
  LWeights: array[0..2] of Single = (1.0, 1.0, 1.0);
begin
  // sum(1*1, 2*1, 3*1) = 6
  CheckTrue(NearEqual(WeightedSumF32(@LValues[0], @LWeights[0], 3), 6.0, EPS), 'WeightedSum uniform');
end;

procedure TTestCase_SimdStats.Test_WeightedMean_Basic;
var
  LValues: array[0..2] of Single = (1.0, 2.0, 3.0);
  LWeights: array[0..2] of Single = (1.0, 2.0, 1.0);
begin
  // mean = (1*1 + 2*2 + 3*1) / (1+2+1) = 8/4 = 2
  CheckTrue(NearEqual(WeightedMeanF32(@LValues[0], @LWeights[0], 3), 2.0, EPS), 'WeightedMean');
end;

{ ============================================================================
  Covariance / Correlation
  ============================================================================ }

procedure TTestCase_SimdStats.Test_Covariance_Basic;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Single = (2.0, 4.0, 6.0, 8.0);
begin
  // Perfect linear relationship, covariance should be positive
  CheckTrue(CovarianceF32(@LX[0], @LY[0], 4) > 0.0, 'Covariance positive');
end;

procedure TTestCase_SimdStats.Test_Correlation_Perfect;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Single = (2.0, 4.0, 6.0, 8.0);
begin
  // Perfect linear: y = 2x, correlation = 1.0
  CheckTrue(NearEqual(CorrelationF32(@LX[0], @LY[0], 4), 1.0, EPS), 'Perfect correlation');
end;

procedure TTestCase_SimdStats.Test_Correlation_Negative;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Single = (8.0, 6.0, 4.0, 2.0);
begin
  // Perfect negative linear: correlation = -1.0
  CheckTrue(NearEqual(CorrelationF32(@LX[0], @LY[0], 4), -1.0, EPS), 'Negative correlation');
end;

{ ============================================================================
  Variance / StdDev
  ============================================================================ }

procedure TTestCase_SimdStats.Test_Variance_Sample;
var
  LSrc: array[0..7] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
begin
  // Sample variance (N-1) of [1..8] = 6.0
  CheckTrue(NearEqual(VarianceF32(@LSrc[0], 8, True), 6.0, EPS), 'Sample variance');
end;

procedure TTestCase_SimdStats.Test_Variance_Population;
var
  LSrc: array[0..7] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
begin
  // Population variance (N) of [1..8] = 5.25
  CheckTrue(NearEqual(VarianceF32(@LSrc[0], 8, False), 5.25, EPS), 'Population variance');
end;

procedure TTestCase_SimdStats.Test_StdDev_Basic;
var
  LSrc: array[0..7] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
begin
  // StdDev = sqrt(6.0) ~ 2.4495
  CheckTrue(NearEqual(StdDevF32(@LSrc[0], 8, True), 2.4495, 0.001), 'StdDev');
end;

{ ============================================================================
  Percentile / Median
  ============================================================================ }

procedure TTestCase_SimdStats.Test_Percentile_Basic;
var
  LSrc: array[0..9] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0);
begin
  // P50 of [1..10] should be ~5.5
  CheckTrue(NearEqual(PercentileF32(@LSrc[0], 10, 50.0), 5.5, 0.5), 'P50');
end;

procedure TTestCase_SimdStats.Test_Median_Basic;
var
  LSrc: array[0..4] of Single = (5.0, 1.0, 3.0, 2.0, 4.0);
begin
  // Median of [1,2,3,4,5] = 3
  CheckTrue(NearEqual(MedianF32(@LSrc[0], 5), 3.0, EPS), 'Median');
end;

{ ============================================================================
  Moving Average
  ============================================================================ }

procedure TTestCase_SimdStats.Test_MovingAverage_Basic;
var
  LSrc: array[0..4] of Single = (1.0, 2.0, 3.0, 4.0, 5.0);
  LDst: array[0..4] of Single;
begin
  CheckTrue(MovingAverageF32(@LSrc[0], @LDst[0], 5, 3), 'MA returns true');
  // First values should be smoothed
  CheckTrue(LDst[2] > LDst[0], 'MA smoothing');
end;

procedure TTestCase_SimdStats.Test_ExponentialMovingAverage_Basic;
var
  LSrc: array[0..4] of Single = (1.0, 2.0, 3.0, 4.0, 5.0);
  LDst: array[0..4] of Single;
begin
  CheckTrue(ExponentialMovingAverageF32(@LSrc[0], @LDst[0], 5, 0.5), 'EMA returns true');
  // EMA should follow the trend
  CheckTrue(LDst[4] > LDst[0], 'EMA follows trend');
end;

{ ============================================================================
  Normalization
  ============================================================================ }

procedure TTestCase_SimdStats.Test_MinMaxNormalize_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
begin
  CheckTrue(MinMaxNormalizeF32(@LSrc[0], @LDst[0], 4), 'MinMaxNorm returns true');
  // Should map to [0, 1]
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'MinMaxNorm min=0');
  CheckTrue(NearEqual(LDst[3], 1.0, EPS), 'MinMaxNorm max=1');
end;

procedure TTestCase_SimdStats.Test_ZScoreNormalize_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
  LSum: Single;
  I: Integer;
begin
  CheckTrue(ZScoreNormalizeF32(@LSrc[0], @LDst[0], 4), 'ZScore returns true');
  // Z-score normalized data should have mean ~0
  LSum := 0.0;
  for I := 0 to 3 do
    LSum := LSum + LDst[I];
  CheckTrue(NearEqual(LSum, 0.0, EPS), 'ZScore mean=0');
end;

{ ============================================================================
  Cosine Similarity
  ============================================================================ }

procedure TTestCase_SimdStats.Test_CosineSimilarity_Same;
var
  LX: array[0..2] of Single = (1.0, 2.0, 3.0);
begin
  // cos(x, x) = 1.0
  CheckTrue(NearEqual(CosineSimilarityF32(@LX[0], @LX[0], 3), 1.0, EPS), 'CosSim same=1');
end;

procedure TTestCase_SimdStats.Test_CosineSimilarity_Orthogonal;
var
  LX: array[0..1] of Single = (1.0, 0.0);
  LY: array[0..1] of Single = (0.0, 1.0);
begin
  // cos(orthogonal) = 0
  CheckTrue(NearEqual(CosineSimilarityF32(@LX[0], @LY[0], 2), 0.0, EPS), 'CosSim orthogonal=0');
end;

{ ============================================================================
  Histogram
  ============================================================================ }

procedure TTestCase_SimdStats.Test_Histogram_Basic;
var
  LSrc: array[0..5] of Single = (0.5, 1.5, 2.5, 0.7, 1.8, 2.1);
  LBins: array[0..2] of Single = (0.0, 1.0, 2.0);
  LCounts: array[0..2] of Int32;
begin
  HistogramF32(@LSrc[0], 6, @LBins[0], @LCounts[0], 3, 0.0, 3.0);
  // Should have counts in each bin
  CheckTrue(LCounts[0] + LCounts[1] + LCounts[2] = 6, 'Histogram total=6');
end;

{ ============================================================================
  OnlineStats (Welford)
  ============================================================================ }

procedure TTestCase_SimdStats.Test_OnlineStats_Add;
var
  LStats: TSimdF32OnlineStats;
begin
  LStats.Clear;
  LStats.Add(2.0);
  LStats.Add(4.0);
  LStats.Add(4.0);
  LStats.Add(4.0);
  LStats.Add(5.0);
  LStats.Add(5.0);
  LStats.Add(7.0);
  LStats.Add(9.0);
  // Mean = 5.0, Variance = 32/7 ~ 4.571 (sample, N-1)
  CheckTrue(NearEqual(LStats.GetMean, 5.0, EPS), 'OnlineStats mean=5');
  CheckTrue(NearEqual(LStats.GetVariance, 32.0/7.0, 0.1), 'OnlineStats var=32/7');
  CheckTrue(NearEqual(LStats.GetStdDev, System.Sqrt(32.0/7.0), 0.1), 'OnlineStats stddev');
end;

procedure TTestCase_SimdStats.Test_OnlineStats_Batch;
var
  LStats: TSimdF32OnlineStats;
  LData: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
begin
  LStats.Clear;
  LStats.AddBatch(@LData[0], 4);
  // Mean = 2.5, Variance = 5/3 ~ 1.667
  CheckTrue(NearEqual(LStats.GetMean, 2.5, EPS), 'OnlineStats batch mean');
  CheckTrue(NearEqual(LStats.GetVariance, 5.0/3.0, 0.1), 'OnlineStats batch var');
end;

procedure TTestCase_SimdStats.Test_OnlineStats_Merge;
var
  LA, LB, LMerged: TSimdF32OnlineStats;
  LDataA: array[0..1] of Single = (1.0, 3.0);
  LDataB: array[0..1] of Single = (5.0, 7.0);
begin
  LA.Clear;
  LA.AddBatch(@LDataA[0], 2);
  LB.Clear;
  LB.AddBatch(@LDataB[0], 2);
  LMerged.Clear;
  LMerged.Merge(LA);
  LMerged.Merge(LB);
  // Combined: [1,3,5,7], mean=4, var=20/3
  CheckTrue(NearEqual(LMerged.GetMean, 4.0, EPS), 'OnlineStats merge mean');
  CheckTrue(NearEqual(LMerged.GetVariance, 20.0/3.0, 0.1), 'OnlineStats merge var');
end;

{ ============================================================================
  F64 Statistics
  ============================================================================ }

procedure TTestCase_SimdStats.Test_VarianceF64_Basic;
var
  LData: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
begin
  // Sample variance of [1,2,3,4] = 5/3 ≈ 1.6667
  CheckTrue(NearEqualF64(VarianceF64(@LData[0], 4, True), 5.0/3.0, 0.001), 'VarianceF64 sample');
  // Population variance = 5/4 = 1.25
  CheckTrue(NearEqualF64(VarianceF64(@LData[0], 4, False), 1.25, 0.001), 'VarianceF64 population');
end;

procedure TTestCase_SimdStats.Test_StdDevF64_Basic;
var
  LData: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
begin
  // Sample std dev = sqrt(5/3) ≈ 1.2910
  CheckTrue(NearEqualF64(StdDevF64(@LData[0], 4, True), System.Sqrt(5.0/3.0), 0.001), 'StdDevF64 sample');
end;

procedure TTestCase_SimdStats.Test_CovarianceF64_Basic;
var
  LX: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Double = (2.0, 4.0, 6.0, 8.0);
begin
  // Y = 2*X, so covariance = 2 * var(X) = 2 * 5/3 ≈ 3.3333
  CheckTrue(NearEqualF64(CovarianceF64(@LX[0], @LY[0], 4, True), 10.0/3.0, 0.001), 'CovarianceF64');
end;

procedure TTestCase_SimdStats.Test_CorrelationF64_Perfect;
var
  LX: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Double = (2.0, 4.0, 6.0, 8.0);
begin
  // Y = 2*X, perfect positive correlation = 1.0
  CheckTrue(NearEqualF64(CorrelationF64(@LX[0], @LY[0], 4), 1.0, 0.001), 'CorrelationF64 perfect');
end;

procedure TTestCase_SimdStats.Test_CosineSimilarityF64_Same;
var
  LX: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
begin
  // Same vector, cosine similarity = 1.0
  CheckTrue(NearEqualF64(CosineSimilarityF64(@LX[0], @LX[0], 4), 1.0, 0.001), 'CosineSimF64 same');
end;

procedure TTestCase_SimdStats.Test_WeightedSumF64_Basic;
var
  LValues: array[0..2] of Double = (1.0, 2.0, 3.0);
  LWeights: array[0..2] of Double = (0.5, 0.3, 0.2);
begin
  // 1*0.5 + 2*0.3 + 3*0.2 = 0.5 + 0.6 + 0.6 = 1.7
  CheckTrue(NearEqualF64(WeightedSumF64(@LValues[0], @LWeights[0], 3), 1.7, 0.001), 'WeightedSumF64');
end;

procedure TTestCase_SimdStats.Test_WeightedMeanF64_Basic;
var
  LValues: array[0..2] of Double = (1.0, 2.0, 3.0);
  LWeights: array[0..2] of Double = (0.5, 0.3, 0.2);
begin
  // 1.7 / 1.0 = 1.7
  CheckTrue(NearEqualF64(WeightedMeanF64(@LValues[0], @LWeights[0], 3), 1.7, 0.001), 'WeightedMeanF64');
end;

procedure TTestCase_SimdStats.Test_MinMaxNormalizeF64_Basic;
var
  LSrc: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Double;
begin
  MinMaxNormalizeF64(@LSrc[0], @LDst[0], 4);
  // Should map to [0, 1/3, 2/3, 1]
  CheckTrue(NearEqualF64(LDst[0], 0.0, 0.001), 'MinMaxNormF64 [0]');
  CheckTrue(NearEqualF64(LDst[3], 1.0, 0.001), 'MinMaxNormF64 [3]');
end;

procedure TTestCase_SimdStats.Test_ZScoreNormalizeF64_Basic;
var
  LSrc: array[0..3] of Double = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Double;
  LMean: Double;
  I: Integer;
begin
  ZScoreNormalizeF64(@LSrc[0], @LDst[0], 4);
  // Output should be zero-mean
  LMean := 0.0;
  for I := 0 to 3 do LMean := LMean + LDst[I];
  LMean := LMean / 4.0;
  CheckTrue(NearEqualF64(LMean, 0.0, 0.001), 'ZScoreNormF64 mean=0');
end;

{ ============================================================================
  Edge Cases
  ============================================================================ }

procedure TTestCase_SimdStats.Test_NilSafety;
begin
  // Should not crash on nil with count=0
  CheckTrue(NearEqual(WeightedSumF32(nil, nil, 0), 0.0, EPS), 'Nil WeightedSum');
  CheckTrue(NearEqual(VarianceF32(nil, 0, True), 0.0, EPS), 'Nil Variance');
  CheckTrue(True, 'Nil safety passed');
end;

end.
