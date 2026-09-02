unit nextpas.core.webview.intf;

{** @desc nextpas.core.webview L3 家族：统一接口契约。
       只依赖 base/errors/window.intf owner（window.intf 仅为 has-a 暴露 IWindow，INV-4 豁免，见 design-conventions §2）；具体后端（fake/gtk/webview2/wk）在各自
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
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.window.intf; { INV-4 豁免: L3→L2 has-a 暴露 IWindow/Window 组合面，仅 window.intf，禁后端/bridge/factory，见 design-conventions §2 范式例外 + CONTRACT INV-4 }

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
    function TryResolveView(const AView: TStringView;
      out ABytes: TBytes; out AMimeType: string): Boolean;
    procedure MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider);
    procedure MountDirectory(const APrefix, ARootDir: string);
  end;

  {** 窗口 + 内容组合面（has-a）。IWebviewWindow 不继承 IWindow，
      而是通过 Window 属性组合 IWindow。生命周期：Close 仅毁引擎，
      不连带 Window.Close（FOwnsWindow 区分）。 *}
  IWebviewWindow = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E006}']

    { 组合入口：平台无关的 IWindow（L2），webview 仅持有不拥有创口 }
    function GetWindow: IWindow;
    property Window: IWindow read GetWindow;

    { 生命周期 }
    procedure Close;
    function IsClosed: Boolean;

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
    procedure OnReady(AHandler: TWebviewNotifyHandler); overload;
    procedure OnReady(AHandler: TWebviewNotifyMethod); overload;
    procedure OnReady(AHandler: TWebviewNotifyProc); overload;

    { invoke 注册表与资源挂载 }
    function GetInvokes: IWebviewInvokeRegistry;
    property Invokes: IWebviewInvokeRegistry read GetInvokes;
    function GetAssets: IWebviewAssets;
    property Assets: IWebviewAssets read GetAssets;

    { 内容缩放与 UA（webview 专有，非 Window 壳） }
    procedure SetZoom(AFactor: Double);
    function GetZoom: Double;
    procedure SetUserAgent(const AUserAgent: string);
    function GetUserAgent: string;
  end;

implementation

end.
