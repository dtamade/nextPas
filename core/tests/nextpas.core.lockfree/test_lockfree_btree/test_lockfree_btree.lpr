program test_lockfree_btree;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.btree;

type
  TIntIntBTree = specialize TConcurrentBTree<Integer, Integer>;

var
  T: TTestSuite;

{ ============================================================ }
{ TEST 1: Basic Insert and Find                                 }
{ ============================================================ }

procedure TestBTreeBasic;
var
  LS: TIntIntBTree;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);

    Check(LS.Find(1, LV), 'find key 1');
    CheckEqual(10, LV, 'value for key 1');
    Check(LS.Find(2, LV), 'find key 2');
    CheckEqual(20, LV, 'value for key 2');
    Check(LS.Find(3, LV), 'find key 3');
    CheckEqual(30, LV, 'value for key 3');
    Check(not LS.Find(4, LV), 'key 4 not found');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 2: Update existing key                                   }
{ ============================================================ }

procedure TestBTreeUpdate;
var
  LS: TIntIntBTree;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(1, 20);

    Check(LS.Find(1, LV), 'find key 1');
    CheckEqual(20, LV, 'value updated');
    CheckEqual(1, LS.Count, 'count after update');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 3: Contains                                              }
{ ============================================================ }

procedure TestBTreeContains;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);

    Check(LS.Contains(1), 'contains key 1');
    Check(LS.Contains(2), 'contains key 2');
    Check(not LS.Contains(3), 'does not contain key 3');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 4: Count                                                 }
{ ============================================================ }

procedure TestBTreeCount;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    CheckEqual(0, LS.Count, 'initial count');
    LS.Insert(1, 10);
    CheckEqual(1, LS.Count, 'count after insert 1');
    LS.Insert(2, 20);
    CheckEqual(2, LS.Count, 'count after insert 2');
    LS.Insert(3, 30);
    CheckEqual(3, LS.Count, 'count after insert 3');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 5: ForEach                                               }
{ ============================================================ }

var
  GForEachKeys: array[0..2] of Integer;
  GForEachValues: array[0..2] of Integer;
  GForEachIdx: Integer;
  GMutatingTree: TIntIntBTree;
  GMutationAttempted: Boolean;

procedure ForEachCallback(const AKey: Integer; const AValue: Integer);
begin
  GForEachKeys[GForEachIdx] := AKey;
  GForEachValues[GForEachIdx] := AValue;
  Inc(GForEachIdx);
end;

procedure MutatingForEachCallback(const AKey: Integer; const AValue: Integer);
begin
  if not GMutationAttempted then
  begin
    GMutationAttempted := True;
    GMutatingTree.Insert(99, 990);
  end;
end;

procedure TestBTreeForEach;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(3, 30);
    LS.Insert(1, 10);
    LS.Insert(2, 20);

    GForEachIdx := 0;
    LS.ForEach(@ForEachCallback);

    CheckEqual(3, GForEachIdx, 'forEach count');
    CheckEqual(1, GForEachKeys[0], 'key 0');
    CheckEqual(10, GForEachValues[0], 'value 0');
    CheckEqual(2, GForEachKeys[1], 'key 1');
    CheckEqual(20, GForEachValues[1], 'value 1');
    CheckEqual(3, GForEachKeys[2], 'key 2');
    CheckEqual(30, GForEachValues[2], 'value 2');
  finally
    LS.Free;
  end;
end;

procedure TestBTreeForEachAllowsMutation;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    GMutatingTree := LS;
    GMutationAttempted := False;

    LS.ForEach(@MutatingForEachCallback);

    Check(GMutationAttempted, 'callback should run');
    Check(LS.Contains(99), 'callback insertion should complete');
    CheckEqual(3, LS.Count, 'count after callback insertion');
  finally
    GMutatingTree := nil;
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 6: ForEachRange                                          }
{ ============================================================ }

var
  GRangeKeys: array[0..2] of Integer;
  GRangeValues: array[0..2] of Integer;
  GRangeIdx: Integer;

procedure RangeCallback(const AKey: Integer; const AValue: Integer);
begin
  GRangeKeys[GRangeIdx] := AKey;
  GRangeValues[GRangeIdx] := AValue;
  Inc(GRangeIdx);
end;

procedure TestBTreeForEachRange;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);
    LS.Insert(4, 40);
    LS.Insert(5, 50);

    GRangeIdx := 0;
    LS.ForEachRange(2, 4, @RangeCallback);

    CheckEqual(3, GRangeIdx, 'range count');
    CheckEqual(2, GRangeKeys[0], 'key 0');
    CheckEqual(20, GRangeValues[0], 'value 0');
    CheckEqual(3, GRangeKeys[1], 'key 1');
    CheckEqual(30, GRangeValues[1], 'value 1');
    CheckEqual(4, GRangeKeys[2], 'key 2');
    CheckEqual(40, GRangeValues[2], 'value 2');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 7: Clear                                                 }
{ ============================================================ }

procedure TestBTreeClear;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);
    CheckEqual(3, LS.Count, 'count before clear');

    LS.Clear;
    CheckEqual(0, LS.Count, 'count after clear');
    Check(not LS.Contains(1), 'key 1 not found after clear');
    Check(not LS.Contains(2), 'key 2 not found after clear');
    Check(not LS.Contains(3), 'key 3 not found after clear');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 8: Many keys stress                                      }
{ ============================================================ }

procedure TestBTreeManyKeys;
const
  KEY_COUNT = 1000;
var
  LS: TIntIntBTree;
  LI: Integer;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    { Insert many keys }
    for LI := 1 to KEY_COUNT do
      LS.Insert(LI, LI * 10);
    CheckEqual(KEY_COUNT, LS.Count, 'count after insert');

    { Verify all keys }
    for LI := 1 to KEY_COUNT do
    begin
      Check(LS.Find(LI, LV), 'key exists');
      CheckEqual(LI * 10, LV, 'value matches');
    end;
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 9: Empty operations                                      }
{ ============================================================ }

procedure TestBTreeEmpty;
var
  LS: TIntIntBTree;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    CheckEqual(0, LS.Count, 'empty count');
    Check(not LS.Find(1, LV), 'find in empty');
    Check(not LS.Contains(1), 'contains in empty');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 10: Reverse order insertion                              }
{ ============================================================ }

procedure TestBTreeReverseOrder;
var
  LS: TIntIntBTree;
  LV: Integer;
  LI: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    { Insert in reverse order }
    for LI := 100 downto 1 do
      LS.Insert(LI, LI * 10);
    CheckEqual(100, LS.Count, 'count after insert');

    { Verify all keys exist and are in order via ForEach }
    for LI := 1 to 100 do
    begin
      Check(LS.Find(LI, LV), 'key exists');
      CheckEqual(LI * 10, LV, 'value matches');
    end;
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 11: Random order insertion                               }
{ ============================================================ }

procedure TestBTreeRandomOrder;
const
  KEY_COUNT = 500;
var
  LS: TIntIntBTree;
  LKeys: array[0..KEY_COUNT - 1] of Integer;
  LV: Integer;
  LI, LJ: Integer;
  LTemp: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    { Create shuffled key array }
    for LI := 0 to KEY_COUNT - 1 do
      LKeys[LI] := LI + 1;
    { Simple Fisher-Yates shuffle }
    for LI := KEY_COUNT - 1 downto 1 do
    begin
      LJ := Random(LI + 1);
      LTemp := LKeys[LI];
      LKeys[LI] := LKeys[LJ];
      LKeys[LJ] := LTemp;
    end;

    { Insert in random order }
    for LI := 0 to KEY_COUNT - 1 do
      LS.Insert(LKeys[LI], LKeys[LI] * 10);
    CheckEqual(KEY_COUNT, LS.Count, 'count after insert');

    { Verify all keys }
    for LI := 1 to KEY_COUNT do
    begin
      Check(LS.Find(LI, LV), 'key exists');
      CheckEqual(LI * 10, LV, 'value matches');
    end;
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 12: ForEachCtx with context                              }
{ ============================================================ }

var
  GCtxSum: Integer;

procedure ForEachCtxCallback(const AKey: Integer; const AValue: Integer; AContext: Pointer);
begin
  PInteger(AContext)^ := PInteger(AContext)^ + AValue;
end;

procedure TestBTreeForEachCtx;
var
  LS: TIntIntBTree;
  LSum: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);

    LSum := 0;
    LS.ForEachCtx(@ForEachCtxCallback, @LSum);
    CheckEqual(60, LSum, 'sum of values');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 13: Remove basic                                         }
{ ============================================================ }

procedure TestBTreeRemoveBasic;
var
  LS: TIntIntBTree;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);
    CheckEqual(3, LS.Count, 'count before remove');

    Check(LS.Remove(2), 'remove key 2');
    CheckEqual(2, LS.Count, 'count after remove');
    Check(not LS.Contains(2), 'key 2 removed');
    Check(LS.Contains(1), 'key 1 still exists');
    Check(LS.Contains(3), 'key 3 still exists');
    Check(LS.Find(1, LV), 'find key 1');
    CheckEqual(10, LV, 'value 1');
    Check(LS.Find(3, LV), 'find key 3');
    CheckEqual(30, LV, 'value 3');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 14: Remove from many keys                                }
{ ============================================================ }

procedure TestBTreeRemoveMany;
const
  KEY_COUNT = 100;
var
  LS: TIntIntBTree;
  LI: Integer;
  LV: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    for LI := 1 to KEY_COUNT do
      LS.Insert(LI, LI * 10);
    CheckEqual(KEY_COUNT, LS.Count, 'count before remove');

    { Remove all even keys }
    for LI := 2 to KEY_COUNT do
    begin
      if LI mod 2 = 0 then
        Check(LS.Remove(LI), 'remove key ' + IntToStr(LI));
    end;
    CheckEqual(KEY_COUNT div 2, LS.Count, 'count after remove even');

    { Verify remaining keys }
    for LI := 1 to KEY_COUNT do
    begin
      if LI mod 2 = 1 then
      begin
        Check(LS.Find(LI, LV), 'odd key exists');
        CheckEqual(LI * 10, LV, 'value matches');
      end
      else
        Check(not LS.Contains(LI), 'even key removed');
    end;
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 15: Remove non-existent key                              }
{ ============================================================ }

procedure TestBTreeRemoveNonExistent;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);

    Check(not LS.Remove(3), 'remove non-existent key');
    CheckEqual(2, LS.Count, 'count unchanged');
    Check(not LS.Remove(0), 'remove key 0');
    Check(not LS.Remove(-1), 'remove key -1');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 16: Remove from empty tree                               }
{ ============================================================ }

procedure TestBTreeRemoveEmpty;
var
  LS: TIntIntBTree;
begin
  LS := TIntIntBTree.Create;
  try
    Check(not LS.Remove(1), 'remove from empty');
    CheckEqual(0, LS.Count, 'count still 0');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 17: Remove all keys                                      }
{ ============================================================ }

procedure TestBTreeRemoveAll;
const
  KEY_COUNT = 50;
var
  LS: TIntIntBTree;
  LI: Integer;
begin
  LS := TIntIntBTree.Create;
  try
    for LI := 1 to KEY_COUNT do
      LS.Insert(LI, LI * 10);
    CheckEqual(KEY_COUNT, LS.Count, 'count before remove all');

    for LI := 1 to KEY_COUNT do
      Check(LS.Remove(LI), 'remove key ' + IntToStr(LI));
    CheckEqual(0, LS.Count, 'count after remove all');
    Check(not LS.Contains(1), 'key 1 not found');
    Check(not LS.Contains(KEY_COUNT), 'last key not found');
  finally
    LS.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.lockfree.btree');
  T.Test('Basic insert and find', @TestBTreeBasic);
  T.Test('Update existing key', @TestBTreeUpdate);
  T.Test('Contains', @TestBTreeContains);
  T.Test('Count', @TestBTreeCount);
  T.Test('ForEach', @TestBTreeForEach);
  T.Test('ForEach callback mutation', @TestBTreeForEachAllowsMutation);
  T.Test('ForEachRange', @TestBTreeForEachRange);
  T.Test('Clear', @TestBTreeClear);
  T.Test('Many keys stress', @TestBTreeManyKeys);
  T.Test('Empty operations', @TestBTreeEmpty);
  T.Test('Reverse order insertion', @TestBTreeReverseOrder);
  T.Test('Random order insertion', @TestBTreeRandomOrder);
  T.Test('ForEachCtx with context', @TestBTreeForEachCtx);
  T.Test('Remove basic', @TestBTreeRemoveBasic);
  T.Test('Remove from many keys', @TestBTreeRemoveMany);
  T.Test('Remove non-existent key', @TestBTreeRemoveNonExistent);
  T.Test('Remove from empty tree', @TestBTreeRemoveEmpty);
  T.Test('Remove all keys', @TestBTreeRemoveAll);
  if not T.Run then Halt(1);
end.
