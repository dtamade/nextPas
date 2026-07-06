program test_lockfree_hashset;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.lockfree,
  nextpas.core.lockfree.hashset;

type
  TIntHashSet = specialize TConcurrentHashSet<Integer>;

var
  T: TTestSuite;

{ ============================================================ }
{ TEST 1: Basic insert and contains                             }
{ ============================================================ }

procedure TestHashSetBasic;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(1);
    LS.Insert(2);
    LS.Insert(3);

    Check(LS.Contains(1), 'contains 1');
    Check(LS.Contains(2), 'contains 2');
    Check(LS.Contains(3), 'contains 3');
    Check(not LS.Contains(4), 'does not contain 4');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 2: Remove                                                }
{ ============================================================ }

procedure TestHashSetRemove;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(1);
    LS.Insert(2);
    LS.Insert(3);

    Check(LS.Remove(2), 'remove 2');
    Check(not LS.Contains(2), 'does not contain 2');
    Check(LS.Contains(1), 'still contains 1');
    Check(LS.Contains(3), 'still contains 3');
    CheckEqual(PtrUInt(2), LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 3: Count                                                 }
{ ============================================================ }

procedure TestHashSetCount;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    CheckEqual(PtrUInt(0), LS.Count, 'initial count');
    LS.Insert(1);
    CheckEqual(PtrUInt(1), LS.Count, 'count after insert 1');
    LS.Insert(2);
    CheckEqual(PtrUInt(2), LS.Count, 'count after insert 2');
    LS.Insert(3);
    CheckEqual(PtrUInt(3), LS.Count, 'count after insert 3');
    LS.Remove(2);
    CheckEqual(PtrUInt(2), LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 4: Clear                                                 }
{ ============================================================ }

procedure TestHashSetClear;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(1);
    LS.Insert(2);
    LS.Insert(3);
    CheckEqual(PtrUInt(3), LS.Count, 'count before clear');

    LS.Clear;
    CheckEqual(PtrUInt(0), LS.Count, 'count after clear');
    Check(not LS.Contains(1), 'does not contain 1 after clear');
    Check(not LS.Contains(2), 'does not contain 2 after clear');
    Check(not LS.Contains(3), 'does not contain 3 after clear');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 5: Duplicate insert                                      }
{ ============================================================ }

procedure TestHashSetDuplicate;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(1);
    LS.Insert(1);
    LS.Insert(1);
    CheckEqual(PtrUInt(1), LS.Count, 'count after duplicate inserts');
    Check(LS.Contains(1), 'contains 1');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 6: Empty operations                                      }
{ ============================================================ }

procedure TestHashSetEmpty;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    CheckEqual(PtrUInt(0), LS.Count, 'empty count');
    Check(not LS.Contains(1), 'does not contain 1');
    Check(not LS.Remove(1), 'remove from empty');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 7: Many keys stress                                      }
{ ============================================================ }

procedure TestHashSetManyKeys;
const
  KEY_COUNT = 1000;
var
  LS: TIntHashSet;
  LI: Integer;
begin
  LS := TIntHashSet.Create;
  try
    for LI := 1 to KEY_COUNT do
      LS.Insert(LI);
    CheckEqual(PtrUInt(KEY_COUNT), LS.Count, 'count after insert');

    for LI := 1 to KEY_COUNT do
      Check(LS.Contains(LI), 'contains key');

    for LI := 1 to KEY_COUNT do
      Check(LS.Remove(LI), 'remove key');
    CheckEqual(PtrUInt(0), LS.Count, 'count after remove all');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 8: Remove non-existent key                               }
{ ============================================================ }

procedure TestHashSetRemoveNonExistent;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(1);
    LS.Insert(2);

    Check(not LS.Remove(3), 'remove non-existent');
    Check(not LS.Remove(0), 'remove 0');
    Check(not LS.Remove(-1), 'remove -1');
    CheckEqual(PtrUInt(2), LS.Count, 'count unchanged');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ TEST 9: Negative keys                                        }
{ ============================================================ }

procedure TestHashSetNegativeKeys;
var
  LS: TIntHashSet;
begin
  LS := TIntHashSet.Create;
  try
    LS.Insert(-10);
    LS.Insert(-5);
    LS.Insert(0);
    LS.Insert(5);
    LS.Insert(10);

    Check(LS.Contains(-10), 'contains -10');
    Check(LS.Contains(-5), 'contains -5');
    Check(LS.Contains(0), 'contains 0');
    Check(LS.Contains(5), 'contains 5');
    Check(LS.Contains(10), 'contains 10');
    Check(not LS.Contains(-11), 'does not contain -11');
    Check(not LS.Contains(11), 'does not contain 11');

    Check(LS.Remove(-5), 'remove -5');
    Check(not LS.Contains(-5), 'does not contain -5 after remove');
    CheckEqual(PtrUInt(4), LS.Count, 'count after remove');
  finally
    LS.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.lockfree.hashset');
  T.Test('Basic insert and contains', @TestHashSetBasic);
  T.Test('Remove', @TestHashSetRemove);
  T.Test('Count', @TestHashSetCount);
  T.Test('Clear', @TestHashSetClear);
  T.Test('Duplicate insert', @TestHashSetDuplicate);
  T.Test('Empty operations', @TestHashSetEmpty);
  T.Test('Many keys stress', @TestHashSetManyKeys);
  T.Test('Remove non-existent key', @TestHashSetRemoveNonExistent);
  T.Test('Negative keys', @TestHashSetNegativeKeys);
  if not T.Run then Halt(1);
end.
