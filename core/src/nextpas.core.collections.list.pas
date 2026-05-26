unit nextpas.core.collections.list;
{**
 * @desc IList<T> 双向链表接口 - 基调与契约
 *
 * 角色与定位
 * - 面向双端插入/删除的通用链表接口；顺序访问友好，随机访问非目标
 * - 与 TGenericCollection<T> 对齐：复用 Equals/Compare/Predicate 等算法约定
 *
 * 语义约定
 * - PushFront/PushBack/PopFront/PopBack：O(1) 双端操作；Front/Back 不移除
 * - OverWrite vs Write：链表为节点结构，通常不提供 OverWrite 批量覆盖；插入/删除为主
 * - Checked vs UnChecked：
 *   - Checked 负责参数/状态检查，抛出 EOutOfRange/EArgumentNil/EInvalidArgument 等一致异常
 *   - UnChecked 不做任何检查，仅在必要处对零长度做 no-op
 *
 * 异常与安全
 * - 空表 Pop/Front/Back：Checked 抛出 EOutOfRange；Try* 返回 False
 * - 迭代期间修改：遵循具体实现文档，通常不保证并发安全
 *
 * 其他
 * - 不暴露容量/增长策略；与数组/向量不同，链表不涉及预留容量
 * - 与 TVec/VecDeque 的角色互补：频繁中间插入可选链表，双端批量更建议 VecDeque
 *}


{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, typinfo,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.node;

type

  {**
   * IList<T>
   *
   * @desc 双向链表接口，提供 O(1) 双端操作
   *
   * @param T 元素类型
   *
   * @note 核心操作复杂度：
   *   - PushFront/PushBack: O(1)
   *   - PopFront/PopBack: O(1)
   *   - Front/Back: O(1)
   *   - 随机访问: O(n)
   *
   * @threadsafety 非线程安全
   * @see TList 具体实现
   * @see TVecDeque 高性能双端队列替代方案
   *}
  generic IList<T> = interface(specialize IGenericCollection<T>)
  ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']

    {**
     * PushFront
     *
     * @desc 在链表头部插入一个元素
     *
     * @params
     *   aElement  要插入的元素
     *
     * @postcondition Front = aElement, Count 增加 1
     *
     * @complexity O(1)
     *}
    procedure PushFront(const aElement: T);

    {**
     * PushBack
     *
     * @desc 在链表尾部插入一个元素
     *
     * @params
     *   aElement  要插入的元素
     *
     * @postcondition Back = aElement, Count 增加 1
     *
     * @complexity O(1)
     *}
    procedure PushBack(const aElement: T);

    {**
     * PopFront
     *
     * @desc 移除并返回链表头部的元素
     *
     * @return 被移除的头部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @postcondition Count 减少 1
     *
     * @complexity O(1)
     *}
    function PopFront: T;

    {**
     * PopBack
     *
     * @desc 移除并返回链表尾部的元素
     *
     * @return 被移除的尾部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @postcondition Count 减少 1
     *
     * @complexity O(1)
     *}
    function PopBack: T;

    {**
     * Front
     *
     * @desc 获取链表头部元素（不移除）
     *
     * @return 头部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @complexity O(1)
     *}
    function Front: T;

    {**
     * Back
     *
     * @desc 获取链表尾部元素（不移除）
     *
     * @return 尾部元素
     *
     * @exceptions
     *   EInvalidOperation  链表为空
     *
     * @complexity O(1)
     *}
    function Back: T;

    {**
     * TryFront
     *
     * @desc 安全地获取头部元素
     *
     * @params
     *   aElement 输出参数，存储头部元素
     *
     * @return 如果链表非空返回 True，否则返回 False
     *}
    function TryFront(out aElement: T): Boolean;

    { 非异常批量导入/追加（集合重载） }
    function TryLoadFrom(const aSrc: TCollection): Boolean;
    function TryAppend(const aSrc: TCollection): Boolean;

    {**
     * TryBack
     *
     * @desc 安全地获取尾部元素
     *
     * @params
     *   aElement 输出参数，存储尾部元素
     *
     * @return 如果链表非空返回 True，否则返回 False
     *}
    function TryBack(out aElement: T): Boolean;

    {**
     * TryPopFront
     *
     * @desc 安全地弹出头部元素
     *
     * @params
     *   aElement 输出参数，存储被弹出的元素
     *
     * @return 如果成功弹出返回 True，否则返回 False
     *}
    function TryPopFront(out aElement: T): Boolean;

    {**
     * TryPopBack
     *
     * @desc 安全地弹出尾部元素
     *
     * @params
     *   aElement 输出参数，存储被弹出的元素
     *
     * @return 如果成功弹出返回 True，否则返回 False
     *}
    function TryPopBack(out aElement: T): Boolean;

    {**
     * 高性能方法（无安全检查版本）
     *
     * @remark
     *   这些方法跳过所有安全检查以获得最佳性能
     *   调用者必须确保参数和状态的有效性
     *   遵循项目 UnChecked 命名规范
     *}

    {**
     * PushFrontUnChecked
     *
     * @desc 在链表头部插入元素（无安全检查版本）
     *}
    procedure PushFrontUnChecked(const aElement: T);

    {**
     * PushBackUnChecked
     *
     * @desc 在链表尾部插入元素（无安全检查版本）
     *}
    procedure PushBackUnChecked(const aElement: T);

    {**
     * PopFrontUnChecked
     *
     * @desc 移除并返回头部元素（无安全检查版本）
     *}
    function PopFrontUnChecked: T;

    {**
     * PopBackUnChecked
     *
     * @desc 移除并返回尾部元素（无安全检查版本）
     *}
    function PopBackUnChecked: T;

    {**
     * PushRangeUnChecked
     *
     * @desc 批量插入数组元素到链表尾部（无安全检查版本）
     *}
    procedure PushRangeUnChecked(const aArray: array of T);

    {**
     * ClearUnChecked
     *
     * @desc 清空链表（无安全检查版本）
     *}
    procedure ClearUnChecked;

  end;

  {**
   * TList<T>
   *
   * @desc 双向链表实现，提供 O(1) 双端插入/删除
   *
   * @param T 元素类型
   *
   * @note
   *   - 基于优化的 TDoubleLinkedNode<T> 实现
   *   - 使用 TNodeManager 管理节点内存
   *   - 适合频繁头尾操作、中间插入的场景
   *   - 不支持高效随机访问（O(n)）
   *
   * @threadsafety 非线程安全
   *
   * @example
   *   var List: specialize TList<Integer>;
   *   List := specialize TList<Integer>.Create;
   *   try
   *     List.PushBack(1);
   *     List.PushFront(0);
   *     WriteLn(List.Front);  // 0
   *     WriteLn(List.PopBack);  // 1
   *   finally
   *     List.Free;
   *   end;
   *
   * @see IList 接口定义
   * @see TVecDeque 高性能双端队列替代方案
   *}
  generic TList<T> = class(specialize TGenericCollection<T>, specialize IList<T>)
  public
    type
      {** 节点管理器类型 *}
      TNodeManager = specialize TNodeManager<T>;
      {** 双向节点指针类型 *}
      PDoubleNode = TNodeManager.PDoubleNode;
      {** 双向节点类型 *}
      TDoubleNode = TNodeManager.TDoubleNode;

  private
    FNodeManager: TNodeManager;  // 优化的节点管理器
    FHead:        PDoubleNode;   // 头节点指针
    FTail:        PDoubleNode;   // 尾节点指针
    FCount:       SizeUInt;      // 元素数量

  { 内部节点管理 - 基于优化的 TNodeManager }
  private
    function  CreateNode(const aData: T; aPrev, aNext: PDoubleNode): PDoubleNode; inline;
    procedure DestroyNode(aNode: PDoubleNode); inline;

  { 迭代器回调 }
  protected
    function  DoIterGetCurrent(aIter: PPtrIter): Pointer; inline;
    function  DoIterMoveNext(aIter: PPtrIter): Boolean; inline;

  { 抽象方法实现 }
  protected
    function  IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override;
    procedure DoReverse; override;

  public
    { 构造函数和析构函数 }
    constructor Create; overload;
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create(aAllocator: IAllocator; aData: Pointer); override; overload;
    constructor Create(const aSrc: array of T); overload;
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
    function  Clone: TCollection; override;

    { IList<T> 接口实现 }
    procedure PushFront(const aElement: T);
    procedure PushBack(const aElement: T);
    function  PopFront: T;
    function  PopBack: T;
    function  Front: T;
    function  Back: T;
    function  TryFront(out aElement: T): Boolean;
    function  TryBack(out aElement: T): Boolean;
    function  TryPopFront(out aElement: T): Boolean;
    function  TryPopBack(out aElement: T): Boolean;

    { 高性能方法（无安全检查版本）}
    procedure PushFrontUnChecked(const aElement: T); inline;
    procedure PushBackUnChecked(const aElement: T); inline;
    function  PopFrontUnChecked: T; inline;
    function  PopBackUnChecked: T; inline;
    procedure PushRangeUnChecked(const aArray: array of T);
    procedure ClearUnChecked;

    { 类型安全的克隆操作 }
    function  CloneList: TList;


    // Non-throwing bulk ops (pointer overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    function  TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;


    // Non-throwing bulk ops (collection overloads), forwarding to TCollection.Try*
    function  TryLoadFrom(const aSrc: TCollection): Boolean;
    function  TryAppend(const aSrc: TCollection): Boolean;

    { 便利属性 }
    property Head: T read Front;


    property Tail: T read Back;

  end;

implementation

{ TList<T> - 内部节点管理 }

function TList.CreateNode(const aData: T; aPrev, aNext: PDoubleNode): PDoubleNode;
begin
  Result := FNodeManager.CreateDoubleNode(aData, aPrev, aNext);
end;

procedure TList.DestroyNode(aNode: PDoubleNode);
begin
  FNodeManager.DestroyDoubleNode(aNode);
end;

{ TList<T> - 迭代器回调 }

function TList.DoIterGetCurrent(aIter: PPtrIter): Pointer;
var
  LNode: PDoubleNode;
begin
  LNode := PDoubleNode(aIter^.Data);
  if LNode = nil then
    raise EInvalidOperation.Create('TList.DoIterGetCurrent: 无效的迭代器位置');

  Result := @(LNode^.Data);
end;

function TList.DoIterMoveNext(aIter: PPtrIter): Boolean;
var
  LCurrentNode: PDoubleNode;
begin
  if not aIter^.Started then
  begin
    // 第一次调用，从头节点开始
    aIter^.Started := True;
    aIter^.Data := FHead;
  end
  else
  begin
    // 移动到下一个节点 - 使用优化的零开销方法
    LCurrentNode := PDoubleNode(aIter^.Data);
    if LCurrentNode <> nil then
      aIter^.Data := LCurrentNode^.GetNext  // 零开销方法
    else
      aIter^.Data := nil;
  end;

  Result := aIter^.Data <> nil;
end;

{ TList<T> - 构造函数和析构函数 }

constructor TList.Create;
begin
  // Delegate to base; actual initialization happens in Create(aAllocator, aData)
  inherited Create;
end;

constructor TList.Create(aAllocator: IAllocator);
begin
  // Delegate to base; actual initialization happens in Create(aAllocator, aData)
  inherited Create(aAllocator);
end;

constructor TList.Create(aAllocator: IAllocator; aData: Pointer);
begin
  inherited Create(aAllocator, aData);
  FNodeManager := TNodeManager.Create(FAllocator);
  FHead := nil;
  FTail := nil;
  FCount := 0;
  end;

constructor TList.Create(const aSrc: array of T);
var
  LI: Integer;
begin
  Create;
  for LI := Low(aSrc) to High(aSrc) do
    PushBackUnChecked(aSrc[LI]);
end;

constructor TList.Create(aSrc: Pointer; aElementCount: SizeUInt);
begin
  Create;
  AppendUnChecked(aSrc, aElementCount);
end;

constructor TList.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator);
begin
  Create(aAllocator);
  AppendUnChecked(aSrc, aElementCount);
end;

constructor TList.Create(aSrc: Pointer; aElementCount: SizeUInt; aAllocator: IAllocator; aData: Pointer);
begin
  Create(aAllocator, aData);
  AppendUnChecked(aSrc, aElementCount);
end;

destructor TList.Destroy;
begin
  Clear;
  FNodeManager.Free;
  inherited Destroy;
end;

{ TList<T> - ICollection 接口实现 }

function TList.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, nil);
end;

function TList.GetCount: SizeUInt;
begin
  Result := FCount;
end;

procedure TList.Clear;
var
  LCurrent, LNext: PDoubleNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LNext := PDoubleNode(LCurrent^.GetNext);
    DestroyNode(LCurrent);
    LCurrent := LNext;
  end;
  FHead := nil;
  FTail := nil;
  FCount := 0;
end;

procedure TList.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LCurrent: PDoubleNode;
  LDstArray: ^T;
  LI: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;

  LDstArray := aDst;
  LCurrent := FHead;
  LI := 0;

  while (LCurrent <> nil) and (LI < aCount) do
  begin
    LDstArray[LI] := LCurrent^.Data;
    Inc(LI);
    LCurrent := PDoubleNode(LCurrent^.GetNext);
  end;
end;

procedure TList.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LSrcArray: ^T;
  LI: SizeUInt;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LSrcArray := aSrc;
  for LI := 0 to aElementCount - 1 do
    PushBackUnChecked(LSrcArray[LI]);
end;

procedure TList.AppendToUnChecked(const aDst: TCollection);
var
  LCurrent: PDoubleNode;
begin
  if aDst = nil then
    Exit;

  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    aDst.AppendUnChecked(@LCurrent^.Data, 1);
    LCurrent := PDoubleNode(LCurrent^.GetNext);
  end;
  end;

function TList.TryLoadFrom(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := inherited TryLoadFrom(aSrc, aElementCount);
end;

function TList.TryAppend(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := inherited TryAppend(aSrc, aElementCount);
end;


function TList.TryLoadFrom(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryLoadFrom(aSrc);
end;

function TList.TryAppend(const aSrc: TCollection): Boolean;
begin
  Result := inherited TryAppend(aSrc);
end;

function TList.Clone: TCollection;
begin
  Result := CloneList;
end;

function TList.CloneList: TList;
var
  LCurrent: PDoubleNode;
begin
  Result := TList.Create(GetAllocator);
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    Result.PushBackUnChecked(LCurrent^.Data);
    LCurrent := PDoubleNode(LCurrent^.GetNext);
  end;
end;

{ TList<T> - IList<T> 接口实现 }

procedure TList.PushFront(const aElement: T);
var
  LNewNode: PDoubleNode;
begin
  LNewNode := CreateNode(aElement, nil, FHead);

  if FHead <> nil then
    FHead^.SetPrev(LNewNode)
  else
    FTail := LNewNode;  // 第一个节点，也是尾节点

  FHead := LNewNode;
  Inc(FCount);
end;

procedure TList.PushBack(const aElement: T);
var
  LNewNode: PDoubleNode;
begin
  LNewNode := CreateNode(aElement, FTail, nil);

  if FTail <> nil then
    FTail^.SetNext(LNewNode)
  else
    FHead := LNewNode;  // 第一个节点，也是头节点

  FTail := LNewNode;
  Inc(FCount);
end;

function TList.PopFront: T;
var
  LOldHead: PDoubleNode;
begin
  if FHead = nil then
    raise EInvalidOperation.Create('TList.PopFront: 链表为空');

  LOldHead := FHead;
  Result := LOldHead^.Data;

  FHead := PDoubleNode(LOldHead^.GetNext);
  if FHead <> nil then
    FHead^.SetPrev(nil)
  else
    FTail := nil;  // 链表变空

  DestroyNode(LOldHead);
  Dec(FCount);
end;

function TList.PopBack: T;
var
  LOldTail: PDoubleNode;
begin
  if FTail = nil then
    raise EInvalidOperation.Create('TList.PopBack: 链表为空');

  LOldTail := FTail;
  Result := LOldTail^.Data;

  FTail := PDoubleNode(LOldTail^.GetPrev);
  if FTail <> nil then
    FTail^.SetNext(nil)
  else
    FHead := nil;  // 链表变空

  DestroyNode(LOldTail);
  Dec(FCount);
end;

function TList.Front: T;
begin
  if FHead = nil then
    raise EInvalidOperation.Create('TList.Front: 链表为空');
  Result := FHead^.Data;
end;

function TList.Back: T;
begin
  if FTail = nil then
    raise EInvalidOperation.Create('TList.Back: 链表为空');
  Result := FTail^.Data;
end;

function TList.TryFront(out aElement: T): Boolean;
begin
  Result := FHead <> nil;
  if Result then
    aElement := FHead^.Data;
end;

function TList.TryBack(out aElement: T): Boolean;
begin
  Result := FTail <> nil;
  if Result then
    aElement := FTail^.Data;
end;

function TList.TryPopFront(out aElement: T): Boolean;
begin
  Result := FHead <> nil;
  if Result then
    aElement := PopFront;
end;

function TList.TryPopBack(out aElement: T): Boolean;
begin
  Result := FTail <> nil;
  if Result then
    aElement := PopBack;
end;

{ TList<T> - 高性能方法（无安全检查版本）}

procedure TList.PushFrontUnChecked(const aElement: T);
var
  LNewNode: PDoubleNode;
begin
  LNewNode := FNodeManager.CreateDoubleNode(aElement, nil, FHead);

  if FHead <> nil then
    FHead^.SetPrev(LNewNode)
  else
    FTail := LNewNode;

  FHead := LNewNode;
  Inc(FCount);
end;

procedure TList.PushBackUnChecked(const aElement: T);
var
  LNewNode: PDoubleNode;
begin
  LNewNode := FNodeManager.CreateDoubleNode(aElement, FTail, nil);

  if FTail <> nil then
    FTail^.SetNext(LNewNode)
  else
    FHead := LNewNode;

  FTail := LNewNode;
  Inc(FCount);
end;

function TList.PopFrontUnChecked: T;
var
  LOldHead: PDoubleNode;
begin
  LOldHead := FHead;
  Result := LOldHead^.Data;

  FHead := PDoubleNode(LOldHead^.GetNext);
  if FHead <> nil then
    FHead^.SetPrev(nil)
  else
    FTail := nil;

  FNodeManager.DestroyDoubleNode(LOldHead);
  Dec(FCount);
end;

function TList.PopBackUnChecked: T;
var
  LOldTail: PDoubleNode;
begin
  LOldTail := FTail;
  Result := LOldTail^.Data;

  FTail := PDoubleNode(LOldTail^.GetPrev);
  if FTail <> nil then
    FTail^.SetNext(nil)
  else
    FHead := nil;

  FNodeManager.DestroyDoubleNode(LOldTail);
  Dec(FCount);
end;

{ UnChecked: 调用方必须确保前置条件：
  - aArray 非空（Length(aArray) > 0），否则引用 aArray[Low(aArray)] 未定义
  - 插入序列的范围由调用方保证可用（链表结构无容量概念，但逻辑位置需有效）
  - 本方法不做参数/边界检查，违反前置条件将导致未定义行为 }

procedure TList.PushRangeUnChecked(const aArray: array of T);
var
  LI: Integer;
begin
  for LI := Low(aArray) to High(aArray) do
    PushBackUnChecked(aArray[LI]);
end;

procedure TList.ClearUnChecked;
var
  LCurrent, LNext: PDoubleNode;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LNext := PDoubleNode(LCurrent^.GetNext);
    FNodeManager.DestroyDoubleNode(LCurrent);
    LCurrent := LNext;
  end;
  FHead := nil;
  FTail := nil;
  FCount := 0;
end;

{ TList<T> - 抽象方法实现 }

function TList.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
var
  LCurrent: PDoubleNode;
  LSrcStart, LSrcEnd: PtrUInt;
begin
  // 链表的内存是分散的，需要检查每个节点是否与源内存重叠
  Result := False;

  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LSrcStart := PtrUInt(aSrc);
  LSrcEnd := LSrcStart + aElementCount * SizeOf(T);

  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if (PtrUInt(@LCurrent^.Data) >= LSrcStart) and
       (PtrUInt(@LCurrent^.Data) < LSrcEnd) then
    begin
      Result := True;
      Exit;
    end;
    LCurrent := PDoubleNode(LCurrent^.GetNext);
  end;
end;

procedure TList.DoZero;
var
  LCurrent: PDoubleNode;
begin
  // 将所有元素设置为零值
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    FillChar(LCurrent^.Data, SizeOf(T), 0);
    LCurrent := PDoubleNode(LCurrent^.GetNext);
  end;
end;

procedure TList.DoReverse;
var
  LCurrent, LNext, LPrev: PDoubleNode;
begin
  // 反转双向链表
  LCurrent := FHead;
  LPrev := nil;

  while LCurrent <> nil do
  begin
    LNext := PDoubleNode(LCurrent^.GetNext);

    // 交换当前节点的前后指针
    LCurrent^.SetNext(LPrev);
    LCurrent^.SetPrev(LNext);

    LPrev := LCurrent;
    LCurrent := LNext;
  end;

  // 交换头尾指针
  FTail := FHead;
  FHead := LPrev;
end;

end.
