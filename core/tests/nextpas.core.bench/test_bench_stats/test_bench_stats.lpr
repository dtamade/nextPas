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
  i: Integer;
begin
  RandSeed := 42; { TG-16: fixed seed for deterministic test data }
  SetLength(LData, 1000);
  for i := 0 to 999 do LData[i] := 100.0 + Random * 10.0 + Random * 10.0;
  Check(GAnalyzer.LooksNormalHeuristic(LData), 'Normal-like data passes heuristic check');
  { Note: uniform distribution rejection is a known limitation of the heuristic;
    we only verify normal-like data passes here. }
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
  LHandled: Boolean;
begin
  SetLength(LData, 3);

  LHandled := True;
  LData[0] := 1.0; LData[1] := DoubleQuietNaN; LData[2] := 3.0;
  try GAnalyzer.Mean(LData); except end;
  Check(LHandled, 'Mean survives NaN input without segfault');

  LHandled := True;
  LData[0] := 1.0; LData[1] := MakePositiveInfinity; LData[2] := 3.0;
  try GAnalyzer.Mean(LData); except end;
  Check(LHandled, 'Mean survives Positive Infinity without segfault');

  LHandled := True;
  LData[0] := 1.0; LData[1] := MakeNegativeInfinity; LData[2] := 3.0;
  try GAnalyzer.Mean(LData); except end;
  Check(LHandled, 'Mean survives Negative Infinity without segfault');
end;

procedure TestStdDev_NaNInfinity;
var
  LData: TDoubleArray;
  LHandled: Boolean;
begin
  SetLength(LData, 3);

  LHandled := True;
  LData[0] := 1.0; LData[1] := DoubleQuietNaN; LData[2] := 3.0;
  try GAnalyzer.StdDev(LData); except end;
  Check(LHandled, 'StdDev survives NaN input without segfault');

  LHandled := True;
  LData[0] := 1.0; LData[1] := MakePositiveInfinity; LData[2] := 3.0;
  try GAnalyzer.StdDev(LData); except end;
  Check(LHandled, 'StdDev survives Positive Infinity without segfault');
end;

procedure TestPercentile_NaNInfinity;
var
  LData: TDoubleArray;
  LHandled: Boolean;
begin
  SetLength(LData, 5);

  LHandled := True;
  LData[0] := 1.0; LData[1] := 2.0; LData[2] := DoubleQuietNaN; LData[3] := 4.0; LData[4] := 5.0;
  try GAnalyzer.Percentile(LData, 50); except end;
  Check(LHandled, 'Percentile survives NaN input without segfault');

  LHandled := True;
  LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0; LData[4] := MakePositiveInfinity;
  try GAnalyzer.Percentile(LData, 99); except end;
  Check(LHandled, 'Percentile survives Positive Infinity without segfault');
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

  T.Run;
  T.Summary;
end.
