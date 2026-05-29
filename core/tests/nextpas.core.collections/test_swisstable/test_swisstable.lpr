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

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Grow (10000 elements)', @TestGrow);
  T.Run('Remove + Reinsert', @TestRemoveReinsert);
  T.Run('String key', @TestStringKey);
  T.Run('Clear', @TestClear);
  T.Run('Prealloc', @TestPrealloc);
  T.Summary;
end.
