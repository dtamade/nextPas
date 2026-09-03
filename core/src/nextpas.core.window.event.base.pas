unit nextpas.core.window.event.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowEventHandle = record
    Id: UInt64;
    Generation: UInt32;
    class function Invalid: TWindowEventHandle; static; inline;
    function IsValid: Boolean; inline;
  end;

  TWindowEventBusOptions = record
    MaxHandlers: Integer;
  end;

function DefaultWindowEventBusOptions: TWindowEventBusOptions; inline;

type
  EWindowEventError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowEventInvalidOptions = class(EWindowEventError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowEventHandleInvalid = class(EWindowEventError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

class function TWindowEventHandle.Invalid: TWindowEventHandle; static; inline;
begin
  Result.Id := 0;
  Result.Generation := 0;
end;

function TWindowEventHandle.IsValid: Boolean; inline;
begin
  Result := Id <> 0;
end;

function DefaultWindowEventBusOptions: TWindowEventBusOptions; inline;
begin
  Result.MaxHandlers := 0;
end;

class function EWindowEventError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowEventInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowEventHandleInvalid.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
