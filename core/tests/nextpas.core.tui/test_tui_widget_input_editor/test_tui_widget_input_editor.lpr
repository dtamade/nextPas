program test_tui_widget_input_editor;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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
  LEditor.HandleKey(LEvent.Key);
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

procedure TestEditorMoveWordLeftRight;
var
  LEditor: IInputEditor;
begin
  LEditor := TInputEditor.New;
  LEditor.InsertChar(Ord('h'));
  LEditor.InsertChar(Ord('e'));
  LEditor.InsertChar(Ord('l'));
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
  T.Test('MoveWordLeft/Right', @TestEditorMoveWordLeftRight);
  if not T.Run then Halt(1);
end.
