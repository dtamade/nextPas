program test_lockfree_hashtable;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.lockfree.hashtable;

type
  TIntHashTable = specialize TLockFreeHashTableImpl<Integer, Integer>;

var
  GTests, GPassed: Integer;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

procedure TestBasicInsertFind;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestBasicInsertFind ---');
  HT := TIntHashTable.Create;
  try
    Check(HT.IsEmpty, 'empty initially');
    Check(HT.Insert(1, 100) = htOk, 'insert 1');
    Check(not HT.IsEmpty, 'not empty');
    Check(HT.ApproxCount = 1, 'count = 1');
    Check(HT.Find(1, LVal) = htOk, 'find 1');
    Check(LVal = 100, 'value = 100');
    Check(HT.Find(999, LVal) = htNotFound, 'find missing');
  finally
    HT.Free;
  end;
end;

procedure TestInsertOverwrite;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestInsertOverwrite ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    Check(HT.Insert(1, 200) = htExists, 'duplicate key');
    Check(HT.Find(1, LVal) = htOk, 'find');
    Check(LVal = 100, 'original value preserved');
  finally
    HT.Free;
  end;
end;

procedure TestRemove;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestRemove ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Insert(2, 200);
    Check(HT.Remove(1) = htOk, 'remove 1');
    Check(HT.Find(1, LVal) = htNotFound, 'find removed');
    Check(HT.Find(2, LVal) = htOk, 'find 2 still exists');
    Check(LVal = 200, 'value = 200');
    Check(HT.Remove(999) = htNotFound, 'remove missing');
  finally
    HT.Free;
  end;
end;

procedure TestContains;
var
  HT: TIntHashTable;
begin
  WriteLn('--- TestContains ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(42, 1);
    Check(HT.Contains(42), 'contains 42');
    Check(not HT.Contains(99), 'not contains 99');
    HT.Remove(42);
    Check(not HT.Contains(42), 'not contains after remove');
  finally
    HT.Free;
  end;
end;

procedure TestManyInserts;
var
  HT: TIntHashTable;
  LVal, I, LN: Integer;
begin
  WriteLn('--- TestManyInserts ---');
  LN := 1000;
  HT := TIntHashTable.Create(16);
  try
    for I := 1 to LN do
      Check(HT.Insert(I, I * 10) = htOk, 'insert ' + IntToStr(I));
    Check(HT.ApproxCount = LN, 'count = ' + IntToStr(LN));
    for I := 1 to LN do
    begin
      Check(HT.Find(I, LVal) = htOk, 'find ' + IntToStr(I));
      Check(LVal = I * 10, 'value');
    end;
  finally
    HT.Free;
  end;
end;

procedure TestInsertRemoveInsert;
var
  HT: TIntHashTable;
  LVal: Integer;
begin
  WriteLn('--- TestInsertRemoveInsert ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Remove(1);
    Check(HT.Insert(1, 200) = htOk, 're-insert');
    Check(HT.Find(1, LVal) = htOk, 'find re-inserted');
    Check(LVal = 200, 'new value');
  finally
    HT.Free;
  end;
end;

procedure TestClose;
var
  HT: TIntHashTable;
begin
  WriteLn('--- TestClose ---');
  HT := TIntHashTable.Create;
  try
    HT.Insert(1, 100);
    HT.Close;
    Check(HT.IsClosed, 'is closed');
    Check(HT.Insert(2, 200) = htClosed, 'insert after close');
    Check(HT.Contains(1), 'can still read');
  finally
    HT.Free;
  end;
end;

procedure TestGrow;
var
  HT: TIntHashTable;
  LVal, I: Integer;
begin
  WriteLn('--- TestGrow ---');
  HT := TIntHashTable.Create(8);  // Small initial capacity
  try
    for I := 1 to 100 do
      HT.Insert(I, I);
    for I := 1 to 100 do
    begin
      Check(HT.Find(I, LVal) = htOk, 'find after grow');
      Check(LVal = I, 'value after grow');
    end;
  finally
    HT.Free;
  end;
end;

procedure TestStrings;
var
  HT: specialize TLockFreeHashTableImpl<string, Integer>;
  LVal: Integer;
begin
  WriteLn('--- TestStrings ---');
  HT := specialize TLockFreeHashTableImpl<string, Integer>.Create;
  try
    Check(HT.Insert('hello', 1) = htOk, 'insert hello');
    Check(HT.Insert('world', 2) = htOk, 'insert world');
    Check((HT.Find('hello', LVal) = htOk) and (LVal = 1), 'find hello');
    Check((HT.Find('world', LVal) = htOk) and (LVal = 2), 'find world');
  finally
    HT.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicInsertFind;
  TestInsertOverwrite;
  TestRemove;
  TestContains;
  TestManyInserts;
  TestInsertRemoveInsert;
  TestClose;
  TestGrow;
  TestStrings;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
