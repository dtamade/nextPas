program test_lockfree_rbtree;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.rbtree,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GSum: Int64;
  GValues: array of Int64;
  GIdx: Integer;

procedure SumCallback(AKey, AValue: Int64);
begin
  GSum := GSum + AValue;
end;

procedure CollectCallback(AKey, AValue: Int64);
begin
  GValues[GIdx] := AKey;
  Inc(GIdx);
end;

procedure TestRBTreeBasic;
var
  LTree: TConcurrentRBTree;
  LValue: Int64;
begin
  LTree := TConcurrentRBTree.Create;
  try
    CheckEqual(Ord(rbInserted), Ord(LTree.Insert(5, 500)));
    CheckEqual(Ord(rbInserted), Ord(LTree.Insert(3, 300)));
    CheckEqual(Ord(rbInserted), Ord(LTree.Insert(7, 700)));

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

procedure TestRBTreeUpdate;
var
  LTree: TConcurrentRBTree;
  LValue: Int64;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(1, 100);
    CheckEqual(Ord(rbUpdated), Ord(LTree.Insert(1, 999)));

    Check(LTree.Find(1, LValue), 'Should find key 1');
    CheckEqual(Int64(999), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeRemove;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Insert(2, 200);
    LTree.Insert(3, 300);

    CheckEqual(Ord(rbRemoved), Ord(LTree.Remove(2)));
    Check(not LTree.Contains(2), 'Key 2 should be removed');
    Check(LTree.Contains(1), 'Key 1 should still exist');
    Check(LTree.Contains(3), 'Key 3 should still exist');

    CheckEqual(Ord(rbNotFound), Ord(LTree.Remove(99)));
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeContains;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(1, 100);
    Check(LTree.Contains(1), 'Should contain key 1');
    Check(not LTree.Contains(99), 'Should not contain key 99');
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeCount;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
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

procedure TestRBTreeForEach;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
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

procedure TestRBTreeClear;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Insert(2, 200);
    LTree.Clear;
    CheckEqual(Int64(0), LTree.GetCount);
    Check(not LTree.Contains(1), 'Should be empty after clear');
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeClose;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Close;
    Check(LTree.IsClosed, 'Should be closed');
    CheckEqual(Ord(rbClosed), Ord(LTree.Insert(2, 200)));
    CheckEqual(Ord(rbClosed), Ord(LTree.Remove(1)));
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeSorted;
var
  LTree: TConcurrentRBTree;
begin
  LTree := TConcurrentRBTree.Create;
  try
    LTree.Insert(10, 100);
    LTree.Insert(5, 50);
    LTree.Insert(15, 150);
    LTree.Insert(3, 30);
    LTree.Insert(7, 70);
    LTree.Insert(12, 120);
    LTree.Insert(18, 180);

    SetLength(GValues, 7);
    GIdx := 0;
    LTree.ForEach(@CollectCallback);

    CheckEqual(Int64(3), GValues[0]);
    CheckEqual(Int64(5), GValues[1]);
    CheckEqual(Int64(7), GValues[2]);
    CheckEqual(Int64(10), GValues[3]);
    CheckEqual(Int64(12), GValues[4]);
    CheckEqual(Int64(15), GValues[5]);
    CheckEqual(Int64(18), GValues[6]);
  finally
    LTree.Free;
  end;
end;

procedure TestRBTreeLargeInsert;
var
  LTree: TConcurrentRBTree;
  LI: Integer;
begin
  LTree := TConcurrentRBTree.Create;
  try
    for LI := 1 to 100 do
      CheckEqual(Ord(rbInserted), Ord(LTree.Insert(LI, LI * 10)));

    CheckEqual(Int64(100), LTree.GetCount);

    for LI := 1 to 100 do
      Check(LTree.Contains(LI), 'Should contain all keys');
  finally
    LTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_rbtree ===');
  WriteLn;

  TestRBTreeBasic;
  WriteLn('  + Basic operations');

  TestRBTreeUpdate;
  WriteLn('  + Update');

  TestRBTreeRemove;
  WriteLn('  + Remove');

  TestRBTreeContains;
  WriteLn('  + Contains');

  TestRBTreeCount;
  WriteLn('  + Count');

  TestRBTreeForEach;
  WriteLn('  + ForEach');

  TestRBTreeClear;
  WriteLn('  + Clear');

  TestRBTreeClose;
  WriteLn('  + Close semantics');

  TestRBTreeSorted;
  WriteLn('  + Sorted order');

  TestRBTreeLargeInsert;
  WriteLn('  + Large insert');

  WriteLn;
  WriteLn('All RBTree tests passed!');
end.
