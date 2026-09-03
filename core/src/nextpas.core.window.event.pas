unit nextpas.core.window.event;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.event.base,
  nextpas.core.window.event.intf,
  nextpas.core.window.event.impl,
  nextpas.core.window.base;

type
  TWindowEventHandle = nextpas.core.window.event.base.TWindowEventHandle;
  TWindowEventBusOptions = nextpas.core.window.event.base.TWindowEventBusOptions;
  EWindowEventError = nextpas.core.window.event.base.EWindowEventError;
  EWindowEventInvalidOptions = nextpas.core.window.event.base.EWindowEventInvalidOptions;
  EWindowEventHandleInvalid = nextpas.core.window.event.base.EWindowEventHandleInvalid;
  IWindowEventSubscription = nextpas.core.window.event.intf.IWindowEventSubscription;
  IWindowEventBus = nextpas.core.window.event.intf.IWindowEventBus;
  TWindowEventSubscriptionImpl = nextpas.core.window.event.impl.TWindowEventSubscriptionImpl;
  TWindowEventBusImpl = nextpas.core.window.event.impl.TWindowEventBusImpl;

function DefaultWindowEventBusOptions: TWindowEventBusOptions; inline;
procedure CheckWindowEventBusOptions(const AOptions: TWindowEventBusOptions); inline;
function WindowEventGrowCapacity(ACurrent: Integer): Integer; inline;
function CreateWindowEventBus: IWindowEventBus; inline; overload;
function CreateWindowEventBus(const AOptions: TWindowEventBusOptions): IWindowEventBus; inline; overload;

implementation

function DefaultWindowEventBusOptions: TWindowEventBusOptions; inline;
begin
  Result := nextpas.core.window.event.base.DefaultWindowEventBusOptions;
end;

procedure CheckWindowEventBusOptions(const AOptions: TWindowEventBusOptions); inline;
begin
  nextpas.core.window.event.impl.CheckWindowEventBusOptions(AOptions);
end;

function WindowEventGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := nextpas.core.window.event.impl.WindowEventGrowCapacity(ACurrent);
end;

function CreateWindowEventBus: IWindowEventBus; inline; overload;
begin
  Result := nextpas.core.window.event.impl.CreateWindowEventBus;
end;

function CreateWindowEventBus(const AOptions: TWindowEventBusOptions): IWindowEventBus; inline; overload;
begin
  Result := nextpas.core.window.event.impl.CreateWindowEventBus(AOptions);
end;

end.
