program test_tui_widget_misc;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.clear,
  nextpas.core.tui.widget.tabs,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.testing;
var T: TTestRunner;

{ === TClearWidget === }
procedure TestClearWidget;
var LW: IWidget; LBuf: TBuffer; LCP: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  try
    LBuf.SetString(0, 0, 'XYZ', StyleDefault.WithFg(TUI_RED));
    LW := TClearWidget.New;
    LW.Render(TRect.Make(0, 0, 3, 2), LBuf);
    LCP := LBuf.CellAt(0, 0);
    Check(CellEquals(LCP^, CELL_EMPTY), 'cell reset to empty');
  finally LBuf.Free; end;
end;

{ === TTabsWidget === }
procedure TestTabsRender;
var LTabs: ITabsWidget; LBuf: TBuffer; LState: TTabsState; LRow: AnsiString;
begin
  LTabs := TTabsWidget.New(['Tab1', 'Tab2', 'Tab3']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 1));
  LState.Selected := 1;
  try
    LTabs.RenderStateful(TRect.Make(0, 0, 30, 1), LBuf, LState);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Tab1', LRow) > 0, 'Tab1 present');
    Check(Pos('Tab2', LRow) > 0, 'Tab2 present');
    Check(Pos('|', LRow) > 0, 'separator present');
  finally LBuf.Free; end;
end;

procedure TestTabsAsIWidget;
var LW: IWidget; LBuf: TBuffer;
begin
  LW := TTabsWidget.New(['A', 'B']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LW.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(Pos('A', LBuf.RowAsString(0)) > 0, 'rendered via IWidget');
  finally LBuf.Free; end;
end;

{ === TScrollbar === }
procedure TestScrollbarThumb;
var LS: TScrollbar;
begin
  LS.TotalItems := 100;
  LS.VisibleItems := 10;
  LS.ScrollOffset := 0;
  CheckEqual(Int64(1), Int64(LS.ThumbSize(10)), 'thumb size 1 (10% of 10)');
  CheckEqual(Int64(0), Int64(LS.ThumbStart(10)), 'thumb at top');
  LS.ScrollOffset := 90;
  CheckEqual(Int64(9), Int64(LS.ThumbStart(10)), 'thumb at bottom');
end;

procedure TestScrollbarRender;
var LS: TScrollbar; LBuf: TBuffer; LSty: TScrollbarStyle;
begin
  LS.TotalItems := 20;
  LS.VisibleItems := 5;
  LS.ScrollOffset := 0;
  LSty := DefaultScrollbarStyle;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 5));
  try
    LS.Render(TRect.Make(0, 0, 1, 5), LBuf, LSty);
    { 不崩溃即可——视觉验证需要真实终端 }
    Check(True, 'scrollbar rendered without crash');
  finally LBuf.Free; end;
end;

procedure TestScrollbarHitTest;
var LS: TScrollbar;
begin
  LS.TotalItems := 20;
  LS.VisibleItems := 5;
  LS.ScrollOffset := 0;
  { thumb at top, size ~1 in track height 5 }
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 0) = shThumb, 'hit thumb at 0');
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 3) = shBelow, 'hit below');
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 10) = shNone, 'hit none outside');
end;

procedure TestScrollbarPageUpDown;
var LS: TScrollbar;
begin
  LS.TotalItems := 50;
  LS.VisibleItems := 10;
  LS.ScrollOffset := 20;
  CheckEqual(Int64(10), Int64(LS.PageUp), 'page up');
  CheckEqual(Int64(30), Int64(LS.PageDown), 'page down');
  LS.ScrollOffset := 0;
  CheckEqual(Int64(0), Int64(LS.PageUp), 'page up clamped at 0');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.misc');
  T.Run('clear widget', @TestClearWidget);
  T.Run('tabs render', @TestTabsRender);
  T.Run('tabs as IWidget', @TestTabsAsIWidget);
  T.Run('scrollbar thumb', @TestScrollbarThumb);
  T.Run('scrollbar render', @TestScrollbarRender);
  T.Run('scrollbar hit test', @TestScrollbarHitTest);
  T.Run('scrollbar page up/down', @TestScrollbarPageUpDown);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
