unit nextpas.core.collections.arr.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type
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
    procedure OverWrite(aIndex: SizeUInt; const aSrc: TCollection); overload;

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
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;

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

implementation

end.
