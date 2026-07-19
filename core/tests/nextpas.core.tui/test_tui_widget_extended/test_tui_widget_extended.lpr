program test_tui_widget_extended;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.tree,
  nextpas.core.tui.widget.dialog,
  nextpas.core.tui.widget.menu,
  nextpas.core.test;
var T: TTestSuite;

{ === TTree === }
procedure TestTreeRender;
var LTree: ITree; LState: TTreeState; LBuf: TBuffer; LLines: TBufferLines;
begin
  LTree := TTree.New([
    TTreeNode.Make('Root').WithChildren([
      TTreeNode.Make('Child 1'),
      TTreeNode.Make('Child 2')
    ])
  ]);
  LState := TTreeState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 20, 5), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('Root', LLines[0]) > 0, 'root visible');
  finally LBuf.Free; end;
end;

procedure TestTreeSingleRoot;
var LTree: ITree; LState: TTreeState; LBuf: TBuffer;
begin
  LTree := TTree.New([TTreeNode.Make('Only')]);
  LState := TTreeState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 10, 3), LBuf, LState);
    Check(Pos('Only', LBuf.RowAsString(0)) > 0, 'single root visible');
  finally LBuf.Free; end;
end;

procedure TestTreeIndent;
var LTree: ITree; LState: TTreeState; LBuf: TBuffer;
begin
  LTree := TTree.New([
    TTreeNode.Make('P').WithChildren([TTreeNode.Make('C')])
  ]).WithIndent(4);
  LState := TTreeState.Empty;
  LState.EnsureSize(2);
  LState.Opened[0] := True;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 20, 3), LBuf, LState);
    Check(Pos('P', LBuf.RowAsString(0)) > 0, 'parent visible');
    Check(Pos('C', LBuf.RowAsString(1)) > 0, 'child visible');
  finally LBuf.Free; end;
end;

{ === TDialog === }
procedure TestDialogRender;
var LD: IWidget; LBuf: TBuffer; LLines: TBufferLines;
begin
  LD := TDialog.New('Confirm', 'Are you sure?') as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    LD.Render(TRect.Make(0, 0, 30, 10), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('Confirm', LLines[0]) > 0, 'title visible');
  finally LBuf.Free; end;
end;

procedure TestDialogWithButtons;
var LD: IDialog; LBuf: TBuffer;
begin
  LD := TDialog.New('Save?', 'Unsaved changes').WithButtons(['Yes', 'No']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    (LD as IWidget).Render(TRect.Make(0, 0, 40, 10), LBuf);
    Check(Pos('Yes', LBuf.RowAsString(8)) > 0, 'Yes button visible');
  finally LBuf.Free; end;
end;

procedure TestDialogCenteredArea;
var LD: IDialog; R: TRect;
begin
  LD := TDialog.New('Title', 'Body').WithWidth(20).WithHeight(5);
  R := LD.CenteredArea(TRect.Make(0, 0, 80, 24));
  CheckEqual(20, R.Width, 'centered width');
  CheckEqual(5, R.Height, 'centered height');
end;

{ === TMenu === }
procedure TestMenuRender;
var LM: IMenu; LState: TMenuState; LBuf: TBuffer; LLines: TBufferLines;
begin
  LM := TMenu.New([
    TMenuItem.Action('Open'),
    TMenuItem.Action('Save'),
    TMenuItem.Separator,
    TMenuItem.Action('Quit')
  ]);
  LState.Selected := 0;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 6));
  try
    LM.RenderStateful(TRect.Make(0, 0, 20, 6), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('Open', LLines[0]) > 0, 'Open visible');
    Check(Pos('Save', LLines[1]) > 0, 'Save visible');
    Check(Pos('Quit', LLines[3]) > 0, 'Quit visible');
  finally LBuf.Free; end;
end;

procedure TestMenuMoveDown;
var LM: IMenu; LState: TMenuState;
begin
  LM := TMenu.New([TMenuItem.Action('A'), TMenuItem.Action('B'), TMenuItem.Action('C')]);
  LState := TMenuState.Default;
  CheckEqual(0, LState.Selected, 'initial selected');
  LM.MoveDown(LState);
  CheckEqual(1, LState.Selected, 'after move down');
  LM.MoveDown(LState);
  CheckEqual(2, LState.Selected, 'after move down 2');
  LM.MoveDown(LState);
  CheckEqual(0, LState.Selected, 'wraps to 0');
end;

procedure TestMenuMoveUp;
var LM: IMenu; LState: TMenuState;
begin
  LM := TMenu.New([TMenuItem.Action('A'), TMenuItem.Action('B'), TMenuItem.Action('C')]);
  LState := TMenuState.Default;
  LState.Selected := 2;
  LM.MoveUp(LState);
  CheckEqual(1, LState.Selected, 'after move up');
  LM.MoveUp(LState);
  CheckEqual(0, LState.Selected, 'after move up 2');
  LM.MoveUp(LState);
  CheckEqual(2, LState.Selected, 'wraps to end');
end;

procedure TestMenuItemCount;
var LM: IMenu;
begin
  LM := TMenu.New([TMenuItem.Action('A'), TMenuItem.Separator, TMenuItem.Action('B')]);
  CheckEqual(3, LM.ItemCount, 'item count includes separator');
  CheckEqual(2, LM.SelectableCount, 'selectable excludes separator');
end;

procedure TestMenuShortcut;
var LM: IMenu; LState: TMenuState; LBuf: TBuffer;
begin
  LM := TMenu.New([TMenuItem.Action('Quit').WithShortcut('Ctrl+Q')]);
  LState := TMenuState.Default;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 3));
  try
    LM.RenderStateful(TRect.Make(0, 0, 30, 3), LBuf, LState);
    Check(Pos('Ctrl+Q', LBuf.RowAsString(0)) > 0, 'shortcut visible');
  finally LBuf.Free; end;
end;


procedure TestTreeEmptyNodes;
var LTree: ITree; LState: TTreeState; LBuf: TBuffer;
begin
  LTree := TTree.New([]);
  LState := TTreeState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 10, 3), LBuf, LState);
    Check(True, 'empty tree renders');
  finally LBuf.Free; end;
end;

procedure TestTreeSmallArea;
var LTree: ITree; LState: TTreeState; LBuf: TBuffer;
begin
  LTree := TTree.New([TTreeNode.Make('Root')]);
  LState := TTreeState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LTree.RenderStateful(TRect.Make(0, 0, 3, 1), LBuf, LState);
    { 3-cell width may clip label; ensure no crash and row length holds }
    CheckEqual(3, Length(LBuf.RowAsString(0)), 'small area row width');
  finally LBuf.Free; end;
end;

procedure TestDialogEmptyMessage;
var LD: IWidget; LBuf: TBuffer;
begin
  LD := TDialog.New('Title', '') as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 8));
  try
    LD.Render(TRect.Make(0, 0, 20, 8), LBuf);
    Check(Pos('Title', LBuf.RowAsString(0)) > 0, 'title with empty message');
  finally LBuf.Free; end;
end;

procedure TestMenuEmptyItems;
var LM: IMenu; LState: TMenuState; LBuf: TBuffer;
begin
  LM := TMenu.New([]);
  LState := TMenuState.Default;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    LM.RenderStateful(TRect.Make(0, 0, 20, 3), LBuf, LState);
    CheckEqual(0, LM.ItemCount, 'empty menu item count');
    CheckEqual(0, LM.SelectableCount, 'empty selectable');
  finally LBuf.Free; end;
end;

procedure TestMenuMoveDownAtEndStays;
var LM: IMenu; LState: TMenuState;
begin
  LM := TMenu.New([TMenuItem.Action('Only')]);
  LState := TMenuState.Default;
  LM.MoveDown(LState);
  LM.MoveDown(LState);
  CheckEqual(0, LState.Selected, 'move down at end stays');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.widget.extended');
  T.Test('tree render', @TestTreeRender);
  T.Test('tree single root', @TestTreeSingleRoot);
  T.Test('tree indent', @TestTreeIndent);
  T.Test('dialog render', @TestDialogRender);
  T.Test('dialog with buttons', @TestDialogWithButtons);
  T.Test('dialog centered area', @TestDialogCenteredArea);
  T.Test('menu render', @TestMenuRender);
  T.Test('menu move down', @TestMenuMoveDown);
  T.Test('menu move up', @TestMenuMoveUp);
  T.Test('menu item count', @TestMenuItemCount);
  T.Test('menu shortcut', @TestMenuShortcut);
  T.Test('tree empty nodes', @TestTreeEmptyNodes);
  T.Test('tree small area', @TestTreeSmallArea);
  T.Test('dialog empty message', @TestDialogEmptyMessage);
  T.Test('menu empty items', @TestMenuEmptyItems);
  T.Test('menu move down at end stays', @TestMenuMoveDownAtEndStays);
if not T.Run then Halt(1);
end.
