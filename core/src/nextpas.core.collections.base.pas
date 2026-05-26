unit nextpas.core.collections.base;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,typinfo,variants,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.allocator,
  nextpas.core.collections.element_manager;

// Suppress unused parameter hints - growth strategies and IsOverlap have intentionally unused params
{$WARN 5024 OFF}


type

  TCollection = class;

  generic TGenericArray<T> = array of T;

  {**
   * TMapEntry<K,V> - 键值对记录
   *
   * @desc 用于 Map 类型容器的统一键值对类型
   * @param K 键类型
   * @param V 值类型
   *}
  generic TMapEntry<K,V> = record
    Key: K;
    Value: V;
  end;

  {**
   * TPair<K,V> - 键值对记录（与 TMapEntry 结构相同）
   *
   * @desc 保持向后兼容，部分模块使用 TPair 命名
   *}
  generic TPair<K,V> = record
    Key: K;
    Value: V;
  end;

  PPtrIter = ^TPtrIter;

  { TPtrIter 指针迭代器 }
  TPtrIter = record
  type
    TPtrIterGetCurrentMethod = function(aIter: PPtrIter): Pointer of object;
    TPtrIterMoveNextMethod   = function(aIter: PPtrIter): Boolean of object;
    TPtrIterMovePrevMethod   = function(aIter: PPtrIter): Boolean of object;

  private
    FGetCurrent: TPtrIterGetCurrentMethod; // 必须
    FMoveNext:   TPtrIterMoveNextMethod;   // 必须
    FMovePrev:   TPtrIterMovePrevMethod;   // 非必须
  public
    Owner:   TCollection;
    Started: Boolean;
    Data:    Pointer;
  public
    procedure Init(aOwner: TCollection; aGetCurrent: TPtrIterGetCurrentMethod; aMoveNext: TPtrIterMoveNextMethod; aMovePrev: TPtrIterMovePrevMethod; aData: Pointer); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Init(aOwner: TCollection; aGetCurrent: TPtrIterGetCurrentMethod; aMoveNext: TPtrIterMoveNextMethod; aData: Pointer); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    function  GetStarted: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetCurrent: Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  MoveNext: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  MovePrev: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Reset; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    property Current: Pointer read GetCurrent;
  end;

  { ICollection 基础非泛型容器接口 }
  ICollection = interface
  ['{F5141F56-CA81-46F3-966E-71988C038AE0}']

    {**
    * PtrIter
    *
    * @desc
    *   Gets a pointer iterator for the container's elements.
    *   获取容器元素指针迭代器.
    *
    * @return
    *   A pointer iterator for the container's elements.
    *   容器元素指针迭代器.
    *}
    function PtrIter: TPtrIter;

    {**
    * GetAllocator
    *
    * @desc
    *   Gets the memory allocator used by the collection.
    *   获取容器使用的内存分配器.
    *
    * @return
    *   The `TAllocator` instance for this collection.
    *   此容器的 `TAllocator` 实例.
    *
    * @remark
    *   All memory operations within the collection are handled by this allocator, forming the basis of its lifecycle.
    *   容器内的所有内存操作都由此分配器处理, 它是容器生命周期的基础.
    *   This allocator is never `nil`; by default, it is the RTL's memory allocator.
    *   此容器永远不会 `nil`, 默认它是 `rtl` 的内存分配器.
    *}
    function GetAllocator: IAllocator;

    {**
    * GetCount
    *
    * @desc
    *   Gets the number of elements currently in the collection.
    *   获取容器中当前元素的数量.
    *
    * @return
    *   The number of elements.
    *   元素的数量.
    *}
    function GetCount: SizeUInt;

    {**
    * IsEmpty
    *
    * @desc
    *   Checks if the collection contains no elements.
    *   检查容器是否为空 (不包含任何元素).
    *
    * @return
    *   Returns `True` if the collection is empty, otherwise `False`.
    *   如果容器为空, 则返回 `True`, 否则返回 `False`.
    *
    * @remark
    *   This method is equivalent to `GetCount = 0`.
    *   此方法等同 `GetCount = 0`.
    *}
    function IsEmpty: Boolean;

    {**
    * GetData
    *
    * @desc
    *   Gets the user-defined data pointer associated with the collection.
    *   获取与容器关联的用户自定义数据指针.
    *
    * @return
    *   The user-defined pointer.
    *   用户自定义的指针.
    *
    * @remark
    *   This property allows a user to associate arbitrary data with a collection instance.
    *   The collection itself does not manage or interpret this data.
    *   此属性允许用户将任意数据与容器实例关联. 容器本身不管理或解释此数据.
    *}
    function GetData: Pointer;

    {**
    * SetData
    *
    * @desc
    *   Sets the user-defined data pointer associated with the collection.
    *   设置与容器关联的用户自定义数据指针.
    *
    * @params
    *   aData  A pointer to the custom data.
    *          指向自定义数据的指针.
    *
    * @remark
    *   This property allows a user to associate arbitrary data with a collection instance.
    *   The collection itself does not manage or interpret this data.
    *   此属性允许用户将任意数据与容器实例关联. 容器本身不管理或解释此数据.
    *}
    procedure SetData(aData: Pointer);

    {**
    * Clear
    *
    * @desc
    *   Removes all elements from the collection.
    *   从容器中移除所有元素.
    *
    * @remark
    *   The specific behavior of `Clear` (e.g., whether memory is released) depends on the concrete collection implementation.
    *   `Clear` 的具体行为 (例如, 是否释放内存) 取决于具体的容器实现.
    *   Please refer to the documentation of the respective class for details.
    *   请参考相应类的文档以获取详细信息.
    *}
    procedure Clear;

    {**
    * SerializeToArrayBuffer
    *
    * @desc
    *   Serializes the collection's elements into a raw memory buffer.
    *   将容器中的元素序列化到原始内存缓冲区.
    *
    * @params
    *   aDst    A pointer to the destination memory buffer.
    *           指向目标内存缓冲区的指针.
    *
    *   aCount  The number of elements to serialize.
    *           要序列化的元素数量.
    *
    * @remark
    *   This operation serializes `aCount` elements starting from the beginning of the collection's logical sequence.
    *   **WARNING:** The caller must ensure the destination buffer is large enough to hold `aCount` elements to prevent buffer overflows.
    *   此操作从容器逻辑序列的起始位置开始序列化 `aCount` 个元素.
    *   **警告:** 调用者必须确保 `aDst` 指向的目标缓冲区足够大,以容纳 `aCount` 个元素, 以防止缓冲区溢出.
    *
    * @exceptions
    *   EArgumentNil      If `aDst` is `nil` and `aCount` > 0.
    *                     当 `aDst` 为 `nil` 且 `aCount` > 0 时抛出.
    *
    *   EInvalidArgument  If the source pointer overlaps with the container's memory range.
    *                     如果源指针与当前容器内存范围重叠.
    *
    *   EOutOfRange       If `aCount` is out of range.
    *                     如果 `aCount` 超出范围.
    *}
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);

    {**
    * Clone
    *
    * @desc
    *   Creates a new, deep copy of the collection.
    *   创建容器的一个新的深层副本.
    *
    * @return
    *   A new `TCollection` instance containing copies of the elements.
    *   一个包含元素副本的新的 `TCollection` 实例.
    *
    * @remark
    *   The new collection will share the same memory allocator and other configurations as the original.
    *   The "depth" of the clone (i.e., how elements that are pointers or interfaces are handled) depends on the concrete collection implementation.
    *   新容器将与原始容器共享相同的内存分配器和其他配置.
    *   克隆的"深度" (即如何处理作为指针或接口的元素) 取决于具体的容器实现.
    *}
    function Clone: TCollection;

    {**
    * IsCompatible
    *
    * @desc
    *   Checks if the current collection is compatible with a specified collection.
    *   检查当前容器是否兼容指定容器.
    *
    * @params
    *   aDst  The target collection.
    *         目标容器.
    *
    * @return
    *   Returns `True` if compatible, otherwise `False`.
    *   如果兼容, 则返回 `True`, 否则返回 `False`.
    *
    * @remark
    *   This method is used to check if the current collection is compatible with a specified type of collection.
    *   Descendants should override this for more specific checks (e.g., element type).
    *   此方法用于检查当前容器是否兼容指定类型的容器. 后代类应重写此方法以进行更具体的检查 (例如, 元素类型).
    *}
    function IsCompatible(aDst: TCollection): Boolean;

    {**
    * LoadFrom
    *
    * @desc
    *   Clears the current collection and loads elements from a raw memory buffer.
    *   清空当前容器, 并从原始内存缓冲区加载元素.
    *
    * @params
    *   aSrc           A pointer to the source memory buffer.
    *                  指向源内存缓冲区的指针.
    *
    *   aElementCount  The number of elements to load from the buffer.
    *                  要从缓冲区加载的元素数量.
    *
    * @remark
    *   The source buffer is expected to be an array in memory.
    *   If `aElementCount` is 0, this operation is treated as a `Clear`.
    *   源缓冲区为一块数组内存.
    *   如果 `aElementCount` 为 0, 此操作视作 `Clear`.
    *
    * @exceptions
    *   EArgumentNil      If `aSrc` is `nil`.
    *                     当 `aSrc` 为 `nil` 时抛出.
    *
    *   EInvalidArgument  If the source pointer overlaps with the container's memory range.
    *                     如果源指针与当前容器内存范围重叠.
    *
    *   EOutOfMemory      If memory allocation fails.
    *                     如果内存分配失败.
    *}
    procedure LoadFrom(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    {**
    * LoadFromUnChecked
    *
    * @desc
    *   Clears the current collection and loads elements from a raw memory buffer (fast, unchecked version).
    *   清空当前容器, 并从原始内存缓冲区加载元素(快速,无检查版本).
    *
    * @params
    *   aSrc           A pointer to the source memory buffer.
    *                  指向源内存缓冲区的指针.
    *
    *   aElementCount  The number of elements to load from the buffer.
    *                  要从缓冲区加载的元素数量.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   此过程不执行检查. 调用者必须自行保证安全.
    *
    * @exceptions
    *   EOutOfMemory  If memory allocation fails.
    *                 如果内存分配失败.
    *}
    procedure LoadFromUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    {**
    * Append
    *
    * @desc
    *   Appends a specified number of elements from a raw memory buffer to the end of the collection (by copying).
    *   从原始内存缓冲区将指定数量的元素追加到容器末尾(拷贝).
    *
    * @params
    *   aSrc           A pointer to the source memory buffer.
    *                  指向源内存缓冲区的指针.
    *
    *   aElementCount  The number of elements to append from the buffer.
    *                  要从缓冲区追加的元素数量.
    *
    * @remark
    *   This operation increases the size of the collection.
    *   If `aElementCount` is 0, this operation does nothing.
    *   Source memory must not overlap with container memory.
    *   此操作会增加容器的大小.
    *   如果 `aElementCount` 为 0, 此操作不执行任何动作.
    *   源内存不得与容器内存重叠.
    *
    * @exceptions
    *   EArgumentNil     If `aSrc` is `nil`.
    *                    如果源指针为 `nil`.
    *
    *   EInvalidArgument If source memory overlaps with container memory.
    *                    如果源内存与容器内存重叠.
    *
    *   EOutOfMemory     If memory allocation fails.
    *                    如果内存分配失败.
    *}
    procedure Append(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    {**
    * AppendUnChecked
    *
    * @desc
    *   Appends elements from a raw memory buffer (fast, unchecked version).
    *   从原始内存缓冲区追加元素(快速,无检查版本).
    *
    * @params
    *   aSrc           A pointer to the source memory buffer.
    *                  指向源内存缓冲区的指针.
    *
    *   aElementCount  The number of elements to append.
    *                  要追加的元素数量.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   Source memory must not overlap with container memory.
    *   此过程不执行任何检查. 调用者必须自行保证安全.
    *   源内存不得与容器内存重叠.
    *
    * @exceptions
    *   EOutOfRange  If the operation causes a range overflow.
    *                如果操作导致范围越界.
    *}
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    {**
    * LoadFrom
    *
    * @desc
    *   Clears the current collection and loads all elements from a source collection.
    *   清空当前容器, 并从源容器加载所有元素.
    *
    * @params
    *   aSrc  The source collection to load elements from.
    *         从中加载元素的源容器.
    *
    * @remark
    *   This operation clears the current collection before loading.
    *   If the source collection is empty, this is equivalent to `Clear`.
    *   此操作在加载前会先清空当前容器.
    *   如果源容器为空, 则此操作等同于 `Clear`.
    *
    * @exceptions
    *   EArgumentNil      If `aSrc` is `nil`.
    *                     如果源容器为 `nil`.
    *
    *   EInvalidOperation If `aSrc` is the same as the current instance.
    *                     如果源容器为自身.
    *
    *   ENotCompatible    If `aSrc` is not compatible with the current collection.
    *                     如果源容器与当前容器不兼容.
    *
    *   EOutOfMemory      If memory allocation fails.
    *                     如果内存分配失败.
    *}
    procedure LoadFrom(const aSrc: TCollection); overload;

    {**
    * LoadFromUnChecked
    *
    * @desc
    *   Clears the current collection and loads all elements from a source collection (fast, unchecked version).
    *   清空当前容器, 并从源容器加载所有元素(快速,无检查版本).
    *
    * @params
    *   aSrc  The source collection to load elements from.
    *         从中加载元素的源容器.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   此过程不执行任何检查. 调用者必须自行保证安全.
    *
    * @exceptions
    *   EOutOfMemory  If memory allocation fails.
    *                 如果内存分配失败.
    *}
    procedure LoadFromUnChecked(const aSrc: TCollection); overload;

    {**
    * SaveTo
    *
    * @desc
    *   Clears the destination collection and copies all elements from the current collection into it.
    *   清空目标容器, 并将当前容器的所有元素复制到其中.
    *
    * @params
    *   aDst  The destination collection.
    *         目标容器.
    *
    * @remark
    *   This operation clears the destination collection before copying.
    *   此操作在复制前会先清空目标容器.
    *
    * @exceptions
    *   EArgumentNil      If `aDst` is `nil`.
    *                     如果目标容器为 `nil`.
    *
    *   EInvalidOperation If `aDst` is the same as the current instance.
    *                     如果目标容器为自身.
    *
    *   ENotCompatible    If `aDst` is not compatible with the current collection.
    *                     如果目标容器与当前容器不兼容.
    *}
    procedure SaveTo(aDst: TCollection); overload;

    {**
    * SaveToUnChecked
    *
    * @desc
    *   Clears the destination collection and copies all elements into it (fast, unchecked version).
    *   清空目标容器, 并将所有元素复制到其中(快速,无检查版本).
    *
    * @params
    *   aDst  The destination collection.
    *         目标容器.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   此过程不执行任何检查. 调用者必须自行保证安全.
    *}
    procedure SaveToUnChecked(aDst: TCollection);

    {**
    * Append
    *
    * @desc
    *   Appends all elements from a source collection to the end of the current collection (by copying).
    *   将源容器的所有元素追加到当前容器的末尾(拷贝).
    *
    * @params
    *   aSrc  The source collection.
    *         源容器.
    *
    * @remark
    *   This operation increases the size of the collection.
    *   此操作会增加容器的大小.
    *
    * @exceptions
    *   EArgumentNil      If `aSrc` is `nil`.
    *                     如果源容器为 `nil`.
    *
    *   EInvalidOperation If `aSrc` is the same as the current instance.
    *                     如果源容器为自身.
    *
    *   ENotCompatible    If `aSrc` is not compatible with the current collection.
    *                     如果源容器与当前容器不兼容.
    *
    *   EOutOfMemory      If memory allocation fails.
    *                     如果内存分配失败.
    *}
    procedure Append(const aSrc: TCollection); overload;

    {**
    * AppendUnChecked
    *
    * @desc
    *   Appends all elements from a source collection (fast, unchecked version).
    *   将源容器的所有元素追加到当前容器(快速,无检查版本).
    *
    * @params
    *   aSrc  The source collection.
    *         源容器.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   此过程不执行任何检查. 调用者必须自行保证安全.
    *
    * @exceptions
    *   EOutOfMemory  If memory allocation fails.
    *                 如果内存分配失败.
    *}
    procedure AppendUnChecked(const aSrc: TCollection); overload;

    {**
    * AppendTo
    *
    * @desc
    *   Appends all elements from the current collection to the end of a destination collection (by copying).
    *   将当前容器的所有元素追加到目标容器的末尾(拷贝).
    *
    * @params
    *   aDst  The destination collection.
    *         目标容器.
    *
    * @remark
    *   This operation increases the size of the destination collection.
    *   此操作会增加目标容器的大小.
    *
    * @exceptions
    *   EArgumentNil      If `aDst` is `nil`.
    *                     如果目标容器为 `nil`.
    *
    *   EInvalidOperation If `aDst` is the same as the current instance.
    *                     如果目标容器为自身.
    *
    *   ENotCompatible    If `aDst` is not compatible with the current collection.
    *                     如果目标容器与当前容器不兼容.
    *
    *   EOutOfMemory      If memory allocation fails.
    *                     如果内存分配失败.
    *}
    procedure AppendTo(const aDst: TCollection); overload;

    {**
    * AppendToUnChecked
    *
    * @desc
    *   Appends all elements to a destination collection (fast, unchecked version).
    *   将所有元素追加到目标容器(快速,无检查版本).
    *
    * @params
    *   aDst  The destination collection.
    *         目标容器.
    *
    * @remark
    *   This procedure performs no checks. The caller must ensure safety.
    *   此过程不执行任何检查. 调用者必须自行保证安全.
    *
    * @exceptions
    *   EOutOfMemory  If memory allocation fails.
    *                 如果内存分配失败.
    *}
    procedure AppendToUnChecked(const aDst: TCollection); overload;

    property Count:     SizeUInt   read GetCount;
    property Data:      Pointer    read GetData write SetData;
    property Allocator: IAllocator read GetAllocator;

  end;


  { TCollection: 所有容器的基类. }
  TCollection = class(TInterfacedObject, ICollection)
  private
    FData:      Pointer;
  protected
    FAllocator: IAllocator;
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; virtual; abstract;
  public
    constructor Create; overload;
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create(aAllocator: IAllocator; aData: Pointer); virtual; overload;
    constructor Create(const aSrc: TCollection); overload;
    constructor Create(const aSrc: TCollection; aAllocator: IAllocator); overload;
    constructor Create(const aSrc: TCollection; aAllocator: IAllocator; aData: Pointer); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer); overload;

    function  PtrIter: TPtrIter; virtual; abstract;

    function  GetAllocator: IAllocator; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetCount: SizeUInt; virtual; abstract;
    function  IsEmpty: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetData: Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure SetData(aData: Pointer); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Clear; virtual; abstract;

    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); virtual; abstract;

    function  Clone: TCollection; virtual;
    function  IsCompatible(aDst: TCollection): Boolean; virtual;

    procedure LoadFrom(const aSrc: Pointer; aElementCount: SizeUInt); virtual; overload;
    procedure LoadFromUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); virtual; overload;
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; virtual; overload;
    procedure Append(const aSrc: Pointer; aElementCount: SizeUInt); virtual; overload;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); virtual; abstract; overload;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; virtual; overload;

    procedure LoadFrom(const aSrc: TCollection); overload;
    procedure LoadFromUnChecked(const aSrc: TCollection); virtual; overload;
    function  TryLoadFrom(const aSrc: TCollection): Boolean; overload;

    procedure Append(const aSrc: TCollection); overload;
    procedure AppendUnChecked(const aSrc: TCollection); virtual;
    function  TryAppend(const aSrc: TCollection): Boolean; overload;

    procedure AppendTo(const aDst: TCollection);
    procedure AppendToUnChecked(const aDst: TCollection); virtual; abstract;

    procedure SaveTo(aDst: TCollection); overload;
    procedure SaveToUnChecked(aDst: TCollection); virtual;

    //function Equals(Obj: TObject): Boolean; virtual;

    property  Count:     SizeUInt   read GetCount;
    property  Data:      Pointer    read GetData write SetData;
    property  Allocator: IAllocator read GetAllocator;
  end;

  TCollectionClass = class of TCollection;

  type

  { TIter<T> 泛型迭代器. }
  generic TIter<T> = record
  public
    PtrIter: TPtrIter;
  public
    procedure Init(const aIter: TPtrIter); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    function  GetStarted: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetCurrent: T; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  MoveNext: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  MovePrev: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure Reset; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    property  Current: T read GetCurrent;
  end;

  type

  { 算法回调函数 }


  { 泛型断言回调函数 }
  generic TPredicateFunc<T>    = function (const aElement: T; aData: Pointer): Boolean;
  generic TPredicateMethod<T>  = function (const aElement: T; aData: Pointer): Boolean of Object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TPredicateRefFunc<T> = reference to function (const aElement: T): Boolean;
  {$ENDIF}

  { 泛型映射回调函数 }
  generic TMapperFunc<T, U>    = function (const aElement: T; aData: Pointer): U;
  generic TMapperMethod<T, U>  = function (const aElement: T; aData: Pointer): U of Object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TMapperRefFunc<T, U> = reference to function (const aElement: T): U;
  {$ENDIF}

  { 泛型比较回调函数 }

  generic TCompareFunc<T>    = function (const aLeft, aRight: T; aData: Pointer): SizeInt;
  generic TCompareMethod<T>  = function (const aLeft, aRight: T; aData: Pointer): SizeInt of Object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TCompareRefFunc<T> = reference to function (const aLeft, aRight: T): SizeInt;
  {$ENDIF}

  { 泛型相等回调函数 }

  generic TEqualsFunc<T>    = function (const aLeft, aRight: T; aData: Pointer): Boolean;
  generic TEqualsMethod<T>  = function (const aLeft, aRight: T; aData: Pointer): Boolean of Object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  generic TEqualsRefFunc<T> = reference to function (const aLeft, aRight: T): Boolean;
  {$ENDIF}

  { IGenericCollection 泛型容器接口 }
  generic IGenericCollection<T> = interface(ICollection)
  ['{89825945-5184-4554-8618-465913072857}']

    function GetElementTypeInfo: PTypeInfo;

    {**
      * GetEnumerator
      *
      * @desc 获取容器的迭代器
      *
      * @return 迭代器
      *}
    function GetEnumerator: specialize TIter<T>;

    {**
      * Iter
      *
      * @desc 获取容器的开始迭代器
      *
      * @return 迭代器
      *}
    function Iter: specialize TIter<T>;

    {*
      * GetElementSize
      *
      * @desc 获取容器中元素的大小(字节)
      *
      * @return 元素大小
      *}
    function GetElementSize: SizeUInt;

    {**
    * GetIsManagedType
    *
    * @desc 判断容器中元素是否为托管类型
    *
    * @return 托管类型返回True,否则返回False
    *
    * @remark 托管类型包括 string、IInterface（接口）、以及包含托管字段的结构体等。
    *         容器会自动对托管类型进行初始化和释放，这可能带来一定的性能开销。
    *}
    function GetIsManagedType: Boolean;

    {**
     * GetElementManager
     *
     * @desc 获取元素管理器
     *
     * @return 元素管理器
     *
     * @remark 元素管理器用于在容器内部管理元素的内存分配和释放。
     *}
    function GetElementManager: specialize TElementManager<T>;

    {**
     * LoadFrom
     *
     * @desc 从指定数组加载元素到容器(拷贝)。
     *
     * @params
     *   aSrc 用于初始化的源数组
     *
     * @remark 此操作将重置容器大小，并从指定数组加载元素到容器
     *         如果源数组为空,则容器将清空
     *}
    procedure LoadFrom(const aSrc: array of T); overload;

    {**
     * Append
     *
     * @desc 从指定数组追加元素到容器(拷贝)
     *
     * @params
     *   aSrc 用于追加的源数组。
     *
     * @remark 此操作会扩充容器大小以包含追加的元素到尾部
     *         如果源数组为空,则什么都没发生,直接返回 True
     *}
    procedure Append(const aSrc: array of T); overload;

    {**
     * ToArray
     *
     * @desc 将容器内元素转换为数组(拷贝)
     *
     * @return 数组
     *
     * @remark 此操作会创建一个新的数组,并复制容器中的元素到新数组中
     *}
    function ToArray: specialize TGenericArray<T>;

    {
      容器算法
      所有算法都支持 `过程`/`对象方法`/`匿名引用函数` 三种版本.
    }

    { ForEach 容器遍历算法 }

    {**
     * ForEach
     *
     * @desc 遍历容器中的元素
     *
     * @params
     *   aPredicate 遍历函数回调
     *   aData      用户自定义数据
     *
     * @return 完整遍历返回 True,否则返回 False
     *
     * @remark
     *   此操作会遍历容器中的所有元素,并依次调用回调函数
     *   如果容器为空,则立即返回 True
     *   在回调函数中返回 False 时,遍历会立即停止,并返回 False 表示未完全遍历
     *   在回调函数中返回 True 时,遍历会继续,并返回 True 表示完全遍历
     *}
    function ForEach(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * ForEach
     *
     * @desc 遍历容器中的元素
     *
     * @params
     *   aForEach 遍历函数对象方法回调
     *   aData    用户自定义数据
     *
     * @return 完整遍历返回 True,否则返回 False
     *
     * @remark
     *   此操作会遍历容器中的所有元素,并依次调用回调函数
     *   如果容器为空,则立即返回 True
     *   在回调函数中返回 False 时,遍历会立即停止,并返回 False 表示未完全遍历
     *   在回调函数中返回 True 时,遍历会继续,并返回 True 表示完全遍历
     *}
    function ForEach(aForEach: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ForEach
     *
     * @desc 遍历容器中的元素(匿名引用函数版本)
     *
     * @params
     *   aPredicate 遍历函数回调
     *
     * @return 完整遍历返回 True,否则返回 False
     *
     * @remark
     *   此操作会遍历容器中的所有元素,并依次调用回调函数
     *   如果容器为空,则立即返回 True
     *   在回调函数中返回 False 时,遍历会立即停止,并返回 False 表示未完全遍历
     *   在回调函数中返回 True 时,遍历会继续,并返回 True 表示完全遍历
     *   使用此接口需要在 fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function ForEach(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}


    { Contains 容器包含查找算法 }


    {**
     * Contains
     *
     * @desc 检查容器中是否包含指定的元素(默认版本)
     *
     * @params
     *   aElement 要检查的元素值
     *
     * @return 如果包含返回 True 否则返回 False
     *
     * @remark
     *   此接口内部会根据元素类型自动选择合适的默认比较器（如数值比较、字符串比较或内存比较）
     *   对于自定义的 record 或 object 类型，若未提供自定义比较器，默认行为是进行内存比较，这可能不是预期的逻辑
     *   若需要自定义比较逻辑，请使用 Contains 方法的回调版本
     *   当容器为空时,立即返回 False
     *}
    function Contains(const aElement: T): Boolean; overload;

    {**
     * Contains
     *
     * @desc 检查容器中是否包含指定的元素(回调函数版本)
     *
     * @params
     *   aElement 要检查的元素值
     *   aEquals  相等回调函数
     *   aData    用户自定义数据
     *
     * @return 如果包含返回 True 否则返回 False
     *
     * @remark
     *   回调函数中应该遵守相等返回值规则:
     *    返回 True  表示相等
     *    返回 False 表示不相等
     *
     *   当容器为空时,立即返回 False
     *}
    function Contains(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;

    {**
     * Contains
     *
     * @desc 检查容器中是否包含指定的元素(对象方法版本)
     *
     * @params
     *   aElement 要检查的元素值
     *   aEquals  相等回调函数
     *   aData    用户自定义数据
     *
     * @return 如果包含返回 True 否则返回 False
     *
     * @remark
     *   回调函数中应该遵守相等返回值规则:
     *    返回 True  表示相等
     *    返回 False 表示不相等
     *
     *   当容器为空时,立即返回 False
     *}
    function Contains(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Contains
     *
     * @desc 检查容器中是否包含指定的元素(匿名引用函数版本)
     *
     * @params
     *   aElement  要检查的元素值
     *   aComparer 比较回调函数
     *   aData     用户自定义数据
     *
     * @return 如果包含返回 True 否则返回 False
     *
     * @remark
     *   回调函数中应该遵守相等返回值规则:
     *    返回 True  表示相等
     *    返回 False 表示不相等
     *
     *   当容器为空时,立即返回 False
     *   使用此接口需要在 fpc 3.3.1 及以上并且开启宏 FAFAFA_CORE_ANONYMOUS_REFERENCES
     *}
    function Contains(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    { CountOf 容器统计算法 }

    {**
     * CountOf
     *
     * @desc 计算容器中等于指定值的元素数量
     *}
    function CountOf(const aElement: T): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中等于指定值的元素数量
     *}
    function CountOf(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountOf
     *
     * @desc 计算容器中等于指定值的元素数量
     *}
    function CountOf(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountOf
     *
     * @desc 计算容器中等于指定值的元素数量
     *}
    function CountOf(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    { CountIF 容器统计算法 }

    {**
     * CountIF
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountIF
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountIF
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIF(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    {**
     * Fill
     *
     * @desc 填充容器中的元素
     *}
    procedure Fill(const aElement: T);

    {**
     * Zero
     *
     * @desc 将容器中的元素清零
     *}
    procedure Zero();



    {**
     * Replace
     *
     * @desc 替换容器中的元素
     *}
    procedure Replace(const aElement, aNewElement: T);

    {**
     * Replace
     *
     * @desc 替换容器中的元素
     *}
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer);

    {**
     * Replace
     *
     * @desc 替换容器中的元素
     *}
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer);

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * Replace
     *
     * @desc 替换容器中的元素
     *}
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsRefFunc<T>);
    {$ENDIF}


    {**
     * ReplaceIf
     *
     * @desc 替换容器中的元素
     *}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);

    {**
     * ReplaceIf
     *
     * @desc 替换容器中的元素
     *}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * ReplaceIf
     *
     * @desc 替换容器中的元素
     *}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateRefFunc<T>);
    {$ENDIF}


    {**
     * Reverse
     *
     * @desc 反转容器中的元素
     *}
    procedure Reverse;

    property Enumerator:      specialize TIter<T>           read GetEnumerator;
    property ElementSize:     SizeUInt                      read GetElementSize;
    property IsManagedType:   Boolean                       read GetIsManagedType;
    property ElementManager:  specialize TElementManager<T> read GetElementManager;
    property ElementTypeInfo: PTypeInfo                     read GetElementTypeInfo;

  end;

  { TGenericCollection 泛型容器基类 }

  generic TGenericCollection<T> = class(TCollection, specialize IGenericCollection<T>)

  type
    PElement        = ^T;
    TIter           = specialize TIter<T>;
    TElementManager = specialize TElementManager<T>;

    TEqualsFunc    = specialize TEqualsFunc<T>;
    TEqualsMethod  = specialize TEqualsMethod<T>;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    TEqualsRefFunc = specialize TEqualsRefFunc<T>;
    {$ENDIF}

    TPredicateFunc    = specialize TPredicateFunc<T>;
    TPredicateMethod  = specialize TPredicateMethod<T>;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    TPredicateRefFunc = specialize TPredicateRefFunc<T>;
    {$ENDIF}

    TCompareFunc      = specialize TCompareFunc<T>;
    TCompareMethod    = specialize TCompareMethod<T>;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    TCompareRefFunc   = specialize TCompareRefFunc<T>;
    {$ENDIF}

    TInternalEqualsMethod  = function (const aLeft, aRight: T): Boolean of object;
    TInternalCompareMethod = function (const aLeft, aRight: T): SizeInt of object;

  protected
    FElementManager:   TElementManager;
    FElementSizeCache: SizeUInt; // 元素大小缓存

  { Equals 内部相等回调 }
  protected
    FInternalEquals: TInternalEqualsMethod;
    function DoEqualsBool(const aLeft, aRight: Boolean): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsChar(const aLeft, aRight: Char): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsWChar(const aLeft, aRight: WideChar): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsI8(const aLeft, aRight: Int8): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsI16(const aLeft, aRight: Int16): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsI32(const aLeft, aRight: Int32): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsI64(const aLeft, aRight: Int64): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsU8(const aLeft, aRight: UInt8): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsU16(const aLeft, aRight: UInt16): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsU32(const aLeft, aRight: UInt32): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsU64(const aLeft, aRight: UInt64): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsSingle(const aLeft, aRight: Single): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsDouble(const aLeft, aRight: Double): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsExtended(const aLeft, aRight: Extended): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsCurrency(const aLeft, aRight: Currency): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsComp(const aLeft, aRight: Comp): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsShortString(const aLeft, aRight: ShortString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsAnsiString(const aLeft, aRight: AnsiString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsWideString(const aLeft, aRight: WideString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsUnicodeString(const aLeft: UnicodeString; const aRight: UnicodeString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsPointer(const aLeft, aRight: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsVariant(const aLeft, aRight: Variant): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsStr(const aLeft, aRight: String): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsMethod(const aLeft, aRight: TMethod): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsBin(const aLeft, aRight: T): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsDynArray(const aLeft, aRight: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    { compare 内部比较回调 }
  protected
    FInternalComparer: TInternalCompareMethod;
    function DoCompareBool(const aLeft, aRight: Boolean): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareChar(const aLeft, aRight: Char): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareWChar(const aLeft, aRight: WideChar): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareI8(const aLeft, aRight: Int8): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareI16(const aLeft, aRight: Int16): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareI32(const aLeft, aRight: Int32): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareI64(const aLeft, aRight: Int64): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareU8(const aLeft, aRight: UInt8): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareU16(const aLeft, aRight: UInt16): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareU32(const aLeft, aRight: UInt32): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareU64(const aLeft, aRight: UInt64): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareSingle(const aLeft, aRight: Single): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareDouble(const aLeft, aRight: Double): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareExtended(const aLeft, aRight: Extended): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareCurrency(const aLeft, aRight: Currency): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareComp(const aLeft, aRight: Comp): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareShortString(const aLeft, aRight: ShortString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareAnsiString(const aLeft, aRight: AnsiString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareWideString(const aLeft, aRight: WideString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareUnicodeString(const aLeft, aRight: UnicodeString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoComparePointer(const aLeft, aRight: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareVariant(const aLeft, aRight: Variant): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareStr(const aLeft, aRight: String): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareMethod(const aLeft, aRight: TMethod): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareBin(const aLeft, aRight: T): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareDynArray(const aLeft, aRight: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

  { Equals 代理 }
  type
    TEqualsProxyMethod = function (aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean of object;
  protected
    function DoEqualsDefaultProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsFuncProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoEqualsMethodProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoEqualsRefFuncProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
  { Compare 代理 }
  type
    TCompareProxyMethod = function (aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt of object;
  protected
    function DoCompareDefaultProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareFuncProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoCompareMethodProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoCompareRefFuncProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
  { Predicate 代理 }
  type
    TPredicateProxyMethod = function (aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean of object;
  protected
    function DoPredicateFuncProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoPredicateMethodProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoPredicateRefFuncProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

  { TRandomGeneratorProxyMethod }
  type
    TRandomGeneratorProxyMethod = function (aRandomGenerator: Pointer; aRange:Int64; aData: Pointer): Int64 of object;
  protected
    function DoRandomGeneratorDefaultProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoRandomGeneratorFuncProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoRandomGeneratorMethodProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoRandomGeneratorRefFuncProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
  protected
    function  DoForEach(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): Boolean; virtual;
    function  DoContains(aProxy: TEqualsProxyMethod;const aElement: T; aEquals, aData: Pointer): Boolean; virtual;
    function  DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): SizeUInt; virtual;
    function  DoCountIF(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt; virtual;
    procedure DoFill(const aElement: T); virtual;
    procedure DoZero(); virtual; abstract;
    procedure DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aEquals, aData: Pointer); virtual;
    procedure DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer); virtual;
    procedure DoReverse; virtual;abstract;

  public
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    constructor Create(const aSrc: array of T); overload;
    constructor Create(const aSrc: array of T; aAllocator: IAllocator); overload;
    constructor Create(const aSrc: array of T; aAllocator: IAllocator; aData: Pointer); overload;

    destructor  Destroy; override;

    { 迭代器相关 }

    function GetEnumerator: specialize TIter<T>; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function Iter: specialize TIter<T>; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    function GetElementSize: SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function GetIsManagedType: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function GetElementTypeInfo: PTypeInfo; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function GetElementManager: specialize TElementManager<T>; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    function  IsCompatible(aDst: TCollection): Boolean; override;
    procedure LoadFrom(const aSrc: array of T); overload;
    procedure Append(const aSrc: array of T); overload;

    function ToArray: specialize TGenericArray<T>; virtual;

    function ForEach(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function ForEach(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function ForEach(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function Contains(const aElement: T): Boolean; overload;
    function Contains(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Contains(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function CountOf(const aElement: T): SizeUInt; overload;
    function CountOf(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIF(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    procedure Fill(const aElement: T);
    procedure Zero();
    procedure Reverse;

    procedure Replace(const aElement, aNewElement: T);
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsRefFunc<T>);
    {$ENDIF}

    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateRefFunc<T>);
    {$ENDIF}

    property Enumerator:      specialize TIter<T>           read GetEnumerator;
    property ElementSize:     SizeUInt                      read GetElementSize;
    property IsManagedType:   Boolean                       read GetIsManagedType;
    property ElementManager:  specialize TElementManager<T> read GetElementManager;
    property ElementTypeInfo: PTypeInfo                     read GetElementTypeInfo;

  end;


  { IGrowthStrategy 增长策略接口 }
  IGrowthStrategy = interface
  ['{FC9AB81C-B79D-425C-A453-2137C359CF83}']
    function GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
  end;


  { TGrowthStrategy 增长策略基类 }
  TGrowthStrategy = class(TInterfacedObject, IGrowthStrategy)
  protected
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; virtual; abstract;
  public
    function GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; virtual;
  end;

  TGrowthStrategyClass = class of TGrowthStrategy;


  { 增长策略回调 }
  TGrowFunc    = function (aCurrentSize, aRequiredSize: SizeUInt; aData: Pointer): SizeUInt;
  TGrowMethod  = function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  TGrowRefFunc = reference to function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
  {$ENDIF}
  TGrowProxyMethod = function (aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;

  { TCustomGrowthStrategy 自定义回调增长策略 }
  TCustomGrowthStrategy = class(TGrowthStrategy)
  private
    FData:        Pointer;
    FGrowFunc:    TGrowFunc;
    FGrowMethod:  TGrowMethod;
    FGrowRefFunc: TGrowRefFunc;
    FGrowProxy:   TGrowProxyMethod;
    function GetData: Pointer; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoGetGrowSizeFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    function DoGetGrowSizeMethod(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function DoGetGrowSizeRefFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aGrowFunc: TGrowFunc; aData: Pointer);
    constructor Create(aGrowMethod: TGrowMethod; aData: Pointer);
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    constructor Create(aGrowRefFunc: TGrowRefFunc);
    {$ENDIF}

  strict protected
    property Data:     Pointer read GetData;
  end;

  { TCalcGrowStrategy 计算增长策略(这是个抽象类,不能直接使用) }
  TCalcGrowStrategy = class(TGrowthStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; virtual; abstract;
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
  end;

  { TDoublingGrowStrategy 指数增长 }
  TDoublingGrowStrategy = class(TCalcGrowStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  private
    class var FGlobal: TDoublingGrowStrategy;
    class destructor Destroy;
  public
    class function GetGlobal: TDoublingGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TFixedGrowStrategy 固定线性增长 }
  TFixedGrowStrategy = class(TCalcGrowStrategy)
  private
    FFixedSize: SizeUInt;
    function GetFixedSize: SizeUInt; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aFixedSize: SizeUInt);

    property FixedSize: SizeUInt read GetFixedSize;
  end;

  { TFactorGrowStrategy 因子增长 }
  TFactorGrowStrategy = class(TCalcGrowStrategy)
  private
    FFactor: Single;
    function GetFactor: Single; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  public
    constructor Create(aFactor: Single);

    property Factor: Single read GetFactor;
  end;

  { TPowerOfTwoGrowStrategy 最近的2次幂增长 }
  TPowerOfTwoGrowStrategy = class(TGrowthStrategy)
  private
    class var FGlobal: TPowerOfTwoGrowStrategy;
    class destructor Destroy;
  protected
    function DoGetGrowSize({%H-}aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    class function GetGlobal: TPowerOfTwoGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TGoldenRatioGrowStrategy 黄金比例增长 }
  TGoldenRatioGrowStrategy = class(TCalcGrowStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; override;
  private
    class var FGlobal: TGoldenRatioGrowStrategy;
    class destructor Destroy;
  public
    class function GetGlobal: TGoldenRatioGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

  { TAlignedWrapperStrategy 对齐包装增长策略 }
  TAlignedWrapperStrategy = class(TGrowthStrategy)
  private
    FGrowStrategy: IGrowthStrategy;
    FAlignSize: SizeUInt;

    function GetGrowStrategy: IGrowthStrategy;
    function GetAlignSize: SizeUInt;
  public
    const
      DEFAULT_ALIGN_SIZE    = 64;
  public
    constructor Create(const aGrowStrategy: IGrowthStrategy; aAlignSize: SizeUInt);
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;

    property GrowStrategy: IGrowthStrategy read GetGrowStrategy;
    property AlignSize: SizeUInt read GetAlignSize;
  end;

  { TExactGrowStrategy 精确增长策略 }


  type

  TExactGrowStrategy = class(TGrowthStrategy)
  private
    class var FGlobal: TExactGrowStrategy;
    class destructor Destroy;
  protected
    function DoGetGrowSize({%H-}aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    class function GetGlobal: TExactGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;


{ 内置相等函数 }

{ 工厂函数：返回常见增长策略的接口实例 }
function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

function equals_bool(const aLeft, aRight: Boolean): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_char(const aLeft, aRight: Char): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_wchar(const aLeft, aRight: WideChar): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_i8(const aLeft, aRight: Int8): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_i16(const aLeft, aRight: Int16): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_i32(const aLeft, aRight: Int32): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_i64(const aLeft, aRight: Int64): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_u8(const aLeft, aRight: UInt8): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_u16(const aLeft, aRight: UInt16): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_u32(const aLeft, aRight: UInt32): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_u64(const aLeft, aRight: UInt64): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_single(const aLeft, aRight: Single): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_double(const aLeft, aRight: Double): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_extended(const aLeft, aRight: Extended): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_currency(const aLeft, aRight: Currency): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_comp(const aLeft, aRight: Comp): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_shortstring(const aLeft, aRight: ShortString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_ansistring(const aLeft, aRight: AnsiString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_widestring(const aLeft, aRight: WideString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_unicodestring(const aLeft, aRight: UnicodeString): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_pointer(const aLeft, aRight: Pointer): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_bin(const aLeft, aRight: Pointer; aSize: SizeUInt): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_variant(const aLeft, aRight: Variant): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_string(const aLeft, aRight: string): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_method(const aLeft, aRight: TMethod): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function equals_dynarray(const aLeft, aRight: Pointer; aElementSize: SizeUInt): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

{ 内置比较函数 }
function compare_bool(const aLeft, aRight: Boolean): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_char(const aLeft, aRight: Char): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_wchar(const aLeft, aRight: WideChar): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_i8(const aLeft, aRight: Int8): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_i16(const aLeft, aRight: Int16): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_i32(const aLeft, aRight: Int32): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_i64(const aLeft, aRight: Int64): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_u8(const aLeft, aRight: UInt8): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_u16(const aLeft, aRight: UInt16): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_u32(const aLeft, aRight: UInt32): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_u64(const aLeft, aRight: UInt64): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_single(const aLeft, aRight: Single): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_double(const aLeft, aRight: Double): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_extended(const aLeft, aRight: Extended): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_currency(const aLeft, aRight: Currency): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_comp(const aLeft, aRight: Comp): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_shortstring(const aLeft, aRight: ShortString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_ansistring(const aLeft, aRight: AnsiString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_widestring(const aLeft, aRight: WideString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_unicodestring(const aLeft, aRight: UnicodeString): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_pointer(const aLeft, aRight: Pointer): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_bin(const aLeft, aRight: Pointer; aSize: SizeUInt): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_variant(const aLeft, aRight: Variant): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_string(const aLeft, aRight: string): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_method(const aLeft, aRight: TMethod): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
function compare_dynarray(const aLeft, aRight: Pointer; aElementSize: SizeUInt): SizeInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}


{ 检查 }
procedure CheckIndex(aIndex, aMax: SizeUInt; const aCallerName: string); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
procedure CheckBounds(aIndex, aCount, aMax: SizeUInt; const aCallerName: string); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}


implementation

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
begin
  Result := TFixedGrowStrategy.Create(aStep);
end;

function FactorGrow(aFactor: Double): IGrowthStrategy;
begin
  Result := TFactorGrowStrategy.Create(aFactor);
end;

function DoublingGrow: IGrowthStrategy;
begin
  Result := TDoublingGrowStrategy.Create;
end;


function ExactGrow: IGrowthStrategy;
begin
  Result := TExactGrowStrategy.Create;
end;

function GoldenRatioGrow: IGrowthStrategy;
begin
  Result := TGoldenRatioGrowStrategy.Create;
end;


function compare_bool(const aLeft, aRight: Boolean): SizeInt;
begin
  if aLeft = aRight then
    Result := 0
  else if aLeft then
    Result := 1
  else
    Result := -1;
end;

function compare_char(const aLeft, aRight: Char): SizeInt;
begin
  Result := compare_u8(Ord(aLeft), Ord(aRight));
end;

function compare_wchar(const aLeft, aRight: WideChar): SizeInt;
begin
  Result := compare_u16(Ord(aLeft), Ord(aRight));
end;

function compare_i8(const aLeft, aRight: Int8): SizeInt;
begin
  Result := aLeft - aRight;
end;

function compare_i16(const aLeft, aRight: Int16): SizeInt;
begin
  Result := aLeft - aRight;
end;

function compare_i32(const aLeft, aRight: Int32): SizeInt;
begin
  {$IFDEF CPU64}
  Result := aLeft - aRight;
  {$ELSE}
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
  {$ENDIF}
end;

function compare_i64(const aLeft, aRight: Int64): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_u8(const aLeft, aRight: UInt8): SizeInt;
begin
  Result := aLeft - aRight;
end;

function compare_u16(const aLeft, aRight: UInt16): SizeInt;
begin
  Result := aLeft - aRight;
end;

function compare_u32(const aLeft, aRight: UInt32): SizeInt;
begin
  {$IFDEF CPU64}
  Result := aLeft - aRight;
  {$ELSE}
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
  {$ENDIF}
end;

function compare_u64(const aLeft, aRight: UInt64): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_single(const aLeft, aRight: Single): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_double(const aLeft, aRight: Double): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_extended(const aLeft, aRight: Extended): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_currency(const aLeft, aRight: Currency): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_comp(const aLeft, aRight: Comp): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;


function compare_variant(const aLeft, aRight: Variant): SizeInt;
var
  LLeftString, LRightString: string;
begin
  try
    case VarCompareValue(aLeft, aRight) of
      vrGreaterThan:
        Exit(1);
      vrLessThan:
        Exit(-1);
      vrEqual:
        Exit(0);
      vrNotEqual:
        if VarIsEmpty(aLeft) or VarIsNull(aLeft) then
          Exit(1)
        else
          Exit(-1);
    end;
  except
    try
      LLeftString  := aLeft;
      LRightString := aRight;
      Result := CompareStr(LLeftString, LRightString);
    except
      Result := CompareMemRange(@aLeft, @aRight, SizeOf(System.Variant));
    end;
  end;
end;

function compare_string(const aLeft, aRight: string): SizeInt;
begin
  Result := CompareStr(aLeft, aRight);
end;

function compare_method(const aLeft, aRight: TMethod): SizeInt;
begin
  Result := CompareMemRange(@aLeft, @aRight, SizeOf(TMethod));
end;

function compare_dynarray(const aLeft, aRight: Pointer; aElementSize: SizeUInt): SizeInt;
var
  LLeftLen:  SizeInt;
  LRightLen: SizeInt;
  LLen:      SizeInt;
begin
  LLeftLen := DynArraySize(aLeft);
  LRightLen := DynArraySize(aRight);

  if LLeftLen > LRightLen then
    LLen := LRightLen
  else
    LLen := LLeftLen;

  Result := CompareMemRange(aLeft, aRight, LLen * aElementSize);

  if Result = 0 then
    Result := LLeftLen - LRightLen;
end;

procedure CheckIndex(aIndex, aMax: SizeUInt; const aCallerName: string);
begin
  if aIndex >= aMax then
    raise EOutOfRange.CreateFmt('%s: Index (%u) out of range [0..%u]', [aCallerName, aIndex, aMax - 1]);
end;

procedure CheckBounds(aIndex, aCount, aMax: SizeUInt; const aCallerName: string);
begin
  CheckIndex(aIndex, aMax, aCallerName);

  if aCount > (aMax - aIndex) then
    raise EOutOfRange.CreateFmt('%s:Bounds check failed. Count (%u) exceeds available length from index %u.', [aCallerName, aCount, aMax - aIndex - 1]);
end;

function compare_shortstring(const aLeft, aRight: ShortString): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_ansistring(const aLeft, aRight: AnsiString): SizeInt;
begin
  Result := AnsiCompareStr(aLeft, aRight);
end;

function compare_widestring(const aLeft, aRight: WideString): SizeInt;
begin
  Result := WideCompareStr(aLeft, aRight);
end;

function compare_unicodestring(const aLeft, aRight: UnicodeString): SizeInt;
begin
  Result := UnicodeCompareStr(aLeft, aRight);
end;

function compare_pointer(const aLeft, aRight: Pointer): SizeInt;
begin
  if aLeft > aRight then
    Result := 1
  else if aLeft < aRight then
    Result := -1
  else
    Result := 0;
end;

function compare_bin(const aLeft, aRight: Pointer; aSize: SizeUInt): SizeInt;
begin
  Result := CompareMemRange(aLeft, aRight, aSize);
end;

function equals_bool(const aLeft, aRight: Boolean): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_char(const aLeft, aRight: Char): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_wchar(const aLeft, aRight: WideChar): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_i8(const aLeft, aRight: Int8): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_i16(const aLeft, aRight: Int16): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_i32(const aLeft, aRight: Int32): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_i64(const aLeft, aRight: Int64): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_u8(const aLeft, aRight: UInt8): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_u16(const aLeft, aRight: UInt16): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_u32(const aLeft, aRight: UInt32): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_u64(const aLeft, aRight: UInt64): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_single(const aLeft, aRight: Single): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_double(const aLeft, aRight: Double): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_extended(const aLeft, aRight: Extended): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_currency(const aLeft, aRight: Currency): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_comp(const aLeft, aRight: Comp): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_shortstring(const aLeft, aRight: ShortString): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_ansistring(const aLeft, aRight: AnsiString): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_widestring(const aLeft, aRight: WideString): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_unicodestring(const aLeft, aRight: UnicodeString): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_pointer(const aLeft, aRight: Pointer): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_bin(const aLeft, aRight: Pointer; aSize: SizeUInt): Boolean;
begin
  Result := (compare_bin(aLeft, aRight, aSize) = 0);
end;

function equals_variant(const aLeft, aRight: Variant): Boolean;
begin
  Result := (VarCompareValue(aLeft, aRight) = vrEqual);
end;

function equals_string(const aLeft, aRight: string): Boolean;
begin
  Result := (aLeft = aRight);
end;

function equals_method(const aLeft, aRight: TMethod): Boolean;
begin
  Result := (aLeft.Code = aRight.Code) and (aLeft.Data = aRight.Data);
end;

function equals_dynarray(const aLeft, aRight: Pointer; aElementSize: SizeUInt): Boolean;
var
  LLen: SizeInt;
begin
  LLen := DynArraySize(aLeft);
  Result := (LLen = DynArraySize(aRight)) and (compare_bin(aLeft, aRight, LLen * aElementSize) = 0);
end;


procedure TPtrIter.Init(aOwner: TCollection; aGetCurrent: TPtrIterGetCurrentMethod; aMoveNext: TPtrIterMoveNextMethod; aMovePrev: TPtrIterMovePrevMethod; aData: Pointer);
begin
  if aOwner = nil then
    raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aOwner is nil');

  if aGetCurrent = nil then
    raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aGetCurrent is nil');

  if aMoveNext = nil then
    raise EArgumentNil.Create('TPtrIter.Init: Failed to init: aMoveNext is nil');

  Owner            := aOwner;
  Data             := aData;
  Started          := False;

  FGetCurrent      := aGetCurrent;
  FMoveNext        := aMoveNext;
  FMovePrev        := aMovePrev;
end;

procedure TPtrIter.Init(aOwner: TCollection; aGetCurrent: TPtrIterGetCurrentMethod; aMoveNext: TPtrIterMoveNextMethod; aData: Pointer);
begin
  Init(aOwner, aGetCurrent, aMoveNext, nil, aData);
end;

function TPtrIter.GetStarted: Boolean;
begin
  Result := Started;
end;

function TPtrIter.GetCurrent: Pointer;
begin
  Result := FGetCurrent(@Self);
end;

function TPtrIter.MoveNext: Boolean;
begin
  Result := FMoveNext(@Self);
end;

function TPtrIter.MovePrev: Boolean;
begin
  Result := FMovePrev <> nil;

  if Result then
    Result := FMovePrev(@Self);
end;

procedure TPtrIter.Reset;
begin
  Started := False;
end;



procedure TIter.Init(const aIter: TPtrIter);
begin
  PtrIter := aIter;
end;

function TIter.GetStarted: Boolean;
begin
  Result := PtrIter.Started;
end;

function TIter.GetCurrent: T;
var
  LPtr: Pointer;
begin
  LPtr := PtrIter.GetCurrent;
  if LPtr = nil then
    raise EInvalidOperation.Create('TIter.GetCurrent: 无效的迭代器位置');

  Result := T(LPtr^);
end;

function TIter.MoveNext: Boolean;
begin
  Result := PtrIter.MoveNext;
end;

function TIter.MovePrev: Boolean;
begin
  Result := PtrIter.MovePrev;
end;

procedure TIter.Reset;
begin
  PtrIter.Reset;
end;



constructor TCollection.Create;
begin
  Create(GetRtlAllocator());
end;

constructor TCollection.Create(aAllocator: IAllocator);
begin
  Create(aAllocator, nil);
end;

constructor TCollection.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create;
  FData := aData;

  if aAllocator = nil then
    FAllocator := GetRtlAllocator()
  else
    FAllocator := aAllocator;
end;

constructor TCollection.Create(const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.Create: aSrc is nil');

  Create(aSrc, aSrc.GetAllocator, aSrc.Data);
end;

constructor TCollection.Create(const aSrc: TCollection; aAllocator: IAllocator);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.Create: aSrc is nil');

  Create(aSrc, aAllocator, aSrc.Data);
end;

constructor TCollection.Create(const aSrc: TCollection; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  LoadFrom(aSrc);
end;

constructor TCollection.Create(aSrc: Pointer; aElementCount: SizeUInt);
begin
  Create(aSrc, aElementCount, GetRtlAllocator(), nil);
end;

constructor TCollection.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator);
begin
  Create(aSrc, aElementCount, aAllocator, nil);
end;

constructor TCollection.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  LoadFrom(aSrc, aElementCount);
end;

function TCollection.GetAllocator: IAllocator;
begin
  Result := FAllocator;
end;

function TCollection.IsEmpty: Boolean;
begin
  Result := GetCount = 0;
end;

function TCollection.GetData: Pointer;
begin
  Result := FData;
end;

procedure TCollection.SetData(aData: Pointer);
begin
  FData := aData;
end;

function TCollection.Clone: TCollection;
var
  LCollectionClass: TCollectionClass;
begin
  { 检查Self的有效性 }
  if Self = nil then
    raise EArgumentNil.Create('TCollection.Clone: Self is nil');

  { 检查ClassType的有效性 }
  if Self.ClassType = nil then
    raise EInvalidArgument.Create('TCollection.Clone: Self.ClassType is nil');

  { 安全的类型转换 }
  try
    LCollectionClass := TCollectionClass(Self.ClassType);
  except
    on E: Exception do
      raise EInvalidArgument.CreateFmt('TCollection.Clone: Invalid class type conversion: %s', [E.Message]);
  end;

  { 创建克隆对象，构造函数内部会处理异常 }
  try
    Result := LCollectionClass.Create(Self);
  except
    on E: Exception do
    begin
      Result := nil;
      raise EInvalidArgument.CreateFmt('TCollection.Clone: Failed to create clone: %s', [E.Message]);
    end;
  end;
end;

function TCollection.IsCompatible(aDst: TCollection): Boolean;
begin
  Result := (aDst is TCollection);
end;

procedure TCollection.LoadFrom(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aSrc is nil');

  if IsOverlap(aSrc, aElementCount) then
    raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aSrc overlaps with current container');

  if aElementCount = 0 then
  begin
    Clear;
    exit;
  end;

  LoadFromUnChecked(aSrc, aElementCount);
end;

procedure TCollection.LoadFromUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  Clear;
  AppendUnChecked(aSrc, aElementCount);
end;


function TCollection.TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  { 非异常版本：非法参数/重叠/溢出/内存失败均返回 False }
  Result := False;
  if (aSrc = nil) and (aElementCount > 0) then Exit;
  if aElementCount = 0 then
  begin
    Clear;
    Result := True;
    Exit;
  end;
  if IsOverlap(aSrc, aElementCount) then Exit;
  try
    LoadFromUnChecked(aSrc, aElementCount);
    Result := True;
  except
    Result := False;
  end;
end;

function TCollection.TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  { 非异常版本：非法参数/重叠/溢出/内存失败均返回 False }
  Result := False;
  if aElementCount = 0 then
  begin
    Result := True;
    Exit;
  end;
  if aSrc = nil then Exit;
  if IsAddOverflow(GetCount, aElementCount) then Exit;
  if IsOverlap(aSrc, aElementCount) then Exit;
  try
    AppendUnChecked(aSrc, aElementCount);
    Result := True;
  except
    Result := False;
  end;
end;



procedure TCollection.Append(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    Exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.Append: Failed to append: aSrc is nil');

  if IsAddOverflow(GetCount, aElementCount) then
    raise EOverflow.Create('TCollection.Append: Failed to append: aElementCount is too large(Overflow)');

  // 检测内存重叠：不允许从容器内部内存追加
  if IsOverlap(aSrc, aElementCount) then
    raise EInvalidArgument.Create('TCollection.Append: source memory overlaps with container memory');

  AppendUnChecked(aSrc, aElementCount);
end;

procedure TCollection.LoadFrom(const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.LoadFrom: Failed to load: aCollection is nil');

  if aSrc = Self then
    raise EInvalidArgument.Create('TCollection.LoadFrom: Failed to load: aCollection is self');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TCollection.LoadFrom: Failed to load: aCollection is not compatible');

  { 空操作检查：如果源集合为空，只需清空当前集合 }
  if aSrc.GetCount = 0 then
  begin
    Clear;
    exit;
  end;

  LoadFromUnChecked(aSrc);
end;

procedure TCollection.LoadFromUnChecked(const aSrc: TCollection);
begin
  aSrc.SaveToUnChecked(Self);
end;

procedure TCollection.Append(const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TCollection.Append: Failed to append: aCollection is nil');

  if aSrc = Self then
    raise EInvalidArgument.Create('TCollection.Append: Failed to append: aCollection is self');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TCollection.Append: Failed to append: aCollection is not compatible');

  { 空操作检查：如果源集合为空，直接返回 }
  if aSrc.IsEmpty then
    exit;

  if IsAddOverflow(GetCount, aSrc.GetCount) then
    raise EOverflow.Create('TCollection.Append: Failed to append: aCollection is too large(Overflow)');

  AppendUnChecked(aSrc);
end;

procedure TCollection.AppendUnChecked(const aSrc: TCollection);
begin
  if aSrc.IsEmpty then
    exit;

  aSrc.AppendToUnChecked(Self);
end;

procedure TCollection.AppendTo(const aDst: TCollection);
begin
  if aDst = nil then
    raise EArgumentNil.Create('TCollection.AppendTo: Failed to append: aCollection is nil');

  if not IsCompatible(aDst) then
    raise ENotCompatible.Create('TCollection.AppendTo: Failed to append: aCollection is not compatible');

  AppendToUnChecked(aDst);
end;

procedure TCollection.SaveTo(aDst: TCollection);
begin
  if aDst = nil then
    raise EArgumentNil.Create('TCollection.SaveTo: Failed to save: aCollection is nil');

  if aDst = Self then
    raise EInvalidArgument.Create('TCollection.SaveTo: Failed to save: aCollection is self');

  if not IsCompatible(aDst) then
    raise ENotCompatible.Create('TCollection.SaveTo: Failed to save: aCollection is not compatible');

  SaveToUnChecked(aDst);
end;

procedure TCollection.SaveToUnChecked(aDst: TCollection);
begin
  aDst.Clear;

  if IsEmpty then
    exit;

  aDst.AppendUnChecked(Self);
end;


function TGenericCollection.DoForEach(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): Boolean;
var
  LIter: TIter;
begin
  LIter := Iter;

  while LIter.MoveNext do
  begin
    if not aProxy(aPredicate, LIter.GetCurrent, aData) then
      Exit(False);
  end;
  Result := True;
end;


function TCollection.TryLoadFrom(const aSrc: TCollection): Boolean;
begin
  { 非异常版本：非法参数/不兼容/自赋值 → False；空源 → 清空并 True }
  Result := False;
  if aSrc = nil then Exit;
  if aSrc = Self then Exit;
  if not IsCompatible(aSrc) then Exit;
  if aSrc.GetCount = 0 then
  begin
    Clear;
    Result := True;
    Exit;
  end;
  try
    LoadFromUnChecked(aSrc);
    Result := True;
  except
    Result := False;
  end;
end;

function TCollection.TryAppend(const aSrc: TCollection): Boolean;
begin
  { 非异常版本：非法参数/不兼容/自赋值/溢出 → False；空源 → True }
  Result := False;
  if aSrc = nil then Exit;
  if aSrc = Self then Exit;
  if not IsCompatible(aSrc) then Exit;
  if aSrc.IsEmpty then
  begin
    Result := True;
    Exit;
  end;
  if IsAddOverflow(GetCount, aSrc.GetCount) then Exit;
  try
    AppendUnChecked(aSrc);
    Result := True;
  except
    Result := False;
  end;
end;





function TGenericCollection.DoEqualsBool(const aLeft, aRight: Boolean): Boolean;
begin
  Result := equals_bool(aLeft, aRight);
end;

function TGenericCollection.DoEqualsChar(const aLeft, aRight: Char): Boolean;
begin
  Result := equals_char(aLeft, aRight);
end;

function TGenericCollection.DoEqualsWChar(const aLeft, aRight: WideChar): Boolean;
begin
  Result := equals_wchar(aLeft, aRight);
end;

function TGenericCollection.DoEqualsI8(const aLeft, aRight: Int8): Boolean;
begin
  Result := equals_i8(aLeft, aRight);
end;

function TGenericCollection.DoEqualsI16(const aLeft, aRight: Int16): Boolean;
begin
  Result := equals_i16(aLeft, aRight);
end;

function TGenericCollection.DoEqualsI32(const aLeft, aRight: Int32): Boolean;
begin
  Result := equals_i32(aLeft, aRight);
end;

function TGenericCollection.DoEqualsI64(const aLeft, aRight: Int64): Boolean;
begin
  Result := equals_i64(aLeft, aRight);
end;

function TGenericCollection.DoEqualsU8(const aLeft, aRight: UInt8): Boolean;
begin
  Result := equals_u8(aLeft, aRight);
end;

function TGenericCollection.DoEqualsU16(const aLeft, aRight: UInt16): Boolean;
begin
  Result := equals_u16(aLeft, aRight);
end;

function TGenericCollection.DoEqualsU32(const aLeft, aRight: UInt32): Boolean;
begin
  Result := equals_u32(aLeft, aRight);
end;

function TGenericCollection.DoEqualsU64(const aLeft, aRight: UInt64): Boolean;
begin
  Result := equals_u64(aLeft, aRight);
end;

function TGenericCollection.DoEqualsSingle(const aLeft, aRight: Single): Boolean;
begin
  Result := equals_single(aLeft, aRight);
end;

function TGenericCollection.DoEqualsDouble(const aLeft, aRight: Double): Boolean;
begin
  Result := equals_double(aLeft, aRight);
end;

function TGenericCollection.DoEqualsExtended(const aLeft, aRight: Extended): Boolean;
begin
  Result := equals_extended(aLeft, aRight);
end;

function TGenericCollection.DoEqualsCurrency(const aLeft, aRight: Currency): Boolean;
begin
  Result := equals_currency(aLeft, aRight);
end;

function TGenericCollection.DoEqualsComp(const aLeft, aRight: Comp): Boolean;
begin
  Result := equals_comp(aLeft, aRight);
end;

function TGenericCollection.DoEqualsShortString(const aLeft, aRight: ShortString): Boolean;
begin
  Result := equals_shortstring(aLeft, aRight);
end;

function TGenericCollection.DoEqualsAnsiString(const aLeft, aRight: AnsiString): Boolean;
begin
  Result := equals_ansistring(aLeft, aRight);
end;

function TGenericCollection.DoEqualsWideString(const aLeft, aRight: WideString): Boolean;
begin
  Result := equals_widestring(aLeft, aRight);
end;

function TGenericCollection.DoEqualsUnicodeString(const aLeft: UnicodeString; const aRight: UnicodeString): Boolean;
begin
  Result := equals_unicodestring(aLeft, aRight);
end;

function TGenericCollection.DoEqualsPointer(const aLeft, aRight: Pointer): Boolean;
begin
  Result := equals_pointer(aLeft, aRight);
end;

function TGenericCollection.DoEqualsVariant(const aLeft, aRight: Variant): Boolean;
begin
  Result := equals_variant(aLeft, aRight);
end;

function TGenericCollection.DoEqualsStr(const aLeft, aRight: String): Boolean;
begin
  Result := equals_string(aLeft, aRight);
end;

function TGenericCollection.DoEqualsMethod(const aLeft, aRight: TMethod): Boolean;
begin
  Result := equals_method(aLeft, aRight);
end;

function TGenericCollection.DoEqualsBin(const aLeft, aRight: T): Boolean;
begin
  Result := equals_bin(@aLeft, @aRight, FElementSizeCache);
end;

function TGenericCollection.DoEqualsDynArray(const aLeft, aRight: Pointer): Boolean;
begin
  Result := equals_dynarray(aLeft, aRight, FElementSizeCache);
end;

function TGenericCollection.DoContains(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): Boolean;
var
  LIter: TIter;
begin
  LIter := Iter;

  while LIter.MoveNext do
  begin
    if aProxy(aEquals, aElement, LIter.GetCurrent, aData) then
      Exit(True);
  end;

  Result := False;
end;

function TGenericCollection.DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): SizeUInt;
var
  LIter: TIter;
begin
  LIter  := Iter;
  Result := 0;

  while LIter.MoveNext do
  begin
    if aProxy(aEquals, aElement, LIter.GetCurrent, aData) then
      Inc(Result);
  end;
end;

function TGenericCollection.DoCountIF(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt;
var
  LIter: TIter;
begin
  LIter  := Iter;
  Result := 0;

  while LIter.MoveNext do
  begin
    if aProxy(aPredicate, LIter.GetCurrent, aData) then
      Inc(Result);
  end;
end;

procedure TGenericCollection.DoFill(const aElement: T);
var
  LIter: TPtrIter;
  LP:    PElement;
begin
  LIter := PtrIter();

  while LIter.MoveNext do
  begin
    LP  := LIter.GetCurrent;
    LP^ := aElement;
  end;
end;

procedure TGenericCollection.DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aEquals, aData: Pointer);
var
  LIter: TPtrIter;
  LP:    PElement;
begin
  LIter := PtrIter();

  while LIter.MoveNext do
  begin
    LP  := LIter.GetCurrent;

    if aProxy(aEquals, aElement, LP^, aData) then
      LP^ := aNewElement;
  end;
end;

procedure TGenericCollection.DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer);
var
  LIter: TPtrIter;
  LP:    PElement;
begin
  LIter := PtrIter();

  while LIter.MoveNext do
  begin
    LP  := LIter.GetCurrent;

    if aProxy(aPredicate, LP^, aData) then
      LP^ := aNewElement;
  end;
end;

function TGenericCollection.DoCompareBool(const aLeft, aRight: Boolean): SizeInt;
begin
  Result := compare_bool(aLeft, aRight);
end;

function TGenericCollection.DoCompareChar(const aLeft, aRight: Char): SizeInt;
begin
  Result := compare_char(aLeft, aRight);
end;

function TGenericCollection.DoCompareWChar(const aLeft, aRight: WideChar): SizeInt;
begin
  Result := compare_wchar(aLeft, aRight);
end;

function TGenericCollection.DoCompareI8(const aLeft, aRight: Int8): SizeInt;
begin
  Result := compare_i8(aLeft, aRight);
end;

function TGenericCollection.DoCompareI16(const aLeft, aRight: Int16): SizeInt;
begin
  Result := compare_i16(aLeft, aRight);
end;

function TGenericCollection.DoCompareI32(const aLeft, aRight: Int32): SizeInt;
begin
  Result := compare_i32(aLeft, aRight);
end;

function TGenericCollection.DoCompareI64(const aLeft, aRight: Int64): SizeInt;
begin
  Result := compare_i64(aLeft, aRight);
end;

function TGenericCollection.DoCompareU8(const aLeft, aRight: UInt8): SizeInt;
begin
  Result := compare_u8(aLeft, aRight);
end;

function TGenericCollection.DoCompareU16(const aLeft, aRight: UInt16): SizeInt;
begin
  Result := compare_u16(aLeft, aRight);
end;

function TGenericCollection.DoCompareU32(const aLeft, aRight: UInt32): SizeInt;
begin
  Result := compare_u32(aLeft, aRight);
end;

function TGenericCollection.DoCompareU64(const aLeft, aRight: UInt64): SizeInt;
begin
  Result := compare_u64(aLeft, aRight);
end;

function TGenericCollection.DoCompareSingle(const aLeft, aRight: Single): SizeInt;
begin
  Result := compare_single(aLeft, aRight);
end;

function TGenericCollection.DoCompareDouble(const aLeft, aRight: Double): SizeInt;
begin
  Result := compare_double(aLeft, aRight);
end;

function TGenericCollection.DoCompareExtended(const aLeft, aRight: Extended): SizeInt;
begin
  Result := compare_extended(aLeft, aRight);
end;

function TGenericCollection.DoCompareCurrency(const aLeft, aRight: Currency): SizeInt;
begin
  Result := compare_currency(aLeft, aRight);
end;

function TGenericCollection.DoCompareComp(const aLeft, aRight: Comp): SizeInt;
begin
  Result := compare_comp(aLeft, aRight);
end;

function TGenericCollection.DoCompareShortString(const aLeft, aRight: ShortString): SizeInt;
begin
  Result := compare_shortstring(aLeft, aRight);
end;

function TGenericCollection.DoCompareAnsiString(const aLeft, aRight: AnsiString): SizeInt;
begin
  Result := compare_ansistring(aLeft, aRight);
end;

function TGenericCollection.DoCompareWideString(const aLeft, aRight: WideString): SizeInt;
begin
  Result := compare_widestring(aLeft, aRight);
end;

function TGenericCollection.DoCompareUnicodeString(const aLeft, aRight: UnicodeString): SizeInt;
begin
  Result := compare_unicodestring(aLeft, aRight);
end;

function TGenericCollection.DoComparePointer(const aLeft, aRight: Pointer): SizeInt;
begin
  Result := compare_pointer(aLeft, aRight);
end;

function TGenericCollection.DoCompareVariant(const aLeft, aRight: Variant): SizeInt;
begin
  Result := compare_variant(aLeft, aRight);
end;

function TGenericCollection.DoCompareStr(const aLeft, aRight: String): SizeInt;
begin
  Result := compare_string(aLeft, aRight);
end;

function TGenericCollection.DoCompareMethod(const aLeft, aRight: TMethod): SizeInt;
begin
  Result := compare_method(aLeft, aRight);
end;

function TGenericCollection.DoCompareBin(const aLeft, aRight: T): SizeInt;
begin
  Result := compare_bin(@aLeft, @aRight, FElementSizeCache);
end;

function TGenericCollection.DoCompareDynArray(const aLeft, aRight: Pointer): SizeInt;
begin
  Result := compare_dynarray(aLeft, aRight, FElementSizeCache);
end;

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoEqualsDefaultProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean;
begin
  Result := FInternalEquals(aLeft, aRight);
end;
{$POP}

function TGenericCollection.DoEqualsFuncProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean;
begin
  Result := TEqualsFunc(aEquals^)(aLeft, aRight, aData);
end;

function TGenericCollection.DoEqualsMethodProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean;
begin
  Result := TEqualsMethod(aEquals^)(aLeft, aRight, aData);
end;

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoEqualsRefFuncProxy(aEquals: Pointer; const aLeft, aRight: T; aData: Pointer): Boolean;
begin
  Result := TEqualsRefFunc(aEquals^)(aLeft, aRight);
end;
{$POP}

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoCompareDefaultProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt;
begin
  Result := FInternalComparer(aLeft, aRight);
end;
{$POP}

function TGenericCollection.DoCompareFuncProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt;
begin
  Result := TCompareFunc(aCompare^)(aLeft, aRight, aData);
end;

function TGenericCollection.DoCompareMethodProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt;
begin
  Result := TCompareMethod(aCompare^)(aLeft, aRight, aData);
end;

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoCompareRefFuncProxy(aCompare: Pointer; const aLeft, aRight: T; aData: Pointer): SizeInt;
begin
  Result := TCompareRefFunc(aCompare^)(aLeft, aRight);
end;
{$POP}

function TGenericCollection.DoPredicateFuncProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean;
begin
  Result := TPredicateFunc(aPredicate^)(aElement, aData);
end;

function TGenericCollection.DoPredicateMethodProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean;
begin
  Result := TPredicateMethod(aPredicate^)(aElement, aData);
end;

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoPredicateRefFuncProxy(aPredicate: Pointer; const aElement: T; aData: Pointer): Boolean;
begin
  Result := TPredicateRefFunc(aPredicate^)(aElement);
end;
{$POP}

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoRandomGeneratorDefaultProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64;
begin
  Result := System.Random(aRange);
end;
{$POP}

function TGenericCollection.DoRandomGeneratorFuncProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64;
begin
  Result := TRandomGeneratorFunc(aRandomGenerator^)(aRange, aData);
end;

function TGenericCollection.DoRandomGeneratorMethodProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64;
begin
  Result := TRandomGeneratorMethod(aRandomGenerator^)(aRange, aData);
end;

{$PUSH}{$HINTS OFF}
function TGenericCollection.DoRandomGeneratorRefFuncProxy(aRandomGenerator: Pointer; aRange: Int64; aData: Pointer): Int64;
begin
  Result := TRandomGeneratorRefFunc(aRandomGenerator^)(aRange);
end;
{$POP}


constructor TGenericCollection.Create(aAllocator: IAllocator; aData: Pointer);
var
  LTypeInfo: PTypeInfo;
begin
  inherited Create(aAllocator, aData);
  FElementManager := TElementManager.Create(FAllocator);
  FElementSizeCache := FElementManager.GetElementSize;

  LTypeInfo := GetElementTypeInfo();

    case LTypeInfo^.Kind of
    tkBool:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareBool);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsBool);
    end;
    tkChar:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareChar);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsChar);
    end;
    tkWChar:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareWChar);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsWChar);
    end;
    tkInteger:
    begin
      if LTypeInfo = system.typeinfo(Int8) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI8);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI8);
      end
      else if LTypeInfo = system.typeinfo(Int16) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI16);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI16);
      end
      else if LTypeInfo = system.typeinfo(Int32) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI32);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI32);
      end
      else if LTypeInfo = system.typeinfo(UInt8) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU8);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU8);
      end
      else if LTypeInfo = system.typeinfo(UInt16) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU16);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU16);
      end
      else if LTypeInfo = system.typeinfo(UInt32) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU32);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU32);
      end
    end;
    tkInt64:
    begin
      if LTypeInfo = system.typeinfo(Int64) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI64);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI64);
      end
      else if LTypeInfo = system.typeinfo(Comp) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareComp);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsComp);
      end;
    end;
    tkQWord:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareU64);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsU64);
    end;
    tkFloat:
    begin
      if LTypeInfo = system.typeinfo(Single) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareSingle);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsSingle);
      end
      else if LTypeInfo = system.typeinfo(Double) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareDouble);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsDouble);
      end
      else if LTypeInfo = system.typeinfo(Extended) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareExtended);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsExtended);
      end
      else if LTypeInfo = system.typeinfo(Currency) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareCurrency);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsCurrency);
      end;
    end;
    tkSString:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareShortString);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsShortString);
    end;
    tkLString,tkAString:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareAnsiString);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsAnsiString);
    end;
    tkUString:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareUnicodeString);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsUnicodeString);
    end;
    tkWString:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareWideString);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsWideString);
    end;
    tkVariant:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareVariant);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsVariant);
    end;
    tkMethod:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareMethod);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsMethod);
    end;
    tkPointer:
    begin
      FInternalComparer := TInternalCompareMethod(@DoComparePointer);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsPointer);
    end;
    tkDynArray:
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareDynArray);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsDynArray);
    end;
    else
    begin
      FInternalComparer := TInternalCompareMethod(@DoCompareBin);
      FInternalEquals   := TInternalEqualsMethod(@DoEqualsBin);
    end;
  end;

end;

constructor TGenericCollection.Create(const aSrc: array of T);
begin
  Create(aSrc, GetRtlAllocator(), nil);
end;

constructor TGenericCollection.Create(const aSrc: array of T; aAllocator: IAllocator);
begin
  Create(aSrc, aAllocator, nil);
end;

constructor TGenericCollection.Create(const aSrc: array of T; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  LoadFrom(aSrc);
end;

destructor TGenericCollection.Destroy;
begin
  FElementManager.Free;
  inherited Destroy;
end;

function TGenericCollection.GetEnumerator: specialize TIter<T>;
begin
  Result := Iter();
end;

function TGenericCollection.Iter: specialize TIter<T>;
begin
  Result.Init(PtrIter());
end;

function TGenericCollection.GetElementSize: SizeUInt;
begin
  Result := FElementSizeCache;
end;

function TGenericCollection.GetIsManagedType: Boolean;
begin
  Result := FElementManager.IsManagedType;
end;

function TGenericCollection.GetElementTypeInfo: PTypeInfo;
begin
  Result := FElementManager.ElementTypeInfo;
end;

function TGenericCollection.GetElementManager: specialize TElementManager<T>;
begin
  Result := FElementManager;
end;

function TGenericCollection.IsCompatible(aDst: TCollection): Boolean;
begin
  Result := (aDst is TGenericCollection);
end;

procedure TGenericCollection.LoadFrom(const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
  begin
    Clear;
    Exit;
  end;

  LoadFrom(@aSrc[0], LLen);
end;

procedure TGenericCollection.Append(const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;

  Append(@aSrc[0], LLen);
end;

function TGenericCollection.ToArray: specialize TGenericArray<T>;
var
  LCount: SizeUInt;
begin
  LCount := GetCount;
  {$PUSH}{$WARN 5093 OFF}
  SetLength(Result, LCount);
  {$POP}

  if LCount > 0 then
  begin
    SerializeToArrayBuffer(@Result[0], LCount);
  end;
end;

function TGenericCollection.ForEach(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if GetCount = 0 then
    Exit(True);

  Result := DoForEach(@DoPredicateFuncProxy, @aPredicate, aData);
end;

function TGenericCollection.ForEach(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if GetCount = 0 then
    Exit(True);

  Result := DoForEach(@DoPredicateMethodProxy, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TGenericCollection.ForEach(aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if GetCount = 0 then
    Exit(True);

  Result := DoForEach(@DoPredicateRefFuncProxy, @aPredicate, nil);
end;
{$ENDIF}

function TGenericCollection.Contains(const aElement: T): Boolean;
begin
  if GetCount = 0 then
    Exit(False);

  Result := DoContains(@DoEqualsDefaultProxy, aElement, nil, nil);
end;

function TGenericCollection.Contains(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if GetCount = 0 then
    Exit(False);

  Result := DoContains(@DoEqualsFuncProxy, aElement, @aEquals, aData);
end;

function TGenericCollection.Contains(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if GetCount = 0 then
    Exit(False);

  Result := DoContains(@DoEqualsMethodProxy, aElement, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TGenericCollection.Contains(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if GetCount = 0 then
    Exit(False);

  Result := DoContains(@DoEqualsRefFuncProxy, aElement, @aEquals, nil);
end;
{$ENDIF}

function TGenericCollection.CountOf(const aElement: T): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountOf(@DoEqualsDefaultProxy, aElement, nil, nil);
end;

function TGenericCollection.CountOf(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountOf(@DoEqualsFuncProxy, aElement, @aEquals, aData);
end;

function TGenericCollection.CountOf(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountOf(@DoEqualsMethodProxy, aElement, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TGenericCollection.CountOf(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountOf(@DoEqualsRefFuncProxy, aElement, @aEquals, nil);
end;
{$ENDIF}

function TGenericCollection.CountIF(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIF(@DoPredicateFuncProxy, @aPredicate, aData);
end;

function TGenericCollection.CountIF(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIF(@DoPredicateMethodProxy, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TGenericCollection.CountIF(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIF(@DoPredicateRefFuncProxy, @aPredicate, nil);
end;
{$ENDIF}

procedure TGenericCollection.Fill(const aElement: T);
begin
  if GetCount = 0 then
    exit;

  DoFill(aElement);
end;

procedure TGenericCollection.Zero();
begin
  if GetCount = 0 then
    exit;

  DoZero;
end;

procedure TGenericCollection.Reverse;
begin
  if GetCount < 2 then
    exit;

  DoReverse;
end;

procedure TGenericCollection.Replace(const aElement, aNewElement: T);
begin
  if GetCount = 0 then
    exit;

  DoReplace(@DoEqualsDefaultProxy, aElement, aNewElement, nil, nil);
end;

procedure TGenericCollection.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if GetCount = 0 then
    exit;

  DoReplace(@DoEqualsFuncProxy, aElement, aNewElement, @aEquals, aData);
end;

procedure TGenericCollection.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if GetCount = 0 then
    exit;

  DoReplace(@DoEqualsMethodProxy, aElement, aNewElement, @aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TGenericCollection.Replace(const aElement, aNewElement: T; aEquals: specialize TEqualsRefFunc<T>);
begin
  if GetCount = 0 then
    exit;

  DoReplace(@DoEqualsRefFuncProxy, aElement, aNewElement, @aEquals, nil);
end;
{$ENDIF}

procedure TGenericCollection.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if GetCount = 0 then
    exit;

  DoReplaceIf(@DoPredicateFuncProxy, aNewElement, @aPredicate, aData);
end;

procedure TGenericCollection.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if GetCount = 0 then
    exit;

  DoReplaceIf(@DoPredicateMethodProxy, aNewElement, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TGenericCollection.ReplaceIf(const aNewElement: T; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if GetCount = 0 then
    exit;

  DoReplaceIf(@DoPredicateRefFuncProxy, aNewElement, @aPredicate, nil);
end;
{$ENDIF}




{ 设计说明：
  - GetGrowSize 统一委派到具体策略 DoGetGrowSize，即便 aCurrentSize=0 也不在这里特判，
    让自定义策略可以在“首轮扩张”时生效自己的下界/策略。
  - 基类负责做最小下界收敛：Result >= aRequiredSize，保证调用方契约。
}

function TGrowthStrategy.GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  // Basic guards: required cannot be less than current range in callers; here we coerce minimal behavior
  if aRequiredSize <= aCurrentSize then
    Exit(aCurrentSize);

  // Delegate to concrete strategy, letting it decide even for aCurrentSize=0
  Result := DoGetGrowSize(aCurrentSize, aRequiredSize);
  // Ensure monotonic non-decreasing lower bound
  if Result < aRequiredSize then
    Result := aRequiredSize;


end;

function TCustomGrowthStrategy.GetData: Pointer;
begin
  Result := FData;
end;

function TCustomGrowthStrategy.DoGetGrowSizeFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowFunc(aCurrentSize, aRequiredSize, FData);
end;

function TCustomGrowthStrategy.DoGetGrowSizeMethod(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowMethod(aCurrentSize, aRequiredSize);
end;

function TCustomGrowthStrategy.DoGetGrowSizeRefFunc(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowRefFunc(aCurrentSize, aRequiredSize);
end;

function TCustomGrowthStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowProxy(aCurrentSize, aRequiredSize);
end;

constructor TCustomGrowthStrategy.Create(aGrowFunc: TGrowFunc; aData: Pointer);
begin
  inherited Create;

  if aGrowFunc = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowFunc is nil');

  FGrowFunc  := aGrowFunc;
  FData      := aData;

  FGrowProxy := @DoGetGrowSizeFunc;
end;

constructor TCustomGrowthStrategy.Create(aGrowMethod: TGrowMethod; aData: Pointer);
begin
  inherited Create;

  if aGrowMethod = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowMethod is nil');

  FGrowMethod := aGrowMethod;
  FData       := aData;

  FGrowProxy  := @DoGetGrowSizeMethod;
end;

constructor TCustomGrowthStrategy.Create(aGrowRefFunc: TGrowRefFunc);
begin
  inherited Create;

  if aGrowRefFunc = nil then
    raise EArgumentNil.Create('TCustomGrowthStrategy.Create: aGrowRefFunc is nil');

  FGrowRefFunc := aGrowRefFunc;
  FData        := nil;

  FGrowProxy   := @DoGetGrowSizeRefFunc;
end;

function TCalcGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := aCurrentSize;

  while Result < aRequiredSize do
    Result := DoCalc(Result);
end;

function TDoublingGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
begin
  // 处理初始容量为0的情况，避免无限循环
  if aCurrentSize = 0 then
    Result := 1  // 从1开始，后续按2倍增长
  else
  begin
    // 检查乘法是否会导致溢出
    if aCurrentSize > High(SizeUInt) div 2 then
      Result := High(SizeUInt)  // 返回最大值，让上层处理溢出
    else
      Result := aCurrentSize * 2;
  end;
end;

class destructor TDoublingGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TDoublingGrowStrategy.GetGlobal: TDoublingGrowStrategy;
begin
  // No global: return a fresh instance
  Result := TDoublingGrowStrategy.Create;
end;

function TFixedGrowStrategy.GetFixedSize: SizeUInt;
begin
  Result := FFixedSize;
end;

function TFixedGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
begin
  Result := aCurrentSize + FFixedSize;
end;

constructor TFixedGrowStrategy.Create(aFixedSize: SizeUInt);
begin
  inherited Create;

  if aFixedSize = 0 then
    raise EInvalidArgument.Create('TFixedGrowStrategy.Create: aFixedSize is 0');

  FFixedSize := aFixedSize;
end;

function TFactorGrowStrategy.GetFactor: Single;
begin
  Result := FFactor;
end;

function TFactorGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
var
  LProduct: Single;
  LCeiled: Int64;
const
  MAX_SAFE_SIZEUINT = 9223372036854775807; // High(Int64)
begin
  // 处理初始容量为0的情况，避免无限循环
  if aCurrentSize = 0 then
    Result := 1  // 从1开始，后续按因子增长
  else
  begin
    // 检查乘法是否会导致溢出
    LProduct := aCurrentSize * FFactor;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT  // 返回安全的最大值
    else
    begin
      // LCeiled is Int64; after the MAX_SAFE_SIZEUINT / NaN / Inf guard above,
      // this conversion cannot overflow Int64.
      LCeiled := ceil(LProduct);
      Result := SizeUInt(LCeiled);
    end;
  end;
end;

constructor TFactorGrowStrategy.Create(aFactor: Single);
begin
  inherited Create;

  if aFactor <= 0 then
    raise EInvalidArgument.Create('TFactorGrowStrategy.Create: aFactor is 0');

  FFactor := aFactor;
end;

class destructor TPowerOfTwoGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TPowerOfTwoGrowStrategy.GetGlobal: TPowerOfTwoGrowStrategy;
begin
  // No global: return a fresh instance
  Result := TPowerOfTwoGrowStrategy.Create;
end;

function TPowerOfTwoGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize <> 0 then;
  if aRequiredSize = 0 then
    Exit(0);
  Result := 1;
  while Result < aRequiredSize do
    Result := Result shl 1;
end;

function TGoldenRatioGrowStrategy.DoCalc(aCurrentSize: SizeUInt): SizeUInt;
const
  GOLDEN_RATIO: Single = 1.61803398875;
  MAX_SAFE_SIZEUINT = 9223372036854775807; // High(Int64)
var
  LProduct: Single;
  LCeiled: Int64;
begin
  // 处理初始容量为0的情况，避免无限循环
  if aCurrentSize = 0 then
    Result := 1  // 从1开始，后续按黄金比例增长
  else
  begin
    // 检查乘法是否会导致溢出
    LProduct := aCurrentSize * GOLDEN_RATIO;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT  // 返回安全的最大值
    else
    begin
      // LCeiled is Int64; after the MAX_SAFE_SIZEUINT / NaN / Inf guard above,
      // this conversion cannot overflow Int64.
      LCeiled := ceil(LProduct);
      Result := SizeUInt(LCeiled);
    end;
  end;
end;

class destructor TGoldenRatioGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;

class function TGoldenRatioGrowStrategy.GetGlobal: TGoldenRatioGrowStrategy;
begin
  // No global: return a fresh instance
  Result := TGoldenRatioGrowStrategy.Create;
end;

function TAlignedWrapperStrategy.GetGrowStrategy: IGrowthStrategy;
begin
  Result := FGrowStrategy;
end;

function TAlignedWrapperStrategy.GetAlignSize: SizeUInt;
begin
  Result := FAlignSize;
end;

constructor TAlignedWrapperStrategy.Create(const aGrowStrategy: IGrowthStrategy; aAlignSize: SizeUInt);
begin
  inherited Create;

  if (aGrowStrategy = nil) then
    raise EArgumentNil.Create('TAlignedWrapperStrategy.Create: aGrowStrategy is nil');

  if (aAlignSize = 0) then
    raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize is 0');

  if ((aAlignSize and (aAlignSize - 1)) <> 0) then
    raise EInvalidArgument.Create('TAlignedWrapperStrategy.Create: aAlignSize must be power of two');

  FGrowStrategy := aGrowStrategy;
  FAlignSize    := aAlignSize;
end;

function TAlignedWrapperStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Result := FGrowStrategy.GetGrowSize(aCurrentSize, aRequiredSize);
  Result := ((Result + FAlignSize - 1) div FAlignSize) * FAlignSize;
end;

class destructor TExactGrowStrategy.Destroy;
begin
  if FGlobal <> nil then
  begin
    FGlobal.Free;
    FGlobal := nil;
  end;
end;


class function TExactGrowStrategy.GetGlobal: TExactGrowStrategy;
begin
  // No global: return a fresh instance
  Result := TExactGrowStrategy.Create;
end;


function TExactGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize <> 0 then;
  Result := aRequiredSize;
end;

end.
