unit nextpas.core.mem.pool.slab.sharded;

{$I nextpas.core.settings.inc}

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions used in routing maps

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.time.cpu,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.error;

type
  {**
   * TSlabPoolSharded
   *
   * @desc “性能向”并发 slab 池：多分片（shards）+ 每分片独立锁，降低锁竞争。
   *       释放路由采用只读路由表（page->shard）+ fallback 精确表（ptr->shard），避免扫描。
   *
   * @note
   *   - Reset 会使之前分配的指针失效；调用端需自行保证语义正确。
   *   - 仍保持 TSlabPool 的严格所有权：释放非本池指针会抛 ESlabPoolCorruption。
   *}
  TSlabPoolSharded = class(TInterfacedObject, IMemoryPool, IAllocator)
  private
    type
      TShard = record
        Pool: TSlabPool;
        Lock: IMutex;
        KnownSegmentCount: Integer;
        RemoteFreeHead: Pointer; // lock-free remote frees (slab only)
      end;
  private
    FAllocator: IAllocator;
    FConfig: TSlabConfig;
    FInitialCapacity: SizeUInt;
    FMinShift: SizeUInt;
    FShardMask: Integer;
    FShardCount: Integer;
    FShards: array of TShard;

    // Routing maps are protected by RWLock; reads are concurrent, writes are rare.
    FRoutingLock: IRWLock;

    // pageKey -> shardIndex map (slab segments, no deletions)
    FPageShift: SizeUInt;
    FPageKeys: array of PtrUInt;   // 0 = empty
    FPageVals: array of Integer;   // shard index
    FPageMask: SizeUInt;
    FPageHighShift: SizeUInt;
    FPageCount: SizeUInt;

    // userPtr -> shardIndex map (fallback allocations, deletions via tombstones)
    FFbKeys: array of PtrUInt;     // 0 = empty, 1 = tombstone
    FFbVals: array of Integer;     // shard index
    FFbMask: SizeUInt;
    FFbHighShift: SizeUInt;
    FFbCount: SizeUInt;            // live entries
    FFbFill: SizeUInt;             // live + tombstones
  private
    function IsPowerOfTwoInt(aValue: Integer): Boolean; inline;
    function NextPow2Int(aValue: Integer): Integer; inline;
    function NormalizeShardCount(aShardCount: Integer): Integer;
    function ChooseShardIndex: Integer; inline;
    function PageKeyOf(aPtr: Pointer): PtrUInt; inline;

    procedure PageMapInit(aMinCapacity: SizeUInt);
    procedure PageMapClear;
    procedure PageMapGrowIfNeeded(aNeedMore: SizeUInt);
    procedure PageMapInsert(aKey: PtrUInt; aShard: Integer);
    function PageMapLookup(aKey: PtrUInt; out aShard: Integer): Boolean; inline;

    procedure FbMapInit(aMinCapacity: SizeUInt);
    procedure FbMapClear;
    procedure FbMapRehash(aNewCapacity: SizeUInt);
    procedure FbMapGrowIfNeeded(aNeedMore: SizeUInt);
    procedure FbMapInsert(aPtr: Pointer; aShard: Integer);
    function FbMapLookup(aPtr: Pointer; out aShard: Integer): Boolean; inline;
    function FbMapDelete(aPtr: Pointer): Boolean;

    procedure IndexShardNewSegmentsLocked(aShard: Integer);
    procedure IndexSegmentPagesLocked(aShard: Integer; aSegIndex: Integer);

    procedure FlushRemoteFreesLocked(aShard: Integer); inline; // requires shard lock
    procedure RemoteFreePush(aShard: Integer; aPtr: Pointer); inline; // lock-free push

    function NaturalAlignmentForSize(const aSize: SizeUInt): SizeUInt; inline;
    function ShouldUseFallback(const aSize: SizeUInt): Boolean; inline;
    function TryRouteShardIndex(aPtr: Pointer; out aShard: Integer; out aIsFallback: Boolean): Boolean;
  public
    constructor Create(aCapacity: SizeUInt; aShardCount: Integer = 0; aAllocator: IAllocator = nil; aMinShift: SizeUInt = 3); overload;
    constructor Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aShardCount: Integer = 0; aAllocator: IAllocator = nil); overload;
    destructor Destroy; override;
  public
    // IPool
    function Acquire(out aPtr: Pointer): Boolean;
    function TryAcquire(out aPtr: Pointer): Boolean; inline;
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(aPtr: Pointer);
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);
    procedure Reset;

    // IMemoryPool
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);

    // IAllocator aligned allocation
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);

    // IAllocator capability
    function Traits: TAllocatorTraits;
  public
    // Diagnostics
    function Owns(aPtr: Pointer): Boolean;
    function MemSizeOf(aPtr: Pointer): SizeUInt;
    function Stats: TSlabPoolStats;
    function GetPerfCounters: TSlabPerfCounters;
    function ShardCount: Integer; inline;
    function SegmentCount: Integer;
    function FallbackAllocCount: Integer;
  end;

implementation

const
  HASH_MIN_CAP = 64;
  FB_TOMBSTONE = PtrUInt(1);

{$push}
{$Q-}
function MulHash64(x: QWord): QWord; inline;
begin
  Result := x * QWord(11400714819323198485);
end;
{$pop}

function IsPowerOfTwoSize(aValue: SizeUInt): Boolean; inline;
begin
  Result := (aValue <> 0) and ((aValue and (aValue - 1)) = 0);
end;

function NextPow2Size(const aValue: SizeUInt): SizeUInt; inline;
var
  LResult: SizeUInt;
begin
  if aValue <= 1 then Exit(1);
  LResult := 1;
  while LResult < aValue do
    LResult := LResult shl 1;
  Result := LResult;
end;

{ TSlabPoolSharded }

procedure TSlabPoolSharded.FlushRemoteFreesLocked(aShard: Integer);
var
  LNode: Pointer;
  LNext: Pointer;
begin
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;

  LNode := atomic_load(FShards[aShard].RemoteFreeHead);
  if LNode = nil then Exit;
  LNode := atomic_exchange(FShards[aShard].RemoteFreeHead, nil);
  while LNode <> nil do
  begin
    LNext := PPointer(LNode)^;
    FShards[aShard].Pool.FreeMem(LNode);
    LNode := LNext;
  end;
end;

procedure TSlabPoolSharded.RemoteFreePush(aShard: Integer; aPtr: Pointer);
var
  LExpected: Pointer;
begin
  if aPtr = nil then Exit;
  if (aShard < 0) or (aShard >= FShardCount) then
    raise EInvalidArgument.Create('TSlabPoolSharded.RemoteFreePush: invalid shard index');

  LExpected := atomic_load(FShards[aShard].RemoteFreeHead);
  repeat
    PPointer(aPtr)^ := LExpected;
  until atomic_compare_exchange_strong(FShards[aShard].RemoteFreeHead, LExpected, aPtr);
end;

function TSlabPoolSharded.IsPowerOfTwoInt(aValue: Integer): Boolean; inline;
begin
  Result := (aValue > 0) and ((aValue and (aValue - 1)) = 0);
end;

function TSlabPoolSharded.NextPow2Int(aValue: Integer): Integer; inline;
var
  LResult: Integer;
begin
  if aValue <= 1 then Exit(1);
  LResult := 1;
  while LResult < aValue do
    LResult := LResult shl 1;
  Result := LResult;
end;

function TSlabPoolSharded.NormalizeShardCount(aShardCount: Integer): Integer;
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

function TSlabPoolSharded.ChooseShardIndex: Integer; inline;
var
  LId: QWord;
begin
  if FShardCount <= 1 then Exit(0);
  LId := QWord(CurrentThreadId);
  Result := Integer(MulHash64(LId) and QWord(FShardMask));
end;

function TSlabPoolSharded.PageKeyOf(aPtr: Pointer): PtrUInt; inline;
begin
  Result := PtrUInt(aPtr) shr FPageShift;
end;

procedure TSlabPoolSharded.PageMapInit(aMinCapacity: SizeUInt);
var
  LCap, LIdx, LLog, LTmp: SizeUInt;
begin
  LCap := HASH_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FPageKeys, LCap);
  SetLength(FPageVals, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FPageKeys[LIdx] := 0;
    FPageVals[LIdx] := -1;
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

procedure TSlabPoolSharded.PageMapClear;
var
  LIdx: SizeUInt;
begin
  for LIdx := 0 to FPageMask do
  begin
    FPageKeys[LIdx] := 0;
    FPageVals[LIdx] := -1;
  end;
  FPageCount := 0;
end;

procedure TSlabPoolSharded.PageMapGrowIfNeeded(aNeedMore: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldVals: array of Integer;
  LOldCap, LIdx, LLog, LTmp: SizeUInt;
  LKey: PtrUInt;
  LVal: Integer;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if (FPageCount + aNeedMore) <= ((FPageMask + 1) shr 1) then Exit;

  LOldCap := FPageMask + 1;
  LOldKeys := FPageKeys;
  LOldVals := FPageVals;

  SetLength(FPageKeys, LOldCap shl 1);
  SetLength(FPageVals, LOldCap shl 1);
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
    FPageVals[LIdx] := -1;
  end;
  FPageCount := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if LKey <> 0 then
    begin
      LVal := LOldVals[LIdx];
      LHash := MulHash64(LKey);
      LPos := (LHash shr FPageHighShift) and FPageMask;
      while FPageKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FPageMask;
      FPageKeys[LPos] := LKey;
      FPageVals[LPos] := LVal;
      Inc(FPageCount);
    end;
  end;
end;

procedure TSlabPoolSharded.PageMapInsert(aKey: PtrUInt; aShard: Integer);
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  if aKey = 0 then aKey := 1;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FPageHighShift) and FPageMask;
  while FPageKeys[LPos] <> 0 do
    LPos := (LPos + 1) and FPageMask;
  FPageKeys[LPos] := aKey;
  FPageVals[LPos] := aShard;
  Inc(FPageCount);
end;

function TSlabPoolSharded.PageMapLookup(aKey: PtrUInt; out aShard: Integer): Boolean; inline;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  if aKey = 0 then aKey := 1;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FPageHighShift) and FPageMask;
  while True do
  begin
    if FPageKeys[LPos] = 0 then Exit(False);
    if FPageKeys[LPos] = aKey then
    begin
      aShard := FPageVals[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FPageMask;
  end;
end;

procedure TSlabPoolSharded.FbMapInit(aMinCapacity: SizeUInt);
var
  LCap, LIdx, LLog, LTmp: SizeUInt;
begin
  LCap := HASH_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FFbKeys, LCap);
  SetLength(FFbVals, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FFbKeys[LIdx] := 0;
    FFbVals[LIdx] := -1;
  end;
  FFbMask := LCap - 1;
  LLog := 0;
  LTmp := LCap;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FFbHighShift := SizeUInt(64 - LLog);
  FFbCount := 0;
  FFbFill := 0;
end;

procedure TSlabPoolSharded.FbMapClear;
var
  LIdx: SizeUInt;
begin
  for LIdx := 0 to FFbMask do
  begin
    FFbKeys[LIdx] := 0;
    FFbVals[LIdx] := -1;
  end;
  FFbCount := 0;
  FFbFill := 0;
end;

procedure TSlabPoolSharded.FbMapRehash(aNewCapacity: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldVals: array of Integer;
  LOldCap, LIdx, LLog, LTmp: SizeUInt;
  LKey: PtrUInt;
  LVal: Integer;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if aNewCapacity < HASH_MIN_CAP then
    aNewCapacity := HASH_MIN_CAP;
  if not IsPowerOfTwoSize(aNewCapacity) then
    aNewCapacity := NextPow2Size(aNewCapacity);

  LOldCap := FFbMask + 1;
  LOldKeys := FFbKeys;
  LOldVals := FFbVals;

  SetLength(FFbKeys, aNewCapacity);
  SetLength(FFbVals, aNewCapacity);
  FFbMask := aNewCapacity - 1;

  LLog := 0;
  LTmp := aNewCapacity;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FFbHighShift := SizeUInt(64 - LLog);

  for LIdx := 0 to FFbMask do
  begin
    FFbKeys[LIdx] := 0;
    FFbVals[LIdx] := -1;
  end;
  FFbCount := 0;
  FFbFill := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if (LKey <> 0) and (LKey <> FB_TOMBSTONE) then
    begin
      LVal := LOldVals[LIdx];
      LHash := MulHash64(LKey);
      LPos := (LHash shr FFbHighShift) and FFbMask;
      while FFbKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FFbMask;
      FFbKeys[LPos] := LKey;
      FFbVals[LPos] := LVal;
      Inc(FFbCount);
      Inc(FFbFill);
    end;
  end;
end;

procedure TSlabPoolSharded.FbMapGrowIfNeeded(aNeedMore: SizeUInt);
begin
  if (FFbFill + aNeedMore) <= ((FFbMask + 1) shr 1) then Exit;
  FbMapRehash((FFbMask + 1) shl 1);
end;

procedure TSlabPoolSharded.FbMapInsert(aPtr: Pointer; aShard: Integer);
var
  LKey: PtrUInt;
  LPos, LTomb: SizeUInt;
  LHash: QWord;
begin
  if aPtr = nil then Exit;
  LKey := PtrUInt(aPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then
    raise EInvalidArgument.Create('TSlabPoolSharded.FbMapInsert: invalid pointer key');

  FbMapGrowIfNeeded(1);
  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  LTomb := High(SizeUInt);
  while True do
  begin
    if FFbKeys[LPos] = 0 then Break;
    if FFbKeys[LPos] = LKey then
    begin
      FFbVals[LPos] := aShard;
      Exit;
    end;
    if (LTomb = High(SizeUInt)) and (FFbKeys[LPos] = FB_TOMBSTONE) then
      LTomb := LPos;
    LPos := (LPos + 1) and FFbMask;
  end;

  if LTomb <> High(SizeUInt) then
    LPos := LTomb
  else
    Inc(FFbFill); // used a previously empty slot

  FFbKeys[LPos] := LKey;
  FFbVals[LPos] := aShard;
  Inc(FFbCount);
end;

function TSlabPoolSharded.FbMapLookup(aPtr: Pointer; out aShard: Integer): Boolean; inline;
var
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if aPtr = nil then Exit(False);
  LKey := PtrUInt(aPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then Exit(False);

  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  while True do
  begin
    if FFbKeys[LPos] = 0 then Exit(False);
    if FFbKeys[LPos] = LKey then
    begin
      aShard := FFbVals[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FFbMask;
  end;
end;

function TSlabPoolSharded.FbMapDelete(aPtr: Pointer): Boolean;
var
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  Result := False;
  if aPtr = nil then Exit(False);
  LKey := PtrUInt(aPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then Exit(False);

  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  while True do
  begin
    if FFbKeys[LPos] = 0 then Exit(False);
    if FFbKeys[LPos] = LKey then
    begin
      FFbKeys[LPos] := FB_TOMBSTONE;
      FFbVals[LPos] := -1;
      Dec(FFbCount);
      Result := True;
      Exit;
    end;
    LPos := (LPos + 1) and FFbMask;
  end;
end;

procedure TSlabPoolSharded.IndexSegmentPagesLocked(aShard: Integer; aSegIndex: Integer);
var
  LStart, LEnd: PByte;
  LPageShift: SizeUInt;
  LStep: SizeUInt;
  LNeed: SizeUInt;
  LPtr: PByte;
  LKey: PtrUInt;
begin
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;
  if not FShards[aShard].Pool.GetSegmentRegion(aSegIndex, LStart, LEnd, LPageShift) then Exit;
  if LStart = nil then Exit;

  // keep consistent page shift across all shards/segments
  if FPageShift = 0 then
    FPageShift := LPageShift;

  LNeed := (PtrUInt(LEnd) - PtrUInt(LStart)) shr LPageShift;
  if LNeed = 0 then Exit;

  PageMapGrowIfNeeded(LNeed);
  LStep := SizeUInt(1) shl LPageShift;
  LPtr := LStart;
  while PtrUInt(LPtr) < PtrUInt(LEnd) do
  begin
    LKey := (PtrUInt(LPtr) shr LPageShift);
    PageMapInsert(LKey, aShard);
    Inc(PtrUInt(LPtr), LStep);
  end;
end;

procedure TSlabPoolSharded.IndexShardNewSegmentsLocked(aShard: Integer);
var
  LSegCount, LIdx: Integer;
begin
  if (aShard < 0) or (aShard >= FShardCount) then Exit;
  if FShards[aShard].Pool = nil then Exit;

  LSegCount := FShards[aShard].Pool.SegmentCount;
  if LSegCount <= FShards[aShard].KnownSegmentCount then Exit;

  FRoutingLock.AcquireWrite;
  try
    for LIdx := FShards[aShard].KnownSegmentCount to LSegCount - 1 do
      IndexSegmentPagesLocked(aShard, LIdx);
    FShards[aShard].KnownSegmentCount := LSegCount;
  finally
    FRoutingLock.ReleaseWrite;
  end;
end;

function TSlabPoolSharded.NaturalAlignmentForSize(const aSize: SizeUInt): SizeUInt; inline;
var
  LMinSize, LPageSize: SizeUInt;
begin
  if aSize = 0 then Exit(SizeOf(Pointer));
  LMinSize := SizeUInt(1) shl FMinShift;
  if aSize <= LMinSize then Exit(LMinSize);
  LPageSize := SizeUInt(1) shl FPageShift;
  if aSize >= (LPageSize shr 1) then Exit(LPageSize);
  Result := NextPow2Size(aSize);
end;

function TSlabPoolSharded.ShouldUseFallback(const aSize: SizeUInt): Boolean; inline;
begin
  Result := aSize > FInitialCapacity;
end;

function TSlabPoolSharded.TryRouteShardIndex(aPtr: Pointer; out aShard: Integer; out aIsFallback: Boolean): Boolean;
var
  LKey: PtrUInt;
begin
  Result := False;
  aIsFallback := False;
  if aPtr = nil then Exit(False);

  FRoutingLock.AcquireRead;
  try
    LKey := PageKeyOf(aPtr);
    if PageMapLookup(LKey, aShard) then Exit(True);
    if FbMapLookup(aPtr, aShard) then
    begin
      aIsFallback := True;
      Exit(True);
    end;
    Result := False;
  finally
    FRoutingLock.ReleaseRead;
  end;
end;

constructor TSlabPoolSharded.Create(aCapacity: SizeUInt; aShardCount: Integer; aAllocator: IAllocator; aMinShift: SizeUInt);
var
  LShardCount, LIdx: Integer;
  LStart, LEnd: PByte;
  LPageShift: SizeUInt;
  LApproxPages: SizeUInt;
begin
  inherited Create;

  FAllocator := aAllocator;
  if FAllocator = nil then
    FAllocator := nextpas.core.mem.allocator.GetRtlAllocator;

  if aCapacity = 0 then
    aCapacity := 64 * 1024;
  if aMinShift = 0 then
    aMinShift := 3;

  FInitialCapacity := aCapacity;
  FMinShift := aMinShift;
  if FConfig.MinShift = 0 then
  begin
    FConfig := CreateDefaultSlabConfig;
    FConfig.MinShift := aMinShift;
  end;

  LShardCount := NormalizeShardCount(aShardCount);
  FShardCount := LShardCount;
  FShardMask := LShardCount - 1;
  SetLength(FShards, LShardCount);

  FRoutingLock := RWLock;

  // create shards (each shard has its own inner slab pool)
  for LIdx := 0 to LShardCount - 1 do
  begin
    FShards[LIdx].Lock := Mutex;
    FShards[LIdx].Pool := TSlabPool.Create(aCapacity, FConfig, FAllocator);
    FShards[LIdx].KnownSegmentCount := FShards[LIdx].Pool.SegmentCount;
    FShards[LIdx].RemoteFreeHead := nil;
  end;

  // initialize page shift from shard 0 (segment 0)
  FPageShift := 0;
  if (LShardCount > 0) and (FShards[0].Pool <> nil) then
    if FShards[0].Pool.GetSegmentRegion(0, LStart, LEnd, LPageShift) then
      FPageShift := LPageShift;

  // routing maps init (approx capacity: pages-per-shard * shards * 2)
  if FPageShift = 0 then
    FPageShift := 12; // fallback: nginx slab default page shift
  LApproxPages := (aCapacity shr FPageShift) * SizeUInt(LShardCount) * 2;
  if LApproxPages < HASH_MIN_CAP then LApproxPages := HASH_MIN_CAP;
  PageMapInit(LApproxPages);
  FbMapInit(8);

  // index initial segments for all shards
  FRoutingLock.AcquireWrite;
  try
    for LIdx := 0 to LShardCount - 1 do
      IndexSegmentPagesLocked(LIdx, 0);
  finally
    FRoutingLock.ReleaseWrite;
  end;
end;

constructor TSlabPoolSharded.Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aShardCount: Integer; aAllocator: IAllocator);
begin
  FConfig := aConfig;
  if FConfig.MinShift = 0 then
    FConfig.MinShift := 3;
  Create(aCapacity, aShardCount, aAllocator, FConfig.MinShift);
end;

destructor TSlabPoolSharded.Destroy;
var
  LIdx: Integer;
begin
  // lock shards to avoid racing with concurrent frees/allocs
  for LIdx := 0 to High(FShards) do
    if FShards[LIdx].Lock <> nil then
      FShards[LIdx].Lock.Acquire;
  try
    // clear routing maps
    FRoutingLock.AcquireWrite;
    try
      PageMapClear;
      FbMapClear;
    finally
      FRoutingLock.ReleaseWrite;
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

function TSlabPoolSharded.Acquire(out aPtr: Pointer): Boolean;
var
  LUnitSize: SizeUInt;
begin
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  aPtr := GetMem(LUnitSize);
  Result := aPtr <> nil;
end;

function TSlabPoolSharded.TryAcquire(out aPtr: Pointer): Boolean;
begin
  Result := Acquire(aPtr);
end;

function TSlabPoolSharded.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
begin
  Result := 0;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then
      Break;
    if not Acquire(aUnits[LIdx]) then
      Break;
    Inc(Result);
  end;
end;

procedure TSlabPoolSharded.Release(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

procedure TSlabPoolSharded.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then
      Break;
    Release(aUnits[LIdx]);
  end;
end;

procedure TSlabPoolSharded.Reset;
var
  LIdx: Integer;
  LSeg: Integer;
begin
  // acquire shard locks first (avoid deadlock with alloc paths that may take routing write lock)
  for LIdx := 0 to High(FShards) do
    FShards[LIdx].Lock.Acquire;
  try
    for LIdx := 0 to High(FShards) do
      if FShards[LIdx].Pool <> nil then
      begin
        FlushRemoteFreesLocked(LIdx);
        FShards[LIdx].Pool.Reset;
      end;

    FRoutingLock.AcquireWrite;
    try
      PageMapClear;
      FbMapClear;
      for LIdx := 0 to High(FShards) do
      begin
        if FShards[LIdx].Pool = nil then Continue;
        FShards[LIdx].KnownSegmentCount := FShards[LIdx].Pool.SegmentCount;
        for LSeg := 0 to FShards[LIdx].KnownSegmentCount - 1 do
          IndexSegmentPagesLocked(LIdx, LSeg);
      end;
    finally
      FRoutingLock.ReleaseWrite;
    end;
  finally
    for LIdx := 0 to High(FShards) do
      FShards[LIdx].Lock.Release;
  end;
end;

function TSlabPoolSharded.GetMem(aSize: SizeUInt): Pointer;
var
  LShard: Integer;
begin
  if aSize = 0 then Exit(nil);
  LShard := ChooseShardIndex;
  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    Result := FShards[LShard].Pool.GetMem(aSize);
    if Result <> nil then
    begin
      // update segment routing if needed (new segments are rare)
      IndexShardNewSegmentsLocked(LShard);
      // track fallback pointers for exact routing
      if ShouldUseFallback(aSize) then
      begin
        FRoutingLock.AcquireWrite;
        try
          FbMapInsert(Result, LShard);
        finally
          FRoutingLock.ReleaseWrite;
        end;
      end;
    end;
  finally
    FShards[LShard].Lock.Release;
  end;
end;

function TSlabPoolSharded.AllocMem(aSize: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TSlabPoolSharded.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LShard: Integer;
  LIsFallback: Boolean;
  LNewSize: SizeUInt;
  LNewAlign: SizeUInt;
  LNewIsFallback: Boolean;
begin
  if aDst = nil then Exit(GetMem(aSize));
  if aSize = 0 then
  begin
    FreeMem(aDst);
    Exit(nil);
  end;

  if not TryRouteShardIndex(aDst, LShard, LIsFallback) then
    raise ESlabPoolCorruption.Create(aeInvalidPointer, 'Pointer does not belong to this pool');

  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    Result := FShards[LShard].Pool.ReallocMem(aDst, aSize);
    if Result <> nil then
    begin
      IndexShardNewSegmentsLocked(LShard);
      LNewIsFallback := FShards[LShard].Pool.TryGetFallbackAllocInfo(Result, LNewSize, LNewAlign);
      if LIsFallback or LNewIsFallback then
      begin
        FRoutingLock.AcquireWrite;
        try
          if LIsFallback then
            FbMapDelete(aDst);
          if LNewIsFallback then
            FbMapInsert(Result, LShard);
        finally
          FRoutingLock.ReleaseWrite;
        end;
      end;
    end;
  finally
    FShards[LShard].Lock.Release;
  end;
end;

procedure TSlabPoolSharded.FreeMem(aDst: Pointer);
var
  LShard: Integer;
  LIsFallback: Boolean;
  {$IFNDEF FAF_MEM_DEBUG}
  LLocalShard: Integer;
  {$ENDIF}
begin
  if aDst = nil then Exit;

  if not TryRouteShardIndex(aDst, LShard, LIsFallback) then
    raise ESlabPoolCorruption.Create(aeInvalidPointer, 'Pointer does not belong to this pool');

  {$IFNDEF FAF_MEM_DEBUG}
  // Fast path: cross-shard slab frees are enqueued lock-free and drained by the owning shard.
  if not LIsFallback then
  begin
    LLocalShard := ChooseShardIndex;
    if (LLocalShard >= 0) and (LLocalShard <> LShard) then
    begin
      RemoteFreePush(LShard, aDst);
      Exit;
    end;
  end;
  {$ENDIF}

  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    FShards[LShard].Pool.FreeMem(aDst);
    if LIsFallback then
    begin
      FRoutingLock.AcquireWrite;
      try
        FbMapDelete(aDst);
      finally
        FRoutingLock.ReleaseWrite;
      end;
    end;
  finally
    FShards[LShard].Lock.Release;
  end;
end;

function TSlabPoolSharded.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TSlabPoolSharded.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TSlabPoolSharded.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TSlabPoolSharded.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LShard: Integer;
  LNeedFallback: Boolean;
  LNatural: SizeUInt;
begin
  if aSize = 0 then Exit(nil);
  if aAlignment < SizeOf(Pointer) then
    aAlignment := SizeOf(Pointer);
  if not IsPowerOfTwoSize(aAlignment) then
    raise EInvalidArgument.Create('TSlabPoolSharded.AllocAligned: aAlignment must be power of two and >= pointer size');

  LShard := ChooseShardIndex;
  FShards[LShard].Lock.Acquire;
  try
    FlushRemoteFreesLocked(LShard);
    Result := FShards[LShard].Pool.AllocAligned(aSize, aAlignment);
    if Result <> nil then
    begin
      IndexShardNewSegmentsLocked(LShard);
      LNeedFallback := ShouldUseFallback(aSize);
      if not LNeedFallback then
      begin
        LNatural := NaturalAlignmentForSize(aSize);
        LNeedFallback := aAlignment > LNatural;
      end;
      if LNeedFallback then
      begin
        FRoutingLock.AcquireWrite;
        try
          FbMapInsert(Result, LShard);
        finally
          FRoutingLock.ReleaseWrite;
        end;
      end;
    end;
  finally
    FShards[LShard].Lock.Release;
  end;
end;

procedure TSlabPoolSharded.FreeAligned(aPtr: Pointer);
begin
  FreeMem(aPtr);
end;

function TSlabPoolSharded.Traits: TAllocatorTraits;
begin
  // keep consistent with TSlabPool but mark as thread-safe
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
  Result.HasMemSize := True;
  Result.SupportsAligned := False;
end;

function TSlabPoolSharded.Owns(aPtr: Pointer): Boolean;
var
  LShard: Integer;
  LIsFallback: Boolean;
begin
  Result := TryRouteShardIndex(aPtr, LShard, LIsFallback);
end;

function TSlabPoolSharded.MemSizeOf(aPtr: Pointer): SizeUInt;
var
  LShard: Integer;
  LIsFallback: Boolean;
begin
  if aPtr = nil then Exit(0);
  if not TryRouteShardIndex(aPtr, LShard, LIsFallback) then Exit(0);

  FShards[LShard].Lock.Acquire;
  try
    Result := FShards[LShard].Pool.MemSizeOf(aPtr);
  finally
    FShards[LShard].Lock.Release;
  end;
end;

function TSlabPoolSharded.Stats: TSlabPoolStats;
var
  LIdx: Integer;
  LInner: TSlabPoolStats;
begin
  Result.SegmentCount := 0;
  Result.TotalCapacity := 0;
  Result.TotalUsed := 0;
  Result.FallbackAllocCount := 0;
  Result.FallbackBytes := 0;

  for LIdx := 0 to High(FShards) do
  begin
    FShards[LIdx].Lock.Acquire;
    try
      FlushRemoteFreesLocked(LIdx);
      LInner := FShards[LIdx].Pool.Stats;
    finally
      FShards[LIdx].Lock.Release;
    end;
    Inc(Result.SegmentCount, LInner.SegmentCount);
    Inc(Result.TotalCapacity, LInner.TotalCapacity);
    Inc(Result.TotalUsed, LInner.TotalUsed);
    Inc(Result.FallbackAllocCount, LInner.FallbackAllocCount);
    Inc(Result.FallbackBytes, LInner.FallbackBytes);
  end;
end;

function TSlabPoolSharded.GetPerfCounters: TSlabPerfCounters;
var
  LIdx: Integer;
  LInner: TSlabPerfCounters;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LIdx := 0 to High(FShards) do
  begin
    if FShards[LIdx].Pool = nil then
      Continue;
    FShards[LIdx].Lock.Acquire;
    try
      FlushRemoteFreesLocked(LIdx);
      LInner := FShards[LIdx].Pool.GetPerfCounters;
    finally
      FShards[LIdx].Lock.Release;
    end;
    Result.AllocCalls := Result.AllocCalls + LInner.AllocCalls;
    Result.FreeCalls := Result.FreeCalls + LInner.FreeCalls;
    Result.AllocTime := Result.AllocTime + LInner.AllocTime;
    Result.FreeTime := Result.FreeTime + LInner.FreeTime;
    Result.PageMerges := Result.PageMerges + LInner.PageMerges;
    Result.MergeTime := Result.MergeTime + LInner.MergeTime;
    Result.MergedPages := Result.MergedPages + LInner.MergedPages;
  end;
end;

function TSlabPoolSharded.ShardCount: Integer; inline;
begin
  Result := FShardCount;
end;

function TSlabPoolSharded.SegmentCount: Integer;
var
  LIdx: Integer;
begin
  Result := 0;
  for LIdx := 0 to High(FShards) do
  begin
    FShards[LIdx].Lock.Acquire;
    try
      Inc(Result, FShards[LIdx].Pool.SegmentCount);
    finally
      FShards[LIdx].Lock.Release;
    end;
  end;
end;

function TSlabPoolSharded.FallbackAllocCount: Integer;
var
  LIdx: Integer;
begin
  Result := 0;
  for LIdx := 0 to High(FShards) do
  begin
    FShards[LIdx].Lock.Acquire;
    try
      Inc(Result, FShards[LIdx].Pool.FallbackAllocCount);
    finally
      FShards[LIdx].Lock.Release;
    end;
  end;
end;

{$POP}

end.
