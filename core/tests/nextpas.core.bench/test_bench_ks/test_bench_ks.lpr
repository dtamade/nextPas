program test_bench_ks;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.test;

var
  T: TTestSuite;

{ 辅助函数：生成正态分布数据（Box-Muller 变换） }
function GenerateNormalData(AMean, AStdDev: Double; ACount: Integer): TDoubleArray;
var
  I: Integer;
  LU1, LU2: Double;
begin
  SetLength(Result, ACount);
  RandSeed := 42; // 固定种子，可重现
  for I := 0 to ACount - 1 do
  begin
    LU1 := Random;
    LU2 := Random;
    if LU1 < 1e-10 then
      LU1 := 1e-10;
    // Box-Muller 变换
    Result[I] := AMean + AStdDev * Sqrt(-2.0 * Ln(LU1)) * Cos(2.0 * Pi * LU2);
  end;
end;

{ 辅助函数：生成均匀分布数据 }
function GenerateUniformData(ALow, AHigh: Double; ACount: Integer): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  RandSeed := 42;
  for I := 0 to ACount - 1 do
    Result[I] := ALow + (AHigh - ALow) * Random;
end;

{ 测试 1: 空数组单样本 K-S 检验 }
procedure TestKSTestNormal_EmptyData;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(nil, 0, 1);
  Check(LResult.Statistic = 0.0, 'Empty data: D = 0');
  Check(LResult.PValue = 1.0, 'Empty data: p-value = 1');
  Check(not LResult.IsSignificant, 'Empty data: not significant');
  Check(LResult.SampleSize1 = 0, 'Empty data: n = 0');
end;

{ 测试 2: 单元素数组单样本 K-S 检验 }
procedure TestKSTestNormal_SingleElement;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LData: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  SetLength(LData, 1);
  LData[0] := 5.0;
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 5.0, 1.0);
  Check(LResult.Statistic = 0.0, 'Single element: D = 0');
  Check(LResult.PValue = 1.0, 'Single element: p-value = 1');
  Check(not LResult.IsSignificant, 'Single element: not significant');
end;

{ 测试 3: 标准正态分布数据应通过正态性检验 }
procedure TestKSTestNormal_NormalData;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LData: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  // 生成 100 个 N(0,1) 样本
  LData := GenerateNormalData(0.0, 1.0, 100);
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 0.0, 1.0);
  Check(LResult.SampleSize1 = 100, 'Normal data: n = 100');
  Check(LResult.Statistic > 0.0, 'Normal data: D > 0');
  Check(LResult.Statistic < 0.3, 'Normal data: D < 0.3 (should be small for normal)');
  // 正态数据不应显著（即不应拒绝正态假设）
  Check(not LResult.IsSignificant, 'Normal data: not significant (p > 0.05)');
end;

{ 测试 4: 均匀分布数据应拒绝正态性检验 }
procedure TestKSTestNormal_UniformData;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LData: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  // 生成 200 个 U(0,1) 样本，检验是否来自 N(0.5, 0.15²)
  // 均匀分布的尾部与正态分布差异大，应该被检测出来
  LData := GenerateUniformData(0.0, 1.0, 200);
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 0.5, 0.15);
  Check(LResult.SampleSize1 = 200, 'Uniform data: n = 200');
  Check(LResult.Statistic > 0.1, 'Uniform data: D > 0.1 (should be large)');
  // 均匀分布与正态分布差异大，应该显著
  Check(LResult.IsSignificant, 'Uniform data: significant (reject normality)');
end;

{ 测试 5: 标准差为 0 时的边界处理 }
procedure TestKSTestNormal_ZeroStdDev;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LData: TDoubleArray;
  LResult: TKSTestResult;
  I: Integer;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  SetLength(LData, 10);
  // 所有值相同
  for I := 0 to 9 do
    LData[I] := 5.0;
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 5.0, 0.0);
  Check(LResult.Statistic = 0.0, 'Zero StdDev: D = 0');
  Check(LResult.PValue = 1.0, 'Zero StdDev: p-value = 1');
  Check(not LResult.IsSignificant, 'Zero StdDev: not significant');
end;

{ 测试 6: 两样本 K-S 检验 - 相同分布 }
procedure TestKSTestTwoSample_SameDistribution;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA, LB: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  // 两个来自同一正态分布的样本
  LA := GenerateNormalData(0.0, 1.0, 50);
  LB := GenerateNormalData(0.0, 1.0, 50);
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, LB);
  Check(LResult.SampleSize1 = 50, 'Same dist: n1 = 50');
  Check(LResult.SampleSize2 = 50, 'Same dist: n2 = 50');
  Check(LResult.Statistic >= 0.0, 'Same dist: D >= 0');
  // 来自同一分布的样本不应显著
  Check(not LResult.IsSignificant, 'Same dist: not significant (same distribution)');
end;

{ 测试 7: 两样本 K-S 检验 - 不同分布 }
procedure TestKSTestTwoSample_DifferentDistribution;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA, LB: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  // 一个正态，一个均匀，差异明显
  LA := GenerateNormalData(0.0, 1.0, 200);
  LB := GenerateUniformData(-3.0, 3.0, 200);
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, LB);
  Check(LResult.SampleSize1 = 200, 'Diff dist: n1 = 200');
  Check(LResult.SampleSize2 = 200, 'Diff dist: n2 = 200');
  Check(LResult.Statistic > 0.1, 'Diff dist: D > 0.1');
  // 不同分布应该显著
  Check(LResult.IsSignificant, 'Diff dist: significant (different distributions)');
end;

{ 测试 8: 两样本 K-S 检验 - 空数组 }
procedure TestKSTestTwoSample_EmptyData;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(nil, nil);
  Check(LResult.Statistic = 0.0, 'Empty: D = 0');
  Check(LResult.PValue = 1.0, 'Empty: p-value = 1');
  Check(not LResult.IsSignificant, 'Empty: not significant');
end;

{ 测试 9: 两样本 K-S 检验 - 一个空一个非空 }
procedure TestKSTestTwoSample_OneEmpty;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA: TDoubleArray;
  LResult: TKSTestResult;
  I: Integer;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  SetLength(LA, 5);
  for I := 0 to 4 do
    LA[I] := I;
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, nil);
  Check(LResult.Statistic = 0.0, 'One empty: D = 0');
  Check(LResult.PValue = 1.0, 'One empty: p-value = 1');
  Check(not LResult.IsSignificant, 'One empty: not significant');
end;

{ 测试 10: 两样本 K-S 检验 - 不同均值 }
procedure TestKSTestTwoSample_DifferentMeans;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA, LB: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  // 两个正态分布，均值差异大
  LA := GenerateNormalData(0.0, 1.0, 100);
  LB := GenerateNormalData(5.0, 1.0, 100);
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, LB);
  Check(LResult.Statistic > 0.5, 'Diff means: D > 0.5 (large separation)');
  Check(LResult.IsSignificant, 'Diff means: significant');
end;

{ 测试 11: 两样本 K-S 检验 - 不同样本大小 }
procedure TestKSTestTwoSample_DifferentSizes;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA, LB: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  LA := GenerateNormalData(0.0, 1.0, 30);
  LB := GenerateNormalData(0.0, 1.0, 100);
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, LB);
  Check(LResult.SampleSize1 = 30, 'Diff sizes: n1 = 30');
  Check(LResult.SampleSize2 = 100, 'Diff sizes: n2 = 100');
  // 来自同一分布，不应显著
  Check(not LResult.IsSignificant, 'Diff sizes: not significant (same distribution)');
end;

{ 测试 12: K-S 统计量范围检查 }
procedure TestKSTest_StatisticRange;
var
  LAnalyzer: IBenchStatsAnalyzer;
  LA, LB: TDoubleArray;
  LResult: TKSTestResult;
begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  LA := GenerateNormalData(0.0, 1.0, 50);
  LB := GenerateUniformData(0.0, 1.0, 50);
  LResult := LAnalyzer.KolmogorovSmirnovTwoSampleTest(LA, LB);
  Check(LResult.Statistic >= 0.0, 'Range: D >= 0');
  Check(LResult.Statistic <= 1.0, 'Range: D <= 1');
  Check(LResult.PValue >= 0.0, 'Range: p-value >= 0');
  Check(LResult.PValue <= 1.0, 'Range: p-value <= 1');
end;

begin
  T := TTestSuite.Create('nextpas.core.bench.ks');
  T.Test('KSTestNormal_EmptyData', @TestKSTestNormal_EmptyData);
  T.Test('KSTestNormal_SingleElement', @TestKSTestNormal_SingleElement);
  T.Test('KSTestNormal_NormalData', @TestKSTestNormal_NormalData);
  T.Test('KSTestNormal_UniformData', @TestKSTestNormal_UniformData);
  T.Test('KSTestNormal_ZeroStdDev', @TestKSTestNormal_ZeroStdDev);
  T.Test('KSTestTwoSample_SameDistribution', @TestKSTestTwoSample_SameDistribution);
  T.Test('KSTestTwoSample_DifferentDistribution', @TestKSTestTwoSample_DifferentDistribution);
  T.Test('KSTestTwoSample_EmptyData', @TestKSTestTwoSample_EmptyData);
  T.Test('KSTestTwoSample_OneEmpty', @TestKSTestTwoSample_OneEmpty);
  T.Test('KSTestTwoSample_DifferentMeans', @TestKSTestTwoSample_DifferentMeans);
  T.Test('KSTestTwoSample_DifferentSizes', @TestKSTestTwoSample_DifferentSizes);
  T.Test('KSTest_StatisticRange', @TestKSTest_StatisticRange);
  T.Run;
  T.Summary;
end.
