unit nextpas.core.window;

{** @desc nextpas.core.window 门面：聚合 re-export 全部公共 API，
       不含任何逻辑（design-conventions §2 门面职责）。

       消费方大多数时候只需 uses 本单元；只要类型的场景可改引
       *.base / *.intf 降低依赖闭包。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake,
  nextpas.core.window.factory;

{ ---- 类型：base ---- }

type
  TWindowKind = nextpas.core.window.base.TWindowKind;
  TWindowNativeHandle = nextpas.core.window.base.TWindowNativeHandle;
  TWindowOptions = nextpas.core.window.base.TWindowOptions;
  TWindowEventKind = nextpas.core.window.base.TWindowEventKind;
  TWindowEvent = nextpas.core.window.base.TWindowEvent;
  TWindowEventHandler = nextpas.core.window.base.TWindowEventHandler;
  TWindowEventMethod = nextpas.core.window.base.TWindowEventMethod;
  TWindowEventProc = nextpas.core.window.base.TWindowEventProc;

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

{ ---- 类型：intf 接口 ---- }

  IWindowDispatcher = nextpas.core.window.intf.IWindowDispatcher;
  IWindow = nextpas.core.window.intf.IWindow;
  IWindowBuilder = nextpas.core.window.factory.IWindowBuilder;

{ ---- 类型：fake 测试支撑 ---- }

  TFakeWindow = nextpas.core.window.fake.TFakeWindow;
  IFakeSelfAccess = nextpas.core.window.fake.IFakeSelfAccess;

  TWindowBuilder = nextpas.core.window.factory.TWindowBuilder;

{ ---- 函数 inline 转发 ---- }

function DefaultWindowOptions: TWindowOptions; inline;
procedure CheckWindowOptions(const AOptions: TWindowOptions); inline;

function WindowBackendAvailable(AKind: TWindowKind): Boolean; inline;
function DefaultWindowKind: TWindowKind; inline;
function WindowBackendDiagnostics: string; inline;
function CreateFakeWindow(const AOptions: TWindowOptions): IWindow; inline;
function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow; inline;

procedure WindowRunLoop; inline;
procedure WindowExitLoop; inline;
function WindowPumpOnce: Boolean; inline;
procedure WindowPumpAll; inline;
function FakeLiveWindowCount: Integer; inline;
procedure FakePumpAll; inline;
function FakeHasPendingPosts: Boolean; inline;

implementation

function DefaultWindowOptions: TWindowOptions;
begin
  Result := nextpas.core.window.base.DefaultWindowOptions;
end;

procedure CheckWindowOptions(const AOptions: TWindowOptions);
begin
  nextpas.core.window.base.CheckWindowOptions(AOptions);
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

function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;
begin
  Result := nextpas.core.window.factory.CreateFakeWindow(AOptions);
end;

function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
begin
  Result := nextpas.core.window.factory.CreateWindowOf(AKind, AOptions);
end;

procedure WindowRunLoop;
begin
  nextpas.core.window.factory.WindowRunLoop;
end;

procedure WindowExitLoop;
begin
  nextpas.core.window.factory.WindowExitLoop;
end;

function WindowPumpOnce: Boolean;
begin
  Result := nextpas.core.window.factory.WindowPumpOnce;
end;

procedure WindowPumpAll;
begin
  nextpas.core.window.factory.WindowPumpAll;
end;

function FakeLiveWindowCount: Integer;
begin
  Result := nextpas.core.window.fake.FakeLiveWindowCount;
end;

procedure FakePumpAll;
begin
  nextpas.core.window.fake.FakePumpAll;
end;

function FakeHasPendingPosts: Boolean;
begin
  Result := nextpas.core.window.fake.FakeHasPendingPosts;
end;

end.
