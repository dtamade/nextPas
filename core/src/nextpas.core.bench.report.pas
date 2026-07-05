{**
 * @desc 基准测试报告生成器
 *
 * 提供 Console、JSON、TSV、HTML、SVG、Matrix 等
 * 多种格式的基准测试报告生成功能。
 *}
unit nextpas.core.bench.report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.text.builder; { M3: for TStringBuilder in TLineBuffer }

type
  TCrossLangEntry = record
    Name: string;
    Language: string;
    NsPerOp: Double;
  end;

  TCrossLangEntryArray = array of TCrossLangEntry;

  {** 行缓冲区 — 使用 TStringBuilder 实现，更优雅更高效 }
  TLineBuffer = record
    Builder: TStringBuilder;
  end;

  {** 报告生成器 }
  TBenchReportGenerator = class(TInterfacedObject, IBenchReportGenerator)
  private
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FEnvironment: TBenchEnvironment;
    FCachedCSS: string; { PF-19: cached CSS string }
    FCSSCached: Boolean;
    FMaxDetailCount: Integer;

    {** 生成 HTML 图表 }
    function GenerateChart(const AResults: array of TBenchResult): string;

    {** 生成 HTML 样式 (cached) }
    function GenerateCSS: string;

    {** 生成 HTML 报告头部（head + body 开头 + environment div + chart div + 表头） }
    procedure GenerateHTMLHeader(var ABuf: TLineBuffer);

    {** 生成 HTML 结果表格行 }
    procedure GenerateHTMLResultRows(var ABuf: TLineBuffer);

    {** 生成 HTML 跳过的基准测试段落 }
    procedure GenerateHTMLSkippedSection(var ABuf: TLineBuffer);

    {** 生成 HTML 详细统计段落 }
    procedure GenerateHTMLDetailedStats(var ABuf: TLineBuffer);

    {** 生成 HTML 箱线图 div }
    procedure GenerateHTMLBoxPlots(var ABuf: TLineBuffer);

    {** 生成 HTML 页脚（closing body + html 标签） }
    procedure GenerateHTMLFooter(var ABuf: TLineBuffer);

  public
    constructor Create;
    destructor Destroy; override;

    {** 设置统计详情最大显示数量 }
    procedure SetMaxDetailCount(ACount: Integer);

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
    function PrintToConsole: string;

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
      const ABaselines: array of TBenchComparison): string;

    {** 生成 benchstat 兼容格式 (Go benchstat 工具可直接解析) }
    function ToBenchstat: string;

    {** 生成多基线对比矩阵报告 (P2-1, console) }
    function GenerateMatrixReport(const AMatrix: TMatrixResult): string;

    {** 生成多基线对比矩阵 HTML (P2-1) }
    function GenerateMatrixHTML(const AMatrix: TMatrixResult): string;

    {** 生成多基线对比矩阵 JSON (CI 消费) }
    function GenerateMatrixJSON(const AMatrix: TMatrixResult): string;

    {** P2-3: 生成分布直方图 SVG (原始样本分布) }
    function GenerateDistributionChart(const ASamples: TDoubleArray;
      const AName: string): string;

    {** P2-3: 生成基线对比图 SVG (当前 vs N 基线) }
    function GenerateComparisonChart(
      const AComparisons: array of TBenchComparison): string;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.math.scalar,
  nextpas.core.json.writer;

{ 辅助函数：行缓冲区操作 — 基于 TStringBuilder }

procedure BufferAddLine(var ABuf: TLineBuffer; const ALine: string);
begin
  if ABuf.Builder.Len > 0 then
    ABuf.Builder.AppendStr(LineEnding);
  ABuf.Builder.AppendStr(ALine);
end;

function BufferToString(const ABuf: TLineBuffer): string;
begin
  Result := ABuf.Builder.ToString;
end;

{ 跨语言对比条目按名称排序（插入排序，数据量通常 <50 条，O(n²) 可接受） }
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
begin
  SetLength(Result, Length(AStr));
  for I := 1 to Length(AStr) do
    if AStr[I] in [#9, #10, #13] then
      Result[I] := ' '
    else
      Result[I] := AStr[I];
end;

{ CR-23: Percentile with linear interpolation on already-sorted array }
{ 已移至 base.pas 作为公共函数 PercentileSorted }

{ TBenchReportGenerator }

constructor TBenchReportGenerator.Create;
begin
  inherited Create;
  FResultCount := 0;
  SetLength(FResults, 0);
  FCSSCached := False;
  FCachedCSS := '';
  FMaxDetailCount := 5;
end;

procedure TBenchReportGenerator.SetMaxDetailCount(ACount: Integer);
begin
  FMaxDetailCount := ACount;
end;

destructor TBenchReportGenerator.Destroy;
begin
  SetLength(FResults, 0);
  inherited Destroy;
end;

procedure TBenchReportGenerator.SetResults(const AResults: array of TBenchResult);
var
  I: Integer;
begin
  FResultCount := Length(AResults);
  SetLength(FResults, FResultCount);
  for I := 0 to FResultCount - 1 do
    FResults[I] := AResults[I];
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

{ 格式化吞吐量 (bytes/s → 人类可读) }
function FormatThroughput(ABytesPerSec: Double): string;
begin
  if ABytesPerSec < 1024.0 then
    Result := nextpas.core.text.conv.FloatToStrF(ABytesPerSec, 1) + ' B/s'
  else if ABytesPerSec < 1024.0 * 1024.0 then
    Result := nextpas.core.text.conv.FloatToStrF(ABytesPerSec / 1024.0, 1) + ' KB/s'
  else if ABytesPerSec < 1024.0 * 1024.0 * 1024.0 then
    Result := nextpas.core.text.conv.FloatToStrF(ABytesPerSec / (1024.0 * 1024.0), 1) + ' MB/s'
  else
    Result := nextpas.core.text.conv.FloatToStrF(ABytesPerSec / (1024.0 * 1024.0 * 1024.0), 2) + ' GB/s';
end;

{ 格式化变异系数 CV = StdDev / Mean * 100%
  <5% 优秀，5-15% 一般，>15% 警告 }
function FormatCV(AMean, AStdDev: Double): string;
var
  LPct: Double;
begin
  if (AMean <= 0) or (AStdDev <= 0) then
    Exit('-');
  LPct := (AStdDev / AMean) * 100.0;
  if LPct < 5.0 then
    Result := FormatFloat('0.0', LPct) + '% OK'
  else if LPct < 15.0 then
    Result := FormatFloat('0.0', LPct) + '%'
  else
    Result := FormatFloat('0.0', LPct) + '% WARN';
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

function TBenchReportGenerator.PrintToConsole: string;
var
  LLines: TLineBuffer;
  LSkippedCount: Integer;
  LMaxDetail: Integer;
  I: Integer;
begin
  LLines.Builder.Init(4096);

  // title
  BufferAddLine(LLines, '=== nextpas.core.bench v' + BENCH_VERSION + ' ===');
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

  // ST-18: columns match HTML (Name, Iterations, ns/op, ops/s, StdDev, Median, P95, P99)
  BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s %10s %10s %10s',
    ['Name', 'Iterations', 'ns/op', 'ops/s', 'StdDev', 'Median', 'P95', 'P99']));
  // ST-17: separator width matches content columns (40+8×10+7 spaces = 127)
  BufferAddLine(LLines, '  ' + TextOfChar('-', 127));

  // results (non-skipped only) + count skipped in one pass (ST-16)
  LSkippedCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if not FResults[I].Skipped then
    begin
      // ST-18: columns match HTML header
      BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s %10s %10s %10s',
        [FResults[I].Name,
         FormatLargeNumber(FResults[I].Iterations),
         FormatNumber(FResults[I].NsPerOp, 1),
         FormatLargeNumber(Trunc(FResults[I].OpsPerSec)),
         FormatNumber(FResults[I].StdDev, 1),
         FormatNumber(FResults[I].Median, 1),
         FormatNumber(FResults[I].P95, 1),
         FormatNumber(FResults[I].P99, 1)]));
    end
    else
      Inc(LSkippedCount);
  end;

  if LSkippedCount > 0 then
  begin
    BufferAddLine(LLines, '');
    BufferAddLine(LLines, 'Skipped Benchmarks:');
    BufferAddLine(LLines, '');
    for I := 0 to FResultCount - 1 do
    begin
      if FResults[I].Skipped then
      begin
        BufferAddLine(LLines, '  ' + FResults[I].Name);
        BufferAddLine(LLines, '    Reason: ' + FResults[I].SkipReason);
      end;
    end;
  end;

  BufferAddLine(LLines, '');
  BufferAddLine(LLines, '=== Statistics ===');

  // detailed statistics (non-skipped, up to LMaxDetail)
  LSkippedCount := 0;
  LMaxDetail := Min(FResultCount, FMaxDetailCount);
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Skipped then
    begin
      Inc(LSkippedCount);
      Continue;
    end;
    if I - LSkippedCount >= LMaxDetail then
      Break;
    BufferAddLine(LLines, '');
    BufferAddLine(LLines, FResults[I].Name + ':');
    BufferAddLine(LLines, TextFormat('  Mean: %s  StdDev: %s  Median: %s  CV: %s',
      [FormatTime(FResults[I].NsPerOp),
       FormatTime(FResults[I].StdDev),
       FormatTime(FResults[I].Median),
       FormatCV(FResults[I].NsPerOp, FResults[I].StdDev)]));
    BufferAddLine(LLines, TextFormat('  P95: %s  P99: %s  Outliers: %d/%d',
      [FormatTime(FResults[I].P95),
       FormatTime(FResults[I].P99),
       FResults[I].Outliers,
       FResults[I].SampleCount]));
    if (FResults[I].BytesPerOp > 0) and (FResults[I].NsPerOp > 0) then
      BufferAddLine(LLines, TextFormat('  Throughput: %s  (%d B/op)',
        [FormatThroughput(FResults[I].BytesPerOp * 1e9 / FResults[I].NsPerOp),
         FResults[I].BytesPerOp]));
  end;

  Result := BufferToString(LLines);
  LLines.Builder.Done;
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
  I: Integer;
begin
  LLines.Builder.Init(4096);

  // header
  BufferAddLine(LLines, 'name' + #9 + 'status' + #9 + 'skip_reason' + #9 + 'iterations' + #9 + 'ns_per_op' + #9 + 'ops_per_sec' + #9 + 'stddev' + #9 + 'median' + #9 + 'p95' + #9 + 'p99' + #9 + 'outliers' + #9 + 'samples');

  // data
  for I := 0 to FResultCount - 1 do
  begin
    BufferAddLine(LLines,
      SanitizeTSVField(FResults[I].Name) + #9 +
      BoolToStr(FResults[I].Skipped, 'skipped', 'ok') + #9 +
      SanitizeTSVField(FResults[I].SkipReason) + #9 +
      IntToStr(FResults[I].Iterations) + #9 +
      FormatNumber(FResults[I].NsPerOp, 2) + #9 +
      FormatNumber(FResults[I].OpsPerSec, 0) + #9 +
      FormatNumber(FResults[I].StdDev, 2) + #9 +
      FormatNumber(FResults[I].Median, 2) + #9 +
      FormatNumber(FResults[I].P95, 2) + #9 +
      FormatNumber(FResults[I].P99, 2) + #9 +
      IntToStr(FResults[I].Outliers) + #9 +
      IntToStr(FResults[I].SampleCount));
  end;

  Result := BufferToString(LLines);
  LLines.Builder.Done;
end;

{ SVG 图表生成方法 — 从 report.svg.inc 包含 }
{$I nextpas.core.bench.report.svg.inc}

{ HTML 报告生成方法 — 从 report.html.inc 包含 }
{$I nextpas.core.bench.report.html.inc}

function TBenchReportGenerator.GenerateComparisonReport(
  const ABaselines: array of TBenchComparison): string;
var
  LLines: TLineBuffer;
  LStatus: string;
  I: Integer;
begin
  LLines.Builder.Init(4096);

  BufferAddLine(LLines, '=== Baseline Comparison ===');
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s',
    ['Benchmark', 'Current', 'Baseline', 'Ratio', 'Status']));
  BufferAddLine(LLines, '  ' + TextOfChar('-', 90));

  for I := 0 to High(ABaselines) do
  begin
    if ABaselines[I].IsSignificant then
    begin
      if ABaselines[I].Ratio > 1.0 then
        LStatus := 'SLOWER'
      else if ABaselines[I].Ratio < 1.0 then
        LStatus := 'FASTER'
      else
        LStatus := '≈ same';
    end
    else
      LStatus := '≈ same';
    BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s %10s',
      [ABaselines[I].BaselineName,
       FormatTime(ABaselines[I].CurrentNsPerOp),
       FormatTime(ABaselines[I].BaselineNsPerOp),
       FormatNumber(ABaselines[I].Ratio, 2) + 'x',
       LStatus]));
  end;

  Result := BufferToString(LLines);
  LLines.Builder.Done;
end;

function TBenchReportGenerator.ToBenchstat: string;
var
  LLines: TLineBuffer;
  LPct: Double;
  LBytes, LAllocs: string;
  I: Integer;
begin
  LLines.Builder.Init(4096);

  { benchstat 兼容的 tab-separated 表头 }
  BufferAddLine(LLines, TextFormat('%-40s %12s %8s %12s %10s',
    ['name', 'ns/op', '+- %', 'B/op', 'allocs/op']));

  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Skipped then
      Continue;

    if FResults[I].NsPerOp > 0 then
      LPct := (FResults[I].StdDev / FResults[I].NsPerOp) * 100.0
    else
      LPct := 0;

    if FResults[I].BytesPerOp > 0 then
      LBytes := IntToStr(FResults[I].BytesPerOp)
    else
      LBytes := '-';
    if FResults[I].AllocsPerOp > 0 then
      LAllocs := IntToStr(FResults[I].AllocsPerOp)
    else
      LAllocs := '-';

    BufferAddLine(LLines, TextFormat('%-40s %12s %7s%% %12s %10s',
      [FResults[I].Name,
       FormatNumber(FResults[I].NsPerOp, 1),
       FormatNumber(LPct, 0),
       LBytes,
       LAllocs]));
  end;

  Result := BufferToString(LLines);
  LLines.Builder.Done;
end;

{ P2-1: 多基线对比矩阵 — Console 报告 }

function TBenchReportGenerator.GenerateMatrixReport(const AMatrix: TMatrixResult): string;
var
  LLines: TLineBuffer;
  LNCols: Integer;
  LLine: string;
  LRatio: Double;
  I, J: Integer;
begin
  LLines.Builder.Init(4096);
  LNCols := Length(AMatrix.BaselineNames);

  BufferAddLine(LLines, '=== Multi-Baseline Comparison Matrix ===');
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, 'Ratio = current / baseline. <1.0 faster, >1.0 slower.');
  BufferAddLine(LLines, '');

  { 表头 }
  LLine := TextFormat('  %-40s %10s %8s %8s', ['Benchmark', 'ns/op', 'B/op', 'allocs/op']);
  for I := 0 to LNCols - 1 do
    LLine := LLine + TextFormat(' %10s', [AMatrix.BaselineNames[I]]);
  BufferAddLine(LLines, LLine);
  BufferAddLine(LLines, '  ' + TextOfChar('-', 58 + LNCols * 11));

  { 每行数据 }
  for I := 0 to High(AMatrix.Rows) do
  begin
    LLine := TextFormat('  %-40s %10s %8s %8s',
      [AMatrix.Rows[I].Name,
       FormatTime(AMatrix.Rows[I].CurrentNsPerOp),
       IntToStr(AMatrix.Rows[I].CurrentBytesPerOp),
       IntToStr(AMatrix.Rows[I].CurrentAllocsPerOp)]);
    for J := 0 to High(AMatrix.Rows[I].Cells) do
    begin
      LRatio := AMatrix.Rows[I].Cells[J].Ratio;
      if LRatio < 0.95 then
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x +'])
      else if LRatio > 1.05 then
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x -'])
      else
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x']);
    end;
    BufferAddLine(LLines, LLine);
  end;

  { 几何均值行 }
  if Length(AMatrix.GeometricMeanRatios) > 0 then
  begin
    BufferAddLine(LLines, '  ' + TextOfChar('-', 58 + LNCols * 11));
    LLine := TextFormat('  %-40s %10s %8s %8s', ['Geometric Mean', '', '', '']);
    for J := 0 to High(AMatrix.GeometricMeanRatios) do
    begin
      LRatio := AMatrix.GeometricMeanRatios[J];
      if IsDoubleNaN(LRatio) then
        LLine := LLine + TextFormat(' %9s', ['N/A'])
      else if LRatio < 0.95 then
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x +'])
      else if LRatio > 1.05 then
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x -'])
      else
        LLine := LLine + TextFormat(' %9s', [FormatFloat('0.00', LRatio) + 'x']);
    end;
    BufferAddLine(LLines, LLine);
  end;

  { P2-2: 内存+性能联合报告 }
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, '=== Memory Impact ===');
  BufferAddLine(LLines, '');
  BufferAddLine(LLines, TextFormat('  %-40s %10s %10s %10s',
    ['Benchmark', 'ns/op', 'B/op', 'allocs/op']));
  BufferAddLine(LLines, '  ' + TextOfChar('-', 73));
  for I := 0 to High(AMatrix.Rows) do
  begin
    LLine := TextFormat('  %-40s %10s %10s %10s',
      [AMatrix.Rows[I].Name,
       FormatTime(AMatrix.Rows[I].CurrentNsPerOp),
       IntToStr(AMatrix.Rows[I].CurrentBytesPerOp),
       IntToStr(AMatrix.Rows[I].CurrentAllocsPerOp)]);
    BufferAddLine(LLines, LLine);
  end;

  Result := BufferToString(LLines);
  LLines.Builder.Done;
end;

{ 矩阵 JSON 导出 — CI 可直接消费 }

function TBenchReportGenerator.GenerateMatrixJSON(const AMatrix: TMatrixResult): string;
var
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
  I, J: Integer;
begin
  LBuilder.Init(512);
  try
    LWriter.Init(LBuilder);
    LWriter.BeginObject;
    LWriter.Key('baselines');
    LWriter.BeginArray;
    for I := 0 to High(AMatrix.BaselineNames) do
      LWriter.Str(AMatrix.BaselineNames[I]);
    LWriter.EndArray;
    LWriter.Key('rows');
    LWriter.BeginArray;
    for I := 0 to High(AMatrix.Rows) do
    begin
      LWriter.BeginObject;
      LWriter.Key('name');
      LWriter.Str(AMatrix.Rows[I].Name);
      LWriter.Key('nsPerOp');
      LWriter.Float(AMatrix.Rows[I].CurrentNsPerOp);
      LWriter.Key('bytesPerOp');
      LWriter.Int(AMatrix.Rows[I].CurrentBytesPerOp);
      LWriter.Key('allocsPerOp');
      LWriter.Int(AMatrix.Rows[I].CurrentAllocsPerOp);
      LWriter.Key('ratios');
      LWriter.BeginArray;
      for J := 0 to High(AMatrix.Rows[I].Cells) do
        LWriter.Float(AMatrix.Rows[I].Cells[J].Ratio);
      LWriter.EndArray;
      LWriter.EndObject;
    end;
    LWriter.EndArray;
    LWriter.Key('geometricMeanRatios');
    LWriter.BeginArray;
    for I := 0 to High(AMatrix.GeometricMeanRatios) do
    begin
      if IsDoubleNaN(AMatrix.GeometricMeanRatios[I]) then
        LWriter.Null
      else
        LWriter.Float(AMatrix.GeometricMeanRatios[I]);
    end;
    LWriter.EndArray;
    LWriter.EndObject;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;


end.