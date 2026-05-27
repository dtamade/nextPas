program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections;

var
  T: TTestRunner;

procedure TestFacadeFactoriesReturnPublicInterfaces;
var
  LValue: Integer;
begin
  with specialize Vec<Integer> do
  begin
    Push(10);
    CheckEqual(Int64(1), Int64(Count), 'vec count');
    CheckEqual(Int64(10), Int64(Get(0)), 'vec value');
  end;

  with specialize Map<Integer, Integer> do
  begin
    Put(1, 100);
    Check(Get(1, LValue), 'map get');
    CheckEqual(Int64(100), Int64(LValue), 'map value');
  end;

  with specialize Set_<Integer> do
  begin
    Check(Add(7), 'set add');
    Check(Contains(7), 'set contains');
  end;

  with specialize Deque<Integer> do
  begin
    PushBack(1);
    PushFront(0);
    CheckEqual(Int64(2), Int64(Count), 'deque count');
    CheckEqual(Int64(0), Int64(PopFront), 'deque front');
    CheckEqual(Int64(1), Int64(PopBack), 'deque back');
  end;
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
