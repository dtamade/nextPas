program test_managed_types;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.stack.intf,
  nextpas.core.collections.list.intf,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.tree_set.intf;

type
  TStrVec = specialize TVec<string>;
  IStrVec = specialize IVec<string>;
  TStrDeque = specialize TVecDeque<string>;
  IStrQueue = specialize IQueue<string>;
  IStrStack = specialize IStack<string>;
  IStrList = specialize IList<string>;
  IStrFList = specialize IForwardList<string>;
  IStrStrMap = specialize IHashMap<string, string>;
  TStrStrMap = specialize THashMap<string, string>;
  IStrCache = specialize ILruCache<string, string>;
  IStrTreeSet = specialize ITreeSet<string>;

var
  T: TTestRunner;

procedure TestVecStringPushPopDrain;
var
  LV: TStrVec;
  LDrained: IStrVec;
  LS: string;
begin
  LV := TStrVec.Create;
  try
    LV.Push('hello');
    LV.Push('world');
    LV.Push('foo');
    LV.Push('bar');
    CheckEqual('bar', LV.Pop, 'pop');
    LDrained := LV.Drain(0, 2);
    CheckEqual(Int64(2), Int64(LDrained.Count), 'drained');
    CheckEqual('hello', LDrained.Get(0), 'drained[0]');
    CheckEqual(Int64(1), Int64(LV.Count), 'source after drain');
    Check(LV.TryPop(LS), 'try pop');
    CheckEqual('foo', LS, 'remaining');
  finally
    LV.Free;
  end;
end;

procedure TestVecStringInsertRemove;
var
  LV: TStrVec;
  LS: string;
begin
  LV := TStrVec.Create;
  try
    LV.Push(['alpha', 'beta', 'gamma', 'delta']);
    LV.Insert(2, 'inserted');
    CheckEqual(Int64(5), Int64(LV.Count), 'count after insert');
    CheckEqual('inserted', LV.Get(2), 'inserted value');
    LS := LV.RemoveAt(2);
    CheckEqual('inserted', LS, 'removed value');
    LS := LV.SwapRemoveAt(1);
    CheckEqual('beta', LS, 'swap removed');
  finally
    LV.Free;
  end;
end;

procedure TestVecStringSpliceRetain;
var
  LV: TStrVec;
begin
  LV := TStrVec.Create;
  try
    LV.Push(['a', 'bb', 'ccc', 'dd', 'e']);
    LV.Splice(1, 2, ['X', 'Y']);
    CheckEqual(Int64(5), Int64(LV.Count), 'splice count');
    CheckEqual('X', LV.Get(1), 'spliced[1]');
    LV.Clear;
    Check(LV.IsEmpty, 'clear');
  finally
    LV.Free;
  end;
end;

procedure TestDequeStringPushPop;
var
  LD: TStrDeque;
begin
  LD := TStrDeque.Create;
  try
    LD.PushBack('one');
    LD.PushBack('two');
    LD.PushBack('three');
    LD.PushFront('zero');
    CheckEqual(Int64(4), Int64(LD.GetCount), 'count');
    CheckEqual('zero', LD.PopFront, 'pop front');
    CheckEqual('three', LD.PopBack, 'pop back');
    LD.Insert(1, 'mid');
    CheckEqual('mid', LD.Get(1), 'inserted');
    LD.RemoveAt(1);
    CheckEqual(Int64(2), Int64(LD.GetCount), 'after remove');
    LD.Clear;
  finally
    LD.Free;
  end;
end;

procedure TestQueueString;
var
  LQ: IStrQueue;
begin
  LQ := specialize MakeQueue<string>;
  LQ.Push('first');
  LQ.Push('second');
  LQ.Push('third');
  CheckEqual('first', LQ.Pop, 'FIFO');
  CheckEqual('second', LQ.Pop, 'FIFO 2');
  LQ.Clear;
end;

procedure TestStackString;
var
  LS: IStrStack;
begin
  LS := specialize MakeStack<string>;
  LS.Push('bottom');
  LS.Push('middle');
  LS.Push('top');
  CheckEqual('top', LS.Pop, 'LIFO');
  CheckEqual('middle', LS.Pop, 'LIFO 2');
  LS.Clear;
end;

procedure TestListString;
var
  LL: IStrList;
begin
  LL := specialize MakeList<string>;
  LL.PushBack('a');
  LL.PushBack('b');
  LL.PushFront('z');
  CheckEqual('z', LL.PopFront, 'front');
  CheckEqual('b', LL.PopBack, 'back');
  CheckEqual('a', LL.PopFront, 'last');
end;

procedure TestForwardListString;
var
  LF: IStrFList;
  LS: string;
begin
  LF := specialize MakeForwardList<string>;
  LF.PushFront('c');
  LF.PushFront('b');
  LF.PushFront('a');
  CheckEqual(Int64(3), Int64(LF.GetCount), 'count');
  Check(LF.TryPopFront(LS), 'pop');
  CheckEqual('a', LS, 'LIFO front');
  LF.Clear;
end;

procedure TestHashMapString;
var
  LM: TStrStrMap;
  LV: string;
begin
  LM := TStrStrMap.Create;
  try
    LM.Put('key1', 'value1');
    LM.Put('key2', 'value2');
    LM.Put('key3', 'value3');
    Check(LM.TryGetValue('key2', LV), 'get');
    CheckEqual('value2', LV, 'value');
    LM.Put('key2', 'updated');
    CheckEqual('updated', LM.Get('key2'), 'overwritten');
    Check(LM.Remove('key1'), 'remove');
    Check(not LM.ContainsKey('key1'), 'removed');
    LM.Clear;
  finally
    LM.Free;
  end;
end;

procedure TestLruCacheString;
var
  LC: IStrCache;
  LV: string;
begin
  LC := specialize MakeLruCache<string, string>(3);
  LC.Put('a', 'alpha');
  LC.Put('b', 'beta');
  LC.Put('c', 'gamma');
  LC.Put('d', 'delta');
  Check(not LC.Get('a', LV), 'evicted');
  Check(LC.Get('b', LV), 'still present');
  CheckEqual('beta', LV, 'value');
  LC.Clear;
end;

procedure TestTreeSetString;
var
  LS: IStrTreeSet;
  LMin: string;
begin
  LS := specialize MakeTreeSet<string>;
  LS.Add('banana');
  LS.Add('apple');
  LS.Add('cherry');
  Check(LS.Contains('apple'), 'contains');
  Check(LS.Min(LMin), 'min');
  CheckEqual('apple', LMin, 'min is apple (sorted)');
  Check(LS.Remove('banana'), 'remove');
  CheckEqual(Int64(2), Int64(LS.GetCount), 'count after remove');
end;

procedure TestVecStringGrowStress;
var
  LV: TStrVec;
  I: Integer;
begin
  LV := TStrVec.Create;
  try
    for I := 1 to 1000 do
      LV.Push('item_' + IntToStr(I));
    CheckEqual(Int64(1000), Int64(LV.Count), '1000 strings');
    CheckEqual('item_1', LV.Get(0), 'first');
    CheckEqual('item_1000', LV.Get(999), 'last');
    for I := 1 to 500 do
      LV.Pop;
    CheckEqual(Int64(500), Int64(LV.Count), 'after 500 pops');
    LV.ShrinkToFit;
    LV.Clear;
  finally
    LV.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.managed_types');
  T.Run('Vec string push/pop/drain', @TestVecStringPushPopDrain);
  T.Run('Vec string insert/remove', @TestVecStringInsertRemove);
  T.Run('Vec string splice/retain', @TestVecStringSpliceRetain);
  T.Run('Deque string push/pop/insert/remove', @TestDequeStringPushPop);
  T.Run('Queue string FIFO', @TestQueueString);
  T.Run('Stack string LIFO', @TestStackString);
  T.Run('List string', @TestListString);
  T.Run('ForwardList string', @TestForwardListString);
  T.Run('HashMap string keys+values', @TestHashMapString);
  T.Run('LruCache string', @TestLruCacheString);
  T.Run('TreeSet string', @TestTreeSetString);
  T.Run('Vec string grow stress (1000)', @TestVecStringGrowStress);
  T.Summary;
end.
