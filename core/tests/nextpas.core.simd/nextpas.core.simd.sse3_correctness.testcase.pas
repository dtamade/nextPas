unit nextpas.core.simd.sse3_correctness.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$R-}{$Q-}

interface

uses
  fpcunit, testregistry,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.testcase;

type
  TTestCase_SSE3Correctness = class(TSimdVectorAsmStatefulTestCase)
  private
    procedure VerifyF32x4ArithmeticForBackend(aBackend: TSimdBackend;
      const aLabel: string);
    procedure VerifyF32x4CompareForBackend(aBackend: TSimdBackend;
      const aLabel: string);
  published
    procedure Test_SSE3_F32x4_Arithmetic;
    procedure Test_SSE3_F32x4_Compare;
    procedure Test_SSSE3_F32x4_Arithmetic;
    procedure Test_SSSE3_F32x4_Compare;
    procedure Test_SSE41_F32x4_Arithmetic;
    procedure Test_SSE41_F32x4_Compare;
  end;

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.sse3,
  nextpas.core.simd.ssse3,
  nextpas.core.simd.sse41;

const
  EPS = 1e-6;

procedure TTestCase_SSE3Correctness.VerifyF32x4ArithmeticForBackend(
  aBackend: TSimdBackend; const aLabel: string);
var
  a, b, r, rScalar: TVecF32x4;
begin
  SetVectorAsmEnabled(True);

  if not IsBackendDispatchable(aBackend) then
    Exit;

  a.f[0] := 1.5; a.f[1] := -2.3; a.f[2] := 4.7; a.f[3] := 0.1;
  b.f[0] := 3.2; b.f[1] := 1.1; b.f[2] := -0.5; b.f[3] := 8.9;

  // Scalar reference
  SetActiveBackend(sbScalar);
  rScalar := VecF32x4Add(a, b);
  SetActiveBackend(aBackend);
  r := VecF32x4Add(a, b);
  AssertTrue(aLabel + ' Add[0]', Abs(r.f[0] - rScalar.f[0]) < EPS);
  AssertTrue(aLabel + ' Add[1]', Abs(r.f[1] - rScalar.f[1]) < EPS);
  AssertTrue(aLabel + ' Add[2]', Abs(r.f[2] - rScalar.f[2]) < EPS);
  AssertTrue(aLabel + ' Add[3]', Abs(r.f[3] - rScalar.f[3]) < EPS);

  SetActiveBackend(sbScalar);
  rScalar := VecF32x4Sub(a, b);
  SetActiveBackend(aBackend);
  r := VecF32x4Sub(a, b);
  AssertTrue(aLabel + ' Sub[0]', Abs(r.f[0] - rScalar.f[0]) < EPS);
  AssertTrue(aLabel + ' Sub[1]', Abs(r.f[1] - rScalar.f[1]) < EPS);
  AssertTrue(aLabel + ' Sub[2]', Abs(r.f[2] - rScalar.f[2]) < EPS);
  AssertTrue(aLabel + ' Sub[3]', Abs(r.f[3] - rScalar.f[3]) < EPS);

  SetActiveBackend(sbScalar);
  rScalar := VecF32x4Mul(a, b);
  SetActiveBackend(aBackend);
  r := VecF32x4Mul(a, b);
  AssertTrue(aLabel + ' Mul[0]', Abs(r.f[0] - rScalar.f[0]) < EPS);
  AssertTrue(aLabel + ' Mul[1]', Abs(r.f[1] - rScalar.f[1]) < EPS);
  AssertTrue(aLabel + ' Mul[2]', Abs(r.f[2] - rScalar.f[2]) < EPS);
  AssertTrue(aLabel + ' Mul[3]', Abs(r.f[3] - rScalar.f[3]) < EPS);

  SetActiveBackend(sbScalar);
  rScalar := VecF32x4Div(a, b);
  SetActiveBackend(aBackend);
  r := VecF32x4Div(a, b);
  AssertTrue(aLabel + ' Div[0]', Abs(r.f[0] - rScalar.f[0]) < EPS);
  AssertTrue(aLabel + ' Div[1]', Abs(r.f[1] - rScalar.f[1]) < EPS);
  AssertTrue(aLabel + ' Div[2]', Abs(r.f[2] - rScalar.f[2]) < EPS);
  AssertTrue(aLabel + ' Div[3]', Abs(r.f[3] - rScalar.f[3]) < EPS);
end;

procedure TTestCase_SSE3Correctness.VerifyF32x4CompareForBackend(
  aBackend: TSimdBackend; const aLabel: string);
var
  a, b: TVecF32x4;
  mTarget, mScalar: TMask4;
begin
  SetVectorAsmEnabled(True);

  if not IsBackendDispatchable(aBackend) then
    Exit;

  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 1.0; b.f[1] := 3.0; b.f[2] := 3.0; b.f[3] := 2.0;

  SetActiveBackend(sbScalar);
  mScalar := VecF32x4CmpEq(a, b);
  SetActiveBackend(aBackend);
  mTarget := VecF32x4CmpEq(a, b);
  AssertEquals(aLabel + ' CmpEq mask', Integer(mScalar), Integer(mTarget));

  SetActiveBackend(sbScalar);
  mScalar := VecF32x4CmpLt(a, b);
  SetActiveBackend(aBackend);
  mTarget := VecF32x4CmpLt(a, b);
  AssertEquals(aLabel + ' CmpLt mask', Integer(mScalar), Integer(mTarget));
end;

procedure TTestCase_SSE3Correctness.Test_SSE3_F32x4_Arithmetic;
begin
  VerifyF32x4ArithmeticForBackend(sbSSE3, 'SSE3');
end;

procedure TTestCase_SSE3Correctness.Test_SSE3_F32x4_Compare;
begin
  VerifyF32x4CompareForBackend(sbSSE3, 'SSE3');
end;

procedure TTestCase_SSE3Correctness.Test_SSSE3_F32x4_Arithmetic;
begin
  VerifyF32x4ArithmeticForBackend(sbSSSE3, 'SSSE3');
end;

procedure TTestCase_SSE3Correctness.Test_SSSE3_F32x4_Compare;
begin
  VerifyF32x4CompareForBackend(sbSSSE3, 'SSSE3');
end;

procedure TTestCase_SSE3Correctness.Test_SSE41_F32x4_Arithmetic;
begin
  VerifyF32x4ArithmeticForBackend(sbSSE41, 'SSE4.1');
end;

procedure TTestCase_SSE3Correctness.Test_SSE41_F32x4_Compare;
begin
  VerifyF32x4CompareForBackend(sbSSE41, 'SSE4.1');
end;

initialization
  RegisterTest(TTestCase_SSE3Correctness);

end.
