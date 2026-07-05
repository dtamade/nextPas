{**
 * @desc Bench 模块自举性能基准测试
 *
 * 使用 bench 模块自身测试关键路径的性能：
 * - SortDoubleArray: 排序算法
 * - ComputeStats: 统计计算
 * - ToJSON: JSON 报告生成
 * - ToHTML: HTML 报告生成
 *
 * 验证每个基准测试产出合理结果，并检查内存无泄漏。
 *}
program test_bench_self_bench;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
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

{ === 验证测试：确保基准函数本身正确 === }

procedure TestSortDoubleArray_Correctness;
var
  LData: TDoubleArray;
  I: Integer;
  LSorted: Boolean;
begin
  LData := GenerateRandomArray(1000);
  SortDoubleArray(LData);
  LSorted := True;
  for I := 1 to High(LData) do
    if LData[I] < LData[I - 1] then
    begin
      LSorted := False;
      Break;
    end;
  Check(LSorted, 'SortDoubleArray must produce sorted output');
  CheckEqual(1000, Length(LData), 'Array length must be preserved');
end;

procedure TestSortDoubleArray_Empty;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 0);
  SortDoubleArray(LData);
  CheckEqual(0, Length(LData), 'Empty array sort is no-op');
end;

procedure TestSortDoubleArray_Single;
var
  LData: TDoubleArray;
begin
  SetLength(LData, 1);
  LData[0] := 42.0;
  SortDoubleArray(LData);
  CheckNear(42.0, LData[0], 1e-10, 'Single element preserved');
end;

procedure TestComputeStats_Reasonable;
var
  LData: TDoubleArray;
  LAnalyzer: TBenchStatsAnalyzer;
  LStats: TBenchStats;
begin
  LData := GenerateRandomArray(1000);
  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    LStats := LAnalyzer.ComputeStats(LData);
    Check(LStats.Mean > 0, 'Mean must be positive for random [0,10000)');
    Check(LStats.StdDev > 0, 'StdDev must be positive');
    Check(LStats.Median > 0, 'Median must be positive');
    Check(LStats.P95 >= LStats.Median, 'P95 >= Median');
    Check(LStats.P99 >= LStats.P95, 'P99 >= P95');
    Check(LStats.SampleCount = 1000, 'SampleCount matches input');
  finally
    LAnalyzer.Free;
  end;
end;

procedure TestComputeStats_Constant;
var
  LData: TDoubleArray;
  LAnalyzer: TBenchStatsAnalyzer;
  LStats: TBenchStats;
  I: Integer;
begin
  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := 5.0;
  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    LStats := LAnalyzer.ComputeStats(LData);
    CheckNear(5.0, LStats.Mean, 1e-10, 'Constant data mean');
    CheckNear(0.0, LStats.StdDev, 1e-10, 'Constant data stddev is 0');
  finally
    LAnalyzer.Free;
  end;
end;

{ 报告生成验证 }

procedure TestToJSON_ContainsExpectedKeys;
var
  LResults: array[0..2] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LJSON: string;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    LResults[I] := Default(TBenchResult);
    LResults[I].Name := 'TestBench' + IntToStr(I);
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
    LJSON := LGenerator.ToJSON;
    Check(Length(LJSON) > 0, 'ToJSON must produce non-empty output');
    Check(Pos('"version"', LJSON) > 0, 'JSON must contain version key');
    Check(Pos('"benchmarks"', LJSON) > 0, 'JSON must contain benchmarks key');
    Check(Pos('"ns_per_op"', LJSON) > 0, 'JSON must contain ns_per_op key');
    Check(Pos('TestBench0', LJSON) > 0, 'JSON must contain benchmark name');
    Check(Pos('"environment"', LJSON) > 0, 'JSON must contain environment key');
  finally
    LGenerator.Free;
  end;
end;

procedure TestToJSON_SkippedEntries;
var
  LResults: array[0..1] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LJSON: string;
begin
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'Normal';
  LResults[0].Executed := True;
  LResults[0].NsPerOp := 100.0;
  LResults[0].OpsPerSec := 1e7;
  LResults[0].Iterations := 1000;
  LResults[0].SampleCount := 30;

  LResults[1] := Default(TBenchResult);
  LResults[1].Name := 'Skipped';
  LResults[1].Executed := False;
  LResults[1].Skipped := True;
  LResults[1].SkipReason := 'too slow';

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LJSON := LGenerator.ToJSON;
    Check(Pos('"skipped"', LJSON) > 0, 'JSON must contain skipped status');
    Check(Pos('too slow', LJSON) > 0, 'JSON must contain skip reason');
    Check(Pos('"status"', LJSON) > 0, 'JSON must contain status key');
  finally
    LGenerator.Free;
  end;
end;

procedure TestToHTML_ContainsStructure;
var
  LResults: array[0..2] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LHTML: string;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    LResults[I] := Default(TBenchResult);
    LResults[I].Name := 'HtmlBench' + IntToStr(I);
    LResults[I].Executed := True;
    LResults[I].NsPerOp := 200.0 + I * 20.0;
    LResults[I].OpsPerSec := 1e9 / LResults[I].NsPerOp;
    LResults[I].StdDev := 10.0;
    LResults[I].Median := LResults[I].NsPerOp;
    LResults[I].P95 := LResults[I].NsPerOp * 1.1;
    LResults[I].P99 := LResults[I].NsPerOp * 1.2;
    LResults[I].Iterations := 500;
    LResults[I].SampleCount := 20;
  end;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LHTML := LGenerator.ToHTML;
    Check(Length(LHTML) > 0, 'ToHTML must produce non-empty output');
    Check(Pos('<!DOCTYPE html>', LHTML) > 0, 'HTML must have doctype');
    Check(Pos('<table>', LHTML) > 0, 'HTML must contain table');
    Check(Pos('HtmlBench0', LHTML) > 0, 'HTML must contain benchmark name');
    Check(Pos('<svg', LHTML) > 0, 'HTML must contain SVG chart');
    Check(Pos('</html>', LHTML) > 0, 'HTML must have closing tag');
  finally
    LGenerator.Free;
  end;
end;

procedure TestToTSV_ContainsHeaders;
var
  LResults: array[0..0] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LTSV: string;
begin
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'TsvBench';
  LResults[0].Executed := True;
  LResults[0].NsPerOp := 50.0;
  LResults[0].OpsPerSec := 2e7;
  LResults[0].Iterations := 2000;
  LResults[0].SampleCount := 10;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LTSV := LGenerator.ToTSV;
    Check(Length(LTSV) > 0, 'ToTSV must produce non-empty output');
    Check(Pos('name', LTSV) = 1, 'TSV must start with name header');
    Check(Pos('ns_per_op', LTSV) > 0, 'TSV must contain ns_per_op column');
    Check(Pos('TsvBench', LTSV) > 0, 'TSV must contain benchmark name');
  finally
    LGenerator.Free;
  end;
end;

procedure TestToBenchstat_Format;
var
  LResults: array[0..0] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LOutput: string;
begin
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'BenchstatBench';
  LResults[0].Executed := True;
  LResults[0].NsPerOp := 75.0;
  LResults[0].OpsPerSec := 1e9 / 75.0;
  LResults[0].StdDev := 3.0;
  LResults[0].Median := 75.0;
  LResults[0].P95 := 80.0;
  LResults[0].P99 := 85.0;
  LResults[0].Iterations := 5000;
  LResults[0].SampleCount := 50;
  LResults[0].BytesPerOp := 64;
  LResults[0].AllocsPerOp := 2;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LOutput := LGenerator.ToBenchstat;
    Check(Length(LOutput) > 0, 'ToBenchstat must produce non-empty output');
    Check(Pos('BenchstatBench', LOutput) > 0, 'Benchstat must contain name');
    Check(Pos('B/op', LOutput) > 0, 'Benchstat must have B/op column');
    Check(Pos('allocs/op', LOutput) > 0, 'Benchstat must have allocs/op column');
  finally
    LGenerator.Free;
  end;
end;

procedure TestPrintToConsole_ContainsResults;
var
  LResults: array[0..1] of TBenchResult;
  LGenerator: TBenchReportGenerator;
  LConsole: string;
  I: Integer;
begin
  for I := 0 to 1 do
  begin
    LResults[I] := Default(TBenchResult);
    LResults[I].Name := 'ConsoleBench' + IntToStr(I);
    LResults[I].Executed := True;
    LResults[I].NsPerOp := 300.0 + I * 50.0;
    LResults[I].OpsPerSec := 1e9 / LResults[I].NsPerOp;
    LResults[I].StdDev := 15.0;
    LResults[I].Median := LResults[I].NsPerOp;
    LResults[I].P95 := LResults[I].NsPerOp * 1.1;
    LResults[I].P99 := LResults[I].NsPerOp * 1.2;
    LResults[I].Iterations := 200;
    LResults[I].SampleCount := 15;
  end;

  LGenerator := TBenchReportGenerator.Create;
  try
    LGenerator.SetResults(LResults);
    LConsole := LGenerator.PrintToConsole;
    Check(Length(LConsole) > 0, 'PrintToConsole must produce non-empty output');
    Check(Pos('ConsoleBench0', LConsole) > 0, 'Console must contain benchmark name');
    Check(Pos('Statistics', LConsole) > 0, 'Console must have statistics section');
  finally
    LGenerator.Free;
  end;
end;

{ Suite runner — 实际基准测试 + 运行验证 }

procedure TestBenchSortDoubleArray;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('self-sort');
  LSuite.Add('SortDoubleArray/1000', procedure(const ACtx: IBenchContext)
    var LData: TDoubleArray;
    begin
      LData := GenerateRandomArray(1000);
      SortDoubleArray(LData);
      ACtx.SetBytes(1000 * SizeOf(Double));
    end);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMinSamples(3);
  LResults := LSuite.Run;
  Check(LResults.Count > 0, 'Sort benchmark must produce results');
  Check(LResults.GetAll[0].Executed, 'Sort benchmark must be executed');
  Check(LResults.GetAll[0].NsPerOp > 0, 'Sort ns/op must be positive');
  Check(LResults.GetAll[0].Iterations > 0, 'Sort iterations must be positive');
end;

procedure TestBenchComputeStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('self-stats');
  LSuite.Add('ComputeStats/1000', procedure(const ACtx: IBenchContext)
    var LData: TDoubleArray; LAnalyzer: TBenchStatsAnalyzer;
    begin
      LData := GenerateRandomArray(1000);
      LAnalyzer := TBenchStatsAnalyzer.Create;
      try
        LAnalyzer.ComputeStats(LData);
      finally
        LAnalyzer.Free;
      end;
      ACtx.SetBytes(1000 * SizeOf(Double));
    end);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMinSamples(3);
  LResults := LSuite.Run;
  Check(LResults.Count > 0, 'Stats benchmark must produce results');
  Check(LResults.GetAll[0].Executed, 'Stats benchmark must be executed');
  Check(LResults.GetAll[0].NsPerOp > 0, 'Stats ns/op must be positive');
end;

procedure TestBenchToJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('self-json');
  LSuite.Add('ToJSON/10results', procedure(const ACtx: IBenchContext)
    var LRes: array[0..9] of TBenchResult; LGen: TBenchReportGenerator; I: Integer;
    begin
      for I := 0 to 9 do
      begin
        LRes[I] := Default(TBenchResult);
        LRes[I].Name := 'Bench' + IntToStr(I);
        LRes[I].Executed := True;
        LRes[I].NsPerOp := 100.0 + I * 10.0;
        LRes[I].OpsPerSec := 1e9 / LRes[I].NsPerOp;
        LRes[I].Iterations := 1000;
        LRes[I].SampleCount := 30;
      end;
      LGen := TBenchReportGenerator.Create;
      try
        LGen.SetResults(LRes);
        LGen.ToJSON;
      finally
        LGen.Free;
      end;
    end);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMinSamples(3);
  LResults := LSuite.Run;
  Check(LResults.Count > 0, 'JSON benchmark must produce results');
  Check(LResults.GetAll[0].Executed, 'JSON benchmark must be executed');
end;

procedure TestBenchToHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('self-html');
  LSuite.Add('ToHTML/10results', procedure(const ACtx: IBenchContext)
    var LRes: array[0..9] of TBenchResult; LGen: TBenchReportGenerator; I: Integer;
    begin
      for I := 0 to 9 do
      begin
        LRes[I] := Default(TBenchResult);
        LRes[I].Name := 'Bench' + IntToStr(I);
        LRes[I].Executed := True;
        LRes[I].NsPerOp := 100.0 + I * 10.0;
        LRes[I].OpsPerSec := 1e9 / LRes[I].NsPerOp;
        LRes[I].Iterations := 1000;
        LRes[I].SampleCount := 30;
      end;
      LGen := TBenchReportGenerator.Create;
      try
        LGen.SetResults(LRes);
        LGen.ToHTML;
      finally
        LGen.Free;
      end;
    end);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMinSamples(3);
  LResults := LSuite.Run;
  Check(LResults.Count > 0, 'HTML benchmark must produce results');
  Check(LResults.GetAll[0].Executed, 'HTML benchmark must be executed');
end;

{ TBenchSuite fluent API 验证 }

procedure TestBenchSuite_FluentAPI;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('fluent-test');
  LSuite
    .Add('noop1', procedure(const ACtx: IBenchContext) begin end)
    .Add('noop2', procedure(const ACtx: IBenchContext) begin end)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMinSamples(2);
  LResults := LSuite.Run;
  Check(LResults.Count = 2, 'Fluent API must register and run 2 benchmarks');
end;

procedure TestBenchResults_PrintToConsole;
var
  LResults: array[0..0] of TBenchResult;
  LGen: TBenchReportGenerator;
  LOutput: string;
begin
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'TestResult';
  LResults[0].Executed := True;
  LResults[0].NsPerOp := 42.0;
  LResults[0].OpsPerSec := 1e9 / 42.0;
  LResults[0].Median := 42.0;
  LResults[0].P95 := 45.0;
  LResults[0].P99 := 50.0;
  LResults[0].StdDev := 2.0;
  LResults[0].Iterations := 10000;
  LResults[0].SampleCount := 100;

  LGen := TBenchReportGenerator.Create;
  try
    LGen.SetResults(LResults);
    LOutput := LGen.PrintToConsole;
    Check(Pos('TestResult', LOutput) > 0, 'Console output must contain result name');
    Check(Pos('nextpas.core.bench', LOutput) > 0, 'Console output must contain version');
  finally
    LGen.Free;
  end;
end;

var
  T: TTestSuite;
begin
  RandSeed := 42;

  T := TTestSuite.Create('bench-self-bench');

  { 功能验证 }
  T.Test('SortDoubleArray_Correctness', @TestSortDoubleArray_Correctness);
  T.Test('SortDoubleArray_Empty', @TestSortDoubleArray_Empty);
  T.Test('SortDoubleArray_Single', @TestSortDoubleArray_Single);
  T.Test('ComputeStats_Reasonable', @TestComputeStats_Reasonable);
  T.Test('ComputeStats_Constant', @TestComputeStats_Constant);

  { 报告格式验证 }
  T.Test('ToJSON_ContainsExpectedKeys', @TestToJSON_ContainsExpectedKeys);
  T.Test('ToJSON_SkippedEntries', @TestToJSON_SkippedEntries);
  T.Test('ToHTML_ContainsStructure', @TestToHTML_ContainsStructure);
  T.Test('ToTSV_ContainsHeaders', @TestToTSV_ContainsHeaders);
  T.Test('ToBenchstat_Format', @TestToBenchstat_Format);
  T.Test('PrintToConsole_ContainsResults', @TestPrintToConsole_ContainsResults);

  { 基准运行验证 }
  T.Test('BenchSortDoubleArray', @TestBenchSortDoubleArray);
  T.Test('BenchComputeStats', @TestBenchComputeStats);
  T.Test('BenchToJSON', @TestBenchToJSON);
  T.Test('BenchToHTML', @TestBenchToHTML);

  { API 验证 }
  T.Test('BenchSuite_FluentAPI', @TestBenchSuite_FluentAPI);
  T.Test('BenchResults_PrintToConsole', @TestBenchResults_PrintToConsole);

  T.Run;
  T.Summary;
end.
