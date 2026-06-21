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
  Check(SizeOf(TX11KeySym) = 8, 'KeySym is 8 bytes (UInt64, matches C unsigned long)');
  Check(SizeOf(TX11KeyCode) = 4, 'KeyCode is 4 bytes (UInt32, matches C unsigned int)');
  Check(SizeOf(TX11Event) = 192, 'XEvent is 192 bytes (matches C union XEvent)');
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
  Check(XK_KP_ENTER = $FF8D, 'XK_KP_Enter = $FF8D');
end;

{ Write a known value at each offset and verify the helper reads it back. }
procedure TestAllEventFieldHelpers;
var
  LEv: TX11Event;
begin
  FillChar(LEv, SizeOf(LEv), 0);

  { event_type at offset 0 }
  PInt32(@LEv[X11_EVENT_TYPE_OFFSET])^ := 42;
  Check(x11_event_type(LEv) = 42, 'event_type reads offset 0');
  PInt32(@LEv[X11_EVENT_TYPE_OFFSET])^ := 0;

  { event_window at offset 32 }
  PTX11Window(@LEv[X11_EVENT_WINDOW_OFFSET])^ := $DEADBEEF;
  Check(x11_event_window(LEv) = $DEADBEEF, 'event_window reads offset 32');
  PTX11Window(@LEv[X11_EVENT_WINDOW_OFFSET])^ := 0;

  { event_time at offset 56 }
  PUInt32(@LEv[X11_EVENT_TIME_OFFSET])^ := 12345;
  Check(x11_event_time(LEv) = 12345, 'event_time reads offset 56');
  PUInt32(@LEv[X11_EVENT_TIME_OFFSET])^ := 0;

  { key_event_state at offset 80 }
  PUInt32(@LEv[X11_KEY_EVENT_STATE_OFFSET])^ := $0F;
  Check(x11_key_event_state(LEv) = $0F, 'key_event_state reads offset 80');
  PUInt32(@LEv[X11_KEY_EVENT_STATE_OFFSET])^ := 0;

  { key_event_keycode at offset 84 }
  PUInt32(@LEv[X11_KEY_EVENT_KEYCODE_OFFSET])^ := 38;
  Check(x11_key_event_keycode(LEv) = 38, 'key_event_keycode reads offset 84');
  PUInt32(@LEv[X11_KEY_EVENT_KEYCODE_OFFSET])^ := 0;

  { button_event_button at offset 84 }
  PUInt32(@LEv[X11_BUTTON_EVENT_BUTTON_OFFSET])^ := 3;
  Check(x11_button_event_button(LEv) = 3, 'button_event_button reads offset 84');
  PUInt32(@LEv[X11_BUTTON_EVENT_BUTTON_OFFSET])^ := 0;

  { button_event_x at offset 64 }
  PInt32(@LEv[X11_BUTTON_EVENT_X_OFFSET])^ := 150;
  Check(x11_button_event_x(LEv) = 150, 'button_event_x reads offset 64');
  PInt32(@LEv[X11_BUTTON_EVENT_X_OFFSET])^ := 0;

  { button_event_y at offset 68 }
  PInt32(@LEv[X11_BUTTON_EVENT_Y_OFFSET])^ := 250;
  Check(x11_button_event_y(LEv) = 250, 'button_event_y reads offset 68');
  PInt32(@LEv[X11_BUTTON_EVENT_Y_OFFSET])^ := 0;

  { motion_event_x at offset 64 }
  PInt32(@LEv[X11_MOTION_EVENT_X_OFFSET])^ := 300;
  Check(x11_motion_event_x(LEv) = 300, 'motion_event_x reads offset 64');
  PInt32(@LEv[X11_MOTION_EVENT_X_OFFSET])^ := 0;

  { motion_event_y at offset 68 }
  PInt32(@LEv[X11_MOTION_EVENT_Y_OFFSET])^ := 400;
  Check(x11_motion_event_y(LEv) = 400, 'motion_event_y reads offset 68');
  PInt32(@LEv[X11_MOTION_EVENT_Y_OFFSET])^ := 0;

  { configure_event_window at offset 40 }
  PTX11Window(@LEv[X11_CONFIGURE_EVENT_WINDOW_OFFSET])^ := $CAFEBABE;
  Check(x11_configure_event_window(LEv) = $CAFEBABE,
    'configure_event_window reads offset 40');
  PTX11Window(@LEv[X11_CONFIGURE_EVENT_WINDOW_OFFSET])^ := 0;

  { configure_event_width at offset 56 }
  PInt32(@LEv[X11_CONFIGURE_EVENT_WIDTH_OFFSET])^ := 1920;
  Check(x11_configure_event_width(LEv) = 1920,
    'configure_event_width reads offset 56');
  PInt32(@LEv[X11_CONFIGURE_EVENT_WIDTH_OFFSET])^ := 0;

  { configure_event_height at offset 60 }
  PInt32(@LEv[X11_CONFIGURE_EVENT_HEIGHT_OFFSET])^ := 1080;
  Check(x11_configure_event_height(LEv) = 1080,
    'configure_event_height reads offset 60');
  PInt32(@LEv[X11_CONFIGURE_EVENT_HEIGHT_OFFSET])^ := 0;

  { client_message_l0 at offset 56 }
  PTX11Atom(@LEv[X11_CLIENT_MESSAGE_DATA_OFFSET])^ := $1234567890ABCDEF;
  Check(x11_client_message_l0(LEv) = $1234567890ABCDEF,
    'client_message_l0 reads offset 56');
  PTX11Atom(@LEv[X11_CLIENT_MESSAGE_DATA_OFFSET])^ := 0;
end;

{ Verify event_type helper works for negative values (X11 uses int for type). }
procedure TestEventTypeNegative;
var
  LEv: TX11Event;
begin
  FillChar(LEv, SizeOf(LEv), 0);
  PInt32(@LEv[0])^ := -1;
  Check(x11_event_type(LEv) = -1, 'event_type handles negative values');
end;

{ Verify window field is zero when event buffer is zeroed. }
procedure TestZeroedEvent;
var
  LEv: TX11Event;
begin
  FillChar(LEv, SizeOf(LEv), 0);
  Check(x11_event_type(LEv) = 0, 'zeroed event type is 0');
  Check(x11_event_window(LEv) = 0, 'zeroed event window is 0');
  Check(x11_event_time(LEv) = 0, 'zeroed event time is 0');
  Check(x11_key_event_state(LEv) = 0, 'zeroed key state is 0');
  Check(x11_key_event_keycode(LEv) = 0, 'zeroed key keycode is 0');
  Check(x11_client_message_l0(LEv) = 0, 'zeroed client message l0 is 0');
end;

procedure TestNotLoadedByDefault;
begin
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
    T.Run('TestLoadLibX11 [SKIP: no libX11]',
      procedure begin end);
    Exit;
  end;
  Check(x11_is_loaded, 'loaded after x11_load');

  { Verify all resolved function pointers are set. }
  Check(@XOpenDisplay <> nil, 'XOpenDisplay resolved');
  Check(@XCloseDisplay <> nil, 'XCloseDisplay resolved');
  Check(@XCreateSimpleWindow <> nil, 'XCreateSimpleWindow resolved');
  Check(@XMapWindow <> nil, 'XMapWindow resolved');
  Check(@XNextEvent <> nil, 'XNextEvent resolved');
  Check(@XPending <> nil, 'XPending resolved');
  Check(@XInternAtom <> nil, 'XInternAtom resolved');
  Check(@XLookupString <> nil, 'XLookupString resolved');
  Check(@XFlush <> nil, 'XFlush resolved');
  Check(@XSelectInput <> nil, 'XSelectInput resolved');
  Check(@XSetWMProtocols <> nil, 'XSetWMProtocols resolved');
  Check(@XDestroyWindow <> nil, 'XDestroyWindow resolved');

  x11_unload;
  Check(not x11_is_loaded, 'unloaded after x11_unload');
end;

procedure TestDoubleLoadIdempotent;
begin
  if x11_load <> 0 then Exit;
  Check(x11_is_loaded, 'first load ok');
  Check(x11_load = 0, 'second load returns 0 (idempotent)');
  x11_unload; { decrements refcount, doesn't unload yet }
  Check(x11_is_loaded, 'still loaded after one unload (refcount)');
  x11_unload; { now refcount hits 0 }
  Check(not x11_is_loaded, 'fully unloaded after second unload');
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
  T.Run('AllEventFieldHelpers', @TestAllEventFieldHelpers);
  T.Run('EventTypeNegative', @TestEventTypeNegative);
  T.Run('ZeroedEvent', @TestZeroedEvent);
  T.Run('NotLoadedByDefault', @TestNotLoadedByDefault);
  T.Run('LoadLibX11', @TestLoadLibX11);
  T.Run('DoubleLoadIdempotent', @TestDoubleLoadIdempotent);
  T.Run('UnloadSafeWhenNotLoaded', @TestUnloadSafeWhenNotLoaded);
  T.Summary;
end.
