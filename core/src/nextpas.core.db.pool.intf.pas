unit nextpas.core.db.pool.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.pool.base,
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  IDbPoolLeaseDiagnostics = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE020}']
    function LeaseKind: TDbPoolLeaseKind;
    function HeldMs(const ANowTick: QWord; const ALeaseTick: QWord): QWord;
  end;

function DbPoolIsStale(const ACreatedTick, ANowTick: QWord; const AMaxLifetimeSec: Integer): Boolean; inline;
function DbPoolIsIdleStale(const AReturnedTick, ANowTick: QWord; const AIdleTimeoutSec: Integer): Boolean; inline;

implementation

uses
  nextpas.core.time;

function DbPoolIsStale(const ACreatedTick, ANowTick: QWord; const AMaxLifetimeSec: Integer): Boolean; inline;
begin
  { perf: inline int compare, zero-copy, single source monotonic tick }
  if AMaxLifetimeSec <= 0 then
    Exit(False);
  Result := ANowTick >= ACreatedTick + QWord(AMaxLifetimeSec) * 1000;
end;

function DbPoolIsIdleStale(const AReturnedTick, ANowTick: QWord; const AIdleTimeoutSec: Integer): Boolean; inline;
begin
  { perf: inline, no alloc, wall-clock check }
  if AIdleTimeoutSec <= 0 then
    Exit(False);
  Result := ANowTick >= AReturnedTick + QWord(AIdleTimeoutSec) * 1000;
end;

end.
