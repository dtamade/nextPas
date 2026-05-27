unit nextpas.core.collections.treemap;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - tree structures use node-based storage
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.treemap.base,
  nextpas.core.collections.treemap.intf,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.arr;

type

  { TRedBlackTree 节点 }
  generic TRedBlackTreeNode<K, V> = record
    Key: K;
    Value: V;
    Left: Pointer;
    Right: Pointer;
    Parent: Pointer;
    Color: UInt8;  // 0 = Red, 1 = Black
  end;

  generic TRedBlackTree<K, V> = class
  type
    PNode = ^specialize TRedBlackTreeNode<K, V>;
    TNodeArray = array of PNode;
    TMapEntryType = specialize TMapEntry<K, V>;
    TElementManagerType = specialize TElementManager<specialize TMapEntry<K, V>>;

  public
    FRoot: PNode;
    FSentinel: specialize TRedBlackTreeNode<K, V>;

  private
    FCount: SizeUInt;
    FAllocator: IAllocator;
    FElementManager: TElementManagerType;
    FCompareMethod: specialize TCompareFunc<K>;

    procedure InitTree; {$IFDEF FAFAFA_CORE_INLINE} inline;{$ENDIF}

    { 红黑树操作 }
    procedure RotateLeft(aNode: PNode);
    procedure RotateRight(aNode: PNode);
    function InsertNode(const aKey: K; const aValue: V; out aExisted: Boolean): PNode;
    function FindNode(const aKey: K): PNode;
    function GetMaximum(aNode: PNode): PNode;
    function GetLowerBoundNode(const aKey: K): PNode;
    function GetUpperBoundNode(const aKey: K): PNode;

    procedure FixInsert(aNode: PNode);
    procedure FixDelete(aNode, aParent: PNode);

    procedure Transplant(aU, aV: PNode);
    procedure InOrderTraversal(aNode: PNode; const aCallback: specialize TKeyValueCallback<K, V>);

    function AllocateNode(const aKey: K; const aValue: V): PNode;
    procedure DeallocateNode(aNode: PNode);
    procedure FreeNodeAndChildren(aNode: PNode);

  public
    function GetMinimum(aNode: PNode): PNode;
    function GetSuccessor(aNode: PNode): PNode;
    function GetPredecessor(aNode: PNode): PNode;

  public
    constructor Create(const aAllocator: IAllocator; const aCompare: specialize TCompareFunc<K>);
    destructor Destroy; override;

    { API }
    function Get(const aKey: K; out aValue: V): Boolean;
    function Put(const aKey: K; const aValue: V): Boolean;
    function Remove(const aKey: K): Boolean;
    function ContainsKey(const aKey: K): Boolean;
    function GetCount: SizeUInt;

    function GetLowerBound(const aKey: K; out aValue: V): Boolean;
    function GetUpperBound(const aKey: K; out aValue: V): Boolean;
    function GetRange(const aLow, aHigh: K; const aCallback: specialize TKeyValueCallback<K, V>): Boolean;
    function Ceiling(const aKey: K; out aValue: V): Boolean;
    function Floor(const aKey: K; out aValue: V): Boolean;

    function GetKeys: TCollection;
    function GetValues: TCollection;

    procedure Clear;
  end;

  {**
   * TTreeMap<K,V>
   *
   * @desc 红黑树实现的有序键值对映射
   *
   * @param K 键类型（必须支持比较操作，或提供自定义比较器）
   * @param V 值类型
   *
   * @note
   *   - 键按升序排列，支持范围查询
   *   - O(log n) 插入、删除、查找
   *   - 支持 Rust 风格的 Entry API
   *   - 与 HashMap 相比：内存占用更高，但支持有序遍历和范围查询
   *
   * @threadsafety NOT thread-safe。并发访问需外部同步。
   *
   * @example
   *   var
   *     tree: specialize TTreeMap<Integer, String>;
   *   begin
   *     tree := specialize TTreeMap<Integer, String>.Create;
   *     try
   *       tree.Put(3, 'three');
   *       tree.Put(1, 'one');
   *       tree.Put(2, 'two');
   *       // 遍历按键升序: 1, 2, 3
   *     finally
   *       tree.Free;
   *     end;
   *   end;
   *
   * @see ITreeMap, THashMap
   *}
  generic TTreeMap<K, V> = class(specialize TGenericCollection<specialize TMapEntry<K, V>>, specialize ITreeMap<K, V>)

  type
    PNode = specialize TRedBlackTreeNode<K, V>;
    PNodeArray = array of PNode;
    TRedBlackTreeType = specialize TRedBlackTree<K, V>;
    TKeyCompareFunc = specialize TCompareFunc<K>;

  private
    FTree: TRedBlackTreeType;
    FComparer: TKeyCompareFunc;

  type
    TEntryType = specialize TMapEntry<K, V>;
    PEntryType = ^TEntryType;
    // Entry API types
    TValueSupplier = specialize TTreeValueSupplierFunc<V>;
    TValueModifier = specialize TTreeValueModifierProc<V>;

  protected
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override;
    procedure DoReverse; override;
    function DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function DoIterMoveNext(aIter: PPtrIter): Boolean;

  public
    function GetCount: SizeUInt; override;

    {**
     * Create
     *
     * @desc 创建 TTreeMap 实例
     *
     * @params
     *   aAllocator  内存分配器（nil 则使用默认 RTL 分配器）
     *   aCompare    键比较函数（nil 则使用默认比较）
     *
     * @exceptions
     *   EOutOfMemory  内存分配失败
     *
     * @example
     *   // 默认创建
     *   tree := specialize TTreeMap<Integer, String>.Create;
     *
     *   // 自定义比较器（降序）
     *   tree := specialize TTreeMap<Integer, String>.Create(nil, @ReverseCompare);
     *}
    constructor Create(const aAllocator: IAllocator = nil; const aCompare: TKeyCompareFunc = nil); reintroduce; overload;

    {**
     * Destroy
     *
     * @desc 释放 TTreeMap 及其所有元素
     *
     * @note 会自动调用 Clear 释放所有节点
     *}
    destructor Destroy; override;

    procedure AfterConstruction; override;

    { TCollection 抽象方法实现 }

    {**
     * PtrIter
     *
     * @desc 获取指针迭代器（按键升序遍历）
     *
     * @return TPtrIter 迭代器
     *
     * @complexity 初始化 O(log n)，遍历 O(n)
     *}
    function PtrIter: TPtrIter; override;

    {**
     * SerializeToArrayBuffer
     *
     * @desc 将键值对序列化到数组缓冲区（按键升序）
     *
     * @params
     *   aDst    目标缓冲区指针
     *   aCount  要序列化的元素数量
     *
     * @precondition aDst 必须有足够空间容纳 aCount 个 TMapEntry<K,V>
     *}
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;

    {**
     * AppendUnChecked
     *
     * @desc 从数组缓冲区追加键值对（无检查版本）
     *
     * @params
     *   aSrc           源缓冲区指针
     *   aElementCount  元素数量
     *
     * @precondition aSrc 指向有效的 TMapEntry<K,V> 数组
     *}
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;

    {**
     * AppendToUnChecked
     *
     * @desc 将当前元素追加到目标容器（无检查版本）
     *
     * @params
     *   aDst  目标容器
     *
     * @precondition aDst 是兼容的 TTreeMap 实例
     *}
    procedure AppendToUnChecked(const aDst: TCollection); override;

    { ITreeMap 接口实现 - 详见 ITreeMap 文档 }
    function GetLowerBound(const aKey: K; out aValue: V): Boolean; overload;
    function GetUpperBound(const aKey: K; out aValue: V): Boolean; overload;
    function GetRange(const aLow, aHigh: K; const aCallback: specialize TKeyValueCallback<K, V>): Boolean;
    function Ceiling(const aKey: K; out aValue: V): Boolean;
    function Floor(const aKey: K; out aValue: V): Boolean;

    function Get(const aKey: K; out aValue: V): Boolean;
    function Put(const aKey: K; const aValue: V): Boolean;
    function Remove(const aKey: K): Boolean;
    function ContainsKey(const aKey: K): Boolean;
    function GetKeyCount: SizeUInt;

    function GetKeys: TCollection;
    function GetValues: TCollection;

    procedure Clear; override;

    { Entry API - Rust 风格的键值访问模式 }
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    function GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
    procedure ModifyOrInsert(const AKey: K; AModifier: TValueModifier; const ADefault: V);

    { 便捷属性 - API 一致性 }
    property Count: SizeUInt read GetCount;
  end;

implementation

{ TRedBlackTree }

constructor TRedBlackTree.Create(const aAllocator: IAllocator; const aCompare: specialize TCompareFunc<K>);
begin
  inherited Create;
  FAllocator := aAllocator;
  if FAllocator = nil then
    FAllocator := GetRtlAllocator;

  FElementManager := TElementManagerType.Create(FAllocator);
  InitTree;

  if Assigned(aCompare) then
    FCompareMethod := aCompare
  else
    raise EArgumentNil.Create('TRedBlackTree.Create: compare function cannot be nil');
end;

procedure TRedBlackTree.InitTree;
begin
  FSentinel.Left := @FSentinel;
  FSentinel.Right := @FSentinel;
  FSentinel.Parent := @FSentinel;
  FSentinel.Color := 1; // Black
  FRoot := @FSentinel;
  FCount := 0;
end;

destructor TRedBlackTree.Destroy;
begin
  Clear;
  FElementManager.Free;
  inherited Destroy;
end;

function TRedBlackTree.AllocateNode(const aKey: K; const aValue: V): PNode;
begin
  Result := nil;
  Result := FAllocator.AllocMem(SizeOf(Result^));
  Result^.Key := aKey;
  Result^.Value := aValue;
  Result^.Left := @FSentinel;
  Result^.Right := @FSentinel;
  Result^.Parent := @FSentinel;
  Result^.Color := 0;  // Red
end;

procedure TRedBlackTree.DeallocateNode(aNode: PNode);
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit;
  { 在释放内存前 Finalize 键值（特别是字符串等引用类型） }
  Finalize(aNode^.Key);
  Finalize(aNode^.Value);
  FAllocator.FreeMem(aNode);
end;

procedure TRedBlackTree.RotateLeft(aNode: PNode);
var
  LRight: PNode;
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit;
  LRight := PNode(aNode^.Right);
  if LRight = @FSentinel then Exit;
  aNode^.Right := LRight^.Left;

  if LRight^.Left <> @FSentinel then
    PNode(LRight^.Left)^.Parent := aNode;

  LRight^.Parent := aNode^.Parent;

  if aNode^.Parent = @FSentinel then
    FRoot := LRight
  else if aNode = PNode(aNode^.Parent)^.Left then
    PNode(aNode^.Parent)^.Left := LRight
  else
    PNode(aNode^.Parent)^.Right := LRight;

  LRight^.Left := aNode;
  aNode^.Parent := LRight;
end;

procedure TRedBlackTree.RotateRight(aNode: PNode);
var
  LLeft: PNode;
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit;
  LLeft := PNode(aNode^.Left);
  if LLeft = @FSentinel then Exit;
  aNode^.Left := LLeft^.Right;

  if LLeft^.Right <> @FSentinel then
    PNode(LLeft^.Right)^.Parent := aNode;

  LLeft^.Parent := aNode^.Parent;

  if aNode^.Parent = @FSentinel then
    FRoot := LLeft
  else if aNode = PNode(aNode^.Parent)^.Left then
    PNode(aNode^.Parent)^.Left := LLeft
  else
    PNode(aNode^.Parent)^.Right := LLeft;

  LLeft^.Right := aNode;
  aNode^.Parent := LLeft;
end;

procedure TRedBlackTree.FixInsert(aNode: PNode);
var
  LUncle: PNode;
begin
  while (aNode^.Parent <> @FSentinel) and (PNode(aNode^.Parent)^.Color = 0) do
  begin
    if aNode^.Parent = PNode(PNode(aNode^.Parent)^.Parent)^.Left then
    begin
      LUncle := PNode(PNode(aNode^.Parent)^.Parent)^.Right;
      if (LUncle <> @FSentinel) and (PNode(LUncle)^.Color = 0) then
      begin
        PNode(aNode^.Parent)^.Color := 1;
        PNode(LUncle)^.Color := 1;
        PNode(PNode(aNode^.Parent)^.Parent)^.Color := 0;
        aNode := PNode(aNode^.Parent)^.Parent;
      end
      else
      begin
        if aNode = PNode(aNode^.Parent)^.Right then
        begin
          aNode := PNode(aNode^.Parent);
          RotateLeft(aNode);
        end;
        PNode(aNode^.Parent)^.Color := 1;
        PNode(PNode(aNode^.Parent)^.Parent)^.Color := 0;
        RotateRight(PNode(aNode^.Parent)^.Parent);
      end;
    end
    else
    begin
      LUncle := PNode(PNode(aNode^.Parent)^.Parent)^.Left;
      if (LUncle <> @FSentinel) and (PNode(LUncle)^.Color = 0) then
      begin
        PNode(aNode^.Parent)^.Color := 1;
        PNode(LUncle)^.Color := 1;
        PNode(PNode(aNode^.Parent)^.Parent)^.Color := 0;
        aNode := PNode(aNode^.Parent)^.Parent;
      end
      else
      begin
        if aNode = PNode(aNode^.Parent)^.Left then
        begin
          aNode := PNode(aNode^.Parent);
          RotateRight(aNode);
        end;
        PNode(aNode^.Parent)^.Color := 1;
        PNode(PNode(aNode^.Parent)^.Parent)^.Color := 0;
        RotateLeft(PNode(aNode^.Parent)^.Parent);
      end;
    end;
  end;

  if FRoot <> @FSentinel then
    PNode(FRoot)^.Color := 1;
end;

function TRedBlackTree.InsertNode(const aKey: K; const aValue: V; out aExisted: Boolean): PNode;
var
  LParent, LCurrent: PNode;
  LCompareResult: SizeInt;
begin
  LParent := @FSentinel;
  LCurrent := FRoot;
  while LCurrent <> @FSentinel do
  begin
    LParent := LCurrent;
    LCompareResult := FCompareMethod(aKey, LCurrent^.Key, nil);
    if LCompareResult = 0 then
    begin
      LCurrent^.Value := aValue;
      aExisted := True;
      Exit(LCurrent);
    end
    else if LCompareResult < 0 then
      LCurrent := PNode(LCurrent^.Left)
    else
      LCurrent := PNode(LCurrent^.Right);
  end;

  Result := AllocateNode(aKey, aValue);
  Result^.Parent := LParent;

  if LParent = @FSentinel then
    FRoot := Result
  else if FCompareMethod(aKey, LParent^.Key, nil) < 0 then
    LParent^.Left := Result
  else
    LParent^.Right := Result;

  aExisted := False;
  Inc(FCount);
  FixInsert(Result);
end;

procedure TRedBlackTree.Transplant(aU, aV: PNode);
begin
  if aU^.Parent = @FSentinel then
    FRoot := aV
  else if aU = PNode(aU^.Parent)^.Left then
    PNode(aU^.Parent)^.Left := aV
  else
    PNode(aU^.Parent)^.Right := aV;

  if aV <> @FSentinel then
    aV^.Parent := aU^.Parent;
end;

function TRedBlackTree.GetMinimum(aNode: PNode): PNode;
begin
  Result := aNode;
  if Result = nil then Exit(nil);
  if Result = @FSentinel then Exit(@FSentinel);
  while Result^.Left <> @FSentinel do
    Result := PNode(Result^.Left);
end;

function TRedBlackTree.GetMaximum(aNode: PNode): PNode;
begin
  Result := aNode;
  if Result = nil then Exit(nil);
  if Result = @FSentinel then Exit(@FSentinel);
  while Result^.Right <> @FSentinel do
    Result := PNode(Result^.Right);
end;

procedure TRedBlackTree.FixDelete(aNode, aParent: PNode);
var
  LSibling: PNode;
begin
  while (aNode <> FRoot) and ((aNode = @FSentinel) or (aNode^.Color = 1)) do
  begin
    if aNode = PNode(aParent)^.Left then
    begin
      LSibling := PNode(aParent^.Right);
      if (LSibling <> @FSentinel) and (PNode(LSibling)^.Color = 0) then
      begin
        PNode(LSibling)^.Color := 1;
        PNode(aParent)^.Color := 0;
        RotateLeft(aParent);
        LSibling := PNode(aParent^.Right);
      end;

      if ((LSibling = @FSentinel) or (PNode(LSibling)^.Left = @FSentinel) or (PNode(PNode(LSibling)^.Left)^.Color = 1)) and
         ((LSibling = @FSentinel) or (PNode(LSibling)^.Right = @FSentinel) or (PNode(PNode(LSibling)^.Right)^.Color = 1)) then
      begin
        if LSibling <> @FSentinel then
          PNode(LSibling)^.Color := 0;
        aNode := aParent;
        aParent := PNode(aParent^.Parent);
      end
      else
      begin
        if (LSibling <> @FSentinel) and ((PNode(LSibling)^.Right = @FSentinel) or (PNode(PNode(LSibling)^.Right)^.Color = 1)) then
        begin
          if PNode(LSibling)^.Left <> @FSentinel then
            PNode(PNode(LSibling)^.Left)^.Color := 1;
          if LSibling <> @FSentinel then
            PNode(LSibling)^.Color := 0;
          RotateRight(LSibling);
          LSibling := PNode(aParent^.Right);
        end;

        if LSibling <> @FSentinel then
          PNode(LSibling)^.Color := PNode(aParent)^.Color;
        PNode(aParent)^.Color := 1;
        if (LSibling <> @FSentinel) and (PNode(LSibling)^.Right <> @FSentinel) then
          PNode(PNode(LSibling)^.Right)^.Color := 1;
        RotateLeft(aParent);
        aNode := FRoot;
      end;
    end
    else
    begin
      LSibling := PNode(aParent^.Left);
      if (LSibling <> @FSentinel) and (PNode(LSibling)^.Color = 0) then
      begin
        PNode(LSibling)^.Color := 1;
        PNode(aParent)^.Color := 0;
        RotateRight(aParent);
        LSibling := PNode(aParent^.Left);
      end;

      if ((LSibling = @FSentinel) or (PNode(LSibling)^.Right = @FSentinel) or (PNode(PNode(LSibling)^.Right)^.Color = 1)) and
         ((LSibling = @FSentinel) or (PNode(LSibling)^.Left = @FSentinel) or (PNode(PNode(LSibling)^.Left)^.Color = 1)) then
      begin
        if LSibling <> @FSentinel then
          PNode(LSibling)^.Color := 0;
        aNode := aParent;
        aParent := PNode(aParent^.Parent);
      end
      else
      begin
        if (LSibling <> @FSentinel) and ((PNode(LSibling)^.Left = @FSentinel) or (PNode(PNode(LSibling)^.Left)^.Color = 1)) then
        begin
          if PNode(LSibling)^.Right <> @FSentinel then
            PNode(PNode(LSibling)^.Right)^.Color := 1;
          if LSibling <> @FSentinel then
            PNode(LSibling)^.Color := 0;
          RotateLeft(LSibling);
          LSibling := PNode(aParent^.Left);
        end;

        if LSibling <> @FSentinel then
          PNode(LSibling)^.Color := PNode(aParent)^.Color;
        PNode(aParent)^.Color := 1;
        if (LSibling <> @FSentinel) and (PNode(LSibling)^.Left <> @FSentinel) then
          PNode(PNode(LSibling)^.Left)^.Color := 1;
        RotateRight(aParent);
        aNode := FRoot;
      end;
    end;
  end;

  if aNode <> @FSentinel then
    aNode^.Color := 1;
end;

function TRedBlackTree.GetSuccessor(aNode: PNode): PNode;
var
  LTemp: PNode;
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit(@FSentinel);
  if aNode^.Right <> @FSentinel then
  begin
    Result := GetMinimum(PNode(aNode^.Right));
    Exit;
  end;

  LTemp := aNode^.Parent;
  while (LTemp <> @FSentinel) and (aNode = PNode(LTemp)^.Right) do
  begin
    aNode := LTemp;
    LTemp := LTemp^.Parent;
  end;
  Result := LTemp;
end;

function TRedBlackTree.GetPredecessor(aNode: PNode): PNode;
var
  LTemp: PNode;
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit(@FSentinel);
  if aNode^.Left <> @FSentinel then
  begin
    Result := GetMaximum(PNode(aNode^.Left));
    Exit;
  end;

  LTemp := aNode^.Parent;
  while (LTemp <> @FSentinel) and (aNode = PNode(LTemp)^.Left) do
  begin
    aNode := LTemp;
    LTemp := LTemp^.Parent;
  end;
  Result := LTemp;
end;

function TRedBlackTree.FindNode(const aKey: K): PNode;
var
  LCompareResult: SizeInt;
begin
  Result := FRoot;
  while Result <> @FSentinel do
  begin
    LCompareResult := FCompareMethod(aKey, PNode(Result)^.Key, nil);

    if LCompareResult = 0 then
      Exit
    else if LCompareResult < 0 then
      Result := PNode(Result)^.Left
    else
      Result := PNode(Result)^.Right;
  end;
  Result := nil;
end;

function TRedBlackTree.GetLowerBoundNode(const aKey: K): PNode;
var
  LResult: PNode;
  LCompareResult: SizeInt;
begin
  LResult := @FSentinel;
  Result := FRoot;

  while Result <> @FSentinel do
  begin
    LCompareResult := FCompareMethod(aKey, PNode(Result)^.Key, nil);

    if LCompareResult <= 0 then
    begin
      LResult := Result;
      Result := PNode(Result)^.Left;
    end
    else
      Result := PNode(Result)^.Right;
  end;

  if LResult = @FSentinel then
    Result := nil
  else
    Result := LResult;
end;

function TRedBlackTree.GetUpperBoundNode(const aKey: K): PNode;
var
  LResult: PNode;
  LCompareResult: SizeInt;
begin
  LResult := @FSentinel;
  Result := FRoot;

  while Result <> @FSentinel do
  begin
    LCompareResult := FCompareMethod(aKey, PNode(Result)^.Key, nil);

    if LCompareResult < 0 then
    begin
      LResult := Result;
      Result := PNode(Result)^.Left;
    end
    else
      Result := PNode(Result)^.Right;
  end;

  if LResult = @FSentinel then
    Result := nil
  else
    Result := LResult;
end;

{ API 实现 }

function TRedBlackTree.Get(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
begin
  LNode := FindNode(aKey);
  if LNode <> nil then
  begin
    aValue := LNode^.Value;
    Result := True;
  end
  else
    Result := False;
end;

function TRedBlackTree.Put(const aKey: K; const aValue: V): Boolean;
var
  LExisted: Boolean;
  LNode: PNode;
begin
  LNode := InsertNode(aKey, aValue, LExisted);
  Result := LExisted;
end;

function TRedBlackTree.Remove(const aKey: K): Boolean;
var
  LNode, LSuccessor, LChild, LChildParent: PNode;
  LOriginalColor: UInt8;
begin
  LNode := FindNode(aKey);
  if LNode = nil then
    Exit(False);

  LSuccessor := LNode;
  LOriginalColor := LSuccessor^.Color;
  if LNode^.Left = @FSentinel then
  begin
    LChild := PNode(LNode^.Right);
    LChildParent := LNode^.Parent;
    Transplant(LNode, LChild);
  end
  else if LNode^.Right = @FSentinel then
  begin
    LChild := PNode(LNode^.Left);
    LChildParent := LNode^.Parent;
    Transplant(LNode, LChild);
  end
  else
  begin
    LSuccessor := GetMinimum(PNode(LNode^.Right));
    LOriginalColor := LSuccessor^.Color;
    LChild := PNode(LSuccessor^.Right);
    if LSuccessor^.Parent = LNode then
      LChildParent := LSuccessor
    else
    begin
      LChildParent := LSuccessor^.Parent;
      Transplant(LSuccessor, LChild);
      LSuccessor^.Right := LNode^.Right;
      PNode(LSuccessor^.Right)^.Parent := LSuccessor;
    end;
    Transplant(LNode, LSuccessor);
    LSuccessor^.Left := LNode^.Left;
    PNode(LSuccessor^.Left)^.Parent := LSuccessor;
    LSuccessor^.Color := LNode^.Color;
  end;

  DeallocateNode(LNode);
  Dec(FCount);

  if LOriginalColor = 1 then
    FixDelete(LChild, LChildParent);

  Result := True;
end;

procedure TRedBlackTree.InOrderTraversal(aNode: PNode; const aCallback: specialize TKeyValueCallback<K, V>);
var
  LEntry: TMapEntryType;
begin
  if (aNode = nil) or (aNode = @FSentinel) then
    Exit;

  InOrderTraversal(PNode(aNode^.Left), aCallback);

  LEntry.Key := aNode^.Key;
  LEntry.Value := aNode^.Value;
  aCallback(LEntry, nil);

  InOrderTraversal(PNode(aNode^.Right), aCallback);
end;

function TRedBlackTree.ContainsKey(const aKey: K): Boolean;
begin
  Result := FindNode(aKey) <> nil;
end;

function TRedBlackTree.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TRedBlackTree.GetLowerBound(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
begin
  LNode := GetLowerBoundNode(aKey);
  if LNode <> nil then
  begin
    aValue := LNode^.Value;
    Result := True;
  end
  else
    Result := False;
end;

function TRedBlackTree.GetUpperBound(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
begin
  LNode := GetUpperBoundNode(aKey);
  if LNode <> nil then
  begin
    aValue := LNode^.Value;
    Result := True;
  end
  else
    Result := False;
end;

function TRedBlackTree.GetRange(const aLow, aHigh: K; const aCallback: specialize TKeyValueCallback<K, V>): Boolean;
{**
 * 实现范围查询 (GetRange)
 *
 * 功能：遍历并访问键在 [aLow, aHigh] 范围内的所有节点
 * 方法：中序遍历，只访问范围内的节点
 * 参数：
 *   aLow - 范围下限（包含）
 *   aHigh - 范围上限（包含）
 *   aCallback - 对每个匹配节点调用的回调函数
 * 返回值：
 *   始终返回 True（范围查询不失败）
 *}
var
  LStartNode: PNode;
  LCurrent: PNode;
  LEntry: TMapEntryType;
  LCompareHigh: SizeInt;
begin
  Result := True;
  if FRoot = @FSentinel then Exit;

  { 找到范围内的第一个节点 }
  LStartNode := GetLowerBoundNode(aLow);
  if LStartNode = nil then Exit;  { 没有节点 >= aLow }

  LCurrent := LStartNode;

  { 遍历范围内的节点，直到超出 aHigh }
  while LCurrent <> nil do
  begin
    LCompareHigh := FCompareMethod(aHigh, PNode(LCurrent)^.Key, nil);
    if LCompareHigh < 0 then
      Break;  { 当前节点键 > aHigh，结束 }

    { 调用回调函数 }
    LEntry.Key := LCurrent^.Key;
    LEntry.Value := LCurrent^.Value;
    aCallback(LEntry, nil);

    { 移动到下一个节点（中序遍历的后继）}
    LCurrent := GetSuccessor(LCurrent);
    if LCurrent = @FSentinel then
      LCurrent := nil;
  end;
end;

function TRedBlackTree.Ceiling(const aKey: K; out aValue: V): Boolean;
begin
  Result := GetLowerBound(aKey, aValue);
end;

function TRedBlackTree.Floor(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
  LResult: PNode;
  LCompareResult: SizeInt;
begin
  LNode := FRoot;
  LResult := @FSentinel;
  while LNode <> @FSentinel do
  begin
    LCompareResult := FCompareMethod(aKey, PNode(LNode)^.Key, nil);

    if LCompareResult < 0 then
    begin
      { 键大于当前节点，可能在左子树 }
      LNode := PNode(LNode)^.Left;
    end
    else
    begin
      { 键小于等于当前节点，记录当前节点，可能在右子树找到更优解 }
      LResult := LNode;
      LNode := PNode(LNode)^.Right;
    end;
  end;

  if LResult <> @FSentinel then
  begin
    aValue := LResult^.Value;
    Result := True;
  end
  else
    Result := False;
end;

function TRedBlackTree.GetKeys: TCollection;
{**
 * 获取所有键的集合 (GetKeys)
 *
 * 功能：遍历树并返回包含所有键的集合
 * 方法：递归中序遍历，收集所有键
 * 返回值：
 *   TCollection - 包含所有键的新集合
 *   调用者负责释放返回的集合
 *}
var
  LKeyArray: array of K;
  LCount: SizeUInt;

  { 内部递归遍历收集键 }
  procedure CollectKeys(aNode: PNode);
  begin
    if (aNode = nil) or (aNode = @FSentinel) then Exit;

    CollectKeys(PNode(aNode^.Left));
    LKeyArray[LCount] := aNode^.Key;
    Inc(LCount);
    CollectKeys(PNode(aNode^.Right));
  end;

begin
  if FRoot = @FSentinel then
  begin
    { 空树返回空集合 }
    Result := specialize TArray<K>.Create(FAllocator);
    Exit;
  end;

  { 创建新数组并预分配容量 }
  LCount := 0;
  SetLength(LKeyArray, FCount);

  { 递归遍历树并收集键 }
  CollectKeys(FRoot);

  { 调整数组大小到实际元素数量 }
  SetLength(LKeyArray, LCount);

  { 创建集合并加载数据 }
  Result := specialize TArray<K>.Create(Pointer(LKeyArray), LCount, FAllocator);
end;

function TRedBlackTree.GetValues: TCollection;
{**
 * 获取所有值的集合 (GetValues)
 *
 * 功能：遍历树并返回包含所有值的集合
 * 方法：递归中序遍历，收集所有值
 * 返回值：
 *   TCollection - 包含所有值的新集合
 *   调用者负责释放返回的集合
 *}
var
  LValueArray: array of V;
  LCount: SizeUInt;

  { 内部递归遍历收集值 }
  procedure CollectValues(aNode: PNode);
  begin
    if (aNode = nil) or (aNode = @FSentinel) then Exit;

    CollectValues(PNode(aNode^.Left));
    LValueArray[LCount] := aNode^.Value;
    Inc(LCount);
    CollectValues(PNode(aNode^.Right));
  end;

begin
  if FRoot = @FSentinel then
  begin
    { 空树返回空集合 }
    Result := specialize TArray<V>.Create(FAllocator);
    Exit;
  end;

  { 创建新数组并预分配容量 }
  LCount := 0;
  SetLength(LValueArray, FCount);

  { 递归遍历树并收集值 }
  CollectValues(FRoot);

  { 调整数组大小到实际元素数量 }
  SetLength(LValueArray, LCount);

  { 创建集合并加载数据 }
  Result := specialize TArray<V>.Create(Pointer(LValueArray), LCount, FAllocator);
end;

procedure TRedBlackTree.FreeNodeAndChildren(aNode: PNode);
begin
  if (aNode = nil) or (aNode = @FSentinel) then Exit;

  { 递归释放左右子树 }
  if aNode^.Left <> @FSentinel then
    FreeNodeAndChildren(PNode(aNode^.Left));

  if aNode^.Right <> @FSentinel then
    FreeNodeAndChildren(PNode(aNode^.Right));

  { 释放当前节点 }
  DeallocateNode(aNode);
end;

procedure TRedBlackTree.Clear;
begin
  { 递归释放所有节点 }
  if FRoot <> @FSentinel then
    FreeNodeAndChildren(FRoot);

  InitTree;
end;

{ TTreeMap }

constructor TTreeMap.Create(const aAllocator: IAllocator; const aCompare: TKeyCompareFunc);
begin
  FComparer := aCompare;
  inherited Create(aAllocator, nil);
end;

procedure TTreeMap.AfterConstruction;
var
  LCompare: TKeyCompareFunc;
begin
  inherited AfterConstruction;
  if Assigned(FComparer) then
    LCompare := FComparer
  else
    LCompare := TKeyCompareFunc(Data);

  if not Assigned(LCompare) then
    raise EArgumentNil.Create('TTreeMap.AfterConstruction: compare function cannot be nil');

  if FAllocator = nil then
    FAllocator := GetRtlAllocator;

  FTree := TRedBlackTreeType.Create(FAllocator, LCompare);
  FComparer := nil;
  Data := nil;
end;

destructor TTreeMap.Destroy;
begin
  FTree.Free;
  inherited Destroy;
end;

function TTreeMap.GetCount: SizeUInt;
begin
  Result := FTree.GetCount;
end;

function TTreeMap.GetLowerBound(const aKey: K; out aValue: V): Boolean;
begin
  Result := FTree.GetLowerBound(aKey, aValue);
end;

function TTreeMap.GetUpperBound(const aKey: K; out aValue: V): Boolean;
begin
  Result := FTree.GetUpperBound(aKey, aValue);
end;

function TTreeMap.GetRange(const aLow, aHigh: K; const aCallback: specialize TKeyValueCallback<K, V>): Boolean;
begin
  Result := FTree.GetRange(aLow, aHigh, aCallback);
end;

function TTreeMap.Ceiling(const aKey: K; out aValue: V): Boolean;
begin
  Result := FTree.Ceiling(aKey, aValue);
end;

function TTreeMap.Floor(const aKey: K; out aValue: V): Boolean;
begin
  Result := FTree.Floor(aKey, aValue);
end;

function TTreeMap.Get(const aKey: K; out aValue: V): Boolean;
begin
  Result := FTree.Get(aKey, aValue);
end;

function TTreeMap.Put(const aKey: K; const aValue: V): Boolean;
begin
  Result := FTree.Put(aKey, aValue);
end;

function TTreeMap.Remove(const aKey: K): Boolean;
begin
  Result := FTree.Remove(aKey);
end;

function TTreeMap.ContainsKey(const aKey: K): Boolean;
begin
  Result := FTree.ContainsKey(aKey);
end;

function TTreeMap.GetKeyCount: SizeUInt;
begin
  Result := FTree.GetCount;
end;

function TTreeMap.GetKeys: TCollection;
begin
  Result := FTree.GetKeys;
end;

function TTreeMap.GetValues: TCollection;
begin
  Result := FTree.GetValues;
end;

procedure TTreeMap.Clear;
begin
  FTree.Clear;
end;

function TTreeMap.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // TreeMap uses non-contiguous node-based storage, no overlap possible
  Result := False;
end;

function TTreeMap.DoIterGetCurrent(aIter: PPtrIter): Pointer;
type
  PNodeType = TRedBlackTreeType.PNode;
begin
  if (aIter = nil) or (aIter^.Data = nil) then
    Exit(nil);
  // Return pointer to the entry (key-value pair)
  Result := aIter^.Data;
end;

function TTreeMap.DoIterMoveNext(aIter: PPtrIter): Boolean;
type
  PNodeType = TRedBlackTreeType.PNode;
var
  LNode: PNodeType;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    // Start from minimum (leftmost) node
    if FTree.GetCount = 0 then
    begin
      aIter^.Data := nil;
      Exit(False);
    end;
    LNode := FTree.GetMinimum(FTree.FRoot);
    if (LNode = nil) or (LNode = @FTree.FSentinel) then
    begin
      aIter^.Data := nil;
      Exit(False);
    end;
    aIter^.Data := LNode;
    Result := True;
  end
  else if aIter^.Data <> nil then
  begin
    LNode := FTree.GetSuccessor(PNodeType(aIter^.Data));
    if (LNode = nil) or (LNode = @FTree.FSentinel) then
    begin
      aIter^.Data := nil;
      Exit(False);
    end;
    aIter^.Data := LNode;
    Result := True;
  end
  else
    Result := False;
end;

function TTreeMap.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, nil);
end;

procedure TTreeMap.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
type
  PNodeType = TRedBlackTreeType.PNode;
var
  LDstEntry: PEntryType;
  LNode: PNodeType;
  i: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;

  LDstEntry := PEntryType(aDst);
  LNode := FTree.GetMinimum(FTree.FRoot);
  i := 0;

  while (LNode <> nil) and (LNode <> @FTree.FSentinel) and (i < aCount) do
  begin
    LDstEntry^.Key := LNode^.Key;
    LDstEntry^.Value := LNode^.Value;
    Inc(LDstEntry);
    Inc(i);
    LNode := FTree.GetSuccessor(LNode);
  end;
end;

procedure TTreeMap.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  LSrcEntry: PEntryType;
  i: SizeUInt;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LSrcEntry := PEntryType(aSrc);
  for i := 0 to aElementCount - 1 do
  begin
    FTree.Put(LSrcEntry^.Key, LSrcEntry^.Value);
    Inc(LSrcEntry);
  end;
end;

procedure TTreeMap.AppendToUnChecked(const aDst: TCollection);
type
  PNodeType = TRedBlackTreeType.PNode;
var
  LNode: PNodeType;
  LEntry: TEntryType;
begin
  if aDst = nil then
    Exit;

  // In-order traversal and append each entry
  LNode := FTree.GetMinimum(FTree.FRoot);
  while (LNode <> nil) and (LNode <> @FTree.FSentinel) do
  begin
    LEntry.Key := LNode^.Key;
    LEntry.Value := LNode^.Value;
    aDst.AppendUnChecked(@LEntry, 1);
    LNode := FTree.GetSuccessor(LNode);
  end;
end;

procedure TTreeMap.DoZero;
type
  PNodeType = TRedBlackTreeType.PNode;
var
  LNode: PNodeType;
  LZeroValue: V;
begin
  // Zero all values while preserving keys
  FillChar(LZeroValue, SizeOf(V), 0);

  LNode := FTree.GetMinimum(FTree.FRoot);
  while (LNode <> nil) and (LNode <> @FTree.FSentinel) do
  begin
    LNode^.Value := LZeroValue;
    LNode := FTree.GetSuccessor(LNode);
  end;
end;

procedure TTreeMap.DoReverse;
begin
  // TreeMap is ordered by keys, reversing has no meaningful semantic
  // This is a no-op for ordered containers
end;

{ Entry API implementation }

function TTreeMap.GetOrInsert(const AKey: K; const ADefault: V): V;
begin
  if FTree.Get(AKey, Result) then
    Exit;
  // Key doesn't exist - insert default
  FTree.Put(AKey, ADefault);
  Result := ADefault;
end;

function TTreeMap.GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
begin
  if FTree.Get(AKey, Result) then
    Exit;
  // Key doesn't exist - call supplier
  Result := ASupplier();
  FTree.Put(AKey, Result);
end;

procedure TTreeMap.ModifyOrInsert(const AKey: K; AModifier: TValueModifier; const ADefault: V);
type
  PNodeType = TRedBlackTreeType.PNode;
var
  LNode: PNodeType;
begin
  LNode := FTree.FindNode(AKey);
  if LNode <> nil then
    // Key exists - modify in place
    AModifier(LNode^.Value)
  else
    // Key doesn't exist - insert default
    FTree.Put(AKey, ADefault);
end;

end.
