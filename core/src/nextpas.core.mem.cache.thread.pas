unit nextpas.core.mem.cache.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass;

const
  { Maximum entries per free list before batch flush. }
  CACHE_MAX_LIST_SIZE = 64;

  { Number of entries to refill/flush in a batch. }
  CACHE_BATCH_SIZE = 16;

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
  LBlocks: array[0..CACHE_BATCH_SIZE - 1] of Pointer;
  LCount, I: Word;
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit;
  if not Assigned(ARefillProc) then
    Exit;
  LCount := ARefillProc(ASizeClass, CACHE_BATCH_SIZE, @LBlocks[0]);
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
  LBlocks: array[0..CACHE_BATCH_SIZE - 1] of Pointer;
  LFlushCount, I: Word;
  LNode: PFreeNode;
begin
  if (ASizeClass < 0) or (ASizeClass >= MEM_SIZECLASS_COUNT) then
    Exit;
  if not Assigned(AFlushProc) then
    Exit;
  { Pop up to CACHE_BATCH_SIZE entries. }
  LFlushCount := 0;
  while (ACache.FHeads[ASizeClass] <> nil) and (LFlushCount < CACHE_BATCH_SIZE) do
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

end.
