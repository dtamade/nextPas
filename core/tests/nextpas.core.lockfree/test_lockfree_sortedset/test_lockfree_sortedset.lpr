program test_lockfree_sortedset;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.sortedset;

type
  TIntSortedSet = specialize TConcurrentSortedSetImpl<Integer>;

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

procedure TestBasicInsertContains;
var
  SS: TIntSortedSet;
begin
  WriteLn('--- TestBasicInsertContains ---');
  SS := TIntSortedSet.Create;
  try
    Check(SS.IsEmpty, 'empty initially');
    Check(SS.Insert(42) = ssetOk, 'insert 42');
    Check(not SS.IsEmpty, 'not empty');
    Check(SS.Count = 1, 'count = 1');
    Check(SS.Contains(42), 'contains 42');
    Check(not SS.Contains(99), 'not contains 99');
  finally
    SS.Free;
  end;
end;

procedure TestDuplicateInsert;
var
  SS: TIntSortedSet;
begin
  WriteLn('--- TestDuplicateInsert ---');
  SS := TIntSortedSet.Create;
  try
    SS.Insert(42);
    Check(SS.Insert(42) = ssetExists, 'duplicate returns exists');
    Check(SS.Count = 1, 'count still 1');
  finally
    SS.Free;
  end;
end;

procedure TestRemove;
var
  SS: TIntSortedSet;
begin
  WriteLn('--- TestRemove ---');
  SS := TIntSortedSet.Create;
  try
    SS.Insert(1);
    SS.Insert(2);
    SS.Insert(3);
    Check(SS.Remove(2) = ssetOk, 'remove 2');
    Check(not SS.Contains(2), 'not contains 2');
    Check(SS.Contains(1), 'contains 1');
    Check(SS.Contains(3), 'contains 3');
    Check(SS.Count = 2, 'count = 2');
    Check(SS.Remove(99) = ssetNotFound, 'remove missing');
  finally
    SS.Free;
  end;
end;

procedure TestInsertRemoveInsert;
var
  SS: TIntSortedSet;
begin
  WriteLn('--- TestInsertRemoveInsert ---');
  SS := TIntSortedSet.Create;
  try
    SS.Insert(42);
    SS.Remove(42);
    Check(SS.Insert(42) = ssetOk, 're-insert');
    Check(SS.Contains(42), 'contains after re-insert');
    Check(SS.Count = 1, 'count = 1');
  finally
    SS.Free;
  end;
end;

procedure TestManyInserts;
var
  SS: TIntSortedSet;
  I, LN: Integer;
begin
  WriteLn('--- TestManyInserts ---');
  LN := 1000;
  SS := TIntSortedSet.Create;
  try
    for I := 1 to LN do
      Check(SS.Insert(I) = ssetOk, 'insert ' + IntToStr(I));
    Check(SS.Count = LN, 'count = ' + IntToStr(LN));
    for I := 1 to LN do
      Check(SS.Contains(I), 'contains ' + IntToStr(I));
  finally
    SS.Free;
  end;
end;

procedure TestStrings;
var
  SS: specialize TConcurrentSortedSetImpl<string>;
begin
  WriteLn('--- TestStrings ---');
  SS := specialize TConcurrentSortedSetImpl<string>.Create;
  try
    Check(SS.Insert('banana') = ssetOk, 'insert banana');
    Check(SS.Insert('apple') = ssetOk, 'insert apple');
    Check(SS.Insert('cherry') = ssetOk, 'insert cherry');
    Check(SS.Count = 3, 'count = 3');
    Check(SS.Contains('apple'), 'contains apple');
    Check(SS.Contains('banana'), 'contains banana');
    Check(SS.Contains('cherry'), 'contains cherry');
  finally
    SS.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicInsertContains;
  TestDuplicateInsert;
  TestRemove;
  TestInsertRemoveInsert;
  TestManyInserts;
  TestStrings;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
