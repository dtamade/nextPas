unit nextpas.core.simd.group;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.vec16;

type
  TGroupMask = nextpas.core.simd.vec16.TMask16;

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
function GroupCtz(AMask: TGroupMask): Int32; inline;
function GroupPopcnt(AMask: TGroupMask): Int32; inline;

implementation

function GroupMatch(ACtrl: PByte; AValue: Byte): TGroupMask; inline;
begin
  Result := Vec16CmpEq(ACtrl, AValue);
end;

function GroupCtz(AMask: TGroupMask): Int32; inline;
begin
  Result := Vec16Ctz(AMask);
end;

function GroupPopcnt(AMask: TGroupMask): Int32; inline;
begin
  Result := Vec16Popcnt(AMask);
end;

end.
