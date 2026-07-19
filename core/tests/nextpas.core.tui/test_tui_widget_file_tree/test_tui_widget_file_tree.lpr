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
  // With no nodes, SelectNext should not change Selected
  LState.SelectNext;
  Check(LState.Selected = 0, 'Should stay at 0 with no nodes');
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
  try
    LTree.Render(LArea, LBuf);
    Check(True, 'Should render file tree');
  finally
    LBuf.Free;
  end;
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
  try
    LTree.RenderStateful(LArea, LBuf, LState);
    Check(True, 'Should render stateful file tree');
  finally
    LBuf.Free;
  end;
end;

procedure TestFileTreeRenderEmpty;
var
  LTree: IFileTree;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LTree := TFileTree.New;
  LArea := TRect.Make(0, 0, 10, 5);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LTree.Render(LArea, LBuf);
    Check(True, 'Should render empty file tree');
  finally
    LBuf.Free;
  end;
end;

procedure TestFileTreeRenderSmallArea;
var
  LTree: IFileTree;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LTree := TFileTree.New;
  LArea := TRect.Make(0, 0, 3, 2);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LTree.Render(LArea, LBuf);
    Check(True, 'Should render in small area');
  finally
    LBuf.Free;
  end;
end;

procedure TestFileTreeStateSelectNextMultiple;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  // With no nodes, SelectNext should not crash
  LState.SelectNext;
  Check(LState.Selected = 0, 'Should stay at 0 with no nodes');
end;

procedure TestFileTreeStateSelectPrevMultiple;
var
  LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  LState.Selected := 5;
  LState.SelectPrev;
  LState.SelectPrev;
  LState.SelectPrev;
  Check(LState.Selected = 2, 'Should be at 2 after 3 SelectPrev from 5');
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
  T.Test('TFileTree.Render empty', @TestFileTreeRenderEmpty);
  T.Test('TFileTree.Render small area', @TestFileTreeRenderSmallArea);
  T.Test('TFileTreeState.SelectNext multiple', @TestFileTreeStateSelectNextMultiple);
  T.Test('TFileTreeState.SelectPrev multiple', @TestFileTreeStateSelectPrevMultiple);
  if not T.Run then Halt(1);
end.
