program test_btree_managed_lifecycle;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree,
  leak_tracker;

type
  TTrackedMap = specialize TBTreeMap<Integer, ITracked>;
  TTrackedSet = specialize TBTreeSet<ITracked>;

var
  T: TTestRunner;

function CompareInt(const A, B: Integer; AData: Pointer): SizeInt;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

function CompareTracked(const A, B: ITracked; AData: Pointer): SizeInt;
begin
  if A.GetId < B.GetId then
    Result := -1
  else if A.GetId > B.GetId then
    Result := 1
  else
    Result := 0;
end;

procedure TestMapManagedValuesReleasedAfterSplitClear;
var
  LMap: TTrackedMap;
  LSnap: TLeakSnapshot;
  LValue: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LMap := TTrackedMap.Create(@CompareInt);
  try
    for i := 0 to BTREE_MAX_KEYS do
    begin
      LValue := MakeTracked(i);
      LMap.Put(i, LValue);
      LValue := nil;
    end;

    CheckEqual(Int64(BTREE_MAX_KEYS + 1), Int64(LMap.Count), 'map count after split');
    LMap.Clear;
    SnapAssert(LSnap, 'BTree managed value split/clear');
  finally
    LMap.Free;
  end;

  SnapAssert(LSnap, 'BTree managed value split/free');
end;

procedure CheckAliveDelta(AExpected: Int32; ASnap: TLeakSnapshot; const AContext: string);
var
  LActual: Int32;
begin
  LActual := GTrackedAlive - ASnap;
  CheckEqual(Int64(AExpected), Int64(LActual), AContext);
end;

procedure TestMapManagedValueReleasedAfterSplitRemove;
var
  LMap: TTrackedMap;
  LSnap: TLeakSnapshot;
  LValue: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LMap := TTrackedMap.Create(@CompareInt);
  try
    for i := 0 to BTREE_MAX_KEYS do
    begin
      LValue := MakeTracked(i);
      LMap.Put(i, LValue);
      LValue := nil;
    end;

    CheckEqual(Int64(BTREE_MAX_KEYS + 1), Int64(LMap.Count), 'map count after split');
    CheckAliveDelta(BTREE_MAX_KEYS + 1, LSnap, 'alive count after split');

    Check(LMap.Remove(BTREE_ORDER), 'remove first key from split right child');
    CheckEqual(Int64(BTREE_MAX_KEYS), Int64(LMap.Count), 'map count after split remove');
    CheckAliveDelta(BTREE_MAX_KEYS, LSnap, 'alive count after split remove');

    LMap.Clear;
    SnapAssert(LSnap, 'BTree managed value split/remove/clear');
  finally
    LMap.Free;
  end;

  SnapAssert(LSnap, 'BTree managed value split/remove/free');
end;

procedure TestSetManagedKeyReleasedAfterSplitRemove;
var
  LSet: TTrackedSet;
  LSnap: TLeakSnapshot;
  LItem: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LSet := TTrackedSet.Create(@CompareTracked);
  try
    for i := 0 to BTREE_MAX_KEYS do
    begin
      LItem := MakeTracked(i);
      Check(LSet.Add(LItem), 'insert tracked item ' + IntToStr(i));
      LItem := nil;
    end;

    CheckEqual(Int64(BTREE_MAX_KEYS + 1), Int64(LSet.Count), 'set count after split');
    CheckAliveDelta(BTREE_MAX_KEYS + 1, LSnap, 'key alive count after split');

    LItem := MakeTracked(BTREE_ORDER);
    Check(LSet.Remove(LItem), 'remove first key from split right child');
    LItem := nil;
    CheckEqual(Int64(BTREE_MAX_KEYS), Int64(LSet.Count), 'set count after split remove');
    CheckAliveDelta(BTREE_MAX_KEYS, LSnap, 'key alive count after split remove');

    LSet.Clear;
    SnapAssert(LSnap, 'BTree managed key split/remove/clear');
  finally
    LSet.Free;
  end;

  SnapAssert(LSnap, 'BTree managed key split/remove/free');
end;

procedure TestMapManagedValuesReleasedDuringRemoveStress;
var
  LMap: TTrackedMap;
  LSnap: TLeakSnapshot;
  LValue: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LMap := TTrackedMap.Create(@CompareInt);
  try
    for i := 0 to 95 do
    begin
      LValue := MakeTracked(i);
      LMap.Put(i, LValue);
      LValue := nil;
    end;

    CheckAliveDelta(96, LSnap, 'map remove stress alive after insert');
    for i := 0 to 95 do
    begin
      Check(LMap.Remove(i), 'remove map key ' + IntToStr(i));
      CheckAliveDelta(Int32(LMap.Count), LSnap,
        'map remove stress alive after removing ' + IntToStr(i));
    end;

    SnapAssert(LSnap, 'BTree managed value remove stress');
  finally
    LMap.Free;
  end;

  SnapAssert(LSnap, 'BTree managed value remove stress + free');
end;

procedure TestSetManagedKeysReleasedDuringRemoveStress;
var
  LSet: TTrackedSet;
  LSnap: TLeakSnapshot;
  LItem: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LSet := TTrackedSet.Create(@CompareTracked);
  try
    for i := 0 to 95 do
    begin
      LItem := MakeTracked(i);
      Check(LSet.Add(LItem), 'insert set item ' + IntToStr(i));
      LItem := nil;
    end;

    CheckAliveDelta(96, LSnap, 'set remove stress alive after insert');
    for i := 0 to 95 do
    begin
      LItem := MakeTracked(i);
      Check(LSet.Remove(LItem), 'remove set item ' + IntToStr(i));
      LItem := nil;
      CheckAliveDelta(Int32(LSet.Count), LSnap,
        'set remove stress alive after removing ' + IntToStr(i));
    end;

    SnapAssert(LSnap, 'BTree managed key remove stress');
  finally
    LSet.Free;
  end;

  SnapAssert(LSnap, 'BTree managed key remove stress + free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btree_managed_lifecycle');
  T.Run('map managed values released after split clear', @TestMapManagedValuesReleasedAfterSplitClear);
  T.Run('map managed value released after split remove', @TestMapManagedValueReleasedAfterSplitRemove);
  T.Run('set managed key released after split remove', @TestSetManagedKeyReleasedAfterSplitRemove);
  T.Run('map managed values released during remove stress', @TestMapManagedValuesReleasedDuringRemoveStress);
  T.Run('set managed keys released during remove stress', @TestSetManagedKeysReleasedDuringRemoveStress);
  T.Summary;
end.
