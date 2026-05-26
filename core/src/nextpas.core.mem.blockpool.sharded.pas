{
  nextpas.core.mem.blockpool.sharded

  High-throughput concurrent IBlockPool:
  - Shards: per-shard TGrowingBlockPool + per-shard mutex
  - Routing: global segment table (range -> shard) protected by RWLock
  - Optional lock-free remote frees (disabled under FAF_MEM_DEBUG)
}
unit nextpas.core.mem.blockpool.sharded;

{$I nextpas.core.settings.inc}

{$PUSH}
{$HINTS OFF} // pointer/ordinal conversions in pool internals

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.growable,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

const
  SHARDED_BLOCKPOOL_THREADCACHE_MAX = 256;
  SHARDED_BLOCKPOOL_REMOTE_BATCH = 32;

type
  TShardedBlockPoolConfig = record
    Pool: TGrowingBlockPoolConfig;
    ShardCount: Integer;              // 0 = auto (CPUCount rounded to pow2)
    ThreadCacheCapacity: Integer;     // 0 = disabled (per-thread pointer cache)
    ThreadCacheCheckDoubleFree: Boolean; // enable O(n) scan in cache
    TrackInUse: Boolean;              // accurate InUse/Available via atomic counters (costs per-op atomics)

    class function Default(aBlockSize, aCapacity: SizeUInt; aShardCount: Integer = 0): TShardedBlockPoolConfig; static;
  end;

  {**
   * TShardedBlockPool
   *
   * @desc Thread-safe sharded block pool:
   *   - reduced lock contention vs. single global mutex
   *   - fast Release routing via segment range table
   *
   * @note Reset invalidates pointers allocated before Reset.
   *}
  TShardedBlockPool = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    type
      TShard = record
        Pool: TGrowingBlockPool;
        Lock: IMutex;
        KnownCapacity: SizeUInt;
        KnownSegmentCount: SizeInt;
        InUseCount: Int64; // blocks in-use by callers (per-shard, atomic)
        RemoteFreeHead: Pointer;
      end;
      TRoute = record
        Base: PByte;
        Limit: PByte; // one-past-end
        Shard: Integer;
      end;
      TRemoteFreeBuf = record
        Head: Pointer;
        Tail: Pointer;
        Count: Integer;
      end;
      PThreadCacheNode = ^TThreadCacheNode;
      TThreadCacheNode = record
        PoolPtr: Pointer;
        PoolId: UInt64;
        Epoch: UInt64;
        Shard: Integer;
        Count: Integer;
        Next: PThreadCacheNode;
        RemoteBufs: Pointer; // points to TRemoteFreeBuf[FShardCount] (tail-allocated)
        RemoteBufLen: Integer;
        Ptrs: array[0..SHARDED_BLOCKPOOL_THREADCACHE_MAX - 1] of Pointer;
      end;
  private
    FShardCount: Integer;
    FShardMask: Integer;
    FShards: array of TShard;

    // segment routing table (sorted by Base), protected by a lightweight spin RW lock
    FRoutingState: Int32;
    FRoutes: array of TRoute;

    // page-map routing (pageKey -> {Base,Limit,Shard}); writes are rare, reads are hot
    FPageShift: SizeUInt;
    FPageKeys: array of PtrUInt;  // 0 = empty
    FPageBase: array of PByte;
    FPageLimit: array of PByte;
    FPageShard: array of Integer;
    FPageMask: SizeUInt;
    FPageHighShift: SizeUInt;
    FPageCount: SizeUInt;

    // normalized (actual) block geometry
    FBlockSize: SizeUInt;
    FBlockShift: SizeUInt;
    FBlockMask: SizeUInt;

    FConfig: TGrowingBlockPoolConfig;

    // thread-local free cache (optional)
    FPoolId: UInt64;
    FCacheEpoch: UInt64;
    FThreadCacheCapacity: Integer;
    FThreadCacheCheckDoubleFree: Boolean;
    FTrackInUse: Boolean;

    // fast statistics (atomic, approximate under heavy contention but monotonic)
    FTotalCapacity: Int64; // blocks
  private
    function IsPowerOfTwoInt(aValue: Integer): Boolean; inline;
    function NextPow2Int(aValue: Integer): Integer; inline;
    function NormalizeShardCount(aShardCount: Integer): Integer;
    function ChooseShardIndex: Integer; inline;
    function GetLocalShardIndex: Integer; inline;

    procedure RouteReadLock; inline;
    procedure RouteReadUnlock; inline;
    procedure RouteWriteLock; inline;
    procedure RouteWriteUnlock; inline;

    procedure RouteClear;
    procedure RouteInsert(aBase, aLimit: PByte; aShard: Integer);
    function TryRoute(aPtr: Pointer; out aShard: Integer; out aBase: PByte): Boolean;

    function PageKeyOf(aPtr: Pointer): PtrUInt; inline;
    procedure PageMapInit(aMinCapacity: SizeUInt);
    procedure PageMapClear;
    procedure PageMapGrowIfNeeded(aNeedMore: SizeUInt);
    procedure PageMapPut(aKey: PtrUInt; aBase, aLimit: PByte; aShard: Integer);
    function PageMapLookup(aKey: PtrUInt; out aBase, aLimit: PByte; out aShard: Integer): Boolean; inline;
    procedure IndexSegmentPagesLocked(aShard: Integer; aStart, aEnd: PByte);

    procedure IndexShardNewSegmentsLocked(aShard: Integer);

    procedure FlushRemoteFreesLocked(aShard: Integer); inline; // requires shard lock
    procedure RemoteFreePush(aShard: Integer; aPtr: Pointer); inline; // lock-free push
    procedure RemoteFreePushList(aShard: Integer; aHead, aTail: Pointer); inline; // lock-free list push
    procedure RemoteFreeBufferPush(aNode: PThreadCacheNode; aShard: Integer; aPtr: Pointer); inline;
    procedure FlushThreadRemoteBuffers(aNode: PThreadCacheNode);

    function GetThreadCacheNode: PThreadCacheNode; inline;
    procedure InvalidateThreadCacheNode(aNode: PThreadCacheNode); inline;
    procedure FlushThreadCacheLocked(aShard: Integer; aNode: PThreadCacheNode; aFlushCount: Integer);

  public
    constructor Create(const aConfig: TShardedBlockPoolConfig); overload;
    constructor Create(const aConfig: TGrowingBlockPoolConfig; aShardCount: Integer = 0); overload;
    constructor Create(aBlockSize, aCapacity: SizeUInt; aShardCount: Integer = 0; aAlignment: SizeUInt = DEFAULT_ALIGNMENT); overload;
    destructor Destroy; override;

    { IBlockPool }
    function Acquire: Pointer;
    function TryAcquire(out aPtr: Pointer): Boolean;
    procedure Release(aPtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;

    { IBlockPoolBatch }
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    // Flush current thread cache back to shard (optional helper for short-lived threads)
    procedure FlushThreadCache;

    function ShardCount: Integer; inline;
  end;

implementation

uses
  nextpas.core.time.cpu;

var
  GShardedBlockPoolIdGen: UInt64 = 0;

type
  TThreadRouteCache = record
    PoolPtr: Pointer;
    PoolId: UInt64;
    Epoch: UInt64;
    Base: PByte;
    Limit: PByte;
    Shard: Integer;
  end;

  TThreadCacheNodeCache = record
    PoolPtr: Pointer;
    PoolId: UInt64;
    Node: TShardedBlockPool.PThreadCacheNode;
  end;

  TThreadShardCache = record
    PoolPtr: Pointer;
    PoolId: UInt64;
    Epoch: UInt64;
    Shard: Integer;
  end;

threadvar
  GShardedBlockPoolThreadCacheHead: TShardedBlockPool.PThreadCacheNode;
  GShardedBlockPoolRouteCache: TThreadRouteCache;
  GShardedBlockPoolThreadCacheNodeCache: TThreadCacheNodeCache;
  GShardedBlockPoolLocalShardCache: TThreadShardCache;

const
  HASH_MIN_CAP = 64;
  ROUTING_WRITE_BIT = Int32($80000000);
  ROUTING_WAIT_BIT  = Int32($40000000);
  ROUTING_READ_MASK = Int32($3FFFFFFF);

function NextShardedBlockPoolId: UInt64; inline;
begin
  Result := atomic_fetch_add_64(GShardedBlockPoolIdGen, 1) + 1;
end;

{$push}
{$Q-}
function MulHash64(aValue: QWord): QWord; inline;
begin
  Result := aValue * QWord(11400714819323198485);
end;
{$pop}

class function TShardedBlockPoolConfig.Default(aBlockSize, aCapacity: SizeUInt; aShardCount: Integer): TShardedBlockPoolConfig;
begin
  Result.Pool := TGrowingBlockPoolConfig.Default(aBlockSize, aCapacity);
  Result.ShardCount := aShardCount;
  Result.ThreadCacheCapacity := 0;
  Result.ThreadCacheCheckDoubleFree := True;
  Result.TrackInUse := True;
end;

function TShardedBlockPool.IsPowerOfTwoInt(aValue: Integer): Boolean;
begin
  Result := (aValue > 0) and ((aValue and (aValue - 1)) = 0);
end;

function TShardedBlockPool.NextPow2Int(aValue: Integer): Integer;
var
  LResult: Integer;
begin
  if aValue <= 1 then Exit(1);
  LResult := 1;
  while LResult < aValue do
    LResult := LResult shl 1;
  Result := LResult;
end;

function TShardedBlockPool.NormalizeShardCount(aShardCount: Integer): Integer;
var
  LCPU: Integer;
begin
  if aShardCount <= 0 then
  begin
    LCPU := CpuCount;
    if LCPU < 1 then LCPU := 1;
    if LCPU > 32 then LCPU := 32;
    aShardCount := LCPU;
  end;
  if not IsPowerOfTwoInt(aShardCount) then
    aShardCount := NextPow2Int(aShardCount);
  if aShardCount < 1 then aShardCount := 1;
  Result := aShardCount;
end;

function TShardedBlockPool.ChooseShardIndex: Integer;
var
  LId: QWord;
begin
  if FShardCount <= 1 then Exit(0);
  LId := QWord(CurrentThreadId);
  Result := Integer(MulHash64(LId) and QWord(FShardMask));
end;

function TShardedBlockPool.GetLocalShardIndex: Integer;
begin
  if FShardCount <= 1 then
    Exit(0);

  if (GShardedBlockPoolLocalShardCache.PoolPtr = Pointer(Self)) and
    (GShardedBlockPoolLocalShardCache.PoolId = FPoolId) and
    (GShardedBlockPoolLocalShardCache.Epoch = FCacheEpoch) then
    Exit(GShardedBlockPoolLocalShardCache.Shard);

  Result := ChooseShardIndex;
  GShardedBlockPoolLocalShardCache.PoolPtr := Pointer(Self);
  GShardedBlockPoolLocalShardCache.PoolId := FPoolId;
  GShardedBlockPoolLocalShardCache.Epoch := FCacheEpoch;
  GShardedBlockPoolLocalShardCache.Shard := Result;
end;

procedure TShardedBlockPool.RouteReadLock;
var
  LState: Int32;
  LDesired: Int32;
  LSpins: UInt32;
begin
  LSpins := 0;
  repeat
    LState := atomic_load(FRoutingState);
    if (LState and (ROUTING_WRITE_BIT or ROUTING_WAIT_BIT)) <> 0 then
    begin
      CpuRelax;
      Inc(LSpins);
      if (LSpins and 1023) = 0 then
        SchedYield;
      Continue;
    end;

    if (LState and ROUTING_READ_MASK) = ROUTING_READ_MASK then
      raise EAllocError.Create(aeInternalError, 'TShardedBlockPool: routing reader overflow');

    LDesired := LState + 1;
    if atomic_compare_exchange_weak(FRoutingState, LState, LDesired) then
      Exit;
  until False;
end;

procedure TShardedBlockPool.RouteReadUnlock;
begin
  atomic_fetch_add(FRoutingState, -1);
end;

procedure TShardedBlockPool.RouteWriteLock;
var
  LState: Int32;
  LExpected: Int32;
  LSpins: UInt32;
begin
  LSpins := 0;
  // Announce writer intent: block new readers.
  atomic_fetch_or(FRoutingState, ROUTING_WAIT_BIT);
  repeat
    LState := atomic_load(FRoutingState);
    if (LState and ROUTING_WAIT_BIT) = 0 then
    begin
      atomic_fetch_or(FRoutingState, ROUTING_WAIT_BIT);
      Continue;
    end;

    // Wait until no readers and no writer.
    if ((LState and ROUTING_READ_MASK) = 0) and ((LState and ROUTING_WRITE_BIT) = 0) then
    begin
      LExpected := LState;
      if atomic_compare_exchange_weak(FRoutingState, LExpected, LState or ROUTING_WRITE_BIT) then
        Exit;
      Continue;
    end;

    CpuRelax;
    Inc(LSpins);
    if (LSpins and 1023) = 0 then
      SchedYield;
  until False;
end;

procedure TShardedBlockPool.RouteWriteUnlock;
begin
  atomic_store(FRoutingState, 0, mo_release);
end;

procedure TShardedBlockPool.RouteClear;
begin
  SetLength(FRoutes, 0);
end;

procedure TShardedBlockPool.RouteInsert(aBase, aLimit: PByte; aShard: Integer);
var
  LIdx: SizeInt;
  LInsert: SizeInt;
  LTmp: TRoute;
begin
  if (aBase = nil) or (aLimit = nil) or (aLimit <= aBase) then
    Exit;

  LIdx := Length(FRoutes);
  SetLength(FRoutes, LIdx + 1);
  FRoutes[LIdx].Base := aBase;
  FRoutes[LIdx].Limit := aLimit;
  FRoutes[LIdx].Shard := aShard;

  // insertion sort (routes count is expected to be small)
  LInsert := LIdx;
  while (LInsert > 0) and (PtrUInt(FRoutes[LInsert - 1].Base) > PtrUInt(FRoutes[LInsert].Base)) do
  begin
    LTmp := FRoutes[LInsert - 1];
    FRoutes[LInsert - 1] := FRoutes[LInsert];
    FRoutes[LInsert] := LTmp;
    Dec(LInsert);
  end;
end;

function TShardedBlockPool.PageKeyOf(aPtr: Pointer): PtrUInt;
begin
  Result := PtrUInt(aPtr) shr FPageShift;
end;

procedure TShardedBlockPool.PageMapInit(aMinCapacity: SizeUInt);
var
  LCap: SizeUInt;
  LIdx: SizeUInt;
  LLog: SizeUInt;
  LTmp: SizeUInt;
begin
  LCap := HASH_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;

  SetLength(FPageKeys, LCap);
  SetLength(FPageBase, LCap);
  SetLength(FPageLimit, LCap);
  SetLength(FPageShard, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FPageKeys[LIdx] := 0;
    FPageBase[LIdx] := nil;
    FPageLimit[LIdx] := nil;
    FPageShard[LIdx] := -1;
  end;

  FPageMask := LCap - 1;
  LLog := 0;
  LTmp := LCap;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FPageHighShift := SizeUInt(64 - LLog);
  FPageCount := 0;
end;

procedure TShardedBlockPool.PageMapClear;
var
  LIdx: SizeUInt;
begin
  if Length(FPageKeys) = 0 then Exit;
  for LIdx := 0 to FPageMask do
  begin
    FPageKeys[LIdx] := 0;
    FPageBase[LIdx] := nil;
    FPageLimit[LIdx] := nil;
    FPageShard[LIdx] := -1;
  end;
  FPageCount := 0;
end;

procedure TShardedBlockPool.PageMapGrowIfNeeded(aNeedMore: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldBase: array of PByte;
  LOldLimit: array of PByte;
  LOldShard: array of Integer;
  LOldCap: SizeUInt;
  LIdx: SizeUInt;
  LLog: SizeUInt;
  LTmp: SizeUInt;
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if Length(FPageKeys) = 0 then
  begin
    PageMapInit(aNeedMore * 2);
    Exit;
  end;

  if (FPageCount + aNeedMore) <= ((FPageMask + 1) shr 1) then Exit;

  LOldCap := FPageMask + 1;
  LOldKeys := FPageKeys;
  LOldBase := FPageBase;
  LOldLimit := FPageLimit;
  LOldShard := FPageShard;

  SetLength(FPageKeys, LOldCap shl 1);
  SetLength(FPageBase, LOldCap shl 1);
  SetLength(FPageLimit, LOldCap shl 1);
  SetLength(FPageShard, LOldCap shl 1);
  FPageMask := (LOldCap shl 1) - 1;

  LLog := 0;
  LTmp := FPageMask + 1;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FPageHighShift := SizeUInt(64 - LLog);

  for LIdx := 0 to FPageMask do
  begin
    FPageKeys[LIdx] := 0;
    FPageBase[LIdx] := nil;
    FPageLimit[LIdx] := nil;
    FPageShard[LIdx] := -1;
  end;
  FPageCount := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if LKey <> 0 then
    begin
      LHash := MulHash64(QWord(LKey));
      LPos := (LHash shr FPageHighShift) and FPageMask;
      while FPageKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FPageMask;
      FPageKeys[LPos] := LKey;
      FPageBase[LPos] := LOldBase[LIdx];
      FPageLimit[LPos] := LOldLimit[LIdx];
      FPageShard[LPos] := LOldShard[LIdx];
      Inc(FPageCount);
    end;
  end;
end;

procedure TShardedBlockPool.PageMapPut(aKey: PtrUInt; aBase, aLimit: PByte; aShard: Integer);
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  if Length(FPageKeys) = 0 then
    PageMapInit(HASH_MIN_CAP);

  if aKey = 0 then aKey := 1;
  LHash := MulHash64(QWord(aKey));
  LPos := (LHash shr FPageHighShift) and FPageMask;
  while True do
  begin
    if FPageKeys[LPos] = 0 then
    begin
      FPageKeys[LPos] := aKey;
      FPageBase[LPos] := aBase;
      FPageLimit[LPos] := aLimit;
      FPageShard[LPos] := aShard;
      Inc(FPageCount);
      Exit;
    end;
    if FPageKeys[LPos] = aKey then
    begin
      // update (handles shared pages between segments)
      FPageBase[LPos] := aBase;
      FPageLimit[LPos] := aLimit;
      FPageShard[LPos] := aShard;
      Exit;
    end;
    LPos := (LPos + 1) and FPageMask;
  end;
end;

function TShardedBlockPool.PageMapLookup(aKey: PtrUInt; out aBase, aLimit: PByte; out aShard: Integer): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  aBase := nil;
  aLimit := nil;
  aShard := -1;
  Result := False;
  if Length(FPageKeys) = 0 then Exit(False);

  if aKey = 0 then aKey := 1;
  LHash := MulHash64(QWord(aKey));
  LPos := (LHash shr FPageHighShift) and FPageMask;
  while True do
  begin
    if FPageKeys[LPos] = 0 then Exit(False);
    if FPageKeys[LPos] = aKey then
    begin
      aBase := FPageBase[LPos];
      aLimit := FPageLimit[LPos];
      aShard := FPageShard[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FPageMask;
  end;
end;

procedure TShardedBlockPool.IndexSegmentPagesLocked(aShard: Integer; aStart, aEnd: PByte);
var
  LStartKey: PtrUInt;
  LEndKey: PtrUInt;
  LKey: PtrUInt;
  LPages: SizeUInt;
begin
  if (aStart = nil) or (aEnd = nil) or (aEnd <= aStart) then Exit;
  if FPageShift = 0 then Exit;

  LStartKey := PtrUInt(aStart) shr FPageShift;
  LEndKey := (PtrUInt(aEnd) - 1) shr FPageShift;
  if LEndKey < LStartKey then Exit;
  LPages := SizeUInt(LEndKey - LStartKey + 1);

  PageMapGrowIfNeeded(LPages);
  LKey := LStartKey;
  while LKey <= LEndKey do
  begin
    PageMapPut(LKey, aStart, aEnd, aShard);
    Inc(LKey);
  end;
end;

function TShardedBlockPool.TryRoute(aPtr: Pointer; out aShard: Integer; out aBase: PByte): Boolean;
var
  LLeft, LRight, LMid: SizeInt;
  LPtrU, LBaseU, LLimitU: PtrUInt;
  LCacheBaseU, LCacheLimitU: PtrUInt;
  LPageBase: PByte;
  LPageLimit: PByte;
  LPageShard: Integer;
begin
  aShard := -1;
  aBase := nil;
  Result := False;
  if aPtr = nil then Exit(False);

  // Fast TLS route cache
  LPtrU := PtrUInt(aPtr);
  if (GShardedBlockPoolRouteCache.PoolPtr = Pointer(Self)) and
    (GShardedBlockPoolRouteCache.PoolId = FPoolId) and
    (GShardedBlockPoolRouteCache.Epoch = FCacheEpoch) and
    (GShardedBlockPoolRouteCache.Base <> nil) and
    (GShardedBlockPoolRouteCache.Limit <> nil) then
  begin
    LCacheBaseU := PtrUInt(GShardedBlockPoolRouteCache.Base);
    LCacheLimitU := PtrUInt(GShardedBlockPoolRouteCache.Limit);
    if (LPtrU >= LCacheBaseU) and (LPtrU < LCacheLimitU) then
    begin
      aShard := GShardedBlockPoolRouteCache.Shard;
      aBase := GShardedBlockPoolRouteCache.Base;
      Exit(True);
    end;
  end;

  RouteReadLock;
  try
    // Fast page-map routing first (common case)
    if PageMapLookup(PageKeyOf(aPtr), LPageBase, LPageLimit, LPageShard) then
    begin
      if (LPageBase <> nil) and (LPageLimit <> nil) then
      begin
        LBaseU := PtrUInt(LPageBase);
        LLimitU := PtrUInt(LPageLimit);
        if (LPtrU >= LBaseU) and (LPtrU < LLimitU) then
        begin
          aShard := LPageShard;
          aBase := LPageBase;
          // Update TLS route cache
          GShardedBlockPoolRouteCache.PoolPtr := Pointer(Self);
          GShardedBlockPoolRouteCache.PoolId := FPoolId;
          GShardedBlockPoolRouteCache.Epoch := FCacheEpoch;
          GShardedBlockPoolRouteCache.Base := LPageBase;
          GShardedBlockPoolRouteCache.Limit := LPageLimit;
          GShardedBlockPoolRouteCache.Shard := aShard;
          Exit(True);
        end;
      end;
    end;

    if Length(FRoutes) = 0 then
      Exit(False);

    LLeft := 0;
    LRight := High(FRoutes);
    while LLeft <= LRight do
    begin
      LMid := (LLeft + LRight) shr 1;
      LBaseU := PtrUInt(FRoutes[LMid].Base);
      if LPtrU < LBaseU then
      begin
        LRight := LMid - 1;
        Continue;
      end;

      LLimitU := PtrUInt(FRoutes[LMid].Limit);
      if LPtrU >= LLimitU then
      begin
        LLeft := LMid + 1;
        Continue;
      end;

      aShard := FRoutes[LMid].Shard;
      aBase := FRoutes[LMid].Base;
      // Update TLS route cache
      GShardedBlockPoolRouteCache.PoolPtr := Pointer(Self);
      GShardedBlockPoolRouteCache.PoolId := FPoolId;
      GShardedBlockPoolRouteCache.Epoch := FCacheEpoch;
      GShardedBlockPoolRouteCache.Base := FRoutes[LMid].Base;
      GShardedBlockPoolRouteCache.Limit := FRoutes[LMid].Limit;
      GShardedBlockPoolRouteCache.Shard := aShard;
      Exit(True);
    end;
  finally
    RouteReadUnlock;
  end;
end;

procedure TShardedBlockPool.FlushRemoteFreesLocked(aShard: Integer);
var
  LNode: Pointer;
  LNext: Pointer;
begin
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;

  LNode := atomic_exchange(FShards[aShard].RemoteFreeHead, nil, mo_acq_rel);
  if LNode = nil then Exit;
  while LNode <> nil do
  begin
    LNext := PPointer(LNode)^;
    FShards[aShard].Pool.Release(LNode);
    LNode := LNext;
  end;
end;

procedure TShardedBlockPool.RemoteFreePush(aShard: Integer; aPtr: Pointer);
var
  LExpected: Pointer;
begin
  if aPtr = nil then Exit;
  if (aShard < 0) or (aShard >= FShardCount) then
    raise EInvalidArgument.Create('TShardedBlockPool.RemoteFreePush: invalid shard index');

  LExpected := atomic_load(FShards[aShard].RemoteFreeHead, mo_relaxed);
  repeat
    PPointer(aPtr)^ := LExpected;
  until atomic_compare_exchange_strong(FShards[aShard].RemoteFreeHead, LExpected, aPtr, mo_release, mo_relaxed);
end;

procedure TShardedBlockPool.RemoteFreePushList(aShard: Integer; aHead, aTail: Pointer);
var
  LExpected: Pointer;
begin
  if (aHead = nil) or (aTail = nil) then Exit;
  if (aShard < 0) or (aShard >= FShardCount) then
    raise EInvalidArgument.Create('TShardedBlockPool.RemoteFreePushList: invalid shard index');

  LExpected := atomic_load(FShards[aShard].RemoteFreeHead, mo_relaxed);
  repeat
    PPointer(aTail)^ := LExpected;
  until atomic_compare_exchange_strong(FShards[aShard].RemoteFreeHead, LExpected, aHead, mo_release, mo_relaxed);
end;

procedure TShardedBlockPool.RemoteFreeBufferPush(aNode: PThreadCacheNode; aShard: Integer; aPtr: Pointer);
var
  LBuf: ^TRemoteFreeBuf;
begin
  if (aNode = nil) or (aPtr = nil) then Exit;
  if (aShard < 0) or (aShard >= FShardCount) then
    raise EInvalidArgument.Create('TShardedBlockPool.RemoteFreeBufferPush: invalid shard index');
  if (aNode^.RemoteBufs = nil) or (aNode^.RemoteBufLen <= 0) then
  begin
    RemoteFreePush(aShard, aPtr);
    Exit;
  end;
  if aShard >= aNode^.RemoteBufLen then
  begin
    RemoteFreePush(aShard, aPtr);
    Exit;
  end;

  LBuf := Pointer(PByte(aNode^.RemoteBufs) + SizeUInt(aShard) * SizeUInt(SizeOf(TRemoteFreeBuf)));
  PPointer(aPtr)^ := LBuf^.Head;
  LBuf^.Head := aPtr;
  if LBuf^.Tail = nil then
    LBuf^.Tail := aPtr;
  Inc(LBuf^.Count);
  if LBuf^.Count >= SHARDED_BLOCKPOOL_REMOTE_BATCH then
  begin
    RemoteFreePushList(aShard, LBuf^.Head, LBuf^.Tail);
    LBuf^.Head := nil;
    LBuf^.Tail := nil;
    LBuf^.Count := 0;
  end;
end;

procedure TShardedBlockPool.FlushThreadRemoteBuffers(aNode: PThreadCacheNode);
var
  LIdx: Integer;
  LBuf: ^TRemoteFreeBuf;
  LHead: Pointer;
  LTail: Pointer;
begin
  if (aNode = nil) or (aNode^.RemoteBufs = nil) or (aNode^.RemoteBufLen <= 0) then Exit;

  for LIdx := 0 to aNode^.RemoteBufLen - 1 do
  begin
    LBuf := Pointer(PByte(aNode^.RemoteBufs) + SizeUInt(LIdx) * SizeUInt(SizeOf(TRemoteFreeBuf)));
    if LBuf^.Count <= 0 then
      Continue;
    LHead := LBuf^.Head;
    LTail := LBuf^.Tail;
    LBuf^.Head := nil;
    LBuf^.Tail := nil;
    LBuf^.Count := 0;
    if (LHead <> nil) and (LTail <> nil) then
      RemoteFreePushList(LIdx, LHead, LTail);
  end;
end;

procedure TShardedBlockPool.IndexShardNewSegmentsLocked(aShard: Integer);
var
  LSegCount: SizeInt;
  LSegIdx: SizeInt;
  LStart, LEnd: PByte;
  LNewCap: SizeUInt;
  LAdded: SizeUInt;
  LRouteIdx: SizeInt;
  LWrite: SizeInt;
begin
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;

  LSegCount := SizeInt(FShards[aShard].Pool.SegmentCount);
  if LSegCount <= FShards[aShard].KnownSegmentCount then Exit;

  RouteWriteLock;
  try
    // Segments are kept sorted by Base inside TGrowingBlockPool, so new segments may not be appended.
    // Rebuild this shard's routing entries to avoid missing ranges.
    LWrite := 0;
    for LRouteIdx := 0 to High(FRoutes) do
      if FRoutes[LRouteIdx].Shard <> aShard then
      begin
        FRoutes[LWrite] := FRoutes[LRouteIdx];
        Inc(LWrite);
      end;
    SetLength(FRoutes, LWrite);

    for LSegIdx := 0 to LSegCount - 1 do
      if FShards[aShard].Pool.GetSegmentRegion(LSegIdx, LStart, LEnd) then
      begin
        RouteInsert(LStart, LEnd, aShard);
        IndexSegmentPagesLocked(aShard, LStart, LEnd);
      end;
  finally
    RouteWriteUnlock;
  end;

  FShards[aShard].KnownSegmentCount := LSegCount;
  LNewCap := FShards[aShard].Pool.Capacity;
  if LNewCap > FShards[aShard].KnownCapacity then
  begin
    LAdded := LNewCap - FShards[aShard].KnownCapacity;
    FShards[aShard].KnownCapacity := LNewCap;
    if LAdded <> 0 then
      atomic_fetch_add_64(FTotalCapacity, Int64(LAdded));
  end
  else if LNewCap < FShards[aShard].KnownCapacity then
    FShards[aShard].KnownCapacity := LNewCap;
end;

function TShardedBlockPool.GetThreadCacheNode: PThreadCacheNode;
var
  LNode: PThreadCacheNode;
  LAllocSize: SizeUInt;
begin
  Result := nil;
  if FThreadCacheCapacity <= 0 then
    Exit(nil);

  if (GShardedBlockPoolThreadCacheNodeCache.PoolPtr = Pointer(Self)) and
    (GShardedBlockPoolThreadCacheNodeCache.PoolId = FPoolId) and
    (GShardedBlockPoolThreadCacheNodeCache.Node <> nil) then
  begin
    LNode := GShardedBlockPoolThreadCacheNodeCache.Node;
    if LNode^.Epoch <> FCacheEpoch then
      InvalidateThreadCacheNode(LNode);
    Exit(LNode);
  end;

  LNode := GShardedBlockPoolThreadCacheHead;
  while LNode <> nil do
  begin
    if (LNode^.PoolPtr = Pointer(Self)) and (LNode^.PoolId = FPoolId) then
    begin
      if LNode^.Epoch <> FCacheEpoch then
        InvalidateThreadCacheNode(LNode);
      GShardedBlockPoolThreadCacheNodeCache.PoolPtr := Pointer(Self);
      GShardedBlockPoolThreadCacheNodeCache.PoolId := FPoolId;
      GShardedBlockPoolThreadCacheNodeCache.Node := LNode;
      Exit(LNode);
    end;
    LNode := LNode^.Next;
  end;

  if (FShardCount <= 0) or
    (SizeUInt(FShardCount) > ((High(SizeUInt) - SizeUInt(SizeOf(TThreadCacheNode))) div SizeUInt(SizeOf(TRemoteFreeBuf)))) then
    Exit(nil);
  LAllocSize := SizeUInt(SizeOf(TThreadCacheNode)) + SizeUInt(FShardCount) * SizeUInt(SizeOf(TRemoteFreeBuf));
  GetMem(LNode, LAllocSize);
  if LNode = nil then
    Exit(nil);
  FillChar(LNode^, LAllocSize, 0);
  LNode^.PoolPtr := Pointer(Self);
  LNode^.PoolId := FPoolId;
  LNode^.Epoch := FCacheEpoch;
  LNode^.Shard := ChooseShardIndex;
  LNode^.Count := 0;
  LNode^.RemoteBufLen := FShardCount;
  if FShardCount > 0 then
    LNode^.RemoteBufs := Pointer(PByte(LNode) + SizeOf(TThreadCacheNode))
  else
    LNode^.RemoteBufs := nil;
  LNode^.Next := GShardedBlockPoolThreadCacheHead;
  GShardedBlockPoolThreadCacheHead := LNode;
  GShardedBlockPoolThreadCacheNodeCache.PoolPtr := Pointer(Self);
  GShardedBlockPoolThreadCacheNodeCache.PoolId := FPoolId;
  GShardedBlockPoolThreadCacheNodeCache.Node := LNode;
  Result := LNode;
end;

procedure TShardedBlockPool.InvalidateThreadCacheNode(aNode: PThreadCacheNode);
begin
  if aNode = nil then Exit;
  aNode^.Count := 0;
  aNode^.Epoch := FCacheEpoch;
  aNode^.Shard := ChooseShardIndex;
  if (aNode^.RemoteBufs <> nil) and (aNode^.RemoteBufLen > 0) then
    FillChar(PByte(aNode^.RemoteBufs)^, SizeUInt(aNode^.RemoteBufLen) * SizeUInt(SizeOf(TRemoteFreeBuf)), 0);
end;

procedure TShardedBlockPool.FlushThreadCacheLocked(aShard: Integer; aNode: PThreadCacheNode; aFlushCount: Integer);
var
  LPtr: Pointer;
begin
  if (aNode = nil) or (aFlushCount <= 0) then Exit;
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;

  while (aFlushCount > 0) and (aNode^.Count > 0) do
  begin
    Dec(aNode^.Count);
    LPtr := aNode^.Ptrs[aNode^.Count];
    FShards[aShard].Pool.Release(LPtr);
    Dec(aFlushCount);
  end;
end;

	constructor TShardedBlockPool.Create(const aConfig: TShardedBlockPoolConfig);
var
  LShardCount: Integer;
  LIdx: Integer;
  LPerShardCap: SizeUInt;
  LShardConfig: TGrowingBlockPoolConfig;
  LStart, LEnd: PByte;
 LSegIdx: SizeInt;
  LShift: SizeUInt;
  LTmp: SizeUInt;
  LPageSize: SizeUInt;
  LPageShift: SizeUInt;
  LPageTmp: SizeUInt;
  LApproxPages: SizeUInt;
  LStartKey: PtrUInt;
  LEndKey: PtrUInt;
  LTotalCap: Int64;
	begin
	  inherited Create;

	  FRoutingState := 0;
	  RouteClear;

  FPoolId := NextShardedBlockPoolId;
  FCacheEpoch := 1;
  FThreadCacheCapacity := aConfig.ThreadCacheCapacity;
  if FThreadCacheCapacity < 0 then
    FThreadCacheCapacity := 0
  else if FThreadCacheCapacity > SHARDED_BLOCKPOOL_THREADCACHE_MAX then
    FThreadCacheCapacity := SHARDED_BLOCKPOOL_THREADCACHE_MAX;
  FThreadCacheCheckDoubleFree := aConfig.ThreadCacheCheckDoubleFree;
  FTrackInUse := aConfig.TrackInUse;
  FTotalCapacity := 0;

  FConfig := aConfig.Pool;
  LShardCount := NormalizeShardCount(aConfig.ShardCount);
  FShardCount := LShardCount;
  FShardMask := LShardCount - 1;
  SetLength(FShards, LShardCount);

  if FConfig.InitialCapacity = 0 then
    FConfig.InitialCapacity := 64;
  LPerShardCap := (FConfig.InitialCapacity + SizeUInt(LShardCount) - 1) div SizeUInt(LShardCount);
  if LPerShardCap = 0 then
    LPerShardCap := 1;

  // create shards
  for LIdx := 0 to LShardCount - 1 do
  begin
    FShards[LIdx].Lock := Mutex;
    LShardConfig := FConfig;
    LShardConfig.InitialCapacity := LPerShardCap;
    // sharded pool relies on stable routing; keep segments by default
    if not LShardConfig.KeepSegments then
      LShardConfig.KeepSegments := True;
    FShards[LIdx].Pool := TGrowingBlockPool.Create(LShardConfig);
    FShards[LIdx].KnownCapacity := FShards[LIdx].Pool.Capacity;
    FShards[LIdx].KnownSegmentCount := SizeInt(FShards[LIdx].Pool.SegmentCount);
    FShards[LIdx].InUseCount := 0;
    FShards[LIdx].RemoteFreeHead := nil;
  end;

  // normalize actual block geometry (may be rounded by TGrowingBlockPool)
  if (LShardCount > 0) and (FShards[0].Pool <> nil) then
    FBlockSize := FShards[0].Pool.BlockSize
  else
    FBlockSize := 0;

  FBlockMask := 0;
  FBlockShift := 0;
  if (FBlockSize <> 0) and IsPowerOfTwo(FBlockSize) then
  begin
    FBlockMask := FBlockSize - 1;
    LShift := 0;
    LTmp := FBlockSize;
    while LTmp > 1 do
    begin
      Inc(LShift);
      LTmp := LTmp shr 1;
    end;
    FBlockShift := LShift;
  end;

  // page-map granularity (default 4096 bytes)
  LPageSize := SizeUInt(MEM_PAGE_SIZE);
  if (LPageSize <> 0) and IsPowerOfTwo(LPageSize) then
  begin
    LPageShift := 0;
    LPageTmp := LPageSize;
    while LPageTmp > 1 do
    begin
      Inc(LPageShift);
      LPageTmp := LPageTmp shr 1;
    end;
    FPageShift := LPageShift;
  end
  else
    FPageShift := 12;

  // init page map with a rough capacity estimate (keep load <= 0.5)
  LApproxPages := 0;
  for LIdx := 0 to LShardCount - 1 do
    for LSegIdx := 0 to SizeInt(FShards[LIdx].Pool.SegmentCount) - 1 do
      if FShards[LIdx].Pool.GetSegmentRegion(LSegIdx, LStart, LEnd) then
      begin
        if (LStart <> nil) and (LEnd <> nil) and (LEnd > LStart) then
        begin
          LStartKey := PtrUInt(LStart) shr FPageShift;
          LEndKey := (PtrUInt(LEnd) - 1) shr FPageShift;
          if LEndKey >= LStartKey then
            Inc(LApproxPages, SizeUInt(LEndKey - LStartKey + 1));
        end;
      end;
  if LApproxPages < HASH_MIN_CAP then
    LApproxPages := HASH_MIN_CAP;
  PageMapInit(LApproxPages * 2);

	  // index initial segments for all shards
	  RouteWriteLock;
	  try
	    for LIdx := 0 to LShardCount - 1 do
	      for LSegIdx := 0 to SizeInt(FShards[LIdx].Pool.SegmentCount) - 1 do
	        if FShards[LIdx].Pool.GetSegmentRegion(LSegIdx, LStart, LEnd) then
          begin
	          RouteInsert(LStart, LEnd, LIdx);
            IndexSegmentPagesLocked(LIdx, LStart, LEnd);
          end;
	  finally
	    RouteWriteUnlock;
	  end;

  // initialize fast stats
  LTotalCap := 0;
  for LIdx := 0 to High(FShards) do
    if FShards[LIdx].Pool <> nil then
      Inc(LTotalCap, Int64(FShards[LIdx].Pool.Capacity));
  FTotalCapacity := LTotalCap;
end;

constructor TShardedBlockPool.Create(const aConfig: TGrowingBlockPoolConfig; aShardCount: Integer);
var
  LCfg: TShardedBlockPoolConfig;
begin
  LCfg.Pool := aConfig;
  LCfg.ShardCount := aShardCount;
  LCfg.ThreadCacheCapacity := 0;
  LCfg.ThreadCacheCheckDoubleFree := True;
  LCfg.TrackInUse := True;
  Create(LCfg);
end;

constructor TShardedBlockPool.Create(aBlockSize, aCapacity: SizeUInt; aShardCount: Integer; aAlignment: SizeUInt);
var
  LCfg: TShardedBlockPoolConfig;
begin
  LCfg := TShardedBlockPoolConfig.Default(aBlockSize, aCapacity, aShardCount);
  LCfg.Pool.Alignment := aAlignment;
  Create(LCfg);
end;

	destructor TShardedBlockPool.Destroy;
var
  LIdx: Integer;
	begin
	  // lock shards to avoid racing with concurrent frees/allocs
	  for LIdx := 0 to High(FShards) do
	    if FShards[LIdx].Lock <> nil then
	      FShards[LIdx].Lock.Acquire;
	  try
	    RouteWriteLock;
	    try
	      RouteClear;
        PageMapClear;
	    finally
	      RouteWriteUnlock;
	    end;

    for LIdx := 0 to High(FShards) do
    begin
      if FShards[LIdx].Pool <> nil then
        FlushRemoteFreesLocked(LIdx);
      FreeAndNil(FShards[LIdx].Pool);
    end;
  finally
    for LIdx := 0 to High(FShards) do
      if FShards[LIdx].Lock <> nil then
        FShards[LIdx].Lock.Release;
  end;

  for LIdx := 0 to High(FShards) do
    FShards[LIdx].Lock := nil;

	  inherited Destroy;
	end;

function TShardedBlockPool.Acquire: Pointer;
var
  LShard: Integer;
  LNode: PThreadCacheNode;
  LCachedShard: Integer;
begin
  Result := nil;
  if FShardCount <= 0 then Exit(nil);

  if FThreadCacheCapacity > 0 then
  begin
    LNode := GetThreadCacheNode;
    if (LNode <> nil) and (LNode^.Count > 0) then
    begin
      Dec(LNode^.Count);
      Result := LNode^.Ptrs[LNode^.Count];
      LCachedShard := LNode^.Shard;
      if FTrackInUse and (LCachedShard >= 0) and (LCachedShard < FShardCount) then
        atomic_fetch_add_64(FShards[LCachedShard].InUseCount, 1, mo_relaxed);
      Exit;
    end;

    if LNode <> nil then
      LShard := LNode^.Shard
    else
      LShard := GetLocalShardIndex;
  end
  else
    LShard := GetLocalShardIndex;
  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    Result := FShards[LShard].Pool.Acquire;
    if Result <> nil then
      IndexShardNewSegmentsLocked(LShard);
  finally
    FShards[LShard].Lock.Release;
  end;

  if FTrackInUse and (Result <> nil) then
    atomic_fetch_add_64(FShards[LShard].InUseCount, 1, mo_relaxed);
end;

function TShardedBlockPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  aPtr := Acquire;
  Result := aPtr <> nil;
end;

procedure TShardedBlockPool.Release(aPtr: Pointer);
var
  LShard: Integer;
  LLocalShard: Integer;
  LBase: PByte;
  LDiff: PtrUInt;
  LNode: PThreadCacheNode;
  LIdx: Integer;
  LFlush: Integer;
begin
  if aPtr = nil then Exit;

  if not TryRoute(aPtr, LShard, LBase) then
    raise EAllocError.Create(aeInvalidPointer, 'TShardedBlockPool.Release: pointer does not belong to this pool');

  // Quick alignment check to avoid corrupting memory on remote-free fast path.
  if LBase = nil then
    raise EAllocError.Create(aeInternalError, 'TShardedBlockPool.Release: invalid routing entry');
  LDiff := PtrUInt(aPtr) - PtrUInt(LBase);
  if FBlockMask <> 0 then
  begin
    if (LDiff and PtrUInt(FBlockMask)) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, 'TShardedBlockPool.Release: misaligned pointer');
  end
  else
  begin
    if (FBlockSize <> 0) and ((LDiff mod FBlockSize) <> 0) then
      raise EAllocError.Create(aeInvalidPointer, 'TShardedBlockPool.Release: misaligned pointer');
  end;

  LLocalShard := GetLocalShardIndex;
  if (FThreadCacheCapacity > 0) and (LLocalShard = LShard) then
  begin
    LNode := GetThreadCacheNode;
    if (LNode <> nil) and (LNode^.Shard = LShard) then
    begin
      if FThreadCacheCheckDoubleFree then
        for LIdx := 0 to LNode^.Count - 1 do
          if LNode^.Ptrs[LIdx] = aPtr then
            raise EAllocError.Create(aeDoubleFree, 'TShardedBlockPool.Release: double free detected (thread cache)');

      if LNode^.Count >= FThreadCacheCapacity then
      begin
        LFlush := FThreadCacheCapacity div 2;
        if LFlush < 1 then
          LFlush := 1;
        if LFlush > LNode^.Count then
          LFlush := LNode^.Count;

        FShards[LShard].Lock.Acquire;
        try
          FlushRemoteFreesLocked(LShard);
          FlushThreadCacheLocked(LShard, LNode, LFlush);
        finally
          FShards[LShard].Lock.Release;
        end;
      end;

      if LNode^.Count < FThreadCacheCapacity then
      begin
        LNode^.Ptrs[LNode^.Count] := aPtr;
        Inc(LNode^.Count);
        if FTrackInUse then
          atomic_fetch_add_64(FShards[LShard].InUseCount, -1, mo_relaxed);
        Exit;
      end;
    end;
  end;

  {$IFNDEF FAF_MEM_DEBUG}
  // Cross-shard frees are enqueued lock-free and drained by the owning shard.
  if (LLocalShard >= 0) and (LLocalShard <> LShard) then
  begin
    if FThreadCacheCapacity > 0 then
    begin
      LNode := GetThreadCacheNode;
      if LNode <> nil then
        RemoteFreeBufferPush(LNode, LShard, aPtr)
      else
        RemoteFreePush(LShard, aPtr);
    end
    else
      RemoteFreePush(LShard, aPtr);
    if FTrackInUse then
      atomic_fetch_add_64(FShards[LShard].InUseCount, -1, mo_relaxed);
    Exit;
  end;
  {$ENDIF}

  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    FShards[LShard].Pool.Release(aPtr);
  finally
    FShards[LShard].Lock.Release;
  end;

  if FTrackInUse then
    atomic_fetch_add_64(FShards[LShard].InUseCount, -1, mo_relaxed);
end;

procedure TShardedBlockPool.Reset;
var
  LIdx: Integer;
  LSegIdx: SizeInt;
  LStart, LEnd: PByte;
begin
  // lock shards first (avoid deadlock with alloc paths that may take routing write lock)
  for LIdx := 0 to High(FShards) do
    FShards[LIdx].Lock.Acquire;
  try
    for LIdx := 0 to High(FShards) do
      if FShards[LIdx].Pool <> nil then
      begin
        FlushRemoteFreesLocked(LIdx);
        FShards[LIdx].Pool.Reset;
        FShards[LIdx].KnownSegmentCount := SizeInt(FShards[LIdx].Pool.SegmentCount);
      end;

    RouteWriteLock;
    try
      RouteClear;
      PageMapClear;
      for LIdx := 0 to High(FShards) do
        if FShards[LIdx].Pool <> nil then
          for LSegIdx := 0 to SizeInt(FShards[LIdx].Pool.SegmentCount) - 1 do
            if FShards[LIdx].Pool.GetSegmentRegion(LSegIdx, LStart, LEnd) then
            begin
              RouteInsert(LStart, LEnd, LIdx);
              IndexSegmentPagesLocked(LIdx, LStart, LEnd);
            end;
    finally
      RouteWriteUnlock;
    end;
  finally
    for LIdx := 0 to High(FShards) do
      FShards[LIdx].Lock.Release;
  end;

  for LIdx := 0 to High(FShards) do
    atomic_store_64(FShards[LIdx].InUseCount, 0, mo_relaxed);
  Inc(FCacheEpoch);
end;

function TShardedBlockPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TShardedBlockPool.Capacity: SizeUInt;
var
  LCap: Int64;
begin
  LCap := atomic_load_64(FTotalCapacity);
  if LCap < 0 then LCap := 0;
  Result := SizeUInt(LCap);
end;

function TShardedBlockPool.Available: SizeUInt;
var
  LCap: Int64;
  LInUse: Int64;
  LSum: Int64;
  LIdx: Integer;
  LAvail: Int64;
begin
  if not FTrackInUse then
  begin
    LSum := 0;
    for LIdx := 0 to High(FShards) do
    begin
      if FShards[LIdx].Lock <> nil then
        FShards[LIdx].Lock.Acquire;
      try
        FlushRemoteFreesLocked(LIdx);
        if FShards[LIdx].Pool <> nil then
          Inc(LSum, Int64(FShards[LIdx].Pool.Available));
      finally
        if FShards[LIdx].Lock <> nil then
          FShards[LIdx].Lock.Release;
      end;
    end;

    if LSum < 0 then LSum := 0;
    Exit(SizeUInt(LSum));
  end;

  LCap := atomic_load_64(FTotalCapacity);
  LSum := 0;
  for LIdx := 0 to High(FShards) do
    Inc(LSum, atomic_load_64(FShards[LIdx].InUseCount));
  LInUse := LSum;
  LAvail := LCap - LInUse;
  if LAvail < 0 then LAvail := 0;
  Result := SizeUInt(LAvail);
end;

function TShardedBlockPool.InUse: SizeUInt;
var
  LSum: Int64;
  LIdx: Integer;
  LCap: Int64;
  LAvail: Int64;
begin
  if not FTrackInUse then
  begin
    LCap := atomic_load_64(FTotalCapacity);
    LSum := 0;
    for LIdx := 0 to High(FShards) do
    begin
      if FShards[LIdx].Lock <> nil then
        FShards[LIdx].Lock.Acquire;
      try
        FlushRemoteFreesLocked(LIdx);
        if FShards[LIdx].Pool <> nil then
          Inc(LSum, Int64(FShards[LIdx].Pool.Available));
      finally
        if FShards[LIdx].Lock <> nil then
          FShards[LIdx].Lock.Release;
      end;
    end;
    LAvail := LSum;
    LSum := LCap - LAvail;
    if LSum < 0 then LSum := 0;
    Exit(SizeUInt(LSum));
  end;

  LSum := 0;
  for LIdx := 0 to High(FShards) do
    Inc(LSum, atomic_load_64(FShards[LIdx].InUseCount));
  if LSum < 0 then LSum := 0;
  Result := SizeUInt(LSum);
end;

function TShardedBlockPool.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then Exit(0);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    LPtr := Acquire;
    if LPtr = nil then
      Break;
    aPtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TShardedBlockPool.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  if aCount <= 0 then Exit;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    Release(aPtrs[LIdx]);
  end;
end;

procedure TShardedBlockPool.FlushThreadCache;
var
  LNode: PThreadCacheNode;
  LShard: Integer;
  LCount: Integer;
begin
  if FThreadCacheCapacity <= 0 then Exit;
  LNode := GetThreadCacheNode;
  if LNode = nil then Exit;
  if LNode^.Epoch <> FCacheEpoch then
  begin
    InvalidateThreadCacheNode(LNode);
    Exit;
  end;

  LShard := LNode^.Shard;
  LCount := LNode^.Count;
  if (LShard < 0) or (LShard >= FShardCount) then
  begin
    InvalidateThreadCacheNode(LNode);
    Exit;
  end;

  if LCount > 0 then
  begin
    FShards[LShard].Lock.Acquire;
    try
      FlushRemoteFreesLocked(LShard);
      FlushThreadCacheLocked(LShard, LNode, LCount);
    finally
      FShards[LShard].Lock.Release;
    end;
  end;

  FlushThreadRemoteBuffers(LNode);
end;

function TShardedBlockPool.ShardCount: Integer;
begin
  Result := FShardCount;
end;

{$POP}

end.
