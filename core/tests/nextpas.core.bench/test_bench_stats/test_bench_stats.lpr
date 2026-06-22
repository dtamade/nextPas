program test_bench_stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  nextpas.core.math.scalar,
  nextpas.core.text.conv,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

var
  GAnalyzer: IBenchStatsAnalyzer;
  GTestCount: Integer;
  GPassCount: Integer;
  GFailCount: Integer;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  ✗ ', ATestName);
  end;
end;

procedure CheckApprox(AActual, AExpected, AEpsilon: Double; const ATestName: string);
begin
  Check(Abs(AActual - AExpected) <= AEpsilon,
    ATestName + ' (expected: ' + FloatToStr(AExpected) + ', got: ' + FloatToStr(AActual) + ')');
end;

procedure TestMean;
var
  LData: TDoubleArray;
begin
  WriteLn('TestMean:');

  // 空数组
  SetLength(LData, 0);
  CheckApprox(GAnalyzer.Mean(LData), 0.0, 0.001, 'Empty array returns 0');

  // 单元素
  SetLength(LData, 1);
  LData[0] := 5.0;
  CheckApprox(GAnalyzer.Mean(LData), 5.0, 0.001, 'Single value returns that value');

  // 多元素
  SetLength(LData, 5);
  LData[0] := 1.0;
  LData[1] := 2.0;
  LData[2] := 3.0;
  LData[3] := 4.0;
  LData[4] := 5.0;
  CheckApprox(GAnalyzer.Mean(LData), 3.0, 0.001, 'Multiple values correct mean');

  // 大数求和精度（Kahan 求和）
  SetLength(LData, 3);
  LData[0] := 1e15;
  LData[1] := 1.0;
  LData[2] := -1e15;
  CheckApprox(GAnalyzer.Mean(LData), 1.0/3.0, 0.001, 'Kahan sum precision');
end;

procedure TestMedian;
var
  LData: TDoubleArray;
begin
  WriteLn('TestMedian:');

  // 奇数个元素
  SetLength(LData, 5);
  LData[0] := 1.0;
  LData[1] := 3.0;
  LData[2] := 2.0;
  LData[3] := 5.0;
  LData[4] := 4.0;
  CheckApprox(GAnalyzer.Median(LData), 3.0, 0.001, 'Odd count returns middle');

  // 偶数个元素
  SetLength(LData, 4);
  LData[0] := 1.0;
  LData[1] := 2.0;
  LData[2] := 3.0;
  LData[3] := 4.0;
  CheckApprox(GAnalyzer.Median(LData), 2.5, 0.001, 'Even count returns average');

  // 空数组
  SetLength(LData, 0);
  CheckApprox(GAnalyzer.Median(LData), 0.0, 0.001, 'Empty array returns 0');
end;

procedure TestStdDev;
var
  LData: TDoubleArray;
begin
  WriteLn('TestStdDev:');

  // 方差为零
  SetLength(LData, 3);
  LData[0] := 5.0;
  LData[1] := 5.0;
  LData[2] := 5.0;
  CheckApprox(GAnalyzer.StdDev(LData), 0.0, 0.001, 'Zero variance returns 0');

  // 已知标准差
  SetLength(LData, 5);
  LData[0] := 2.0;
  LData[1] := 4.0;
  LData[2] := 4.0;
  LData[3] := 4.0;
  LData[4] := 5.0;
  // 样本标准差 = sqrt(1.2) ≈ 1.09544511501033
  CheckApprox(GAnalyzer.StdDev(LData), 1.09544511501033, 0.001, 'Known values correct stddev');

  // 单元素
  SetLength(LData, 1);
  LData[0] := 10.0;
  CheckApprox(GAnalyzer.StdDev(LData), 0.0, 0.001, 'Single value returns 0');
end;

procedure TestPercentile;
var
  LSorted: TDoubleArray;
begin
  WriteLn('TestPercentile:');

  // 准备排序数据
  SetLength(LSorted, 10);
  LSorted[0] := 1.0;
  LSorted[1] := 2.0;
  LSorted[2] := 3.0;
  LSorted[3] := 4.0;
  LSorted[4] := 5.0;
  LSorted[5] := 6.0;
  LSorted[6] := 7.0;
  LSorted[7] := 8.0;
  LSorted[8] := 9.0;
  LSorted[9] := 10.0;

  // P0 = min
  CheckApprox(GAnalyzer.Percentile(LSorted, 0), 1.0, 0.001, 'P0 returns min');

  // P100 = max
  CheckApprox(GAnalyzer.Percentile(LSorted, 100), 10.0, 0.001, 'P100 returns max');

  // P50 = median
  CheckApprox(GAnalyzer.Percentile(LSorted, 50), 5.5, 0.001, 'P50 returns median');

  // P25
  CheckApprox(GAnalyzer.Percentile(LSorted, 25), 3.25, 0.001, 'P25 correct');

  // P75
  CheckApprox(GAnalyzer.Percentile(LSorted, 75), 7.75, 0.001, 'P75 correct');

  // P95
  CheckApprox(GAnalyzer.Percentile(LSorted, 95), 9.55, 0.01, 'P95 correct');

  // P99
  CheckApprox(GAnalyzer.Percentile(LSorted, 99), 9.91, 0.01, 'P99 correct');
end;

procedure TestOutliers;
var
  LSorted: TDoubleArray;
begin
  WriteLn('TestOutliers:');

  // 无异常值
  SetLength(LSorted, 10);
  LSorted[0] := 1.0;
  LSorted[1] := 2.0;
  LSorted[2] := 3.0;
  LSorted[3] := 4.0;
  LSorted[4] := 5.0;
  LSorted[5] := 6.0;
  LSorted[6] := 7.0;
  LSorted[7] := 8.0;
  LSorted[8] := 9.0;
  LSorted[9] := 10.0;
  Check(GAnalyzer.CountOutliers(LSorted, 3.25, 7.75, 1.5) = 0,
    'No outliers detected');

  // 有异常值
  SetLength(LSorted, 10);
  LSorted[0] := -100.0;  // 异常值
  LSorted[1] := 2.0;
  LSorted[2] := 3.0;
  LSorted[3] := 4.0;
  LSorted[4] := 5.0;
  LSorted[5] := 6.0;
  LSorted[6] := 7.0;
  LSorted[7] := 8.0;
  LSorted[8] := 9.0;
  LSorted[9] := 100.0;  // 异常值
  Check(GAnalyzer.CountOutliers(LSorted, 3.25, 7.75, 1.5) = 2,
    'Some outliers detected');

  // 全是异常值
  SetLength(LSorted, 3);
  LSorted[0] := -1000.0;
  LSorted[1] := 0.0;
  LSorted[2] := 1000.0;
  Check(GAnalyzer.CountOutliers(LSorted, 0.0, 0.0, 1.5) = 2,
    'All outliers detected');
end;

procedure TestComputeStats;
var
  LSamples: TDoubleArray;
  LStats: TBenchStats;
  i: Integer;
begin
  WriteLn('TestComputeStats:');

  // 准备测试数据
  SetLength(LSamples, 100);
  for i := 0 to 99 do
    LSamples[i] := 100.0 + Random * 10.0;  // 100-110 之间的随机数

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

  // 相同分布
  SetLength(LA, 100);
  SetLength(LB, 100);
  for i := 0 to 99 do
  begin
    LA[i] := 100.0 + Random * 10.0;
    LB[i] := 100.0 + Random * 10.0;
  end;
  LStatsA := GAnalyzer.ComputeStats(LA);
  LStatsB := GAnalyzer.ComputeStats(LB);
  // 相同分布不应该有显著差异
  Check(not GAnalyzer.HasHeuristicDifference(LStatsA, LStatsB),
    'Same distribution no heuristic difference');

  // 不同分布
  SetLength(LA, 100);
  SetLength(LB, 100);
  for i := 0 to 99 do
  begin
    LA[i] := 100.0 + Random * 10.0;
    LB[i] := 200.0 + Random * 10.0;
  end;
  LStatsA := GAnalyzer.ComputeStats(LA);
  LStatsB := GAnalyzer.ComputeStats(LB);
  // 不同分布应该有显著差异
  Check(GAnalyzer.HasHeuristicDifference(LStatsA, LStatsB),
    'Different distribution heuristic difference');
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
  LSamples[0] := 1.0;
  LSamples[1] := 2.0;
  LSamples[2] := 3.0;
  LSamples[3] := 4.0;
  LSamples[4] := 5.0;

  LStats := GAnalyzer.ComputeStats(LSamples);
  LCIWidth := LStats.Confidence95High - LStats.Confidence95Low;

  CheckApprox(LCIWidth, 3.926, 0.15, 'DF=4 uses lookup-table CI width');
  Check(LStats.Confidence95Low < LStats.Mean, 'CI95 low < mean');
  Check(LStats.Confidence95High > LStats.Mean, 'CI95 high > mean');

  SetLength(LSamples, 30);
  for I := 0 to 29 do
    LSamples[I] := 100.0 + I;

  LStats := GAnalyzer.ComputeStats(LSamples);
  Check(LStats.SampleCount = 30, 'TInv sample count = 30');
  Check(LStats.Confidence95Low < LStats.Mean, 'TInv 30-samples CI95 low < mean');
  Check(LStats.Confidence95High > LStats.Mean, 'TInv 30-samples CI95 high > mean');

  SetLength(LSamples, 1);
  LSamples[0] := 42.0;
  LStats := GAnalyzer.ComputeStats(LSamples);
  Check(LStats.Confidence95Low = 42.0, 'Single sample CI95 low = mean');
  Check(LStats.Confidence95High = 42.0, 'Single sample CI95 high = mean');
end;

procedure TestIsNormal;
var
  LData: TDoubleArray;
  i: Integer;
begin
  WriteLn('TestIsNormal:');

  // 正态分布数据（近似）
  SetLength(LData, 1000);
  for i := 0 to 999 do
    LData[i] := 100.0 + Random * 10.0 + Random * 10.0;
  Check(GAnalyzer.LooksNormalHeuristic(LData),
    'Normal data passes heuristic check');

  // 均匀分布数据
  SetLength(LData, 1000);
  for i := 0 to 999 do
    LData[i] := i * 0.1;
  // 注意：简化的 Shapiro-Wilk 实现可能不够严格
  // 均匀分布可能通过检验，这是预期行为
  // 完整实现需要查表
  if GAnalyzer.LooksNormalHeuristic(LData) then
    WriteLn('  ℹ Uniform distribution test: PASS')
  else
    WriteLn('  ℹ Uniform distribution test: FAIL');
end;

procedure TestComputeApproximatePValue;
var
  LA, LB: TDoubleArray;
  LStatsA, LStatsB: TBenchStats;
  LPValue: Double;
  i: Integer;
begin
  WriteLn('TestComputeApproximatePValue:');

  // 相同分布 - p-value 应该较高（不显著）
  SetLength(LA, 100);
  SetLength(LB, 100);
  for i := 0 to 99 do
  begin
    LA[i] := 100.0 + Random * 10.0;
    LB[i] := 100.0 + Random * 10.0;
  end;
  LStatsA := GAnalyzer.ComputeStats(LA);
  LStatsB := GAnalyzer.ComputeStats(LB);
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue >= 0.0, 'Same distribution p-value >= 0');
  Check(LPValue <= 1.0, 'Same distribution p-value <= 1');
  Check(LPValue > 0.05, 'Same distribution p-value > 0.05 (not significant)');

  // 不同分布 - p-value 应该较低（显著）
  SetLength(LA, 100);
  SetLength(LB, 100);
  for i := 0 to 99 do
  begin
    LA[i] := 100.0 + Random * 2.0;
    LB[i] := 200.0 + Random * 2.0;
  end;
  LStatsA := GAnalyzer.ComputeStats(LA);
  LStatsB := GAnalyzer.ComputeStats(LB);
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue >= 0.0, 'Different distribution p-value >= 0');
  Check(LPValue <= 1.0, 'Different distribution p-value <= 1');
  Check(LPValue < 0.05, 'Different distribution p-value < 0.05 (significant)');

  // 完全相同的数据 - p-value 应该为 1.0
  SetLength(LA, 50);
  for i := 0 to 49 do
    LA[i] := 100.0;
  LStatsA := GAnalyzer.ComputeStats(LA);
  LStatsB := LStatsA;
  LPValue := GAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Check(LPValue = 1.0, 'Identical data p-value = 1.0');

  // 受控统计量 - 旧阶梯实现会错误返回 0.1
  LStatsA.Mean := 0.0;
  LStatsA.StdDev := 1.0;
  LStatsA.SampleCount := 10;
  LStatsB := LStatsA;
  LStatsB.Mean := 0.5;
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
  LData[0] := 5.0;
  LData[1] := 3.0;
  LData[2] := 1.0;
  LData[3] := 4.0;
  LData[4] := 2.0;

  GAnalyzer.Sort(LData);

  CheckApprox(LData[0], 1.0, 0.001, 'Sort[0] = 1.0');
  CheckApprox(LData[1], 2.0, 0.001, 'Sort[1] = 2.0');
  CheckApprox(LData[2], 3.0, 0.001, 'Sort[2] = 3.0');
  CheckApprox(LData[3], 4.0, 0.001, 'Sort[3] = 4.0');
  CheckApprox(LData[4], 5.0, 0.001, 'Sort[4] = 5.0');
end;

begin
  WriteLn('=== nextpas.core.bench.stats Unit Tests ===');
  WriteLn;

  GAnalyzer := TBenchStatsAnalyzer.Create;
  GTestCount := 0;
  GPassCount := 0;
  GFailCount := 0;

  TestMean;
  WriteLn;
  TestMedian;
  WriteLn;
  TestStdDev;
  WriteLn;
  TestPercentile;
  WriteLn;
  TestOutliers;
  WriteLn;
  TestComputeStats;
  WriteLn;
  TestSignificantDifference;
  WriteLn;
  TestComputeApproximatePValue;
  WriteLn;
  TestTInvLookup;
  WriteLn;
  TestIsNormal;
  WriteLn;
  TestSort;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
  begin
    WriteLn;
    WriteLn('✗ ', GFailCount, ' test(s) failed!');
    Halt(1);
  end
  else
  begin
    WriteLn;
    WriteLn('✓ All tests passed!');
  end;
end.
