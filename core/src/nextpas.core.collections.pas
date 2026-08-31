unit nextpas.core.collections;
{**
 * @desc 容器门面：Vec、HashMap、Deque、BTree、LRU、Pool、SlotRegistry。
 *}

{$I nextpas.core.settings.inc}
{$DEFINE NEXTPAS_COLLECTIONS_FACADE}
// Suppress unused parameter hints - facade unit
{$WARN 5024 OFF}

interface

uses
  // 基础与通用抽象
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
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
  nextpas.core.collections.arr,
  nextpas.core.collections.slice,
  nextpas.core.collections.iterators,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.builder,
  nextpas.core.collections.node,
  nextpas.core.collections.smallvec.base,
  nextpas.core.collections.trie.base,
  // 容器接口/实现
  nextpas.core.collections.vec,
  nextpas.core.collections.smallvec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.forward_list,
  nextpas.core.collections.deque,
  nextpas.core.collections.queue,
  nextpas.core.collections.stack,
  nextpas.core.collections.list,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.slotregistry,
  nextpas.core.collections.element_manager,
  // HashMap / HashSet (OA default)
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss.adapter,
  nextpas.core.collections.hashset,
  nextpas.core.collections.linkedhashmap,
  nextpas.core.collections.linkedhashset,
  nextpas.core.collections.multimap,
  nextpas.core.collections.multiset,
  // Ordered containers (RB)
  nextpas.core.collections.tree.rb,
  nextpas.core.collections.orderedmap.rb,
  // 新增：有序容器和缓存
  nextpas.core.collections.treemap,
  nextpas.core.collections.tree_set,
  nextpas.core.collections.btree,
  nextpas.core.collections.btree.intf,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.trie,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.lrucache,
  // BitSet (高效位集合)
  nextpas.core.collections.bitset,
  // ConcurrentHashMap (thread-safe map)
  nextpas.core.collections.concurrent.map.intf,
  nextpas.core.collections.concurrent.hashmap,
 nextpas.core.mem.allocator.base;

type
  // 统一对外导出的关键接口类型
  ICollection = nextpas.core.collections.intf.ICollection;
  IBitSet = nextpas.core.collections.bitset.intf.IBitSet;
  ISlotRegistryItem = nextpas.core.collections.slotregistry.ISlotRegistryItem;

  // 非泛型公共载体类型
  PPtrIter = nextpas.core.collections.base.PPtrIter;
  TPtrIter = nextpas.core.collections.base.TPtrIter;
  TCollection = nextpas.core.collections.base.TCollection;
  TCollectionClass = nextpas.core.collections.base.TCollectionClass;
  TMergePosition = nextpas.core.collections.vecdeque.base.TMergePosition;
  TSortAlgorithm = nextpas.core.collections.vecdeque.base.TSortAlgorithm;

  // 非泛型公共回调类型
  TRandomGeneratorFunc = nextpas.core.collections.base.TRandomGeneratorFunc;
  TRandomGeneratorMethod = nextpas.core.collections.base.TRandomGeneratorMethod;
  TRandomGeneratorRefFunc = nextpas.core.collections.base.TRandomGeneratorRefFunc;
  TGrowFunc = nextpas.core.collections.base.TGrowFunc;
  TGrowMethod = nextpas.core.collections.base.TGrowMethod;
  TGrowRefFunc = nextpas.core.collections.base.TGrowRefFunc;
  TGrowProxyMethod = nextpas.core.collections.base.TGrowProxyMethod;

  // 算法公共回调类型 — re-export from owner base units，门面不自有定义
  generic TPredicateFunc<T> = specialize nextpas.core.collections.base.TPredicateFunc<T>;
  generic TPredicateMethod<T> = specialize nextpas.core.collections.base.TPredicateMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TPredicateRefFunc<T> = specialize nextpas.core.collections.base.TPredicateRefFunc<T>;
  {$ENDIF}
  generic TMapperFunc<T,U> = specialize nextpas.core.collections.base.TMapperFunc<T,U>;
  generic TMapperMethod<T,U> = specialize nextpas.core.collections.base.TMapperMethod<T,U>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TMapperRefFunc<T,U> = specialize nextpas.core.collections.base.TMapperRefFunc<T,U>;
  {$ENDIF}
  generic TCompareFunc<T> = specialize nextpas.core.collections.base.TCompareFunc<T>;
  generic TCompareMethod<T> = specialize nextpas.core.collections.base.TCompareMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TCompareRefFunc<T> = specialize nextpas.core.collections.base.TCompareRefFunc<T>;
  {$ENDIF}
  generic TEqualsFunc<T> = specialize nextpas.core.collections.base.TEqualsFunc<T>;
  generic TEqualsMethod<T> = specialize nextpas.core.collections.base.TEqualsMethod<T>;
  {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
  generic TEqualsRefFunc<T> = specialize nextpas.core.collections.base.TEqualsRefFunc<T>;
  {$ENDIF}

  // HashMap / TreeMap / LRU public callback types — re-export from owner base units
  generic TKeyHashFunc<K> = specialize nextpas.core.collections.hashmap.base.TKeyHashFunc<K>;
  generic TKeyEqualsFunc<K> = specialize nextpas.core.collections.hashmap.base.TKeyEqualsFunc<K>;
  generic TSkipListCompareFunc<K> = specialize nextpas.core.collections.skiplist.base.TSkipListCompareFunc<K>;
  generic TValueSupplierFunc<V> = specialize nextpas.core.collections.hashmap.base.TValueSupplierFunc<V>;
  generic TValueModifierProc<V> = specialize nextpas.core.collections.hashmap.base.TValueModifierProc<V>;
  generic TKeyValueCallback<K,V> = specialize nextpas.core.collections.treemap.base.TKeyValueCallback<K,V>;
  generic TTreeValueSupplierFunc<V> = specialize nextpas.core.collections.treemap.base.TTreeValueSupplierFunc<V>;
  generic TTreeValueModifierProc<V> = specialize nextpas.core.collections.treemap.base.TTreeValueModifierProc<V>;
  generic THashFunc<T> = specialize nextpas.core.collections.lrucache.base.THashFunc<T>;
  generic TBTreeCompareFunc<T> = specialize nextpas.core.collections.base.TBTreeCompareFunc<T>;

  // 增长策略导出（接口优先 + 兼容类基实现）
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

{$IFDEF NEXTPAS_COLLECTIONS_TYPE_ALIASES}
  // 可选：常用 specialization 的类型别名，避免重复 specialization（按需开启）
{$ENDIF}

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

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

// 工厂函数（TDD：先声明，后实现；优先 MakeVec/MakeVecDeque/MakeArray）
// 为减少调用方对实现细节的耦合，返回接口类型
// 约定：Capacity=0 表示按实现默认容量策略；GrowStrategy=nil 则使用默认策略

// ==== Vec / VecDeque (capacity-based) ====

// 简化的工厂函数（避免泛型函数参数默认值问题）
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

// ==== HashMap / HashSet ====
// Default mapping (document in CONTRACT):
//   MakeMap / MakeHashMap / MakeSwissHashMap → TSwissHashMap (IHashMap)
//   MakeSet / MakeHashSet → THashSet (IHashSet; Swiss-backed via TSwissHashMap<K,Byte>)
// OA THashMap remains available as a concrete class for expert use.
{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
  generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
    aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
    aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  { Default semantic map factory. Currently: TSwissHashMap → IHashMap. }
  generic function MakeMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
    aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
  { Default semantic set factory. Currently: THashSet → IHashSet. }
  generic function MakeSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
{$ENDIF}

// ==== TreeMap / TreeSet (Ordered containers) ====
generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: TMemAllocator = nil): specialize ITreeMap<K,V>;
generic function MakeTreeSet<T>(aAllocator: TMemAllocator = nil): specialize ITreeSet<T>;
generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>;
  aAllocator: TMemAllocator = nil; aCompareData: Pointer = nil): specialize ITreeSet<T>;
generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;
generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator = nil): specialize IRBTreeMap<K,V>;
generic function MakeBTreeMap<K,V>(aCompare: specialize TBTreeCompareFunc<K>): specialize IBTreeMap<K,V>;
generic function MakeBTreeSet<T>(aCompare: specialize TBTreeCompareFunc<T>): specialize IBTreeSet<T>;
generic function MakeSkipList<K,V>: specialize ISkipList<K,V>;
generic function MakeSkipList<K,V>(aCompare: specialize TSkipListCompareFunc<K>): specialize ISkipList<K,V>;
generic function MakeTrie<V>: specialize ITrie<V>;

// ==== LRU Cache (Caching) ====
generic function MakeLruCache<K,V>(aMaxSize: SizeUInt = 100; aAllocator: TMemAllocator = nil;
  aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil;
  aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>;

// ==== LinkedHashMap (Insertion-order preserving hash map) ====
generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize ILinkedHashMap<K,V>;

// ==== CircularBuffer / PriorityQueue ====
generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean = True): specialize ICircularBuffer<T>;
generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt = PRIORITYQUEUE_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): specialize IPriorityQueue<T>;

// ==== MultiMap / MultiSet ====
generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>;
generic function MakeMultiSet<T>: specialize IMultiSet<T>;

// ==== BitSet (Efficient bit set) ====
function MakeBitSet(aInitialCapacity: SizeUInt = BITSET_DEFAULT_CAPACITY; aAllocator: TMemAllocator = nil): IBitSet;
//

// ==== ConcurrentHashMap (Thread-safe map) ====
generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt = 0): specialize IConcurrentMap<K,V>;


// generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TAllocator; aData: Pointer): specialize IArray<T>; overload;

{$IFDEF NEXTPAS_COLLECTIONS_FACADE}

// ==== Deque (source-based) ====

generic function MakeVecDeque<T>: specialize IDeque<T>; overload;

generic function MakeDeque<T>: specialize IDeque<T>; overload;
generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;

// ==== Queue (source-based) ====

generic function MakeQueue<T>: specialize IQueue<T>; overload;
generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;

// ==== Stack ====
generic function MakeStack<T>: specialize IStack<T>; overload;
generic function MakeStack<T>(aAllocator: TMemAllocator): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrc: array of T; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator = nil): specialize IStack<T>; overload;

// ==== List (source-based + capacity) ====

generic function MakeList<T>: specialize IList<T>; overload;
generic function MakeList<T>(aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>; overload;
generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; overload;

// ==== ForwardList (source-based) ====

generic function MakeForwardList<T>: specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IForwardList<T>; overload;

// generic function MakeDeque<T>(aCapacity: SizeUInt = 0; aAllocator: TAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>;

// generic function MakeQueue<T>(aCapacity: SizeUInt = 0; aAllocator: TAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>;



{$ENDIF}




implementation

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.FixedGrow(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.FactorGrow(aFactor);
end;

function DoublingGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.DoublingGrow;
end;

function ExactGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.ExactGrow;
end;

function GoldenRatioGrow: IGrowthStrategy;
begin
  Result := nextpas.core.collections.base.GoldenRatioGrow;
end;

// 工厂实现
// 说明：当前直接创建真实实例，返回接口以降低调用方耦合
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


// Arr from pointer+count
generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator));
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator, aData));
end;



generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  // 支持传入增长策略；内部会将容量统一归一到 2 的幂
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


{$IFDEF NEXTPAS_COLLECTIONS_FACADE}

// VecDeque facade helpers
generic function MakeVecDeque<T>: specialize IDeque<T>;
var
  LDeque: specialize TVecDeque<T>;
begin
  LDeque := specialize TVecDeque<T>.Create(DefaultAllocator());
  Result := LDeque;
end;

// ForwardList factories
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

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator)
  else LI := specialize TForwardList<T>.Create(aSrcCollection);
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

// List factories
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


// Deque factories (source-based)
generic function MakeDeque<T>: specialize IDeque<T>;
begin
  Result := specialize MakeDeque<T>(0, TMemAllocator(nil), TGrowthStrategy(nil));
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

// Queue factories (delegate to Deque)
generic function MakeQueue<T>: specialize IQueue<T>;
begin
  Result := specialize MakeQueue<T>(0, TMemAllocator(nil), TGrowthStrategy(nil));
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

// Stack factories (based on TStack)
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

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TMemAllocator; aData: Pointer): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LObj := specialize TList<T>.Create(aSrc, aElementCount, DefaultAllocator(), aData);
  Result := LObj;
end;

{$ENDIF}




generic function MakeArr<T>(aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(0, aAllocator));
end;

// From dynamic array (copy)
generic function MakeArr<T>(const aSrc: array of T; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aAllocator));
end;

// From another collection (copy)
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator));
end;


// From another collection with data (copy)
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: TMemAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator, aData));
end;


// Facade capacity-based factories (unconditionally compiled)




generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>;
begin
  // 当前 List 实现不区分容量，保持接口一致性
  if aAllocator <> nil then
    Exit(specialize TList<T>.Create(aAllocator))
  else
    Exit(specialize TList<T>.Create);
end;


generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: TMemAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


{$IFNDEF NEXTPAS_COLLECTIONS_DISABLE_HASH}
// HashMap / HashSet factories — implementation will be provided by hashmap unit

generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
  aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeSwissHashMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
  aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize TSwissHashMap<K,V>.Create(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize MakeHashMap<K,V>(aCapacity, aAllocator);
end;

generic function MakeMap<K,V>(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>;
  aEquals: specialize TKeyEqualsFunc<K>; aAllocator: TMemAllocator = nil): specialize IHashMap<K,V>;
begin
  Result := specialize MakeHashMap<K,V>(aCapacity, aHash, aEquals, aAllocator);
end;

generic function MakeSet<K>(aCapacity: SizeUInt = 0; aAllocator: TMemAllocator = nil): specialize IHashSet<K>;
begin
  Result := specialize MakeHashSet<K>(aCapacity, aAllocator);
end;
{$ENDIF}

// ==== TreeMap / TreeSet factories ====

generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: TMemAllocator = nil): specialize ITreeMap<K,V>;
begin
  Result := specialize TTreeMap<K,V>.Create(aAllocator, aCompare);
end;

generic function MakeTreeSet<T>(aAllocator: TMemAllocator = nil): specialize ITreeSet<T>;
begin
  if aAllocator <> nil then
    Result := specialize TTreeSet<T>.Create(aAllocator)
  else
    Result := specialize TTreeSet<T>.Create;
end;

generic function MakeTreeSet<T>(aCompare: specialize TCompareFunc<T>;
  aAllocator: TMemAllocator; aCompareData: Pointer): specialize ITreeSet<T>;
begin
  Result := specialize TTreeSet<T>.Create(aAllocator, aCompare, aCompareData);
end;

generic function MakeLinkedHashSet<T>: specialize ILinkedHashSet<T>;
begin
  Result := specialize TLinkedHashSet<T>.Create;
end;

generic function MakeRBTreeMap<K,V>(aKeyComparer: specialize TCompareFunc<K>; aAllocator: TMemAllocator = nil): specialize IRBTreeMap<K,V>;
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

// ==== LRU Cache factories ====

generic function MakeLruCache<K,V>(aMaxSize: SizeUInt; aAllocator: TMemAllocator = nil;
  aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil;
  aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>;
begin
  Result := specialize TLruCache<K,V>.Create(aMaxSize, aAllocator, aHash, aEquals, aHashData, aEqualsData);
end;

// ==== LinkedHashMap factories ====

generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize ILinkedHashMap<K,V>;
begin
  if aAllocator <> nil then
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity, aAllocator)
  else
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity);
end;

// ==== CircularBuffer / PriorityQueue factories ====

generic function MakeCircularBuffer<T>(aCapacity: SizeUInt; aOverwriteOldest: Boolean): specialize ICircularBuffer<T>;
begin
  Result := specialize TCircularBuffer<T>.Create(aCapacity, aOverwriteOldest);
end;

generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt; aAllocator: TMemAllocator): specialize IPriorityQueue<T>;
begin
  Result := specialize TPriorityQueue<T>.Create(aComparer, aCapacity, aAllocator);
end;

// ==== MultiMap / MultiSet factories ====

generic function MakeMultiMap<K,V>: specialize IMultiMap<K,V>;
begin
  Result := specialize TMultiMap<K,V>.Create;
end;

generic function MakeMultiSet<T>: specialize IMultiSet<T>;
begin
  Result := specialize TMultiSet<T>.Create;
end;

// ==== BitSet factories ====

function MakeBitSet(aInitialCapacity: SizeUInt; aAllocator: TMemAllocator): IBitSet;
begin
  if aAllocator <> nil then
    Result := TBitSet.Create(aInitialCapacity, aAllocator)
  else
    Result := TBitSet.Create(aInitialCapacity);
end;


// ==== ConcurrentHashMap factories ====

generic function MakeConcurrentHashMap<K,V>(aInitialCapacityPerSegment: SizeUInt = 0): specialize IConcurrentMap<K,V>;
begin
  Result := specialize TConcurrentHashMap<K,V>.Create(nil, nil, aInitialCapacityPerSegment);
end;
// end of factories

end.
