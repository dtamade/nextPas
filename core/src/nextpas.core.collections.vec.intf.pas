unit nextpas.core.collections.vec.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.arr.intf;

type
  {**
   * IVec<T>
   *
   * @desc 动态向量接口，连续内存的可变长度数组
   *
   * @param T 元素类型
   *
   * @note 核心操作复杂度：
   *   - Push/Pop: O(1) 摊销
   *   - Get/Put: O(1)
   *   - Insert/Delete: O(n)
   *   - DeleteSwap: O(1)
   *
   * @threadsafety 非线程安全，并发访问需外部同步
   * @see TVec 具体实现
   * @see docs/README_TVec.md 快速指南
   *}
  generic IVec<T> = interface(specialize IArray<T>)
  ['{C205D988-F671-4E47-8573-9AF2C85AC749}']


    {**
     * GetCapacity
     *
     * @desc 获取当前容量
     *
     * @return SizeUInt 当前容量
     *
     * @complexity O(1)
     *}
    function GetCapacity: SizeUInt;

    {**
     * SetCapacity
     *
     * @desc Sets the vector's capacity
     * @param aCapacity The capacity to set
     * @note Throws exception if operation fails
     *}
    procedure SetCapacity(aCapacity: SizeUInt);

    {**
     * GetGrowStrategy
     *
     * @desc Gets the vector's current growth strategy
     * @return IGrowthStrategy The growth strategy
     * @note
     *   The growth strategy determines how the internal storage expands when
     *   capacity is insufficient. This is a key parameter affecting performance
     *   and memory usage efficiency.
     *}
    function GetGrowStrategy: IGrowthStrategy;

    {**
     * SetGrowStrategy
     *
     * @desc Sets the vector's capacity growth strategy
     * @param aGrowStrategy The growth strategy to set
     * @note
     *   By changing the growth strategy, you can adjust the container's behavior
     *   during automatic expansion, trading off between memory usage and
     *   reallocation frequency (affecting performance).
     *
     *   If set to nil, the container will use the default `TFactorGrowStrategy(1.5)`
     *   (1.5x factor growth) strategy. The default strategy provides better balance
     *   between memory usage and reallocation count, suitable for general scenarios.
     *
     *   User can create custom strategies and set them to the container. The
     *   strategy object's lifecycle is managed by the user.
     *
     *   Built-in growth strategies include:
     *     TCustomGrowthStrategy    Custom callback growth strategy. Fine control via callback.
     *     TDoublingGrowStrategy    Exponential growth (capacity * 2). Widely used.
     *     TFixedGrowStrategy       Fixed linear growth (每次 += fixedSize). High memory efficiency.
     *     TFactorGrowStrategy      Factor growth (capacity *= factor). Adjustable.
     *     TPowerOfTwoGrowStrategy  Capacity extended to next power of 2.
     *     TGoldenRatioGrowStrategy Golden ratio growth (capacity *= 1.618). Low waste.
     *     TAlignedWrapperStrategy  Alignment wrapper. Align capacity to byte boundary.
     *     TExactGrowStrategy       Exact growth. Exactly fits requirements, but frequent allocation.
     *}
    procedure SetGrowStrategy(aGrowStrategy: IGrowthStrategy);

	    {**
	     * GetGrowStrategyI / SetGrowStrategyI
	     *
	     * @desc Get/set growth strategy via interface (interface-first approach)
	     *       Set to nil to restore default strategy (1.5x factor growth)
	     *       Provides this interface variant to decouple implementation
	     *       and facilitate A/B testing.
	     *}


    {**
     * TryReserve
     *
     * @desc Attempts to reserve additional capacity (Count + aAdditional)
     * @param aAdditional Additional capacity to reserve
     * @return Boolean True if successful, False otherwise
     * @note
     *   If reservation fails, no exception is thrown (returns False)
     *   Reserved space may be larger than requested due to growth strategy
     *   If current capacity is sufficient, no operation is performed
     *}
    function TryReserve(aAdditional: SizeUInt): Boolean;

    { Non-exception bulk import/append (pointer overload) }
    function TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; overload;
    function TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; overload;

    {**
     * Reserve
     *
     * @desc 预留额外容量
     *
     * @params
     *   aAdditional  需要预留的额外容量
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败
     *
     * @complexity O(n) 最坏（需要复制现有元素）
     *
     * @note 实际容量可能大于请求值（受增长策略影响）
     *}
    procedure Reserve(aAdditional: SizeUInt);

    {**
     * TryReserveExact
     *
     * @desc Attempts to reserve exact capacity
     * @param aAdditional Exact capacity to reserve
     * @return Boolean True if successful, False otherwise
     * @note
     *   If reservation fails, no exception is thrown
     *   Unlike Reserve, this tries to allocate exactly the requested space
     *   May fail if allocation is not possible
     *}
    function TryReserveExact(aAdditional: SizeUInt): Boolean;
    procedure ReserveExact(aAdditional: SizeUInt);

    {**
     * EnsureCapacity
     *
     * @desc 确保容量至少为指定值（仅扩容，不改变 Count）
     *}
    procedure EnsureCapacity(aCapacity: SizeUInt);

    {**
     * Shrink
     *
     * @desc 收缩向量容量到实际使用的大小,释放多余的内存空间。
     *
     * @remark
     *   如果收缩失败会抛出异常
     *   收缩后的容量等于当前元素数量
     *   注意：建议在实际业务中优先使用 ShrinkToFit（带滞回），以避免频繁抖动。
     *}
    procedure Shrink;

    {**
     * ShrinkTo
     *
     * @desc 收缩向量容量到指定大小,释放多余的内存空间。
     *
     * @params
     *   aCapacity 要收缩到的容量大小
     *
     * @remark
     *   如果收缩失败会抛出异常
     *   如果指定的容量小于当前元素数量则会抛出异常(因为会截断元素)
     *   如果指定收缩的容量大于当前容量,什么也不会发生
     *}
    procedure ShrinkTo(aCapacity: SizeUInt);

    {**
     * ShrinkToFit
     *
     * @desc 在容量远超需求时进行收缩（滞回策略），避免抖动。
     *       当前策略：当 CapacityBytes > max(2×UsedBytes, 64 KiB) 时，收缩到 Count。
     *       其中 UsedBytes = Count * ElementSize，CapacityBytes = Capacity * ElementSize。
     *}
    procedure ShrinkToFit;

    {**
     * FreeBuffer
     *
     * @desc 释放底层缓冲（SetCapacity(0)）。
     *       用于需要显式归还内存的场景。
     *}
    procedure FreeBuffer;

    {**
     * Truncate
     *
     * @desc 截断向量到指定数量，丢弃被截断的尾部元素。
     *
     * @params
     *   aCount 要截断到的元素数量
     *
     * @remark
     *   如果指定数量大于当前元素数量，不进行任何操作
     *   不会释放内存空间（不影响 Capacity），仅修改元素数量
     *   如需同时缩减容量，请组合使用 Truncate + Shrink
     *}
    procedure Truncate(aCount: SizeUInt);

    {**
     * ResizeExact
     *
     * @desc 精确重置向量大小
     *
     * @params
     *   aNewSize 要重置的元素数量与容量大小（精确设置）
     *
     * @remark
     *   此接口精确改变容器大小与容量；若新大小小于当前大小，会丢弃多余元素
     *   与 Resize 不同：Resize 依据增长策略扩容，ResizeExact 严格按新大小设置容量
     *
     * @exceptions
     *   EAlloc 内存分配/调整失败.
     *}
    procedure ResizeExact(aNewSize: SizeUInt);



    { Insert 系列接口 }

    {**
     * Insert
     *
     * @desc 在指定位置插入多个元素（从指针拷贝）
     *
     * @params
     *   aIndex  要插入的位置
     *   aSrc    要插入的指针
     *   aCount  要插入的元素数量


     *
     * @remark
     *   如果插入失败会抛出异常
     *   索引必须小于等于当前元素数量(<= Count)
     *   插入成功后指定索引处的元素会向后移动(低效)
     *}
    procedure Insert(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;

    {**
     * Insert
     *
     * @desc 在指定位置插入一个元素
     *
     * @params
     *   aIndex    要插入的位置（0 <= aIndex <= Count）
     *   aElement  要插入的元素
     *
     * @exceptions
     *   EOutOfRange   索引越界
     *   EOutOfMemory  内存分配失败
     *
     * @complexity O(n) 需要移动后续元素
     *}
    procedure Insert(aIndex: SizeUInt; const aElement: T); overload;

    {**
     * Insert
     *
     * @desc 在指定位置插入多个元素
     *
     * @params
     *   aIndex 要插入的位置
     *   aSrc   要插入的元素数组
     *
     * @remark
     *   如果插入失败会抛出异常
     *   索引必须小于等于当前元素数量(<= Count)
     *   插入成功后指定索引处的元素会向后移动(低效)
     *}
    procedure Insert(aIndex: SizeUInt; const aSrc: array of T); overload;

    {**
     * Insert
     *
     * @desc 在指定位置插入集合元素（拷贝）
     *
     * @params
     *   aIndex  要插入的位置
     *   aSrc    要插入的泛型容器
     *   aCount  要插入的元素数量
     *
     * @remark
     *   如果插入失败会抛出异�?
     *   索引必须小于等于当前元素数量(<= Count)
     *   插入成功后指定索引处原来的元素会向后移动(低效)
     *}
    procedure Insert(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;



    { Write 系列接口 }

    {**
     * Write
     *
     * @desc 从指针内存写入多个元素到指定位置
     *
     * @params
     *   aIndex  要写入的元素位置
     *   aSrc    要写入的指针
     *   aCount  要写入的元素数量
     *
     * @remark
     *   超出容量会自动扩容
     *   目标索引边界是Count位置,不得超越
     *
     * @exceptions
     *   EArgumentNil      `aSrc` 为 `nil`。
     *   EOutOfRange       索引越界。
     *}
    procedure Write(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;

    {**
     * Write
     *
     * @desc 在容器内指定位置写入一个动态数组的全部内容，必要时自动扩容
     *
     * @params
     *   aIndex 容器内开始写入的起始索引 (0-based).
     *   aSrc   包含源数据的动态数�?
     *
     * @remark
     *   写入的元素数量由 Length(aSrc) 决定.
     *   如果 aIndex + Length(aSrc) 超出当前 Count, 容器将被扩容.
     *   如果 aSrc 为空, 此操作不产生任何效果.
     *
     * @exceptions
     *   EAlloc           如果内存分配失败.
     *   ERangeOutOfIndex 索引越界
     *}
    procedure Write(aIndex: SizeUInt; const aSrc: array of T); overload;

    {**
     * Write
     *
     * @desc 在容器内指定位置写入另一个容器的全部内容，必要时自动扩容
     *
     * @params
     *   aIndex 容器内开始写入的起始索引 (0-based).
     *   aSrc   提供源数据的容器.
     *
     * @remark
     *   写入的元素数量由 `aSrc.GetCount` 决定.
     *   如果 `aIndex + aSrc.GetCount` 超出当前 Count, 容器将被扩容.
     *
     * @exceptions
     *   EArgumentNil     `aSrc` 为 `nil`。
     *   EOutOfRange      索引越界
     *   ESelf            `aSrc` 是容器自身
     *   ENotCompatible   `aSrc` 与当前容器不兼容.
     *   EAlloc           如果内存分配失败.
     *}
    procedure Write(aIndex: SizeUInt; const aSrc: TCollection); overload;

    {**
     * Write
     *
     * @desc 在容器内指定位置写入另一个容器的全部内容，必要时自动扩容
     *
     * @params
     *   aIndex 容器内开始写入的起始索引 (0-based).
     *   aSrc   提供源数据的容器.
     *   aCount 要写入的元素数量
     *
     * @remark
     *   写入的元素数量由 `aCount` 决定.
     *   如果 aIndex + aCount 超出当前 Count, 容器将被扩容.
     *   如果 aCount = 0，此操作不产生任何效果。
     *
     * @exceptions
     *   EArgumentNil   如果 aCollection 为 nil。
     *   ESelf          如果 aCollection 是容器自身
     *   ENotCompatible 如果 aCollection 与当前容器不兼容.
     *   EAlloc         如果内存分配失败.
     *}
    procedure Write(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;

    {**
     * WriteExact
     *
     * @desc 精确将指定内存指针处的多个元素复制到容器中的指定位置（拷贝）
     *
     * @params
     *   aIndex  要写入的索引
     *   aSrc    要写入的内存指针
     *   aCount  要写入的元素数量
     *
     * @return 返回是否写入成功
     *
     * @remark
     *   aIndex  必须为有效索引
     *   aSrc    必须为有效指针
     *   aCount  必须大于 0
     *   遇到扩容时不再遵循增长策略，而是精确扩容到正好容纳元素的容量
     *}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);

    {**
     * WriteExact
     *
     * @desc 精确写入元素数组
     *
     * @params
     *   aIndex 要写入的索引
     *   aSrc   要写入的元素数组
     *
     * @return 返回是否写入成功
     *
     * @remark
     *   aIndex 必须为有效索引
     *   aArray 必须为有效数组
     *   aCount 必须大于 0
     *   遇到扩容时不再遵循增长策略，而是精确扩容到正好容纳元素的容量
     *}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: array of T);

    {**
     * WriteExact
     *
     * @desc 精确写入元素数组
     *
     * @params
     *   aIndex 要写入的索引
     *   aSrc   要写入的元素容器
     *
     * @return 返回是否写入成功
     *
     * @remark
     *   aIndex 必须为有效索引
     *   aCollection 必须为有效容器
     *   遇到扩容时不再遵循增长策略，而是精确扩容到正好容纳元素的容量
     *}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: TCollection); overload;

    {**
     * WriteExact
     *
     * @desc 精确写入元素数组
     *
     * @params
     *   aIndex 要写入的索引
     *   aSrc   要写入的元素容器
     *   aCount 要写入的元素数量
     *
     * @return 返回是否写入成功
     *
     * @remark
     *   aIndex 必须为有效索引
     *   aCollection 必须为有效容器
     *   aCount 必须大于 0
     *   遇到扩容时不再遵循增长策略，而是精确扩容到正好容纳元素的容量
     *}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);



    { 栈操作系列接口 }

    {**
     * Push
     *
     * @desc 在末尾添加多个元�?从指针拷�?
     *
     * @params
     *   aSrc    指针
     *   aCount  元素数量
     *
     * @remark 指针内存应为泛型元素数组内存
     *}
    procedure Push(const aSrc: Pointer; aCount: SizeUInt); overload;

    {**
     * Push
     *
     * @desc 在末尾添加数组元�?拷贝)
     *
     * @params
     *   aElements 元素数组
     *}
    procedure Push(const aSrc: array of T); overload;

    {**
     * Push
     *
     * @desc 在末尾添加容器指定数量的元素(拷贝)
     *
     * @params
     *   aSrc   要添加的集合
     *   aCount 要添加的元素数量
     *
     *
     * @remark 如果容器为空会抛出异�?
     *}
    procedure Push(const aSrc: TCollection; aCount: SizeUInt); overload;

    {**
     * Push
     *
     * @desc 在末尾添加一个元素
     *
     * @params
     *   aElement  要添加的元素
     *
     * @complexity O(1) 摊销，O(n) 最坏（触发扩容时）
     *}
    procedure Push(const aElement: T); overload;


    {**
     * TryPop
     *
     * @desc 尝试从末尾弹出多个元素拷贝到指定指针内存
     *
     * @params
     *   aDst    指针
     *   aCount  元素数量
     *
     * @return 如果成功弹出返回 True,否则返回 False
     *
     * @remark
     *   Try 方法保证永不抛异常，会检查所有参数的有效性
     *   如果 aDst 为 nil 或 aCount 超出容器元素数量，返回 False
     *}
    function TryPop(aDst: Pointer; aCount: SizeUInt): Boolean; overload;

    {**
     * TryPop
     *
     * @desc 尝试从末尾弹出多个元素拷贝到指定数组
     *
     * @params
     *   aElements  元素数组
     *   aCount     元素数量
     *
     * @return 如果成功移除返回 True,否则返回 False
     *}
    function TryPop(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean; overload;

    {**
     * TryPop
     *
     * @desc 尝试从末尾弹出单个元素拷贝到指定元素内存变量
     *
     * @params
     *   aDst 目标变量
     *
     * @return 如果成功移除返回 True,否则返回 False
      *}
      function TryPop(var aDst: T): Boolean; overload;

    {**
     * Pop
     *
     * @desc 从末尾移除一个元素
     *
     * @return 返回移除的元素
     *
     * @exceptions
     *   EOutOfRange  容器为空
     *
     * @complexity O(1)
     *}
    function Pop: T; overload;

    {**
     * TryPeekCopy
     *
     * @desc 尝试拷贝末尾多个元素到指定指针内存
     *
     * @params
     *   aDst    指针
     *   aCount  元素数量
     *
     * @return 如果成功读取返回 True,否则返回 False
     *}
    function TryPeekCopy(aDst: Pointer; aCount: SizeUInt): Boolean; overload;

    {**
     * TryPeek
     *
     * @desc 尝试拷贝末尾多个元素到指定数组内存
     *
     * @params
     *   aDst    元素数组
     *   aCount  元素数量
     *
     * @return 如果成功获取返回 True,否则返回 False
     *
     * @remark 数组会被修改长度为指定大小
     *}
    function TryPeek(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean; overload;

    {**
     * TryPeek
     *
     * @desc 尝试获取末尾一个元素拷贝到指定元素内存变量
     *
     * @params
     *   aElement 元素
     *
     * @return 如果成功获取返回 True,否则返回 False
     *}
    function TryPeek(out aElement: T): Boolean; overload;

    {**
     * PeekRange
     *
     * @desc 获取从末尾开始指定数量的元素的指针(容器内的指针)
     *
     * @params
     *   aCount 元素数量
     *
     * @return 返回指针
     *
     * @remark 如果容器为空或者元素数量大于容器数量会返回 nil
     *}
    function PeekRange(aCount: SizeUInt): specialize TElementRef<T>.PElement; overload;

    {**
     * Peek
     *
     * @desc 获取末尾一个元素
     *
     * @return 返回末尾元素
     *
     * @remark 如果容器为空会抛出异常
     *}
    function Peek: T; overload;


    {**
     * Delete
     *
     * @desc 删除指定位置的元素(低效操作)
     *
     * @params
     *   aIndex  要删除的元素位置
     *   aCount  要删除的元素数量
     *
     * @remark
     *   如果指定位置后有元素,则这些元素会向前移动,在大量数据下非常低效,如果不介意元素顺序,请使用 DeleteSwap
     *   如果删除失败会抛出异常
     *   如果删除的元素数量大于容器数量会抛出异常
     *   如果删除的元素数量小于0会抛出异常
     *}
    procedure Delete(aIndex, aCount: SizeUInt); overload;

    {**
     * Delete
     *
     * @desc 删除指定位置的元素
     *
     * @params
     *   aIndex  要删除的元素位置
     *
     * @exceptions
     *   EOutOfRange  索引越界
     *
     * @complexity O(n) 需要移动后续元素
     *
     * @note 如不关心元素顺序，建议使用 DeleteSwap (O(1))
     *}
    procedure Delete(aIndex: SizeUInt); overload;

    {**
     * DeleteSwap
     *
     * @desc 删除指定位置的元素并用最后一个元素填充删除的位置(交换)
     *
     * @params
     *   aIndex  要删除的元素位置
     *   aCount  要删除的元素数量
     *
     * @remark
     *   此函数是一种高效的删除操作,可以避免元素的移动但会破坏元素的顺序适合不敏感的场合
     *   如果删除失败会抛出异常
     *   如果删除的元素数量大于容器数量会抛出异常
     *   如果删除的元素数量小于0会抛出异常
     *}
    procedure DeleteSwap(aIndex, aCount: SizeUInt); overload;

    {**
     * DeleteSwap
     *
     * @desc 交换删除：用末尾元素替换被删除位置
     *
     * @params
     *   aIndex  要删除的元素位置
     *
     * @exceptions
     *   EOutOfRange  索引越界
     *
     * @complexity O(1) 不需要移动元素
     *
     * @note 会破坏元素顺序，适用于不关心顺序的场景
     *}
    procedure DeleteSwap(aIndex: SizeUInt); overload;


    { 关于 Delete 和 Remove 的说明 "擦掉"和"移走" }

    {**
     * RemoveCopy
     *
     * @desc 移除指定位置指定数量的元素并拷贝到指定指针内存
     *
     * @params
     *   aIndex  要移除的元素位置
     *   aDst    保存元素的内存指针
     *   aCount  要移除的元素数量
     *
     * @remark
     *   如果指定位置后有元素,则这些元素会向前移动,在大量数据下非常低效,如果不介意元素顺序,请使用 RemoveCopySwap
     *   请确保aDst指向的内存空间足够容纳aCount个元素
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveCopy(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload;

    {**
     * RemoveCopy
     *
     * @desc 移除指定位置的元素并拷贝到指定指针内存
     *
     * @params
     *   aIndex 要移除的元素位置
     *   aDst   保存元素的内存指针
     *
     * @remark
     *   如果指定位置后有元素,则这些元素会向前移动,在大量数据下非常低效,如果不介意元素顺序,请使用 RemoveCopySwap
     *   请确保aDst指向的内存空间足够容纳1个元素
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveCopy(aIndex: SizeUInt; aDst: Pointer); overload;

    {**
     * RemoveArray
     *
     * @desc 移除指定位置指定数量的元素并拷贝到指定数组内存
     *
     * @params
     *   aIndex     要移除的元素位置
     *   aElements  保存元素的数组变量
     *   aCount     要移除的元素数量
     *
     * @remark
     *   aElements指向的数组数量会被自动调整
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveArray(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt); overload;

    {**
     * Remove
     *
     * @desc 移除指定位置的元素并拷贝到指定元素变量
     *
     * @params
     *   aIndex   要移除的元素位置
     *   aElement 保存元素的元素变量
     *
     * @remark
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure Remove(aIndex: SizeUInt; var aElement: T); overload;

    {**
     * Remove
     *
     * @desc 移除指定位置的元素
     *
     * @params
     *   aIndex 要移除的元素位置
     *
     * @return 返回移除的元素
     *
     * @remark
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    function Remove(aIndex: SizeUInt): T; overload;



    {**
     * RemoveCopySwap
     *
     * @desc 移除指定位置指定数量的元素并拷贝到指定指针,并用最后一个元素填充删除数据的位置(交换)
     *
     * @params
     *   aIndex  要移除的元素位置
     *   aDst    保存元素的内存指针
     *   aCount  要移除的元素数量
     *
     * @remark
     *   请确保aDst指向的内存空间足够容纳aCount个元素
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveCopySwap(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload;

    {**
     * RemoveCopySwap
     *
     * @desc 移除指定位置的元素并拷贝到指定指针,并用最后一个元素填充删除数据的位置(交换)
     *
     * @params
     *   aIndex 要移除的元素位置
     *   aDst   保存元素的内存指针
     *
     * @remark
     *   请确保aDst指向的内存空间足够容纳1个元素
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveCopySwap(aIndex: SizeUInt; aDst: Pointer); overload;


    {**
     * RemoveArraySwap
     *
     * @desc 移除指定位置指定数量的元素,并用最后一个元素填充删除的位置(交换)
     *
     * @params
     *   aIndex     要移除的元素位置
     *   aElements  保存元素的数组变量
     *   aCount     要移除的元素数量
     *
     * @remark
     *   aElements指向的数组数量会被自动调整
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveArraySwap(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt); overload;

    {**
     * RemoveSwap
     *
     * @desc 移除指定位置的元素并用最后一个元素填充删除的位置(交换)
     *
     * @params
     *   aIndex   要移除的元素位置
     *   aElement 保存元素的元素变量
     *
     * @remark
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    procedure RemoveSwap(aIndex: SizeUInt; var aElement: T); overload;

    {**
     * RemoveSwap
     *
     * @desc 移除指定位置的元素并用最后一个元素填充删除的位置(交换)
     *
     * @params
     *   aIndex 要移除的元素位置
     *
     * @return 返回移除的元素
     *
     * @remark
     *   如果移除失败会抛出异常
     *   如果移除的元素数量大于容器数量会抛出异常
     *   如果移除的元素数量小于0会抛出异常
     *}
    function RemoveSwap(aIndex: SizeUInt): T; overload;

    {**
     * Filter
     *
     * @desc 根据谓词函数过滤元素，返回包含满足条件元素的新向量
     *
     * @param aPredicate 谓词函数，返回 True 的元素将被保留
     * @param aData 传递给谓词函数的额外数据指针
     * @return 包含满足条件元素的新向量
     *
     * @remark
     *   这是函数式编程的核心操作之一
     *   返回的新向量使用相同的分配器和增长策略
     *}
    function Filter(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): specialize IVec<T>; overload;
    function Filter(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): specialize IVec<T>; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Filter(aPredicate: specialize TPredicateRefFunc<T>): specialize IVec<T>; overload;
    {$ENDIF}

    {**
     * Any
     *
     * @desc 检查是否存在至少一个元素满足谓词条件
     *
     * @param aPredicate 谓词函数
     * @param aData 传递给谓词函数的额外数据指针
     * @return 如果存在满足条件的元素返回 True，否则返回 False
     *
     * @remark
     *   如果向量为空，返回 False
     *   一旦找到满足条件的元素就立即返回，具有短路特性
     *}
    function Any(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function Any(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Any(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * All
     *
     * @desc 检查是否所有元素都满足谓词条件
     *
     * @param aPredicate 谓词函数
     * @param aData 传递给谓词函数的额外数据指针
     * @return 如果所有元素都满足条件返回 True，否则返回 False
     *
     * @remark
     *   如果向量为空，返回 True
     *   一旦找到不满足条件的元素就立即返回，具有短路特性
     *}
    function All(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function All(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function All(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * Retain
     *
     * @desc 就地过滤，保留满足谓词条件的元素，删除不满足条件的元素
     *
     * @param aPredicate 谓词函数，返回 True 的元素将被保留
     * @param aData 传递给谓词函数的额外数据指针
     *
     * @remark
     *   这是高性能的就地操作，不会分配新的向量
     *   比 Filter 更高效，因为避免了内存分配和元素拷贝
     *   操作后向量大小可能会改变
     *}
    procedure Retain(aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure Retain(aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Retain(aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}

    {**
     * Drain
     *
     * @desc 高效的范围删除，返回被删除的元素组成的新向量
     *
     * @param aStart 开始索引
     * @param aCount 要删除的元素数量
     * @return 包含被删除元素的新向量
     *
     * @remark
     *   这是高性能的范围删除操作
     *   比逐个删除更高效，因为只需要一次内存移动
     *   返回的向量包含被删除的元素，可用于撤销操作
     *}
    function Drain(aStart, aCount: SizeUInt): specialize IVec<T>;

    {**
     * SplitOff
     *
     * @desc 从指定位置分割向量，返回分离出的后半部分
     *
     * @param aIndex 分割位置（包含该位置的元素将移入新向量）
     * @return 包含从 aIndex 到末尾所有元素的新向量
     *
     * @remark
     *   类似 Rust 的 Vec::split_off
     *   原向量保留 [0, aIndex) 范围的元素
     *   新向量包含 [aIndex, Count) 范围的元素
     *   如果 aIndex > Count 会抛出 EOutOfRange 异常
     *}
    function SplitOff(aIndex: SizeUInt): specialize IVec<T>;

    {**
     * Splice
     *
     * @desc 在指定位置移除指定数量的元素，并用新元素替换
     *
     * @param aIndex 开始位置
     * @param aRemoveCount 要移除的元素数量
     * @param aInsert 要插入的新元素数组
     *
     * @remark
     *   类似 Rust 的 Vec::splice 和 JavaScript 的 Array.splice
     *   如果 aRemoveCount = 0，相当于纯插入
     *   如果 aInsert 为空，相当于纯删除
     *   如果两者都非空，则先删除后插入
     *}
    procedure Splice(aIndex, aRemoveCount: SizeUInt; const aInsert: array of T);

    {**
     * Dedup
     *
     * @desc 移除相邻重复元素
     *
     * @return 被移除的元素数量
     *
     * @remark
     *   类似 Rust 的 Vec::dedup
     *   只移除相邻的重复元素，如果想移除所有重复需要先排序
     *   使用默认的内存比较来判断元素是否相等
     *}
    function Dedup: SizeUInt;

    {**
     * DedupBy
     *
     * @desc 使用自定义比较器移除相邻重复元素
     *
     * @param aEquals 比较函数，返回 True 表示两个元素相等
     * @param aData 传递给比较函数的额外数据指针
     * @return 被移除的元素数量
     *
     * @remark
     *   类似 Rust 的 Vec::dedup_by
     *   只移除相邻的重复元素，保留第一个出现的元素
     *}
    function DedupBy(aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;

    // ToArray and Clone are inherited (IGenericCollection<T> / ICollection).
    {**
     * First
     *
     * @desc 获取第一个元素
     *
     * @return 第一个元素的值
     *
     * @remark
     *   如果向量为空会抛出异常
     *   这是一个便利方法，等价于 Get(0)
     *}
    function First: T;

    {**
     * Last
     *
     * @desc 获取最后一个元素
     *
     * @return 最后一个元素的值
     *
     * @remark
     *   如果向量为空会抛出异常
     *   这是一个便利方法，等价于 Get(Count-1)
     *}
    function Last: T;

    property Capacity:     SizeUInt        read GetCapacity     write SetCapacity;
    property GrowStrategy: IGrowthStrategy read GetGrowStrategy write SetGrowStrategy;
  end;

implementation

end.
