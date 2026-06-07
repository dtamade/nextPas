program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math;

var
  T: TTestRunner;

procedure CheckNear(const AExpected, AActual: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then
    LDelta := -LDelta;
  Check(LDelta <= 0.000001, AMessage);
end;

procedure TestFacadeScalarAndTrig;
begin
  CheckNear(5.0, Clamp(10.0, 0.0, 5.0), 'facade re-exports scalar Clamp');
  CheckNear(5.0, Clamp(Single(10.0), Single(0.0), Single(5.0)), 'facade re-exports Single Clamp');
  CheckNear(PI_VALUE, DegToRad(180.0), 'facade re-exports DegToRad');
  CheckNear(1.0, Sin(HALF_PI), 'facade re-exports trig Sin');
  CheckNear(1.0, Sin(Single(HALF_PI)), 'facade re-exports Single trig Sin');
end;

procedure TestFacadeRoundingSurface;
begin
  CheckNear(3.0, Min(3.0, 4.0), 'facade exposes Min');
  CheckNear(4.0, Max(3.0, 4.0), 'facade exposes Max');
  CheckNear(3.0, Min(Single(3.0), Single(4.0)), 'facade exposes Single Min');
  CheckEqual(Int64(4), Ceil(3.2), 'facade exposes Ceil');
  CheckEqual(Int64(4), Ceil(Single(3.2)), 'facade exposes Single Ceil');
  CheckEqual(Int64(-2), Floor(-1.2), 'facade exposes Floor');
  CheckEqual(Int64(3), Round(2.6), 'facade exposes Round');
  CheckEqual(Int64(-2), Trunc(-2.6), 'facade exposes Trunc');
end;

procedure TestFacadeNewScalarSurface;
begin
  CheckEqual(Int64(6), GCD(Int64(12), Int64(18)), 'facade exposes GCD');
  CheckEqual(Int64(36), LCM(Int64(12), Int64(18)), 'facade exposes LCM');
  CheckNear(5.0, Hypot(3.0, 4.0), 'facade exposes Hypot');
  CheckNear(1.5, Fmod(5.5, 2.0), 'facade exposes Fmod');
  CheckNear(0.5, SmoothStep(0.0, 1.0, 0.5), 'facade exposes SmoothStep');
  CheckNear(0.5, SmoothStep(Single(0.0), Single(1.0), Single(0.5)), 'facade exposes Single SmoothStep');
end;

procedure TestFacadeVectorSurface;
var
  V: TVec3f;
  M: TMat4f;
  Q: TQuatf;
begin
  V := TVec3f.Create(1.0, 2.0, 3.0);
  CheckNear(14.0, V.LengthSqr, 'facade exposes TVec3f');
  CheckNear(1.0, TVec3f.Cross(TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0)).Z, 'facade exposes TVec3f.Cross');
  M := TMat4f.Identity;
  CheckNear(1.0, (M * TVec4f.Create(1.0, 0.0, 0.0, 1.0)).X, 'facade exposes TMat4f');
  Q := TQuatf.Identity;
  CheckNear(1.0, Q.W, 'facade exposes TQuatf');
  CheckNear(6.0, (Translate(Single(5.0), Single(0.0), Single(0.0)) *
    TVec4f.Create(1.0, 0.0, 0.0, 1.0)).X, 'facade exposes Translate');
  CheckNear(0.25, EaseInQuad(0.5), 'facade exposes easing functions');
end;

procedure TestFacadeRandomSurface;
var
  Rng: TRandomGen;
  Noise: TNoiseGen;
begin
  Rng := TRandomGen.Create(123456789);
  Noise := TNoiseGen.Create(2468);
  try
    CheckEqual(Int64(1644187685), Int64(Rng.NextInt), 'facade exposes TRandomGen');
    CheckNear(0.146484375, Noise.Noise1D(0.25), 'facade exposes TNoiseGen');
  finally
    Noise.Free;
    Rng.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math facade');
  T.Run('scalar and trig re-export', @TestFacadeScalarAndTrig);
  T.Run('facade scalar rounding surface', @TestFacadeRoundingSurface);
  T.Run('facade new scalar surface', @TestFacadeNewScalarSurface);
  T.Run('facade vector surface', @TestFacadeVectorSurface);
  T.Run('facade random surface', @TestFacadeRandomSurface);
  T.Summary;
end.
