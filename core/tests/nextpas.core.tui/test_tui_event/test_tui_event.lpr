program test_tui_event;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.event,
  nextpas.core.testing;
var T: TTestRunner;
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
begin
  T := TTestRunner.Create('nextpas.core.tui.event');
  T.Run('none', @TestNone); T.Run('key char', @TestKeyChar);
  T.Run('key code', @TestKeyCode); T.Run('mouse', @TestMouse);
  T.Run('resize', @TestResize); T.Summary;
  if not T.AllPassed then Halt(1);
end.
