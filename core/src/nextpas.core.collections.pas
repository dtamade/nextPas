unit nextpas.core.collections;
{**
 * @desc 容器门面：纯转发至 collections.factory，聚合 base/intf 常量与接口别名。
 *}

{$I nextpas.core.settings.inc}
{$DEFINE NEXTPAS_COLLECTIONS_FACADE}
{$WARN 5024 OFF}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.arr.base,
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.vec.base,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.vecdeque.base,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.list.intf,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.stack.intf,
  nextpas.core.collections.circularbuffer.intf,
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashset.intf,
  nextpas.core.collections.linkedhashmap.intf,
  nextpas.core.collections.linkedhashset.intf,
  nextpas.core.collections.multimap.intf,
  nextpas.core.collections.multiset.intf,
  nextpas.core.collections.orderedmap.rb.intf,
  nextpas.core.collections.treemap.base,
  nextpas.core.collections.treemap.intf,
  nextpas.core.collections.tree_set.intf,
  nextpas.core.collections.skiplist.base,
  nextpas.core.collections.skiplist.intf,
  nextpas.core.collections.trie.base,
  nextpas.core.collections.trie.intf,
  nextpas.core.collections.prefixrouter.base,
  nextpas.core.collections.prefixrouter.intf,
  nextpas.core.collections.lrucache.base,
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.priorityqueue.base,
  nextpas.core.collections.priorityqueue.intf,
  nextpas.core.collections.bitset.base,
  nextpas.core.collections.bitset.intf,
  nextpas.core.collections.btree.intf,
  nextpas.core.collections.concurrent.map.intf,
  nextpas.core.collections.smallvec.base,
  nextpas.core.collections.slotregistry,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  ICollection = nextpas.core.collections.intf.ICollection;
  IBitSet = nextpas.core.collections.bitset.intf.IBitSet;
  ISlotRegistryItem = nextpas.core.collections.slotregistry.ISlotRegistryItem;
  PPtrIter = nextpas.core.collections.base.PPtrIter;
  TPtrIter = nextpas.core.collections.base.TPtrIter;
  TCollection = nextpas.core.collections.base.TCollection;
  TCollectionClass = nextpas.core.collections.base.TCollectionClass;
  TMergePosition = nextpas.core.collections.vecdeque.base.TMergePosition;
  TSortAlgorithm = nextpas.core.collections.vecdeque.base.TSortAlgorithm;
  TRandomGeneratorFunc = nextpas.core.collections.base.TRandomGeneratorFunc;
  TRandomGeneratorMethod = nextpas.core.collections.base.TRandomGeneratorMethod;
  TRandomGeneratorRefFunc = nextpas.core.collections.base.TRandomGeneratorRefFunc;
  TGrowFunc = nextpas.core.collections.base.TGrowFunc;
  TGrowMethod = nextpas.core.collections.base.TGrowMethod;
  TGrowRefFunc = nextpas.core.collections.base.TGrowRefFunc;
  TGrowProxyMethod = nextpas.core.collections.base.TGrowProxyMethod;

  generic TPredicateFunc<T> = nextpas.core.collections.base.TPredicateFunc<T>;
  generic TPredicateMethod<T> = nextpas.core.collections.base.TPredicateMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TPredicateRefFunc<T> = nextpas.core.collections.base.TPredicateRefFunc<T>;
  {$ENDIF}
  generic TMapperFunc<T,U> = nextpas.core.collections.base.TMapperFunc<T,U>;
  generic TMapperMethod<T,U> = nextpas.core.collections.base.TMapperMethod<T,U>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TMapperRefFunc<T,U> = nextpas.core.collections.base.TMapperRefFunc<T,U>;
  {$ENDIF}
  generic TCompareFunc<T> = nextpas.core.collections.base.TCompareFunc<T>;
  generic TCompareMethod<T> = nextpas.core.collections.base.TCompareMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TCompareRefFunc<T> = nextpas.core.collections.base.TCompareRefFunc<T>;
  {$ENDIF}
  generic TEqualsFunc<T> = nextpas.core.collections.base.TEqualsFunc<T>;
  generic TEqualsMethod<T> = nextpas.core.collections.base.TEqualsMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TEqualsRefFunc<T> = nextpas.core.collections.base.TEqualsRefFunc<T>;
  {$ENDIF}
  generic TKeyHashFunc<K> = nextpas.core.collections.hashmap.base.TKeyHashFunc<K>;
  generic TKeyEqualsFunc<K> = nextpas.core.collections.hashmap.base.TKeyEqualsFunc<K>;
  generic TSkipListCompareFunc<K> = nextpas.core.collections.skiplist.base.TSkipListCompareFunc<K>;
  generic TValueSupplierFunc<V> = nextpas.core.collections.hashmap.base.TValueSupplierFunc<V>;
  generic TValueModifierProc<V> = nextpas.core.collections.hashmap.base.TValueModifierProc<V>;
  generic TKeyValueCallback<K,V> = nextpas.core.collections.treemap.base.TKeyValueCallback<K,V>;
  generic TTreeValueSupplierFunc<V> = nextpas.core.collections.treemap.base.TTreeValueSupplierFunc<V>;
  generic TTreeValueModifierProc<V> = nextpas.core.collections.treemap.base.TTreeValueModifierProc<V>;
  generic THashFunc<T> = nextpas.core.collections.lrucache.base.THashFunc<T>;
  generic TBTreeCompareFunc<T> = nextpas.core.collections.base.TBTreeCompareFunc<T>;

  IGrowthStrategy          = nextpas.core.collections.base.IGrowthStrategy;
  TGrowthStrategy          = nextpas.core.collections.base.TGrowthStrategy;
  TGrowthStrategyClass     = nextpas.core.collections.base.TGrowthStrategyClass;
  TCustomGrowthStrategy    = nextpas.core.collections.base.TCustomGrowthStrategy;
  TCalcGrowStrategy        = nextpas.core.collections.base.TCalcGrowStrategy;
  TDoublingGrowStrategy    = nextpas.core.collections.base.TDoublingGrowStrategy;
  TFixedGrowStrategy       = nextpas.core.collections.base.TFixedGrowStrategy;
  TFactorGrowStrategy      = nextpas.core.collections.base.TFactorGrowStrategy;
  TPowerOfTwoGrowStrategy  = nextpas.core.collections.base.TPowerOfTwoGrowStrategy;
  TGoldenRatioGrowStrategy = nextpas.core.collections.base.TGoldenRatioGrowStrategy;
  TAlignedWrapperStrategy  = nextpas.core.collections.base.TAlignedWrapperStrategy;
  TExactGrowStrategy       = nextpas.core.collections.base.TExactGrowStrategy;

const
  ARRAY_DEFAULT_SWAP_BUFFER_SIZE = nextpas.core.collections.arr.base.ARRAY_DEFAULT_SWAP_BUFFER_SIZE;
  INSERTION_SORT_THRESHOLD = nextpas.core.collections.arr.base.INSERTION_SORT_THRESHOLD;
  VEC_DEFAULT_CAPACITY = nextpas.core.collections.vec.base.VEC_DEFAULT_CAPACITY;
  DEFAULT_SWAP_BUFFER_SIZE = nextpas.core.collections.vec.base.DEFAULT_SWAP_BUFFER_SIZE;
  VECDEQUE_DEFAULT_CAPACITY = nextpas.core.collections.vecdeque.base.VECDEQUE_DEFAULT_CAPACITY;
  DEFAULT_MAX_LOAD_FACTOR = nextpas.core.collections.hashmap.base.DEFAULT_MAX_LOAD_FACTOR;
  SKIPLIST_MAX_LEVEL = nextpas.core.collections.skiplist.base.SKIPLIST_MAX_LEVEL;
  SKIPLIST_P = nextpas.core.collections.skiplist.base.SKIPLIST_P;
  BITSET_BITS_PER_WORD = nextpas.core.collections.bitset.base.BITSET_BITS_PER_WORD;
  BITSET_DEFAULT_CAPACITY = nextpas.core.collections.bitset.base.BITSET_DEFAULT_CAPACITY;
  SLOT_REGISTRY_DEFAULT_CAPACITY =
    nextpas.core.collections.slotregistry.SLOT_REGISTRY_DEFAULT_CAPACITY;
  PRIORITYQUEUE_DEFAULT_CAPACITY = nextpas.core.collections.priorityqueue.base.PRIORITYQUEUE_DEFAULT_CAPACITY;
  PRIORITYQUEUE_MIN_CAPACITY = nextpas.core.collections.priorityqueue.base.PRIORITYQUEUE_MIN_CAPACITY;
  SMALLVEC_MIN_HEAP_CAPACITY = nextpas.core.collections.smallvec.base.SMALLVEC_MIN_HEAP_CAPACITY;
  TRIE_ALPHABET_SIZE = nextpas.core.collections.trie.base.TRIE_ALPHABET_SIZE;
  TRIE_ALPHABET_LAST_INDEX = nextpas.core.collections.trie.base.TRIE_ALPHABET_LAST_INDEX;
  TRIE_KEYS_GROWTH_STEP = nextpas.core.collections.trie.base.TRIE_KEYS_GROWTH_STEP;

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
{$ENDIF}

implementation

uses
  nextpas.core.collections.factory;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.base.FixedGrow(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.base.FactorGrow(aFactor);
end;

function DoublingGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.base.DoublingGrow;
end;

function ExactGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.base.ExactGrow;
end;

function GoldenRatioGrow: IGrowthStrategy; inline;
begin
  Result := nextpas.core.collections.base.GoldenRatioGrow;
end;

// Forward Vec
generic function MakeVec<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVec<T>(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVec<T>(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVec<T>(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVec<T>(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVecDeque<T>(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeArr<T>(aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aAllocator);
end;

generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aSrc, aAllocator);
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aSrcCollection, aAllocator);
end;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aSrcCollection, aAllocator, aData);
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aSrc, aElementCount, aAllocator);
end;

{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeHashMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeHashMap<K,V>(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeSwissHashMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeSwissHashMap<K,V>(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator): specialize IHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeMap<K,V>(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeHashSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeHashSet<K>(aCapacity, aAllocator);
end;

generic function MakeSet<K>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IHashSet<K>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeSet<K>(aCapacity, aAllocator);
end;
{$ENDIF}

generic function MakeTreeMap<K,V>(aCapacity: SizeUInt; aCompare: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize ITreeMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeTreeMap<K,V>(aCapacity, aCompare, aAllocator);
end;

generic function MakeTreeSet<T>(aAllocator: TMemAllocator): specialize ITreeSet<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeTreeSet<T>(aAllocator);
end;

generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>; aAllocator: TMemAllocator; aCompareData: Pointer): specialize ITreeSet<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeTreeSet<T>(aCompare, aAllocator, aCompareData);
end;

generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeLinkedHashSet<T>;
end;

generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator): specialize IRBTreeMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeRBTreeMap<K,V>(aKeyComparer, aAllocator);
end;

generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeBTreeMap<K,V>(aCompare);
end;

generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeBTreeSet<T>(aCompare);
end;

generic function MakeSkipList<K,V>: specialize ISkipList<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeSkipList<K,V>;
end;

generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeSkipList<K,V>(aCompare);
end;

generic function MakeTrie<V>: specialize ITrie<V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeTrie<V>;
end;

generic function MakeLruCache<K,V>(aMaxSize: SizeUInt; aAllocator: TMemAllocator; aHash: specialize THashFunc<K>; aEquals: specialize TEqualsFunc<K>; aHashData: Pointer; aEqualsData: Pointer): specialize ILruCache<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeLruCache<K,V>(aMaxSize, aAllocator, aHash, aEquals, aHashData, aEqualsData);
end;

generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize ILinkedHashMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeLinkedHashMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean): specialize ICircularBuffer<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeCircularBuffer<T>(aCapacity, aOverwriteOldest);
end;

generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IPriorityQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakePriorityQueue<T>(aComparer, aCapacity, aAllocator);
end;

generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeMultiMap<K,V>;
end;

generic function MakeMultiSet<T>: specialize IMultiSet<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeMultiSet<T>;
end;

function MakeBitSet(aInitialCapacity: SizeUInt; aAllocator: TMemAllocator): IBitSet; inline;
begin
  Result := nextpas.core.collections.factory.MakeBitSet(aInitialCapacity, aAllocator);
end;

generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt): specialize IConcurrentMap<K,V>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment);
end;

{$IFDEF NEXTPAS_COLLECTIONS_FACADE}
generic function MakeVecDeque<T>: specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeVecDeque<T>;
end;

generic function MakeDeque<T>: specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>;
end;

generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aSrcCollection, aAllocator, aGrowStrategy, aData);
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeDeque<T>(aSrc, aElementCount, aAllocator, aGrowStrategy, aData);
end;

generic function MakeQueue<T>: specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>;
end;

generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aSrc, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aSrcCollection, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aSrc, aElementCount, aAllocator, aGrowStrategy);
end;

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aSrcCollection, aAllocator, aGrowStrategy, aData);
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeQueue<T>(aSrc, aElementCount, aAllocator, aGrowStrategy, aData);
end;

generic function MakeStack<T>: specialize IStack<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeStack<T>;
end;

generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeStack<T>(aAllocator);
end;

generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IStack<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeStack<T>(aSrc, aAllocator);
end;

generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IStack<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeStack<T>(aSrcCollection, aAllocator);
end;

generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IStack<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeStack<T>(aSrc, aElementCount, aAllocator);
end;

generic function MakeList<T>: specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>;
end;

generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aAllocator);
end;

generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aSrc);
end;

generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aSrc, aAllocator);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aSrc, aElementCount);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aSrc, aElementCount, aAllocator);
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aSrc, aElementCount, aAllocator, aData);
end;

generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeList<T>(aCapacity, aAllocator, aGrowStrategy);
end;

generic function MakeForwardList<T>: specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>;
end;

generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aAllocator);
end;

generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aSrc);
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aSrc, aAllocator);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aSrc, aElementCount);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aSrc, aElementCount, aAllocator);
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeForwardList<T>(aSrc, aElementCount, aAllocator, aData);
end;
{$ENDIF}

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>; inline;
begin
  Result := specialize nextpas.core.collections.factory.MakeArr<T>(aSrc, aElementCount, aAllocator, aData);
end;

end.
