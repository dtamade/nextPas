unit nextpas.core.platform.x11.ffi;

{$I nextpas.core.settings.inc}

// X11 FFI type and function pointer declarations.
//
// Types, constants, and typed function pointer globals for the subset
// of libX11 needed by nextPas/core window management. Zero implementation
// logic -- the companion unit nextpas.core.platform.x11 handles loading.

interface

type
  { Opaque X11 handles }
  TX11Display = type Pointer;
  TX11Window  = type UInt64;
  TX11Colormap = type UInt64;
  TX11Atom     = type UInt64;
  TX11KeyCode  = type Byte;
  TX11KeySym   = type UInt32;
  TX11Status   = type Int32;

  { XEvent buffer -- 96 bytes on x86_64, matches C union XEvent.
    Layout: type(4) + pad(4) + serial(8) + send_event(4) + pad(4) + display(8)
            = 32 bytes before window(8), then 56 bytes rest. }
  TX11Event = record
    FType: Int32;
    FPad: array[0..27] of Byte;  // pad(4) + serial(8) + send_event(4) + pad(4) + display(8)
    FWindow: TX11Window;
    FPad2: array[0..55] of Byte;
  end;

  { XSizeHints for WM_NORMAL_HINTS (partial). }
  TX11SizeHints = record
    Flags: Int64;
    X, Y: Int32;
    Width, Height: Int32;
    MinWidth, MinHeight: Int32;
    MaxWidth, MaxHeight: Int32;
    WidthInc, HeightInc: Int32;
    MinAspect, MaxAspect: record Num, Den: Int32; end;
    BaseWidth, BaseHeight: Int32;
    WinGravity: Int32;
  end;

const
  { X event types }
  X11_KEY_PRESS      = 2;
  X11_KEY_RELEASE    = 3;
  X11_BUTTON_PRESS   = 4;
  X11_BUTTON_RELEASE = 5;
  X11_MOTION_NOTIFY  = 6;
  X11_FOCUS_IN       = 9;
  X11_FOCUS_OUT      = 10;
  X11_EXPOSE         = 12;
  X11_CONFIGURE_NOTIFY = 22;
  X11_CLIENT_MESSAGE = 33;

  { X event masks }
  X11_KEY_PRESS_MASK      = 1 shl 0;
  X11_KEY_RELEASE_MASK    = 1 shl 1;
  X11_BUTTON_PRESS_MASK   = 1 shl 2;
  X11_BUTTON_RELEASE_MASK = 1 shl 3;
  X11_POINTER_MOTION_MASK = 1 shl 6;
  X11_EXPOSURE_MASK       = 1 shl 15;
  X11_STRUCTURE_NOTIFY_MASK = 1 shl 17;
  X11_FOCUS_CHANGE_MASK   = 1 shl 21;

  X11_EVENT_MASK = X11_KEY_PRESS_MASK or X11_KEY_RELEASE_MASK
    or X11_BUTTON_PRESS_MASK or X11_BUTTON_RELEASE_MASK
    or X11_POINTER_MOTION_MASK or X11_EXPOSURE_MASK
    or X11_STRUCTURE_NOTIFY_MASK or X11_FOCUS_CHANGE_MASK;

  { X modifier masks }
  X11_SHIFT_MASK   = 1 shl 0;
  X11_LOCK_MASK    = 1 shl 1;
  X11_CONTROL_MASK = 1 shl 2;
  X11_MOD1_MASK    = 1 shl 3;   // Alt
  X11_MOD4_MASK    = 1 shl 6;   // Super

  { X Event offsets (x86_64) -- relative to start of XEvent.
    Verified with FPC sizeof/offsetof against C XKeyEvent layout. }
  X11_EVENT_TYPE_OFFSET   = 0;
  X11_EVENT_WINDOW_OFFSET = 32;

  { XKeyEvent sub-record offsets }
  X11_KEY_EVENT_STATE_OFFSET   = 80;
  X11_KEY_EVENT_KEYCODE_OFFSET = 84;

  { XButtonEvent sub-record offsets }
  X11_BUTTON_EVENT_BUTTON_OFFSET = 84;
  X11_BUTTON_EVENT_X_OFFSET      = 64;
  X11_BUTTON_EVENT_Y_OFFSET      = 68;

  { XMotionEvent sub-record offsets (same as button: x, y at 64, 68) }
  X11_MOTION_EVENT_X_OFFSET = 64;
  X11_MOTION_EVENT_Y_OFFSET = 68;

  { XConfigureEvent sub-record offsets }
  X11_CONFIGURE_EVENT_WIDTH_OFFSET  = 56;
  X11_CONFIGURE_EVENT_HEIGHT_OFFSET = 60;

  { XClientMessageEvent sub-record offsets }
  X11_CLIENT_MESSAGE_DATA_OFFSET = 52;

  { X11 KeySym constants -- subset needed for terminal key mapping }
  XK_BACKSPACE   = $FF08;
  XK_TAB         = $FF09;
  XK_RETURN      = $FF0D;
  XK_ESCAPE      = $FF1B;
  XK_DELETE       = $FFFF;
  XK_HOME        = $FF50;
  XK_LEFT        = $FF51;
  XK_UP          = $FF52;
  XK_RIGHT       = $FF53;
  XK_DOWN        = $FF54;
  XK_PAGE_UP     = $FF55;
  XK_PAGE_DOWN   = $FF56;
  XK_END         = $FF57;
  XK_INSERT      = $FF63;
  XK_F1          = $FFBE;
  XK_F2          = $FFBF;
  XK_F3          = $FFC0;
  XK_F4          = $FFC1;
  XK_F5          = $FFC2;
  XK_F6          = $FFC3;
  XK_F7          = $FFC4;
  XK_F8          = $FFC5;
  XK_F9          = $FFC6;
  XK_F10         = $FFC7;
  XK_F11         = $FFC8;
  XK_F12         = $FFC9;

  { X11 protocol atoms }
  X11_XA_PRIMARY     = 1;
  X11_XA_STRING      = 31;
  X11_XA_ATOM        = 4;
  X11_XA_CARDINAL    = 6;

  X11_PROP_MODE_REPLACE = 0;

  { X11 CW masks for XCreateWindow }
  X11_CW_EVENT_MASK = 1 shl 11;

  { X11 return codes }
  X11_SUCCESS = 0;

type
  { Pointer types used by function signatures }
  PTX11KeySym = ^TX11KeySym;
  PTX11Atom = ^TX11Atom;

  { XOpenDisplay }
  TXOpenDisplay = function(AName: PAnsiChar): TX11Display; cdecl;
  { XCloseDisplay }
  TXCloseDisplay = function(ADisplay: TX11Display): Int32; cdecl;
  { XDefaultRootWindow }
  TXDefaultRootWindow = function(ADisplay: TX11Display): TX11Window; cdecl;
  { XDefaultScreen }
  TXDefaultScreen = function(ADisplay: TX11Display): Int32; cdecl;
  { XDefaultVisual }
  TXDefaultVisual = function(ADisplay: TX11Display; AScreen: Int32): Pointer; cdecl;
  { XDefaultColormap }
  TXDefaultColormap = function(ADisplay: TX11Display; AScreen: Int32): TX11Colormap; cdecl;
  { XBlackPixel }
  TXBlackPixel = function(ADisplay: TX11Display; AScreen: Int32): UInt64; cdecl;
  { XWhitePixel }
  TXWhitePixel = function(ADisplay: TX11Display; AScreen: Int32): UInt64; cdecl;
  { XCreateSimpleWindow }
  TXCreateSimpleWindow = function(ADisplay: TX11Display;
    AParent: TX11Window; AX, AY, AWidth, AHeight, ABorderWidth: Int32;
    ABorder: UInt64; ABackground: UInt64): TX11Window; cdecl;
  { XCreateWindow }
  TXCreateWindow = function(ADisplay: TX11Display;
    AParent: TX11Window; AX, AY, AWidth, AHeight, ABorderWidth, ADepth: Int32;
    AClass: UInt32; AVisual: Pointer; AValueMask: UInt64;
    AAttributes: Pointer): TX11Window; cdecl;
  { XDestroyWindow }
  TXDestroyWindow = function(ADisplay: TX11Display; AW: TX11Window): Int32; cdecl;
  { XMapWindow }
  TXMapWindow = function(ADisplay: TX11Display; AW: TX11Window): Int32; cdecl;
  { XUnmapWindow }
  TXUnmapWindow = function(ADisplay: TX11Display; AW: TX11Window): Int32; cdecl;
  { XStoreName }
  TXStoreName = function(ADisplay: TX11Display; AW: TX11Window;
    AName: PAnsiChar): Int32; cdecl;
  { XSelectInput }
  TXSelectInput = function(ADisplay: TX11Display; AW: TX11Window;
    AEventMask: Int64): Int32; cdecl;
  { XNextEvent }
  TXNextEvent = function(ADisplay: TX11Display;
    var AEvent: TX11Event): Int32; cdecl;
  { XPending }
  TXPending = function(ADisplay: TX11Display): Int32; cdecl;
  { XSync }
  TXSync = function(ADisplay: TX11Display; ADiscard: Int32): Int32; cdecl;
  { XFlush }
  TXFlush = function(ADisplay: TX11Display): Int32; cdecl;
  { XInternAtom }
  TXInternAtom = function(ADisplay: TX11Display; AName: PAnsiChar;
    AOnlyIfExists: Int32): TX11Atom; cdecl;
  { XSetWMProtocols }
  TXSetWMProtocols = function(ADisplay: TX11Display; AW: TX11Window;
    AProtocols: PTX11Atom; ACount: Int32): Int32; cdecl;
  { XLookupString }
  TXLookupString = function(var AEvent: TX11Event;
    ABuffer: PAnsiChar; ABytes: Int32;
    AKeysym: PTX11KeySym; AStatus: Pointer): Int32; cdecl;
  { XkbKeycodeToKeysym }
  TXkbKeycodeToKeysym = function(ADisplay: TX11Display;
    AKeycode: TX11KeyCode; AGroup, ALevel: Int32): TX11KeySym; cdecl;
  { XChangeProperty }
  TXChangeProperty = function(ADisplay: TX11Display; AW: TX11Window;
    AProperty, AType: TX11Atom; AFormat, AMode: Int32;
    AData: PByte; AElements: Int32): Int32; cdecl;

var
  { Display management }
  XOpenDisplay: TXOpenDisplay;
  XCloseDisplay: TXCloseDisplay;
  XDefaultRootWindow: TXDefaultRootWindow;
  XDefaultScreen: TXDefaultScreen;
  XDefaultVisual: TXDefaultVisual;
  XDefaultColormap: TXDefaultColormap;
  XBlackPixel: TXBlackPixel;
  XWhitePixel: TXWhitePixel;

  { Window management }
  XCreateSimpleWindow: TXCreateSimpleWindow;
  XCreateWindow: TXCreateWindow;
  XDestroyWindow: TXDestroyWindow;
  XMapWindow: TXMapWindow;
  XUnmapWindow: TXUnmapWindow;
  XStoreName: TXStoreName;
  XSelectInput: TXSelectInput;

  { Events }
  XNextEvent: TXNextEvent;
  XPending: TXPending;
  XSync: TXSync;
  XFlush: TXFlush;

  { Atoms and properties }
  XInternAtom: TXInternAtom;
  XSetWMProtocols: TXSetWMProtocols;
  XChangeProperty: TXChangeProperty;

  { Key translation }
  XLookupString: TXLookupString;
  XkbKeycodeToKeysym: TXkbKeycodeToKeysym;

implementation

end.
