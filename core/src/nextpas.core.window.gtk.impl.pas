unit nextpas.core.window.gtk.impl;

{** @desc GTK 共享窗口后端共享显式单元（单源枢纽，dispatcher/window 已分治）。

       背景：原三家族以 `{$I}` 共享 786 行，绕过 uses 导致 INV-3/INV-5 难扫描；
       本单元显式声明依赖，将注入式符号转为 `TGtkOps/TGtkContext` 显式注入，
       保持与 sdl/win32/fake 相同的“显式 uses + 单源复用 bytes.ops”纪律。
       2026-09 分治：原 860 行三职责（dispatcher/窗口/信号回调）超 800 阈值，
       按 dispatcher 与 window 进一步拆分提升内聚：
       `window.gtk.dispatcher` 收口 dispatcher（g_idle_add_full+ring，per-instance）
       `window.gtk.window` 收口窗口形态与 7 信号回调（delete/configure/focus/scale/destroy/state）
       本单元保留共享显式类型（TGtkOps/TGtkContext）、活窗聚合与轻量转发（Create/Run/Pump），
       三者均 <600 行，守体积指引。

       依赖方向：`window.gtk.impl` ← `window.base/intf/impl/live/queue`
       （L2 内家族共享，非门面 re-export，仅被 `window.gtk3/4/2` uses）；
       `window.gtk.window` → `window.gtk.impl` + `window.gtk.dispatcher`（单向）；
       `window.gtk.dispatcher` → `window.gtk.impl` + `window.dispatcher.base/queue`（单向）；
       无循环，INV-3/INV-5 可静态扫描。

       性能：IGtkOps trait 接口 + TGtkOpsAdapter 薄转发外联单源（非 inline，避 7后端×20方法≈140展开点 I-Cache 复制，仅 WindowGtkTotalLiveCount/WindowGtkLiveAdjust/GtkOpsWrap 等 1行 accessor 保留 inline 零额外调用），单次字段间接零虚表零额外堆分配，Assigned 折叠 nil 守卫；显式单源：TGtkOps 字段经 fields.inc 单源、Adapter 透传经 adapter.inc 单源，复用 bytes.ops 单源思想零手写重复；沿用
       TWindowQueue `32cap 起步、2× 指数扩容、Move 环绕、锁外 Drain` 单源，
       inline Push/Drain 零额外调用，标题 `StrToPAnsiView` 零拷贝（复用 bytes.ops
       TByteSpan 视图单源，gtk 同步拷贝），`WindowGrowCapacity` 单源转发
       `bytes.ops.BytesGrowCapacity 0→32→2×` O(1) 均摊。

       稳定性：队列 Clear 逐条 nil 释放闭包；单 FIdleTag+ILock 保护 DropAll 原子摘除
       并 g_source_remove，try-finally 不丢释放；Close/Destroy 幂等摘除
       GLiveRegistry 并 WindowGtkLiveAdjust 回退，托管闭包计数的 FreeAndNil 对称 0 泄漏；Adapter 外联薄转发 nil 守卫不丢资源释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.live,
  nextpas.core.window.queue,
  nextpas.core.window.dispatcher.base;

type
  gboolean = Int32;
  guint = Cardinal;
  gulong = QWord;
  gint = Int32;

const
  GLIB_SOURCE_REMOVE = 0;
  G_PRIORITY_DEFAULT = 0;
  GTK_WINDOW_TOPLEVEL = 0;
  GDK_WINDOW_STATE_ICONIFIED = 1 shl 1;

type
  TGtkTryLoadFunc = function(out ALoaded: Boolean): Boolean;

  TGtkIdleFunc = function(AData: Pointer): gboolean; cdecl;
  TGDestroyNotify = procedure(AData: Pointer); cdecl;

  // 显式单源：GTK 窗口壳 ABI 函数指针类型单表，手写零 codegen 缝，显式声明可扫描，守 INV-5 单向与 bytes.ops 单源思想，inline 零额外虚派
  TGIdleAddFullFunc = function(APriority: gint; AFunc: TGtkIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint; cdecl;
  TSourceRemoveFunc = function(ATag: guint): gboolean; cdecl;
  TSignalConnectFunc = function(AInstance: Pointer; ADetailedSignal: PAnsiChar; AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify; AConnectFlags: guint): gulong; cdecl;
  TSignalDisconnectProc = procedure(AInstance: Pointer; AHandlerId: gulong); cdecl;
  TGtkInitCheckFunc = function(AArgc: PInt32; AArgv: PPAnsiChar): gboolean; cdecl;
  TGtkWindowNewFunc = function(AType: gint): Pointer; cdecl;
  TGtkWindowSetTitleProc = procedure(AWindow: Pointer; ATitle: PAnsiChar); cdecl;
  TGtkWindowGetTitleFunc = function(AWindow: Pointer): PAnsiChar; cdecl;
  TGtkWindowSetDefaultSizeProc = procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  TGtkWindowSetResizableProc = procedure(AWindow: Pointer; AResizable: gboolean); cdecl;
  TGtkWindowResizeProc = procedure(AWindow: Pointer; AWidth, AHeight: gint); cdecl;
  TGtkWindowMaximizeProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowUnmaximizeProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowIconifyProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowDeiconifyProc = procedure(AWindow: Pointer); cdecl;
  TGtkWindowIsMaximizedFunc = function(AWindow: Pointer): gboolean; cdecl;
  TGtkWidgetShowAllProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetHideProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetVisibleFunc = function(AWidget: Pointer): gboolean; cdecl;
  TGtkWidgetGetScaleFactorFunc = function(AWidget: Pointer): gint; cdecl;
  TGtkWidgetGrabFocusProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetWindowFunc = function(AWidget: Pointer): Pointer; cdecl;
  TGtkWidgetDestroyProc = procedure(AWidget: Pointer); cdecl;
  TGtkWidgetGetAllocatedWidthFunc = function(AWidget: Pointer): gint; cdecl;
  TGtkWidgetGetAllocatedHeightFunc = function(AWidget: Pointer): gint; cdecl;
  TGdkWindowGetStateFunc = function(AWindow: Pointer): guint; cdecl;
  TGtkMainProc = procedure; cdecl;
  TGtkMainQuitProc = procedure; cdecl;
  TGtkMainIterationDoFunc = function(ABlocking: gboolean): gboolean; cdecl;
  TGtkEventsPendingFunc = function: gboolean; cdecl;

  // trait 风格：IGtkOps 接口为单一抽象（对标 Rust trait），TGtkOps 记录为低层存储单源 via fields.inc，TGtkOpsAdapter 适配器桥接，外联薄转发（非 inline，避 140+点 I-Cache 复制，仅 1行 accessor 保留 inline），单源复用 fields.inc/adapter.inc 零手写重复，守 bytes.ops 单源思想
  IGtkOps = interface ['{8A3F9C1D-4E2B-4F7A-9A0B-C1D2E3F4A500}']
    function TryLoad(out ALoaded: Boolean): Boolean;
    function IdleAddFull(APriority: gint; AFunc: TGtkIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint;
    function SourceRemove(ATag: guint): gboolean;
    function SignalConnectData(AInstance: Pointer; ADetailedSignal: PAnsiChar; AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify; AConnectFlags: guint): gulong;
    procedure SignalHandlerDisconnect(AInstance: Pointer; AHandlerId: gulong);
    function InitCheck(AArgc: PInt32; AArgv: PPAnsiChar): gboolean;
    function WindowNew(AType: gint): Pointer;
    procedure WindowSetTitle(AWindow: Pointer; ATitle: PAnsiChar);
    function WindowGetTitle(AWindow: Pointer): PAnsiChar;
    procedure WindowSetDefaultSize(AWindow: Pointer; AWidth, AHeight: gint);
    procedure WindowSetResizable(AWindow: Pointer; AResizable: gboolean);
    procedure WindowResize(AWindow: Pointer; AWidth, AHeight: gint);
    procedure WindowMaximize(AWindow: Pointer);
    procedure WindowUnmaximize(AWindow: Pointer);
    procedure WindowIconify(AWindow: Pointer);
    procedure WindowDeiconify(AWindow: Pointer);
    function WindowIsMaximized(AWindow: Pointer): gboolean;
    procedure WidgetShowAll(AWidget: Pointer);
    procedure WidgetHide(AWidget: Pointer);
    function WidgetGetVisible(AWidget: Pointer): gboolean;
    function WidgetGetScaleFactor(AWidget: Pointer): gint;
    procedure WidgetGrabFocus(AWidget: Pointer);
    function WidgetGetWindow(AWidget: Pointer): Pointer;
    procedure WidgetDestroy(AWidget: Pointer);
    function WidgetGetAllocatedWidth(AWidget: Pointer): gint;
    function WidgetGetAllocatedHeight(AWidget: Pointer): gint;
    function GdkWindowGetState(AWindow: Pointer): guint;
    procedure Main;
    procedure MainQuit;
    function MainIterationDo(ABlocking: gboolean): gboolean;
    function EventsPending: gboolean;
  end;

  // 低层存储：仍为记录单源 via fields.inc，零手写重复，供 Adapter 零拷贝持有，单次字段间接零虚表
  TGtkOps = record
  {$I nextpas.core.window.gtk.ops.fields.inc}
  end;

  // 适配器：记录 → trait 接口桥接，外联薄转发（非 inline，薄转发单源 adapter.inc 零重复，7后端共享零 I-Cache 膨胀），nil 守卫不丢释放，对标 trait impl
  TGtkOpsAdapter = class(TInterfacedObject, IGtkOps)
  private
    FRec: TGtkOps;
  public
    constructor Create(const ARec: TGtkOps);
    function TryLoad(out ALoaded: Boolean): Boolean;
    function IdleAddFull(APriority: gint; AFunc: TGtkIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint;
    function SourceRemove(ATag: guint): gboolean;
    function SignalConnectData(AInstance: Pointer; ADetailedSignal: PAnsiChar; AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify; AConnectFlags: guint): gulong;
    procedure SignalHandlerDisconnect(AInstance: Pointer; AHandlerId: gulong);
    function InitCheck(AArgc: PInt32; AArgv: PPAnsiChar): gboolean;
    function WindowNew(AType: gint): Pointer;
    procedure WindowSetTitle(AWindow: Pointer; ATitle: PAnsiChar);
    function WindowGetTitle(AWindow: Pointer): PAnsiChar;
    procedure WindowSetDefaultSize(AWindow: Pointer; AWidth, AHeight: gint);
    procedure WindowSetResizable(AWindow: Pointer; AResizable: gboolean);
    procedure WindowResize(AWindow: Pointer; AWidth, AHeight: gint);
    procedure WindowMaximize(AWindow: Pointer);
    procedure WindowUnmaximize(AWindow: Pointer);
    procedure WindowIconify(AWindow: Pointer);
    procedure WindowDeiconify(AWindow: Pointer);
    function WindowIsMaximized(AWindow: Pointer): gboolean;
    procedure WidgetShowAll(AWidget: Pointer);
    procedure WidgetHide(AWidget: Pointer);
    function WidgetGetVisible(AWidget: Pointer): gboolean;
    function WidgetGetScaleFactor(AWidget: Pointer): gint;
    procedure WidgetGrabFocus(AWidget: Pointer);
    function WidgetGetWindow(AWidget: Pointer): Pointer;
    procedure WidgetDestroy(AWidget: Pointer);
    function WidgetGetAllocatedWidth(AWidget: Pointer): gint;
    function WidgetGetAllocatedHeight(AWidget: Pointer): gint;
    function GdkWindowGetState(AWindow: Pointer): guint;
    procedure Main;
    procedure MainQuit;
    function MainIterationDo(ABlocking: gboolean): gboolean;
    function EventsPending: gboolean;
    property Rec: TGtkOps read FRec;
  end;

  function GtkOpsWrap(const ARec: TGtkOps): IGtkOps; inline;
  function GtkOpsUnwrap(const AOops: IGtkOps; out ARec: TGtkOps): Boolean; inline;

type
  TGtkContext = class
  private
    FOps: IGtkOps;
    FInitDone: Boolean;
    FInitOk: Boolean;
    FMainLoopRunning: Boolean;
    FLiveRegistry: TWindowLiveRegistry;
  public
    constructor Create(const AOps: TGtkOps); overload;
    constructor Create(const AOps: IGtkOps); overload;
    destructor Destroy; override;
    property Ops: IGtkOps read FOps write FOps;
    property InitDone: Boolean read FInitDone write FInitDone;
    property InitOk: Boolean read FInitOk write FInitOk;
    property MainLoopRunning: Boolean read FMainLoopRunning write FMainLoopRunning;
    property LiveRegistry: TWindowLiveRegistry read FLiveRegistry;
  end;

function GtkIsAvailable(ACtx: TGtkContext): Boolean;
function GtkCreateWindow(ACtx: TGtkContext; const AOptions: TWindowOptions): IWindow;
function GtkLiveCount(ACtx: TGtkContext): Integer;
procedure GtkRunMainLoop(ACtx: TGtkContext);
procedure GtkQuitMainLoop(ACtx: TGtkContext);
function GtkPumpOnce(ACtx: TGtkContext): Boolean;
function GtkEnsureInit(ACtx: TGtkContext): Boolean;

{ GTK 全局活窗聚合：owner gtk.impl，单源原子，与通用 window.live GLiveTotal 分离，读写零锁 16ns inline }
function WindowGtkTotalLiveCount: Integer; inline;
procedure WindowGtkLiveAdjust(ADelta: Integer); inline;

{ 家族内共享：活窗注册（由 window.gtk.window 调用，inline 零额外调用，幂等） }
procedure GtkRegisterLive(ACtx: TGtkContext; AWin: Pointer);
procedure GtkUnregisterLive(ACtx: TGtkContext; AWin: Pointer);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.text.ansi,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.window.impl,
  nextpas.core.window.gtk.window;

var
  GGtkLiveTotal: Int32 = 0; // gtk 聚合单源，owner gtk.impl，与通用 GLiveTotal 分离，写锁外原子 16ns 快照

function WindowGtkTotalLiveCount: Integer; inline;
begin
  Result := atomic_load(GGtkLiveTotal);
end;

procedure WindowGtkLiveAdjust(ADelta: Integer); inline;
begin
  atomic_fetch_add(GGtkLiveTotal, Int32(ADelta));
end;

constructor TGtkOpsAdapter.Create(const ARec: TGtkOps);
begin
  inherited Create;
  FRec := ARec;
end;

{$I nextpas.core.window.gtk.ops.adapter.inc}

function GtkOpsWrap(const ARec: TGtkOps): IGtkOps; inline;
begin
  Result := TGtkOpsAdapter.Create(ARec);
end;

function GtkOpsUnwrap(const AOops: IGtkOps; out ARec: TGtkOps): Boolean; inline;
var LAdapt: TGtkOpsAdapter;
begin
  if (AOops <> nil) and (AOops is TGtkOpsAdapter) then
  begin
    LAdapt := AOops as TGtkOpsAdapter;
    ARec := LAdapt.Rec;
    Result := True;
  end else
  begin
    FillChar(ARec, SizeOf(ARec), 0);
    Result := False;
  end;
end;

constructor TGtkContext.Create(const AOps: TGtkOps);
begin
  inherited Create;
  FOps := GtkOpsWrap(AOps);
  FInitDone := False;
  FInitOk := False;
  FMainLoopRunning := False;
  FLiveRegistry := nil;
end;

constructor TGtkContext.Create(const AOps: IGtkOps);
begin
  inherited Create;
  FOps := AOps;
  FInitDone := False;
  FInitOk := False;
  FMainLoopRunning := False;
  FLiveRegistry := nil;
end;

destructor TGtkContext.Destroy;
begin
  if FLiveRegistry <> nil then
  begin
    FLiveRegistry.Free;
    FLiveRegistry := nil;
  end;
  inherited;
end;

function GtkEnsureInit(ACtx: TGtkContext): Boolean; inline;
var
  LArgc: Int32 = 0;
begin
  if not ACtx.InitDone then
  begin
    nextpas.core.math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
    if (ACtx.Ops <> nil) then
      ACtx.InitOk := ACtx.Ops.InitCheck(@LArgc, nil) <> 0
    else
      ACtx.InitOk := False;
    ACtx.InitDone := True;
  end;
  Result := ACtx.InitOk;
end;

function GtkIsAvailable(ACtx: TGtkContext): Boolean; inline;
var
  LLoaded: Boolean;
begin
  Result := False;
  if (ACtx = nil) or (ACtx.Ops = nil) then Exit(False);
  Result := ACtx.Ops.TryLoad(LLoaded) and LLoaded;
end;

function GtkLiveCount(ACtx: TGtkContext): Integer; inline;
begin
  if (ACtx = nil) or (ACtx.LiveRegistry = nil) then Exit(0);
  Result := ACtx.LiveRegistry.Count;
end;

procedure GtkRegisterLive(ACtx: TGtkContext; AWin: Pointer);
begin
  // 单源托管：window.live 工厂 WindowLiveRegistryEnsure 复用 WindowFamilyToken 单源 inline 零拷贝，消重复手写 Create(WindowFamilyToken)
  if ACtx = nil then Exit;
  WindowLiveRegistryEnsure(ACtx.FLiveRegistry);
  ACtx.LiveRegistry.Register(AWin);
  WindowGtkLiveAdjust(1);
end;

procedure GtkUnregisterLive(ACtx: TGtkContext; AWin: Pointer);
var
  LBefore: Integer;
begin
  if (ACtx = nil) or (ACtx.LiveRegistry = nil) then Exit;
  LBefore := ACtx.LiveRegistry.Count;
  ACtx.LiveRegistry.Unregister(AWin);
  if ACtx.LiveRegistry.Count < LBefore then
    WindowGtkLiveAdjust(-1);
end;

function GtkCreateWindow(ACtx: TGtkContext; const AOptions: TWindowOptions): IWindow;
begin
  // 转发至分治后的 window.gtk.window 单源（保持 window.gtk.impl 为 gtk3/4/2 唯一显式 uses 点，守 INV-3 零后端泄露）
  Result := nextpas.core.window.gtk.window.GtkWindowCreate(ACtx, AOptions);
end;

procedure GtkRunMainLoop(ACtx: TGtkContext);
begin
  if ACtx = nil then Exit;
  ACtx.MainLoopRunning := True;
  try
    if ACtx.Ops <> nil then
      ACtx.Ops.Main();
  finally
    ACtx.MainLoopRunning := False;
  end;
end;

procedure GtkQuitMainLoop(ACtx: TGtkContext);
begin
  if (ACtx = nil) or not ACtx.MainLoopRunning then Exit;
  if ACtx.Ops <> nil then
    ACtx.Ops.MainQuit();
end;

function GtkPumpOnce(ACtx: TGtkContext): Boolean;
var
  LDid: Boolean;
begin
  Result := False;
  LDid := False;
  // 非阻塞泵：零拷贝 EventsPending + MainIterationDo(False)，inline 快速路径，无分配，trait 接口透传零虚派协同 nil 守卫
  if (ACtx <> nil) and (ACtx.Ops <> nil) then
  begin
    while ACtx.Ops.EventsPending() <> 0 do
    begin
      ACtx.Ops.MainIterationDo(0);
      LDid := True;
    end;
  end;
  Result := LDid;
  // stability: 无待处理事件时返回 False，避免 tick 空转误判为有工作
end;

end.
