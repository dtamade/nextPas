{
  nextpas.core.math.vec.compat

  fafafa.game Vectors.pas compatibility layer.
  Maps fafafa type names (TVector2/TVector3/...) to nextpas canonical
  types (TVec2f/TVec3f/...) and provides legacy Vector2/Vector3/Vector4
  constructor functions.

  MEMORY LAYOUT COMPATIBILITY:
  - Vec types: XY(XY)/XYZW — layout matches, safe to alias
  - Mat types: 2D array storage matches, BUT access semantics differ:
    fafafa uses [Column, Row] while nextpas uses [Row, Column].
    Code migrating from fafafa must transpose index order.
  - Quat types: FX,FY,FZ,FW field order matches fafafa's
    (Vector:XYZ + Real:W) layout.

  NEW CODE SHOULD USE nextpas.core.math.vec DIRECTLY.
}
unit nextpas.core.math.vec.compat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat.base,
  nextpas.core.math.quat.base;

type
  { Single-precision vector types (fafafa.game aliases) }
  TVector2 = TVec2f;
  PVector2 = ^TVector2;

  TVector3 = TVec3f;
  PVector3 = ^TVector3;

  TVector4 = TVec4f;
  PVector4 = ^TVector4;

  { Single-precision matrix types (fafafa.game aliases) }
  TMatrix3 = TMat3f;
  PMatrix3 = ^TMatrix3;

  TMatrix4 = TMat4f;
  PMatrix4 = ^TMatrix4;

  { Single-precision quaternion (fafafa.game alias) }
  TQuaternion = TQuatf;
  PQuaternion = ^TQuaternion;

  { Double-precision vector types (fafafa.game aliases) }
  TVector2Double = TVec2d;
  PVector2Double = ^TVector2Double;

  TVector3Double = TVec3d;
  PVector3Double = ^TVector3Double;

  TVector4Double = TVec4d;
  PVector4Double = ^TVector4Double;

  { Double-precision matrix types (fafafa.game aliases) }
  TMatrix3Double = TMat3d;
  PMatrix3Double = ^TMatrix3Double;

  TMatrix4Double = TMat4d;
  PMatrix4Double = ^TMatrix4Double;

  { Double-precision quaternion (fafafa.game alias) }
  TQuaternionDouble = TQuatd;
  PQuaternionDouble = ^TQuaternionDouble;

{ Legacy constructor functions — map fafafa.game calling convention }

{** Construct a TVector2 (alias for Vec2f) }
function Vector2(const AX, AY: Single): TVector2; inline;

{** Construct a TVector3 from components (alias for Vec3f) }
function Vector3(const AX, AY, AZ: Single): TVector3; overload; inline;
{** Construct a TVector3 from TVector2 + Z }
function Vector3(const AV: TVector2; const AZ: Single): TVector3; overload; inline;

{** Construct a TVector4 from components (alias for Vec4f) }
function Vector4(const AX, AY, AZ, AW: Single): TVector4; overload; inline;
{** Construct a TVector4 from TVector3 + W }
function Vector4(const AV: TVector3; const AW: Single): TVector4; overload; inline;
{** Construct a TVector4 from TVector2 + Z + W }
function Vector4(const AV: TVector2; const AZ, AW: Single): TVector4; overload; inline;

implementation

function Vector2(const AX, AY: Single): TVector2;
begin
  Result := TVec2f.Create(AX, AY);
end;

function Vector3(const AX, AY, AZ: Single): TVector3;
begin
  Result := TVec3f.Create(AX, AY, AZ);
end;

function Vector3(const AV: TVector2; const AZ: Single): TVector3;
begin
  Result := TVec3f.Create(AV.X, AV.Y, AZ);
end;

function Vector4(const AX, AY, AZ, AW: Single): TVector4;
begin
  Result := TVec4f.Create(AX, AY, AZ, AW);
end;

function Vector4(const AV: TVector3; const AW: Single): TVector4;
begin
  Result := TVec4f.Create(AV.X, AV.Y, AV.Z, AW);
end;

function Vector4(const AV: TVector2; const AZ, AW: Single): TVector4;
begin
  Result := TVec4f.Create(AV.X, AV.Y, AZ, AW);
end;

end.
