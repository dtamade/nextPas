unit nextpas.core.collections;

{$I nextpas.core.settings.inc}
{$DEFINE FAFAFA_COLLECTIONS_FACADE}
// Suppress unused parameter hints - facade unit
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes,
  // 基础与通用抽象
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
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
  nextpas.core.collections.multimap.intf,
  nextpas.core.collections.multiset.base,
  nextpas.core.collections.multiset.intf,
  nextpas.core.collections.orderedset.intf,
  nextpas.core.collections.rbset.intf,
  nextpas.core.collections.orderedset.rb.intf,
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
  nextpas.core.collections.element_manager,
  // HashMap / HashSet (OA default)
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashset,
  nextpas.core.collections.linkedhashmap,
  nextpas.core.collections.multimap,
  nextpas.core.collections.multiset,
  // Ordered containers (RB)
  nextpas.core.collections.tree.rb,
  nextpas.core.collections.rbset,
  nextpas.core.collections.orderedset,
  nextpas.core.collections.orderedset.rb,
  nextpas.core.collections.orderedmap.rb,
  // 新增：有序容器和缓存
  nextpas.core.collections.treemap,
  nextpas.core.collections.tree_set,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.trie,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.lrucache,
  // BitSet (高效位集合)
  nextpas.core.collections.bitset;

type
  // 统一对外导出的关键接口类型
  ICollection = nextpas.core.collections.intf.ICollection;
  IBitSet = nextpas.core.collections.bitset.intf.IBitSet;

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

  // 算法公共回调类型
  generic TPredicateFunc<T> = function(const aElement: T; aData: Pointer): Boolean;
  generic TPredicateMethod<T> = function(const aElement: T; aData: Pointer): Boolean of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TPredicateRefFunc<T> = reference to function(const aElement: T): Boolean;
  {$ENDIF}
  generic TMapperFunc<T,U> = function(const aElement: T; aData: Pointer): U;
  generic TMapperMethod<T,U> = function(const aElement: T; aData: Pointer): U of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TMapperRefFunc<T,U> = reference to function(const aElement: T): U;
  {$ENDIF}
  generic TCompareFunc<T> = function(const aLeft, aRight: T; aData: Pointer): SizeInt;
  generic TCompareMethod<T> = function(const aLeft, aRight: T; aData: Pointer): SizeInt of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TCompareRefFunc<T> = reference to function(const aLeft, aRight: T): SizeInt;
  {$ENDIF}
  generic TEqualsFunc<T> = function(const aLeft, aRight: T; aData: Pointer): Boolean;
  generic TEqualsMethod<T> = function(const aLeft, aRight: T; aData: Pointer): Boolean of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TEqualsRefFunc<T> = reference to function(const aLeft, aRight: T): Boolean;
  {$ENDIF}

  // HashMap / TreeMap / LRU public callback types
  generic TKeyHashFunc<K> = function(const AKey: K): UInt32;
  generic TKeyEqualsFunc<K> = function(const L, R: K): Boolean;
  generic TValueSupplierFunc<V> = function: V;
  generic TValueModifierProc<V> = procedure(var Value: V);
  generic TKeyValueCallback<K,V> = procedure(const aEntry: specialize TMapEntry<K,V>; aData: Pointer);
  generic TTreeValueSupplierFunc<V> = function: V;
  generic TTreeValueModifierProc<V> = procedure(var Value: V);
  generic THashFunc<T> = function(const aValue: T; aData: Pointer): UInt64;

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

{$IFDEF FAFAFA_CORE_TYPE_ALIASES}
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
generic function MakeVec<T>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(const aSrc: array of T; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;
generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IVec<T>;


generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>;

generic function MakeArr<T>(aAllocator: IAllocator = nil): specialize IArray<T>;
generic function MakeArr<T>(const aSrc: array of T; aAllocator: IAllocator = nil): specialize IArray<T>;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: IAllocator = nil): specialize IArray<T>;

generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aData: Pointer): specialize IArray<T>;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator = nil): specialize IArray<T>;

// ==== HashMap / HashSet (OA default) ====
{$IFNDEF FAFAFA_COLLECTIONS_DISABLE_HASH}
  generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil): specialize IHashMap<K,V>;
  generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil): specialize IHashSet<K>;
{$ENDIF}

// ==== TreeMap / TreeSet (Ordered containers) ====
generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: IAllocator = nil): specialize ITreeMap<K,V>;
// 注意：MakeTreeSet 移除了 aCapacity 和 aCompare 参数，因为 TTreeSet 当前不支持这些参数
generic function MakeTreeSet<T>(aAllocator: IAllocator = nil): specialize ITreeSet<T>;

// ==== LRU Cache (Caching) ====
generic function MakeLruCache<K,V>(aMaxSize: SizeUInt = 100; aAllocator: IAllocator = nil;
  aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil;
  aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>;

// ==== LinkedHashMap (Insertion-order preserving hash map) ====
generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil): specialize ILinkedHashMap<K,V>;

// ==== BitSet (Efficient bit set) ====
function MakeBitSet(aInitialCapacity: SizeUInt = BITSET_DEFAULT_CAPACITY; aAllocator: IAllocator = nil): IBitSet;
//


// generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: TAllocator; aData: Pointer): specialize IArray<T>; overload;

{$IFDEF FAFAFA_COLLECTIONS_FACADE}

// ==== Deque (source-based) ====

generic function MakeVecDeque<T>: specialize IDeque<T>; overload;

generic function MakeDeque<T>: specialize IDeque<T>; overload;
generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrc: array of T; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IDeque<T>; overload;
generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;
generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>; overload;

// ==== Queue (source-based) ====

generic function MakeQueue<T>: specialize IQueue<T>; overload;
generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrc: array of T; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator = nil; aGrowStrategy: TGrowthStrategy = nil): specialize IQueue<T>; overload;
generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;
generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>; overload;

// ==== Stack (source-based) ====
// 注意：MakeStack 移除了 aCapacity 和 aGrowStrategy 参数，因为 TArrayStack 当前不支持这些参数
generic function MakeStack<T>: specialize IStack<T>; overload;
generic function MakeStack<T>(aAllocator: IAllocator): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrc: array of T; aAllocator: IAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: IAllocator = nil): specialize IStack<T>; overload;
generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator = nil): specialize IStack<T>; overload;

// ==== List (source-based + capacity) ====

generic function MakeList<T>: specialize IList<T>; overload;
generic function MakeList<T>(aAllocator: IAllocator): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T): specialize IList<T>; overload;
generic function MakeList<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IList<T>; overload;
generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer): specialize IList<T>; overload;
generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>; overload;

// ==== ForwardList (source-based) ====

generic function MakeForwardList<T>: specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aAllocator: IAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IForwardList<T>; overload;
generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer): specialize IForwardList<T>; overload;

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
generic function MakeVec<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrc, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrcCollection, aAllocator, aGrowStrategy));
end;

generic function MakeVec<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IVec<T>;
begin
  Exit(specialize TVec<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy));
end;


// Arr from pointer+count
generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator));
end;

generic function MakeArr<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aElementCount, aAllocator, aData));
end;



generic function MakeVecDeque<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  // 支持传入增长策略；内部会将容量统一归一到 2 的幂
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


{$IFDEF FAFAFA_COLLECTIONS_FACADE}

// VecDeque facade helpers
generic function MakeVecDeque<T>: specialize IDeque<T>;
var
  LDeque: specialize TVecDeque<T>;
begin
  LDeque := specialize TVecDeque<T>.Create(GetRtlAllocator());
  Result := LDeque;
end;

// ForwardList factories
generic function MakeForwardList<T>: specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(IAllocator(nil));
end;

generic function MakeForwardList<T>(aAllocator: IAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aAllocator)
  else LI := specialize TForwardList<T>.Create;
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrc: array of T): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, IAllocator(nil));
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aAllocator)
  else LI := specialize TForwardList<T>.Create(aSrc);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: IAllocator): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator)
  else LI := specialize TForwardList<T>.Create(aSrcCollection);
  Result := LI;
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, aElementCount, IAllocator(nil));
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IForwardList<T>;
begin
  Result := specialize MakeForwardList<T>(aSrc, aElementCount, aAllocator, nil);
end;

generic function MakeForwardList<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrcCollection, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrcCollection, GetRtlAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(const aSrc: array of T; aAllocator: IAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, GetRtlAllocator(), aData);
  Result := LI;
end;

generic function MakeForwardList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer): specialize IForwardList<T>;
var LI: specialize IForwardList<T>;
begin
  if aAllocator <> nil then LI := specialize TForwardList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LI := specialize TForwardList<T>.Create(aSrc, aElementCount, GetRtlAllocator(), aData);
  Result := LI;
end;

// List factories
generic function MakeList<T>: specialize IList<T>;
begin
  Result := specialize MakeList<T>(IAllocator(nil));
end;

generic function MakeList<T>(aAllocator: IAllocator): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aAllocator)
  else LObj := specialize TList<T>.Create;
  Result := LObj;
end;

generic function MakeList<T>(const aSrc: array of T): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, IAllocator(nil));
end;

generic function MakeList<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aAllocator)
  else LObj := specialize TList<T>.Create(aSrc);
  Result := LObj;
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, aElementCount, IAllocator(nil));
end;

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IList<T>;
begin
  Result := specialize MakeList<T>(aSrc, aElementCount, aAllocator, nil);
end;


// Deque factories (source-based)
generic function MakeDeque<T>: specialize IDeque<T>;
begin
  Result := specialize MakeDeque<T>(0, IAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeDeque<T>(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
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

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
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

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
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

generic function MakeDeque<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection, GetRtlAllocator(), aData));
end;

generic function MakeDeque<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IDeque<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, GetRtlAllocator(), aData));
end;

// Queue factories (delegate to Deque)
generic function MakeQueue<T>: specialize IQueue<T>;
begin
  Result := specialize MakeQueue<T>(0, IAllocator(nil), TGrowthStrategy(nil));
end;

generic function MakeQueue<T>(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
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

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
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

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
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

generic function MakeQueue<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aGrowStrategy, aData))
    else
      Exit(specialize TVecDeque<T>.Create(aSrcCollection, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrcCollection, GetRtlAllocator(), aData));
end;

generic function MakeQueue<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy; aData: Pointer): specialize IQueue<T>;
begin
  if aAllocator <> nil then
  begin
    if aGrowStrategy <> nil then
      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aGrowStrategy, aData))
    else

      Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, aAllocator, aData));
  end
  else
    Exit(specialize TVecDeque<T>.Create(aSrc, aElementCount, GetRtlAllocator(), aData));
end;

// Stack factories (based on TArrayStack)
// 注意：移除了 aCapacity 和 aGrowStrategy 参数，因为 TArrayStack 当前不支持这些参数
generic function MakeStack<T>: specialize IStack<T>;
begin
  Result := specialize MakeStack<T>(IAllocator(nil));
end;

generic function MakeStack<T>(aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  Result := LStack;
end;

generic function MakeStack<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
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

generic function MakeStack<T>(const aSrcCollection: TCollection; aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
  PT = ^T;
var
  LStack: TStackImpl;
  LIter: TPtrIter;
begin
  LStack := TStackImpl.Create(aAllocator);
  try
    // 从 aSrcCollection 复制元素
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

generic function MakeStack<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
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

generic function MakeList<T>(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer): specialize IList<T>;
var LObj: specialize TList<T>;
begin
  if aAllocator <> nil then LObj := specialize TList<T>.Create(aSrc, aElementCount, aAllocator, aData)
  else LObj := specialize TList<T>.Create(aSrc, aElementCount, GetRtlAllocator(), aData);
  Result := LObj;
end;

{$ENDIF}




generic function MakeArr<T>(aAllocator: IAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(0, aAllocator));
end;

// From dynamic array (copy)
generic function MakeArr<T>(const aSrc: array of T; aAllocator: IAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrc, aAllocator));
end;

// From another collection (copy)
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: IAllocator): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator));
end;


// From another collection with data (copy)
generic function MakeArr<T>(const aSrcCollection: TCollection; aAllocator: IAllocator; aData: Pointer): specialize IArray<T>;
begin
  Exit(specialize TArray<T>.Create(aSrcCollection, aAllocator, aData));
end;


// Facade capacity-based factories (unconditionally compiled)




generic function MakeList<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IList<T>;
begin
  // 当前 List 实现不区分容量，保持接口一致性
  if aAllocator <> nil then
    Exit(specialize TList<T>.Create(aAllocator))
  else
    Exit(specialize TList<T>.Create);
end;


generic function MakeDeque<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IDeque<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


generic function MakeQueue<T>(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: TGrowthStrategy): specialize IQueue<T>;
begin
  Exit(specialize TVecDeque<T>.Create(aCapacity, aAllocator, aGrowStrategy));
end;


{$IFNDEF FAFAFA_COLLECTIONS_DISABLE_HASH}
// HashMap / HashSet factories — implementation will be provided by hashmap unit

generic function MakeHashMap<K,V>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil): specialize IHashMap<K,V>;
begin
  // Construct real HashMap instance - 使用nil使用默认hash/equals
  Result := specialize THashMap<K,V>.Create(aCapacity, nil, nil, aAllocator);
end;

generic function MakeHashSet<K>(aCapacity: SizeUInt = 0; aAllocator: IAllocator = nil): specialize IHashSet<K>;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, aAllocator);
end;
{$ENDIF}

// ==== TreeMap / TreeSet factories ====

generic function MakeTreeMap<K,V>(aCapacity: SizeUInt = 0; aCompare: specialize TCompareFunc<K> = nil; aAllocator: IAllocator = nil): specialize ITreeMap<K,V>;
begin
  Result := specialize TTreeMap<K,V>.Create(aAllocator, aCompare);
end;

generic function MakeTreeSet<T>(aAllocator: IAllocator = nil): specialize ITreeSet<T>;
begin
  if aAllocator <> nil then
    Result := specialize TTreeSet<T>.Create(aAllocator)
  else
    Result := specialize TTreeSet<T>.Create;
end;

// ==== LRU Cache factories ====

generic function MakeLruCache<K,V>(aMaxSize: SizeUInt; aAllocator: IAllocator = nil;
  aHash: specialize THashFunc<K> = nil; aEquals: specialize TEqualsFunc<K> = nil;
  aHashData: Pointer = nil; aEqualsData: Pointer = nil): specialize ILruCache<K,V>;
begin
  Result := specialize TLruCache<K,V>.Create(aMaxSize, aAllocator, aHash, aEquals, aHashData, aEqualsData);
end;

// ==== LinkedHashMap factories ====

generic function MakeLinkedHashMap<K,V>(aCapacity: SizeUInt; aAllocator: IAllocator): specialize ILinkedHashMap<K,V>;
begin
  if aAllocator <> nil then
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity, aAllocator)
  else
    Result := specialize TLinkedHashMap<K,V>.Create(aCapacity);
end;

// ==== BitSet factories ====

function MakeBitSet(aInitialCapacity: SizeUInt; aAllocator: IAllocator): IBitSet;
begin
  if aAllocator <> nil then
    Result := TBitSet.Create(aInitialCapacity, aAllocator)
  else
    Result := TBitSet.Create(aInitialCapacity);
end;

// end of factories

end.
