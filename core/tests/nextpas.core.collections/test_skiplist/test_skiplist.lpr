program test_skiplist;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.skiplist,
  leak_tracker;

type
  TIntSkipList = specialize TSkipList<Integer, Integer>;
  TStringSkipList = specialize TSkipList<AnsiString, Integer>;
  TDoubleSkipList = specialize TSkipList<Double, Integer>;
  TPointerSkipList = specialize TSkipList<Pointer, Integer>;
  TIntTrackedSkipList = specialize TSkipList<Integer, ITracked>;
  TTrackedIntSkipList = specialize TSkipList<ITracked, Integer>;

var
  T: TTestRunner;

function CompareTracked(const A, B: ITracked): SizeInt;
begin
  if A.GetId < B.GetId then
    Result := -1
  else if A.GetId > B.GetId then
    Result := 1
  else
    Result := 0;
end;

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

procedure TestDefaultComparerBuiltInKeyTypes;
var
  Strings: TStringSkipList;
  Doubles: TDoubleSkipList;
  Pointers: TPointerSkipList;
  SKey: AnsiString;
  DKey: Double;
  PKey, P1, P2, P3: Pointer;
  V: Integer;
begin
  Strings := TStringSkipList.Create;
  try
    Strings.Put('gamma', 30);
    Strings.Put('alpha', 10);
    Strings.Put('beta', 20);
    Check(Strings.Min(SKey, V), 'string min');
    Check(SKey = 'alpha', 'string min key');
    CheckEqual(Int64(10), Int64(V), 'string min value');
    Check(Strings.Max(SKey, V), 'string max');
    Check(SKey = 'gamma', 'string max key');
  finally
    Strings.Free;
  end;

  Doubles := TDoubleSkipList.Create;
  try
    Doubles.Put(2.5, 25);
    Doubles.Put(-1.0, -10);
    Doubles.Put(4.25, 42);
    Check(Doubles.TryGetValue(2.5, V), 'double get');
    CheckEqual(Int64(25), Int64(V), 'double get value');
    Check(Doubles.Min(DKey, V), 'double min');
    Check(DKey = -1.0, 'double min key');
    Check(Doubles.Max(DKey, V), 'double max');
    Check(DKey = 4.25, 'double max key');
  finally
    Doubles.Free;
  end;

  Pointers := TPointerSkipList.Create;
  try
    P1 := Pointer(PtrUInt($10));
    P2 := Pointer(PtrUInt($20));
    P3 := Pointer(PtrUInt($30));
    Pointers.Put(P2, 20);
    Pointers.Put(P1, 10);
    Pointers.Put(P3, 30);
    Check(Pointers.TryGetValue(P2, V), 'pointer get');
    CheckEqual(Int64(20), Int64(V), 'pointer get value');
    Check(Pointers.Min(PKey, V), 'pointer min');
    Check(PtrUInt(PKey) = PtrUInt(P1), 'pointer min key');
    Check(Pointers.Max(PKey, V), 'pointer max');
    Check(PtrUInt(PKey) = PtrUInt(P3), 'pointer max key');
  finally
    Pointers.Free;
  end;
end;

procedure TestManagedValueOverwriteRemoveClear;
var
  LS: TIntTrackedSkipList;
  Snap: TLeakSnapshot;
  V: ITracked;
begin
  Snap := SnapTake;
  LS := TIntTrackedSkipList.Create;
  try
    V := MakeTracked(10);
    LS.Put(1, V);
    V := nil;

    V := MakeTracked(20);
    LS.Put(1, V);
    V := nil;

    V := MakeTracked(30);
    LS.Put(2, V);
    V := nil;

    Check(LS.Remove(1), 'remove overwritten managed value');
    LS.Clear;
    SnapAssert(Snap, 'SkipList managed value overwrite/remove/clear');
  finally
    LS.Free;
  end;
  SnapAssert(Snap, 'SkipList managed value overwrite/remove/free');
end;

procedure TestManagedKeyRemoveAndFree;
var
  LS: TTrackedIntSkipList;
  Snap: TLeakSnapshot;
  K, Lookup: ITracked;
begin
  Snap := SnapTake;
  LS := TTrackedIntSkipList.Create(@CompareTracked);
  try
    K := MakeTracked(10);
    LS.Put(K, 10);
    K := nil;

    K := MakeTracked(20);
    LS.Put(K, 20);
    K := nil;

    Lookup := MakeTracked(10);
    Check(LS.Remove(Lookup), 'remove managed key');
    Lookup := nil;

    LS.Clear;
    SnapAssert(Snap, 'SkipList managed key remove/clear');

    K := MakeTracked(30);
    LS.Put(K, 30);
    K := nil;
  finally
    LS.Free;
  end;
  SnapAssert(Snap, 'SkipList managed key remove/free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.skiplist');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Min/Max', @TestMinMax);
  T.Run('Grow (1000)', @TestGrow);
  T.Run('Clear', @TestClear);
  T.Run('Default comparer built-in key types', @TestDefaultComparerBuiltInKeyTypes);
  T.Run('Managed value overwrite/remove/clear', @TestManagedValueOverwriteRemoveClear);
  T.Run('Managed key remove/free', @TestManagedKeyRemoveAndFree);
  T.Summary;
end.
