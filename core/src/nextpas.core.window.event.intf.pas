unit nextpas.core.window.event.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.event.base,
  nextpas.core.window.base;

type
  IWindowEventSubscription = interface
    ['{A1B2C3D4-2002-4F60-9A8B-C0D1E2F3A211}']
    function GetHandle: TWindowEventHandle;
    procedure Unsubscribe;
    function IsActive: Boolean;
    property Handle: TWindowEventHandle read GetHandle;
  end;

  IWindowEventBus = interface
    ['{A1B2C3D4-2002-4F60-9A8B-C0D1E2F3A212}']
    function Subscribe(AHandler: TWindowEventHandler): IWindowEventSubscription; overload;
    function Subscribe(AHandler: TWindowEventMethod): IWindowEventSubscription; overload;
    function Subscribe(AHandler: TWindowEventProc): IWindowEventSubscription; overload;
    procedure Unsubscribe(const AHandle: TWindowEventHandle);
    procedure Clear;
    function Count: Integer;
    procedure Dispatch(const AEvent: TWindowEvent);
    function GetOptions: TWindowEventBusOptions;
    procedure SetOptions(const AOptions: TWindowEventBusOptions);
    property Options: TWindowEventBusOptions read GetOptions write SetOptions;
  end;

implementation

end.
