program test_hashmap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashmap;

type
  IIntIntMap = specialize IHashMap<Integer, Integer>;
  TIntIntMap = specialize THashMap<Integer, Integer>;
  IStrIntMap = specialize IHashMap<string, Integer>;
  TStrIntMap = specialize THashMap<string, Integer>;

var
  T: TTestRunner;

procedure TestPutGet;
var
  LMap: IIntIntMap;
  LVal: Integer;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 100);
  LMap.Put(2, 200);
  LMap.Put(3, 300);

  CheckEqual(Int64(100), Int64(LMap.Get(1)), 'value 1');
  CheckEqual(Int64(200), Int64(LMap.Get(2)), 'value 2');
  CheckEqual(Int64(300), Int64(LMap.Get(3)), 'value 3');
  Check(not LMap.TryGetValue(99, LVal), 'missing key');
end;

procedure TestContains;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(42, 1);

  Check(LMap.ContainsKey(42), 'contains existing');
  Check(not LMap.ContainsKey(99), 'not contains missing');
end;

procedure TestRemove;
var
  LMap: IIntIntMap;
  LVal: Integer;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Put(3, 30);

  Check(LMap.Remove(2), 'remove existing');
  Check(not LMap.ContainsKey(2), 'removed key gone');
  Check(not LMap.TryGetValue(2, LVal), 'get removed returns false');
  CheckEqual(Int64(2), Int64(LMap.Count), 'count after remove');

  Check(not LMap.Remove(99), 'remove missing');

  CheckEqual(Int64(10), Int64(LMap.Get(1)), 'value intact 1');
  CheckEqual(Int64(30), Int64(LMap.Get(3)), 'value intact 3');
end;

procedure TestOverwrite;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 100);
  LMap.Put(1, 999);

  CheckEqual(Int64(1), Int64(LMap.Count), 'count stays 1');
  CheckEqual(Int64(999), Int64(LMap.Get(1)), 'new value');
end;

procedure TestRehash;
var
  LMap: IIntIntMap;
  LIdx: Integer;
begin
  LMap := TIntIntMap.Create;
  for LIdx := 0 to 99 do
    LMap.Put(LIdx, LIdx * 10);

  CheckEqual(Int64(100), Int64(LMap.Count), 'count after 100 inserts');

  for LIdx := 0 to 99 do
  begin
    CheckEqual(Int64(LIdx * 10), Int64(LMap.Get(LIdx)), 'value after rehash');
  end;
end;

procedure TestStringKey;
var
  LMap: IStrIntMap;
  LVal: Integer;
begin
  LMap := TStrIntMap.Create;
  LMap.Put('hello', 1);
  LMap.Put('world', 2);
  LMap.Put('foo', 3);

  CheckEqual(Int64(1), Int64(LMap.Get('hello')), 'value hello');
  CheckEqual(Int64(2), Int64(LMap.Get('world')), 'value world');
  Check(not LMap.TryGetValue('missing', LVal), 'missing string key');
end;

procedure TestRemoveThenInsert;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Remove(1);
  LMap.Put(1, 99);

  CheckEqual(Int64(99), Int64(LMap.Get(1)), 're-inserted value');
  CheckEqual(Int64(2), Int64(LMap.Count), 'count correct');
end;

procedure TestClear;
var
  LMap: IIntIntMap;
  LVal: Integer;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 10);
  LMap.Put(2, 20);
  LMap.Clear;

  Check(LMap.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LMap.Count), 'count 0');
  Check(not LMap.TryGetValue(1, LVal), 'cleared key gone');
end;

procedure TestGetOrInsert;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 42);

  CheckEqual(Int64(42), Int64(LMap.GetOrInsert(1, 0)), 'existing key');
  CheckEqual(Int64(-1), Int64(LMap.GetOrInsert(99, -1)), 'missing key inserted');
  CheckEqual(Int64(2), Int64(LMap.Count), 'missing insert increments count');
end;

procedure TestAddOnly;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  Check(LMap.Add(1, 100), 'add new key');
  Check(not LMap.Add(1, 200), 'add existing key fails');
  CheckEqual(Int64(100), Int64(LMap.Get(1)), 'value unchanged');
end;

procedure TestAddOrAssign;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  Check(LMap.AddOrAssign(1, 100), 'addorassign new');
  Check(not LMap.AddOrAssign(1, 200), 'addorassign existing');
  CheckEqual(Int64(200), Int64(LMap.Get(1)), 'value updated');
end;

procedure TestTryGetValue;
var
  LMap: IIntIntMap;
  LVal: Integer;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(5, 50);
  Check(LMap.TryGetValue(5, LVal), 'tryget existing');
  CheckEqual(Int64(50), Int64(LVal), 'tryget value');
  Check(not LMap.TryGetValue(99, LVal), 'tryget missing');
end;

procedure TestLoadFactor;
var
  LMap: IIntIntMap;
  LI: Integer;
begin
  LMap := TIntIntMap.Create;
  Check(LMap.LoadFactor = 0.0, 'empty load factor');
  for LI := 0 to 3 do
    LMap.Put(LI, LI);
  Check(LMap.LoadFactor > 0.0, 'non-zero load factor');
  Check(LMap.LoadFactor <= 1.0, 'load factor <= 1');
end;

procedure TestTombstoneRehash;
var
  LMap: IIntIntMap;
  LI: Integer;
begin
  LMap := TIntIntMap.Create;
  for LI := 0 to 49 do
    LMap.Put(LI, LI);
  for LI := 0 to 49 do
    LMap.Remove(LI);
  CheckEqual(Int64(0), Int64(LMap.Count), 'all removed');
  for LI := 100 to 149 do
    LMap.Put(LI, LI * 2);
  CheckEqual(Int64(50), Int64(LMap.Count), 'reinserted count');
  for LI := 100 to 149 do
  begin
    CheckEqual(Int64(LI * 2), Int64(LMap.Get(LI)), 'value correct');
  end;
end;

procedure TestAutoFree;
var
  LMap: IIntIntMap;
begin
  LMap := TIntIntMap.Create;
  LMap.Put(1, 100);
  LMap := nil;
  Check(True);
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
  T.Run('GetOrInsert', @TestGetOrInsert);
  T.Run('Add (no overwrite)', @TestAddOnly);
  T.Run('AddOrAssign', @TestAddOrAssign);
  T.Run('TryGetValue', @TestTryGetValue);
  T.Run('LoadFactor', @TestLoadFactor);
  T.Run('Tombstone rehash', @TestTombstoneRehash);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Summary;
end.
