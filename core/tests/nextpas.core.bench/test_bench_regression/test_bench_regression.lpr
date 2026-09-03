{*
 * nextpas.core.bench - Regression Test Suite
 *
 * 自动化回归检测：基线保存、报告格式、环境信息。
 *}

program test_bench_regression;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.bench,
  nextpas.core.time.base;

var
  GTestCount: Integer = 0;
  GUniq: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(GTestCount);
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

{*
 * 简单基准函数
 *}
procedure BenchExample(const ACtx: IBenchContext);
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
 * 带自定义指标的基准函数
 *}
procedure BenchWithMetrics(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 1 to 1000 do
    Inc(LSum, I);
  if LSum < 0 then
    WriteLn('Impossible');

  { 设置自定义指标 }
  ACtx.SetCustomMetric('cache_misses', 42.0);
  ACtx.SetCustomMetric('cache_hits', 958.0);
end;

function UniqPath(const APrefix, ASuffix: string): string;
begin
  Inc(GUniq);
  Result := APrefix + IntToStr(GetProcessID) + '-' + IntToStr(GUniq) + ASuffix;
end;

{*
 * 测试基线保存
 *}
procedure Test_Baseline_Save;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
begin
  WriteLn('  + baseline_save');

  LPath := UniqPath('test-baseline-', '.json');

  { 创建测试结果 }
  LSuite := TBenchSuite.Create('RegressionTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 保存基线 }
  LResults.SaveToJSON(LPath);

  { 验证文件存在 }
  Check(FileExists(LPath), 'Baseline file should exist');

  { 清理 }
  DeleteFile(LPath);
end;

{*
 * 测试基线加载
 *}
procedure Test_Baseline_Load;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
  LLoaded: Boolean;
begin
  WriteLn('  + baseline_load');

  LPath := UniqPath('test-baseline-', '.json');

  { 创建测试结果 }
  LSuite := TBenchSuite.Create('RegressionTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 保存基线 }
  LResults.SaveToJSON(LPath);

  { 尝试加载基线 }
  LSuite := TBenchSuite.Create('LoadTest');
  LLoaded := LSuite.TryLoadBaseline(LPath);

  if LLoaded then
  begin
    LSuite := TBenchSuite.Create('LoadTest');
    LResults := LSuite
      .Add('Benchmark', @BenchExample)
      .Run;

    LLoaded := LResults <> nil;
  end;

  Check(LLoaded, 'Should be able to load baseline');

  { 清理 }
  DeleteFile(LPath);
end;

{*
 * 测试阈值检测
 *}
procedure Test_Threshold_Detection;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('  + threshold_detection');

  LSuite := TBenchSuite.Create('ThresholdTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 无基线时应无回归 }
  Check(not LResults.HasRegression(5.0), 'No regression without baseline');
end;

{*
 * 测试环境信息收集
 *}
procedure Test_Environment_Info;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LJSON: string;
begin
  WriteLn('  + environment_info');

  LSuite := TBenchSuite.Create('EnvTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  LJSON := LResults.ToJSON;

  { 验证 JSON 包含环境信息 }
  Check(Pos('environment', LJSON) > 0, 'JSON should contain environment info');
  Check(Pos('timestamp', LJSON) > 0, 'JSON should contain timestamp');
end;

{*
 * 测试报告格式
 *}
procedure Test_Report_Formats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LConsole, LJSON, LTSV: string;
begin
  WriteLn('  + report_formats');

  LSuite := TBenchSuite.Create('ReportTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 测试各种报告格式 }
  LConsole := LResults.PrintToConsole;
  Check(Length(LConsole) > 0, 'Console report should not be empty');

  LJSON := LResults.ToJSON;
  Check(Length(LJSON) > 0, 'JSON report should not be empty');
  Check(Pos('{', LJSON) > 0, 'JSON should start with {');

  LTSV := LResults.ToTSV;
  Check(Length(LTSV) > 0, 'TSV report should not be empty');
end;

{*
 * 测试时间线追加
 *}
procedure Test_Timeline_Append;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath: string;
begin
  WriteLn('  + timeline_append');

  LPath := UniqPath('test-timeline-', '.jsonl');

  LSuite := TBenchSuite.Create('TimelineTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 追加到时间线 }
  LResults.AppendToTimeline(LPath);

  { 验证文件存在 }
  Check(FileExists(LPath), 'Timeline file should exist');

  { 清理 }
  DeleteFile(LPath);
end;

{*
 * 测试 Benchstat 格式
 *}
procedure Test_Benchstat_Format;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LBenchstat: string;
begin
  WriteLn('  + benchstat_format');

  LSuite := TBenchSuite.Create('BenchstatTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  LBenchstat := LResults.ToBenchstat;

  { 验证 Benchstat 格式 }
  Check(Length(LBenchstat) > 0, 'Benchstat should not be empty');
  Check(Pos('ns/op', LBenchstat) > 0, 'Benchstat should contain ns/op');
end;

{*
 * 测试 HTML 报告
 *}
procedure Test_HTML_Report;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
begin
  WriteLn('  + html_report');

  LSuite := TBenchSuite.Create('HTMLTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  LHTML := LResults.ToHTML;

  { 验证 HTML 格式 }
  Check(Length(LHTML) > 0, 'HTML should not be empty');
  Check(Pos('<html', LHTML) > 0, 'HTML should contain <html tag');
end;

{*
 * 测试并行执行
 *}
procedure Test_RunParallel;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin
  WriteLn('  + run_parallel');

  LSuite := TBenchSuite.Create('ParallelTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(3)
    .Add('Benchmark1', @BenchExample)
    .Add('Benchmark2', @BenchExample)
    .Add('Benchmark3', @BenchExample)
    .RunParallel(2);

  LAll := LResults.GetAll;

  { 验证所有条目都执行了 }
  Check(Length(LAll) = 3, 'Should have 3 results');
  Check(LAll[0].Executed, 'Benchmark1 should be executed');
  Check(LAll[1].Executed, 'Benchmark2 should be executed');
  Check(LAll[2].Executed, 'Benchmark3 should be executed');

  { 验证统计数据有效 }
  Check(LAll[0].NsPerOp > 0, 'Benchmark1 ns/op should be > 0');
  Check(LAll[1].NsPerOp > 0, 'Benchmark2 ns/op should be > 0');
  Check(LAll[2].NsPerOp > 0, 'Benchmark3 ns/op should be > 0');
end;

{*
 * 测试自定义指标
 *}
procedure Test_Custom_Metrics;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  LFound: Boolean;
  I: Integer;
begin
  WriteLn('  + custom_metrics');

  LSuite := TBenchSuite.Create('CustomMetricsTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(3)
    .Add('Benchmark', @BenchWithMetrics)
    .Run;

  LAll := LResults.GetAll;
  Check(Length(LAll) = 1, 'Should have 1 result');

  { 验证自定义指标已复制到结果 }
  LFound := False;
  for I := 0 to High(LAll[0].CustomMetrics) do
  begin
    if LAll[0].CustomMetrics[I].Name = 'cache_misses' then
    begin
      LFound := True;
      Check(LAll[0].CustomMetrics[I].Value > 0, 'Cache misses should be > 0');
    end;
  end;
  Check(LFound, 'Should have cache_misses metric');
end;

{*
 * 测试 ToSummary 报告
 *}
procedure Test_ToSummary;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSummary: string;
begin
  WriteLn('  + to_summary');

  LSuite := TBenchSuite.Create('SummaryTest');
  LResults := LSuite
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(3)
    .Add('Benchmark', @BenchExample)
    .Run;

  LSummary := LResults.ToSummary;

  { 验证摘要格式 }
  Check(Length(LSummary) > 0, 'Summary should not be empty');
  Check(Pos('Benchmarks: 1 results', LSummary) > 0, 'Should contain result count');
  Check(Pos('Benchmark:', LSummary) > 0, 'Should contain benchmark name');
  Check(Pos('ns/op', LSummary) > 0, 'Should contain ns/op');
  Check(Pos('ops/s', LSummary) > 0, 'Should contain ops/s');
end;

{*
 * 主测试套件
 *}
begin
  WriteLn('=== nextpas.core.bench Regression Tests ===');
  WriteLn;

  Test_Baseline_Save;
  Test_Baseline_Load;
  Test_Threshold_Detection;
  Test_Environment_Info;
  Test_Report_Formats;
  Test_Timeline_Append;
  Test_Benchstat_Format;
  Test_HTML_Report;
  Test_RunParallel;
  Test_Custom_Metrics;
  Test_ToSummary;

  WriteLn;
  WriteLn(Format('  %d passed, %d failed, 0 skipped', [GPassCount, GFailCount]));
  WriteLn('--- bench-regression ---');
  WriteLn(Format('  Total tests: %d', [GTestCount]));
  WriteLn(Format('  Passed: %d, Failed: %d, Skipped: 0', [GPassCount, GFailCount]));
  WriteLn;

  if GFailCount > 0 then
  begin
    WriteLn('=== REGRESSION TESTS FAILED ===');
    ExitCode := 1;
  end
  else
    WriteLn('=== All Regression Tests Passed ===');
end.
