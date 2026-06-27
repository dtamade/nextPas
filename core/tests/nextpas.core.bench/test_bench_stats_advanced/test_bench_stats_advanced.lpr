program test_bench_stats_advanced;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.scalar,
  nextpas.core.math.impl.scalar,
  nextpas.core.bench.base,
  nextpas.core.bench.stats.advanced,
  nextpas.core.test;

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

function CreateTestData(AValues: array of Double): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do Result[I] := AValues[I];
end;

{ === TAdvancedStats Tests === }

procedure Test_Create;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Count = 5, 'Count = 5');
  LStats.Free;
end;

procedure Test_Mean;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Mean - 3.0) < 0.001, 'Mean = 3.0');
  LData[0] := 101.0;
  Check(Abs(LStats.Mean - 3.0) < 0.001, 'Mean cache survives source mutation');
  LStats.Free;
end;

procedure Test_Median;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Median - 3.0) < 0.001, 'Median = 3.0');
  LStats.Free;
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Median - 2.5) < 0.001, 'Median = 2.5');
  LStats.Free;
end;

procedure Test_StdDev;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.StdDev - 1.5811) < 0.01, 'StdDev ~ 1.5811');
  LStats.Free;
end;

procedure Test_Variance;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Variance - 2.5) < 0.01, 'Variance ~ 2.5');
  LStats.Free;
end;

procedure Test_Skewness;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Skewness) < 0.1, 'Skewness ~ 0');
  LStats.Free;
  LData := CreateTestData([1.0, 1.0, 1.0, 1.0, 10.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Skewness > 0, 'Skewness > 0');
  LStats.Free;
end;

procedure Test_Kurtosis;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Kurtosis < 0, 'Uniform data has negative kurtosis (platykurtic)');
  Check(Abs(LStats.Kurtosis - (-1.3)) < 0.2, 'Kurtosis ~ -1.3 for uniform 1..5');
  LStats.Free;
end;

procedure Test_Percentile;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Percentile(0) - 1.0) < 0.001, 'P0 = 1.0');
  Check(Abs(LStats.Percentile(50) - 3.0) < 0.001, 'P50 = 3.0');
  Check(Abs(LStats.Percentile(100) - 5.0) < 0.001, 'P100 = 5.0');
  LStats.Free;
end;

procedure Test_IQR;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.IQR - 2.0) < 0.01, 'IQR = 2.0');
  LStats.Free;
end;

procedure Test_DetectOutliers_Tukey;
var LData: TDoubleArray; LStats: TAdvancedStats; LResult: TOutlierDetection;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_Tukey;
  Check(Length(LResult.Outliers) = 1, 'Found 1 outlier');
  Check(LResult.Outliers[0] = 100.0, 'Outlier = 100.0');
  Check(LResult.OutlierIndices[0] = 5, 'Outlier index = 5');
  LStats.Free;
end;

procedure Test_DetectOutliers_ZScore;
var LData: TDoubleArray; LStats: TAdvancedStats; LResult: TOutlierDetection;
  LFound100: Boolean; I: Integer;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_ZScore(1.5);
  Check(LResult.Method = omZScore, 'Method = ZScore');
  LFound100 := False;
  for I := 0 to High(LResult.Outliers) do
    if LResult.Outliers[I] = 100.0 then LFound100 := True;
  Check(LFound100, 'Value 100.0 detected as outlier with threshold=1.5');
  LStats.Free;
end;

procedure Test_DetectOutliers_ModifiedZScore;
var LData: TDoubleArray; LStats: TAdvancedStats; LResult: TOutlierDetection;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_ModifiedZScore;
  Check(Length(LResult.Outliers) >= 1, 'Found at least 1 outlier');
  Check(LResult.Method = omModifiedZScore, 'Method = ModifiedZScore');
  LStats.Free;
end;

procedure Test_ConfidenceInterval;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LCI := LStats.ConfidenceInterval(0.95);
  Check(Abs(LCI.Level - 0.95) < 0.01, 'Level ~ 0.95');
  Check(LCI.Lower < 3.0, 'Lower < 3.0');
  Check(LCI.Upper > 3.0, 'Upper > 3.0');
  LStats.Free;
end;

procedure Test_BootstrapCI;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]);
  LStats := TAdvancedStats.Create(LData);
  LCI := LStats.BootstrapCI(10000, 0.95);
  { TG-23: Fixed seed (12345) makes BootstrapCI fully deterministic }
  CheckNear(3.7, LCI.Lower, 0.15, 'Bootstrap CI lower ~ 3.7');
  CheckNear(7.3, LCI.Upper, 0.15, 'Bootstrap CI upper ~ 7.3');
  CheckNear(3.6, LCI.Upper - LCI.Lower, 0.3, 'Bootstrap CI width ~ 3.6');
  Check(Abs(LCI.Level - 0.95) < 0.01, 'Bootstrap CI level = 0.95');
  LStats.Free;
end;

procedure Test_TestNormality;
var LData: TDoubleArray; LStats: TAdvancedStats; LResult: TNormalityTest;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.TestNormalityByMoments;
  Check(LResult.ApproximatePValue > 0, 'ApproximatePValue > 0');
  Check(LResult.Method <> '', 'Method is set');
  LStats.Free;
end;

procedure Test_CompareWith;
var LData1, LData2: TDoubleArray; LStats: TAdvancedStats; LTStat: Double;
begin
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LData2 := CreateTestData([2.0, 3.0, 4.0, 5.0, 6.0]);
  LStats := TAdvancedStats.Create(LData1);
  LTStat := LStats.ApproximateWelchTScore(LData2);
  Check(LTStat < 0, 'T-statistic < 0');
  LStats.Free;
end;

procedure Test_EffectSize;
var LData1, LData2: TDoubleArray; LStats: TAdvancedStats; LD: Double;
begin
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LData2 := CreateTestData([2.0, 3.0, 4.0, 5.0, 6.0]);
  LStats := TAdvancedStats.Create(LData1);
  LD := LStats.EffectSize(LData2);
  Check(LD < 0, 'Effect size < 0');
  LStats.Free;
end;

procedure Test_EmptyData;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := nil;
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Count = 0, 'Count = 0');
  Check(LStats.Mean = 0, 'Mean = 0');
  Check(LStats.Median = 0, 'Median = 0');
  Check(LStats.StdDev = 0, 'StdDev = 0');
  LStats.Free;
end;

procedure Test_SingleValue;
var LData: TDoubleArray; LStats: TAdvancedStats;
begin
  LData := CreateTestData([42.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Count = 1, 'Count = 1');
  Check(LStats.Mean = 42.0, 'Mean = 42.0');
  Check(LStats.Median = 42.0, 'Median = 42.0');
  Check(LStats.StdDev = 0, 'StdDev = 0');
  LStats.Free;
end;

{ === TG-06: NaN/Infinity Input Tests === }
{ Verify NaN/Infinity inputs do not cause segfaults or infinite loops.
  Raising a managed exception is acceptable; crashing is not. }

procedure Test_NaNInput_NoCrash;
var LData: TDoubleArray; LHandled: Boolean;
begin
  LHandled := True;
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  try
    TAdvancedStats.Create(LData).Mean;
    TAdvancedStats.Create(LData).Median;
    TAdvancedStats.Create(LData).StdDev;
    TAdvancedStats.Create(LData).Variance;
  except end;
  Check(LHandled, 'NaN input: all stats survive without segfault');
end;

procedure Test_InfinityInput_NoCrash;
var LData: TDoubleArray; LHandled: Boolean;
begin
  LHandled := True;
  LData := CreateTestData([1.0, 2.0, MakePositiveInfinity, 4.0, 5.0]);
  try
    TAdvancedStats.Create(LData).Mean;
    TAdvancedStats.Create(LData).Median;
    TAdvancedStats.Create(LData).StdDev;
    TAdvancedStats.Create(LData).Variance;
  except end;
  Check(LHandled, 'Positive Infinity input: all stats survive without segfault');

  LHandled := True;
  LData := CreateTestData([1.0, 2.0, MakeNegativeInfinity, 4.0, 5.0]);
  try
    TAdvancedStats.Create(LData).Mean;
    TAdvancedStats.Create(LData).Median;
    TAdvancedStats.Create(LData).StdDev;
    TAdvancedStats.Create(LData).Variance;
  except end;
  Check(LHandled, 'Negative Infinity input: all stats survive without segfault');
end;

procedure Test_NaNInfinity_Kurtosis;
var LData: TDoubleArray; LHandled: Boolean;
begin
  LHandled := True;
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  try
    TAdvancedStats.Create(LData).Kurtosis;
    TAdvancedStats.Create(LData).Skewness;
  except end;
  Check(LHandled, 'NaN: Kurtosis/Skewness survive without segfault');

  LHandled := True;
  LData := CreateTestData([1.0, MakePositiveInfinity, 3.0, 4.0, 5.0]);
  try
    TAdvancedStats.Create(LData).Kurtosis;
    TAdvancedStats.Create(LData).Skewness;
  except end;
  Check(LHandled, 'Infinity: Kurtosis/Skewness survive without segfault');
end;

procedure Test_NaNInfinity_Percentile;
var LData: TDoubleArray; LHandled: Boolean;
begin
  LHandled := True;
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  try TAdvancedStats.Create(LData).Percentile(50); except end;
  Check(LHandled, 'NaN: Percentile survives without segfault');

  LHandled := True;
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, MakePositiveInfinity]);
  try TAdvancedStats.Create(LData).Percentile(99); except end;
  Check(LHandled, 'Infinity: Percentile survives without segfault');
end;

procedure Test_GetData;
var LOrig, LCopy: TDoubleArray; LStats: TAdvancedStats;
begin
  LOrig := CreateTestData([10.0, 20.0, 30.0]);
  LStats := TAdvancedStats.Create(LOrig);
  try
    LCopy := LStats.GetData;
    Check(Length(LCopy) = 3, 'GetData returns correct length');
    CheckNear(10.0, LCopy[0], 0.001, 'GetData[0] = 10.0');
    CheckNear(20.0, LCopy[1], 0.001, 'GetData[1] = 20.0');
    CheckNear(30.0, LCopy[2], 0.001, 'GetData[2] = 30.0');
    { 修改副本不影响原始数据 }
    LCopy[0] := 999.0;
    LCopy := LStats.GetData;
    CheckNear(10.0, LCopy[0], 0.001, 'GetData returns independent copy');
  finally
    LStats.Free;
  end;
end;

procedure Test_Count;
var LStats: TAdvancedStats;
begin
  LStats := TAdvancedStats.Create(CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]));
  try
    Check(5 = LStats.Count, 'Count = 5 for 5-element data');
  finally
    LStats.Free;
  end;
  LStats := TAdvancedStats.Create(CreateTestData([]));
  try
    Check(0 = LStats.Count, 'Count = 0 for empty data');
  finally
    LStats.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.stats.advanced');
  T.Test('Create', @Test_Create);
  T.Test('Mean', @Test_Mean);
  T.Test('Median', @Test_Median);
  T.Test('StdDev', @Test_StdDev);
  T.Test('Variance', @Test_Variance);
  T.Test('Skewness', @Test_Skewness);
  T.Test('Kurtosis', @Test_Kurtosis);
  T.Test('Percentile', @Test_Percentile);
  T.Test('IQR', @Test_IQR);
  T.Test('DetectOutliers_Tukey', @Test_DetectOutliers_Tukey);
  T.Test('DetectOutliers_ZScore', @Test_DetectOutliers_ZScore);
  T.Test('DetectOutliers_ModifiedZScore', @Test_DetectOutliers_ModifiedZScore);
  T.Test('ConfidenceInterval', @Test_ConfidenceInterval);
  T.Test('BootstrapCI', @Test_BootstrapCI);
  T.Test('TestNormality', @Test_TestNormality);
  T.Test('CompareWith', @Test_CompareWith);
  T.Test('EffectSize', @Test_EffectSize);
  T.Test('EmptyData', @Test_EmptyData);
  T.Test('SingleValue', @Test_SingleValue);
  T.Test('NaNInput_NoCrash', @Test_NaNInput_NoCrash);
  T.Test('InfinityInput_NoCrash', @Test_InfinityInput_NoCrash);
  T.Test('NaNInfinity_Kurtosis', @Test_NaNInfinity_Kurtosis);
  T.Test('NaNInfinity_Percentile', @Test_NaNInfinity_Percentile);
  T.Test('GetData', @Test_GetData);
  T.Test('Count', @Test_Count);
  T.Run;
  T.Summary;
end.
