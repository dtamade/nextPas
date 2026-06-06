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

procedure ExpectArgumentError(const AName: string; const AProc: TTestProc);
begin
  try
    AProc;
  except
    on E: EArgumentError do
      Exit;
    on E: Exception do
      Fail(AName + ': expected EArgumentError, got ' + E.ClassName);
  end;
  Fail(AName + ': expected EArgumentError');
end;

procedure RaiseOrthoZeroWidth;
begin
  Ortho(Single(1.0), Single(1.0), Single(-1.0), Single(1.0), Single(0.0), Single(10.0));
end;

procedure RaisePerspectiveZeroAspect;
begin
  Perspective(Single(HALF_PI), Single(0.0), Single(1.0), Single(10.0));
end;

procedure RaiseCamera2DZeroZoom;
begin
  Camera2D(Single(0.0), Single(0.0), Single(0.0), 100, 100);
end;

procedure RaiseOrthoZeroDepthDouble;
begin
  Ortho(Double(-1.0), Double(1.0), Double(-1.0), Double(1.0), Double(5.0), Double(5.0));
end;

procedure RaisePerspectiveFarNotGreaterSingle;
begin
  Perspective(Single(HALF_PI), Single(1.0), Single(5.0), Single(5.0));
end;

procedure RaiseLookAtCoincidentEyeSingle;
begin
  LookAt(TVec3f.Create(1.0, 2.0, 3.0), TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(0.0, 1.0, 0.0));
end;

procedure RaiseLookAtParallelUpDouble;
begin
  LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero, TVec3d.Create(0.0, 0.0, -2.0));
end;

procedure RaiseCamera2DZeroWidthSingle;
begin
  Camera2D(Single(0.0), Single(0.0), Single(1.0), 0, 100);
end;

procedure RaiseCamera2DNegativeHeightDouble;
begin
  Camera2D(Double(0.0), Double(0.0), Double(1.0), 100, -1);
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

procedure RaisePerspectiveNaNFovSingle;
begin
  Perspective(SingleNaN, Single(1.0), Single(1.0), Single(10.0));
end;

procedure RaisePerspectiveNaNFovDouble;
begin
  Perspective(DoubleNaN, Double(1.0), Double(1.0), Double(10.0));
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

procedure RaiseLookAtInfiniteUpDouble;
begin
  LookAt(TVec3d.Create(0.0, 0.0, 5.0), TVec3d.Zero,
    TVec3d.Create(0.0, DoubleInfinity, 0.0));
end;

procedure RaiseTranslateNaNSingle;
begin
  Translate(SingleNaN, Single(0.0), Single(0.0));
end;

procedure RaiseTranslateInfinityDouble;
begin
  Translate(Double(0.0), Double(0.0), DoubleInfinity);
end;

procedure RaiseTranslateInfinityYDouble;
begin
  Translate(Double(0.0), DoubleInfinity, Double(0.0));
end;

procedure RaiseScaleNaNSingle;
begin
  Scale(Single(1.0), SingleNaN, Single(1.0));
end;

procedure RaiseScaleInfinityDouble;
begin
  Scale(Double(1.0), DoubleInfinity, Double(1.0));
end;

procedure RaiseScaleInfinityXDouble;
begin
  Scale(DoubleInfinity, Double(1.0), Double(1.0));
end;

procedure RaiseScaleNaNZSingle;
begin
  Scale(Single(1.0), Single(1.0), SingleNaN);
end;

procedure RaiseRotateZNaNSingle;
begin
  RotateZ(SingleNaN);
end;

procedure RaiseRotateXInfinityDouble;
begin
  RotateX(DoubleInfinity);
end;

procedure RaiseRotateYInfinityDouble;
begin
  RotateY(DoubleInfinity);
end;

procedure RaiseCamera2DNaNZoomSingle;
begin
  Camera2D(Single(0.0), Single(0.0), SingleNaN, 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterDouble;
begin
  Camera2D(DoubleInfinity, Double(0.0), Double(1.0), 100, 100);
end;

procedure RaiseCamera2DInfiniteCenterYDouble;
begin
  Camera2D(Double(0.0), DoubleInfinity, Double(1.0), 100, 100);
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

  ExpectArgumentError('Ortho zero width', @RaiseOrthoZeroWidth);
  ExpectArgumentError('Perspective zero aspect', @RaisePerspectiveZeroAspect);
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

  ExpectArgumentError('Camera2D zero zoom', @RaiseCamera2DZeroZoom);
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
  ExpectArgumentError('Ortho single infinite far', @RaiseOrthoInfiniteFarSingle);
  ExpectArgumentError('Ortho double infinite far', @RaiseOrthoInfiniteFarDouble);
  ExpectArgumentError('Perspective single NaN FOV', @RaisePerspectiveNaNFovSingle);
  ExpectArgumentError('Perspective double NaN FOV', @RaisePerspectiveNaNFovDouble);
  ExpectArgumentErrorMessage('LookAt: eye must be finite', 'LookAt single infinite eye',
    @RaiseLookAtInfiniteEyeSingle);
  ExpectArgumentErrorMessage('LookAt: eye must be finite', 'LookAt double infinite eye',
    @RaiseLookAtInfiniteEyeDouble);
  ExpectArgumentErrorMessage('LookAt: target must be finite', 'LookAt single infinite target',
    @RaiseLookAtInfiniteTargetSingle);
  ExpectArgumentErrorMessage('LookAt: up vector must be finite', 'LookAt double infinite up',
    @RaiseLookAtInfiniteUpDouble);
  ExpectArgumentErrorMessage('Translate: X must be finite', 'Translate single NaN X',
    @RaiseTranslateNaNSingle);
  ExpectArgumentErrorMessage('Translate: Y must be finite', 'Translate double infinite Y',
    @RaiseTranslateInfinityYDouble);
  ExpectArgumentErrorMessage('Translate: Z must be finite', 'Translate double infinite Z',
    @RaiseTranslateInfinityDouble);
  ExpectArgumentErrorMessage('Scale: X must be finite', 'Scale double infinite X',
    @RaiseScaleInfinityXDouble);
  ExpectArgumentErrorMessage('Scale: Y must be finite', 'Scale single NaN Y',
    @RaiseScaleNaNSingle);
  ExpectArgumentErrorMessage('Scale: Z must be finite', 'Scale single NaN Z',
    @RaiseScaleNaNZSingle);
  ExpectArgumentErrorMessage('RotateX: radians must be finite', 'RotateX double infinity',
    @RaiseRotateXInfinityDouble);
  ExpectArgumentErrorMessage('RotateY: radians must be finite', 'RotateY double infinity',
    @RaiseRotateYInfinityDouble);
  ExpectArgumentErrorMessage('RotateZ: radians must be finite', 'RotateZ single NaN',
    @RaiseRotateZNaNSingle);
  ExpectArgumentErrorMessage('Camera2D: zoom must be finite', 'Camera2D single NaN zoom',
    @RaiseCamera2DNaNZoomSingle);
  ExpectArgumentErrorMessage('Camera2D: center X must be finite',
    'Camera2D double infinite center X', @RaiseCamera2DInfiniteCenterDouble);
  ExpectArgumentErrorMessage('Camera2D: center Y must be finite',
    'Camera2D double infinite center Y', @RaiseCamera2DInfiniteCenterYDouble);
end;

procedure TestGeometryGuardMessages;
begin
  ExpectArgumentErrorMessage('Ortho: depth must not be zero',
    'Ortho double zero depth', @RaiseOrthoZeroDepthDouble);
  ExpectArgumentErrorMessage('Perspective: far plane must be greater than near plane',
    'Perspective single far not greater', @RaisePerspectiveFarNotGreaterSingle);
  ExpectArgumentErrorMessage('LookAt: eye and target must differ',
    'LookAt single coincident eye/target', @RaiseLookAtCoincidentEyeSingle);
  ExpectArgumentErrorMessage('LookAt: up vector must not be parallel to forward',
    'LookAt double parallel up', @RaiseLookAtParallelUpDouble);
  ExpectArgumentErrorMessage('Camera2D: viewport width must be positive',
    'Camera2D single zero width', @RaiseCamera2DZeroWidthSingle);
  ExpectArgumentErrorMessage('Camera2D: viewport height must be positive',
    'Camera2D double negative height', @RaiseCamera2DNegativeHeightDouble);
end;

begin
  T := TTestRunner.Create('nextpas.core.math.transform');
  T.Run('projection builders', @TestProjectionBuilders);
  T.Run('Ortho allows reversed bounds', @TestOrthoAllowsReversedBounds);
  T.Run('model and view builders', @TestModelAndViewBuilders);
  T.Run('LookAt ignores up magnitude', @TestLookAtIgnoresUpMagnitude);
  T.Run('camera2d and double builders', @TestCamera2DAndDoubleBuilders);
  T.Run('direct double builder parity', @TestDirectDoubleBuilderParity);
  T.Run('non-finite inputs fail fast', @TestNonFiniteInputsFailFast);
  T.Run('geometry guards report public contract messages', @TestGeometryGuardMessages);
  T.Summary;
end.
