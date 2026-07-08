unit nextpas.core.platform.x11;

{$I nextpas.core.settings.inc}

// X11 and GLX runtime loader and convenience wrappers.
//
// Loads libX11.so.6 via dlopen/dlsym at runtime. Avoids hard link
// dependency so binaries run on headless or Wayland-only systems.
//
// GLX loads libGL.so.1 separately. Most GLX symbols are resolved via
// dlsym; GL extension functions are resolved via glXGetProcAddress at
// runtime in the GPU layer.
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

  GLX_ERR_LOAD_FAILED = -10;

{** @desc 加载 X11 动态库并解析符号（引用计数）
    @return 0 成功，X11_ERR_LOAD_FAILED 加载失败 *}
function x11_load: Int32;

{** @desc 释放 X11 引用（引用计数归零时卸载） *}
procedure x11_unload;

{** @desc 检查 X11 是否已加载
    @return True 已加载 *}
function x11_is_loaded: Boolean;

{** @desc 加载 GLX 动态库并解析符号（引用计数）
    @return 0 成功，GLX_ERR_LOAD_FAILED 加载失败 *}
function glx_load: Int32;

{** @desc 释放 GLX 引用（引用计数归零时卸载） *}
procedure glx_unload;

{** @desc 检查 GLX 是否已加载
    @return True 已加载 *}
function glx_is_loaded: Boolean;

{ --- Event field helpers (byte-offset access into flat TX11Event) --- }

{** @desc 获取事件类型
    @param AEvent X11 事件缓冲区
    @return 事件类型值 *}
function x11_event_type(const AEvent: TX11Event): Int32;

{** @desc 获取事件关联的窗口
    @param AEvent X11 事件缓冲区
    @return 窗口 ID *}
function x11_event_window(const AEvent: TX11Event): TX11Window;

{** @desc 获取事件时间戳
    @param AEvent X11 事件缓冲区
    @return 时间戳（毫秒） *}
function x11_event_time(const AEvent: TX11Event): UInt32;

{** @desc 获取键盘事件修饰键状态
    @param AEvent X11 事件缓冲区
    @return 修饰键掩码 *}
function x11_key_event_state(const AEvent: TX11Event): UInt32;

{** @desc 获取键盘事件键码
    @param AEvent X11 事件缓冲区
    @return 键码值 *}
function x11_key_event_keycode(const AEvent: TX11Event): UInt32;

{** @desc 获取鼠标按钮事件按钮号
    @param AEvent X11 事件缓冲区
    @return 按钮号 *}
function x11_button_event_button(const AEvent: TX11Event): UInt32;

{** @desc 获取鼠标按钮事件 X 坐标
    @param AEvent X11 事件缓冲区
    @return X 坐标 *}
function x11_button_event_x(const AEvent: TX11Event): Int32;

{** @desc 获取鼠标按钮事件 Y 坐标
    @param AEvent X11 事件缓冲区
    @return Y 坐标 *}
function x11_button_event_y(const AEvent: TX11Event): Int32;

{** @desc 获取鼠标移动事件 X 坐标
    @param AEvent X11 事件缓冲区
    @return X 坐标 *}
function x11_motion_event_x(const AEvent: TX11Event): Int32;

{** @desc 获取鼠标移动事件 Y 坐标
    @param AEvent X11 事件缓冲区
    @return Y 坐标 *}
function x11_motion_event_y(const AEvent: TX11Event): Int32;

{** @desc 获取窗口配置事件关联窗口
    @param AEvent X11 事件缓冲区
    @return 窗口 ID *}
function x11_configure_event_window(const AEvent: TX11Event): TX11Window;

{** @desc 获取窗口配置事件宽度
    @param AEvent X11 事件缓冲区
    @return 宽度（像素） *}
function x11_configure_event_width(const AEvent: TX11Event): Int32;

{** @desc 获取窗口配置事件高度
    @param AEvent X11 事件缓冲区
    @return 高度（像素） *}
function x11_configure_event_height(const AEvent: TX11Event): Int32;

{** @desc 获取客户端消息事件第一个 long 数据
    @param AEvent X11 事件缓冲区
    @return 消息数据 *}
function x11_client_message_l0(const AEvent: TX11Event): TX11Atom;

{ --- Selection event helpers --- }

{** @desc 获取选择请求事件的请求者窗口
    @param AEvent X11 事件缓冲区
    @return 请求者窗口 ID *}
function x11_selreq_requestor(const AEvent: TX11Event): TX11Window;

{** @desc 获取选择请求事件的选择原子
    @param AEvent X11 事件缓冲区
    @return 选择原子 *}
function x11_selreq_selection(const AEvent: TX11Event): TX11Atom;

{** @desc 获取选择请求事件的目标原子
    @param AEvent X11 事件缓冲区
    @return 目标原子 *}
function x11_selreq_target(const AEvent: TX11Event): TX11Atom;

{** @desc 获取选择请求事件的属性原子
    @param AEvent X11 事件缓冲区
    @return 属性原子 *}
function x11_selreq_property(const AEvent: TX11Event): TX11Atom;

{** @desc 获取选择通知事件的属性原子
    @param AEvent X11 事件缓冲区
    @return 属性原子 *}
function x11_selnotify_property(const AEvent: TX11Event): TX11Atom;

{** @desc 获取选择清除事件的选择原子
    @param AEvent X11 事件缓冲区
    @return 选择原子 *}
function x11_selclear_selection(const AEvent: TX11Event): TX11Atom;

implementation

var
  GLib: TPlatformLibrary;
  GLoaded: Boolean = False;
  GRefCount: Int32 = 0;
  GGLLib: TPlatformLibrary;
  GGLLoaded: Boolean = False;
  GGLRefCount: Int32 = 0;

{** @desc 尝试从已加载的动态库解析符号
    @param AName 符号名称
    @param APtr 输出符号指针
    @return True 解析成功 *}
function TryLoadSymbol(const AName: PAnsiChar; out APtr: Pointer): Boolean;
begin
  Result := platform_dl_sym(GLib, AName, APtr) = 0;
end;

{** @desc 尝试从已加载的 GL 动态库解析符号
    @param AName 符号名称
    @param APtr 输出符号指针
    @return True 解析成功 *}
function TryLoadGLSymbol(const AName: PAnsiChar; out APtr: Pointer): Boolean;
begin
  Result := platform_dl_sym(GGLLib, AName, APtr) = 0;
end;

function x11_load: Int32;
begin
  if GLoaded then
  begin
    Inc(GRefCount);
    Exit(X11_SUCCESS);
  end;

  if platform_dl_open('libX11.so.6', PLATFORM_DL_NOW, GLib) <> 0 then
    Exit(X11_ERR_LOAD_FAILED);

  { Resolve required symbols. On any failure, unload and return error. }
  if not TryLoadSymbol('XOpenDisplay', Pointer(XOpenDisplay)) or
     not TryLoadSymbol('XCloseDisplay', Pointer(XCloseDisplay)) or
     not TryLoadSymbol('XDefaultRootWindow', Pointer(XDefaultRootWindow)) or
     not TryLoadSymbol('XDefaultScreen', Pointer(XDefaultScreen)) or
     not TryLoadSymbol('XDefaultVisual', Pointer(XDefaultVisual)) or
     not TryLoadSymbol('XDefaultColormap', Pointer(XDefaultColormap)) or
     not TryLoadSymbol('XBlackPixel', Pointer(XBlackPixel)) or
     not TryLoadSymbol('XWhitePixel', Pointer(XWhitePixel)) or
     not TryLoadSymbol('XCreateSimpleWindow', Pointer(XCreateSimpleWindow)) or
     not TryLoadSymbol('XCreateWindow', Pointer(XCreateWindow)) or
     not TryLoadSymbol('XDestroyWindow', Pointer(XDestroyWindow)) or
     not TryLoadSymbol('XMapWindow', Pointer(XMapWindow)) or
     not TryLoadSymbol('XUnmapWindow', Pointer(XUnmapWindow)) or
     not TryLoadSymbol('XStoreName', Pointer(XStoreName)) or
     not TryLoadSymbol('XSelectInput', Pointer(XSelectInput)) or
     not TryLoadSymbol('XNextEvent', Pointer(XNextEvent)) or
     not TryLoadSymbol('XPending', Pointer(XPending)) or
     not TryLoadSymbol('XSync', Pointer(XSync)) or
     not TryLoadSymbol('XFlush', Pointer(XFlush)) or
     not TryLoadSymbol('XInternAtom', Pointer(XInternAtom)) or
     not TryLoadSymbol('XSetWMProtocols', Pointer(XSetWMProtocols)) or
     not TryLoadSymbol('XLookupString', Pointer(XLookupString)) or
     not TryLoadSymbol('XChangeProperty', Pointer(XChangeProperty)) or
     not TryLoadSymbol('XSetSelectionOwner', Pointer(XSetSelectionOwner)) or
     not TryLoadSymbol('XConvertSelection', Pointer(XConvertSelection)) or
     not TryLoadSymbol('XGetWindowProperty', Pointer(XGetWindowProperty)) or
     not TryLoadSymbol('XDeleteProperty', Pointer(XDeleteProperty)) or
     not TryLoadSymbol('XSendEvent', Pointer(XSendEvent)) or
     not TryLoadSymbol('XFree', Pointer(XFree)) or
     not TryLoadSymbol('XGetSelectionOwner', Pointer(XGetSelectionOwner)) or
     not TryLoadSymbol('XCreateColormap', Pointer(XCreateColormap)) or
     not TryLoadSymbol('XFreeColormap', Pointer(XFreeColormap)) then
  begin
    x11_unload;
    Exit(X11_ERR_LOAD_FAILED);
  end;

  { XkbKeycodeToKeysym is optional -- fallback to XLookupString if absent. }
  if not TryLoadSymbol('XkbKeycodeToKeysym', Pointer(XkbKeycodeToKeysym)) then
    Pointer(XkbKeycodeToKeysym) := nil;

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
  Pointer(XSetSelectionOwner) := nil;
  Pointer(XConvertSelection) := nil;
  Pointer(XGetWindowProperty) := nil;
  Pointer(XDeleteProperty) := nil;
  Pointer(XSendEvent) := nil;
  Pointer(XFree) := nil;
  Pointer(XGetSelectionOwner) := nil;
  Pointer(XCreateColormap) := nil;
  Pointer(XFreeColormap) := nil;
  platform_dl_close(GLib);
  GLoaded := False;
end;

function x11_is_loaded: Boolean;
begin
  Result := GLoaded;
end;

function glx_load: Int32;
begin
  if GGLLoaded then
  begin
    Inc(GGLRefCount);
    Exit(X11_SUCCESS);
  end;

  if platform_dl_open('libGL.so.1', PLATFORM_DL_NOW, GGLLib) <> 0 then
    Exit(GLX_ERR_LOAD_FAILED);

  { Core GLX symbols -- all required. }
  if not TryLoadGLSymbol('glXChooseFBConfig', Pointer(glXChooseFBConfig)) or
     not TryLoadGLSymbol('glXGetVisualFromFBConfig', Pointer(glXGetVisualFromFBConfig)) or
     not TryLoadGLSymbol('glXMakeCurrent', Pointer(glXMakeCurrent)) or
     not TryLoadGLSymbol('glXSwapBuffers', Pointer(glXSwapBuffers)) or
     not TryLoadGLSymbol('glXDestroyContext', Pointer(glXDestroyContext)) or
     not TryLoadGLSymbol('glXQueryExtension', Pointer(glXQueryExtension)) or
     not TryLoadGLSymbol('glXGetProcAddress', Pointer(glXGetProcAddress)) then
  begin
    glx_unload;
    Exit(GLX_ERR_LOAD_FAILED);
  end;

  { Extensions: resolved via GetProcAddress. }
  if @glXGetProcAddress <> nil then
  begin
    Pointer(glXCreateContextAttribsARB) := glXGetProcAddress(
      'glXCreateContextAttribsARB');
    Pointer(glXSwapIntervalEXT) := glXGetProcAddress(
      'glXSwapIntervalEXT');
    Pointer(glXCreatePbuffer) := glXGetProcAddress(
      'glXCreatePbuffer');
    Pointer(glXDestroyPbuffer) := glXGetProcAddress(
      'glXDestroyPbuffer');
  end
  else
  begin
    Pointer(glXCreateContextAttribsARB) := nil;
    Pointer(glXSwapIntervalEXT) := nil;
    Pointer(glXCreatePbuffer) := nil;
    Pointer(glXDestroyPbuffer) := nil;
  end;

  GGLLoaded := True;
  GGLRefCount := 1;
  Result := X11_SUCCESS;
end;

procedure glx_unload;
begin
  if not GGLLoaded then
    Exit;
  Dec(GGLRefCount);
  if GGLRefCount > 0 then
    Exit;

  Pointer(glXChooseFBConfig) := nil;
  Pointer(glXGetVisualFromFBConfig) := nil;
  Pointer(glXCreateContextAttribsARB) := nil;
  Pointer(glXMakeCurrent) := nil;
  Pointer(glXSwapBuffers) := nil;
  Pointer(glXDestroyContext) := nil;
  Pointer(glXQueryExtension) := nil;
  Pointer(glXSwapIntervalEXT) := nil;
  Pointer(glXCreatePbuffer) := nil;
  Pointer(glXDestroyPbuffer) := nil;
  Pointer(glXGetProcAddress) := nil;
  platform_dl_close(GGLLib);
  GGLLoaded := False;
end;

function glx_is_loaded: Boolean;
begin
  Result := GGLLoaded;
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

{ --- Selection event helpers --- }

function x11_selreq_requestor(const AEvent: TX11Event): TX11Window;
begin
  Result := PTX11Window(@AEvent[X11_SELREQ_REQUESTOR_OFFSET])^;
end;

function x11_selreq_selection(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_SELREQ_SELECTION_OFFSET])^;
end;

function x11_selreq_target(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_SELREQ_TARGET_OFFSET])^;
end;

function x11_selreq_property(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_SELREQ_PROPERTY_OFFSET])^;
end;

function x11_selnotify_property(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_SELNOTIFY_PROPERTY_OFFSET])^;
end;

function x11_selclear_selection(const AEvent: TX11Event): TX11Atom;
begin
  Result := PTX11Atom(@AEvent[X11_SELCLEAR_SELECTION_OFFSET])^;
end;

end.
