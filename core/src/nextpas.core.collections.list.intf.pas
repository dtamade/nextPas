unit nextpas.core.collections.list.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type

  {**
   * IList<T>
   *
   * @desc 双向链表接口，提供 O(1) 双端操作
   *
   * @param T 元素类型
   *
   * @note 核心操作复杂度：
   *   - PushFront/PushBack: O(1)
   *   - PopFront/PopBack: O(1)
   *   - Front/Back: O(1)
   *   - 随机访问: O(n)
   *
   * @threadsafety 非线程安全
   * @see TList 具体实现
   * @see TVecDeque 高性能双端队列替代方案
   *}
  generic IList<T> = interface(specialize IGenericCollection<T>)
  ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']

    {**
     * PushFront
     *
     * @desc 在链表头部插入一个元素
     *
     * @params
     *   aElement  要插入的元素
     *
     * @postcondition Front = aElement, Count 增加 1
     *
     * @complexity O(1)
     *}
    procedure PushFront(const aElement: T);

    {**
     * PushBack
     *
     * @desc 在链表尾部插入一个元素
     *
     * @params
     *   aElement  要插入的元素
     *
     * @postcondition Back = aElement, Count 增加 1
     *
     * @complexity O(1)
     *}
    procedure PushBack(const aElement: T);

    {**
     * PopFront
     *
     * @desc 移除并返回链表头部的元素
     *
     * @return 被移除的头部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @postcondition Count 减少 1
     *
     * @complexity O(1)
     *}
    function PopFront: T;

    {**
     * PopBack
     *
     * @desc 移除并返回链表尾部的元素
     *
     * @return 被移除的尾部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @postcondition Count 减少 1
     *
     * @complexity O(1)
     *}
    function PopBack: T;

    {**
     * Front
     *
     * @desc 获取链表头部元素（不移除）
     *
     * @return 头部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @complexity O(1)
     *}
    function Front: T;

    {**
     * Back
     *
     * @desc 获取链表尾部元素（不移除）
     *
     * @return 尾部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @complexity O(1)
     *}
    function Back: T;

    {**
     * TryFront
     *
     * @desc 安全地获取头部元素
     *
     * @params
     *   aElement 输出参数，存储头部元素
     *
     * @return 如果链表非空返回 True，否则返回 False
     *}
    function TryFront(out aElement: T): Boolean;

    { 非异常批量导入/追加（集合重载） }
    function TryLoadFrom(const aSrc: TCollection): Boolean;
    function TryAppend(const aSrc: TCollection): Boolean;

    {**
     * TryBack
     *
     * @desc 安全地获取尾部元素
     *
     * @params
     *   aElement 输出参数，存储尾部元素
     *
     * @return 如果链表非空返回 True，否则返回 False
     *}
    function TryBack(out aElement: T): Boolean;

    {**
     * TryPopFront
     *
     * @desc 安全地弹出头部元素
     *
     * @params
     *   aElement 输出参数，存储被弹出的元素
     *
     * @return 如果成功弹出返回 True，否则返回 False
     *}
    function TryPopFront(out aElement: T): Boolean;

    {**
     * TryPopBack
     *
     * @desc 安全地弹出尾部元素
     *
     * @params
     *   aElement 输出参数，存储被弹出的元素
     *
     * @return 如果成功弹出返回 True，否则返回 False
     *}
    function TryPopBack(out aElement: T): Boolean;

    {**
     * 高性能方法（无安全检查版本）
     *
     * @remark
     *   这些方法跳过所有安全检查以获得最佳性能
     *   调用者必须确保参数和状态的有效性
     *   遵循项目 Unchecked 命名规范
     *}

    {**
     * PushFrontUnchecked
     *
     * @desc 在链表头部插入元素（无安全检查版本）
     *}
    procedure PushFrontUnchecked(const aElement: T);

    {**
     * PushBackUnchecked
     *
     * @desc 在链表尾部插入元素（无安全检查版本）
     *}
    procedure PushBackUnchecked(const aElement: T);

    {**
     * PopFrontUnchecked
     *
     * @desc 移除并返回头部元素（无安全检查版本）
     *}
    function PopFrontUnchecked: T;

    {**
     * PopBackUnchecked
     *
     * @desc 移除并返回尾部元素（无安全检查版本）
     *}
    function PopBackUnchecked: T;

    {**
     * PushRangeUnchecked
     *
     * @desc 批量插入数组元素到链表尾部（无安全检查版本）
     *}
    procedure PushRangeUnchecked(const aArray: array of T);

    {**
     * ClearUnchecked
     *
     * @desc 清空链表（无安全检查版本）
     *}
    procedure ClearUnchecked;

  end;

implementation

end.
