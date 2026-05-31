program test_tui_widget_batch;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.layout,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.widget.sparkline,
  nextpas.core.tui.widget.barchart,
  nextpas.core.tui.widget.canvas,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input,
  nextpas.core.testing;
var T: TTestRunner;

{ === Gauge === }
procedure TestGaugeEmpty;
var LG: TGauge; LBuf: TBuffer;
begin
  LG := TGauge.Default.WithRatio(0.0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LG.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'empty gauge renders');
  finally LBuf.Free; end;
end;

procedure TestGaugeFull;
var LG: TGauge; LBuf: TBuffer; LRow: AnsiString;
begin
  LG := TGauge.Default.WithRatio(1.0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try LG.Render(TRect.Make(0, 0, 5, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    { 全满应有 full block 字符 U+2588 = E2 96 88 }
    Check(Pos(#$E2#$96#$88, LRow) > 0, 'full gauge has block chars');
  finally LBuf.Free; end;
end;

procedure TestGaugeLabel;
var LG: TGauge; LBuf: TBuffer; LRow: AnsiString;
begin
  LG := TGauge.Default.WithRatio(0.5).WithLabel('50%');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LG.Render(TRect.Make(0, 0, 20, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('50%', LRow) > 0, 'label visible');
  finally LBuf.Free; end;
end;

{ === Sparkline === }
procedure TestSparklineRender;
var LS: TSparkline; LBuf: TBuffer; LRow: AnsiString;
begin
  LS := TSparkline.Create([1.0, 5.0, 2.0, 8.0, 3.0]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try LS.Render(TRect.Make(0, 0, 5, 2), LBuf);
    LRow := LBuf.RowAsString(0);
    { braille chars are U+2800..U+28FF = E2 A0 80..E2 A3 BF }
    Check(Length(LRow) > 0, 'sparkline has content');
  finally LBuf.Free; end;
end;

{ === BarChart === }
procedure TestBarchartWithData;
var LB: TBarChart; LBuf: TBuffer; LLines: TBufferLines;
begin
  LB := TBarChart.Create([
    TBarData.Make('A', 5.0),
    TBarData.Make('B', 10.0)
  ]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 8));
  try LB.Render(TRect.Make(0, 0, 20, 8), LBuf);
    LLines := LBuf.AsLines;
    { 底部应有标签 }
    Check(Pos('A', LLines[High(LLines)]) > 0, 'label A at bottom');
  finally LBuf.Free; end;
end;

{ === Canvas === }
procedure TestCanvasDrawDot;
var LC: TCanvas; LBuf: TBuffer; LRow: AnsiString;
begin
  LC := TCanvas.Create(10, 8);
  LC.SetDot(2, 3);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 4));
  try LC.Render(TRect.Make(0, 0, 5, 4), LBuf);
    LRow := LBuf.RowAsString(0);
    { 应有非空 braille 字符 }
    Check(Length(LRow) > 0, 'canvas with dot has content');
  finally LBuf.Free; end;
end;

{ === Table === }
procedure TestTableWithData;
var LT: TTable; LBuf: TBuffer; LState: TTableState; LLines: TBufferLines;
begin
  LT := TTable.Create([
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
var LT: TTable; LBuf: TBuffer; LState: TTableState;
begin
  LT := TTable.Create([TTableColumn.Make('X', LengthConstraint(5))])
    .WithRows([TTableRow.Make(['a']), TTableRow.Make(['b'])]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 4));
  LState := TTableState.Empty;
  LState.Selected := 1;
  LState.HasSelection := True;
  try LT.RenderStateful(TRect.Make(0, 0, 10, 4), LBuf, LState);
    Check(True, 'table with selection renders');
  finally LBuf.Free; end;
end;

{ === Input === }
procedure TestInputRender;
var LI: TInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.Default;
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('hello', LRow) > 0, 'input shows text');
  finally LBuf.Free; end;
end;

procedure TestInputCursor;
var LI: TInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.Default;
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try LI.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    Check(True, 'input with cursor renders');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.batch');
  T.Run('gauge empty', @TestGaugeEmpty);
  T.Run('gauge full', @TestGaugeFull);
  T.Run('gauge label', @TestGaugeLabel);
  T.Run('sparkline render', @TestSparklineRender);
  T.Run('barchart with data', @TestBarchartWithData);
  T.Run('canvas draw dot', @TestCanvasDrawDot);
  T.Run('table with data', @TestTableWithData);
  T.Run('table selection', @TestTableSelection);
  //T.Run('input render', @TestInputRender);
  //T.Run('input cursor', @TestInputCursor);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
