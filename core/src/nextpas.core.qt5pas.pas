unit nextpas.core.qt5pas;

{** @desc nextpas.core.qt5pas 门面：聚合 re-export 全部公共 API，
       不含任何逻辑（design-conventions §2 门面职责）。

       消费方大多数时候只需 uses 本单元；只要类型的场景可改引
       *.base 降低依赖闭包。实际窗口后端实现位于后续的
       nextpas.core.window.qt5pas.*（待立项），本家族当前仅提供
       ABI/装载占位。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.qt5pas.base,
  nextpas.core.qt5pas.ffi,
  nextpas.core.qt5pas.loader;

type
  TQt5PasHandle = nextpas.core.qt5pas.base.TQt5PasHandle;
  TQt5PasWidgetHandle = nextpas.core.qt5pas.base.TQt5PasWidgetHandle;
  TQt5PasWindowHandle = nextpas.core.qt5pas.base.TQt5PasWindowHandle;
  TQt5PasAppHandle = nextpas.core.qt5pas.base.TQt5PasAppHandle;
  TQt5PasHookHandle = nextpas.core.qt5pas.base.TQt5PasHookHandle;
  TQt5PasWindowOptions = nextpas.core.qt5pas.base.TQt5PasWindowOptions;
  TQt5PasLoadInfo = nextpas.core.qt5pas.loader.TQt5PasLoadInfo;

  EQt5PasError = nextpas.core.qt5pas.base.EQt5PasError;
  EQt5PasBackendUnavailable = nextpas.core.qt5pas.base.EQt5PasBackendUnavailable;
  EQt5PasNotInitialized = nextpas.core.qt5pas.base.EQt5PasNotInitialized;

function DefaultQt5PasWindowOptions: TQt5PasWindowOptions; inline;

function TryLoadQt5Pas(out AInfo: TQt5PasLoadInfo): Boolean; inline;
procedure UnloadQt5Pas; inline;
function Qt5PasLoadInfo: TQt5PasLoadInfo; inline;
function Qt5PasIsLoaded: Boolean; inline;

implementation

function DefaultQt5PasWindowOptions: TQt5PasWindowOptions;
begin
  Result := nextpas.core.qt5pas.base.DefaultQt5PasWindowOptions;
end;

function TryLoadQt5Pas(out AInfo: TQt5PasLoadInfo): Boolean;
begin
  Result := nextpas.core.qt5pas.loader.TryLoadQt5Pas(AInfo);
end;

procedure UnloadQt5Pas;
begin
  nextpas.core.qt5pas.loader.UnloadQt5Pas;
end;

function Qt5PasLoadInfo: TQt5PasLoadInfo;
begin
  Result := nextpas.core.qt5pas.loader.Qt5PasLoadInfo;
end;

function Qt5PasIsLoaded: Boolean;
begin
  Result := nextpas.core.qt5pas.loader.Qt5PasIsLoaded;
end;

end.
