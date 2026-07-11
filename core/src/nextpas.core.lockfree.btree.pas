unit nextpas.core.lockfree.btree;
{**
 * @desc Concurrent B-Tree using an instance-wide read-write lock.
 *
 * @note This is NOT a lock-free structure. It uses an atomic read-write lock
 *       to keep root replacement and node reclamation safe for readers.
 *       Placed in the lockfree namespace because it uses atomic primitives
 *       and follows the same concurrent data structure patterns.
 *
 * @concurrency Thread-safe for multiple readers and writers:
 *   - Find/Contains/ForEach/ForEachRange: shared read lock
 *   - Insert/Remove/Clear: exclusive write lock
 *
 * @see libart (C) — Adaptive Radix Tree for comparison
 * @see lmdb (C) — B+Tree for comparison
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.thread;

const
  BTREE_ORDER = 64; { Maximum number of keys per node }
  BTREE_MIN_KEYS = BTREE_ORDER div 2 - 1; { Minimum keys per non-root node }
  BTREE_MAX_KEYS = BTREE_ORDER - 1; { Maximum keys per node }

type
  {**
   * 并发 B-Tree。
   *
   * 使用读写锁实现并发安全，支持有序键值对存储和高效范围查询。
   * 读操作 (Find/Contains/Count/ForEach/ForEachRange) 使用无锁读，
   * 写操作 (Insert/Remove/Update) 使用写锁独占访问。
   *
   * @constraints
   *   - TKey 必须支持比较操作 (<, >, =)
   *   - TKey 和 TValue 必须是 unmanaged 类型
   *   - 所有公共方法是线程安全的
   *}
  generic TConcurrentBTreeImpl<TKey, TValue> = class
  public type
    {** @desc ForEach 回调类型 }
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    {** @desc ForEachCtx 带上下文的回调类型 }
    TForEachCtxCallback = procedure(const AKey: TKey; const AValue: TValue; AContext: Pointer);
  private type
    TKeyArray = array of TKey;
    TValueArray = array of TValue;
    PBTreeNode = ^TBTreeNode;
    TBTreeNode = record
      IsLeaf: Boolean;
      KeyCount: Integer;
      Keys: array[0..BTREE_MAX_KEYS - 1] of TKey;
      Values: array[0..BTREE_MAX_KEYS - 1] of TValue;
      Children: array[0..BTREE_ORDER - 1] of PBTreeNode;
    end;
  private
    FRoot: PBTreeNode;
    FSize: Integer;
    FLock: Int32;
    procedure GlobalReadLock;
    procedure GlobalReadUnlock;
    procedure GlobalWriteLock;
    procedure GlobalWriteUnlock;
    {** 辅助方法 }
    function CompareKeys(const AKey1, AKey2: TKey): Integer;
    function CreateNode(AIsLeaf: Boolean): PBTreeNode;
    procedure FreeNode(ANode: PBTreeNode);
    procedure SplitChild(AParent: PBTreeNode; AIndex: Integer);
    procedure InsertNonFull(ANode: PBTreeNode; const AKey: TKey; const AValue: TValue);
    {** Remove 辅助方法 }
    function FindKeyIndex(ANode: PBTreeNode; const AKey: TKey): Integer;
    procedure RemoveFromLeaf(ANode: PBTreeNode; AIndex: Integer);
    procedure RemoveFromInternal(ANode: PBTreeNode; AIndex: Integer);
    function GetPredecessor(ANode: PBTreeNode; out AKey: TKey; out AValue: TValue): Boolean;
    procedure FillChild(AParent: PBTreeNode; AIndex: Integer);
    procedure BorrowFromPrev(AParent: PBTreeNode; AIndex: Integer);
    procedure BorrowFromNext(AParent: PBTreeNode; AIndex: Integer);
    procedure MergeChildren(AParent: PBTreeNode; AIndex: Integer);
    function RemoveInternal(ANode: PBTreeNode; const AKey: TKey): Boolean;
    procedure CollectNode(ANode: PBTreeNode; var AKeys: TKeyArray;
      var AValues: TValueArray; var ACount: Integer);
    procedure CollectRangeNode(ANode: PBTreeNode; const AFrom, ATo: TKey;
      var AKeys: TKeyArray; var AValues: TValueArray; var ACount: Integer);
  public
    {** @desc 创建并发 B-Tree }
    constructor Create;
    destructor Destroy; override;

    {** @desc 插入或更新键值对
      @param AKey 要插入的键
      @param AValue 要插入的值
      @note 如果键已存在，则更新值 }
    procedure Insert(const AKey: TKey; const AValue: TValue);

    {** @desc 查找键值对
      @param AKey 要查找的键
      @param AValue 返回找到的值
      @return 如果找到返回 True }
    function Find(const AKey: TKey; out AValue: TValue): Boolean;

    {** @desc 删除键值对
      @param AKey 要删除的键
      @return 如果删除成功返回 True }
    function Remove(const AKey: TKey): Boolean;

    {** @desc 检查键是否存在
      @param AKey 要检查的键
      @return 如果存在返回 True }
    function Contains(const AKey: TKey): Boolean;

    {** @desc 获取元素数量
      @return 元素数量 }
    function Count: Integer;

    {** @desc 遍历所有元素
      @param ACallback 回调函数 }
    procedure ForEach(const ACallback: TForEachCallback);

    {** @desc 遍历所有元素（带上下文）
      @param ACallback 回调函数
      @param AContext 上下文指针 }
    procedure ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);

    {** @desc 范围查询
      @param AFrom 起始键（包含）
      @param ATo 结束键（包含）
      @param ACallback 回调函数 }
    procedure ForEachRange(const AFrom, ATo: TKey; const ACallback: TForEachCallback);

    {** @desc 清空所有元素 }
    procedure Clear;
  end;

  generic TConcurrentBTree<TKey, TValue> = class(specialize TConcurrentBTreeImpl<TKey, TValue>)
  end;

implementation

constructor TConcurrentBTreeImpl.Create;
begin
  inherited Create;
  if IsManagedType(TKey) or IsManagedType(TValue) then
    raise EArgumentError.Create('TConcurrentBTree: TKey and TValue must be unmanaged');

  FRoot := CreateNode(True);
  FSize := 0;
  FLock := 0;
end;

destructor TConcurrentBTreeImpl.Destroy;
begin
  FreeNode(FRoot);
  inherited;
end;

function TConcurrentBTreeImpl.CreateNode(AIsLeaf: Boolean): PBTreeNode;
var
  LI: Integer;
begin
  New(Result);
  Result^.IsLeaf := AIsLeaf;
  Result^.KeyCount := 0;
  for LI := 0 to BTREE_MAX_KEYS - 1 do
  begin
    Result^.Keys[LI] := Default(TKey);
    Result^.Values[LI] := Default(TValue);
  end;
  for LI := 0 to BTREE_ORDER - 1 do
    Result^.Children[LI] := nil;
end;

procedure TConcurrentBTreeImpl.FreeNode(ANode: PBTreeNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;
  if not ANode^.IsLeaf then
  begin
    for LI := 0 to ANode^.KeyCount do
      FreeNode(ANode^.Children[LI]);
  end;
  Dispose(ANode);
end;

function TConcurrentBTreeImpl.CompareKeys(const AKey1, AKey2: TKey): Integer;
begin
  if AKey1 < AKey2 then
    Result := -1
  else if AKey1 > AKey2 then
    Result := 1
  else
    Result := 0;
end;

procedure TConcurrentBTreeImpl.GlobalReadLock;
var
  LLock: Int32;
  LSpins: Int32;
begin
  LSpins := 0;
  repeat
    LLock := AtomicLoad32(FLock, moRelaxed);
    if LLock >= 0 then
    begin
      if AtomicCompareExchange32(FLock, LLock, LLock + 1, moAcquire) = LLock then
        Exit;
    end;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      platform_thread_yield;
    end;
  until False;
end;

procedure TConcurrentBTreeImpl.GlobalReadUnlock;
begin
  AtomicFetchSub32(FLock, 1, moRelease);
end;

procedure TConcurrentBTreeImpl.GlobalWriteLock;
var
  LSpins: Int32;
begin
  LSpins := 0;
  repeat
    if AtomicCompareExchange32(FLock, 0, -1, moAcquire) = 0 then
      Exit;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      platform_thread_yield;
    end;
  until False;
end;

procedure TConcurrentBTreeImpl.GlobalWriteUnlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TConcurrentBTreeImpl.SplitChild(AParent: PBTreeNode; AIndex: Integer);
var
  LChild: PBTreeNode;
  LNewNode: PBTreeNode;
  LI: Integer;
begin
  LChild := AParent^.Children[AIndex];
  LNewNode := CreateNode(LChild^.IsLeaf);
  LNewNode^.KeyCount := BTREE_MIN_KEYS;

  { Copy the last (BTREE_ORDER-1)/2 keys to the new node }
  for LI := 0 to BTREE_MIN_KEYS - 1 do
  begin
    LNewNode^.Keys[LI] := LChild^.Keys[LI + BTREE_MIN_KEYS + 1];
    LNewNode^.Values[LI] := LChild^.Values[LI + BTREE_MIN_KEYS + 1];
  end;

  { Copy the last (BTREE_ORDER)/2 children to the new node }
  if not LChild^.IsLeaf then
  begin
    for LI := 0 to BTREE_MIN_KEYS do
      LNewNode^.Children[LI] := LChild^.Children[LI + BTREE_MIN_KEYS + 1];
  end;

  LChild^.KeyCount := BTREE_MIN_KEYS;

  { Shift children of parent to make room for the new child }
  for LI := AParent^.KeyCount downto AIndex + 1 do
    AParent^.Children[LI + 1] := AParent^.Children[LI];
  AParent^.Children[AIndex + 1] := LNewNode;

  { Shift keys of parent to make room for the middle key }
  for LI := AParent^.KeyCount - 1 downto AIndex do
  begin
    AParent^.Keys[LI + 1] := AParent^.Keys[LI];
    AParent^.Values[LI + 1] := AParent^.Values[LI];
  end;
  AParent^.Keys[AIndex] := LChild^.Keys[BTREE_MIN_KEYS];
  AParent^.Values[AIndex] := LChild^.Values[BTREE_MIN_KEYS];
  Inc(AParent^.KeyCount);
end;

procedure TConcurrentBTreeImpl.InsertNonFull(ANode: PBTreeNode; const AKey: TKey; const AValue: TValue);
var
  LI: Integer;
begin
  if ANode^.IsLeaf then
  begin
    { Insert into leaf node }
    LI := ANode^.KeyCount - 1;
    while (LI >= 0) and (CompareKeys(ANode^.Keys[LI], AKey) > 0) do
    begin
      ANode^.Keys[LI + 1] := ANode^.Keys[LI];
      ANode^.Values[LI + 1] := ANode^.Values[LI];
      Dec(LI);
    end;

    if (LI >= 0) and (CompareKeys(ANode^.Keys[LI], AKey) = 0) then
    begin
      { Update existing key }
      ANode^.Values[LI] := AValue;
    end
    else
    begin
      { Insert new key }
      ANode^.Keys[LI + 1] := AKey;
      ANode^.Values[LI + 1] := AValue;
      Inc(ANode^.KeyCount);
      AtomicFetchAdd32(FSize, 1, moRelaxed);
    end;
  end
  else
  {
    Insert into internal node
  }
  begin
    LI := ANode^.KeyCount - 1;
    while (LI >= 0) and (CompareKeys(ANode^.Keys[LI], AKey) > 0) do
      Dec(LI);

    if (LI >= 0) and (CompareKeys(ANode^.Keys[LI], AKey) = 0) then
    begin
      { Update existing key }
      ANode^.Values[LI] := AValue;
      Exit;
    end;

    Inc(LI);
    if ANode^.Children[LI]^.KeyCount = BTREE_MAX_KEYS then
    begin
      SplitChild(ANode, LI);
      if CompareKeys(ANode^.Keys[LI], AKey) < 0 then
        Inc(LI);
    end;
    InsertNonFull(ANode^.Children[LI], AKey, AValue);
  end;
end;

procedure TConcurrentBTreeImpl.Insert(const AKey: TKey; const AValue: TValue);
var
  LNewRoot: PBTreeNode;
begin
  GlobalWriteLock;
  try
    if FRoot^.KeyCount = BTREE_MAX_KEYS then
    begin
      LNewRoot := CreateNode(False);
      LNewRoot^.Children[0] := FRoot;
      SplitChild(LNewRoot, 0);
      FRoot := LNewRoot;
    end;
    InsertNonFull(FRoot, AKey, AValue);
  finally
    GlobalWriteUnlock;
  end;
end;

function TConcurrentBTreeImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LCurrent: PBTreeNode;
  LI: Integer;
begin
  GlobalReadLock;
  try
    LCurrent := FRoot;
    while True do
    begin
      LI := 0;
      while (LI < LCurrent^.KeyCount) and (CompareKeys(LCurrent^.Keys[LI], AKey) < 0) do
        Inc(LI);

      if (LI < LCurrent^.KeyCount) and (CompareKeys(LCurrent^.Keys[LI], AKey) = 0) then
      begin
        AValue := LCurrent^.Values[LI];
        Exit(True);
      end;

      if LCurrent^.IsLeaf then
        Exit(False);

      LCurrent := LCurrent^.Children[LI];
    end;
  finally
    GlobalReadUnlock;
  end;
end;

function TConcurrentBTreeImpl.FindKeyIndex(ANode: PBTreeNode; const AKey: TKey): Integer;
begin
  Result := 0;
  while (Result < ANode^.KeyCount) and (CompareKeys(ANode^.Keys[Result], AKey) < 0) do
    Inc(Result);
end;

procedure TConcurrentBTreeImpl.RemoveFromLeaf(ANode: PBTreeNode; AIndex: Integer);
var
  LI: Integer;
begin
  for LI := AIndex to ANode^.KeyCount - 2 do
  begin
    ANode^.Keys[LI] := ANode^.Keys[LI + 1];
    ANode^.Values[LI] := ANode^.Values[LI + 1];
  end;
  ANode^.Keys[ANode^.KeyCount - 1] := Default(TKey);
  ANode^.Values[ANode^.KeyCount - 1] := Default(TValue);
  Dec(ANode^.KeyCount);
  AtomicFetchSub32(FSize, 1, moRelaxed);
end;

function TConcurrentBTreeImpl.GetPredecessor(ANode: PBTreeNode; out AKey: TKey; out AValue: TValue): Boolean;
var
  LCurrent: PBTreeNode;
begin
  LCurrent := ANode;
  while not LCurrent^.IsLeaf do
    LCurrent := LCurrent^.Children[LCurrent^.KeyCount];
  if LCurrent^.KeyCount > 0 then
  begin
    AKey := LCurrent^.Keys[LCurrent^.KeyCount - 1];
    AValue := LCurrent^.Values[LCurrent^.KeyCount - 1];
    Result := True;
  end
  else
    Result := False;
end;

procedure TConcurrentBTreeImpl.BorrowFromPrev(AParent: PBTreeNode; AIndex: Integer);
var
  LChild: PBTreeNode;
  LSibling: PBTreeNode;
  LI: Integer;
begin
  LChild := AParent^.Children[AIndex];
  LSibling := AParent^.Children[AIndex - 1];

  { Shift child keys right }
  for LI := LChild^.KeyCount - 1 downto 0 do
  begin
    LChild^.Keys[LI + 1] := LChild^.Keys[LI];
    LChild^.Values[LI + 1] := LChild^.Values[LI];
  end;

  { Shift child children right }
  if not LChild^.IsLeaf then
  begin
    for LI := LChild^.KeyCount downto 0 do
      LChild^.Children[LI + 1] := LChild^.Children[LI];
  end;

  { Move parent key down to child }
  LChild^.Keys[0] := AParent^.Keys[AIndex - 1];
  LChild^.Values[0] := AParent^.Values[AIndex - 1];

  { Move sibling's last child to child's first child }
  if not LChild^.IsLeaf then
    LChild^.Children[0] := LSibling^.Children[LSibling^.KeyCount];

  { Move sibling's last key up to parent }
  AParent^.Keys[AIndex - 1] := LSibling^.Keys[LSibling^.KeyCount - 1];
  AParent^.Values[AIndex - 1] := LSibling^.Values[LSibling^.KeyCount - 1];

  Dec(LSibling^.KeyCount);
  Inc(LChild^.KeyCount);
end;

procedure TConcurrentBTreeImpl.BorrowFromNext(AParent: PBTreeNode; AIndex: Integer);
var
  LChild: PBTreeNode;
  LSibling: PBTreeNode;
  LI: Integer;
begin
  LChild := AParent^.Children[AIndex];
  LSibling := AParent^.Children[AIndex + 1];

  { Move parent key down to child's last position }
  LChild^.Keys[LChild^.KeyCount] := AParent^.Keys[AIndex];
  LChild^.Values[LChild^.KeyCount] := AParent^.Values[AIndex];

  { Move sibling's first child to child's last child }
  if not LChild^.IsLeaf then
    LChild^.Children[LChild^.KeyCount + 1] := LSibling^.Children[0];

  { Move sibling's first key up to parent }
  AParent^.Keys[AIndex] := LSibling^.Keys[0];
  AParent^.Values[AIndex] := LSibling^.Values[0];

  { Shift sibling keys left }
  for LI := 0 to LSibling^.KeyCount - 2 do
  begin
    LSibling^.Keys[LI] := LSibling^.Keys[LI + 1];
    LSibling^.Values[LI] := LSibling^.Values[LI + 1];
  end;
  LSibling^.Keys[LSibling^.KeyCount - 1] := Default(TKey);
  LSibling^.Values[LSibling^.KeyCount - 1] := Default(TValue);

  { Shift sibling children left }
  if not LSibling^.IsLeaf then
  begin
    for LI := 0 to LSibling^.KeyCount - 1 do
      LSibling^.Children[LI] := LSibling^.Children[LI + 1];
    LSibling^.Children[LSibling^.KeyCount] := nil;
  end;

  Inc(LChild^.KeyCount);
  Dec(LSibling^.KeyCount);
end;

procedure TConcurrentBTreeImpl.MergeChildren(AParent: PBTreeNode; AIndex: Integer);
var
  LChild: PBTreeNode;
  LSibling: PBTreeNode;
  LI: Integer;
begin
  LChild := AParent^.Children[AIndex];
  LSibling := AParent^.Children[AIndex + 1];

  { Move parent key to child }
  LChild^.Keys[BTREE_MIN_KEYS] := AParent^.Keys[AIndex];
  LChild^.Values[BTREE_MIN_KEYS] := AParent^.Values[AIndex];

  { Copy sibling's keys to child }
  for LI := 0 to LSibling^.KeyCount - 1 do
  begin
    LChild^.Keys[BTREE_MIN_KEYS + 1 + LI] := LSibling^.Keys[LI];
    LChild^.Values[BTREE_MIN_KEYS + 1 + LI] := LSibling^.Values[LI];
  end;

  { Copy sibling's children to child }
  if not LChild^.IsLeaf then
  begin
    for LI := 0 to LSibling^.KeyCount do
      LChild^.Children[BTREE_MIN_KEYS + 1 + LI] := LSibling^.Children[LI];
  end;

  LChild^.KeyCount := BTREE_MAX_KEYS;

  { Shift parent's keys and children }
  for LI := AIndex to AParent^.KeyCount - 2 do
  begin
    AParent^.Keys[LI] := AParent^.Keys[LI + 1];
    AParent^.Values[LI] := AParent^.Values[LI + 1];
  end;
  AParent^.Keys[AParent^.KeyCount - 1] := Default(TKey);
  AParent^.Values[AParent^.KeyCount - 1] := Default(TValue);

  for LI := AIndex + 1 to AParent^.KeyCount - 1 do
    AParent^.Children[LI] := AParent^.Children[LI + 1];
  AParent^.Children[AParent^.KeyCount] := nil;

  Dec(AParent^.KeyCount);

  { Free sibling }
  Dispose(LSibling);
end;

procedure TConcurrentBTreeImpl.FillChild(AParent: PBTreeNode; AIndex: Integer);
begin
  { Try to borrow from left sibling }
  if (AIndex > 0) and (AParent^.Children[AIndex - 1]^.KeyCount > BTREE_MIN_KEYS) then
    BorrowFromPrev(AParent, AIndex)
  { Try to borrow from right sibling }
  else if (AIndex < AParent^.KeyCount) and (AParent^.Children[AIndex + 1]^.KeyCount > BTREE_MIN_KEYS) then
    BorrowFromNext(AParent, AIndex)
  { Merge with a sibling }
  else
  begin
    if AIndex < AParent^.KeyCount then
      MergeChildren(AParent, AIndex)
    else
      MergeChildren(AParent, AIndex - 1);
  end;
end;

procedure TConcurrentBTreeImpl.RemoveFromInternal(ANode: PBTreeNode; AIndex: Integer);
var
  LKey: TKey;
  LValue: TValue;
begin
  if ANode^.Children[AIndex]^.KeyCount > BTREE_MIN_KEYS then
  begin
    { Get predecessor }
    GetPredecessor(ANode^.Children[AIndex], LKey, LValue);
    ANode^.Keys[AIndex] := LKey;
    ANode^.Values[AIndex] := LValue;
    RemoveInternal(ANode^.Children[AIndex], LKey);
  end
  else if ANode^.Children[AIndex + 1]^.KeyCount > BTREE_MIN_KEYS then
  begin
    { Get successor - simplified: take first key from right child }
    LKey := ANode^.Children[AIndex + 1]^.Keys[0];
    LValue := ANode^.Children[AIndex + 1]^.Values[0];
    ANode^.Keys[AIndex] := LKey;
    ANode^.Values[AIndex] := LValue;
    RemoveInternal(ANode^.Children[AIndex + 1], LKey);
  end
  else
  begin
    { Merge children and recurse }
    MergeChildren(ANode, AIndex);
    RemoveInternal(ANode^.Children[AIndex], ANode^.Keys[AIndex]);
  end;
end;

function TConcurrentBTreeImpl.RemoveInternal(ANode: PBTreeNode; const AKey: TKey): Boolean;
var
  LIndex: Integer;
begin
  LIndex := FindKeyIndex(ANode, AKey);

  if (LIndex < ANode^.KeyCount) and (CompareKeys(ANode^.Keys[LIndex], AKey) = 0) then
  begin
    if ANode^.IsLeaf then
    begin
      RemoveFromLeaf(ANode, LIndex);
      Result := True;
    end
    else
    begin
      RemoveFromInternal(ANode, LIndex);
      Result := True;
    end;
  end
  else
  begin
    if ANode^.IsLeaf then
      Exit(False);

    if ANode^.Children[LIndex]^.KeyCount < BTREE_MIN_KEYS + 1 then
      FillChild(ANode, LIndex);

    if LIndex > ANode^.KeyCount then
      Result := RemoveInternal(ANode^.Children[ANode^.KeyCount], AKey)
    else
      Result := RemoveInternal(ANode^.Children[LIndex], AKey);
  end;
end;

function TConcurrentBTreeImpl.Remove(const AKey: TKey): Boolean;
var
  LNewChild: PBTreeNode;
begin
  GlobalWriteLock;
  try
    Result := RemoveInternal(FRoot, AKey);

    { If root is empty and has children, make first child the new root }
    if (FRoot^.KeyCount = 0) and (not FRoot^.IsLeaf) then
    begin
      LNewChild := FRoot^.Children[0];
      Dispose(FRoot);
      FRoot := LNewChild;
    end;
  finally
    GlobalWriteUnlock;
  end;
end;

function TConcurrentBTreeImpl.Contains(const AKey: TKey): Boolean;
var
  LDummy: TValue;
begin
  Result := Find(AKey, LDummy);
end;

function TConcurrentBTreeImpl.Count: Integer;
begin
  Result := AtomicLoad32(FSize, moRelaxed);
end;

procedure TConcurrentBTreeImpl.CollectNode(ANode: PBTreeNode;
  var AKeys: TKeyArray; var AValues: TValueArray; var ACount: Integer);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;

  for LI := 0 to ANode^.KeyCount - 1 do
  begin
    if not ANode^.IsLeaf then
      CollectNode(ANode^.Children[LI], AKeys, AValues, ACount);
    AKeys[ACount] := ANode^.Keys[LI];
    AValues[ACount] := ANode^.Values[LI];
    Inc(ACount);
  end;

  if not ANode^.IsLeaf then
    CollectNode(ANode^.Children[ANode^.KeyCount], AKeys, AValues, ACount);
end;

procedure TConcurrentBTreeImpl.ForEach(const ACallback: TForEachCallback);
var
  LKeys: TKeyArray;
  LValues: TValueArray;
  LCount, LI: Integer;
begin
  if not Assigned(ACallback) then
    Exit;
  GlobalReadLock;
  try
    SetLength(LKeys, FSize);
    SetLength(LValues, FSize);
    LCount := 0;
    CollectNode(FRoot, LKeys, LValues, LCount);
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI]);
end;

procedure TConcurrentBTreeImpl.ForEachCtx(
  const ACallback: TForEachCtxCallback; AContext: Pointer);
var
  LKeys: TKeyArray;
  LValues: TValueArray;
  LCount, LI: Integer;
begin
  if not Assigned(ACallback) then
    Exit;
  GlobalReadLock;
  try
    SetLength(LKeys, FSize);
    SetLength(LValues, FSize);
    LCount := 0;
    CollectNode(FRoot, LKeys, LValues, LCount);
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI], AContext);
end;

procedure TConcurrentBTreeImpl.CollectRangeNode(ANode: PBTreeNode;
  const AFrom, ATo: TKey; var AKeys: TKeyArray;
  var AValues: TValueArray; var ACount: Integer);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;

  for LI := 0 to ANode^.KeyCount - 1 do
  begin
    if not ANode^.IsLeaf then
      if CompareKeys(ANode^.Keys[LI], AFrom) > 0 then
        CollectRangeNode(ANode^.Children[LI], AFrom, ATo,
          AKeys, AValues, ACount);

    if (CompareKeys(ANode^.Keys[LI], AFrom) >= 0) and (CompareKeys(ANode^.Keys[LI], ATo) <= 0) then
    begin
      AKeys[ACount] := ANode^.Keys[LI];
      AValues[ACount] := ANode^.Values[LI];
      Inc(ACount);
    end;

    if CompareKeys(ANode^.Keys[LI], ATo) > 0 then
      Exit;
  end;

  if not ANode^.IsLeaf then
    CollectRangeNode(ANode^.Children[ANode^.KeyCount], AFrom, ATo,
      AKeys, AValues, ACount);
end;

procedure TConcurrentBTreeImpl.ForEachRange(const AFrom, ATo: TKey; const ACallback: TForEachCallback);
var
  LKeys: TKeyArray;
  LValues: TValueArray;
  LCount, LI: Integer;
begin
  if not Assigned(ACallback) then
    Exit;
  GlobalReadLock;
  try
    SetLength(LKeys, FSize);
    SetLength(LValues, FSize);
    LCount := 0;
    CollectRangeNode(FRoot, AFrom, ATo, LKeys, LValues, LCount);
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI]);
end;

procedure TConcurrentBTreeImpl.Clear;
begin
  GlobalWriteLock;
  try
    FreeNode(FRoot);
    FRoot := CreateNode(True);
    AtomicStore32(FSize, 0, moRelaxed);
  finally
    GlobalWriteUnlock;
  end;
end;

end.
