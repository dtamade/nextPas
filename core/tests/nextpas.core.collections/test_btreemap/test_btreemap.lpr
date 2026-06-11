program test_btreemap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree;

type
  TIntBTree = specialize TBTreeMap<Integer, Integer>;
  TStrBTree = specialize TBTreeMap<string, Integer>;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

function CmpStr(const A, B: string; aData: Pointer): SizeInt;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

var
  T: TTestRunner;

procedure TestPutGet;
var M: TIntBTree; v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(5, 50); M.Put(1, 10); M.Put(9, 90); M.Put(3, 30);
    CheckEqual(Int64(4), Int64(M.Count), 'count');
    Check(M.TryGetValue(1, v), 'get 1'); CheckEqual(Int64(10), Int64(v), 'val 1');
    Check(M.TryGetValue(9, v), 'get 9'); CheckEqual(Int64(90), Int64(v), 'val 9');
    Check(not M.TryGetValue(99, v), 'miss');
  finally M.Free; end;
end;

procedure TestUpdate;
var M: TIntBTree; v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(1, 10); M.Put(1, 99);
    CheckEqual(Int64(1), Int64(M.Count), 'count');
    Check(M.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated');
  finally M.Free; end;
end;

procedure TestRemove;
var M: TIntBTree;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(1, 10); M.Put(2, 20); M.Put(3, 30); M.Put(4, 40); M.Put(5, 50);
    M.Remove(3);
    CheckEqual(Int64(4), Int64(M.Count), 'count after remove');
    Check(not M.ContainsKey(3), 'not contains 3');
    Check(M.ContainsKey(1), 'still 1');
    Check(M.ContainsKey(5), 'still 5');
  finally M.Free; end;
end;

procedure TestMinMax;
var M: TIntBTree; k, v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(50, 500); M.Put(10, 100); M.Put(90, 900); M.Put(30, 300);
    Check(M.Min(k, v), 'min'); CheckEqual(Int64(10), Int64(k), 'min key');
    Check(M.Max(k, v), 'max'); CheckEqual(Int64(90), Int64(k), 'max key');
  finally M.Free; end;
end;

procedure TestGrow;
var M: TIntBTree; i, v: Integer; ok: Boolean;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 9999 do M.Put(i, i * 2);
    CheckEqual(Int64(10000), Int64(M.Count), 'count');
    ok := True;
    for i := 0 to 9999 do
      if not M.TryGetValue(i, v) or (v <> i * 2) then ok := False;
    Check(ok, 'all values');
  finally M.Free; end;
end;

procedure TestRemoveStress;
var M: TIntBTree; i: Integer; ok: Boolean;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 999 do M.Put(i, i);
    for i := 0 to 499 do M.Remove(i * 2);
    CheckEqual(Int64(500), Int64(M.Count), 'count after remove');
    ok := True;
    for i := 0 to 499 do
      if not M.ContainsKey(i * 2 + 1) then ok := False;
    Check(ok, 'odd keys remain');
    ok := True;
    for i := 0 to 499 do
      if M.ContainsKey(i * 2) then ok := False;
    Check(ok, 'even keys gone');
  finally M.Free; end;
end;

procedure TestStringKey;
var M: TStrBTree; i, v: Integer; ok: Boolean;
begin
  M := TStrBTree.Create(@CmpStr);
  try
    for i := 0 to 99 do M.Put('key' + IntToStr(i), i);
    CheckEqual(Int64(100), Int64(M.Count), 'count');
    ok := True;
    for i := 0 to 99 do
      if not M.TryGetValue('key' + IntToStr(i), v) or (v <> i) then ok := False;
    Check(ok, 'string keys correct');
    M.Remove('key50');
    Check(not M.ContainsKey('key50'), 'removed');
    CheckEqual(Int64(99), Int64(M.Count), 'count after remove');
  finally M.Free; end;
end;

procedure TestClear;
var M: TIntBTree;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(1, 1); M.Put(2, 2); M.Put(3, 3);
    M.Clear;
    CheckEqual(Int64(0), Int64(M.Count), 'count after clear');
    Check(not M.ContainsKey(1), 'not contains');
    M.Put(99, 99);
    CheckEqual(Int64(1), Int64(M.Count), 'usable after clear');
  finally M.Free; end;
end;

var
  GForEachSum: Int64;
  GForEachCount: Integer;

procedure ForEachCb(const AKey: Integer; const AValue: Integer; aData: Pointer);
begin
  Inc(GForEachSum, AKey);
  Inc(GForEachCount);
end;

procedure TestLowerBound;
var M: TIntBTree; k, v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(10, 1); M.Put(20, 2); M.Put(30, 3); M.Put(40, 4); M.Put(50, 5);
    Check(M.LowerBound(25, k, v), 'lb 25'); CheckEqual(Int64(30), Int64(k), 'lb 25 key');
    Check(M.LowerBound(30, k, v), 'lb 30'); CheckEqual(Int64(30), Int64(k), 'lb 30 key');
    Check(M.LowerBound(10, k, v), 'lb 10'); CheckEqual(Int64(10), Int64(k), 'lb 10 key');
    Check(not M.LowerBound(51, k, v), 'lb 51 not found');
  finally M.Free; end;
end;

procedure TestUpperBound;
var M: TIntBTree; k, v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(10, 1); M.Put(20, 2); M.Put(30, 3); M.Put(40, 4); M.Put(50, 5);
    Check(M.UpperBound(30, k, v), 'ub 30'); CheckEqual(Int64(40), Int64(k), 'ub 30 key');
    Check(M.UpperBound(9, k, v), 'ub 9'); CheckEqual(Int64(10), Int64(k), 'ub 9 key');
    Check(not M.UpperBound(50, k, v), 'ub 50 not found');
  finally M.Free; end;
end;

procedure TestForEach;
var M: TIntBTree; i: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 99 do M.Put(i, i);
    GForEachSum := 0; GForEachCount := 0;
    M.ForEach(@ForEachCb);
    CheckEqual(Int64(100), Int64(GForEachCount), 'count');
    CheckEqual(Int64(4950), GForEachSum, 'sum');
  finally M.Free; end;
end;

procedure TestRange;
var M: TIntBTree; i: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 99 do M.Put(i * 10, i);
    GForEachSum := 0; GForEachCount := 0;
    M.Range(200, 500, @ForEachCb);
    CheckEqual(Int64(31), Int64(GForEachCount), 'range count');
    CheckEqual(Int64(10850), GForEachSum, 'range sum');
  finally M.Free; end;
end;

procedure TestFloor;
var M: TIntBTree; k, v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    M.Put(10, 1); M.Put(20, 2); M.Put(30, 3); M.Put(40, 4); M.Put(50, 5);
    Check(M.Floor(25, k, v), 'floor 25'); CheckEqual(Int64(20), Int64(k), 'floor 25 key');
    Check(M.Floor(30, k, v), 'floor 30'); CheckEqual(Int64(30), Int64(k), 'floor 30 key');
    Check(M.Floor(55, k, v), 'floor 55'); CheckEqual(Int64(50), Int64(k), 'floor 55 key');
    Check(not M.Floor(5, k, v), 'floor 5 not found');
  finally M.Free; end;
end;

procedure TestRank;
var M: TIntBTree; i: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 99 do M.Put(i * 10, i);
    CheckEqual(Int64(0), Int64(M.Rank(0)), 'rank 0');
    CheckEqual(Int64(1), Int64(M.Rank(10)), 'rank 10');
    CheckEqual(Int64(5), Int64(M.Rank(50)), 'rank 50');
    CheckEqual(Int64(99), Int64(M.Rank(990)), 'rank 990');
  finally M.Free; end;
end;

procedure TestRankInternalSeparatorKey;
var
  M: TIntBTree;
  I, K, V: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for I := 0 to 31 do
      M.Put(I, I * 10);

    Check(M.Select(15, K, V), 'select separator rank');
    CheckEqual(Int64(15), Int64(K), 'select separator key');
    CheckEqual(Int64(15), Int64(M.Rank(15)), 'rank internal separator key');
  finally
    M.Free;
  end;
end;

procedure TestEnumerator;
var M: TIntBTree; E: TIntBTree.TEntry; i, prev, count: Integer; sorted: Boolean;
begin
  M := TIntBTree.Create(@CmpInt);
  try
    for i := 0 to 99 do M.Put((i * 7919) mod 100, i);
    count := 0; prev := -1; sorted := True;
    for E in M do
    begin
      if E.Key <= prev then sorted := False;
      prev := E.Key;
      Inc(count);
    end;
    CheckEqual(Int64(100), Int64(count), 'enum count');
    Check(sorted, 'enum sorted');
  finally M.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btreemap');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('Min/Max', @TestMinMax);
  T.Run('Grow (10000)', @TestGrow);
  T.Run('Remove stress (1000)', @TestRemoveStress);
  T.Run('String key', @TestStringKey);
  T.Run('Clear', @TestClear);
  T.Run('LowerBound', @TestLowerBound);
  T.Run('UpperBound', @TestUpperBound);
  T.Run('ForEach', @TestForEach);
  T.Run('Range', @TestRange);
  T.Run('Floor', @TestFloor);
  T.Run('Rank', @TestRank);
  T.Run('Rank internal separator key', @TestRankInternalSeparatorKey);
  T.Run('Enumerator (for-in)', @TestEnumerator);
  T.Summary;
end.
