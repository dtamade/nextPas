unit nextpas.core.collections.treemap.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.treemap.base;

type

  {**
   * ITreeMap<K,V>
   *
   * @desc 红黑树实现的有序键值对映射
   * @param K 键类型（必须支持比较操作）
   * @param V 值类型
   * @note
   *   - 支持范围查询（GetRange、GetLowerBound、GetUpperBound）
   *   - 支持 floor/ceiling 操作
   *   - O(log n) 插入、删除、查找
   *   - 纯数据管理，无并发安全（职责分离）
   *}
  generic ITreeMap<K, V> = interface(specialize IGenericCollection<specialize TMapEntry<K, V>>)
    ['{A1B2C3D4-E5F6-4789-ABCD-123456789ABC}']

    {**
     * GetLowerBound
     *
     * @desc 获取严格大于指定键的最小键值对
     *
     * @params
     *   aKey    参考键
     *   aValue  (输出) 找到的值
     *
     * @return 找到返回 True，否则返回 False
     *
     * @complexity O(log n)
     * @see GetUpperBound, Ceiling, Floor
     *}
    function GetLowerBound(const aKey: K; out aValue: V): Boolean; overload;

    {**
     * GetUpperBound
     *
     * @desc 获取大于等于指定键的最小键值对
     *
     * @params
     *   aKey    参考键
     *   aValue  (输出) 找到的值
     *
     * @return 找到返回 True，否则返回 False
     *
     * @complexity O(log n)
     * @see GetLowerBound, Ceiling, Floor
     *}
    function GetUpperBound(const aKey: K; out aValue: V): Boolean; overload;

    {**
     * GetRange
     *
     * @desc 遍历指定范围 [aLow, aHigh] 内的所有键值对
     *
     * @params
     *   aLow      范围下界（包含）
     *   aHigh     范围上界（包含）
     *   aCallback 每个键值对的回调函数
     *
     * @return 范围内有元素返回 True，否则返回 False
     *
     * @complexity O(log n + k)，k 为范围内元素数量
     *
     * @example
     *   tree.GetRange(10, 20, @ProcessEntry);  // 遍历键在 10~20 的所有元素
     *}
    function GetRange(const aLow, aHigh: K; const aCallback: specialize TKeyValueCallback<K, V>): Boolean;

    {**
     * Ceiling
     *
     * @desc 获取大于等于指定键的最小键值对（“天花板”）
     *
     * @params
     *   aKey    参考键
     *   aValue  (输出) 找到的值
     *
     * @return 找到返回 True，否则返回 False
     *
     * @complexity O(log n)
     *
     * @example
     *   // 树中有键: 1, 5, 10, 15
     *   tree.Ceiling(7, v);  // 返回 True, v 对应键 10
     *   tree.Ceiling(5, v);  // 返回 True, v 对应键 5
     *   tree.Ceiling(20, v); // 返回 False
     *}
    function Ceiling(const aKey: K; out aValue: V): Boolean;

    {**
     * Floor
     *
     * @desc 获取小于等于指定键的最大键值对（“地板”）
     *
     * @params
     *   aKey    参考键
     *   aValue  (输出) 找到的值
     *
     * @return 找到返回 True，否则返回 False
     *
     * @complexity O(log n)
     *
     * @example
     *   // 树中有键: 1, 5, 10, 15
     *   tree.Floor(7, v);   // 返回 True, v 对应键 5
     *   tree.Floor(5, v);   // 返回 True, v 对应键 5
     *   tree.Floor(0, v);   // 返回 False
     *}
    function Floor(const aKey: K; out aValue: V): Boolean;

    {**
     * TryGetValue
     *
     * @desc 尝试根据键获取值
     *
     * @params
     *   aKey    要查找的键
     *   aValue  (输出) 找到的值
     *
     * @return 键存在返回 True，否则返回 False
     *
     * @complexity O(log n)
     * @see Get, ContainsKey
     *}
    function TryGetValue(const aKey: K; out aValue: V): Boolean;

    {**
     * Get
     *
     * @desc 根据键获取值，键不存在时抛出异常
     *
     * @params
     *   aKey  要查找的键
     *
     * @return V 键对应的值
     *
     * @complexity O(log n)
     * @see TryGetValue, ContainsKey
     *}
    function Get(const aKey: K): V;

    {**
     * Add
     *
     * @desc 仅当键不存在时插入键值对
     *
     * @params
     *   aKey    键
     *   aValue  值
     *
     * @return 新插入返回 True，键已存在返回 False
     *
     * @postcondition 若返回 True，则 Count 增加 1
     * @complexity O(log n)
     *}
    function Add(const aKey: K; const aValue: V): Boolean;

    {**
     * AddOrAssign
     *
     * @desc 插入或更新键值对，并报告新增或更新
     *
     * @params
     *   aKey    键
     *   aValue  值
     *
     * @return 新插入返回 True，更新已有键返回 False
     *
     * @postcondition ContainsKey(aKey) = True
     * @complexity O(log n)
     *}
    function AddOrAssign(const aKey: K; const aValue: V): Boolean;

    {**
     * Put
     *
     * @desc 写入键值对，不报告新增或更新
     *
     * @params
     *   aKey    键
     *   aValue  值
     *
     * @postcondition ContainsKey(aKey) = True
     * @complexity O(log n)
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败
     *}
    procedure Put(const aKey: K; const aValue: V);

    {**
     * Remove
     *
     * @desc 删除指定键的键值对
     *
     * @params
     *   aKey  要删除的键
     *
     * @return 删除成功返回 True，键不存在返回 False
     *
     * @postcondition ContainsKey(aKey) = False
     * @complexity O(log n)
     *}
    function Remove(const aKey: K): Boolean;

    {**
     * ContainsKey
     *
     * @desc 检查键是否存在
     *
     * @params
     *   aKey  要检查的键
     *
     * @return 键存在返回 True，否则返回 False
     *
     * @complexity O(log n)
     *}
    function ContainsKey(const aKey: K): Boolean;

    {**
     * GetKeyCount
     *
     * @desc 获取键值对数量
     *
     * @return 当前元素数量
     *
     * @complexity O(1)
     *}
    function GetKeyCount: SizeUInt;

    {**
     * GetKeys
     *
     * @desc 获取所有键的集合（按升序排列）
     *
     * @return 包含所有键的 TCollection
     *
     * @complexity O(n)
     * @note 调用者负责释放返回的集合
     *}
    function GetKeys: TCollection;

    {**
     * GetValues
     *
     * @desc 获取所有值的集合（按键升序排列）
     *
     * @return 包含所有值的 TCollection
     *
     * @complexity O(n)
     * @note 调用者负责释放返回的集合
     *}
    function GetValues: TCollection;

    // Clear 继承自 ICollection，不再重复声明

    { Entry API - Rust 风格的键值访问模式 }

    {**
     * GetOrInsert
     *
     * @desc 获取值，如果键不存在则插入默认值
     *
     * @params
     *   AKey      键
     *   ADefault  默认值（键不存在时插入）
     *
     * @return 键对应的值（已存在或新插入的）
     *
     * @complexity O(log n)
     *
     * @example
     *   count := tree.GetOrInsert('apple', 0);  // 不存在则插入 0
     *}
    function GetOrInsert(const AKey: K; const ADefault: V): V;

    {**
     * GetOrInsertWith
     *
     * @desc 获取值，如果键不存在则调用函数生成默认值
     *
     * @params
     *   AKey       键
     *   ASupplier  生成默认值的函数（仅在键不存在时调用）
     *
     * @return 键对应的值
     *
     * @complexity O(log n)
     * @note 比 GetOrInsert 更高效，因为只在需要时才计算默认值
     *}
    function GetOrInsertWith(const AKey: K; ASupplier: specialize TTreeValueSupplierFunc<V>): V;

    {**
     * ModifyOrInsert
     *
     * @desc 修改已有值或插入默认值 (Rust entry().and_modify().or_insert() 模式)
     *
     * @params
     *   AKey       键
     *   AModifier  修改函数（键存在时调用）
     *   ADefault   默认值（键不存在时插入）
     *
     * @complexity O(log n)
     *
     * @example
     *   // 统计单词频率
     *   tree.ModifyOrInsert(word, @IncValue, 1);
     *}
    procedure ModifyOrInsert(const AKey: K; AModifier: specialize TTreeValueModifierProc<V>; const ADefault: V);
  end;

implementation

end.
