unit nextpas.core.collections.intf;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.slice;

type
  ICollection = nextpas.core.collections.base.ICollection;
  IGrowthStrategy = nextpas.core.collections.base.IGrowthStrategy;

  { IArray 数组接口 }
  generic IArray<T> = interface(specialize IGenericCollection<T>)
  ['{8ECBF26E-5B78-439A-BDB9-716BEF587828}']

    {**
     * Get
     *
     * @desc 获取指定索引处的元素 (安全版本).
     *
     * @params
     *   aIndex 要获取的元素的索引 (0-based)
     *
     * @return 位于指定索引的元素.
     *
     * @remark
     *   此方法进行索引越界检查.
     *   为追求极致性能, 可使用 `GetUnChecked` 或通过 `GetMemory` 直接访问指针.
     *   示例: `LValue := LArray.GetMemory[aIndex];`
     *
     * @exceptions
     *   EOutOfRange 索引超出范围.
     *}
    function Get(aIndex: SizeUInt): T;

    {**
     * GetUnChecked
     *
     * @desc 获取指定索引处的元素 (不安全快速版本)
     *
     * @params
     *   aIndex 要获取的元素的索引 (0-based).
     *
     * @return 位于指定索引的元素.
     *
     * @remark
     *   **警告: 仅用于性能极其关键的路径.**
     *   此方法不执行任何边界检查. 调用者必须自行确保 `aIndex` 在有效范围内.
     *   传递无效索引将导致未定义行为 (如访问冲突、数据损坏).
     *}
    function GetUnChecked(aIndex: SizeUInt): T;

    {**
     * Put
     *
     * @desc 设置指定索引处的元素 (安全版本).
     *
     * @params
     *   aIndex   要设置的元素的索引 (0-based).
     *   aElement 要设置的新元素值.
     *
     * @remark
     *   此方法进行索引越界检查.
     *   对于托管类型, 此过程会正确处理旧元素的释放和新元素的引用计数.
     *   为追求极致性能, 可使用 `PutUnChecked` 或通过 `GetMemory` 直接访问指针.
     *   示例: `LArray.GetMemory[aIndex] := aElement;`
     *
     * @exceptions
     *   EOutOfRange 索引超出范围.
     *}
    procedure Put(aIndex: SizeUInt; const aElement: T);

    {**
     * PutUnChecked
     *
     * @desc 设置指定索引处的元素(不安全快速版本)
     *
     * @params
     *   aIndex   要设置的元素的索引 (0-based).
     *   aElement 要设置的新元素值.
     *
     * @remark
     *   **警告: 仅用于性能极其关键的路径.**
     *   此方法不执行任何边界检查. 调用者必须自行确保 `aIndex` 在有效范围内.
     *   传递无效索引将导致未定义行为.
     *}
    procedure PutUnChecked(aIndex: SizeUInt; const aElement: T);

    {**
     * GetMemory
     *
     * @desc 获取指向容器内部存储区头部的直接指针.
     *
     * @return 指向第一个元素的指针。若容器为空，返回 nil。请勿依赖其长期有效性。
     *
     * @remark
     *   **警告: 返回的指针是易变的, 绝不能长期持有.**
     *   任何可能导致内存重分配的操作 (如 `Resize`, `Add`, `Insert`)都会使此指针失效.
     *   仅用于在小范围内进行高性能的连续操作.
     *}
    function GetMemory: specialize TElementRef<T>.PElement;

    {**
     * GetPtr
     *
     * @desc 获取指向指定索引处元素的指针 (安全版本).
     *
     * @params
     *   aIndex 目标元素的索引 (0-based).
     *
     * @return 指向指定元素的指针.
     *
     * @remark
     *   **警告: 返回的指针是易变的, 绝不能长期持有.** (原因同 `GetMemory`).
     *   此方法进行严格的边界检查.
     *
     * @exceptions
     *   EOutOfRange 索引超出范围.
     *}
    function GetPtr(aIndex: SizeUInt): specialize TElementRef<T>.PElement;

    {**
     * GetPtrUnChecked
     *
     * @desc 获取指向指定索引处元素的指针 (不安全快速版本)
     *
     * @params
     *   aIndex 目标元素的索引 (0-based).
     *
     * @return 指向指定元素的指针.
     *
     * @remark
     *   **警告: 返回的指针是易变的, 且此方法不进行边界检查.**
     *   调用者必须自行确保 `aIndex` 有效, 且不能长期持有返回的指针.
     *}
    function GetPtrUnChecked(aIndex: SizeUInt): specialize TElementRef<T>.PElement;

    {**
     * Resize
     *
     * @desc 调整容器大小, 使其恰好包含指定数量的元素.
     *
     * @params
     *   aNewSize 容器的新元素数量.
     *
     * @remark
     *   若 `aNewSize < GetCount`, 多余元素将被截断 (托管类型会被正确终结).
     *   若 `aNewSize > GetCount`, 新增元素将被零初始化 (托管类型会被正确初始化).
     *   若 `aNewSize = GetCount`, 不执行任何操作.
     *   若 `aNewSize = 0`, 容器将被清空.
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败.
     *}
    procedure Resize(aNewSize: SizeUInt);

    {**
     * Ensure
     *
     * @desc 确保容器内部容量至少能容纳指定数量的元素.
     *
     * @params
     *   aCount 需要确保的最小容量 (以元素数量计).
     *
     * @remark
     *   这是一个性能优化工具, 用于在大量添加元素前一次性分配足够内存,
     *   避免连续的、小规模的内存重分配.
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败.
     *}
    procedure Ensure(aCount: SizeUInt);

    {**
     * OverWrite
     *
     * @desc 在容器内指定位置覆写一段来自外部指针的元素.
     *
     * @params
     *   aIndex 容器内开始覆写的目标索引 (0-based).
     *   aSrc   指向源数据的外部内存指针.
     *   aCount 要复制的元素数量
     *
     * @remark
     *   此操作严格遵守“覆写”语义, 绝不会改变容器的 `Count`.
     *   对于托管类型, 会正确处理被覆写元素的生命周期.
     *   调用者必须确保目标范围 `aIndex` 到 `aCount` 在容器的有效范围内.
     *   当 `aCount` = 0 什么也不会发生
     *
     * @exceptions
     *   EArgumentNil  当 `aSrc` 为 `nil` 且 `aCount` > 0 时抛出.
     *   EOutOfRange   索引/范围越界.
     *}
    procedure OverWrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;

    {**
     * OverWriteUnChecked
     *
     * @desc 在容器内指定位置覆写一段来自外部指针的元素 (不安全快速版本).
     *
     * @params
     *   aIndex 容器内开始覆写的目标索引 (0-based).
     *   aSrc   指向源数据的外部内存指针.
     *   aCount 要复制的元素数量
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   传递无效索引将导致未定义行为.
     *}
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;

    {**
     * OverWrite
     *
     * @desc 在容器内指定位置覆写一个动态数组的全部内容.
     *
     * @params
     *   aIndex 容器内开始覆写的目标索引 (0-based).
     *   aSrc 包含源数据的动态数组.
     *
     * @remark
     *   此操作严格遵守“覆写”语义, 绝不会改变容器的 `Count`.
     *   覆写的元素数量由 `Length(aSrc)` 决定.
     *   如果 `aSrc` 为空, 此操作不产生任何效果.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    procedure OverWrite(aIndex: SizeUInt; const aSrc: array of T); overload;

    {**
     * OverWriteUnChecked
     *
     * @desc 在容器内指定位置覆写一个动态数组的全部内容 (不安全快速版本).
     *
     * @params
     *   aIndex 容器内开始覆写的目标索引 (0-based).
     *   aSrc 包含源数据的动态数组.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   传递无效索引将导致未定义行为.
     *}
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: array of T); overload;

    {**
     * OverWrite
     *
     * @desc 在容器内指定位置覆写另一个容器的全部内容.
     *
     * @params
     *   aIndex 容器内开始覆写的目标索引 (0-based).
     *   aSrc   提供源数据的容器.
     *
     * @remark
     *   此操作严格遵守“覆写”语义, 绝不会改变容器的 `Count`.
     *   覆写的元素数量由 `aSrc.GetCount` 决定.
     *   如果 `aSrc` 为空, 此操作不产生任何效果.
     *   aSrc 应为兼容的容器, 否则会抛出 `ENotCompatible` 异常.
     *
     * @exceptions
     *   EArgumentNil    源容器为 `nil`.
     *   ENotCompatible  源容器与目标容器不兼容.
     *   EOutOfRange     索引/范围越界.
     *}
    procedure OverWrite(aIndex:SizeUInt; const aSrc: TCollection); overload;

    {**
     * OverWrite
     *
     * @desc 在容器内指定位置覆写另一个集合的部分内容.
     *
     * @params
     *   aIndex  容器内开始覆写的目标索引 (0-based).
     *   aSrc    提供源数据的容器.
     *   aCount  要从 `aSrc` 复制并覆写的元素数量.
     *
     * @remark
     *   此操作严格遵守“覆写”语义, 绝不会改变容器的 `Count`.
     *
     * @exceptions
     *   EArgumentNil    源容器为 nil.
     *   ENotCompatible  源容器与目标容器不兼容.
     *   EOutOfRange     索引/范围越界.
     *
     * @params
     *   aIndex  容器内开始覆写的目标索引 (0-based).
     *   aSrc    提供源数据的容器.
     *   aCount  要从 `aSrc` 复制并覆写的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   传递无效索引将导致未定义行为.
     *}
    procedure OverWriteUnChecked(aIndex:SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;

    {**
     * Read
     *
     * @desc 将容器内指定范围的元素复制到外部内存.
     *
     * @params
     *   aIndex  容器内开始读取的源索引 (0-based).
     *   aDst    用于接收数据的外部内存指针.
     *   aCount  要复制的元素数量.
     *
     * @remark
     *   **警告: 调用者必须确保 `aDst` 指向的内存区域已分配且足够大,**
     *   以容纳 `aCount` 个元素, 否则将导致缓冲区溢出.
     *
     * @exceptions
     *   EArgumentNil  `aDst` 为 `nil`.
     *   EOutOfRange   索引/范围越界.
     *}
    procedure Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);

    {**
     * ReadUnChecked
     *
     * @desc 将容器内指定范围的元素复制到外部内存 (无检查版本).
     *
     * @params
     *   aIndex  容器内开始读取的源索引 (0-based).
     *   aDst    用于接收数据的外部内存指针.
     *   aCount  要复制的元素数量.

     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   传递无效索引将导致未定义行为.
     *}
    procedure ReadUnChecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload;


    { 非异常批量导入/追加（集合重载） - 接口便捷方法，转发至基类实现 }
    function TryLoadFrom(const aSrc: TCollection): Boolean; overload;
    function TryAppend(const aSrc: TCollection): Boolean; overload;

    { 非异常批量导入/追加（指针重载）见 TCollection.TryLoadFrom/TryAppend 指针重载 }

    {**
     * Read
     *
     * @desc 将容器内指定范围的元素读取到一个动态数组中.
     *
     * @params
     *   aIndex  容器内开始读取的源索引 (0-based).
     *   aDst    (var) 用于接收数据的动态数组.
     *   aCount  要读取的元素数量.
     *
     * @remark
     *   `aDst` 数组将被自动调整大小以容纳读取的数据.
     *
     * @exceptions
     *   EArgumentNil  `aDst` 为 `nil`.
     *   EOutOfRange   索引/范围越界.
     *}
    procedure Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload;

    {**
     * ReadUnChecked
     *
     * @desc 将容器内指定范围的元素读取到一个动态数组中 (无检查版本).
     *
     * @params
     *   aIndex  容器内开始读取的源索引 (0-based).
     *   aDst    (var) 用于接收数据的动态数组.
     *   aCount  要读取的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   传递无效索引将导致未定义行为.
     *}
    procedure ReadUnChecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload;

    {**
     * Swap
     *
     * @desc 交换两个指定索引处的元素
     *
     * @params
     *   aIndex1 第一个元素的索引 (0-based).
     *   aIndex2 第二个元素的索引 (0-based).
     *
     * @remark
     *   为追求极致性能, 可使用 `SwapUnChecked` 版本.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *   EInvalidArgument  索引相同.
     *}
    procedure Swap(aIndex1, aIndex2: SizeUInt); overload;

    {**
     * SwapUnChecked
     *
     * @desc 交换两个指定索引处的元素(无检查版本)
     *
     * @params
     *   aIndex1 第一个元素的索引 (0-based).
     *   aIndex2 第二个元素的索引 (0-based).
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须自行确保索引有效且不相等.
     *   传递无效参数将导致未定义行为.
     *}
    procedure SwapUnChecked(aIndex1, aIndex2: SizeUInt);

    {**
     * Swap
     *
     * @desc 交换两个不重叠的、等长的元素范围
     *
     * @params
     *   aIndex1  第一个元素的索引 (0-based).
     *   aIndex2  第二个元素的索引 (0-based).
     *   aCount   每个范围的元素数量.
     *
     * @exceptions
     *   EInvalidArgument  元素数量为 0.
     *   EInvalidArgument  索引相同.
     *   EOutOfRange       索引/范围越界.
     *   EOutOfMemory      分配内存失败.
     *}
    procedure Swap(aIndex1, aIndex2, aCount: SizeUInt); overload;

    {**
     * Swap
     *
     * @desc 交换两个不重叠的、等长的元素范围
     *
     * @params
     *   aIndex1          第一个元素的索引 (0-based).
     *   aIndex2          第二个元素的索引 (0-based).
     *   aCount           每个范围的元素数量.
     *   aSwapBufferSize  内部交换操作使用的临时缓冲区大小 (字节).
     *
     * @remark
     *   提供更大的 `aSwapBufferSize` 通常可以提升性能, 但会增加内存消耗.
     *
     * @exceptions
     *   EInvalidArgument  元素数量为 0.
     *   EInvalidArgument  索引相同.
     *   EOutOfRange       索引/范围越界.
     *   EOutOfMemory      分配内存失败.
     *}
    procedure Swap(aIndex1, aIndex2, aCount, aSwapBufferSize: SizeUInt); overload;

    {**
     * Copy
     *
     * @desc 在容器内部复制元素, 安全处理重叠区域.
     *
     * @params
     *   aSrcIndex  源范围的起始索引.
     *   aDstIndex  目标范围的起始索引.
     *   aCount     要复制的元素数量..
     *
     * @remark
     *   此函数的行为类似于 C 语言的 `memmove`, 能正确处理源和目标范围重叠的情况.
     *   对于托管类型, 会正确处理相关的引用计数.
     *
     * @exceptions
     *   EInvalidArgument  源索引和目标索引相同.
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);

    {**
     * CopyUnChecked
     *
     * @desc 在容器内部复制元素(无检查版本)
     *
     * @params
     *   aSrcIndex  源范围的起始索引.
     *   aDstIndex  目标范围的起始索引.
     *   aCount     要复制的元素数量..
     *
     * @remark
     *   此函数的行为类似于 C 语言的 `memmove`, 能正确处理源和目标范围重叠的情况.
     *   传递无效参数将导致未定义行为.
     *}
    procedure CopyUnChecked(aSrcIndex, aDstIndex, aCount: SizeUInt);



    { 容器算法 }


    {**
     * Fill
     *
     * @desc
     *   使用指定值填充容器内的指定范围.
     *
     * @params
     *   aIndex    填充操作的起始索引 (0-based).
     *   aElement  用于填充的元素值.
     *
     * @remark
     *   此操作会覆写范围内的现有元素.
     *   对于托管类型, 会正确处理被覆写元素的释放和新元素的引用计数.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Fill(aIndex: SizeUInt; const aElement: T); overload;

    {**
     * Fill
     *
     * @desc 使用指定值填充容器内的指定范围.
     *
     * @params
     *   aIndex    填充操作的起始索引 (0-based).
     *   aCount    要填充的元素数量..
     *   aElement  用于填充的元素值..
     *
     * @remark
     *   此操作会覆写范围内的现有元素.
     *   对于托管类型, 会正确处理被覆写元素的释放和新元素的引用计数.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Fill(aIndex, aCount: SizeUInt; const aElement: T); overload;

    {**
     * FillUnChecked
     *
     * @desc 用指定元素填充容器的指定范围 (无检查版本).
     *
     * @params
     *   aIndex   填充的起始索引 (0-based).
     *   aCount   要填充的元素数量.
     *   aElement 用于填充的元素值.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   此操作会覆盖指定范围内的所有现有元素.
     *}
    procedure FillUnChecked(aIndex, aCount: SizeUInt; const aElement: T);


    {**
     * Zero
     *
     * @desc 将容器内指定范围的元素写零.
     *
     * @params
     *   aIndex 写零操作的起始索引 (0-based).
     *
     * @remark
     *   对托管类型意味着释放 (设为 `nil`), 对值类型意味着内存按位清零.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Zero(aIndex: SizeUInt); overload;

    {**
     * Zero
     *
     * @desc 将容器内指定范围的元素写零.
     *
     * @params
     *   aIndex  写零操作的起始索引 (0-based).
     *   aCount  元素数量
     *
     * @remark
     *   对托管类型意味着释放 (设为 `nil`), 对值类型意味着内存按位清零.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Zero(aIndex, aCount: SizeUInt); overload;

    {**
     * ZeroUnChecked
     *
     * @desc 将容器内指定范围的元素写零 (无检查版本).
     *
     * @params
     *   aIndex  写零操作的起始索引 (0-based).
     *   aCount  元素数量
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    procedure ZeroUnChecked(aIndex, aCount: SizeUInt); overload;


    { Reverse 反转 }

    {**
     * Reverse
     *
     * @desc 从指定索引位置开始反转容器中的元素
     *
     * @params
     *   aStartIndex 反转操作的起始索引..
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    procedure Reverse(aStartIndex: SizeUInt); overload;

    {**
     * Reverse
     *
     * @desc 反转容器内指定范围的元素.
     *
     * @params
     *   aStartIndex 反转操作的起始索引..
     *   aCount      要反转的元素数量..
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    procedure Reverse(aStartIndex, aCount: SizeUInt); overload;

    {**
     * ReverseUnChecked
     *
     * @desc 反转容器中指定范围内的元素顺序 (无检查版本).
     *
     * @params
     *   aStartIndex 反转范围的起始索引 (0-based).
     *   aCount      要反转的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    procedure ReverseUnChecked(aStartIndex, aCount: SizeUInt);

    { ForEach 遍历 }

    {**
     * ForEach
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (过程指针版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aPredicate   要对每个元素执行的回调过程.
     *   aData        传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调函数 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * ForEach
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (对象方法版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aPredicate   要对每个元素执行的回调过程.
     *   aData        传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调函数 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ForEach
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (匿名方法版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aPredicate   要对每个元素执行的匿名方法.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   匿名方法 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * ForEach
     *
     * @desc 在指定范围内, 对容器的每个元素执行一个回调 (过程指针版本).
     *
     * @params
     *   aStartIndex 遍历的起始索引 (0-based).
     *   aCount      要遍历的元素数量.
     *   aPredicate    要对每个元素执行的回调过程.
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   如果 `aCount` 为 0, 此函数不执行任何操作并立即返回 `True`.
     *   回调过程 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * ForEach
     *
     * @desc 在指定范围内, 对容器的每个元素执行一个回调 (对象方法版本).
     *
     * @params
     *   aStartIndex 遍历的起始索引 (0-based).
     *   aCount      要遍历的元素数量.
     *   aPredicate    要对每个元素执行的回调过程.
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   如果 `aCount` 为 0, 此函数不执行任何操作并立即返回 `True`.
     *   回调过程 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ForEach
     *
     * @desc 在指定范围内, 对容器的每个元素执行一个回调 (匿名方法版本).
     *
     * @params
     *   aStartIndex 遍历的起始索引 (0-based).
     *   aCount      要遍历的元素数量.
     *   aPredicate    要对每个元素执行的匿名方法.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   如果 `aCount` 为 0, 此函数不执行任何操作并立即返回 `True`.
     *   匿名方法 `aPredicate` 返回 `False` 将立即中断遍历过程.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * ForEachUnChecked
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (过程指针版本, 无检查版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aCount       要遍历的元素数量.
     *   aPredicate   要对每个元素执行的回调过程.
     *   aData        传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * ForEachUnChecked
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (对象方法版本, 无检查版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aCount       要遍历的元素数量.
     *   aPredicate   要对每个元素执行的回调过程.
     *   aData        传递给回调过程的用户自定义数据.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ForEachUnChecked
     *
     * @desc 从指定索引开始, 对容器的每个后续元素执行一个回调 (匿名方法版本, 无检查版本).
     *
     * @params
     *   aStartIndex  遍历的起始索引 (0-based).
     *   aCount       要遍历的元素数量.
     *   aPredicate   要对每个元素执行的回调过程.
     *
     * @return 若遍历完成 (回调从未返回 `False`), 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   此重载版本需要在 fpc 3.3.1 及以上并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    { Contains 包含 }

    {**
     * Contains
     *
     * @desc 检查元素是否存在, 从指定索引搜索到末尾 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex: SizeUInt): Boolean; overload;

    {**
     * Contains
     *
     * @desc 检查元素是否存在, 从指定索引搜索到末尾 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * Contains
     *
     * @desc 检查元素是否存在, 从指定索引搜索到末尾 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Contains
     *
     * @desc 检查元素是否存在, 从指定索引搜索到末尾 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * Contains
     *
     * @desc 在指定范围内检查元素是否存在 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean; overload;

    {**
     * Contains
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * Contains
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Contains
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    function Contains(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * ContainsUnChecked
     *
     * @desc 在指定范围内检查元素是否存在 (使用默认比较器, 跳过边界检查).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器.
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean; overload;

    {**
     * ContainsUnChecked
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器, 跳过边界检查).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * ContainsUnChecked
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器, 跳过边界检查).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ContainsUnChecked
     *
     * @desc 在指定范围内检查元素是否存在 (使用自定义比较器, 跳过边界检查).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到元素, 返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   此重载版本需要在 fpc 3.3.1 及以上并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * FindIFUnChecked
     *
     * @desc 在指定范围内查找满足条件的元素 (跳过边界检查).
     *
     * @params
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到满足条件的元素, 返回其索引; 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * FindIFNotUnChecked
     *
     * @desc 在指定范围内查找不满足条件的元素 (跳过边界检查).
     *
     * @params
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到不满足条件的元素, 返回其索引; 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * FindLastUnChecked
     *
     * @desc 在指定范围内从后向前查找元素 (跳过边界检查).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到元素, 返回其索引; 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * FindLastIFUnChecked
     *
     * @desc 在指定范围内从后向前查找满足条件的元素 (跳过边界检查).
     *
     * @params
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到满足条件的元素, 返回其索引; 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * FindLastIFNotUnChecked
     *
     * @desc 在指定范围内从后向前查找不满足条件的元素 (跳过边界检查).
     *
     * @params
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到不满足条件的元素, 返回其索引; 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * CountOfUnChecked
     *
     * @desc 在指定范围内计算指定元素的数量 (跳过边界检查).
     *
     * @params
     *   aElement    要计算的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 找到的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * CountIfUnChecked
     *
     * @desc 在指定范围内计算满足条件的元素数量 (跳过边界检查).
     *
     * @params
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 满足条件的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * ReplaceUnChecked
     *
     * @desc 在指定范围内替换元素 (跳过边界检查).
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 新元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 替换的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * ReplaceIFUnChecked
     *
     * @desc 在指定范围内替换满足条件的元素 (跳过边界检查).
     *
     * @params
     *   aNewElement 新元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 替换的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * IsSortedUnChecked
     *
     * @desc 检查指定范围内的元素是否已排序 (跳过边界检查).
     *
     * @params
     *   aStartIndex 检查范围的起始索引 (0-based).
     *   aCount      要检查的元素数量.
     *   aComparer   用于比较元素的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果已排序返回 True, 否则返回 False.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * BinarySearchUnChecked
     *
     * @desc 在已排序的指定范围内进行二分查找 (跳过边界检查).
     *
     * @params
     *   aElement    要查找的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较元素的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 如果找到返回元素索引, 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保范围内的元素已排序.
     *}
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * BinarySearchInsertUnChecked
     *
     * @desc 在已排序的指定范围内查找插入位置 (跳过边界检查).
     *
     * @params
     *   aElement    要插入的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较元素的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @return 返回应该插入的位置索引.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保范围内的元素已排序.
     *}
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * ShuffleUnChecked
     *
     * @desc 随机打乱指定范围内的元素 (跳过边界检查).
     *
     * @params
     *   aStartIndex 打乱范围的起始索引 (0-based).
     *   aCount      要打乱的元素数量.
     *   aRandom     用于生成随机数的自定义回调.
     *   aData       传递给回调的用户自定义数据.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *}
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt); overload;
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    { find 查找 }

    {**
     * Find
     *
     * @desc  从头开始搜索指定元素, 并返回其首次出现的索引 (使用默认比较器).
     *
     * @params
     *   aElement 要搜索的元素.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *}
    function Find(const aElement: T): SizeInt; overload;

    {**
     * Find
     *
     * @desc 从头开始搜索指定元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement  要搜索的元素.
     *   aEquals 用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData   传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *}
    function Find(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * Find
     *
     * @desc 从头开始搜索指定元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *}
    function Find(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Find
     *
     * @desc 从头开始搜索指定元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function Find(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * Find
     *
     * @desc 从指定索引开始搜索元素, 并返回其首次出现的索引 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    function Find(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload;

    {**
     * Find
     *
     * @desc 从指定索引开始搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.
     *                索引超出范围.
     *}
    function Find(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * Find
     *
     * @desc 从指定索引开始搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    function Find(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Find
     *
     * @desc 从指定索引开始搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    function Find(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * Find
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EInvalidArgument  Count cannot be zero.
     *                元素数量为 0.
     *
     *   EOutOfRange  Index out of range.
     *                索引超出范围.
     *
     *   EOutOfRange  Range out of bounds.
     *
     *                范围超出容器大小.
     *}
    function Find(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;

    {**
     * Find
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   If the container is empty, this function does not perform a search and returns immediately.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EInvalidArgument  Count cannot be zero.

     *                元素数量为 0.
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *   EOutOfRange  Range out of bounds.

     *                范围超出容器大小.
     *}
    function Find(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * Find
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   If the container is empty, this function does not perform a search and returns immediately.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *
     * @exceptions
     *   EInvalidArgument  Count cannot be zero.

     *                元素数量为 0.
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *   EOutOfRange  Range out of bounds.

     *                范围超出容器大小.
     *}
    function Find(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Find
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   If the container is empty, this function does not perform a search and returns immediately.

     *   如果容器为空, 此函数不执行搜索并立即返回 -1.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EInvalidArgument  元素数量为 0.
     *   EOutOfRange       索引/范围越界.
     *}
    function Find(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * FindUnChecked
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (无检查版本).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   此接口内部会根据元素类型自动选择合适的默认比较器.
     *}
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;

    {**
     * FindUnChecked
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *}
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * FindUnChecked
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *}
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * FindUnChecked
     *
     * @desc 在指定范围内搜索元素, 并返回其首次出现的索引 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aEquals     用于判断元素是否相等的自定义回调 (匿名方法版本).
     *
     * @return 如果找到, 返回元素的索引 (0-based); 否则返回 -1.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aEquals` 应在两元素相等时返回 `True`.
     *   此重载版本需要在 fpc 3.3.1 及以上并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { FindIf 查找 }

    function FindIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIF(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { FindIfNot 查找不满足条件的元素 }

    function FindIFNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { FindLast 查找最后一个元素 }

    function FindLast(const aElement: T): SizeInt; overload;
    function FindLast(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLast(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { FindLastIf 查找最后一个满足条件的元素 }

    function FindLastIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIF(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { FindLastIFNot 查找最后一个不满足条件的元素 }

    function FindLastIFNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    { CountOf 计算数量 }

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *}
    function CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountOf
     *
     * @desc 计算容器中指定元素的数量.
     *
     * @params
     *   aElement    要计算数量的元素.
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    { CountIf 计算满足条件的元素数量 }

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (过程指针版本).
     *}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量.
     *
     * @params
     *   aStartIndex 要开始计算的索引位置 (0-based).
     *   aCount      要计算的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    { Replace 替换 }

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt); overload;

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aEquals     用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aEquals     用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aEquals     用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt); overload;

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aEquals     用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;

    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aEquals     用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Replace
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aElement    要替换的元素.
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aEquals     用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}

    { ReplaceIF 替换满足条件的元素 }

    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;

    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aPredicate  用于判断元素是否满足条件的回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}

    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;

    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ReplaceIF
     *
     * @desc 替换容器中的元素.
     *
     * @params
     *   aNewElement 要替换的新元素.
     *   aStartIndex 要替换的索引位置 (0-based).
     *   aCount      要替换的元素数量.
     *   aPredicate  用于判断元素是否满足条件的回调 (匿名方法版本).
     *
     * @remark
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}

    { IsSorted 判断是否有序 }

    function IsSorted: Boolean; overload;
    function IsSorted(aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function IsSorted(aStartIndex: SizeUInt): Boolean; overload;
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function IsSorted(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}


    { sort 排序 }

    {**
     * Sort
     *
     * @desc 对容器中的所有元素进行排序 (使用默认比较器).
     *
     * @remark
     *   排序算法为内省排序 (Introsort), 结合了快速排序、堆排序和插入排序的优点.
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *}
    procedure Sort; overload;

    {**
     * Sort
     *
     * @desc 对容器中的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aComparer 用于比较两个元素的自定义回调 (过程指针版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    procedure Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;

    {**
     * Sort
     *
     * @desc 对容器中的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aComparer 用于比较两个元素的自定义回调 (对象方法版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    procedure Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Sort
     *
     * @desc 对容器中的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aComparer 用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure Sort(aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    {**
     * Sort
     *
     * @desc 对从指定索引到末尾的所有元素进行排序 (使用默认比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    procedure Sort(aStartIndex: SizeUInt); overload;

    {**
     * Sort
     *
     * @desc 对从指定索引到末尾的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;

    {**
     * Sort
     *
     * @desc 对从指定索引到末尾的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Sort
     *
     * @desc 对从指定索引到末尾的所有元素进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    {**
     * Sort
     *
     * @desc 对容器内的指定范围进行排序 (使用默认比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EInvalidArgument  Count cannot be zero.
     *                     元素数量为 0.
     *
     *   EOutOfRange       Index out of range.
     *                     索引超出范围.
     *
     *   EOutOfRange       Range out of bounds.
     *                     范围超出容器大小.
     *}
    procedure Sort(aStartIndex, aCount: SizeUInt); overload;

    {**
     * Sort
     *
     * @desc 对容器内的指定范围进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EInvalidArgument  Count cannot be zero.

     *                元素数量为 0.
     *   EOutOfRange  Index out of range.

     *                索引超出范围.
     *   EOutOfRange  Range out of bounds.

     *                范围超出容器大小.
     *}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;

    {**
     * Sort
     *
     * @desc 对容器内的指定范围进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Sort
     *
     * @desc 对容器内的指定范围进行排序 (使用自定义比较器).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange       索引/范围越界.
     *}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    { SortUnChecked 无检查排序 - 跳过边界检查，追求极致性能 }

    {**
     * SortUnChecked
     *
     * @desc 对指定范围内的元素进行排序 (使用默认比较器, 无检查版本).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   此接口内部会根据元素类型自动选择合适的默认比较器.
     *   排序算法为稳定的快速排序, 平均时间复杂度为 O(n log n).
     *}
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt); overload;

    {**
     * SortUnChecked
     *
     * @desc 对指定范围内的元素进行排序 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aComparer` 应在第一个元素小于第二个元素时返回负值, 相等时返回 0, 大于时返回正值.
     *   排序算法为稳定的快速排序, 平均时间复杂度为 O(n log n).
     *}
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;

    {**
     * SortUnChecked
     *
     * @desc 对指定范围内的元素进行排序 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aComparer` 应在第一个元素小于第二个元素时返回负值, 相等时返回 0, 大于时返回正值.
     *   排序算法为稳定的快速排序, 平均时间复杂度为 O(n log n).
     *}
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * SortUnChecked
     *
     * @desc 对指定范围内的元素进行排序 (使用自定义比较器, 无检查版本).
     *
     * @params
     *   aStartIndex 排序范围的起始索引 (0-based).
     *   aCount      要排序的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @remark
     *   **UnChecked 统一约定：** 不进行参数/边界/空指针检查；调用方需保证前置条件。
     *   详见 docs/UnChecked_Methods_Summary.md。
     *   调用者必须确保 aStartIndex 和 aCount 参数的有效性, 否则可能导致程序崩溃.
     *   回调 `aComparer` 应在第一个元素小于第二个元素时返回负值, 相等时返回 0, 大于时返回正值.
     *   排序算法为稳定的快速排序, 平均时间复杂度为 O(n log n).
     *   此重载版本需要在 fpc 3.3.1 及以上并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    { BinarySearch 二分查找 }

    {**
     * BinarySearch
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement 要搜索的元素.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.** 在未排序的容器上调用, 结果是未定义的.
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *}
    function BinarySearch(const aElement: T): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (过程指针版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.** 在未排序的容器上调用, 结果是未定义的.
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (对象方法版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.** 在未排序的容器上调用, 结果是未定义的.
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearch
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.** 在未排序的容器上调用, 结果是未定义的.
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearch
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素 (使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 搜索范围的起始索引 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return 如果找到匹配元素, 返回其索引. 如果未找到, 返回-1.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   此重载版本需要在fpc 3.3.1 及以上 并启用 `FAFAFA_CORE_ANONYMOUS_REFERENCES` 编译指令.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    { BinarySearchInsert 二分查找后端版本 }

    {**
     * BinarySearchInsert
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素, 并返回其位置或插入点.
     *
     * @params
     *   aElement 要搜索的元素.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.** 在未排序的容器上调用, 结果是未定义的.
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *}
    function BinarySearchInsert(const aElement: T): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素, 并返回其位置或插入点 (使用自定义比较器)..
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (过程指针版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素, 并返回其位置或插入点 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (对象方法版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearchInsert
     *
     * @desc 在整个(有序)序列中, 使用二分搜索算法查找元素, 并返回其位置或插入点 (使用自定义比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aComparer 用于比较两个元素的自定义回调 (匿名方法版本).
     *   aData     传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`.
     *
     * @remark
     *   **警告: 此函数要求整个容器必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   使用此接口需要在fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点(使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点(使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点(使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定后续范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点(使用默认比较器).
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求从 `aStartIndex` 到末尾的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   使用此接口需要在fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点.
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aCount      要搜索的元素数量.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求指定的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   对于复杂类型, 强烈建议使用提供自定义比较器的重载版本.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点.
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (过程指针版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求指定的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;

    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点.
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (对象方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求指定的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * BinarySearchInsert
     *
     * @desc 在(有序)序列的指定范围中, 使用二分搜索算法查找元素, 并返回其位置或插入点.
     *
     * @params
     *   aElement    要搜索的元素.
     *   aStartIndex 要开始查找的索引位置 (0-based).
     *   aCount      要搜索的元素数量.
     *   aComparer   用于比较两个元素的自定义回调 (匿名方法版本).
     *   aData       传递给回调过程的用户自定义数据.
     *
     * @return
     *   如果找到匹配元素, 返回其索引 (一个 `>= 0` 的值).
     *   如果未找到, 返回 `(-(插入点) - 1)`. 插入点是第一个大于 `aElement` 的元素的索引.
     *
     * @remark
     *   **警告: 此函数要求指定的范围必须是已排序的.**
     *   **返回值契约**:
     *     返回值 `>= 0` 表示找到了元素.
     *     返回值 `< 0` 表示未找到. 可以通过 `Abs(Result) - 1` 计算出正确的插入点.
     *
     *   回调函数中应该遵守比较返回值规则:
     *    * 小于0表示左值小于右值
     *    * 等于0表示左值等于右值
     *    * 大于0表示左值大于右值
     *
     *   使用此接口需要在fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    { Shuffle 打乱 }

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *}
    procedure Shuffle; overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aRandomGenerator 用于生成随机数的回调.
     *   aData            传递给回调过程的用户自定义数据.
     *}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aRandomGenerator 用于生成随机数的类方法回调.
     *   aData            传递给回调过程的用户自定义数据.
     *}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aRandomGenerator 用于生成随机数的匿名方法回调.
     *}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex 要开始打乱的索引位置 (0-based).
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    procedure Shuffle(aStartIndex: SizeUInt); overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aRandomGenerator 用于生成随机数的回调.
     *   aData            传递给回调过程的用户自定义数据.
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aRandomGenerator 用于生成随机数的类方法回调.
     *   aData            传递给回调过程的用户自定义数据.
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aRandomGenerator 用于生成随机数的匿名方法回调.
     *
     * @exceptions
     *   EOutOfRange  索引越界.
     *}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex 要开始打乱的索引位置 (0-based).
     *   aCount      要打乱的元素数量.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    procedure Shuffle(aStartIndex, aCount: SizeUInt); overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aCount           要打乱的元素数量.
     *   aRandomGenerator 用于生成随机数的回调.
     *   aData            传递给回调过程的用户自定义数据.
     *
     * @exceptions
     *   EOutOfRange  索引/范围越界.
     *}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;

    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aCount           要打乱的元素数量.
     *   aRandomGenerator 用于生成随机数的类方法回调.
     *   aData            传递给回调过程的用户自定义数据.
     *}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Shuffle
     *
     * @desc 随机打乱容器中的元素.
     *
     * @params
     *   aStartIndex      要开始打乱的索引位置 (0-based).
     *   aCount           要打乱的元素数量.
     *   aRandomGenerator 用于生成随机数的匿名方法回调.
     *}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}



    property Items[aIndex: SizeUInt]: T                                            read Get write Put; default;
    property Ptr[aIndex: SizeUInt]:   specialize TElementRef<T>.PElement read GetPtr;
    property Memory:                  specialize TElementRef<T>.PElement read GetMemory;
  end;


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
     * @return SizeUint 当前容量
     *
     * @complexity O(1)
     *}
    function GetCapacity: SizeUint;

    {**
     * SetCapacity
     *
     * @desc Sets the vector's capacity
     * @param aCapacity The capacity to set
     * @note Throws exception if operation fails
     *}
    procedure SetCapacity(aCapacity: SizeUint);

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
    function TryReserve(aAdditional: SizeUint): Boolean;

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
    procedure Reserve(aAdditional: SizeUint);

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
    function TryReserveExact(aAdditional: SizeUint): Boolean;
    procedure ReserveExact(aAdditional: SizeUint);

    {**
     * EnsureCapacity
     *
     * @desc 确保容量至少为指定值（仅扩容，不改变 Count）
     *}
    procedure EnsureCapacity(aCapacity: SizeUint);

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
    procedure ShrinkTo(aCapacity: SizeUint);

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
    procedure Truncate(aCount: SizeUint);

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
    procedure ResizeExact(aNewSize: SizeUint);



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
    procedure Insert(aIndex: SizeUint; const aSrc: Pointer; aCount: SizeUInt); overload;

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
    procedure Write(aIndex:SizeUInt; const aSrc: array of T); overload;

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
    procedure Write(aIndex:SizeUInt; const aSrc: TCollection); overload;

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
    procedure Write(aIndex:SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;

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
    procedure WriteExact(aIndex: SizeUint; const aSrc: Pointer; aCount: SizeUInt);

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
    procedure WriteExact(aIndex: SizeUint; const aSrc: array of T);

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
    procedure WriteExact(aIndex: SizeUint; const aSrc: TCollection); overload;

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
    procedure WriteExact(aIndex: SizeUint; const aSrc: TCollection; aCount: SizeUInt);



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
    function TryPeekCopy(aDst: Pointer; aCount: SizeUint): Boolean; overload;

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

    property Capacity:     SizeUint        read GetCapacity     write SetCapacity;
    property GrowStrategy: IGrowthStrategy read GetGrowStrategy write SetGrowStrategy;
  end;




  {**
   * IQueue<T>
   *
   * @desc 泛型队列接口 - FIFO (先进先出) 语义
   * @param T 元素类型
   * @note
   *   - Push: 入队 O(1)
   *   - Pop: 出队 O(1)
   *   - Peek: 查看队首 O(1)
   *   - 不继承 IGenericCollection，保持最小接口
   *}
  generic IQueue<T> = interface
  ['{8D2A4A2F-3C7C-4E94-A763-6E2E7D6C5D37}']
    { 入队（同名重载） }
    procedure Push(const aElement: T); overload;              // 失败抛异常（如有容量上限）
    procedure Push(const aSrc: array of T); overload;         // 全部入队，遇满抛异常
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload; // 指针批量

    { 出队（Try 语义与异常语义） }
    function  Pop(out aElement: T): Boolean; overload;        // 空返回 False
    function  Pop: T; overload;                               // 空抛异常

    { 预览（不移除）— 若实现不支持可返回 False/抛异常 }
    function  TryPeek(out aElement: T): Boolean; overload;    // 空或不支持返回 False
    function  Peek: T; overload;                              // 空或不支持抛异常

    { 状态与维护（最佳努力） }
    function  IsEmpty: Boolean;                               // 并发下允许竞态
    procedure Clear;                                          // 最佳努力清空
    function  Count: SizeUInt;                                // 精确或最佳努力计数（不支持可返回 0）
  end;

  {**
   * IDeque<T>
   *
   * @desc 双端队列接口 - 支持两端插入/删除
   * @param T 元素类型
   * @note
   *   - 继承 IQueue<T>
   *   - PushFront/PushBack: O(1)
   *   - PopFront/PopBack: O(1)
   *   - 随机访问 Get(i): O(1)
   *   - 内部插入/删除: O(n)
   *}
  generic IDeque<T> = interface(specialize IQueue<T>)
  ['{F1A2B3C4-D5E6-4F78-9A0B-1C2D3E4F5A6B}']
    // Front/Back 访问
    function Front: T; overload;
    function Front(var aElement: T): Boolean; overload;
    function Back: T; overload;
    function Back(var aElement: T): Boolean; overload;

    // 双端 Push/Pop
    procedure PushFront(const aElement: T); overload;
    procedure PushFront(const aElements: array of T); overload;
    procedure PushFront(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure PushBack(const aElement: T); overload;
    procedure PushBack(const aElements: array of T); overload;
    procedure PushBack(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    function PopFront: T; overload;
    function PopFront(var aElement: T): Boolean; overload;
    function PopBack: T; overload;
    function PopBack(var aElement: T): Boolean; overload;

    // 随机访问与修改
    procedure Swap(aIndex1, aIndex2: SizeUInt);
    function Get(aIndex: SizeUInt): T;
    function TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
    procedure Insert(aIndex: SizeUInt; const aElement: T);
    function Remove(aIndex: SizeUInt): T;
    function TryRemove(aIndex: SizeUInt; var aElement: T): Boolean;

    // 容量与尺寸管理
    procedure Reserve(aAdditional: SizeUInt);
    procedure ReserveExact(aAdditional: SizeUInt);
    procedure ShrinkToFit;
    procedure ShrinkTo(aMinCapacity: SizeUInt);
    procedure Truncate(aLen: SizeUInt);
    procedure Resize(aNewSize: SizeUInt; const aValue: T);

    // 批量与结构操作
    procedure Append(const aOther: specialize IQueue<T>);
    function SplitOff(aAt: SizeUInt): specialize IQueue<T>;
  end;


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
