program test_tui_widget_list;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.list,
  nextpas.core.test;
var T: TTestSuite;

procedure TestSimpleRender;
var LL: IListWidget; LBuf: TBuffer; LLines: TBufferLines;
begin
  LL := TListWidget.FromStrings(['alpha', 'beta', 'gamma']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LL.Render(TRect.Make(0, 0, 10, 3), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('alpha', LLines[0]) > 0, 'row 0 alpha');
    Check(Pos('beta', LLines[1]) > 0, 'row 1 beta');
    Check(Pos('gamma', LLines[2]) > 0, 'row 2 gamma');
  finally LBuf.Free; end;
end;

procedure TestStatefulSelection;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
    LLines: TBufferLines;
begin
  LL := TListWidget.FromStrings(['a', 'b', 'c'])
    .WithHighlightStyle(StyleDefault.WithFg(TUI_RED));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  LState := TListState.Empty;
  LState.Select(1);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 3), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('b', LLines[1]) > 0, 'selected row b');
  finally LBuf.Free; end;
end;

procedure TestScrollOffset;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
    LLines: TBufferLines;
begin
  { 5 items, area height 2, select item 4 -> should scroll }
  LL := TListWidget.FromStrings(['i0', 'i1', 'i2', 'i3', 'i4']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  LState := TListState.Empty;
  LState.Select(4);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 2), LBuf, LState);
    LLines := LBuf.AsLines;
    { 选中 item 4 -> 应可见 }
    Check(Pos('i4', LLines[1]) > 0, 'scrolled to i4');
    { offset 应被更新 }
    Check(LState.Offset >= 3, 'offset scrolled');
  finally LBuf.Free; end;
end;

procedure TestWithBlock;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
    LLines: TBufferLines;
begin
  LL := TListWidget.FromStrings(['x', 'y'])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 4));
  LState := TListState.Empty;
  try
    LL.RenderStateful(TRect.Make(0, 0, 6, 4), LBuf, LState);
    LLines := LBuf.AsLines;
    { 边框内应有 x }
    Check(Pos('x', LLines[1]) > 0, 'x inside block');
  finally LBuf.Free; end;
end;

procedure TestHighlightSymbol;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
    LLines: TBufferLines;
begin
  LL := TListWidget.FromStrings(['aa', 'bb'])
    .WithHighlightSymbol('> ');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 2));
  LState := TListState.Empty;
  LState.Select(0);
  try
    LL.RenderStateful(TRect.Make(0, 0, 8, 2), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('> ', LLines[0]) > 0, 'highlight symbol on selected');
    { 非选中行应有空白 gutter }
    Check(Pos('  ', LLines[1]) > 0, 'blank gutter on unselected');
  finally LBuf.Free; end;
end;

procedure TestAsIWidget;
var LW: IWidget; LBuf: TBuffer;
begin
  LW := TListWidget.FromStrings(['test']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    LW.Render(TRect.Make(0, 0, 8, 1), LBuf);
    Check(Pos('test', LBuf.RowAsString(0)) > 0, 'rendered via IWidget');
  finally LBuf.Free; end;
end;

procedure TestEmptyList;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
begin
  LL := TListWidget.FromStrings([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  LState := TListState.Empty;
  LState.Select(0);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 3), LBuf, LState);
    Check(not LState.HasSelection, 'empty list clears selection');
  finally LBuf.Free; end;
end;

procedure TestSingleItem;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
    LLines: TBufferLines;
begin
  LL := TListWidget.FromStrings(['only']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  LState := TListState.Empty;
  LState.Select(0);
  try
    LL.RenderStateful(TRect.Make(0, 0, 8, 1), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('only', LLines[0]) > 0, 'single item rendered');
    Check(LState.HasSelection, 'has selection');
  finally LBuf.Free; end;
end;

procedure TestSelectionBeyondRange;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
begin
  LL := TListWidget.FromStrings(['a', 'b']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  LState := TListState.Empty;
  LState.Select(99); // Beyond range
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 2), LBuf, LState);
    Check(True, 'selection beyond range does not crash');
  finally LBuf.Free; end;
end;

procedure TestWithHighlightStyle;
var LL: IListWidget; LBuf: TBuffer; LState: TListState;
begin
  LL := TListWidget.FromStrings(['x', 'y'])
    .WithHighlightStyle(StyleDefault.WithFg(TUI_RED));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  LState := TListState.Empty;
  LState.Select(0);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 2), LBuf, LState);
    Check(True, 'highlight style does not crash');
  finally LBuf.Free; end;
end;

procedure TestListStateNextPrevious;
var LState: TListState;
begin
  LState := TListState.Empty;
  LState.Select(0);
  LState.Next(5);
  Check(LState.Selected = 1, 'Next → index 1');
  LState.Next(5);
  Check(LState.Selected = 2, 'Next → index 2');
  LState.Previous;
  Check(LState.Selected = 1, 'Previous → index 1');
end;

procedure TestListStateFirstLast;
var LState: TListState;
begin
  LState := TListState.Empty;
  LState.Select(3);
  LState.First;
  Check(LState.Selected = 0, 'First → index 0');
  LState.Last(10);
  Check(LState.Selected = 9, 'Last(10) → index 9');
end;

procedure TestListStateClearSelection;
var LState: TListState;
begin
  LState := TListState.Empty;
  LState.Select(2);
  Check(LState.HasSelection, 'HasSelection after Select');
  LState.ClearSelection;
  Check(not LState.HasSelection, 'No selection after Clear');
end;

procedure TestListItemFromString;
var LItem: TListItem;
begin
  LItem := TListItem.FromString('hello');
  Check(LItem.Content = 'hello', 'FromString sets content');
end;

procedure TestListStateNextBoundary;
var LState: TListState;
begin
  LState := TListState.Empty;
  LState.Select(4);
  LState.Next(5); // at last item, Next should clamp
  Check(LState.Selected = 4, 'Next at boundary stays at 4');
end;

procedure TestListStatePreviousBoundary;
var LState: TListState;
begin
  LState := TListState.Empty;
  LState.Select(0);
  LState.Previous; // at first item, Previous should clamp
  Check(LState.Selected = 0, 'Previous at 0 stays at 0');
end;

{ PH33 P3：数据更新面——SetItems 原地替换列表内容 }
procedure TestListSetItems;
var LL: IListWidget; LBuf: TBuffer; LAll: AnsiString;
begin
  LL := TListWidget.FromStrings(['alpha', 'beta']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 3));
  try
    LL.SetItems([TListItem.FromString('x-ray'),
      TListItem.FromString('yankee'), TListItem.FromString('zulu')]);
    LL.Render(TRect.Make(0, 0, 12, 3), LBuf);
    LAll := LBuf.RowAsString(0) + LBuf.RowAsString(1) + LBuf.RowAsString(2);
    Check(Pos('x-ray', LAll) > 0, 'row 0 replaced');
    Check(Pos('zulu', LAll) > 0, 'row 2 zulu');
    Check(Pos('alpha', LAll) = 0, 'old alpha gone');
  finally LBuf.Free; end;
end;

procedure TestListWithItemsChaining;
var LL: IListWidget;
begin
  LL := TListWidget.FromStrings(['a'])
    .WithItems([TListItem.FromString('chained')]);
  Check(LL <> nil, 'WithItems chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.list');
  T.Test('simple render', @TestSimpleRender);
  T.Test('stateful selection', @TestStatefulSelection);
  T.Test('scroll offset', @TestScrollOffset);
  T.Test('with block', @TestWithBlock);
  T.Test('highlight symbol', @TestHighlightSymbol);
  T.Test('as IWidget', @TestAsIWidget);
  T.Test('empty list', @TestEmptyList);
  T.Test('single item', @TestSingleItem);
  T.Test('selection beyond range', @TestSelectionBeyondRange);
  T.Test('with highlight style', @TestWithHighlightStyle);
  T.Test('ListState Next/Previous', @TestListStateNextPrevious);
  T.Test('ListState First/Last', @TestListStateFirstLast);
  T.Test('ListState ClearSelection', @TestListStateClearSelection);
  T.Test('ListItem FromString', @TestListItemFromString);
  T.Test('ListState Next boundary', @TestListStateNextBoundary);
  T.Test('ListState Previous boundary', @TestListStatePreviousBoundary);
  T.Test('SetItems in-place update (PH33 P3)', @TestListSetItems);
  T.Test('WithItems chaining (PH33 P3)', @TestListWithItemsChaining);
  if not T.Run then Halt(1);
end.
