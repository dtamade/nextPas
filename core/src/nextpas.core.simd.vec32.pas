unit nextpas.core.simd.vec32;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// === Byte-lane compare (32 bytes → 32-bit mask) ===

function Vec32CmpEq(AData: PByte; AValue: Byte): TMask32; inline;
function Vec32CmpEq2(AData, APattern: PByte): TMask32; inline;
function Vec32CmpLtU(AData: PByte; AThreshold: Byte): TMask32; inline;
function Vec32CmpGtU(AData: PByte; AThreshold: Byte): TMask32; inline;
function Vec32CmpRange(AData: PByte; ALo, AHi: Byte): TMask32; inline;

// === Mask manipulation ===

function Vec32Ctz(AMask: TMask32): Int32; inline;
function Vec32FirstSet(AMask: TMask32): Int32; inline;
function Vec32Popcnt(AMask: TMask32): Int32; inline;

// === Byte-lane transform (in-place, 32 bytes) ===

procedure Vec32AddWhere(AData: PByte; AMask: TMask32; ADelta: Byte); inline;
procedure Vec32SubWhere(AData: PByte; AMask: TMask32; ADelta: Byte); inline;

implementation

{$IF Defined(CPUX86_64) and Defined(HAS_AVX2)}
  {$I nextpas.core.simd.vec32.avx2.inc}
{$ELSE}
  {$I nextpas.core.simd.vec32.scalar.inc}
{$ENDIF}

end.
