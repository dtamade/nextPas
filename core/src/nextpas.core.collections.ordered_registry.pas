unit nextpas.core.collections.ordered_registry;

{ Ordered registry single source (owner=collections).
  Extracted from db.factory monomorphic DbRegistryLowerBound to generic
  candidate: TRBTreeCore.LowerBound / algorithms.LowerBound shape, O(log n)
  zero-copy, inline. Factory keeps monomorphic string-compare variant for
  hot-path without generic instantiation overhead; this unit is the generic
  single source for future ordered registries. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.algorithms;

generic function OrderedLowerBound<T>(const AArr: array of T; const AValue: T;
  ACompare: specialize TAlgoCompareFunc<T>; AData: Pointer): SizeInt; inline;

generic function OrderedBinarySearch<T>(const AArr: array of T; const AValue: T;
  ACompare: specialize TAlgoCompareFunc<T>; AData: Pointer; out AIndex: SizeInt): Boolean; inline;

implementation

generic function OrderedLowerBound<T>(const AArr: array of T; const AValue: T;
  ACompare: specialize TAlgoCompareFunc<T>; AData: Pointer): SizeInt; inline;
begin
  Result := specialize LowerBound<T>(AArr, AValue, ACompare, AData);
end;

generic function OrderedBinarySearch<T>(const AArr: array of T; const AValue: T;
  ACompare: specialize TAlgoCompareFunc<T>; AData: Pointer; out AIndex: SizeInt): Boolean; inline;
begin
  Result := specialize BinarySearch<T>(AArr, AValue, ACompare, AData, AIndex);
end;

end.
