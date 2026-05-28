program test_linkedhashset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.linkedhashset.intf;

type
  IIntLHSet = specialize ILinkedHashSet<Integer>;

var
  T: TTestRunner;

procedure TestAddAndContains;
var
  LS: IIntLHSet;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  Check(LS.Add(1), 'add 1');
  Check(LS.Add(2), 'add 2');
  Check(not LS.Add(1), 'add duplicate');
  CheckEqual(Int64(2), Int64(LS.Count), 'count');
  Check(LS.Contains(1), 'contains 1');
  Check(LS.Contains(2), 'contains 2');
  Check(not LS.Contains(3), 'not contains 3');
end;

procedure TestInsertionOrder;
var
  LS: IIntLHSet;
  LVal: Integer;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  LS.Add(30);
  LS.Add(10);
  LS.Add(20);
  Check(LS.TryGetFirst(LVal), 'try first');
  CheckEqual(Int64(30), Int64(LVal), 'first is 30 (insertion order)');
  Check(LS.TryGetLast(LVal), 'try last');
  CheckEqual(Int64(20), Int64(LVal), 'last is 20 (insertion order)');
end;

procedure TestRemove;
var
  LS: IIntLHSet;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  LS.Add(1);
  LS.Add(2);
  LS.Add(3);
  Check(LS.Remove(2), 'remove existing');
  Check(not LS.Remove(2), 'remove again');
  CheckEqual(Int64(2), Int64(LS.Count), 'count after remove');
  Check(not LS.Contains(2), 'not contains removed');
end;

procedure TestFirstLast;
var
  LS: IIntLHSet;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  LS.Add(100);
  LS.Add(200);
  LS.Add(300);
  CheckEqual(Int64(100), Int64(LS.First), 'first');
  CheckEqual(Int64(300), Int64(LS.Last), 'last');
end;

procedure TestTryGetFirstLastEmpty;
var
  LS: IIntLHSet;
  LVal: Integer;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  Check(not LS.TryGetFirst(LVal), 'try first on empty');
  Check(not LS.TryGetLast(LVal), 'try last on empty');
end;

procedure TestClear;
var
  LS: IIntLHSet;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  LS.Add(1);
  LS.Add(2);
  LS.Clear;
  Check(LS.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LS.Count), 'count 0');
end;

procedure TestIsEmpty;
var
  LS: IIntLHSet;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  Check(LS.IsEmpty, 'initially empty');
  LS.Add(1);
  Check(not LS.IsEmpty, 'not empty');
end;

procedure TestRemovePreservesOrder;
var
  LS: IIntLHSet;
  LVal: Integer;
begin
  LS := specialize MakeLinkedHashSet<Integer>;
  LS.Add(10);
  LS.Add(20);
  LS.Add(30);
  LS.Remove(20);
  Check(LS.TryGetFirst(LVal), 'first after remove');
  CheckEqual(Int64(10), Int64(LVal), 'first still 10');
  Check(LS.TryGetLast(LVal), 'last after remove');
  CheckEqual(Int64(30), Int64(LVal), 'last still 30');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.linkedhashset');
  T.Run('Add and Contains', @TestAddAndContains);
  T.Run('Insertion order', @TestInsertionOrder);
  T.Run('Remove', @TestRemove);
  T.Run('First/Last', @TestFirstLast);
  T.Run('TryGetFirst/Last empty', @TestTryGetFirstLastEmpty);
  T.Run('Clear', @TestClear);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('Remove preserves order', @TestRemovePreservesOrder);
  T.Summary;
end.
