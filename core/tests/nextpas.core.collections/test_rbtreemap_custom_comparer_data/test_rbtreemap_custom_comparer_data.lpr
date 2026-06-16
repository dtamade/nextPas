program test_rbtreemap_custom_comparer_data;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.base,
  nextpas.core.collections.orderedmap.rb,
  nextpas.core.mem.intf;

type
  TIntRBMap = specialize TRBTreeMap<Integer, Integer>;
  PCompareState = ^TCompareState;
  TCompareState = record
    Magic: Integer;
    Calls: Integer;
  end;

var
  T: TTestRunner;

function CompareRequiresData(const A, B: Integer; AData: Pointer): SizeInt;
var
  LState: PCompareState;
begin
  if AData = nil then
    raise Exception.Create('RBTreeMap comparer data was nil');

  LState := PCompareState(AData);
  if LState^.Magic <> 73129 then
    raise Exception.Create('RBTreeMap comparer data magic mismatch');

  Inc(LState^.Calls);
  if A < B then
    Exit(-1);
  if A > B then
    Exit(1);
  Result := 0;
end;

procedure CheckEqualInt(AExpected, AActual: Integer; const AMessage: string);
begin
  CheckEqual(Int64(AExpected), Int64(AActual), AMessage);
end;

procedure TestComparerDataReachesCoreAndMapKeyPaths;
var
  LMap: TIntRBMap;
  LState: TCompareState;
  LValue: Integer;
  LEntry: TIntRBMap.TEntry;
begin
  LState.Magic := 73129;
  LState.Calls := 0;
  LMap := TIntRBMap.Create(@CompareRequiresData, IAllocator(nil), @LState);
  try
    Check(LMap.Add(10, 100), 'add first');
    Check(LMap.Add(20, 200), 'add second');
    Check(not LMap.Add(10, 999), 'duplicate add');
    Check(not LMap.AddOrAssign(10, 101), 'update reports false');
    Check(LMap.TryUpdate(20, 201), 'try update existing');
    Check(LMap.TryGetValue(10, LValue), 'try get key 10');
    CheckEqualInt(101, LValue, 'value for key 10');
    Check(LMap.ContainsKey(20), 'contains key 20');
    Check(LMap.LowerBoundKey(15, LEntry), 'lower bound key 15');
    CheckEqualInt(20, LEntry.Key, 'lower bound result key');
    Check(LMap.UpperBoundKey(10, LEntry), 'upper bound key 10');
    CheckEqualInt(20, LEntry.Key, 'upper bound result key');
    Check(LMap.Remove(10), 'remove key 10');
    Check(not LMap.ContainsKey(10), 'removed key missing');
    Check(LState.Calls > 0, 'comparer should have been called');
  finally
    LMap.Free;
  end;
end;

procedure TestComparerDataReachesRangeIterator;
var
  LMap: TIntRBMap;
  LState: TCompareState;
  LIter: TPtrIter;
  LEntry: TIntRBMap.PEntry;
  LSeen: array[0..2] of Integer;
  LCount: Integer;
begin
  LState.Magic := 73129;
  LState.Calls := 0;
  LMap := TIntRBMap.Create(@CompareRequiresData, IAllocator(nil), @LState);
  try
    LMap.Put(10, 100);
    LMap.Put(20, 200);
    LMap.Put(30, 300);

    LCount := 0;
    LIter := LMap.IterateRange(10, 30, True);
    while LIter.MoveNext do
    begin
      LEntry := TIntRBMap.PEntry(LIter.GetCurrent);
      Check(LCount <= High(LSeen), 'range produced expected number of entries');
      LSeen[LCount] := LEntry^.Key;
      Inc(LCount);
    end;

    CheckEqualInt(3, LCount, 'inclusive range count');
    CheckEqualInt(10, LSeen[0], 'range key 0');
    CheckEqualInt(20, LSeen[1], 'range key 1');
    CheckEqualInt(30, LSeen[2], 'range key 2');
    Check(LState.Calls > 0, 'range should have called comparer');
  finally
    LMap.Free;
  end;
end;

procedure TestRangeMovePrevStartsAtLastWhenRightBoundExceedsMax;
var
  LMap: TIntRBMap;
  LState: TCompareState;
  LIter: TPtrIter;
  LEntry: TIntRBMap.PEntry;
begin
  LState.Magic := 73129;
  LState.Calls := 0;
  LMap := TIntRBMap.Create(@CompareRequiresData, IAllocator(nil), @LState);
  try
    LMap.Put(10, 100);
    LMap.Put(20, 200);
    LMap.Put(30, 300);

    LIter := LMap.IterateRange(10, 50, False);
    Check(LIter.MovePrev, 'reverse range with high right bound should start at max key');
    LEntry := TIntRBMap.PEntry(LIter.GetCurrent);
    Check(LEntry <> nil, 'reverse range high bound entry should be present');
    CheckEqualInt(30, LEntry^.Key, 'reverse range high bound first key');
    Check(LIter.MovePrev, 'reverse range high bound should continue to previous key');
    LEntry := TIntRBMap.PEntry(LIter.GetCurrent);
    CheckEqualInt(20, LEntry^.Key, 'reverse range high bound second key');
  finally
    LMap.Free;
  end;
end;

procedure TestRangeMovePrevHonorsExclusiveRightBound;
var
  LMap: TIntRBMap;
  LState: TCompareState;
  LIter: TPtrIter;
  LEntry: TIntRBMap.PEntry;
begin
  LState.Magic := 73129;
  LState.Calls := 0;
  LMap := TIntRBMap.Create(@CompareRequiresData, IAllocator(nil), @LState);
  try
    LMap.Put(10, 100);
    LMap.Put(20, 200);
    LMap.Put(30, 300);

    LIter := LMap.IterateRange(10, 30, False);
    Check(LIter.MovePrev, 'exclusive reverse range should start before right bound');
    LEntry := TIntRBMap.PEntry(LIter.GetCurrent);
    Check(LEntry <> nil, 'exclusive reverse range entry should be present');
    CheckEqualInt(20, LEntry^.Key, 'exclusive reverse range first key');
    Check(LIter.MovePrev, 'exclusive reverse range should continue to lower key');
    LEntry := TIntRBMap.PEntry(LIter.GetCurrent);
    CheckEqualInt(10, LEntry^.Key, 'exclusive reverse range second key');
    Check(not LIter.MovePrev, 'exclusive reverse range should stop at left bound');
  finally
    LMap.Free;
  end;
end;

procedure TestRangeIteratorsKeepIndependentBounds;
var
  LMap: TIntRBMap;
  LState: TCompareState;
  LLeftIter: TPtrIter;
  LRightIter: TPtrIter;
  LEntry: TIntRBMap.PEntry;
begin
  LState.Magic := 73129;
  LState.Calls := 0;
  LMap := TIntRBMap.Create(@CompareRequiresData, IAllocator(nil), @LState);
  try
    LMap.Put(10, 100);
    LMap.Put(20, 200);
    LMap.Put(30, 300);
    LMap.Put(40, 400);
    LMap.Put(50, 500);

    LLeftIter := LMap.IterateRange(10, 30, True);
    LRightIter := LMap.IterateRange(40, 50, True);

    Check(LLeftIter.MoveNext, 'first range iterator should keep its left bound');
    LEntry := TIntRBMap.PEntry(LLeftIter.GetCurrent);
    Check(LEntry <> nil, 'first range iterator entry should be present');
    CheckEqualInt(10, LEntry^.Key, 'first range iterator first key');

    Check(LRightIter.MoveNext, 'second range iterator should keep its left bound');
    LEntry := TIntRBMap.PEntry(LRightIter.GetCurrent);
    Check(LEntry <> nil, 'second range iterator entry should be present');
    CheckEqualInt(40, LEntry^.Key, 'second range iterator first key');

    Check(LLeftIter.MoveNext, 'first range iterator should keep its right bound');
    LEntry := TIntRBMap.PEntry(LLeftIter.GetCurrent);
    CheckEqualInt(20, LEntry^.Key, 'first range iterator second key');
    Check(LLeftIter.MoveNext, 'first range iterator should reach inclusive right bound');
    LEntry := TIntRBMap.PEntry(LLeftIter.GetCurrent);
    CheckEqualInt(30, LEntry^.Key, 'first range iterator third key');
    Check(not LLeftIter.MoveNext, 'first range iterator should stop at original right bound');
  finally
    LMap.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.rbtreemap_custom_comparer_data');
  T.Run('comparer data reaches core and map key paths', @TestComparerDataReachesCoreAndMapKeyPaths);
  T.Run('comparer data reaches range iterator', @TestComparerDataReachesRangeIterator);
  T.Run('range MovePrev starts at last when right bound exceeds max', @TestRangeMovePrevStartsAtLastWhenRightBoundExceedsMax);
  T.Run('range MovePrev honors exclusive right bound', @TestRangeMovePrevHonorsExclusiveRightBound);
  T.Run('range iterators keep independent bounds', @TestRangeIteratorsKeepIndependentBounds);
  T.Summary;
end.
