unit nextpas.core.simd.intrinsics.sse41;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends

{$mode objfpc}
{$I nextpas.core.settings.inc}

{
  === nextpas.core.simd.intrinsics.sse41 ===
  Placeholder SSE4.1 intrinsics surface for isolated experimental bring-up.
  SSE4.1 expands integer min/max, dot-product, blend, round, and conversion helpers.
  Highlights:
  - extended integer min/max operations
  - dot-product instructions
  - blend operations
  - round instructions
  - insert/extract enhancements
  - zero-extension loads and ptest-style helpers
  Compatibility: most modern x86/x64 processors.
}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status (2026-05-17):
  - This unit remains on the experimental x86 intrinsics lane.
  - It must not be treated as a default stable raw leaf.
  - Non-x86 branches remain compile scaffolding; runtime fail-close is intentional.
}

// === SSE4.1 扩展 Min/Max 操作 ===
function sse41_max_epi8(const a, b: TM128): TM128;
function sse41_max_epi32(const a, b: TM128): TM128;
function sse41_max_epu16(const a, b: TM128): TM128;
function sse41_max_epu32(const a, b: TM128): TM128;
function sse41_min_epi8(const a, b: TM128): TM128;
function sse41_min_epi32(const a, b: TM128): TM128;
function sse41_min_epu16(const a, b: TM128): TM128;
function sse41_min_epu32(const a, b: TM128): TM128;

// === SSE4.1 点积指令 ===
function sse41_dp_ps(const a, b: TM128; imm8: Byte): TM128;
function sse41_dp_pd(const a, b: TM128; imm8: Byte): TM128;

// === SSE4.1 混合操作 ===
function sse41_blend_ps(const a, b: TM128; imm8: Byte): TM128;
function sse41_blend_pd(const a, b: TM128; imm8: Byte): TM128;
function sse41_blendv_ps(const a, b, mask: TM128): TM128;
function sse41_blendv_pd(const a, b, mask: TM128): TM128;
function sse41_blendv_epi8(const a, b, mask: TM128): TM128;

// === SSE4.1 舍入指令 ===
function sse41_round_ps(const a: TM128; rounding: Byte): TM128;
function sse41_round_pd(const a: TM128; rounding: Byte): TM128;
function sse41_round_ss(const a, b: TM128; rounding: Byte): TM128;
function sse41_round_sd(const a, b: TM128; rounding: Byte): TM128;

// === SSE4.1 插入/提取指令增强 ===
function sse41_insert_ps(const a, b: TM128; imm8: Byte): TM128;
function sse41_extract_ps(const a: TM128; imm8: Byte): Cardinal;
function sse41_insert_epi8(const a: TM128; Value: Integer; imm8: Byte): TM128;
function sse41_insert_epi32(const a: TM128; Value: Integer; imm8: Byte): TM128;
function sse41_insert_epi64(const a: TM128; Value: Int64; imm8: Byte): TM128;
function sse41_extract_epi8(const a: TM128; imm8: Byte): Integer;
function sse41_extract_epi32(const a: TM128; imm8: Byte): Integer;
function sse41_extract_epi64(const a: TM128; imm8: Byte): Int64;

// === SSE4.1 零扩展加载 ===
function sse41_loadl_epi64(const Ptr: Pointer): TM128;

// === SSE4.1 转换指令 ===
function sse41_cvtepi8_epi16(const a: TM128): TM128;
function sse41_cvtepi8_epi32(const a: TM128): TM128;
function sse41_cvtepi8_epi64(const a: TM128): TM128;
function sse41_cvtepi16_epi32(const a: TM128): TM128;
function sse41_cvtepi16_epi64(const a: TM128): TM128;
function sse41_cvtepi32_epi64(const a: TM128): TM128;
function sse41_cvtepu8_epi16(const a: TM128): TM128;   // 8位到16位零扩展
function sse41_cvtepu8_epi32(const a: TM128): TM128;   // 8位到32位零扩展
function sse41_cvtepu8_epi64(const a: TM128): TM128;   // 8位到64位零扩展
function sse41_cvtepu16_epi32(const a: TM128): TM128;  // 16位到32位零扩展
function sse41_cvtepu16_epi64(const a: TM128): TM128;  // 16位到64位零扩展
function sse41_cvtepu32_epi64(const a: TM128): TM128;  // 32位到64位零扩展

// === SSE4.1 测试指令 ===
function sse41_test_all_zeros(const a, mask: TM128): Boolean;      // 测试全零
function sse41_test_all_ones(const a: TM128): Boolean;             // 测试全一
function sse41_test_mix_ones_zeros(const a, mask: TM128): Boolean; // 测试混合

// === SSE4.1 其他指令 ===
function sse41_mullo_epi32(const a, b: TM128): TM128;
function sse41_mul_epi32(const a, b: TM128): TM128;
function sse41_packus_epi32(const a, b: TM128): TM128;

implementation

uses
  SysUtils,
  Math;  // RTL Math 单元 (Round, Int)

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  raise ENotSupportedException.Create(
    'nextpas.core.simd.intrinsics.sse41 is experimental placeholder semantics. ' +
    'Define NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS to opt in.'
  );
  {$ENDIF}
end;

procedure EnsureExperimentalSse41TargetSupported; inline;
begin
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUX86}
  raise ENotSupportedException.Create(
    'nextpas.core.simd.intrinsics.sse41 experimental runtime is only qualified on x86/x86_64. ' +
    'The non-x86 branch remains compile scaffolding, not executable semantics.'
  );
  {$ENDIF}
  {$ENDIF}
end;

function SSE41RoundScalar(const aValue: Extended; aRounding: Byte): Extended; inline;
begin
  case aRounding and 7 of
    0: Result := Round(aValue);
    1: Result := Int(aValue - 0.5);
    2: Result := Int(aValue + 0.5);
    3: Result := Int(aValue);
    else Result := aValue;
  end;
end;

function SSE41ExtendSignedI8(const aValue: TM128; aTargetWidth: Integer): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  case aTargetWidth of
    16:
      for i := 0 to 7 do
        Result.m128i_i16[i] := aValue.m128i_i8[i];
    32:
      for i := 0 to 3 do
        Result.m128i_i32[i] := aValue.m128i_i8[i];
    64:
      for i := 0 to 1 do
        Result.m128i_i64[i] := aValue.m128i_i8[i];
  end;
end;

function SSE41ExtendSignedI16(const aValue: TM128; aTargetWidth: Integer): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  case aTargetWidth of
    32:
      for i := 0 to 3 do
        Result.m128i_i32[i] := aValue.m128i_i16[i];
    64:
      for i := 0 to 1 do
        Result.m128i_i64[i] := aValue.m128i_i16[i];
  end;
end;

function SSE41ExtendSignedI32(const aValue: TM128): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for i := 0 to 1 do
    Result.m128i_i64[i] := aValue.m128i_i32[i];
end;

function SSE41ExtendUnsignedU8(const aValue: TM128; aTargetWidth: Integer): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  case aTargetWidth of
    16:
      for i := 0 to 7 do
        Result.m128i_u16[i] := aValue.m128i_u8[i];
    32:
      for i := 0 to 3 do
        Result.m128i_u32[i] := aValue.m128i_u8[i];
    64:
      for i := 0 to 1 do
        Result.m128i_u64[i] := aValue.m128i_u8[i];
  end;
end;

function SSE41ExtendUnsignedU16(const aValue: TM128; aTargetWidth: Integer): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  case aTargetWidth of
    32:
      for i := 0 to 3 do
        Result.m128i_u32[i] := aValue.m128i_u16[i];
    64:
      for i := 0 to 1 do
        Result.m128i_u64[i] := aValue.m128i_u16[i];
  end;
end;

function SSE41ExtendUnsignedU32(const aValue: TM128): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for i := 0 to 1 do
    Result.m128i_u64[i] := aValue.m128i_u32[i];
end;

function SSE41MinMaxI8x16(const a, b: TM128; aUseMax: Boolean): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if aUseMax then
    for i := 0 to 15 do
      if a.m128i_i8[i] > b.m128i_i8[i] then
        Result.m128i_i8[i] := a.m128i_i8[i]
      else
        Result.m128i_i8[i] := b.m128i_i8[i]
  else
    for i := 0 to 15 do
      if a.m128i_i8[i] < b.m128i_i8[i] then
        Result.m128i_i8[i] := a.m128i_i8[i]
      else
        Result.m128i_i8[i] := b.m128i_i8[i];
end;

function SSE41MinMaxI32x4(const a, b: TM128; aUseMax: Boolean): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if aUseMax then
    for i := 0 to 3 do
      if a.m128i_i32[i] > b.m128i_i32[i] then
        Result.m128i_i32[i] := a.m128i_i32[i]
      else
        Result.m128i_i32[i] := b.m128i_i32[i]
  else
    for i := 0 to 3 do
      if a.m128i_i32[i] < b.m128i_i32[i] then
        Result.m128i_i32[i] := a.m128i_i32[i]
      else
        Result.m128i_i32[i] := b.m128i_i32[i];
end;

function SSE41MinMaxU16x8(const a, b: TM128; aUseMax: Boolean): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if aUseMax then
    for i := 0 to 7 do
      if a.m128i_u16[i] > b.m128i_u16[i] then
        Result.m128i_u16[i] := a.m128i_u16[i]
      else
        Result.m128i_u16[i] := b.m128i_u16[i]
  else
    for i := 0 to 7 do
      if a.m128i_u16[i] < b.m128i_u16[i] then
        Result.m128i_u16[i] := a.m128i_u16[i]
      else
        Result.m128i_u16[i] := b.m128i_u16[i];
end;

function SSE41MinMaxU32x4(const a, b: TM128; aUseMax: Boolean): TM128; inline;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if aUseMax then
    for i := 0 to 3 do
      if a.m128i_u32[i] > b.m128i_u32[i] then
        Result.m128i_u32[i] := a.m128i_u32[i]
      else
        Result.m128i_u32[i] := b.m128i_u32[i]
  else
    for i := 0 to 3 do
      if a.m128i_u32[i] < b.m128i_u32[i] then
        Result.m128i_u32[i] := a.m128i_u32[i]
      else
        Result.m128i_u32[i] := b.m128i_u32[i];
end;

// === Min/Max 操作实现 ===
function sse41_max_epi8(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxI8x16(a, b, True);
end;

function sse41_max_epi32(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxI32x4(a, b, True);
end;

function sse41_max_epu16(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxU16x8(a, b, True);
end;

function sse41_max_epu32(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxU32x4(a, b, True);
end;

function sse41_min_epi8(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxI8x16(a, b, False);
end;

function sse41_min_epi32(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxI32x4(a, b, False);
end;

function sse41_min_epu16(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxU16x8(a, b, False);
end;

function sse41_min_epu32(const a, b: TM128): TM128;
begin
  Result := SSE41MinMaxU32x4(a, b, False);
end;

// === 点积指令实现 ===
function sse41_dp_ps(const a, b: TM128; imm8: Byte): TM128;
var
  i: Integer;
  sum: Single;
begin
  // 简化的点积实现
  sum := 0;
  for i := 0 to 3 do
    if (imm8 and (1 shl (i + 4))) <> 0 then
      sum := sum + a.m128_f32[i] * b.m128_f32[i];
  
  FillChar(Result, SizeOf(Result), 0);
  for i := 0 to 3 do
    if (imm8 and (1 shl i)) <> 0 then
      Result.m128_f32[i] := sum;
end;

function sse41_dp_pd(const a, b: TM128; imm8: Byte): TM128;
var
  i: Integer;
  sum: Double;
begin
  // 简化的双精度点积实现
  sum := 0;
  for i := 0 to 1 do
    if (imm8 and (1 shl (i + 4))) <> 0 then
      sum := sum + a.m128d_f64[i] * b.m128d_f64[i];
  
  FillChar(Result, SizeOf(Result), 0);
  for i := 0 to 1 do
    if (imm8 and (1 shl i)) <> 0 then
      Result.m128d_f64[i] := sum;
end;

function SSE41BlendF32x4(const a, b: TM128; imm8: Byte): TM128; inline;
var
  i: Integer;
begin
  Result := a;
  for i := 0 to 3 do
    if (imm8 and (1 shl i)) <> 0 then
      Result.m128_f32[i] := b.m128_f32[i];
end;

function SSE41BlendF64x2(const a, b: TM128; imm8: Byte): TM128; inline;
var
  i: Integer;
begin
  Result := a;
  for i := 0 to 1 do
    if (imm8 and (1 shl i)) <> 0 then
      Result.m128d_f64[i] := b.m128d_f64[i];
end;

function SSE41BlendVF32x4(const a, b, mask: TM128): TM128; inline;
var
  i: Integer;
begin
  Result := a;
  for i := 0 to 3 do
    if (mask.m128i_u32[i] and $80000000) <> 0 then
      Result.m128_f32[i] := b.m128_f32[i];
end;

function SSE41BlendVF64x2(const a, b, mask: TM128): TM128; inline;
var
  i: Integer;
begin
  Result := a;
  for i := 0 to 1 do
    if (mask.m128i_u64[i] and $8000000000000000) <> 0 then
      Result.m128d_f64[i] := b.m128d_f64[i];
end;

function SSE41BlendVE8x16(const a, b, mask: TM128): TM128; inline;
var
  i: Integer;
begin
  Result := a;
  for i := 0 to 15 do
    if (mask.m128i_u8[i] and $80) <> 0 then
      Result.m128i_u8[i] := b.m128i_u8[i];
end;

// === 混合操作实现 ===
function sse41_blend_ps(const a, b: TM128; imm8: Byte): TM128;
begin
  Result := SSE41BlendF32x4(a, b, imm8);
end;

function sse41_blend_pd(const a, b: TM128; imm8: Byte): TM128;
begin
  Result := SSE41BlendF64x2(a, b, imm8);
end;

function sse41_blendv_ps(const a, b, mask: TM128): TM128;
begin
  Result := SSE41BlendVF32x4(a, b, mask);
end;

function sse41_blendv_pd(const a, b, mask: TM128): TM128;
begin
  Result := SSE41BlendVF64x2(a, b, mask);
end;

function sse41_blendv_epi8(const a, b, mask: TM128): TM128;
begin
  Result := SSE41BlendVE8x16(a, b, mask);
end;

// === 舍入指令实现 ===
function sse41_round_ps(const a: TM128; rounding: Byte): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := SSE41RoundScalar(a.m128_f32[i], rounding);
end;

function sse41_round_pd(const a: TM128; rounding: Byte): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := SSE41RoundScalar(a.m128d_f64[i], rounding);
end;

function sse41_round_ss(const a, b: TM128; rounding: Byte): TM128;
begin
  Result := a;
  Result.m128_f32[0] := SSE41RoundScalar(b.m128_f32[0], rounding);
end;

function sse41_round_sd(const a, b: TM128; rounding: Byte): TM128;
begin
  Result := a;
  Result.m128d_f64[0] := SSE41RoundScalar(b.m128d_f64[0], rounding);
end;

// === Simplified implementations for the remaining helpers ===
function sse41_insert_ps(const a, b: TM128; imm8: Byte): TM128;
begin
  Result := a;
  // 简化实现：按 imm8 选择目标/源 lane
  Result.m128_f32[imm8 and 3] := b.m128_f32[(imm8 shr 6) and 3];
end;

function sse41_extract_ps(const a: TM128; imm8: Byte): Cardinal;
begin
  Result := a.m128i_u32[imm8 and 3];
end;

function sse41_insert_epi8(const a: TM128; Value: Integer; imm8: Byte): TM128;
begin
  Result := a;
  Result.m128i_i8[imm8 and 15] := ShortInt(Value);
end;

function sse41_insert_epi32(const a: TM128; Value: Integer; imm8: Byte): TM128;
begin
  Result := a;
  Result.m128i_i32[imm8 and 3] := Value;
end;

function sse41_insert_epi64(const a: TM128; Value: Int64; imm8: Byte): TM128;
begin
  Result := a;
  Result.m128i_i64[imm8 and 1] := Value;
end;

function sse41_extract_epi8(const a: TM128; imm8: Byte): Integer;
begin
  Result := a.m128i_u8[imm8 and 15];
end;

function sse41_extract_epi32(const a: TM128; imm8: Byte): Integer;
begin
  Result := a.m128i_i32[imm8 and 3];
end;

function sse41_extract_epi64(const a: TM128; imm8: Byte): Int64;
begin
  Result := a.m128i_i64[imm8 and 1];
end;

function sse41_loadl_epi64(const Ptr: Pointer): TM128;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m128i_i64[0] := PInt64(Ptr)^;
end;

// === Simplified conversion helpers ===
function sse41_cvtepi8_epi16(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI8(a, 16);
end;

function sse41_cvtepi8_epi32(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI8(a, 32);
end;

function sse41_cvtepi8_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI8(a, 64);
end;

function sse41_cvtepi16_epi32(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI16(a, 32);
end;

function sse41_cvtepi16_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI16(a, 64);
end;

function sse41_cvtepi32_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendSignedI32(a);
end;

function sse41_cvtepu8_epi16(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU8(a, 16);
end;

function sse41_cvtepu8_epi32(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU8(a, 32);
end;

function sse41_cvtepu8_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU8(a, 64);
end;

function sse41_cvtepu16_epi32(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU16(a, 32);
end;

function sse41_cvtepu16_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU16(a, 64);
end;

function sse41_cvtepu32_epi64(const a: TM128): TM128;
begin
  Result := SSE41ExtendUnsignedU32(a);
end;

// === 测试指令实现 ===
function sse41_test_all_zeros(const a, mask: TM128): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to 3 do
    if (a.m128i_u32[i] and mask.m128i_u32[i]) <> 0 then
    begin
      Result := False;
      Exit;
    end;
end;

function sse41_test_all_ones(const a: TM128): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to 3 do
    if a.m128i_u32[i] <> $FFFFFFFF then
    begin
      Result := False;
      Exit;
    end;
end;

function sse41_test_mix_ones_zeros(const a, mask: TM128): Boolean;
var
  i: Integer;
  has_zero, has_one: Boolean;
begin
  has_zero := False;
  has_one := False;
  
  for i := 0 to 3 do
  begin
    if (a.m128i_u32[i] and mask.m128i_u32[i]) = 0 then
      has_zero := True
    else
      has_one := True;
  end;
  
  Result := has_zero and has_one;
end;

// === 其他指令实现 ===
function sse41_mullo_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_i32[i] := a.m128i_i32[i] * b.m128i_i32[i];
end;

function sse41_mul_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128i_i64[i] := Int64(a.m128i_i32[i * 2]) * Int64(b.m128i_i32[i * 2]);
end;

function sse41_packus_epi32(const a, b: TM128): TM128;
var
  i: Integer;
  temp: LongInt;
begin
  for i := 0 to 3 do
  begin
    temp := a.m128i_i32[i];
    if temp < 0 then
      Result.m128i_u16[i] := 0
    else if temp > 65535 then
      Result.m128i_u16[i] := 65535
    else
      Result.m128i_u16[i] := UInt16(temp);
      
    temp := b.m128i_i32[i];
    if temp < 0 then
      Result.m128i_u16[i + 4] := 0
    else if temp > 65535 then
      Result.m128i_u16[i + 4] := 65535
    else
      Result.m128i_u16[i + 4] := UInt16(temp);
  end;
end;

initialization
  EnsureExperimentalIntrinsicsEnabled;
  EnsureExperimentalSse41TargetSupported;

end.


