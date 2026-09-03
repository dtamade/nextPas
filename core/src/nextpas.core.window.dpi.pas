unit nextpas.core.window.dpi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.dpi.base,
  nextpas.core.window.dpi.intf,
  nextpas.core.window.dpi.impl;

type
  TWindowDpiMonitorId = nextpas.core.window.dpi.base.TWindowDpiMonitorId;
  TWindowDpiInfo = nextpas.core.window.dpi.base.TWindowDpiInfo;
  TWindowDpiOptions = nextpas.core.window.dpi.base.TWindowDpiOptions;
  EWindowDpiError = nextpas.core.window.dpi.base.EWindowDpiError;
  EWindowDpiInvalidOptions = nextpas.core.window.dpi.base.EWindowDpiInvalidOptions;
  IWindowDpiSubscription = nextpas.core.window.dpi.intf.IWindowDpiSubscription;
  IWindowDpi = nextpas.core.window.dpi.intf.IWindowDpi;
  TWindowDpiChangedHandler = nextpas.core.window.dpi.intf.TWindowDpiChangedHandler;
  TWindowDpiChangedMethod = nextpas.core.window.dpi.intf.TWindowDpiChangedMethod;
  TWindowDpiChangedProc = nextpas.core.window.dpi.intf.TWindowDpiChangedProc;
  TWindowDpiSubscriptionImpl = nextpas.core.window.dpi.impl.TWindowDpiSubscriptionImpl;
  TWindowDpiImpl = nextpas.core.window.dpi.impl.TWindowDpiImpl;

function DefaultWindowDpiOptions: TWindowDpiOptions; inline;
function DefaultWindowDpiInfo: TWindowDpiInfo; inline;
procedure CheckWindowDpiOptions(const AOptions: TWindowDpiOptions); inline;
function WindowDpiGrowCapacity(ACurrent: Integer): Integer; inline;
function CreateWindowDpi: IWindowDpi; inline; overload;
function CreateWindowDpi(const AOptions: TWindowDpiOptions): IWindowDpi; inline; overload;

implementation

function DefaultWindowDpiOptions: TWindowDpiOptions; inline;
begin
  Result := nextpas.core.window.dpi.base.DefaultWindowDpiOptions;
end;

function DefaultWindowDpiInfo: TWindowDpiInfo; inline;
begin
  Result := nextpas.core.window.dpi.base.DefaultWindowDpiInfo;
end;

procedure CheckWindowDpiOptions(const AOptions: TWindowDpiOptions); inline;
begin
  nextpas.core.window.dpi.impl.CheckWindowDpiOptions(AOptions);
end;

function WindowDpiGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.window.dpi.impl.WindowDpiGrowCapacity(ACurrent);
end;

function CreateWindowDpi: IWindowDpi; inline; overload;
begin
  Result := nextpas.core.window.dpi.impl.CreateWindowDpi;
end;

function CreateWindowDpi(const AOptions: TWindowDpiOptions): IWindowDpi; inline; overload;
begin
  Result := nextpas.core.window.dpi.impl.CreateWindowDpi(AOptions);
end;

end.
