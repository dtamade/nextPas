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

procedure RaiseQuatfFromAxisAngleInfiniteAxis;
begin
  TQuatf.FromAxisAngle(TVec3f.Create(SingleInfinity, 0.0, 1.0), Single(HALF_PI));
end;

procedure RaiseQuatdFromAxisAngleNaNAngle;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), DoubleNaN);
end;

procedure RaiseQuatdFromAxisAngleInfiniteAxis;
begin
  TQuatd.FromAxisAngle(TVec3d.Create(DoubleInfinity, 0.0, 1.0), HALF_PI);
end;

procedure RaiseQuatfSlerpNaNT;
begin
  TQuatf.Slerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), SingleNaN);
end;

procedure RaiseQuatfNlerpInfiniteT;
begin
  TQuatf.Nlerp(TQuatf.Identity,
    TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI)), SingleInfinity);
end;

procedure RaiseQuatdSlerpNaNT;
begin
  TQuatd.Slerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    DoubleNaN);
end;

procedure RaiseQuatdNlerpInfiniteT;
begin
  TQuatd.Nlerp(TQuatd.Identity, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI),
    DoubleInfinity);
end;

function QuarterTurnZf: TQuatf;
begin
  Result := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
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
end;

procedure TestFromAxisAngleRejectsNonFiniteInputs;
begin
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAngleRad must be finite',
    'TQuatf FromAxisAngle NaN angle', @RaiseQuatfFromAxisAngleNaNAngle);
  ExpectArgumentErrorMessage('TQuatf.FromAxisAngle: AAxis must be finite',
    'TQuatf FromAxisAngle infinite axis', @RaiseQuatfFromAxisAngleInfiniteAxis);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAngleRad must be finite',
    'TQuatd FromAxisAngle NaN angle', @RaiseQuatdFromAxisAngleNaNAngle);
  ExpectArgumentErrorMessage('TQuatd.FromAxisAngle: AAxis must be finite',
    'TQuatd FromAxisAngle infinite axis', @RaiseQuatdFromAxisAngleInfiniteAxis);
end;

procedure TestInterpolationRejectsNonFiniteT;
begin
  ExpectArgumentErrorMessage('TQuatf.Slerp: AT must be finite',
    'TQuatf Slerp NaN t', @RaiseQuatfSlerpNaNT);
  ExpectArgumentErrorMessage('TQuatf.Nlerp: AT must be finite',
    'TQuatf Nlerp infinite t', @RaiseQuatfNlerpInfiniteT);
  ExpectArgumentErrorMessage('TQuatd.Slerp: AT must be finite',
    'TQuatd Slerp NaN t', @RaiseQuatdSlerpNaNT);
  ExpectArgumentErrorMessage('TQuatd.Nlerp: AT must be finite',
    'TQuatd Nlerp infinite t', @RaiseQuatdNlerpInfiniteT);
end;

begin
  T := TTestRunner.Create('nextpas.core.math.quat');
  T.Run('TQuatf contracts', @TestQuatfContracts);
  T.Run('TQuatd contracts', @TestQuatdContracts);
  T.Run('FromAxisAngle rejects non-finite inputs', @TestFromAxisAngleRejectsNonFiniteInputs);
  T.Run('Interpolation rejects non-finite t', @TestInterpolationRejectsNonFiniteT);
  T.Summary;
end.
