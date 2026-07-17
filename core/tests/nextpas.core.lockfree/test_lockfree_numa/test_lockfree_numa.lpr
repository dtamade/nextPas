program test_lockfree_numa;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.hashmap,
  nextpas.core.lockfree.hashmap.numa;

type
  TTestHashMap = specialize TNumaShardedHashMapImpl<UInt64, UInt64>;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('  + ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  - ', ATestName, ' FAILED');
  end;
end;

function ComputeDouble(const AKey: UInt64): UInt64;
begin
  Result := AKey * 10;
end;

function ComputeTriple(const AKey: UInt64): UInt64;
begin
  Result := AKey * 100;
end;

function IncrementValue(const AOldValue: UInt64): UInt64;
begin
  Result := AOldValue + 1;
end;

procedure TestNumaHashMapBasic;
var
  LMap: TTestHashMap;
  LValue: UInt64;
begin
  WriteLn('TestNumaHashMapBasic:');
  LMap := TTestHashMap.Create(4);
  try
    // Insert and Find
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);
    LMap.Insert(3, 300);

    Check(LMap.Find(1, LValue) and (LValue = 100), 'Find key 1');
    Check(LMap.Find(2, LValue) and (LValue = 200), 'Find key 2');
    Check(LMap.Find(3, LValue) and (LValue = 300), 'Find key 3');
    Check(not LMap.Find(4, LValue), 'Find non-existent key');

    // Contains
    Check(LMap.Contains(1), 'Contains key 1');
    Check(not LMap.Contains(4), 'Contains non-existent key');

    // Count
    Check(LMap.Count = 3, 'Count = 3');

    // Remove
    Check(LMap.Remove(2), 'Remove key 2');
    Check(not LMap.Contains(2), 'Key 2 removed');
    Check(LMap.Count = 2, 'Count = 2 after remove');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapInsert;
var
  LMap: TTestHashMap;
  LValue: UInt64;
begin
  WriteLn('TestNumaHashMapInsert:');
  LMap := TTestHashMap.Create(4);
  try
    // TryInsert
    Check(LMap.TryInsert(1, 100), 'TryInsert new key');
    Check(not LMap.TryInsert(1, 200), 'TryInsert existing key');
    Check(LMap.Find(1, LValue) and (LValue = 100), 'Value unchanged after failed TryInsert');

    // Replace
    Check(LMap.Replace(1, 300, LValue), 'Replace existing key');
    Check(LValue = 100, 'Old value returned');
    Check(LMap.Find(1, LValue) and (LValue = 300), 'New value set');
    Check(not LMap.Replace(999, 400, LValue), 'Replace non-existent key');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapGetOrInsert;
var
  LMap: TTestHashMap;
  LResult: TTestHashMap.TGetOrInsertResult;
begin
  WriteLn('TestNumaHashMapGetOrInsert:');
  LMap := TTestHashMap.Create(4);
  try
    // GetOrInsert
    LResult := LMap.GetOrInsert(1, 100);
    Check(not LResult.Existed, 'GetOrInsert new key - Existed=false');
    Check(LResult.Value = 100, 'GetOrInsert new key - Value=100');

    LResult := LMap.GetOrInsert(1, 200);
    Check(LResult.Existed, 'GetOrInsert existing key - Existed=true');
    Check(LResult.Value = 100, 'GetOrInsert existing key - Value=100');

    // GetOrInsertFn
    LResult := LMap.GetOrInsertFn(2, @ComputeDouble);
    Check(not LResult.Existed, 'GetOrInsertFn new key - Existed=false');
    Check(LResult.Value = 20, 'GetOrInsertFn new key - Value=20');

    LResult := LMap.GetOrInsertFn(2, @ComputeTriple);
    Check(LResult.Existed, 'GetOrInsertFn existing key - Existed=true');
    Check(LResult.Value = 20, 'GetOrInsertFn existing key - Value=20');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapGetOrUpdate;
var
  LMap: TTestHashMap;
  LResult: TTestHashMap.TGetOrInsertResult;
begin
  WriteLn('TestNumaHashMapGetOrUpdate:');
  LMap := TTestHashMap.Create(4);
  try
    // GetOrUpdate - insert default
    LResult := LMap.GetOrUpdate(1, 10, @IncrementValue);
    Check(not LResult.Existed, 'GetOrUpdate new key - Existed=false');
    Check(LResult.Value = 10, 'GetOrUpdate new key - Value=10');

    // GetOrUpdate - update existing
    LResult := LMap.GetOrUpdate(1, 10, @IncrementValue);
    Check(LResult.Existed, 'GetOrUpdate existing key - Existed=true');
    Check(LResult.Value = 11, 'GetOrUpdate existing key - Value=11');

    // Multiple updates
    LResult := LMap.GetOrUpdate(1, 10, @IncrementValue);
    Check(LResult.Value = 12, 'GetOrUpdate after 2 updates - Value=12');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapReserve;
var
  LMap: TTestHashMap;
begin
  WriteLn('TestNumaHashMapReserve:');
  LMap := TTestHashMap.Create(4);
  try
    // Reserve should not fail
    LMap.Reserve(100);
    Check(True, 'Reserve(100) completed');

    // Insert after reserve
    LMap.Insert(1, 100);
    Check(LMap.Count = 1, 'Count = 1 after insert');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapNodeCount;
var
  LMap: TTestHashMap;
begin
  WriteLn('TestNumaHashMapNodeCount:');
  LMap := TTestHashMap.Create(4);
  try
    Check(LMap.NodeCount >= 1, 'NodeCount >= 1');

    // Insert to different nodes
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);
    LMap.Insert(3, 300);

    // Total count should be 3
    Check(LMap.Count = 3, 'Total count = 3');
  finally
    LMap.Free;
  end;
end;

procedure TestNumaHashMapClear;
var
  LMap: TTestHashMap;
begin
  WriteLn('TestNumaHashMapClear:');
  LMap := TTestHashMap.Create(4);
  try
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);
    Check(LMap.Count = 2, 'Count = 2 before clear');

    LMap.Clear;
    Check(LMap.Count = 0, 'Count = 0 after clear');
    Check(not LMap.Contains(1), 'Key 1 cleared');
    Check(not LMap.Contains(2), 'Key 2 cleared');
  finally
    LMap.Free;
  end;
end;

begin
  WriteLn('=== NUMA HashMap Tests ===');
  WriteLn;

  TestNumaHashMapBasic;
  TestNumaHashMapInsert;
  TestNumaHashMapGetOrInsert;
  TestNumaHashMapGetOrUpdate;
  TestNumaHashMapReserve;
  TestNumaHashMapNodeCount;
  TestNumaHashMapClear;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed, %d total', [GPassCount, GFailCount, GTestCount]));

  if GFailCount > 0 then
    Halt(1);
end.
