unit nextpas.core.qt;

{** @desc nextpas.core.qt 门面：聚合 re-export 全部公共 API，
       不含任何逻辑（design-conventions §2 门面职责）。

       自包装 C shim 桩阶段（deferred）：loader 以 BindOpt 装载，
       符号缺席不报错，Loaded 仅反映主库是否加载成功。触发条件与
       shim 契约见 core/docs/qt/README.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.qt.base,
  nextpas.core.qt.ffi,
  nextpas.core.qt.loader;

type
  TQtHandle = nextpas.core.qt.base.TQtHandle;
  TQtAppHandle = nextpas.core.qt.base.TQtAppHandle;
  TQtWindowHandle = nextpas.core.qt.base.TQtWindowHandle;
  TQtWindowOptions = nextpas.core.qt.base.TQtWindowOptions;
  TQtLoadInfo = nextpas.core.qt.loader.TQtLoadInfo;

  EQtError = nextpas.core.qt.base.EQtError;
  EQtBackendUnavailable = nextpas.core.qt.base.EQtBackendUnavailable;
  EQtNotInitialized = nextpas.core.qt.base.EQtNotInitialized;

function DefaultQtWindowOptions: TQtWindowOptions; inline;

function TryLoadQt(out AInfo: TQtLoadInfo): Boolean; inline;
procedure UnloadQt; inline;
function QtLoadInfo: TQtLoadInfo; inline;
function QtIsLoaded: Boolean; inline;

implementation

function DefaultQtWindowOptions: TQtWindowOptions;
begin
  Result := nextpas.core.qt.base.DefaultQtWindowOptions;
end;

function TryLoadQt(out AInfo: TQtLoadInfo): Boolean;
begin
  Result := nextpas.core.qt.loader.TryLoadQt(AInfo);
end;

procedure UnloadQt;
begin
  nextpas.core.qt.loader.UnloadQt;
end;

function QtLoadInfo: TQtLoadInfo;
begin
  Result := nextpas.core.qt.loader.QtLoadInfo;
end;

function QtIsLoaded: Boolean;
begin
  Result := nextpas.core.qt.loader.QtIsLoaded;
end;

end.
