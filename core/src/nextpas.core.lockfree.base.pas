unit nextpas.core.lockfree.base;

{$I nextpas.core.settings.inc}

interface

const
  LOCKFREE_SPIN_COUNT = 32;
  LOCKFREE_YIELD_COUNT = 32;

type
  TCacheLinePad = array[0..3] of Int64;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
function LockFreeIsPow2(const AValue: PtrUInt): Boolean;

implementation

uses
  nextpas.core.errors;

function LockFreeMaxPowerOfTwo: PtrUInt; inline;
var
  LMax: PtrUInt;
begin
  LMax := not PtrUInt(0);
  Result := LMax - (LMax shr 1);
end;

function LockFreeIsPow2(const AValue: PtrUInt): Boolean;
begin
  Result := (AValue > 0) and ((AValue and (AValue - 1)) = 0);
end;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
begin
  if LockFreeIsPow2(AValue) then
    Exit(AValue);
  if AValue > LockFreeMaxPowerOfTwo then
    raise EArgumentError.Create('LockFreeNextPow2: capacity exceeds maximum power-of-two');
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

end.
