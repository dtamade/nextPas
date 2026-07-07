{*
 * nextpas.core.bench - Regression Test Suite
 *
 * 自动化回归检测：基线保存、报告格式、环境信息。
 *}

program test_bench_regression;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

var
  GTestCount: Integer = 0;
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
 * 测试基线保存
 *}
procedure Test_Baseline_Save;
var
  LResults: IBenchResults;
  LPath: string;
begin
  WriteLn('  + baseline_save');

  LPath := 'test-baseline-' + IntToStr(Random(10000)) + '.json';

  { 创建测试结果 }
  LResults := TBenchSuite.Create('RegressionTest')
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
  LResults: IBenchResults;
  LPath: string;
  LLoaded: Boolean;
begin
  WriteLn('  + baseline_load');

  LPath := 'test-baseline-' + IntToStr(Random(10000)) + '.json';

  { 创建测试结果 }
  LResults := TBenchSuite.Create('RegressionTest')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Benchmark', @BenchExample)
    .Run;

  { 保存基线 }
  LResults.SaveToJSON(LPath);

  { 尝试加载基线 }
  LLoaded := TBenchSuite.Create('LoadTest')
    .TryLoadBaseline(LPath);

  if LLoaded then
  begin
    LResults := TBenchSuite.Create('LoadTest')
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
  LResults: IBenchResults;
begin
  WriteLn('  + threshold_detection');

  LResults := TBenchSuite.Create('ThresholdTest')
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
  LResults: IBenchResults;
  LJSON: string;
begin
  WriteLn('  + environment_info');

  LResults := TBenchSuite.Create('EnvTest')
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
  LResults: IBenchResults;
  LConsole, LJSON, LTSV: string;
begin
  WriteLn('  + report_formats');

  LResults := TBenchSuite.Create('ReportTest')
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
  LResults: IBenchResults;
  LPath: string;
begin
  WriteLn('  + timeline_append');

  LPath := 'test-timeline-' + IntToStr(Random(10000)) + '.jsonl';

  LResults := TBenchSuite.Create('TimelineTest')
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
  LResults: IBenchResults;
  LBenchstat: string;
begin
  WriteLn('  + benchstat_format');

  LResults := TBenchSuite.Create('BenchstatTest')
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
  LResults: IBenchResults;
  LHTML: string;
begin
  WriteLn('  + html_report');

  LResults := TBenchSuite.Create('HTMLTest')
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
