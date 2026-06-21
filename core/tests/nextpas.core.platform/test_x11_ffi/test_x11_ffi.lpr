program test_x11_ffi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.x11,
  nextpas.core.platform.x11.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

{ Compile-only gate: types and constants are resolvable at compile time. }
procedure TestTypeSizes;
begin
  Check(SizeOf(TX11Display) = SizeOf(Pointer), 'Display is pointer-sized');
  Check(SizeOf(TX11Window) = 8, 'Window is 8 bytes (UInt64)');
  Check(SizeOf(TX11Atom) = 8, 'Atom is 8 bytes (UInt64)');
  Check(SizeOf(TX11KeySym) = 4, 'KeySym is 4 bytes (UInt32)');
  Check(SizeOf(TX11KeyCode) = 1, 'KeyCode is 1 byte');
  Check(SizeOf(TX11Event) = 96, 'XEvent is 96 bytes');
end;

procedure TestConstants;
begin
  Check(X11_KEY_PRESS = 2, 'KeyPress = 2');
  Check(X11_KEY_RELEASE = 3, 'KeyRelease = 3');
  Check(X11_BUTTON_PRESS = 4, 'ButtonPress = 4');
  Check(X11_CONFIGURE_NOTIFY = 22, 'ConfigureNotify = 22');
  Check(X11_CLIENT_MESSAGE = 33, 'ClientMessage = 33');
  Check(X11_SHIFT_MASK = 1, 'ShiftMask = 1');
  Check(X11_CONTROL_MASK = 4, 'ControlMask = 4');
  Check(X11_MOD1_MASK = 8, 'Mod1Mask (Alt) = 8');
  Check(X11_MOD4_MASK = 64, 'Mod4Mask (Super) = 64');
  Check(XK_RETURN = $FF0D, 'XK_Return = $FF0D');
  Check(XK_ESCAPE = $FF1B, 'XK_Escape = $FF1B');
  Check(XK_BACKSPACE = $FF08, 'XK_BackSpace = $FF08');
  Check(XK_F1 = $FFBE, 'XK_F1 = $FFBE');
end;

procedure TestEventFieldOffsets;
var
  LEv: TX11Event;
begin
  { Verify event type is at offset 0. }
  FillChar(LEv, SizeOf(LEv), 0);
  LEv.FType := 42;
  Check(x11_event_type(LEv) = 42, 'event type at expected offset');
  LEv.FType := 0;

  { Verify window field is readable. }
  LEv.FWindow := $DEADBEEF;
  Check(x11_event_window(LEv) = $DEADBEEF, 'event window at expected offset');
end;

procedure TestNotLoadedByDefault;
begin
  { After fresh load (program start), x11_is_loaded should be False
    unless some other test called x11_load. }
  { We just verify the function is callable. }
  x11_unload; { Safe even if not loaded. }
  Check(not x11_is_loaded, 'not loaded after unload');
end;

procedure TestLoadLibX11;
var
  LResult: Int32;
begin
  LResult := x11_load;
  if LResult <> 0 then
  begin
    { Headless environment without libX11 -- skip gracefully. }
    T.Run('TestLoadLibX11 [SKIP: no libX11]',
      procedure begin end);
    Exit;
  end;
  Check(x11_is_loaded, 'loaded after x11_load');

  { Verify some key function pointers are set. }
  Check(@XOpenDisplay <> nil, 'XOpenDisplay resolved');
  Check(@XCloseDisplay <> nil, 'XCloseDisplay resolved');
  Check(@XCreateSimpleWindow <> nil, 'XCreateSimpleWindow resolved');
  Check(@XMapWindow <> nil, 'XMapWindow resolved');
  Check(@XNextEvent <> nil, 'XNextEvent resolved');
  Check(@XPending <> nil, 'XPending resolved');
  Check(@XInternAtom <> nil, 'XInternAtom resolved');
  Check(@XLookupString <> nil, 'XLookupString resolved');
  Check(@XFlush <> nil, 'XFlush resolved');

  x11_unload;
  Check(not x11_is_loaded, 'unloaded after x11_unload');
end;

procedure TestDoubleLoadIdempotent;
begin
  if x11_load <> 0 then Exit;
  Check(x11_is_loaded, 'first load ok');
  Check(x11_load = 0, 'second load returns 0 (idempotent)');
  x11_unload;
end;

procedure TestUnloadSafeWhenNotLoaded;
begin
  x11_unload;
  x11_unload;
  Check(not x11_is_loaded, 'double unload is safe');
end;

begin
  T := TTestRunner.Create('test_x11_ffi');
  T.Run('TypeSizes', @TestTypeSizes);
  T.Run('Constants', @TestConstants);
  T.Run('EventFieldOffsets', @TestEventFieldOffsets);
  T.Run('NotLoadedByDefault', @TestNotLoadedByDefault);
  T.Run('LoadLibX11', @TestLoadLibX11);
  T.Run('DoubleLoadIdempotent', @TestDoubleLoadIdempotent);
  T.Run('UnloadSafeWhenNotLoaded', @TestUnloadSafeWhenNotLoaded);
  T.Summary;
end.
