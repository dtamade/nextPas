unit nextpas.core.webview.intf;

{** @desc nextpas.core.webview L3 家族：统一接口契约。
       只依赖 base/errors owner；具体后端（fake/gtk/webview2/wk）在各自
       单元实现这些接口。所有权模型：对外一律 interface（COM 引用计数），
       消费方不手写 Free。

       线程契约摘要（全文见 docs/webview/CONTRACT.md §4）：
       - 一切用户回调在 UI 主线程触发
       - 跨线程安全面仅三处：IWebviewDispatcher.Post、IWebviewWindow.Close、
         IWebviewInvokeCompletion.Ok/Fail *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base;

type
  {** invoke 异步完成面。Ok/Fail 恰好其一至多一次；可从任意线程调用
      （桥内部 marshal 回主线程再回执）。 *}
  IWebviewInvokeCompletion = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E001}']
    procedure Ok(const AResultJson: string);
    procedure Fail(const ACode, AMessage: string);
  end;

  { 回调命名类型全集 —— FPC 不支持内联过程类型作参数；
    三形式范式见 docs/design-conventions.md §8 }

  TWebviewProcRef    = reference to procedure;
  TWebviewProcMethod = procedure of object;
  TWebviewProc       = procedure;

  TWebviewScaleHandler      = reference to procedure(ANewScale: Double);
  TWebviewEvalCallback      = reference to procedure(const AResultJson: string);
  TWebviewEvalErrorCallback = reference to procedure(const AError: Exception);
  TWebviewNavEventHandler   = reference to procedure(
    const AEvent: TWebviewNavigationEvent);
  TWebviewNavFailedHandler  = reference to procedure(
    const AEvent: TWebviewNavigationEvent);
  TWebviewNotifyHandler     = reference to procedure;

  TWebviewInvokeSyncHandler = reference to function(
    const APayloadJson: string): string;
  TWebviewInvokeSyncMethod  = function(
    const APayloadJson: string): string of object;
  TWebviewInvokeSyncProc    = function(
    const APayloadJson: string): string;

  TWebviewInvokeAsyncHandler = reference to procedure(
    const APayloadJson: string;
    const ACompletion: IWebviewInvokeCompletion);
  TWebviewInvokeAsyncMethod  = procedure(
    const APayloadJson: string;
    const ACompletion: IWebviewInvokeCompletion) of object;
  TWebviewInvokeAsyncProc    = procedure(
    const APayloadJson: string;
    const ACompletion: IWebviewInvokeCompletion);

  { method/proc 形式的事件回调类型（IWebviewWindow 重载用） }
  TWebviewScaleMethod      = procedure(ANewScale: Double) of object;
  TWebviewScaleProc        = procedure(ANewScale: Double);
  TWebviewNavEventMethod   = procedure(
    const AEvent: TWebviewNavigationEvent) of object;
  TWebviewNavEventProc     = procedure(
    const AEvent: TWebviewNavigationEvent);
  TWebviewNavFailedMethod  = procedure(
    const AEvent: TWebviewNavigationEvent) of object;
  TWebviewNavFailedProc    = procedure(
    const AEvent: TWebviewNavigationEvent);
  TWebviewNotifyMethod     = procedure of object;
  TWebviewNotifyProc       = procedure;

  {** 主线程投递。任意线程 → UI 主线程；窗口关闭后投递静默丢弃。
      fake 后端经 PumpOnce/PumpAll 手动驱动（确定性测试）。 *}
  IWebviewDispatcher = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E002}']
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean;
    property OnMainThread: Boolean read IsOnMainThread;
  end;

  {** invoke 注册表。cmd 规则：空、以 'npw.' 或 '_' 开头 → 抛
      EWebviewInvalidState；同名重复注册抛 EWebviewInvalidState
      （先 Unregister 可重注册）。 *}
  IWebviewInvokeRegistry = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E003}']
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler); overload;
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncMethod); overload;
    procedure Register(const ACmd: string;
      AHandler: TWebviewInvokeSyncProc); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncMethod); overload;
    procedure RegisterAsync(const ACmd: string;
      AHandler: TWebviewInvokeAsyncProc); overload;
    procedure Unregister(const ACmd: string);
  end;

  {** 资产 provider：解析失败返回 False（404 是正常业务路径，不抛异常）。 *}
  IWebviewAssetProvider = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E004}']
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

  {** 资源挂载面。解析顺序 = mount 顺序（先挂先查）。
      DevServerUrl 开发模式下 Mount 被 no-op 并记录诊断（CONTRACT §3.4）。 *}
  IWebviewAssets = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E005}']
    function TryResolve(const ASchemeRelativePath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    procedure MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider);
    procedure MountDirectory(const APrefix, ARootDir: string);
  end;

  {** 窗口 + 内容统一面（单窗单 webview；多窗经 Builder.Build 多次创建，
      共享同一 UI 主循环）。生命周期：Close 幂等；Close 后除
      IsClosed/NativeHandle 外一切方法抛 EWebviewClosed。 *}
  IWebviewWindow = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E006}']

    { 生命周期 }
    procedure Close;                       // 幂等；跨线程安全（内部 marshal）
    function IsClosed: Boolean;

    { 窗口壳 —— 可见性与焦点 }
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;

    { 窗口壳 —— 标题与几何 }
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure SetResizable(AResizable: Boolean);

    { 窗口壳 —— 状态（tao 对齐最小集） }
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;

    { 内容缩放与 UA }
    procedure SetZoom(AFactor: Double);    // 1.0 = 100%
    function GetZoom: Double;
    procedure SetUserAgent(const AUserAgent: string);
    function GetUserAgent: string;

    { DPI 只读最小集（GTK 整数诚实升格为浮点） }
    function GetScaleFactor: Double;
    procedure OnScaleChanged(AHandler: TWebviewScaleHandler); overload;
    procedure OnScaleChanged(AHandler: TWebviewScaleMethod); overload;
    procedure OnScaleChanged(AHandler: TWebviewScaleProc); overload;

    { 导航 }
    procedure Navigate(const AUrl: string);
    procedure NavigateToString(const AHtml: string);
    procedure Reload;
    procedure Stop;
    function CanGoBack: Boolean;
    function GoBack: Boolean;
    function CanGoForward: Boolean;
    function GoForward: Boolean;

    { 异步 eval —— 唯一入口，禁止同步形态。
      ACallback/AOnError 恰好其一被调用一次且都在 UI 主线程；
      Close 时在途 Eval 统一 AOnError(EWebviewEvalFailed) 收尾。 }
    procedure Eval(const AJavascript: string;
      ACallback: TWebviewEvalCallback;
      AOnError: TWebviewEvalErrorCallback);

    { IPC：native → js 事件；页面未就绪时静默丢弃 }
    procedure Emit(const AEvent, APayloadJson: string);

    { 主线程投递 }
    function GetDispatcher: IWebviewDispatcher;
    property Dispatcher: IWebviewDispatcher read GetDispatcher;

    { 平台原生句柄（X11=XID / Wayland=nil；语义见 BACKENDS §8） }
    function NativeHandle: TWebviewNativeHandle;

    { 事件注册：匿名形如下；method/proc 三重载形态从略（签名同形） }
    procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventProc); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventProc); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyHandler); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyMethod); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyProc); overload;    procedure OnReady(AHandler: TWebviewNotifyHandler); overload;
    procedure OnReady(AHandler: TWebviewNotifyMethod); overload;
    procedure OnReady(AHandler: TWebviewNotifyProc); overload;

    { invoke 注册表与资源挂载 }
    function GetInvokes: IWebviewInvokeRegistry;
    property Invokes: IWebviewInvokeRegistry read GetInvokes;
    function GetAssets: IWebviewAssets;
    property Assets: IWebviewAssets read GetAssets;
  end;

implementation

end.
