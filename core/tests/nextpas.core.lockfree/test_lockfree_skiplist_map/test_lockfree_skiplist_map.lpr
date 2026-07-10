{$mode ObjFPC}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
program test_lockfree_skiplist_map;

uses
  SysUtils,
  nextpas.core.lockfree.skiplist_map;

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
  LMap: TConcurrentSkipListMap;
  LVal: AnsiString;
begin
  WriteLn('--- Empty ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    Check(LMap.Count = 0, 'empty count = 0');
    Check(LMap.IsEmpty, 'empty is empty');
    Check(LMap.Find('key', LVal) = slmNotFound, 'empty find = not found');
    Check(not LMap.Contains('key'), 'empty not contains');
    Check(LMap.Remove('key') = slmNotFound, 'empty remove = not found');
  finally
    LMap.Free;
  end;
end;

procedure Test_InsertFind;
var
  LMap: TConcurrentSkipListMap;
  LVal: AnsiString;
begin
  WriteLn('--- InsertFind ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    Check(LMap.Insert('hello', 'world') = slmOk, 'insert hello');
    Check(LMap.Count = 1, 'count = 1');
    Check(LMap.Find('hello', LVal) = slmOk, 'find hello');
    Check(LVal = 'world', 'value = world');
  finally
    LMap.Free;
  end;
end;

procedure Test_SortedOrder;
var
  LMap: TConcurrentSkipListMap;
  LKeys: AnsiString;
begin
  WriteLn('--- SortedOrder ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    LMap.Insert('c', '3');
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    LKeys := '';
    LMap.ForEach(procedure(const AKey, AValue: AnsiString)
    begin
      if LKeys <> '' then LKeys := LKeys + ',';
      LKeys := LKeys + AKey;
    end);
    Check(LKeys = 'a,b,c', 'sorted order a,b,c');
  finally
    LMap.Free;
  end;
end;

procedure Test_MinMax;
var
  LMap: TConcurrentSkipListMap;
  LKey, LVal: AnsiString;
begin
  WriteLn('--- MinMax ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    LMap.Insert('c', '3');
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    Check(LMap.Min(LKey, LVal), 'min exists');
    Check(LKey = 'a', 'min key = a');
    Check(LMap.Max(LKey, LVal), 'max exists');
    Check(LKey = 'c', 'max key = c');
  finally
    LMap.Free;
  end;
end;

procedure Test_CeilingFloor;
var
  LMap: TConcurrentSkipListMap;
  LKey, LVal: AnsiString;
begin
  WriteLn('--- CeilingFloor ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('c', '3');
    LMap.Insert('e', '5');
    Check(LMap.Ceiling('b', LKey, LVal), 'ceiling b');
    Check(LKey = 'c', 'ceiling b = c');
    Check(LMap.Floor('d', LKey, LVal), 'floor d');
    Check(LKey = 'c', 'floor d = c');
  finally
    LMap.Free;
  end;
end;

procedure Test_Remove;
var
  LMap: TConcurrentSkipListMap;
begin
  WriteLn('--- Remove ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    Check(LMap.Remove('a') = slmOk, 'remove a');
    Check(LMap.Count = 1, 'count = 1');
    Check(not LMap.Contains('a'), 'not contains a');
  finally
    LMap.Free;
  end;
end;

procedure Test_MultipleKeys;
var
  LMap: TConcurrentSkipListMap;
  LVal: AnsiString;
  I: Int32;
begin
  WriteLn('--- MultipleKeys ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    for I := 1 to 100 do
      LMap.Insert('key' + IntToStr(I), 'val' + IntToStr(I));
    Check(LMap.Count = 100, 'count = 100');
    for I := 1 to 100 do
    begin
      Check(LMap.Find('key' + IntToStr(I), LVal) = slmOk, 'find key' + IntToStr(I));
      Check(LVal = 'val' + IntToStr(I), 'value matches');
    end;
  finally
    LMap.Free;
  end;
end;

procedure Test_ForEachAllowsMutation;
var
  LMap: TConcurrentSkipListMap;
  LMutationAttempted: Boolean;
begin
  WriteLn('--- ForEachAllowsMutation ---');
  LMap := TConcurrentSkipListMap.Create;
  try
    LMap.Insert('a', '1');
    LMap.Insert('b', '2');
    LMutationAttempted := False;
    LMap.ForEach(procedure(const AKey, AValue: AnsiString)
    begin
      if not LMutationAttempted then
      begin
        LMutationAttempted := True;
        LMap.Insert('z', '26');
      end;
    end);
    Check(LMutationAttempted, 'callback should run');
    Check(LMap.Contains('z'), 'callback insertion should complete');
  finally
    LMap.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  Test_Empty;
  Test_InsertFind;
  Test_SortedOrder;
  Test_MinMax;
  Test_CeilingFloor;
  Test_Remove;
  Test_MultipleKeys;
  Test_ForEachAllowsMutation;

  WriteLn;
  WriteLn('=== SkipListMap: ', GPassed, ' passed, ', GFailed, ' failed ===');
  if GFailed > 0 then
    Halt(1);
end.
