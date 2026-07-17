program test_lockfree_multimap;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.multimap,
  nextpas.core.test;

type
  TIntMultiMap = specialize TLockFreeMultiMap<Int64, Int64>;

procedure TestMultiMapBasic;
var
  LMap: TIntMultiMap;
  LValues: array[0..9] of Int64;
  LCount: Integer;
begin
  LMap := TIntMultiMap.Create(16);
  try
    // Empty map
    Check(LMap.IsEmpty, 'Map should be empty');
    Check(not LMap.IsClosed, 'Map should not be closed');
    CheckEqual(PtrUInt(0), LMap.Count);
    CheckEqual(PtrUInt(0), LMap.KeyCount);

    // Add one key-value pair
    Check(LMap.Add(1, 10) = mmAdded, 'Should add pair');
    Check(not LMap.IsEmpty, 'Map should not be empty');
    CheckEqual(PtrUInt(1), LMap.Count);
    CheckEqual(PtrUInt(1), LMap.KeyCount);

    // Add another value to same key
    Check(LMap.Add(1, 20) = mmAdded, 'Should add second value');
    CheckEqual(PtrUInt(2), LMap.Count);
    CheckEqual(PtrUInt(1), LMap.KeyCount);

    // Find values for key
    LCount := LMap.Find(1, LValues);
    CheckEqual(2, LCount);
    CheckEqual(Int64(10), LValues[0]);
    CheckEqual(Int64(20), LValues[1]);

    // Contains key
    Check(LMap.Contains(1), 'Should contain key 1');
    Check(not LMap.Contains(2), 'Should not contain key 2');

    // Remove key
    Check(LMap.Remove(1), 'Should remove key 1');
    Check(not LMap.Contains(1), 'Should not contain key 1 after removal');
    CheckEqual(PtrUInt(0), LMap.Count);
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapMultipleKeys;
var
  LMap: TIntMultiMap;
begin
  LMap := TIntMultiMap.Create(16);
  try
    // Add multiple keys
    LMap.Add(1, 10);
    LMap.Add(2, 20);
    LMap.Add(3, 30);

    CheckEqual(PtrUInt(3), LMap.Count);
    CheckEqual(PtrUInt(3), LMap.KeyCount);

    // Contains all keys
    Check(LMap.Contains(1), 'Should contain key 1');
    Check(LMap.Contains(2), 'Should contain key 2');
    Check(LMap.Contains(3), 'Should contain key 3');

    // Remove middle key
    Check(LMap.Remove(2), 'Should remove key 2');
    Check(not LMap.Contains(2), 'Should not contain key 2');
    CheckEqual(PtrUInt(2), LMap.Count);
    CheckEqual(PtrUInt(2), LMap.KeyCount);
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapRemoveValue;
var
  LMap: TIntMultiMap;
  LValues: array[0..9] of Int64;
  LCount: Integer;
begin
  LMap := TIntMultiMap.Create(16);
  try
    // Add multiple values to same key
    LMap.Add(1, 10);
    LMap.Add(1, 20);
    LMap.Add(1, 30);

    CheckEqual(PtrUInt(3), LMap.Count);

    // Remove specific value
    Check(LMap.RemoveValue(1, 20), 'Should remove value 20');
    CheckEqual(PtrUInt(2), LMap.Count);

    // Verify remaining values
    LCount := LMap.Find(1, LValues);
    CheckEqual(2, LCount);
    CheckEqual(Int64(10), LValues[0]);
    CheckEqual(Int64(30), LValues[1]);

    // Remove non-existent value
    Check(not LMap.RemoveValue(1, 20), 'Should not find value 20');
    Check(not LMap.RemoveValue(2, 10), 'Should not find key 2');
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapRemoveLastValueRemovesKey;
var
  LMap: TIntMultiMap;
begin
  LMap := TIntMultiMap.Create(4);
  try
    Check(LMap.Add(1, 10) = mmAdded, 'Should add the only value');
    Check(LMap.RemoveValue(1, 10), 'Should remove the only value');
    Check(not LMap.Contains(1), 'Removing the last value removes the key');
    CheckEqual(PtrUInt(0), LMap.Count);
    CheckEqual(PtrUInt(0), LMap.KeyCount);

    Check(LMap.Add(5, 50) = mmAdded, 'Cluster remains reusable after last-value removal');
    Check(LMap.Contains(5), 'Reinserted key remains findable');
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapClear;
var
  LMap: TIntMultiMap;
begin
  LMap := TIntMultiMap.Create(16);
  try
    LMap.Add(1, 10);
    LMap.Add(2, 20);
    LMap.Add(3, 30);

    CheckEqual(PtrUInt(3), LMap.Count);

    // Clear all
    LMap.Clear;

    Check(LMap.IsEmpty, 'Map should be empty');
    CheckEqual(PtrUInt(0), LMap.Count);
    Check(not LMap.Contains(1), 'Should not contain key 1');
    Check(not LMap.Contains(2), 'Should not contain key 2');
    Check(not LMap.Contains(3), 'Should not contain key 3');
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapClose;
var
  LMap: TIntMultiMap;
begin
  LMap := TIntMultiMap.Create(16);
  try
    LMap.Add(1, 10);

    // Close map
    LMap.Close;
    Check(LMap.IsClosed, 'Map should be closed');

    // Can still read
    Check(LMap.Contains(1), 'Should still contain key 1');

    // Cannot add after close
    Check(LMap.Add(2, 20) = mmClosed, 'Should not add after close');
  finally
    LMap.Free;
  end;
end;

procedure TestMultiMapDuplicateKeys;
var
  LMap: TIntMultiMap;
  LValues: array[0..9] of Int64;
  LCount: Integer;
  I: Integer;
begin
  LMap := TIntMultiMap.Create(16);
  try
    // Add multiple values to same key
    for I := 1 to 5 do
      Check(LMap.Add(42, I * 10) = mmAdded, 'Should add value');

    CheckEqual(PtrUInt(5), LMap.Count);
    CheckEqual(PtrUInt(1), LMap.KeyCount);

    // Find all values
    LCount := LMap.Find(42, LValues);
    CheckEqual(5, LCount);
    for I := 0 to 4 do
      CheckEqual(Int64((I + 1) * 10), LValues[I]);
  finally
    LMap.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_multimap ===');
  WriteLn;

  TestMultiMapBasic;
  WriteLn('  + Basic add/find/remove');

  TestMultiMapMultipleKeys;
  WriteLn('  + Multiple keys');

  TestMultiMapRemoveValue;
  WriteLn('  + Remove specific value');

  TestMultiMapRemoveLastValueRemovesKey;
  WriteLn('  + Remove last value removes key');

  TestMultiMapClear;
  WriteLn('  + Clear');

  TestMultiMapClose;
  WriteLn('  + Close semantics');

  TestMultiMapDuplicateKeys;
  WriteLn('  + Duplicate keys');

  WriteLn;
  WriteLn('All multimap tests passed!');
end.
