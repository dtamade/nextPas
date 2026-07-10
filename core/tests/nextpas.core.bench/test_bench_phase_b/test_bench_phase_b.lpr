{**
 * @desc Phase B 统计深化测试
 *
 * 测试 Xoroshiro128+ PRNG、BCa Bootstrap、Bootstrap 假设检验
 *}
program test_bench_phase_b;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats.advanced;

{ ===== Xoroshiro128+ PRNG 测试 ===== }

procedure Test_Xoroshiro128Plus_Init;
var
  LPRNG: TXoroshiro128Plus;
begin
  LPRNG.Init(12345);
  Check(LPRNG.S0 <> 0, 'S0 should not be 0');
  Check(LPRNG.S1 <> 0, 'S1 should not be 0');
end;

procedure Test_Xoroshiro128Plus_DifferentSeeds;
var
  LPRNG1, LPRNG2: TXoroshiro128Plus;
begin
  LPRNG1.Init(12345);
  LPRNG2.Init(67890);
  Check(LPRNG1.S0 <> LPRNG2.S0, 'Different seeds should produce different states');
end;

procedure Test_Xoroshiro128Plus_Next;
var
  LPRNG: TXoroshiro128Plus;
  LVal1, LVal2: UInt64;
begin
  LPRNG.Init(42);
  LVal1 := LPRNG.Next;
  LVal2 := LPRNG.Next;
  Check(LVal1 <> LVal2, 'Consecutive values should differ');
  Check(LVal1 <> 0, 'Value should not be 0');
end;

procedure Test_Xoroshiro128Plus_NextInt;
var
  LPRNG: TXoroshiro128Plus;
  LI: Integer;
  LVal: Integer;
  LCounts: array[0..9] of Integer;
begin
  LPRNG.Init(42);
  FillChar(LCounts, SizeOf(LCounts), 0);

  { 生成 10000 个 [0, 10) 范围内的随机数 }
  for LI := 0 to 9999 do
  begin
    LVal := LPRNG.NextInt(10);
    Check(LVal >= 0, 'Value should be >= 0');
    Check(LVal < 10, 'Value should be < 10');
    Inc(LCounts[LVal]);
  end;

  { 检查分布均匀性：每个桶应该有 ~1000 个，允许 20% 偏差 }
  for LI := 0 to 9 do
    Check(LCounts[LI] > 800, 'Distribution should be roughly uniform');
end;

procedure Test_Xoroshiro128Plus_ZeroSeed;
var
  LPRNG: TXoroshiro128Plus;
  LVal: UInt64;
begin
  LPRNG.Init(0);
  LVal := LPRNG.Next;
  Check(LVal <> 0, 'Should handle zero seed gracefully');
end;

{ ===== BCa Bootstrap 测试 ===== }

procedure Test_BootstrapCI_BCa_Normal;
var
  LStats: TAdvancedStats;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
  LI: Integer;
begin
  { 生成正态分布数据 N(100, 10) }
  SetLength(LData, 100);
  for LI := 0 to 99 do
    LData[LI] := 100.0 + (LI mod 20) - 10;

  LStats := TAdvancedStats.Create(LData);
  try
    LCI := LStats.BootstrapCI_BCa(10000, 0.95, 12345);
    Check(LCI.Lower < LCI.Upper, 'Lower should be < Upper');
    Check(Abs(LCI.Level - 0.95) < 0.001, 'Level should be 0.95');
    { 置信区间应该包含真实均值 100 }
    Check(LCI.Lower < 100.0, 'Lower should be < 100');
    Check(LCI.Upper > 100.0, 'Upper should be > 100');
  finally
    LStats.Free;
  end;
end;

procedure Test_BootstrapCI_BCa_Empty;
var
  LStats: TAdvancedStats;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
begin
  SetLength(LData, 0);
  LStats := TAdvancedStats.Create(LData);
  try
    LCI := LStats.BootstrapCI_BCa(1000, 0.95);
    Check(LCI.Lower = 0.0, 'Empty data should return 0');
    Check(LCI.Upper = 0.0, 'Empty data should return 0');
  finally
    LStats.Free;
  end;
end;

procedure Test_BootstrapCI_BCa_Single;
var
  LStats: TAdvancedStats;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
begin
  SetLength(LData, 1);
  LData[0] := 42.0;
  LStats := TAdvancedStats.Create(LData);
  try
    LCI := LStats.BootstrapCI_BCa(1000, 0.95);
    Check(LCI.Lower = 42.0, 'Single value should return that value');
    Check(LCI.Upper = 42.0, 'Single value should return that value');
  finally
    LStats.Free;
  end;
end;

procedure Test_BootstrapCI_BCa_Skewed;
var
  LStats: TAdvancedStats;
  LData: TDoubleArray;
  LCI_BCa: TConfidenceInterval;
  LI: Integer;
begin
  { 生成右偏数据：指数分布 }
  SetLength(LData, 100);
  for LI := 0 to 99 do
    LData[LI] := LI * 0.1; { 线性增长，右偏 }

  LStats := TAdvancedStats.Create(LData);
  try
    LCI_BCa := LStats.BootstrapCI_BCa(10000, 0.95, 12345);

    { BCa 应该产生不同的置信区间（更准确） }
    Check(LCI_BCa.Lower < LCI_BCa.Upper, 'BCa Lower should be < Upper');
    { 对于右偏数据，BCa 的下界通常比百分位数法更高 }
  finally
    LStats.Free;
  end;
end;

{ ===== Bootstrap 假设检验测试 ===== }

procedure Test_BootstrapTestDifference_Same;
var
  LA, LB: TDoubleArray;
  LResult: TBootstrapTestResult;
  LI: Integer;
begin
  { 两组相同的数据 }
  SetLength(LA, 50);
  SetLength(LB, 50);
  for LI := 0 to 49 do
  begin
    LA[LI] := 100.0 + (LI mod 10);
    LB[LI] := 100.0 + (LI mod 10);
  end;

  LResult := BootstrapTestDifference(LA, LB, 10000, 12345);
  Check(LResult.ObservedDiff = 0.0, 'Observed diff should be 0');
  Check(not LResult.IsSignificant, 'Same data should not be significant');
  Check(LResult.PValue > 0.5, 'p-value should be high for same data');
end;

procedure Test_BootstrapTestDifference_Different;
var
  LA, LB: TDoubleArray;
  LResult: TBootstrapTestResult;
  LI: Integer;
  LMeanA, LMeanB: Double;
begin
  { 两组明显不同的数据 }
  SetLength(LA, 50);
  SetLength(LB, 50);
  LMeanA := 0;
  LMeanB := 0;
  for LI := 0 to 49 do
  begin
    LA[LI] := 100.0 + (LI mod 5);
    LB[LI] := 200.0 + (LI mod 5);
    LMeanA := LMeanA + LA[LI];
    LMeanB := LMeanB + LB[LI];
  end;
  LMeanA := LMeanA / 50;
  LMeanB := LMeanB / 50;

  LResult := BootstrapTestDifference(LA, LB, 10000, 12345);
  { 均值应该是 102 和 202，差为 100 }
  Check(Abs(LResult.ObservedDiff - (LMeanA - LMeanB)) < 0.01, 'Observed diff should match mean difference');
  Check(LResult.IsSignificant, 'Different data should be significant');
  Check(LResult.PValue < 0.01, 'p-value should be very low');
end;

procedure Test_BootstrapTestDifference_Empty;
var
  LA, LB: TDoubleArray;
  LCaught: Boolean;
begin
  SetLength(LA, 0);
  SetLength(LB, 50);
  LCaught := False;
  try
    BootstrapTestDifference(LA, LB, 1000, 12345);
  except
    on E: EBenchInvalidParam do LCaught := True;
  end;
  Check(LCaught, 'Empty array should raise EBenchInvalidParam');
end;

procedure Test_BootstrapTestDifference_WeakDifference;
var
  LA, LB: TDoubleArray;
  LResult: TBootstrapTestResult;
  LI: Integer;
  LMeanA, LMeanB: Double;
begin
  { 两组数据有微弱差异 }
  SetLength(LA, 100);
  SetLength(LB, 100);
  LMeanA := 0;
  LMeanB := 0;
  for LI := 0 to 99 do
  begin
    LA[LI] := 100.0 + (LI mod 20) - 10;
    LB[LI] := 102.0 + (LI mod 20) - 10; { 均值差 2 }
    LMeanA := LMeanA + LA[LI];
    LMeanB := LMeanB + LB[LI];
  end;
  LMeanA := LMeanA / 100;
  LMeanB := LMeanB / 100;

  LResult := BootstrapTestDifference(LA, LB, 10000, 12345);
  Check(Abs(LResult.ObservedDiff - (LMeanA - LMeanB)) < 0.01, 'Observed diff should match mean difference');
  { 微弱差异可能不显著 }
  Check(LResult.PValue > 0.0, 'p-value should be positive');
end;

{ ===== 注册测试 ===== }

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  T := TTestSuite.Create('bench-phase-b');

  { Xoroshiro128+ PRNG }
  T.Test('Xoroshiro128Plus_Init', @Test_Xoroshiro128Plus_Init);
  T.Test('Xoroshiro128Plus_DifferentSeeds', @Test_Xoroshiro128Plus_DifferentSeeds);
  T.Test('Xoroshiro128Plus_Next', @Test_Xoroshiro128Plus_Next);
  T.Test('Xoroshiro128Plus_NextInt', @Test_Xoroshiro128Plus_NextInt);
  T.Test('Xoroshiro128Plus_ZeroSeed', @Test_Xoroshiro128Plus_ZeroSeed);

  { BCa Bootstrap }
  T.Test('BootstrapCI_BCa_Normal', @Test_BootstrapCI_BCa_Normal);
  T.Test('BootstrapCI_BCa_Empty', @Test_BootstrapCI_BCa_Empty);
  T.Test('BootstrapCI_BCa_Single', @Test_BootstrapCI_BCa_Single);
  T.Test('BootstrapCI_BCa_Skewed', @Test_BootstrapCI_BCa_Skewed);

  { Bootstrap 假设检验 }
  T.Test('BootstrapTestDifference_Same', @Test_BootstrapTestDifference_Same);
  T.Test('BootstrapTestDifference_Different', @Test_BootstrapTestDifference_Different);
  T.Test('BootstrapTestDifference_Empty', @Test_BootstrapTestDifference_Empty);
  T.Test('BootstrapTestDifference_WeakDifference', @Test_BootstrapTestDifference_WeakDifference);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
