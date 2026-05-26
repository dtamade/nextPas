unit nextpas.core.collections.element_manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.collections.element_manager

## Abstract 摘要

Element manager, an interface for managing the allocation and
release of elements and providing some element operations.
元素管理器, 用于管理元素的分配和释放和提供一些元素操作的接口.

## Declaration 声明

For forwarding or using it for your own project, please retain the copyright notice of this project. Thank you.
转发或者用于自己项目请保留本项目的版权声明,谢谢.

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

{$I nextpas.core.settings.inc}

interface

  uses
    sysutils,
    typinfo,
    nextpas.core.base,
    nextpas.core.math,
    nextpas.core.mem.utils,
    nextpas.core.mem.allocator;

  type

  generic TGenericHelper<T> = class
  public
    type
      PElement = ^T;
  end;

  type

  {**
   * IElementManager<T>
   *
   * @desc
   *   An interface for managing the lifecycle of elements of type T,
   *   including allocation, deallocation, initialization, finalization, and manipulation.
   *   一个用于管理 T 类型元素生命周期的接口,
   *   包括分配, 释放, 初始化, 终结和操作.
   *}
  generic IElementManager<T> = interface
  ['{11472FC3-A5E0-4CCA-A8E4-51053B6D5D7C}']

    {**
     * GetAllocator
     *
     * @desc
     *   Gets the underlying raw memory allocator used by this element manager.
     *   获取此元素管理器所使用的底层原始内存分配器.
     *
     * @return
     *   An `TAllocator` instance.
     *   一个 `TAllocator` 实例.
     *}
    function GetAllocator: IAllocator;

    {**
     * GetElementSize
     *
     * @desc
     *   Gets the memory size (in bytes) of a single element of the generic type T.
     *   获取泛型类型 T 的单个元素所占用的内存大小 (以字节为单位).
     *
     * @return
     *   The size of a single element.
     *   单个元素的大小.
     *}
    function GetElementSize: SizeUInt;

    {**
     * GetIsManagedType
     *
     * @desc
     *   Checks if the generic type T is a managed type (e.g., string, interface).
     *   检查泛型类型 T 是否为托管类型 (如 `string`, `interface`).
     *
     * @return
     *   `True` if T is a managed type; otherwise, `False`.
     *   如果是托管类型, 则返回 `True`; 否则返回 `False`.
     *
     * @remark
     *   Managed types have automatic lifecycle management (e.g., reference counting).
     *   This manager provides special handling for their initialization and finalization.
     *   托管类型拥有自动的生命周期管理 (如引用计数).
     *   此管理器会为它们提供特殊的初始化和释放处理.
     *}
    function GetIsManagedType: Boolean;

    {**
     * GetElementTypeInfo
     *
     * @desc
     *   Gets the Runtime Type Information (RTTI) for the generic type T.
     *   获取泛型类型 T 的运行时类型信息 (RTTI).
     *
     * @return
     *   A pointer to the TTypeInfo record.
     *   指向 TTypeInfo 记录的指针.
     *}
    function GetElementTypeInfo: PTypeInfo;

    {**
     * InitializeElements
     *
     * @desc
     *   Initializes all elements in a specified memory block.
     *   对一块内存区域中的所有元素进行初始化.
     *
     * @params
     *   aDst           A pointer to the array of elements.
     *                  指向元素数组的指针.
     *
     *   aElementCount  The number of elements to initialize.
     *                  要初始化的元素数量.
     *
     * @remark
     *   This method is only effective for managed types, initializing them to their default
     *   empty state (e.g., empty string, `nil` interface). It performs no action for non-managed types.
     *   In accordance with the no-op principle, if `aElementCount` is 0, the procedure exits immediately.
     *
     *   此方法仅对托管类型有效, 它会将 string 初始化为空字符串, 接口初始化为 nil 等.
     *   对于非托管类型, 此方法不执行任何操作.
     *   根据空操作原则, 如果 `aElementCount` 为 0, 该过程将直接退出.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure InitializeElements(aDst: Pointer; aElementCount: SizeUInt);

    {**
     * InitializeElementsUnChecked
     *
     * @desc
     *   Initializes all elements in a memory block. (Unchecked version for performance).
     *   对一块内存区域中的所有元素进行初始化 (快速, 无检查版本).
     *
     * @params
     *   aDst           A pointer to the array of elements.
     *                  指向元素数组的指针.
     *
     *   aElementCount  The number of elements to initialize.
     *                  要初始化的元素数量.
     *
     * @remark
     *   This is the unchecked version. The caller must ensure all parameters are valid.
     *   这是无检查版本. 调用者必须自行保证所有参数的有效性.
     *}
    procedure InitializeElementsUnChecked(aDst: Pointer; aElementCount: SizeUInt);

    {**
     * FinalizeManagedElements
     *
     * @desc
     *   Finalizes all managed-type elements in a specified memory block.
     *   对一块内存区域中的所有托管类型元素进行终结 (Finalize).
     *
     * @params
     *   aDst           A pointer to the array of elements.
     *                  指向元素数组的指针.
     *
     *   aElementCount  The number of elements to finalize.
     *                  要终结的元素数量.
     *
     * @remark
     *   This method is only effective for managed types, decrementing their reference counts.
     *   It performs no action for non-managed types.
     *   In accordance with the no-op principle, if `aElementCount` is 0, the procedure exits immediately.
     *   此方法仅对托管类型有效, 它会减少 string 或 interface 的引用计数.
     *   对于非托管类型, 此方法不执行任何操作.
     *   根据空操作原则, 如果 `aElementCount` 为 0, 该过程将直接退出.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure FinalizeManagedElements(aDst: Pointer; aElementCount: SizeUInt);

    {**
     * FinalizeManagedElementsUnChecked
     *
     * @desc
     *   Finalizes all managed-type elements in a memory block. (Unchecked version for performance).
     *   对一块内存区域中的所有托管类型元素进行终结 (快速, 无检查版本).
     *
     * @params
     *   aDst           A pointer to the array of elements.
     *                  指向元素数组的指针.
     *
     *   aElementCount  The number of elements to finalize.
     *                  要终结的元素数量.
     *
     * @remark
     *   This is the unchecked version. The caller must ensure all parameters are valid.
     *   这是无检查版本. 调用者必须自行保证所有参数的有效性.
     *}
    procedure FinalizeManagedElementsUnChecked(aDst: Pointer; aElementCount: SizeUInt);

    {**
     * AllocElements
     *
     * @desc
     *   Allocates memory for a specified number of elements and initializes them.
     *   分配足够容纳指定数量元素的内存, 并进行适当的初始化.
     *
     * @params
     *   aElementCount The number of elements to allocate.
     *                 要分配的元素数量.
     *
     * @return
     *   A type-safe pointer to the newly allocated array.
     *   一个指向新分配的元素数组的类型安全指针.
     *
     * @remark
     *   If T is a managed type, the allocated memory is initialized via `InitializeElements`.
     *   If `aCount` is 0, returns `nil` as per the no-op principle.
     *   如果 T 是托管类型, 分配后的内存区域会通过 `InitializeElements` 进行初始化.
     *   如果 `aCount` 为 0, 根据空操作原则返回 `nil`.
     *}
    function AllocElements(aElementCount: SizeUInt): specialize TGenericHelper<T>.PElement;

    {**
     * AllocElement
     *
     * @desc
     *   Allocates and initializes memory for a single element.
     *   分配并初始化单个元素的内存.
     *
     * @return
     *   A type-safe pointer to the newly allocated element.
     *   一个指向新分配的单个元素的类型安全指针.
     *
     * @remark  This is a convenience method for `AllocElements(1)`.
     *          这是 `AllocElements(1)` 的便捷方法.
     *}
    function AllocElement: specialize TGenericHelper<T>.PElement;

    {**
     * ReallocElements
     *
     * @desc
     *   Reallocates a memory block for elements, adjusting its capacity.
     *   重新分配一块元素内存区域, 调整其可容纳的元素数量.
     *
     * @params
     *   aDst              A pointer to the current memory block. Can be `nil`.
     *                     指向当前元素内存块的指针. 可以为 `nil`.
     *
     *   aElementCount     The current number of elements in the memory block.
     *                     内存块中当前的元素数量.
     *
     *   aNewElementCount  The desired new number of elements.
     *                     调整后期望的元素数量.
     *
     * @return
     *   A type-safe pointer to the reallocated array of elements.
     *   一个指向新分配的元素数组的类型安全指针.
     *
     * @remark
     *   If `aDst` is `nil`, this function behaves like `AllocElements`.
     *   If `aNewElementCount` is 0, this function behaves like `FreeElements` and returns `nil`.
     *   This function intelligently handles managed types during resizing.
     *
     *   如果 `aDst` 为 `nil`, 此函数行为类似于 `AllocElements`.
     *   如果 `aNewElementCount` 为 0, 此函数行为类似于 `FreeElements`, 并返回 `nil`.
     *   此过程在调整大小时会智能处理托管类型.
     *
     * @exceptions
     *   EInvalidOperation  If `aDst` is `nil` and `aElementCount` is not 0, as this indicates an inconsistent state.
     *                      当 `aDst` 为 `nil` 但 `aElementCount` 不为 0 时抛出, 因为这表示一个不一致的状态.
     *}
    function ReallocElements(aDst: Pointer; aElementCount, aNewElementCount: SizeUInt): specialize TGenericHelper<T>.PElement;

    {**
     * FreeElements
     *
     * @desc
     *   Frees a memory block containing a specified number of elements.
     *   释放一块包含指定数量元素的内存.
     *
     * @params
     *   aDst           A pointer to the memory block to be freed.
     *                  指向要释放的元素内存块的指针.
     *
     *   aElementCount  The number of elements in the block.
     *                  内存块中的元素数量.
     *
     * @remark
     *   If T is a managed type, all elements are finalized before freeing the memory.
     *   In accordance with the no-op principle, if `aElementCount` is 0, the procedure exits immediately.
     *   如果 T 是托管类型, 在释放内存前, 所有元素会先被终结.
     *   根据空操作原则, 如果 `aElementCount` 为 0, 该过程将直接退出.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure FreeElements(aDst: Pointer; aElementCount: SizeUInt);

    {**
     * FreeElement
     *
     * @desc
     *   Frees the memory for a single element allocated by `AllocElement`.
     *   释放由 `AllocElement` 分配的单个元素内存.
     *
     * @params
     *   aDst  A pointer to the element to be freed.
     *         指向要释放的元素的指针.
     *
     * @remark
     *   This is a convenience method for `FreeElements(aDst, 1)`.
     *   这是 `FreeElements(aDst, 1)` 的便捷方法.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil`.
     *                 当 `aDst` 为 `nil` 时抛出.
     *}
    procedure FreeElement(aDst: Pointer);

    {**
     * IsOverlap
     *
     * @desc
     *   Checks if two memory regions of elements overlap.
     *   检查两个元素数组的内存区域是否重叠.
     *
     * @params
     *   aSrc           A pointer to the first array of elements.
     *                  指向第一个元素数组的指针.
     *
     *   aDst           A pointer to the second array of elements.
     *                  指向第二个元素数组的指针.
     *
     *   aElementCount  The number of elements in the arrays.
     *                  数组中的元素数量.
     *
     * @return
     *   `True` if the memory regions overlap; otherwise, `False`.
     *   如果内存区域有重叠, 则返回 `True`; 否则返回 `False`.
     *}
    function IsOverlap(aSrc, aDst: Pointer; aElementCount: SizeUInt): Boolean;

    {**
     * CopyElements
     *
     * @desc
     *   Copies elements from a source to a destination, safely handling overlapping memory regions.
     *   复制元素, 能安全处理源和目标内存区域重叠的情况.
     *
     * @params
     *   aSrc           A pointer to the source array of elements.
     *                  指向源元素数组的指针.
     *
     *   aDst           A pointer to the destination array of elements.
     *                  指向目标元素数组的指针.
     *
     *   aElementCount  The number of elements to copy.
     *                  要复制的元素数量.
     *
     * @remark
     *   This operation is safe for managed types (handles reference counts correctly).
     *   It is equivalent to a `Move` operation on the elements.
     *   The caller must ensure that pointers are valid and the destination has enough capacity.
     *   此操作对于托管类型是安全的 (会正确处理引用计数), 等价于对元素进行 `Move` 操作.
     *   调用者必须确保指针有效且目标区域有足够容量.
     *
     * @exceptions
     *   EArgumentNil       If `aSrc` or `aDst` is `nil` and `aElementCount` > 0.
     *                      当 `aSrc` 或 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *
     *   EInvalidOperation  If `aSrc` and `aDst` point to the same memory location.
     *                      当 `aSrc` 和 `aDst` 指向相同的内存地址时抛出.
     *}
    procedure CopyElements(aSrc, aDst: specialize TGenericHelper<T>.PElement; aElementCount: SizeUInt);

    {**
     * CopyElementsUnChecked
     *
     * @desc
     *   Copies elements, safely handling overlaps. (Unchecked version for performance).
     *   复制元素, 能安全处理重叠情况 (快速, 无检查版本).
     *
     * @params
     *   aSrc           A pointer to the source array of elements.
     *                  指向源元素数组的指针.
     *
     *   aDst           A pointer to the destination array of elements.
     *                  指向目标元素数组的指针.
     *
     *   aElementCount  The number of elements to copy.
     *                  要复制的元素数量.
     *
     * @remark
     *   This is the unchecked version. The caller must ensure all parameters are valid.
     *   这是无检查版本. 调用者必须自行保证所有参数的有效性.
     *}
    procedure CopyElementsUnChecked(aSrc, aDst: specialize TGenericHelper<T>.PElement; aElementCount: SizeUInt);

    {**
     * CopyElementsNonOverlap
     *
     * @desc
     *   Copies elements, assuming the source and destination memory regions do not overlap.
     *   复制元素, 此过程假定源和目标内存区域没有重叠.
     *
     * @params
     *   aSrc           A pointer to the first source element.
     *                  指向第一个源元素的指针.
     *
     *   aDst           A pointer to the first destination element.
     *                  指向第一个目标元素的指针.
     *
     *   aElementCount  The number of elements to copy.
     *                  要复制的元素数量.
     *
     * @remark
     *   WARNING: The result is undefined if the memory regions overlap.
     *   For managed types, this procedure correctly increments reference counts.
     *   警告: 如果源和目标内存区域有任何重叠, 结果是未定义的.
     *   对于托管类型, 此过程会正确增加其引用计数.
     *
     * @exceptions
     *   EArgumentNil  If `aSrc` or `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aSrc` 或 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure CopyElementsNonOverlap(aSrc, aDst: specialize TGenericHelper<T>.PElement; aElementCount: SizeUInt);

    {**
     * CopyElementsNonOverlapUnChecked
     *
     * @desc
     *   Copies elements, assuming no overlap. (Unchecked version for performance).
     *   复制元素, 假定无重叠 (快速, 无检查版本).
     *
     * @params
     *   aSrc           A pointer to the first source element.
     *                  指向第一个源元素的指针.
     *
     *   aDst           A pointer to the first destination element.
     *                  指向第一个目标元素的指针.
     *
     *   aElementCount  The number of elements to copy.
     *                  要复制的元素数量.
     *
     * @remark
     *   This is the unchecked version. The caller must ensure all parameters are valid and regions do not overlap.
     *   这是无检查版本. 调用者必须自行保证所有参数有效且区域不重叠.
     *}
    procedure CopyElementsNonOverlapUnChecked(aSrc, aDst: specialize TGenericHelper<T>.PElement; aElementCount: SizeUInt);

    {**
     * FillElements
     *
     * @desc
     *   Fills a memory block with a "template" element.
     *   使用一个“模板”元素, 填充一块内存区域.
     *
     * @params
     *   aDst           A pointer to the first destination element.
     *                  指向要填充的第一个目标元素的指针.
     *
     *   aValue         The template element to use as the source for filling.
     *                  用作填充源的模板元素.
     *
     *   aElementCount  The number of elements to fill.
     *                  要填充的元素数量.
     *
     * @remark
     *   For managed types, this procedure increments the reference count of `aValue`.
     *   The caller must ensure the destination has enough capacity.
     *   对于托管类型, 此过程会增加 `aValue` 的引用计数.
     *   调用者必须确保目标区域有足够容量.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure FillElements(aDst: Pointer; aValue: T; aElementCount: SizeUInt);

    {**
     * ZeroElements
     *
     * @desc
     *   Initializes all elements in a memory block to their type's "zero-equivalent" value.
     *   将一块内存区域中的所有元素初始化为其类型的“零等价值”.
     *
     * @params
     *   aDst  A pointer to the first element to be zeroed.
     *         指向要清零的第一个元素的指针.
     *
     *   aElementCount  The number of elements to zero.
     *                  要清零的元素数量.
     *
     * @remark
     *   For managed types, this means finalizing them (e.g., setting to `nil`).
     *   For non-managed types, this means a binary zeroing of the memory.
     *   对于托管类型, 零等价意味着终结它们 (设为 `nil`, 减少引用计数).
     *   对于非托管类型, 零等价意味着将内存按位清零.
     *
     * @exceptions
     *   EArgumentNil  If `aDst` is `nil` and `aElementCount` > 0.
     *                 当 `aDst` 为 `nil` 且 `aElementCount` > 0 时抛出.
     *}
    procedure ZeroElements(aDst: Pointer; aElementCount: SizeUInt);

    property ElementSize:     SizeUInt   read GetElementSize;
    property IsManagedType:   Boolean    read GetIsManagedType;
    property ElementTypeInfo: PTypeInfo  read GetElementTypeInfo;
    property Allocator:       IAllocator read GetAllocator;

  end;

  type

  { TElementManager 泛型元素分配器实现 }

  generic TElementManager<T> = class(TObject)
  type
    PElement = ^T;
  private
    FAllocator:       IAllocator;
    FElementSize:     SizeUInt;
    FIsManagedType:   Boolean;
    FElementTypeInfo: PTypeInfo;
  private
    procedure CopyElementsUnCheckedInternal(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  public
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create; overload;

    function  GeTAllocator: IAllocator; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetElementSize: SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetIsManagedType: Boolean; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  GetElementTypeInfo: PTypeInfo; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure InitializeElements(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure InitializeElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FinalizeManagedElements(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FinalizeManagedElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    function  AllocElements(aElementCount: SizeUInt): PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  AllocElement: PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function  ReallocElements(aDst: Pointer; aElementCount, aNewElementCount: SizeUInt): PElement; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FreeElements(aDst: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure FreeElement(aDst: Pointer); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    function  IsOverlap(aSrc, aDst: Pointer; aElementCount: SizeUInt): Boolean; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure CopyElements(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure CopyElementsUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure CopyElementsNonOverlap(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure CopyElementsNonOverlapUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    procedure FillElements(aDst: Pointer; aValue: T; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    procedure ZeroElements(aDst: Pointer; aElementCount: SizeUInt); {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}

    property  ElementSize:     SizeUInt   read GetElementSize;
    property  IsManagedType:   Boolean    read GetIsManagedType;
    property  ElementTypeInfo: PTypeInfo  read GetElementTypeInfo;
    property  Allocator:       IAllocator read GeTAllocator;
  end;


implementation

{ TElementManager }

constructor TElementManager.Create(aAllocator: IAllocator);
begin
  inherited Create;
  FAllocator       := aAllocator;
  FElementSize     := SizeOf(T);
  FIsManagedType   := system.IsManagedType(T);
  FElementTypeInfo := system.TypeInfo(T);
end;

constructor TElementManager.Create;
begin
  Create(nextpas.core.mem.allocator.GetRtlAllocator);
end;

function TElementManager.GeTAllocator: IAllocator;
begin
  Result := FAllocator;
end;

procedure TElementManager.InitializeElements(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aPtr = nil then
    raise EArgumentNil.Create('TElementManager.InitializeElements: aPtr is nil');

  InitializeElementsUnChecked(aPtr, aElementCount);
end;

procedure TElementManager.InitializeElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 1 then
    Initialize(T(aPtr^))
  else
    InitializeArray(aPtr,FElementTypeInfo,aElementCount); // FillChar(aPtr^, aElementCount * FElementSize, 0);
end;

procedure TElementManager.FinalizeManagedElements(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aPtr = nil then
    raise EArgumentNil.Create('TElementManager.FinalizeManagedElements: aPtr is nil');

  FinalizeManagedElementsUnChecked(aPtr, aElementCount);
end;

procedure TElementManager.FinalizeManagedElementsUnChecked(aPtr: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aElementCount = 1 then
    Finalize(T(aPtr^))
  else
    FinalizeArray(aPtr, FElementTypeInfo, aElementCount);
end;

procedure TElementManager.CopyElementsNonOverlapUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  case aElementCount of
    1:aDst[0] := aSrc[0];
    2:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
    end;
    3:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
    end;
    4:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
    end;
    5:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
    end;
    6:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
    end;
    7:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
      aDst[6] := aSrc[6];
    end;
    8:begin
      aDst[0] := aSrc[0];
      aDst[1] := aSrc[1];
      aDst[2] := aSrc[2];
      aDst[3] := aSrc[3];
      aDst[4] := aSrc[4];
      aDst[5] := aSrc[5];
      aDst[6] := aSrc[6];
      aDst[7] := aSrc[7];
    end;
  else
    if FIsManagedType then
      CopyArray(aDst, aSrc, FElementTypeInfo, aElementCount)
    else
      nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, aElementCount * FElementSize);
  end;
end;

procedure TElementManager.CopyElementsUnCheckedInternal(aSrc, aDst: PElement; aElementCount: SizeUInt);
var
  LPSrcTail:        ^T;
  LPDstTail:        ^T;
  LIsReverse:       boolean;
  LOverlapCount:    SizeUInt;
  LNonOverlapCount: SizeUInt;
begin
  { 非托管类型,直接拷贝 }
  if not FIsManagedType then
  begin
    nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, aElementCount * FElementSize);
    exit;
  end;

  { 托管类型 }
  LPSrcTail  := aSrc + aElementCount;
  LPDstTail  := aDst + aElementCount ;
  LIsReverse := (aSrc > aDst);

  if LIsReverse then
    LOverlapCount := LPDstTail - aSrc
    else
    LOverlapCount := LPSrcTail - aDst;

  LNonOverlapCount := aElementCount - LOverlapCount;

  { 小重叠 直接拷贝两手 }
  if LNonOverlapCount >= LOverlapCount then
  begin
    if LIsReverse then
    begin
      CopyArray(aDst, aSrc, FElementTypeInfo, LOverlapCount);
      CopyArray(aDst + LOverlapCount, aSrc + LOverlapCount, FElementTypeInfo, LNonOverlapCount);
    end
    else
    begin
      CopyArray(LPDstTail - LOverlapCount, LPSrcTail - LOverlapCount, FElementTypeInfo, LOverlapCount);
      CopyArray(aDst, aSrc, FElementTypeInfo, LNonOverlapCount);
    end;
  end
  else
  begin
    { 大重叠 }
    if LIsReverse then
    begin
      FinalizeManagedElementsUnChecked(aDst, LOverlapCount);
      nextpas.core.mem.utils.CopyUnChecked(aSrc, aDst, LOverlapCount * FElementSize);
      nextpas.core.mem.utils.Zero(LPDstTail - LNonOverlapCount, LNonOverlapCount * FElementSize);
      CopyArray(LPDstTail - LNonOverlapCount, LPSrcTail - LNonOverlapCount, FElementTypeInfo, LNonOverlapCount);
    end
    else
    begin
      FinalizeManagedElementsUnChecked(LPDstTail - LNonOverlapCount, LNonOverlapCount);
      nextpas.core.mem.utils.CopyUnChecked(aSrc + LNonOverlapCount, aDst + LNonOverlapCount, LOverlapCount * FElementSize);
      nextpas.core.mem.utils.Zero(aDst, LNonOverlapCount * FElementSize);
      CopyArray(aDst, aSrc, FElementTypeInfo, LNonOverlapCount);
    end;
  end;
end;

function TElementManager.GetElementSize: SizeUInt;
begin
  Result := FElementSize;
end;

function TElementManager.GetIsManagedType: Boolean;
begin
  Result := FIsManagedType;
end;

function TElementManager.GetElementTypeInfo: PTypeInfo;
begin
  Result := FElementTypeInfo;
end;

function TElementManager.AllocElements(aElementCount: SizeUInt): PElement;
begin
  if aElementCount = 0 then
    Exit(nil);

  // size overflow guard: aElementCount * FElementSize
  if (aElementCount > 0) and (aElementCount > High(SizeUInt) div FElementSize) then
    raise EOverflow.Create('TElementManager.AllocElements: size overflow');

  Result := FAllocator.GetMem(aElementCount * FElementSize);

  if (Result <> nil) and FIsManagedType then
    InitializeElementsUnChecked(Result, aElementCount);
end;

function TElementManager.AllocElement: PElement;
begin
  Result := AllocElements(1);
end;

function TElementManager.ReallocElements(aDst: Pointer; aElementCount, aNewElementCount: SizeUInt): PElement;
begin
  { 分配 }
  if aDst = nil then
  begin
    if aNewElementCount > 0 then
      Result := AllocElements(aNewElementCount)
    else
      Exit(nil); // aDst=nil 且新容量=0 => 无操作，返回 nil

    exit;
  end;

  { 释放 }
  if aNewElementCount = 0 then
  begin
    FreeElements(aDst, aElementCount);
    Exit(nil);
  end;

  { 调整 }

  // size overflow guard before any pointer arithmetic or allocation
  if (aNewElementCount > 0) and (aNewElementCount > High(SizeUInt) div FElementSize) then
    raise EOverflow.Create('TElementManager.ReallocElements: size overflow');

  { 托管元素缩小前,反初始化因缩小而放弃的内存 }
  if FIsManagedType and (aNewElementCount < aElementCount) then
    FinalizeManagedElements(Pointer(aDst + (aNewElementCount * FElementSize)), aElementCount - aNewElementCount);

  { 调整内存 }
  Result := FAllocator.ReallocMem(aDst, aNewElementCount * FElementSize);

  { 托管元素扩大时,初始化新扩大的内存 }
  if FIsManagedType and (aNewElementCount > aElementCount) then
    InitializeElements(Pointer(Result + aElementCount), aNewElementCount - aElementCount);
end;

procedure TElementManager.FreeElements(aDst: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.FreeElements: aDst is nil');

  if FIsManagedType then
    FinalizeManagedElements(aDst, aElementCount);

  FAllocator.FreeMem(aDst);
end;

procedure TElementManager.FreeElement(aDst: Pointer);
begin
  FreeElements(aDst, 1);
end;

function TElementManager.IsOverlap(aSrc, aDst: Pointer; aElementCount: SizeUInt): Boolean;
var
  LSize: SizeUInt;
begin
  LSize  := aElementCount * FElementSize;
  Result := nextpas.core.mem.utils.IsOverlap(aSrc, LSize, aDst, LSize);
end;

procedure TElementManager.CopyElements(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TElementManager.CopyElements: aSrc is nil');

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.CopyElements: aDst is nil');

  if aSrc = aDst then
    raise EInvalidArgument.Create('TElementManager.CopyElements: aSrc and aDst are the same');

  CopyElementsUnChecked(aSrc, aDst, aElementCount);
end;

procedure TElementManager.CopyElementsUnChecked(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if IsOverlap(aSrc, aDst, aElementCount) then
    CopyElementsUnCheckedInternal(aSrc, aDst, aElementCount)
  else
    CopyElementsNonOverlapUnChecked(aSrc, aDst, aElementCount); // 不重叠,直接拷贝
end;

procedure TElementManager.CopyElementsNonOverlap(aSrc, aDst: PElement; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TElementManager.CopyElementsNonOverlap: aSrc is nil');

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.CopyElementsNonOverlap: aDst is nil');

  if aSrc = aDst then
    raise EInvalidArgument.Create('TElementManager.CopyElementsNonOverlap: aSrc and aDst are the same');

  CopyElementsNonOverlapUnChecked(aSrc, aDst, aElementCount);
end;

procedure TElementManager.FillElements(aDst: Pointer; aValue: T; aElementCount: SizeUInt);
var
  LPDst:      ^T;
  LBlockSize: SizeUInt;
  LSize:      SizeUInt;
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.FillElements: aDst is nil');

  if FIsManagedType or (FElementSize > 8) then
  begin
    LPDst  := aDst;
    LPDst^ := aValue;

    if aElementCount > 1 then
    begin
      LBlockSize := 1;

      while LBlockSize < aElementCount do
      begin
        LSize := Min(LBlockSize, aElementCount - LBlockSize);
        CopyElementsNonOverlapUnChecked(LPDst, Pointer(LPDst + LBlockSize), LSize);
        inc(LBlockSize, LSize);
      end;
    end;

  end
  else
  begin
    case FElementSize of
      1: nextpas.core.mem.utils.Fill8(aDst, aElementCount,  PUInt8(@aValue)^);
      2: nextpas.core.mem.utils.Fill16(aDst, aElementCount, PUInt16(@aValue)^);
      4: nextpas.core.mem.utils.Fill32(aDst, aElementCount, PUInt32(@aValue)^);
      8: nextpas.core.mem.utils.Fill64(aDst, aElementCount, PUInt64(@aValue)^);
    end;
  end;
end;

procedure TElementManager.ZeroElements(aDst: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TElementManager.ZeroElements: aDst is nil');

  if FIsManagedType then
    FinalizeManagedElementsUnChecked(aDst, aElementCount)
  else
  begin
    case FElementSize of
      1: nextpas.core.mem.utils.Fill8(aDst,  aElementCount, 0);
      2: nextpas.core.mem.utils.Fill16(aDst, aElementCount, 0);
      4: nextpas.core.mem.utils.Fill32(aDst, aElementCount, 0);
      8: nextpas.core.mem.utils.Fill64(aDst, aElementCount, 0);
    else
      nextpas.core.mem.utils.Zero(aDst, aElementCount * FElementSize);
    end;
  end;
end;


end.
