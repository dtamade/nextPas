program test_tui_widget_clear;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.clear,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestClearWidgetNew;
var
  LWidget: IWidget;
begin
  LWidget := TClearWidget.New;
  Check(LWidget <> nil, 'New clear widget should not be nil');
end;

procedure TestClearWidgetRender;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
  LX, LY: Integer;
  LCP: PCell;
  LCell: TCell;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 5, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCell := CELL_EMPTY;
    LCell.Glyph.Bytes[0] := Ord('X');
    LCell.Glyph.Len := 1;
    for LY := 0 to 4 do
      for LX := 0 to 4 do
      begin
        LCP := LBuffer.CellAt(LX, LY);
        if LCP <> nil then
          LCP^ := LCell;
      end;
    LWidget.Render(LArea, LBuffer);
    for LY := 0 to 4 do
      for LX := 0 to 4 do
      begin
        LCP := LBuffer.CellAt(LX, LY);
        Check(LCP <> nil, 'Cell should exist');
        Check(LCP^.Glyph.Bytes[0] = 32, 'Cell should be cleared (space)');
      end;
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetRenderPartial;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea, LClearArea: TRect;
  LX, LY: Integer;
  LCP: PCell;
  LCell: TCell;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 10, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCell := CELL_EMPTY;
    LCell.Glyph.Bytes[0] := Ord('X');
    LCell.Glyph.Len := 1;
    for LY := 0 to 9 do
      for LX := 0 to 9 do
      begin
        LCP := LBuffer.CellAt(LX, LY);
        if LCP <> nil then
          LCP^ := LCell;
      end;
    LClearArea := TRect.Make(2, 2, 3, 3);
    LWidget.Render(LClearArea, LBuffer);
    for LY := 0 to 9 do
      for LX := 0 to 9 do
      begin
        LCP := LBuffer.CellAt(LX, LY);
        if (LX >= 2) and (LX < 5) and (LY >= 2) and (LY < 5) then
          Check(LCP^.Glyph.Bytes[0] = 32, 'Cell in clear area should be cleared')
        else
          Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'Cell outside clear area should not be cleared');
      end;
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetRenderEmpty;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 5, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LWidget.Render(LArea, LBuffer);
    Check(True, 'Render on empty buffer should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetZeroSize;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 0, 0);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LWidget.Render(LArea, LBuffer);
    Check(True, 'Render on zero-size should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetOutOfBounds;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 5, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LWidget.Render(TRect.Make(100, 100, 5, 5), LBuffer);
    Check(True, 'Render out of bounds should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure FillWithX(ABuf: TBuffer; const AArea: TRect);
var
  LX, LY: Integer;
  LCP: PCell;
  LCell: TCell;
begin
  LCell := CELL_EMPTY;
  LCell.Glyph.Bytes[0] := Ord('X');
  LCell.Glyph.Len := 1;
  for LY := AArea.Top to AArea.Bottom - 1 do
    for LX := AArea.Left to AArea.Right - 1 do
    begin
      LCP := ABuf.CellAt(LX, LY);
      if LCP <> nil then
        LCP^ := LCell;
    end;
end;

procedure TestClearWidgetIdempotent;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
  LCP: PCell;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 4, 4);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    FillWithX(LBuffer, LArea);
    LWidget.Render(LArea, LBuffer);
    LWidget.Render(LArea, LBuffer);
    LCP := LBuffer.CellAt(1, 1);
    Check(LCP <> nil, 'cell exists');
    Check(LCP^.Glyph.Bytes[0] = 32, 'double clear stays empty');
    Check(LCP^.Glyph.Len = CELL_EMPTY.Glyph.Len, 'empty glyph len');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetSingleCell;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LArea: TRect;
  LCP: PCell;
begin
  LWidget := TClearWidget.New;
  LArea := TRect.Make(0, 0, 3, 3);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    FillWithX(LBuffer, LArea);
    LWidget.Render(TRect.Make(1, 1, 1, 1), LBuffer);
    LCP := LBuffer.CellAt(1, 1);
    Check(LCP^.Glyph.Bytes[0] = 32, 'target cleared');
    LCP := LBuffer.CellAt(0, 0);
    Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'neighbor unchanged');
    LCP := LBuffer.CellAt(2, 2);
    Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'far neighbor unchanged');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetZeroWidth;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 4));
  try
    FillWithX(LBuffer, TRect.Make(0, 0, 4, 4));
    LWidget.Render(TRect.Make(1, 1, 0, 2), LBuffer);
    LCP := LBuffer.CellAt(1, 1);
    Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'zero-width clear is no-op');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetZeroHeight;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 4));
  try
    FillWithX(LBuffer, TRect.Make(0, 0, 4, 4));
    LWidget.Render(TRect.Make(1, 1, 2, 0), LBuffer);
    LCP := LBuffer.CellAt(1, 1);
    Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'zero-height clear is no-op');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetPartialClipEdge;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
  LX, LY: Integer;
begin
  { clear area overhangs buffer bottom-right; only intersection clears }
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 5));
  try
    FillWithX(LBuffer, TRect.Make(0, 0, 5, 5));
    LWidget.Render(TRect.Make(3, 3, 10, 10), LBuffer);
    for LY := 0 to 4 do
      for LX := 0 to 4 do
      begin
        LCP := LBuffer.CellAt(LX, LY);
        if (LX >= 3) and (LY >= 3) then
          Check(LCP^.Glyph.Bytes[0] = 32, 'clipped region cleared')
        else
          Check(LCP^.Glyph.Bytes[0] = Ord('X'), 'outside intersection kept');
      end;
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetResetsToCellEmpty;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
  LCell: TCell;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 2));
  try
    LCell := CELL_EMPTY;
    LCell.Glyph.Bytes[0] := Ord('#');
    LCell.Glyph.Len := 1;
    LCell.Width := 1;
    LCP := LBuffer.CellAt(0, 0);
    LCP^ := LCell;
    LWidget.Render(TRect.Make(0, 0, 1, 1), LBuffer);
    LCP := LBuffer.CellAt(0, 0);
    Check(LCP^.Glyph.Bytes[0] = CELL_EMPTY.Glyph.Bytes[0], 'glyph is CELL_EMPTY');
    Check(LCP^.Width = CELL_EMPTY.Width, 'width reset');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetTwoInstances;
var
  LWa, LWb: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
begin
  LWa := TClearWidget.New;
  LWb := TClearWidget.New;
  Check(LWa <> nil, 'a ok');
  Check(LWb <> nil, 'b ok');
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 2));
  try
    FillWithX(LBuffer, TRect.Make(0, 0, 2, 2));
    LWa.Render(TRect.Make(0, 0, 1, 2), LBuffer);
    LWb.Render(TRect.Make(1, 0, 1, 2), LBuffer);
    LCP := LBuffer.CellAt(0, 0);
    Check(LCP^.Glyph.Bytes[0] = 32, 'left cleared by a');
    LCP := LBuffer.CellAt(1, 1);
    Check(LCP^.Glyph.Bytes[0] = 32, 'right cleared by b');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetFullAreaAfterPartial;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    FillWithX(LBuffer, TRect.Make(0, 0, 4, 2));
    LWidget.Render(TRect.Make(1, 0, 2, 1), LBuffer);
    LWidget.Render(TRect.Make(0, 0, 4, 2), LBuffer);
    LCP := LBuffer.CellAt(0, 0);
    Check(LCP^.Glyph.Bytes[0] = 32, 'full clear row0');
    LCP := LBuffer.CellAt(3, 1);
    Check(LCP^.Glyph.Bytes[0] = 32, 'full clear row1');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetStyleDefaultAfterStyled;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
  LCP: PCell;
  LStyle: TStyle;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LStyle := StyleDefault;
    LStyle.Fg := RgbColor(255, 0, 0);
    LBuffer.SetString(0, 0, 'AB', LStyle);
    LWidget.Render(TRect.Make(0, 0, 2, 1), LBuffer);
    LCP := LBuffer.CellAt(0, 0);
    Check(ColorEquals(LCP^.Fg, CELL_EMPTY.Fg) or (not ColorIsSet(LCP^.Fg)),
      'fg cleared/default');
  finally
    LBuffer.Free;
  end;
end;

procedure TestClearWidgetDoesNotGrowBuffer;
var
  LWidget: IWidget;
  LBuffer: TBuffer;
begin
  LWidget := TClearWidget.New;
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  try
    LWidget.Render(TRect.Make(0, 0, 3, 2), LBuffer);
    CheckEqual(3, LBuffer.Area.Width, 'width unchanged');
    CheckEqual(2, LBuffer.Area.Height, 'height unchanged');
  finally
    LBuffer.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.clear');
  T.Test('TClearWidget.New', @TestClearWidgetNew);
  T.Test('TClearWidget.Render', @TestClearWidgetRender);
  T.Test('TClearWidget.Render partial', @TestClearWidgetRenderPartial);
  T.Test('TClearWidget.Render empty', @TestClearWidgetRenderEmpty);
  T.Test('TClearWidget zero size', @TestClearWidgetZeroSize);
  T.Test('TClearWidget out of bounds', @TestClearWidgetOutOfBounds);
  T.Test('TClearWidget idempotent', @TestClearWidgetIdempotent);
  T.Test('TClearWidget single cell', @TestClearWidgetSingleCell);
  T.Test('TClearWidget zero width', @TestClearWidgetZeroWidth);
  T.Test('TClearWidget zero height', @TestClearWidgetZeroHeight);
  T.Test('TClearWidget partial clip edge', @TestClearWidgetPartialClipEdge);
  T.Test('TClearWidget resets to CELL_EMPTY', @TestClearWidgetResetsToCellEmpty);
  T.Test('TClearWidget two instances', @TestClearWidgetTwoInstances);
  T.Test('TClearWidget full after partial', @TestClearWidgetFullAreaAfterPartial);
  T.Test('TClearWidget style default after styled', @TestClearWidgetStyleDefaultAfterStyled);
  T.Test('TClearWidget does not grow buffer', @TestClearWidgetDoesNotGrowBuffer);
  if not T.Run then Halt(1);
end.
