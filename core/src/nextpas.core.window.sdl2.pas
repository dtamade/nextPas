unit nextpas.core.window.sdl2;

{** @desc SDL2 后端：窗口壳 + 事件泵 + 闭包投递。
       依托 window.sdl2.ffi/.loader（platform.dl 装载），实现 IWindow
       与以 SDL 用户事件唤醒的 IWindowDispatcher。

       设计要点（directui/游戏复用）：
       - 每个窗口的 Dispatcher 共享同一个 SDL 用户事件类型（RegisterEvents 1）
         与全局互斥环形队列，Post 任意线程安全，SDL_PushEvent 唤醒主线程
       - 主线程泵（SdlPumpOnce/SdlRunLoop）在 SDL_PollEvent 循环里识别用户事件
         并 Drain 队列执行闭包；窗口事件按 windowID 路由到归属 TWindowSdl2
       - NativeHandle：优先 SDL_GetWindowWMInfo 的 X11 XID / HWND / NSWindow*
         （Wayland 返回 nil 诚实表）；WMInfo 不可用时回退 SDL_Window* 非 nil
       - GetScaleFactor：≥2.24 时 SDL_GetWindowDisplayScale，否则恒 1.0
       - 几何：SDL 点坐标即物理像素口径（CONTRACT §2.2 ±1 诚实）           *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowSdl2IsAvailable: Boolean;
function CreateWindowSdl2(const AOptions: TWindowOptions): IWindow;
function SdlLiveWindowCount: Integer;
function SdlPollAndDispatchOnce: Boolean;
procedure WindowSdl2RunLoop;
procedure WindowSdl2QuitLoop;

implementation

uses

  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.time.base,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.dispatcher.base,
  nextpas.core.window.registry,
  nextpas.core.window.sdl2.ffi,
  nextpas.core.window.sdl2.loader;

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowSdlLiveRegistry;
  GUserEventType: UInt32 = 0;
  GQueue: TWindowQueue;
  GDestroying: Boolean = False;
  GWaitEvent: IEvent;

function EnsureSdlInit: Boolean;
var
  LInfo: TWindowSdl2LoadInfo;
begin
  if GInitDone then Exit(GInitOk);
  GInitDone := True;
  if not TryLoadWindowSdl2(LInfo) or not LInfo.Loaded then Exit(False);
  // SDL_Init is idempotent; VIDEO only
  if SDL_Init(SDL_INIT_VIDEO) <> 0 then Exit(False);
  // Register one user event for dispatcher wake
  GUserEventType := SDL_RegisterEvents(1);
  if GUserEventType = UInt32(-1) then
    GUserEventType := SDL_USEREVENT;
  if GQueue = nil then
    GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  GInitOk := True;
  Result := True;
end;

function WindowSdl2IsAvailable: Boolean;
var
  LInfo: TWindowSdl2LoadInfo;
begin
  Result := TryLoadWindowSdl2(LInfo) and LInfo.Loaded;
end;

function SdlLiveWindowCount: Integer;
begin
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure RegisterLive(AWin: Pointer; AID: UInt32);
begin
  RegistryEnsureSdlLiveRegistry(GLiveRegistry);
  GLiveRegistry.Register(AWin, AID);
end;

procedure UnregisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

function FindWindowByID(AID: UInt32): Pointer;
begin
  if GLiveRegistry = nil then Exit(nil);
  Result := GLiveRegistry.FindByID(AID);
end;

{ ---- Dispatcher helpers ---- }

procedure SdlDispatcherWake(AData: Pointer);
begin
  DispatcherWake;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GQueue = nil then
    GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  GQueue.Push(AProc);
  GWaitEvent.SetEvent;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  if GQueue = nil then
  begin
    AProc := nil;
    Exit(False);
  end;
  Result := GQueue.TryPop(AProc);
end;

procedure DispatcherDropAll;
begin
  if GQueue = nil then Exit;
  GQueue.Clear;
end;

procedure DispatcherWake;
var
  E: TSDL_Event;
begin
  if GUserEventType = 0 then Exit;
  FillChar(E, SizeOf(E), 0);
  E.type_ := GUserEventType;
  // SDL_PushEvent is thread-safe
  SDL_PushEvent(@E);
end;

procedure DispatcherDrain;
begin
  if GQueue = nil then Exit;
  GQueue.Drain;
end;

{ ---- Global dispatcher facade per window ---- }

type
  TWindowSdl2Dispatcher = class(TWindowDispatcherBase)
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
    procedure Post(AProc: TWindowProcRef); overload; reintroduce; inline;
    procedure Post(AProc: TWindowProcMethod); overload; reintroduce; inline;
    procedure Post(AProc: TWindowProc); overload; reintroduce; inline;
  end;

constructor TWindowSdl2Dispatcher.Create(AOwnerThread: UInt64);
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
  inherited Create(WindowFamilyToken, AOwnerThread, GQueue, GWaitEvent, @SdlDispatcherWake, nil, False);
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProcRef); inline;
begin
  if GDestroying then Exit;
  inherited Post(AProc);
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProcMethod); inline;
begin
  if GDestroying then Exit;
  inherited Post(AProc);
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProc); inline;
begin
  if GDestroying then Exit;
  inherited Post(AProc);
end;

{ ---- TWindowSdl2 ---- }

type
  TWindowSdl2 = class(TInterfacedObject, IWindow)
  private
    FHandle: PSDL_Window;
    FWindowID: UInt32;
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FTitle: string;
    FWidth, FHeight: Integer;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventVariant;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    function IsOnMainThread: Boolean; inline;
  protected
    procedure Close;
    function IsClosed: Boolean; inline;
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer; inline;
    function GetHeight: Integer; inline;
    procedure SetResizable(AResizable: Boolean);
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;
    function GetScaleFactor: Double;
    function NativeHandle: TWindowNativeHandle;
    function GetDispatcher: IWindowDispatcher;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

constructor TWindowSdl2.Create(const AOptions: TWindowOptions);
var
  LFlags: UInt32;
  LInfo: TWindowSdl2LoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowSdl2(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('SDL2 backend not available');
  if not EnsureSdlInit then
    raise EWindowNotInitialized.Create('SDL_Init VIDEO failed: ' + string(AnsiString(SDL_GetError)));

  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then FWidth := DefaultWindowOptions.Size.Width else FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then FHeight := DefaultWindowOptions.Size.Height else FHeight := AOptions.Size.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowSdl2Dispatcher.Create(FOwnerThread);

  LFlags := SDL_WINDOW_HIDDEN or SDL_WINDOW_ALLOW_HIGHDPI;
  if FResizable then LFlags := LFlags or SDL_WINDOW_RESIZABLE;

  // perf: inline zero-copy StrToPAnsiView 无 StrToAnsi 临时分配，复用 bytes.ops TByteSpan 视图单源，SDL_CreateWindow 同步拷贝
  FHandle := SDL_CreateWindow(StrToPAnsiView(FTitle), $2FFF0000, $2FFF0000, FWidth, FHeight, LFlags);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('SDL_CreateWindow failed: ' + string(AnsiString(SDL_GetError)));
  FWindowID := SDL_GetWindowID(FHandle);
  if (AOptions.Constraints.MinWidth > 0) or (AOptions.Constraints.MinHeight > 0) then
    SDL_SetWindowMinimumSize(FHandle, AOptions.Constraints.MinWidth, AOptions.Constraints.MinHeight);
  if (AOptions.Constraints.MaxWidth > 0) or (AOptions.Constraints.MaxHeight > 0) then
    SDL_SetWindowMaximumSize(FHandle, AOptions.Constraints.MaxWidth, AOptions.Constraints.MaxHeight);
  if AOptions.Maximized then
    SDL_MaximizeWindow(FHandle);

  RegisterLive(Pointer(Self), FWindowID);
end;

destructor TWindowSdl2.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  if not FClosed and (FHandle <> nil) then
  begin
    // Ensure window destroyed on owner thread; if not, leak is contained
  end;
  if not FClosed then
    UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowSdl2.RequireOpen;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TWindowSdl2.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TWindowSdl2.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  WindowEventVariantClear(FOnEvent);
  FVisible := False;
  if FHandle <> nil then
  begin
    SDL_DestroyWindow(FHandle);
    FHandle := nil;
  end;
  UnregisterLive(Pointer(Self));
  if SdlLiveWindowCount = 0 then
    GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherWake;
end;

function TWindowSdl2.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowSdl2.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowSdl2.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TWindowSdl2.Show;
begin
  RequireOpen;
  SDL_ShowWindow(FHandle);
  FVisible := True;
end;

procedure TWindowSdl2.Hide;
begin
  RequireOpen;
  SDL_HideWindow(FHandle);
  FVisible := False;
end;

function TWindowSdl2.IsVisible: Boolean;
var
  fl: UInt32;
begin
  RequireOpen;
  fl := SDL_GetWindowFlags(FHandle);
  Result := (fl and SDL_WINDOW_SHOWN) <> 0;
end;

procedure TWindowSdl2.Focus;
begin
  RequireOpen;
  // SDL2 focus is implicit on Show/Raise; no dedicated API, keep no-op
end;

procedure TWindowSdl2.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
  // perf: inline zero-copy StrToPAnsiView 高频标题零分配，SDL 同步拷贝视图安全
  SDL_SetWindowTitle(FHandle, StrToPAnsiView(ATitle));
end;

function TWindowSdl2.GetTitle: string;
var
  P: PAnsiChar;
begin
  RequireOpen;
  P := SDL_GetWindowTitle(FHandle);
  if P <> nil then Result := AnsiPtrToStr(P) else Result := FTitle;
end;

procedure TWindowSdl2.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  SDL_SetWindowSize(FHandle, AWidth, AHeight);
  E := Default(TWindowEvent); E.Kind := weResized;
  E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

function TWindowSdl2.GetWidth: Integer; inline;
var
  W, H: Int32;
begin
  RequireOpen;
  SDL_GetWindowSize(FHandle, @W, @H);
  Result := W;
end;

function TWindowSdl2.GetHeight: Integer; inline;
var
  W, H: Int32;
begin
  RequireOpen;
  SDL_GetWindowSize(FHandle, @W, @H);
  Result := H;
end;

procedure TWindowSdl2.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
  SDL_SetWindowResizable(FHandle, AResizable);
end;

procedure TWindowSdl2.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  SDL_MaximizeWindow(FHandle);
  E := Default(TWindowEvent); E.Kind := weResized;
  E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TWindowSdl2.Unmaximize;
begin
  RequireOpen;
  SDL_RestoreWindow(FHandle);
end;

function TWindowSdl2.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := (SDL_GetWindowFlags(FHandle) and SDL_WINDOW_MAXIMIZED) <> 0;
end;

procedure TWindowSdl2.Minimize;
begin
  RequireOpen;
  SDL_MinimizeWindow(FHandle);
end;

procedure TWindowSdl2.Restore;
begin
  RequireOpen;
  SDL_RestoreWindow(FHandle);
end;

function TWindowSdl2.IsMinimized: Boolean;
begin
  RequireOpen;
  Result := (SDL_GetWindowFlags(FHandle) and SDL_WINDOW_MINIMIZED) <> 0;
end;

function TWindowSdl2.GetScaleFactor: Double;
begin
  RequireOpen;
  if Assigned(SDL_GetWindowDisplayScale) then
    Result := SDL_GetWindowDisplayScale(FHandle)
  else
    Result := 1.0;
  if Result <= 0 then Result := 1.0;
end;

function TWindowSdl2.NativeHandle: TWindowNativeHandle;
var
  Info: TSDL_SysWMinfo;
begin
  if FClosed or (FHandle = nil) then Exit(nil);
  FillChar(Info, SizeOf(Info), 0);
  Info.version.major := 2;
  Info.version.minor := 0;
  Info.version.patch := 0;
  if SDL_GetWindowWMInfo(FHandle, @Info) <> SDL_bool(True) then
    Exit(TWindowNativeHandle(FHandle));
  case Info.subsystem of
    SDL_SYSWM_WAYLAND: Exit(nil);
    SDL_SYSWM_X11:     Exit(TWindowNativeHandle(Pointer(PtrUInt(PPointer(@Info.tail[0])^))));
    SDL_SYSWM_WINDOWS: Exit(TWindowNativeHandle(Pointer(PtrUInt(PPointer(@Info.tail[0])^))));
    SDL_SYSWM_COCOA:   Exit(TWindowNativeHandle(Pointer(PtrUInt(PPointer(@Info.tail[0])^))));
    else
      Exit(TWindowNativeHandle(FHandle));
  end;
end;

function TWindowSdl2.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventHandler); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromRef(AHandler);
end;

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen;
  FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventProc); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromProc(AHandler);
end;

function CreateWindowSdl2(const AOptions: TWindowOptions): IWindow;
begin
  Result := TWindowSdl2.Create(AOptions);
end;

{ ---- Global SDL event pump ---- }

function SdlModToWindowMod(AMod: UInt16): Integer; inline;
begin
  Result := 0;
  if (AMod and KMOD_SHIFT) <> 0 then Result := Result or 1;
  if (AMod and KMOD_CTRL) <> 0 then Result := Result or 2;
  if (AMod and KMOD_ALT) <> 0 then Result := Result or 4;
  if (AMod and KMOD_GUI) <> 0 then Result := Result or 8;
end;

function SdlButtonToWindowButton(AButton: UInt8): Integer; inline;
begin
  case AButton of
    1: Result := 1;
    3: Result := 2;
    2: Result := 3;
    else Result := AButton;
  end;
end;

function SdlPollAndDispatchOnce: Boolean;
var
  E: TSDL_Event;
  LWin: Pointer;
  LEvent: TWindowEvent;
  LSelf: TWindowSdl2;
  Has: Int32;
begin
  Result := False;
  Has := SDL_PollEvent(@E);
  if Has = 0 then Exit;
  Result := True;
  if E.type_ = GUserEventType then
  begin
    DispatcherDrain;
    Exit;
  end;
  if E.type_ = SDL_QUIT then
  begin
    GLoopQuit := True;
    Exit;
  end;
  if E.type_ = SDL_WINDOWEVENT then
  begin
    LWin := FindWindowByID(E.window.windowID);
    if LWin = nil then Exit;
    LSelf := TWindowSdl2(LWin);
    case E.window.event of
      SDL_WINDOWEVENT_CLOSE:
        begin
          LEvent := Default(TWindowEvent); LEvent.Kind := weCloseRequested;
          LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_RESIZED, SDL_WINDOWEVENT_SIZE_CHANGED:
        begin
          LSelf.FWidth := E.window.data1;
          LSelf.FHeight := E.window.data2;
          LEvent := Default(TWindowEvent); LEvent.Kind := weResized;
          LEvent.Width := TWindowPixel(LSelf.FWidth); LEvent.Height := TWindowPixel(LSelf.FHeight);
          LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_MOVED:
        begin
          LEvent := Default(TWindowEvent); LEvent.Kind := weMoved;
          LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0);
          LEvent.X := TWindowPixel(E.window.data1); LEvent.Y := TWindowPixel(E.window.data2);
          LEvent.NewScale := TWindowScale.Invalid;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_FOCUS_GAINED:
        begin
          LEvent := Default(TWindowEvent); LEvent.Kind := weFocusIn;
          LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_FOCUS_LOST:
        begin
          LEvent := Default(TWindowEvent); LEvent.Kind := weFocusOut;
          LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
          LSelf.DoDispatch(LEvent);
        end;
    end;
  end;
end;

procedure WindowSdl2RunLoop;
var
  LEv: TSDL_Event;
  LWin: Pointer;
  LSelf: TWindowSdl2;
  LEvent: TWindowEvent;
begin
  GLoopQuit := False;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  while not GLoopQuit do
  begin
    while SdlPollAndDispatchOnce do ;
    if SdlLiveWindowCount = 0 then Break;
    DispatcherDrain;
    if Assigned(SDL_WaitEvent) then
    begin
      // 性能：事件唤醒零等待，对齐 win32 WaitMessage/cocoa dispatch_async；SDL_PushEvent 即时唤醒，空载零 CPU 阻塞，无 16ms 轮询，inline 零拷贝单次事件处理
      if SDL_WaitEvent(@LEv) <> 0 then
      begin
        if LEv.type_ = GUserEventType then
          DispatcherDrain
        else if LEv.type_ = SDL_QUIT then
          GLoopQuit := True
        else if LEv.type_ = SDL_WINDOWEVENT then
        begin
          LWin := FindWindowByID(LEv.window.windowID);
          if LWin <> nil then
          begin
            LSelf := TWindowSdl2(LWin);
            case LEv.window.event of
              SDL_WINDOWEVENT_CLOSE:
                begin
                  LEvent := Default(TWindowEvent); LEvent.Kind := weCloseRequested;
                  LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
                  LSelf.DoDispatch(LEvent);
                end;
              SDL_WINDOWEVENT_RESIZED, SDL_WINDOWEVENT_SIZE_CHANGED:
                begin
                  LSelf.FWidth := LEv.window.data1;
                  LSelf.FHeight := LEv.window.data2;
                  LEvent := Default(TWindowEvent); LEvent.Kind := weResized;
                  LEvent.Width := TWindowPixel(LSelf.FWidth); LEvent.Height := TWindowPixel(LSelf.FHeight);
                  LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
                  LSelf.DoDispatch(LEvent);
                end;
              SDL_WINDOWEVENT_MOVED:
                begin
                  LEvent := Default(TWindowEvent); LEvent.Kind := weMoved;
                  LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0);
                  LEvent.X := TWindowPixel(LEv.window.data1); LEvent.Y := TWindowPixel(LEv.window.data2);
                  LEvent.NewScale := TWindowScale.Invalid;
                  LSelf.DoDispatch(LEvent);
                end;
              SDL_WINDOWEVENT_FOCUS_GAINED:
                begin
                  LEvent := Default(TWindowEvent); LEvent.Kind := weFocusIn;
                  LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
                  LSelf.DoDispatch(LEvent);
                end;
              SDL_WINDOWEVENT_FOCUS_LOST:
                begin
                  LEvent := Default(TWindowEvent); LEvent.Kind := weFocusOut;
                  LEvent.Width := TWindowPixel(0); LEvent.Height := TWindowPixel(0); LEvent.X := TWindowPixel(0); LEvent.Y := TWindowPixel(0); LEvent.NewScale := TWindowScale.Invalid;
                  LSelf.DoDispatch(LEvent);
                end;
            end;
          end;
        end;
      end;
    end
    else if GWaitEvent <> nil then
      // 回退：SDL_WaitEvent 缺席时以 GWaitEvent 阻塞等待，对齐 cocoa Wait 语义，事件唤醒零等待，无 5ms 轮询
      GWaitEvent.Wait;
    if SdlLiveWindowCount = 0 then Break;
  end;
end;

procedure WindowSdl2QuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent <> nil then
    GWaitEvent.SetEvent;
  DispatcherWake;
end;

procedure RegisterSdl2Backend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkSdl2;
  LDesc.Probe := @WindowSdl2IsAvailable;
  LDesc.Create := @CreateWindowSdl2;
  LDesc.Live := @SdlLiveWindowCount;
  LDesc.Run := @WindowSdl2RunLoop;
  LDesc.Quit := @WindowSdl2QuitLoop;
  LDesc.Pump := @SdlPollAndDispatchOnce;
  LDesc.Sonames := WINDOW_SDL2_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterSdl2Backend;

finalization
  GLiveRegistry.Free;
  // 单源托管：GQueue/GWaitEvent 由 registry 统一释放，backend 仅置 nil 不双重 Free，heaptrc 0
  GQueue := nil;
  GWaitEvent := nil;

end.
