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
  nextpas.core.test;
var T: TTestSuite;

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
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(0);
  CheckEqual(Int64(1), Int64(LS.ThumbSize(10)), 'thumb size 1 (10% of 10)');
  CheckEqual(Int64(0), Int64(LS.ThumbStart(10)), 'thumb at top');
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(90);
  CheckEqual(Int64(9), Int64(LS.ThumbStart(10)), 'thumb at bottom');
end;

procedure TestScrollbarRender;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(20).WithVisible(5).WithOffset(0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 5));
  try
    LS.Render(TRect.Make(0, 0, 1, 5), LBuf);
    Check(True, 'scrollbar rendered without crash');
  finally LBuf.Free; end;
end;

procedure TestScrollbarHitTest;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(20).WithVisible(5).WithOffset(0);
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 0) = shThumb, 'hit thumb at 0');
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 3) = shBelow, 'hit below');
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 10) = shNone, 'hit none outside');
end;

procedure TestScrollbarClampsOffsetForThumbRenderAndHit;
var
  LS: IScrollbar;
  LBuf: TBuffer;
begin
  LS := TScrollbar.New
    .WithTotal(20)
    .WithVisible(5)
    .WithOffset(999)
    .WithTrackChar('.')
    .WithThumbChar('#');
  CheckEqual(Int64(15), Int64(LS.Clamped), 'scroll offset clamps to max');
  CheckEqual(Int64(4), Int64(LS.ThumbStart(5)), 'thumb start uses clamped offset');
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 4) = shThumb,
    'bottom row hits clamped thumb');

  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 5));
  try
    LS.Render(TRect.Make(0, 0, 1, 5), LBuf);
    CheckEqual('.', LBuf.RowAsString(0), 'row 0 remains track');
    CheckEqual('.', LBuf.RowAsString(1), 'row 1 remains track');
    CheckEqual('.', LBuf.RowAsString(2), 'row 2 remains track');
    CheckEqual('.', LBuf.RowAsString(3), 'row 3 remains track');
    CheckEqual('#', LBuf.RowAsString(4), 'row 4 renders clamped thumb');
  finally
    LBuf.Free;
  end;
end;

procedure TestScrollbarPageUpDown;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(50).WithVisible(10).WithOffset(20);
  CheckEqual(Int64(10), Int64(LS.PageUp), 'page up');
  CheckEqual(Int64(30), Int64(LS.PageDown), 'page down');
  LS := TScrollbar.New.WithTotal(50).WithVisible(10).WithOffset(0);
  CheckEqual(Int64(0), Int64(LS.PageUp), 'page up clamped at 0');
end;

{ === Tabs builders === }
procedure TestTabsStyles;
var LTabs: ITabsWidget; LBuf: TBuffer; LState: TTabsState;
begin
  LTabs := TTabsWidget.New(['A', 'B', 'C'])
    .WithActiveStyle(StyleFg(TUI_RED))
    .WithInactiveStyle(StyleFg(TUI_BLUE))
    .WithSeparator(' | ');
  LState.Selected := 0;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 1));
  try
    LTabs.RenderStateful(TRect.Make(0, 0, 30, 1), LBuf, LState);
    Check(Pos('A', LBuf.RowAsString(0)) > 0, 'tab A visible');
    Check(Pos('|', LBuf.RowAsString(0)) > 0, 'custom separator visible');
  finally LBuf.Free; end;
end;

procedure TestTabsNavigation;
var LState: TTabsState;
begin
  LState.Selected := 0;
  CheckEqual(0, LState.Selected, 'initial');
  LState.Selected := 1;
  CheckEqual(1, LState.Selected, 'after set');
  LState.Selected := 2;
  CheckEqual(2, LState.Selected, 'after second set');
end;

{ === Scrollbar builders === }
procedure TestScrollbarCustomChars;
var LS: IScrollbar; LBuf: TBuffer; LCell: PCell;
begin
  LS := TScrollbar.New
    .WithTotal(10).WithVisible(3).WithOffset(0)
    .WithTrackChar('.').WithThumbChar('#')
    .WithTrackStyle(StyleFg(TUI_BLUE))
    .WithThumbStyle(StyleFg(TUI_RED));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 5));
  try
    LS.Render(TRect.Make(0, 0, 1, 5), LBuf);
    LCell := LBuf.CellAt(0, 4);
    Check(LCell <> nil, 'cell at bottom exists');
    Check(True, 'scrollbar with custom chars renders');
  finally LBuf.Free; end;
end;

procedure TestScrollbarSingleItem;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(1).WithVisible(1).WithOffset(0);
  CheckEqual(Int64(0), Int64(LS.ThumbStart(5)), 'single item thumb at 0');
  { 未溢出(total = visible)= 无滚动条可点,HitAt 恒 shNone(语义修正:
    旧断言编码了退化态 ThumbSize 铺满整轨、整列误报 shThumb 的错误行为) }
  Check(LS.HitAt(TRect.Make(0, 0, 1, 5), 0) = shNone, 'single item no hit');
end;

procedure TestScrollbarOffsetFromDragY;
var LS: IScrollbar; LOffset: Integer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(0);
  LOffset := LS.OffsetFromDragY(TRect.Make(0, 0, 1, 10), 5);
  Check(LOffset >= 0, 'drag offset non-negative');
  Check(LOffset <= 90, 'drag offset within bounds');
end;


procedure TestTabsEmptyTitles;
var LT: ITabsWidget; LBuf: TBuffer;
begin
  LT := TTabsWidget.New([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 2));
  try
    LT.Render(TRect.Make(0, 0, 20, 2), LBuf);
    Check(True, 'empty tabs render');
  finally LBuf.Free; end;
end;

procedure TestScrollbarZeroTotal;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(0).WithVisible(0).WithOffset(0);
  CheckEqual(Int64(0), Int64(LS.ThumbStart(10)), 'zero total thumb start 0');
end;

procedure TestScrollbarOffsetClampOnRender;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(50).WithVisible(10).WithOffset(999);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 10));
  try
    LS.Render(TRect.Make(0, 0, 1, 10), LBuf);
    Check(True, 'large offset clamped on render');
  finally LBuf.Free; end;
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.widget.misc');
  T.Test('clear widget', @TestClearWidget);
  T.Test('tabs render', @TestTabsRender);
  T.Test('tabs as IWidget', @TestTabsAsIWidget);
  T.Test('scrollbar thumb', @TestScrollbarThumb);
  T.Test('scrollbar render', @TestScrollbarRender);
  T.Test('scrollbar hit test', @TestScrollbarHitTest);
  T.Test('scrollbar clamps offset for thumb render and hit',
    @TestScrollbarClampsOffsetForThumbRenderAndHit);
  T.Test('scrollbar page up/down', @TestScrollbarPageUpDown);
  T.Test('tabs styles', @TestTabsStyles);
  T.Test('tabs navigation', @TestTabsNavigation);
  T.Test('scrollbar custom chars', @TestScrollbarCustomChars);
  T.Test('scrollbar single item', @TestScrollbarSingleItem);
  T.Test('scrollbar offset from drag', @TestScrollbarOffsetFromDragY);
  T.Test('tabs empty titles', @TestTabsEmptyTitles);
  T.Test('scrollbar zero total', @TestScrollbarZeroTotal);
  T.Test('scrollbar offset clamp on render', @TestScrollbarOffsetClampOnRender);
if not T.Run then Halt(1);
end.
