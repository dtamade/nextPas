program test_lockfree_bplus;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.bplus,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GSum: Int64;
  GKeys: array of Int64;
  GIdx: Integer;

procedure SumCallback(AKey, AValue: Int64);
begin
  GSum := GSum + AValue;
end;

procedure RangeCallback(AKey, AValue: Int64; var AContinue: Boolean);
begin
  GKeys[GIdx] := AKey;
  Inc(GIdx);
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

  TestBplusRangeQuery;
  WriteLn('  + Range query');

  TestBplusClose;
  WriteLn('  + Close semantics');

  TestBplusLargeInsert;
  WriteLn('  + Large insert');

  WriteLn;
  WriteLn('All B+ tree tests passed!');
end.
