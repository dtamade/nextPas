program test_tui_widget_complex;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.diffview,
  nextpas.core.tui.widget.file_tree,
  nextpas.core.tui.widget.kanban,
  nextpas.core.tui.widget.markdown,
  nextpas.core.tui.widget.virtual_list,
  nextpas.core.tui.widget.notification_center,
  nextpas.core.tui.widget.toast,
  nextpas.core.testing;
var T: TTestRunner;

{ === TDiffView === }

procedure TestDiffViewNew;
var LD: IDiffView; LBuf: TBuffer; LSt: TDiffViewState;
    Lines: array[0..2] of TDiffLine;
begin
  Lines[0].Kind := dlHeader; Lines[0].Text := '@@ -1,3 +1,3 @@';
  Lines[0].OldNum := 0; Lines[0].NewNum := 0;
  Lines[1].Kind := dlRemoved; Lines[1].Text := 'old line';
  Lines[1].OldNum := 1; Lines[1].NewNum := 0;
  Lines[2].Kind := dlAdded; Lines[2].Text := 'new line';
  Lines[2].OldNum := 0; Lines[2].NewNum := 1;
  LD := TDiffView.New(Lines);
  LSt := TDiffViewState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LD.RenderStateful(TRect.Make(0, 0, 40, 10), LBuf, LSt);
    Check(True, 'diffview renders');
  finally LBuf.Free; end;
end;

procedure TestDiffViewFromUnified;
var LD: IDiffView; LBuf: TBuffer; LSt: TDiffViewState;
begin
  LD := TDiffView.FromUnifiedDiff(
    '--- a/file.pas' + #10 +
    '+++ b/file.pas' + #10 +
    '@@ -1,2 +1,2 @@' + #10 +
    '-old' + #10 +
    '+new' + #10);
  LSt := TDiffViewState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LD.RenderStateful(TRect.Make(0, 0, 40, 10), LBuf, LSt);
    Check(True, 'diffview from unified renders');
  finally LBuf.Free; end;
end;

{ === TFileTree === }

procedure TestFileTreeRender;
var LF: IFileTree; LBuf: TBuffer; LSt: TFileTreeState;
begin
  LF := TFileTree.New;
  LSt := TFileTreeState.Empty;
  LSt.AddNode('src', True, 0);
  LSt.AddNode('main.pas', False, 1);
  LSt.AddNode('utils.pas', False, 1);
  LSt.AddNode('tests', True, 0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    LF.RenderStateful(TRect.Make(0, 0, 30, 10), LBuf, LSt);
    Check(Pos('src', LBuf.RowAsString(0)) > 0, 'file tree shows dir');
  finally LBuf.Free; end;
end;

procedure TestFileTreeNavigation;
var LSt: TFileTreeState;
begin
  LSt := TFileTreeState.Empty;
  LSt.AddNode('dir1', True, 0);
  LSt.AddNode('file1', False, 1);
  LSt.AddNode('file2', False, 1);
  CheckEqual(0, LSt.Selected, 'initial selection');
  LSt.SelectNext;
  CheckEqual(1, LSt.Selected, 'select next');
  LSt.SelectPrev;
  CheckEqual(0, LSt.Selected, 'select prev');
end;

{ === TKanban === }

procedure TestKanbanRender;
var LK: IKanban; LBuf: TBuffer; LSt: TKanbanState;
begin
  LK := TKanban.New([
    MakeColumn('Todo', [TKanbanCard.Make('Task 1'), TKanbanCard.Make('Task 2')]),
    MakeColumn('Done', [TKanbanCard.Make('Task 3')])
  ]);
  LSt := TKanbanState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LK.RenderStateful(TRect.Make(0, 0, 40, 10), LBuf, LSt);
    Check(True, 'kanban renders');
  finally LBuf.Free; end;
end;

procedure TestKanbanNavigation;
var LSt: TKanbanState;
begin
  LSt := TKanbanState.Empty;
  CheckEqual(0, LSt.ActiveCol, 'initial col');
  LSt.MoveRight(3);
  CheckEqual(1, LSt.ActiveCol, 'move right');
  LSt.MoveLeft;
  CheckEqual(0, LSt.ActiveCol, 'move left');
  LSt.MoveDown(5);
  CheckEqual(1, LSt.ActiveCard, 'move down');
  LSt.MoveUp;
  CheckEqual(0, LSt.ActiveCard, 'move up');
end;

{ === TMarkdown === }

procedure TestMarkdownRender;
var LM: IMarkdown; LBuf: TBuffer;
begin
  LM := TMarkdown.New('# Hello' + #10 + 'Some text' + #10 + '- item1');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 5));
  try
    (LM as IWidget).Render(TRect.Make(0, 0, 30, 5), LBuf);
    Check(Pos('Hello', LBuf.RowAsString(0)) > 0, 'markdown renders heading');
  finally LBuf.Free; end;
end;

procedure TestMarkdownEmpty;
var LM: IMarkdown; LBuf: TBuffer;
begin
  LM := TMarkdown.New('');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    (LM as IWidget).Render(TRect.Make(0, 0, 20, 3), LBuf);
    Check(True, 'empty markdown renders');
  finally LBuf.Free; end;
end;

{ === TVirtualList === }

function VListProvider(Index: Integer): AnsiString;
begin
  Result := 'Item ' + IntToStr(Index);
end;

procedure TestVirtualListRender;
var LV: IVirtualList; LBuf: TBuffer; LSt: TVirtualListState;
begin
  LV := TVirtualList.New(@VListProvider);
  LSt := TVirtualListState.Create(100);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    LV.RenderStateful(TRect.Make(0, 0, 20, 5), LBuf, LSt);
    Check(Pos('Item 0', LBuf.RowAsString(0)) > 0, 'virtual list shows first item');
  finally LBuf.Free; end;
end;

procedure TestVirtualListNavigation;
var LSt: TVirtualListState;
begin
  LSt := TVirtualListState.Create(50);
  CheckEqual(0, LSt.Selected, 'initial selected');
  LSt.SelectNext;
  CheckEqual(1, LSt.Selected, 'select next');
  LSt.SelectLast;
  CheckEqual(49, LSt.Selected, 'select last');
  LSt.SelectFirst;
  CheckEqual(0, LSt.Selected, 'select first');
end;

{ === TNotificationCenter === }

procedure TestNotificationCenterPush;
var LN: INotificationCenter;
begin
  LN := TNotificationCenter.New;
  LN.Push(TNotification.Make('Hello', nlInfo));
  LN.Push(TNotification.Make('Warning', nlWarning));
  CheckEqual(2, LN.Count, 'count after push');
  CheckEqual(2, LN.UnreadCount, 'unread count');
  LN.MarkRead(0);
  CheckEqual(1, LN.UnreadCount, 'unread after mark');
end;

procedure TestNotificationCenterRender;
var LN: INotificationCenter; LBuf: TBuffer;
    LSt: TNotificationCenterState;
begin
  LN := TNotificationCenter.New;
  LN.Push(TNotification.Make('Test', nlInfo));
  LSt.Selected := 0; LSt.ScrollY := 0; LSt.Visible := True;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 50, 10));
  try
    LN.RenderStateful(TRect.Make(0, 0, 50, 10), LBuf, LSt);
    Check(True, 'notification center renders');
  finally LBuf.Free; end;
end;

{ === TToastManager === }

procedure TestToastPushAndTick;
var LT: IToastManager;
begin
  LT := TToastManager.New;
  LT.Push('Hello', tlInfo);
  LT.Push('Error', tlError);
  CheckEqual(2, LT.Count, 'count after push');
  LT.Tick(4000);
  CheckEqual(0, LT.Count, 'count after tick expires all');
end;

procedure TestToastRender;
var LT: IToastManager; LBuf: TBuffer;
begin
  LT := TToastManager.New;
  LT.Push('Saved', tlSuccess);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 50, 5));
  try
    (LT as IWidget).Render(TRect.Make(0, 0, 50, 5), LBuf);
    Check(True, 'toast renders');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.complex');
  T.Run('diffview new', @TestDiffViewNew);
  T.Run('diffview from unified', @TestDiffViewFromUnified);
  T.Run('file tree render', @TestFileTreeRender);
  T.Run('file tree navigation', @TestFileTreeNavigation);
  T.Run('kanban render', @TestKanbanRender);
  T.Run('kanban navigation', @TestKanbanNavigation);
  T.Run('markdown render', @TestMarkdownRender);
  T.Run('markdown empty', @TestMarkdownEmpty);
  T.Run('virtual list render', @TestVirtualListRender);
  T.Run('virtual list navigation', @TestVirtualListNavigation);
  T.Run('notification center push', @TestNotificationCenterPush);
  T.Run('notification center render', @TestNotificationCenterRender);
  T.Run('toast push and tick', @TestToastPushAndTick);
  T.Run('toast render', @TestToastRender);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
