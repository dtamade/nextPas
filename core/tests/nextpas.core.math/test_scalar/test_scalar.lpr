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

function MakeSingleNegativeInfinity: Single;
var
  LBits: UInt32;
begin
  LBits := UInt32($FF800000);
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
  LWrapped: Double;
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
  Check(IsSingleNegativeZero(Clamp(MakeSingleNegativeZero, Single(0.0), Single(1.0))),
    'Clamp Single negative zero inside range keeps sign');

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
  CheckNear(0.0, SmoothStep(Single(5.0), Single(5.0), Single(4.0)), 0.0,
    'SmoothStep Single equal edges returns step boundary below');
  CheckNear(1.0, SmoothStep(Single(5.0), Single(5.0), Single(5.0)), 0.0,
    'SmoothStep Single equal edges returns step boundary');
end;

procedure TestAngleConversions;
begin
  CheckNear(PI_VALUE, DegToRad(180.0), 0.0001, 'DegToRad(180)=PI');
  CheckNear(PI_VALUE, DegToRad(Single(180.0)), 0.0001, 'DegToRad(Single 180)=PI');
  CheckNear(180.0, RadToDeg(PI_VALUE), 0.0001, 'RadToDeg(PI)=180');
  CheckNear(180.0, RadToDeg(Single(PI_VALUE)), 0.0001, 'RadToDeg(Single PI)=180');
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
  Check(not FloatEquals(1.0, MakePositiveInfinity, MakePositiveInfinity),
    'FloatEquals rejects infinite epsilon');
  Check(not FloatEquals(Single(1.0), MakeSinglePositiveInfinity, MakeSinglePositiveInfinity),
    'FloatEquals Single rejects infinite epsilon');
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
  LDoubleRemainder: Double;
  LHugeSingle: Single;
  LTinySingle: Single;
  LSingleRemainder: Single;
begin
  LZeroUInt32 := UInt32(0);
  LHighUInt32 := High(UInt32);
  LHugeDouble := 1.0e308;
  LTinyDouble := 1.0e-308;
  LHugeSingle := Single(3.0e30);
  LTinySingle := Single(1.0e-30);

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
  Check(Hypot(1.0e308, 1.0e308) < MakePositiveInfinity,
    'Hypot Double huge finite inputs stay finite');
  Check(Hypot(Single(3.0e30), Single(4.0e30)) < MakeSinglePositiveInfinity,
    'Hypot Single huge finite inputs stay finite');

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
  CheckNear(1.0, Fmod(1.0, MakePositiveInfinity), 0.0, 'Fmod Double finite over infinity');
  Check(IsNaN(Fmod(MakePositiveInfinity, 1.0)), 'Fmod Double infinity dividend returns NaN');
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

procedure RaiseFloorNegativeInfinity;
begin
  Floor(MakeNegativeInfinity);
end;

procedure RaiseCeilHugePositive;
begin
  Ceil(1.0e300);
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

procedure RaiseCeilHugeNegative;
begin
  Ceil(-1.0e300);
end;

procedure RaiseCeilSinglePositive2Pow63;
begin
  Ceil(Single(Pow2_63));
end;

procedure RaiseTruncPositive2Pow63;
begin
  Trunc(Pow2_63);
end;

procedure RaiseTruncSinglePositive2Pow63;
begin
  Trunc(Single(Pow2_63));
end;

procedure RaiseFloorPositive2Pow63;
begin
  Floor(Pow2_63);
end;

procedure RaiseFloorSinglePositive2Pow63;
begin
  Floor(Single(Pow2_63));
end;

procedure RaiseRoundPositive2Pow63;
begin
  Round(Pow2_63);
end;

procedure RaiseRoundSinglePositive2Pow63;
begin
  Round(Single(Pow2_63));
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

procedure RaiseRoundSinglePositiveInfinity;
begin
  Round(MakeSinglePositiveInfinity);
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

procedure RaiseFracSinglePositiveInfinity;
begin
  Frac(MakeSinglePositiveInfinity);
end;

procedure RaiseFracPositive2Pow63;
begin
  Frac(Pow2_63);
end;

procedure RaiseFracSinglePositive2Pow63;
begin
  Frac(Single(Pow2_63));
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

procedure TestSinglePrecisionBoundaryMessages;
begin
  ExpectArgumentErrorMessage('Floor: NaN cannot be converted to Int64',
    'Floor(Single NaN)', @RaiseFloorSingleNaN);
  ExpectArgumentErrorMessage('Floor: infinity cannot be converted to Int64',
    'Floor(Single +Inf)', @RaiseFloorSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Floor: value is outside Int64 range',
    'Floor(Single 2^63)', @RaiseFloorSinglePositive2Pow63);

  ExpectArgumentErrorMessage('Ceil: value is outside Int64 range',
    'Ceil(Single 2^63)', @RaiseCeilSinglePositive2Pow63);

  ExpectArgumentErrorMessage('Round: NaN cannot be converted to Int64',
    'Round(Single NaN)', @RaiseRoundSingleNaN);
  ExpectArgumentErrorMessage('Round: infinity cannot be converted to Int64',
    'Round(Single +Inf)', @RaiseRoundSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Round: value is outside Int64 range',
    'Round(Single 2^63)', @RaiseRoundSinglePositive2Pow63);

  ExpectArgumentErrorMessage('Trunc: NaN cannot be converted to Int64',
    'Trunc(Single NaN)', @RaiseTruncSingleNaN);
  ExpectArgumentErrorMessage('Trunc: infinity cannot be converted to Int64',
    'Trunc(Single +Inf)', @RaiseTruncSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Trunc: value is outside Int64 range',
    'Trunc(Single 2^63)', @RaiseTruncSinglePositive2Pow63);

  ExpectArgumentErrorMessage('Frac: NaN cannot be converted to Int64',
    'Frac(Single NaN)', @RaiseFracSingleNaN);
  ExpectArgumentErrorMessage('Frac: infinity cannot be converted to Int64',
    'Frac(Single +Inf)', @RaiseFracSinglePositiveInfinity);
  ExpectArgumentErrorMessage('Frac: value is outside Int64 range',
    'Frac(Single 2^63)', @RaiseFracSinglePositive2Pow63);
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
  T.Run('angle conversions', @TestAngleConversions);
  T.Run('integer rounding boundaries', @TestIntegerRoundingBoundaries);
  T.Run('owner-level boundary messages', @TestOwnerLevelBoundaryMessages);
  T.Run('single-precision boundary messages', @TestSinglePrecisionBoundaryMessages);
  T.Run('overflow helpers', @TestOverflowHelpers);
  T.Summary;
end.
