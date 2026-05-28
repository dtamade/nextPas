unit nextpas.core.collections.vec;
{ TVec/IVec quick guide: see docs/README_TVec.md }


{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.collections.base,
  nextpas.core.collections.arr.base,
  nextpas.core.collections.arr.intf,
  nextpas.core.collections.vec.base,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.arr,
  nextpas.core.collections.slice,
  nextpas.core.mem.allocator;

function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;

type


  {**
   * TVec<T>
   *
   * @desc 动态向量实现，连续内存的可变长度数组
   *
   * @param T 元素类型
   *
   * @note
   *   - 底层使用 TArray<T> 存储，保证内存连续
   *   - 支持可配置的增长策略（默认 1.5x）
   *   - 提供栈操作（Push/Pop）、函数式操作（Filter/Retain）
   *   - 支持 O(1) 的交换删除（DeleteSwap）
   *
   * @threadsafety 非线程安全
   *
   * @example
   *   var Vec: specialize TVec<Integer>;
   *   Vec := specialize TVec<Integer>.Create;
   *   try
   *     Vec.Push(1);
   *     Vec.Push(2);
   *     WriteLn(Vec.Pop);  // 2
   *   finally
   *     Vec.Free;
   *   end;
   *
   * @see IVec 接口定义
   * @see TVecDeque 双端队列替代方案
   *}
  generic TVec<T> = class(specialize TGenericCollection<T>, specialize IVec<T>)
  public type
    IVecT = specialize IVec<T>;
    {**
     * TDrainIter - Drain 迭代器
     *
     * @desc 消费式范围迭代器，迭代被 drain 的元素
     *       调用 Drain 时立即从原容器移除元素，迭代器逐个返回
     *}
    TDrainIter = record
    private
      FDrained: IVecT;
      FIndex: SizeUInt;
      FCurrent: T;
    public
      procedure Init(const aDrained: IVecT);
      function MoveNext: Boolean;
      function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
      property Current: T read GetCurrent;
    end;
  type
    TVecBuf = specialize TArray<T>;
    TSpan   = specialize TReadOnlySpan<T>;
  private
    FBuf:          TVecBuf;
    FCount:        SizeUInt;
    FGrowStrategy: IGrowthStrategy;
    FPrevNonAlignedStrategy: IGrowthStrategy; // 保存启用对齐包装前的策略以便恢复


  { 迭代器回调}
{ 参见迭代器最佳实践：docs/Iterator_BestPractices.md }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  DoIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

  protected
    function  IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean; override;
    function  GetDefaultGrowStrategyI: IGrowthStrategy; virtual;
    function  CalcGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

  { 基类虚方法实现}
  protected
    procedure DoFill(const aElement: T); override;
    procedure DoZero; override;
    procedure DoReverse; override;
  public
    constructor Create; reintroduce; overload;
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    constructor Create(aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy); overload;
    constructor Create(aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer); overload;

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

    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    // IStack compatibility: expose Count() as a method as well
    function  Count: SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure LoadFromUnchecked(const aSrc: Pointer; aCount: SizeUInt); override; overload;
    procedure AppendUnchecked(const aSrc: Pointer; aCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;
    procedure SaveToUnchecked(aDst: TCollection); override;

    function  GetMemory: PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  Get(aIndex: SizeUInt): T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetUnchecked(aIndex: SizeUInt): T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Put(aIndex: SizeUInt; const aValue: T); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure PutUnchecked(aIndex: SizeUInt; const aValue: T); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetPtr(aIndex: SizeUInt): PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetPtrUnchecked(aIndex: SizeUInt): PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    // Read-only view into a contiguous subrange (zero-copy)
    function  SliceView(aIndex, aCount: SizeUInt): TSpan; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Resize(aNewSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Ensure(aCount: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Overwrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure OverwriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Overwrite(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure OverwriteUnchecked(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Overwrite(aIndex: SizeUInt; const aSrc: TCollection); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Overwrite(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure OverwriteUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure ReadUnchecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure ReadUnchecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Swap(aIndex1, aIndex2: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SwapUnchecked(aIndex1, aIndex2: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Swap(aIndex1, aIndex2, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Swap(aIndex1, aIndex2, aCount, aSwapBufferSize: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Copy(aSrcIndex, aDstIndex, aCount: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure CopyUnchecked(aSrcIndex, aDstIndex, aCount: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Fill(aIndex: SizeUInt; const aValue: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Fill(aIndex, aCount: SizeUInt; const aValue: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Zero(aIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Zero(aIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    function Find(const aValue: T): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function Find(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    procedure Reverse(aStartIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Reverse(aStartIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindLastIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindLastIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    procedure Sort; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aComparer: specialize TCompareRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure Sort(aStartIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure Sort(aStartIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function BinarySearch(const aElement: T): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function BinarySearchInsert(const aElement: T): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    procedure Shuffle; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure Shuffle(aStartIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    procedure Shuffle(aStartIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function IsSorted: Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aComparer: specialize TCompareRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function IsSorted(aStartIndex: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}
    function IsSorted(aStartIndex, aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindLast(const aValue: T): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindLast(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function Contains(const aValue: T; aStartIndex: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function  GetCapacity: SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SetCapacity(aCapacity: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetGrowStrategy: IGrowthStrategy; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SetGrowStrategy(aGrowStrategy: IGrowthStrategy); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    function  TryReserve(aAdditional: SizeUInt): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Reserve(aAdditional: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryReserveExact(aAdditional: SizeUInt): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure ReserveExact(aAdditional: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure EnsureCapacity(aCapacity: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Shrink;
    procedure ShrinkTo(aCapacity: SizeUInt);
    procedure ShrinkToFit;

    procedure FreeBuffer;
    procedure EnableAlignedGrowth(aAlignElements: SizeUInt = 64);
    procedure DisableAlignedGrowth;
    function  IsAlignedGrowthEnabled: Boolean;
    procedure Truncate(aCount: SizeUInt);
    procedure ResizeExact(aNewSize: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Insert(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure InsertUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Insert(aIndex: SizeUInt; const aElement: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure InsertUnchecked(aIndex: SizeUInt; const aElement: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Insert(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Insert(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure InsertUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Write(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Write(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteUnchecked(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Write(aIndex: SizeUInt; const aSrc: TCollection); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Write(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure WriteExact(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExactUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExactUnchecked(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: TCollection); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExact(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure WriteExactUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Push(const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Push(const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Push(const aSrc: TCollection; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Push(const aElement: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPop(aDst: Pointer; aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPop(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPop(var aDst: T): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPeek(out aElement: T): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}


    function  Pop: T; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPeekCopy(aDst: Pointer; aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryPeek(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  PeekRange(aCount: SizeUInt): PElement; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  Peek: T; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure Delete(aIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Delete(aIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure DeleteSwap(aIndex, aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure DeleteSwap(aIndex: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    procedure RemoveCopyAt(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure RemoveCopyAt(aIndex: SizeUInt; aDst: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure RemoveArrayAt(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure RemoveAt(aIndex: SizeUInt; var aElement: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  RemoveAt(aIndex: SizeUInt): T; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TryRemoveAt(aIndex: SizeUInt; var aElement: T): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SwapRemoveCopyAt(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SwapRemoveCopyAt(aIndex: SizeUInt; aDst: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SwapRemoveArrayAt(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure SwapRemoveAt(aIndex: SizeUInt; var aElement: T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  SwapRemoveAt(aIndex: SizeUInt): T; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  TrySwapRemoveAt(aIndex: SizeUInt; var aElement: T): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    { 函数式编程方法 }
    function Filter(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): specialize IVec<T>; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Filter(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): specialize IVec<T>; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Filter(aPredicate: specialize TPredicateRefFunc<T>): specialize IVec<T>; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function Any(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Any(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Any(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function All(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function All(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function All(aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    { 就地操作方法 }
    procedure Retain(aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Retain(aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Retain(aPredicate: specialize TPredicateRefFunc<T>); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    {$ENDIF}

    function Drain(aStart, aCount: SizeUInt): specialize IVec<T>; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function DrainRange(aStart, aEnd: SizeUInt): TDrainIter;

    function SplitOff(aIndex: SizeUInt): specialize IVec<T>;
    procedure Splice(aIndex, aRemoveCount: SizeUInt; const aInsert: array of T);

    { 去重方法 }
    function Dedup: SizeUInt;
    function DedupBy(aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;

    { 便利方法 }
    function ToArray: specialize TGenericArray<T>; override;
    function Clone: TCollection; override;
    function First: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function Last: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    { 高性能无检查方法 }
    procedure PushUnchecked(const aElement: T); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    { Unchecked 算法方法 - 跳过边界检查，追求极致性能 }

    {**
     * FindUnchecked
     * @desc 无检查版本的查找方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * ForEachUnchecked
     * @desc 无检查版本的遍历方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * SortUnchecked
     * @desc 无检查版本的排序方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt); overload;
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    {**
     * ContainsUnchecked
     * @desc 无检查版本的包含检查方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean; overload;
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * ZeroUnchecked
     * @desc 无检查版本的清零方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    procedure ZeroUnchecked(aIndex, aCount: SizeUInt);

    {**
     * FindIfUnchecked, FindIfNotUnchecked, FindLastUnchecked, FindLastIfUnchecked, FindLastIfNotUnchecked
     * @desc 无检查版本的查找方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * CountOfUnchecked, CountIfUnchecked
     * @desc 无检查版本的计数方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * FillUnchecked
     * @desc 无检查版本的填充方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    procedure FillUnchecked(aStartIndex, aCount: SizeUInt; const aElement: T);

    {**
     * ReplaceUnchecked, ReplaceIfUnchecked
     * @desc 无检查版本的替换方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    {**
     * IsSortedUnchecked
     * @desc 无检查版本的排序检查方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    {**
     * BinarySearchUnchecked, BinarySearchInsertUnchecked
     * @desc 无检查版本的二分查找方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    function BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    {**
     * ShuffleUnchecked
     * @desc 无检查版本的随机打乱方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt); overload;
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    {**
     * ReverseUnchecked
     * @desc 无检查版本的反转方法，跳过所有边界检查
     * @remark 调用者必须确保参数有效性，否则可能导致程序崩溃
     *}
    procedure ReverseUnchecked(aStartIndex, aCount: SizeUInt);

    property Capacity:                SizeUInt        read GetCapacity     write SetCapacity;
    property GrowStrategy:            IGrowthStrategy read GetGrowStrategy write SetGrowStrategy;
    property Items[aIndex: SizeUInt]: T               read Get             write Put; default;
    property Ptr[aIndex: SizeUInt]:   PElement        read GetPtr;
    property Memory:                  PElement        read GetMemory;

  end;











implementation

function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;
begin
  Result := IsOverlap(aPtr1, aSize1, aPtr2, aSize2);
end;

{ TVec<T> }
constructor TVec.Create;
begin
  Create(VEC_DEFAULT_CAPACITY, GetRtlAllocator(), nil, nil);
end;


constructor TVec.Create(aAllocator: IAllocator; aData: Pointer);
begin
  Create(VEC_DEFAULT_CAPACITY, aAllocator, nil, aData);
end;

constructor TVec.Create(aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(VEC_DEFAULT_CAPACITY, aAllocator, aGrowStrategy, nil);
end;

constructor TVec.Create(aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy;
  aData: Pointer);
begin
  Create(VEC_DEFAULT_CAPACITY, aAllocator, aGrowStrategy, aData);
end;

constructor TVec.Create(aCapacity: SizeUInt);
begin
  Create(aCapacity, GetRtlAllocator(), nil, nil);
end;

constructor TVec.Create(aCapacity: SizeUInt; aAllocator: IAllocator);
begin
  Create(aCapacity, aAllocator, nil, nil);
end;

constructor TVec.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aCapacity, aAllocator, aGrowStrategy, nil);
end;

constructor TVec.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  FGrowStrategy := aGrowStrategy;
  FBuf   := TVecBuf.Create(aCapacity, aAllocator, aData);
  FCount := 0;
end;

constructor TVec.Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aAllocator, aGrowStrategy, nil);
end;

constructor TVec.Create(const aSrc: TCollection; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc);
end;

constructor TVec.Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aCount, aAllocator, aGrowStrategy, nil);
end;

constructor TVec.Create(aSrc: Pointer; aCount: SizeUInt; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc, aCount);
end;

constructor TVec.Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy);
begin
  Create(aSrc, aAllocator, aGrowStrategy, nil);
end;

constructor TVec.Create(const aSrc: array of T; aAllocator: IAllocator; aGrowStrategy: IGrowthStrategy; aData: Pointer);
begin
  Create(0, aAllocator, aGrowStrategy, aData);
  LoadFrom(aSrc);
end;

destructor TVec.Destroy;
begin
  // 接口化统一：策略仅为接口持有，依赖引用计数自动回收
  FGrowStrategy := nil;
  FPrevNonAlignedStrategy := nil;
  FBuf.Free;
  inherited Destroy;
end;

{ 迭代器回�?}

function TVec.DoIterGetCurrent(aIter: PPtrIter): Pointer;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := FBuf.GetPtrUnchecked(SizeUInt(aIter^.Data));
  {$POP}
end;

function TVec.DoIterMoveNext(aIter: PPtrIter): Boolean;
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

{ 内部辅助方法 }

function TVec.GetDefaultGrowStrategyI: IGrowthStrategy;
begin
  // 默认采用因子增长 1.5x（与 Java ArrayList/Rust 常见实践一致）
  // 如需 2 的幂对齐，请显式设置策略或在 VecDeque 使用按幂归一化策略
  Result := FactorGrow(1.5);
end;

function TVec.IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean;
begin
  Result := MemIsOverlap(GetMemory, GetCapacity * GetElementSize,
                         aSrc, aCount * GetElementSize);
end;

function TVec.CalcGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if FGrowStrategy = nil then
    FGrowStrategy := GetDefaultGrowStrategyI;
  Result := FGrowStrategy.GetGrowSize(aCurrentSize, aRequiredSize);
end;

{ 基类虚方法实�?- 直接委托给TArray }

procedure TVec.DoFill(const aElement: T);
begin
  Fill(0, FCount, aElement);
end;

procedure TVec.DoZero;
begin
  Zero(0, FCount);
end;

procedure TVec.DoReverse;
begin
  Reverse(0, FCount);
end;

{ ICollection - 直接委托给TArray }

function TVec.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

function TVec.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TVec.Count: SizeUInt;
begin
  Result := FCount;
end;

procedure TVec.Clear;
begin
  Resize(0);
end;

procedure TVec.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aCount > FCount then
    raise EOutOfRange.Create('TVec.SerializeToArrayBuffer: aCount out of bounds');

  FBuf.SerializeToArrayBuffer(aDst, aCount);
end;

procedure TVec.LoadFromUnchecked(const aSrc: Pointer; aCount: SizeUInt);
begin
  FBuf.LoadFromUnchecked(aSrc, aCount);
  FCount := aCount;
end;

procedure TVec.AppendUnchecked(const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  Reserve(aCount);
  OverwriteUnchecked(FCount, aSrc, aCount);
  Inc(FCount, aCount);
end;

procedure TVec.AppendToUnchecked(const aDst: TCollection);
begin
  if FCount = 0 then
    exit;

  aDst.AppendUnchecked(GetMemory, FCount);
end;

{ IGenericCollection - 直接委托给TArray }

procedure TVec.SaveToUnchecked(aDst: TCollection);
begin
  if FCount = 0 then
    aDst.Clear
  else
    aDst.LoadFromUnchecked(GetMemory, FCount);
end;

{ IArray - 直接委托给TArray }

function TVec.GetMemory: PElement;
begin
  Result := FBuf.GetMemory;
end;

function TVec.Get(aIndex: SizeUInt): T;
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Get: aIndex out of bounds');

  Result := GetUnchecked(aIndex);
end;

function TVec.GetUnchecked(aIndex: SizeUInt): T;
begin
  Result := FBuf.GetUnchecked(aIndex);
end;

procedure TVec.Put(aIndex: SizeUInt; const aValue: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Put: aIndex out of bounds');

  PutUnchecked(aIndex, aValue);
end;

procedure TVec.PutUnchecked(aIndex: SizeUInt; const aValue: T);
begin
  FBuf.PutUnchecked(aIndex, aValue);
end;

function TVec.GetPtr(aIndex: SizeUInt): PElement;
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.GetPtr: aIndex out of bounds');

  Result := GetPtrUnchecked(aIndex);
end;

function TVec.GetPtrUnchecked(aIndex: SizeUInt): PElement;
begin
  Result := FBuf.GetPtrUnchecked(aIndex);
end;

function TVec.SliceView(aIndex, aCount: SizeUInt): TSpan;
var
  LEnd: SizeUInt;
  LElemSize: SizeUInt;
  LPtr: Pointer;
begin
  // 边界裁剪：允许 aCount=0，返回空 span；若起点超界，返回空 span
  if (aCount = 0) or (aIndex >= FCount) then
    Exit(TSpan.FromPointer(nil, 0, SizeOf(T)));

  // 计算实际可视图长度，避免溢出
  LEnd := aIndex + aCount;
  if LEnd > FCount then
    LEnd := FCount;

  LElemSize := GetElementSize;
  LPtr := FBuf.GetPtrUnchecked(aIndex);
  Result := TSpan.FromPointer(LPtr, LEnd - aIndex, LElemSize);
end;

procedure TVec.Resize(aNewSize: SizeUInt);
begin
  if aNewSize = FCount then
    exit;

  if (aNewSize < FCount) and (GetIsManagedType) then
    GetElementManager.FinalizeManagedElementsUnchecked(FBuf.GetPtrUnchecked(aNewSize), FCount - aNewSize)
  else if aNewSize > FCount then
  begin
    Reserve(aNewSize - FCount);
    // 初始化新增范围，确保托管类型被正确初始化，非托管类型置零
    GetElementManager.InitializeElementsUnchecked(FBuf.GetPtrUnchecked(FCount), aNewSize - FCount);
  end;

  FCount := aNewSize;
end;

procedure TVec.Ensure(aCount: SizeUInt);
begin
  if FCount < aCount then
    Resize(aCount);
end;

function TVec.GetCapacity: SizeUInt;
begin
  Result := FBuf.GetCount;
end;

procedure TVec.SetCapacity(aCapacity: SizeUInt);
begin
  FBuf.Resize(aCapacity);

  if (aCapacity < FCount) then
    FCount := aCapacity;
end;


  { 接口化统一：直接以接口持有，不再使用弱包装视图 }
function TVec.GetGrowStrategy: IGrowthStrategy;
begin
  if FGrowStrategy = nil then
    FGrowStrategy := GetDefaultGrowStrategyI;
  Result := FGrowStrategy;
end;

procedure TVec.SetGrowStrategy(aGrowStrategy: IGrowthStrategy);
begin
  if aGrowStrategy = nil then
    FGrowStrategy := GetDefaultGrowStrategyI
  else
    FGrowStrategy := aGrowStrategy;
end;



function TVec.TryReserve(aAdditional: SizeUInt): Boolean;
var
  LCapacity: SizeUInt;
  LTarget:   SizeUInt;
  LExpected:   SizeUInt;
begin
  if aAdditional = 0 then
    exit(True);

  LCapacity := GetCapacity;

  if IsAddOverflow(FCount, aAdditional) then
    exit(False);  // TryReserve 不应该抛出异常，返回 False

  LTarget := FCount + aAdditional;
  Result  := (LCapacity >= LTarget);

  if not Result then
  begin
    LExpected := CalcGrowSize(LCapacity, LTarget);

    if LExpected <= LCapacity then
      exit(False);  // 增长计算错误，返�?False 而不是抛出异�?

    SetCapacity(LExpected);
    Result := True;
  end;
end;

procedure TVec.Reserve(aAdditional: SizeUInt);
begin
  if not TryReserve(aAdditional) then
    raise ECore.Create('TVec.Reserve: failed to reserve');
end;

function TVec.TryReserveExact(aAdditional: SizeUInt): Boolean;
var
  LExpect: SizeUInt;
begin
  if aAdditional = 0 then
    exit(True);

  if IsAddOverflow(FCount, aAdditional) then
    exit(False);  // TryReserveExact 不应该抛出异常，返回 False

  LExpect := FCount + aAdditional;
  Result  := (GetCapacity >= LExpect);

  if not Result then
  begin
    try
      SetCapacity(LExpect);
      Result := True;
    except
      Result := False;  // Try 方法不应该抛出异常，捕获并返回 False
    end;
  end;
end;

procedure TVec.ReserveExact(aAdditional: SizeUInt);
begin
  if not TryReserveExact(aAdditional) then
    raise ECore.Create('TVec.ReserveExact: failed to reserve exact additional capacity');
end;

procedure TVec.EnsureCapacity(aCapacity: SizeUInt);
var
  LCap: SizeUInt;
begin
  LCap := GetCapacity;
  if aCapacity > LCap then
    Reserve(aCapacity - LCap);
end;

procedure TVec.Shrink;
begin
  SetCapacity(FCount);
end;

procedure TVec.ShrinkTo(aCapacity: SizeUInt);
begin
  if aCapacity >= GetCapacity then
    exit;

  if aCapacity < FCount then
    raise EInvalidArgument.Create('TVec.ShrinkTo: failed to shrink to (less than count)');

  SetCapacity(aCapacity);
end;

procedure TVec.EnableAlignedGrowth(aAlignElements: SizeUInt);
begin
  // 启用对齐增长：TAlignedWrapperStrategy 直接接受 IGrowthStrategy
  // aAlignElements 需为 2 的幂；若非法，回退到默认 64
  if aAlignElements = 0 then
    aAlignElements := TAlignedWrapperStrategy.DEFAULT_ALIGN_SIZE;
  if (aAlignElements and (aAlignElements - 1)) <> 0 then
    aAlignElements := TAlignedWrapperStrategy.DEFAULT_ALIGN_SIZE;

  // 若已启用，则先禁用以恢复原策略
  if IsAlignedGrowthEnabled then
    DisableAlignedGrowth;

  // 保存原策略以便恢复
  FPrevNonAlignedStrategy := GetGrowStrategy;

  // 直接创建 TAlignedWrapperStrategy，它实现 IGrowthStrategy
  SetGrowStrategy(TAlignedWrapperStrategy.Create(FPrevNonAlignedStrategy, aAlignElements));
end;

procedure TVec.DisableAlignedGrowth;
begin
  // 恢复先前的非对齐策略
  if FPrevNonAlignedStrategy <> nil then
    SetGrowStrategy(FPrevNonAlignedStrategy)
  else
    SetGrowStrategy(nil);

  FPrevNonAlignedStrategy := nil;
end;

function TVec.IsAlignedGrowthEnabled: Boolean;
begin
  Result := FPrevNonAlignedStrategy <> nil;
end;


procedure TVec.Truncate(aCount: SizeUInt);
begin
  if FCount > aCount then
    Resize(aCount);
end;

procedure TVec.ResizeExact(aNewSize: SizeUInt);
var
  LCap: SizeUInt;
begin
  if aNewSize = FCount then
    exit;

  LCap := GetCapacity;

  // 如果需要扩容，先扩容
  if aNewSize > LCap then
    SetCapacity(aNewSize);

  // 如果需要缩容（减少元素数），处理托管类型
  if (aNewSize < FCount) and GetIsManagedType then
    GetElementManager.FinalizeManagedElementsUnchecked(FBuf.GetPtrUnchecked(aNewSize), FCount - aNewSize);

  // 如果需要扩容（增加元素数），初始化新元素
  if aNewSize > FCount then
    GetElementManager.InitializeElementsUnchecked(FBuf.GetPtrUnchecked(FCount), aNewSize - FCount);

  // 只改变 FCount，不改变容量（除非之前需要扩容）
  FCount := aNewSize;
end;

procedure TVec.Push(const aElement: T);
begin
  Push(@aElement, 1);
end;


procedure TVec.ShrinkToFit;
var
  UsedElems, CapElems: SizeUInt;
  UsedBytes, CapBytes: SizeUInt;
  RatioThresholdBytes, MinKeepBytes: SizeUInt;
  ElemSize: SizeUInt;
  ThresholdBytes: SizeUInt;
begin
  // 滞回策略（按字节计）：阈值 = max(2×UsedBytes, 64 KiB)
  // 当 CapacityBytes > 阈值时，收缩到 Count
  UsedElems := FCount;
  CapElems  := GetCapacity;

  if CapElems <= UsedElems then
    exit; // 容量不超过使用量，无需收缩

  ElemSize := GetElementSize;
  UsedBytes := UsedElems * ElemSize;
  CapBytes  := CapElems * ElemSize;

  // 阈值 = max(2×UsedBytes, 64 KiB)
  RatioThresholdBytes := UsedBytes shl 1;  // 2×UsedBytes
  MinKeepBytes := 64 * 1024;               // 64 KiB

  // 如果容量字节数小于 64 KiB，主要使用 2×UsedBytes 作为阈值
  // 否则使用 max(2×UsedBytes, 64 KiB)
  if CapBytes < MinKeepBytes then
    ThresholdBytes := RatioThresholdBytes
  else
    ThresholdBytes := Max(RatioThresholdBytes, MinKeepBytes);

  if CapBytes > ThresholdBytes then
    SetCapacity(FCount);
end;

procedure TVec.FreeBuffer;
begin
  SetCapacity(0);
end;

procedure TVec.Push(const aSrc: Pointer; aCount: SizeUInt);
var
  LOldCount: SizeUInt;
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Push: source is nil');

  if IsAddOverflow(FCount, aCount) then
    raise EOverflow.Create('TVec.Push: failed to push (overflow)');

  LOldCount := FCount;
  Resize(FCount + aCount);
  Overwrite(LOldCount, aSrc, aCount);
end;

procedure TVec.Push(const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;

  Push(@aSrc[0], LLen);
end;

procedure TVec.Push(const aSrc: TCollection; aCount: SizeUInt);
var
  LOldCount: SizeUInt;
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Push: source collection is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TVec.Push: source is not compatible');

  if aCount > aSrc.GetCount then
    raise EInvalidArgument.Create('TVec.Push: aCount exceeds source collection count');

  LOldCount := FCount;
  Resize(LOldCount + aCount);
  aSrc.SerializeToArrayBuffer(FBuf.GetPtrUnchecked(LOldCount), aCount);
end;

function TVec.TryPop(var aDst: T): Boolean;
begin
  Result := TryPop(@aDst, 1);
end;

function TVec.TryPop(aDst: Pointer; aCount: SizeUInt): Boolean;
var
  LIndex: SizeUInt;
begin
  // Try 方法完整参数检查：确保永不抛异常
  Result := (aCount > 0) and (FCount >= aCount) and (aDst <> nil);

  if Result then
  begin
    LIndex := FCount - aCount;
    ReadUnchecked(LIndex, aDst, aCount);
    Resize(LIndex);
  end;
end;

function TVec.TryPop(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;
var
  LLen: SizeUInt;
begin
  if aCount = 0 then
    exit(True);  // aCount = 0 是成功的无操作

  LLen := Length(aDst);

  if LLen <> aCount then
    SetLength(aDst, aCount);

  Result := TryPop(@aDst[0], aCount);
end;



function TVec.Pop: T;
begin
  if not TryPop(@Result, 1) then
    raise EEmptyCollection.Create('TVec.Pop: failed to pop (empty)');
end;

function TVec.TryPeek(out aElement: T): Boolean;
var
  LP: Pointer;
begin
  LP     := PeekRange(1);
  Result := (LP <> nil);
  if Result then
    aElement := PElement(LP)^;
end;

function TVec.Peek: T;
begin
  if not TryPeekCopy(@Result, 1) then
    raise EEmptyCollection.Create('TVec.Peek: failed to peek (empty)');
end;

function TVec.TryPeekCopy(aDst: Pointer; aCount: SizeUInt): Boolean;
var
  LP: Pointer;
begin
  // Try 方法完整参数检查：确保永不抛异常
  if aCount = 0 then
    exit(True);

  if (aDst = nil) or (aCount > FCount) then
    exit(False);

  LP := PeekRange(aCount);
  // PeekRange 已经检查了边界，这里 LP 不会为 nil
  GetElementManager.CopyElementsNonOverlapUnchecked(LP, aDst, aCount);
  Result := True;
end;

function TVec.TryPeek(var aDst: specialize TGenericArray<T>; aCount: SizeUInt): Boolean;
var
  LLen: SizeUInt;
begin
  if aCount = 0 then
    exit(True);  // aCount = 0 是成功的无操作

  if aCount > FCount then
    exit(False);

  LLen := Length(aDst);

  if LLen <> aCount then
    SetLength(aDst, aCount);

  Result := TryPeekCopy(@aDst[0], aCount);
end;

function TVec.PeekRange(aCount: SizeUInt): PElement;
begin
  if (aCount = 0) or (aCount > FCount) then
    exit(nil);

  Result := GetPtrUnchecked(FCount - aCount);
end;


procedure TVec.Insert(aIndex: SizeUInt; const aElement: T);
begin
  Insert(aIndex, @aElement, 1);
end;

procedure TVec.InsertUnchecked(aIndex: SizeUInt; const aElement: T);
begin
  InsertUnchecked(aIndex, @aElement, 1);
end;

procedure TVec.Insert(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Insert: source is nil');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Insert: index out of bounds');

  InsertUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.InsertUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
var
  LOldCount: SizeUInt;
begin
  LOldCount := FCount;
  Resize(FCount + aCount);

  if (aIndex < LOldCount) then
    Copy(aIndex, aIndex + aCount, LOldCount - aIndex);

  Overwrite(aIndex, aSrc, aCount);
end;

procedure TVec.Insert(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;

  Insert(aIndex, @aSrc[0], LLen);
end;

procedure TVec.Insert(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Insert: source is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TVec.Insert: source is not compatible');

  if aCount > aSrc.GetCount then
    raise EInvalidArgument.Create('TVec.Insert: aCount exceeds source collection count');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Insert: index out of bounds');

  InsertUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.InsertUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
var
  LOldCount: SizeUInt;
begin
  LOldCount := FCount;
  Resize(FCount + aCount);

  if aIndex < LOldCount then
    Copy(aIndex, aIndex + aCount, LOldCount - aIndex);

  aSrc.SerializeToArrayBuffer(GetPtrUnchecked(aIndex), aCount);
end;

{ IVec - Write 系列（需要动态扩容的特殊逻辑）}

procedure TVec.Write(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if (aCount = 0) then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Write: source is nil');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Write: index out of bounds');

  WriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.WriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
var
  LEnd:      SizeUInt;
  LCapacity: SizeUInt;
begin
  LEnd      := aIndex + aCount;
  LCapacity := GetCapacity;

  if LCapacity < LEnd then
    Reserve(LEnd - LCapacity);

  OverwriteUnchecked(aIndex, aSrc, aCount);

  if LEnd > FCount then
    FCount := LEnd;
end;

procedure TVec.Write(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;

  WriteUnchecked(aIndex, @aSrc[0], LLen);
end;

  { Unchecked: 调用方必须确保前置条件：
    - aSrc 非空（Length(aSrc) > 0），否则引用 @aSrc[0] 未定义
    - 写入范围 [aIndex, aIndex + Length(aSrc) - 1] 在有效范围内，或调用方先行 Reserve/SetCapacity
    - 本方法不做任何参数/边界检查，违反前置条件将导致未定义行为 }

procedure TVec.WriteUnchecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  WriteUnchecked(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TVec.Write(aIndex: SizeUInt; const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Write: source is nil');

  Write(aIndex, aSrc, aSrc.GetCount);
end;

procedure TVec.Write(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Write: source is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TVec.Write: source is not compatible');

  if aCount > aSrc.GetCount then
    raise EInvalidArgument.Create('TVec.Write: aCount exceeds source collection count');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Write: index out of bounds');

  WriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.WriteUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
var
  LEnd:      SizeUInt;
  LCapacity: SizeUInt;
begin
  LEnd      := aIndex + aCount;
  LCapacity := GetCapacity;

  if LCapacity < LEnd then
    Reserve(LEnd - LCapacity);

  aSrc.SerializeToArrayBuffer(GetPtrUnchecked(aIndex), aCount);

  if LEnd > FCount then
    FCount := LEnd;
end;

procedure TVec.WriteExact(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.WriteExact: source is nil');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.WriteExact: index out of bounds');

  WriteExactUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.WriteExactUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
var
  LEnd:      SizeUInt;
  LCapacity: SizeUInt;
begin
  LEnd      := aIndex + aCount;
  LCapacity := GetCapacity;

  if LCapacity < LEnd then
    SetCapacity(LEnd);

  OverwriteUnchecked(aIndex, aSrc, aCount);

  if LEnd > FCount then
    FCount := LEnd;
end;

procedure TVec.WriteExact(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;

  WriteExact(aIndex, @aSrc[0], LLen);
end;

  { Unchecked: 调用方必须确保前置条件：
    - aSrc 非空（Length(aSrc) > 0），否则引用 @aSrc[0] 未定义
    - 写入范围 [aIndex, aIndex + Length(aSrc) - 1] 在 [0..Capacity) 内；WriteExactUnchecked 不会自动扩容
    - 本方法不做任何参数/边界检查，违反前置条件将导致未定义行为 }

procedure TVec.WriteExactUnchecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  WriteExactUnchecked(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TVec.WriteExact(aIndex: SizeUInt; const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.WriteExact: source is nil');

  WriteExact(aIndex, aSrc, aSrc.GetCount);
end;

procedure TVec.WriteExact(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.WriteExact: source is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TVec.WriteExact: source is not compatible');

  if aCount > aSrc.GetCount then
    raise EInvalidArgument.Create('TVec.WriteExact: aCount exceeds source collection count');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.WriteExact: index out of bounds');

  WriteExactUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.WriteExactUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
var
  LEnd:      SizeUInt;
  LCapacity: SizeUInt;
begin
  LEnd      := aIndex + aCount;
  LCapacity := GetCapacity;

  if LCapacity < LEnd then
    SetCapacity(LEnd);

  aSrc.SerializeToArrayBuffer(GetPtrUnchecked(aIndex), aCount);

  if LEnd > FCount then
    FCount := LEnd;
end;

procedure TVec.Delete(aIndex, aCount: SizeUInt);
var
  LRight:      SizeUInt;
  LRightCount: SizeUInt;
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Delete: index out of bounds');

  if aCount > FCount - aIndex then
    raise EOutOfRange.Create('TVec.Delete: count out of bounds');

  LRight      := aIndex + aCount;
  LRightCount := FCount - LRight;

  if LRightCount > 0 then
    Copy(LRight, aIndex, LRightCount);

  Resize(FCount - aCount);
end;

procedure TVec.Delete(aIndex: SizeUInt);
begin
  Delete(aIndex, 1);
end;

procedure TVec.DeleteSwap(aIndex, aCount: SizeUInt);
var
  LRight:      SizeUInt;
  LRightCount: SizeUInt;
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.DeleteSwap: index out of bounds');

  if aCount > FCount - aIndex then
    raise EOutOfRange.Create('TVec.DeleteSwap: count out of bounds');

  LRight      := aIndex + aCount;
  LRightCount := FCount - LRight;

  if LRightCount > 0 then
  begin
    if LRightCount > aCount then
      Copy(FCount - aCount, aIndex, aCount)
    else
      Copy(LRight, aIndex, LRightCount);
  end;

  Resize(FCount - aCount);
end;

procedure TVec.DeleteSwap(aIndex: SizeUInt);
begin
  DeleteSwap(aIndex, 1);
end;

procedure TVec.RemoveCopyAt(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EInvalidArgument.Create('TVec.RemoveCopyAt: destination is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.RemoveCopyAt: index out of bounds');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TVec.RemoveCopyAt: count out of bounds');

  ReadUnchecked(aIndex, aDst, aCount);
  Delete(aIndex, aCount);
end;

procedure TVec.RemoveCopyAt(aIndex: SizeUInt; aDst: Pointer);
begin
  RemoveCopyAt(aIndex, aDst, 1);
end;

procedure TVec.RemoveArrayAt(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt);
var
  LLen: SizeInt;
begin
  if aCount = 0 then
    exit;

  LLen := Length(aElements);

  if LLen <> aCount then
    SetLength(aElements, aCount);

  RemoveCopyAt(aIndex, @aElements[0], aCount);
end;

procedure TVec.RemoveAt(aIndex: SizeUInt; var aElement: T);
begin
  RemoveCopyAt(aIndex, @aElement, 1);
end;

function TVec.RemoveAt(aIndex: SizeUInt): T;
begin
  RemoveCopyAt(aIndex, @Result);
end;

function TVec.TryRemoveAt(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex >= FCount then
    exit(False);

  RemoveCopyAt(aIndex, @aElement, 1);
  Result := True;
end;

procedure TVec.SwapRemoveCopyAt(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EInvalidArgument.Create('TVec.SwapRemoveCopyAt: destination is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.SwapRemoveCopyAt: index out of bounds');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TVec.SwapRemoveCopyAt: count out of bounds');

  ReadUnchecked(aIndex, aDst, aCount);
  DeleteSwap(aIndex, aCount);
end;

procedure TVec.SwapRemoveCopyAt(aIndex: SizeUInt; aDst: Pointer);
begin
  SwapRemoveCopyAt(aIndex, aDst, 1);
end;

procedure TVec.SwapRemoveArrayAt(aIndex: SizeUInt; var aElements: specialize TGenericArray<T>; aCount: SizeUInt);
var
  LLen: SizeInt;
begin
  if aCount = 0 then
    exit;

  LLen := Length(aElements);

  if LLen <> aCount then
    SetLength(aElements, aCount);

  SwapRemoveCopyAt(aIndex, @aElements[0], aCount);
end;

procedure TVec.SwapRemoveAt(aIndex: SizeUInt; var aElement: T);
begin
  SwapRemoveCopyAt(aIndex, @aElement, 1);
end;

function TVec.SwapRemoveAt(aIndex: SizeUInt): T;
begin
  SwapRemoveCopyAt(aIndex, @Result);
end;

function TVec.TrySwapRemoveAt(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex >= FCount then
    exit(False);

  SwapRemoveCopyAt(aIndex, @aElement, 1);
  Result := True;
end;

{ 函数式编程方法实现 }

function TVec.Filter(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  i: SizeUInt;
begin
  // 预分配最大可能容量，避免重分配
  LResult := specialize TVec<T>.Create(FCount, GetAllocator, nil);
  try
    // 复制增长策略
    LResult.SetGrowStrategy(GetGrowStrategy);

    for i := 0 to FCount - 1 do
      if aPredicate(GetUnchecked(i), aData) then  // 直接使用引用，避免拷贝
        LResult.PushUnchecked(GetUnchecked(i));   // 无边界检查版本

    // 收缩到实际大小
    LResult.ShrinkToFit;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

function TVec.Filter(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  i: SizeUInt;
begin
  // 预分配最大可能容量，避免重分配
  LResult := specialize TVec<T>.Create(FCount, GetAllocator, nil);
  try
    // 复制增长策略
    LResult.SetGrowStrategy(GetGrowStrategy);

    for i := 0 to FCount - 1 do
      if aPredicate(GetUnchecked(i), aData) then  // 直接使用引用，避免拷贝
        LResult.PushUnchecked(GetUnchecked(i));   // 无边界检查版本

    // 收缩到实际大小
    LResult.ShrinkToFit;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Filter(aPredicate: specialize TPredicateRefFunc<T>): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  i: SizeUInt;
begin
  // 预分配最大可能容量，避免重分配
  LResult := specialize TVec<T>.Create(FCount, GetAllocator, nil);
  try
    // 复制增长策略
    LResult.SetGrowStrategy(GetGrowStrategy);

    for i := 0 to FCount - 1 do
      if aPredicate(GetUnchecked(i)) then         // 直接使用引用，避免拷贝
        LResult.PushUnchecked(GetUnchecked(i));   // 无边界检查版本

    // 收缩到实际大小
    LResult.ShrinkToFit;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;
{$ENDIF}

function TVec.Any(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i), aData) then
      Exit(True);
  Result := False;
end;

function TVec.Any(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i), aData) then
      Exit(True);
  Result := False;
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Any(aPredicate: specialize TPredicateRefFunc<T>): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i)) then
      Exit(True);
  Result := False;
end;
{$ENDIF}

function TVec.All(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnchecked(i), aData) then
      Exit(False);
  Result := True;
end;

function TVec.All(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnchecked(i), aData) then
      Exit(False);
  Result := True;
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.All(aPredicate: specialize TPredicateRefFunc<T>): Boolean;
var
  i: SizeUInt;
begin
  for i := 0 to FCount - 1 do
    if not aPredicate(GetUnchecked(i)) then
      Exit(False);
  Result := True;
end;
{$ENDIF}

{ 就地操作方法实现 }

procedure TVec.Retain(aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
var
  i, j: SizeUInt;
begin
  if FCount = 0 then Exit;

  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i), aData) then
    begin
      if i <> j then
        PutUnchecked(j, GetUnchecked(i));
      Inc(j);
    end;
  // 调整大小，自动处理托管类型清理
  Resize(j);
end;

procedure TVec.Retain(aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
var
  i, j: SizeUInt;
begin
  if FCount = 0 then Exit;

  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i), aData) then
    begin
      if i <> j then
        PutUnchecked(j, GetUnchecked(i));
      Inc(j);
    end;
  // 调整大小，自动处理托管类型清理
  Resize(j);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Retain(aPredicate: specialize TPredicateRefFunc<T>);
var
  i, j: SizeUInt;
begin
  if FCount = 0 then Exit;

  j := 0;
  for i := 0 to FCount - 1 do
    if aPredicate(GetUnchecked(i)) then
    begin
      if i <> j then
        PutUnchecked(j, GetUnchecked(i));
      Inc(j);
    end;
  // 调整大小，自动处理托管类型清理
  Resize(j);
end;
{$ENDIF}

function TVec.Drain(aStart, aCount: SizeUInt): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  i: SizeUInt;
begin
  // 边界检查
  if aStart >= FCount then
    raise EOutOfRange.Create('TVec.Drain: start index out of range');
  if aStart + aCount > FCount then
    aCount := FCount - aStart;

  // 创建结果向量并复制要删除的元素
  LResult := specialize TVec<T>.Create(aCount, GetAllocator, nil);
  try
    // 复制增长策略
    LResult.SetGrowStrategy(GetGrowStrategy);

    for i := 0 to aCount - 1 do
      LResult.PushUnchecked(GetUnchecked(aStart + i));

    // 移动后续元素（如果有的话）
    if aStart + aCount < FCount then
    begin
      for i := aStart + aCount to FCount - 1 do
        PutUnchecked(i - aCount, GetUnchecked(i));
    end;

    // 调整大小
    Resize(FCount - aCount);
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

function TVec.DrainRange(aStart, aEnd: SizeUInt): TDrainIter;
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

{ TVec.TDrainIter }

procedure TVec.TDrainIter.Init(const aDrained: IVecT);
begin
  FDrained := aDrained;
  FIndex := 0;
  FCurrent := Default(T);
end;

function TVec.TDrainIter.MoveNext: Boolean;
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

function TVec.TDrainIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

function TVec.SplitOff(aIndex: SizeUInt): specialize IVec<T>;
var
  LResult: specialize TVec<T>;
  LSplitCount: SizeUInt;
  i: SizeUInt;
begin
  // 边界检查
  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.SplitOff: index out of range');

  // 计算分割出去的元素数量
  LSplitCount := FCount - aIndex;

  // 创建结果向量
  LResult := specialize TVec<T>.Create(LSplitCount, GetAllocator, nil);
  try
    // 复制增长策略
    LResult.SetGrowStrategy(GetGrowStrategy);

    // 复制 [aIndex, Count) 范围的元素到新向量
    // 注意：使用 LSplitCount > 0 检查避免无符号整数下溢
    if LSplitCount > 0 then
      for i := 0 to LSplitCount - 1 do
        LResult.PushUnchecked(GetUnchecked(aIndex + i));

    // 截断原向量到 [0, aIndex)
    Truncate(aIndex);

    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

procedure TVec.Splice(aIndex, aRemoveCount: SizeUInt; const aInsert: array of T);
var
  LInsertLen: SizeInt;
begin
  // 边界检查
  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Splice: index out of range');

  // 调整 aRemoveCount，确保不超出边界
  if aRemoveCount > FCount - aIndex then
    aRemoveCount := FCount - aIndex;

  LInsertLen := Length(aInsert);

  // 先删除元素
  if aRemoveCount > 0 then
    Delete(aIndex, aRemoveCount);

  // 再插入新元素
  if LInsertLen > 0 then
    Insert(aIndex, aInsert);
end;

{ 去重方法实现 }

function TVec.Dedup: SizeUInt;
var
  i, j: SizeUInt;
begin
  // 空向量或单元素向量无需去重
  if FCount < 2 then
    Exit(0);

  // 使用就地压缩算法，保留第一个出现的元素
  j := 1; // 写入位置，从第二个元素开始
  for i := 1 to FCount - 1 do
  begin
    // 使用内存比较判断是否相等
    if not CompareMem(GetPtrUnchecked(i), GetPtrUnchecked(j - 1), GetElementSize) then
    begin
      // 元素不同，保留
      if i <> j then
        PutUnchecked(j, GetUnchecked(i));
      Inc(j);
    end;
  end;

  // 计算被移除的元素数量
  Result := FCount - j;

  // 调整大小，自动处理托管类型清理
  if Result > 0 then
    Resize(j);
end;

function TVec.DedupBy(aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
var
  i, j: SizeUInt;
begin
  // 空向量或单元素向量无需去重
  if FCount < 2 then
    Exit(0);

  // 使用就地压缩算法，保留第一个出现的元素
  j := 1; // 写入位置，从第二个元素开始
  for i := 1 to FCount - 1 do
  begin
    // 使用自定义比较函数判断是否相等
    if not aEquals(GetUnchecked(i), GetUnchecked(j - 1), aData) then
    begin
      // 元素不同，保留
      if i <> j then
        PutUnchecked(j, GetUnchecked(i));
      Inc(j);
    end;
  end;

  // 计算被移除的元素数量
  Result := FCount - j;

  // 调整大小，自动处理托管类型清理
  if Result > 0 then
    Resize(j);
end;

{ 便利方法实现 }

function TVec.ToArray: specialize TGenericArray<T>;
var
  i: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);
  // 空向量直接返回，避免无效索引访问
  if FCount > 0 then
    for i := 0 to FCount - 1 do
      Result[i] := GetUnchecked(i);
end;

function TVec.Clone: TCollection;
var
  LResult: specialize TVec<T>;
begin
  LResult := specialize TVec<T>.Create(FCount, GetAllocator, nil);
  try
    // 复制增长策略，保持完整配置
    LResult.SetGrowStrategy(GetGrowStrategy);

    if FCount > 0 then
      LResult.OverwriteUnchecked(0, GetMemory, FCount);
    LResult.FCount := FCount;
    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

function TVec.First: T;
begin
  if FCount = 0 then
    raise EEmptyCollection.Create('TVec: collection is empty');
  Result := GetUnchecked(0);
end;

function TVec.Last: T;
begin
  if FCount = 0 then
    raise EEmptyCollection.Create('TVec: collection is empty');
  Result := GetUnchecked(FCount - 1);
end;

{ 高性能无检查方法实现 }

procedure TVec.PushUnchecked(const aElement: T);
begin
  PutUnchecked(FCount, aElement);
  Inc(FCount);
end;

procedure TVec.Overwrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Overwrite: source is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Overwrite: index out of bounds');

  if aCount > FCount - aIndex then
    raise EOutOfRange.Create('TVec.Overwrite: count out of bounds');

  OverwriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  FBuf.OverwriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.Overwrite(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);

  if LLen = 0 then
    exit;
  { Unchecked: 调用方必须确保前置条件：
    - aSrc 非空（Length(aSrc) > 0），否则引用 @aSrc[0] 未定义
    - 覆写范围 [aIndex, aIndex + Length(aSrc) - 1] 在有效范围内
    - 本方法不做任何参数/边界检查，违反前置条件将导致未定义行为 }


  Overwrite(aIndex, @aSrc[0], LLen);
end;

procedure TVec.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  OverwriteUnchecked(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TVec.Overwrite(aIndex: SizeUInt; const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Overwrite: source is nil');

  Overwrite(aIndex, aSrc, aSrc.GetCount);
end;

procedure TVec.Overwrite(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrc = nil then
    raise EInvalidArgument.Create('TVec.Overwrite: source is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TVec.Overwrite: source is not compatible');

  if aIndex > FCount then
    raise EOutOfRange.Create('TVec.Overwrite: index out of bounds');

  if aCount > FCount - aIndex then
    raise EOutOfRange.Create('TVec.Overwrite: count out of bounds');

  OverwriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TVec.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  aSrc.SerializeToArrayBuffer(GetPtrUnchecked(aIndex), aCount);
end;

procedure TVec.Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EInvalidArgument.Create('TVec.Read: aDst is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Read: index out of bounds');

  if aCount > FCount - aIndex then
    raise EOutOfRange.Create('TVec.Read: count out of bounds');

  ReadUnchecked(aIndex, aDst, aCount);
end;

procedure TVec.ReadUnchecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  FBuf.ReadUnchecked(aIndex, aDst, aCount);
end;

procedure TVec.Read(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
var
  LLen: SizeInt;
begin
  if aCount = 0 then
    exit;

  LLen := Length(aDst);

  if LLen <> aCount then
    SetLength(aDst, aCount);

  Read(aIndex, @aDst[0], aCount);
end;

procedure TVec.ReadUnchecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
begin
  SetLength(aDst, aCount);
  ReadUnchecked(aIndex, @aDst[0], aCount);
end;

procedure TVec.Swap(aIndex1, aIndex2: SizeUInt);
begin
  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise EOutOfRange.Create('TVec.Swap: index out of bounds');

  SwapUnchecked(aIndex1, aIndex2);
end;

procedure TVec.SwapUnchecked(aIndex1, aIndex2: SizeUInt);
begin
  FBuf.SwapUnchecked(aIndex1, aIndex2);
end;

procedure TVec.Swap(aIndex1, aIndex2, aCount: SizeUInt);
begin
  Swap(aIndex1, aIndex2, aCount, DEFAULT_SWAP_BUFFER_SIZE);
end;

procedure TVec.Swap(aIndex1, aIndex2, aCount, aSwapBufferSize: SizeUInt);
begin
  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise EOutOfRange.Create('TVec.Swap: index out of bounds');

  if (aCount > (FCount - aIndex1)) or (aCount > (FCount - aIndex2)) then
    raise EOutOfRange.Create('TVec.Swap: count out of bounds');

  FBuf.Swap(aIndex1, aIndex2, aCount, aSwapBufferSize);
end;

procedure TVec.Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if (aSrcIndex >= FCount) then
    raise EOutOfRange.Create('TVec.Copy: src index out of bounds');

  if (aDstIndex >= FCount) then
    raise EOutOfRange.Create('TVec.Copy: dst index out of bounds');

  if aCount > (FCount - aSrcIndex) then
    raise EOutOfRange.Create('TVec.Copy: count out of bounds');

  if aCount > (FCount - aDstIndex) then
    raise EOutOfRange.Create('TVec.Copy: count out of bounds');

  CopyUnchecked(aSrcIndex, aDstIndex, aCount);
end;

procedure TVec.CopyUnchecked(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  FBuf.CopyUnchecked(aSrcIndex, aDstIndex, aCount);
end;

procedure TVec.Fill(aIndex: SizeUInt; const aValue: T);
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Fill: index out of bounds');

  Fill(aIndex, FCount - aIndex, aValue);
end;

procedure TVec.Fill(aIndex, aCount: SizeUInt; const aValue: T);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Fill: index out of bounds');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TVec.Fill: count out of bounds');

  FBuf.Fill(aIndex, aCount, aValue);
end;

procedure TVec.Zero(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Zero: index out of bounds');

  Zero(aIndex, FCount - aIndex);
end;

procedure TVec.Zero(aIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TVec.Zero: index out of bounds');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TVec.Zero: count out of bounds');

  FBuf.Zero(aIndex, aCount);
end;

function TVec.Find(const aValue: T): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := Find(aValue, 0, FCount);
end;

function TVec.Find(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := Find(aValue, 0, FCount, aEquals, aData);
end;

function TVec.Find(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := Find(aValue, 0, FCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Find(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := Find(aValue, 0, FCount, aEquals);
end;
{$ENDIF}

function TVec.Find(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex);
end;

function TVec.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TVec.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TVec.Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Find: count out of bounds');

  Result := FBuf.Find(aValue, aStartIndex, aCount);
end;

function TVec.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Find: count out of bounds');

  Result := FBuf.Find(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVec.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Find: count out of bounds');

  Result := FBuf.Find(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Find: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Find: count out of bounds');

  Result := FBuf.Find(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

{ FindUnchecked 无检查查找 - 跳过边界检查，追求极致性能 }

function TVec.FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := FBuf.FindUnchecked(aValue, aStartIndex, aCount);
end;

function TVec.FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVec.FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindUnchecked(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindUnchecked(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TVec.FindIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindIf(0, FCount, aPredicate, aData);
end;

function TVec.FindIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindIf(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindIf(0, FCount, aPredicate);
end;
{$ENDIF}

function TVec.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIf: count out of bounds');

  Result := FBuf.FindIf(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIf: count out of bounds');

  Result := FBuf.FindIf(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIf: count out of bounds');

  Result := FBuf.FindIf(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}


procedure TVec.Reverse(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Reverse: index out of bounds');

  Reverse(aStartIndex, FCount - aStartIndex);
end;

procedure TVec.Reverse(aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Reverse: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Reverse: count out of bounds');

  FBuf.Reverse(aStartIndex, aCount);
end;

function TVec.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ForEach: count out of bounds');

  Result := FBuf.ForEach(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ForEach: count out of bounds');

  Result := FBuf.ForEach(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ForEach: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ForEach: count out of bounds');

  Result := FBuf.ForEach(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIf(0, FCount, aPredicate, aData);
end;

function TVec.FindLastIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIf(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIf(0, FCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIf: count out of bounds');

  Result := FBuf.FindLastIf(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIf: count out of bounds');

  Result := FBuf.FindLastIf(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIf: count out of bounds');

  Result := FBuf.FindLastIf(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate, aData);
end;

function TVec.FindLastIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  Result := FindLastIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  Result := FindLastIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  Result := FindLastIfNot(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIfNot: count out of bounds');

  Result := FBuf.FindLastIfNot(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIfNot: count out of bounds');

  Result := FBuf.FindLastIfNot(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLastIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLastIfNot: count out of bounds');

  Result := FBuf.FindLastIfNot(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

{ IGenericCollection - CountOf 系列方法实现 }
function TVec.CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  Result := CountOf(aElement, aStartIndex, FCount - aStartIndex);
end;

function TVec.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  Result := CountOf(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TVec.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  Result := CountOf(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  Result := CountOf(aElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TVec.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountOf: count out of bounds');

  Result := FBuf.CountOf(aElement, aStartIndex, aCount);
end;

function TVec.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountOf: count out of bounds');

  Result := FBuf.CountOf(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TVec.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountOf: count out of bounds');

  Result := FBuf.CountOf(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountOf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountOf: count out of bounds');

  Result := FBuf.CountOf(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TVec.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountIf: count out of bounds');

  Result := FBuf.CountIf(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountIf: count out of bounds');

  Result := FBuf.CountIf(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.CountIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.CountIf: count out of bounds');

  Result := FBuf.CountIf(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex);
end;

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Replace: count out of bounds');

  FBuf.Replace(aElement, aNewElement, aStartIndex, aCount);
end;

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Replace: count out of bounds');

  FBuf.Replace(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Replace: count out of bounds');

  FBuf.Replace(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Replace: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Replace: count out of bounds');

  FBuf.Replace(aElement, aNewElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ReplaceIf: count out of bounds');

  FBuf.ReplaceIf(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ReplaceIf: count out of bounds');

  FBuf.ReplaceIf(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.ReplaceIf: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.ReplaceIf: count out of bounds');

  FBuf.ReplaceIf(aNewElement, aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

procedure TVec.Sort;
begin
  if FCount = 0 then
    exit;

  Sort(0, FCount);
end;

procedure TVec.Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if FCount = 0 then
    exit;

  Sort(0, FCount, aComparer, aData);
end;

procedure TVec.Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if FCount = 0 then
    exit;

  Sort(0, FCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Sort(aComparer: specialize TCompareRefFunc<T>);
begin
  if FCount = 0 then
    exit;

  Sort(0, FCount, aComparer);
end;
{$ENDIF}

procedure TVec.Sort(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  Sort(aStartIndex, FCount - aStartIndex);
end;

procedure TVec.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

procedure TVec.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  Sort(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

procedure TVec.Sort(aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Sort: count out of bounds');

  FBuf.Sort(aStartIndex, aCount);
end;

procedure TVec.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Sort: count out of bounds');

  FBuf.Sort(aStartIndex, aCount, aComparer, aData);
end;

procedure TVec.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Sort: count out of bounds');

  FBuf.Sort(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Sort: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Sort: count out of bounds');

  FBuf.Sort(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearch(const aElement: T): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearch(aElement, 0, FCount);
end;

function TVec.BinarySearch(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearch(aElement, 0, FCount, aComparer, aData);
end;

function TVec.BinarySearch(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearch(aElement, 0, FCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearch(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearch(aElement, 0, FCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearch(const aElement: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  Result := BinarySearch(aElement, aStartIndex, FCount - aStartIndex);
end;

function TVec.BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  Result := BinarySearch(aElement, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TVec.BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  Result := BinarySearch(aElement, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearch(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  Result := BinarySearch(aElement, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TVec.BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearch: count out of bounds');

  Result := FBuf.BinarySearch(aElement, aStartIndex, aCount);
end;

function TVec.BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearch: count out of bounds');

  Result := FBuf.BinarySearch(aElement, aStartIndex, aCount, aComparer, aData);
end;

function TVec.BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearch: count out of bounds');

  Result := FBuf.BinarySearch(aElement, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearch(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearch: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearch: count out of bounds');

  Result := FBuf.BinarySearch(aElement, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearchInsert(const aElement: T): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearchInsert(aElement, 0, FCount);
end;

function TVec.BinarySearchInsert(const aElement: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearchInsert(aElement, 0, FCount, aComparer, aData);
end;

function TVec.BinarySearchInsert(const aElement: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearchInsert(aElement, 0, FCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearchInsert(const aElement: T; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := BinarySearchInsert(aElement, 0, FCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  Result := BinarySearchInsert(aElement, aStartIndex, FCount - aStartIndex);
end;

function TVec.BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  Result := BinarySearchInsert(aElement, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TVec.BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  Result := BinarySearchInsert(aElement, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearchInsert(const aElement: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  Result := BinarySearchInsert(aElement, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TVec.BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: count out of bounds');

  Result := FBuf.BinarySearchInsert(aElement, aStartIndex, aCount);
end;

function TVec.BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: count out of bounds');

  Result := FBuf.BinarySearchInsert(aElement, aStartIndex, aCount, aComparer, aData);
end;

function TVec.BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: count out of bounds');

  Result := FBuf.BinarySearchInsert(aElement, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearchInsert(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.BinarySearchInsert: count out of bounds');

  Result := FBuf.BinarySearchInsert(aElement, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

procedure TVec.Shuffle;
begin
  if FCount = 0 then
    exit;

  Shuffle(0, FCount);
end;

procedure TVec.Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if FCount = 0 then
    exit;

  Shuffle(0, FCount, aRandomGenerator, aData);
end;

procedure TVec.Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if FCount = 0 then
    exit;

  Shuffle(0, FCount, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Shuffle(aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if FCount = 0 then
    exit;

  Shuffle(0, FCount, aRandomGenerator);
end;
{$ENDIF}

procedure TVec.Shuffle(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  Shuffle(aStartIndex, FCount - aStartIndex);
end;

procedure TVec.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

procedure TVec.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator);
end;
{$ENDIF}

procedure TVec.Shuffle(aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Shuffle: count out of bounds');

  FBuf.Shuffle(aStartIndex, aCount);
end;

procedure TVec.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Shuffle: count out of bounds');

  FBuf.Shuffle(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TVec.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Shuffle: count out of bounds');

  FBuf.Shuffle(aStartIndex, aCount, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aCount = 0 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Shuffle: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Shuffle: count out of bounds');

  FBuf.Shuffle(aStartIndex, aCount, aRandomGenerator);
end;
{$ENDIF}

function TVec.IsSorted: Boolean;
begin
  if FCount < 2 then
    exit(True);

  Result := IsSorted(0, FCount);
end;

function TVec.IsSorted(aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if FCount < 2 then
    exit(True);

  Result := IsSorted(0, FCount, aComparer, aData);
end;

function TVec.IsSorted(aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if FCount < 2 then
    exit(True);

  Result := IsSorted(0, FCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.IsSorted(aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if FCount < 2 then
    exit(True);

  Result := IsSorted(0, FCount, aComparer);
end;
{$ENDIF}

function TVec.IsSorted(aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  Result := IsSorted(aStartIndex, FCount - aStartIndex);
end;

function TVec.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TVec.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TVec.IsSorted(aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount < 2 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.IsSorted: count out of bounds');

  Result := FBuf.IsSorted(aStartIndex, aCount);
end;

function TVec.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.IsSorted: count out of bounds');

  Result := FBuf.IsSorted(aStartIndex, aCount, aComparer, aData);
end;

function TVec.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.IsSorted: count out of bounds');

  Result := FBuf.IsSorted(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aCount < 2 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.IsSorted: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.IsSorted: count out of bounds');

  Result := FBuf.IsSorted(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.FindIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(0);

  Result := FindIfNot(0, FCount, aPredicate, aData);
end;

function TVec.FindIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(0);

  Result := FindIfNot(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(0);

  Result := FindIfNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TVec.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TVec.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TVec.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIfNot: count out of bounds');

  Result := FBuf.FindIfNot(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIfNot: count out of bounds');

  Result := FBuf.FindIfNot(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindIfNot: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindIfNot: count out of bounds');

  Result := FBuf.FindIfNot(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLast(const aValue: T): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLast(aValue, 0, FCount);
end;

function TVec.FindLast(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLast(aValue, 0, FCount, aEquals, aData);
end;

function TVec.FindLast(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLast(aValue, 0, FCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLast(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    exit(-1);

  Result := FindLast(aValue, 0, FCount, aEquals);
end;
{$ENDIF}

function TVec.FindLast(const aValue: T; aStartIndex: SizeUInt): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  Result := FindLast(aValue, aStartIndex, FCount - aStartIndex);
end;

function TVec.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  Result := FindLast(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TVec.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  Result := FindLast(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLast(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  Result := FindLast(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TVec.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLast: count out of bounds');

  Result := FBuf.FindLast(aValue, aStartIndex, aCount);
end;

function TVec.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLast: count out of bounds');

  Result := FBuf.FindLast(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVec.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLast: count out of bounds');

  Result := FBuf.FindLast(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLast(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.FindLast: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.FindLast: count out of bounds');

  Result := FBuf.FindLast(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TVec.Contains(const aValue: T; aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex);
end;

function TVec.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TVec.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TVec.Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Contains: count out of bounds');

  Result := FBuf.Contains(aValue, aStartIndex, aCount);
end;

function TVec.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Contains: count out of bounds');

  Result := FBuf.Contains(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TVec.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Contains: count out of bounds');

  Result := FBuf.Contains(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TVec.Contains: index out of bounds');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TVec.Contains: count out of bounds');

  Result := FBuf.Contains(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

{ Unchecked 算法方法实现 - 跳过边界检查，追求极致性能 }

function TVec.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.ForEachUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.ForEachUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  Result := FBuf.ForEachUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

procedure TVec.SortUnchecked(aStartIndex, aCount: SizeUInt);
begin
  FBuf.SortUnchecked(aStartIndex, aCount);
end;

procedure TVec.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  FBuf.SortUnchecked(aStartIndex, aCount, aComparer, aData);
end;

procedure TVec.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  FBuf.SortUnchecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  FBuf.SortUnchecked(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := FBuf.ContainsUnchecked(aElement, aStartIndex, aCount);
end;

function TVec.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.ContainsUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TVec.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.ContainsUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  Result := FBuf.ContainsUnchecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

procedure TVec.ZeroUnchecked(aIndex, aCount: SizeUInt);
begin
  FBuf.ZeroUnchecked(aIndex, aCount);
end;

function TVec.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindIfNotUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := FBuf.FindLastUnchecked(aElement, aStartIndex, aCount);
end;

function TVec.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TVec.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindLastUnchecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

procedure TVec.FillUnchecked(aStartIndex, aCount: SizeUInt; const aElement: T);
begin
  FBuf.FillUnchecked(aStartIndex, aCount, aElement);
end;

function TVec.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindLastIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := FBuf.FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  Result := FBuf.CountOfUnchecked(aElement, aStartIndex, aCount);
end;

function TVec.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.CountOfUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TVec.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.CountOfUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  Result := FBuf.CountOfUnchecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TVec.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.CountIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TVec.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.CountIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  Result := FBuf.CountIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  Result := FBuf.ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount);
end;

function TVec.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

function TVec.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  Result := FBuf.ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TVec.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

function TVec.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := FBuf.ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  Result := FBuf.ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TVec.IsSortedUnchecked(aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := FBuf.IsSortedUnchecked(aStartIndex, aCount);
end;

function TVec.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.IsSortedUnchecked(aStartIndex, aCount, aComparer, aData);
end;

function TVec.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  Result := FBuf.IsSortedUnchecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  Result := FBuf.IsSortedUnchecked(aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := FBuf.BinarySearchUnchecked(aElement, aStartIndex, aCount);
end;

function TVec.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.BinarySearchUnchecked(aElement, aStartIndex, aCount, aComparer, aData);
end;

function TVec.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.BinarySearchUnchecked(aElement, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := FBuf.BinarySearchUnchecked(aElement, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

function TVec.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := FBuf.BinarySearchInsertUnchecked(aElement, aStartIndex, aCount);
end;

function TVec.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.BinarySearchInsertUnchecked(aElement, aStartIndex, aCount, aComparer, aData);
end;

function TVec.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := FBuf.BinarySearchInsertUnchecked(aElement, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TVec.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := FBuf.BinarySearchInsertUnchecked(aElement, aStartIndex, aCount, aComparer);
end;
{$ENDIF}

procedure TVec.ShuffleUnchecked(aStartIndex, aCount: SizeUInt);
begin
  FBuf.ShuffleUnchecked(aStartIndex, aCount);
end;

procedure TVec.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  FBuf.ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TVec.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  FBuf.ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TVec.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  FBuf.ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator);
end;
{$ENDIF}

procedure TVec.ReverseUnchecked(aStartIndex, aCount: SizeUInt);
begin
  FBuf.ReverseUnchecked(aStartIndex, aCount);
end;

end.


finalization
  if Assigned(_VecDefaultFactorStrategy) then
  begin
    _VecDefaultFactorStrategy.Free;
    _VecDefaultFactorStrategy := nil;
  end;
用
