unit nextpas.core.math.batch.simd;
{**
 * SIMD-optimized batch math operations.
 *
 * This unit provides SIMD-accelerated wrappers for batch scalar operations.
 * Uses nextpas.core.simd Array* batch functions for O(1) dispatch overhead.
 *
 * Design contract:
 *   - API mirrors nextpas.core.math.batch (same signatures)
 *   - Array* functions: single dispatch, internal SIMD loop + scalar tail
 *   - The "Simd" suffix signals SIMD-ready dispatch path
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{** Batch sine (SIMD-ready). Computes sin(x) for each element. *}
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch cosine (SIMD-ready). Computes cos(x) for each element. *}
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch tangent (SIMD-ready). Computes tan(x) for each element. *}
function BatchTanSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch simultaneous sine and cosine (SIMD-ready). *}
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;

{** Batch exponential (SIMD-ready). Computes e^x for each element. *}
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch natural logarithm (SIMD-ready). Computes ln(x) for each element. *}
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;

{** Batch base-2 logarithm (SIMD-ready). Computes log2(x) for each element. *}
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch base-10 logarithm (SIMD-ready). Computes log10(x) for each element. *}
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch square root (SIMD-ready). Computes sqrt(x) for each element. *}
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch absolute value (SIMD-ready). Computes |x| for each element. *}
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch negation (SIMD-ready). Computes -x for each element. *}
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;

{** Batch ceiling (SIMD-ready). Computes ceil(x) for each element. *}
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch floor (SIMD-ready). Computes floor(x) for each element. *}
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch round (SIMD-ready). Computes round(x) for each element. *}
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch truncation (SIMD-ready). Computes trunc(x) for each element. *}
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch linear interpolation (SIMD-ready). *}
function BatchLerpSimdF32(const AStart, AEnd: array of Single;
                          const AT: Single;
                          var AOutput: array of Single): SizeInt;

{** Batch clamp (SIMD-ready). Clamps each element to [AMin, AMax] range. *}
function BatchClampSimdF32(const AInput: array of Single;
                           const AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;

{** Batch scale and offset (SIMD-ready). *}
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 const AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;

implementation

uses
  nextpas.core.simd,
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

{ Helper: compute min count from input/output arrays }
function MinArrayCount(const AInput: array of Single;
                      const AOutput: array of Single): SizeInt; inline;
var
  LInCount, LOutCount: SizeInt;
begin
  LInCount := Length(AInput);
  LOutCount := Length(AOutput);
  if LInCount < LOutCount then
    Result := LInCount
  else
    Result := LOutCount;
end;

{ Helper: compute min count from two input arrays and one output array }
function MinArrayCount3(const A1, A2, AOutput: array of Single): SizeInt; inline;
var
  L1, L2, LOut: SizeInt;
begin
  L1 := Length(A1);
  L2 := Length(A2);
  LOut := Length(AOutput);
  Result := L1;
  if L2 < Result then
    Result := L2;
  if LOut < Result then
    Result := LOut;
end;

{ ============================================================================
  Batch operations using Array* (O(1) dispatch, internal SIMD loop)
  All functions use native SIMD batch implementations from nextpas.core.simd.
  ============================================================================ }

{ BatchSinSimdF32 - uses ArraySinF32 }
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySinF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchCosSimdF32 - uses ArrayCosF32 }
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayCosF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchTanSimdF32 - uses ArrayTanF32 }
function BatchTanSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayTanF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchSinCosSimdF32 - uses ArraySinCosF32 }
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AInput, ASinOutput, ACosOutput);
  if LCount > 0 then
    ArraySinCosF32(@AInput[0], @ASinOutput[0], @ACosOutput[0], LCount);
  Result := LCount;
end;

{ BatchExpSimdF32 - uses ArrayExpF32 }
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayExpF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchLnSimdF32 - uses ArrayLogF32 (natural log) }
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLogF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchLog2SimdF32 - uses ArrayLog2F32 }
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLog2F32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchLog10SimdF32 - uses ArrayLog10F32 }
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLog10F32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchSqrtSimdF32 - uses ArraySqrtF32 }
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySqrtF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchAbsSimdF32 - uses ArrayAbsF32 }
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayAbsF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchNegSimdF32 - uses ArrayNegF32 }
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayNegF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchCeilSimdF32 - uses ArrayCeilF32 }
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayCeilF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchFloorSimdF32 - uses ArrayFloorF32 }
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayFloorF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchRoundSimdF32 - uses ArrayRoundF32 }
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayRoundF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchTruncSimdF32 - uses ArrayTruncF32 }
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayTruncF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchLerpSimdF32 - uses ArrayLerpF32 }
function BatchLerpSimdF32(const AStart, AEnd: array of Single;
                          const AT: Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AStart, AEnd, AOutput);
  if LCount > 0 then
    ArrayLerpF32(@AStart[0], @AEnd[0], @AOutput[0], LCount, AT);
  Result := LCount;
end;

{ BatchClampSimdF32 - uses ArrayClampF32 }
function BatchClampSimdF32(const AInput: array of Single;
                           const AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayClampF32(@AInput[0], @AOutput[0], LCount, AMin, AMax);
  Result := LCount;
end;

{ BatchScaleOffsetSimdF32 - uses ArrayLinearF32 (scale * x + bias) }
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 const AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLinearF32(@AInput[0], @AOutput[0], LCount, AScale, AOffset);
  Result := LCount;
end;

end.
