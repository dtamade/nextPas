unit nextpas.core.collections.multiset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IMultiSet<T>
   *
   * @desc 多重集合接口
   *}
  generic IMultiSet<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    {**
     * Add
     *
     * @desc 添加一个元素（计数+1）
     * @param aElement 要添加的元素
     * @return SizeUInt 添加后该元素的计数
     *}
    function Add(const aElement: T): SizeUInt;

    {**
     * AddN
     *
     * @desc 添加元素指定次数
     * @param aElement 要添加的元素
     * @param aCount 添加次数
     * @return SizeUInt 添加后该元素的计数
     *}
    function AddN(const aElement: T; aCount: SizeUInt): SizeUInt;

    {**
     * Remove
     *
     * @desc 移除一个元素（计数-1）
     * @param aElement 要移除的元素
     * @return Boolean 如果元素存在返回 True
     *}
    function Remove(const aElement: T): Boolean;

    {**
     * RemoveAll
     *
     * @desc 完全移除某个元素（计数清零）
     * @param aElement 要移除的元素
     * @return SizeUInt 移除前该元素的计数
     *}
    function RemoveAll(const aElement: T): SizeUInt;

    {**
     * Contains
     *
     * @desc 检查是否包含元素
     * @param aElement 要检查的元素
     * @return Boolean 如果计数 > 0 返回 True
     *}
    function Contains(const aElement: T): Boolean;

    {**
     * CountOf
     *
     * @desc 获取元素的计数
     * @param aElement 要查询的元素
     * @return SizeUInt 元素计数，不存在则返回 0
     *}
    function CountOf(const aElement: T): SizeUInt;

    {**
     * SetCount
     *
     * @desc 设置元素的计数
     * @param aElement 元素
     * @param aCount 新计数（0表示移除）
     *}
    procedure SetCount(const aElement: T; aCount: SizeUInt);

    {**
     * Clear
     *
     * @desc 清空所有元素
     *}
    procedure Clear;

    {**
     * GetCount
     *
     * @desc 获取唯一元素个数
     * @return SizeUInt 不同元素的数量
     *}
    function GetCount: SizeUInt;

    {**
     * GetTotalCount
     *
     * @desc 获取所有元素的总计数
     * @return SizeUInt 所有元素计数之和
     *}
    function GetTotalCount: SizeUInt;

    {**
     * IsEmpty
     *
     * @desc 检查是否为空
     * @return Boolean 如果没有元素返回 True
     *}
    function IsEmpty: Boolean;

    property Count: SizeUInt read GetCount;
    property TotalCount: SizeUInt read GetTotalCount;
  end;

implementation

end.
