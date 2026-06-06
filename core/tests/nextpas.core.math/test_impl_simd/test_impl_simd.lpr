program test_impl_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math,
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.vec,
  nextpas.core.math.impl.simd;

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

procedure CheckVec4f(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Single;
  const AActual: TVec4f; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000001, AMessage + '.W');
end;

procedure TestVec4fSimdHelpers;
var
  A: TVec4f;
  B: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);

  CheckVec4f(6.0, 8.0, 10.0, 12.0, SimdVec4fAdd(A, B), 'SimdVec4fAdd');
  CheckVec4f(-4.0, -4.0, -4.0, -4.0, SimdVec4fSub(A, B), 'SimdVec4fSub');
  CheckVec4f(5.0, 12.0, 21.0, 32.0, SimdVec4fMulComponents(A, B),
    'SimdVec4fMulComponents');
  CheckVec4f(2.5, 5.0, 7.5, 10.0, SimdVec4fScale(A, 2.5), 'SimdVec4fScale');
  CheckNear(70.0, SimdVec4fDot(A, B), 0.000001, 'SimdVec4fDot');
  CheckNear(5.0, SimdVec4fLength(TVec4f.Create(0.0, 0.0, 3.0, 4.0)), 0.000001,
    'SimdVec4fLength');
end;

procedure TestVec3fSimdHelpers;
var
  A: TVec3f;
  B: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);

  CheckNear(32.0, SimdVec3fDot(A, B), 0.000001, 'SimdVec3fDot');
  CheckVec3f(0.0, 0.0, 1.0, SimdVec3fCross(TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0)), 'SimdVec3fCross');
end;

procedure TestMat4fSimdHelpers;
var
  M: TMat4f;
  V: TVec4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(5.0, 6.0, 7.0, 8.0),
    TVec4f.Create(9.0, 10.0, 11.0, 12.0),
    TVec4f.Create(13.0, 14.0, 15.0, 16.0));
  V := TVec4f.Create(0.5, -1.0, 2.0, 1.5);

  CheckVec4f(33.0, 36.0, 39.0, 42.0, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f');
end;

procedure TestQuatfSimdHelpers;
var
  Q: TQuatf;
  ScaledQ: TQuatf;
  V: TVec3f;
begin
  Q := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
  V := TVec3f.Create(1.0, 0.0, 0.0);
  CheckVec3f(0.0, 1.0, 0.0, SimdQuatfRotate(Q, V),
    'SimdQuatfRotate quarter turn');

  ScaledQ := TQuatf.Create(Q.X * 2.0, Q.Y * 2.0, Q.Z * 2.0, Q.W * 2.0);
  CheckVec3f(Q.Rotate(V).X, Q.Rotate(V).Y, Q.Rotate(V).Z, SimdQuatfRotate(ScaledQ, V),
    'SimdQuatfRotate matches public Rotate semantics for non-unit quaternions');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.impl.simd');
  T.Run('vec4f simd helpers', @TestVec4fSimdHelpers);
  T.Run('vec3f simd helpers', @TestVec3fSimdHelpers);
  T.Run('mat4f simd helpers', @TestMat4fSimdHelpers);
  T.Run('quatf simd helpers', @TestQuatfSimdHelpers);
  T.Summary;
end.
