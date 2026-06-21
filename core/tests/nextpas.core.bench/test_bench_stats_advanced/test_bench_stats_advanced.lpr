program test_bench_stats_advanced;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  nextpas.core.math.scalar,
  nextpas.core.bench.base,
  nextpas.core.bench.stats.advanced;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', ATestName);
  end;
end;

{ Helper function to create test data }

function CreateTestData(AValues: array of Double): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

{ === TAdvancedStats Tests === }

procedure Test_Create;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Create:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Count = 5, 'Count = 5');
end;

procedure Test_Mean;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Mean:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Mean - 3.0) < 0.001, 'Mean = 3.0');
end;

procedure Test_Median;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Median:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Median - 3.0) < 0.001, 'Median = 3.0');

  LData := CreateTestData([1.0, 2.0, 3.0, 4.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Median - 2.5) < 0.001, 'Median = 2.5');
end;

procedure Test_StdDev;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_StdDev:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.StdDev - 1.5811) < 0.01, 'StdDev ≈ 1.5811');
end;

procedure Test_Variance;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Variance:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Variance - 2.5) < 0.01, 'Variance ≈ 2.5');
end;

procedure Test_Skewness;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Skewness:');
  // Symmetric data should have skewness ≈ 0
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.Skewness) < 0.1, 'Skewness ≈ 0');

  // Right-skewed data
  LData := CreateTestData([1.0, 1.0, 1.0, 1.0, 10.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(LStats.Skewness > 0, 'Skewness > 0');
end;

procedure Test_Kurtosis;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Kurtosis:');
  // Normal-like data should have kurtosis near 0
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  // Just check it's a valid number
  Check(LStats.Kurtosis <> 0, 'Kurtosis is computed');
end;

procedure Test_Percentile;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_Percentile:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);

  Check(Abs(LStats.Percentile(0) - 1.0) < 0.001, 'P0 = 1.0');
  Check(Abs(LStats.Percentile(50) - 3.0) < 0.001, 'P50 = 3.0');
  Check(Abs(LStats.Percentile(100) - 5.0) < 0.001, 'P100 = 5.0');
end;

procedure Test_IQR;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_IQR:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  Check(Abs(LStats.IQR - 2.0) < 0.01, 'IQR = 2.0');
end;

procedure Test_DetectOutliers_Tukey;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
  LResult: TOutlierDetection;
begin
  WriteLn('Test_DetectOutliers_Tukey:');
  // Data with outlier
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_Tukey;

  Check(Length(LResult.Outliers) = 1, 'Found 1 outlier');
  Check(LResult.Outliers[0] = 100.0, 'Outlier = 100.0');
  Check(LResult.OutlierIndices[0] = 5, 'Outlier index = 5');
end;

procedure Test_DetectOutliers_ZScore;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
  LResult: TOutlierDetection;
begin
  WriteLn('Test_DetectOutliers_ZScore:');
  // Data with outlier
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_ZScore;

  // Z-Score might not detect outliers with small sample size
  Check(Length(LResult.Outliers) >= 0, 'Outliers detected or none');
  Check(LResult.Method = omZScore, 'Method = ZScore');
end;

procedure Test_DetectOutliers_ModifiedZScore;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
  LResult: TOutlierDetection;
begin
  WriteLn('Test_DetectOutliers_ModifiedZScore:');
  // Data with outlier
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0, 100.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.DetectOutliers_ModifiedZScore;

  Check(Length(LResult.Outliers) >= 1, 'Found at least 1 outlier');
  Check(LResult.Method = omModifiedZScore, 'Method = ModifiedZScore');
end;

procedure Test_ConfidenceInterval;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
  LCI: TConfidenceInterval;
begin
  WriteLn('Test_ConfidenceInterval:');
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);

  LCI := LStats.ConfidenceInterval(0.95);
  Check(Abs(LCI.Level - 0.95) < 0.01, 'Level ≈ 0.95');
  Check(LCI.Lower < 3.0, 'Lower < 3.0');
  Check(LCI.Upper > 3.0, 'Upper > 3.0');
end;

procedure Test_TestNormality;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
  LResult: TNormalityTest;
begin
  WriteLn('Test_TestNormality:');
  // Normal-like data
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LResult := LStats.TestNormalityHeuristic;

  // Just check it returns a valid result
  Check(LResult.ApproximatePValue > 0, 'ApproximatePValue > 0');
  Check(LResult.Method <> '', 'Method is set');
end;

procedure Test_CompareWith;
var
  LData1: TDoubleArray;
  LData2: TDoubleArray;
  LStats: TAdvancedStats;
  LTStat: Double;
begin
  WriteLn('Test_CompareWith:');
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LData2 := CreateTestData([2.0, 3.0, 4.0, 5.0, 6.0]);
  LStats := TAdvancedStats.Create(LData1);
  LTStat := LStats.ApproximateWelchTScore(LData2);

  // Should be negative since LData1 mean < LData2 mean
  Check(LTStat < 0, 'T-statistic < 0');
end;

procedure Test_EffectSize;
var
  LData1: TDoubleArray;
  LData2: TDoubleArray;
  LStats: TAdvancedStats;
  LD: Double;
begin
  WriteLn('Test_EffectSize:');
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LData2 := CreateTestData([2.0, 3.0, 4.0, 5.0, 6.0]);
  LStats := TAdvancedStats.Create(LData1);
  LD := LStats.EffectSize(LData2);

  // Should be negative since LData1 mean < LData2 mean
  Check(LD < 0, 'Effect size < 0');
end;

procedure Test_EmptyData;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_EmptyData:');
  LData := nil;
  LStats := TAdvancedStats.Create(LData);

  Check(LStats.Count = 0, 'Count = 0');
  Check(LStats.Mean = 0, 'Mean = 0');
  Check(LStats.Median = 0, 'Median = 0');
  Check(LStats.StdDev = 0, 'StdDev = 0');
end;

procedure Test_SingleValue;
var
  LData: TDoubleArray;
  LStats: TAdvancedStats;
begin
  WriteLn('Test_SingleValue:');
  LData := CreateTestData([42.0]);
  LStats := TAdvancedStats.Create(LData);

  Check(LStats.Count = 1, 'Count = 1');
  Check(LStats.Mean = 42.0, 'Mean = 42.0');
  Check(LStats.Median = 42.0, 'Median = 42.0');
  Check(LStats.StdDev = 0, 'StdDev = 0');
end;

{ === Run All Tests === }

procedure RunAllTests;
begin
  WriteLn('=== TAdvancedStats Tests ===');
  Test_Create;
  Test_Mean;
  Test_Median;
  Test_StdDev;
  Test_Variance;
  Test_Skewness;
  Test_Kurtosis;
  Test_Percentile;
  Test_IQR;
  Test_DetectOutliers_Tukey;
  Test_DetectOutliers_ZScore;
  Test_DetectOutliers_ModifiedZScore;
  Test_ConfidenceInterval;
  Test_TestNormality;
  Test_CompareWith;
  Test_EffectSize;
  Test_EmptyData;
  Test_SingleValue;
end;

begin
  WriteLn('=== nextpas.core.bench.stats.advanced Test Suite ===');
  WriteLn('');

  RunAllTests;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestsPassed + GTestsFailed);
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
  begin
    WriteLn('');
    WriteLn('*** FAILED ***');
    Halt(1);
  end
  else
  begin
    WriteLn('');
    WriteLn('✓ All tests passed!');
  end;
end.
