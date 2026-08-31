program test_tui_widget_file_tree;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.fs.base,
  nextpas.core.fs.dir,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
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

{ ===== PH33 P5b：LoadDir 真扫描 ===== }

const
  kFtFixture = '/tmp/nextpas_ft_p5b_test';

{ 夹具布局（先清后建，确定性）：
  kFtFixture/
    zeta.txt  Alpha.txt  beta.md  .hidden   （文件）
    adir/afile                          （目录+文件）
    bdir/nested.txt  bdir/csub/（空）    （目录+文件+空子目录） }
procedure FtBuildFixture;
begin
  FsRemoveAll(kFtFixture);            { 不存在视为成功 }
  FsMkdirAll(kFtFixture + '/adir');
  FsMkdirAll(kFtFixture + '/bdir/csub');
  FsWriteFileText(kFtFixture + '/zeta.txt', 'z');
  FsWriteFileText(kFtFixture + '/Alpha.txt', 'a');
  FsWriteFileText(kFtFixture + '/beta.md', 'b');
  FsWriteFileText(kFtFixture + '/.hidden', 'h');
  FsWriteFileText(kFtFixture + '/adir/afile', 'x');
  FsWriteFileText(kFtFixture + '/bdir/nested.txt', 'n');
end;

{ 单节点全字段断言 }
procedure FtExpect(const AState: TFileTreeState; AIdx: Integer;
  const AName: AnsiString; AIsDir: Boolean; ADepth: Integer; AExpanded: Boolean);
begin
  Check(AIdx < Length(AState.Nodes), 'node exists @' + IntToStr(AIdx));
  if AIdx >= Length(AState.Nodes) then Exit;
  Check(AState.Nodes[AIdx].Name = AName, 'name @' + IntToStr(AIdx) + '=' + AName);
  Check(AState.Nodes[AIdx].IsDir = AIsDir, 'isdir @' + IntToStr(AIdx));
  Check(AState.Nodes[AIdx].Depth = ADepth, 'depth @' + IntToStr(AIdx));
  Check(AState.Nodes[AIdx].Expanded = AExpanded, 'expanded @' + IntToStr(AIdx));
end;

procedure TestFileTreeLoadDirBasic;
var LState: TFileTreeState;
begin
  FtBuildFixture;
  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, 2, False), 'root readable');
  { DFS 先序：每层目录在前、同类 CompareText 升序；深度边界外收拢 }
  FtExpect(LState, 0, 'nextpas_ft_p5b_test', True, 0, True);
  FtExpect(LState, 1, 'adir', True, 1, True);
  FtExpect(LState, 2, 'afile', False, 2, False);
  FtExpect(LState, 3, 'bdir', True, 1, True);
  FtExpect(LState, 4, 'csub', True, 2, False);      { 边界外：诚实收拢 }
  FtExpect(LState, 5, 'nested.txt', False, 2, False);
  FtExpect(LState, 6, 'Alpha.txt', False, 1, False); { 大小写不敏感序 }
  FtExpect(LState, 7, 'beta.md', False, 1, False);
  FtExpect(LState, 8, 'zeta.txt', False, 1, False);
  Check(Length(LState.Nodes) = 9, 'hidden filtered: total 9 nodes');
end;

procedure TestFileTreeLoadDirDepth;
var LState: TFileTreeState;
begin
  FtBuildFixture;
  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, 0, False), 'depth0 readable');
  Check(Length(LState.Nodes) = 1, 'depth0 root only');
  Check(LState.Nodes[0].Expanded, 'depth0 root expanded');

  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, 1, False), 'depth1 readable');
  Check(Length(LState.Nodes) = 6, 'depth1: root + 2 dirs + 3 files');
  Check(LState.Nodes[1].Name = 'adir', 'dirs first @1');
  Check(not LState.Nodes[1].Expanded, 'boundary dir collapsed at depth1');
  Check(LState.Nodes[2].Name = 'bdir', 'dirs first @2');

  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, -3, False), 'negative depth clamps');
  Check(Length(LState.Nodes) = 1, 'negative depth = root only');
end;

procedure TestFileTreeLoadDirHidden;
var LState: TFileTreeState;
begin
  FtBuildFixture;
  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, 1, True), 'show-hidden readable');
  { 深度 1 全量：根 + 2 目录 + 4 文件（.hidden 放开）= 7 节点；
    文件段排序 '.' < 'A' < 'b' < 'z' }
  Check(Length(LState.Nodes) = 7, 'show-hidden total 7');
  FtExpect(LState, 3, '.hidden', False, 1, False);
  FtExpect(LState, 4, 'Alpha.txt', False, 1, False);
  FtExpect(LState, 6, 'zeta.txt', False, 1, False);
end;

procedure TestFileTreeLoadDirMissing;
var LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  Check(not LState.LoadDir('/tmp/nextpas_ft_p5b_missing_xyz', 2, False),
    'missing dir returns False');
  Check(Length(LState.Nodes) = 1, 'single collapsed root on failure');
  Check(LState.Nodes[0].Name = 'nextpas_ft_p5b_missing_xyz', 'root keeps basename');
  Check(not LState.Nodes[0].Expanded, 'failed root stays collapsed');
end;

procedure TestFileTreeLoadDirEmptyPath;
var LState: TFileTreeState;
begin
  LState := TFileTreeState.Empty;
  Check(not LState.LoadDir('', 2, False), 'empty path returns False');
  Check(Length(LState.Nodes) = 0, 'empty path: no nodes');
end;

procedure TestFileTreeLoadDirRender;
var LState: TFileTreeState; LBuf: TBuffer; LArea: TRect;
begin
  FtBuildFixture;
  LState := TFileTreeState.Empty;
  Check(LState.LoadDir(kFtFixture, 2, False), 'fixture readable');
  LArea := TRect.Make(0, 0, 30, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    TFileTree.New.RenderStateful(LArea, LBuf, LState);
    Check(Pos('adir', LBuf.RowAsString(1)) > 0, 'render shows real dir adir');
    Check(Pos('afile', LBuf.RowAsString(2)) > 0, 'render shows real file afile');
    Check(Pos('csub', LBuf.RowAsString(4)) > 0, 'render shows nested dir csub');
    Check(Pos('nested.txt', LBuf.RowAsString(5)) > 0, 'render shows nested file');
  finally LBuf.Free; end;
end;

procedure TestFileTreeCleanup;
begin
  FsRemoveAll(kFtFixture);
  Check(True, 'fixture removed');
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
  T.Test('LoadDir basic (PH33 P5b)', @TestFileTreeLoadDirBasic);
  T.Test('LoadDir depth clamp (PH33 P5b)', @TestFileTreeLoadDirDepth);
  T.Test('LoadDir hidden filter (PH33 P5b)', @TestFileTreeLoadDirHidden);
  T.Test('LoadDir missing dir (PH33 P5b)', @TestFileTreeLoadDirMissing);
  T.Test('LoadDir empty path (PH33 P5b)', @TestFileTreeLoadDirEmptyPath);
  T.Test('LoadDir render integration (PH33 P5b)', @TestFileTreeLoadDirRender);
  T.Test('LoadDir fixture cleanup (PH33 P5b)', @TestFileTreeCleanup);
  if not T.Run then Halt(1);
end.
