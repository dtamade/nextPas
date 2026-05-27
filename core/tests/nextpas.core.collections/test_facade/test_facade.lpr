program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.base,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashset.intf;

type
  IIntVec = specialize IVec<Integer>;
  IIntIntMap = specialize IHashMap<Integer, Integer>;
  IIntSet = specialize IHashSet<Integer>;
  IIntDeque = specialize IDeque<Integer>;

var
  T: TTestRunner;

procedure TestFacadeFactoriesReturnPublicInterfaces;
var
  LVec: IIntVec;
  LMap: IIntIntMap;
  LSet: IIntSet;
  LDeque: IIntDeque;
  LValue: Integer;
begin
  LVec := specialize Vec<Integer>;
  LVec.Push(10);
  CheckEqual(Int64(1), Int64(LVec.Count), 'vec count');
  CheckEqual(Int64(10), Int64(LVec[0]), 'vec value');

  LMap := specialize Map<Integer, Integer>;
  LMap.Put(1, 100);
  Check(LMap.Get(1, LValue), 'map get');
  CheckEqual(Int64(100), Int64(LValue), 'map value');

  LSet := specialize Set_<Integer>;
  Check(LSet.Add(7), 'set add');
  Check(LSet.Contains(7), 'set contains');

  LDeque := specialize Deque<Integer>;
  LDeque.PushBack(1);
  LDeque.PushFront(0);
  CheckEqual(Int64(2), Int64(LDeque.Count), 'deque count');
  CheckEqual(Int64(0), Int64(LDeque.PopFront), 'deque front');
  CheckEqual(Int64(1), Int64(LDeque.PopBack), 'deque back');
end;

procedure TestFacadeExportsGrowthStrategies;
var
  LStrategy: IGrowthStrategy;
begin
  LStrategy := FactorGrow(1.5);
  Check(LStrategy <> nil, 'FactorGrow should return a growth strategy');
  Check(LStrategy.GetGrowSize(0, 12) >= 12, 'FactorGrow should satisfy required size');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'DoublingGrow should double capacity');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.facade');
  T.Run('facade factories return public interfaces', @TestFacadeFactoriesReturnPublicInterfaces);
  T.Run('facade exports growth strategies', @TestFacadeExportsGrowthStrategies);
  T.Summary;
end.
