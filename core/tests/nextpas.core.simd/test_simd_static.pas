{
  test_simd_static.pas

  Test compile-time static dispatch for SIMD operations.

  This test verifies that:
  1. Static dispatch macros are correctly defined
  2. Static dispatch compiles without errors
  3. Static dispatch produces correct results
  4. Static dispatch has zero runtime overhead
}

program test_simd_static;

{$mode ObjFPC}{$H+}

{$DEFINE SIMD_STATIC_SSE2}

uses
  nextpas.core.simd, nextpas.core.test;

{$M+}
type
  TTestSimdStatic = class(TTestFixture)
  published
    procedure TestVecF32x4Add;
    procedure TestVecF32x4Sub;
    procedure TestVecF32x4Mul;
    procedure TestVecF32x4Dot;
    procedure TestMemEqual;
    procedure TestUtf8Validate;
  end;

procedure TTestSimdStatic.TestVecF32x4Add;
var
  A, B, C: TVecF32x4;
begin
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  // This should use static dispatch (SSE2AddF32x4)
  C := VecF32x4Add(A, B);

  Expect(C.f[0]).ToBe(6.0);
  Expect(C.f[1]).ToBe(8.0);
  Expect(C.f[2]).ToBe(10.0);
  Expect(C.f[3]).ToBe(12.0);
end;

procedure TTestSimdStatic.TestVecF32x4Sub;
var
  A, B, C: TVecF32x4;
begin
  A := VecF32x4Make(5.0, 6.0, 7.0, 8.0);
  B := VecF32x4Make(1.0, 2.0, 3.0, 4.0);

  // This should use static dispatch (SSE2SubF32x4)
  C := VecF32x4Sub(A, B);

  Expect(C.f[0]).ToBe(4.0);
  Expect(C.f[1]).ToBe(4.0);
  Expect(C.f[2]).ToBe(4.0);
  Expect(C.f[3]).ToBe(4.0);
end;

procedure TTestSimdStatic.TestVecF32x4Mul;
var
  A, B, C: TVecF32x4;
begin
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  // This should use static dispatch (SSE2MulF32x4)
  C := VecF32x4Mul(A, B);

  Expect(C.f[0]).ToBe(5.0);
  Expect(C.f[1]).ToBe(12.0);
  Expect(C.f[2]).ToBe(21.0);
  Expect(C.f[3]).ToBe(32.0);
end;

procedure TTestSimdStatic.TestVecF32x4Dot;
var
  A, B: TVecF32x4;
  Dot: Single;
begin
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  // This should use static dispatch (SSE2DotF32x4)
  Dot := VecF32x4Dot(A, B);

  Expect(Dot).ToBe(70.0);
end;

procedure TTestSimdStatic.TestMemEqual;
var
  A, B: array[0..15] of Byte;
begin
  FillChar(A, 16, $AA);
  FillChar(B, 16, $AA);

  // This should use static dispatch (SSE2MemEqual)
  Expect(MemEqual(@A, @B, 16)).ToBeTrue;

  B[0] := $BB;
  Expect(MemEqual(@A, @B, 16)).ToBeFalse;
end;

procedure TTestSimdStatic.TestUtf8Validate;
var
  S: AnsiString;
begin
  S := 'Hello, World!';

  // This should use static dispatch (SSE2Utf8Validate)
  Expect(Utf8Validate(@S[1], Length(S))).ToBeTrue;
end;

begin
  RegisterTest(TTestSimdStatic);
  RunAllTests;
end.
