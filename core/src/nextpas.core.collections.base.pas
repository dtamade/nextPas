unit nextpas.core.collections.base;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,typinfo,variants,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.allocator,
  nextpas.core.collections.element_manager.intf;

// Suppress unused parameter hints - growth strategies and IsOverlap have intentionally unused params
{$WARN 5024 OFF}


type

  TCollection = class;

  generic TGenericArray<T> = array of T;

  generic TElementRef<T> = record
  public type
    PElement = ^T;
  end;

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



  { TCollection: 所有容器的基类. }
  TCollection = class(TInterfacedObject)
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
    procedure LoadFromUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); virtual; overload;
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; virtual; overload;
    procedure Append(const aSrc: Pointer; aElementCount: SizeUInt); virtual; overload;
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); virtual; abstract; overload;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; virtual; overload;

    procedure LoadFrom(const aSrc: TCollection); overload;
    procedure LoadFromUnchecked(const aSrc: TCollection); virtual; overload;
    function  TryLoadFrom(const aSrc: TCollection): Boolean; overload;

    procedure Append(const aSrc: TCollection); overload;
    procedure AppendUnchecked(const aSrc: TCollection); virtual;
    function  TryAppend(const aSrc: TCollection): Boolean; overload;

    procedure AppendTo(const aDst: TCollection);
    procedure AppendToUnchecked(const aDst: TCollection); virtual; abstract;

    procedure SaveTo(aDst: TCollection); overload;
    procedure SaveToUnchecked(aDst: TCollection); virtual;

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

  { 公共随机数回调类型由 collections.base 统一对外暴露 }
  TRandomGeneratorFunc = function (aRange: Int64; aData: Pointer): Int64;
  TRandomGeneratorMethod = function (aRange: Int64; aData: Pointer): Int64 of Object;
  TRandomGeneratorRefFunc = reference to function (aRange: Int64): Int64;



  { TGenericCollection 泛型容器基类 }

  generic TGenericCollection<T> = class(TCollection)

  type
    PElement        = ^T;
    TIter           = specialize TIter<T>;

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
    FElementManager:   specialize IElementManager<T>;
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
    function  DoCountIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt; virtual;
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
    function GetElementManager: specialize IElementManager<T>; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

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

    function CountIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt; overload;
    function CountIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function CountIf(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt; overload;
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
    property ElementManager:  specialize IElementManager<T> read GetElementManager;
    property ElementTypeInfo: PTypeInfo                     read GetElementTypeInfo;

  end;

type
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
  TGrowFunc = function(aCurrentSize, aRequiredSize: SizeUInt; aData: Pointer): SizeUInt;
  TGrowMethod = function(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;
  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  TGrowRefFunc = reference to function(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
  {$ENDIF}
  TGrowProxyMethod = function(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt of object;

  { TCustomGrowthStrategy 自定义回调增长策略 }
  TCustomGrowthStrategy = class(TGrowthStrategy)
  private
    FData: Pointer;
    FGrowFunc: TGrowFunc;
    FGrowMethod: TGrowMethod;
    FGrowRefFunc: TGrowRefFunc;
    FGrowProxy: TGrowProxyMethod;
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
    property Data: Pointer read GetData;
  end;

  { TCalcGrowStrategy 计算增长策略(这是个抽象类,不能直接使用) }
  TCalcGrowStrategy = class(TGrowthStrategy)
  protected
    function DoCalc(aCurrentSize: SizeUInt): SizeUInt; virtual; abstract;
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
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
      DEFAULT_ALIGN_SIZE = 64;
  public
    constructor Create(const aGrowStrategy: IGrowthStrategy; aAlignSize: SizeUInt);
    function DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
    property GrowStrategy: IGrowthStrategy read GetGrowStrategy;
    property AlignSize: SizeUInt read GetAlignSize;
  end;

  { TExactGrowStrategy 精确增长策略 }
  TExactGrowStrategy = class(TGrowthStrategy)
  private
    class var FGlobal: TExactGrowStrategy;
    class destructor Destroy;
  protected
    function DoGetGrowSize({%H-}aCurrentSize, aRequiredSize: SizeUInt): SizeUInt; override;
  public
    class function GetGlobal: TExactGrowStrategy; static; {$IFDEF FAFAFA_COLLECTIONS_INLINE} inline;{$ENDIF}
  end;

function FixedGrow(aStep: SizeUInt): IGrowthStrategy;
function FactorGrow(aFactor: Double): IGrowthStrategy;
function DoublingGrow: IGrowthStrategy;
function ExactGrow: IGrowthStrategy;
function GoldenRatioGrow: IGrowthStrategy;

{ 内置相等函数 }

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

uses
  nextpas.core.collections.element_manager;

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

  LoadFromUnchecked(aSrc, aElementCount);
end;

procedure TCollection.LoadFromUnchecked(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  Clear;
  AppendUnchecked(aSrc, aElementCount);
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
    LoadFromUnchecked(aSrc, aElementCount);
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
    AppendUnchecked(aSrc, aElementCount);
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

  AppendUnchecked(aSrc, aElementCount);
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

  LoadFromUnchecked(aSrc);
end;

procedure TCollection.LoadFromUnchecked(const aSrc: TCollection);
begin
  aSrc.SaveToUnchecked(Self);
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

  AppendUnchecked(aSrc);
end;

procedure TCollection.AppendUnchecked(const aSrc: TCollection);
begin
  if aSrc.IsEmpty then
    exit;

  aSrc.AppendToUnchecked(Self);
end;

procedure TCollection.AppendTo(const aDst: TCollection);
begin
  if aDst = nil then
    raise EArgumentNil.Create('TCollection.AppendTo: Failed to append: aCollection is nil');

  if not IsCompatible(aDst) then
    raise ENotCompatible.Create('TCollection.AppendTo: Failed to append: aCollection is not compatible');

  AppendToUnchecked(aDst);
end;

procedure TCollection.SaveTo(aDst: TCollection);
begin
  if aDst = nil then
    raise EArgumentNil.Create('TCollection.SaveTo: Failed to save: aCollection is nil');

  if aDst = Self then
    raise EInvalidArgument.Create('TCollection.SaveTo: Failed to save: aCollection is self');

  if not IsCompatible(aDst) then
    raise ENotCompatible.Create('TCollection.SaveTo: Failed to save: aCollection is not compatible');

  SaveToUnchecked(aDst);
end;

procedure TCollection.SaveToUnchecked(aDst: TCollection);
begin
  aDst.Clear;

  if IsEmpty then
    exit;

  aDst.AppendUnchecked(Self);
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
    LoadFromUnchecked(aSrc);
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
    AppendUnchecked(aSrc);
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

function TGenericCollection.DoCountIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): SizeUInt;
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
  FElementManager := specialize TElementManager<T>.Create(FAllocator);
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
      if LTypeInfo = TypeInfo(Int8) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI8);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI8);
      end
      else if LTypeInfo = TypeInfo(Int16) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI16);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI16);
      end
      else if LTypeInfo = TypeInfo(Int32) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI32);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI32);
      end
      else if LTypeInfo = TypeInfo(UInt8) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU8);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU8);
      end
      else if LTypeInfo = TypeInfo(UInt16) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU16);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU16);
      end
      else if LTypeInfo = TypeInfo(UInt32) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareU32);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsU32);
      end
    end;
    tkInt64:
    begin
      if LTypeInfo = TypeInfo(Int64) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareI64);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsI64);
      end
      else if LTypeInfo = TypeInfo(Comp) then
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
      if LTypeInfo = TypeInfo(Single) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareSingle);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsSingle);
      end
      else if LTypeInfo = TypeInfo(Double) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareDouble);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsDouble);
      end
      else if LTypeInfo = TypeInfo(Extended) then
      begin
        FInternalComparer := TInternalCompareMethod(@DoCompareExtended);
        FInternalEquals   := TInternalEqualsMethod(@DoEqualsExtended);
      end
      else if LTypeInfo = TypeInfo(Currency) then
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

function TGenericCollection.GetElementManager: specialize IElementManager<T>;
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

function TGenericCollection.CountIf(aPredicate: specialize TPredicateFunc<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIf(@DoPredicateFuncProxy, @aPredicate, aData);
end;

function TGenericCollection.CountIf(aPredicate: specialize TPredicateMethod<T>; aData: Pointer): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIf(@DoPredicateMethodProxy, @aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TGenericCollection.CountIf(aPredicate: specialize TPredicateRefFunc<T>): SizeUInt;
begin
  if GetCount = 0 then
    exit(0);

  Result := DoCountIf(@DoPredicateRefFuncProxy, @aPredicate, nil);
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

{ 设计说明：
  - GetGrowSize 统一委派到具体策略 DoGetGrowSize，即便 aCurrentSize=0 也不在这里特判，
    让自定义策略可以在“首轮扩张”时生效自己的下界/策略。
  - 基类负责做最小下界收敛：Result >= aRequiredSize，保证调用方契约。
}

function TGrowthStrategy.GetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aRequiredSize <= aCurrentSize then
    Exit(aCurrentSize);

  Result := DoGetGrowSize(aCurrentSize, aRequiredSize);
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
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    if aCurrentSize > High(SizeUInt) div 2 then
      Result := High(SizeUInt)
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
  MAX_SAFE_SIZEUINT = 9223372036854775807;
begin
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    LProduct := aCurrentSize * FFactor;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT
    else
    begin
      LCeiled := Ceil(LProduct);
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
  MAX_SAFE_SIZEUINT = 9223372036854775807;
var
  LProduct: Single;
  LCeiled: Int64;
begin
  if aCurrentSize = 0 then
    Result := 1
  else
  begin
    LProduct := aCurrentSize * GOLDEN_RATIO;
    if (LProduct > MAX_SAFE_SIZEUINT) or IsInfinite(LProduct) or IsNaN(LProduct) then
      Result := MAX_SAFE_SIZEUINT
    else
    begin
      LCeiled := Ceil(LProduct);
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
  Result := TExactGrowStrategy.Create;
end;

function TExactGrowStrategy.DoGetGrowSize(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  if aCurrentSize <> 0 then;
  Result := aRequiredSize;
end;

end.
