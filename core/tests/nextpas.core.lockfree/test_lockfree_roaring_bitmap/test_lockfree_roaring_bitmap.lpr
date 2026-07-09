{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_roaring_bitmap;

uses
  SysUtils,
  nextpas.core.lockfree.roaring_bitmap;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_Empty;
var
  LBitmap: TRoaringBitmap;
  LVal: UInt32;
begin
  WriteLn('--- Empty ---');
  LBitmap := TRoaringBitmap.Create;
  try
    Check(LBitmap.Cardinality = 0, 'empty cardinality = 0');
    Check(LBitmap.IsEmpty, 'empty IsEmpty');
    Check(not LBitmap.Contains(0), 'empty not contains 0');
    Check(not LBitmap.Contains(100), 'empty not contains 100');
    Check(not LBitmap.Min(LVal), 'empty no Min');
    Check(not LBitmap.Max(LVal), 'empty no Max');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_AddContains;
var
  LBitmap: TRoaringBitmap;
begin
  WriteLn('--- Add/Contains ---');
  LBitmap := TRoaringBitmap.Create;
  try
    Check(LBitmap.Add(1) = rbOk, 'Add(1) = ok');
    Check(LBitmap.Add(2) = rbOk, 'Add(2) = ok');
    Check(LBitmap.Add(3) = rbOk, 'Add(3) = ok');
    Check(LBitmap.Add(1) = rbExists, 'Add(1) again = exists');
    Check(LBitmap.Cardinality = 3, 'cardinality = 3');
    Check(LBitmap.Contains(1), 'contains 1');
    Check(LBitmap.Contains(2), 'contains 2');
    Check(LBitmap.Contains(3), 'contains 3');
    Check(not LBitmap.Contains(4), 'not contains 4');
    Check(not LBitmap.Contains(0), 'not contains 0');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_Remove;
var
  LBitmap: TRoaringBitmap;
begin
  WriteLn('--- Remove ---');
  LBitmap := TRoaringBitmap.Create;
  try
    LBitmap.Add(10);
    LBitmap.Add(20);
    LBitmap.Add(30);
    Check(LBitmap.Cardinality = 3, 'cardinality = 3');
    Check(LBitmap.Remove(20) = rbOk, 'Remove(20) = ok');
    Check(LBitmap.Cardinality = 2, 'cardinality = 2');
    Check(not LBitmap.Contains(20), 'not contains 20 after remove');
    Check(LBitmap.Contains(10), 'still contains 10');
    Check(LBitmap.Contains(30), 'still contains 30');
    Check(LBitmap.Remove(20) = rbNotFound, 'Remove(20) again = not found');
    Check(LBitmap.Remove(99) = rbNotFound, 'Remove(99) = not found');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_LargeRange;
var
  LBitmap: TRoaringBitmap;
  I: Int32;
begin
  WriteLn('--- Large Range ---');
  LBitmap := TRoaringBitmap.Create;
  try
    { Add 10000 values to trigger array→bitmap promotion }
    for I := 0 to 9999 do
      LBitmap.Add(UInt32(I));
    Check(LBitmap.Cardinality = 10000, '10000 cardinality');
    Check(LBitmap.Contains(0), 'contains 0');
    Check(LBitmap.Contains(5000), 'contains 5000');
    Check(LBitmap.Contains(9999), 'contains 9999');
    Check(not LBitmap.Contains(10000), 'not contains 10000');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_MinMax;
var
  LBitmap: TRoaringBitmap;
  LVal: UInt32;
begin
  WriteLn('--- Min/Max ---');
  LBitmap := TRoaringBitmap.Create;
  try
    LBitmap.Add(100);
    LBitmap.Add(50);
    LBitmap.Add(200);
    LBitmap.Add(1);
    Check(LBitmap.Min(LVal), 'has Min');
    Check(LVal = 1, 'Min = 1');
    Check(LBitmap.Max(LVal), 'has Max');
    Check(LVal = 200, 'Max = 200');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_MinMaxLarge;
var
  LBitmap: TRoaringBitmap;
  LVal: UInt32;
  I: Int32;
begin
  WriteLn('--- Min/Max Large ---');
  LBitmap := TRoaringBitmap.Create;
  try
    for I := 0 to 999 do
      LBitmap.Add(UInt32(I * 100));
    Check(LBitmap.Min(LVal), 'has Min');
    Check(LVal = 0, 'Min = 0');
    Check(LBitmap.Max(LVal), 'has Max');
    Check(LVal = 99900, 'Max = 99900');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_SparseValues;
var
  LBitmap: TRoaringBitmap;
  LVal: UInt32;
begin
  WriteLn('--- Sparse Values ---');
  LBitmap := TRoaringBitmap.Create;
  try
    { Values across different containers }
    LBitmap.Add(0);
    LBitmap.Add(65536);
    LBitmap.Add(131072);
    LBitmap.Add($FFFFFFFF);
    Check(LBitmap.Cardinality = 4, '4 sparse cardinality');
    Check(LBitmap.Contains(0), 'contains 0');
    Check(LBitmap.Contains(65536), 'contains 65536');
    Check(LBitmap.Contains(131072), 'contains 131072');
    Check(LBitmap.Contains($FFFFFFFF), 'contains $FFFFFFFF');
    Check(LBitmap.Min(LVal), 'has Min');
    Check(LVal = 0, 'Min = 0');
    Check(LBitmap.Max(LVal), 'has Max');
    Check(LVal = $FFFFFFFF, 'Max = $FFFFFFFF');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

procedure Test_And;
var
  LA, LB, LC: TRoaringBitmap;
begin
  WriteLn('--- AND ---');
  LA := TRoaringBitmap.Create;
  LB := TRoaringBitmap.Create;
  try
    LA.Add(1); LA.Add(2); LA.Add(3); LA.Add(4);
    LB.Add(2); LB.Add(4); LB.Add(6);
    LC := LA.AndWith(LB);
    try
      Check(LC.Cardinality = 2, 'AND cardinality = 2');
      Check(not LC.Contains(1), 'AND not contains 1');
      Check(LC.Contains(2), 'AND contains 2');
      Check(not LC.Contains(3), 'AND not contains 3');
      Check(LC.Contains(4), 'AND contains 4');
      Check(not LC.Contains(6), 'AND not contains 6');
    finally
      LC.Free;
    end;
    LA.Free;
    LB.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LA.Free;
      LB.Free;
    end;
  end;
end;

procedure Test_Or;
var
  LA, LB, LC: TRoaringBitmap;
begin
  WriteLn('--- OR ---');
  LA := TRoaringBitmap.Create;
  LB := TRoaringBitmap.Create;
  try
    LA.Add(1); LA.Add(2); LA.Add(3);
    LB.Add(3); LB.Add(4); LB.Add(5);
    LC := LA.OrWith(LB);
    try
      Check(LC.Cardinality = 5, 'OR cardinality = 5');
      Check(LC.Contains(1), 'OR contains 1');
      Check(LC.Contains(2), 'OR contains 2');
      Check(LC.Contains(3), 'OR contains 3');
      Check(LC.Contains(4), 'OR contains 4');
      Check(LC.Contains(5), 'OR contains 5');
      Check(not LC.Contains(6), 'OR not contains 6');
    finally
      LC.Free;
    end;
    LA.Free;
    LB.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LA.Free;
      LB.Free;
    end;
  end;
end;

procedure Test_Xor;
var
  LA, LB, LC: TRoaringBitmap;
begin
  WriteLn('--- XOR ---');
  LA := TRoaringBitmap.Create;
  LB := TRoaringBitmap.Create;
  try
    LA.Add(1); LA.Add(2); LA.Add(3);
    LB.Add(2); LB.Add(3); LB.Add(4);
    LC := LA.XorWith(LB);
    try
      Check(LC.Cardinality = 2, 'XOR cardinality = 2');
      Check(LC.Contains(1), 'XOR contains 1');
      Check(not LC.Contains(2), 'XOR not contains 2');
      Check(not LC.Contains(3), 'XOR not contains 3');
      Check(LC.Contains(4), 'XOR contains 4');
    finally
      LC.Free;
    end;
    LA.Free;
    LB.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LA.Free;
      LB.Free;
    end;
  end;
end;

procedure Test_AndNot;
var
  LA, LB, LC: TRoaringBitmap;
begin
  WriteLn('--- AND NOT ---');
  LA := TRoaringBitmap.Create;
  LB := TRoaringBitmap.Create;
  try
    LA.Add(1); LA.Add(2); LA.Add(3); LA.Add(4);
    LB.Add(2); LB.Add(4);
    LC := LA.AndNot(LB);
    try
      Check(LC.Cardinality = 2, 'ANDNOT cardinality = 2');
      Check(LC.Contains(1), 'ANDNOT contains 1');
      Check(not LC.Contains(2), 'ANDNOT not contains 2');
      Check(LC.Contains(3), 'ANDNOT contains 3');
      Check(not LC.Contains(4), 'ANDNOT not contains 4');
    finally
      LC.Free;
    end;
    LA.Free;
    LB.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LA.Free;
      LB.Free;
    end;
  end;
end;

procedure Test_Clear;
var
  LBitmap: TRoaringBitmap;
begin
  WriteLn('--- Clear ---');
  LBitmap := TRoaringBitmap.Create;
  try
    LBitmap.Add(1);
    LBitmap.Add(2);
    LBitmap.Add(3);
    Check(LBitmap.Cardinality = 3, 'before clear cardinality = 3');
    LBitmap.Clear;
    Check(LBitmap.Cardinality = 0, 'after clear cardinality = 0');
    Check(LBitmap.IsEmpty, 'after clear IsEmpty');
    Check(not LBitmap.Contains(1), 'after clear not contains 1');
    LBitmap.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LBitmap.Free;
    end;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;
  WriteLn('=== RoaringBitmap Tests ===');
  Test_Empty;
  Test_AddContains;
  Test_Remove;
  Test_LargeRange;
  Test_MinMax;
  Test_MinMaxLarge;
  Test_SparseValues;
  Test_And;
  Test_Or;
  Test_Xor;
  Test_AndNot;
  Test_Clear;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
