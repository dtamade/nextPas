program test_lockfree_scapegoat;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.scapegoat,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GSum: Int64;

procedure SumCallback(AKey, AValue: Int64);
begin
  GSum := GSum + AValue;
end;

procedure TestScapegoatBasic;
var
  LTree: TConcurrentScapegoatTree;
  LValue: Int64;
begin
  LTree := TConcurrentScapegoatTree.Create;
  try
    CheckEqual(Ord(sgInserted), Ord(LTree.Insert(5, 500)));
    CheckEqual(Ord(sgInserted), Ord(LTree.Insert(3, 300)));
    CheckEqual(Ord(sgInserted), Ord(LTree.Insert(7, 700)));

    Check(LTree.Find(5, LValue), 'Should find key 5');
    CheckEqual(Int64(500), LValue);

    Check(LTree.Find(3, LValue), 'Should find key 3');
    CheckEqual(Int64(300), LValue);

    Check(not LTree.Find(99, LValue), 'Should not find key 99');
  finally
    LTree.Free;
  end;
end;

procedure TestScapegoatUpdate;
var
  LTree: TConcurrentScapegoatTree;
  LValue: Int64;
begin
  LTree := TConcurrentScapegoatTree.Create;
  try
    LTree.Insert(1, 100);
    CheckEqual(Ord(sgUpdated), Ord(LTree.Insert(1, 999)));

    Check(LTree.Find(1, LValue), 'Should find key 1');
    CheckEqual(Int64(999), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestScapegoatRemove;
var
  LTree: TConcurrentScapegoatTree;
begin
  LTree := TConcurrentScapegoatTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Insert(2, 200);
    LTree.Insert(3, 300);

    CheckEqual(Ord(sgRemoved), Ord(LTree.Remove(2)));
    Check(not LTree.Contains(2), 'Key 2 should be removed');
    Check(LTree.Contains(1), 'Key 1 should still exist');
    Check(LTree.Contains(3), 'Key 3 should still exist');

    CheckEqual(Ord(sgNotFound), Ord(LTree.Remove(99)));
  finally
    LTree.Free;
  end;
end;

procedure TestScapegoatCount;
var
  LTree: TConcurrentScapegoatTree;
begin
  LTree := TConcurrentScapegoatTree.Create;
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

procedure TestScapegoatForEach;
var
  LTree: TConcurrentScapegoatTree;
begin
  LTree := TConcurrentScapegoatTree.Create;
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

procedure TestScapegoatClose;
var
  LTree: TConcurrentScapegoatTree;
begin
  LTree := TConcurrentScapegoatTree.Create;
  try
    LTree.Insert(1, 100);
    LTree.Close;
    Check(LTree.IsClosed, 'Should be closed');
    CheckEqual(Ord(sgClosed), Ord(LTree.Insert(2, 200)));
    CheckEqual(Ord(sgClosed), Ord(LTree.Remove(1)));
  finally
    LTree.Free;
  end;
end;

procedure TestScapegoatLargeInsert;
var
  LTree: TConcurrentScapegoatTree;
  LI: Integer;
begin
  LTree := TConcurrentScapegoatTree.Create;
  try
    for LI := 1 to 100 do
      CheckEqual(Ord(sgInserted), Ord(LTree.Insert(LI, LI * 10)));

    CheckEqual(Int64(100), LTree.GetCount);

    for LI := 1 to 100 do
      Check(LTree.Contains(LI), 'Should contain all keys');
  finally
    LTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_scapegoat ===');
  WriteLn;

  TestScapegoatBasic;
  WriteLn('  + Basic operations');

  TestScapegoatUpdate;
  WriteLn('  + Update');

  TestScapegoatRemove;
  WriteLn('  + Remove');

  TestScapegoatCount;
  WriteLn('  + Count');

  TestScapegoatForEach;
  WriteLn('  + ForEach');

  TestScapegoatClose;
  WriteLn('  + Close semantics');

  TestScapegoatLargeInsert;
  WriteLn('  + Large insert');

  WriteLn;
  WriteLn('All scapegoat tree tests passed!');
end.
