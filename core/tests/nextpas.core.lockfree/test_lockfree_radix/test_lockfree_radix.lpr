program test_lockfree_radix;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.radix,
  nextpas.core.atomic,
  nextpas.core.test;

var
  GMutatingTree: TConcurrentRadixTree;
  GMutationAttempted: Boolean;

procedure MutatingCallback(const AKey: AnsiString; AValue: Int64);
begin
  if not GMutationAttempted then
  begin
    GMutationAttempted := True;
    GMutatingTree.Insert('z', 26);
  end;
end;

procedure TestRadixBasic;
var
  LTree: TConcurrentRadixTree;
  LValue: Int64;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    CheckEqual(Ord(rdInserted), Ord(LTree.Insert('hello', 100)));
    CheckEqual(Ord(rdInserted), Ord(LTree.Insert('world', 200)));
    CheckEqual(Ord(rdInserted), Ord(LTree.Insert('help', 300)));

    Check(LTree.Find('hello', LValue), 'Should find hello');
    CheckEqual(Int64(100), LValue);

    Check(LTree.Find('world', LValue), 'Should find world');
    CheckEqual(Int64(200), LValue);

    Check(LTree.Find('help', LValue), 'Should find help');
    CheckEqual(Int64(300), LValue);

    Check(not LTree.Find('xyz', LValue), 'Should not find xyz');
  finally
    LTree.Free;
  end;
end;

procedure TestRadixUpdate;
var
  LTree: TConcurrentRadixTree;
  LValue: Int64;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    LTree.Insert('key', 100);
    CheckEqual(Ord(rdUpdated), Ord(LTree.Insert('key', 999)));

    Check(LTree.Find('key', LValue), 'Should find key');
    CheckEqual(Int64(999), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestRadixRemove;
var
  LTree: TConcurrentRadixTree;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    LTree.Insert('abc', 1);
    LTree.Insert('abd', 2);
    LTree.Insert('abe', 3);

    CheckEqual(Ord(rdRemoved), Ord(LTree.Remove('abd')));
    Check(not LTree.Contains('abd'), 'abd should be removed');
    Check(LTree.Contains('abc'), 'abc should still exist');
    Check(LTree.Contains('abe'), 'abe should still exist');

    CheckEqual(Ord(rdNotFound), Ord(LTree.Remove('xyz')));
  finally
    LTree.Free;
  end;
end;

procedure TestRadixCount;
var
  LTree: TConcurrentRadixTree;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    CheckEqual(Int64(0), LTree.GetCount);
    LTree.Insert('a', 1);
    CheckEqual(Int64(1), LTree.GetCount);
    LTree.Insert('b', 2);
    CheckEqual(Int64(2), LTree.GetCount);
    LTree.Remove('a');
    CheckEqual(Int64(1), LTree.GetCount);
  finally
    LTree.Free;
  end;
end;

procedure TestRadixCommonPrefix;
var
  LTree: TConcurrentRadixTree;
  LValue: Int64;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    LTree.Insert('testing', 1);
    LTree.Insert('test', 2);
    LTree.Insert('tested', 3);

    Check(LTree.Find('testing', LValue), 'Should find testing');
    CheckEqual(Int64(1), LValue);

    Check(LTree.Find('test', LValue), 'Should find test');
    CheckEqual(Int64(2), LValue);

    Check(LTree.Find('tested', LValue), 'Should find tested');
    CheckEqual(Int64(3), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestRadixClose;
var
  LTree: TConcurrentRadixTree;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    LTree.Insert('key', 100);
    LTree.Close;
    Check(LTree.IsClosed, 'Should be closed');
    CheckEqual(Ord(rdClosed), Ord(LTree.Insert('key2', 200)));
    CheckEqual(Ord(rdClosed), Ord(LTree.Remove('key')));
  finally
    LTree.Free;
  end;
end;

procedure TestRadixEmptyKey;
var
  LTree: TConcurrentRadixTree;
  LValue: Int64;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    CheckEqual(Ord(rdInserted), Ord(LTree.Insert('', 42)));
    Check(LTree.Find('', LValue), 'Should find empty key');
    CheckEqual(Int64(42), LValue);
  finally
    LTree.Free;
  end;
end;

procedure TestRadixForEachAllowsMutation;
var
  LTree: TConcurrentRadixTree;
begin
  LTree := TConcurrentRadixTree.Create;
  try
    LTree.Insert('a', 1);
    LTree.Insert('b', 2);
    GMutatingTree := LTree;
    GMutationAttempted := False;
    LTree.ForEach(@MutatingCallback);
    Check(GMutationAttempted, 'Callback should run');
    Check(LTree.Contains('z'), 'Callback insertion should complete');
  finally
    GMutatingTree := nil;
    LTree.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_radix ===');
  WriteLn;

  TestRadixBasic;
  WriteLn('  + Basic operations');

  TestRadixUpdate;
  WriteLn('  + Update');

  TestRadixRemove;
  WriteLn('  + Remove');

  TestRadixCount;
  WriteLn('  + Count');

  TestRadixCommonPrefix;
  WriteLn('  + Common prefix');

  TestRadixClose;
  WriteLn('  + Close semantics');

  TestRadixEmptyKey;
  WriteLn('  + Empty key');

  TestRadixForEachAllowsMutation;
  WriteLn('  + ForEach callback mutation');

  WriteLn;
  WriteLn('All radix tree tests passed!');
end.
