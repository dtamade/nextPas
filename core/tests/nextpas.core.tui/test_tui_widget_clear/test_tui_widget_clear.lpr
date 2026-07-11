program test_tui_widget_clear;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
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

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.clear');
  T.Test('TClearWidget.New', @TestClearWidgetNew);
  T.Test('TClearWidget.Render', @TestClearWidgetRender);
  T.Test('TClearWidget.Render partial', @TestClearWidgetRenderPartial);
  T.Test('TClearWidget.Render empty', @TestClearWidgetRenderEmpty);
  if not T.Run then Halt(1);
end.
