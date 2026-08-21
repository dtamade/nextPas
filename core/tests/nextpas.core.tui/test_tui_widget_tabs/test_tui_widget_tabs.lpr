program test_tui_widget_tabs;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.tabs,
  nextpas.core.test;

var T: TTestSuite;

{ === TTabsState === }

procedure TestTabsStateDefault;
var S: TTabsState;
begin
  FillChar(S, SizeOf(S), 0);
  Check(S.Selected = 0, 'default selected is 0');
end;

{ === ITabsWidget Builders === }

procedure TestTabsNew;
var LT: ITabsWidget;
begin
  LT := TTabsWidget.New(['Tab1', 'Tab2', 'Tab3']);
  Check(LT <> nil, 'TTabsWidget.New returns non-nil');
end;

procedure TestTabsRender;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['Home', 'Settings']);
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Home', LRow) > 0, 'Home tab visible');
    Check(Pos('Settings', LRow) > 0, 'Settings tab visible');
  finally LBuf.Free; end;
end;

procedure TestTabsSelection;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New(['A', 'B', 'C']);
  FillChar(LS, SizeOf(LS), 0);
  LS.Selected := 1;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'tabs with selection renders');
  finally LBuf.Free; end;
end;

procedure TestTabsWithActiveStyle;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New(['A', 'B'])
    .WithActiveStyle(TStyle.Default.WithBg(IndexedColor(4)));
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    Check(True, 'tabs with active style renders');
  finally LBuf.Free; end;
end;

procedure TestTabsWithInactiveStyle;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New(['A', 'B'])
    .WithInactiveStyle(TStyle.Default.WithFg(IndexedColor(8)));
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    Check(True, 'tabs with inactive style renders');
  finally LBuf.Free; end;
end;

procedure TestTabsWithSeparator;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B', 'C'])
    .WithSeparator(' | ');
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('|', LRow) > 0, 'separator visible');
  finally LBuf.Free; end;
end;

procedure TestTabsAsIWidget;
var LT: ITabsWidget; LW: IWidget;
begin
  LT := TTabsWidget.New(['A', 'B']);
  LW := LT as IWidget;
  Check(LW <> nil, 'ITabsWidget casts to IWidget');
end;

procedure TestTabsRenderIWidget;
var LT: ITabsWidget; LBuf: TBuffer;
begin
  LT := TTabsWidget.New(['X', 'Y']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    (LT as IWidget).Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'IWidget.Render works');
  finally LBuf.Free; end;
end;

procedure TestTabsEmptyTitles;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New([]);
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'Empty titles should not crash');
  finally LBuf.Free; end;
end;

procedure TestTabsSingleTab;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['Only']);
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Only', LRow) > 0, 'Single tab visible');
    Check(Pos('|', LRow) = 0, 'No separator with single tab');
  finally LBuf.Free; end;
end;

procedure TestTabsCustomSeparator;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B']).WithSeparator(' <-> ');
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('<->', LRow) > 0, 'Custom separator visible');
  finally LBuf.Free; end;
end;

procedure TestTabsTruncation;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['Tab1', 'Tab2', 'Tab3']);
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 8, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Length(LRow) > 0, 'Should produce some output even when truncated');
  finally LBuf.Free; end;
end;

{ === New tests === }

procedure TestTabsSelectedOutOfBounds;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B', 'C']);
  FillChar(LS, SizeOf(LS), 0);
  LS.Selected := 99;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('A', LRow) > 0, 'renders with out-of-bounds selected');
  finally LBuf.Free; end;
end;

procedure TestTabsSelectedNegative;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B']);
  FillChar(LS, SizeOf(LS), 0);
  LS.Selected := -1;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Length(LRow) > 0, 'renders with negative selected');
  finally LBuf.Free; end;
end;

procedure TestTabsActiveStyleApplied;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LCell: PCell;
begin
  LT := TTabsWidget.New(['A', 'B'])
    .WithActiveStyle(TStyle.Default.WithFg(TUI_RED));
  FillChar(LS, SizeOf(LS), 0);
  LS.Selected := 0;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    LCell := LBuf.CellAt(0, 0);
    Check(LCell <> nil, 'cell exists');
    Check(ColorEquals(TUI_RED, LCell^.Fg), 'active style fg applied');
  finally LBuf.Free; end;
end;

procedure TestTabsInactiveStyleApplied;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LCell: PCell;
begin
  LT := TTabsWidget.New(['A', 'B'])
    .WithInactiveStyle(TStyle.Default.WithFg(TUI_GRAY));
  FillChar(LS, SizeOf(LS), 0);
  LS.Selected := 0;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    { Second tab 'B' starts after separator ' | ' at position3 }
    LCell := LBuf.CellAt(4, 0);
    if LCell <> nil then
      Check(ColorEquals(TUI_GRAY, LCell^.Fg), 'inactive style fg applied');
  finally LBuf.Free; end;
end;

procedure TestTabsNoSepBeforeFirst;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B']).WithSeparator(' | ');
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    { First char should be 'A', not separator }
    Check(LRow[1] = 'A', 'no separator before first tab');
  finally LBuf.Free; end;
end;

procedure TestTabsVeryNarrowWithSep;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New(['A', 'B']).WithSeparator(' | ');
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 2, 1), LBuf, LS);
    Check(True, 'very narrow does not crash');
  finally LBuf.Free; end;
end;

procedure TestTabsEmptyArea;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState;
begin
  LT := TTabsWidget.New(['A', 'B']);
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    LT.RenderStateful(TRect.Make(0, 0, 0, 0), LBuf, LS);
    Check(True, 'empty area does not crash');
  finally LBuf.Free; end;
end;

procedure TestTabsEmptySeparator;
var LT: ITabsWidget; LBuf: TBuffer; LS: TTabsState; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['A', 'B']).WithSeparator('');
  FillChar(LS, SizeOf(LS), 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LT.RenderStateful(TRect.Make(0, 0, 10, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('A', LRow) > 0, 'empty sep renders A');
    Check(Pos('B', LRow) > 0, 'empty sep renders B');
  finally LBuf.Free; end;
end;

{ PH33 P3：数据更新面——SetTitles 原地替换页签标题 }
procedure TestTabsSetTitles;
var LT: ITabsWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  LT := TTabsWidget.New(['alpha', 'beta']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 1));
  try
    LT.SetTitles(['delta', 'gamma']);
    LT.Render(TRect.Make(0, 0, 30, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('gamma', LRow) > 0, 'new title gamma visible');
    Check(Pos('alpha', LRow) = 0, 'old title alpha gone');
  finally LBuf.Free; end;
end;

procedure TestTabsWithTitlesChaining;
var LT: ITabsWidget;
begin
  LT := TTabsWidget.New(['a']).WithTitles(['x', 'y', 'z']);
  Check(LT <> nil, 'WithTitles chains and returns interface');
end;

begin
  T := TTestSuite.Create('test_tui_widget_tabs');
  { TTabsState }
  T.Test('TabsState default', @TestTabsStateDefault);
  { ITabsWidget Builders }
  T.Test('Tabs New', @TestTabsNew);
  T.Test('Tabs render', @TestTabsRender);
  T.Test('Tabs selection', @TestTabsSelection);
  T.Test('Tabs WithActiveStyle', @TestTabsWithActiveStyle);
  T.Test('Tabs WithInactiveStyle', @TestTabsWithInactiveStyle);
  T.Test('Tabs WithSeparator', @TestTabsWithSeparator);
  T.Test('Tabs as IWidget', @TestTabsAsIWidget);
  T.Test('Tabs IWidget.Render', @TestTabsRenderIWidget);
  T.Test('Tabs empty titles', @TestTabsEmptyTitles);
  T.Test('Tabs single tab', @TestTabsSingleTab);
  T.Test('Tabs custom separator', @TestTabsCustomSeparator);
  T.Test('Tabs truncation', @TestTabsTruncation);
  { New tests }
  T.Test('Tabs selected out of bounds', @TestTabsSelectedOutOfBounds);
  T.Test('Tabs selected negative', @TestTabsSelectedNegative);
  T.Test('Tabs active style applied', @TestTabsActiveStyleApplied);
  T.Test('Tabs inactive style applied', @TestTabsInactiveStyleApplied);
  T.Test('Tabs no sep before first', @TestTabsNoSepBeforeFirst);
  T.Test('Tabs very narrow with sep', @TestTabsVeryNarrowWithSep);
  T.Test('Tabs empty area', @TestTabsEmptyArea);
  T.Test('Tabs empty separator', @TestTabsEmptySeparator);
  T.Test('SetTitles in-place update (PH33 P3)', @TestTabsSetTitles);
  T.Test('WithTitles chaining (PH33 P3)', @TestTabsWithTitlesChaining);
  if not T.Run then Halt(1);
end.
