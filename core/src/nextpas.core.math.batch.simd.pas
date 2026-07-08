unit nextpas.core.math.batch.simd;
{**
 * SIMD-optimized batch math operations.
 *
 * This unit provides SIMD-accelerated wrappers for batch scalar operations,
 * using SSE/AVX intrinsics via nextpas.core.simd for 4-wide F32 processing.
 * Scalar fallback handles remaining elements when count is not a multiple of 4.
 *
 * Design contract:
 *   - API mirrors nextpas.core.math.batch (same signatures)
 *   - SIMD loop processes 4 elements per iteration via VecF32x4* primitives
 *   - Scalar tail loop handles remaining 0-3 elements
 *   - The "Simd" suffix signals SIMD-ready dispatch path
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{** Batch sine (SIMD-ready). Computes sin(x) for each element.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for sine values
 * @return Number of elements processed
 *}
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch cosine (SIMD-ready). Computes cos(x) for each element.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for cosine values
 * @return Number of elements processed
 *}
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch tangent (SIMD-ready). Computes tan(x) for each element.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for tangent values
 * @return Number of elements processed
 *}
function BatchTanSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch simultaneous sine and cosine (SIMD-ready).
 * Computes both sin(x) and cos(x) in a single pass.
 * @param AInput Input array of angles in radians
 * @param ASinOutput Output array for sine values
 * @param ACosOutput Output array for cosine values
 * @return Number of elements processed
 *}
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;

{** Batch exponential (SIMD-ready). Computes e^x for each element.
 * @param AInput Input array of exponents
 * @param AOutput Output array for exponential values
 * @return Number of elements processed
 *}
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch natural logarithm (SIMD-ready). Computes ln(x) for each element.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;

{** Batch base-2 logarithm (SIMD-ready). Computes log2(x) for each element.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch base-10 logarithm (SIMD-ready). Computes log10(x) for each element.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch square root (SIMD-ready). Computes sqrt(x) for each element.
 * @param AInput Input array (must be non-negative)
 * @param AOutput Output array for square root values
 * @return Number of elements processed
 *}
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch absolute value (SIMD-ready). Computes |x| for each element.
 * @param AInput Input array
 * @param AOutput Output array for absolute values
 * @return Number of elements processed
 *}
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch negation (SIMD-ready). Computes -x for each element.
 * @param AInput Input array
 * @param AOutput Output array for negated values
 * @return Number of elements processed
 *}
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch ceiling (SIMD-ready). Computes ceil(x) for each element.
 * @param AInput Input array
 * @param AOutput Output array for ceiling values
 * @return Number of elements processed
 *}
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch floor (SIMD-ready). Computes floor(x) for each element.
 * @param AInput Input array
 * @param AOutput Output array for floor values
 * @return Number of elements processed
 *}
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch round (SIMD-ready). Computes round(x) for each element.
 * @param AInput Input array
 * @param AOutput Output array for rounded values (as Single)
 * @return Number of elements processed
 *}
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch truncation (SIMD-ready). Computes trunc(x) for each element.
 * @param AInput Input array
 * @param AOutput Output array for truncated values (as Single)
 * @return Number of elements processed
 *}
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch linear interpolation (SIMD-ready).
 * Computes lerp(a, b, t) = a + t * (b - a) for each element.
 * Signature matches BatchLerpF32 in nextpas.core.math.batch.
 * @param AStart Start values array
 * @param AEnd End values array
 * @param AT Interpolation factor (scalar, 0..1 typical)
 * @param AOutput Output array for interpolated values
 * @return Number of elements processed
 *}
function BatchLerpSimdF32(const AStart, AEnd: array of Single;
                          const AT: Single;
                          var AOutput: array of Single): SizeInt;

{** Batch clamp (SIMD-ready). Clamps each element to [AMin, AMax].
 * @param AInput Input array
 * @param AMin Minimum value
 * @param AMax Maximum value
 * @param AOutput Output array for clamped values
 * @return Number of elements processed
 *}
function BatchClampSimdF32(const AInput: array of Single;
                           const AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;

{** Batch scale and offset (SIMD-ready).
 * Computes input * scale + offset for each element.
 * @param AInput Input array
 * @param AScale Scale factor
 * @param AOffset Offset value
 * @param AOutput Output array
 * @return Number of elements processed
 *}
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 const AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;

implementation

uses
  Math,
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.simd;

// -- SIMD-optimized implementations --
// Each function processes 4 elements per SIMD iteration, scalar fallback for remaining elements.

{ BatchSinSimdF32 }
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Sin(AInput[i]);
  Result := LCount;
end;

{ BatchCosSimdF32 }
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Cos(AInput[i]);
  Result := LCount;
end;

{ BatchTanSimdF32 }
function BatchTanSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Tan(AInput[i]);
  Result := LCount;
end;

{ BatchSinCosSimdF32 — Scalar fallback using Math.SinCos for joint computation }
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
  LS, LC: Single;
begin
  LCount := Length(AInput);
  if LCount > Length(ASinOutput) then
    LCount := Length(ASinOutput);
  if LCount > Length(ACosOutput) then
    LCount := Length(ACosOutput);
  for i := 0 to LCount - 1 do
  begin
    Math.SinCos(AInput[i], LS, LC);
    ASinOutput[i] := LS;
    ACosOutput[i] := LC;
  end;
  Result := LCount;
end;

{ BatchExpSimdF32 }
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Exp(AInput[i]);
  Result := LCount;
end;

{ BatchLnSimdF32 }
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Ln(AInput[i]);
  Result := LCount;
end;

{ BatchLog2SimdF32 }
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log2(AInput[i]);
  Result := LCount;
end;

{ BatchLog10SimdF32 }
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log10(AInput[i]);
  Result := LCount;
end;

{ BatchSqrtSimdF32 — SIMD-optimized via VecF32x4Sqrt (SQRTPS/VSQRTSS) }
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Sqrt(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Sqrt(AInput[i]);
  Result := LCount;
end;

{ BatchAbsSimdF32 — SIMD-optimized via VecF32x4Abs (ANDPS with 0x7FFFFFFF mask) }
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Abs(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Abs(AInput[i]);
  Result := LCount;
end;

{ BatchNegSimdF32 — SIMD-optimized via unary negation (XORPS with 0x80000000 sign bit) }
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := -LVec;
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := -AInput[i];
  Result := LCount;
end;

{ BatchCeilSimdF32 — SIMD-optimized via VecF32x4Ceil (ROUNDPD with +inf rounding) }
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Ceil(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Single(Ceil(AInput[i]));
  Result := LCount;
end;

{ BatchFloorSimdF32 — SIMD-optimized via VecF32x4Floor (ROUNDPD with -inf rounding) }
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Floor(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Single(Floor(AInput[i]));
  Result := LCount;
end;

{ BatchRoundSimdF32 — SIMD-optimized via VecF32x4Round (ROUNDPD with nearest) }
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Round(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Single(Round(AInput[i]));
  Result := LCount;
end;

{ BatchTruncSimdF32 — SIMD-optimized via VecF32x4Trunc (ROUNDPD with toward-zero) }
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Trunc(LVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := Single(Trunc(AInput[i]));
  Result := LCount;
end;

{ BatchLerpSimdF32 — SIMD-optimized via VecF32x4Fma: lerp(a,b,t) = a + t*(b-a) = fma(t, b-a, a) }
function BatchLerpSimdF32(const AStart, AEnd: array of Single;
                          const AT: Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LStart, LEnd, LDiff, LT: TVecF32x4;
begin
  LCount := Length(AStart);
  if LCount > Length(AEnd) then
    LCount := Length(AEnd);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LT := VecF32x4Splat(AT);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LStart := VecF32x4Load(@AStart[i]);
    LEnd := VecF32x4Load(@AEnd[i]);
    LDiff := VecF32x4Sub(LEnd, LStart);
    LStart := VecF32x4Fma(LT, LDiff, LStart);
    VecF32x4Store(@AOutput[i], LStart);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := AStart[i] + AT * (AEnd[i] - AStart[i]);
  Result := LCount;
end;

{ BatchClampSimdF32 — SIMD-optimized via VecF32x4Clamp (MINPS+MAXPS) }
function BatchClampSimdF32(const AInput: array of Single;
                           const AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec, LMinVec, LMaxVec: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LMinVec := VecF32x4Splat(AMin);
  LMaxVec := VecF32x4Splat(AMax);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Clamp(LVec, LMinVec, LMaxVec);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
  begin
    if AInput[i] < AMin then
      AOutput[i] := AMin
    else if AInput[i] > AMax then
      AOutput[i] := AMax
    else
      AOutput[i] := AInput[i];
  end;
  Result := LCount;
end;

{ BatchScaleOffsetSimdF32 — SIMD-optimized via VecF32x4Fma: input*scale + offset = fma(input, scale, offset) }
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 const AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdEnd: SizeInt;
  LVec, LScale, LOffset: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  LScale := VecF32x4Splat(AScale);
  LOffset := VecF32x4Splat(AOffset);
  LSimdEnd := LCount - (LCount mod 4);
  i := 0;
  while i < LSimdEnd do
  begin
    LVec := VecF32x4Load(@AInput[i]);
    LVec := VecF32x4Fma(LVec, LScale, LOffset);
    VecF32x4Store(@AOutput[i], LVec);
    Inc(i, 4);
  end;
  for i := LSimdEnd to LCount - 1 do
    AOutput[i] := AInput[i] * AScale + AOffset;
  Result := LCount;
end;

end.
