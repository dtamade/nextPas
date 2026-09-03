unit nextpas.core.window;

{**
 * @desc nextpas.core.window 门面：聚合 re-export 公共 API，不含逻辑。
 *
 * @note 家族内特权 shard 不经本门面 re-export，仅 window.* 后端 uses；
 *       详见 core/docs/window/CONTRACT.md §1。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.impl,
  nextpas.core.window.factory;

{ ---- 类型：base ---- }

type
  TWindowKind = nextpas.core.window.base.TWindowKind;
  TWindowNativeHandle = nextpas.core.window.base.TWindowNativeHandle;
  TWindowSize = nextpas.core.window.base.TWindowSize;
  TWindowConstraints = nextpas.core.window.base.TWindowConstraints;
  TWindowOptions = nextpas.core.window.base.TWindowOptions;
  TWindowEventKind = nextpas.core.window.base.TWindowEventKind;
  TWindowPixel = nextpas.core.window.base.TWindowPixel;
  TWindowScale = nextpas.core.window.base.TWindowScale;
  TWindowEvent = nextpas.core.window.base.TWindowEvent;
  TWindowEventHandler = nextpas.core.window.base.TWindowEventHandler;
  TWindowEventMethod = nextpas.core.window.base.TWindowEventMethod;
  TWindowEventProc = nextpas.core.window.base.TWindowEventProc;
  TWindowEventDispatchKind = nextpas.core.window.base.TWindowEventDispatchKind;
  TWindowEventVariant = nextpas.core.window.base.TWindowEventVariant;

  EWindowError = nextpas.core.window.base.EWindowError;
  EWindowBackendUnavailable = nextpas.core.window.base.EWindowBackendUnavailable;
  EWindowNotInitialized = nextpas.core.window.base.EWindowNotInitialized;
  EWindowInvalidState = nextpas.core.window.base.EWindowInvalidState;
  EWindowClosed = nextpas.core.window.base.EWindowClosed;
  EWindowUnsupported = nextpas.core.window.base.EWindowUnsupported;

{ ---- 类型：intf 回调 ---- }

  TWindowProcRef    = nextpas.core.window.intf.TWindowProcRef;
  TWindowProcMethod = nextpas.core.window.intf.TWindowProcMethod;
  TWindowProc       = nextpas.core.window.intf.TWindowProc;

{ ---- 类型：intf 接口（小接口组合） ---- }

  IWindowDispatcher = nextpas.core.window.intf.IWindowDispatcher;
  IWindowLifecycle = nextpas.core.window.intf.IWindowLifecycle;
  IWindowVisibility = nextpas.core.window.intf.IWindowVisibility;
  IWindowTitle = nextpas.core.window.intf.IWindowTitle;
  IWindowGeometry = nextpas.core.window.intf.IWindowGeometry;
  IWindowState = nextpas.core.window.intf.IWindowState;
  IWindowScale = nextpas.core.window.intf.IWindowScale;
  IWindowNativeHandle = nextpas.core.window.intf.IWindowNativeHandle;
  IWindowDispatcherProvider = nextpas.core.window.intf.IWindowDispatcherProvider;
  IWindowEvents = nextpas.core.window.intf.IWindowEvents;
  IWindow = nextpas.core.window.intf.IWindow;
  IWindowHost = nextpas.core.window.intf.IWindowHost;
  IWindowBuilder = nextpas.core.window.factory.IWindowBuilder;

  TWindowBuilder = nextpas.core.window.factory.TWindowBuilder;

{ ---- 函数 inline 转发 ---- }

function DefaultWindowOptions: TWindowOptions; inline;
procedure CheckWindowOptions(const AOptions: TWindowOptions); inline;

function WindowBackendAvailable(AKind: TWindowKind): Boolean;
function DefaultWindowKind: TWindowKind;
function WindowBackendDiagnostics: string;
function CreateFakeWindow(const AOptions: TWindowOptions): IWindow; inline;
function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow; inline;

procedure WindowRunLoop; inline;
procedure WindowExitLoop; inline;
function WindowPumpOnce: Boolean; inline;
procedure WindowPumpAll; inline;

implementation

function DefaultWindowOptions: TWindowOptions; inline;
begin
  Result := nextpas.core.window.base.DefaultWindowOptions;
end;

procedure CheckWindowOptions(const AOptions: TWindowOptions); inline;
begin
  nextpas.core.window.impl.CheckWindowOptions(AOptions);
end;

function WindowBackendAvailable(AKind: TWindowKind): Boolean;
begin
  Result := nextpas.core.window.factory.WindowBackendAvailable(AKind);
end;

function DefaultWindowKind: TWindowKind;
begin
  Result := nextpas.core.window.factory.DefaultWindowKind;
end;

function WindowBackendDiagnostics: string;
begin
  Result := nextpas.core.window.factory.WindowBackendDiagnostics;
end;

function CreateFakeWindow(const AOptions: TWindowOptions): IWindow; inline;
begin
  Result := nextpas.core.window.factory.CreateFakeWindow(AOptions);
end;

function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow; inline;
begin
  Result := nextpas.core.window.factory.CreateWindowOf(AKind, AOptions);
end;

procedure WindowRunLoop; inline;
begin
  nextpas.core.window.factory.WindowRunLoop;
end;

procedure WindowExitLoop; inline;
begin
  nextpas.core.window.factory.WindowExitLoop;
end;

function WindowPumpOnce: Boolean; inline;
begin
  Result := nextpas.core.window.factory.WindowPumpOnce;
end;

procedure WindowPumpAll; inline;
begin
  nextpas.core.window.factory.WindowPumpAll;
end;

end.
