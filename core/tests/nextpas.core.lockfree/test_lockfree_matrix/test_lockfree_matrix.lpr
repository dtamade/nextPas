program test_lockfree_matrix;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.matrix,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestMatrixBasic;
var
  LMat: TMatrixImpl;
  LVal: Double;
begin
  LMat := TMatrixImpl.Create(3, 3);
  try
    CheckEqual(3, LMat.GetRows);
    CheckEqual(3, LMat.GetCols);

    { Set identity matrix }
    LMat.Put(0, 0, 1.0);
    LMat.Put(0, 1, 0.0);
    LMat.Put(0, 2, 0.0);
    LMat.Put(1, 0, 0.0);
    LMat.Put(1, 1, 1.0);
    LMat.Put(1, 2, 0.0);
    LMat.Put(2, 0, 0.0);
    LMat.Put(2, 1, 0.0);
    LMat.Put(2, 2, 1.0);

    CheckEqual(Ord(mtOk), Ord(LMat.Get(1, 1, LVal)));
    Check(Abs(LVal - 1.0) < 1e-12, 'Diagonal should be 1');

    CheckEqual(Ord(mtOk), Ord(LMat.Get(0, 1, LVal)));
    Check(Abs(LVal) < 1e-12, 'Off-diagonal should be 0');
  finally
    LMat.Free;
  end;
end;

procedure TestMatrixMultiply;
var
  LA, LB, LC: TMatrixImpl;
  LVal: Double;
begin
  { [1 2] * [5 6] = [19 22]
    [3 4]   [7 8]   [43 50] }
  LA := TMatrixImpl.Create(2, 2);
  LB := TMatrixImpl.Create(2, 2);
  try
    LA.Put(0, 0, 1); LA.Put(0, 1, 2);
    LA.Put(1, 0, 3); LA.Put(1, 1, 4);

    LB.Put(0, 0, 5); LB.Put(0, 1, 6);
    LB.Put(1, 0, 7); LB.Put(1, 1, 8);

    CheckEqual(Ord(mtOk), Ord(LA.Multiply(LB, LC)));
    try
      Check(Abs(LC.FData[0] - 19) < 1e-12, 'C[0,0] should be 19');
      Check(Abs(LC.FData[1] - 22) < 1e-12, 'C[0,1] should be 22');
      Check(Abs(LC.FData[2] - 43) < 1e-12, 'C[1,0] should be 43');
      Check(Abs(LC.FData[3] - 50) < 1e-12, 'C[1,1] should be 50');
    finally
      LC.Free;
    end;
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestMatrixTranspose;
var
  LA, LB: TMatrixImpl;
begin
  LA := TMatrixImpl.Create(2, 3);
  try
    LA.Put(0, 0, 1); LA.Put(0, 1, 2); LA.Put(0, 2, 3);
    LA.Put(1, 0, 4); LA.Put(1, 1, 5); LA.Put(1, 2, 6);

    CheckEqual(Ord(mtOk), Ord(LA.Transpose(LB)));
    try
      CheckEqual(3, LB.GetRows);
      CheckEqual(2, LB.GetCols);
      Check(Abs(LB.FData[0] - 1) < 1e-12, 'T[0,0] = 1');
      Check(Abs(LB.FData[1] - 4) < 1e-12, 'T[0,1] = 4');
      Check(Abs(LB.FData[2] - 2) < 1e-12, 'T[1,0] = 2');
      Check(Abs(LB.FData[3] - 5) < 1e-12, 'T[1,1] = 5');
      Check(Abs(LB.FData[4] - 3) < 1e-12, 'T[2,0] = 3');
      Check(Abs(LB.FData[5] - 6) < 1e-12, 'T[2,1] = 6');
    finally
      LB.Free;
    end;
  finally
    LA.Free;
  end;
end;

procedure TestMatrixDeterminant;
var
  LMat: TMatrixImpl;
  LDet: Double;
begin
  { [1 2] det = 1*4 - 2*3 = -2
    [3 4] }
  LMat := TMatrixImpl.Create(2, 2);
  try
    LMat.Put(0, 0, 1); LMat.Put(0, 1, 2);
    LMat.Put(1, 0, 3); LMat.Put(1, 1, 4);

    CheckEqual(Ord(mtOk), Ord(LMat.Determinant(LDet)));
    Check(Abs(LDet - (-2)) < 1e-10, 'Det should be -2');
  finally
    LMat.Free;
  end;
end;

procedure TestMatrixInverse;
var
  LMat, LInv: TMatrixImpl;
  LVal: Double;
begin
  { [1 2] inverse = [-2  1]
    [3 4]           [1.5 -0.5] }
  LMat := TMatrixImpl.Create(2, 2);
  try
    LMat.Put(0, 0, 1); LMat.Put(0, 1, 2);
    LMat.Put(1, 0, 3); LMat.Put(1, 1, 4);

    CheckEqual(Ord(mtOk), Ord(LMat.Inverse(LInv)));
    try
      Check(Abs(LInv.FData[0] - (-2)) < 1e-10, 'Inv[0,0] = -2');
      Check(Abs(LInv.FData[1] - 1) < 1e-10, 'Inv[0,1] = 1');
      Check(Abs(LInv.FData[2] - 1.5) < 1e-10, 'Inv[1,0] = 1.5');
      Check(Abs(LInv.FData[3] - (-0.5)) < 1e-10, 'Inv[1,1] = -0.5');
    finally
      LInv.Free;
    end;
  finally
    LMat.Free;
  end;
end;

procedure TestMatrixSingular;
var
  LMat: TMatrixImpl;
  LDet: Double;
begin
  { Singular matrix: [1 2]
                     [2 4] }
  LMat := TMatrixImpl.Create(2, 2);
  try
    LMat.Put(0, 0, 1); LMat.Put(0, 1, 2);
    LMat.Put(1, 0, 2); LMat.Put(1, 1, 4);

    CheckEqual(Ord(mtSingular), Ord(LMat.Determinant(LDet)));
  finally
    LMat.Free;
  end;
end;

procedure TestMatrixClose;
var
  LMat: TMatrixImpl;
begin
  LMat := TMatrixImpl.Create(2, 2);
  try
    LMat.Put(0, 0, 1);
    LMat.Close;
    Check(LMat.IsClosed, 'Should be closed');
    CheckEqual(Ord(mtClosed), Ord(LMat.Put(1, 1, 2)));
  finally
    LMat.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_matrix ===');
  WriteLn;

  TestMatrixBasic;
  WriteLn('  + Basic get/put');

  TestMatrixMultiply;
  WriteLn('  + Multiply');

  TestMatrixTranspose;
  WriteLn('  + Transpose');

  TestMatrixDeterminant;
  WriteLn('  + Determinant');

  TestMatrixInverse;
  WriteLn('  + Inverse');

  TestMatrixSingular;
  WriteLn('  + Singular matrix');

  TestMatrixClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All Matrix tests passed!');
end.
