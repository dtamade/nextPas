{
  nextpas.core.simd.intrinsics.sse2.fastpath.inc

  Fast-path SIMD FP arithmetic with IEEE 754 special value handling.

  This file provides optimized implementations of SIMD FP arithmetic
  that use real SIMD instructions while correctly handling IEEE 754
  special values (NaN, Inf, -0.0).

  Strategy:
    1. Execute SIMD instruction (fast path)
    2. Check for special values (NaN, Inf)
    3. If special values found, use scalar fallback (slow path)

  Performance:
    - Fast path: ~1 cycle (SIMD instruction)
    - Slow path: ~4-8 cycles (scalar fallback)
    - Typical case: 99%+ fast path, ~1 cycle average
}

{
  Helper: Check if a packed single value contains NaN or Inf.
  Returns True if any lane has NaN or Inf.
}
function HasSpecialValues_ps(constref a: TM128): Boolean; inline;
const
  EXPONENT_MASK = DWord($7F800000);
var
  i: Integer;
begin
  for i := 0 to 3 do
    if (a.m128i_u32[i] and EXPONENT_MASK) = EXPONENT_MASK then
      Exit(True);
  Result := False;
end;

{
  Helper: Check if a packed double value contains NaN or Inf.
  Returns True if any lane has NaN or Inf.
}
function HasSpecialValues_pd(constref a: TM128): Boolean; inline;
const
  EXPONENT_MASK = QWord($7FF0000000000000);
var
  i: Integer;
begin
  for i := 0 to 1 do
    if (a.m128i_u64[i] and EXPONENT_MASK) = EXPONENT_MASK then
      Exit(True);
  Result := False;
end;

{
  Fast-path simd_add_ps with IEEE 754 special value handling.
}
function simd_add_ps_fast(constref a, b: TM128): TM128;
begin
  Result := simd_add_ps(a, b);
  if HasSpecialValues_ps(Result) then
    Result := BuildPackedSingleSpecialArithmetic(a, b, bakAdd);
end;

{
  Fast-path simd_sub_ps with IEEE 754 special value handling.
}
function simd_sub_ps_fast(constref a, b: TM128): TM128;
begin
  Result := simd_sub_ps(a, b);
  if HasSpecialValues_ps(Result) then
    Result := BuildPackedSingleSpecialArithmetic(a, b, bakSub);
end;

{
  Fast-path simd_mul_ps with IEEE 754 special value handling.
}
function simd_mul_ps_fast(constref a, b: TM128): TM128;
begin
  Result := simd_mul_ps(a, b);
  if HasSpecialValues_ps(Result) then
    Result := BuildPackedSingleSpecialArithmetic(a, b, bakMul);
end;

{
  Fast-path simd_div_ps with IEEE 754 special value handling.
}
function simd_div_ps_fast(constref a, b: TM128): TM128;
begin
  Result := simd_div_ps(a, b);
  if HasSpecialValues_ps(Result) then
    Result := BuildPackedSingleDiv(a, b);
end;

{
  Fast-path simd_add_pd with IEEE 754 special value handling.
}
function simd_add_pd_fast(constref a, b: TM128): TM128;
begin
  Result := simd_add_pd(a, b);
  if HasSpecialValues_pd(Result) then
    Result := BuildPackedDoubleSpecialArithmetic(a, b, bakAdd);
end;

{
  Fast-path simd_sub_pd with IEEE 754 special value handling.
}
function simd_sub_pd_fast(constref a, b: TM128): TM128;
begin
  Result := simd_sub_pd(a, b);
  if HasSpecialValues_pd(Result) then
    Result := BuildPackedDoubleSpecialArithmetic(a, b, bakSub);
end;

{
  Fast-path simd_mul_pd with IEEE 754 special value handling.
}
function simd_mul_pd_fast(constref a, b: TM128): TM128;
begin
  Result := simd_mul_pd(a, b);
  if HasSpecialValues_pd(Result) then
    Result := BuildPackedDoubleSpecialArithmetic(a, b, bakMul);
end;

{
  Fast-path simd_div_pd with IEEE 754 special value handling.
}
function simd_div_pd_fast(constref a, b: TM128): TM128;
begin
  Result := simd_div_pd(a, b);
  if HasSpecialValues_pd(Result) then
    Result := BuildPackedDoubleDiv(a, b);
end;
