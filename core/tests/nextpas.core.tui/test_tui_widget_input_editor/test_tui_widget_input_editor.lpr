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
  T.Test('CutSelection', @TestEditorCutSelection);
  T.Test('ReplaceContent', @TestEditorReplaceContent);
  T.Test('MoveWordLeft/Right', @TestEditorMoveWordLeftRight);
  T.Test('MoveUp', @TestEditorMoveUp);
  T.Test('MoveDown', @TestEditorMoveDown);
  T.Test('HandleKey backspace', @TestEditorHandleKeyBackspace);
  T.Test('HandleKey delete', @TestEditorHandleKeyDelete);
  T.Test('Multiple undo/redo', @TestEditorMultipleUndoRedo);
  T.Test('Content empty', @TestEditorContentEmpty);
  T.Test('CursorScreenPos', @TestEditorCursorScreenPos);
  T.Test('CursorRow', @TestEditorCursorRow);
  if not T.Run then Halt(1);
end.
