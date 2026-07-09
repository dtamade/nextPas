{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_cuckooset;

uses
  SysUtils,
  nextpas.core.lockfree.cuckooset;

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

procedure Test_InsertContains;
var
  LSet: TCuckooSet;
begin
  WriteLn('--- Insert/Contains ---');
  LSet := TCuckooSet.Create(16);
  try
    Check(LSet.IsEmpty, 'IsEmpty initially');

    Check(LSet.Insert('key1') = csrOk, 'Insert(key1) = ok');
    Check(LSet.Insert('key2') = csrOk, 'Insert(key2) = ok');
    Check(LSet.Insert('key3') = csrOk, 'Insert(key3) = ok');
    Check(LSet.Count = 3, 'Count = 3');

    Check(LSet.Contains('key1'), 'Contains(key1) = true');
    Check(LSet.Contains('key2'), 'Contains(key2) = true');
    Check(LSet.Contains('key3'), 'Contains(key3) = true');
    Check(not LSet.Contains('key4'), 'Contains(key4) = false');

    Check(LSet.Insert('key1') = csrExists, 'Insert(key1) again = exists');
    Check(LSet.Count = 3, 'Count still 3');
  finally
    LSet.Free;
  end;
end;

procedure Test_Remove;
var
  LSet: TCuckooSet;
begin
  WriteLn('--- Remove ---');
  LSet := TCuckooSet.Create(16);
  try
    LSet.Insert('key1');
    LSet.Insert('key2');
    LSet.Insert('key3');

    Check(LSet.Remove('key2') = csrOk, 'Remove(key2) = ok');
    Check(LSet.Count = 2, 'Count = 2');
    Check(not LSet.Contains('key2'), 'Contains(key2) = false');
    Check(LSet.Contains('key1'), 'Contains(key1) = true');

    Check(LSet.Remove('key2') = csrNotFound, 'Remove(key2) again = not found');
    Check(LSet.Remove('key4') = csrNotFound, 'Remove(key4) = not found');
  finally
    LSet.Free;
  end;
end;

procedure Test_Clear;
var
  LSet: TCuckooSet;
begin
  WriteLn('--- Clear ---');
  LSet := TCuckooSet.Create(16);
  try
    LSet.Insert('key1');
    LSet.Insert('key2');

    LSet.Clear;
    Check(LSet.IsEmpty, 'IsEmpty after clear');
    Check(not LSet.Contains('key1'), 'Contains(key1) = false after clear');
  finally
    LSet.Free;
  end;
end;

procedure Test_LargeScale;
var
  LSet: TCuckooSet;
  I: Int32;
begin
  WriteLn('--- Large Scale ---');
  LSet := TCuckooSet.Create(16);
  try
    for I := 0 to 999 do
      Check(LSet.Insert('key-' + IntToStr(I)) = csrOk, 'Insert(key-' + IntToStr(I) + ')');

    Check(LSet.Count = 1000, 'Count = 1000');

    for I := 0 to 999 do
      Check(LSet.Contains('key-' + IntToStr(I)), 'Contains(key-' + IntToStr(I) + ')');
  finally
    LSet.Free;
  end;
end;

procedure Test_AutoResize;
var
  LSet: TCuckooSet;
  I: Int32;
begin
  WriteLn('--- Auto Resize ---');
  LSet := TCuckooSet.Create(4); { Small initial capacity }
  try
    { Insert many elements to trigger resize }
    for I := 0 to 199 do
      LSet.Insert('resize-' + IntToStr(I));

    Check(LSet.Count = 200, 'Count = 200 after resize');

    for I := 0 to 199 do
      Check(LSet.Contains('resize-' + IntToStr(I)), 'Contains after resize');
  finally
    LSet.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Cuckoo Hash Set Tests ===');
  Test_InsertContains;
  Test_Remove;
  Test_Clear;
  Test_LargeScale;
  Test_AutoResize;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
