program test_bench_stats_advanced;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.scalar,
  nextpas.core.math.impl.scalar,
  nextpas.core.bench.base,
  nextpas.core.bench.intf, { PF-06: for EBenchInvalidParam }
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

procedure Test_BootstrapCI_Empty;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := nil;
  LStats := TAdvancedStats.Create(LData);
  LCI := LStats.BootstrapCI(1000, 0.95);
  Check(LCI.Lower = 0.0, 'Bootstrap CI empty: lower = 0');
  Check(LCI.Upper = 0.0, 'Bootstrap CI empty: upper = 0');
  Check(Abs(LCI.Level - 0.95) < 0.01, 'Bootstrap CI empty: level = 0.95');
  LStats.Free;
end;

procedure Test_BootstrapCI_Single;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := CreateTestData([42.0]);
  LStats := TAdvancedStats.Create(LData);
  LCI := LStats.BootstrapCI(1000, 0.95);
  Check(Abs(LCI.Lower - 42.0) < 0.001, 'Bootstrap CI single: lower = 42.0');
  Check(Abs(LCI.Upper - 42.0) < 0.001, 'Bootstrap CI single: upper = 42.0');
  Check(Abs(LCI.Level - 0.95) < 0.01, 'Bootstrap CI single: level = 0.95');
  LStats.Free;
end;

procedure Test_BootstrapCI_ZeroIterations;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := CreateTestData([1.0, 2.0, 3.0]);
  LStats := TAdvancedStats.Create(LData);
  { F-09: AIterations=0 should not crash, clamped to 1 }
  LCI := LStats.BootstrapCI(0, 0.95);
  Check(LCI.Lower <> 0.0, 'Bootstrap CI zero iterations: lower set');
  Check(LCI.Upper <> 0.0, 'Bootstrap CI zero iterations: upper set');
  LStats.Free;
end;

procedure Test_BootstrapCI_LevelBoundary;
var LData: TDoubleArray; LStats: TAdvancedStats; LCI: TConfidenceInterval;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  { F-09: ALevel=1.0 → full range }
  LCI := LStats.BootstrapCI(1000, 1.0);
  Check(LCI.Lower <= LCI.Upper, 'Bootstrap CI level=1.0: lower <= upper');
  Check(Abs(LCI.Level - 1.0) < 0.01, 'Bootstrap CI level=1.0: level preserved');
  { F-09: ALevel=0.0 → degenerate }
  LCI := LStats.BootstrapCI(1000, 0.0);
  Check(LCI.Lower <= LCI.Upper, 'Bootstrap CI level=0.0: lower <= upper');
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
  Check(LTStat < 0, 'T-statistic < 0 (data1 mean < data2 mean)');
  Check(LTStat > -5, 'T-statistic > -5 (not extremely negative for close means)');
  LStats.Free;
end;

procedure Test_WelchTScore_SignificantDifference;
var LData1, LData2: TDoubleArray; LStats: TAdvancedStats; LTStat: Double;
begin
  { data1 mean=100, data2 mean=1, very different → large |t| }
  LData1 := CreateTestData([98.0, 99.0, 100.0, 101.0, 102.0]);
  LData2 := CreateTestData([0.0, 0.5, 1.0, 1.5, 2.0]);
  LStats := TAdvancedStats.Create(LData1);
  LTStat := LStats.ApproximateWelchTScore(LData2);
  Check(LTStat > 10, 'Significant difference: t > 10');
  LStats.Free;
end;

procedure Test_WelchTScore_NoDifference;
var LData: TDoubleArray; LStats: TAdvancedStats; LTStat: Double;
begin
  { Same data → t should be ~0 }
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LTStat := LStats.ApproximateWelchTScore(LData);
  Check(Abs(LTStat) < 0.01, 'No difference: t ~ 0');
  LStats.Free;
end;

procedure Test_EffectSize;
var LData1, LData2: TDoubleArray; LStats: TAdvancedStats; LD: Double;
begin
  { data1 mean=3, data2 mean=4, same spread → Cohen's d should be negative and ~-1 }
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LData2 := CreateTestData([2.0, 3.0, 4.0, 5.0, 6.0]);
  LStats := TAdvancedStats.Create(LData1);
  LD := LStats.EffectSize(LData2);
  Check(LD < 0, 'Effect size < 0 (data1 mean < data2 mean)');
  Check(LD > -3, 'Effect size > -3 (not extreme for close distributions)');
  LStats.Free;
end;

procedure Test_EffectSize_LargeEffect;
var LData1, LData2: TDoubleArray; LStats: TAdvancedStats; LD: Double;
begin
  { data1 mean=1, data2 mean=100, same spread → large negative Cohen's d }
  LData1 := CreateTestData([0.0, 0.5, 1.0, 1.5, 2.0]);
  LData2 := CreateTestData([98.0, 99.0, 100.0, 101.0, 102.0]);
  LStats := TAdvancedStats.Create(LData1);
  LD := LStats.EffectSize(LData2);
  Check(LD < -10, 'Large effect: d < -10');
  LStats.Free;
end;

procedure Test_EffectSize_SameData;
var LData1: TDoubleArray; LStats: TAdvancedStats; LD: Double;
begin
  { Same data → Cohen's d should be ~0 }
  LData1 := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData1);
  LD := LStats.EffectSize(LData1);
  Check(Abs(LD) < 0.01, 'Same data: effect size ~ 0');
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
var LData: TDoubleArray; LStats: TAdvancedStats; LVal: Double;
  LNoCrash: Boolean;
begin
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Mean;
      Check(IsNan(LVal) or (LVal >= 0), 'NaN input: Mean returns NaN or defined value');
    except end;
    try
      LVal := LStats.StdDev;
      Check(IsNan(LVal) or (LVal >= 0), 'NaN input: StdDev returns NaN or non-negative');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'NaN input: all stats survive without segfault');
end;

procedure Test_InfinityInput_NoCrash;
var LData: TDoubleArray; LStats: TAdvancedStats; LVal: Double;
  LNoCrash: Boolean;
begin
  { +Infinity }
  LData := CreateTestData([1.0, 2.0, MakePositiveInfinity, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Mean;
      Check(LVal > 1e300, '+Inf input: Mean returns +Inf');
    except end;
    try
      LVal := LStats.StdDev;
      Check(LVal >= 0, '+Inf input: StdDev non-negative');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'Positive Infinity input: all stats survive without segfault');

  { -Infinity }
  LData := CreateTestData([1.0, 2.0, MakeNegativeInfinity, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Mean;
      Check(LVal < -1e300, '-Inf input: Mean returns -Inf');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'Negative Infinity input: all stats survive without segfault');
end;

procedure Test_NaNInfinity_Kurtosis;
var LData: TDoubleArray; LStats: TAdvancedStats; LVal: Double;
  LNoCrash: Boolean;
begin
  { NaN input }
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Kurtosis;
      Check(not IsInfinite(LVal), 'NaN: Kurtosis does not return Infinity');
    except end;
    try
      LVal := LStats.Skewness;
      Check(not IsInfinite(LVal), 'NaN: Skewness does not return Infinity');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'NaN: Kurtosis/Skewness survive without segfault');

  { +Infinity input }
  LData := CreateTestData([1.0, MakePositiveInfinity, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try LStats.Kurtosis; except end;
    try LStats.Skewness; except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'Infinity: Kurtosis/Skewness survive without segfault');
end;

procedure Test_NaNInfinity_Percentile;
var LData: TDoubleArray; LStats: TAdvancedStats; LVal: Double;
  LNoCrash: Boolean;
begin
  { NaN in data }
  LData := CreateTestData([1.0, 2.0, DoubleQuietNaN, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Percentile(50);
      Check(not IsInfinite(LVal), 'NaN: Percentile(50) does not return Infinity');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'NaN: Percentile survives without segfault');

  { +Infinity in data }
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, MakePositiveInfinity]);
  LStats := TAdvancedStats.Create(LData);
  LNoCrash := True;
  try
    try
      LVal := LStats.Percentile(99);
      Check(LVal > 3.0, '+Inf: Percentile(99) > 3.0');
    except end;
  except
    LNoCrash := False;
  end;
  LStats.Free;
  Check(LNoCrash, 'Infinity: Percentile survives without segfault');
end;

{ PF-06: Percentile range validation }
procedure Test_Percentile_RangeValidation;
var LData: TDoubleArray; LStats: TAdvancedStats;
  LCaught: Boolean;
begin
  LData := CreateTestData([1.0, 2.0, 3.0, 4.0, 5.0]);
  LStats := TAdvancedStats.Create(LData);
  try
    { Valid range should work }
    CheckNear(1.0, LStats.Percentile(0), 0.001, 'P0 valid');
    CheckNear(5.0, LStats.Percentile(100), 0.001, 'P100 valid');
    CheckNear(3.0, LStats.Percentile(50), 0.001, 'P50 valid');

    { Negative percentile should raise EBenchInvalidParam }
    LCaught := False;
    try
      LStats.Percentile(-1.0);
    except
      on E: EBenchInvalidParam do LCaught := True;
    end;
    Check(LCaught, 'Percentile(-1.0) raises EBenchInvalidParam');

    { Percentile > 100 should raise EBenchInvalidParam }
    LCaught := False;
    try
      LStats.Percentile(101.0);
    except
      on E: EBenchInvalidParam do LCaught := True;
    end;
    Check(LCaught, 'Percentile(101.0) raises EBenchInvalidParam');

    { Large negative percentile should raise EBenchInvalidParam }
    LCaught := False;
    try
      LStats.Percentile(-100.0);
    except
      on E: EBenchInvalidParam do LCaught := True;
    end;
    Check(LCaught, 'Percentile(-100.0) raises EBenchInvalidParam');

    { Large positive percentile should raise EBenchInvalidParam }
    LCaught := False;
    try
      LStats.Percentile(200.0);
    except
      on E: EBenchInvalidParam do LCaught := True;
    end;
    Check(LCaught, 'Percentile(200.0) raises EBenchInvalidParam');
  finally
    LStats.Free;
  end;
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

procedure Test_OutlierSeverity_None;
begin
  { Q1=25, Q3=75, IQR=50, value=50 (在中间) }
  Check(ClassifyOutlierSeverity(50, 25, 75) = osNone, 'Value at median is not outlier');
  { 值在 Q1-Q3 内 }
  Check(ClassifyOutlierSeverity(30, 25, 75) = osNone, 'Value in IQR is not outlier');
  Check(ClassifyOutlierSeverity(70, 25, 75) = osNone, 'Value in IQR is not outlier (high)');
end;

procedure Test_OutlierSeverity_Mild;
begin
  { Q1=25, Q3=75, IQR=50
    Mild: 距离 > 1.5*IQR = 75，但 < 3*IQR = 150
    下界: Q1 - 1.5*IQR = 25 - 75 = -50 → 值 < -50
    上界: Q3 + 1.5*IQR = 75 + 75 = 150 → 值 > 150 }
  Check(ClassifyOutlierSeverity(-60, 25, 75) = osMild, 'Below lower mild fence');
  Check(ClassifyOutlierSeverity(160, 25, 75) = osMild, 'Above upper mild fence');
end;

procedure Test_OutlierSeverity_Moderate;
begin
  { Q1=25, Q3=75, IQR=50
    Moderate: 距离 > 3*IQR = 150，但 < 10*IQR = 500
    下界: Q1 - 3*IQR = 25 - 150 = -125 → 值 < -125
    上界: Q3 + 3*IQR = 75 + 150 = 225 → 值 > 225 }
  Check(ClassifyOutlierSeverity(-130, 25, 75) = osModerate, 'Below moderate fence');
  Check(ClassifyOutlierSeverity(230, 25, 75) = osModerate, 'Above moderate fence');
end;

procedure Test_OutlierSeverity_Severe;
begin
  { Q1=25, Q3=75, IQR=50
    Severe: 距离 > 10*IQR = 500
    下界: Q1 - 10*IQR = 25 - 500 = -475
    上界: Q3 + 10*IQR = 75 + 500 = 575 }
  Check(ClassifyOutlierSeverity(-500, 25, 75) = osSevere, 'Below severe fence');
  Check(ClassifyOutlierSeverity(600, 25, 75) = osSevere, 'Above severe fence');
end;

procedure Test_OutlierSeverity_ZeroIQR;
begin
  { IQR=0: 所有值相同，不应分类为异常值 }
  Check(ClassifyOutlierSeverity(50, 50, 50) = osNone, 'Zero IQR returns osNone');
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
  T.Test('BootstrapCI_Empty', @Test_BootstrapCI_Empty);
  T.Test('BootstrapCI_Single', @Test_BootstrapCI_Single);
  T.Test('BootstrapCI_ZeroIterations', @Test_BootstrapCI_ZeroIterations);
  T.Test('BootstrapCI_LevelBoundary', @Test_BootstrapCI_LevelBoundary);
  T.Test('TestNormality', @Test_TestNormality);
  T.Test('CompareWith', @Test_CompareWith);
  T.Test('WelchTScore_SignificantDifference', @Test_WelchTScore_SignificantDifference);
  T.Test('WelchTScore_NoDifference', @Test_WelchTScore_NoDifference);
  T.Test('EffectSize', @Test_EffectSize);
  T.Test('EffectSize_LargeEffect', @Test_EffectSize_LargeEffect);
  T.Test('EffectSize_SameData', @Test_EffectSize_SameData);
  T.Test('EmptyData', @Test_EmptyData);
  T.Test('SingleValue', @Test_SingleValue);
  T.Test('NaNInput_NoCrash', @Test_NaNInput_NoCrash);
  T.Test('InfinityInput_NoCrash', @Test_InfinityInput_NoCrash);
  T.Test('NaNInfinity_Kurtosis', @Test_NaNInfinity_Kurtosis);
  T.Test('NaNInfinity_Percentile', @Test_NaNInfinity_Percentile);
  T.Test('Percentile_RangeValidation', @Test_Percentile_RangeValidation);
  T.Test('GetData', @Test_GetData);
  T.Test('Count', @Test_Count);
  T.Test('OutlierSeverity_None', @Test_OutlierSeverity_None);
  T.Test('OutlierSeverity_Mild', @Test_OutlierSeverity_Mild);
  T.Test('OutlierSeverity_Moderate', @Test_OutlierSeverity_Moderate);
  T.Test('OutlierSeverity_Severe', @Test_OutlierSeverity_Severe);
  T.Test('OutlierSeverity_ZeroIQR', @Test_OutlierSeverity_ZeroIQR);
  T.Run;
  T.Summary;
end.
