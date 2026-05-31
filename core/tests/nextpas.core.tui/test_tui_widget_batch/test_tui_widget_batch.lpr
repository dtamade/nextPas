program test_tui_widget_batch;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.widget.sparkline,
  nextpas.core.tui.widget.barchart,
  nextpas.core.tui.widget.canvas,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input,
  nextpas.core.testing;
var T: TTestRunner;

procedure TestGaugeRender;
var LG: TGauge; LBuf: TBuffer;
begin
  LG := TGauge.Default.WithRatio(0.5).WithLabel('50%');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LG.Render(TRect.Make(0, 0, 20, 1), LBuf);
    Check(True, 'gauge rendered'); finally LBuf.Free; end;
end;

procedure TestSparklineRender;
var LS: TSparkline; LBuf: TBuffer;
begin
  LS := TSparkline.Create([1.0, 3.0, 2.0, 5.0, 4.0]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try LS.Render(TRect.Make(0, 0, 5, 2), LBuf);
    Check(True, 'sparkline rendered'); finally LBuf.Free; end;
end;

procedure TestBarchartRender;
var LB: TBarChart; LBuf: TBuffer;
begin
  LB := TBarChart.Create([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try LB.Render(TRect.Make(0, 0, 20, 5), LBuf);
    Check(True, 'barchart rendered'); finally LBuf.Free; end;
end;

procedure TestCanvasRender;
var LC: TCanvas; LBuf: TBuffer;
begin
  LC := TCanvas.Create(10, 8);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 4));
  try LC.Render(TRect.Make(0, 0, 5, 4), LBuf);
    Check(True, 'canvas rendered'); finally LBuf.Free; end;
end;

procedure TestTableRender;
var LT: TTable; LBuf: TBuffer;
begin
  LT := TTable.Create([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 5));
  try LT.Render(TRect.Make(0, 0, 30, 5), LBuf);
    Check(True, 'table rendered'); finally LBuf.Free; end;
end;

procedure TestInputRender;
var LI: TInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.Default; LS := TInputState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'input rendered'); finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.batch');
  T.Run('gauge render', @TestGaugeRender);
  T.Run('sparkline render', @TestSparklineRender);
  T.Run('barchart render', @TestBarchartRender);
  T.Run('canvas render', @TestCanvasRender);
  T.Run('table render', @TestTableRender);
  T.Run('input render', @TestInputRender);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
