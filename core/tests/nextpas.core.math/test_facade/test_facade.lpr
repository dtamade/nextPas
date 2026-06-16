program test_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math;

var
  T: TTestRunner;

function DoubleFromBits(const ABits: UInt64): Double;
type
  TDoubleBits = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: UInt64);
  end;
var
  LCast: TDoubleBits;
begin
  LCast.Bits := ABits;
  Result := LCast.Value;
end;

function MakeNaN: Double;
begin
  Result := DoubleFromBits(UInt64($7FF8000000000000));
end;

function MakeSingleNaN: Single;
type
  TSingleBits = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: UInt32);
  end;
var
  LCast: TSingleBits;
begin
  LCast.Bits := UInt32($7FC00000);
  Result := LCast.Value;
end;

function MakePositiveInfinity: Double;
begin
  Result := DoubleFromBits(UInt64($7FF0000000000000));
end;

function MakeDoubleNegativeZero: Double;
begin
  Result := DoubleFromBits(UInt64($8000000000000000));
end;

procedure CheckNear(const AExpected, AActual: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then
    LDelta := -LDelta;
  Check(LDelta <= 0.000001, AMessage);
end;

function IsDoublePositiveZero(const AValue: Double): Boolean;
type
  TDoubleBits = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: UInt64);
  end;
var
  LCast: TDoubleBits;
begin
  LCast.Value := AValue;
  Result := LCast.Bits = UInt64(0);
end;

function IsSinglePositiveZero(const AValue: Single): Boolean;
type
  TSingleBits = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: UInt32);
  end;
var
  LCast: TSingleBits;
begin
  LCast.Value := AValue;
  Result := LCast.Bits = UInt32(0);
end;

function SameDoubleBits(const ALeft, ARight: Double): Boolean;
type
  TDoubleBits = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: UInt64);
  end;
var
  LLeft: TDoubleBits;
  LRight: TDoubleBits;
begin
  LLeft.Value := ALeft;
  LRight.Value := ARight;
  Result := LLeft.Bits = LRight.Bits;
end;

function SameSingleBits(const ALeft, ARight: Single): Boolean;
type
  TSingleBits = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: UInt32);
  end;
var
  LLeft: TSingleBits;
  LRight: TSingleBits;
begin
  LLeft.Value := ALeft;
  LRight.Value := ARight;
  Result := LLeft.Bits = LRight.Bits;
end;

procedure RaiseFacadeClampReversedBounds; forward;
procedure RaiseFacadeWrapDoubleReversedBounds; forward;
procedure RaiseFacadeWrapSingleReversedBounds; forward;
procedure RaiseFacadeWrapDoubleNaNValue; forward;
procedure RaiseFacadeWrapSingleNaNValue; forward;

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

procedure TestFacadeWrapErrorSemantics;
begin
  CheckNear(10.0, Wrap(370.0, 0.0, 360.0), 'facade Wrap Double high');
  CheckNear(10.0, Wrap(Single(370.0), Single(0.0), Single(360.0)), 'facade Wrap Single high');
  CheckNear(5.0, Wrap(10.0, 5.0, 5.0), 'facade Wrap Double equal bounds returns minimum');
  CheckNear(5.0, Wrap(Single(10.0), Single(5.0), Single(5.0)),
    'facade Wrap Single equal bounds returns minimum');
  ExpectArgumentErrorMessage('Wrap: minimum must not exceed maximum',
    'facade Wrap Double reversed bounds', @RaiseFacadeWrapDoubleReversedBounds);
  ExpectArgumentErrorMessage('Wrap: minimum must not exceed maximum',
    'facade Wrap Single reversed bounds', @RaiseFacadeWrapSingleReversedBounds);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'facade Wrap Double NaN value', @RaiseFacadeWrapDoubleNaNValue);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'facade Wrap Single NaN value', @RaiseFacadeWrapSingleNaNValue);
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
var
  LWideRemainder: Extended;
begin
  CheckEqual(Int64(6), GCD(Int64(12), Int64(18)), 'facade exposes GCD');
  CheckEqual(Int64(36), LCM(Int64(12), Int64(18)), 'facade exposes LCM');
  CheckNear(5.0, Hypot(3.0, 4.0), 'facade exposes Hypot');
  CheckNear(1.5, Fmod(5.5, 2.0), 'facade exposes Fmod');
  LWideRemainder := Fmod(1.0e308, 3.0);
  Check((LWideRemainder = LWideRemainder) and (LWideRemainder > -3.0) and
    (LWideRemainder < 3.0),
    'facade Fmod huge untyped finite literals choose wide finite remainder path');
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

procedure TestFacadeVectorLerpScalarParityContracts;
var
  A3f: TVec3f;
  B3f: TVec3f;
  L3f: TVec3f;
  A4d: TVec4d;
  B4d: TVec4d;
  L4d: TVec4d;
begin
  A3f := TVec3f.Create(Single(-2.0), Single(4.0), Single(8.0));
  B3f := TVec3f.Create(Single(6.0), Single(-4.0), Single(0.0));
  L3f := TVec3f.Lerp(A3f, B3f, Single(0.25));
  CheckNear(nextpas.core.math.Lerp(A3f.X, B3f.X, Single(0.25)), L3f.X,
    'facade TVec3f Lerp scalar parity X');
  CheckNear(nextpas.core.math.Lerp(A3f.Y, B3f.Y, Single(0.25)), L3f.Y,
    'facade TVec3f Lerp scalar parity Y');
  CheckNear(nextpas.core.math.Lerp(A3f.Z, B3f.Z, Single(0.25)), L3f.Z,
    'facade TVec3f Lerp scalar parity Z');

  A4d := TVec4d.Create(-4.0, 2.0, 8.0, -10.0);
  B4d := TVec4d.Create(12.0, -6.0, 0.0, 14.0);
  L4d := TVec4d.Lerp(A4d, B4d, 1.0);
  CheckNear(nextpas.core.math.Lerp(A4d.X, B4d.X, 1.0), L4d.X,
    'facade TVec4d Lerp scalar parity t=1 X');
  CheckNear(nextpas.core.math.Lerp(A4d.Y, B4d.Y, 1.0), L4d.Y,
    'facade TVec4d Lerp scalar parity t=1 Y');
  CheckNear(nextpas.core.math.Lerp(A4d.Z, B4d.Z, 1.0), L4d.Z,
    'facade TVec4d Lerp scalar parity t=1 Z');
  CheckNear(nextpas.core.math.Lerp(A4d.W, B4d.W, 1.0), L4d.W,
    'facade TVec4d Lerp scalar parity t=1 W');
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

procedure TestFacadeTypeAliasCompileSurface;
var
  LVec2f: TVec2f;
  LVec3f: TVec3f;
  LVec4f: TVec4f;
  LVec2d: TVec2d;
  LVec3d: TVec3d;
  LVec4d: TVec4d;
  LMat3f: TMat3f;
  LMat4f: TMat4f;
  LMat3d: TMat3d;
  LMat4d: TMat4d;
  LQuatf: TQuatf;
  LQuatd: TQuatd;
  LEasing: TEasingFunction;
  LState: TRandomState;
  LRng: TRandomGen;
  LNoise: TNoiseGen;
begin
  LVec2f := TVec2f.Create(1.0, 2.0);
  LVec3f := TVec3f.Create(LVec2f.X, LVec2f.Y, 3.0);
  LVec4f := TVec4f.Create(LVec3f.X, LVec3f.Y, LVec3f.Z, 1.0);
  LVec2d := TVec2d.Create(Double(1.0), Double(2.0));
  LVec3d := TVec3d.Create(LVec2d.X, LVec2d.Y, Double(3.0));
  LVec4d := TVec4d.Create(LVec3d.X, LVec3d.Y, LVec3d.Z, Double(1.0));
  LMat3f := TMat3f.Identity;
  LMat4f := TMat4f.Identity;
  LMat3d := TMat3d.Identity;
  LMat4d := TMat4d.Identity;
  LQuatf := TQuatf.Identity;
  LQuatd := TQuatd.Identity;
  LEasing := @EaseLinear;
  LState.S0 := UInt64(1);
  LState.S1 := UInt64(2);
  LRng := nil;
  LNoise := nil;
  Check((LVec4f.W = 1.0) and (LVec4d.W = 1.0),
    'facade vector aliases compile');
  Check((LMat3f.Data[0, 0] = 1.0) and (LMat4f.Data[0, 0] = 1.0) and
    (LMat3d.Data[0, 0] = 1.0) and (LMat4d.Data[0, 0] = 1.0),
    'facade matrix aliases compile');
  Check((LQuatf.W = 1.0) and (LQuatd.W = 1.0), 'facade quaternion aliases compile');
  Check((LEasing <> nil) and (LEasing(0.5) = 0.5), 'facade easing alias compiles');
  Check((LState.S0 = UInt64(1)) and (LState.S1 = UInt64(2)) and
    (LRng = nil) and (LNoise = nil), 'facade random aliases compile');
end;

procedure TestFacadeRootForwarderCompileSurface;
var
  B: Boolean;
  F: Single;
  D: Double;
  E: Extended;
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
    E := nextpas.core.math.Fmod(Extended(5.5), Extended(2.0));
    B := B or (E = E);
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
  Check(nextpas.core.math.FloatEquals(nextpas.core.math.Clamp(2.0, 0.0, 3.0),
    nextpas.core.math.Lerp(0.0, 4.0, 0.5), 0.0),
    'facade root forwarder compile surface touches scalar family');
  Check(nextpas.core.math.FloatEquals(nextpas.core.math.Sin(nextpas.core.math.HALF_PI),
    nextpas.core.math.Sqrt(1.0), 0.000001),
    'facade root forwarder compile surface touches trig family');
  Check(nextpas.core.math.FloatEquals(
    (nextpas.core.math.Translate(1.0, 0.0, 0.0) *
      TVec4f.Create(1.0, 0.0, 0.0, 1.0)).X,
    2.0, 0.000001),
    'facade root forwarder compile surface touches transform family');
  Check(nextpas.core.math.FloatEquals(nextpas.core.math.EaseInQuad(0.5),
    0.25, 0.000001),
    'facade root forwarder compile surface touches easing family');
end;

procedure TestFacadePublicMemberCompileSurface;
var
  B: Boolean;
  I: Integer;
  F: Single;
  D: Double;
  V2fA: TVec2f;
  V2fB: TVec2f;
  V2fC: TVec2f;
  V3fA: TVec3f;
  V3fB: TVec3f;
  V3fC: TVec3f;
  V4fA: TVec4f;
  V4fB: TVec4f;
  V4fC: TVec4f;
  V2dA: TVec2d;
  V2dB: TVec2d;
  V2dC: TVec2d;
  V3dA: TVec3d;
  V3dB: TVec3d;
  V3dC: TVec3d;
  V4dA: TVec4d;
  V4dB: TVec4d;
  V4dC: TVec4d;
  M3fA: TMat3f;
  M3fB: TMat3f;
  M3fInv: TMat3f;
  M4fA: TMat4f;
  M4fB: TMat4f;
  M4fInv: TMat4f;
  M3dA: TMat3d;
  M3dB: TMat3d;
  M3dInv: TMat3d;
  M4dA: TMat4d;
  M4dB: TMat4d;
  M4dInv: TMat4d;
  QfA: TQuatf;
  QfB: TQuatf;
  QdA: TQuatd;
  QdB: TQuatd;
  AxisF: TVec3f;
  AxisD: TVec3d;
  AngleF: Single;
  AngleD: Double;
  State: TRandomState;
  Rng: TRandomGen;
  Noise: TNoiseGen;
  Values: array[0..3] of Integer;
begin
  if ParamCount < 0 then
  begin
    V2fA := TVec2f.Create(Single(1.0), Single(2.0));
    V2fB := TVec2f.Zero;
    V2fC := V2fA + V2fB;
    V2fC := V2fC - V2fA;
    V2fC := -V2fC;
    V2fC := V2fC * Single(2.0);
    V2fC := Single(2.0) * V2fC;
    V2fC := V2fC / Single(2.0);
    V2fC := TVec2f.MulComponents(V2fA, V2fC);
    V2fC := TVec2f.DivComponents(V2fC, TVec2f.Create(Single(1.0), Single(1.0)));
    F := TVec2f.Dot(V2fA, V2fC) + V2fC.LengthSqr + V2fC.Length;
    V2fC := TVec2f.Lerp(V2fA, V2fC, Single(0.5)).Normalize;
    B := TVec2f.Equals(V2fC, V2fC, Single(0.0));

    V3fA := TVec3f.Create(Single(1.0), Single(2.0), Single(3.0));
    V3fB := TVec3f.Zero;
    V3fC := V3fA + V3fB;
    V3fC := V3fC - V3fA;
    V3fC := -V3fC;
    V3fC := V3fC * Single(2.0);
    V3fC := Single(2.0) * V3fC;
    V3fC := V3fC / Single(2.0);
    V3fC := TVec3f.MulComponents(V3fA, V3fC);
    V3fC := TVec3f.DivComponents(V3fC, TVec3f.Create(Single(1.0), Single(1.0), Single(1.0)));
    F := F + TVec3f.Dot(V3fA, V3fC) + V3fC.LengthSqr + V3fC.Length;
    V3fC := TVec3f.Cross(V3fA, V3fC);
    V3fC := TVec3f.Lerp(V3fA, V3fC, Single(0.5)).Normalize;
    B := B or TVec3f.Equals(V3fC, V3fC, Single(0.0));

    V4fA := TVec4f.Create(Single(1.0), Single(2.0), Single(3.0), Single(4.0));
    V4fB := TVec4f.Zero;
    V4fC := V4fA + V4fB;
    V4fC := V4fC - V4fA;
    V4fC := -V4fC;
    V4fC := V4fC * Single(2.0);
    V4fC := Single(2.0) * V4fC;
    V4fC := V4fC / Single(2.0);
    V4fC := TVec4f.MulComponents(V4fA, V4fC);
    V4fC := TVec4f.DivComponents(V4fC,
      TVec4f.Create(Single(1.0), Single(1.0), Single(1.0), Single(1.0)));
    F := F + TVec4f.Dot(V4fA, V4fC) + V4fC.LengthSqr + V4fC.Length;
    V4fC := TVec4f.Lerp(V4fA, V4fC, Single(0.5)).Normalize;
    B := B or TVec4f.Equals(V4fC, V4fC, Single(0.0));

    V2dA := TVec2d.Create(1.0, 2.0);
    V2dB := TVec2d.Zero;
    V2dC := V2dA + V2dB;
    V2dC := V2dC - V2dA;
    V2dC := -V2dC;
    V2dC := V2dC * 2.0;
    V2dC := 2.0 * V2dC;
    V2dC := V2dC / 2.0;
    V2dC := TVec2d.MulComponents(V2dA, V2dC);
    V2dC := TVec2d.DivComponents(V2dC, TVec2d.Create(1.0, 1.0));
    D := TVec2d.Dot(V2dA, V2dC) + V2dC.LengthSqr + V2dC.Length;
    V2dC := TVec2d.Lerp(V2dA, V2dC, 0.5).Normalize;
    B := B or TVec2d.Equals(V2dC, V2dC, 0.0);

    V3dA := TVec3d.Create(1.0, 2.0, 3.0);
    V3dB := TVec3d.Zero;
    V3dC := V3dA + V3dB;
    V3dC := V3dC - V3dA;
    V3dC := -V3dC;
    V3dC := V3dC * 2.0;
    V3dC := 2.0 * V3dC;
    V3dC := V3dC / 2.0;
    V3dC := TVec3d.MulComponents(V3dA, V3dC);
    V3dC := TVec3d.DivComponents(V3dC, TVec3d.Create(1.0, 1.0, 1.0));
    D := D + TVec3d.Dot(V3dA, V3dC) + V3dC.LengthSqr + V3dC.Length;
    V3dC := TVec3d.Cross(V3dA, V3dC);
    V3dC := TVec3d.Lerp(V3dA, V3dC, 0.5).Normalize;
    B := B or TVec3d.Equals(V3dC, V3dC, 0.0);

    V4dA := TVec4d.Create(1.0, 2.0, 3.0, 4.0);
    V4dB := TVec4d.Zero;
    V4dC := V4dA + V4dB;
    V4dC := V4dC - V4dA;
    V4dC := -V4dC;
    V4dC := V4dC * 2.0;
    V4dC := 2.0 * V4dC;
    V4dC := V4dC / 2.0;
    V4dC := TVec4d.MulComponents(V4dA, V4dC);
    V4dC := TVec4d.DivComponents(V4dC, TVec4d.Create(1.0, 1.0, 1.0, 1.0));
    D := D + TVec4d.Dot(V4dA, V4dC) + V4dC.LengthSqr + V4dC.Length;
    V4dC := TVec4d.Lerp(V4dA, V4dC, 0.5).Normalize;
    B := B or TVec4d.Equals(V4dC, V4dC, 0.0);

    M3fA := TMat3f.Create(V3fA, V3fB, V3fC);
    M3fB := TMat3f.Identity + TMat3f.Zero;
    M3fA := M3fA + M3fB;
    M3fA := M3fA - M3fB;
    M3fA := -M3fA;
    M3fA := M3fA * Single(2.0);
    M3fA := Single(2.0) * M3fA;
    V3fC := M3fA * V3fA;
    M3fA := M3fA * M3fB;
    M3fA[0, 0] := M3fA[0, 0];
    M3fA.Rows[0] := M3fA.Rows[0];
    M3fA.Columns[0] := M3fA.Columns[0];
    F := F + M3fA.Transpose.Determinant;
    B := B or M3fA.TryInverse(M3fInv) or TMat3f.Equals(M3fA, M3fB, Single(0.0));
    M3fInv := M3fB.Inverse;

    M4fA := TMat4f.Create(V4fA, V4fB, V4fC,
      TVec4f.Create(Single(0.0), Single(0.0), Single(0.0), Single(1.0)));
    M4fB := TMat4f.Identity + TMat4f.Zero;
    M4fA := M4fA + M4fB;
    M4fA := M4fA - M4fB;
    M4fA := -M4fA;
    M4fA := M4fA * Single(2.0);
    M4fA := Single(2.0) * M4fA;
    V4fC := M4fA * V4fA;
    M4fA := M4fA * M4fB;
    M4fA[0, 0] := M4fA[0, 0];
    M4fA.Rows[0] := M4fA.Rows[0];
    M4fA.Columns[0] := M4fA.Columns[0];
    F := F + M4fA.Transpose.Determinant;
    B := B or M4fA.TryInverse(M4fInv) or TMat4f.Equals(M4fA, M4fB, Single(0.0));
    M4fInv := M4fB.Inverse;

    M3dA := TMat3d.Create(V3dA, V3dB, V3dC);
    M3dB := TMat3d.Identity + TMat3d.Zero;
    M3dA := M3dA + M3dB;
    M3dA := M3dA - M3dB;
    M3dA := -M3dA;
    M3dA := M3dA * 2.0;
    M3dA := 2.0 * M3dA;
    V3dC := M3dA * V3dA;
    M3dA := M3dA * M3dB;
    M3dA[0, 0] := M3dA[0, 0];
    M3dA.Rows[0] := M3dA.Rows[0];
    M3dA.Columns[0] := M3dA.Columns[0];
    D := D + M3dA.Transpose.Determinant;
    B := B or M3dA.TryInverse(M3dInv) or TMat3d.Equals(M3dA, M3dB, 0.0);
    M3dInv := M3dB.Inverse;

    M4dA := TMat4d.Create(V4dA, V4dB, V4dC, TVec4d.Create(0.0, 0.0, 0.0, 1.0));
    M4dB := TMat4d.Identity + TMat4d.Zero;
    M4dA := M4dA + M4dB;
    M4dA := M4dA - M4dB;
    M4dA := -M4dA;
    M4dA := M4dA * 2.0;
    M4dA := 2.0 * M4dA;
    V4dC := M4dA * V4dA;
    M4dA := M4dA * M4dB;
    M4dA[0, 0] := M4dA[0, 0];
    M4dA.Rows[0] := M4dA.Rows[0];
    M4dA.Columns[0] := M4dA.Columns[0];
    D := D + M4dA.Transpose.Determinant;
    B := B or M4dA.TryInverse(M4dInv) or TMat4d.Equals(M4dA, M4dB, 0.0);
    M4dInv := M4dB.Inverse;

    QfA := TQuatf.Create(Single(0.0), Single(0.0), Single(0.0), Single(1.0));
    QfB := TQuatf.Identity;
    QfA := QfA * QfB;
    QfA := TQuatf.FromAxisAngle(TVec3f.Create(Single(0.0), Single(0.0), Single(1.0)),
      Single(0.25));
    QfB := TQuatf.Slerp(QfA, QfB, Single(0.5));
    QfB := TQuatf.Nlerp(QfA, QfB, Single(0.5));
    B := B or TQuatf.Equals(QfA, QfB, Single(0.0));
    QfB.ToAxisAngle(AxisF, AngleF);
    M3fA := QfB.ToRotationMatrix;
    V3fC := QfB.Rotate(V3fA);
    QfB := QfB.Conjugate.Normalize;

    QdA := TQuatd.Create(0.0, 0.0, 0.0, 1.0);
    QdB := TQuatd.Identity;
    QdA := QdA * QdB;
    QdA := TQuatd.FromAxisAngle(TVec3d.Create(0.0, 0.0, 1.0), 0.25);
    QdB := TQuatd.Slerp(QdA, QdB, 0.5);
    QdB := TQuatd.Nlerp(QdA, QdB, 0.5);
    B := B or TQuatd.Equals(QdA, QdB, 0.0);
    QdB.ToAxisAngle(AxisD, AngleD);
    M3dA := QdB.ToRotationMatrix;
    V3dC := QdB.Rotate(V3dA);
    QdB := QdB.Conjugate.Normalize;

    Rng := TRandomGen.Create(1);
    Noise := TNoiseGen.Create(2);
    try
      Rng.SetSeed(3);
      State := Rng.State;
      Rng.State := State;
      I := Rng.NextInt + Rng.NextIntRange(1, 3);
      F := F + Rng.NextFloat + Rng.NextFloatRange(Single(0.0), Single(1.0)) +
        Rng.NextGaussian;
      D := D + Rng.NextDouble;
      B := B or Rng.NextBool(Single(0.5));
      V2fC := Rng.NextVec2InCircle + Rng.NextVec2OnCircle;
      I := I + Rng.Roll(6) + Rng.RollMultiple(2, 6) +
        Rng.WeightedChoice([Single(1.0), Single(2.0)]);
      Values[0] := 1;
      Values[1] := 2;
      Values[2] := 3;
      Values[3] := 4;
      Rng.Shuffle(Values);

      Noise.SetSeed(4);
      D := D + Noise.Noise1D(0.25) + Noise.Noise2D(0.25, 0.5) +
        Noise.Noise3D(0.25, 0.5, 0.75) + Noise.FBM1D(0.25, 2) +
        Noise.FBM2D(0.25, 0.5, 2) + Noise.FBM3D(0.25, 0.5, 0.75, 2);
    finally
      Noise.Free;
      Rng.Free;
    end;

    if B or (I = Low(Integer)) or (F < -1.0e30) or (D < -1.0e300) or
      (M3fInv.Data[0, 0] < -1.0e30) or (M4fInv.Data[0, 0] < -1.0e30) or
      (M3dInv.Data[0, 0] < -1.0e300) or (M4dInv.Data[0, 0] < -1.0e300) or
      (M3fA.Data[0, 0] < -1.0e30) or (M3dA.Data[0, 0] < -1.0e300) or
      (AxisF.X < -1.0e30) or (AxisD.X < -1.0e300) or
      (AngleF < -1.0e30) or (AngleD < -1.0e300) or
      (V2fC.X < -1.0e30) or (V3fC.X < -1.0e30) or (V4fC.X < -1.0e30) or
      (V2dC.X < -1.0e300) or (V3dC.X < -1.0e300) or (V4dC.X < -1.0e300) then
      Halt(1);
  end;

  Check(True, 'facade public member compile surface touches vector members');
  Check(True, 'facade public member compile surface touches matrix members');
  Check(True, 'facade public member compile surface touches quaternion members');
  Check(True, 'facade public member compile surface touches random and noise members');
end;

procedure TestFacadeRootTrigDeclarationParityCompileSurface;
var
  D: Double;
  F: Single;
begin
  if ParamCount < 0 then
  begin
    D := nextpas.core.math.Sin(Double(0.0));
    D := D + nextpas.core.math.Cos(Double(0.0));
    D := D + nextpas.core.math.Tan(Double(0.0));
    D := D + nextpas.core.math.ArcSin(Double(0.5));
    D := D + nextpas.core.math.ArcCos(Double(0.5));
    D := D + nextpas.core.math.ArcTan(Double(1.0));
    D := D + nextpas.core.math.ArcTan2(Double(1.0), Double(1.0));
    D := D + nextpas.core.math.Exp(Double(0.0));
    D := D + nextpas.core.math.Ln(Double(1.0));
    D := D + nextpas.core.math.Log2(Double(8.0));
    D := D + nextpas.core.math.Log10(Double(100.0));
    D := D + nextpas.core.math.Power(Double(2.0), Double(3.0));
    D := D + nextpas.core.math.Sqrt(Double(4.0));

    F := nextpas.core.math.Sin(Single(0.0));
    F := F + nextpas.core.math.Cos(Single(0.0));
    F := F + nextpas.core.math.Tan(Single(0.0));
    F := F + nextpas.core.math.ArcSin(Single(0.5));
    F := F + nextpas.core.math.ArcCos(Single(0.5));
    F := F + nextpas.core.math.ArcTan(Single(1.0));
    F := F + nextpas.core.math.ArcTan2(Single(1.0), Single(1.0));
    F := F + nextpas.core.math.Exp(Single(0.0));
    F := F + nextpas.core.math.Ln(Single(1.0));
    F := F + nextpas.core.math.Log2(Single(8.0));
    F := F + nextpas.core.math.Log10(Single(100.0));
    F := F + nextpas.core.math.Power(Single(2.0), Single(3.0));
    F := F + nextpas.core.math.Sqrt(Single(4.0));

    if (D < -1.0e300) or (F < -1.0e30) then
      Halt(1);
  end;
  Check(True, 'facade root trig declaration parity compile surface');
end;

procedure TestFacadePowerFiniteIdentityPrecisionContracts;
begin
  CheckNear(2.25, nextpas.core.math.Power(Double(1.5), Double(2.0)),
    'facade Power Double finite identity precision');
  CheckNear(0.5, nextpas.core.math.Power(Double(4.0), Double(-0.5)),
    'facade Power Double reciprocal square root precision');
  CheckNear(-3.375, nextpas.core.math.Power(Double(-1.5), Double(3.0)),
    'facade Power Double negative odd finite precision');
  CheckNear(2.25, nextpas.core.math.Power(Single(1.5), Single(2.0)),
    'facade Power Single finite identity precision');
  CheckNear(0.5, nextpas.core.math.Power(Single(4.0), Single(-0.5)),
    'facade Power Single reciprocal square root precision');
  CheckNear(-3.375, nextpas.core.math.Power(Single(-1.5), Single(3.0)),
    'facade Power Single negative odd finite precision');
end;

procedure TestFacadeLogExactIdentityContracts;
begin
  Check(IsDoublePositiveZero(nextpas.core.math.Log2(1.0)),
    'facade Log2(1)=+0 exact bits');
  Check(IsSinglePositiveZero(nextpas.core.math.Log2(Single(1.0))),
    'facade Log2(Single 1)=+0 exact bits');
  Check(IsDoublePositiveZero(nextpas.core.math.Log10(1.0)),
    'facade Log10(1)=+0 exact bits');
  Check(IsSinglePositiveZero(nextpas.core.math.Log10(Single(1.0))),
    'facade Log10(Single 1)=+0 exact bits');
  Check(SameDoubleBits(1.0, nextpas.core.math.Log2(2.0)),
    'facade Log2(2)=1 exact bits');
  Check(SameSingleBits(Single(1.0), nextpas.core.math.Log2(Single(2.0))),
    'facade Log2(Single 2)=1 exact bits');
  Check(SameDoubleBits(1.0, nextpas.core.math.Log10(10.0)),
    'facade Log10(10)=1 exact bits');
  Check(SameSingleBits(Single(1.0), nextpas.core.math.Log10(Single(10.0))),
    'facade Log10(Single 10)=1 exact bits');
end;

procedure TestFacadeTrigIeeeDomainSmoke;
var
  LPositiveInfinity: Double;
  LExpPositiveInfinity: Double;
begin
  LPositiveInfinity := MakePositiveInfinity;
  LExpPositiveInfinity := nextpas.core.math.Exp(LPositiveInfinity);
  Check(nextpas.core.math.IsNaN(nextpas.core.math.ArcSin(Double(1.0001))),
    'facade ArcSin domain overflow returns NaN');
  Check(nextpas.core.math.IsNaN(nextpas.core.math.Ln(Double(-1.0))),
    'facade Ln negative input returns NaN');
  Check(nextpas.core.math.IsNaN(nextpas.core.math.Sqrt(Double(-1.0))),
    'facade Sqrt negative input returns NaN');
  Check(nextpas.core.math.IsNaN(nextpas.core.math.Power(Double(-2.0), Double(0.5))),
    'facade Power negative fractional exponent returns NaN');
  Check(nextpas.core.math.IsInfinite(LExpPositiveInfinity) and
    (LExpPositiveInfinity > 0.0),
    'facade Exp positive infinity returns positive infinity');
  Check(SameDoubleBits(-PI_VALUE,
    nextpas.core.math.ArcTan2(MakeDoubleNegativeZero, MakeDoubleNegativeZero)),
    'facade ArcTan2(-0,-0) returns -PI exact bits');
end;

procedure TestFacadeImportsOnlyRootMathUnit;
begin
  CheckNear(PI_VALUE, nextpas.core.math.PI_VALUE,
    'facade root import exposes constants');
  CheckNear(1.0, nextpas.core.math.Cos(0.0),
    'facade root import exposes functions');
end;

procedure RaiseFacadeClampReversedBounds;
begin
  Clamp(1.0, 2.0, 1.0);
end;

procedure RaiseFacadeWrapDoubleReversedBounds;
begin
  Wrap(1.0, 2.0, 1.0);
end;

procedure RaiseFacadeWrapSingleReversedBounds;
begin
  Wrap(Single(1.0), Single(2.0), Single(1.0));
end;

procedure RaiseFacadeWrapDoubleNaNValue;
begin
  Wrap(MakeNaN, 0.0, 1.0);
end;

procedure RaiseFacadeWrapSingleNaNValue;
begin
  Wrap(MakeSingleNaN, Single(0.0), Single(1.0));
end;

begin
  T := TTestRunner.Create('nextpas.core.math facade');
  T.Run('scalar and trig re-export', @TestFacadeScalarAndTrig);
  T.Run('facade Wrap error semantics', @TestFacadeWrapErrorSemantics);
  T.Run('facade scalar rounding surface', @TestFacadeRoundingSurface);
  T.Run('facade new scalar surface', @TestFacadeNewScalarSurface);
  T.Run('facade vector surface', @TestFacadeVectorSurface);
  T.Run('facade vector Lerp scalar parity contracts',
    @TestFacadeVectorLerpScalarParityContracts);
  T.Run('facade random surface', @TestFacadeRandomSurface);
  T.Run('facade type alias compile surface', @TestFacadeTypeAliasCompileSurface);
  T.Run('facade root forwarder compile surface', @TestFacadeRootForwarderCompileSurface);
  T.Run('facade public member compile surface', @TestFacadePublicMemberCompileSurface);
  T.Run('facade root trig declaration parity compile surface',
    @TestFacadeRootTrigDeclarationParityCompileSurface);
  T.Run('facade Power finite identity precision contracts',
    @TestFacadePowerFiniteIdentityPrecisionContracts);
  T.Run('facade Log exact identity contracts', @TestFacadeLogExactIdentityContracts);
  T.Run('facade trig IEEE domain smoke', @TestFacadeTrigIeeeDomainSmoke);
  T.Run('facade imports only root math unit', @TestFacadeImportsOnlyRootMathUnit);
  T.Summary;
end.
