unit nextpas.core.math.batch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.math.base,
  nextpas.core.math.trig;

{** Batch sine function for Single arrays.
 * Computes sine of each element in the input array.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for sine values
 * @return Number of elements processed
 *}
function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch cosine function for Single arrays.
 * Computes cosine of each element in the input array.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for cosine values
 * @return Number of elements processed
 *}
function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch simultaneous sine and cosine for Single arrays.
 * Computes both sin(x) and cos(x) for each element in a single pass,
 * which is faster than calling BatchSinF32 and BatchCosF32 separately.
 * @param AInput Input array of angles in radians
 * @param ASinOutput Output array for sine values
 * @param ACosOutput Output array for cosine values
 * @return Number of elements processed
 *}
function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;

{** Batch tangent function for Single arrays.
 * Computes tangent of each element in the input array.
 * @param AInput Input array of angles in radians
 * @param AOutput Output array for tangent values
 * @return Number of elements processed
 *}
function BatchTanF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch exponential function for Single arrays.
 * Computes e^x for each element in the input array.
 * @param AInput Input array of exponents
 * @param AOutput Output array for exponential values
 * @return Number of elements processed
 *}
function BatchExpF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch natural logarithm for Single arrays.
 * Computes ln(x) for each element in the input array.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLnF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;

{** Alias for BatchLnF32 (natural log). Matches simd ArrayLogF32 naming. *}
function BatchLogF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Try natural log: False if any non-positive or non-finite element (no write). *}
function TryBatchLnF32(const AInput: array of Single;
                       var AOutput: array of Single;
                       out ACount: SizeInt): Boolean;

{** Batch base-10 logarithm for Single arrays.
 * Computes log10(x) for each element in the input array.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLog10F32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch base-2 logarithm for Single arrays.
 * Computes log2(x) for each element in the input array.
 * @param AInput Input array (must be positive)
 * @param AOutput Output array for logarithm values
 * @return Number of elements processed
 *}
function BatchLog2F32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch square root for Single arrays.
 * Computes sqrt(x) for each element in the input array.
 * @param AInput Input array (must be non-negative)
 * @param AOutput Output array for square root values
 * @return Number of elements processed
 *}
function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch absolute value for Single arrays.
 * Computes |x| for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for absolute values
 * @return Number of elements processed
 *}
function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;

{** Batch negation for Single arrays.
 * Computes -x for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for negated values
 * @return Number of elements processed
 *}
function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;

{** Batch ceiling for Single arrays.
 * Computes ceil(x) for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for ceiling values
 * @return Number of elements processed
 *}
function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;

{** Batch floor for Single arrays.
 * Computes floor(x) for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for floor values
 * @return Number of elements processed
 *}
function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch round for Single arrays.
 * Computes round(x) for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for rounded values (as Single)
 * @return Number of elements processed
 *}
function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch truncation for Single arrays.
 * Computes trunc(x) for each element in the input array.
 * @param AInput Input array
 * @param AOutput Output array for truncated values (as Single)
 * @return Number of elements processed
 *}
function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch linear interpolation for Single arrays.
 * Computes lerp(a, b, t) = a + t * (b - a) for each element.
 * @param AStart Start values array
 * @param AEnd End values array
 * @param AT Interpolation factor (scalar)
 * @param AOutput Output array for interpolated values
 * @return Number of elements processed
 *}
function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;

{** Batch clamp for Single arrays.
 * Clamps each element to [AMin, AMax] range.
 * @param AInput Input array
 * @param AMin Minimum value
 * @param AMax Maximum value
 * @param AOutput Output array for clamped values
 * @return Number of elements processed
 *}
function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;

{** Batch scale and offset for Single arrays.
 * Computes aInput * aScale + aOffset for each element.
 * @param AInput Input array
 * @param AScale Scale factor
 * @param AOffset Offset value
 * @param AOutput Output array
 * @return Number of elements processed
 *}
function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;

{** Batch arc tangent of y/x for Single arrays.
 * Computes atan2(y, x) for each pair of elements.
 * @param AY Y component array
 * @param AX X component array
 * @param AOutput Output array for arc tangent values
 * @return Number of elements processed
 *}
function BatchAtan2F32(const AY, AX: array of Single;
                       var AOutput: array of Single): SizeInt;

{** Batch hypotenuse for Single arrays.
 * Computes sqrt(x*x + y*y) with overflow protection.
 * @param AX X component array
 * @param AY Y component array
 * @param AOutput Output array for hypotenuse values
 * @return Number of elements processed
 *}
function BatchHypotF32(const AX, AY: array of Single;
                       var AOutput: array of Single): SizeInt;

{** Batch fractional part for Single arrays.
 * Computes x - trunc(x) for each element.
 * @param AInput Input array
 * @param AOutput Output array for fractional parts
 * @return Number of elements processed
 *}
function BatchFractF32(const AInput: array of Single;
                       var AOutput: array of Single): SizeInt;

{** Batch modulo for Single arrays.
 * Computes x mod divisor for each element.
 * @param AInput Input array
 * @param ADivisor Divisor value
 * @param AOutput Output array for modulo values
 * @return Number of elements processed
 *}
function BatchModF32(const AInput: array of Single;
                     const ADivisor: Single;
                     var AOutput: array of Single): SizeInt;

{** Batch sign for Single arrays.
 * Returns -1, 0, or 1 for each element.
 * @param AInput Input array
 * @param AOutput Output array for sign values
 * @return Number of elements processed
 *}
function BatchSignF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch step function for Single arrays.
 * Returns 0 if x < edge, 1 otherwise.
 * @param AEdge Edge values array
 * @param AInput Input array
 * @param AOutput Output array for step values
 * @return Number of elements processed
 *}
function BatchStepF32(const AEdge, AInput: array of Single;
                      var AOutput: array of Single): SizeInt;

{** Batch smoothstep for Single arrays.
 * Hermite interpolation between 0 and 1.
 * @param AEdge0 Lower edge array
 * @param AEdge1 Upper edge array
 * @param AInput Input array
 * @param AOutput Output array for smoothstep values
 * @return Number of elements processed
 *}
function BatchSmoothstepF32(const AEdge0, AEdge1, AInput: array of Single;
                            var AOutput: array of Single): SizeInt;

{ Double-precision public batch API — F32 parity over Array*F64. }
function BatchSinF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchCosF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchSinCosF64(const AInput: array of Double;
                        var ASinOutput, ACosOutput: array of Double): SizeInt;
function BatchTanF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchExpF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchLnF64(const AInput: array of Double;
                    var AOutput: array of Double): SizeInt;
{** Alias for BatchLnF64 (natural log). *}
function BatchLogF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function TryBatchLnF64(const AInput: array of Double;
                       var AOutput: array of Double;
                       out ACount: SizeInt): Boolean;
function BatchLog10F64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchLog2F64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchSqrtF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchAbsF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchNegF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
function BatchCeilF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchFloorF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchRoundF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchTruncF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchLerpF64(const AStart, AEnd: array of Double;
                      const AT: Double;
                      var AOutput: array of Double): SizeInt;
function BatchClampF64(const AInput: array of Double;
                       const AMin, AMax: Double;
                       var AOutput: array of Double): SizeInt;
function BatchScaleOffsetF64(const AInput: array of Double;
                             const AScale, AOffset: Double;
                             var AOutput: array of Double): SizeInt;
function BatchAtan2F64(const AY, AX: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchHypotF64(const AX, AY: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchFractF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
function BatchModF64(const AInput: array of Double;
                     const ADivisor: Double;
                     var AOutput: array of Double): SizeInt;
function BatchSignF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchStepF64(const AEdge, AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
function BatchSmoothstepF64(const AEdge0, AEdge1, AInput: array of Double;
                            var AOutput: array of Double): SizeInt;

implementation

uses
  nextpas.core.math.batch.simd,
  nextpas.core.math.scalar;

{ BatchSinF32 }
function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchSinSimdF32(AInput, AOutput);
end;

{ BatchCosF32 }
function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchCosSimdF32(AInput, AOutput);
end;

{ BatchSinCosF32 }
function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;
begin
  Result := BatchSinCosSimdF32(AInput, ASinOutput, ACosOutput);
end;

{ BatchTanF32 }
function BatchTanF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchTanSimdF32(AInput, AOutput);
end;

{ BatchExpF32 }
function BatchExpF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchExpSimdF32(AInput, AOutput);
end;

{ BatchLnF32 }
function BatchLnF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := BatchLnSimdF32(AInput, AOutput);
end;

{ BatchLogF32 — alias of BatchLnF32 }
function BatchLogF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchLnF32(AInput, AOutput);
end;

{ TryBatchLnF32 }
function TryBatchLnF32(const AInput: array of Single;
                       var AOutput: array of Single;
                       out ACount: SizeInt): Boolean;
var
  i: SizeInt;
  L: SizeInt;
begin
  ACount := 0;
  L := Length(AInput);
  if L <> Length(AOutput) then
    Exit(False);
  if L = 0 then
    Exit(True);
  for i := 0 to L - 1 do
    if (AInput[i] <= 0.0) or IsNaN(AInput[i]) or IsInfinite(AInput[i]) then
      Exit(False);
  ACount := BatchLnF32(AInput, AOutput);
  Result := True;
end;

{ BatchLog10F32 }
function BatchLog10F32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchLog10SimdF32(AInput, AOutput);
end;

{ BatchLog2F32 }
function BatchLog2F32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchLog2SimdF32(AInput, AOutput);
end;

{ BatchSqrtF32 }
function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchSqrtSimdF32(AInput, AOutput);
end;

{ BatchAbsF32 }
function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := BatchAbsSimdF32(AInput, AOutput);
end;

{ BatchNegF32 }
function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
begin
  Result := BatchNegSimdF32(AInput, AOutput);
end;

{ BatchCeilF32 }
function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchCeilSimdF32(AInput, AOutput);
end;

{ BatchFloorF32 }
function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchFloorSimdF32(AInput, AOutput);
end;

{ BatchRoundF32 }
function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchRoundSimdF32(AInput, AOutput);
end;

{ BatchTruncF32 }
function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchTruncSimdF32(AInput, AOutput);
end;

{ BatchLerpF32 }
function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchLerpSimdF32(AStart, AEnd, AT, AOutput);
end;

{ BatchClampF32 }
function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;
begin
  if AMin > AMax then
    raise EArgumentError.Create('Clamp: minimum must not exceed maximum');
  Result := BatchClampSimdF32(AInput, AMin, AMax, AOutput);
end;

{ BatchScaleOffsetF32 }
function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;
begin
  Result := BatchScaleOffsetSimdF32(AInput, AScale, AOffset, AOutput);
end;

{ BatchAtan2F32 }
function BatchAtan2F32(const AY, AX: array of Single;
                       var AOutput: array of Single): SizeInt;
begin
  Result := BatchAtan2SimdF32(AY, AX, AOutput);
end;

{ BatchHypotF32 }
function BatchHypotF32(const AX, AY: array of Single;
                       var AOutput: array of Single): SizeInt;
begin
  Result := BatchHypotSimdF32(AX, AY, AOutput);
end;

{ BatchFractF32 }
function BatchFractF32(const AInput: array of Single;
                       var AOutput: array of Single): SizeInt;
begin
  Result := BatchFractSimdF32(AInput, AOutput);
end;

{ BatchModF32 }
function BatchModF32(const AInput: array of Single;
                     const ADivisor: Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchModSimdF32(AInput, ADivisor, AOutput);
end;

{ BatchSignF32 }
function BatchSignF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchSignSimdF32(AInput, AOutput);
end;

{ BatchStepF32 }
function BatchStepF32(const AEdge, AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
begin
  Result := BatchStepSimdF32(AEdge, AInput, AOutput);
end;

{ BatchSmoothstepF32 }
function BatchSmoothstepF32(const AEdge0, AEdge1, AInput: array of Single;
                            var AOutput: array of Single): SizeInt;
begin
  Result := BatchSmoothstepSimdF32(AEdge0, AEdge1, AInput, AOutput);
end;

{ F64 public wrappers }

function BatchSinF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchSinSimdF64(AInput, AOutput);
end;

function BatchCosF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchCosSimdF64(AInput, AOutput);
end;

function BatchSinCosF64(const AInput: array of Double;
                        var ASinOutput, ACosOutput: array of Double): SizeInt;
begin
  Result := BatchSinCosSimdF64(AInput, ASinOutput, ACosOutput);
end;

function BatchTanF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchTanSimdF64(AInput, AOutput);
end;

function BatchExpF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchExpSimdF64(AInput, AOutput);
end;

function BatchLnF64(const AInput: array of Double;
                    var AOutput: array of Double): SizeInt;
begin
  Result := BatchLnSimdF64(AInput, AOutput);
end;

function BatchLogF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchLnF64(AInput, AOutput);
end;

function TryBatchLnF64(const AInput: array of Double;
                       var AOutput: array of Double;
                       out ACount: SizeInt): Boolean;
var
  i: SizeInt;
  L: SizeInt;
begin
  ACount := 0;
  L := Length(AInput);
  if L <> Length(AOutput) then
    Exit(False);
  if L = 0 then
    Exit(True);
  for i := 0 to L - 1 do
    if (AInput[i] <= 0.0) or IsNaN(AInput[i]) or IsInfinite(AInput[i]) then
      Exit(False);
  ACount := BatchLnF64(AInput, AOutput);
  Result := True;
end;

function BatchLog10F64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchLog10SimdF64(AInput, AOutput);
end;

function BatchLog2F64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchLog2SimdF64(AInput, AOutput);
end;

function BatchSqrtF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchSqrtSimdF64(AInput, AOutput);
end;

function BatchAbsF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchAbsSimdF64(AInput, AOutput);
end;

function BatchNegF64(const AInput: array of Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchNegSimdF64(AInput, AOutput);
end;

function BatchCeilF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchCeilSimdF64(AInput, AOutput);
end;

function BatchFloorF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchFloorSimdF64(AInput, AOutput);
end;

function BatchRoundF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchRoundSimdF64(AInput, AOutput);
end;

function BatchTruncF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchTruncSimdF64(AInput, AOutput);
end;

function BatchLerpF64(const AStart, AEnd: array of Double;
                      const AT: Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchLerpSimdF64(AStart, AEnd, AT, AOutput);
end;

function BatchClampF64(const AInput: array of Double;
                       const AMin, AMax: Double;
                       var AOutput: array of Double): SizeInt;
begin
  if AMin > AMax then
    raise EArgumentError.Create('Clamp: minimum must not exceed maximum');
  Result := BatchClampSimdF64(AInput, AMin, AMax, AOutput);
end;

function BatchScaleOffsetF64(const AInput: array of Double;
                             const AScale, AOffset: Double;
                             var AOutput: array of Double): SizeInt;
begin
  Result := BatchScaleOffsetSimdF64(AInput, AScale, AOffset, AOutput);
end;

function BatchAtan2F64(const AY, AX: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchAtan2SimdF64(AY, AX, AOutput);
end;

function BatchHypotF64(const AX, AY: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchHypotSimdF64(AX, AY, AOutput);
end;

function BatchFractF64(const AInput: array of Double;
                       var AOutput: array of Double): SizeInt;
begin
  Result := BatchFractSimdF64(AInput, AOutput);
end;

function BatchModF64(const AInput: array of Double;
                     const ADivisor: Double;
                     var AOutput: array of Double): SizeInt;
begin
  Result := BatchModSimdF64(AInput, ADivisor, AOutput);
end;

function BatchSignF64(const AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchSignSimdF64(AInput, AOutput);
end;

function BatchStepF64(const AEdge, AInput: array of Double;
                      var AOutput: array of Double): SizeInt;
begin
  Result := BatchStepSimdF64(AEdge, AInput, AOutput);
end;

function BatchSmoothstepF64(const AEdge0, AEdge1, AInput: array of Double;
                            var AOutput: array of Double): SizeInt;
begin
  Result := BatchSmoothstepSimdF64(AEdge0, AEdge1, AInput, AOutput);
end;

end.
