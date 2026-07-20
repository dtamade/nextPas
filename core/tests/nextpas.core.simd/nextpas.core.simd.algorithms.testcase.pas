{$I ../../src/nextpas.core.settings.inc}

unit nextpas.core.simd.algorithms.testcase;

interface

uses
  nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd.base,
  nextpas.core.simd.algorithms;

{$M+}
type
  TTestCase_SimdAlgorithms = class(TTestFixture)
  published
    procedure Test_ArrayAdd_Basic;
    procedure Test_ArrayAdd_OddCount;
    procedure Test_ArrayAdd_SingleElement;
    procedure Test_ArrayMul_Basic;
    procedure Test_ArrayMulScalar_Basic;
    procedure Test_ArrayAxpy_Basic;
    procedure Test_ReduceSum_Basic;
    procedure Test_ReduceSum_LargeArray;
    procedure Test_ReduceDot_Basic;
    procedure Test_ReduceDot_Orthogonal;
    procedure Test_ReduceMin_Basic;
    procedure Test_ReduceMax_Basic;
    procedure Test_ReduceMinMax_SingleElement;
    procedure Test_NilSafety;
    procedure Test_WidthStepping_Correctness;
  end;

implementation

const
  EPS = 1e-5;

procedure TTestCase_SimdAlgorithms.Test_ArrayAdd_Basic;
var
  A, B, C: array[0..15] of Single;
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    A[i] := i * 1.0;
    B[i] := (15 - i) * 1.0;
  end;
  SimdArrayAdd(@A[0], @B[0], @C[0], 16);
  for i := 0 to 15 do
    CheckNear(15.0, C[i], EPS, 'ArrayAdd[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdAlgorithms.Test_ArrayAdd_OddCount;
var
  A, B, C: array[0..6] of Single;
  i: Integer;
begin
  for i := 0 to 6 do
  begin
    A[i] := i + 1.0;
    B[i] := 10.0;
  end;
  SimdArrayAdd(@A[0], @B[0], @C[0], 7);
  for i := 0 to 6 do
    CheckNear(i + 11.0, C[i], EPS, 'ArrayAdd odd[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdAlgorithms.Test_ArrayAdd_SingleElement;
var
  A, B, C: Single;
begin
  A := 3.14;
  B := 2.71;
  SimdArrayAdd(@A, @B, @C, 1);
  CheckNear(5.85, C, EPS, 'ArrayAdd single');
end;

procedure TTestCase_SimdAlgorithms.Test_ArrayMul_Basic;
var
  A, B, C: array[0..7] of Single;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    A[i] := i + 1.0;
    B[i] := 2.0;
  end;
  SimdArrayMul(@A[0], @B[0], @C[0], 8);
  for i := 0 to 7 do
    CheckNear((i + 1.0) * 2.0, C[i], EPS, 'ArrayMul[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdAlgorithms.Test_ArrayMulScalar_Basic;
var
  A, C: array[0..9] of Single;
  i: Integer;
begin
  for i := 0 to 9 do
    A[i] := i + 1.0;
  SimdArrayMulScalar(@A[0], @C[0], 10, 3.0);
  for i := 0 to 9 do
    CheckNear((i + 1.0) * 3.0, C[i], EPS, 'MulScalar[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdAlgorithms.Test_ArrayAxpy_Basic;
var
  X, Y, D: array[0..7] of Single;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    X[i] := i + 1.0;
    Y[i] := 100.0;
  end;
  SimdArrayAxpy(2.0, @X[0], @Y[0], @D[0], 8);
  for i := 0 to 7 do
    CheckNear(2.0 * (i + 1.0) + 100.0, D[i], EPS, 'Axpy[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceSum_Basic;
var
  A: array[0..7] of Single;
  i: Integer;
  R: Single;
begin
  for i := 0 to 7 do
    A[i] := 1.0;
  R := SimdReduceSum(@A[0], 8);
  CheckNear(8.0, R, EPS, 'ReduceSum 8x1.0');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceSum_LargeArray;
var
  A: array[0..255] of Single;
  i: Integer;
  R, Expected: Single;
begin
  Expected := 0;
  for i := 0 to 255 do
  begin
    A[i] := (i + 1) * 0.01;
    Expected := Expected + A[i];
  end;
  R := SimdReduceSum(@A[0], 256);
  CheckNear(Expected, R, 0.1, 'ReduceSum 256 elements');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceDot_Basic;
var
  A, B: array[0..3] of Single;
  R: Single;
begin
  A[0] := 1; A[1] := 2; A[2] := 3; A[3] := 4;
  B[0] := 5; B[1] := 6; B[2] := 7; B[3] := 8;
  R := SimdReduceDot(@A[0], @B[0], 4);
  CheckNear(1*5 + 2*6 + 3*7 + 4*8, R, EPS, 'Dot product');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceDot_Orthogonal;
var
  A, B: array[0..3] of Single;
  R: Single;
begin
  A[0] := 1; A[1] := 0; A[2] := 0; A[3] := 0;
  B[0] := 0; B[1] := 1; B[2] := 0; B[3] := 0;
  R := SimdReduceDot(@A[0], @B[0], 4);
  CheckNear(0.0, R, EPS, 'Orthogonal dot');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceMin_Basic;
var
  A: array[0..7] of Single;
  R: Single;
begin
  A[0] := 5; A[1] := 3; A[2] := 8; A[3] := 1;
  A[4] := 9; A[5] := 2; A[6] := 7; A[7] := 4;
  R := SimdReduceMin(@A[0], 8);
  CheckNear(1.0, R, EPS, 'ReduceMin');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceMax_Basic;
var
  A: array[0..7] of Single;
  R: Single;
begin
  A[0] := 5; A[1] := 3; A[2] := 8; A[3] := 1;
  A[4] := 9; A[5] := 2; A[6] := 7; A[7] := 4;
  R := SimdReduceMax(@A[0], 8);
  CheckNear(9.0, R, EPS, 'ReduceMax');
end;

procedure TTestCase_SimdAlgorithms.Test_ReduceMinMax_SingleElement;
var
  A: Single;
begin
  A := 42.0;
  CheckNear(42.0, SimdReduceMin(@A, 1), EPS, 'Min single');
  CheckNear(42.0, SimdReduceMax(@A, 1), EPS, 'Max single');
end;

procedure TTestCase_SimdAlgorithms.Test_NilSafety;
var
  A: array[0..3] of Single;
begin
  SimdArrayAdd(nil, @A[0], @A[0], 4);
  SimdArrayAdd(@A[0], nil, @A[0], 4);
  SimdArrayAdd(@A[0], @A[0], nil, 4);
  SimdArrayAdd(@A[0], @A[0], @A[0], 0);
  CheckNear(0.0, SimdReduceSum(nil, 4), EPS, 'Nil safety sum');
  CheckNear(0.0, SimdReduceSum(@A[0], 0), EPS, 'Zero count sum');
end;

procedure TTestCase_SimdAlgorithms.Test_WidthStepping_Correctness;
var
  A, B, C: array[0..32] of Single;
  i, count: Integer;
  Expected: Single;
begin
  for count := 1 to 33 do
  begin
    for i := 0 to count - 1 do
    begin
      A[i] := i * 0.5;
      B[i] := 1.0;
    end;
    SimdArrayAdd(@A[0], @B[0], @C[0], count);
    for i := 0 to count - 1 do
    begin
      Expected := i * 0.5 + 1.0;
      CheckNear(Expected, C[i], EPS, 'Width step count=' + IntToStr(count) + ' i=' + IntToStr(i));
    end;
  end;
end;


end.