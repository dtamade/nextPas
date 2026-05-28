program test_multiset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.multiset.intf;

type
  IIntMSet = specialize IMultiSet<Integer>;

var
  T: TTestRunner;

procedure TestAddAndCountOf;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  CheckEqual(Int64(1), Int64(LS.Add(5)), 'first add returns 1');
  CheckEqual(Int64(2), Int64(LS.Add(5)), 'second add returns 2');
  CheckEqual(Int64(1), Int64(LS.Add(10)), 'different element');
  CheckEqual(Int64(2), Int64(LS.CountOf(5)), 'count of 5');
  CheckEqual(Int64(1), Int64(LS.CountOf(10)), 'count of 10');
  CheckEqual(Int64(0), Int64(LS.CountOf(99)), 'count of missing');
end;

procedure TestAddN;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  CheckEqual(Int64(5), Int64(LS.AddN(7, 5)), 'addN returns new count');
  CheckEqual(Int64(5), Int64(LS.CountOf(7)), 'count after addN');
  CheckEqual(Int64(8), Int64(LS.AddN(7, 3)), 'addN again');
end;

procedure TestRemove;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  LS.AddN(1, 3);
  Check(LS.Remove(1), 'remove existing');
  CheckEqual(Int64(2), Int64(LS.CountOf(1)), 'count decremented');
  Check(LS.Remove(1), 'remove again');
  Check(LS.Remove(1), 'remove last');
  Check(not LS.Remove(1), 'remove when gone');
  Check(not LS.Contains(1), 'no longer contains');
end;

procedure TestRemoveAll;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  LS.AddN(3, 10);
  CheckEqual(Int64(10), Int64(LS.RemoveAll(3)), 'removeall returns old count');
  CheckEqual(Int64(0), Int64(LS.CountOf(3)), 'count is 0');
  Check(not LS.Contains(3), 'not contains');
end;

procedure TestSetCount;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  LS.SetCount(5, 7);
  CheckEqual(Int64(7), Int64(LS.CountOf(5)), 'set count to 7');
  LS.SetCount(5, 0);
  Check(not LS.Contains(5), 'set count to 0 removes');
end;

procedure TestContains;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  Check(not LS.Contains(1), 'not contains initially');
  LS.Add(1);
  Check(LS.Contains(1), 'contains after add');
end;

procedure TestGetCountAndTotalCount;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  LS.AddN(1, 3);
  LS.AddN(2, 5);
  CheckEqual(Int64(2), Int64(LS.Count), 'unique count');
  CheckEqual(Int64(8), Int64(LS.TotalCount), 'total count');
end;

procedure TestClear;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  LS.AddN(1, 5);
  LS.AddN(2, 3);
  LS.Clear;
  Check(LS.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LS.Count), 'count 0');
  CheckEqual(Int64(0), Int64(LS.TotalCount), 'total 0');
end;

procedure TestIsEmpty;
var
  LS: IIntMSet;
begin
  LS := specialize MakeMultiSet<Integer>;
  Check(LS.IsEmpty, 'initially empty');
  LS.Add(1);
  Check(not LS.IsEmpty, 'not empty');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.multiset');
  T.Run('Add and CountOf', @TestAddAndCountOf);
  T.Run('AddN', @TestAddN);
  T.Run('Remove', @TestRemove);
  T.Run('RemoveAll', @TestRemoveAll);
  T.Run('SetCount', @TestSetCount);
  T.Run('Contains', @TestContains);
  T.Run('Count/TotalCount', @TestGetCountAndTotalCount);
  T.Run('Clear', @TestClear);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Summary;
end.
