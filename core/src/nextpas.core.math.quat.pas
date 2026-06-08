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

function IsFinite(const AValue: TQuatf): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and
    IsFinite(AValue.Z) and IsFinite(AValue.W);
end;

function IsFinite(const AValue: TQuatd): Boolean; overload; inline;
begin
  Result := IsFinite(AValue.X) and IsFinite(AValue.Y) and
    IsFinite(AValue.Z) and IsFinite(AValue.W);
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

procedure ValidateQuaternionInput(const AFunctionName, AParamName: string;
  const AValue: TQuatf); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': ' + AParamName + ' must be finite');
end;

procedure ValidateQuaternionInput(const AFunctionName, AParamName: string;
  const AValue: TQuatd); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': ' + AParamName + ' must be finite');
end;

procedure ValidateVectorInput(const AFunctionName, AParamName: string;
  const AValue: TVec3f); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': ' + AParamName + ' must be finite');
end;

procedure ValidateVectorInput(const AFunctionName, AParamName: string;
  const AValue: TVec3d); overload; inline;
begin
  if not IsFinite(AValue) then
    raise EArgumentError.Create(AFunctionName + ': ' + AParamName + ' must be finite');
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

function ShouldNegateHalfTurnAxis(const AX, AY, AZ: Single): Boolean; overload; inline;
begin
  if AX < 0.0 then
    Exit(True);
  if AX > 0.0 then
    Exit(False);
  if AY < 0.0 then
    Exit(True);
  if AY > 0.0 then
    Exit(False);
  Result := AZ < 0.0;
end;

function ShouldNegateHalfTurnAxis(const AX, AY, AZ: Double): Boolean; overload; inline;
begin
  if AX < 0.0 then
    Exit(True);
  if AX > 0.0 then
    Exit(False);
  if AY < 0.0 then
    Exit(True);
  if AY > 0.0 then
    Exit(False);
  Result := AZ < 0.0;
end;

function CanonicalizeAxisAngleQuat(const AValue: TQuatf): TQuatf; overload; inline;
begin
  Result := AValue;
  if Result.W < 0.0 then
    Result := NegateQuat(Result);
  if nextpas.core.math.scalar.Abs(Result.W) <= SINGLE_QUAT_EPSILON then
  begin
    Result.W := 0.0;
    if ShouldNegateHalfTurnAxis(Result.X, Result.Y, Result.Z) then
      Result := NegateQuat(Result);
    Result.W := 0.0;
  end;
end;

function CanonicalizeAxisAngleQuat(const AValue: TQuatd): TQuatd; overload; inline;
begin
  Result := AValue;
  if Result.W < 0.0 then
    Result := NegateQuat(Result);
  if nextpas.core.math.scalar.Abs(Result.W) <= DOUBLE_QUAT_EPSILON then
  begin
    Result.W := 0.0;
    if ShouldNegateHalfTurnAxis(Result.X, Result.Y, Result.Z) then
      Result := NegateQuat(Result);
    Result.W := 0.0;
  end;
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

function NormalizeFiniteQuat(const AValue: TQuatf): TQuatf; overload; inline;
var
  LX: Single;
  LY: Single;
  LZ: Single;
  LW: Single;
  LMax: Single;
  LScaledX: Single;
  LScaledY: Single;
  LScaledZ: Single;
  LScaledW: Single;
  LScaledLength: Single;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LW := nextpas.core.math.scalar.Abs(AValue.W);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(TQuatf.Identity);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledW := AValue.W / LMax;
  LScaledLength := Single(System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW));
  Result := TQuatf.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength,
    LScaledW / LScaledLength);
end;

function NormalizeFiniteQuat(const AValue: TQuatd): TQuatd; overload; inline;
var
  LX: Double;
  LY: Double;
  LZ: Double;
  LW: Double;
  LMax: Double;
  LScaledX: Double;
  LScaledY: Double;
  LScaledZ: Double;
  LScaledW: Double;
  LScaledLength: Double;
begin
  LX := nextpas.core.math.scalar.Abs(AValue.X);
  LY := nextpas.core.math.scalar.Abs(AValue.Y);
  LZ := nextpas.core.math.scalar.Abs(AValue.Z);
  LW := nextpas.core.math.scalar.Abs(AValue.W);
  LMax := nextpas.core.math.scalar.Max(LX,
    nextpas.core.math.scalar.Max(LY, nextpas.core.math.scalar.Max(LZ, LW)));
  if LMax = 0.0 then
    Exit(TQuatd.Identity);
  LScaledX := AValue.X / LMax;
  LScaledY := AValue.Y / LMax;
  LScaledZ := AValue.Z / LMax;
  LScaledW := AValue.W / LMax;
  LScaledLength := System.Sqrt(
    LScaledX * LScaledX + LScaledY * LScaledY +
    LScaledZ * LScaledZ + LScaledW * LScaledW);
  Result := TQuatd.Create(
    LScaledX / LScaledLength,
    LScaledY / LScaledLength,
    LScaledZ / LScaledLength,
    LScaledW / LScaledLength);
end;

function RotationMatrixFromFiniteQuat(const AValue: TQuatf): TMat3f; overload; inline;
var
  Q: TQuatf;
  XX: Single;
  YY: Single;
  ZZ: Single;
begin
  Q := NormalizeFiniteQuat(AValue);
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

function RotationMatrixFromFiniteQuat(const AValue: TQuatd): TMat3d; overload; inline;
var
  Q: TQuatd;
  XX: Double;
  YY: Double;
  ZZ: Double;
begin
  Q := NormalizeFiniteQuat(AValue);
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
  ValidateQuaternionInput('TQuatf.Slerp', 'AA', AA);
  ValidateQuaternionInput('TQuatf.Slerp', 'AB', AB);
  StartQuat := NormalizeFiniteQuat(AA);
  EndQuat := NormalizeFiniteQuat(AB);
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
  ValidateQuaternionInput('TQuatf.Nlerp', 'AA', AA);
  ValidateQuaternionInput('TQuatf.Nlerp', 'AB', AB);
  StartQuat := NormalizeFiniteQuat(AA);
  EndQuat := NormalizeFiniteQuat(AB);
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
  ValidateQuaternionInput('TQuatf.ToAxisAngle', 'quaternion', Self);
  Q := CanonicalizeAxisAngleQuat(NormalizeFiniteQuat(Self));
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
begin
  ValidateQuaternionInput('TQuatf.ToRotationMatrix', 'quaternion', Self);
  Result := RotationMatrixFromFiniteQuat(Self);
end;

function TQuatf.Rotate(const AVector: TVec3f): TVec3f;
begin
  ValidateQuaternionInput('TQuatf.Rotate', 'quaternion', Self);
  ValidateVectorInput('TQuatf.Rotate', 'AVector', AVector);
  Result := RotationMatrixFromFiniteQuat(Self) * AVector;
end;

function TQuatf.Conjugate: TQuatf;
begin
  Result := TQuatf.Create(-X, -Y, -Z, W);
end;

function TQuatf.Normalize: TQuatf;
begin
  ValidateQuaternionInput('TQuatf.Normalize', 'quaternion', Self);
  Result := NormalizeFiniteQuat(Self);
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
  ValidateQuaternionInput('TQuatd.Slerp', 'AA', AA);
  ValidateQuaternionInput('TQuatd.Slerp', 'AB', AB);
  StartQuat := NormalizeFiniteQuat(AA);
  EndQuat := NormalizeFiniteQuat(AB);
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
  ValidateQuaternionInput('TQuatd.Nlerp', 'AA', AA);
  ValidateQuaternionInput('TQuatd.Nlerp', 'AB', AB);
  StartQuat := NormalizeFiniteQuat(AA);
  EndQuat := NormalizeFiniteQuat(AB);
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
  ValidateQuaternionInput('TQuatd.ToAxisAngle', 'quaternion', Self);
  Q := CanonicalizeAxisAngleQuat(NormalizeFiniteQuat(Self));
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
begin
  ValidateQuaternionInput('TQuatd.ToRotationMatrix', 'quaternion', Self);
  Result := RotationMatrixFromFiniteQuat(Self);
end;

function TQuatd.Rotate(const AVector: TVec3d): TVec3d;
begin
  ValidateQuaternionInput('TQuatd.Rotate', 'quaternion', Self);
  ValidateVectorInput('TQuatd.Rotate', 'AVector', AVector);
  Result := RotationMatrixFromFiniteQuat(Self) * AVector;
end;

function TQuatd.Conjugate: TQuatd;
begin
  Result := TQuatd.Create(-X, -Y, -Z, W);
end;

function TQuatd.Normalize: TQuatd;
begin
  ValidateQuaternionInput('TQuatd.Normalize', 'quaternion', Self);
  Result := NormalizeFiniteQuat(Self);
end;

end.
