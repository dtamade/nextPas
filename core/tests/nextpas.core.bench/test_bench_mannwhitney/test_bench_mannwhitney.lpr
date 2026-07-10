program test_bench_mannwhitney;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

var
  GAnalyzer: IBenchStatsAnalyzer;

{ 相同分布：两组来自同一分布，p-value 应 > 0.05 }
procedure TestSameDistribution;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 50);
  SetLength(LB, 50);
  for I := 0 to 49 do
  begin
    LA[I] := 100.0 + Random * 10.0;
    LB[I] := 100.0 + Random * 10.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP >= 0.0, 'Same dist p >= 0');
  Check(LP <= 1.0, 'Same dist p <= 1');
  Check(LP > 0.01, 'Same dist p > 0.01 (not significant)');
end;

{ 显著不同分布：均值差 10 倍标准差，p-value 应极小 }
procedure TestDifferentDistribution;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 50);
  SetLength(LB, 50);
  for I := 0 to 49 do
  begin
    LA[I] := 100.0 + Random * 2.0;
    LB[I] := 200.0 + Random * 2.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP >= 0.0, 'Diff dist p >= 0');
  Check(LP <= 1.0, 'Diff dist p <= 1');
  Check(LP < 0.001, 'Diff dist p < 0.001 (highly significant)');
end;

{ 完全相同的数据：p-value = 1.0 }
procedure TestIdenticalData;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  SetLength(LA, 30);
  SetLength(LB, 30);
  for I := 0 to 29 do
  begin
    LA[I] := 50.0 + I;
    LB[I] := 50.0 + I;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP > 0.5, 'Identical data p > 0.5');
end;

{ 边界条件：空数组 }
procedure TestEmptyArrays;
var
  LA, LB: TDoubleArray;
  LP: Double;
begin
  SetLength(LA, 0);
  SetLength(LB, 10);
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP = 1.0, 'Empty A returns 1.0');

  SetLength(LA, 10);
  SetLength(LB, 0);
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP = 1.0, 'Empty B returns 1.0');

  SetLength(LA, 0);
  SetLength(LB, 0);
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP = 1.0, 'Both empty returns 1.0');
end;

{ 单元素数组 }
procedure TestSingleElement;
var
  LA, LB: TDoubleArray;
  LP: Double;
begin
  SetLength(LA, 1);
  SetLength(LB, 1);
  LA[0] := 10.0;
  LB[0] := 10.0;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP = 1.0, 'Same single element p = 1.0');

  LA[0] := 10.0;
  LB[0] := 20.0;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP > 0.0, 'Different single elements p > 0');
end;

{ 并列值处理：大量 tied ranks }
procedure TestManyTies;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  { 全部并列：两组数据完全相同 }
  SetLength(LA, 30);
  SetLength(LB, 30);
  for I := 0 to 29 do
  begin
    LA[I] := 100.0;
    LB[I] := 100.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP > 0.5, 'All tied data p > 0.5');

  { 部分并列：38/40 相同，2 个极值有系统性偏移 }
  SetLength(LA, 40);
  SetLength(LB, 40);
  for I := 0 to 39 do
  begin
    LA[I] := 100.0;
    LB[I] := 100.0;
  end;
  LA[0] := 95.0;
  LA[1] := 96.0;
  LB[38] := 104.0;
  LB[39] := 105.0;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP >= 0.0, 'Many ties p >= 0');
  Check(LP <= 1.0, 'Many ties p <= 1');
end;

{ 小样本（n=5 每组）}
procedure TestSmallSample;
var
  LA, LB: TDoubleArray;
  LP: Double;
begin
  SetLength(LA, 5);
  SetLength(LB, 5);
  LA[0] := 1.0; LA[1] := 2.0; LA[2] := 3.0; LA[3] := 4.0; LA[4] := 5.0;
  LB[0] := 6.0; LB[1] := 7.0; LB[2] := 8.0; LB[3] := 9.0; LB[4] := 10.0;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  { 完全不重叠，应有极小的 p-value }
  Check(LP < 0.05, 'Non-overlapping small samples p < 0.05');
end;

{ 右偏数据：模拟真实基准分布（偶尔的高延迟尾部） }
procedure TestRightSkewed;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 100);
  SetLength(LB, 100);
  for I := 0 to 99 do
  begin
    { 基础值 100 + 小波动 }
    LA[I] := 100.0 + Random * 5.0;
    LB[I] := 105.0 + Random * 5.0;
  end;
  { 添加右偏长尾（模拟 GC 暂停） }
  LA[95] := 200.0;
  LA[96] := 250.0;
  LA[97] := 300.0;
  LB[95] := 210.0;
  LB[96] := 260.0;
  LB[97] := 310.0;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP >= 0.0, 'Right-skewed p >= 0');
  Check(LP <= 1.0, 'Right-skewed p <= 1');
  { Mann-Whitney U 对右偏数据比 t-test 更可靠 }
end;

{ 大样本（n=500）验证正态近似 }
procedure TestLargeSample;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 500);
  SetLength(LB, 500);
  for I := 0 to 499 do
  begin
    LA[I] := 100.0 + Random * 10.0;
    LB[I] := 100.0 + Random * 10.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP > 0.05, 'Large same-dist p > 0.05');

  for I := 0 to 499 do
  begin
    LA[I] := 100.0 + Random * 10.0;
    LB[I] := 110.0 + Random * 10.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP < 0.001, 'Large diff-dist p < 0.001');
end;

{ 边际差异：两组数据有微小差异 }
procedure TestMarginalDifference;
var
  LA, LB: TDoubleArray;
  LP: Double;
  I: Integer;
begin
  RandSeed := 42;
  SetLength(LA, 200);
  SetLength(LB, 200);
  for I := 0 to 199 do
  begin
    { 1% 差异，大噪声 }
    LA[I] := 100.0 + Random * 20.0;
    LB[I] := 101.0 + Random * 20.0;
  end;
  LP := GAnalyzer.ComputeMannWhitneyPValue(LA, LB);
  Check(LP >= 0.0, 'Marginal p >= 0');
  Check(LP <= 1.0, 'Marginal p <= 1');
  { 1% 差异在大噪声下通常不显著 }
end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  GAnalyzer := TBenchStatsAnalyzer.Create;
  T := TTestSuite.Create('nextpas.core.bench.mannwhitney');

  T.Test('SameDistribution', @TestSameDistribution);
  T.Test('DifferentDistribution', @TestDifferentDistribution);
  T.Test('IdenticalData', @TestIdenticalData);
  T.Test('EmptyArrays', @TestEmptyArrays);
  T.Test('SingleElement', @TestSingleElement);
  T.Test('ManyTies', @TestManyTies);
  T.Test('SmallSample', @TestSmallSample);
  T.Test('RightSkewed', @TestRightSkewed);
  T.Test('LargeSample', @TestLargeSample);
  T.Test('MarginalDifference', @TestMarginalDifference);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
