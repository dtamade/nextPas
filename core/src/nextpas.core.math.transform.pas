unit nextpas.core.math.transform;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec,
  nextpas.core.math.mat;

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f; overload;
function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d; overload;
function Perspective(const AFovYRad, AAspect, ANear, AFar: Single): TMat4f; overload;
function Perspective(const AFovYRad, AAspect, ANear, AFar: Double): TMat4d; overload;
function LookAt(const AEye, ATarget, AUp: TVec3f): TMat4f; overload;
function LookAt(const AEye, ATarget, AUp: TVec3d): TMat4d; overload;
function Translate(const AX, AY, AZ: Single): TMat4f; overload;
function Translate(const AX, AY, AZ: Double): TMat4d; overload;
function Scale(const AX, AY, AZ: Single): TMat4f; overload;
function Scale(const AX, AY, AZ: Double): TMat4d; overload;
function RotateX(const ARadians: Single): TMat4f; overload;
function RotateX(const ARadians: Double): TMat4d; overload;
function RotateY(const ARadians: Single): TMat4f; overload;
function RotateY(const ARadians: Double): TMat4d; overload;
function RotateZ(const ARadians: Single): TMat4f; overload;
function RotateZ(const ARadians: Double): TMat4d; overload;
function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer): TMat4f; overload;
function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer): TMat4d; overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

function IsFinite(const AValue: Single): Boolean; overload; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

function IsFinite(const AValue: Double): Boolean; overload; inline;
begin
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and
    (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

procedure RequireFinite(const AValue: Single; const AMessage: string); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AMessage);
end;

procedure RequireFinite(const AValue: Double; const AMessage: string); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AMessage);
end;

procedure RequireFinite(const AValue: TVec3f; const AMessage: string); overload; inline;
begin
  if (not IsFinite(AValue.X)) or (not IsFinite(AValue.Y)) or (not IsFinite(AValue.Z)) then
    raise EArgumentError.Create(AMessage);
end;

procedure RequireFinite(const AValue: TVec3d; const AMessage: string); overload; inline;
begin
  if (not IsFinite(AValue.X)) or (not IsFinite(AValue.Y)) or (not IsFinite(AValue.Z)) then
    raise EArgumentError.Create(AMessage);
end;

procedure RequireNonZero(const AValue: Single; const AMessage: string); overload; inline;
begin
  if AValue = 0.0 then
    raise EArgumentError.Create(AMessage);
end;

procedure RequireNonZero(const AValue: Double; const AMessage: string); overload; inline;
begin
  if AValue = 0.0 then
    raise EArgumentError.Create(AMessage);
end;

procedure RequirePositive(const AValue: Single; const AMessage: string); overload; inline;
begin
  if AValue <= 0.0 then
    raise EArgumentError.Create(AMessage);
end;

procedure RequirePositive(const AValue: Double; const AMessage: string); overload; inline;
begin
  if AValue <= 0.0 then
    raise EArgumentError.Create(AMessage);
end;

procedure RequirePositive(const AValue: Integer; const AMessage: string); overload; inline;
begin
  if AValue <= 0 then
    raise EArgumentError.Create(AMessage);
end;

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f;
var
  Width: Single;
  Height: Single;
  Depth: Single;
begin
  RequireFinite(ALeft, 'Ortho: left must be finite');
  RequireFinite(ARight, 'Ortho: right must be finite');
  RequireFinite(ABottom, 'Ortho: bottom must be finite');
  RequireFinite(ATop, 'Ortho: top must be finite');
  RequireFinite(ANear, 'Ortho: near plane must be finite');
  RequireFinite(AFar, 'Ortho: far plane must be finite');
  Width := ARight - ALeft;
  Height := ATop - ABottom;
  Depth := AFar - ANear;
  RequireNonZero(Width, 'Ortho: width must not be zero');
  RequireNonZero(Height, 'Ortho: height must not be zero');
  RequireNonZero(Depth, 'Ortho: depth must not be zero');

  Result := TMat4f.Zero;
  Result[0, 0] := 2.0 / Width;
  Result[1, 1] := 2.0 / Height;
  Result[2, 2] := -2.0 / Depth;
  Result[3, 0] := -(ARight + ALeft) / Width;
  Result[3, 1] := -(ATop + ABottom) / Height;
  Result[3, 2] := -(AFar + ANear) / Depth;
  Result[3, 3] := 1.0;
end;

function Ortho(const ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d;
var
  Width: Double;
  Height: Double;
  Depth: Double;
begin
  RequireFinite(ALeft, 'Ortho: left must be finite');
  RequireFinite(ARight, 'Ortho: right must be finite');
  RequireFinite(ABottom, 'Ortho: bottom must be finite');
  RequireFinite(ATop, 'Ortho: top must be finite');
  RequireFinite(ANear, 'Ortho: near plane must be finite');
  RequireFinite(AFar, 'Ortho: far plane must be finite');
  Width := ARight - ALeft;
  Height := ATop - ABottom;
  Depth := AFar - ANear;
  RequireNonZero(Width, 'Ortho: width must not be zero');
  RequireNonZero(Height, 'Ortho: height must not be zero');
  RequireNonZero(Depth, 'Ortho: depth must not be zero');

  Result := TMat4d.Zero;
  Result[0, 0] := 2.0 / Width;
  Result[1, 1] := 2.0 / Height;
  Result[2, 2] := -2.0 / Depth;
  Result[3, 0] := -(ARight + ALeft) / Width;
  Result[3, 1] := -(ATop + ABottom) / Height;
  Result[3, 2] := -(AFar + ANear) / Depth;
  Result[3, 3] := 1.0;
end;

function Perspective(const AFovYRad, AAspect, ANear, AFar: Single): TMat4f;
var
  F: Single;
  Depth: Single;
begin
  RequireFinite(AFovYRad, 'Perspective: vertical FOV must be finite');
  RequireFinite(AAspect, 'Perspective: aspect must be finite');
  RequireFinite(ANear, 'Perspective: near plane must be finite');
  RequireFinite(AFar, 'Perspective: far plane must be finite');
  RequirePositive(AFovYRad, 'Perspective: vertical FOV must be positive');
  RequirePositive(AAspect, 'Perspective: aspect must be positive');
  RequirePositive(ANear, 'Perspective: near plane must be positive');
  if AFar <= ANear then
    raise EArgumentError.Create('Perspective: far plane must be greater than near plane');

  F := 1.0 / nextpas.core.math.trig.Tan(AFovYRad * 0.5);
  RequireNonZero(F, 'Perspective: vertical FOV is invalid');
  Depth := ANear - AFar;

  Result := TMat4f.Zero;
  Result[0, 0] := F / AAspect;
  Result[1, 1] := F;
  Result[2, 2] := (AFar + ANear) / Depth;
  Result[3, 2] := 2.0 * AFar * ANear / Depth;
  Result[2, 3] := -1.0;
end;

function Perspective(const AFovYRad, AAspect, ANear, AFar: Double): TMat4d;
var
  F: Double;
  Depth: Double;
begin
  RequireFinite(AFovYRad, 'Perspective: vertical FOV must be finite');
  RequireFinite(AAspect, 'Perspective: aspect must be finite');
  RequireFinite(ANear, 'Perspective: near plane must be finite');
  RequireFinite(AFar, 'Perspective: far plane must be finite');
  RequirePositive(AFovYRad, 'Perspective: vertical FOV must be positive');
  RequirePositive(AAspect, 'Perspective: aspect must be positive');
  RequirePositive(ANear, 'Perspective: near plane must be positive');
  if AFar <= ANear then
    raise EArgumentError.Create('Perspective: far plane must be greater than near plane');

  F := 1.0 / nextpas.core.math.trig.Tan(AFovYRad * 0.5);
  RequireNonZero(F, 'Perspective: vertical FOV is invalid');
  Depth := ANear - AFar;

  Result := TMat4d.Zero;
  Result[0, 0] := F / AAspect;
  Result[1, 1] := F;
  Result[2, 2] := (AFar + ANear) / Depth;
  Result[3, 2] := 2.0 * AFar * ANear / Depth;
  Result[2, 3] := -1.0;
end;

function LookAt(const AEye, ATarget, AUp: TVec3f): TMat4f;
var
  Forward: TVec3f;
  Right: TVec3f;
  RealUp: TVec3f;
begin
  RequireFinite(AEye, 'LookAt: eye must be finite');
  RequireFinite(ATarget, 'LookAt: target must be finite');
  RequireFinite(AUp, 'LookAt: up vector must be finite');
  Forward := (ATarget - AEye).Normalize;
  if TVec3f.Equals(Forward, TVec3f.Zero, Single(0.0)) then
    raise EArgumentError.Create('LookAt: eye and target must differ');

  Right := TVec3f.Cross(Forward, AUp).Normalize;
  if TVec3f.Equals(Right, TVec3f.Zero, Single(0.0)) then
    raise EArgumentError.Create('LookAt: up vector must not be parallel to forward');

  RealUp := TVec3f.Cross(Right, Forward);
  Result := TMat4f.Zero;
  Result[0, 0] := Right.X;
  Result[1, 0] := Right.Y;
  Result[2, 0] := Right.Z;
  Result[0, 1] := RealUp.X;
  Result[1, 1] := RealUp.Y;
  Result[2, 1] := RealUp.Z;
  Result[0, 2] := -Forward.X;
  Result[1, 2] := -Forward.Y;
  Result[2, 2] := -Forward.Z;
  Result[3, 0] := -TVec3f.Dot(Right, AEye);
  Result[3, 1] := -TVec3f.Dot(RealUp, AEye);
  Result[3, 2] := TVec3f.Dot(Forward, AEye);
  Result[3, 3] := 1.0;
end;

function LookAt(const AEye, ATarget, AUp: TVec3d): TMat4d;
var
  Forward: TVec3d;
  Right: TVec3d;
  RealUp: TVec3d;
begin
  RequireFinite(AEye, 'LookAt: eye must be finite');
  RequireFinite(ATarget, 'LookAt: target must be finite');
  RequireFinite(AUp, 'LookAt: up vector must be finite');
  Forward := (ATarget - AEye).Normalize;
  if TVec3d.Equals(Forward, TVec3d.Zero, 0.0) then
    raise EArgumentError.Create('LookAt: eye and target must differ');

  Right := TVec3d.Cross(Forward, AUp).Normalize;
  if TVec3d.Equals(Right, TVec3d.Zero, 0.0) then
    raise EArgumentError.Create('LookAt: up vector must not be parallel to forward');

  RealUp := TVec3d.Cross(Right, Forward);
  Result := TMat4d.Zero;
  Result[0, 0] := Right.X;
  Result[1, 0] := Right.Y;
  Result[2, 0] := Right.Z;
  Result[0, 1] := RealUp.X;
  Result[1, 1] := RealUp.Y;
  Result[2, 1] := RealUp.Z;
  Result[0, 2] := -Forward.X;
  Result[1, 2] := -Forward.Y;
  Result[2, 2] := -Forward.Z;
  Result[3, 0] := -TVec3d.Dot(Right, AEye);
  Result[3, 1] := -TVec3d.Dot(RealUp, AEye);
  Result[3, 2] := TVec3d.Dot(Forward, AEye);
  Result[3, 3] := 1.0;
end;

function Translate(const AX, AY, AZ: Single): TMat4f;
begin
  RequireFinite(AX, 'Translate: X must be finite');
  RequireFinite(AY, 'Translate: Y must be finite');
  RequireFinite(AZ, 'Translate: Z must be finite');
  Result := TMat4f.Identity;
  Result[3, 0] := AX;
  Result[3, 1] := AY;
  Result[3, 2] := AZ;
end;

function Translate(const AX, AY, AZ: Double): TMat4d;
begin
  RequireFinite(AX, 'Translate: X must be finite');
  RequireFinite(AY, 'Translate: Y must be finite');
  RequireFinite(AZ, 'Translate: Z must be finite');
  Result := TMat4d.Identity;
  Result[3, 0] := AX;
  Result[3, 1] := AY;
  Result[3, 2] := AZ;
end;

function Scale(const AX, AY, AZ: Single): TMat4f;
begin
  RequireFinite(AX, 'Scale: X must be finite');
  RequireFinite(AY, 'Scale: Y must be finite');
  RequireFinite(AZ, 'Scale: Z must be finite');
  Result := TMat4f.Identity;
  Result[0, 0] := AX;
  Result[1, 1] := AY;
  Result[2, 2] := AZ;
end;

function Scale(const AX, AY, AZ: Double): TMat4d;
begin
  RequireFinite(AX, 'Scale: X must be finite');
  RequireFinite(AY, 'Scale: Y must be finite');
  RequireFinite(AZ, 'Scale: Z must be finite');
  Result := TMat4d.Identity;
  Result[0, 0] := AX;
  Result[1, 1] := AY;
  Result[2, 2] := AZ;
end;

function RotateX(const ARadians: Single): TMat4f;
var
  C: Single;
  S: Single;
begin
  RequireFinite(ARadians, 'RotateX: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4f.Identity;
  Result[1, 1] := C;
  Result[2, 1] := -S;
  Result[1, 2] := S;
  Result[2, 2] := C;
end;

function RotateX(const ARadians: Double): TMat4d;
var
  C: Double;
  S: Double;
begin
  RequireFinite(ARadians, 'RotateX: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4d.Identity;
  Result[1, 1] := C;
  Result[2, 1] := -S;
  Result[1, 2] := S;
  Result[2, 2] := C;
end;

function RotateY(const ARadians: Single): TMat4f;
var
  C: Single;
  S: Single;
begin
  RequireFinite(ARadians, 'RotateY: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4f.Identity;
  Result[0, 0] := C;
  Result[2, 0] := S;
  Result[0, 2] := -S;
  Result[2, 2] := C;
end;

function RotateY(const ARadians: Double): TMat4d;
var
  C: Double;
  S: Double;
begin
  RequireFinite(ARadians, 'RotateY: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4d.Identity;
  Result[0, 0] := C;
  Result[2, 0] := S;
  Result[0, 2] := -S;
  Result[2, 2] := C;
end;

function RotateZ(const ARadians: Single): TMat4f;
var
  C: Single;
  S: Single;
begin
  RequireFinite(ARadians, 'RotateZ: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4f.Identity;
  Result[0, 0] := C;
  Result[1, 0] := -S;
  Result[0, 1] := S;
  Result[1, 1] := C;
end;

function RotateZ(const ARadians: Double): TMat4d;
var
  C: Double;
  S: Double;
begin
  RequireFinite(ARadians, 'RotateZ: radians must be finite');
  C := nextpas.core.math.trig.Cos(ARadians);
  S := nextpas.core.math.trig.Sin(ARadians);
  Result := TMat4d.Identity;
  Result[0, 0] := C;
  Result[1, 0] := -S;
  Result[0, 1] := S;
  Result[1, 1] := C;
end;

function Camera2D(const ACenterX, ACenterY, AZoom: Single;
  const AViewportWidth, AViewportHeight: Integer): TMat4f;
var
  HalfWidth: Single;
  HalfHeight: Single;
begin
  RequireFinite(ACenterX, 'Camera2D: center X must be finite');
  RequireFinite(ACenterY, 'Camera2D: center Y must be finite');
  RequireFinite(AZoom, 'Camera2D: zoom must be finite');
  RequirePositive(AZoom, 'Camera2D: zoom must be positive');
  RequirePositive(AViewportWidth, 'Camera2D: viewport width must be positive');
  RequirePositive(AViewportHeight, 'Camera2D: viewport height must be positive');

  HalfWidth := (AViewportWidth * 0.5) / AZoom;
  HalfHeight := (AViewportHeight * 0.5) / AZoom;
  Result := Ortho(
    ACenterX - HalfWidth, ACenterX + HalfWidth,
    ACenterY + HalfHeight, ACenterY - HalfHeight,
    -1000.0, 1000.0);
end;

function Camera2D(const ACenterX, ACenterY, AZoom: Double;
  const AViewportWidth, AViewportHeight: Integer): TMat4d;
var
  HalfWidth: Double;
  HalfHeight: Double;
begin
  RequireFinite(ACenterX, 'Camera2D: center X must be finite');
  RequireFinite(ACenterY, 'Camera2D: center Y must be finite');
  RequireFinite(AZoom, 'Camera2D: zoom must be finite');
  RequirePositive(AZoom, 'Camera2D: zoom must be positive');
  RequirePositive(AViewportWidth, 'Camera2D: viewport width must be positive');
  RequirePositive(AViewportHeight, 'Camera2D: viewport height must be positive');

  HalfWidth := (AViewportWidth * 0.5) / AZoom;
  HalfHeight := (AViewportHeight * 0.5) / AZoom;
  Result := Ortho(
    ACenterX - HalfWidth, ACenterX + HalfWidth,
    ACenterY + HalfHeight, ACenterY - HalfHeight,
    -1000.0, 1000.0);
end;

end.
