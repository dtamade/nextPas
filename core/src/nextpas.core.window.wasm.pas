unit nextpas.core.window.wasm;

{** @desc WASM canvas 后端：attach 形态的 <canvas> 窗口。
       依托 window.wasm.ffi/.loader（platform.dl 装载），实现 IWindow
       与 emscripten 驱动的 scale/几何。

       语义（CONTRACT §2.1/2.2）：
       - ParentHandle 携带 canvas 元素 id 的 PAnsiChar 指针（C 字符串）；
         nil 时使用 "#canvas" 缺省
       - NativeHandle 返回 canvas 句柄（ParentHandle 指针值本身，生命周期归 DOM）
       - 几何：SetBounds 写 CSS 尺寸（emscripten_set_element_css_size），
         内部 ×devicePixelRatio 得物理往返；GetWidth/Height 返回物理像素
       - Min/Max 诚实 no-op（canvas 尺寸归 CSS/浏览器布局）
       - GetScaleFactor = devicePixelRatio（1.0..3.0，缺席回退 1.0），
         浏览器缩放时由宿主经 JS 事件转 weScaleChanged（当前 stub 仅读值）
       - Dispatcher：wasm 无真线程，Post 入 JS 任务队列（当前用互斥环 + 同步 Drain，
         主线程 Pump 时兑现，关闭后丢弃）
       - 仅 attach 形态：桌面后端 ParentHandle 抛 Unsupported 已在 factory 处理；
         wasm 接受 nil 与非 nil                         *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowWasmIsAvailable: Boolean;
function CreateWindowWasm(const AOptions: TWindowOptions): IWindow;
function WasmLiveWindowCount: Integer;
procedure WindowWasmRunLoop;
procedure WindowWasmQuitLoop;
function WasmPumpOnce: Boolean;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.time.base,
  nextpas.core.window.wasm.ffi,
  nextpas.core.window.wasm.loader;

var
  GLoopQuit: Boolean = False;
  GLiveWindows: array of Pointer;
  GDispLock: ILock;
  GDispRing: array of TWindowProcRef;
  GDispHead: Integer = 0;
  GDispCount: Integer = 0;
  GWaitEvent: IEvent;

function WindowWasmIsAvailable: Boolean;
var
  LInfo: TWindowWasmLoadInfo;
begin
  Result := TryLoadWindowWasm(LInfo) and LInfo.Loaded;
end;

function WasmLiveWindowCount: Integer;
begin
  Result := Length(GLiveWindows);
end;

procedure RegisterLive(AWin: Pointer);
begin
  SetLength(GLiveWindows, Length(GLiveWindows)+1);
  GLiveWindows[High(GLiveWindows)] := AWin;
end;

procedure UnregisterLive(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = AWin then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      SetLength(GLiveWindows, Length(GLiveWindows)-1);
      Break;
    end;
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

procedure DispatcherGrow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(GDispRing)*2;
  if LNewCap=0 then LNewCap:=32;
  SetLength(LNew, LNewCap);
  for I:=0 to GDispCount-1 do
    LNew[I] := GDispRing[(GDispHead+I) mod Length(GDispRing)];
  GDispRing := LNew;
  GDispHead := 0;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GDispLock=nil then GDispLock := TMutex.Create as ILock;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
  GDispLock.Acquire;
  try
    if GDispCount=Length(GDispRing) then DispatcherGrow;
    GDispRing[(GDispHead+GDispCount) mod Length(GDispRing)] := AProc;
    Inc(GDispCount);
  finally GDispLock.Release; end;
  GWaitEvent.SetEvent;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  Result:=False; AProc:=nil;
  if GDispLock=nil then Exit;
  GDispLock.Acquire;
  try
    if GDispCount=0 then Exit;
    AProc:=GDispRing[GDispHead];
    GDispRing[GDispHead]:=nil;
    GDispHead := (GDispHead+1) mod Length(GDispRing);
    Dec(GDispCount);
    Result:=True;
  finally GDispLock.Release; end;
end;

procedure DispatcherDrain;
var
  LProc: TWindowProcRef;
begin
  while DispatcherPop(LProc) do
  begin
    try if Assigned(LProc) then LProc(); except raise; end;
    LProc:=nil;
  end;
end;

type
  TWindowWasmDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowWasmDispatcher.Create(AOwnerThread: UInt64);
begin inherited Create; FOwnerThread := AOwnerThread; end;

function TWindowWasmDispatcher.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowWasmDispatcher.Post(AProc: TWindowProcRef);
begin if not Assigned(AProc) then Exit; DispatcherPush(AProc); DispatcherDrain; end;

procedure TWindowWasmDispatcher.Post(AProc: TWindowProcMethod);
begin Post(WindowMethodToRef(AProc)); end;

procedure TWindowWasmDispatcher.Post(AProc: TWindowProc);
begin Post(WindowProcToRef(AProc)); end;

type
  TWindowWasm = class(TInterfacedObject, IWindow, IWindowHost)
  private
    FCanvasTarget: string;
    FCanvasHandle: TWindowNativeHandle;
    FClosed: Boolean;
    FVisible: Boolean;
    FTitle: string;
    FCssW, FCssH: Double;
    FPhysW, FPhysH: Integer;
    FScale: Double;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventHandler;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    function IsOnMainThread: Boolean; inline;
    function ResolveTarget: PAnsiChar;
    function QueryScale: Double;
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

function TWindowWasm.ResolveTarget: PAnsiChar;
begin
  if FCanvasTarget = '' then
    Result := '#canvas'
  else
    Result := PAnsiChar(AnsiString(FCanvasTarget));
end;

function TWindowWasm.QueryScale: Double;
begin
  if Assigned(emscripten_get_device_pixel_ratio) then
  begin
    Result := emscripten_get_device_pixel_ratio();
    if Result <= 0 then Result := 1.0;
    if Result > 3.5 then Result := 3.0;
  end
  else
    Result := 1.0;
end;

constructor TWindowWasm.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowWasmLoadInfo;
  P: PAnsiChar;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowWasm(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('WASM backend not available (not Emscripten)');
  // wasm is attach-only: ParentHandle carries canvas id string pointer; nil = "#canvas"
  if AOptions.ParentHandle <> nil then
  begin
    P := PAnsiChar(AOptions.ParentHandle);
    if P <> nil then
      FCanvasTarget := string(AnsiString(P))
    else
      FCanvasTarget := '#canvas';
  end
  else
    FCanvasTarget := '#canvas';

  FClosed := False;
  FVisible := False;
  FTitle := AOptions.Title;
  if AOptions.Width <= 0 then FCssW := DefaultWindowOptions.Width else FCssW := AOptions.Width;
  if AOptions.Height <= 0 then FCssH := DefaultWindowOptions.Height else FCssH := AOptions.Height;
  FScale := QueryScale;
  FPhysW := Round(FCssW * FScale);
  FPhysH := Round(FCssH * FScale);
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowWasmDispatcher.Create(FOwnerThread);
  if AOptions.ParentHandle <> nil then
    FCanvasHandle := AOptions.ParentHandle
  else
    FCanvasHandle := TWindowNativeHandle(Pointer($CAFE0001));

  // Try to sync CSS size to canvas (best effort, ignore errors)
  if Assigned(emscripten_set_element_css_size) then
    emscripten_set_element_css_size(ResolveTarget, FCssW, FCssH);
  if Assigned(emscripten_set_canvas_element_size) then
    emscripten_set_canvas_element_size(ResolveTarget, FPhysW, FPhysH);

  RegisterLive(Pointer(Self));
end;

destructor TWindowWasm.Destroy;
begin
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowWasm.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowWasm.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowWasm.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  FCanvasHandle := nil;
  UnregisterLive(Pointer(Self));
  if WasmLiveWindowCount = 0 then GLoopQuit := True;
end;

function TWindowWasm.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowWasm.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowWasm.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowWasm.Show;
begin RequireOpen; FVisible := True; end;

procedure TWindowWasm.Hide;
begin RequireOpen; FVisible := False; end;

function TWindowWasm.IsVisible: Boolean;
begin RequireOpen; Result := FVisible; end;

procedure TWindowWasm.Focus;
begin RequireOpen; end;

procedure TWindowWasm.SetTitle(const ATitle: string);
begin RequireOpen; FTitle := ATitle; end;

function TWindowWasm.GetTitle: string;
begin RequireOpen; Result := FTitle; end;

procedure TWindowWasm.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FCssW := AWidth; FCssH := AHeight;
  FScale := QueryScale;
  FPhysW := Round(FCssW * FScale);
  FPhysH := Round(FCssH * FScale);
  if Assigned(emscripten_set_element_css_size) then
    emscripten_set_element_css_size(ResolveTarget, FCssW, FCssH);
  if Assigned(emscripten_set_canvas_element_size) then
    emscripten_set_canvas_element_size(ResolveTarget, FPhysW, FPhysH);
  E.Kind := weResized; E.Width := FPhysW; E.Height := FPhysH; E.X := 0; E.Y := 0; E.NewScale := 0;
  DoDispatch(E);
end;

function TWindowWasm.GetWidth: Integer; inline;
begin RequireOpen; Result := FPhysW; end;

function TWindowWasm.GetHeight: Integer; inline;
begin RequireOpen; Result := FPhysH; end;

procedure TWindowWasm.SetResizable(AResizable: Boolean);
begin RequireOpen; end;

procedure TWindowWasm.Maximize;
begin RequireOpen; end;

procedure TWindowWasm.Unmaximize;
begin RequireOpen; end;

function TWindowWasm.IsMaximized: Boolean;
begin RequireOpen; Result := False; end;

procedure TWindowWasm.Minimize;
begin RequireOpen; end;

procedure TWindowWasm.Restore;
begin RequireOpen; end;

function TWindowWasm.IsMinimized: Boolean;
begin RequireOpen; Result := False; end;

function TWindowWasm.GetScaleFactor: Double;
begin RequireOpen; Result := QueryScale; end;

function TWindowWasm.NativeHandle: TWindowNativeHandle;
begin
  if FClosed then Exit(nil);
  Result := FCanvasHandle;
end;

function TWindowWasm.GetDispatcher: IWindowDispatcher; inline;
begin Result := FDispatcher; end;

procedure TWindowWasm.OnEvent(AHandler: TWindowEventHandler);
begin RequireOpen; FOnEvent := AHandler; end;

procedure TWindowWasm.OnEvent(AHandler: TWindowEventMethod);
begin OnEvent(EventMethodToRef(AHandler)); end;

procedure TWindowWasm.OnEvent(AHandler: TWindowEventProc);
begin OnEvent(EventProcToRef(AHandler)); end;

procedure TWindowWasm.HostResized(AWidth, AHeight: Integer);
var E: TWindowEvent;
begin
  if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostResized(AWidth, AHeight); end); Exit; end;
  RequireOpen;
  if AWidth<0 then AWidth:=0; if AHeight<0 then AHeight:=0;
  FCssW:=AWidth; FCssH:=AHeight; FScale:=QueryScale;
  FPhysW:=Round(FCssW*FScale); FPhysH:=Round(FCssH*FScale);
  if Assigned(emscripten_set_element_css_size) then emscripten_set_element_css_size(ResolveTarget, FCssW, FCssH);
  if Assigned(emscripten_set_canvas_element_size) then emscripten_set_canvas_element_size(ResolveTarget, FPhysW, FPhysH);
  E.Kind:=weResized; E.Width:=FPhysW; E.Height:=FPhysH; E.X:=0; E.Y:=0; E.NewScale:=0;
  DoDispatch(E);
end;

procedure TWindowWasm.HostScaleChanged(ANewScale: Double);
var E: TWindowEvent;
begin
  if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostScaleChanged(ANewScale); end); Exit; end;
  RequireOpen;
  if ANewScale<=0 then Exit;
  FScale:=ANewScale;
  FPhysW:=Round(FCssW*FScale); FPhysH:=Round(FCssH*FScale);
  if Assigned(emscripten_set_canvas_element_size) then emscripten_set_canvas_element_size(ResolveTarget, FPhysW, FPhysH);
  E.Kind:=weScaleChanged; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=FScale;
  DoDispatch(E);
end;

procedure TWindowWasm.HostCloseRequested;
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostCloseRequested; end); Exit; end; RequireOpen; E.Kind:=weCloseRequested; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=0; DoDispatch(E); end;

function CreateWindowWasm(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowWasm.Create(AOptions); end;

procedure WindowWasmRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if WasmLiveWindowCount = 0 then Break;
    // 事件驱动等待：由 DispatcherPush/SetEvent 唤醒，宿主侧 requestAnimationFrame 衔接
    GWaitEvent.WaitTimeout(TDuration.FromMilliseconds(5));
    if WasmLiveWindowCount = 0 then Break;
  end;
end;

function WasmPumpOnce: Boolean;
var LProc: TWindowProcRef;
begin Result := DispatcherPop(LProc); if Result then try if Assigned(LProc) then LProc(); except raise; end; end;

procedure WindowWasmQuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherDrain;
end;

end.
