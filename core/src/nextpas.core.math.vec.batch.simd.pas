unit nextpas.core.math.vec.batch.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat;

{** SIMD-optimized batch dot product for TVec4f arrays.
 * Computes dot product of corresponding vectors in ALeft and ARight.
 * @param ALeft Left operand array
 * @param ARight Right operand array
 * @param AResults Output array for dot products
 * @return Number of elements processed
 *}
function BatchDotSimd4f(const ALeft, ARight: array of TVec4f;
                        var AResults: array of Single): SizeInt;

{** SIMD-optimized batch dot product for TVec3f arrays.
 * Computes dot product of corresponding vectors in ALeft and ARight.
 * @param ALeft Left operand array
 * @param ARight Right operand array
 * @param AResults Output array for dot products
 * @return Number of elements processed
 *}
function BatchDotSimd3f(const ALeft, ARight: array of TVec3f;
                        var AResults: array of Single): SizeInt;

{** SIMD-optimized batch normalize for TVec4f arrays (in-place).
 * Normalizes each vector to unit length.
 * @param AVectors Input/output vector array
 * @return Number of elements processed
 *}
function BatchNormalizeSimd4f(var AVectors: array of TVec4f): SizeInt;

{** SIMD-optimized batch normalize for TVec3f arrays (in-place).
 * Normalizes each vector to unit length.
 * @param AVectors Input/output vector array
 * @return Number of elements processed
 *}
function BatchNormalizeSimd3f(var AVectors: array of TVec3f): SizeInt;

{** SIMD-optimized batch normalize for TVec3f arrays (with output).
 * @param ASource Source vector array
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchNormalizeSimd3f(const ASource: array of TVec3f;
                              var ADest: array of TVec3f): SizeInt;

{** SIMD-optimized batch transform for TMat4f * TVec3f arrays.
 * Transforms each vector by the matrix (homogeneous coordinates).
 * @param AMatrix Transformation matrix
 * @param ASource Source vector array
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchTransformSimd4f(const AMatrix: TMat4f;
                              const ASource: array of TVec3f;
                              var ADest: array of TVec3f): SizeInt;

{** SIMD-optimized batch lerp for TVec4f arrays.
 * Linearly interpolates between start and end vectors.
 * @param AStart Start vector array
 * @param AEnd End vector array
 * @param AT Interpolation factor (0 = start, 1 = end)
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchLerpSimd4f(const AStart, AEnd: array of TVec4f;
                         const AT: Single;
                         var ADest: array of TVec4f): SizeInt;

{** SIMD-optimized batch lerp for TVec3f arrays.
 * Linearly interpolates between start and end vectors.
 * @param AStart Start vector array
 * @param AEnd End vector array
 * @param AT Interpolation factor (0 = start, 1 = end)
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchLerpSimd3f(const AStart, AEnd: array of TVec3f;
                         const AT: Single;
                         var ADest: array of TVec3f): SizeInt;

{** SIMD-optimized batch clamp for TVec4f arrays.
 * Clamps each vector to [AMin, AMax] range.
 * @param AVectors Input vector array
 * @param AMin Minimum values
 * @param AMax Maximum values
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchClampSimd4f(const AVectors: array of TVec4f;
                          const AMin, AMax: TVec4f;
                          var ADest: array of TVec4f): SizeInt;

{** SIMD-optimized batch clamp for TVec3f arrays.
 * Clamps each vector to [AMin, AMax] range.
 * @param AVectors Input vector array
 * @param AMin Minimum values
 * @param AMax Maximum values
 * @param ADest Destination vector array
 * @return Number of elements processed
 *}
function BatchClampSimd3f(const AVectors: array of TVec3f;
                          const AMin, AMax: TVec3f;
                          var ADest: array of TVec3f): SizeInt;

implementation

uses
  nextpas.core.errors,
  nextpas.core.simd,
  nextpas.core.text.conv;

{ Length policy (usability Wave-2): same as math.batch.simd. }

function ResolveEqualOrMin(const A, B: SizeInt): SizeInt; inline;
begin
  if (A = 0) or (B = 0) then
    Exit(0);
  if A = B then
    Exit(A);
{$IFDEF NEXTPAS_MATH_BATCH_TRUNCATE_MIN}
  if A < B then
    Result := A
  else
    Result := B;
{$ELSE}
  raise EArgumentError.Create(
    'Batch: array lengths must match (got ' + IntToStr(Int64(A)) +
    ' vs ' + IntToStr(Int64(B)) + ')');
{$ENDIF}
end;

function ResolveEqualOrMin3(const A, B, C: SizeInt): SizeInt; inline;
begin
  Result := ResolveEqualOrMin(ResolveEqualOrMin(A, B), C);
end;


{ Helper: Convert TVec4f to TVecF32x4 }
function Vec4fToSimd(const V: TVec4f): TVecF32x4; inline;
begin
  Result := VecF32x4Load(@V.Data[0]);
end;

{ Helper: Convert TVecF32x4 to TVec4f }
function SimdToVec4f(const V: TVecF32x4): TVec4f; inline;
begin
  VecF32x4Store(@Result.Data[0], V);
end;

{ Helper: Convert TVec3f to TVecF32x4 (W = 0) }
function Vec3fToSimd(const V: TVec3f): TVecF32x4; inline;
begin
  Result := VecF32x4Make(V.X, V.Y, V.Z, 0.0);
end;

{ Helper: Convert TVecF32x4 to TVec3f (ignores W) }
function SimdToVec3f(const V: TVecF32x4): TVec3f; inline;
begin
  Result.X := VecF32x4Extract(V, 0);
  Result.Y := VecF32x4Extract(V, 1);
  Result.Z := VecF32x4Extract(V, 2);
end;

{ BatchDotSimd4f }
function BatchDotSimd4f(const ALeft, ARight: array of TVec4f;
                        var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
  LLeft, LRight: TVecF32x4;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));

  for i := 0 to LCount - 1 do
  begin
    LLeft := Vec4fToSimd(ALeft[i]);
    LRight := Vec4fToSimd(ARight[i]);
    AResults[i] := VecF32x4Dot(LLeft, LRight);
  end;

  Result := LCount;
end;

{ BatchDotSimd3f }
function BatchDotSimd3f(const ALeft, ARight: array of TVec3f;
                        var AResults: array of Single): SizeInt;
var
  i, LCount: SizeInt;
  LLeft, LRight: TVecF32x4;
begin
  LCount := ResolveEqualOrMin3(Length(ALeft), Length(ARight), Length(AResults));

  for i := 0 to LCount - 1 do
  begin
    LLeft := Vec3fToSimd(ALeft[i]);
    LRight := Vec3fToSimd(ARight[i]);
    AResults[i] := VecF32x3Dot(LLeft, LRight);
  end;

  Result := LCount;
end;

{ BatchNormalizeSimd4f }
function BatchNormalizeSimd4f(var AVectors: array of TVec4f): SizeInt;
var
  i, LCount: SizeInt;
  LV: TVecF32x4;
begin
  LCount := Length(AVectors);

  for i := 0 to LCount - 1 do
  begin
    LV := Vec4fToSimd(AVectors[i]);
    LV := VecF32x4Normalize(LV);
    VecF32x4Store(@AVectors[i].Data[0], LV);
  end;

  Result := LCount;
end;

{ BatchNormalizeSimd3f (in-place) }
function BatchNormalizeSimd3f(var AVectors: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LV: TVecF32x4;
begin
  LCount := Length(AVectors);

  for i := 0 to LCount - 1 do
  begin
    LV := Vec3fToSimd(AVectors[i]);
    LV := VecF32x3Normalize(LV);
    AVectors[i] := SimdToVec3f(LV);
  end;

  Result := LCount;
end;

{ BatchNormalizeSimd3f (with output) }
function BatchNormalizeSimd3f(const ASource: array of TVec3f;
                              var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LV: TVecF32x4;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));

  for i := 0 to LCount - 1 do
  begin
    LV := Vec3fToSimd(ASource[i]);
    LV := VecF32x3Normalize(LV);
    ADest[i] := SimdToVec3f(LV);
  end;

  Result := LCount;
end;

{ BatchTransformSimd4f }
function BatchTransformSimd4f(const AMatrix: TMat4f;
                              const ASource: array of TVec3f;
                              var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LMat0, LMat1, LMat2, LMat3: TVecF32x4;
  LSrc, LResult: TVecF32x4;
  LX, LY, LZ, LW: TVecF32x4;
begin
  LCount := ResolveEqualOrMin(Length(ASource), Length(ADest));

  { Load matrix columns into SIMD registers }
  LMat0 := VecF32x4Load(@AMatrix.Data[0, 0]);
  LMat1 := VecF32x4Load(@AMatrix.Data[1, 0]);
  LMat2 := VecF32x4Load(@AMatrix.Data[2, 0]);
  LMat3 := VecF32x4Load(@AMatrix.Data[3, 0]);

  for i := 0 to LCount - 1 do
  begin
    { Load source vector (x, y, z, 1.0) }
    LSrc := VecF32x4Make(ASource[i].X, ASource[i].Y, ASource[i].Z, 1.0);

    { Matrix-vector multiply: result = x*col0 + y*col1 + z*col2 + w*col3 }
    LX := VecF32x4Splat(VecF32x4Extract(LSrc, 0));
    LY := VecF32x4Splat(VecF32x4Extract(LSrc, 1));
    LZ := VecF32x4Splat(VecF32x4Extract(LSrc, 2));
    LW := VecF32x4Splat(VecF32x4Extract(LSrc, 3));

    LResult := VecF32x4Mul(LMat0, LX);
    LResult := VecF32x4Fma(LMat1, LY, LResult);
    LResult := VecF32x4Fma(LMat2, LZ, LResult);
    LResult := VecF32x4Fma(LMat3, LW, LResult);

    { Store result (x, y, z) - ignore w }
    ADest[i] := SimdToVec3f(LResult);
  end;

  Result := LCount;
end;

{ BatchLerpSimd4f }
function BatchLerpSimd4f(const AStart, AEnd: array of TVec4f;
                         const AT: Single;
                         var ADest: array of TVec4f): SizeInt;
var
  i, LCount: SizeInt;
  LStart, LEnd, LT, LResult: TVecF32x4;
begin
  LCount := ResolveEqualOrMin3(Length(AStart), Length(AEnd), Length(ADest));

  LT := VecF32x4Splat(AT);

  for i := 0 to LCount - 1 do
  begin
    LStart := Vec4fToSimd(AStart[i]);
    LEnd := Vec4fToSimd(AEnd[i]);

    { Lerp: result = start + t * (end - start) }
    LResult := VecF32x4Sub(LEnd, LStart);
    LResult := VecF32x4Mul(LResult, LT);
    LResult := VecF32x4Add(LStart, LResult);

    VecF32x4Store(@ADest[i].Data[0], LResult);
  end;

  Result := LCount;
end;

{ BatchLerpSimd3f }
function BatchLerpSimd3f(const AStart, AEnd: array of TVec3f;
                         const AT: Single;
                         var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LStart, LEnd, LT, LResult: TVecF32x4;
begin
  LCount := ResolveEqualOrMin3(Length(AStart), Length(AEnd), Length(ADest));

  LT := VecF32x4Splat(AT);

  for i := 0 to LCount - 1 do
  begin
    LStart := Vec3fToSimd(AStart[i]);
    LEnd := Vec3fToSimd(AEnd[i]);

    { Lerp: result = start + t * (end - start) }
    LResult := VecF32x4Sub(LEnd, LStart);
    LResult := VecF32x4Mul(LResult, LT);
    LResult := VecF32x4Add(LStart, LResult);

    ADest[i] := SimdToVec3f(LResult);
  end;

  Result := LCount;
end;

{ BatchClampSimd4f }
function BatchClampSimd4f(const AVectors: array of TVec4f;
                          const AMin, AMax: TVec4f;
                          var ADest: array of TVec4f): SizeInt;
var
  i, LCount: SizeInt;
  LV, LMin, LMax: TVecF32x4;
begin
  LCount := ResolveEqualOrMin(Length(AVectors), Length(ADest));

  LMin := Vec4fToSimd(AMin);
  LMax := Vec4fToSimd(AMax);

  for i := 0 to LCount - 1 do
  begin
    LV := Vec4fToSimd(AVectors[i]);
    LV := VecF32x4Clamp(LV, LMin, LMax);
    VecF32x4Store(@ADest[i].Data[0], LV);
  end;

  Result := LCount;
end;

{ BatchClampSimd3f }
function BatchClampSimd3f(const AVectors: array of TVec3f;
                          const AMin, AMax: TVec3f;
                          var ADest: array of TVec3f): SizeInt;
var
  i, LCount: SizeInt;
  LV, LMin, LMax: TVecF32x4;
begin
  LCount := ResolveEqualOrMin(Length(AVectors), Length(ADest));

  LMin := Vec3fToSimd(AMin);
  LMax := Vec3fToSimd(AMax);

  for i := 0 to LCount - 1 do
  begin
    LV := Vec3fToSimd(AVectors[i]);
    LV := VecF32x4Clamp(LV, LMin, LMax);
    ADest[i] := SimdToVec3f(LV);
  end;

  Result := LCount;
end;

end.
