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
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.window.sdl2.ffi,
  nextpas.core.window.sdl2.loader;

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GLoopQuit: Boolean = False;
  GLiveWindows: array of Pointer;
  GLiveWindowIDs: array of UInt32;
  GUserEventType: UInt32 = 0;
  GDispLock: ILock;
  GDispRing: array of TWindowProcRef;
  GDispHead: Integer = 0;
  GDispCount: Integer = 0;
  GDestroying: Boolean = False;

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
  if GDispLock = nil then
    GDispLock := TMutex.Create as ILock;
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
  Result := Length(GLiveWindows);
end;

procedure RegisterLive(AWin: Pointer; AID: UInt32);
begin
  SetLength(GLiveWindows, Length(GLiveWindows)+1);
  GLiveWindows[High(GLiveWindows)] := AWin;
  SetLength(GLiveWindowIDs, Length(GLiveWindowIDs)+1);
  GLiveWindowIDs[High(GLiveWindowIDs)] := AID;
end;

procedure UnregisterLive(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = AWin then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      GLiveWindowIDs[I] := GLiveWindowIDs[High(GLiveWindowIDs)];
      SetLength(GLiveWindows, Length(GLiveWindows)-1);
      SetLength(GLiveWindowIDs, Length(GLiveWindowIDs)-1);
      Break;
    end;
end;

function FindWindowByID(AID: UInt32): Pointer;
var
  I: Integer;
begin
  Result := nil;
  if AID = 0 then Exit;
  for I := 0 to High(GLiveWindowIDs) do
    if GLiveWindowIDs[I] = AID then
      Exit(GLiveWindows[I]);
end;

{ ---- Dispatcher helpers ---- }

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

procedure DispatcherGrow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(GDispRing) * 2;
  if LNewCap = 0 then LNewCap := 32;
  SetLength(LNew, LNewCap);
  for I := 0 to GDispCount -1 do
    LNew[I] := GDispRing[(GDispHead + I) mod Length(GDispRing)];
  GDispRing := LNew;
  GDispHead := 0;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GDispLock = nil then
    GDispLock := TMutex.Create as ILock;
  GDispLock.Acquire;
  try
    if GDispCount = Length(GDispRing) then
      DispatcherGrow;
    GDispRing[(GDispHead + GDispCount) mod Length(GDispRing)] := AProc;
    Inc(GDispCount);
  finally
    GDispLock.Release;
  end;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  Result := False;
  AProc := nil;
  if GDispLock = nil then Exit;
  GDispLock.Acquire;
  try
    if GDispCount = 0 then Exit;
    AProc := GDispRing[GDispHead];
    GDispRing[GDispHead] := nil;
    GDispHead := (GDispHead + 1) mod Length(GDispRing);
    Dec(GDispCount);
    Result := True;
  finally
    GDispLock.Release;
  end;
end;

procedure DispatcherDropAll;
var
  I: Integer;
begin
  if GDispLock = nil then Exit;
  GDispLock.Acquire;
  try
    for I := 0 to GDispCount -1 do
      GDispRing[(GDispHead + I) mod Length(GDispRing)] := nil;
    GDispCount := 0;
    GDispHead := 0;
  finally
    GDispLock.Release;
  end;
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
var
  LProc: TWindowProcRef;
begin
  while DispatcherPop(LProc) do
  begin
    try
      if Assigned(LProc) then LProc();
    except
      raise;
    end;
    LProc := nil;
  end;
end;

{ ---- Global dispatcher facade per window ---- }

type
  TWindowSdl2Dispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowSdl2Dispatcher.Create(AOwnerThread: UInt64);
begin
  inherited Create;
  FOwnerThread := AOwnerThread;
end;

function TWindowSdl2Dispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProcRef);
begin
  if not Assigned(AProc) then Exit;
  if GDestroying then Exit;
  DispatcherPush(AProc);
  DispatcherWake;
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProcMethod);
begin
  Post(WindowMethodToRef(AProc));
end;

procedure TWindowSdl2Dispatcher.Post(AProc: TWindowProc);
begin
  Post(WindowProcToRef(AProc));
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
    FOnEvent: TWindowEventHandler;
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
  if AOptions.Width <= 0 then FWidth := DefaultWindowOptions.Width else FWidth := AOptions.Width;
  if AOptions.Height <= 0 then FHeight := DefaultWindowOptions.Height else FHeight := AOptions.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowSdl2Dispatcher.Create(FOwnerThread);

  LFlags := SDL_WINDOW_HIDDEN or SDL_WINDOW_ALLOW_HIGHDPI;
  if FResizable then LFlags := LFlags or SDL_WINDOW_RESIZABLE;

  FHandle := SDL_CreateWindow(PAnsiChar(AnsiString(FTitle)), $2FFF0000, $2FFF0000, FWidth, FHeight, LFlags);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('SDL_CreateWindow failed: ' + string(AnsiString(SDL_GetError)));
  FWindowID := SDL_GetWindowID(FHandle);
  if (AOptions.MinWidth > 0) or (AOptions.MinHeight > 0) then
    SDL_SetWindowMinimumSize(FHandle, AOptions.MinWidth, AOptions.MinHeight);
  if (AOptions.MaxWidth > 0) or (AOptions.MaxHeight > 0) then
    SDL_SetWindowMaximumSize(FHandle, AOptions.MaxWidth, AOptions.MaxHeight);
  if AOptions.Maximized then
    SDL_MaximizeWindow(FHandle);

  RegisterLive(Pointer(Self), FWindowID);
end;

destructor TWindowSdl2.Destroy;
begin
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

procedure TWindowSdl2.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowSdl2.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  // Drop pending closures? Per CONTRACT §4.1: after last window close, post dropped.
  // We keep global queue but Close no longer dispatches events.
  if FHandle <> nil then
  begin
    SDL_DestroyWindow(FHandle);
    FHandle := nil;
  end;
  UnregisterLive(Pointer(Self));
  if SdlLiveWindowCount = 0 then
    GLoopQuit := True;
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
  SDL_SetWindowTitle(FHandle, PAnsiChar(AnsiString(ATitle)));
end;

function TWindowSdl2.GetTitle: string;
var
  P: PAnsiChar;
begin
  RequireOpen;
  P := SDL_GetWindowTitle(FHandle);
  if P <> nil then Result := string(AnsiString(P)) else Result := FTitle;
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
  E.Kind := weResized;
  E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
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
  E.Kind := weResized;
  E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
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

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventHandler);
begin
  RequireOpen;
  FOnEvent := AHandler;
end;

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventMethod);
begin
  OnEvent(EventMethodToRef(AHandler));
end;

procedure TWindowSdl2.OnEvent(AHandler: TWindowEventProc);
begin
  OnEvent(EventProcToRef(AHandler));
end;

function CreateWindowSdl2(const AOptions: TWindowOptions): IWindow;
begin
  Result := TWindowSdl2.Create(AOptions);
end;

{ ---- Global SDL event pump ---- }

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
          LEvent.Kind := weCloseRequested;
          LEvent.Width := 0; LEvent.Height := 0; LEvent.X := 0; LEvent.Y := 0; LEvent.NewScale := 0;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_RESIZED, SDL_WINDOWEVENT_SIZE_CHANGED:
        begin
          LSelf.FWidth := E.window.data1;
          LSelf.FHeight := E.window.data2;
          LEvent.Kind := weResized;
          LEvent.Width := LSelf.FWidth; LEvent.Height := LSelf.FHeight;
          LEvent.X := 0; LEvent.Y := 0; LEvent.NewScale := 0;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_MOVED:
        begin
          LEvent.Kind := weMoved;
          LEvent.Width := 0; LEvent.Height := 0;
          LEvent.X := E.window.data1; LEvent.Y := E.window.data2;
          LEvent.NewScale := 0;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_FOCUS_GAINED:
        begin
          LEvent.Kind := weFocusIn;
          LEvent.Width := 0; LEvent.Height := 0; LEvent.X := 0; LEvent.Y := 0; LEvent.NewScale := 0;
          LSelf.DoDispatch(LEvent);
        end;
      SDL_WINDOWEVENT_FOCUS_LOST:
        begin
          LEvent.Kind := weFocusOut;
          LEvent.Width := 0; LEvent.Height := 0; LEvent.X := 0; LEvent.Y := 0; LEvent.NewScale := 0;
          LSelf.DoDispatch(LEvent);
        end;
    end;
  end;
end;

procedure WindowSdl2RunLoop;
begin
  GLoopQuit := False;
  while not GLoopQuit do
  begin
    while SdlPollAndDispatchOnce do ;
    // If no live windows, exit
    if SdlLiveWindowCount = 0 then Break;
    // Also drain any pending dispatcher closures even without SDL event
    DispatcherDrain;
    // Avoid busy spin: sleep 1ms
    platform_thread_sleep_ms(1);
    if SdlLiveWindowCount = 0 then Break;
  end;
end;

procedure WindowSdl2QuitLoop;
begin
  GLoopQuit := True;
  DispatcherWake;
end;

end.
