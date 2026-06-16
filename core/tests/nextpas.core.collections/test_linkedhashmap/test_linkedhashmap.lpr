program test_linkedhashmap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  leak_tracker,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.base,
  nextpas.core.collections.linkedhashmap.intf,
  nextpas.core.collections.linkedhashmap;

type
  IIntStrMap = specialize ILinkedHashMap<Integer, string>;
  TIntStrMap = specialize TLinkedHashMap<Integer, string>;
  TIntStrEntry = specialize TMapEntry<Integer, string>;
  TIntTrackedMap = specialize TLinkedHashMap<Integer, ITracked>;
  TIntTrackedEntry = specialize TMapEntry<Integer, ITracked>;

var
  T: TTestRunner;

procedure TestPutAndGet;
var
  LM: IIntStrMap;
  LVal: string;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  LM.Put(1, 'one');
  LM.Put(2, 'two');
  LM.Put(3, 'three');
  CheckEqual(Int64(3), Int64(LM.GetCount), 'count');
  Check(LM.TryGetValue(1, LVal), 'get 1');
  CheckEqual('one', LVal, 'value 1');
  Check(LM.TryGetValue(3, LVal), 'get 3');
  CheckEqual('three', LVal, 'value 3');
end;

procedure TestInsertionOrder;
var
  LM: TIntStrMap;
begin
  LM := TIntStrMap.Create;
  try
    LM.Put(3, 'three');
    LM.Put(1, 'one');
    LM.Put(2, 'two');
    CheckEqual(Int64(3), Int64(LM.First.Key), 'first key is 3 (insertion order)');
    CheckEqual(Int64(2), Int64(LM.Last.Key), 'last key is 2 (insertion order)');
  finally
    LM.Free;
  end;
end;

procedure TestOverwritePreservesOrder;
var
  LM: TIntStrMap;
  LVal: string;
begin
  LM := TIntStrMap.Create;
  try
    LM.Put(1, 'one');
    LM.Put(2, 'two');
    LM.Put(3, 'three');
    LM.Put(1, 'ONE');
    CheckEqual(Int64(1), Int64(LM.First.Key), 'overwrite preserves position');
    Check(LM.TryGetValue(1, LVal), 'get overwritten');
    CheckEqual('ONE', LVal, 'value updated');
  finally
    LM.Free;
  end;
end;

procedure TestRemove;
var
  LM: IIntStrMap;
  LVal: string;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  LM.Put(1, 'one');
  LM.Put(2, 'two');
  LM.Put(3, 'three');
  Check(LM.Remove(2), 'remove existing');
  Check(not LM.Remove(2), 'remove again');
  CheckEqual(Int64(2), Int64(LM.GetCount), 'count after remove');
  Check(not LM.TryGetValue(2, LVal), 'removed key gone');
end;

procedure TestContainsKey;
var
  LM: IIntStrMap;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  LM.Put(1, 'one');
  Check(LM.ContainsKey(1), 'contains existing');
  Check(not LM.ContainsKey(99), 'not contains missing');
end;

procedure TestAdd;
var
  LM: IIntStrMap;
  LVal: string;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  Check(LM.Add(1, 'one'), 'add new');
  Check(not LM.Add(1, 'ONE'), 'add duplicate');
  Check(LM.TryGetValue(1, LVal), 'get after dup add');
  CheckEqual('one', LVal, 'value not overwritten by failed add');
end;

procedure TestAddOrAssign;
var
  LM: IIntStrMap;
  LVal: string;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  Check(LM.AddOrAssign(1, 'one'), 'addorassign new = true');
  Check(not LM.AddOrAssign(1, 'ONE'), 'addorassign existing = false');
  Check(LM.TryGetValue(1, LVal), 'get');
  CheckEqual('ONE', LVal, 'value updated');
end;

procedure TestClear;
var
  LM: IIntStrMap;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  LM.Put(1, 'one');
  LM.Put(2, 'two');
  LM.Clear;
  CheckEqual(Int64(0), Int64(LM.GetCount), 'count after clear');
  Check(LM.IsEmpty, 'empty after clear');
end;

procedure TestCheckedGet;
var
  LM: IIntStrMap;
  LRaised: Boolean;
begin
  LM := specialize MakeLinkedHashMap<Integer, string>;
  LM.Put(1, 'one');
  CheckEqual('one', LM.Get(1), 'checked get existing');
  LRaised := False;
  try
    LM.Get(99);
  except
    LRaised := True;
  end;
  Check(LRaised, 'checked get missing raises');
end;

function KeepEntryWithKeyOne(const AEntry: TIntTrackedEntry; AData: Pointer): Boolean;
begin
  Result := AEntry.Key = 1;
end;

function EntryEqualsKeyAndValue(const ALeft, ARight: TIntStrEntry; AData: Pointer): Boolean;
begin
  Result := (ALeft.Key = ARight.Key) and (ALeft.Value = ARight.Value);
end;

procedure TestInheritedReplaceKeepsBackingMapInSync;
var
  LM: TIntStrMap;
  LOldEntry: TIntStrEntry;
  LNewEntry: TIntStrEntry;
  LPair: specialize TPair<Integer, string>;
  LValue: string;
begin
  LM := TIntStrMap.Create;
  try
    LM.Put(1, 'one');
    LM.Put(2, 'two');

    LOldEntry.Key := 1;
    LOldEntry.Value := 'one';
    LNewEntry.Key := 1;
    LNewEntry.Value := 'ONE';
    LM.Replace(LOldEntry, LNewEntry, @EntryEqualsKeyAndValue, nil);

    Check(LM.TryGetValue(1, LValue), 'replace backing map still finds key 1');
    CheckEqual('ONE', LValue, 'replace updates backing map value');

    Check(LM.TryGetFirst(LPair), 'replace linked node still has first pair');
    CheckEqual('ONE', LPair.Value, 'replace updates linked node value');
  finally
    LM.Free;
  end;
end;

procedure RunInheritedReplaceIfManagedScenario(ASnap: TLeakSnapshot);
var
  LM: TIntTrackedMap;
  LEntry: TIntTrackedEntry;
  LPair: specialize TPair<Integer, ITracked>;
  LValue: ITracked;
begin
  LM := TIntTrackedMap.Create;
  try
    LValue := MakeTracked(10);
    LM.Put(1, LValue);
    LValue := nil;

    LValue := MakeTracked(30);
    LM.Put(2, LValue);
    LValue := nil;

    LEntry.Key := 1;
    LEntry.Value := MakeTracked(20);
    LM.ReplaceIf(LEntry, @KeepEntryWithKeyOne, nil);
    LEntry.Value := nil;

    Check(LM.TryGetValue(1, LValue), 'replaceif backing map still finds key 1');
    CheckEqual(Int64(20), Int64(LValue.GetId), 'replaceif updates backing map value');
    LValue := nil;

    Check(LM.TryGetFirst(LPair), 'replaceif linked node still has first pair');
    CheckEqual(Int64(20), Int64(LPair.Value.GetId), 'replaceif updates linked node value');
    LPair.Value := nil;

    LM.Retain(@KeepEntryWithKeyOne, nil);
    CheckEqual(Int64(1), Int64(GTrackedAlive - ASnap), 'retain releases removed and replaced values');

    LM.Clear;
    LEntry := Default(TIntTrackedEntry);
    LPair := Default(specialize TPair<Integer, ITracked>);
    LValue := nil;
  finally
    LM.Free;
  end;
end;

procedure TestInheritedReplaceIfKeepsBackingMapInSync;
var
  Snap: TLeakSnapshot;
begin
  Snap := SnapTake;
  RunInheritedReplaceIfManagedScenario(Snap);
  SnapAssert(Snap, 'LinkedHashMap inherited ReplaceIf keeps backing map in sync');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.linkedhashmap');
  T.Run('Put and Get', @TestPutAndGet);
  T.Run('Insertion order', @TestInsertionOrder);
  T.Run('Overwrite preserves order', @TestOverwritePreservesOrder);
  T.Run('Remove', @TestRemove);
  T.Run('ContainsKey', @TestContainsKey);
  T.Run('Add (absent only)', @TestAdd);
  T.Run('AddOrAssign', @TestAddOrAssign);
  T.Run('Clear', @TestClear);
  T.Run('Checked Get', @TestCheckedGet);
  T.Run('Inherited Replace keeps backing map in sync', @TestInheritedReplaceKeepsBackingMapInSync);
  T.Run('Inherited ReplaceIf keeps backing map in sync', @TestInheritedReplaceIfKeepsBackingMapInSync);
  T.Summary;
end.
