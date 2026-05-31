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
  nextpas.core.testing;
var T: TTestRunner;

procedure TestSimpleRender;
var LL: ITuiList; LBuf: TBuffer; LLines: TBufferLines;
begin
  LL := TTuiList.FromStrings(['alpha', 'beta', 'gamma']);
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
var LL: ITuiList; LBuf: TBuffer; LState: TTuiListState;
    LLines: TBufferLines;
begin
  LL := TTuiList.FromStrings(['a', 'b', 'c'])
    .WithHighlightStyle(StyleDefault.WithFg(TUI_RED));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  LState := TTuiListState.Empty;
  LState.Select(1);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 3), LBuf, LState);
    LLines := LBuf.AsLines;
    Check(Pos('b', LLines[1]) > 0, 'selected row b');
  finally LBuf.Free; end;
end;

procedure TestScrollOffset;
var LL: ITuiList; LBuf: TBuffer; LState: TTuiListState;
    LLines: TBufferLines;
begin
  { 5 items, area height 2, select item 4 -> should scroll }
  LL := TTuiList.FromStrings(['i0', 'i1', 'i2', 'i3', 'i4']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  LState := TTuiListState.Empty;
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
var LL: ITuiList; LBuf: TBuffer; LState: TTuiListState;
    LLines: TBufferLines;
begin
  LL := TTuiList.FromStrings(['x', 'y'])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 4));
  LState := TTuiListState.Empty;
  try
    LL.RenderStateful(TRect.Make(0, 0, 6, 4), LBuf, LState);
    LLines := LBuf.AsLines;
    { 边框内应有 x }
    Check(Pos('x', LLines[1]) > 0, 'x inside block');
  finally LBuf.Free; end;
end;

procedure TestHighlightSymbol;
var LL: ITuiList; LBuf: TBuffer; LState: TTuiListState;
    LLines: TBufferLines;
begin
  LL := TTuiList.FromStrings(['aa', 'bb'])
    .WithHighlightSymbol('> ');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 2));
  LState := TTuiListState.Empty;
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
  LW := TTuiList.FromStrings(['test']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    LW.Render(TRect.Make(0, 0, 8, 1), LBuf);
    Check(Pos('test', LBuf.RowAsString(0)) > 0, 'rendered via IWidget');
  finally LBuf.Free; end;
end;

procedure TestEmptyList;
var LL: ITuiList; LBuf: TBuffer; LState: TTuiListState;
begin
  LL := TTuiList.FromStrings([]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  LState := TTuiListState.Empty;
  LState.Select(0);
  try
    LL.RenderStateful(TRect.Make(0, 0, 5, 3), LBuf, LState);
    Check(not LState.HasSelection, 'empty list clears selection');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.list');
  T.Run('simple render', @TestSimpleRender);
  T.Run('stateful selection', @TestStatefulSelection);
  T.Run('scroll offset', @TestScrollOffset);
  T.Run('with block', @TestWithBlock);
  T.Run('highlight symbol', @TestHighlightSymbol);
  T.Run('as IWidget', @TestAsIWidget);
  T.Run('empty list', @TestEmptyList);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
