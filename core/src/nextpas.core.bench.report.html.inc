{**
 * HTML 报告生成方法（从 report.pas 拆分）
 *
 * 包含 GenerateCSS、GenerateHTML*、ToHTML、ToCrossLanguageHTML、
 * GenerateMatrixHTML 等 HTML 生成方法。
 *}

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

procedure TBenchReportGenerator.GenerateHTMLHeader(var ABuf: TLineBuffer);
begin
  BufferAddLine(ABuf, '<!DOCTYPE html>');
  BufferAddLine(ABuf, '<html>');
  BufferAddLine(ABuf, '<head>');
  BufferAddLine(ABuf, '  <title>nextpas.core.bench Report</title>');
  BufferAddLine(ABuf, '  <meta charset="UTF-8">');
  BufferAddLine(ABuf, '  ' + GenerateCSS);
  BufferAddLine(ABuf, '</head>');
  BufferAddLine(ABuf, '<body>');
  BufferAddLine(ABuf, '  <h1>nextpas.core.bench Report</h1>');
  BufferAddLine(ABuf, '');
  BufferAddLine(ABuf, '  <div class="stats">');
  BufferAddLine(ABuf, '    <h2>Environment</h2>');
  BufferAddLine(ABuf, '    <p><strong>OS:</strong> ' + EscapeHTML(FEnvironment.OS) + '</p>');
  BufferAddLine(ABuf, '    <p><strong>CPU:</strong> ' + EscapeHTML(FEnvironment.CPU) + '</p>');
  BufferAddLine(ABuf, '    <p><strong>Cores:</strong> ' + IntToStr(FEnvironment.Cores) + '</p>');
  BufferAddLine(ABuf, '    <p><strong>FPC:</strong> ' + EscapeHTML(FEnvironment.FPCVersion) + '</p>');
  BufferAddLine(ABuf, '    <p><strong>Time:</strong> ' + EscapeHTML(FEnvironment.Timestamp) + '</p>');
  BufferAddLine(ABuf, '  </div>');
  BufferAddLine(ABuf, '');
  BufferAddLine(ABuf, '  <div class="chart-container">');
  BufferAddLine(ABuf, '    <h2>Performance Chart</h2>');
  BufferAddLine(ABuf, '    ' + GenerateChart(FResults));
  BufferAddLine(ABuf, '  </div>');
  BufferAddLine(ABuf, '');
  BufferAddLine(ABuf, '  <h2>Benchmark Results</h2>');
  BufferAddLine(ABuf, '  <table>');
  BufferAddLine(ABuf, '    <thead>');
  BufferAddLine(ABuf, '      <tr>');
  BufferAddLine(ABuf, '        <th>Name</th>');
  BufferAddLine(ABuf, '        <th>Iterations</th>');
  BufferAddLine(ABuf, '        <th>ns/op</th>');
  BufferAddLine(ABuf, '        <th>ops/s</th>');
  BufferAddLine(ABuf, '        <th>StdDev</th>');
  BufferAddLine(ABuf, '        <th>Median</th>');
  BufferAddLine(ABuf, '        <th>P95</th>');
  BufferAddLine(ABuf, '        <th>P99</th>');
  BufferAddLine(ABuf, '        <th>Outliers</th>');
  BufferAddLine(ABuf, '      </tr>');
  BufferAddLine(ABuf, '    </thead>');
  BufferAddLine(ABuf, '    <tbody>');
end;

procedure TBenchReportGenerator.GenerateHTMLResultRows(var ABuf: TLineBuffer);
var
  I: Integer;
begin
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Skipped then
      Continue;
    BufferAddLine(ABuf, '      <tr>');
    BufferAddLine(ABuf, '        <td class="benchmark-name">' + EscapeHTML(FResults[I].Name) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatLargeNumber(FResults[I].Iterations) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatNumber(FResults[I].NsPerOp, 1) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatLargeNumber(Trunc(FResults[I].OpsPerSec)) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatNumber(FResults[I].StdDev, 1) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatNumber(FResults[I].Median, 1) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatNumber(FResults[I].P95, 1) + '</td>');
    BufferAddLine(ABuf, '        <td>' + FormatNumber(FResults[I].P99, 1) + '</td>');
    BufferAddLine(ABuf, '        <td>' + IntToStr(FResults[I].Outliers) + '</td>');
    BufferAddLine(ABuf, '      </tr>');
  end;
  BufferAddLine(ABuf, '    </tbody>');
  BufferAddLine(ABuf, '  </table>');
end;

procedure TBenchReportGenerator.GenerateHTMLSkippedSection(var ABuf: TLineBuffer);
var
  LSkippedCount: Integer;
  I: Integer;
begin
  LSkippedCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Skipped then
      Inc(LSkippedCount);

  if LSkippedCount > 0 then
  begin
    BufferAddLine(ABuf, '');
    BufferAddLine(ABuf, '  <h2>Skipped Benchmarks</h2>');
    BufferAddLine(ABuf, '  <table>');
    BufferAddLine(ABuf, '    <thead>');
    BufferAddLine(ABuf, '      <tr>');
    BufferAddLine(ABuf, '        <th>Name</th>');
    BufferAddLine(ABuf, '        <th>Reason</th>');
    BufferAddLine(ABuf, '      </tr>');
    BufferAddLine(ABuf, '    </thead>');
    BufferAddLine(ABuf, '    <tbody>');
    for I := 0 to FResultCount - 1 do
    begin
      if FResults[I].Skipped then
      begin
        BufferAddLine(ABuf, '      <tr>');
        BufferAddLine(ABuf, '        <td class="benchmark-name">' + EscapeHTML(FResults[I].Name) + '</td>');
        BufferAddLine(ABuf, '        <td>' + EscapeHTML(FResults[I].SkipReason) + '</td>');
        BufferAddLine(ABuf, '      </tr>');
      end;
    end;
    BufferAddLine(ABuf, '    </tbody>');
    BufferAddLine(ABuf, '  </table>');
  end;
end;

procedure TBenchReportGenerator.GenerateHTMLDetailedStats(var ABuf: TLineBuffer);
var
  LSkippedCount: Integer;
  LMaxDetail: Integer;
  I: Integer;
begin
  BufferAddLine(ABuf, '');
  BufferAddLine(ABuf, '  <div class="stats">');
  BufferAddLine(ABuf, '    <h2>Detailed Statistics</h2>');

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
    BufferAddLine(ABuf, '    <h3>' + EscapeHTML(FResults[I].Name) + '</h3>');
    BufferAddLine(ABuf, '    <p>Mean: ' + FormatTime(FResults[I].NsPerOp) + '</p>');
    BufferAddLine(ABuf, '    <p>StdDev: ' + FormatTime(FResults[I].StdDev) + '</p>');
    BufferAddLine(ABuf, '    <p>Median: ' + FormatTime(FResults[I].Median) + '</p>');
    BufferAddLine(ABuf, '    <p>P95: ' + FormatTime(FResults[I].P95) + '</p>');
    BufferAddLine(ABuf, '    <p>P99: ' + FormatTime(FResults[I].P99) + '</p>');
    BufferAddLine(ABuf, '    <p>Outliers: ' + IntToStr(FResults[I].Outliers) + '/' + IntToStr(FResults[I].SampleCount) + '</p>');
  end;

  BufferAddLine(ABuf, '  </div>');
end;

procedure TBenchReportGenerator.GenerateHTMLBoxPlots(var ABuf: TLineBuffer);
var
  I: Integer;
begin
  for I := 0 to FResultCount - 1 do
  begin
    if (not FResults[I].Skipped) and (Length(FResults[I].RawSamples) > 0) then
    begin
      BufferAddLine(ABuf, '  <div class="chart-container">');
      BufferAddLine(ABuf, '    <h3>' + EscapeHTML(FResults[I].Name) + ' - Sample Distribution</h3>');
      BufferAddLine(ABuf, '    ' + GenerateBoxPlot(FResults[I].RawSamples, FResults[I].Name));
      BufferAddLine(ABuf, '  </div>');
    end;
  end;
end;

procedure TBenchReportGenerator.GenerateHTMLFooter(var ABuf: TLineBuffer);
begin
  BufferAddLine(ABuf, '</body>');
  BufferAddLine(ABuf, '</html>');
end;

function TBenchReportGenerator.ToHTML: string;
var
  LHTML: TLineBuffer;
begin
  LHTML := Default(TLineBuffer);
  GenerateHTMLHeader(LHTML);
  GenerateHTMLResultRows(LHTML);
  GenerateHTMLSkippedSection(LHTML);
  GenerateHTMLDetailedStats(LHTML);
  GenerateHTMLBoxPlots(LHTML);
  GenerateHTMLFooter(LHTML);
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

function TBenchReportGenerator.GenerateMatrixHTML(const AMatrix: TMatrixResult): string;
var
  LBuf: TLineBuffer;
  I, J: Integer;
  LRatio: Double;
  LClass: string;
begin
  LBuf := Default(TLineBuffer);

  BufferAddLine(LBuf, '<!DOCTYPE html>');
  BufferAddLine(LBuf, '<html><head><meta charset="utf-8">');
  BufferAddLine(LBuf, '<title>Multi-Baseline Comparison Matrix</title>');
  BufferAddLine(LBuf, '<style>');
  BufferAddLine(LBuf, '  body { font-family: system-ui, -apple-system, sans-serif; margin: 20px; background: #f5f5f5; }');
  BufferAddLine(LBuf, '  .matrix { border-collapse: collapse; width: 100%; background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }');
  BufferAddLine(LBuf, '  .matrix th, .matrix td { padding: 10px 14px; text-align: right; border-bottom: 1px solid #eee; }');
  BufferAddLine(LBuf, '  .matrix th { background: #2d3748; color: white; font-weight: 600; }');
  BufferAddLine(LBuf, '  .matrix td:first-child { text-align: left; font-weight: 500; }');
  BufferAddLine(LBuf, '  .faster { color: #38a169; font-weight: 600; }');
  BufferAddLine(LBuf, '  .slower { color: #e53e3e; font-weight: 600; }');
  BufferAddLine(LBuf, '  .same { color: #718096; }');
  BufferAddLine(LBuf, '  .geomean { background: #edf2f7; font-weight: 700; }');
  BufferAddLine(LBuf, '  h1 { color: #2d3748; }');
  BufferAddLine(LBuf, '  .subtitle { color: #718096; margin-bottom: 20px; }');
  BufferAddLine(LBuf, '</style></head><body>');
  BufferAddLine(LBuf, '<h1>Multi-Baseline Comparison Matrix</h1>');
  BufferAddLine(LBuf, '<p class="subtitle">Ratio = current / baseline. &lt;1.0 = faster, &gt;1.0 = slower.</p>');
  BufferAddLine(LBuf, '<table class="matrix">');
  BufferAddLine(LBuf, '<tr><th>Benchmark</th><th>ns/op</th><th>B/op</th><th>allocs/op</th>');
  for I := 0 to High(AMatrix.BaselineNames) do
    BufferAddLine(LBuf, '<th>' + EscapeHTML(AMatrix.BaselineNames[I]) + '</th>');
  BufferAddLine(LBuf, '</tr>');

  for I := 0 to High(AMatrix.Rows) do
  begin
    BufferAddLine(LBuf, '<tr>');
    BufferAddLine(LBuf, '<td>' + EscapeHTML(AMatrix.Rows[I].Name) + '</td>');
    BufferAddLine(LBuf, '<td>' + FormatTime(AMatrix.Rows[I].CurrentNsPerOp) + '</td>');
    BufferAddLine(LBuf, '<td>' + IntToStr(AMatrix.Rows[I].CurrentBytesPerOp) + '</td>');
    BufferAddLine(LBuf, '<td>' + IntToStr(AMatrix.Rows[I].CurrentAllocsPerOp) + '</td>');
    for J := 0 to High(AMatrix.Rows[I].Cells) do
    begin
      LRatio := AMatrix.Rows[I].Cells[J].Ratio;
      if LRatio < 0.95 then
        LClass := ' class="faster"'
      else if LRatio > 1.05 then
        LClass := ' class="slower"'
      else
        LClass := ' class="same"';
      BufferAddLine(LBuf, '<td' + LClass + '>' +
        FormatFloat('0.00', LRatio) + 'x</td>');
    end;
    BufferAddLine(LBuf, '</tr>');
  end;

  { 几何均值行 }
  if Length(AMatrix.GeometricMeanRatios) > 0 then
  begin
    BufferAddLine(LBuf, '<tr class="geomean"><td>Geometric Mean</td><td></td><td></td><td></td>');
    for J := 0 to High(AMatrix.GeometricMeanRatios) do
    begin
      LRatio := AMatrix.GeometricMeanRatios[J];
      if LRatio < 0.95 then
        LClass := ' class="faster"'
      else if LRatio > 1.05 then
        LClass := ' class="slower"'
      else
        LClass := ' class="same"';
      BufferAddLine(LBuf, '<td' + LClass + '>' +
        FormatFloat('0.00', LRatio) + 'x</td>');
    end;
    BufferAddLine(LBuf, '</tr>');
  end;

  BufferAddLine(LBuf, '</table>');
  BufferAddLine(LBuf, '</body></html>');

  Result := BufferToString(LBuf);
end;
