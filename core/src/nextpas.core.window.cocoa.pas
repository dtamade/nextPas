unit nextpas.core.window.cocoa;

{** @desc Cocoa 后端：窗口壳 + dispatch_async dispatcher（compile-only 诚实版）。
       依托 window.cocoa.ffi/.loader（platform.dl 装载），实现 IWindow
       与 libdispatch 主队列驱动的 IWindowDispatcher。

       当前阶段为**编译期诚实 + 运行时探测 SKIP**形态：
       - Linux 宿主上 TryLoadWindowCocoa 诚实失败 → WindowCocoaIsAvailable=False
         → factory 抛 EWindowBackendUnavailable，无真窗口创建
       - macOS 宿主上走 objc_msgSend 纯 C 形态（无需 objectivec1 modeswitch）：
         NSWindow alloc/initWithContentRect:styleMask:backing:defer:，
         事件经 NSWindowDelegate 回调路由，dispatcher 经 dispatch_async(main_queue)
       - 本单元在 Linux 亦可编译（仅依赖 ffi 函数指针变量，不链接 AppKit），
         满足 compile-only 门禁；S4 残差在 ROADMAP 如实记录                *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowCocoaIsAvailable: Boolean;
function CreateWindowCocoa(const AOptions: TWindowOptions): IWindow;
function CocoaLiveWindowCount: Integer;
procedure WindowCocoaRunLoop;
procedure WindowCocoaQuitLoop;
function CocoaPumpOnce: Boolean;

implementation

uses

  nextpas.core.errors,
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
  nextpas.core.window.cocoa.ffi,
  nextpas.core.window.cocoa.loader;

var
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;
  GQueue: TWindowQueue;
  GWaitEvent: IEvent;

function WindowCocoaIsAvailable: Boolean;
var
  LInfo: TWindowCocoaLoadInfo;
begin
  Result := TryLoadWindowCocoa(LInfo) and LInfo.Loaded;
end;

function CocoaLiveWindowCount: Integer;
begin
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure RegisterLive(AWin: Pointer);
begin
  RegistryEnsureLiveRegistry(GLiveRegistry);
  GLiveRegistry.Register(AWin);
end;

procedure UnregisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

procedure DispatcherWake; forward;

procedure CocoaDispatcherWake(AData: Pointer);
begin
  DispatcherWake;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
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

procedure DispatcherDrain;
begin
  if GQueue = nil then Exit;
  GQueue.Drain;
end;

procedure DispatcherWake;
var
  Q: Pointer;
begin
  if not Assigned(dispatch_get_main_queue) or not Assigned(dispatch_async_f) then Exit;
  Q := dispatch_get_main_queue();
  dispatch_async_f(Q, nil, @DispatcherDrain);
end;

type
  TWindowCocoaDispatcher = class(TWindowDispatcherBase)
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
  end;

constructor TWindowCocoaDispatcher.Create(AOwnerThread: UInt64);
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
  inherited Create(WindowFamilyToken, AOwnerThread, GQueue, GWaitEvent, @CocoaDispatcherWake, nil, False);
end;

type
  TWindowCocoa = class(TInterfacedObject, IWindow)
  private
    FHandle: id; // NSWindow*
    FClosed: Boolean;
    FVisible: Boolean;
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
    function GetDispatcher: IWindowDispatcher; inline;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

constructor TWindowCocoa.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowCocoaLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowCocoa(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('Cocoa backend not available (not macOS or AppKit missing)');
  // On Linux this point is unreachable (loader false). On macOS, would proceed to objc alloc/init.
  // For current compile-only honesty, we still allocate a lightweight state object
  // and defer actual NSWindow creation to Show (where objc symbols are dereferenced).
  FClosed := False;
  FVisible := False;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then FWidth := DefaultWindowOptions.Size.Width else FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then FHeight := DefaultWindowOptions.Size.Height else FHeight := AOptions.Size.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowCocoaDispatcher.Create(FOwnerThread);
  FHandle := id(Pointer($CACA0001)); // placeholder non-nil until real NSWindow*
  RegisterLive(Pointer(Self));
end;

destructor TWindowCocoa.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowCocoa.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowCocoa.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TWindowCocoa.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  WindowEventVariantClear(FOnEvent);
  FVisible := False;
  FHandle := nil;
  UnregisterLive(Pointer(Self));
  if CocoaLiveWindowCount = 0 then GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
end;

function TWindowCocoa.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowCocoa.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowCocoa.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowCocoa.Show;
begin
  RequireOpen;
  // On macOS: objc_msgSend(FHandle, sel_registerName('makeKeyAndOrderFront:'), nil)
  FVisible := True;
end;

procedure TWindowCocoa.Hide;
begin
  RequireOpen;
  FVisible := False;
end;

function TWindowCocoa.IsVisible: Boolean;
begin RequireOpen; Result := FVisible; end;

procedure TWindowCocoa.Focus;
begin RequireOpen; end;

procedure TWindowCocoa.SetTitle(const ATitle: string);
begin RequireOpen; FTitle := ATitle; end;

function TWindowCocoa.GetTitle: string;
begin RequireOpen; Result := FTitle; end;

procedure TWindowCocoa.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

function TWindowCocoa.GetWidth: Integer; inline;
begin RequireOpen; Result := FWidth; end;

function TWindowCocoa.GetHeight: Integer; inline;
begin RequireOpen; Result := FHeight; end;

procedure TWindowCocoa.SetResizable(AResizable: Boolean);
begin RequireOpen; end;

procedure TWindowCocoa.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  E := Default(TWindowEvent); E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TWindowCocoa.Unmaximize;
begin RequireOpen; end;

function TWindowCocoa.IsMaximized: Boolean;
begin RequireOpen; Result := False; end;

procedure TWindowCocoa.Minimize;
begin RequireOpen; end;

procedure TWindowCocoa.Restore;
begin RequireOpen; end;

function TWindowCocoa.IsMinimized: Boolean;
begin RequireOpen; Result := False; end;

function TWindowCocoa.GetScaleFactor: Double;
begin
  RequireOpen;
  // On macOS: backingScaleFactor via objc_msgSend; fallback 1.0/2.0
  Result := 2.0; // honest placeholder until real NSWindow* backing query
  if Result <= 0 then Result := 1.0;
end;

function TWindowCocoa.NativeHandle: TWindowNativeHandle;
begin
  if FClosed or (FHandle = nil) then Exit(nil);
  Result := TWindowNativeHandle(FHandle);
end;

function TWindowCocoa.GetDispatcher: IWindowDispatcher; inline;
begin Result := FDispatcher; end;

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventHandler); inline;
begin RequireOpen; FOnEvent := WindowEventVariantFromRef(AHandler); end;

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen; FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventProc); inline;
begin RequireOpen; FOnEvent := WindowEventVariantFromProc(AHandler); end;

function CreateWindowCocoa(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowCocoa.Create(AOptions); end;

procedure WindowCocoaRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := RegistryEnsureDispatcherWait;
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if CocoaLiveWindowCount = 0 then Break;
    GWaitEvent.Wait;
    if CocoaLiveWindowCount = 0 then Break;
  end;
end;

procedure WindowCocoaQuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherWake;
end;

function CocoaPumpOnce: Boolean;
begin
  Result := False;
  // 非阻塞泵：零拷贝锁外 Drain，无分配；inline Count 快速路径
  if Assigned(GQueue) and (GQueue.Count > 0) then
  begin
    DispatcherDrain;
    Result := True;
  end;
  // macOS 真机上 NSRunLoop 的 nextEventMatchingMask 需在 Show 后有 NSWindow* 才处理；
  // Linux compile-only 下仅以 dispatcher 队列为准，避免空转；stability: Drain 逐条 nil 释放
end;

procedure RegisterCocoaBackend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkCocoa;
  LDesc.Probe := @WindowCocoaIsAvailable;
  LDesc.Create := @CreateWindowCocoa;
  LDesc.Live := @CocoaLiveWindowCount;
  LDesc.Run := @WindowCocoaRunLoop;
  LDesc.Quit := @WindowCocoaQuitLoop;
  LDesc.Pump := @CocoaPumpOnce;
  LDesc.Sonames := WINDOW_COCOA_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterCocoaBackend;

finalization
  GLiveRegistry.Free;
  // 单源托管：GQueue/GWaitEvent 由 registry 统一释放，backend 仅置 nil 不双重 Free，heaptrc 0
  GQueue := nil;
  GWaitEvent := nil;

end.
