unit nextpas.core.math.vec;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec.base;

function Vec2f(const AX, AY: Single): TVec2f; inline;
function Vec2d(const AX, AY: Double): TVec2d; inline;
function Vec3f(const AX, AY, AZ: Single): TVec3f; inline;
function Vec3d(const AX, AY, AZ: Double): TVec3d; inline;
function Vec4f(const AX, AY, AZ, AW: Single): TVec4f; inline;
function Vec4d(const AX, AY, AZ, AW: Double): TVec4d; inline;

function Vec2fZero: TVec2f; inline;
function Vec2dZero: TVec2d; inline;
function Vec3fZero: TVec3f; inline;
function Vec3dZero: TVec3d; inline;
function Vec4fZero: TVec4f; inline;
function Vec4dZero: TVec4d; inline;

implementation

function Vec2f(const AX, AY: Single): TVec2f;
begin
  Result := TVec2f.Create(AX, AY);
end;

function Vec2d(const AX, AY: Double): TVec2d;
begin
  Result := TVec2d.Create(AX, AY);
end;

function Vec3f(const AX, AY, AZ: Single): TVec3f;
begin
  Result := TVec3f.Create(AX, AY, AZ);
end;

function Vec3d(const AX, AY, AZ: Double): TVec3d;
begin
  Result := TVec3d.Create(AX, AY, AZ);
end;

function Vec4f(const AX, AY, AZ, AW: Single): TVec4f;
begin
  Result := TVec4f.Create(AX, AY, AZ, AW);
end;

function Vec4d(const AX, AY, AZ, AW: Double): TVec4d;
begin
  Result := TVec4d.Create(AX, AY, AZ, AW);
end;

function Vec2fZero: TVec2f;
begin
  Result := nextpas.core.math.vec.base.Vec2fZero;
end;

function Vec2dZero: TVec2d;
begin
  Result := nextpas.core.math.vec.base.Vec2dZero;
end;

function Vec3fZero: TVec3f;
begin
  Result := nextpas.core.math.vec.base.Vec3fZero;
end;

function Vec3dZero: TVec3d;
begin
  Result := nextpas.core.math.vec.base.Vec3dZero;
end;

function Vec4fZero: TVec4f;
begin
  Result := nextpas.core.math.vec.base.Vec4fZero;
end;

function Vec4dZero: TVec4d;
begin
  Result := nextpas.core.math.vec.base.Vec4dZero;
end;

end.
