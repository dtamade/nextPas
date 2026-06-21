unit nextpas.core.platform.x11;

{$I nextpas.core.settings.inc}

// X11 runtime loader and convenience wrappers.
//
// Loads libX11.so.6 via dlopen/dlsym at runtime. Avoids hard link
// dependency so binaries run on headless or Wayland-only systems.
//
// Event field helpers read from a flat 192-byte TX11Event buffer
// using byte offsets verified against gcc offsetof(XKeyEvent, ...).

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.platform.x11.ffi;

const
  X11_ERR_NOT_LOADED  = -1;
  X11_ERR_LOAD_FAILED = -2;
  X11_ERR_DISPLAY     = -3;
  X11_ERR_WINDOW      = -4;
  X11_ERR_ATOM        = -5;

{ Runtime load/unload of libX11. Returns 0 on success. }
function x11_load: Int32;
procedure x11_unload;
function x11_is_loaded: Boolean;

{ --- Event field helpers (byte-offset access into flat TX11Event) --- }

{ Common header fields (shared by all event types) }
function x11_event_type(const AEvent: TX11Event): Int32;
function x11_event_window(const AEvent: TX11Event): TX11Window;

{ XKeyEvent / XButtonEvent / XMotionEvent time field }
function x11_event_time(const AEvent: TX11Event): UInt32;

{ XKeyEvent sub-fields }
function x11_key_event_state(const AEvent: TX11Event): UInt32;
function x11_key_event_keycode(const AEvent: TX11Event): UInt32;

{ XButtonEvent sub-fields }
function x11_button_event_button(const AEvent: TX11Event): UInt32;
function x11_button_event_x(const AEvent: TX11Event): Int32;
function x11_button_event_y(const AEvent: TX11Event): Int32;

{ XMotionEvent sub-fields }
function x11_motion_event_x(const AEvent: TX11Event): Int32;
function x11_motion_event_y(const AEvent: TX11Event): Int32;

{ XConfigureEvent sub-fields }
function x11_configure_event_window(const AEvent: TX11Event): TX11Window;
function x11_configure_event_width(const AEvent: TX11Event): Int32;
function x11_configure_event_height(const AEvent: TX11Event): Int32;

{ XClientMessageEvent sub-fields }
function x11_client_message_l0(const AEvent: TX11Event): TX11Atom;

implementation

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;

function x11_load: Int32;
var
  LPtr: Pointer;
begin
  if GLoaded then
  begin
    Inc(GRefCount);
    Exit(X11_SUCCESS);
  end;

  if platform_dl_open('libX11.so.6', PLATFORM_DL_NOW, GLib) <> 0 then
    Exit(X11_ERR_LOAD_FAILED);

  { Resolve required symbols. On any failure, unload and return error. }
  if platform_dl_sym(GLib, 'XOpenDisplay', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XOpenDisplay) := LPtr;

  if platform_dl_sym(GLib, 'XCloseDisplay', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XCloseDisplay) := LPtr;

  if platform_dl_sym(GLib, 'XDefaultRootWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XDefaultRootWindow) := LPtr;

  if platform_dl_sym(GLib, 'XDefaultScreen', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XDefaultScreen) := LPtr;

  if platform_dl_sym(GLib, 'XDefaultVisual', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XDefaultVisual) := LPtr;

  if platform_dl_sym(GLib, 'XDefaultColormap', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XDefaultColormap) := LPtr;

  if platform_dl_sym(GLib, 'XBlackPixel', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XBlackPixel) := LPtr;

  if platform_dl_sym(GLib, 'XWhitePixel', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XWhitePixel) := LPtr;

  if platform_dl_sym(GLib, 'XCreateSimpleWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XCreateSimpleWindow) := LPtr;

  if platform_dl_sym(GLib, 'XCreateWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XCreateWindow) := LPtr;

  if platform_dl_sym(GLib, 'XDestroyWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XDestroyWindow) := LPtr;

  if platform_dl_sym(GLib, 'XMapWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XMapWindow) := LPtr;

  if platform_dl_sym(GLib, 'XUnmapWindow', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XUnmapWindow) := LPtr;

  if platform_dl_sym(GLib, 'XStoreName', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XStoreName) := LPtr;

  if platform_dl_sym(GLib, 'XSelectInput', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XSelectInput) := LPtr;

  if platform_dl_sym(GLib, 'XNextEvent', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XNextEvent) := LPtr;

  if platform_dl_sym(GLib, 'XPending', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XPending) := LPtr;

  if platform_dl_sym(GLib, 'XSync', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XSync) := LPtr;

  if platform_dl_sym(GLib, 'XFlush', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XFlush) := LPtr;

  if platform_dl_sym(GLib, 'XInternAtom', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XInternAtom) := LPtr;

  if platform_dl_sym(GLib, 'XSetWMProtocols', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XSetWMProtocols) := LPtr;

  if platform_dl_sym(GLib, 'XLookupString', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XLookupString) := LPtr;

  { XkbKeycodeToKeysym is optional -- fallback to XLookupString if absent. }
  if platform_dl_sym(GLib, 'XkbKeycodeToKeysym', LPtr) = 0 then
    Pointer(XkbKeycodeToKeysym) := LPtr
  else
    Pointer(XkbKeycodeToKeysym) := nil;

  if platform_dl_sym(GLib, 'XChangeProperty', LPtr) <> 0 then
  begin x11_unload; Exit(X11_ERR_LOAD_FAILED); end;
  Pointer(XChangeProperty) := LPtr;

  GLoaded := True;
  GRefCount := 1;
  Result := X11_SUCCESS;
end;

procedure x11_unload;
begin
  if not GLoaded then
    Exit;
  Dec(GRefCount);
  if GRefCount > 0 then
    Exit;

  Pointer(XOpenDisplay) := nil;
  Pointer(XCloseDisplay) := nil;
  Pointer(XDefaultRootWindow) := nil;
  Pointer(XDefaultScreen) := nil;
  Pointer(XDefaultVisual) := nil;
  Pointer(XDefaultColormap) := nil;
  Pointer(XBlackPixel) := nil;
  Pointer(XWhitePixel) := nil;
  Pointer(XCreateSimpleWindow) := nil;
  Pointer(XCreateWindow) := nil;
  Pointer(XDestroyWindow) := nil;
  Pointer(XMapWindow) := nil;
  Pointer(XUnmapWindow) := nil;
  Pointer(XStoreName) := nil;
  Pointer(XSelectInput) := nil;
  Pointer(XNextEvent) := nil;
  Pointer(XPending) := nil;
  Pointer(XSync) := nil;
  Pointer(XFlush) := nil;
  Pointer(XInternAtom) := nil;
  Pointer(XSetWMProtocols) := nil;
  Pointer(XLookupString) := nil;
  Pointer(XkbKeycodeToKeysym) := nil;
  Pointer(XChangeProperty) := nil;
  platform_dl_close(GLib);
  GLoaded := False;
end;

function x11_is_loaded: Boolean;
begin
  Result := GLoaded;
end;

{ --- Event field helpers --- }

function x11_event_type(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_EVENT_TYPE_OFFSET])^;
end;

function x11_event_window(const AEvent: TX11Event): TX11Window;
begin
  Result := PTX11Window(@AEvent[X11_EVENT_WINDOW_OFFSET])^;
end;

function x11_event_time(const AEvent: TX11Event): UInt32;
begin
  Result := PUInt32(@AEvent[X11_EVENT_TIME_OFFSET])^;
end;

function x11_key_event_state(const AEvent: TX11Event): UInt32;
begin
  Result := PUInt32(@AEvent[X11_KEY_EVENT_STATE_OFFSET])^;
end;

function x11_key_event_keycode(const AEvent: TX11Event): UInt32;
begin
  Result := PUInt32(@AEvent[X11_KEY_EVENT_KEYCODE_OFFSET])^;
end;

function x11_button_event_button(const AEvent: TX11Event): UInt32;
begin
  Result := PUInt32(@AEvent[X11_BUTTON_EVENT_BUTTON_OFFSET])^;
end;

function x11_button_event_x(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_BUTTON_EVENT_X_OFFSET])^;
end;

function x11_button_event_y(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_BUTTON_EVENT_Y_OFFSET])^;
end;

function x11_motion_event_x(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_MOTION_EVENT_X_OFFSET])^;
end;

function x11_motion_event_y(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_MOTION_EVENT_Y_OFFSET])^;
end;

function x11_configure_event_window(const AEvent: TX11Event): TX11Window;
begin
  Result := PTX11Window(@AEvent[X11_CONFIGURE_EVENT_WINDOW_OFFSET])^;
end;

function x11_configure_event_width(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_CONFIGURE_EVENT_WIDTH_OFFSET])^;
end;

function x11_configure_event_height(const AEvent: TX11Event): Int32;
begin
  Result := PInt32(@AEvent[X11_CONFIGURE_EVENT_HEIGHT_OFFSET])^;
end;

function x11_client_message_l0(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_CLIENT_MESSAGE_DATA_OFFSET])^;
end;

end.
