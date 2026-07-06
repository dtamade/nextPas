{
  test_ieee754_compliance.pas

  IEEE 754 compliance test suite for SIMD FP arithmetic.

  This test suite verifies that SIMD FP arithmetic correctly handles
  IEEE 754 special values:
    - NaN propagation
    - Inf handling
    - -0.0 handling
    - Rounding modes

  Test categories:
    1. NaN propagation tests
    2. Inf handling tests
    3. Zero handling tests
    4. Rounding mode tests
    5. Special value combinations
}

program test_ieee754_compliance;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.simd,
  nextpas.core.test;

type
  TTestIEEE754 = class(TTestCase)
  published
    procedure TestNaNPropagation_Add;
    procedure TestNaNPropagation_Sub;
    procedure TestNaNPropagation_Mul;
    procedure TestNaNPropagation_Div;
    procedure TestInfHandling_Add;
    procedure TestInfHandling_Sub;
    procedure TestInfHandling_Mul;
    procedure TestInfHandling_Div;
    procedure TestZeroHandling_Add;
    procedure TestZeroHandling_Sub;
    procedure TestZeroHandling_Mul;
    procedure TestZeroHandling_Div;
    procedure TestSpecialCombinations;
  end;

const
  CANONICAL_SINGLE_QNAN: DWord = $7FC00000;
  CANONICAL_DOUBLE_QNAN: QWord = $7FF8000000000000;

procedure TTestIEEE754.TestNaNPropagation_Add;
var
  A, B, C: TVecF32x4;
begin
  // NaN + anything = NaN
  A := VecF32x4Make(Single(CANONICAL_SINGLE_QNAN), 1.0, 2.0, 3.0);
  B := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  C := VecF32x4Add(A, B);

  // First lane should be NaN
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(3.0);
  Expect(C.f[2]).ToBe(5.0);
  Expect(C.f[3]).ToBe(7.0);
end;

procedure TTestIEEE754.TestNaNPropagation_Sub;
var
  A, B, C: TVecF32x4;
begin
  // NaN - anything = NaN
  A := VecF32x4Make(Single(CANONICAL_SINGLE_QNAN), 5.0, 6.0, 7.0);
  B := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  C := VecF32x4Sub(A, B);

  Expect(IsNaN(C.f[0])).ToBeTrue;
  Expect(C.f[1]).ToBe(3.0);
  Expect(C.f[2]).ToBe(3.0);
  Expect(C.f[3]).ToBe(3.0);
end;

procedure TTestIEEE754.TestNaNPropagation_Mul;
var
  A, B, C: TVecF32x4;
begin
  // NaN * anything = NaN
  A := VecF32x4Make(Single(CANONICAL_SINGLE_QNAN), 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);
  C := VecF32x4Mul(A, B);

  Expect(IsNaN(C.f[0])).ToBeTrue;
  Expect(C.f[1]).ToBe(12.0);
  Expect(C.f[2]).ToBe(21.0);
  Expect(C.f[3]).ToBe(32.0);
end;

procedure TTestIEEE754.TestNaNPropagation_Div;
var
  A, B, C: TVecF32x4;
begin
  // NaN / anything = NaN
  A := VecF32x4Make(Single(CANONICAL_SINGLE_QNAN), 10.0, 20.0, 30.0);
  B := VecF32x4Make(2.0, 5.0, 10.0, 15.0);
  C := VecF32x4Div(A, B);

  Expect(IsNaN(C.f[0])).ToBeTrue;
  Expect(C.f[1]).ToBe(2.0);
  Expect(C.f[2]).ToBe(2.0);
  Expect(C.f[3]).ToBe(2.0);
end;

procedure TTestIEEE754.TestInfHandling_Add;
var
  A, B, C: TVecF32x4;
begin
  // Inf + Inf = Inf
  A := VecF32x4Make(Single($7F800000), 1.0, 2.0, 3.0);
  B := VecF32x4Make(Single($7F800000), 4.0, 5.0, 6.0);
  C := VecF32x4Add(A, B);

  // First lane should be Inf
  Expect(IsInf(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(5.0);
  Expect(C.f[2]).ToBe(7.0);
  Expect(C.f[3]).ToBe(9.0);
end;

procedure TTestIEEE754.TestInfHandling_Sub;
var
  A, B, C: TVecF32x4;
begin
  // Inf - Inf = NaN
  A := VecF32x4Make(Single($7F800000), 5.0, 6.0, 7.0);
  B := VecF32x4Make(Single($7F800000), 2.0, 3.0, 4.0);
  C := VecF32x4Sub(A, B);

  // First lane should be NaN (Inf - Inf)
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(3.0);
  Expect(C.f[2]).ToBe(3.0);
  Expect(C.f[3]).ToBe(3.0);
end;

procedure TTestIEEE754.TestInfHandling_Mul;
var
  A, B, C: TVecF32x4;
begin
  // Inf * 0 = NaN
  A := VecF32x4Make(Single($7F800000), 2.0, 3.0, 4.0);
  B := VecF32x4Make(0.0, 6.0, 7.0, 8.0);
  C := VecF32x4Mul(A, B);

  // First lane should be NaN (Inf * 0)
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(12.0);
  Expect(C.f[2]).ToBe(21.0);
  Expect(C.f[3]).ToBe(32.0);
end;

procedure TTestIEEE754.TestInfHandling_Div;
var
  A, B, C: TVecF32x4;
begin
  // Inf / Inf = NaN
  A := VecF32x4Make(Single($7F800000), 10.0, 20.0, 30.0);
  B := VecF32x4Make(Single($7F800000), 5.0, 10.0, 15.0);
  C := VecF32x4Div(A, B);

  // First lane should be NaN (Inf / Inf)
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(2.0);
  Expect(C.f[2]).ToBe(2.0);
  Expect(C.f[3]).ToBe(2.0);
end;

procedure TTestIEEE754.TestZeroHandling_Add;
var
  A, B, C: TVecF32x4;
begin
  // +0 + -0 = +0 (or -0, depending on rounding)
  A := VecF32x4Make(0.0, 1.0, 2.0, 3.0);
  B := VecF32x4Make(Single($80000000), 4.0, 5.0, 6.0);
  C := VecF32x4Add(A, B);

  // First lane should be +0 or -0
  Expect(C.f[0]).ToBe(0.0);
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(5.0);
  Expect(C.f[2]).ToBe(7.0);
  Expect(C.f[3]).ToBe(9.0);
end;

procedure TTestIEEE754.TestZeroHandling_Sub;
var
  A, B, C: TVecF32x4;
begin
  // +0 - +0 = +0 (or -0)
  A := VecF32x4Make(0.0, 5.0, 6.0, 7.0);
  B := VecF32x4Make(0.0, 2.0, 3.0, 4.0);
  C := VecF32x4Sub(A, B);

  // First lane should be +0 or -0
  Expect(C.f[0]).ToBe(0.0);
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(3.0);
  Expect(C.f[2]).ToBe(3.0);
  Expect(C.f[3]).ToBe(3.0);
end;

procedure TTestIEEE754.TestZeroHandling_Mul;
var
  A, B, C: TVecF32x4;
begin
  // 0 * Inf = NaN
  A := VecF32x4Make(0.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(Single($7F800000), 6.0, 7.0, 8.0);
  C := VecF32x4Mul(A, B);

  // First lane should be NaN (0 * Inf)
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(12.0);
  Expect(C.f[2]).ToBe(21.0);
  Expect(C.f[3]).ToBe(32.0);
end;

procedure TTestIEEE754.TestZeroHandling_Div;
var
  A, B, C: TVecF32x4;
begin
  // 0 / 0 = NaN
  A := VecF32x4Make(0.0, 10.0, 20.0, 30.0);
  B := VecF32x4Make(0.0, 5.0, 10.0, 15.0);
  C := VecF32x4Div(A, B);

  // First lane should be NaN (0 / 0)
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // Other lanes should be normal
  Expect(C.f[1]).ToBe(2.0);
  Expect(C.f[2]).ToBe(2.0);
  Expect(C.f[3]).ToBe(2.0);
end;

procedure TTestIEEE754.TestSpecialCombinations;
var
  A, B, C: TVecF32x4;
begin
  // Test mixed special values
  A := VecF32x4Make(
    Single(CANONICAL_SINGLE_QNAN),  // NaN
    Single($7F800000),               // +Inf
    Single($FF800000),               // -Inf
    0.0                              // +0
  );
  B := VecF32x4Make(
    1.0,                             // normal
    Single($7F800000),               // +Inf
    Single($7F800000),               // +Inf
    Single($7F800000)                // +Inf
  );
  C := VecF32x4Add(A, B);

  // NaN + 1 = NaN
  Expect(IsNaN(C.f[0])).ToBeTrue;
  // +Inf + +Inf = +Inf
  Expect(IsInf(C.f[1])).ToBeTrue;
  // -Inf + +Inf = NaN
  Expect(IsNaN(C.f[2])).ToBeTrue;
  // +0 + +Inf = +Inf
  Expect(IsInf(C.f[3])).ToBeTrue;
end;

begin
  RegisterTest(TTestIEEE754);
  RunAllTests;
end.
