unit nextpas.core.mem.allocator.mmap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,          // AlignUp (QA-003: 去重)
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.memory_map,
  nextpas.core.text,
  nextpas.core.mem.mutex;

type
  TMemoryMapAllocator = class(TAllocator)
  private
    FMap: TMemoryMap;
    FBase: PByte;
    FReservationSize: SizeUInt;
    FFreeHeadOffset: UInt64;
    FLock: TMemMutex;

    function AllocateLocked(ASize: SizeUInt): Pointer;
    procedure FreeLocked(APtr: Pointer);
    function FindBlockForPayload(APtr: Pointer; out aBlock: Pointer; out aHeaderOffset: UInt64): Boolean;
    function PointerToOffset(APtr: Pointer; out aOffset: UInt64): Boolean;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    constructor CreateAnonymous(aReservationSize: UInt64);
    destructor Destroy; override;
    function Traits: TAllocatorTraits; override;

    property ReservationSize: SizeUInt read FReservationSize;
  end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.mem.error;

const
  MAP_BLOCK_MAGIC = $4D4D4150; // 'MMAP'
  MAP_BLOCK_FREE = 0;
  MAP_BLOCK_USED = 1;
  NO_FREE_OFFSET = High(UInt64);

type
  PMemoryMapBlockHeader = ^TMemoryMapBlockHeader;
  TMemoryMapBlockHeader = packed record
    Magic: UInt32;
    State: UInt32;
    TotalSize: SizeUInt;
    RequestedSize: SizeUInt;
    NextFreeOffset: UInt64;
  end;

function HeaderSize: SizeUInt; inline;
begin
  Result := (SizeOf(TMemoryMapBlockHeader) + SizeOf(Pointer) - 1) and not (SizeOf(Pointer) - 1);
end;

function MinSizeUInt(aLeft, aRight: SizeUInt): SizeUInt; inline;
begin
  if aLeft < aRight then
    Result := aLeft
  else
    Result := aRight;
end;

function TMemoryMapAllocator.PointerToOffset(APtr: Pointer; out aOffset: UInt64): Boolean;
var
  LBase: PtrUInt;
  LPtr: PtrUInt;
begin
  Result := False;
  aOffset := 0;
  if (APtr = nil) or (FBase = nil) then Exit;

  LBase := PtrUInt(FBase);
  LPtr := PtrUInt(APtr);
  if LPtr < LBase then Exit;

  aOffset := UInt64(LPtr - LBase);
  Result := aOffset < FReservationSize;
end;

function TMemoryMapAllocator.FindBlockForPayload(APtr: Pointer; out aBlock: Pointer;
  out aHeaderOffset: UInt64): Boolean;
var
  LPayloadOffset: UInt64;
  LCurrentOffset: UInt64;
  LBlock: PMemoryMapBlockHeader;
begin
  Result := False;
  aBlock := nil;
  aHeaderOffset := 0;
  if (not PointerToOffset(APtr, LPayloadOffset)) or (LPayloadOffset < HeaderSize) then Exit;

  LCurrentOffset := 0;
  while LCurrentOffset < FReservationSize do
  begin
    LBlock := PMemoryMapBlockHeader(FBase + LCurrentOffset);
    if (LBlock^.Magic <> MAP_BLOCK_MAGIC) or
       (LBlock^.TotalSize < HeaderSize) or
       (LBlock^.TotalSize > FReservationSize - LCurrentOffset) then
      raise EAllocError.Create(aeInternalError, 'TMemoryMapAllocator: block chain corruption');

    if LPayloadOffset = LCurrentOffset + HeaderSize then
    begin
      aBlock := LBlock;
      aHeaderOffset := LCurrentOffset;
      Exit(True);
    end;

    if LPayloadOffset < LCurrentOffset + LBlock^.TotalSize then
      Exit(False);

    Inc(LCurrentOffset, LBlock^.TotalSize);
  end;
end;

function TMemoryMapAllocator.AllocateLocked(ASize: SizeUInt): Pointer;
var
  LNeeded: SizeUInt;
  LPrevOffset: UInt64;
  LCurrentOffset: UInt64;
  LBlock: PMemoryMapBlockHeader;
  LPrev: PMemoryMapBlockHeader;
  LRemaining: SizeUInt;
  LNextOffset: UInt64;
  LSplit: PMemoryMapBlockHeader;
begin
  Result := nil;
  if ASize = 0 then Exit;

  LNeeded := AlignUp(HeaderSize + ASize, SizeOf(Pointer));
  if LNeeded < ASize then Exit;

  LPrevOffset := NO_FREE_OFFSET;
  LCurrentOffset := FFreeHeadOffset;
  while LCurrentOffset <> NO_FREE_OFFSET do
  begin
    if LCurrentOffset >= FReservationSize then
      raise EAllocError.Create(aeInternalError, 'TMemoryMapAllocator: free list offset out of range');

    LBlock := PMemoryMapBlockHeader(FBase + LCurrentOffset);
    if (LBlock^.Magic <> MAP_BLOCK_MAGIC) or (LBlock^.State <> MAP_BLOCK_FREE) then
      raise EAllocError.Create(aeInternalError, 'TMemoryMapAllocator: free list corruption');

    if LBlock^.TotalSize >= LNeeded then
    begin
      LNextOffset := LBlock^.NextFreeOffset;
      LRemaining := LBlock^.TotalSize - LNeeded;
      if LRemaining >= HeaderSize + SizeOf(Pointer) then
      begin
        LSplit := PMemoryMapBlockHeader(PByte(LBlock) + LNeeded);
        LSplit^.Magic := MAP_BLOCK_MAGIC;
        LSplit^.State := MAP_BLOCK_FREE;
        LSplit^.TotalSize := LRemaining;
        LSplit^.RequestedSize := 0;
        LSplit^.NextFreeOffset := LNextOffset;
        LNextOffset := UInt64(PtrUInt(LSplit) - PtrUInt(FBase));
        LBlock^.TotalSize := LNeeded;
      end;

      if LPrevOffset = NO_FREE_OFFSET then
        FFreeHeadOffset := LNextOffset
      else
      begin
        LPrev := PMemoryMapBlockHeader(FBase + LPrevOffset);
        LPrev^.NextFreeOffset := LNextOffset;
      end;

      LBlock^.State := MAP_BLOCK_USED;
      LBlock^.RequestedSize := ASize;
      LBlock^.NextFreeOffset := NO_FREE_OFFSET;
      Exit(Pointer(PByte(LBlock) + HeaderSize));
    end;

    LPrevOffset := LCurrentOffset;
    LCurrentOffset := LBlock^.NextFreeOffset;
  end;
end;

procedure TMemoryMapAllocator.FreeLocked(APtr: Pointer);
var
  LHeaderOffset: UInt64;
  LBlockPtr: Pointer;
  LBlock: PMemoryMapBlockHeader;
  LCurrentOffset: UInt64;
  LCurBlock: PMemoryMapBlockHeader;
  LRunBase: PMemoryMapBlockHeader;
  LRunSize: SizeUInt;
begin
  if APtr = nil then Exit;
  if not FindBlockForPayload(APtr, LBlockPtr, LHeaderOffset) then
    raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.FreeMem: pointer not owned');
  LBlock := PMemoryMapBlockHeader(LBlockPtr);
  if LBlock^.State = MAP_BLOCK_FREE then
    raise EAllocError.Create(aeDoubleFree, 'TMemoryMapAllocator.FreeMem: double free detected');
  if LBlock^.State <> MAP_BLOCK_USED then
    raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.FreeMem: invalid block state');

  { Mark the freed block as free. }
  LBlock^.State := MAP_BLOCK_FREE;
  LBlock^.RequestedSize := 0;

  { Coalesce adjacent free blocks: single pass over the block chain.
    Consecutive free runs are merged so the first block's TotalSize
    covers the entire run. Merged-away blocks remain valid but are
    invisible to the allocation scan (AllocateLocked walks by TotalSize). }
  LCurrentOffset := 0;
  while LCurrentOffset < FReservationSize do
  begin
    LCurBlock := PMemoryMapBlockHeader(FBase + LCurrentOffset);
    if (LCurBlock^.Magic <> MAP_BLOCK_MAGIC) or (LCurBlock^.TotalSize < HeaderSize) then
      raise EAllocError.Create(aeInternalError, 'TMemoryMapAllocator: coalesce scan corruption');

    if LCurBlock^.State = MAP_BLOCK_FREE then
    begin
      LRunBase := LCurBlock;
      LRunSize := LCurBlock^.TotalSize;
      Inc(LCurrentOffset, LCurBlock^.TotalSize);

      { Extend the run through consecutive free blocks. }
      while LCurrentOffset < FReservationSize do
      begin
        LCurBlock := PMemoryMapBlockHeader(FBase + LCurrentOffset);
        if (LCurBlock^.Magic <> MAP_BLOCK_MAGIC) or (LCurBlock^.TotalSize < HeaderSize) then
          raise EAllocError.Create(aeInternalError, 'TMemoryMapAllocator: coalesce scan corruption');
        if LCurBlock^.State <> MAP_BLOCK_FREE then
          Break;
        Inc(LRunSize, LCurBlock^.TotalSize);
        Inc(LCurrentOffset, LCurBlock^.TotalSize);
      end;

      { Merge: extend the first free block to cover the entire run. }
      LRunBase^.TotalSize := LRunSize;
      LRunBase^.NextFreeOffset := NO_FREE_OFFSET;
    end
    else
      Inc(LCurrentOffset, LCurBlock^.TotalSize);
  end;

  { Rebuild the free list from the merged block chain.
    Forward scan with prepend produces a list ordered by ascending address. }
  FFreeHeadOffset := NO_FREE_OFFSET;
  LCurrentOffset := 0;
  while LCurrentOffset < FReservationSize do
  begin
    LCurBlock := PMemoryMapBlockHeader(FBase + LCurrentOffset);
    if LCurBlock^.State = MAP_BLOCK_FREE then
    begin
      LCurBlock^.NextFreeOffset := FFreeHeadOffset;
      FFreeHeadOffset := LCurrentOffset;
    end;
    Inc(LCurrentOffset, LCurBlock^.TotalSize);
  end;
end;

constructor TMemoryMapAllocator.CreateAnonymous(aReservationSize: UInt64);
var
  LInitialBlock: PMemoryMapBlockHeader;
begin
  inherited Create;
  FLock.Init;

  if aReservationSize < HeaderSize + SizeOf(Pointer) then
    raise EAllocError.Create(aeInvalidLayout, 'TMemoryMapAllocator: invalid reservation size');
  {$IF SizeOf(SizeUInt) < SizeOf(UInt64)}
  if aReservationSize > High(SizeUInt) then
    raise EAllocError.Create(aeInvalidLayout, 'TMemoryMapAllocator: reservation size exceeds addressable range');
  {$ENDIF}

  FMap := TMemoryMap.Create;
  if not FMap.CreateAnonymous(aReservationSize) then
  begin
    FMap.Free;
    FMap := nil;
    FLock.Done;
    raise EOutOfMemory.Create(aeOutOfMemory,
      'TMemoryMapAllocator.Create: failed to create anonymous mapping (' +
      IntToStr(Int64(aReservationSize)) + ' bytes)');
  end;

  FBase := FMap.BaseAddress;
  FReservationSize := SizeUInt(aReservationSize);
  FFreeHeadOffset := 0;

  LInitialBlock := PMemoryMapBlockHeader(FBase);
  LInitialBlock^.Magic := MAP_BLOCK_MAGIC;
  LInitialBlock^.State := MAP_BLOCK_FREE;
  LInitialBlock^.TotalSize := FReservationSize;
  LInitialBlock^.RequestedSize := 0;
  LInitialBlock^.NextFreeOffset := NO_FREE_OFFSET;
end;

destructor TMemoryMapAllocator.Destroy;
begin
  FBase := nil;
  FReservationSize := 0;
  FFreeHeadOffset := NO_FREE_OFFSET;
  FMap.Free;
  FMap := nil;
  FLock.Done;
  inherited Destroy;
end;

function TMemoryMapAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := AllocateLocked(ASize);
  finally
    FLock.Release;
  end;
end;

function TMemoryMapAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  FLock.Acquire;
  try
    Result := AllocateLocked(ASize);
    if Result <> nil then
      ZeroMem(Result, ASize);
  finally
    FLock.Release;
  end;
end;

function TMemoryMapAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LHeaderOffset: UInt64;
  LOldBlockPtr: Pointer;
  LOldBlock: PMemoryMapBlockHeader;
  LCopySize: SizeUInt;
begin
  FLock.Acquire;
  try
    if not FindBlockForPayload(ADst, LOldBlockPtr, LHeaderOffset) then
      raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.ReallocMem: pointer not owned');

    LOldBlock := PMemoryMapBlockHeader(LOldBlockPtr);
    if LOldBlock^.State <> MAP_BLOCK_USED then
      raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.ReallocMem: invalid block');

    if ASize <= (LOldBlock^.TotalSize - HeaderSize) then
    begin
      LOldBlock^.RequestedSize := ASize;
      Exit(ADst);
    end;

    Result := AllocateLocked(ASize);
    if Result = nil then Exit;

    LCopySize := MinSizeUInt(LOldBlock^.RequestedSize, ASize);
    if LCopySize > 0 then
      CopyMem(Result, ADst, LCopySize);
    FreeLocked(ADst);
  finally
    FLock.Release;
  end;
end;

procedure TMemoryMapAllocator.DoFreeMem(ADst: Pointer);
begin
  FLock.Acquire;
  try
    FreeLocked(ADst);
  finally
    FLock.Release;
  end;
end;

function TMemoryMapAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ZeroInitialized := True;
  Result.ThreadSafe := True;
end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;
begin
  Result := TMemoryMapAllocator.CreateAnonymous(aReservationSize);
end;

end.
