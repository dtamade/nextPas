unit nextpas.core.math.quat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.vec,
  nextpas.core.math.mat;

type
  TQuatf = packed record
  public
    type
      TIndex = 0..3;
    class function Create(const AX, AY, AZ, AW: Single): TQuatf; static; inline;
    class function Identity: TQuatf; static; inline;
    class operator * (const AA, AB: TQuatf): TQuatf; inline;
    class function FromAxisAngle(const AAxis: TVec3f; const AAngleRad: Single): TQuatf; static;
    class function Slerp(const AA, AB: TQuatf; const AT: Single): TQuatf; static;
    class function Nlerp(const AA, AB: TQuatf; const AT: Single): TQuatf; static;
    class function Equals(const AA, AB: TQuatf; const AEpsilon: Single): Boolean; static; inline;
    procedure ToAxisAngle(out AAxis: TVec3f; out AAngleRad: Single);
    function ToRotationMatrix: TMat3f;
    function Rotate(const AVector: TVec3f): TVec3f;
    function Conjugate: TQuatf; inline;
    function Normalize: TQuatf;
    var
      case Integer of
        0: (X, Y, Z, W: Single);
        1: (Data: array[TIndex] of Single);
  end;

  TQuatd = packed record
  public
    type
      TIndex = 0..3;
    class function Create(const AX, AY, AZ, AW: Double): TQuatd; static; inline;
    class function Identity: TQuatd; static; inline;
    class operator * (const AA, AB: TQuatd): TQuatd; inline;
    class function FromAxisAngle(const AAxis: TVec3d; const AAngleRad: Double): TQuatd; static;
    class function Slerp(const AA, AB: TQuatd; const AT: Double): TQuatd; static;
    class function Nlerp(const AA, AB: TQuatd; const AT: Double): TQuatd; static;
    class function Equals(const AA, AB: TQuatd; const AEpsilon: Double): Boolean; static; inline;
    procedure ToAxisAngle(out AAxis: TVec3d; out AAngleRad: Double);
    function ToRotationMatrix: TMat3d;
    function Rotate(const AVector: TVec3d): TVec3d;
    function Conjugate: TQuatd; inline;
    function Normalize: TQuatd;
    var
      case Integer of
        0: (X, Y, Z, W: Double);
        1: (Data: array[TIndex] of Double);
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

const
  SINGLE_QUAT_EPSILON: Single = 0.000001;
  DOUBLE_QUAT_EPSILON: Double = 0.000000000001;

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

function IsFinite(const AValue: TVec3f): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and IsFinite(AValue.Z);
end;

function IsFinite(const AValue: TVec3d): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and IsFinite(AValue.Z);
end;

procedure ValidateAxisAngleInputs(const AFunctionName: string; const AAxis: TVec3f;
  const AAngleRad: Single); overload; inline;
begin
  if not IsFinite(AAxis) then
    raise EArgumentError.Create(AFunctionName + ': AAxis must be finite');
  if not IsFinite(AAngleRad) then
    raise EArgumentError.Create(AFunctionName + ': AAngleRad must be finite');
end;

procedure ValidateAxisAngleInputs(const AFunctionName: string; const AAxis: TVec3d;
  const AAngleRad: Double); overload; inline;
begin
  if not IsFinite(AAxis) then
    raise EArgumentError.Create(AFunctionName + ': AAxis must be finite');
  if not IsFinite(AAngleRad) then
    raise EArgumentError.Create(AFunctionName + ': AAngleRad must be finite');
end;

procedure ValidateInterpolationFactorInputs(const AFunctionName: string;
  const AT: Single); overload; inline;
begin
  if not IsFinite(AT) then
    raise EArgumentError.Create(AFunctionName + ': AT must be finite');
end;

procedure ValidateInterpolationFactorInputs(const AFunctionName: string;
  const AT: Double); overload; inline;
begin
  if not IsFinite(AT) then
    raise EArgumentError.Create(AFunctionName + ': AT must be finite');
end;

function QuatLengthSqr(const AX, AY, AZ, AW: Single): Single; inline;
begin
  Result := AX * AX + AY * AY + AZ * AZ + AW * AW;
end;

function QuatLengthSqr(const AX, AY, AZ, AW: Double): Double; inline;
begin
  Result := AX * AX + AY * AY + AZ * AZ + AW * AW;
end;

function QuatDot(const AA, AB: TQuatf): Single; inline;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z + AA.W * AB.W;
end;

function QuatDot(const AA, AB: TQuatd): Double; inline;
begin
  Result := AA.X * AB.X + AA.Y * AB.Y + AA.Z * AB.Z + AA.W * AB.W;
end;

function NegateQuat(const AValue: TQuatf): TQuatf; inline;
begin
  Result := TQuatf.Create(-AValue.X, -AValue.Y, -AValue.Z, -AValue.W);
end;

function NegateQuat(const AValue: TQuatd): TQuatd; inline;
begin
  Result := TQuatd.Create(-AValue.X, -AValue.Y, -AValue.Z, -AValue.W);
end;

function LerpQuat(const AA, AB: TQuatf; const AT: Single): TQuatf; inline;
begin
  Result := TQuatf.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT),
    nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT));
end;

function LerpQuat(const AA, AB: TQuatd; const AT: Double): TQuatd; inline;
begin
  Result := TQuatd.Create(
    nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT),
    nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT),
    nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT),
    nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT));
end;

{ TQuatf }

class function TQuatf.Create(const AX, AY, AZ, AW: Single): TQuatf;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
  Result.W := AW;
end;

class function TQuatf.Identity: TQuatf;
begin
  Result := TQuatf.Create(0.0, 0.0, 0.0, 1.0);
end;

class operator TQuatf.* (const AA, AB: TQuatf): TQuatf;
begin
  Result := TQuatf.Create(
    AA.W * AB.X + AA.X * AB.W + AA.Y * AB.Z - AA.Z * AB.Y,
    AA.W * AB.Y - AA.X * AB.Z + AA.Y * AB.W + AA.Z * AB.X,
    AA.W * AB.Z + AA.X * AB.Y - AA.Y * AB.X + AA.Z * AB.W,
    AA.W * AB.W - AA.X * AB.X - AA.Y * AB.Y - AA.Z * AB.Z);
end;

class function TQuatf.FromAxisAngle(const AAxis: TVec3f; const AAngleRad: Single): TQuatf;
var
  Axis: TVec3f;
  HalfAngle: Single;
  SinHalfAngle: Single;
begin
  ValidateAxisAngleInputs('TQuatf.FromAxisAngle', AAxis, AAngleRad);
  Axis := AAxis.Normalize;
  if TVec3f.Equals(Axis, TVec3f.Zero, Single(0.0)) then
    Exit(Identity);

  HalfAngle := AAngleRad * 0.5;
  SinHalfAngle := nextpas.core.math.trig.Sin(HalfAngle);
  Result := TQuatf.Create(
    Axis.X * SinHalfAngle,
    Axis.Y * SinHalfAngle,
    Axis.Z * SinHalfAngle,
    nextpas.core.math.trig.Cos(HalfAngle));
end;

class function TQuatf.Slerp(const AA, AB: TQuatf; const AT: Single): TQuatf;
var
  StartQuat: TQuatf;
  EndQuat: TQuatf;
  CosTheta: Single;
  Theta: Single;
  SinTheta: Single;
  WeightA: Single;
  WeightB: Single;
begin
  ValidateInterpolationFactorInputs('TQuatf.Slerp', AT);
  StartQuat := AA.Normalize;
  EndQuat := AB.Normalize;
  CosTheta := QuatDot(StartQuat, EndQuat);
  if CosTheta < 0.0 then
  begin
    EndQuat := NegateQuat(EndQuat);
    CosTheta := -CosTheta;
  end;

  CosTheta := nextpas.core.math.scalar.Clamp(CosTheta, Single(-1.0), Single(1.0));
  Theta := nextpas.core.math.trig.ArcCos(CosTheta);
  SinTheta := nextpas.core.math.trig.Sin(Theta);

  if nextpas.core.math.scalar.Abs(SinTheta) > SINGLE_QUAT_EPSILON then
  begin
    WeightA := nextpas.core.math.trig.Sin((1.0 - AT) * Theta) / SinTheta;
    WeightB := nextpas.core.math.trig.Sin(AT * Theta) / SinTheta;
    Result := TQuatf.Create(
      StartQuat.X * WeightA + EndQuat.X * WeightB,
      StartQuat.Y * WeightA + EndQuat.Y * WeightB,
      StartQuat.Z * WeightA + EndQuat.Z * WeightB,
      StartQuat.W * WeightA + EndQuat.W * WeightB).Normalize;
  end else
    Result := Nlerp(StartQuat, EndQuat, AT);
end;

class function TQuatf.Nlerp(const AA, AB: TQuatf; const AT: Single): TQuatf;
var
  StartQuat: TQuatf;
  EndQuat: TQuatf;
begin
  ValidateInterpolationFactorInputs('TQuatf.Nlerp', AT);
  StartQuat := AA.Normalize;
  EndQuat := AB.Normalize;
  if QuatDot(StartQuat, EndQuat) < 0.0 then
    EndQuat := NegateQuat(EndQuat);
  Result := LerpQuat(StartQuat, EndQuat, AT).Normalize;
end;

class function TQuatf.Equals(const AA, AB: TQuatf; const AEpsilon: Single): Boolean;
begin
  Result := (AEpsilon >= 0.0) and
    nextpas.core.math.scalar.FloatEquals(AA.X, AB.X, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.Y, AB.Y, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.Z, AB.Z, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.W, AB.W, AEpsilon);
end;

procedure TQuatf.ToAxisAngle(out AAxis: TVec3f; out AAngleRad: Single);
var
  Q: TQuatf;
  HalfAngle: Single;
  SinHalfAngle: Single;
begin
  Q := Normalize;
  HalfAngle := nextpas.core.math.trig.ArcCos(
    nextpas.core.math.scalar.Clamp(Q.W, Single(-1.0), Single(1.0)));
  SinHalfAngle := nextpas.core.math.trig.Sin(HalfAngle);
  AAngleRad := HalfAngle * 2.0;

  if nextpas.core.math.scalar.Abs(SinHalfAngle) <= SINGLE_QUAT_EPSILON then
    AAxis := TVec3f.Create(0.0, 0.0, 1.0)
  else
    AAxis := TVec3f.Create(Q.X / SinHalfAngle, Q.Y / SinHalfAngle, Q.Z / SinHalfAngle);
end;

function TQuatf.ToRotationMatrix: TMat3f;
var
  Q: TQuatf;
  XX: Single;
  YY: Single;
  ZZ: Single;
begin
  Q := Normalize;
  XX := Q.X * Q.X;
  YY := Q.Y * Q.Y;
  ZZ := Q.Z * Q.Z;

  Result := TMat3f.Identity;
  Result[0, 0] := 1.0 - 2.0 * (YY + ZZ);
  Result[1, 0] := 2.0 * (Q.X * Q.Y - Q.W * Q.Z);
  Result[2, 0] := 2.0 * (Q.X * Q.Z + Q.W * Q.Y);
  Result[0, 1] := 2.0 * (Q.X * Q.Y + Q.W * Q.Z);
  Result[1, 1] := 1.0 - 2.0 * (XX + ZZ);
  Result[2, 1] := 2.0 * (Q.Y * Q.Z - Q.W * Q.X);
  Result[0, 2] := 2.0 * (Q.X * Q.Z - Q.W * Q.Y);
  Result[1, 2] := 2.0 * (Q.Y * Q.Z + Q.W * Q.X);
  Result[2, 2] := 1.0 - 2.0 * (XX + YY);
end;

function TQuatf.Rotate(const AVector: TVec3f): TVec3f;
begin
  Result := ToRotationMatrix * AVector;
end;

function TQuatf.Conjugate: TQuatf;
begin
  Result := TQuatf.Create(-X, -Y, -Z, W);
end;

function TQuatf.Normalize: TQuatf;
var
  LengthSqr: Single;
  InvLength: Single;
begin
  LengthSqr := QuatLengthSqr(X, Y, Z, W);
  if LengthSqr = 0.0 then
    Exit(Identity);
  InvLength := 1.0 / nextpas.core.math.trig.Sqrt(LengthSqr);
  Result := TQuatf.Create(X * InvLength, Y * InvLength, Z * InvLength, W * InvLength);
end;

{ TQuatd }

class function TQuatd.Create(const AX, AY, AZ, AW: Double): TQuatd;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
  Result.W := AW;
end;

class function TQuatd.Identity: TQuatd;
begin
  Result := TQuatd.Create(0.0, 0.0, 0.0, 1.0);
end;

class operator TQuatd.* (const AA, AB: TQuatd): TQuatd;
begin
  Result := TQuatd.Create(
    AA.W * AB.X + AA.X * AB.W + AA.Y * AB.Z - AA.Z * AB.Y,
    AA.W * AB.Y - AA.X * AB.Z + AA.Y * AB.W + AA.Z * AB.X,
    AA.W * AB.Z + AA.X * AB.Y - AA.Y * AB.X + AA.Z * AB.W,
    AA.W * AB.W - AA.X * AB.X - AA.Y * AB.Y - AA.Z * AB.Z);
end;

class function TQuatd.FromAxisAngle(const AAxis: TVec3d; const AAngleRad: Double): TQuatd;
var
  Axis: TVec3d;
  HalfAngle: Double;
  SinHalfAngle: Double;
begin
  ValidateAxisAngleInputs('TQuatd.FromAxisAngle', AAxis, AAngleRad);
  Axis := AAxis.Normalize;
  if TVec3d.Equals(Axis, TVec3d.Zero, 0.0) then
    Exit(Identity);

  HalfAngle := AAngleRad * 0.5;
  SinHalfAngle := nextpas.core.math.trig.Sin(HalfAngle);
  Result := TQuatd.Create(
    Axis.X * SinHalfAngle,
    Axis.Y * SinHalfAngle,
    Axis.Z * SinHalfAngle,
    nextpas.core.math.trig.Cos(HalfAngle));
end;

class function TQuatd.Slerp(const AA, AB: TQuatd; const AT: Double): TQuatd;
var
  StartQuat: TQuatd;
  EndQuat: TQuatd;
  CosTheta: Double;
  Theta: Double;
  SinTheta: Double;
  WeightA: Double;
  WeightB: Double;
begin
  ValidateInterpolationFactorInputs('TQuatd.Slerp', AT);
  StartQuat := AA.Normalize;
  EndQuat := AB.Normalize;
  CosTheta := QuatDot(StartQuat, EndQuat);
  if CosTheta < 0.0 then
  begin
    EndQuat := NegateQuat(EndQuat);
    CosTheta := -CosTheta;
  end;

  CosTheta := nextpas.core.math.scalar.Clamp(CosTheta, Double(-1.0), Double(1.0));
  Theta := nextpas.core.math.trig.ArcCos(CosTheta);
  SinTheta := nextpas.core.math.trig.Sin(Theta);

  if nextpas.core.math.scalar.Abs(SinTheta) > DOUBLE_QUAT_EPSILON then
  begin
    WeightA := nextpas.core.math.trig.Sin((1.0 - AT) * Theta) / SinTheta;
    WeightB := nextpas.core.math.trig.Sin(AT * Theta) / SinTheta;
    Result := TQuatd.Create(
      StartQuat.X * WeightA + EndQuat.X * WeightB,
      StartQuat.Y * WeightA + EndQuat.Y * WeightB,
      StartQuat.Z * WeightA + EndQuat.Z * WeightB,
      StartQuat.W * WeightA + EndQuat.W * WeightB).Normalize;
  end else
    Result := Nlerp(StartQuat, EndQuat, AT);
end;

class function TQuatd.Nlerp(const AA, AB: TQuatd; const AT: Double): TQuatd;
var
  StartQuat: TQuatd;
  EndQuat: TQuatd;
begin
  ValidateInterpolationFactorInputs('TQuatd.Nlerp', AT);
  StartQuat := AA.Normalize;
  EndQuat := AB.Normalize;
  if QuatDot(StartQuat, EndQuat) < 0.0 then
    EndQuat := NegateQuat(EndQuat);
  Result := LerpQuat(StartQuat, EndQuat, AT).Normalize;
end;

class function TQuatd.Equals(const AA, AB: TQuatd; const AEpsilon: Double): Boolean;
begin
  Result := (AEpsilon >= 0.0) and
    nextpas.core.math.scalar.FloatEquals(AA.X, AB.X, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.Y, AB.Y, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.Z, AB.Z, AEpsilon) and
    nextpas.core.math.scalar.FloatEquals(AA.W, AB.W, AEpsilon);
end;

procedure TQuatd.ToAxisAngle(out AAxis: TVec3d; out AAngleRad: Double);
var
  Q: TQuatd;
  HalfAngle: Double;
  SinHalfAngle: Double;
begin
  Q := Normalize;
  HalfAngle := nextpas.core.math.trig.ArcCos(
    nextpas.core.math.scalar.Clamp(Q.W, Double(-1.0), Double(1.0)));
  SinHalfAngle := nextpas.core.math.trig.Sin(HalfAngle);
  AAngleRad := HalfAngle * 2.0;

  if nextpas.core.math.scalar.Abs(SinHalfAngle) <= DOUBLE_QUAT_EPSILON then
    AAxis := TVec3d.Create(0.0, 0.0, 1.0)
  else
    AAxis := TVec3d.Create(Q.X / SinHalfAngle, Q.Y / SinHalfAngle, Q.Z / SinHalfAngle);
end;

function TQuatd.ToRotationMatrix: TMat3d;
var
  Q: TQuatd;
  XX: Double;
  YY: Double;
  ZZ: Double;
begin
  Q := Normalize;
  XX := Q.X * Q.X;
  YY := Q.Y * Q.Y;
  ZZ := Q.Z * Q.Z;

  Result := TMat3d.Identity;
  Result[0, 0] := 1.0 - 2.0 * (YY + ZZ);
  Result[1, 0] := 2.0 * (Q.X * Q.Y - Q.W * Q.Z);
  Result[2, 0] := 2.0 * (Q.X * Q.Z + Q.W * Q.Y);
  Result[0, 1] := 2.0 * (Q.X * Q.Y + Q.W * Q.Z);
  Result[1, 1] := 1.0 - 2.0 * (XX + ZZ);
  Result[2, 1] := 2.0 * (Q.Y * Q.Z - Q.W * Q.X);
  Result[0, 2] := 2.0 * (Q.X * Q.Z - Q.W * Q.Y);
  Result[1, 2] := 2.0 * (Q.Y * Q.Z + Q.W * Q.X);
  Result[2, 2] := 1.0 - 2.0 * (XX + YY);
end;

function TQuatd.Rotate(const AVector: TVec3d): TVec3d;
begin
  Result := ToRotationMatrix * AVector;
end;

function TQuatd.Conjugate: TQuatd;
begin
  Result := TQuatd.Create(-X, -Y, -Z, W);
end;

function TQuatd.Normalize: TQuatd;
var
  LengthSqr: Double;
  InvLength: Double;
begin
  LengthSqr := QuatLengthSqr(X, Y, Z, W);
  if LengthSqr = 0.0 then
    Exit(Identity);
  InvLength := 1.0 / nextpas.core.math.trig.Sqrt(LengthSqr);
  Result := TQuatd.Create(X * InvLength, Y * InvLength, Z * InvLength, W * InvLength);
end;

end.
