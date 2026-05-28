program test_multimap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.multimap.intf;

type
  IIntStrMMap = specialize IMultiMap<Integer, string>;

var
  T: TTestRunner;

procedure TestAddAndGetValueCount;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  LM.Add(1, 'b');
  LM.Add(2, 'c');
  CheckEqual(Int64(2), Int64(LM.GetValueCount(1)), 'key 1 has 2 values');
  CheckEqual(Int64(1), Int64(LM.GetValueCount(2)), 'key 2 has 1 value');
  CheckEqual(Int64(0), Int64(LM.GetValueCount(99)), 'missing key has 0');
end;

procedure TestContains;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  Check(LM.Contains(1), 'contains existing key');
  Check(not LM.Contains(2), 'not contains missing key');
end;

procedure TestContainsValue;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'hello');
  LM.Add(1, 'world');
  Check(LM.ContainsValue(1, 'hello'), 'contains value hello');
  Check(LM.ContainsValue(1, 'world'), 'contains value world');
  Check(not LM.ContainsValue(1, 'foo'), 'not contains foo');
  Check(not LM.ContainsValue(2, 'hello'), 'wrong key');
end;

procedure TestRemoveKeyValue;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  LM.Add(1, 'b');
  LM.Add(1, 'c');
  Check(LM.Remove(1, 'b'), 'remove existing value');
  Check(not LM.Remove(1, 'b'), 'remove again fails');
  CheckEqual(Int64(2), Int64(LM.GetValueCount(1)), 'count after remove');
end;

procedure TestRemoveAll;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  LM.Add(1, 'b');
  LM.Add(2, 'c');
  CheckEqual(Int64(2), Int64(LM.RemoveAll(1)), 'removed 2 values');
  Check(not LM.Contains(1), 'key 1 gone');
  CheckEqual(Int64(1), Int64(LM.KeyCount), 'key count');
end;

procedure TestKeyCountTotalCount;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  LM.Add(1, 'b');
  LM.Add(2, 'c');
  CheckEqual(Int64(2), Int64(LM.KeyCount), 'key count');
  CheckEqual(Int64(3), Int64(LM.TotalCount), 'total count');
end;

procedure TestClear;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  LM.Add(1, 'a');
  LM.Add(2, 'b');
  LM.Clear;
  Check(LM.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LM.KeyCount), 'key count 0');
  CheckEqual(Int64(0), Int64(LM.TotalCount), 'total count 0');
end;

procedure TestIsEmpty;
var
  LM: IIntStrMMap;
begin
  LM := specialize MakeMultiMap<Integer, string>;
  Check(LM.IsEmpty, 'initially empty');
  LM.Add(1, 'x');
  Check(not LM.IsEmpty, 'not empty after add');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.multimap');
  T.Run('Add and GetValueCount', @TestAddAndGetValueCount);
  T.Run('Contains', @TestContains);
  T.Run('ContainsValue', @TestContainsValue);
  T.Run('Remove key+value', @TestRemoveKeyValue);
  T.Run('RemoveAll', @TestRemoveAll);
  T.Run('KeyCount/TotalCount', @TestKeyCountTotalCount);
  T.Run('Clear', @TestClear);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Summary;
end.
