program test_rbtreemap_range_managed_state;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections.base,
  nextpas.core.collections.orderedmap.rb,
  leak_tracker;

type
  TTrackedRBMap = specialize TRBTreeMap<ITracked, Integer>;

var
  T: TTestRunner;

function CompareTracked(const A, B: ITracked; AData: Pointer): SizeInt;
begin
  if A.GetId < B.GetId then
    Exit(-1);
  if A.GetId > B.GetId then
    Exit(1);
  Result := 0;
end;

procedure CheckAliveDelta(AExpected: Int32; ASnap: TLeakSnapshot; const AContext: string);
var
  LActual: Int32;
begin
  LActual := GTrackedAlive - ASnap;
  CheckEqual(Int64(AExpected), Int64(LActual), AContext);
end;

procedure AddTracked(var AMap: TTrackedRBMap; AId: Int32);
var
  LKey: ITracked;
begin
  LKey := MakeTracked(AId);
  Check(AMap.Add(LKey, AId * 10), 'tracked key insert');
  LKey := nil;
end;

procedure TestRangeIteratorDoesNotRetainManagedBounds;
var
  LMap: TTrackedRBMap;
  LSnap: TLeakSnapshot;
  LLeft: ITracked;
  LRight: ITracked;
  LIter: TPtrIter;
  LEntry: TTrackedRBMap.PEntry;
begin
  LSnap := SnapTake;
  LMap := TTrackedRBMap.Create(@CompareTracked);
  try
    AddTracked(LMap, 10);
    AddTracked(LMap, 20);
    AddTracked(LMap, 30);
    CheckAliveDelta(3, LSnap, 'map owns inserted keys before range');

    LLeft := MakeTracked(15);
    LRight := MakeTracked(25);
    LIter := LMap.IterateRange(LLeft, LRight, True);
    LLeft := nil;
    LRight := nil;

    CheckAliveDelta(3, LSnap, 'range iterator should not retain transient managed bounds');
    Check(LIter.MoveNext, 'range iterator remains usable after releasing bounds');
    LEntry := TTrackedRBMap.PEntry(LIter.GetCurrent);
    Check(LEntry <> nil, 'range iterator current entry exists');
    CheckEqual(Int64(20), Int64(LEntry^.Key.GetId), 'range iterator current key');
    CheckEqual(Int64(200), Int64(LEntry^.Value), 'range iterator current value');
    Check(not LIter.MoveNext, 'range iterator stops after the only matching key');
    LMap.Clear;
    SnapAssert(LSnap, 'RBTreeMap range managed bounds after clear');
  finally
    LMap.Free;
  end;

  SnapAssert(LSnap, 'RBTreeMap range managed bounds after free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.rbtreemap_range_managed_state');
  T.Run('range iterator does not retain managed bounds', @TestRangeIteratorDoesNotRetainManagedBounds);
  T.Summary;
end.
