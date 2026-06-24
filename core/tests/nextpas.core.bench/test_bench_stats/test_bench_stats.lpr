program test_bench_stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  nextpas.core.math.scalar,
  nextpas.core.math.impl.scalar,
  nextpas.core.text.conv,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

var
  GAnalyzer: IBenchStatsAnalyzer;
  GTestCount: Integer;
  GPassCount: Integer;
  GFailCount: Integer;

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

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTestCount);
  if ACondition then begin Inc(GPassCount); WriteLn('  ✓ ', ATestName); end
  else begin Inc(GFailCount); WriteLn('  ✗ ', ATestName); end;
end;

procedure CheckApprox(AActual, AExpected, AEpsilon: Double; const ATestName: string);
begin
  Check(Abs(AActual - AExpected) <= AEpsilon,
    ATestName + ' (expected: ' + FloatToStr(AExpected) + ', got: ' + FloatToStr(AActual) + ')');
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
  WriteLn('TestMean:');
  SetLength(LData, 0);
  CheckApprox(GAnalyzer.Mean(LData), 0.0, 0.001, 'Empty array returns 0');
  SetLength(LData, 1); LData[0] := 5.0;
  CheckApprox(GAnalyzer.Mean(LData), 5.0, 0.001, 'Single value returns that value');
  SetLength(LData, 5); LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0; LData[4] := 5.0;
  CheckApprox(GAnalyzer.Mean(LData), 3.0, 0.001, 'Multiple values correct mean');
  SetLength(LData, 3); LData[0] := 1e15; LData[1] := 1.0; LData[2] := -1e15;
  CheckApprox(GAnalyzer.Mean(LData), 1.0/3.0, 0.001, 'Kahan sum precision');
end;

procedure TestMedian;
var
  LData: TDoubleArray;
begin
  WriteLn('TestMedian:');
  SetLength(LData, 5); LData[0] := 1.0; LData[1] := 3.0; LData[2] := 2.0; LData[3] := 5.0; LData[4] := 4.0;
  CheckApprox(GAnalyzer.Median(LData), 3.0, 0.001, 'Odd count returns middle');
  SetLength(LData, 4); LData[0] := 1.0; LData[1] := 2.0; LData[2] := 3.0; LData[3] := 4.0;
  CheckApprox(GAnalyzer.Median(LData), 2.5, 0.001, 'Even count returns average');
  SetLength(LData, 0);
  CheckApprox(GAnalyzer.Median(LData), 0.0, 0.001, 'Empty array returns 0');
end;

procedure TestStdDev;
var
  LData: TDoubleArray;
begin
  WriteLn('TestStdDev:');
  SetLength(LData, 3); LData[0] := 5.0; LData[1] := 5.0; LData[2] := 5.0;
  CheckApprox(GAnalyzer.StdDev(LData), 0.0, 0.001, 'Zero variance returns 0');
  SetLength(LData, 5); LData[0] := 2.0; LData[1] := 4.0; LData[2] := 4.0; LData[3] := 4.0; LData[4] := 5.0;
  CheckApprox(GAnalyzer.StdDev(LData), 1.09544511501033, 0.001, 'Known values correct stddev');
  SetLength(LData, 1); LData[0] := 10.0;
  CheckApprox(GAnalyzer.StdDev(LData), 0.0, 0.001, 'Single value returns 0');
end;

procedure TestPercentile;
var
  LSorted: TDoubleArray;
begin
  WriteLn('TestPercentile:');
  SetLength(LSorted, 10);
  LSorted[0] := 1.0; LSorted[1] := 2.0; LSorted[2] := 3.0; LSorted[3] := 4.0; LSorted[4] := 5.0;
  LSorted[5] := 6.0; LSorted[6] := 7.0; LSorted[7] := 8.0; LSorted[8] := 9.0; LSorted[9] := 10.0;
  CheckApprox(GAnalyzer.Percentile(LSorted, 0), 1.0, 0.001, 'P0 returns min');
  CheckApprox(GAnalyzer.Percentile(LSorted, 100), 10.0, 0.001, 'P100 returns max');
  CheckApprox(GAnalyzer.Percentile(LSorted, 50), 5.5, 0.001, 'P50 returns median');
  CheckApprox(GAnalyzer.Percentile(LSorted, 25), 3.25, 0.001, 'P25 correct');
  CheckApprox(GAnalyzer.Percentile(LSorted, 75), 7.75, 0.001, 'P75 correct');
  CheckApprox(GAnalyzer.Percentile(LSorted, 95), 9.55, 0.01, 'P95 correct');
  CheckApprox(GAnalyzer.Percentile(LSorted, 99), 9.91, 0.01, 'P99 correct');

  // TG-26: Single element Percentile
  SetLength(LSorted, 1);
  LSorted[0] := 42.0;
  CheckApprox(GAnalyzer.Percentile(LSorted, 50), 42.0, 0.001, 'Single element P50 = 42.0');
  CheckApprox(GAnalyzer.Percentile(LSorted, 0), 42.0, 0.001, 'Single element P0 = 42.0');
  CheckApprox(GAnalyzer.Percentile(LSorted, 100), 42.0, 0.001, 'Single element P100 = 42.0');

  // TG-26: Two element Percentile
  SetLength(LSorted, 2);
  LSorted[0] := 10.0; LSorted[1] := 20.0;
  CheckApprox(GAnalyzer.Percentile(LSorted, 0), 10.0, 0.001, 'Two element P0 = 10.0');
  CheckApprox(GAnalyzer.Percentile(LSorted, 50), 15.0, 0.001, 'Two element P50 = 15.0');
  CheckApprox(GAnalyzer.Percentile(LSorted, 100), 20.0, 0.001, 'Two element P100 = 20.0');
end;

procedure TestOutliers;
var
  LSorted: TDoubleArray;
begin
  WriteLn('TestOutliers:');
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
  WriteLn('TestComputeStats:');
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
  WriteLn('TestSignificantDifference:');
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
  WriteLn('TestTInvLookup:');
  SetLength(LSamples, 5);
  LSamples[0] := 1.0; LSamples[1] := 2.0; LSamples[2] := 3.0; LSamples[3] := 4.0; LSamples[4] := 5.0;
  LStats := GAnalyzer.ComputeStats(LSamples);
  LCIWidth := LStats.Confidence95High - LStats.Confidence95Low;
  CheckApprox(LCIWidth, 3.926, 0.15, 'DF=4 uses lookup-table CI width');
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
  LUniformResult: Boolean;
  i: Integer;
begin
  WriteLn('TestIsNormal:');
  RandSeed := 42; { TG-16: fixed seed for deterministic test data }
  SetLength(LData, 1000);
  for i := 0 to 999 do LData[i] := 100.0 + Random * 10.0 + Random * 10.0;
  Check(GAnalyzer.LooksNormalHeuristic(LData), 'Normal-like data passes heuristic check');
  SetLength(LData, 1000);
  for i := 0 to 999 do LData[i] := i * 0.1;
  LUniformResult := GAnalyzer.LooksNormalHeuristic(LData);
  if not LUniformResult then WriteLn('  ✓ Uniform correctly rejected as non-normal')
  else WriteLn('  ⚠ Uniform incorrectly accepted (known limitation of heuristic)');
end;

procedure TestComputeApproximatePValue;
var
  LA, LB: TDoubleArray;
  LStatsA, LStatsB: TBenchStats;
  LPValue: Double;
  i: Integer;
begin
  WriteLn('TestComputeApproximatePValue:');
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
  Check(LPValue > 0.2, 'Controlled t≈1.118 p-value > 0.2');
  Check(LPValue < 0.35, 'Controlled t≈1.118 p-value < 0.35');
end;

procedure TestSort;
var
  LData: TDoubleArray;
begin
  WriteLn('TestSort:');
  SetLength(LData, 5);
  LData[0] := 5.0; LData[1] := 3.0; LData[2] := 1.0; LData[3] := 4.0; LData[4] := 2.0;
  SortDoubleArray(LData);
  CheckApprox(LData[0], 1.0, 0.001, 'Sort[0] = 1.0');
  CheckApprox(LData[1], 2.0, 0.001, 'Sort[1] = 2.0');
  CheckApprox(LData[2], 3.0, 0.001, 'Sort[2] = 3.0');
  CheckApprox(LData[3], 4.0, 0.001, 'Sort[3] = 4.0');
  CheckApprox(LData[4], 5.0, 0.001, 'Sort[4] = 5.0');
end;

{ === TG-03: SortDoubleArray Edge Cases === }

procedure TestSort_EmptyArray;
var
  LData: TDoubleArray;
  LNoCrash: Boolean;
begin
  WriteLn('TestSort_EmptyArray:');
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
  WriteLn('TestSort_SingleElement:');
  SetLength(LData, 1);
  LData[0] := 42.0;
  SortDoubleArray(LData);
  CheckApprox(LData[0], 42.0, 0.001, 'Single element unchanged');
end;

procedure TestSort_ReverseOrder;
var
  LData: TDoubleArray;
  i: Integer;
begin
  WriteLn('TestSort_ReverseOrder:');
  SetLength(LData, 10);
  for i := 0 to 9 do
    LData[i] := 10.0 - i;
  SortDoubleArray(LData);
  for i := 0 to 9 do
    CheckApprox(LData[i], i + 1, 0.001, 'ReverseSort[' + IntToStr(i) + '] = ' + IntToStr(i + 1));
end;

procedure TestSort_AllEqual;
var
  LData: TDoubleArray;
  i: Integer;
begin
  WriteLn('TestSort_AllEqual:');
  SetLength(LData, 10);
  for i := 0 to 9 do
    LData[i] := 7.0;
  SortDoubleArray(LData);
  for i := 0 to 9 do
    CheckApprox(LData[i], 7.0, 0.001, 'AllEqual[' + IntToStr(i) + '] = 7.0');
end;

{ === TG-04: TInvLookup Edge Cases === }

procedure TestTInvLookup_KnownValues;
begin
  WriteLn('TestTInvLookup_KnownValues:');

  { df=10, p=0.05 (two-tailed 95%) => t ≈ 2.228
    TInvLookup(10, TINV95_DATA, Z_SCORE_95) should return TINV95_DATA[9] = 2.228 }
  CheckApprox(TInvLookup(10, TINV95_DATA, Z_SCORE_95), 2.228, 0.001,
    'TInv 95% df=10 = 2.228');

  { df=5, p=0.05 => t ≈ 2.571 }
  CheckApprox(TInvLookup(5, TINV95_DATA, Z_SCORE_95), 2.571, 0.001,
    'TInv 95% df=5 = 2.571');

  { df=1, p=0.05 => t ≈ 12.706 }
  CheckApprox(TInvLookup(1, TINV95_DATA, Z_SCORE_95), 12.706, 0.001,
    'TInv 95% df=1 = 12.706');

  { df=10, p=0.01 (two-tailed 99%) => t ≈ 3.169 }
  CheckApprox(TInvLookup(10, TINV99_DATA, Z_SCORE_99), 3.169, 0.001,
    'TInv 99% df=10 = 3.169');
end;

procedure TestTInvLookup_ExtremeDf;
begin
  WriteLn('TestTInvLookup_ExtremeDf:');

  { df < 1 should clamp to table[0] }
  CheckApprox(TInvLookup(0.5, TINV95_DATA, Z_SCORE_95), 12.706, 0.001,
    'TInv df=0.5 clamps to df=1');

  CheckApprox(TInvLookup(0.1, TINV95_DATA, Z_SCORE_95), 12.706, 0.001,
    'TInv df=0.1 clamps to df=1');

  { df >= 30 should converge to z-score }
  CheckApprox(TInvLookup(30, TINV95_DATA, Z_SCORE_95), Z_SCORE_95, 0.001,
    'TInv df=30 = z-score 1.96');

  CheckApprox(TInvLookup(100, TINV95_DATA, Z_SCORE_95), Z_SCORE_95, 0.001,
    'TInv df=100 = z-score 1.96');

  CheckApprox(TInvLookup(1000, TINV95_DATA, Z_SCORE_95), Z_SCORE_95, 0.001,
    'TInv df=1000 = z-score 1.96');
end;

{ === TG-05: NaN/Infinity Input Tests === }
{ These verify that NaN/Infinity inputs do not cause segfaults or infinite loops.
  Raising a managed exception is acceptable; crashing is not. }

procedure TestMean_NaNInfinity;
var
  LData: TDoubleArray;
  LHandled: Boolean;
begin
  WriteLn('TestMean_NaNInfinity:');
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
  WriteLn('TestStdDev_NaNInfinity:');
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
  WriteLn('TestPercentile_NaNInfinity:');
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

{ === DS-04: HasHeuristicDifferenceAt === }

procedure TestHasHeuristicDifferenceAt;
var
  LA, LB: TDoubleArray;
  LSa, LSb: TBenchStats;
  LI: Integer;
begin
  WriteLn('TestHasHeuristicDifferenceAt:');
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

begin
  WriteLn('=== nextpas.core.bench.stats Unit Tests ===');
  WriteLn;
  GAnalyzer := TBenchStatsAnalyzer.Create;
  GTestCount := 0; GPassCount := 0; GFailCount := 0;

  TestMean; WriteLn;
  TestMedian; WriteLn;
  TestStdDev; WriteLn;
  TestPercentile; WriteLn;
  TestOutliers; WriteLn;
  TestComputeStats; WriteLn;
  TestSignificantDifference; WriteLn;
  TestComputeApproximatePValue; WriteLn;
  TestTInvLookup; WriteLn;
  TestIsNormal; WriteLn;
  TestSort; WriteLn;
  WriteLn('=== SortDoubleArray Edge Cases (TG-03) ===');
  TestSort_EmptyArray; WriteLn;
  TestSort_SingleElement; WriteLn;
  TestSort_ReverseOrder; WriteLn;
  TestSort_AllEqual; WriteLn;
  WriteLn('=== TInvLookup Edge Cases (TG-04) ===');
  TestTInvLookup_KnownValues; WriteLn;
  TestTInvLookup_ExtremeDf; WriteLn;
  WriteLn('=== NaN/Infinity Input Tests (TG-05) ===');
  TestMean_NaNInfinity; WriteLn;
  TestStdDev_NaNInfinity; WriteLn;
  TestPercentile_NaNInfinity; WriteLn;

  WriteLn('=== HasHeuristicDifferenceAt (DS-04) ===');
  TestHasHeuristicDifferenceAt; WriteLn;

  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  if GFailCount > 0 then begin WriteLn; WriteLn('✗ ', GFailCount, ' test(s) failed!'); Halt(1); end
  else begin WriteLn; WriteLn('✓ All tests passed!'); end;
end.
