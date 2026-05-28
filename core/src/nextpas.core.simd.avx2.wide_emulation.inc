// === 512-bit 向量的 AVX2 仿真实现 (2×256-bit 操作) ===
// Performance tier — provides 2×256-bit emulation when AVX-512 unavailable.
// Faster than SSE2 wide_emulation (4×128) and scalar fallback.
// ============================================================================

// === F32x16 操作 (16×Float32) - 使用 2×F32x8 ===

function AVX2AddF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2AddF32x8(a.lo, b.lo);
  Result.hi := AVX2AddF32x8(a.hi, b.hi);
end;

function AVX2SubF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2SubF32x8(a.lo, b.lo);
  Result.hi := AVX2SubF32x8(a.hi, b.hi);
end;

function AVX2MulF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2MulF32x8(a.lo, b.lo);
  Result.hi := AVX2MulF32x8(a.hi, b.hi);
end;

function AVX2DivF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2DivF32x8(a.lo, b.lo);
  Result.hi := AVX2DivF32x8(a.hi, b.hi);
end;

function AVX2AbsF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2AbsF32x8(a.lo);
  Result.hi := AVX2AbsF32x8(a.hi);
end;

function AVX2SqrtF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2SqrtF32x8(a.lo);
  Result.hi := AVX2SqrtF32x8(a.hi);
end;

function AVX2MinF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2MinF32x8(a.lo, b.lo);
  Result.hi := AVX2MinF32x8(a.hi, b.hi);
end;

function AVX2MaxF32x16(const a, b: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2MaxF32x8(a.lo, b.lo);
  Result.hi := AVX2MaxF32x8(a.hi, b.hi);
end;

function AVX2FmaF32x16(const a, b, c: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2FmaF32x8(a.lo, b.lo, c.lo);
  Result.hi := AVX2FmaF32x8(a.hi, b.hi, c.hi);
end;

function AVX2FloorF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2FloorF32x8(a.lo);
  Result.hi := AVX2FloorF32x8(a.hi);
end;

function AVX2CeilF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2CeilF32x8(a.lo);
  Result.hi := AVX2CeilF32x8(a.hi);
end;

function AVX2RoundF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2RoundF32x8(a.lo);
  Result.hi := AVX2RoundF32x8(a.hi);
end;

function AVX2TruncF32x16(const a: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2TruncF32x8(a.lo);
  Result.hi := AVX2TruncF32x8(a.hi);
end;

function AVX2ClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16; inline;
begin
  Result.lo := AVX2ClampF32x8(a.lo, minVal.lo, maxVal.lo);
  Result.hi := AVX2ClampF32x8(a.hi, minVal.hi, maxVal.hi);
end;

function AVX2ReduceAddF32x16(const a: TVecF32x16): Single; inline;
begin
  Result := AVX2ReduceAddF32x8(a.lo) + AVX2ReduceAddF32x8(a.hi);
end;

function AVX2ReduceMinF32x16(const a: TVecF32x16): Single; inline;
var
  minLo, minHi: Single;
begin
  minLo := AVX2ReduceMinF32x8(a.lo);
  minHi := AVX2ReduceMinF32x8(a.hi);
  if minLo < minHi then
    Result := minLo
  else
    Result := minHi;
end;

function AVX2ReduceMaxF32x16(const a: TVecF32x16): Single; inline;
var
  maxLo, maxHi: Single;
begin
  maxLo := AVX2ReduceMaxF32x8(a.lo);
  maxHi := AVX2ReduceMaxF32x8(a.hi);
  if maxLo > maxHi then
    Result := maxLo
  else
    Result := maxHi;
end;

function AVX2ReduceMulF32x16(const a: TVecF32x16): Single; inline;
begin
  Result := AVX2ReduceMulF32x8(a.lo) * AVX2ReduceMulF32x8(a.hi);
end;

function AVX2LoadF32x16(p: PSingle): TVecF32x16; inline;
begin
  Result.lo := AVX2LoadF32x8(p);
  Result.hi := AVX2LoadF32x8(p + 8);
end;

procedure AVX2StoreF32x16(p: PSingle; const a: TVecF32x16); inline;
begin
  AVX2StoreF32x8(p, a.lo);
  AVX2StoreF32x8(p + 8, a.hi);
end;

function AVX2SplatF32x16(value: Single): TVecF32x16; inline;
begin
  Result.lo := AVX2SplatF32x8(value);
  Result.hi := AVX2SplatF32x8(value);
end;

function AVX2ZeroF32x16: TVecF32x16; inline;
begin
  Result.lo := AVX2ZeroF32x8;
  Result.hi := AVX2ZeroF32x8;
end;

function AVX2CmpEqF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] = b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpLtF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] < b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpLeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] <= b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpGtF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] > b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpGeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] >= b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpNeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] <> b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2SelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
  end;
end;

// === F64x8 操作 (8×Float64) - 使用 2×F64x4 ===

function AVX2AddF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2AddF64x4(a.lo, b.lo);
  Result.hi := AVX2AddF64x4(a.hi, b.hi);
end;

function AVX2SubF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2SubF64x4(a.lo, b.lo);
  Result.hi := AVX2SubF64x4(a.hi, b.hi);
end;

function AVX2MulF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2MulF64x4(a.lo, b.lo);
  Result.hi := AVX2MulF64x4(a.hi, b.hi);
end;

function AVX2DivF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2DivF64x4(a.lo, b.lo);
  Result.hi := AVX2DivF64x4(a.hi, b.hi);
end;

function AVX2AbsF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2AbsF64x4(a.lo);
  Result.hi := AVX2AbsF64x4(a.hi);
end;

function AVX2SqrtF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2SqrtF64x4(a.lo);
  Result.hi := AVX2SqrtF64x4(a.hi);
end;

function AVX2MinF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2MinF64x4(a.lo, b.lo);
  Result.hi := AVX2MinF64x4(a.hi, b.hi);
end;

function AVX2MaxF64x8(const a, b: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2MaxF64x4(a.lo, b.lo);
  Result.hi := AVX2MaxF64x4(a.hi, b.hi);
end;

function AVX2FmaF64x8(const a, b, c: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2FmaF64x4(a.lo, b.lo, c.lo);
  Result.hi := AVX2FmaF64x4(a.hi, b.hi, c.hi);
end;

function AVX2FloorF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2FloorF64x4(a.lo);
  Result.hi := AVX2FloorF64x4(a.hi);
end;

function AVX2CeilF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2CeilF64x4(a.lo);
  Result.hi := AVX2CeilF64x4(a.hi);
end;

function AVX2RoundF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2RoundF64x4(a.lo);
  Result.hi := AVX2RoundF64x4(a.hi);
end;

function AVX2TruncF64x8(const a: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2TruncF64x4(a.lo);
  Result.hi := AVX2TruncF64x4(a.hi);
end;

function AVX2ClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8; inline;
begin
  Result.lo := AVX2ClampF64x4(a.lo, minVal.lo, maxVal.lo);
  Result.hi := AVX2ClampF64x4(a.hi, minVal.hi, maxVal.hi);
end;

function AVX2ReduceAddF64x8(const a: TVecF64x8): Double; inline;
begin
  Result := AVX2ReduceAddF64x4(a.lo) + AVX2ReduceAddF64x4(a.hi);
end;

function AVX2ReduceMinF64x8(const a: TVecF64x8): Double; inline;
var
  minLo, minHi: Double;
begin
  minLo := AVX2ReduceMinF64x4(a.lo);
  minHi := AVX2ReduceMinF64x4(a.hi);
  if minLo < minHi then
    Result := minLo
  else
    Result := minHi;
end;

function AVX2ReduceMaxF64x8(const a: TVecF64x8): Double; inline;
var
  maxLo, maxHi: Double;
begin
  maxLo := AVX2ReduceMaxF64x4(a.lo);
  maxHi := AVX2ReduceMaxF64x4(a.hi);
  if maxLo > maxHi then
    Result := maxLo
  else
    Result := maxHi;
end;

function AVX2ReduceMulF64x8(const a: TVecF64x8): Double; inline;
begin
  Result := AVX2ReduceMulF64x4(a.lo) * AVX2ReduceMulF64x4(a.hi);
end;

function AVX2LoadF64x8(p: PDouble): TVecF64x8; inline;
begin
  Result.lo := AVX2LoadF64x4(p);
  Result.hi := AVX2LoadF64x4(p + 4);
end;

procedure AVX2StoreF64x8(p: PDouble; const a: TVecF64x8); inline;
begin
  AVX2StoreF64x4(p, a.lo);
  AVX2StoreF64x4(p + 4, a.hi);
end;

function AVX2SplatF64x8(value: Double): TVecF64x8; inline;
begin
  Result.lo := AVX2SplatF64x4(value);
  Result.hi := AVX2SplatF64x4(value);
end;

function AVX2ZeroF64x8: TVecF64x8; inline;
begin
  Result.lo := AVX2ZeroF64x4;
  Result.hi := AVX2ZeroF64x4;
end;

function AVX2CmpEqF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] = b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpLtF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] < b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpLeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] <= b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpGtF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] > b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpGeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] >= b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2CmpNeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] <> b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function AVX2SelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    if (mask and (1 shl i)) <> 0 then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := b.d[i];
  end;
end;

// === I32x16 操作 (16×Int32) - 使用 2×I32x8 ===

function AVX2AddI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2AddI32x8(a.lo, b.lo);
  Result.hi := AVX2AddI32x8(a.hi, b.hi);
end;

function AVX2SubI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2SubI32x8(a.lo, b.lo);
  Result.hi := AVX2SubI32x8(a.hi, b.hi);
end;

function AVX2MulI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2MulI32x8(a.lo, b.lo);
  Result.hi := AVX2MulI32x8(a.hi, b.hi);
end;

function AVX2AndI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2AndI32x8(a.lo, b.lo);
  Result.hi := AVX2AndI32x8(a.hi, b.hi);
end;

function AVX2OrI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2OrI32x8(a.lo, b.lo);
  Result.hi := AVX2OrI32x8(a.hi, b.hi);
end;

function AVX2XorI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2XorI32x8(a.lo, b.lo);
  Result.hi := AVX2XorI32x8(a.hi, b.hi);
end;

function AVX2NotI32x16(const a: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2NotI32x8(a.lo);
  Result.hi := AVX2NotI32x8(a.hi);
end;

function AVX2AndNotI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2AndNotI32x8(a.lo, b.lo);
  Result.hi := AVX2AndNotI32x8(a.hi, b.hi);
end;

function AVX2ShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16; inline;
begin
  Result.lo := AVX2ShiftLeftI32x8(a.lo, count);
  Result.hi := AVX2ShiftLeftI32x8(a.hi, count);
end;

function AVX2ShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16; inline;
begin
  Result.lo := AVX2ShiftRightI32x8(a.lo, count);
  Result.hi := AVX2ShiftRightI32x8(a.hi, count);
end;

function AVX2ShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16; inline;
begin
  Result.lo := AVX2ShiftRightArithI32x8(a.lo, count);
  Result.hi := AVX2ShiftRightArithI32x8(a.hi, count);
end;

function AVX2CmpEqI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpEqI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpEqI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2CmpLtI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpLtI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpLtI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2CmpGtI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpGtI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpGtI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2CmpLeI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpLeI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpLeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2CmpGeI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpGeI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpGeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2CmpNeI32x16(const a, b: TVecI32x16): TMask16; inline;
begin
  Result := (AVX2CmpNeI32x8(a.lo, b.lo) and $FF) or ((AVX2CmpNeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function AVX2MinI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2MinI32x8(a.lo, b.lo);
  Result.hi := AVX2MinI32x8(a.hi, b.hi);
end;

function AVX2MaxI32x16(const a, b: TVecI32x16): TVecI32x16; inline;
begin
  Result.lo := AVX2MaxI32x8(a.lo, b.lo);
  Result.hi := AVX2MaxI32x8(a.hi, b.hi);
end;

// === I64x8 Operations (512-bit emulated via 2×I64x4) ===

function AVX2AddI64x8(const a, b: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2AddI64x4(a.lo, b.lo);
  Result.hi := AVX2AddI64x4(a.hi, b.hi);
end;

function AVX2SubI64x8(const a, b: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2SubI64x4(a.lo, b.lo);
  Result.hi := AVX2SubI64x4(a.hi, b.hi);
end;

function AVX2AndI64x8(const a, b: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2AndI64x4(a.lo, b.lo);
  Result.hi := AVX2AndI64x4(a.hi, b.hi);
end;

function AVX2OrI64x8(const a, b: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2OrI64x4(a.lo, b.lo);
  Result.hi := AVX2OrI64x4(a.hi, b.hi);
end;

function AVX2XorI64x8(const a, b: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2XorI64x4(a.lo, b.lo);
  Result.hi := AVX2XorI64x4(a.hi, b.hi);
end;

function AVX2NotI64x8(const a: TVecI64x8): TVecI64x8; inline;
begin
  Result.lo := AVX2NotI64x4(a.lo);
  Result.hi := AVX2NotI64x4(a.hi);
end;

function AVX2CmpEqI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpEqI64x4(a.lo, b.lo) and $F) or ((AVX2CmpEqI64x4(a.hi, b.hi) and $F) shl 4);
end;

function AVX2CmpLtI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpLtI64x4(a.lo, b.lo) and $F) or ((AVX2CmpLtI64x4(a.hi, b.hi) and $F) shl 4);
end;

function AVX2CmpGtI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpGtI64x4(a.lo, b.lo) and $F) or ((AVX2CmpGtI64x4(a.hi, b.hi) and $F) shl 4);
end;

function AVX2CmpLeI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpLeI64x4(a.lo, b.lo) and $F) or ((AVX2CmpLeI64x4(a.hi, b.hi) and $F) shl 4);
end;

function AVX2CmpGeI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpGeI64x4(a.lo, b.lo) and $F) or ((AVX2CmpGeI64x4(a.hi, b.hi) and $F) shl 4);
end;

function AVX2CmpNeI64x8(const a, b: TVecI64x8): TMask8; inline;
begin
  Result := (AVX2CmpNeI64x4(a.lo, b.lo) and $F) or ((AVX2CmpNeI64x4(a.hi, b.hi) and $F) shl 4);
end;

// === Extract/Insert Operations ===

// F32x8 (256-bit): 使用 VEXTRACTF128 提取高/低半部分
function AVX2ExtractF32x8(const a: TVecF32x8; index: Integer): Single;
begin
  if (index < 0) or (index > 7) then
    Result := 0.0
  else
    Result := a.f[index];
end;

function AVX2InsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
begin
  Result := a;
  if (index >= 0) and (index <= 7) then
    Result.f[index] := value;
end;

// F64x2 (128-bit)
function AVX2ExtractF64x2(const a: TVecF64x2; index: Integer): Double;
begin
  if (index < 0) or (index > 1) then
    Result := 0.0
  else
    Result := a.d[index];
end;

function AVX2InsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
begin
  Result := a;
  if (index >= 0) and (index <= 1) then
    Result.d[index] := value;
end;

// F64x4 (256-bit)
function AVX2ExtractF64x4(const a: TVecF64x4; index: Integer): Double;
begin
  if (index < 0) or (index > 3) then
    Result := 0.0
  else
    Result := a.d[index];
end;

function AVX2InsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
begin
  Result := a;
  if (index >= 0) and (index <= 3) then
    Result.d[index] := value;
end;

// I32x4 (128-bit)
function AVX2ExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
begin
  if (index < 0) or (index > 3) then
    Result := 0
  else
    Result := a.i[index];
end;

function AVX2InsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
begin
  Result := a;
  if (index >= 0) and (index <= 3) then
    Result.i[index] := value;
end;

// I32x8 (256-bit)
function AVX2ExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
begin
  if (index < 0) or (index > 7) then
    Result := 0
  else
    Result := a.i[index];
end;

function AVX2InsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
begin
  Result := a;
  if (index >= 0) and (index <= 7) then
    Result.i[index] := value;
end;

// I64x2 (128-bit)
function AVX2ExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
begin
  if (index < 0) or (index > 1) then
    Result := 0
  else
    Result := a.i[index];
end;

function AVX2InsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
begin
  Result := a;
  if (index >= 0) and (index <= 1) then
    Result.i[index] := value;
end;

// I64x4 (256-bit)
function AVX2ExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
begin
  if (index < 0) or (index > 3) then
    Result := 0
  else
    Result := a.i[index];
end;

function AVX2InsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
begin
  Result := a;
  if (index >= 0) and (index <= 3) then
    Result.i[index] := value;
end;

// F32x16 (512-bit)
function AVX2ExtractF32x16(const a: TVecF32x16; index: Integer): Single;
begin
  if (index < 0) or (index > 15) then
    Result := 0.0
  else
    Result := a.f[index];
end;

function AVX2InsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
begin
  Result := a;
  if (index >= 0) and (index <= 15) then
    Result.f[index] := value;
end;

// I32x16 (512-bit)
function AVX2ExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
begin
  if (index < 0) or (index > 15) then
    Result := 0
  else
    Result := a.i[index];
end;

function AVX2InsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
begin
  Result := a;
  if (index >= 0) and (index <= 15) then
    Result.i[index] := value;
end;

function AVX2AddI16x32(const a, b: TVecI16x32): TVecI16x32;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vmovdqu ymm1, [rdx+32]
    vpaddw  ymm0, ymm0, [rcx]
    vpaddw  ymm1, ymm1, [rcx+32]
    vmovdqu [rax], ymm0
    vmovdqu [rax+32], ymm1
    vzeroupper
  end;
end;

function AVX2MulU32x16(const a, b: TVecU32x16): TVecU32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vmovdqu ymm1, [rdx+32]
    vpmulld ymm0, ymm0, [rcx]
    vpmulld ymm1, ymm1, [rcx+32]
    vmovdqu [rax], ymm0
    vmovdqu [rax+32], ymm1
    vzeroupper
  end;
end;

function AVX2AddU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vmovdqu ymm1, [rdx+32]
    vpaddq  ymm0, ymm0, [rcx]
    vpaddq  ymm1, ymm1, [rcx+32]
    vmovdqu [rax], ymm0
    vmovdqu [rax+32], ymm1
    vzeroupper
  end;
end;

function AVX2MaxU8x64(const a, b: TVecU8x64): TVecU8x64;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vmovdqu ymm1, [rdx+32]
    vpmaxub ymm0, ymm0, [rcx]
    vpmaxub ymm1, ymm1, [rcx+32]
    vmovdqu [rax], ymm0
    vmovdqu [rax+32], ymm1
    vzeroupper
  end;
end;
