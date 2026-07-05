{**
 * @desc Bench 模块自举性能基准测试
 *
 * 使用 bench 模块自身测试关键路径的性能：
 * - SortDoubleArray: 排序算法
 * - ComputeStats: 统计计算
 * - ToJSON: JSON 报告生成
 * - ToHTML: HTML 报告生成
 *
 * 这是 "dogfooding" 验证，确保 bench 模块自身性能可接受。
 *}
program test_bench_self_bench;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.stats,
  nextpas.core.bench.report,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.time.base;

{ 生成指定大小的随机数组 }
function GenerateRandomArray(ASize: Integer): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := Random * 10000.0;
end;

{ 生成指定大小的已排序数组 }
function GenerateSortedArray(ASize: Integer): TDoubleArray;
var
  I: Integer;
begin
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := I * 1.0;
end;

{ SortDoubleArray 基准 }
procedure BenchSortDoubleArray(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := GenerateRandomArray(1000);
  SortDoubleArray(LData);
  ACtx.SetBytes(1000 * SizeOf(Double));
end;

{ ComputeStats 基准 }
procedure BenchComputeStats(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
  LAnalyzer: TBenchStatsAnalyzer;
begin
  LData := GenerateRandomArray(1000);
  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    LAnalyzer.ComputeStats(LData);
  finally
    LAnalyzer.Free;
  end;
  ACtx.SetBytes(1000 * SizeOf(Double));
end;

{ ToJSON 基准 }
procedure BenchToJSON(const ACtx: IBenchContext);
var
  LResults: array[0..9] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  I: Integer;
begin
  for I := 0 to 9 do
  begin
    LResults[I] := Default(TBenchResult);
    LResults[I].Name := 'Benchmark' + IntToStr(I);
    LResults[I].Executed := True;
    LResults[I].NsPerOp := 100.0 + I * 10.0;
    LResults[I].OpsPerSec := 1e9 / LResults[I].NsPerOp;
    LResults[I].StdDev := 5.0;
    LResults[I].Median := LResults[I].NsPerOp;
    LResults[I].P95 := LResults[I].NsPerOp * 1.1;
    LResults[I].P99 := LResults[I].NsPerOp * 1.2;
    LResults[I].Iterations := 1000;
    LResults[I].SampleCount := 30;
  end;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LGenerator.ToJSON;
  finally
    LGenerator.Free;
  end;
end;

{ ToHTML 基准 }
procedure BenchToHTML(const ACtx: IBenchContext);
var
  LResults: array[0..9] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  I: Integer;
begin
  for I := 0 to 9 do
  begin
    LResults[I] := Default(TBenchResult);
    LResults[I].Name := 'Benchmark' + IntToStr(I);
    LResults[I].Executed := True;
    LResults[I].NsPerOp := 100.0 + I * 10.0;
    LResults[I].OpsPerSec := 1e9 / LResults[I].NsPerOp;
    LResults[I].StdDev := 5.0;
    LResults[I].Median := LResults[I].NsPerOp;
    LResults[I].P95 := LResults[I].NsPerOp * 1.1;
    LResults[I].P99 := LResults[I].NsPerOp * 1.2;
    LResults[I].Iterations := 1000;
    LResults[I].SampleCount := 30;
  end;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LGenerator.ToHTML;
  finally
    LGenerator.Free;
  end;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LData: TDoubleArray;
  LAnalyzer: TBenchStatsAnalyzer;
  LStats: TBenchStats;
  I: Integer;
begin
  RandSeed := 42;

  WriteLn('=== Bench Module Self-Benchmark ===');
  WriteLn('');

  { Quick smoke test }
  WriteLn('Quick smoke test:');
  LData := GenerateRandomArray(100);
  SortDoubleArray(LData);
  WriteLn('  SortDoubleArray(100): OK');

  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    LStats := LAnalyzer.ComputeStats(LData);
    WriteLn('  ComputeStats(100): OK');
  finally
    LAnalyzer.Free;
  end;

  WriteLn('');
  WriteLn('Running full benchmark suite...');

  LSuite := TBenchSuite.Create('bench-self-bench');
  try
    LSuite
      .Add('SortDoubleArray/1000', @BenchSortDoubleArray)
      .Add('ComputeStats/1000', @BenchComputeStats)
      .Add('ToJSON/10results', @BenchToJSON)
      .Add('ToHTML/10results', @BenchToHTML)
      .SetMinDuration(TDuration.FromMilliseconds(10))
      .SetMinSamples(3);

    LResults := LSuite.Run;
    WriteLn(LResults.PrintToConsole);
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;

  WriteLn('Done.');
end.
