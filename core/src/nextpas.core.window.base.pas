unit nextpas.core.window.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

type
  TWindowKind = (wkGtk2, wkGtk3, wkGtk4, wkQt, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkFake);

  TWindowNativeHandle = type Pointer;

const
  wkGtk = wkGtk3;

type
  TWindowEventKind =
    (weResized, weMoved, weCloseRequested, weClosed, weFocusChanged, weScaleChanged, weDpiChanged);

const
  weFocusIn = weFocusChanged;
  weFocusOut = weFocusChanged;

type
  TWindowOptions = record
    Title: string;
    Width: Integer;
    Height: Integer;
    MinWidth: Integer;
    MinHeight: Integer;
    MaxWidth: Integer;
    MaxHeight: Integer;
    Resizable: Boolean;
    Maximized: Boolean;
    ParentHandle: TWindowNativeHandle;
  end;

  TWindowEvent = record
    Kind: TWindowEventKind;
    Width: Integer;
    Height: Integer;
    X: Integer;
    Y: Integer;
    NewScale: Double;
  end;

  TWindowEventHandler = reference to procedure(const AEvent: TWindowEvent);
  TWindowEventMethod = procedure(const AEvent: TWindowEvent) of object;
  TWindowEventProc = procedure(const AEvent: TWindowEvent);

function DefaultWindowOptions: TWindowOptions;
procedure CheckWindowOptions(const AOptions: TWindowOptions);

type
  EWindowError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowBackendUnavailable = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowNotInitialized = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowInvalidState = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowClosed = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowUnsupported = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowOptions: TWindowOptions;
begin
  Result.Title := '';
  Result.Width := 1024;
  Result.Height := 768;
  Result.MinWidth := 0;
  Result.MinHeight := 0;
  Result.MaxWidth := 0;
  Result.MaxHeight := 0;
  Result.Resizable := True;
  Result.Maximized := False;
  Result.ParentHandle := nil;
end;

procedure CheckWindowOptions(const AOptions: TWindowOptions);
begin
  if (AOptions.Width < 0) or (AOptions.Height < 0) then
    raise EWindowInvalidState.CreateFmt('Width/Height must be >= 0 (got %d, %d)', [AOptions.Width, AOptions.Height]);
  if (AOptions.MinWidth < 0) or (AOptions.MinHeight < 0) then
    raise EWindowInvalidState.CreateFmt('MinWidth/MinHeight must be >= 0 (got %d, %d)', [AOptions.MinWidth, AOptions.MinHeight]);
  if (AOptions.MaxWidth < 0) or (AOptions.MaxHeight < 0) then
    raise EWindowInvalidState.CreateFmt('MaxWidth/MaxHeight must be >= 0 (got %d, %d)', [AOptions.MaxWidth, AOptions.MaxHeight]);
  if (AOptions.MinWidth > 0) and (AOptions.MaxWidth > 0)
    and (AOptions.MaxWidth < AOptions.MinWidth) then
    raise EWindowInvalidState.CreateFmt('MaxWidth (%d) must be >= MinWidth (%d)', [AOptions.MaxWidth, AOptions.MinWidth]);
  if (AOptions.MinHeight > 0) and (AOptions.MaxHeight > 0)
    and (AOptions.MaxHeight < AOptions.MinHeight) then
    raise EWindowInvalidState.CreateFmt('MaxHeight (%d) must be >= MinHeight (%d)', [AOptions.MaxHeight, AOptions.MinHeight]);
end;

class function EWindowError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EWindowNotInitialized.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowInvalidState.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowClosed.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowUnsupported.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
