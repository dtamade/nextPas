unit nextpas.core.lockfree.base;

{$I nextpas.core.settings.inc}

interface

const
  LOCKFREE_SPIN_COUNT = 32;
  LOCKFREE_YIELD_COUNT = 32;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
function LockFreeIsPow2(const AValue: PtrUInt): Boolean;

implementation

function LockFreeIsPow2(const AValue: PtrUInt): Boolean;
begin
  Result := (AValue > 0) and ((AValue and (AValue - 1)) = 0);
end;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
begin
  if LockFreeIsPow2(AValue) then
    Exit(AValue);
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

end.
