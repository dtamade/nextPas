unit nextpas.core.simd.vec16;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// TMask16 is defined in nextpas.core.simd.base

// === Byte-lane compare (16 bytes → 16-bit mask) ===

function Vec16CmpEq(AData: PByte; AValue: Byte): TMask16; inline;
function Vec16CmpEq2(AData, APattern: PByte): TMask16; inline;
function Vec16CmpLtU(AData: PByte; AThreshold: Byte): TMask16; inline;
function Vec16CmpGtU(AData: PByte; AThreshold: Byte): TMask16; inline;
function Vec16CmpRange(AData: PByte; ALo, AHi: Byte): TMask16; inline;

// === Mask manipulation ===

function Vec16Ctz(AMask: TMask16): Int32; inline;
function Vec16Popcnt(AMask: TMask16): Int32; inline;

// === Byte-lane transform (in-place, 16 bytes) ===

procedure Vec16AddWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
procedure Vec16SubWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;

implementation

{$IFDEF CPUX86_64}
  {$I nextpas.core.simd.vec16.x86_64.inc}
{$ELSEIF Defined(CPUAARCH64)}
  {$I nextpas.core.simd.vec16.aarch64.inc}
{$ELSE}
  {$I nextpas.core.simd.vec16.scalar.inc}
{$ENDIF}

end.
