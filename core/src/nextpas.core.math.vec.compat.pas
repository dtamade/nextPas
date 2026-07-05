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
  { Single-precision vector types (fafafa.game aliases) — deprecated, use TVec2f/TVec3f/TVec4f }
  TVector2 = TVec2f deprecated 'Use TVec2f from nextpas.core.math.vec';
  PVector2 = ^TVector2 deprecated 'Use TVec2f from nextpas.core.math.vec';

  TVector3 = TVec3f deprecated 'Use TVec3f from nextpas.core.math.vec';
  PVector3 = ^TVector3 deprecated 'Use TVec3f from nextpas.core.math.vec';

  TVector4 = TVec4f deprecated 'Use TVec4f from nextpas.core.math.vec';
  PVector4 = ^TVector4 deprecated 'Use TVec4f from nextpas.core.math.vec';

  { Single-precision matrix types (fafafa.game aliases) — deprecated, use TMat3f/TMat4f }
  TMatrix3 = TMat3f deprecated 'Use TMat3f from nextpas.core.math.mat';
  PMatrix3 = ^TMatrix3 deprecated 'Use TMat3f from nextpas.core.math.mat';

  TMatrix4 = TMat4f deprecated 'Use TMat4f from nextpas.core.math.mat';
  PMatrix4 = ^TMatrix4 deprecated 'Use TMat4f from nextpas.core.math.mat';

  { Single-precision quaternion (fafafa.game alias) — deprecated, use TQuatf }
  TQuaternion = TQuatf deprecated 'Use TQuatf from nextpas.core.math.quat';
  PQuaternion = ^TQuaternion deprecated 'Use TQuatf from nextpas.core.math.quat';

  { Double-precision vector types (fafafa.game aliases) — deprecated, use TVec2d/TVec3d/TVec4d }
  TVector2Double = TVec2d deprecated 'Use TVec2d from nextpas.core.math.vec';
  PVector2Double = ^TVector2Double deprecated 'Use TVec2d from nextpas.core.math.vec';

  TVector3Double = TVec3d deprecated 'Use TVec3d from nextpas.core.math.vec';
  PVector3Double = ^TVector3Double deprecated 'Use TVec3d from nextpas.core.math.vec';

  TVector4Double = TVec4d deprecated 'Use TVec4d from nextpas.core.math.vec';
  PVector4Double = ^TVector4Double deprecated 'Use TVec4d from nextpas.core.math.vec';

  { Double-precision matrix types (fafafa.game aliases) — deprecated, use TMat3d/TMat4d }
  TMatrix3Double = TMat3d deprecated 'Use TMat3d from nextpas.core.math.mat';
  PMatrix3Double = ^TMatrix3Double deprecated 'Use TMat3d from nextpas.core.math.mat';

  TMatrix4Double = TMat4d deprecated 'Use TMat4d from nextpas.core.math.mat';
  PMatrix4Double = ^TMatrix4Double deprecated 'Use TMat4d from nextpas.core.math.mat';

  { Double-precision quaternion (fafafa.game alias) — deprecated, use TQuatd }
  TQuaternionDouble = TQuatd deprecated 'Use TQuatd from nextpas.core.math.quat';
  PQuaternionDouble = ^TQuaternionDouble deprecated 'Use TQuatd from nextpas.core.math.quat';

{ Legacy constructor functions — deprecated, use TVec2f.Create/TVec3f.Create/TVec4f.Create }

{** Construct a TVector2 (alias for Vec2f) — deprecated }
function Vector2(const AX, AY: Single): TVector2; inline; deprecated 'Use TVec2f.Create';

{** Construct a TVector3 from components (alias for Vec3f) — deprecated }
function Vector3(const AX, AY, AZ: Single): TVector3; overload; inline; deprecated 'Use TVec3f.Create';
{** Construct a TVector3 from TVector2 + Z — deprecated }
function Vector3(const AV: TVector2; const AZ: Single): TVector3; overload; inline; deprecated 'Use TVec3f.Create';

{** Construct a TVector4 from components (alias for Vec4f) — deprecated }
function Vector4(const AX, AY, AZ, AW: Single): TVector4; overload; inline; deprecated 'Use TVec4f.Create';
{** Construct a TVector4 from TVector3 + W — deprecated }
function Vector4(const AV: TVector3; const AW: Single): TVector4; overload; inline; deprecated 'Use TVec4f.Create';
{** Construct a TVector4 from TVector2 + Z + W — deprecated }
function Vector4(const AV: TVector2; const AZ, AW: Single): TVector4; overload; inline; deprecated 'Use TVec4f.Create';

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
