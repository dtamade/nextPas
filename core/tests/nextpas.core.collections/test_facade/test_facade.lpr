program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.collections;

var
  T: TTestSuite;

function HashModuloTen(const AKey: Integer): UInt32;
begin
  Result := UInt32(AKey mod 10);
end;

function EqualModuloTen(const L, R: Integer): Boolean;
begin
  Result := (L mod 10) = (R mod 10);
end;

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

  with specialize MakeMultiMap<Integer, string> do
  begin
    Add(1, 'a');
    Add(1, 'b');
    Add(2, 'c');
    CheckEqual(Int64(2), Int64(GetValueCount(1)), 'multimap value count');
    CheckEqual(Int64(2), Int64(KeyCount), 'multimap key count');
    CheckEqual(Int64(3), Int64(TotalCount), 'multimap total count');
  end;

  with specialize MakeMultiSet<Integer> do
  begin
    Add(5);
    Add(5);
    Add(10);
    CheckEqual(Int64(2), Int64(CountOf(5)), 'multiset count of 5');
    CheckEqual(Int64(1), Int64(CountOf(10)), 'multiset count of 10');
    CheckEqual(Int64(2), Int64(Count), 'multiset unique count');
    CheckEqual(Int64(3), Int64(TotalCount), 'multiset total count');
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

procedure TestFacadeExportsSlotRegistry;
begin
  CheckEqual(Int64(64), Int64(SLOT_REGISTRY_DEFAULT_CAPACITY),
    'facade re-exports slot registry default cap');
end;

procedure TestFacadeHashMapFactoriesForwardCallbacks;
var
  LValue: Integer;
begin
  with specialize MakeHashMap<Integer, Integer>(0, @HashModuloTen, @EqualModuloTen) do
  begin
    Put(1, 10);
    Check(not AddOrAssign(11, 110), 'MakeHashMap callback equal key updates');
    CheckEqual(Int64(1), Int64(Count), 'MakeHashMap callback count');
    Check(TryGetValue(21, LValue), 'MakeHashMap callback lookup');
    CheckEqual(Int64(110), Int64(LValue), 'MakeHashMap callback value');
  end;

  with specialize MakeSwissHashMap<Integer, Integer>(0, @HashModuloTen, @EqualModuloTen) do
  begin
    Put(2, 20);
    Check(not AddOrAssign(12, 120), 'MakeSwissHashMap callback equal key updates');
    CheckEqual(Int64(1), Int64(Count), 'MakeSwissHashMap callback count');
    Check(TryGetValue(22, LValue), 'MakeSwissHashMap callback lookup');
    CheckEqual(Int64(120), Int64(LValue), 'MakeSwissHashMap callback value');
  end;
end;

procedure TestFacadeDefaultSemanticFactories;
var
  LValue: Integer;
begin
  { MakeMap currently maps to MakeHashMap (Swiss-backed IHashMap). }
  with specialize MakeMap<Integer, Integer> do
  begin
    Put(3, 30);
    CheckEqual(Int64(30), Int64(Get(3)), 'MakeMap default value');
  end;

  with specialize MakeMap<Integer, Integer>(0, @HashModuloTen, @EqualModuloTen) do
  begin
    Put(4, 40);
    Check(not AddOrAssign(14, 140), 'MakeMap callback equal key updates');
    Check(TryGetValue(24, LValue), 'MakeMap callback lookup');
    CheckEqual(Int64(140), Int64(LValue), 'MakeMap callback value');
  end;

  { MakeSet currently maps to MakeHashSet (Swiss-backed IHashSet). }
  with specialize MakeSet<Integer> do
  begin
    Check(Add(9), 'MakeSet add');
    Check(Contains(9), 'MakeSet contains');
    Check(not Add(9), 'MakeSet duplicate add');
  end;
end;

{ Minimal Create + one basic op for remaining MakeXxx (depth lives in special suites). }
procedure TestFacadeRemainingFactorySmoke;
var
  LVal: Integer;
  LQueueVal: Integer;
  LStackVal: Integer;
  LLruVal: Integer;
begin
  with specialize MakeArr<Integer>([1, 2, 3]) do
  begin
    CheckEqual(Int64(3), Int64(Count), 'arr count');
    CheckEqual(Int64(1), Int64(Get(0)), 'arr first');
  end;

  with specialize MakeVecDeque<Integer> do
  begin
    PushBack(1);
    PushFront(0);
    CheckEqual(Int64(0), Int64(PopFront), 'vecdeque front');
    CheckEqual(Int64(1), Int64(PopBack), 'vecdeque back');
  end;

  with specialize MakeQueue<Integer> do
  begin
    Push(10);
    Check(Pop(LQueueVal), 'queue pop');
    CheckEqual(Int64(10), Int64(LQueueVal), 'queue value');
  end;

  with specialize MakeStack<Integer> do
  begin
    Push(20);
    Check(Pop(LStackVal), 'stack pop');
    CheckEqual(Int64(20), Int64(LStackVal), 'stack value');
  end;

  with specialize MakeList<Integer> do
  begin
    PushBack(1);
    PushFront(0);
    CheckEqual(Int64(2), Int64(Count), 'list count');
  end;

  with specialize MakeForwardList<Integer> do
  begin
    PushFront(5);
    CheckEqual(Int64(1), Int64(Count), 'forward list count');
  end;

  with specialize MakeTreeMap<Integer, Integer>(0, @CompareIntWithData) do
  begin
    Put(1, 100);
    CheckEqual(Int64(100), Int64(Get(1)), 'tree map get');
  end;

  with specialize MakeTreeSet<Integer> do
  begin
    Check(Add(7), 'tree set add');
    Check(Contains(7), 'tree set contains');
  end;

  with specialize MakeLinkedHashMap<Integer, Integer> do
  begin
    Put(1, 10);
    Put(2, 20);
    CheckEqual(Int64(10), Int64(Get(1)), 'linked hash map get');
    CheckEqual(Int64(2), Int64(Count), 'linked hash map count');
  end;

  with specialize MakeLinkedHashSet<Integer> do
  begin
    Check(Add(3), 'linked hash set add');
    Check(Contains(3), 'linked hash set contains');
  end;

  with specialize MakeLruCache<Integer, Integer>(8) do
  begin
    Put(1, 11);
    Check(Get(1, LLruVal), 'lru get hit');
    CheckEqual(Int64(11), Int64(LLruVal), 'lru value');
  end;

  with specialize MakeBTreeMap<Integer, Integer>(@CompareIntWithData) do
  begin
    Put(2, 22);
    Check(TryGetValue(2, LVal), 'btree map try get');
    CheckEqual(Int64(22), Int64(LVal), 'btree map value');
  end;

  with specialize MakeBTreeSet<Integer>(@CompareIntWithData) do
  begin
    Check(Add(9), 'btree set add');
    Check(Contains(9), 'btree set contains');
  end;

  with MakeBitSet(64) do
  begin
    SetBit(3);
    Check(Test(3), 'bitset test');
    Check(not Test(4), 'bitset clear bit');
  end;

  with specialize MakeConcurrentHashMap<Integer, Integer> do
  begin
    Put(1, 42);
    Check(TryGetValue(1, LVal), 'concurrent map try get');
    CheckEqual(Int64(42), Int64(LVal), 'concurrent map value');
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.collections.facade');
  T.Test('facade factories return public interfaces', @TestFacadeFactoriesReturnPublicInterfaces);
  T.Test('facade exports growth strategies', @TestFacadeExportsGrowthStrategies);
  T.Test('facade exports slot registry constant', @TestFacadeExportsSlotRegistry);
  T.Test('facade hash map factories forward callbacks', @TestFacadeHashMapFactoriesForwardCallbacks);
  T.Test('facade default semantic MakeMap MakeSet', @TestFacadeDefaultSemanticFactories);
  T.Test('facade remaining MakeXxx smoke', @TestFacadeRemainingFactorySmoke);
  if not T.Run then Halt(1);
end.
