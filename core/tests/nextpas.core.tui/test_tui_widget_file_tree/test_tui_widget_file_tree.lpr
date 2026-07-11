program test_tui_widget_file_tree;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.file_tree,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFileTreeStateEmpty;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  Check(LState.Selected = 0, 'Should start at index 0');
end;

procedure TestFileTreeStateToggleExpand;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  LState.ToggleExpand;
  Check(True, 'Should toggle expand without error');
end;

procedure TestFileTreeStateSelectNext;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  LState.SelectNext;
  Check(LState.Selected = 1, 'Should move to 1');
end;

procedure TestFileTreeStateSelectPrev;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  LState.Selected := 3;
  LState.SelectPrev;
  Check(LState.Selected = 2, 'Should move to 2');
end;

procedure TestFileTreeStateSelectPrevBoundary;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  LState.SelectPrev;
  Check(LState.Selected = 0, 'Should stay at 0');
end;

procedure TestFileTreeNew;
var
  LTree: IFileTree;
begin
  LTree := TFileTree.New;
  Check(LTree <> nil, 'Should create file tree instance');
end;

procedure TestFileTreeWithStyle;
var
  LTree: IFileTree;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LTree := TFileTree.New.WithStyle(LStyle);
  Check(LTree <> nil, 'Should set style');
end;

procedure TestFileTreeWithDirStyle;
var
  LTree: IFileTree;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LTree := TFileTree.New.WithDirStyle(LStyle);
  Check(LTree <> nil, 'Should set dir style');
end;

procedure TestFileTreeWithFileStyle;
var
  LTree: IFileTree;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LTree := TFileTree.New.WithFileStyle(LStyle);
  Check(LTree <> nil, 'Should set file style');
end;

procedure TestFileTreeWithSelectedStyle;
var
  LTree: IFileTree;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(4);
  LTree := TFileTree.New.WithSelectedStyle(LStyle);
  Check(LTree <> nil, 'Should set selected style');
end;

procedure TestFileTreeRender;
var
  LTree: IFileTree;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LTree := TFileTree.New;
  LArea := TRect.Make(0, 0, 30, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LTree.Render(LArea, LBuf);
  Check(True, 'Should render file tree');
end;

procedure TestFileTreeRenderStateful;
var
  LTree: IFileTree;
  LState: TFileTreeState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LTree := TFileTree.New;
  LState := TFileTreeState.Empty;
  LArea := TRect.Make(0, 0, 30, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LTree.RenderStateful(LArea, LBuf, LState);
  Check(True, 'Should render stateful file tree');
end;

procedure TestFileTreeBuilderChaining;
var
  LTree: IFileTree;
  LStyle, LDirStyle, LFileStyle, LSelectedStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LDirStyle.Fg := IndexedColor(2);
  LFileStyle.Fg := IndexedColor(3);
  LSelectedStyle.Fg := IndexedColor(4);
  LTree := TFileTree.New
    .WithStyle(LStyle)
    .WithDirStyle(LDirStyle)
    .WithFileStyle(LFileStyle)
    .WithSelectedStyle(LSelectedStyle);
  Check(LTree <> nil, 'Should chain builder calls');
end;

begin
  T := TTestSuite.Create('tui_widget_file_tree');
  T.Test('TFileTreeState.Empty', @TestFileTreeStateEmpty);
  T.Test('TFileTreeState.ToggleExpand', @TestFileTreeStateToggleExpand);
  T.Test('TFileTreeState.SelectNext', @TestFileTreeStateSelectNext);
  T.Test('TFileTreeState.SelectPrev', @TestFileTreeStateSelectPrev);
  T.Test('TFileTreeState.SelectPrev boundary', @TestFileTreeStateSelectPrevBoundary);
  T.Test('TFileTree.New creates instance', @TestFileTreeNew);
  T.Test('TFileTree.WithStyle', @TestFileTreeWithStyle);
  T.Test('TFileTree.WithDirStyle', @TestFileTreeWithDirStyle);
  T.Test('TFileTree.WithFileStyle', @TestFileTreeWithFileStyle);
  T.Test('TFileTree.WithSelectedStyle', @TestFileTreeWithSelectedStyle);
  T.Test('TFileTree.Render', @TestFileTreeRender);
  T.Test('TFileTree.RenderStateful', @TestFileTreeRenderStateful);
  T.Test('TFileTree builder chaining', @TestFileTreeBuilderChaining);
  if not T.Run then Halt(1);
end.
