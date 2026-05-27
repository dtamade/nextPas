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
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.arr,
  nextpas.core.collections.slice,
  nextpas.core.collections.iterators,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.builder,
  nextpas.core.collections.node,
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
  // 统一对外导出的关键接口类型（非泛型别名；泛型类型请直接使用其本单元 uses 引入的原始定义）
  ICollection = nextpas.core.collections.intf.ICollection;

  // 增长策略导出（接口优先 + 兼容类基实现）
  IGrowthStrategy          = nextpas.core.collections.base.IGrowthStrategy;
  TGrowthStrategy          = nextpas.core.collections.base.TGrowthStrategy;
  TGrowthStrategyClass     = nextpas.core.collections.base.TGrowthStrategyClass;
  TCustomGrowthStrategy    = nextpas.core.collections.base.TCustomGrowthStrategy;
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

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

// 工厂函数（TDD：先声明，后实现；优先 MakeVec/MakeVecDeque/MakeArray）
// 为减少调用方对实现细节的耦合，返回接口类型
// 约定：Capacity=0 表示按实现默认容量策略；GrowStrategy=nil 则使用默认策略

// ==== 简洁快捷构造函数 ====
// 类似 Rust/C++ 风格的泛型工厂函数，避免冗长的 Make* 前缀
// 用法：V := specialize Vec<Integer>(100);  // 创建容量为100的向量
//       M := specialize Map<String, Integer>;  // 创建空 HashMap

// Vec<T> - 动态数组向量
generic function Vec<T>: specialize IVec<T>;
generic function Vec<T>(aCapacity: SizeUInt): specialize IVec<T>;
generic function Vec<T>(const aSrc: array of T): specialize IVec<T>;

// Deque<T> - 双端队列
generic function Deque<T>: specialize IDeque<T>;
generic function Deque<T>(aCapacity: SizeUInt): specialize IDeque<T>;
generic function Deque<T>(const aSrc: array of T): specialize IDeque<T>;

{$IFNDEF FAFAFA_COLLECTIONS_DISABLE_HASH}
// Map<K,V> - 哈希映射表 (HashMap)
generic function Map<K,V>: specialize IHashMap<K,V>;
generic function Map<K,V>(aCapacity: SizeUInt): specialize IHashMap<K,V>;

// Set_<K> - 哈希集合 (HashSet)，使用 Set_ 避免与 Pascal 关键字冲突
generic function Set_<K>: specialize IHashSet<K>;
generic function Set_<K>(aCapacity: SizeUInt): specialize IHashSet<K>;
{$ENDIF}

// OrdMap<K,V> - 有序映射表 (TreeMap)
generic function OrdMap<K,V>: specialize ITreeMap<K,V>;
generic function OrdMap<K,V>(aCompare: specialize TCompareFunc<K>): specialize ITreeMap<K,V>;

// OrdSet<K> - 有序集合 (TreeSet)
// 注意：TTreeSet 当前不支持自定义比较器，因此移除了 aCompare 参数的重载
generic function OrdSet<K>: specialize ITreeSet<K>;

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
function MakeBitSet(aInitialCapacity: SizeUInt = 64; aAllocator: IAllocator = nil): IBitSet;
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

// ==== 简洁快捷构造函数实现 ====

// Vec<T> 实现
generic function Vec<T>: specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create;
end;

generic function Vec<T>(aCapacity: SizeUInt): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create(aCapacity);
end;

generic function Vec<T>(const aSrc: array of T): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create(aSrc, nil, nil);
end;

// Deque<T> 实现
generic function Deque<T>: specialize IDeque<T>;
begin
  Result := specialize TVecDeque<T>.Create;
end;

generic function Deque<T>(aCapacity: SizeUInt): specialize IDeque<T>;
begin
  Result := specialize TVecDeque<T>.Create(aCapacity, nil, nil);
end;

generic function Deque<T>(const aSrc: array of T): specialize IDeque<T>;
begin
  Result := specialize TVecDeque<T>.Create(aSrc);
end;

{$IFNDEF FAFAFA_COLLECTIONS_DISABLE_HASH}
// Map<K,V> 实现
generic function Map<K,V>: specialize IHashMap<K,V>;
begin
  Result := specialize THashMap<K,V>.Create(0, nil, nil, nil);
end;

generic function Map<K,V>(aCapacity: SizeUInt): specialize IHashMap<K,V>;
begin
  Result := specialize THashMap<K,V>.Create(aCapacity, nil, nil, nil);
end;

// Set_<K> 实现
generic function Set_<K>: specialize IHashSet<K>;
begin
  Result := specialize THashSet<K>.Create(0, nil, nil, nil);
end;

generic function Set_<K>(aCapacity: SizeUInt): specialize IHashSet<K>;
begin
  Result := specialize THashSet<K>.Create(aCapacity, nil, nil, nil);
end;
{$ENDIF}

// OrdMap<K,V> 实现
generic function OrdMap<K,V>: specialize ITreeMap<K,V>;
begin
  Result := specialize TTreeMap<K,V>.Create(nil, nil);
end;

generic function OrdMap<K,V>(aCompare: specialize TCompareFunc<K>): specialize ITreeMap<K,V>;
begin
  Result := specialize TTreeMap<K,V>.Create(nil, aCompare);
end;

// OrdSet<K> 实现
generic function OrdSet<K>: specialize ITreeSet<K>;
begin
  Result := specialize TTreeSet<K>.Create;
end;

// OrdSet<K>(aCompare) 已移除，因为 TTreeSet 当前不支持自定义比较器

// end of factories

end.
