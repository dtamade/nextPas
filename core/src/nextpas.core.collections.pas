unit nextpas.core.collections;
{**
 * @desc 容器门面：Vec、HashMap、Deque、BTree、LRU、Pool、SlotRegistry。
 *       Thin wrapper — 工厂实现位于 nextpas.core.collections.factory。
 *}

{$I nextpas.core.settings.inc}
{$DEFINE NEXTPAS_COLLECTIONS_FACADE}
{$WARN 5024 OFF}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.mem.allocator.base,
  nextpas.core.collections.factory,
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashset.intf,
  nextpas.core.collections.linkedhashmap.intf,
  nextpas.core.collections.linkedhashset.intf,
  nextpas.core.collections.multimap.intf,
  nextpas.core.collections.multiset.intf,
  nextpas.core.collections.orderedmap.rb.intf,
  nextpas.core.collections.treemap.intf,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.btree.intf,
  nextpas.core.collections.skiplist.intf,
  nextpas.core.collections.trie.intf,
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.list.intf,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.stack.intf,
  nextpas.core.collections.circularbuffer.intf,
  nextpas.core.collections.priorityqueue.intf,
  nextpas.core.collections.bitset.intf,
  nextpas.core.collections.concurrent.map.intf;

type
  ICollection = nextpas.core.collections.factory.ICollection;
  IBitSet = nextpas.core.collections.factory.IBitSet;
  ISlotRegistryItem = nextpas.core.collections.factory.ISlotRegistryItem;
  PPtrIter = nextpas.core.collections.factory.PPtrIter;
  TPtrIter = nextpas.core.collections.factory.TPtrIter;
  TCollection = nextpas.core.collections.factory.TCollection;
  TCollectionClass = nextpas.core.collections.factory.TCollectionClass;
  TMergePosition = nextpas.core.collections.factory.TMergePosition;
  TSortAlgorithm = nextpas.core.collections.factory.TSortAlgorithm;
  TRandomGeneratorFunc = nextpas.core.collections.factory.TRandomGeneratorFunc;
  TRandomGeneratorMethod = nextpas.core.collections.factory.TRandomGeneratorMethod;
  TRandomGeneratorRefFunc = nextpas.core.collections.factory.TRandomGeneratorRefFunc;
  TGrowFunc = nextpas.core.collections.factory.TGrowFunc;
  TGrowMethod = nextpas.core.collections.factory.TGrowMethod;
  TGrowRefFunc = nextpas.core.collections.factory.TGrowRefFunc;
  TGrowProxyMethod = nextpas.core.collections.factory.TGrowProxyMethod;
  generic TPredicateFunc<T> = function(const aElement: T; aData: Pointer): Boolean;
  generic TPredicateMethod<T> = function(const aElement: T; aData: Pointer): Boolean of object;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TPredicateRefFunc<T> = reference to function(const aElement: T): Boolean;
  {$ENDIF}
  generic TMapperFunc<T,U> = function(const aElement: T; aData: Pointer): U;
  generic TMapperMethod<T,U> = function(const aElement: T; aData: Pointer): U of object;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TMapperRefFunc<T,U> = reference to function(const aElement: T): U;
  {$ENDIF}
  generic TCompareFunc<T> = function(const aLeft, aRight: T; aData: Pointer): SizeInt;
  generic TCompareMethod<T> = function(const aLeft, aRight: T; aData: Pointer): SizeInt of object;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TCompareRefFunc<T> = reference to function(const aLeft, aRight: T): SizeInt;
  {$ENDIF}
  generic TEqualsFunc<T> = function(const aLeft, aRight: T; aData: Pointer): Boolean;
  generic TEqualsMethod<T> = function(const aLeft, aRight: T; aData: Pointer): Boolean of object;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TEqualsRefFunc<T> = reference to function(const aLeft, aRight: T): Boolean;
  {$ENDIF}
  generic TKeyHashFunc<K> = function(const AKey: K): UInt32;
  generic TKeyEqualsFunc<K> = function(const L, R: K): Boolean;
  generic TSkipListCompareFunc<K> = function(const A, B: K): SizeInt;
  generic TValueSupplierFunc<V> = function: V;
  generic TValueModifierProc<V> = procedure(var Value: V);
  generic TKeyValueCallback<K,V> = procedure(const aEntry: specialize TMapEntry<K,V>; aData: Pointer);
  generic TTreeValueSupplierFunc<V> = function: V;
  generic TTreeValueModifierProc<V> = procedure(var Value: V);
  generic THashFunc<T> = function(const aValue: T; aData: Pointer): UInt64;
  generic TBTreeCompareFunc<T> = function(const A, B: T; aData: Pointer): SizeInt;
  IGrowthStrategy = nextpas.core.collections.factory.IGrowthStrategy;
  TGrowthStrategy = nextpas.core.collections.factory.TGrowthStrategy;
  TGrowthStrategyClass = nextpas.core.collections.factory.TGrowthStrategyClass;
  TCustomGrowthStrategy = nextpas.core.collections.factory.TCustomGrowthStrategy;
  TCalcGrowStrategy = nextpas.core.collections.factory.TCalcGrowStrategy;
  TDoublingGrowStrategy = nextpas.core.collections.factory.TDoublingGrowStrategy;
  TFixedGrowStrategy = nextpas.core.collections.factory.TFixedGrowStrategy;
  TFactorGrowStrategy = nextpas.core.collections.factory.TFactorGrowStrategy;
  TPowerOfTwoGrowStrategy = nextpas.core.collections.factory.TPowerOfTwoGrowStrategy;
  TGoldenRatioGrowStrategy = nextpas.core.collections.factory.TGoldenRatioGrowStrategy;
  TAlignedWrapperStrategy = nextpas.core.collections.factory.TAlignedWrapperStrategy;
  TExactGrowStrategy = nextpas.core.collections.factory.TExactGrowStrategy;

const
  ARRAY_DEFAULT_SWAP_BUFFER_SIZE = nextpas.core.collections.factory.ARRAY_DEFAULT_SWAP_BUFFER_SIZE;
  INSERTION_SORT_THRESHOLD = nextpas.core.collections.factory.INSERTION_SORT_THRESHOLD;
  VEC_DEFAULT_CAPACITY = nextpas.core.collections.factory.VEC_DEFAULT_CAPACITY;
  DEFAULT_SWAP_BUFFER_SIZE = nextpas.core.collections.factory.DEFAULT_SWAP_BUFFER_SIZE;
  VECDEQUE_DEFAULT_CAPACITY = nextpas.core.collections.factory.VECDEQUE_DEFAULT_CAPACITY;
  DEFAULT_MAX_LOAD_FACTOR = nextpas.core.collections.factory.DEFAULT_MAX_LOAD_FACTOR;
  SKIPLIST_MAX_LEVEL = nextpas.core.collections.factory.SKIPLIST_MAX_LEVEL;
  SKIPLIST_P = nextpas.core.collections.factory.SKIPLIST_P;
  BITSET_BITS_PER_WORD = nextpas.core.collections.factory.BITSET_BITS_PER_WORD;
  BITSET_DEFAULT_CAPACITY = nextpas.core.collections.factory.BITSET_DEFAULT_CAPACITY;
  SLOT_REGISTRY_DEFAULT_CAPACITY = nextpas.core.collections.factory.SLOT_REGISTRY_DEFAULT_CAPACITY;
  PRIORITYQUEUE_DEFAULT_CAPACITY = nextpas.core.collections.factory.PRIORITYQUEUE_DEFAULT_CAPACITY;
  PRIORITYQUEUE_MIN_CAPACITY = nextpas.core.collections.factory.PRIORITYQUEUE_MIN_CAPACITY;
  SMALLVEC_MIN_HEAP_CAPACITY = nextpas.core.collections.factory.SMALLVEC_MIN_HEAP_CAPACITY;
  TRIE_ALPHABET_SIZE = nextpas.core.collections.factory.TRIE_ALPHABET_SIZE;
  TRIE_ALPHABET_LAST_INDEX = nextpas.core.collections.factory.TRIE_ALPHABET_LAST_INDEX;
  TRIE_KEYS_GROWTH_STEP = nextpas.core.collections.factory.TRIE_KEYS_GROWTH_STEP;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy; inline;
function FactorGrow(aFactor: Double): IGrowthStrategy; inline;
function DoublingGrow: IGrowthStrategy; inline;
function ExactGrow: IGrowthStrategy; inline;
function GoldenRatioGrow: IGrowthStrategy; inline;

generic function MakeVec<T>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>; inline;
generic function MakeVec<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>; inline;
generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>; inline;
generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>; inline;
generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; inline;
generic function MakeArr<T>(aAllocator: TMemAllocator = nil): specialize IArray<T>; inline;
generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil): specialize IArray<T>; inline;
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil): specialize IArray<T>; inline;
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>; inline;
generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil): specialize IArray<T>; inline;
{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
  generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>; inline;
  generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>; inline;
  generic function MakeSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>; inline;
{$ENDIF}
generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: TMemAllocator = nil): specialize ITreeMap<K,V>; inline;
generic function MakeTreeSet<T>(aAllocator: TMemAllocator = nil): specialize ITreeSet<T>; inline;
generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>; aAllocator: TMemAllocator = nil; aCompareData: Pointer = nil): specialize ITreeSet<T>; inline;
generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>; inline;
generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator = nil): specialize IRBTreeMap<K,V>; inline;
generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>; inline;
generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>; inline;
generic function MakeSkipList<K,V>: specialize ISkipList<K,V>; inline;
generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>; inline;
generic function MakeTrie<V>: specialize ITrie<V>; inline;
generic function MakeLruCache<K,V>(aMaxSize: SizeUInt = 100; aAllocator: TMemAllocator = nil; aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil; aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>; inline;
generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize ILinkedHashMap<K,V>; inline;
generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean = True): specialize ICircularBuffer<T>; inline;
generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt = PRIORITYQUEUE_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): specialize IPriorityQueue<T>; inline;
generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>; inline;
generic function MakeMultiSet<T>: specialize IMultiSet<T>; inline;
function MakeBitSet(aInitialCapacity: SizeUInt = BITSET_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): IBitSet; inline;
generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt = 0): specialize IConcurrentMap<K,V>; inline;
{$IFDEF NEXTPAS_COLLECTIONS_FACADE}
generic function MakeVecDeque<T>: specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>: specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline; overload;
generic function MakeQueue<T>: specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline; overload;
generic function MakeStack<T>: specialize IStack<T>; inline; overload;
generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>; inline; overload;
generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil): specialize IStack<T>; inline; overload;
generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil): specialize IStack<T>; inline; overload;
generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil): specialize IStack<T>; inline; overload;
generic function MakeList<T>: specialize IList<T>; inline; overload;
generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>; inline; overload;
generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; inline; overload;
generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>; inline; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; inline; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>; inline; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>; inline; overload;
generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; inline; overload;
generic function MakeForwardList<T>: specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IForwardList<T>; inline; overload;
generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline; overload;
{$ENDIF}

implementation

uses
  nextpas.core.collections.vec,
  nextpas.core.collections.arr,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss.adapter,
  nextpas.core.collections.hashset,
  nextpas.core.collections.linkedhashmap,
  nextpas.core.collections.linkedhashset,
  nextpas.core.collections.multimap,
  nextpas.core.collections.multiset,
  nextpas.core.collections.orderedmap.rb,
  nextpas.core.collections.treemap,
  nextpas.core.collections.tree_set,
  nextpas.core.collections.btree,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.trie,
  nextpas.core.collections.lrucache,
  nextpas.core.collections.list,
  nextpas.core.collections.forward_list,
  nextpas.core.collections.stack,
  nextpas.core.collections.queue,
  nextpas.core.collections.deque,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.bitset,
  nextpas.core.collections.concurrent.hashmap,
  nextpas.core.collections.smallvec,
  nextpas.core.collections.element_manager,
  nextpas.core.mem.default;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.factory.FixedGrow(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.factory.FactorGrow(aFactor);
end;

function DoublingGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.factory.DoublingGrow;
end;

function ExactGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.factory.ExactGrow;
end;

function GoldenRatioGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.factory.GoldenRatioGrow;
end;

generic function MakeVec<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize TVec<T>.Create(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize TVec<T>.Create(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize TVec<T>.Create(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize TVec<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeArr<T>(aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize TArray<T>.Create(0, aAllocator);
end;

generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize TArray<T>.Create(aSrc, aAllocator);
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize TArray<T>.Create(aSrcCollection, aAllocator);
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>; inline;
begin
  Result := specialize TArray<T>.Create(aSrcCollection, aAllocator, aData);
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize TArray<T>.Create(aSrc, aElementCount, aAllocator);
end;

{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeHashSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>; inline;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>; inline;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, aAllocator);
end;
{$ENDIF}

generic function MakeTreeMap<K,V>(aCapacity: SizeUInt; aCompare: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize ITreeMap<K,V>; inline;
begin
  Result := specialize TTreeMap<K,V>.Create(aAllocator, aCompare);
end;

generic function MakeTreeSet<T>(aAllocator: TMemAllocator): specialize ITreeSet<T>; inline;
begin
  if aAllocator <> nil then Result := specialize TTreeSet<T>.Create(aAllocator) else Result := specialize TTreeSet<T>.Create;
end;

generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>; aAllocator: TMemAllocator; aCompareData: Pointer): specialize ITreeSet<T>; inline;
begin
  Result := specialize TTreeSet<T>.Create(aAllocator, aCompare, aCompareData);
end;

generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>; inline;
begin
  Result := specialize TLinkedHashSet<T>.Create;
end;

generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize IRBTreeMap<K,V>; inline;
begin
  if aAllocator <> nil then Result := specialize TRBTreeMap<K,V>.Create(aKeyComparer, aAllocator) else Result := specialize TRBTreeMap<K,V>.Create(aKeyComparer);
end;

generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>; inline;
begin
  Result := specialize TBTreeMap<K,V>.Create(specialize TBTreeMap<K,V>.TKeyCompareFunc(aCompare));
end;

generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>; inline;
begin
  Result := specialize TBTreeSet<T>.Create(specialize TBTreeSet<T>.TCompareFunc(aCompare));
end;

generic function MakeSkipList<K,V>: specialize ISkipList<K,V>; inline;
begin
  Result := specialize TSkipList<K,V>.Create;
end;

generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>; inline;
begin
  Result := specialize TSkipList<K,V>.Create(aCompare);
end;

generic function MakeTrie<V>: specialize ITrie<V>; inline;
begin
  Result := specialize TTrie<V>.Create;
end;

generic function MakeLruCache<K,V>(aMaxSize: SizeUInt; aAllocator: TMemAllocator; aHash: specialize THashFunc<K>; aEquals: specialize TEqualsFunc<K>; aHashData: Pointer; aEqualsData: Pointer): specialize ILruCache<K,V>; inline;
begin
  Result := specialize TLruCache<K,V>.Create(aMaxSize, aAllocator, aHash, aEquals, aHashData, aEqualsData);
end;

generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize ILinkedHashMap<K,V>; inline;
begin
  if aAllocator <> nil then Result := specialize TLinkedHashMap<K,V>.Create(aCapacity, aAllocator) else Result := specialize TLinkedHashMap<K,V>.Create(aCapacity);
end;

generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean): specialize ICircularBuffer<T>; inline;
begin
  Result := specialize TCircularBuffer<T>.Create(aCapacity, aOverwriteOldest);
end;

generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IPriorityQueue<T>; inline;
begin
  Result := specialize TPriorityQueue<T>.Create(aComparer, aCapacity, aAllocator);
end;

generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>; inline;
begin
  Result := specialize TMultiMap<K,V>.Create;
end;

generic function MakeMultiSet<T>: specialize IMultiSet<T>; inline;
begin
  Result := specialize TMultiSet<T>.Create;
end;

function MakeBitSet(aInitialCapacity: SizeUInt; aAllocator: TMemAllocator): IBitSet; inline;
begin
  if aAllocator <> nil then Result := TBitSet.Create(aInitialCapacity, aAllocator) else Result := TBitSet.Create(aInitialCapacity);
end;

generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt): specialize IConcurrentMap<K,V>; inline;
begin
  Result := specialize TConcurrentHashMap<K,V>.Create(nil, nil, aInitialCapacityPerSegment);
end;

{$IFDEF NEXTPAS_COLLECTIONS_FACADE}
generic function MakeVecDeque<T>: specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(DefaultAllocator());
end;

generic function MakeDeque<T>: specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(0, TMemAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline;
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

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline;
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

generic function MakeQueue<T>: specialize IQueue<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(0, TMemAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline;
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

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline;
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

generic function MakeStack<T>: specialize IStack<T>; inline;
begin
  Result := specialize TStack<T>.Create(TMemAllocator(nil));
end;

generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>; inline;
begin
  Result := specialize TStack<T>.Create(aAllocator);
end;

generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IStack<T>; inline;
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

generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IStack<T>; inline;
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

generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IStack<T>; inline;
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

generic function MakeList<T>: specialize IList<T>; inline;
begin
  Result := specialize MakeList<T>(TMemAllocator(nil));
end;

generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize TList<T>.Create(aAllocator);
end;

generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; inline;
begin
  Result := specialize TList<T>.Create(aSrc);
end;

generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize TList<T>.Create(aSrc, aAllocator);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; inline;
begin
  Result := specialize TList<T>.Create(aSrc, aElementCount);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize TList<T>.Create(aSrc, aElementCount, aAllocator);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>; inline;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LObj := specialize TList<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData);
  Result := LObj;
end;

generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; inline;
begin
  if aAllocator <> nil then
    Exit(specialize TList<T>.Create(aAllocator))
  else
    Exit(specialize TList<T>.Create);
end;

generic function MakeForwardList<T>: specialize IForwardList<T>; inline;
begin
  Result := specialize MakeForwardList<T>(TMemAllocator(nil));
end;

generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aAllocator);
end;

generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aSrc);
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aSrc, aAllocator);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aSrc, aElementCount);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aSrc, aElementCount, aAllocator);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline;
var LI: specialize TForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline;
var LI: specialize TForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, DefaultAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize TForwardList<T>.Create(aSrcCollection, aAllocator);
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline;
var LI: specialize TForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrcCollection, DefaultAllocator(), aData);
  Result := LI;
end;
{$ENDIF}

end.
