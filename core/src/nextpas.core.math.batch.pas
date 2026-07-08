unit nextpas.core.math.batch;

{$I nextpas.core.settings.inc}

interface

uses
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

implementation

uses
  nextpas.core.math.scalar,
  nextpas.core.simd;

{ BatchSinF32 }
function BatchSinF32(const AInput: array of Single;
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

{ BatchCosF32 }
function BatchCosF32(const AInput: array of Single;
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

{ BatchTanF32 }
function BatchTanF32(const AInput: array of Single;
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

{ BatchExpF32 }
function BatchExpF32(const AInput: array of Single;
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

{ BatchLnF32 }
function BatchLnF32(const AInput: array of Single;
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

{ BatchLog10F32 }
function BatchLog10F32(const AInput: array of Single;
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

{ BatchLog2F32 }
function BatchLog2F32(const AInput: array of Single;
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

{ BatchSqrtF32 }
function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Sqrt(AInput[i]);

  Result := LCount;
end;

{ BatchAbsF32 }
function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Abs(AInput[i]);

  Result := LCount;
end;

{ BatchNegF32 }
function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := -AInput[i];

  Result := LCount;
end;

{ BatchCeilF32 }
function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Ceil(AInput[i]);

  Result := LCount;
end;

{ BatchFloorF32 }
function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Floor(AInput[i]);

  Result := LCount;
end;

{ BatchRoundF32 }
function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Round(AInput[i]);

  Result := LCount;
end;

{ BatchTruncF32 }
function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := Trunc(AInput[i]);

  Result := LCount;
end;

{ BatchLerpF32 }
function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AStart);
  if LCount > Length(AEnd) then
    LCount := Length(AEnd);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := AStart[i] + AT * (AEnd[i] - AStart[i]);

  Result := LCount;
end;

{ BatchClampF32 }
function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
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

{ BatchScaleOffsetF32 }
function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);

  for i := 0 to LCount - 1 do
    AOutput[i] := AInput[i] * AScale + AOffset;

  Result := LCount;
end;

end.
