// === Utility Operations ===

function NEONSplatF32x4(value: Single): TVecF32x4;
begin
  Result := ScalarSplatF32x4(value);
end;

function NEONZeroF32x4: TVecF32x4;
begin
  Result := Default(TVecF32x4);
end;

function NEONSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarSelectF32x4(mask, a, b);
end;

function NEONExtractF32x4(const a: TVecF32x4; index: Integer): Single;
begin
  Result := ScalarExtractF32x4(a, index);
end;

function NEONInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
begin
  Result := ScalarInsertF32x4(a, value, index);
end;

{$I nextpas.core.simd.neon.facade_scalar.inc}

// Saturating Arithmetic Scalar Fallback
// 用于 FPC < 3.3.1 或非 ARM 平台

function NEONI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarI8x16SatAdd(a, b);
end;

function NEONI8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarI8x16SatSub(a, b);
end;

function NEONI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarI16x8SatAdd(a, b);
end;

function NEONI16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarI16x8SatSub(a, b);
end;

function NEONU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarU8x16SatAdd(a, b);
end;

function NEONU8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarU8x16SatSub(a, b);
end;

function NEONU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarU16x8SatAdd(a, b);
end;

function NEONU16x8SatSub(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarU16x8SatSub(a, b);
end;

// Narrow Integer Types Scalar Fallback
// 用于 FPC < 3.3.1 或非 ARM 平台

// --- I16x8 Scalar Fallback ---
function NEONAddI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarAddI16x8(a, b); end;

function NEONSubI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarSubI16x8(a, b); end;

function NEONMulI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarMulI16x8(a, b); end;

function NEONAndI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarAndI16x8(a, b); end;

function NEONOrI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarOrI16x8(a, b); end;

function NEONXorI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarXorI16x8(a, b); end;

function NEONNotI16x8(const a: TVecI16x8): TVecI16x8;
begin Result := ScalarNotI16x8(a); end;

function NEONAndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarAndNotI16x8(a, b); end;

function NEONMinI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarMinI16x8(a, b); end;

function NEONMaxI16x8(const a, b: TVecI16x8): TVecI16x8;
begin Result := ScalarMaxI16x8(a, b); end;

// --- I8x16 Scalar Fallback ---
function NEONAddI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarAddI8x16(a, b); end;

function NEONSubI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarSubI8x16(a, b); end;

function NEONAndI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarAndI8x16(a, b); end;

function NEONOrI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarOrI8x16(a, b); end;

function NEONXorI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarXorI8x16(a, b); end;

function NEONNotI8x16(const a: TVecI8x16): TVecI8x16;
begin Result := ScalarNotI8x16(a); end;

function NEONMinI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarMinI8x16(a, b); end;

function NEONMaxI8x16(const a, b: TVecI8x16): TVecI8x16;
begin Result := ScalarMaxI8x16(a, b); end;

// --- U16x8 Scalar Fallback ---
function NEONAddU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarAddU16x8(a, b); end;

function NEONSubU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarSubU16x8(a, b); end;

function NEONMulU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarMulU16x8(a, b); end;

function NEONAndU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarAndU16x8(a, b); end;

function NEONOrU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarOrU16x8(a, b); end;

function NEONXorU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarXorU16x8(a, b); end;

function NEONNotU16x8(const a: TVecU16x8): TVecU16x8;
begin Result := ScalarNotU16x8(a); end;

function NEONMinU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarMinU16x8(a, b); end;

function NEONMaxU16x8(const a, b: TVecU16x8): TVecU16x8;
begin Result := ScalarMaxU16x8(a, b); end;

// --- U8x16 Scalar Fallback ---
function NEONAddU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarAddU8x16(a, b); end;

function NEONSubU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarSubU8x16(a, b); end;

function NEONAndU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarAndU8x16(a, b); end;

function NEONOrU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarOrU8x16(a, b); end;

function NEONXorU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarXorU8x16(a, b); end;

function NEONNotU8x16(const a: TVecU8x16): TVecU8x16;
begin Result := ScalarNotU8x16(a); end;

function NEONMinU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarMinU8x16(a, b); end;

function NEONMaxU8x16(const a, b: TVecU8x16): TVecU8x16;
begin Result := ScalarMaxU8x16(a, b); end;

// I64x2 Scalar Fallback (用于 FPC < 3.3.1 或非 ARM 平台)
function NEONAddI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarAddI64x2(a, b);
end;

function NEONSubI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarSubI64x2(a, b);
end;

function NEONAndI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarAndI64x2(a, b);
end;

function NEONOrI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarOrI64x2(a, b);
end;

function NEONXorI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarXorI64x2(a, b);
end;

function NEONNotI64x2(const a: TVecI64x2): TVecI64x2;
begin
  Result := ScalarNotI64x2(a);
end;

function NEONAndNotI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result := ScalarAndNotI64x2(a, b);
end;

function NEONShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result := ScalarShiftLeftI64x2(a, count);
end;

function NEONShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result := ScalarShiftRightI64x2(a, count);
end;

function NEONShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result := ScalarShiftRightArithI64x2(a, count);
end;

function NEONAddU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarAddU64x2(a, b);
end;

function NEONSubU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarSubU64x2(a, b);
end;

function NEONAndU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarAndU64x2(a, b);
end;

function NEONOrU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarOrU64x2(a, b);
end;

function NEONXorU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarXorU64x2(a, b);
end;

function NEONNotU64x2(const a: TVecU64x2): TVecU64x2;
begin
  Result := ScalarNotU64x2(a);
end;

function NEONAndNotU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarAndNotU64x2(a, b);
end;

function NEONCmpEqU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := ScalarCmpEqU64x2(a, b);
end;

function NEONCmpLtU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := ScalarCmpLtU64x2(a, b);
end;

function NEONCmpGtU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := ScalarCmpGtU64x2(a, b);
end;

function NEONMinU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarMinU64x2(a, b);
end;

function NEONMaxU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarMaxU64x2(a, b);
end;

function NEONCmpEqI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpEqI64x2(a, b);
end;

function NEONCmpLtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpLtI64x2(a, b);
end;

function NEONCmpGtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpGtI64x2(a, b);
end;

function NEONCmpLeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpLeI64x2(a, b);
end;

function NEONCmpGeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpGeI64x2(a, b);
end;

function NEONCmpNeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := ScalarCmpNeI64x2(a, b);
end;

// SelectF64x2 (Pascal Implementation)
function NEONSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarSelectF64x2(mask, a, b);
end;
