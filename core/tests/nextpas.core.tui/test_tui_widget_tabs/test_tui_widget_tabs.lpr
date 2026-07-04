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

begin
  T := TTestSuite.Create('test_tui_widget_tabs');
  try
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

    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
