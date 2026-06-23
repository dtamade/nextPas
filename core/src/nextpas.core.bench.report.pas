unit nextpas.core.bench.report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf;

type
  TCrossLangEntry = record
    Name: string;
    Language: string;
    NsPerOp: Double;
  end;

  TCrossLangEntryArray = array of TCrossLangEntry;

  {** 报告生成器 }
  TBenchReportGenerator = class
  private
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FEnvironment: TBenchEnvironment;
    FCachedCSS: string; { PF-19: cached CSS string }
    FCSSCached: Boolean;

    {** 生成 HTML 图表 }
    function GenerateChart(const AResults: array of TBenchResult): string;

    {** 生成 HTML 样式 (cached) }
    function GenerateCSS: string;

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

    {** 生成跨语言对比 HTML 报告 }
    function ToCrossLanguageHTML(const AEntries: TCrossLangEntryArray): string;

    {** 生成 SVG 箱线图 }
    function GenerateBoxPlot(const ASamples: TDoubleArray; const AName: string): string;

    {** 生成基线对比报告 }
    function GenerateComparisonReport(
      const ABaselines: array of TBenchComparison): string; overload;
    function GenerateComparisonReport(
      const AResults: array of TBenchResult;
      const ABaselines: array of TBenchComparison): string; overload;
  end;

implementation

uses
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.math.scalar,
  nextpas.core.json.writer,
  nextpas.core.text.builder;

{ 辅助函数：行缓冲区（capacity 翻倍策略）}
type
  TLineBuffer = record
    Lines: TStringArray;
    Count: Integer;
    Capacity: Integer;
  end;

procedure BufferAddLine(var ABuf: TLineBuffer; const ALine: string);
begin
  if ABuf.Count >= ABuf.Capacity then
  begin
    if ABuf.Capacity = 0 then ABuf.Capacity := 16
    else ABuf.Capacity := ABuf.Capacity * 2;
    SetLength(ABuf.Lines, ABuf.Capacity);
  end;
  ABuf.Lines[ABuf.Count] := ALine;
  Inc(ABuf.Count);
end;

function BufferToString(const ABuf: TLineBuffer): string;
var
  I: Integer;
  LBuilder: TStringBuilder;
  LTotalLen: Integer;
begin
  if ABuf.Count = 0 then Exit('');

  // PF-20: estimate actual content size instead of count * 80
  LTotalLen := 0;
  for I := 0 to ABuf.Count - 1 do
    Inc(LTotalLen, Length(ABuf.Lines[I]));
  Inc(LTotalLen, ABuf.Count * Length(LineEnding));

  LBuilder.Init(LTotalLen + 256);
  try
    for I := 0 to ABuf.Count - 1 do
    begin
      if I > 0 then LBuilder.AppendStr(LineEnding);
      LBuilder.AppendStr(ABuf.Lines[I]);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure SortCrossLangEntriesByName(var AEntries: TCrossLangEntryArray);
var
  I: Integer;
  J: Integer;
  LEntry: TCrossLangEntry;
begin
  for I := 1 to High(AEntries) do
  begin
    LEntry := AEntries[I];
    J := I - 1;
    while (J >= 0) and (AEntries[J].Name > LEntry.Name) do
    begin
      AEntries[J + 1] := AEntries[J];
      Dec(J);
    end;
    AEntries[J + 1] := LEntry;
  end;
end;


{ TSV 辅助：将 Tab/换行替换为空格，防止破坏 TSV 结构 }
function SanitizeTSVField(const AStr: string): string;
var
  I: Integer;
  LBuf: array of Char;
begin
  SetLength(LBuf, Length(AStr));
  for I := 1 to Length(AStr) do
  begin
    if AStr[I] in [#9, #10, #13] then
      LBuf[I - 1] := ' '
    else
      LBuf[I - 1] := AStr[I];
  end;
  SetString(Result, PChar(LBuf), Length(AStr));
end;

{ TBenchReportGenerator }

constructor TBenchReportGenerator.Create;
begin
  inherited Create;
  FResultCount := 0;
  SetLength(FResults, 0);
  FCSSCached := False;
  FCachedCSS := '';
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
  Result := nextpas.core.text.conv.FloatToStrF(AValue, APrecision);
end;

function TBenchReportGenerator.FormatLargeNumber(AValue: Int64): string;
var
  LStr: string;
  LLen, I, LFirstGroup: Integer;
  LBuilder: TStringBuilder;
begin
  if AValue = 0 then Exit('0');
  LStr := IntToStr(Abs(AValue));
  LLen := Length(LStr);
  LBuilder.Init(LLen + LLen div 3 + 2);
  try
    if AValue < 0 then LBuilder.AppendChar('-');
    LFirstGroup := LLen mod 3;
    if LFirstGroup = 0 then LFirstGroup := 3;
    // 第一组
    for I := 1 to LFirstGroup do
      LBuilder.AppendChar(LStr[I]);
    // 后续每 3 位一组
    I := LFirstGroup + 1;
    while I <= LLen do
    begin
      LBuilder.AppendChar(',');
      LBuilder.AppendChar(LStr[I]);
      LBuilder.AppendChar(LStr[I+1]);
      LBuilder.AppendChar(LStr[I+2]);
      Inc(I, 3);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
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
    Result := FormatNumber(ANs / 1000.0, 2) + ' µs' { ST-19: Unicode micro sign }
  else if ANs < 1000000000 then
    Result := FormatNumber(ANs / 1000000.0, 2) + ' ms'
  else
    Result := FormatNumber(ANs / 1000000000.0, 3) + ' s';
end;

function TBenchReportGenerator.EscapeJSON(const AStr: string): string;
var
  I: Integer;
  LBuilder: TStringBuilder;
begin
  LBuilder.Init(Length(AStr) + 16);
  try
    for I := 1 to Length(AStr) do
    begin
      case AStr[I] of
        '\': LBuilder.AppendStr('\\');
        '"': LBuilder.AppendStr('\"');
        #0: LBuilder.AppendStr('\u0000');
        #8: LBuilder.AppendStr('\b');
        #10: LBuilder.AppendStr('\n');
        #12: LBuilder.AppendStr('\f');
        #13: LBuilder.AppendStr('\r');
        #9: LBuilder.AppendStr('\t');
      else
        LBuilder.AppendChar(AStr[I]);
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TBenchReportGenerator.EscapeHTML(const AStr: string): string;
var
  I: Integer;
  LBuilder: TStringBuilder;
begin
  LBuilder.Init(Length(AStr) + 16);
  try
    for I := 1 to Length(AStr) do
    begin
      case AStr[I] of
        '&': LBuilder.AppendStr('&amp;');
        '<': LBuilder.AppendStr('&lt;');
        '>': LBuilder.AppendStr('&gt;');
        '"': LBuilder.AppendStr('&quot;');
        '''': LBuilder.AppendStr('&apos;');
      else
        LBuilder.AppendChar(AStr[I]);
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TBenchReportGenerator.ToConsole: string;
var
  LLines: TLineBuffer;
  LSkippedCount: Integer;
  LMaxDetail: Integer;
  i: Integer;
begin
  LLines := Default(TLineBuffer);

  // title
  BufferAddLine(LLines, '=== nextpas.core.bench v1.0 ===');
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, 'Environment:');
  BufferAddLine(LLines, '  OS: ' + FEnvironment.OS);
  BufferAddLine(LLines, '  CPU: ' + FEnvironment.CPU);
  BufferAddLine(LLines, '  Cores: ' + IntToStr(FEnvironment.Cores));
  BufferAddLine(LLines, '  FPC: ' + FEnvironment.FPCVersion);
  BufferAddLine(LLines, '  Time: ' + FEnvironment.Timestamp);
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, 'Benchmark Results:');
  BufferAddLine(LLines, '');

  // header
  BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s %10s',
    ['Name', 'Iterations', 'ns/op', 'ops/s', 'StdDev', 'P99']));
  // ST-17: separator width matches content columns (40+10+10+10+10+10+5 spaces = 95)
  BufferAddLine(LLines, '  ' + TextOfChar('-', 95));

  // results (non-skipped only) + count skipped in one pass (ST-16)
  LSkippedCount := 0;
  for i := 0 to FResultCount - 1 do
  begin
    if not FResults[i].Skipped then
    begin
      BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s %10s',
        [FResults[i].Name,
         FormatLargeNumber(FResults[i].Iterations),
         FormatNumber(FResults[i].NsPerOp, 1),
         FormatLargeNumber(Min(Int64(FResults[i].OpsPerSec), High(Int64))),
         FormatNumber(FResults[i].StdDev, 1),
         FormatNumber(FResults[i].P99, 1)]));
    end
    else
      Inc(LSkippedCount);
  end;

  if LSkippedCount > 0 then
  begin
    BufferAddLine(LLines, '');
    BufferAddLine(LLines, 'Skipped Benchmarks:');
    BufferAddLine(LLines, '');
    for i := 0 to FResultCount - 1 do
    begin
      if FResults[i].Skipped then
      begin
        BufferAddLine(LLines, '  ' + FResults[i].Name);
        BufferAddLine(LLines, '    Reason: ' + FResults[i].SkipReason);
      end;
    end;
  end;

  BufferAddLine(LLines, '');
  BufferAddLine(LLines, '=== Statistics ===');

  // detailed statistics (non-skipped, up to LMaxDetail)
  LSkippedCount := 0;
  LMaxDetail := Min(FResultCount, 5);
  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Skipped then
    begin
      Inc(LSkippedCount);
      Continue;
    end;
    if i - LSkippedCount >= LMaxDetail then
      Break;
    BufferAddLine(LLines, '');
    BufferAddLine(LLines, FResults[i].Name + ':');
    BufferAddLine(LLines, TextFormat('  Mean: %s  StdDev: %s  Median: %s',
      [FormatTime(FResults[i].NsPerOp),
       FormatTime(FResults[i].StdDev),
       FormatTime(FResults[i].Median)]));
    BufferAddLine(LLines, TextFormat('  P95: %s  P99: %s  Outliers: %d/%d',
      [FormatTime(FResults[i].P95),
       FormatTime(FResults[i].P99),
       FResults[i].Outliers,
       FResults[i].SampleCount]));
  end;

  Result := BufferToString(LLines);
end;

function TBenchReportGenerator.ToJSON: string;
var
  I: Integer;
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  LBuilder.Init(256 + FResultCount * 256);
  try
    LWriter.Init(LBuilder);
    LWriter.BeginObject;
    LWriter.Key('version');
    LWriter.Str('1.0');
    LWriter.Key('timestamp');
    LWriter.Str(FEnvironment.Timestamp);
    LWriter.Key('environment');
    LWriter.BeginObject;
    LWriter.Key('os');
    LWriter.Str(FEnvironment.OS);
    LWriter.Key('cpu');
    LWriter.Str(FEnvironment.CPU);
    LWriter.Key('cores');
    LWriter.Int(FEnvironment.Cores);
    LWriter.Key('fpc_version');
    LWriter.Str(FEnvironment.FPCVersion);
    LWriter.EndObject;
    LWriter.Key('benchmarks');
    LWriter.BeginArray;
    for I := 0 to FResultCount - 1 do
    begin
      LWriter.BeginObject;
      LWriter.Key('name');
      LWriter.Str(FResults[I].Name);
      if FResults[I].Skipped then
      begin
        // ST-20: skipped entries omit numerical fields
        LWriter.Key('status');
        LWriter.Str('skipped');
        LWriter.Key('skip_reason');
        LWriter.Str(FResults[I].SkipReason);
      end
      else
      begin
        LWriter.Key('status');
        LWriter.Str('ok');
        LWriter.Key('iterations');
        LWriter.Int(FResults[I].Iterations);
        LWriter.Key('ns_per_op');
        LWriter.Float(FResults[I].NsPerOp);
        LWriter.Key('ops_per_sec');
        LWriter.Float(FResults[I].OpsPerSec);
        LWriter.Key('bytes_per_op');
        LWriter.Int(FResults[I].BytesPerOp);
        LWriter.Key('allocs_per_op');
        LWriter.Int(FResults[I].AllocsPerOp);
        LWriter.Key('statistics');
        LWriter.BeginObject;
        LWriter.Key('stddev');
        LWriter.Float(FResults[I].StdDev);
        LWriter.Key('median');
        LWriter.Float(FResults[I].Median);
        LWriter.Key('p95');
        LWriter.Float(FResults[I].P95);
        LWriter.Key('p99');
        LWriter.Float(FResults[I].P99);
        LWriter.Key('outliers');
        LWriter.Int(FResults[I].Outliers);
        LWriter.Key('sample_count');
        LWriter.Int(FResults[I].SampleCount);
        LWriter.EndObject;
      end;
      LWriter.EndObject;
    end;
    LWriter.EndArray;
    LWriter.EndObject;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TBenchReportGenerator.ToTSV: string;
var
  LLines: TLineBuffer;
  i: Integer;
begin
  LLines := Default(TLineBuffer);

  // header
  BufferAddLine(LLines, 'name' + #9 + 'status' + #9 + 'skip_reason' + #9 + 'iterations' + #9 + 'ns_per_op' + #9 + 'ops_per_sec' + #9 + 'stddev' + #9 + 'median' + #9 + 'p95' + #9 + 'p99' + #9 + 'outliers' + #9 + 'samples');

  // data
  for i := 0 to FResultCount - 1 do
  begin
    BufferAddLine(LLines,
      SanitizeTSVField(FResults[i].Name) + #9 +
      BoolToStr(FResults[i].Skipped, 'skipped', 'ok') + #9 +
      SanitizeTSVField(FResults[i].SkipReason) + #9 +
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

  Result := BufferToString(LLines);
end;

function TBenchReportGenerator.GenerateChart(const AResults: array of TBenchResult): string;
var
  LCopy: array of TBenchResult;
  LLines: TLineBuffer;
  LMaxNsPerOp: Double;
  LBarWidth: Double;
  LBarHeight: Double;
  LBarX: Double;
  LBarY: Double;
  LHeightRatio: Double;
  LMaxNameLen: Integer;
  LChartWidth: Double;
  LChartRight: Double;
  LCount: Integer;
  LIndex: Integer;
  I: Integer;
begin
  // snapshot the open-array to a local copy (CR-20)
  SetLength(LCopy, Length(AResults));
  for I := 0 to High(AResults) do
    LCopy[I] := AResults[I];

  // count non-skipped
  LCount := 0;
  for I := 0 to High(LCopy) do
    if not LCopy[I].Skipped then
      Inc(LCount);

  if LCount = 0 then
    Exit('<svg class="bench-chart" viewBox="0 0 820 280" role="img" aria-label="No benchmark data"></svg>');

  LMaxNsPerOp := 0.0;
  for I := 0 to High(LCopy) do
    if (not LCopy[I].Skipped) and (LCopy[I].NsPerOp > LMaxNsPerOp) then
      LMaxNsPerOp := LCopy[I].NsPerOp;
  if LMaxNsPerOp <= 0 then
    LMaxNsPerOp := 1.0;

  // compute longest name for dynamic viewBox width (CR-21)
  LMaxNameLen := 0;
  for I := 0 to High(LCopy) do
    if not LCopy[I].Skipped then
      if Length(LCopy[I].Name) > LMaxNameLen then
        LMaxNameLen := Length(LCopy[I].Name);

  LChartWidth := Max(820.0, 140.0 + LMaxNameLen * 8.0);
  LChartRight := LChartWidth - 36.0;

  LLines := Default(TLineBuffer);
  BufferAddLine(LLines,
    TextFormat('  <svg class="bench-chart" viewBox="%s" role="img" aria-label="Benchmark ns per op chart">',
      [TextFormat('0 0 %s 280', [FormatNumber(LChartWidth, 0)])]));
  BufferAddLine(LLines,
    TextFormat('  <rect x="0" y="0" width="%s" height="280" rx="18" fill="#fbfcfd"/>',
      [FormatNumber(LChartWidth, 0)]));
  BufferAddLine(LLines,
    TextFormat('  <line x1="64" y1="236" x2="%s" y2="236" stroke="#cfd7de" stroke-width="1"/>',
      [FormatNumber(LChartRight, 0)]));
  BufferAddLine(LLines, '  <line x1="64" y1="24" x2="64" y2="236" stroke="#cfd7de" stroke-width="1"/>');

  LBarWidth := (LChartRight - 64.0) / Max(LCount, 1);
  LIndex := 0;
  for I := 0 to High(LCopy) do
  begin
    if LCopy[I].Skipped then
      Continue;

    LHeightRatio := LCopy[I].NsPerOp / LMaxNsPerOp;
    LBarHeight := 184.0 * LHeightRatio;
    LBarX := 76.0 + LIndex * LBarWidth;
    LBarY := 236.0 - LBarHeight;

    BufferAddLine(LLines,
      TextFormat('  <rect x="%s" y="%s" width="%s" height="%s" rx="8" fill="#4a7a6f"/>',
        [FormatNumber(LBarX, 2),
         FormatNumber(LBarY, 2),
         FormatNumber(Max(LBarWidth - 18.0, 14.0), 2),
         FormatNumber(LBarHeight, 2)]));
    BufferAddLine(LLines,
      TextFormat('  <text x="%s" y="%s" class="chart-value">%s ns</text>',
        [FormatNumber(LBarX, 2),
         FormatNumber(Max(LBarY - 8.0, 18.0), 2),
         EscapeHTML(FormatNumber(LCopy[I].NsPerOp, 1))]));
    BufferAddLine(LLines,
      TextFormat('  <text x="%s" y="254" class="chart-label">%s</text>',
        [FormatNumber(LBarX, 2),
         EscapeHTML(LCopy[I].Name)]));

    Inc(LIndex);
  end;

  BufferAddLine(LLines, '</svg>');

  Result := BufferToString(LLines);
end;

function TBenchReportGenerator.GenerateCSS: string;
begin
  // PF-19: cache CSS since it's static (doesn't depend on results)
  if FCSSCached then
    Exit(FCachedCSS);
  FCachedCSS :=
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
  FCSSCached := True;
  Result := FCachedCSS;
end;

function TBenchReportGenerator.ToHTML: string;
var
  LHTML: TLineBuffer;
  LSkippedCount: Integer;
  LMaxDetail: Integer;
  i: Integer;
begin
  LHTML := Default(TLineBuffer);

  BufferAddLine(LHTML, '<!DOCTYPE html>');
  BufferAddLine(LHTML, '<html>');
  BufferAddLine(LHTML, '<head>');
  BufferAddLine(LHTML, '  <title>nextpas.core.bench Report</title>');
  BufferAddLine(LHTML, '  <meta charset="UTF-8">');
  BufferAddLine(LHTML, '  ' + GenerateCSS);
  BufferAddLine(LHTML, '</head>');
  BufferAddLine(LHTML, '<body>');
  BufferAddLine(LHTML, '  <h1>nextpas.core.bench Report</h1>');
  BufferAddLine(LHTML, '');
  BufferAddLine(LHTML, '  <div class="stats">');
  BufferAddLine(LHTML, '    <h2>Environment</h2>');
  BufferAddLine(LHTML, '    <p><strong>OS:</strong> ' + EscapeHTML(FEnvironment.OS) + '</p>');
  BufferAddLine(LHTML, '    <p><strong>CPU:</strong> ' + EscapeHTML(FEnvironment.CPU) + '</p>');
  BufferAddLine(LHTML, '    <p><strong>Cores:</strong> ' + IntToStr(FEnvironment.Cores) + '</p>');
  BufferAddLine(LHTML, '    <p><strong>FPC:</strong> ' + EscapeHTML(FEnvironment.FPCVersion) + '</p>');
  BufferAddLine(LHTML, '    <p><strong>Time:</strong> ' + EscapeHTML(FEnvironment.Timestamp) + '</p>');
  BufferAddLine(LHTML, '  </div>');
  BufferAddLine(LHTML, '');
  BufferAddLine(LHTML, '  <div class="chart-container">');
  BufferAddLine(LHTML, '    <h2>Performance Chart</h2>');
  BufferAddLine(LHTML, '    ' + GenerateChart(FResults));
  BufferAddLine(LHTML, '  </div>');
  BufferAddLine(LHTML, '');
  BufferAddLine(LHTML, '  <h2>Benchmark Results</h2>');
  BufferAddLine(LHTML, '  <table>');
  BufferAddLine(LHTML, '    <thead>');
  BufferAddLine(LHTML, '      <tr>');
  BufferAddLine(LHTML, '        <th>Name</th>');
  BufferAddLine(LHTML, '        <th>Iterations</th>');
  BufferAddLine(LHTML, '        <th>ns/op</th>');
  BufferAddLine(LHTML, '        <th>ops/s</th>');
  BufferAddLine(LHTML, '        <th>StdDev</th>');
  BufferAddLine(LHTML, '        <th>Median</th>');
  BufferAddLine(LHTML, '        <th>P95</th>');
  BufferAddLine(LHTML, '        <th>P99</th>');
  BufferAddLine(LHTML, '        <th>Outliers</th>');
  BufferAddLine(LHTML, '      </tr>');
  BufferAddLine(LHTML, '    </thead>');
  BufferAddLine(LHTML, '    <tbody>');

  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Skipped then
      Continue;
    BufferAddLine(LHTML, '      <tr>');
    BufferAddLine(LHTML, '        <td class="benchmark-name">' + EscapeHTML(FResults[i].Name) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatLargeNumber(FResults[i].Iterations) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatNumber(FResults[i].NsPerOp, 1) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatLargeNumber(Min(Int64(FResults[i].OpsPerSec), High(Int64))) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatNumber(FResults[i].StdDev, 1) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatNumber(FResults[i].Median, 1) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatNumber(FResults[i].P95, 1) + '</td>');
    BufferAddLine(LHTML, '        <td>' + FormatNumber(FResults[i].P99, 1) + '</td>');
    BufferAddLine(LHTML, '        <td>' + IntToStr(FResults[i].Outliers) + '</td>');
    BufferAddLine(LHTML, '      </tr>');
  end;

  BufferAddLine(LHTML, '    </tbody>');
  BufferAddLine(LHTML, '  </table>');

  // skipped benchmarks
  LSkippedCount := 0;
  for i := 0 to FResultCount - 1 do
    if FResults[i].Skipped then
      Inc(LSkippedCount);

  if LSkippedCount > 0 then
  begin
    BufferAddLine(LHTML, '');
    BufferAddLine(LHTML, '  <h2>Skipped Benchmarks</h2>');
    BufferAddLine(LHTML, '  <table>');
    BufferAddLine(LHTML, '    <thead>');
    BufferAddLine(LHTML, '      <tr>');
    BufferAddLine(LHTML, '        <th>Name</th>');
    BufferAddLine(LHTML, '        <th>Reason</th>');
    BufferAddLine(LHTML, '      </tr>');
    BufferAddLine(LHTML, '    </thead>');
    BufferAddLine(LHTML, '    <tbody>');
    for i := 0 to FResultCount - 1 do
    begin
      if FResults[i].Skipped then
      begin
        BufferAddLine(LHTML, '      <tr>');
        BufferAddLine(LHTML, '        <td class="benchmark-name">' + EscapeHTML(FResults[i].Name) + '</td>');
        BufferAddLine(LHTML, '        <td>' + EscapeHTML(FResults[i].SkipReason) + '</td>');
        BufferAddLine(LHTML, '      </tr>');
      end;
    end;
    BufferAddLine(LHTML, '    </tbody>');
    BufferAddLine(LHTML, '  </table>');
  end;

  BufferAddLine(LHTML, '');
  BufferAddLine(LHTML, '  <div class="stats">');
  BufferAddLine(LHTML, '    <h2>Detailed Statistics</h2>');

  // detailed stats (non-skipped, up to LMaxDetail)
  LSkippedCount := 0;
  LMaxDetail := Min(FResultCount, 5);
  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Skipped then
    begin
      Inc(LSkippedCount);
      Continue;
    end;
    if i - LSkippedCount >= LMaxDetail then
      Break;
    BufferAddLine(LHTML, '    <h3>' + EscapeHTML(FResults[i].Name) + '</h3>');
    BufferAddLine(LHTML, '    <p>Mean: ' + FormatTime(FResults[i].NsPerOp) + '</p>');
    BufferAddLine(LHTML, '    <p>StdDev: ' + FormatTime(FResults[i].StdDev) + '</p>');
    BufferAddLine(LHTML, '    <p>Median: ' + FormatTime(FResults[i].Median) + '</p>');
    BufferAddLine(LHTML, '    <p>P95: ' + FormatTime(FResults[i].P95) + '</p>');
    BufferAddLine(LHTML, '    <p>P99: ' + FormatTime(FResults[i].P99) + '</p>');
    BufferAddLine(LHTML, '    <p>Outliers: ' + IntToStr(FResults[i].Outliers) + '/' + IntToStr(FResults[i].SampleCount) + '</p>');
  end;

  BufferAddLine(LHTML, '  </div>');
  for i := 0 to FResultCount - 1 do
  begin
    if (not FResults[i].Skipped) and (Length(FResults[i].RawSamples) > 0) then
    begin
      BufferAddLine(LHTML, '  <div class="chart-container">');
      BufferAddLine(LHTML, '    <h3>' + EscapeHTML(FResults[i].Name) + ' - Sample Distribution</h3>');
      BufferAddLine(LHTML, '    ' + GenerateBoxPlot(FResults[i].RawSamples, FResults[i].Name));
      BufferAddLine(LHTML, '  </div>');
    end;
  end;
  BufferAddLine(LHTML, '</body>');
  BufferAddLine(LHTML, '</html>');

  Result := BufferToString(LHTML);
end;

function TBenchReportGenerator.ToCrossLanguageHTML(
  const AEntries: TCrossLangEntryArray): string;
var
  LEntries: TCrossLangEntryArray;
  LHTML: TLineBuffer;
  LCurrentName: string;
  LGroupMaxNsPerOp: Double;
  LBarWidth: Double;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LEntries := Copy(AEntries);
  SortCrossLangEntriesByName(LEntries);

  LHTML := Default(TLineBuffer);
  BufferAddLine(LHTML, '<!DOCTYPE html>');
  BufferAddLine(LHTML, '<html>');
  BufferAddLine(LHTML, '<head>');
  BufferAddLine(LHTML, '  <meta charset="UTF-8">');
  BufferAddLine(LHTML, '  <title>nextpas.core.bench Cross-Language Report</title>');
  BufferAddLine(LHTML, '  <style>');
  BufferAddLine(LHTML, '    body { font-family: sans-serif; margin: 24px; color: #23313a; }');
  BufferAddLine(LHTML, '    h1, h2 { color: #1a4b5a; }');
  BufferAddLine(LHTML, '    table { width: 100%; border-collapse: collapse; margin: 16px 0 28px; }');
  BufferAddLine(LHTML, '    th, td { border-bottom: 1px solid #d9e1e5; padding: 10px 8px; text-align: left; }');
  BufferAddLine(LHTML, '    .value { white-space: nowrap; }');
  BufferAddLine(LHTML, '    .bar-track { background: #edf3f5; border-radius: 999px; height: 12px; overflow: hidden; }');
  BufferAddLine(LHTML, '    .bar-fill { background: linear-gradient(90deg, #4a7a6f, #6ca38c); height: 12px; }');
  BufferAddLine(LHTML, '  </style>');
  BufferAddLine(LHTML, '</head>');
  BufferAddLine(LHTML, '<body>');
  BufferAddLine(LHTML, '  <h1>Cross-Language Benchmark Comparison</h1>');

  I := 0;
  while I <= High(LEntries) do
  begin
    LCurrentName := LEntries[I].Name;
    LGroupMaxNsPerOp := 0.0;
    J := I;
    while (J <= High(LEntries)) and (LEntries[J].Name = LCurrentName) do
    begin
      if LEntries[J].NsPerOp > LGroupMaxNsPerOp then
        LGroupMaxNsPerOp := LEntries[J].NsPerOp;
      Inc(J);
    end;
    if LGroupMaxNsPerOp <= 0.0 then
      LGroupMaxNsPerOp := 1.0;

    BufferAddLine(LHTML, '  <h2>' + EscapeHTML(LCurrentName) + '</h2>');
    BufferAddLine(LHTML, '  <table>');
    BufferAddLine(LHTML, '    <thead>');
    BufferAddLine(LHTML, '      <tr><th>Language</th><th>ns/op</th><th>Relative</th></tr>');
    BufferAddLine(LHTML, '    </thead>');
    BufferAddLine(LHTML, '    <tbody>');
    for K := I to J - 1 do
    begin
      LBarWidth := (LEntries[K].NsPerOp / LGroupMaxNsPerOp) * 100.0;
      BufferAddLine(LHTML, '      <tr>');
      BufferAddLine(LHTML, '        <td>' + EscapeHTML(LEntries[K].Language) + '</td>');
      BufferAddLine(LHTML, '        <td class="value">' + FormatNumber(LEntries[K].NsPerOp, 1) + '</td>');
      BufferAddLine(LHTML,
        '        <td><div class="bar-track"><div class="bar-fill" style="width: ' +
        FormatNumber(LBarWidth, 1) + '%"></div></div></td>');
      BufferAddLine(LHTML, '      </tr>');
    end;
    BufferAddLine(LHTML, '    </tbody>');
    BufferAddLine(LHTML, '  </table>');

    I := J;
  end;

  BufferAddLine(LHTML, '</body>');
  BufferAddLine(LHTML, '</html>');

  Result := BufferToString(LHTML);
end;

function TBenchReportGenerator.GenerateBoxPlot(
  const ASamples: TDoubleArray; const AName: string): string;
var
  LSorted: TDoubleArray;
  LLines: TLineBuffer;
  LCount: Integer;
  LIndex: Integer;
  LMin: Double;
  LMax: Double;
  LQ1: Double;
  LMedian: Double;
  LQ3: Double;
  LIQR: Double;
  LOutlierLow: Double;
  LOutlierHigh: Double;
  LWhiskerLow: Double;
  LWhiskerHigh: Double;
  LScale: Double;
  LBaseX: Double;
  LScaledQ1: Double;
  LScaledMedian: Double;
  LScaledQ3: Double;
  LScaledWhiskerLow: Double;
  LScaledWhiskerHigh: Double;
  LScaledOutlier: Double;
begin
  LCount := Length(ASamples);
  if LCount = 0 then
    Exit('');

  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);

  LMin := LSorted[0];
  LMax := LSorted[LCount - 1];
  if LCount >= 4 then
  begin
    LQ1 := LSorted[LCount div 4];
    LMedian := LSorted[LCount div 2];
    LQ3 := LSorted[(3 * LCount) div 4];
  end
  else
  begin
    case LCount of
      1:
        begin
          LQ1 := LSorted[0];
          LMedian := LSorted[0];
          LQ3 := LSorted[0];
        end;
      2:
        begin
          LQ1 := LSorted[0];
          LMedian := (LSorted[0] + LSorted[1]) / 2.0;
          LQ3 := LSorted[1];
        end;
    else
      begin
        LQ1 := LSorted[0];
        LMedian := LSorted[1];
        LQ3 := LSorted[2];
      end;
    end;
  end;

  LIQR := LQ3 - LQ1;
  LOutlierLow := LQ1 - 1.5 * LIQR;
  LOutlierHigh := LQ3 + 1.5 * LIQR;
  LWhiskerLow := LMin;
  LWhiskerHigh := LMax;

  for LIndex := 0 to LCount - 1 do
  begin
    if LSorted[LIndex] >= LOutlierLow then
    begin
      LWhiskerLow := LSorted[LIndex];
      Break;
    end;
  end;

  for LIndex := LCount - 1 downto 0 do
  begin
    if LSorted[LIndex] <= LOutlierHigh then
    begin
      LWhiskerHigh := LSorted[LIndex];
      Break;
    end;
  end;

  if Abs(LMax - LMin) < 1e-10 then
    LScale := 1.0
  else
    LScale := 200.0 / (LMax - LMin);

  LBaseX := 50.0;
  LScaledWhiskerLow := LBaseX + (LWhiskerLow - LMin) * LScale;
  LScaledWhiskerHigh := LBaseX + (LWhiskerHigh - LMin) * LScale;
  LScaledQ1 := LBaseX + (LQ1 - LMin) * LScale;
  LScaledMedian := LBaseX + (LMedian - LMin) * LScale;
  LScaledQ3 := LBaseX + (LQ3 - LMin) * LScale;

  LLines := Default(TLineBuffer);
  BufferAddLine(LLines,
    '<svg viewBox="0 0 300 60" role="img" aria-label="Boxplot ' +
    EscapeHTML(AName) + '">');
  BufferAddLine(LLines, '  <rect x="0" y="0" width="300" height="60" fill="#fbfcfd"/>');
  BufferAddLine(LLines,
    '  <line x1="' + FormatNumber(LScaledWhiskerLow, 1) + '" y1="30" x2="' +
    FormatNumber(LScaledWhiskerHigh, 1) + '" y2="30" stroke="#666" stroke-width="1"/>');
  BufferAddLine(LLines,
    '  <line x1="' + FormatNumber(LScaledWhiskerLow, 1) + '" y1="24" x2="' +
    FormatNumber(LScaledWhiskerLow, 1) + '" y2="36" stroke="#666" stroke-width="1"/>');
  BufferAddLine(LLines,
    '  <line x1="' + FormatNumber(LScaledWhiskerHigh, 1) + '" y1="24" x2="' +
    FormatNumber(LScaledWhiskerHigh, 1) + '" y2="36" stroke="#666" stroke-width="1"/>');
  BufferAddLine(LLines,
    '  <rect x="' + FormatNumber(LScaledQ1, 1) + '" y="18" width="' +
    FormatNumber(LScaledQ3 - LScaledQ1, 1) +
    '" height="24" fill="#4a7a6f" stroke="#333" stroke-width="1"/>');
  BufferAddLine(LLines,
    '  <line x1="' + FormatNumber(LScaledMedian, 1) + '" y1="18" x2="' +
    FormatNumber(LScaledMedian, 1) + '" y2="42" stroke="#ff6600" stroke-width="2"/>');

  for LIndex := 0 to LCount - 1 do
  begin
    if (LSorted[LIndex] < LWhiskerLow) or (LSorted[LIndex] > LWhiskerHigh) then
    begin
      LScaledOutlier := LBaseX + (LSorted[LIndex] - LMin) * LScale;
      BufferAddLine(LLines,
        '  <circle cx="' + FormatNumber(LScaledOutlier, 1) +
        '" cy="30" r="2" fill="#cc0000"/>');
    end;
  end;

  BufferAddLine(LLines, '</svg>');

  Result := BufferToString(LLines);
end;

function TBenchReportGenerator.GenerateComparisonReport(
  const ABaselines: array of TBenchComparison): string;
var
  LLines: TLineBuffer;
  LStatus: string;
  i: Integer;
begin
  LLines := Default(TLineBuffer);

  BufferAddLine(LLines, '=== Baseline Comparison ===');
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s',
    ['Benchmark', 'Current', 'Baseline', 'Ratio', 'Status']));
  BufferAddLine(LLines, '  ' + TextOfChar('-', 90));

  for i := 0 to High(ABaselines) do
  begin
    if ABaselines[i].DifferenceHeuristic then
    begin
      if ABaselines[i].Ratio > 1.0 then
        LStatus := '✗ slower'
      else if ABaselines[i].Ratio < 1.0 then
        LStatus := '✓ faster'
      else
        LStatus := '≈ same';
    end
    else
      LStatus := '≈ same';
    BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s',
      [ABaselines[i].BaselineName,
       FormatTime(ABaselines[i].CurrentNsPerOp),
       FormatTime(ABaselines[i].BaselineNsPerOp),
       FormatNumber(ABaselines[i].Ratio, 2) + 'x',
       LStatus]));
  end;

  Result := BufferToString(LLines);
end;

function TBenchReportGenerator.GenerateComparisonReport(
  const AResults: array of TBenchResult;
  const ABaselines: array of TBenchComparison): string;
begin
  Result := GenerateComparisonReport(ABaselines);
end;

end.
