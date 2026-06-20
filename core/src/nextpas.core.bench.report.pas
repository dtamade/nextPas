unit nextpas.core.bench.report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats;

type
  {** 报告生成器 }
  TBenchReportGenerator = class
  private
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FEnvironment: TBenchEnvironment;
    FStatsAnalyzer: IBenchStatsAnalyzer;

    {** 格式化数字 }
    function FormatNumber(AValue: Double; APrecision: Integer): string;

    {** 格式化大数字（带分隔符） }
    function FormatLargeNumber(AValue: Int64): string;

    {** 格式化字节大小 }
    function FormatBytes(ABytes: Int64): string;

    {** 格式化时间 }
    function FormatTime(ANs: Double): string;

    {** 转义 JSON 字符串 }
    function EscapeJSON(const AStr: string): string;

    {** 转义 HTML 字符串 }
    function EscapeHTML(const AStr: string): string;

    {** 生成 HTML 图表 }
    function GenerateChart(const AResults: array of TBenchResult): string;

    {** 生成 HTML 样式 }
    function GenerateCSS: string;

    {** 生成 HTML 脚本 }
    function GenerateJS: string;

  public
    constructor Create;
    destructor Destroy; override;

    {** 设置结果 }
    procedure SetResults(const AResults: array of TBenchResult);

    {** 设置环境信息 }
    procedure SetEnvironment(const AEnvironment: TBenchEnvironment);

    {** 生成控制台报告 }
    function ToConsole: string;

    {** 生成 JSON 报告 }
    function ToJSON: string;

    {** 生成 TSV 报告 }
    function ToTSV: string;

    {** 生成 HTML 报告 }
    function ToHTML: string;

    {** 生成基线对比报告 }
    function GenerateComparisonReport(
      const AResults: array of TBenchResult;
      const ABaselines: array of TBenchComparison): string;
  end;

implementation

uses
  SysUtils, StrUtils;

{ TBenchReportGenerator }

constructor TBenchReportGenerator.Create;
begin
  inherited Create;
  FStatsAnalyzer := TBenchStatsAnalyzer.Create;
  FResultCount := 0;
  SetLength(FResults, 0);
end;

destructor TBenchReportGenerator.Destroy;
begin
  SetLength(FResults, 0);
  inherited Destroy;
end;

procedure TBenchReportGenerator.SetResults(const AResults: array of TBenchResult);
var
  i: Integer;
begin
  FResultCount := Length(AResults);
  SetLength(FResults, FResultCount);
  for i := 0 to FResultCount - 1 do
    FResults[i] := AResults[i];
end;

procedure TBenchReportGenerator.SetEnvironment(const AEnvironment: TBenchEnvironment);
begin
  FEnvironment := AEnvironment;
end;

function TBenchReportGenerator.FormatNumber(AValue: Double; APrecision: Integer): string;
begin
  Result := FloatToStrF(AValue, ffFixed, 15, APrecision);
end;

function TBenchReportGenerator.FormatLargeNumber(AValue: Int64): string;
var
  LStr: string;
  LLen, i: Integer;
begin
  LStr := IntToStr(AValue);
  LLen := Length(LStr);
  Result := '';

  for i := 1 to LLen do
  begin
    if (i > 1) and ((LLen - i + 1) mod 3 = 0) then
      Result := Result + ',';
    Result := Result + LStr[i];
  end;
end;

function TBenchReportGenerator.FormatBytes(ABytes: Int64): string;
begin
  if ABytes < 1024 then
    Result := IntToStr(ABytes) + ' B'
  else if ABytes < 1024 * 1024 then
    Result := FormatNumber(ABytes / 1024.0, 1) + ' KB'
  else if ABytes < 1024 * 1024 * 1024 then
    Result := FormatNumber(ABytes / (1024.0 * 1024.0), 1) + ' MB'
  else
    Result := FormatNumber(ABytes / (1024.0 * 1024.0 * 1024.0), 2) + ' GB';
end;

function TBenchReportGenerator.FormatTime(ANs: Double): string;
begin
  if ANs < 1000 then
    Result := FormatNumber(ANs, 1) + ' ns'
  else if ANs < 1000000 then
    Result := FormatNumber(ANs / 1000.0, 2) + ' µs'
  else if ANs < 1000000000 then
    Result := FormatNumber(ANs / 1000000.0, 2) + ' ms'
  else
    Result := FormatNumber(ANs / 1000000000.0, 3) + ' s';
end;

function TBenchReportGenerator.EscapeJSON(const AStr: string): string;
begin
  Result := AStr;
  Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function TBenchReportGenerator.EscapeHTML(const AStr: string): string;
begin
  Result := AStr;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function TBenchReportGenerator.ToConsole: string;
var
  LLines: TStringArray;
  i: Integer;
begin
  SetLength(LLines, 0);

  // 标题
  Add(LLines, '=== nextpas.core.bench v1.0 ===');
  Add(LLines, '');
  Add(LLines, 'Environment:');
  Add(LLines, '  OS: ' + FEnvironment.OS);
  Add(LLines, '  CPU: ' + FEnvironment.CPU);
  Add(LLines, '  Cores: ' + IntToStr(FEnvironment.Cores));
  Add(LLines, '  FPC: ' + FEnvironment.FPCVersion);
  Add(LLines, '  Time: ' + FEnvironment.Timestamp);
  Add(LLines, '');
  Add(LLines, 'Benchmark Results:');
  Add(LLines, '');

  // 表头
  Add(LLines, Format('  %-40s %10s %10s %10s %10s %10s',
    ['Name', 'Iterations', 'ns/op', 'ops/s', 'StdDev', 'P99']));
  Add(LLines, '  ' + StringOfChar('-', 100));

  // 结果
  for i := 0 to FResultCount - 1 do
  begin
    Add(LLines, Format('  %-40s %10s %10s %10s %10s %10s',
      [FResults[i].Name,
       FormatLargeNumber(FResults[i].Iterations),
       FormatNumber(FResults[i].NsPerOp, 1),
       FormatLargeNumber(Int64(FResults[i].OpsPerSec)),
       FormatNumber(FResults[i].StdDev, 1),
       FormatNumber(FResults[i].P99, 1)]));
  end;

  Add(LLines, '');
  Add(LLines, '=== Statistics ===');

  // 详细统计（只显示前 5 个结果）
  for i := 0 to Min(4, FResultCount - 1) do
  begin
    Add(LLines, '');
    Add(LLines, FResults[i].Name + ':');
    Add(LLines, Format('  Mean: %s  StdDev: %s  Median: %s',
      [FormatTime(FResults[i].NsPerOp),
       FormatTime(FResults[i].StdDev),
       FormatTime(FResults[i].Median)]));
    Add(LLines, Format('  P95: %s  P99: %s  Outliers: %d/%d',
      [FormatTime(FResults[i].P95),
       FormatTime(FResults[i].P99),
       FResults[i].Outliers,
       FResults[i].SampleCount]));
  end;

  Result := '';
  for i := 0 to High(LLines) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + LLines[i];
  end;
end;

function TBenchReportGenerator.ToJSON: string;
var
  LJSON: TStringArray;
  i: Integer;
begin
  SetLength(LJSON, 0);

  Add(LJSON, '{');
  Add(LJSON, '  "version": "1.0",');
  Add(LJSON, '  "timestamp": "' + FEnvironment.Timestamp + '",');
  Add(LJSON, '  "environment": {');
  Add(LJSON, '    "os": "' + EscapeJSON(FEnvironment.OS) + '",');
  Add(LJSON, '    "cpu": "' + EscapeJSON(FEnvironment.CPU) + '",');
  Add(LJSON, '    "cores": ' + IntToStr(FEnvironment.Cores) + ',');
  Add(LJSON, '    "fpc_version": "' + EscapeJSON(FEnvironment.FPCVersion) + '"');
  Add(LJSON, '  },');
  Add(LJSON, '  "benchmarks": [');

  for i := 0 to FResultCount - 1 do
  begin
    Add(LJSON, '    {');
    Add(LJSON, '      "name": "' + EscapeJSON(FResults[i].Name) + '",');
    Add(LJSON, '      "iterations": ' + IntToStr(FResults[i].Iterations) + ',');
    Add(LJSON, '      "ns_per_op": ' + FormatNumber(FResults[i].NsPerOp, 2) + ',');
    Add(LJSON, '      "ops_per_sec": ' + FormatNumber(FResults[i].OpsPerSec, 0) + ',');
    Add(LJSON, '      "bytes_per_op": ' + IntToStr(FResults[i].BytesPerOp) + ',');
    Add(LJSON, '      "allocs_per_op": ' + IntToStr(FResults[i].AllocsPerOp) + ',');
    Add(LJSON, '      "statistics": {');
    Add(LJSON, '        "stddev": ' + FormatNumber(FResults[i].StdDev, 2) + ',');
    Add(LJSON, '        "median": ' + FormatNumber(FResults[i].Median, 2) + ',');
    Add(LJSON, '        "p95": ' + FormatNumber(FResults[i].P95, 2) + ',');
    Add(LJSON, '        "p99": ' + FormatNumber(FResults[i].P99, 2) + ',');
    Add(LJSON, '        "outliers": ' + IntToStr(FResults[i].Outliers) + ',');
    Add(LJSON, '        "sample_count": ' + IntToStr(FResults[i].SampleCount));
    Add(LJSON, '      }');
    if i < FResultCount - 1 then
      Add(LJSON, '    },')
    else
      Add(LJSON, '    }');
  end;

  Add(LJSON, '  ]');
  Add(LJSON, '}');

  Result := '';
  for i := 0 to High(LJSON) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + LJSON[i];
  end;
end;

function TBenchReportGenerator.ToTSV: string;
var
  LLines: TStringArray;
  i: Integer;
begin
  SetLength(LLines, 0);

  // 表头
  Add(LLines, 'name' + #9 + 'iterations' + #9 + 'ns_per_op' + #9 + 'ops_per_sec' + #9 + 'stddev' + #9 + 'median' + #9 + 'p95' + #9 + 'p99' + #9 + 'outliers' + #9 + 'samples');

  // 数据
  for i := 0 to FResultCount - 1 do
  begin
    Add(LLines,
      FResults[i].Name + #9 +
      IntToStr(FResults[i].Iterations) + #9 +
      FormatNumber(FResults[i].NsPerOp, 2) + #9 +
      FormatNumber(FResults[i].OpsPerSec, 0) + #9 +
      FormatNumber(FResults[i].StdDev, 2) + #9 +
      FormatNumber(FResults[i].Median, 2) + #9 +
      FormatNumber(FResults[i].P95, 2) + #9 +
      FormatNumber(FResults[i].P99, 2) + #9 +
      IntToStr(FResults[i].Outliers) + #9 +
      IntToStr(FResults[i].SampleCount));
  end;

  Result := '';
  for i := 0 to High(LLines) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + LLines[i];
  end;
end;

function TBenchReportGenerator.GenerateChart(const AResults: array of TBenchResult): string;
var
  LLabels, LData: string;
  i: Integer;
begin
  LLabels := '';
  LData := '';

  for i := 0 to High(AResults) do
  begin
    if i > 0 then
    begin
      LLabels := LLabels + ', ';
      LData := LData + ', ';
    end;
    LLabels := LLabels + '"' + EscapeJSON(AResults[i].Name) + '"';
    LData := LData + FormatNumber(AResults[i].NsPerOp, 2);
  end;

  Result :=
    '<canvas id="benchmarkChart" width="800" height="400"></canvas>' + LineEnding +
    '<script>' + LineEnding +
    '  var ctx = document.getElementById("benchmarkChart").getContext("2d");' + LineEnding +
    '  var chart = new Chart(ctx, {' + LineEnding +
    '    type: "bar",' + LineEnding +
    '    data: {' + LineEnding +
    '      labels: [' + LLabels + '],' + LineEnding +
    '      datasets: [{' + LineEnding +
    '        label: "ns/op",' + LineEnding +
    '        data: [' + LData + '],' + LineEnding +
    '        backgroundColor: "rgba(54, 162, 235, 0.5)",' + LineEnding +
    '        borderColor: "rgba(54, 162, 235, 1)",' + LineEnding +
    '        borderWidth: 1' + LineEnding +
    '      }]' + LineEnding +
    '    },' + LineEnding +
    '    options: {' + LineEnding +
    '      scales: {' + LineEnding +
    '        y: {' + LineEnding +
    '          beginAtZero: true' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  });' + LineEnding +
    '</script>';
end;

function TBenchReportGenerator.GenerateCSS: string;
begin
  Result :=
    '<style>' + LineEnding +
    '  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; }' + LineEnding +
    '  h1 { color: #333; }' + LineEnding +
    '  table { border-collapse: collapse; width: 100%; margin: 20px 0; }' + LineEnding +
    '  th, td { border: 1px solid #ddd; padding: 8px; text-align: right; }' + LineEnding +
    '  th { background-color: #f2f2f2; font-weight: bold; }' + LineEnding +
    '  tr:nth-child(even) { background-color: #f9f9f9; }' + LineEnding +
    '  tr:hover { background-color: #f1f1f1; }' + LineEnding +
    '  .benchmark-name { text-align: left; font-weight: bold; }' + LineEnding +
    '  .stats { margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 5px; }' + LineEnding +
    '  .chart-container { margin: 30px 0; }' + LineEnding +
    '</style>';
end;

function TBenchReportGenerator.GenerateJS: string;
begin
  Result :=
    '<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>';
end;

function TBenchReportGenerator.ToHTML: string;
var
  LHTML: TStringArray;
  i: Integer;
begin
  SetLength(LHTML, 0);

  Add(LHTML, '<!DOCTYPE html>');
  Add(LHTML, '<html>');
  Add(LHTML, '<head>');
  Add(LHTML, '  <title>nextpas.core.bench Report</title>');
  Add(LHTML, '  <meta charset="UTF-8">');
  Add(LHTML, '  ' + GenerateCSS);
  Add(LHTML, '  ' + GenerateJS);
  Add(LHTML, '</head>');
  Add(LHTML, '<body>');
  Add(LHTML, '  <h1>nextpas.core.bench Report</h1>');
  Add(LHTML, '');
  Add(LHTML, '  <div class="stats">');
  Add(LHTML, '    <h2>Environment</h2>');
  Add(LHTML, '    <p><strong>OS:</strong> ' + EscapeHTML(FEnvironment.OS) + '</p>');
  Add(LHTML, '    <p><strong>CPU:</strong> ' + EscapeHTML(FEnvironment.CPU) + '</p>');
  Add(LHTML, '    <p><strong>Cores:</strong> ' + IntToStr(FEnvironment.Cores) + '</p>');
  Add(LHTML, '    <p><strong>FPC:</strong> ' + EscapeHTML(FEnvironment.FPCVersion) + '</p>');
  Add(LHTML, '    <p><strong>Time:</strong> ' + EscapeHTML(FEnvironment.Timestamp) + '</p>');
  Add(LHTML, '  </div>');
  Add(LHTML, '');
  Add(LHTML, '  <div class="chart-container">');
  Add(LHTML, '    <h2>Performance Chart</h2>');
  Add(LHTML, '    ' + GenerateChart(FResults));
  Add(LHTML, '  </div>');
  Add(LHTML, '');
  Add(LHTML, '  <h2>Benchmark Results</h2>');
  Add(LHTML, '  <table>');
  Add(LHTML, '    <thead>');
  Add(LHTML, '      <tr>');
  Add(LHTML, '        <th>Name</th>');
  Add(LHTML, '        <th>Iterations</th>');
  Add(LHTML, '        <th>ns/op</th>');
  Add(LHTML, '        <th>ops/s</th>');
  Add(LHTML, '        <th>StdDev</th>');
  Add(LHTML, '        <th>Median</th>');
  Add(LHTML, '        <th>P95</th>');
  Add(LHTML, '        <th>P99</th>');
  Add(LHTML, '        <th>Outliers</th>');
  Add(LHTML, '      </tr>');
  Add(LHTML, '    </thead>');
  Add(LHTML, '    <tbody>');

  for i := 0 to FResultCount - 1 do
  begin
    Add(LHTML, '      <tr>');
    Add(LHTML, '        <td class="benchmark-name">' + EscapeHTML(FResults[i].Name) + '</td>');
    Add(LHTML, '        <td>' + FormatLargeNumber(FResults[i].Iterations) + '</td>');
    Add(LHTML, '        <td>' + FormatNumber(FResults[i].NsPerOp, 1) + '</td>');
    Add(LHTML, '        <td>' + FormatLargeNumber(Int64(FResults[i].OpsPerSec)) + '</td>');
    Add(LHTML, '        <td>' + FormatNumber(FResults[i].StdDev, 1) + '</td>');
    Add(LHTML, '        <td>' + FormatNumber(FResults[i].Median, 1) + '</td>');
    Add(LHTML, '        <td>' + FormatNumber(FResults[i].P95, 1) + '</td>');
    Add(LHTML, '        <td>' + FormatNumber(FResults[i].P99, 1) + '</td>');
    Add(LHTML, '        <td>' + IntToStr(FResults[i].Outliers) + '</td>');
    Add(LHTML, '      </tr>');
  end;

  Add(LHTML, '    </tbody>');
  Add(LHTML, '  </table>');
  Add(LHTML, '');
  Add(LHTML, '  <div class="stats">');
  Add(LHTML, '    <h2>Detailed Statistics</h2>');

  // 显示前 5 个结果的详细统计
  for i := 0 to Min(4, FResultCount - 1) do
  begin
    Add(LHTML, '    <h3>' + EscapeHTML(FResults[i].Name) + '</h3>');
    Add(LHTML, '    <p>Mean: ' + FormatTime(FResults[i].NsPerOp) + '</p>');
    Add(LHTML, '    <p>StdDev: ' + FormatTime(FResults[i].StdDev) + '</p>');
    Add(LHTML, '    <p>Median: ' + FormatTime(FResults[i].Median) + '</p>');
    Add(LHTML, '    <p>P95: ' + FormatTime(FResults[i].P95) + '</p>');
    Add(LHTML, '    <p>P99: ' + FormatTime(FResults[i].P99) + '</p>');
    Add(LHTML, '    <p>Outliers: ' + IntToStr(FResults[i].Outliers) + '/' + IntToStr(FResults[i].SampleCount) + '</p>');
  end;

  Add(LHTML, '  </div>');
  Add(LHTML, '</body>');
  Add(LHTML, '</html>');

  Result := '';
  for i := 0 to High(LHTML) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + LHTML[i];
  end;
end;

function TBenchReportGenerator.GenerateComparisonReport(
  const AResults: array of TBenchResult;
  const ABaselines: array of TBenchComparison): string;
var
  LLines: TStringArray;
  i: Integer;
begin
  SetLength(LLines, 0);

  Add(LLines, '=== Baseline Comparison ===');
  Add(LLines, '');
  Add(LLines, Format('  %-40s %10s %10s %10s %10s',
    ['Benchmark', 'Current', 'Baseline', 'Ratio', 'Status']));
  Add(LLines, '  ' + StringOfChar('-', 90));

  for i := 0 to High(ABaselines) do
  begin
    Add(LLines, Format('  %-40s %10s %10s %10s %10s',
      [ABaselines[i].BaselineName,
       FormatTime(ABaselines[i].CurrentNsPerOp),
       FormatTime(ABaselines[i].BaselineNsPerOp),
       FormatNumber(ABaselines[i].Ratio, 2) + 'x',
       IfThen(ABaselines[i].Significant,
         IfThen(ABaselines[i].Ratio > 1.0, '✓ faster', '✗ slower'),
         '≈ same')]));
  end;

  Result := '';
  for i := 0 to High(LLines) do
  begin
    if i > 0 then
      Result := Result + LineEnding;
    Result := Result + LLines[i];
  end;
end;

end.
