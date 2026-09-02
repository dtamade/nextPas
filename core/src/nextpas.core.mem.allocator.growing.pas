unit nextpas.core.mem.allocator.growing;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.span,
  nextpas.core.mem.central,
  nextpas.core.mem.cache.thread,
  nextpas.core.mem.shuffle;

type
  {** Aggregate scavenger / retention snapshot for TGrowingAllocator.
      Portable alternative to process RSS for SC5-style long-run checks. }
  TGrowingHeapStats = record
    LiveSpans: Int32;
    IdleSpans: Int32;
    DecommittedSpans: Int32;
    FreeSlots: SizeUInt;
    LiveBytes: SizeUInt;        { virtual bytes still held by central spans }
    ReleasedSpans: UInt64;      { lifetime hard FreeMem of idle spans }
    ReleasedBytes: UInt64;
    DecommitEvents: UInt64;
    DecommittedBytes: UInt64;
    OpCounter: UInt64;
  end;

  {** Unified growing allocator.
      Routes allocations through:
        small (≤ MEM_SIZECLASS_MAX) → TLS cache → central pool → new span
        large (> MEM_SIZECLASS_MAX) → direct GetMem

      Architecture (matches Go mcache/mcentral/mheap pattern):
        Layer 1: TThreadCache (threadvar, zero contention, ~5ns)
        Layer 2: TCentralPool (spinlock, batch refill/flush)
        Layer 3: NpSystemGetMem (large allocations only)

      Thread-safe: TLS cache absorbs most traffic; central pool uses spinlock. }
  TGrowingAllocator = class
  private
    FCentrals: array[0..MEM_SIZECLASS_COUNT - 1] of TCentralPool;
    FOpCounter: UInt64;  { Stats-only: last observed per-thread op count
                           (OpCounter property / GetHeapStats). Idle aging
                           uses the pool-local FTick in central instead. }
    procedure InitCentrals;
  public
    constructor Create;
    destructor Destroy; override;

    {** Allocate ASize bytes. Returns nil on failure.
        Small allocations go through TLS cache → central pool.
        Large allocations use direct GetMem. }
    function GetMem(ASize: SizeUInt): Pointer; inline;

    {** Free a block previously allocated by GetMem.
        ASize is required for O(1) size class lookup (hot path). }
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt);

    {** Free a block previously allocated by GetMem.
        Size class is determined by scanning central pool spans.
        Slower than the two-parameter version — use when size is unknown. }
    procedure FreeMem(APtr: Pointer);

    {** Lookup size-class capacity for a block owned by this allocator.
        Returns False for nil, huge/System blocks, or foreign pointers. }
    function TryBlockSize(APtr: Pointer; out ASize: SizeUInt): Boolean;

    {** Allocate ASize bytes, zero-initialized. }
    function AllocMem(ASize: SizeUInt): Pointer;

    {** Batch allocate ACount blocks of ASize bytes each.
        More efficient than N individual GetMem calls: amortizes TLS/refill overhead.
        Returns count actually allocated (may < ACount on OOM). }
    function BatchGetMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer): Word; inline;

    {** Batch free ACount blocks of ASize bytes each. }
    procedure BatchFreeMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer); inline;

    {** Mixed-size batch: allocates then frees N blocks cycling through ASizes[].
        Pre-computes class indices once for maximum throughput.
        ASizes points to an array of SizeUInt values. }
    procedure MixedBatch(ASizes: Pointer; ACount: Integer;
      ABlocks: PPointer); inline;

    {** Resize a block. If the new size fits in the same size class,
        returns the same pointer (zero-copy). Otherwise allocates new,
        copies data, and frees the old block. }
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer;

    {** System-shaped realloc when old size is unknown (span scan or System).
        Prefer ReallocMem(ptr, old, new) on hot paths. }
    function ReallocMem(APtr: Pointer; ANewSize: SizeUInt): Pointer;

    {** Force a scavenge pass across all central pools (release threshold 0).
        Returns number of spans hard-released this pass. }
    function Scavenge: Int32;

    {** Aggregate live + lifetime scavenger counters across size classes. }
    procedure GetHeapStats(out AStats: TGrowingHeapStats);

    {** Monotonic op counter for scavenger idle tracking. }
    property OpCounter: UInt64 read FOpCounter;
  end;

{** Get the global singleton growing allocator. }
function DefaultGrowingAllocator: TGrowingAllocator;

{** Release the global singleton (for cleanup/testing). }
procedure ResetDefaultGrowingAllocator;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.mem.error,
  nextpas.core.system.heap,
  nextpas.core.platform.thread;

const
  { Max threads tracked in global registry (power of 2 for fast modulo). }
  MAX_THREAD_SLOTS = 256;

var
  GGrowingAllocator: TGrowingAllocator;

{ Forward declarations for thread-exit cleanup. }
procedure FlushToCentral(AIndex: Int32; ACount: Word; ABlocks: PPointer); forward;

{ Thread-local cache: one per thread, zero initialization on thread start. }
threadvar
  GThreadCache: TThreadCache;

{ Global registry: maps thread ID → TLS cache pointer.
  Allows cross-thread free to push directly to owner's inbox. }
type
  TThreadSlot = record
    FThreadId: QWord;
    FCache: Pointer;  { Pointer to TThreadCache }
    FActive: Boolean;
  end;

var
  GThreadRegistry: array[0..MAX_THREAD_SLOTS - 1] of TThreadSlot;
  GThreadRegistryLock: SizeUInt;

procedure RegistryLock;
var
  LExpected: SizeUInt;
begin
  LExpected := 0;
  while not atomic_compare_exchange_strong(GThreadRegistryLock, LExpected, 1, mo_acquire, mo_relaxed) do
  begin
    LExpected := 0;
    ThreadSwitch;
  end;
end;

procedure RegistryUnlock;
begin
  atomic_exchange(GThreadRegistryLock, 0, mo_release);
end;

{ Register current thread's TLS cache in global registry. }
procedure RegisterThreadCache;
var
  LSlot: SizeUInt;
  LThreadId: QWord;
begin
  LThreadId := QWord(PtrUInt(platform_thread_id));
  LSlot := SizeUInt(LThreadId) and (MAX_THREAD_SLOTS - 1);
  RegistryLock;
  try
    GThreadRegistry[LSlot].FThreadId := LThreadId;
    GThreadRegistry[LSlot].FCache := @GThreadCache;
    GThreadRegistry[LSlot].FActive := True;
  finally
    RegistryUnlock;
  end;
end;

{ Unregister current thread's TLS cache from global registry.
  Order: clear FCache first (with release), then set FActive = False.
  This ensures concurrent FindThreadCache readers either see a valid
  FCache with FActive=True, or nil FCache with FActive=False. }
procedure UnregisterThreadCache;
var
  LSlot: SizeUInt;
  LThreadId: QWord;
begin
  LThreadId := QWord(PtrUInt(platform_thread_id));
  LSlot := SizeUInt(LThreadId) and (MAX_THREAD_SLOTS - 1);
  RegistryLock;
  try
    if (GThreadRegistry[LSlot].FThreadId = LThreadId) and
       GThreadRegistry[LSlot].FActive then
    begin
      { Mark inactive first, then clear cache pointer.
        FindThreadCache reads FCache then FActive — by marking inactive first
        and issuing a release fence, any concurrent reader that sees FActive=True
        is guaranteed to see the old FCache (still valid at that point).
        Any reader that sees FActive=False returns nil. }
      GThreadRegistry[LSlot].FActive := False;
      atomic_store(GThreadRegistry[LSlot].FCache, nil, mo_release);
    end;
  finally
    RegistryUnlock;
  end;
end;

{ Find TLS cache for a given thread ID (lock-free read).
  Uses acquire loads to prevent TOCTOU: we read FCache first, then
  FActive. If the thread exits between our reads, FActive will be
  False and we return nil.

  On x86-64 aligned loads have acquire semantics by default.
  The AtomicLoadPtr provides the compiler barrier. }
function FindThreadCache(AThreadId: QWord): Pointer;
var
  LSlot: SizeUInt;
begin
  LSlot := SizeUInt(AThreadId) and (MAX_THREAD_SLOTS - 1);
  if GThreadRegistry[LSlot].FThreadId <> AThreadId then
    Exit(nil);
  { Read cache pointer first, then verify active flag.
    If thread exits between these reads, FActive will be False. }
  Result := atomic_load(GThreadRegistry[LSlot].FCache, mo_acquire);
  if (Result <> nil) and (not GThreadRegistry[LSlot].FActive) then
    Result := nil;
end;

{ --- Thread-exit cleanup ---
  UNIX: pthread TLS key destructor. Windows: FlsCallback.
  When a thread exits, the callback flushes all cached blocks
  back to the central pool to prevent leakage. }

var
  GCacheCleanupKey: TPlatformTLSKey;
  GCacheCleanupKeyCreated: Boolean = False;

procedure ThreadExitFlush(AData: Pointer); cdecl;
begin
  if (AData <> nil) and (GGrowingAllocator <> nil) then
  begin
    { Drain cross-thread-freed blocks from per-size-class inboxes first,
      returning them to their respective central pools. }
    ThreadCacheDrainInboxes(GThreadCache, @FlushToCentral);
    { Then flush the local TLS free lists. }
    ThreadCacheFlushAll(GThreadCache, @FlushToCentral);
    UnregisterThreadCache;
  end;
end;

{$IFDEF NEXTPAS_WINDOWS}
procedure ThreadExitFlsCallback(lpFlsData: Pointer); stdcall;
begin
  ThreadExitFlush(lpFlsData);
end;
{$ENDIF}

{ Fast inline size class lookup — same logic as the band checks in GetMem/FreeMem
  but as a single function for use in ReallocMem's same-class check.
  Must produce the same index as SizeClassIndex() from mem.sizeclass.
  Band layout: 16-256 (step 16, 16 classes), 256-1024 (step 64, 13 classes). }
function FastSizeClassIndex(ASize: SizeUInt): Int32; inline;
begin
  if ASize <= 256 then
    Result := Int32((ASize + 15) shr 4) - 1
  else if ASize <= 1024 then
    Result := 16 + Int32((ASize + 63 - 256) shr 6)
  else
    Result := SizeClassIndex(ASize);
end;

procedure ValidateFastSizeClassIndex;
var
  LCheckSize: SizeUInt;
begin
  for LCheckSize := 16 to 1024 do
    if FastSizeClassIndex(LCheckSize) <> SizeClassIndex(LCheckSize) then
      raise EAllocError.Create(aeInternalError,
      FormatAllocErrorMsg('TGrowingAllocator', 'FastSizeClassIndex',
        'formula mismatch: sizeclass table inconsistency detected'));
end;

{ Refill/Flush callbacks (standalone functions for TRefillProc/TFlushProc) --- }

function RefillFromCentral(AIndex: Int32; ACount: Word;
  ABlocks: PPointer): Word;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit(0);
  if GGrowingAllocator = nil then
    Exit(0);
  Result := CentralPoolAlloc(GGrowingAllocator.FCentrals[AIndex], ACount, ABlocks);
end;

procedure FlushToCentral(AIndex: Int32; ACount: Word;
  ABlocks: PPointer);
var
  I: Word;
  LOldHead, LExpected: Pointer;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit;
  if GGrowingAllocator = nil then
    Exit;
  if ACount = 0 then
    Exit;
  { Chain all blocks into a linked list, then CAS entire chain into inbox
    (single atomic swap instead of N individual CAS pushes).
    Loop starts at 1: with I: Word, a bound of "ACount - 2" underflows to
    65535 when ACount = 1 (FPC converts the bound to the loop var type),
    turning a single-block flush into a 64Ki wild-write loop. }
  for I := 1 to ACount - 1 do
    PFreeNode(ABlocks[I - 1])^.FNext := PFreeNode(ABlocks[I]);
  PFreeNode(ABlocks[ACount - 1])^.FNext := nil;
  repeat
    LOldHead := GGrowingAllocator.FCentrals[AIndex].FInboxHead;
    PFreeNode(ABlocks[ACount - 1])^.FNext := PFreeNode(LOldHead);
    LExpected := LOldHead;
  until atomic_compare_exchange_strong(GGrowingAllocator.FCentrals[AIndex].FInboxHead,
    LExpected, ABlocks[0], mo_acq_rel, mo_acquire);
end;

{ --- TGrowingAllocator --- }

procedure TGrowingAllocator.InitCentrals;
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
    CentralPoolInit(FCentrals[I], SizeClasses[I]);
end;

constructor TGrowingAllocator.Create;
begin
  inherited Create;
  InitCentrals;
end;

destructor TGrowingAllocator.Destroy;
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
    CentralPoolDestroy(FCentrals[I]);
  inherited Destroy;
end;

{$push}{$R-} { Range checks disabled in hot path for performance. }
function TGrowingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LIndex: Int32;
  LNode: PFreeNode;
begin
  if ASize = 0 then
    Exit(nil);
  Inc(GThreadCache.FOpCount);
  { Register thread-exit cleanup callback and global registry (once per thread). }
  if GThreadCache.FOpCount = 1 then
  begin
    RegisterThreadCache;
    if GCacheCleanupKeyCreated then
      platform_tls_set(GCacheCleanupKey, @GThreadCache);
  end;
  { Periodic scavenge: uses thread-local counter in GThreadCache. }
  if (GThreadCache.FOpCount and (SCAVENGER_CHECK_INTERVAL - 1)) = 0 then
  begin
    atomic_exchange_64(FOpCounter, GThreadCache.FOpCount, mo_relaxed);
    for LIndex := 0 to MEM_SIZECLASS_COUNT - 1 do
      ScavengeCentralPools(FCentrals[LIndex], SCAVENGER_IDLE_THRESHOLD);
  end;
  { Huge allocation: skip size class lookup, direct NpSystemGetMem. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    Result := NpSystemGetMem(ASize);
    Exit;
  end;
  { Size-class index: must match SizeClassIndex (see FastSizeClassIndex).
    Prior band1 formula (size shr 6)+14 was off-by-one vs the class table and
    mixed freelist slots across classes, truncating ReallocMem copies. }
  LIndex := FastSizeClassIndex(ASize);
  if LIndex >= 0 then
  begin
    LNode := GThreadCache.FHeads[LIndex];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LIndex] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LIndex]);
      Result := Pointer(LNode);
      {$IFDEF DEBUG}FillChar(Result^, ASize, MEM_POISON_ALLOC);{$ENDIF}
      Exit(Result);
    end;
  end;
  { Cache miss: refill from central pool. }
  if LIndex < 0 then
    LIndex := SizeClassIndex(ASize);
  ThreadCacheRefill(GThreadCache, LIndex, @RefillFromCentral);
  LNode := GThreadCache.FHeads[LIndex];
  if LNode <> nil then
  begin
    GThreadCache.FHeads[LIndex] := LNode^.FNext;
    Dec(GThreadCache.FCounts[LIndex]);
    Result := Pointer(LNode);
  end
  else
    { Central exhausted (OOM): fall back to the System heap. Allocate the
      FULL class capacity, not ASize — the block is indistinguishable from
      span slots to the free paths, and BatchFreeMem may push it into the
      TLS cache where it can be handed out for any request of this class. }
    Result := NpSystemGetMem(SizeClasses[LIndex]);
  {$IFDEF DEBUG}
  if Result <> nil then
    FillChar(Result^, ASize, MEM_POISON_ALLOC);
  {$ENDIF}
end;
{$pop}

{$push}{$R-}
procedure TGrowingAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
var
  LIndex: Int32;
  LNode: PFreeNode;
  LOwnerThreadId: QWord;
begin
  if APtr = nil then
    Exit;
  {$IFDEF DEBUG}FillChar(APtr^, ASize, MEM_POISON_FREED);{$ENDIF}
  Inc(GThreadCache.FOpCount);
  { Huge allocation: skip size class lookup. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    NpSystemFreeMem(APtr);
    Exit;
  end;
  { Compute size class index (must match GetMem / SizeClassIndex). }
  LIndex := FastSizeClassIndex(ASize);
  if LIndex < 0 then
  begin
    NpSystemFreeMem(APtr);
    Exit;
  end;
  { Cross-thread free optimization: check if block belongs to another thread.
    If so, return directly to central pool. We avoid pushing to the owner's
    per-thread inbox because the owner thread may be exiting concurrently,
    making its threadvar cache a dangling pointer (use-after-free).
    Central pool free is always safe and correct. }
  LOwnerThreadId := FindSpanOwnerThreadId(FCentrals[LIndex], APtr);
  if LOwnerThreadId = 0 then
  begin
    { Not from any span of this instance: either the OOM fallback block
      GetMem handed out via NpSystemGetMem, or a block of another instance.
      It must NOT enter the TLS cache — on flush, central would silently
      drop it (leak). Route to the owning instance when identifiable,
      else free it back to the System heap. Wrong-heap pointers remain UB
      per ERROR-POLICY. }
    if (GGrowingAllocator <> nil) and (GGrowingAllocator <> Self) and
       (FindSpanOwnerThreadId(GGrowingAllocator.FCentrals[LIndex], APtr) <> 0) then
      GGrowingAllocator.FreeMem(APtr, ASize)
    else
      NpSystemFreeMem(APtr);
    Exit;
  end;
  if LOwnerThreadId <> QWord(PtrUInt(platform_thread_id)) then
  begin
    CentralPoolFree(FCentrals[LIndex], 1, @APtr);
    Exit;
  end;
  { Same-thread free: push to local TLS cache. }
  if GThreadCache.FCounts[LIndex] < CACHE_ADAPTIVE_MAX_SMALL then
  begin
    LNode := PFreeNode(APtr);
    LNode^.FNext := GThreadCache.FHeads[LIndex];
    GThreadCache.FHeads[LIndex] := LNode;
    Inc(GThreadCache.FCounts[LIndex]);
    Exit;
  end;
  { Cache full: flush a batch to central, then push. }
  ThreadCacheFlush(GThreadCache, LIndex, @FlushToCentral);
  LNode := PFreeNode(APtr);
  LNode^.FNext := GThreadCache.FHeads[LIndex];
  GThreadCache.FHeads[LIndex] := LNode;
  Inc(GThreadCache.FCounts[LIndex]);
end;
{$pop}

{$push}{$R-}
function TGrowingAllocator.TryBlockSize(APtr: Pointer; out ASize: SizeUInt): Boolean;
var
  I: Int32;
begin
  Result := False;
  ASize := 0;
  if APtr = nil then
    Exit;
  { Always scan Self's centrals first (this instance may own the block). }
  for I := MEM_SIZECLASS_COUNT - 1 downto 0 do
  begin
    if FCentrals[I].FEntryCount <= 0 then
      Continue;
    if FindSpanOwnerThreadId(FCentrals[I], APtr) <> 0 then
    begin
      ASize := SizeClasses[I];
      Exit(True);
    end;
  end;
  { If Self is not the global instance and global exists, try it too. }
  if (GGrowingAllocator <> nil) and (GGrowingAllocator <> Self) then
  begin
    for I := MEM_SIZECLASS_COUNT - 1 downto 0 do
    begin
      if GGrowingAllocator.FCentrals[I].FEntryCount <= 0 then
        Continue;
      if FindSpanOwnerThreadId(GGrowingAllocator.FCentrals[I], APtr) <> 0 then
      begin
        ASize := SizeClasses[I];
        Exit(True);
      end;
    end;
  end;
end;

procedure TGrowingAllocator.FreeMem(APtr: Pointer);
{**
 * Compat free without caller size (slower than FreeMem(ptr, size)).
 * Prefer FreeMem(APtr, ASize) on hot paths.
 * Lookup order: TLS / span map → if owned, sized free; else NpSystemFreeMem
 * (huge blocks that bypassed size-classes). Wrong-heap pointers remain UB.
 *}
var
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit;
  if TryBlockSize(APtr, LSize) then
    FreeMem(APtr, LSize)
  else
    NpSystemFreeMem(APtr);
end;
{$pop}

function TGrowingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

{$push}{$R-}
function TGrowingAllocator.BatchGetMem(ASize: SizeUInt; ACount: Word;
  ABlocks: PPointer): Word; inline;
var
  LIndex: Int32;
  LNode: PFreeNode;
begin
  Result := 0;
  if (ASize = 0) or (ACount = 0) then
    Exit;
  { Huge: NpSystemGetMem per block. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    while Result < ACount do
    begin
      Inc(GThreadCache.FOpCount);
      ABlocks^ := NpSystemGetMem(ASize);
      if ABlocks^ = nil then
        Break;
      Inc(ABlocks);
      Inc(Result);
    end;
    Exit;
  end;
  { Compute size class index once (must match GetMem / SizeClassIndex). }
  LIndex := FastSizeClassIndex(ASize);
  if LIndex < 0 then
    Exit;
  { Pre-fill cache if empty. }
  if GThreadCache.FHeads[LIndex] = nil then
    ThreadCacheRefill(GThreadCache, LIndex, @RefillFromCentral);
  { Pop from cache, refill on miss. }
  while Result < ACount do
  begin
    LNode := GThreadCache.FHeads[LIndex];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LIndex] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LIndex]);
      ABlocks^ := Pointer(LNode);
      Inc(ABlocks);
      Inc(Result);
      Inc(GThreadCache.FOpCount);
    end
    else
    begin
      ThreadCacheRefill(GThreadCache, LIndex, @RefillFromCentral);
      if GThreadCache.FHeads[LIndex] = nil then
        Break;
    end;
  end;
end;

procedure TGrowingAllocator.BatchFreeMem(ASize: SizeUInt; ACount: Word;
  ABlocks: PPointer); inline;
var
  LIndex: Int32;
  LNode: PFreeNode;
  I: Word;
begin
  if (ACount = 0) or (ABlocks = nil) then
    Exit;
  { Guard: ASize=0 would produce invalid size class index }
  if ASize = 0 then
    Exit;
  { Huge: NpSystemFreeMem per block. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    for I := 0 to ACount - 1 do
    begin
      Inc(GThreadCache.FOpCount);
      if ABlocks^ <> nil then
        NpSystemFreeMem(ABlocks^);
      Inc(ABlocks);
    end;
    Exit;
  end;
  { Compute size class index once (must match GetMem / SizeClassIndex). }
  LIndex := FastSizeClassIndex(ASize);
  if LIndex < 0 then
    Exit;
  { Push all blocks to cache, flush when full. }
  for I := 0 to ACount - 1 do
  begin
    Inc(GThreadCache.FOpCount);
    if ABlocks^ = nil then
    begin
      Inc(ABlocks);
      Continue;
    end;
    if GThreadCache.FCounts[LIndex] >= CACHE_ADAPTIVE_MAX_SMALL then
      ThreadCacheFlush(GThreadCache, LIndex, @FlushToCentral);
    LNode := PFreeNode(ABlocks^);
    LNode^.FNext := GThreadCache.FHeads[LIndex];
    GThreadCache.FHeads[LIndex] := LNode;
    Inc(GThreadCache.FCounts[LIndex]);
    Inc(ABlocks);
  end;
end;

procedure TGrowingAllocator.MixedBatch(ASizes: Pointer; ACount: Integer;
  ABlocks: PPointer); inline;
const
  MAX_MIXED = 8;
type
  TSizeUIntArray = array[0..MAX_MIXED - 1] of SizeUInt;
  PSizeUIntArray = ^TSizeUIntArray;
var
  LSizes: TSizeUIntArray;
  LClasses: array[0..MAX_MIXED - 1] of Int32;
  LBase: PPointer;
  LSizesPtr: PSizeUIntArray;
  LCount, I: Integer;
  LSize: SizeUInt;
  LClass: Int32;
  LNode: PFreeNode;
begin
  FillChar(LSizes, SizeOf(LSizes), 0);
  FillChar(LClasses, SizeOf(LClasses), 0);
  LCount := ACount;
  if LCount > MAX_MIXED then
    LCount := MAX_MIXED;
  LBase := ABlocks;
  LSizesPtr := PSizeUIntArray(ASizes);
  { Pre-compute class indices once (must match GetMem / SizeClassIndex). }
  for I := 0 to LCount - 1 do
  begin
    LSizes[I] := LSizesPtr^[I];
    LSize := LSizes[I];
    if (LSize > 0) and (LSize <= MEM_SIZECLASS_MAX) then
      LClasses[I] := FastSizeClassIndex(LSize)
    else
      LClasses[I] := -1;
  end;
  { Allocate all blocks, store to LBase[0..LCount-1]. }
  for I := 0 to LCount - 1 do
  begin
    if LClasses[I] < 0 then
    begin
      LBase[I] := NpSystemGetMem(LSizes[I]);
      Continue;
    end;
    LClass := LClasses[I];
    LNode := GThreadCache.FHeads[LClass];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LClass] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LClass]);
      LBase[I] := Pointer(LNode);
    end
    else
    begin
      ThreadCacheRefill(GThreadCache, LClass, @RefillFromCentral);
      LNode := GThreadCache.FHeads[LClass];
      if LNode <> nil then
      begin
        GThreadCache.FHeads[LClass] := LNode^.FNext;
        Dec(GThreadCache.FCounts[LClass]);
        LBase[I] := Pointer(LNode);
      end
      else
        LBase[I] := nil;
    end;
  end;
  { Free all blocks. }
  for I := 0 to LCount - 1 do
  begin
    if LBase[I] = nil then
      Continue;
    if LClasses[I] < 0 then
    begin
      NpSystemFreeMem(LBase[I]);
      Continue;
    end;
    LClass := LClasses[I];
    if GThreadCache.FCounts[LClass] >= CACHE_ADAPTIVE_MAX_SMALL then
      ThreadCacheFlush(GThreadCache, LClass, @FlushToCentral);
    LNode := PFreeNode(LBase[I]);
    LNode^.FNext := GThreadCache.FHeads[LClass];
    GThreadCache.FHeads[LClass] := LNode;
    Inc(GThreadCache.FCounts[LClass]);
  end;
end;
{$pop}

function TGrowingAllocator.ReallocMem(APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer;
begin
  if APtr = nil then
    Exit(GetMem(ANewSize));
  if ANewSize = 0 then
  begin
    FreeMem(APtr, AOldSize);
    Exit(nil);
  end;
  { Same size class → zero-copy (most common: Vec/GrowSlice growing within class). }
  if (AOldSize <= MEM_SIZECLASS_MAX) and (ANewSize <= MEM_SIZECLASS_MAX) then
    if FastSizeClassIndex(AOldSize) = FastSizeClassIndex(ANewSize) then
      Exit(APtr);
  { Different class: alloc + copy + free. }
  Result := GetMem(ANewSize);
  if Result <> nil then
  begin
    if ANewSize > AOldSize then
      Move(APtr^, Result^, AOldSize)
    else
      Move(APtr^, Result^, ANewSize);
    FreeMem(APtr, AOldSize);
  end;
end;

function TGrowingAllocator.ReallocMem(APtr: Pointer; ANewSize: SizeUInt): Pointer;
var
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ANewSize));
  if ANewSize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if TryBlockSize(APtr, LOldSize) then
    Result := ReallocMem(APtr, LOldSize, ANewSize)
  else
    { Huge or foreign block: host System path (compiler kernel System). }
    Result := NpSystemReallocMem(APtr, ANewSize);
end;

function TGrowingAllocator.Scavenge: Int32;
var
  I: Int32;
  LOp: UInt64;
begin
  Result := 0;
  { TLS free lists hold slots that still look allocated in central bitmaps.
    Flush this thread's cache so idle spans can become fully free.
    FlushToCentral targets the global singleton (product DefaultHeap path). }
  if Self = GGrowingAllocator then
    ThreadCacheFlushAll(GThreadCache, @FlushToCentral);
  LOp := GThreadCache.FOpCount;
  if LOp = 0 then
    LOp := FOpCounter;
  atomic_exchange_64(FOpCounter, LOp, mo_relaxed);
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
    Inc(Result, ScavengeCentralPools(FCentrals[I], 0));
end;

procedure TGrowingAllocator.GetHeapStats(out AStats: TGrowingHeapStats);
var
  I: Int32;
  LPool: TCentralPoolStats;
begin
  FillChar(AStats, SizeOf(AStats), 0);
  AStats.OpCounter := FOpCounter;
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    CentralPoolGetStats(FCentrals[I], LPool);
    Inc(AStats.LiveSpans, LPool.LiveSpans);
    Inc(AStats.IdleSpans, LPool.IdleSpans);
    Inc(AStats.DecommittedSpans, LPool.DecommittedSpans);
    Inc(AStats.FreeSlots, LPool.FreeSlots);
    Inc(AStats.LiveBytes, LPool.LiveBytes);
    Inc(AStats.ReleasedSpans, LPool.ReleasedSpans);
    Inc(AStats.ReleasedBytes, LPool.ReleasedBytes);
    Inc(AStats.DecommitEvents, LPool.DecommitEvents);
    Inc(AStats.DecommittedBytes, LPool.DecommittedBytes);
  end;
end;

function DefaultGrowingAllocator: TGrowingAllocator;
begin
  Result := GGrowingAllocator;
end;

procedure ResetDefaultGrowingAllocator;
begin
  FreeAndNil(GGrowingAllocator);
end;

initialization
  ValidateFastSizeClassIndex;
{$IFDEF NEXTPAS_UNIX}
  GCacheCleanupKeyCreated :=
    platform_tls_create_with_destructor(GCacheCleanupKey, @ThreadExitFlush) = 0;
{$ELSE}
{$IFDEF NEXTPAS_WINDOWS}
  GCacheCleanupKeyCreated :=
    platform_tls_create_with_destructor(GCacheCleanupKey, @ThreadExitFlsCallback) = 0;
{$ELSE}
  GCacheCleanupKeyCreated :=
    platform_tls_create_with_destructor(GCacheCleanupKey, nil) = 0;
{$ENDIF}
{$ENDIF}
  GGrowingAllocator := TGrowingAllocator.Create;

finalization
  FreeAndNil(GGrowingAllocator);
  if GCacheCleanupKeyCreated then
    platform_tls_destroy_dtor(GCacheCleanupKey);

end.
