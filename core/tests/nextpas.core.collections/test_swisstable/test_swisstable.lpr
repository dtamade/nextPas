program test_swisstable;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.swiss;

type
  TIntSwiss = specialize TSwissTable<Integer, Integer>;
  TStrSwiss = specialize TSwissTable<string, Integer>;

var
  T: TTestRunner;

function HashFirstSwissGroup(const AKey: Integer): UInt32;
begin
  Result := UInt32(AKey and $7F);
end;

procedure TestPutGet;
var M: TIntSwiss; v: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  CheckEqual(Int64(3), Int64(M.Count), 'count');
  Check(M.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
  Check(M.TryGetValue(2, v), 'get 2'); CheckEqual(Int64(20), Int64(v), 'val 2');
  Check(M.TryGetValue(3, v), 'get 3'); CheckEqual(Int64(30), Int64(v), 'val 3');
  Check(not M.TryGetValue(99, v), 'miss');
  M.Free;
end;

procedure TestUpdate;
var M: TIntSwiss; v: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10);
  M.Put(1, 99);
  CheckEqual(Int64(1), Int64(M.Count), 'count after update');
  Check(M.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated val');
  M.Free;
end;

procedure TestRemove;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  Check(M.Remove(2), 'remove 2');
  CheckEqual(Int64(2), Int64(M.Count), 'count after remove');
  Check(not M.ContainsKey(2), 'not contains 2');
  Check(M.ContainsKey(1), 'still contains 1');
  Check(M.ContainsKey(3), 'still contains 3');
  M.Free;
end;

procedure TestGrow;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create;
  for i := 0 to 9999 do M.Put(i, i * 2);
  CheckEqual(Int64(10000), Int64(M.Count), 'count 10000');
  ok := True;
  for i := 0 to 9999 do
    if not M.TryGetValue(i, v) or (v <> i * 2) then ok := False;
  Check(ok, 'all values correct');
  M.Free;
end;

procedure TestRemoveReinsert;
var M: TIntSwiss; i, v: Integer;
begin
  M := TIntSwiss.Create;
  for i := 0 to 999 do M.Put(i, i);
  for i := 0 to 499 do M.Remove(i * 2);
  CheckEqual(Int64(500), Int64(M.Count), 'count after remove');
  for i := 0 to 499 do M.Put(i * 2, i * 2 + 1000);
  CheckEqual(Int64(1000), Int64(M.Count), 'count after reinsert');
  Check(M.TryGetValue(0, v), 'get 0'); CheckEqual(Int64(1000), Int64(v), 'reinserted val');
  M.Free;
end;

procedure TestDeletedSlotReuseKeepsStableCapacity;
var
  M: TIntSwiss;
  I: Integer;
  InitialCapacity: SizeUInt;
begin
  M := TIntSwiss.Create(GROUP_SIZE * 4, @HashFirstSwissGroup);
  try
    for I := 0 to GROUP_SIZE - 1 do
      M.Put(I, I);

    InitialCapacity := M.Capacity;

    for I := 1 to Integer(InitialCapacity) do
    begin
      Check(M.Remove(0), 'remove churn key');
      M.Put(0, I);
      CheckEqual(Int64(GROUP_SIZE), Int64(M.Count), 'stable count');
    end;

    CheckEqual(Int64(InitialCapacity), Int64(M.Capacity),
      'deleted slot reuse keeps capacity stable');
  finally
    M.Free;
  end;
end;

procedure TestStringKey;
var M: TStrSwiss; i, v: Integer; ok: Boolean;
begin
  M := TStrSwiss.Create;
  for i := 0 to 999 do M.Put('key' + IntToStr(i), i);
  CheckEqual(Int64(1000), Int64(M.Count), 'str count');
  ok := True;
  for i := 0 to 999 do
    if not M.TryGetValue('key' + IntToStr(i), v) or (v <> i) then ok := False;
  Check(ok, 'str values correct');
  Check(not M.ContainsKey('nope'), 'str miss');
  M.Remove('key500');
  CheckEqual(Int64(999), Int64(M.Count), 'str count after remove');
  M.Free;
end;

procedure TestClear;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 1); M.Put(2, 2);
  M.Clear;
  CheckEqual(Int64(0), Int64(M.Count), 'count after clear');
  Check(not M.ContainsKey(1), 'not contains after clear');
  M.Put(3, 3);
  CheckEqual(Int64(1), Int64(M.Count), 'usable after clear');
  M.Free;
end;

procedure TestPrealloc;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create(10000);
  for i := 0 to 9999 do M.Put(i, i);
  CheckEqual(Int64(10000), Int64(M.Count), 'prealloc count');
  ok := True;
  for i := 0 to 9999 do
    if not M.TryGetValue(i, v) or (v <> i) then ok := False;
  Check(ok, 'prealloc values');
  M.Free;
end;

function KeepOdd(const AKey: Integer; const AValue: Integer): Boolean;
begin
  Result := (AKey mod 2) = 1;
end;

procedure TestRetain;
var M: TIntSwiss; i: Integer;
begin
  M := TIntSwiss.Create;
  for i := 0 to 99 do M.Put(i, i);
  M.Retain(@KeepOdd);
  CheckEqual(Int64(50), Int64(M.Count), 'retain count');
  Check(M.ContainsKey(1), 'has odd');
  Check(not M.ContainsKey(0), 'no even');
  M.Free;
end;

var GDrainSum: Int64;

procedure DrainVisit(const AKey: Integer; const AValue: Integer);
begin
  Inc(GDrainSum, AKey);
end;

procedure TestDrain;
var M: TIntSwiss;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  GDrainSum := 0;
  M.Drain(@DrainVisit);
  CheckEqual(Int64(6), GDrainSum, 'drain sum');
  CheckEqual(Int64(0), Int64(M.Count), 'empty after drain');
  M.Free;
end;

procedure TestReserve;
var M: TIntSwiss; i, v: Integer; ok: Boolean;
begin
  M := TIntSwiss.Create;
  M.Reserve(500);
  Check(M.Capacity >= 500, 'capacity after reserve');
  for i := 0 to 499 do M.Put(i, i);
  CheckEqual(Int64(500), Int64(M.Count), 'count');
  ok := True;
  for i := 0 to 499 do
    if not M.TryGetValue(i, v) or (v <> i) then ok := False;
  Check(ok, 'all values');
  M.Free;
end;

procedure TestForEachAndEnumerator;
var M: TIntSwiss; E: TIntSwiss.TSlot; sum: Int64; count: Integer;
begin
  M := TIntSwiss.Create;
  M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
  sum := 0; count := 0;
  for E in M do
  begin
    Inc(sum, E.Key);
    Inc(count);
  end;
  CheckEqual(Int64(3), Int64(count), 'enum count');
  CheckEqual(Int64(6), sum, 'enum sum');
  M.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Grow (10000 elements)', @TestGrow);
  T.Run('Remove + Reinsert', @TestRemoveReinsert);
  T.Run('Deleted slot reuse keeps stable capacity', @TestDeletedSlotReuseKeepsStableCapacity);
  T.Run('String key', @TestStringKey);
  T.Run('Clear', @TestClear);
  T.Run('Prealloc', @TestPrealloc);
  T.Run('Retain', @TestRetain);
  T.Run('Drain', @TestDrain);
  T.Run('Reserve', @TestReserve);
  T.Run('ForEach/Enumerator', @TestForEachAndEnumerator);
  T.Summary;
end.
