program test_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
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

procedure RaiseFacadeClampReversedBounds; forward;

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

procedure TestFacadeScalarAndTrig;
begin
  CheckNear(5.0, Clamp(10.0, 0.0, 5.0), 'facade re-exports scalar Clamp');
  CheckNear(5.0, Clamp(Single(10.0), Single(0.0), Single(5.0)), 'facade re-exports Single Clamp');
  ExpectArgumentErrorMessage('Clamp: minimum must not exceed maximum',
    'facade Clamp reversed bounds', @RaiseFacadeClampReversedBounds);
  CheckNear(PI_VALUE, DegToRad(180.0), 'facade re-exports DegToRad');
  CheckNear(PI_VALUE, DegToRad(Single(180.0)), 'facade re-exports Single DegToRad');
  CheckNear(180.0, RadToDeg(PI_VALUE), 'facade re-exports RadToDeg');
  CheckNear(180.0, RadToDeg(Single(PI_VALUE)), 'facade re-exports Single RadToDeg');
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

procedure TestFacadeRootForwarderCompileSurface;
var
  B: Boolean;
  F: Single;
  D: Double;
  I: Int64;
  I32: Int32;
  SU: SizeUInt;
  U32: UInt32;
  V3f: TVec3f;
  V3d: TVec3d;
  M4f: TMat4f;
  M4d: TMat4d;
begin
  if ParamCount < 0 then
  begin
    B := nextpas.core.math.IsAddOverflow(SizeUInt(1), SizeUInt(2));
    B := B or nextpas.core.math.IsAddOverflow(UInt32(1), UInt32(2));
    B := B or nextpas.core.math.IsMulOverflow(SizeUInt(1), SizeUInt(2));
    B := B or nextpas.core.math.IsMulOverflow(UInt32(1), UInt32(2));
    SU := nextpas.core.math.Min(SizeUInt(1), SizeUInt(2));
    SU := nextpas.core.math.Max(SU, SizeUInt(2));
    U32 := UInt32(SU);
    I := nextpas.core.math.Min(SizeInt(-1), SizeInt(2));
    I := nextpas.core.math.Max(SizeInt(I), SizeInt(2));
    D := nextpas.core.math.Min(1.0, 2.0);
    D := nextpas.core.math.Max(D, 2.0);
    F := nextpas.core.math.Min(Single(1.0), Single(2.0));
    F := nextpas.core.math.Max(F, Single(2.0));
    D := nextpas.core.math.Clamp(D, 0.0, 3.0);
    F := nextpas.core.math.Clamp(F, Single(0.0), Single(3.0));
    I32 := nextpas.core.math.Clamp(Int32(2), Int32(0), Int32(3));
    D := nextpas.core.math.Lerp(0.0, 2.0, 0.5);
    F := nextpas.core.math.Lerp(Single(0.0), Single(2.0), Single(0.5));
    D := nextpas.core.math.InverseLerp(0.0, 2.0, 1.0);
    F := nextpas.core.math.InverseLerp(Single(0.0), Single(2.0), Single(1.0));
    D := nextpas.core.math.Wrap(3.0, 0.0, 2.0);
    F := nextpas.core.math.Wrap(Single(3.0), Single(0.0), Single(2.0));
    D := nextpas.core.math.SmoothStep(0.0, 1.0, 0.5);
    F := nextpas.core.math.SmoothStep(Single(0.0), Single(1.0), Single(0.5));
    I := nextpas.core.math.Floor(D);
    I := I + nextpas.core.math.Floor(F);
    I := I + nextpas.core.math.Ceil(D);
    I := I + nextpas.core.math.Ceil(F);
    I := I + nextpas.core.math.Round(D);
    I := I + nextpas.core.math.Round(F);
    I := I + nextpas.core.math.Trunc(D);
    I := I + nextpas.core.math.Trunc(F);
    D := nextpas.core.math.Frac(D);
    F := nextpas.core.math.Frac(F);
    D := nextpas.core.math.Abs(-D);
    F := nextpas.core.math.Abs(-F);
    I32 := nextpas.core.math.Abs(-I32);
    I := nextpas.core.math.Abs(Int64(-I));
    D := nextpas.core.math.Sign(D);
    F := nextpas.core.math.Sign(F);
    I32 := nextpas.core.math.Sign(I32);
    I := nextpas.core.math.Sign(I);
    B := B or nextpas.core.math.IsNaN(D);
    B := B or nextpas.core.math.IsNaN(F);
    B := B or nextpas.core.math.IsInfinite(D);
    B := B or nextpas.core.math.IsInfinite(F);
    B := B or nextpas.core.math.FloatEquals(1.0, 1.0, 0.0);
    B := B or nextpas.core.math.FloatEquals(Single(1.0), Single(1.0), Single(0.0));
    B := B or nextpas.core.math.FloatIsZero(0.0, 0.0);
    B := B or nextpas.core.math.FloatIsZero(Single(0.0), Single(0.0));
    D := nextpas.core.math.DegToRad(180.0);
    F := nextpas.core.math.DegToRad(Single(180.0));
    D := nextpas.core.math.RadToDeg(D);
    F := nextpas.core.math.RadToDeg(F);
    I := nextpas.core.math.GCD(12, 18);
    I := nextpas.core.math.LCM(I, 18);
    D := nextpas.core.math.Hypot(3.0, 4.0);
    F := nextpas.core.math.Hypot(Single(3.0), Single(4.0));
    D := nextpas.core.math.Fmod(5.5, 2.0);
    F := nextpas.core.math.Fmod(Single(5.5), Single(2.0));
    D := nextpas.core.math.Sin(0.0) + nextpas.core.math.Cos(0.0) +
      nextpas.core.math.Tan(0.0) + nextpas.core.math.ArcSin(0.5) +
      nextpas.core.math.ArcCos(0.5) + nextpas.core.math.ArcTan(1.0) +
      nextpas.core.math.ArcTan2(1.0, 1.0) + nextpas.core.math.Exp(0.0) +
      nextpas.core.math.Ln(1.0) + nextpas.core.math.Log2(8.0) +
      nextpas.core.math.Log10(100.0) + nextpas.core.math.Power(2.0, 3.0) +
      nextpas.core.math.Sqrt(4.0);
    F := nextpas.core.math.Sin(Single(0.0)) + nextpas.core.math.Cos(Single(0.0)) +
      nextpas.core.math.Tan(Single(0.0)) + nextpas.core.math.ArcSin(Single(0.5)) +
      nextpas.core.math.ArcCos(Single(0.5)) + nextpas.core.math.ArcTan(Single(1.0)) +
      nextpas.core.math.ArcTan2(Single(1.0), Single(1.0)) + nextpas.core.math.Exp(Single(0.0)) +
      nextpas.core.math.Ln(Single(1.0)) + nextpas.core.math.Log2(Single(8.0)) +
      nextpas.core.math.Log10(Single(100.0)) + nextpas.core.math.Power(Single(2.0), Single(3.0)) +
      nextpas.core.math.Sqrt(Single(4.0));
    V3f := TVec3f.Create(0.0, 0.0, 1.0);
    V3d := TVec3d.Create(0.0, 0.0, 1.0);
    M4f := nextpas.core.math.Ortho(Single(-1.0), Single(1.0), Single(-1.0), Single(1.0),
      Single(0.0), Single(10.0));
    M4d := nextpas.core.math.Ortho(Double(-1.0), Double(1.0), Double(-1.0), Double(1.0),
      Double(0.0), Double(10.0));
    M4f := nextpas.core.math.Perspective(Single(HALF_PI), Single(1.0), Single(1.0), Single(10.0));
    M4d := nextpas.core.math.Perspective(Double(HALF_PI), Double(1.0), Double(1.0), Double(10.0));
    M4f := nextpas.core.math.LookAt(V3f, TVec3f.Zero, TVec3f.Create(0.0, 1.0, 0.0));
    M4d := nextpas.core.math.LookAt(V3d, TVec3d.Zero, TVec3d.Create(Double(0.0), Double(1.0), Double(0.0)));
    M4f := nextpas.core.math.Translate(Single(1.0), Single(2.0), Single(3.0));
    M4d := nextpas.core.math.Translate(Double(1.0), Double(2.0), Double(3.0));
    M4f := nextpas.core.math.Scale(Single(1.0), Single(2.0), Single(3.0));
    M4d := nextpas.core.math.Scale(Double(1.0), Double(2.0), Double(3.0));
    M4f := nextpas.core.math.RotateX(Single(0.25));
    M4d := nextpas.core.math.RotateX(Double(0.25));
    M4f := nextpas.core.math.RotateY(Single(0.25));
    M4d := nextpas.core.math.RotateY(Double(0.25));
    M4f := nextpas.core.math.RotateZ(Single(0.25));
    M4d := nextpas.core.math.RotateZ(Double(0.25));
    M4f := nextpas.core.math.Camera2D(Single(0.0), Single(0.0), Single(1.0), 100, 100);
    M4d := nextpas.core.math.Camera2D(Double(0.0), Double(0.0), Double(1.0), 100, 100);
    D := nextpas.core.math.EaseLinear(0.5) + nextpas.core.math.EaseInQuad(0.5) +
      nextpas.core.math.EaseOutQuad(0.5) + nextpas.core.math.EaseInOutQuad(0.5) +
      nextpas.core.math.EaseInCubic(0.5) + nextpas.core.math.EaseOutCubic(0.5) +
      nextpas.core.math.EaseInOutCubic(0.5) + nextpas.core.math.EaseInQuart(0.5) +
      nextpas.core.math.EaseOutQuart(0.5) + nextpas.core.math.EaseInOutQuart(0.5) +
      nextpas.core.math.EaseInExpo(0.5) + nextpas.core.math.EaseOutExpo(0.5) +
      nextpas.core.math.EaseInOutExpo(0.5) + nextpas.core.math.EaseInElastic(0.5) +
      nextpas.core.math.EaseOutElastic(0.5) + nextpas.core.math.EaseInOutElastic(0.5) +
      nextpas.core.math.EaseInBack(0.5) + nextpas.core.math.EaseOutBack(0.5) +
      nextpas.core.math.EaseInOutBack(0.5) + nextpas.core.math.EaseInBounce(0.5) +
      nextpas.core.math.EaseOutBounce(0.5) + nextpas.core.math.EaseInOutBounce(0.5);
    U32 := U32 + UInt32(I32);
    if B or (I = Low(Int64)) or (U32 = High(UInt32)) or (D < -1.0e300) or
      (F < -1.0e30) or (M4f.Data[0, 0] < -1.0e30) or
      (M4d.Data[0, 0] < -1.0e300) then
      Halt(1);
  end;
  Check(True, 'facade root forwarder compile surface');
end;

procedure RaiseFacadeClampReversedBounds;
begin
  Clamp(1.0, 2.0, 1.0);
end;

begin
  T := TTestRunner.Create('nextpas.core.math facade');
  T.Run('scalar and trig re-export', @TestFacadeScalarAndTrig);
  T.Run('facade scalar rounding surface', @TestFacadeRoundingSurface);
  T.Run('facade new scalar surface', @TestFacadeNewScalarSurface);
  T.Run('facade vector surface', @TestFacadeVectorSurface);
  T.Run('facade random surface', @TestFacadeRandomSurface);
  T.Run('facade root forwarder compile surface', @TestFacadeRootForwarderCompileSurface);
  T.Summary;
end.
