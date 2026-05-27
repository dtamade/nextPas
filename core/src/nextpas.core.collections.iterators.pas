unit nextpas.core.collections.iterators;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.collections.iterators - 迭代器适配器模块
 *
 * 提供 Rust 风格的惰性迭代器适配器:
 * - TEnumerateIter<T> : 枚举迭代器，带索引迭代
 * - TZipIter<T, U>    : 压缩迭代器，并行迭代两个迭代器
 * - TChainIter<T>     : 链接迭代器，串联两个迭代器
 * - TMapIter<T, U>    : 映射迭代器，将 T 转换为 U
 * - TFilterIter<T>    : 过滤迭代器，只保留满足条件的元素
 * - TTakeIter<T>      : 取前 N 个元素
 * - TSkipIter<T>      : 跳过前 N 个元素
 *
 * 所有适配器都是惰性求值的，支持链式组合。
 *}

interface

uses
  SysUtils,
  nextpas.core.collections.base,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.vec;

type
  {**
   * TEnumerateIter<T> - 枚举迭代器
   *
   * 在迭代时同时提供元素索引和元素值
   * 类似 Rust 的 .enumerate() 和 Python 的 enumerate()
   *}
  generic TEnumerateIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
  private
    FSource: TSourceIter;
    FIndex: SizeUInt;
    FStartIndex: SizeUInt;
    FCurrent: T;
    FStarted: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aStartIndex: SizeUInt = 0);
    class function Create(const aSource: TSourceIter; aStartIndex: SizeUInt = 0): specialize TEnumerateIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function GetIndex: SizeUInt; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    // For TIter<T> compatibility
    function ToIter: TSourceIter;

    property Current: T read GetCurrent;
    property Index: SizeUInt read GetIndex;
  end;

  {**
   * TZipIter<T, U> - 压缩迭代器
   *
   * 并行迭代两个迭代器，返回元素对
   * 当任一迭代器耗尽时停止
   * 类似 Rust 的 .zip() 和 Python 的 zip()
   *}
  generic TZipIter<T, U> = record
  public type
    TFirstIter = specialize TIter<T>;
    TSecondIter = specialize TIter<U>;
  private
    FFirst: TFirstIter;
    FSecond: TSecondIter;
    FCurrentFirst: T;
    FCurrentSecond: U;
  public
    procedure Init(const aFirst: TFirstIter; const aSecond: TSecondIter);
    class function Create(const aFirst: TFirstIter; const aSecond: TSecondIter): specialize TZipIter<T, U>; static;

    function MoveNext: Boolean;
    function GetFirst: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}
    function GetSecond: U; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property First: T read GetFirst;
    property Second: U read GetSecond;
  end;

  {**
   * TChainIter<T> - 链接迭代器
   *
   * 串联两个相同类型的迭代器
   * 先迭代第一个，耗尽后迭代第二个
   * 类似 Rust 的 .chain()
   *}
  generic TChainIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
  private
    FFirst: TSourceIter;
    FSecond: TSourceIter;
    FCurrent: T;
    FFirstExhausted: Boolean;
  public
    procedure Init(const aFirst: TSourceIter; const aSecond: TSourceIter);
    class function Create(const aFirst: TSourceIter; const aSecond: TSourceIter): specialize TChainIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

  {**
   * TMapIter<T, U> - 映射迭代器
   *
   * 将源迭代器的每个元素通过映射函数转换为新类型
   *}
  generic TMapIter<T, U> = record
  public type
    TSourceIter = specialize TIter<T>;
    TMapperFunc = function(const aElement: T; aData: Pointer): U;
  private
    FSource: TSourceIter;
    FMapper: TMapperFunc;
    FData: Pointer;
    FCurrent: U;
    FStarted: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aMapper: TMapperFunc; aData: Pointer);
    class function Create(const aSource: TSourceIter; aMapper: TMapperFunc; aData: Pointer): specialize TMapIter<T, U>; static;

    function MoveNext: Boolean;
    function GetCurrent: U; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: U read GetCurrent;
  end;

  {**
   * TFilterIter<T> - 过滤迭代器
   *
   * 只返回满足谓词条件的元素
   *}
  generic TFilterIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
    TPredicateFunc = function(const aElement: T; aData: Pointer): Boolean;
  private
    FSource: TSourceIter;
    FPredicate: TPredicateFunc;
    FData: Pointer;
    FCurrent: T;
    FStarted: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
    class function Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TFilterIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    // For TIter<T> compatibility
    function ToIter: TSourceIter;

    property Current: T read GetCurrent;
  end;

  {**
   * TTakeIter<T> - 取前 N 个元素
   *
   * 最多返回前 N 个元素
   *}
  generic TTakeIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
  private
    FSource: TSourceIter;
    FRemaining: SizeUInt;
    FCurrent: T;
    FStarted: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aCount: SizeUInt);
    class function Create(const aSource: TSourceIter; aCount: SizeUInt): specialize TTakeIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

  {**
   * TRevIter<T> - 反向迭代器
   *
   * 将源迭代器的元素以反向顺序返回
   * 注意：需要缓存所有元素，因此会消耗额外内存
   * 类似 Rust 的 .rev()
   *}
  generic TRevIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
    TElementArray = array of T;
  private
    FElements: TElementArray;
    FIndex: SizeInt;  // 当前位置，从 Count-1 向 0 递减
    FCurrent: T;
    FInitialized: Boolean;
  public
    procedure Init(const aSource: TSourceIter);
    class function Create(const aSource: TSourceIter): specialize TRevIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

  {**
   * TSkipIter<T> - 跳过前 N 个元素
   *
   * 跳过前 N 个元素，返回剩余元素
   *}
  generic TSkipIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
  private
    FSource: TSourceIter;
    FSkipCount: SizeUInt;
    FSkipped: Boolean;
    FCurrent: T;
    FStarted: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aCount: SizeUInt);
    class function Create(const aSource: TSourceIter; aCount: SizeUInt): specialize TSkipIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    // For TIter<T> compatibility
    function ToIter: TSourceIter;

    property Current: T read GetCurrent;
  end;

  {**
   * TTakeWhileIter<T> - 条件取元素迭代器
   *
   * 只要谓词返回 True 就继续返回元素，一旦谓词返回 False 就停止
   * 类似 Rust 的 .take_while()
   *}
  generic TTakeWhileIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
    TPredicateFunc = function(const aElement: T; aData: Pointer): Boolean;
  private
    FSource: TSourceIter;
    FPredicate: TPredicateFunc;
    FData: Pointer;
    FCurrent: T;
    FDone: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
    class function Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TTakeWhileIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

  {**
   * TSkipWhileIter<T> - 条件跳过迭代器
   *
   * 跳过所有满足谓词的元素，一旦谓词返回 False 就开始返回剩余元素
   * 类似 Rust 的 .skip_while()
   *}
  generic TSkipWhileIter<T> = record
  public type
    TSourceIter = specialize TIter<T>;
    TPredicateFunc = function(const aElement: T; aData: Pointer): Boolean;
  private
    FSource: TSourceIter;
    FPredicate: TPredicateFunc;
    FData: Pointer;
    FCurrent: T;
    FSkipping: Boolean;
  public
    procedure Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
    class function Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TSkipWhileIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

  {**
   * TFlattenIter<T> - 扁平化迭代器
   *
   * 将嵌套的迭代器扁平化为单层迭代器
   * 类似 Rust 的 .flatten()
   *
   * 注意：此实现用于将 IVec<IVec<T>> 扁平化为 T 的迭代器
   *}
  generic TFlattenIter<T> = record
  public type
    TInnerVec = specialize IVec<T>;
    TOuterVec = specialize IVec<TInnerVec>;
    TOuterIter = specialize TIter<TInnerVec>;
    TInnerIter = specialize TIter<T>;
  private
    FOuterIter: TOuterIter;
    FInnerIter: TInnerIter;
    FHasInner: Boolean;
    FCurrent: T;
  public
    procedure Init(const aSource: TOuterIter);
    class function Create(const aSource: TOuterIter): specialize TFlattenIter<T>; static;

    function MoveNext: Boolean;
    function GetCurrent: T; {$IFDEF NEXTPAS_CORE_INLINE} inline;{$ENDIF}

    property Current: T read GetCurrent;
  end;

// ==== Collect 收集器函数 ====
// 从迭代器收集元素到 Vec 容器

{**
 * CollectToVec<T> - 从 TIter<T> 收集到 IVec<T>
 *
 * 消费迭代器中的所有元素，构造一个新的 Vec
 *}
generic function CollectToVec<T>(var aIter: specialize TIter<T>): specialize IVec<T>;

{**
 * CollectFilterToVec<T> - 从 TFilterIter<T> 收集到 IVec<T>
 *
 * 消费过滤迭代器中的所有元素，构造一个新的 Vec
 *}
generic function CollectFilterToVec<T>(var aIter: specialize TFilterIter<T>): specialize IVec<T>;

{**
 * CollectTakeToVec<T> - 从 TTakeIter<T> 收集到 IVec<T>
 *
 * 消费取前 N 个迭代器中的所有元素，构造一个新的 Vec
 *}
generic function CollectTakeToVec<T>(var aIter: specialize TTakeIter<T>): specialize IVec<T>;

{**
 * CollectChainToVec<T> - 从 TChainIter<T> 收集到 IVec<T>
 *
 * 消费链接迭代器中的所有元素，构造一个新的 Vec
 *}
generic function CollectChainToVec<T>(var aIter: specialize TChainIter<T>): specialize IVec<T>;

// ==== 终结组合子 (Terminal Combinators) ====
// 消费迭代器并产生单一结果

{**
 * IterFold<T, TAcc> - 折叠迭代器
 *
 * 使用累加器函数将迭代器中的所有元素折叠为单一值
 * 类似 Rust 的 .fold()
 *
 * @param aIter - 源迭代器
 * @param aInit - 初始累加值
 * @param aFolder - 折叠函数 (acc, element) -> acc
 * @param aData - 传递给折叠函数的用户数据
 * @return 最终累加值
 *}
type
  generic TFolderFunc<T, TAcc> = function(const aAcc: TAcc; const aElement: T; aData: Pointer): TAcc;

generic function IterFold<T, TAcc>(var aIter: specialize TIter<T>;
  const aInit: TAcc;
  aFolder: specialize TFolderFunc<T, TAcc>;
  aData: Pointer): TAcc;

{**
 * IterReduce<T> - 归约迭代器
 *
 * 使用二元函数将迭代器中的所有元素归约为单一值
 * 第一个元素作为初始值
 * 类似 Rust 的 .reduce()
 *
 * @param aIter - 源迭代器
 * @param aReducer - 归约函数 (acc, element) -> acc
 * @param aData - 传递给归约函数的用户数据
 * @param aResult - 输出结果
 * @return 如果迭代器非空返回 True，否则返回 False
 *}
type
  generic TReducerFunc<T> = function(const aAcc: T; const aElement: T; aData: Pointer): T;

generic function IterReduce<T>(var aIter: specialize TIter<T>;
  aReducer: specialize TReducerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;

{**
 * IterFind<T> - 查找元素
 *
 * 查找第一个满足谓词的元素
 * 类似 Rust 的 .find()
 *
 * @param aIter - 源迭代器
 * @param aPredicate - 谓词函数
 * @param aData - 传递给谓词函数的用户数据
 * @param aResult - 输出找到的元素
 * @return 如果找到返回 True，否则返回 False
 *}
type
  generic TIterPredicateFunc<T> = function(const aElement: T; aData: Pointer): Boolean;

generic function IterFind<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;

{**
 * IterAny<T> - 任意匹配
 *
 * 检查是否存在任意元素满足谓词
 * 类似 Rust 的 .any()
 *
 * @param aIter - 源迭代器
 * @param aPredicate - 谓词函数
 * @param aData - 传递给谓词函数的用户数据
 * @return 如果存在满足条件的元素返回 True
 *}
generic function IterAny<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): Boolean;

{**
 * IterAll<T> - 全部匹配
 *
 * 检查是否所有元素都满足谓词
 * 类似 Rust 的 .all()
 *
 * @param aIter - 源迭代器
 * @param aPredicate - 谓词函数
 * @param aData - 传递给谓词函数的用户数据
 * @return 如果所有元素都满足条件返回 True（空迭代器返回 True）
 *}
generic function IterAll<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): Boolean;

{**
 * IterForEach<T> - 遍历执行
 *
 * 对每个元素执行副作用操作
 * 类似 Rust 的 .for_each()
 *
 * @param aIter - 源迭代器
 * @param aAction - 操作函数
 * @param aData - 传递给操作函数的用户数据
 *}
type
  generic TActionFunc<T> = procedure(const aElement: T; aData: Pointer);

generic procedure IterForEach<T>(var aIter: specialize TIter<T>;
  aAction: specialize TActionFunc<T>;
  aData: Pointer);

{**
 * IterCount<T> - 计数
 *
 * 返回迭代器中的元素数量
 * 类似 Rust 的 .count()
 *
 * @param aIter - 源迭代器
 * @return 元素数量
 *}
generic function IterCount<T>(var aIter: specialize TIter<T>): SizeUInt;

{**
 * IterCountIf<T> - 条件计数
 *
 * 返回满足谓词的元素数量
 *
 * @param aIter - 源迭代器
 * @param aPredicate - 谓词函数
 * @param aData - 传递给谓词函数的用户数据
 * @return 满足条件的元素数量
 *}
generic function IterCountIf<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): SizeUInt;

{**
 * IterSum - 求和（整数）
 *
 * 计算迭代器中所有整数元素的和
 *
 * @param aIter - 源迭代器
 * @return 元素之和
 *}
function IterSumInt(var aIter: specialize TIter<Integer>): Int64;
function IterSumInt64(var aIter: specialize TIter<Int64>): Int64;

{**
 * IterMin/IterMax<T> - 最小/最大值
 *
 * 查找迭代器中的最小或最大元素
 *
 * @param aIter - 源迭代器
 * @param aComparer - 比较函数，返回负数表示 a < b
 * @param aData - 传递给比较函数的用户数据
 * @param aResult - 输出结果
 * @return 如果迭代器非空返回 True
 *}
type
  generic TComparerFunc<T> = function(const aA, aB: T; aData: Pointer): Integer;

generic function IterMin<T>(var aIter: specialize TIter<T>;
  aComparer: specialize TComparerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;

generic function IterMax<T>(var aIter: specialize TIter<T>;
  aComparer: specialize TComparerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;

{**
 * IterNth<T> - 获取第 N 个元素
 *
 * 获取迭代器中的第 N 个元素（0-indexed）
 *
 * @param aIter - 源迭代器
 * @param aIndex - 索引（从 0 开始）
 * @param aResult - 输出结果
 * @return 如果索引有效返回 True
 *}
generic function IterNth<T>(var aIter: specialize TIter<T>;
  aIndex: SizeUInt;
  out aResult: T): Boolean;

{**
 * IterLast<T> - 获取最后一个元素
 *
 * 获取迭代器中的最后一个元素
 *
 * @param aIter - 源迭代器
 * @param aResult - 输出结果
 * @return 如果迭代器非空返回 True
 *}
generic function IterLast<T>(var aIter: specialize TIter<T>;
  out aResult: T): Boolean;

implementation

{ TEnumerateIter<T> }

procedure TEnumerateIter.Init(const aSource: TSourceIter; aStartIndex: SizeUInt);
begin
  FSource := aSource;
  FStartIndex := aStartIndex;
  FIndex := aStartIndex;
  FStarted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TEnumerateIter.Create(const aSource: TSourceIter; aStartIndex: SizeUInt): specialize TEnumerateIter<T>;
begin
  Result.Init(aSource, aStartIndex);
end;

function TEnumerateIter.MoveNext: Boolean;
begin
  Result := FSource.MoveNext;
  if Result then
  begin
    FCurrent := FSource.Current;
    // First successful MoveNext: index stays at FStartIndex
    // Subsequent calls: increment index before returning
    if FStarted then
      Inc(FIndex)
    else
      FStarted := True;
  end;
end;

function TEnumerateIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

function TEnumerateIter.GetIndex: SizeUInt;
begin
  Result := FIndex;
end;

function TEnumerateIter.ToIter: TSourceIter;
begin
  Result := FSource;
end;

{ TZipIter<T, U> }

procedure TZipIter.Init(const aFirst: TFirstIter; const aSecond: TSecondIter);
begin
  FFirst := aFirst;
  FSecond := aSecond;
  FillChar(FCurrentFirst, SizeOf(FCurrentFirst), 0);
  FillChar(FCurrentSecond, SizeOf(FCurrentSecond), 0);
end;

class function TZipIter.Create(const aFirst: TFirstIter; const aSecond: TSecondIter): specialize TZipIter<T, U>;
begin
  Result.Init(aFirst, aSecond);
end;

function TZipIter.MoveNext: Boolean;
begin
  // Both must advance successfully
  Result := FFirst.MoveNext and FSecond.MoveNext;
  if Result then
  begin
    FCurrentFirst := FFirst.Current;
    FCurrentSecond := FSecond.Current;
  end;
end;

function TZipIter.GetFirst: T;
begin
  Result := FCurrentFirst;
end;

function TZipIter.GetSecond: U;
begin
  Result := FCurrentSecond;
end;

{ TChainIter<T> }

procedure TChainIter.Init(const aFirst: TSourceIter; const aSecond: TSourceIter);
begin
  FFirst := aFirst;
  FSecond := aSecond;
  FFirstExhausted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TChainIter.Create(const aFirst: TSourceIter; const aSecond: TSourceIter): specialize TChainIter<T>;
begin
  Result.Init(aFirst, aSecond);
end;

function TChainIter.MoveNext: Boolean;
begin
  if not FFirstExhausted then
  begin
    Result := FFirst.MoveNext;
    if Result then
    begin
      FCurrent := FFirst.Current;
      Exit;
    end;
    // First exhausted, switch to second
    FFirstExhausted := True;
  end;

  // Try second iterator
  Result := FSecond.MoveNext;
  if Result then
    FCurrent := FSecond.Current;
end;

function TChainIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ TMapIter<T, U> }

procedure TMapIter.Init(const aSource: TSourceIter; aMapper: TMapperFunc; aData: Pointer);
begin
  FSource := aSource;
  FMapper := aMapper;
  FData := aData;
  FStarted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TMapIter.Create(const aSource: TSourceIter; aMapper: TMapperFunc; aData: Pointer): specialize TMapIter<T, U>;
begin
  Result.Init(aSource, aMapper, aData);
end;

function TMapIter.MoveNext: Boolean;
begin
  Result := FSource.MoveNext;
  if Result then
    FCurrent := FMapper(FSource.Current, FData);
end;

function TMapIter.GetCurrent: U;
begin
  Result := FCurrent;
end;

{ TFilterIter<T> }

procedure TFilterIter.Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
begin
  FSource := aSource;
  FPredicate := aPredicate;
  FData := aData;
  FStarted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TFilterIter.Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TFilterIter<T>;
begin
  Result.Init(aSource, aPredicate, aData);
end;

function TFilterIter.MoveNext: Boolean;
begin
  // Keep moving until we find an element that matches predicate
  while FSource.MoveNext do
  begin
    if FPredicate(FSource.Current, FData) then
    begin
      FCurrent := FSource.Current;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TFilterIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

function TFilterIter.ToIter: TSourceIter;
begin
  Result := FSource;
end;

{ TTakeIter<T> }

procedure TTakeIter.Init(const aSource: TSourceIter; aCount: SizeUInt);
begin
  FSource := aSource;
  FRemaining := aCount;
  FStarted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TTakeIter.Create(const aSource: TSourceIter; aCount: SizeUInt): specialize TTakeIter<T>;
begin
  Result.Init(aSource, aCount);
end;

function TTakeIter.MoveNext: Boolean;
begin
  if FRemaining = 0 then
    Exit(False);

  Result := FSource.MoveNext;
  if Result then
  begin
    FCurrent := FSource.Current;
    Dec(FRemaining);
  end;
end;

function TTakeIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ TRevIter<T> }

procedure TRevIter.Init(const aSource: TSourceIter);
var
  LSource: TSourceIter;
  LCapacity, LCount: SizeUInt;
begin
  // Collect all elements from source in one pass with dynamic growth
  LSource := aSource;
  LCapacity := 16;
  LCount := 0;
  SetLength(FElements, LCapacity);

  while LSource.MoveNext do
  begin
    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(FElements, LCapacity);
    end;
    FElements[LCount] := LSource.Current;
    Inc(LCount);
  end;

  // Trim to actual size
  SetLength(FElements, LCount);

  // Initialize for reverse iteration
  FIndex := SizeInt(LCount);  // Start past the end
  FInitialized := True;
  FillChar(FCurrent, SizeOf(T), 0);
end;

class function TRevIter.Create(const aSource: TSourceIter): specialize TRevIter<T>;
var
  LSource: TSourceIter;
  LCapacity, LCount: SizeUInt;
begin
  // Initialize Result to ensure managed types are properly set up
  Result := Default(specialize TRevIter<T>);

  // Collect all elements from source in one pass
  LSource := aSource;
  LCapacity := 16;
  LCount := 0;
  SetLength(Result.FElements, LCapacity);

  while LSource.MoveNext do
  begin
    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(Result.FElements, LCapacity);
    end;
    Result.FElements[LCount] := LSource.Current;
    Inc(LCount);
  end;

  // Trim to actual size
  SetLength(Result.FElements, LCount);

  // Initialize for reverse iteration
  Result.FIndex := SizeInt(LCount);  // Start past the end
  Result.FInitialized := True;
  FillChar(Result.FCurrent, SizeOf(T), 0);
end;

function TRevIter.MoveNext: Boolean;
begin
  // FIndex starts at Length(FElements), decrements each call
  Dec(FIndex);
  if FIndex >= 0 then
  begin
    FCurrent := FElements[FIndex];
    Result := True;
  end
  else
    Result := False;
end;

function TRevIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ TSkipIter<T> }

procedure TSkipIter.Init(const aSource: TSourceIter; aCount: SizeUInt);
begin
  FSource := aSource;
  FSkipCount := aCount;
  FSkipped := False;
  FStarted := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TSkipIter.Create(const aSource: TSourceIter; aCount: SizeUInt): specialize TSkipIter<T>;
begin
  Result.Init(aSource, aCount);
end;

function TSkipIter.MoveNext: Boolean;
begin
  // Skip elements on first call
  if not FSkipped then
  begin
    FSkipped := True;
    while (FSkipCount > 0) and FSource.MoveNext do
      Dec(FSkipCount);
  end;

  // Now return remaining elements
  Result := FSource.MoveNext;
  if Result then
    FCurrent := FSource.Current;
end;

function TSkipIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

function TSkipIter.ToIter: TSourceIter;
begin
  Result := FSource;
end;

{ TTakeWhileIter<T> }

procedure TTakeWhileIter.Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
begin
  FSource := aSource;
  FPredicate := aPredicate;
  FData := aData;
  FDone := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TTakeWhileIter.Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TTakeWhileIter<T>;
begin
  Result.Init(aSource, aPredicate, aData);
end;

function TTakeWhileIter.MoveNext: Boolean;
begin
  if FDone then
    Exit(False);

  Result := FSource.MoveNext;
  if Result then
  begin
    FCurrent := FSource.Current;
    // Check predicate - if false, we're done
    if not FPredicate(FCurrent, FData) then
    begin
      FDone := True;
      Result := False;
    end;
  end;
end;

function TTakeWhileIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ TSkipWhileIter<T> }

procedure TSkipWhileIter.Init(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer);
begin
  FSource := aSource;
  FPredicate := aPredicate;
  FData := aData;
  FSkipping := True;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TSkipWhileIter.Create(const aSource: TSourceIter; aPredicate: TPredicateFunc; aData: Pointer): specialize TSkipWhileIter<T>;
begin
  Result.Init(aSource, aPredicate, aData);
end;

function TSkipWhileIter.MoveNext: Boolean;
begin
  // Skip elements while predicate is true
  while FSkipping do
  begin
    Result := FSource.MoveNext;
    if not Result then
      Exit(False);

    FCurrent := FSource.Current;
    if not FPredicate(FCurrent, FData) then
    begin
      FSkipping := False;
      Exit(True);
    end;
  end;

  // After skipping phase, just pass through
  Result := FSource.MoveNext;
  if Result then
    FCurrent := FSource.Current;
end;

function TSkipWhileIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ TFlattenIter<T> }

procedure TFlattenIter.Init(const aSource: TOuterIter);
begin
  FOuterIter := aSource;
  FHasInner := False;
  FillChar(FCurrent, SizeOf(FCurrent), 0);
end;

class function TFlattenIter.Create(const aSource: TOuterIter): specialize TFlattenIter<T>;
begin
  Result.Init(aSource);
end;

function TFlattenIter.MoveNext: Boolean;
var
  InnerVec: TInnerVec;
begin
  // Try to get next element from current inner iterator
  while True do
  begin
    if FHasInner then
    begin
      if FInnerIter.MoveNext then
      begin
        FCurrent := FInnerIter.Current;
        Exit(True);
      end;
      // Current inner exhausted, try next outer
      FHasInner := False;
    end;

    // Get next inner iterator from outer
    if not FOuterIter.MoveNext then
      Exit(False);

    InnerVec := FOuterIter.Current;
    if InnerVec <> nil then
    begin
      FInnerIter := InnerVec.Iter;
      FHasInner := True;
    end;
  end;
end;

function TFlattenIter.GetCurrent: T;
begin
  Result := FCurrent;
end;

{ Collect 收集器函数实现 }

generic function CollectToVec<T>(var aIter: specialize TIter<T>): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create;
  while aIter.MoveNext do
    Result.Push(aIter.Current);
end;

generic function CollectFilterToVec<T>(var aIter: specialize TFilterIter<T>): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create;
  while aIter.MoveNext do
    Result.Push(aIter.Current);
end;

generic function CollectTakeToVec<T>(var aIter: specialize TTakeIter<T>): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create;
  while aIter.MoveNext do
    Result.Push(aIter.Current);
end;

generic function CollectChainToVec<T>(var aIter: specialize TChainIter<T>): specialize IVec<T>;
begin
  Result := specialize TVec<T>.Create;
  while aIter.MoveNext do
    Result.Push(aIter.Current);
end;

{ 终结组合子实现 }

generic function IterFold<T, TAcc>(var aIter: specialize TIter<T>;
  const aInit: TAcc;
  aFolder: specialize TFolderFunc<T, TAcc>;
  aData: Pointer): TAcc;
begin
  Result := aInit;
  while aIter.MoveNext do
    Result := aFolder(Result, aIter.Current, aData);
end;

generic function IterReduce<T>(var aIter: specialize TIter<T>;
  aReducer: specialize TReducerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;
begin
  // 第一个元素作为初始值
  if not aIter.MoveNext then
    Exit(False);

  aResult := aIter.Current;
  while aIter.MoveNext do
    aResult := aReducer(aResult, aIter.Current, aData);
  Result := True;
end;

generic function IterFind<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;
begin
  while aIter.MoveNext do
  begin
    if aPredicate(aIter.Current, aData) then
    begin
      aResult := aIter.Current;
      Exit(True);
    end;
  end;
  Result := False;
end;

generic function IterAny<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): Boolean;
begin
  while aIter.MoveNext do
  begin
    if aPredicate(aIter.Current, aData) then
      Exit(True);
  end;
  Result := False;
end;

generic function IterAll<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): Boolean;
begin
  while aIter.MoveNext do
  begin
    if not aPredicate(aIter.Current, aData) then
      Exit(False);
  end;
  Result := True;  // 空迭代器返回 True
end;

generic procedure IterForEach<T>(var aIter: specialize TIter<T>;
  aAction: specialize TActionFunc<T>;
  aData: Pointer);
begin
  while aIter.MoveNext do
    aAction(aIter.Current, aData);
end;

generic function IterCount<T>(var aIter: specialize TIter<T>): SizeUInt;
begin
  Result := 0;
  while aIter.MoveNext do
    Inc(Result);
end;

generic function IterCountIf<T>(var aIter: specialize TIter<T>;
  aPredicate: specialize TIterPredicateFunc<T>;
  aData: Pointer): SizeUInt;
begin
  Result := 0;
  while aIter.MoveNext do
  begin
    if aPredicate(aIter.Current, aData) then
      Inc(Result);
  end;
end;

function IterSumInt(var aIter: specialize TIter<Integer>): Int64;
begin
  Result := 0;
  while aIter.MoveNext do
    Inc(Result, aIter.Current);
end;

function IterSumInt64(var aIter: specialize TIter<Int64>): Int64;
begin
  Result := 0;
  while aIter.MoveNext do
    Inc(Result, aIter.Current);
end;

generic function IterMin<T>(var aIter: specialize TIter<T>;
  aComparer: specialize TComparerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;
begin
  if not aIter.MoveNext then
    Exit(False);

  aResult := aIter.Current;
  while aIter.MoveNext do
  begin
    if aComparer(aIter.Current, aResult, aData) < 0 then
      aResult := aIter.Current;
  end;
  Result := True;
end;

generic function IterMax<T>(var aIter: specialize TIter<T>;
  aComparer: specialize TComparerFunc<T>;
  aData: Pointer;
  out aResult: T): Boolean;
begin
  if not aIter.MoveNext then
    Exit(False);

  aResult := aIter.Current;
  while aIter.MoveNext do
  begin
    if aComparer(aIter.Current, aResult, aData) > 0 then
      aResult := aIter.Current;
  end;
  Result := True;
end;

generic function IterNth<T>(var aIter: specialize TIter<T>;
  aIndex: SizeUInt;
  out aResult: T): Boolean;
var
  LCount: SizeUInt;
begin
  LCount := 0;
  while aIter.MoveNext do
  begin
    if LCount = aIndex then
    begin
      aResult := aIter.Current;
      Exit(True);
    end;
    Inc(LCount);
  end;
  Result := False;
end;

generic function IterLast<T>(var aIter: specialize TIter<T>;
  out aResult: T): Boolean;
begin
  Result := False;
  while aIter.MoveNext do
  begin
    aResult := aIter.Current;
    Result := True;
  end;
end;

end.
