program test_swiss_adapter;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashmap.swiss.adapter;

type
  TIntMap = specialize TSwissHashMap<Integer, Integer>;
  TStrMap = specialize TSwissHashMap<string, Integer>;
  IIntMap = specialize IHashMap<Integer, Integer>;

var
  T: TTestRunner;

procedure TestPutGet;
var M: TIntMap; v: Integer;
begin
  M := TIntMap.Create;
  try
    M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
    CheckEqual(Int64(3), Int64(M.GetCount), 'count');
    Check(M.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
    Check(M.TryGetValue(3, v), 'get 3'); CheckEqual(Int64(30), Int64(v), 'val 3');
    Check(not M.TryGetValue(99, v), 'miss');
  finally M.Free; end;
end;

procedure TestAdd;
var M: TIntMap;
begin
  M := TIntMap.Create;
  try
    Check(M.Add(1, 10), 'add new');
    Check(not M.Add(1, 99), 'add dup');
    CheckEqual(Int64(1), Int64(M.GetCount), 'count');
  finally M.Free; end;
end;

procedure TestAddOrAssign;
var M: TIntMap; v: Integer;
begin
  M := TIntMap.Create;
  try
    Check(M.AddOrAssign(1, 10), 'new');
    Check(not M.AddOrAssign(1, 99), 'update');
    M.TryGetValue(1, v);
    CheckEqual(Int64(99), Int64(v), 'updated val');
  finally M.Free; end;
end;

procedure TestRemove;
var M: TIntMap;
begin
  M := TIntMap.Create;
  try
    M.Put(1, 10); M.Put(2, 20);
    Check(M.Remove(1), 'remove existing');
    Check(not M.Remove(99), 'remove missing');
    CheckEqual(Int64(1), Int64(M.GetCount), 'count');
    Check(not M.ContainsKey(1), 'not contains');
  finally M.Free; end;
end;

procedure TestGet;
var M: TIntMap; v: Integer; raised: Boolean;
begin
  M := TIntMap.Create;
  try
    M.Put(1, 10);
    CheckEqual(Int64(10), Int64(M.Get(1)), 'get existing');
    raised := False;
    try M.Get(99); except raised := True; end;
    Check(raised, 'get missing raises');
  finally M.Free; end;
end;

procedure TestGetOrInsert;
var M: TIntMap; v: Integer;
begin
  M := TIntMap.Create;
  try
    v := M.GetOrInsert(1, 42);
    CheckEqual(Int64(42), Int64(v), 'new');
    M.Put(1, 100);
    v := M.GetOrInsert(1, 99);
    CheckEqual(Int64(100), Int64(v), 'existing');
  finally M.Free; end;
end;

procedure IncVal(var V: Integer);
begin Inc(V); end;

procedure TestModifyOrInsert;
var M: TIntMap; v: Integer;
begin
  M := TIntMap.Create;
  try
    M.ModifyOrInsert(1, @IncVal, 10);
    M.TryGetValue(1, v);
    CheckEqual(Int64(10), Int64(v), 'insert default');
    M.ModifyOrInsert(1, @IncVal, 10);
    M.TryGetValue(1, v);
    CheckEqual(Int64(11), Int64(v), 'modified');
  finally M.Free; end;
end;

procedure TestCapacityLoadFactor;
var M: TIntMap;
begin
  M := TIntMap.Create(100);
  try
    Check(M.GetCapacity >= 100, 'capacity >= requested');
    M.Put(1, 1);
    Check(M.GetLoadFactor > 0, 'load > 0');
    Check(M.GetLoadFactor < 1, 'load < 1');
  finally M.Free; end;
end;

procedure TestClear;
var M: TIntMap;
begin
  M := TIntMap.Create;
  try
    M.Put(1, 1); M.Put(2, 2); M.Put(3, 3);
    M.Clear;
    CheckEqual(Int64(0), Int64(M.GetCount), 'count');
    Check(not M.ContainsKey(1), 'not contains');
  finally M.Free; end;
end;

procedure TestStringKey;
var M: TStrMap; i, v: Integer; ok: Boolean;
begin
  M := TStrMap.Create;
  try
    for i := 0 to 99 do M.Put('key' + IntToStr(i), i);
    CheckEqual(Int64(100), Int64(M.GetCount), 'count');
    ok := True;
    for i := 0 to 99 do
      if not M.TryGetValue('key' + IntToStr(i), v) or (v <> i) then ok := False;
    Check(ok, 'all string keys correct');
  finally M.Free; end;
end;

procedure TestInterfaceRefCount;
var Map: IIntMap; v: Integer;
begin
  Map := TIntMap.Create;
  Map.Put(1, 10); Map.Put(2, 20);
  Check(Map.TryGetValue(1, v), 'get via interface');
  CheckEqual(Int64(10), Int64(v), 'val via interface');
  Map := nil;
  Check(True, 'no crash after nil');
end;

procedure TestGrow;
var M: TIntMap; i, v: Integer; ok: Boolean;
begin
  M := TIntMap.Create;
  try
    for i := 0 to 9999 do M.Put(i, i * 2);
    CheckEqual(Int64(10000), Int64(M.GetCount), 'count');
    ok := True;
    for i := 0 to 9999 do
      if not M.TryGetValue(i, v) or (v <> i * 2) then ok := False;
    Check(ok, 'all values after grow');
  finally M.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.swiss_adapter');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Add', @TestAdd);
  T.Run('AddOrAssign', @TestAddOrAssign);
  T.Run('Remove', @TestRemove);
  T.Run('Get (+ exception)', @TestGet);
  T.Run('GetOrInsert', @TestGetOrInsert);
  T.Run('ModifyOrInsert', @TestModifyOrInsert);
  T.Run('Capacity/LoadFactor', @TestCapacityLoadFactor);
  T.Run('Clear', @TestClear);
  T.Run('String key', @TestStringKey);
  T.Run('Interface refcount', @TestInterfaceRefCount);
  T.Run('Grow (10000)', @TestGrow);
  T.Summary;
end.
