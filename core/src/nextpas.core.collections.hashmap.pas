unit nextpas.core.collections.hashmap;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - hash map uses non-contiguous bucket storage
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base;

type
  {**
   * TKeyHashFunc<K>
   *
   * @desc Hash function for key type K
   * @param AKey The key to hash
   * @return UInt32 hash value
   *}
  generic TKeyHashFunc<K>  = function (const AKey: K): UInt32;

  {**
   * TKeyEqualsFunc<K>
   *
   * @desc Equality comparison function for key type K
   * @param L Left operand
   * @param R Right operand
   * @return Boolean True if L equals R
   *}
  generic TKeyEqualsFunc<K> = function (const L, R: K): Boolean;

  { Entry API 回调类型 }
  generic TValueSupplierFunc<V> = function: V;
  generic TValueModifierProc<V> = procedure(var Value: V);

  {**
   * IHashMap<K,V>
   *
   * @desc 开放寻址哈希映射接口
   *
   * @param K 键类型（必须可哈希、可比较）
   * @param V 值类型
   *
   * @note 实现使用线性探测解决冲突，默认负载因子阈值 0.86
   * @see THashMap 具体实现
   * @see ITreeMap 有序映射替代方案
   *}
  generic IHashMap<K,V> = interface(specialize IGenericCollection<specialize TMapEntry<K,V>>)
  ['{3C7B7B5B-4A29-46F0-9B13-9E5AC2D32E1F}']
    {**
     * TryGetValue
     *
     * @desc 尝试获取键对应的值
     *
     * @params
     *   AKey    要查找的键
     *   AValue  输出参数，找到时返回对应值
     *
     * @return Boolean 键存在返回 True，否则 False
     *
     * @complexity O(1) 平均, O(n) 最坏（哈希冲突严重时）
     *
     * @example
     *   var Value: Integer;
     *   if Map.TryGetValue('key', Value) then
     *     WriteLn('Found: ', Value);
     *}
    function TryGetValue(const AKey: K; out AValue: V): Boolean;

    {**
     * ContainsKey
     *
     * @desc 检查键是否存在
     *
     * @params
     *   AKey  要检查的键
     *
     * @return Boolean 键存在返回 True
     *
     * @complexity O(1) 平均, O(n) 最坏
     *}
    function ContainsKey(const AKey: K): Boolean;

    {**
     * Add
     *
     * @desc 添加键值对（仅当键不存在时）
     *
     * @params
     *   AKey    要添加的键
     *   AValue  要添加的值
     *
     * @return Boolean 成功添加返回 True，键已存在返回 False
     *
     * @postcondition 若返回 True，则 Count 增加 1
     *
     * @exceptions
     *   EOutOfMemory       内存分配失败
     *   EInvalidOperation  哈希表已满（极端情况）
     *
     * @complexity O(1) 平均, O(n) 最坏（触发 rehash 时）
     *
     * @example
     *   if Map.Add('new_key', 42) then
     *     WriteLn('Added successfully')
     *   else
     *     WriteLn('Key already exists');
     *}
    function Add(const AKey: K; const AValue: V): Boolean;

    {**
     * AddOrAssign
     *
     * @desc 添加或更新键值对
     *
     * @params
     *   AKey    键
     *   AValue  值
     *
     * @return Boolean True 表示新增, False 表示更新已有键
     *
     * @postcondition 键对应的值为 AValue
     *
     * @exceptions
     *   EOutOfMemory       内存分配失败
     *   EInvalidOperation  哈希表已满
     *
     * @complexity O(1) 平均, O(n) 最坏
     *
     * @example
     *   Map.AddOrAssign('counter', 1);  // 添加或覆盖
     *}
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;

    {**
     * Remove
     *
     * @desc 移除键值对
     *
     * @params
     *   AKey  要移除的键
     *
     * @return Boolean 成功移除返回 True，键不存在返回 False
     *
     * @postcondition 若返回 True，则 Count 减少 1，键不再存在
     *
     * @complexity O(1) 平均, O(n) 最坏
     *
     * @note 使用墓碑标记（tombstone）处理删除，不会立即回收空间
     *}
    function Remove(const AKey: K): Boolean;

    // Clear 继承自 ICollection，不再重复声明

    {**
     * GetCapacity
     *
     * @desc 获取当前容量（桶数量）
     *
     * @return SizeUInt 已分配的桶数量
     *
     * @complexity O(1)
     *
     * @note 容量始终为 2 的幂次
     *}
    function GetCapacity: SizeUInt;

    {**
     * GetLoadFactor
     *
     * @desc 获取当前负载因子（Count / Capacity）
     *
     * @return Single 负载因子，范围 [0.0, 1.0]
     *
     * @complexity O(1)
     *
     * @note 当 LoadFactor > 0.86 时自动触发 rehash
     *}
    function GetLoadFactor: Single;

    {**
     * Reserve
     *
     * @desc 预分配空间
     *
     * @params
     *   aCapacity  期望的最小容量
     *
     * @postcondition Capacity >= aCapacity（实际会向上取整到 2 的幂次）
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败
     *
     * @complexity O(n) 需要 rehash 现有元素
     *
     * @example
     *   Map.Reserve(1000);  // 预分配至少 1000 个桶
     *}
    procedure Reserve(aCapacity: SizeUInt);

    {**
     * Put
     *
     * @desc 添加或更新键值对（AddOrAssign 别名）
     *
     * @params
     *   AKey    键
     *   AValue  值
     *
     * @return Boolean True 表示新增, False 表示更新
     *
     * @complexity O(1) 平均
     *
     * @note 与 TreeMap API 保持一致
     *}
    function Put(const AKey: K; const AValue: V): Boolean;

    {**
     * Get
     *
     * @desc 尝试获取值（TryGetValue 别名）
     *
     * @params
     *   AKey    要查找的键
     *   AValue  输出参数
     *
     * @return Boolean 键存在返回 True
     *
     * @complexity O(1) 平均
     *
     * @note 与 TreeMap API 保持一致
     *}
    function Get(const AKey: K; out AValue: V): Boolean;

    {**
     * Capacity
     *
     * @desc 当前容量属性
     *
     * @return SizeUInt 桶数量
     *}
    property Capacity: SizeUInt read GetCapacity;

    {**
     * LoadFactor
     *
     * @desc 当前负载因子属性
     *
     * @return Single 负载因子
     *}
    property LoadFactor: Single read GetLoadFactor;

    { Entry API - Rust 风格的键值访问模式 }

    {**
     * GetOrInsert
     *
     * @desc 获取值，键不存在时插入默认值
     *
     * @params
     *   AKey      键
     *   ADefault  默认值（键不存在时插入）
     *
     * @return V 已存在或新插入的值
     *
     * @postcondition 键必然存在于映射中
     *
     * @complexity O(1) 平均
     *
     * @example
     *   // 计数器模式
     *   Count := Map.GetOrInsert('visits', 0);
     *}
    function GetOrInsert(const AKey: K; const ADefault: V): V;

    {**
     * GetOrInsertWith
     *
     * @desc 获取值，键不存在时调用函数生成值
     *
     * @params
     *   AKey       键
     *   ASupplier  生成默认值的函数（仅键不存在时调用）
     *
     * @return V 已存在或新生成的值
     *
     * @complexity O(1) 平均（不含 Supplier 执行时间）
     *
     * @note ASupplier 采用惰性求值，只在需要时调用
     *
     * @example
     *   Value := Map.GetOrInsertWith('config', @LoadDefaultConfig);
     *}
    function GetOrInsertWith(const AKey: K; ASupplier: specialize TValueSupplierFunc<V>): V;

    {**
     * ModifyOrInsert
     *
     * @desc Rust entry().and_modify().or_insert() 模式
     *
     * @params
     *   AKey       键
     *   AModifier  修改函数（键存在时调用）
     *   ADefault   默认值（键不存在时插入）
     *
     * @complexity O(1) 平均
     *
     * @example
     *   // 计数器递增
     *   procedure IncValue(var V: Integer); begin Inc(V); end;
     *   Map.ModifyOrInsert('counter', @IncValue, 1);
     *}
    procedure ModifyOrInsert(const AKey: K; AModifier: specialize TValueModifierProc<V>; const ADefault: V);

    {**
     * Retain
     *
     * @desc 保留满足条件的键值对，删除不满足条件的
     *
     * @params
     *   aPredicate  谓词函数，返回 True 的元素将被保留
     *   aData       传递给谓词函数的用户数据
     *
     * @postcondition 仅保留 aPredicate 返回 True 的元素
     *
     * @complexity O(n)
     *
     * @example
     *   // 保留值大于 10 的键值对
     *   function KeepLarge(const E: TEntry; Data: Pointer): Boolean;
     *   begin Result := E.Value > 10; end;
     *   Map.Retain(@KeepLarge, nil);
     *}
    procedure Retain(aPredicate: specialize TPredicateFunc<specialize TMapEntry<K,V>>; aData: Pointer);
  end;

const
  DEFAULT_MAX_LOAD_FACTOR = 0.86;

// Common hash helpers (callers can pass these as aHash)

{**
 * HashMix32
 *
 * @desc Mixes a 32-bit hash value for better distribution
 * @param x Input hash value
 * @return UInt32 Mixed hash value
 *}
function HashMix32(x: UInt32): UInt32;

{**
 * HashOfPointer
 *
 * @desc Hash function for Pointer type
 * @param p Pointer to hash
 * @return UInt32 Hash value
 *}
function HashOfPointer(p: Pointer): UInt32;

{**
 * HashOfUInt32
 *
 * @desc Hash function for UInt32 type
 * @param x Value to hash
 * @return UInt32 Hash value
 *}
function HashOfUInt32(x: UInt32): UInt32;

{**
 * HashOfUInt64
 *
 * @desc Hash function for UInt64 type
 * @param x Value to hash
 * @return UInt32 Hash value
 *}
function HashOfUInt64(x: QWord): UInt32;

{**
 * HashOfAnsiString
 *
 * @desc Hash function for AnsiString type
 * @param s String to hash
 * @return UInt32 Hash value
 *}
function HashOfAnsiString(const s: AnsiString): UInt32;

{**
 * HashOfUnicodeString
 *
 * @desc Hash function for UnicodeString type
 * @param s String to hash
 * @return UInt32 Hash value
 *}
function HashOfUnicodeString(const s: UnicodeString): UInt32;

type
  {**
   * IHashSet<K>
   *
   * @desc 哈希集合接口，用于成员资格测试
   *
   * @param K 元素类型（必须可哈希、可比较）
   *
   * @note 内部实现为 HashMap<K, Byte> 的轻量包装
   * @see THashSet 具体实现
   * @see ITreeSet 有序集合替代方案
   *}
  generic IHashSet<K> = interface(specialize IGenericCollection<K>)
  ['{4E6B9CD0-2D7E-4E7D-A7A7-7B0E9D6ABF1A}']
    {**
     * Add
     *
     * @desc 添加元素（不允许重复）
     *
     * @params
     *   AKey  要添加的元素
     *
     * @return Boolean 成功添加返回 True，已存在返回 False
     *
     * @postcondition 若返回 True，则 Count 增加 1
     *
     * @exceptions
     *   EOutOfMemory       内存分配失败
     *   EInvalidOperation  哈希表已满
     *
     * @complexity O(1) 平均, O(n) 最坏
     *
     * @example
     *   if MySet.Add('item') then
     *     WriteLn('Added new item');
     *}
    function Add(const AKey: K): Boolean;

    // Contains 继承自 IGenericCollection，不再重复声明

    {**
     * Remove
     *
     * @desc 移除元素
     *
     * @params
     *   AKey  要移除的元素
     *
     * @return Boolean 成功移除返回 True，元素不存在返回 False
     *
     * @postcondition 若返回 True，则 Count 减少 1
     *
     * @complexity O(1) 平均, O(n) 最坏
     *}
    function Remove(const AKey: K): Boolean;

    // Clear 继承自 ICollection，不再重复声明

    {**
     * GetCapacity
     *
     * @desc 获取当前容量
     *
     * @return SizeUInt 容量值
     *
     * @complexity O(1)
     *}
    function GetCapacity: SizeUInt;

    {**
     * Reserve
     *
     * @desc 预分配空间
     *
     * @params
     *   aCapacity  期望的最小容量
     *
     * @postcondition Capacity >= aCapacity
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败
     *
     * @complexity O(n)
     *}
    procedure Reserve(aCapacity: SizeUInt);

    {**
     * Capacity
     *
     * @desc 当前容量属性
     *
     * @return SizeUInt 容量值
     *}
    property Capacity: SizeUInt read GetCapacity;
  end;
  {**
   * THashMap<K,V>
   *
   * @desc 开放寻址哈希映射实现
   *
   * @param K 键类型（必须可哈希、可比较）
   * @param V 值类型
   *
   * @note
   *   - 使用线性探测（Linear Probing）解决哈希冲突
   *   - 墓碑标记（Tombstone）处理删除，保证探测链完整性
   *   - 自动扩容：当 LoadFactor > 0.86 时触发 rehash
   *   - 容量始终为 2 的幂次，便于位运算取模
   *   - 支持自定义哈希函数和相等比较函数
   *
   * @threadsafety 非线程安全。并发访问请使用 TMichaelHashMap（nextpas.core.lockfree.hashmap）
   *
   * @example
   *   var Map: specialize THashMap<String, Integer>;
   *   Map := specialize THashMap<String, Integer>.Create;
   *   try
   *     Map.Put('key', 42);
   *     if Map.ContainsKey('key') then
   *       WriteLn(Map.GetOrInsert('key', 0));
   *   finally
   *     Map.Free;
   *   end;
   *
   * @see IHashMap 接口定义
   * @see TTreeMap 有序映射替代方案
   *}
  generic THashMap<K,V> = class(specialize TGenericCollection<specialize TMapEntry<K,V>>, specialize IHashMap<K,V>)
  public
    type
      {** 键值对类型别名 *}
      TEntry = specialize TMapEntry<K,V>;
      {** 哈希函数类型 *}
      THash = specialize TKeyHashFunc<K>;
      {** 相等比较函数类型 *}
      TEquals = specialize TKeyEqualsFunc<K>;
      {**
       * TState - 桶状态枚举
       *
       * @desc 表示哈希表中每个桶的当前状态
       *
       * bsEmpty     - 空桶，从未使用
       * bsOccupied  - 已占用，存储有效键值对
       * bsTombstone - 墓碑，曾占用但已删除
       *
       * @note 墓碑状态对于线性探测至关重要，它保证探测链的连续性
       *}
      TState = (bsEmpty, bsOccupied, bsTombstone);
      {**
       * TBucket - 哈希桶结构
       *
       * @desc 存储单个键值对及其元数据
       *
       * State  - 桶状态（0=Empty, 1=Occupied, 2=Tombstone）
       * Hash   - 键的缓存哈希值，避免重复计算
       * Key    - 键
       * Value  - 值
       *}
      TBucket = record
        State: Byte; // 0=Empty,1=Occupied,2=Tombstone
        Hash: UInt32;
        Key: K;
        Value: V;
      end;
  private
    FBuckets: array of TBucket;
    FMask: SizeUInt;
    FCapacity: SizeUInt;
    FCount: SizeUInt;    // occupied count
    FUsed: SizeUInt;     // occupied + tombstone
    FMaxLoad: SizeUInt;  // threshold for rehash by used
    FHash: THash;
    FEquals: TEquals;
  private
    procedure InitCapacity(aCapacity: SizeUInt);
    procedure RecalcMaxLoad; inline;
    procedure Rehash(aNewCapacity: SizeUInt);
    function  NextPow2(x: SizeUInt): SizeUInt; inline;
    function  KeyHash(const AKey: K): UInt32;
    function  KeysEqual(const L, R: K): Boolean; inline;
    function  FindIndex(const AKey: K; AHash: UInt32; out AIndex: SizeUInt): Boolean;
  private
    // 迭代器回调方法
    function DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function DoIterMoveNext(aIter: PPtrIter): Boolean;
  protected
    // TCollection 抽象方法实现
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    // TGenericCollection 抽象方法实现
    procedure DoZero(); override;
    procedure DoReverse; override;
  public
    // TCollection overrides (public in base)
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;
    {**
     * PtrIter
     *
     * @desc 返回底层指针迭代器
     *
     * @return TPtrIter 迭代 TEntry 指针的迭代器
     *
     * @complexity O(1)
     *}
    function PtrIter: TPtrIter; override;

    {**
     * Create
     *
     * @desc 创建哈希映射实例
     *
     * @params
     *   aCapacity   初始容量（可选，默认 0 表示延迟分配）
     *   aHash       自定义哈希函数（可选，nil 使用默认）
     *   aEquals     自定义相等比较函数（可选，nil 使用 = 运算符）
     *   aAllocator  自定义内存分配器（可选）
     *
     * @note 默认哈希函数支持：Integer, String, Pointer 等基本类型
     * @note 复杂类型（如 record）需要提供自定义 aHash
     *
     * @example
     *   // 使用默认哈希
     *   Map := specialize THashMap<Integer, String>.Create;
     *   // 预分配 1000 容量
     *   Map := specialize THashMap<Integer, String>.Create(1000);
     *   // 自定义哈希函数
     *   Map := specialize THashMap<TMyRecord, Integer>.Create(0, @MyRecordHash);
     *}
    constructor Create(aCapacity: SizeUInt = 0; aHash: THash = nil; aEquals: TEquals = nil; aAllocator: IAllocator = nil);

    {**
     * Destroy
     *
     * @desc 销毁哈希映射，释放所有资源
     *
     * @note 自动调用 Clear 和 Finalize 所有键值对
     *}
    destructor Destroy; override;
    procedure Clear; override;
    function GetCount: SizeUInt; override;
    function GetCapacity: SizeUInt;
    function GetLoadFactor: Single;
    procedure Reserve(aCapacity: SizeUInt);

    // IGenericCollection（迭代先返回空实现，后续补充）
    function GetEnumerator: specialize TIter<TEntry>;
    function Iter: specialize TIter<TEntry>;
    function GetElementSize: SizeUInt; inline;

    // 基本操作
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Add(const AKey: K; const AValue: V): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;

    // API 一致性别名 (与 TreeMap 统一)
    function Put(const AKey: K; const AValue: V): Boolean; inline;
    function Get(const AKey: K; out AValue: V): Boolean; inline;

    {**
     * GetKeys
     * @desc 获取所有键
     * @return 键数组
     * @Complexity O(n)
     *}
    type
      TKeyArray = array of K;
      TValueSupplier = specialize TValueSupplierFunc<V>;
      TValueModifier = specialize TValueModifierProc<V>;
    function GetKeys: TKeyArray;

    // Entry API
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    function GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
    procedure ModifyOrInsert(const AKey: K; AModifier: TValueModifier; const ADefault: V);

    // Retain API
    type
      TEntryPredicate = specialize TPredicateFunc<TEntry>;
    procedure Retain(aPredicate: TEntryPredicate; aData: Pointer);
  end;

  {**
   * THashSet<K>
   *
   * @desc 哈希集合实现，内部基于 THashMap<K, Byte>
   *
   * @param K 元素类型（必须可哈希、可比较）
   *
   * @note
   *   - 轻量包装 THashMap，Value 使用 Byte 占位
   *   - 性能特征与 THashMap 相同
   *   - 适用于快速成员资格测试场景
   *
   * @threadsafety 非线程安全
   *
   * @example
   *   var Visited: specialize THashSet<Integer>;
   *   Visited := specialize THashSet<Integer>.Create;
   *   try
   *     Visited.Add(1);
   *     Visited.Add(2);
   *     if Visited.Contains(1) then
   *       WriteLn('Already visited');
   *   finally
   *     Visited.Free;
   *   end;
   *
   * @see IHashSet 接口定义
   * @see TTreeSet 有序集合替代方案
   *}
  generic THashSet<K> = class(specialize TGenericCollection<K>, specialize IHashSet<K>)
  private
    type
      {** 内部映射类型：K -> Byte（Byte 仅作占位） *}
      TInternalMap = specialize THashMap<K, Byte>;
      PK = ^K;
    var
      FMap: TInternalMap;
  protected
    // TCollection 抽象方法实现
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    // TGenericCollection 抽象方法实现
    procedure DoZero(); override;
    procedure DoReverse; override;
  public
    // TCollection overrides (public in base)
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    function PtrIter: TPtrIter; override;

    {**
     * Create
     *
     * @desc 创建哈希集合实例
     *
     * @params
     *   aCapacity   初始容量（可选）
     *   aHash       自定义哈希函数（可选）
     *   aEquals     自定义相等比较函数（可选）
     *   aAllocator  自定义内存分配器（可选）
     *}
    constructor Create(aCapacity: SizeUInt = 0; aHash: specialize TKeyHashFunc<K> = nil; aEquals: specialize TKeyEqualsFunc<K> = nil; aAllocator: IAllocator = nil);

    {**
     * Destroy
     *
     * @desc 销毁哈希集合
     *}
    destructor Destroy; override;
    procedure Clear; override;
    function GetCount: SizeUInt; override;
    function GetCapacity: SizeUInt;
    procedure Reserve(aCapacity: SizeUInt);

    // IGenericCollection
    function GetEnumerator: specialize TIter<K>;
    function Iter: specialize TIter<K>;
    function GetElementSize: SizeUInt; inline;

    // 基本操作
    function Add(const AKey: K): Boolean;
    function Contains(const AKey: K): Boolean; overload;
    function Contains(const AKey: K; aEquals: specialize TEqualsFunc<K>; aData: Pointer): Boolean; overload;
    function Contains(const AKey: K; aEquals: specialize TEqualsMethod<K>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Contains(const AKey: K; aEquals: specialize TEqualsRefFunc<K>): Boolean; overload;
    {$ENDIF}
    function Remove(const AKey: K): Boolean;

    // Set operations - 集合运算
    {**
     * Union - 并集
     * @desc 返回包含两个集合所有元素的新集合
     * @param Other 另一个集合
     * @return THashSet 新的并集集合（调用者负责释放）
     *}
    function Union(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * Intersection - 交集
     * @desc 返回同时存在于两个集合中的元素
     * @param Other 另一个集合
     * @return THashSet 新的交集集合（调用者负责释放）
     *}
    function Intersection(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * Difference - 差集
     * @desc 返回存在于当前集合但不存在于 Other 中的元素
     * @param Other 另一个集合
     * @return THashSet 新的差集集合（调用者负责释放）
     *}
    function Difference(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * SymmetricDifference - 对称差集
     * @desc 返回存在于任一集合但不同时存在于两个集合中的元素
     * @param Other 另一个集合
     * @return THashSet 新的对称差集集合（调用者负责释放）
     *}
    function SymmetricDifference(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * IsSubsetOf - 子集判断
     * @desc 判断当前集合是否是 Other 的子集
     * @param Other 另一个集合
     * @return Boolean 如果当前集合的所有元素都存在于 Other 中返回 True
     *}
    function IsSubsetOf(const Other: specialize THashSet<K>): Boolean;

    {**
     * IsSupersetOf - 超集判断
     * @desc 判断当前集合是否是 Other 的超集
     * @param Other 另一个集合
     * @return Boolean 如果 Other 的所有元素都存在于当前集合中返回 True
     *}
    function IsSupersetOf(const Other: specialize THashSet<K>): Boolean;

    {**
     * IsDisjoint - 不相交判断
     * @desc 判断两个集合是否没有共同元素
     * @param Other 另一个集合
     * @return Boolean 如果两个集合没有共同元素返回 True
     *}
    function IsDisjoint(const Other: specialize THashSet<K>): Boolean;
  end;

implementation

uses
  nextpas.core.math;

{ Hash helper functions }

function HashMix32(x: UInt32): UInt32;
begin
  x := (x xor (x shr 16)) * $7feb352d;
  x := (x xor (x shr 15)) * $846ca68b;
  x := x xor (x shr 16);
  Result := x;
end;

function HashOfPointer(p: Pointer): UInt32;
begin
  Result := HashMix32(UInt32(PtrUInt(p)));
end;

function HashOfUInt32(x: UInt32): UInt32;
begin
  Result := HashMix32(x);
end;

function HashOfUInt64(x: QWord): UInt32;
var lo,hi: UInt32;
begin
  lo := UInt32(x and $FFFFFFFF);
  hi := UInt32(x shr 32);
  Result := HashMix32(lo xor (hi * $9E3779B1));
end;

function HashOfAnsiString(const s: AnsiString): UInt32;
var i: SizeInt; h: UInt32;
begin
  h := 2166136261;
  for i := 1 to Length(s) do
    h := (h xor Ord(s[i])) * 16777619; // FNV-1a 简化版
  Result := HashMix32(h);
end;

function HashOfUnicodeString(const s: UnicodeString): UInt32;
var i: SizeInt; h: UInt32;
begin
  h := 2166136261;
  for i := 1 to Length(s) do
    h := (h xor Ord(s[i])) * 16777619;
  Result := HashMix32(h);
end;

{ THashMap<K,V> }

constructor THashMap.Create(aCapacity: SizeUInt; aHash: THash; aEquals: TEquals; aAllocator: IAllocator);
begin
  inherited Create(aAllocator);
  FHash := aHash;
  FEquals := aEquals;
  FCapacity := 0;
  FMask := 0;
  FCount := 0;
  FUsed := 0;
  SetLength(FBuckets, 0);
  if aCapacity > 0 then
    InitCapacity(aCapacity);
end;

function THashMap.NextPow2(x: SizeUInt): SizeUInt;
begin
  if x <= 1 then Exit(1);
  Dec(x);
  x := x or (x shr 1);
  x := x or (x shr 2);
  x := x or (x shr 4);
  x := x or (x shr 8);
  x := x or (x shr 16);
  {$IF SizeOf(SizeUInt) = 8}
  x := x or (x shr 32);
  {$ENDIF}
  Inc(x);
  Result := x;
end;

procedure THashMap.RecalcMaxLoad;
begin
  FMaxLoad := Trunc(FCapacity * DEFAULT_MAX_LOAD_FACTOR);
  if FMaxLoad >= FCapacity then
    FMaxLoad := FCapacity - 1;
end;

procedure THashMap.InitCapacity(aCapacity: SizeUInt);
var i: SizeUInt;
begin
  if aCapacity < 4 then aCapacity := 4;
  aCapacity := NextPow2(aCapacity);
  SetLength(FBuckets, aCapacity);
  FCapacity := aCapacity;
  FMask := aCapacity - 1;
  FCount := 0; FUsed := 0;
  for i := 0 to aCapacity-1 do FBuckets[i].State := Ord(bsEmpty);
  RecalcMaxLoad;
end;

procedure THashMap.Rehash(aNewCapacity: SizeUInt);
var oldBuckets: array of TBucket; oldCap, i: SizeUInt; b: TBucket; idx: SizeUInt;
begin
  oldBuckets := FBuckets; oldCap := FCapacity;
  InitCapacity(aNewCapacity);
  // 重新插入占用项
  for i := 0 to oldCap-1 do
  begin
    b := oldBuckets[i];
    if b.State = Ord(bsOccupied) then
    begin
      idx := b.Hash and FMask;
      while (FBuckets[idx].State = Ord(bsOccupied)) do
        idx := (idx + 1) and FMask;
      FBuckets[idx].State := Ord(bsOccupied);

      FBuckets[idx].Hash := b.Hash;
      FBuckets[idx].Key := b.Key;
      FBuckets[idx].Value := b.Value;
      Inc(FCount); Inc(FUsed);
    end;
  end;
end;

function THashMap.KeyHash(const AKey: K): UInt32;
var
  p: Pointer;
  ti: PTypeInfo;
begin
  if Assigned(FHash) then Exit(FHash(AKey));

  // Auto-detect string types and use content-based hash
  ti := TypeInfo(K);
  if ti <> nil then
  begin
    case ti^.Kind of
      tkAString, tkLString:
        Exit(HashOfAnsiString(AnsiString((@AKey)^)));
      tkUString, tkWString:
        Exit(HashOfUnicodeString(UnicodeString((@AKey)^)));
    else
      ; // fallthrough to default hashing
    end;
  end;

  // 默认分派：指针/整数/枚举 -> 混洗
  p := @AKey;
  case SizeOf(K) of
    1: Exit(HashOfUInt32(PByte(p)^));
    2: Exit(HashOfUInt32(PWord(p)^));
    4: Exit(HashOfUInt32(PUInt32(p)^));
    8: Exit(HashOfUInt64(PQWord(p)^));
  else
    // 复杂类型，需要自定义哈希
    raise ENotSupported.Create('THashMap.KeyHash: please provide custom hasher for this key type');
  end;
end;

function THashMap.KeysEqual(const L, R: K): Boolean;
begin
  if Assigned(FEquals) then Exit(FEquals(L, R));
  // 默认使用“=”语义
  Result := L = R;
end;

function THashMap.FindIndex(const AKey: K; AHash: UInt32; out AIndex: SizeUInt): Boolean;
var idx: SizeUInt; start: SizeUInt;
begin
  if FCapacity = 0 then begin AIndex := 0; Exit(False); end;
  idx := AHash and FMask; start := idx;
  while True do
  begin
    case FBuckets[idx].State of
      Ord(bsEmpty): begin AIndex := idx; Exit(False); end;
      Ord(bsOccupied):
        if (FBuckets[idx].Hash = AHash) and KeysEqual(FBuckets[idx].Key, AKey) then
        begin AIndex := idx; Exit(True); end;
      Ord(bsTombstone): ;
    end;
    idx := (idx + 1) and FMask;
    if idx = start then begin AIndex := idx; Exit(False); end;
  end;
end;

procedure THashMap.Clear;
var i: SizeUInt;
begin
  if FCapacity = 0 then Exit;
  for i := 0 to FCapacity-1 do
  begin
    if FBuckets[i].State = Ord(bsOccupied) then
    begin
      Finalize(FBuckets[i].Key);
      Finalize(FBuckets[i].Value);
    end;
    FBuckets[i].State := Ord(bsEmpty);
    FBuckets[i].Hash := 0;
    // Key/Value 已经 Finalize；保持为已清空状态
  end;
  FCount := 0;
  FUsed := 0;
end;

function THashMap.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function THashMap.GetCapacity: SizeUInt;
begin


  Result := FCapacity;
end;

function THashMap.GetLoadFactor: Single;
begin
  if FCapacity = 0 then Exit(0.0);
  Result := FCount / FCapacity;
end;

procedure THashMap.DoZero();
var i: SizeUInt; defaultValue: V;
begin
  // CRITICAL FIX: Properly finalize and reinitialize values to avoid memory corruption
  // Old code used FillChar which bypasses reference counting and causes leaks/crashes
  if FCapacity = 0 then Exit;

  // Initialize a default zero value properly
  FillChar(defaultValue, SizeOf(V), 0);

  for i := 0 to FCapacity-1 do
  begin
    if FBuckets[i].State = Ord(bsOccupied) then
    begin
      // Finalize old value to release resources
      Finalize(FBuckets[i].Value);
      // Assign fresh zero value
      FBuckets[i].Value := defaultValue;
    end;
  end;
end;

procedure THashMap.DoReverse;
begin
  // HashMap 没有固定的顺序，Reverse 操作无实际意义，保持空实现
  // 这是为了满足基类抽象方法的要求
end;

function THashMap.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // HashMap 不使用连续内存，不会与外部指针重叠
  Result := False;
end;

function THashMap.DoIterGetCurrent(aIter: PPtrIter): Pointer;
var
  idx: SizeUInt;
begin
  {$PUSH}{$WARN 4055 OFF}
  idx := SizeUInt(aIter^.Data);
  {$POP}
  // 返回当前桶的 TEntry 指针（Key 和 Value 在内存中连续）
  Result := @FBuckets[idx].Key;
end;

function THashMap.DoIterMoveNext(aIter: PPtrIter): Boolean;
var
  idx: SizeUInt;
begin
  if aIter^.Started then
  begin
    {$PUSH}{$WARN 4055 OFF}
    idx := SizeUInt(aIter^.Data) + 1;
    {$POP}
  end
  else
  begin
    aIter^.Started := True;
    idx := 0;
  end;

  // 找到下一个 bsOccupied 桶
  while idx < FCapacity do
  begin
    if FBuckets[idx].State = Ord(bsOccupied) then
    begin
      {$PUSH}{$WARN 4055 OFF}
      aIter^.Data := Pointer(idx);
      {$POP}
      Exit(True);
    end;
    Inc(idx);
  end;

  Result := False;
end;

function THashMap.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

procedure THashMap.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  i, cnt: SizeUInt;
  pEntry: ^TEntry;
begin
  // 将 HashMap 中的键值对序列化到数组缓冲区
  if (aDst = nil) or (aCount = 0) or (FCount = 0) then Exit;

  pEntry := aDst;
  cnt := 0;
  for i := 0 to FCapacity - 1 do
  begin
    if FBuckets[i].State = Ord(bsOccupied) then
    begin
      if cnt >= aCount then Break;
      pEntry^.Key := FBuckets[i].Key;
      pEntry^.Value := FBuckets[i].Value;
      Inc(pEntry);
      Inc(cnt);
    end;
  end;
end;

procedure THashMap.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  pEntry: ^TEntry;
begin
  // 从数组缓冲区追加键值对
  if (aSrc = nil) or (aElementCount = 0) then Exit;

  pEntry := aSrc;
  for i := 0 to aElementCount - 1 do
  begin
    AddOrAssign(pEntry^.Key, pEntry^.Value);
    Inc(pEntry);
  end;
end;

procedure THashMap.AppendToUnChecked(const aDst: TCollection);
var
  i: SizeUInt;
  dstMap: specialize THashMap<K, V>;
begin
  // 将当前 HashMap 的所有元素追加到目标容器
  if aDst = nil then Exit;

  // 如果目标也是同类型的 HashMap，可以直接调用 AddOrAssign
  if aDst is specialize THashMap<K, V> then
  begin
    dstMap := specialize THashMap<K, V>(aDst);
    for i := 0 to FCapacity - 1 do
    begin
      if FBuckets[i].State = Ord(bsOccupied) then
        dstMap.AddOrAssign(FBuckets[i].Key, FBuckets[i].Value);
    end;
  end
  else
  begin
    // 对于其他类型的容器，我们无法直接支持
    // 因为 THashMap<K,V> 的元素类型是 TEntry<K,V>，而不是单个类型
    raise EInvalidOperation.Create('THashMap.AppendToUnChecked: cannot append to incompatible container type');
  end;
end;

procedure THashMap.Reserve(aCapacity: SizeUInt);
begin
  if aCapacity <= FCapacity then Exit;
  if FCapacity = 0 then InitCapacity(aCapacity)
  else Rehash(NextPow2(aCapacity));
end;

destructor THashMap.Destroy;
begin
  Clear;
  SetLength(FBuckets, 0);
  inherited;
end;

function THashMap.GetEnumerator: specialize TIter<TEntry>;
begin
  Result := inherited GetEnumerator;
end;

function THashMap.Iter: specialize TIter<TEntry>;
begin
  Result := inherited Iter;
end;

function THashMap.GetElementSize: SizeUInt;
begin
  Result := SizeOf(TEntry);
end;

function THashMap.TryGetValue(const AKey: K; out AValue: V): Boolean;
var idx: SizeUInt; h: UInt32;
begin
  if FCapacity = 0 then Exit(False);
  h := KeyHash(AKey);
  if FindIndex(AKey, h, idx) then
  begin
    AValue := FBuckets[idx].Value;
    Exit(True);
  end;
  Result := False;
end;

function THashMap.ContainsKey(const AKey: K): Boolean;
var dummy: V;
begin
  Result := TryGetValue(AKey, dummy);
end;

function THashMap.Add(const AKey: K; const AValue: V): Boolean;
var h: UInt32; idx, firstTomb: SizeUInt; start: SizeUInt; st: Byte;
begin
  if FCapacity = 0 then InitCapacity(4);
  if FUsed >= FMaxLoad then Rehash(FCapacity shl 1);
  h := KeyHash(AKey);
  idx := h and FMask; start := idx; firstTomb := SizeUInt(-1);
  while True do
  begin
    st := FBuckets[idx].State;
    if st = Ord(bsEmpty) then
    begin
      if firstTomb <> SizeUInt(-1) then
      begin
        idx := firstTomb;
        st := Ord(bsTombstone); // 复用墓碑：不增加 FUsed
      end;
      FBuckets[idx].State := Ord(bsOccupied);
      FBuckets[idx].Hash := h;
      FBuckets[idx].Key := AKey;
      FBuckets[idx].Value := AValue;
      Inc(FCount);
      if st = Ord(bsEmpty) then
        Inc(FUsed);
      Exit(True);
    end
    else if st = Ord(bsTombstone) then
    begin
      if firstTomb = SizeUInt(-1) then firstTomb := idx;
    end
    else // occupied
    begin
      if (FBuckets[idx].Hash = h) and KeysEqual(FBuckets[idx].Key, AKey) then
        Exit(False);
    end;
    idx := (idx + 1) and FMask;
    if idx = start then
      raise EInvalidOperation.Create('THashMap.Add: map is full');
  end;
end;

function THashMap.AddOrAssign(const AKey: K; const AValue: V): Boolean;
var h: UInt32; idx, firstTomb: SizeUInt; start: SizeUInt; st: Byte;
begin
  if FCapacity = 0 then InitCapacity(4);
  if FUsed >= FMaxLoad then Rehash(FCapacity shl 1);
  h := KeyHash(AKey);
  idx := h and FMask; start := idx; firstTomb := SizeUInt(-1);
  while True do
  begin
    st := FBuckets[idx].State;
    if st = Ord(bsEmpty) then
    begin
      if firstTomb <> SizeUInt(-1) then
      begin
        idx := firstTomb;
        st := Ord(bsTombstone);
      end;
      FBuckets[idx].State := Ord(bsOccupied);
      FBuckets[idx].Hash := h;
      FBuckets[idx].Key := AKey;
      FBuckets[idx].Value := AValue;
      Inc(FCount);
      if st = Ord(bsEmpty) then
        Inc(FUsed);
      Exit(True);
    end
    else if st = Ord(bsTombstone) then
    begin
      if firstTomb = SizeUInt(-1) then firstTomb := idx;
    end
    else // occupied
    begin
      if (FBuckets[idx].Hash = h) and KeysEqual(FBuckets[idx].Key, AKey) then
      begin
        // 覆盖旧值（先 Finalize 再赋值，避免泄漏）
        Finalize(FBuckets[idx].Value);
        FBuckets[idx].Value := AValue;
        Exit(False);
      end;
    end;
    idx := (idx + 1) and FMask;
    if idx = start then
      raise EInvalidOperation.Create('THashMap.AddOrAssign: map is full');
end;
end;

function THashMap.Remove(const AKey: K): Boolean;
var idx: SizeUInt; h: UInt32;
begin
  if FCapacity = 0 then Exit(False);
  h := KeyHash(AKey);
  if not FindIndex(AKey, h, idx) then Exit(False);
  // CRITICAL FIX: Finalize then re-initialize to ensure clean state
  // Prevents dangling references and undefined behavior
  Finalize(FBuckets[idx].Key);
  Finalize(FBuckets[idx].Value);
  Initialize(FBuckets[idx].Key);
  Initialize(FBuckets[idx].Value);
  FBuckets[idx].State := Ord(bsTombstone);
  FBuckets[idx].Hash := 0;
  Dec(FCount);
  Result := True;
end;

function THashMap.Put(const AKey: K; const AValue: V): Boolean;
begin
  // Put 是 AddOrAssign 的别名，与 TreeMap API 保持一致
  Result := AddOrAssign(AKey, AValue);
end;

function THashMap.Get(const AKey: K; out AValue: V): Boolean;
begin
  // Get 是 TryGetValue 的别名，与 TreeMap API 保持一致
  Result := TryGetValue(AKey, AValue);
end;

function THashMap.GetKeys: TKeyArray;
var
  i, idx: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);

  // CRITICAL FIX: Check if map is empty or uninitialized
  if (FCapacity = 0) or (FCount = 0) then
    Exit;  // Return empty array

  idx := 0;

  for i := 0 to FCapacity - 1 do
  begin
    if FBuckets[i].State = Ord(bsOccupied) then
    begin
      Result[idx] := FBuckets[i].Key;
      Inc(idx);
    end;
  end;
end;

{ Entry API Implementation }

function THashMap.GetOrInsert(const AKey: K; const ADefault: V): V;
var
  h: UInt32;
  idx: SizeUInt;
begin
  if FCapacity = 0 then InitCapacity(4);
  h := KeyHash(AKey);
  if FindIndex(AKey, h, idx) then
    Result := FBuckets[idx].Value
  else
  begin
    AddOrAssign(AKey, ADefault);
    Result := ADefault;
  end;
end;

function THashMap.GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
var
  h: UInt32;
  idx: SizeUInt;
begin
  if FCapacity = 0 then InitCapacity(4);
  h := KeyHash(AKey);
  if FindIndex(AKey, h, idx) then
    Result := FBuckets[idx].Value
  else
  begin
    Result := ASupplier();
    AddOrAssign(AKey, Result);
  end;
end;

procedure THashMap.ModifyOrInsert(const AKey: K; AModifier: TValueModifier; const ADefault: V);
var
  h: UInt32;
  idx: SizeUInt;
begin
  if FCapacity = 0 then InitCapacity(4);
  h := KeyHash(AKey);
  if FindIndex(AKey, h, idx) then
    // Key exists - modify in place
    AModifier(FBuckets[idx].Value)
  else
    // Key not exists - insert default
    AddOrAssign(AKey, ADefault);
end;

procedure THashMap.Retain(aPredicate: TEntryPredicate; aData: Pointer);
var
  i: SizeUInt;
  entry: TEntry;
begin
  if FCapacity = 0 then Exit;

  for i := 0 to FCapacity - 1 do
  begin
    if FBuckets[i].State = Ord(bsOccupied) then
    begin
      entry.Key := FBuckets[i].Key;
      entry.Value := FBuckets[i].Value;

      // 如果谓词返回 False，删除这个元素
      if not aPredicate(entry, aData) then
      begin
        Finalize(FBuckets[i].Key);
        Finalize(FBuckets[i].Value);
        Initialize(FBuckets[i].Key);
        Initialize(FBuckets[i].Value);
        FBuckets[i].State := Ord(bsTombstone);
        FBuckets[i].Hash := 0;
        Dec(FCount);
      end;
    end;
  end;
end;

{ THashSet<K> }

constructor THashSet.Create(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: IAllocator);
begin
  inherited Create(aAllocator);
  FMap := TInternalMap.Create(aCapacity, aHash, aEquals, aAllocator);
end;

destructor THashSet.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure THashSet.Clear;
begin
  FMap.Clear;
end;

function THashSet.GetCount: SizeUInt;
begin
  Result := FMap.GetCount;
end;

function THashSet.GetCapacity: SizeUInt;
begin
  Result := FMap.GetCapacity;
end;

procedure THashSet.Reserve(aCapacity: SizeUInt);
begin
  FMap.Reserve(aCapacity);
end;

function THashSet.GetEnumerator: specialize TIter<K>;
begin
  Result := inherited GetEnumerator;
end;

function THashSet.Iter: specialize TIter<K>;
begin
  Result := inherited Iter;
end;

function THashSet.GetElementSize: SizeUInt;
begin
  Result := SizeOf(K);
end;

procedure THashSet.DoZero();
begin
  // HashSet 的 Zero 操作委托给底层 HashMap
  FMap.DoZero();
end;

procedure THashSet.DoReverse;
begin
  // HashSet 没有固定的顺序，Reverse 操作无实际意义
  // 委托给底层 HashMap（也是空实现）
  FMap.DoReverse;
end;

function THashSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := FMap.IsOverlap(aSrc, aElementCount);
end;

function THashSet.PtrIter: TPtrIter;
begin
  Result := FMap.PtrIter;
end;

procedure THashSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
{**
 * 将 HashSet 中的元素序列化到数组缓冲区
 *
 * HashSet 内部使用 FMap: THashMap<K, Byte> 存储键值对
 * 其中 Byte 类型充当占位符（值不重要）
 * 需要从 FMap 中提取所有键并写入缓冲区
 *
 * @param aDst 目标缓冲区指针
 * @param aCount 期望写入的元素数量（通常为 GetCount）
 *}
var
  LCopied: SizeUInt;
  LIter: TPtrIter;
  PDst: PK;
begin
  if (aDst = nil) or (aCount = 0) or (GetCount = 0) then Exit;

  PDst := aDst;
  LCopied := 0;
  LIter := PtrIter();

  // 使用公共迭代器接口遍历，不直接访问 FMap 内部字段
  // PtrIter 返回指向 TMapEntry<K, Byte> 的指针
  // 由于 TMapEntry 的第一个字段是 Key，内存布局上指针起始位置就是 Key
  while LIter.MoveNext and (LCopied < aCount) do
  begin
    PDst^ := PK(LIter.GetCurrent)^;
    Inc(PDst);
    Inc(LCopied);
  end;
end;

procedure THashSet.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  pKey: ^K;
begin
  // 从数组缓冲区追加元素
  if (aSrc = nil) or (aElementCount = 0) then Exit;

  pKey := aSrc;
  for i := 0 to aElementCount - 1 do
  begin
    Add(pKey^);
    Inc(pKey);
  end;
end;

procedure THashSet.AppendToUnChecked(const aDst: TCollection);
var
  i: SizeUInt;
  dstSet: specialize THashSet<K>;
  mapIter: specialize TIter<specialize TMapEntry<K, Byte>>;
  entry: specialize TMapEntry<K, Byte>;
begin
  // 将当前 HashSet 的所有元素追加到目标容器
  if aDst = nil then Exit;

  // 如果目标也是同类型的 HashSet
  if aDst is specialize THashSet<K> then
  begin
    dstSet := specialize THashSet<K>(aDst);
    // 迭代 FMap 获取所有 Key
    mapIter := FMap.Iter;
    while mapIter.MoveNext do
    begin
      entry := mapIter.Current;
      dstSet.Add(entry.Key);
    end;
  end
  else
  begin
    // 对于其他类型，我们无法直接支持
    raise EInvalidOperation.Create('THashSet.AppendToUnChecked: cannot append to incompatible container type');
  end;
end;

function THashSet.Add(const AKey: K): Boolean;
begin
  Result := FMap.Add(AKey, 1);
end;

function THashSet.Contains(const AKey: K): Boolean;
begin
  Result := FMap.ContainsKey(AKey);
end;

function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsFunc<K>; aData: Pointer): Boolean;
begin
  // Delegate to base class generic algorithm which iterates and checks with custom equals
  Result := inherited Contains(AKey, aEquals, aData);
end;

function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsMethod<K>; aData: Pointer): Boolean;
begin
  Result := inherited Contains(AKey, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsRefFunc<K>): Boolean;
begin
  Result := inherited Contains(AKey, aEquals);
end;
{$ENDIF}

function THashSet.Remove(const AKey: K): Boolean;
begin
  Result := FMap.Remove(AKey);
end;

// Set operations implementations

function THashSet.Union(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  // Add all elements from current set
  for Element in Self do
    Result.Add(Element);

  // Add all elements from other set
  for Element in Other do
    Result.Add(Element);
end;

function THashSet.Intersection(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  // Add only elements that exist in both sets
  for Element in Self do
    if Other.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.Difference(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  // Add only elements that exist in Self but not in Other
  for Element in Self do
    if not Other.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.SymmetricDifference(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  // Add elements from Self that are not in Other
  for Element in Self do
    if not Other.Contains(Element) then
      Result.Add(Element);

  // Add elements from Other that are not in Self
  for Element in Other do
    if not Self.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.IsSubsetOf(const Other: specialize THashSet<K>): Boolean;
var
  Element: K;
begin
  // Empty set is subset of any set
  if GetCount = 0 then
    Exit(True);

  // If Self has more elements than Other, Self cannot be a subset
  if GetCount > Other.GetCount then
    Exit(False);

  // Check if all elements in Self exist in Other
  for Element in Self do
    if not Other.Contains(Element) then
      Exit(False);

  Result := True;
end;

function THashSet.IsSupersetOf(const Other: specialize THashSet<K>): Boolean;
begin
  // Self is superset of Other iff Other is subset of Self
  Result := Other.IsSubsetOf(Self);
end;

function THashSet.IsDisjoint(const Other: specialize THashSet<K>): Boolean;
var
  Element: K;
  Smaller, Larger: specialize THashSet<K>;
begin
  // Empty sets are disjoint with any set
  if (GetCount = 0) or (Other.GetCount = 0) then
    Exit(True);

  // Optimize: iterate over the smaller set
  if GetCount <= Other.GetCount then
  begin
    Smaller := Self;
    Larger := Other;
  end
  else
  begin
    Smaller := Other;
    Larger := Self;
  end;

  // Check if any element from smaller set exists in larger set
  for Element in Smaller do
    if Larger.Contains(Element) then
      Exit(False);

  Result := True;
end;

end.
