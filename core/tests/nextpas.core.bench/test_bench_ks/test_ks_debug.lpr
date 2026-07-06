program test_ks_debug;

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

var
  LAnalyzer: IBenchStatsAnalyzer;
  LData: TDoubleArray;
  LResult: TKSTestResult;
  I: Integer;

function GenerateNormalData(AMean, AStdDev: Double; ACount: Integer): TDoubleArray;
var
  I: Integer;
  LU1, LU2: Double;
begin
  SetLength(Result, ACount);
  RandSeed := 42;
  for I := 0 to ACount - 1 do
  begin
    LU1 := Random;
    LU2 := Random;
    if LU1 < 1e-10 then
      LU1 := 1e-10;
    Result[I] := AMean + AStdDev * Sqrt(-2.0 * Ln(LU1)) * Cos(2.0 * Pi * LU2);
  end;
end;

begin
  LAnalyzer := TBenchStatsAnalyzer.Create;
  
  // Test 1: Normal data
  LData := GenerateNormalData(0.0, 1.0, 100);
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 0.0, 1.0);
  WriteLn('Normal data test:');
  WriteLn('  D = ', LResult.Statistic:0:6);
  WriteLn('  p-value = ', LResult.PValue:0:6);
  WriteLn('  IsSignificant = ', LResult.IsSignificant);
  WriteLn;
  
  // Test 2: Uniform data
  SetLength(LData, 100);
  RandSeed := 42;
  for I := 0 to 99 do
    LData[I] := Random;
  LResult := LAnalyzer.KolmogorovSmirnovNormalTest(LData, 0.5, 0.3);
  WriteLn('Uniform data test:');
  WriteLn('  D = ', LResult.Statistic:0:6);
  WriteLn('  p-value = ', LResult.PValue:0:6);
  WriteLn('  IsSignificant = ', LResult.IsSignificant);
end.
