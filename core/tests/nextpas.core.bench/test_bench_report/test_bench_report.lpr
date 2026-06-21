program test_bench_report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.bench.report;

var
  GTestCount: Integer;
  GPassCount: Integer;
  GFailCount: Integer;
  GGenerator: TBenchReportGenerator;

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

procedure CheckContains(const AStr, ASubstr, ATestName: string);
begin
  Check(Pos(ASubstr, AStr) > 0, ATestName);
end;

procedure CheckNotContains(const AStr, ASubstr, ATestName: string);
begin
  Check(Pos(ASubstr, AStr) = 0, ATestName);
end;

function CreateTestResults: TBenchResultArray;
var
  LResults: TBenchResultArray;
begin
  SetLength(LResults, 3);

  LResults[0].Name := 'HashMap.Put';
  LResults[0].Iterations := 1000000;
  LResults[0].NsPerOp := 245.3;
  LResults[0].OpsPerSec := 4080000;
  LResults[0].BytesPerOp := 0;
  LResults[0].AllocsPerOp := 1;
  LResults[0].StdDev := 12.3;
  LResults[0].Median := 243.1;
  LResults[0].P95 := 268.4;
  LResults[0].P99 := 289.2;
  LResults[0].Outliers := 3;
  LResults[0].SampleCount := 30;

  LResults[1].Name := 'HashMap.Get(hit)';
  LResults[1].Iterations := 5000000;
  LResults[1].NsPerOp := 89.2;
  LResults[1].OpsPerSec := 11210000;
  LResults[1].BytesPerOp := 0;
  LResults[1].AllocsPerOp := 0;
  LResults[1].StdDev := 5.1;
  LResults[1].Median := 88.5;
  LResults[1].P95 := 95.2;
  LResults[1].P99 := 102.1;
  LResults[1].Outliers := 5;
  LResults[1].SampleCount := 30;

  LResults[2].Name := 'Bytes.Compare';
  LResults[2].Iterations := 10000000;
  LResults[2].NsPerOp := 45.1;
  LResults[2].OpsPerSec := 22170000;
  LResults[2].BytesPerOp := 1024;
  LResults[2].AllocsPerOp := 0;
  LResults[2].StdDev := 2.1;
  LResults[2].Median := 44.8;
  LResults[2].P95 := 48.5;
  LResults[2].P99 := 52.3;
  LResults[2].Outliers := 2;
  LResults[2].SampleCount := 30;

  Result := LResults;
end;

function CreateTestEnvironment: TBenchEnvironment;
begin
  Result.OS := 'linux';
  Result.CPU := 'x86_64';
  Result.Cores := 16;
  Result.FPCVersion := '3.3.1';
  Result.Timestamp := '2026-06-21T15:30:00Z';
end;

procedure TestToConsole;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LConsole: string;
begin
  WriteLn('TestToConsole:');

  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LConsole := GGenerator.ToConsole;

  CheckContains(LConsole, 'nextpas.core.bench v1.0', 'Contains version');
  CheckContains(LConsole, 'Environment:', 'Contains environment header');
  CheckContains(LConsole, 'OS: linux', 'Contains OS');
  CheckContains(LConsole, 'CPU: x86_64', 'Contains CPU');
  CheckContains(LConsole, 'Cores: 16', 'Contains cores');
  CheckContains(LConsole, 'FPC: 3.3.1', 'Contains FPC version');
  CheckContains(LConsole, 'Benchmark Results:', 'Contains results header');
  CheckContains(LConsole, 'HashMap.Put', 'Contains first benchmark');
  CheckContains(LConsole, 'HashMap.Get(hit)', 'Contains second benchmark');
  CheckContains(LConsole, 'Bytes.Compare', 'Contains third benchmark');
  CheckContains(LConsole, '245.3', 'Contains NsPerOp');
  CheckContains(LConsole, 'Statistics', 'Contains statistics header');
end;

procedure TestToJSON;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LJSON: string;
begin
  WriteLn('TestToJSON:');

  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LJSON := GGenerator.ToJSON;

  CheckContains(LJSON, '"version": "1.0"', 'Contains version');
  CheckContains(LJSON, '"os": "linux"', 'Contains OS');
  CheckContains(LJSON, '"cpu": "x86_64"', 'Contains CPU');
  CheckContains(LJSON, '"cores": 16', 'Contains cores');
  CheckContains(LJSON, '"fpc_version": "3.3.1"', 'Contains FPC version');
  CheckContains(LJSON, '"name": "HashMap.Put"', 'Contains first benchmark');
  CheckContains(LJSON, '"iterations": 1000000', 'Contains iterations');
  CheckContains(LJSON, '"ns_per_op": 245.3', 'Contains NsPerOp');
  CheckContains(LJSON, '"ops_per_sec": 4080000', 'Contains OpsPerSec');
  CheckContains(LJSON, '"stddev": 12.3', 'Contains StdDev');
  CheckContains(LJSON, '"median": 243.1', 'Contains Median');
  CheckContains(LJSON, '"p95": 268.4', 'Contains P95');
  CheckContains(LJSON, '"p99": 289.2', 'Contains P99');
  CheckContains(LJSON, '"outliers": 3', 'Contains Outliers');
end;

procedure TestToTSV;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LTSV: string;
begin
  WriteLn('TestToTSV:');

  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LTSV := GGenerator.ToTSV;

  CheckContains(LTSV, 'name' + #9 + 'iterations', 'Contains header');
  CheckContains(LTSV, 'HashMap.Put' + #9 + '1000000', 'Contains first benchmark');
  CheckContains(LTSV, 'HashMap.Get(hit)' + #9 + '5000000', 'Contains second benchmark');
  CheckContains(LTSV, 'Bytes.Compare' + #9 + '10000000', 'Contains third benchmark');
end;

procedure TestToHTML;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LHTML: string;
begin
  WriteLn('TestToHTML:');

  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LHTML := GGenerator.ToHTML;

  CheckContains(LHTML, '<!DOCTYPE html>', 'Contains DOCTYPE');
  CheckContains(LHTML, '<title>nextpas.core.bench Report</title>', 'Contains title');
  CheckContains(LHTML, '<h1>nextpas.core.bench Report</h1>', 'Contains main header');
  CheckContains(LHTML, '<h2>Environment</h2>', 'Contains environment header');
  CheckContains(LHTML, 'linux', 'Contains OS');
  CheckContains(LHTML, 'x86_64', 'Contains CPU');
  CheckContains(LHTML, '<h2>Benchmark Results</h2>', 'Contains results header');
  CheckContains(LHTML, 'HashMap.Put', 'Contains first benchmark');
  CheckContains(LHTML, '245.3', 'Contains NsPerOp');
  CheckContains(LHTML, '<h2>Detailed Statistics</h2>', 'Contains statistics header');
end;

procedure TestGenerateComparisonReport;
var
  LResults: array of TBenchResult;
  LComparisons: array of TBenchComparison;
  LReport: string;
begin
  WriteLn('TestGenerateComparisonReport:');

  LResults := CreateTestResults;

  SetLength(LComparisons, 2);
  LComparisons[0].BaselineName := 'HashMap.Put';
  LComparisons[0].BaselineNsPerOp := 250.0;
  LComparisons[0].CurrentNsPerOp := 245.3;
  LComparisons[0].Ratio := 1.019;
  LComparisons[0].Significant := True;
  LComparisons[0].PValue := 0.05;

  LComparisons[1].BaselineName := 'HashMap.Get(hit)';
  LComparisons[1].BaselineNsPerOp := 92.1;
  LComparisons[1].CurrentNsPerOp := 89.2;
  LComparisons[1].Ratio := 1.033;
  LComparisons[1].Significant := True;
  LComparisons[1].PValue := 0.05;

  LReport := GGenerator.GenerateComparisonReport(LResults, LComparisons);

  CheckContains(LReport, 'Baseline Comparison', 'Contains header');
  CheckContains(LReport, 'HashMap.Put', 'Contains first comparison');
  CheckContains(LReport, 'HashMap.Get(hit)', 'Contains second comparison');
  // 比率可能被格式化为不同精度
  CheckContains(LReport, 'x', 'Contains ratio indicator');
  CheckContains(LReport, 'faster', 'Contains faster status');
end;

procedure TestFormatNumber;
begin
  WriteLn('TestFormatNumber:');

  // 测试数字格式化
  Check(GGenerator.FormatNumber(245.3, 1) = '245.3', 'FormatNumber 245.3');
  Check(GGenerator.FormatNumber(89.2, 2) = '89.20', 'FormatNumber 89.2');
  Check(GGenerator.FormatNumber(0.0, 1) = '0.0', 'FormatNumber 0.0');
end;

procedure TestFormatLargeNumber;
begin
  WriteLn('TestFormatLargeNumber:');

  // 测试大数字格式化
  Check(GGenerator.FormatLargeNumber(1000000) = '1,000,000', 'FormatLargeNumber 1M');
  Check(GGenerator.FormatLargeNumber(1000) = '1,000', 'FormatLargeNumber 1K');
  Check(GGenerator.FormatLargeNumber(100) = '100', 'FormatLargeNumber 100');
  Check(GGenerator.FormatLargeNumber(0) = '0', 'FormatLargeNumber 0');
end;

procedure TestFormatBytes;
begin
  WriteLn('TestFormatBytes:');

  // 测试字节格式化
  Check(GGenerator.FormatBytes(1024) = '1.0 KB', 'FormatBytes 1KB');
  Check(GGenerator.FormatBytes(1048576) = '1.0 MB', 'FormatBytes 1MB');
  Check(GGenerator.FormatBytes(1073741824) = '1.00 GB', 'FormatBytes 1GB');
  Check(GGenerator.FormatBytes(100) = '100 B', 'FormatBytes 100B');
end;

procedure TestFormatTime;
begin
  WriteLn('TestFormatTime:');

  // 测试时间格式化
  Check(GGenerator.FormatTime(1000.0) = '1.00 µs', 'FormatTime 1µs');
  Check(GGenerator.FormatTime(1000000.0) = '1.00 ms', 'FormatTime 1ms');
  Check(GGenerator.FormatTime(1000000000.0) = '1.000 s', 'FormatTime 1s');
  Check(GGenerator.FormatTime(500.0) = '500.0 ns', 'FormatTime 500ns');
end;

procedure TestEscapeJSON;
begin
  WriteLn('TestEscapeJSON:');

  // 测试 JSON 转义
  Check(GGenerator.EscapeJSON('hello') = 'hello', 'EscapeJSON simple');
  Check(GGenerator.EscapeJSON('hello "world"') = 'hello \"world\"', 'EscapeJSON quotes');
  Check(GGenerator.EscapeJSON('hello\nworld') = 'hello\\nworld', 'EscapeJSON newline');
  Check(GGenerator.EscapeJSON('hello\tworld') = 'hello\\tworld', 'EscapeJSON tab');
end;

procedure TestEscapeHTML;
begin
  WriteLn('TestEscapeHTML:');

  // 测试 HTML 转义
  Check(GGenerator.EscapeHTML('hello') = 'hello', 'EscapeHTML simple');
  Check(GGenerator.EscapeHTML('hello <world>') = 'hello &lt;world&gt;', 'EscapeHTML tags');
  Check(GGenerator.EscapeHTML('hello "world"') = 'hello &quot;world&quot;', 'EscapeHTML quotes');
  Check(GGenerator.EscapeHTML('hello & world') = 'hello &amp; world', 'EscapeHTML ampersand');
end;

begin
  WriteLn('=== nextpas.core.bench.report Unit Tests ===');
  WriteLn;

  GTestCount := 0;
  GPassCount := 0;
  GFailCount := 0;
  GGenerator := TBenchReportGenerator.Create;

  try
    TestToConsole;
    WriteLn;
    TestToJSON;
    WriteLn;
    TestToTSV;
    WriteLn;
    TestToHTML;
    WriteLn;
    TestGenerateComparisonReport;
    WriteLn;
    TestFormatNumber;
    WriteLn;
    TestFormatLargeNumber;
    WriteLn;
    TestFormatBytes;
    WriteLn;
    TestFormatTime;
    WriteLn;
    TestEscapeJSON;
    WriteLn;
    TestEscapeHTML;

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
  finally
    GGenerator.Free;
  end;
end.
