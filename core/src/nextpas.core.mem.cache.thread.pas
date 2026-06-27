unit nextpas.core.mem.cache.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
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

  {** Per-thread free-list cache for all size classes.
      Each slot is an intrusive singly-linked list of freed blocks.
      Allocations pop from the list; frees push to the list.
      When the list is empty, a batch refill is requested.
      When the list exceeds CACHE_MAX_LIST_SIZE, a batch flush occurs. }
  TThreadCache = record
    FHeads: array[0..MEM_SIZECLASS_COUNT - 1] of PFreeNode;
    FCounts: array[0..MEM_SIZECLASS_COUNT - 1] of Word;
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
function AdaptiveBatchSize(ASizeClassIndex: Int32): Word;

{** Adaptive max list size for a size class index. }
function AdaptiveMaxListSize(ASizeClassIndex: Int32): Word;

implementation

procedure ThreadCacheInit(out ACache: TThreadCache);
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    ACache.FHeads[I] := nil;
    ACache.FCounts[I] := 0;
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

end.
