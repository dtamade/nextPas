{*
 * nextpas.core.bench - Advanced Statistics Example
 *
 * 展示基准测试统计：均值、标准差、中位数、百分位数等。
 *}

program bench_advanced_stats;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

{*
 * 简单基准函数
 *}
procedure BenchIntegerSum(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 1 to 1000 do
    Inc(LSum, I);
  if LSum < 0 then
    WriteLn('Impossible');
end;

{*
 * 演示基准测试统计
 *}
procedure DemoBenchmarkStats;
var
  LResults: IBenchResults;
  LResult: TBenchResult;
begin
  WriteLn('=== Benchmark Statistics ===');

  LResults := TBenchSuite.Create('StatsDemo')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetMinSamples(30)
    .Add('IntegerSum/1000', @BenchIntegerSum)
    .Run;

  LResult := LResults.GetByName('IntegerSum/1000');

  WriteLn(Format('  Name: %s', [LResult.Name]));
  WriteLn(Format('  Iterations: %d', [LResult.Iterations]));
  WriteLn(Format('  NsPerOp: %.2f', [LResult.NsPerOp]));
  WriteLn(Format('  OpsPerSec: %.2f', [LResult.OpsPerSec]));
  WriteLn(Format('  StdDev: %.2f', [LResult.StdDev]));
  WriteLn(Format('  Median: %.2f', [LResult.Median]));
  WriteLn(Format('  P95: %.2f', [LResult.P95]));
  WriteLn(Format('  P99: %.2f', [LResult.P99]));
  WriteLn(Format('  SampleCount: %d', [LResult.SampleCount]));
  WriteLn(Format('  Outliers: %d', [LResult.Outliers]));
  WriteLn;
end;

{*
 * 演示多基准对比
 *}
procedure DemoBenchmarkComparison;
var
  LResults: IBenchResults;
begin
  WriteLn('=== Benchmark Comparison ===');

  LResults := TBenchSuite.Create('Comparison')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetMinSamples(30)
    .Add('Fast', @BenchIntegerSum)
    .Add('Slow', @BenchIntegerSum)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;
end;

{*
 * 主程序
 *}
begin
  WriteLn('=== nextpas.core.bench Advanced Statistics ===');
  WriteLn;

  DemoBenchmarkStats;
  DemoBenchmarkComparison;

  WriteLn('=== Advanced Statistics Complete ===');
end.
