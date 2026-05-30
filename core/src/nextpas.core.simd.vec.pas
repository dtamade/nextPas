unit nextpas.core.simd.vec;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base,
  {$IFDEF HAS_AVX2}
  nextpas.core.simd.vec32;
  {$ELSE}
  nextpas.core.simd.vec16;
  {$ENDIF}

const
  VecWidth = {$IFDEF HAS_AVX2} 32 {$ELSE} 16 {$ENDIF};

type
  TVecMask = {$IFDEF HAS_AVX2} TMask32 {$ELSE} TMask16 {$ENDIF};

function VecCmpEq(AData: PByte; AValue: Byte): TVecMask; inline;
function VecCmpEq2(AData, APattern: PByte): TVecMask; inline;
function VecCmpLtU(AData: PByte; AThreshold: Byte): TVecMask; inline;
function VecCmpGtU(AData: PByte; AThreshold: Byte): TVecMask; inline;
function VecCmpRange(AData: PByte; ALo, AHi: Byte): TVecMask; inline;
function VecCtz(AMask: TVecMask): Int32; inline;
function VecFirstSet(AMask: TVecMask): Int32; inline;
function VecPopcnt(AMask: TVecMask): Int32; inline;

implementation

function VecCmpEq(AData: PByte; AValue: Byte): TVecMask; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpEq(AData, AValue);
  {$ELSE}
  Result := Vec16CmpEq(AData, AValue);
  {$ENDIF}
end;

function VecCmpEq2(AData, APattern: PByte): TVecMask; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpEq2(AData, APattern);
  {$ELSE}
  Result := Vec16CmpEq2(AData, APattern);
  {$ENDIF}
end;

function VecCmpLtU(AData: PByte; AThreshold: Byte): TVecMask; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpLtU(AData, AThreshold);
  {$ELSE}
  Result := Vec16CmpLtU(AData, AThreshold);
  {$ENDIF}
end;

function VecCmpGtU(AData: PByte; AThreshold: Byte): TVecMask; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpGtU(AData, AThreshold);
  {$ELSE}
  Result := Vec16CmpGtU(AData, AThreshold);
  {$ENDIF}
end;

function VecCmpRange(AData: PByte; ALo, AHi: Byte): TVecMask; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpRange(AData, ALo, AHi);
  {$ELSE}
  Result := Vec16CmpRange(AData, ALo, AHi);
  {$ENDIF}
end;

function VecCtz(AMask: TVecMask): Int32; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32Ctz(AMask);
  {$ELSE}
  Result := Vec16Ctz(AMask);
  {$ENDIF}
end;

function VecFirstSet(AMask: TVecMask): Int32; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32FirstSet(AMask);
  {$ELSE}
  Result := Vec16FirstSet(AMask);
  {$ENDIF}
end;

function VecPopcnt(AMask: TVecMask): Int32; inline;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32Popcnt(AMask);
  {$ELSE}
  Result := Vec16Popcnt(AMask);
  {$ENDIF}
end;

end.
