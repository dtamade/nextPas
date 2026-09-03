unit nextpas.core.window.uikit;

{** @desc UIKit surface attach 后端。
       依托 uikit.ffi/.loader（platform.dl 装载），实现 IWindow 的
       attach 形态：ParentHandle 携带 UIWindow*（宿主提供），几何只读。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowUIKitIsAvailable: Boolean;
function CreateWindowUIKit(const AOptions: TWindowOptions): IWindow;
function UIKitLiveWindowCount: Integer;
procedure WindowUIKitRunLoop;
procedure WindowUIKitQuitLoop;
function UIKitPumpOnce: Boolean;

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
  nextpas.core.window.uikit.ffi,
  nextpas.core.window.uikit.loader;

var
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;
  GQueue: TWindowQueue;
  GWaitEvent: IEvent;

function WindowUIKitIsAvailable: Boolean;
var
  LInfo: TWindowUIKitLoadInfo;
begin
  Result := TryLoadWindowUIKit(LInfo) and LInfo.Loaded;
end;

function UIKitLiveWindowCount: Integer;
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

type
  TWindowUIKitDispatcher = class(TWindowDispatcherBase)
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
  end;

constructor TWindowUIKitDispatcher.Create(AOwnerThread: UInt64);
begin
  if GQueue = nil then GQueue := RegistryEnsureDispatcherQueue;
  if GWaitEvent = nil then GWaitEvent := RegistryEnsureDispatcherWait;
  inherited Create(WindowFamilyToken, AOwnerThread, GQueue, GWaitEvent, nil, nil, False);
end;

type
  TWindowUIKit = class(TInterfacedObject, IWindow, IWindowHost)
  private
    FHandle: TWindowNativeHandle;
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
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

constructor TWindowUIKit.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowUIKitLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowUIKit(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('UIKit backend not available (not iOS host)');
  if AOptions.ParentHandle = nil then
    raise EWindowUnsupported.Create('UIKit attach requires ParentHandle (UIWindow*)');
  FClosed := False;
  FVisible := False;
  FTitle := AOptions.Title;
  if AOptions.Size.Width <= 0 then FWidth := DefaultWindowOptions.Size.Width else FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then FHeight := DefaultWindowOptions.Size.Height else FHeight := AOptions.Size.Height;
  FHandle := AOptions.ParentHandle;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowUIKitDispatcher.Create(FOwnerThread);
  RegisterLive(Pointer(Self));
end;

destructor TWindowUIKit.Destroy;
begin
  WindowEventVariantClear(FOnEvent);
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowUIKit.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowUIKit.DoDispatch(const AEvent: TWindowEvent); inline;
begin
  // 零堆分配分发：Method/Proc 直存 variant，inline 零拷贝
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TWindowUIKit.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  WindowEventVariantClear(FOnEvent);
  FVisible := False;
  FHandle := nil;
  UnregisterLive(Pointer(Self));
  if UIKitLiveWindowCount = 0 then GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
end;

function TWindowUIKit.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowUIKit.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowUIKit.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowUIKit.Show;
begin RequireOpen; FVisible := True; end;

procedure TWindowUIKit.Hide;
begin RequireOpen; FVisible := False; end;

function TWindowUIKit.IsVisible: Boolean;
begin RequireOpen; Result := FVisible; end;

procedure TWindowUIKit.Focus;
begin RequireOpen; end;

procedure TWindowUIKit.SetTitle(const ATitle: string);
begin RequireOpen; FTitle := ATitle; end;

function TWindowUIKit.GetTitle: string;
begin RequireOpen; Result := FTitle; end;

procedure TWindowUIKit.SetBounds(AWidth, AHeight: Integer);
begin RequireOpen; end;

function TWindowUIKit.GetWidth: Integer; inline;
begin RequireOpen; Result := FWidth; end;

function TWindowUIKit.GetHeight: Integer; inline;
begin RequireOpen; Result := FHeight; end;

procedure TWindowUIKit.SetResizable(AResizable: Boolean);
begin RequireOpen; end;

procedure TWindowUIKit.Maximize;
begin RequireOpen; end;

procedure TWindowUIKit.Unmaximize;
begin RequireOpen; end;

function TWindowUIKit.IsMaximized: Boolean;
begin RequireOpen; Result := False; end;

procedure TWindowUIKit.Minimize;
begin RequireOpen; end;

procedure TWindowUIKit.Restore;
begin RequireOpen; end;

function TWindowUIKit.IsMinimized: Boolean;
begin RequireOpen; Result := False; end;

function TWindowUIKit.GetScaleFactor: Double;
begin RequireOpen; Result := 2.0; end;

function TWindowUIKit.NativeHandle: TWindowNativeHandle;
begin
  if FClosed then Exit(nil);
  Result := FHandle;
end;

function TWindowUIKit.GetDispatcher: IWindowDispatcher; inline;
begin Result := FDispatcher; end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventHandler); inline;
begin RequireOpen; FOnEvent := WindowEventVariantFromRef(AHandler); end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  // 零堆分配直存 wedkMethod，inline 零拷贝
  RequireOpen; FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventProc); inline;
begin RequireOpen; FOnEvent := WindowEventVariantFromProc(AHandler); end;

procedure TWindowUIKit.HostResized(AWidth, AHeight: Integer);
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostResized(AWidth, AHeight); end); Exit; end; RequireOpen; if AWidth<0 then AWidth:=0; if AHeight<0 then AHeight:=0; FWidth:=AWidth; FHeight:=AHeight; E := Default(TWindowEvent); E.Kind:=weResized; E.Width:=TWindowPixel(FWidth); E.Height:=TWindowPixel(FHeight); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.Invalid; DoDispatch(E); end;

procedure TWindowUIKit.HostScaleChanged(ANewScale: Double);
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostScaleChanged(ANewScale); end); Exit; end; RequireOpen; E := Default(TWindowEvent); E.Kind:=weScaleChanged; E.Width:=TWindowPixel(0); E.Height:=TWindowPixel(0); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.FromFactor(ANewScale); DoDispatch(E); end;

procedure TWindowUIKit.HostCloseRequested;
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostCloseRequested; end); Exit; end; RequireOpen; E := Default(TWindowEvent); E.Kind:=weCloseRequested; E.Width:=TWindowPixel(0); E.Height:=TWindowPixel(0); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.Invalid; DoDispatch(E); end;

function CreateWindowUIKit(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowUIKit.Create(AOptions); end;

procedure WindowUIKitRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := RegistryEnsureDispatcherWait;
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if UIKitLiveWindowCount = 0 then Break;
    GWaitEvent.Wait;
    if UIKitLiveWindowCount = 0 then Break;
  end;
end;

function UIKitPumpOnce: Boolean;
var LItem: TWindowWorkItem;
begin
  Result := False;
  if GQueue = nil then Exit(False);
  Result := GQueue.TryPopItem(LItem);
  if Result then
    try
      case LItem.Kind of
        wwkRef: if Assigned(LItem.Ref) then LItem.Ref();
        wwkMethod: if Assigned(LItem.Method) then LItem.Method();
        wwkProc: if Assigned(LItem.Proc) then LItem.Proc();
      end;
    except raise; end;
  LItem.Ref := nil;
end;

procedure WindowUIKitQuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherDrain;
end;

procedure RegisterUIKitBackend;
var LDesc: TBackendDesc;
begin
  LDesc.Kind := wkUIKit;
  LDesc.Probe := @WindowUIKitIsAvailable;
  LDesc.Create := @CreateWindowUIKit;
  LDesc.Live := @UIKitLiveWindowCount;
  LDesc.Run := @WindowUIKitRunLoop;
  LDesc.Quit := @WindowUIKitQuitLoop;
  LDesc.Pump := @UIKitPumpOnce;
  LDesc.Sonames := WINDOW_UIKIT_SONAMES;
  RegistryRegister(LDesc);
end;

initialization
  RegisterUIKitBackend;

finalization
  GLiveRegistry.Free;
  // 单源托管：GQueue/GWaitEvent 由 registry 统一释放，backend 仅置 nil 不双重 Free，heaptrc 0
  GQueue := nil;
  GWaitEvent := nil;

end.
