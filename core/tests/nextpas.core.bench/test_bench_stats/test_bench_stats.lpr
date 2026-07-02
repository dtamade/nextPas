program test_bench_stats;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math.scalar,
  nextpas.core.math.impl.scalar,
  nextpas.core.text.conv,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

var
  GAnalyzer: IBenchStatsAnalyzer;

function MakePositiveInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeNegativeInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($FFF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

{ Helper: returns True if the call completes without segfault/hang.
  An exception from the stats function is acceptable (valid "no crash" outcome). }
function SurvivesCall(AFunc: Pointer): Boolean;
begin
  Result := True;
  try
    TProcedure(AFunc)();
  except
    // Exception is acceptable -- the function detected bad input
    // and raised rather than crashing. This is a pass.
  end;
end;

procedure TestMean;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 0);
  CheckNear(0.0, GAnalyzer.Mean(LData), 0.001, 'Empty array returns 0');
  SetLength(LData, 1); LData[0] := 5.0;
  CheckNear(5.0, GAnalyzer.Mean(LData), 0.001, 'Single value returns that value');
  SetLength(LData, 5); LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0; LData[4] := 5.0;
  CheckNear(3.0, GAnalyzer.Mean(LData), 0.001, 'Multiple values correct mean');
  SetLength(LData, 3); LData[0] := 1e15; LData[1] := 1.0; LData[2] := -1e15;
  CheckNear(1.0/3.0, GAnalyzer.Mean(LData), 0.001, 'Kahan sum precision');
end;

procedure TestMedian;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 5); LData[0] := 1.0; LData[1] := 3.0; LData[2] := 2.0; LData[3] := 5.0; LData[4] := 4.0;
  CheckNear(3.0, GAnalyzer.Median(LData), 0.001, 'Odd count returns middle');
  SetLength(LData, 4); LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0;
  CheckNear(2.5, GAnalyzer.Median(LData), 0.001, 'Even count returns average');
  SetLength(LData, 0);
  CheckNear(0.0, GAnalyzer.Median(LData), 0.001, 'Empty array returns 0');
end;

procedure TestStdDev;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 3); LData[0] := 5.0; LData[1] := 5.0; LData[2] := 5.0;
  CheckNear(0.0, GAnalyzer.StdDev(LData), 0.001, 'Zero variance returns 0');
  SetLength(LData, 5); LData[0] := 2.0; LData[1] := 4.0; LData[2] := 4.0; LData[3] := 4.0; LData[4] := 5.0;
  CheckNear(1.09544511501033, GAnalyzer.StdDev(LData), 0.001, 'Known values correct stddev');
  SetLength(LData, 1); LData[0] := 10.0;
  CheckNear(0.0, GAnalyzer.StdDev(LData), 0.001, 'Single value returns 0');
end;

procedure TestPercentile;
var
  LSorted: TDoubleArray;
begin
  SetLength(LSorted, 10);
  LSorted[0] := 1.0; LSorted[1] := 2.0; LSorted[2] := 3.0; LSorted[3] := 4.0; LSorted[4] := 5.0;
  LSorted[5] := 6.0; LSorted[6] := 7.0; LSorted[7] := 8.0; LSorted[8] := 9.0; LSorted[9] := 10.0;
  CheckNear(1.0, GAnalyzer.Percentile(LSorted, 0), 0.001, 'P0 returns min');
  CheckNear(10.0, GAnalyzer.Percentile(LSorted, 100), 0.001, 'P100 returns max');
  CheckNear(5.5, GAnalyzer.Percentile(LSorted, 50), 0.001, 'P50 returns median');
  CheckNear(3.25, GAnalyzer.Percentile(LSorted, 25), 0.001, 'P25 correct');
  CheckNear(7.75, GAnalyzer.Percentile(LSorted, 75), 0.001, 'P75 correct');
  CheckNear(9.55, GAnalyzer.Percentile(LSorted, 95), 0.01, 'P95 correct');
  CheckNear(9.91, GAnalyzer.Percentile(LSorted, 99), 0.01, 'P99 correct');

  // TG-26: Single element Percentile
  SetLength(LSorted, 1);
  LSorted[0] := 42.0;
  CheckNear(42.0, GAnalyzer.Percentile(LSorted, 50), 0.001, 'Single element P50 = 42.0');
  CheckNear(42.0, GAnalyzer.Percentile(LSorted, 0), 0.001, 'Single element P0 = 42.0');
  CheckNear(42.0, GAnalyzer.Percentile(LSorted, 100), 0.001, 'Single element P100 = 42.0');

  // TG-26: Two element Percentile
  SetLength(LSorted, 2);
  LSorted[0] := 10.0; LSorted[1] := 20.0;
  CheckNear(10.0, GAnalyzer.Percentile(LSorted, 0), 0.001, 'Two element P0 = 10.0');
  CheckNear(15.0, GAnalyzer.Percentile(LSorted, 50), 0.001, 'Two element P50 = 15.0');
  CheckNear(20.0, GAnalyzer.Percentile(LSorted, 100), 0.001, 'Two element P100 = 20.0');
end;

procedure TestOutliers;
var
  LSorted: TDoubleArray;
begin
  SetLength(LSorted, 10);
  LSorted[0] := 1.0; LSorted[1] := 2.0; LSorted[2] := 3.0; LSorted[3] := 4.0; LSorted[4] := 5.0;
  LSorted[5] := 6.0; LSorted[6] := 7.0; LSorted[7] := 8.0; LSorted[8] := 9.0; LSorted[9] := 10.0;
  Check(GAnalyzer.CountOutliers(LSorted, 3.25, 7.75, 1.5) = 0, 'No outliers detected');
  SetLength(LSorted, 10);
  LSorted[0] := -100.0; LSorted[1] := 2.0; LSorted[2] := 3.0; LSorted[3] := 4.0; LSorted[4] := 5.0;
  LSorted[5] := 6.0; LSorted[6] := 7.0; LSorted[7] := 8.0; LSorted[8] := 9.0; LSorted[9] := 100.0;
  Check(GAnalyzer.CountOutliers(LSorted, 3.25, 7.75, 1.5) = 2, 'Some outliers detected');
  SetLength(LSorted, 3); LSorted[0] := -1000.0; LSorted[1] := 0.0; LSorted[2] := 1000.0;
  Check(GAnalyzer.CountOutliers(LSorted, 0.0, 0.0, 1.5) = 2, 'All outliers detected');
end;

procedure TestComputeStats;
var
  LSamples: TDoubleArray;
  LStats: TBenchStats;
  i: Integer;
begin
  RandSeed := 42;
  SetLength(LSamples, 100);
  for i := 0 to 99 do LSamples[i] := 100.0 + Random * 10.0;
  LStats := GAnalyzer.ComputeStats(LSamples);
  Check(LStats.SampleCount = 100, 'Sample count correct');
  Check(LStats.Mean > 99.0, 'Mean > 99');
  Check(LStats.Mean < 111.0, 'Mean < 111');
  Check(LStats.StdDev > 0, 'StdDev > 0');
  Check(LStats.StdDev < 5.0, 'StdDev < 5');
  Check(LStats.Median > 99.0, 'Median > 99');
  Check(LStats.Median < 111.0, 'Median < 111');
  Check(LStats.Min >= 100.0, 'Min >= 100');
  Check(LStats.Max <= 110.0, 'Max <= 110');
  Check(LStats.P5 < LStats.P25, 'P5 < P25');
  Check(LStats.P25 < LStats.Median, 'P25 < Median');
  Check(LStats.Median < LStats.P75, 'Median < P75');
  Check(LStats.P75 < LStats.P95, 'P75 < P95');
  Check(LStats.P95 < LStats.P99, 'P95 < P99');
  Check(LStats.IQR > 0, 'IQR > 0');
  Check(LStats.Confidence95Low < LStats.Mean, 'CI95 low < mean');
  Check(LStats.Confidence95High > LStats.Mean, 'CI95 high > mean');
  Check(LStats.Confidence99Low < LStats.Confidence95Low, 'CI99 low < CI95 low');
  Check(LStats.Confidence99High > LStats.Confidence95High, 'CI99 high > CI95 high');
end;

procedure TestSignificantDifference;
var
  LA, LB: TDoubleArray;
  LStatsA, LStatsB: TBenchStats;
  i: Integer;
begin
  { TG-17: use large sample (1000+) with fixed seed to reduce false positives }
  RandSeed := 42;
  SetLength(LA, 1000); SetLength(LB, 1000);
  for i := 0 to 999 do begin LA[i] := 100.0 + Random * 10.0; LB[i] := 100.0 + Random * 10.0; end;
  LStatsA := GAnalyzer.ComputeStats(LA); LStatsB := GAnalyzer.ComputeStats(LB);
  Check(not GAnalyzer.HasHeuristicDifference(LStatsA, LStatsB), 'Same distribution no heuristic difference');
  SetLength(LA, 1000); SetLength(LB, 1000);
  for i := 0 to 999 do begin LA[i] := 100.0 + Random * 10.0; LB[i] := 200.0 + Random * 10.0; end;
  LStatsA := GAnalyzer.ComputeStats(LA); LStatsB := GAnalyzer.ComputeStats(LB);
  Check(GAnalyzer.HasHeuristicDifference(LStatsA, LStatsB), 'Different distribution heuristic difference');
end;

procedure TestTInvLookup;
var
  LSamples: TDoubleArray;
  LStats: TBenchStats;
  LCIWidth: Double;
  I: Integer;
begin
  SetLength(LSamples, 5);
  LSamples[0] := 1.0; LSamples[1] := 2.0; LSamples[2] := 3.0; LSamples[3] := 4.0; LSamples[4] := 5.0;
  LStats := GAnalyzer.ComputeStats(LSamples);
  LCIWidth := LStats.Confidence95High - LStats.Confidence95Low;
  CheckNear(3.926, LCIWidth, 0.15, 'DF=4 uses lookup-table CI width');
  Check(LStats.Confidence95Low < LStats.Mean, 'CI95 low < mean');
  Check(LStats.Confidence95High > LStats.Mean, 'CI95 high > mean');
  SetLength(LSamples, 30);
  for I := 0 to 29 do LSamples[I] := 100.0 + I;
  LStats := GAnalyzer.ComputeStats(LSamples);
  Check(LStats.SampleCount = 30, 'TInv sample count = 30');
  Check(LStats.Confidence95Low < LStats.Mean, 'TInv 30-samples CI95 low < mean');
  Check(LStats.Confidence95High > LStats.Mean, 'TInv 30-samples CI95 high > mean');
  SetLength(LSamples, 1); LSamples[0] := 42.0;
  LStats := GAnalyzer.ComputeStats(LSamples);
  Check(LStats.Confidence95Low = 42.0, 'Single sample CI95 low = mean');
  Check(LStats.Confidence95High = 42.0, 'Single sample CI95 high = mean');
end;

procedure TestIsNormal;
var
  LData: TDoubleArray;
  LIsNormal: Boolean;
  i: Integer;
begin
  RandSeed := 42; { TG-16: fixed seed for deterministic test data }
  SetLength(LData, 1000);
  for i := 0 to 999 do LData[i] := 100.0 + Random * 10.0 + Random * 10.0;
  Check(GAnalyzer.LooksNormalHeuristic(LData), 'Normal-like data passes heuristic check');

  { Negative case: bimodal distribution should be rejected after W normalization fix }
  for i := 0 to 499 do LData[i] := 0.0;
  for i := 500 to 999 do LData[i] := 100.0;
  LIsNormal := GAnalyzer.LooksNormalHeuristic(LData);
  Check(not LIsNormal, 'Bimodal distribution: LooksNormalHeuristic returns False');

  { Exponential distribution should also be rejected }
  for i := 0 to 999 do LData[i] := Exp(i * 0.01);
  LIsNormal := GAnalyzer.LooksNormalHeuristic(LData);
  Check(not LIsNormal, 'Exponential distribution: LooksNormalHeuristic returns False');
end;

procedure TestComputeApproximatePValue;
var
  LA, LB: TDoubleArray;
  LStatsA, LStatsB: TBenchStats;
  LPValue: Double;
  i: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 100); SetLength(LB, 100);
  for i := 0 to 99 do begin LA[i] := 100.0 + Random * 10.0; LB[i] := 100.0 + Random * 10.0; end;
  LStatsA := GAnalyzer.ComputeStats(LA); LStatsB := GAnalyzer.ComputeStats(LB);
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue >= 0.0, 'Same distribution p-value >= 0');
  Check(LPValue <= 1.0, 'Same distribution p-value <= 1');
  Check(LPValue > 0.05, 'Same distribution p-value > 0.05 (not significant)');
  SetLength(LA, 100); SetLength(LB, 100);
  for i := 0 to 99 do begin LA[i] := 100.0 + Random * 2.0; LB[i] := 200.0 + Random * 2.0; end;
  LStatsA := GAnalyzer.ComputeStats(LA); LStatsB := GAnalyzer.ComputeStats(LB);
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue >= 0.0, 'Different distribution p-value >= 0');
  Check(LPValue <= 1.0, 'Different distribution p-value <= 1');
  Check(LPValue < 0.05, 'Different distribution p-value < 0.05 (significant)');
  SetLength(LA, 50);
  for i := 0 to 49 do LA[i] := 100.0;
  LStatsA := GAnalyzer.ComputeStats(LA); LStatsB := LStatsA;
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue = 1.0, 'Identical data p-value = 1.0');
  LStatsA.Mean := 0.0; LStatsA.StdDev := 1.0; LStatsA.SampleCount := 10;
  LStatsB := LStatsA; LStatsB.Mean := 0.5;
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue > 0.2, 'Controlled t~1.118 p-value > 0.2');
  Check(LPValue < 0.35, 'Controlled t~1.118 p-value < 0.35');
end;

procedure TestSort;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 5);
  LData[0] := 5.0; LData[1] := 3.0; LData[2] := 1.0; LData[3] := 4.0; LData[4] := 2.0;
  SortDoubleArray(LData);
  CheckNear(1.0, LData[0], 0.001, 'Sort[0] = 1.0');
  CheckNear(2.0, LData[1], 0.001, 'Sort[1] = 2.0');
  CheckNear(3.0, LData[2], 0.001, 'Sort[2] = 3.0');
  CheckNear(4.0, LData[3], 0.001, 'Sort[3] = 4.0');
  CheckNear(5.0, LData[4], 0.001, 'Sort[4] = 5.0');
end;

procedure TestSort_EmptyArray;
var
  LData: TDoubleArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  SetLength(LData, 0);
  try
    SortDoubleArray(LData);
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Sort empty array does not crash');
  Check(Length(LData) = 0, 'Empty array remains length 0');
end;

procedure TestSort_SingleElement;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 1);
  LData[0] := 42.0;
  SortDoubleArray(LData);
  CheckNear(42.0, LData[0], 0.001, 'Single element unchanged');
end;

procedure TestSort_ReverseOrder;
var
  LData: TDoubleArray;
  i: Integer;
begin
  SetLength(LData, 10);
  for i := 0 to 9 do
    LData[i] := 10.0 - i;
  SortDoubleArray(LData);
  for i := 0 to 9 do
    CheckNear(i + 1, LData[i], 0.001, 'ReverseSort[' + IntToStr(i) + '] = ' + IntToStr(i + 1));
end;

procedure TestSort_AllEqual;
var
  LData: TDoubleArray;
  i: Integer;
begin
  SetLength(LData, 10);
  for i := 0 to 9 do
    LData[i] := 7.0;
  SortDoubleArray(LData);
  for i := 0 to 9 do
    CheckNear(7.0, LData[i], 0.001, 'AllEqual[' + IntToStr(i) + '] = 7.0');
end;

procedure TestSort_NaNMixed;
var
  LData: TDoubleArray;
begin
  { NaN should sort to the tail, non-NaN portion sorted normally }
  SetLength(LData, 6);
  LData[0] := 5.0; LData[1] := DoubleQuietNaN; LData[2] := 1.0;
  LData[3] := DoubleQuietNaN; LData[4] := 3.0; LData[5] := 2.0;
  SortDoubleArray(LData);
  CheckNear(1.0, LData[0], 0.001, 'NaN-mixed sort[0] = 1.0');
  CheckNear(2.0, LData[1], 0.001, 'NaN-mixed sort[1] = 2.0');
  CheckNear(3.0, LData[2], 0.001, 'NaN-mixed sort[2] = 3.0');
  CheckNear(5.0, LData[3], 0.001, 'NaN-mixed sort[3] = 5.0');
  Check(IsNan(LData[4]), 'NaN-mixed sort[4] = NaN');
  Check(IsNan(LData[5]), 'NaN-mixed sort[5] = NaN');
end;

procedure TestSort_AllNaN;
var
  LData: TDoubleArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  SetLength(LData, 4);
  LData[0] := DoubleQuietNaN; LData[1] := DoubleQuietNaN;
  LData[2] := DoubleQuietNaN; LData[3] := DoubleQuietNaN;
  try
    SortDoubleArray(LData);
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'All-NaN sort does not crash');
  Check(Length(LData) = 4, 'All-NaN array length preserved');
end;

procedure TestSort_NaNWithInfinity;
var
  LData: TDoubleArray;
begin
  { Infinity sorts normally, NaN sorts to tail }
  SetLength(LData, 4);
  LData[0] := DoubleQuietNaN; LData[1] := MakePositiveInfinity;
  LData[2] := 1.0; LData[3] := MakeNegativeInfinity;
  SortDoubleArray(LData);
  Check(LData[0] < 0, 'NaN+Inf sort[0] = -Inf (negative)');
  Check(not IsNan(LData[0]), 'NaN+Inf sort[0] is not NaN');
  CheckNear(1.0, LData[1], 0.001, 'NaN+Inf sort[1] = 1.0');
  Check(LData[2] > 1e100, 'NaN+Inf sort[2] = +Inf (very large)');
  Check(not IsNan(LData[2]), 'NaN+Inf sort[2] is not NaN');
  Check(IsNan(LData[3]), 'NaN+Inf sort[3] = NaN');
end;

procedure TestTInvLookup_KnownValues;
begin
  { df=10, p=0.05 (two-tailed 95%) => t ~ 2.228
    TInvLookup(10, TINV95_DATA, Z_SCORE_95) should return TINV95_DATA[9] = 2.228 }
  CheckNear(2.228, TInvLookup(10, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv 95% df=10 = 2.228');

  { df=5, p=0.05 => t ~ 2.571 }
  CheckNear(2.571, TInvLookup(5, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv 95% df=5 = 2.571');

  { df=1, p=0.05 => t ~ 12.706 }
  CheckNear(12.706, TInvLookup(1, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv 95% df=1 = 12.706');

  { df=10, p=0.01 (two-tailed 99%) => t ~ 3.169 }
  CheckNear(3.169, TInvLookup(10, TINV99_DATA, Z_SCORE_99), 0.001,
    'TInv 99% df=10 = 3.169');
end;

procedure TestTInvLookup_ExtremeDf;
begin
  { df < 1 should clamp to table[0] }
  CheckNear(12.706, TInvLookup(0.5, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv df=0.5 clamps to df=1');

  CheckNear(12.706, TInvLookup(0.1, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv df=0.1 clamps to df=1');

  { df >= 30 should converge to z-score }
  CheckNear(Z_SCORE_95, TInvLookup(30, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv df=30 = z-score 1.96');

  CheckNear(Z_SCORE_95, TInvLookup(100, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv df=100 = z-score 1.96');

  CheckNear(Z_SCORE_95, TInvLookup(1000, TINV95_DATA, Z_SCORE_95), 0.001,
    'TInv df=1000 = z-score 1.96');
end;

procedure TestMean_NaNInfinity;
var
  LData: TDoubleArray;
  LResult: Double;
  LNoCrash: Boolean;
begin
  SetLength(LData, 3);

  { NaN input: FPC propagates NaN through arithmetic }
  LData[0] := 1.0; LData[1] := DoubleQuietNaN; LData[2] := 3.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.Mean(LData);
    Check(IsNan(LResult), 'Mean with NaN input returns NaN');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Mean survives NaN input without crash');

  { +Inf input: result should be +Inf }
  LData[0] := 1.0; LData[1] := MakePositiveInfinity; LData[2] := 3.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.Mean(LData);
    Check(LResult > 1e300, 'Mean with +Inf input returns +Inf');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Mean survives +Inf input without crash');

  { -Inf input: result should be -Inf }
  LData[0] := 1.0; LData[1] := MakeNegativeInfinity; LData[2] := 3.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.Mean(LData);
    Check(LResult < -1e300, 'Mean with -Inf input returns -Inf');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Mean survives -Inf input without crash');
end;

procedure TestStdDev_NaNInfinity;
var
  LData: TDoubleArray;
  LResult: Double;
  LNoCrash: Boolean;
begin
  SetLength(LData, 3);

  { NaN input: StdDev should return NaN or 0 (not crash) }
  LData[0] := 1.0; LData[1] := DoubleQuietNaN; LData[2] := 3.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.StdDev(LData);
    { NaN propagation through Sqrt(Variance) }
    Check(IsNan(LResult) or (LResult >= 0), 'StdDev with NaN input returns NaN or non-negative');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'StdDev survives NaN input without crash');

  { +Inf input }
  LData[0] := 1.0; LData[1] := MakePositiveInfinity; LData[2] := 3.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.StdDev(LData);
    Check(LResult >= 0, 'StdDev with +Inf input returns non-negative or Inf');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'StdDev survives +Inf input without crash');
end;

procedure TestPercentile_NaNInfinity;
var
  LData: TDoubleArray;
  LResult: Double;
  LNoCrash: Boolean;
begin
  SetLength(LData, 5);

  { NaN in sorted position — Percentile should return some value or NaN }
  LData[0] := 1.0; LData[1] := 2.0; LData[2] := DoubleQuietNaN; LData[3] := 4.0; LData[4] := 5.0;
  LNoCrash := True;
  try
    LResult := GAnalyzer.Percentile(LData, 50);
    { NaN may be at any position in sorted order; result could be NaN or a valid value }
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Percentile survives NaN input without crash');

  { +Inf at end — Percentile(99) should return +Inf or a large value }
  LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0; LData[4] := MakePositiveInfinity;
  LNoCrash := True;
  try
    LResult := GAnalyzer.Percentile(LData, 99);
    Check(LResult > 3.0, 'Percentile(99) with +Inf at end > 3.0');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Percentile survives +Inf input without crash');
end;

procedure TestHasHeuristicDifferenceAt;
var
  LA, LB: TDoubleArray;
  LSa, LSb: TBenchStats;
  LI: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 100); SetLength(LB, 100);
  for LI := 0 to 99 do begin LA[LI] := 100.0 + Random * 10.0; LB[LI] := 200.0 + Random * 10.0; end;
  LSa := GAnalyzer.ComputeStats(LA); LSb := GAnalyzer.ComputeStats(LB);
  Check(GAnalyzer.HasHeuristicDifferenceAt(LSa, LSb, 0.05),
    'DS-04: alpha=0.05 detects large difference');
  Check(GAnalyzer.HasHeuristicDifferenceAt(LSa, LSb, 0.01),
    'DS-04: alpha=0.01 still detects large difference');

  RandSeed := 42;
  for LI := 0 to 99 do begin LA[LI] := 100.0 + Random * 10.0; LB[LI] := 100.0 + Random * 10.0; end;
  LSa := GAnalyzer.ComputeStats(LA); LSb := GAnalyzer.ComputeStats(LB);
  Check(not GAnalyzer.HasHeuristicDifferenceAt(LSa, LSb, 0.05),
    'DS-04: alpha=0.05 same distribution no difference');
end;

procedure TestGeometricMean;
var
  LRatios: TDoubleArray;
begin
  { 空数组返回 1.0 }
  SetLength(LRatios, 0);
  CheckNear(1.0, GAnalyzer.GeometricMean(LRatios), 0.001, 'Empty ratios returns 1.0');

  { 单元素返回该元素 }
  SetLength(LRatios, 1); LRatios[0] := 2.0;
  CheckNear(2.0, GAnalyzer.GeometricMean(LRatios), 0.001, 'Single ratio returns itself');

  { 经典例子: sqrt(1.2 * 0.8) = sqrt(0.96) = 0.9798 }
  SetLength(LRatios, 2); LRatios[0] := 1.2; LRatios[1] := 0.8;
  CheckNear(0.9798, GAnalyzer.GeometricMean(LRatios), 0.001,
    'Geometric mean of 1.2 and 0.8 = 0.9798');

  { 算术均值错误: (1.2 + 0.8) / 2 = 1.0 → 掩盖了实际的回归 }
  { 几何均值正确: 0.9798 < 1.0 → 检测到回归 }

  { 三个相同 ratio: geo mean = ratio }
  SetLength(LRatios, 3); LRatios[0] := 1.5; LRatios[1] := 1.5; LRatios[2] := 1.5;
  CheckNear(1.5, GAnalyzer.GeometricMean(LRatios), 0.001, 'Three identical ratios = ratio');

  { 1.0 表示无变化 }
  SetLength(LRatios, 5);
  LRatios[0] := 1.0; LRatios[1] := 1.0; LRatios[2] := 1.0;
  LRatios[3] := 1.0; LRatios[4] := 1.0;
  CheckNear(1.0, GAnalyzer.GeometricMean(LRatios), 0.001, 'All 1.0 = 1.0');

  { 非法 ratio (负数) 返回 0 }
  SetLength(LRatios, 2); LRatios[0] := 1.0; LRatios[1] := -0.5;
  CheckNear(0.0, GAnalyzer.GeometricMean(LRatios), 0.001, 'Negative ratio returns 0');
end;

procedure TestOLSRegression;
var
  LIters, LTimes: TDoubleArray;
  LResult: TOLSRegression;
  LStats: TBenchStatsAnalyzer;
begin
  LStats := TBenchStatsAnalyzer.Create;
  try
    { 线性关系: time = 100 + 50*N }
    SetLength(LIters, 5);
    SetLength(LTimes, 5);
    LIters[0] := 1;   LTimes[0] := 150;   { 100 + 50*1 }
    LIters[1] := 2;   LTimes[1] := 200;   { 100 + 50*2 }
    LIters[2] := 4;   LTimes[2] := 300;   { 100 + 50*4 }
    LIters[3] := 8;   LTimes[3] := 500;   { 100 + 50*8 }
    LIters[4] := 16;  LTimes[4] := 900;   { 100 + 50*16 }
    LResult := LStats.ComputeOLSRegression(LIters, LTimes);
    Check(LResult.Valid, 'OLS regression valid');
    CheckNear(50.0, LResult.Slope, 0.01, 'Slope = 50 ns/iter');
    CheckNear(100.0, LResult.Intercept, 0.01, 'Intercept = 100 ns overhead');
    Check(LResult.RSquared > 0.999, 'R² > 0.999 for perfect linear data');
  finally
    LStats.Free;
  end;
end;

procedure TestOLSRegression_InsufficientData;
var
  LIters, LTimes: TDoubleArray;
  LResult: TOLSRegression;
  LStats: TBenchStatsAnalyzer;
begin
  LStats := TBenchStatsAnalyzer.Create;
  try
    { 只有 1 个数据点 }
    SetLength(LIters, 1);
    SetLength(LTimes, 1);
    LIters[0] := 10;
    LTimes[0] := 100;
    LResult := LStats.ComputeOLSRegression(LIters, LTimes);
    Check(not LResult.Valid, 'Single point regression invalid');

    { 空数据 }
    SetLength(LIters, 0);
    SetLength(LTimes, 0);
    LResult := LStats.ComputeOLSRegression(LIters, LTimes);
    Check(not LResult.Valid, 'Empty data regression invalid');
  finally
    LStats.Free;
  end;
end;

procedure TestOLSRegression_PerfectFit;
var
  LIters, LTimes: TDoubleArray;
  LResult: TOLSRegression;
  LStats: TBenchStatsAnalyzer;
begin
  LStats := TBenchStatsAnalyzer.Create;
  try
    { 完美线性: time = 0 + 10*N (无固定开销) }
    SetLength(LIters, 4);
    SetLength(LTimes, 4);
    LIters[0] := 1;   LTimes[0] := 10;
    LIters[1] := 10;  LTimes[1] := 100;
    LIters[2] := 100; LTimes[2] := 1000;
    LIters[3] := 1000; LTimes[3] := 10000;
    LResult := LStats.ComputeOLSRegression(LIters, LTimes);
    Check(LResult.Valid, 'Perfect fit valid');
    CheckNear(10.0, LResult.Slope, 0.001, 'Slope = 10');
    CheckNear(0.0, LResult.Intercept, 0.001, 'Intercept = 0 (no overhead)');
    Check(LResult.RSquared > 0.9999, 'R² > 0.9999 for perfect data');
  finally
    LStats.Free;
  end;
end;

{ ---- SortIndirect: sort indices by data values ---- }

procedure TestSortIndirect_Basic;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I: Integer;
begin
  { Data: [50, 10, 40, 20, 30] => sorted indices: [1,3,4,2,0] }
  SetLength(LData, 5);
  LData[0] := 50.0; LData[1] := 10.0; LData[2] := 40.0; LData[3] := 20.0; LData[4] := 30.0;
  SetLength(LIndices, 5);
  for I := 0 to 4 do LIndices[I] := I;
  SortIndirect(LIndices, LData);
  { After sort: LIndices[i] is the original index of the i-th smallest value }
  Check(LIndices[0] = 1, 'SortIndirect[0] = 1 (value 10)');
  Check(LIndices[1] = 3, 'SortIndirect[1] = 3 (value 20)');
  Check(LIndices[2] = 4, 'SortIndirect[2] = 4 (value 30)');
  Check(LIndices[3] = 2, 'SortIndirect[3] = 2 (value 40)');
  Check(LIndices[4] = 0, 'SortIndirect[4] = 0 (value 50)');
  { Verify monotonicity: data[indices[i]] should be non-decreasing }
  for I := 0 to 3 do
    Check(LData[LIndices[I]] <= LData[LIndices[I + 1]],
      'SortIndirect monotonic[' + IntToStr(I) + ']');
end;

procedure TestSortIndirect_Empty;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  LNoCrash: Boolean;
begin
  SetLength(LData, 0);
  SetLength(LIndices, 0);
  LNoCrash := True;
  try
    SortIndirect(LIndices, LData);
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'SortIndirect empty does not crash');
  Check(Length(LIndices) = 0, 'SortIndirect empty length preserved');
end;

procedure TestSortIndirect_SingleElement;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
begin
  SetLength(LData, 1); LData[0] := 42.0;
  SetLength(LIndices, 1); LIndices[0] := 0;
  SortIndirect(LIndices, LData);
  Check(LIndices[0] = 0, 'SortIndirect single element index unchanged');
end;

procedure TestSortIndirect_AlreadySorted;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I: Integer;
begin
  SetLength(LData, 5);
  for I := 0 to 4 do LData[I] := I * 10.0;
  SetLength(LIndices, 5);
  for I := 0 to 4 do LIndices[I] := I;
  SortIndirect(LIndices, LData);
  for I := 0 to 4 do
    Check(LIndices[I] = I, 'SortIndirect already-sorted[' + IntToStr(I) + '] = ' + IntToStr(I));
end;

procedure TestSortIndirect_ReverseOrder;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I: Integer;
begin
  SetLength(LData, 10);
  for I := 0 to 9 do LData[I] := (9 - I) * 10.0;  { 90, 80, ... 0 }
  SetLength(LIndices, 10);
  for I := 0 to 9 do LIndices[I] := I;
  SortIndirect(LIndices, LData);
  { Smallest value (0) is at original index 9 }
  for I := 0 to 9 do
    Check(LIndices[I] = 9 - I, 'SortIndirect reverse[' + IntToStr(I) + '] = ' + IntToStr(9 - I));
end;

procedure TestSortIndirect_AllEqual;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I, J: Integer;
  LSorted: Boolean;
  LSeen: array[0..9] of Boolean;
begin
  SetLength(LData, 10);
  for I := 0 to 9 do LData[I] := 7.0;
  SetLength(LIndices, 10);
  for I := 0 to 9 do LIndices[I] := I;
  SortIndirect(LIndices, LData);
  { All equal => any permutation is valid; verify monotonicity (trivially true) }
  LSorted := True;
  for I := 0 to 8 do
    if LData[LIndices[I]] > LData[LIndices[I + 1]] then LSorted := False;
  Check(LSorted, 'SortIndirect all-equal maintains monotonicity');
  { Verify all indices are still present (no data loss) }
  for I := 0 to 9 do LSeen[I] := False;
  for I := 0 to 9 do LSeen[LIndices[I]] := True;
  for I := 0 to 9 do
    Check(LSeen[I], 'SortIndirect all-equal index ' + IntToStr(I) + ' preserved');
end;

procedure TestSortIndirect_LargeArray;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I: Integer;
  LSorted: Boolean;
  LSeen: array[0..999] of Boolean;
begin
  RandSeed := 42;
  SetLength(LData, 1000);
  SetLength(LIndices, 1000);
  for I := 0 to 999 do
  begin
    LData[I] := Random * 10000.0;
    LIndices[I] := I;
  end;
  SortIndirect(LIndices, LData);
  { Verify sorted order }
  LSorted := True;
  for I := 0 to 998 do
    if LData[LIndices[I]] > LData[LIndices[I + 1]] then LSorted := False;
  Check(LSorted, 'SortIndirect 1000 elements sorted correctly');
  { Verify permutation is valid (all indices present) }
  for I := 0 to 999 do LSeen[I] := False;
  for I := 0 to 999 do LSeen[LIndices[I]] := True;
  LSorted := True;
  for I := 0 to 999 do
    if not LSeen[I] then LSorted := False;
  Check(LSorted, 'SortIndirect 1000 elements: valid permutation');
end;

procedure TestSortIndirect_OddLength;
var
  LData: TDoubleArray;
  LIndices: TInt64Array;
  I: Integer;
begin
  { 7 elements — exercises odd-length path in MedianOfThree }
  SetLength(LData, 7);
  LData[0] := 70.0; LData[1] := 10.0; LData[2] := 50.0; LData[3] := 30.0;
  LData[4] := 60.0; LData[5] := 20.0; LData[6] := 40.0;
  SetLength(LIndices, 7);
  for I := 0 to 6 do LIndices[I] := I;
  SortIndirect(LIndices, LData);
  Check(LIndices[0] = 1, 'SortIndirect odd[0] = 1 (value 10)');
  Check(LIndices[6] = 0, 'SortIndirect odd[6] = 0 (value 70)');
  for I := 0 to 5 do
    Check(LData[LIndices[I]] <= LData[LIndices[I + 1]],
      'SortIndirect odd monotonic[' + IntToStr(I) + ']');
end;

procedure TestGlobMatch;
begin
  { 精确匹配 }
  Check(GlobMatch('Foo', 'Foo'), 'GlobMatch exact match');
  Check(not GlobMatch('Foo', 'Bar'), 'GlobMatch exact mismatch');

  { 空模式和空字符串 }
  Check(GlobMatch('', ''), 'GlobMatch empty pattern and string');
  Check(not GlobMatch('', 'Foo'), 'GlobMatch empty pattern, non-empty string');
  Check(not GlobMatch('Foo', ''), 'GlobMatch non-empty pattern, empty string');

  { ? 通配符 }
  Check(GlobMatch('F?o', 'Foo'), 'GlobMatch ? matches single char');
  Check(GlobMatch('F?o', 'Fao'), 'GlobMatch ? matches different char');
  Check(not GlobMatch('F?o', 'Fooo'), 'GlobMatch ? does not match multiple chars');
  Check(not GlobMatch('F?o', 'Fo'), 'GlobMatch ? requires exactly one char');

  { * 通配符 }
  Check(GlobMatch('*', 'anything'), 'GlobMatch * matches anything');
  Check(GlobMatch('*', ''), 'GlobMatch * matches empty');
  Check(GlobMatch('Foo*', 'FooBar'), 'GlobMatch prefix* matches');
  Check(GlobMatch('Foo*', 'Foo'), 'GlobMatch prefix* matches exact');
  Check(GlobMatch('*Bar', 'FooBar'), 'GlobMatch *suffix matches');
  Check(GlobMatch('F*ar', 'FooBar'), 'GlobMatch F*ar matches middle');
  Check(not GlobMatch('Foo*', 'BarFoo'), 'GlobMatch prefix* does not match wrong prefix');

  { 连续 ** }
  Check(GlobMatch('**', 'anything'), 'GlobMatch ** same as *');
  Check(GlobMatch('F**r', 'FooBar'), 'GlobMatch F**r matches');

  { 基准名称模式 }
  Check(GlobMatch('Benchmark*', 'BenchmarkSort'), 'GlobMatch Benchmark prefix');
  Check(GlobMatch('*Sort', 'QuickSort'), 'GlobMatch Sort suffix');
  Check(GlobMatch('*Sort*', 'BenchmarkSortN=100'), 'GlobMatch *Sort* contains');

  { 大小写敏感 }
  Check(not GlobMatch('foo', 'Foo'), 'GlobMatch is case-sensitive');
end;

var
  T: TTestSuite;
begin
  GAnalyzer := TBenchStatsAnalyzer.Create;
  T := TTestSuite.Create('nextpas.core.bench.stats');

  T.Test('Mean', @TestMean);
  T.Test('Median', @TestMedian);
  T.Test('StdDev', @TestStdDev);
  T.Test('Percentile', @TestPercentile);
  T.Test('Outliers', @TestOutliers);
  T.Test('ComputeStats', @TestComputeStats);
  T.Test('SignificantDifference', @TestSignificantDifference);
  T.Test('ApproximatePValue', @TestComputeApproximatePValue);
  T.Test('TInvLookup', @TestTInvLookup);
  T.Test('IsNormal', @TestIsNormal);
  T.Test('Sort', @TestSort);
  T.Test('Sort_EmptyArray', @TestSort_EmptyArray);
  T.Test('Sort_SingleElement', @TestSort_SingleElement);
  T.Test('Sort_ReverseOrder', @TestSort_ReverseOrder);
  T.Test('Sort_AllEqual', @TestSort_AllEqual);
  T.Test('Sort_NaNMixed', @TestSort_NaNMixed);
  T.Test('Sort_AllNaN', @TestSort_AllNaN);
  T.Test('Sort_NaNWithInfinity', @TestSort_NaNWithInfinity);
  T.Test('TInvLookup_KnownValues', @TestTInvLookup_KnownValues);
  T.Test('TInvLookup_ExtremeDf', @TestTInvLookup_ExtremeDf);
  T.Test('Mean_NaNInfinity', @TestMean_NaNInfinity);
  T.Test('StdDev_NaNInfinity', @TestStdDev_NaNInfinity);
  T.Test('Percentile_NaNInfinity', @TestPercentile_NaNInfinity);
  T.Test('HasHeuristicDifferenceAt', @TestHasHeuristicDifferenceAt);
  T.Test('GeometricMean', @TestGeometricMean);
  T.Test('GlobMatch', @TestGlobMatch);
  T.Test('OLSRegression', @TestOLSRegression);
  T.Test('OLSRegression_InsufficientData', @TestOLSRegression_InsufficientData);
  T.Test('OLSRegression_PerfectFit', @TestOLSRegression_PerfectFit);
  T.Test('SortIndirect_Basic', @TestSortIndirect_Basic);
  T.Test('SortIndirect_Empty', @TestSortIndirect_Empty);
  T.Test('SortIndirect_SingleElement', @TestSortIndirect_SingleElement);
  T.Test('SortIndirect_AlreadySorted', @TestSortIndirect_AlreadySorted);
  T.Test('SortIndirect_ReverseOrder', @TestSortIndirect_ReverseOrder);
  T.Test('SortIndirect_AllEqual', @TestSortIndirect_AllEqual);
  T.Test('SortIndirect_LargeArray', @TestSortIndirect_LargeArray);
  T.Test('SortIndirect_OddLength', @TestSortIndirect_OddLength);

  T.Run;
  T.Summary;
end.
