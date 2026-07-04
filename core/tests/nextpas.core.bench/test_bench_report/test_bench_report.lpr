program test_bench_report;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.bench.report,
  nextpas.core.test;

type
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;

var
  GGenerator: TBenchReportGenerator;

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

function CreateSkippedResults: TBenchResultArray;
begin
  Result := CreateTestResults;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Default(TBenchResult);
  Result[High(Result)].Name := 'Unsupported.SIMD';
  Result[High(Result)].Executed := True;
  Result[High(Result)].Skipped := True;
  Result[High(Result)].SkipReason := 'SIMD extension unavailable';
end;

procedure TestPrintToConsole;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LConsole: string;
begin
  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LConsole := GGenerator.PrintToConsole;

  CheckContains(LConsole, 'nextpas.core.bench v1.0');
  CheckContains(LConsole, 'Environment:');
  CheckContains(LConsole, 'OS: linux');
  CheckContains(LConsole, 'CPU: x86_64');
  CheckContains(LConsole, 'Cores: 16');
  CheckContains(LConsole, 'FPC: 3.3.1');
  CheckContains(LConsole, 'Benchmark Results:');
  CheckContains(LConsole, 'HashMap.Put');
  CheckContains(LConsole, 'HashMap.Get(hit)');
  CheckContains(LConsole, 'Bytes.Compare');
  CheckContains(LConsole, '245.3');
  CheckContains(LConsole, 'Statistics');
end;

procedure TestToJSON;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LJSON: string;
begin
  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LJSON := GGenerator.ToJSON;

  CheckContains(LJSON, '"version":"1.0"');
  CheckContains(LJSON, '"os":"linux"');
  CheckContains(LJSON, '"cpu":"x86_64"');
  CheckContains(LJSON, '"cores":16');
  CheckContains(LJSON, '"fpc_version":"3.3.1"');
  CheckContains(LJSON, '"name":"HashMap.Put"');
  CheckContains(LJSON, '"iterations":1000000');
  CheckContains(LJSON, '"ns_per_op":245.3');
  CheckContains(LJSON, '"ops_per_sec":4080000');
  CheckContains(LJSON, '"stddev":12.3');
  CheckContains(LJSON, '"median":243.1');
  CheckContains(LJSON, '"p95":268.4');
  CheckContains(LJSON, '"p99":289.2');
  CheckContains(LJSON, '"outliers":3');
end;

procedure TestToTSV;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LTSV: string;
begin
  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LTSV := GGenerator.ToTSV;

  CheckContains(LTSV, 'name' + #9 + 'status' + #9 + 'skip_reason' + #9 + 'iterations');
  CheckContains(LTSV, 'HashMap.Put' + #9 + 'ok' + #9 + #9 + '1000000');
  CheckContains(LTSV, 'HashMap.Get(hit)' + #9 + 'ok' + #9 + #9 + '5000000');
  CheckContains(LTSV, 'Bytes.Compare' + #9 + 'ok' + #9 + #9 + '10000000');
end;

procedure TestToHTML;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LHTML: string;
begin
  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LHTML := GGenerator.ToHTML;

  CheckContains(LHTML, '<!DOCTYPE html>');
  CheckContains(LHTML, '<title>nextpas.core.bench Report</title>');
  CheckContains(LHTML, '<h1>nextpas.core.bench Report</h1>');
  CheckContains(LHTML, '<h2>Environment</h2>');
  CheckContains(LHTML, 'linux');
  CheckContains(LHTML, 'x86_64');
  CheckContains(LHTML, '<h2>Benchmark Results</h2>');
  CheckContains(LHTML, 'HashMap.Put');
  CheckContains(LHTML, '245.3');
  CheckContains(LHTML, '<svg');
  Check(Pos('new Chart(', LHTML) = 0, 'Does not depend on Chart.js');
  CheckContains(LHTML, '<h2>Detailed Statistics</h2>');
end;

procedure TestToBenchstat;
var
  LResults: array of TBenchResult;
  LBenchstat: string;
begin
  LResults := CreateTestResults;

  GGenerator.SetResults(LResults);
  LBenchstat := GGenerator.ToBenchstat;

  CheckContains(LBenchstat, 'name');
  CheckContains(LBenchstat, 'ns/op');
  CheckContains(LBenchstat, '+- %');
  CheckContains(LBenchstat, 'B/op');
  CheckContains(LBenchstat, 'allocs/op');
  CheckContains(LBenchstat, 'HashMap.Put');
  CheckContains(LBenchstat, '245.3');
  CheckContains(LBenchstat, 'HashMap.Get(hit)');
  CheckContains(LBenchstat, '89.2');
  CheckContains(LBenchstat, 'Bytes.Compare');
  CheckContains(LBenchstat, '1024');
end;

procedure TestToCrossLanguageHTML;
var
  LEntries: TCrossLangEntryArray;
  LHTML: string;
begin
  SetLength(LEntries, 4);
  LEntries[0].Name := 'HashMap.Put';
  LEntries[0].Language := 'Pascal';
  LEntries[0].NsPerOp := 245.3;
  LEntries[1].Name := 'HashMap.Put';
  LEntries[1].Language := 'Go';
  LEntries[1].NsPerOp := 320.1;
  LEntries[2].Name := 'HashMap.Put';
  LEntries[2].Language := 'Rust';
  LEntries[2].NsPerOp := 180.5;
  LEntries[3].Name := 'Sort.1M';
  LEntries[3].Language := 'Pascal';
  LEntries[3].NsPerOp := 150000.0;

  LHTML := GGenerator.ToCrossLanguageHTML(LEntries);

  CheckContains(LHTML, '<!DOCTYPE html>');
  CheckContains(LHTML, 'Pascal');
  CheckContains(LHTML, 'Go');
  CheckContains(LHTML, 'Rust');
  CheckContains(LHTML, 'HashMap.Put');
  CheckContains(LHTML, '245.3');
  CheckContains(LHTML, 'Sort.1M');
end;

procedure TestGenerateBoxPlot;
var
  LSamples: TDoubleArray;
  LSVG: string;
begin
  SetLength(LSamples, 10);
  LSamples[0] := 1.0;
  LSamples[1] := 2.0;
  LSamples[2] := 3.0;
  LSamples[3] := 4.0;
  LSamples[4] := 5.0;
  LSamples[5] := 6.0;
  LSamples[6] := 7.0;
  LSamples[7] := 8.0;
  LSamples[8] := 9.0;
  LSamples[9] := 10.0;

  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'TestBench');

  CheckContains(LSVG, '<svg');
  CheckContains(LSVG, '<rect');
  CheckContains(LSVG, 'stroke="#ff6600"');
  CheckContains(LSVG, 'Boxplot TestBench');
end;

procedure TestToHTMLWithBoxPlot;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LHTML: string;
begin
  LResults := CreateTestResults;
  SetLength(LResults[0].RawSamples, 5);
  LResults[0].RawSamples[0] := 200.0;
  LResults[0].RawSamples[1] := 220.0;
  LResults[0].RawSamples[2] := 245.0;
  LResults[0].RawSamples[3] := 260.0;
  LResults[0].RawSamples[4] := 280.0;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LHTML := GGenerator.ToHTML;

  CheckContains(LHTML, 'Sample Distribution');
  CheckContains(LHTML, 'Boxplot HashMap.Put');
end;

procedure TestGenerateComparisonReport;
var
  LResults: array of TBenchResult;
  LComparisons: array of TBenchComparison;
  LReport: string;
begin
  LResults := CreateTestResults;

  SetLength(LComparisons, 2);
  LComparisons[0].BaselineName := 'HashMap.Put';
  LComparisons[0].BaselineNsPerOp := 250.0;
  LComparisons[0].CurrentNsPerOp := 245.3;
  LComparisons[0].Ratio := 1.019;
  LComparisons[0].HasStatisticalTest := False;
  LComparisons[0].IsSignificant := True;
  LComparisons[0].ApproximatePValue := 0.05;

  LComparisons[1].BaselineName := 'HashMap.Get(hit)';
  LComparisons[1].BaselineNsPerOp := 92.1;
  LComparisons[1].CurrentNsPerOp := 89.2;
  LComparisons[1].Ratio := 1.033;
  LComparisons[1].HasStatisticalTest := False;
  LComparisons[1].IsSignificant := True;
  LComparisons[1].ApproximatePValue := 0.05;

  LReport := GGenerator.GenerateComparisonReport(LComparisons);

  CheckContains(LReport, 'Baseline Comparison');
  CheckContains(LReport, 'HashMap.Put');
  CheckContains(LReport, 'HashMap.Get(hit)');
  CheckContains(LReport, 'x');
  CheckContains(LReport, 'SLOWER');
  Check(Pos('HashMap.Put', LReport) < Pos('HashMap.Get(hit)', LReport),
    'First comparison appears before second');
end;

procedure TestSkippedResultsReporting;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LConsole: string;
  LJSON: string;
  LTSV: string;
  LHTML: string;
begin
  LResults := CreateSkippedResults;
  LEnvironment := CreateTestEnvironment;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);

  LConsole := GGenerator.PrintToConsole;
  CheckContains(LConsole, 'Skipped Benchmarks');
  CheckContains(LConsole, 'SIMD extension unavailable');

  LJSON := GGenerator.ToJSON;
  CheckContains(LJSON, '"status":"skipped"');
  CheckContains(LJSON, '"skip_reason":"SIMD extension unavailable"');

  LTSV := GGenerator.ToTSV;
  CheckContains(LTSV, 'status' + #9 + 'skip_reason');
  CheckContains(LTSV, 'Unsupported.SIMD' + #9 + 'skipped' + #9 + 'SIMD extension unavailable');

  LHTML := GGenerator.ToHTML;
  CheckContains(LHTML, '<h2>Skipped Benchmarks</h2>');
  CheckContains(LHTML, 'SIMD extension unavailable');
end;

procedure TestFormatNumber;
begin
  Check(GGenerator.FormatNumber(245.3, 1) = '245.3', 'FormatNumber 245.3');
  Check(GGenerator.FormatNumber(89.2, 2) = '89.20', 'FormatNumber 89.2');
  Check(GGenerator.FormatNumber(0.0, 1) = '0.0', 'FormatNumber 0.0');
end;

procedure TestInvariantLocaleFormatting;
var
  LResults: array of TBenchResult;
  LEnvironment: TBenchEnvironment;
  LJSON: string;
begin
  Check(GGenerator.FormatNumber(245.3, 1) = '245.3',
    'FormatNumber uses invariant decimal separator');

  LResults := CreateTestResults;
  LEnvironment := CreateTestEnvironment;
  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(LEnvironment);
  LJSON := GGenerator.ToJSON;
  CheckContains(LJSON, '"ns_per_op":245.3');
  Check(Pos('"ns_per_op":245,3', LJSON) = 0, 'JSON does not emit locale decimal separator');
end;

procedure TestFormatLargeNumber;
begin
  Check(GGenerator.FormatLargeNumber(1000000) = '1,000,000', 'FormatLargeNumber 1M');
  Check(GGenerator.FormatLargeNumber(1000) = '1,000', 'FormatLargeNumber 1K');
  Check(GGenerator.FormatLargeNumber(100) = '100', 'FormatLargeNumber 100');
  Check(GGenerator.FormatLargeNumber(0) = '0', 'FormatLargeNumber 0');

  Check(GGenerator.FormatLargeNumber(-999) = '-999', 'FormatLargeNumber -999');
  Check(GGenerator.FormatLargeNumber(-1000) = '-1,000', 'FormatLargeNumber -1000');
  Check(GGenerator.FormatLargeNumber(1) = '1', 'FormatLargeNumber 1');
  Check(GGenerator.FormatLargeNumber(999) = '999', 'FormatLargeNumber 999');
  Check(GGenerator.FormatLargeNumber(1000000000) = '1,000,000,000', 'FormatLargeNumber 1B');
  Check(GGenerator.FormatLargeNumber(-1234567) = '-1,234,567', 'FormatLargeNumber -1.2M');
end;

procedure TestFormatBytes;
begin
  Check(GGenerator.FormatBytes(1024) = '1.0 KB', 'FormatBytes 1KB');
  Check(GGenerator.FormatBytes(1048576) = '1.0 MB', 'FormatBytes 1MB');
  Check(GGenerator.FormatBytes(1073741824) = '1.00 GB', 'FormatBytes 1GB');
  Check(GGenerator.FormatBytes(100) = '100 B', 'FormatBytes 100B');
end;

procedure TestFormatTime;
begin
  Check(GGenerator.FormatTime(1000.0) = '1.00 µs', 'FormatTime 1µs');
  Check(GGenerator.FormatTime(1000000.0) = '1.00 ms', 'FormatTime 1ms');
  Check(GGenerator.FormatTime(1000000000.0) = '1.000 s', 'FormatTime 1s');
  Check(GGenerator.FormatTime(500.0) = '500.0 ns', 'FormatTime 500ns');

  Check(GGenerator.FormatTime(0.0) = '0.0 ns', 'FormatTime 0ns');
  Check(GGenerator.FormatTime(1.0) = '1.0 ns', 'FormatTime 1ns');
  Check(GGenerator.FormatTime(999.0) = '999.0 ns', 'FormatTime 999ns');
  Check(GGenerator.FormatTime(999999.0) = '1000.00 µs', 'FormatTime 999999ns = 1000µs');
  Check(GGenerator.FormatTime(60000000000.0) = '60.000 s', 'FormatTime 60s');
end;

procedure TestEscapeJSON;
begin
  Check(GGenerator.EscapeJSON('hello') = 'hello', 'EscapeJSON simple');
  Check(GGenerator.EscapeJSON('hello "world"') = 'hello \"world\"', 'EscapeJSON quotes');
  Check(GGenerator.EscapeJSON('hello\nworld') = 'hello\\nworld', 'EscapeJSON newline');
  Check(GGenerator.EscapeJSON('hello\tworld') = 'hello\\tworld', 'EscapeJSON tab');
end;

procedure TestEscapeHTML;
begin
  Check(GGenerator.EscapeHTML('hello') = 'hello', 'EscapeHTML simple');
  Check(GGenerator.EscapeHTML('hello <world>') = 'hello &lt;world&gt;', 'EscapeHTML tags');
  Check(GGenerator.EscapeHTML('hello "world"') = 'hello &quot;world&quot;', 'EscapeHTML quotes');
  Check(GGenerator.EscapeHTML('hello & world') = 'hello &amp; world', 'EscapeHTML ampersand');
end;

procedure TestGenerateBoxPlot_EmptyData;
var
  LSamples: TDoubleArray;
  LSVG: string;
begin
  SetLength(LSamples, 0);
  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'Empty');
  Check(LSVG = '', 'GenerateBoxPlot with empty data returns empty string');
end;

procedure TestGenerateBoxPlot_SingleElement;
var
  LSamples: TDoubleArray;
  LSVG: string;
begin
  SetLength(LSamples, 1);
  LSamples[0] := 42.0;
  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'Single');
  Check(Length(LSVG) > 0, 'GenerateBoxPlot with single element produces SVG');
  CheckContains(LSVG, '<svg');
  CheckContains(LSVG, 'Boxplot Single');
end;

procedure TestGenerateBoxPlot_ConstantData;
var
  LSamples: TDoubleArray;
  LSVG: string;
  i: Integer;
begin
  SetLength(LSamples, 10);
  for i := 0 to 9 do
    LSamples[i] := 5.0;
  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'Constant');
  Check(Length(LSVG) > 0, 'GenerateBoxPlot with constant data produces SVG');
  CheckContains(LSVG, '<svg');
  CheckContains(LSVG, 'Boxplot Constant');
end;

procedure TestGenerateBoxPlot_SmallSamples;
{ CR-23: Verify boxplot works correctly with 2-3 samples using linear interpolation }
var
  LSamples: TDoubleArray;
  LSVG: string;
begin
  { 2 elements: Q1=first, Median=avg, Q3=second }
  SetLength(LSamples, 2);
  LSamples[0] := 10.0;
  LSamples[1] := 20.0;
  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'TwoElem');
  Check(Length(LSVG) > 0, 'GenerateBoxPlot with 2 elements produces SVG');
  CheckContains(LSVG, '<svg');

  { 3 elements: Q1=interpolated, Median=middle, Q3=interpolated }
  SetLength(LSamples, 3);
  LSamples[0] := 10.0;
  LSamples[1] := 20.0;
  LSamples[2] := 30.0;
  LSVG := GGenerator.GenerateBoxPlot(LSamples, 'ThreeElem');
  Check(Length(LSVG) > 0, 'GenerateBoxPlot with 3 elements produces SVG');
  CheckContains(LSVG, '<svg');
end;

procedure TestSanitizeTSVField;
var
  LResults: array of TBenchResult;
  LTSV: string;
begin
  SetLength(LResults, 2);
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'Bench' + #9 + 'Tab';
  LResults[0].NsPerOp := 100.0;
  LResults[0].OpsPerSec := 10000000;
  LResults[1] := Default(TBenchResult);
  LResults[1].Name := 'Bench' + #13 + 'CR';
  LResults[1].NsPerOp := 50.0;
  LResults[1].Skipped := True;
  LResults[1].SkipReason := 'reason' + #10 + 'LF';

  GGenerator.SetResults(LResults);

  LTSV := GGenerator.ToTSV;

  CheckContains(LTSV, 'Bench Tab');
  CheckContains(LTSV, 'Bench CR');
  CheckContains(LTSV, 'reason LF');
end;

procedure TestGenerateComparisonReport_Faster;
var
  LComparisons: array of TBenchComparison;
  LReport: string;
begin
  SetLength(LComparisons, 1);
  LComparisons[0].BaselineName := 'Sort.1K';
  LComparisons[0].BaselineNsPerOp := 100.0;
  LComparisons[0].CurrentNsPerOp := 80.0;
  LComparisons[0].Ratio := 0.8;
  LComparisons[0].HasStatisticalTest := False;
  LComparisons[0].IsSignificant := True;
  LComparisons[0].ApproximatePValue := 0.05;

  LReport := GGenerator.GenerateComparisonReport(LComparisons);

  CheckContains(LReport, 'Baseline Comparison');
  CheckContains(LReport, 'Sort.1K');
  CheckContains(LReport, 'FASTER');
  Check(Pos('SLOWER', LReport) = 0, 'Faster report does not show slower');
end;

procedure TestGenerateComparisonReport_SameRatio;
var
  LComparisons: array of TBenchComparison;
  LReport: string;
begin
  SetLength(LComparisons, 1);
  LComparisons[0].BaselineName := 'Lookup';
  LComparisons[0].BaselineNsPerOp := 50.0;
  LComparisons[0].CurrentNsPerOp := 50.0;
  LComparisons[0].Ratio := 1.0;
  LComparisons[0].HasStatisticalTest := False;
  LComparisons[0].IsSignificant := True;
  LComparisons[0].ApproximatePValue := 0.05;

  LReport := GGenerator.GenerateComparisonReport(LComparisons);

  CheckContains(LReport, 'Lookup');
  CheckContains(LReport, 'same');
end;

procedure TestGenerateComparisonReport_NotSignificant;
var
  LComparisons: array of TBenchComparison;
  LReport: string;
begin
  SetLength(LComparisons, 1);
  LComparisons[0].BaselineName := 'Memcpy';
  LComparisons[0].BaselineNsPerOp := 20.0;
  LComparisons[0].CurrentNsPerOp := 20.5;
  LComparisons[0].Ratio := 1.025;
  LComparisons[0].HasStatisticalTest := False;
  LComparisons[0].IsSignificant := False;
  LComparisons[0].ApproximatePValue := 0.05;

  LReport := GGenerator.GenerateComparisonReport(LComparisons);

  CheckContains(LReport, 'Memcpy');
  CheckContains(LReport, 'same');
  Check(Pos('SLOWER', LReport) = 0, 'Not significant report does not show slower');
  Check(Pos('FASTER', LReport) = 0, 'Not significant report does not show faster');
end;

procedure TestGenerateChart_AllSkipped;
var
  LResults: array of TBenchResult;
  LHTML: string;
begin
  SetLength(LResults, 2);
  LResults[0] := Default(TBenchResult);
  LResults[0].Name := 'Skipped1';
  LResults[0].Skipped := True;
  LResults[1] := Default(TBenchResult);
  LResults[1].Name := 'Skipped2';
  LResults[1].Skipped := True;

  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(CreateTestEnvironment);

  LHTML := GGenerator.ToHTML;
  CheckContains(LHTML, 'No benchmark data');
  CheckContains(LHTML, '<svg');
  CheckContains(LHTML, 'Skipped Benchmarks');
  CheckContains(LHTML, 'Skipped1');
  CheckContains(LHTML, 'Skipped2');
end;

procedure Test_EmptyResults_ToJSON;
var
  LResults: TBenchResultArray;
  LJSON: string;
begin
  SetLength(LResults, 0);
  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(CreateTestEnvironment);

  LJSON := GGenerator.ToJSON;
  Check(Length(LJSON) > 0, 'Empty results JSON is non-empty (structural)');
  CheckContains(LJSON, '"version"');
  CheckContains(LJSON, '"benchmarks"');
end;

procedure Test_EmptyResults_ToHTML;
var
  LResults: TBenchResultArray;
  LHTML: string;
begin
  SetLength(LResults, 0);
  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(CreateTestEnvironment);

  LHTML := GGenerator.ToHTML;
  CheckContains(LHTML, '<!DOCTYPE html>');
  CheckContains(LHTML, '<h1>');
end;

procedure Test_EmptyResults_PrintToConsole;
var
  LResults: TBenchResultArray;
  LConsole: string;
begin
  SetLength(LResults, 0);
  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(CreateTestEnvironment);

  LConsole := GGenerator.PrintToConsole;
  CheckContains(LConsole, 'nextpas.core.bench v1.0');
end;

procedure TestSetMaxDetailCount;
var
  LResults: TBenchResultArray;
  LHTML: string;
  LCount1, LCount2: Integer;
begin
  LResults := CreateTestResults;

  { Default max detail count (5) should include detailed stats }
  GGenerator.SetResults(LResults);
  GGenerator.SetEnvironment(CreateTestEnvironment);
  LHTML := GGenerator.ToHTML;
  LCount1 := Length(LHTML);

  { Set max detail to 0 — should exclude detailed stats, shorter HTML }
  GGenerator.SetMaxDetailCount(0);
  GGenerator.SetResults(LResults);
  LHTML := GGenerator.ToHTML;
  LCount2 := Length(LHTML);
  Check(LCount2 < LCount1, 'SetMaxDetailCount(0) produces shorter HTML than default');

  { Set max detail to 100 — should not crash, same or longer than default }
  GGenerator.SetMaxDetailCount(100);
  GGenerator.SetResults(LResults);
  LHTML := GGenerator.ToHTML;
  Check(Length(LHTML) >= LCount1, 'SetMaxDetailCount(100) produces at least as much as default');
end;

var
  T: TTestSuite;
begin
  GGenerator := TBenchReportGenerator.Create;
  try
    T := TTestSuite.Create('nextpas.core.bench.report');
    T.Test('print to console', @TestPrintToConsole);
    T.Test('to JSON', @TestToJSON);
    T.Test('to TSV', @TestToTSV);
    T.Test('to HTML', @TestToHTML);
    T.Test('to benchstat', @TestToBenchstat);
    T.Test('to cross-language HTML', @TestToCrossLanguageHTML);
    T.Test('generate box plot', @TestGenerateBoxPlot);
    T.Test('box plot small samples', @TestGenerateBoxPlot_SmallSamples);
    T.Test('to HTML with box plot', @TestToHTMLWithBoxPlot);
    T.Test('generate comparison report', @TestGenerateComparisonReport);
    T.Test('comparison report faster', @TestGenerateComparisonReport_Faster);
    T.Test('comparison report same ratio', @TestGenerateComparisonReport_SameRatio);
    T.Test('comparison report not significant', @TestGenerateComparisonReport_NotSignificant);
    T.Test('generate chart all skipped', @TestGenerateChart_AllSkipped);
    T.Test('skipped results reporting', @TestSkippedResultsReporting);
    T.Test('format number', @TestFormatNumber);
    T.Test('invariant locale formatting', @TestInvariantLocaleFormatting);
    T.Test('format large number', @TestFormatLargeNumber);
    T.Test('format bytes', @TestFormatBytes);
    T.Test('format time', @TestFormatTime);
    T.Test('escape JSON', @TestEscapeJSON);
    T.Test('escape HTML', @TestEscapeHTML);
    T.Test('sanitize TSV field', @TestSanitizeTSVField);
    T.Test('box plot empty data', @TestGenerateBoxPlot_EmptyData);
    T.Test('box plot single element', @TestGenerateBoxPlot_SingleElement);
    T.Test('box plot constant data', @TestGenerateBoxPlot_ConstantData);
    T.Test('empty results to JSON', @Test_EmptyResults_ToJSON);
    T.Test('empty results to HTML', @Test_EmptyResults_ToHTML);
    T.Test('empty results print to console', @Test_EmptyResults_PrintToConsole);
    T.Test('set max detail count', @TestSetMaxDetailCount);
    T.Run;
    T.Summary;
  finally
    GGenerator.Free;
  end;
end.
