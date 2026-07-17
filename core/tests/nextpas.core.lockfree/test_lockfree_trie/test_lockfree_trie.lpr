program test_lockfree_trie;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.trie,
  nextpas.core.test;

type
  TIntTrie = specialize TConcurrentTrieImpl<Integer>;

procedure TestTrieBasic;
var
  LTrie: TIntTrie;
begin
  LTrie := TIntTrie.Create;
  try
    Check(not LTrie.IsClosed, 'Should not be closed');
    CheckEqual(Int64(0), LTrie.GetCount, 'Count should be 0');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieInsertFind;
var
  LTrie: TIntTrie;
  LValue: Integer;
  LResult: TLockFreeTrieResult;
begin
  LTrie := TIntTrie.Create;
  try
    // Insert
    LResult := LTrie.Insert('hello', 42);
    Check(trInserted = LResult, 'Should insert');
    CheckEqual(Int64(1), LTrie.GetCount, 'Count should be 1');

    // Find
    Check(LTrie.Find('hello', LValue), 'Should find hello');
    CheckEqual(42, LValue, 'Value should be 42');

    // Not found
    Check(not LTrie.Find('world', LValue), 'Should not find world');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieUpdate;
var
  LTrie: TIntTrie;
  LValue: Integer;
  LResult: TLockFreeTrieResult;
begin
  LTrie := TIntTrie.Create;
  try
    LTrie.Insert('key', 10);
    LResult := LTrie.Insert('key', 20);
    Check(trUpdated = LResult, 'Should update');

    Check(LTrie.Find('key', LValue), 'Should find key');
    CheckEqual(20, LValue, 'Value should be 20');
    CheckEqual(Int64(1), LTrie.GetCount, 'Count should be 1');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieDelete;
var
  LTrie: TIntTrie;
  LResult: TLockFreeTrieResult;
begin
  LTrie := TIntTrie.Create;
  try
    LTrie.Insert('key', 42);
    LResult := LTrie.Delete('key');
    Check(trDeleted = LResult, 'Should delete');
    CheckEqual(Int64(0), LTrie.GetCount, 'Count should be 0');

    // Delete again
    LResult := LTrie.Delete('key');
    Check(trNotFound = LResult, 'Should not find');

    // Delete non-existent
    LResult := LTrie.Delete('missing');
    Check(trNotFound = LResult, 'Should not find');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieContains;
var
  LTrie: TIntTrie;
begin
  LTrie := TIntTrie.Create;
  try
    LTrie.Insert('abc', 1);
    LTrie.Insert('abd', 2);
    LTrie.Insert('acd', 3);

    Check(LTrie.Contains('abc'), 'Should contain abc');
    Check(LTrie.Contains('abd'), 'Should contain abd');
    Check(LTrie.Contains('acd'), 'Should contain acd');
    Check(not LTrie.Contains('abe'), 'Should not contain abe');
    Check(not LTrie.Contains('a'), 'Should not contain a');
  finally
    LTrie.Free;
  end;
end;

procedure TestTriePrefixKeys;
var
  LTrie: TIntTrie;
  LValue: Integer;
begin
  LTrie := TIntTrie.Create;
  try
    // Insert keys with common prefixes
    LTrie.Insert('app', 1);
    LTrie.Insert('apple', 2);
    LTrie.Insert('application', 3);
    LTrie.Insert('apply', 4);

    Check(LTrie.Find('app', LValue), 'Should find app');
    CheckEqual(1, LValue);
    Check(LTrie.Find('apple', LValue), 'Should find apple');
    CheckEqual(2, LValue);
    Check(LTrie.Find('application', LValue), 'Should find application');
    CheckEqual(3, LValue);
    Check(LTrie.Find('apply', LValue), 'Should find apply');
    CheckEqual(4, LValue);

    CheckEqual(Int64(4), LTrie.GetCount, 'Count should be 4');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieClose;
var
  LTrie: TIntTrie;
  LResult: TLockFreeTrieResult;
begin
  LTrie := TIntTrie.Create;
  try
    LTrie.Close;
    Check(LTrie.IsClosed, 'Should be closed');

    LResult := LTrie.Insert('key', 42);
    Check(trClosed = LResult, 'Should return closed');

    Check(not LTrie.Find('key', PInteger(nil)^), 'Should not find when closed');
  finally
    LTrie.Free;
  end;
end;

procedure TestTrieClear;
var
  LTrie: TIntTrie;
begin
  LTrie := TIntTrie.Create;
  try
    LTrie.Insert('a', 1);
    LTrie.Insert('b', 2);
    LTrie.Insert('c', 3);
    CheckEqual(Int64(3), LTrie.GetCount, 'Count should be 3');

    LTrie.Clear;
    CheckEqual(Int64(0), LTrie.GetCount, 'Count should be 0 after clear');
  finally
    LTrie.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_trie ===');
  WriteLn;

  TestTrieBasic;
  WriteLn('  + Basic state');

  TestTrieInsertFind;
  WriteLn('  + Insert/Find');

  TestTrieUpdate;
  WriteLn('  + Update');

  TestTrieDelete;
  WriteLn('  + Delete');

  TestTrieContains;
  WriteLn('  + Contains');

  TestTriePrefixKeys;
  WriteLn('  + Prefix keys');

  TestTrieClose;
  WriteLn('  + Close semantics');

  TestTrieClear;
  WriteLn('  + Clear');

  WriteLn;
  WriteLn('All trie tests passed!');
end.
