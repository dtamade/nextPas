unit nextpas.core.math.impl.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.vec;

function SimdVec4fAdd(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fSub(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fMulComponents(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fScale(const AValue: TVec4f; const AScalar: Single): TVec4f; inline;
function SimdVec4fDot(const AA, AB: TVec4f): Single; inline;
function SimdVec4fLength(const AValue: TVec4f): Single; inline;
function SimdVec3fDot(const AA, AB: TVec3f): Single; inline;
function SimdVec3fCross(const AA, AB: TVec3f): TVec3f; inline;
function SimdMat4fMulVec4f(const AMatrix: TMat4f; const AVector: TVec4f): TVec4f; inline;
function SimdQuatfRotate(const AQuat: TQuatf; const AVector: TVec3f): TVec3f; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.simd;

function Vec4fToSimd(const AValue: TVec4f): TVecF32x4; inline;
begin
  Result := VecF32x4Make(AValue.X, AValue.Y, AValue.Z, AValue.W);
end;

function Vec3fToSimd(const AValue: TVec3f): TVecF32x4; inline;
begin
  Result := VecF32x4Make(AValue.X, AValue.Y, AValue.Z, 0.0);
end;

function QuatfVectorToSimd(const AQuat: TQuatf): TVecF32x4; inline;
begin
  Result := VecF32x4Make(AQuat.X, AQuat.Y, AQuat.Z, 0.0);
end;

function Mat4fColumnToSimd(const AMatrix: TMat4f; const AColumn: TMat4f.TIndex): TVecF32x4; inline;
begin
  Result := VecF32x4Make(
    AMatrix.Data[AColumn, 0],
    AMatrix.Data[AColumn, 1],
    AMatrix.Data[AColumn, 2],
    AMatrix.Data[AColumn, 3]);
end;

function SimdToVec4f(const AValue: TVecF32x4): TVec4f; inline;
begin
  Result := TVec4f.Create(
    VecF32x4Extract(AValue, 0),
    VecF32x4Extract(AValue, 1),
    VecF32x4Extract(AValue, 2),
    VecF32x4Extract(AValue, 3));
end;

function SimdToVec3f(const AValue: TVecF32x4): TVec3f; inline;
begin
  Result := TVec3f.Create(
    VecF32x4Extract(AValue, 0),
    VecF32x4Extract(AValue, 1),
    VecF32x4Extract(AValue, 2));
end;

function SingleIsFinite(const AValue: Single): Boolean; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function QuatfIsFinite(const AValue: TQuatf): Boolean; inline;
begin
  Result := SingleIsFinite(AValue.X) and SingleIsFinite(AValue.Y) and
    SingleIsFinite(AValue.Z) and SingleIsFinite(AValue.W);
end;

function Vec3fIsFinite(const AValue: TVec3f): Boolean; inline;
begin
  Result := SingleIsFinite(AValue.X) and SingleIsFinite(AValue.Y) and
    SingleIsFinite(AValue.Z);
end;

function SimdVec4fAdd(const AA, AB: TVec4f): TVec4f;
begin
  Result := SimdToVec4f(VecF32x4Add(Vec4fToSimd(AA), Vec4fToSimd(AB)));
end;

function SimdVec4fSub(const AA, AB: TVec4f): TVec4f;
begin
  Result := SimdToVec4f(VecF32x4Sub(Vec4fToSimd(AA), Vec4fToSimd(AB)));
end;

function SimdVec4fMulComponents(const AA, AB: TVec4f): TVec4f;
begin
  Result := SimdToVec4f(VecF32x4Mul(Vec4fToSimd(AA), Vec4fToSimd(AB)));
end;

function SimdVec4fScale(const AValue: TVec4f; const AScalar: Single): TVec4f;
begin
  Result := SimdToVec4f(VecF32x4Mul(Vec4fToSimd(AValue), VecF32x4Splat(AScalar)));
end;

function SimdVec4fDot(const AA, AB: TVec4f): Single;
begin
  Result := TVec4f.Dot(AA, AB);
end;

function SimdVec4fLength(const AValue: TVec4f): Single;
begin
  Result := AValue.Length;
end;

function SimdVec3fDot(const AA, AB: TVec3f): Single;
begin
  Result := TVec3f.Dot(AA, AB);
end;

function SimdVec3fCross(const AA, AB: TVec3f): TVec3f;
begin
  Result := TVec3f.Cross(AA, AB);
end;

function SimdMat4fMulVec4f(const AMatrix: TMat4f; const AVector: TVec4f): TVec4f;
var
  LResult: TVecF32x4;
begin
  LResult := VecF32x4Mul(Mat4fColumnToSimd(AMatrix, 0), VecF32x4Splat(AVector.X));
  LResult := VecF32x4Add(LResult,
    VecF32x4Mul(Mat4fColumnToSimd(AMatrix, 1), VecF32x4Splat(AVector.Y)));
  LResult := VecF32x4Add(LResult,
    VecF32x4Mul(Mat4fColumnToSimd(AMatrix, 2), VecF32x4Splat(AVector.Z)));
  LResult := VecF32x4Add(LResult,
    VecF32x4Mul(Mat4fColumnToSimd(AMatrix, 3), VecF32x4Splat(AVector.W)));
  Result := SimdToVec4f(LResult);
end;

function SimdQuatfRotate(const AQuat: TQuatf; const AVector: TVec3f): TVec3f;
var
  LQuat: TQuatf;
  LQuatVec: TVecF32x4;
  LVector: TVecF32x4;
  LT: TVecF32x4;
  LResult: TVecF32x4;
begin
  if not QuatfIsFinite(AQuat) then
    raise EArgumentError.Create('TQuatf.Rotate: quaternion must be finite');
  if not Vec3fIsFinite(AVector) then
    raise EArgumentError.Create('TQuatf.Rotate: AVector must be finite');

  LQuat := AQuat.Normalize;
  LQuatVec := QuatfVectorToSimd(LQuat);
  LVector := Vec3fToSimd(AVector);
  LT := VecF32x4Mul(VecF32x3Cross(LQuatVec, LVector), VecF32x4Splat(2.0));
  LResult := VecF32x4Add(LVector, VecF32x4Mul(LT, VecF32x4Splat(LQuat.W)));
  LResult := VecF32x4Add(LResult, VecF32x3Cross(LQuatVec, LT));
  Result := SimdToVec3f(LResult);
end;

end.
