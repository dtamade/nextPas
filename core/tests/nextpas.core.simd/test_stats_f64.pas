program test_stats_f64;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.stats;

var
  LPass, LFail: Integer;

procedure Check(const aName: string; aGot, aExpect: Double; aTol: Double = 1e-10);
begin
  if System.Abs(aGot - aExpect) <= aTol then Inc(LPass)
  else begin WriteLn('  FAIL ', aName, ': got=', aGot:0:15, ' expect=', aExpect:0:15); Inc(LFail); end;
end;

var
  X, Y, W: array[0..7] of Double;
  i: Integer;
  LMeanX, LMeanY, LVar, LCov: Double;
begin
  LPass := 0;
  LFail := 0;

  for i := 0 to 7 do X[i] := i + 1.0;
  for i := 0 to 7 do Y[i] := (i + 1.0) * 2.0;
  for i := 0 to 7 do W[i] := 1.0;

  // WeightedSum: uniform weights = sum
  Check('WeightedSum', WeightedSumF64(@X[0], @W[0], 8), 36.0);

  // WeightedMean: uniform weights = mean
  Check('WeightedMean', WeightedMeanF64(@X[0], @W[0], 8), 4.5);

  // Variance (population)
  LMeanX := 4.5;
  LVar := 0;
  for i := 0 to 7 do LVar := LVar + (X[i] - LMeanX) * (X[i] - LMeanX);
  LVar := LVar / 8;
  Check('Variance_pop', VarianceF64(@X[0], 8, False), LVar);

  // Variance (sample)
  LVar := 0;
  for i := 0 to 7 do LVar := LVar + (X[i] - LMeanX) * (X[i] - LMeanX);
  LVar := LVar / 7;
  Check('Variance_sample', VarianceF64(@X[0], 8, True), LVar);

  // StdDev
  Check('StdDev', StdDevF64(@X[0], 8, True), System.Sqrt(LVar));

  // Covariance: X and 2*X should have cov = 2*var(X)
  LCov := 0;
  LMeanY := 9.0;
  for i := 0 to 7 do LCov := LCov + (X[i] - LMeanX) * (Y[i] - LMeanY);
  LCov := LCov / 7;
  Check('Covariance', CovarianceF64(@X[0], @Y[0], 8, True), LCov);

  // Correlation: X and 2*X should have correlation = 1.0
  Check('Correlation_perfect', CorrelationF64(@X[0], @Y[0], 8), 1.0, 1e-9);

  // Correlation: X and -X should have correlation = -1.0
  for i := 0 to 7 do Y[i] := -(i + 1.0);
  Check('Correlation_neg', CorrelationF64(@X[0], @Y[0], 8), -1.0, 1e-9);

  // CosineSimilarity: same vector = 1.0
  Check('CosSim_same', CosineSimilarityF64(@X[0], @X[0], 8), 1.0, 1e-9);

  // CosineSimilarity: orthogonal
  X[0] := 1; X[1] := 0; X[2] := 0; X[3] := 0;
  Y[0] := 0; Y[1] := 1; Y[2] := 0; Y[3] := 0;
  Check('CosSim_ortho', CosineSimilarityF64(@X[0], @Y[0], 4), 0.0, 1e-9);

  // Edge cases
  Check('Variance_n1', VarianceF64(@X[0], 1, True), 0.0);
  Check('Correlation_n1', CorrelationF64(@X[0], @Y[0], 1), 0.0);

  // MinMaxNormalize
  for i := 0 to 7 do X[i] := i * 10.0;  // 0, 10, 20, ..., 70
  MinMaxNormalizeF64(@X[0], @Y[0], 8);
  Check('MinMax[0]=0', Y[0], 0.0);
  Check('MinMax[7]=1', Y[7], 1.0);
  Check('MinMax[4]=4/7', Y[4], Double(4) / Double(7), 1e-10);

  // ZScoreNormalize
  for i := 0 to 7 do X[i] := i + 1.0;
  ZScoreNormalizeF64(@X[0], @Y[0], 8);
  // After z-score: mean should be ~0, std should be ~1
  LMeanX := 0;
  for i := 0 to 7 do LMeanX := LMeanX + Y[i];
  LMeanX := LMeanX / 8;
  Check('ZScore mean~0', LMeanX, 0.0, 1e-10);
  LVar := 0;
  for i := 0 to 7 do LVar := LVar + Y[i] * Y[i];
  LVar := LVar / 8;
  Check('ZScore var~1', LVar, 1.0, 1e-6);

  // MinMaxNormalize: constant input → all zeros
  for i := 0 to 7 do X[i] := 5.0;
  MinMaxNormalizeF64(@X[0], @Y[0], 8);
  Check('MinMax_const', Y[0], 0.0);

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then WriteLn('All tests passed!')
  else Halt(1);
end.
