program test_skiplist;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.skiplist;

type
  TIntSkipList = specialize TSkipList<Integer, Integer>;

var
  T: TTestRunner;

procedure TestPutGet;
var LS: TIntSkipList; v: Integer;
begin
  LS := TIntSkipList.Create;
  try
    LS.Put(1, 10); LS.Put(2, 20); LS.Put(3, 30);
    Check(LS.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
    Check(LS.TryGetValue(2, v), 'get 2'); CheckEqual(Int64(20), Int64(v), 'val 2');
    Check(LS.TryGetValue(3, v), 'get 3'); CheckEqual(Int64(30), Int64(v), 'val 3');
    Check(not LS.TryGetValue(99, v), 'miss');
    CheckEqual(Int64(3), Int64(LS.Count), 'count');
  finally LS.Free; end;
end;

procedure TestUpdate;
var LS: TIntSkipList; v: Integer;
begin
  LS := TIntSkipList.Create;
  try
    LS.Put(1, 10); LS.Put(1, 99);
    CheckEqual(Int64(1), Int64(LS.Count), 'count after update');
    Check(LS.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated');
  finally LS.Free; end;
end;

procedure TestRemove;
var LS: TIntSkipList;
begin
  LS := TIntSkipList.Create;
  try
    LS.Put(1, 10); LS.Put(2, 20); LS.Put(3, 30);
    Check(LS.Remove(2), 'remove 2');
    Check(not LS.ContainsKey(2), 'not contains 2');
    CheckEqual(Int64(2), Int64(LS.Count), 'count');
  finally LS.Free; end;
end;

procedure TestMinMax;
var LS: TIntSkipList; k, v: Integer;
begin
  LS := TIntSkipList.Create;
  try
    LS.Put(5, 50); LS.Put(1, 10); LS.Put(9, 90); LS.Put(3, 30);
    Check(LS.Min(k, v), 'min'); CheckEqual(Int64(1), Int64(k), 'min key');
    Check(LS.Max(k, v), 'max'); CheckEqual(Int64(9), Int64(k), 'max key');
  finally LS.Free; end;
end;

procedure TestGrow;
var LS: TIntSkipList; i, v: Integer; ok: Boolean;
begin
  LS := TIntSkipList.Create;
  try
    for i := 0 to 999 do LS.Put(i, i * 2);
    CheckEqual(Int64(1000), Int64(LS.Count), 'count 1000');
    ok := True;
    for i := 0 to 999 do
      if not LS.TryGetValue(i, v) or (v <> i * 2) then ok := False;
    Check(ok, 'all values correct');
  finally LS.Free; end;
end;

procedure TestClear;
var LS: TIntSkipList;
begin
  LS := TIntSkipList.Create;
  try
    LS.Put(1, 1); LS.Put(2, 2);
    LS.Clear;
    CheckEqual(Int64(0), Int64(LS.Count), 'count after clear');
    Check(not LS.ContainsKey(1), 'not contains after clear');
    LS.Put(3, 3);
    CheckEqual(Int64(1), Int64(LS.Count), 'usable after clear');
  finally LS.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.skiplist');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Min/Max', @TestMinMax);
  T.Run('Grow (1000)', @TestGrow);
  T.Run('Clear', @TestClear);
  T.Summary;
end.
