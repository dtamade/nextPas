program test_tui_event;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.event,
  nextpas.core.test;
var T: TTestSuite;
procedure TestNone;
var E: TEvent;
begin E := NoneEvent; Check(E.Kind = evNone, 'none kind'); end;
procedure TestKeyChar;
var E: TEvent;
begin E := KeyCharEvent(Ord('A'), []); Check(E.Kind = evKey, 'key kind');
  Check(E.Key.Code = kcChar, 'char code'); CheckEqual(Int64(65), Int64(E.Key.Ch), 'ch=A'); end;
procedure TestKeyCode;
var E: TEvent;
begin E := KeyCodeEvent(kcEnter, [kmCtrl]); Check(E.Key.Code = kcEnter, 'enter');
  Check(kmCtrl in E.Key.Modifiers, 'ctrl mod'); end;
procedure TestMouse;
var E: TEvent;
begin E := MouseEvent(mkDown, mbLeft, 5, 3, [kmShift]);
  Check(E.Kind = evMouse, 'mouse kind'); CheckEqual(Int64(5), Int64(E.Mouse.X), 'x');
  Check(kmShift in E.Mouse.Modifiers, 'shift'); end;
procedure TestResize;
var E: TEvent;
begin E := ResizeEvent(80, 24); Check(E.Kind = evResize, 'resize kind');
  CheckEqual(Int64(80), Int64(E.Resize.Width), 'w'); CheckEqual(Int64(24), Int64(E.Resize.Height), 'h'); end;

{ --- KeyFunctionEvent --- }

procedure TestKeyFunction;
var E: TEvent;
begin
  E := KeyFunctionEvent(5, [kmAlt]);
  Check(E.Kind = evKey, 'function key kind');
  Check(E.Key.Code = kcF, 'function key code');
  CheckEqual(Int64(5), Int64(E.Key.F), 'F=5');
  Check(kmAlt in E.Key.Modifiers, 'alt mod');
end;

{ --- PasteEvent --- }

procedure TestPaste;
var E: TEvent;
begin
  E := PasteEvent;
  Check(E.Kind = evPaste, 'paste kind');
end;

{ --- IsNone --- }

procedure TestIsNone;
begin
  Check(IsNone(NoneEvent), 'NoneEvent is none');
  Check(not IsNone(KeyCharEvent(Ord('A'), [])), 'key char is not none');
end;

{ --- IsKey --- }

procedure TestIsKey;
begin
  Check(IsKey(KeyCharEvent(Ord('A'), [])), 'key char is key');
  Check(IsKey(KeyCodeEvent(kcEnter, [])), 'key code is key');
  Check(not IsKey(NoneEvent), 'none is not key');
  Check(not IsKey(MouseEvent(mkDown, mbLeft, 0, 0, [])), 'mouse is not key');
end;

{ --- IsMouse --- }

procedure TestIsMouse;
begin
  Check(IsMouse(MouseEvent(mkDown, mbLeft, 0, 0, [])), 'mouse is mouse');
  Check(not IsMouse(NoneEvent), 'none is not mouse');
end;

{ --- IsResize --- }

procedure TestIsResize;
begin
  Check(IsResize(ResizeEvent(80, 24)), 'resize is resize');
  Check(not IsResize(NoneEvent), 'none is not resize');
end;

{ --- IsPaste --- }

procedure TestIsPaste;
begin
  Check(IsPaste(PasteEvent), 'paste is paste');
  Check(not IsPaste(NoneEvent), 'none is not paste');
end;

{ --- IsKeyChar --- }

procedure TestIsKeyChar;
begin
  Check(IsKeyChar(KeyCharEvent(Ord('A'), []), Ord('A')), 'A matches A');
  Check(not IsKeyChar(KeyCharEvent(Ord('A'), []), Ord('B')), 'A does not match B');
  Check(not IsKeyChar(NoneEvent, Ord('A')), 'none is not key char');
end;

{ --- IsKeyCode --- }

procedure TestIsKeyCode;
begin
  Check(IsKeyCode(KeyCodeEvent(kcEnter, []), kcEnter), 'enter matches enter');
  Check(not IsKeyCode(KeyCodeEvent(kcEnter, []), kcEsc), 'enter does not match esc');
  Check(not IsKeyCode(NoneEvent, kcEnter), 'none is not key code');
end;

{ --- IsQuit --- }

procedure TestIsQuit;
begin
  // Quit is typically Ctrl+C or similar
  Check(not IsQuit(NoneEvent), 'none is not quit');
  Check(not IsQuit(KeyCharEvent(Ord('A'), [])), 'regular char is not quit');
end;

{ --- Various key codes --- }

procedure TestKeyCodeEsc;
var E: TEvent;
begin
  E := KeyCodeEvent(kcEsc, []);
  Check(E.Key.Code = kcEsc, 'esc code');
  Check(E.Key.Modifiers = [], 'no modifiers');
end;

procedure TestKeyCodeTab;
var E: TEvent;
begin
  E := KeyCodeEvent(kcTab, [kmShift]);
  Check(E.Key.Code = kcTab, 'tab code');
  Check(kmShift in E.Key.Modifiers, 'shift mod');
end;

procedure TestKeyCodeArrow;
var E: TEvent;
begin
  E := KeyCodeEvent(kcUp, []);
  Check(E.Key.Code = kcUp, 'up code');
  E := KeyCodeEvent(kcDown, []);
  Check(E.Key.Code = kcDown, 'down code');
  E := KeyCodeEvent(kcLeft, []);
  Check(E.Key.Code = kcLeft, 'left code');
  E := KeyCodeEvent(kcRight, []);
  Check(E.Key.Code = kcRight, 'right code');
end;

{ --- Mouse event kinds --- }

procedure TestMouseKinds;
var E: TEvent;
begin
  E := MouseEvent(mkUp, mbRight, 10, 20, []);
  Check(E.Kind = evMouse, 'mouse up kind');
  Check(E.Mouse.Kind = mkUp, 'mkUp');
  Check(E.Mouse.Button = mbRight, 'right button');
  CheckEqual(Int64(10), Int64(E.Mouse.X), 'x=10');
  CheckEqual(Int64(20), Int64(E.Mouse.Y), 'y=20');
end;

procedure TestMouseScroll;
var E: TEvent;
begin
  E := MouseEvent(mkScrollUp, mbNone, 0, 0, []);
  Check(E.Mouse.Kind = mkScrollUp, 'scroll up');
  E := MouseEvent(mkScrollDown, mbNone, 0, 0, []);
  Check(E.Mouse.Kind = mkScrollDown, 'scroll down');
end;

{ --- Key modifiers --- }

procedure TestKeyModifiers;
var E: TEvent;
begin
  E := KeyCharEvent(Ord('C'), [kmCtrl, kmShift]);
  Check(kmCtrl in E.Key.Modifiers, 'ctrl present');
  Check(kmShift in E.Key.Modifiers, 'shift present');
  Check(not (kmAlt in E.Key.Modifiers), 'alt absent');
end;

{ --- KeyCodeKind enum values --- }

procedure TestKeyCodeKindEnum;
begin
  Check(Ord(kcChar) = 0, 'kcChar=0');
  Check(Ord(kcEnter) = 1, 'kcEnter=1');
  Check(Ord(kcEsc) = 2, 'kcEsc=2');
  Check(Ord(kcTab) = 3, 'kcTab=3');
  Check(Ord(kcBackTab) = 4, 'kcBackTab=4');
  Check(Ord(kcBackspace) = 5, 'kcBackspace=5');
  Check(Ord(kcDelete) = 6, 'kcDelete=6');
end;

{ --- MouseEventKind enum values --- }

procedure TestMouseEventKindEnum;
begin
  Check(Ord(mkDown) = 0, 'mkDown=0');
  Check(Ord(mkUp) = 1, 'mkUp=1');
  Check(Ord(mkMoved) = 2, 'mkMoved=2');
  Check(Ord(mkDrag) = 3, 'mkDrag=3');
  Check(Ord(mkScrollUp) = 4, 'mkScrollUp=4');
  Check(Ord(mkScrollDown) = 5, 'mkScrollDown=5');
end;

{ --- MouseButton enum values --- }

procedure TestMouseButtonEnum;
begin
  Check(Ord(mbLeft) = 0, 'mbLeft=0');
  Check(Ord(mbMiddle) = 1, 'mbMiddle=1');
  Check(Ord(mbRight) = 2, 'mbRight=2');
  Check(Ord(mbNone) = 3, 'mbNone=3');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.event');
  T.Test('none', @TestNone);
  T.Test('key char', @TestKeyChar);
  T.Test('key code', @TestKeyCode);
  T.Test('mouse', @TestMouse);
  T.Test('resize', @TestResize);
  T.Test('key function', @TestKeyFunction);
  T.Test('paste', @TestPaste);
  T.Test('IsNone', @TestIsNone);
  T.Test('IsKey', @TestIsKey);
  T.Test('IsMouse', @TestIsMouse);
  T.Test('IsResize', @TestIsResize);
  T.Test('IsPaste', @TestIsPaste);
  T.Test('IsKeyChar', @TestIsKeyChar);
  T.Test('IsKeyCode', @TestIsKeyCode);
  T.Test('IsQuit', @TestIsQuit);
  T.Test('key code Esc', @TestKeyCodeEsc);
  T.Test('key code Tab', @TestKeyCodeTab);
  T.Test('key code arrows', @TestKeyCodeArrow);
  T.Test('mouse kinds', @TestMouseKinds);
  T.Test('mouse scroll', @TestMouseScroll);
  T.Test('key modifiers', @TestKeyModifiers);
  T.Test('KeyCodeKind enum', @TestKeyCodeKindEnum);
  T.Test('MouseEventKind enum', @TestMouseEventKindEnum);
  T.Test('MouseButton enum', @TestMouseButtonEnum);
  if not T.Run then Halt(1);
end.
