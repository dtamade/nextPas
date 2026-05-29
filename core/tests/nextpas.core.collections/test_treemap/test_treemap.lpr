program test_treemap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.treemap;

type
  TIntTreeMap = specialize TTreeMap<Integer, Integer>;

function CompareInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

var
  T: TTestRunner;

procedure TestPutGet;
var LM: TIntTreeMap; v: Integer;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    LM.Put(5, 50); LM.Put(1, 10); LM.Put(9, 90);
    Check(LM.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
    Check(LM.TryGetValue(5, v), 'get 5'); CheckEqual(Int64(50), Int64(v), 'val 5');
    Check(LM.TryGetValue(9, v), 'get 9'); CheckEqual(Int64(90), Int64(v), 'val 9');
    Check(not LM.TryGetValue(99, v), 'miss');
    CheckEqual(Int64(3), Int64(LM.Count), 'count');
  finally LM.Free; end;
end;

procedure TestUpdate;
var LM: TIntTreeMap; v: Integer;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    LM.Put(1, 10); LM.Put(1, 99);
    CheckEqual(Int64(1), Int64(LM.Count), 'count');
    Check(LM.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated');
  finally LM.Free; end;
end;

procedure TestRemove;
var LM: TIntTreeMap;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    LM.Put(1, 10); LM.Put(2, 20); LM.Put(3, 30);
    Check(LM.Remove(2), 'remove 2');
    Check(not LM.ContainsKey(2), 'not contains 2');
    Check(LM.ContainsKey(1), 'still 1');
    Check(LM.ContainsKey(3), 'still 3');
    CheckEqual(Int64(2), Int64(LM.Count), 'count');
  finally LM.Free; end;
end;

procedure TestOrderedOps;
var LM: TIntTreeMap; v: Integer;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    LM.Put(10, 100); LM.Put(20, 200); LM.Put(30, 300); LM.Put(40, 400);
    Check(LM.GetLowerBound(25, v), 'lower bound 25');
    CheckEqual(Int64(300), Int64(v), 'lb val (first >= 25 is key 30)');
    Check(LM.GetUpperBound(25, v), 'upper bound 25');
    CheckEqual(Int64(300), Int64(v), 'ub val (first > 25 is key 30)');
  finally LM.Free; end;
end;

procedure TestGrow;
var LM: TIntTreeMap; i, v: Integer; ok: Boolean;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    for i := 0 to 999 do LM.Put(i, i * 2);
    CheckEqual(Int64(1000), Int64(LM.Count), 'count');
    ok := True;
    for i := 0 to 999 do
      if not LM.TryGetValue(i, v) or (v <> i * 2) then ok := False;
    Check(ok, 'all values');
  finally LM.Free; end;
end;

procedure TestClear;
var LM: TIntTreeMap;
begin
  LM := TIntTreeMap.Create(nil, @CompareInt);
  try
    LM.Put(1, 1); LM.Put(2, 2);
    LM.Clear;
    CheckEqual(Int64(0), Int64(LM.Count), 'count after clear');
    LM.Put(3, 3);
    CheckEqual(Int64(1), Int64(LM.Count), 'usable after clear');
  finally LM.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.treemap');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Ordered ops (LowerBound/UpperBound)', @TestOrderedOps);
  T.Run('Grow (1000)', @TestGrow);
  T.Run('Clear', @TestClear);
  T.Summary;
end.
