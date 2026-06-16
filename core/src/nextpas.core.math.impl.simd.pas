{
  nextpas.core.math.impl.simd.pas
  SIMD-accelerated implementations for math module hot paths.
  Internal implementation module — not part of public API.
}
unit nextpas.core.math.impl.simd;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd,
  nextpas.core.simd.base;

{ Vec4f SIMD operations }
function SimdVec4fDot(const AX, AY, AZ, AW, BX, BY, BZ, BW: Single): Single;
function SimdVec4fLength(const AX, AY, AZ, AW: Single): Single;
procedure SimdVec4fNormalize(const AX, AY, AZ, AW: Single; out OX, OY, OZ, OW: Single);

{ Vec3f SIMD operations }
function SimdVec3fDot(const AX, AY, AZ, BX, BY, BZ: Single): Single;
function SimdVec3fLength(const AX, AY, AZ: Single): Single;
procedure SimdVec3fNormalize(const AX, AY, AZ: Single; out OX, OY, OZ: Single);
procedure SimdVec3fCross(const AX, AY, AZ, BX, BY, BZ: Single; out OX, OY, OZ: Single);

{ Mat4f SIMD operations — row-major FData[0..3, 0..3] }

type
  PMat4fData = ^TMat4fData;
  TMat4fData = array[0..15] of Single;

procedure SimdMat4fMul(
  const AData, BData: PMat4fData;
  const CData: PMat4fData);
procedure SimdMat4fMulVec4f(
  const MData: PMat4fData;
  const VX, VY, VZ, VW: Single;
  out OX, OY, OZ, OW: Single);

{ Quatf SIMD operations }
procedure SimdQuatfMul(
  const AX, AY, AZ, AW, BX, BY, BZ, BW: Single;
  out OX, OY, OZ, OW: Single);

implementation

{ === Vec4f === }

function SimdVec4fDot(const AX, AY, AZ, AW, BX, BY, BZ, BW: Single): Single;
var
  LA, LB: TVecF32x4;
begin
  LA := VecF32x4Make(AX, AY, AZ, AW);
  LB := VecF32x4Make(BX, BY, BZ, BW);
  Result := VecF32x4Dot(LA, LB);
end;

function SimdVec4fLength(const AX, AY, AZ, AW: Single): Single;
var
  LV: TVecF32x4;
begin
  LV := VecF32x4Make(AX, AY, AZ, AW);
  Result := VecF32x4Length(LV);
end;

procedure SimdVec4fNormalize(const AX, AY, AZ, AW: Single; out OX, OY, OZ, OW: Single);
var
  LV, LR: TVecF32x4;
begin
  LV := VecF32x4Make(AX, AY, AZ, AW);
  LR := VecF32x4Normalize(LV);
  OX := LR.f[0];
  OY := LR.f[1];
  OZ := LR.f[2];
  OW := LR.f[3];
end;

{ === Vec3f === }

function SimdVec3fDot(const AX, AY, AZ, BX, BY, BZ: Single): Single;
var
  LA, LB: TVecF32x4;
begin
  LA := VecF32x4Make(AX, AY, AZ, 0.0);
  LB := VecF32x4Make(BX, BY, BZ, 0.0);
  Result := VecF32x3Dot(LA, LB);
end;

function SimdVec3fLength(const AX, AY, AZ: Single): Single;
var
  LV: TVecF32x4;
begin
  LV := VecF32x4Make(AX, AY, AZ, 0.0);
  Result := VecF32x3Length(LV);
end;

procedure SimdVec3fNormalize(const AX, AY, AZ: Single; out OX, OY, OZ: Single);
var
  LV, LR: TVecF32x4;
begin
  LV := VecF32x4Make(AX, AY, AZ, 0.0);
  LR := VecF32x3Normalize(LV);
  OX := LR.f[0];
  OY := LR.f[1];
  OZ := LR.f[2];
end;

procedure SimdVec3fCross(const AX, AY, AZ, BX, BY, BZ: Single; out OX, OY, OZ: Single);
var
  LA, LB, LR: TVecF32x4;
begin
  LA := VecF32x4Make(AX, AY, AZ, 0.0);
  LB := VecF32x4Make(BX, BY, BZ, 0.0);
  LR := VecF32x3Cross(LA, LB);
  OX := LR.f[0];
  OY := LR.f[1];
  OZ := LR.f[2];
end;

{ === Mat4f === }
{ Column-major: Data[Row, Col], stored row-major in memory as Data[0..3, 0..3]
  Memory layout: [R0C0, R0C1, R0C2, R0C3, R1C0, R1C1, ...]
  Each row is 4 contiguous Singles → loadable as TVecF32x4 }

procedure SimdMat4fMul(
  const AData, BData: PMat4fData;
  const CData: PMat4fData);
var
  LRowA, LColB: TVecF32x4;
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
  begin
    LRowA := VecF32x4Load(@AData^[LRow * 4]);
    for LCol := 0 to 3 do
    begin
      LColB := VecF32x4Make(
        BData^[LCol], BData^[4 + LCol], BData^[8 + LCol], BData^[12 + LCol]);
      CData^[LRow * 4 + LCol] := VecF32x4Dot(LRowA, LColB);
    end;
  end;
end;

procedure SimdMat4fMulVec4f(
  const MData: PMat4fData;
  const VX, VY, VZ, VW: Single;
  out OX, OY, OZ, OW: Single);
var
  LV, LRow: TVecF32x4;
begin
  LV := VecF32x4Make(VX, VY, VZ, VW);
  LRow := VecF32x4Load(@MData^[0]);
  OX := VecF32x4Dot(LRow, LV);
  LRow := VecF32x4Load(@MData^[4]);
  OY := VecF32x4Dot(LRow, LV);
  LRow := VecF32x4Load(@MData^[8]);
  OZ := VecF32x4Dot(LRow, LV);
  LRow := VecF32x4Load(@MData^[12]);
  OW := VecF32x4Dot(LRow, LV);
end;

{ === Quatf === }
{ Quaternion multiply: (a * b)
  x = a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y
  y = a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x
  z = a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w
  w = a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z }

procedure SimdQuatfMul(
  const AX, AY, AZ, AW, BX, BY, BZ, BW: Single;
  out OX, OY, OZ, OW: Single);
begin
  { Quaternion multiply — cross-term shuffling makes pure SIMD less efficient
    than scalar for single quaternion operations. Use scalar for clarity. }
  OX := AW * BX + AX * BW + AY * BZ - AZ * BY;
  OY := AW * BY - AX * BZ + AY * BW + AZ * BX;
  OZ := AW * BZ + AX * BY - AY * BX + AZ * BW;
  OW := AW * BW - AX * BX - AY * BY - AZ * BZ;
end;

end.
