program test_lockfree_robinhood;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.robinhood,
  nextpas.core.test;

procedure TestBasicInsertLookup;
var
  LMap: TRobinHoodMap;
  LValue: UInt64;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    Check(not LMap.IsClosed, 'Should not be closed');
    CheckEqual(Int32(0), LMap.GetCount, 'Empty map');

    Check(LMap.Insert(1, 100) = rhOk, 'Should insert');
    CheckEqual(Int32(1), LMap.GetCount, 'Count after insert');

    Check(LMap.Lookup(1, LValue) = rhOk, 'Should lookup');
    CheckEqual(UInt64(100), LValue, 'Lookup value');
  finally
    LMap.Free;
  end;
end;

procedure TestUpdate;
var
  LMap: TRobinHoodMap;
  LValue: UInt64;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    LMap.Insert(1, 100);
    Check(LMap.Insert(1, 200) = rhExists, 'Should report exists on update');
    Check(LMap.Lookup(1, LValue) = rhOk, 'Should lookup updated');
    CheckEqual(UInt64(200), LValue, 'Updated value');
    CheckEqual(Int32(1), LMap.GetCount, 'Count still 1');
  finally
    LMap.Free;
  end;
end;

procedure TestDelete;
var
  LMap: TRobinHoodMap;
  LValue: UInt64;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);

    Check(LMap.Delete(1) = rhOk, 'Should delete');
    Check(LMap.Lookup(1, LValue) = rhNotFound, 'Deleted key not found');
    Check(LMap.Lookup(2, LValue) = rhOk, 'Other key still exists');
    CheckEqual(UInt64(200), LValue, 'Other key value');
    CheckEqual(Int32(1), LMap.GetCount, 'Count after delete');

    Check(LMap.Delete(99) = rhNotFound, 'Delete non-existent');
  finally
    LMap.Free;
  end;
end;

procedure TestManyInserts;
var
  LMap: TRobinHoodMap;
  LValue: UInt64;
  I: Integer;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    for I := 1 to 100 do
      Check(LMap.Insert(UInt64(I), UInt64(I * 10)) = rhOk, 'Insert');

    CheckEqual(Int32(100), LMap.GetCount, '100 entries');

    for I := 1 to 100 do
    begin
      Check(LMap.Lookup(UInt64(I), LValue) = rhOk, 'Lookup');
      CheckEqual(UInt64(I * 10), LValue, 'Value correct');
    end;
  finally
    LMap.Free;
  end;
end;

procedure TestClose;
var
  LMap: TRobinHoodMap;
  LValue: UInt64;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    LMap.Insert(1, 100);
    LMap.Close;
    Check(LMap.IsClosed, 'Should be closed');

    Check(LMap.Lookup(1, LValue) = rhClosed, 'Lookup on closed');
    Check(LMap.Insert(2, 200) = rhClosed, 'Insert on closed');
    Check(LMap.Delete(1) = rhClosed, 'Delete on closed');
  finally
    LMap.Free;
  end;
end;

procedure TestClear;
var
  LMap: TRobinHoodMap;
begin
  LMap := TRobinHoodMap.Create(16);
  try
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);
    CheckEqual(Int32(2), LMap.GetCount, 'Before clear');

    LMap.Clear;
    CheckEqual(Int32(0), LMap.GetCount, 'After clear');
  finally
    LMap.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_robinhood ===');
  WriteLn;

  TestBasicInsertLookup;
  WriteLn('  + Basic insert/lookup');

  TestUpdate;
  WriteLn('  + Update existing key');

  TestDelete;
  WriteLn('  + Delete');

  TestManyInserts;
  WriteLn('  + Many inserts (auto-resize)');

  TestClose;
  WriteLn('  + Close semantics');

  TestClear;
  WriteLn('  + Clear');

  WriteLn;
  WriteLn('All Robin Hood hash map tests passed!');
end.
