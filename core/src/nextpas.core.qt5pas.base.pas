unit nextpas.core.qt5pas.base;

{** @desc nextpas.core.qt5pas L2 家族：公共类型根（窗口壳最小需求占位）。
       只依赖 errors owner；禁止 uses 本家族 ffi/loader/后端单元。

       本单元为后续 IWindow/Qt 桥接保留最小词汇：句柄别名、窗口标志、
       几何/标题约束常量与错误族。当前阶段仅占位，不引入逻辑。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  {** Qt 窗口标志（占位，映射 Qt::WindowFlags 子集，实际值由 ffi 侧解释） *}
  QT_WINDOW_FLAG_TOPLEVEL = $00000000;
  QT_WINDOW_FLAG_DIALOG   = $00000002;

  {** 默认窗口几何占位（与 window.base 对齐，便于后续对接 IWindow） *}
  QT5PAS_DEFAULT_WIDTH  = 1024;
  QT5PAS_DEFAULT_HEIGHT = 768;

type
  {** 不透明 Qt 句柄别名（QApplication*/QWidget*/QWindow*/Hook* 统一承载） *}
  TQt5PasHandle = type Pointer;
  TQt5PasWidgetHandle = type Pointer;
  TQt5PasWindowHandle = type Pointer;
  TQt5PasAppHandle = type Pointer;
  TQt5PasHookHandle = type Pointer;

  {** 窗口选项占位（deferred 前最小集，仅保留标题与几何） *}
  TQt5PasWindowOptions = record
    Title: string;
    Width: Integer;
    Height: Integer;
    Resizable: Boolean;
  end;

{** 默认选项 *}
function DefaultQt5PasWindowOptions: TQt5PasWindowOptions;

{** 错误族（类目与 window.base 对齐） *}
type
  EQt5PasError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EQt5PasBackendUnavailable = class(EQt5PasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EQt5PasNotInitialized = class(EQt5PasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultQt5PasWindowOptions: TQt5PasWindowOptions;
begin
  Result.Title := '';
  Result.Width := QT5PAS_DEFAULT_WIDTH;
  Result.Height := QT5PAS_DEFAULT_HEIGHT;
  Result.Resizable := True;
end;

class function EQt5PasError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EQt5PasBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EQt5PasNotInitialized.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
