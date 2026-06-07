program test_transform;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.scalar,
  nextpas.core.math.vec,
  nextpas.core.math.mat,
  nextpas.core.math.transform;

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

procedure CheckVec4f(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Single;
  const AActual: TVec4f; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000001, AMessage + '.W');
end;

procedure CheckVec4d(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Double;
  const AActual: TVec4d; const AMessage: string);
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

procedure RaiseOrthoZeroWidth;
begin
  Ortho(Single(1.0), Single(1.0), Single(-1.0), Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaiseOrthoZeroWidthDouble;
begin
  Ortho(Double(1.0), Double(1.0), Double(-1.0), Double(1.0), Double(0.0), Double(10.0));
end;

procedure RaiseOrthoZeroHeightSingle;
begin
  Ortho(Single(-1.0), Single(1.0), Single(2.0), Single(2.0), Single(0.0), Single(10.0));
end;

procedure RaiseOrthoZeroHeightDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(2.0), Double(2.0), Double(0.0), Double(10.0));
end;

procedure RaisePerspectiveZeroAspect;
begin
  Perspective(Single(HALF_PI), Single(0.0), Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveZeroAspectDouble;
begin
  Perspective(Double(HALF_PI), Double(0.0), Double(1.0), Double(10.0));
end;

procedure RaisePerspectiveZeroFovSingle;
begin
  Perspective(Single(0.0), Single(1.0), Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveZeroFovDouble;
begin
  Perspective(Double(0.0), Double(1.0), Double(1.0), Double(10.0));
end;

procedure RaisePerspectiveZeroNearDouble;
begin
  Perspective(Double(HALF_PI), Double(1.0), Double(0.0), Double(10.0));
end;

procedure RaisePerspectiveZeroNearSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaisePerspectiveInvalidFovSingle;
begin
  Perspective(Single(PI_VALUE), Single(1.0), Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveInvalidFovDouble;
begin
  Perspective(Double(PI_VALUE * 3.0), Double(1.0), Double(1.0), Double(10.0));
end;

procedure RaiseCamera2DZeroZoom;
begin
  Camera2D(Single(0.0), Single(0.0), Single(0.0), 100, 100);
end;

procedure RaiseCamera2DZeroZoomDouble;
begin
  Camera2D(Double(0.0), Double(0.0), Double(0.0), 100, 100);
end;

procedure RaiseCamera2DNegativeZoomSingle;
begin
  Camera2D(Single(0.0), Single(0.0), Single(-1.0), 100, 100);
end;

procedure RaiseCamera2DNegativeZoomDouble;
begin
  Camera2D(Double(0.0), Double(0.0), Double(-1.0), 100, 100);
end;

procedure RaiseOrthoZeroDepthDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(-1.0), Double(1.0), Double(5.0), Double(5.0));
end;

procedure RaiseOrthoZeroDepthSingle;
begin
  Ortho(Single(-1.0), Single(1.0), Single(-1.0), Single(1.0), Single(5.0), Single(5.0));
end;

procedure RaisePerspectiveFarNotGreaterSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), Single(5.0), Single(5.0));
end;

procedure RaisePerspectiveFarNotGreaterDouble;
begin
  Perspective(Double(HALF_PI), Double(1.0), Double(5.0), Double(5.0));
end;

procedure RaisePerspectiveFarLessThanNearSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), Single(5.0), Single(4.0));
end;

procedure RaisePerspectiveFarLessThanNearDouble;
begin
  Perspective(Double(HALF_PI), Double(1.0), Double(5.0), Double(4.0));
end;

procedure RaiseLookAtCoincidentEyeSingle;
begin
  LookAt(TVec3f.Create(1.0, 2.0, 3.0), TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtCoincidentEyeDouble;
begin
  LookAt(TVec3d.Create(1.0, 2.0, 3.0), TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtParallelUpDouble;
begin
  LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero, TVec3d.Create(0.0, 0.0, -2.0));
end;

procedure RaiseLookAtParallelUpSingle;
begin
  LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero, TVec3f.Create(0.0, 0.0, -2.0));
end;

procedure RaiseCamera2DZeroWidthSingle;
begin
  Camera2D(Single(0.0), Single(0.0), Single(1.0), 0, 100);
end;

procedure RaiseCamera2DZeroWidthDouble;
begin
  Camera2D(Double(0.0), Double(0.0), Double(1.0), 0, 100);
end;

procedure RaiseCamera2DNegativeHeightDouble;
begin
  Camera2D(Double(0.0), Double(0.0), Double(1.0), 100, -1);
end;

procedure RaiseCamera2DNegativeHeightSingle;
begin
  Camera2D(Single(0.0), Single(0.0), Single(1.0), 100, -1);
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

procedure RaiseOrthoInfiniteFarSingle;
begin
  Ortho(Single(-1.0), Single(1.0), Single(-1.0), Single(1.0), Single(0.0), SingleInfinity);
end;

procedure RaiseOrthoInfiniteFarDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(-1.0), Double(1.0), Double(0.0), DoubleInfinity);
end;

procedure RaiseOrthoInfiniteLeftSingle;
begin
  Ortho(SingleInfinity, Single(1.0), Single(-1.0), Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaiseOrthoInfiniteLeftDouble;
begin
  Ortho(DoubleInfinity, Double(1.0), Double(-1.0), Double(1.0), Double(0.0), Double(10.0));
end;

procedure RaiseOrthoInfiniteRightDouble;
begin
  Ortho(Double(-1.0), DoubleInfinity, Double(-1.0), Double(1.0), Double(0.0), Double(10.0));
end;

procedure RaiseOrthoInfiniteRightSingle;
begin
  Ortho(Single(-1.0), SingleInfinity, Single(-1.0), Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaiseOrthoInfiniteBottomSingle;
begin
  Ortho(Single(-1.0), Single(1.0), SingleInfinity, Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaiseOrthoInfiniteBottomDouble;
begin
  Ortho(Double(-1.0), Double(1.0), DoubleInfinity, Double(1.0), Double(0.0), Double(10.0));
end;

procedure RaiseOrthoInfiniteTopDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(-1.0), DoubleInfinity, Double(0.0), Double(10.0));
end;

procedure RaiseOrthoInfiniteTopSingle;
begin
  Ortho(Single(-1.0), Single(1.0), Single(-1.0), SingleInfinity, Single(0.0), Single(10.0));
end;

procedure RaiseOrthoNaNNearSingle;
begin
  Ortho(Single(-1.0), Single(1.0), Single(-1.0), Single(1.0), SingleNaN, Single(10.0));
end;

procedure RaiseOrthoNaNNearDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(-1.0), Double(1.0), DoubleNaN, Double(10.0));
end;

procedure RaisePerspectiveNaNFovSingle;
begin
  Perspective(SingleNaN, Single(1.0), Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveNaNFovDouble;
begin
  Perspective(DoubleNaN, Double(1.0), Double(1.0), Double(10.0));
end;

procedure RaisePerspectiveInfiniteAspectDouble;
begin
  Perspective(Double(HALF_PI), DoubleInfinity, Double(1.0), Double(10.0));
end;

procedure RaisePerspectiveInfiniteAspectSingle;
begin
  Perspective(Single(HALF_PI), SingleInfinity, Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveNaNNearSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), SingleNaN, Single(10.0));
end;

procedure RaisePerspectiveNaNNearDouble;
begin
  Perspective(Double(HALF_PI), Double(1.0), DoubleNaN, Double(10.0));
end;

procedure RaisePerspectiveInfiniteFarDouble;
begin
  Perspective(Double(HALF_PI), Double(1.0), Double(1.0), DoubleInfinity);
end;

procedure RaisePerspectiveInfiniteFarSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), Single(1.0), SingleInfinity);
end;

procedure RaiseLookAtInfiniteEyeSingle;
begin
  LookAt(TVec3f.Create(SingleInfinity, 0.0, 5.0), TVec3f.Zero, TVec3f.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtInfiniteEyeDouble;
begin
  LookAt(TVec3d.Create(DoubleInfinity, 0.0, 5.0), TVec3d.Zero, TVec3d.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtInfiniteTargetSingle;
begin
  LookAt(TVec3f.Create(0.0, 0.0, 5.0),
    TVec3f.Create(SingleInfinity, 0.0, 0.0), TVec3f.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtInfiniteTargetDouble;
begin
  LookAt(TVec3d.Create(0.0, 0.0, 5.0),
    TVec3d.Create(DoubleInfinity, 0.0, 0.0), TVec3d.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtInfiniteUpDouble;
begin
  LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero,
    TVec3d.Create(0.0, DoubleInfinity, 0.0));
end;

procedure RaiseLookAtInfiniteUpSingle;
begin
  LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero,
    TVec3f.Create(0.0, SingleInfinity, 0.0));
end;

procedure RaiseTranslateNaNSingle;
begin
  Translate(SingleNaN, Single(0.0), Single(0.0));
end;

procedure RaiseTranslateNaNDouble;
begin
  Translate(DoubleNaN, Double(0.0), Double(0.0));
end;

procedure RaiseTranslateInfinityDouble;
begin
  Translate(Double(0.0), Double(0.0), DoubleInfinity);
end;

procedure RaiseTranslateInfinityZSingle;
begin
  Translate(Single(0.0), Single(0.0), SingleInfinity);
end;

procedure RaiseTranslateInfinityYDouble;
begin
  Translate(Double(0.0), DoubleInfinity, Double(0.0));
end;

procedure RaiseTranslateInfinityYSingle;
begin
  Translate(Single(0.0), SingleInfinity, Single(0.0));
end;

procedure RaiseScaleNaNSingle;
begin
  Scale(Single(1.0), SingleNaN, Single(1.0));
end;

procedure RaiseScaleInfinityYDouble;
begin
  Scale(Double(1.0), DoubleInfinity, Double(1.0));
end;

procedure RaiseScaleInfinityXDouble;
begin
  Scale(DoubleInfinity, Double(1.0), Double(1.0));
end;

procedure RaiseScaleInfinityXSingle;
begin
  Scale(SingleInfinity, Single(1.0), Single(1.0));
end;

procedure RaiseScaleNaNZSingle;
begin
  Scale(Single(1.0), Single(1.0), SingleNaN);
end;

procedure RaiseScaleInfinityZDouble;
begin
  Scale(Double(1.0), Double(1.0), DoubleInfinity);
end;

procedure RaiseRotateZNaNSingle;
begin
  RotateZ(SingleNaN);
end;

procedure RaiseRotateZInfinityDouble;
begin
  RotateZ(DoubleInfinity);
end;

procedure RaiseRotateXInfinityDouble;
begin
  RotateX(DoubleInfinity);
end;

procedure RaiseRotateXNaNSingle;
begin
  RotateX(SingleNaN);
end;

procedure RaiseRotateYInfinityDouble;
begin
  RotateY(DoubleInfinity);
end;

procedure RaiseRotateYNaNSingle;
begin
  RotateY(SingleNaN);
end;

procedure RaiseCamera2DNaNZoomSingle;
begin
  Camera2D(Single(0.0), Single(0.0), SingleNaN, 100, 100);
end;

procedure RaiseCamera2DNaNZoomDouble;
begin
  Camera2D(Double(0.0), Double(0.0), DoubleNaN, 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterDouble;
begin
  Camera2D(DoubleInfinity, Double(0.0), Double(1.0), 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterSingle;
begin
  Camera2D(SingleInfinity, Single(0.0), Single(1.0), 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterYDouble;
begin
  Camera2D(Double(0.0), DoubleInfinity, Double(1.0), 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterYSingle;
begin
  Camera2D(Single(0.0), SingleInfinity, Single(1.0), 100, 100);
end;

procedure TestProjectionBuilders;
var
  M: TMat4f;
  Clip: TVec4f;
begin
  M := Ortho(Single(-2.0), Single(2.0), Single(-1.0), Single(1.0), Single(0.0), Single(10.0));
  CheckNear(0.5, M[0, 0], 0.000001, 'Ortho stores X scale');
  CheckNear(-1.0, M[3, 2], 0.000001, 'Ortho stores Z offset');
  CheckVec4f(1.0, 1.0, 0.0, 1.0, M * TVec4f.Create(2.0, 1.0, -5.0, 1.0),
    'Ortho maps known point');

  M := Perspective(Single(HALF_PI), Single(1.0), Single(1.0), Single(11.0));
  CheckNear(1.0, M[0, 0], 0.000001, 'Perspective stores aspect scale');
  CheckNear(-1.0, M[2, 3], 0.000001, 'Perspective stores homogeneous divide');
  Clip := M * TVec4f.Create(0.0, 0.0, -1.0, 1.0);
  CheckNear(-1.0, Clip.Z / Clip.W, 0.000001, 'Perspective maps near plane');
  Clip := M * TVec4f.Create(0.0, 0.0, -11.0, 1.0);
  CheckNear(1.0, Clip.Z / Clip.W, 0.000001, 'Perspective maps far plane');

  ExpectArgumentErrorMessage('Perspective: aspect must be positive', 'Perspective zero aspect',
    @RaisePerspectiveZeroAspect);
end;

procedure TestOrthoAllowsReversedBounds;
var
  M: TMat4f;
  D: TMat4d;
begin
  M := Ortho(Single(2.0), Single(-2.0), Single(3.0), Single(-3.0), Single(10.0), Single(0.0));
  CheckNear(-0.5, M[0, 0], 0.000001, 'Ortho reversed X flips horizontal axis');
  CheckNear(-1.0 / 3.0, M[1, 1], 0.000001, 'Ortho reversed Y flips vertical axis');
  CheckNear(0.2, M[2, 2], 0.000001, 'Ortho reversed depth flips Z axis');
  CheckVec4f(-1.0, -1.0, -1.0, 1.0, M * TVec4f.Create(2.0, 3.0, -10.0, 1.0),
    'Ortho reversed bounds map near corner');
  CheckVec4f(1.0, 1.0, 1.0, 1.0, M * TVec4f.Create(-2.0, -3.0, 0.0, 1.0),
    'Ortho reversed bounds map far corner');

  D := Ortho(Double(2.0), Double(-2.0), Double(3.0), Double(-3.0), Double(10.0), Double(0.0));
  CheckVec4d(-1.0, -1.0, -1.0, 1.0, D * TVec4d.Create(2.0, 3.0, -10.0, 1.0),
    'Double Ortho reversed bounds map near corner');
  CheckVec4d(1.0, 1.0, 1.0, 1.0, D * TVec4d.Create(-2.0, -3.0, 0.0, 1.0),
    'Double Ortho reversed bounds map far corner');
end;

procedure TestModelAndViewBuilders;
var
  M: TMat4f;
begin
  CheckVec4f(6.0, 8.0, 10.0, 1.0,
    Translate(Single(5.0), Single(6.0), Single(7.0)) * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'Translate stores offset in column 3');
  CheckVec4f(2.0, 6.0, 12.0, 1.0,
    Scale(Single(2.0), Single(3.0), Single(4.0)) * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'Scale maps known point');
  CheckVec4f(0.0, 1.0, 0.0, 1.0,
    RotateZ(Single(HALF_PI)) * TVec4f.Create(1.0, 0.0, 0.0, 1.0), 'RotateZ quarter turn');
  CheckVec4f(0.0, 0.0, 1.0, 1.0,
    RotateX(Single(HALF_PI)) * TVec4f.Create(0.0, 1.0, 0.0, 1.0), 'RotateX quarter turn');
  CheckVec4f(1.0, 0.0, 0.0, 1.0,
    RotateY(Single(HALF_PI)) * TVec4f.Create(0.0, 0.0, 1.0, 1.0), 'RotateY quarter turn');

  M := Translate(Single(5.0), Single(6.0), Single(7.0)) *
    RotateZ(Single(HALF_PI)) * Scale(Single(2.0), Single(3.0), Single(4.0));
  CheckVec4f(5.0, 8.0, 7.0, 1.0, M * TVec4f.Create(1.0, 0.0, 0.0, 1.0),
    'Local composition is Translate * Rotate * Scale');

  M := LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero, TVec3f.Create(0.0, 1.0, 0.0));
  CheckVec4f(0.0, 0.0, -5.0, 1.0, M * TVec4f.Create(0.0, 0.0, 0.0, 1.0),
    'LookAt maps target down negative Z');
end;

procedure TestLookAtIgnoresUpMagnitude;
var
  SingleBase: TMat4f;
  SingleScaled: TMat4f;
  DoubleBase: TMat4d;
  DoubleScaled: TMat4d;
begin
  SingleBase := LookAt(
    TVec3f.Create(1.0, 2.0, 5.0),
    TVec3f.Create(2.0, 4.0, 1.0),
    TVec3f.Create(0.0, 2.0, 1.0));
  SingleScaled := LookAt(
    TVec3f.Create(1.0, 2.0, 5.0),
    TVec3f.Create(2.0, 4.0, 1.0),
    TVec3f.Create(0.0, 10.0, 5.0));
  Check(TMat4f.Equals(SingleBase, SingleScaled, Single(0.000001)),
    'LookAt single ignores positive up scaling');

  DoubleBase := LookAt(
    TVec3d.Create(-3.0, 1.0, 7.0),
    TVec3d.Create(0.0, 5.0, 2.0),
    TVec3d.Create(1.0, 2.0, 3.0));
  DoubleScaled := LookAt(
    TVec3d.Create(-3.0, 1.0, 7.0),
    TVec3d.Create(0.0, 5.0, 2.0),
    TVec3d.Create(4.0, 8.0, 12.0));
  Check(TMat4d.Equals(DoubleBase, DoubleScaled, 0.000000000001),
    'LookAt double ignores positive up scaling');
end;

procedure TestLookAtUpDirectionControlsRoll;
var
  SingleUp: TMat4f;
  SingleDown: TMat4f;
  DoubleUp: TMat4d;
  DoubleDown: TMat4d;
begin
  SingleUp := LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero, TVec3f.Create(0.0, 1.0, 0.0));
  SingleDown := LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero, TVec3f.Create(0.0, -1.0, 0.0));
  CheckVec4f(0.0, 0.0, 0.0, 1.0, SingleUp * TVec4f.Create(0.0, 0.0, 5.0, 1.0),
    'LookAt single positive up maps eye to origin');
  CheckVec4f(0.0, 0.0, 0.0, 1.0, SingleDown * TVec4f.Create(0.0, 0.0, 5.0, 1.0),
    'LookAt single negative up maps eye to origin');
  CheckVec4f(0.0, 0.0, -5.0, 1.0, SingleUp * TVec4f.Create(0.0, 0.0, 0.0, 1.0),
    'LookAt single positive up keeps target on negative Z');
  CheckVec4f(0.0, 0.0, -5.0, 1.0, SingleDown * TVec4f.Create(0.0, 0.0, 0.0, 1.0),
    'LookAt single negative up keeps target on negative Z');
  CheckVec4f(0.0, 1.0, 0.0, 1.0, SingleUp * TVec4f.Create(0.0, 1.0, 5.0, 1.0),
    'LookAt single positive up keeps eye-above point on positive Y');
  CheckVec4f(0.0, -1.0, 0.0, 1.0, SingleDown * TVec4f.Create(0.0, 1.0, 5.0, 1.0),
    'LookAt single negative up flips eye-above point to negative Y');

  DoubleUp := LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero, TVec3d.Create(0.0, 1.0, 0.0));
  DoubleDown := LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero, TVec3d.Create(0.0, -1.0, 0.0));
  CheckVec4d(0.0, 0.0, 0.0, 1.0, DoubleUp * TVec4d.Create(0.0, 0.0, 5.0, 1.0),
    'LookAt double positive up maps eye to origin');
  CheckVec4d(0.0, 0.0, 0.0, 1.0, DoubleDown * TVec4d.Create(0.0, 0.0, 5.0, 1.0),
    'LookAt double negative up maps eye to origin');
  CheckVec4d(0.0, 0.0, -5.0, 1.0, DoubleUp * TVec4d.Create(0.0, 0.0, 0.0, 1.0),
    'LookAt double positive up keeps target on negative Z');
  CheckVec4d(0.0, 0.0, -5.0, 1.0, DoubleDown * TVec4d.Create(0.0, 0.0, 0.0, 1.0),
    'LookAt double negative up keeps target on negative Z');
  CheckVec4d(0.0, 1.0, 0.0, 1.0, DoubleUp * TVec4d.Create(0.0, 1.0, 5.0, 1.0),
    'LookAt double positive up keeps eye-above point on positive Y');
  CheckVec4d(0.0, -1.0, 0.0, 1.0, DoubleDown * TVec4d.Create(0.0, 1.0, 5.0, 1.0),
    'LookAt double negative up flips eye-above point to negative Y');
end;

procedure TestCamera2DAndDoubleBuilders;
var
  M: TMat4f;
  D: TMat4d;
begin
  M := Camera2D(Single(10.0), Single(20.0), Single(2.0), 100, 50);
  CheckVec4f(0.0, 0.0, 0.0, 1.0, M * TVec4f.Create(10.0, 20.0, 0.0, 1.0),
    'Camera2D maps center to origin');
  CheckVec4f(1.0, -1.0, 0.0, 1.0, M * TVec4f.Create(35.0, 32.5, 0.0, 1.0),
    'Camera2D keeps screen-space positive Y down');

  D := Translate(Double(5.0), Double(6.0), Double(7.0)) * RotateZ(Double(HALF_PI)) *
    Scale(Double(2.0), Double(3.0), Double(4.0));
  CheckVec4d(5.0, 8.0, 7.0, 1.0, D * TVec4d.Create(1.0, 0.0, 0.0, 1.0),
    'Double transform builders compose');

  ExpectArgumentErrorMessage('Camera2D: zoom must be positive',
    'Camera2D zero zoom', @RaiseCamera2DZeroZoom);
end;

procedure TestDirectDoubleBuilderParity;
var
  M: TMat4d;
  Clip: TVec4d;
begin
  M := Perspective(Double(HALF_PI), Double(2.0), Double(1.0), Double(11.0));
  CheckNear(0.5, M[0, 0], 0.000000000001, 'Double Perspective stores aspect scale');
  CheckNear(1.0, M[1, 1], 0.000000000001, 'Double Perspective stores vertical scale');
  CheckNear(-1.0, M[2, 3], 0.000000000001, 'Double Perspective stores homogeneous divide');
  Clip := M * TVec4d.Create(0.0, 0.0, -1.0, 1.0);
  CheckNear(-1.0, Clip.Z / Clip.W, 0.000000000001, 'Double Perspective maps near plane');
  Clip := M * TVec4d.Create(0.0, 0.0, -11.0, 1.0);
  CheckNear(1.0, Clip.Z / Clip.W, 0.000000000001, 'Double Perspective maps far plane');

  CheckVec4d(6.0, 8.0, 10.0, 1.0,
    Translate(Double(5.0), Double(6.0), Double(7.0)) * TVec4d.Create(1.0, 2.0, 3.0, 1.0),
    'Double Translate stores offset in column 3');
  CheckVec4d(2.0, 6.0, 12.0, 1.0,
    Scale(Double(2.0), Double(3.0), Double(4.0)) * TVec4d.Create(1.0, 2.0, 3.0, 1.0),
    'Double Scale maps known point');
  CheckVec4d(0.0, 1.0, 0.0, 1.0,
    RotateZ(Double(HALF_PI)) * TVec4d.Create(1.0, 0.0, 0.0, 1.0),
    'Double RotateZ quarter turn');
  CheckVec4d(0.0, 0.0, 1.0, 1.0,
    RotateX(Double(HALF_PI)) * TVec4d.Create(0.0, 1.0, 0.0, 1.0),
    'Double RotateX quarter turn');
  CheckVec4d(1.0, 0.0, 0.0, 1.0,
    RotateY(Double(HALF_PI)) * TVec4d.Create(0.0, 0.0, 1.0, 1.0),
    'Double RotateY quarter turn');

  M := LookAt(TVec3d.Create(1.0, 2.0, 5.0), TVec3d.Create(1.0, 2.0, 4.0),
    TVec3d.Create(0.0, 1.0, 0.0));
  CheckVec4d(0.0, 0.0, 0.0, 1.0, M * TVec4d.Create(1.0, 2.0, 5.0, 1.0),
    'Double LookAt maps eye to origin');
  CheckVec4d(0.0, 0.0, -1.0, 1.0, M * TVec4d.Create(1.0, 2.0, 4.0, 1.0),
    'Double LookAt maps target down negative Z');

  M := Camera2D(Double(10.0), Double(20.0), Double(2.0), 100, 50);
  CheckVec4d(0.0, 0.0, 0.0, 1.0, M * TVec4d.Create(10.0, 20.0, 0.0, 1.0),
    'Double Camera2D maps center to origin');
  CheckVec4d(1.0, -1.0, 0.0, 1.0, M * TVec4d.Create(35.0, 32.5, 0.0, 1.0),
    'Double Camera2D keeps screen-space positive Y down');
end;

procedure TestNonFiniteInputsFailFast;
begin
  ExpectArgumentErrorMessage('Ortho: left must be finite', 'Ortho single infinite left',
    @RaiseOrthoInfiniteLeftSingle);
  ExpectArgumentErrorMessage('Ortho: left must be finite', 'Ortho double infinite left',
    @RaiseOrthoInfiniteLeftDouble);
  ExpectArgumentErrorMessage('Ortho: right must be finite', 'Ortho single infinite right',
    @RaiseOrthoInfiniteRightSingle);
  ExpectArgumentErrorMessage('Ortho: right must be finite', 'Ortho double infinite right',
    @RaiseOrthoInfiniteRightDouble);
  ExpectArgumentErrorMessage('Ortho: bottom must be finite', 'Ortho single infinite bottom',
    @RaiseOrthoInfiniteBottomSingle);
  ExpectArgumentErrorMessage('Ortho: bottom must be finite', 'Ortho double infinite bottom',
    @RaiseOrthoInfiniteBottomDouble);
  ExpectArgumentErrorMessage('Ortho: top must be finite', 'Ortho single infinite top',
    @RaiseOrthoInfiniteTopSingle);
  ExpectArgumentErrorMessage('Ortho: top must be finite', 'Ortho double infinite top',
    @RaiseOrthoInfiniteTopDouble);
  ExpectArgumentErrorMessage('Ortho: near plane must be finite', 'Ortho single NaN near',
    @RaiseOrthoNaNNearSingle);
  ExpectArgumentErrorMessage('Ortho: near plane must be finite', 'Ortho double NaN near',
    @RaiseOrthoNaNNearDouble);
  ExpectArgumentErrorMessage('Ortho: far plane must be finite', 'Ortho single infinite far',
    @RaiseOrthoInfiniteFarSingle);
  ExpectArgumentErrorMessage('Ortho: far plane must be finite', 'Ortho double infinite far',
    @RaiseOrthoInfiniteFarDouble);
  ExpectArgumentErrorMessage('Perspective: vertical FOV must be finite',
    'Perspective single NaN FOV', @RaisePerspectiveNaNFovSingle);
  ExpectArgumentErrorMessage('Perspective: vertical FOV must be finite',
    'Perspective double NaN FOV', @RaisePerspectiveNaNFovDouble);
  ExpectArgumentErrorMessage('Perspective: aspect must be finite',
    'Perspective single infinite aspect', @RaisePerspectiveInfiniteAspectSingle);
  ExpectArgumentErrorMessage('Perspective: aspect must be finite',
    'Perspective double infinite aspect', @RaisePerspectiveInfiniteAspectDouble);
  ExpectArgumentErrorMessage('Perspective: near plane must be finite',
    'Perspective single NaN near', @RaisePerspectiveNaNNearSingle);
  ExpectArgumentErrorMessage('Perspective: near plane must be finite',
    'Perspective double NaN near', @RaisePerspectiveNaNNearDouble);
  ExpectArgumentErrorMessage('Perspective: far plane must be finite',
    'Perspective single infinite far', @RaisePerspectiveInfiniteFarSingle);
  ExpectArgumentErrorMessage('Perspective: far plane must be finite',
    'Perspective double infinite far', @RaisePerspectiveInfiniteFarDouble);
  ExpectArgumentErrorMessage('Perspective: vertical FOV must be positive',
    'Perspective single zero FOV', @RaisePerspectiveZeroFovSingle);
  ExpectArgumentErrorMessage('Perspective: near plane must be positive',
    'Perspective single zero near', @RaisePerspectiveZeroNearSingle);
  ExpectArgumentErrorMessage('Perspective: near plane must be positive',
    'Perspective double zero near', @RaisePerspectiveZeroNearDouble);
  ExpectArgumentErrorMessage('LookAt: eye must be finite', 'LookAt single infinite eye',
    @RaiseLookAtInfiniteEyeSingle);
  ExpectArgumentErrorMessage('LookAt: eye must be finite', 'LookAt double infinite eye',
    @RaiseLookAtInfiniteEyeDouble);
  ExpectArgumentErrorMessage('LookAt: target must be finite', 'LookAt single infinite target',
    @RaiseLookAtInfiniteTargetSingle);
  ExpectArgumentErrorMessage('LookAt: target must be finite', 'LookAt double infinite target',
    @RaiseLookAtInfiniteTargetDouble);
  ExpectArgumentErrorMessage('LookAt: up vector must be finite', 'LookAt single infinite up',
    @RaiseLookAtInfiniteUpSingle);
  ExpectArgumentErrorMessage('LookAt: up vector must be finite', 'LookAt double infinite up',
    @RaiseLookAtInfiniteUpDouble);
  ExpectArgumentErrorMessage('Translate: X must be finite', 'Translate single NaN X',
    @RaiseTranslateNaNSingle);
  ExpectArgumentErrorMessage('Translate: X must be finite', 'Translate double NaN X',
    @RaiseTranslateNaNDouble);
  ExpectArgumentErrorMessage('Translate: Y must be finite', 'Translate single infinite Y',
    @RaiseTranslateInfinityYSingle);
  ExpectArgumentErrorMessage('Translate: Y must be finite', 'Translate double infinite Y',
    @RaiseTranslateInfinityYDouble);
  ExpectArgumentErrorMessage('Translate: Z must be finite', 'Translate single infinite Z',
    @RaiseTranslateInfinityZSingle);
  ExpectArgumentErrorMessage('Translate: Z must be finite', 'Translate double infinite Z',
    @RaiseTranslateInfinityDouble);
  ExpectArgumentErrorMessage('Scale: X must be finite', 'Scale single infinite X',
    @RaiseScaleInfinityXSingle);
  ExpectArgumentErrorMessage('Scale: X must be finite', 'Scale double infinite X',
    @RaiseScaleInfinityXDouble);
  ExpectArgumentErrorMessage('Scale: Y must be finite', 'Scale single NaN Y',
    @RaiseScaleNaNSingle);
  ExpectArgumentErrorMessage('Scale: Y must be finite', 'Scale double infinite Y',
    @RaiseScaleInfinityYDouble);
  ExpectArgumentErrorMessage('Scale: Z must be finite', 'Scale single NaN Z',
    @RaiseScaleNaNZSingle);
  ExpectArgumentErrorMessage('Scale: Z must be finite', 'Scale double infinite Z',
    @RaiseScaleInfinityZDouble);
  ExpectArgumentErrorMessage('RotateX: radians must be finite', 'RotateX single NaN',
    @RaiseRotateXNaNSingle);
  ExpectArgumentErrorMessage('RotateX: radians must be finite', 'RotateX double infinity',
    @RaiseRotateXInfinityDouble);
  ExpectArgumentErrorMessage('RotateY: radians must be finite', 'RotateY single NaN',
    @RaiseRotateYNaNSingle);
  ExpectArgumentErrorMessage('RotateY: radians must be finite', 'RotateY double infinity',
    @RaiseRotateYInfinityDouble);
  ExpectArgumentErrorMessage('RotateZ: radians must be finite', 'RotateZ single NaN',
    @RaiseRotateZNaNSingle);
  ExpectArgumentErrorMessage('RotateZ: radians must be finite', 'RotateZ double infinity',
    @RaiseRotateZInfinityDouble);
  ExpectArgumentErrorMessage('Camera2D: zoom must be finite', 'Camera2D single NaN zoom',
    @RaiseCamera2DNaNZoomSingle);
  ExpectArgumentErrorMessage('Camera2D: zoom must be finite', 'Camera2D double NaN zoom',
    @RaiseCamera2DNaNZoomDouble);
  ExpectArgumentErrorMessage('Camera2D: center X must be finite',
    'Camera2D single infinite center X', @RaiseCamera2DInfiniteCenterSingle);
  ExpectArgumentErrorMessage('Camera2D: center X must be finite',
    'Camera2D double infinite center X', @RaiseCamera2DInfiniteCenterDouble);
  ExpectArgumentErrorMessage('Camera2D: center Y must be finite',
    'Camera2D single infinite center Y', @RaiseCamera2DInfiniteCenterYSingle);
  ExpectArgumentErrorMessage('Camera2D: center Y must be finite',
    'Camera2D double infinite center Y', @RaiseCamera2DInfiniteCenterYDouble);
end;

procedure TestGeometryGuardMessages;
begin
  ExpectArgumentErrorMessage('Ortho: width must not be zero',
    'Ortho zero width', @RaiseOrthoZeroWidth);
  ExpectArgumentErrorMessage('Ortho: width must not be zero',
    'Ortho double zero width', @RaiseOrthoZeroWidthDouble);
  ExpectArgumentErrorMessage('Ortho: height must not be zero',
    'Ortho single zero height', @RaiseOrthoZeroHeightSingle);
  ExpectArgumentErrorMessage('Ortho: height must not be zero',
    'Ortho double zero height', @RaiseOrthoZeroHeightDouble);
  ExpectArgumentErrorMessage('Ortho: depth must not be zero',
    'Ortho single zero depth', @RaiseOrthoZeroDepthSingle);
  ExpectArgumentErrorMessage('Ortho: depth must not be zero',
    'Ortho double zero depth', @RaiseOrthoZeroDepthDouble);
  ExpectArgumentErrorMessage('Perspective: aspect must be positive',
    'Perspective double zero aspect', @RaisePerspectiveZeroAspectDouble);
  ExpectArgumentErrorMessage('Perspective: vertical FOV must be positive',
    'Perspective double zero FOV', @RaisePerspectiveZeroFovDouble);
  ExpectArgumentErrorMessage('Perspective: far plane must be greater than near plane',
    'Perspective single far not greater', @RaisePerspectiveFarNotGreaterSingle);
  ExpectArgumentErrorMessage('Perspective: far plane must be greater than near plane',
    'Perspective double far not greater', @RaisePerspectiveFarNotGreaterDouble);
  ExpectArgumentErrorMessage('Perspective: far plane must be greater than near plane',
    'Perspective single far less than near', @RaisePerspectiveFarLessThanNearSingle);
  ExpectArgumentErrorMessage('Perspective: far plane must be greater than near plane',
    'Perspective double far less than near', @RaisePerspectiveFarLessThanNearDouble);
  ExpectArgumentErrorMessage('Perspective: vertical FOV is invalid',
    'Perspective single invalid FOV', @RaisePerspectiveInvalidFovSingle);
  ExpectArgumentErrorMessage('Perspective: vertical FOV is invalid',
    'Perspective double invalid FOV', @RaisePerspectiveInvalidFovDouble);
  ExpectArgumentErrorMessage('LookAt: eye and target must differ',
    'LookAt single coincident eye/target', @RaiseLookAtCoincidentEyeSingle);
  ExpectArgumentErrorMessage('LookAt: eye and target must differ',
    'LookAt double coincident eye/target', @RaiseLookAtCoincidentEyeDouble);
  ExpectArgumentErrorMessage('LookAt: up vector must not be parallel to forward',
    'LookAt single parallel up', @RaiseLookAtParallelUpSingle);
  ExpectArgumentErrorMessage('LookAt: up vector must not be parallel to forward',
    'LookAt double parallel up', @RaiseLookAtParallelUpDouble);
  ExpectArgumentErrorMessage('Camera2D: zoom must be positive',
    'Camera2D single zero zoom', @RaiseCamera2DZeroZoom);
  ExpectArgumentErrorMessage('Camera2D: zoom must be positive',
    'Camera2D double zero zoom', @RaiseCamera2DZeroZoomDouble);
  ExpectArgumentErrorMessage('Camera2D: zoom must be positive',
    'Camera2D single negative zoom', @RaiseCamera2DNegativeZoomSingle);
  ExpectArgumentErrorMessage('Camera2D: zoom must be positive',
    'Camera2D double negative zoom', @RaiseCamera2DNegativeZoomDouble);
  ExpectArgumentErrorMessage('Camera2D: viewport width must be positive',
    'Camera2D single zero width', @RaiseCamera2DZeroWidthSingle);
  ExpectArgumentErrorMessage('Camera2D: viewport width must be positive',
    'Camera2D double zero width', @RaiseCamera2DZeroWidthDouble);
  ExpectArgumentErrorMessage('Camera2D: viewport height must be positive',
    'Camera2D single negative height', @RaiseCamera2DNegativeHeightSingle);
  ExpectArgumentErrorMessage('Camera2D: viewport height must be positive',
    'Camera2D double negative height', @RaiseCamera2DNegativeHeightDouble);
end;

begin
  T := TTestRunner.Create('nextpas.core.math.transform');
  T.Run('projection builders', @TestProjectionBuilders);
  T.Run('Ortho allows reversed bounds', @TestOrthoAllowsReversedBounds);
  T.Run('model and view builders', @TestModelAndViewBuilders);
  T.Run('LookAt ignores up magnitude', @TestLookAtIgnoresUpMagnitude);
  T.Run('LookAt up direction controls roll', @TestLookAtUpDirectionControlsRoll);
  T.Run('camera2d and double builders', @TestCamera2DAndDoubleBuilders);
  T.Run('direct double builder parity', @TestDirectDoubleBuilderParity);
  T.Run('non-finite inputs fail fast', @TestNonFiniteInputsFailFast);
  T.Run('geometry guards report public contract messages', @TestGeometryGuardMessages);
  T.Summary;
end.
