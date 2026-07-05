unit nextpas.core.mem.cache.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.atomic,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass;

const
  { Default max list size for ThreadCacheFree (low-level API).
    Adaptive path in allocator.growing uses AdaptiveMaxListSize per band. }
  CACHE_MAX_LIST_SIZE = 64;

  { Default batch size for ThreadCacheRefill/Flush (low-level API).
    Adaptive path uses AdaptiveBatchSize per band. }
  CACHE_BATCH_SIZE = 16;

  { Adaptive batch thresholds by size class band.
    Small objects get larger batches (more throughput, less central contention).
    Large objects get smaller batches (less memory waste). }
  CACHE_ADAPTIVE_BATCH_SMALL = 32;   { band 0-1: ≤1KB, batch 32, max 128 }
  CACHE_ADAPTIVE_BATCH_MEDIUM = 16;  { band 2-3: ≤8KB, batch 16, max 64 }
  CACHE_ADAPTIVE_BATCH_LARGE = 8;    { band 4:   ≤16KB, batch 8, max 32 }
  CACHE_ADAPTIVE_BATCH_HUGE = 4;     { band 5:   ≤53KB, batch 4, max 16 }

  CACHE_ADAPTIVE_MAX_SMALL = 128;
  CACHE_ADAPTIVE_MAX_MEDIUM = 64;
  CACHE_ADAPTIVE_MAX_LARGE = 32;
  CACHE_ADAPTIVE_MAX_HUGE = 16;

type
  {** Intrusive free-list node. Stored in the first Pointer-sized
      bytes of each freed block (zero overhead per allocation). }
  PFreeNode = ^TFreeNode;
  TFreeNode = record
    FNext: PFreeNode;
  end;

  {** Lock-free inbox node for cross-thread free.
      Uses the same layout as TFreeNode (intrusive, zero overhead). }
  PInboxNode = ^TInboxNode;
  TInboxNode = record
    FNext: PInboxNode;
  end;

  {** Lock-free Treiber stack inbox for cross-thread free.
      Multiple producers (other threads) push via CAS.
      Single consumer (owner thread) pops all via atomic exchange.

      Replaces the previous MPSC queue implementation which had
      sentinel lifecycle issues causing use-after-free in concurrent
      thread creation/destruction scenarios.

      Push: 1 CAS (compare-and-swap on head pointer).
      PopAll: 1 atomic exchange (take entire chain at once). }
  TInboxStack = record
    FHead: PInboxNode;  { Top of stack. Producers CAS here. }
  end;

  {** Per-thread free-list cache for all size classes.
      Each slot is an intrusive singly-linked list of freed blocks.
      Allocations pop from the list; frees push to the list.
      When the list is empty, a batch refill is requested.
      When the list exceeds CACHE_MAX_LIST_SIZE, a batch flush occurs.

      Per-size-class inbox: other threads can push freed blocks here via
      lock-free CAS stack. Owner thread drains inboxes during thread exit.
      Separate inboxes per size class enable correct central pool return. }
  PThreadCache = ^TThreadCache;
  TThreadCache = record
    FHeads: array[0..MEM_SIZECLASS_COUNT - 1] of PFreeNode;
    FCounts: array[0..MEM_SIZECLASS_COUNT - 1] of Word;
    FOpCount: UInt64;
    FInboxes: array[0..MEM_SIZECLASS_COUNT - 1] of TInboxStack;
  end;

  {** Callback for batch refill: allocate ACount blocks of size class AIndex
      and store them in ABlocks[]. Returns actual count filled. }
  TRefillProc = function(AIndex: Int32; ACount: Word;
    ABlocks: PPointer): Word;

  {** Callback for batch flush: free ACount blocks of size class AIndex. }
  TFlushProc = procedure(AIndex: Int32; ACount: Word;
    ABlocks: PPointer);

{** Initialize a thread cache (zero all lists). }
procedure ThreadCacheInit(out ACache: TThreadCache);

{** Try to allocate from the thread cache. Returns nil if the list
    for ASizeClass is empty (caller should refill or use backing allocator). }
function ThreadCacheAlloc(var ACache: TThreadCache;
  ASizeClass: Int32): Pointer;

{** Free a block back to the thread cache.
    If the list exceeds CACHE_MAX_LIST_SIZE, returns False to signal
    the caller should flush a batch. Returns True if cached successfully. }
function ThreadCacheFree(var ACache: TThreadCache;
  ASizeClass: Int32; APtr: Pointer): Boolean;

{** Refill the cache for a size class by requesting blocks from the
    backing allocator via ARefillProc. Fills up to CACHE_BATCH_SIZE entries. }
procedure ThreadCacheRefill(var ACache: TThreadCache;
  ASizeClass: Int32; ARefillProc: TRefillProc);

{** Flush excess entries from a size class's free list via AFlushProc.
    Flushes min(current_count, CACHE_BATCH_SIZE) entries. }
procedure ThreadCacheFlush(var ACache: TThreadCache;
  ASizeClass: Int32; AFlushProc: TFlushProc);

{** Return the number of cached entries for a size class. }
function ThreadCacheCount(const ACache: TThreadCache;
  ASizeClass: Int32): Word; inline;

{** Adaptive batch size for a size class index.
    Small objects → larger batches (throughput), large → smaller (memory). }
function AdaptiveBatchSize(ASizeClassIndex: Int32): Word; inline;

{** Adaptive max list size for a size class index. }
function AdaptiveMaxListSize(ASizeClassIndex: Int32): Word; inline;

{** Flush all cached blocks from all size classes using AFlushProc.
    Used for thread-exit cleanup to prevent cache block leakage. }
procedure ThreadCacheFlushAll(var ACache: TThreadCache;
  AFlushProc: TFlushProc);

{** Drain all per-size-class inboxes and flush via AFlushProc.
    Used for thread-exit cleanup to return cross-thread-freed blocks
    to their respective central pools. }
procedure ThreadCacheDrainInboxes(var ACache: TThreadCache;
  AFlushProc: TFlushProc);

{** Initialize an inbox stack (set head to nil). }
procedure InboxStackInit(out AStack: TInboxStack);

{** Push a block to the inbox stack (lock-free, safe from any thread).
    Uses CAS for O(1) push. }
procedure InboxStackPush(var AStack: TInboxStack; APtr: Pointer);

{** Pop all blocks from the inbox stack via atomic exchange.
    Returns the head of the reversed chain. Caller must walk FNext links.
    Returns nil if empty. Only safe to call from the owner thread. }
function InboxStackPopAll(var AStack: TInboxStack): PInboxNode;

{** Check if the inbox stack is empty. }
function InboxStackIsEmpty(var AStack: TInboxStack): Boolean; inline;

{** Push a block to a specific size class inbox in the thread cache.
    Lock-free, safe from any thread. Used for cross-thread free. }
procedure ThreadCacheInboxPush(var ACache: TThreadCache;
  ASizeClass: Int32; APtr: Pointer);

implementation

procedure ThreadCacheInit(out ACache: TThreadCache);
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    ACache.FHeads[I] := nil;
    ACache.FCounts[I] := 0;
    InboxStackInit(ACache.FInboxes[I]);
  end;
end;

function ThreadCacheAlloc(var ACache: TThreadCache;
  ASizeClass: Int32): Pointer;
var
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit(nil);
  LNode := ACache.FHeads[ASizeClass];
  if LNode = nil then
    Exit(nil);
  { Pop from head. }
  ACache.FHeads[ASizeClass] := LNode^.FNext;
  Dec(ACache.FCounts[ASizeClass]);
  Result := Pointer(LNode);
end;

function ThreadCacheFree(var ACache: TThreadCache;
  ASizeClass: Int32; APtr: Pointer): Boolean;
var
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit(False);
  { Check if flush needed. }
  if ACache.FCounts[ASizeClass] >= CACHE_MAX_LIST_SIZE then
    Exit(False);
  { Push to head. }
  LNode := PFreeNode(APtr);
  LNode^.FNext := ACache.FHeads[ASizeClass];
  ACache.FHeads[ASizeClass] := LNode;
  Inc(ACache.FCounts[ASizeClass]);
  Result := True;
end;

procedure ThreadCacheRefill(var ACache: TThreadCache;
  ASizeClass: Int32; ARefillProc: TRefillProc);
var
  LBlocks: array[0..CACHE_ADAPTIVE_BATCH_SMALL - 1] of Pointer;
  LBatchSize: Word;
  LCount, I: Word;
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit;
  if not Assigned(ARefillProc) then
    Exit;
  LBatchSize := AdaptiveBatchSize(ASizeClass);
  LCount := ARefillProc(ASizeClass, LBatchSize, @LBlocks[0]);
  { Push all allocated blocks to the free list (in reverse to maintain order). }
  for I := LCount downto 1 do
  begin
    LNode := PFreeNode(LBlocks[I - 1]);
    LNode^.FNext := ACache.FHeads[ASizeClass];
    ACache.FHeads[ASizeClass] := LNode;
  end;
  Inc(ACache.FCounts[ASizeClass], LCount);
end;

procedure ThreadCacheFlush(var ACache: TThreadCache;
  ASizeClass: Int32; AFlushProc: TFlushProc);
var
  LBlocks: array[0..CACHE_ADAPTIVE_BATCH_SMALL - 1] of Pointer;
  LBatchSize: Word;
  LFlushCount, I: Word;
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit;
  if not Assigned(AFlushProc) then
    Exit;
  LBatchSize := AdaptiveBatchSize(ASizeClass);
  { Pop up to LBatchSize entries. }
  LFlushCount := 0;
  while (ACache.FHeads[ASizeClass] <> nil) and (LFlushCount < LBatchSize) do
  begin
    LNode := ACache.FHeads[ASizeClass];
    ACache.FHeads[ASizeClass] := LNode^.FNext;
    LBlocks[LFlushCount] := Pointer(LNode);
    Inc(LFlushCount);
  end;
  Dec(ACache.FCounts[ASizeClass], LFlushCount);
  if LFlushCount > 0 then
    AFlushProc(ASizeClass, LFlushCount, @LBlocks[0]);
end;

function ThreadCacheCount(const ACache: TThreadCache;
  ASizeClass: Int32): Word;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit(0);
  Result := ACache.FCounts[ASizeClass];
end;

function AdaptiveBatchSize(ASizeClassIndex: Int32): Word;
begin
  if ASizeClassIndex < 16 then
    Result := CACHE_ADAPTIVE_BATCH_SMALL    { band 0-1: ≤256B-1KB }
  else if ASizeClassIndex < 42 then
    Result := CACHE_ADAPTIVE_BATCH_MEDIUM   { band 2-3: ≤4KB-8KB }
  else if ASizeClassIndex < 47 then
    Result := CACHE_ADAPTIVE_BATCH_LARGE    { band 4: ≤16KB }
  else
    Result := CACHE_ADAPTIVE_BATCH_HUGE;    { band 5: ≤53KB }
end;

function AdaptiveMaxListSize(ASizeClassIndex: Int32): Word;
begin
  if ASizeClassIndex < 16 then
    Result := CACHE_ADAPTIVE_MAX_SMALL
  else if ASizeClassIndex < 42 then
    Result := CACHE_ADAPTIVE_MAX_MEDIUM
  else if ASizeClassIndex < 47 then
    Result := CACHE_ADAPTIVE_MAX_LARGE
  else
    Result := CACHE_ADAPTIVE_MAX_HUGE;
end;

procedure ThreadCacheFlushAll(var ACache: TThreadCache;
  AFlushProc: TFlushProc);
var
  LSizeClass: Int32;
begin
  if not Assigned(AFlushProc) then
    Exit;
  for LSizeClass := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    while ACache.FHeads[LSizeClass] <> nil do
      ThreadCacheFlush(ACache, LSizeClass, AFlushProc);
  end;
end;

procedure ThreadCacheDrainInboxes(var ACache: TThreadCache;
  AFlushProc: TFlushProc);
var
  LSizeClass: Int32;
  LHead: PInboxNode;
  LBlocks: array[0..CACHE_ADAPTIVE_BATCH_SMALL - 1] of Pointer;
  LCount: Word;
begin
  if not Assigned(AFlushProc) then
    Exit;
  for LSizeClass := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    LHead := InboxStackPopAll(ACache.FInboxes[LSizeClass]);
    while LHead <> nil do
    begin
      LCount := 0;
      while (LHead <> nil) and (LCount < CACHE_ADAPTIVE_BATCH_SMALL) do
      begin
        LBlocks[LCount] := Pointer(LHead);
        LHead := LHead^.FNext;
        Inc(LCount);
      end;
      if LCount > 0 then
        AFlushProc(LSizeClass, LCount, @LBlocks[0]);
    end;
  end;
end;

{ --- Inbox Treiber stack implementation --- }

procedure InboxStackInit(out AStack: TInboxStack);
begin
  AStack.FHead := nil;
end;

procedure InboxStackPush(var AStack: TInboxStack; APtr: Pointer);
var
  LNode, LOldHead: PInboxNode;
begin
  LNode := PInboxNode(APtr);
  repeat
    LOldHead := AStack.FHead;
    LNode^.FNext := LOldHead;
  until AtomicCompareExchangePtr(Pointer(AStack.FHead), Pointer(LOldHead), Pointer(LNode)) = Pointer(LOldHead);
end;

function InboxStackPopAll(var AStack: TInboxStack): PInboxNode;
begin
  Result := PInboxNode(AtomicExchangePtr(Pointer(AStack.FHead), nil));
end;

function InboxStackIsEmpty(var AStack: TInboxStack): Boolean;
begin
  Result := AStack.FHead = nil;
end;

procedure ThreadCacheInboxPush(var ACache: TThreadCache;
  ASizeClass: Int32; APtr: Pointer);
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit;
  InboxStackPush(ACache.FInboxes[ASizeClass], APtr);
end;

end.
