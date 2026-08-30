unit nextpas.core.window.fake;

{** @desc window 无头脚本化后端：纯 Pascal、无线程、无图形依赖，
       契约测试的唯一载体（CI 不需要图形环境）。

       职责边界（S1）：
       - 完整实现 IWindow 行为矩阵（状态机/关闭幂等/句柄纪律）
       - Dispatcher 用 sync 互斥保护 FIFO 环形队列：接口承诺的跨线程
         安全在 fake 上是真实现，不是测试专用降级
       - 注入事件走与生产后端同一条 OnEvent 分发路径（无旁路）
         —— InjectEvent → DoDispatch 为唯一分发体
       - PumpOnce/PumpAll 确定性驱动 Post 队列
       - 状态脚本：scale / 最大化/最小化/可见性等可直接改写并可
         选择是否产生对应事件
       - 句柄：确定性生成的非零假句柄，Close 后归 nil

       句柄纪律与生产一致：Show 前已非 nil（fake 立即分配），
       Close 后恒 nil；Wayland nil 诚实由生产后端体现，fake 恒非 nil
       供传递链断言。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  {** 接口引用 → 类引用 的安全通道（QueryInterface 驱动）。
      测试驱动面经 TFakeWindow.FromWindow 获取；禁止接口指针硬转
      类指针（COM 接口指针 ≠ 对象起始地址）。 *}
  IFakeSelfAccess = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A003}']
    function FakeSelf: TObject;
  end;

  TFakeWindow = class(TInterfacedObject, IWindow, IFakeSelfAccess, IWindowHost)
  private
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FMaximized: Boolean;
    FMinimized: Boolean;
    FTitle: string;
    FWidth: Integer;
    FHeight: Integer;
    FScale: Double;
    FNativeHandle: TWindowNativeHandle;
    FParentHandle: TWindowNativeHandle;
    FDispatcher: IWindowDispatcher;
    FOwnerThread: UInt64;
    FOnEvent: TWindowEventHandler;
    procedure RequireOpen;
    procedure DoDispatch(const AEvent: TWindowEvent);
    procedure RealClose;
  protected
    { IWindow }
    procedure Close; virtual;
    function IsClosed: Boolean;
    procedure Show; virtual;
    procedure Hide; virtual;
    function IsVisible: Boolean;
    procedure Focus; virtual;
    procedure SetTitle(const ATitle: string); virtual;
    function GetTitle: string; virtual;
    procedure SetBounds(AWidth, AHeight: Integer); virtual;
    function GetWidth: Integer; inline;
    function GetHeight: Integer; inline;
    procedure SetResizable(AResizable: Boolean); virtual;
    procedure Maximize; virtual;
    procedure Unmaximize; virtual;
    function IsMaximized: Boolean;
    procedure Minimize; virtual;
    procedure Restore; virtual;
    function IsMinimized: Boolean;
    function GetScaleFactor: Double;
    function NativeHandle: TWindowNativeHandle;
    function GetDispatcher: IWindowDispatcher;
    procedure OnEvent(AHandler: TWindowEventHandler); overload; virtual;
    procedure OnEvent(AHandler: TWindowEventMethod); overload; virtual;
    procedure OnEvent(AHandler: TWindowEventProc); overload; virtual;
    { IWindowHost }
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  public
    class function FromWindow(const AWindow: IWindow): TFakeWindow; static;
    function FakeSelf: TObject;
    constructor Create(const AOptions: TWindowOptions); virtual;
    destructor Destroy; override;

    { ---- 测试驱动面 ---- }

    { 泵一次/泵空主线程投递队列（Dispatcher.Post 的确定性驱动） }
    function PumpOnce: Boolean;
    procedure PumpAll;
    function PendingPosts: Integer;

    { 注入事件：走与生产后端同一条 DoDispatch 路径；跨线程时经
      Dispatcher.Post marshal，需 Pump 兑现 }
    procedure InjectEvent(const AEvent: TWindowEvent);
    { 输入便捷注入（3.0）：等价于构造 TWindowEvent 后 InjectEvent }
    procedure InjectKey(AKind: TWindowEventKind; AKeyCode, AModifiers: Integer);
    procedure InjectMouse(AKind: TWindowEventKind; AX, AY, AButton, AModifiers: Integer);

    { 状态脚本：直接改写内部状态并可选择是否产生对应事件 }
    procedure SetScale(ANewScale: Double);
    procedure SetVisibleForTest(AVisible: Boolean);
    procedure SetMaximizedForTest(AValue: Boolean);
    procedure SetMinimizedForTest(AValue: Boolean);

    { 只读探针 }
    function StoredParentHandle: TWindowNativeHandle;
  end;

{ 活跃 fake 窗口数（factory 的 RunLoop 退出事实源） }
function FakeLiveWindowCount: Integer;

{ 对所有活跃 fake 窗口各泵一次投递队列（factory RunLoop 用） }
procedure FakePumpAll;
function FakeHasPendingPosts: Boolean;

{ 句柄探针：返回最近一次分配的假句柄值（测试断言句柄传递链） }
function FakeLastHandleValue: TWindowNativeHandle;

implementation

uses
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex;



{ ---- TFakeDispatcher：互斥保护的环形 FIFO ---- }

type
  TFakeDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FLck: ILock;
    FRing: array of TWindowProcRef;
    FHead: Integer;
    FCount: Integer;
    FOwnerThread: UInt64;
    procedure Grow; inline;
  public
    constructor Create(AOwnerThread: UInt64);
    destructor Destroy; override;
    procedure PostRef(AProc: TWindowProcRef); inline;
    function IsOnMainThread: Boolean; inline;
    function PumpOnce: Boolean; inline;
    procedure PumpAll;
    function PendingCount: Integer;
    procedure DropAll;
    { IWindowDispatcher }
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TFakeDispatcher.Create(AOwnerThread: UInt64);
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FOwnerThread := AOwnerThread;
end;

destructor TFakeDispatcher.Destroy;
begin
  DropAll;
  inherited Destroy;
end;

procedure TFakeDispatcher.Grow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(FRing) * 2;
  if LNewCap = 0 then
    LNewCap := 32;
  SetLength(LNew, LNewCap);
  for I := 0 to FCount - 1 do
    LNew[I] := FRing[(FHead + I) mod Length(FRing)];
  FRing := LNew;
  FHead := 0;
end;

procedure TFakeDispatcher.PostRef(AProc: TWindowProcRef); inline;
begin
  FLck.Acquire;
  try
    if FCount = Length(FRing) then
      Grow;
    FRing[(FHead + FCount) mod Length(FRing)] := AProc;
    Inc(FCount);
  finally
    FLck.Release;
  end;
end;

function TFakeDispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

function TFakeDispatcher.PumpOnce: Boolean; inline;
var
  LProc: TWindowProcRef;
begin
  FLck.Acquire;
  try
    if FCount = 0 then
      Exit(False);
    LProc := FRing[FHead];
    FRing[FHead] := nil;
    FHead := (FHead + 1) mod Length(FRing);
    Dec(FCount);
  finally
    FLck.Release;
  end;
  if Assigned(LProc) then
    LProc();
  LProc := nil;
  Result := True;
end;

procedure TFakeDispatcher.PumpAll;
begin
  while PumpOnce do ;
end;

function TFakeDispatcher.PendingCount: Integer;
begin
  FLck.Acquire;
  try
    Result := FCount;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.DropAll;
var
  I: Integer;
begin
  FLck.Acquire;
  try
    for I := 0 to FCount - 1 do
      FRing[(FHead + I) mod Length(FRing)] := nil;
    FCount := 0;
    FHead := 0;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.Post(AProc: TWindowProcRef);
begin
  PostRef(AProc);
end;

procedure TFakeDispatcher.Post(AProc: TWindowProcMethod);
begin
  PostRef(WindowMethodToRef(AProc));
end;

procedure TFakeDispatcher.Post(AProc: TWindowProc);
begin
  PostRef(WindowProcToRef(AProc));
end;

{ ---- 全局活跃窗口登记 & 假句柄生成 ---- }

var
  GLiveWindows: array of TFakeWindow;
  GFakeLiveCount: Integer = 0;
  GNextHandle: PtrUInt = $1000;
  GLastHandle: TWindowNativeHandle = nil;

function FakeLiveWindowCount: Integer; inline;
begin
  Result := GFakeLiveCount;
end;

procedure FakePumpAll;
var
  I: Integer;
begin
  for I := 0 to High(GLiveWindows) do
    if not GLiveWindows[I].FClosed then
      GLiveWindows[I].PumpAll;
end;

function FakeHasPendingPosts: Boolean;
var
  I: Integer;
begin
  for I := 0 to High(GLiveWindows) do
    if not GLiveWindows[I].FClosed and (GLiveWindows[I].PendingPosts > 0) then
      Exit(True);
  Result := False;
end;

function FakeLastHandleValue: TWindowNativeHandle;
begin
  Result := GLastHandle;
end;

function AllocFakeHandle: TWindowNativeHandle;
begin
  GNextHandle := GNextHandle + $10;
  Result := TWindowNativeHandle(Pointer(GNextHandle));
  GLastHandle := Result;
end;

{ ---- TFakeWindow ---- }

class function TFakeWindow.FromWindow(const AWindow: IWindow): TFakeWindow;
var
  LAcc: IFakeSelfAccess;
begin
  if (AWindow <> nil) and (AWindow.QueryInterface(IFakeSelfAccess, LAcc) = 0) then
    Result := LAcc.FakeSelf as TFakeWindow
  else
    raise EWindowInvalidState.Create(
      'window is not a nextpas.core.window.fake instance');
end;

function TFakeWindow.FakeSelf: TObject;
begin
  Result := Self;
end;

constructor TFakeWindow.Create(const AOptions: TWindowOptions);
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FMaximized := AOptions.Maximized;
  FMinimized := False;
  FTitle := AOptions.Title;
  if AOptions.Width <= 0 then
    FWidth := DefaultWindowOptions.Width
  else
    FWidth := AOptions.Width;
  if AOptions.Height <= 0 then
    FHeight := DefaultWindowOptions.Height
  else
    FHeight := AOptions.Height;
  FScale := 1.0;
  FNativeHandle := AllocFakeHandle;
  FParentHandle := AOptions.ParentHandle;
  FOwnerThread := platform_thread_id;
  FDispatcher := TFakeDispatcher.Create(FOwnerThread);
  SetLength(GLiveWindows, Length(GLiveWindows) + 1);
  GLiveWindows[High(GLiveWindows)] := Self;
  Inc(GFakeLiveCount);
end;

destructor TFakeWindow.Destroy;
var
  I: Integer;
begin
  if not FClosed then
    Dec(GFakeLiveCount);
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = Self then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      SetLength(GLiveWindows, Length(GLiveWindows) - 1);
      Break;
    end;
  inherited Destroy;
end;

procedure TFakeWindow.RequireOpen;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TFakeWindow.DoDispatch(const AEvent: TWindowEvent);
var
  LHandler: TWindowEventHandler;
begin
  { 窗口销毁后不再产生该窗事件（INV-2） }
  if FClosed then
    Exit;
  LHandler := FOnEvent;
  if Assigned(LHandler) then
    LHandler(AEvent);
end;

procedure TFakeWindow.RealClose;
var
  LWasClosed: Boolean;
begin
  LWasClosed := FClosed;
  if LWasClosed then
    Exit;
  FClosed := True;
  Dec(GFakeLiveCount);
  FVisible := False;
  FNativeHandle := nil;
  { 关闭后投递静默丢弃（CONTRACT §4.1） }
  (FDispatcher as TFakeDispatcher).DropAll;
end;

procedure TFakeWindow.Close;
var
  LDispatcher: TFakeDispatcher;
begin
  { 幂等；跨线程 marshal }
  if FClosed then
    Exit;
  LDispatcher := FDispatcher as TFakeDispatcher;
  if not LDispatcher.IsOnMainThread then
  begin
    LDispatcher.PostRef(
      procedure
      begin
        RealClose;
      end);
    Exit;
  end;
  RealClose;
end;

function TFakeWindow.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TFakeWindow.Show;
begin
  RequireOpen;
  FVisible := True;
end;

procedure TFakeWindow.Hide;
begin
  RequireOpen;
  FVisible := False;
end;

function TFakeWindow.IsVisible: Boolean;
begin
  RequireOpen;
  Result := FVisible;
end;

procedure TFakeWindow.Focus;
begin
  RequireOpen;
end;

procedure TFakeWindow.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
end;

function TFakeWindow.GetTitle: string;
begin
  RequireOpen;
  Result := FTitle;
end;

procedure TFakeWindow.SetBounds(AWidth, AHeight: Integer);
var
  LEvent: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then
    AWidth := 0;
  if AHeight < 0 then
    AHeight := 0;
  FWidth := AWidth;
  FHeight := AHeight;
  { 同步产生 weResized 事件，走同一分发路径 }
  LEvent := Default(TWindowEvent);

  LEvent.Kind := weResized;
  LEvent.Width := FWidth;
  LEvent.Height := FHeight;
  LEvent.X := 0;
  LEvent.Y := 0;
  LEvent.NewScale := 0;
  DoDispatch(LEvent);
end;

function TFakeWindow.GetWidth: Integer; inline;
begin
  RequireOpen;
  Result := FWidth;
end;

function TFakeWindow.GetHeight: Integer; inline;
begin
  RequireOpen;
  Result := FHeight;
end;

procedure TFakeWindow.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
end;

procedure TFakeWindow.Maximize;
var
  LEvent: TWindowEvent;
begin
  RequireOpen;
  FMaximized := True;
  FMinimized := False;
  LEvent := Default(TWindowEvent);

  LEvent.Kind := weResized;
  LEvent.Width := FWidth;
  LEvent.Height := FHeight;
  LEvent.X := 0;
  LEvent.Y := 0;
  LEvent.NewScale := 0;
  DoDispatch(LEvent);
end;

procedure TFakeWindow.Unmaximize;
begin
  RequireOpen;
  FMaximized := False;
end;

function TFakeWindow.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := FMaximized;
end;

procedure TFakeWindow.Minimize;
begin
  RequireOpen;
  FMinimized := True;
end;

procedure TFakeWindow.Restore;
begin
  RequireOpen;
  FMinimized := False;
  FMaximized := False;
end;

function TFakeWindow.IsMinimized: Boolean;
begin
  RequireOpen;
  Result := FMinimized;
end;

function TFakeWindow.GetScaleFactor: Double; inline;
begin
  RequireOpen;
  Result := FScale;
end;

function TFakeWindow.NativeHandle: TWindowNativeHandle; inline;
begin
  { INV-1：Close 完成后恒为 nil；其余情况返回确定性假句柄 }
  if FClosed then
    Result := nil
  else
    Result := FNativeHandle;
end;

function TFakeWindow.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TFakeWindow.OnEvent(AHandler: TWindowEventHandler);
begin
  RequireOpen;
  FOnEvent := AHandler;
end;

procedure TFakeWindow.OnEvent(AHandler: TWindowEventMethod);
begin
  OnEvent(EventMethodToRef(AHandler));
end;

procedure TFakeWindow.OnEvent(AHandler: TWindowEventProc);
begin
  OnEvent(EventProcToRef(AHandler));
end;

{ ---- 驱动面 ---- }

function TFakeWindow.PumpOnce: Boolean;
begin
  Result := (FDispatcher as TFakeDispatcher).PumpOnce;
end;

procedure TFakeWindow.PumpAll;
begin
  (FDispatcher as TFakeDispatcher).PumpAll;
end;

function TFakeWindow.PendingPosts: Integer;
begin
  Result := (FDispatcher as TFakeDispatcher).PendingCount;
end;

procedure TFakeWindow.InjectEvent(const AEvent: TWindowEvent);
var
  LCopy: TWindowEvent;
begin
  if FClosed then
    Exit;
  LCopy := AEvent;
  if (FDispatcher as TFakeDispatcher).IsOnMainThread then
    DoDispatch(LCopy)
  else
    FDispatcher.Post(
      procedure
      begin
        DoDispatch(LCopy);
      end);
end;

procedure TFakeWindow.InjectKey(AKind: TWindowEventKind; AKeyCode, AModifiers: Integer);
var
  E: TWindowEvent;
begin
  E := Default(TWindowEvent);
  E.Kind := AKind;
  E.KeyCode := AKeyCode;
  E.Modifiers := AModifiers;
  InjectEvent(E);
end;

procedure TFakeWindow.InjectMouse(AKind: TWindowEventKind; AX, AY, AButton, AModifiers: Integer);
var
  E: TWindowEvent;
begin
  E := Default(TWindowEvent);
  E.Kind := AKind;
  E.X := AX; E.Y := AY;
  E.Button := AButton;
  E.Modifiers := AModifiers;
  InjectEvent(E);
end;

procedure TFakeWindow.SetScale(ANewScale: Double);
var
  LEvent: TWindowEvent;
begin
  RequireOpen;
  if ANewScale <= 0 then
    raise EWindowInvalidState.Create('scale must be > 0');
  FScale := ANewScale;
  LEvent := Default(TWindowEvent);

  LEvent.Kind := weScaleChanged;
  LEvent.Width := 0;
  LEvent.Height := 0;
  LEvent.X := 0;
  LEvent.Y := 0;
  LEvent.NewScale := FScale;
  DoDispatch(LEvent);
end;

procedure TFakeWindow.SetVisibleForTest(AVisible: Boolean);
begin
  RequireOpen;
  FVisible := AVisible;
end;

procedure TFakeWindow.SetMaximizedForTest(AValue: Boolean);
begin
  RequireOpen;
  FMaximized := AValue;
end;

procedure TFakeWindow.SetMinimizedForTest(AValue: Boolean);
begin
  RequireOpen;
  FMinimized := AValue;
end;

function TFakeWindow.StoredParentHandle: TWindowNativeHandle;
begin
  Result := FParentHandle;
end;

procedure TFakeWindow.HostResized(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  if not (FDispatcher as TFakeDispatcher).IsOnMainThread then
  begin FDispatcher.Post(procedure begin HostResized(AWidth, AHeight); end); Exit; end;
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  E.Kind := weResized; E.Width := FWidth; E.Height := FHeight; E.X:=0; E.Y:=0; E.NewScale:=0;
  DoDispatch(E);
end;

procedure TFakeWindow.HostScaleChanged(ANewScale: Double);
var
  E: TWindowEvent;
begin
  if not (FDispatcher as TFakeDispatcher).IsOnMainThread then
  begin FDispatcher.Post(procedure begin HostScaleChanged(ANewScale); end); Exit; end;
  RequireOpen;
  if ANewScale <= 0 then raise EWindowInvalidState.Create('scale must be > 0');
  FScale := ANewScale;
  E.Kind := weScaleChanged; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=FScale;
  DoDispatch(E);
end;

procedure TFakeWindow.HostCloseRequested;
var
  E: TWindowEvent;
begin
  if not (FDispatcher as TFakeDispatcher).IsOnMainThread then
  begin FDispatcher.Post(procedure begin HostCloseRequested; end); Exit; end;
  RequireOpen;
  E.Kind := weCloseRequested; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=0;
  DoDispatch(E);
end;

end.
