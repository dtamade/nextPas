program test_linalg_f64;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.linalg;

var
  LPass, LFail: Integer;

procedure Check(const aName: string; aGot, aExpect: Double; aTol: Double = 1e-10);
begin
  if System.Abs(aGot - aExpect) <= aTol then Inc(LPass)
  else begin WriteLn('  FAIL ', aName, ': got=', aGot:0:12, ' expect=', aExpect:0:12); Inc(LFail); end;
end;

var
  A, B, C, I3: TSimdF64Matrix;
  v, w: TSimdF64Array;
  i, j: Integer;
begin
  LPass := 0;
  LFail := 0;

  // Identity
  I3 := TSimdF64Matrix.Identity(3);
  Check('Identity[0,0]', I3.Get(0,0), 1.0);
  Check('Identity[1,1]', I3.Get(1,1), 1.0);
  Check('Identity[0,1]', I3.Get(0,1), 0.0);
  Check('Identity[2,0]', I3.Get(2,0), 0.0);

  // MatMul: I * I = I
  C := MatMulF64(I3, I3);
  for i := 0 to 2 do
    for j := 0 to 2 do
      if i = j then Check('I*I['+IntToStr(i)+','+IntToStr(j)+']', C.Get(i,j), 1.0)
      else Check('I*I['+IntToStr(i)+','+IntToStr(j)+']', C.Get(i,j), 0.0);
  C.Free;

  // MatMul: 2x3 * 3x2
  A := TSimdF64Matrix.Create(2, 3);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(0,2, 3);
  A.Put(1,0, 4); A.Put(1,1, 5); A.Put(1,2, 6);
  B := TSimdF64Matrix.Create(3, 2);
  B.Put(0,0, 7); B.Put(0,1, 8);
  B.Put(1,0, 9); B.Put(1,1, 10);
  B.Put(2,0, 11); B.Put(2,1, 12);
  C := MatMulF64(A, B);
  Check('MatMul[0,0]', C.Get(0,0), 1*7+2*9+3*11);
  Check('MatMul[0,1]', C.Get(0,1), 1*8+2*10+3*12);
  Check('MatMul[1,0]', C.Get(1,0), 4*7+5*9+6*11);
  Check('MatMul[1,1]', C.Get(1,1), 4*8+5*10+6*12);
  C.Free; A.Free; B.Free;

  // MatVecMul
  A := TSimdF64Matrix.Create(2, 3);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(0,2, 3);
  A.Put(1,0, 4); A.Put(1,1, 5); A.Put(1,2, 6);
  v := TSimdF64Array.Create(3);
  v.Data[0] := 1; v.Data[1] := 2; v.Data[2] := 3;
  w := MatVecMulF64(A, v);
  Check('MatVecMul[0]', w.Data[0], 1*1+2*2+3*3);
  Check('MatVecMul[1]', w.Data[1], 4*1+5*2+6*3);
  w.Free; v.Free; A.Free;

  // Transpose
  A := TSimdF64Matrix.Create(2, 3);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(0,2, 3);
  A.Put(1,0, 4); A.Put(1,1, 5); A.Put(1,2, 6);
  B := A.Transpose;
  Check('Transpose.Rows', B.Rows, 3);
  Check('Transpose.Cols', B.Cols, 2);
  Check('Transpose[0,0]', B.Get(0,0), 1);
  Check('Transpose[1,0]', B.Get(1,0), 2);
  Check('Transpose[2,1]', B.Get(2,1), 6);
  B.Free; A.Free;

  // MatAdd
  A := TSimdF64Matrix.Create(2, 2);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(1,0, 3); A.Put(1,1, 4);
  B := TSimdF64Matrix.Create(2, 2);
  B.Put(0,0, 5); B.Put(0,1, 6); B.Put(1,0, 7); B.Put(1,1, 8);
  C := MatAddF64(A, B);
  Check('MatAdd[0,0]', C.Get(0,0), 6);
  Check('MatAdd[1,1]', C.Get(1,1), 12);
  C.Free; A.Free; B.Free;

  // MatScale
  A := TSimdF64Matrix.Create(2, 2);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(1,0, 3); A.Put(1,1, 4);
  C := MatScaleF64(A, 3.0);
  Check('MatScale[0,0]', C.Get(0,0), 3);
  Check('MatScale[1,1]', C.Get(1,1), 12);
  C.Free; A.Free;

  // Trace
  A := TSimdF64Matrix.Create(3, 3);
  A.Put(0,0, 1); A.Put(1,1, 5); A.Put(2,2, 9);
  Check('Trace', MatTraceF64(A), 15.0);
  A.Free;

  // FrobeniusNorm
  A := TSimdF64Matrix.Create(2, 2);
  A.Put(0,0, 1); A.Put(0,1, 2); A.Put(1,0, 3); A.Put(1,1, 4);
  Check('FrobNorm', MatFrobeniusNormF64(A), System.Sqrt(1+4+9+16), 1e-10);
  A.Free;

  I3.Free;

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then WriteLn('All tests passed!')
  else Halt(1);
end.
