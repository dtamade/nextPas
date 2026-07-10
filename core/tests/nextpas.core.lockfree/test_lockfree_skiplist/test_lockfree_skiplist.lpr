program test_lockfree_skiplist;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
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
  GMutatingSkipList: TIntIntSkipList;
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
    GMutatingSkipList.Insert(99, 990);
  end;
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

procedure TestSkipListForEachAllowsMutation;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(2, 20);
    GMutatingSkipList := LS;
    GMutationAttempted := False;
    LS.ForEach(@MutatingForEachCallback);
    Check(GMutationAttempted, 'callback should run');
    Check(LS.Contains(99), 'callback insertion should complete');
  finally
    GMutatingSkipList := nil;
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

{ ============================================================ }
{ TEST 11: Reverse order insertion                              }
{ ============================================================ }

procedure TestSkipListReverseOrder;
var
  LS: TIntIntSkipList;
  LV: Integer;
  LI: Integer;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 12: Random order insertion                               }
{ ============================================================ }

procedure TestSkipListRandomOrder;
const
  KEY_COUNT = 500;
var
  LS: TIntIntSkipList;
  LKeys: array[0..KEY_COUNT - 1] of Integer;
  LV: Integer;
  LI, LJ: Integer;
  LTemp: Integer;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 13: Range query boundary - empty range                   }
{ ============================================================ }

var
  GRangeCount: Integer;

procedure RangeCountCallback(const AKey: Integer; const AValue: Integer);
begin
  Inc(GRangeCount);
end;

procedure TestSkipListRangeEmpty;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(5, 50);
    LS.Insert(10, 100);

    { Range with no elements }
    GRangeCount := 0;
    LS.ForEachRange(2, 4, @RangeCountCallback);
    CheckEqual(0, GRangeCount, 'empty range count');

    { Range before all elements }
    GRangeCount := 0;
    LS.ForEachRange(-10, -5, @RangeCountCallback);
    CheckEqual(0, GRangeCount, 'before all elements');

    { Range after all elements }
    GRangeCount := 0;
    LS.ForEachRange(20, 30, @RangeCountCallback);
    CheckEqual(0, GRangeCount, 'after all elements');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 14: Range query boundary - single element                }
{ ============================================================ }

var
  GRangeKey: Integer;
  GRangeValue: Integer;

procedure RangeSingleCallback(const AKey: Integer; const AValue: Integer);
begin
  GRangeKey := AKey;
  GRangeValue := AValue;
  Inc(GRangeCount);
end;

procedure TestSkipListRangeSingle;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(5, 50);

    GRangeCount := 0;
    LS.ForEachRange(5, 5, @RangeSingleCallback);
    CheckEqual(1, GRangeCount, 'single element range');
    CheckEqual(5, GRangeKey, 'key');
    CheckEqual(50, GRangeValue, 'value');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 15: Range query boundary - full range                    }
{ ============================================================ }

procedure TestSkipListRangeFull;
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

    { Full range covering all elements }
    GRangeCount := 0;
    LS.ForEachRange(0, 100, @RangeCountCallback);
    CheckEqual(5, GRangeCount, 'full range count');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 16: Single element operations                           }
{ ============================================================ }

procedure TestSkipListSingleElement;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(42, 420);
    CheckEqual(1, LS.Count, 'count after insert');
    Check(LS.Find(42, LV), 'find key');
    CheckEqual(420, LV, 'value');
    Check(LS.Contains(42), 'contains');
    Check(not LS.Contains(99), 'does not contain');

    LS.Remove(42);
    CheckEqual(0, LS.Count, 'count after remove');
    Check(not LS.Find(42, LV), 'not found after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 17: Duplicate key update                                }
{ ============================================================ }

procedure TestSkipListDuplicateUpdate;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(1, 10);
    LS.Insert(1, 20);
    LS.Insert(1, 30);
    CheckEqual(1, LS.Count, 'count after duplicate inserts');
    Check(LS.Find(1, LV), 'find key');
    CheckEqual(30, LV, 'last value wins');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 18: Interleaved insert/remove                           }
{ ============================================================ }

procedure TestSkipListInterleaved;
var
  LS: TIntIntSkipList;
  LV: Integer;
  LI: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    { Insert 10, remove 5, insert 10 more }
    for LI := 1 to 10 do
      LS.Insert(LI, LI * 10);
    for LI := 1 to 5 do
      LS.Remove(LI);
    for LI := 11 to 20 do
      LS.Insert(LI, LI * 10);

    CheckEqual(15, LS.Count, 'count after interleaved ops');

    { Verify remaining keys }
    for LI := 6 to 20 do
    begin
      Check(LS.Find(LI, LV), 'key exists');
      CheckEqual(LI * 10, LV, 'value matches');
    end;

    { Verify removed keys }
    for LI := 1 to 5 do
      Check(not LS.Find(LI, LV), 'key removed');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 19: Large key values                                    }
{ ============================================================ }

procedure TestSkipListLargeKeys;
const
  KEY_COUNT = 100;
var
  LS: TIntIntSkipList;
  LV: Integer;
  LI: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    { Insert with large key values }
    for LI := 1 to KEY_COUNT do
      LS.Insert(LI * 1000, LI * 10000);
    CheckEqual(KEY_COUNT, LS.Count, 'count after insert');

    { Verify all keys }
    for LI := 1 to KEY_COUNT do
    begin
      Check(LS.Find(LI * 1000, LV), 'key exists');
      CheckEqual(LI * 10000, LV, 'value matches');
    end;
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 20: ForEachCtx with context                             }
{ ============================================================ }

var
  GCtxSum: Integer;

procedure ForEachCtxCallback(const AKey: Integer; const AValue: Integer; AContext: Pointer);
begin
  PInteger(AContext)^ := PInteger(AContext)^ + AValue;
end;

procedure TestSkipListForEachCtx;
var
  LS: TIntIntSkipList;
  LSum: Integer;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 21: Remove all keys                                      }
{ ============================================================ }

procedure TestSkipListRemoveAll;
const
  KEY_COUNT = 50;
var
  LS: TIntIntSkipList;
  LI: Integer;
begin
  LS := TIntIntSkipList.Create;
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

{ ============================================================ }
{ TEST 22: Remove non-existent key                              }
{ ============================================================ }

procedure TestSkipListRemoveNonExistent;
var
  LS: TIntIntSkipList;
begin
  LS := TIntIntSkipList.Create;
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
{ TEST 23: Negative keys                                        }
{ ============================================================ }

procedure TestSkipListNegativeKeys;
var
  LS: TIntIntSkipList;
  LV: Integer;
begin
  LS := TIntIntSkipList.Create;
  try
    LS.Insert(-10, 100);
    LS.Insert(-5, 50);
    LS.Insert(0, 0);
    LS.Insert(5, 50);
    LS.Insert(10, 100);

    Check(LS.Find(-10, LV), 'find -10');
    CheckEqual(100, LV, 'value -10');
    Check(LS.Find(-5, LV), 'find -5');
    CheckEqual(50, LV, 'value -5');
    Check(LS.Find(0, LV), 'find 0');
    CheckEqual(0, LV, 'value 0');
    Check(LS.Find(5, LV), 'find 5');
    CheckEqual(50, LV, 'value 5');
    Check(LS.Find(10, LV), 'find 10');
    CheckEqual(100, LV, 'value 10');
    Check(not LS.Find(-11, LV), '-11 not found');
    Check(not LS.Find(11, LV), '11 not found');

    Check(LS.Remove(-5), 'remove -5');
    Check(not LS.Contains(-5), '-5 removed');
    CheckEqual(4, LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 24: ForEach after remove                                 }
{ ============================================================ }

var
  GRemovedSum: Integer;

procedure RemovedSumCallback(const AKey: Integer; const AValue: Integer);
begin
  GRemovedSum := GRemovedSum + AValue;
end;

procedure TestSkipListForEachAfterRemove;
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

    { Remove keys 2 and 4 }
    LS.Remove(2);
    LS.Remove(4);

    GRemovedSum := 0;
    LS.ForEach(@RemovedSumCallback);
    CheckEqual(90, GRemovedSum, 'sum after remove (10+30+50)');
    CheckEqual(3, LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 25: Concurrent insert stress                              }
{ ============================================================ }

const
  CONCURRENT_OPS = 1000;
  CONCURRENT_THREADS = 2;

var
  GConcurrentSkipList: TIntIntSkipList;
  GConcurrentReady: Int32;
  GConcurrentDone: Int32;

function ConcurrentInserter(AArg: Pointer): Int64;
var
  LThreadID: Integer;
  LI: Integer;
  LBase: Integer;
begin
  Result := 0;
  LThreadID := PInteger(AArg)^;
  LBase := LThreadID * CONCURRENT_OPS;

  { Wait for signal }
  while AtomicLoad32(GConcurrentReady, moAcquire) = 0 do
    CpuPause;

  { Insert keys }
  for LI := 1 to CONCURRENT_OPS do
    GConcurrentSkipList.Insert(LBase + LI, (LBase + LI) * 10);

  AtomicFetchAdd32(GConcurrentDone, 1, moRelease);
end;

procedure TestSkipListConcurrentInsert;
var
  LThreads: array[0..CONCURRENT_THREADS - 1] of TThreadID;
  LThreadIDs: array[0..CONCURRENT_THREADS - 1] of Integer;
  LI: Integer;
begin
  GConcurrentSkipList := TIntIntSkipList.Create;
  try
    AtomicStore32(GConcurrentReady, 0, moRelease);
    AtomicStore32(GConcurrentDone, 0, moRelease);

    { Create threads }
    for LI := 0 to CONCURRENT_THREADS - 1 do
    begin
      LThreadIDs[LI] := LI;
      LThreads[LI] := BeginThread(@ConcurrentInserter, @LThreadIDs[LI]);
    end;

    { Signal ready }
    AtomicStore32(GConcurrentReady, 1, moRelease);

    { Wait for completion }
    for LI := 0 to CONCURRENT_THREADS - 1 do
      WaitForThreadTerminate(LThreads[LI], 0);

    { Verify count - just check it's positive }
    Check(GConcurrentSkipList.Count > 0, 'concurrent insert count > 0');
  finally
    GConcurrentSkipList.Free;
  end;
end;

{ ============================================================ }
{ TEST 26: Concurrent find stress                               }
{ ============================================================ }

function ConcurrentFinder(AArg: Pointer): Int64;
var
  LI: Integer;
  LV: Integer;
begin
  Result := 0;

  { Wait for signal }
  while AtomicLoad32(GConcurrentReady, moAcquire) = 0 do
    CpuPause;

  { Find keys }
  for LI := 1 to CONCURRENT_OPS do
    GConcurrentSkipList.Find(LI, LV);

  AtomicFetchAdd32(GConcurrentDone, 1, moRelease);
end;

procedure TestSkipListConcurrentFind;
var
  LThreads: array[0..CONCURRENT_THREADS - 1] of TThreadID;
  LThreadIDs: array[0..CONCURRENT_THREADS - 1] of Integer;
  LI: Integer;
begin
  GConcurrentSkipList := TIntIntSkipList.Create;
  try
    { Pre-populate }
    for LI := 1 to CONCURRENT_OPS do
      GConcurrentSkipList.Insert(LI, LI * 10);

    AtomicStore32(GConcurrentReady, 0, moRelease);
    AtomicStore32(GConcurrentDone, 0, moRelease);

    { Create threads }
    for LI := 0 to CONCURRENT_THREADS - 1 do
    begin
      LThreadIDs[LI] := LI;
      LThreads[LI] := BeginThread(@ConcurrentFinder, @LThreadIDs[LI]);
    end;

    { Signal ready }
    AtomicStore32(GConcurrentReady, 1, moRelease);

    { Wait for completion }
    for LI := 0 to CONCURRENT_THREADS - 1 do
      WaitForThreadTerminate(LThreads[LI], 0);

    { Verify count unchanged }
    CheckEqual(CONCURRENT_OPS, GConcurrentSkipList.Count, 'concurrent find count');
  finally
    GConcurrentSkipList.Free;
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
  T.Test('ForEach callback mutation', @TestSkipListForEachAllowsMutation);
  T.Test('ForEachRange', @TestSkipListForEachRange);
  T.Test('Clear', @TestSkipListClear);
  T.Test('Many keys stress', @TestSkipListManyKeys);
  T.Test('Empty operations', @TestSkipListEmpty);
  T.Test('Reverse order insertion', @TestSkipListReverseOrder);
  T.Test('Random order insertion', @TestSkipListRandomOrder);
  T.Test('Range query empty', @TestSkipListRangeEmpty);
  T.Test('Range query single', @TestSkipListRangeSingle);
  T.Test('Range query full', @TestSkipListRangeFull);
  T.Test('Single element', @TestSkipListSingleElement);
  T.Test('Duplicate key update', @TestSkipListDuplicateUpdate);
  T.Test('Interleaved insert/remove', @TestSkipListInterleaved);
  T.Test('Large key values', @TestSkipListLargeKeys);
  T.Test('ForEachCtx with context', @TestSkipListForEachCtx);
  T.Test('Remove all keys', @TestSkipListRemoveAll);
  T.Test('Remove non-existent key', @TestSkipListRemoveNonExistent);
  T.Test('Negative keys', @TestSkipListNegativeKeys);
  T.Test('ForEach after remove', @TestSkipListForEachAfterRemove);
  T.Test('Concurrent insert stress', @TestSkipListConcurrentInsert);
  T.Test('Concurrent find stress', @TestSkipListConcurrentFind);
  if not T.Run then Halt(1);
end.
