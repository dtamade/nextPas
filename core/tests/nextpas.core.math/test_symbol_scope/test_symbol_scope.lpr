program test_symbol_scope;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.math,
  nextpas.core.math.trig,
  nextpas.core.simd.mathutil;

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

procedure TestMathAndSimdMathUtilNoAmbiguousCommonSymbols;
var
  LLogZero: Single;
  LLogNegative: Single;
  LLogNaN: Single;
  LLogInfinity: Single;
begin
  CheckNear(1.0, Min(Single(1.0), Single(2.0)), 'Single Min resolves to nextpas.core.math');
  CheckNear(1.0, Min(1.0, 2.0), 'Min resolves to nextpas.core.math');
  CheckNear(2.0, Max(Single(1.0), Single(2.0)), 'Single Max resolves to nextpas.core.math');
  CheckNear(2.0, Max(1.0, 2.0), 'Max resolves to nextpas.core.math');
  CheckEqual(Int64(2), Ceil(Single(1.5)), 'Single Ceil resolves to nextpas.core.math');
  CheckEqual(Int64(2), Ceil(1.5), 'Ceil resolves to nextpas.core.math');
  CheckEqual(Int64(-2), Floor(-1.5), 'Floor resolves to nextpas.core.math');
  CheckNear(5.0, Hypot(Single(3.0), Single(4.0)), 'Single Hypot resolves to nextpas.core.math');
  CheckNear(0.5, SmoothStep(Single(0.0), Single(1.0), Single(0.5)), 'Single SmoothStep resolves to nextpas.core.math');
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

begin
  T := TTestRunner.Create('nextpas.core.math symbol scope');
  T.Run('math + simd.mathutil common symbols', @TestMathAndSimdMathUtilNoAmbiguousCommonSymbols);
  T.Summary;
end.
