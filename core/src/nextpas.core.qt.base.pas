unit nextpas.core.qt.base;

{** @desc nextpas.core.qt L2 家族：自包装 C shim 的公共类型根（deferred 占位）。
       只依赖 errors owner；禁止 uses 本家族 ffi/loader/后端单元。

       本单元为 vendors/libnextpas-qt 自包装方案预留最小词汇，当前阶段
       仅占位，不引入逻辑。触发条件见 core/docs/qt/README.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  {** 自包装库 soname 占位 *}
  QT_SHIM_SONAME     = 'libnextpas-qt.so';
  QT_SHIM_SONAME_V1  = 'libnextpas-qt.so.1';

  QT_DEFAULT_WIDTH  = 1024;
  QT_DEFAULT_HEIGHT = 768;

type
  {** 不透明句柄别名（qt_app*/qt_window* 统一承载） *}
  TQtHandle = type Pointer;
  TQtAppHandle = type Pointer;
  TQtWindowHandle = type Pointer;

  {** 窗口选项占位（deferred 前最小集） *}
  TQtWindowOptions = record
    Title: string;
    Width: Integer;
    Height: Integer;
    Resizable: Boolean;
  end;

function DefaultQtWindowOptions: TQtWindowOptions;

type
  EQtError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EQtBackendUnavailable = class(EQtError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EQtNotInitialized = class(EQtError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultQtWindowOptions: TQtWindowOptions;
begin
  Result.Title := '';
  Result.Width := QT_DEFAULT_WIDTH;
  Result.Height := QT_DEFAULT_HEIGHT;
  Result.Resizable := True;
end;

class function EQtError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EQtBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EQtNotInitialized.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
