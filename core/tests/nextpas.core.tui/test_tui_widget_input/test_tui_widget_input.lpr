program test_tui_widget_input;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.input,
  nextpas.core.test;

var T: TTestSuite;

{ === TInputState === }

procedure TestInputStateEmpty;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  Check(LS.Text = '', 'empty state has empty text');
  Check(LS.Cursor = 0, 'empty state cursor at 0');
  Check(LS.ScrollX = 0, 'empty state scroll at 0');
end;

procedure TestInputStateWithText;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello');
  Check(LS.Text = 'hello', 'state has text hello');
  Check(LS.Cursor = 5, 'cursor at end');
end;

procedure TestInputStateInsertChar;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  LS.InsertChar(Ord('a'));
  Check(LS.Text = 'a', 'insert a');
  Check(LS.Cursor = 1, 'cursor at 1');
  LS.InsertChar(Ord('b'));
  Check(LS.Text = 'ab', 'insert b');
  Check(LS.Cursor = 2, 'cursor at 2');
end;

procedure TestInputStateInsertStr;
var LS: TInputState;
begin
  LS := TInputState.Empty;
  LS.InsertStr('hello');
  Check(LS.Text = 'hello', 'insert hello');
  Check(LS.Cursor = 5, 'cursor at 5');
end;

procedure TestInputStateDeleteBack;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.DeleteBack;
  Check(LS.Text = 'ab', 'delete back from abc');
  Check(LS.Cursor = 2, 'cursor at 2');
  LS.DeleteBack;
  Check(LS.Text = 'a', 'delete back from ab');
  Check(LS.Cursor = 1, 'cursor at 1');
  LS.DeleteBack;
  Check(LS.Text = '', 'delete back from a');
  Check(LS.Cursor = 0, 'cursor at 0');
  LS.DeleteBack;
  Check(LS.Text = '', 'delete back from empty is noop');
end;

procedure TestInputStateDeleteForward;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LS.DeleteForward;
  Check(LS.Text = 'ac', 'delete forward from middle');
  Check(LS.Cursor = 1, 'cursor stays');
  LS.DeleteForward;
  Check(LS.Text = 'a', 'delete forward from end-1');
  LS.DeleteForward;
  Check(LS.Text = 'a', 'delete forward at end is noop');
end;

procedure TestInputStateMoveLeft;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.MoveLeft;
  Check(LS.Cursor = 2, 'move left from 3');
  LS.MoveLeft;
  Check(LS.Cursor = 1, 'move left from 2');
  LS.MoveLeft;
  Check(LS.Cursor = 0, 'move left from 1');
  LS.MoveLeft;
  Check(LS.Cursor = 0, 'move left from 0 stays');
end;

procedure TestInputStateMoveRight;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 0;
  LS.MoveRight;
  Check(LS.Cursor = 1, 'move right from 0');
  LS.MoveRight;
  Check(LS.Cursor = 2, 'move right from 1');
  LS.MoveRight;
  Check(LS.Cursor = 3, 'move right from 2');
  LS.MoveRight;
  Check(LS.Cursor = 3, 'move right from 3 stays');
end;

procedure TestInputStateMoveHome;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.MoveHome;
  Check(LS.Cursor = 0, 'move home');
end;

procedure TestInputStateMoveEnd;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  LS.MoveEnd;
  Check(LS.Cursor = 3, 'move end');
end;

{ === TInputState 词操作（Ctrl+←/→/Backspace/Delete） === }

procedure TestInputStateMoveWordLeft;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello world');
  LS.MoveWordLeft;
  Check(LS.Cursor = 6, 'word left from end lands on prior word start');
  LS.MoveWordLeft;
  Check(LS.Cursor = 0, 'word left from word start lands on first word');
  LS.MoveWordLeft;
  Check(LS.Cursor = 0, 'word left at start stays');
  LS := TInputState.WithText('hello  world');
  LS.MoveWordLeft;
  Check(LS.Cursor = 7, 'word left skips runs of blanks');
end;

procedure TestInputStateMoveWordRight;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello world');
  LS.Cursor := 0;
  LS.MoveWordRight;
  Check(LS.Cursor = 5, 'word right from start lands just past word');
  LS.MoveWordRight;
  Check(LS.Cursor = 11, 'word right from between lands at end');
  LS.MoveWordRight;
  Check(LS.Cursor = 11, 'word right at end stays');
end;

procedure TestInputStateDeleteWordLeft;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello world');
  LS.DeleteWordLeft;
  CheckEqual('hello ', LS.Text, 'word left delete keeps separator blank');
  Check(LS.Cursor = 6, 'word left delete cursor lands after blank');
  LS.DeleteWordLeft;
  CheckEqual('', LS.Text, 'word left delete removes last word');
  Check(LS.Cursor = 0, 'word left delete cursor at start');
  LS.DeleteWordLeft;
  CheckEqual('', LS.Text, 'word left delete at start is noop');
end;

procedure TestInputStateDeleteWordRight;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello world');
  LS.Cursor := 0;
  LS.DeleteWordRight;
  CheckEqual(' world', LS.Text, 'word right delete keeps leading blank');
  Check(LS.Cursor = 0, 'word right delete cursor stays');
  LS := TInputState.WithText('hello world');
  LS.Cursor := 6;
  LS.DeleteWordRight;
  CheckEqual('hello ', LS.Text, 'word right delete keeps separator blank');
  LS := TInputState.Empty;
  LS.DeleteWordRight;
  CheckEqual('', LS.Text, 'word right delete at end is noop');
end;

procedure TestInputStateHandleKeyCtrlWords;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('hello world');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcLeft;
  KE.Modifiers := [kmCtrl];
  Check(LS.HandleKey(KE), 'ctrl+left handled');
  Check(LS.Cursor = 6, 'ctrl+left jumps word');
  LS := TInputState.WithText('hello world');
  LS.Cursor := 0;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcRight;
  KE.Modifiers := [kmCtrl];
  LS.HandleKey(KE);
  Check(LS.Cursor = 5, 'ctrl+right from start jumps past word');
  LS := TInputState.WithText('hello world');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  KE.Modifiers := [kmCtrl];
  Check(LS.HandleKey(KE), 'ctrl+backspace handled');
  CheckEqual('hello ', LS.Text, 'ctrl+backspace deletes word left');
  LS := TInputState.WithText('hello world');
  LS.Cursor := 0;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcDelete;
  KE.Modifiers := [kmCtrl];
  LS.HandleKey(KE);
  CheckEqual(' world', LS.Text, 'ctrl+delete deletes word right');
  LS := TInputState.WithText('hello world');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcLeft;
  KE.Modifiers := [kmCtrl, kmShift];
  LS.HandleKey(KE);
  Check(LS.Cursor = 6, 'ctrl+shift+left still jumps word');
end;

procedure TestInputStateCursorCol;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  Check(LS.CursorCol = 3, 'cursor col at end');
  LS.Cursor := 1;
  Check(LS.CursorCol = 1, 'cursor col at 1');
end;

procedure TestInputStateTextWidth;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  Check(LS.TextWidth = 3, 'text width of abc');
  LS := TInputState.Empty;
  Check(LS.TextWidth = 0, 'text width of empty');
end;

{ === IInput Builders === }

procedure TestInputNew;
var LI: IInput;
begin
  LI := TInput.New;
  Check(LI <> nil, 'TInput.New returns non-nil');
end;

procedure TestInputWithPlaceholder;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithPlaceholder('type here');
  LS := TInputState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('type here', LRow) > 0, 'placeholder visible when empty');
  finally LBuf.Free; end;
end;

procedure TestInputPlaceholderHidden;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithPlaceholder('type here');
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('hello', LRow) > 0, 'text visible');
    Check(Pos('type here', LRow) = 0, 'placeholder hidden when text exists');
  finally LBuf.Free; end;
end;

procedure TestInputWithMask;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LRow: AnsiString;
begin
  LI := TInput.New.WithMask('*');
  LS := TInputState.WithText('secret');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    LRow := LBuf.RowAsString(0);
    Check(Pos('secret', LRow) = 0, 'original text hidden');
    Check(Pos('*', LRow) > 0, 'mask char visible');
  finally LBuf.Free; end;
end;

procedure TestInputWithStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithStyle(TStyle.Default.WithFg(IndexedColor(1)));
  LS := TInputState.WithText('styled');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'styled input renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithPlaceholderStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New
    .WithPlaceholder('hint')
    .WithPlaceholderStyle(TStyle.Default.WithFg(IndexedColor(8)));
  LS := TInputState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'input with placeholder style renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithCursorStyle;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithCursorStyle(TStyle.Default.WithBg(IndexedColor(4)));
  LS := TInputState.WithText('abc');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(True, 'input with cursor style renders');
  finally LBuf.Free; end;
end;

procedure TestInputWithBlock;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithBlock(TBlock.New.WithTitle('Name'));
  LS := TInputState.WithText('hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 3), LBuf, LS);
    Check(True, 'input with block renders');
  finally LBuf.Free; end;
end;

procedure TestInputRenderInline;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New;
  LS := TInputState.WithText('inline');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderInline(LBuf, 0, 0, 20, LS);
    Check(True, 'inline render works');
  finally LBuf.Free; end;
end;

procedure TestInputAsIWidget;
var LI: IInput; LW: IWidget;
begin
  LI := TInput.New;
  LW := LI as IWidget;
  Check(LW <> nil, 'IInput casts to IWidget');
end;

{ === TInputState.HandleKey === }

procedure TestInputStateHandleKeyChar;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.Empty;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcChar;
  KE.Ch := Ord('x');
  Check(LS.HandleKey(KE), 'handle key returns true');
  Check(LS.Text = 'x', 'char inserted');
end;

procedure TestInputStateHandleKeyBackspace;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('ab');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  Check(LS.HandleKey(KE), 'handle backspace');
  Check(LS.Text = 'a', 'char deleted');
end;

procedure TestInputStateHandleKeyLeft;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcLeft;
  LS.HandleKey(KE);
  Check(LS.Cursor = 2, 'cursor moved left');
end;

procedure TestInputStateHandleKeyRight;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcRight;
  LS.HandleKey(KE);
  Check(LS.Cursor = 2, 'cursor moved right');
end;

procedure TestInputStateHandleKeyHome;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcHome;
  LS.HandleKey(KE);
  Check(LS.Cursor = 0, 'cursor at home');
end;

procedure TestInputStateHandleKeyEnd;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcEnd;
  LS.HandleKey(KE);
  Check(LS.Cursor = 3, 'cursor at end');
end;

procedure TestInputStateHandleKeyDelete;
var LS: TInputState; KE: TKeyEvent;
begin
  LS := TInputState.WithText('abc');
  LS.Cursor := 1;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcDelete;
  LS.HandleKey(KE);
  Check(LS.Text = 'ac', 'forward delete');
end;

{ === 选区(鼠标拖选/Shift 扩展/双击词/全选) === }

procedure TestSelectionBeginUpdate;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello world');
  Check(not LS.HasSelection, 'no selection initially');
  LS.BeginSelect(6);
  Check(not LS.HasSelection, 'anchor=head is not a selection');
  LS.UpdateSelect(11);
  Check(LS.HasSelection, 'anchor<>head has selection');
  Check(LS.SelFrom = 6, 'sel from 6');
  Check(LS.SelTo = 11, 'sel to 11');
  LS.ClearSelection;
  Check(not LS.HasSelection, 'cleared');
end;

procedure TestSelectionReversed;
var LS: TInputState;
begin
  { 反向拖拽(从右往左):From/To 归一化 }
  LS := TInputState.WithText('hello world');
  LS.BeginSelect(11);
  LS.UpdateSelect(6);
  Check(LS.SelFrom = 6, 'reversed from still 6');
  Check(LS.SelTo = 11, 'reversed to still 11');
  CheckEqual('world', LS.SelectedText, 'reversed selected text');
end;

procedure TestSelectionSelectedText;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello');
  CheckEqual('', LS.SelectedText, 'no selection empty text');
  LS.BeginSelect(1);
  LS.UpdateSelect(3);
  CheckEqual('el', LS.SelectedText, 'utf8-safe byte slice');
  LS := TInputState.WithText('你好世界');
  LS.BeginSelect(0);
  LS.UpdateSelect(3);
  CheckEqual('你', LS.SelectedText, 'cjk single char selection');
end;

procedure TestSelectionDelete;
var LS: TInputState; LHad: Boolean;
begin
  LS := TInputState.WithText('hello world');
  LHad := LS.DeleteSelection;
  Check(not LHad, 'no selection delete returns false');
  CheckEqual('hello world', LS.Text, 'text untouched');
  LS.BeginSelect(5);
  LS.UpdateSelect(11);
  LHad := LS.DeleteSelection;
  Check(LHad, 'delete returns true with selection');
  CheckEqual('hello', LS.Text, 'tail removed');
  Check(LS.Cursor = 5, 'cursor lands at from');
  Check(not LS.HasSelection, 'selection cleared after delete');
end;

procedure TestSelectionInsertReplaces;
var LS: TInputState;
begin
  { 标准编辑器语义:输入/粘贴替换选区 }
  LS := TInputState.WithText('hello world');
  LS.BeginSelect(0);
  LS.UpdateSelect(5);
  LS.InsertChar(Ord('X'));
  CheckEqual('X world', LS.Text, 'typing replaces selection');
  Check(LS.Cursor = 1, 'cursor after replacement');
  Check(not LS.HasSelection, 'selection consumed');
  LS := TInputState.WithText('hello world');
  LS.BeginSelect(6);
  LS.UpdateSelect(11);
  LS.InsertStr('there');
  CheckEqual('hello there', LS.Text, 'paste replaces selection');
end;

procedure TestSelectionWordAt;
var LS: TInputState;
begin
  LS := TInputState.WithText('foo bar baz');
  Check(LS.SelectWordAt(0), 'click inside word selects');
  Check(LS.SelFrom = 0, 'word from start');
  Check(LS.SelTo = 3, 'word to end');
  Check(LS.Cursor = 3, 'cursor lands at word end (neovim style)');
  Check(LS.SelectWordAt(5), 'second word');
  Check(LS.SelFrom = 4, 'second word from');
  Check(LS.SelTo = 7, 'second word to');
  Check(not LS.SelectWordAt(3), 'click on blank refuses');
  Check(LS.SelectWordAt(100), 'click past tail falls back to last word');
  Check(LS.SelFrom = 8, 'past-tail selects last word from');
  Check(LS.SelTo = 11, 'past-tail selects last word to');
  LS := TInputState.Empty;
  Check(not LS.SelectWordAt(0), 'empty text refuses');
  { CJK 无空格连续串视为一个词 }
  LS := TInputState.WithText('你好世界');
  Check(LS.SelectWordAt(3), 'cjk click selects');
  Check(LS.SelFrom = 0, 'cjk word from start');
  Check(LS.SelTo = 12, 'cjk word to text length');
end;

procedure TestSelectionSelectAll;
var LS: TInputState;
begin
  LS := TInputState.WithText('hello');
  LS.SelectAll;
  Check(LS.HasSelection, 'select all has selection');
  CheckEqual('hello', LS.SelectedText, 'select all content');
  LS := TInputState.Empty;
  LS.SelectAll;
  Check(not LS.HasSelection, 'empty select all noop');
end;

procedure TestColToBytePos;
var LS: TInputState;
begin
  LS := TInputState.WithText('abc');
  Check(LS.ColToBytePos(0) = 0, 'col 0 at 0');
  Check(LS.ColToBytePos(1) = 1, 'col 1 at 1');
  Check(LS.ColToBytePos(2) = 2, 'col 2 at 2');
  Check(LS.ColToBytePos(3) = 3, 'col at tail');
  Check(LS.ColToBytePos(100) = 3, 'beyond tail clamps to end');
  Check(LS.ColToBytePos(-1) = 0, 'negative clamps to 0');
  LS := TInputState.WithText('ab你');
  Check(LS.ColToBytePos(2) = 2, 'wide char col start');
  Check(LS.ColToBytePos(3) = 2, 'wide char middle clamps to its head');
  Check(LS.ColToBytePos(4) = 5, 'after wide char');
  LS := TInputState.Empty;
  Check(LS.ColToBytePos(5) = 0, 'empty text maps to 0');
end;

procedure TestHandleKeyShiftExtend;
var LS: TInputState; KE: TKeyEvent;
begin
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcLeft;
  KE.Modifiers := [kmShift];
  LS := TInputState.WithText('abc');
  LS.HandleKey(KE);
  Check(LS.HasSelection, 'shift+left starts selection at cursor');
  CheckEqual('c', LS.SelectedText, 'one char selected');
  LS.HandleKey(KE);
  CheckEqual('bc', LS.SelectedText, 'extends over b');
  Check(LS.Cursor = 1, 'head moved to 1');
  KE.Modifiers := [];
  LS.HandleKey(KE);
  Check(not LS.HasSelection, 'plain left collapses selection');
  Check(LS.Cursor = 0, 'and moves normally');
  { Shift+Home 全选到行首 }
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcHome;
  KE.Modifiers := [kmShift];
  LS := TInputState.WithText('abc');
  LS.Cursor := 2;
  LS.HandleKey(KE);
  CheckEqual('ab', LS.SelectedText, 'shift+home selects to start');
  { Ctrl+Shift+Right 按词扩展 }
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcRight;
  KE.Modifiers := [kmCtrl, kmShift];
  LS := TInputState.WithText('foo bar');
  LS.Cursor := 0;
  LS.HandleKey(KE);
  CheckEqual('foo', LS.SelectedText, 'ctrl+shift+right extends by word');
end;

procedure TestHandleKeyDeleteSelectionKeys;
var LS: TInputState; KE: TKeyEvent;
begin
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  LS := TInputState.WithText('hello world');
  LS.BeginSelect(5);
  LS.UpdateSelect(11);
  LS.HandleKey(KE);
  CheckEqual('hello', LS.Text, 'backspace deletes whole selection');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcDelete;
  LS := TInputState.WithText('hello world');
  LS.BeginSelect(0);
  LS.UpdateSelect(5);
  LS.HandleKey(KE);
  CheckEqual(' world', LS.Text, 'delete key deletes whole selection');
  Check(LS.Cursor = 0, 'cursor at from');
end;

procedure TestRenderHighlight;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New;
  LS := TInputState.WithText('abcdef');
  LS.BeginSelect(1);
  LS.UpdateSelect(4);   { 选 bcde,列 1..3 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(not (mbReversed in LBuf.CellAt(0, 0)^.Modifier), 'before range plain');
    Check(mbReversed in LBuf.CellAt(1, 0)^.Modifier, 'range start highlighted');
    Check(mbReversed in LBuf.CellAt(3, 0)^.Modifier, 'range last highlighted');
    Check(not (mbReversed in LBuf.CellAt(4, 0)^.Modifier), 'after range plain');
  finally LBuf.Free; end;
end;

procedure TestRenderHighlightClipsToViewport;
var LI: IInput; LBuf: TBuffer; LS: TInputState; LI2: Integer;

  function CellSel(ABuf: TBuffer; AX, AY: Integer): Boolean;
  var LC: PCell;
  begin
    LC := ABuf.CellAt(AX, AY);
    Result := (LC <> nil) and (LC^.Bg.Kind = ckIndexed) and (LC^.Bg.Index = 5);
  end;

begin
  { 用专属背景色标记选区,与默认光标的 mbReversed 区分 }
  LI := TInput.New.WithSelectionStyle(TStyle.Default.WithBg(IndexedColor(5)));
  { 视口 4 列,文本 10 字符全选:可见 4 格全部高亮,不越界 }
  LS := TInputState.WithText('abcdefghij');
  LS.BeginSelect(0);
  LS.UpdateSelect(10);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 4, 1), LBuf, LS);
    for LI2 := 0 to 3 do
      Check(CellSel(LBuf, LI2, 0), 'visible cell highlighted');
  finally LBuf.Free; end;
  { 选区完全滚出视口左侧:无高亮、不越界 }
  LS := TInputState.WithText('abcdefghijklmnop');
  LS.BeginSelect(0);
  LS.UpdateSelect(2);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 4, 1), LBuf, LS);
    for LI2 := 0 to 3 do
      Check(not CellSel(LBuf, LI2, 0), 'scrolled-out selection not drawn');
  finally LBuf.Free; end;
end;

procedure TestRenderHighlightMasked;
var LI: IInput; LBuf: TBuffer; LS: TInputState;
begin
  LI := TInput.New.WithMask('*');
  LS := TInputState.WithText('secret');
  LS.BeginSelect(1);
  LS.UpdateSelect(4);   { 遮罩显示列 1..3 }
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LI.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(not (mbReversed in LBuf.CellAt(0, 0)^.Modifier), 'masked before plain');
    Check(mbReversed in LBuf.CellAt(1, 0)^.Modifier, 'masked range highlighted');
    Check(mbReversed in LBuf.CellAt(3, 0)^.Modifier, 'masked range end highlighted');
    Check(not (mbReversed in LBuf.CellAt(4, 0)^.Modifier), 'masked after plain');
  finally LBuf.Free; end;
end;

begin
  T := TTestSuite.Create('test_tui_widget_input');
  try
    { TInputState }
    T.Test('InputState Empty', @TestInputStateEmpty);
    T.Test('InputState WithText', @TestInputStateWithText);
    T.Test('InputState InsertChar', @TestInputStateInsertChar);
    T.Test('InputState InsertStr', @TestInputStateInsertStr);
    T.Test('InputState DeleteBack', @TestInputStateDeleteBack);
    T.Test('InputState DeleteForward', @TestInputStateDeleteForward);
    T.Test('InputState MoveLeft', @TestInputStateMoveLeft);
    T.Test('InputState MoveRight', @TestInputStateMoveRight);
    T.Test('InputState MoveHome', @TestInputStateMoveHome);
    T.Test('InputState MoveEnd', @TestInputStateMoveEnd);
    T.Test('InputState MoveWordLeft', @TestInputStateMoveWordLeft);
    T.Test('InputState MoveWordRight', @TestInputStateMoveWordRight);
    T.Test('InputState DeleteWordLeft', @TestInputStateDeleteWordLeft);
    T.Test('InputState DeleteWordRight', @TestInputStateDeleteWordRight);
    T.Test('HandleKey ctrl words', @TestInputStateHandleKeyCtrlWords);
    T.Test('InputState CursorCol', @TestInputStateCursorCol);
    T.Test('InputState TextWidth', @TestInputStateTextWidth);

    { IInput Builders }
    T.Test('Input New', @TestInputNew);
    T.Test('Input WithPlaceholder', @TestInputWithPlaceholder);
    T.Test('Input placeholder hidden', @TestInputPlaceholderHidden);
    T.Test('Input WithMask', @TestInputWithMask);
    T.Test('Input WithStyle', @TestInputWithStyle);
    T.Test('Input WithPlaceholderStyle', @TestInputWithPlaceholderStyle);
    T.Test('Input WithCursorStyle', @TestInputWithCursorStyle);
    T.Test('Input WithBlock', @TestInputWithBlock);
    T.Test('Input RenderInline', @TestInputRenderInline);
    T.Test('Input as IWidget', @TestInputAsIWidget);

    { HandleKey }
    T.Test('HandleKey char', @TestInputStateHandleKeyChar);
    T.Test('HandleKey backspace', @TestInputStateHandleKeyBackspace);
    T.Test('HandleKey left', @TestInputStateHandleKeyLeft);
    T.Test('HandleKey right', @TestInputStateHandleKeyRight);
    T.Test('HandleKey home', @TestInputStateHandleKeyHome);
    T.Test('HandleKey end', @TestInputStateHandleKeyEnd);
    T.Test('HandleKey delete', @TestInputStateHandleKeyDelete);

    { 选区 }
    T.Test('Selection BeginUpdate', @TestSelectionBeginUpdate);
    T.Test('Selection Reversed', @TestSelectionReversed);
    T.Test('Selection SelectedText', @TestSelectionSelectedText);
    T.Test('Selection Delete', @TestSelectionDelete);
    T.Test('Selection InsertReplaces', @TestSelectionInsertReplaces);
    T.Test('Selection WordAt', @TestSelectionWordAt);
    T.Test('Selection SelectAll', @TestSelectionSelectAll);
    T.Test('ColToBytePos', @TestColToBytePos);
    T.Test('HandleKey ShiftExtend', @TestHandleKeyShiftExtend);
    T.Test('HandleKey DeleteSelectionKeys', @TestHandleKeyDeleteSelectionKeys);
    T.Test('Render Highlight', @TestRenderHighlight);
    T.Test('Render Highlight ClipsToViewport', @TestRenderHighlightClipsToViewport);
    T.Test('Render Highlight Masked', @TestRenderHighlightMasked);

    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
