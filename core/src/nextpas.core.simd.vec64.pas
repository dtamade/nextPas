unit nextpas.core.simd.vec64;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// === Byte-lane compare (64 bytes → 64-bit mask) ===

function Vec64CmpEq(AData: PByte; AValue: Byte): TMask64; inline;
function Vec64CmpEq2(AData, APattern: PByte): TMask64; inline;
function Vec64CmpLtU(AData: PByte; AThreshold: Byte): TMask64; inline;
function Vec64CmpGtU(AData: PByte; AThreshold: Byte): TMask64; inline;
function Vec64CmpRange(AData: PByte; ALo, AHi: Byte): TMask64; inline;

// === Mask manipulation ===

function Vec64Ctz(AMask: TMask64): Int32; inline;
function Vec64Popcnt(AMask: TMask64): Int32; inline;

// === Byte-lane transform (in-place, 64 bytes) ===

procedure Vec64AddWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;
procedure Vec64SubWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;

implementation

{$IF Defined(CPUX86_64) and Defined(HAS_AVX512)}
  {$I nextpas.core.simd.vec64.avx512.inc}
{$ELSE}
  {$I nextpas.core.simd.vec64.scalar.inc}
{$ENDIF}

end.
