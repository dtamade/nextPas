program test_btree_managed_returns;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.btree;

type
  TStringMap = specialize TBTreeMap<string, string>;
  TStringSet = specialize TBTreeSet<string>;

var
  T: TTestRunner;

function CompareString(const A, B: string; AData: Pointer): SizeInt;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

procedure TestMapManagedKeyAndValueArraysOutliveMap;
var
  LMap: TStringMap;
  LKeys: TStringMap.TKeyArray;
  LValues: TStringMap.TValueArray;
begin
  LMap := TStringMap.Create(@CompareString);
  try
    LMap.Put('gamma', 'G');
    LMap.Put('alpha', 'A');
    LMap.Put('beta', 'B');
    LKeys := LMap.GetKeys;
    LValues := LMap.GetValues;
  finally
    LMap.Free;
  end;

  CheckEqual(Int64(3), Int64(Length(LKeys)), 'key array length');
  CheckEqual(Int64(3), Int64(Length(LValues)), 'value array length');
  CheckEqual('alpha', LKeys[0], 'keys[0]');
  CheckEqual('beta', LKeys[1], 'keys[1]');
  CheckEqual('gamma', LKeys[2], 'keys[2]');
  CheckEqual('A', LValues[0], 'values[0]');
  CheckEqual('B', LValues[1], 'values[1]');
  CheckEqual('G', LValues[2], 'values[2]');
end;

procedure TestSetManagedArrayOutlivesSet;
var
  LSet: TStringSet;
  LItems: TStringSet.TItemArray;
begin
  LSet := TStringSet.Create(@CompareString);
  try
    LSet.Add('delta');
    LSet.Add('alpha');
    LSet.Add('charlie');
    LItems := LSet.ToArray;
  finally
    LSet.Free;
  end;

  CheckEqual(Int64(3), Int64(Length(LItems)), 'item array length');
  CheckEqual('alpha', LItems[0], 'items[0]');
  CheckEqual('charlie', LItems[1], 'items[1]');
  CheckEqual('delta', LItems[2], 'items[2]');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.btree_managed_returns');
  T.Run('map managed key/value arrays outlive map', @TestMapManagedKeyAndValueArraysOutliveMap);
  T.Run('set managed array outlives set', @TestSetManagedArrayOutlivesSet);
  T.Summary;
end.
