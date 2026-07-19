program test_tui_widget_batch;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.layout,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.widget.sparkline,
  nextpas.core.tui.widget.barchart,
  nextpas.core.tui.widget.canvas,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input,
  nextpas.core.test;
var T: TTestSuite;

{ === Gauge === }
procedure TestGaugeEmpty;
var LG: IWidget; LBuf: TBuffer;
begin
  LG := TGauge.New.WithRatio(0.0) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LG.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'empty gauge renders');
  finally LBuf.Free; end;
end;

procedure TestGaugeFull;
var LG: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  LG := TGauge.New.WithRatio(1.0) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try LG.Render(TRect.Make(0, 0, 5, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos(#$E2#$96#$88, LRow) > 0, 'full gauge has block chars');
  finally LBuf.Free; end;
end;

procedure TestGaugeLabel;
var LG: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  LG := TGauge.New.WithRatio(0.5).WithLabel('50%') as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LG.Render(TRect.Make(0, 0, 20, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('50%', LRow) > 0, 'label visible');
  finally LBuf.Free; end;
end;

{ === Sparkline === }
procedure TestSparklineRender;
var LS: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  LS := TSparkline.New([1.0, 5.0, 2.0, 8.0, 3.0]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try LS.Render(TRect.Make(0, 0, 5, 2), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Length(LRow) > 0, 'sparkline has content');
  finally LBuf.Free; end;
end;

{ === BarChart === }
procedure TestBarchartWithData;
var LB: IWidget; LBuf: TBuffer; LLines: TBufferLines;
begin
  LB := TBarChart.New([
    TBarData.Make('A', 5.0),
    TBarData.Make('B', 10.0)
  ]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 8));
  try LB.Render(TRect.Make(0, 0, 20, 8), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('A', LLines[High(LLines)]) > 0, 'label A at bottom');
  finally LBuf.Free; end;
end;

{ === Canvas === }
procedure TestCanvasDrawDot;
var LC: ICanvas; LBuf: TBuffer; LRow: AnsiString;
begin
  LC := TCanvas.New(5, 4);
  LC.SetDot(2, 3);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 4));
  try (LC as IWidget).Render(TRect.Make(0, 0, 5, 4), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Length(LRow) > 0, 'canvas with dot has content');
  finally LBuf.Free; end;
end;

{ === Table === }
procedure TestTableWithData;
var LT: ITable; LBuf: TBuffer; LState: TTableState; LLines: TBufferLines;
begin
  LT := TTable.New([
    TTableColumn.Make('Name', LengthConstraint(10)),
    TTableColumn.Make('Age', LengthConstraint(5))
  ]).WithRows([
    TTableRow.Make(['Alice', '30']),
    TTableRow.Make(['Bob', '25'])
  ]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  LState := TTableState.Empty;
  try LT.RenderStateful(TRect.Make(0, 0, 20, 5), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('Alice', LLines[1]) > 0, 'Alice in table');
    Check(Pos('Bob', LLines[2]) > 0, 'Bob in table');
  finally LBuf.Free; end;
end;

procedure TestTableSelection;
var LT: ITable; LBuf: TBuffer; LState: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', LengthConstraint(5))])
    .WithRows([TTableRow.Make(['a']), TTableRow.Make(['b'])]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  LState := TTableState.Empty;
  LState.Selected := 1;
  LState.HasSelection := True;
  try LT.RenderStateful(TRect.Make(0, 0, 10, 4), LBuf, LState);
    Check(True, 'table with selection renders');
  finally LBuf.Free; end;
end;

procedure TestTableEmptyRowsClearState;
var LT: ITable; LBuf: TBuffer; LState: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', LengthConstraint(5))])
    .WithRows([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  LState := TTableState.Empty;
  LState.Offset := 3;
  LState.Selected := 2;
  LState.HasSelection := True;
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 4), LBuf, LState);
    CheckEqual(Int64(0), Int64(LState.Offset),
      'empty table rows reset stale offset');
    Check(not LState.HasSelection,
      'empty table rows clear stale selection');
  finally LBuf.Free; end;
end;

procedure TestTableColumnAlignment;
var LColumn: TTableColumn; LAlign: TContentAlign;
begin
  LAlign := caRight;
  LColumn := TTableColumn.Make('X', LengthConstraint(5)).WithAlign(LAlign);
  CheckEqual(Ord(caRight), Ord(LColumn.Align), 'table alignment constants remain public');
end;

{ === Input === }
procedure TestInputRender;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New;
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('hello', LRow) > 0, 'input shows text');
  finally LBuf.Free; end;
end;

procedure TestInputCursor;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New;
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LI.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    Check(True, 'input with cursor renders');
  finally LBuf.Free; end;
end;

{ === Gauge builders === }
procedure TestGaugePercent;
var LG: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  LG := TGauge.New.WithPercent(75).WithLabel('75%') as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LG.Render(TRect.Make(0, 0, 20, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('75%', LRow) > 0, 'percent label visible');
  finally LBuf.Free; end;
end;

procedure TestGaugeFilledAndEmptyStyle;
var LG: IWidget; LBuf: TBuffer;
begin
  LG := TGauge.New
    .WithRatio(0.5)
    .WithFilledStyle(StyleFg(TUI_GREEN))
    .WithEmptyStyle(StyleFg(TUI_RED)) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LG.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'gauge with styled filled/empty renders');
  finally LBuf.Free; end;
end;

procedure TestGaugeThreshold;
var LG: IWidget; LBuf: TBuffer;
begin
  LG := TGauge.New
    .WithRatio(0.8)
    .WithThreshold(0.7, StyleFg(TUI_RED)) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LG.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'gauge with threshold renders');
  finally LBuf.Free; end;
end;

{ === BarChart builders === }
procedure TestBarchartBuilders;
var LB: IWidget; LBuf: TBuffer;
begin
  LB := TBarChart.New([
    TBarData.Make('A', 5.0).WithStyle(StyleFg(TUI_BLUE)),
    TBarData.Make('B', 10.0)
  ]).WithMax(20.0).WithBarWidth(3).WithBarGap(1)
    .WithShowValues(True).WithShowLabels(True) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 25, 10));
  try LB.Render(TRect.Make(0, 0, 25, 10), LBuf);
    Check(True, 'barchart with all builders renders');
  finally LBuf.Free; end;
end;

{ === Canvas advanced === }
procedure TestCanvasClearDot;
var LC: ICanvas;
begin
  LC := TCanvas.New(5, 5);
  LC.SetDot(2, 2);
  Check(LC.GetDot(2, 2), 'dot set');
  LC.ClearDot(2, 2);
  Check(not LC.GetDot(2, 2), 'dot cleared');
end;

procedure TestCanvasDrawLine;
var LC: ICanvas; LBuf: TBuffer;
begin
  LC := TCanvas.New(10, 5);
  LC.DrawLine(0, 0, 9, 4);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    (LC as IWidget).Render(TRect.Make(0, 0, 10, 5), LBuf);
    Check(True, 'canvas line renders');
  finally LBuf.Free; end;
end;

procedure TestCanvasDrawRect;
var LC: ICanvas; LBuf: TBuffer;
begin
  LC := TCanvas.New(10, 5);
  LC.DrawRect(1, 1, 8, 3);
  Check(LC.GetDot(1, 1), 'rect corner set');
  Check(not LC.GetDot(5, 2), 'rect interior clear');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    (LC as IWidget).Render(TRect.Make(0, 0, 10, 5), LBuf);
    Check(True, 'canvas rect renders');
  finally LBuf.Free; end;
end;

procedure TestCanvasClear;
var LC: ICanvas;
begin
  LC := TCanvas.New(5, 5);
  LC.SetDot(0, 0);
  LC.SetDot(4, 4);
  LC.Clear;
  Check(not LC.GetDot(0, 0), 'canvas clear removes dots');
  Check(not LC.GetDot(4, 4), 'canvas clear removes all dots');
end;

{ === Table state navigation === }
procedure TestTableSelect;
var LT: ITable; LBuf: TBuffer; LState: TTableState;
begin
  LT := TTable.New([TTableColumn.Make('X', LengthConstraint(5))])
    .WithRows([TTableRow.Make(['a']), TTableRow.Make(['b']), TTableRow.Make(['c'])]);
  LState := TTableState.Empty;
  LState.HasSelection := True;
  LState.Select(0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 5), LBuf, LState);
    CheckEqual(0, LState.Selected, 'initial selection');
    LState.Select(1);
    CheckEqual(1, LState.Selected, 'after select 1');
    LState.Select(2);
    CheckEqual(2, LState.Selected, 'after select 2');
    LState.ClearSelection;
    Check(not LState.HasSelection, 'cleared selection');
  finally LBuf.Free; end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.batch');
  T.Test('gauge empty', @TestGaugeEmpty);
  T.Test('gauge full', @TestGaugeFull);
  T.Test('gauge label', @TestGaugeLabel);
  T.Test('sparkline render', @TestSparklineRender);
  T.Test('barchart with data', @TestBarchartWithData);
  T.Test('canvas draw dot', @TestCanvasDrawDot);
  T.Test('table with data', @TestTableWithData);
  T.Test('table selection', @TestTableSelection);
  T.Test('table empty rows clear state', @TestTableEmptyRowsClearState);
  T.Test('table column alignment', @TestTableColumnAlignment);
  T.Test('input render', @TestInputRender);
  T.Test('input cursor', @TestInputCursor);
  T.Test('gauge percent', @TestGaugePercent);
  T.Test('gauge styled filled/empty', @TestGaugeFilledAndEmptyStyle);
  T.Test('gauge threshold', @TestGaugeThreshold);
  T.Test('barchart builders', @TestBarchartBuilders);
  T.Test('canvas clear dot', @TestCanvasClearDot);
  T.Test('canvas draw line', @TestCanvasDrawLine);
  T.Test('canvas draw rect', @TestCanvasDrawRect);
  T.Test('canvas clear', @TestCanvasClear);
  T.Test('table select/clear', @TestTableSelect);
  if not T.Run then Halt(1);
end.
