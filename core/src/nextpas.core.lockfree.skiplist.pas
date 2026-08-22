unit nextpas.core.lockfree.skiplist;
{**
 * @desc Concurrent skip list using per-level read-write locks.
 *
 * @note This is NOT a lock-free structure. It uses atomic read-write locks
 *       per level, which provides good performance for read-heavy workloads.
 *       Placed in the lockfree namespace because it uses atomic primitives
 *       and follows the same concurrent data structure patterns.
 *
 * @see crossbeam-skiplist (Rust) — similar concurrent skip list design
 * @see java.util.concurrent.ConcurrentSkipListMap — reference implementation
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

const
  SKIPLIST_MAX_LEVEL = 20;
  SKIPLIST_DEFAULT_MAX_LEVEL = 12;
  SKIPLIST_P = 4; { 1/4 probability for level promotion }

type
  {**
   * 并发跳表。
   *
   * 使用读写锁实现并发安全，支持有序键值对存储。
   * 读操作（Find/Contains/Count/ForEach）允许多读者并发，
   * 写操作（Insert/Remove/Update）独占访问。
   *
   * @constraints
   *   - TKey 必须支持比较操作（<, >, =）
   *   - TKey 和 TValue 必须是 unmanaged 类型
   *   - 所有公共方法是线程安全的
   *}
  generic TConcurrentSkipListImpl<TKey, TValue> = class
  public type
    {** @desc ForEach 回调类型 }
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    {** @desc ForEachCtx 带上下文的回调类型 }
    TForEachCtxCallback = procedure(const AKey: TKey; const AValue: TValue; AContext: Pointer);
  private type
    TKeyArray = array of TKey;
    TValueArray = array of TValue;
    PSkipListNode = ^TSkipListNode;
    TSkipListNode = record
      Key: TKey;
      Value: TValue;
      Next: array[0..SKIPLIST_MAX_LEVEL - 1] of PSkipListNode;
      Level: Integer;
      {** 读写锁: 0=无锁, >0=读锁计数, -1=写锁 }
      Lock: Int32;
    end;
  private
    FHead: PSkipListNode;
    FTail: PSkipListNode;
    FMaxLevel: Integer;
    FSize: Integer;
    FLock: Int32;  // global read-write lock: 0=unlocked, >0=readers, -1=writer
    {** 读写锁方法 }
    procedure NodeReadLock(var ANode: TSkipListNode);
    procedure NodeReadUnlock(var ANode: TSkipListNode);
    procedure NodeWriteLock(var ANode: TSkipListNode);
    procedure NodeWriteUnlock(var ANode: TSkipListNode);
    {** 全局读写锁 }
    procedure GlobalReadLock;
    procedure GlobalReadUnlock;
    procedure GlobalWriteLock;
    procedure GlobalWriteUnlock;
    {** 辅助方法 }
    function RandomLevel: Integer;
    function CompareKeys(const AKey1, AKey2: TKey): Integer;
    procedure FreeNode(ANode: PSkipListNode);
  public
    {** @desc 创建并发跳表
      @param AMaxLevel 最大层数，默认 SKIPLIST_DEFAULT_MAX_LEVEL }
    constructor Create(const AMaxLevel: Integer = SKIPLIST_DEFAULT_MAX_LEVEL);
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
    function Count: Integer; inline;

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

  generic TConcurrentSkipList<TKey, TValue> = class(specialize TConcurrentSkipListImpl<TKey, TValue>)
  end;

implementation

constructor TConcurrentSkipListImpl.Create(const AMaxLevel: Integer);
var
  LI: Integer;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TConcurrentSkipList: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TConcurrentSkipList: TValue must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  if AMaxLevel < 1 then
    raise EArgumentError.Create('TConcurrentSkipList: max level must be >= 1');
  if AMaxLevel > SKIPLIST_MAX_LEVEL then
    raise EArgumentError.Create('TConcurrentSkipList: max level must be <= SKIPLIST_MAX_LEVEL');

  FMaxLevel := AMaxLevel;
  FSize := 0;
  FLock := 0;

  { Create head node with maximum level }
  New(FHead);
  FHead^.Key := Default(TKey);
  FHead^.Value := Default(TValue);
  FHead^.Level := FMaxLevel;
  FHead^.Lock := 0;
  for LI := 0 to FMaxLevel - 1 do
    FHead^.Next[LI] := nil;

  { Create tail sentinel }
  New(FTail);
  FTail^.Key := Default(TKey);
  FTail^.Value := Default(TValue);
  FTail^.Level := 0;
  FTail^.Lock := 0;
  for LI := 0 to FMaxLevel - 1 do
    FTail^.Next[LI] := nil;

  { Point head to tail at all levels }
  for LI := 0 to FMaxLevel - 1 do
    FHead^.Next[LI] := FTail;
end;

destructor TConcurrentSkipListImpl.Destroy;
var
  LNode, LNext: PSkipListNode;
begin
  { Free all nodes }
  LNode := FHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next[0];
    FreeNode(LNode);
    LNode := LNext;
  end;
  inherited;
end;

procedure TConcurrentSkipListImpl.FreeNode(ANode: PSkipListNode);
begin
  if ANode <> nil then
    Dispose(ANode);
end;

function TConcurrentSkipListImpl.RandomLevel: Integer;
var
  LLevel: Integer;
begin
  LLevel := 1;
  while (LLevel < FMaxLevel) and (Random(SKIPLIST_P) = 0) do
    Inc(LLevel);
  Result := LLevel;
end;

function TConcurrentSkipListImpl.CompareKeys(const AKey1, AKey2: TKey): Integer;
begin
  if AKey1 < AKey2 then
    Result := -1
  else if AKey1 > AKey2 then
    Result := 1
  else
    Result := 0;
end;

procedure TConcurrentSkipListImpl.NodeReadLock(var ANode: TSkipListNode);
var
  LLock: Int32;
  LSpins: Int32;
begin
  LSpins := 0;
  repeat
    LLock := atomic_load(ANode.Lock, mo_relaxed);
    if LLock >= 0 then
    begin
      if atomic_compare_exchange_strong(ANode.Lock, LLock, LLock + 1, mo_acquire, mo_relaxed) then
        Exit;
    end;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  until False;
end;

procedure TConcurrentSkipListImpl.NodeReadUnlock(var ANode: TSkipListNode);
begin
  atomic_fetch_sub(ANode.Lock, 1, mo_release);
end;

procedure TConcurrentSkipListImpl.NodeWriteLock(var ANode: TSkipListNode);
var
  LSpins: Int32;
  LCasExpected: Int32;
begin
  LSpins := 0;
  repeat
    LCasExpected := 0;
    if atomic_compare_exchange_strong(ANode.Lock, LCasExpected, -1, mo_acquire, mo_relaxed) then
      Exit;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  until False;
end;

procedure TConcurrentSkipListImpl.NodeWriteUnlock(var ANode: TSkipListNode);
begin
  atomic_store(ANode.Lock, 0, mo_release);
end;

procedure TConcurrentSkipListImpl.GlobalReadLock;
var
  LLock: Int32;
  LSpins: Int32;
begin
  LSpins := 0;
  repeat
    LLock := atomic_load(FLock, mo_relaxed);
    if LLock >= 0 then
    begin
      if atomic_compare_exchange_strong(FLock, LLock, LLock + 1, mo_acquire, mo_relaxed) then
        Exit;
    end;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  until False;
end;

procedure TConcurrentSkipListImpl.GlobalReadUnlock;
begin
  atomic_fetch_sub(FLock, 1, mo_release);
end;

procedure TConcurrentSkipListImpl.GlobalWriteLock;
var
  LSpins: Int32;
  LCasExpected: Int32;
begin
  LSpins := 0;
  repeat
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, -1, mo_acquire, mo_relaxed) then
      Exit;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  until False;
end;

procedure TConcurrentSkipListImpl.GlobalWriteUnlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TConcurrentSkipListImpl.Insert(const AKey: TKey; const AValue: TValue);
var
  LUpdate: array[0..SKIPLIST_MAX_LEVEL - 1] of PSkipListNode;
  LCurrent: PSkipListNode;
  LNext: PSkipListNode;
  LLevel: Integer;
  LI: Integer;
begin
  GlobalWriteLock;
  try
    { Find position for insertion }
    LCurrent := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      LNext := LCurrent^.Next[LI];
      while (LNext <> FTail) and (CompareKeys(LNext^.Key, AKey) < 0) do
      begin
        LCurrent := LNext;
        LNext := LCurrent^.Next[LI];
      end;
      LUpdate[LI] := LCurrent;
    end;

    { Check if key already exists }
    LNext := LCurrent^.Next[0];
    if (LNext <> FTail) and (CompareKeys(LNext^.Key, AKey) = 0) then
    begin
      { Update existing node }
      LNext^.Value := AValue;
      Exit;
    end;

    { Create new node }
    LLevel := RandomLevel;
    New(LCurrent);
    LCurrent^.Key := AKey;
    LCurrent^.Value := AValue;
    LCurrent^.Level := LLevel;
    LCurrent^.Lock := 0;
    for LI := 0 to LLevel - 1 do
      LCurrent^.Next[LI] := nil;

    { Insert at each level }
    for LI := 0 to LLevel - 1 do
    begin
      LCurrent^.Next[LI] := LUpdate[LI]^.Next[LI];
      LUpdate[LI]^.Next[LI] := LCurrent;
    end;

    atomic_fetch_add(FSize, 1, mo_relaxed);
  finally
    GlobalWriteUnlock;
  end;
end;

function TConcurrentSkipListImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LCurrent: PSkipListNode;
  LNext: PSkipListNode;
  LI: Integer;
begin
  GlobalReadLock;
  try
    LCurrent := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      LNext := LCurrent^.Next[LI];
      while (LNext <> FTail) and (CompareKeys(LNext^.Key, AKey) < 0) do
      begin
        LCurrent := LNext;
        LNext := LCurrent^.Next[LI];
      end;
    end;

    LNext := LCurrent^.Next[0];
    if (LNext <> FTail) and (CompareKeys(LNext^.Key, AKey) = 0) then
    begin
      AValue := LNext^.Value;
      Result := True;
    end
    else
      Result := False;
  finally
    GlobalReadUnlock;
  end;
end;

function TConcurrentSkipListImpl.Remove(const AKey: TKey): Boolean;
var
  LUpdate: array[0..SKIPLIST_MAX_LEVEL - 1] of PSkipListNode;
  LCurrent: PSkipListNode;
  LNext: PSkipListNode;
  LI: Integer;
begin
  GlobalWriteLock;
  try
    { Find node to remove }
    LCurrent := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      LNext := LCurrent^.Next[LI];
      while (LNext <> FTail) and (CompareKeys(LNext^.Key, AKey) < 0) do
      begin
        LCurrent := LNext;
        LNext := LCurrent^.Next[LI];
      end;
      LUpdate[LI] := LCurrent;
    end;

    LNext := LCurrent^.Next[0];
    if (LNext = FTail) or (CompareKeys(LNext^.Key, AKey) <> 0) then
      Exit(False);

    { Remove from each level }
    for LI := 0 to LNext^.Level - 1 do
      LUpdate[LI]^.Next[LI] := LNext^.Next[LI];

    atomic_fetch_sub(FSize, 1, mo_relaxed);
    FreeNode(LNext);
    Result := True;
  finally
    GlobalWriteUnlock;
  end;
end;

function TConcurrentSkipListImpl.Contains(const AKey: TKey): Boolean;
var
  LDummy: TValue;
begin
  Result := Find(AKey, LDummy);
end;

function TConcurrentSkipListImpl.Count: Integer; inline;
begin
  Result := atomic_load(FSize, mo_relaxed);
end;

procedure TConcurrentSkipListImpl.ForEach(const ACallback: TForEachCallback);
var
  LNode: PSkipListNode;
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
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      LKeys[LCount] := LNode^.Key;
      LValues[LCount] := LNode^.Value;
      Inc(LCount);
      LNode := LNode^.Next[0];
    end;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI]);
end;

procedure TConcurrentSkipListImpl.ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
var
  LNode: PSkipListNode;
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
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      LKeys[LCount] := LNode^.Key;
      LValues[LCount] := LNode^.Value;
      Inc(LCount);
      LNode := LNode^.Next[0];
    end;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI], AContext);
end;

procedure TConcurrentSkipListImpl.ForEachRange(const AFrom, ATo: TKey; const ACallback: TForEachCallback);
var
  LCurrent: PSkipListNode;
  LNext: PSkipListNode;
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
    { Find starting position }
    LCurrent := FHead;
    for LI := FMaxLevel - 1 downto 0 do
    begin
      LNext := LCurrent^.Next[LI];
      while (LNext <> FTail) and (CompareKeys(LNext^.Key, AFrom) < 0) do
      begin
        LCurrent := LNext;
        LNext := LCurrent^.Next[LI];
      end;
    end;

    { Iterate from start to end }
    LCurrent := LCurrent^.Next[0];
    while (LCurrent <> FTail) and (CompareKeys(LCurrent^.Key, ATo) <= 0) do
    begin
      LKeys[LCount] := LCurrent^.Key;
      LValues[LCount] := LCurrent^.Value;
      Inc(LCount);
      LCurrent := LCurrent^.Next[0];
    end;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
  finally
    GlobalReadUnlock;
  end;
  for LI := 0 to LCount - 1 do
    ACallback(LKeys[LI], LValues[LI]);
end;

procedure TConcurrentSkipListImpl.Clear;
var
  LNode, LNext: PSkipListNode;
  LI: Integer;
begin
  GlobalWriteLock;
  try
    { Free all nodes except head and tail }
    LNode := FHead^.Next[0];
    while LNode <> FTail do
    begin
      LNext := LNode^.Next[0];
      FreeNode(LNode);
      LNode := LNext;
    end;

    { Reset head to point to tail at all levels }
    for LI := 0 to FMaxLevel - 1 do
      FHead^.Next[LI] := FTail;

    atomic_store(FSize, 0, mo_relaxed);
  finally
    GlobalWriteUnlock;
  end;
end;

end.
