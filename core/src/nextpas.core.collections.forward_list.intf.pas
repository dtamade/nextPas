unit nextpas.core.collections.forward_list.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type

  { IForwardList 单向链表接口 }
  generic IForwardList<T> = interface(specialize IGenericCollection<T>)
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    {**
     * PushFront
     *
     * @desc 在链表头部插入一个元素
     *
     * @params
     *   aElement 要插入的元素
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   插入后，新元素成为链表的第一个元素
     *
     * @exceptions
     *   EOutOfMemory 如果内存分配失败
     *}
    procedure PushFront(const aElement: T);

    {**
     * PopFront
     *
     * @desc 移除并返回链表头部的元素
     *
     * @return 被移除的头部元素
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   移除后，原来的第二个元素（如果存在）成为新的头部元素
     *
     * @exceptions
     *   EInvalidOperation 如果链表为空
     *}
    function PopFront: T;

    {**
     * TryPopFront
     *
     * @desc 尝试移除并返回链表头部的元素（安全版本）
     *
     * @params
     *   aElement 输出参数，如果成功则包含被移除的元素
     *
     * @return 如果成功移除元素返回 True，否则返回 False
     *
     * @remark
     *   此方法不会抛出异常，适用于不确定链表是否为空的场景
     *   如果链表为空，返回 False 且 aElement 的值未定义
     *}
    function TryPopFront(out aElement: T): Boolean;

    {**
     * Front
     *
     * @desc 获取链表头部元素（不移除）
     *
     * @return 头部元素的值（按值返回）
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   注意：本方法按值返回，不提供可直接修改的引用
     *
     * @exceptions
    *   EInvalidOperation 如果链表为空
    *}
    function Front: T;

    { 非异常批量导入/追加（指针重载） }
    function TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
    function TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;

    { 非异常批量导入/追加（集合重载） }
    function TryLoadFrom(const aSrc: TCollection): Boolean;
    function TryAppend(const aSrc: TCollection): Boolean;

    {**
     * TryFront
     *
     * @desc 尝试获取链表头部元素（安全版本）
     *
     * @params
     *   aElement 输出参数，如果成功则包含头部元素的副本
     *
     * @return 如果链表非空返回 True，否则返回 False
     *
     * @remark
     *   此方法不会抛出异常
     *   如果链表为空，返回 False 且 aElement 的值未定义
     *}
    function TryFront(out aElement: T): Boolean;

    {**
     * InsertAfter
     *
     * @desc 在指定位置之后插入一个元素
     *
     * @params
     *   aPosition 插入位置的迭代器
     *   aElement  要插入的元素
     *
     * @return 指向新插入元素的迭代器
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   如果 aPosition 指向链表末尾，新元素将成为新的末尾元素
     *
     * @exceptions
     *   EInvalidArgument 如果 aPosition 无效或不属于此链表
     *   EOutOfMemory     如果内存分配失败
     *}
    function InsertAfter(aPosition: specialize TIter<T>; const aElement: T): specialize TIter<T>;

    {**
     * EraseAfter
     *
     * @desc 移除指定位置之后的元素
     *
     * @params
     *   aPosition 要移除元素的前一个位置的迭代器
     *
     * @return 指向被移除元素之后元素的迭代器，如果移除的是最后一个元素则返回 end 迭代器
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   如果 aPosition 指向最后一个元素，则此操作无效果
     *
     * @exceptions
     *   EInvalidArgument 如果 aPosition 无效或不属于此链表
     *   EInvalidOperation 如果 aPosition 之后没有元素可移除
     *}
    function EraseAfter(aPosition: specialize TIter<T>): specialize TIter<T>;

    {**
     * Remove
     *
     * @desc 移除所有等于指定值的元素
     *
     * @params
     *   aElement 要移除的元素值
     *
     * @return 被移除的元素数量
     *
     * @remark
     *   此操作的时间复杂度为 O(n)，其中 n 是链表长度
     *   使用默认的相等比较器进行元素比较
     *}
    function Remove(const aElement: T): SizeUInt; overload;

    {**
     * Remove
     *
     * @desc 移除所有等于指定值的元素（自定义比较器版本）
     *
     * @params
     *   aElement 要移除的元素值
     *   aEquals  自定义相等比较函数
     *   aData    传递给比较函数的用户数据
     *
     * @return 被移除的元素数量
     *}
    function Remove(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * Remove
     *
     * @desc 移除所有等于指定值的元素（对象方法版本）
     *
     * @params
     *   aElement 要移除的元素值
     *   aEquals  自定义相等比较方法
     *   aData    传递给比较方法的用户数据
     *
     * @return 被移除的元素数量
     *}
    function Remove(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Remove
     *
     * @desc 移除所有等于指定值的元素（匿名引用函数版本）
     *
     * @params
     *   aElement 要移除的元素值
     *   aEquals  自定义相等比较匿名函数
     *
     * @return 被移除的元素数量
     *
     * @remark 使用此接口需要在 fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function Remove(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * RemoveIf
     *
     * @desc 移除所有满足条件的元素
     *
     * @params
     *   aPredicate 判断条件函数
     *   aData      传递给条件函数的用户数据
     *
     * @return 被移除的元素数量
     *
     * @remark
     *   此操作的时间复杂度为 O(n)，其中 n 是链表长度
     *   条件函数返回 True 的元素将被移除
     *}
    function RemoveIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * RemoveIf
     *
     * @desc 移除所有满足条件的元素（对象方法版本）
     *
     * @params
     *   aPredicate 判断条件方法
     *   aData      传递给条件方法的用户数据
     *
     * @return 被移除的元素数量
     *}
    function RemoveIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * RemoveIf
     *
     * @desc 移除所有满足条件的元素（匿名引用函数版本）
     *
     * @params
     *   aPredicate 判断条件匿名函数
     *
     * @return 被移除的元素数量
     *
     * @remark 使用此接口需要在 fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function RemoveIf(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * Find
     *
     * @desc 查找第一个等于指定值的元素
     *
     * @params
     *   aElement 要查找的元素值
     *
     * @return 指向找到元素的迭代器，如果未找到则返回 end 迭代器
     *
     * @remark
     *   此操作的时间复杂度为 O(n)，其中 n 是链表长度
     *   使用默认的相等比较器进行元素比较
     *}
    function Find(const aElement: T): specialize TIter<T>; overload;

    {**
     * Find
     *
     * @desc 查找第一个等于指定值的元素（自定义比较器版本）
     *
     * @params
     *   aElement 要查找的元素值
     *   aEquals  自定义相等比较函数
     *   aData    传递给比较函数的用户数据
     *
     * @return 指向找到元素的迭代器，如果未找到则返回 end 迭代器
     *}
    function Find(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): specialize TIter<T>; overload;

    {**
     * FindIf
     *
     * @desc 查找第一个满足条件的元素
     *
     * @params
     *   aPredicate 判断条件函数
     *   aData      传递给条件函数的用户数据
     *
     * @return 指向找到元素的迭代器，如果未找到则返回 end 迭代器
     *
     * @remark
     *   此操作的时间复杂度为 O(n)，其中 n 是链表长度
     *   条件函数返回 True 的第一个元素将被返回
     *}
    function FindIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): specialize TIter<T>; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * FindIf
     *
     * @desc 查找第一个满足条件的元素（匿名引用函数版本）
     *
     * @params
     *   aPredicate 判断条件匿名函数
     *
     * @return 指向找到元素的迭代器，如果未找到则返回 end 迭代器
     *
     * @remark 使用此接口需要在 fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function FindIf(aPredicate: specialize TPredicateRefFunc<T>): specialize TIter<T>; overload;
    {$ENDIF}

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
     * @desc 在链表头部插入一个元素（无安全检查版本）
     *
     * @params
     *   aElement 要插入的元素
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   跳过所有安全检查以获得最佳性能
     *}
    procedure PushFrontUnchecked(const aElement: T);

    {**
     * PopFrontUnchecked
     *
     * @desc 移除并返回链表头部的元素（无安全检查版本）
     *
     * @return 被移除的头部元素
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   跳过空链表检查以获得最佳性能
     *   调用者必须确保链表非空
     *}
    function PopFrontUnchecked: T;

    {**
     * EmplaceFrontUnchecked
     *
     * @desc 在链表头部就地构造一个元素（无安全检查版本）
     *
     * @params
     *   aElement 要构造的元素
     *
     * @remark
     *   此操作的时间复杂度为 O(1)
     *   跳过所有安全检查以获得最佳性能
     *}
    procedure EmplaceFrontUnchecked(const aElement: T);

    {**
     * PushFrontRangeUnchecked
     *
     * @desc 批量在链表头部插入元素（无安全检查版本）
     *
     * @params
     *   aArray 要插入的元素数组
     *
     * @remark
     *   此操作的时间复杂度为 O(n)，其中 n 是数组长度
     *   跳过所有安全检查以获得最佳性能
     *   元素按数组顺序插入，最后一个元素成为新的头部
     *}
    procedure PushFrontRangeUnchecked(const aArray: array of T);

    {**
     * ClearUnchecked
     *
     * @desc 清空链表（无安全检查版本）
     *
     * @remark
     *   此操作的时间复杂度为 O(n)
     *   跳过所有安全检查以获得最佳性能
     *   直接释放所有节点，不进行额外验证
     *}
    procedure ClearUnchecked;

  end;

implementation

end.
