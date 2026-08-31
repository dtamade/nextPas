unit nextpas.core.app;

{** @desc nextpas.core.app 门面：聚合 re-export 应用壳全部公共 API。
       P3 自动摘除 + OnWindowClosed 聚合 + GetWindows 快照；多窗薄封装，
       零逻辑重复，复用 webview 单源（WebviewGrowCapacity / CheckWebviewOptions）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory,
  nextpas.core.app.base,
  nextpas.core.app.intf,
  nextpas.core.app.factory;

type
  TAppOptions = nextpas.core.app.base.TAppOptions;
  TAppKind = nextpas.core.app.base.TAppKind;
  TAppNativeHandle = nextpas.core.app.base.TAppNativeHandle;

  EAppError = nextpas.core.app.base.EAppError;
  EAppBackendUnavailable = nextpas.core.app.base.EAppBackendUnavailable;
  EAppInvalidState = nextpas.core.app.base.EAppInvalidState;
  EAppClosed = nextpas.core.app.base.EAppClosed;

  IApp = nextpas.core.app.intf.IApp;
  IAppBuilder = nextpas.core.app.intf.IAppBuilder;

  TAppBuilder = nextpas.core.app.factory.TAppBuilder;

  TWebviewKind = nextpas.core.webview.base.TWebviewKind;
  IWebviewWindow = nextpas.core.webview.intf.IWebviewWindow;
  IWebviewBuilder = nextpas.core.webview.factory.IWebviewBuilder;

function DefaultAppOptions: TAppOptions; inline;
procedure CheckAppOptions(const AOptions: TAppOptions); inline;
function DefaultAppKind: TAppKind; inline;
function AppBackendAvailable(AKind: TAppKind): Boolean; inline;

implementation

function DefaultAppOptions: TAppOptions;
begin
  Result := nextpas.core.app.base.DefaultAppOptions;
end;

procedure CheckAppOptions(const AOptions: TAppOptions);
begin
  nextpas.core.app.base.CheckAppOptions(AOptions);
end;

function DefaultAppKind: TAppKind;
begin
  Result := nextpas.core.app.factory.DefaultAppKind;
end;

function AppBackendAvailable(AKind: TAppKind): Boolean;
begin
  Result := nextpas.core.app.factory.AppBackendAvailable(AKind);
end;

end.
