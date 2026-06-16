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

function Distance(constref A, B: TVec2f): Single; overload; inline;
function Distance(constref A, B: TVec2d): Double; overload; inline;
function Distance(constref A, B: TVec3f): Single; overload; inline;
function Distance(constref A, B: TVec3d): Double; overload; inline;
function Distance(constref A, B: TVec4f): Single; overload; inline;
function Distance(constref A, B: TVec4d): Double; overload; inline;

function Lerp(constref A, B: TVec2f; const AT: Single): TVec2f; overload; inline;
function Lerp(constref A, B: TVec2d; const AT: Double): TVec2d; overload; inline;
function Lerp(constref A, B: TVec3f; const AT: Single): TVec3f; overload; inline;
function Lerp(constref A, B: TVec3d; const AT: Double): TVec3d; overload; inline;
function Lerp(constref A, B: TVec4f; const AT: Single): TVec4f; overload; inline;
function Lerp(constref A, B: TVec4d; const AT: Double): TVec4d; overload; inline;

function Reflect(constref AIncident, ANormal: TVec2f): TVec2f; overload; inline;
function Reflect(constref AIncident, ANormal: TVec2d): TVec2d; overload; inline;
function Reflect(constref AIncident, ANormal: TVec3f): TVec3f; overload; inline;
function Reflect(constref AIncident, ANormal: TVec3d): TVec3d; overload; inline;
function Reflect(constref AIncident, ANormal: TVec4f): TVec4f; overload; inline;
function Reflect(constref AIncident, ANormal: TVec4d): TVec4d; overload; inline;

function Project(constref A, B: TVec2f): TVec2f; overload; inline;
function Project(constref A, B: TVec2d): TVec2d; overload; inline;
function Project(constref A, B: TVec3f): TVec3f; overload; inline;
function Project(constref A, B: TVec3d): TVec3d; overload; inline;
function Project(constref A, B: TVec4f): TVec4f; overload; inline;
function Project(constref A, B: TVec4d): TVec4d; overload; inline;

function AngleBetween(constref A, B: TVec2f): Single; overload; inline;
function AngleBetween(constref A, B: TVec2d): Double; overload; inline;
function AngleBetween(constref A, B: TVec3f): Single; overload; inline;
function AngleBetween(constref A, B: TVec3d): Double; overload; inline;
function AngleBetween(constref A, B: TVec4f): Single; overload; inline;
function AngleBetween(constref A, B: TVec4d): Double; overload; inline;

implementation

uses
  nextpas.core.math.trig;

{ Vec constructors }

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

{ Vec zero constructors }

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

{ Distance }

function Distance(constref A, B: TVec2f): Single;
begin
  Result := (A - B).Length;
end;

function Distance(constref A, B: TVec2d): Double;
begin
  Result := (A - B).Length;
end;

function Distance(constref A, B: TVec3f): Single;
begin
  Result := (A - B).Length;
end;

function Distance(constref A, B: TVec3d): Double;
begin
  Result := (A - B).Length;
end;

function Distance(constref A, B: TVec4f): Single;
begin
  Result := (A - B).Length;
end;

function Distance(constref A, B: TVec4d): Double;
begin
  Result := (A - B).Length;
end;

{ Lerp }

function Lerp(constref A, B: TVec2f; const AT: Single): TVec2f;
begin
  Result := A + (B - A) * AT;
end;

function Lerp(constref A, B: TVec2d; const AT: Double): TVec2d;
begin
  Result := A + (B - A) * AT;
end;

function Lerp(constref A, B: TVec3f; const AT: Single): TVec3f;
begin
  Result := A + (B - A) * AT;
end;

function Lerp(constref A, B: TVec3d; const AT: Double): TVec3d;
begin
  Result := A + (B - A) * AT;
end;

function Lerp(constref A, B: TVec4f; const AT: Single): TVec4f;
begin
  Result := A + (B - A) * AT;
end;

function Lerp(constref A, B: TVec4d; const AT: Double): TVec4d;
begin
  Result := A + (B - A) * AT;
end;

{ Reflect }

function Reflect(constref AIncident, ANormal: TVec2f): TVec2f;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

function Reflect(constref AIncident, ANormal: TVec2d): TVec2d;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

function Reflect(constref AIncident, ANormal: TVec3f): TVec3f;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

function Reflect(constref AIncident, ANormal: TVec3d): TVec3d;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

function Reflect(constref AIncident, ANormal: TVec4f): TVec4f;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

function Reflect(constref AIncident, ANormal: TVec4d): TVec4d;
begin
  Result := AIncident - 2.0 * AIncident.Dot(ANormal) * ANormal;
end;

{ Project }

function Project(constref A, B: TVec2f): TVec2f;
var
  LDotBB: Single;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec2fZero;
end;

function Project(constref A, B: TVec2d): TVec2d;
var
  LDotBB: Double;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec2dZero;
end;

function Project(constref A, B: TVec3f): TVec3f;
var
  LDotBB: Single;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec3fZero;
end;

function Project(constref A, B: TVec3d): TVec3d;
var
  LDotBB: Double;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec3dZero;
end;

function Project(constref A, B: TVec4f): TVec4f;
var
  LDotBB: Single;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec4fZero;
end;

function Project(constref A, B: TVec4d): TVec4d;
var
  LDotBB: Double;
begin
  LDotBB := B.Dot(B);
  if LDotBB > 0 then
    Result := B * (A.Dot(B) / LDotBB)
  else
    Result := Vec4dZero;
end;

{ AngleBetween }

function AngleBetween(constref A, B: TVec2f): Single;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

function AngleBetween(constref A, B: TVec2d): Double;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

function AngleBetween(constref A, B: TVec3f): Single;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

function AngleBetween(constref A, B: TVec3d): Double;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

function AngleBetween(constref A, B: TVec4f): Single;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

function AngleBetween(constref A, B: TVec4d): Double;
begin
  Result := ArcCos(A.Dot(B) / (A.Length * B.Length));
end;

end.
