unit nextpas.core.collections.arr;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.arr.base,
  nextpas.core.collections.arr.intf;

procedure MemCopyUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt); inline;
function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;

type


  { TArray 数组实现类 }
  generic TArray<T> = class(specialize TGenericCollection<T>, specialize IArray<T>)
  type
    TSwapMethod  = procedure(const aIndex1, aIndex2: SizeUInt) of object;
  private
    FMemory: Pointer;
    FCount:  SizeUInt;

  { ITerator 迭代器回调 }
{ 参见迭代器最佳实践：docs/Iterator_BestPractices.md }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  DoIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

  { 交换相关 }
  protected
    FSwapBufferCache:  Pointer;     // 交换内存缓冲区
    FSwapValueCache:   T;           // 交换值缓冲区
    FSwapPointerCache: PtrUInt;     // 交换指针缓冲区
    FSwapMethod:       TSwapMethod; // 交换回调
    procedure DoSwapRaw(const aIndex1, aIndex2: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure DoSwapPtrUInt(const aIndex1, aIndex2: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure DoSwapMove(const aIndex1, aIndex2: SizeUInt); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
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
    function  DoFindIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindIfNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindLast(aProxy: TEqualsProxyMethod;const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeInt; virtual;
    function  DoFindLastIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoFindLastIfNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt; virtual;
    function  DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aEquals, aData: Pointer): SizeUInt; override;
    function  DoCountOf(aProxy: TEqualsProxyMethod; const aElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer): SizeUInt; virtual;
    function  DoCountIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt; override;
    function  DoCountIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeUInt; virtual;
    procedure DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aEquals, aData: Pointer); override;
    procedure DoReplace(aProxy: TEqualsProxyMethod; const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals, aData: Pointer); virtual;
    procedure DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer); override;
    procedure DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer); virtual;
    function  DoIsSorted(aCompareProxy: TCompareProxyMethod; aStartIndex, aCount: SizeUInt; aComparer, aData: Pointer): Boolean; virtual;
    procedure DoQuickSort(aCompareProxy: TCompareProxyMethod; aLeft, aRight: SizeUInt; aComparer, aData: Pointer); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
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
    procedure LoadFromUnchecked(const aSrc: Pointer; aCount: SizeUInt); override; overload;
    procedure AppendUnchecked(const aSrc: Pointer; aCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;

    { IGenericCollection }
    procedure SaveToUnchecked(aDst: TCollection); override;

    { 容器方法... 只需要重写  doXXX }


    { IArray}

    function  GetMemory: PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  Get(aIndex: SizeUInt): T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetUnchecked(aIndex: SizeUInt): T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Put(aIndex: SizeUInt; const aValue: T); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure PutUnchecked(aIndex: SizeUInt; const aValue: T); {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetPtr(aIndex: SizeUInt): PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function  GetPtrUnchecked(aIndex: SizeUInt): PElement; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Resize(aNewSize: SizeUInt);
    procedure Ensure(aCount: SizeUInt);

    procedure Overwrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure OverwriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    procedure Overwrite(aIndex: SizeUInt; const aSrc: array of T); overload; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    // Non-throwing bulk ops (pointer overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;


    // Non-throwing bulk ops (collection overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: TCollection): Boolean;
    function  TryAppend(const aSrc: TCollection): Boolean;

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


    procedure Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
    procedure CopyUnchecked(aSrcIndex, aDstIndex, aCount: SizeUInt);


    procedure Fill(aIndex: SizeUInt; const aValue: T); overload;
    procedure Fill(aIndex, aCount: SizeUInt; const aValue: T); overload;


    procedure Zero(aIndex: SizeUInt); overload;
    procedure Zero(aIndex, aCount: SizeUInt); overload;


    procedure Reverse(aStartIndex: SizeUInt); overload;
    procedure Reverse(aStartIndex, aCount: SizeUInt); overload;


    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function  ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function  ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}


    function  Contains(const aValue: T; aStartIndex: SizeUInt): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function  Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function  Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function Find(const aValue: T): SizeInt; overload;
    function Find(const aValue: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function Find(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function FindIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function FindIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function FindLast(const aElement: T): SizeInt; overload;
    function FindLast(const aElement: T; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLast(const aElement: T; aStartIndex: SizeUInt): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function FindLastIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function FindLastIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt; overload;
    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}

    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
    {$ENDIF}


    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}

    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer); overload;
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>); overload;
    {$ENDIF}


    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}

    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer); overload;
    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>); overload;
    {$ENDIF}


    function IsSorted: Boolean; overload;
    function IsSorted(aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function IsSorted(aStartIndex: SizeUInt): Boolean; overload;
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

    function IsSorted(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}


    procedure Sort; overload;
    procedure Sort(aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure Sort(aStartIndex: SizeUInt); overload;
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure Sort(aStartIndex, aCount: SizeUInt); overload;
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}


    function BinarySearch(const aValue: T): SizeInt; overload;
    function BinarySearch(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearch(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    function BinarySearchInsert(const aValue: T): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt; overload;
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt; overload;
    {$ENDIF}


    procedure Shuffle; overload;
    procedure Shuffle(aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    procedure Shuffle(aStartIndex: SizeUInt); overload;
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    procedure Shuffle(aStartIndex, aCount: SizeUInt); overload;
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    { Unchecked 算法方法 - 跳过边界检查，追求极致性能 }
    function FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt; overload;
    function FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt; overload;
    function FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt; overload;
    {$ENDIF}

    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean; overload;
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean; overload;
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean; overload;
    {$ENDIF}

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

    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt): Boolean; overload;
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean; overload;
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean; overload;
    {$ENDIF}

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

    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt); overload;
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer); overload;
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc); overload;
    {$ENDIF}

    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean; overload;
    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean; overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    function ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean; overload;
    {$ENDIF}

    procedure SortUnchecked(aStartIndex, aCount: SizeUInt); overload;
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer); overload;
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer); overload;
    {$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
    procedure SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>); overload;
    {$ENDIF}

    procedure FillUnchecked(aIndex, aCount: SizeUInt; const aElement: T);
    procedure ZeroUnchecked(aIndex, aCount: SizeUInt);
    procedure ReverseUnchecked(aStartIndex, aCount: SizeUInt);

    property Items[aIndex: SizeUInt]: T           read Get write Put; default;
    property Ptr[aIndex: SizeUInt]:   PElement read GetPtr;
    property Memory:                  PElement read GetMemory;


  end;


implementation

procedure MemCopyUnchecked(aSrc, aDst: Pointer; aSize: SizeUInt); inline;
begin
  CopyUnChecked(aSrc, aDst, aSize);
end;

function MemIsOverlap(aPtr1: Pointer; aSize1: SizeUInt; aPtr2: Pointer; aSize2: SizeUInt): Boolean; inline;
begin
  Result := IsOverlap(aPtr1, aSize1, aPtr2, aSize2);
end;

function TArray.DoIterGetCurrent(aIter: PPtrIter): Pointer;
begin
  {$PUSH}{$WARN 4055 OFF}
  Result := GetPtrUnchecked(SizeUInt(aIter^.Data));
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
  FSwapValueCache := GetUnchecked(aIndex1);
  PutUnchecked(aIndex1, GetUnchecked(aIndex2));
  PutUnchecked(aIndex2, FSwapValueCache);
end;

procedure TArray.DoSwapPtrUInt(const aIndex1, aIndex2: SizeUInt);
var
  LP1: PPtrUInt;
  LP2: PPtrUInt;
begin
  LP1               := PPtrUInt(GetPtrUnchecked(aIndex1));
  LP2               := PPtrUInt(GetPtrUnchecked(aIndex2));
  FSwapPointerCache := LP1^;
  LP1^              := LP2^;
  LP2^              := FSwapPointerCache;
end;

procedure TArray.DoSwapMove(const aIndex1, aIndex2: SizeUInt);
var
  LP1: PElement;
  LP2: PElement;
begin
  LP1 := GetPtrUnchecked(aIndex1);
  LP2 := GetPtrUnchecked(aIndex2);

  MemCopyUnchecked(LP1, FSwapBufferCache, FElementSizeCache);
  MemCopyUnchecked(LP2, LP1, FElementSizeCache);
  MemCopyUnchecked(FSwapBufferCache, LP2, FElementSizeCache);
end;

function TArray.IsOverlap(const aSrc: Pointer; aCount: SizeUInt): Boolean;
var
  LArraySize, LExternalSize: SizeUInt;
begin
  { 计算数组内存大小和外部内存块大小 }
  LArraySize := FCount * GetElementSize;
  LExternalSize := aCount * GetElementSize;

  { 使用底层内存重叠检测函数 }
  Result := MemIsOverlap(FMemory, LArraySize, aSrc, LExternalSize);
end;

procedure TArray.DoFill(const aElement: T);
begin
  DoFill(0, FCount, aElement);
end;

procedure TArray.DoFill(aIndex, aCount: SizeUInt; const aElement: T);
begin
  FElementManager.FillElements(GetPtrUnchecked(aIndex), aElement, aCount);
end;

procedure TArray.DoZero();
begin
  DoZero(0, FCount);
end;

procedure TArray.DoZero(aIndex, aCount: SizeUInt);
begin
  FElementManager.ZeroElements(GetPtrUnchecked(aIndex), aCount);
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
    SwapUnchecked(LLeft, LRight);
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
    if not aProxy(aPredicate, GetUnchecked(i), aData) then
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
    if aProxy(aEquals, aElement, GetUnchecked(i), aData) then
      exit(i);
    Inc(i);
  end;

  Result := -1;
end;

function TArray.DoFindIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if aProxy(aPredicate, GetUnchecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindIfNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex to aStartIndex + aCount - 1 do
    if not aProxy(aPredicate, GetUnchecked(i), aData) then
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
    if aProxy(aEquals, aElement, GetUnchecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindLastIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex + aCount - 1 downto aStartIndex do
    if aProxy(aPredicate, GetUnchecked(i), aData) then
      exit(i);

  Result := -1;
end;

function TArray.DoFindLastIfNot(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeInt;
var
  i: SizeUInt;
begin
  if aCount = 0 then
    Exit(-1);

  for i := aStartIndex + aCount - 1 downto aStartIndex do
    if not aProxy(aPredicate, GetUnchecked(i), aData) then
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
    if aProxy(aEquals, aElement, GetUnchecked(i), aData) then
      Inc(Result);
end;

function TArray.DoCountIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt;
begin
  Result := DoCountIf(aProxy, 0, FCount, aPredicate, aData);
end;

function TArray.DoCountIf(aProxy: TPredicateProxyMethod; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer): SizeUInt;
var
  i, LEndIndex: SizeUInt;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  LEndIndex := aStartIndex + aCount - 1;
  for i := aStartIndex to LEndIndex do
    if aProxy(aPredicate, GetUnchecked(i), aData) then
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
    LP := GetPtrUnchecked(i);

    if aProxy(aEquals, aElement, LP^, aData) then
      LP^ := aNewElement;
  end;
end;

procedure TArray.DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aPredicate, aData: Pointer);
begin
  DoReplaceIf(aProxy, aNewElement, 0, FCount, aPredicate, aData);
end;

procedure TArray.DoReplaceIf(aProxy: TPredicateProxyMethod; const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate, aData: Pointer);
var
  i:  SizeUInt;
  LP: PElement;
begin
  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);

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

  LPCurrent := GetPtrUnchecked(aStartIndex);
  LPNext    := GetPtrUnchecked(aStartIndex + 1);
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
          SwapUnchecked(i, j);
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
  LP := GetPtrUnchecked(0);

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
    SwapUnchecked(i, aStartIndex + aProxy(aRandomGenerator, i - aStartIndex + 1, aData));
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
    raise EArgumentNil.Create('TArray.SerializeToArrayBuffer: aDst is nil');

  if IsOverlap(aDst, aCount) then
    raise EInvalidArgument.Create('TArray.SerializeToArrayBuffer: aDst is overlapped');

  if aCount > FCount then
    raise EOutOfRange.Create('TArray.SerializeToArrayBuffer: aCount out of bounds');

  FElementManager.CopyElementsNonOverlapUnchecked(FMemory, aDst, aCount);
end;

procedure TArray.LoadFromUnchecked(const aSrc: Pointer; aCount: SizeUInt);
begin
  Resize(aCount);
  OverwriteUnchecked(0, aSrc, aCount);
end;

procedure TArray.AppendUnchecked(const aSrc: Pointer; aCount: SizeUInt);
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
      raise EInvalidArgument.Create('TArray.AppendUnchecked: aSrc is not aligned');

    LIndex := (PtrUInt(aSrc) - PtrUInt(FMemory)) div LElementSize;
    {$POP}
    if (LIndex >= LCount) or (aCount > (LCount - LIndex)) then
      raise EOutOfRange.Create('TArray.AppendUnchecked: bounds out of range');

    Resize(LCount + aCount);
    CopyUnchecked(LIndex, LCount, aCount);
  end
  else
  begin
    Resize(LCount + aCount);
    OverwriteUnchecked(LCount, aSrc, aCount);
  end;
end;

procedure TArray.AppendToUnchecked(const aDst: TCollection);
begin
  if (FCount = 0) then
    exit;

  aDst.AppendUnchecked(FMemory, FCount);
end;

function TArray.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

procedure TArray.SaveToUnchecked(aDst: TCollection);
begin
  if FCount = 0 then
    aDst.Clear
  else
    aDst.LoadFromUnchecked(FMemory, FCount);
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

function TArray.GetUnchecked(aIndex: SizeUInt): T;
begin
  Result := GetPtrUnchecked(aIndex)^;
end;

procedure TArray.Put(aIndex: SizeUInt; const aValue: T);
begin
  GetPtr(aIndex)^ := aValue;
end;

procedure TArray.PutUnchecked(aIndex: SizeUInt; const aValue: T);
begin
  GetPtrUnchecked(aIndex)^ := aValue;
end;

function TArray.GetPtr(aIndex: SizeUInt): PElement;
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.GetPtr: index out of range');

  Result := GetPtrUnchecked(aIndex);
end;

function TArray.GetPtrUnchecked(aIndex: SizeUInt): PElement;
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
    raise EOutOfMemory.Create('TArray.Resize: out of memory');

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
    raise EOutOfRange.Create('TArray.Fill: aIndex out of range');

  DoFill(aIndex, FCount - aIndex, aValue);
end;

procedure TArray.Fill(aIndex, aCount: SizeUInt; const aValue: T);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Fill: aIndex out of range');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TArray.Fill: aIndex + aCount out of range');

  FillUnchecked(aIndex, aCount, aValue);
end;


procedure TArray.Zero(aIndex: SizeUInt);
begin
  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Zero: aIndex out of range');

  ZeroUnchecked(aIndex, FCount - aIndex);
end;

procedure TArray.Zero(aIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Zero: aIndex out of range');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TArray.Zero: aIndex + aCount out of range');

  ZeroUnchecked(aIndex, aCount);
end;

procedure TArray.Swap(aIndex1, aIndex2: SizeUInt);
begin
  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise EOutOfRange.Create('TArray.Swap: index out of range');

  if aIndex1 = aIndex2 then
    raise EInvalidArgument.Create('TArray.Swap: same index');

  SwapUnchecked(aIndex1, aIndex2);
end;

procedure TArray.SwapUnchecked(aIndex1, aIndex2: SizeUInt);
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
    raise EInvalidArgument.Create('TArray.Swap: same index');

  if (aIndex1 >= FCount) or (aIndex2 >= FCount) then
    raise EOutOfRange.Create('TArray.Swap: index out of range');

  if aCount > (FCount - aIndex1) then
    raise EOutOfRange.Create('TArray.Swap: aIndex1 + aCount out of range');

  if aCount > (FCount - aIndex2) then
    raise EOutOfRange.Create('TArray.Swap: aIndex2 + aCount out of range');

  { 如果元素数量大于 1，则需要检查范围是否越界和是否重叠并且用临时缓冲区交换元素 }
  if aCount > 1 then
  begin
    if (aIndex1 + aCount > aIndex2) and (aIndex2 + aCount > aIndex1) then
      raise EInvalidArgument.Create('TArray.Swap: overlap');

    LElementSize := GetElementSize;
    LRemainSize  := aCount * LElementSize;

    if LRemainSize > aSwapBufferSize then
      LBufferSize := aSwapBufferSize
    else
      LBufferSize := LRemainSize;

    LBuffer := Allocator.GetMem(LBufferSize);

    if LBuffer = nil then
      raise EOutOfMemory.Create('TArray.Swap: out of memory');

    try
      { 分块交换元素 }
      LP1 := PByte(GetPtrUnchecked(aIndex1));
      LP2 := PByte(GetPtrUnchecked(aIndex2));

      while LRemainSize > 0 do
      begin
        if LBufferSize > LRemainSize then
          LBufferSize  := LRemainSize;

        MemCopyUnchecked(LP1,     LBuffer, LBufferSize);
        MemCopyUnchecked(LP2,     LP1,     LBufferSize);
        MemCopyUnchecked(LBuffer, LP2,     LBufferSize);

        Inc(LP1, LBufferSize);
        Inc(LP2, LBufferSize);
        Dec(LRemainSize, LBufferSize);
      end;

    finally
      Allocator.FreeMem(LBuffer);
    end;
  end
  else
    SwapUnchecked(aIndex1, aIndex2);
end;

procedure TArray.Copy(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aSrcIndex >= FCount then
    raise EOutOfRange.Create('TArray.Copy: src index out of range');

  if aDstIndex >= FCount then
    raise EOutOfRange.Create('TArray.Copy: dst index out of range');

  if aCount > (FCount - aSrcIndex) then
    raise EOutOfRange.Create('TArray.Copy: src index + count out of range');

  if aCount > (FCount - aDstIndex) then
    raise EOutOfRange.Create('TArray.Copy: dst index + count out of range');

  if aSrcIndex = aDstIndex then
    raise EInvalidArgument.Create('TArray.Copy: same index');

  CopyUnchecked(aSrcIndex, aDstIndex, aCount);
end;

procedure TArray.CopyUnchecked(aSrcIndex, aDstIndex, aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnchecked(GetPtrUnchecked(aSrcIndex), GetPtrUnchecked(aDstIndex), aCount);
end;

procedure TArray.Reverse(aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Reverse: aStartIndex out of range');

  Reverse(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Reverse(aStartIndex, aCount: SizeUInt);
begin
  if aCount <= 1 then
    exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Reverse: aStartIndex out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Reverse: aStartIndex + aCount out of range');

  ReverseUnchecked(aStartIndex, aCount);
end;

function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEach(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  Result := ForEach(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEach(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ForEach: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ForEach: bounds out of range');

  Result := ForEachUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.Contains(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  Result := Contains(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnchecked(aValue, aStartIndex, aCount);
end;

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.Contains(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  if aCount = 0 then
    exit(False);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Contains: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Contains: bounds out of range');

  Result := ContainsUnchecked(aValue, aStartIndex, aCount, aEquals);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.Find(const aValue: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  Result := Find(aValue, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnchecked(aValue, aStartIndex, aCount);
end;

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnchecked(aValue, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.Find(const aValue: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Find: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Find: bounds out of range');

  Result := FindUnchecked(aValue, aStartIndex, aCount, aEquals);
end;
{$ENDIF}


function TArray.FindIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIf(0, FCount, aPredicate, aData);
end;

function TArray.FindIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIf(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIf(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  Result := FindIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIf: bounds out of range');

  Result := FindIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIf: bounds out of range');

  Result := FindIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIf: bounds out of range');

  Result := FindIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}


function TArray.FindIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIfNot(0, FCount, aPredicate, aData);
end;

function TArray.FindIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIfNot(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindIfNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIfNot(aStartIndex: SizeUInt; aPredicate: specialize
  TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  Result := FindIfNot(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIfNot: bounds out of range');

  Result := FindIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIfNot: bounds out of range');

  Result := FindIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindIfNot: bounds out of range');

  Result := FindIfNotUnchecked(aStartIndex, aCount, aPredicate);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex);
end;

function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLast(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  Result := FindLast(aElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnchecked(aElement, aStartIndex, aCount);
end;

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLast(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLast: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLast: bounds out of range');

  Result := FindLastUnchecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TArray.FindLastIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIf(0, FCount, aPredicate, aData);
end;

function TArray.FindLastIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIf(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIf(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIf(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  Result := FindLastIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIf: bounds out of range');

  Result := FindLastIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIf: bounds out of range');

  Result := FindLastIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIf: bounds out of range');

  Result := FindLastIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIfNot(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate, aData);
end;

function TArray.FindLastIfNot(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIfNot(aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if FCount = 0 then
    Exit(-1);

  Result := FindLastIfNot(0, FCount, aPredicate);
end;
{$ENDIF}

function TArray.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  Result := FindLastIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  Result := FindLastIfNot(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIfNot(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  Result := DoFindLastIfNot(@DoPredicateRefFuncProxy, aStartIndex, FCount - aStartIndex, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIfNot: bounds out of range');

  Result := FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIfNot: bounds out of range');

  Result := FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIfNot(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.FindLastIfNot: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.FindLastIfNot: bounds out of range');

  Result := FindLastIfNotUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsDefaultProxy, aElement, aStartIndex, FCount - aStartIndex, nil, nil);
end;

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsFuncProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, aData);
end;

function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsMethodProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOf(const aElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  Result := DoCountOf(@DoEqualsRefFuncProxy, aElement, aStartIndex, FCount - aStartIndex, @aEquals, nil);
end;
{$ENDIF}

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnchecked(aElement, aStartIndex, aCount);
end;

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnchecked(aElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOf(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountOf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountOf: bounds out of range');

  Result := CountOfUnchecked(aElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIf(aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  Result := CountIf(aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnchecked(aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIf(aStartIndex, aCount: SizeUInt; aPredicate: specialize
  TPredicateRefFunc<T>): SizeUInt;
begin
  if aCount = 0 then
    Exit(0);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.CountIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.CountIf: bounds out of range');

  Result := CountIfUnchecked(aStartIndex, aCount, aPredicate);
end;
{$ENDIF}

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  Replace(aElement, aNewElement, aStartIndex, FCount - aStartIndex, aEquals);
end;
{$ENDIF}


procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Replace(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Replace: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Replace: bounds out of range');

  ReplaceUnchecked(aElement, aNewElement, aStartIndex, aCount, aEquals);
end;
{$ENDIF}

procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  ReplaceIf(aNewElement, aStartIndex, FCount - aStartIndex, aPredicate);
end;
{$ENDIF}

procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ReplaceIf: bounds out of range');

  ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ReplaceIf: bounds out of range');

  ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ReplaceIf(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>);
begin
  if aCount = 0 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.ReplaceIf: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.ReplaceIf: bounds out of range');

  ReplaceIfUnchecked(aNewElement, aStartIndex, aCount, aPredicate);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex);
end;

function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSorted(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  Result := IsSorted(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.IsSorted(aStartIndex, aCount: SizeUInt): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnchecked(aStartIndex, aCount);
end;

function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnchecked(aStartIndex, aCount, aComparer, aData);
end;

function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnchecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSorted(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  if aCount < 2 then
    Exit(True);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.IsSorted: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.IsSorted: bounds out of range');

  Result := IsSortedUnchecked(aStartIndex, aCount, aComparer);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Sort(aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  Sort(aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}


procedure TArray.Sort(aStartIndex, aCount: SizeUInt);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnchecked(aStartIndex, aCount);
end;

procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnchecked(aStartIndex, aCount, aComparer, aData);
end;

procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnchecked(aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Sort(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Sort: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Sort: bounds out of range');

  SortUnchecked(aStartIndex, aCount, aComparer);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearch(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  Result := BinarySearch(aValue, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnchecked(aValue, aStartIndex, aCount);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnchecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnchecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearch(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearch: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearch: bounds out of range');

  Result := BinarySearchUnchecked(aValue, aStartIndex, aCount, aComparer);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsert(const aValue: T; aStartIndex: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  Result := BinarySearchInsert(aValue, aStartIndex, FCount - aStartIndex, aComparer);
end;
{$ENDIF}

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnchecked(aValue, aStartIndex, aCount);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnchecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnchecked(aValue, aStartIndex, aCount, aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsert(const aValue: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  if aCount = 0 then
    Exit(-1);

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.BinarySearchInsert: bounds out of range');

  Result := BinarySearchInsertUnchecked(aValue, aStartIndex, aCount, aComparer);
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

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
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
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex);
end;

procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Shuffle(aStartIndex: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  Shuffle(aStartIndex, FCount - aStartIndex, aRandomGenerator);
end;
{$ENDIF}

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  DoShuffle(@DoRandomGeneratorDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.Shuffle(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  if aCount < 2 then
    Exit;

  if aStartIndex >= FCount then
    raise EOutOfRange.Create('TArray.Shuffle: index out of range');

  if aCount > (FCount - aStartIndex) then
    raise EOutOfRange.Create('TArray.Shuffle: bounds out of range');

  ShuffleUnchecked(aStartIndex, aCount, aRandomGenerator);
end;
{$ENDIF}

procedure TArray.Overwrite(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TArray.Overwrite: aSrc is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Overwrite: index out of range');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TArray.Overwrite: bounds out of range');

  OverwriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TArray.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: Pointer; aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnchecked(aSrc, GetPtrUnchecked(aIndex), aCount);
end;

procedure TArray.Overwrite(aIndex: SizeUInt; const aSrc: array of T);
var
  LLen: SizeInt;
begin
  LLen := Length(aSrc);
  if LLen = 0 then
    Exit;
  Overwrite(aIndex, @aSrc[0], LLen);
end;

  { Unchecked 统一约定：
    - 不进行参数/边界/空指针检查；调用方需保证前置条件
    - open array 版本要求 aSrc 非空，否则 @aSrc[0] 未定义
    - 详见 docs/Unchecked_Methods_Summary.md }

procedure TArray.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: array of T);
begin
  OverwriteUnchecked(aIndex, @aSrc[0], Length(aSrc));
end;

procedure TArray.Overwrite(aIndex: SizeUInt; const aSrc: TCollection);
begin
  if aSrc = nil then
    raise EArgumentNil.Create('TArray.Overwrite: aSrc is nil');

  Overwrite(aIndex, aSrc, aSrc.GetCount);
end;

procedure TArray.Overwrite(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  if aCount = 0 then
    Exit;

  if aSrc = nil then
    raise EArgumentNil.Create('TArray.Overwrite: aSrc is nil');

  if not IsCompatible(aSrc) then
    raise ENotCompatible.Create('TArray.Overwrite: aSrc is not compatible');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Overwrite: index out of range');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TArray.Overwrite: bounds out of range');

  OverwriteUnchecked(aIndex, aSrc, aCount);
end;

procedure TArray.OverwriteUnchecked(aIndex: SizeUInt; const aSrc: TCollection; aCount: SizeUInt);
begin
  aSrc.SerializeToArrayBuffer(GetPtrUnchecked(aIndex), aCount);
end;

procedure TArray.Read(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  if aCount = 0 then
    exit;

  if aDst = nil then
    raise EArgumentNil.Create('TArray.Read: aDst is nil');

  if aIndex >= FCount then
    raise EOutOfRange.Create('TArray.Read: index out of range');

  if aCount > (FCount - aIndex) then
    raise EOutOfRange.Create('TArray.Read: bounds out of range');

  ReadUnchecked(aIndex, aDst, aCount);
end;

procedure TArray.ReadUnchecked(aIndex: SizeUInt; aDst: Pointer; aCount: SizeUInt);
begin
  FElementManager.CopyElementsUnchecked(GetPtrUnchecked(aIndex), aDst, aCount);
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

procedure TArray.ReadUnchecked(aIndex: SizeUInt; var aDst: specialize TGenericArray<T>; aCount: SizeUInt);
begin
  SetLength(aDst, aCount);
  ReadUnchecked(aIndex, @aDst[0], aCount);
end;

{ Unchecked 算法方法实现 - 跳过边界检查，追求极致性能 }

function TArray.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := DoContains(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoContains(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoContains(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ContainsUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): Boolean;
begin
  Result := DoContains(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIf(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIf(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindIf(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIfNot(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindIfNot(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindIfNot(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoFindLast(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLast(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLast(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := DoFindLast(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoFind(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFind(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFind(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeInt;
begin
  Result := DoFind(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIf(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIf(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindLastIf(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIfNot(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoFindLastIfNot(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.FindLastIfNotUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeInt;
begin
  Result := DoFindLastIfNot(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsFuncProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

function TArray.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsMethodProxy, aElement, aStartIndex, aCount, @aEquals, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountOfUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
begin
  Result := DoCountOf(@DoEqualsRefFuncProxy, aElement, aStartIndex, aCount, @aEquals, nil);
end;
{$ENDIF}

function TArray.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoForEach(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoForEach(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ForEachUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): Boolean;
begin
  Result := DoForEach(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountIf(@DoPredicateFuncProxy, aStartIndex, aCount, @aPredicate, aData);
end;

function TArray.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  Result := DoCountIf(@DoPredicateMethodProxy, aStartIndex, aCount, @aPredicate, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.CountIfUnchecked(aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  Result := DoCountIf(@DoPredicateRefFuncProxy, aStartIndex, aCount, @aPredicate, nil);
end;
{$ENDIF}

function TArray.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoEqualsDefaultProxy(nil, aElement, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsFunc<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoEqualsFuncProxy(@aEquals, aElement, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsMethod<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoEqualsMethodProxy(@aEquals, aElement, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ReplaceUnchecked(const aElement, aNewElement: T; aStartIndex, aCount: SizeUInt; aEquals: specialize TEqualsRefFunc<T>): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoEqualsRefFuncProxy(@aEquals, aElement, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;
{$ENDIF}

function TArray.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoPredicateFuncProxy(@aPredicate, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

function TArray.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoPredicateMethodProxy(@aPredicate, LP^, aData) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.ReplaceIfUnchecked(const aNewElement: T; aStartIndex, aCount: SizeUInt; aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
var
  i: SizeUInt;
  LP: PElement;
begin
  Result := 0;

  if aCount = 0 then
    Exit;

  for i := aStartIndex to aStartIndex + aCount - 1 do
  begin
    LP := GetPtrUnchecked(i);
    if DoPredicateRefFuncProxy(@aPredicate, LP^, nil) then
    begin
      LP^ := aNewElement;
      Inc(Result);
    end;
  end;
end;
{$ENDIF}

procedure TArray.SortUnchecked(aStartIndex, aCount: SizeUInt);
begin
  DoSort(@DoCompareDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer);
begin
  DoSort(@DoCompareFuncProxy, aStartIndex, aCount, @aComparer, aData);
end;

procedure TArray.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer);
begin
  DoSort(@DoCompareMethodProxy, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.SortUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>);
begin
  DoSort(@DoCompareRefFuncProxy, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.IsSortedUnchecked(aStartIndex, aCount: SizeUInt): Boolean;
begin
  Result := DoIsSorted(@DoCompareDefaultProxy, aStartIndex, aCount, nil, nil);
end;

function TArray.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): Boolean;
begin
  Result := DoIsSorted(@DoCompareFuncProxy, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): Boolean;
begin
  Result := DoIsSorted(@DoCompareMethodProxy, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.IsSortedUnchecked(aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): Boolean;
begin
  Result := DoIsSorted(@DoCompareRefFuncProxy, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareFuncProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareMethodProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := DoBinarySearch(@DoCompareRefFuncProxy, aElement, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

function TArray.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareDefaultProxy, aElement, aStartIndex, aCount, nil, nil);
end;

function TArray.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareFunc<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareFuncProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

function TArray.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareMethod<T>; aData: Pointer): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareMethodProxy, aElement, aStartIndex, aCount, @aComparer, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
function TArray.BinarySearchInsertUnchecked(const aElement: T; aStartIndex, aCount: SizeUInt; aComparer: specialize TCompareRefFunc<T>): SizeInt;
begin
  Result := DoBinarySearchInsert(@DoCompareRefFuncProxy, aElement, aStartIndex, aCount, @aComparer, nil);
end;
{$ENDIF}

procedure TArray.ShuffleUnchecked(aStartIndex, aCount: SizeUInt);
begin
  DoShuffle(@DoRandomGeneratorDefaultProxy, aStartIndex, aCount, nil, nil);
end;

procedure TArray.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorFunc; aData: Pointer);
begin
  DoShuffle(@DoRandomGeneratorFuncProxy, aStartIndex, aCount, @aRandomGenerator, aData);
end;

procedure TArray.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorMethod; aData: Pointer);
begin
  DoShuffle(@DoRandomGeneratorMethodProxy, aStartIndex, aCount, @aRandomGenerator, aData);
end;

{$IFDEF NEXTPAS_CORE_ANONYMOUS_REFERENCES}
procedure TArray.ShuffleUnchecked(aStartIndex, aCount: SizeUInt; aRandomGenerator: TRandomGeneratorRefFunc);
begin
  DoShuffle(@DoRandomGeneratorRefFuncProxy, aStartIndex, aCount, @aRandomGenerator, nil);
end;
{$ENDIF}

procedure TArray.FillUnchecked(aIndex, aCount: SizeUInt; const aElement: T);
begin
  // Route through the same optimized path as checked Fill to ensure
  // consistent behavior for managed/unmanaged types and better performance.
  DoFill(aIndex, aCount, aElement);
end;

procedure TArray.ZeroUnchecked(aIndex, aCount: SizeUInt);
begin
  DoZero(aIndex, aCount);
end;

procedure TArray.ReverseUnchecked(aStartIndex, aCount: SizeUInt);
begin
  DoReverse(aStartIndex, aCount);
end;

initialization
  System.Randomize;

end.
