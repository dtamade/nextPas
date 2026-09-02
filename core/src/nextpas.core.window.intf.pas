unit nextpas.core.window.intf;

{** @desc nextpas.core.window L2 家族：统一接口契约。
       只依赖 base/errors owner；具体后端（fake/gtk/sdl2/win32/…）
       在各自单元实现这些接口。所有权模型：对外一律 interface
       （COM 引用计数），消费方不手写 Free。

       线程契约摘要（全文见 docs/window/CONTRACT.md §5）：
       - 一切用户回调（OnEvent handler、Post 投递的闭包）都在 UI 主线程触发
       - 跨线程安全面仅两处：IWindowDispatcher.Post、IWindow.Close
       - 无同步阻塞形态 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base;

type
  { 回调命名类型全集 —— FPC 不支持内联过程类型作参数；
    三形式范式见 docs/design-conventions.md §8 }

  TWindowProcRef    = reference to procedure;
  TWindowProcMethod = procedure of object;
  TWindowProc       = procedure;

  { IWindowDispatcher }

  IWindowDispatcher = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A001}']
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
    function IsOnMainThread: Boolean;
    property OnMainThread: Boolean read IsOnMainThread;
  end;

  { IWindow }

  IWindow = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A002}']

    { 生命周期 }
    procedure Close;                    // 幂等；跨线程安全（内部 marshal）
    function IsClosed: Boolean;

    { 可见性与焦点 }
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;

    { 标题与几何（物理像素口径，见诚实表换算行） }
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure SetResizable(AResizable: Boolean);

    { 状态（tao 对齐最小集） }
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;

    { DPI 只读最小集 }
    function GetScaleFactor: Double;

    { 平台原生句柄（诚实表 §2.1；Close 后返回 nil） }
    function NativeHandle: TWindowNativeHandle;

    { 主线程投递（转发到本窗所属后端的 dispatcher） }
    function GetDispatcher: IWindowDispatcher;
    property Dispatcher: IWindowDispatcher read GetDispatcher;

    { 事件注册：唯一事件入口；重复注册覆盖旧 handler（最后注册者生效） }
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
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

  IWindowPrivateHandle = interface
    ['{A1B2C3D4-E5F6-47AA-B123-456789ABC001}']
    function GetHandle: Pointer;
  end;

function WindowEventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
function WindowEventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;
function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef; inline;
function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef; inline;
function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler; inline;
function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler; inline;

implementation

function WindowEventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowEventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin
  Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end;
end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin
  Result := procedure begin AHandler(); end;
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin
  Result := WindowEventMethodToRef(AHandler);
end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin
  Result := WindowEventProcToRef(AHandler);
end;

end.
