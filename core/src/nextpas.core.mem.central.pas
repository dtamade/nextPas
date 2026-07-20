unit nextpas.core.mem.central;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.span,
  nextpas.core.platform.memory;

const
  { Default number of slots per span. }
  CENTRAL_SPAN_SLOTS = 64;

  { Scavenger: soft purge — return physical pages, keep virtual reservation.
    Must be < SCAVENGER_IDLE_THRESHOLD so decommit can fire before hard release.
    At ~10M ops/s, 100K ops ≈ 10ms idle. }
  SCAVENGER_DECOMMIT_THRESHOLD = 100000;

  { Scavenger: hard release — FreeMem backing store after longer idle.
    At ~10M ops/s, 1M ops ≈ 100ms idle. }
  SCAVENGER_IDLE_THRESHOLD = 1000000;

  { Scavenger: how often (in ops) to run a scavenge check.
    Must be power of 2 for cheap masking. }
  SCAVENGER_CHECK_INTERVAL = 1024;

  { Scavenger: max spans hard-released per scavenge pass (bounds hold time). }
  SCAVENGER_MAX_RELEASE = 16;

type
  {** Entry in the central span pool: a span + its memory region. }
  PCentralSpanEntry = ^TCentralSpanEntry;
  TCentralSpanEntry = record
    FSpan: TSpan;
    FMemory: Pointer;     { Allocated memory backing the span. }
    FMemorySize: SizeUInt;
    FLastFreeTick: UInt64; { Op counter when span became fully free (0 = not idle). }
    FOwnerThreadId: QWord; { Thread that allocated this span (for cross-thread free). }
    FDecommitted: Boolean; { True if physical pages returned to OS (virtual reservation kept). }
  end;

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
    FEntries: array of TCentralSpanEntry;
    FEntryCount: Int32;
    FPartialHead: Int32;    { Index of first partial entry (-1 = none). }
    FPartialNext: array of Int32; { Intrusive linked list via indices. }
    FSlotSize: SizeUInt;
    FSpinLock: SizeUInt;    { CentralPoolLock/CentralPoolUnlock. }
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
    AOpCounter: current op counter (for idle tracking on inbox drain).
    Thread-safe. }
function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer; AOpCounter: UInt64): Word;

{** Batch free: return ABlocks[] to their respective spans.
    Fully free spans are marked with the current op counter for scavenging.
    AOpCounter: current op counter (for idle tracking). Thread-safe. }
procedure CentralPoolFree(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer; AOpCounter: UInt64);

{** Return total free slots across all non-released spans. }
function CentralPoolFreeCount(var APool: TCentralPool): SizeUInt;

{** Snapshot live + lifetime scavenger counters. Thread-safe. }
procedure CentralPoolGetStats(var APool: TCentralPool;
  out AStats: TCentralPoolStats);

{** Scan fully-free spans:
    - age >= AIdleThreshold → hard FreeMem (counts as Released*)
    - else age >= SCAVENGER_DECOMMIT_THRESHOLD → soft decommit (Decommit*)
    AOpCounter: current monotonic operation counter.
    Returns number of spans hard-released this pass. Thread-safe. }
function ScavengeCentralPools(var APool: TCentralPool;
  AOpCounter: UInt64; AIdleThreshold: UInt64): Int32;

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
  APool.FSpinLock := 0;
  APool.FInboxHead := nil;
  APool.FLastHitIndex := -1;
  APool.FReleasedSpans := 0;
  APool.FReleasedBytes := 0;
  APool.FDecommitEvents := 0;
  APool.FDecommittedBytes := 0;
  SetLength(APool.FEntries, INITIAL_CAPACITY);
  SetLength(APool.FPartialNext, INITIAL_CAPACITY);
end;

procedure CentralPoolDestroy(var APool: TCentralPool);
var
  I: Int32;
begin
  for I := 0 to APool.FEntryCount - 1 do
    if APool.FEntries[I].FMemory <> nil then
      FreeMem(APool.FEntries[I].FMemory, APool.FEntries[I].FMemorySize);
  APool.FEntryCount := 0;
  APool.FPartialHead := -1;
  APool.FInboxHead := nil;
  SetLength(APool.FEntries, 0);
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
begin
  { Grow arrays if needed. }
  if APool.FEntryCount >= Length(APool.FEntries) then
  begin
    SetLength(APool.FEntries, Length(APool.FEntries) * 2);
    SetLength(APool.FPartialNext, Length(APool.FPartialNext) * 2);
  end;
  LIdx := APool.FEntryCount;
  Inc(APool.FEntryCount);
  { Allocate memory for the span. }
  LMemSize := SizeUInt(CENTRAL_SPAN_SLOTS) * APool.FSlotSize;
  GetMem(LMem, LMemSize);
  FillChar(LMem^, LMemSize, 0);
  { Initialize span. }
  SpanInit(APool.FEntries[LIdx].FSpan, LMem, APool.FSlotSize, CENTRAL_SPAN_SLOTS);
  APool.FEntries[LIdx].FMemory := LMem;
  APool.FEntries[LIdx].FMemorySize := LMemSize;
  APool.FEntries[LIdx].FLastFreeTick := 0;
  { Darwin aarch64 TThreadID is not assignment-compatible with QWord without cast. }
  APool.FEntries[LIdx].FOwnerThreadId := QWord(PtrUInt(GetCurrentThreadId));
  APool.FEntries[LIdx].FDecommitted := False;
  { Add to partial list. }
  APool.FPartialNext[LIdx] := APool.FPartialHead;
  APool.FPartialHead := LIdx;
  Result := LIdx;
end;

{** Grab entire inbox chain via CAS (lock-free, O(1)).
    Returns the head of the grabbed chain, or nil if inbox was empty.
    Safe to call from any thread without locking. }
function GrabInboxChain(var APool: TCentralPool): PInboxNode; forward;

{** Process a grabbed inbox chain: return blocks to their spans.
    Caller must hold spinlock. Returns number of blocks processed. }
function ProcessInboxChain(var APool: TCentralPool;
  AChain: PInboxNode; AOpCounter: UInt64): Word; forward;

function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer; AOpCounter: UInt64): Word;
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
    { Phase 2: Process grabbed chain under spinlock.
      FindSpanIndex + SpanFree need spinlock protection. }
    if LInboxChain <> nil then
      ProcessInboxChain(APool, LInboxChain, AOpCounter);
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
        platform_virtual_commit(APool.FEntries[LIdx].FMemory,
          APool.FEntries[LIdx].FMemorySize);
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
  AChain: PInboxNode; AOpCounter: UInt64): Word;
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
          APool.FEntries[LIdx].FLastFreeTick := AOpCounter;
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
  ACount: Word; ABlocks: PPointer; AOpCounter: UInt64);
var
  I: Word;
  LIdx: Int32;
  LWasFull: Boolean;
begin
  CentralPoolLock(APool.FSpinLock);
  try
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
          APool.FEntries[LIdx].FLastFreeTick := AOpCounter;
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
  AOpCounter: UInt64; AIdleThreshold: UInt64): Int32;
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
      ProcessInboxChain(APool, LInboxChain, AOpCounter);
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
      { Check if idle long enough. }
      LAge := AOpCounter - APool.FEntries[I].FLastFreeTick;
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
        FreeMem(APool.FEntries[I].FMemory, LMemSize);
        APool.FEntries[I].FMemory := nil;
        APool.FEntries[I].FLastFreeTick := 0;
        APool.FEntries[I].FDecommitted := False;
        APool.FEntries[I].FSpan.FBitmap := 0;
        APool.FEntries[I].FSpan.FFreeCount := 0;
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
  I: Int32;
  LBase: PByte;
  LSize: SizeUInt;
begin
  { Check MRU cache first. }
  I := APool.FLastHitIndex;
  if (I >= 0) and (I < APool.FEntryCount) and (APool.FEntries[I].FMemory <> nil) then
  begin
    LBase := PByte(APool.FEntries[I].FMemory);
    LSize := APool.FEntries[I].FMemorySize;
    if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
      Exit(APool.FEntries[I].FOwnerThreadId);
  end;
  { Scan in reverse order. }
  for I := APool.FEntryCount - 1 downto 0 do
  begin
    if APool.FEntries[I].FMemory = nil then
      Continue;
    LBase := PByte(APool.FEntries[I].FMemory);
    LSize := APool.FEntries[I].FMemorySize;
    if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
    begin
      APool.FLastHitIndex := I;
      Exit(APool.FEntries[I].FOwnerThreadId);
    end;
  end;
  Result := 0;
end;

end.
