unit nextpas.core.collections.abstract;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type
  ICollection = nextpas.core.collections.intf.ICollection;
  TCollection = nextpas.core.collections.base.TCollection;
  TCollectionClass = nextpas.core.collections.base.TCollectionClass;
  IGrowthStrategy = nextpas.core.collections.base.IGrowthStrategy;
  TGrowthStrategy = nextpas.core.collections.base.TGrowthStrategy;
  TGrowthStrategyClass = nextpas.core.collections.base.TGrowthStrategyClass;
  TGrowFunc = nextpas.core.collections.base.TGrowFunc;
  TGrowMethod = nextpas.core.collections.base.TGrowMethod;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  TGrowRefFunc = nextpas.core.collections.base.TGrowRefFunc;
  {$ENDIF}
  TGrowProxyMethod = nextpas.core.collections.base.TGrowProxyMethod;
  TCustomGrowthStrategy = nextpas.core.collections.base.TCustomGrowthStrategy;
  TCalcGrowStrategy = nextpas.core.collections.base.TCalcGrowStrategy;
  TDoublingGrowStrategy = nextpas.core.collections.base.TDoublingGrowStrategy;
  TFixedGrowStrategy = nextpas.core.collections.base.TFixedGrowStrategy;
  TFactorGrowStrategy = nextpas.core.collections.base.TFactorGrowStrategy;
  TPowerOfTwoGrowStrategy = nextpas.core.collections.base.TPowerOfTwoGrowStrategy;
  TGoldenRatioGrowStrategy = nextpas.core.collections.base.TGoldenRatioGrowStrategy;
  TAlignedWrapperStrategy = nextpas.core.collections.base.TAlignedWrapperStrategy;
  TExactGrowStrategy = nextpas.core.collections.base.TExactGrowStrategy;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

implementation

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.FixedGrow(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.FactorGrow(aFactor);
end;

function DoublingGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.DoublingGrow;
end;

function ExactGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.ExactGrow;
end;

function GoldenRatioGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.GoldenRatioGrow;
end;

end.
