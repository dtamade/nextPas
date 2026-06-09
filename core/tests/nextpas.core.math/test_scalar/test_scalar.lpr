program test_scalar;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.scalar;

{$IF (SizeOf(Extended) > SizeOf(Double)) AND (DEFINED(CPUX86_64) OR DEFINED(CPUX86) OR DEFINED(CPUI386))}
  {$DEFINE NEXTPAS_TEST_MATH_EXTENDED_X87_80}
{$ELSEIF SizeOf(Extended) = SizeOf(Double)}
  {$DEFINE NEXTPAS_TEST_MATH_EXTENDED_DOUBLE_COMPAT}
{$ELSE}
  {$FATAL Unsupported Extended floating-point layout}
{$ENDIF}

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

function MakeSingleNegativeInfinity: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($FF800000);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeMaxFiniteSingle: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($7F7FFFFF);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeMaxFiniteDouble: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($7FEFFFFFFFFFFFFF);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeMinPositiveSubnormalSingle: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($00000001);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeMinPositiveSubnormalDouble: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($0000000000000001);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeSingleBelowInt64Min: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($DF000001);
  Move(LBits, Result, SizeOf(Result));
end;

function MakeSingleNegativeZero: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($80000000);
  Move(LBits, Result, SizeOf(Result));
end;

function IsSingleNegativeZero(const AValue: Single): Boolean;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt32($80000000);
end;

function IsSinglePositiveZero(const AValue: Single): Boolean;
var
  LBits: UInt32;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt32(0);
end;

function MakeDoubleNegativeZero: Double;
var
  LBits: UInt64;
begin
  LBits := UInt64($8000000000000000);
  Move(LBits, Result, SizeOf(Result));
end;

function IsDoubleNegativeZero(const AValue: Double): Boolean;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt64($8000000000000000);
end;

function IsDoublePositiveZero(const AValue: Double): Boolean;
var
  LBits: UInt64;
begin
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt64(0);
end;

function MakeExtendedNaN: Extended;
begin
  Result := Extended(MakeNaN);
end;

function MakeExtendedPositiveInfinity: Extended;
begin
  Result := Extended(MakePositiveInfinity);
end;

function MakeExtendedNegativeInfinity: Extended;
begin
  Result := Extended(MakeNegativeInfinity);
end;

function MakeExtendedNegativeZero: Extended;
begin
  Result := Extended(MakeDoubleNegativeZero);
end;

function IsExtendedNegativeZero(const AValue: Extended): Boolean;
{$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
type
  TExtendedBytes = packed array[0..SizeOf(Extended) - 1] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
  LBytes: TExtendedBytes;
  LMantissa: UInt64;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
  Move(AValue, LBytes, SizeOf(LBytes));
  LMantissa := 0;
  Move(LBytes[0], LMantissa, SizeOf(LMantissa));
  Result := (LBytes[8] = 0) and (LBytes[9] = Byte($80)) and
    (LMantissa = 0);
  {$ELSE}
  Move(AValue, LBits, SizeOf(LBits));
  Result := LBits = UInt64($8000000000000000);
  {$ENDIF}
end;

function IsExtendedNaN(const AValue: Extended): Boolean;
{$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
type
  TExtended10Bytes = packed array[0..9] of Byte;
{$ENDIF}
var
  {$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
  LBytes: TExtended10Bytes;
  LExp: UInt16;
  LFraction: UInt64;
  {$ELSE}
  LBits: UInt64;
  {$ENDIF}
begin
  {$IFDEF NEXTPAS_TEST_MATH_EXTENDED_X87_80}
  Move(AValue, LBytes, SizeOf(LBytes));
  LExp := (UInt16(LBytes[9]) and UInt16($7F)) shl 8;
  LExp := LExp or UInt16(LBytes[8]);
  LFraction := 0;
  Move(LBytes[0], LFraction, SizeOf(LFraction));
  Result := (LExp = UInt16($7FFF)) and
    ((LFraction and UInt64($7FFFFFFFFFFFFFFF)) <> 0);
  {$ELSE}
  Move(AValue, LBits, SizeOf(LBits));
  Result := ((LBits and UInt64($7FF0000000000000)) = UInt64($7FF0000000000000)) and
    ((LBits and UInt64($000FFFFFFFFFFFFF)) <> 0);
  {$ENDIF}
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

procedure CheckScaledNear(const AExpected, AActual, AScale, AEpsilon: Double; const AMessage: string);
begin
  CheckNear(AExpected / AScale, AActual / AScale, AEpsilon, AMessage);
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

procedure RaiseClampSingleReversedBounds; forward;
procedure RaiseClampDoubleReversedBounds; forward;
procedure RaiseClampInt32ReversedBounds; forward;
procedure RaiseClampSingleNaNMin; forward;
procedure RaiseClampDoubleNaNMax; forward;
procedure RaiseClampSingleInfiniteMax; forward;
procedure RaiseWrapSingleReversedBounds; forward;
procedure RaiseWrapDoubleReversedBounds; forward;
procedure RaiseWrapSingleNaNValue; forward;
procedure RaiseWrapDoubleInfiniteValue; forward;
procedure RaiseWrapSingleNaNMin; forward;
procedure RaiseWrapDoubleInfiniteMax; forward;
procedure RaiseSmoothStepSingleNaNEdge; forward;
procedure RaiseSmoothStepDoubleNaNEdge; forward;
procedure RaiseSmoothStepSingleInfiniteEdge; forward;
procedure RaiseSmoothStepDoubleInfiniteEdge; forward;

procedure TestMinMaxClamp;
var
  LNaN: Double;
  LSingleNaN: Single;
begin
  CheckNear(1.5, nextpas.core.math.scalar.Min(Single(1.5), Single(2.5)), 0.0, 'Min Single');
  CheckNear(2.5, nextpas.core.math.scalar.Max(Single(1.5), Single(2.5)), 0.0, 'Max Single');
  CheckEqual(Int64(1), Int64(nextpas.core.math.scalar.Min(Int64(1), Int64(2))), 'Min Int64');
  CheckEqual(Int64(2), Int64(nextpas.core.math.scalar.Max(Int64(1), Int64(2))), 'Max Int64');
  CheckNear(-1.5, nextpas.core.math.scalar.Min(-1.5, 2.0), 0.0, 'Min Double');
  CheckNear(2.0, nextpas.core.math.scalar.Max(-1.5, 2.0), 0.0, 'Max Double');
  Check(IsNaN(nextpas.core.math.scalar.Min(MakeNaN, 1.0)), 'Min Double propagates NaN first');
  Check(IsNaN(nextpas.core.math.scalar.Min(1.0, MakeNaN)), 'Min Double propagates NaN second');
  Check(IsNaN(nextpas.core.math.scalar.Max(MakeNaN, 1.0)), 'Max Double propagates NaN first');
  Check(IsNaN(nextpas.core.math.scalar.Max(1.0, MakeNaN)), 'Max Double propagates NaN second');
  Check(IsNaN(nextpas.core.math.scalar.Min(MakeSingleNaN, Single(1.0))), 'Min Single propagates NaN first');
  Check(IsNaN(nextpas.core.math.scalar.Min(Single(1.0), MakeSingleNaN)), 'Min Single propagates NaN second');
  Check(IsNaN(nextpas.core.math.scalar.Max(MakeSingleNaN, Single(1.0))), 'Max Single propagates NaN first');
  Check(IsNaN(nextpas.core.math.scalar.Max(Single(1.0), MakeSingleNaN)), 'Max Single propagates NaN second');
  Check(IsDoubleNegativeZero(nextpas.core.math.scalar.Min(MakeDoubleNegativeZero, 0.0)),
    'Min Double keeps negative zero first');
  Check(IsDoubleNegativeZero(nextpas.core.math.scalar.Min(0.0, MakeDoubleNegativeZero)),
    'Min Double keeps negative zero second');
  Check(not IsDoubleNegativeZero(nextpas.core.math.scalar.Max(MakeDoubleNegativeZero, 0.0)),
    'Max Double keeps positive zero second');
  Check(not IsDoubleNegativeZero(nextpas.core.math.scalar.Max(0.0, MakeDoubleNegativeZero)),
    'Max Double keeps positive zero first');
  Check(IsSingleNegativeZero(nextpas.core.math.scalar.Min(MakeSingleNegativeZero, Single(0.0))),
    'Min Single keeps negative zero first');
  Check(IsSingleNegativeZero(nextpas.core.math.scalar.Min(Single(0.0), MakeSingleNegativeZero)),
    'Min Single keeps negative zero second');
  Check(not IsSingleNegativeZero(nextpas.core.math.scalar.Max(MakeSingleNegativeZero, Single(0.0))),
    'Max Single keeps positive zero second');
  Check(not IsSingleNegativeZero(nextpas.core.math.scalar.Max(Single(0.0), MakeSingleNegativeZero)),
    'Max Single keeps positive zero first');
  CheckNear(5.0, Clamp(Single(10.0), Single(0.0), Single(5.0)), 0.0, 'Clamp Single high');
  CheckNear(5.0, Clamp(10.0, 0.0, 5.0), 0.0, 'Clamp high');
  CheckNear(0.0, Clamp(-1.0, 0.0, 5.0), 0.0, 'Clamp low');
  CheckNear(3.0, Clamp(3.0, 0.0, 5.0), 0.0, 'Clamp inside');
  LSingleNaN := Clamp(MakeSingleNaN, Single(0.0), Single(5.0));
  Check(IsNaN(LSingleNaN), 'Clamp Single NaN value propagates NaN');
  LNaN := Clamp(MakeNaN, 0.0, 5.0);
  Check(IsNaN(LNaN), 'Clamp Double NaN value propagates NaN');
  ExpectArgumentErrorMessage('Clamp: minimum must not exceed maximum',
    'Clamp Single reversed bounds', @RaiseClampSingleReversedBounds);
  ExpectArgumentErrorMessage('Clamp: minimum must not exceed maximum',
    'Clamp Double reversed bounds', @RaiseClampDoubleReversedBounds);
  ExpectArgumentErrorMessage('Clamp: minimum must not exceed maximum',
    'Clamp Int32 reversed bounds', @RaiseClampInt32ReversedBounds);
  ExpectArgumentErrorMessage('Clamp: minimum and maximum must be finite',
    'Clamp Single NaN minimum', @RaiseClampSingleNaNMin);
  ExpectArgumentErrorMessage('Clamp: minimum and maximum must be finite',
    'Clamp Double NaN maximum', @RaiseClampDoubleNaNMax);
  ExpectArgumentErrorMessage('Clamp: minimum and maximum must be finite',
    'Clamp Single infinite maximum', @RaiseClampSingleInfiniteMax);
end;

procedure TestInterpolation;
var
  LDoubleResult: Double;
  LSingleResult: Single;
  LWrapped: Double;
begin
  CheckNear(5.0, Lerp(Single(0.0), Single(10.0), Single(0.5)), 0.0, 'Lerp Single midpoint');
  CheckNear(5.0, Lerp(0.0, 10.0, 0.5), 0.0, 'Lerp midpoint');
  CheckNear(-5.0, Lerp(-10.0, 0.0, 0.5), 0.0, 'Lerp negative midpoint');
  LDoubleResult := Lerp(Double(-1.0e308), Double(1.0e308), Double(0.5));
  Check((not IsNaN(LDoubleResult)) and (not IsInfinite(LDoubleResult)),
    'Lerp Double huge opposite finite midpoint stays finite');
  CheckNear(0.0, LDoubleResult, 0.0,
    'Lerp Double huge opposite finite midpoint returns center');
  CheckScaledNear(Double(-5.0e307), Lerp(Double(-1.0e308), Double(1.0e308), Double(0.25)),
    Double(1.0e307), 0.000000000000001, 'Lerp Double huge opposite finite off-center');
  CheckScaledNear(Double(5.0e307), Lerp(Double(1.0e308), Double(-1.0e308), Double(0.25)),
    Double(1.0e307), 0.000000000000001, 'Lerp Double huge reversed finite off-center');
  LSingleResult := Lerp(Single(-3.0e38), Single(3.0e38), Single(0.5));
  Check((not IsNaN(LSingleResult)) and (not IsInfinite(LSingleResult)),
    'Lerp Single huge opposite finite midpoint stays finite');
  CheckNear(0.0, LSingleResult, 0.0,
    'Lerp Single huge opposite finite midpoint returns center');
  CheckNear(0.5, InverseLerp(Single(10.0), Single(20.0), Single(15.0)), 0.0, 'InverseLerp Single midpoint');
  CheckNear(0.5, InverseLerp(10.0, 20.0, 15.0), 0.0, 'InverseLerp midpoint');
  CheckNear(0.5, InverseLerp(Double(-1.0e308), Double(1.0e308), Double(0.0)), 0.000000000000001,
    'InverseLerp Double huge opposite finite midpoint returns half');
  CheckNear(0.25, InverseLerp(Double(-1.0e308), Double(1.0e308), Double(-5.0e307)), 0.000000000000001,
    'InverseLerp Double huge opposite finite off-center returns quarter');
  CheckNear(0.25, InverseLerp(Double(1.0e308), Double(-1.0e308), Double(5.0e307)), 0.000000000000001,
    'InverseLerp Double huge reversed finite off-center returns quarter');
  CheckNear(0.5, InverseLerp(Single(-3.0e38), Single(3.0e38), Single(0.0)), 0.000001,
    'InverseLerp Single huge opposite finite midpoint returns half');
  CheckNear(0.0, InverseLerp(5.0, 5.0, 5.0), 0.0, 'InverseLerp equal endpoints');
  CheckNear(10.0, Wrap(Single(370.0), Single(0.0), Single(360.0)), 0.0, 'Wrap Single high');
  CheckNear(10.0, Wrap(370.0, 0.0, 360.0), 0.0, 'Wrap high');
  CheckNear(350.0, Wrap(-10.0, 0.0, 360.0), 0.0, 'Wrap low');
  CheckNear(5.0, Wrap(Single(10.0), Single(5.0), Single(5.0)), 0.0,
    'Wrap Single equal bounds returns minimum');
  CheckNear(5.0, Wrap(10.0, 5.0, 5.0), 0.0,
    'Wrap Double equal bounds returns minimum');
  LWrapped := Wrap(Double(0.0), Double(-1.0e308), Double(1.0e308));
  CheckNear(0.0, LWrapped, 0.0, 'Wrap Double huge finite range keeps in-range value');
  Check((not IsNaN(LWrapped)) and (not IsInfinite(LWrapped)) and
    (LWrapped >= Double(-1.0e308)) and (LWrapped < Double(1.0e308)),
    'Wrap Double huge finite range stays finite');
  LWrapped := Wrap(Double(1.7e308), Double(-1.0e308), Double(1.0e308));
  CheckScaledNear(Double(-3.0e307), LWrapped, Double(1.0e307), 0.000000000000001,
    'Wrap Double huge finite overflowed range wraps above max');
  Check((not IsNaN(LWrapped)) and (not IsInfinite(LWrapped)) and
    (LWrapped >= Double(-1.0e308)) and (LWrapped < Double(1.0e308)),
    'Wrap Double huge finite overflowed range result stays finite');
  LWrapped := Wrap(Double(1.7e308), Double(-8.0e307), Double(8.0e307));
  Check((not IsNaN(LWrapped)) and (not IsInfinite(LWrapped)) and
    (LWrapped >= Double(-8.0e307)) and (LWrapped < Double(8.0e307)),
    'Wrap Double huge finite delta stays finite');
  LWrapped := Wrap(Double(-1.7e308), Double(-8.0e307), Double(8.0e307));
  Check((not IsNaN(LWrapped)) and (not IsInfinite(LWrapped)) and
    (LWrapped >= Double(-8.0e307)) and (LWrapped < Double(8.0e307)),
    'Wrap Double huge finite negative delta stays finite');
  ExpectArgumentErrorMessage('Wrap: minimum must not exceed maximum',
    'Wrap Single reversed bounds', @RaiseWrapSingleReversedBounds);
  ExpectArgumentErrorMessage('Wrap: minimum must not exceed maximum',
    'Wrap Double reversed bounds', @RaiseWrapDoubleReversedBounds);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'Wrap Single NaN value', @RaiseWrapSingleNaNValue);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'Wrap Double infinite value', @RaiseWrapDoubleInfiniteValue);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'Wrap Single NaN minimum', @RaiseWrapSingleNaNMin);
  ExpectArgumentErrorMessage('Wrap: value, minimum, and maximum must be finite',
    'Wrap Double infinite maximum', @RaiseWrapDoubleInfiniteMax);
  CheckNear(0.5, SmoothStep(Single(0.0), Single(1.0), Single(0.5)), 0.000001, 'SmoothStep Single midpoint');
  CheckNear(0.5, SmoothStep(Double(-1.0e308), Double(1.0e308), Double(0.0)), 0.000000000000001,
    'SmoothStep Double huge opposite finite midpoint returns half');
  CheckNear(0.5, SmoothStep(Single(-3.0e38), Single(3.0e38), Single(0.0)), 0.000001,
    'SmoothStep Single huge opposite finite midpoint returns half');
  CheckNear(0.0, SmoothStep(0.0, 1.0, -1.0), 0.0, 'SmoothStep clamps low');
  CheckNear(1.0, SmoothStep(0.0, 1.0, 2.0), 0.0, 'SmoothStep clamps high');
end;

procedure TestScalarRangeBoundaryEdgeContracts;
begin
  CheckNear(0.0, Wrap(0.0, 0.0, 360.0), 0.0,
    'Wrap Double minimum endpoint stays minimum');
  CheckNear(0.0, Wrap(360.0, 0.0, 360.0), 0.0,
    'Wrap Double maximum endpoint returns minimum');
  CheckNear(0.0, Wrap(Single(360.0), Single(0.0), Single(360.0)), 0.0,
    'Wrap Single maximum endpoint returns minimum');
  CheckNear(-1.0e308, Wrap(1.0e308, -1.0e308, 1.0e308), 0.0,
    'Wrap Double huge maximum endpoint returns minimum');

  CheckNear(5.0, Clamp(MakeSinglePositiveInfinity, Single(0.0), Single(5.0)), 0.0,
    'Clamp Single positive infinity clamps high');
  CheckNear(0.0, Clamp(MakeSingleNegativeInfinity, Single(0.0), Single(5.0)), 0.0,
    'Clamp Single negative infinity clamps low');
  CheckNear(5.0, Clamp(Single(100.0), Single(5.0), Single(5.0)), 0.0,
    'Clamp Single equal bounds returns bound');
  Check(IsSingleNegativeZero(Clamp(Single(0.0), MakeSingleNegativeZero, MakeSingleNegativeZero)),
    'Clamp Single equal negative-zero bounds return bound');
  Check(IsSinglePositiveZero(Clamp(MakeSingleNegativeZero, Single(0.0), Single(0.0))),
    'Clamp Single equal positive-zero bounds return bound');
  Check(IsSingleNegativeZero(Clamp(MakeSingleNegativeZero, Single(0.0), Single(1.0))),
    'Clamp Single negative zero inside range keeps sign');
  Check(IsSinglePositiveZero(Clamp(Single(0.0), MakeSingleNegativeZero, Single(1.0))),
    'Clamp Single positive zero inside range keeps sign');

  Check(IsDoubleNegativeZero(Clamp(0.0, MakeDoubleNegativeZero, MakeDoubleNegativeZero)),
    'Clamp Double equal negative-zero bounds return bound');
  Check(IsDoublePositiveZero(Clamp(MakeDoubleNegativeZero, 0.0, 0.0)),
    'Clamp Double equal positive-zero bounds return bound');

  Check(IsDoubleNegativeZero(nextpas.core.math.scalar.Min(MakeDoubleNegativeZero, MakeDoubleNegativeZero)),
    'Min Double same negative zero returns negative zero');
  Check(IsDoubleNegativeZero(nextpas.core.math.scalar.Max(MakeDoubleNegativeZero, MakeDoubleNegativeZero)),
    'Max Double same negative zero returns negative zero');
  Check(IsSingleNegativeZero(nextpas.core.math.scalar.Min(MakeSingleNegativeZero, MakeSingleNegativeZero)),
    'Min Single same negative zero returns negative zero');
  Check(IsSingleNegativeZero(nextpas.core.math.scalar.Max(MakeSingleNegativeZero, MakeSingleNegativeZero)),
    'Max Single same negative zero returns negative zero');
  Check(IsDoublePositiveZero(nextpas.core.math.scalar.Min(0.0, 0.0)),
    'Min Double same positive zero returns positive zero');
  Check(IsDoublePositiveZero(nextpas.core.math.scalar.Max(0.0, 0.0)),
    'Max Double same positive zero returns positive zero');
  Check(IsSinglePositiveZero(nextpas.core.math.scalar.Min(Single(0.0), Single(0.0))),
    'Min Single same positive zero returns positive zero');
  Check(IsSinglePositiveZero(nextpas.core.math.scalar.Max(Single(0.0), Single(0.0))),
    'Max Single same positive zero returns positive zero');

  CheckNear(0.0, InverseLerp(5.0, 5.0, 99.0), 0.0,
    'InverseLerp Double equal bounds returns 0');
  CheckNear(0.0, InverseLerp(Single(5.0), Single(5.0), Single(-99.0)), 0.0,
    'InverseLerp Single equal bounds returns 0');
  CheckNear(0.0, SmoothStep(5.0, 5.0, 4.0), 0.0,
    'SmoothStep Double equal edges returns step boundary below');
  CheckNear(1.0, SmoothStep(5.0, 5.0, 5.0), 0.0,
    'SmoothStep Double equal edges returns step boundary');
  Check(IsNaN(SmoothStep(5.0, 5.0, MakeNaN)),
    'SmoothStep Double equal edges propagates NaN value');
  CheckNear(0.0, SmoothStep(Single(5.0), Single(5.0), Single(4.0)), 0.0,
    'SmoothStep Single equal edges returns step boundary below');
  CheckNear(1.0, SmoothStep(Single(5.0), Single(5.0), Single(5.0)), 0.0,
    'SmoothStep Single equal edges returns step boundary');
  Check(IsNaN(SmoothStep(Single(5.0), Single(5.0), MakeSingleNaN)),
    'SmoothStep Single equal edges propagates NaN value');
  Check(IsNaN(SmoothStep(Single(0.0), MakeSinglePositiveInfinity, MakeSingleNaN)),
    'SmoothStep Single NaN value propagates before non-finite edge validation');
  Check(IsNaN(SmoothStep(0.0, MakePositiveInfinity, MakeNaN)),
    'SmoothStep Double NaN value propagates before non-finite edge validation');
  ExpectArgumentErrorMessage('SmoothStep: edges must be finite',
    'SmoothStep Single NaN edge', @RaiseSmoothStepSingleNaNEdge);
  ExpectArgumentErrorMessage('SmoothStep: edges must be finite',
    'SmoothStep Double NaN edge', @RaiseSmoothStepDoubleNaNEdge);
  ExpectArgumentErrorMessage('SmoothStep: edges must be finite',
    'SmoothStep Single infinite edge', @RaiseSmoothStepSingleInfiniteEdge);
  ExpectArgumentErrorMessage('SmoothStep: edges must be finite',
    'SmoothStep Double infinite edge', @RaiseSmoothStepDoubleInfiniteEdge);
end;

procedure TestAngleConversions;
begin
  CheckNear(PI_VALUE, DegToRad(180.0), 0.0001, 'DegToRad(180)=PI');
  CheckNear(PI_VALUE, DegToRad(Single(180.0)), 0.0001, 'DegToRad(Single 180)=PI');
  CheckNear(180.0, RadToDeg(PI_VALUE), 0.0001, 'RadToDeg(PI)=180');
  CheckNear(180.0, RadToDeg(Single(PI_VALUE)), 0.0001, 'RadToDeg(Single PI)=180');
end;

procedure TestSignAndAngleEdgeContracts;
begin
  CheckEqual(Int32(-1), Sign(Low(Int32)), 'Sign Int32 minimum returns negative one');
  CheckEqual(Int64(-1), Sign(Low(Int64)), 'Sign Int64 minimum returns negative one');

  Check(IsNaN(Sign(MakeNaN)), 'Sign Double NaN propagates NaN');
  Check(IsNaN(Sign(MakeSingleNaN)), 'Sign Single NaN propagates NaN');
  Check(IsDoubleNegativeZero(Sign(MakeDoubleNegativeZero)),
    'Sign Double negative zero keeps negative zero');
  Check(IsSingleNegativeZero(Sign(MakeSingleNegativeZero)),
    'Sign Single negative zero keeps negative zero');
  Check(IsDoublePositiveZero(Sign(0.0)), 'Sign Double positive zero keeps positive zero');
  Check(IsSinglePositiveZero(Sign(Single(0.0))),
    'Sign Single positive zero keeps positive zero');
  CheckNear(1.0, Sign(MakePositiveInfinity), 0.0,
    'Sign Double positive infinity returns one');
  CheckNear(-1.0, Sign(MakeNegativeInfinity), 0.0,
    'Sign Double negative infinity returns negative one');
  CheckNear(1.0, Sign(MakeSinglePositiveInfinity), 0.0,
    'Sign Single positive infinity returns one');
  CheckNear(-1.0, Sign(MakeSingleNegativeInfinity), 0.0,
    'Sign Single negative infinity returns negative one');

  Check(IsNaN(DegToRad(MakeNaN)), 'DegToRad Double NaN propagates NaN');
  Check(IsNaN(DegToRad(MakeSingleNaN)), 'DegToRad Single NaN propagates NaN');
  Check(IsInfinite(DegToRad(MakePositiveInfinity)) and
    (DegToRad(MakePositiveInfinity) > 0.0),
    'DegToRad Double positive infinity propagates infinity');
  Check(IsInfinite(DegToRad(MakeNegativeInfinity)) and
    (DegToRad(MakeNegativeInfinity) < 0.0),
    'DegToRad Double negative infinity propagates infinity');
  Check(IsInfinite(DegToRad(MakeSinglePositiveInfinity)) and
    (DegToRad(MakeSinglePositiveInfinity) > 0.0),
    'DegToRad Single positive infinity propagates infinity');
  Check(IsInfinite(DegToRad(MakeSingleNegativeInfinity)) and
    (DegToRad(MakeSingleNegativeInfinity) < 0.0),
    'DegToRad Single negative infinity propagates infinity');
  Check(IsDoublePositiveZero(DegToRad(0.0)),
    'DegToRad Double positive zero keeps positive zero');
  Check(IsSinglePositiveZero(DegToRad(Single(0.0))),
    'DegToRad Single positive zero keeps positive zero');
  Check(IsDoubleNegativeZero(DegToRad(MakeDoubleNegativeZero)),
    'DegToRad Double negative zero keeps negative zero');
  Check(IsSingleNegativeZero(DegToRad(MakeSingleNegativeZero)),
    'DegToRad Single negative zero keeps negative zero');
  Check((not IsNaN(DegToRad(MakeMaxFiniteDouble))) and
    (not IsInfinite(DegToRad(MakeMaxFiniteDouble))),
    'DegToRad Double max finite stays finite');
  Check((not IsNaN(DegToRad(MakeMaxFiniteSingle))) and
    (not IsInfinite(DegToRad(MakeMaxFiniteSingle))),
    'DegToRad Single max finite stays finite');
  Check((not IsNaN(DegToRad(-MakeMaxFiniteDouble))) and
    (not IsInfinite(DegToRad(-MakeMaxFiniteDouble))),
    'DegToRad Double negative max finite stays finite');
  Check((not IsNaN(DegToRad(-MakeMaxFiniteSingle))) and
    (not IsInfinite(DegToRad(-MakeMaxFiniteSingle))),
    'DegToRad Single negative max finite stays finite');

  Check(IsNaN(RadToDeg(MakeNaN)), 'RadToDeg Double NaN propagates NaN');
  Check(IsNaN(RadToDeg(MakeSingleNaN)), 'RadToDeg Single NaN propagates NaN');
  Check(IsInfinite(RadToDeg(MakePositiveInfinity)) and
    (RadToDeg(MakePositiveInfinity) > 0.0),
    'RadToDeg Double positive infinity propagates infinity');
  Check(IsInfinite(RadToDeg(MakeNegativeInfinity)) and
    (RadToDeg(MakeNegativeInfinity) < 0.0),
    'RadToDeg Double negative infinity propagates infinity');
  Check(IsInfinite(RadToDeg(MakeSinglePositiveInfinity)) and
    (RadToDeg(MakeSinglePositiveInfinity) > 0.0),
    'RadToDeg Single positive infinity propagates infinity');
  Check(IsInfinite(RadToDeg(MakeSingleNegativeInfinity)) and
    (RadToDeg(MakeSingleNegativeInfinity) < 0.0),
    'RadToDeg Single negative infinity propagates infinity');
  Check(IsDoublePositiveZero(RadToDeg(0.0)),
    'RadToDeg Double positive zero keeps positive zero');
  Check(IsSinglePositiveZero(RadToDeg(Single(0.0))),
    'RadToDeg Single positive zero keeps positive zero');
  Check(IsDoubleNegativeZero(RadToDeg(MakeDoubleNegativeZero)),
    'RadToDeg Double negative zero keeps negative zero');
  Check(IsSingleNegativeZero(RadToDeg(MakeSingleNegativeZero)),
    'RadToDeg Single negative zero keeps negative zero');
  Check(IsInfinite(RadToDeg(MakeMaxFiniteDouble)) and
    (RadToDeg(MakeMaxFiniteDouble) > 0.0),
    'RadToDeg Double max finite overflows to positive infinity');
  Check(IsInfinite(RadToDeg(MakeMaxFiniteSingle)) and
    (RadToDeg(MakeMaxFiniteSingle) > 0.0),
    'RadToDeg Single max finite overflows to positive infinity');
  Check(IsInfinite(RadToDeg(-MakeMaxFiniteDouble)) and
    (RadToDeg(-MakeMaxFiniteDouble) < 0.0),
    'RadToDeg Double negative max finite overflows to negative infinity');
  Check(IsInfinite(RadToDeg(-MakeMaxFiniteSingle)) and
    (RadToDeg(-MakeMaxFiniteSingle) < 0.0),
    'RadToDeg Single negative max finite overflows to negative infinity');
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
  Check(FloatEquals(MakeSinglePositiveInfinity, MakeSinglePositiveInfinity, Single(0.0)),
    'FloatEquals Single +Inf exact');
  Check(FloatEquals(MakePositiveInfinity, MakePositiveInfinity, 0.0),
    'FloatEquals Double +Inf exact');
  Check(FloatEquals(MakeNegativeInfinity, MakeNegativeInfinity, 0.0),
    'FloatEquals Double -Inf exact');
  Check(not FloatEquals(MakeSinglePositiveInfinity, MakeSingleNegativeInfinity, Single(1000.0)),
    'FloatEquals Single rejects opposite infinities');
  Check(not FloatEquals(MakePositiveInfinity, MakeNegativeInfinity, 1000.0),
    'FloatEquals Double rejects opposite infinities');
  Check(not FloatEquals(1.0, MakePositiveInfinity, 0.0),
    'FloatEquals Double rejects finite versus +Inf with valid epsilon');
  Check(not FloatEquals(Single(1.0), MakeSinglePositiveInfinity, Single(0.0)),
    'FloatEquals Single rejects finite versus +Inf with valid epsilon');
  Check(not FloatEquals(MakeNaN, 1.0, 0.0),
    'FloatEquals Double rejects NaN first');
  Check(not FloatEquals(1.0, MakeNaN, 0.0),
    'FloatEquals Double rejects NaN second');
  Check(not FloatEquals(MakeSingleNaN, Single(1.0), Single(0.0)),
    'FloatEquals Single rejects NaN first');
  Check(not FloatEquals(Single(1.0), MakeSingleNaN, Single(0.0)),
    'FloatEquals Single rejects NaN second');
  Check(not FloatEquals(1.0, MakePositiveInfinity, MakePositiveInfinity),
    'FloatEquals rejects infinite epsilon');
  Check(not FloatEquals(Single(1.0), MakeSinglePositiveInfinity, MakeSinglePositiveInfinity),
    'FloatEquals Single rejects infinite epsilon');
  Check(not FloatEquals(1.0, 1.0, MakePositiveInfinity),
    'FloatEquals Double rejects infinite epsilon for equal finite values');
  Check(not FloatEquals(Single(1.0), Single(1.0), MakeSinglePositiveInfinity),
    'FloatEquals Single rejects infinite epsilon for equal finite values');
  Check(not FloatEquals(1.0, 1.0, MakeNaN),
    'FloatEquals rejects NaN epsilon');
  Check(not FloatEquals(Single(1.0), Single(1.0), MakeSingleNaN),
    'FloatEquals Single rejects NaN epsilon');
  Check(not FloatEquals(1.0, 1.0, -0.000001),
    'FloatEquals rejects negative epsilon');
  Check(not FloatEquals(Single(1.0), Single(1.0), Single(-0.000001)),
    'FloatEquals Single rejects negative epsilon');
  Check(FloatIsZero(Single(0.0000001), Single(0.000001)), 'FloatIsZero Single epsilon');
  Check(FloatIsZero(0.0000001, 0.000001), 'FloatIsZero epsilon');
  Check(not FloatIsZero(MakeSingleNaN, Single(0.000001)),
    'FloatIsZero Single rejects NaN value');
  Check(not FloatIsZero(MakeNaN, 0.000001),
    'FloatIsZero Double rejects NaN value');
  Check(not FloatIsZero(MakePositiveInfinity, 0.000001),
    'FloatIsZero Double rejects +Inf value');
  Check(not FloatIsZero(MakeNegativeInfinity, 0.000001),
    'FloatIsZero Double rejects -Inf value');
  Check(not FloatIsZero(MakeSinglePositiveInfinity, Single(0.000001)),
    'FloatIsZero Single rejects +Inf value');
  Check(not FloatIsZero(MakeSingleNegativeInfinity, Single(0.000001)),
    'FloatIsZero Single rejects -Inf value');
  Check(not FloatIsZero(0.0, MakePositiveInfinity),
    'FloatIsZero rejects infinite epsilon');
  Check(not FloatIsZero(Single(0.0), MakeSinglePositiveInfinity),
    'FloatIsZero Single rejects infinite epsilon');
  Check(not FloatIsZero(0.0, MakeNaN),
    'FloatIsZero rejects NaN epsilon');
  Check(not FloatIsZero(Single(0.0), MakeSingleNaN),
    'FloatIsZero Single rejects NaN epsilon');
  Check(not FloatIsZero(0.0, -0.000001),
    'FloatIsZero rejects negative epsilon');
  Check(not FloatIsZero(Single(0.0), Single(-0.000001)),
    'FloatIsZero Single rejects negative epsilon');
end;

procedure TestScalarIEEEEdgeContracts;
var
  LZeroUInt32: UInt32;
  LHighUInt32: UInt32;
  LHugeDouble: Double;
  LTinyDouble: Double;
  LMinSubnormalDouble: Double;
  LDoubleRemainder: Double;
  LWideRemainder: Extended;
  LHugeSingle: Single;
  LTinySingle: Single;
  LMinSubnormalSingle: Single;
  LSingleRemainder: Single;
begin
  LZeroUInt32 := UInt32(0);
  LHighUInt32 := High(UInt32);
  LHugeDouble := 1.0e308;
  LTinyDouble := 1.0e-308;
  LMinSubnormalDouble := MakeMinPositiveSubnormalDouble;
  LHugeSingle := Single(3.0e30);
  LTinySingle := Single(1.0e-30);
  LMinSubnormalSingle := MakeMinPositiveSubnormalSingle;

  CheckEqual(Int64(3), Round(2.5), 'Round Double ties away from zero positive');
  CheckEqual(Int64(-3), Round(-2.5), 'Round Double ties away from zero negative');
  CheckEqual(Int64(1), Round(0.5), 'Round Double half positive');
  CheckEqual(Int64(-1), Round(-0.5), 'Round Double half negative');
  CheckEqual(Int64(3), Round(Single(2.5)), 'Round Single ties away from zero positive');
  CheckEqual(Int64(-3), Round(Single(-2.5)), 'Round Single ties away from zero negative');

  Check(IsDoublePositiveZero(nextpas.core.math.scalar.Abs(MakeDoubleNegativeZero)),
    'Abs Double negative zero returns positive zero');
  Check(IsSinglePositiveZero(nextpas.core.math.scalar.Abs(MakeSingleNegativeZero)),
    'Abs Single negative zero returns positive zero');

  CheckNear(-0.25, Frac(-1.25), 0.0, 'Frac Double negative value keeps fractional sign');
  CheckNear(-0.25, Frac(Single(-1.25)), 0.0, 'Frac Single negative value keeps fractional sign');
  Check(IsDoubleNegativeZero(Frac(MakeDoubleNegativeZero)),
    'Frac Double negative zero keeps input sign');
  Check(IsSingleNegativeZero(Frac(MakeSingleNegativeZero)),
    'Frac Single negative zero keeps input sign');
  Check(IsDoubleNegativeZero(Frac(-1.0)),
    'Frac Double exact negative integer keeps input sign');
  Check(IsSingleNegativeZero(Frac(Single(-1.0))),
    'Frac Single exact negative integer keeps input sign');

  Check(IsInfinite(Hypot(MakePositiveInfinity, MakeNaN)) and
    (Hypot(MakePositiveInfinity, MakeNaN) > 0.0),
    'Hypot Double positive infinity dominates NaN');
  Check(IsInfinite(Hypot(MakeNaN, MakeNegativeInfinity)) and
    (Hypot(MakeNaN, MakeNegativeInfinity) > 0.0),
    'Hypot Double negative infinity dominates NaN');
  Check(IsInfinite(Hypot(MakeSinglePositiveInfinity, MakeSingleNaN)) and
    (Hypot(MakeSinglePositiveInfinity, MakeSingleNaN) > 0.0),
    'Hypot Single positive infinity dominates NaN');
  Check(IsNaN(Hypot(MakeNaN, 1.0)),
    'Hypot Double NaN-only returns NaN');
  Check(IsNaN(Hypot(1.0, MakeNaN)),
    'Hypot Double finite plus NaN-only returns NaN');
  Check(IsNaN(Hypot(MakeSingleNaN, Single(1.0))),
    'Hypot Single NaN-only returns NaN');
  Check(IsNaN(Hypot(Single(1.0), MakeSingleNaN)),
    'Hypot Single finite plus NaN-only returns NaN');
  Check(Hypot(1.0e308, 1.0e308) < MakePositiveInfinity,
    'Hypot Double huge finite inputs stay finite');
  Check(Hypot(Single(3.0e30), Single(4.0e30)) < MakeSinglePositiveInfinity,
    'Hypot Single huge finite inputs stay finite');
  Check(IsInfinite(Hypot(MakeMaxFiniteDouble, MakeMaxFiniteDouble)) and
    (Hypot(MakeMaxFiniteDouble, MakeMaxFiniteDouble) > 0.0),
    'Hypot Double max finite pair saturates to positive infinity');
  Check(IsInfinite(Hypot(MakeMaxFiniteSingle, MakeMaxFiniteSingle)) and
    (Hypot(MakeMaxFiniteSingle, MakeMaxFiniteSingle) > Single(0.0)),
    'Hypot Single max finite pair saturates to positive infinity');
  Check(IsDoublePositiveZero(Hypot(MakeDoubleNegativeZero, 0.0)),
    'Hypot Double signed-zero pair returns positive zero');
  Check(IsDoublePositiveZero(Hypot(0.0, MakeDoubleNegativeZero)),
    'Hypot Double positive and negative zero pair returns positive zero');
  Check(IsSinglePositiveZero(Hypot(MakeSingleNegativeZero, Single(0.0))),
    'Hypot Single signed-zero pair returns positive zero');
  Check(IsSinglePositiveZero(Hypot(Single(0.0), MakeSingleNegativeZero)),
    'Hypot Single positive and negative zero pair returns positive zero');
  CheckNear(LMinSubnormalDouble * 5.0, Hypot(LMinSubnormalDouble * 3.0,
    LMinSubnormalDouble * 4.0), 0.0,
    'Hypot Double min subnormal 3-4-5 stays subnormal finite');
  CheckNear(LMinSubnormalSingle * Single(5.0), Hypot(LMinSubnormalSingle * Single(3.0),
    LMinSubnormalSingle * Single(4.0)), Single(0.0),
    'Hypot Single min subnormal 3-4-5 stays subnormal finite');

  Check(IsDoubleNegativeZero(Fmod(MakeDoubleNegativeZero, 3.0)),
    'Fmod Double keeps negative zero dividend');
  Check(IsSingleNegativeZero(Fmod(MakeSingleNegativeZero, Single(3.0))),
    'Fmod Single keeps negative zero dividend');
  Check(IsDoubleNegativeZero(Fmod(-4.0, 2.0)),
    'Fmod Double exact negative dividend keeps negative zero remainder');
  Check(IsSingleNegativeZero(Fmod(Single(-4.0), Single(2.0))),
    'Fmod Single exact negative dividend keeps negative zero remainder');
  CheckNear(1.5, Fmod(5.5, -2.0), 0.0, 'Fmod Double negative divisor positive dividend');
  CheckNear(-1.5, Fmod(-5.5, -2.0), 0.0, 'Fmod Double negative divisor negative dividend');
  LWideRemainder := Fmod(1.0e308, 3.0);
  Check((LWideRemainder = LWideRemainder) and (LWideRemainder > -3.0) and
    (LWideRemainder < 3.0),
    'Fmod huge untyped finite literals choose wide finite remainder path');
  CheckNear(2.0, Fmod(Double(1.0e308), Double(3.0)), 0.0,
    'Fmod Double typed huge finite literals keep double remainder');
  Check(IsExtendedNegativeZero(Fmod(MakeExtendedNegativeZero, Extended(3.0))),
    'Fmod Extended keeps negative zero dividend');
  Check(IsExtendedNegativeZero(Fmod(Extended(-4.0), Extended(2.0))),
    'Fmod Extended exact negative dividend keeps negative zero remainder');
  Check((Fmod(Extended(1.0), MakeExtendedPositiveInfinity) = Extended(1.0)),
    'Fmod Extended finite over positive infinity returns dividend');
  Check((Fmod(Extended(-1.0), MakeExtendedNegativeInfinity) = Extended(-1.0)),
    'Fmod Extended negative finite over negative infinity returns dividend');
  Check(IsExtendedNaN(Fmod(Extended(1.0), Extended(0.0))),
    'Fmod Extended zero divisor returns NaN');
  Check(IsExtendedNaN(Fmod(MakeExtendedNaN, Extended(1.0))),
    'Fmod Extended NaN dividend returns NaN');
  Check(IsExtendedNaN(Fmod(Extended(1.0), MakeExtendedNaN)),
    'Fmod Extended NaN divisor returns NaN');
  Check(IsExtendedNaN(Fmod(MakeExtendedPositiveInfinity, Extended(1.0))),
    'Fmod Extended positive infinity dividend returns NaN');
  Check(IsExtendedNaN(Fmod(MakeExtendedNegativeInfinity, Extended(1.0))),
    'Fmod Extended negative infinity dividend returns NaN');
  CheckNear(1.0, Fmod(1.0, MakePositiveInfinity), 0.0, 'Fmod Double finite over infinity');
  CheckNear(-1.0, Fmod(-1.0, MakeNegativeInfinity), 0.0, 'Fmod Double negative finite over infinity returns dividend');
  CheckNear(-1.0, Fmod(-1.0, MakePositiveInfinity), 0.0,
    'Fmod Double negative finite over positive infinity returns dividend');
  CheckNear(1.0, Fmod(1.0, MakeNegativeInfinity), 0.0,
    'Fmod Double positive finite over negative infinity returns dividend');
  Check(IsNaN(Fmod(1.0, MakeDoubleNegativeZero)), 'Fmod Double negative zero divisor returns NaN');
  Check(IsNaN(Fmod(MakeNaN, 1.0)), 'Fmod Double NaN dividend returns NaN');
  Check(IsNaN(Fmod(1.0, MakeNaN)), 'Fmod Double NaN divisor returns NaN');
  Check(IsNaN(Fmod(1.0, 0.0)), 'Fmod Double zero divisor returns NaN');
  Check(IsNaN(Fmod(MakePositiveInfinity, 1.0)), 'Fmod Double infinity dividend returns NaN');
  Check(IsNaN(Fmod(MakeNegativeInfinity, 1.0)), 'Fmod Double negative infinity dividend returns NaN');
  CheckNear(Single(1.0), Fmod(Single(1.0), MakeSinglePositiveInfinity), 0.0,
    'Fmod Single finite over infinity returns dividend');
  CheckNear(Single(-1.0), Fmod(Single(-1.0), MakeSingleNegativeInfinity), 0.0,
    'Fmod Single negative finite over infinity returns dividend');
  CheckNear(Single(-1.0), Fmod(Single(-1.0), MakeSinglePositiveInfinity), 0.0,
    'Fmod Single negative finite over positive infinity returns dividend');
  CheckNear(Single(1.0), Fmod(Single(1.0), MakeSingleNegativeInfinity), 0.0,
    'Fmod Single positive finite over negative infinity returns dividend');
  Check(IsNaN(Fmod(Single(1.0), MakeSingleNegativeZero)), 'Fmod Single negative zero divisor returns NaN');
  Check(IsNaN(Fmod(MakeSingleNaN, Single(1.0))), 'Fmod Single NaN dividend returns NaN');
  Check(IsNaN(Fmod(Single(1.0), MakeSingleNaN)), 'Fmod Single NaN divisor returns NaN');
  Check(IsNaN(Fmod(Single(1.0), Single(0.0))), 'Fmod Single zero divisor returns NaN');
  Check(IsNaN(Fmod(MakeSinglePositiveInfinity, Single(1.0))), 'Fmod Single infinity dividend returns NaN');
  Check(IsNaN(Fmod(MakeSingleNegativeInfinity, Single(1.0))), 'Fmod Single negative infinity dividend returns NaN');
  LDoubleRemainder := Fmod(LHugeDouble, LTinyDouble);
  Check((not IsNaN(LDoubleRemainder)) and (not IsInfinite(LDoubleRemainder)) and
    (nextpas.core.math.scalar.Abs(LDoubleRemainder) < LTinyDouble),
    'Fmod Double huge finite quotient stays finite remainder');
  LDoubleRemainder := Fmod(-LHugeDouble, LTinyDouble);
  Check(((LDoubleRemainder < 0.0) or IsDoubleNegativeZero(LDoubleRemainder)) and
    (nextpas.core.math.scalar.Abs(LDoubleRemainder) < LTinyDouble),
    'Fmod Double huge finite quotient keeps dividend sign');
  LSingleRemainder := Fmod(LHugeSingle, LTinySingle);
  Check((not IsNaN(LSingleRemainder)) and (not IsInfinite(LSingleRemainder)) and
    (nextpas.core.math.scalar.Abs(LSingleRemainder) < LTinySingle),
    'Fmod Single huge finite quotient stays finite remainder');
  LSingleRemainder := Fmod(-LHugeSingle, LTinySingle);
  Check(((LSingleRemainder < Single(0.0)) or IsSingleNegativeZero(LSingleRemainder)) and
    (nextpas.core.math.scalar.Abs(LSingleRemainder) < LTinySingle),
    'Fmod Single negative huge finite quotient keeps dividend sign');
  Check(IsDoublePositiveZero(Fmod(LMinSubnormalDouble * 4.0, LMinSubnormalDouble)),
    'Fmod Double min subnormal exact multiple returns positive zero');
  Check(IsDoubleNegativeZero(Fmod(-(LMinSubnormalDouble * 4.0), LMinSubnormalDouble)),
    'Fmod Double min subnormal exact negative multiple returns negative zero');
  CheckNear(LMinSubnormalDouble, Fmod(LMinSubnormalDouble * 5.0,
    LMinSubnormalDouble * 2.0), 0.0,
    'Fmod Double min subnormal divisor keeps one-ulp remainder');
  Check(IsSinglePositiveZero(Fmod(LMinSubnormalSingle * Single(4.0), LMinSubnormalSingle)),
    'Fmod Single min subnormal exact multiple returns positive zero');
  Check(IsSingleNegativeZero(Fmod(-(LMinSubnormalSingle * Single(4.0)), LMinSubnormalSingle)),
    'Fmod Single min subnormal exact negative multiple returns negative zero');
  CheckNear(LMinSubnormalSingle, Fmod(LMinSubnormalSingle * Single(5.0),
    LMinSubnormalSingle * Single(2.0)), Single(0.0),
    'Fmod Single min subnormal divisor keeps one-ulp remainder');

  CheckNear(5.0, Clamp(MakePositiveInfinity, 0.0, 5.0), 0.0,
    'Clamp Double positive infinity clamps high');
  CheckNear(0.0, Clamp(MakeNegativeInfinity, 0.0, 5.0), 0.0,
    'Clamp Double negative infinity clamps low');
  Check(IsDoubleNegativeZero(Clamp(MakeDoubleNegativeZero, 0.0, 1.0)),
    'Clamp Double negative zero inside range keeps sign');

  Check(IsAddOverflow(LHighUInt32, UInt32(1)), 'IsAddOverflow UInt32 high plus one');
  Check(not IsAddOverflow(LHighUInt32 - UInt32(1), UInt32(1)),
    'IsAddOverflow UInt32 high minus one plus one');
  Check(not IsMulOverflow(LZeroUInt32, LHighUInt32),
    'IsMulOverflow UInt32 zero times high');
  Check(not IsMulOverflow(LHighUInt32, LZeroUInt32),
    'IsMulOverflow UInt32 high times zero');
  Check(IsMulOverflow(LHighUInt32, UInt32(2)),
    'IsMulOverflow UInt32 high times two');
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

procedure RaiseGCDLowInt64LowInt64;
begin
  GCD(Low(Int64), Low(Int64));
end;

procedure RaiseGCDZeroLowInt64;
begin
  GCD(Int64(0), Low(Int64));
end;

procedure RaiseLCMLowInt64One;
begin
  LCM(Low(Int64), Int64(1));
end;

procedure RaiseLCMHighInt64TimesTwo;
begin
  LCM(High(Int64), Int64(2));
end;

procedure RaiseLCMHighInt64HighMinusOne;
begin
  LCM(High(Int64), High(Int64) - Int64(1));
end;

procedure TestGCDLCMInt64BoundaryContracts;
begin
  CheckEqual(Int64(2), GCD(Low(Int64), Int64(-2)),
    'GCD Low(Int64) with negative two returns representable divisor');
  CheckEqual(Int64(1), GCD(Low(Int64), High(Int64)),
    'GCD Low(Int64) with High(Int64) stays representable');
  CheckEqual(High(Int64), GCD(Int64(0), -High(Int64)),
    'GCD zero with negative High(Int64) normalizes sign');

  CheckEqual(Int64(0), LCM(Low(Int64), Int64(0)),
    'LCM Low(Int64) with zero returns zero before overflow');
  CheckEqual(Int64(0), LCM(Int64(0), Low(Int64)),
    'LCM zero with Low(Int64) returns zero before overflow');
  CheckEqual(High(Int64), LCM(High(Int64), Int64(1)),
    'LCM High(Int64) with one stays representable');
  CheckEqual(High(Int64), LCM(High(Int64), High(Int64)),
    'LCM High(Int64) with itself stays representable');
  CheckEqual(High(Int64), LCM(High(Int64), Int64(-1)),
    'LCM High(Int64) with negative one normalizes sign');
  CheckEqual(High(Int64), LCM(-High(Int64), High(Int64)),
    'LCM negative High(Int64) with High(Int64) normalizes sign');
  CheckEqual(Int64(42), LCM(Int64(-21), Int64(-6)),
    'LCM negative inputs normalize to positive result');

  ExpectArgumentErrorMessage('GCD: result is outside Int64 range',
    'GCD(Low(Int64), Low(Int64))', @RaiseGCDLowInt64LowInt64);
  ExpectArgumentErrorMessage('GCD: result is outside Int64 range',
    'GCD(0, Low(Int64))', @RaiseGCDZeroLowInt64);
  ExpectArgumentErrorMessage('LCM: result is outside Int64 range',
    'LCM(Low(Int64), 1)', @RaiseLCMLowInt64One);
  ExpectArgumentErrorMessage('LCM: result is outside Int64 range',
    'LCM(High(Int64), 2)', @RaiseLCMHighInt64TimesTwo);
  ExpectArgumentErrorMessage('LCM: result is outside Int64 range',
    'LCM(High(Int64), High(Int64) - 1)', @RaiseLCMHighInt64HighMinusOne);
end;

procedure RaiseFloorNaN;
begin
  Floor(MakeNaN);
end;

procedure RaiseFloorSingleNaN;
begin
  Floor(MakeSingleNaN);
end;

procedure RaiseFloorPositiveInfinity;
begin
  Floor(MakePositiveInfinity);
end;

procedure RaiseFloorSinglePositiveInfinity;
begin
  Floor(MakeSinglePositiveInfinity);
end;

procedure RaiseFloorSingleNegativeInfinity;
begin
  Floor(MakeSingleNegativeInfinity);
end;

procedure RaiseFloorNegativeInfinity;
begin
  Floor(MakeNegativeInfinity);
end;

procedure RaiseFloorBelowInt64Min;
begin
  Floor(-Pow2_63 - 4096.0);
end;

procedure RaiseCeilHugePositive;
begin
  Ceil(1.0e300);
end;

procedure RaiseCeilPositive2Pow63;
begin
  Ceil(Pow2_63);
end;

procedure RaiseCeilNaN;
begin
  Ceil(MakeNaN);
end;

procedure RaiseCeilPositiveInfinity;
begin
  Ceil(MakePositiveInfinity);
end;

procedure RaiseCeilNegativeInfinity;
begin
  Ceil(MakeNegativeInfinity);
end;

procedure RaiseCeilSingleNaN;
begin
  Ceil(MakeSingleNaN);
end;

procedure RaiseCeilSinglePositiveInfinity;
begin
  Ceil(MakeSinglePositiveInfinity);
end;

procedure RaiseCeilSingleNegativeInfinity;
begin
  Ceil(MakeSingleNegativeInfinity);
end;

procedure RaiseCeilHugeNegative;
begin
  Ceil(-1.0e300);
end;

procedure RaiseCeilBelowInt64Min;
begin
  Ceil(-Pow2_63 - 4096.0);
end;

procedure RaiseCeilSinglePositive2Pow63;
begin
  Ceil(Single(Pow2_63));
end;

procedure RaiseCeilSingleBelowInt64Min;
begin
  Ceil(MakeSingleBelowInt64Min);
end;

procedure RaiseTruncPositive2Pow63;
begin
  Trunc(Pow2_63);
end;

procedure RaiseTruncSinglePositive2Pow63;
begin
  Trunc(Single(Pow2_63));
end;

procedure RaiseTruncSingleBelowInt64Min;
begin
  Trunc(MakeSingleBelowInt64Min);
end;

procedure RaiseFloorPositive2Pow63;
begin
  Floor(Pow2_63);
end;

procedure RaiseFloorSinglePositive2Pow63;
begin
  Floor(Single(Pow2_63));
end;

procedure RaiseFloorSingleBelowInt64Min;
begin
  Floor(MakeSingleBelowInt64Min);
end;

procedure RaiseRoundPositive2Pow63;
begin
  Round(Pow2_63);
end;

procedure RaiseRoundSinglePositive2Pow63;
begin
  Round(Single(Pow2_63));
end;

procedure RaiseRoundSingleBelowInt64Min;
begin
  Round(MakeSingleBelowInt64Min);
end;

procedure RaiseRoundNaN;
begin
  Round(MakeNaN);
end;

procedure RaiseRoundSingleNaN;
begin
  Round(MakeSingleNaN);
end;

procedure RaiseRoundPositiveInfinity;
begin
  Round(MakePositiveInfinity);
end;

procedure RaiseRoundNegativeInfinity;
begin
  Round(MakeNegativeInfinity);
end;

procedure RaiseRoundSinglePositiveInfinity;
begin
  Round(MakeSinglePositiveInfinity);
end;

procedure RaiseRoundSingleNegativeInfinity;
begin
  Round(MakeSingleNegativeInfinity);
end;

procedure RaiseRoundBelowInt64Min;
begin
  Round(-Pow2_63 - 4096.0);
end;

procedure RaiseTruncBelowInt64Min;
begin
  Trunc(-Pow2_63 - 4096.0);
end;

procedure RaiseTruncSingleNaN;
begin
  Trunc(MakeSingleNaN);
end;

procedure RaiseTruncNaN;
begin
  Trunc(MakeNaN);
end;

procedure RaiseTruncSinglePositiveInfinity;
begin
  Trunc(MakeSinglePositiveInfinity);
end;

procedure RaiseTruncPositiveInfinity;
begin
  Trunc(MakePositiveInfinity);
end;

procedure RaiseTruncNegativeInfinity;
begin
  Trunc(MakeNegativeInfinity);
end;

procedure RaiseTruncSingleNegativeInfinity;
begin
  Trunc(MakeSingleNegativeInfinity);
end;

procedure RaiseAbsLowInt32;
begin
  nextpas.core.math.scalar.Abs(Low(Int32));
end;

procedure RaiseAbsLowInt64;
begin
  nextpas.core.math.scalar.Abs(Low(Int64));
end;

procedure RaiseClampSingleReversedBounds;
begin
  Clamp(Single(1.0), Single(2.0), Single(1.0));
end;

procedure RaiseClampDoubleReversedBounds;
begin
  Clamp(1.0, 2.0, 1.0);
end;

procedure RaiseClampInt32ReversedBounds;
begin
  Clamp(1, 2, 1);
end;

procedure RaiseClampSingleNaNMin;
begin
  Clamp(Single(1.0), MakeSingleNaN, Single(2.0));
end;

procedure RaiseClampDoubleNaNMax;
begin
  Clamp(1.0, 0.0, MakeNaN);
end;

procedure RaiseClampSingleInfiniteMax;
begin
  Clamp(Single(1.0), Single(0.0), MakeSinglePositiveInfinity);
end;

procedure RaiseWrapSingleReversedBounds;
begin
  Wrap(Single(1.0), Single(2.0), Single(1.0));
end;

procedure RaiseWrapDoubleReversedBounds;
begin
  Wrap(1.0, 2.0, 1.0);
end;

procedure RaiseWrapSingleNaNValue;
begin
  Wrap(MakeSingleNaN, Single(0.0), Single(1.0));
end;

procedure RaiseWrapDoubleInfiniteValue;
begin
  Wrap(MakePositiveInfinity, 0.0, 1.0);
end;

procedure RaiseWrapSingleNaNMin;
begin
  Wrap(Single(1.0), MakeSingleNaN, Single(2.0));
end;

procedure RaiseWrapDoubleInfiniteMax;
begin
  Wrap(1.0, 0.0, MakePositiveInfinity);
end;

procedure RaiseSmoothStepSingleNaNEdge;
begin
  SmoothStep(MakeSingleNaN, Single(1.0), Single(0.5));
end;

procedure RaiseSmoothStepDoubleNaNEdge;
begin
  SmoothStep(MakeNaN, 1.0, 0.5);
end;

procedure RaiseSmoothStepSingleInfiniteEdge;
begin
  SmoothStep(Single(0.0), MakeSinglePositiveInfinity, Single(0.5));
end;

procedure RaiseSmoothStepDoubleInfiniteEdge;
begin
  SmoothStep(0.0, MakePositiveInfinity, 0.5);
end;

procedure RaiseFracNaN;
begin
  Frac(MakeNaN);
end;

procedure RaiseFracSingleNaN;
begin
  Frac(MakeSingleNaN);
end;

procedure RaiseFracPositiveInfinity;
begin
  Frac(MakePositiveInfinity);
end;

procedure RaiseFracNegativeInfinity;
begin
  Frac(MakeNegativeInfinity);
end;

procedure RaiseFracSinglePositiveInfinity;
begin
  Frac(MakeSinglePositiveInfinity);
end;

procedure RaiseFracSingleNegativeInfinity;
begin
  Frac(MakeSingleNegativeInfinity);
end;

procedure RaiseFracPositive2Pow63;
begin
  Frac(Pow2_63);
end;

procedure RaiseFracSinglePositive2Pow63;
begin
  Frac(Single(Pow2_63));
end;

procedure RaiseFracSingleBelowInt64Min;
begin
  Frac(MakeSingleBelowInt64Min);
end;

procedure RaiseFracBelowInt64Min;
begin
  Frac(-Pow2_63 - 4096.0);
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
  CheckEqual(Int64(9223372036854774784), Round(CNearMaxInt64),
    'Round Double near Int64 max does not spuriously overflow');
  CheckEqual(Int64(9223372036854774784), Trunc(CNearMaxInt64), 'Trunc near 2^63');
  Check(IsDoublePositiveZero(Frac(CNearMaxInt64)),
    'Frac Double near 2^63 returns positive zero');

  CheckEqual(Low(Int64), Floor(CInt64Min), 'Floor -2^63');
  CheckEqual(Low(Int64), Ceil(CInt64Min), 'Ceil -2^63');
  CheckEqual(Low(Int64), Round(CInt64Min), 'Round -2^63');
  CheckEqual(Low(Int64), Trunc(CInt64Min), 'Trunc -2^63');
  Check(IsDoubleNegativeZero(Frac(CInt64Min)),
    'Frac Double -2^63 keeps negative zero');

  CheckEqual(Int64(-9223372036854774784), Floor(CNearMinInt64), 'Floor near -2^63');
  CheckEqual(Int64(-9223372036854774784), Ceil(CNearMinInt64), 'Ceil near -2^63');
  CheckEqual(Int64(-9223372036854774784), Round(CNearMinInt64), 'Round near -2^63');
  CheckEqual(Int64(-9223372036854774784), Trunc(CNearMinInt64), 'Trunc near -2^63');
  Check(IsDoubleNegativeZero(Frac(CNearMinInt64)),
    'Frac Double near -2^63 keeps negative zero');

  ExpectArgumentErrorMessage('Floor: NaN cannot be converted to Int64',
    'Floor(NaN)', @RaiseFloorNaN);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(+Inf)', @RaiseFloorPositiveInfinity);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(-Inf)', @RaiseFloorNegativeInfinity);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(Double below -2^63)', @RaiseFloorBelowInt64Min);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(huge positive)', @RaiseCeilHugePositive);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Double 2^63)', @RaiseCeilPositive2Pow63);
  ExpectArgumentErrorMessage('Ceil: NaN cannot be converted to Int64',
    'Ceil(Double NaN)', @RaiseCeilNaN);
  ExpectArgumentErrorMessage('Ceil: infinity cannot be converted to Int64',
    'Ceil(Double +Inf)', @RaiseCeilPositiveInfinity);
  ExpectArgumentErrorMessage('Ceil: infinity cannot be converted to Int64',
    'Ceil(Double -Inf)', @RaiseCeilNegativeInfinity);
  ExpectArgumentErrorMessage('Ceil: NaN cannot be converted to Int64',
    'Ceil(Single NaN)', @RaiseCeilSingleNaN);
  ExpectArgumentErrorMessage('Ceil: infinity cannot be converted to Int64',
    'Ceil(Single +Inf)', @RaiseCeilSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Double huge negative)', @RaiseCeilHugeNegative);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Double below -2^63)', @RaiseCeilBelowInt64Min);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(Double 2^63)', @RaiseTruncPositive2Pow63);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(Double 2^63)', @RaiseFloorPositive2Pow63);
  ExpectArgumentErrorMessage('Round: NaN cannot be converted to Int64',
    'Round(NaN)', @RaiseRoundNaN);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(+Inf)', @RaiseRoundPositiveInfinity);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(Double -Inf)', @RaiseRoundNegativeInfinity);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(Double 2^63)', @RaiseRoundPositive2Pow63);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(Double below -2^63)', @RaiseRoundBelowInt64Min);
  ExpectArgumentErrorMessage('Trunc: NaN cannot be converted to Int64',
    'Trunc(NaN)', @RaiseTruncNaN);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(+Inf)', @RaiseTruncPositiveInfinity);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(Double -Inf)', @RaiseTruncNegativeInfinity);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(Double below -2^63)', @RaiseTruncBelowInt64Min);
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
  ExpectArgumentErrorMessage('Frac: infinity cannot be converted to Int64',
    'Frac(Double -Inf)', @RaiseFracNegativeInfinity);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(Double 2^63)', @RaiseFracPositive2Pow63);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(Double below -2^63)', @RaiseFracBelowInt64Min);
  ExpectArgumentErrorMessage('GCD: result is outside Int64 range',
    'GCD(Low(Int64), 0)', @RaiseGCDLowInt64);
  ExpectArgumentErrorMessage('LCM: result is outside Int64 range',
    'LCM overflow', @RaiseLCMOverflow);
end;

procedure TestSinglePrecisionBoundaryMessages;
begin
  ExpectArgumentErrorMessage('Floor: NaN cannot be converted to Int64',
    'Floor(Single NaN)', @RaiseFloorSingleNaN);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(Single +Inf)', @RaiseFloorSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(Single -Inf)', @RaiseFloorSingleNegativeInfinity);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(Single 2^63)', @RaiseFloorSinglePositive2Pow63);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(Single below -2^63)', @RaiseFloorSingleBelowInt64Min);

  ExpectArgumentErrorMessage('Ceil: infinity cannot be converted to Int64',
    'Ceil(Single -Inf)', @RaiseCeilSingleNegativeInfinity);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Single 2^63)', @RaiseCeilSinglePositive2Pow63);
  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Single below -2^63)', @RaiseCeilSingleBelowInt64Min);

  ExpectArgumentErrorMessage('Round: NaN cannot be converted to Int64',
    'Round(Single NaN)', @RaiseRoundSingleNaN);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(Single +Inf)', @RaiseRoundSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(Single -Inf)', @RaiseRoundSingleNegativeInfinity);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(Single 2^63)', @RaiseRoundSinglePositive2Pow63);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(Single below -2^63)', @RaiseRoundSingleBelowInt64Min);

  ExpectArgumentErrorMessage('Trunc: NaN cannot be converted to Int64',
    'Trunc(Single NaN)', @RaiseTruncSingleNaN);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(Single +Inf)', @RaiseTruncSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(Single -Inf)', @RaiseTruncSingleNegativeInfinity);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(Single 2^63)', @RaiseTruncSinglePositive2Pow63);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(Single below -2^63)', @RaiseTruncSingleBelowInt64Min);

  ExpectArgumentErrorMessage('Frac: NaN cannot be converted to Int64',
    'Frac(Single NaN)', @RaiseFracSingleNaN);
  ExpectArgumentErrorMessage('Frac: infinity cannot be converted to Int64',
    'Frac(Single +Inf)', @RaiseFracSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Frac: infinity cannot be converted to Int64',
    'Frac(Single -Inf)', @RaiseFracSingleNegativeInfinity);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(Single 2^63)', @RaiseFracSinglePositive2Pow63);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(Single below -2^63)', @RaiseFracSingleBelowInt64Min);
end;

procedure TestOverflowHelpers;
var
  LZeroSizeUInt: SizeUInt;
  LHighSizeUInt: SizeUInt;
begin
  LZeroSizeUInt := SizeUInt(0);
  LHighSizeUInt := High(SizeUInt);

  Check(IsAddOverflow(LHighSizeUInt, SizeUInt(1)), 'IsAddOverflow SizeUInt');
  Check(not IsAddOverflow(SizeUInt(10), SizeUInt(20)), 'IsAddOverflow false');
  Check(not IsMulOverflow(LZeroSizeUInt, LHighSizeUInt),
    'IsMulOverflow SizeUInt zero times high');
  Check(not IsMulOverflow(LHighSizeUInt, LZeroSizeUInt),
    'IsMulOverflow SizeUInt high times zero');
  Check(IsMulOverflow(LHighSizeUInt, SizeUInt(2)), 'IsMulOverflow SizeUInt');
  Check(not IsMulOverflow(SizeUInt(10), SizeUInt(20)), 'IsMulOverflow false');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.scalar');
  T.Run('constants', @TestConstants);
  T.Run('min max clamp', @TestMinMaxClamp);
  T.Run('interpolation', @TestInterpolation);
  T.Run('rounding and sign', @TestRoundingAndSign);
  T.Run('float predicates', @TestFloatPredicates);
  T.Run('scalar IEEE edge contracts', @TestScalarIEEEEdgeContracts);
  T.Run('scalar range boundary edge contracts', @TestScalarRangeBoundaryEdgeContracts);
  T.Run('number theory and scalar extras', @TestNumberTheoryAndScalarExtras);
  T.Run('GCD LCM Int64 boundary contracts', @TestGCDLCMInt64BoundaryContracts);
  T.Run('angle conversions', @TestAngleConversions);
  T.Run('scalar sign and angle edge contracts', @TestSignAndAngleEdgeContracts);
  T.Run('integer rounding boundaries', @TestIntegerRoundingBoundaries);
  T.Run('owner-level boundary messages', @TestOwnerLevelBoundaryMessages);
  T.Run('single-precision boundary messages', @TestSinglePrecisionBoundaryMessages);
  T.Run('overflow helpers', @TestOverflowHelpers);
  T.Summary;
end.
