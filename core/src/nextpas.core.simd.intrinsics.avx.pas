unit nextpas.core.simd.intrinsics.avx;
// Disposition: STABLE — low-level intrinsics, used by dispatch backends

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.avx ===
  Placeholder AVX intrinsics surface for isolated experimental bring-up.
  AVX was introduced by Intel in 2011 and expands SIMD vectors to 256 bits.
  Highlights:
  - 256-bit vector registers (ymm0-ymm15)
  - three-operand instruction forms
  - wider floating-point operations and load/store helpers
  - vector permutation helpers
  Compatibility: Intel Sandy Bridge (2011) and newer processors.
}

interface

uses
  nextpas.core.simd.intrinsics.base;

{
  Experimental status (2026-02-17):
  - This unit still contains placeholder implementations for several AVX APIs.
  - It should not be used as a default public entry path.
  - There is no current in-repo consumer beyond isolated smoke / opt-in bring-up.
  - This raw leaf is only qualified on x86/x86_64 targets.
}

// === AVX 256-bit 浮点运算 ===
// Load/Store
function avx_load_ps256(const Ptr: Pointer): TM256;
function avx_loadu_ps256(const Ptr: Pointer): TM256;
function avx_load_pd256(const Ptr: Pointer): TM256;
function avx_loadu_pd256(const Ptr: Pointer): TM256;
procedure avx_store_ps256(var Dest; const Src: TM256);
procedure avx_storeu_ps256(var Dest; const Src: TM256);
procedure avx_store_pd256(var Dest; const Src: TM256);
procedure avx_storeu_pd256(var Dest; const Src: TM256);

// Set/Zero
function avx_setzero_ps256: TM256;
function avx_setzero_pd256: TM256;
function avx_set1_ps256(Value: Single): TM256;
function avx_set1_pd256(Value: Double): TM256;

// Arithmetic
function avx_add_ps256(const a, b: TM256): TM256;
function avx_add_pd256(const a, b: TM256): TM256;
function avx_sub_ps256(const a, b: TM256): TM256;
function avx_sub_pd256(const a, b: TM256): TM256;
function avx_mul_ps256(const a, b: TM256): TM256;
function avx_mul_pd256(const a, b: TM256): TM256;
function avx_div_ps256(const a, b: TM256): TM256;
function avx_div_pd256(const a, b: TM256): TM256;

// Math Functions
function avx_sqrt_ps256(const a: TM256): TM256;
function avx_sqrt_pd256(const a: TM256): TM256;
function avx_rsqrt_ps256(const a: TM256): TM256;
function avx_rcp_ps256(const a: TM256): TM256;

// Min/Max
function avx_min_ps256(const a, b: TM256): TM256;
function avx_min_pd256(const a, b: TM256): TM256;
function avx_max_ps256(const a, b: TM256): TM256;
function avx_max_pd256(const a, b: TM256): TM256;

// Logical
function avx_and_ps256(const a, b: TM256): TM256;
function avx_and_pd256(const a, b: TM256): TM256;
function avx_andnot_ps256(const a, b: TM256): TM256;
function avx_andnot_pd256(const a, b: TM256): TM256;
function avx_or_ps256(const a, b: TM256): TM256;
function avx_or_pd256(const a, b: TM256): TM256;
function avx_xor_ps256(const a, b: TM256): TM256;
function avx_xor_pd256(const a, b: TM256): TM256;

// Compare
function avx_cmp_ps256(const a, b: TM256; imm8: Byte): TM256;
function avx_cmp_pd256(const a, b: TM256; imm8: Byte): TM256;

// Blend
function avx_blend_ps256(const a, b: TM256; imm8: Byte): TM256;
function avx_blend_pd256(const a, b: TM256; imm8: Byte): TM256;
function avx_blendv_ps256(const a, b, mask: TM256): TM256;
function avx_blendv_pd256(const a, b, mask: TM256): TM256;

// Shuffle/Permute
function avx_shuffle_ps256(const a, b: TM256; imm8: Byte): TM256;
function avx_shuffle_pd256(const a, b: TM256; imm8: Byte): TM256;
function avx_permute_ps256(const a: TM256; imm8: Byte): TM256;
function avx_permute_pd256(const a: TM256; imm8: Byte): TM256;
function avx_permute2f128_ps256(const a, b: TM256; imm8: Byte): TM256;
function avx_permute2f128_pd256(const a, b: TM256; imm8: Byte): TM256;

// Unpack
function avx_unpackhi_ps256(const a, b: TM256): TM256;
function avx_unpackhi_pd256(const a, b: TM256): TM256;
function avx_unpacklo_ps256(const a, b: TM256): TM256;
function avx_unpacklo_pd256(const a, b: TM256): TM256;

// Convert
function avx_cvt_ps2pd256(const a: TM128): TM256;
function avx_cvt_pd2ps256(const a: TM256): TM128;

// Extract/Insert 128-bit
function avx_extractf128_ps256(const a: TM256; imm8: Byte): TM128;
function avx_extractf128_pd256(const a: TM256; imm8: Byte): TM128;
function avx_insertf128_ps256(const a: TM256; const b: TM128; imm8: Byte): TM256;
function avx_insertf128_pd256(const a: TM256; const b: TM128; imm8: Byte): TM256;

// Move
function avx_movemask_ps256(const a: TM256): Integer;
function avx_movemask_pd256(const a: TM256): Integer;

// Test
function avx_testz_ps256(const a, b: TM256): Boolean;
function avx_testz_pd256(const a, b: TM256): Boolean;
function avx_testc_ps256(const a, b: TM256): Boolean;
function avx_testc_pd256(const a, b: TM256): Boolean;
function avx_testnzc_ps256(const a, b: TM256): Boolean;
function avx_testnzc_pd256(const a, b: TM256): Boolean;

// Cache Control
procedure avx_zeroupper;
procedure avx_zeroall;

implementation

uses
  nextpas.core.simd.mathutil;

procedure EnsureExperimentalIntrinsicsEnabled; inline;
begin
  {$IFNDEF NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS}
  
  RunError(217);  {$ENDIF}
end;

procedure EnsureExperimentalAvxTargetSupported; inline;
begin
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUX86}
  
  RunError(217);  {$ENDIF}
  {$ENDIF}
end;

function AVXLoadTM256(const Ptr: Pointer): TM256; inline;
begin
  Result := PTM256(Ptr)^;
end;

procedure AVXStoreTM256(var aDest; const aSrc: TM256); inline;
begin
  PTM256(@aDest)^ := aSrc;
end;

procedure AVXSetTM256F32(var aResult: TM256; const aValue: Single); inline;
var
  i: Integer;
begin
  for i := 0 to 7 do
    aResult.m256_f32[i] := aValue;
end;

procedure AVXSetTM256F64(var aResult: TM256; const aValue: Double); inline;
var
  i: Integer;
begin
  for i := 0 to 3 do
    aResult.m256_f64[i] := aValue;
end;

function AVXCopyTM256(const aValue: TM256): TM256; inline;
begin
  Result := aValue;
end;

function AVXExtractF128TM128(const aValue: TM256; imm8: Byte): TM128; inline;
begin
  if (imm8 and 1) = 0 then
    Result := aValue.m256_m128[0]
  else
    Result := aValue.m256_m128[1];
end;

function AVXInsertF128TM256(const aValue: TM256; const aInsert: TM128; imm8: Byte): TM256; inline;
begin
  Result := aValue;
  if (imm8 and 1) = 0 then
    Result.m256_m128[0] := aInsert
  else
    Result.m256_m128[1] := aInsert;
end;

function AVXReturnTrue: Boolean; inline;
begin
  Result := True;
end;

function AVXReturnFalse: Boolean; inline;
begin
  Result := False;
end;

// === 基础函数实现 (Pascal 版本) ===
function avx_load_ps256(const Ptr: Pointer): TM256;
begin
  Result := AVXLoadTM256(Ptr);
end;

function avx_loadu_ps256(const Ptr: Pointer): TM256;
begin
  Result := AVXLoadTM256(Ptr);
end;

function avx_load_pd256(const Ptr: Pointer): TM256;
begin
  Result := AVXLoadTM256(Ptr);
end;

function avx_loadu_pd256(const Ptr: Pointer): TM256;
begin
  Result := AVXLoadTM256(Ptr);
end;

procedure avx_store_ps256(var Dest; const Src: TM256);
begin
  AVXStoreTM256(Dest, Src);
end;

procedure avx_storeu_ps256(var Dest; const Src: TM256);
begin
  AVXStoreTM256(Dest, Src);
end;

procedure avx_store_pd256(var Dest; const Src: TM256);
begin
  AVXStoreTM256(Dest, Src);
end;

procedure avx_storeu_pd256(var Dest; const Src: TM256);
begin
  AVXStoreTM256(Dest, Src);
end;

function avx_setzero_ps256: TM256;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function avx_setzero_pd256: TM256;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function avx_set1_ps256(Value: Single): TM256;
begin
  AVXSetTM256F32(Result, Value);
end;

function avx_set1_pd256(Value: Double): TM256;
begin
  AVXSetTM256F64(Result, Value);
end;

function avx_add_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] + b.m256_f32[i];
end;

function avx_add_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] + b.m256_f64[i];
end;

function avx_sub_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] - b.m256_f32[i];
end;

function avx_sub_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] - b.m256_f64[i];
end;

function avx_mul_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] * b.m256_f32[i];
end;

function avx_mul_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] * b.m256_f64[i];
end;

function avx_div_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := a.m256_f32[i] / b.m256_f32[i];
end;

function avx_div_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m256_f64[i] / b.m256_f64[i];
end;

function avx_sqrt_ps256(const a: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256_f32[i] := Sqrt(a.m256_f32[i]);
end;

function avx_sqrt_pd256(const a: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := Sqrt(a.m256_f64[i]);
end;

function avx_rsqrt_ps256(const a: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256_f32[i] <> 0 then
      Result.m256_f32[i] := 1.0 / Sqrt(a.m256_f32[i])
    else
      Result.m256_f32[i] := 0;
end;

function avx_rcp_ps256(const a: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256_f32[i] <> 0 then
      Result.m256_f32[i] := 1.0 / a.m256_f32[i]
    else
      Result.m256_f32[i] := 0;
end;

function avx_min_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256_f32[i] < b.m256_f32[i] then
      Result.m256_f32[i] := a.m256_f32[i]
    else
      Result.m256_f32[i] := b.m256_f32[i];
end;

function avx_min_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m256_f64[i] < b.m256_f64[i] then
      Result.m256_f64[i] := a.m256_f64[i]
    else
      Result.m256_f64[i] := b.m256_f64[i];
end;

function avx_max_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m256_f32[i] > b.m256_f32[i] then
      Result.m256_f32[i] := a.m256_f32[i]
    else
      Result.m256_f32[i] := b.m256_f32[i];
end;

function avx_max_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m256_f64[i] > b.m256_f64[i] then
      Result.m256_f64[i] := a.m256_f64[i]
    else
      Result.m256_f64[i] := b.m256_f64[i];
end;

function avx_and_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] and b.m256i_u32[i];
end;

function avx_and_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256i_u64[i] := a.m256i_u64[i] and b.m256i_u64[i];
end;

function avx_andnot_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := (not a.m256i_u32[i]) and b.m256i_u32[i];
end;

function avx_andnot_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256i_u64[i] := (not a.m256i_u64[i]) and b.m256i_u64[i];
end;

function avx_or_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] or b.m256i_u32[i];
end;

function avx_or_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256i_u64[i] := a.m256i_u64[i] or b.m256i_u64[i];
end;

function avx_xor_ps256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m256i_u32[i] := a.m256i_u32[i] xor b.m256i_u32[i];
end;

function avx_xor_pd256(const a, b: TM256): TM256;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m256i_u64[i] := a.m256i_u64[i] xor b.m256i_u64[i];
end;

// 其他复杂函数的占位符实现
function avx_cmp_ps256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_cmp_pd256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_blend_ps256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_blend_pd256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_blendv_ps256(const a, b, mask: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_blendv_pd256(const a, b, mask: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_shuffle_ps256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_shuffle_pd256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_permute_ps256(const a: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_permute_pd256(const a: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_permute2f128_ps256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_permute2f128_pd256(const a, b: TM256; imm8: Byte): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_unpackhi_ps256(const a, b: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_unpackhi_pd256(const a, b: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_unpacklo_ps256(const a, b: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_unpacklo_pd256(const a, b: TM256): TM256;
begin
  Result := AVXCopyTM256(a);
end;

function avx_cvt_ps2pd256(const a: TM128): TM256;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m256_f64[i] := a.m128_f32[i];
end;

function avx_cvt_pd2ps256(const a: TM256): TM128;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := a.m256_f64[i];
end;

function avx_extractf128_ps256(const a: TM256; imm8: Byte): TM128;
begin
  Result := AVXExtractF128TM128(a, imm8);
end;

function avx_extractf128_pd256(const a: TM256; imm8: Byte): TM128;
begin
  Result := AVXExtractF128TM128(a, imm8);
end;

function avx_insertf128_ps256(const a: TM256; const b: TM128; imm8: Byte): TM256;
begin
  Result := AVXInsertF128TM256(a, b, imm8);
end;

function avx_insertf128_pd256(const a: TM256; const b: TM128; imm8: Byte): TM256;
begin
  Result := AVXInsertF128TM256(a, b, imm8);
end;

function avx_movemask_ps256(const a: TM256): Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if (a.m256i_u32[i] and $80000000) <> 0 then
      Result := Result or (1 shl i);
end;

function avx_movemask_pd256(const a: TM256): Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if (a.m256i_u64[i] and $8000000000000000) <> 0 then
      Result := Result or (1 shl i);
end;

function avx_testz_ps256(const a, b: TM256): Boolean; begin Result := AVXReturnTrue; end;
function avx_testz_pd256(const a, b: TM256): Boolean; begin Result := AVXReturnTrue; end;
function avx_testc_ps256(const a, b: TM256): Boolean; begin Result := AVXReturnTrue; end;
function avx_testc_pd256(const a, b: TM256): Boolean; begin Result := AVXReturnTrue; end;
function avx_testnzc_ps256(const a, b: TM256): Boolean; begin Result := AVXReturnFalse; end;
function avx_testnzc_pd256(const a, b: TM256): Boolean; begin Result := AVXReturnFalse; end;

procedure avx_zeroupper; begin end;
procedure avx_zeroall; begin end;

initialization
  EnsureExperimentalIntrinsicsEnabled;
  EnsureExperimentalAvxTargetSupported;

end.


