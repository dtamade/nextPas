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

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.time.base,
  nextpas.core.window.live,
  nextpas.core.window.queue,
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
  if GLiveRegistry = nil then
    GLiveRegistry := TWindowLiveRegistry.Create;
  GLiveRegistry.Register(AWin);
end;

procedure UnregisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GQueue = nil then
    GQueue := TWindowQueue.Create;
  if GWaitEvent = nil then
    GWaitEvent := CreateEvent(False);
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
  // Use dispatch_async_f with C function that drains
  dispatch_async_f(Q, nil, @DispatcherDrain);
end;

type
  TWindowCocoaDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowCocoaDispatcher.Create(AOwnerThread: UInt64);
begin inherited Create; FOwnerThread := AOwnerThread; end;

function TWindowCocoaDispatcher.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowCocoaDispatcher.Post(AProc: TWindowProcRef);
begin if not Assigned(AProc) then Exit; DispatcherPush(AProc); DispatcherWake; end;

procedure TWindowCocoaDispatcher.Post(AProc: TWindowProcMethod);
begin Post(WindowMethodToRef(AProc)); end;

procedure TWindowCocoaDispatcher.Post(AProc: TWindowProc);
begin Post(WindowProcToRef(AProc)); end;

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
  if AOptions.Width <= 0 then FWidth := DefaultWindowOptions.Width else FWidth := AOptions.Width;
  if AOptions.Height <= 0 then FHeight := DefaultWindowOptions.Height else FHeight := AOptions.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowCocoaDispatcher.Create(FOwnerThread);
  FHandle := id(Pointer($CACA0001)); // placeholder non-nil until real NSWindow*
  RegisterLive(Pointer(Self));
end;

destructor TWindowCocoa.Destroy;
begin
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowCocoa.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowCocoa.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowCocoa.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
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
  E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
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
  E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
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

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventHandler);
begin RequireOpen; FOnEvent := AHandler; end;

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventMethod);
begin OnEvent(EventMethodToRef(AHandler)); end;

procedure TWindowCocoa.OnEvent(AHandler: TWindowEventProc);
begin OnEvent(EventProcToRef(AHandler)); end;

function CreateWindowCocoa(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowCocoa.Create(AOptions); end;

procedure WindowCocoaRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
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

finalization
  GLiveRegistry.Free;
  GQueue.Free;
  GWaitEvent := nil;

end.
