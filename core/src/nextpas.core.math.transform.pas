{
  nextpas.core.math.transform.pas
  Transform builders: Ortho, Perspective, LookAt, Translate, Scale, Rotate
}
unit nextpas.core.math.transform;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base;

{ === Projection Matrices === }

function Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f;
function Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d;
function Perspective(AFOV, AAspect, ANear, AFar: Single): TMat4f;
function Perspective(AFOV, AAspect, ANear, AFar: Double): TMat4d;

{ === View Matrices === }

function LookAt(AEye, ATarget, AUp: TVec3f): TMat4f;
function LookAt(AEye, ATarget, AUp: TVec3d): TMat4d;

{ === Transform Builders === }

function Translate(ATranslation: TVec3f): TMat4f;
function Translate(ATranslation: TVec3d): TMat4d;
function Scale(AScale: TVec3f): TMat4f;
function Scale(AScale: TVec3d): TMat4d;
function RotateX(AAngle: Single): TMat4f;
function RotateX(AAngle: Double): TMat4d;
function RotateY(AAngle: Single): TMat4f;
function RotateY(AAngle: Double): TMat4d;
function RotateZ(AAngle: Single): TMat4f;
function RotateZ(AAngle: Double): TMat4d;

{ === 2D Transforms === }

function Camera2D(AOffset: TVec2f; ARotation, AScale: Single): TMat3f;
function Camera2D(AOffset: TVec2d; ARotation, AScale: Double): TMat3d;

implementation

uses
  nextpas.core.math.scalar;

{ === Projection Matrices === }

function Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar: Single): TMat4f;
begin
  Result := Mat4fZero;
  Result.Data[0, 0] := 2.0 / (ARight - ALeft);
  Result.Data[1, 1] := 2.0 / (ATop - ABottom);
  Result.Data[2, 2] := -2.0 / (AFar - ANear);
  Result.Data[3, 0] := -(ARight + ALeft) / (ARight - ALeft);
  Result.Data[3, 1] := -(ATop + ABottom) / (ATop - ABottom);
  Result.Data[3, 2] := -(AFar + ANear) / (AFar - ANear);
  Result.Data[3, 3] := 1.0;
end;

function Ortho(ALeft, ARight, ABottom, ATop, ANear, AFar: Double): TMat4d;
begin
  Result := Mat4dZero;
  Result.Data[0, 0] := 2.0 / (ARight - ALeft);
  Result.Data[1, 1] := 2.0 / (ATop - ABottom);
  Result.Data[2, 2] := -2.0 / (AFar - ANear);
  Result.Data[3, 0] := -(ARight + ALeft) / (ARight - ALeft);
  Result.Data[3, 1] := -(ATop + ABottom) / (ATop - ABottom);
  Result.Data[3, 2] := -(AFar + ANear) / (AFar - ANear);
  Result.Data[3, 3] := 1.0;
end;

function Perspective(AFOV, AAspect, ANear, AFar: Single): TMat4f;
var
  LTanHalfFOV: Single;
begin
  LTanHalfFOV := Sin(AFOV / 2.0) / Cos(AFOV / 2.0);
  Result := Mat4fZero;
  Result.Data[0, 0] := 1.0 / (AAspect * LTanHalfFOV);
  Result.Data[1, 1] := 1.0 / LTanHalfFOV;
  Result.Data[2, 2] := -(AFar + ANear) / (AFar - ANear);
  Result.Data[2, 3] := -1.0;
  Result.Data[3, 2] := -(2.0 * AFar * ANear) / (AFar - ANear);
end;

function Perspective(AFOV, AAspect, ANear, AFar: Double): TMat4d;
var
  LTanHalfFOV: Double;
begin
  LTanHalfFOV := Sin(AFOV / 2.0) / Cos(AFOV / 2.0);
  Result := Mat4dZero;
  Result.Data[0, 0] := 1.0 / (AAspect * LTanHalfFOV);
  Result.Data[1, 1] := 1.0 / LTanHalfFOV;
  Result.Data[2, 2] := -(AFar + ANear) / (AFar - ANear);
  Result.Data[2, 3] := -1.0;
  Result.Data[3, 2] := -(2.0 * AFar * ANear) / (AFar - ANear);
end;

{ === View Matrices === }

function LookAt(AEye, ATarget, AUp: TVec3f): TMat4f;
var
  LF, LS, LU: TVec3f;
begin
  LF := (ATarget - AEye).Normalize;
  LS := LF.Cross(AUp).Normalize;
  LU := LS.Cross(LF);

  Result := Mat4fIdentity;
  Result.Data[0, 0] := LS.X;
  Result.Data[1, 0] := LS.Y;
  Result.Data[2, 0] := LS.Z;
  Result.Data[0, 1] := LU.X;
  Result.Data[1, 1] := LU.Y;
  Result.Data[2, 1] := LU.Z;
  Result.Data[0, 2] := -LF.X;
  Result.Data[1, 2] := -LF.Y;
  Result.Data[2, 2] := -LF.Z;
  Result.Data[3, 0] := -LS.Dot(AEye);
  Result.Data[3, 1] := -LU.Dot(AEye);
  Result.Data[3, 2] := LF.Dot(AEye);
end;

function LookAt(AEye, ATarget, AUp: TVec3d): TMat4d;
var
  LF, LS, LU: TVec3d;
begin
  LF := (ATarget - AEye).Normalize;
  LS := LF.Cross(AUp).Normalize;
  LU := LS.Cross(LF);

  Result := Mat4dIdentity;
  Result.Data[0, 0] := LS.X;
  Result.Data[1, 0] := LS.Y;
  Result.Data[2, 0] := LS.Z;
  Result.Data[0, 1] := LU.X;
  Result.Data[1, 1] := LU.Y;
  Result.Data[2, 1] := LU.Z;
  Result.Data[0, 2] := -LF.X;
  Result.Data[1, 2] := -LF.Y;
  Result.Data[2, 2] := -LF.Z;
  Result.Data[3, 0] := -LS.Dot(AEye);
  Result.Data[3, 1] := -LU.Dot(AEye);
  Result.Data[3, 2] := LF.Dot(AEye);
end;

{ === Transform Builders === }

function Translate(ATranslation: TVec3f): TMat4f;
begin
  Result := Mat4fIdentity;
  Result.Data[3, 0] := ATranslation.X;
  Result.Data[3, 1] := ATranslation.Y;
  Result.Data[3, 2] := ATranslation.Z;
end;

function Translate(ATranslation: TVec3d): TMat4d;
begin
  Result := Mat4dIdentity;
  Result.Data[3, 0] := ATranslation.X;
  Result.Data[3, 1] := ATranslation.Y;
  Result.Data[3, 2] := ATranslation.Z;
end;

function Scale(AScale: TVec3f): TMat4f;
begin
  Result := Mat4fZero;
  Result.Data[0, 0] := AScale.X;
  Result.Data[1, 1] := AScale.Y;
  Result.Data[2, 2] := AScale.Z;
  Result.Data[3, 3] := 1.0;
end;

function Scale(AScale: TVec3d): TMat4d;
begin
  Result := Mat4dZero;
  Result.Data[0, 0] := AScale.X;
  Result.Data[1, 1] := AScale.Y;
  Result.Data[2, 2] := AScale.Z;
  Result.Data[3, 3] := 1.0;
end;

function RotateX(AAngle: Single): TMat4f;
var
  LSin, LCos: Single;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4fIdentity;
  Result.Data[1, 1] := LCos;
  Result.Data[1, 2] := LSin;
  Result.Data[2, 1] := -LSin;
  Result.Data[2, 2] := LCos;
end;

function RotateX(AAngle: Double): TMat4d;
var
  LSin, LCos: Double;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4dIdentity;
  Result.Data[1, 1] := LCos;
  Result.Data[1, 2] := LSin;
  Result.Data[2, 1] := -LSin;
  Result.Data[2, 2] := LCos;
end;

function RotateY(AAngle: Single): TMat4f;
var
  LSin, LCos: Single;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4fIdentity;
  Result.Data[0, 0] := LCos;
  Result.Data[0, 2] := -LSin;
  Result.Data[2, 0] := LSin;
  Result.Data[2, 2] := LCos;
end;

function RotateY(AAngle: Double): TMat4d;
var
  LSin, LCos: Double;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4dIdentity;
  Result.Data[0, 0] := LCos;
  Result.Data[0, 2] := -LSin;
  Result.Data[2, 0] := LSin;
  Result.Data[2, 2] := LCos;
end;

function RotateZ(AAngle: Single): TMat4f;
var
  LSin, LCos: Single;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4fIdentity;
  Result.Data[0, 0] := LCos;
  Result.Data[0, 1] := LSin;
  Result.Data[1, 0] := -LSin;
  Result.Data[1, 1] := LCos;
end;

function RotateZ(AAngle: Double): TMat4d;
var
  LSin, LCos: Double;
begin
  LSin := Sin(AAngle);
  LCos := Cos(AAngle);
  Result := Mat4dIdentity;
  Result.Data[0, 0] := LCos;
  Result.Data[0, 1] := LSin;
  Result.Data[1, 0] := -LSin;
  Result.Data[1, 1] := LCos;
end;

{ === 2D Transforms === }

function Camera2D(AOffset: TVec2f; ARotation, AScale: Single): TMat3f;
var
  LSin, LCos: Single;
begin
  LSin := Sin(ARotation);
  LCos := Cos(ARotation);
  Result := Mat3fIdentity;
  // Scale
  Result.Data[0, 0] := AScale;
  Result.Data[1, 1] := AScale;
  // Rotation
  Result.Data[0, 0] := Result.Data[0, 0] * LCos;
  Result.Data[0, 1] := Result.Data[0, 1] * LSin;
  Result.Data[1, 0] := Result.Data[1, 0] * (-LSin);
  Result.Data[1, 1] := Result.Data[1, 1] * LCos;
  // Translation
  Result.Data[2, 0] := -AOffset.X;
  Result.Data[2, 1] := -AOffset.Y;
end;

function Camera2D(AOffset: TVec2d; ARotation, AScale: Double): TMat3d;
var
  LSin, LCos: Double;
begin
  LSin := Sin(ARotation);
  LCos := Cos(ARotation);
  Result := Mat3dIdentity;
  // Scale
  Result.Data[0, 0] := AScale;
  Result.Data[1, 1] := AScale;
  // Rotation
  Result.Data[0, 0] := Result.Data[0, 0] * LCos;
  Result.Data[0, 1] := Result.Data[0, 1] * LSin;
  Result.Data[1, 0] := Result.Data[1, 0] * (-LSin);
  Result.Data[1, 1] := Result.Data[1, 1] * LCos;
  // Translation
  Result.Data[2, 0] := -AOffset.X;
  Result.Data[2, 1] := -AOffset.Y;
end;

end.
