unit nextpas.core.db.async.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.async.base;

type
  IDbAsyncPolicyView = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE023}']
    function Kind: TDbAsyncKind;
    function TickMs: Integer;
  end;

function DbAsyncIsSingleFlight(const AInFlight: Boolean): Boolean; inline;

implementation

function DbAsyncIsSingleFlight(const AInFlight: Boolean): Boolean; inline;
begin
  { perf: inline branch, zero-copy, single-flight discipline }
  Result := not AInFlight;
end;

end.
