program test_lockfree_skiplist;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.skiplist;

type
  TIntIntSkipList = specialize TConcurrentSkipList<Integer, Integer>;

var
  T: TTestSuite;

{ ============================================================ }
{ TEST 1: Basic Insert and Find                                 }
{ ============================================================ }

procedure TestSkipListBasic;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
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

procedure TestSkipListUpdate;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 3: Remove                                                }
{ ============================================================ }

procedure TestSkipListRemove;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    LS.Insert(3, 30);

    Check(LS.Remove(2), 'remove key 2');
    Check(not LS.Find(2, LV), 'key 2 not found after remove');
    CheckEqual(2, LS.Count, 'count after remove');
    Check(LS.Find(1, LV), 'key 1 still exists');
    Check(LS.Find(3, LV), 'key 3 still exists');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 4: Contains                                              }
{ ============================================================ }

procedure TestSkipListContains;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 5: Count                                                 }
{ ============================================================ }

procedure TestSkipListCount;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
  try
    CheckEqual(0, LS.Count, 'initial count');
    LS.Insert(1, 10);
    CheckEqual(1, LS.Count, 'count after insert 1');
    LS.Insert(2, 20);
    CheckEqual(2, LS.Count, 'count after insert 2');
    LS.Insert(3, 30);
    CheckEqual(3, LS.Count, 'count after insert 3');
    LS.Remove(2);
    CheckEqual(2, LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 6: ForEach                                               }
{ ============================================================ }

var
  GForEachKeys: array[0..2] of Integer;
  GForEachValues: array[0..2] of Integer;
  GForEachIdx: Integer;

procedure ForEachCallback(const AKey: Integer; const AValue: Integer);
begin
  GForEachKeys[GForEachIdx] := AKey;
  GForEachValues[GForEachIdx] := AValue;
  Inc(GForEachIdx);
end;

procedure TestSkipListForEach;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
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

{ ============================================================ }
{ TEST 7: ForEachRange                                          }
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

procedure TestSkipListForEachRange;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 8: Clear                                                 }
{ ============================================================ }

procedure TestSkipListClear;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 9: Many keys stress                                      }
{ ============================================================ }

procedure TestSkipListManyKeys;
const
  KEY_COUNT = 1000;
var
  LS: TIntIntSkipList;
  LI: Integer;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
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

    { Remove all keys }
    for LI := 1 to KEY_COUNT do
      Check(LS.Remove(LI), 'remove succeeds');
    CheckEqual(0, LS.Count, 'count after remove all');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 10: Empty operations                                     }
{ ============================================================ }

procedure TestSkipListEmpty;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    CheckEqual(0, LS.Count, 'empty count');
    Check(not LS.Find(1, LV), 'find in empty');
    Check(not LS.Contains(1), 'contains in empty');
    Check(not LS.Remove(1), 'remove from empty');
  finally
    LS.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.lockfree.skiplist');
  T.Test('Basic insert and find', @TestSkipListBasic);
  T.Test('Update existing key', @TestSkipListUpdate);
  T.Test('Remove', @TestSkipListRemove);
  T.Test('Contains', @TestSkipListContains);
  T.Test('Count', @TestSkipListCount);
  T.Test('ForEach', @TestSkipListForEach);
  T.Test('ForEachRange', @TestSkipListForEachRange);
  T.Test('Clear', @TestSkipListClear);
  T.Test('Many keys stress', @TestSkipListManyKeys);
  T.Test('Empty operations', @TestSkipListEmpty);
  if not T.Run then Halt(1);
end.
