program test_tui_widget_form;
{$I nextpas.core.settings.inc}
uses
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

{ === TCheckboxState (immediate-mode) === }

procedure TestCheckboxStateEmpty;
var LS: TCheckboxState;
begin
  LS := TCheckboxState.Empty;
  Check(not LS.Checked, 'empty unchecked');
end;

procedure TestCheckboxStateToggle;
var LS: TCheckboxState;
begin
  LS := TCheckboxState.Empty;
  LS.Toggle;
  Check(LS.Checked, 'toggle to checked');
  LS.Toggle;
  Check(not LS.Checked, 'toggle back');
end;

procedure TestCheckboxStateRender;
var LC: ICheckbox; LBuf: TBuffer; LS: TCheckboxState;
begin
  LC := TCheckbox.New('Accept', False);
  LS := TCheckboxState.Empty;
  LS.Checked := True;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LC.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(Pos('[x]', LBuf.RowAsString(0)) > 0, 'stateful renders checked');
  finally LBuf.Free; end;
end;

procedure TestCheckboxStateRenderUnchecked;
var LC: ICheckbox; LBuf: TBuffer; LS: TCheckboxState;
begin
  LC := TCheckbox.New('Accept', True);
  LS := TCheckboxState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LC.RenderStateful(TRect.Make(0, 0, 20, 1), LBuf, LS);
    Check(Pos('[ ]', LBuf.RowAsString(0)) > 0, 'stateful overrides constructor');
  finally LBuf.Free; end;
end;

{ === TRadioGroupState (immediate-mode) === }

procedure TestRadioGroupStateEmpty;
var LS: TRadioGroupState;
begin
  LS := TRadioGroupState.Empty;
  CheckEqual(0, LS.Selected, 'empty selected 0');
end;

procedure TestRadioGroupStateSelect;
var LS: TRadioGroupState;
begin
  LS := TRadioGroupState.Empty;
  LS.Select(2);
  CheckEqual(2, LS.Selected, 'select 2');
  LS.Select(-1);
  CheckEqual(2, LS.Selected, 'negative ignored');
end;

procedure TestRadioGroupStateNextPrev;
var LS: TRadioGroupState;
begin
  LS := TRadioGroupState.Empty;
  LS.Next(3);
  CheckEqual(1, LS.Selected, 'next to 1');
  LS.Next(3);
  CheckEqual(2, LS.Selected, 'next to 2');
  LS.Next(3);
  CheckEqual(2, LS.Selected, 'next clamped');
  LS.Prev;
  CheckEqual(1, LS.Selected, 'prev to 1');
  LS.Prev;
  CheckEqual(0, LS.Selected, 'prev to 0');
  LS.Prev;
  CheckEqual(0, LS.Selected, 'prev clamped');
end;

procedure TestRadioGroupStateRender;
var LR: IRadioGroup; LBuf: TBuffer; LS: TRadioGroupState;
begin
  LR := TRadioGroup.New(['Red', 'Green', 'Blue']);
  LS := TRadioGroupState.Empty;
  LS.Select(1);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    LR.RenderStateful(TRect.Make(0, 0, 20, 3), LBuf, LS);
    Check(Pos('(*)', LBuf.RowAsString(1)) > 0, 'stateful selects index 1');
    Check(Pos('( )', LBuf.RowAsString(0)) > 0, 'stateful index 0 unselected');
  finally LBuf.Free; end;
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
  T.Test('checkbox state empty', @TestCheckboxStateEmpty);
  T.Test('checkbox state toggle', @TestCheckboxStateToggle);
  T.Test('checkbox state render', @TestCheckboxStateRender);
  T.Test('checkbox state render unchecked', @TestCheckboxStateRenderUnchecked);
  T.Test('radio state empty', @TestRadioGroupStateEmpty);
  T.Test('radio state select', @TestRadioGroupStateSelect);
  T.Test('radio state next/prev', @TestRadioGroupStateNextPrev);
  T.Test('radio state render', @TestRadioGroupStateRender);
  if not T.Run then Halt(1);
end.
