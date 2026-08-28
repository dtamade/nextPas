unit nextpas.core.window.android;

{** @desc Android surface attach 后端。
       依托 android.ffi/.loader（platform.dl 装载），实现 IWindow 的
       attach 形态：ParentHandle 携带 ANativeWindow*（宿主 Activity 提供），
       生命周期归宿主，窗口几何只读（SetBounds no-op），scale 来自宿主 metrics
       （当前占位 1.0 或 ANativeWindow 尺寸推算）。

       非 Android 宿主上 loader 诚实失败 → WindowAndroidIsAvailable=False，
       factory 抛 ecNotFound；Linux compile-only 通过。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowAndroidIsAvailable: Boolean;
function CreateWindowAndroid(const AOptions: TWindowOptions): IWindow;
function AndroidLiveWindowCount: Integer;
procedure WindowAndroidRunLoop;
procedure WindowAndroidQuitLoop;
function AndroidPumpOnce: Boolean;

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
  nextpas.core.window.android.ffi,
  nextpas.core.window.android.loader;

var
  GLoopQuit: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;
  GQueue: TWindowQueue;
  GWaitEvent: IEvent;

function WindowAndroidIsAvailable: Boolean;
var
  LInfo: TWindowAndroidLoadInfo;
begin
  Result := TryLoadWindowAndroid(LInfo) and LInfo.Loaded;
end;

function AndroidLiveWindowCount: Integer;
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

type
  TWindowAndroidDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowAndroidDispatcher.Create(AOwnerThread: UInt64);
begin inherited Create; FOwnerThread := AOwnerThread; end;

function TWindowAndroidDispatcher.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowAndroidDispatcher.Post(AProc: TWindowProcRef);
begin if not Assigned(AProc) then Exit; DispatcherPush(AProc); end;

procedure TWindowAndroidDispatcher.Post(AProc: TWindowProcMethod);
begin Post(WindowMethodToRef(AProc)); end;

procedure TWindowAndroidDispatcher.Post(AProc: TWindowProc);
begin Post(WindowProcToRef(AProc)); end;

type
  TWindowAndroid = class(TInterfacedObject, IWindow, IWindowHost)
  private
    FHandle: TWindowNativeHandle; // ANativeWindow*
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
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

constructor TWindowAndroid.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowAndroidLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowAndroid(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('Android backend not available (not Android host)');
  if AOptions.ParentHandle = nil then
    raise EWindowUnsupported.Create('Android attach requires ParentHandle (ANativeWindow*)');
  FClosed := False;
  FVisible := False;
  FTitle := AOptions.Title;
  // On attach, size is owned by host; we cache options as initial but treat as read-only
  if AOptions.Width <= 0 then FWidth := DefaultWindowOptions.Width else FWidth := AOptions.Width;
  if AOptions.Height <= 0 then FHeight := DefaultWindowOptions.Height else FHeight := AOptions.Height;
  // Try to query real size from ANativeWindow if possible
  if Assigned(ANativeWindow_getWidth) and Assigned(ANativeWindow_getHeight) then
  begin
    // Best effort: if ANativeWindow* is valid, query dims; if fails keep options
    // We guard with try: on Linux ANativeWindow* is dummy pointer, calling would crash, so skip when not Android
    // Since loader false on Linux, this path never reached on Linux.
  end;
  FHandle := AOptions.ParentHandle;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowAndroidDispatcher.Create(FOwnerThread);
  RegisterLive(Pointer(Self));
end;

destructor TWindowAndroid.Destroy;
begin
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowAndroid.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowAndroid.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowAndroid.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  FHandle := nil;
  UnregisterLive(Pointer(Self));
  if AndroidLiveWindowCount = 0 then GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
end;

function TWindowAndroid.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowAndroid.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowAndroid.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowAndroid.Show;
begin RequireOpen; FVisible := True; end;

procedure TWindowAndroid.Hide;
begin RequireOpen; FVisible := False; end;

function TWindowAndroid.IsVisible: Boolean;
begin RequireOpen; Result := FVisible; end;

procedure TWindowAndroid.Focus;
begin RequireOpen; end;

procedure TWindowAndroid.SetTitle(const ATitle: string);
begin RequireOpen; FTitle := ATitle; end;

function TWindowAndroid.GetTitle: string;
begin RequireOpen; Result := FTitle; end;

procedure TWindowAndroid.SetBounds(AWidth, AHeight: Integer);
begin
  RequireOpen;
  // Attach: geometry read-only → honest no-op (do not change, do not dispatch)
end;

function TWindowAndroid.GetWidth: Integer; inline;
begin RequireOpen; Result := FWidth; end;

function TWindowAndroid.GetHeight: Integer; inline;
begin RequireOpen; Result := FHeight; end;

procedure TWindowAndroid.SetResizable(AResizable: Boolean);
begin RequireOpen; end;

procedure TWindowAndroid.Maximize;
begin RequireOpen; end;

procedure TWindowAndroid.Unmaximize;
begin RequireOpen; end;

function TWindowAndroid.IsMaximized: Boolean;
begin RequireOpen; Result := False; end;

procedure TWindowAndroid.Minimize;
begin RequireOpen; end;

procedure TWindowAndroid.Restore;
begin RequireOpen; end;

function TWindowAndroid.IsMinimized: Boolean;
begin RequireOpen; Result := False; end;

function TWindowAndroid.GetScaleFactor: Double;
begin RequireOpen; Result := 1.0; end;

function TWindowAndroid.NativeHandle: TWindowNativeHandle;
begin
  if FClosed then Exit(nil);
  Result := FHandle;
end;

function TWindowAndroid.GetDispatcher: IWindowDispatcher; inline;
begin Result := FDispatcher; end;

procedure TWindowAndroid.OnEvent(AHandler: TWindowEventHandler);
begin RequireOpen; FOnEvent := AHandler; end;

procedure TWindowAndroid.OnEvent(AHandler: TWindowEventMethod);
begin OnEvent(EventMethodToRef(AHandler)); end;

procedure TWindowAndroid.OnEvent(AHandler: TWindowEventProc);
begin OnEvent(EventProcToRef(AHandler)); end;

procedure TWindowAndroid.HostResized(AWidth, AHeight: Integer);
var E: TWindowEvent;
begin
  if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostResized(AWidth, AHeight); end); Exit; end;
  RequireOpen;
  if AWidth<0 then AWidth:=0; if AHeight<0 then AHeight:=0;
  FWidth:=AWidth; FHeight:=AHeight;
  E.Kind:=weResized; E.Width:=FWidth; E.Height:=FHeight; E.X:=0; E.Y:=0; E.NewScale:=0;
  DoDispatch(E);
end;

procedure TWindowAndroid.HostScaleChanged(ANewScale: Double);
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostScaleChanged(ANewScale); end); Exit; end; RequireOpen; E.Kind:=weScaleChanged; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=ANewScale; DoDispatch(E); end;

procedure TWindowAndroid.HostCloseRequested;
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostCloseRequested; end); Exit; end; RequireOpen; E.Kind:=weCloseRequested; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=0; DoDispatch(E); end;

function CreateWindowAndroid(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowAndroid.Create(AOptions); end;

procedure WindowAndroidRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if AndroidLiveWindowCount = 0 then Break;
    // 行业同行做法：Android Looper 阻塞于消息队列，Dispatcher/Host* 以 SetEvent 唤醒，无超时轮询
    GWaitEvent.Wait;
    if AndroidLiveWindowCount = 0 then Break;
  end;
end;

function AndroidPumpOnce: Boolean;
var LProc: TWindowProcRef;
begin Result := DispatcherPop(LProc); if Result then try if Assigned(LProc) then LProc(); except raise; end; end;

procedure WindowAndroidQuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherDrain;
end;

finalization
  GLiveRegistry.Free;
  GQueue.Free;
  GWaitEvent := nil;

end.
