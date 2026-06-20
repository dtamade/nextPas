program test_bench_integration;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

var
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

{ 基准函数：快速操作 }
procedure BenchFast(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for i := 1 to 1000 do
    LSum := LSum + i;
end;

{ 基准函数：中等速度操作 }
procedure BenchMedium(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Double;
begin
  LSum := 0.0;
  for i := 1 to 10000 do
    LSum := LSum + Sin(i * 0.001);
end;

{ 基准函数：使用上下文 }
procedure BenchWithContext(const ACtx: IBenchContext);
var
  i: Integer;
begin
  if ACtx <> nil then
  begin
    ACtx.SetBytes(1024);
    ACtx.SetAllocs(2);
  end;
  for i := 1 to 100 do
    ;
end;

procedure TestTBenchSuite_Basic;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_Basic:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 2, 'Result count = 2');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'First result name correct');
  Check(LResults.GetByName('Medium').Name = 'Medium', 'Second result name correct');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'First NsPerOp > 0');
  Check(LResults.GetByName('Medium').NsPerOp > 0, 'Second NsPerOp > 0');
end;

procedure TestTBenchSuite_WithConfig;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_WithConfig:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 配置
  LSuite.SetMinDuration(TDuration.FromMilliseconds(500));
  LSuite.SetMaxIterations(100000);
  LSuite.SetMinSamples(10);
  LSuite.SetWarmupIters(3);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Result name correct');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'NsPerOp > 0');
end;

procedure TestTBenchSuite_WithBaseline;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: array of TBenchComparison;
begin
  WriteLn('TestTBenchSuite_WithBaseline:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基线
  LSuite.AddBaseline('Fast', 100.0);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');

  // 对比基线
  LComparisons := LResults.CompareWithBaseline;
  Check(Length(LComparisons) = 1, 'Comparison count = 1');
  Check(LComparisons[0].BaselineName = 'Fast', 'Baseline name correct');
  Check(LComparisons[0].BaselineNsPerOp = 100.0, 'Baseline NsPerOp correct');
  Check(LComparisons[0].CurrentNsPerOp > 0, 'Current NsPerOp > 0');
  Check(LComparisons[0].Ratio > 0, 'Ratio > 0');
end;

procedure TestTBenchSuite_WithFilter;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_WithFilter:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 设置过滤器
  LSuite.SetFilter('Fast');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  // 注意：过滤器会让不匹配的基准返回空结果（Iterations=0）
  Check(LResults.Count = 2, 'Result count = 2');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Filtered result exists');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'Filtered NsPerOp > 0');
  Check(LResults.GetByName('Medium').Name = 'Medium', 'Non-filtered result exists');
  Check(LResults.GetByName('Medium').Iterations = 0, 'Non-filtered result has 0 iterations');
end;

procedure TestTBenchSuite_Conditional;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_Conditional:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 条件添加
  LSuite.AddWhen('Fast', @BenchFast, True);
  LSuite.AddWhen('Medium', @BenchMedium, False);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'Conditional result exists');
  Check(LResults.GetByName('Fast').NsPerOp > 0, 'Conditional NsPerOp > 0');
end;

procedure TestTBenchSuite_WithContext;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_WithContext:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加带上下文的基准
  LSuite.Add('WithContext', @BenchWithContext);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 1, 'Result count = 1');
  Check(LResults.GetByName('WithContext').Name = 'WithContext', 'Result name correct');
  Check(LResults.GetByName('WithContext').NsPerOp > 0, 'NsPerOp > 0');
end;

procedure TestTBenchResults_ToConsole;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LConsole: string;
begin
  WriteLn('TestTBenchResults_ToConsole:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成控制台报告
  LConsole := LResults.ToConsole;

  Check(Length(LConsole) > 0, 'Console output not empty');
  Check(Pos('nextpas.core.bench v1.0', LConsole) > 0, 'Contains version');
  Check(Pos('Fast', LConsole) > 0, 'Contains benchmark name');
end;

procedure TestTBenchResults_ToJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LJSON: string;
begin
  WriteLn('TestTBenchResults_ToJSON:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 JSON 报告
  LJSON := LResults.ToJSON;

  Check(Length(LJSON) > 0, 'JSON output not empty');
  Check(Pos('"version": "1.0"', LJSON) > 0, 'Contains version');
  Check(Pos('"name": "Fast"', LJSON) > 0, 'Contains benchmark name');
  Check(Pos('"ns_per_op"', LJSON) > 0, 'Contains NsPerOp');
end;

procedure TestTBenchResults_ToTSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTSV: string;
begin
  WriteLn('TestTBenchResults_ToTSV:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 TSV 报告
  LTSV := LResults.ToTSV;

  Check(Length(LTSV) > 0, 'TSV output not empty');
  Check(Pos('name' + #9 + 'iterations', LTSV) > 0, 'Contains header');
  Check(Pos('Fast', LTSV) > 0, 'Contains benchmark name');
end;

procedure TestTBenchResults_ToHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
begin
  WriteLn('TestTBenchResults_ToHTML:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 生成 HTML 报告
  LHTML := LResults.ToHTML;

  Check(Length(LHTML) > 0, 'HTML output not empty');
  Check(Pos('<!DOCTYPE html>', LHTML) > 0, 'Contains DOCTYPE');
  Check(Pos('Fast', LHTML) > 0, 'Contains benchmark name');
  Check(Pos('<canvas id="benchmarkChart"', LHTML) > 0, 'Contains chart');
end;

procedure TestTBenchResults_HasRegression;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchResults_HasRegression:');

  // 创建套件
  LSuite := TBenchSuite.Create('TestSuite');

  // 添加基线（比当前慢）
  LSuite.AddBaseline('Fast', 1000.0);

  // 添加基准
  LSuite.Add('Fast', @BenchFast);

  // 运行
  LResults := LSuite.Run;

  // 检查回归（阈值 0.8 表示比基线慢 20%）
  Check(not LResults.HasRegression(0.8), 'No regression detected');
end;

procedure TestTBenchSuite_FluentAPI;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('TestTBenchSuite_FluentAPI:');

  // 测试 Fluent API
  LSuite := TBenchSuite.Create('TestSuite')
    .Add('Fast', @BenchFast)
    .Add('Medium', @BenchMedium)
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMaxIterations(100000)
    .SetMinSamples(10)
    .SetWarmupIters(3)
    .AddBaseline('Fast', 100.0)
    .AddBaseline('Medium', 200.0);

  // 运行
  LResults := LSuite.Run;

  // 检查结果
  Check(LResults.Count = 2, 'Result count = 2');
  Check(LResults.GetByName('Fast').Name = 'Fast', 'First result name correct');
  Check(LResults.GetByName('Medium').Name = 'Medium', 'Second result name correct');
end;

begin
  WriteLn('=== nextpas.core.bench Integration Tests ===');
  WriteLn;

  GTestCount := 0;
  GPassCount := 0;
  GFailCount := 0;

  TestTBenchSuite_Basic;
  WriteLn;
  TestTBenchSuite_WithConfig;
  WriteLn;
  TestTBenchSuite_WithBaseline;
  WriteLn;
  TestTBenchSuite_WithFilter;
  WriteLn;
  TestTBenchSuite_Conditional;
  WriteLn;
  TestTBenchSuite_WithContext;
  WriteLn;
  TestTBenchResults_ToConsole;
  WriteLn;
  TestTBenchResults_ToJSON;
  WriteLn;
  TestTBenchResults_ToTSV;
  WriteLn;
  TestTBenchResults_ToHTML;
  WriteLn;
  TestTBenchResults_HasRegression;
  WriteLn;
  TestTBenchSuite_FluentAPI;

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
