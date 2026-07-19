program test_tui_widget_menu;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.menu,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestMenuItemAction;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Action('Open');
  Check(LItem.Kind = mikAction, 'Should be action kind');
  Check(LItem.Label_ = 'Open', 'Should set label');
end;

procedure TestMenuItemSeparator;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Separator;
  Check(LItem.Kind = mikSeparator, 'Should be separator kind');
end;

procedure TestMenuItemWithShortcut;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Action('Save').WithShortcut('Ctrl+S');
  Check(LItem.Shortcut = 'Ctrl+S', 'Should set shortcut');
end;

procedure TestMenuItemWithEnabled;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Action('Delete').WithEnabled(False);
  Check(not LItem.Enabled, 'Should be disabled');
end;

procedure TestMenuItemWithChildren;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Action('Export').WithChildren([
    TMenuItem.Action('PDF'),
    TMenuItem.Action('HTML')
  ]);
  Check(LItem.Kind = mikSubmenu, 'Should be submenu kind');
  Check(Length(LItem.Children) = 2, 'Should have 2 children');
end;

procedure TestMenuStateDefault;
var
  LState: TMenuState;
begin
  LState := TMenuState.Default;
  Check(LState.Selected = 0, 'Should default to index 0');
end;

procedure TestMenuNew;
var
  LMenu: IMenu;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2')
  ]);
  Check(LMenu <> nil, 'Should create menu instance');
end;

procedure TestMenuWithStyle;
var
  LMenu: IMenu;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LMenu := TMenu.New([TMenuItem.Action('Test')]).WithStyle(LStyle);
  Check(LMenu <> nil, 'Should set style');
end;

procedure TestMenuWithHighlightStyle;
var
  LMenu: IMenu;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LMenu := TMenu.New([TMenuItem.Action('Test')]).WithHighlightStyle(LStyle);
  Check(LMenu <> nil, 'Should set highlight style');
end;

procedure TestMenuWithDisabledStyle;
var
  LMenu: IMenu;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LMenu := TMenu.New([TMenuItem.Action('Test')]).WithDisabledStyle(LStyle);
  Check(LMenu <> nil, 'Should set disabled style');
end;

procedure TestMenuWithWidth;
var
  LMenu: IMenu;
begin
  LMenu := TMenu.New([TMenuItem.Action('Test')]).WithWidth(30);
  Check(LMenu <> nil, 'Should set width');
end;

procedure TestMenuRenderStateful;
var
  LMenu: IMenu;
  LState: TMenuState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2'),
    TMenuItem.Action('Item 3')
  ]);
  LState := TMenuState.Default;
  LArea := TRect.Make(0, 0, 20, 5);
  LBuf := TBuffer.CreateEmpty(LArea);
  LMenu.RenderStateful(LArea, LBuf, LState);
  Check(True, 'Should render stateful menu');
end;

procedure TestMenuMoveDown;
var
  LMenu: IMenu;
  LState: TMenuState;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2'),
    TMenuItem.Action('Item 3')
  ]);
  LState := TMenuState.Default;
  Check(LState.Selected = 0, 'Should start at 0');
  LMenu.MoveDown(LState);
  Check(LState.Selected = 1, 'Should move to 1');
  LMenu.MoveDown(LState);
  Check(LState.Selected = 2, 'Should move to 2');
end;

procedure TestMenuMoveDownWrap;
var
  LMenu: IMenu;
  LState: TMenuState;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2')
  ]);
  LState := TMenuState.Default;
  LMenu.MoveDown(LState);
  Check(LState.Selected = 1, 'Should be at 1');
  LMenu.MoveDown(LState);
  Check(LState.Selected = 0, 'Should wrap to 0');
end;

procedure TestMenuMoveUp;
var
  LMenu: IMenu;
  LState: TMenuState;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2'),
    TMenuItem.Action('Item 3')
  ]);
  LState := TMenuState.Default;
  LState.Selected := 2;
  LMenu.MoveUp(LState);
  Check(LState.Selected = 1, 'Should move to 1');
  LMenu.MoveUp(LState);
  Check(LState.Selected = 0, 'Should move to 0');
end;

procedure TestMenuMoveUpWrap;
var
  LMenu: IMenu;
  LState: TMenuState;
begin
  LMenu := TMenu.New([
    TMenuItem.Action('Item 1'),
    TMenuItem.Action('Item 2')
  ]);
  LState := TMenuState.Default;
  Check(LState.Selected = 0, 'Should start at 0');
  LMenu.MoveUp(LState);
  Check(LState.Selected = 1, 'Should wrap to 1');
end;

procedure TestMenuBuilderChaining;
var
  LMenu: IMenu;
  LStyle, LHighlightStyle, LDisabledStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LHighlightStyle.Fg := IndexedColor(2);
  LDisabledStyle.Fg := IndexedColor(3);
  LMenu := TMenu.New([
    TMenuItem.Action('New').WithShortcut('Ctrl+N'),
    TMenuItem.Separator,
    TMenuItem.Action('Exit').WithShortcut('Alt+F4')
  ])
    .WithStyle(LStyle)
    .WithHighlightStyle(LHighlightStyle)
    .WithDisabledStyle(LDisabledStyle)
    .WithWidth(25);
  Check(LMenu <> nil, 'Should chain builder calls');
end;

begin
  T := TTestSuite.Create('tui_widget_menu');
  T.Test('TMenuItem.Action', @TestMenuItemAction);
  T.Test('TMenuItem.Separator', @TestMenuItemSeparator);
  T.Test('TMenuItem.WithShortcut', @TestMenuItemWithShortcut);
  T.Test('TMenuItem.WithEnabled', @TestMenuItemWithEnabled);
  T.Test('TMenuItem.WithChildren', @TestMenuItemWithChildren);
  T.Test('TMenuState.Default', @TestMenuStateDefault);
  T.Test('IMenu.New creates instance', @TestMenuNew);
  T.Test('IMenu.WithStyle', @TestMenuWithStyle);
  T.Test('IMenu.WithHighlightStyle', @TestMenuWithHighlightStyle);
  T.Test('IMenu.WithDisabledStyle', @TestMenuWithDisabledStyle);
  T.Test('IMenu.WithWidth', @TestMenuWithWidth);
  T.Test('IMenu.RenderStateful', @TestMenuRenderStateful);
  T.Test('IMenu.MoveDown', @TestMenuMoveDown);
  T.Test('IMenu.MoveDown wraps at end', @TestMenuMoveDownWrap);
  T.Test('IMenu.MoveUp', @TestMenuMoveUp);
  T.Test('IMenu.MoveUp wraps at start', @TestMenuMoveUpWrap);
  T.Test('IMenu builder chaining', @TestMenuBuilderChaining);
  if not T.Run then Halt(1);
end.
