unit nextpas.core.mem.central;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.span,
  nextpas.core.platform.memory,
  nextpas.core.platform.thread;

const
  { Default number of slots per span. }
  CENTRAL_SPAN_SLOTS = 64;

  { Scavenger ages are measured in CENTRAL ticks (FTick): one tick per
    locked central operation (batch refill / batch flush / inbox drain).
    With a TLS batch of 64 user ops per central op, 16K ticks ≈ 1M user
    ops. Ticks are pool-local and monotonic under the spinlock — never
    compare against per-thread op counters (threadvars from different
    threads made ages meaningless and could underflow). }

  { Scavenger: soft purge — return physical pages, keep virtual reservation.
    Must be < SCAVENGER_IDLE_THRESHOLD so decommit can fire before hard release. }
  SCAVENGER_DECOMMIT_THRESHOLD = 2048;

  { Scavenger: hard release — free backing store after longer idle. }
  SCAVENGER_IDLE_THRESHOLD = 16384;

  { Scavenger: how often (in ops) to run a scavenge check.
    Must be power of 2 for cheap masking. }
  SCAVENGER_CHECK_INTERVAL = 1024;

  { Scavenger: max spans hard-released per scavenge pass (bounds hold time). }
  SCAVENGER_MAX_RELEASE = 16;

type
  {** Entry in the central span pool: a span + its memory region.
      Lock-free reader invariants (FindSpanOwnerThreadId reads entries
      without the spinlock):
      - an index valid in one array generation stays valid in every later
        one (arrays only grow; superseded generations are retired, not
        freed)
      - FMemory is the slot's validity gate for lock-free readers: it is
        written ONLY with atomic_store (nil on hard release, new base with
        release ordering on revival) and read with atomic_load(acquire).
        A reader that observes a non-nil base is guaranteed to see the
        matching FMemorySize / FOwnerThreadId written before it.
      - dead slots (FMemory = nil) are recycled by AddSpan (revival). This
        is safe for stale readers because a hard release requires the span
        to be empty: no live block points into the old region, so a legal
        caller can never probe a pointer that would match the slot's old
        identity. A caller probing a block from the REVIVED span must have
        received that block through a synchronizing handoff, which carries
        the revival writes with it (happens-before), so it cannot observe
        the slot's dead state. }
  PCentralSpanEntry = ^TCentralSpanEntry;
  TCentralSpanEntry = record
    FSpan: TSpan;
    FMemory: Pointer;     { Allocated memory backing the span. }
    FMemorySize: SizeUInt;
    FLastFreeTick: UInt64; { Pool-local tick when span became fully free (0 = not idle). }
    FOwnerThreadId: QWord; { Thread that allocated this span (for cross-thread free). }
    FDecommitted: Boolean; { True if physical pages returned to OS (virtual reservation kept). }
  end;

  TCentralSpanEntryArray = array of TCentralSpanEntry;

  {** Snapshot of one central pool (live + lifetime counters). }
  TCentralPoolStats = record
    EntryCount: Int32;
    LiveSpans: Int32;           { FMemory <> nil }
    IdleSpans: Int32;           { fully free with FLastFreeTick <> 0 }
    DecommittedSpans: Int32;    { live but physical pages returned }
    FreeSlots: SizeUInt;
    LiveBytes: SizeUInt;        { sum of FMemorySize for live spans (virtual) }
    ReleasedSpans: UInt64;      { lifetime hard releases }
    ReleasedBytes: UInt64;
    DecommitEvents: UInt64;     { lifetime soft purges }
    DecommittedBytes: UInt64;   { bytes soft-purged (may re-count if recommitted) }
  end;

  {** Central span pool for one size class. Manages partial and full spans.
      Provides batch alloc/free for the thread cache refill/flush path.
      Thread-safe via spinlock (low contention: TLS cache absorbs most traffic).
      Lock-free inbox: cross-thread frees push via CAS, alloc drains under lock.
      Page-indexed lookup: O(1) FindSpanIndex via span base address comparison. }
  TCentralPool = record
    FEntries: TCentralSpanEntryArray;
    { Raw shadow of FEntries for LOCK-FREE readers. FEntries itself must
      never be read without the spinlock: FPC's SetLength copy-on-write
      writes nil into the field between copying and publishing the new
      array (fpc_dynarray_clear in dynarr.inc), so a lock-free reader can
      observe a transient nil. This shadow is RTL-untouched and published
      with release ordering in AddSpan after the grown array is ready. }
    FEntriesBase: Pointer;
    { Superseded FEntries generations, kept alive for lock-free readers
      (see AddSpan). Total size is bounded by one current array. }
    FRetired: array of TCentralSpanEntryArray;
    FEntryCount: Int32;
    FPartialHead: Int32;    { Index of first partial entry (-1 = none). }
    FPartialNext: array of Int32; { Intrusive linked list via indices. }
    { Dead-slot chain head (-1 = none): slots whose span was hard-released.
      Reuses FPartialNext as the link field (a dead slot is never on the
      partial list). AddSpan pops from here before growing, so FEntryCount
      stays bounded by peak concurrency instead of growing forever across
      peak-idle cycles. }
    FDeadHead: Int32;
    FSlotSize: SizeUInt;
    FSpinLock: SizeUInt;    { CentralPoolLock/CentralPoolUnlock. }
    { Pool-local logical clock: incremented under the spinlock on every
      central operation (alloc / free / inbox drain). Idle ages compare
      only against this clock — per-thread op counters are NOT comparable
      across threads (subtracting them underflows into huge fake ages). }
    FTick: UInt64;
    FInboxHead: Pointer;    { Lock-free inbox: CAS singly linked list. }
    FLastHitIndex: Int32;   { MRU cache: last span found by FindSpanIndex (-1 = none). }
    { Lifetime scavenger counters (monotonic; not reset by scavenge). }
    FReleasedSpans: UInt64;
    FReleasedBytes: UInt64;
    FDecommitEvents: UInt64;
    FDecommittedBytes: UInt64;
  end;

{** Initialize a central pool for a given slot size. }
procedure CentralPoolInit(out APool: TCentralPool; ASlotSize: SizeUInt);

{** Release all spans and free backing memory. }
procedure CentralPoolDestroy(var APool: TCentralPool);

{** Batch allocate: fill ABlocks[] with ACount pointers to free slots.
    Returns actual count allocated (may be < ACount if pool exhausted).
    Advances the pool-local tick (idle tracking). Thread-safe. }
function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer): Word;

{** Batch free: return ABlocks[] to their respective spans.
    Fully free spans are stamped with the pool-local tick for scavenging.
    Thread-safe. }
procedure CentralPoolFree(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer);

{** Return total free slots across all non-released spans. }
function CentralPoolFreeCount(var APool: TCentralPool): SizeUInt;

{** Snapshot live + lifetime scavenger counters. Thread-safe. }
procedure CentralPoolGetStats(var APool: TCentralPool;
  out AStats: TCentralPoolStats);

{** Scan fully-free spans (ages measured in pool-local ticks, see FTick):
    - age >= AIdleThreshold → hard FreeMem (counts as Released*)
    - else age >= SCAVENGER_DECOMMIT_THRESHOLD → soft decommit (Decommit*)
    Returns number of spans hard-released this pass. Thread-safe. }
function ScavengeCentralPools(var APool: TCentralPool;
  AIdleThreshold: UInt64): Int32;

{** Push a freed block to the lock-free inbox (CAS, no spinlock).
    Safe to call from any thread without locking.
    Inbox is drained on the next CentralPoolAlloc call. }
procedure CentralPoolInboxPush(var APool: TCentralPool; APtr: Pointer);

{** Find the owner thread ID for a given pointer.
    Returns the thread ID that allocated the span containing APtr.
    Returns 0 if APtr is not found in any span.
    Uses MRU cache for O(1) common case. }
function FindSpanOwnerThreadId(var APool: TCentralPool; APtr: Pointer): QWord;

{** Find the span entry index for a given pointer.
    Returns the index into FEntries, or -1 if not found.
    Uses MRU cache for O(1) common case. }
function FindSpanIndex(var APool: TCentralPool; APtr: Pointer): Int32;

implementation

uses
  nextpas.core.atomic;

const
  INITIAL_CAPACITY = 4;

type
  { Intrusive free-list node for inbox. Same layout as TFreeNode/ShuffleNode. }
  PInboxNode = ^TInboxNode;
  TInboxNode = record
    FNext: PInboxNode;
  end;

procedure CentralPoolLock(var ALock: SizeUInt);
var
  LBackoff: SizeUInt;
  LExpected: SizeUInt;
begin
  LBackoff := 1;
  LExpected := 0;
  while not atomic_compare_exchange_strong(ALock, LExpected, 1, mo_acquire, mo_relaxed) do
  begin
    LExpected := 0;
    ThreadSwitch;
    if LBackoff < 64 then
      LBackoff := LBackoff shl 1;
  end;
end;

procedure CentralPoolUnlock(var ALock: SizeUInt);
begin
  atomic_exchange(ALock, 0, mo_release);
end;

procedure CentralPoolInit(out APool: TCentralPool; ASlotSize: SizeUInt);
begin
  APool.FSlotSize := ASlotSize;
  APool.FEntryCount := 0;
  APool.FPartialHead := -1;
  APool.FDeadHead := -1;
  APool.FSpinLock := 0;
  APool.FTick := 0;
  APool.FInboxHead := nil;
  APool.FLastHitIndex := -1;
  APool.FReleasedSpans := 0;
  APool.FReleasedBytes := 0;
  APool.FDecommitEvents := 0;
  APool.FDecommittedBytes := 0;
  SetLength(APool.FEntries, INITIAL_CAPACITY);
  SetLength(APool.FPartialNext, INITIAL_CAPACITY);
  APool.FEntriesBase := Pointer(APool.FEntries);
end;

procedure CentralPoolDestroy(var APool: TCentralPool);
var
  I: Int32;
begin
  for I := 0 to APool.FEntryCount - 1 do
    if APool.FEntries[I].FMemory <> nil then
      platform_virtual_release(APool.FEntries[I].FMemory,
        APool.FEntries[I].FMemorySize);
  APool.FEntryCount := 0;
  APool.FPartialHead := -1;
  APool.FDeadHead := -1;
  APool.FInboxHead := nil;
  APool.FEntriesBase := nil;
  SetLength(APool.FEntries, 0);
  SetLength(APool.FRetired, 0);
  SetLength(APool.FPartialNext, 0);
end;

procedure CentralPoolInboxPush(var APool: TCentralPool; APtr: Pointer);
var
  LExpected: Pointer;
begin
  { CAS push: lock-free, safe from any thread. }
  LExpected := APool.FInboxHead;
  while True do
  begin
    PInboxNode(APtr)^.FNext := PInboxNode(LExpected);
    if atomic_compare_exchange_strong(APool.FInboxHead, LExpected, APtr, mo_acq_rel, mo_acquire) then
      Exit;
  end;
end;

{** Add a new span to the pool (caller holds lock). }
function AddSpan(var APool: TCentralPool): Int32;
var
  LIdx: Int32;
  LMemSize: SizeUInt;
  LMem: Pointer;
  LRetired: Int32;
begin
  Result := -1;
  { Span backing comes from the virtual-memory backend, not the process
    heap: the scavenger decommits/recommits spans, which requires the
    page-aligned private mappings mmap/VirtualAlloc provide (heap pointers
    are unaligned, so decommit would either fail or scribble neighbours).
    Anonymous committed pages are zero-filled — no FillChar needed. }
  LMemSize := SizeUInt(CENTRAL_SPAN_SLOTS) * APool.FSlotSize;
  LMem := platform_virtual_reserve(LMemSize);
  if LMem <> nil then
    if not platform_virtual_commit(LMem, LMemSize) then
    begin
      platform_virtual_release(LMem, LMemSize);
      LMem := nil;
    end;
  if LMem = nil then
    Exit; { OOM: caller treats a negative index as allocation failure }
  { Revive a dead slot before growing: keeps FEntryCount bounded across
    peak-idle cycles. Write every field FIRST, then release-store FMemory
    as the validity gate — a lock-free reader that observes the new base
    is guaranteed to see the fields written before it. A reader still
    seeing nil treats the slot as dead, which is also correct: no block
    of the revived span can be legally probed before its alloc result is
    handed over through a synchronizing edge that carries these writes. }
  if APool.FDeadHead >= 0 then
  begin
    LIdx := APool.FDeadHead;
    APool.FDeadHead := APool.FPartialNext[LIdx];
    SpanInit(APool.FEntries[LIdx].FSpan, LMem, APool.FSlotSize, CENTRAL_SPAN_SLOTS);
    APool.FEntries[LIdx].FMemorySize := LMemSize;
    APool.FEntries[LIdx].FLastFreeTick := 0;
    APool.FEntries[LIdx].FOwnerThreadId := QWord(platform_thread_id);
    APool.FEntries[LIdx].FDecommitted := False;
    atomic_store(APool.FEntries[LIdx].FMemory, LMem, mo_release);
    APool.FPartialNext[LIdx] := APool.FPartialHead;
    APool.FPartialHead := LIdx;
    Exit(LIdx);
  end;
  { Grow arrays if needed. }
  if APool.FEntryCount >= Length(APool.FEntries) then
  begin
    { Retire the current generation before growing: FindSpanOwnerThreadId
      scans FEntries WITHOUT the spinlock, so the old array must never be
      freed under a concurrent reader. Holding a second reference forces
      SetLength into copy-on-write — the reader keeps a valid (possibly
      stale) generation, which is safe because entry slots are append-only
      and the fields the reader uses are write-once while live (see
      TCentralSpanEntry). Generations sum to < one current array and are
      freed in CentralPoolDestroy. }
    LRetired := Length(APool.FRetired);
    SetLength(APool.FRetired, LRetired + 1);
    APool.FRetired[LRetired] := APool.FEntries;
    SetLength(APool.FEntries, Length(APool.FEntries) * 2);
    SetLength(APool.FPartialNext, Length(APool.FPartialNext) * 2);
    { Publish the grown array via the raw shadow pointer. SetLength above
      briefly wrote nil into FEntries (FPC COW clears the field before
      assigning the new block), which is exactly why lock-free readers must
      go through FEntriesBase, never FEntries. Release pairs with the
      acquire load in FindSpanOwnerThreadId. }
    atomic_store(APool.FEntriesBase, Pointer(APool.FEntries), mo_release);
  end;
  LIdx := APool.FEntryCount;
  { Initialize the entry BEFORE publishing the new count: lock-free readers
    must never observe a published slot with half-written fields. }
  SpanInit(APool.FEntries[LIdx].FSpan, LMem, APool.FSlotSize, CENTRAL_SPAN_SLOTS);
  APool.FEntries[LIdx].FMemorySize := LMemSize;
  APool.FEntries[LIdx].FLastFreeTick := 0;
  { Portable thread id (not Windows GetCurrentThreadId). }
  APool.FEntries[LIdx].FOwnerThreadId := QWord(platform_thread_id);
  APool.FEntries[LIdx].FDecommitted := False;
  { FMemory last, release-ordered: same "validity gate" shape as the
    revival path, so a non-nil base implies ready fields on BOTH paths
    (this slot is additionally guarded by the FEntryCount release below). }
  atomic_store(APool.FEntries[LIdx].FMemory, LMem, mo_release);
  { Add to partial list. }
  APool.FPartialNext[LIdx] := APool.FPartialHead;
  APool.FPartialHead := LIdx;
  { Release-publish: pairs with the acquire load in FindSpanOwnerThreadId.
    A reader that observes the new count is guaranteed to see the entry
    fields above and an array base with capacity >= count. }
  atomic_store(APool.FEntryCount, LIdx + 1, mo_release);
  Result := LIdx;
end;

{** Grab entire inbox chain via CAS (lock-free, O(1)).
    Returns the head of the grabbed chain, or nil if inbox was empty.
    Safe to call from any thread without locking. }
function GrabInboxChain(var APool: TCentralPool): PInboxNode; forward;

{** Process a grabbed inbox chain: return blocks to their spans.
    Caller must hold spinlock. Returns number of blocks processed. }
function ProcessInboxChain(var APool: TCentralPool;
  AChain: PInboxNode): Word; forward;

function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer): Word;
var
  LCount: Word;
  LIdx: Int32;
  LPtr: Pointer;
  LInboxChain: PInboxNode;
begin
  LCount := 0;
  { Phase 1: Lock-free grab of entire inbox chain (O(1) CAS).
    This reduces spinlock hold time by moving the CAS outside the lock. }
  LInboxChain := GrabInboxChain(APool);
  CentralPoolLock(APool.FSpinLock);
  try
    Inc(APool.FTick);
    { Phase 2: Process grabbed chain under spinlock.
      FindSpanIndex + SpanFree need spinlock protection. }
    if LInboxChain <> nil then
      ProcessInboxChain(APool, LInboxChain);
    while LCount < ACount do
    begin
      { Find a partial span. }
      if APool.FPartialHead < 0 then
      begin
        { No partial spans: allocate a new one. }
        if AddSpan(APool) < 0 then
          Break;
      end;
      LIdx := APool.FPartialHead;
      { Clear idle timestamp (span is being reused). }
      APool.FEntries[LIdx].FLastFreeTick := 0;
      { Recommit memory if it was decommitted to OS. }
      if APool.FEntries[LIdx].FDecommitted then
      begin
        if not platform_virtual_commit(APool.FEntries[LIdx].FMemory,
          APool.FEntries[LIdx].FMemorySize) then
          Break; { commit failed (OOM): stop refilling, caller falls back }
        APool.FEntries[LIdx].FDecommitted := False;
      end;
      { Alloc from this span. }
      LPtr := SpanAlloc(APool.FEntries[LIdx].FSpan);
      if LPtr = nil then
      begin
        { Span is full: remove from partial list. }
        APool.FPartialHead := APool.FPartialNext[LIdx];
        Continue;
      end;
      ABlocks^ := LPtr;
      Inc(ABlocks);
      Inc(LCount);
      { If span is now full, remove from partial list. }
      if not SpanHasFree(APool.FEntries[LIdx].FSpan) then
        APool.FPartialHead := APool.FPartialNext[LIdx];
    end;
  finally
    CentralPoolUnlock(APool.FSpinLock);
  end;
  Result := LCount;
end;

{** Find which span owns APtr (by checking address range).
    Uses MRU cache (FLastHitIndex) for O(1) in the common case
    where consecutive frees go to the same span.
    Optimized: check MRU first, then scan from most recent spans. }
function FindSpanIndex(var APool: TCentralPool; APtr: Pointer): Int32;
var
  I: Int32;
  LBase: PByte;
  LSize: SizeUInt;
begin
  { Check MRU cache first — most frees return to the same span. }
  I := APool.FLastHitIndex;
  if (I >= 0) and (I < APool.FEntryCount) and (APool.FEntries[I].FMemory <> nil) then
  begin
    LBase := PByte(APool.FEntries[I].FMemory);
    LSize := APool.FEntries[I].FMemorySize;
    if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
      Exit(I);
  end;
  { Scan in reverse order (most recently allocated spans first). }
  for I := APool.FEntryCount - 1 downto 0 do
  begin
    if APool.FEntries[I].FMemory = nil then
      Continue;
    LBase := PByte(APool.FEntries[I].FMemory);
    LSize := APool.FEntries[I].FMemorySize;
    if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
    begin
      APool.FLastHitIndex := I;
      Exit(I);
    end;
  end;
  Result := -1;
end;

{** Grab entire inbox chain via CAS (lock-free, O(1)).
    Returns the head of the grabbed chain, or nil if inbox was empty.
    Safe to call from any thread without locking. }
function GrabInboxChain(var APool: TCentralPool): PInboxNode;
begin
  Result := PInboxNode(atomic_exchange(APool.FInboxHead, nil, mo_acq_rel));
end;

{** Process a grabbed inbox chain: return blocks to their spans.
    Caller must hold spinlock. Returns number of blocks processed. }
function ProcessInboxChain(var APool: TCentralPool;
  AChain: PInboxNode): Word;
var
  LHead, LNext: PInboxNode;
  LIdx: Int32;
  LWasFull: Boolean;
begin
  Result := 0;
  LHead := AChain;
  while LHead <> nil do
  begin
    LNext := LHead^.FNext;
    LIdx := FindSpanIndex(APool, Pointer(LHead));
    if LIdx >= 0 then
    begin
      LWasFull := not SpanHasFree(APool.FEntries[LIdx].FSpan);
      if SpanFree(APool.FEntries[LIdx].FSpan, Pointer(LHead)) then
      begin
        if SpanIsEmpty(APool.FEntries[LIdx].FSpan) then
          APool.FEntries[LIdx].FLastFreeTick := APool.FTick;
        if LWasFull and SpanHasFree(APool.FEntries[LIdx].FSpan) then
        begin
          APool.FPartialNext[LIdx] := APool.FPartialHead;
          APool.FPartialHead := LIdx;
        end;
      end;
    end;
    Inc(Result);
    LHead := LNext;
  end;
end;

procedure CentralPoolFree(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer);
var
  I: Word;
  LIdx: Int32;
  LWasFull: Boolean;
begin
  { Guard: with I: Word, "ACount - 1" underflows to 65535 when ACount = 0. }
  if ACount = 0 then
    Exit;
  CentralPoolLock(APool.FSpinLock);
  try
    Inc(APool.FTick);
    for I := 0 to ACount - 1 do
    begin
      LIdx := FindSpanIndex(APool, ABlocks^);
      if LIdx < 0 then
      begin
        Inc(ABlocks);
        Continue;
      end;
      LWasFull := not SpanHasFree(APool.FEntries[LIdx].FSpan);
      if SpanFree(APool.FEntries[LIdx].FSpan, ABlocks^) then
      begin
        { If span became completely empty, mark it as idle for scavenging. }
        if SpanIsEmpty(APool.FEntries[LIdx].FSpan) then
          APool.FEntries[LIdx].FLastFreeTick := APool.FTick;
        { If span was full and now has space, re-add to partial list. }
        if LWasFull and SpanHasFree(APool.FEntries[LIdx].FSpan) then
        begin
          APool.FPartialNext[LIdx] := APool.FPartialHead;
          APool.FPartialHead := LIdx;
        end;
      end;
      Inc(ABlocks);
    end;
  finally
    CentralPoolUnlock(APool.FSpinLock);
  end;
end;

function CentralPoolFreeCount(var APool: TCentralPool): SizeUInt;
var
  I: Int32;
begin
  Result := 0;
  CentralPoolLock(APool.FSpinLock);
  try
    for I := 0 to APool.FEntryCount - 1 do
      if APool.FEntries[I].FMemory <> nil then
        Inc(Result, SpanFreeCount(APool.FEntries[I].FSpan));
  finally
    CentralPoolUnlock(APool.FSpinLock);
  end;
end;

procedure CentralPoolGetStats(var APool: TCentralPool;
  out AStats: TCentralPoolStats);
var
  I: Int32;
begin
  FillChar(AStats, SizeOf(AStats), 0);
  CentralPoolLock(APool.FSpinLock);
  try
    AStats.EntryCount := APool.FEntryCount;
    AStats.ReleasedSpans := APool.FReleasedSpans;
    AStats.ReleasedBytes := APool.FReleasedBytes;
    AStats.DecommitEvents := APool.FDecommitEvents;
    AStats.DecommittedBytes := APool.FDecommittedBytes;
    for I := 0 to APool.FEntryCount - 1 do
    begin
      if APool.FEntries[I].FMemory = nil then
        Continue;
      Inc(AStats.LiveSpans);
      Inc(AStats.LiveBytes, APool.FEntries[I].FMemorySize);
      Inc(AStats.FreeSlots, SpanFreeCount(APool.FEntries[I].FSpan));
      if APool.FEntries[I].FDecommitted then
        Inc(AStats.DecommittedSpans);
      if (APool.FEntries[I].FLastFreeTick <> 0) and
         SpanIsEmpty(APool.FEntries[I].FSpan) then
        Inc(AStats.IdleSpans);
    end;
  finally
    CentralPoolUnlock(APool.FSpinLock);
  end;
end;

function ScavengeCentralPools(var APool: TCentralPool;
  AIdleThreshold: UInt64): Int32;
var
  I, LPrev, LCur: Int32;
  LAge: UInt64;
  LMemSize: SizeUInt;
  LInboxChain: PInboxNode;
begin
  Result := 0;
  { Drain lock-free inbox first so fully-free spans become visible. }
  LInboxChain := GrabInboxChain(APool);
  CentralPoolLock(APool.FSpinLock);
  try
    if LInboxChain <> nil then
      ProcessInboxChain(APool, LInboxChain);
    for I := 0 to APool.FEntryCount - 1 do
    begin
      if Result >= SCAVENGER_MAX_RELEASE then
        Break;
      { Only consider fully-free spans with active memory. }
      if APool.FEntries[I].FMemory = nil then
        Continue;
      if not SpanIsEmpty(APool.FEntries[I].FSpan) then
        Continue;
      if APool.FEntries[I].FLastFreeTick = 0 then
        Continue;
      { Check if idle long enough. Both sides are pool-local ticks, so the
        subtraction can never underflow (FTick only moves forward and the
        stamp was taken from the same clock). }
      LAge := APool.FTick - APool.FEntries[I].FLastFreeTick;
      if LAge >= AIdleThreshold then
      begin
        { Unlink from partial list if present (safety for edge cases). }
        LPrev := -1;
        LCur := APool.FPartialHead;
        while LCur >= 0 do
        begin
          if LCur = I then
          begin
            if LPrev < 0 then
              APool.FPartialHead := APool.FPartialNext[LCur]
            else
              APool.FPartialNext[LPrev] := APool.FPartialNext[LCur];
            Break;
          end;
          LPrev := LCur;
          LCur := APool.FPartialNext[LCur];
        end;
        LMemSize := APool.FEntries[I].FMemorySize;
        platform_virtual_release(APool.FEntries[I].FMemory, LMemSize);
        { atomic_store pairs with the acquire load in FindSpanOwnerThreadId
          (plain store vs atomic load would be a data race). }
        atomic_store(APool.FEntries[I].FMemory, nil, mo_release);
        APool.FEntries[I].FLastFreeTick := 0;
        APool.FEntries[I].FDecommitted := False;
        APool.FEntries[I].FSpan.FBitmap := 0;
        APool.FEntries[I].FSpan.FFreeCount := 0;
        { Push the slot onto the dead chain for revival by AddSpan.
          FPartialNext[I] is free to reuse: the slot was just unlinked
          from the partial list above (if it was there at all). }
        APool.FPartialNext[I] := APool.FDeadHead;
        APool.FDeadHead := I;
        { Invalidate MRU cache if it points to the released span. }
        if APool.FLastHitIndex = I then
          APool.FLastHitIndex := -1;
        Inc(Result);
        Inc(APool.FReleasedSpans);
        Inc(APool.FReleasedBytes, LMemSize);
      end
      { Soft purge: return physical pages, keep virtual reservation.
        Only reachable when SCAVENGER_DECOMMIT_THRESHOLD < AIdleThreshold. }
      else if (LAge >= SCAVENGER_DECOMMIT_THRESHOLD) and
              (not APool.FEntries[I].FDecommitted) then
      begin
        LMemSize := APool.FEntries[I].FMemorySize;
        platform_virtual_decommit(APool.FEntries[I].FMemory, LMemSize);
        APool.FEntries[I].FDecommitted := True;
        Inc(APool.FDecommitEvents);
        Inc(APool.FDecommittedBytes, LMemSize);
      end;
    end;
  finally
    CentralPoolUnlock(APool.FSpinLock);
  end;
end;

function FindSpanOwnerThreadId(var APool: TCentralPool; APtr: Pointer): QWord;
var
  I, LCount: Int32;
  LEntries, LEntry: PCentralSpanEntry;
  LBase: PByte;
  LSize: SizeUInt;
begin
  { LOCK-FREE reader (called from the FreeMem hot path without the
    spinlock). Safety protocol, paired with AddSpan:
    - acquire-load the published count, then snapshot the array base ONCE
      from FEntriesBase — NEVER from FEntries directly: FPC's SetLength
      COW transits the field through nil, which a lock-free reader would
      see as an empty pool (false-negative owner=0). AddSpan
      release-publishes base before count, so seeing count = N guarantees
      a base with capacity >= N and fully initialized entries 0..N-1
    - a stale base is still valid memory: superseded generations are kept
      alive in FRetired. Slot contents may change on revival (dead slot
      reused for a new span), but a legal caller only probes pointers it
      received through a synchronizing handoff, which carries the revival
      writes — see the TCentralSpanEntry invariants. }
  LCount := atomic_load(APool.FEntryCount, mo_acquire);
  LEntries := PCentralSpanEntry(atomic_load(APool.FEntriesBase, mo_acquire));
  if (LCount <= 0) or (LEntries = nil) then
    Exit(0);
  { FMemory is the slot validity gate: acquire-load pairs with the
    release-store in AddSpan's revival path, so a non-nil base guarantees
    the slot's FMemorySize / FOwnerThreadId are the matching values. }
  { Check MRU cache first (racy hint: bounds-checked, validated by range). }
  I := APool.FLastHitIndex;
  if (I >= 0) and (I < LCount) then
  begin
    LEntry := LEntries;
    Inc(LEntry, I);
    LBase := PByte(atomic_load(LEntry^.FMemory, mo_acquire));
    if LBase <> nil then
    begin
      LSize := LEntry^.FMemorySize;
      if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
        Exit(LEntry^.FOwnerThreadId);
    end;
  end;
  { Scan in reverse order. }
  LEntry := LEntries;
  Inc(LEntry, LCount - 1);
  for I := LCount - 1 downto 0 do
  begin
    LBase := PByte(atomic_load(LEntry^.FMemory, mo_acquire));
    if LBase <> nil then
    begin
      LSize := LEntry^.FMemorySize;
      if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
      begin
        { Racy MRU hint write: benign — aligned Int32, always re-validated. }
        APool.FLastHitIndex := I;
        Exit(LEntry^.FOwnerThreadId);
      end;
    end;
    Dec(LEntry);
  end;
  Result := 0;
end;

end.
