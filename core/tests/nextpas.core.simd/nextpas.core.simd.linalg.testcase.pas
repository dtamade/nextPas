{$I ../../src/nextpas.core.settings.inc}

unit nextpas.core.simd.linalg.testcase;

interface

uses
  Classes, nextpas.core.text.conv, fpcunit, testregistry,
  nextpas.core.simd.base,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.linalg;

type
  TTestCase_SimdLinalg = class(TTestCase)
  published
    procedure Test_MatMul_Identity;
    procedure Test_MatMul_2x3_3x2;
    procedure Test_MatVecMul;
    procedure Test_Transpose;
    procedure Test_MatAdd;
    procedure Test_MatScale;
    procedure Test_Trace;
    procedure Test_FrobeniusNorm;
    procedure Test_LU_Decompose;
    procedure Test_SolveLinear;
    procedure Test_MatInverse;
    procedure Test_Determinant;
    procedure Test_OuterProduct;
    procedure Test_Hadamard;
    procedure Test_SumRows;
    procedure Test_SumCols;
  end;

implementation

const
  EPS = 1e-5;

procedure TTestCase_SimdLinalg.Test_MatMul_Identity;
var
  I3, C: TSimdF32Matrix;
  i, j: Integer;
begin
  I3 := TSimdF32Matrix.Identity(3);
  try
    C := MatMulF32(I3, I3);
    try
      for i := 0 to 2 do
        for j := 0 to 2 do
          if i = j then
            AssertEquals('I*I[' + IntToStr(i) + ',' + IntToStr(j) + ']', 1.0, C.Get(i, j), EPS)
          else
            AssertEquals('I*I[' + IntToStr(i) + ',' + IntToStr(j) + ']', 0.0, C.Get(i, j), EPS);
    finally
      C.Free;
    end;
  finally
    I3.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_MatMul_2x3_3x2;
var
  A, B, C: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  B := TSimdF32Matrix.Create(3, 2);
  B.Put(0, 0, 7); B.Put(0, 1, 8);
  B.Put(1, 0, 9); B.Put(1, 1, 10);
  B.Put(2, 0, 11); B.Put(2, 1, 12);

  try
    C := MatMulF32(A, B);
    try
      AssertEquals('MatMul[0,0]', 1*7 + 2*9 + 3*11, C.Get(0, 0), EPS);
      AssertEquals('MatMul[0,1]', 1*8 + 2*10 + 3*12, C.Get(0, 1), EPS);
      AssertEquals('MatMul[1,0]', 4*7 + 5*9 + 6*11, C.Get(1, 0), EPS);
      AssertEquals('MatMul[1,1]', 4*8 + 5*10 + 6*12, C.Get(1, 1), EPS);
    finally
      C.Free;
    end;
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_MatVecMul;
var
  A: TSimdF32Matrix;
  v, w: TSimdF32Array;
begin
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  v := TSimdF32Array.Create(3);
  v.Data[0] := 1; v.Data[1] := 2; v.Data[2] := 3;

  try
    w := MatVecMulF32(A, v);
    try
      AssertEquals('MatVecMul[0]', 1*1 + 2*2 + 3*3, w.Data[0], EPS);
      AssertEquals('MatVecMul[1]', 4*1 + 5*2 + 6*3, w.Data[1], EPS);
    finally
      w.Free;
    end;
  finally
    A.Free;
    v.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_Transpose;
var
  A, B: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  try
    B := A.Transpose;
    try
      AssertEquals('Transpose.Rows', 3, B.Rows);
      AssertEquals('Transpose.Cols', 2, B.Cols);
      AssertEquals('Transpose[0,0]', 1, B.Get(0, 0), EPS);
      AssertEquals('Transpose[1,0]', 2, B.Get(1, 0), EPS);
      AssertEquals('Transpose[2,1]', 6, B.Get(2, 1), EPS);
    finally
      B.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_MatAdd;
var
  A, B, C: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 1); A.Put(0, 1, 2);
  A.Put(1, 0, 3); A.Put(1, 1, 4);

  B := TSimdF32Matrix.Create(2, 2);
  B.Put(0, 0, 5); B.Put(0, 1, 6);
  B.Put(1, 0, 7); B.Put(1, 1, 8);

  try
    C := MatAddF32(A, B);
    try
      AssertEquals('MatAdd[0,0]', 6, C.Get(0, 0), EPS);
      AssertEquals('MatAdd[0,1]', 8, C.Get(0, 1), EPS);
      AssertEquals('MatAdd[1,0]', 10, C.Get(1, 0), EPS);
      AssertEquals('MatAdd[1,1]', 12, C.Get(1, 1), EPS);
    finally
      C.Free;
    end;
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_MatScale;
var
  A, C: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 1); A.Put(0, 1, 2);
  A.Put(1, 0, 3); A.Put(1, 1, 4);

  try
    C := MatScaleF32(A, 3.0);
    try
      AssertEquals('MatScale[0,0]', 3, C.Get(0, 0), EPS);
      AssertEquals('MatScale[0,1]', 6, C.Get(0, 1), EPS);
      AssertEquals('MatScale[1,0]', 9, C.Get(1, 0), EPS);
      AssertEquals('MatScale[1,1]', 12, C.Get(1, 1), EPS);
    finally
      C.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_Trace;
var
  A: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(3, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);
  A.Put(2, 0, 7); A.Put(2, 1, 8); A.Put(2, 2, 9);

  try
    AssertEquals('Trace', 15, MatTraceF32(A), EPS);
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_FrobeniusNorm;
var
  A: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 1); A.Put(0, 1, 2);
  A.Put(1, 0, 3); A.Put(1, 1, 4);

  try
    AssertEquals('FrobeniusNorm', Sqrt(1 + 4 + 9 + 16), MatFrobeniusNormF32(A), EPS);
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_LU_Decompose;
var
  A, L, U: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 2); A.Put(0, 1, 1);
  A.Put(1, 0, 4); A.Put(1, 1, 3);

  try
    L := TSimdF32Matrix.Create(2, 2);
    U := TSimdF32Matrix.Create(2, 2);
    try
      AssertTrue('LU success', LUDecomposeF32(A, L, U));
      // L should be lower triangular, U upper triangular
      AssertEquals('L[0,0]', 1, L.Get(0, 0), EPS);
      AssertEquals('L[1,0]', 2, L.Get(1, 0), EPS);
      AssertEquals('U[0,0]', 2, U.Get(0, 0), EPS);
      AssertEquals('U[0,1]', 1, U.Get(0, 1), EPS);
      AssertEquals('U[1,1]', 1, U.Get(1, 1), EPS);
    finally
      L.Free;
      U.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_SolveLinear;
var
  A: TSimdF32Matrix;
  b, x: TSimdF32Array;
begin
  // Solve: 2x + y = 5, 4x + 3y = 11 => x=2, y=1
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 2); A.Put(0, 1, 1);
  A.Put(1, 0, 4); A.Put(1, 1, 3);

  b := TSimdF32Array.Create(2);
  b.Data[0] := 5; b.Data[1] := 11;

  try
    x := SolveLinearF32(A, b);
    try
      AssertEquals('x[0]', 2, x.Data[0], EPS);
      AssertEquals('x[1]', 1, x.Data[1], EPS);
    finally
      x.Free;
    end;
  finally
    A.Free;
    b.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_MatInverse;
var
  A, AInv, C: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 4); A.Put(0, 1, 7);
  A.Put(1, 0, 2); A.Put(1, 1, 6);

  try
    AInv := MatInverseF32(A);
    try
      // A * A^-1 should be identity
      C := MatMulF32(A, AInv);
      try
        AssertEquals('A*A^-1[0,0]', 1, C.Get(0, 0), EPS);
        AssertEquals('A*A^-1[0,1]', 0, C.Get(0, 1), EPS);
        AssertEquals('A*A^-1[1,0]', 0, C.Get(1, 0), EPS);
        AssertEquals('A*A^-1[1,1]', 1, C.Get(1, 1), EPS);
      finally
        C.Free;
      end;
    finally
      AInv.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_Determinant;
var
  A: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 4); A.Put(0, 1, 7);
  A.Put(1, 0, 2); A.Put(1, 1, 6);

  try
    // det = 4*6 - 7*2 = 24 - 14 = 10
    AssertEquals('Determinant', 10, MatDeterminantF32(A), EPS);
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_OuterProduct;
var
  u, v: TSimdF32Array;
  C: TSimdF32Matrix;
begin
  u := TSimdF32Array.Create(2);
  u.Data[0] := 1; u.Data[1] := 2;

  v := TSimdF32Array.Create(3);
  v.Data[0] := 3; v.Data[1] := 4; v.Data[2] := 5;

  try
    C := OuterProductF32(u, v);
    try
      AssertEquals('Outer[0,0]', 3, C.Get(0, 0), EPS);
      AssertEquals('Outer[0,1]', 4, C.Get(0, 1), EPS);
      AssertEquals('Outer[0,2]', 5, C.Get(0, 2), EPS);
      AssertEquals('Outer[1,0]', 6, C.Get(1, 0), EPS);
      AssertEquals('Outer[1,1]', 8, C.Get(1, 1), EPS);
      AssertEquals('Outer[1,2]', 10, C.Get(1, 2), EPS);
    finally
      C.Free;
    end;
  finally
    u.Free;
    v.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_Hadamard;
var
  A, B, C: TSimdF32Matrix;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0, 0, 1); A.Put(0, 1, 2);
  A.Put(1, 0, 3); A.Put(1, 1, 4);

  B := TSimdF32Matrix.Create(2, 2);
  B.Put(0, 0, 5); B.Put(0, 1, 6);
  B.Put(1, 0, 7); B.Put(1, 1, 8);

  try
    C := MatHadamardF32(A, B);
    try
      AssertEquals('Hadamard[0,0]', 5, C.Get(0, 0), EPS);
      AssertEquals('Hadamard[0,1]', 12, C.Get(0, 1), EPS);
      AssertEquals('Hadamard[1,0]', 21, C.Get(1, 0), EPS);
      AssertEquals('Hadamard[1,1]', 32, C.Get(1, 1), EPS);
    finally
      C.Free;
    end;
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_SumRows;
var
  A: TSimdF32Matrix;
  s: TSimdF32Array;
begin
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  try
    s := MatSumRowsF32(A);
    try
      AssertEquals('SumRows[0]', 6, s.Data[0], EPS);
      AssertEquals('SumRows[1]', 15, s.Data[1], EPS);
    finally
      s.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TTestCase_SimdLinalg.Test_SumCols;
var
  A: TSimdF32Matrix;
  s: TSimdF32Array;
begin
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  try
    s := MatSumColsF32(A);
    try
      AssertEquals('SumCols[0]', 5, s.Data[0], EPS);
      AssertEquals('SumCols[1]', 7, s.Data[1], EPS);
      AssertEquals('SumCols[2]', 9, s.Data[2], EPS);
    finally
      s.Free;
    end;
  finally
    A.Free;
  end;
end;

initialization
  RegisterTest(TTestCase_SimdLinalg);

end.
