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
  {** Unified growing allocator implementing IAllocator.
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
    procedure InitCentrals;
  public
    FOpCounter: UInt64;  { Monotonic op counter for scavenger idle tracking. }
    constructor Create;
    destructor Destroy; override;

    {** Allocate ASize bytes. Returns nil on failure.
        Small allocations go through TLS cache → central pool.
        Large allocations use direct GetMem. }
    function GetMem(ASize: SizeUInt): Pointer;

    {** Free a block previously allocated by GetMem. }
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt);

    {** Allocate ASize bytes, zero-initialized. }
    function AllocMem(ASize: SizeUInt): Pointer;

    {** Force a scavenge pass across all central pools.
        Releases long-idle fully-free spans to OS. }
    procedure Scavenge;
  end;

{** Get the global singleton growing allocator. }
function DefaultGrowingAllocator: TGrowingAllocator;

{** Release the global singleton (for cleanup/testing). }
procedure ResetDefaultGrowingAllocator;

implementation

var
  GGrowingAllocator: TGrowingAllocator;

{ Thread-local cache: one per thread, zero initialization on thread start. }
threadvar
  GThreadCache: TThreadCache;

{ --- Refill/Flush callbacks (standalone functions for TRefillProc/TFlushProc) --- }

function RefillFromCentral(AIndex: Int32; ACount: Word;
  ABlocks: PPointer): Word;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit(0);
  if GGrowingAllocator = nil then
    Exit(0);
  Result := CentralPoolAlloc(GGrowingAllocator.FCentrals[AIndex], ACount, ABlocks,
    GGrowingAllocator.FOpCounter);
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

function TGrowingAllocator.GetMem(ASize: SizeUInt): Pointer;
var
  LIndex: Int32;
  LNode: PFreeNode;
begin
  if ASize = 0 then
    Exit(nil);
  Inc(FOpCounter);
  { Periodic scavenge: release long-idle spans to OS. }
  if (FOpCounter and (SCAVENGER_CHECK_INTERVAL - 1)) = 0 then
  begin
    for LIndex := 0 to MEM_SIZECLASS_COUNT - 1 do
      ScavengeCentralPools(FCentrals[LIndex], FOpCounter,
        SCAVENGER_IDLE_THRESHOLD);
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
      Exit(Pointer(LNode));
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
      Exit(Pointer(LNode));
    end;
  end
  else
  begin
    LIndex := SizeClassIndex(ASize);
    if LIndex < 0 then
    begin
      System.GetMem(Result, ASize);
      Exit;
    end;
    LNode := GThreadCache.FHeads[LIndex];
    if LNode <> nil then
    begin
      GThreadCache.FHeads[LIndex] := LNode^.FNext;
      Dec(GThreadCache.FCounts[LIndex]);
      Exit(Pointer(LNode));
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
end;

procedure TGrowingAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
var
  LIndex: Int32;
  LNode: PFreeNode;
begin
  if APtr = nil then
    Exit;
  Inc(FOpCounter);
  { Fast path for common small sizes: skip SizeClassIndex + shuffle overhead. }
  if ASize <= 256 then
  begin
    LIndex := Int32((ASize + 15) shr 4) - 1;
    if GThreadCache.FCounts[LIndex] < CACHE_ADAPTIVE_MAX_SMALL then
    begin
      { Direct push to head: shuffle not needed for ≤2 element lists. }
      LNode := PFreeNode(APtr);
      LNode^.FNext := GThreadCache.FHeads[LIndex];
      GThreadCache.FHeads[LIndex] := LNode;
      Inc(GThreadCache.FCounts[LIndex]);
      Exit;
    end;
  end
  else if ASize <= 1024 then
  begin
    { Fast formula for band 1 (256-1024, 64B step): (size shr 6) + 14 }
    LIndex := Int32(ASize shr 6) + 14;
    if GThreadCache.FCounts[LIndex] < CACHE_ADAPTIVE_MAX_SMALL then
    begin
      LNode := PFreeNode(APtr);
      LNode^.FNext := GThreadCache.FHeads[LIndex];
      GThreadCache.FHeads[LIndex] := LNode;
      Inc(GThreadCache.FCounts[LIndex]);
      Exit;
    end;
  end
  else
  begin
    LIndex := SizeClassIndex(ASize);
    if LIndex < 0 then
    begin
      System.FreeMem(APtr);
      Exit;
    end;
    if GThreadCache.FCounts[LIndex] < AdaptiveMaxListSize(LIndex) then
    begin
      { For small lists, skip shuffle overhead — direct push to head.
        Shuffle only matters once the list has enough entropy. }
      if GThreadCache.FCounts[LIndex] < 8 then
      begin
        LNode := PFreeNode(APtr);
        LNode^.FNext := GThreadCache.FHeads[LIndex];
        GThreadCache.FHeads[LIndex] := LNode;
        Inc(GThreadCache.FCounts[LIndex]);
        Exit;
      end;
      FreeListInsertShuffled(Pointer(GThreadCache.FHeads[LIndex]),
        APtr, GThreadCache.FCounts[LIndex]);
      Inc(GThreadCache.FCounts[LIndex]);
      Exit;
    end;
  end;
  { Cache full: flush a batch to central, then push with shuffle. }
  ThreadCacheFlush(GThreadCache, LIndex, @FlushToCentral);
  FreeListInsertShuffled(Pointer(GThreadCache.FHeads[LIndex]),
    APtr, GThreadCache.FCounts[LIndex]);
  Inc(GThreadCache.FCounts[LIndex]);
end;

function TGrowingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
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
  GGrowingAllocator := TGrowingAllocator.Create;

finalization
  FreeAndNil(GGrowingAllocator);

end.
