program test_btree_managed_lifecycle;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree,
  leak_tracker;

type
  TTrackedMap = specialize TBTreeMap<Integer, ITracked>;
  TTrackedSet = specialize TBTreeSet<ITracked>;
  TManagedRecord = record
    Initialized: Boolean;
    Id: Int32;
    Payload: string;
    class operator Initialize(var ARecord: TManagedRecord);
    class operator Finalize(var ARecord: TManagedRecord);
  end;
  TManagedRecordMap = specialize TBTreeMap<TManagedRecord, TManagedRecord>;

var
  T: TTestRunner;
  GManagedRecordAlive: Int32 = 0;
  GManagedRecordBadFinalize: Int32 = 0;

class operator TManagedRecord.Initialize(var ARecord: TManagedRecord);
begin
  ARecord.Initialized := True;
  ARecord.Id := 0;
  ARecord.Payload := '';
  Inc(GManagedRecordAlive);
end;

class operator TManagedRecord.Finalize(var ARecord: TManagedRecord);
begin
  if not ARecord.Initialized then
    Inc(GManagedRecordBadFinalize)
  else
  begin
    ARecord.Initialized := False;
    ARecord.Payload := '';
    Dec(GManagedRecordAlive);
  end;
end;

function MakeManagedRecord(AId: Int32): TManagedRecord;
begin
  Result.Id := AId;
  Result.Payload := 'managed-' + IntToStr(AId);
end;

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

function CompareManagedRecord(const A, B: TManagedRecord; AData: Pointer): SizeInt;
begin
  if A.Id < B.Id then
    Result := -1
  else if A.Id > B.Id then
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

procedure TestMapPopMinMaxManagedValueOutputsOwnRefs;
var
  LMap: TTrackedMap;
  LSnap: TLeakSnapshot;
  LValue, LMinValue, LMaxValue: ITracked;
  LMinKey, LMaxKey: Integer;
  i: Integer;
begin
  LSnap := SnapTake;
  LMap := TTrackedMap.Create(@CompareInt);
  try
    for i := 0 to 63 do
    begin
      LValue := MakeTracked(i);
      LMap.Put(i, LValue);
      LValue := nil;
    end;

    Check(LMap.PopMin(LMinKey, LMinValue), 'map pop min');
    CheckEqual(Int64(0), Int64(LMinKey), 'map pop min key');
    CheckEqual(Int64(0), Int64(LMinValue.GetId), 'map pop min value id');
    Check(LMap.PopMax(LMaxKey, LMaxValue), 'map pop max');
    CheckEqual(Int64(63), Int64(LMaxKey), 'map pop max key');
    CheckEqual(Int64(63), Int64(LMaxValue.GetId), 'map pop max value id');

    LMap.Clear;
    CheckEqual(Int64(0), Int64(LMap.Count), 'map count after pop outputs and clear');
    CheckEqual(Int64(0), Int64(LMinValue.GetId), 'map pop min output survives clear');
    CheckEqual(Int64(63), Int64(LMaxValue.GetId), 'map pop max output survives clear');
    CheckAliveDelta(2, LSnap, 'map pop outputs own two refs after clear');

    LMinValue := nil;
    LMaxValue := nil;
    SnapAssert(LSnap, 'BTree map PopMin/PopMax managed outputs');
  finally
    LMap.Free;
  end;

  SnapAssert(LSnap, 'BTree map PopMin/PopMax managed outputs + free');
end;

procedure TestSetPopMinMaxManagedItemOutputsOwnRefs;
var
  LSet: TTrackedSet;
  LSnap: TLeakSnapshot;
  LItem, LMinItem, LMaxItem: ITracked;
  i: Integer;
begin
  LSnap := SnapTake;
  LSet := TTrackedSet.Create(@CompareTracked);
  try
    for i := 0 to 63 do
    begin
      LItem := MakeTracked(i);
      Check(LSet.Add(LItem), 'insert set pop item ' + IntToStr(i));
      LItem := nil;
    end;

    Check(LSet.PopMin(LMinItem), 'set pop min');
    CheckEqual(Int64(0), Int64(LMinItem.GetId), 'set pop min item id');
    Check(LSet.PopMax(LMaxItem), 'set pop max');
    CheckEqual(Int64(63), Int64(LMaxItem.GetId), 'set pop max item id');

    LSet.Clear;
    CheckEqual(Int64(0), Int64(LSet.Count), 'set count after pop outputs and clear');
    CheckEqual(Int64(0), Int64(LMinItem.GetId), 'set pop min output survives clear');
    CheckEqual(Int64(63), Int64(LMaxItem.GetId), 'set pop max output survives clear');
    CheckAliveDelta(2, LSnap, 'set pop outputs own two refs after clear');

    LMinItem := nil;
    LMaxItem := nil;
    SnapAssert(LSnap, 'BTree set PopMin/PopMax managed outputs');
  finally
    LSet.Free;
  end;

  SnapAssert(LSnap, 'BTree set PopMin/PopMax managed outputs + free');
end;

procedure TestMapManagedRecordKeyValueRemoveRebalanceKeepsLifecycle;
var
  LMap: TManagedRecordMap;
  I: Integer;
begin
  GManagedRecordAlive := 0;
  GManagedRecordBadFinalize := 0;
  LMap := TManagedRecordMap.Create(@CompareManagedRecord);
  try
    for I := 0 to BTREE_MAX_KEYS do
      LMap.Put(MakeManagedRecord(I), MakeManagedRecord(I * 10));

    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record no bad finalize after split');

    Check(LMap.Remove(MakeManagedRecord(BTREE_MAX_KEYS)),
      'managed record remove right child key before missing root merge');
    Check(not LMap.Remove(MakeManagedRecord(-1)),
      'managed record missing remove after root merge reports false');
    CheckEqual(Int64(BTREE_MAX_KEYS), Int64(LMap.Count),
      'managed record missing remove keeps count');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record no bad finalize after remove/root merge');

    LMap.Clear;
    CheckEqual(Int64(0), Int64(GManagedRecordAlive),
      'managed record clear releases all key/value slots');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
      'managed record clear does not finalize uninitialized slots');
  finally
    LMap.Free;
  end;

  CheckEqual(Int64(0), Int64(GManagedRecordAlive),
    'managed record free leaves no live key/value slots');
  CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize),
    'managed record free leaves no bad finalize count');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btree_managed_lifecycle');
  T.Run('map managed values released after split clear', @TestMapManagedValuesReleasedAfterSplitClear);
  T.Run('map managed value released after split remove', @TestMapManagedValueReleasedAfterSplitRemove);
  T.Run('set managed key released after split remove', @TestSetManagedKeyReleasedAfterSplitRemove);
  T.Run('map managed values released during remove stress', @TestMapManagedValuesReleasedDuringRemoveStress);
  T.Run('set managed keys released during remove stress', @TestSetManagedKeysReleasedDuringRemoveStress);
  T.Run('map PopMin/PopMax managed outputs own refs', @TestMapPopMinMaxManagedValueOutputsOwnRefs);
  T.Run('set PopMin/PopMax managed outputs own refs', @TestSetPopMinMaxManagedItemOutputsOwnRefs);
  T.Run('map managed record key/value remove rebalance lifecycle',
    @TestMapManagedRecordKeyValueRemoveRebalanceKeepsLifecycle);
  T.Summary;
end.
