program test_lockfree_treap;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.treap,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GSum: Int64;
  GMutatingTreap: TConcurrentTreap;
  GMutationAttempted: Boolean;

procedure SumCallback(AKey, AValue: Int64);
begin
  GSum := GSum + AValue;
end;

procedure MutatingCallback(AKey, AValue: Int64);
begin
  if not GMutationAttempted then
  begin
    GMutationAttempted := True;
    GMutatingTreap.Insert(99, 990);
  end;
end;

procedure TestTreapBasic;
var
  LTreap: TConcurrentTreap;
  LValue: Int64;
begin
  LTreap := TConcurrentTreap.Create;
  try
    CheckEqual(Ord(trInserted), Ord(LTreap.Insert(5, 500)));
    CheckEqual(Ord(trInserted), Ord(LTreap.Insert(3, 300)));
    CheckEqual(Ord(trInserted), Ord(LTreap.Insert(7, 700)));

    Check(LTreap.Find(5, LValue), 'Should find key 5');
    CheckEqual(Int64(500), LValue);

    Check(LTreap.Find(3, LValue), 'Should find key 3');
    CheckEqual(Int64(300), LValue);

    Check(not LTreap.Find(99, LValue), 'Should not find key 99');
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapUpdate;
var
  LTreap: TConcurrentTreap;
  LValue: Int64;
begin
  LTreap := TConcurrentTreap.Create;
  try
    LTreap.Insert(1, 100);
    CheckEqual(Ord(trUpdated), Ord(LTreap.Insert(1, 999)));

    Check(LTreap.Find(1, LValue), 'Should find key 1');
    CheckEqual(Int64(999), LValue);
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapRemove;
var
  LTreap: TConcurrentTreap;
begin
  LTreap := TConcurrentTreap.Create;
  try
    LTreap.Insert(1, 100);
    LTreap.Insert(2, 200);
    LTreap.Insert(3, 300);

    CheckEqual(Ord(trRemoved), Ord(LTreap.Remove(2)));
    Check(not LTreap.Contains(2), 'Key 2 should be removed');
    Check(LTreap.Contains(1), 'Key 1 should still exist');
    Check(LTreap.Contains(3), 'Key 3 should still exist');

    CheckEqual(Ord(trNotFound), Ord(LTreap.Remove(99)));
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapCount;
var
  LTreap: TConcurrentTreap;
begin
  LTreap := TConcurrentTreap.Create;
  try
    CheckEqual(Int64(0), LTreap.GetCount);
    LTreap.Insert(1, 100);
    CheckEqual(Int64(1), LTreap.GetCount);
    LTreap.Insert(2, 200);
    CheckEqual(Int64(2), LTreap.GetCount);
    LTreap.Remove(1);
    CheckEqual(Int64(1), LTreap.GetCount);
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapForEach;
var
  LTreap: TConcurrentTreap;
begin
  LTreap := TConcurrentTreap.Create;
  try
    LTreap.Insert(3, 300);
    LTreap.Insert(1, 100);
    LTreap.Insert(2, 200);

    GSum := 0;
    LTreap.ForEach(@SumCallback);
    CheckEqual(Int64(600), GSum);
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapForEachAllowsMutation;
var
  LTreap: TConcurrentTreap;
begin
  LTreap := TConcurrentTreap.Create;
  try
    LTreap.Insert(1, 10);
    LTreap.Insert(2, 20);
    GMutatingTreap := LTreap;
    GMutationAttempted := False;
    LTreap.ForEach(@MutatingCallback);
    Check(GMutationAttempted, 'Callback should run');
    Check(LTreap.Contains(99), 'Callback insertion should complete');
  finally
    GMutatingTreap := nil;
    LTreap.Free;
  end;
end;

procedure TestTreapClose;
var
  LTreap: TConcurrentTreap;
begin
  LTreap := TConcurrentTreap.Create;
  try
    LTreap.Insert(1, 100);
    LTreap.Close;
    Check(LTreap.IsClosed, 'Should be closed');
    CheckEqual(Ord(trClosed), Ord(LTreap.Insert(2, 200)));
    CheckEqual(Ord(trClosed), Ord(LTreap.Remove(1)));
  finally
    LTreap.Free;
  end;
end;

procedure TestTreapLargeInsert;
var
  LTreap: TConcurrentTreap;
  LI: Integer;
begin
  LTreap := TConcurrentTreap.Create;
  try
    for LI := 1 to 100 do
      CheckEqual(Ord(trInserted), Ord(LTreap.Insert(LI, LI * 10)));

    CheckEqual(Int64(100), LTreap.GetCount);

    for LI := 1 to 100 do
      Check(LTreap.Contains(LI), 'Should contain all keys');
  finally
    LTreap.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_treap ===');
  WriteLn;

  TestTreapBasic;
  WriteLn('  + Basic operations');

  TestTreapUpdate;
  WriteLn('  + Update');

  TestTreapRemove;
  WriteLn('  + Remove');

  TestTreapCount;
  WriteLn('  + Count');

  TestTreapForEach;
  WriteLn('  + ForEach');

  TestTreapForEachAllowsMutation;
  WriteLn('  + ForEach callback mutation');

  TestTreapClose;
  WriteLn('  + Close semantics');

  TestTreapLargeInsert;
  WriteLn('  + Large insert');

  WriteLn;
  WriteLn('All treap tests passed!');
end.
