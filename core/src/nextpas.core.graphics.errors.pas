{**
 * nextpas.core.graphics.errors - 图形族异常闭环
 * L1，仅 errors/exception，零 RTL。
 * CONTRACT §2：EGraphicsError → [EColorError,EImageError(EImageDecodeError),EVectorError,ECanvasError,EEffectError]
 * 收敛 image.png 存量 EIOError/EArgumentError 至 EImageDecodeError 语义。
 *}
unit nextpas.core.graphics.errors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  EGraphicsError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EColorError = class(EGraphicsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EImageError = class(EGraphicsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EImageDecodeError = class(EImageError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EVectorError = class(EGraphicsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  ECanvasError = class(EGraphicsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EEffectError = class(EGraphicsError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

class function EGraphicsError.DefaultCategory: TErrorCategory;
begin Result := ecInternal; end;

class function EColorError.DefaultCategory: TErrorCategory;
begin Result := ecInvalidArgument; end;

class function EImageError.DefaultCategory: TErrorCategory;
begin Result := ecIO; end;

class function EImageDecodeError.DefaultCategory: TErrorCategory;
begin Result := ecIO; end;

class function EVectorError.DefaultCategory: TErrorCategory;
begin Result := ecInternal; end;

class function ECanvasError.DefaultCategory: TErrorCategory;
begin Result := ecInternal; end;

class function EEffectError.DefaultCategory: TErrorCategory;
begin Result := ecInternal; end;

end.
