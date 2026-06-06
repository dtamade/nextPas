unit nextpas.core.math.impl.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec;

function SimdVec4fAdd(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fSub(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fMulComponents(const AA, AB: TVec4f): TVec4f; inline;
function SimdVec4fScale(const AValue: TVec4f; const AScalar: Single): TVec4f; inline;
function SimdVec4fDot(const AA, AB: TVec4f): Single; inline;
function SimdVec4fLength(const AValue: TVec4f): Single; inline;
function SimdVec3fDot(const AA, AB: TVec3f): Single; inline;
function SimdVec3fCross(const AA, AB: TVec3f): TVec3f; inline;

implementation

uses
  nextpas.core.simd;

function Vec4fToSimd(const AValue: TVec4f): TVecF32x4; inline;
begin
  Result := VecF32x4Make(AValue.X, AValue.Y, AValue.Z, AValue.W);
end;

function Vec3fToSimd(const AValue: TVec3f): TVecF32x4; inline;
begin
  Result := VecF32x4Make(AValue.X, AValue.Y, AValue.Z, 0.0);
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
  Result := VecF32x4Dot(Vec4fToSimd(AA), Vec4fToSimd(AB));
end;

function SimdVec4fLength(const AValue: TVec4f): Single;
begin
  Result := VecF32x4Length(Vec4fToSimd(AValue));
end;

function SimdVec3fDot(const AA, AB: TVec3f): Single;
begin
  Result := VecF32x3Dot(Vec3fToSimd(AA), Vec3fToSimd(AB));
end;

function SimdVec3fCross(const AA, AB: TVec3f): TVec3f;
begin
  Result := SimdToVec3f(VecF32x3Cross(Vec3fToSimd(AA), Vec3fToSimd(AB)));
end;

end.
