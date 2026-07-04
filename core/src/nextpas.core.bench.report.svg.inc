{**
 * SVG 图表生成方法（从 report.pas 拆分）
 *
 * 包含 GenerateChart、GenerateBoxPlot、GenerateDistributionChart、
 * GenerateComparisonChart 四个 SVG 生成方法。
 *}

function TBenchReportGenerator.GenerateChart(const AResults: array of TBenchResult): string;
var
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
  // count non-skipped
  LCount := 0;
  for I := 0 to High(AResults) do
    if not AResults[I].Skipped then
      Inc(LCount);

  if LCount = 0 then
    Exit('<svg class="bench-chart" viewBox="0 0 820 280" role="img" aria-label="No benchmark data"></svg>');

  LMaxNsPerOp := 0.0;
  for I := 0 to High(AResults) do
    if (not AResults[I].Skipped) and (AResults[I].NsPerOp > LMaxNsPerOp) then
      LMaxNsPerOp := AResults[I].NsPerOp;
  if LMaxNsPerOp <= 0 then
    LMaxNsPerOp := 1.0;

  // compute longest name for dynamic viewBox width (CR-21)
  LMaxNameLen := 0;
  for I := 0 to High(AResults) do
    if not AResults[I].Skipped then
      if Length(AResults[I].Name) > LMaxNameLen then
        LMaxNameLen := Length(AResults[I].Name);

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
  for I := 0 to High(AResults) do
  begin
    if AResults[I].Skipped then
      Continue;

    LHeightRatio := AResults[I].NsPerOp / LMaxNsPerOp;
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
         EscapeHTML(FormatNumber(AResults[I].NsPerOp, 1))]));
    BufferAddLine(LLines,
      TextFormat('  <text x="%s" y="254" class="chart-label">%s</text>',
        [FormatNumber(LBarX, 2),
         EscapeHTML(AResults[I].Name)]));

    Inc(LIndex);
  end;

  BufferAddLine(LLines, '</svg>');

  Result := BufferToString(LLines);
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
  { CR-23: Use linear interpolation for quartiles (same as Percentile function)
    instead of integer division which degenerates for small samples. }
  if LCount >= 2 then
  begin
    LQ1 := PercentileSorted(LSorted, 25.0);
    LMedian := PercentileSorted(LSorted, 50.0);
    LQ3 := PercentileSorted(LSorted, 75.0);
  end
  else
  begin
    { LCount = 1: all quartiles equal the single value }
    LQ1 := LSorted[0];
    LMedian := LSorted[0];
    LQ3 := LSorted[0];
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
  begin
    // ST-24: Constant data — render a visible center marker instead of invisible 0-width box
    LLines := Default(TLineBuffer);
    BufferAddLine(LLines,
      '<svg viewBox="0 0 300 60" role="img" aria-label="Boxplot ' +
      EscapeHTML(AName) + ' (constant)">');
    BufferAddLine(LLines, '  <rect x="0" y="0" width="300" height="60" fill="#fbfcfd"/>');
    BufferAddLine(LLines,
      '  <line x1="100" y1="20" x2="100" y2="40" stroke="#ff6600" stroke-width="3"/>');
    BufferAddLine(LLines,
      '  <text x="120" y="35" class="chart-label">' +
      EscapeHTML(FormatNumber(LMin, 2)) + ' (constant)</text>');
    BufferAddLine(LLines, '</svg>');
    Result := BufferToString(LLines);
    Exit;
  end;
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

function TBenchReportGenerator.GenerateDistributionChart(
  const ASamples: TDoubleArray; const AName: string): string;
var
  LBuf: TLineBuffer;
  LSorted: TDoubleArray;
  LMin, LMax, LBinWidth: Double;
  LBins: array of Integer;
  LBinCount, LMaxBin, I, LIdx: Integer;
  LBarW, LBarH, LBarX, LBarY: Double;
  LChartW, LChartH: Double;
begin
  LBuf := Default(TLineBuffer);
  if Length(ASamples) < 2 then
    Exit('');

  { 排序样本找范围 }
  LSorted := Copy(ASamples);
  SortDoubleArray(LSorted);
  LMin := LSorted[0];
  LMax := LSorted[High(LSorted)];
  if LMax <= LMin then
    Exit('');

  { 20 个 bin }
  LBinCount := 20;
  LBinWidth := (LMax - LMin) / LBinCount;
  if LBinWidth <= 0 then
    Exit('');
  SetLength(LBins, LBinCount);
  for I := 0 to LBinCount - 1 do
    LBins[I] := 0;
  for I := 0 to High(LSorted) do
  begin
    LIdx := Trunc((LSorted[I] - LMin) / LBinWidth);
    if LIdx >= LBinCount then LIdx := LBinCount - 1;
    if LIdx < 0 then LIdx := 0;
    Inc(LBins[LIdx]);
  end;

  { 找最大 bin 计数用于缩放 }
  LMaxBin := 0;
  for I := 0 to LBinCount - 1 do
    if LBins[I] > LMaxBin then LMaxBin := LBins[I];
  if LMaxBin = 0 then Exit('');

  LChartW := 500.0;
  LChartH := 200.0;

  BufferAddLine(LBuf, TextFormat(
    '<svg viewBox="0 0 %s %s" role="img" aria-label="Distribution: %s">',
    [FormatFloat('0', LChartW), FormatFloat('0', LChartH), EscapeHTML(AName)]));
  BufferAddLine(LBuf, TextFormat(
    '<rect x="0" y="0" width="%s" height="%s" rx="12" fill="#fbfcfd"/>',
    [FormatFloat('0', LChartW), FormatFloat('0', LChartH)]));
  BufferAddLine(LBuf, TextFormat(
    '<text x="10" y="16" font-size="12" fill="#333">%s distribution (%d samples)</text>',
    [EscapeHTML(AName), Length(ASamples)]));

  { 绘制直方图 bar }
  LBarW := (LChartW - 40.0) / LBinCount;
  for I := 0 to LBinCount - 1 do
  begin
    if LBins[I] = 0 then Continue;
    LBarH := (LBins[I] / LMaxBin) * (LChartH - 50.0);
    LBarX := 20.0 + I * LBarW;
    LBarY := LChartH - 20.0 - LBarH;
    BufferAddLine(LBuf, TextFormat(
      '<rect x="%s" y="%s" width="%s" height="%s" fill="#4a7a6f" rx="2"/>',
      [FormatFloat('0.1', LBarX + 1), FormatFloat('0.1', LBarY),
       FormatFloat('0.1', Max(LBarW - 2, 2)), FormatFloat('0.1', LBarH)]));
  end;

  { X 轴标签 }
  BufferAddLine(LBuf, TextFormat(
    '<text x="20" y="%s" font-size="9" fill="#999">%s</text>',
    [FormatFloat('0', LChartH - 5), FormatFloat('0.0', LMin)]));
  BufferAddLine(LBuf, TextFormat(
    '<text x="%s" y="%s" font-size="9" fill="#999" text-anchor="end">%s</text>',
    [FormatFloat('0', LChartW - 5), FormatFloat('0', LChartH - 5),
     FormatFloat('0.0', LMax)]));

  BufferAddLine(LBuf, '</svg>');
  Result := BufferToString(LBuf);
end;

{ P2-3: 基线对比图 SVG }

function TBenchReportGenerator.GenerateComparisonChart(
  const AComparisons: array of TBenchComparison): string;
var
  LBuf: TLineBuffer;
  LMaxVal: Double;
  LChartW, LChartH, LGroupW, LBarW: Double;
  LBarH, LBarX, LBarY: Double;
  I: Integer;
begin
  LBuf := Default(TLineBuffer);
  if Length(AComparisons) = 0 then Exit('');

  { 找最大值 }
  LMaxVal := 0;
  for I := 0 to High(AComparisons) do
  begin
    if AComparisons[I].CurrentNsPerOp > LMaxVal then
      LMaxVal := AComparisons[I].CurrentNsPerOp;
    if AComparisons[I].BaselineNsPerOp > LMaxVal then
      LMaxVal := AComparisons[I].BaselineNsPerOp;
  end;
  if LMaxVal <= 0 then Exit('');

  LChartW := Max(600.0, 100.0 + Length(AComparisons) * 120.0);
  LChartH := 250.0;
  LGroupW := (LChartW - 60.0) / Length(AComparisons);

  BufferAddLine(LBuf, TextFormat(
    '<svg viewBox="0 0 %s %s" role="img" aria-label="Baseline comparison chart">',
    [FormatFloat('0', LChartW), FormatFloat('0', LChartH)]));
  BufferAddLine(LBuf, TextFormat(
    '<rect x="0" y="0" width="%s" height="%s" rx="12" fill="#fbfcfd"/>',
    [FormatFloat('0', LChartW), FormatFloat('0', LChartH)]));
  BufferAddLine(LBuf, '<text x="10" y="16" font-size="12" fill="#333">Current vs Baseline</text>');

  { 图例 }
  BufferAddLine(LBuf, '<rect x="10" y="24" width="10" height="10" fill="#4a7a6f" rx="2"/>');
  BufferAddLine(LBuf, '<text x="24" y="33" font-size="10" fill="#555">Current</text>');
  BufferAddLine(LBuf, '<rect x="90" y="24" width="10" height="10" fill="#e53e3e" rx="2"/>');
  BufferAddLine(LBuf, '<text x="104" y="33" font-size="10" fill="#555">Baseline</text>');

  LBarW := LGroupW * 0.35;

  for I := 0 to High(AComparisons) do
  begin
    LBarX := 30.0 + I * LGroupW;

    { Current bar }
    LBarH := (AComparisons[I].CurrentNsPerOp / LMaxVal) * (LChartH - 70.0);
    LBarY := LChartH - 30.0 - LBarH;
    BufferAddLine(LBuf, TextFormat(
      '<rect x="%s" y="%s" width="%s" height="%s" fill="#4a7a6f" rx="3"/>',
      [FormatFloat('0.1', LBarX), FormatFloat('0.1', LBarY),
       FormatFloat('0.1', LBarW), FormatFloat('0.1', LBarH)]));
    BufferAddLine(LBuf, TextFormat(
      '<text x="%s" y="%s" font-size="9" fill="#555" text-anchor="middle">%s</text>',
      [FormatFloat('0.1', LBarX + LBarW / 2), FormatFloat('0.1', LBarY - 4),
       FormatTime(AComparisons[I].CurrentNsPerOp)]));

    { Baseline bar }
    LBarH := (AComparisons[I].BaselineNsPerOp / LMaxVal) * (LChartH - 70.0);
    LBarY := LChartH - 30.0 - LBarH;
    BufferAddLine(LBuf, TextFormat(
      '<rect x="%s" y="%s" width="%s" height="%s" fill="#e53e3e" rx="3"/>',
      [FormatFloat('0.1', LBarX + LBarW + 4), FormatFloat('0.1', LBarY),
       FormatFloat('0.1', LBarW), FormatFloat('0.1', LBarH)]));
    BufferAddLine(LBuf, TextFormat(
      '<text x="%s" y="%s" font-size="9" fill="#555" text-anchor="middle">%s</text>',
      [FormatFloat('0.1', LBarX + LBarW * 1.5 + 4), FormatFloat('0.1', LBarY - 4),
       FormatTime(AComparisons[I].BaselineNsPerOp)]));

    { Ratio label }
    BufferAddLine(LBuf, TextFormat(
      '<text x="%s" y="%s" font-size="10" fill="#333" text-anchor="middle">%s (%sx)</text>',
      [FormatFloat('0.1', LBarX + LGroupW / 2), FormatFloat('0.1', LChartH - 10),
       EscapeHTML(AComparisons[I].BaselineName),
       FormatFloat('0.00', AComparisons[I].Ratio)]));
  end;

  BufferAddLine(LBuf, '</svg>');
  Result := BufferToString(LBuf);
end;
