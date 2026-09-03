unit nextpas.core.window.fake;

{** @desc window 无头脚本化后端：纯 Pascal、无线程、无图形依赖，
       契约测试的唯一载体（CI 不需要图形环境）。

       职责拆分（守 800 行软阈值）：
       - 句柄 → nextpas.core.window.fake.base（TFakeNativeHandle/AllocFakeHandle/FakeLastHandleValue 确定性原子生成 inline 零拷贝）
       - 分发 → nextpas.core.window.fake.dispatcher（TFakeDispatcher 复用 TWindowDispatcherBase 单源变体，条件变量 0→1 单次唤醒 Burst 10k→1，O(1)均摊不丢）
       - 宿主渗透 → inline 环形直存单队列（TFakeWindow 内联 FRingHost 0→32→2× via WindowGrowCapacity→bytes.ops 单源 inline 零拷贝，Dispatcher 单队列单锁单原子零冗余）
       本单元仅保留 TFakeWindow 状态机/关闭幂等/句柄纪律/宿主渗透纽带，体积 <800 行
       - Dispatcher 用 sync 互斥保护 FIFO 环形队列：接口承诺的跨线程安全在 fake 上是真实现
       - 注入事件走与生产后端同一条 OnEvent 分发路径（InjectEvent → DoDispatch 唯一分发体）
       - PumpOnce/PumpAll 确定性驱动 Post 队列
       - 状态脚本：scale / 最大化/最小化/可见性等可直接改写并可选择是否产生对应事件
       - 句柄：确定性生成的非零假句柄，Close 后归 nil
       句柄纪律与生产一致：Show 前已非 nil（fake 立即分配），Close 后恒 nil；Wayland nil 诚实由生产后端体现，fake 恒非 nil 供传递链断言。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.sync.intf,
  nextpas.core.window.fake.host;

type
  {** 接口引用 → 类引用 的安全通道（QueryInterface 驱动）。
      测试驱动面经 TFakeWindow.FromWindow 获取；禁止接口指针硬转类指针。 *}
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
    FOnEvent: TWindowEventVariant;
    FHostRing: array of THostWork;
    FHostHead: Integer;
    FHostCount: Integer;
    FHostLock: ILock;
    procedure RequireOpen;
    procedure DoDispatch(const AEvent: TWindowEvent);
    procedure RealClose;
    procedure DoProcessPendingHostWork;
    procedure EnqueueHostWork(const AWork: THostWork);
    procedure EnqueueHostResized(AWidth, AHeight: Integer); inline;
    procedure EnqueueHostScaleChanged(ANewScale: Double); inline;
    procedure EnqueueInjectEvent(const AEvent: TWindowEvent); inline;
  protected
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
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  public
    class function FromWindow(const AWindow: IWindow): TFakeWindow; static;
    function FakeSelf: TObject;
    constructor Create(const AOptions: TWindowOptions); virtual;
    destructor Destroy; override;
    function PumpOnce: Boolean;
    procedure PumpAll;
    function PendingPosts: Integer;
    procedure InjectEvent(const AEvent: TWindowEvent);
    procedure SetScale(ANewScale: Double);
    procedure SetVisibleForTest(AVisible: Boolean);
    procedure SetMaximizedForTest(AValue: Boolean);
    procedure SetMinimizedForTest(AValue: Boolean);
    function StoredParentHandle: TWindowNativeHandle;
  end;

function FakeLiveWindowCount: Integer;
procedure FakePumpAll;
function FakeHasPendingPosts: Boolean;
procedure FakeNotifyWaiter; inline;
procedure FakeWaitForActivity(const ATimeoutNs: Int64); inline;
function FakeLastHandleValue: TWindowNativeHandle;

implementation

uses
  nextpas.core.window.fake.base,
  nextpas.core.window.fake.dispatcher,
  nextpas.core.window.impl,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.bytes.ops,
  nextpas.core.sync.cow,
  nextpas.core.sync.mutex,
  nextpas.core.platform.thread;

var
  GLiveRegistry: TWindowLiveRegistry;
  GPooledSnap: TWindowLiveSnapshot; // 池化快照 via SnapshotTo 容量保留复用稳态零堆抖动，bytes.ops SnapshotMaybeShrink 8192 单源，per-frame 零分配，资源托管不丢

procedure RegisterFakeLive(AWin: TFakeWindow); inline;
begin
  WindowLiveRegistryEnsure(GLiveRegistry);
  GLiveRegistry.Register(Pointer(AWin));
  FakeNotifyWaiter;
end;

procedure UnregisterFakeLive(AWin: TFakeWindow); inline;
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(Pointer(AWin));
  FakeNotifyWaiter;
end;

function FakeLiveWindowCount: Integer; inline;
begin
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure FakePumpAll;
var
  I: Integer;
  LWin: TFakeWindow;
begin
  if GLiveRegistry = nil then Exit;
  // 强制池化路径：SnapshotTo 容量保留复用稳态零堆抖动 via bytes.ops ManagedEnsureCapacityExact+ArrayRawCopy inline 零拷贝 O(1)，Snapshot deprecated 每调新分配堆抖动 per-frame 禁用
  GLiveRegistry.SnapshotTo(GPooledSnap);
  for I := 0 to High(GPooledSnap) do
  begin
    LWin := TFakeWindow(GPooledSnap[I]);
    if (LWin <> nil) and not LWin.FClosed then
      LWin.PumpAll;
  end;
end;

function FakeHasPendingPosts: Boolean; inline;
begin
  Result := nextpas.core.window.fake.dispatcher.FakeHasPendingPosts;
end;

procedure FakeNotifyWaiter; inline;
begin
  nextpas.core.window.fake.dispatcher.FakeNotifyWaiter;
end;

procedure FakeWaitForActivity(const ATimeoutNs: Int64); inline;
begin
  nextpas.core.window.fake.dispatcher.FakeWaitForActivity(ATimeoutNs);
end;

function FakeLastHandleValue: TWindowNativeHandle;
begin
  Result := nextpas.core.window.fake.base.FakeLastHandleValue;
end;

{ ---- TFakeWindow ---- }

class function TFakeWindow.FromWindow(const AWindow: IWindow): TFakeWindow;
var
  LAcc: IFakeSelfAccess;
begin
  if (AWindow <> nil) and (AWindow.QueryInterface(IFakeSelfAccess, LAcc) = 0) then
    Result := LAcc.FakeSelf as TFakeWindow
  else
    raise EWindowInvalidState.Create('window is not a nextpas.core.window.fake instance');
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
  if AOptions.Size.Width <= 0 then
    FWidth := DefaultWindowOptions.Size.Width
  else
    FWidth := AOptions.Size.Width;
  if AOptions.Size.Height <= 0 then
    FHeight := DefaultWindowOptions.Size.Height
  else
    FHeight := AOptions.Size.Height;
  FScale := 1.0;
  FNativeHandle := AllocFakeHandle;
  FParentHandle := AOptions.ParentHandle;
  FOwnerThread := platform_thread_id;
  FDispatcher := TFakeDispatcher.Create(FOwnerThread);
  FHostHead := 0;
  FHostCount := 0;
  FHostLock := TMutex.Create as ILock;
  RegisterFakeLive(Self);
end;

destructor TFakeWindow.Destroy;
var
  I: Integer;
begin
  WindowEventVariantClear(FOnEvent);
  if FHostLock <> nil then
  begin
    FHostLock.Acquire;
    try
      for I := 0 to FHostCount - 1 do
        FHostRing[WindowRingIndex(FHostHead, I, Length(FHostRing))].Event := Default(TWindowEvent);
      FHostCount := 0;
      FHostHead := 0;
      SetLength(FHostRing, 0);
    finally
      FHostLock.Release;
    end;
  end;
  FHostLock := nil;
  if GLiveRegistry <> nil then
    GLiveRegistry.Unregister(Pointer(Self));
  inherited Destroy;
end;

procedure TFakeWindow.RequireOpen;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TFakeWindow.DoDispatch(const AEvent: TWindowEvent);
begin
  if FClosed then Exit;
  WindowEventVariantDispatch(FOnEvent, AEvent);
end;

procedure TFakeWindow.RealClose;
var
  I: Integer;
begin
  if FClosed then Exit;
  FClosed := True;
  UnregisterFakeLive(Self);
  FVisible := False;
  FNativeHandle := nil;
  WindowEventVariantClear(FOnEvent);
  (FDispatcher as TFakeDispatcher).DropAll;
  if FHostLock <> nil then
  begin
    FHostLock.Acquire;
    try
      for I := 0 to FHostCount - 1 do
        FHostRing[WindowRingIndex(FHostHead, I, Length(FHostRing))].Event := Default(TWindowEvent);
      FHostCount := 0;
      FHostHead := 0;
    finally
      FHostLock.Release;
    end;
  end;
end;

procedure TFakeWindow.DoProcessPendingHostWork;
var
  LWork: THostWork;
  LHas: Boolean;
  E: TWindowEvent;
begin
  LHas := False;
  if FHostLock <> nil then
  begin
    FHostLock.Acquire;
    try
      if FHostCount > 0 then
      begin
        LWork := FHostRing[FHostHead];
        FHostHead := WindowRingNext(FHostHead, Length(FHostRing));
        Dec(FHostCount);
        LHas := True;
      end;
    finally
      FHostLock.Release;
    end;
  end;
  if not LHas then Exit;
  case LWork.Kind of
    hwkResized:
      begin
        if FClosed then Exit;
        RequireOpen;
        if LWork.Width < 0 then LWork.Width := 0;
        if LWork.Height < 0 then LWork.Height := 0;
        FWidth := LWork.Width;
        FHeight := LWork.Height;
        E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.Invalid;
        DoDispatch(E);
      end;
    hwkScaleChanged:
      begin
        if FClosed then Exit;
        RequireOpen;
        if LWork.Scale <= 0 then
          raise EWindowInvalidState.Create('scale must be > 0');
        FScale := LWork.Scale;
        E.Kind := weScaleChanged; E.Width := TWindowPixel(0); E.Height := TWindowPixel(0); E.X := TWindowPixel(0); E.Y := TWindowPixel(0); E.NewScale := TWindowScale.FromFactor(FScale);
        DoDispatch(E);
      end;
    hwkInjected:
      begin
        if FClosed then Exit;
        DoDispatch(LWork.Event);
      end;
  end;
end;

procedure TFakeWindow.EnqueueHostWork(const AWork: THostWork);
var
  LIdx: Integer;
  LNeedGrow: Boolean;
  LOldCap, LNewCap, LOldCount, LOldHead: Integer;
  LOldRing, LNew: array of THostWork;
  LOldPtr, LCurPtr: Pointer;
begin
  // 禁 inline：真实路由体含锁 acquire/二次容量校验/CowRingPrepare+CowRingGrowInstall 重路由（90 行），禁 inline 避 I-Cache 膨胀（design-conventions 红线#2）；薄转发 EnqueueHostResized/ScaleChanged/InjectEvent 保持 inline 单源复用此路由，3 调用点由 3× 膨胀收口为 1 份；0→32→2× via WindowGrowCapacity→bytes.ops 单源 inline 零拷贝，Grow 锁外分配托管释放不丢（CONTRACT §5）
  if FHostLock = nil then
    FHostLock := TMutex.Create as ILock;
  FHostLock.Acquire;
  try
    if FHostCount < Length(FHostRing) then
    begin
      LIdx := WindowRingIndex(FHostHead, FHostCount, Length(FHostRing));
      FHostRing[LIdx] := AWork;
      Inc(FHostCount);
      LNeedGrow := False;
    end else
    begin
      LOldCap := Length(FHostRing);
      LOldCount := FHostCount;
      LOldHead := FHostHead;
      LOldRing := FHostRing;
      LNewCap := WindowGrowCapacity(LOldCap);
      LNeedGrow := LNewCap > LOldCap;
    end;
  finally
    FHostLock.Release;
  end;
  if not LNeedGrow then
  begin
    (FDispatcher as TFakeDispatcher).Post(TWindowProcMethod(@DoProcessPendingHostWork));
    Exit;
  end;
  if LNewCap <= LOldCap then Exit;
  // 性能：锁外 Cow 分配前二次校验仍需生长，消除高竞争下 stale 回退仍分配 LNew 并 discard 的额外堆抖动；inline 零拷贝 via bytes.ops CowRing* 单源，零二次 SetLength 颠簸，资源托管不丢
  FHostLock.Acquire;
  try
    if FHostCount < Length(FHostRing) then
    begin
      LIdx := WindowRingIndex(FHostHead, FHostCount, Length(FHostRing));
      FHostRing[LIdx] := AWork;
      Inc(FHostCount);
      (FDispatcher as TFakeDispatcher).Post(TWindowProcMethod(@DoProcessPendingHostWork));
      Exit;
    end;
    if Length(LOldRing) > 0 then LOldPtr := @LOldRing[0] else LOldPtr := nil;
    if Length(FHostRing) > 0 then LCurPtr := @FHostRing[0] else LCurPtr := nil;
    if CowRingStale(LOldPtr, LOldCap, LOldCount, LOldHead, LCurPtr, Length(FHostRing), FHostCount, FHostHead) then
    begin
      LOldRing := FHostRing;
      LOldHead := FHostHead;
      LOldCap := Length(FHostRing);
      LOldCount := FHostCount;
      LNewCap := WindowGrowCapacity(LOldCap);
      if LNewCap <= LOldCap then Exit;
    end;
  finally
    FHostLock.Release;
  end;
  specialize CowRingPrepareCopy<THostWork>(LNew, LOldRing, LOldHead, LOldCap, LOldCount, LNewCap);
  FHostLock.Acquire;
  try
    if Length(LOldRing) > 0 then LOldPtr := @LOldRing[0] else LOldPtr := nil;
    if Length(FHostRing) > 0 then LCurPtr := @FHostRing[0] else LCurPtr := nil;
    if not CowRingStale(LOldPtr, LOldCap, LOldCount, LOldHead, LCurPtr, Length(FHostRing), FHostCount, FHostHead) then
    begin
      specialize CowRingGrowInstall<THostWork>(FHostRing, FHostHead, LNew, FHostHead, Length(FHostRing), FHostCount);
      LIdx := FHostCount;
      FHostRing[LIdx] := AWork;
      Inc(FHostCount);
    end else
    begin
      if FHostCount < Length(FHostRing) then
      begin
        if LOldCount > 0 then specialize CowDiscard<THostWork>(LNew, LOldCount);
        SetLength(LNew, 0);
        LIdx := WindowRingIndex(FHostHead, FHostCount, Length(FHostRing));
        FHostRing[LIdx] := AWork;
        Inc(FHostCount);
      end else
      begin
        specialize CowRingReuseBuffer<THostWork>(LNew, LOldCount, FHostRing, FHostHead, Length(FHostRing), FHostCount);
        specialize CowRingGrowInstall<THostWork>(FHostRing, FHostHead, LNew, FHostHead, Length(FHostRing), FHostCount);
        LIdx := FHostCount;
        FHostRing[LIdx] := AWork;
        Inc(FHostCount);
      end;
    end;
  finally
    FHostLock.Release;
  end;
  (FDispatcher as TFakeDispatcher).Post(TWindowProcMethod(@DoProcessPendingHostWork));
end;

procedure TFakeWindow.EnqueueHostResized(AWidth, AHeight: Integer); inline;
var
  LWork: THostWork;
begin
  // 性能：inline 薄转发单队列，零额外锁，值捕获零拷贝，复用 EnqueueHostWork 单源（CONTRACT §5）
  LWork.Kind := hwkResized;
  LWork.Width := AWidth;
  LWork.Height := AHeight;
  LWork.Scale := 0;
  LWork.Event := Default(TWindowEvent);
  EnqueueHostWork(LWork);
end;

procedure TFakeWindow.EnqueueHostScaleChanged(ANewScale: Double); inline;
var
  LWork: THostWork;
begin
  LWork.Kind := hwkScaleChanged;
  LWork.Scale := ANewScale;
  LWork.Width := 0;
  LWork.Height := 0;
  LWork.Event := Default(TWindowEvent);
  EnqueueHostWork(LWork);
end;

procedure TFakeWindow.EnqueueInjectEvent(const AEvent: TWindowEvent); inline;
var
  LWork: THostWork;
begin
  LWork.Kind := hwkInjected;
  LWork.Event := AEvent;
  LWork.Width := 0;
  LWork.Height := 0;
  LWork.Scale := 0;
  EnqueueHostWork(LWork);
end;

procedure TFakeWindow.Close;
var
  LDispatcher: TFakeDispatcher;
begin
  if FClosed then Exit;
  LDispatcher := FDispatcher as TFakeDispatcher;
  if not LDispatcher.IsOnMainThread then
  begin
    LDispatcher.Post(TWindowProcMethod(@RealClose));
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
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth;
  FHeight := AHeight;
  LEvent := Default(TWindowEvent);
  LEvent.Kind := weResized;
  LEvent.Width := TWindowPixel(FWidth);
  LEvent.Height := TWindowPixel(FHeight);
  LEvent.X := TWindowPixel(0);
  LEvent.Y := TWindowPixel(0);
  LEvent.NewScale := TWindowScale.Invalid;
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
  LEvent.Width := TWindowPixel(FWidth);
  LEvent.Height := TWindowPixel(FHeight);
  LEvent.X := TWindowPixel(0);
  LEvent.Y := TWindowPixel(0);
  LEvent.NewScale := TWindowScale.Invalid;
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
  FOnEvent := WindowEventVariantFromRef(AHandler);
end;

procedure TFakeWindow.OnEvent(AHandler: TWindowEventMethod); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromMethod(AHandler);
end;

procedure TFakeWindow.OnEvent(AHandler: TWindowEventProc); inline;
begin
  RequireOpen;
  FOnEvent := WindowEventVariantFromProc(AHandler);
end;

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
  if FClosed then Exit;
  LCopy := AEvent;
  if (FDispatcher as TFakeDispatcher).IsOnMainThread then
    DoDispatch(LCopy)
  else
    EnqueueInjectEvent(LCopy);
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
  LEvent.Width := TWindowPixel(0);
  LEvent.Height := TWindowPixel(0);
  LEvent.X := TWindowPixel(0);
  LEvent.Y := TWindowPixel(0);
  LEvent.NewScale := TWindowScale.FromFactor(FScale);
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
  begin EnqueueHostResized(AWidth, AHeight); Exit; end;
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth; FHeight := AHeight;
  E.Kind := weResized; E.Width := TWindowPixel(FWidth); E.Height := TWindowPixel(FHeight); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.Invalid;
  DoDispatch(E);
end;

procedure TFakeWindow.HostScaleChanged(ANewScale: Double);
var
  E: TWindowEvent;
begin
  if not (FDispatcher as TFakeDispatcher).IsOnMainThread then
  begin EnqueueHostScaleChanged(ANewScale); Exit; end;
  RequireOpen;
  if ANewScale <= 0 then raise EWindowInvalidState.Create('scale must be > 0');
  FScale := ANewScale;
  E.Kind := weScaleChanged; E.Width:=TWindowPixel(0); E.Height:=TWindowPixel(0); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.FromFactor(FScale);
  DoDispatch(E);
end;

procedure TFakeWindow.HostCloseRequested;
var
  E: TWindowEvent;
begin
  if not (FDispatcher as TFakeDispatcher).IsOnMainThread then
  begin (FDispatcher as TFakeDispatcher).Post(TWindowProcMethod(@HostCloseRequested)); Exit; end;
  RequireOpen;
  E.Kind := weCloseRequested; E.Width:=TWindowPixel(0); E.Height:=TWindowPixel(0); E.X:=TWindowPixel(0); E.Y:=TWindowPixel(0); E.NewScale:=TWindowScale.Invalid;
  DoDispatch(E);
end;

finalization
  GPooledSnap := nil; // 池化快照托管释放不丢，bytes.ops SnapshotMaybeShrink 阈值收缩已在 SnapshotTo 内，finalization 单次 SetLength 0 释放不丢
  GLiveRegistry.Free;
  GLiveRegistry := nil;

end.
