program test_quat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.vec,
  nextpas.core.math.mat,
  nextpas.core.math.quat;

var
  T: TTestRunner;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: QWord);
  end;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

procedure CheckVec3f(const AExpectedX, AExpectedY, AExpectedZ: Single; const AActual: TVec3f;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
end;

procedure CheckVec3d(const AExpectedX, AExpectedY, AExpectedZ: Double; const AActual: TVec3d;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000000000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000000000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000000000001, AMessage + '.Z');
end;

procedure CheckQuatf(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Single;
  const AActual: TQuatf; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000001, AMessage + '.W');
end;

procedure CheckQuatd(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Double;
  const AActual: TQuatd; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000000000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000000000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000000000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000000000001, AMessage + '.W');
end;

procedure CheckMat3fIdentity(const AActual: TMat3f; const AMessage: string);
begin
  Check(TMat3f.Equals(TMat3f.Identity, AActual, Single(0.000001)), AMessage);
end;

procedure CheckMat3dIdentity(const AActual: TMat3d; const AMessage: string);
begin
  Check(TMat3d.Equals(TMat3d.Identity, AActual, 0.000000000001), AMessage);
end;

procedure ExpectArgumentErrorMessage(const AExpectedMessage, AName: string; const AProc: TTestProc);
begin
  try
    AProc;
  except
    on E: EArgumentError do
    begin
      CheckEqual(AExpectedMessage, E.Message, AName + ' message');
      Exit;
    end;
    on E: Exception do
      Fail(AName + ': expected EArgumentError, got ' + E.ClassName);
  end;
  Fail(AName + ': expected EArgumentError');
end;

function SingleNaN: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7FC00000;
  Result := LValue.Value;
end;

function SingleInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7F800000;
  Result := LValue.Value;
end;

function DoubleNaN: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF8000000000000;
  Result := LValue.Value;
end;

function DoubleInfinity: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF0000000000000;
  Result := LValue.Value;
end;

procedure RaiseQuatfFromAxisAngleNaNAngle;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), SingleNaN);
end;

procedure RaiseQuatfFromAxisAngleNaNAxis;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(SingleNaN, 0.0, 1.0), Single(HALF_PI));
end;

procedure RaiseQuatfFromAxisAngleInfiniteAxis;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(SingleInfinity, 0.0, 1.0), Single(HALF_PI));
end;

procedure RaiseQuatfFromAxisAngleInfiniteAngle;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), SingleInfinity);
end;

procedure RaiseQuatdFromAxisAngleNaNAngle;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), DoubleNaN);
end;

procedure RaiseQuatdFromAxisAngleNaNAxis;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(DoubleNaN, 0.0, 1.0), HALF_PI);
end;

procedure RaiseQuatdFromAxisAngleInfiniteAxis;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(DoubleInfinity, 0.0, 1.0), HALF_PI);
end;

procedure RaiseQuatdFromAxisAngleInfiniteAngle;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), DoubleInfinity);
end;

procedure RaiseQuatfSlerpNaNT;
begin
  TQuatf.Slerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), SingleNaN);
end;

procedure RaiseQuatfSlerpInfiniteT;
begin
  TQuatf.Slerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), -SingleInfinity);
end;

procedure RaiseQuatfNlerpInfiniteT;
begin
  TQuatf.Nlerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), SingleInfinity);
end;

procedure RaiseQuatfNlerpNaNT;
begin
  TQuatf.Nlerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), SingleNaN);
end;

procedure RaiseQuatdSlerpNaNT;
begin
  TQuatd.Slerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    DoubleNaN);
end;

procedure RaiseQuatdSlerpInfiniteT;
begin
  TQuatd.Slerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    -DoubleInfinity);
end;

procedure RaiseQuatdNlerpInfiniteT;
begin
  TQuatd.Nlerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    DoubleInfinity);
end;

procedure RaiseQuatdNlerpNaNT;
begin
  TQuatd.Nlerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    DoubleNaN);
end;

function QuarterTurnZf: TQuatf;
begin
  Result := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
end;

function QuarterTurnZd: TQuatd;
begin
  Result := TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI);
end;

procedure TestQuatfContracts;
var
  Q: TQuatf;
  NegatedQ: TQuatf;
  Axis: TVec3f;
  Angle: Single;
  HalfTurn: TQuatf;
  Matrix: TMat3f;
  ScaledIdentity: TQuatf;
  ScaledQ: TQuatf;
begin
  Q := QuarterTurnZf;

  CheckEqual(Int64(SizeOf(Single) * 4), Int64(SizeOf(TQuatf)), 'TQuatf is compact value type');
  CheckQuatf(0.0, 0.0, 0.0, 1.0, TQuatf.Identity, 'TQuatf identity');
  CheckQuatf(1.0, 2.0, 3.0, 4.0, TQuatf.Create(1.0, 2.0, 3.0, 4.0), 'TQuatf create');
  CheckNear(Q.Z, Q.Data[2], 0.0, 'TQuatf Data alias');
  Check(TQuatf.Equals(TQuatf.Create(0.0, 0.0, 0.0, 0.0).Normalize, TQuatf.Identity, Single(0.0)),
    'TQuatf zero normalize returns identity');
  CheckQuatf(0.0, 0.0, -Q.Z, Q.W, Q.Conjugate, 'TQuatf conjugate');

  Q.ToAxisAngle(Axis, Angle);
  CheckVec3f(0.0, 0.0, 1.0, Axis, 'TQuatf ToAxisAngle axis');
  CheckNear(HALF_PI, Angle, 0.000001, 'TQuatf ToAxisAngle angle');
  TQuatf.Create(0.0, 0.0, 0.0, 0.0).ToAxisAngle(Axis, Angle);
  CheckVec3f(0.0, 0.0, 1.0, Axis, 'TQuatf ToAxisAngle zero rotation axis');
  CheckNear(0.0, Angle, 0.0, 'TQuatf ToAxisAngle zero rotation angle');
  CheckVec3f(1.0, 2.0, 3.0, TQuatf.Create(0.0, 0.0, 0.0, 0.0).Rotate(TVec3f.Create(1.0, 2.0, 3.0)),
    'TQuatf zero quaternion Rotate behaves like identity');
  CheckMat3fIdentity(TQuatf.Create(0.0, 0.0, 0.0, 0.0).ToRotationMatrix,
    'TQuatf zero quaternion ToRotationMatrix returns identity');

  CheckVec3f(0.0, 1.0, 0.0, Q.Rotate(TVec3f.Create(1.0, 0.0, 0.0)), 'TQuatf Rotate');
  Matrix := Q.ToRotationMatrix;
  CheckVec3f(0.0, 1.0, 0.0, Matrix * TVec3f.Create(1.0, 0.0, 0.0),
    'TQuatf ToRotationMatrix');

  HalfTurn := Q * Q;
  CheckVec3f(-1.0, 0.0, 0.0, HalfTurn.Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf multiply composes rotations');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(TQuatf.Identity, Q, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp midpoint');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Nlerp(TQuatf.Identity, Q, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp midpoint');
  NegatedQ := TQuatf.Create(-Q.X, -Q.Y, -Q.Z, -Q.W);
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(TQuatf.Identity, NegatedQ, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp follows shortest path for opposite-sign endpoint');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Nlerp(TQuatf.Identity, NegatedQ, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp follows shortest path for opposite-sign endpoint');
  ScaledIdentity := TQuatf.Create(0.0, 0.0, 0.0, 2.0);
  ScaledQ := TQuatf.Create(Q.X * 3.0, Q.Y * 3.0, Q.Z * 3.0, Q.W * 3.0);
  ScaledQ.ToAxisAngle(Axis, Angle);
  CheckVec3f(0.0, 0.0, 1.0, Axis, 'TQuatf ToAxisAngle normalizes scaled input axis');
  CheckNear(HALF_PI, Angle, 0.000001, 'TQuatf ToAxisAngle normalizes scaled input angle');
  CheckVec3f(0.0, 1.0, 0.0,
    ScaledQ.Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Rotate normalizes scaled input');
  CheckVec3f(0.0, 1.0, 0.0,
    ScaledQ.ToRotationMatrix * TVec3f.Create(1.0, 0.0, 0.0),
    'TQuatf ToRotationMatrix normalizes scaled input');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(ScaledIdentity, ScaledQ, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp normalizes scaled inputs');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Nlerp(ScaledIdentity, ScaledQ, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp normalizes scaled inputs');
  Check(TQuatf.Equals(Q, TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 2.0), Single(HALF_PI)),
    Single(0.000001)), 'TQuatf FromAxisAngle normalizes axis');
  Check(TQuatf.Equals(TQuatf.Identity, TQuatf.FromAxisAngle(TVec3f.Zero, Single(HALF_PI)),
    Single(0.0)), 'TQuatf FromAxisAngle zero axis returns identity');
  Check(TQuatf.Equals(Q, TQuatf.Create(Q.X + Single(0.0000001), Q.Y, Q.Z, Q.W), Single(0.000001)),
    'TQuatf Equals uses component epsilon');
  Check(not TQuatf.Equals(Q, NegatedQ, Single(0.000001)),
    'TQuatf Equals does not canonicalize opposite-sign rotations');
  Check(not TQuatf.Equals(Q, Q, Single(-0.000001)), 'TQuatf Equals rejects negative epsilon');
end;

procedure TestQuatdContracts;
var
  Q: TQuatd;
  NegatedQ: TQuatd;
  Axis: TVec3d;
  Angle: Double;
  HalfTurn: TQuatd;
  ScaledIdentity: TQuatd;
  ScaledQ: TQuatd;
begin
  Q := TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI);

  CheckEqual(Int64(SizeOf(Double) * 4), Int64(SizeOf(TQuatd)), 'TQuatd is compact value type');
  CheckQuatd(1.0, 2.0, 3.0, 4.0, TQuatd.Create(1.0, 2.0, 3.0, 4.0), 'TQuatd create');
  CheckNear(0.0, TQuatd.Identity.X, 0.0, 'TQuatd identity vector');
  CheckNear(1.0, TQuatd.Identity.W, 0.0, 'TQuatd identity real');
  CheckNear(Q.Z, Q.Data[2], 0.0, 'TQuatd Data alias');
  Check(TQuatd.Equals(TQuatd.Create(0.0, 0.0, 0.0, 0.0).Normalize, TQuatd.Identity, 0.0),
    'TQuatd zero normalize returns identity');
  CheckQuatd(0.0, 0.0, -Q.Z, Q.W, Q.Conjugate, 'TQuatd conjugate');
  Q.ToAxisAngle(Axis, Angle);
  CheckVec3d(0.0, 0.0, 1.0, Axis, 'TQuatd ToAxisAngle axis');
  CheckNear(HALF_PI, Angle, 0.000000000001, 'TQuatd ToAxisAngle angle');
  TQuatd.Create(0.0, 0.0, 0.0, 0.0).ToAxisAngle(Axis, Angle);
  CheckVec3d(0.0, 0.0, 1.0, Axis, 'TQuatd ToAxisAngle zero rotation axis');
  CheckNear(0.0, Angle, 0.0, 'TQuatd ToAxisAngle zero rotation angle');
  CheckVec3d(1.0, 2.0, 3.0, TQuatd.Create(0.0, 0.0, 0.0, 0.0).Rotate(TVec3d.Create(1.0, 2.0, 3.0)),
    'TQuatd zero quaternion Rotate behaves like identity');
  CheckMat3dIdentity(TQuatd.Create(0.0, 0.0, 0.0, 0.0).ToRotationMatrix,
    'TQuatd zero quaternion ToRotationMatrix returns identity');
  CheckVec3d(0.0, 1.0, 0.0, Q.Rotate(TVec3d.Create(1.0, 0.0, 0.0)), 'TQuatd Rotate');
  CheckVec3d(0.0, 1.0, 0.0,
    Q.ToRotationMatrix * TVec3d.Create(1.0, 0.0, 0.0),
    'TQuatd ToRotationMatrix');
  HalfTurn := Q * Q;
  CheckVec3d(-1.0, 0.0, 0.0, HalfTurn.Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd multiply composes rotations');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, Q, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp midpoint');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Nlerp(TQuatd.Identity, Q, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp midpoint');
  NegatedQ := TQuatd.Create(-Q.X, -Q.Y, -Q.Z, -Q.W);
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, NegatedQ, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp follows shortest path for opposite-sign endpoint');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Nlerp(TQuatd.Identity, NegatedQ, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp follows shortest path for opposite-sign endpoint');
  ScaledIdentity := TQuatd.Create(0.0, 0.0, 0.0, 2.0);
  ScaledQ := TQuatd.Create(Q.X * 3.0, Q.Y * 3.0, Q.Z * 3.0, Q.W * 3.0);
  ScaledQ.ToAxisAngle(Axis, Angle);
  CheckVec3d(0.0, 0.0, 1.0, Axis, 'TQuatd ToAxisAngle normalizes scaled input axis');
  CheckNear(HALF_PI, Angle, 0.000000000001, 'TQuatd ToAxisAngle normalizes scaled input angle');
  CheckVec3d(0.0, 1.0, 0.0,
    ScaledQ.Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Rotate normalizes scaled input');
  CheckVec3d(0.0, 1.0, 0.0,
    ScaledQ.ToRotationMatrix * TVec3d.Create(1.0, 0.0, 0.0),
    'TQuatd ToRotationMatrix normalizes scaled input');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(ScaledIdentity, ScaledQ, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp normalizes scaled inputs');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Nlerp(ScaledIdentity, ScaledQ, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp normalizes scaled inputs');
  Check(TQuatd.Equals(Q, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 2.0), HALF_PI),
    0.000000000001), 'TQuatd FromAxisAngle normalizes axis');
  Check(TQuatd.Equals(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Zero, HALF_PI), 0.0),
    'TQuatd FromAxisAngle zero axis returns identity');
  Check(TQuatd.Equals(Q, TQuatd.Create(Q.X + 0.0000000000001, Q.Y, Q.Z, Q.W), 0.000000000001),
    'TQuatd Equals uses component epsilon');
  Check(not TQuatd.Equals(Q, NegatedQ, 0.000000000001),
    'TQuatd Equals does not canonicalize opposite-sign rotations');
  Check(not TQuatd.Equals(Q, Q, -0.000000000001), 'TQuatd Equals rejects negative epsilon');
end;

procedure TestFromAxisAngleRejectsNonFiniteInputs;
begin
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAngleRad must be finite',
    'TQuatf FromAxisAngle NaN angle', @RaiseQuatfFromAxisAngleNaNAngle);
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAngleRad must be finite',
    'TQuatf FromAxisAngle infinite angle', @RaiseQuatfFromAxisAngleInfiniteAngle);
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAxis must be finite',
    'TQuatf FromAxisAngle NaN axis', @RaiseQuatfFromAxisAngleNaNAxis);
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAxis must be finite',
    'TQuatf FromAxisAngle infinite axis', @RaiseQuatfFromAxisAngleInfiniteAxis);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAngleRad must be finite',
    'TQuatd FromAxisAngle NaN angle', @RaiseQuatdFromAxisAngleNaNAngle);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAngleRad must be finite',
    'TQuatd FromAxisAngle infinite angle', @RaiseQuatdFromAxisAngleInfiniteAngle);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAxis must be finite',
    'TQuatd FromAxisAngle NaN axis', @RaiseQuatdFromAxisAngleNaNAxis);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAxis must be finite',
    'TQuatd FromAxisAngle infinite axis', @RaiseQuatdFromAxisAngleInfiniteAxis);
end;

procedure TestInterpolationRejectsNonFiniteT;
begin
  ExpectArgumentErrorMessage('TQuatf.Slerp: AT must be finite',
    'TQuatf Slerp NaN t', @RaiseQuatfSlerpNaNT);
  ExpectArgumentErrorMessage('TQuatf.Slerp: AT must be finite',
    'TQuatf Slerp infinite t', @RaiseQuatfSlerpInfiniteT);
  ExpectArgumentErrorMessage('TQuatf.Nlerp: AT must be finite',
    'TQuatf Nlerp NaN t', @RaiseQuatfNlerpNaNT);
  ExpectArgumentErrorMessage('TQuatf.Nlerp: AT must be finite',
    'TQuatf Nlerp infinite t', @RaiseQuatfNlerpInfiniteT);
  ExpectArgumentErrorMessage('TQuatd.Slerp: AT must be finite',
    'TQuatd Slerp NaN t', @RaiseQuatdSlerpNaNT);
  ExpectArgumentErrorMessage('TQuatd.Slerp: AT must be finite',
    'TQuatd Slerp infinite t', @RaiseQuatdSlerpInfiniteT);
  ExpectArgumentErrorMessage('TQuatd.Nlerp: AT must be finite',
    'TQuatd Nlerp NaN t', @RaiseQuatdNlerpNaNT);
  ExpectArgumentErrorMessage('TQuatd.Nlerp: AT must be finite',
    'TQuatd Nlerp infinite t', @RaiseQuatdNlerpInfiniteT);
end;

procedure TestInterpolationAllowsFiniteExtrapolation;
var
  Qf: TQuatf;
  Qd: TQuatd;
begin
  Qf := QuarterTurnZf;
  CheckVec3f(0.7071068, -0.7071068, 0.0,
    TQuatf.Slerp(TQuatf.Identity, Qf, Single(-0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp extrapolates below zero');
  CheckVec3f(0.8263093, -0.5632167, 0.0,
    TQuatf.Nlerp(TQuatf.Identity, Qf, Single(-0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp extrapolates below zero');
  CheckVec3f(-0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(TQuatf.Identity, Qf, Single(1.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp extrapolates above one');
  CheckVec3f(-0.5632167, 0.8263093, 0.0,
    TQuatf.Nlerp(TQuatf.Identity, Qf, Single(1.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp extrapolates above one');

  Qd := QuarterTurnZd;
  CheckVec3d(0.7071067811865475, -0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, Qd, -0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp extrapolates below zero');
  CheckVec3d(0.8263092599131795, -0.5632166607813849, 0.0,
    TQuatd.Nlerp(TQuatd.Identity, Qd, -0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp extrapolates below zero');
  CheckVec3d(-0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, Qd, 1.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp extrapolates above one');
  CheckVec3d(-0.5632166607813849, 0.8263092599131795, 0.0,
    TQuatd.Nlerp(TQuatd.Identity, Qd, 1.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp extrapolates above one');
end;

procedure TestInterpolationEndpointContracts;
var
  Qf: TQuatf;
  ZeroQuatf: TQuatf;
  NegatedQf: TQuatf;
  ScaledIdentityf: TQuatf;
  ScaledQf: TQuatf;
  Qd: TQuatd;
  ZeroQuatd: TQuatd;
  NegatedQd: TQuatd;
  ScaledIdentityd: TQuatd;
  ScaledQd: TQuatd;
begin
  Qf := QuarterTurnZf;
  ZeroQuatf := TQuatf.Create(0.0, 0.0, 0.0, 0.0);
  NegatedQf := TQuatf.Create(-Qf.X, -Qf.Y, -Qf.Z, -Qf.W);
  ScaledIdentityf := TQuatf.Create(0.0, 0.0, 0.0, 2.0);
  ScaledQf := TQuatf.Create(Qf.X * 3.0, Qf.Y * 3.0, Qf.Z * 3.0, Qf.W * 3.0);
  Check(TQuatf.Equals(TQuatf.Slerp(ZeroQuatf, Qf, Single(0.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Slerp t=0 normalizes zero start');
  Check(TQuatf.Equals(TQuatf.Nlerp(ZeroQuatf, Qf, Single(0.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Nlerp t=0 normalizes zero start');
  Check(TQuatf.Equals(TQuatf.Slerp(Qf, ZeroQuatf, Single(1.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Slerp t=1 normalizes zero end');
  Check(TQuatf.Equals(TQuatf.Nlerp(Qf, ZeroQuatf, Single(1.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Nlerp t=1 normalizes zero end');
  Check(TQuatf.Equals(TQuatf.Slerp(ScaledIdentityf, ScaledQf, Single(0.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Slerp t=0 returns normalized start');
  Check(TQuatf.Equals(TQuatf.Nlerp(ScaledIdentityf, ScaledQf, Single(0.0)), TQuatf.Identity,
    Single(0.000001)), 'TQuatf Nlerp t=0 returns normalized start');
  Check(TQuatf.Equals(TQuatf.Slerp(ScaledIdentityf, ScaledQf, Single(1.0)), Qf,
    Single(0.000001)), 'TQuatf Slerp t=1 returns normalized end');
  Check(TQuatf.Equals(TQuatf.Nlerp(ScaledIdentityf, ScaledQf, Single(1.0)), Qf,
    Single(0.000001)), 'TQuatf Nlerp t=1 returns normalized end');
  Check(TQuatf.Equals(TQuatf.Slerp(TQuatf.Identity, NegatedQf, Single(1.0)), Qf,
    Single(0.000001)), 'TQuatf Slerp t=1 canonicalizes opposite-sign end');
  Check(TQuatf.Equals(TQuatf.Nlerp(TQuatf.Identity, NegatedQf, Single(1.0)), Qf,
    Single(0.000001)), 'TQuatf Nlerp t=1 canonicalizes opposite-sign end');

  Qd := QuarterTurnZd;
  ZeroQuatd := TQuatd.Create(0.0, 0.0, 0.0, 0.0);
  NegatedQd := TQuatd.Create(-Qd.X, -Qd.Y, -Qd.Z, -Qd.W);
  ScaledIdentityd := TQuatd.Create(0.0, 0.0, 0.0, 2.0);
  ScaledQd := TQuatd.Create(Qd.X * 3.0, Qd.Y * 3.0, Qd.Z * 3.0, Qd.W * 3.0);
  Check(TQuatd.Equals(TQuatd.Slerp(ZeroQuatd, Qd, 0.0), TQuatd.Identity, 0.000000000001),
    'TQuatd Slerp t=0 normalizes zero start');
  Check(TQuatd.Equals(TQuatd.Nlerp(ZeroQuatd, Qd, 0.0), TQuatd.Identity, 0.000000000001),
    'TQuatd Nlerp t=0 normalizes zero start');
  Check(TQuatd.Equals(TQuatd.Slerp(Qd, ZeroQuatd, 1.0), TQuatd.Identity, 0.000000000001),
    'TQuatd Slerp t=1 normalizes zero end');
  Check(TQuatd.Equals(TQuatd.Nlerp(Qd, ZeroQuatd, 1.0), TQuatd.Identity, 0.000000000001),
    'TQuatd Nlerp t=1 normalizes zero end');
  Check(TQuatd.Equals(TQuatd.Slerp(ScaledIdentityd, ScaledQd, 0.0), TQuatd.Identity,
    0.000000000001), 'TQuatd Slerp t=0 returns normalized start');
  Check(TQuatd.Equals(TQuatd.Nlerp(ScaledIdentityd, ScaledQd, 0.0), TQuatd.Identity,
    0.000000000001), 'TQuatd Nlerp t=0 returns normalized start');
  Check(TQuatd.Equals(TQuatd.Slerp(ScaledIdentityd, ScaledQd, 1.0), Qd, 0.000000000001),
    'TQuatd Slerp t=1 returns normalized end');
  Check(TQuatd.Equals(TQuatd.Nlerp(ScaledIdentityd, ScaledQd, 1.0), Qd, 0.000000000001),
    'TQuatd Nlerp t=1 returns normalized end');
  Check(TQuatd.Equals(TQuatd.Slerp(TQuatd.Identity, NegatedQd, 1.0), Qd, 0.000000000001),
    'TQuatd Slerp t=1 canonicalizes opposite-sign end');
  Check(TQuatd.Equals(TQuatd.Nlerp(TQuatd.Identity, NegatedQd, 1.0), Qd, 0.000000000001),
    'TQuatd Nlerp t=1 canonicalizes opposite-sign end');
end;

procedure TestInterpolationFollowsShortestPathForOppositeSignStart;
var
  Qf: TQuatf;
  NegatedIdentityf: TQuatf;
  Qd: TQuatd;
  NegatedIdentityd: TQuatd;
begin
  Qf := QuarterTurnZf;
  NegatedIdentityf := TQuatf.Create(0.0, 0.0, 0.0, -1.0);
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(NegatedIdentityf, Qf, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp follows shortest path for opposite-sign start');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Nlerp(NegatedIdentityf, Qf, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp follows shortest path for opposite-sign start');

  Qd := QuarterTurnZd;
  NegatedIdentityd := TQuatd.Create(0.0, 0.0, 0.0, -1.0);
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(NegatedIdentityd, Qd, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp follows shortest path for opposite-sign start');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Nlerp(NegatedIdentityd, Qd, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp follows shortest path for opposite-sign start');
end;

procedure TestInterpolationFollowsShortestPathForOppositeSignEnd;
var
  NegatedQf: TQuatf;
  NegatedQd: TQuatd;
begin
  NegatedQf := TQuatf.Create(-QuarterTurnZf.X, -QuarterTurnZf.Y, -QuarterTurnZf.Z, -QuarterTurnZf.W);
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Slerp(TQuatf.Identity, NegatedQf, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Slerp follows shortest path for opposite-sign end');
  CheckVec3f(0.7071068, 0.7071068, 0.0,
    TQuatf.Nlerp(TQuatf.Identity, NegatedQf, Single(0.5)).Rotate(TVec3f.Create(1.0, 0.0, 0.0)),
    'TQuatf Nlerp follows shortest path for opposite-sign end');

  NegatedQd := TQuatd.Create(-QuarterTurnZd.X, -QuarterTurnZd.Y, -QuarterTurnZd.Z, -QuarterTurnZd.W);
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, NegatedQd, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp follows shortest path for opposite-sign end');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Nlerp(TQuatd.Identity, NegatedQd, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Nlerp follows shortest path for opposite-sign end');
end;

procedure TestInterpolationStaysStableForEquivalentEndpoints;
var
  Qf: TQuatf;
  ScaledQf: TQuatf;
  NegatedQf: TQuatf;
  Qd: TQuatd;
  ScaledQd: TQuatd;
  NegatedQd: TQuatd;
begin
  Qf := QuarterTurnZf;
  ScaledQf := TQuatf.Create(Qf.X * 3.0, Qf.Y * 3.0, Qf.Z * 3.0, Qf.W * 3.0);
  NegatedQf := TQuatf.Create(-Qf.X, -Qf.Y, -Qf.Z, -Qf.W);
  Check(TQuatf.Equals(TQuatf.Slerp(Qf, Qf, Single(0.25)), Qf, Single(0.000001)),
    'TQuatf Slerp keeps identical endpoints stable');
  Check(TQuatf.Equals(TQuatf.Nlerp(Qf, Qf, Single(0.25)), Qf, Single(0.000001)),
    'TQuatf Nlerp keeps identical endpoints stable');
  Check(TQuatf.Equals(TQuatf.Slerp(Qf, ScaledQf, Single(0.25)), Qf, Single(0.000001)),
    'TQuatf Slerp keeps scaled-equivalent endpoints stable');
  Check(TQuatf.Equals(TQuatf.Nlerp(Qf, ScaledQf, Single(0.25)), Qf, Single(0.000001)),
    'TQuatf Nlerp keeps scaled-equivalent endpoints stable');
  Check(TQuatf.Equals(TQuatf.Slerp(Qf, NegatedQf, Single(0.5)), Qf, Single(0.000001)),
    'TQuatf Slerp keeps opposite-sign midpoint stable');
  Check(TQuatf.Equals(TQuatf.Nlerp(Qf, NegatedQf, Single(0.5)), Qf, Single(0.000001)),
    'TQuatf Nlerp keeps opposite-sign midpoint stable');

  Qd := QuarterTurnZd;
  ScaledQd := TQuatd.Create(Qd.X * 3.0, Qd.Y * 3.0, Qd.Z * 3.0, Qd.W * 3.0);
  NegatedQd := TQuatd.Create(-Qd.X, -Qd.Y, -Qd.Z, -Qd.W);
  Check(TQuatd.Equals(TQuatd.Slerp(Qd, Qd, 0.25), Qd, 0.000000000001),
    'TQuatd Slerp keeps identical endpoints stable');
  Check(TQuatd.Equals(TQuatd.Nlerp(Qd, Qd, 0.25), Qd, 0.000000000001),
    'TQuatd Nlerp keeps identical endpoints stable');
  Check(TQuatd.Equals(TQuatd.Slerp(Qd, ScaledQd, 0.25), Qd, 0.000000000001),
    'TQuatd Slerp keeps scaled-equivalent endpoints stable');
  Check(TQuatd.Equals(TQuatd.Nlerp(Qd, ScaledQd, 0.25), Qd, 0.000000000001),
    'TQuatd Nlerp keeps scaled-equivalent endpoints stable');
  Check(TQuatd.Equals(TQuatd.Slerp(Qd, NegatedQd, 0.5), Qd, 0.000000000001),
    'TQuatd Slerp keeps opposite-sign midpoint stable');
  Check(TQuatd.Equals(TQuatd.Nlerp(Qd, NegatedQd, 0.5), Qd, 0.000000000001),
    'TQuatd Nlerp keeps opposite-sign midpoint stable');
end;

procedure TestToAxisAngleCanonicalizesOppositeSignRotations;
var
  Axisf: TVec3f;
  Angledf: Single;
  Axisd: TVec3d;
  Angledd: Double;
begin
  TQuatf.Create(0.0, 0.0, 0.0, -1.0).ToAxisAngle(Axisf, Angledf);
  CheckVec3f(0.0, 0.0, 1.0, Axisf, 'TQuatf ToAxisAngle canonicalizes negated identity axis');
  CheckNear(0.0, Angledf, 0.0, 'TQuatf ToAxisAngle canonicalizes negated identity angle');

  TQuatf.Create(0.0, 0.0, -0.7071068, -0.7071068).ToAxisAngle(Axisf, Angledf);
  CheckVec3f(0.0, 0.0, 1.0, Axisf,
    'TQuatf ToAxisAngle canonicalizes negated quarter-turn axis');
  CheckNear(HALF_PI, Angledf, 0.000001,
    'TQuatf ToAxisAngle canonicalizes negated quarter-turn angle');

  TQuatf.Create(0.0, 0.0, -1.0, 0.0).ToAxisAngle(Axisf, Angledf);
  CheckVec3f(0.0, 0.0, 1.0, Axisf, 'TQuatf ToAxisAngle canonicalizes half-turn axis');
  CheckNear(PI_VALUE, Angledf, 0.000001, 'TQuatf ToAxisAngle canonicalizes half-turn angle');

  TQuatf.Create(-1.0, 0.0, 0.0, 0.0).ToAxisAngle(Axisf, Angledf);
  CheckVec3f(1.0, 0.0, 0.0, Axisf, 'TQuatf ToAxisAngle canonicalizes x half-turn axis');
  CheckNear(PI_VALUE, Angledf, 0.000001, 'TQuatf ToAxisAngle canonicalizes x half-turn angle');

  TQuatf.Create(0.0, -1.0, 0.0, 0.0).ToAxisAngle(Axisf, Angledf);
  CheckVec3f(0.0, 1.0, 0.0, Axisf, 'TQuatf ToAxisAngle canonicalizes y half-turn axis');
  CheckNear(PI_VALUE, Angledf, 0.000001, 'TQuatf ToAxisAngle canonicalizes y half-turn angle');

  TQuatd.Create(0.0, 0.0, 0.0, -1.0).ToAxisAngle(Axisd, Angledd);
  CheckVec3d(0.0, 0.0, 1.0, Axisd, 'TQuatd ToAxisAngle canonicalizes negated identity axis');
  CheckNear(0.0, Angledd, 0.0, 'TQuatd ToAxisAngle canonicalizes negated identity angle');

  TQuatd.Create(0.0, 0.0, -0.7071067811865475, -0.7071067811865475).ToAxisAngle(Axisd, Angledd);
  CheckVec3d(0.0, 0.0, 1.0, Axisd,
    'TQuatd ToAxisAngle canonicalizes negated quarter-turn axis');
  CheckNear(HALF_PI, Angledd, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes negated quarter-turn angle');

  TQuatd.Create(0.0, 0.0, -1.0, 0.0).ToAxisAngle(Axisd, Angledd);
  CheckVec3d(0.0, 0.0, 1.0, Axisd, 'TQuatd ToAxisAngle canonicalizes half-turn axis');
  CheckNear(PI_VALUE, Angledd, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes half-turn angle');

  TQuatd.Create(-1.0, 0.0, 0.0, 0.0).ToAxisAngle(Axisd, Angledd);
  CheckVec3d(1.0, 0.0, 0.0, Axisd, 'TQuatd ToAxisAngle canonicalizes x half-turn axis');
  CheckNear(PI_VALUE, Angledd, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes x half-turn angle');

  TQuatd.Create(0.0, -1.0, 0.0, 0.0).ToAxisAngle(Axisd, Angledd);
  CheckVec3d(0.0, 1.0, 0.0, Axisd, 'TQuatd ToAxisAngle canonicalizes y half-turn axis');
  CheckNear(PI_VALUE, Angledd, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes y half-turn angle');
end;

procedure TestToAxisAngleCanonicalizesMultiTurnInputs;
var
  Axisf: TVec3f;
  Anglef: Single;
  Axisd: TVec3d;
  Angled: Double;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(3.0 * HALF_PI)).ToAxisAngle(Axisf, Anglef);
  CheckVec3f(0.0, 0.0, -1.0, Axisf, 'TQuatf ToAxisAngle canonicalizes positive multi-turn axis');
  CheckNear(HALF_PI, Anglef, 0.000001,
    'TQuatf ToAxisAngle canonicalizes positive multi-turn angle');

  TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(-3.0 * HALF_PI)).ToAxisAngle(Axisf, Anglef);
  CheckVec3f(0.0, 0.0, 1.0, Axisf, 'TQuatf ToAxisAngle canonicalizes negative multi-turn axis');
  CheckNear(HALF_PI, Anglef, 0.000001,
    'TQuatf ToAxisAngle canonicalizes negative multi-turn angle');

  TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), 3.0 * HALF_PI).ToAxisAngle(Axisd, Angled);
  CheckVec3d(0.0, 0.0, -1.0, Axisd, 'TQuatd ToAxisAngle canonicalizes positive multi-turn axis');
  CheckNear(HALF_PI, Angled, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes positive multi-turn angle');

  TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), -3.0 * HALF_PI).ToAxisAngle(Axisd, Angled);
  CheckVec3d(0.0, 0.0, 1.0, Axisd, 'TQuatd ToAxisAngle canonicalizes negative multi-turn axis');
  CheckNear(HALF_PI, Angled, 0.000000000001,
    'TQuatd ToAxisAngle canonicalizes negative multi-turn angle');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.quat');
  T.Run('TQuatf contracts', @TestQuatfContracts);
  T.Run('TQuatd contracts', @TestQuatdContracts);
  T.Run('FromAxisAngle rejects non-finite inputs', @TestFromAxisAngleRejectsNonFiniteInputs);
  T.Run('Interpolation rejects non-finite t', @TestInterpolationRejectsNonFiniteT);
  T.Run('Interpolation allows finite extrapolation', @TestInterpolationAllowsFiniteExtrapolation);
  T.Run('Interpolation endpoint contracts', @TestInterpolationEndpointContracts);
  T.Run('Interpolation follows shortest path for opposite-sign start',
    @TestInterpolationFollowsShortestPathForOppositeSignStart);
  T.Run('Interpolation follows shortest path for opposite-sign end',
    @TestInterpolationFollowsShortestPathForOppositeSignEnd);
  T.Run('Interpolation stays stable for equivalent endpoints',
    @TestInterpolationStaysStableForEquivalentEndpoints);
  T.Run('ToAxisAngle canonicalizes opposite-sign rotations',
    @TestToAxisAngleCanonicalizesOppositeSignRotations);
  T.Run('ToAxisAngle canonicalizes multi-turn inputs',
    @TestToAxisAngleCanonicalizesMultiTurnInputs);
  T.Summary;
end.
