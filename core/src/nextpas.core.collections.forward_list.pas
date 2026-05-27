unit nextpas.core.collections.forward_list;
{**
 * @desc IForwardList<T> 单向链表接口 - 基调与契约
 *
 * 角色与定位
 * - 面向头部插入/删除的轻量链表；顺序访问友好，随机访问非目标
 * - 与 TGenericCollection<T> 对齐：复用 Equals/Compare/Predicate 等算法约定
 *
 * 能力与语义
 * - 最小必需：Front/PushFront/PopFront
 * - 扩展能力：InsertAfter/EraseAfter/Remove/RemoveIf/Find/FindIf/Sort/Unique/Merge/Splice/Resize 等
 * - 无 Back/PushBack/PopBack（单向链表特性）
 * - Checked vs UnChecked：
 *   - Checked 负责参数/状态检查；空表 Pop/Front 抛出 EInvalidOperation
 *   - Try* 形式返回 False，不抛异常
 *   - UnChecked 不做检查，仅在必要处对零长度做 no-op
 *
 * 异常与安全
 * - 迭代期间修改：遵循具体实现文档，通常不保证并发安全
 * - 内存失败：抛出 EOutOfMemory
 *
 * 其他
 * - 不暴露容量/增长策略
 * - 与 TVec/VecDeque/IList 互补：单端频繁操作选 ForwardList；双端高性能选 VecDeque
 *}


{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, typinfo,
  nextpas.core.base,
  {$HINTS OFF}nextpas.core.math,{$HINTS ON}
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.forward_list.intf,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.node;

{$IFDEF DEBUG}
function FL_GetCtorDtorDelta: SizeInt;
function FL_GetCtorCount: SizeInt;
function FL_GetDtorCount: SizeInt;
{$ENDIF}
{$IFDEF DEBUG}
var
  G_FL_Create_Count: SizeInt = 0;
  G_FL_Destroy_Count: SizeInt = 0;
{$ENDIF}


type

  { TForwardList 单向链表实现 - 基于优化的 TSingleLinkedNode<T> }
  generic TForwardList<T> = class(specialize TGenericCollection<T>, specialize IForwardList<T>)
  public
    type
      TNodeManager = specialize TNodeManager<T>;
      PSingleNode = TNodeManager.PSingleNode;
      TSingleNode = TNodeManager.TSingleNode;

      // 向后兼容的类型别名
      PNode = PSingleNode;
      TNode = TSingleNode;

      { 新增的函数类型 }
      TActionFunc       = procedure(var aElement: T; aData: Pointer);
      {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
      TActionRefFunc    = reference to procedure(var aElement: T);
      {$ENDIF}
      TAccumulatorFunc  = function(const aAccumulated, aElement: T; aData: Pointer): T;
      {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
      TAccumulatorRefFunc = reference to function(const aAccumulated, aElement: T): T;
      {$ENDIF}

  private
    FNodeManager: TNodeManager;  // 节点管理器
    FHead:        PSingleNode;   // 头节点
    FLast:        PSingleNode;   // 尾节点（FCount>0 时非 nil）
    FCount:       SizeUInt;      // 元素数量

  { 内部节点管理 - 基于优化的 TNodeManager }
  private
    function  CreateNode(const aData: T; aNext: PSingleNode): PSingleNode; inline;
    procedure DestroyNode(aNode: PSingleNode); inline;

  { 迭代器回调 }
{ 参见迭代器最佳实践：docs/Iterator_BestPractices.md }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}
    function  DoIterMoveNext(aIter: PPtrIter): Boolean; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

  { 内部查找辅助方法 }
  private
    function  FindNodeBefore(const aElement: T; aProxy: TEqualsProxyMethod; aEquals, aData: Pointer): PSingleNode;
    function  FindNodeBeforeIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): PSingleNode;


  { 基类虚方法重写 }
  protected
    function  IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoFill(const aElement: T); override;
    procedure DoZero; override;
    procedure DoReverse; override;

    { 高级操作的辅助方法 }
    function  DoMergeSort(aHead: PNode; aCompare: TCompareFunc; aData: Pointer): PNode;
    function  DoMergeSortMethod(aHead: PNode; aCompare: TCompareMethod; aData: Pointer): PNode;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  DoMergeSortRefFunc(aHead: PNode; aCompare: TCompareRefFunc): PNode;
    {$ENDIF}
    function  DoMergeLists(aLeft, aRight: PNode; aCompare: TCompareFunc; aData: Pointer): PNode;
    function  DoMergeListsMethod(aLeft, aRight: PNode; aCompare: TCompareMethod; aData: Pointer): PNode;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  DoMergeListsRefFunc(aLeft, aRight: PNode; aCompare: TCompareRefFunc): PNode;
    {$ENDIF}
    function  DoSplitList(aHead: PNode): PNode;

  public
    constructor Create; overload;
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    constructor Create(const aSrc: array of T); overload;
    constructor Create(const aSrc: array of T; aAllocator: IAllocator); overload;
    constructor Create(const aSrc: array of T; aAllocator: IAllocator; aData: Pointer); overload;
    constructor Create(const aSrc: TCollection); overload;
    constructor Create(const aSrc: TCollection; aAllocator: IAllocator); overload;
    constructor Create(const aSrc: TCollection; aAllocator: IAllocator; aData: Pointer); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator); overload;
    constructor Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer); overload;

    destructor  Destroy; override;

    { ICollection 接口实现 }
    function  PtrIter: TPtrIter; override;
    function  GetCount: SizeUInt; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    { IGenericCollection<T> 接口实现 }
    procedure SaveToUnChecked(aDst: TCollection); override;
    function  ToArray: specialize TGenericArray<T>; override;

    { IForwardList<T> 接口实现 }
    procedure PushFront(const aElement: T); inline;
    function  PopFront: T; inline;
    function  TryPopFront(out aElement: T): Boolean; inline;
    function  Front: T; inline;
    function  TryFront(out aElement: T): Boolean; inline;


    // Non-throwing bulk ops (pointer overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;

    { 现代化构造方法 }
    procedure EmplaceFront(const aElement: T); inline;
    procedure EmplaceAfter(aPosition: TIter; const aElement: T);
    function  EmplaceAfterEx(aPosition: TIter; const aElement: T): TIter; inline;

    { 高性能方法（无安全检查版本）}
    procedure PushFrontUnChecked(const aElement: T); inline;
    function  PopFrontUnChecked: T; inline;
    procedure EmplaceFrontUnChecked(const aElement: T); inline;
    procedure PushFrontRangeUnChecked(const aArray: array of T);
    procedure ClearUnChecked;

    function  InsertAfter(aPosition: TIter; const aElement: T): TIter;
    function  InsertAfter(aPosition: TIter; aCount: SizeUInt; const aElement: T): TIter;
    function  InsertAfter(aPosition: TIter; const aArray: array of T): TIter;
    function  InsertAfter(aPosition: TIter; aFirst, aLast: TIter): TIter;
    function  EraseAfter(aPosition: TIter): TIter;
    function  EraseAfter(aPosition, aLast: TIter): TIter;

    function  Remove(const aElement: T): SizeUInt; overload;
    function  Remove(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): SizeUInt; overload;
    function  Remove(const aElement: T; aEquals: TEqualsMethod; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  Remove(const aElement: T; aEquals: TEqualsRefFunc): SizeUInt; overload;
    {$ENDIF}

    function  RemoveIf(aPredicate: TPredicateFunc; aData: Pointer): SizeUInt; overload;
    function  RemoveIf(aPredicate: TPredicateMethod; aData: Pointer): SizeUInt; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  RemoveIf(aPredicate: TPredicateRefFunc): SizeUInt; overload;
    {$ENDIF}

    function  Find(const aElement: T): TIter; overload;
    function  Find(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): TIter; overload;

    function  FindIf(aPredicate: TPredicateFunc; aData: Pointer): TIter; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  FindIf(aPredicate: TPredicateRefFunc): TIter; overload;
    {$ENDIF}

    { ForwardList 特有的高级操作 }
    procedure Sort; overload;
    procedure Sort(aCompare: TCompareFunc; aData: Pointer); overload;
    procedure Sort(aCompare: TCompareMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Sort(aCompare: TCompareRefFunc); overload;
    {$ENDIF}

    procedure Unique; overload;
    procedure Unique(aEquals: TEqualsFunc; aData: Pointer); overload;
    procedure Unique(aEquals: TEqualsMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Unique(aEquals: TEqualsRefFunc); overload;
    {$ENDIF}

    procedure Merge(var aOther: TForwardList); overload;
    procedure Merge(var aOther: TForwardList; aCompare: TCompareFunc; aData: Pointer); overload;
    procedure Merge(var aOther: TForwardList; aCompare: TCompareMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure Merge(var aOther: TForwardList; aCompare: TCompareRefFunc); overload;
    {$ENDIF}

    // Copy-based merge variants (do not steal nodes; keep aOther intact)
    procedure MergeCopy(const aOther: TForwardList); overload;
    procedure MergeCopy(const aOther: TForwardList; aCompare: TCompareFunc; aData: Pointer); overload;
    procedure MergeCopy(const aOther: TForwardList; aCompare: TCompareMethod; aData: Pointer); overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure MergeCopy(const aOther: TForwardList; aCompare: TCompareRefFunc); overload;
    {$ENDIF}

    procedure Splice(aPosition: TIter; var aOther: TForwardList); overload;
    procedure Splice(aPosition: TIter; var aOther: TForwardList; aFirst: TIter); overload;
    procedure Splice(aPosition: TIter; var aOther: TForwardList; aFirst, aLast: TIter); overload;

    { 便利方法 }
    function  Size: SizeUInt; inline;                    // STL 兼容的 size() 方法
    function  Empty: Boolean; inline;                    // STL 兼容的 empty() 方法
    procedure Push(const aElement: T); inline;           // 通用的 push 方法
    function  Pop: T; inline;                           // 通用的 pop 方法
    {$IFDEF DEBUG}
    function  DebugValidateTail: Boolean;
    function  DebugGetTailValue(out aValue: T): Boolean;
    {$ENDIF}
    function  Top: T; inline;                           // 栈风格的 top 方法
    function  Head: T; inline;                          // 链表风格的 head 方法

    procedure Assign(const aOther: TForwardList);        // 赋值操作
    procedure Assign(aFirst, aLast: TIter);              // 从范围赋值
    procedure Assign(aCount: SizeUInt; const aValue: T); // 赋值指定数量的相同值
    function  Clone: TCollection; override;             // 克隆操作（基类兼容）
    function  CloneForwardList: TForwardList;           // 类型安全的克隆操作
    function  Equal(const aOther: TForwardList): Boolean; overload; // 相等比较
    function  Equal(const aOther: TForwardList; aEquals: TEqualsFunc; aData: Pointer): Boolean; overload;

    procedure Resize(aNewSize: SizeUInt); overload;      // 调整大小
    procedure Resize(aNewSize: SizeUInt; const aFillValue: T); overload;

    function  BeforeBegin: TIter;                        // STL 兼容的 before_begin()
    function  CBegin: TIter; inline;                     // STL 兼容的 cbegin()
    function  CEnd: TIter; inline;                       // STL 兼容的 cend()

    { 高级功能 }
    function  MaxSize: SizeUInt;                         // 最大可能大小
    procedure Swap(var aOther: TForwardList);            // 交换两个链表

    function  All(aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload;  // 所有元素都满足条件
    function  Any(aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload;  // 任意元素满足条件
    function  None(aPredicate: TPredicateFunc; aData: Pointer): Boolean; overload; // 没有元素满足条件
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  All(aPredicate: TPredicateRefFunc): Boolean; overload;
    function  Any(aPredicate: TPredicateRefFunc): Boolean; overload;
    function  None(aPredicate: TPredicateRefFunc): Boolean; overload;
    {$ENDIF}

    procedure ForEach(aAction: TActionFunc; aData: Pointer); overload;             // 对每个元素执行操作
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    procedure ForEach(aAction: TActionRefFunc); overload;
    {$ENDIF}

    function  Accumulate(aInitial: T; aAccumulator: TAccumulatorFunc; aData: Pointer): T; overload; // 累积操作
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function  Accumulate(aInitial: T; aAccumulator: TAccumulatorRefFunc): T; overload;
    {$ENDIF}

    // Non-throwing bulk ops (collection overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: TCollection): Boolean;
    function  TryAppend(const aSrc: TCollection): Boolean;

  end;

implementation



{$IFDEF DEBUG}
function FL_GetCtorDtorDelta: SizeInt;
begin
  Result := G_FL_Create_Count - G_FL_Destroy_Count;
end;

function FL_GetCtorCount: SizeInt;
begin
  Result := G_FL_Create_Count;
end;

function FL_GetDtorCount: SizeInt;
begin
  Result := G_FL_Destroy_Count;
end;
{$ENDIF}

{ TForwardList<T> - 优化的节点管理 }

function TForwardList.CreateNode(const aData: T; aNext: PSingleNode): PSingleNode;
begin
  // 使用优化的节点管理器
  Result := FNodeManager.CreateSingleNode(aData, aNext);
end;

procedure TForwardList.DestroyNode(aNode: PSingleNode);
begin
  // 使用优化的节点管理器
  FNodeManager.DestroySingleNode(aNode);
end;

{ TForwardList<T> - 优化的迭代器回调 }

function TForwardList.DoIterGetCurrent(aIter: PPtrIter): Pointer;
var
  LNode: PSingleNode;
begin
  LNode := PSingleNode(aIter^.Data);
  if LNode = nil then
  begin
    // 未启动时，GetCurrent 返回头元素并同步迭代器状态
    if not aIter^.Started then
    begin
      if FHead = nil then
        raise EInvalidOperation.Create('TForwardList.DoIterGetCurrent: Empty list');

      aIter^.Started := True;
      aIter^.Data := FHead;
      LNode := FHead;
    end
    else
      raise EInvalidOperation.Create('TForwardList.DoIterGetCurrent: Invalid iterator position');
  end;

  Result := @(LNode^.Data);
end;

function TForwardList.DoIterMoveNext(aIter: PPtrIter): Boolean;
var
  LCurrentNode: PSingleNode;
begin
  if not aIter^.Started then
  begin
    // 第一次调用：如果已有定位(Data 指向某节点)，则从该节点开始；否则从头节点开始
    aIter^.Started := True;
    if aIter^.Data <> nil then
      Exit(True)
    else
    begin
      aIter^.Data := FHead;
      Exit(FHead <> nil);
    end;
  end
  else
  begin
    // 移动到下一个节点 - 使用优化的零开销方法
    LCurrentNode := PSingleNode(aIter^.Data);
    if LCurrentNode <> nil then
      aIter^.Data := LCurrentNode^.GetNext  // 零开销方法
    else
      aIter^.Data := nil;
  end;

  Result := aIter^.Data <> nil;
end;

{ TForwardList<T> - 基类虚方法重写 }

function TForwardList.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
var
  LCurrent: PSingleNode;
begin
  // 链表的内存是分散的，需要检查每个节点是否与源内存重叠
  Result := False;

  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if nextpas.core.mem.utils.IsOverlap(@LCurrent^.Data, FElementSizeCache,
                                       aSrc, aElementCount * FElementSizeCache) then
    begin
      Result := True;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

procedure TForwardList.DoFill(const aElement: T);
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LCurrent^.Data := aElement;
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

procedure TForwardList.DoZero;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if FElementManager.IsManagedType then
    begin
      // 先对托管类型执行反初始化，避免直接清零导致泄漏
      FElementManager.FinalizeManagedElements(@LCurrent^.Data, 1);
      // 反初始化后将存储清零以保证一致性
      FillChar(LCurrent^.Data, FElementSizeCache, 0);
    end
    else
    begin
      // 非托管类型直接清零
      FillChar(LCurrent^.Data, FElementSizeCache, 0);
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

procedure TForwardList.DoReverse;
var
  LPrev, LCurrent, LNext: PNode;
  LOldHead: PSingleNode;
begin
  if FCount <= 1 then
    Exit;

  LPrev := nil;
  LCurrent := FHead;
  LOldHead := FHead;

  while LCurrent <> nil do
  begin
    LNext := PNode(LCurrent^.Next);
    LCurrent^.Next := LPrev;
    LPrev := LCurrent;
    LCurrent := LNext;
  end;

  FHead := LPrev;
  // 反转后，新的尾节点是原来的头节点
  if FCount > 0 then
    FLast := LOldHead;
end;

{ TForwardList<T> - 构造函数和析构函数 }

constructor TForwardList.Create;
begin
  // Delegate initialization to the virtual constructor chain
  inherited Create;
  // Note: Base TCollection.Create will call Create(aAllocator, aData),
  // which is overridden below to perform actual initialization.
end;

constructor TForwardList.Create(aAllocator: IAllocator);
begin
  // Delegate to base; actual init happens in overridden Create(aAllocator, aData)
  inherited Create(aAllocator);
end;

constructor TForwardList.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  {$IFDEF DEBUG}Inc(G_FL_Create_Count);{$ENDIF}
  FNodeManager := TNodeManager.Create(FAllocator);
  FHead := nil;
  FLast := nil;
  FCount := 0;
end;

constructor TForwardList.Create(const aSrc: array of T);
begin
  Create;
  try
    LoadFrom(aSrc);
  except
    Free; // 确保在构造过程中异常时清理已分配资源
    raise;
  end;
end;

constructor TForwardList.Create(const aSrc: array of T; aAllocator: IAllocator);
begin
  Create(aAllocator);
  try
    LoadFrom(aSrc);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(const aSrc: array of T; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  try
    LoadFrom(aSrc);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(const aSrc: TCollection);
begin
  Create;
  try
    LoadFrom(aSrc);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(const aSrc: TCollection; aAllocator: IAllocator);
begin
  Create(aAllocator);
  try
    LoadFrom(aSrc);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(const aSrc: TCollection; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  try
    LoadFrom(aSrc);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(aSrc: Pointer; aElementCount: SizeUInt);
begin
  Create;
  try
    LoadFrom(aSrc, aElementCount);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator);
begin
  Create(aAllocator);
  try
    LoadFrom(aSrc, aElementCount);
  except
    Free;
    raise;
  end;
end;

constructor TForwardList.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  try
    LoadFrom(aSrc, aElementCount);
  except
    Free;
    raise;
  end;
end;

destructor TForwardList.Destroy;
begin
  // Ensure full cleanup order: clear elements, then node manager, then base
  Clear;
  FreeAndNil(FNodeManager);
  {$IFDEF DEBUG}Inc(G_FL_Destroy_Count);{$ENDIF}
  inherited Destroy;
end;

{ TForwardList<T> - ICollection 接口实现 }

function TForwardList.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, nil);
end;


function TForwardList.TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := inherited TryLoadFrom(aSrc, aElementCount);
end;

function TForwardList.TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := inherited TryAppend(aSrc, aElementCount);
end;

function TForwardList.GetCount: SizeUInt;
begin
  Result := FCount;
end;

procedure TForwardList.Clear;
var
  LCurrent, LNext: PSingleNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    // 使用节点的零开销 GetNext 方法，避免直接访问字段带来的别名与可读性问题
    LNext := PSingleNode(LCurrent^.GetNext);
    DestroyNode(LCurrent);
    LCurrent := LNext;
  end;

  FHead := nil;
  FLast := nil;
  FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Clear: tail invariant broken');
  {$ENDIF}
end;

procedure TForwardList.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LCurrent: PNode;
  LDstPtr: PByte;
  i: SizeUInt;
begin
  if (aDst = nil) and (aCount > 0) then
    raise EArgumentNil.Create('TForwardList.SerializeToArrayBuffer: aDst must not be nil');

  if aCount > FCount then
    raise EOutOfRange.Create('TForwardList.SerializeToArrayBuffer: aCount out of range');

  if aCount = 0 then
    Exit;

  // Overlap check: destination must not overlap any node storage
  if IsOverlap(aDst, aCount) then
    raise EInvalidArgument.Create('TForwardList.SerializeToArrayBuffer: destination memory overlaps with container');

  LDstPtr := PByte(aDst);
  LCurrent := FHead;
  i := 0;

  // For managed types, use element-wise assignment to preserve ref-count semantics
  if GetIsManagedType then
  begin
    while (LCurrent <> nil) and (i < aCount) do
    begin
      PElement(LDstPtr)^ := LCurrent^.Data;
      Inc(LDstPtr, FElementSizeCache);
      LCurrent := PNode(LCurrent^.Next);
      Inc(i);
    end;
  end
  else
  begin
    // For POD types, a raw Move per element is fine
    while (LCurrent <> nil) and (i < aCount) do
    begin
      Move(LCurrent^.Data, LDstPtr^, FElementSizeCache);
      Inc(LDstPtr, FElementSizeCache);
      LCurrent := PNode(LCurrent^.Next);
      Inc(i);
    end;
  end;
end;

procedure TForwardList.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LSrcPtr: PByte;
  i: SizeUInt;
  // LTail removed; not needed
  LNew: PNode;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LSrcPtr := PByte(aSrc);

  // 直接使用尾指针 O(1) 追加
  for i := 0 to aElementCount - 1 do
  begin
    LNew := CreateNode(PElement(LSrcPtr)^, nil);
    if FHead = nil then
    begin
      FHead := LNew;
      FLast := LNew;
    end
    else
    begin
      FLast^.Next := LNew;
      FLast := LNew;
    end;
    Inc(FCount);
    Inc(LSrcPtr, FElementSizeCache);
  end;
{$IFDEF DEBUG}
if not DebugValidateTail then
  raise EWow.Create('TForwardList.AppendUnChecked: tail invariant broken');
{$ENDIF}
end;

procedure TForwardList.AppendToUnChecked(const aDst: TCollection);
var
  LCount, LBufCap, LFill: SizeUInt;
  LBuf: array of T;
  LNode: PNode;
  LElemSize: SizeUInt;
begin
  // 流式追加：使用固定大小的缓冲区分批复制，避免一次性分配整表大小的数组
  // 语义：复制（不修改源链表），保持元素顺序
  LCount := FCount;

  // 选择缓冲区容量（约 32KB 的元素存储），至少 1，且不超过总元素数
  LElemSize := FElementSizeCache;
  if LElemSize = 0 then
    LBufCap := LCount
  else
  begin
    LBufCap := 32768 div LElemSize;
    if LBufCap = 0 then LBufCap := 1;
    if LBufCap > LCount then LBufCap := LCount;
  end;

  SetLength(LBuf, LBufCap);

  // 逐节点收集到缓冲区，满批则提交到 aDst
  LNode := FHead;
  LFill := 0;
  while LNode <> nil do
  begin
    LBuf[LFill] := LNode^.Data;
    Inc(LFill);

    if LFill = LBufCap then
    begin
      aDst.AppendUnChecked(@LBuf[0], LFill);
      LFill := 0;
    end;

    LNode := PNode(LNode^.Next);
  end;

  // 处理最后一批
  if LFill > 0 then
    aDst.AppendUnChecked(@LBuf[0], LFill);
end;

{ TForwardList<T> - IGenericCollection<T> 接口实现 }

procedure TForwardList.SaveToUnChecked(aDst: TCollection);
begin
  aDst.Clear;
  AppendToUnChecked(aDst);
end;

function TForwardList.ToArray: specialize TGenericArray<T>;
var
  LCurrent: PNode;
  i: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);
  if FCount = 0 then
    Exit;

  LCurrent := FHead;
  i := 0;
  while LCurrent <> nil do
  begin
    Result[i] := LCurrent^.Data;
    Inc(i);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

function TForwardList.TryLoadFrom(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryLoadFrom(aSrc);
end;

function TForwardList.TryAppend(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryAppend(aSrc);
end;

{ TForwardList<T> - IForwardList<T> 接口实现 }

procedure TForwardList.PushFront(const aElement: T);
var
  LNewNode: PSingleNode;
begin
  LNewNode := CreateNode(aElement, FHead);
  FHead := LNewNode;
  Inc(FCount);
  if FCount = 1 then
    FLast := FHead;
end;

procedure TForwardList.PushFrontUnChecked(const aElement: T);
var
  LNewNode: PSingleNode;
begin
  // 无检查版本：直接创建节点，跳过所有验证
  LNewNode := FNodeManager.CreateSingleNode(aElement, FHead);
  FHead := LNewNode;
  Inc(FCount);
  if FCount = 1 then
    FLast := FHead;
end;

function TForwardList.PopFront: T;
var
  LOldHead: PSingleNode;
begin
  if FHead = nil then
    raise EEmptyCollection.Create('TForwardList.PopFront: empty forward_list');

  LOldHead := FHead;
  Result := LOldHead^.Data;
  FHead := PSingleNode(LOldHead^.GetNext);
  DestroyNode(LOldHead);
  Dec(FCount);
  if FHead = nil then
    FLast := nil;
end;

function TForwardList.PopFrontUnChecked: T;
var
  LOldHead: PSingleNode;
begin
  // 无检查版本：跳过空链表检查，调用者必须确保链表非空
  LOldHead := FHead;
  Result := LOldHead^.Data;
  FHead := PSingleNode(LOldHead^.GetNext);
  FNodeManager.DestroySingleNode(LOldHead);
  Dec(FCount);
  if FHead = nil then
    FLast := nil;
end;

function TForwardList.TryPopFront(out aElement: T): Boolean;
var
  LOldHead: PSingleNode;
begin
  LOldHead := FHead;
  Result := LOldHead <> nil;
  if not Result then Exit;
  aElement := LOldHead^.Data;
  FHead := PSingleNode(LOldHead^.GetNext);
  DestroyNode(LOldHead);
  Dec(FCount);
  if FHead = nil then
    FLast := nil;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.TryPopFront: tail invariant broken');
  {$ENDIF}
end;

function TForwardList.Front: T;
begin
  if FHead = nil then
    raise EEmptyCollection.Create('TForwardList.Front: empty forward_list');

  Result := FHead^.Data;
end;

function TForwardList.TryFront(out aElement: T): Boolean;
begin
  Result := FHead <> nil;
  if Result then
    aElement := FHead^.Data;
end;

function TForwardList.InsertAfter(aPosition: TIter; const aElement: T): TIter;
var
  LPositionNode, LNewNode: PNode;
begin
  // 验证迭代器是否属于此链表
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.InsertAfter: Iterator does not belong to this list');

  // before_begin (Data=nil, Started=False): insert at head
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    LNewNode := CreateNode(aElement, FHead);
    FHead := LNewNode;
    Inc(FCount);
    if FCount = 1 then FLast := FHead;

    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := LNewNode;
    Exit;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    // end() is invalid for insert_after
    raise EInvalidArgument.Create('TForwardList.InsertAfter: Invalid iterator position (end)');
  end;

  LPositionNode := PNode(aPosition.PtrIter.Data);

  // insert after the given node
  LNewNode := CreateNode(aElement, LPositionNode^.Next);
  LPositionNode^.Next := LNewNode;
  Inc(FCount);
  if LNewNode^.Next = nil then FLast := LNewNode;

  // 返回指向新插入元素的迭代器
  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LNewNode;
end;

function TForwardList.InsertAfter(aPosition: TIter; aCount: SizeUInt; const aElement: T): TIter;
var
  LPositionNode, LNewNode, LLastNode: PNode;
  LChainHead, LChainTail: PNode;
  i: SizeUInt;
  LTotal: SizeUInt;
begin
  // 验证迭代器
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.InsertAfter: Iterator does not belong to this list');

  // 记录原始请求数量
  LTotal := aCount;

  // before_begin (Data=nil, Started=False) => insert at head
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    if aCount = 0 then
    begin
      Result := aPosition;
      Exit;
    end;
    // Build a chain [LChainHead..LChainTail] with length aCount
    LChainHead := CreateNode(aElement, nil);
    LChainTail := LChainHead;
    for i := 2 to aCount do
    begin
      LNewNode := CreateNode(aElement, nil);
      LChainTail^.Next := LNewNode;
      LChainTail := LNewNode;
    end;
    // Prepend the chain to current list
    LChainTail^.Next := FHead;
    // If list was empty, new tail is chainTail
    if FCount = 0 then FLast := LChainTail;
    FHead := LChainHead;
    Inc(FCount, LTotal);

    Result.Init(aPosition.PtrIter);
    // Return iterator to last inserted element (closest to old head)
    Result.PtrIter.Data := LChainTail;
    Exit;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.InsertAfter(count): Invalid iterator position (end)');
  end;

  // Normal insert after LPositionNode
  LPositionNode := PNode(aPosition.PtrIter.Data);
  if aCount = 0 then
  begin
    Result := aPosition;
    Exit;
  end;

  // Create first node after position
  LNewNode := CreateNode(aElement, LPositionNode^.Next);
  LPositionNode^.Next := LNewNode;
  LLastNode := LNewNode;

  // Create remaining (aCount-1) nodes immediately after the previous new node
  for i := 2 to aCount do
  begin
    LNewNode := CreateNode(aElement, LLastNode^.Next);
    LLastNode^.Next := LNewNode;
    LLastNode := LNewNode;
  end;

  Inc(FCount, LTotal);
  if LLastNode^.Next = nil then FLast := LLastNode;

  // 返回指向最后插入元素的迭代器
  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LLastNode;
end;

function TForwardList.InsertAfter(aPosition: TIter; const aArray: array of T): TIter;
var
  LPositionNode, LNewNode, LLastNode: PNode;
  LChainHead, LChainTail: PNode;
  i: Integer;
begin
  // 验证迭代器
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.InsertAfter: Iterator does not belong to this list');

  // before_begin (Data=nil, Started=False)
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    if Length(aArray) = 0 then
    begin
      Result := aPosition;
      Exit;
    end;
    // Build chain from array and prepend to head preserving order
    LChainHead := CreateNode(aArray[Low(aArray)], nil);
    LChainTail := LChainHead;
    for i := Low(aArray)+1 to High(aArray) do
    begin
      LNewNode := CreateNode(aArray[i], nil);
      LChainTail^.Next := LNewNode;
      LChainTail := LNewNode;
    end;
    LChainTail^.Next := FHead;
    if FCount = 0 then FLast := LChainTail;
    FHead := LChainHead;
    Inc(FCount, Length(aArray));

    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := LChainTail; // last inserted (closest to old head)
    Exit;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.InsertAfter(array): Invalid iterator position (end)');
  end;

  // Normal insert after given node
  LPositionNode := PNode(aPosition.PtrIter.Data);

  if Length(aArray) = 0 then
  begin
    Result := aPosition;
    Exit;
  end;

  // First element after position
  LNewNode := CreateNode(aArray[Low(aArray)], LPositionNode^.Next);
  LPositionNode^.Next := LNewNode;
  LLastNode := LNewNode;

  for i := Low(aArray)+1 to High(aArray) do
  begin
    LNewNode := CreateNode(aArray[i], LLastNode^.Next);
    LLastNode^.Next := LNewNode;
    LLastNode := LNewNode;
  end;

  Inc(FCount, Length(aArray));
  if LLastNode^.Next = nil then FLast := LLastNode;

  // 返回指向最后插入元素的迭代器
  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LLastNode;
end;

function TForwardList.InsertAfter(aPosition: TIter; aFirst, aLast: TIter): TIter;
var
  LPositionNode, LNewNode, LLastNew: PSingleNode;
  LSrc: TForwardList;
  LStart, LEnd, LCur: PSingleNode;
  LInsertCount: SizeUInt;
begin
  // 验证迭代器归属
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.InsertAfter: Iterator does not belong to this list');

  // Parse position node (supports before_begin)
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    // before_begin: inserting a copy range at head
    LPositionNode := nil; // special marker to prepend after building first node
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.InsertAfter(range): Invalid iterator position (end)');
  end
  else
    LPositionNode := PSingleNode(aPosition.PtrIter.Data);

  // 解析源范围：[aFirst, aLast) 包含 aFirst 当前元素，不包含 aLast
  LSrc := TForwardList(aFirst.PtrIter.Owner);
  if LSrc = nil then
  begin
    Result := aPosition;
    Exit;
  end;

  if aFirst.PtrIter.Data <> nil then
    LStart := PSingleNode(aFirst.PtrIter.Data)
  else if not aFirst.PtrIter.Started then
    LStart := LSrc.FHead
  else
    LStart := nil; // 已启动且Data=nil，表示end

  if aLast.PtrIter.Data <> nil then
    LEnd := PSingleNode(aLast.PtrIter.Data)
  else
    LEnd := nil; // 直到末尾

  if (LStart = nil) or (LStart = LEnd) then
  begin
    Result := aPosition;
    Exit;
  end;

  // 插入第一个节点
  if LPositionNode = nil then
  begin
    // prepend at head
    LNewNode := CreateNode(LStart^.Data, FHead);
    FHead := LNewNode;
  end
  else
  begin
    LNewNode := CreateNode(LStart^.Data, PSingleNode(LPositionNode^.GetNext));
    LPositionNode^.SetNext(LNewNode);
  end;
  LLastNew := LNewNode;
  LInsertCount := 1;

  // 复制剩余节点直到 LEnd（不含）
  LCur := PSingleNode(LStart^.GetNext);
  while (LCur <> nil) and (LCur <> LEnd) do
  begin
    LNewNode := CreateNode(LCur^.Data, PSingleNode(LLastNew^.GetNext));
    LLastNew^.SetNext(LNewNode);
    LLastNew := LNewNode;
    Inc(LInsertCount);
    LCur := PSingleNode(LCur^.GetNext);
  end;

  Inc(FCount, LInsertCount);

  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LLastNew;
end;

function TForwardList.EraseAfter(aPosition: TIter): TIter;
var
  LPositionNode, LNodeToErase: PNode;
begin
  // 验证迭代器是否属于此链表
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.EraseAfter: Iterator does not belong to this list');

  // before_begin: 删除 head（空表则 no-op）
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    if FHead = nil then
    begin
      // 空表：不改变，返回 end()
      Result.Init(aPosition.PtrIter);
      Result.PtrIter.Data := nil;
      Exit;
    end;
    // 非空：删除 head
    LNodeToErase := FHead;
    FHead := PNode(LNodeToErase^.Next);
    if FHead = nil then FLast := nil;
    DestroyNode(LNodeToErase);
    Dec(FCount);

    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := FHead; // 指向被删后新的头
    Exit;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.EraseAfter: Invalid iterator position (end)');
  end;

  // 正常路径：删除 position 之后的一个
  LPositionNode := PNode(aPosition.PtrIter.Data);
  if LPositionNode = nil then
    raise EInvalidArgument.Create('TForwardList.EraseAfter: Invalid iterator position');

  LNodeToErase := PNode(LPositionNode^.Next);
  if LNodeToErase = nil then
    raise EInvalidOperation.Create('TForwardList.EraseAfter: No element to erase after position');

  LPositionNode^.Next := LNodeToErase^.Next;
  if LNodeToErase = FLast then
    FLast := LPositionNode;
  DestroyNode(LNodeToErase);
  Dec(FCount);

  // 返回指向被移除元素之后元素的迭代器
  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LPositionNode^.Next;
end;

function TForwardList.EraseAfter(aPosition, aLast: TIter): TIter;
var
  LPositionNode: PSingleNode;
  LCurrentNode, LNextNode: PSingleNode;
  LEraseCount: SizeUInt;
  {$IFDEF FAFAFA_CORE_STRICT_ERASEAFTER}
  LProbe, LTarget: PSingleNode;
  LReachable: Boolean;
  {$ENDIF}
begin
  // 验证迭代器
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.EraseAfter: Iterator does not belong to this list');


  // 支持未启动且Data=nil -> 当前位置 = 头节点
  if aPosition.PtrIter.Data = nil then
  begin
    if not aPosition.PtrIter.Started then
      LPositionNode := FHead
    else
      raise EInvalidArgument.Create('TForwardList.EraseAfter: Invalid iterator position');
  end
  else
    LPositionNode := PSingleNode(aPosition.PtrIter.Data);

  // Debug: aLast 可达性检查（仅当 aLast 指向某节点时才检查）
  {$IFDEF FAFAFA_CORE_STRICT_ERASEAFTER}
  if aLast.PtrIter.Data <> nil then
  begin
    LProbe := PSingleNode(LPositionNode^.GetNext);
    LTarget := PSingleNode(aLast.PtrIter.Data);
    LReachable := False;
    while LProbe <> nil do
    begin
      if LProbe = LTarget then
      begin
        LReachable := True;
        Break;
      end;
      LProbe := PSingleNode(LProbe^.GetNext);
    end;
    if not LReachable then
      raise EInvalidOperation.Create('TForwardList.EraseAfter(STRICT): aLast is not reachable');
  end;
  {$ENDIF}

  // before_begin: erase head
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    if FHead = nil then
    begin
      Result.Init(aPosition.PtrIter);
      Result.PtrIter.Data := nil;
      Exit;
    end;
    LCurrentNode := FHead;
    FHead := PSingleNode(LCurrentNode^.Next);
    if FHead = nil then FLast := nil;
    DestroyNode(LCurrentNode);
    Dec(FCount);

    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := FHead; // iterator to element after erased head
    Exit;
  end;

  LCurrentNode := PSingleNode(LPositionNode^.GetNext);
  if LCurrentNode = nil then
  begin
    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := nil;
    Exit;
  end;

  LEraseCount := 0;
  while (LCurrentNode <> nil) and ((aLast.PtrIter.Data = nil) or (LCurrentNode <> PSingleNode(aLast.PtrIter.Data))) do
  begin
    LNextNode := PSingleNode(LCurrentNode^.GetNext);
    DestroyNode(LCurrentNode);
    Inc(LEraseCount);
    LCurrentNode := LNextNode;
  end;

  LPositionNode^.SetNext(LCurrentNode);
  if LCurrentNode = nil then
    FLast := LPositionNode;
  Dec(FCount, LEraseCount);

  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LCurrentNode;
end;

{ TForwardList<T> - 内部查找辅助方法 }

function TForwardList.FindNodeBefore(const aElement: T; aProxy: TEqualsProxyMethod; aEquals, aData: Pointer): PNode;
var
  LCurrent: PNode;
begin
  Result := nil;

  // 检查头节点
  if (FHead <> nil) and aProxy(aEquals, aElement, FHead^.Data, aData) then
    Exit; // 头节点匹配，返回 nil 表示没有前驱节点

  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.Next <> nil) do
  begin
    if aProxy(aEquals, aElement, PNode(LCurrent^.Next)^.Data, aData) then
    begin
      Result := LCurrent;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

function TForwardList.FindNodeBeforeIf(aProxy: TPredicateProxyMethod; aPredicate, aData: Pointer): PNode;
var
  LCurrent: PNode;
begin
  Result := nil;

  // 检查头节点
  if (FHead <> nil) and aProxy(aPredicate, FHead^.Data, aData) then
    Exit; // 头节点匹配，返回 nil 表示没有前驱节点

  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.Next <> nil) do
  begin
    if aProxy(aPredicate, PNode(LCurrent^.Next)^.Data, aData) then
    begin
      Result := LCurrent;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
end;



{ TForwardList<T> - Remove 方法实现 }

function TForwardList.Remove(const aElement: T): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and FInternalEquals(aElement, FHead^.Data) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  // 若全部移除为空，维护尾指针并返回
  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if FInternalEquals(aElement, LCurrent^.Data) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  // 循环结束时，LPrev 即为最后一个保留节点
  if FHead <> nil then
    FLast := LPrev;
end;

function TForwardList.Remove(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aEquals(aElement, FHead^.Data, aData) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aEquals(aElement, LCurrent^.Data, aData) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev;
end;

function TForwardList.Remove(const aElement: T; aEquals: TEqualsMethod; aData: Pointer): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aEquals(aElement, FHead^.Data, aData) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aEquals(aElement, LCurrent^.Data, aData) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.Remove(const aElement: T; aEquals: TEqualsRefFunc): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aEquals(aElement, FHead^.Data) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aEquals(aElement, LCurrent^.Data) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev;
end;
{$ENDIF}

function TForwardList.RemoveIf(aPredicate: TPredicateFunc; aData: Pointer): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aPredicate(FHead^.Data, aData) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aPredicate(LCurrent^.Data, aData) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev;
end;

function TForwardList.RemoveIf(aPredicate: TPredicateMethod; aData: Pointer): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aPredicate(FHead^.Data, aData) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;

  if FHead = nil then
  begin
    FLast := nil;
    Exit;
  end;

  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aPredicate(LCurrent^.Data, aData) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev
  else
    FLast := nil;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.RemoveIf(aPredicate: TPredicateRefFunc): SizeUInt;
var
  LPrev, LCurrent: PNode;
begin
  Result := 0;

  // 处理头节点
  while (FHead <> nil) and aPredicate(FHead^.Data) do
  begin
    LCurrent := FHead;
    FHead := PNode(FHead^.Next);
    DestroyNode(LCurrent);
    Dec(FCount);
    Inc(Result);
  end;
  if FHead = nil then begin FLast := nil; Exit; end;


  // 处理其余节点
  LPrev := FHead;
  while (LPrev <> nil) and (LPrev^.Next <> nil) do
  begin
    LCurrent := PNode(LPrev^.Next);
    if aPredicate(LCurrent^.Data) then
    begin
      LPrev^.Next := LCurrent^.Next;
      DestroyNode(LCurrent);
      Dec(FCount);
      Inc(Result);
    end
    else
      LPrev := LCurrent;
  end;
  if FHead <> nil then
    FLast := LPrev
  else
    FLast := nil;
end;
{$ENDIF}

{ TForwardList<T> - Find 方法实现 }

function TForwardList.Find(const aElement: T): TIter;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if FInternalEquals(aElement, LCurrent^.Data) then
    begin
      Result.Init(PtrIter);
      Result.PtrIter.Data := LCurrent;
      // 返回迭代器应使首次 MoveNext 指向当前元素，故保持 Started=False
      Result.PtrIter.Started := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 未找到，返回 end 迭代器
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;
  Result.PtrIter.Started := True;
end;

function TForwardList.Find(const aElement: T; aEquals: TEqualsFunc; aData: Pointer): TIter;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    // 默认等价器
    if Assigned(aEquals) then
    begin
      if aEquals(aElement, LCurrent^.Data, aData) then
      begin
        Result.Init(PtrIter);
        Result.PtrIter.Data := LCurrent;
        // 使调用方在 MoveNext 后获取到当前匹配元素
        Result.PtrIter.Started := False;
        Exit;
      end;
    end
    else if FInternalEquals(aElement, LCurrent^.Data) then
    begin
      Result.Init(PtrIter);
      Result.PtrIter.Data := LCurrent;
      // 统一：Find 返回的迭代器保持 Started=False，使首次 MoveNext 命中当前元素
      Result.PtrIter.Started := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 未找到，返回 end 迭代器
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;
  Result.PtrIter.Started := True;
end;

function TForwardList.FindIf(aPredicate: TPredicateFunc; aData: Pointer): TIter;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if aPredicate(LCurrent^.Data, aData) then
    begin
      Result.Init(PtrIter);
      Result.PtrIter.Data := LCurrent;
      // 使首次 MoveNext 呈现当前元素
      Result.PtrIter.Started := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 未找到，返回 end 迭代器
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;
  Result.PtrIter.Started := True;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.FindIf(aPredicate: TPredicateRefFunc): TIter;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if aPredicate(LCurrent^.Data) then
    begin
      Result.Init(PtrIter);
      Result.PtrIter.Data := LCurrent;
      // 使首次 MoveNext 呈现当前元素
      Result.PtrIter.Started := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 未找到，返回 end 迭代器
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;
  Result.PtrIter.Started := True;
end;
{$ENDIF}

{ ForwardList 高级操作的辅助方法 }

function TForwardList.DoSplitList(aHead: PNode): PNode;
var
  LFast, LSlow, LPrev: PNode;
begin
  if (aHead = nil) or (aHead^.Next = nil) then
  begin
    Result := nil;
    Exit;
  end;

  LSlow := aHead;
  LFast := aHead;
  LPrev := nil;

  // 使用快慢指针找到中点
  while (LFast <> nil) and (LFast^.GetNext <> nil) do
  begin
    LPrev := LSlow;
    LSlow := PSingleNode(LSlow^.GetNext);
    LFast := PSingleNode(PSingleNode(LFast^.GetNext)^.GetNext);
  end;

  // 分割链表
  LPrev^.SetNext(nil);
  Result := LSlow;
end;

function TForwardList.DoMergeLists(aLeft, aRight: PNode; aCompare: TCompareFunc; aData: Pointer): PNode;
var
  LDummy: TNode;
  LCurrent: PNode;
begin
  LDummy.Next := nil;
  LCurrent := @LDummy;

  while (aLeft <> nil) and (aRight <> nil) do
  begin
    if (aCompare <> nil) then
    begin
      if aCompare(aLeft^.Data, aRight^.Data, aData) <= 0 then
      begin
        LCurrent^.Next := aLeft;
        aLeft := PNode(aLeft^.Next);
      end
      else
      begin
        LCurrent^.Next := aRight;
        aRight := PNode(aRight^.Next);
      end;
    end
    else
    begin
      if FInternalComparer(aLeft^.Data, aRight^.Data) <= 0 then
      begin
        LCurrent^.Next := aLeft;
        aLeft := PNode(aLeft^.Next);
      end
      else
      begin
        LCurrent^.Next := aRight;
        aRight := PNode(aRight^.Next);
      end;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  if aLeft <> nil then
    LCurrent^.Next := aLeft
  else
    LCurrent^.Next := aRight;

  Result := PNode(LDummy.Next);
end;

function TForwardList.DoMergeListsMethod(aLeft, aRight: PNode; aCompare: TCompareMethod; aData: Pointer): PNode;
var
  LDummy: TNode;
  LCurrent: PNode;
begin
  LDummy.Next := nil;
  LCurrent := @LDummy;

  while (aLeft <> nil) and (aRight <> nil) do
  begin
    if aCompare(aLeft^.Data, aRight^.Data, aData) <= 0 then
    begin
      LCurrent^.Next := aLeft;
      aLeft := PNode(aLeft^.Next);
    end
    else
    begin
      LCurrent^.Next := aRight;
      aRight := PNode(aRight^.Next);
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 连接剩余部分
  if aLeft <> nil then
    LCurrent^.Next := aLeft
  else
    LCurrent^.Next := aRight;

  Result := PNode(LDummy.Next);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.DoMergeListsRefFunc(aLeft, aRight: PNode; aCompare: TCompareRefFunc): PNode;
var
  LDummy: TNode;
  LCurrent: PNode;
begin
  LDummy.Next := nil;
  LCurrent := @LDummy;

  while (aLeft <> nil) and (aRight <> nil) do
  begin
    if aCompare(aLeft^.Data, aRight^.Data) <= 0 then
    begin
      LCurrent^.Next := aLeft;
      aLeft := PNode(aLeft^.Next);
    end
    else
    begin
      LCurrent^.Next := aRight;
      aRight := PNode(aRight^.Next);
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 连接剩余部分
  if aLeft <> nil then
    LCurrent^.Next := aLeft
  else
    LCurrent^.Next := aRight;

  Result := PNode(LDummy.Next);
end;
{$ENDIF}

function TForwardList.DoMergeSort(aHead: PNode; aCompare: TCompareFunc; aData: Pointer): PNode;
var
  LRight: PNode;
begin
  if (aHead = nil) or (aHead^.Next = nil) then
  begin
    Result := aHead;
    Exit;
  end;

  // 分割链表
  LRight := DoSplitList(aHead);

  // 递归排序
  aHead := DoMergeSort(aHead, aCompare, aData);
  LRight := DoMergeSort(LRight, aCompare, aData);

  // 合并结果
  Result := DoMergeLists(aHead, LRight, aCompare, aData);
end;

function TForwardList.DoMergeSortMethod(aHead: PNode; aCompare: TCompareMethod; aData: Pointer): PNode;
var
  LRight: PNode;
begin
  if (aHead = nil) or (aHead^.Next = nil) then
  begin
    Result := aHead;
    Exit;
  end;

  // 分割链表
  LRight := DoSplitList(aHead);

  // 递归排序
  aHead := DoMergeSortMethod(aHead, aCompare, aData);
  LRight := DoMergeSortMethod(LRight, aCompare, aData);

  // 合并结果
  Result := DoMergeListsMethod(aHead, LRight, aCompare, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.DoMergeSortRefFunc(aHead: PNode; aCompare: TCompareRefFunc): PNode;
var
  LRight: PNode;
begin
  if (aHead = nil) or (aHead^.Next = nil) then
  begin
    Result := aHead;
    Exit;
  end;

  // 分割链表
  LRight := DoSplitList(aHead);

  // 递归排序
  aHead := DoMergeSortRefFunc(aHead, aCompare);
  LRight := DoMergeSortRefFunc(LRight, aCompare);


  // 合并结果
  Result := DoMergeListsRefFunc(aHead, LRight, aCompare);
end;
{$ENDIF}

{ ForwardList 高级操作实现 }

procedure TForwardList.Sort;
begin
  Sort(TCompareFunc(nil), nil);  // 使用默认比较
end;

procedure TForwardList.Sort(aCompare: TCompareFunc; aData: Pointer);
var
  L: PSingleNode;
begin
  if FCount <= 1 then
    Exit;

  // 直接调用，nil 比较器在 DoMergeLists/DoMergeSort 中处理
  FHead := DoMergeSort(FHead, aCompare, aData);
  // 排序重排后，更新尾指针（一次线性扫描，仍总体 O(n log n)）
  if FHead = nil then
    FLast := nil
  else
  begin
    L := FHead;
    while PNode(L^.Next) <> nil do L := PNode(L^.Next);
    FLast := L;
  end;
end;

procedure TForwardList.Sort(aCompare: TCompareMethod; aData: Pointer);
var
  L: PSingleNode;
begin
  if FCount <= 1 then
    Exit;

  FHead := DoMergeSortMethod(FHead, aCompare, aData);
  if FHead = nil then
    FLast := nil
  else
  begin
    L := FHead;
    while PNode(L^.Next) <> nil do L := PNode(L^.Next);
    FLast := L;
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TForwardList.Sort(aCompare: TCompareRefFunc);
var
  L: PSingleNode;
begin
  if FCount <= 1 then
    Exit;

  FHead := DoMergeSortRefFunc(FHead, aCompare);
  if FHead = nil then
    FLast := nil
  else
  begin
    L := FHead;
    while PNode(L^.Next) <> nil do L := PNode(L^.Next);
    FLast := L;
  end;
end;
{$ENDIF}

procedure TForwardList.Unique;
begin
  Unique(TEqualsFunc(nil), nil);  // 使用默认相等比较
end;

procedure TForwardList.Unique(aEquals: TEqualsFunc; aData: Pointer);
var
  LCurrent, LNext: PSingleNode;
begin
  if FCount <= 1 then
    Exit;

  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.Next <> nil) do
  begin
    LNext := PNode(LCurrent^.Next);

    if (aEquals <> nil) then
    begin
      if aEquals(LCurrent^.Data, LNext^.Data, aData) then
      begin
        LCurrent^.Next := LNext^.Next;
        DestroyNode(LNext);
        Dec(FCount);
      end
      else
        LCurrent := PNode(LCurrent^.Next);
    end
    else
    begin
      if FInternalEquals(LCurrent^.Data, LNext^.Data) then
      begin
        LCurrent^.Next := LNext^.Next;
        DestroyNode(LNext);
        Dec(FCount);
      end
      else
        LCurrent := PNode(LCurrent^.Next);
    end;
  end;
  // 刷新尾指针
  if FHead = nil then
    FLast := nil
  else
  begin
    LCurrent := FHead;
    while PNode(LCurrent^.Next) <> nil do
      LCurrent := PNode(LCurrent^.Next);
    FLast := LCurrent;
  end;
end;

procedure TForwardList.Unique(aEquals: TEqualsMethod; aData: Pointer);
var
  LCurrent, LNext: PNode;
begin
  if FCount <= 1 then
    Exit;

  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.Next <> nil) do
  begin
    LNext := PNode(LCurrent^.Next);

    // 检查是否相等
    if Assigned(aEquals) then
    begin
      if aEquals(LCurrent^.Data, LNext^.Data, aData) then
      begin
        // 移除重复元素
        LCurrent^.Next := LNext^.Next;
        DestroyNode(LNext);
        Dec(FCount);
      end
      else
        LCurrent := PNode(LCurrent^.Next);
    end
    else
    begin
      // 没有提供比较函数时，抛出异常
      raise EArgumentException.Create('For types without default equality, you must provide a comparer');
    end;
  end;
  // 刷新尾指针
  if FHead = nil then
    FLast := nil
  else
  begin
    LCurrent := FHead;
    while PNode(LCurrent^.Next) <> nil do
      LCurrent := PNode(LCurrent^.Next);
    FLast := LCurrent;
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TForwardList.Unique(aEquals: TEqualsRefFunc);
var
  LCurrent, LNext: PNode;
begin
  if FCount <= 1 then
    Exit;

  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.Next <> nil) do
  begin
    LNext := PNode(LCurrent^.Next);

    // 检查是否相等
    if Assigned(aEquals) then
    begin
      if aEquals(LCurrent^.Data, LNext^.Data) then
      begin
        // 移除重复元素
        LCurrent^.Next := LNext^.Next;
        DestroyNode(LNext);
        Dec(FCount);
      end
      else
        LCurrent := PNode(LCurrent^.Next);
    end
    else
    begin
      // 没有提供比较函数时，抛出异常
      raise EArgumentException.Create('For types without default equality, you must provide a comparer');
    end;
  end;
  // 刷新尾指针
  if FHead = nil then
    FLast := nil
  else
  begin
    LCurrent := FHead;
    while PNode(LCurrent^.Next) <> nil do
      LCurrent := PNode(LCurrent^.Next);
    FLast := LCurrent;
  end;
end;
{$ENDIF}

procedure TForwardList.Merge(var aOther: TForwardList);
begin
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Merge: self-merge is not supported');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Merge: allocator mismatch between lists');
  Merge(aOther, TCompareFunc(nil), nil);  // 使用默认比较
end;

procedure TForwardList.Merge(var aOther: TForwardList; aCompare: TCompareFunc; aData: Pointer);
var
  LDummy: TSingleNode;
  LCurrent: PSingleNode;
  LOtherCurrent: PSingleNode;
begin
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Merge: self-merge is not supported');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Merge: allocator mismatch between lists');
  if aOther.FCount = 0 then
    Exit;

  if FCount = 0 then
  begin
    FHead := aOther.FHead;
    FCount := aOther.FCount;
    FLast := aOther.FLast;
    aOther.FHead := nil;
    aOther.FLast := nil;
    aOther.FCount := 0;
    Exit;
  end;

  LDummy.Next := nil;
  LCurrent := @LDummy;
  LOtherCurrent := aOther.FHead;

  while (FHead <> nil) and (LOtherCurrent <> nil) do
  begin
    if (aCompare <> nil) then
    begin
      if aCompare(FHead^.Data, LOtherCurrent^.Data, aData) <= 0 then
      begin
        LCurrent^.Next := FHead;
        FHead := PNode(FHead^.Next);
      end
      else
      begin
        LCurrent^.Next := LOtherCurrent;
        LOtherCurrent := PNode(LOtherCurrent^.Next);
      end;
    end
    else
    begin
      if FInternalComparer(FHead^.Data, LOtherCurrent^.Data) <= 0 then
      begin
        LCurrent^.Next := FHead;
        FHead := PNode(FHead^.Next);
      end
      else
      begin
        LCurrent^.Next := LOtherCurrent;
        LOtherCurrent := PNode(LOtherCurrent^.Next);
      end;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  if FHead <> nil then
    LCurrent^.Next := FHead
  else
    LCurrent^.Next := LOtherCurrent;

  // update tail pointer FLast after merging
  while PNode(LCurrent^.Next) <> nil do
    LCurrent := PNode(LCurrent^.Next);

  FHead := PNode(LDummy.Next);
  FLast := LCurrent;
  FCount += aOther.FCount;

  aOther.FHead := nil;
  aOther.FLast := nil;
  aOther.FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Merge(func): tail invariant broken (self)');
  {$ENDIF}
end;

procedure TForwardList.Merge(var aOther: TForwardList; aCompare: TCompareMethod; aData: Pointer);
var
  LDummy: TNode;
  LCurrent: PNode;
  LOtherCurrent: PNode;
begin
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Merge: self-merge is not supported');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Merge: allocator mismatch between lists');
  if aOther.FCount = 0 then
    Exit;

  if FCount = 0 then
  begin
    FHead := aOther.FHead;
    FCount := aOther.FCount;
    FLast := aOther.FLast;
    aOther.FHead := nil;
    aOther.FLast := nil;
    aOther.FCount := 0;
    Exit;
  end;

  LDummy.Next := nil;
  LCurrent := @LDummy;
  LOtherCurrent := aOther.FHead;

  while (FHead <> nil) and (LOtherCurrent <> nil) do
  begin
    if aCompare(FHead^.Data, LOtherCurrent^.Data, aData) <= 0 then
    begin
      LCurrent^.Next := FHead;
      FHead := PNode(FHead^.Next);
    end
    else
    begin
      LCurrent^.Next := LOtherCurrent;
      LOtherCurrent := PNode(LOtherCurrent^.Next);
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 连接剩余部分
  if FHead <> nil then
    LCurrent^.Next := FHead
  else
    LCurrent^.Next := LOtherCurrent;

  // 更新尾指针
  while PNode(LCurrent^.Next) <> nil do
    LCurrent := PNode(LCurrent^.Next);

  FHead := PNode(LDummy.Next);
  FLast := LCurrent;
  FCount += aOther.FCount;

  // 清空源链表
  aOther.FHead := nil;
  aOther.FLast := nil;
  aOther.FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Merge(method): tail invariant broken (self)');
  {$ENDIF}
end;


  procedure TForwardList.MergeCopy(const aOther: TForwardList);
  begin
    MergeCopy(aOther, TCompareFunc(nil), nil);
  end;

  procedure TForwardList.MergeCopy(const aOther: TForwardList; aCompare: TCompareFunc; aData: Pointer);
  var
    LTmp: TForwardList;
    LI1, LI2: TIter;
    LVal1, LVal2: T;
    LHas1, LHas2: Boolean;
  begin
    if @aOther = @Self then
      raise EInvalidOperation.Create('TForwardList.MergeCopy: self-merge is not supported');

    // 快速路径：other 为空
    if aOther.FCount = 0 then Exit;

    // 构造一个与当前分配器一致的新表
    LTmp := TForwardList.Create(FAllocator);
    try
      // 归并拷贝（保持稳定性）；允许 aCompare=nil 使用内部比较器
      LI1 := Iter;  LHas1 := LI1.MoveNext;
      LI2 := aOther.Iter; LHas2 := LI2.MoveNext;
      while LHas1 and LHas2 do
      begin
        LVal1 := LI1.Current; LVal2 := LI2.Current;
        if (aCompare <> nil) then
        begin
          if aCompare(LVal1, LVal2, aData) <= 0 then
          begin LTmp.PushFront(LVal1); LHas1 := LI1.MoveNext; end
          else begin LTmp.PushFront(LVal2); LHas2 := LI2.MoveNext; end;
        end
        else
        begin
          if FInternalComparer(LVal1, LVal2) <= 0 then
          begin LTmp.PushFront(LVal1); LHas1 := LI1.MoveNext; end
          else begin LTmp.PushFront(LVal2); LHas2 := LI2.MoveNext; end;
        end;
      end;
      while LHas1 do begin LTmp.PushFront(LI1.Current); LHas1 := LI1.MoveNext; end;
      while LHas2 do begin LTmp.PushFront(LI2.Current); LHas2 := LI2.MoveNext; end;

      // LTmp 现在是逆序，反转为最终顺序
      LTmp.DoReverse;

      // 用 LTmp 替换 Self 内容
      Clear;
      // 偷 LTmp 的节点（同 allocator）
      FHead := LTmp.FHead; FLast := LTmp.FLast; FCount := LTmp.FCount;
      LTmp.FHead := nil; LTmp.FLast := nil; LTmp.FCount := 0;
    finally
      LTmp.Free;
    end;
  end;

  procedure TForwardList.MergeCopy(const aOther: TForwardList; aCompare: TCompareMethod; aData: Pointer);
  var
    LTmp: TForwardList;
    LI1, LI2: TIter;
    LVal1, LVal2: T;
    LHas1, LHas2: Boolean;
  begin
    if @aOther = @Self then
      raise EInvalidOperation.Create('TForwardList.MergeCopy: self-merge is not supported');

    if aOther.FCount = 0 then Exit;

    LTmp := TForwardList.Create(FAllocator);
    try
      LI1 := Iter;  LHas1 := LI1.MoveNext;
      LI2 := aOther.Iter; LHas2 := LI2.MoveNext;
      while LHas1 and LHas2 do
      begin
        LVal1 := LI1.Current; LVal2 := LI2.Current;
        if aCompare(LVal1, LVal2, aData) <= 0 then
        begin LTmp.PushFront(LVal1); LHas1 := LI1.MoveNext; end
        else begin LTmp.PushFront(LVal2); LHas2 := LI2.MoveNext; end;
      end;
      while LHas1 do begin LTmp.PushFront(LI1.Current); LHas1 := LI1.MoveNext; end;
      while LHas2 do begin LTmp.PushFront(LI2.Current); LHas2 := LI2.MoveNext; end;

      LTmp.DoReverse;

      Clear;
      FHead := LTmp.FHead; FLast := LTmp.FLast; FCount := LTmp.FCount;
      LTmp.FHead := nil; LTmp.FLast := nil; LTmp.FCount := 0;
    finally
      LTmp.Free;
    end;
  end;

  {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
  procedure TForwardList.MergeCopy(const aOther: TForwardList; aCompare: TCompareRefFunc);
  var
    LTmp: TForwardList;
    LI1, LI2: TIter;
    LVal1, LVal2: T;
    LHas1, LHas2: Boolean;
  begin
    if @aOther = @Self then
      raise EInvalidOperation.Create('TForwardList.MergeCopy: self-merge is not supported');

    if aOther.FCount = 0 then Exit;

    LTmp := TForwardList.Create(FAllocator);
    try
      LI1 := Iter;  LHas1 := LI1.MoveNext;
      LI2 := aOther.Iter; LHas2 := LI2.MoveNext;
      while LHas1 and LHas2 do
      begin
        LVal1 := LI1.Current; LVal2 := LI2.Current;
        if aCompare(LVal1, LVal2) <= 0 then
        begin LTmp.PushFront(LVal1); LHas1 := LI1.MoveNext; end
        else begin LTmp.PushFront(LVal2); LHas2 := LI2.MoveNext; end;
      end;
      while LHas1 do begin LTmp.PushFront(LI1.Current); LHas1 := LI1.MoveNext; end;
      while LHas2 do begin LTmp.PushFront(LI2.Current); LHas2 := LI2.MoveNext; end;

      LTmp.DoReverse;

      Clear;
      FHead := LTmp.FHead; FLast := LTmp.FLast; FCount := LTmp.FCount;
      LTmp.FHead := nil; LTmp.FLast := nil; LTmp.FCount := 0;
    finally
      LTmp.Free;
    end;
  end;
  {$ENDIF}

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TForwardList.Merge(var aOther: TForwardList; aCompare: TCompareRefFunc);
var
  LDummy: TNode;
  LCurrent: PNode;
  LOtherCurrent: PNode;
begin
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Merge: self-merge is not supported');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Merge: allocator mismatch between lists');
  if aOther.FCount = 0 then
    Exit;

  if FCount = 0 then
  begin
    FHead := aOther.FHead;
    FCount := aOther.FCount;
    FLast := aOther.FLast;
    aOther.FHead := nil;
    aOther.FLast := nil;
    aOther.FCount := 0;
    Exit;
  end;

  LDummy.Next := nil;
  LCurrent := @LDummy;
  LOtherCurrent := aOther.FHead;

  while (FHead <> nil) and (LOtherCurrent <> nil) do
  begin
    if aCompare(FHead^.Data, LOtherCurrent^.Data) <= 0 then
    begin
      LCurrent^.Next := FHead;
      FHead := PNode(FHead^.Next);
    end
    else
    begin
      LCurrent^.Next := LOtherCurrent;
      LOtherCurrent := PNode(LOtherCurrent^.Next);
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;

  // 连接剩余部分
  if FHead <> nil then
    LCurrent^.Next := FHead
  else
    LCurrent^.Next := LOtherCurrent;

  // 更新尾指针
  while PNode(LCurrent^.Next) <> nil do
    LCurrent := PNode(LCurrent^.Next);

  FHead := PNode(LDummy.Next);
  FLast := LCurrent;
  FCount += aOther.FCount;

  // 清空源链表
  aOther.FHead := nil;
  aOther.FLast := nil;
  aOther.FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Merge(ref): tail invariant broken (self)');
  {$ENDIF}
end;
{$ENDIF}

procedure TForwardList.Splice(aPosition: TIter; var aOther: TForwardList);
var
  LTail, LPosNode: PNode;
begin
  // 归属与自拼接校验
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.Splice: aPosition does not belong to this list');
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Splice: self-splice is not supported');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Splice: allocator mismatch between lists');

  // 优化实现：将整个 aOther 链表插入到 aPosition 之后
  if aOther.FCount = 0 then
    Exit;

  // 预先找到 aOther 的尾部（只遍历一次）
  LTail := aOther.FHead;
  if LTail <> nil then
  begin
    while LTail^.Next <> nil do
      LTail := PNode(LTail^.Next);
  end;

  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    // before_begin: splice entire other to head
    if FHead = nil then
    begin
      FHead := aOther.FHead;
    end
    else
    begin
      LTail^.Next := FHead;
      FHead := aOther.FHead;
    end;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.Splice: Invalid iterator position (end)');
  end
  else
  begin
    // 插入到指定位置之后
    LPosNode := PNode(aPosition.PtrIter.Data);
    LTail^.Next := LPosNode^.Next;
    LPosNode^.Next := aOther.FHead;
  end;

  FCount += aOther.FCount;
  // 若插到尾部或本就是空表，则更新 FLast
  if (LTail^.Next = nil) then FLast := LTail;

  // 清空源链表
  aOther.FHead := nil;
  aOther.FLast := nil;
  aOther.FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Splice(all): tail invariant broken');
  {$ENDIF}
end;

procedure TForwardList.Splice(aPosition: TIter; var aOther: TForwardList; aFirst: TIter);
var
  LBefore, LFirstNode, LPrev, LPosNode: PNode;
begin
  // 归属与自拼接校验
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.Splice: aPosition does not belong to this list');
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Splice: allocator mismatch between lists');
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Splice: self-splice is not supported');
  if (TCollection(aFirst.PtrIter.Owner) <> aOther) and (aFirst.PtrIter.Data <> nil) then
    raise EInvalidArgument.Create('TForwardList.Splice: aFirst does not belong to source list');

  // 语义：移动 aFirst 之后的单个元素（splice_after 单个）
  if aOther.FCount = 0 then
    Exit;

  // 计算要移动的节点：为 aFirst 之后的节点
  LBefore := PNode(aFirst.PtrIter.Data);
  if (LBefore = nil) then
  begin
    // aFirst=before_begin: 取源头结点
    if not aFirst.PtrIter.Started then
      LFirstNode := aOther.FHead
    else
      Exit; // 已启动但Data=nil: 无元素可移
  end
  else
    LFirstNode := PNode(LBefore^.Next);

  if LFirstNode = nil then
    Exit; // aFirst 指向最后一个元素，无可移动元素

  // 从 aOther 中移除 LFirstNode
  if aOther.FHead = LFirstNode then
    aOther.FHead := PNode(LFirstNode^.Next)
  else
  begin
    LPrev := aOther.FHead;
    while (LPrev <> nil) and (LPrev^.Next <> LFirstNode) do
      LPrev := PNode(LPrev^.Next);
    if LPrev <> nil then
      LPrev^.Next := LFirstNode^.Next;
  end;

  Dec(aOther.FCount);

  // 插入到当前链表 aPosition 之后
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    // before_begin: insert single node at head
    LFirstNode^.Next := FHead;
    FHead := LFirstNode;
    if FCount = 0 then FLast := FHead;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.Splice(single): Invalid iterator position (end)');
  end
  else
  begin
    LPosNode := PNode(aPosition.PtrIter.Data);
    LFirstNode^.Next := LPosNode^.Next;
    LPosNode^.Next := LFirstNode;
    if LFirstNode^.Next = nil then FLast := LFirstNode;
  end;

  Inc(FCount);
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Splice(single): tail invariant broken');
  {$ENDIF}
end;

procedure TForwardList.Splice(aPosition: TIter; var aOther: TForwardList; aFirst, aLast: TIter);
var
  LPosNode, LMoveHead, LMoveTail, LPrev, LCur: PSingleNode;
  LMoveCount: SizeUInt;
begin
  // 归属与自拼接校验
  // 分配器一致性检查：不同分配器下禁止偷节点
  if Allocator <> aOther.Allocator then
    raise EInvalidOperation.Create('TForwardList.Splice: allocator mismatch between lists');
  if aPosition.PtrIter.Owner <> Self then
    raise EInvalidArgument.Create('TForwardList.Splice: aPosition does not belong to this list');
  if aOther = Self then
    raise EInvalidOperation.Create('TForwardList.Splice: self-splice is not supported');

  // Semantics: [aFirst, aLast) includes aFirst, excludes aLast
  if aOther.FCount = 0 then Exit;

  // aFirst/aLast should come from aOther
  if TCollection(aFirst.PtrIter.Owner) <> aOther then
    raise EInvalidArgument.Create('TForwardList.Splice: aFirst does not belong to source list');
  if (aLast.PtrIter.Data <> nil) and (TCollection(aLast.PtrIter.Owner) <> aOther) then
    raise EInvalidArgument.Create('TForwardList.Splice: aLast does not belong to source list');

  // 计算区间头
  if aFirst.PtrIter.Data = nil then
  begin
    if not aFirst.PtrIter.Started then
      LMoveHead := aOther.FHead
    else
      Exit;
  end
  else
    LMoveHead := PSingleNode(aFirst.PtrIter.Data);

  // 计算区间尾（最后一个要移动的节点），直到 aLast（不含）
  if aLast.PtrIter.Data = nil then
  begin
    // 到末尾
    LCur := LMoveHead;
    LMoveTail := nil;
    LMoveCount := 0;
    while LCur <> nil do
    begin
      LMoveTail := LCur;
      LCur := PSingleNode(LCur^.Next);
      Inc(LMoveCount);
    end;
  end
  else
  begin
    // 插入到指定位置之后；如插到尾部需维护尾指针
    // 找到 Next = aLast 的节点
    LCur := LMoveHead;
    LMoveTail := nil;
    LMoveCount := 0;
    while (LCur <> nil) and (LCur <> PSingleNode(aLast.PtrIter.Data)) do
    begin
      LMoveTail := LCur;
      Inc(LMoveCount);
      LCur := PSingleNode(LCur^.Next);
    end;
    if LMoveTail = nil then Exit; // 空范围（aFirst==aLast）
  end;

  // 从源链表断开 [LMoveHead, LMoveTail]
  if aOther.FHead = LMoveHead then
    aOther.FHead := PSingleNode(LMoveTail^.Next)
  else
  begin
    LPrev := aOther.FHead;
    while (LPrev <> nil) and (LPrev^.Next <> LMoveHead) do
      LPrev := PSingleNode(LPrev^.Next);
    if LPrev = nil then Exit;
    LPrev^.Next := PSingleNode(LMoveTail^.Next);
  end;

  // 插入到目标 aPosition 之后
  LPosNode := PSingleNode(aPosition.PtrIter.Data);
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    // before_begin: splice range at head
    LMoveTail^.Next := FHead;
    FHead := LMoveHead;
    if FCount = 0 then FLast := LMoveTail;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.Splice(range): Invalid iterator position (end)');
  end
  else
  begin
    LMoveTail^.Next := LPosNode^.Next;
    LPosNode^.Next := LMoveHead;
    if LMoveTail^.Next = nil then FLast := LMoveTail;
  end;

  // 更新计数
  Inc(FCount, LMoveCount);
  Dec(aOther.FCount, LMoveCount);
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.Splice(range): tail invariant broken');
  {$ENDIF}
end;

{ 便利方法实现 }

function TForwardList.Size: SizeUInt;
begin
  Result := GetCount;
end;

function TForwardList.Empty: Boolean;
begin
  Result := IsEmpty;
end;

procedure TForwardList.Push(const aElement: T);
begin
  PushFront(aElement);
end;

function TForwardList.Pop: T;
begin
  Result := PopFront;
end;

{ TForwardList<T> - 现代化构造方法 }

procedure TForwardList.EmplaceFront(const aElement: T);
begin
  // EmplaceFront 在这个简单实现中等同于 PushFront
  // 在更复杂的类型中，这里可以进行就地构造优化
  PushFront(aElement);
end;

procedure TForwardList.EmplaceFrontUnChecked(const aElement: T);
begin
  // 无检查版本：直接调用 PushFrontUnChecked 以获得最佳性能
  PushFrontUnChecked(aElement);
end;

{ UnChecked: 调用方必须确保前置条件：
  - aArray 非空（Length(aArray) > 0），否则引用 aArray[Low(aArray)] 未定义
  - 单向链表仅支持头部插入，语义遵循 PushFront；逻辑位置需由调用方保证
  - 本方法不做参数/边界检查，违反前置条件将导致未定义行为 }

procedure TForwardList.PushFrontRangeUnChecked(const aArray: array of T);
var
  LI: Integer;
  LNewNode: PSingleNode;
  LWasEmpty: Boolean;
  LNewTail: PSingleNode;
begin
  // 为保持与 PushFront 的语义一致（每次在头部插入），应从低到高遍历：
  // 这样最终链表顺序为 aArray[High]..aArray[Low]
  // 若原表为空，首个创建的节点将成为最终的尾节点
  LWasEmpty := (FCount = 0);
  LNewTail := nil;
  for LI := Low(aArray) to High(aArray) do
  begin
    LNewNode := FNodeManager.CreateSingleNode(aArray[LI], FHead);
    if LWasEmpty and (LI = Low(aArray)) then
      LNewTail := LNewNode; // 记录首个插入的节点作为新尾
    FHead := LNewNode;
    Inc(FCount);
  end;
  if LWasEmpty then
    FLast := LNewTail;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.PushFrontRangeUnChecked: tail invariant broken');
  {$ENDIF}
end;

procedure TForwardList.ClearUnChecked;
var
  LCurrent, LNext: PSingleNode;
begin
  // 无检查版本：直接遍历并释放所有节点
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LNext := PSingleNode(LCurrent^.GetNext);
    FNodeManager.DestroySingleNode(LCurrent);
    LCurrent := LNext;
  end;
  FHead := nil;
  FLast := nil;
  FCount := 0;
  {$IFDEF DEBUG}
  if not DebugValidateTail then
    raise EWow.Create('TForwardList.ClearUnChecked: tail invariant broken');
  {$ENDIF}
end;

procedure TForwardList.EmplaceAfter(aPosition: TIter; const aElement: T);
begin
  // 保留旧的 void 版本，转调到返回迭代器版本
  EmplaceAfterEx(aPosition, aElement);
end;

function TForwardList.EmplaceAfterEx(aPosition: TIter; const aElement: T): TIter;
var
  LPosNode, LNewNode: PSingleNode;
begin
  // before_begin: 插入到表头
  if (aPosition.PtrIter.Data = nil) and (not aPosition.PtrIter.Started) then
  begin
    LNewNode := CreateNode(aElement, FHead);
    FHead := LNewNode;
    Inc(FCount);
    if FCount = 1 then FLast := FHead;

    Result.Init(aPosition.PtrIter);
    Result.PtrIter.Data := LNewNode;
    Exit;
  end
  else if (aPosition.PtrIter.Data = nil) and (aPosition.PtrIter.Started) then
  begin
    raise EInvalidArgument.Create('TForwardList.EmplaceAfter: Invalid iterator position (end)');
  end;

  // 插在 aPosition 之后
  LPosNode := PSingleNode(aPosition.PtrIter.Data);
  if LPosNode = nil then
  begin
    Result := aPosition;
    Exit;
  end;

  LNewNode := CreateNode(aElement, LPosNode^.Next);
  LPosNode^.Next := LNewNode;
  Inc(FCount);
  if LNewNode^.Next = nil then FLast := LNewNode;

  Result.Init(aPosition.PtrIter);
  Result.PtrIter.Data := LNewNode;
end;

function TForwardList.Top: T;
begin
  Result := Front;
end;

function TForwardList.Head: T;
begin
  Result := Front;
end;

procedure TForwardList.Assign(const aOther: TForwardList);
var
  LTempArray: array of T;
  i: Integer;
begin
  if @aOther = @Self then
    Exit;

  Clear;

  if aOther.IsEmpty then
    Exit;

  // 先转换为数组，然后逆序插入以保持顺序
  LTempArray := aOther.ToArray;
  for i := High(LTempArray) downto 0 do
    PushFront(LTempArray[i]);
end;

procedure TForwardList.Assign(aFirst, aLast: TIter);
var
  LSrc: TForwardList;
  LStart, LEnd, LCur: PSingleNode;
  LTempArray: array of T;
  i: Integer;
  LCount: SizeUInt;
begin
  Clear;

  // 解析源范围：[aFirst, aLast)
  LSrc := TForwardList(aFirst.PtrIter.Owner);
  if LSrc = nil then Exit;

  if aFirst.PtrIter.Data <> nil then
    LStart := PSingleNode(aFirst.PtrIter.Data)
  else if not aFirst.PtrIter.Started then
    LStart := LSrc.FHead
  else
    LStart := nil;

  if aLast.PtrIter.Data <> nil then
    LEnd := PSingleNode(aLast.PtrIter.Data)
  else
    LEnd := nil;

  if (LStart = nil) or (LStart = LEnd) then Exit;

  // 收集元素（两遍扫描：先计数，再一次性 SetLength，避免 O(n^2) 扩容）
  LCount := 0;
  LCur := LStart;
  while (LCur <> nil) and (LCur <> LEnd) do
  begin
    Inc(LCount);
    LCur := PSingleNode(LCur^.GetNext);
  end;
  SetLength(LTempArray, LCount);
  LCur := LStart;
  i := 0;
  while (LCur <> nil) and (LCur <> LEnd) do
  begin
    LTempArray[i] := LCur^.Data;
    Inc(i);
    LCur := PSingleNode(LCur^.GetNext);
  end;

  // 逆序 PushFront 保持顺序
  for i := High(LTempArray) downto 0 do
    PushFront(LTempArray[i]);
end;

procedure TForwardList.Assign(aCount: SizeUInt; const aValue: T);
var
  i: SizeUInt;
begin
  Clear;

  // 插入指定数量的相同值
  for i := 0 to aCount - 1 do
    PushFront(aValue);
end;

function TForwardList.Clone: TCollection;
begin
  Result := CloneForwardList;
end;

function TForwardList.CloneForwardList: TForwardList;
begin
  Result := TForwardList.Create(GetAllocator);
  Result.Assign(Self);
end;

function TForwardList.Equal(const aOther: TForwardList): Boolean;
begin
  Result := Equal(aOther, nil, nil);  // 使用默认相等比较
end;

function TForwardList.Equal(const aOther: TForwardList; aEquals: TEqualsFunc; aData: Pointer): Boolean;
var
  LIter1, LIter2: TIter;
begin
  if @aOther = @Self then
    Exit(True);

  if Count <> aOther.Count then
    Exit(False);

  LIter1 := Iter;
  LIter2 := aOther.Iter;

  while LIter1.MoveNext and LIter2.MoveNext do
  begin
    if aEquals <> nil then
    begin
      if not aEquals(LIter1.Current, LIter2.Current, aData) then
        Exit(False);
    end
    else
    begin
      if not FInternalEquals(LIter1.Current, LIter2.Current) then
        Exit(False);
    end;
  end;

  Result := True;
end;

procedure TForwardList.Resize(aNewSize: SizeUInt);
begin
  Resize(aNewSize, Default(T));
end;

procedure TForwardList.Resize(aNewSize: SizeUInt; const aFillValue: T);
var
  LCurrentSize: SizeUInt;
  i: SizeUInt;
begin
  LCurrentSize := Count;

  if aNewSize = LCurrentSize then
    Exit;

  if aNewSize < LCurrentSize then
  begin
    // 缩小：移除多余元素
    while Count > aNewSize do
      PopFront;
  end
  else
  begin
    // 扩大：添加新元素
    for i := LCurrentSize to aNewSize - 1 do
      PushFront(aFillValue);
  end;
end;

function TForwardList.BeforeBegin: TIter;
begin
  // 返回一个指向头部之前的迭代器
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;  // 特殊标记：before_begin
  Result.PtrIter.Started := False;
end;

function TForwardList.CBegin: TIter;
begin
  Result := Iter;
end;

function TForwardList.CEnd: TIter;
begin
  Result.Init(PtrIter);
  Result.PtrIter.Data := nil;
  Result.PtrIter.Started := True;
end;

{ 高级功能实现 }

function TForwardList.MaxSize: SizeUInt;
begin
  Result := High(SizeUInt) div SizeOf(TNode);
end;

procedure TForwardList.Swap(var aOther: TForwardList);
var
  LTempHead: PNode;
  LTempCount: SizeUInt;
begin
  if @aOther = @Self then
    Exit;

  LTempHead := FHead;
  LTempCount := FCount;

  FHead := aOther.FHead;
  FCount := aOther.FCount;

  aOther.FHead := LTempHead;
  aOther.FCount := LTempCount;
end;

function TForwardList.All(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if not aPredicate(LCurrent^.Data, aData) then
    begin
      Result := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
  Result := True;
end;

function TForwardList.Any(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if aPredicate(LCurrent^.Data, aData) then
    begin
      Result := True;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
  Result := False;
end;

function TForwardList.None(aPredicate: TPredicateFunc; aData: Pointer): Boolean;
begin
  Result := not Any(aPredicate, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.All(aPredicate: TPredicateRefFunc): Boolean;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if not aPredicate(LCurrent^.Data) then
    begin
      Result := False;
      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
  Result := True;
end;

function TForwardList.Any(aPredicate: TPredicateRefFunc): Boolean;
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if aPredicate(LCurrent^.Data) then
    begin
      Result := True;



      Exit;
    end;
    LCurrent := PNode(LCurrent^.Next);
  end;
  Result := False;
end;

function TForwardList.None(aPredicate: TPredicateRefFunc): Boolean;
begin
  Result := not Any(aPredicate);
end;
{$ENDIF}

procedure TForwardList.ForEach(aAction: TActionFunc; aData: Pointer);
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    aAction(LCurrent^.Data, aData);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
procedure TForwardList.ForEach(aAction: TActionRefFunc);
var
  LCurrent: PNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    aAction(LCurrent^.Data);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;
{$ENDIF}

function TForwardList.Accumulate(aInitial: T; aAccumulator: TAccumulatorFunc; aData: Pointer): T;
var
  LCurrent: PNode;
begin
  Result := aInitial;
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    Result := aAccumulator(Result, LCurrent^.Data, aData);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function TForwardList.Accumulate(aInitial: T; aAccumulator: TAccumulatorRefFunc): T;
var
  LCurrent: PNode;
begin
  Result := aInitial;
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    Result := aAccumulator(Result, LCurrent^.Data);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;
{$ENDIF}

{$IFDEF DEBUG}
function TForwardList.DebugValidateTail: Boolean;
var
  L: PSingleNode;
  C: SizeUInt;
begin
  // 空表：FHead 和 FLast 都应为 nil，计数为 0
  if FCount = 0 then
    Exit((FHead = nil) and (FLast = nil));

  // 非空：FHead 非空，FLast 非空，且 FLast^.Next = nil
  if (FHead = nil) or (FLast = nil) then
    Exit(False);

  L := FHead;
  C := 1;
  while PNode(L^.Next) <> nil do
  begin
    L := PNode(L^.Next);
    Inc(C);
  end;
  Result := (L = FLast) and (C = FCount) and (PNode(FLast^.Next) = nil);
end;

function TForwardList.DebugGetTailValue(out aValue: T): Boolean;
begin
  Result := FLast <> nil;
  if Result then aValue := FLast^.Data;
end;
{$ENDIF}


end.
