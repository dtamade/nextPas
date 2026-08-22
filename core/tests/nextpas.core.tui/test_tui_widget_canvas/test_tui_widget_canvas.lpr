program test_tui_widget_canvas;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.canvas,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCanvasNew;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  Check(LCanvas <> nil, 'New canvas should not be nil');
  Check(LCanvas.Width = 20, 'Width should be CellWidth*2 = 20');
  Check(LCanvas.Height = 40, 'Height should be CellHeight*4 = 40');
end;

procedure TestCanvasNewSmall;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(1, 1);
  Check(LCanvas.Width = 2, 'Width should be 2');
  Check(LCanvas.Height = 4, 'Height should be 4');
end;

procedure TestCanvasClear;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(5, 5);
  LCanvas.SetDot(0, 0);
  Check(LCanvas.GetDot(0, 0), 'Dot should be set');
  LCanvas.Clear;
  Check(not LCanvas.GetDot(0, 0), 'Dot should be cleared after Clear');
end;

procedure TestCanvasSetDot;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.SetDot(5, 5);
  Check(LCanvas.GetDot(5, 5), 'Dot should be set at (5,5)');
  Check(not LCanvas.GetDot(0, 0), 'Dot should not be set at (0,0)');
end;

procedure TestCanvasClearDot;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.SetDot(5, 5);
  Check(LCanvas.GetDot(5, 5), 'Dot should be set');
  LCanvas.ClearDot(5, 5);
  Check(not LCanvas.GetDot(5, 5), 'Dot should be cleared');
end;

procedure TestCanvasGetDotBoundary;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  Check(not LCanvas.GetDot(-1, 0), 'GetDot should return false for negative X');
  Check(not LCanvas.GetDot(0, -1), 'GetDot should return false for negative Y');
  Check(not LCanvas.GetDot(20, 0), 'GetDot should return false for X >= Width');
  Check(not LCanvas.GetDot(0, 40), 'GetDot should return false for Y >= Height');
end;

procedure TestCanvasDrawLineHorizontal;
var
  LCanvas: ICanvas;
  I: Integer;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawLine(0, 0, 10, 0);
  for I := 0 to 10 do
    Check(LCanvas.GetDot(I, 0), 'Dot should be set at (' + IntToStr(I) + ',0)');
  Check(not LCanvas.GetDot(0, 1), 'Dot should not be set at (0,1)');
end;

procedure TestCanvasDrawLineVertical;
var
  LCanvas: ICanvas;
  I: Integer;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawLine(0, 0, 0, 10);
  for I := 0 to 10 do
    Check(LCanvas.GetDot(0, I), 'Dot should be set at (0,' + IntToStr(I) + ')');
  Check(not LCanvas.GetDot(1, 0), 'Dot should not be set at (1,0)');
end;

procedure TestCanvasDrawLineDiagonal;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawLine(0, 0, 5, 5);
  Check(LCanvas.GetDot(0, 0), 'Dot should be set at (0,0)');
  Check(LCanvas.GetDot(5, 5), 'Dot should be set at (5,5)');
  Check(LCanvas.GetDot(2, 2), 'Dot should be set at (2,2)');
end;

procedure TestCanvasDrawRect;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawRect(2, 2, 5, 5);
  Check(LCanvas.GetDot(2, 2), 'Corner (2,2) should be set');
  Check(LCanvas.GetDot(5, 2), 'Corner (5,2) should be set');
  Check(LCanvas.GetDot(2, 5), 'Corner (2,5) should be set');
  Check(LCanvas.GetDot(5, 5), 'Corner (5,5) should be set');
  Check(LCanvas.GetDot(3, 2), 'Edge (3,2) should be set');
  Check(not LCanvas.GetDot(3, 3), 'Inside (3,3) should not be set');
end;

procedure TestCanvasDrawCircle;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(20, 20);
  LCanvas.DrawCircle(10, 10, 5);
  Check(LCanvas.GetDot(10, 5), 'Top of circle should be set');
  Check(LCanvas.GetDot(10, 15), 'Bottom of circle should be set');
  Check(LCanvas.GetDot(5, 10), 'Left of circle should be set');
  Check(LCanvas.GetDot(15, 10), 'Right of circle should be set');
end;

procedure TestCanvasPlot;
var
  LCanvas: ICanvas;
  LData: array[0..4] of Double;
begin
  LCanvas := TCanvas.New(10, 10);
  LData[0] := 0.0;
  LData[1] := 0.5;
  LData[2] := 1.0;
  LData[3] := 0.5;
  LData[4] := 0.0;
  LCanvas.Plot(LData, 1.0);
  Check(True, 'Plot should not raise exception');
end;

procedure TestCanvasWithStyle;
var
  LCanvas: ICanvas;
  LStyle: TStyle;
begin
  LCanvas := TCanvas.New(10, 10);
  LStyle.Fg := IndexedColor(1);
  LCanvas := LCanvas.WithStyle(LStyle);
  Check(LCanvas <> nil, 'WithStyle should return canvas');
end;

procedure TestCanvasRender;
var
  LCanvas: ICanvas;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LCanvas := TCanvas.New(5, 5);
  LCanvas.SetDot(0, 0);
  LCanvas.SetDot(1, 1);
  LArea := TRect.Make(0, 0, 10, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCanvas.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestCanvasMultipleDots;
var
  LCanvas: ICanvas;
  I: Integer;
begin
  LCanvas := TCanvas.New(10, 10);
  for I := 0 to 9 do
    LCanvas.SetDot(I, I);
  for I := 0 to 9 do
    Check(LCanvas.GetDot(I, I), 'Dot should be set at (' + IntToStr(I) + ',' + IntToStr(I) + ')');
end;

procedure TestCanvasRenderEmpty;
var
  LCanvas: ICanvas;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LCanvas := TCanvas.New(5, 5);
  LArea := TRect.Make(0, 0, 10, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCanvas.Render(LArea, LBuffer);
    Check(True, 'Render empty canvas should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestCanvasRenderSmallArea;
var
  LCanvas: ICanvas;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.SetDot(0, 0);
  LArea := TRect.Make(0, 0, 2, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCanvas.Render(LArea, LBuffer);
    Check(True, 'Render in small area should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestCanvasDrawLineZeroLength;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawLine(5, 5, 5, 5);
  Check(LCanvas.GetDot(5, 5), 'Zero-length line should set dot at (5,5)');
end;

procedure TestCanvasDrawRectZeroSize;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawRect(3, 3, 3, 3);
  Check(LCanvas.GetDot(3, 3), 'Zero-size rect should set dot at (3,3)');
end;

procedure TestCanvasDrawCircleZeroRadius;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.DrawCircle(5, 5, 0);
  Check(LCanvas.GetDot(5, 5), 'Zero-radius circle should set dot at center');
end;

procedure TestCanvasSetDotBoundary;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.SetDot(-1, 0);
  LCanvas.SetDot(0, -1);
  LCanvas.SetDot(20, 0);
  LCanvas.SetDot(0, 40);
  Check(True, 'SetDot out of bounds should not crash');
end;

procedure TestCanvasClearDotNotSet;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(10, 10);
  LCanvas.ClearDot(5, 5);
  Check(not LCanvas.GetDot(5, 5), 'ClearDot on unset dot should be no-op');
end;

{ PH33 P2b：布局配置面——WithBlock 块包装（点阵绘制进块内容区） }
procedure TestCanvasWithBlock;
var
  LCanvas: ICanvas;
  LBuf: TBuffer;
  LAll: AnsiString;
  I: Integer;
begin
  LCanvas := TCanvas.New(2, 2).WithBlock(TBlock.Bordered('T'));
  LCanvas.SetDot(0, 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 14));
  try
    LCanvas.Render(TRect.Make(0, 0, 20, 14), LBuf);
    Check(Pos(#$E2#$94#$8C, LBuf.RowAsString(0)) > 0, 'block border drawn');
    LAll := '';
    for I := 1 to 13 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos(#$E2#$A0, LAll) > 0, 'braille dot visible inside block');
  finally LBuf.Free; end;
end;

procedure TestCanvasWithBlockChaining;
var
  LCanvas: ICanvas;
begin
  LCanvas := TCanvas.New(1, 1).WithBlock(TBlock.Bordered('x'));
  Check(LCanvas <> nil, 'WithBlock chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.canvas');
  T.Test('TCanvas.New', @TestCanvasNew);
  T.Test('TCanvas.New small', @TestCanvasNewSmall);
  T.Test('TCanvas.Clear', @TestCanvasClear);
  T.Test('TCanvas.SetDot', @TestCanvasSetDot);
  T.Test('TCanvas.ClearDot', @TestCanvasClearDot);
  T.Test('TCanvas.GetDot boundary', @TestCanvasGetDotBoundary);
  T.Test('TCanvas.DrawLine horizontal', @TestCanvasDrawLineHorizontal);
  T.Test('TCanvas.DrawLine vertical', @TestCanvasDrawLineVertical);
  T.Test('TCanvas.DrawLine diagonal', @TestCanvasDrawLineDiagonal);
  T.Test('TCanvas.DrawRect', @TestCanvasDrawRect);
  T.Test('TCanvas.DrawCircle', @TestCanvasDrawCircle);
  T.Test('TCanvas.Plot', @TestCanvasPlot);
  T.Test('TCanvas.WithStyle', @TestCanvasWithStyle);
  T.Test('TCanvas.Render', @TestCanvasRender);
  T.Test('TCanvas multiple dots', @TestCanvasMultipleDots);
  T.Test('TCanvas.Render empty', @TestCanvasRenderEmpty);
  T.Test('TCanvas.Render small area', @TestCanvasRenderSmallArea);
  T.Test('TCanvas.DrawLine zero length', @TestCanvasDrawLineZeroLength);
  T.Test('TCanvas.DrawRect zero size', @TestCanvasDrawRectZeroSize);
  T.Test('TCanvas.DrawCircle zero radius', @TestCanvasDrawCircleZeroRadius);
  T.Test('TCanvas.SetDot boundary', @TestCanvasSetDotBoundary);
  T.Test('TCanvas.ClearDot not set', @TestCanvasClearDotNotSet);
  T.Test('TCanvas WithBlock render (PH33 P2b)', @TestCanvasWithBlock);
  T.Test('TCanvas WithBlock chaining (PH33 P2b)', @TestCanvasWithBlockChaining);
  if not T.Run then Halt(1);
end.
