{******************************************************************************
  nextpas.core.lockfree.ttl_cache

  TTL Cache — concurrent cache with time-to-live expiration.

  Design:
  - Hash map for O(1) lookup
  - Doubly-linked list for LRU eviction + TTL ordering
  - Spin lock for thread safety
  - Per-entry TTL with lazy cleanup on access
  - Background-style sweep on Put when stale entries exceed threshold

  Use cases: session cache, DNS cache, API response cache, rate limiter.

  2026-07-06  Phase 5
******************************************************************************}
unit nextpas.core.lockfree.ttl_cache;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  TTL_DEFAULT_CAPACITY = 1024;
  TTL_DEFAULT_TTL_MS = 60000; { 60 seconds }
  TTL_HASH_BUCKETS = 1024;
  TTL_SWEEP_THRESHOLD = 256; { sweep after this many expired }

type
  TTTLCacheResult = (
    ttlOk,
    ttlNotFound,
    ttlFull,
    ttlExpired
  );

  PTTLNode = ^TTTLNode;
  TTTLNode = record
    Key: AnsiString;
    Value: AnsiString;
    Prev, Next: PTTLNode;
    HashNext: PTTLNode;
    Hash: UInt32;
    ExpiresAt: Int64; { monotonic ms }
    TTL: Int64; { per-entry TTL in ms }
  end;

  {**
   * TTL Cache — 带过期时间的并发缓存。
   *
   * 支持全局默认 TTL 和 per-entry TTL。
   * Get 时惰性清理过期条目，Put 时批量清理。
   *
   * @constraints
   *   - 容量在创建时固定
   *   - 使用 spin lock 保证线程安全
   *   - 过期时间基于单调时钟（不受系统时间调整影响）
   *}
  TTTLCache = class
  private
    FBuckets: array[0..TTL_HASH_BUCKETS - 1] of PTTLNode;
    FHead, FTail: PTTLNode;
    FCapacity: Int32;
    FCount: Int32;
    FDefaultTTL: Int64;
    FLock: Int32;

    function HashKey(const AKey: AnsiString): UInt32;
    function FindNode(const AKey: AnsiString): PTTLNode;
    procedure MoveToFront(ANode: PTTLNode);
    procedure RemoveFromList(ANode: PTTLNode);
    procedure InsertIntoList(ANode: PTTLNode);
    procedure InsertIntoBucket(ANode: PTTLNode);
    procedure RemoveFromBucket(ANode: PTTLNode);
    function EvictLRU: PTTLNode;
    procedure SweepExpired;
    function GetNowMs: Int64;
    function ComputeExpiresAt(ANow, ATTLMs: Int64): Int64;
    procedure Lock; inline;
    procedure Unlock; inline;
  public
    constructor Create(ACapacity: Int32 = TTL_DEFAULT_CAPACITY;
      ADefaultTTLMs: Int64 = TTL_DEFAULT_TTL_MS);
    destructor Destroy; override;

    {** @desc 存入键值对（使用默认 TTL） }
    function Put(const AKey, AValue: AnsiString): TTTLCacheResult;
    {** @desc 存入键值对（指定 TTL 毫秒） }
    function PutWithTTL(const AKey, AValue: AnsiString; ATTLMs: Int64): TTTLCacheResult;
    {** @desc 获取键对应的值（过期返回 ttlExpired） }
    function Get(const AKey: AnsiString; out AValue: AnsiString): TTTLCacheResult;
    {** @desc 检查键是否存在且未过期 }
    function Contains(const AKey: AnsiString): Boolean;
    {** @desc 删除键值对 }
    function Remove(const AKey: AnsiString): TTTLCacheResult;
    {** @desc 当前元素数量（包含可能过期的） }
    function Count: Int32; inline;
    {** @desc 是否为空 }
    function IsEmpty: Boolean; inline;
    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 设置新的默认 TTL }
    procedure SetDefaultTTL(ATTLMs: Int64);
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.time;

function TTTLCache.GetNowMs: Int64;
begin
  Result := Int64(platform_monotonic_ns div 1000000);
end;

function TTTLCache.ComputeExpiresAt(ANow, ATTLMs: Int64): Int64;
begin
  if ATTLMs <= 0 then
    Exit(0);
  if ATTLMs > High(Int64) - ANow then
    Exit(High(Int64));
  Result := ANow + ATTLMs;
end;

function TTTLCache.HashKey(const AKey: AnsiString): UInt32;
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

procedure TTTLCache.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
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

procedure TTTLCache.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TTTLCache.FindNode(const AKey: AnsiString): PTTLNode;
var
  LIdx: UInt32;
  LNode: PTTLNode;
begin
  LIdx := HashKey(AKey) and (TTL_HASH_BUCKETS - 1);
  LNode := FBuckets[LIdx];
  while LNode <> nil do
  begin
    if LNode^.Key = AKey then
      Exit(LNode);
    LNode := LNode^.HashNext;
  end;
  Result := nil;
end;

procedure TTTLCache.MoveToFront(ANode: PTTLNode);
begin
  if FHead = ANode then
    Exit;
  RemoveFromList(ANode);
  InsertIntoList(ANode);
end;

procedure TTTLCache.RemoveFromList(ANode: PTTLNode);
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

procedure TTTLCache.InsertIntoList(ANode: PTTLNode);
begin
  ANode^.Prev := nil;
  ANode^.Next := FHead;
  if FHead <> nil then
    FHead^.Prev := ANode;
  FHead := ANode;
  if FTail = nil then
    FTail := ANode;
end;

procedure TTTLCache.InsertIntoBucket(ANode: PTTLNode);
var
  LIdx: UInt32;
begin
  LIdx := ANode^.Hash and (TTL_HASH_BUCKETS - 1);
  ANode^.HashNext := FBuckets[LIdx];
  FBuckets[LIdx] := ANode;
end;

procedure TTTLCache.RemoveFromBucket(ANode: PTTLNode);
var
  LIdx: UInt32;
  LCur, LPrev: PTTLNode;
begin
  LIdx := ANode^.Hash and (TTL_HASH_BUCKETS - 1);
  LPrev := nil;
  LCur := FBuckets[LIdx];
  while LCur <> nil do
  begin
    if LCur = ANode then
    begin
      if LPrev <> nil then
        LPrev^.HashNext := LCur^.HashNext
      else
        FBuckets[LIdx] := LCur^.HashNext;
      LCur^.HashNext := nil;
      Exit;
    end;
    LPrev := LCur;
    LCur := LCur^.HashNext;
  end;
end;

function TTTLCache.EvictLRU: PTTLNode;
begin
  Result := FTail;
  if Result <> nil then
  begin
    RemoveFromBucket(Result);
    RemoveFromList(Result);
    Dec(FCount);
  end;
end;

procedure TTTLCache.SweepExpired;
var
  LNode, LNext: PTTLNode;
  LNow: Int64;
  LSwept: Int32;
begin
  LNow := GetNowMs;
  LSwept := 0;
  LNode := FTail;
  while (LNode <> nil) and (LSwept < TTL_SWEEP_THRESHOLD) do
  begin
    LNext := LNode^.Prev;
    if (LNode^.ExpiresAt > 0) and (LNode^.ExpiresAt <= LNow) then
    begin
      RemoveFromBucket(LNode);
      RemoveFromList(LNode);
      LNode^.Key := '';
      LNode^.Value := '';
      Dispose(LNode);
      Dec(FCount);
      Inc(LSwept);
    end;
    LNode := LNext;
  end;
end;

constructor TTTLCache.Create(ACapacity: Int32; ADefaultTTLMs: Int64);
begin
  inherited Create;
  if ACapacity < 1 then ACapacity := TTL_DEFAULT_CAPACITY;
  FCapacity := ACapacity;
  if ADefaultTTLMs < 0 then
    ADefaultTTLMs := 0;
  FDefaultTTL := ADefaultTTLMs;
  FCount := 0;
  FLock := 0;
  FHead := nil;
  FTail := nil;
  FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

destructor TTTLCache.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TTTLCache.Put(const AKey, AValue: AnsiString): TTTLCacheResult;
begin
  Result := PutWithTTL(AKey, AValue, atomic_load_64(FDefaultTTL, mo_acquire));
end;

function TTTLCache.PutWithTTL(const AKey, AValue: AnsiString; ATTLMs: Int64): TTTLCacheResult;
var
  LNode, LEvicted: PTTLNode;
  LNow: Int64;
begin
  Lock;
  try
    LNow := GetNowMs;
    LNode := FindNode(AKey);
    if LNode <> nil then
    begin
      LNode^.Value := AValue;
      LNode^.TTL := ATTLMs;
      LNode^.ExpiresAt := ComputeExpiresAt(LNow, ATTLMs);
      MoveToFront(LNode);
      Exit(ttlOk);
    end;

    if FCount >= FCapacity then
      SweepExpired;
    if FCount >= FCapacity then
    begin
      LEvicted := EvictLRU;
      if LEvicted <> nil then
      begin
        LEvicted^.Key := '';
        LEvicted^.Value := '';
        Dispose(LEvicted);
      end;
    end;

    New(LNode);
    FillChar(LNode^, SizeOf(TTTLNode), 0);
    LNode^.Key := AKey;
    LNode^.Value := AValue;
    LNode^.Hash := HashKey(AKey);
    LNode^.TTL := ATTLMs;
    LNode^.ExpiresAt := ComputeExpiresAt(LNow, ATTLMs);

    InsertIntoBucket(LNode);
    InsertIntoList(LNode);
    Inc(FCount);
    Result := ttlOk;
  finally
    Unlock;
  end;
end;

function TTTLCache.Get(const AKey: AnsiString; out AValue: AnsiString): TTTLCacheResult;
var
  LNode: PTTLNode;
  LNow: Int64;
begin
  Lock;
  try
    LNode := FindNode(AKey);
    if LNode = nil then
      Exit(ttlNotFound);

    LNow := GetNowMs;
    if (LNode^.ExpiresAt > 0) and (LNode^.ExpiresAt <= LNow) then
    begin
      RemoveFromBucket(LNode);
      RemoveFromList(LNode);
      LNode^.Key := '';
      LNode^.Value := '';
      Dispose(LNode);
      Dec(FCount);
      Exit(ttlExpired);
    end;

    AValue := LNode^.Value;
    MoveToFront(LNode);
    Result := ttlOk;
  finally
    Unlock;
  end;
end;

function TTTLCache.Contains(const AKey: AnsiString): Boolean;
var
  LValue: AnsiString;
begin
  Result := Get(AKey, LValue) = ttlOk;
end;

function TTTLCache.Remove(const AKey: AnsiString): TTTLCacheResult;
var
  LNode: PTTLNode;
begin
  Lock;
  try
    LNode := FindNode(AKey);
    if LNode = nil then
      Exit(ttlNotFound);
    RemoveFromBucket(LNode);
    RemoveFromList(LNode);
    LNode^.Key := '';
    LNode^.Value := '';
    Dispose(LNode);
    Dec(FCount);
    Result := ttlOk;
  finally
    Unlock;
  end;
end;

function TTTLCache.Count: Int32; inline;
begin
  Result := atomic_load(FCount);
end;

function TTTLCache.IsEmpty: Boolean; inline;
begin
  Result := atomic_load(FCount) = 0;
end;

procedure TTTLCache.Clear;
var
  LNode, LNext: PTTLNode;
begin
  Lock;
  try
    LNode := FHead;
    while LNode <> nil do
    begin
      LNext := LNode^.Next;
      LNode^.Key := '';
      LNode^.Value := '';
      Dispose(LNode);
      LNode := LNext;
    end;
    FHead := nil;
    FTail := nil;
    FCount := 0;
    FillChar(FBuckets, SizeOf(FBuckets), 0);
  finally
    Unlock;
  end;
end;

procedure TTTLCache.SetDefaultTTL(ATTLMs: Int64);
begin
  if ATTLMs < 0 then
    ATTLMs := 0;
  atomic_exchange_64(FDefaultTTL, ATTLMs);
end;

end.
