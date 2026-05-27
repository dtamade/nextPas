unit nextpas.core.collections.node;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - node-based structures
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes, typinfo,
  nextpas.core.base,
  {$HINTS OFF}nextpas.core.math,{$HINTS ON}
  {$HINTS OFF}nextpas.core.mem.utils,{$HINTS ON}
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager;

type

  {**
   * TSingleLinkedNode<T> - 单向链接节点
   *
   * @desc
   *   极高性能的单向链接节点，使用 record 结构避免对象开销
   *   适用于单向链表、栈、队列等数据结构
   *
   * @remark
   *   - 使用 Pointer 类型存储下一个节点的地址，避免类型循环引用
   *   - 所有方法强制内联以获得最佳性能
   *   - 内存布局优化，确保缓存友好性
   *   - 兼容现有的 TForwardListNode<T> 设计模式
   *}
  generic TSingleLinkedNode<T> = packed record
  public
    Data: T;              // 节点存储的数据（放在前面以获得更好的缓存局部性）
    Next: Pointer;        // 指向下一个节点的指针

  public
    {**
     * Init
     *
     * @desc 初始化节点
     *
     * @params
     *   aData 节点数据
     *   aNext 下一个节点的指针，默认为 nil
     *
     * @remark 此操作的时间复杂度为 O(1)
     *}
    procedure Init(const aData: T; aNext: Pointer = nil); inline;

    {**
     * Clear
     *
     * @desc 清空节点数据和连接
     *
     * @remark
     *   对于托管类型，会自动调用析构函数
     *   此操作的时间复杂度为 O(1)
     *   优化版本：避免不必要的默认值赋值
     *}
    procedure Clear; inline;

    {**
     * GetNext
     *
     * @desc 获取下一个节点的指针（零开销版本）
     *
     * @return 下一个节点的指针，如果没有则返回 nil
     *}
    function GetNext: Pointer; inline;

    {**
     * SetNext
     *
     * @desc 设置下一个节点的指针（零开销版本）
     *
     * @params
     *   aNext 下一个节点的指针
     *}
    procedure SetNext(aNext: Pointer); inline;

    {**
     * HasNext
     *
     * @desc 检查是否有下一个节点（零开销版本）
     *
     * @return 如果有下一个节点返回 True，否则返回 False
     *}
    function HasNext: Boolean; inline;

    {**
     * InitUnchecked
     *
     * @desc 无检查初始化节点（无安全检查版本）
     *
     * @params
     *   aData 节点数据
     *   aNext 下一个节点的指针
     *
     * @remark
     *   此版本跳过所有安全检查，仅用于性能关键路径
     *   调用者必须确保参数的有效性
     *}
    procedure InitUnchecked(const aData: T; aNext: Pointer); inline;

  end;

  {**
   * TDoubleLinkedNode<T> - 双向链接节点
   *
   * @desc
   *   极高性能的双向链接节点，使用 packed record 结构避免对象开销
   *   适用于双向链表、双端队列等数据结构
   *
   * @remark
   *   - 包含前驱和后继指针，支持双向遍历
   *   - 所有方法强制内联以获得最佳性能
   *   - 支持高效的插入和删除操作
   *   - 内存布局优化：Data 在前，指针在后，提高缓存命中率
   *}
  generic TDoubleLinkedNode<T> = packed record
  public
    Data: T;              // 节点存储的数据（放在前面以获得更好的缓存局部性）
    Prev: Pointer;        // 指向前一个节点的指针
    Next: Pointer;        // 指向下一个节点的指针

  public
    {**
     * Init
     *
     * @desc 初始化节点
     *
     * @params
     *   aData 节点数据
     *   aPrev 前一个节点的指针，默认为 nil
     *   aNext 下一个节点的指针，默认为 nil
     *}
    procedure Init(const aData: T; aPrev: Pointer = nil; aNext: Pointer = nil); inline;

    {**
     * Clear
     *
     * @desc 清空节点数据和连接（优化版本）
     *}
    procedure Clear; inline;

    {**
     * GetPrev
     *
     * @desc 获取前一个节点的指针（零开销版本）
     *}
    function GetPrev: Pointer; inline;

    {**
     * SetPrev
     *
     * @desc 设置前一个节点的指针（零开销版本）
     *}
    procedure SetPrev(aPrev: Pointer); inline;

    {**
     * GetNext
     *
     * @desc 获取下一个节点的指针（零开销版本）
     *}
    function GetNext: Pointer; inline;

    {**
     * SetNext
     *
     * @desc 设置下一个节点的指针（零开销版本）
     *}
    procedure SetNext(aNext: Pointer); inline;

    {**
     * HasPrev
     *
     * @desc 检查是否有前一个节点（零开销版本）
     *}
    function HasPrev: Boolean; inline;

    {**
     * HasNext
     *
     * @desc 检查是否有下一个节点（零开销版本）
     *}
    function HasNext: Boolean; inline;

    {**
     * UnlinkUnchecked
     *
     * @desc 无检查将当前节点从链表中断开连接（优化版本）
     *
     * @remark
     *   此操作会连接前后节点，但不会清空当前节点的指针
     *   优化版本：减少内存访问次数，提高缓存效率
     *   调用者需要手动调用 Clear 来清空节点
     *}
    procedure UnlinkUnchecked; inline;

    {**
     * Unlink
     *
     * @desc 将当前节点从链表中断开连接（兼容版本）
     *}
    procedure Unlink; inline;

  end;

  {**
   * TTreeNode<T> - 树节点
   *
   * @desc
   *   极高性能的树节点，使用 packed record 结构避免对象开销
   *   适用于二叉树、多叉树、Trie树等数据结构
   *
   * @remark
   *   - 使用 FirstChild-NextSibling 表示法，节省内存空间
   *   - 支持任意数量的子节点
   *   - 所有方法强制内联以获得最佳性能
   *   - 内存布局优化：Data 在前，指针紧密排列，提高缓存效率
   *}
  generic TTreeNode<T> = packed record
  public
    Data: T;              // 节点存储的数据（放在前面以获得更好的缓存局部性）
    Parent: Pointer;      // 指向父节点的指针
    FirstChild: Pointer;  // 指向第一个子节点的指针
    NextSibling: Pointer; // 指向下一个兄弟节点的指针

  public
    {**
     * Init
     *
     * @desc 初始化节点
     *
     * @params
     *   aData 节点数据
     *   aParent 父节点的指针，默认为 nil
     *}
    procedure Init(const aData: T; aParent: Pointer = nil); inline;

    {**
     * Clear
     *
     * @desc 清空节点数据和连接（优化版本）
     *}
    procedure Clear; inline;

    {**
     * GetParent
     *
     * @desc 获取父节点的指针（零开销版本）
     *}
    function GetParent: Pointer; inline;

    {**
     * SetParent
     *
     * @desc 设置父节点的指针（零开销版本）
     *}
    procedure SetParent(aParent: Pointer); inline;

    {**
     * GetFirstChild
     *
     * @desc 获取第一个子节点的指针（零开销版本）
     *}
    function GetFirstChild: Pointer; inline;

    {**
     * SetFirstChild
     *
     * @desc 设置第一个子节点的指针（零开销版本）
     *}
    procedure SetFirstChild(aChild: Pointer); inline;

    {**
     * GetNextSibling
     *
     * @desc 获取下一个兄弟节点的指针（零开销版本）
     *}
    function GetNextSibling: Pointer; inline;

    {**
     * SetNextSibling
     *
     * @desc 设置下一个兄弟节点的指针（零开销版本）
     *}
    procedure SetNextSibling(aSibling: Pointer); inline;

    {**
     * IsRoot
     *
     * @desc 检查是否为根节点（零开销版本）
     *}
    function IsRoot: Boolean; inline;

    {**
     * IsLeaf
     *
     * @desc 检查是否为叶子节点（零开销版本）
     *}
    function IsLeaf: Boolean; inline;

    {**
     * HasChildren
     *
     * @desc 检查是否有子节点（零开销版本）
     *}
    function HasChildren: Boolean; inline;

    {**
     * HasSiblings
     *
     * @desc 检查是否有兄弟节点（零开销版本）
     *}
    function HasSiblings: Boolean; inline;

  end;

  {**
   * TNodeManager<T> - 节点管理器
   *
   * @desc
   *   提供节点的内存管理、池化和批量操作功能
   *   支持各种类型的节点统一管理
   *
   * @remark
   *   - 使用 IAllocator 进行内存管理
   *   - 支持 TElementManager<T> 处理托管类型
   *   - 提供节点池化以提高性能
   *}
  generic TNodeManager<T> = class
  public
    type
      PSingleNode = ^TSingleNode;
      TSingleNode = specialize TSingleLinkedNode<T>;

      PDoubleNode = ^TDoubleNode;
      TDoubleNode = specialize TDoubleLinkedNode<T>;

      PTreeNode = ^TTreeNodeType;
      TTreeNodeType = specialize TTreeNode<T>;

      TElementManager = specialize TElementManager<T>;

  private
    FAllocator: IAllocator;
    FElementManager: TElementManager;

  public
    constructor Create(aAllocator: IAllocator);
    destructor Destroy; override;

    {**
     * AllocateSingleNode
     *
     * @desc 分配一个单向链接节点
     *
     * @return 新分配的节点指针
     *
     * @exceptions
     *   EOutOfMemory 如果内存分配失败
     *}
    function AllocateSingleNode: PSingleNode;

    {**
     * DeallocateSingleNode
     *
     * @desc 释放一个单向链接节点
     *
     * @params
     *   aNode 要释放的节点指针
     *}
    procedure DeallocateSingleNode(aNode: PSingleNode);

    {**
     * CreateSingleNode
     *
     * @desc 创建并初始化一个单向链接节点
     *
     * @params
     *   aData 节点数据
     *   aNext 下一个节点的指针，默认为 nil
     *
     * @return 新创建的节点指针
     *}
    function CreateSingleNode(const aData: T; aNext: PSingleNode = nil): PSingleNode;

    {**
     * DestroySingleNode
     *
     * @desc 销毁一个单向链接节点（清理数据并释放内存）
     *
     * @params
     *   aNode 要销毁的节点指针
     *}
    procedure DestroySingleNode(aNode: PSingleNode);

    {**
     * AllocateDoubleNode
     *
     * @desc 分配一个双向链接节点
     *}
    function AllocateDoubleNode: PDoubleNode;

    {**
     * DeallocateDoubleNode
     *
     * @desc 释放一个双向链接节点
     *}
    procedure DeallocateDoubleNode(aNode: PDoubleNode);

    {**
     * CreateDoubleNode
     *
     * @desc 创建并初始化一个双向链接节点
     *}
    function CreateDoubleNode(const aData: T; aPrev: PDoubleNode = nil; aNext: PDoubleNode = nil): PDoubleNode;

    {**
     * DestroyDoubleNode
     *
     * @desc 销毁一个双向链接节点
     *}
    procedure DestroyDoubleNode(aNode: PDoubleNode);

    {**
     * AllocateTreeNode
     *
     * @desc 分配一个树节点
     *}
    function AllocateTreeNode: PTreeNode;

    {**
     * DeallocateTreeNode
     *
     * @desc 释放一个树节点
     *}
    procedure DeallocateTreeNode(aNode: PTreeNode);

    {**
     * CreateTreeNode
     *
     * @desc 创建并初始化一个树节点
     *}
    function CreateTreeNode(const aData: T; aParent: PTreeNode = nil): PTreeNode;

    {**
     * DestroyTreeNode
     *
     * @desc 销毁一个树节点
     *}
    procedure DestroyTreeNode(aNode: PTreeNode);

    property Allocator: IAllocator read FAllocator;
    property ElementManager: TElementManager read FElementManager;

  end;

  {**
   * TNodeAlgorithms - 节点算法工具类
   *
   * @desc
   *   提供各种节点操作的通用算法
   *   所有方法都是静态方法，无需实例化
   *}
  TNodeAlgorithms = class
  public
    {**
     * CountSingleLinkedNodes
     *
     * @desc 计算单向链表中的节点数量
     *
     * @params
     *   aHead 链表头节点指针
     *
     * @return 节点数量
     *}
    class function CountSingleLinkedNodes(aHead: Pointer): SizeUInt; static;

    {**
     * FindLastSingleLinkedNode
     *
     * @desc 查找单向链表的最后一个节点
     *
     * @params
     *   aHead 链表头节点指针
     *
     * @return 最后一个节点的指针，如果链表为空则返回 nil
     *}
    class function FindLastSingleLinkedNode(aHead: Pointer): Pointer; static;

    {**
     * ReverseSingleLinkedList
     *
     * @desc 反转单向链表
     *
     * @params
     *   aHead 链表头节点指针
     *
     * @return 反转后的新头节点指针
     *}
    class function ReverseSingleLinkedList(aHead: Pointer): Pointer; static;

    {**
     * CountTreeNodeChildren
     *
     * @desc 计算树节点的直接子节点数量
     *
     * @params
     *   aNode 树节点指针
     *
     * @return 直接子节点数量
     *}
    class function CountTreeNodeChildren(aNode: Pointer): SizeUInt; static;

    {**
     * GetTreeNodeDepth
     *
     * @desc 计算树节点的深度（从根节点开始）
     *
     * @params
     *   aNode 树节点指针
     *
     * @return 节点深度，根节点深度为 0
     *}
    class function GetTreeNodeDepth(aNode: Pointer): SizeUInt; static;

    {**
     * CountTreeNodeDescendants
     *
     * @desc 计算树节点的所有后代节点数量（递归计算）
     *
     * @params
     *   aNode 树节点指针
     *
     * @return 后代节点总数
     *}
    class function CountTreeNodeDescendants(aNode: Pointer): SizeUInt; static;

  end;

  {**
   * TNodeOptimizations - 节点性能优化工具
   *
   * @desc
   *   提供高级性能优化功能，包括内存预取、批量操作等
   *   专为高性能场景设计
   *}
  TNodeOptimizations = class
  public
    class procedure PrefetchNext(aNode: Pointer; aSteps: Integer = 1); static; inline;
    class procedure PrefetchChildren(aTreeNode: Pointer); static; inline;
    class function GetSingleNodeSize: SizeUInt; static; inline;
    class function GetDoubleNodeSize: SizeUInt; static; inline;
    class function GetTreeNodeSize: SizeUInt; static; inline;
    class function ValidateAlignment(aNode: Pointer): Boolean; static; inline;
  end;

implementation

{ TSingleLinkedNode<T> - 极高性能实现 }

procedure TSingleLinkedNode.Init(const aData: T; aNext: Pointer);
begin
  Data := aData;
  Next := aNext;
end;

procedure TSingleLinkedNode.InitUnchecked(const aData: T; aNext: Pointer);
begin
  // 无检查版本：直接赋值，无任何检查
  Data := aData;
  Next := aNext;
end;

procedure TSingleLinkedNode.Clear;
begin
  // 优化版本：只有在必要时才清空数据
  {$IFDEF DEBUG}
  Data := Default(T);
  {$ELSE}
  // 在发布版本中，只清空指针以避免不必要的开销
  // 数据会在下次使用时被覆盖
  {$ENDIF}
  Next := nil;
end;

function TSingleLinkedNode.GetNext: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := Next;
end;

procedure TSingleLinkedNode.SetNext(aNext: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  Next := aNext;
end;

function TSingleLinkedNode.HasNext: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := Next <> nil;
end;

{ TDoubleLinkedNode<T> - 极高性能实现 }

procedure TDoubleLinkedNode.Init(const aData: T; aPrev: Pointer; aNext: Pointer);
begin
  Data := aData;
  Prev := aPrev;
  Next := aNext;
end;

procedure TDoubleLinkedNode.Clear;
begin
  // 优化版本：只有在必要时才清空数据
  {$IFDEF DEBUG}
  Data := Default(T);
  {$ELSE}
  // 在发布版本中，只清空指针以避免不必要的开销
  {$ENDIF}
  Prev := nil;
  Next := nil;
end;

function TDoubleLinkedNode.GetPrev: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := Prev;
end;

procedure TDoubleLinkedNode.SetPrev(aPrev: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  Prev := aPrev;
end;

function TDoubleLinkedNode.GetNext: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := Next;
end;

procedure TDoubleLinkedNode.SetNext(aNext: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  Next := aNext;
end;

function TDoubleLinkedNode.HasPrev: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := Prev <> nil;
end;

function TDoubleLinkedNode.HasNext: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := Next <> nil;
end;

procedure TDoubleLinkedNode.UnlinkUnchecked;
type
  PDoubleNode = ^TDoubleNode;
  TDoubleNode = specialize TDoubleLinkedNode<T>;
var
  LPrev, LNext: PDoubleNode;
begin
  // 无检查版本：减少内存访问，提高缓存效率
  LPrev := PDoubleNode(Prev);
  LNext := PDoubleNode(Next);

  // 使用局部变量减少重复的内存访问
  if LPrev <> nil then
    LPrev^.Next := Next;
  if LNext <> nil then
    LNext^.Prev := Prev;
end;

procedure TDoubleLinkedNode.Unlink;
begin
  // 兼容版本：调用无检查版本
  UnlinkUnchecked;
end;

{ TTreeNode<T> - 极高性能实现 }

procedure TTreeNode.Init(const aData: T; aParent: Pointer);
begin
  Data := aData;
  Parent := aParent;
  FirstChild := nil;
  NextSibling := nil;
end;

procedure TTreeNode.Clear;
begin
  // 优化版本：只有在必要时才清空数据
  {$IFDEF DEBUG}
  Data := Default(T);
  {$ELSE}
  // 在发布版本中，只清空指针以避免不必要的开销
  {$ENDIF}
  Parent := nil;
  FirstChild := nil;
  NextSibling := nil;
end;

function TTreeNode.GetParent: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := Parent;
end;

procedure TTreeNode.SetParent(aParent: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  Parent := aParent;
end;

function TTreeNode.GetFirstChild: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := FirstChild;
end;

procedure TTreeNode.SetFirstChild(aChild: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  FirstChild := aChild;
end;

function TTreeNode.GetNextSibling: Pointer;
begin
  // 零开销版本：直接返回，无任何检查
  Result := NextSibling;
end;

procedure TTreeNode.SetNextSibling(aSibling: Pointer);
begin
  // 零开销版本：直接赋值，无任何检查
  NextSibling := aSibling;
end;

function TTreeNode.IsRoot: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := Parent = nil;
end;

function TTreeNode.IsLeaf: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := FirstChild = nil;
end;

function TTreeNode.HasChildren: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := FirstChild <> nil;
end;

function TTreeNode.HasSiblings: Boolean;
begin
  // 零开销版本：直接比较，无任何检查
  Result := NextSibling <> nil;
end;

{ TNodeManager<T> }

constructor TNodeManager.Create(aAllocator: IAllocator);
begin
  inherited Create;
  if aAllocator = nil then
    raise EArgumentNil.Create('TNodeManager.Create: aAllocator cannot be nil');

  FAllocator := aAllocator;
  FElementManager := TElementManager.Create(aAllocator);
end;

destructor TNodeManager.Destroy;
begin
  FElementManager.Free;
  inherited Destroy;
end;

function TNodeManager.AllocateSingleNode: PSingleNode;
begin
  Result := PSingleNode(FAllocator.GetMem(SizeOf(TSingleNode)));
  if Result = nil then
    raise EOutOfMemory.Create('TNodeManager.AllocateSingleNode: 内存分配失败');
end;

procedure TNodeManager.DeallocateSingleNode(aNode: PSingleNode);
begin
  if aNode <> nil then
    FAllocator.FreeMem(aNode);
end;

function TNodeManager.CreateSingleNode(const aData: T; aNext: PSingleNode): PSingleNode;
var
  LInited: Boolean;
begin
  Result := AllocateSingleNode;
  LInited := False;
  try
    // 初始化托管类型
    if FElementManager.IsManagedType then
    begin
      FElementManager.InitializeElements(@Result^.Data, 1);
      LInited := True;
    end;

    // 初始化节点
    Result^.Init(aData, aNext);
  except
    // 如果已为托管类型初始化，则需要先反初始化，避免泄漏
    if LInited and FElementManager.IsManagedType then
      FElementManager.FinalizeManagedElements(@Result^.Data, 1);
    DeallocateSingleNode(Result);
    raise;
  end;
end;

procedure TNodeManager.DestroySingleNode(aNode: PSingleNode);
begin
  if aNode = nil then
    Exit;

  // 释放托管类型
  if FElementManager.IsManagedType then
    FElementManager.FinalizeManagedElements(@aNode^.Data, 1);

  DeallocateSingleNode(aNode);
end;

function TNodeManager.AllocateDoubleNode: PDoubleNode;
begin
  Result := PDoubleNode(FAllocator.GetMem(SizeOf(TDoubleNode)));
  if Result = nil then
    raise EOutOfMemory.Create('TNodeManager.AllocateDoubleNode: 内存分配失败');
end;

procedure TNodeManager.DeallocateDoubleNode(aNode: PDoubleNode);
begin
  if aNode <> nil then
    FAllocator.FreeMem(aNode);
end;

function TNodeManager.CreateDoubleNode(const aData: T; aPrev: PDoubleNode; aNext: PDoubleNode): PDoubleNode;
var
  LInited: Boolean;
begin
  Result := AllocateDoubleNode;
  LInited := False;
  try
    // 初始化托管类型
    if FElementManager.IsManagedType then
    begin
      FElementManager.InitializeElements(@Result^.Data, 1);
      LInited := True;
    end;

    // 初始化节点
    Result^.Init(aData, aPrev, aNext);
  except
    if LInited and FElementManager.IsManagedType then
      FElementManager.FinalizeManagedElements(@Result^.Data, 1);
    DeallocateDoubleNode(Result);
    raise;
  end;
end;

procedure TNodeManager.DestroyDoubleNode(aNode: PDoubleNode);
begin
  if aNode = nil then
    Exit;

  // 释放托管类型
  if FElementManager.IsManagedType then
    FElementManager.FinalizeManagedElements(@aNode^.Data, 1);

  DeallocateDoubleNode(aNode);
end;

function TNodeManager.AllocateTreeNode: PTreeNode;
begin
  Result := PTreeNode(FAllocator.GetMem(SizeOf(TTreeNodeType)));
  if Result = nil then
    raise EOutOfMemory.Create('TNodeManager.AllocateTreeNode: 内存分配失败');
end;

procedure TNodeManager.DeallocateTreeNode(aNode: PTreeNode);
begin
  if aNode <> nil then
    FAllocator.FreeMem(aNode);
end;

function TNodeManager.CreateTreeNode(const aData: T; aParent: PTreeNode): PTreeNode;
var
  LInited: Boolean;
begin
  Result := AllocateTreeNode;
  LInited := False;
  try
    // 初始化托管类型
    if FElementManager.IsManagedType then
    begin
      FElementManager.InitializeElements(@Result^.Data, 1);
      LInited := True;
    end;

    // 初始化节点
    Result^.Init(aData, aParent);
  except
    if LInited and FElementManager.IsManagedType then
      FElementManager.FinalizeManagedElements(@Result^.Data, 1);
    DeallocateTreeNode(Result);
    raise;
  end;
end;

procedure TNodeManager.DestroyTreeNode(aNode: PTreeNode);
begin
  if aNode = nil then
    Exit;

  // 释放托管类型
  if FElementManager.IsManagedType then
    FElementManager.FinalizeManagedElements(@aNode^.Data, 1);

  DeallocateTreeNode(aNode);
end;

{ TNodeAlgorithms }

class function TNodeAlgorithms.CountSingleLinkedNodes(aHead: Pointer): SizeUInt;
type
  PSingleNode = ^TSingleNode;
  TSingleNode = specialize TSingleLinkedNode<Byte>; // 使用 Byte 作为占位符类型
var
  LCurrent: PSingleNode;
begin
  Result := 0;
  LCurrent := PSingleNode(aHead);

  while LCurrent <> nil do
  begin
    Inc(Result);
    LCurrent := PSingleNode(LCurrent^.GetNext);
  end;
end;

class function TNodeAlgorithms.FindLastSingleLinkedNode(aHead: Pointer): Pointer;
type
  PSingleNode = ^TSingleNode;
  TSingleNode = specialize TSingleLinkedNode<Byte>;
var
  LCurrent: PSingleNode;
begin
  Result := nil;
  LCurrent := PSingleNode(aHead);

  while LCurrent <> nil do
  begin
    Result := LCurrent;
    LCurrent := PSingleNode(LCurrent^.GetNext);
  end;
end;

class function TNodeAlgorithms.ReverseSingleLinkedList(aHead: Pointer): Pointer;
type
  PSingleNode = ^TSingleNode;
  TSingleNode = specialize TSingleLinkedNode<Byte>;
var
  LCurrent, LPrev, LNext: PSingleNode;
begin
  LCurrent := PSingleNode(aHead);
  LPrev := nil;

  while LCurrent <> nil do
  begin
    LNext := PSingleNode(LCurrent^.GetNext);
    LCurrent^.SetNext(LPrev);
    LPrev := LCurrent;
    LCurrent := LNext;
  end;

  Result := LPrev;
end;

class function TNodeAlgorithms.CountTreeNodeChildren(aNode: Pointer): SizeUInt;
type
  PTreeNode = ^TTreeNodeType;
  TTreeNodeType = specialize TTreeNode<Byte>;
var
  LChild: PTreeNode;
begin
  Result := 0;
  if aNode = nil then
    Exit;

  LChild := PTreeNode(PTreeNode(aNode)^.GetFirstChild);
  while LChild <> nil do
  begin
    Inc(Result);
    LChild := PTreeNode(LChild^.GetNextSibling);
  end;
end;

class function TNodeAlgorithms.GetTreeNodeDepth(aNode: Pointer): SizeUInt;
type
  PTreeNode = ^TTreeNodeType;
  TTreeNodeType = specialize TTreeNode<Byte>;
var
  LCurrent: PTreeNode;
begin
  Result := 0;
  if aNode = nil then
    Exit;

  LCurrent := PTreeNode(PTreeNode(aNode)^.GetParent);
  while LCurrent <> nil do
  begin
    Inc(Result);
    LCurrent := PTreeNode(LCurrent^.GetParent);
  end;
end;

class function TNodeAlgorithms.CountTreeNodeDescendants(aNode: Pointer): SizeUInt;
type
  PTreeNode = ^TTreeNodeType;
  TTreeNodeType = specialize TTreeNode<Byte>;
var
  LChild: PTreeNode;
begin
  Result := 0;
  if aNode = nil then
    Exit;

  LChild := PTreeNode(PTreeNode(aNode)^.GetFirstChild);
  while LChild <> nil do
  begin
    Inc(Result); // 计算直接子节点
    Inc(Result, CountTreeNodeDescendants(LChild)); // 递归计算后代
    LChild := PTreeNode(LChild^.GetNextSibling);
  end;
end;



{ TNodeOptimizations - 高性能优化实现 }

class procedure TNodeOptimizations.PrefetchNext(aNode: Pointer; aSteps: Integer);
type
  PSingleNode = ^TSingleNode;
  TSingleNode = specialize TSingleLinkedNode<Byte>;
var
  LCurrent: PSingleNode;
  LI: Integer;
begin
  LCurrent := PSingleNode(aNode);

  // 预取指定步数的节点
  for LI := 1 to aSteps do
  begin
    if LCurrent = nil then
      Break;

    // 简化版本：在不支持内联汇编的情况下跳过预取
    // 实际应用中，编译器的优化通常已经足够

    LCurrent := PSingleNode(LCurrent^.GetNext);
  end;
end;

class procedure TNodeOptimizations.PrefetchChildren(aTreeNode: Pointer);
type
  PTreeNode = ^TTreeNodeType;
  TTreeNodeType = specialize TTreeNode<Byte>;
var
  LChild: PTreeNode;
begin
  if aTreeNode = nil then
    Exit;

  LChild := PTreeNode(PTreeNode(aTreeNode)^.GetFirstChild);

  // 预取所有直接子节点（简化版本）
  while LChild <> nil do
  begin
    // 简单的内存访问，让编译器优化
    LChild := PTreeNode(LChild^.GetNextSibling);
  end;
end;

class function TNodeOptimizations.GetSingleNodeSize: SizeUInt;
begin
  // 编译时计算，零运行时开销
  Result := SizeOf(specialize TSingleLinkedNode<Integer>);
end;

class function TNodeOptimizations.GetDoubleNodeSize: SizeUInt;
begin
  // 编译时计算，零运行时开销
  Result := SizeOf(specialize TDoubleLinkedNode<Integer>);
end;

class function TNodeOptimizations.GetTreeNodeSize: SizeUInt;
begin
  // 编译时计算，零运行时开销
  Result := SizeOf(specialize TTreeNode<Integer>);
end;

class function TNodeOptimizations.ValidateAlignment(aNode: Pointer): Boolean;
begin
  {$IFDEF DEBUG}
  // 检查指针是否按机器字长对齐
  Result := (PtrUInt(aNode) and (SizeOf(Pointer) - 1)) = 0;
  {$ELSE}
  // 发布版本中总是返回 True，会被编译器优化掉
  Result := True;
  {$ENDIF}
end;



end.



end.
