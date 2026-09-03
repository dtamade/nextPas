unit nextpas.core.window.chrome.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowChromeOptions = record
    Decorated: Boolean;
    Transparent: Boolean;
    Shadow: Boolean;
    AnimationMs: Integer;
    Opacity: Double;
  end;

function DefaultWindowChromeOptions: TWindowChromeOptions; inline;

type
  EWindowChromeError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowChromeInvalidOptions = class(EWindowChromeError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowChromeOptions: TWindowChromeOptions; inline;
begin
  Result.Decorated := True;
  Result.Transparent := False;
  Result.Shadow := True;
  Result.AnimationMs := 0;
  Result.Opacity := 1.0;
end;

class function EWindowChromeError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowChromeInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
