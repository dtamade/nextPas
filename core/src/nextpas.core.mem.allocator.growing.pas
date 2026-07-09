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
  {** Unified growing allocator.
      Routes allocations through:
        small (≤ MEM_SIZECLASS_MAX) → TLS cache → central pool → new span
        large (> MEM_SIZECLASS_MAX) → direct GetMem

      Architecture (matches Go mcache/mcentral/mheap pattern):
        Layer 1: TThreadCache (threadvar, zero contention, ~5ns)
        Layer 2: TCentralPool (spinlock, batch refill/flush)
        Layer 3: System.GetMem (large allocations only)

      Thread-safe: TLS cache absorbs most traffic; central pool uses spinlock. }
  TGrowingAllocator = class
  private
    FCentrals: array[0..MEM_SIZECLASS_COUNT - 1] of TCentralPool;
    FOpCounter: UInt64;  { Monotonic op counter for scavenger idle tracking. }
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
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt); inline;

    {** Free a block previously allocated by GetMem.
        Size class is determined by scanning central pool spans.
        Slower than the two-parameter version — use when size is unknown. }
    procedure FreeMem(APtr: Pointer);

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

    {** Force a scavenge pass across all central pools.
        Releases long-idle fully-free spans to OS. }
    procedure Scavenge;

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
  nextpas.core.mem.error;

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
begin
  while AtomicCmpExchange(GThreadRegistryLock, 1, 0) <> 0 do
    ThreadSwitch;
end;

procedure RegistryUnlock;
begin
  AtomicExchange(GThreadRegistryLock, 0);
end;

{ Register current thread's TLS cache in global registry. }
procedure RegisterThreadCache;
var
  LSlot: SizeUInt;
  LThreadId: QWord;
begin
  LThreadId := GetCurrentThreadId;
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
  LThreadId := GetCurrentThreadId;
  LSlot := SizeUInt(LThreadId) and (MAX_THREAD_SLOTS - 1);
  RegistryLock;
  try
    if (GThreadRegistry[LSlot].FThreadId = LThreadId) and
       GThreadRegistry[LSlot].FActive then
    begin
      { Clear cache pointer first, then mark inactive. }
      AtomicStorePtr(GThreadRegistry[LSlot].FCache, nil, moRelease);
      GThreadRegistry[LSlot].FActive := False;
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
  Result := AtomicLoadPtr(GThreadRegistry[LSlot].FCache);
  if (Result <> nil) and (not GThreadRegistry[LSlot].FActive) then
    Result := nil;
end;

{ --- Thread-exit cleanup ---
  UNIX: pthread TLS key destructor. Windows: FlsCallback.
  When a thread exits, the callback flushes all cached blocks
  back to the central pool to prevent leakage. }

type
  TThreadExitProc = procedure(AData: Pointer); cdecl;

{$IFDEF UNIX}
var
  GCacheCleanupKey: QWord;  { pthread_key_t = unsigned long on Linux x86-64 }

function pthread_key_create(var AKey: QWord;
  ADestructor: TThreadExitProc): Integer; cdecl; external 'c' name 'pthread_key_create';
function pthread_key_delete(AKey: QWord): Integer; cdecl; external 'c' name 'pthread_key_delete';
function pthread_setspecific(AKey: QWord; AValue: Pointer): Integer; cdecl; external 'c' name 'pthread_setspecific';
{$ENDIF}

{$IFDEF MSWINDOWS}
type
  TFlsCallback = procedure(lpFlsData: Pointer); stdcall;
var
  GCacheCleanupIndex: DWORD;

function FlsAlloc(lpCallback: TFlsCallback): DWORD; stdcall; external 'kernel32.dll' name 'FlsAlloc';
function FlsFree(dwFlsIndex: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'FlsFree';
function FlsSetValue(dwFlsIndex: DWORD; lpFlsData: Pointer): BOOL; stdcall; external 'kernel32.dll' name 'FlsSetValue';
{$ENDIF}

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

{$IFDEF MSWINDOWS}
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
        'FastSizeClassIndex formula mismatch: sizeclass table inconsistency detected');
end;

{ Refill/Flush callbacks (standalone functions for TRefillProc/TFlushProc) --- }

function RefillFromCentral(AIndex: Int32; ACount: Word;
  ABlocks: PPointer): Word;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit(0);
  if GGrowingAllocator = nil then
    Exit(0);
  Result := CentralPoolAlloc(GGrowingAllocator.FCentrals[AIndex], ACount, ABlocks,
    GThreadCache.FOpCount);
end;

procedure FlushToCentral(AIndex: Int32; ACount: Word;
  ABlocks: PPointer);
var
  I: Word;
  LOldHead: Pointer;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit;
  if GGrowingAllocator = nil then
    Exit;
  if ACount = 0 then
    Exit;
  { Chain all blocks into a linked list, then CAS entire chain into inbox
    (single atomic swap instead of N individual CAS pushes). }
  for I := 0 to ACount - 2 do
    PFreeNode(ABlocks[I])^.FNext := PFreeNode(ABlocks[I + 1]);
  PFreeNode(ABlocks[ACount - 1])^.FNext := nil;
  repeat
    LOldHead := GGrowingAllocator.FCentrals[AIndex].FInboxHead;
    PFreeNode(ABlocks[ACount - 1])^.FNext := PFreeNode(LOldHead);
  until AtomicCmpExchange(GGrowingAllocator.FCentrals[AIndex].FInboxHead,
    ABlocks[0], LOldHead) = LOldHead;
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
    {$IFDEF UNIX}
    pthread_setspecific(GCacheCleanupKey, @GThreadCache);
    {$ENDIF}
    {$IFDEF MSWINDOWS}
    FlsSetValue(GCacheCleanupIndex, @GThreadCache);
    {$ENDIF}
  end;
  { Periodic scavenge: uses thread-local counter in GThreadCache. }
  if (GThreadCache.FOpCount and (SCAVENGER_CHECK_INTERVAL - 1)) = 0 then
  begin
    AtomicExchange(FOpCounter, GThreadCache.FOpCount);
    for LIndex := 0 to MEM_SIZECLASS_COUNT - 1 do
      ScavengeCentralPools(FCentrals[LIndex], GThreadCache.FOpCount,
        SCAVENGER_IDLE_THRESHOLD);
  end;
  { Huge allocation: skip size class lookup, direct System.GetMem. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    System.GetMem(Result, ASize);
    Exit;
  end;
  { Fast path for common small sizes: skip SizeClassIndex lookup. }
  if ASize <= 256 then
  begin
    LIndex := Int32((ASize + 15) shr 4) - 1;
    LNode := GThreadCache.FHeads[LIndex];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LIndex] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LIndex]);
      Result := Pointer(LNode);
      {$IFDEF DEBUG}FillChar(Result^, ASize, MEM_POISON_ALLOC);{$ENDIF}
      Exit(Result);
    end;
  end
  else if ASize <= 1024 then
  begin
    { Fast formula for band 1 (256-1024, 64B step): (size shr 6) + 14 }
    LIndex := Int32(ASize shr 6) + 14;
    LNode := GThreadCache.FHeads[LIndex];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LIndex] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LIndex]);
      Result := Pointer(LNode);
      {$IFDEF DEBUG}FillChar(Result^, ASize, MEM_POISON_ALLOC);{$ENDIF}
      Exit(Result);
    end;
  end
  else
  begin
    LIndex := SizeClassIndex(ASize);
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
    System.GetMem(Result, ASize);
  {$IFDEF DEBUG}
  if Result <> nil then
    FillChar(Result^, ASize, MEM_POISON_ALLOC);
  {$ENDIF}
end;
{$pop}

{$push}{$R-}
procedure TGrowingAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt); inline;
var
  LIndex: Int32;
  LNode: PFreeNode;
  LOwnerThreadId: QWord;
  LOwnerCache: Pointer;
begin
  if APtr = nil then
    Exit;
  {$IFDEF DEBUG}FillChar(APtr^, ASize, MEM_POISON_FREED);{$ENDIF}
  Inc(GThreadCache.FOpCount);
  { Huge allocation: skip size class lookup. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    System.FreeMem(APtr);
    Exit;
  end;
  { Compute size class index. }
  if ASize <= 256 then
    LIndex := Int32((ASize + 15) shr 4) - 1
  else if ASize <= 1024 then
    LIndex := Int32(ASize shr 6) + 14
  else
    LIndex := SizeClassIndex(ASize);
  if LIndex < 0 then
  begin
    System.FreeMem(APtr);
    Exit;
  end;
  { Cross-thread free optimization: check if block belongs to another thread.
    If so, push directly to owner's per-thread inbox (lock-free).
    If owner thread has exited (cache not found), fall through to central pool. }
  LOwnerThreadId := FindSpanOwnerThreadId(FCentrals[LIndex], APtr);
  if (LOwnerThreadId <> 0) and (LOwnerThreadId <> GetCurrentThreadId) then
  begin
    LOwnerCache := FindThreadCache(LOwnerThreadId);
    if LOwnerCache <> nil then
    begin
      ThreadCacheInboxPush(PThreadCache(LOwnerCache)^, LIndex, APtr);
      Exit;
    end;
    { Owner thread exited — return directly to central pool. }
    CentralPoolFree(FCentrals[LIndex], 1, @APtr, GThreadCache.FOpCount);
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
procedure TGrowingAllocator.FreeMem(APtr: Pointer);
var
  I: Int32;
begin
  if APtr = nil then
    Exit;
  { Always scan Self's centrals first (this instance may own the block). }
  for I := MEM_SIZECLASS_COUNT - 1 downto 0 do
  begin
    if FCentrals[I].FEntryCount <= 0 then
      Continue;
    if FindSpanOwnerThreadId(FCentrals[I], APtr) <> 0 then
    begin
      FreeMem(APtr, SizeClasses[I]);
      Exit;
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
        GGrowingAllocator.FreeMem(APtr, SizeClasses[I]);
        Exit;
      end;
    end;
  end;
  System.FreeMem(APtr);
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
  { Huge: System.GetMem per block. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    while Result < ACount do
    begin
      Inc(GThreadCache.FOpCount);
      System.GetMem(ABlocks^, ASize);
      if ABlocks^ = nil then
        Break;
      Inc(ABlocks);
      Inc(Result);
    end;
    Exit;
  end;
  { Compute size class index once. }
  if ASize <= 256 then
    LIndex := Int32((ASize + 15) shr 4) - 1
  else if ASize <= 1024 then
    LIndex := Int32(ASize shr 6) + 14
  else
    LIndex := SizeClassIndex(ASize);
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
  { Huge: System.FreeMem per block. }
  if ASize > MEM_SIZECLASS_MAX then
  begin
    for I := 0 to ACount - 1 do
    begin
      Inc(GThreadCache.FOpCount);
      if ABlocks^ <> nil then
        System.FreeMem(ABlocks^);
      Inc(ABlocks);
    end;
    Exit;
  end;
  { Compute size class index once. }
  if ASize <= 256 then
    LIndex := Int32((ASize + 15) shr 4) - 1
  else if ASize <= 1024 then
    LIndex := Int32(ASize shr 6) + 14
  else
    LIndex := SizeClassIndex(ASize);
  { Push all blocks to cache, flush when full. }
  for I := 0 to ACount - 1 do
  begin
    Inc(GThreadCache.FOpCount);
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
  LCount := ACount;
  if LCount > MAX_MIXED then
    LCount := MAX_MIXED;
  LBase := ABlocks;
  LSizesPtr := PSizeUIntArray(ASizes);
  { Pre-compute class indices once. }
  for I := 0 to LCount - 1 do
  begin
    LSizes[I] := LSizesPtr^[I];
    LSize := LSizes[I];
    if LSize <= MEM_SIZECLASS_MAX then
    begin
      if LSize <= 256 then
        LClasses[I] := Int32((LSize + 15) shr 4) - 1
      else if LSize <= 1024 then
        LClasses[I] := Int32(LSize shr 6) + 14
      else
        LClasses[I] := SizeClassIndex(LSize);
    end
    else
      LClasses[I] := -1;
  end;
  { Allocate all blocks, store to LBase[0..LCount-1]. }
  for I := 0 to LCount - 1 do
  begin
    if LClasses[I] < 0 then
    begin
      System.GetMem(LBase[I], LSizes[I]);
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
      System.FreeMem(LBase[I]);
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

procedure TGrowingAllocator.Scavenge;
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
    ScavengeCentralPools(FCentrals[I], FOpCounter, 0);
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
  {$IFDEF UNIX}pthread_key_create(GCacheCleanupKey, @ThreadExitFlush);{$ENDIF}
  {$IFDEF MSWINDOWS}GCacheCleanupIndex := FlsAlloc(@ThreadExitFlsCallback);{$ENDIF}
  GGrowingAllocator := TGrowingAllocator.Create;

finalization
  FreeAndNil(GGrowingAllocator);
  {$IFDEF UNIX}pthread_key_delete(GCacheCleanupKey);{$ENDIF}
  {$IFDEF MSWINDOWS}FlsFree(GCacheCleanupIndex);{$ENDIF}

end.
