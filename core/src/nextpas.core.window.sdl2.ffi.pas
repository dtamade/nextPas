unit nextpas.core.window.sdl2.ffi;

{** @desc SDL2 窗口子集 ABI 声明层（window 家族）。
       只含窗口壳必需的 SDL 类型与函数指针变量——无逻辑、无 external；
       绑定真相归 window.sdl2.loader（经 nextpas.core.platform.dl）。
       版本：SDL2 ≥2.0；display scale 仅 ≥2.24 可用。 *}

{$I nextpas.core.settings.inc}

interface

type
  SDL_bool = LongBool;

const
  SDL_INIT_VIDEO = $00000020;

  SDL_WINDOW_FULLSCREEN         = $00000001;
  SDL_WINDOW_SHOWN              = $00000004;
  SDL_WINDOW_HIDDEN             = $00000008;
  SDL_WINDOW_RESIZABLE          = $00000020;
  SDL_WINDOW_MINIMIZED          = $00000040;
  SDL_WINDOW_MAXIMIZED          = $00000080;
  SDL_WINDOW_ALLOW_HIGHDPI      = $00002000;

  SDL_WINDOWEVENT_NONE          = 0;
  SDL_WINDOWEVENT_SHOWN         = 1;
  SDL_WINDOWEVENT_HIDDEN        = 2;
  SDL_WINDOWEVENT_EXPOSED       = 3;
  SDL_WINDOWEVENT_MOVED         = 4;
  SDL_WINDOWEVENT_RESIZED       = 5;
  SDL_WINDOWEVENT_SIZE_CHANGED  = 6;
  SDL_WINDOWEVENT_MINIMIZED     = 7;
  SDL_WINDOWEVENT_MAXIMIZED     = 8;
  SDL_WINDOWEVENT_RESTORED      = 9;
  SDL_WINDOWEVENT_ENTER         = 10;
  SDL_WINDOWEVENT_LEAVE         = 11;
  SDL_WINDOWEVENT_FOCUS_GAINED  = 12;
  SDL_WINDOWEVENT_FOCUS_LOST    = 13;
  SDL_WINDOWEVENT_CLOSE         = 14;

  SDL_QUIT                      = $100;
  SDL_WINDOWEVENT               = $200;
  SDL_USEREVENT                 = $8000;

type
  PSDL_Window = Pointer;

  TSDL_WindowEvent = packed record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    event: UInt8;
    padding1: UInt8;
    padding2: UInt8;
    padding3: UInt8;
    data1: Int32;
    data2: Int32;
  end;

  TSDL_UserEvent = packed record
    type_: UInt32;
    timestamp: UInt32;
    windowID: UInt32;
    code: Int32;
    data1: Pointer;
    data2: Pointer;
  end;

  // Minimal SDL_Event union: type + 56 bytes payload (enough for window/user)
  TSDL_Event = packed record
    case Integer of
      0: (type_: UInt32);
      1: (window: TSDL_WindowEvent);
      2: (user: TSDL_UserEvent);
      3: (padding: array[0..127] of Byte);
  end;
  PSDL_Event = ^TSDL_Event;

  TSDL_SysWMinfoVersion = packed record
    major: UInt8;
    minor: UInt8;
    patch: UInt8;
  end;

  // SDL_SysWMinfo minimal: only version + subsystem + window handle union
  // Real struct is union per-subsystem; we expose enough to call GetWMInfo safely.
  // Size: 64+ bytes; we allocate 512 for safety.
  TSDL_SysWMinfo = packed record
    version: TSDL_SysWMinfoVersion;
    subsystem: UInt32;
    // Opaque tail: actual union (info.x11.window etc)
    tail: array[0..511] of Byte;
  end;
  PSDL_SysWMinfo = ^TSDL_SysWMinfo;

const
  SDL_SYSWM_UNKNOWN  = 0;
  SDL_SYSWM_WINDOWS  = 1;
  SDL_SYSWM_X11      = 2;
  SDL_SYSWM_DIRECTFB = 3;
  SDL_SYSWM_COCOA    = 4;
  SDL_SYSWM_UIKIT    = 5;
  SDL_SYSWM_WAYLAND  = 6;

var
  SDL_Init: function(flags: UInt32): Int32; cdecl;
  SDL_QuitProc: procedure; cdecl;
  SDL_GetError: function: PAnsiChar; cdecl;
  SDL_CreateWindow: function(title: PAnsiChar; x, y, w, h: Int32; flags: UInt32): PSDL_Window; cdecl;
  SDL_DestroyWindow: procedure(win: PSDL_Window); cdecl;
  SDL_ShowWindow: procedure(win: PSDL_Window); cdecl;
  SDL_HideWindow: procedure(win: PSDL_Window); cdecl;
  SDL_SetWindowTitle: procedure(win: PSDL_Window; title: PAnsiChar); cdecl;
  SDL_GetWindowTitle: function(win: PSDL_Window): PAnsiChar; cdecl;
  SDL_SetWindowSize: procedure(win: PSDL_Window; w, h: Int32); cdecl;
  SDL_GetWindowSize: procedure(win: PSDL_Window; w, h: PInt32); cdecl;
  SDL_SetWindowMinimumSize: procedure(win: PSDL_Window; min_w, min_h: Int32); cdecl;
  SDL_SetWindowMaximumSize: procedure(win: PSDL_Window; max_w, max_h: Int32); cdecl;
  SDL_SetWindowResizable: procedure(win: PSDL_Window; resizable: SDL_bool); cdecl;
  SDL_MaximizeWindow: procedure(win: PSDL_Window); cdecl;
  SDL_MinimizeWindow: procedure(win: PSDL_Window); cdecl;
  SDL_RestoreWindow: procedure(win: PSDL_Window); cdecl;
  SDL_GetWindowFlags: function(win: PSDL_Window): UInt32; cdecl;
  SDL_GetWindowID: function(win: PSDL_Window): UInt32; cdecl;
  SDL_GetWindowFromID: function(id: UInt32): PSDL_Window; cdecl;
  SDL_GetWindowDisplayIndex: function(win: PSDL_Window): Int32; cdecl;
  // Optional ≥2.24: returns display scale, otherwise absent
  SDL_GetWindowDisplayScale: function(win: PSDL_Window): Single; cdecl;
  SDL_GetWindowWMInfo: function(win: PSDL_Window; info: PSDL_SysWMinfo): SDL_bool; cdecl;
  SDL_PollEvent: function(evt: PSDL_Event): Int32; cdecl;
  SDL_PushEvent: function(evt: PSDL_Event): Int32; cdecl;
  SDL_RegisterEvents: function(num: Int32): UInt32; cdecl;

implementation

end.
