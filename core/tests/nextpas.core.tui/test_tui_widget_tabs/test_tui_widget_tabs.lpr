program test_tui_widget_tabs;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.tabs,
  nextpas.core.testing;

var T: TTestRunner;

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

begin
  T := TTestRunner.Create('test_tui_widget_tabs');
  try
    { TTabsState }
    T.Run('TabsState default', @TestTabsStateDefault);

    { ITabsWidget Builders }
    T.Run('Tabs New', @TestTabsNew);
    T.Run('Tabs render', @TestTabsRender);
    T.Run('Tabs selection', @TestTabsSelection);
    T.Run('Tabs WithActiveStyle', @TestTabsWithActiveStyle);
    T.Run('Tabs WithInactiveStyle', @TestTabsWithInactiveStyle);
    T.Run('Tabs WithSeparator', @TestTabsWithSeparator);
    T.Run('Tabs as IWidget', @TestTabsAsIWidget);
    T.Run('Tabs IWidget.Render', @TestTabsRenderIWidget);

    WriteLn;
    T.Summary;
  finally
  end;
end.
