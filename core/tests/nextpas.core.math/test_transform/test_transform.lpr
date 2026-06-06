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

begin
  T := TTestRunner.Create('nextpas.core.math.transform');
  T.Run('projection builders', @TestProjectionBuilders);
  T.Run('model and view builders', @TestModelAndViewBuilders);
  T.Run('camera2d and double builders', @TestCamera2DAndDoubleBuilders);
  T.Summary;
end.
