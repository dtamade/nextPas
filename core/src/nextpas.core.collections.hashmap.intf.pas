unit nextpas.core.collections.hashmap.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.hashmap.base;

type
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
     * @desc 写入键值对，不报告新增或更新
     *
     * @params
     *   AKey    键
     *   AValue  值
     *
     * @complexity O(1) 平均
     *
     * @note 需要区分新增或更新时使用 AddOrAssign
     *}
    procedure Put(const AKey: K; const AValue: V);

    {**
     * Get
     *
     * @desc 获取键对应的值，键不存在时抛出异常
     *
     * @params
     *   AKey  要查找的键
     *
     * @return V 键对应的值
     *
     * @complexity O(1) 平均
     *
     * @note 非抛出查找使用 TryGetValue
     *}
    function Get(const AKey: K): V;

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

implementation

end.
