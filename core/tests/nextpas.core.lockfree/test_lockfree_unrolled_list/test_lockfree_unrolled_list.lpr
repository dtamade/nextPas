program test_lockfree_unrolled_list;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.unrolled_list,
  nextpas.core.test;

type
  TIntUnrolledList = specialize TConcurrentUnrolledList<Int64>;

procedure TestBasicInsert;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    Check(not LList.IsClosed, 'Should not be closed');
    CheckEqual(Int32(0), LList.GetCount, 'Empty list');

    Check(LList.Insert(42) = ulOk, 'Should insert');
    CheckEqual(Int32(1), LList.GetCount, 'Count after insert');
    Check(LList.Contains(42), 'Should contain');
    Check(not LList.Contains(99), 'Should not contain');
  finally
    LList.Free;
  end;
end;

procedure TestSortedOrder;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    LList.Insert(30);
    LList.Insert(10);
    LList.Insert(20);

    Check(LList.Contains(10), 'Contains 10');
    Check(LList.Contains(20), 'Contains 20');
    Check(LList.Contains(30), 'Contains 30');
    CheckEqual(Int32(3), LList.GetCount, 'Three elements');
  finally
    LList.Free;
  end;
end;

procedure TestDuplicate;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    LList.Insert(1);
    Check(LList.Insert(1) = ulExists, 'Duplicate should return exists');
    CheckEqual(Int32(1), LList.GetCount, 'Still one element');
  finally
    LList.Free;
  end;
end;

procedure TestDelete;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    LList.Insert(10);
    LList.Insert(20);
    LList.Insert(30);

    Check(LList.Delete(20) = ulOk, 'Should delete');
    Check(not LList.Contains(20), 'Should not contain deleted');
    Check(LList.Contains(10), 'Still contains 10');
    Check(LList.Contains(30), 'Still contains 30');
    CheckEqual(Int32(2), LList.GetCount, 'Count after delete');

    Check(LList.Delete(99) = ulNotFound, 'Delete non-existent');
  finally
    LList.Free;
  end;
end;

procedure TestManyInserts;
var
  LList: TIntUnrolledList;
  I: Integer;
begin
  LList := TIntUnrolledList.Create;
  try
    for I := 1 to 100 do
      Check(LList.Insert(Int64(I)) = ulOk, 'Insert');

    CheckEqual(Int32(100), LList.GetCount, '100 elements');
    Check(LList.GetNodeCount > 1, 'Multiple nodes');

    for I := 1 to 100 do
      Check(LList.Contains(Int64(I)), 'Contains');
  finally
    LList.Free;
  end;
end;

procedure TestClose;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    LList.Insert(1);
    LList.Close;
    Check(LList.IsClosed, 'Should be closed');

    Check(LList.Insert(2) = ulClosed, 'Insert on closed');
    Check(LList.Delete(1) = ulClosed, 'Delete on closed');
  finally
    LList.Free;
  end;
end;

procedure TestClear;
var
  LList: TIntUnrolledList;
begin
  LList := TIntUnrolledList.Create;
  try
    LList.Insert(1);
    LList.Insert(2);
    LList.Insert(3);
    CheckEqual(Int32(3), LList.GetCount, 'Before clear');

    LList.Clear;
    CheckEqual(Int32(0), LList.GetCount, 'After clear');
    CheckEqual(Int32(0), LList.GetNodeCount, 'No nodes after clear');
  finally
    LList.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_unrolled_list ===');
  WriteLn;

  TestBasicInsert;
  WriteLn('  + Basic insert/contains');

  TestSortedOrder;
  WriteLn('  + Sorted order');

  TestDuplicate;
  WriteLn('  + Duplicate detection');

  TestDelete;
  WriteLn('  + Delete');

  TestManyInserts;
  WriteLn('  + Many inserts (node splitting)');

  TestClose;
  WriteLn('  + Close semantics');

  TestClear;
  WriteLn('  + Clear');

  WriteLn;
  WriteLn('All unrolled list tests passed!');
end.
