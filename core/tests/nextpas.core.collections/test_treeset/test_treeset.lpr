program test_treeset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.linkedhashset.intf;

type
  IIntTreeSet = specialize ITreeSet<Integer>;
  IIntLinkedHashSet = specialize ILinkedHashSet<Integer>;

var
  T: TTestRunner;

procedure TestTreeSetBasic;
var
  LSet: IIntTreeSet;
begin
  LSet := specialize MakeTreeSet<Integer>;
  Check(LSet.Add(3), 'add 3');
  Check(LSet.Add(1), 'add 1');
  Check(LSet.Add(2), 'add 2');
  Check(not LSet.Add(1), 'add 1 duplicate');
  CheckEqual(Int64(3), Int64(LSet.GetCount), 'count');
  Check(LSet.Contains(2), 'contains 2');
  Check(not LSet.Contains(5), 'not contains 5');
end;

procedure TestTreeSetRemove;
var
  LSet: IIntTreeSet;
begin
  LSet := specialize MakeTreeSet<Integer>;
  LSet.Add(10);
  LSet.Add(20);
  LSet.Add(30);
  Check(LSet.Remove(20), 'remove 20');
  Check(not LSet.Remove(20), 'remove 20 again');
  CheckEqual(Int64(2), Int64(LSet.GetCount), 'count after remove');
end;

procedure TestTreeSetMinMax;
var
  LSet: IIntTreeSet;
  LVal: Integer;
begin
  LSet := specialize MakeTreeSet<Integer>;
  LSet.Add(50);
  LSet.Add(10);
  LSet.Add(30);
  Check(LSet.Min(LVal), 'min exists');
  CheckEqual(Int64(10), Int64(LVal), 'min value');
  Check(LSet.Max(LVal), 'max exists');
  CheckEqual(Int64(50), Int64(LVal), 'max value');
end;

procedure TestTreeSetBounds;
var
  LSet: IIntTreeSet;
  LVal: Integer;
begin
  LSet := specialize MakeTreeSet<Integer>;
  LSet.Add(10);
  LSet.Add(20);
  LSet.Add(30);
  LSet.Add(40);
  Check(LSet.LowerBound(25, LVal), 'lower bound 25');
  CheckEqual(Int64(30), Int64(LVal), 'lower bound value');
  Check(LSet.UpperBound(20, LVal), 'upper bound 20');
  CheckEqual(Int64(30), Int64(LVal), 'upper bound value');
end;

procedure TestTreeSetUnion;
var
  LA, LB, LC: IIntTreeSet;
begin
  LA := specialize MakeTreeSet<Integer>;
  LA.Add(1); LA.Add(2); LA.Add(3);
  LB := specialize MakeTreeSet<Integer>;
  LB.Add(3); LB.Add(4); LB.Add(5);
  LC := LA.Union(LB);
  CheckEqual(Int64(5), Int64(LC.GetCount), 'union count');
end;

procedure TestTreeSetIntersect;
var
  LA, LB, LC: IIntTreeSet;
begin
  LA := specialize MakeTreeSet<Integer>;
  LA.Add(1); LA.Add(2); LA.Add(3);
  LB := specialize MakeTreeSet<Integer>;
  LB.Add(2); LB.Add(3); LB.Add(4);
  LC := LA.Intersect(LB);
  CheckEqual(Int64(2), Int64(LC.GetCount), 'intersect count');
  Check(LC.Contains(2), 'intersect has 2');
  Check(LC.Contains(3), 'intersect has 3');
end;

procedure TestTreeSetDifference;
var
  LA, LB, LC: IIntTreeSet;
begin
  LA := specialize MakeTreeSet<Integer>;
  LA.Add(1); LA.Add(2); LA.Add(3);
  LB := specialize MakeTreeSet<Integer>;
  LB.Add(2); LB.Add(3); LB.Add(4);
  LC := LA.Difference(LB);
  CheckEqual(Int64(1), Int64(LC.GetCount), 'difference count');
  Check(LC.Contains(1), 'difference has 1');
end;

procedure TestLinkedHashSetBasic;
var
  LSet: IIntLinkedHashSet;
  LVal: Integer;
begin
  LSet := specialize MakeLinkedHashSet<Integer>;
  Check(LSet.Add(30), 'add 30');
  Check(LSet.Add(10), 'add 10');
  Check(LSet.Add(20), 'add 20');
  Check(not LSet.Add(10), 'add 10 duplicate');
  CheckEqual(Int64(3), Int64(LSet.Count), 'count');
  Check(LSet.TryGetFirst(LVal), 'try first');
  CheckEqual(Int64(30), Int64(LVal), 'first is 30 (insertion order)');
  Check(LSet.TryGetLast(LVal), 'try last');
  CheckEqual(Int64(20), Int64(LVal), 'last is 20 (insertion order)');
end;

procedure TestLinkedHashSetRemove;
var
  LSet: IIntLinkedHashSet;
begin
  LSet := specialize MakeLinkedHashSet<Integer>;
  LSet.Add(1); LSet.Add(2); LSet.Add(3);
  Check(LSet.Remove(2), 'remove 2');
  Check(not LSet.Contains(2), 'not contains 2');
  CheckEqual(Int64(2), Int64(LSet.Count), 'count after remove');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.treeset');
  T.Run('TreeSet basic add/contains', @TestTreeSetBasic);
  T.Run('TreeSet remove', @TestTreeSetRemove);
  T.Run('TreeSet Min/Max', @TestTreeSetMinMax);
  T.Run('TreeSet LowerBound/UpperBound', @TestTreeSetBounds);
  T.Run('TreeSet Union', @TestTreeSetUnion);
  T.Run('TreeSet Intersect', @TestTreeSetIntersect);
  T.Run('TreeSet Difference', @TestTreeSetDifference);
  T.Run('LinkedHashSet basic (insertion order)', @TestLinkedHashSetBasic);
  T.Run('LinkedHashSet remove', @TestLinkedHashSetRemove);
  T.Summary;
end.
