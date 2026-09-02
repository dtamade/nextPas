unit nextpas.core.http.impl.h2.defense.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.impl.h2.defense.base;

type
  IHttpH2Defense = interface
    ['{C1D2E3F4-A5B6-4C7D-8E9F-3456789012CD}']
    procedure RegisterRapidReset;
    procedure RegisterControlFrameFlood;
    procedure EscalateHeaderBlockFlood;
    function ShouldGoAway: Boolean;
    procedure MarkRequestHandled;
  end;

function H2DefenseShouldGoAway(const ACnt: TH2DefenseCounters): Boolean; inline;

implementation

function H2DefenseShouldGoAway(const ACnt: TH2DefenseCounters): Boolean; inline;
begin
  Result := (ACnt.RapidResetCount >= H2_MAX_RAPID_RESETS) or
            (ACnt.ControlFrameFloodCount >= H2_MAX_CONTROL_FRAME_FLOOD);
end;

end.
