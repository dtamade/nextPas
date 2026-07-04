program test_tui_widget_form;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.input_editor,
  nextpas.core.tui.widget.select,
  nextpas.core.tui.widget.form,
  nextpas.core.tui.widget.command_palette,
  nextpas.core.tui.widget.scrollview,
  nextpas.core.test;
var T: TTestSuite;

{ === TInputEditor === }

procedure TestEditorNew;
var E: IInputEditor;
begin
  E := TInputEditor.New;
  Check(E.Content = '', 'new editor is empty');
  Check(E.IsEmpty, 'IsEmpty true');
  CheckEqual(1, E.LineCount, 'initial line count');
end;

procedure TestEditorInsert;
var E: IInputEditor;
begin
  E := TInputEditor.New;
  E.InsertChar(Ord('H'));
  E.InsertChar(Ord('i'));
  CheckEqual('Hi', E.Content, 'insert chars');
end;

procedure TestEditorMoveLeftRight;
var E: IInputEditor;
begin
  E := TInputEditor.New;
  E.InsertChar(Ord('A'));
  E.InsertChar(Ord('B'));
  E.InsertChar(Ord('C'));
  E.MoveLeft;
  E.InsertChar(Ord('X'));
  CheckEqual('ABXC', E.Content, 'insert after move left');
end;

procedure TestEditorDeleteBackward;
var E: IInputEditor;
begin
  E := TInputEditor.New;
  E.InsertChar(Ord('A'));
  E.InsertChar(Ord('B'));
  E.DeleteBackward;
  CheckEqual('A', E.Content, 'delete backward');
end;

procedure TestEditorUndo;
var E: IInputEditor;
begin
  E := TInputEditor.New;
  E.InsertChar(Ord('X'));
  E.InsertChar(Ord('Y'));
  E.Undo;
  CheckEqual('X', E.Content, 'undo last insert');
end;

procedure TestEditorRender;
var E: IInputEditor; LBuf: TBuffer;
begin
  E := TInputEditor.New;
  E.InsertChar(Ord('T'));
  E.InsertChar(Ord('e'));
  E.InsertChar(Ord('s'));
  E.InsertChar(Ord('t'));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    (E as IWidget).Render(TRect.Make(0, 0, 20, 3), LBuf);
    Check(Pos('Test', LBuf.RowAsString(0)) > 0, 'editor renders content');
  finally LBuf.Free; end;
end;

{ === TSelect === }

procedure TestSelectNew;
var LS: ISelect; LBuf: TBuffer; LSt: TSelectState;
begin
  LS := TSelect.New(['Alpha', 'Beta', 'Gamma']);
  LSt := TSelectState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LS.RenderStateful(TRect.Make(0, 0, 20, 10), LBuf, LSt);
    Check(True, 'select renders closed');
  finally LBuf.Free; end;
end;

procedure TestSelectOpen;
var LS: ISelect; LBuf: TBuffer; LSt: TSelectState;
begin
  LS := TSelect.New(['One', 'Two', 'Three']);
  LSt := TSelectState.Empty;
  LSt.Toggle;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LS.RenderStateful(TRect.Make(0, 0, 20, 10), LBuf, LSt);
    Check(Pos('One', LBuf.RowAsString(1)) > 0, 'select shows items when open');
  finally LBuf.Free; end;
end;

procedure TestSelectOpenKeepsHighlightVisible;
var LS: ISelect; LBuf: TBuffer; LSt: TSelectState;
begin
  LS := TSelect.New(['One', 'Two', 'Three', 'Four'])
    .WithMaxDropHeight(2);
  LSt := TSelectState.Empty;
  LSt.Toggle;
  LSt.HighlightIdx := 3;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 4));
  try
    LS.RenderStateful(TRect.Make(0, 0, 20, 4), LBuf, LSt);
    Check(Pos('Three', LBuf.RowAsString(1)) > 0,
      'select scrolls dropdown window before highlighted item');
    Check(Pos('Four', LBuf.RowAsString(2)) > 0,
      'select keeps highlighted item visible within max drop height');
  finally LBuf.Free; end;
end;

{ === TCheckbox === }

procedure TestCheckboxUnchecked;
var LC: ICheckbox; LBuf: TBuffer;
begin
  LC := TCheckbox.New('Accept', False);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    (LC as IWidget).Render(TRect.Make(0, 0, 20, 1), LBuf);
    Check(Pos('[ ]', LBuf.RowAsString(0)) > 0, 'unchecked marker');
  finally LBuf.Free; end;
end;

procedure TestCheckboxChecked;
var LC: ICheckbox; LBuf: TBuffer;
begin
  LC := TCheckbox.New('Accept', True);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    (LC as IWidget).Render(TRect.Make(0, 0, 20, 1), LBuf);
    Check(Pos('[x]', LBuf.RowAsString(0)) > 0, 'checked marker');
  finally LBuf.Free; end;
end;

procedure TestCheckboxToggle;
var LC: ICheckbox;
begin
  LC := TCheckbox.New('Toggle', False);
  Check(not LC.IsChecked, 'initially unchecked');
  LC.Toggle;
  Check(LC.IsChecked, 'checked after toggle');
end;

{ === TRadioGroup === }

procedure TestRadioGroupRender;
var LR: IRadioGroup; LBuf: TBuffer;
begin
  LR := TRadioGroup.New(['Red', 'Green', 'Blue']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    (LR as IWidget).Render(TRect.Make(0, 0, 20, 3), LBuf);
    Check(Pos('(*)', LBuf.RowAsString(0)) > 0, 'first item selected');
    Check(Pos('( )', LBuf.RowAsString(1)) > 0, 'second item unselected');
  finally LBuf.Free; end;
end;

procedure TestRadioGroupSelect;
var LR: IRadioGroup; LBuf: TBuffer;
begin
  LR := TRadioGroup.New(['A', 'B', 'C']);
  LR.Select(2);
  CheckEqual(2, LR.GetSelected, 'selected index');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    (LR as IWidget).Render(TRect.Make(0, 0, 20, 3), LBuf);
    Check(Pos('(*)', LBuf.RowAsString(2)) > 0, 'third item selected');
  finally LBuf.Free; end;
end;

{ === TCommandPalette === }

procedure TestCommandPaletteRender;
var LP: ICommandPalette; LBuf: TBuffer; LSt: TCommandPaletteState;
begin
  LP := TCommandPalette.New([
    TCommandItem.Make('Open File', 'Open a file'),
    TCommandItem.Make('Save', 'Save current'),
    TCommandItem.Make('Quit', 'Exit app')
  ]);
  LSt := TCommandPaletteState.Empty;
  LSt.Open;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 20));
  try
    LP.RenderStateful(TRect.Make(0, 0, 60, 20), LBuf, LSt);
    Check(True, 'command palette renders');
  finally LBuf.Free; end;
end;

procedure TestCommandPaletteTinyViewportStaysClipped;
var
  LP: ICommandPalette;
  LBuf: TBuffer;
  LSt: TCommandPaletteState;
begin
  LP := TCommandPalette.New([
    TCommandItem.Make('Open File', 'Open a file')
  ]);
  LSt := TCommandPaletteState.Empty;
  LSt.Open;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 5));
  try
    LP.RenderStateful(TRect.Make(0, 0, 7, 4), LBuf, LSt);
    Check(Pos('S', LBuf.RowAsString(3)) = 0,
      'tiny command palette does not leak input content into border-only area');
  finally LBuf.Free; end;
end;

{ === TScrollView === }

procedure TestScrollViewRender;
var LS: IScrollView; LBuf: TBuffer; LSt: TScrollViewState;
begin
  LS := TScrollView.New;
  LSt := TScrollViewState.Empty;
  LSt.ContentHeight := 50;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LS.RenderStateful(TRect.Make(0, 0, 20, 10), LBuf, LSt);
    Check(True, 'scrollview renders');
  finally LBuf.Free; end;
end;

procedure TestScrollViewState;
var LSt: TScrollViewState;
begin
  LSt := TScrollViewState.Empty;
  LSt.ContentHeight := 100;
  LSt.ScrollDown(5);
  CheckEqual(5, LSt.OffsetY, 'scroll down');
  LSt.ScrollUp(3);
  CheckEqual(2, LSt.OffsetY, 'scroll up');
  LSt.ScrollToTop;
  CheckEqual(0, LSt.OffsetY, 'scroll to top');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.form');
  T.Test('editor new', @TestEditorNew);
  T.Test('editor insert', @TestEditorInsert);
  T.Test('editor move left/right', @TestEditorMoveLeftRight);
  T.Test('editor delete backward', @TestEditorDeleteBackward);
  T.Test('editor undo', @TestEditorUndo);
  T.Test('editor render', @TestEditorRender);
  T.Test('select new', @TestSelectNew);
  T.Test('select open', @TestSelectOpen);
  T.Test('select open keeps highlight visible', @TestSelectOpenKeepsHighlightVisible);
  T.Test('checkbox unchecked', @TestCheckboxUnchecked);
  T.Test('checkbox checked', @TestCheckboxChecked);
  T.Test('checkbox toggle', @TestCheckboxToggle);
  T.Test('radio group render', @TestRadioGroupRender);
  T.Test('radio group select', @TestRadioGroupSelect);
  T.Test('command palette render', @TestCommandPaletteRender);
  T.Test('command palette tiny viewport stays clipped',
    @TestCommandPaletteTinyViewportStaysClipped);
  T.Test('scrollview render', @TestScrollViewRender);
  T.Test('scrollview state', @TestScrollViewState);
  if not T.Run then Halt(1);
end.
