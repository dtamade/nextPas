unit nextpas.core.simd.intrinsics.avx2;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.avx2 ===
  Active AVX2 intrinsics leaf.
  AVX2 extends 256-bit SIMD coverage with broader integer support than AVX.
  Highlights:
  - 256-bit integer operations
  - variable shift instructions
  - gather loads
  - broadcast helpers
  Compatibility: Intel Haswell (2013) and newer processors.
}

interface

uses
  nextpas.core.errors,
  nextpas.core.simd.intrinsics.base;

// === AVX2 256-bit 整数运算 ===
// Load/Store
function avx2_load_si256(const Ptr: Pointer): TM256;
function avx2_loadu_si256(const Ptr: Pointer): TM256;
procedure avx2_store_si256(var Dest; const Src: TM256);
procedure avx2_storeu_si256(var Dest; const Src: TM256);

// Set/Zero
function avx2_setzero_si256: TM256;
function avx2_set1_epi32(Value: LongInt): TM256;
function avx2_set1_epi16(Value: SmallInt): TM256;
function avx2_set1_epi8(Value: ShortInt): TM256;

// Arithmetic
function avx2_add_epi32(const a, b: TM256): TM256;
function avx2_add_epi16(const a, b: TM256): TM256;
function avx2_add_epi8(const a, b: TM256): TM256;
function avx2_sub_epi32(const a, b: TM256): TM256;
function avx2_sub_epi16(const a, b: TM256): TM256;
function avx2_sub_epi8(const a, b: TM256): TM256;

// Multiply
function avx2_mullo_epi32(const a, b: TM256): TM256;
function avx2_mullo_epi16(const a, b: TM256): TM256;
function avx2_mulhi_epi16(const a, b: TM256): TM256;
function avx2_mulhi_epu16(const a, b: TM256): TM256;

// Logical
function avx2_and_si256(const a, b: TM256): TM256;
function avx2_andnot_si256(const a, b: TM256): TM256;
function avx2_or_si256(const a, b: TM256): TM256;
function avx2_xor_si256(const a, b: TM256): TM256;

// Compare
function avx2_cmpeq_epi32(const a, b: TM256): TM256;
function avx2_cmpeq_epi16(const a, b: TM256): TM256;
function avx2_cmpeq_epi8(const a, b: TM256): TM256;
function avx2_cmpgt_epi32(const a, b: TM256): TM256;
function avx2_cmpgt_epi16(const a, b: TM256): TM256;
function avx2_cmpgt_epi8(const a, b: TM256): TM256;

// Min/Max
function avx2_max_epi32(const a, b: TM256): TM256;
function avx2_max_epi16(const a, b: TM256): TM256;
function avx2_max_epi8(const a, b: TM256): TM256;
function avx2_min_epi32(const a, b: TM256): TM256;
function avx2_min_epi16(const a, b: TM256): TM256;
function avx2_min_epi8(const a, b: TM256): TM256;

// Variable Shift (AVX2-specific helpers)
function avx2_sllv_epi32(const a, count: TM256): TM256;
function avx2_sllv_epi64(const a, count: TM256): TM256;
function avx2_srlv_epi32(const a, count: TM256): TM256;
function avx2_srlv_epi64(const a, count: TM256): TM256;
function avx2_srav_epi32(const a, count: TM256): TM256;

// Broadcast (AVX2-specific helpers)
function avx2_broadcastss_ps(const a: TM128): TM256;
function avx2_broadcastsd_pd(const a: TM128): TM256;
function avx2_broadcastsi128_si256(const a: TM128): TM256;

// Gather (AVX2-specific helpers)
function avx2_gather_epi32(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
function avx2_gather_epi64(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;
function avx2_gather_ps(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
function avx2_gather_pd(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;

// Pack/Unpack
function avx2_packs_epi32(const a, b: TM256): TM256;
function avx2_packs_epi16(const a, b: TM256): TM256;
function avx2_packus_epi32(const a, b: TM256): TM256;
function avx2_packus_epi16(const a, b: TM256): TM256;
function avx2_unpackhi_epi32(const a, b: TM256): TM256;
function avx2_unpackhi_epi16(const a, b: TM256): TM256;
function avx2_unpackhi_epi8(const a, b: TM256): TM256;
function avx2_unpacklo_epi32(const a, b: TM256): TM256;
function avx2_unpacklo_epi16(const a, b: TM256): TM256;
function avx2_unpacklo_epi8(const a, b: TM256): TM256;

// Permute
function avx2_permute4x64_epi64(const a: TM256; imm8: Byte): TM256;
function avx2_permute4x64_pd(const a: TM256; imm8: Byte): TM256;
function avx2_permutevar8x32_epi32(const a, idx: TM256): TM256;
function avx2_permutevar8x32_ps(const a: TM256; const idx: TM256): TM256;

implementation

// === 基础函数实现 (Pascal 版本) ===
function avx2_load_si256(const Ptr: Pointer): TM256;
begin
  Result := PTM256(Ptr)^;
end;

function avx2_loadu_si256(const Ptr: Pointer): TM256;
begin
  Result := PTM256(Ptr)^;
end;

procedure avx2_store_si256(var Dest; const Src: TM256);
begin
  PTM256(@Dest)^ := Src;
end;

procedure avx2_storeu_si256(var Dest; const Src: TM256);
begin
  PTM256(@Dest)^ := Src;
end;

function avx2_setzero_si256: TM256;
begin
  Result.m256i_u64[0] := 0;
  Result.m256i_u64[1] := 0;
  Result.m256i_u64[2] := 0;
  Result.m256i_u64[3] := 0;
end;

function avx2_set1_epi32(Value: LongInt): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_i32[i] := Value;
end;

function avx2_set1_epi16(Value: SmallInt): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m256i_i16[i] := Value;
end;

function avx2_set1_epi8(Value: ShortInt): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    Result.m256i_i8[i] := Value;
end;

function avx2_add_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_i32[i] := a.m256i_i32[i] + b.m256i_i32[i];
end;

function avx2_add_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m256i_i16[i] := a.m256i_i16[i] + b.m256i_i16[i];
end;

function avx2_add_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    Result.m256i_i8[i] := a.m256i_i8[i] + b.m256i_i8[i];
end;

function avx2_sub_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_i32[i] := a.m256i_i32[i] - b.m256i_i32[i];
end;

function avx2_sub_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m256i_i16[i] := a.m256i_i16[i] - b.m256i_i16[i];
end;

function avx2_sub_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    Result.m256i_i8[i] := a.m256i_i8[i] - b.m256i_i8[i];
end;

function avx2_mullo_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_i32[i] := a.m256i_i32[i] * b.m256i_i32[i];
end;

function avx2_mullo_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m256i_i16[i] := a.m256i_i16[i] * b.m256i_i16[i];
end;

function avx2_mulhi_epi16(const a, b: TM256): TM256;
var
  i: Integer;
  temp: LongInt;
begin
  for i := 0 to 15 do
  begin
    temp := LongInt(a.m256i_i16[i]) * LongInt(b.m256i_i16[i]);
    Result.m256i_i16[i] := SmallInt(temp shr 16);
  end;
end;

function avx2_mulhi_epu16(const a, b: TM256): TM256;
var
  i: Integer;
  temp: Cardinal;
begin
  for i := 0 to 15 do
  begin
    temp := Cardinal(a.m256i_u16[i]) * Cardinal(b.m256i_u16[i]);
    Result.m256i_u16[i] := UInt16(temp shr 16);
  end;
end;

function avx2_and_si256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] and b.m256i_u32[i];
end;

function avx2_andnot_si256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := (not a.m256i_u32[i]) and b.m256i_u32[i];
end;

function avx2_or_si256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] or b.m256i_u32[i];
end;

function avx2_xor_si256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] xor b.m256i_u32[i];
end;

function avx2_cmpeq_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256i_i32[i] = b.m256i_i32[i] then
      Result.m256i_u32[i] := $FFFFFFFF
    else
      Result.m256i_u32[i] := $00000000;
end;

function avx2_cmpeq_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m256i_i16[i] = b.m256i_i16[i] then
      Result.m256i_u16[i] := $FFFF
    else
      Result.m256i_u16[i] := $0000;
end;

function avx2_cmpeq_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    if a.m256i_i8[i] = b.m256i_i8[i] then
      Result.m256i_u8[i] := $FF
    else
      Result.m256i_u8[i] := $00;
end;

function avx2_cmpgt_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256i_i32[i] > b.m256i_i32[i] then
      Result.m256i_u32[i] := $FFFFFFFF
    else
      Result.m256i_u32[i] := $00000000;
end;

function avx2_cmpgt_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m256i_i16[i] > b.m256i_i16[i] then
      Result.m256i_u16[i] := $FFFF
    else
      Result.m256i_u16[i] := $0000;
end;

function avx2_cmpgt_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    if a.m256i_i8[i] > b.m256i_i8[i] then
      Result.m256i_u8[i] := $FF
    else
      Result.m256i_u8[i] := $00;
end;

function avx2_max_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256i_i32[i] > b.m256i_i32[i] then
      Result.m256i_i32[i] := a.m256i_i32[i]
    else
      Result.m256i_i32[i] := b.m256i_i32[i];
end;

function avx2_max_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m256i_i16[i] > b.m256i_i16[i] then
      Result.m256i_i16[i] := a.m256i_i16[i]
    else
      Result.m256i_i16[i] := b.m256i_i16[i];
end;

function avx2_max_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    if a.m256i_i8[i] > b.m256i_i8[i] then
      Result.m256i_i8[i] := a.m256i_i8[i]
    else
      Result.m256i_i8[i] := b.m256i_i8[i];
end;

function avx2_min_epi32(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256i_i32[i] < b.m256i_i32[i] then
      Result.m256i_i32[i] := a.m256i_i32[i]
    else
      Result.m256i_i32[i] := b.m256i_i32[i];
end;

function avx2_min_epi16(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m256i_i16[i] < b.m256i_i16[i] then
      Result.m256i_i16[i] := a.m256i_i16[i]
    else
      Result.m256i_i16[i] := b.m256i_i16[i];
end;

function avx2_min_epi8(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 31 do
    if a.m256i_i8[i] < b.m256i_i8[i] then
      Result.m256i_i8[i] := a.m256i_i8[i]
    else
      Result.m256i_i8[i] := b.m256i_i8[i];
end;

// === Simplified AVX2-specific implementations ===
function avx2_sllv_epi32(const a, count: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if count.m256i_u32[i] >= 32 then
      Result.m256i_u32[i] := 0
    else
      Result.m256i_u32[i] := a.m256i_u32[i] shl count.m256i_u32[i];
end;

function avx2_sllv_epi64(const a, count: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if count.m256i_u64[i] >= 64 then
      Result.m256i_u64[i] := 0
    else
      Result.m256i_u64[i] := a.m256i_u64[i] shl count.m256i_u64[i];
end;

function avx2_srlv_epi32(const a, count: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if count.m256i_u32[i] >= 32 then
      Result.m256i_u32[i] := 0
    else
      Result.m256i_u32[i] := a.m256i_u32[i] shr count.m256i_u32[i];
end;

function avx2_srlv_epi64(const a, count: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if count.m256i_u64[i] >= 64 then
      Result.m256i_u64[i] := 0
    else
      Result.m256i_u64[i] := a.m256i_u64[i] shr count.m256i_u64[i];
end;

function avx2_srav_epi32(const a, count: TM256): TM256;
var
  i: Integer;
  shift_count: Cardinal;
  value: LongInt;
begin
  for i := 0 to 7 do
  begin
    shift_count := count.m256i_u32[i];
    if shift_count >= 32 then
      shift_count := 31;
    
    value := a.m256i_i32[i];
    if shift_count = 0 then
      Result.m256i_i32[i] := value
    else if value >= 0 then
      Result.m256i_i32[i] := value shr shift_count
    else
      Result.m256i_i32[i] := (value shr shift_count) or ((-1) shl (32 - shift_count));
  end;
end;

function avx2_broadcastss_ps(const a: TM128): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m128_f32[0];
end;

function avx2_broadcastsd_pd(const a: TM128): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m128d_f64[0];
end;

function avx2_broadcastsi128_si256(const a: TM128): TM256;
begin
  Result.m256_m128[0] := a;
  Result.m256_m128[1] := a;
end;

// 复杂函数实现（Pascal 回退语义）

function ValidateGatherScale(const aScale: Integer): PtrInt; inline;
begin
  case aScale of
    1, 2, 4, 8:
      Result := aScale;
  else
    raise EArgumentError.CreateFmt('AVX2 gather scale must be 1,2,4,8 (got %d)', [aScale]);
  end;
end;

function SaturateI32ToI16(const aValue: LongInt): SmallInt; inline;
begin
  if aValue > High(SmallInt) then
    Exit(High(SmallInt));
  if aValue < Low(SmallInt) then
    Exit(Low(SmallInt));
  Result := SmallInt(aValue);
end;

function SaturateI16ToI8(const aValue: SmallInt): ShortInt; inline;
begin
  if aValue > High(ShortInt) then
    Exit(High(ShortInt));
  if aValue < Low(ShortInt) then
    Exit(Low(ShortInt));
  Result := ShortInt(aValue);
end;

function SaturateI32ToU16(const aValue: LongInt): Word; inline;
begin
  if aValue < 0 then
    Exit(0);
  if aValue > High(Word) then
    Exit(High(Word));
  Result := Word(aValue);
end;

function SaturateI16ToU8(const aValue: SmallInt): Byte; inline;
begin
  if aValue < 0 then
    Exit(0);
  if aValue > High(Byte) then
    Exit(High(Byte));
  Result := Byte(aValue);
end;

function avx2_gather_epi32(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
var
  LBase: PByte;
  LScale: PtrInt;
  LOffset: PtrInt;
  LIndex: Integer;
begin
  if base_addr = nil then
    raise ENullReferenceError.Create('base_addr');

  LScale := ValidateGatherScale(scale);
  LBase := PByte(base_addr);

  for LIndex := 0 to 7 do
  begin
    LOffset := PtrInt(vindex.m256i_i32[LIndex]) * LScale;
    Result.m256i_i32[LIndex] := PLongInt(LBase + LOffset)^;
  end;
end;

function avx2_gather_epi64(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;
var
  LBase: PByte;
  LScale: PtrInt;
  LOffset: PtrInt;
  LIndex: Integer;
begin
  if base_addr = nil then
    raise ENullReferenceError.Create('base_addr');

  LScale := ValidateGatherScale(scale);
  LBase := PByte(base_addr);

  for LIndex := 0 to 3 do
  begin
    LOffset := PtrInt(vindex.m128i_i32[LIndex]) * LScale;
    Result.m256i_i64[LIndex] := PInt64(LBase + LOffset)^;
  end;
end;

function avx2_gather_ps(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
var
  LBase: PByte;
  LScale: PtrInt;
  LOffset: PtrInt;
  LIndex: Integer;
begin
  if base_addr = nil then
    raise ENullReferenceError.Create('base_addr');

  LScale := ValidateGatherScale(scale);
  LBase := PByte(base_addr);

  for LIndex := 0 to 7 do
  begin
    LOffset := PtrInt(vindex.m256i_i32[LIndex]) * LScale;
    Result.m256_f32[LIndex] := PSingle(LBase + LOffset)^;
  end;
end;

function avx2_gather_pd(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;
var
  LBase: PByte;
  LScale: PtrInt;
  LOffset: PtrInt;
  LIndex: Integer;
begin
  if base_addr = nil then
    raise ENullReferenceError.Create('base_addr');

  LScale := ValidateGatherScale(scale);
  LBase := PByte(base_addr);

  for LIndex := 0 to 3 do
  begin
    LOffset := PtrInt(vindex.m128i_i32[LIndex]) * LScale;
    Result.m256_f64[LIndex] := PDouble(LBase + LOffset)^;
  end;
end;

function avx2_packs_epi32(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
      Result.m256i_i16[LDstOffset + LInner] := SaturateI32ToI16(a.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      Result.m256i_i16[LDstOffset + 4 + LInner] := SaturateI32ToI16(b.m256i_i32[LSrcOffset + LInner]);
  end;
end;

function avx2_packs_epi16(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
      Result.m256i_i8[LDstOffset + LInner] := SaturateI16ToI8(a.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      Result.m256i_i8[LDstOffset + 8 + LInner] := SaturateI16ToI8(b.m256i_i16[LSrcOffset + LInner]);
  end;
end;

function avx2_packus_epi32(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
      Result.m256i_u16[LDstOffset + LInner] := SaturateI32ToU16(a.m256i_i32[LSrcOffset + LInner]);
    for LInner := 0 to 3 do
      Result.m256i_u16[LDstOffset + 4 + LInner] := SaturateI32ToU16(b.m256i_i32[LSrcOffset + LInner]);
  end;
end;

function avx2_packus_epi16(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
      Result.m256i_u8[LDstOffset + LInner] := SaturateI16ToU8(a.m256i_i16[LSrcOffset + LInner]);
    for LInner := 0 to 7 do
      Result.m256i_u8[LDstOffset + 8 + LInner] := SaturateI16ToU8(b.m256i_i16[LSrcOffset + LInner]);
  end;
end;

function avx2_unpackhi_epi32(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := (LLane * 4) + 2;
    LDstOffset := LLane * 4;

    Result.m256i_i32[LDstOffset + 0] := a.m256i_i32[LSrcOffset + 0];
    Result.m256i_i32[LDstOffset + 1] := b.m256i_i32[LSrcOffset + 0];
    Result.m256i_i32[LDstOffset + 2] := a.m256i_i32[LSrcOffset + 1];
    Result.m256i_i32[LDstOffset + 3] := b.m256i_i32[LSrcOffset + 1];
  end;
end;

function avx2_unpackhi_epi16(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := (LLane * 8) + 4;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
    begin
      Result.m256i_i16[LDstOffset + (LInner * 2)] := a.m256i_i16[LSrcOffset + LInner];
      Result.m256i_i16[LDstOffset + (LInner * 2) + 1] := b.m256i_i16[LSrcOffset + LInner];
    end;
  end;
end;

function avx2_unpackhi_epi8(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := (LLane * 16) + 8;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
    begin
      Result.m256i_i8[LDstOffset + (LInner * 2)] := a.m256i_i8[LSrcOffset + LInner];
      Result.m256i_i8[LDstOffset + (LInner * 2) + 1] := b.m256i_i8[LSrcOffset + LInner];
    end;
  end;
end;

function avx2_unpacklo_epi32(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 4;
    LDstOffset := LLane * 4;

    Result.m256i_i32[LDstOffset + 0] := a.m256i_i32[LSrcOffset + 0];
    Result.m256i_i32[LDstOffset + 1] := b.m256i_i32[LSrcOffset + 0];
    Result.m256i_i32[LDstOffset + 2] := a.m256i_i32[LSrcOffset + 1];
    Result.m256i_i32[LDstOffset + 3] := b.m256i_i32[LSrcOffset + 1];
  end;
end;

function avx2_unpacklo_epi16(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 8;
    LDstOffset := LLane * 8;

    for LInner := 0 to 3 do
    begin
      Result.m256i_i16[LDstOffset + (LInner * 2)] := a.m256i_i16[LSrcOffset + LInner];
      Result.m256i_i16[LDstOffset + (LInner * 2) + 1] := b.m256i_i16[LSrcOffset + LInner];
    end;
  end;
end;

function avx2_unpacklo_epi8(const a, b: TM256): TM256;
var
  LLane: Integer;
  LSrcOffset: Integer;
  LDstOffset: Integer;
  LInner: Integer;
begin
  for LLane := 0 to 1 do
  begin
    LSrcOffset := LLane * 16;
    LDstOffset := LLane * 16;

    for LInner := 0 to 7 do
    begin
      Result.m256i_i8[LDstOffset + (LInner * 2)] := a.m256i_i8[LSrcOffset + LInner];
      Result.m256i_i8[LDstOffset + (LInner * 2) + 1] := b.m256i_i8[LSrcOffset + LInner];
    end;
  end;
end;

function avx2_permute4x64_epi64(const a: TM256; imm8: Byte): TM256;
var
  LIndex: Integer;
  LSource: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    LSource := (imm8 shr (LIndex * 2)) and $3;
    Result.m256i_i64[LIndex] := a.m256i_i64[LSource];
  end;
end;

function avx2_permute4x64_pd(const a: TM256; imm8: Byte): TM256;
var
  LIndex: Integer;
  LSource: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    LSource := (imm8 shr (LIndex * 2)) and $3;
    Result.m256_f64[LIndex] := a.m256_f64[LSource];
  end;
end;

function avx2_permutevar8x32_epi32(const a, idx: TM256): TM256;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    Result.m256i_i32[LIndex] := a.m256i_i32[idx.m256i_u32[LIndex] and 7];
end;

function avx2_permutevar8x32_ps(const a: TM256; const idx: TM256): TM256;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
    Result.m256_f32[LIndex] := a.m256_f32[idx.m256i_u32[LIndex] and 7];
end;

end.


