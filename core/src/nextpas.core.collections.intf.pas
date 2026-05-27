unit nextpas.core.collections.intf;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager.intf,
  nextpas.core.collections.slice;

type
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
    * LoadFromUnchecked
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
    procedure LoadFromUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;

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
    * AppendUnchecked
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
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); overload;

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
    * LoadFromUnchecked
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
    procedure LoadFromUnchecked(const aSrc: TCollection); overload;

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
    * SaveToUnchecked
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
    procedure SaveToUnchecked(aDst: TCollection);

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
    * AppendUnchecked
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
    procedure AppendUnchecked(const aSrc: TCollection); overload;

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
    * AppendToUnchecked
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
    procedure AppendToUnchecked(const aDst: TCollection); overload;

    property Count:     SizeUInt   read GetCount;
    property Data:      Pointer    read GetData write SetData;
    property Allocator: IAllocator read GetAllocator;

  end;
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
    function GetElementManager: specialize IElementManager<T>;

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


    { CountIf 容器统计算法 }

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;

    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;

    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    {**
     * CountIf
     *
     * @desc 计算容器中满足条件的元素数量
     *}
    function CountIf(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
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
    property ElementManager:  specialize IElementManager<T> read GetElementManager;
    property ElementTypeInfo: PTypeInfo                     read GetElementTypeInfo;

  end;

implementation

end.
