unit nextpas.core.platform.x11.ffi;

{$I nextpas.core.settings.inc}
{$IF not defined(NEXTPAS_X86_64)}
  {$ERROR 'X11 FFI event offsets are x86_64-only'}
{$ENDIF}

// X11 and GLX FFI type and function pointer declarations.
//
// Types, constants, and typed function pointer globals for the subset
// of libX11 and GLX needed by nextPas/core window management and GL context
// creation. Zero implementation logic -- the companion units
// nextpas.core.platform.x11 and nextpas.core.gpu.gl handle loading.
//
// TX11Event is a flat 192-byte buffer matching C's union XEvent.
// All event field access goes through byte-offset helpers in x11.pas.
// This is the correct model for C unions in Pascal -- named fields
// would create false precision since different event types reuse offsets.

interface

type
  { Opaque X11 handles. Sizes verified against gcc sizeof. }
  TX11Display = type Pointer;   // 8 bytes
  TX11Window  = type UInt64;    // 8 bytes (C unsigned long)
  TX11Colormap = type UInt64;   // 8 bytes
  TX11Atom     = type UInt64;   // 8 bytes (C unsigned long)
  TX11KeyCode  = type UInt32;   // 4 bytes (C unsigned int in XKeyEvent.keycode)
  TX11KeySym   = type UInt64;   // 8 bytes (C unsigned long KeySym)
  TX11Status   = type Int32;

  { Pointer types used by function signatures and event helpers }
  PTX11KeySym = ^TX11KeySym;
  PTX11Atom = ^TX11Atom;
  PTX11Window = ^TX11Window;
  PPByte = ^PByte;

  { GLX opaque handles. Sizes verified against gcc sizeof. }
  TGLXContext   = type Pointer;  { 8 bytes }
  TGLXFBConfig  = type Pointer;  { 8 bytes -- pointer to opaque struct }
  PTGLXFBConfig = ^TGLXFBConfig;

  { XVisualInfo pointer -- used by GLX to return matching visuals. }
  PXVisualInfo = ^TXVisualInfo;
  TXVisualInfo = record
    Visual: Pointer;     { offset 0: XVisualInfo* visual }
    VisualID: UInt64;    { offset 8: VisualID (C unsigned long) }
    Screen: Int32;       { offset 16 }
    Depth: Int32;        { offset 20 }
    CClass: Int32;       { offset 24: C++ keyword guard -- maps to "class" in C }
    RedMask: UInt64;     { offset 32 }
    GreenMask: UInt64;   { offset 40 }
    BlueMask: UInt64;    { offset 48 }
    ColormapSize: Int32; { offset 56 }
    BitsPerRGB: Int32;   { offset 60 }
  end;                   { total 64 bytes, matches C XVisualInfo on x86_64 }

  { XEvent buffer -- 192 bytes on x86_64, matches C union XEvent.
    C declares: long pad[24] = 24 * 8 = 192 bytes.
    We use a flat byte array; all field access goes through offset helpers.
    Verified: gcc sizeof(XEvent) = 192, FPC SizeOf(TX11Event) = 192. }
  TX11Event = array[0..191] of Byte;

const
  { Compile-time size assertion }
  X11_EVENT_EXPECTED_SIZE = 192;

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
  X11_SELECTION_CLEAR = 29;
  X11_SELECTION_REQUEST = 30;
  X11_SELECTION_NOTIFY = 31;
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
    Verified with gcc offsetof against C X11 headers. }
  X11_EVENT_TYPE_OFFSET   = 0;
  X11_EVENT_WINDOW_OFFSET = 32;
  X11_EVENT_TIME_OFFSET   = 56;  // XKeyEvent/XButtonEvent/XMotionEvent time

  { XKeyEvent sub-record offsets (gcc verified: state=80, keycode=84) }
  X11_KEY_EVENT_STATE_OFFSET   = 80;
  X11_KEY_EVENT_KEYCODE_OFFSET = 84;

  { XButtonEvent sub-record offsets (gcc verified: button=84, x=64, y=68) }
  X11_BUTTON_EVENT_BUTTON_OFFSET = 84;
  X11_BUTTON_EVENT_X_OFFSET      = 64;
  X11_BUTTON_EVENT_Y_OFFSET      = 68;

  { XMotionEvent sub-record offsets (same layout as button x/y) }
  X11_MOTION_EVENT_X_OFFSET = 64;
  X11_MOTION_EVENT_Y_OFFSET = 68;

  { XConfigureEvent sub-record offsets (gcc verified: event=32, window=40,
    width=56, height=60). Note: XConfigureEvent has BOTH event(32) and
    window(40) -- x11_event_window reads xany.window at 32 which is
    the "event" field for ConfigureNotify. Use x11_configure_event_window
    for the actual window id. }
  X11_CONFIGURE_EVENT_WINDOW_OFFSET = 40;
  X11_CONFIGURE_EVENT_WIDTH_OFFSET  = 56;
  X11_CONFIGURE_EVENT_HEIGHT_OFFSET = 60;

  { XClientMessageEvent sub-record offsets (gcc verified: data=56) }
  X11_CLIENT_MESSAGE_DATA_OFFSET = 56;

  { XSelectionRequestEvent offsets (gcc verified: requestor=40, selection=48,
    target=56, property=64) }
  X11_SELREQ_REQUESTOR_OFFSET = 40;
  X11_SELREQ_SELECTION_OFFSET = 48;
  X11_SELREQ_TARGET_OFFSET    = 56;
  X11_SELREQ_PROPERTY_OFFSET  = 64;

  { XSelectionEvent offsets (gcc verified: requestor=32, selection=40,
    target=48, property=56) }
  X11_SELNOTIFY_REQUESTOR_OFFSET = 32;
  X11_SELNOTIFY_SELECTION_OFFSET = 40;
  X11_SELNOTIFY_TARGET_OFFSET    = 48;
  X11_SELNOTIFY_PROPERTY_OFFSET  = 56;

  { XSelectionClearEvent offsets (gcc verified: selection=40) }
  X11_SELCLEAR_SELECTION_OFFSET = 40;

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

  { Keypad KeySym constants }
  XK_KP_ENTER    = $FF8D;
  XK_KP_MULTIPLY = $FFAA;
  XK_KP_ADD      = $FFAB;
  XK_KP_SUBTRACT = $FFAD;
  XK_KP_DECIMAL  = $FFAE;
  XK_KP_DIVIDE   = $FFAF;
  XK_KP_0        = $FFB0;
  XK_KP_1        = $FFB1;
  XK_KP_2        = $FFB2;
  XK_KP_3        = $FFB3;
  XK_KP_4        = $FFB4;
  XK_KP_5        = $FFB5;
  XK_KP_6        = $FFB6;
  XK_KP_7        = $FFB7;
  XK_KP_8        = $FFB8;
  XK_KP_9        = $FFB9;

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

  { --- GLX constants --- }

  { glXChooseFBConfig attributes }
  GLX_RGBA            = 4;
  GLX_RENDER_TYPE     = $8011;
  GLX_DRAWABLE_TYPE   = $8010;
  GLX_X_VISUAL_TYPE   = $22;
  GLX_RED_SIZE        = 8;
  GLX_GREEN_SIZE      = 9;
  GLX_BLUE_SIZE       = 10;
  GLX_ALPHA_SIZE      = 11;
  GLX_DEPTH_SIZE      = 12;
  GLX_STENCIL_SIZE    = 13;
  GLX_DOUBLEBUFFER    = 5;
  GLX_SAMPLE_BUFFERS  = $186A0;
  GLX_SAMPLES         = $186A1;

  { glXChooseFBConfig attribute values }
  GLX_RGBA_BIT        = $00000001;
  GLX_WINDOW_BIT      = $00000001;
  GLX_TRUE_COLOR      = $8002;
  GLX_NONE            = $8000;

  { glXGetFBConfigAttrib constant }
  GLX_FBCONFIG_ID     = $8013;

  { glXCreateContextAttribsARB attributes }
  GLX_CONTEXT_MAJOR_VERSION_ARB = $2091;
  GLX_CONTEXT_MINOR_VERSION_ARB = $2092;
  GLX_CONTEXT_FLAGS_ARB         = $2094;
  GLX_CONTEXT_PROFILE_MASK_ARB  = $9126;

  { glXCreateContextAttribsARB attribute values }
  GLX_CONTEXT_CORE_PROFILE_BIT_ARB         = $00000001;
  GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB   = $00000002;

  { glXSwapIntervalEXT attributes }
  GLX_MAX_SWAP_INTERVAL_EXT = $20F2;

type
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
    AEventMask: UInt64): Int32; cdecl;
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
  { XSetSelectionOwner }
  TXSetSelectionOwner = function(ADisplay: TX11Display;
    ASelection: TX11Atom; AOwner: TX11Window; ATime: UInt64): Int32; cdecl;
  { XConvertSelection }
  TXConvertSelection = function(ADisplay: TX11Display;
    ASelection, ATarget, AProperty: TX11Atom;
    ARequestor: TX11Window; ATime: UInt64): Int32; cdecl;
  { XGetWindowProperty }
  TXGetWindowProperty = function(ADisplay: TX11Display; AW: TX11Window;
    AProperty: TX11Atom; ALongOffset, ALongLength: Int64;
    ADelete: Int32; AReqType: TX11Atom;
    AActualType: PTX11Atom; AActualFormat: PInt32;
    ANItems: PUInt64; ABytesAfter: PUInt64;
    APropReturn: PPByte): Int32; cdecl;
  { XDeleteProperty }
  TXDeleteProperty = function(ADisplay: TX11Display;
    AW: TX11Window; AProperty: TX11Atom): Int32; cdecl;
  { XSendEvent }
  TXSendEvent = function(ADisplay: TX11Display; AW: TX11Window;
    APropagate: Int32; AEventMask: Int64;
    var AEvent: TX11Event): Int32; cdecl;
  { XFree }
  TXFree = function(AData: Pointer): Int32; cdecl;
  { XGetSelectionOwner }
  TXGetSelectionOwner = function(ADisplay: TX11Display;
    ASelection: TX11Atom): TX11Window; cdecl;

  { --- GLX function pointer types --- }

  { glXChooseFBConfig }
  TglXChooseFBConfig = function(ADisplay: TX11Display; AScreen: Int32;
    AAttribList: PInt32; out ANElements: Int32): PTGLXFBConfig; cdecl;
  { glXGetVisualFromFBConfig }
  TglXGetVisualFromFBConfig = function(ADisplay: TX11Display;
    AConfig: TGLXFBConfig): PXVisualInfo; cdecl;
  { glXCreateContextAttribsARB }
  TglXCreateContextAttribsARB = function(ADisplay: TX11Display;
    AConfig: TGLXFBConfig; AShareContext: TGLXContext;
    ADirect: Int32; AAttribList: PInt32): TGLXContext; cdecl;
  { glXMakeCurrent }
  TglXMakeCurrent = function(ADisplay: TX11Display; ADrawable: TX11Window;
    AContext: TGLXContext): Int32; cdecl;
  { glXSwapBuffers }
  TglXSwapBuffers = procedure(ADisplay: TX11Display;
    ADrawable: TX11Window); cdecl;
  { glXDestroyContext }
  TglXDestroyContext = procedure(ADisplay: TX11Display;
    AContext: TGLXContext); cdecl;
  { glXQueryExtension -- used to verify GLX is functional on the display }
  TglXQueryExtension = function(ADisplay: TX11Display;
    AErrorBase: PInt32; AEventBase: PInt32): Int32; cdecl;
  { glXSwapIntervalEXT -- extension, resolved via glXGetProcAddress }
  TglXSwapIntervalEXT = procedure(ADisplay: TX11Display;
    ADrawable: TX11Window; AInterval: Int32); cdecl;
  { glXGetProcAddress -- resolves GL and GLX extension function pointers.
    Exported from libGL.so, NOT from libGLX.so. Always use this to resolve
    GL extension functions; dlsym cannot resolve them on GLVND systems. }
  TglXGetProcAddress = function(AProcName: PAnsiChar): Pointer; cdecl;

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

  { Selection protocol }
  XSetSelectionOwner: TXSetSelectionOwner;
  XConvertSelection: TXConvertSelection;
  XGetWindowProperty: TXGetWindowProperty;
  XDeleteProperty: TXDeleteProperty;
  XSendEvent: TXSendEvent;
  XFree: TXFree;
  XGetSelectionOwner: TXGetSelectionOwner;

  { Key translation }
  XLookupString: TXLookupString;
  XkbKeycodeToKeysym: TXkbKeycodeToKeysym;

  { --- GLX function pointer globals --- }
  glXChooseFBConfig: TglXChooseFBConfig;
  glXGetVisualFromFBConfig: TglXGetVisualFromFBConfig;
  glXCreateContextAttribsARB: TglXCreateContextAttribsARB;
  glXMakeCurrent: TglXMakeCurrent;
  glXSwapBuffers: TglXSwapBuffers;
  glXDestroyContext: TglXDestroyContext;
  glXQueryExtension: TglXQueryExtension;
  glXSwapIntervalEXT: TglXSwapIntervalEXT;
  glXGetProcAddress: TglXGetProcAddress;

implementation

end.
