unit nextpas.core.mem.central;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.span;

const
  { Default number of slots per span. }
  CENTRAL_SPAN_SLOTS = 64;

type
  {** Entry in the central span pool: a span + its memory region. }
  PCentralSpanEntry = ^TCentralSpanEntry;
  TCentralSpanEntry = record
    FSpan: TSpan;
    FMemory: Pointer;     { Allocated memory backing the span. }
    FMemorySize: SizeUInt;
  end;

  {** Central span pool for one size class. Manages partial and full spans.
      Provides batch alloc/free for the thread cache refill/flush path.
      Thread-safe via spinlock (low contention: TLS cache absorbs most traffic). }
  TCentralPool = record
    FEntries: array of TCentralSpanEntry;
    FEntryCount: Int32;
    FPartialHead: Int32;    { Index of first partial entry (-1 = none). }
    FPartialNext: array of Int32; { Intrusive linked list via indices. }
    FSlotSize: SizeUInt;
    FSpinLock: SizeUInt;    { Simple test-and-set lock. }
  end;

{** Initialize a central pool for a given slot size. }
procedure CentralPoolInit(out APool: TCentralPool; ASlotSize: SizeUInt);

{** Release all spans and free backing memory. }
procedure CentralPoolDestroy(var APool: TCentralPool);

{** Batch allocate: fill ABlocks[] with ACount pointers to free slots.
    Returns actual count allocated (may be < ACount if pool exhausted).
    Thread-safe. }
function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer): Word;

{** Batch free: return ABlocks[] to their respective spans.
    Thread-safe. }
procedure CentralPoolFree(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer);

{** Return total free slots across all spans. }
function CentralPoolFreeCount(var APool: TCentralPool): SizeUInt;

implementation

const
  INITIAL_CAPACITY = 4;

procedure SpinLock(var ALock: SizeUInt);
begin
  while AtomicCmpExchange(ALock, 1, 0) <> 0 do
    { Spin }; { No backoff: contention is rare with TLS cache. }
end;

procedure SpinUnlock(var ALock: SizeUInt);
begin
  AtomicExchange(ALock, 0);
end;

procedure CentralPoolInit(out APool: TCentralPool; ASlotSize: SizeUInt);
begin
  APool.FSlotSize := ASlotSize;
  APool.FEntryCount := 0;
  APool.FPartialHead := -1;
  APool.FSpinLock := 0;
  SetLength(APool.FEntries, INITIAL_CAPACITY);
  SetLength(APool.FPartialNext, INITIAL_CAPACITY);
end;

procedure CentralPoolDestroy(var APool: TCentralPool);
var
  I: Int32;
begin
  for I := 0 to APool.FEntryCount - 1 do
    FreeMem(APool.FEntries[I].FMemory, APool.FEntries[I].FMemorySize);
  APool.FEntryCount := 0;
  APool.FPartialHead := -1;
  SetLength(APool.FEntries, 0);
  SetLength(APool.FPartialNext, 0);
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
  { Add to partial list. }
  APool.FPartialNext[LIdx] := APool.FPartialHead;
  APool.FPartialHead := LIdx;
  Result := LIdx;
end;

function CentralPoolAlloc(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer): Word;
var
  LCount: Word;
  LIdx: Int32;
  LPtr: Pointer;
begin
  LCount := 0;
  SpinLock(APool.FSpinLock);
  try
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
    SpinUnlock(APool.FSpinLock);
  end;
  Result := LCount;
end;

{** Find which span owns APtr (by checking address range). }
function FindSpanIndex(const APool: TCentralPool; APtr: Pointer): Int32;
var
  I: Int32;
  LBase: PByte;
  LSize: SizeUInt;
begin
  for I := 0 to APool.FEntryCount - 1 do
  begin
    LBase := PByte(APool.FEntries[I].FMemory);
    LSize := APool.FEntries[I].FMemorySize;
    if (PByte(APtr) >= LBase) and (PByte(APtr) < LBase + LSize) then
      Exit(I);
  end;
  Result := -1;
end;

procedure CentralPoolFree(var APool: TCentralPool;
  ACount: Word; ABlocks: PPointer);
var
  I: Word;
  LIdx: Int32;
  LWasFull: Boolean;
begin
  SpinLock(APool.FSpinLock);
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
      SpanFree(APool.FEntries[LIdx].FSpan, ABlocks^);
      { If span was full and now has space, re-add to partial list. }
      if LWasFull and SpanHasFree(APool.FEntries[LIdx].FSpan) then
      begin
        APool.FPartialNext[LIdx] := APool.FPartialHead;
        APool.FPartialHead := LIdx;
      end;
      Inc(ABlocks);
    end;
  finally
    SpinUnlock(APool.FSpinLock);
  end;
end;

function CentralPoolFreeCount(var APool: TCentralPool): SizeUInt;
var
  I: Int32;
begin
  Result := 0;
  SpinLock(APool.FSpinLock);
  try
    for I := 0 to APool.FEntryCount - 1 do
      Inc(Result, SpanFreeCount(APool.FEntries[I].FSpan));
  finally
    SpinUnlock(APool.FSpinLock);
  end;
end;

end.
