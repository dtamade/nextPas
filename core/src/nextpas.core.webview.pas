unit nextpas.core.webview;

{** @desc nextpas.core.webview 门面：聚合 re-export 全部公共 API，
       不含任何逻辑（design-conventions §2 门面职责）。

       消费方大多数时候只需 uses 本单元；只要类型的场景可改引
       *.base / *.intf 降低依赖闭包。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.vfs,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.factory,
  nextpas.core.webview.builder,
  nextpas.core.webview.vfs,
  nextpas.core.window.intf;

{ ---- 常量 ---- }

const
  NPW_BRIDGE_VERSION = nextpas.core.webview.base.NPW_BRIDGE_VERSION;
  DEFAULT_WEBVIEW_SCHEME = nextpas.core.webview.base.DEFAULT_WEBVIEW_SCHEME;

{ ---- 类型：base ---- }

type
  TWebviewKind = nextpas.core.webview.base.TWebviewKind;
  TWebviewNativeHandle = nextpas.core.webview.base.TWebviewNativeHandle;
  TWebviewInitScripts = nextpas.core.webview.base.TWebviewInitScripts;
  TWebviewOptions = nextpas.core.webview.base.TWebviewOptions;
  TWebviewNavigationEvent = nextpas.core.webview.base.TWebviewNavigationEvent;

  EWebviewError = nextpas.core.webview.base.EWebviewError;
  EWebviewBackendUnavailable = nextpas.core.webview.base.EWebviewBackendUnavailable;
  EWebviewNotInitialized = nextpas.core.webview.base.EWebviewNotInitialized;
  EWebviewInvalidState = nextpas.core.webview.base.EWebviewInvalidState;
  EWebviewClosed = nextpas.core.webview.base.EWebviewClosed;
  EWebviewEvalFailed = nextpas.core.webview.base.EWebviewEvalFailed;
  EWebviewTimeout = nextpas.core.webview.base.EWebviewTimeout;
  EWebviewBadFrame = nextpas.core.webview.base.EWebviewBadFrame;
  EWebviewInvokeError = nextpas.core.webview.base.EWebviewInvokeError;

{ ---- 类型：intf 回调 ---- }

  TWebviewProcRef    = nextpas.core.webview.intf.TWebviewProcRef;
  TWebviewProcMethod = nextpas.core.webview.intf.TWebviewProcMethod;
  TWebviewProc       = nextpas.core.webview.intf.TWebviewProc;

  TWebviewScaleHandler      = nextpas.core.webview.intf.TWebviewScaleHandler;
  TWebviewScaleMethod       = nextpas.core.webview.intf.TWebviewScaleMethod;
  TWebviewScaleProc         = nextpas.core.webview.intf.TWebviewScaleProc;
  TWebviewEvalCallback      = nextpas.core.webview.intf.TWebviewEvalCallback;
  TWebviewEvalErrorCallback = nextpas.core.webview.intf.TWebviewEvalErrorCallback;
  TWebviewNavEventHandler   = nextpas.core.webview.intf.TWebviewNavEventHandler;
  TWebviewNavEventMethod    = nextpas.core.webview.intf.TWebviewNavEventMethod;
  TWebviewNavEventProc      = nextpas.core.webview.intf.TWebviewNavEventProc;
  TWebviewNavFailedHandler  = nextpas.core.webview.intf.TWebviewNavFailedHandler;
  TWebviewNavFailedMethod   = nextpas.core.webview.intf.TWebviewNavFailedMethod;
  TWebviewNavFailedProc     = nextpas.core.webview.intf.TWebviewNavFailedProc;
  TWebviewNotifyHandler     = nextpas.core.webview.intf.TWebviewNotifyHandler;
  TWebviewNotifyMethod      = nextpas.core.webview.intf.TWebviewNotifyMethod;
  TWebviewNotifyProc        = nextpas.core.webview.intf.TWebviewNotifyProc;

  TWebviewInvokeSyncHandler  = nextpas.core.webview.intf.TWebviewInvokeSyncHandler;
  TWebviewInvokeSyncMethod   = nextpas.core.webview.intf.TWebviewInvokeSyncMethod;
  TWebviewInvokeSyncProc     = nextpas.core.webview.intf.TWebviewInvokeSyncProc;
  TWebviewInvokeAsyncHandler = nextpas.core.webview.intf.TWebviewInvokeAsyncHandler;
  TWebviewInvokeAsyncMethod  = nextpas.core.webview.intf.TWebviewInvokeAsyncMethod;
  TWebviewInvokeAsyncProc    = nextpas.core.webview.intf.TWebviewInvokeAsyncProc;
  // zero-copy view handlers: TStringView RawSlice single source, zero heap per invoke
  TWebviewInvokeSyncViewHandler  = nextpas.core.webview.intf.TWebviewInvokeSyncViewHandler;
  TWebviewInvokeSyncViewMethod   = nextpas.core.webview.intf.TWebviewInvokeSyncViewMethod;
  TWebviewInvokeSyncViewProc     = nextpas.core.webview.intf.TWebviewInvokeSyncViewProc;
  TWebviewInvokeAsyncViewHandler = nextpas.core.webview.intf.TWebviewInvokeAsyncViewHandler;
  TWebviewInvokeAsyncViewMethod  = nextpas.core.webview.intf.TWebviewInvokeAsyncViewMethod;
  TWebviewInvokeAsyncViewProc    = nextpas.core.webview.intf.TWebviewInvokeAsyncViewProc;

{ ---- 类型：intf 接口 ---- }

  IWebviewInvokeCompletion = nextpas.core.webview.intf.IWebviewInvokeCompletion;
  IWebviewDispatcher       = nextpas.core.webview.intf.IWebviewDispatcher;
  IWebviewInvokeRegistry   = nextpas.core.webview.intf.IWebviewInvokeRegistry;
  IWebviewAssetProvider    = nextpas.core.webview.intf.IWebviewAssetProvider;
  IWebviewAssets           = nextpas.core.webview.intf.IWebviewAssets;
  IWebviewWindow           = nextpas.core.webview.intf.IWebviewWindow;
  IWebviewBuilder          = nextpas.core.webview.builder.IWebviewBuilder;

{ ---- 类型：window has-a（L3→L2 组合面，IWindow 显式别名） ---- }

  IWindow = nextpas.core.window.intf.IWindow;
  IWindowDispatcher = nextpas.core.window.intf.IWindowDispatcher;
  IWindowHost = nextpas.core.window.intf.IWindowHost;
  IWindowPrivateHandle = nextpas.core.window.intf.IWindowPrivateHandle;

  TWebviewBuilder = nextpas.core.webview.builder.TWebviewBuilder;

{ ---- 函数 inline 转发 ---- }

function DefaultWebviewOptions: TWebviewOptions; inline;
procedure CheckWebviewOptions(const AOptions: TWebviewOptions); inline;
procedure CheckInvokeCmd(const ACmd: string); inline;

function DefaultWebviewKind: TWebviewKind; inline;
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean; inline;
function CreateFakeWebview(const AOptions: TWebviewOptions): IWebviewWindow; inline;
function CreateFakeWebviewOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow; inline;
function CreateWebviewOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
function CreateVfsAssetProvider(const AVfs: IVfs): IWebviewAssetProvider; inline;

procedure WebviewRunLoop; inline;
procedure WebviewExitLoop; inline;

implementation

function DefaultWebviewOptions: TWebviewOptions;
begin
  Result := nextpas.core.webview.base.DefaultWebviewOptions;
end;

procedure CheckWebviewOptions(const AOptions: TWebviewOptions);
begin
  nextpas.core.webview.validation.CheckWebviewOptions(AOptions);
end;

procedure CheckInvokeCmd(const ACmd: string);
begin
  nextpas.core.webview.validation.CheckInvokeCmd(ACmd);
end;

function DefaultWebviewKind: TWebviewKind;
begin
  Result := nextpas.core.webview.factory.DefaultWebviewKind;
end;

function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;
begin
  Result := nextpas.core.webview.factory.WebviewBackendAvailable(AKind);
end;

function CreateFakeWebview(const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := nextpas.core.webview.factory.CreateFakeWebview(AOptions);
end;

function CreateFakeWebviewOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := nextpas.core.webview.factory.CreateFakeWebviewOn(AParent, AOptions);
end;

function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := nextpas.core.webview.factory.CreateWebviewOf(AKind, AOptions);
end;

function CreateWebviewOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := nextpas.core.webview.factory.CreateWebviewOn(AParent, AOptions);
end;

function CreateVfsAssetProvider(const AVfs: IVfs): IWebviewAssetProvider;
begin
  Result := nextpas.core.webview.vfs.CreateVfsAssetProvider(AVfs);
end;

procedure WebviewRunLoop;
begin
  nextpas.core.webview.factory.WebviewRunLoop;
end;

procedure WebviewExitLoop;
begin
  nextpas.core.webview.factory.WebviewExitLoop;
end;

end.
