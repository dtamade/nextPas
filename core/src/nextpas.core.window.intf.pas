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

implementation

end.
