unit nextpas.core.window.constraints.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.constraints.base;

type
  IWindowConstraints = interface
    ['{C1D2E3F4-1003-4F60-9A8B-C0D1E2F3A103}']
    function GetConstraints: TWindowConstraints;
    procedure SetConstraints(const AConstraints: TWindowConstraints);
    procedure SetMinSize(AWidth, AHeight: Integer);
    procedure SetMaxSize(AWidth, AHeight: Integer);
    procedure Apply(const AConstraints: TWindowConstraints);
    property Constraints: TWindowConstraints read GetConstraints write SetConstraints;
  end;

implementation

end.
