unit nextpas.core.window.loop.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowLoopOptions = record
    TickIntervalMs: Integer;
    PumpBudget: Integer;
  end;

  TWindowLoopTickResult = (wltrIdle, wltrWork, wltrClosed);

function DefaultWindowLoopOptions: TWindowLoopOptions; inline;

type
  EWindowLoopError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowLoopInvalidOptions = class(EWindowLoopError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowLoopOptions: TWindowLoopOptions; inline;
begin
  Result.TickIntervalMs := 16;
  Result.PumpBudget := 0;
end;

class function EWindowLoopError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowLoopInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
