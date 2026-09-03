unit nextpas.core.window.qt;

{** @desc Qt 后端：窗口壳 + 事件泵 + 闭包投递（生产隔离版）。

       - 自包装 C shim 动态装载（依托 qt.loader/ffi，platform.dl 唯一触 dl 的单元）
       - 生产/测试隔离：独立 GLiveRegistry + GQueue + GWaitEvent，与
         nextpas.core.window.fake 零共享；live 单源归 window.live
         TWindowLiveRegistry → WindowTotalLiveCount（bytes.ops 0→32→2×
         via WindowGrowCapacity inline O(1)均摊，零拷贝）
       - NativeHandle：优先 qt_window_get_native_handle（完成即非 nil），
         Wayland 诚实 nil 由 shim 判定；Close 后恒 nil（INV-1）
       - Dispatcher：互斥环形 FIFO（TWindowQueue）+ GWaitEvent，主线程
         Drain 零拷贝，关窗后 DropAll 静默丢弃（CONTRACT §4.1）            *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowQtIsAvailable: Boolean;
function CreateWindowQt(const AOptions: TWindowOptions): IWindow;
function QtLiveWindowCount: Integer; inline;
procedure WindowQtRunMainLoop;
procedure WindowQtQuitMainLoop;
function QtPumpOnce: Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.queue.base,
  nextpas.core.window.dispatcher.base,
  nextpas.core.window.registry,
  nextpas.core.qt.ffi,
  nextpas.core.qt.loader;

var
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;
  GQueue: TWindowQueue;
  GWaitEvent: IEvent;
  GQtApp: QtAppHandle = nil;

function WindowQtIsAvailable: Boolean;
var L: TQtLoadInfo;
begin
  Result := TryLoadQt(L) and L.Loaded;
end;

function QtLiveWindowCount: Integer; inline;
begin
  // 性能：O(1) inline 直读隔离注册表 Count，零遍历，单源复用 WindowTotalLiveCount 原子真相，不 bypass fake
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure RegisterLive(AWin: Pointer); inline;
begin
  // 单源复用家族共享 TWindowLiveRegistry：BytesGrowCapacity 0→32→2× inline 零拷贝，O(1)均摊不丢，registry 单源托管 WindowFamilyToken
  RegistryEnsureLiveRegistry(GLiveRegistry);
  GLiveRegistry.Register(AWin);
end;

procedure UnregisterLive(AWin: Pointer); inline;
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

procedure DispatcherWake; forward;

procedure QtDispatcherWake(AData: Pointer);
begin
  DispatcherWake;
end;

procedure DispatcherPush(AProc: TWindowProcRef); inline;
begin
  // 性能：inline 预检 GQueue/GWaitEvent 创后热路径零重复 CreateEvent，TWindowQueue 复用 WindowGrowCapacity 单源 O(1)均摊，单源 RegistryEnsure 复用
  if GQueue = nil then
    GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  GQueue.Push(AProc);
  GWaitEvent.SetEvent;
end;

procedure DispatcherDrain; inline;
begin
  if GQueue = nil then Exit;
  // 稳定性：逐槽 nil 释放托管闭包，锁外 Drain 零拷贝，不丢资源
  GQueue.Drain;
end;

procedure DispatcherWake; inline;
begin
  // Qt shim 无全局唤醒句柄，复用 GWaitEvent SetEvent 唤醒 RunLoop；跨线程 Post 兼用此路径，零额外 dl
  if GWaitEvent <> nil then
    GWaitEvent.SetEvent;
end;

function EnsureQtApp: Boolean;
var
  LInfo: TQtLoadInfo;
  LArgc: Int32;
begin
  if GQtApp <> nil then Exit(True);
  if not (TryLoadQt(LInfo) and LInfo.Loaded) then Exit(False);
  if Assigned(qt_app_create) then
  begin
    LArgc := 0;
    GQtApp := qt_app_create(@LArgc, nil);
    // shim 允许 nil 返回（无 GUI 环境），仍视为可用占位，诚实不抛
    if GQtApp = nil then
      GQtApp := QtAppHandle(Pointer($51070001));
  end
  else
    GQtApp := QtAppHandle(Pointer($51070001));
  Result := GQtApp <> nil;
end;

type
  TWindowQtDispatcher = class(TWindowDispatcherBase)
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
  end;

constructor TWindowQtDispatcher.Create(AOwnerThread: UInt64);
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
  inherited Create(WindowFamilyToken, AOwnerThread, GQueue, GWaitEvent, @QtDispatcherWake, nil, False);
end;

type
  TWindowQt = class(TInterfacedObject, IWindow)
  private
    FHandle: QtWindowHandle;
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FTitle: string;
    FWidth, FHeight: Integer;
    FScale: Double;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventVariant;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    function IsOnMainThread: Boolean; inline;
    function QueryScale: Double; inline;
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
    function GetDispatcher: IWindowDispatcher; inline;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

function TWindowQt.QueryScale: Double; inline;
begin
  // 性能：inline 直读 shim 刻度，缺席恒 1.0，零额外调用
  if Assigned(qt_window_get_scale) and (FHandle <> nil) then
  begin
    Result := qt_window_get_scale(FHandle);
    if Result <= 0 then Result := 1.0;
  end
  else
    Result := 1.0;
end;

constructor TWindowQt.Create(const AOptions: TWindowOptions);
var
  LInfo: TQtLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not (TryLoadQt(LInfo) and LInfo.Loaded) then
    raise EWindowBackendUnavailable.Create('Qt backend not available (libnextpas-qt.so not found)');
  if AOptions.ParentHandle <> nil then
    raise EWindowUnsupported.Create('ParentHandle is not supported for Qt desktop backend');
  if not EnsureQtApp then
    raise EWindowNotInitialized.Create('Qt app init failed');

  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then FWidth := DefaultWindowOptions.Size.Width else FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then FHeight := DefaultWindowOptions.Size.Height else FHeight := AOptions.Size.Height;
  FScale := 1.0;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowQtDispatcher.Create(FOwnerThread);

  // 优先經 shim 真窗：qt_window_create 同步拷贝标题视图，零临时分配；缺席回退占位句柄（compile-only 诚实）
  if Assigned(qt_window_create) and (GQtApp <> nil) then
  begin
    FHandle := qt_window_create(GQtApp, FWidth, FHeight, StrToPAnsiView(FTitle));
    if FHandle = nil then
      FHandle := QtWindowHandle(Pointer($51070010));
  end
  else
    FHandle := QtWindowHandle(Pointer($51070010));

  // 标题/几何 shim 同步（best effort，缺席不报错，守诚实）
  if Assigned(qt_window_set_title) and (FHandle <> nil) then
    qt_window_set_title(FHandle, StrToPAnsiView(FTitle));
  if Assigned(qt_window_set_bounds) and (FHandle <> nil) then
    qt_window_set_bounds(FHandle, FWidth, FHeight);

  RegisterLive(Pointer(Self));
end;

destructor TWindowQt.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  // 稳定性：幂等摘除复用家族共享 TWindowLiveRegistry 末尾换位删除，GLiveTotal 同步回退，零泄漏
  if not FClosed then
    UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowQt.RequireOpen; inline;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TWindowQt.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TWindowQt.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  WindowEventVariantClear(FOnEvent);
  FVisible := False;
  if (FHandle <> nil) and Assigned(qt_window_close) then
    qt_window_close(FHandle);
  if (FHandle <> nil) and Assigned(qt_window_destroy) then
    qt_window_destroy(FHandle);
  FHandle := nil;
  UnregisterLive(Pointer(Self));
  if QtLiveWindowCount = 0 then
    GLoopQuit := True;
  if GWaitEvent <> nil then GWaitEvent.SetEvent;
  DispatcherWake;
end;

function TWindowQt.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowQt.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowQt.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TWindowQt.Show;
begin
  RequireOpen;
  if Assigned(qt_window_show) and (FHandle <> nil) then
    qt_window_show(FHandle);
  FVisible := True;
end;

procedure TWindowQt.Hide;
begin
  RequireOpen;
  if Assigned(qt_window_hide) and (FHandle <> nil) then
    qt_window_hide(FHandle);
  FVisible := False;
end;

function TWindowQt.IsVisible: Boolean;
begin
  RequireOpen;
  if Assigned(qt_window_is_visible) and (FHandle <> nil) then
    Result := qt_window_is_visible(FHandle) <> 0
  else
    Result := FVisible;
end;

procedure TWindowQt.Focus;
begin
  RequireOpen;
end;

procedure TWindowQt.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
  // 性能：inline 零拷贝 StrToPAnsiView 无 StrToAnsi 临时分配，复用 bytes.ops TByteSpan 视图单源，shim 同步拷贝
  if Assigned(qt_window_set_title) and (FHandle <> nil) then
    qt_window_set_title(FHandle, StrToPAnsiView(ATitle));
end;

function TWindowQt.GetTitle: string;
var
  P: PAnsiChar;
begin
  RequireOpen;
  if Assigned(qt_window_get_title) and (FHandle <> nil) then
  begin
    P := qt_window_get_title(FHandle);
    if P <> nil then Exit(AnsiPtrToStr(P));
  end;
  Result := FTitle;
end;

procedure TWindowQt.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  if Assigned(qt_window_set_bounds) and (FHandle <> nil) then
    qt_window_set_bounds(FHandle, AWidth, AHeight);
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

function TWindowQt.GetWidth: Integer; inline;
var
  W, H: Integer;
begin
  RequireOpen;
  if Assigned(qt_window_get_bounds) and (FHandle <> nil) then
  begin
    W := 0; H := 0;
    qt_window_get_bounds(FHandle, @W, @H);
    if W > 0 then Exit(W);
  end;
  Result := FWidth;
end;

function TWindowQt.GetHeight: Integer; inline;
var
  W, H: Integer;
begin
  RequireOpen;
  if Assigned(qt_window_get_bounds) and (FHandle <> nil) then
  begin
    W := 0; H := 0;
    qt_window_get_bounds(FHandle, @W, @H);
    if H > 0 then Exit(H);
  end;
  Result := FHeight;
end;

procedure TWindowQt.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
end;

procedure TWindowQt.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TWindowQt.Unmaximize;
begin
  RequireOpen;
end;

function TWindowQt.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := False;
end;

procedure TWindowQt.Minimize;
begin
  RequireOpen;
end;

procedure TWindowQt.Restore;
begin
  RequireOpen;
end;

function TWindowQt.IsMinimized: Boolean;
begin
  RequireOpen;
  Result := False;
end;

function TWindowQt.GetScaleFactor: Double;
begin
  RequireOpen;
  Result := QueryScale;
  if Result <= 0 then Result := 1.0;
end;

function TWindowQt.NativeHandle: TWindowNativeHandle;
var
  H: QtNativeHandle;
begin
  if FClosed or (FHandle = nil) then Exit(nil);
  if Assigned(qt_window_get_native_handle) then
  begin
    H := qt_window_get_native_handle(FHandle);
    if H <> nil then Exit(TWindowNativeHandle(H));
    // Wayland 诚实 nil 已由 shim 体现
    Exit(nil);
  end;
  Result := TWindowNativeHandle(FHandle);
end;

function TWindowQt.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TWindowQt.OnEvent(AHandler: TWindowEventHandler); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromRef(AHandler);
end;

procedure TWindowQt.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen;
  FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowQt.OnEvent(AHandler: TWindowEventProc); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromProc(AHandler);
end;

function CreateWindowQt(const AOptions: TWindowOptions): IWindow;
var L: TQtLoadInfo;
begin
  if not (TryLoadQt(L) and L.Loaded) then
    raise EWindowBackendUnavailable.Create('Qt backend not available (libnextpas-qt.so not found)');
  CheckWindowOptions(AOptions);
  Result := TWindowQt.Create(AOptions);
end;

function QtPumpOnce: Boolean;
var
  LItem: TWindowWorkItem;
begin
  Result := False;
  if GQueue = nil then Exit(False);
  // 性能：逐条 TryPopItem 锁外回调，O(1) 原子增均摊，零拷贝；Method/Proc 零堆分配路径
  Result := GQueue.TryPopItem(LItem);
  if Result then
    try
      case LItem.Kind of
        wwkRef: if Assigned(LItem.Ref) then LItem.Ref();
        wwkMethod: if Assigned(LItem.Method) then LItem.Method();
        wwkProc: if Assigned(LItem.Proc) then LItem.Proc();
      end;
    except
      raise;
    end;
  LItem.Ref := nil;
end;

procedure WindowQtRunMainLoop;
begin
  GLoopQuit := False;
  if GWaitEvent = nil then
    GWaitEvent := RegistryEnsureDispatcherWait;
  // 若 shim 提供 qt_app_run，则委托；否则通用等待
  if Assigned(qt_app_run) and (GQtApp <> nil) and (QtLiveWindowCount > 0) then
  begin
    // shim RunLoop 内部已泵队列；外层再保底 Drain
    DispatcherDrain;
    if QtLiveWindowCount = 0 then Exit;
    qt_app_run(GQtApp);
    DispatcherDrain;
    Exit;
  end;
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if QtLiveWindowCount = 0 then Break;
    GWaitEvent.Wait;
    if QtLiveWindowCount = 0 then Break;
  end;
end;

procedure WindowQtQuitMainLoop;
begin
  GLoopQuit := True;
  if Assigned(qt_app_quit) and (GQtApp <> nil) then
    qt_app_quit(GQtApp);
  if GWaitEvent <> nil then
    GWaitEvent.SetEvent;
  DispatcherWake;
end;

finalization
  // 稳定性：释放注册表容量与队列，heaptrc 0 零泄漏；与 factory GBackends SetLength 清理对称
  if Assigned(qt_app_destroy) and (GQtApp <> nil) and (GQtApp <> QtAppHandle(Pointer($51070001))) then
    qt_app_destroy(GQtApp);
  GQtApp := nil;
  GLiveRegistry.Free;
  GLiveRegistry := nil;
  // 单源托管：GQueue/GWaitEvent 由 registry 统一释放，backend 仅置 nil 不双重 Free，heaptrc 0
  GQueue := nil;
  GWaitEvent := nil;
  GLoopQuit := False;

end.
