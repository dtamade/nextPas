program test_hashmap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap;

type
  TIntIntMap = specialize THashMap<Integer, Integer>;
  TStrIntMap = specialize THashMap<string, Integer>;

var
  T: TTestRunner;

procedure TestPutGet;
var
  LMap: TIntIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put(1, 100);
  LMap.Put(2, 200);
  LMap.Put(3, 300);

  Check(LMap.Get(1, LVal), 'get key 1');
  CheckEqual(Int64(100), Int64(LVal), 'value 1');
  Check(LMap.Get(2, LVal), 'get key 2');
  CheckEqual(Int64(200), Int64(LVal), 'value 2');
  Check(LMap.Get(3, LVal), 'get key 3');
  CheckEqual(Int64(300), Int64(LVal), 'value 3');
  Check(not LMap.Get(99, LVal), 'missing key');

  LMap.Done;
end;

procedure TestContains;
var
  LMap: TIntIntMap;
begin
  LMap.Init;
  LMap.Put(42, 1);

  Check(LMap.Contains(42), 'contains existing');
  Check(not LMap.Contains(99), 'not contains missing');

  LMap.Done;
end;

procedure TestRemove;
var
  LMap: TIntIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Put(3, 30);

  Check(LMap.Remove(2), 'remove existing');
  Check(not LMap.Contains(2), 'removed key gone');
  Check(not LMap.Get(2, LVal), 'get removed returns false');
  CheckEqual(Int64(2), Int64(LMap.Count), 'count after remove');

  Check(not LMap.Remove(99), 'remove missing');

  Check(LMap.Get(1, LVal), 'other keys intact 1');
  CheckEqual(Int64(10), Int64(LVal), 'value intact 1');
  Check(LMap.Get(3, LVal), 'other keys intact 3');
  CheckEqual(Int64(30), Int64(LVal), 'value intact 3');

  LMap.Done;
end;

procedure TestOverwrite;
var
  LMap: TIntIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put(1, 100);
  LMap.Put(1, 999);

  CheckEqual(Int64(1), Int64(LMap.Count), 'count stays 1');
  Check(LMap.Get(1, LVal), 'get overwritten');
  CheckEqual(Int64(999), Int64(LVal), 'new value');

  LMap.Done;
end;

procedure TestRehash;
var
  LMap: TIntIntMap;
  LVal: Integer;
  LIdx: Integer;
begin
  LMap.Init;
  for LIdx := 0 to 99 do
    LMap.Put(LIdx, LIdx * 10);

  CheckEqual(Int64(100), Int64(LMap.Count), 'count after 100 inserts');

  for LIdx := 0 to 99 do
  begin
    Check(LMap.Get(LIdx, LVal), 'get after rehash ' + IntToStr(LIdx));
    CheckEqual(Int64(LIdx * 10), Int64(LVal), 'value after rehash');
  end;

  LMap.Done;
end;

procedure TestStringKey;
var
  LMap: TStrIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put('hello', 1);
  LMap.Put('world', 2);
  LMap.Put('foo', 3);

  Check(LMap.Get('hello', LVal), 'get hello');
  CheckEqual(Int64(1), Int64(LVal), 'value hello');
  Check(LMap.Get('world', LVal), 'get world');
  CheckEqual(Int64(2), Int64(LVal), 'value world');
  Check(not LMap.Get('missing', LVal), 'missing string key');

  LMap.Done;
end;

procedure TestRemoveThenInsert;
var
  LMap: TIntIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Remove(1);
  LMap.Put(1, 99);

  Check(LMap.Get(1, LVal), 'get re-inserted');
  CheckEqual(Int64(99), Int64(LVal), 're-inserted value');
  CheckEqual(Int64(2), Int64(LMap.Count), 'count correct');

  LMap.Done;
end;

procedure TestClear;
var
  LMap: TIntIntMap;
  LVal: Integer;
begin
  LMap.Init;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Clear;

  Check(LMap.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LMap.Count), 'count 0');
  Check(not LMap.Get(1, LVal), 'cleared key gone');

  LMap.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.hashmap');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Contains', @TestContains);
  T.Run('Remove', @TestRemove);
  T.Run('Overwrite', @TestOverwrite);
  T.Run('Rehash (100 inserts)', @TestRehash);
  T.Run('String key', @TestStringKey);
  T.Run('Remove then insert (tombstone reuse)', @TestRemoveThenInsert);
  T.Run('Clear', @TestClear);
  T.Summary;
end.
