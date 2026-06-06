program test_quat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math.scalar,
  nextpas.core.math.vec,
  nextpas.core.math.mat,
  nextpas.core.math.quat;

var
  T: TTestRunner;

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

function QuarterTurnZf: TQuatf;
begin
  Result := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
end;

procedure TestQuatfContracts;
var
  Q: TQuatf;
  Axis: TVec3f;
  Angle: Single;
  HalfTurn: TQuatf;
  Matrix: TMat3f;
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
  Check(TQuatf.Equals(Q, TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 2.0), Single(HALF_PI)),
    Single(0.000001)), 'TQuatf FromAxisAngle normalizes axis');
  Check(TQuatf.Equals(TQuatf.Identity, TQuatf.FromAxisAngle(TVec3f.Zero, Single(HALF_PI)),
    Single(0.0)), 'TQuatf FromAxisAngle zero axis returns identity');
end;

procedure TestQuatdContracts;
var
  Q: TQuatd;
begin
  Q := TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), HALF_PI);

  CheckEqual(Int64(SizeOf(Double) * 4), Int64(SizeOf(TQuatd)), 'TQuatd is compact value type');
  CheckNear(0.0, TQuatd.Identity.X, 0.0, 'TQuatd identity vector');
  CheckNear(1.0, TQuatd.Identity.W, 0.0, 'TQuatd identity real');
  Check(TQuatd.Equals(TQuatd.Create(0.0, 0.0, 0.0, 0.0).Normalize, TQuatd.Identity, 0.0),
    'TQuatd zero normalize returns identity');
  CheckVec3d(0.0, 1.0, 0.0, Q.Rotate(TVec3d.Create(1.0, 0.0, 0.0)), 'TQuatd Rotate');
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0,
    TQuatd.Slerp(TQuatd.Identity, Q, 0.5).Rotate(TVec3d.Create(1.0, 0.0, 0.0)),
    'TQuatd Slerp midpoint');
  Check(TQuatd.Equals(Q, TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 2.0), HALF_PI),
    0.000000000001), 'TQuatd FromAxisAngle normalizes axis');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.quat');
  T.Run('TQuatf contracts', @TestQuatfContracts);
  T.Run('TQuatd contracts', @TestQuatdContracts);
  T.Summary;
end.
