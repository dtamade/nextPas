program test_tui_edge_cases;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.test;

var
  T: TTestSuite;

{ ---- TEvent edge cases ---- }

procedure TestEventAllKeyCodeKinds;
var
  E: TEvent;
begin
  E := KeyCodeEvent(kcChar, []); Check(E.Key.Code = kcChar, 'kcChar');
  E := KeyCodeEvent(kcEnter, []); Check(E.Key.Code = kcEnter, 'kcEnter');
  E := KeyCodeEvent(kcEsc, []); Check(E.Key.Code = kcEsc, 'kcEsc');
  E := KeyCodeEvent(kcTab, []); Check(E.Key.Code = kcTab, 'kcTab');
  E := KeyCodeEvent(kcBackTab, []); Check(E.Key.Code = kcBackTab, 'kcBackTab');
  E := KeyCodeEvent(kcBackspace, []); Check(E.Key.Code = kcBackspace, 'kcBackspace');
  E := KeyCodeEvent(kcDelete, []); Check(E.Key.Code = kcDelete, 'kcDelete');
  E := KeyCodeEvent(kcLeft, []); Check(E.Key.Code = kcLeft, 'kcLeft');
  E := KeyCodeEvent(kcRight, []); Check(E.Key.Code = kcRight, 'kcRight');
  E := KeyCodeEvent(kcUp, []); Check(E.Key.Code = kcUp, 'kcUp');
  E := KeyCodeEvent(kcDown, []); Check(E.Key.Code = kcDown, 'kcDown');
  E := KeyCodeEvent(kcHome, []); Check(E.Key.Code = kcHome, 'kcHome');
  E := KeyCodeEvent(kcEnd, []); Check(E.Key.Code = kcEnd, 'kcEnd');
  E := KeyCodeEvent(kcPageUp, []); Check(E.Key.Code = kcPageUp, 'kcPageUp');
  E := KeyCodeEvent(kcPageDown, []); Check(E.Key.Code = kcPageDown, 'kcPageDown');
  E := KeyCodeEvent(kcInsert, []); Check(E.Key.Code = kcInsert, 'kcInsert');
end;

procedure TestEventAllMouseKinds;
var
  E: TEvent;
begin
  E := MouseEvent(mkDown, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkDown, 'mkDown');
  E := MouseEvent(mkUp, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkUp, 'mkUp');
  E := MouseEvent(mkMoved, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkMoved, 'mkMoved');
  E := MouseEvent(mkDrag, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkDrag, 'mkDrag');
  E := MouseEvent(mkScrollUp, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkScrollUp, 'mkScrollUp');
  E := MouseEvent(mkScrollDown, mbLeft, 0, 0, []); Check(E.Mouse.Kind = mkScrollDown, 'mkScrollDown');
end;

procedure TestEventAllMouseButtons;
var
  E: TEvent;
begin
  E := MouseEvent(mkDown, mbLeft, 0, 0, []); Check(E.Mouse.Button = mbLeft, 'mbLeft');
  E := MouseEvent(mkDown, mbMiddle, 0, 0, []); Check(E.Mouse.Button = mbMiddle, 'mbMiddle');
  E := MouseEvent(mkDown, mbRight, 0, 0, []); Check(E.Mouse.Button = mbRight, 'mbRight');
  E := MouseEvent(mkDown, mbNone, 0, 0, []); Check(E.Mouse.Button = mbNone, 'mbNone');
end;

procedure TestEventAllModifiers;
var
  E: TEvent;
begin
  E := KeyCharEvent(Ord('a'), [kmCtrl]); Check(kmCtrl in E.Key.Modifiers, 'kmCtrl');
  E := KeyCharEvent(Ord('a'), [kmAlt]); Check(kmAlt in E.Key.Modifiers, 'kmAlt');
  E := KeyCharEvent(Ord('a'), [kmShift]); Check(kmShift in E.Key.Modifiers, 'kmShift');
  E := KeyCharEvent(Ord('a'), [kmCtrl, kmAlt, kmShift]);
  Check(kmCtrl in E.Key.Modifiers, 'all mods ctrl');
  Check(kmAlt in E.Key.Modifiers, 'all mods alt');
  Check(kmShift in E.Key.Modifiers, 'all mods shift');
end;

procedure TestEventMouseBoundaryCoords;
var
  E: TEvent;
begin
  E := MouseEvent(mkDown, mbLeft, 0, 0, []); Check(E.Mouse.X = 0, 'min x'); Check(E.Mouse.Y = 0, 'min y');
  E := MouseEvent(mkDown, mbLeft, 65535, 65535, []); Check(E.Mouse.X = 65535, 'max x'); Check(E.Mouse.Y = 65535, 'max y');
end;

procedure TestEventResizeBoundary;
var
  E: TEvent;
begin
  E := ResizeEvent(1, 1); Check(E.Resize.Width = 1, 'min w'); Check(E.Resize.Height = 1, 'min h');
  E := ResizeEvent(65535, 65535); Check(E.Resize.Width = 65535, 'max w'); Check(E.Resize.Height = 65535, 'max h');
end;

procedure TestEventKeyCharUCS4;
var
  E: TEvent;
begin
  E := KeyCharEvent($4E2D, []); // 中
  Check(E.Key.Ch = $4E2D, 'CJK char');
  E := KeyCharEvent($1F600, []); // emoji
  Check(E.Key.Ch = $1F600, 'emoji char');
end;

procedure TestEventFunctionKey;
var
  E: TEvent;
begin
  E := KeyFunctionEvent(1, []); Check(E.Key.Code = kcF, 'kcF'); Check(E.Key.F = 1, 'F1');
  E := KeyFunctionEvent(12, []); Check(E.Key.F = 12, 'F12');
end;

procedure TestEventPaste;
var
  E: TEvent;
begin
  E := PasteEvent; Check(E.Kind = evPaste, 'paste kind');
end;

{ ---- TStyle edge cases ---- }

procedure TestStylePatchBothUnset;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default;
  LOther := TStyle.Default;
  LResult := LBase.Patch(LOther);
  Check(not ColorIsSet(LResult.Fg), 'both unset fg');
  Check(not ColorIsSet(LResult.Bg), 'both unset bg');
end;

procedure TestStylePatchSelfUnset;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default;
  LOther := TStyle.Default.WithFg(TUI_RED);
  LResult := LBase.Patch(LOther);
  Check(ColorEquals(LResult.Fg, TUI_RED), 'other fg applied');
end;

procedure TestStylePatchOtherUnset;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default.WithFg(TUI_RED);
  LOther := TStyle.Default;
  LResult := LBase.Patch(LOther);
  Check(ColorEquals(LResult.Fg, TUI_RED), 'base fg kept');
end;

procedure TestStylePatchResetColor;
var
  LBase, LOther, LResult: TStyle;
begin
  LBase := TStyle.Default.WithFg(TUI_RED);
  LOther := TStyle.Default.WithFg(ResetColor);
  LResult := LBase.Patch(LOther);
  Check(LResult.Fg.Kind = ckReset, 'reset color applied');
end;

procedure TestStyleWithUnderline;
var
  LS: TStyle;
begin
  LS := TStyle.Default.WithUnderline(TUI_GREEN);
  Check(ColorEquals(LS.Ul, TUI_GREEN), 'underline color set');
end;

procedure TestStyleChainedOperations;
var
  LS: TStyle;
begin
  LS := TStyle.Default
    .WithFg(TUI_RED)
    .WithBg(TUI_BLUE)
    .WithUnderline(TUI_GREEN)
    .WithModifier([mbBold, mbItalic])
    .WithoutModifier([mbItalic])
    .WithFg(TUI_YELLOW);
  Check(ColorEquals(LS.Fg, TUI_YELLOW), 'last fg wins');
  Check(ColorEquals(LS.Bg, TUI_BLUE), 'bg preserved');
  Check(ColorEquals(LS.Ul, TUI_GREEN), 'underline preserved');
  Check(mbBold in LS.AddMod, 'bold kept');
  Check(not (mbItalic in LS.AddMod), 'italic removed');
end;

procedure TestStyleEquals;
var
  LA, LB: TStyle;
begin
  LA := TStyle.Default.WithFg(TUI_RED);
  LB := TStyle.Default.WithFg(TUI_RED);
  Check(StyleEquals(LA, LB), 'same styles equal');
  LB := TStyle.Default.WithFg(TUI_BLUE);
  Check(not StyleEquals(LA, LB), 'different styles not equal');
end;

procedure TestColorEdgeCases;
begin
  Check(ColorIsSet(IndexedColor(0)), 'index 0 is set');
  Check(ColorIsSet(IndexedColor(255)), 'index 255 is set');
  Check(ColorIsSet(RgbColor(0, 0, 0)), 'rgb(0,0,0) is set');
  Check(ColorIsSet(RgbColor(255, 255, 255)), 'rgb(255,255,255) is set');
  Check(not ColorIsSet(UnsetColor), 'unset is not set');
  Check(ColorIsSet(ResetColor), 'reset is set');
  Check(ColorEquals(IndexedColor(42), IndexedColor(42)), 'same index equal');
  Check(not ColorEquals(IndexedColor(1), IndexedColor(2)), 'different index not equal');
end;

{ ---- TBuffer edge cases ---- }

procedure TestBufferCreateEmpty1x1;
var
  LBuf: TBuffer;
  LArea: TRect;
begin
  LArea := TRect.Make(0, 0, 1, 1);
  LBuf := TBuffer.CreateEmpty(LArea);
  Check(LBuf.Width = 1, 'width 1');
  Check(LBuf.Height = 1, 'height 1');
  LBuf.Free;
end;

procedure TestBufferCellAtBoundary;
var
  LBuf: TBuffer;
  LArea: TRect;
  LCell: PCell;
begin
  LArea := TRect.Make(0, 0, 5, 5);
  LBuf := TBuffer.CreateEmpty(LArea);
  LCell := LBuf.CellAt(0, 0); Check(LCell <> nil, '(0,0) valid');
  LCell := LBuf.CellAt(4, 4); Check(LCell <> nil, '(4,4) valid');
  LCell := LBuf.CellAt(5, 5); Check(LCell = nil, '(5,5) out of bounds');
  LCell := LBuf.CellAt(-1, 0); Check(LCell = nil, '(-1,0) out of bounds');
  LCell := LBuf.CellAt(0, -1); Check(LCell = nil, '(0,-1) out of bounds');
  LBuf.Free;
end;

procedure TestBufferReset;
var
  LBuf: TBuffer;
  LArea: TRect;
  LCell: PCell;
begin
  LArea := TRect.Make(0, 0, 3, 3);
  LBuf := TBuffer.CreateEmpty(LArea);
  LBuf.Reset;
  LCell := LBuf.CellAt(0, 0);
  Check(LCell <> nil, 'cell exists after reset');
  LBuf.Free;
end;

procedure TestModifierEdgeCases;
begin
  Check(ModifierIsEmpty([]), 'empty set is empty');
  Check(not ModifierIsEmpty([mbBold]), 'bold not empty');
  Check(ModifierEquals([], []), 'empty equals empty');
  Check(ModifierEquals([mbBold, mbItalic], [mbBold, mbItalic]), 'same sets equal');
  Check(not ModifierEquals([mbBold], [mbItalic]), 'different sets not equal');
end;

begin
  T := TTestSuite.Create('tui_edge_cases');
  { Event }
  T.Test('Event all KeyCodeKinds', @TestEventAllKeyCodeKinds);
  T.Test('Event all MouseKinds', @TestEventAllMouseKinds);
  T.Test('Event all MouseButtons', @TestEventAllMouseButtons);
  T.Test('Event all Modifiers', @TestEventAllModifiers);
  T.Test('Event mouse boundary coords', @TestEventMouseBoundaryCoords);
  T.Test('Event resize boundary', @TestEventResizeBoundary);
  T.Test('Event UCS4 char', @TestEventKeyCharUCS4);
  T.Test('Event function key', @TestEventFunctionKey);
  T.Test('Event paste', @TestEventPaste);
  { Style }
  T.Test('Style patch both unset', @TestStylePatchBothUnset);
  T.Test('Style patch self unset', @TestStylePatchSelfUnset);
  T.Test('Style patch other unset', @TestStylePatchOtherUnset);
  T.Test('Style patch reset color', @TestStylePatchResetColor);
  T.Test('Style with underline', @TestStyleWithUnderline);
  T.Test('Style chained operations', @TestStyleChainedOperations);
  T.Test('Style equals', @TestStyleEquals);
  T.Test('Color edge cases', @TestColorEdgeCases);
  { Buffer }
  T.Test('Buffer create 1x1', @TestBufferCreateEmpty1x1);
  T.Test('Buffer CellAt boundary', @TestBufferCellAtBoundary);
  T.Test('Buffer reset', @TestBufferReset);
  T.Test('Modifier edge cases', @TestModifierEdgeCases);
  if not T.Run then Halt(1);
end.
