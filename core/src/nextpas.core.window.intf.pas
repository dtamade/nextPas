unit nextpas.core.window.intf;

{** @desc nextpas.core.window L2 家族：小接口组合契约。
       只依赖 base/errors owner；具体后端（fake/gtk/sdl2/win32/…）
       在各自单元实现这些接口。所有权模型：对外一律 interface
       （COM 引用计数），消费方不手写 Free。

       线程契约摘要（全文见 docs/window/CONTRACT.md §5）：
       - 一切用户回调（OnEvent handler、Post 投递的闭包）都在 UI 主线程触发
       - 跨线程安全面仅两处：IWindowDispatcher.Post、IWindowLifecycle.Close
       - 无同步阻塞形态

       设计立场（小接口组合）：
       - 拒绝 20+ 方法单体 IWindow；按 ISP 拆为 9 个 <6 方法的小接口
         （Lifecycle/Visibility/Title/Geometry/State/Scale/Handle/Dispatcher/Events），
         各持独立 GUID，Supports 探测按需依赖，测试可 mock 单 facet。
       - IWindow 为轻量组合门面（9 小接口多继承 + 单一 GUID 002），
         存量 W.Show 直调不变（via 祖先），新代码可依赖 IWindowTitle 等小口径。
       - 守四件套（intf 只含声明）与 L0-L3 零后端依赖，性能虚表一跳直达、
         OnEvent 变体直存 Method/Proc 零堆分配 inline 薄转发，托管 Ref 单次赋值；
         实现同步 dispatcher.base 单源 0→32→2×。
       - 稳定性：资源释放与幂等语义由实现守 heaptrc 0，variant Clear 托管释放不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.base.callbacks;

type
  { 回调命名类型全集 —— FPC 不支持内联过程类型作参数；
    三形式范式见 docs/design-conventions.md §8 }

  TWindowProcRef    = reference to procedure;
  TWindowProcMethod = procedure of object;
  TWindowProc       = procedure;

  { IWindowDispatcher — 主线程投递；任意线程可 Post，UI 主线程执行；见 CONTRACT §5 }
  { 单源锚点：显式关联 L0 base.callbacks 单源，守 L0-L3 单向，inline 零成本 }
  _WindowCallbacksBaseAnchor = nextpas.core.base.callbacks.TCallbackScaleHandler;

  { IWindowDispatcher }

  IWindowDispatcher = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A001}']
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
    function IsOnMainThread: Boolean;
    property OnMainThread: Boolean read IsOnMainThread;
  end;

  { --- 小接口：按 ISP 拆分，单职责 <6 方法，各 GUID 可 Supports，按需依赖零耦合 --- }

  IWindowLifecycle = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A010}']
    procedure Close;                    // 幂等；跨线程安全（内部 marshal）
    function IsClosed: Boolean;
  end;

  IWindowVisibility = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A011}']
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;
  end;

  IWindowTitle = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A012}']
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
  end;

  IWindowGeometry = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A013}']
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure SetResizable(AResizable: Boolean);
  end;

  IWindowState = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A014}']
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;
  end;

  IWindowScale = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A015}']
    function GetScaleFactor: Double;
  end;

  IWindowNativeHandle = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A016}']
    function NativeHandle: TWindowNativeHandle;
  end;

  IWindowDispatcherProvider = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A017}']
    function GetDispatcher: IWindowDispatcher;
    property Dispatcher: IWindowDispatcher read GetDispatcher;
  end;

  IWindowEvents = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A018}']
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  end;

  { IWindow — 小接口组合门面：继承 9 小接口，单一 GUID 002 兼容存量 W.Show 直调；
    新代码可按需依赖 IWindowTitle/IWindowGeometry 等小口径，Supports 探测轻量。 }
  IWindow = interface(IWindowLifecycle, IWindowVisibility, IWindowTitle, IWindowGeometry, IWindowState, IWindowScale, IWindowNativeHandle, IWindowDispatcherProvider, IWindowEvents)
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A002}']
  end;

  {** 宿主驱动扩展：仅 attach 后端（wasm/android/uikit）与 fake 暴露。
      桌面后端不支持，QueryInterface 返回非 0。

      设计立场：拒绝 LCL 式 LM_ 跨平台消息。平台特有能力不经消息号伪装，
      而经强类型接口 + Supports 探测。宿主（Android Activity / iOS
      UIViewController / 浏览器 JS）通过此接口把 surface/canvas 生命周期
      事件翻译成 TWindowEvent，不经 WPARAM/LPARAM。 *}
  IWindowHost = interface
    ['{7E9A1B2C-3D4E-4F60-9A8B-C1D2E3F4A005}']
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  end;

{ OnEvent 变体分发：Method/Proc 直存 wedkMethod/wedkProc 零拷贝 inline，Ref 托管；业务以 CONTRACT 为准 }
function WindowEventVariantFromRef(const AHandler: TWindowEventHandler): TWindowEventVariant; inline;
function WindowEventVariantFromMethod(AHandler: TWindowEventMethod): TWindowEventVariant; inline;
function WindowEventVariantFromProc(AHandler: TWindowEventProc): TWindowEventVariant; inline;
procedure WindowEventVariantDispatch(const AVariant: TWindowEventVariant; const AEvent: TWindowEvent); inline;
function WindowEventVariantIsAssigned(const AVariant: TWindowEventVariant): Boolean; inline;
procedure WindowEventVariantClear(var AVariant: TWindowEventVariant); inline;
{ 闭包包装薄转发（main 单源思想，镜像 L0 base.callbacks）：供 dispatcher/post 便捷面复用 }
function WindowEventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
function WindowEventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;
function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef; inline;
function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef; inline;
function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;

implementation

function WindowEventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
begin
  { thin forward single source: mirrors L0 base.callbacks.CallbackEventMethodToRef, inline zero-copy }
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowEventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowEventVariantFromRef(const AHandler: TWindowEventHandler): TWindowEventVariant; inline;
begin
  Result.Kind := wedkRef;
  Result.Ref := AHandler;
  Result.Method := nil;
  Result.Proc := nil;
  if not Assigned(AHandler) then Result.Kind := wedkNone;
end;

function WindowEventVariantFromMethod(AHandler: TWindowEventMethod): TWindowEventVariant; inline;
begin
  // 直存方法指针，外联零拷贝
  if not Assigned(AHandler) then
  begin
    Result.Kind := wedkNone;
    Result.Ref := nil;
    Result.Method := nil;
    Result.Proc := nil;
    Exit;
  end;
  Result.Kind := wedkMethod;
  Result.Ref := nil;
  Result.Method := AHandler;
  Result.Proc := nil;
end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef; inline;
begin
  { thin forward single source: mirrors L0 base.callbacks.CallbackNotifyMethodToRef, inline zero-copy }
  Result := procedure begin AHandler(); end;
end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef; inline;
begin
  Result := procedure begin AHandler(); end;
end;

function WindowEventVariantFromProc(AHandler: TWindowEventProc): TWindowEventVariant; inline;
begin
  // 直存过程指针，外联零拷贝
  if not Assigned(AHandler) then
  begin
    Result.Kind := wedkNone;
    Result.Ref := nil;
    Result.Method := nil;
    Result.Proc := nil;
    Exit;
  end;
  Result.Kind := wedkProc;
  Result.Ref := nil;
  Result.Method := nil;
  Result.Proc := AHandler;
end;

procedure WindowEventVariantDispatch(const AVariant: TWindowEventVariant; const AEvent: TWindowEvent); inline;
begin
  // 按 Kind 直调，外联零分支
  case AVariant.Kind of
    wedkRef: if Assigned(AVariant.Ref) then AVariant.Ref(AEvent);
    wedkMethod: if Assigned(AVariant.Method) then AVariant.Method(AEvent);
    wedkProc: if Assigned(AVariant.Proc) then AVariant.Proc(AEvent);
  else
    // wedkNone: no-op
  end;
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
begin
  Result := WindowEventMethodToRef(AHandler);
end;

function WindowEventVariantIsAssigned(const AVariant: TWindowEventVariant): Boolean; inline;
begin
  case AVariant.Kind of
    wedkRef: Result := Assigned(AVariant.Ref);
    wedkMethod: Result := Assigned(AVariant.Method);
    wedkProc: Result := Assigned(AVariant.Proc);
  else Result := False;
  end;
end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;
begin
  Result := WindowEventProcToRef(AHandler);
end;

procedure WindowEventVariantClear(var AVariant: TWindowEventVariant); inline;
begin
  // 释放托管 Ref，Method/Proc 为非托管直存无需清理；inline 零拷贝，资源托管不丢
  AVariant.Ref := nil;
  AVariant.Method := nil;
  AVariant.Proc := nil;
  AVariant.Kind := wedkNone;
end;

end.
