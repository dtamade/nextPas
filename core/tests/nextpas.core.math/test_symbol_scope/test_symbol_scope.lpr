program test_symbol_scope;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math,
  nextpas.core.math.trig,
  nextpas.core.simd.mathutil;

var
  T: TTestRunner;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

function MakeSingleNaN: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7FC00000;
  Result := LValue.Value;
end;

function MakeSingleNegativeZero: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := LongWord($80000000);
  Result := LValue.Value;
end;

function IsSingleNegativeZero(const AValue: Single): Boolean;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits = LongWord($80000000);
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

procedure TestMathAndSimdMathUtilNoAmbiguousCommonSymbols;
var
  LLogZero: Single;
  LLogNegative: Single;
  LLogNaN: Single;
  LLogInfinity: Single;
begin
  CheckNear(1.0, Min(Single(1.0), Single(2.0)), 'Single Min resolves to nextpas.core.math');
  Check(IsNaN(Min(MakeSingleNaN, Single(1.0))), 'Single Min NaN resolves to nextpas.core.math');
  Check(IsSingleNegativeZero(Min(Single(0.0), MakeSingleNegativeZero)),
    'Single Min zero tie resolves to nextpas.core.math');
  Check(IsSingleNegativeZero(Min(MakeSingleNegativeZero, Single(0.0))),
    'Single Min reverse zero tie resolves to nextpas.core.math');
  CheckNear(1.0, Min(1.0, 2.0), 'Min resolves to nextpas.core.math');
  CheckNear(2.0, Max(Single(1.0), Single(2.0)), 'Single Max resolves to nextpas.core.math');
  Check(IsNaN(Max(MakeSingleNaN, Single(1.0))), 'Single Max NaN resolves to nextpas.core.math');
  Check(not IsSingleNegativeZero(Max(MakeSingleNegativeZero, Single(0.0))),
    'Single Max zero tie resolves to nextpas.core.math');
  Check(not IsSingleNegativeZero(Max(Single(0.0), MakeSingleNegativeZero)),
    'Single Max reverse zero tie resolves to nextpas.core.math');
  CheckNear(2.0, Max(1.0, 2.0), 'Max resolves to nextpas.core.math');
  CheckEqual(Int64(2), Ceil(Single(1.5)), 'Single Ceil resolves to nextpas.core.math');
  CheckEqual(Int64(2), Ceil(1.5), 'Ceil resolves to nextpas.core.math');
  CheckEqual(Int64(-2), Floor(-1.5), 'Floor resolves to nextpas.core.math');
  CheckNear(5.0, Hypot(Single(3.0), Single(4.0)), 'Single Hypot resolves to nextpas.core.math');
  CheckNear(0.5, InverseLerp(Single(0.0), Single(2.0), Single(1.0)), 'Single InverseLerp resolves to nextpas.core.math');
  CheckNear(10.0, Wrap(Single(370.0), Single(0.0), Single(360.0)), 'Single Wrap resolves to nextpas.core.math');
  CheckNear(0.5, SmoothStep(Single(0.0), Single(1.0), Single(0.5)), 'Single SmoothStep resolves to nextpas.core.math');
  CheckNear(PI_VALUE, DegToRad(180.0), 'DegToRad resolves to nextpas.core.math');
  CheckNear(180.0, RadToDeg(PI_VALUE), 'RadToDeg resolves to nextpas.core.math');
  CheckNear(1.0, Sin(HALF_PI), 'Sin remains available with math.trig imported');
  CheckNear(1.0, Sin(Single(HALF_PI)), 'Single Sin remains available with math.trig imported');
  CheckNear(1.0, SimdMinF32(1.0, 2.0), 'SIMD min keeps Simd* name');
  CheckNear(2.0, SimdMaxF32(1.0, 2.0), 'SIMD max keeps Simd* name');
  CheckNear(2.0, SimdCeilF32(1.5), 'SIMD ceil keeps Simd* name');
  CheckNear(-2.0, SimdFloorF32(-1.5), 'SIMD floor keeps Simd* name');

  LLogZero := SimdLnF32(0.0);
  LLogNegative := SimdLnF32(-1.0);
  LLogNaN := SimdLnF32(SimdNaN);
  LLogInfinity := SimdLnF32(SimdInfinity);
  Check(SimdIsInfinite(LLogZero) and (LLogZero < 0.0), 'SimdLnF32(0) returns -Inf');
  Check(SimdIsNaN(LLogNegative), 'SimdLnF32(negative) returns NaN');
  Check(SimdIsNaN(LLogNaN), 'SimdLnF32(NaN) returns NaN');
  Check(SimdIsInfinite(LLogInfinity) and (LLogInfinity > 0.0), 'SimdLnF32(+Inf) returns +Inf');
end;

procedure TestExpandedScalarTrigCommonSymbols;
var
  LFrac: Double;
  LLog: Double;
  LLog2: Double;
  LLog10: Double;
  LRoot: Double;
  LSimdLog: Single;
begin
  CheckNear(2.5, Abs(-2.5), 'Root Abs resolves to nextpas.core.math');
  CheckNear(-1.0, Sign(-42.0), 'Root Sign resolves to nextpas.core.math');
  CheckEqual(Int64(2), Round(1.5), 'Root Round resolves to nextpas.core.math');
  CheckEqual(Int64(-1), Trunc(-1.75), 'Root Trunc resolves to nextpas.core.math');

  LFrac := Frac(-1.25);
  CheckNear(-0.25, LFrac, 'Root Frac resolves to nextpas.core.math');
  CheckNear(1.0, Fmod(5.5, 1.5), 'Root Fmod resolves to nextpas.core.math');

  LLog := Ln(1.0);
  LLog2 := Log2(2.0);
  LLog10 := Log10(10.0);
  LRoot := Sqrt(9.0);
  CheckNear(0.0, LLog, 'Root Ln resolves to nextpas.core.math');
  CheckNear(1.0, LLog2, 'Root Log2 resolves to nextpas.core.math');
  CheckNear(1.0, LLog10, 'Root Log10 resolves to nextpas.core.math');
  CheckNear(3.0, LRoot, 'Root Sqrt resolves to nextpas.core.math');
  CheckNear(3.0, Power(9.0, 0.5), 'Root Power resolves to nextpas.core.math');
  Check(True, 'Root Abs/Round/Ln/Log/Sqrt resolve to nextpas.core.math');

  LSimdLog := SimdLnF32(1.0);
  CheckNear(0.0, LSimdLog, 'SimdLnF32 keeps Simd* name');
  CheckNear(2.0, SimdRoundF32(1.5), 'SimdRoundF32 keeps Simd* name');
  CheckNear(-1.0, SimdTruncFloatF32(-1.75), 'SimdTruncFloatF32 keeps Simd* name');
  Check(True, 'SimdLnF32/SimdRoundF32/SimdTruncFloatF32 keep Simd* names');
end;

begin
  T := TTestRunner.Create('nextpas.core.math symbol scope');
  T.Run('math + simd.mathutil common symbols', @TestMathAndSimdMathUtilNoAmbiguousCommonSymbols);
  T.Run('expanded scalar/trig common symbols', @TestExpandedScalarTrigCommonSymbols);
  T.Summary;
end.
