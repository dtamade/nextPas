unit nextpas.core.window.chrome.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.chrome.base;

type
  IWindowChrome = interface
    ['{A1B2C3D4-1002-4F60-9A8B-C0D1E2F3A101}']
    procedure Apply(const AOptions: TWindowChromeOptions);
    function GetOptions: TWindowChromeOptions;
    procedure SetOpacity(AOpacity: Double);
    function GetOpacity: Double;
    property Options: TWindowChromeOptions read GetOptions;
    property Opacity: Double read GetOpacity write SetOpacity;
  end;

implementation

end.
