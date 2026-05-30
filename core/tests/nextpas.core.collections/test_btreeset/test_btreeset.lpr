program test_btreeset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree;

type
  TIntSet = specialize TBTreeSet<Integer>;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

var
  T: TTestRunner;

procedure TestAddContains;
var S: TIntSet;
begin
  S := TIntSet.Create(@CmpInt);
  try
    Check(S.Add(5), 'add 5');
    Check(S.Add(3), 'add 3');
    Check(S.Add(7), 'add 7');
    Check(not S.Add(5), 'dup 5');
    CheckEqual(Int64(3), Int64(S.Count), 'count');
    Check(S.Contains(5), 'contains 5');
    Check(S.Contains(3), 'contains 3');
    Check(not S.Contains(99), 'not contains 99');
  finally S.Free; end;
end;

procedure TestRemove;
var S: TIntSet;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(1); S.Add(2); S.Add(3);
    Check(S.Remove(2), 'remove 2');
    Check(not S.Remove(99), 'remove missing');
    CheckEqual(Int64(2), Int64(S.Count), 'count');
    Check(not S.Contains(2), 'not contains 2');
  finally S.Free; end;
end;

procedure TestMinMax;
var S: TIntSet; v: Integer;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(50); S.Add(10); S.Add(90); S.Add(30);
    Check(S.Min(v), 'min'); CheckEqual(Int64(10), Int64(v), 'min val');
    Check(S.Max(v), 'max'); CheckEqual(Int64(90), Int64(v), 'max val');
  finally S.Free; end;
end;

procedure TestPopMinMax;
var S: TIntSet; v: Integer;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(10); S.Add(20); S.Add(30);
    Check(S.PopMin(v), 'popmin'); CheckEqual(Int64(10), Int64(v), 'popmin val');
    Check(S.PopMax(v), 'popmax'); CheckEqual(Int64(30), Int64(v), 'popmax val');
    CheckEqual(Int64(1), Int64(S.Count), 'count after pops');
    Check(S.Contains(20), 'still has 20');
  finally S.Free; end;
end;

procedure TestLowerUpperBound;
var S: TIntSet; v: Integer;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(10); S.Add(20); S.Add(30); S.Add(40); S.Add(50);
    Check(S.LowerBound(25, v), 'lb 25'); CheckEqual(Int64(30), Int64(v), 'lb 25 val');
    Check(S.LowerBound(30, v), 'lb 30'); CheckEqual(Int64(30), Int64(v), 'lb 30 val');
    Check(S.UpperBound(30, v), 'ub 30'); CheckEqual(Int64(40), Int64(v), 'ub 30 val');
    Check(not S.UpperBound(50, v), 'ub 50 none');
  finally S.Free; end;
end;

procedure TestFloor;
var S: TIntSet; v: Integer;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(10); S.Add(20); S.Add(30); S.Add(40); S.Add(50);
    Check(S.Floor(25, v), 'floor 25'); CheckEqual(Int64(20), Int64(v), 'floor 25 val');
    Check(S.Floor(30, v), 'floor 30'); CheckEqual(Int64(30), Int64(v), 'floor 30 val');
    Check(not S.Floor(5, v), 'floor 5 none');
  finally S.Free; end;
end;

procedure TestUnion;
var A, B: TIntSet;
begin
  A := TIntSet.Create(@CmpInt); B := TIntSet.Create(@CmpInt);
  try
    A.Add(1); A.Add(2); A.Add(3);
    B.Add(3); B.Add(4); B.Add(5);
    A.Union(B);
    CheckEqual(Int64(5), Int64(A.Count), 'union count');
    Check(A.Contains(1) and A.Contains(5), 'union has all');
  finally A.Free; B.Free; end;
end;

procedure TestIntersection;
var A, B: TIntSet;
begin
  A := TIntSet.Create(@CmpInt); B := TIntSet.Create(@CmpInt);
  try
    A.Add(1); A.Add(2); A.Add(3); A.Add(4);
    B.Add(2); B.Add(4); B.Add(6);
    A.Intersection(B);
    CheckEqual(Int64(2), Int64(A.Count), 'intersect count');
    Check(A.Contains(2) and A.Contains(4), 'intersect has common');
    Check(not A.Contains(1), 'intersect removed 1');
  finally A.Free; B.Free; end;
end;

procedure TestDifference;
var A, B: TIntSet;
begin
  A := TIntSet.Create(@CmpInt); B := TIntSet.Create(@CmpInt);
  try
    A.Add(1); A.Add(2); A.Add(3); A.Add(4);
    B.Add(2); B.Add(4);
    A.Difference(B);
    CheckEqual(Int64(2), Int64(A.Count), 'diff count');
    Check(A.Contains(1) and A.Contains(3), 'diff kept');
    Check(not A.Contains(2), 'diff removed');
  finally A.Free; B.Free; end;
end;

procedure TestIsEmpty;
var S: TIntSet;
begin
  S := TIntSet.Create(@CmpInt);
  try
    Check(S.IsEmpty, 'empty initially');
    S.Add(1);
    Check(not S.IsEmpty, 'not empty after add');
    S.Remove(1);
    Check(S.IsEmpty, 'empty after remove');
  finally S.Free; end;
end;

procedure TestClear;
var S: TIntSet;
begin
  S := TIntSet.Create(@CmpInt);
  try
    S.Add(1); S.Add(2); S.Add(3);
    S.Clear;
    CheckEqual(Int64(0), Int64(S.Count), 'count after clear');
    Check(S.IsEmpty, 'empty after clear');
    S.Add(99);
    CheckEqual(Int64(1), Int64(S.Count), 'usable after clear');
  finally S.Free; end;
end;

procedure TestGrow;
var S: TIntSet; i: Integer; ok: Boolean;
begin
  S := TIntSet.Create(@CmpInt);
  try
    for i := 0 to 999 do S.Add(i);
    CheckEqual(Int64(1000), Int64(S.Count), 'count');
    ok := True;
    for i := 0 to 999 do
      if not S.Contains(i) then ok := False;
    Check(ok, 'all present');
  finally S.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btreeset');
  T.Run('Add/Contains', @TestAddContains);
  T.Run('Remove', @TestRemove);
  T.Run('Min/Max', @TestMinMax);
  T.Run('PopMin/PopMax', @TestPopMinMax);
  T.Run('LowerBound/UpperBound', @TestLowerUpperBound);
  T.Run('Floor', @TestFloor);
  T.Run('Union', @TestUnion);
  T.Run('Intersection', @TestIntersection);
  T.Run('Difference', @TestDifference);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('Clear', @TestClear);
  T.Run('Grow (1000)', @TestGrow);
  T.Summary;
end.
