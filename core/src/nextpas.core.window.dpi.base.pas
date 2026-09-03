unit nextpas.core.window.dpi.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowDpiMonitorId = type UInt32;

  TWindowDpiInfo = record
    MonitorId: TWindowDpiMonitorId;
    ScaleFactor: Double;
    Width: Integer;
    Height: Integer;
  end;

  TWindowDpiOptions = record
    MonitorId: TWindowDpiMonitorId;
    ListenPerMonitor: Boolean;
  end;

function DefaultWindowDpiOptions: TWindowDpiOptions; inline;
function DefaultWindowDpiInfo: TWindowDpiInfo; inline;

type
  EWindowDpiError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowDpiInvalidOptions = class(EWindowDpiError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

function DefaultWindowDpiOptions: TWindowDpiOptions; inline;
begin
  Result.MonitorId := 0;
  Result.ListenPerMonitor := True;
end;

function DefaultWindowDpiInfo: TWindowDpiInfo; inline;
begin
  Result.MonitorId := 0;
  Result.ScaleFactor := 1.0;
  Result.Width := 0;
  Result.Height := 0;
end;

class function EWindowDpiError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowDpiInvalidOptions.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
