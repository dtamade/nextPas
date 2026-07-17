{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_fibheap;

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.fibheap;

var
  GHeap: TLockFreeFibonacciHeap;
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

procedure Test_InsertExtractMin;
var
  LKey, LValue: Int64;
  LRes: TFibHeapResult;
begin
  WriteLn('--- Insert/ExtractMin ---');
  GHeap := TLockFreeFibonacciHeap.Create;
  try
    Check(GHeap.IsEmpty, 'IsEmpty initially');
    Check(GHeap.Count = 0, 'Count = 0');

    GHeap.Insert(5, 50);
    GHeap.Insert(3, 30);
    GHeap.Insert(7, 70);
    GHeap.Insert(1, 10);
    GHeap.Insert(4, 40);

    Check(GHeap.Count = 5, 'Count = 5');
    Check(not GHeap.IsEmpty, 'IsEmpty = false');

    { Extract min should be 1 }
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrOk, 'ExtractMin(1) = ok');
    Check(LKey = 1, 'Key = 1');
    Check(LValue = 10, 'Value = 10');

    { Extract min should be 3 }
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrOk, 'ExtractMin(3) = ok');
    Check(LKey = 3, 'Key = 3');

    { Extract min should be 4 }
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrOk, 'ExtractMin(4) = ok');
    Check(LKey = 4, 'Key = 4');

    { Extract min should be 5 }
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrOk, 'ExtractMin(5) = ok');
    Check(LKey = 5, 'Key = 5');

    { Extract min should be 7 }
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrOk, 'ExtractMin(7) = ok');
    Check(LKey = 7, 'Key = 7');

    Check(GHeap.IsEmpty, 'IsEmpty after extracting all');
    LRes := GHeap.ExtractMin(LKey, LValue);
    Check(LRes = fhrEmpty, 'ExtractMin from empty = empty');
  finally
    GHeap.Free;
  end;
end;

procedure Test_PeekMin;
var
  LKey, LValue: Int64;
begin
  WriteLn('--- PeekMin ---');
  GHeap := TLockFreeFibonacciHeap.Create;
  try
    Check(GHeap.PeekMin(LKey, LValue) = fhrEmpty, 'PeekMin empty = empty');

    GHeap.Insert(10, 100);
    GHeap.Insert(5, 50);

    Check(GHeap.PeekMin(LKey, LValue) = fhrOk, 'PeekMin = ok');
    Check(LKey = 5, 'PeekMin key = 5');
    Check(LValue = 50, 'PeekMin value = 50');
    Check(GHeap.Count = 2, 'Count still 2 after peek');
  finally
    GHeap.Free;
  end;
end;

procedure Test_DecreaseKey;
var
  LNode: PFibNode;
  LKey, LValue: Int64;
begin
  WriteLn('--- DecreaseKey ---');
  GHeap := TLockFreeFibonacciHeap.Create;
  try
    GHeap.Insert(10, 100);
    LNode := GHeap.Insert(20, 200);
    GHeap.Insert(15, 150);

    { Decrease key of node from 20 to 5 }
    Check(GHeap.DecreaseKey(LNode, 5) = fhrOk, 'DecreaseKey(20 -> 5) = ok');

    GHeap.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');

    { Can't increase key }
    LNode := GHeap.Insert(30, 300);
    Check(GHeap.DecreaseKey(LNode, 40) = fhrInvalidKey, 'DecreaseKey(increase) = invalid');
  finally
    GHeap.Free;
  end;
end;

procedure Test_Merge;
var
  LHeap1, LHeap2: TLockFreeFibonacciHeap;
  LKey, LValue: Int64;
begin
  WriteLn('--- Merge ---');
  LHeap1 := TLockFreeFibonacciHeap.Create;
  LHeap2 := TLockFreeFibonacciHeap.Create;
  try
    LHeap1.Insert(5, 50);
    LHeap1.Insert(10, 100);

    LHeap2.Insert(3, 30);
    LHeap2.Insert(7, 70);

    Check(LHeap1.Merge(LHeap2) = fhrOk, 'Merge = ok');
    Check(LHeap1.Count = 4, 'Count = 4 after merge');
    Check(LHeap2.IsEmpty, 'Other heap empty after merge');

    LHeap1.ExtractMin(LKey, LValue);
    Check(LKey = 3, 'ExtractMin key = 3');

    LHeap1.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');

    LHeap1.ExtractMin(LKey, LValue);
    Check(LKey = 7, 'ExtractMin key = 7');

    LHeap1.ExtractMin(LKey, LValue);
    Check(LKey = 10, 'ExtractMin key = 10');
  finally
    LHeap1.Free;
    LHeap2.Free;
  end;
end;

procedure Test_MergeEmpty;
var
  LHeap1, LHeap2: TLockFreeFibonacciHeap;
  LKey, LValue: Int64;
begin
  WriteLn('--- Merge Empty ---');
  LHeap1 := TLockFreeFibonacciHeap.Create;
  LHeap2 := TLockFreeFibonacciHeap.Create;
  try
    LHeap1.Insert(5, 50);

    { Merge empty into non-empty }
    LHeap1.Merge(LHeap2);
    Check(LHeap1.Count = 1, 'Count = 1 after merging empty');

    { Merge non-empty into empty }
    LHeap2.Merge(LHeap1);
    Check(LHeap2.Count = 1, 'Count = 1 after being merged into');

    LHeap2.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');
  finally
    LHeap1.Free;
    LHeap2.Free;
  end;
end;

procedure Test_LargeScale;
var
  LKey, LValue: Int64;
  I: Int32;
begin
  WriteLn('--- Large Scale ---');
  GHeap := TLockFreeFibonacciHeap.Create;
  try
    { Insert in reverse order }
    for I := 999 downto 0 do
      GHeap.Insert(I, I * 10);

    Check(GHeap.Count = 1000, 'Count = 1000');

    { Extract should be in order }
    for I := 0 to 999 do
    begin
      GHeap.ExtractMin(LKey, LValue);
      if LKey <> I then
      begin
        Check(False, 'ExtractMin key mismatch at ' + IntToStr(I));
        Break;
      end;
    end;
    Check(True, 'All 1000 elements extracted in order');

    Check(GHeap.IsEmpty, 'IsEmpty after extracting all');
  finally
    GHeap.Free;
  end;
end;

procedure Test_DuplicateKeys;
var
  LKey, LValue: Int64;
begin
  WriteLn('--- Duplicate Keys ---');
  GHeap := TLockFreeFibonacciHeap.Create;
  try
    GHeap.Insert(5, 50);
    GHeap.Insert(5, 51);
    GHeap.Insert(5, 52);

    Check(GHeap.Count = 3, 'Count = 3');

    GHeap.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');

    GHeap.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');

    GHeap.ExtractMin(LKey, LValue);
    Check(LKey = 5, 'ExtractMin key = 5');
  finally
    GHeap.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Fibonacci Heap Tests ===');
  Test_InsertExtractMin;
  Test_PeekMin;
  Test_DecreaseKey;
  Test_Merge;
  Test_MergeEmpty;
  Test_LargeScale;
  Test_DuplicateKeys;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
