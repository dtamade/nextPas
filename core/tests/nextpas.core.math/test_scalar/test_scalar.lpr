program test_scalar;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.scalar;

var
  T: TTestRunner;

function MakeNaN: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF8000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakePositiveInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeNegativeInfinity: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($FFF0000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeSingleNaN: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($7FC00000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeSinglePositiveInfinity: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($7F800000);
  Move(LBits, Result, SizeOf(Result));
end;

function Pow2_63: Double;
var
  LI: Integer;
begin
  Result := 1.0;
  for LI := 1 to 63 do
    Result := Result * 2.0;
end;

procedure CheckNear(const AExpected, AActual: Double; const AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
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

procedure TestConstants;
begin
  CheckNear(3.14159265358979323846, PI_VALUE, 0.000000000000001, 'PI_VALUE');
  CheckNear(6.28318530717958647692, TWO_PI, 0.000000000000001, 'TWO_PI');
  CheckNear(1.57079632679489661923, HALF_PI, 0.000000000000001, 'HALF_PI');
  CheckNear(0.01745329251994329577, DEG_TO_RAD, 0.000000000000001, 'DEG_TO_RAD');
  CheckNear(57.2957795130823208768, RAD_TO_DEG, 0.000000000000001, 'RAD_TO_DEG');
end;

procedure TestMinMaxClamp;
begin
  CheckNear(1.5, nextpas.core.math.scalar.Min(Single(1.5), Single(2.5)), 0.0, 'Min Single');
  CheckNear(2.5, nextpas.core.math.scalar.Max(Single(1.5), Single(2.5)), 0.0, 'Max Single');
  CheckEqual(Int64(1), Int64(nextpas.core.math.scalar.Min(Int64(1), Int64(2))), 'Min Int64');
  CheckEqual(Int64(2), Int64(nextpas.core.math.scalar.Max(Int64(1), Int64(2))), 'Max Int64');
  CheckNear(-1.5, nextpas.core.math.scalar.Min(-1.5, 2.0), 0.0, 'Min Double');
  CheckNear(2.0, nextpas.core.math.scalar.Max(-1.5, 2.0), 0.0, 'Max Double');
  CheckNear(5.0, Clamp(Single(10.0), Single(0.0), Single(5.0)), 0.0, 'Clamp Single high');
  CheckNear(5.0, Clamp(10.0, 0.0, 5.0), 0.0, 'Clamp high');
  CheckNear(0.0, Clamp(-1.0, 0.0, 5.0), 0.0, 'Clamp low');
  CheckNear(3.0, Clamp(3.0, 0.0, 5.0), 0.0, 'Clamp inside');
end;

procedure TestInterpolation;
begin
  CheckNear(5.0, Lerp(Single(0.0), Single(10.0), Single(0.5)), 0.0, 'Lerp Single midpoint');
  CheckNear(5.0, Lerp(0.0, 10.0, 0.5), 0.0, 'Lerp midpoint');
  CheckNear(-5.0, Lerp(-10.0, 0.0, 0.5), 0.0, 'Lerp negative midpoint');
  CheckNear(0.5, InverseLerp(Single(10.0), Single(20.0), Single(15.0)), 0.0, 'InverseLerp Single midpoint');
  CheckNear(0.5, InverseLerp(10.0, 20.0, 15.0), 0.0, 'InverseLerp midpoint');
  CheckNear(0.0, InverseLerp(5.0, 5.0, 5.0), 0.0, 'InverseLerp equal endpoints');
  CheckNear(10.0, Wrap(Single(370.0), Single(0.0), Single(360.0)), 0.0, 'Wrap Single high');
  CheckNear(10.0, Wrap(370.0, 0.0, 360.0), 0.0, 'Wrap high');
  CheckNear(350.0, Wrap(-10.0, 0.0, 360.0), 0.0, 'Wrap low');
  CheckNear(0.5, SmoothStep(Single(0.0), Single(1.0), Single(0.5)), 0.000001, 'SmoothStep Single midpoint');
  CheckNear(0.0, SmoothStep(0.0, 1.0, -1.0), 0.0, 'SmoothStep clamps low');
  CheckNear(1.0, SmoothStep(0.0, 1.0, 2.0), 0.0, 'SmoothStep clamps high');
end;

procedure TestRoundingAndSign;
begin
  CheckEqual(Int64(4), Ceil(Single(3.2)), 'Ceil Single positive');
  CheckEqual(Int64(-2), Floor(Single(-1.2)), 'Floor Single negative');
  CheckEqual(Int64(3), Floor(3.7), 'Floor positive');
  CheckEqual(Int64(-2), Floor(-1.2), 'Floor negative');
  CheckEqual(Int64(4), Ceil(3.2), 'Ceil positive');
  CheckEqual(Int64(-1), Ceil(-1.8), 'Ceil negative');
  CheckEqual(Int64(4), Round(3.5), 'Round half up');
  CheckEqual(Int64(3), Trunc(3.9), 'Trunc positive');
  CheckNear(0.25, Frac(3.25), 0.000000001, 'Frac positive');
  CheckNear(0.25, Frac(Single(3.25)), 0.000000001, 'Frac Single positive');
  CheckNear(3.0, nextpas.core.math.scalar.Abs(Single(-3.0)), 0.0, 'Abs Single');
  CheckNear(3.0, nextpas.core.math.scalar.Abs(-3.0), 0.0, 'Abs Double');
  CheckNear(-1.0, Sign(Single(-3.0)), 0.0, 'Sign Single negative');
  CheckNear(-1.0, Sign(-3.0), 0.0, 'Sign negative');
  CheckNear(0.0, Sign(0.0), 0.0, 'Sign zero');
  CheckNear(1.0, Sign(3.0), 0.0, 'Sign positive');
end;

procedure TestFloatPredicates;
var
  LNaN: Double;
  LInf: Double;
begin
  LNaN := MakeNaN;
  LInf := MakePositiveInfinity;
  Check(IsNaN(MakeSingleNaN), 'IsNaN Single');
  Check(IsNaN(LNaN), 'IsNaN');
  Check(IsInfinite(LInf), 'IsInfinite');
  Check(FloatEquals(Single(1.0), Single(1.0 + 0.0000001), Single(0.000001)), 'FloatEquals Single epsilon');
  Check(FloatEquals(1.0, 1.0 + 0.0000001, 0.000001), 'FloatEquals epsilon');
  Check(FloatIsZero(Single(0.0000001), Single(0.000001)), 'FloatIsZero Single epsilon');
  Check(FloatIsZero(0.0000001, 0.000001), 'FloatIsZero epsilon');
end;

procedure TestNumberTheoryAndScalarExtras;
begin
  CheckEqual(Int64(6), GCD(Int64(-12), Int64(18)), 'GCD signed inputs');
  CheckEqual(Int64(0), GCD(Int64(0), Int64(0)), 'GCD zero zero');
  CheckEqual(Int64(36), LCM(Int64(-12), Int64(18)), 'LCM signed inputs');
  CheckEqual(Int64(0), LCM(Int64(0), Int64(18)), 'LCM zero');
  CheckNear(5.0, Hypot(Single(3.0), Single(4.0)), 0.000001, 'Hypot Single 3-4-5');
  CheckNear(5.0, Hypot(3.0, 4.0), 0.000001, 'Hypot Double 3-4-5');
  Check(IsInfinite(Hypot(MakeSinglePositiveInfinity, MakeSinglePositiveInfinity)) and
    (Hypot(MakeSinglePositiveInfinity, MakeSinglePositiveInfinity) > 0.0), 'Hypot Single infinities');
  Check(IsInfinite(Hypot(MakePositiveInfinity, MakePositiveInfinity)) and
    (Hypot(MakePositiveInfinity, MakePositiveInfinity) > 0.0), 'Hypot Double infinities');
  CheckNear(1.5, Fmod(Single(5.5), Single(2.0)), 0.000001, 'Fmod Single');
  CheckNear(-1.5, Fmod(-5.5, 2.0), 0.000001, 'Fmod sign follows dividend');
  Check(IsNaN(Fmod(1.0, 0.0)), 'Fmod divide by zero returns NaN');
end;

procedure RaiseFloorNaN;
begin
  Floor(MakeNaN);
end;

procedure RaiseFloorPositiveInfinity;
begin
  Floor(MakePositiveInfinity);
end;

procedure RaiseFloorNegativeInfinity;
begin
  Floor(MakeNegativeInfinity);
end;

procedure RaiseCeilHugePositive;
begin
  Ceil(1.0e300);
end;

procedure RaiseCeilSingleNaN;
begin
  Ceil(MakeSingleNaN);
end;

procedure RaiseCeilSinglePositiveInfinity;
begin
  Ceil(MakeSinglePositiveInfinity);
end;

procedure RaiseCeilHugeNegative;
begin
  Ceil(-1.0e300);
end;

procedure RaiseTruncPositive2Pow63;
begin
  Trunc(Pow2_63);
end;

procedure RaiseFloorPositive2Pow63;
begin
  Floor(Pow2_63);
end;

procedure RaiseRoundPositive2Pow63;
begin
  Round(Pow2_63);
end;

procedure RaiseRoundNaN;
begin
  Round(MakeNaN);
end;

procedure RaiseRoundPositiveInfinity;
begin
  Round(MakePositiveInfinity);
end;

procedure RaiseTruncBelowInt64Min;
begin
  Trunc(-Pow2_63 - 4096.0);
end;

procedure RaiseTruncNaN;
begin
  Trunc(MakeNaN);
end;

procedure RaiseTruncPositiveInfinity;
begin
  Trunc(MakePositiveInfinity);
end;

procedure RaiseAbsLowInt32;
begin
  nextpas.core.math.scalar.Abs(Low(Int32));
end;

procedure RaiseAbsLowInt64;
begin
  nextpas.core.math.scalar.Abs(Low(Int64));
end;

procedure RaiseFracNaN;
begin
  Frac(MakeNaN);
end;

procedure RaiseFracPositiveInfinity;
begin
  Frac(MakePositiveInfinity);
end;

procedure RaiseFracPositive2Pow63;
begin
  Frac(Pow2_63);
end;

procedure RaiseGCDLowInt64;
begin
  GCD(Low(Int64), 0);
end;

procedure RaiseLCMOverflow;
begin
  LCM(Low(Int64), 2);
end;

procedure TestIntegerRoundingBoundaries;
const
  CNearMaxInt64: Double = 9223372036854774784.0;
  CInt64Min: Double = -9223372036854775808.0;
  CNearMinInt64: Double = -9223372036854774784.0;
begin
  CheckEqual(Int64(3), Floor(3.7), 'Floor positive');
  CheckEqual(Int64(-2), Floor(-1.2), 'Floor negative');
  CheckEqual(Int64(4), Ceil(3.2), 'Ceil positive');
  CheckEqual(Int64(-1), Ceil(-1.8), 'Ceil negative');
  CheckEqual(Int64(4), Round(3.5), 'Round half positive');
  CheckEqual(Int64(-2), Round(-1.6), 'Round negative');
  CheckEqual(Int64(3), Trunc(3.9), 'Trunc positive');
  CheckEqual(Int64(-3), Trunc(-3.9), 'Trunc negative');

  CheckEqual(Int64(9223372036854774784), Floor(CNearMaxInt64), 'Floor near 2^63');
  CheckEqual(Int64(9223372036854774784), Ceil(CNearMaxInt64), 'Ceil near 2^63');
  CheckEqual(Int64(9223372036854774784), Round(CNearMaxInt64), 'Round near 2^63');
  CheckEqual(Int64(9223372036854774784), Trunc(CNearMaxInt64), 'Trunc near 2^63');

  CheckEqual(Low(Int64), Floor(CInt64Min), 'Floor -2^63');
  CheckEqual(Low(Int64), Ceil(CInt64Min), 'Ceil -2^63');
  CheckEqual(Low(Int64), Round(CInt64Min), 'Round -2^63');
  CheckEqual(Low(Int64), Trunc(CInt64Min), 'Trunc -2^63');

  CheckEqual(Int64(-9223372036854774784), Floor(CNearMinInt64), 'Floor near -2^63');
  CheckEqual(Int64(-9223372036854774784), Ceil(CNearMinInt64), 'Ceil near -2^63');
  CheckEqual(Int64(-9223372036854774784), Round(CNearMinInt64), 'Round near -2^63');
  CheckEqual(Int64(-9223372036854774784), Trunc(CNearMinInt64), 'Trunc near -2^63');

  ExpectArgumentErrorMessage('Floor: NaN cannot be converted to Int64',
    'Floor(NaN)', @RaiseFloorNaN);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(+Inf)', @RaiseFloorPositiveInfinity);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(-Inf)', @RaiseFloorNegativeInfinity);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(huge positive)', @RaiseCeilHugePositive);
  ExpectArgumentErrorMessage('Ceil: NaN cannot be converted to Int64',
    'Ceil(Single NaN)', @RaiseCeilSingleNaN);
  ExpectArgumentErrorMessage('Ceil: infinity cannot be converted to Int64',
    'Ceil(Single +Inf)', @RaiseCeilSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(huge negative)', @RaiseCeilHugeNegative);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(2^63)', @RaiseTruncPositive2Pow63);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(2^63)', @RaiseFloorPositive2Pow63);
  ExpectArgumentErrorMessage('Round: NaN cannot be converted to Int64',
    'Round(NaN)', @RaiseRoundNaN);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(+Inf)', @RaiseRoundPositiveInfinity);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(2^63)', @RaiseRoundPositive2Pow63);
  ExpectArgumentErrorMessage('Trunc: NaN cannot be converted to Int64',
    'Trunc(NaN)', @RaiseTruncNaN);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(+Inf)', @RaiseTruncPositiveInfinity);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(below -2^63)', @RaiseTruncBelowInt64Min);
  ExpectArgumentErrorMessage('Abs: absolute value is outside Int32 range',
    'Abs(Low(Int32))', @RaiseAbsLowInt32);
  ExpectArgumentErrorMessage('Abs: absolute value is outside Int64 range',
    'Abs(Low(Int64))', @RaiseAbsLowInt64);
end;

procedure TestOwnerLevelBoundaryMessages;
begin
  ExpectArgumentErrorMessage('Frac: NaN cannot be converted to Int64',
    'Frac(NaN)', @RaiseFracNaN);
  ExpectArgumentErrorMessage('Frac: infinity cannot be converted to Int64',
    'Frac(+Inf)', @RaiseFracPositiveInfinity);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(2^63)', @RaiseFracPositive2Pow63);
  ExpectArgumentErrorMessage('GCD: result is outside Int64 range',
    'GCD(Low(Int64), 0)', @RaiseGCDLowInt64);
  ExpectArgumentErrorMessage('LCM: result is outside Int64 range',
    'LCM overflow', @RaiseLCMOverflow);
end;

procedure TestOverflowHelpers;
begin
  Check(IsAddOverflow(High(SizeUInt), SizeUInt(1)), 'IsAddOverflow SizeUInt');
  Check(not IsAddOverflow(SizeUInt(10), SizeUInt(20)), 'IsAddOverflow false');
  Check(IsMulOverflow(High(SizeUInt), SizeUInt(2)), 'IsMulOverflow SizeUInt');
  Check(not IsMulOverflow(SizeUInt(10), SizeUInt(20)), 'IsMulOverflow false');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.scalar');
  T.Run('constants', @TestConstants);
  T.Run('min max clamp', @TestMinMaxClamp);
  T.Run('interpolation', @TestInterpolation);
  T.Run('rounding and sign', @TestRoundingAndSign);
  T.Run('float predicates', @TestFloatPredicates);
  T.Run('number theory and scalar extras', @TestNumberTheoryAndScalarExtras);
  T.Run('integer rounding boundaries', @TestIntegerRoundingBoundaries);
  T.Run('owner-level boundary messages', @TestOwnerLevelBoundaryMessages);
  T.Run('overflow helpers', @TestOverflowHelpers);
  T.Summary;
end.
