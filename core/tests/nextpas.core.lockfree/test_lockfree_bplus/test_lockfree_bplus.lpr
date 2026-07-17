program test_lockfree_bplus;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.bplus,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GSum: Int64;
  GKeys: array of Int64;
  GIdx: Integer;
  GMutatingTree: TConcurrentBPlusTree;
  GMutationAttempted: Boolean;

procedure SumCallback(AKey, AValue: Int64);
begin
  GSum := GSum + AValue;
end;

procedure RangeCallback(AKey, AValue: Int64; var AContinue: Boolean);
begin
  GKeys[GIdx] := AKey;
  Inc(GIdx);
end;

procedure MutatingCallback(AKey, AValue: Int64);
begin
  if not GMutationAttempted then
  begin
    GMutationAttempted := True;
    GMutatingTree.Insert(99, 990);
  end;
end;

procedure TestBplusBasic;
var
  LTree: TConcurrentBPlusTree;
  LValue: Int64;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    CheckEqual(Ord(bpInserted), Ord(LTree.Insert(5, 500)));
    CheckEqual(Ord(bpInserted), Ord(LTree.Insert(3, 300)));
    CheckEqual(Ord(bpInserted), Ord(LTree.Insert(7, 700)));

    Check(LTree.Find(5, LValue), 'Should find key 5');
    CheckEqual(Int64(500), LValue);

    Check(LTree.Find(3, LValue), 'Should find key 3');
    CheckEqual(Int64(300), LValue);

    Check(LTree.Find(7, LValue), 'Should find key 7');
    CheckEqual(Int64(700), LValue);

    Check(not LTree.Find(99, LValue), 'Should not find key 99');
  finally
    LTree.Free;
  end;
end;

procedure TestBplusUpdate;
var
  LTree: TConcurrentBPlusTree;
  LValue: Int64;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(1, 100);
    CheckEqual(Ord(bpUpdated), Ord(LTree.Insert(1, 999)));

    Check(LTree.Find(1, LValue), 'Should find key 1');
    CheckEqual(Int64(999), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestBplusRemove;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Insert(2, 200);
    LTree.Insert(3, 300);

    CheckEqual(Ord(bpRemoved), Ord(LTree.Remove(2)));
    Check(not LTree.Contains(2), 'Key 2 should be removed');
    Check(LTree.Contains(1), 'Key 1 should still exist');
    Check(LTree.Contains(3), 'Key 3 should still exist');

    CheckEqual(Ord(bpNotFound), Ord(LTree.Remove(99)));
  finally
    LTree.Free;
  end;
end;

procedure TestBplusCount;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    CheckEqual(Int64(0), LTree.GetCount);
    LTree.Insert(1, 100);
    CheckEqual(Int64(1), LTree.GetCount);
    LTree.Insert(2, 200);
    CheckEqual(Int64(2), LTree.GetCount);
    LTree.Remove(1);
    CheckEqual(Int64(1), LTree.GetCount);
  finally
    LTree.Free;
  end;
end;

procedure TestBplusForEach;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(3, 300);
    LTree.Insert(1, 100);
    LTree.Insert(2, 200);

    GSum := 0;
    LTree.ForEach(@SumCallback);
    CheckEqual(Int64(600), GSum);
  finally
    LTree.Free;
  end;
end;

procedure TestBplusForEachAllowsMutation;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(1, 10);
    LTree.Insert(2, 20);
    GMutatingTree := LTree;
    GMutationAttempted := False;

    LTree.ForEach(@MutatingCallback);

    Check(GMutationAttempted, 'Callback should run');
    Check(LTree.Contains(99), 'Callback insertion should complete');
    CheckEqual(Int64(3), LTree.GetCount);
  finally
    GMutatingTree := nil;
    LTree.Free;
  end;
end;

procedure TestBplusRangeQuery;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(1, 10);
    LTree.Insert(2, 20);
    LTree.Insert(3, 30);
    LTree.Insert(4, 40);
    LTree.Insert(5, 50);

    SetLength(GKeys, 5);
    GIdx := 0;
    LTree.RangeQuery(2, 4, @RangeCallback);

    CheckEqual(3, GIdx);
    CheckEqual(Int64(2), GKeys[0]);
    CheckEqual(Int64(3), GKeys[1]);
    CheckEqual(Int64(4), GKeys[2]);
  finally
    LTree.Free;
  end;
end;

procedure TestBplusClose;
var
  LTree: TConcurrentBPlusTree;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Close;
    Check(LTree.IsClosed, 'Should be closed');
    CheckEqual(Ord(bpClosed), Ord(LTree.Insert(2, 200)));
    CheckEqual(Ord(bpClosed), Ord(LTree.Remove(1)));
  finally
    LTree.Free;
  end;
end;

procedure TestBplusLargeInsert;
var
  LTree: TConcurrentBPlusTree;
  LI: Integer;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    for LI := 1 to 100 do
      CheckEqual(Ord(bpInserted), Ord(LTree.Insert(LI, LI * 10)));

    CheckEqual(Int64(100), LTree.GetCount);

    for LI := 1 to 100 do
      Check(LTree.Contains(LI), 'Should contain all keys');
  finally
    LTree.Free;
  end;
end;

procedure TestBplusMultiLevelInsert;
const
  KEY_COUNT = 5000;
var
  LTree: TConcurrentBPlusTree;
  LValue: Int64;
  LI: Integer;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    for LI := 1 to KEY_COUNT do
      CheckEqual(Ord(bpInserted), Ord(LTree.Insert(LI, LI * 10)));

    CheckEqual(Int64(KEY_COUNT), LTree.GetCount);
    for LI := 1 to KEY_COUNT do
    begin
      Check(LTree.Find(LI, LValue), 'Multi-level tree should find every key');
      CheckEqual(Int64(LI * 10), LValue);
    end;
  finally
    LTree.Free;
  end;
end;

procedure TestBplusRemoveMaintainsFill;
const
  KEY_COUNT = 5000;
  REMOVE_COUNT = 4500;
var
  LTree: TConcurrentBPlusTree;
  LValue: Int64;
  LI: Integer;
begin
  LTree := TConcurrentBPlusTree.Create;
  try
    for LI := 1 to KEY_COUNT do
      LTree.Insert(LI, LI * 10);
    Check(LTree.ValidateInvariants, 'Inserted B+ tree should satisfy invariants');

    for LI := 1 to REMOVE_COUNT do
      CheckEqual(Ord(bpRemoved), Ord(LTree.Remove(LI)));

    CheckEqual(Int64(KEY_COUNT - REMOVE_COUNT), LTree.GetCount);
    Check(LTree.ValidateInvariants, 'Deletion should preserve B+ fill and separators');
    for LI := REMOVE_COUNT + 1 to KEY_COUNT do
    begin
      Check(LTree.Find(LI, LValue), 'Remaining key should be found');
      CheckEqual(Int64(LI * 10), LValue);
    end;
  finally
    LTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_bplus ===');
  WriteLn;

  TestBplusBasic;
  WriteLn('  + Basic operations');

  TestBplusUpdate;
  WriteLn('  + Update');

  TestBplusRemove;
  WriteLn('  + Remove');

  TestBplusCount;
  WriteLn('  + Count');

  TestBplusForEach;
  WriteLn('  + ForEach');

  TestBplusForEachAllowsMutation;
  WriteLn('  + ForEach callback mutation');

  TestBplusRangeQuery;
  WriteLn('  + Range query');

  TestBplusClose;
  WriteLn('  + Close semantics');

  TestBplusLargeInsert;
  WriteLn('  + Large insert');

  TestBplusMultiLevelInsert;
  WriteLn('  + Multi-level insert');

  TestBplusRemoveMaintainsFill;
  WriteLn('  + Remove maintains fill');

  WriteLn;
  WriteLn('All B+ tree tests passed!');
end.
