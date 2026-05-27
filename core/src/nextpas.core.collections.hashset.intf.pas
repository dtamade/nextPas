unit nextpas.core.collections.hashset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

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

implementation

end.
