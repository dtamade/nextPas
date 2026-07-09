{$mode ObjFPC}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
program test_lockfree_trie_map;

uses
  SysUtils,
  nextpas.core.lockfree.trie_map;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_Empty;
var
  LMap: TConcurrentTrieMap;
  LVal: AnsiString;
begin
  WriteLn('--- Empty ---');
  LMap := TConcurrentTrieMap.Create;
  try
    Check(LMap.Count = 0, 'empty count = 0');
    Check(LMap.IsEmpty, 'empty is empty');
    Check(LMap.Find('key', LVal) = tmNotFound, 'empty find = not found');
    Check(not LMap.Contains('key'), 'empty not contains');
    Check(LMap.Remove('key') = tmNotFound, 'empty remove = not found');
  finally
    LMap.Free;
  end;
end;

procedure Test_InsertFind;
var
  LMap: TConcurrentTrieMap;
  LVal: AnsiString;
begin
  WriteLn('--- InsertFind ---');
  LMap := TConcurrentTrieMap.Create;
  try
    Check(LMap.Insert('hello', 'world') = tmOk, 'insert hello');
    Check(LMap.Count = 1, 'count = 1');
    Check(not LMap.IsEmpty, 'not empty');
    Check(LMap.Find('hello', LVal) = tmOk, 'find hello');
    Check(LVal = 'world', 'value = world');
    Check(LMap.Contains('hello'), 'contains hello');
  finally
    LMap.Free;
  end;
end;

procedure Test_Update;
var
  LMap: TConcurrentTrieMap;
  LVal: AnsiString;
begin
  WriteLn('--- Update ---');
  LMap := TConcurrentTrieMap.Create;
  try
    LMap.Insert('key', 'v1');
    LMap.Insert('key', 'v2');
    Check(LMap.Count = 1, 'count still 1');
    Check(LMap.Find('key', LVal) = tmOk, 'find key');
    Check(LVal = 'v2', 'value updated to v2');
  finally
    LMap.Free;
  end;
end;

procedure Test_InsertIfAbsent;
var
  LMap: TConcurrentTrieMap;
begin
  WriteLn('--- InsertIfAbsent ---');
  LMap := TConcurrentTrieMap.Create;
  try
    Check(LMap.InsertIfAbsent('key', 'v1') = tmOk, 'first insert ok');
    Check(LMap.InsertIfAbsent('key', 'v2') = tmKeyExists, 'second insert = exists');
    Check(LMap.Count = 1, 'count = 1');
  finally
    LMap.Free;
  end;
end;

procedure Test_Remove;
var
  LMap: TConcurrentTrieMap;
begin
  WriteLn('--- Remove ---');
  LMap := TConcurrentTrieMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    Check(LMap.Remove('a') = tmOk, 'remove a');
    Check(LMap.Count = 1, 'count = 1');
    Check(not LMap.Contains('a'), 'not contains a');
    Check(LMap.Contains('b'), 'contains b');
  finally
    LMap.Free;
  end;
end;

procedure Test_MultipleKeys;
var
  LMap: TConcurrentTrieMap;
  LVal: AnsiString;
  I: Int32;
begin
  WriteLn('--- MultipleKeys ---');
  LMap := TConcurrentTrieMap.Create;
  try
    for I := 1 to 100 do
      LMap.Insert('key' + IntToStr(I), 'val' + IntToStr(I));
    Check(LMap.Count = 100, 'count = 100');
    for I := 1 to 100 do
    begin
      Check(LMap.Find('key' + IntToStr(I), LVal) = tmOk, 'find key' + IntToStr(I));
      Check(LVal = 'val' + IntToStr(I), 'value matches');
    end;
  finally
    LMap.Free;
  end;
end;

procedure Test_Clear;
var
  LMap: TConcurrentTrieMap;
begin
  WriteLn('--- Clear ---');
  LMap := TConcurrentTrieMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    LMap.Clear;
    Check(LMap.Count = 0, 'clear count = 0');
    Check(LMap.IsEmpty, 'clear is empty');
  finally
    LMap.Free;
  end;
end;

procedure Test_ForEach;
var
  LMap: TConcurrentTrieMap;
  LCount: Int32;
begin
  WriteLn('--- ForEach ---');
  LMap := TConcurrentTrieMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    LMap.Insert('c', '3');
    LCount := 0;
    LMap.ForEach(procedure(const AKey, AValue: AnsiString)
    begin
      Inc(LCount);
    end);
    Check(LCount = 3, 'foreach count = 3');
  finally
    LMap.Free;
  end;
end;

procedure Test_HashCollision;
var
  LMap: TConcurrentTrieMap;
  LVal: AnsiString;
begin
  WriteLn('--- HashCollision ---');
  LMap := TConcurrentTrieMap.Create;
  try
    { Many keys to test collision handling }
    LMap.Insert('abc', '1');
    LMap.Insert('acb', '2');
    LMap.Insert('bac', '3');
    LMap.Insert('bca', '4');
    LMap.Insert('cab', '5');
    LMap.Insert('cba', '6');
    Check(LMap.Count = 6, 'collision count = 6');
    Check(LMap.Find('abc', LVal) = tmOk, 'find abc');
    Check(LVal = '1', 'abc = 1');
    Check(LMap.Find('cba', LVal) = tmOk, 'find cba');
    Check(LVal = '6', 'cba = 6');
  finally
    LMap.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  Test_Empty;
  Test_InsertFind;
  Test_Update;
  Test_InsertIfAbsent;
  Test_Remove;
  Test_MultipleKeys;
  Test_Clear;
  Test_ForEach;
  Test_HashCollision;

  WriteLn;
  WriteLn('=== TrieMap: ', GPassed, ' passed, ', GFailed, ' failed ===');
  if GFailed > 0 then
    Halt(1);
end.
