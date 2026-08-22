program test_tui_widget_input_editor;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.syntax,
  nextpas.core.tui.widget.input_editor,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestEditorSnapshotRecord;
var
  LSnapshot: TEditorSnapshot;
begin
  LSnapshot.Text := 'hello';
  LSnapshot.CurByte := 3;
  LSnapshot.Anchor := 0;
  Check(LSnapshot.Text = 'hello', 'Snapshot text should be hello');
  Check(LSnapshot.CurByte = 3, 'Snapshot CurByte should be 3');
  Check(LSnapshot.Anchor = 0, 'Snapshot Anchor should be 0');
end;

procedure TestEditorNew;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  Check(LEditor <> nil, 'New editor should not be nil');
  Check(LEditor.IsEmpty, 'New editor should be empty');
  Check(LEditor.LineCount = 1, 'New editor should have 1 line');
end;

procedure TestEditorNewWithMaxLines;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.NewWithMaxLines(10);
  Check(LEditor <> nil, 'NewWithMaxLines editor should not be nil');
  Check(LEditor.IsEmpty, 'NewWithMaxLines editor should be empty');
end;

procedure TestEditorInsertChar;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  Check(LEditor.Content = 'hello', 'Content should be hello');
  Check(not LEditor.IsEmpty, 'Editor should not be empty');
end;

procedure TestEditorInsertNewline;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('i'));
  LEditor.InsertChar(Ord('n'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('1'));
  LEditor.InsertNewline;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('i'));
  LEditor.InsertChar(Ord('n'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('2'));
  Check(LEditor.LineCount = 2, 'Should have 2 lines');
  Check(Pos('line1', LEditor.Content) > 0, 'Should contain line1');
  Check(Pos('line2', LEditor.Content) > 0, 'Should contain line2');
end;

procedure TestEditorDeleteBackward;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.DeleteBackward;
  Check(LEditor.Content = 'hell', 'Content should be hell after delete');
  LEditor.DeleteBackward;
  Check(LEditor.Content = 'hel', 'Content should be hel after delete');
end;

procedure TestEditorDeleteForward;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.MoveHome;
  LEditor.DeleteForward;
  Check(LEditor.Content = 'ello', 'Content should be ello after forward delete');
end;

procedure TestEditorMoveLeftRight;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEditor.InsertChar(Ord('c'));
  LEditor.MoveLeft;
  LEditor.MoveLeft;
  LEditor.InsertChar(Ord('X'));
  Check(LEditor.Content = 'aXbc', 'Content should be aXbc');
end;

procedure TestEditorMoveHomeEnd;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.MoveHome;
  LEditor.InsertChar(Ord('X'));
  Check(LEditor.Content = 'Xhello', 'Content should be Xhello');
  LEditor.MoveEnd;
  LEditor.InsertChar(Ord('Y'));
  Check(LEditor.Content = 'XhelloY', 'Content should be XhelloY');
end;

procedure TestEditorSelectAll;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.SelectAll;
  LEditor.DeleteBackward;
  Check(LEditor.IsEmpty, 'Editor should be empty after select all and delete');
end;

procedure TestEditorClear;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.Clear;
  Check(LEditor.IsEmpty, 'Editor should be empty after clear');
  Check(LEditor.Content = '', 'Content should be empty after clear');
end;

procedure TestEditorUndoRedo;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEditor.InsertChar(Ord('c'));
  Check(LEditor.Content = 'abc', 'Content should be abc');
  LEditor.Undo;
  Check(LEditor.Content = 'ab', 'Content should be ab after undo');
  LEditor.Redo;
  Check(LEditor.Content = 'abc', 'Content should be abc after redo');
end;

procedure TestEditorPlaceholder;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor := LEditor.WithPlaceholder('Type here...');
  Check(LEditor.IsEmpty, 'Editor with placeholder should still be empty');
end;

procedure TestEditorTextStyle;
var
  LEditor: IInputEditor;
  LStyle: TStyle;
begin
  LEditor := TInputEditor.New;
  LStyle.Fg := IndexedColor(1);
  LStyle.Bg := IndexedColor(2);
  LEditor := LEditor.WithTextStyle(LStyle);
  Check(LEditor <> nil, 'WithTextStyle should return editor');
end;

procedure TestEditorPlaceholderStyle;
var
  LEditor: IInputEditor;
  LStyle: TStyle;
begin
  LEditor := TInputEditor.New;
  LStyle.Fg := IndexedColor(3);
  LStyle.Bg := IndexedColor(4);
  LEditor := LEditor.WithPlaceholderStyle(LStyle);
  Check(LEditor <> nil, 'WithPlaceholderStyle should return editor');
end;

procedure TestEditorSelectionStyle;
var
  LEditor: IInputEditor;
  LStyle: TStyle;
begin
  LEditor := TInputEditor.New;
  LStyle.Fg := IndexedColor(5);
  LStyle.Bg := IndexedColor(6);
  LEditor := LEditor.WithSelectionStyle(LStyle);
  Check(LEditor <> nil, 'WithSelectionStyle should return editor');
end;

procedure TestEditorMaxLines;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor := LEditor.WithMaxLines(5);
  Check(LEditor <> nil, 'WithMaxLines should return editor');
end;

procedure TestEditorSetHighlighter;
var
  LEditor: IInputEditor;
  LHighlighter: IHighlighter;
  LTheme: TSyntaxTheme;
begin
  LEditor := TInputEditor.New;
  LHighlighter := TPascalHighlighter.Create;
  LTheme := TSyntaxTheme.Default;
  LEditor.SetHighlighter(LHighlighter, LTheme);
  Check(True, 'SetHighlighter should not raise exception');
end;

procedure TestEditorHandleKey;
var
  LEditor: IInputEditor;
  LEvent: TEvent;
begin
  LEditor := TInputEditor.New;
  LEvent := KeyCharEvent(Ord('a'), []);
  Check(LEditor.HandleKey(LEvent.Key), 'HandleKey consumes char');
  Check(LEditor.Content = 'a', 'Content should be a after handle key');
end;

procedure TestEditorInsertCharUnicode;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar($00E9); // é
  Check(Length(LEditor.Content) > 0, 'Should insert unicode char');
end;

procedure TestEditorMultipleLines;
var
  LEditor: IInputEditor;
  I: Integer;
begin
  LEditor := TInputEditor.New;
  for I := 1 to 5 do
  begin
    LEditor.InsertChar(Ord('l'));
    LEditor.InsertChar(Ord('i'));
    LEditor.InsertChar(Ord('n'));
    LEditor.InsertChar(Ord('e'));
    if I < 5 then
      LEditor.InsertNewline;
  end;
  Check(LEditor.LineCount = 4, 'Should have 4 lines');
end;

procedure TestEditorDeleteLine;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('i'));
  LEditor.InsertChar(Ord('n'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('1'));
  LEditor.InsertNewline;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('i'));
  LEditor.InsertChar(Ord('n'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('2'));
  LEditor.MoveUp;
  LEditor.DeleteLine;
  Check(LEditor.LineCount = 1, 'Should have 1 line after delete line');
end;

procedure TestEditorCopyCutPaste;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.SelectAll;
  LEditor.CopySelection;
  LEditor.Clear;
  LEditor.Paste;
  Check(LEditor.Content = 'hello', 'Content should be hello after paste');
end;

procedure TestEditorDeleteWordBackward;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = 'hello ', 'backspace word keeps separator blank');
  Check(LEditor.CursorRow = 0, 'backspace word cursor row');
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = '', 'backspace word removes last word');
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = '', 'backspace word at start is noop');
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello  world');
  LEditor.MoveEnd;
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = 'hello  ', 'backspace word keeps all leading blanks');
end;

procedure TestEditorDeleteWordForward;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  LEditor.MoveHome;
  LEditor.DeleteWordForward;
  Check(LEditor.Content = 'world', 'delete word forward eats separator (landing = ctrl+right)');
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello');
  LEditor.MoveEnd;
  LEditor.DeleteWordForward;
  Check(LEditor.Content = 'hello', 'delete word forward at end is noop');
end;

procedure TestEditorDeleteWordUndo;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = 'hello ', 'word delete applied');
  LEditor.Undo;
  Check(LEditor.Content = 'hello world', 'word delete is single undo op');
end;

procedure TestEditorDeleteWordSelection;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  LEditor.MoveHome;
  LEditor.SelectAll;
  LEditor.DeleteWordBackward;
  Check(LEditor.Content = '', 'word delete with selection removes selection');
end;

procedure TestEditorHandleKeyCtrlWordDelete;
var
  LEditor: IInputEditor;
  KE: TKeyEvent;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  KE.Modifiers := [kmCtrl];
  Check(LEditor.HandleKey(KE), 'ctrl+backspace handled');
  Check(LEditor.Content = 'hello ', 'ctrl+backspace deletes word');
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  { 光标移到 'world' 的 'o'（0-based 8）：Home 后 8 次 MoveRight }
  LEditor.MoveHome;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  LEditor.MoveRight;
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcDelete;
  KE.Modifiers := [kmCtrl];
  LEditor.HandleKey(KE);
  Check(LEditor.Content = 'hello wo', 'ctrl+delete from word middle deletes word tail');
  FillChar(KE, SizeOf(KE), 0);
  KE.Code := kcBackspace;
  LEditor.HandleKey(KE);
  Check(LEditor.Content = 'hello w', 'plain backspace still deletes char');
end;

procedure TestEditorPasteText;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('hello world');
  Check(LEditor.Content = 'hello world', 'paste text inserts text');
  Check(LEditor.LineCount = 1, 'paste text keeps single line');
  LEditor.PasteText('');
  Check(LEditor.Content = 'hello world', 'empty paste text is noop');
  LEditor.Undo;
  Check(LEditor.IsEmpty, 'paste text is single undo op');
end;

procedure TestEditorPasteTextMultilineCrop;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('a' + #10 + 'b' + #10 + 'c');
  Check(LEditor.Content = 'a' + #10 + 'b' + #10 + 'c', 'paste text keeps newlines');
  Check(LEditor.LineCount = 3, 'paste text spans lines');
  LEditor := TInputEditor.New.WithMaxLines(2);
  LEditor.PasteText('a' + #10 + 'b' + #10 + 'c');
  Check(LEditor.LineCount = 2, 'paste text cropped to max lines');
  Check(LEditor.Content = 'a' + #10 + 'b', 'overflow line clipped off');
end;

procedure TestEditorPasteTextReplacesSelection;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.PasteText('abcdef');
  LEditor.MoveHome;
  LEditor.SelectAll;
  LEditor.PasteText('xy');
  Check(LEditor.Content = 'xy', 'paste text replaces selection');
end;

procedure TestEditorCutSelection;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.SelectAll;
  LEditor.CutSelection;
  Check(LEditor.IsEmpty, 'Editor should be empty after cut');
  LEditor.Paste;
  Check(LEditor.Content = 'hello', 'Content should be hello after paste');
end;

procedure TestEditorReplaceContent;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  { 整文替换：文本 + 光标定位（UTF-8 字节）}
  LEditor.ReplaceContent('优化：请以快速排序实现', 27);
  Check(LEditor.Content = '优化：请以快速排序实现',
    'Content should be replaced');
  { 单次 Undo 恢复全文（非逐字符污染撤销栈）}
  LEditor.Undo;
  Check(LEditor.Content = 'hello', 'one undo restores original text');
  LEditor.Redo;
  Check(LEditor.Content = '优化：请以快速排序实现',
    'redo reapplies replaced content');
  { caret 越界 clamp + 选区清除 }
  LEditor.ReplaceContent('abc', 999);
  LEditor.SelectAll;
  LEditor.ReplaceContent('xy', -1);
  Check(LEditor.Content = 'xy', 'clamped negative caret replaces');
  LEditor.InsertChar(Ord('z'));
  Check(LEditor.Content = 'zxy', 'selection anchor cleared by replace');
  LEditor.Undo;
  Check(LEditor.Content = 'xy', 'safe to undo after clamp replace');
end;

procedure TestEditorMoveWordLeftRight;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('o'));
  LEditor.InsertChar(Ord(' '));
  LEditor.InsertChar(Ord('w'));
  LEditor.InsertChar(Ord('o'));
  LEditor.InsertChar(Ord('r'));
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('d'));
  LEditor.MoveHome;
  LEditor.MoveWordRight;
  LEditor.InsertChar(Ord('X'));
  Check(Pos('X', LEditor.Content) > 0, 'Should insert X after word move');
end;

{ --- MoveUp/MoveDown --- }

procedure TestEditorMoveUp;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('1'));
  LEditor.InsertNewline;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('2'));
  Check(LEditor.LineCount = 2, 'Should have 2 lines');
  LEditor.MoveUp;
  LEditor.InsertChar(Ord('X'));
  Check(Pos('X', LEditor.Content) > 0, 'Should insert X on first line');
end;

procedure TestEditorMoveDown;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('1'));
  LEditor.InsertNewline;
  LEditor.InsertChar(Ord('l'));
  LEditor.InsertChar(Ord('2'));
  LEditor.MoveHome;
  LEditor.MoveUp;
  LEditor.MoveDown;
  LEditor.InsertChar(Ord('Y'));
  Check(Pos('Y', LEditor.Content) > 0, 'Should insert Y on second line');
end;

{ --- HandleKey with special keys --- }

procedure TestEditorHandleKeyBackspace;
var
  LEditor: IInputEditor;
  LEvent: TEvent;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEvent := KeyCodeEvent(kcBackspace, []);
  LEditor.HandleKey(LEvent.Key);
  Check(LEditor.Content = 'a', 'Content should be a after backspace');
end;

procedure TestEditorHandleKeyDelete;
var
  LEditor: IInputEditor;
  LEvent: TEvent;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEditor.MoveHome;
  LEvent := KeyCodeEvent(kcDelete, []);
  LEditor.HandleKey(LEvent.Key);
  Check(LEditor.Content = 'b', 'Content should be b after delete');
end;

{ --- Multiple undo/redo --- }

procedure TestEditorMultipleUndoRedo;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEditor.InsertChar(Ord('c'));
  Check(LEditor.Content = 'abc', 'Content should be abc');
  LEditor.Undo;
  Check(LEditor.Content = 'ab', 'Content should be ab after undo');
  LEditor.Undo;
  Check(LEditor.Content = 'a', 'Content should be a after 2nd undo');
  LEditor.Redo;
  Check(LEditor.Content = 'ab', 'Content should be ab after redo');
  LEditor.Redo;
  Check(LEditor.Content = 'abc', 'Content should be abc after 2nd redo');
end;

{ --- Content after operations --- }

procedure TestEditorContentEmpty;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  Check(LEditor.Content = '', 'Empty editor content should be empty string');
end;

{ --- CursorScreenPos --- }

procedure TestEditorCursorScreenPos;
var
  LEditor: IInputEditor;
  LPos: TPosition;
  LArea: TRect;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LArea := TRect.Make(0, 0, 20, 1);
  LPos := LEditor.CursorScreenPos(LArea);
  Check(LPos.X >= 0, 'Cursor X should be non-negative');
  Check(LPos.Y >= 0, 'Cursor Y should be non-negative');
end;

{ --- CursorRow（光标绝对行，0-based，与滚动无关）--- }

procedure TestEditorCursorRow;
var
  LEditor: IInputEditor;
  LText: AnsiString;
  I: Integer;
begin
  { 空文本 → 第 0 行 }
  LEditor := TInputEditor.New;
  Check(LEditor.CursorRow = 0, 'Empty editor cursor on row 0');
  { 单行光标尾 → 第 0 行 }
  LEditor.InsertChar(Ord('a'));
  LEditor.InsertChar(Ord('b'));
  LEditor.InsertChar(Ord('c'));
  Check(LEditor.CursorRow = 0, 'Single line cursor on row 0');
  { 多行：a\nb 光标尾 → 第 1 行；MoveUp → 0；第 0 行再上移仍 0；MoveDown → 1 }
  LEditor.InsertNewline;
  LEditor.InsertChar(Ord('d'));
  Check(LEditor.CursorRow = 1, 'Two-line text cursor on row 1');
  LEditor.MoveUp;
  Check(LEditor.CursorRow = 0, 'Cursor row 0 after MoveUp');
  LEditor.MoveUp;
  Check(LEditor.CursorRow = 0, 'Cursor stays row 0 at top');
  LEditor.MoveDown;
  Check(LEditor.CursorRow = 1, 'Cursor row 1 after MoveDown');
  { 行中 InsertNewline：第 0 行尾插换行 → 光标落新行（第 1 行）}
  LEditor.ReplaceContent('ab', 2);    { 重置为单行 'ab'，光标置尾（第 0 行）}
  LEditor.InsertNewline;
  Check(LEditor.CursorRow = 1, 'Cursor on new line after InsertNewline');
  Check(LEditor.LineCount = 2, 'Two lines after InsertNewline');
  { 30 行长文本（经 ReplaceContent，不受默认 MaxLines=4 限制）光标深处 →
    绝对行准确——不经过 FScrollRow，视口/滚动无关。
    末行不带 #10，光标落最后一行行尾（0-based 29）}
  LText := '';
  for I := 1 to 29 do
    LText := LText + 'line' + #10;
  LText := LText + 'line30';
  LEditor.ReplaceContent(LText, Length(LText));
  Check(LEditor.CursorRow = 29, 'Deep cursor row 29 on 30-line text');
  LEditor.MoveUp;
  Check(LEditor.CursorRow = 28, 'Cursor row 28 after MoveUp');
  LEditor.MoveDown;
  Check(LEditor.CursorRow = 29, 'Cursor row 29 after MoveDown');
end;

{ --- MoveTo:字节定位(越界 clamp),不进撤销栈 --- }

procedure TestEditorMoveTo;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.ReplaceContent('hello'#10'world'#10, 0);
  { world 行 'r' 前:hello(0-4) LF(5) w(6) o(7) r(8) }
  LEditor.MoveTo(8);
  LEditor.InsertChar(Ord('!'));
  Check(LEditor.Content = 'hello'#10'wo!rld'#10, 'MoveTo positions caret');
  { 越界高位 clamp 到末尾 }
  LEditor.MoveTo(999);
  LEditor.InsertChar(Ord('X'));
  Check(LEditor.Content = 'hello'#10'wo!rld'#10'X', 'MoveTo clamps high');
  { 越界低位 clamp 到 0 }
  LEditor.MoveTo(-5);
  LEditor.InsertChar(Ord('Y'));
  Check(LEditor.Content = 'Yhello'#10'wo!rld'#10'X', 'MoveTo clamps low');
  { 定位不污染撤销栈:Undo 仍回到定位前全文 }
end;

{ --- ByteOffsetAt:屏幕坐标 → 字节偏移(行/列 clamp) --- }

procedure TestEditorByteOffsetAt;
var
  LEditor: IInputEditor;
  A: TRect;
begin
  LEditor := TInputEditor.New;
  LEditor.ReplaceContent('abc'#10'def'#10, 0);
  A := TRect.Make(0, 0, 10, 10);
  Check(LEditor.ByteOffsetAt(A, 0, 0) = 0, 'col0 row0');
  Check(LEditor.ByteOffsetAt(A, 2, 0) = 2, 'col2 row0');
  Check(LEditor.ByteOffsetAt(A, 99, 0) = 3, 'col clamp row0');
  Check(LEditor.ByteOffsetAt(A, 0, 1) = 4, 'row1 start');
  Check(LEditor.ByteOffsetAt(A, 1, 1) = 5, 'row1 col1');
  { 视口底部外 clamp 到末行(尾换行产生的空行)行首 }
  Check(LEditor.ByteOffsetAt(A, 0, 99) = 8, 'row clamp to last');
end;

{ --- SetFindHits:渲染命中高亮(当前/非当前样式),清除 --- }

procedure TestEditorFindHits;
var
  LEditor: IInputEditor;
  B: TBuffer;
  H: array of TFindHit;
  St, CurSt: TStyle;
begin
  LEditor := TInputEditor.New;
  LEditor.ReplaceContent('foo bar foo'#10, 0);
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 5), nil);
  try
    St.Fg := IndexedColor(1);
    St.Bg := IndexedColor(7);
    CurSt.Fg := IndexedColor(2);
    CurSt.Bg := IndexedColor(8);
    SetLength(H, 2);
    H[0].Start := 0; H[0].Len := 3;   { 行首 foo }
    H[1].Start := 8; H[1].Len := 3;   { 行尾 foo }
    LEditor.SetFindHits(H, 0, St, CurSt);
    LEditor.Render(TRect.Make(0, 0, 30, 5), B);
    Check(B.CellAt(0, 0)^.Bg.Index = 8, 'cur hit style bg');
    Check(B.CellAt(8, 0)^.Bg.Index = 7, 'non-cur hit style bg');
    Check(B.CellAt(4, 0)^.Bg.Index <> 7, 'gap not highlighted');
    { 空数组清除高亮:新帧(TBuffer 每帧新建,样式合并语义下不可复用旧缓冲) }
    LEditor.SetFindHits([], -1, St, CurSt);
    B.Free;
    B := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 5), nil);
    LEditor.Render(TRect.Make(0, 0, 30, 5), B);
    Check(B.CellAt(0, 0)^.Bg.Index <> 8, 'clear hits');
  finally
    B.Free;
  end;
end;

{ 选区读取 API:无选区 HasSelection=False/SelectedText='';
  移动+Shift 选择后有选区,SelectedText=选中字节;光标在选区内时
  选区文本不随光标移动变化(Anchor/Cur 反转由内部处理) }
procedure TestEditorSelectionAPI;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.ReplaceContent('abcd'#10'ef', 0);
  Check(not LEditor.HasSelection, 'no selection initially');
  Check(LEditor.SelectedText = '', 'empty text without selection');
  LEditor.MoveRight;          { 光标到 1 }
  LEditor.MoveRight;          { 光标到 2 }
  LEditor.MoveRight;          { 光标到 3:Anchor=-1 纯移动,无选区 }
  Check(not LEditor.HasSelection, 'plain moves keep no selection');
  LEditor.MoveLeft;           { 光标 2 }
  { 用 Shift 扩展:HandleKey 的 kcRight+kmShift 走 MoveRightInternal(Selecting) }
  LEditor.HandleKey(KeyCodeEvent(kcRight, [kmShift]).Key);  { 光标 3,选区 [2,3) }
  Check(LEditor.HasSelection, 'shift moves select');
  Check(LEditor.SelectedText = 'c', 'selected text span');
  { Anchor 在 2:再右移扩展 }
  LEditor.HandleKey(KeyCodeEvent(kcRight, [kmShift]).Key);  { 光标 4,选区 [2,4) }
  Check(LEditor.SelectedText = 'cd', 'selection grows right');
  { 反向移动(Anchor 3,光标回到 2):选区 [2,3) }
  LEditor.HandleKey(KeyCodeEvent(kcLeft, [kmShift]).Key);
  Check(LEditor.SelectedText = 'c', 'selection shrinks');
end;

{ 删除选区:DeleteSelected 入撤销栈,一次 Undo 恢复 }
procedure TestEditorDeleteSelectedUndo;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.ReplaceContent('hello world', 0);
  LEditor.HandleKey(KeyCodeEvent(kcRight, [kmShift]).Key);  { 选 'h' }
  LEditor.HandleKey(KeyCodeEvent(kcRight, [kmShift]).Key);  { 选 'he' }
  LEditor.DeleteSelected;
  Check(LEditor.Content = 'llo world', 'delete selected removes span');
  Check(not LEditor.HasSelection, 'selection cleared after delete');
  Check(LEditor.CursorRow = 0, 'cursor stays at deletion point');
  LEditor.Undo;
  Check(LEditor.Content = 'hello world', 'undo restores span');
  { 无选区时无操作(Undo 恢复含 Anchor 的快照,先 MoveTo 清选区) }
  LEditor.MoveTo(0);
  LEditor.DeleteSelected;
  Check(LEditor.Content = 'hello world', 'no-op without selection');
end;

{ PH33 P2b：布局配置面——WithBlock 块包装（边框在区边缘、占位文本仍在内容区） }
procedure TestEditorWithBlock;
var LE: IInputEditor; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LE := TInputEditor.New
    .WithPlaceholder('ph-mark')
    .WithBlock(TBlock.Bordered('T'));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 4));
  try
    LE.Render(TRect.Make(0, 0, 30, 4), LBuf);
    LAll := '';
    for I := 0 to 3 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos(#$E2#$94#$8C, LBuf.RowAsString(0)) > 0, 'block border drawn');
    Check(Pos('ph-mark', LAll) > 0, 'placeholder visible inside block');
  finally LBuf.Free; end;
end;

procedure TestEditorWithBlockChaining;
var LE: IInputEditor;
begin
  LE := TInputEditor.New.WithBlock(TBlock.Bordered('x'));
  Check(LE <> nil, 'WithBlock chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.input_editor');
  T.Test('TEditorSnapshot record', @TestEditorSnapshotRecord);
  T.Test('TInputEditor.New', @TestEditorNew);
  T.Test('TInputEditor.NewWithMaxLines', @TestEditorNewWithMaxLines);
  T.Test('InsertChar', @TestEditorInsertChar);
  T.Test('InsertNewline', @TestEditorInsertNewline);
  T.Test('DeleteBackward', @TestEditorDeleteBackward);
  T.Test('DeleteForward', @TestEditorDeleteForward);
  T.Test('MoveLeft/Right', @TestEditorMoveLeftRight);
  T.Test('MoveHome/End', @TestEditorMoveHomeEnd);
  T.Test('SelectAll', @TestEditorSelectAll);
  T.Test('Clear', @TestEditorClear);
  T.Test('Undo/Redo', @TestEditorUndoRedo);
  T.Test('Placeholder', @TestEditorPlaceholder);
  T.Test('TextStyle', @TestEditorTextStyle);
  T.Test('PlaceholderStyle', @TestEditorPlaceholderStyle);
  T.Test('SelectionStyle', @TestEditorSelectionStyle);
  T.Test('MaxLines', @TestEditorMaxLines);
  T.Test('SetHighlighter', @TestEditorSetHighlighter);
  T.Test('HandleKey', @TestEditorHandleKey);
  T.Test('InsertChar Unicode', @TestEditorInsertCharUnicode);
  T.Test('Multiple lines', @TestEditorMultipleLines);
  T.Test('DeleteLine', @TestEditorDeleteLine);
  T.Test('Copy/Paste', @TestEditorCopyCutPaste);
  T.Test('PasteText', @TestEditorPasteText);
  T.Test('PasteText multiline crop', @TestEditorPasteTextMultilineCrop);
  T.Test('PasteText replaces selection', @TestEditorPasteTextReplacesSelection);
  T.Test('CutSelection', @TestEditorCutSelection);
  T.Test('ReplaceContent', @TestEditorReplaceContent);
  T.Test('MoveWordLeft/Right', @TestEditorMoveWordLeftRight);
  T.Test('DeleteWordBackward', @TestEditorDeleteWordBackward);
  T.Test('DeleteWordForward', @TestEditorDeleteWordForward);
  T.Test('DeleteWord undo', @TestEditorDeleteWordUndo);
  T.Test('DeleteWord selection', @TestEditorDeleteWordSelection);
  T.Test('HandleKey ctrl word delete', @TestEditorHandleKeyCtrlWordDelete);
  T.Test('MoveUp', @TestEditorMoveUp);
  T.Test('MoveDown', @TestEditorMoveDown);
  T.Test('HandleKey backspace', @TestEditorHandleKeyBackspace);
  T.Test('HandleKey delete', @TestEditorHandleKeyDelete);
  T.Test('Multiple undo/redo', @TestEditorMultipleUndoRedo);
  T.Test('Content empty', @TestEditorContentEmpty);
  T.Test('CursorScreenPos', @TestEditorCursorScreenPos);
  T.Test('CursorRow', @TestEditorCursorRow);
  T.Test('MoveTo', @TestEditorMoveTo);
  T.Test('ByteOffsetAt', @TestEditorByteOffsetAt);
  T.Test('FindHits', @TestEditorFindHits);
  T.Test('SelectionAPI', @TestEditorSelectionAPI);
  T.Test('DeleteSelected undo', @TestEditorDeleteSelectedUndo);
  T.Test('WithBlock render (PH33 P2b)', @TestEditorWithBlock);
  T.Test('WithBlock chaining (PH33 P2b)', @TestEditorWithBlockChaining);
  if not T.Run then Halt(1);
end.
