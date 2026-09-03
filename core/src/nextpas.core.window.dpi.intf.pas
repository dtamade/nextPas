unit nextpas.core.window.dpi.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.dpi.base;

type
  TWindowDpiChangedHandler = reference to procedure(const AInfo: TWindowDpiInfo);
  TWindowDpiChangedMethod = procedure(const AInfo: TWindowDpiInfo) of object;
  TWindowDpiChangedProc = procedure(const AInfo: TWindowDpiInfo);

  IWindowDpiSubscription = interface
    ['{A1B2C3D4-2001-4F60-9A8B-C0D1E2F3A201}']
    procedure Unsubscribe;
    function IsActive: Boolean;
  end;

  IWindowDpi = interface
    ['{A1B2C3D4-2001-4F60-9A8B-C0D1E2F3A202}']
    function GetScaleFactor: Double;
    function GetMonitorScale(AMonitor: TWindowDpiMonitorId): Double;
    function Subscribe(AHandler: TWindowDpiChangedHandler): IWindowDpiSubscription; overload;
    function Subscribe(AHandler: TWindowDpiChangedMethod): IWindowDpiSubscription; overload;
    function Subscribe(AHandler: TWindowDpiChangedProc): IWindowDpiSubscription; overload;
    procedure NotifyChanged(const AInfo: TWindowDpiInfo);
    function GetOptions: TWindowDpiOptions;
    procedure SetOptions(const AOptions: TWindowDpiOptions);
    property Options: TWindowDpiOptions read GetOptions write SetOptions;
  end;

implementation

end.
