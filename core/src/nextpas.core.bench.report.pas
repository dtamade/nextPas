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

    {** 生成 HTML 图表 }
    function GenerateChart(const AResults: array of TBenchResult): string;

    {** 生成 HTML 样式 }
    function GenerateCSS: string;

    {** 生成 HTML 脚本 }
    function GenerateJS: string;

  public
    constructor Create;
    destructor Destroy; override;

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
  SysUtils, StrUtils, Math;

function CreateInvariantFormatSettings: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
  Result.ThousandSeparator := ',';
end;

{ 辅助函数：添加字符串到数组 }
procedure AddLine(var ALines: TStringArray; const ALine: string);
begin
  SetLength(ALines, Length(ALines) + 1);
  ALines[High(ALines)] := ALine;
end;

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
  Result := FloatToStrF(AValue, ffFixed, 18, APrecision, CreateInvariantFormatSettings);
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
  LSkippedCount: Integer;
  i: Integer;
begin
  SetLength(LLines, 0);

  // 标题
  AddLine(LLines, '=== nextpas.core.bench v1.0 ===');
  AddLine(LLines, '');
  AddLine(LLines, 'Environment:');
  AddLine(LLines, '  OS: ' + FEnvironment.OS);
  AddLine(LLines, '  CPU: ' + FEnvironment.CPU);
  AddLine(LLines, '  Cores: ' + IntToStr(FEnvironment.Cores));
  AddLine(LLines, '  FPC: ' + FEnvironment.FPCVersion);
  AddLine(LLines, '  Time: ' + FEnvironment.Timestamp);
  AddLine(LLines, '');
  AddLine(LLines, 'Benchmark Results:');
  AddLine(LLines, '');

  // 表头
  AddLine(LLines, Format('  %-40s %10s %10s %10s %10s %10s',
    ['Name', 'Iterations', 'ns/op', 'ops/s', 'StdDev', 'P99']));
  AddLine(LLines, '  ' + StringOfChar('-', 100));

  // 结果（只显示未跳过的）
  for i := 0 to FResultCount - 1 do
  begin
    if not FResults[i].Skipped then
    begin
      AddLine(LLines, Format('  %-40s %10s %10s %10s %10s %10s',
        [FResults[i].Name,
         FormatLargeNumber(FResults[i].Iterations),
         FormatNumber(FResults[i].NsPerOp, 1),
         FormatLargeNumber(Int64(FResults[i].OpsPerSec)),
         FormatNumber(FResults[i].StdDev, 1),
         FormatNumber(FResults[i].P99, 1)]));
    end;
  end;

  // 跳过的基准
  LSkippedCount := 0;
  for i := 0 to FResultCount - 1 do
    if FResults[i].Skipped then
      Inc(LSkippedCount);

  if LSkippedCount > 0 then
  begin
    AddLine(LLines, '');
    AddLine(LLines, 'Skipped Benchmarks:');
    AddLine(LLines, '');
    for i := 0 to FResultCount - 1 do
    begin
      if FResults[i].Skipped then
      begin
        AddLine(LLines, '  ' + FResults[i].Name);
        AddLine(LLines, '    Reason: ' + FResults[i].SkipReason);
      end;
    end;
  end;

  AddLine(LLines, '');
  AddLine(LLines, '=== Statistics ===');

  // 详细统计（只显示前 5 个未跳过的结果）
  LSkippedCount := 0;
  for i := 0 to Min(4 + LSkippedCount, FResultCount - 1) do
  begin
    if FResults[i].Skipped then
    begin
      Inc(LSkippedCount);
      Continue;
    end;
    if i - LSkippedCount >= 5 then
      Break;
    AddLine(LLines, '');
    AddLine(LLines, FResults[i].Name + ':');
    AddLine(LLines, Format('  Mean: %s  StdDev: %s  Median: %s',
      [FormatTime(FResults[i].NsPerOp),
       FormatTime(FResults[i].StdDev),
       FormatTime(FResults[i].Median)]));
    AddLine(LLines, Format('  P95: %s  P99: %s  Outliers: %d/%d',
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

  AddLine(LJSON, '{');
  AddLine(LJSON, '  "version": "1.0",');
  AddLine(LJSON, '  "timestamp": "' + FEnvironment.Timestamp + '",');
  AddLine(LJSON, '  "environment": {');
  AddLine(LJSON, '    "os": "' + EscapeJSON(FEnvironment.OS) + '",');
  AddLine(LJSON, '    "cpu": "' + EscapeJSON(FEnvironment.CPU) + '",');
  AddLine(LJSON, '    "cores": ' + IntToStr(FEnvironment.Cores) + ',');
  AddLine(LJSON, '    "fpc_version": "' + EscapeJSON(FEnvironment.FPCVersion) + '"');
  AddLine(LJSON, '  },');
  AddLine(LJSON, '  "benchmarks": [');

  for i := 0 to FResultCount - 1 do
  begin
    AddLine(LJSON, '    {');
    AddLine(LJSON, '      "name": "' + EscapeJSON(FResults[i].Name) + '",');
    if FResults[i].Skipped then
    begin
      AddLine(LJSON, '      "status": "skipped",');
      AddLine(LJSON, '      "skip_reason": "' + EscapeJSON(FResults[i].SkipReason) + '",');
    end
    else
    begin
      AddLine(LJSON, '      "status": "ok",');
    end;
    AddLine(LJSON, '      "iterations": ' + IntToStr(FResults[i].Iterations) + ',');
    AddLine(LJSON, '      "ns_per_op": ' + FormatNumber(FResults[i].NsPerOp, 2) + ',');
    AddLine(LJSON, '      "ops_per_sec": ' + FormatNumber(FResults[i].OpsPerSec, 0) + ',');
    AddLine(LJSON, '      "bytes_per_op": ' + IntToStr(FResults[i].BytesPerOp) + ',');
    AddLine(LJSON, '      "allocs_per_op": ' + IntToStr(FResults[i].AllocsPerOp) + ',');
    AddLine(LJSON, '      "statistics": {');
    AddLine(LJSON, '        "stddev": ' + FormatNumber(FResults[i].StdDev, 2) + ',');
    AddLine(LJSON, '        "median": ' + FormatNumber(FResults[i].Median, 2) + ',');
    AddLine(LJSON, '        "p95": ' + FormatNumber(FResults[i].P95, 2) + ',');
    AddLine(LJSON, '        "p99": ' + FormatNumber(FResults[i].P99, 2) + ',');
    AddLine(LJSON, '        "outliers": ' + IntToStr(FResults[i].Outliers) + ',');
    AddLine(LJSON, '        "sample_count": ' + IntToStr(FResults[i].SampleCount));
    AddLine(LJSON, '      }');
    if i < FResultCount - 1 then
      AddLine(LJSON, '    },')
    else
      AddLine(LJSON, '    }');
  end;

  AddLine(LJSON, '  ]');
  AddLine(LJSON, '}');

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
  AddLine(LLines, 'name' + #9 + 'status' + #9 + 'skip_reason' + #9 + 'iterations' + #9 + 'ns_per_op' + #9 + 'ops_per_sec' + #9 + 'stddev' + #9 + 'median' + #9 + 'p95' + #9 + 'p99' + #9 + 'outliers' + #9 + 'samples');

  // 数据
  for i := 0 to FResultCount - 1 do
  begin
    AddLine(LLines,
      FResults[i].Name + #9 +
      IfThen(FResults[i].Skipped, 'skipped', 'ok') + #9 +
      FResults[i].SkipReason + #9 +
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
  LLines: TStringArray;
  LMaxNsPerOp: Double;
  LBarWidth: Double;
  LBarHeight: Double;
  LBarX: Double;
  LBarY: Double;
  LHeightRatio: Double;
  I: Integer;
begin
  if Length(AResults) = 0 then
    Exit('<svg class="bench-chart" viewBox="0 0 820 280" role="img" aria-label="No benchmark data"></svg>');

  LMaxNsPerOp := 0.0;
  for I := 0 to High(AResults) do
    if AResults[I].NsPerOp > LMaxNsPerOp then
      LMaxNsPerOp := AResults[I].NsPerOp;
  if LMaxNsPerOp <= 0 then
    LMaxNsPerOp := 1.0;

  SetLength(LLines, 0);
  AddLine(LLines, '<svg class="bench-chart" viewBox="0 0 820 280" role="img" aria-label="Benchmark ns per op chart">');
  AddLine(LLines, '  <rect x="0" y="0" width="820" height="280" rx="18" fill="#fbfcfd"/>');
  AddLine(LLines, '  <line x1="64" y1="236" x2="784" y2="236" stroke="#cfd7de" stroke-width="1"/>');
  AddLine(LLines, '  <line x1="64" y1="24" x2="64" y2="236" stroke="#cfd7de" stroke-width="1"/>');

  LBarWidth := 720.0 / Max(Length(AResults), 1);
  for I := 0 to High(AResults) do
  begin
    LHeightRatio := AResults[I].NsPerOp / LMaxNsPerOp;
    LBarHeight := 184.0 * LHeightRatio;
    LBarX := 76.0 + I * LBarWidth;
    LBarY := 236.0 - LBarHeight;

    AddLine(LLines,
      Format('  <rect x="%s" y="%s" width="%s" height="%s" rx="8" fill="#4a7a6f"/>',
        [FormatNumber(LBarX, 2),
         FormatNumber(LBarY, 2),
         FormatNumber(Max(LBarWidth - 18.0, 14.0), 2),
         FormatNumber(LBarHeight, 2)]));
    AddLine(LLines,
      Format('  <text x="%s" y="%s" class="chart-value">%s ns</text>',
        [FormatNumber(LBarX, 2),
         FormatNumber(Max(LBarY - 8.0, 18.0), 2),
         EscapeHTML(FormatNumber(AResults[I].NsPerOp, 1))]));
    AddLine(LLines,
      Format('  <text x="%s" y="254" class="chart-label">%s</text>',
        [FormatNumber(LBarX, 2),
         EscapeHTML(AResults[I].Name)]));
  end;

  AddLine(LLines, '</svg>');

  Result := '';
  for I := 0 to High(LLines) do
  begin
    if I > 0 then
      Result := Result + LineEnding;
    Result := Result + LLines[I];
  end;
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
    '  .bench-chart { width: 100%; height: auto; overflow: visible; }' + LineEnding +
    '  .chart-label { font: 11px sans-serif; fill: #27403a; }' + LineEnding +
    '  .chart-value { font: 11px sans-serif; fill: #5b6470; }' + LineEnding +
    '</style>';
end;

function TBenchReportGenerator.GenerateJS: string;
begin
  Result := '';
end;

function TBenchReportGenerator.ToHTML: string;
var
  LHTML: TStringArray;
  LSkippedCount: Integer;
  i: Integer;
begin
  SetLength(LHTML, 0);

  AddLine(LHTML, '<!DOCTYPE html>');
  AddLine(LHTML, '<html>');
  AddLine(LHTML, '<head>');
  AddLine(LHTML, '  <title>nextpas.core.bench Report</title>');
  AddLine(LHTML, '  <meta charset="UTF-8">');
  AddLine(LHTML, '  ' + GenerateCSS);
  AddLine(LHTML, '  ' + GenerateJS);
  AddLine(LHTML, '</head>');
  AddLine(LHTML, '<body>');
  AddLine(LHTML, '  <h1>nextpas.core.bench Report</h1>');
  AddLine(LHTML, '');
  AddLine(LHTML, '  <div class="stats">');
  AddLine(LHTML, '    <h2>Environment</h2>');
  AddLine(LHTML, '    <p><strong>OS:</strong> ' + EscapeHTML(FEnvironment.OS) + '</p>');
  AddLine(LHTML, '    <p><strong>CPU:</strong> ' + EscapeHTML(FEnvironment.CPU) + '</p>');
  AddLine(LHTML, '    <p><strong>Cores:</strong> ' + IntToStr(FEnvironment.Cores) + '</p>');
  AddLine(LHTML, '    <p><strong>FPC:</strong> ' + EscapeHTML(FEnvironment.FPCVersion) + '</p>');
  AddLine(LHTML, '    <p><strong>Time:</strong> ' + EscapeHTML(FEnvironment.Timestamp) + '</p>');
  AddLine(LHTML, '  </div>');
  AddLine(LHTML, '');
  AddLine(LHTML, '  <div class="chart-container">');
  AddLine(LHTML, '    <h2>Performance Chart</h2>');
  AddLine(LHTML, '    ' + GenerateChart(FResults));
  AddLine(LHTML, '  </div>');
  AddLine(LHTML, '');
  AddLine(LHTML, '  <h2>Benchmark Results</h2>');
  AddLine(LHTML, '  <table>');
  AddLine(LHTML, '    <thead>');
  AddLine(LHTML, '      <tr>');
  AddLine(LHTML, '        <th>Name</th>');
  AddLine(LHTML, '        <th>Iterations</th>');
  AddLine(LHTML, '        <th>ns/op</th>');
  AddLine(LHTML, '        <th>ops/s</th>');
  AddLine(LHTML, '        <th>StdDev</th>');
  AddLine(LHTML, '        <th>Median</th>');
  AddLine(LHTML, '        <th>P95</th>');
  AddLine(LHTML, '        <th>P99</th>');
  AddLine(LHTML, '        <th>Outliers</th>');
  AddLine(LHTML, '      </tr>');
  AddLine(LHTML, '    </thead>');
  AddLine(LHTML, '    <tbody>');

  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Skipped then
      Continue;
    AddLine(LHTML, '      <tr>');
    AddLine(LHTML, '        <td class="benchmark-name">' + EscapeHTML(FResults[i].Name) + '</td>');
    AddLine(LHTML, '        <td>' + FormatLargeNumber(FResults[i].Iterations) + '</td>');
    AddLine(LHTML, '        <td>' + FormatNumber(FResults[i].NsPerOp, 1) + '</td>');
    AddLine(LHTML, '        <td>' + FormatLargeNumber(Int64(FResults[i].OpsPerSec)) + '</td>');
    AddLine(LHTML, '        <td>' + FormatNumber(FResults[i].StdDev, 1) + '</td>');
    AddLine(LHTML, '        <td>' + FormatNumber(FResults[i].Median, 1) + '</td>');
    AddLine(LHTML, '        <td>' + FormatNumber(FResults[i].P95, 1) + '</td>');
    AddLine(LHTML, '        <td>' + FormatNumber(FResults[i].P99, 1) + '</td>');
    AddLine(LHTML, '        <td>' + IntToStr(FResults[i].Outliers) + '</td>');
    AddLine(LHTML, '      </tr>');
  end;

  AddLine(LHTML, '    </tbody>');
  AddLine(LHTML, '  </table>');

  // 跳过的基准
  LSkippedCount := 0;
  for i := 0 to FResultCount - 1 do
    if FResults[i].Skipped then
      Inc(LSkippedCount);

  if LSkippedCount > 0 then
  begin
    AddLine(LHTML, '');
    AddLine(LHTML, '  <h2>Skipped Benchmarks</h2>');
    AddLine(LHTML, '  <table>');
    AddLine(LHTML, '    <thead>');
    AddLine(LHTML, '      <tr>');
    AddLine(LHTML, '        <th>Name</th>');
    AddLine(LHTML, '        <th>Reason</th>');
    AddLine(LHTML, '      </tr>');
    AddLine(LHTML, '    </thead>');
    AddLine(LHTML, '    <tbody>');
    for i := 0 to FResultCount - 1 do
    begin
      if FResults[i].Skipped then
      begin
        AddLine(LHTML, '      <tr>');
        AddLine(LHTML, '        <td class="benchmark-name">' + EscapeHTML(FResults[i].Name) + '</td>');
        AddLine(LHTML, '        <td>' + EscapeHTML(FResults[i].SkipReason) + '</td>');
        AddLine(LHTML, '      </tr>');
      end;
    end;
    AddLine(LHTML, '    </tbody>');
    AddLine(LHTML, '  </table>');
  end;

  AddLine(LHTML, '');
  AddLine(LHTML, '  <div class="stats">');
  AddLine(LHTML, '    <h2>Detailed Statistics</h2>');

  // 显示前 5 个未跳过结果的详细统计
  LSkippedCount := 0;
  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Skipped then
    begin
      Inc(LSkippedCount);
      Continue;
    end;
    if i - LSkippedCount >= 5 then
      Break;
    AddLine(LHTML, '    <h3>' + EscapeHTML(FResults[i].Name) + '</h3>');
    AddLine(LHTML, '    <p>Mean: ' + FormatTime(FResults[i].NsPerOp) + '</p>');
    AddLine(LHTML, '    <p>StdDev: ' + FormatTime(FResults[i].StdDev) + '</p>');
    AddLine(LHTML, '    <p>Median: ' + FormatTime(FResults[i].Median) + '</p>');
    AddLine(LHTML, '    <p>P95: ' + FormatTime(FResults[i].P95) + '</p>');
    AddLine(LHTML, '    <p>P99: ' + FormatTime(FResults[i].P99) + '</p>');
    AddLine(LHTML, '    <p>Outliers: ' + IntToStr(FResults[i].Outliers) + '/' + IntToStr(FResults[i].SampleCount) + '</p>');
  end;

  AddLine(LHTML, '  </div>');
  AddLine(LHTML, '</body>');
  AddLine(LHTML, '</html>');

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

  AddLine(LLines, '=== Baseline Comparison ===');
  AddLine(LLines, '');
  AddLine(LLines, Format('  %-40s %10s %10s %10s %10s',
    ['Benchmark', 'Current', 'Baseline', 'Ratio', 'Status']));
  AddLine(LLines, '  ' + StringOfChar('-', 90));

  for i := 0 to High(ABaselines) do
  begin
    AddLine(LLines, Format('  %-40s %10s %10s %10s %10s',
      [ABaselines[i].BaselineName,
       FormatTime(ABaselines[i].CurrentNsPerOp),
       FormatTime(ABaselines[i].BaselineNsPerOp),
       FormatNumber(ABaselines[i].Ratio, 2) + 'x',
       IfThen(ABaselines[i].DifferenceHeuristic,
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
