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

{** Batch arc tangent of y/x (SIMD-ready). *}
function BatchAtan2SimdF32(const AY, AX: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch hypotenuse (SIMD-ready). Computes sqrt(x*x + y*y). *}
function BatchHypotSimdF32(const AX, AY: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch fractional part (SIMD-ready). Computes x - trunc(x). *}
function BatchFractSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;

{** Batch modulo (SIMD-ready). Computes x mod divisor. *}
function BatchModSimdF32(const AInput: array of Single;
                         const ADivisor: Single;
                         var AOutput: array of Single): SizeInt;

{** Batch sign (SIMD-ready). Returns -1, 0, or 1. *}
function BatchSignSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch step function (SIMD-ready). Returns 0 if x < edge, 1 otherwise. *}
function BatchStepSimdF32(const AEdge, AInput: array of Single;
                          var AOutput: array of Single): SizeInt;

{** Batch smoothstep (SIMD-ready). Hermite interpolation between 0 and 1. *}
function BatchSmoothstepSimdF32(const AEdge0, AEdge1, AInput: array of Single;
                                var AOutput: array of Single): SizeInt;

{ F64 batch surface — mirrors F32, dispatching to Array*F64. }
function BatchSinSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchCosSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchTanSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchSinCosSimdF64(const AInput: array of Double;
                            var ASinOutput, ACosOutput: array of Double): SizeInt;
function BatchExpSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchLnSimdF64(const AInput: array of Double;
                        var AOutput: array of Double): SizeInt;
function BatchLog2SimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
function BatchLog10SimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchSqrtSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
function BatchAbsSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchNegSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
function BatchCeilSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
function BatchFloorSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchRoundSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchTruncSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchLerpSimdF64(const AStart, AEnd: array of Double;
                          const AT: Double;
                          var AOutput: array of Double): SizeInt;
function BatchClampSimdF64(const AInput: array of Double;
                           const AMin, AMax: Double;
                           var AOutput: array of Double): SizeInt;
function BatchScaleOffsetSimdF64(const AInput: array of Double;
                                 const AScale, AOffset: Double;
                                 var AOutput: array of Double): SizeInt;
function BatchAtan2SimdF64(const AY, AX: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchHypotSimdF64(const AX, AY: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchFractSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
function BatchModSimdF64(const AInput: array of Double;
                         const ADivisor: Double;
                         var AOutput: array of Double): SizeInt;
function BatchSignSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
function BatchStepSimdF64(const AEdge, AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
function BatchSmoothstepSimdF64(const AEdge0, AEdge1, AInput: array of Double;
                                var AOutput: array of Double): SizeInt;

implementation

uses
  nextpas.core.errors,
  nextpas.core.simd,
  nextpas.core.math.base,
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

{ Helper: batch open-array length for 1 in + 1 out }
function MinArrayCount(const AInput: array of Single;
                      const AOutput: array of Single): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin(Length(AInput), Length(AOutput));
end;

function MinArrayCount(const AInput: array of Double;
                      const AOutput: array of Double): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin(Length(AInput), Length(AOutput));
end;

{ Helper: two inputs + one output }
function MinArrayCount3(const A1, A2, AOutput: array of Single): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin3(Length(A1), Length(A2), Length(AOutput));
end;

function MinArrayCount3(const A1, A2, AOutput: array of Double): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin3(Length(A1), Length(A2), Length(AOutput));
end;

{ Helper: three inputs + one output }
function MinArrayCount4(const A1, A2, A3, AOutput: array of Single): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin4(Length(A1), Length(A2), Length(A3), Length(AOutput));
end;

function MinArrayCount4(const A1, A2, A3, AOutput: array of Double): SizeInt; inline; overload;
begin
  Result := ResolveEqualOrMin4(Length(A1), Length(A2), Length(A3), Length(AOutput));
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

{ BatchAtan2SimdF32 - uses ArrayAtan2F32 }
function BatchAtan2SimdF32(const AY, AX: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AY, AX, AOutput);
  if LCount > 0 then
    ArrayAtan2F32(@AY[0], @AX[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchHypotSimdF32 - uses ArrayHypotF32 }
function BatchHypotSimdF32(const AX, AY: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AX, AY, AOutput);
  if LCount > 0 then
    ArrayHypotF32(@AX[0], @AY[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchFractSimdF32 - uses ArrayFractF32 }
function BatchFractSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayFractF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchModSimdF32 - uses ArrayModF32 }
function BatchModSimdF32(const AInput: array of Single;
                         const ADivisor: Single;
                         var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayModF32(@AInput[0], @AOutput[0], LCount, ADivisor);
  Result := LCount;
end;

{ BatchSignSimdF32 - uses ArraySignF32 }
function BatchSignSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySignF32(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchStepSimdF32 - uses ArrayStepF32 }
function BatchStepSimdF32(const AEdge, AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AEdge, AInput, AOutput);
  if LCount > 0 then
    ArrayStepF32(@AEdge[0], @AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ BatchSmoothstepSimdF32 - uses ArraySmoothstepF32 }
function BatchSmoothstepSimdF32(const AEdge0, AEdge1, AInput: array of Single;
                                var AOutput: array of Single): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount4(AEdge0, AEdge1, AInput, AOutput);
  if LCount > 0 then
    ArraySmoothstepF32(@AEdge0[0], @AEdge1[0], @AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

{ ============================================================================
  F64 batch operations using Array*F64
  ============================================================================ }

function BatchSinSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySinF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchCosSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayCosF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchTanSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayTanF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchSinCosSimdF64(const AInput: array of Double;
                            var ASinOutput, ACosOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AInput, ASinOutput, ACosOutput);
  if LCount > 0 then
    ArraySinCosF64(@AInput[0], @ASinOutput[0], @ACosOutput[0], LCount);
  Result := LCount;
end;

function BatchExpSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayExpF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchLnSimdF64(const AInput: array of Double;
                        var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLogF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchLog2SimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLog2F64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchLog10SimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLog10F64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchSqrtSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySqrtF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchAbsSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayAbsF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchNegSimdF64(const AInput: array of Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayNegF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchCeilSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayCeilF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchFloorSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayFloorF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchRoundSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayRoundF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchTruncSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayTruncF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchLerpSimdF64(const AStart, AEnd: array of Double;
                          const AT: Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AStart, AEnd, AOutput);
  if LCount > 0 then
    ArrayLerpF64(@AStart[0], @AEnd[0], @AOutput[0], LCount, AT);
  Result := LCount;
end;

function BatchClampSimdF64(const AInput: array of Double;
                           const AMin, AMax: Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayClampF64(@AInput[0], @AOutput[0], LCount, AMin, AMax);
  Result := LCount;
end;

function BatchScaleOffsetSimdF64(const AInput: array of Double;
                                 const AScale, AOffset: Double;
                                 var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayLinearF64(@AInput[0], @AOutput[0], LCount, AScale, AOffset);
  Result := LCount;
end;

function BatchAtan2SimdF64(const AY, AX: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AY, AX, AOutput);
  if LCount > 0 then
    ArrayAtan2F64(@AY[0], @AX[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchHypotSimdF64(const AX, AY: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AX, AY, AOutput);
  if LCount > 0 then
    ArrayHypotF64(@AX[0], @AY[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchFractSimdF64(const AInput: array of Double;
                           var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayFractF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchModSimdF64(const AInput: array of Double;
                         const ADivisor: Double;
                         var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArrayModF64(@AInput[0], @AOutput[0], LCount, ADivisor);
  Result := LCount;
end;

function BatchSignSimdF64(const AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount(AInput, AOutput);
  if LCount > 0 then
    ArraySignF64(@AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchStepSimdF64(const AEdge, AInput: array of Double;
                          var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount3(AEdge, AInput, AOutput);
  if LCount > 0 then
    ArrayStepF64(@AEdge[0], @AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

function BatchSmoothstepSimdF64(const AEdge0, AEdge1, AInput: array of Double;
                                var AOutput: array of Double): SizeInt;
var
  LCount: SizeInt;
begin
  LCount := MinArrayCount4(AEdge0, AEdge1, AInput, AOutput);
  if LCount > 0 then
    ArraySmoothstepF64(@AEdge0[0], @AEdge1[0], @AInput[0], @AOutput[0], LCount);
  Result := LCount;
end;

end.
