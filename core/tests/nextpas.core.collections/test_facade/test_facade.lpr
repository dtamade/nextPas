program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections;

var
  T: TTestRunner;

function CompareInt(const A, B: Integer): SizeInt;
begin
  if A < B then
    Exit(-1);
  if A > B then
    Exit(1);
  Result := 0;
end;

function CompareIntWithData(const A, B: Integer; AData: Pointer): SizeInt;
begin
  Result := CompareInt(A, B);
end;

function CompareIntDescWithData(const A, B: Integer; AData: Pointer): SizeInt;
begin
  Result := CompareInt(B, A);
end;

procedure TestFacadeFactoriesReturnPublicInterfaces;
var
  LSkipValue: string;
  LTrieValue: Integer;
  LMapValue: string;
  LQueueValue: Integer;
  LBufferValue: Integer;
begin
  with specialize MakeVec<Integer> do
  begin
    Push(10);
    CheckEqual(Int64(1), Int64(Count), 'vec count');
    CheckEqual(Int64(10), Int64(Get(0)), 'vec value');
  end;

  with specialize MakeHashMap<Integer, Integer> do
  begin
    Put(1, 100);
    CheckEqual(Int64(100), Int64(Get(1)), 'map value');
  end;

  with specialize MakeHashSet<Integer> do
  begin
    Check(Add(7), 'set add');
    Check(Contains(7), 'set contains');
  end;

  with specialize MakeDeque<Integer> do
  begin
    PushBack(1);
    PushFront(0);
    CheckEqual(Int64(2), Int64(Count), 'deque count');
    CheckEqual(Int64(0), Int64(PopFront), 'deque front');
    CheckEqual(Int64(1), Int64(PopBack), 'deque back');
  end;

  with specialize MakeSkipList<Integer, string>(@CompareInt) do
  begin
    Check(Add(1, 'one'), 'skiplist add');
    Check(not Add(1, 'uno'), 'skiplist duplicate add');
    Put(1, 'uno');
    Check(TryGetValue(1, LSkipValue), 'skiplist try get');
    CheckEqual('uno', LSkipValue, 'skiplist value');
    CheckEqual('uno', Get(1), 'skiplist checked get');
  end;

  with specialize MakeTrie<Integer> do
  begin
    Check(Add('one', 1), 'trie add');
    Check(not Add('one', 11), 'trie duplicate add');
    Put('one', 11);
    Check(TryGetValue('one', LTrieValue), 'trie try get');
    CheckEqual(Int64(11), Int64(LTrieValue), 'trie value');
    CheckEqual(Int64(11), Int64(Get('one')), 'trie checked get');
  end;

  with specialize MakeRBTreeMap<Integer, string>(@CompareIntWithData) do
  begin
    Check(Add(1, 'one'), 'rb map add');
    Check(not Add(1, 'uno'), 'rb map duplicate add');
    Check(not AddOrAssign(1, 'uno'), 'rb map update reports false');
    Check(TryGetValue(1, LMapValue), 'rb map try get');
    CheckEqual('uno', LMapValue, 'rb map value');
    Put(1, 'eins');
    CheckEqual('eins', Get(1), 'rb map checked get');
  end;

  with specialize MakeCircularBuffer<Integer>(2, False) do
  begin
    Check(Push(10), 'circular buffer first push');
    Check(Push(20), 'circular buffer second push');
    Check(not Push(30), 'circular buffer full push rejected');
    Check(TryPeek(LBufferValue), 'circular buffer try peek');
    CheckEqual(Int64(10), Int64(LBufferValue), 'circular buffer peek value');
  end;

  with specialize MakePriorityQueue<Integer>(@CompareIntDescWithData) do
  begin
    Push(1);
    Push(3);
    Push(2);
    Check(TryPeek(LQueueValue), 'priority queue try peek');
    CheckEqual(Int64(3), Int64(LQueueValue), 'priority queue peek value');
    CheckEqual(Int64(3), Int64(Pop), 'priority queue pop value');
  end;
end;

procedure TestFacadeExportsGrowthStrategies;
var
  LStrategy: IGrowthStrategy;
begin
  LStrategy := FactorGrow(1.5);
  Check(LStrategy <> nil, 'FactorGrow should return a growth strategy');
  Check(LStrategy.GetGrowSize(0, 12) >= 12, 'FactorGrow should satisfy required size');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'DoublingGrow should double capacity');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.facade');
  T.Run('facade factories return public interfaces', @TestFacadeFactoriesReturnPublicInterfaces);
  T.Run('facade exports growth strategies', @TestFacadeExportsGrowthStrategies);
  T.Summary;
end.
