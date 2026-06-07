program test_btree_custom_comparer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree;

type
  TIntBTree = specialize TBTreeMap<Integer, Integer>;
  TIntSet = specialize TBTreeSet<Integer>;

var
  T: TTestRunner;
  GRangeItems: array[0..7] of Integer;
  GRangeCount: Integer;

function CmpIntDesc(const A, B: Integer; AData: Pointer): SizeInt;
begin
  if A > B then
    Result := -1
  else if A < B then
    Result := 1
  else
    Result := 0;
end;

procedure AddSampleKeys(ATree: TIntBTree);
begin
  ATree.Put(10, 100);
  ATree.Put(50, 500);
  ATree.Put(30, 300);
  ATree.Put(20, 200);
  ATree.Put(40, 400);
end;

procedure AddSampleSetItems(ASet: TIntSet);
begin
  ASet.Add(10);
  ASet.Add(50);
  ASet.Add(30);
  ASet.Add(20);
  ASet.Add(40);
end;

procedure CheckEqualInt(AExpected, AActual: Integer; const AMessage: string);
begin
  CheckEqual(Int64(AExpected), Int64(AActual), AMessage);
end;

procedure CheckRangeItem(AIndex, AExpected: Integer);
begin
  CheckEqualInt(AExpected, GRangeItems[AIndex], 'range item ' + IntToStr(AIndex));
end;

procedure RangeCallback(const AKey: Integer; const AValue: Integer; AData: Pointer);
begin
  GRangeItems[GRangeCount] := AKey;
  Inc(GRangeCount);
end;

procedure TestMapHonorsDescendingComparerForLookupAndBounds;
var
  LTree: TIntBTree;
  LKey, LValue: Integer;
begin
  LTree := TIntBTree.Create(@CmpIntDesc);
  try
    AddSampleKeys(LTree);

    Check(LTree.ContainsKey(40), 'contains existing key');
    Check(not LTree.ContainsKey(35), 'does not contain missing key');
    Check(LTree.TryGetValue(20, LValue), 'get existing key');
    CheckEqualInt(200, LValue, 'get value');

    Check(LTree.Min(LKey, LValue), 'min exists');
    CheckEqualInt(50, LKey, 'min follows descending comparer');
    Check(LTree.Max(LKey, LValue), 'max exists');
    CheckEqualInt(10, LKey, 'max follows descending comparer');

    Check(LTree.LowerBound(35, LKey, LValue), 'lower bound 35');
    CheckEqualInt(30, LKey, 'lower bound follows descending comparer');
    Check(LTree.UpperBound(30, LKey, LValue), 'upper bound 30');
    CheckEqualInt(20, LKey, 'upper bound follows descending comparer');
    Check(LTree.Floor(35, LKey, LValue), 'floor 35');
    CheckEqualInt(40, LKey, 'floor follows descending comparer');
  finally
    LTree.Free;
  end;
end;

procedure TestMapHonorsDescendingComparerForRangeAndEnumeration;
var
  LTree: TIntBTree;
  LEntry: TIntBTree.TEntry;
  LExpected: Integer;
  LCount: Integer;
begin
  LTree := TIntBTree.Create(@CmpIntDesc);
  try
    AddSampleKeys(LTree);

    GRangeCount := 0;
    LTree.Range(45, 15, @RangeCallback);
    CheckEqualInt(3, GRangeCount, 'range count');
    CheckRangeItem(0, 40);
    CheckRangeItem(1, 30);
    CheckRangeItem(2, 20);

    LExpected := 50;
    LCount := 0;
    for LEntry in LTree do
    begin
      CheckEqualInt(LExpected, LEntry.Key, 'enumerator key ' + IntToStr(LCount));
      Dec(LExpected, 10);
      Inc(LCount);
    end;
    CheckEqualInt(5, LCount, 'enumerator count');
  finally
    LTree.Free;
  end;
end;

procedure TestMapHonorsDescendingComparerAfterSplits;
var
  LTree: TIntBTree;
  LEntry: TIntBTree.TEntry;
  LExpected, LValue: Integer;
begin
  LTree := TIntBTree.Create(@CmpIntDesc);
  try
    for LExpected := 0 to 63 do
      LTree.Put(LExpected, LExpected * 10);

    for LExpected := 0 to 63 do
    begin
      Check(LTree.ContainsKey(LExpected), 'split contains ' + IntToStr(LExpected));
      Check(LTree.TryGetValue(LExpected, LValue), 'split get ' + IntToStr(LExpected));
      CheckEqualInt(LExpected * 10, LValue, 'split value ' + IntToStr(LExpected));
    end;

    LExpected := 63;
    for LEntry in LTree do
    begin
      CheckEqualInt(LExpected, LEntry.Key, 'split enumerator key ' + IntToStr(63 - LExpected));
      Dec(LExpected);
    end;
    CheckEqualInt(-1, LExpected, 'split enumerator count');
  finally
    LTree.Free;
  end;
end;

procedure TestSetHonorsDescendingComparer;
var
  LSet: TIntSet;
  LValue: Integer;
  LItems: TIntSet.TItemArray;
begin
  LSet := TIntSet.Create(@CmpIntDesc);
  try
    AddSampleSetItems(LSet);

    Check(LSet.Contains(40), 'set contains existing item');
    Check(not LSet.Contains(35), 'set does not contain missing item');

    Check(LSet.Min(LValue), 'set min exists');
    CheckEqualInt(50, LValue, 'set min follows descending comparer');
    Check(LSet.Max(LValue), 'set max exists');
    CheckEqualInt(10, LValue, 'set max follows descending comparer');

    Check(LSet.LowerBound(35, LValue), 'set lower bound 35');
    CheckEqualInt(30, LValue, 'set lower bound follows descending comparer');
    Check(LSet.UpperBound(30, LValue), 'set upper bound 30');
    CheckEqualInt(20, LValue, 'set upper bound follows descending comparer');

    LItems := LSet.ToArray;
    CheckEqualInt(5, Length(LItems), 'set array length');
    CheckEqualInt(50, LItems[0], 'set array item 0');
    CheckEqualInt(40, LItems[1], 'set array item 1');
    CheckEqualInt(30, LItems[2], 'set array item 2');
    CheckEqualInt(20, LItems[3], 'set array item 3');
    CheckEqualInt(10, LItems[4], 'set array item 4');
  finally
    LSet.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btree_custom_comparer');
  T.Run('Map lookup and bounds honor descending comparer', @TestMapHonorsDescendingComparerForLookupAndBounds);
  T.Run('Map range and enumeration honor descending comparer', @TestMapHonorsDescendingComparerForRangeAndEnumeration);
  T.Run('Map split paths honor descending comparer', @TestMapHonorsDescendingComparerAfterSplits);
  T.Run('Set honors descending comparer', @TestSetHonorsDescendingComparer);
  T.Summary;
end.
