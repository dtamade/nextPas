{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_trie_hmt;

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.trie_hmt;

var
  GTrie: THashMappedTrie;
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

procedure Test_InsertFind;
var
  LValue: AnsiString;
begin
  WriteLn('--- Insert/Find ---');
  GTrie := THashMappedTrie.Create;
  try
    Check(GTrie.IsEmpty, 'IsEmpty initially');

    Check(GTrie.Insert('key1', 'value1') = hmtOk, 'Insert(key1, value1)');
    Check(GTrie.Insert('key2', 'value2') = hmtOk, 'Insert(key2, value2)');
    Check(GTrie.Insert('key3', 'value3') = hmtOk, 'Insert(key3, value3)');
    Check(GTrie.Size = 3, 'Size = 3');

    Check(GTrie.Find('key1', LValue), 'Find(key1) = true');
    Check(LValue = 'value1', 'Find(key1) value = value1');

    Check(GTrie.Find('key2', LValue), 'Find(key2) = true');
    Check(LValue = 'value2', 'Find(key2) value = value2');

    Check(not GTrie.Find('key4', LValue), 'Find(key4) = false');

    Check(GTrie.Contains('key1'), 'Contains(key1) = true');
    Check(not GTrie.Contains('key4'), 'Contains(key4) = false');
  finally
    GTrie.Free;
  end;
end;

procedure Test_Update;
var
  LValue: AnsiString;
begin
  WriteLn('--- Update ---');
  GTrie := THashMappedTrie.Create;
  try
    GTrie.Insert('key1', 'value1');
    Check(GTrie.Size = 1, 'Size = 1');

    GTrie.Insert('key1', 'value1-updated');
    Check(GTrie.Size = 1, 'Size still 1 after update');

    GTrie.Find('key1', LValue);
    Check(LValue = 'value1-updated', 'Value updated to value1-updated');
  finally
    GTrie.Free;
  end;
end;

procedure Test_Remove;
var
  LValue: AnsiString;
begin
  WriteLn('--- Remove ---');
  GTrie := THashMappedTrie.Create;
  try
    GTrie.Insert('key1', 'value1');
    GTrie.Insert('key2', 'value2');
    GTrie.Insert('key3', 'value3');

    Check(GTrie.Remove('key2') = hmtOk, 'Remove(key2) = ok');
    Check(GTrie.Size = 2, 'Size = 2');
    Check(not GTrie.Contains('key2'), 'Contains(key2) = false');
    Check(GTrie.Contains('key1'), 'Contains(key1) = true');
    Check(GTrie.Contains('key3'), 'Contains(key3) = true');

    Check(GTrie.Remove('key4') = hmtNotFound, 'Remove(key4) = not found');

    GTrie.Remove('key1');
    GTrie.Remove('key3');
    Check(GTrie.IsEmpty, 'IsEmpty after removing all');
  finally
    GTrie.Free;
  end;
end;

procedure Test_Collision;
var
  LValue: AnsiString;
  I: Int32;
begin
  WriteLn('--- Collision (many keys) ---');
  GTrie := THashMappedTrie.Create;
  try
    { Insert many keys to force collisions }
    for I := 0 to 999 do
      GTrie.Insert('key-' + IntToStr(I), 'val-' + IntToStr(I));

    Check(GTrie.Size = 1000, 'Size = 1000');

    { Verify all keys }
    for I := 0 to 999 do
    begin
      if not GTrie.Find('key-' + IntToStr(I), LValue) then
      begin
        Check(False, 'Find(key-' + IntToStr(I) + ') failed');
        Break;
      end;
      if LValue <> 'val-' + IntToStr(I) then
      begin
        Check(False, 'Value mismatch for key-' + IntToStr(I));
        Break;
      end;
    end;
    Check(True, 'All 1000 keys verified');
  finally
    GTrie.Free;
  end;
end;

procedure Test_Snapshot;
var
  LSnap: THmtSnapshot;
begin
  WriteLn('--- Snapshot ---');
  GTrie := THashMappedTrie.Create;
  try
    GTrie.Insert('key1', 'value1');
    GTrie.Insert('key2', 'value2');

    LSnap := GTrie.Snapshot;
    Check(LSnap.Size = 2, 'Snapshot size = 2');
    Check(LSnap.Root <> nil, 'Snapshot root <> nil');

    { Modify trie after snapshot }
    GTrie.Insert('key3', 'value3');
    LSnap := GTrie.Snapshot;
    Check(LSnap.Size = 3, 'Snapshot size = 3 after insert');
  finally
    GTrie.Free;
  end;
end;

procedure Test_EmptyKey;
var
  LValue: AnsiString;
begin
  WriteLn('--- Empty Key ---');
  GTrie := THashMappedTrie.Create;
  try
    Check(GTrie.Insert('', 'empty-value') = hmtOk, 'Insert empty key');
    Check(GTrie.Find('', LValue), 'Find empty key = true');
    Check(LValue = 'empty-value', 'Empty key value = empty-value');
  finally
    GTrie.Free;
  end;
end;

procedure Test_PrefixKeys;
var
  LValue: AnsiString;
begin
  WriteLn('--- Prefix Keys ---');
  GTrie := THashMappedTrie.Create;
  try
    GTrie.Insert('app', 'root');
    GTrie.Insert('app.config', 'config');
    GTrie.Insert('app.config.db', 'db');
    GTrie.Insert('app.config.cache', 'cache');
    GTrie.Insert('app.users', 'users');

    Check(GTrie.Size = 5, 'Size = 5');

    GTrie.Find('app', LValue);
    Check(LValue = 'root', 'app = root');
    GTrie.Find('app.config.db', LValue);
    Check(LValue = 'db', 'app.config.db = db');
  finally
    GTrie.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Hash Mapped Trie (HMT) Tests ===');
  Test_InsertFind;
  Test_Update;
  Test_Remove;
  Test_Collision;
  Test_Snapshot;
  Test_EmptyKey;
  Test_PrefixKeys;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
