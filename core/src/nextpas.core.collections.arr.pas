unit nextpas.core.collections.arr;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base;

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
    function GetMemory: specialize TGenericCollection<T>.PElement;

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
    function GetPtr(aIndex: SizeUInt): specialize TGenericCollection<T>.PElement;

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
    function GetPtrUnChecked(aIndex: SizeUInt): specialize TGenericCollection<T>.PElement;

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
    property Ptr[aIndex: SizeUInt]:   specialize TGenericCollection<T>.PElement read GetPtr;
    property Memory:                  specialize TGenericCollection<T>.PElement read GetMemory;
  end;

  { TArray 数组实现类 }
  generic TArray<T> = class(specialize TGenericCollection<T>, specialize IArray<T>)
  const
    ARRAY_DEFAULT_SWAP_BUFFER_SIZE = 4096; // 默认交换缓冲区最大用量(字节)
    INSERTION_SORT_THRESHOLD = 16;         // 插入排序阈值
  type
    TSwapMethod  = procedure(const aIndex1, aIndex2: SizeUInt) of object;
  private
    FMemory: Pointer;
    FCount:  SizeUInt;

  { ITerator 迭代器回调 }
{ 参见迭代器最佳实践：docs/Iterator_BestPractices.md }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  DoIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

  { 交换相关 }
  protected
    FSwapBufferCache:  Pointer;     // 交换内存缓冲区
    FSwapValueCache:   T;           // 交换值缓冲区
    FSwapPointerCache: PtrUInt;     // 交换指针缓冲区
    FSwapMethod:       TSwapMethod; // 交换回调
    procedure DoSwapRaw(const aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure DoSwapPtrUInt(const aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure DoSwapMove(const aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
  protected
    function  IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean; override;
  protected
    procedure DoFill(const aElement: T); override;
    procedure DoFill(aIndex, aCount: SizeUInt; const aElement: T); virtual;
    procedure DoZero(); override;
    procedure DoZero(aIndex, aCount: SizeUInt); virtual;
    procedure DoReverse; override;
    procedure DoReverse(aStartIndex, aCount: SizeUInt); virtual;
    function  DoForEach(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): Boolean; override;
    function  DoForEach(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): Boolean; virtual;
    function  DoContains(aProxy: TEqualsProxyMethod;const aElement: T; aEquals, aData: Pointer): Boolean; override;
    function  DoContains(aProxy: TEqualsProxyMethod;const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): Boolean; virtual;
    function  DoFind(aProxy: TEqualsProxyMethod;const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeInt; virtual;
    function  DoFindIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindIFNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindLast(aProxy: TEqualsProxyMethod;const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeInt; virtual;
    function  DoFindLastIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindLastIFNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): SizeUInt; override;
    function  DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeUInt; virtual;
    function  DoCountIF(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt; override;
    function  DoCountIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeUInt; virtual;
    procedure DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aEquals, aData: Pointer); override;
    procedure DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer); virtual;
    procedure DoReplaceIF(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer); override;
    procedure DoReplaceIF(aProxy: TPredicateProxyMethod; const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer); virtual;
    function  DoIsSorted(aCompareProxy: TCompareProxyMethod; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): Boolean; virtual;
    procedure DoQuickSort(aCompareProxy: TCompareProxyMethod; aLeft, aRight: SizeUInt; aComparer, aData: Pointer); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure DoSort(aCompareProxy: TCompareProxyMethod; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer); virtual;
    function  DoBinarySearch(aCompareProxy: TCompareProxyMethod; const aValue: T; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): SizeInt; virtual;
    function  DoBinarySearchInsert(aCompareProxy: TCompareProxyMethod; const aValue: T; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): SizeInt; virtual;
    procedure DoShuffle(aProxy: TRandomGeneratorProxyMethod; aStartIndex, aCount: SizeUInt; aRandomGenerator, aData: Pointer); virtual;

  public
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    constructor Create(aCount: SizeUInt); overload;
    constructor Create(aCount: SizeUInt; aAllocator: IAllocator); overload;
    constructor Create(aCount: SizeUInt; aAllocator: IAllocator; aData: Pointer); virtual; overload;
    destructor  Destroy; override;

    { ICollection }
    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure LoadFromUnChecked(const aSrc: Pointer; aCount: SizeUInt); override; overload;
    procedure AppendUnChecked(const aSrc: Pointer; aCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    { IGenericCollection }
    procedure SaveToUnChecked(aDst: TCollection); override;

    { 容器方法... 只需要重写  doXXX }


    { IArray}

    function  GetMemory: PElement; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  Get(aIndex: SizeUInt): T; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetUnChecked(aIndex: SizeUInt): T; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Put(aIndex: SizeUInt; const aValue: T); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure PutUnChecked(aIndex: SizeUInt; const aValue: T); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetPtr(aIndex: SizeUInt): PElement; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetPtrUnChecked(aIndex: SizeUInt): PElement; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Resize(aNewSize: SizeUInt);
    procedure Ensure(aCount: SizeUInt);

    procedure OverWrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure OverWrite(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    // Non-throwing bulk ops (pointer overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;


    // Non-throwing bulk ops (collection overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: TCollection): Boolean;
    function  TryAppend(const aSrc: TCollection): Boolean;

    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure OverWrite(aIndex:SizeUInt; const aSrc: TCollection); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure OverWrite(aIndex:SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure OverWriteUnChecked(aIndex:SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    procedure Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure ReadUnChecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure ReadUnChecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}


    procedure Swap(aIndex1, aIndex2: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure SwapUnChecked(aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Swap(aIndex1, aIndex2, aCount: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Swap(aIndex1, aIndex2, aCount, aSwapBufferSize: SizeUInt); overload; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}


    procedure Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
    procedure CopyUnChecked(aSrcIndex, aDstIndex, aCount: SizeUInt);


    procedure Fill(aIndex: SizeUInt; const aValue: T); overload;
    procedure Fill(aIndex, aCount: SizeUInt; const aValue: T); overload;


    procedure Zero(aIndex: SizeUInt); overload;
    procedure Zero(aIndex, aCount: SizeUInt); overload;


    procedure Reverse(aStartIndex: SizeUInt); overload;
    procedure Reverse(aStartIndex, aCount: SizeUInt); overload;


    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}


    function  Contains(const aValue: T; aStartIndex: SizeUInt): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function Find(const aValue: T): SizeInt; overload;
    function Find(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function Find(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}


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


    function CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}

    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}


    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}

    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}


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


    procedure Sort; overload;
    procedure Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure Sort(aStartIndex: SizeUInt); overload;
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure Sort(aStartIndex, aCount: SizeUInt); overload;
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}


    function BinarySearch(const aValue: T): SizeInt; overload;
    function BinarySearch(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearch(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function BinarySearchInsert(const aValue: T): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    procedure Shuffle; overload;
    procedure Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    procedure Shuffle(aStartIndex: SizeUInt); overload;
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    procedure Shuffle(aStartIndex, aCount: SizeUInt); overload;
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    { UnChecked 算法方法 - 跳过边界检查，追求极致性能 }
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt); overload;
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    procedure SortUnChecked(aStartIndex, aCount: SizeUInt); overload;
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure FillUnChecked(aIndex, aCount: SizeUInt; const aElement: T);
    procedure ZeroUnChecked(aIndex, aCount: SizeUInt);
    procedure ReverseUnChecked(aStartIndex, aCount: SizeUInt);

    property Items[aIndex: SizeUInt]: T           read Get write Put; default;
    property Ptr[aIndex: SizeUInt]:   PElement read GetPtr;
    property Memory:                  PElement read GetMemory;


  end;


implementation

function TArray.DoIterGetCurrent(aIter: PPtrIter): Pointer;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := GetPtrUnChecked(SizeUInt(aIter^.Data));
  {$POP}
end;

function TArray.DoIterMoveNext(aIter: PPtrIter): Boolean;
begin
  if aIter^.Started then
  begin
    {$PUSH}{$WARN 4055 OFF}
    Inc(SizeUInt(aIter^.Data));
    Result := SizeUInt(aIter^.Data) < FCount;
    {$POP}
  end
  else
  begin
    aIter^.Started := True;
    aIter^.Data    := Pointer(0);
    Result         := FCount > 0;
  end;
end;

procedure TArray.DoSwapRaw(const aIndex1, aIndex2: SizeUInt);
begin
  FSwapValueCache := GetUnChecked(aIndex1);
  PutUnChecked(aIndex1, GetUnChecked(aIndex2));
  PutUnChecked(aIndex2, FSwapValueCache);
end;

procedure TArray.DoSwapPtrUInt(const aIndex1, aIndex2: SizeUInt);
var
  LP1: PPtrUInt;
  LP2: PPtrUInt;
begin
  LP1               := PPtrUInt(GetPtrUnChecked(aIndex1));
  LP2               := PPtrUInt(GetPtrUnChecked(aIndex2));
  FSwapPointerCache := LP1^;
  LP1^              := LP2^;
  LP2^              := FSwapPointerCache;
end;

procedure TArray.DoSwapMove(const aIndex1, aIndex2: SizeUInt);
var
  LP1: PElement;
  LP2: PElement;
begin
  LP1 := GetPtrUnChecked(aIndex1);
  LP2 := GetPtrUnChecked(aIndex2);

  nextpas.core.mem.utils.CopyUnChecked(LP1, FSwapBufferCache, FElementSizeCache);
  nextpas.core.mem.utils.CopyUnChecked(LP2, LP1, FElementSizeCache);
  nextpas.core.mem.utils.CopyUnChecked(FSwapBufferCache, LP2, FElementSizeCache);
end;

function TArray.IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean;
var
  LArraySize, LExternalSize: SizeUInt;
begin
  { 计算数组内存大小和外部内存块大小 }
  LArraySize := FCount * GetElementSize;
  LExternalSize := aCount * GetElementSize;

  { 使用底层内存重叠检测函数 }
  Result := nextpas.core.mem.utils.IsOverlap(FMemory, LArraySize, aSrc, LExternalSize);
end;

procedure TArray.DoFill(const aElement: T);
begin
  DoFill(0, FCount, aElement);
end;

procedure TArray.DoFill(aIndex, aCount: SizeUInt; const aElement: T);
begin
  FElementManager.FillElements(GetPtrUnChecked(aIndex), aElement, aCount);
end;

procedure TArray.DoZero();
begin
  DoZero(0, FCount);
end;

procedure TArray.DoZero(aIndex, aCount: SizeUInt);
begin
  FElementManager.ZeroElements(GetPtrUnChecked(aIndex), aCount);
end;

procedure TArray.DoReverse;
begin
  DoReverse(0, FCount);
end;

procedure TArray.DoReverse(aStartIndex, aCount: SizeUInt);
var
  LSwapCount:    SizeUInt;
  LLeft:         SizeUInt;
  LRight:        SizeUInt;
  i:             SizeUInt;
begin
  LSwapCount := aCount div 2;
  LLeft      := aStartIndex;
  LRight     := aStartIndex + aCount - 1;

  for i := 0 to LSwapCount - 1 do
  begin
    SwapUnChecked(LLeft, LRight);
    Inc(LLeft);
    Dec(LRight);
  end;
end;

function TArray.DoForEach(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): Boolean;
begin
  Result := DoForEach(aProxy, 0, FCount, aPredicate, aData);
end;

function TArray.DoForEach(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(True);

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if not aProxy(aPredicate, GetUnChecked(i), aData) then
      exit(False);

  Result := True;
end;

function TArray.DoContains(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): Boolean;
begin
  Result := DoContains(aProxy, aElement, 0, FCount, aEquals, aData);
end;

function TArray.DoContains(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): Boolean;
begin
  Result := DoFind(aProxy, aElement, aStartIndex, aCount, aEquals, aData) >= 0;
end;

function TArray.DoFind(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeInt;
var
  i, LEndIndex: SizeUInt;
begin
  LEndIndex := aStartIndex + aCount;
  i := aStartIndex;
  while i < LEndIndex do
  begin
    if aProxy(aEquals, aElement, GetUnChecked(i), aData) then
      exit(i);
    Inc(i);
  end;

  Result := -1;
end;

function TArray.DoFindIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if aProxy(aPredicate, GetUnChecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindIFNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if not aProxy(aPredicate, GetUnChecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindLast(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex + aCount - 1 downto aStartIndex do
    if aProxy(aEquals, aElement, GetUnChecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindLastIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex + aCount - 1 downto aStartIndex do
    if aProxy(aPredicate, GetUnChecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindLastIFNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex + aCount - 1 downto aStartIndex do
    if not aProxy(aPredicate, GetUnChecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): SizeUInt;
begin
  Result := DoCountOf(aProxy, aElement, 0, FCount, aEquals, aData);
end;

function TArray.DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeUInt;
var
  i: SizeUInt;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if aProxy(aEquals, aElement, GetUnChecked(i), aData) then
      Inc(Result);
end;

function TArray.DoCountIF(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt;
begin
  Result := DoCountIF(aProxy, 0, FCount, aPredicate, aData);
end;

function TArray.DoCountIF(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeUInt;
var
  i, LEndIndex: SizeUInt;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  LEndIndex := aStartIndex + aCount - 1;
  for i := aStartIndex to LEndIndex do
    if aProxy(aPredicate, GetUnChecked(i), aData) then
      Inc(Result);
end;

procedure TArray.DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aEquals, aData: Pointer);
begin
  DoReplace(aProxy, aElement, aNewElement, 0, FCount, aEquals, aData);
end;

procedure TArray.DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer);
var
  i:  SizeUInt;
  LP: PElement;
begin
  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);

    if aProxy(aEquals, aElement, LP^, aData) then
      LP^ := aNewElement;
  end;
end;

procedure TArray.DoReplaceIF(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer);
begin
  DoReplaceIF(aProxy, aNewElement, 0, FCount, aPredicate, aData);
end;

procedure TArray.DoReplaceIF(aProxy: TPredicateProxyMethod; const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer);
var
  i:  SizeUInt;
  LP: PElement;
begin
  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);

    if aProxy(aPredicate, LP^, aData) then
      LP^ := aNewElement;
  end;
end;

function TArray.DoIsSorted(aCompareProxy: TCompareProxyMethod; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): Boolean;
var
  i, LEndIndex: SizeUInt;
  LPCurrent: PElement;
  LPNext:    PElement;
begin
  if aCount < 2 then
    Exit(True);

  LPCurrent := GetPtrUnChecked(aStartIndex);
  LPNext    := GetPtrUnChecked(aStartIndex + 1);
  LEndIndex := aStartIndex + aCount - 2;

  for i := aStartIndex to LEndIndex do
  begin
    if aCompareProxy(aComparer, LPCurrent^, LPNext^, aData) > 0 then
      Exit(False);

    Inc(LPCurrent);
    Inc(LPNext);
  end;

  Result := True;
end;

procedure TArray.DoQuickSort(aCompareProxy: TCompareProxyMethod; aLeft, aRight: SizeUInt; aComparer, aData: Pointer);

  function MedianOfThree(const A, B, C: T): T; inline;
  begin
    if aCompareProxy(aComparer, A, B, aData) < 0 then
    begin
      if aCompareProxy(aComparer, B, C, aData) < 0 then
        Exit(B)
      else if aCompareProxy(aComparer, A, C, aData) < 0 then
        Exit(C)
      else
        Exit(A);
    end
    else
    begin
      if aCompareProxy(aComparer, A, C, aData) < 0 then
        Exit(A)
      else if aCompareProxy(aComparer, B, C, aData) < 0 then
        Exit(C)
      else
        Exit(B);
    end;
  end;

  procedure InsertionSort(aLeft, aRight: SizeUInt); inline;
  var
    LP:   PElement;
    i, j: SizeUInt;
    temp: T;
  begin
    LP := PElement(FMemory);

    for i := aLeft + 1 to aRight do
    begin
      temp := LP[i];
      j := i;

      while (j > aLeft) and (aCompareProxy(aComparer, LP[j - 1], temp, aData) > 0) do
      begin
        LP[j] := LP[j - 1];
        Dec(j);
      end;

      LP[j] := temp;
    end;
  end;

var
  LP:    PElement;
  i, j:  SizeUInt;
  pivot: T;
begin
  LP := PElement(FMemory);

  while aLeft < aRight do
  begin
    if aRight - aLeft <= INSERTION_SORT_THRESHOLD then
    begin
      InsertionSort(aLeft, aRight);
      Exit;
    end;

    i := aLeft;
    j := aRight;

    pivot := MedianOfThree(
      LP[aLeft],
      LP[(aLeft + aRight) div 2],
      LP[aRight]
    );

    repeat
      while aCompareProxy(aComparer, LP[i], pivot, aData) < 0 do Inc(i);
      while aCompareProxy(aComparer, LP[j], pivot, aData) > 0 do Dec(j);

      if i <= j then
      begin
        if i <> j then
          SwapUnChecked(i, j);
        Inc(i);
        Dec(j);
      end;
    until i > j;

    // 尾递归优化：先处理小段，尾递归处理大段
    if (j - aLeft) < (aRight - i) then
    begin
      DoQuickSort(aCompareProxy, aLeft, j, aComparer, aData);
      aLeft := i;
    end
    else
    begin
      DoQuickSort(aCompareProxy, i, aRight, aComparer, aData);
      aRight := j;
    end;
  end;
end;

procedure TArray.DoSort(aCompareProxy: TCompareProxyMethod; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  DoQuickSort(aCompareProxy, aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
end;

function TArray.DoBinarySearch(aCompareProxy: TCompareProxyMethod; const aValue: T; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): SizeInt;
var
  LInsertIndex: SizeInt;
begin
  LInsertIndex := DoBinarySearchInsert(aCompareProxy, aValue, aStartIndex, aCount, aComparer, aData);

  if LInsertIndex >= 0 then
    Result := LInsertIndex
  else
    Result := -1;
end;

function TArray.DoBinarySearchInsert(aCompareProxy: TCompareProxyMethod; const aValue: T; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): SizeInt;
var
  LL:         SizeUInt;
  LR:         SizeUInt;
  LM:         SizeUInt;
  LCMPResult: SizeInt;
  LP:         PElement;
begin
  LL := aStartIndex;
  LR := aStartIndex + aCount;
  LP := GetPtrUnChecked(0);

  while LL < LR do
  begin
    LM := LL + (LR - LL) div 2;
    LCMPResult := aCompareProxy(aComparer, LP[LM], aValue, aData);

    if LCMPResult < 0 then
      LL := LM + 1
    else if LCMPResult > 0 then
      LR := LM
    else
      exit(LM);
  end;

  { 未找到，返回负数编码的插入位置 }
  { 使用 -(LL + 1) 来编码插入位置，避免与找到的情况(>=0)冲突 }
  if LL <= SizeUInt(High(SizeInt)) then
    Result := -(SizeInt(LL) + 1)
  else
    Result := -1;  // 插入位置太大，返回错误
end;

procedure TArray.DoShuffle(aProxy: TRandomGeneratorProxyMethod; aStartIndex, aCount: SizeUInt; aRandomGenerator, aData: Pointer);
var
  i: SizeUInt;
begin
  if aCount < 2 then
    Exit;

  for i := (aStartIndex + aCount - 1) downto (aStartIndex + 1) do
    SwapUnChecked(i, aStartIndex + aProxy(aRandomGenerator, i - aStartIndex + 1, aData));
end;

constructor TArray.Create(aAllocator: IAllocator; aData: Pointer);
begin
  Create(0, aAllocator, aData);
end;

constructor TArray.Create(aCount: SizeUInt);
begin
  Create(aCount, GetRtlAllocator(), nil);
end;

constructor TArray.Create(aCount: SizeUInt; aAllocator: IAllocator);
begin
  Create(aCount, aAllocator, nil);
end;

constructor TArray.Create(aCount: SizeUInt; aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  FMemory := nil;
  FCount  := 0;
  FSwapBufferCache := nil;  { 初始化为nil，确保安全 }

  if GetIsManagedType then
  begin
    if FElementSizeCache = SIZE_PTR then
      FSwapMethod := @DoSwapPtrUInt
    else
    begin
      FSwapBufferCache := GetAllocator.GetMem(FElementSizeCache);

      if FSwapBufferCache = nil then
        raise EOutOfMemory.Create('TArray.Create: Failed to allocate swap buffer cache.');

      FSwapMethod := @DoSwapMove;
    end;
  end
  else
    FSwapMethod := @DoSwapRaw;

  { 使用try-except确保在Resize失败时清理已分配的资源 }
  if (aCount > 0) then
  begin
    try
      Resize(aCount);
    except
      { 如果Resize失败，需要清理已分配的FSwapBufferCache }
      if (FSwapBufferCache <> nil) and GetIsManagedType and (FElementSizeCache <> SIZE_PTR) then
      begin
        GetAllocator.FreeMem(FSwapBufferCache);
        FSwapBufferCache := nil;
      end;
      raise;  { 重新抛出异常 }
    end;
  end;
end;

destructor TArray.Destroy;
begin
  Clear;

  if GetIsManagedType and (FElementSizeCache <> SIZE_PTR) and (FSwapBufferCache <> nil) then
    GetAllocator.FreeMem(FSwapBufferCache);

  inherited Destroy;
end;

function TArray.GetCount: SizeUInt;
begin
  Result := FCount;
end;

procedure TArray.Clear;
begin
  if FCount > 0 then
    Resize(0);
end;

procedure TArray.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise nextpas.core.base.EArgumentNil.Create('TArray.SerializeToArrayBuffer: aDst is nil');

  if IsOverlap(aDst, aCount) then
    raise nextpas.core.base.EInvalidArgument.Create('TArray.SerializeToArrayBuffer: aDst is overlapped');

  if aCount > FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.SerializeToArrayBuffer: aCount out of bounds');

  FElementManager.CopyElementsNonOverlapUnChecked(FMemory, aDst, aCount);
end;

procedure TArray.LoadFromUnChecked(const aSrc: Pointer; aCount: SizeUInt);
begin
  Resize(aCount);
  OverWriteUnChecked(0, aSrc, aCount);
end;

procedure TArray.AppendUnChecked(const aSrc: Pointer; aCount: SizeUInt);
var
  LCount:       SizeUInt;
  LIndex:       SizeUInt;
  LElementSize: SizeUInt;
begin
  if aCount = 0 then
    exit;

  LCount := FCount;

  if IsOverlap(aSrc, aCount) then
  begin
    LElementSize := GetElementSize;

    {$PUSH}{$WARN 4055 OFF}
    if (PtrUInt(aSrc) mod LElementSize) <> 0 then
      raise nextpas.core.base.EInvalidArgument.Create('TArray.AppendUnChecked: aSrc is not aligned');

    LIndex := (PtrUInt(aSrc) - PtrUInt(FMemory)) div LElementSize;
    {$POP}
    if (LIndex >= LCount) or (aCount > (LCount - LIndex)) then
      raise nextpas.core.base.EOutOfRange.Create('TArray.AppendUnChecked: bounds out of range');

    Resize(LCount + aCount);
    CopyUnChecked(LIndex, LCount, aCount);
  end
  else
  begin
    Resize(LCount + aCount);
    OverWriteUnChecked(LCount, aSrc, aCount);
  end;
end;

procedure TArray.AppendToUnChecked(const aDst: TCollection);
begin
  if (FCount = 0) then
    exit;

  aDst.AppendUnChecked(FMemory, FCount);
end;

function TArray.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

procedure TArray.SaveToUnChecked(aDst: TCollection);
begin
  if FCount = 0 then
    aDst.Clear
  else
    aDst.LoadFromUnChecked(FMemory, FCount);
end;


function TArray.TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := (Self as TCollection).TryLoadFrom(aSrc, aElementCount);
end;


function TArray.TryLoadFrom(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryLoadFrom(aSrc);
end;

function TArray.TryAppend(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryAppend(aSrc);
end;

function TArray.TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := (Self as TCollection).TryAppend(aSrc, aElementCount);
end;

function TArray.GetMemory: PElement;
begin
  Result := PElement(FMemory);
end;

function TArray.Get(aIndex: SizeUInt): T;
begin
  Result := GetPtr(aIndex)^;
end;

function TArray.GetUnChecked(aIndex: SizeUInt): T;
begin
  Result := GetPtrUnChecked(aIndex)^;
end;

procedure TArray.Put(aIndex: SizeUInt; const aValue: T);
begin
  GetPtr(aIndex)^ := aValue;
end;

procedure TArray.PutUnChecked(aIndex: SizeUInt; const aValue: T);
begin
  GetPtrUnChecked(aIndex)^ := aValue;
end;

function TArray.GetPtr(aIndex: SizeUInt): PElement;
begin
  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.GetPtr: index out of range');

  Result := GetPtrUnChecked(aIndex);
end;

function TArray.GetPtrUnChecked(aIndex: SizeUInt): PElement;
begin
  Result := PElement(FMemory) + aIndex;
end;

procedure TArray.Resize(aNewSize: SizeUInt);
var
  LMemory: Pointer;
begin
  if aNewSize = FCount then
    exit;

  LMemory := FElementManager.ReallocElements(FMemory, FCount, aNewSize);

  if (aNewSize > 0) and (LMemory = nil) then
    raise nextpas.core.base.EOutOfMemory.Create('TArray.Resize: out of memory');

  FMemory := LMemory;
  FCount  := aNewSize;
end;

procedure TArray.Ensure(aCount: SizeUInt);
begin
  if FCount < aCount then
    Resize(aCount);
end;


procedure TArray.Fill(aIndex: SizeUInt; const aValue: T);
begin
  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Fill: aIndex out of range');

  DoFill(aIndex, FCount - aIndex, aValue);
end;

procedure TArray.Fill(aIndex, aCount: SizeUInt; const aValue: T);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Fill: aIndex out of range');

  if aCount > (FCount - aIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Fill: aIndex + aCount out of range');

  FillUnChecked(aIndex, aCount, aValue);
end;


procedure TArray.Zero(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Zero: aIndex out of range');

  ZeroUnChecked(aIndex, FCount - aIndex);
end;

procedure TArray.Zero(aIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Zero: aIndex out of range');

  if aCount > (FCount - aIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Zero: aIndex + aCount out of range');

  ZeroUnChecked(aIndex, aCount);
end;

procedure TArray.Swap(aIndex1, aIndex2: SizeUInt);
begin
  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Swap: index out of range');

  if aIndex1 = aIndex2 then
    raise nextpas.core.base.EInvalidArgument.Create('TArray.Swap: same index');

  SwapUnChecked(aIndex1, aIndex2);
end;

procedure TArray.SwapUnChecked(aIndex1, aIndex2: SizeUInt);
begin
  FSwapMethod(aIndex1, aIndex2);
end;

procedure TArray.Swap(aIndex1, aIndex2, aCount: SizeUInt);
begin
  Swap(aIndex1, aIndex2, aCount, ARRAY_DEFAULT_SWAP_BUFFER_SIZE);
end;

procedure TArray.Swap(aIndex1, aIndex2, aCount, aSwapBufferSize: SizeUInt);
var
  LBuffer:      Pointer;
  LP1:          PByte;
  LP2:          PByte;
  LBufferSize:  SizeUInt;
  LElementSize: SizeUInt;
  LRemainSize:  SizeUInt;
begin
  if aCount = 0 then
    Exit;

  if aIndex1 = aIndex2 then
    raise nextpas.core.base.EInvalidArgument.Create('TArray.Swap: same index');

  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Swap: index out of range');

  if aCount > (FCount - aIndex1) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Swap: aIndex1 + aCount out of range');

  if aCount > (FCount - aIndex2) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Swap: aIndex2 + aCount out of range');

  { 如果元素数量大于 1，则需要检查范围是否越界和是否重叠并且用临时缓冲区交换元素 }
  if aCount > 1 then
  begin
    if (aIndex1 + aCount > aIndex2) and (aIndex2 + aCount > aIndex1) then
      raise nextpas.core.base.EInvalidArgument.Create('TArray.Swap: overlap');

    LElementSize := GetElementSize;
    LRemainSize  := aCount * LElementSize;

    if LRemainSize > aSwapBufferSize then
      LBufferSize := aSwapBufferSize
    else
      LBufferSize := LRemainSize;

    LBuffer := Allocator.GetMem(LBufferSize);

    if LBuffer = nil then
      raise nextpas.core.base.EOutOfMemory.Create('TArray.Swap: out of memory');

    try
      { 分块交换元素 }
      LP1 := PByte(GetPtrUnChecked(aIndex1));
      LP2 := PByte(GetPtrUnChecked(aIndex2));

      while LRemainSize > 0 do
      begin
        if LBufferSize > LRemainSize then
          LBufferSize  := LRemainSize;

        nextpas.core.mem.utils.CopyUnChecked(LP1,     LBuffer, LBufferSize);
        nextpas.core.mem.utils.CopyUnChecked(LP2,     LP1,     LBufferSize);
        nextpas.core.mem.utils.CopyUnChecked(LBuffer, LP2,     LBufferSize);

        Inc(LP1, LBufferSize);
        Inc(LP2, LBufferSize);
        Dec(LRemainSize, LBufferSize);
      end;

    finally
      Allocator.FreeMem(LBuffer);
    end;
  end
  else
    SwapUnChecked(aIndex1, aIndex2);
end;

procedure TArray.Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrcIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Copy: src index out of range');

  if aDstIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Copy: dst index out of range');

  if aCount > (FCount - aSrcIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Copy: src index + count out of range');

  if aCount > (FCount - aDstIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Copy: dst index + count out of range');

  if aSrcIndex = aDstIndex then
    raise nextpas.core.base.EInvalidArgument.Create('TArray.Copy: same index');

  CopyUnChecked(aSrcIndex, aDstIndex, aCount);
end;

procedure TArray.CopyUnChecked(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnChecked(GetPtrUnChecked(aSrcIndex), GetPtrUnChecked(aDstIndex), aCount);
end;

procedure TArray.Reverse(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Reverse: aStartIndex out of range');

  Reverse(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Reverse(aStartIndex, aCount: SizeUInt);
begin
  if aCount <= 1 then
    exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Reverse: aStartIndex out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Reverse: aStartIndex + aCount out of range');

  ReverseUnChecked(aStartIndex, aCount);
end;

function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnChecked(aValue, aStartIndex, aCount);
end;

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnChecked(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TArray.Find(const aValue: T): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := Find(aValue, 0, FCount);
end;

function TArray.Find(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := Find(aValue, 0, FCount, aEquals, aData);
end;

function TArray.Find(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := Find(aValue, 0, FCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.Find(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := Find(aValue, 0, FCount, aEquals);
end;
{$ENDIF}

function TArray.Find(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnChecked(aValue, aStartIndex, aCount);
end;

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnChecked(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}


function TArray.FindIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIF(0, FCount, aPredicate, aData);
end;

function TArray.FindIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIF(0, FCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIF(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIF(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  Result := FindIF(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  Result := FindIF(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  Result := FindIF(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: bounds out of range');

  Result := FindIFUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: bounds out of range');

  Result := FindIFUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIF: bounds out of range');

  Result := FindIFUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}


function TArray.FindIFNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIFNot(0, FCount, aPredicate, aData);
end;

function TArray.FindIFNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIFNot(0, FCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIFNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIFNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  Result := FindIFNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  Result := FindIFNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIFNot(aStartIndex: SizeUInt; aPredicate: specialize
  TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  Result := FindIFNot(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: bounds out of range');

  Result := FindIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: bounds out of range');

  Result := FindIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindIFNot: bounds out of range');

  Result := FindIFNotUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLast(const aElement: T): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLast(aElement, 0, FCount);
end;

function TArray.FindLast(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLast(aElement, 0, FCount, aEquals, aData);
end;

function TArray.FindLast(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLast(aElement, 0, FCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLast(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLast(aElement, 0, FCount, aEquals);
end;
{$ENDIF}

function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex);
end;

function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnChecked(aElement, aStartIndex, aCount);
end;

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnChecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnChecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnChecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TArray.FindLastIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIF(0, FCount, aPredicate, aData);
end;

function TArray.FindLastIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIF(0, FCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIF(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIF(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  Result := FindLastIF(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  Result := FindLastIF(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIF(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  Result := FindLastIF(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: bounds out of range');

  Result := FindLastIFUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: bounds out of range');

  Result := FindLastIFUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIF: bounds out of range');

  Result := FindLastIFUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIFNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIFNot(0, FCount, aPredicate, aData);
end;

function TArray.FindLastIFNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIFNot(0, FCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIFNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIFNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  Result := FindLastIFNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  Result := FindLastIFNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  Result := DoFindLastIFNot(@DoPredicateRefFuncProxy, aStartIndex, FCount - aStartIndex, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: bounds out of range');

  Result := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: bounds out of range');

  Result := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.FindLastIFNot: bounds out of range');

  Result := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsDefaultProxy, aElement, aStartIndex, FCount - aStartIndex, nil, nil);
end;

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsFuncProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, aData);
end;

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsMethodProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsRefFuncProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, nil);
end;
{$ENDIF}

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnChecked(aElement, aStartIndex, aCount);
end;

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnChecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnChecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnChecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize
  TPredicateRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}


procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnChecked(aElement, aNewElement, aStartIndex, aCount);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnChecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnChecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnChecked(aElement, aNewElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  ReplaceIF(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  ReplaceIF(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  ReplaceIF(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: bounds out of range');

  ReplaceIFUnChecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: bounds out of range');

  ReplaceIFUnChecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ReplaceIF(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.ReplaceIF: bounds out of range');

  ReplaceIFUnChecked(aNewElement, aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.IsSorted: Boolean;
begin
  if FCount < 2 then
    Exit(True);

  Result := IsSorted(0, FCount);
end;

function TArray.IsSorted(aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if FCount < 2 then
    Exit(True);

  Result := IsSorted(0, FCount, aComparer, aData);
end;

function TArray.IsSorted(aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if FCount < 2 then
    Exit(True);

  Result := IsSorted(0, FCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSorted(aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if FCount < 2 then
    Exit(True);

  Result := IsSorted(0, FCount, aComparer);
end;
{$ENDIF}

function TArray.IsSorted(aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex);
end;

function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.IsSorted(aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnChecked(aStartIndex, aCount);
end;

function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer, aData);
end;

function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

procedure TArray.Sort;
begin
  if FCount < 2 then
    Exit;

  Sort(0, FCount);
end;

procedure TArray.Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if FCount < 2 then
    Exit;

  Sort(0, FCount, aComparer, aData);
end;

procedure TArray.Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if FCount < 2 then
    Exit;

  Sort(0, FCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Sort(aComparer: specialize TCompareRefFunc<T>);
begin
  if FCount < 2 then
    Exit;

  Sort(0, FCount, aComparer);
end;
{$ENDIF}

procedure TArray.Sort(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}


procedure TArray.Sort(aStartIndex, aCount: SizeUInt);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnChecked(aStartIndex, aCount);
end;

procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnChecked(aStartIndex, aCount, aComparer, aData);
end;

procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnChecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnChecked(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TArray.BinarySearch(const aValue: T): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearch(aValue, 0, FCount);
end;

function TArray.BinarySearch(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearch(aValue, 0, FCount, aComparer, aData);
end;

function TArray.BinarySearch(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearch(aValue, 0, FCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearch(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearch(aValue, 0, FCount, aComparer);
end;
{$ENDIF}

function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TArray.BinarySearchInsert(const aValue: T): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearchInsert(aValue, 0, FCount);
end;

function TArray.BinarySearchInsert(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearchInsert(aValue, 0, FCount, aComparer, aData);
end;

function TArray.BinarySearchInsert(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearchInsert(aValue, 0, FCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsert(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := BinarySearchInsert(aValue, 0, FCount, aComparer);
end;
{$ENDIF}

function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

procedure TArray.Shuffle;
begin
  if FCount < 2 then
    Exit;

  Shuffle(0, FCount);
end;

procedure TArray.Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if FCount < 2 then
    Exit;

  Shuffle(0, FCount, aRandomGenerator, aData);
end;

procedure TArray.Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if FCount < 2 then
    Exit;

  Shuffle(0, FCount, aRandomGenerator, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Shuffle(aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if FCount < 2 then
    Exit;

  Shuffle(0, FCount, aRandomGenerator);
end;
{$ENDIF}

procedure TArray.Shuffle(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator);
end;
{$ENDIF}

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  DoShuffle(@DoRandomGeneratorDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator);
end;
{$ENDIF}

procedure TArray.OverWrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aSrc = nil then
    raise nextpas.core.base.EArgumentNil.Create('TArray.OverWrite: aSrc is nil');

  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.OverWrite: index out of range');

  if aCount > (FCount - aIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.OverWrite: bounds out of range');

  OverWriteUnChecked(aIndex, aSrc, aCount);
end;

procedure TArray.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnChecked(aSrc, GetPtrUnChecked(aIndex), aCount);
end;

procedure TArray.OverWrite(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);
  if LLen = 0 then
    Exit;
  OverWrite(aIndex, @aSrc[0], LLen);
end;

  { UnChecked 统一约定：
    - 不进行参数/边界/空指针检查；调用方需保证前置条件
    - open array 版本要求 aSrc 非空，否则 @aSrc[0] 未定义
    - 详见 docs/UnChecked_Methods_Summary.md }

procedure TArray.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  OverWriteUnChecked(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TArray.OverWrite(aIndex: SizeUInt; const aSrc: TCollection);
begin
  if aSrc = nil then
    raise nextpas.core.base.EArgumentNil.Create('TArray.OverWrite: aSrc is nil');

  OverWrite(aIndex, aSrc, aSrc.GetCount);
end;

procedure TArray.OverWrite(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aSrc = nil then
    raise nextpas.core.base.EArgumentNil.Create('TArray.OverWrite: aSrc is nil');

  if not IsCompatible(aSrc) then
    raise nextpas.core.base.ENotCompatible.Create('TArray.OverWrite: aSrc is not compatible');

  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.OverWrite: index out of range');

  if aCount > (FCount - aIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.OverWrite: bounds out of range');

  OverWriteUnChecked(aIndex, aSrc, aCount);
end;

procedure TArray.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  aSrc.SerializeToArrayBuffer(GetPtrUnChecked(aIndex), aCount);
end;

procedure TArray.Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise nextpas.core.base.EArgumentNil.Create('TArray.Read: aDst is nil');

  if aIndex >= FCount then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Read: index out of range');

  if aCount > (FCount - aIndex) then
    raise nextpas.core.base.EOutOfRange.Create('TArray.Read: bounds out of range');

  ReadUnChecked(aIndex, aDst, aCount);
end;

procedure TArray.ReadUnChecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnChecked(GetPtrUnChecked(aIndex), aDst, aCount);
end;

procedure TArray.Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
var
  LLen: SizeUInt;
begin
  if aCount = 0 then
    exit;

  LLen := Length(aDst);

  if LLen <> aCount then
    SetLength(aDst, aCount);

  Read(aIndex, @aDst[0], aCount);
end;

procedure TArray.ReadUnChecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
begin
  SetLength(aDst, aCount);
  ReadUnChecked(aIndex, @aDst[0], aCount);
end;

{ UnChecked 算法方法实现 - 跳过边界检查，追求极致性能 }

function TArray.ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := DoContains(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoContains(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoContains(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ContainsUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  Result := DoContains(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIF(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIF(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindIF(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIFNot(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIFNot(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindIFNot(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoFindLast(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLast(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLast(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := DoFindLast(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoFind(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFind(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFind(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := DoFind(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIF(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIF(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindLastIF(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIFNot(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIFNot(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindLastIFNot(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOfUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoForEach(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoForEach(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEachUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  Result := DoForEach(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountIF(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountIF(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  Result := DoCountIF(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoEqualsDefaultProxy(nil, aElement, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoEqualsFuncProxy(@aEquals, aElement, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoEqualsMethodProxy(@aEquals, aElement, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ReplaceUnChecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoEqualsRefFuncProxy(@aEquals, aElement, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;
{$ENDIF}

function TArray.ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoPredicateFuncProxy(@aPredicate, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoPredicateMethodProxy(@aPredicate, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.ReplaceIFUnChecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnChecked(i);
    if DoPredicateRefFuncProxy(@aPredicate, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;
{$ENDIF}

procedure TArray.SortUnChecked(aStartIndex, aCount: SizeUInt);
begin
  DoSort(@DoCompareDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  DoSort(@DoCompareFuncProxy, aStartIndex, aCount, @aComparer, aData);
end;

procedure TArray.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  DoSort(@DoCompareMethodProxy, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  DoSort(@DoCompareRefFuncProxy, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.IsSortedUnChecked(aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := DoIsSorted(@DoCompareDefaultProxy, aStartIndex, aCount, nil, nil);
end;

function TArray.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoIsSorted(@DoCompareFuncProxy, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoIsSorted(@DoCompareMethodProxy, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  Result := DoIsSorted(@DoCompareRefFuncProxy, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareFuncProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareMethodProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareRefFuncProxy, aElement, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareFuncProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareMethodProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsertUnChecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareRefFuncProxy, aElement, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

procedure TArray.ShuffleUnChecked(aStartIndex, aCount: SizeUInt);
begin
  DoShuffle(@DoRandomGeneratorDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  DoShuffle(@DoRandomGeneratorFuncProxy, aStartIndex, aCount, @aRandomGenerator, aData);
end;

procedure TArray.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  DoShuffle(@DoRandomGeneratorMethodProxy, aStartIndex, aCount, @aRandomGenerator, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  DoShuffle(@DoRandomGeneratorRefFuncProxy, aStartIndex, aCount, @aRandomGenerator, nil);
end;
{$ENDIF}

procedure TArray.FillUnChecked(aIndex, aCount: SizeUInt; const aElement: T);
begin
  // Route through the same optimized path as checked Fill to ensure
  // consistent behavior for managed/unmanaged types and better performance.
  DoFill(aIndex, aCount, aElement);
end;

procedure TArray.ZeroUnChecked(aIndex, aCount: SizeUInt);
begin
  DoZero(aIndex, aCount);
end;

procedure TArray.ReverseUnChecked(aStartIndex, aCount: SizeUInt);
begin
  DoReverse(aStartIndex, aCount);
end;

initialization
  System.Randomize;

end.
