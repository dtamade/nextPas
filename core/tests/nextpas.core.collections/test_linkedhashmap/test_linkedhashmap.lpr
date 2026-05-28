program test_linkedhashmap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.linkedhashmap.intf,
  nextpas.core.collections.linkedhashmap;

type
  IIntStrMap = specialize ILinkedHashMap<Integer, string>;
  TIntStrMap = specialize TLinkedHashMap<Integer, string>;

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
  T.Summary;
end.
