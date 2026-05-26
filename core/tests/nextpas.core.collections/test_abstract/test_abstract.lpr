program test_abstract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections.abstract;

var
  T: TTestRunner;

procedure TestAbstractExportsCollectionSkeleton;
var
  LClass: TCollectionClass;
begin
  LClass := TCollection;
  Check(LClass <> nil, 'TCollectionClass should accept TCollection');
end;

procedure TestAbstractExportsGrowthStrategies;
var
  LStrategy: IGrowthStrategy;
begin
  LStrategy := FactorGrow(1.5);
  Check(LStrategy <> nil, 'FactorGrow should return a strategy');
  Check(LStrategy.GetGrowSize(0, 10) >= 10, 'growth strategy should satisfy required size');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'doubling strategy should double capacity');

  CheckEqual(
    Int64(64),
    Int64(TAlignedWrapperStrategy.DEFAULT_ALIGN_SIZE),
    'aligned wrapper default alignment');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.abstract');
  T.Run('exports collection skeleton', @TestAbstractExportsCollectionSkeleton);
  T.Run('exports growth strategies', @TestAbstractExportsGrowthStrategies);
  T.Summary;
end.
