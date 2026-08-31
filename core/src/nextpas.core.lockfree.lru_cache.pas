{******************************************************************************
  nextpas.core.lockfree.lru_cache

  Concurrent LRU Cache — thread-safe least-recently-used cache.

  Design:
  - Hash map for O(1) lookup
  - Doubly-linked list for O(1) eviction ordering
  - Spin lock for thread safety
  - Get promotes item to most-recently-used
  - Put adds item, evicts LRU if at capacity

  2026-07-06  Phase 4
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.lru_cache;

interface

uses
  nextpas.core.errors;

const
  LRU_DEFAULT_CAPACITY = 1024;
  LRU_HASH_BUCKETS = 1024;

type
  TLRUCacheResult = (
    lrOk,
    lrNotFound,
    lrFull
  );

  PLruNode = ^TLruNode;
  TLruNode = record
    Key: AnsiString;
    Value: AnsiString;
    Prev, Next: PLruNode;
    HashNext: PLruNode;
    Hash: UInt32;
  end;

  {**
   * Concurrent LRU Cache — 线程安全的最近最少使用缓存。
   *
   * @constraints
   *   - 容量在创建时固定
   *   - 使用 spin lock 保证线程安全
   *   - 不是 lock-free，但性能良好
   *}
  TConcurrentLRUCache = class
  private
    FBuckets: array[0..LRU_HASH_BUCKETS - 1] of PLruNode;
    FHead, FTail: PLruNode;
    FCapacity: Int32;
    FCount: Int32;
    FLock: Int32;

    function HashKey(const AKey: AnsiString): UInt32;
    function FindNode(const AKey: AnsiString): PLruNode;
    procedure RemoveFromList(ANode: PLruNode);
    procedure AddToFront(ANode: PLruNode);
    function EvictLRU: PLruNode;
    procedure AcquireLock;
    procedure ReleaseLock;

  public
    constructor Create(ACapacity: Int32 = LRU_DEFAULT_CAPACITY);
    destructor Destroy; override;

    { 获取缓存值，提升为最近使用 }
    function Get(const AKey: AnsiString; out AValue: AnsiString): TLRUCacheResult;

    { 添加或更新缓存值 }
    function Put(const AKey, AValue: AnsiString): TLRUCacheResult;

    { 检查是否存在（不改变顺序） }
    function Contains(const AKey: AnsiString): Boolean;

    { 移除指定键 }
    function Remove(const AKey: AnsiString): TLRUCacheResult;

    { 当前缓存数量 }
    function Count: Int32;

    { 清空缓存 }
    procedure Clear;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

constructor TConcurrentLRUCache.Create(ACapacity: Int32);
begin
  inherited Create;
  if ACapacity < 1 then
    ACapacity := LRU_DEFAULT_CAPACITY;
  FCapacity := ACapacity;
  FCount := 0;
  FHead := nil;
  FTail := nil;
  FLock := 0;
  FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

destructor TConcurrentLRUCache.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TConcurrentLRUCache.HashKey(const AKey: AnsiString): UInt32;
var
  I: Int32;
begin
  Result := 2166136261;
  for I := 1 to Length(AKey) do
  begin
    Result := Result xor Ord(AKey[I]);
    Result := Result * 16777619;
  end;
end;

procedure TConcurrentLRUCache.AcquireLock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TConcurrentLRUCache.ReleaseLock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TConcurrentLRUCache.FindNode(const AKey: AnsiString): PLruNode;
var
  LHash: UInt32;
  LIdx: Int32;
  LNode: PLruNode;
begin
  LHash := HashKey(AKey);
  LIdx := Int32(LHash and (LRU_HASH_BUCKETS - 1));
  LNode := FBuckets[LIdx];
  while LNode <> nil do
  begin
    if (LNode^.Hash = LHash) and (LNode^.Key = AKey) then
    begin
      Result := LNode;
      Exit;
    end;
    LNode := LNode^.HashNext;
  end;
  Result := nil;
end;

procedure TConcurrentLRUCache.RemoveFromList(ANode: PLruNode);
begin
  if ANode^.Prev <> nil then
    ANode^.Prev^.Next := ANode^.Next
  else
    FHead := ANode^.Next;
  if ANode^.Next <> nil then
    ANode^.Next^.Prev := ANode^.Prev
  else
    FTail := ANode^.Prev;
  ANode^.Prev := nil;
  ANode^.Next := nil;
end;

procedure TConcurrentLRUCache.AddToFront(ANode: PLruNode);
begin
  ANode^.Prev := nil;
  ANode^.Next := FHead;
  if FHead <> nil then
    FHead^.Prev := ANode;
  FHead := ANode;
  if FTail = nil then
    FTail := ANode;
end;

function TConcurrentLRUCache.EvictLRU: PLruNode;
var
  LHash: UInt32;
  LIdx: Int32;
  LNode, LPrev: PLruNode;
begin
  Result := FTail;
  if Result = nil then
    Exit;

  { Remove from list }
  RemoveFromList(Result);

  { Remove from hash bucket }
  LHash := Result^.Hash;
  LIdx := Int32(LHash and (LRU_HASH_BUCKETS - 1));
  LNode := FBuckets[LIdx];
  LPrev := nil;
  while LNode <> nil do
  begin
    if LNode = Result then
    begin
      if LPrev <> nil then
        LPrev^.HashNext := LNode^.HashNext
      else
        FBuckets[LIdx] := LNode^.HashNext;
      Break;
    end;
    LPrev := LNode;
    LNode := LNode^.HashNext;
  end;

  Dec(FCount);
end;

function TConcurrentLRUCache.Get(const AKey: AnsiString;
  out AValue: AnsiString): TLRUCacheResult;
var
  LNode: PLruNode;
begin
  AcquireLock;
  try
    LNode := FindNode(AKey);
    if LNode = nil then
    begin
      AValue := '';
      Result := lrNotFound;
      Exit;
    end;
    AValue := LNode^.Value;
    { Move to front (most recently used) }
    RemoveFromList(LNode);
    AddToFront(LNode);
    Result := lrOk;
  finally
    ReleaseLock;
  end;
end;

function TConcurrentLRUCache.Put(const AKey, AValue: AnsiString): TLRUCacheResult;
var
  LNode: PLruNode;
  LHash: UInt32;
  LIdx: Int32;
begin
  AcquireLock;
  try
    { Check if key already exists }
    LNode := FindNode(AKey);
    if LNode <> nil then
    begin
      { Update existing }
      LNode^.Value := AValue;
      RemoveFromList(LNode);
      AddToFront(LNode);
      Result := lrOk;
      Exit;
    end;

    { Evict if at capacity }
    if FCount >= FCapacity then
    begin
      LNode := EvictLRU;
      if LNode <> nil then
        Dispose(LNode);
    end;

    { Create new node }
    New(LNode);
    LNode^.Key := AKey;
    LNode^.Value := AValue;
    LNode^.Prev := nil;
    LNode^.Next := nil;
    LHash := HashKey(AKey);
    LNode^.Hash := LHash;

    { Add to hash bucket }
    LIdx := Int32(LHash and (LRU_HASH_BUCKETS - 1));
    LNode^.HashNext := FBuckets[LIdx];
    FBuckets[LIdx] := LNode;

    { Add to front of list }
    AddToFront(LNode);
    Inc(FCount);
    Result := lrOk;
  finally
    ReleaseLock;
  end;
end;

function TConcurrentLRUCache.Contains(const AKey: AnsiString): Boolean;
begin
  AcquireLock;
  try
    Result := FindNode(AKey) <> nil;
  finally
    ReleaseLock;
  end;
end;

function TConcurrentLRUCache.Remove(const AKey: AnsiString): TLRUCacheResult;
var
  LNode: PLruNode;
  LHash: UInt32;
  LIdx: Int32;
  LCurr, LPrev: PLruNode;
begin
  AcquireLock;
  try
    LNode := FindNode(AKey);
    if LNode = nil then
    begin
      Result := lrNotFound;
      Exit;
    end;

    { Remove from list }
    RemoveFromList(LNode);

    { Remove from hash bucket }
    LHash := LNode^.Hash;
    LIdx := Int32(LHash and (LRU_HASH_BUCKETS - 1));
    LCurr := FBuckets[LIdx];
    LPrev := nil;
    while LCurr <> nil do
    begin
      if LCurr = LNode then
      begin
        if LPrev <> nil then
          LPrev^.HashNext := LCurr^.HashNext
        else
          FBuckets[LIdx] := LCurr^.HashNext;
        Break;
      end;
      LPrev := LCurr;
      LCurr := LCurr^.HashNext;
    end;

    Dispose(LNode);
    Dec(FCount);
    Result := lrOk;
  finally
    ReleaseLock;
  end;
end;

function TConcurrentLRUCache.Count: Int32;
begin
  AcquireLock;
  try
    Result := FCount;
  finally
    ReleaseLock;
  end;
end;

procedure TConcurrentLRUCache.Clear;
var
  LNode, LNext: PLruNode;
  I: Int32;
begin
  AcquireLock;
  try
    LNode := FHead;
    while LNode <> nil do
    begin
      LNext := LNode^.Next;
      Dispose(LNode);
      LNode := LNext;
    end;
    FHead := nil;
    FTail := nil;
    FCount := 0;
    for I := 0 to LRU_HASH_BUCKETS - 1 do
      FBuckets[I] := nil;
  finally
    ReleaseLock;
  end;
end;

end.
