unit nextpas.core.collections.vecdeque;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.vecdeque.base,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.arr,
  nextpas.core.collections.vec;

function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;

type

  {**
   * TVecDeque<T>
   *
   * @desc 向量双端队列实现 - 基于环形缓冲区的高性能双端队列
   *
   * @param T 元素类型
   *
   * @note
   *   **核心特性**:
   *   - O(1) 双端插入/删除 (PushFront/PushBack/PopFront/PopBack)
   *   - O(1) 随机访问 (Get/Put)
   *   - 内部容量始终为 2 的幂，使用位掩码优化索引计算
   *   - 支持多种排序算法 (QuickSort/MergeSort/HeapSort/IntroSort)
   *   - 支持旋转/分割/合并等高级操作
   *
   *   **复杂度速查**:
   *   - PushFront/PushBack: O(1) 摊销, O(n) 最坏（扩容时）
   *   - PopFront/PopBack: O(1)
   *   - Get/Put: O(1)
   *   - Insert/Remove: O(n)
   *   - Reserve: O(n)
   *   - Rotate: O(n)
   *
   * @threadsafety 非线程安全，并发访问需外部同步
   *
   * @example
   *   var Deque: specialize TVecDeque<Integer>;
   *   Deque := specialize TVecDeque<Integer>.Create;
   *   try
   *     Deque.PushBack(1);
   *     Deque.PushFront(0);
   *     WriteLn(Deque.Front);  // 0
   *     WriteLn(Deque.Back);   // 1
   *     WriteLn(Deque[0]);     // 0 (随机访问)
   *   finally
   *     Deque.Free;
   *   end;
   *
   * @see IVecDeque 接口定义
   * @see TVec 纯尾部操作替代方案
   * @see TList 链表替代方案
   *}
  generic TVecDeque<T> = class(specialize TGenericCollection<T>,
                               specialize IDeque<T>,
                               specialize IQueue<T>)
  public type
    IVecT = specialize IVec<T>;
    {**
     * TDrainIter - Drain 迭代器
     *
     * @desc 消费式范围迭代器，迭代被 drain 的元素
     *       调用 DrainRange 时立即从原容器移除元素，迭代器逐个返回
     *}
    TDrainIter = record
    private
      FDrained: IVecT;
      FIndex: SizeUInt;
      FCurrent: T;
    public
      procedure Init(const aDrained: IVecT);
      function MoveNext: Boolean;
      function GetCurrent: T; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
      property Current: T read GetCurrent;
    end;
  type
    TInternalArray = specialize TArray<T>;
    TQueueIntf    = specialize IQueue<T>;
  private
    FBuffer:       TInternalArray;    // 内部存储缓冲区
    FHead:         SizeUInt;          // 头部索引 (第一个元素位置)
    FTail:         SizeUInt;          // 尾部索引 (下一个插入位置)
    FCount:        SizeUInt;          // 元素数量 (与双指针同步)
    FCapacityMask: SizeUInt;          // 容量掩码 (capacity - 1)，用于位运算优化
    FGrowStrategy: IGrowthStrategy;   // 增长策略（接口引用，引用计数管理生命周期）

  { 内部辅助方法 }
  private
    function  GetPhysicalIndex(aLogicalIndex: SizeUInt): SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  WrapIndex(aIndex: SizeUInt): SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  WrapAdd(aIndex, aValue: SizeUInt): SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  WrapSub(aIndex, aValue: SizeUInt): SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  GetTailIndex: SizeUInt; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  IsFull: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  IsValidIndex(aIndex: SizeUInt): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  IsEmpty: Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  RequireAddCount(aBase, aAdditional: SizeUInt; const aCallerName: string): SizeUInt;
    procedure EnsureCapacity(aRequiredCapacity: SizeUInt);
    procedure Grow(aNewCapacity: SizeUInt);
    function  CalcGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
    function  NextPowerOfTwo(aValue: SizeUInt): SizeUInt;
    function  IsPowerOfTwo(aValue: SizeUInt): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure UpdateCapacityMask;
    procedure SyncCountAndTail; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  ChooseOptimalGrowStrategy(aFirstPartSize, aSecondPartSize, aNewCapacity: SizeUInt): Integer;
    function  GetDefaultGrowStrategy: IGrowthStrategy;
    procedure ReverseRange(aStartIndex: SizeUInt; aCount: SizeUInt);
    procedure CopyReversed(aSrc: Pointer; aDstIndex: SizeUInt; aCount: SizeUInt);
    procedure CopyForward(aSrc: Pointer; aDstIndex: SizeUInt; aCount: SizeUInt);
    procedure MoveElementsRight(aIndex: SizeUInt; aCount: SizeUInt);
    procedure MoveElementsLeft(aIndex: SizeUInt; aCount: SizeUInt);
    procedure InsertRawNoOverlap(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
    procedure InsertFromOverlappingSource(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);

    { 高级容量管理 }
    function GetLoadFactor: Double;
    function GetWastedSpace: SizeUInt;

    // 将整个逻辑范围整理为单段连续内存，返回第一段指针与长度（若为空则返回 nil,0）
    procedure MakeContiguous(out aPtr: PElement; out aLen: SizeUInt);

    function ShouldShrink: Boolean;
    function ShouldGrow(aAdditionalElements: SizeUInt): Boolean;
    function CalculateOptimalCapacity(aRequiredSize: SizeUInt): SizeUInt;
    procedure OptimizeCapacity;

    { 批量移除操作 - 使用 Range 命名范式 }
    procedure RemoveRange(aIndex, aCount: SizeUInt);
    procedure RemoveRangeUnChecked(aIndex, aCount: SizeUInt);
    function PopFrontRange(aCount: SizeUInt): SizeUInt;
    function PopBackRange(aCount: SizeUInt): SizeUInt;
    procedure PopFrontRange(aCount: SizeUInt; const aTarget: TCollection);
    procedure PopBackRange(aCount: SizeUInt; const aTarget: TCollection);
    procedure TrimFront(aCount: SizeUInt);
    procedure TrimBack(aCount: SizeUInt);
    procedure TrimToSize(aNewSize: SizeUInt);

    { 双端队列特有算法 }
    procedure Rotate(aPositions: Integer);
    procedure RotateLeft(aPositions: SizeUInt);
    procedure RotateRight(aPositions: SizeUInt);
    function Split(aIndex: SizeUInt): TVecDeque;
    procedure Merge(const aOther: TVecDeque; aPosition: TMergePosition);
    procedure SwapEnds;
    procedure MoveToFront(aIndex: SizeUInt);
    procedure MoveToBack(aIndex: SizeUInt);

    { 高级排序算法实现 }
    procedure DoQuickSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure DoMergeSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure DoHeapSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure DoIntroSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure DoInsertionSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);

    { 排序辅助方法 }
    function DoCompare(const aLeft, aRight: T; aComparer: TCompareFunc; aData: Pointer): Integer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    procedure DoSwap(aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function DoPartition(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeUInt;
    procedure DoHeapify(aIndex, aHeapSize: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure DoMerge(aLeft, aMid, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    function DoIntroSortDepthLimit(aCount: SizeUInt): Integer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    type
      TCompareMethodContext = record
        Comparer: TCompareMethod;
        Data: Pointer;
      end;

    class function CompareMethodAdapter(const aLeft, aRight: T; aData: Pointer): SizeInt; static;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    class function CompareRefFuncAdapter(const aLeft, aRight: T; aData: Pointer): SizeInt; static;
    {$ENDIF}


  { ITerator 迭代器回调 }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function  DoIterMoveNext(aIter: PPtrIter): Boolean;

  { 内存重叠检查 }
  protected
    function IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean; override;

  { 算法实现 }
  protected
    procedure DoFill(const aElement: T); override;
    procedure DoZero(); override;
    procedure DoReverse; override;

  public
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    // VecDeque 支持自定义增长策略，但最终容量会统一归一为 2 的幂，确保位掩码优化
    constructor Create(aAllocator: IAllocator); overload;

    constructor Create(aCapacity: SizeUInt); overload;
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator); overload;
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy); overload;
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer); virtual; overload;

    constructor Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy); overload;
    constructor Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer); overload;

    constructor Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy); overload;
    constructor Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer); overload;

    constructor Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy); overload;
    constructor Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer); overload;

    destructor  Destroy; override;

    { ICollection 接口实现 }
    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: TCollection); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    { 高性能批量操作接口 - 提供更高效的数据转移方式 }
    { LoadFrom: 直接加载数据到容器（替换当前内容） }
    procedure LoadFromPointer(aSrc: PElement; aCount: SizeUInt); inline;
    procedure LoadFromArray(const aSrc: array of T);

    { AppendFrom: 从指定位置追加数据到容器末尾 }
    procedure AppendFrom(const aSrc: TVecDeque; aSrcIndex: SizeUInt; aCount: SizeUInt);

    { InsertFrom: 从指定位置插入批量数据 }
    procedure InsertFrom(aIndex: SizeUInt; aSrc: PElement; aCount: SizeUInt); inline;
    procedure InsertFrom(aIndex: SizeUInt; const aSrc: array of T);

    { IGenericCollection<T> 接口实现 }
    procedure SaveToUnChecked(aDst: TCollection); override;

    { IArray<T> 接口实现 }
    function GetMemory: PElement;
    function Get(aIndex: SizeUInt): T;
    function GetUnChecked(aIndex: SizeUInt): T;
    procedure Put(aIndex: SizeUInt; const aElement: T);
    procedure PutUnChecked(aIndex: SizeUInt; const aElement: T);
    function GetPtr(aIndex: SizeUInt): PElement;
    function GetPtrUnChecked(aIndex: SizeUInt): PElement;
    procedure Resize(aNewSize: SizeUInt);
    procedure Ensure(aIndex: SizeUInt);
    procedure OverWrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload;
    procedure OverWrite(aIndex: SizeUInt; const aSrc: array of T); overload;
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: array of T); overload;
    procedure OverWrite(aIndex: SizeUInt; const aSrc: TCollection); overload;
    procedure OverWriteUnChecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload;
    procedure Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload;
    procedure ReadUnChecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload;
    procedure Read(aIndex: SizeUInt; var aDst: TCollection; aCount: SizeUInt); overload;
    procedure ReadUnChecked(aIndex: SizeUInt; var aDst: TCollection; aCount: SizeUInt); overload;
    procedure Swap(aIndex1, aIndex2: SizeUInt); overload;
    procedure SwapUnChecked(aIndex1, aIndex2: SizeUInt); overload;
    procedure Swap(aIndex1, aIndex2, aCount: SizeUInt); overload;
    procedure Swap(aSrcIndex, aDstIndex, aCount, aStride: SizeUInt); overload;
    procedure Copy(aSrcIndex, aDstIndex, aCount: SizeUInt); overload;
    procedure CopyUnChecked(aSrcIndex, aDstIndex, aCount: SizeUInt); overload;
    procedure Fill(aIndex: SizeUInt; const aElement: T); overload;
    procedure Fill(aIndex, aCount: SizeUInt; const aElement: T); overload;
    procedure FillUnChecked(aIndex, aCount: SizeUInt; const aElement: T); overload;
    procedure Zero(aIndex: SizeUInt); overload;
    procedure Zero(aIndex, aCount: SizeUInt); overload;
    procedure ZeroUnChecked(aIndex, aCount: SizeUInt); overload;
    procedure Reverse(aIndex: SizeUInt); overload;
    procedure Reverse(aIndex, aCount: SizeUInt); overload;
    procedure ReverseUnChecked(aIndex, aCount: SizeUInt); overload;

    { Search and algorithm methods }
    function ForEach(aIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload;
    function ForEach(aIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean; overload;
    function ForEach(aIndex: SizeUInt; aPredicate: TPredicateRefFunc): Boolean; overload;
    function ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload;
    function ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean; overload;
    function ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Boolean; overload;
    function ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload;
    function ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean; overload;
    function ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Boolean; overload;

    function Contains(const aElement: T; aIndex: SizeUInt): Boolean; overload;
    function Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsRefFunc): Boolean; overload;
    function Contains(const aElement: T; aIndex, aCount: SizeUInt): Boolean; overload;
    function Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean; overload;
    function Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean; overload;
    function ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): Boolean; overload;

    function FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Int64; overload;
    function FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Int64; overload;
    function FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Int64; overload;
    function FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Int64; overload;
    function FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Int64; overload;
    function FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Int64; overload;

    { IVec<T> 接口实现 }
    function GetCapacity: SizeUint;
    procedure SetCapacity(aCapacity: SizeUint);
    // IGrowthStrategy（接口统一，对齐 IVec<T> 签名）
    function GetGrowStrategy: IGrowthStrategy;
    procedure SetGrowStrategy(aGrowStrategy: IGrowthStrategy);
    function TryReserve(aAdditional: SizeUint): Boolean;
        procedure FreeBuffer;
    procedure Reserve(aAdditional: SizeUint);
    procedure ShrinkToFit;
    procedure ShrinkToFitExact;
    function InsertElement(aIndex: SizeUInt; const aElement: T): SizeUInt;
    function Remove(aIndex: SizeUInt): T;
    function RemoveSwap(aIndex: SizeUInt): T;
    function Add(const aElement: T): SizeUInt;

    { IQueue<T> 队列接口实现 }
    procedure Enqueue(const aElement: T); overload;
    procedure Enqueue(const aElements: array of T); overload;
    procedure Enqueue(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure Push(const aElement: T); overload;
    procedure Push(const aElements: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    function Dequeue: T; overload;
    function Pop: T; overload;
    function Peek: T; overload;
    function Dequeue(var aElement: T): Boolean; overload;
    function Pop(out aElement: T): Boolean; overload;
    function Peek(out aElement: T): Boolean; overload;  // ✅ 统一为 out 参数
    function TryPeek(out aElement: T): Boolean; overload; // 新 IQueue 兼容
    function Count: SizeUInt; // 新 IQueue 兼容
    function Front: T; overload;
    function Front(var aElement: T): Boolean; overload;
    function Back: T; overload;
    function Back(var aElement: T): Boolean; overload;
    function TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
    function TryRemove(aIndex: SizeUInt; var aElement: T): Boolean;
    procedure Resize(aNewSize: SizeUInt; const aValue: T);
    // IDeque<T> 接口要求的方法
    procedure Append(const aOther: TQueueIntf);
    function SplitOff(aAt: SizeUInt): TQueueIntf;
    // IVec<T> 接口要求的 SplitOff（返回 IVec<T>）
    function SplitOffToVec(aIndex: SizeUInt): specialize IVec<T>;

    { IDeque<T> 双端队列接口实现 }
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
    function PeekFront: T; overload;
    function PeekFront(out aElement: T): Boolean; overload;  // ✅ 统一为 out 参数
    function PeekBack: T; overload;
    function PeekBack(out aElement: T): Boolean; overload;   // ✅ 统一为 out 参数

    { IArray<T> 接口实现 - 所有必需的方法声明 }

    // Read 方法
    procedure Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
    procedure ReadUnChecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);

    // Find 系列方法
    function Find(const aValue: T): SizeInt;
    function Find(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function Find(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function Find(const aValue: T; aEquals: TEqualsRefFunc): SizeInt;
    function Find(const aValue: T; aStartIndex: SizeUInt): SizeInt;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;

    // FindUnChecked 系列方法
    function FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;

    // FindIF 系列方法
    function FindIF(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIF(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIF(aPredicate: TPredicateRefFunc): SizeInt;
    function FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;



    // FindIFNot 系列方法
    function FindIFNot(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIFNot(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIFNot(aPredicate: TPredicateRefFunc): SizeInt;
    function FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;



    // FindLast 系列方法
    function FindLast(const aValue: T): SizeInt;
    function FindLast(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aEquals: TEqualsRefFunc): SizeInt;
    function FindLast(const aValue: T; aStartIndex: SizeUInt): SizeInt;
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;

    function FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
    function FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
    function FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;

    // FindLastIF 系列方法
    function FindLastIF(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIF(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIF(aPredicate: TPredicateRefFunc): SizeInt;
    function FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;

    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;

    // FindLastIFNot 系列方法
    function FindLastIFNot(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIFNot(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIFNot(aPredicate: TPredicateRefFunc): SizeInt;
    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;

    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
    function FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;

    // CountOf 系列方法
    function CountOf(const aValue: T; aStartIndex: SizeUInt): SizeUInt;
    function CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;
    function CountOf(const aValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
    function CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;

    function CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
    function CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
    function CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
    function CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;

    // CountIf 系列方法
    function CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
    function CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
    function CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;

    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
    function CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;

    // Replace 系列方法
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc);

    function ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
    function ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
    function ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
    function ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;

    // ReplaceIF 系列方法
    procedure ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer);
    procedure ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer);
    procedure ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc);
    procedure ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer);
    procedure ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer);
    procedure ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc);

    function ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
    function ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
    function ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;

    // IsSorted 系列方法
    function IsSorted(aStartIndex: SizeUInt): Boolean;
    function IsSorted(aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
    function IsSorted(aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
    function IsSorted(aStartIndex: SizeUInt; aComparer: TCompareRefFunc): Boolean;
    function IsSorted(aStartIndex, aCount: SizeUInt): Boolean;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): Boolean;

    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt): Boolean;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
    function IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): Boolean;

    // BinarySearch 系列方法
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;

    function BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;

    // BinarySearchInsert 系列方法
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;

    function BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
    function BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;

    // Shuffle 系列方法
    procedure Shuffle(aStartIndex: SizeUInt);
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
    procedure Shuffle(aStartIndex, aCount: SizeUInt);
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);

    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt);
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
    procedure ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);

    // 基础方法（无参数版本）
    function CountOf(const aValue: T): SizeUInt;
    function CountOf(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
    function CountOf(const aValue: T; aEquals: TEqualsRefFunc): SizeUInt;

    function CountIF(aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
    function CountIF(aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
    function CountIF(aPredicate: TPredicateRefFunc): SizeUInt;

    procedure Replace(const aOldValue, aNewValue: T);
    procedure Replace(const aOldValue, aNewValue: T; aEquals: TEqualsFunc; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aEquals: TEqualsMethod; aData: Pointer);
    procedure Replace(const aOldValue, aNewValue: T; aEquals: TEqualsRefFunc);

    procedure ReplaceIf(const aNewValue: T; aPredicate: TPredicateFunc; aData: Pointer);
    procedure ReplaceIf(const aNewValue: T; aPredicate: TPredicateMethod; aData: Pointer);
    procedure ReplaceIf(const aNewValue: T; aPredicate: TPredicateRefFunc);

    function IsSorted: Boolean;
    function IsSorted(aComparer: TCompareFunc; aData: Pointer): Boolean;
    function IsSorted(aComparer: TCompareMethod; aData: Pointer): Boolean;
    function IsSorted(aComparer: TCompareRefFunc): Boolean;

    function BinarySearch(const aValue: T): SizeInt;
    function BinarySearch(const aValue: T; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearch(const aValue: T; aComparer: TCompareRefFunc): SizeInt;

    function BinarySearchInsert(const aValue: T): SizeInt;
    function BinarySearchInsert(const aValue: T; aComparer: TCompareFunc; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aComparer: TCompareMethod; aData: Pointer): SizeInt;
    function BinarySearchInsert(const aValue: T; aComparer: TCompareRefFunc): SizeInt;

    procedure Shuffle;
    procedure Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
    procedure Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc);

    // Sort 系列方法
    procedure Sort;
    procedure Sort(aComparer: TCompareFunc; aData: Pointer);
    procedure Sort(aComparer: TCompareMethod; aData: Pointer);
    procedure Sort(aComparer: TCompareRefFunc);
    procedure Sort(aStartIndex: SizeUInt);
    procedure Sort(aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure Sort(aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
    procedure Sort(aStartIndex: SizeUInt; aComparer: TCompareRefFunc);
    procedure Sort(aStartIndex, aCount: SizeUInt);
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc);

    // SortUnChecked 系列方法
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt);
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
    procedure SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc);

    // 其他缺失的方法
    function TryReserveExact(aCapacity: SizeUInt): Boolean;
    procedure ReserveExact(aCapacity: SizeUInt);

    // 批量操作优化方法
    procedure FillWith(const aValue: T; aCount: SizeUInt);
    procedure ClearAndReserve(aCapacity: SizeUInt);
    procedure SwapRange(aIndex1, aIndex2, aCount: SizeUInt); // 批量交换
    function FastIndexOf(const aValue: T): SizeInt; // 快速查找
    function FastLastIndexOf(const aValue: T): SizeInt; // 快速反向查找
    procedure WarmupMemory; // 内存预热，提高首次访问性能
    procedure WarmupMemory(aMinCapacity: SizeUInt); // 预热到指定最小容量（不改变 Count）

    // 高级排序算法方法
    procedure SortWith(aAlgorithm: TSortAlgorithm); // 使用指定算法排序
    procedure SortWith(aAlgorithm: TSortAlgorithm; aComparer: TCompareFunc; aData: Pointer);
    procedure SortWith(aAlgorithm: TSortAlgorithm; aComparer: TCompareRefFunc);
    procedure SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm);
    procedure SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm; aComparer: TCompareFunc; aData: Pointer);
    procedure SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm; aComparer: TCompareRefFunc);

    // 并行操作方法已移除，使用标准方法替代

    // 并行方法已移除，使用标准方法替代

    // Rust VecDeque 关键功能前向声明已移除

    // IVec基础方法
    procedure Shrink;
    procedure ShrinkTo(aCapacity: SizeUInt);
    procedure Truncate(aNewCount: SizeUInt);
    procedure ResizeExact(aNewCount: SizeUInt);

    // Insert 系列方法（重载已存在的方法）
    procedure Insert(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
    procedure Insert(aIndex: SizeUInt; const aElement: T);
    procedure Insert(aIndex: SizeUInt; const aArray: array of T);
    procedure Insert(aIndex: SizeUInt; const aCollection: TCollection); overload;
    procedure Insert(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt); overload;

    // Write 系列方法
    procedure Write(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
    procedure Write(aIndex: SizeUInt; const aArray: array of T);
    procedure Write(aIndex: SizeUInt; const aCollection: TCollection);
    procedure Write(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt);

    // WriteExact 系列方法
    procedure WriteExact(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
    procedure WriteExact(aIndex: SizeUInt; const aArray: array of T);
    procedure WriteExact(aIndex: SizeUInt; const aCollection: TCollection);
    procedure WriteExact(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt);


    // 提供零拷贝访问当前逻辑区间的两段连续内存切片（若连续仅返回第一段，第二段长度为0）
    // 返回：
    //   aPtr1, aLen1: 第一段起始指针与元素数
    //   aPtr2, aLen2: 第二段起始指针与元素数（可能为0）
    procedure GetTwoSlices(out aPtr1: PElement; out aLen1: SizeUInt; out aPtr2: PElement; out aLen2: SizeUInt);
    // 区间版本：将 [aIndex, aIndex+aCount) 映射为至多两段物理连续切片
    procedure GetTwoSlices(aIndex, aCount: SizeUInt; out aPtr1: PElement; out aLen1: SizeUInt; out aPtr2: PElement; out aLen2: SizeUInt);
    // Push 系列方法（重载已存在的方法）
    procedure Push(const aCollection: TCollection; aStartIndex: SizeUInt);

    // TryPop 系列方法
    function TryPop(aPtr: Pointer; aCount: SizeUInt): Boolean;
    function TryPop(var aArray: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;
    function TryPop(var aElement: T): Boolean;

    // TryPeek 系列方法
    function TryPeekCopy(aPtr: Pointer; aCount: SizeUInt): Boolean;
    function TryPeek(var aArray: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;



      // Try 前/后端别名（与现有 Pop/Peek 族保持兼容，不改变语义）
      function TryPeekFront(out aElement: T): Boolean;
      function TryPeekBack(out aElement: T): Boolean;
      function TryPopFront(out aElement: T): Boolean;
      function TryPopBack(out aElement: T): Boolean;

    // PeekRange 方法
    function PeekRange(aCount: SizeUInt): PElement;
    function PeekRangeContiguous(aCount: SizeUInt): PElement;  // 强制连续化版本

    // 批量插入操作 - Range 命名范式
    procedure InsertRange(aIndex: SizeUInt; const aElements: array of T);
    procedure InsertRange(aIndex: SizeUInt; const aOther: TCollection);
    procedure PushFrontRange(const aElements: array of T);
    procedure PushFrontRange(const aPtr: Pointer; aCount: SizeUInt);
    procedure PushBackRange(const aElements: array of T);
    procedure PushBackRange(const aPtr: Pointer; aCount: SizeUInt);

    // 统一的 RemoveRange 重载系列
    procedure RemoveRange(aIndex, aCount: SizeUInt; aPtr: Pointer); overload;
    procedure RemoveRange(aIndex, aCount: SizeUInt; var aArray: specialize TGenericArray<T>); overload;
    procedure RemoveRange(aIndex, aCount: SizeUInt; const aTarget: TCollection); overload;

    // 现代化便利方法 - Java ArrayDeque 风格
    function RemoveFirstOccurrence(const aElement: T): Boolean;
    function RemoveLastOccurrence(const aElement: T): Boolean;

    // Delete 系列方法
    procedure Delete(aIndex: SizeUInt; aCount: SizeUInt);
    procedure Delete(aIndex: SizeUInt);
    procedure DeleteSwap(aIndex: SizeUInt; aCount: SizeUInt);
    procedure DeleteSwap(aIndex: SizeUInt);

    // Remove 系列方法（重载已存在的方法）
    procedure RemoveCopy(aIndex: SizeUInt; aPtr: Pointer; aCount: SizeUInt);
    procedure RemoveCopy(aIndex: SizeUInt; aPtr: Pointer);
    procedure RemoveArray(aIndex: SizeUInt; var aArray: specialize TGenericArray<T>; aCount: SizeUInt);
    procedure Remove(aIndex: SizeUInt; var aElement: T);
    procedure RemoveCopySwap(aIndex: SizeUInt; aPtr: Pointer; aCount: SizeUInt);
    procedure RemoveCopySwap(aIndex: SizeUInt; aPtr: Pointer);
    procedure RemoveArraySwap(aIndex: SizeUInt; var aArray: specialize TGenericArray<T>; aCount: SizeUInt);
    procedure RemoveSwap(aIndex: SizeUInt; var aElement: T);


    // IGenericCollection 兼容的按值移除（返回是否移除至少1个）
    function RemoveValue(const aElement: T): Boolean; overload;
    function RemoveValue(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): Boolean; overload;
    function RemoveValue(const aElement: T; aEquals: TEqualsMethod; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function RemoveValue(const aElement: T; aEquals: TEqualsRefFunc): Boolean; overload;
    {$ENDIF}

    // MinElement/MaxElement 系列方法 - 返回值版本
    function MinElement: T;
    function MinElement(aComparer: TCompareFunc; aData: Pointer): T;
    function MinElement(aComparer: TCompareMethod; aData: Pointer): T;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function MinElement(aComparer: TCompareRefFunc): T;
    {$ENDIF}

    function MaxElement: T;
    function MaxElement(aComparer: TCompareFunc; aData: Pointer): T;
    function MaxElement(aComparer: TCompareMethod; aData: Pointer): T;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function MaxElement(aComparer: TCompareRefFunc): T;
    {$ENDIF}

    // MinElement/MaxElement 系列方法 - 返回索引版本
    function MinElementIndex: SizeUInt;
    function MinElementIndex(aComparer: TCompareFunc; aData: Pointer): SizeUInt;
    function MinElementIndex(aComparer: TCompareMethod; aData: Pointer): SizeUInt;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function MinElementIndex(aComparer: TCompareRefFunc): SizeUInt;
    {$ENDIF}

    function MaxElementIndex: SizeUInt;
    function MaxElementIndex(aComparer: TCompareFunc; aData: Pointer): SizeUInt;
    function MaxElementIndex(aComparer: TCompareMethod; aData: Pointer): SizeUInt;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function MaxElementIndex(aComparer: TCompareRefFunc): SizeUInt;
    {$ENDIF}

    // Filter 系列方法
    function Filter(aPredicate: TPredicateFunc; aData: Pointer): specialize IVec<T>;
    function Filter(aPredicate: TPredicateMethod; aData: Pointer): specialize IVec<T>;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Filter(aPredicate: TPredicateRefFunc): specialize IVec<T>;
    {$ENDIF}

    // Any 系列方法
    function Any(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
    function Any(aPredicate: TPredicateMethod; aData: Pointer): Boolean;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Any(aPredicate: TPredicateRefFunc): Boolean;
    {$ENDIF}

    // All 系列方法
    function All(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
    function All(aPredicate: TPredicateMethod; aData: Pointer): Boolean;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function All(aPredicate: TPredicateRefFunc): Boolean;
    {$ENDIF}

    // Retain 系列方法
    procedure Retain(aPredicate: TPredicateFunc; aData: Pointer);
    procedure Retain(aPredicate: TPredicateMethod; aData: Pointer);
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Retain(aPredicate: TPredicateRefFunc);
    {$ENDIF}

    // Drain 方法
    function Drain(aStart, aCount: SizeUInt): specialize IVec<T>;
    function DrainRange(aStart, aEnd: SizeUInt): TDrainIter;

    // Splice 方法（IVec<T> 接口要求）
    procedure Splice(aIndex, aRemoveCount: SizeUInt; const aInsert: array of T);

    // First / Last 方法
    function First: T;
    function Last: T;

    property Capacity:     SizeUint        read GetCapacity     write SetCapacity;
    property GrowStrategy: IGrowthStrategy read GetGrowStrategy write SetGrowStrategy;



  end;

implementation

function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;
begin
  Result := IsOverlap(aPtr1, aSize1, aPtr2, aSize2);
end;

{ TVecDeque<T> }

{ 内部辅助方法 }

procedure TVecDeque.GetTwoSlices(out aPtr1: PElement; out aLen1: SizeUInt; out aPtr2: PElement; out aLen2: SizeUInt);
var
  LTailIndex: SizeUInt;
begin
  aPtr1 := nil; aLen1 := 0; aPtr2 := nil; aLen2 := 0;
  if FCount = 0 then Exit;
  LTailIndex := WrapSub(FTail, 1);
  if FHead <= LTailIndex then
  begin
    // 连续
    aPtr1 := FBuffer.GetPtrUnChecked(FHead);
    aLen1 := FCount;
    Exit;
  end;
  // 跨环：两段
  aPtr1 := FBuffer.GetPtrUnChecked(FHead);
  aLen1 := FBuffer.GetCount - FHead;
  aPtr2 := FBuffer.GetPtrUnChecked(0);
  aLen2 := FTail;
end;

procedure TVecDeque.GetTwoSlices(aIndex, aCount: SizeUInt; out aPtr1: PElement; out aLen1: SizeUInt; out aPtr2: PElement; out aLen2: SizeUInt);
var
  LStartPhysical, LEndPhysical: SizeUInt;
begin
  aPtr1 := nil; aLen1 := 0; aPtr2 := nil; aLen2 := 0;
  if (aCount = 0) or (aIndex >= FCount) or (aIndex + aCount > FCount) then Exit;
  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);
  if LStartPhysical <= LEndPhysical then
  begin
    // 连续
    aPtr1 := FBuffer.GetPtrUnChecked(LStartPhysical);
    aLen1 := aCount;
    Exit;
  end;
  // 跨环：两段
  aPtr1 := FBuffer.GetPtrUnChecked(LStartPhysical);
  aLen1 := FBuffer.GetCount - LStartPhysical;
  aPtr2 := FBuffer.GetPtrUnChecked(0);
  aLen2 := aCount - aLen1;
end;

function TVecDeque.WrapIndex(aIndex: SizeUInt): SizeUInt;
begin
  // 使用位运算进行快速环形索引计算（仅当容量为2的幂时有效）
  if FCapacityMask > 0 then
    Result := aIndex and FCapacityMask
  else if FBuffer.GetCount > 0 then
    Result := aIndex mod FBuffer.GetCount  // 回退到模运算
  else
    Result := 0;
end;

function TVecDeque.WrapAdd(aIndex, aValue: SizeUInt): SizeUInt;
begin
  Result := WrapIndex(aIndex + aValue);
end;

function TVecDeque.WrapSub(aIndex, aValue: SizeUInt): SizeUInt;
begin
  if FCapacityMask > 0 then
    Result := (aIndex + FBuffer.GetCount - aValue) and FCapacityMask
  else if FBuffer.GetCount > 0 then
    Result := (aIndex + FBuffer.GetCount - aValue) mod FBuffer.GetCount
  else
    Result := 0;
end;

function TVecDeque.GetPhysicalIndex(aLogicalIndex: SizeUInt): SizeUInt;
begin
  // 简化边界检查：只检查缓冲区是否为空
  // 逻辑索引的有效性由调用者负责检查
  if FBuffer.GetCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.GetPhysicalIndex: buffer is empty');

  Result := WrapAdd(FHead, aLogicalIndex);
end;

function TVecDeque.GetTailIndex: SizeUInt;
begin
  // 在双指针设计中，FTail直接就是尾部索引
  Result := FTail;
end;



function TVecDeque.IsFull: Boolean;
begin
  Result := GetCount >= FBuffer.GetCount;  // 双指针设计不需要保留位置
end;

function TVecDeque.IsEmpty: Boolean;
begin
  Result := FCount = 0;  // 使用FCount判断，更可靠
end;

function TVecDeque.IsValidIndex(aIndex: SizeUInt): Boolean;
begin
  Result := aIndex < FCount;
end;

function TVecDeque.RequireAddCount(aBase, aAdditional: SizeUInt; const aCallerName: string): SizeUInt;
begin
  if IsAddOverflow(aBase, aAdditional) then
    raise EOverflow.CreateFmt('%s: size overflow', [aCallerName]);
  Result := aBase + aAdditional;
end;

procedure TVecDeque.EnsureCapacity(aRequiredCapacity: SizeUInt);
var
  LCurrentCapacity: SizeUInt;
  LNewCapacity: SizeUInt;
begin
  LCurrentCapacity := FBuffer.GetCount;
  if LCurrentCapacity >= aRequiredCapacity then
    Exit;

  // 使用智能容量计算
  LNewCapacity := CalculateOptimalCapacity(aRequiredCapacity);
  Grow(LNewCapacity);
end;

procedure TVecDeque.Grow(aNewCapacity: SizeUInt);
var
  LNewBuffer: TInternalArray;
  LTailIndex: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LNewHead: SizeUInt;
  LOptimalStrategy: Integer;
begin
  // 规范化目标容量到不小于当前元素数量的2的幂，确保位掩码加速路径
  if aNewCapacity < FCount then
    aNewCapacity := FCount;
  if aNewCapacity < VECDEQUE_DEFAULT_CAPACITY then
    aNewCapacity := VECDEQUE_DEFAULT_CAPACITY;
  // 幂次归一（核心不变式）：所有容量最终为 2 的幂
  aNewCapacity := NextPowerOfTwo(aNewCapacity);
  {$IFOPT C+} Assert(IsPowerOfTwo(aNewCapacity), 'TVecDeque.Grow: capacity must be power of two'); {$ENDIF}

  if FCount = 0 then
  begin
    // 空队列，直接调整缓冲区大小，无需复制数据
    FBuffer.Resize(aNewCapacity);
    FHead := 0;
    FTail := 0;
    UpdateCapacityMask;
    Exit;
  end;

  // 创建新的缓冲区
  LNewBuffer := TInternalArray.Create(SizeUInt(aNewCapacity), FBuffer.GetAllocator);
  try
    LTailIndex := WrapSub(FTail, 1);  // 最后一个元素的位置

    if FHead <= LTailIndex then
    begin
      // 情况1：数据是连续的 [____XXXX____]
      // 选择最优放置策略：居中放置以便两端都有增长空间
      LNewHead := (aNewCapacity - FCount) div 2;
      LNewBuffer.OverWriteUnChecked(LNewHead, FBuffer.GetPtrUnChecked(FHead), FCount);
      FHead := LNewHead;
      FTail := LNewHead + FCount;
    end
    else
    begin
      // 情况2：数据跨越了缓冲区边界 [XXX_____XXXX]
      // 智能选择重排策略
      LFirstPartSize := FBuffer.GetCount - FHead;
      LSecondPartSize := FTail;

      // 策略选择：比较三种方案的效率
      // 0: 连续放置在开头
      // 1: 连续放置在中间
      // 2: 保持分段但优化位置
      LOptimalStrategy := ChooseOptimalGrowStrategy(LFirstPartSize, LSecondPartSize, aNewCapacity);

      case LOptimalStrategy of
        0: // 连续放置在开头
        begin
          LNewBuffer.OverWriteUnChecked(0, FBuffer.GetPtrUnChecked(FHead), LFirstPartSize);
          LNewBuffer.OverWriteUnChecked(LFirstPartSize, FBuffer.GetPtrUnChecked(0), LSecondPartSize);
          FHead := 0;
          FTail := FCount;
        end;

        1: // 连续放置在中间（推荐）
        begin
          LNewHead := (aNewCapacity - FCount) div 2;
          LNewBuffer.OverWriteUnChecked(LNewHead, FBuffer.GetPtrUnChecked(FHead), LFirstPartSize);
          LNewBuffer.OverWriteUnChecked(LNewHead + LFirstPartSize, FBuffer.GetPtrUnChecked(0), LSecondPartSize);
          FHead := LNewHead;
          FTail := LNewHead + FCount;
        end;

        2: // 保持分段但优化位置
        begin
          // 将较大的段放在开头，较小的段放在末尾
          if LFirstPartSize >= LSecondPartSize then
          begin
            LNewBuffer.OverWriteUnChecked(0, FBuffer.GetPtrUnChecked(FHead), LFirstPartSize);
            LNewBuffer.OverWriteUnChecked(aNewCapacity - LSecondPartSize, FBuffer.GetPtrUnChecked(0), LSecondPartSize);
            FHead := 0;
            FTail := aNewCapacity - LSecondPartSize;
          end
          else
          begin
            LNewBuffer.OverWriteUnChecked(0, FBuffer.GetPtrUnChecked(0), LSecondPartSize);
            LNewBuffer.OverWriteUnChecked(aNewCapacity - LFirstPartSize, FBuffer.GetPtrUnChecked(FHead), LFirstPartSize);
            FHead := aNewCapacity - LFirstPartSize;
            FTail := LSecondPartSize;
          end;
        end;
      end;
    end;

    // 释放旧缓冲区并使用新缓冲区
    FBuffer.Free;
    FBuffer := LNewBuffer;
    LNewBuffer := nil; // 防止在finally中被释放

    // 更新容量掩码以支持位运算优化
    UpdateCapacityMask;
  finally
    if LNewBuffer <> nil then
      LNewBuffer.Free;
  end;
end;

function TVecDeque.CalcGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  // 当未设置外部增长策略时，使用内置“按需→2的幂”策略
  if FGrowStrategy <> nil then
    Result := FGrowStrategy.GetGrowSize(aCurrentSize, aRequiredSize)
  else
  begin
    // 默认：至少翻倍或满足需求，然后归一为 2 的幂
    if aRequiredSize <= aCurrentSize then
      Result := aCurrentSize
    else
      Result := NextPowerOfTwo(Max(aCurrentSize * 2, aRequiredSize));
  end;
end;

procedure TVecDeque.ReverseRange(aStartIndex: SizeUInt; aCount: SizeUInt);
var
  i, j, LPi, LPj: SizeUInt;
  LTemp: T;
begin
  if aCount <= 1 then
    Exit;

  i := aStartIndex;
  j := aStartIndex + aCount - 1;

  while i < j do
  begin
    // 使用逻辑→物理映射，确保跨环时正确交换
    LPi := GetPhysicalIndex(i);
    LPj := GetPhysicalIndex(j);
    LTemp := FBuffer.GetUnChecked(LPi);
    FBuffer.PutUnChecked(LPi, FBuffer.GetUnChecked(LPj));
    FBuffer.PutUnChecked(LPj, LTemp);
    Inc(i);
    Dec(j);
  end;
end;

procedure TVecDeque.CopyReversed(aSrc: Pointer; aDstIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LSrcPtr: PByte;
  LElementSize: SizeUInt;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit;

  LElementSize := GetElementSize;
  LSrcPtr := PByte(aSrc) + (aCount - 1) * LElementSize;

  for i := 0 to aCount - 1 do
  begin
    FBuffer.PutUnChecked(aDstIndex + i, PElement(LSrcPtr)^);
    Dec(LSrcPtr, LElementSize);
  end;
end;

procedure TVecDeque.CopyForward(aSrc: Pointer; aDstIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LSrcPtr: PByte;
  LElementSize: SizeUInt;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit;

  LElementSize := GetElementSize;
  LSrcPtr := PByte(aSrc);

  for i := 0 to aCount - 1 do
  begin
    FBuffer.PutUnChecked(aDstIndex + i, PElement(LSrcPtr)^);
    Inc(LSrcPtr, LElementSize);
  end;
end;

procedure TVecDeque.MoveElementsRight(aIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LElement: T;
  LSrcPhysical, LDstPhysical: SizeUInt;
begin
  { 将从 aIndex 开始的元素向右移动 aCount 个位置 }
  // 从后往前移动，避免覆盖
  if aIndex >= FCount then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  // 虽然这个操作本质上需要逐个移动，但我们可以减少索引计算
  for i := FCount - 1 downto aIndex do
  begin
    LSrcPhysical := GetPhysicalIndex(i);
    LDstPhysical := GetPhysicalIndex(i + aCount);

    LElement := FBuffer.GetUnChecked(LSrcPhysical);
    FBuffer.PutUnChecked(LDstPhysical, LElement);
  end;
end;

procedure TVecDeque.MoveElementsLeft(aIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LElement: T;
  LSrcPhysical, LDstPhysical: SizeUInt;
begin
  { 将从 aIndex 开始的元素向左移动 aCount 个位置 }
  // 从前往后移动，避免覆盖
  if aIndex >= FCount then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  // 虽然这个操作本质上需要逐个移动，但我们可以减少索引计算
  for i := aIndex to FCount - 1 do
  begin
    LSrcPhysical := GetPhysicalIndex(i);
    LDstPhysical := GetPhysicalIndex(i - aCount);

    LElement := FBuffer.GetUnChecked(LSrcPhysical);
    FBuffer.PutUnChecked(LDstPhysical, LElement);
  end;
end;

procedure TVecDeque.InsertRawNoOverlap(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
var
  i: SizeUInt;
  LPtr: PByte;
  LPhysicalIndex: SizeUInt;
  LRequiredCapacity: SizeUInt;
begin
  LRequiredCapacity := RequireAddCount(FCount, aCount, 'TVecDeque.Insert');
  EnsureCapacity(LRequiredCapacity);

  if aIndex < FCount then
    MoveElementsRight(aIndex, aCount);

  LPtr := PByte(aPtr);
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    FBuffer.PutUnChecked(LPhysicalIndex, PElement(LPtr)^);
    Inc(LPtr, SizeOf(T));
  end;

  Inc(FCount, aCount);
  FTail := WrapAdd(FHead, FCount);
end;

procedure TVecDeque.InsertFromOverlappingSource(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
var
  LSnapshot: TVecDeque;
begin
  LSnapshot := TVecDeque.Create(aCount, FBuffer.GetAllocator, FGrowStrategy);
  try
    LSnapshot.PushBack(aPtr, aCount);
    InsertRawNoOverlap(aIndex, LSnapshot.GetMemory, aCount);
  finally
    LSnapshot.Free;
  end;
end;

{ 迭代器回调 - 零分配迭代器：
  参考：docs/Iterator_BestPractices.md
  aIter.Data 直接保存逻辑索引（SizeUInt），首个 MoveNext 将其置为 0 并返回 FCount>0；
  后续每次 MoveNext 自增，返回 SizeUInt(Data) < FCount；
  DoIterGetCurrent 用逻辑索引映射到物理索引（mask/mod）。
  本实现无堆分配/释放，避免所有提前退出泄漏路径。 }

function TVecDeque.DoIterGetCurrent(aIter: PPtrIter): Pointer;
var
  LLogicalIndex: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  {$PUSH}{$WARN 4055 OFF}
  LLogicalIndex := SizeUInt(aIter^.Data);
  {$POP}

  if LLogicalIndex >= FCount then
  begin
    Result := nil;
    Exit;
  end;

  if FCapacityMask > 0 then
    LPhysicalIndex := (FHead + LLogicalIndex) and FCapacityMask
  else
    LPhysicalIndex := (FHead + LLogicalIndex) mod FBuffer.GetCount;

  Result := FBuffer.GetPtrUnChecked(LPhysicalIndex);
end;

function TVecDeque.DoIterMoveNext(aIter: PPtrIter): Boolean;
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

{ 内存重叠检查 }

function TVecDeque.IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean;
begin
  if (aSrc = nil) or (FCount = 0) then
  begin
    Result := False;
    Exit;
  end;

  // 检查源指针是否与VecDeque的缓冲区重叠
  Result := MemIsOverlap(
    FBuffer.GetMemory, FBuffer.GetCount * GetElementSize,
    aSrc, aCount * GetElementSize);
end;

{ 算法实现 }

procedure TVecDeque.DoFill(const aElement: T);
var
  LTailIndex: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  if FCount = 0 then
    Exit;

  LTailIndex := WrapSub(FTail, 1);  // 最后一个元素的位置

  if FHead <= LTailIndex then
  begin
    // 情况1：数据是连续的 [____XXXX____]
    // 一次性填充整个连续区域
    FBuffer.FillUnChecked(FHead, FCount, aElement);
  end
  else
  begin
    // 情况2：数据跨越了缓冲区边界 [XXX_____XXXX]
    // 分两段填充
    LFirstPartSize := FBuffer.GetCount - FHead;  // 从FHead到缓冲区末尾
    LSecondPartSize := FTail;                    // 从缓冲区开头到FTail

    // 填充第一段：从FHead到缓冲区末尾
    if LFirstPartSize > 0 then
      FBuffer.FillUnChecked(FHead, LFirstPartSize, aElement);

    // 填充第二段：从缓冲区开头到FTail
    if LSecondPartSize > 0 then
      FBuffer.FillUnChecked(0, LSecondPartSize, aElement);
  end;
end;

procedure TVecDeque.DoZero;
var
  LTailIndex: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  if FCount = 0 then
    Exit;

  LTailIndex := WrapSub(FTail, 1);  // 最后一个元素的位置

  if FHead <= LTailIndex then
  begin
    // 情况1：数据是连续的 [____XXXX____]
    // 一次性清零整个连续区域
    FBuffer.ZeroUnChecked(FHead, FCount);
  end
  else
  begin
    // 情况2：数据跨越了缓冲区边界 [XXX_____XXXX]
    // 分两段清零
    LFirstPartSize := FBuffer.GetCount - FHead;  // 从FHead到缓冲区末尾
    LSecondPartSize := FTail;                    // 从缓冲区开头到FTail

    // 清零第一段：从FHead到缓冲区末尾
    if LFirstPartSize > 0 then
      FBuffer.ZeroUnChecked(FHead, LFirstPartSize);

    // 清零第二段：从缓冲区开头到FTail
    if LSecondPartSize > 0 then
      FBuffer.ZeroUnChecked(0, LSecondPartSize);
  end;
end;

procedure TVecDeque.DoReverse;
var
  LTailIndex: SizeUInt;

  i, j: SizeUInt;
  LTemp: T;
  LPhysicalI, LPhysicalJ: SizeUInt;
begin
  if FCount <= 1 then
    Exit;

  LTailIndex := WrapSub(FTail, 1);  // 最后一个元素的位置

  if FHead <= LTailIndex then
  begin
    // 情况1：数据是连续的 [____XXXX____]
    // 可以使用高效的连续内存反转
    i := FHead;
    j := LTailIndex;

    while i < j do
    begin
      LTemp := FBuffer.GetUnChecked(i);
      FBuffer.PutUnChecked(i, FBuffer.GetUnChecked(j));
      FBuffer.PutUnChecked(j, LTemp);
      Inc(i);
      Dec(j);
    end;
  end
  else
  begin
    // 情况2：数据跨越了缓冲区边界 [XXX_____XXXX]
    // 需要特殊的分段反转算法

    // 使用逻辑索引进行反转，保持原有的正确性 - 优化：减少 GetPhysicalIndex 调用
    i := 0;
    j := FCount - 1;

    while i < j do
    begin
      LPhysicalI := GetPhysicalIndex(i);
      LPhysicalJ := GetPhysicalIndex(j);

      LTemp := FBuffer.GetUnChecked(LPhysicalI);
      FBuffer.PutUnChecked(LPhysicalI, FBuffer.GetUnChecked(LPhysicalJ));
      FBuffer.PutUnChecked(LPhysicalJ, LTemp);
      Inc(i);
      Dec(j);
    end;
  end;
end;

{ 构造函数和析构函数 }



constructor TVecDeque.Create(aAllocator: IAllocator; aData: Pointer);
begin
  Create(VECDEQUE_DEFAULT_CAPACITY, aAllocator, GetDefaultGrowStrategy, aData);
end;

constructor TVecDeque.Create(aAllocator: IAllocator);
begin
  Create(VECDEQUE_DEFAULT_CAPACITY, aAllocator, GetDefaultGrowStrategy, nil);
end;


constructor TVecDeque.Create(aCapacity: SizeUInt);
begin
  Create(aCapacity, GetRtlAllocator(), GetDefaultGrowStrategy, nil);
end;

constructor TVecDeque.Create(aCapacity: SizeUInt; aAllocator: IAllocator);
begin
  Create(aCapacity, aAllocator, GetDefaultGrowStrategy, nil);
end;

constructor TVecDeque.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aCapacity, aAllocator, aGrowStrategy, nil);
end;

constructor TVecDeque.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
var
  LCapacity: SizeUInt;
begin
  inherited Create(aAllocator, aData);
  FGrowStrategy := aGrowStrategy;
  LCapacity := NextPowerOfTwo(Max(aCapacity, SizeUInt(1)));
  FBuffer := TInternalArray.Create(LCapacity, aAllocator);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  UpdateCapacityMask;
end;

constructor TVecDeque.Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aAllocator, aGrowStrategy, nil);
end;

constructor TVecDeque.Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc);
end;

constructor TVecDeque.Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aCount, aAllocator, aGrowStrategy, nil);
end;

constructor TVecDeque.Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc, aCount);
end;

constructor TVecDeque.Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aAllocator, aGrowStrategy, nil);
end;

constructor TVecDeque.Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc);
end;

destructor TVecDeque.Destroy;
begin
  // 接口化统一：策略仅为接口持有，依赖引用计数自动回收
  FGrowStrategy := nil;
  FBuffer.Free;
  inherited Destroy;
end;



{ ICollection 接口实现 }

function TVecDeque.PtrIter: TPtrIter;
begin
  // 零分配迭代器：逻辑索引直接存放在 aIter.Data 中（从 0 开始）
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

function TVecDeque.GetCount: SizeUInt;
begin
  // 使用FCount，提供高效的计数访问
  // 注意：内部一致性由其他方法保证
  Result := FCount;
end;

procedure TVecDeque.Clear;
var
  P1, P2: PElement;
  L1, L2: SizeUInt;
begin
  // 语义：仅清空逻辑长度；容量保持不变
  // 安全性：若 T 为托管类型，需对当前逻辑区间元素做安全清理，避免引用泄露
  if (FCount <> 0) and GetIsManagedType then
  begin
    // 将逻辑区间拆分为至多两段并清理
    GetTwoSlices(P1, L1, P2, L2);
    if L1 > 0 then FElementManager.ZeroElements(P1, L1);
    if L2 > 0 then FElementManager.ZeroElements(P2, L2);
  end;
  // 重置逻辑状态（保持环形缓冲空不变式）
  FCount := 0;
  FHead  := 0;
  FTail  := 0;
end;

procedure TVecDeque.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
  LDstPtr: PByte;
  LElementSize: SizeUInt;
begin
  if aDst = nil then
    raise EArgumentNil.Create('TVecDeque.SerializeToArrayBuffer: aDst is nil');
  if aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.SerializeToArrayBuffer: aCount > Count');
  if aCount = 0 then Exit;

  LDstPtr := PByte(aDst);
  LElementSize := GetElementSize;

  // 使用统一的两段切片拆分
  GetTwoSlices(0, aCount, LPtr1, LLen1, LPtr2, LLen2);
  if LLen1 > 0 then
  begin
    Move(LPtr1^, LDstPtr^, LLen1 * LElementSize);
    Inc(LDstPtr, LLen1 * LElementSize);
  end;
  if LLen2 > 0 then
    Move(LPtr2^, LDstPtr^, LLen2 * LElementSize);
end;

procedure TVecDeque.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  if aElementCount = 0 then
    Exit;

  // 直接使用优化的PushBack批量操作
  PushBack(aSrc, aElementCount);
end;

procedure TVecDeque.AppendToUnChecked(const aDst: TCollection);
var
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if FCount = 0 then
    Exit;
  // 使用统一的两段切片拆分
  GetTwoSlices(LPtr1, LLen1, LPtr2, LLen2);
  if LLen1 > 0 then aDst.AppendUnChecked(LPtr1, LLen1);
  if LLen2 > 0 then aDst.AppendUnChecked(LPtr2, LLen2);
end;

procedure TVecDeque.AppendUnChecked(const aSrc: TCollection);
var
  LSrcVecDeque: TVecDeque;
  LSrcArray: TInternalArray;
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if (aSrc = nil) or aSrc.IsEmpty then
    Exit;

  // 类型优化：同类型 VecDeque 的高效复制
  if aSrc is TVecDeque then
  begin
    LSrcVecDeque := TVecDeque(aSrc);
    // 获取源的两段切片并批量复制
    LSrcVecDeque.GetTwoSlices(LPtr1, LLen1, LPtr2, LLen2);
    if LLen1 > 0 then PushBack(LPtr1, LLen1);
    if LLen2 > 0 then PushBack(LPtr2, LLen2);
  end
  // 类型优化：数组类型的高效复制
  else if aSrc is TInternalArray then
  begin
    LSrcArray := TInternalArray(aSrc);
    if LSrcArray.GetCount > 0 then
      PushBack(LSrcArray.GetMemory, LSrcArray.GetCount);
  end
  else
  begin
    // 通用路径：使用祖先类的默认实现
    inherited AppendUnChecked(aSrc);
  end;
end;

{ 高性能批量操作接口实现 }

procedure TVecDeque.LoadFromPointer(aSrc: PElement; aCount: SizeUInt);
{**
 * 直接加载数据到容器（替换当前内容）
 *
 * 性能优化：
 * - 清除当前内容
 * - 确保容量充足
 * - 批量内存转移
 *
 * 等效于: Clear + AppendFromPointer
 *}
begin
  if aCount = 0 then
  begin
    Clear;
    Exit;
  end;

  if aSrc = nil then
    raise EArgumentNil.Create('TVecDeque.LoadFromPointer: aSrc is nil but aCount > 0');

  Clear;
  EnsureCapacity(aCount);
  PushBack(aSrc, aCount);
end;

procedure TVecDeque.LoadFromArray(const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);
  if LLen = 0 then
  begin
    Clear;
    Exit;
  end;
  LoadFromPointer(@aSrc[0], LLen);
end;

procedure TVecDeque.AppendFrom(const aSrc: TVecDeque; aSrcIndex: SizeUInt; aCount: SizeUInt);
{**
 * 从指定位置追加数据到容器末尾
 *
 * 性能优化：
 * - 确保容量充足（一次性分配）
 * - 处理环形缓冲区跨越情况
 * - 批量内存转移
 *
 * 这个方法将由 TArrayDeque.Append 内部调用
 *}
var
  LSrcPtr1, LSrcPtr2: PElement;
  LSrcLen1, LSrcLen2: SizeUInt;
  LSnapshot: TVecDeque;
  LRequiredCapacity: SizeUInt;
begin
  if (aSrc = nil) or (aCount = 0) then Exit;

  // 验证范围
  if (aSrcIndex > aSrc.Count) or (aCount > aSrc.Count - aSrcIndex) then
    raise EOutOfRange.Create('Source index or count out of range');

  if aSrc = Self then
  begin
    LSnapshot := TVecDeque.Create(aCount, FBuffer.GetAllocator, FGrowStrategy);
    try
      LSnapshot.AppendFrom(Self, aSrcIndex, aCount);
      AppendFrom(LSnapshot, 0, aCount);
    finally
      LSnapshot.Free;
    end;
    Exit;
  end;

  // 提前扩容，避免 PushBack 过程中重新分配导致指针失效
  LRequiredCapacity := RequireAddCount(FCount, aCount, 'TVecDeque.AppendFrom');
  EnsureCapacity(LRequiredCapacity);

  // 获取源的两段切片
  aSrc.GetTwoSlices(aSrcIndex, aCount, LSrcPtr1, LSrcLen1, LSrcPtr2, LSrcLen2);

  // 批量追加
  if LSrcLen1 > 0 then
    PushBack(LSrcPtr1, LSrcLen1);
  if LSrcLen2 > 0 then
    PushBack(LSrcPtr2, LSrcLen2);
end;

procedure TVecDeque.InsertFrom(aIndex: SizeUInt; aSrc: PElement; aCount: SizeUInt);
{**
 * 从指定位置插入批量数据
 *
 * 性能优化：
 * - 确保容量充足
 * - 处理插入位置后的元素移动
 * - 批量内存转移
 *}
begin
  if (aCount = 0) then Exit;

  // 验证位置
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.InsertFrom: index %d out of range [0..%d]', [aIndex, FCount]);

  Insert(aIndex, aSrc, aCount);
end;

procedure TVecDeque.InsertFrom(aIndex: SizeUInt; const aSrc: array of T);
begin
  if Length(aSrc) = 0 then Exit;
  InsertFrom(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TVecDeque.MakeContiguous(out aPtr: PElement; out aLen: SizeUInt);
var
  P1, P2: PElement;
  L1, L2: SizeUInt;
  LElementSize: SizeUInt;
  Tmp: TInternalArray;
  LDst: PByte;
begin
  aPtr := nil; aLen := 0;
  if FCount = 0 then Exit;

  // 若本身已连续（Head <= Tail），直接返回
  if FHead <= FTail then
  begin
    aPtr := FBuffer.GetPtr(FHead);
    aLen := FCount;
    Exit;
  end;

  // 逻辑跨环：整理为连续。策略：用临时数组转存两段，线性覆写回 0..Count-1
  GetTwoSlices(P1, L1, P2, L2);
  LElementSize := GetElementSize;

  // ✅ 优化：使用携带分配器，只分配实际需要的大小
  Tmp := TInternalArray.Create(FBuffer.GetAllocator);
  try
    Tmp.Resize(FCount);  // ✅ 只分配 FCount 而不是 FBuffer.GetCount
    LDst := PByte(Tmp.GetPtr(0));
    if L1 > 0 then begin Move(P1^, LDst^, L1 * LElementSize); Inc(LDst, L1 * LElementSize); end;
    if L2 > 0 then begin Move(P2^, LDst^, L2 * LElementSize); end;

    // 线性覆写回主缓冲的前 Count 段
    FBuffer.OverWrite(0, Tmp, FCount);

    // 修正头尾指针，形成连续 [0..Count)
    FHead := 0;
    FTail := FCount;
  finally
    Tmp.Free;
  end;

  // 返回线性区域
  aPtr := FBuffer.GetPtr(FHead);
  aLen := FCount;
end;


{ IGenericCollection<T> 接口实现 }

procedure TVecDeque.SaveToUnChecked(aDst: TCollection);
begin
  AppendToUnChecked(aDst);
end;

{ IArray<T> 接口实现 }

function TVecDeque.GetMemory: PElement;
begin
  // 注意：环形缓冲区的内存不是连续的，这个方法有局限性
  // 但为了接口兼容性，我们返回第一个元素的指针
  if FCount = 0 then
    Result := nil
  else
    Result := FBuffer.GetPtr(GetPhysicalIndex(0));
end;

function TVecDeque.Get(aIndex: SizeUInt): T;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Get: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  Result := GetUnChecked(aIndex);
end;

function TVecDeque.GetUnChecked(aIndex: SizeUInt): T;
begin
  Result := FBuffer.GetUnChecked(GetPhysicalIndex(aIndex));
end;

procedure TVecDeque.Put(aIndex: SizeUInt; const aElement: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Put: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  PutUnChecked(aIndex, aElement);
end;

procedure TVecDeque.PutUnChecked(aIndex: SizeUInt; const aElement: T);
begin
  FBuffer.PutUnChecked(GetPhysicalIndex(aIndex), aElement);
end;

function TVecDeque.GetPtr(aIndex: SizeUInt): PElement;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.GetPtr: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  Result := GetPtrUnChecked(aIndex);
end;

function TVecDeque.GetPtrUnChecked(aIndex: SizeUInt): PElement;
begin
  Result := FBuffer.GetPtrUnChecked(GetPhysicalIndex(aIndex));
end;

procedure TVecDeque.Resize(aNewSize: SizeUInt);
begin
  if aNewSize > FBuffer.GetCount then
    EnsureCapacity(aNewSize);
  FCount := aNewSize;
end;

procedure TVecDeque.Ensure(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    Resize(aIndex + 1);
end;

procedure TVecDeque.OverWrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.OverWrite: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  OverWriteUnChecked(aIndex, aSrc, aCount);
end;

procedure TVecDeque.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LSrcPtr: PByte;
  LElementSize: SizeUInt;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit;

  LElementSize := GetElementSize;
  LSrcPtr := PByte(aSrc);
  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);

  if LStartPhysical <= LEndPhysical then
  begin
    // 情况1：要覆写的范围是连续的
    Move(LSrcPtr^, FBuffer.GetPtrUnChecked(LStartPhysical)^, aCount * LElementSize);
  end
  else
  begin
    // 情况2：要覆写的范围跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;  // 从起始位置到缓冲区末尾
    LSecondPartSize := aCount - LFirstPartSize;           // 从缓冲区开头的剩余部分

    // 覆写第一段：从起始位置到缓冲区末尾
    Move(LSrcPtr^, FBuffer.GetPtrUnChecked(LStartPhysical)^, LFirstPartSize * LElementSize);
    Inc(LSrcPtr, LFirstPartSize * LElementSize);

    // 覆写第二段：从缓冲区开头
    if LSecondPartSize > 0 then
      Move(LSrcPtr^, FBuffer.GetPtrUnChecked(0)^, LSecondPartSize * LElementSize);
  end;
end;

procedure TVecDeque.OverWrite(aIndex: SizeUInt; const aSrc: array of T);
begin
  OverWrite(aIndex, @aSrc[Low(aSrc)], Length(aSrc));
end;

  { UnChecked: 调用方必须确保前置条件：
    - aSrc 非空（Length(aSrc) > 0），否则引用 @aSrc[Low(aSrc)] 未定义
    - 覆写范围 [aIndex, aIndex + Length(aSrc) - 1] 在当前计数/容量映射的有效范围内（VecDeque 为环缓，覆盖可能跨两段）
    - 本方法不做任何参数/边界检查，违反前置条件将导致未定义行为 }

procedure TVecDeque.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  OverWriteUnChecked(aIndex, @aSrc[Low(aSrc)], Length(aSrc));
end;

procedure TVecDeque.OverWrite(aIndex: SizeUInt; const aSrc: TCollection);
var
  i: SizeUInt;
  LIterator: TPtrIter;
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TVecDeque.OverWrite: aSrc is nil');

  // 由于环形缓冲区的复杂性，我们使用逐个元素复制
  if aIndex + aSrc.GetCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.OverWrite: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aSrc.GetCount - 1, FCount - 1]);

  // 实现集合到集合的复制
  LIterator := aSrc.PtrIter;
  i := aIndex;
  while LIterator.MoveNext and (i < FCount) do
  begin
    FBuffer.PutUnChecked(GetPhysicalIndex(i), PElement(LIterator.GetCurrent)^);
    Inc(i);
  end;
  // zero-allocation iterator: nothing to finalize
end;

procedure TVecDeque.OverWriteUnChecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
var
  i: SizeUInt;
  LIterator: TPtrIter;
  LCopiedCount: SizeUInt;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit;

  LIterator := aSrc.PtrIter;
  // 零分配迭代器：aIter.Data 直接保存逻辑索引，无需释放
  LCopiedCount := 0;
  i := aIndex;
  while LIterator.MoveNext and (LCopiedCount < aCount) and (i < FCount) do
  begin
    FBuffer.PutUnChecked(GetPhysicalIndex(i), PElement(LIterator.GetCurrent)^);
    Inc(i);
    Inc(LCopiedCount);
  end;

  // zero-allocation iterator: nothing to finalize
end;

procedure TVecDeque.Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Read: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  ReadUnChecked(aIndex, aDst, aCount);
end;

procedure TVecDeque.ReadUnChecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LDstPtr: PByte;
  LElementSize: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;

  LElementSize := GetElementSize;
  LDstPtr := PByte(aDst);
  // 利用 GetTwoSlices 拆分区间，简化拷贝分支


  // 手动两段计算以避免引入本地临时 PElement 变量类型声明改动过大
  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);
  if LStartPhysical <= LEndPhysical then
  begin
    Move(FBuffer.GetPtrUnChecked(LStartPhysical)^, LDstPtr^, aCount * LElementSize);
  end
  else
  begin
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;
    LSecondPartSize := aCount - LFirstPartSize;
    Move(FBuffer.GetPtrUnChecked(LStartPhysical)^, LDstPtr^, LFirstPartSize * LElementSize);
    Inc(LDstPtr, LFirstPartSize * LElementSize);
    if LSecondPartSize > 0 then
      Move(FBuffer.GetPtrUnChecked(0)^, LDstPtr^, LSecondPartSize * LElementSize);
  end;
end;

procedure TVecDeque.Read(aIndex: SizeUInt; var aDst: TCollection; aCount: SizeUInt);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Read: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  ReadUnChecked(aIndex, aDst, aCount);
end;

procedure TVecDeque.ReadUnChecked(aIndex: SizeUInt; var aDst: TCollection; aCount: SizeUInt);
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  // Basic implementation - copy elements to destination collection
  aDst.Clear;

  if aCount = 0 then
    Exit;

  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);

  if LStartPhysical <= LEndPhysical then
  begin
    // 情况1：要读取的范围是连续的
    aDst.AppendUnChecked(FBuffer.GetPtrUnChecked(LStartPhysical), aCount);
  end
  else
  begin
    // 情况2：要读取的范围跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;  // 从起始位置到缓冲区末尾
    LSecondPartSize := aCount - LFirstPartSize;           // 从缓冲区开头的剩余部分

    // 读取第一段：从起始位置到缓冲区末尾
    aDst.AppendUnChecked(FBuffer.GetPtrUnChecked(LStartPhysical), LFirstPartSize);

    // 读取第二段：从缓冲区开头
    if LSecondPartSize > 0 then
      aDst.AppendUnChecked(FBuffer.GetPtrUnChecked(0), LSecondPartSize);
  end;
end;

procedure TVecDeque.Swap(aIndex1, aIndex2: SizeUInt);
begin
  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise EOutOfRange.Create('TVecDeque.Swap: index out of range');
  SwapUnChecked(aIndex1, aIndex2);
end;

procedure TVecDeque.SwapUnChecked(aIndex1, aIndex2: SizeUInt);
var
  LTemp: T;
  LPhysical1, LPhysical2: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  LPhysical1 := GetPhysicalIndex(aIndex1);
  LPhysical2 := GetPhysicalIndex(aIndex2);

  LTemp := FBuffer.GetUnChecked(LPhysical1);
  FBuffer.PutUnChecked(LPhysical1, FBuffer.GetUnChecked(LPhysical2));
  FBuffer.PutUnChecked(LPhysical2, LTemp);
end;

procedure TVecDeque.Swap(aIndex1, aIndex2, aCount: SizeUInt);
var
  i: SizeUInt;
  LTemp: T;
  LPhysical1, LPhysical2: SizeUInt;
begin
  if (aIndex1 + aCount > FCount) or (aIndex2 + aCount > FCount) then
    raise EOutOfRange.Create('TVecDeque.Swap: range out of bounds');

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysical1 := GetPhysicalIndex(aIndex1 + i);
    LPhysical2 := GetPhysicalIndex(aIndex2 + i);

    LTemp := FBuffer.GetUnChecked(LPhysical1);
    FBuffer.PutUnChecked(LPhysical1, FBuffer.GetUnChecked(LPhysical2));
    FBuffer.PutUnChecked(LPhysical2, LTemp);
  end;
end;

procedure TVecDeque.Swap(aSrcIndex, aDstIndex, aCount, aStride: SizeUInt);
var
  i: SizeUInt;
  LTemp: T;
  LPhysicalSrc, LPhysicalDst: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalSrc := GetPhysicalIndex(aSrcIndex + i * aStride);
    LPhysicalDst := GetPhysicalIndex(aDstIndex + i * aStride);

    LTemp := FBuffer.GetUnChecked(LPhysicalSrc);
    FBuffer.PutUnChecked(LPhysicalSrc, FBuffer.GetUnChecked(LPhysicalDst));
    FBuffer.PutUnChecked(LPhysicalDst, LTemp);
  end;
end;

procedure TVecDeque.Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  if (aSrcIndex + aCount > FCount) or (aDstIndex + aCount > FCount) then
    raise EOutOfRange.Create('TVecDeque.Copy: range out of bounds');
  CopyUnChecked(aSrcIndex, aDstIndex, aCount);
end;

procedure TVecDeque.CopyUnChecked(aSrcIndex, aDstIndex, aCount: SizeUInt);
var
  i: SizeUInt;
  LSrcPhysical, LDstPhysical: SizeUInt;
begin
  if aCount = 0 then
    Exit;

  if aSrcIndex < aDstIndex then
  begin
    // Copy backwards to avoid overlap issues
    // 优化：减少 GetPhysicalIndex 调用次数
    i := aCount - 1;
    repeat
      LSrcPhysical := GetPhysicalIndex(aSrcIndex + i);
      LDstPhysical := GetPhysicalIndex(aDstIndex + i);
      FBuffer.PutUnChecked(LDstPhysical, FBuffer.GetUnChecked(LSrcPhysical));
      if i = 0 then Break;
      Dec(i);
    until False;
  end
  else
  begin
    // Copy forwards
    // 优化：减少 GetPhysicalIndex 调用次数
    for i := 0 to aCount - 1 do
    begin
      LSrcPhysical := GetPhysicalIndex(aSrcIndex + i);
      LDstPhysical := GetPhysicalIndex(aDstIndex + i);
      FBuffer.PutUnChecked(LDstPhysical, FBuffer.GetUnChecked(LSrcPhysical));
    end;
  end;
end;

procedure TVecDeque.Fill(aIndex: SizeUInt; const aElement: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Fill: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  FBuffer.PutUnChecked(GetPhysicalIndex(aIndex), aElement);
end;

procedure TVecDeque.Fill(aIndex, aCount: SizeUInt; const aElement: T);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Fill: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  FillUnChecked(aIndex, aCount, aElement);
end;

procedure TVecDeque.FillUnChecked(aIndex, aCount: SizeUInt; const aElement: T);
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  if aCount = 0 then
    Exit;

  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);

  if LStartPhysical <= LEndPhysical then
  begin
    // 情况1：要填充的范围是连续的
    FBuffer.FillUnChecked(LStartPhysical, aCount, aElement);
  end
  else
  begin
    // 情况2：要填充的范围跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;  // 从起始位置到缓冲区末尾
    LSecondPartSize := aCount - LFirstPartSize;           // 从缓冲区开头的剩余部分

    // 填充第一段：从起始位置到缓冲区末尾
    FBuffer.FillUnChecked(LStartPhysical, LFirstPartSize, aElement);

    // 填充第二段：从缓冲区开头
    if LSecondPartSize > 0 then
      FBuffer.FillUnChecked(0, LSecondPartSize, aElement);
  end;
end;

procedure TVecDeque.Zero(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Zero: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  FBuffer.Zero(GetPhysicalIndex(aIndex), 1);
end;

procedure TVecDeque.Zero(aIndex, aCount: SizeUInt);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Zero: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  ZeroUnChecked(aIndex, aCount);
end;

procedure TVecDeque.ZeroUnChecked(aIndex, aCount: SizeUInt);
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  if aCount = 0 then
    Exit;

  LStartPhysical := GetPhysicalIndex(aIndex);
  LEndPhysical := GetPhysicalIndex(aIndex + aCount - 1);

  if LStartPhysical <= LEndPhysical then
  begin
    // 情况1：要清零的范围是连续的
    FBuffer.ZeroUnChecked(LStartPhysical, aCount);
  end
  else
  begin
    // 情况2：要清零的范围跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;  // 从起始位置到缓冲区末尾
    LSecondPartSize := aCount - LFirstPartSize;           // 从缓冲区开头的剩余部分

    // 清零第一段：从起始位置到缓冲区末尾
    FBuffer.ZeroUnChecked(LStartPhysical, LFirstPartSize);

    // 清零第二段：从缓冲区开头
    if LSecondPartSize > 0 then
      FBuffer.ZeroUnChecked(0, LSecondPartSize);
  end;
end;

procedure TVecDeque.Reverse(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Reverse: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  // Single element reverse is a no-op
end;

procedure TVecDeque.Reverse(aIndex, aCount: SizeUInt);
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Reverse: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  ReverseUnChecked(aIndex, aCount);
end;

procedure TVecDeque.ReverseUnChecked(aIndex, aCount: SizeUInt);
var
  i, j: SizeUInt;
begin
  if aCount <= 1 then
    Exit;

  i := aIndex;
  j := aIndex + aCount - 1;

  while i < j do
  begin
    SwapUnChecked(i, j);
    Inc(i);
    Dec(j);
  end;
end;

{ Search and algorithm methods - Basic implementations }

function TVecDeque.ForEach(aIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean;
begin
  Result := ForEach(aIndex, FCount - aIndex, aPredicate, aData);
end;

function TVecDeque.ForEach(aIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean;
begin
  Result := ForEach(aIndex, FCount - aIndex, aPredicate, aData);
end;

function TVecDeque.ForEach(aIndex: SizeUInt; aPredicate: TPredicateRefFunc): Boolean;
begin
  Result := ForEach(aIndex, FCount - aIndex, aPredicate);
end;

function TVecDeque.ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.ForEach: range out of bounds');
  Result := ForEachUnChecked(aIndex, aCount, aPredicate, aData);
end;

function TVecDeque.ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.ForEach: range out of bounds');
  Result := ForEachUnChecked(aIndex, aCount, aPredicate, aData);
end;

function TVecDeque.ForEach(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.ForEach: range out of bounds');
  Result := ForEachUnChecked(aIndex, aCount, aPredicate);
end;

function TVecDeque.ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function TVecDeque.ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function TVecDeque.ForEachUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex)) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

{ Contains methods }

function TVecDeque.Contains(const aElement: T; aIndex: SizeUInt): Boolean;
begin
  Result := Contains(aElement, aIndex, FCount - aIndex);
end;

function TVecDeque.Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean;
begin
  Result := Contains(aElement, aIndex, FCount - aIndex, aEquals, aData);
end;

function TVecDeque.Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean;
begin
  Result := Contains(aElement, aIndex, FCount - aIndex, aEquals, aData);
end;

function TVecDeque.Contains(const aElement: T; aIndex: SizeUInt; aEquals: TEqualsRefFunc): Boolean;
begin
  Result := Contains(aElement, aIndex, FCount - aIndex, aEquals);
end;

function TVecDeque.Contains(const aElement: T; aIndex, aCount: SizeUInt): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Contains: range out of bounds');
  Result := ContainsUnChecked(aElement, aIndex, aCount);
end;

function TVecDeque.Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Contains: range out of bounds');
  Result := ContainsUnChecked(aElement, aIndex, aCount, aEquals, aData);
end;

function TVecDeque.Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Contains: range out of bounds');
  Result := ContainsUnChecked(aElement, aIndex, aCount, aEquals, aData);
end;

function TVecDeque.Contains(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): Boolean;
begin
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Contains: range out of bounds');
  Result := ContainsUnChecked(aElement, aIndex, aCount, aEquals);
end;

function TVecDeque.ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LCurrentElement: T;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：一次起算 + WrapAdd 递增，减少 GetPhysicalIndex 调用
  LPhysicalIndex := GetPhysicalIndex(aIndex);
  for i := 0 to aCount - 1 do
  begin
    LCurrentElement := FBuffer.GetUnChecked(LPhysicalIndex);
    if CompareMem(@aElement, @LCurrentElement, GetElementSize) then
      Exit(True);
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;
  Result := False;
end;

function TVecDeque.ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：一次起算 + WrapAdd 递增
  LPhysicalIndex := GetPhysicalIndex(aIndex);
  for i := 0 to aCount - 1 do
  begin
    if aEquals(aElement, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := True;
      Exit;
    end;
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;
  Result := False;
end;

function TVecDeque.ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if aEquals(aElement, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TVecDeque.ContainsUnChecked(const aElement: T; aIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：一次起算 + WrapAdd 递增
  LPhysicalIndex := GetPhysicalIndex(aIndex);
  for i := 0 to aCount - 1 do
  begin
    if aEquals(aElement, FBuffer.GetUnChecked(LPhysicalIndex)) then
      Exit(True);
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;
  Result := False;
end;

{ Find methods }

function TVecDeque.FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：一次起算 + WrapAdd 递增
  LPhysicalIndex := GetPhysicalIndex(aIndex);
  for i := 0 to aCount - 1 do
  begin
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;
  Result := -1;
end;

function TVecDeque.FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindIFUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex)) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindIFNotUnChecked(aIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): Int64;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex)) then
    begin
      Result := Int64(aIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;



{ IVec<T> 接口实现 }

function TVecDeque.GetCapacity: SizeUint;
begin
  Result := FBuffer.GetCount;
end;

procedure TVecDeque.SetCapacity(aCapacity: SizeUint);
begin
  if aCapacity < FCount then
    raise EInvalidArgument.CreateFmt('TVecDeque.SetCapacity: capacity %d < count %d', [aCapacity, FCount]);

  if aCapacity <> FBuffer.GetCount then
    Grow(aCapacity);
end;

procedure TVecDeque.FreeBuffer;
begin
  // 与 TVec.FreeBuffer 语义一致：释放底层缓冲区
  SetCapacity(0);
end;


function TVecDeque.GetGrowStrategy: IGrowthStrategy;
begin
  Result := FGrowStrategy;
end;

procedure TVecDeque.SetGrowStrategy(aGrowStrategy: IGrowthStrategy);
begin
  FGrowStrategy := aGrowStrategy;
end;

function TVecDeque.TryReserve(aAdditional: SizeUint): Boolean;
var
  LRequiredCapacity: SizeUInt;
begin
  if IsAddOverflow(FCount, aAdditional) then
  begin
    Result := False;
    Exit;
  end;

  LRequiredCapacity := FCount + aAdditional;
  if LRequiredCapacity <= FBuffer.GetCount then
  begin
    Result := True;
    Exit;
  end;

  try
    EnsureCapacity(LRequiredCapacity);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TVecDeque.Reserve(aAdditional: SizeUint);
begin
  if not TryReserve(aAdditional) then
    raise EOutOfMemory.Create('TVecDeque.Reserve: failed to reserve additional capacity');
end;

procedure TVecDeque.ShrinkToFit;
var
  LOptimalCapacity: SizeUInt;
begin
  if FCount < FBuffer.GetCount then
  begin
    LOptimalCapacity := CalculateOptimalCapacity(FCount);
    if LOptimalCapacity < FBuffer.GetCount then
      Grow(LOptimalCapacity);
  end;
end;

procedure TVecDeque.ShrinkToFitExact;
var
  LNewCapacity: SizeUInt;
begin
  // 精确贴合当前元素数量（仍保持最小容量和 2 的幂）
  LNewCapacity := NextPowerOfTwo(Max(FCount, SizeUInt(16)));
  if LNewCapacity < FBuffer.GetCount then
    Grow(LNewCapacity);
end;

function TVecDeque.InsertElement(aIndex: SizeUInt; const aElement: T): SizeUInt;
var
  i: SizeUInt;
  LPhysicalI, LPhysicalIPlus1, LPhysicalIMinus1: SizeUInt;
begin
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Insert: index %d out of range [0..%d]', [aIndex, FCount]);

  EnsureCapacity(FCount + 1);

  // 如果插入位置在前半部分，向前移动头部
  if aIndex <= FCount div 2 then
  begin
    // 向前移动头部元素
    if FHead = 0 then
      FHead := FBuffer.GetCount - 1
    else
      Dec(FHead);

    // 向前移动元素 - 优化：减少 GetPhysicalIndex 调用
    for i := 0 to aIndex - 1 do
    begin
      LPhysicalI := GetPhysicalIndex(i);
      LPhysicalIPlus1 := GetPhysicalIndex(i + 1);
      FBuffer.PutUnChecked(LPhysicalI, FBuffer.GetUnChecked(LPhysicalIPlus1));
    end;
  end
  else
  begin
    // 向后移动尾部元素 - 优化：减少 GetPhysicalIndex 调用
    for i := FCount downto aIndex + 1 do
    begin
      LPhysicalI := GetPhysicalIndex(i);
      LPhysicalIMinus1 := GetPhysicalIndex(i - 1);
      FBuffer.PutUnChecked(LPhysicalI, FBuffer.GetUnChecked(LPhysicalIMinus1));
    end;
  end;

  FBuffer.PutUnChecked(GetPhysicalIndex(aIndex), aElement);
  Inc(FCount);
  Result := aIndex;
end;

function TVecDeque.Remove(aIndex: SizeUInt): T;
var
  i, j: SizeUInt;
  LPhysicalI, LPhysicalIPlus1, LPhysicalJ, LPhysicalJMinus1: SizeUInt;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Remove: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  Result := FBuffer.GetUnChecked(GetPhysicalIndex(aIndex));

  // 如果移除位置在前半部分，向后移动头部
  if aIndex <= FCount div 2 then
  begin
    // 向后移动头部元素 - 优化：减少 GetPhysicalIndex 调用
    // 修复：使用 while 循环避免无符号整数下溢导致的无限循环
    j := aIndex;
    while j > 0 do
    begin
      LPhysicalJ := GetPhysicalIndex(j);
      LPhysicalJMinus1 := GetPhysicalIndex(j - 1);
      FBuffer.PutUnChecked(LPhysicalJ, FBuffer.GetUnChecked(LPhysicalJMinus1));
      Dec(j);
    end;

    FHead := WrapAdd(FHead, 1);
  end
  else
  begin
    // 向前移动尾部元素 - 优化：减少 GetPhysicalIndex 调用
    for i := aIndex to FCount - 2 do
    begin
      LPhysicalI := GetPhysicalIndex(i);
      LPhysicalIPlus1 := GetPhysicalIndex(i + 1);
      FBuffer.PutUnChecked(LPhysicalI, FBuffer.GetUnChecked(LPhysicalIPlus1));
    end;
  end;

  Dec(FCount);
end;

function TVecDeque.RemoveSwap(aIndex: SizeUInt): T;
var
  LPhysicalIndex, LPhysicalLast: SizeUInt;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveSwap: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  LPhysicalIndex := GetPhysicalIndex(aIndex);
  Result := FBuffer.GetUnChecked(LPhysicalIndex);

  // 用最后一个元素替换被移除的元素 - 优化：减少 GetPhysicalIndex 调用
  if aIndex < FCount - 1 then
  begin
    LPhysicalLast := GetPhysicalIndex(FCount - 1);
    FBuffer.PutUnChecked(LPhysicalIndex, FBuffer.GetUnChecked(LPhysicalLast));
  end;

  Dec(FCount);
end;

function TVecDeque.Add(const aElement: T): SizeUInt;
begin
  PushBack(aElement);
  Result := FCount - 1;
end;

function TVecDeque.Pop: T;
begin
  Result := PopFront;
end;

function TVecDeque.Peek: T;
begin
  Result := PeekFront;
end;



{ IQueue<T> 队列接口实现 }

procedure TVecDeque.Enqueue(const aElement: T);
begin
  PushBack(aElement);
end;

procedure TVecDeque.Push(const aElement: T);
begin
  PushBack(aElement);
end;

function TVecDeque.Dequeue: T;
begin
  Result := PopFront;
end;

function TVecDeque.Dequeue(var aElement: T): Boolean;
begin
  Result := PopFront(aElement);
end;

function TVecDeque.Pop(out aElement: T): Boolean;
begin
  Result := PopFront(aElement);
end;

function TVecDeque.Peek(out aElement: T): Boolean;
begin
  Result := PeekFront(aElement);
end;



{ IDeque<T> 双端队列接口实现 - 真正的O(1)环形缓冲区实现 }


function TVecDeque.Count: SizeUInt;
begin
  Result := FCount;
end;

procedure TVecDeque.PushFront(const aElement: T);
begin
  if IsFull then
    EnsureCapacity(FCount + 1);

  // 双指针设计：先移动head，再放置元素
  FHead := WrapSub(FHead, 1);
  FBuffer.PutUnChecked(FHead, aElement);
  Inc(FCount);
end;

procedure TVecDeque.PushFront(const aElements: array of T);
var
  LElementCount: SizeUInt;
  LNewHead: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LSrcPtr: Pointer;
  LRequiredCapacity: SizeUInt;



begin
  LElementCount := Length(aElements);
  if LElementCount = 0 then
    Exit;

  // 检查是否需要扩容（双指针设计不需要预留空位，保持与 IsFull/PushBack 一致）
  LRequiredCapacity := RequireAddCount(FCount, LElementCount, 'TVecDeque.PushFront');
  if LRequiredCapacity > FBuffer.GetCount then
    EnsureCapacity(LRequiredCapacity);

  LSrcPtr := @aElements[Low(aElements)];

  if LElementCount <= FHead then
  begin
    // 情况1：有足够空间在头部前面连续放置
    LNewHead := FHead - LElementCount;
    // 正向复制以保持正确顺序：[100,200,300] -> [100,200,300,...]
    CopyForward(LSrcPtr, LNewHead, LElementCount);
  end
  else
  begin
    // 情况2：需要跨越缓冲区边界
    LFirstPartSize := FHead;
    LSecondPartSize := LElementCount - LFirstPartSize;

    // 第一部分：放到头部前面（数组的后半部分）
    if LFirstPartSize > 0 then
      CopyForward(Pointer(PByte(LSrcPtr) + LSecondPartSize * SizeOf(T)), 0, LFirstPartSize);

    // 第二部分：放到缓冲区尾部（数组的前半部分）
    LNewHead := FBuffer.GetCount - LSecondPartSize;
    CopyForward(LSrcPtr, LNewHead, LSecondPartSize);
  end;

  FHead := LNewHead;
  Inc(FCount, LElementCount);
end;

procedure TVecDeque.PushFront(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LNewHead: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LSrcPtr: PByte;
  LElementSize: SizeUInt;
  LRequiredCapacity: SizeUInt;

  procedure CopyReversedBlock(aSrcPtr: Pointer; aDstIndex: SizeUInt; aCount: SizeUInt);
  var
    j: SizeUInt;
    LSrc: PByte;
  begin
    LSrc := PByte(aSrcPtr);
    for j := 0 to aCount - 1 do
      FBuffer.OverWriteUnChecked(aDstIndex + j, LSrc + (aCount - 1 - j) * LElementSize, 1);
  end;

begin
  if aSrc = nil then
  begin
    if aElementCount > 0 then
      raise EArgumentNil.Create('TVecDeque.PushFront: aSrc is nil but aElementCount > 0');
    Exit;
  end;

  if aElementCount = 0 then
    Exit;

  if IsOverlap(aSrc, aElementCount) then
    raise EInvalidArgument.Create('TVecDeque.PushFront: source overlaps with collection memory');

  // 检查是否需要扩容
  LRequiredCapacity := RequireAddCount(FCount, aElementCount, 'TVecDeque.PushFront');
  if LRequiredCapacity > FBuffer.GetCount then
    EnsureCapacity(LRequiredCapacity);

  LElementSize := GetElementSize;
  LSrcPtr := PByte(aSrc);

  if aElementCount <= FHead then
  begin
    // 情况1：有足够空间在头部前面连续放置
    FHead := WrapSub(FHead, aElementCount);
    // 反向复制以保持正确顺序
    CopyReversedBlock(LSrcPtr, FHead, aElementCount);
  end
  else
  begin
    // 情况2：需要跨越缓冲区边界
    LFirstPartSize := FHead;
    LSecondPartSize := aElementCount - LFirstPartSize;

    // 第一部分：放到头部前面（反向）
    if LFirstPartSize > 0 then
      CopyReversedBlock(LSrcPtr + LSecondPartSize * LElementSize, 0, LFirstPartSize);

    // 第二部分：放到缓冲区尾部（反向）
    LNewHead := FBuffer.GetCount - LSecondPartSize;
    CopyReversedBlock(LSrcPtr, LNewHead, LSecondPartSize);

    FHead := LNewHead;
  end;

  Inc(FCount, aElementCount);
end;

procedure TVecDeque.PushBack(const aElement: T);
begin
  if IsFull then
    EnsureCapacity(FCount + 1);

  // 双指针设计：直接在FTail位置放置元素
  FBuffer.PutUnChecked(FTail, aElement);
  FTail := WrapAdd(FTail, 1);
  Inc(FCount);
end;

procedure TVecDeque.PushBack(const aElements: array of T);
var
  LElementCount: SizeUInt;
  LAvailableSpace: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LSrcPtr: Pointer;
  LRequiredCapacity: SizeUInt;
begin
  LElementCount := Length(aElements);
  if LElementCount = 0 then
    Exit;

  // 检查是否需要扩容
  LRequiredCapacity := RequireAddCount(FCount, LElementCount, 'TVecDeque.PushBack');
  if LRequiredCapacity > FBuffer.GetCount then
    EnsureCapacity(LRequiredCapacity);

  // 计算尾部到缓冲区末尾的可用空间
  LAvailableSpace := FBuffer.GetCount - FTail;
  LSrcPtr := @aElements[Low(aElements)];

  if LElementCount <= LAvailableSpace then
  begin
    // 情况1：有足够空间在尾部连续放置 - 使用块复制
    FBuffer.OverWriteUnChecked(FTail, LSrcPtr, LElementCount);
    FTail := WrapAdd(FTail, LElementCount);
  end
  else
  begin
    // 情况2：需要跨越缓冲区边界 - 分两次块复制
    LFirstPartSize := LAvailableSpace;
    LSecondPartSize := LElementCount - LFirstPartSize;

    // 第一部分：复制到尾部剩余空间
    FBuffer.OverWriteUnChecked(FTail, LSrcPtr, LFirstPartSize);

    // 第二部分：复制到缓冲区开头
    FBuffer.OverWriteUnChecked(0,
      Pointer(PByte(LSrcPtr) + LFirstPartSize * SizeOf(T)),
      LSecondPartSize);

    FTail := LSecondPartSize;  // 新的尾部位置
  end;

  Inc(FCount, LElementCount);
end;

procedure TVecDeque.PushBack(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LFirstPartSize, LSecondPartSize: SizeUInt;
  LAvailableSpace: SizeUInt;
  LRequiredCapacity: SizeUInt;
begin
  if aSrc = nil then
  begin
    if aElementCount > 0 then
      raise EArgumentNil.Create('TVecDeque.PushBack: aSrc is nil but aElementCount > 0');
    Exit;
  end;

  if aElementCount = 0 then
    Exit;

  if IsOverlap(aSrc, aElementCount) then
    raise EInvalidArgument.Create('TVecDeque.PushBack: source overlaps with collection memory');

  // 检查是否需要扩容
  LRequiredCapacity := RequireAddCount(FCount, aElementCount, 'TVecDeque.PushBack');
  if LRequiredCapacity > FBuffer.GetCount then
    EnsureCapacity(LRequiredCapacity);

  // 计算尾部到缓冲区末尾的可用空间
  LAvailableSpace := FBuffer.GetCount - FTail;

  if aElementCount <= LAvailableSpace then
  begin
    // 情况1：有足够空间在尾部连续放置
    FBuffer.OverWriteUnChecked(FTail, aSrc, aElementCount);
    FTail := WrapAdd(FTail, aElementCount);
  end
  else
  begin
    // 情况2：需要跨越缓冲区边界
    LFirstPartSize := LAvailableSpace;
    LSecondPartSize := aElementCount - LFirstPartSize;

    // 第一部分：放到尾部剩余空间
    FBuffer.OverWriteUnChecked(FTail, aSrc, LFirstPartSize);

    // 第二部分：放到缓冲区开头
    FBuffer.OverWriteUnChecked(0, PByte(aSrc) + LFirstPartSize * GetElementSize, LSecondPartSize);

    FTail := LSecondPartSize;
  end;

  Inc(FCount, aElementCount);
end;

function TVecDeque.PopFront: T;
begin
  if IsEmpty then
    raise EOutOfRange.Create('TVecDeque.PopFront: deque is empty');

  Result := FBuffer.GetUnChecked(FHead);
  if GetIsManagedType then
    ZeroUnChecked(0, 1);
  FHead := WrapAdd(FHead, 1);
  Dec(FCount);
end;

function TVecDeque.PopFront(var aElement: T): Boolean;
begin
  if IsEmpty then
  begin
    Result := False;
    Exit;
  end;

  aElement := FBuffer.GetUnChecked(FHead);
  if GetIsManagedType then
    ZeroUnChecked(0, 1);
  FHead := WrapAdd(FHead, 1);
  Dec(FCount);
  Result := True;
end;

function TVecDeque.PopBack: T;
begin
  if IsEmpty then
    raise EOutOfRange.Create('TVecDeque.PopBack: deque is empty');

  FTail := WrapSub(FTail, 1);
  Result := FBuffer.GetUnChecked(FTail);
  if GetIsManagedType then
    FBuffer.ZeroUnChecked(FTail, 1);
  Dec(FCount);
end;

function TVecDeque.PopBack(var aElement: T): Boolean;
begin
  if IsEmpty then
  begin
    Result := False;
    Exit;
  end;

  FTail := WrapSub(FTail, 1);
  aElement := FBuffer.GetUnChecked(FTail);
  if GetIsManagedType then
    FBuffer.ZeroUnChecked(FTail, 1);
  Dec(FCount);
  Result := True;
end;

function TVecDeque.PeekFront: T;
begin
  if FCount = 0 then
    raise EOutOfRange.Create('TVecDeque.PeekFront: deque is empty');

  Result := FBuffer.GetUnChecked(FHead);
end;

function TVecDeque.PeekFront(out aElement: T): Boolean;
begin
  if FCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  aElement := FBuffer.GetUnChecked(FHead);
  Result := True;
end;

function TVecDeque.PeekBack: T;
begin
  if FCount = 0 then
    raise EOutOfRange.Create('TVecDeque.PeekBack: deque is empty');

  // 修复：FTail指向下一个插入位置，最后一个元素在WrapSub(FTail, 1)
  Result := FBuffer.GetUnChecked(WrapSub(FTail, 1));
end;

function TVecDeque.PeekBack(out aElement: T): Boolean;
begin
  if FCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  // 修复：FTail指向下一个插入位置，最后一个元素在WrapSub(FTail, 1)
  aElement := FBuffer.GetUnChecked(WrapSub(FTail, 1));
  Result := True;
end;

{ 高级容量管理实现 }

function TVecDeque.GetLoadFactor: Double;
begin
  if FBuffer.GetCount = 0 then
    Result := 0.0
  else
    Result := FCount / FBuffer.GetCount;
end;

function TVecDeque.GetWastedSpace: SizeUInt;
begin
  if FBuffer.GetCount > FCount then
    Result := FBuffer.GetCount - FCount
  else
    Result := 0;
end;

function TVecDeque.ShouldShrink: Boolean;
const
  MIN_LOAD_FACTOR = 0.25;  // 当负载因子低于25%时考虑收缩
  MIN_CAPACITY = 16;       // 最小容量阈值
begin
  Result := (FBuffer.GetCount > MIN_CAPACITY) and
            (GetLoadFactor < MIN_LOAD_FACTOR) and
            (GetWastedSpace > MIN_CAPACITY);
end;

function TVecDeque.ShouldGrow(aAdditionalElements: SizeUInt): Boolean;
begin
  Result := IsAddOverflow(FCount, aAdditionalElements) or
            (FCount + aAdditionalElements > FBuffer.GetCount);
end;

function TVecDeque.CalculateOptimalCapacity(aRequiredSize: SizeUInt): SizeUInt;
const
  MIN_CAPACITY = 16;  // 最小容量，已经是2的幂
begin
  // 确保最小容量
  Result := Max(aRequiredSize, MIN_CAPACITY);

  // 强制使用2的幂容量以支持位运算优化
  if aRequiredSize > FBuffer.GetCount then
  begin
    // 增长时：使用2的幂策略
    if FGrowStrategy <> nil then
    begin
      try
        Result := FGrowStrategy.GetGrowSize(FBuffer.GetCount, aRequiredSize);
      except
        // 如果调用失败，使用默认策略
        Result := Max(FBuffer.GetCount * 2, aRequiredSize);
      end;
      // 确保结果是2的幂
      Result := NextPowerOfTwo(Result);
    end
    else
    begin
      // 默认策略：至少翻倍，但不超过所需大小的4倍
      Result := Max(FBuffer.GetCount * 2, aRequiredSize);
      Result := NextPowerOfTwo(Result);

      // 限制过度增长
      if Result > aRequiredSize * 4 then
        Result := NextPowerOfTwo(aRequiredSize * 2);
    end;
  end
  else
  begin
    // 收缩时：保持2的幂，但留有一定余量
    Result := NextPowerOfTwo(Max(Trunc(aRequiredSize * 1.25), MIN_CAPACITY));
  end;
end;

procedure TVecDeque.OptimizeCapacity;
var
  LOptimalCapacity: SizeUInt;
begin
  if ShouldShrink then
  begin
    LOptimalCapacity := CalculateOptimalCapacity(FCount);
    if LOptimalCapacity < FBuffer.GetCount then
      Grow(LOptimalCapacity);
  end;
end;

{ 批量移除操作实现 }

procedure TVecDeque.RemoveRange(aIndex, aCount: SizeUInt);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveRange: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveRange: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  RemoveRangeUnChecked(aIndex, aCount);
end;

procedure TVecDeque.RemoveRangeUnChecked(aIndex, aCount: SizeUInt);
var
  LElementsAfter: SizeUInt;
  LElementsBefore: SizeUInt;
  i, j: SizeUInt;
  LPhysicalI, LPhysicalIMinusCount, LPhysicalJ, LPhysicalJPlusCount: SizeUInt;
begin
  if aCount = 0 then
    Exit;

  if GetIsManagedType then
    ZeroUnChecked(aIndex, aCount);

  LElementsBefore := aIndex;
  LElementsAfter := FCount - aIndex - aCount;

  // 选择移动较少元素的策略
  if LElementsBefore <= LElementsAfter then
  begin
    // 向后移动前面的元素
    // 修复：安全处理 aIndex = 0 的情况，避免下溢
    if aIndex > 0 then
    begin
      j := aIndex - 1;
      repeat
        LPhysicalJPlusCount := GetPhysicalIndex(j + aCount);
        LPhysicalJ := GetPhysicalIndex(j);
        FBuffer.PutUnChecked(LPhysicalJPlusCount, FBuffer.GetUnChecked(LPhysicalJ));
        if j = 0 then Break;
        Dec(j);
      until False;
    end;

    // 更新头部位置
    FHead := WrapAdd(FHead, aCount);
  end
  else
  begin
    // 向前移动后面的元素 - 优化：减少 GetPhysicalIndex 调用
    for i := aIndex + aCount to FCount - 1 do
    begin
      LPhysicalIMinusCount := GetPhysicalIndex(i - aCount);
      LPhysicalI := GetPhysicalIndex(i);
      FBuffer.PutUnChecked(LPhysicalIMinusCount, FBuffer.GetUnChecked(LPhysicalI));
    end;
  end;

  Dec(FCount, aCount);

  // 检查是否需要优化容量
  if ShouldShrink then
    OptimizeCapacity;
end;

function TVecDeque.PopFrontRange(aCount: SizeUInt): SizeUInt;
begin
  Result := Min(aCount, FCount);
  if Result > 0 then
  begin
    if GetIsManagedType then
      ZeroUnChecked(0, Result);
    FHead := WrapAdd(FHead, Result);
    Dec(FCount, Result);

    if ShouldShrink then
      OptimizeCapacity;
  end;
end;

function TVecDeque.PopBackRange(aCount: SizeUInt): SizeUInt;
begin
  Result := Min(aCount, FCount);
  if Result > 0 then
  begin
    if GetIsManagedType then
      ZeroUnChecked(FCount - Result, Result);
    Dec(FCount, Result);
    FTail := WrapSub(FTail, Result);  // ✅ 修复：正确更新 FTail 指针

    if ShouldShrink then
      OptimizeCapacity;
  end;
end;

procedure TVecDeque.PopFrontRange(aCount: SizeUInt; const aTarget: TCollection);
var
  LActualCount: SizeUInt;
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if aTarget = nil then
    raise EArgumentNil.Create('aTarget cannot be nil');

  LActualCount := Min(aCount, FCount);
  if LActualCount = 0 then Exit;

  // 获取前端的双切片
  GetTwoSlices(0, LActualCount, LPtr1, LLen1, LPtr2, LLen2);

  // 批量添加到目标容器
  if LLen1 > 0 then aTarget.AppendUnChecked(LPtr1, LLen1);
  if LLen2 > 0 then aTarget.AppendUnChecked(LPtr2, LLen2);

  if GetIsManagedType then
    ZeroUnChecked(0, LActualCount);

  // 更新状态
  FHead := WrapAdd(FHead, LActualCount);
  Dec(FCount, LActualCount);

  if ShouldShrink then
    OptimizeCapacity;
end;

procedure TVecDeque.PopBackRange(aCount: SizeUInt; const aTarget: TCollection);
var
  LActualCount: SizeUInt;
  LStartIndex: SizeUInt;
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if aTarget = nil then
    raise EArgumentNil.Create('aTarget cannot be nil');

  LActualCount := Min(aCount, FCount);
  if LActualCount = 0 then Exit;

  // 从后端开始的索引
  LStartIndex := FCount - LActualCount;
  GetTwoSlices(LStartIndex, LActualCount, LPtr1, LLen1, LPtr2, LLen2);

  // 批量添加到目标容器
  if LLen1 > 0 then aTarget.AppendUnChecked(LPtr1, LLen1);
  if LLen2 > 0 then aTarget.AppendUnChecked(LPtr2, LLen2);

  if GetIsManagedType then
    ZeroUnChecked(LStartIndex, LActualCount);

  // 更新状态
  FTail := WrapSub(FTail, LActualCount);
  Dec(FCount, LActualCount);

  if ShouldShrink then
    OptimizeCapacity;
end;

procedure TVecDeque.TrimFront(aCount: SizeUInt);
var
  LActualCount: SizeUInt;
begin
  LActualCount := Min(aCount, FCount);
  PopFrontRange(LActualCount);
end;

procedure TVecDeque.TrimBack(aCount: SizeUInt);
var
  LActualCount: SizeUInt;
begin
  LActualCount := Min(aCount, FCount);
  PopBackRange(LActualCount);
end;

procedure TVecDeque.TrimToSize(aNewSize: SizeUInt);
begin
  if aNewSize >= FCount then
    Exit;

  // 从后面移除多余元素
  TrimBack(FCount - aNewSize);
end;

{ 双端队列特有算法实现 }

procedure TVecDeque.Rotate(aPositions: Integer);
begin
  if aPositions > 0 then
    RotateLeft(SizeUInt(aPositions))
  else if aPositions < 0 then
    RotateRight(SizeUInt(-aPositions));
end;

procedure TVecDeque.RotateLeft(aPositions: SizeUInt);
var
  LActualPositions: SizeUInt;
  i: SizeUInt;
  LElement: T;
begin
  if (FCount <= 1) or (aPositions = 0) then
    Exit;

  LActualPositions := aPositions mod FCount;
  if LActualPositions = 0 then
    Exit;

  // 将前面的元素移动到后面
  for i := 1 to LActualPositions do
  begin
    LElement := PopFront;
    PushBack(LElement);
  end;
end;

procedure TVecDeque.RotateRight(aPositions: SizeUInt);
var
  LActualPositions: SizeUInt;
  i: SizeUInt;
  LElement: T;
begin
  if (FCount <= 1) or (aPositions = 0) then
    Exit;

  LActualPositions := aPositions mod FCount;
  if LActualPositions = 0 then
    Exit;

  // 将后面的元素移动到前面
  for i := 1 to LActualPositions do
  begin
    LElement := PopBack;
    PushFront(LElement);
  end;
end;

function TVecDeque.Split(aIndex: SizeUInt): TVecDeque;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Split: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  // 创建新的VecDeque包含从aIndex开始的所有元素
  Result := TVecDeque.Create(FCount - aIndex, GetAllocator);

  // 复制元素到新的VecDeque - 优化：减少 GetPhysicalIndex 调用
  for i := aIndex to FCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(i);
    Result.PushBack(FBuffer.GetUnChecked(LPhysicalIndex));
  end;

  // 从当前VecDeque中移除这些元素
  TrimToSize(aIndex);
end;

procedure TVecDeque.Merge(const aOther: TVecDeque; aPosition: TMergePosition);
var
  i: SizeUInt;
begin
  if aOther = nil then
    Exit;

  case aPosition of
    mpFront:
      begin
        // 在前面合并：将aOther的元素添加到前面
        for i := aOther.GetCount - 1 downto 0 do
          PushFront(aOther.GetUnChecked(i));
      end;
    mpBack:
      begin
        // 在后面合并：将aOther的元素添加到后面
        for i := 0 to aOther.GetCount - 1 do
          PushBack(aOther.GetUnChecked(i));
      end;
    mpReplace:
      begin
        // 替换：清空当前内容，复制aOther的内容
        Clear;
        for i := 0 to aOther.GetCount - 1 do
          PushBack(aOther.GetUnChecked(i));
      end;
  end;
end;

procedure TVecDeque.SwapEnds;
var
  LFrontElement, LBackElement: T;
begin
  if FCount < 2 then
    Exit;

  LFrontElement := PopFront;
  LBackElement := PopBack;
  PushFront(LBackElement);
  PushBack(LFrontElement);
end;

procedure TVecDeque.MoveToFront(aIndex: SizeUInt);
var
  LElement: T;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.MoveToFront: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  if aIndex = 0 then
    Exit;

  LElement := Remove(aIndex);
  PushFront(LElement); // explicit index remove; RemoveValue refers to by-value removal
end;

procedure TVecDeque.MoveToBack(aIndex: SizeUInt);
var
  LElement: T;
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.MoveToBack: index %d out of range [0..%d]', [aIndex, FCount - 1]);

  if aIndex = FCount - 1 then
    Exit;

  LElement := Remove(aIndex);
  PushBack(LElement);
end;

{ 2的幂容量相关辅助方法 }

function TVecDeque.NextPowerOfTwo(aValue: SizeUInt): SizeUInt;
begin
  if aValue <= 1 then
  begin
    Result := 1;
    Exit;
  end;

  // 使用位运算找到下一个2的幂
  Result := 1;
  while Result < aValue do
    Result := Result shl 1;

  // 防止溢出
  if Result = 0 then
    Result := High(SizeUInt) shr 1 + 1;
end;

function TVecDeque.IsPowerOfTwo(aValue: SizeUInt): Boolean;
begin
  Result := (aValue > 0) and ((aValue and (aValue - 1)) = 0);
end;

procedure TVecDeque.UpdateCapacityMask;
begin
  if IsPowerOfTwo(FBuffer.GetCount) then
    FCapacityMask := FBuffer.GetCount - 1
  else
    FCapacityMask := 0;  // 标记为非2的幂，回退到模运算
end;

procedure TVecDeque.SyncCountAndTail;
begin
  // 根据FCount计算FTail位置
  FTail := WrapAdd(FHead, FCount);
end;

function TVecDeque.GetDefaultGrowStrategy: IGrowthStrategy;
begin
  // nil 表示使用内置的 2 的幂增长策略
  Result := nil;
end;

function TVecDeque.ChooseOptimalGrowStrategy(aFirstPartSize, aSecondPartSize, aNewCapacity: SizeUInt): Integer;
var
  LTotalSize: SizeUInt;
  LWasteRatio: Double;
  LFragmentationCost: Double;
begin
  LTotalSize := aFirstPartSize + aSecondPartSize;

  // 策略0：连续放置在开头 - 简单但可能浪费尾部空间
  // 策略1：连续放置在中间 - 平衡两端增长空间，推荐用于大多数情况
  // 策略2：保持分段 - 适用于特殊情况，减少复制开销

  // 如果新容量相对较小，优先选择连续布局
  if aNewCapacity < LTotalSize * 2 then
  begin
    Result := 0;  // 连续放置在开头
    Exit;
  end;

  // 计算浪费空间比例
  LWasteRatio := (aNewCapacity - LTotalSize) / aNewCapacity;

  // 如果浪费空间很多，使用居中策略以平衡两端增长
  if LWasteRatio > 0.5 then
  begin
    Result := 1;  // 连续放置在中间
    Exit;
  end;

  // 计算分段的碎片化成本
  if aFirstPartSize >= aSecondPartSize then
    LFragmentationCost := (aFirstPartSize - aSecondPartSize) / LTotalSize
  else
    LFragmentationCost := (aSecondPartSize - aFirstPartSize) / LTotalSize;

  // 如果两段大小相近且总体较大，考虑保持分段以减少复制
  if (LFragmentationCost < 0.3) and (LTotalSize > aNewCapacity div 4) then
  begin
    Result := 2;  // 保持分段但优化位置
  end
  else
  begin
    Result := 1;  // 默认：连续放置在中间
  end;
end;

// CountOf 系列方法实现
function TVecDeque.CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
var
  LStartPhysical, LEndPhysical: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
  i: SizeUInt;
  LElementSize: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  LElementSize := GetElementSize;
  LStartPhysical := GetPhysicalIndex(aStartIndex);
  LEndPhysical := GetPhysicalIndex(aStartIndex + aCount - 1);

  if LStartPhysical <= LEndPhysical then
  begin
    // 情况1：要搜索的范围是连续的 - 优化内存访问
    for i := LStartPhysical to LStartPhysical + aCount - 1 do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
        Inc(Result);
    end;
  end
  else
  begin
    // 情况2：要搜索的范围跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - LStartPhysical;
    LSecondPartSize := aCount - LFirstPartSize;

    // 搜索第一段：从起始位置到缓冲区末尾
    for i := LStartPhysical to FBuffer.GetCount - 1 do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
        Inc(Result);
    end;

    // 搜索第二段：从缓冲区开头
    for i := 0 to LSecondPartSize - 1 do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
        Inc(Result);
    end;
  end;
end;

function TVecDeque.CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
      Inc(Result);
  end;
end;

function TVecDeque.CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
      Inc(Result);
  end;
end;

function TVecDeque.CountOfUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aValue, FBuffer.GetUnChecked(LPhysicalIndex)) then
      Inc(Result);
  end;
end;

// CountIf 系列方法实现
function TVecDeque.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
      Inc(Result);
  end;
end;

function TVecDeque.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
      Inc(Result);
  end;
end;

function TVecDeque.CountIfUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex)) then
      Inc(Result);
  end;
end;

// Replace 系列方法实现
function TVecDeque.ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
var
  i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  for i := 0 to aCount - 1 do
  begin
    if CompareMem(@aOldValue, GetPtrUnChecked(aStartIndex + i), GetElementSize) then
    begin
      PutUnChecked(aStartIndex + i, aNewValue);
      Inc(Result);
    end;
  end;
end;

function TVecDeque.ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aOldValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      FBuffer.PutUnChecked(LPhysicalIndex, aNewValue);
      Inc(Result);
    end;
  end;
end;

function TVecDeque.ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aOldValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      FBuffer.PutUnChecked(LPhysicalIndex, aNewValue);
      Inc(Result);
    end;
  end;
end;

function TVecDeque.ReplaceUnChecked(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aOldValue, FBuffer.GetUnChecked(LPhysicalIndex)) then
    begin
      FBuffer.PutUnChecked(LPhysicalIndex, aNewValue);
      Inc(Result);
    end;
  end;
end;

// ReplaceIF 系列方法实现
function TVecDeque.ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      FBuffer.PutUnChecked(LPhysicalIndex, aNewValue);
      Inc(Result);
    end;
  end;
end;

function TVecDeque.ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  for i := 0 to aCount - 1 do
  begin
    if aPredicate(GetUnChecked(aStartIndex + i), aData) then
    begin
      PutUnChecked(aStartIndex + i, aNewValue);
      Inc(Result);
    end;
  end;
end;

function TVecDeque.ReplaceIFUnChecked(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;
var
  i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then
    Exit;

  for i := 0 to aCount - 1 do
  begin
    if aPredicate(GetUnChecked(aStartIndex + i)) then
    begin
      PutUnChecked(aStartIndex + i, aNewValue);
      Inc(Result);
    end;
  end;
end;

// IsSorted 系列方法实现
function TVecDeque.IsSortedUnChecked(aStartIndex, aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LPhysical1, LPhysical2: SizeUInt;
begin
  if aCount <= 1 then
    Exit(True);

  // 使用内部默认比较器进行检查
  for i := 1 to aCount - 1 do
  begin
    LPhysical1 := GetPhysicalIndex(aStartIndex + i - 1);
    LPhysical2 := GetPhysicalIndex(aStartIndex + i);
    if FInternalComparer(FBuffer.GetUnChecked(LPhysical1), FBuffer.GetUnChecked(LPhysical2)) > 0 then
      Exit(False);
  end;
  Result := True;
end;

function TVecDeque.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
var
  i: SizeUInt;
  LPhysical1, LPhysical2: SizeUInt;
begin
  if aCount <= 1 then
    Exit(True);

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 1 to aCount - 1 do
  begin
    LPhysical1 := GetPhysicalIndex(aStartIndex + i - 1);
    LPhysical2 := GetPhysicalIndex(aStartIndex + i);
    if aComparer(FBuffer.GetUnChecked(LPhysical1), FBuffer.GetUnChecked(LPhysical2), aData) > 0 then
      Exit(False);
  end;
  Result := True;
end;

function TVecDeque.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  if aCount <= 1 then
    Exit(True);

  for i := 1 to aCount - 1 do
  begin
    if aComparer(GetUnChecked(aStartIndex + i - 1), GetUnChecked(aStartIndex + i), aData) > 0 then
      Exit(False);
  end;
  Result := True;
end;

function TVecDeque.IsSortedUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): Boolean;
var
  i: SizeUInt;
begin
  if aCount <= 1 then
    Exit(True);

  for i := 1 to aCount - 1 do
  begin
    if aComparer(GetUnChecked(aStartIndex + i - 1), GetUnChecked(aStartIndex + i)) > 0 then
      Exit(False);
  end;
  Result := True;
end;

// BinarySearch 系列方法实现
function TVecDeque.BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
  LPhysicalMid: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);


  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    LPhysicalMid := GetPhysicalIndex(Mid);
    CompareResult := FInternalComparer(FBuffer.GetUnChecked(LPhysicalMid), aValue);

    if CompareResult = 0 then
      Exit(SizeInt(Mid))
    else if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then Break; // 防止 SizeUInt 下溢
      Right := Mid - 1;
    end;
  end;
  Result := -1;
end;

function TVecDeque.BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(-1);

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue, aData);

    if CompareResult = 0 then
      Exit(SizeInt(Mid))
    else if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := -1;
end;

function TVecDeque.BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(-1);

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue, aData);

    if CompareResult = 0 then
      Exit(SizeInt(Mid))
    else if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := -1;
end;

function TVecDeque.BinarySearchUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(-1);

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue);

    if CompareResult = 0 then
      Exit(SizeInt(Mid))
    else if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := -1;
end;

// BinarySearchInsert 系列方法实现
function TVecDeque.BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
  LPhysicalMid: SizeUInt;
begin
  if aCount = 0 then
    Exit(SizeInt(aStartIndex));


  Left := aStartIndex;
  Right := aStartIndex + aCount;

  while Left < Right do
  begin
    Mid := Left + (Right - Left) div 2;
    LPhysicalMid := GetPhysicalIndex(Mid);
    CompareResult := FInternalComparer(FBuffer.GetUnChecked(LPhysicalMid), aValue);

    if CompareResult < 0 then
      Left := Mid + 1
    else
      Right := Mid;
  end;
  Result := SizeInt(Left);
end;

function TVecDeque.BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue, aData);

    if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := SizeInt(Left);
end;

function TVecDeque.BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue, aData);

    if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := SizeInt(Left);
end;

function TVecDeque.BinarySearchInsertUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
var
  Left, Right, Mid: SizeUInt;
  CompareResult: Integer;
begin
  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  Left := aStartIndex;
  Right := aStartIndex + aCount - 1;

  while Left <= Right do
  begin
    Mid := Left + (Right - Left) div 2;
    CompareResult := aComparer(GetUnChecked(Mid), aValue);

    if CompareResult < 0 then
      Left := Mid + 1
    else
    begin
      if Mid = 0 then
        Break;
      Right := Mid - 1;
    end;
  end;

  Result := SizeInt(Left);
end;

// Shuffle 系列方法实现
procedure TVecDeque.ShuffleUnChecked(aStartIndex, aCount: SizeUInt);
var
  i, j: SizeUInt;
begin
  if aCount <= 1 then
    Exit;

  // Fisher-Yates shuffle算法，使用系统默认随机数生成器
  for i := aCount - 1 downto 1 do
  begin
    j := System.Random(Integer(i + 1));
    SwapUnChecked(aStartIndex + i, aStartIndex + j);
  end;
end;

procedure TVecDeque.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
var
  i, j: SizeUInt;
begin
  if aCount <= 1 then
    Exit;

  // Fisher-Yates shuffle算法，使用自定义随机数生成器
  for i := aCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1, aData);
    SwapUnChecked(aStartIndex + i, aStartIndex + j);
  end;
end;

procedure TVecDeque.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
var
  i, j: SizeUInt;
begin
  if aCount <= 1 then
    Exit;

  // Fisher-Yates shuffle算法，使用自定义随机数生成器
  for i := aCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1, aData);
    SwapUnChecked(aStartIndex + i, aStartIndex + j);
  end;
end;

procedure TVecDeque.ShuffleUnChecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
var
  i, j: SizeUInt;
begin
  if aCount <= 1 then
    Exit;

  // Fisher-Yates shuffle算法，使用自定义随机数生成器
  for i := aCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1);
    SwapUnChecked(aStartIndex + i, aStartIndex + j);
  end;
end;

{ IArray<T> 接口实现 - 占位符实现 }

procedure TVecDeque.Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
begin
  // 边界检查
  if aIndex >= GetCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Read: index %d out of range [0..%d]', [aIndex, GetCount - 1]);

  if aIndex + aCount > GetCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Read: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, GetCount - 1]);

  ReadUnChecked(aIndex, aDst, aCount);
end;

procedure TVecDeque.ReadUnChecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
var
  i: SizeUInt;
begin
  // 确保目标数组有足够的空间
  if Length(aDst) < aCount then
    SetLength(aDst, aCount);

  // 复制元素
  for i := 0 to aCount - 1 do
  begin
    aDst[i] := GetUnChecked(aIndex + i);
  end;
end;

function TVecDeque.Find(const aValue: T): SizeInt;
begin
  Result := Find(aValue, 0, GetCount);
end;

function TVecDeque.Find(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
begin
  Result := Find(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.Find(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
begin
  Result := Find(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.Find(const aValue: T; aEquals: TEqualsRefFunc): SizeInt;
begin
  Result := Find(aValue, 0, GetCount, aEquals);
end;

function TVecDeque.Find(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := Find(aValue, aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := Find(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := Find(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := Find(aValue, aStartIndex, GetCount - aStartIndex, aEquals);
end;

function TVecDeque.Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := FindUnChecked(aValue, aStartIndex, aCount);
end;

function TVecDeque.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LMaxIndex: SizeInt;
  LIsFullRange: Boolean;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  // 检查是否是全范围搜索
  LIsFullRange := (aStartIndex = 0) and (aCount = GetCount);

  if LIsFullRange then
  begin
    // 全范围搜索：返回第一次出现
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i), aData) then
      begin
        Result := SizeInt(i);
        Exit;
      end;
    end;
    Result := -1;
  end
  else
  begin
    // 部分范围搜索：返回最后一次出现在指定范围内
    LMaxIndex := -1;
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i), aData) then
        LMaxIndex := i;
    end;
    Result := LMaxIndex;
  end;
end;

function TVecDeque.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LMaxIndex: SizeInt;
  LIsFullRange: Boolean;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  // 检查是否是全范围搜索
  LIsFullRange := (aStartIndex = 0) and (aCount = GetCount);

  if LIsFullRange then
  begin
    // 全范围搜索：返回第一次出现
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i), aData) then
      begin
        Result := SizeInt(i);
        Exit;
      end;
    end;
    Result := -1;
  end
  else
  begin
    // 部分范围搜索：返回最后一次出现在指定范围内
    LMaxIndex := -1;
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i), aData) then
        LMaxIndex := i;
    end;
    Result := LMaxIndex;
  end;
end;

function TVecDeque.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
var
  i: SizeUInt;
  LMaxIndex: SizeInt;
  LIsFullRange: Boolean;
begin
  // 边界检查
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  // 检查是否是全范围搜索
  LIsFullRange := (aStartIndex = 0) and (aCount = GetCount);

  if LIsFullRange then
  begin
    // 全范围搜索：返回第一次出现
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i)) then
      begin
        Result := SizeInt(i);
        Exit;
      end;
    end;
    Result := -1;
  end
  else
  begin
    // 部分范围搜索：返回最后一次出现在指定范围内
    LMaxIndex := -1;
    for i := aStartIndex to aStartIndex + aCount - 1 do
    begin
      if aEquals(aValue, GetUnChecked(i)) then
        LMaxIndex := i;
    end;
    Result := LMaxIndex;
  end;
end;

function TVecDeque.FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
var
  i: SizeUInt;
begin
  // 使用默认的内存比较
  for i := 0 to aCount - 1 do
  begin
    if CompareMem(@aValue, GetPtrUnChecked(aStartIndex + i), GetElementSize) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aEquals(aValue, FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
var
  i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
  begin
    if aEquals(aValue, GetUnChecked(aStartIndex + i)) then
    begin
      Result := SizeInt(aStartIndex + i);  // 返回逻辑索引
      Exit;
    end;
  end;
  Result := -1;
end;

function TVecDeque.FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  // 从后往前搜索
  // 修复：使用安全的循环避免无符号整数下溢
  i := aCount - 1;
  repeat
    if CompareMem(@aValue, GetPtrUnChecked(aStartIndex + i), GetElementSize) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;

    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  // 从后往前搜索
  // 修复：使用安全的循环避免无符号整数下溢
  i := aCount - 1;
  repeat
    if aEquals(aValue, GetUnChecked(aStartIndex + i), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;

    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  // 从后往前搜索
  // 修复：使用安全的循环避免无符号整数下溢
  i := aCount - 1;
  repeat
    if aEquals(aValue, GetUnChecked(aStartIndex + i), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;

    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastUnChecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  // 从后往前搜索
  // 修复：使用安全的循环避免无符号整数下溢
  i := aCount - 1;
  repeat
    if aEquals(aValue, GetUnChecked(aStartIndex + i)) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;

    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  // 从后往前搜索，避免无符号下溢
  i := aCount - 1;
  repeat
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  i := aCount - 1;
  repeat
    if aPredicate(GetUnChecked(aStartIndex + i), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  i := aCount - 1;
  repeat
    if aPredicate(GetUnChecked(aStartIndex + i)) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  i := aCount - 1;
  repeat
    LPhysicalIndex := GetPhysicalIndex(aStartIndex + i);
    if not aPredicate(FBuffer.GetUnChecked(LPhysicalIndex), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  i := aCount - 1;
  repeat
    if not aPredicate(GetUnChecked(aStartIndex + i), aData) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

function TVecDeque.FindLastIFNotUnChecked(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  i := aCount - 1;
  repeat
    if not aPredicate(GetUnChecked(aStartIndex + i)) then
    begin
      Result := SizeInt(aStartIndex + i);
      Exit;
    end;
    if i = 0 then Break;
    Dec(i);
  until False;
  Result := -1;
end;

// ReplaceIF 系列方法实现
procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  ReplaceIF(aNewValue, aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  ReplaceIF(aNewValue, aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  ReplaceIF(aNewValue, aStartIndex, GetCount - aStartIndex, aPredicate);
end;

procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceIFUnChecked(aNewValue, aStartIndex, aCount, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceIFUnChecked(aNewValue, aStartIndex, aCount, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIF(const aNewValue: T; aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceIFUnChecked(aNewValue, aStartIndex, aCount, aPredicate);
end;

// IsSorted 系列方法实现
function TVecDeque.IsSorted(aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  Result := IsSorted(aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.IsSorted(aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  Result := IsSorted(aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.IsSorted(aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  Result := IsSorted(aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.IsSorted(aStartIndex: SizeUInt; aComparer: TCompareRefFunc): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  Result := IsSorted(aStartIndex, GetCount - aStartIndex, aComparer);
end;

function TVecDeque.IsSorted(aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  if aCount <= 1 then
    Exit(True);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := IsSortedUnChecked(aStartIndex, aCount);
end;

function TVecDeque.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  if aCount <= 1 then
    Exit(True);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  if aCount <= 1 then
    Exit(True);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): Boolean;
begin
  if aStartIndex >= GetCount then
    Exit(True);

  if aCount <= 1 then
    Exit(True);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := IsSortedUnChecked(aStartIndex, aCount, aComparer);
end;

// FindIF 系列方法实现
function TVecDeque.FindIF(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  Result := FindIF(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindIF(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  Result := FindIF(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindIF(aPredicate: TPredicateRefFunc): SizeInt;
begin
  Result := FindIF(0, GetCount, aPredicate);
end;

function TVecDeque.FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIF(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIF(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindIF(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIF(aStartIndex, GetCount - aStartIndex, aPredicate);
end;

function TVecDeque.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := SizeInt(TempResult);
end;

function TVecDeque.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := SizeInt(TempResult);
end;

function TVecDeque.FindIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFUnChecked(aStartIndex, aCount, aPredicate);
  Result := SizeInt(TempResult);
end;

// FindIFNot 系列方法实现
function TVecDeque.FindIFNot(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  Result := FindIFNot(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindIFNot(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  Result := FindIFNot(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindIFNot(aPredicate: TPredicateRefFunc): SizeInt;
begin
  Result := FindIFNot(0, GetCount, aPredicate);
end;

function TVecDeque.FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIFNot(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIFNot(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindIFNot(aStartIndex, GetCount - aStartIndex, aPredicate);
end;

function TVecDeque.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := SizeInt(TempResult);
end;

function TVecDeque.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := SizeInt(TempResult);
end;

function TVecDeque.FindIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  TempResult: Int64;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  TempResult := FindIFNotUnChecked(aStartIndex, aCount, aPredicate);
  Result := SizeInt(TempResult);
end;

// FindLast 系列方法实现
function TVecDeque.FindLast(const aValue: T): SizeInt;
begin
  if GetCount = 0 then
    Exit(-1);

  Result := FindLast(aValue, 0, GetCount);
end;

function TVecDeque.FindLast(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
begin
  if GetCount = 0 then
    Exit(-1);

  Result := FindLast(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
begin
  if GetCount = 0 then
    Exit(-1);

  Result := FindLast(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aEquals: TEqualsRefFunc): SizeInt;
begin
  if GetCount = 0 then
    Exit(-1);

  Result := FindLast(aValue, 0, GetCount, aEquals);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindLast(aValue, aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindLast(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindLast(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := FindLast(aValue, aStartIndex, GetCount - aStartIndex, aEquals);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := FindLastUnChecked(aValue, aStartIndex, aCount);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := FindLastUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := FindLastUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVecDeque.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := FindLastUnChecked(aValue, aStartIndex, aCount, aEquals);
end;

// FindLastIF 系列方法实现
function TVecDeque.FindLastIF(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  Result := FindLastIF(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindLastIF(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  Result := FindLastIF(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindLastIF(aPredicate: TPredicateRefFunc): SizeInt;
begin
  Result := FindLastIF(0, GetCount, aPredicate);
end;

function TVecDeque.FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIF(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIF(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindLastIF(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIF(aStartIndex, GetCount - aStartIndex, aPredicate);
end;

function TVecDeque.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := TempResult;
end;

function TVecDeque.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := TempResult;
end;

function TVecDeque.FindLastIF(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFUnChecked(aStartIndex, aCount, aPredicate);
  Result := TempResult;
end;

// FindLastIFNot 系列方法实现
function TVecDeque.FindLastIFNot(aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  Result := FindLastIFNot(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindLastIFNot(aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  Result := FindLastIFNot(0, GetCount, aPredicate, aData);
end;

function TVecDeque.FindLastIFNot(aPredicate: TPredicateRefFunc): SizeInt;
begin
  Result := FindLastIFNot(0, GetCount, aPredicate);
end;

function TVecDeque.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIFNot(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIFNot(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.FindLastIFNot(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  Result := FindLastIFNot(aStartIndex, GetCount - aStartIndex, aPredicate);
end;

function TVecDeque.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := TempResult;
end;

function TVecDeque.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate, aData);
  Result := TempResult;
end;

function TVecDeque.FindLastIFNot(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeInt;
var
  TempResult: SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);
  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;
  if aCount = 0 then
    Exit(-1);
  TempResult := FindLastIFNotUnChecked(aStartIndex, aCount, aPredicate);
  Result := TempResult;
end;

// CountOf 系列方法实现
function TVecDeque.CountOf(const aValue: T; aStartIndex: SizeUInt): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountOf(aValue, aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountOf(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountOf(aValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountOf(aValue, aStartIndex, GetCount - aStartIndex, aEquals);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountOfUnChecked(aValue, aStartIndex, aCount);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountOfUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountOfUnChecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountOfUnChecked(aValue, aStartIndex, aCount, aEquals);
end;

// CountIf 系列方法实现
function TVecDeque.CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountIf(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountIf(aStartIndex, GetCount - aStartIndex, aPredicate, aData);
end;

function TVecDeque.CountIf(aStartIndex: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  Result := CountIf(aStartIndex, GetCount - aStartIndex, aPredicate);
end;

function TVecDeque.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVecDeque.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVecDeque.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: TPredicateRefFunc): SizeUInt;
begin
  if aStartIndex >= GetCount then
    Exit(0);

  if aCount = 0 then
    Exit(0);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := CountIfUnChecked(aStartIndex, aCount, aPredicate);
end;

// Replace 系列方法实现
procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt);
begin
  if aStartIndex >= GetCount then
    Exit;

  Replace(aOldValue, aNewValue, aStartIndex, GetCount - aStartIndex);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  Replace(aOldValue, aNewValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  Replace(aOldValue, aNewValue, aStartIndex, GetCount - aStartIndex, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex: SizeUInt; aEquals: TEqualsRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  Replace(aOldValue, aNewValue, aStartIndex, GetCount - aStartIndex, aEquals);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceUnChecked(aOldValue, aNewValue, aStartIndex, aCount);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceUnChecked(aOldValue, aNewValue, aStartIndex, aCount, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceUnChecked(aOldValue, aNewValue, aStartIndex, aCount, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aStartIndex, aCount: SizeUInt; aEquals: TEqualsRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount = 0 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ReplaceUnChecked(aOldValue, aNewValue, aStartIndex, aCount, aEquals);
end;

// 基础方法（无参数版本）实现
function TVecDeque.CountOf(const aValue: T): SizeUInt;
begin
  Result := CountOf(aValue, 0, GetCount);
end;

function TVecDeque.CountOf(const aValue: T; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
begin
  Result := CountOf(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
begin
  Result := CountOf(aValue, 0, GetCount, aEquals, aData);
end;

function TVecDeque.CountOf(const aValue: T; aEquals: TEqualsRefFunc): SizeUInt;
begin
  Result := CountOf(aValue, 0, GetCount, aEquals);
end;

function TVecDeque.CountIF(aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
begin
  { 计算满足条件的元素数量 }
  Result := CountIfUnChecked(0, FCount, aPredicate, aData);
end;

function TVecDeque.CountIF(aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
begin
  { 计算满足条件的元素数量 }
  Result := CountIfUnChecked(0, FCount, aPredicate, aData);
end;

function TVecDeque.CountIF(aPredicate: TPredicateRefFunc): SizeUInt;
begin
  { 计算满足条件的元素数量 }
  Result := CountIfUnChecked(0, FCount, aPredicate);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T);
begin
  Replace(aOldValue, aNewValue, 0, GetCount);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aEquals: TEqualsFunc; aData: Pointer);
begin
  Replace(aOldValue, aNewValue, 0, GetCount, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aEquals: TEqualsMethod; aData: Pointer);
begin
  Replace(aOldValue, aNewValue, 0, GetCount, aEquals, aData);
end;

procedure TVecDeque.Replace(const aOldValue, aNewValue: T; aEquals: TEqualsRefFunc);
begin
  Replace(aOldValue, aNewValue, 0, GetCount, aEquals);
end;

procedure TVecDeque.ReplaceIf(const aNewValue: T; aPredicate: TPredicateFunc; aData: Pointer);
begin
  { 替换满足条件的元素 }
  ReplaceIF(aNewValue, 0, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIf(const aNewValue: T; aPredicate: TPredicateMethod; aData: Pointer);
begin
  { 替换满足条件的元素 }
  ReplaceIF(aNewValue, 0, aPredicate, aData);
end;

procedure TVecDeque.ReplaceIf(const aNewValue: T; aPredicate: TPredicateRefFunc);
begin
  { 替换满足条件的元素 }
  ReplaceIF(aNewValue, 0, aPredicate);
end;

function TVecDeque.IsSorted: Boolean;
begin
  Result := IsSorted(0, GetCount);
end;

function TVecDeque.IsSorted(aComparer: TCompareFunc; aData: Pointer): Boolean;
begin
  Result := IsSorted(0, GetCount, aComparer, aData);
end;

function TVecDeque.IsSorted(aComparer: TCompareMethod; aData: Pointer): Boolean;
begin
  Result := IsSorted(0, GetCount, aComparer, aData);
end;

function TVecDeque.IsSorted(aComparer: TCompareRefFunc): Boolean;
begin
  Result := IsSorted(0, GetCount, aComparer);
end;

function TVecDeque.BinarySearch(const aValue: T): SizeInt;
begin
  { 使用内部默认比较器进行二分查找 }
  Result := BinarySearchUnChecked(aValue, 0, FCount);
end;

function TVecDeque.BinarySearch(const aValue: T; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  { 二分查找 }
  Result := BinarySearchUnChecked(aValue, 0, FCount, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  { 二分查找 }
  Result := BinarySearchUnChecked(aValue, 0, FCount, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aComparer: TCompareRefFunc): SizeInt;
begin
  { 二分查找 }
  Result := BinarySearchUnChecked(aValue, 0, FCount, aComparer);
end;

function TVecDeque.BinarySearchInsert(const aValue: T): SizeInt;
begin
  { 使用内部默认比较器进行二分查找插入位置 }
  Result := BinarySearchInsertUnChecked(aValue, 0, FCount);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  { 二分查找插入位置 }
  Result := BinarySearchInsertUnChecked(aValue, 0, FCount, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  { 二分查找插入位置 }
  Result := BinarySearchInsertUnChecked(aValue, 0, FCount, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aComparer: TCompareRefFunc): SizeInt;
begin
  { 二分查找插入位置 }
  Result := BinarySearchInsertUnChecked(aValue, 0, FCount, aComparer);
end;

procedure TVecDeque.Shuffle;
begin
  { 使用默认随机数生成器洗牌 }
  Shuffle(
    function(aRange: Int64): Int64
    begin
      Result := Random(aRange);
    end
  );
end;

procedure TVecDeque.Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
var
  i, j: SizeUInt;
  LElement1, LElement2: T;
  LPhysicalI, LPhysicalJ: SizeUInt;
begin
  { Fisher-Yates 洗牌算法 }
  if FCount <= 1 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := FCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1, aData);

    // 交换元素 i 和 j - 预计算物理索引
    LPhysicalI := GetPhysicalIndex(i);
    LPhysicalJ := GetPhysicalIndex(j);

    LElement1 := FBuffer.GetUnChecked(LPhysicalI);
    LElement2 := FBuffer.GetUnChecked(LPhysicalJ);
    FBuffer.PutUnChecked(LPhysicalI, LElement2);
    FBuffer.PutUnChecked(LPhysicalJ, LElement1);
  end;
end;

procedure TVecDeque.Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
var
  i, j: SizeUInt;
  LElement1, LElement2: T;
  LPhysicalI, LPhysicalJ: SizeUInt;
begin
  { Fisher-Yates 洗牌算法 }
  if FCount <= 1 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := FCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1, aData);

    // 交换元素 i 和 j - 预计算物理索引
    LPhysicalI := GetPhysicalIndex(i);
    LPhysicalJ := GetPhysicalIndex(j);

    LElement1 := FBuffer.GetUnChecked(LPhysicalI);
    LElement2 := FBuffer.GetUnChecked(LPhysicalJ);
    FBuffer.PutUnChecked(LPhysicalI, LElement2);
    FBuffer.PutUnChecked(LPhysicalJ, LElement1);
  end;
end;

procedure TVecDeque.Shuffle(aRandomGenerator: TRandomGeneratorRefFunc);
var
  i, j: SizeUInt;
  LElement1, LElement2: T;
  LPhysicalI, LPhysicalJ: SizeUInt;
begin
  { Fisher-Yates 洗牌算法 }
  if FCount <= 1 then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := FCount - 1 downto 1 do
  begin
    j := aRandomGenerator(i + 1);

    // 交换元素 i 和 j - 预计算物理索引
    LPhysicalI := GetPhysicalIndex(i);
    LPhysicalJ := GetPhysicalIndex(j);

    LElement1 := FBuffer.GetUnChecked(LPhysicalI);
    LElement2 := FBuffer.GetUnChecked(LPhysicalJ);
    FBuffer.PutUnChecked(LPhysicalI, LElement2);
    FBuffer.PutUnChecked(LPhysicalJ, LElement1);
  end;
end;

// Sort 系列方法实现
procedure TVecDeque.Sort;
begin
  { 使用默认比较器和内省排序算法 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, saIntroSort);
end;

procedure TVecDeque.Sort(aComparer: TCompareFunc; aData: Pointer);
begin
  { 使用自定义比较器和内省排序算法 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, saIntroSort, aComparer, aData);
end;

procedure TVecDeque.Sort(aComparer: TCompareMethod; aData: Pointer);
var
  LContext: TCompareMethodContext;
begin
  { 使用自定义比较方法和内省排序算法 - 简化为使用默认比较器 }
  if FCount <= 1 then
    Exit;
  LContext.Comparer := aComparer;
  LContext.Data := aData;
  SortWith(0, FCount, saIntroSort, @CompareMethodAdapter, @LContext);
end;

procedure TVecDeque.Sort(aComparer: TCompareRefFunc);
begin
  { 使用自定义比较函数引用和内省排序算法 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, saIntroSort, aComparer);
end;

procedure TVecDeque.Sort(aStartIndex: SizeUInt);
begin
  { 从指定索引开始排序到末尾 }
  if aStartIndex >= FCount then
    Exit;
  SortWith(aStartIndex, FCount - aStartIndex, saIntroSort);
end;

procedure TVecDeque.Sort(aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
begin
  { 从指定索引开始排序到末尾，使用自定义比较器 }
  if aStartIndex >= FCount then
    Exit;
  SortWith(aStartIndex, FCount - aStartIndex, saIntroSort, aComparer, aData);
end;

procedure TVecDeque.Sort(aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
var
  LContext: TCompareMethodContext;
begin
  { 从指定索引开始排序到末尾，使用默认比较器 }
  if aStartIndex >= FCount then
    Exit;
  if aStartIndex + 1 >= FCount then
    Exit;
  LContext.Comparer := aComparer;
  LContext.Data := aData;
  SortWith(aStartIndex, FCount - aStartIndex, saIntroSort, @CompareMethodAdapter, @LContext);
end;

procedure TVecDeque.Sort(aStartIndex: SizeUInt; aComparer: TCompareRefFunc);
begin
  { 从指定索引开始排序到末尾，使用自定义比较函数引用 }
  if aStartIndex >= FCount then
    Exit;
  SortWith(aStartIndex, FCount - aStartIndex, saIntroSort, aComparer);
end;

procedure TVecDeque.Sort(aStartIndex, aCount: SizeUInt);
begin
  { 排序指定范围，使用默认比较器 }
  if (aStartIndex >= FCount) or (aCount = 0) then
    Exit;
  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Sort: range out of bounds');
  SortWith(aStartIndex, aCount, saIntroSort);
end;

procedure TVecDeque.Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
begin
  { 排序指定范围，使用自定义比较器 }
  if (aStartIndex >= FCount) or (aCount = 0) then
    Exit;
  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Sort: range out of bounds');
  SortWith(aStartIndex, aCount, saIntroSort, aComparer, aData);
end;

procedure TVecDeque.Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
var
  LContext: TCompareMethodContext;
begin
  { 排序指定范围，使用默认比较器 }
  if (aStartIndex >= FCount) or (aCount = 0) then
    Exit;
  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Sort: range out of bounds');
  if aCount <= 1 then Exit;
  LContext.Comparer := aComparer;
  LContext.Data := aData;
  SortWith(aStartIndex, aCount, saIntroSort, @CompareMethodAdapter, @LContext);
end;

procedure TVecDeque.Sort(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc);
begin
  { 排序指定范围，使用自定义比较函数引用 }
  if (aStartIndex >= FCount) or (aCount = 0) then
    Exit;
  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.Sort: range out of bounds');
  SortWith(aStartIndex, aCount, saIntroSort, aComparer);
end;

// SortUnChecked 系列方法实现
procedure TVecDeque.SortUnChecked(aStartIndex, aCount: SizeUInt);
begin
  { 无边界检查的排序，使用默认比较器 }
  if aCount <= 1 then
    Exit;
  DoQuickSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
end;

procedure TVecDeque.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
begin
  { 无边界检查的排序，使用自定义比较器 }
  if aCount <= 1 then
    Exit;
  DoQuickSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
end;

procedure TVecDeque.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer);
var
  LContext: TCompareMethodContext;
begin
  { 无边界检查的排序，使用默认比较器 }
  if aCount <= 1 then
    Exit;
  LContext.Comparer := aComparer;
  LContext.Data := aData;
  DoQuickSort(aStartIndex, aStartIndex + aCount - 1, @CompareMethodAdapter, @LContext);
end;

procedure TVecDeque.SortUnChecked(aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc);
begin
  { 无边界检查的排序，使用自定义比较函数引用 }
  if aCount <= 1 then
    Exit;
  SortWith(aStartIndex, aCount, saQuickSort, aComparer);
end;

// 其他缺失方法实现
function TVecDeque.TryReserveExact(aCapacity: SizeUInt): Boolean;
begin
  { 尝试精确预留容量，不使用增长策略 }
  try
    if aCapacity > FBuffer.GetCount then
      Grow(aCapacity);
    Result := True;
  except
    on EOutOfMemory do
      Result := False;
  end;
end;

procedure TVecDeque.ReserveExact(aCapacity: SizeUInt);
begin
  { 精确预留容量，不使用增长策略 }
  if aCapacity > FBuffer.GetCount then
    Grow(aCapacity);
end;

procedure TVecDeque.FillWith(const aValue: T; aCount: SizeUInt);
var
  LStartTail: SizeUInt;
  LFirstPartSize, LSecondPartSize: SizeUInt;
begin
  { 高效批量填充指定数量的相同元素 - 使用批量优化 }
  if aCount = 0 then
    Exit;

  // 确保有足够容量
  EnsureCapacity(FCount + aCount);

  LStartTail := FTail;
  LFirstPartSize := Min(aCount, FBuffer.GetCount - LStartTail);
  LSecondPartSize := aCount - LFirstPartSize;

  // 批量填充第一段：从当前尾部到缓冲区末尾
  if LFirstPartSize > 0 then
    FBuffer.FillUnChecked(LStartTail, LFirstPartSize, aValue);

  // 批量填充第二段：从缓冲区开头
  if LSecondPartSize > 0 then
    FBuffer.FillUnChecked(0, LSecondPartSize, aValue);

  // 更新状态
  FTail := WrapAdd(FTail, aCount);
  Inc(FCount, aCount);
end;

procedure TVecDeque.ClearAndReserve(aCapacity: SizeUInt);
begin
  { 高效清空并预留容量，避免重复分配 }
  Clear;
  if aCapacity > FBuffer.GetCount then
    ReserveExact(aCapacity);
end;

procedure TVecDeque.SwapRange(aIndex1, aIndex2, aCount: SizeUInt);
var
  i: SizeUInt;
  LElement1, LElement2: T;
  LPhysical1, LPhysical2: SizeUInt;
begin
  { 高效批量交换两个范围的元素 }
  if (aIndex1 + aCount > FCount) or (aIndex2 + aCount > FCount) then
    raise EOutOfRange.Create('TVecDeque.SwapRange: range out of bounds');

  if (aIndex1 = aIndex2) or (aCount = 0) then
    Exit;

  // 检查范围是否重叠
  if (aIndex1 < aIndex2 + aCount) and (aIndex2 < aIndex1 + aCount) then
    raise EInvalidOperation.Create('TVecDeque.SwapRange: ranges overlap');

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := 0 to aCount - 1 do
  begin
    LPhysical1 := GetPhysicalIndex(aIndex1 + i);
    LPhysical2 := GetPhysicalIndex(aIndex2 + i);

    LElement1 := FBuffer.GetUnChecked(LPhysical1);
    LElement2 := FBuffer.GetUnChecked(LPhysical2);
    FBuffer.PutUnChecked(LPhysical1, LElement2);
    FBuffer.PutUnChecked(LPhysical2, LElement1);
  end;
end;



function TVecDeque.FastIndexOf(const aValue: T): SizeInt;
var
  LTailIndex: SizeUInt;
  LFirstPartSize: SizeUInt;
  i: SizeUInt;
  LElementSize: SizeUInt;
begin
  { 快速正向查找，优化的线性搜索 - 使用分段优化 }
  Result := -1;

  if FCount = 0 then
    Exit;

  LElementSize := GetElementSize;
  LTailIndex := WrapSub(FTail, 1);  // 最后一个元素的位置

  if FHead <= LTailIndex then
  begin
    // 情况1：数据是连续的 - 优化内存访问
    for i := FHead to LTailIndex do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
      begin
        Result := SizeInt(i - FHead);
        Exit;
      end;
    end;
  end
  else
  begin
    // 情况2：数据跨越了缓冲区边界
    LFirstPartSize := FBuffer.GetCount - FHead;

    // 搜索第一段：从FHead到缓冲区末尾
    for i := FHead to FBuffer.GetCount - 1 do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
      begin
        Result := SizeInt(i - FHead);
        Exit;
      end;
    end;

    // 搜索第二段：从缓冲区开头到FTail
    for i := 0 to FTail - 1 do
    begin
      if CompareMem(@aValue, FBuffer.GetPtrUnChecked(i), LElementSize) then
      begin
        Result := SizeInt(LFirstPartSize + i);
        Exit;
      end;
    end;
  end;
end;

function TVecDeque.FastLastIndexOf(const aValue: T): SizeInt;
var
  i: SizeUInt;
  LElement: T;
begin
  { 快速反向查找，从末尾开始 }
  Result := -1;

  if FCount = 0 then
    Exit;

  i := FCount;
  repeat
    Dec(i);
    LElement := FBuffer.GetUnChecked(GetPhysicalIndex(i));
    if CompareMem(@LElement, @aValue, GetElementSize) then
    begin
      Result := SizeInt(i);
      Exit;
    end;
  until i = 0;
end;

procedure TVecDeque.WarmupMemory;
var
  i: SizeUInt;
  LDummy: Byte;
  LPtr: PByte;


begin
  { 内存预热：触摸所有已分配的内存页面，提高后续访问性能 }
  if FBuffer.GetCount = 0 then
    Exit;

  LPtr := PByte(FBuffer.GetPtr(0));
  // 以页面大小（通常4KB）间隔访问内存
  for i := 0 to (FBuffer.GetCount * SizeOf(T)) div 4096 do
  begin
    LDummy := LPtr^;  // 触摸内存页面
    Inc(LPtr, 4096);
  end;

  // 避免编译器优化掉访问
  if LDummy = 255 then
    LDummy := 0;
end;

procedure TVecDeque.WarmupMemory(aMinCapacity: SizeUInt);
begin
  // 仅确保容量，不改变元素数量
  if aMinCapacity = 0 then Exit;
  if aMinCapacity > Capacity then
    Reserve(aMinCapacity - Capacity);
end;

// IVec基础方法实现
procedure TVecDeque.Shrink;
begin
  { 收缩到合适的容量，类似于 ShrinkToFit }
  ShrinkToFit;
end;

procedure TVecDeque.ShrinkTo(aCapacity: SizeUInt);
var
  LNewCapacity: SizeUInt;
begin
  { 收缩到指定容量，但不能小于当前元素数量 }
  if aCapacity < FCount then
    raise EInvalidArgument.CreateFmt('TVecDeque.ShrinkTo: capacity %d < count %d', [aCapacity, FCount]);

  LNewCapacity := NextPowerOfTwo(aCapacity);
  if LNewCapacity < FBuffer.GetCount then
    Grow(LNewCapacity);
end;

procedure TVecDeque.Truncate(aNewCount: SizeUInt);
var
  i: SizeUInt;
  LElement: T;
begin
  { 截断到指定数量，移除多余元素 }
  if aNewCount >= FCount then
    Exit; // 无需截断

  // 如果是托管类型，需要正确释放被移除的元素
  if GetIsManagedType then
  begin
    for i := aNewCount to FCount - 1 do
    begin
      LElement := Default(T);
      FBuffer.Put(GetPhysicalIndex(i), LElement);
    end;
  end;

  FCount := aNewCount;
  // 修复：同步更新 FTail 指针，确保 Back() 返回正确值
  FTail := WrapAdd(FHead, aNewCount);
end;

procedure TVecDeque.ResizeExact(aNewCount: SizeUInt);
var
  LDefaultElement: T;
  i: SizeUInt;
begin
  { 精确调整大小，不使用增长策略 }
  if aNewCount = FCount then
    Exit;

  if aNewCount > FCount then
  begin
    // 需要扩大
    if aNewCount > FBuffer.GetCount then
      Grow(NextPowerOfTwo(aNewCount));

    // 用默认值填充新元素
    LDefaultElement := Default(T);
    for i := FCount to aNewCount - 1 do
      FBuffer.Put(GetPhysicalIndex(i), LDefaultElement);
  end
  else
  begin
    // 需要缩小
    Truncate(aNewCount);
  end;

  FCount := aNewCount;
end;

// Insert 系列方法实现
procedure TVecDeque.Insert(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
begin
  { 在指定位置插入指针数据 }
  if aPtr = nil then
    raise EArgumentNil.Create('TVecDeque.Insert: aPtr cannot be nil');

  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Insert: index %d out of range [0..%d]', [aIndex, FCount]);

  if aCount = 0 then
    Exit;

  if IsOverlap(aPtr, aCount) then
  begin
    InsertFromOverlappingSource(aIndex, aPtr, aCount);
    Exit;
  end;

  InsertRawNoOverlap(aIndex, aPtr, aCount);
end;

procedure TVecDeque.Insert(aIndex: SizeUInt; const aElement: T);
begin
  { 在指定位置插入单个元素 }
  Insert(aIndex, @aElement, 1);
end;

procedure TVecDeque.Insert(aIndex: SizeUInt; const aArray: array of T);
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
  LInsertCount: SizeUInt;
  LRequiredCapacity: SizeUInt;
begin
  { 在指定位置插入数组 }
  if Length(aArray) = 0 then
    Exit;

  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Insert: index %d out of range [0..%d]', [aIndex, FCount]);

  LInsertCount := SizeUInt(Length(aArray));
  LRequiredCapacity := RequireAddCount(FCount, LInsertCount, 'TVecDeque.Insert');

  // 确保有足够容量
  EnsureCapacity(LRequiredCapacity);

  // 移动现有元素
  if aIndex < FCount then
    MoveElementsRight(aIndex, LInsertCount);

  // 插入数组元素 - 优化：减少 GetPhysicalIndex 调用
  for i := 0 to High(aArray) do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    FBuffer.PutUnChecked(LPhysicalIndex, aArray[i]);
  end;

  Inc(FCount, LInsertCount);
  FTail := WrapAdd(FHead, FCount);
end;

procedure TVecDeque.Insert(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt);
var
  LTotal, LInsertCount: SizeUInt;
  LIter: TPtrIter;
  LCopied: SizeUInt;
  LPhysicalIndex: SizeUInt;
  LRequiredCapacity: SizeUInt;
begin
  { 从集合插入元素 }
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.Insert: aCollection cannot be nil');

  if aStartIndex >= aCollection.GetCount then
    Exit; // 没有元素可插入

  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Insert: index %d out of range [0..%d]', [aIndex, FCount]);

  // 计算需要插入的元素数量（从 aStartIndex 到末尾）
  LTotal := aCollection.GetCount;
  if aStartIndex >= LTotal then Exit;
  LInsertCount := LTotal - aStartIndex;

  LRequiredCapacity := RequireAddCount(FCount, LInsertCount, 'TVecDeque.Insert');
  EnsureCapacity(LRequiredCapacity);

  // 为插入腾出空间
  if aIndex < FCount then
    MoveElementsRight(aIndex, LInsertCount);

  // 通过迭代器逐个复制（避免临时子集合/切片）
  // 零分配迭代器：aIter.Data 直接保存逻辑索引，无需释放
  LIter := aCollection.PtrIter;
  LCopied := 0;
  // 跳过起始索引之前的元素
  while (LCopied < aStartIndex) and LIter.MoveNext do
    Inc(LCopied);

  LCopied := 0;
  while (LCopied < LInsertCount) and LIter.MoveNext do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + LCopied);
    FBuffer.PutUnChecked(LPhysicalIndex, PElement(LIter.GetCurrent)^);
    Inc(LCopied);
  end;

  // zero-allocation iterator: nothing to finalize

  Inc(FCount, LInsertCount);
  FTail := WrapAdd(FHead, FCount);


end;

procedure TVecDeque.Insert(aIndex: SizeUInt; const aCollection: TCollection);
begin
  Insert(aIndex, aCollection, 0);
end;


// Write 系列方法实现
procedure TVecDeque.Write(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
begin



  if aPtr = nil then
    raise EArgumentNil.Create('TVecDeque.Write: aPtr is nil');
  if aCount = 0 then
    Exit;
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Write: index %d out of range [0..%d]', [aIndex, FCount]);

  // 确保容量并调整 Count
  EnsureCapacity(aIndex + aCount);
  if aIndex + aCount > FCount then
    FCount := aIndex + aCount;

  // 复用覆盖写入逻辑（环形两段写）
  OverWriteUnChecked(aIndex, aPtr, aCount);
end;

procedure TVecDeque.Write(aIndex: SizeUInt; const aArray: array of T);
var
  LCount: SizeUInt;
begin
  LCount := SizeUInt(Length(aArray));
  if LCount = 0 then
    Exit;
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Write: index %d out of range [0..%d]', [aIndex, FCount]);

  EnsureCapacity(aIndex + LCount);
  if aIndex + LCount > FCount then
    FCount := aIndex + LCount;

  OverWriteUnChecked(aIndex, @aArray[Low(aArray)], LCount);
end;

procedure TVecDeque.Write(aIndex: SizeUInt; const aCollection: TCollection);
var
  LCount: SizeUInt;
begin
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.Write: aCollection is nil');
  LCount := aCollection.Count;
  if LCount = 0 then
    Exit;
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Write: index %d out of range [0..%d]', [aIndex, FCount]);

  EnsureCapacity(aIndex + LCount);
  if aIndex + LCount > FCount then
    FCount := aIndex + LCount;

  OverWriteUnChecked(aIndex, aCollection, LCount);
end;

procedure TVecDeque.Write(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt);
var
  LCount: SizeUInt;
  LIter: TPtrIter;
  LCopied: SizeUInt;
begin
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.Write: aCollection is nil');
  if aStartIndex > aCollection.Count then
    Exit;
  LCount := aCollection.Count - aStartIndex;
  if LCount = 0 then
    Exit;
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Write: index %d out of range [0..%d]', [aIndex, FCount]);

  EnsureCapacity(aIndex + LCount);
  if aIndex + LCount > FCount then
    FCount := aIndex + LCount;

  // 以迭代器方式写入（避免拷贝额外子集合），并正确跳过起始索引
  // 零分配迭代器：aIter.Data 直接保存逻辑索引，无需释放
  LIter := aCollection.PtrIter;
  LCopied := 0;
  // 跳过 aStartIndex 个元素
  while (LCopied < aStartIndex) and LIter.MoveNext do
    Inc(LCopied);

  // 复制接下来的 LCount 个元素
  LCopied := 0;
  while (LCopied < LCount) and LIter.MoveNext do
  begin
    FBuffer.PutUnChecked(GetPhysicalIndex(aIndex + LCopied), PElement(LIter.GetCurrent)^);
    Inc(LCopied);
  end;

  // zero-allocation iterator: nothing to finalize
end;

// WriteExact 系列方法实现
procedure TVecDeque.WriteExact(aIndex: SizeUInt; const aPtr: Pointer; aCount: SizeUInt);
begin
  if aPtr = nil then
    raise EArgumentNil.Create('TVecDeque.WriteExact: aPtr is nil');
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.WriteExact: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);
  if aCount = 0 then
    Exit;
  OverWriteUnChecked(aIndex, aPtr, aCount);
end;

procedure TVecDeque.WriteExact(aIndex: SizeUInt; const aArray: array of T);
var
  LCount: SizeUInt;
begin
  LCount := SizeUInt(Length(aArray));
  if aIndex + LCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.WriteExact: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + LCount - 1, FCount - 1]);
  if LCount = 0 then
    Exit;
  OverWriteUnChecked(aIndex, @aArray[Low(aArray)], LCount);
end;

procedure TVecDeque.WriteExact(aIndex: SizeUInt; const aCollection: TCollection);
var
  LCount: SizeUInt;
begin
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.WriteExact: aCollection is nil');
  LCount := aCollection.Count;
  if aIndex + LCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.WriteExact: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + LCount - 1, FCount - 1]);
  if LCount = 0 then
    Exit;
  OverWriteUnChecked(aIndex, aCollection, LCount);
end;

procedure TVecDeque.WriteExact(aIndex: SizeUInt; const aCollection: TCollection; aStartIndex: SizeUInt);
var
  LCount: SizeUInt;
begin
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.WriteExact: aCollection is nil');
  if aStartIndex > aCollection.Count then
    raise EOutOfRange.CreateFmt('TVecDeque.WriteExact: aStartIndex %d out of range [0..%d]',
      [aStartIndex, aCollection.Count]);
  LCount := aCollection.Count - aStartIndex;
  if aIndex + LCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.WriteExact: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + LCount - 1, FCount - 1]);
  if LCount = 0 then
    Exit;
  OverWriteUnChecked(aIndex, aCollection, LCount);
end;

// Push 系列方法实现
procedure TVecDeque.Push(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  { Push 等同于 PushBack }
  PushBack(aSrc, aElementCount);
end;

procedure TVecDeque.Push(const aElements: array of T);
begin
  { Push 等同于 PushBack }
  PushBack(aElements);
end;

procedure TVecDeque.Push(const aCollection: TCollection; aStartIndex: SizeUInt);
begin
  { Push 等同于 PushBack }
  if aCollection = nil then
    raise EArgumentNil.Create('TVecDeque.Push: aCollection is nil');
  if aStartIndex >= aCollection.Count then
    Exit;
  // 复用 Insert 的集合 + 起始索引逻辑，在末尾插入
  Insert(FCount, aCollection, aStartIndex);
end;

// TryPop 系列方法实现
function TVecDeque.TryPop(aPtr: Pointer; aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LPtr: PByte;
  LPhysicalIndex: SizeUInt;
begin
  { 尝试从后端弹出指定数量的元素到指针 }
  if (aPtr = nil) or (aCount = 0) then
  begin
    Result := False;
    Exit;
  end;

  if aCount > FCount then
  begin
    Result := False;
    Exit;
  end;

  // 复制元素到指针 - 进一步减少 GetPhysicalIndex 调用：一次起算 + 每次 WrapAdd
  LPtr := PByte(aPtr);
  LPhysicalIndex := GetPhysicalIndex(FCount - aCount);
  for i := 0 to aCount - 1 do
  begin
    Move(FBuffer.GetPtrUnChecked(LPhysicalIndex)^, LPtr^, SizeOf(T));
    Inc(LPtr, SizeOf(T));
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;

  // 移除元素
  Dec(FCount, aCount);
  Result := True;
end;

function TVecDeque.TryPop(var aArray: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  { 尝试从后端弹出指定数量的元素到数组 }
  if aCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  if aCount > FCount then
  begin
    Result := False;
    Exit;
  end;

  // 调整数组大小
  SetLength(aArray, aCount);

  // 复制元素到数组 - 进一步减少 GetPhysicalIndex 调用
  LPhysicalIndex := GetPhysicalIndex(FCount - aCount);
  for i := 0 to aCount - 1 do
  begin
    aArray[i] := FBuffer.GetUnChecked(LPhysicalIndex);
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;

  // 移除元素
  Dec(FCount, aCount);
  Result := True;
end;

function TVecDeque.TryPop(var aElement: T): Boolean;
begin
  { 尝试从后端弹出单个元素 }
  if FCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  aElement := FBuffer.GetUnChecked(GetPhysicalIndex(FCount - 1));
  Dec(FCount);
  Result := True;
end;

// TryPeek 系列方法实现
function TVecDeque.TryPeekCopy(aPtr: Pointer; aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LPtr: PByte;
  LPhysicalIndex: SizeUInt;
begin
  { 尝试查看后端指定数量的元素并复制到指针 }
  if (aPtr = nil) or (aCount = 0) then
  begin
    Result := False;
    Exit;
  end;

  if aCount > FCount then
  begin
    Result := False;
    Exit;
  end;

  // 复制元素到指针 - 进一步减少 GetPhysicalIndex 调用：一次起算 + 每次 WrapAdd
  LPtr := PByte(aPtr);
  LPhysicalIndex := GetPhysicalIndex(FCount - aCount);
  for i := 0 to aCount - 1 do
  begin
    Move(FBuffer.GetPtrUnChecked(LPhysicalIndex)^, LPtr^, SizeOf(T));
    Inc(LPtr, SizeOf(T));
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;

  Result := True;
end;

function TVecDeque.TryPeek(var aArray: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  { 尝试查看后端指定数量的元素并复制到数组 }
  if aCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  if aCount > FCount then
  begin
    Result := False;
    Exit;
  end;

  // 调整数组大小
  SetLength(aArray, aCount);

  // 复制元素到数组 - 进一步减少 GetPhysicalIndex 调用
  LPhysicalIndex := GetPhysicalIndex(FCount - aCount);
  for i := 0 to aCount - 1 do
  begin
    aArray[i] := FBuffer.GetUnChecked(LPhysicalIndex);
    LPhysicalIndex := WrapAdd(LPhysicalIndex, 1);
  end;

  Result := True;
end;

function TVecDeque.TryPeek(out aElement: T): Boolean;
begin
  { 尝试查看队首元素 (FIFO 语义: Peek 返回下一个要 Pop 的元素) }
  if FCount = 0 then
  begin
    Result := False;
    Exit;
  end;

  aElement := FBuffer.GetUnChecked(FHead);
  Result := True;
end;

// PeekRange 方法实现（仅当后端 aCount 元素物理连续时返回指针，否则返回 nil）
function TVecDeque.PeekRange(aCount: SizeUInt): PElement;
var
  P1, P2: PElement;
  L1, L2: SizeUInt;
begin
  if (aCount = 0) or (aCount > FCount) then
    Exit(nil);

  // 映射尾部 aCount 元素为至多两段
  GetTwoSlices(FCount - aCount, aCount, P1, L1, P2, L2);
  if (P1 <> nil) and (L1 = aCount) and (L2 = 0) then
    Result := P1
  else
    Result := nil;
end;

function TVecDeque.PeekRangeContiguous(aCount: SizeUInt): PElement;
var
  LPtr: PElement;
  LLen: SizeUInt;
begin
  if (aCount = 0) or (aCount > FCount) then
    Exit(nil);

  // 先尝试快速路径
  Result := PeekRange(aCount);
  if Result <> nil then
    Exit;

  // 非连续时强制连续化
  MakeContiguous(LPtr, LLen);

  // 返回尾部 aCount 元素的指针
  if aCount <= LLen then
    Result := PElement(PByte(LPtr) + (LLen - aCount) * GetElementSize)
  else
    Result := nil;
end;


function TVecDeque.TryPeekFront(out aElement: T): Boolean;
begin
  Result := PeekFront(aElement);
end;

function TVecDeque.TryPeekBack(out aElement: T): Boolean;
begin
  Result := PeekBack(aElement);
end;

function TVecDeque.TryPopFront(out aElement: T): Boolean;
begin
  aElement := Default(T);
  Result := PopFront(aElement);
end;

function TVecDeque.TryPopBack(out aElement: T): Boolean;
begin
  aElement := Default(T);
  Result := PopBack(aElement);
end;


// Delete 系列方法实现
procedure TVecDeque.Delete(aIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LElement: T;
begin
  { 删除指定范围的元素 }
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Delete: index %d out of range [0..%d)', [aIndex, FCount]);

  if aCount = 0 then
    Exit;

  if aIndex + aCount > FCount then
    aCount := FCount - aIndex;

  // 如果是托管类型，需要正确释放被删除的元素
  if GetIsManagedType then
  begin
    LElement := Default(T);
    for i := aIndex to aIndex + aCount - 1 do
      FBuffer.Put(GetPhysicalIndex(i), LElement);
  end;

  // 移动后面的元素向前填补空隙
  if aIndex + aCount < FCount then
    MoveElementsLeft(aIndex + aCount, aCount);

  Dec(FCount, aCount);
end;

procedure TVecDeque.Delete(aIndex: SizeUInt);
begin
  { 删除单个元素 }
  Delete(aIndex, 1);
end;

procedure TVecDeque.DeleteSwap(aIndex: SizeUInt; aCount: SizeUInt);
var
  i: SizeUInt;
  LElement: T;
  LMoveCount: SizeUInt;
  LSrcPhysical, LDstPhysical: SizeUInt;
begin
  { 删除元素并用末尾元素填补（不保持顺序，但更高效） }
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.DeleteSwap: index %d out of range [0..%d)', [aIndex, FCount]);

  if aCount = 0 then
    Exit;

  if aIndex + aCount > FCount then
    aCount := FCount - aIndex;

  // 计算需要移动的元素数量
  LMoveCount := Min(aCount, FCount - aIndex - aCount);

  // 用末尾元素填补被删除的位置 - 优化：减少 GetPhysicalIndex 调用
  for i := 0 to LMoveCount - 1 do
  begin
    LSrcPhysical := GetPhysicalIndex(FCount - 1 - i);
    LDstPhysical := GetPhysicalIndex(aIndex + i);

    LElement := FBuffer.GetUnChecked(LSrcPhysical);
    FBuffer.PutUnChecked(LDstPhysical, LElement);
  end;

  // 如果是托管类型，清理末尾元素
  if GetIsManagedType then
  begin
    LElement := Default(T);
    for i := FCount - aCount to FCount - 1 do
      FBuffer.Put(GetPhysicalIndex(i), LElement);
  end;

  Dec(FCount, aCount);
end;

procedure TVecDeque.DeleteSwap(aIndex: SizeUInt);
begin
  { 删除单个元素并用末尾元素填补 }
  DeleteSwap(aIndex, 1);
end;

// Remove 系列方法实现
procedure TVecDeque.RemoveCopy(aIndex: SizeUInt; aPtr: Pointer; aCount: SizeUInt);
var
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
  LDstPtr: PByte;
  LElementSize: SizeUInt;
begin
  if aPtr = nil then
    raise EArgumentNil.Create('TVecDeque.RemoveCopy: aPtr is nil');
  if aCount = 0 then
    Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveCopy: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  // ✅ 优化：使用双切片批量复制，避免逐个元素操作
  GetTwoSlices(aIndex, aCount, LPtr1, LLen1, LPtr2, LLen2);
  LElementSize := GetElementSize;
  LDstPtr := PByte(aPtr);

  // 批量内存复制 - O(1) 或 O(log n)
  if LLen1 > 0 then
  begin
    Move(LPtr1^, LDstPtr^, LLen1 * LElementSize);
    Inc(LDstPtr, LLen1 * LElementSize);
  end;
  if LLen2 > 0 then
    Move(LPtr2^, LDstPtr^, LLen2 * LElementSize);

  // 删除该范围（保持顺序）
  Delete(aIndex, aCount);
end;

procedure TVecDeque.RemoveCopy(aIndex: SizeUInt; aPtr: Pointer);
begin
  RemoveCopy(aIndex, aPtr, 1);
end;

procedure TVecDeque.RemoveArray(aIndex: SizeUInt; var aArray: specialize TGenericArray<T>; aCount: SizeUInt);
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  if aCount = 0 then
    Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveArray: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  {$PUSH}{$WARN 5093 OFF}
  SetLength(aArray, aCount);
  {$POP}

  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    aArray[i] := FBuffer.GetUnChecked(LPhysicalIndex);
  end;

  Delete(aIndex, aCount);
end;

procedure TVecDeque.Remove(aIndex: SizeUInt; var aElement: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Remove: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  aElement := Remove(aIndex);
end;


function TVecDeque.RemoveValue(const aElement: T): Boolean;
var
  idx: SizeInt;
begin
  idx := Find(aElement);
  if idx >= 0 then
  begin
    Delete(SizeUInt(idx));
    Exit(True);
  end;
  Result := False;
end;

function TVecDeque.RemoveValue(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): Boolean;
var
  idx: SizeInt;
begin
  idx := Find(aElement, aEquals, aData);
  if idx >= 0 then
  begin
    Delete(SizeUInt(idx));
    Exit(True);
  end;
  Result := False;
end;

function TVecDeque.RemoveValue(const aElement: T; aEquals: TEqualsMethod; aData: Pointer): Boolean;
var
  idx: SizeInt;
begin
  idx := Find(aElement, aEquals, aData);
  if idx >= 0 then
  begin
    Delete(SizeUInt(idx));
    Exit(True);
  end;
  Result := False;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.RemoveValue(const aElement: T; aEquals: TEqualsRefFunc): Boolean;
var
  idx: SizeInt;
begin
  idx := Find(aElement, aEquals);
  if idx >= 0 then
  begin
    Delete(SizeUInt(idx));
    Exit(True);
  end;
  Result := False;
end;
{$ENDIF}
procedure TVecDeque.RemoveCopySwap(aIndex: SizeUInt; aPtr: Pointer; aCount: SizeUInt);
var
  i: SizeUInt;
  LPtr: PByte;
  LPhysicalIndex: SizeUInt;
begin
  if aPtr = nil then
    raise EArgumentNil.Create('TVecDeque.RemoveCopySwap: aPtr is nil');
  if aCount = 0 then Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveCopySwap: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  // 先拷贝
  LPtr := PByte(aPtr);
  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    Move(FBuffer.GetPtrUnChecked(LPhysicalIndex)^, LPtr^, SizeOf(T));
    Inc(LPtr, SizeOf(T));
  end;

  // 再用尾部填补（不保持顺序）
  DeleteSwap(aIndex, aCount);
end;

procedure TVecDeque.RemoveCopySwap(aIndex: SizeUInt; aPtr: Pointer);
begin
  RemoveCopySwap(aIndex, aPtr, 1);
end;

procedure TVecDeque.RemoveArraySwap(aIndex: SizeUInt; var aArray: specialize TGenericArray<T>; aCount: SizeUInt);
var
  i: SizeUInt;
  LPhysicalIndex: SizeUInt;
begin
  if aCount = 0 then Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveArraySwap: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  {$PUSH}{$WARN 5093 OFF}
  SetLength(aArray, aCount);
  {$POP}

  for i := 0 to aCount - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aIndex + i);
    aArray[i] := FBuffer.GetUnChecked(LPhysicalIndex);
  end;

  DeleteSwap(aIndex, aCount);
end;

procedure TVecDeque.RemoveSwap(aIndex: SizeUInt; var aElement: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.RemoveSwap: index %d out of range [0..%d]', [aIndex, FCount - 1]);
  aElement := FBuffer.GetUnChecked(GetPhysicalIndex(aIndex));
  DeleteSwap(aIndex, 1);
end;

// BinarySearch 系列方法实现
function TVecDeque.BinarySearch(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := BinarySearch(aValue, aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := BinarySearch(aValue, aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := BinarySearch(aValue, aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  Result := BinarySearch(aValue, aStartIndex, GetCount - aStartIndex, aComparer);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
begin
  if aStartIndex >= GetCount then
    Exit(-1);

  if aCount = 0 then
    Exit(-1);

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchUnChecked(aValue, aStartIndex, aCount, aComparer);
end;

// BinarySearchInsert 系列方法实现
function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  Result := BinarySearchInsert(aValue, aStartIndex, GetCount - aStartIndex);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  Result := BinarySearchInsert(aValue, aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  Result := BinarySearchInsert(aValue, aStartIndex, GetCount - aStartIndex, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  Result := BinarySearchInsert(aValue, aStartIndex, GetCount - aStartIndex, aComparer);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareMethod; aData: Pointer): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TVecDeque.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: TCompareRefFunc): SizeInt;
begin
  if aStartIndex > GetCount then
    Exit(SizeInt(GetCount));

  if aCount = 0 then
    Exit(SizeInt(aStartIndex));

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  Result := BinarySearchInsertUnChecked(aValue, aStartIndex, aCount, aComparer);
end;

// Shuffle 系列方法实现
procedure TVecDeque.Shuffle(aStartIndex: SizeUInt);
begin
  if aStartIndex >= GetCount then
    Exit;

  Shuffle(aStartIndex, GetCount - aStartIndex);
end;

procedure TVecDeque.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  Shuffle(aStartIndex, GetCount - aStartIndex, aRandomGenerator, aData);
end;

procedure TVecDeque.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  Shuffle(aStartIndex, GetCount - aStartIndex, aRandomGenerator, aData);
end;

procedure TVecDeque.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  Shuffle(aStartIndex, GetCount - aStartIndex, aRandomGenerator);
end;

procedure TVecDeque.Shuffle(aStartIndex, aCount: SizeUInt);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount <= 1 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ShuffleUnChecked(aStartIndex, aCount);
end;

procedure TVecDeque.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount <= 1 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TVecDeque.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount <= 1 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TVecDeque.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aStartIndex >= GetCount then
    Exit;

  if aCount <= 1 then
    Exit;

  if aStartIndex + aCount > GetCount then
    aCount := GetCount - aStartIndex;

  ShuffleUnChecked(aStartIndex, aCount, aRandomGenerator);
end;

// 高级排序算法实现
procedure TVecDeque.SortWith(aAlgorithm: TSortAlgorithm);
begin
  { 使用指定算法排序整个容器 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, aAlgorithm);
end;

procedure TVecDeque.SortWith(aAlgorithm: TSortAlgorithm; aComparer: TCompareFunc; aData: Pointer);
begin
  { 使用指定算法和比较器排序整个容器 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, aAlgorithm, aComparer, aData);
end;

procedure TVecDeque.SortWith(aAlgorithm: TSortAlgorithm; aComparer: TCompareRefFunc);
begin
  { 使用指定算法和比较函数引用排序整个容器 }
  if FCount <= 1 then
    Exit;
  SortWith(0, FCount, aAlgorithm, aComparer);
end;

procedure TVecDeque.SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm);
var
  CPtr: PElement;
  CLen: SizeUInt;
begin
  { 使用指定算法排序指定范围，使用默认比较器 }
  if (aStartIndex >= FCount) or (aCount <= 1) then
    Exit;

  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.SortWith: range out of bounds');

  // 排序前整理为连续内存，降低索引/环处理成本
  MakeContiguous(CPtr, CLen);
  case aAlgorithm of
    saQuickSort: DoQuickSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
    saMergeSort: DoMergeSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
    saHeapSort: DoHeapSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
    saIntroSort: DoIntroSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
    saInsertionSort: DoInsertionSort(aStartIndex, aStartIndex + aCount - 1, nil, nil);
  end;
end;

class function TVecDeque.CompareMethodAdapter(const aLeft, aRight: T; aData: Pointer): SizeInt;
type
  PCompareMethodContext = ^TCompareMethodContext;
var
  LContext: PCompareMethodContext;
begin
  LContext := PCompareMethodContext(aData);
  Result := LContext^.Comparer(aLeft, aRight, LContext^.Data);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
class function TVecDeque.CompareRefFuncAdapter(const aLeft, aRight: T; aData: Pointer): SizeInt;
type
  PCompareRefFunc = ^TCompareRefFunc;
begin
  Result := PCompareRefFunc(aData)^(aLeft, aRight);
end;
{$ENDIF}

procedure TVecDeque.SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm; aComparer: TCompareFunc; aData: Pointer);
var
  CPtr: PElement;
  CLen: SizeUInt;
begin
  { 使用指定算法和比较器排序指定范围 }
  if (aStartIndex >= FCount) or (aCount <= 1) then
    Exit;

  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.SortWith: range out of bounds');

  MakeContiguous(CPtr, CLen);
  case aAlgorithm of
    saQuickSort: DoQuickSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
    saMergeSort: DoMergeSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
    saHeapSort: DoHeapSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
    saIntroSort: DoIntroSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
    saInsertionSort: DoInsertionSort(aStartIndex, aStartIndex + aCount - 1, aComparer, aData);
  end;
end;

procedure TVecDeque.SortWith(aStartIndex, aCount: SizeUInt; aAlgorithm: TSortAlgorithm; aComparer: TCompareRefFunc);
begin
  { 使用指定算法和比较函数引用排序指定范围 }
  if (aStartIndex >= FCount) or (aCount <= 1) then
    Exit;

  if aStartIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.SortWith: range out of bounds');

  SortWith(aStartIndex, aCount, aAlgorithm, @CompareRefFuncAdapter, @aComparer);
end;

// 排序辅助方法实现
function TVecDeque.DoCompare(const aLeft, aRight: T; aComparer: TCompareFunc; aData: Pointer): Integer;
begin
  { 统一的比较方法 - 修复类型安全问题 }
  if Assigned(aComparer) then
    Result := aComparer(aLeft, aRight, aData)
  else
  begin
    // 使用泛型集合的内部默认比较器
    Result := FInternalComparer(aLeft, aRight);
  end;
end;

procedure TVecDeque.DoSwap(aIndex1, aIndex2: SizeUInt);
var
  LElement1, LElement2: T;
  LPhysical1, LPhysical2: SizeUInt;
begin
  { 高效的元素交换 - 优化：减少 GetPhysicalIndex 调用 }
  if aIndex1 = aIndex2 then
    Exit;

  LPhysical1 := GetPhysicalIndex(aIndex1);
  LPhysical2 := GetPhysicalIndex(aIndex2);

  LElement1 := FBuffer.GetUnChecked(LPhysical1);
  LElement2 := FBuffer.GetUnChecked(LPhysical2);
  FBuffer.PutUnChecked(LPhysical1, LElement2);
  FBuffer.PutUnChecked(LPhysical2, LElement1);
end;

function TVecDeque.DoIntroSortDepthLimit(aCount: SizeUInt): Integer;
begin
  { 计算内省排序的深度限制 }
  Result := 0;
  while aCount > 1 do
  begin
    aCount := aCount shr 1;
    Inc(Result);
  end;
  Result := Result * 2;
end;

// 插入排序实现（小数组最优）
procedure TVecDeque.DoInsertionSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
var
  i, j: SizeUInt;
  LKey: T;
  LPhysicalI, LPhysicalJ, LPhysicalJMinus1: SizeUInt;
begin
  { 插入排序 - 对小数组最优 }
  if aLeft >= aRight then
    Exit;

  // 优化：减少 GetPhysicalIndex 调用次数
  for i := aLeft + 1 to aRight do
  begin
    LPhysicalI := GetPhysicalIndex(i);
    LKey := FBuffer.GetUnChecked(LPhysicalI);
    j := i;

    while (j > aLeft) and
          (DoCompare(FBuffer.GetUnChecked(GetPhysicalIndex(j - 1)), LKey, aComparer, aData) > 0) do
    begin
      LPhysicalJ := GetPhysicalIndex(j);
      LPhysicalJMinus1 := GetPhysicalIndex(j - 1);
      FBuffer.PutUnChecked(LPhysicalJ, FBuffer.GetUnChecked(LPhysicalJMinus1));
      Dec(j);
    end;

    LPhysicalJ := GetPhysicalIndex(j);
    FBuffer.PutUnChecked(LPhysicalJ, LKey);
  end;
end;

// 快速排序分区函数 (改进的Lomuto分区，更好处理重复元素)
function TVecDeque.DoPartition(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer): SizeUInt;
var
  LPivot: T;
  i, j: SizeUInt;
  LCompareResult: Integer;
  LJPhysical: SizeUInt;
begin
  { 快速排序的分区操作 - 改进的Lomuto分区方案 }
  if aLeft >= aRight then
  begin
    Result := aLeft;
    Exit;
  end;

  // 选择中间元素作为基准，移到末尾
  DoSwap((aLeft + aRight) div 2, aRight);
  LPivot := FBuffer.GetUnChecked(GetPhysicalIndex(aRight));
  i := aLeft;

  // 优化：减少 GetPhysicalIndex 调用
  for j := aLeft to aRight - 1 do
  begin
    LJPhysical := GetPhysicalIndex(j);
    LCompareResult := DoCompare(FBuffer.GetUnChecked(LJPhysical), LPivot, aComparer, aData);
    if LCompareResult < 0 then  // 严格小于，改善重复元素处理
    begin
      if i <> j then
        DoSwap(i, j);
      Inc(i);
    end;
  end;

  DoSwap(i, aRight);
  Result := i;
end;

// 快速排序实现 (改进版，添加保护机制)
procedure TVecDeque.DoQuickSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
const
  INSERTION_SORT_THRESHOLD = 16; // 小数组使用插入排序
  MAX_RECURSION_DEPTH = 64;     // 最大递归深度保护
procedure QuickSortRecursive(aL, aR: SizeUInt; aDepth: Integer);
  var
    LPart: SizeUInt;
  begin
    // 递归深度保护
    if aDepth <= 0 then
    begin
      DoHeapSort(aL, aR, aComparer, aData);
      Exit;
    end;

    if aL >= aR then
      Exit;

    // 小数组使用插入排序
    if aR - aL + 1 <= INSERTION_SORT_THRESHOLD then
    begin
      DoInsertionSort(aL, aR, aComparer, aData);
      Exit;
    end;

    LPart := DoPartition(aL, aR, aComparer, aData);

    // 递归排序左右两部分
    if LPart > aL then
      QuickSortRecursive(aL, LPart - 1, aDepth - 1);
    if LPart + 1 <= aR then
      QuickSortRecursive(LPart + 1, aR, aDepth - 1);
  end;

begin
  { 快速排序 - 改进版，平均O(n log n) }
  if aLeft >= aRight then
    Exit;

  QuickSortRecursive(aLeft, aRight, MAX_RECURSION_DEPTH);
end;

// 堆化操作 (标准实现)
procedure TVecDeque.DoHeapify(aIndex, aHeapSize: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
var
  LLargest, LLeft, LRight: SizeUInt;
  LPhysicalLargest, LPhysicalLeft, LPhysicalRight: SizeUInt;
begin
  { 维护最大堆性质 }
  LLargest := aIndex;
  LLeft := 2 * aIndex + 1;
  LRight := 2 * aIndex + 2;

  // 找到最大的元素 - 优化：减少 GetPhysicalIndex 调用
  LPhysicalLargest := GetPhysicalIndex(LLargest);

  if (LLeft < aHeapSize) then
  begin
    LPhysicalLeft := GetPhysicalIndex(LLeft);
    if DoCompare(FBuffer.GetUnChecked(LPhysicalLeft),
                 FBuffer.GetUnChecked(LPhysicalLargest), aComparer, aData) > 0 then
    begin
      LLargest := LLeft;
      LPhysicalLargest := LPhysicalLeft;
    end;
  end;

  if (LRight < aHeapSize) then
  begin
    LPhysicalRight := GetPhysicalIndex(LRight);
    if DoCompare(FBuffer.GetUnChecked(LPhysicalRight),
                 FBuffer.GetUnChecked(LPhysicalLargest), aComparer, aData) > 0 then
      LLargest := LRight;
  end;

  // 如果最大元素不是根节点，交换并递归堆化
  if LLargest <> aIndex then
  begin
    DoSwap(aIndex, LLargest);
    DoHeapify(LLargest, aHeapSize, aComparer, aData);
  end;
end;

// 堆排序实现 (完全重写，标准教科书算法)
procedure TVecDeque.DoHeapSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
var
  i, LHeapSize: SizeUInt;

  procedure MaxHeapify(aIndex: SizeUInt; aSize: SizeUInt);
  var
    LLargest, LLeft, LRight: SizeUInt;
    LNeedSwap: Boolean;
  begin
    { 维护最大堆性质 - 使用迭代而非递归避免栈溢出 }
    repeat
      LNeedSwap := False;
      LLargest := aIndex;

      // 计算左右子节点的逻辑索引
      LLeft := 2 * (aIndex - aLeft) + 1 + aLeft;
      LRight := 2 * (aIndex - aLeft) + 2 + aLeft;

      // 检查左子节点
      if (LLeft < aLeft + aSize) then
      begin
        if DoCompare(FBuffer.GetUnChecked(GetPhysicalIndex(LLeft)),
                     FBuffer.GetUnChecked(GetPhysicalIndex(LLargest)), aComparer, aData) > 0 then
          LLargest := LLeft;
      end;

      // 检查右子节点
      if (LRight < aLeft + aSize) then
      begin
        if DoCompare(FBuffer.GetUnChecked(GetPhysicalIndex(LRight)),
                     FBuffer.GetUnChecked(GetPhysicalIndex(LLargest)), aComparer, aData) > 0 then
          LLargest := LRight;
      end;

      // 如果需要交换
      if LLargest <> aIndex then
      begin
        DoSwap(aIndex, LLargest);
        aIndex := LLargest;
        LNeedSwap := True;
      end;
    until not LNeedSwap;
  end;

begin
  { 堆排序 - 标准算法 O(n log n) }
  if aLeft >= aRight then
    Exit;

  LHeapSize := aRight - aLeft + 1;

  // 第一阶段：构建最大堆
  // 从最后一个非叶子节点开始，向上堆化
  if LHeapSize > 1 then
  begin
    i := aLeft + (LHeapSize div 2) - 1;
    while True do
    begin
      MaxHeapify(i, LHeapSize);
      if i = aLeft then Break; // 防止无符号整数下溢
      Dec(i);
    end;
  end;

  // 第二阶段：逐个提取最大元素
  for i := aRight downto aLeft + 1 do
  begin
    // 将堆顶（最大元素）与当前末尾交换
    DoSwap(aLeft, i);
    // 减少堆大小
    Dec(LHeapSize);
    // 重新堆化
    MaxHeapify(aLeft, LHeapSize);
  end;
end;

// 归并操作
procedure TVecDeque.DoMerge(aLeft, aMid, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
var
  LTemp: array of T;
  i, j, k: SizeUInt;
  LLeftSize, LRightSize: SizeUInt;
  LPhysicalIndex: SizeUInt;
  LPhysicalK: SizeUInt;
begin
  { 归并两个已排序的子数组 }
  LLeftSize := aMid - aLeft + 1;
  LRightSize := aRight - aMid;

  // 创建临时数组
  LTemp := nil;
  SetLength(LTemp, LLeftSize + LRightSize);

  // 复制数据到临时数组 - 优化：减少 GetPhysicalIndex 调用
  for i := 0 to LLeftSize - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aLeft + i);
    LTemp[i] := FBuffer.GetUnChecked(LPhysicalIndex);
  end;
  for j := 0 to LRightSize - 1 do
  begin
    LPhysicalIndex := GetPhysicalIndex(aMid + 1 + j);
    LTemp[LLeftSize + j] := FBuffer.GetUnChecked(LPhysicalIndex);
  end;

  // 归并临时数组回原数组
  i := 0; j := LLeftSize; k := aLeft;

  // 优化：减少 GetPhysicalIndex 调用次数
  while (i < LLeftSize) and (j < LLeftSize + LRightSize) do
  begin
    LPhysicalK := GetPhysicalIndex(k);
    if DoCompare(LTemp[i], LTemp[j], aComparer, aData) <= 0 then
    begin
      FBuffer.PutUnChecked(LPhysicalK, LTemp[i]);
      Inc(i);
    end
    else
    begin
      FBuffer.PutUnChecked(LPhysicalK, LTemp[j]);
      Inc(j);
    end;
    Inc(k);
  end;

  // 复制剩余元素 - 优化：减少 GetPhysicalIndex 调用次数
  while i < LLeftSize do
  begin
    LPhysicalK := GetPhysicalIndex(k);
    FBuffer.PutUnChecked(LPhysicalK, LTemp[i]);
    Inc(i);
    Inc(k);
  end;

  while j < LLeftSize + LRightSize do
  begin
    LPhysicalK := GetPhysicalIndex(k);
    FBuffer.PutUnChecked(LPhysicalK, LTemp[j]);
    Inc(j);
    Inc(k);
  end;
end;

// 归并排序实现
procedure TVecDeque.DoMergeSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
var
  LMid: SizeUInt;
begin
  { 归并排序 - 稳定O(n log n) }
  if aLeft >= aRight then
    Exit;

  LMid := aLeft + (aRight - aLeft) div 2;

  // 递归排序左右两半
  DoMergeSort(aLeft, LMid, aComparer, aData);
  DoMergeSort(LMid + 1, aRight, aComparer, aData);

  // 归并结果
  DoMerge(aLeft, LMid, aRight, aComparer, aData);
end;

// 内省排序实现（混合算法）
procedure TVecDeque.DoIntroSort(aLeft, aRight: SizeUInt; aComparer: TCompareFunc; aData: Pointer);
const
  INSERTION_SORT_THRESHOLD = 16;
var
  LDepthLimit: Integer;
  LPartition: SizeUInt;

  procedure IntroSortRecursive(aL, aR: SizeUInt; aDepth: Integer);
  begin
    if aL >= aR then
      Exit;

    // 小数组使用插入排序
    if aR - aL + 1 <= INSERTION_SORT_THRESHOLD then
    begin
      DoInsertionSort(aL, aR, aComparer, aData);
      Exit;
    end;

    // 递归深度过深时使用堆排序
    if aDepth = 0 then
    begin
      DoHeapSort(aL, aR, aComparer, aData);
      Exit;
    end;

    // 否则使用快速排序
    LPartition := DoPartition(aL, aR, aComparer, aData);
    if LPartition > aL then
      IntroSortRecursive(aL, LPartition - 1, aDepth - 1);
    if LPartition + 1 <= aR then
      IntroSortRecursive(LPartition + 1, aR, aDepth - 1);
  end;

begin
  { 内省排序 - 混合算法，最优性能 }
  if aLeft >= aRight then
    Exit;

  LDepthLimit := DoIntroSortDepthLimit(aRight - aLeft + 1);
  IntroSortRecursive(aLeft, aRight, LDepthLimit);
end;

// 所有并行方法实现已移除，使用标准方法替代

{ IQueue<T> 接口实现 - 缺失的方法 }

procedure TVecDeque.Enqueue(const aElements: array of T);
begin
  PushBack(aElements);
end;

procedure TVecDeque.Enqueue(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  PushBack(aSrc, aElementCount);
end;



function TVecDeque.Front: T;
begin
  Result := PeekFront;
end;

function TVecDeque.Front(var aElement: T): Boolean;
begin
  Result := PeekFront(aElement);
end;

function TVecDeque.Back: T;
begin
  Result := PeekBack;
end;

function TVecDeque.Back(var aElement: T): Boolean;
begin
  Result := PeekBack(aElement);
end;

function TVecDeque.TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex < GetCount then
  begin
    aElement := GetUnChecked(aIndex);
    Result := True;
  end
  else
    Result := False;
end;

function TVecDeque.TryRemove(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex < GetCount then
  begin
    aElement := Remove(aIndex);
    Result := True;
  end
  else
    Result := False;
end;

procedure TVecDeque.Resize(aNewSize: SizeUInt; const aValue: T);
var
  LCurrentSize: SizeUInt;
  i: SizeUInt;
begin
  LCurrentSize := GetCount;
  if aNewSize > LCurrentSize then
  begin
    // 扩展：添加默认值
    for i := LCurrentSize to aNewSize - 1 do
      PushBack(aValue);
  end
  else if aNewSize < LCurrentSize then
  begin
    // 收缩：移除多余元素
    while GetCount > aNewSize do
      PopBack;
  end;
  // 如果 aNewSize = LCurrentSize，不需要做任何操作
end;

procedure TVecDeque.Append(const aOther: TQueueIntf);
var
  LElement: T;
  LCollection: ICollection;
  LIter: TPtrIter;
  LElementPtr: PElement;
begin
  if aOther = nil then
    Exit;

  // 优先尝试非破坏性路径（目标实现了 ICollection，可获取元素指针迭代器）
  if Supports(aOther, ICollection, LCollection) then
  begin
    LIter := LCollection.PtrIter;
    while LIter.MoveNext do
    begin
      LElementPtr := PElement(LIter.Current);
      if LElementPtr <> nil then
        PushBack(LElementPtr^);
    end;
    Exit;
  end;

  // 兼容退化实现：逐个弹出（会清空来源，但这是最后的兜底方案）
  while aOther.Count > 0 do
  begin
    LElement := aOther.Pop;
    PushBack(LElement);
  end;
end;

function TVecDeque.SplitOff(aAt: SizeUInt): TQueueIntf;
var
  LNewDeque: TVecDeque;
  LMoveCount: SizeUInt;
  P1, P2: PElement;
  L1, L2: SizeUInt;
  LNewCap: SizeUInt;
begin
  if aAt > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.SplitOff: index %d > count %d', [aAt, FCount]);

  // 创建新的 VecDeque（沿用相同 allocator，然后设置接口策略）
  LNewDeque := TVecDeque.Create(VECDEQUE_DEFAULT_CAPACITY, FBuffer.GetAllocator, nil, nil);
  LNewDeque.FGrowStrategy := FGrowStrategy;  // 共享接口引用

  // 快路径：分割点在末尾 -> 返回空新队列
  if aAt = FCount then
  begin
    Result := LNewDeque as TQueueIntf;
    Exit;
  end;

  // 快路径：分割点在开头 -> 直接转移整个缓冲区到新队列，当前队列重置为空
  if aAt = 0 then
  begin
    // 释放新队列默认缓冲区，转移当前缓冲区所有权
    if LNewDeque.FBuffer <> nil then
      LNewDeque.FBuffer.Free;
    LNewDeque.FBuffer := FBuffer;
    LNewDeque.FHead   := FHead;
    LNewDeque.FTail   := FTail;
    LNewDeque.FCount  := FCount;
    LNewDeque.UpdateCapacityMask;

    // 重新初始化当前队列为“空且容量为默认值”的状态
    FBuffer := TInternalArray.Create(NextPowerOfTwo(VECDEQUE_DEFAULT_CAPACITY), LNewDeque.FBuffer.GetAllocator);
    FHead := 0;
    FTail := 0;
    FCount := 0;
    UpdateCapacityMask;

    Result := LNewDeque as TQueueIntf;
    Exit;
  end;

  // 通用路径：将 [aAt .. FCount-1] 批量搬运到新队列
  LMoveCount := FCount - aAt;

  // 预留新队列容量（最终仍会被规范化到 2 的幂）
  LNewCap := LMoveCount;
  if LNewCap < VECDEQUE_DEFAULT_CAPACITY then
    LNewCap := VECDEQUE_DEFAULT_CAPACITY;
  LNewDeque.ReserveExact(LNewCap);

  // 两段切片复制，避免逐元素成本
  GetTwoSlices(aAt, LMoveCount, P1, L1, P2, L2);
  if L1 > 0 then
    LNewDeque.PushBack(P1, L1);
  if L2 > 0 then
    LNewDeque.PushBack(P2, L2);

  // 托管类型安全：对被移除区间做零化以释放引用
  if GetIsManagedType and (LMoveCount > 0) then
    Zero(aAt, LMoveCount);

  // 截断当前队列（O(1) 调整）
  FCount := aAt;
  FTail  := WrapAdd(FHead, FCount);

  // 返回接口类型，明确所有权转移给调用方
  Result := LNewDeque as TQueueIntf;
end;



{ MinElement/MaxElement 系列方法实现 }

function TVecDeque.MinElement: T;
var
  i: SizeUInt;
  LMinValue: T;
  LCurrentValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElement: collection is empty');

  LMinValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    LCurrentValue := GetUnChecked(i);
    if FInternalComparer(LCurrentValue, LMinValue) < 0 then
      LMinValue := LCurrentValue;
  end;
  Result := LMinValue;
end;

function TVecDeque.MinElement(aComparer: TCompareFunc; aData: Pointer): T;
var
  i: SizeUInt;
  LMinValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElement: collection is empty');

  LMinValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue, aData) < 0 then
      LMinValue := GetUnChecked(i);
  end;
  Result := LMinValue;
end;

function TVecDeque.MinElement(aComparer: TCompareMethod; aData: Pointer): T;
var
  i: SizeUInt;
  LMinValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElement: collection is empty');

  LMinValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue, aData) < 0 then
      LMinValue := GetUnChecked(i);
  end;
  Result := LMinValue;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.MinElement(aComparer: TCompareRefFunc): T;
var
  i: SizeUInt;
  LMinValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElement: collection is empty');

  LMinValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue) < 0 then
      LMinValue := GetUnChecked(i);
  end;
  Result := LMinValue;
end;
{$ENDIF}

function TVecDeque.MaxElement: T;
var
  i: SizeUInt;
  LMaxValue: T;
  LCurrentValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElement: collection is empty');

  LMaxValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    LCurrentValue := GetUnChecked(i);
    if FInternalComparer(LCurrentValue, LMaxValue) > 0 then
      LMaxValue := LCurrentValue;
  end;
  Result := LMaxValue;
end;

function TVecDeque.MaxElement(aComparer: TCompareFunc; aData: Pointer): T;
var
  i: SizeUInt;
  LMaxValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElement: collection is empty');

  LMaxValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue, aData) > 0 then
      LMaxValue := GetUnChecked(i);
  end;
  Result := LMaxValue;
end;

function TVecDeque.MaxElement(aComparer: TCompareMethod; aData: Pointer): T;
var
  i: SizeUInt;
  LMaxValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElement: collection is empty');

  LMaxValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue, aData) > 0 then
      LMaxValue := GetUnChecked(i);
  end;
  Result := LMaxValue;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.MaxElement(aComparer: TCompareRefFunc): T;
var
  i: SizeUInt;
  LMaxValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElement: collection is empty');

  LMaxValue := GetUnChecked(0);
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue) > 0 then
      LMaxValue := GetUnChecked(i);
  end;
  Result := LMaxValue;
end;
{$ENDIF}

{ MinElementIndex/MaxElementIndex 系列方法实现 }

function TVecDeque.MinElementIndex: SizeUInt;
var
  i: SizeUInt;
  LMinValue: T;
  LMinIndex: SizeUInt;
  LCurrentValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElementIndex: collection is empty');

  LMinValue := GetUnChecked(0);
  LMinIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    LCurrentValue := GetUnChecked(i);
    if FInternalComparer(LCurrentValue, LMinValue) < 0 then
    begin
      LMinValue := LCurrentValue;
      LMinIndex := i;
    end;
  end;
  Result := LMinIndex;
end;

function TVecDeque.MinElementIndex(aComparer: TCompareFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LMinValue: T;
  LMinIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElementIndex: collection is empty');

  LMinValue := GetUnChecked(0);
  LMinIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue, aData) < 0 then
    begin
      LMinValue := GetUnChecked(i);
      LMinIndex := i;
    end;
  end;
  Result := LMinIndex;
end;

function TVecDeque.MinElementIndex(aComparer: TCompareMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LMinValue: T;
  LMinIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElementIndex: collection is empty');

  LMinValue := GetUnChecked(0);
  LMinIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue, aData) < 0 then
    begin
      LMinValue := GetUnChecked(i);
      LMinIndex := i;
    end;
  end;
  Result := LMinIndex;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.MinElementIndex(aComparer: TCompareRefFunc): SizeUInt;
var
  i: SizeUInt;
  LMinValue: T;
  LMinIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MinElementIndex: collection is empty');

  LMinValue := GetUnChecked(0);
  LMinIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMinValue) < 0 then
    begin
      LMinValue := GetUnChecked(i);
      LMinIndex := i;
    end;
  end;
  Result := LMinIndex;
end;
{$ENDIF}

function TVecDeque.MaxElementIndex: SizeUInt;
var
  i: SizeUInt;
  LMaxValue: T;
  LMaxIndex: SizeUInt;
  LCurrentValue: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElementIndex: collection is empty');

  LMaxValue := GetUnChecked(0);
  LMaxIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    LCurrentValue := GetUnChecked(i);
    if FInternalComparer(LCurrentValue, LMaxValue) > 0 then
    begin
      LMaxValue := LCurrentValue;
      LMaxIndex := i;
    end;
  end;
  Result := LMaxIndex;
end;

function TVecDeque.MaxElementIndex(aComparer: TCompareFunc; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LMaxValue: T;
  LMaxIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElementIndex: collection is empty');

  LMaxValue := GetUnChecked(0);
  LMaxIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue, aData) > 0 then
    begin
      LMaxValue := GetUnChecked(i);
      LMaxIndex := i;
    end;
  end;
  Result := LMaxIndex;
end;

function TVecDeque.MaxElementIndex(aComparer: TCompareMethod; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LMaxValue: T;
  LMaxIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElementIndex: collection is empty');

  LMaxValue := GetUnChecked(0);
  LMaxIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue, aData) > 0 then
    begin
      LMaxValue := GetUnChecked(i);
      LMaxIndex := i;
    end;
  end;
  Result := LMaxIndex;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.MaxElementIndex(aComparer: TCompareRefFunc): SizeUInt;
var
  i: SizeUInt;
  LMaxValue: T;
  LMaxIndex: SizeUInt;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.MaxElementIndex: collection is empty');

  LMaxValue := GetUnChecked(0);
  LMaxIndex := 0;
  for i := 1 to FCount - 1 do
  begin
    if aComparer(GetUnChecked(i), LMaxValue) > 0 then
    begin
      LMaxValue := GetUnChecked(i);
      LMaxIndex := i;
    end;
  end;
  Result := LMaxIndex;
end;
{$ENDIF}

{ Filter 系列方法实现 }

function TVecDeque.Filter(aPredicate: TPredicateFunc; aData: Pointer): specialize IVec<T>;
var
  i: SizeUInt;
  LResult: specialize TVec<T>;
begin
  LResult := specialize TVec<T>.Create;
  try
    for i := 0 to FCount - 1 do
    begin
      if aPredicate(GetUnChecked(i), aData) then
        LResult.PushUnChecked(GetUnChecked(i));
    end;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

function TVecDeque.Filter(aPredicate: TPredicateMethod; aData: Pointer): specialize IVec<T>;
var
  i: SizeUInt;
  LResult: specialize TVec<T>;
begin
  LResult := specialize TVec<T>.Create;
  try
    for i := 0 to FCount - 1 do
    begin
      if aPredicate(GetUnChecked(i), aData) then
        LResult.PushUnChecked(GetUnChecked(i));
    end;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.Filter(aPredicate: TPredicateRefFunc): specialize IVec<T>;
var
  i: SizeUInt;
  LResult: specialize TVec<T>;
begin
  LResult := specialize TVec<T>.Create;
  try
    for i := 0 to FCount - 1 do
    begin
      if aPredicate(GetUnChecked(i)) then
        LResult.PushUnChecked(GetUnChecked(i));
    end;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;
{$ENDIF}

// 删除重复的 RotateLeft/RotateRight 实现 - 已在上面实现

{ Range 命名范式方法实现 }

procedure TVecDeque.InsertRange(aIndex: SizeUInt; const aElements: array of T);
begin
  Insert(aIndex, aElements);  // 复用现有实现
end;

procedure TVecDeque.InsertRange(aIndex: SizeUInt; const aOther: TCollection);
begin
  Insert(aIndex, aOther, 0);  // 复用现有实现，从索引0开始
end;

procedure TVecDeque.PushFrontRange(const aElements: array of T);
begin
  PushFront(aElements);  // 复用现有实现
end;

procedure TVecDeque.PushFrontRange(const aPtr: Pointer; aCount: SizeUInt);
begin
  PushFront(aPtr, aCount);  // 复用现有实现
end;

procedure TVecDeque.PushBackRange(const aElements: array of T);
begin
  PushBack(aElements);  // 复用现有实现
end;

procedure TVecDeque.PushBackRange(const aPtr: Pointer; aCount: SizeUInt);
begin
  PushBack(aPtr, aCount);  // 复用现有实现
end;

procedure TVecDeque.RemoveRange(aIndex, aCount: SizeUInt; aPtr: Pointer);
begin
  RemoveCopy(aIndex, aPtr, aCount);  // 复用现有优化实现
end;

procedure TVecDeque.RemoveRange(aIndex, aCount: SizeUInt; var aArray: specialize TGenericArray<T>);
var
  i: SizeUInt;
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if aCount = 0 then Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.Create('TVecDeque.RemoveRange: range out of bounds');

  // 调整数组大小
  SetLength(aArray, aCount);

  // 获取两段切片并复制到数组
  GetTwoSlices(aIndex, aCount, LPtr1, LLen1, LPtr2, LLen2);
  for i := 0 to LLen1 - 1 do
    aArray[i] := LPtr1[i];
  for i := 0 to LLen2 - 1 do
    aArray[LLen1 + i] := LPtr2[i];

  // 删除该范围
  Delete(aIndex, aCount);
end;

procedure TVecDeque.RemoveRange(aIndex, aCount: SizeUInt; const aTarget: TCollection);
var
  LPtr1, LPtr2: PElement;
  LLen1, LLen2: SizeUInt;
begin
  if aTarget = nil then
    raise EArgumentNil.Create('aTarget cannot be nil');
  if aCount = 0 then Exit;
  if aIndex + aCount > FCount then
    raise EOutOfRange.CreateFmt('RemoveRange: range [%d..%d] out of bounds [0..%d]',
      [aIndex, aIndex + aCount - 1, FCount - 1]);

  // 使用双切片高效复制到目标容器
  GetTwoSlices(aIndex, aCount, LPtr1, LLen1, LPtr2, LLen2);
  if LLen1 > 0 then aTarget.AppendUnChecked(LPtr1, LLen1);
  if LLen2 > 0 then aTarget.AppendUnChecked(LPtr2, LLen2);

  // 删除该范围
  Delete(aIndex, aCount);
end;

{ 现代化便利方法实现 }

function TVecDeque.RemoveFirstOccurrence(const aElement: T): Boolean;
var
  LIndex: SizeInt;
begin
  LIndex := FastIndexOf(aElement);
  if LIndex >= 0 then
  begin
    Delete(SizeUInt(LIndex));
    Result := True;
  end
  else
    Result := False;
end;

function TVecDeque.RemoveLastOccurrence(const aElement: T): Boolean;
var
  LIndex: SizeInt;
begin
  LIndex := FastLastIndexOf(aElement);
  if LIndex >= 0 then
  begin
    Delete(SizeUInt(LIndex));
    Result := True;
  end
  else
    Result := False;
end;

{ IVec<T> 接口缺失方法实现 }

function TVecDeque.Any(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i), aData) then
      Exit(True);
  Result := False;
end;

function TVecDeque.Any(aPredicate: TPredicateMethod; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i), aData) then
      Exit(True);
  Result := False;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.Any(aPredicate: TPredicateRefFunc): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i)) then
      Exit(True);
  Result := False;
end;
{$ENDIF}

function TVecDeque.All(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnChecked(i), aData) then
      Exit(False);
  Result := True;
end;

function TVecDeque.All(aPredicate: TPredicateMethod; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnChecked(i), aData) then
      Exit(False);
  Result := True;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TVecDeque.All(aPredicate: TPredicateRefFunc): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnChecked(i)) then
      Exit(False);
  Result := True;
end;
{$ENDIF}

procedure TVecDeque.Retain(aPredicate: TPredicateFunc; aData: Pointer);
var
  i, j: SizeUInt;
begin
  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i), aData) then
    begin
      if i <> j then
        PutUnChecked(j, GetUnChecked(i));
      Inc(j);
    end;
  Resize(j);
end;

procedure TVecDeque.Retain(aPredicate: TPredicateMethod; aData: Pointer);
var
  i, j: SizeUInt;
begin
  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i), aData) then
    begin
      if i <> j then
        PutUnChecked(j, GetUnChecked(i));
      Inc(j);
    end;
  Resize(j);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TVecDeque.Retain(aPredicate: TPredicateRefFunc);
var
  i, j: SizeUInt;
begin
  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnChecked(i)) then
    begin
      if i <> j then
        PutUnChecked(j, GetUnChecked(i));
      Inc(j);
    end;
  Resize(j);
end;
{$ENDIF}

function TVecDeque.Drain(aStart, aCount: SizeUInt): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  i: SizeUInt;
begin
  if aStart >= FCount then
    raise EOutOfRange.Create('Drain: start index out of range');
  if aStart + aCount > FCount then
    aCount := FCount - aStart;

  LResult := specialize TVec<T>.Create(aCount, GetAllocator, nil);
  try
    for i := 0 to aCount - 1 do
      LResult.PushUnChecked(GetUnChecked(aStart + i));

    Delete(aStart, aCount);
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

function TVecDeque.DrainRange(aStart, aEnd: SizeUInt): TDrainIter;
var
  LCount: SizeUInt;
  LDrained: IVecT;
begin
  // 半开区间 [aStart, aEnd) 转换为 (start, count) 格式
  if aEnd <= aStart then
    LCount := 0
  else
    LCount := aEnd - aStart;

  // 空范围特殊处理
  if LCount = 0 then
  begin
    LDrained := specialize TVec<T>.Create;
    Result.Init(LDrained);
    Exit;
  end;

  // 使用原有 Drain 方法获取被移除的元素
  LDrained := Drain(aStart, LCount);
  Result.Init(LDrained);
end;

{ TVecDeque.TDrainIter }

procedure TVecDeque.TDrainIter.Init(const aDrained: IVecT);
begin
  FDrained := aDrained;
  FIndex := 0;
  FCurrent := Default(T);
end;

function TVecDeque.TDrainIter.MoveNext: Boolean;
begin
  if FIndex < FDrained.Count then
  begin
    FCurrent := FDrained.Get(FIndex);
    Inc(FIndex);
    Result := True;
  end
  else
    Result := False;
end;

function TVecDeque.TDrainIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ SplitOffToVec / Splice 方法实现 }

function TVecDeque.SplitOffToVec(aIndex: SizeUInt): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  LSplitCount: SizeUInt;
  i: SizeUInt;
begin
  // 边界检查
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.SplitOffToVec: index %d out of range [0..%d]', [aIndex, FCount]);

  // 计算要分离的元素数量
  LSplitCount := FCount - aIndex;

  // 创建新的 Vec 保存 [aIndex, Count) 范围的元素
  LResult := specialize TVec<T>.Create(LSplitCount, GetAllocator, nil);
  try
    // 复制元素到新 Vec
    for i := aIndex to FCount - 1 do
      LResult.PushUnChecked(GetUnChecked(i));

    // 截断原 VecDeque 到 [0, aIndex)
    Truncate(aIndex);

    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

procedure TVecDeque.Splice(aIndex, aRemoveCount: SizeUInt; const aInsert: array of T);
var
  i: SizeUInt;
begin
  // 边界检查
  if aIndex > FCount then
    raise EOutOfRange.CreateFmt('TVecDeque.Splice: index %d out of range [0..%d]', [aIndex, FCount]);

  // 调整移除数量，避免越界
  if aIndex + aRemoveCount > FCount then
    aRemoveCount := FCount - aIndex;

  // 先删除元素
  if aRemoveCount > 0 then
    Delete(aIndex, aRemoveCount);

  // 再插入新元素
  if Length(aInsert) > 0 then
  begin
    for i := 0 to High(aInsert) do
      Insert(aIndex + i, aInsert[i]);
  end;
end;

function TVecDeque.First: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.First: collection is empty');
  Result := GetUnChecked(0);
end;

function TVecDeque.Last: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TVecDeque.Last: collection is empty');
  Result := GetUnChecked(FCount - 1);
end;

end.
