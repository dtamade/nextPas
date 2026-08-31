unit nextpas.core.collections.factories;
{**
 * @desc 集合工厂实现层：承载所有 Make* 泛型工厂的真实创建逻辑。
 *       由门面 nextpas.core.collections 以 inline 转发复用，避免门面
 *       直接聚合 60+ 子单元与近千行实现，满足 800 行软指引；零拷贝
 *       inline 保证与直调一致的性能，异常与资源释放语义保持与原实现一致。
 *}

{$I nextpas.core.settings.inc}
{$WARN 5024 OFF}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.arr.base,
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.vec.base,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.vecdeque.base,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashset.intf,
  nextpas.core.collections.linkedhashmap.base,
  nextpas.core.collections.linkedhashmap.intf,
  nextpas.core.collections.linkedhashset.intf,
  nextpas.core.collections.multimap.intf,
  nextpas.core.collections.multiset.base,
  nextpas.core.collections.multiset.intf,
  nextpas.core.collections.orderedmap.rb.base,
  nextpas.core.collections.orderedmap.rb.intf,
  nextpas.core.collections.treemap.base,
  nextpas.core.collections.treemap.intf,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.skiplist.base,
  nextpas.core.collections.skiplist.intf,
  nextpas.core.collections.trie.intf,
  nextpas.core.collections.lrucache.base,
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.element_manager.base,
  nextpas.core.collections.element_manager.intf,
  nextpas.core.collections.list.intf,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.stack.intf,
  nextpas.core.collections.circularbuffer.intf,
  nextpas.core.collections.priorityqueue.base,
  nextpas.core.collections.priorityqueue.intf,
  nextpas.core.collections.bitset.base,
  nextpas.core.collections.bitset.intf,
  nextpas.core.collections.btree.intf,
  nextpas.core.collections.concurrent.map.intf;

{ Vec / VecDeque / Arr capacity-based }
generic function MakeVec<T>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>;
generic function MakeArr<T>(aAllocator: TMemAllocator = nil): specialize IArray<T>;
generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil): specialize IArray<T>;
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil): specialize IArray<T>;
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;
generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil): specialize IArray<T>;
generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;

{ HashMap / HashSet }
{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
generic function MakeSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
{$ENDIF}

{ Tree / Ordered }
generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: TMemAllocator = nil): specialize ITreeMap<K,V>;
generic function MakeTreeSet<T>(aAllocator: TMemAllocator = nil): specialize ITreeSet<T>;
generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>; aAllocator: TMemAllocator = nil; aCompareData: Pointer = nil): specialize ITreeSet<T>;
generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;
generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator = nil): specialize IRBTreeMap<K,V>;
generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>;
generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>;
generic function MakeSkipList<K,V>: specialize ISkipList<K,V>;
generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>;
generic function MakeTrie<V>: specialize ITrie<V>;
generic function MakeLruCache<K,V>(aMaxSize: SizeUInt = 100; aAllocator: TMemAllocator = nil; aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil; aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>;
generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize ILinkedHashMap<K,V>;
generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean = True): specialize ICircularBuffer<T>;
generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt = PRIORITYQUEUE_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): specialize IPriorityQueue<T>;
generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>;
generic function MakeMultiSet<T>: specialize IMultiSet<T>;
function MakeBitSet(aInitialCapacity: SizeUInt = BITSET_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): IBitSet;
generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt = 0): specialize IConcurrentMap<K,V>;

{ Facade extended overloads }
generic function MakeVecDeque<T>: specialize IDeque<T>; overload;
generic function MakeDeque<T>: specialize IDeque<T>; overload;
generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;
generic function MakeQueue<T>: specialize IQueue<T>; overload;
generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;
generic function MakeStack<T>: specialize IStack<T>; overload;
generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;
generic function MakeList<T>: specialize IList<T>; overload;
generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>; overload;
generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; overload;
generic function MakeForwardList<T>: specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; overload;

implementation

uses
  nextpas.core.mem.default,
  nextpas.core.collections.arr,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.forward_list,
  nextpas.core.collections.deque,
  nextpas.core.collections.queue,
  nextpas.core.collections.stack,
  nextpas.core.collections.list,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.slotregistry,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss.adapter,
  nextpas.core.collections.hashset,
  nextpas.core.collections.linkedhashmap,
  nextpas.core.collections.linkedhashset,
  nextpas.core.collections.multimap,
  nextpas.core.collections.multiset,
  nextpas.core.collections.tree.rb,
  nextpas.core.collections.orderedmap.rb,
  nextpas.core.collections.treemap,
  nextpas.core.collections.tree_set,
  nextpas.core.collections.btree,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.trie,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.lrucache,
  nextpas.core.collections.bitset,
  nextpas.core.collections.concurrent.hashmap,
  nextpas.core.collections.smallvec.base,
  nextpas.core.collections.trie.base;

{ Vec / Arr factories }
generic function MakeVec<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrc, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrcCollection, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy));
end;

generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;

generic function MakeArr<T>(aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(0, aAllocator));
end;

generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aAllocator));
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator));
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator, aData));
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator));
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator, aData));
end;

{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeHashSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize MakeHashMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>;
begin
  Result := specialize MakeHashMap<K,V>(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>;
begin
  Result := specialize MakeHashSet<K>(aCapacity, aAllocator);
end;
{$ENDIF}

generic function MakeTreeMap<K,V>(aCapacity: SizeUInt; aCompare: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize ITreeMap<K,V>;
begin
  Result := specialize TTreeMap<K,V>.Create(aAllocator, aCompare);
end;

generic function MakeTreeSet<T>(aAllocator: TMemAllocator): specialize ITreeSet<T>;
begin
  if aAllocator <> nil then
    Result := specialize TTreeSet<T>.Create(aAllocator)
  else
    Result := specialize TTreeSet<T>.Create;
end;

generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>; aAllocator: TMemAllocator; aCompareData: Pointer): specialize ITreeSet<T>;
begin
  Result := specialize TTreeSet<T>.Create(aAllocator, aCompare, aCompareData);
end;

generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;
begin
  Result := specialize TLinkedHashSet<T>.Create;
end;

generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize IRBTreeMap<K,V>;
begin
  if aAllocator <> nil then
    Result := specialize TRBTreeMap<K,V>.Create(aKeyComparer, aAllocator)
  else
    Result := specialize TRBTreeMap<K,V>.Create(aKeyComparer);
end;

generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>;
begin
  Result := specialize TBTreeMap<K,V>.Create(specialize TBTreeMap<K,V>.TKeyCompareFunc(aCompare));
end;

generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>;
begin
  Result := specialize TBTreeSet<T>.Create(specialize TBTreeSet<T>.TCompareFunc(aCompare));
end;

generic function MakeSkipList<K,V>: specialize ISkipList<K,V>;
begin
  Result := specialize TSkipList<K,V>.Create;
end;

generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>;
begin
  Result := specialize TSkipList<K,V>.Create(aCompare);
end;

generic function MakeTrie<V>: specialize ITrie<V>;
begin
  Result := specialize TTrie<V>.Create;
end;

generic function MakeLruCache<K,V>(aMaxSize: SizeUInt; aAllocator: TMemAllocator; aHash: specialize THashFunc<K>; aEquals: specialize TEqualsFunc<K>; aHashData: Pointer; aEqualsData: Pointer): specialize ILruCache<K,V>;
begin
  Result := specialize TLruCache<K,V>.Create(aMaxSize, aAllocator, aHash, aEquals, aHashData, aEqualsData);
end;

generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize ILinkedHashMap<K,V>;
begin
  if aAllocator <> nil then
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity, aAllocator)
  else
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity);
end;

generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean): specialize ICircularBuffer<T>;
begin
  Result := specialize TCircularBuffer<T>.Create(aCapacity, aOverwriteOldest);
end;

generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IPriorityQueue<T>;
begin
  Result := specialize TPriorityQueue<T>.Create(aComparer, aCapacity, aAllocator);
end;

generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>;
begin
  Result := specialize TMultiMap<K,V>.Create;
end;

generic function MakeMultiSet<T>: specialize IMultiSet<T>;
begin
  Result := specialize TMultiSet<T>.Create;
end;

function MakeBitSet(aInitialCapacity: SizeUInt; aAllocator: TMemAllocator): IBitSet;
begin
  if aAllocator <> nil then
    Result := TBitSet.Create(aInitialCapacity, aAllocator)
  else
    Result := TBitSet.Create(aInitialCapacity);
end;

generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt): specialize IConcurrentMap<K,V>;
begin
  Result := specialize TConcurrentHashMap<K,V>.Create(nil, nil, aInitialCapacityPerSegment);
end;

{ Facade extended overloads impl }
generic function MakeVecDeque<T>: specialize IDeque<T>;
var
  LDeque: specialize TVecDeque<T>;
begin
  LDeque := specialize TVecDeque<T>.Create(DefaultAllocator());
  Result := LDeque;
end;

generic function MakeDeque<T>: specialize IDeque<T>;
begin
  Result := specialize MakeDeque<T>(0, TMemAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;

generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc));
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection));
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount));
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection, DefaultAllocator(), aData));
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData));
end;

generic function MakeQueue<T>: specialize IQueue<T>;
begin
  Result := specialize MakeQueue<T>(0, TMemAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;

generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc));
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection));
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount));
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection, DefaultAllocator(), aData));
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData));
end;

generic function MakeStack<T>: specialize IStack<T>;
begin
  Result := specialize MakeStack<T>(TMemAllocator(nil));
end;

generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  Result := LStack;
end;

generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  try
    LStack.Push(aSrc);
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
  PT = ^T;
var
  LStack: TStackImpl;
  LIter: TPtrIter;
begin
  LStack := TStackImpl.Create(aAllocator);
  try
    if (aSrcCollection <> nil) and (not aSrcCollection.IsEmpty) then
    begin
      LIter := aSrcCollection.PtrIter;
      while LIter.MoveNext do
        LStack.Push(PT(LIter.Current)^);
    end;
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  try
    LStack.Push(aSrc, aElementCount);
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeList<T>: specialize IList<T>;
begin
  Result := specialize MakeList<T>(TMemAllocator(nil));
end;

generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aAllocator)
  else LObj := specialize TList<T>.Create;
  Result := LObj;
end;

generic function MakeList<T>(const aSrc: array of T): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, TMemAllocator(nil));
end;

generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aAllocator)
  else LObj := specialize TList<T>.Create(aSrc);
  Result := LObj;
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, aElementCount, TMemAllocator(nil));
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, aElementCount, aAllocator, nil);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LObj := specialize TList<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData);
  Result := LObj;
end;

generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>;
begin
  if aAllocator <> nil then
    Exit(specialize TList<T>.Create(aAllocator))
  else
    Exit(specialize TList<T>.Create);
end;

generic function MakeForwardList<T>: specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(TMemAllocator(nil));
end;

generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aAllocator)
  else LI := specialize TForwardList<T>.Create;
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, TMemAllocator(nil));
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aAllocator)
  else LI := specialize TForwardList<T>.Create(aSrc);
  Result := LI;
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, aElementCount, TMemAllocator(nil));
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, aElementCount, aAllocator, nil);
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator)
  else LI := specialize TForwardList<T>.Create(aSrcCollection);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrcCollection, DefaultAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, DefaultAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrcCollection, DefaultAllocator(), aData);
  Result := LI;
end;

end.
