unit nextpas.core.mem.allocator.memory_map_allocator;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.memory_map;

type
  TMemoryMapAllocator = class(TAllocator)
  private
    FMap: TMemoryMap;
    FBase: PByte;
    FReservationSize: SizeUInt;
    FFreeHeadOffset: UInt64;
    FLock: TRTLCriticalSection;

    function AllocateLocked(aSize: SizeUInt): Pointer;
    procedure FreeLocked(aPtr: Pointer);
    function FindBlockForPayload(aPtr: Pointer; out aBlock: Pointer; out aHeaderOffset: UInt64): Boolean;
    function PointerToOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    constructor CreateAnonymous(aReservationSize: UInt64);
    destructor Destroy; override;
    function Traits: TAllocatorTraits; override;

    property ReservationSize: SizeUInt read FReservationSize;
  end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;

implementation

uses
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

function AlignUp(aValue, aAlign: SizeUInt): SizeUInt; inline;
begin
  Result := (aValue + aAlign - 1) and not (aAlign - 1);
end;

function MinSizeUInt(aLeft, aRight: SizeUInt): SizeUInt; inline;
begin
  if aLeft < aRight then
    Result := aLeft
  else
    Result := aRight;
end;

function TMemoryMapAllocator.PointerToOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
var
  LBase: PtrUInt;
  LPtr: PtrUInt;
begin
  Result := False;
  aOffset := 0;
  if (aPtr = nil) or (FBase = nil) then Exit;

  LBase := PtrUInt(FBase);
  LPtr := PtrUInt(aPtr);
  if LPtr < LBase then Exit;

  aOffset := UInt64(LPtr - LBase);
  Result := aOffset < FReservationSize;
end;

function TMemoryMapAllocator.FindBlockForPayload(aPtr: Pointer; out aBlock: Pointer;
  out aHeaderOffset: UInt64): Boolean;
var
  LPayloadOffset: UInt64;
  LCurrentOffset: UInt64;
  LBlock: PMemoryMapBlockHeader;
begin
  Result := False;
  aBlock := nil;
  aHeaderOffset := 0;
  if (not PointerToOffset(aPtr, LPayloadOffset)) or (LPayloadOffset < HeaderSize) then Exit;

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

function TMemoryMapAllocator.AllocateLocked(aSize: SizeUInt): Pointer;
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
  if aSize = 0 then Exit;

  LNeeded := AlignUp(HeaderSize + aSize, SizeOf(Pointer));
  if LNeeded < aSize then Exit;

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
      LBlock^.RequestedSize := aSize;
      LBlock^.NextFreeOffset := NO_FREE_OFFSET;
      Exit(Pointer(PByte(LBlock) + HeaderSize));
    end;

    LPrevOffset := LCurrentOffset;
    LCurrentOffset := LBlock^.NextFreeOffset;
  end;
end;

procedure TMemoryMapAllocator.FreeLocked(aPtr: Pointer);
var
  LHeaderOffset: UInt64;
  LBlockPtr: Pointer;
  LBlock: PMemoryMapBlockHeader;
begin
  if aPtr = nil then Exit;
  if not FindBlockForPayload(aPtr, LBlockPtr, LHeaderOffset) then
    raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.FreeMem: pointer not owned');
  LBlock := PMemoryMapBlockHeader(LBlockPtr);
  if LBlock^.State = MAP_BLOCK_FREE then
    raise EAllocError.Create(aeDoubleFree, 'TMemoryMapAllocator.FreeMem: double free detected');
  if LBlock^.State <> MAP_BLOCK_USED then
    raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.FreeMem: invalid block state');

  LBlock^.State := MAP_BLOCK_FREE;
  LBlock^.RequestedSize := 0;
  LBlock^.NextFreeOffset := FFreeHeadOffset;
  FFreeHeadOffset := LHeaderOffset;
end;

constructor TMemoryMapAllocator.CreateAnonymous(aReservationSize: UInt64);
var
  LInitialBlock: PMemoryMapBlockHeader;
begin
  inherited Create;
  InitCriticalSection(FLock);

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
    DoneCriticalSection(FLock);
    raise EOutOfMemory.Create(aeOutOfMemory, 'TMemoryMapAllocator: failed to create anonymous mapping');
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
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TMemoryMapAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  EnterCriticalSection(FLock);
  try
    Result := AllocateLocked(aSize);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TMemoryMapAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  EnterCriticalSection(FLock);
  try
    Result := AllocateLocked(aSize);
    if Result <> nil then
      FillChar(Result^, aSize, 0);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TMemoryMapAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LHeaderOffset: UInt64;
  LOldBlockPtr: Pointer;
  LOldBlock: PMemoryMapBlockHeader;
  LCopySize: SizeUInt;
begin
  EnterCriticalSection(FLock);
  try
    if not FindBlockForPayload(aDst, LOldBlockPtr, LHeaderOffset) then
      raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.ReallocMem: pointer not owned');

    LOldBlock := PMemoryMapBlockHeader(LOldBlockPtr);
    if LOldBlock^.State <> MAP_BLOCK_USED then
      raise EAllocError.Create(aeInvalidPointer, 'TMemoryMapAllocator.ReallocMem: invalid block');

    if aSize <= (LOldBlock^.TotalSize - HeaderSize) then
    begin
      LOldBlock^.RequestedSize := aSize;
      Exit(aDst);
    end;

    Result := AllocateLocked(aSize);
    if Result = nil then Exit;

    LCopySize := MinSizeUInt(LOldBlock^.RequestedSize, aSize);
    if LCopySize > 0 then
      Move(aDst^, Result^, LCopySize);
    FreeLocked(aDst);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TMemoryMapAllocator.DoFreeMem(aDst: Pointer);
begin
  EnterCriticalSection(FLock);
  try
    FreeLocked(aDst);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TMemoryMapAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ZeroInitialized := False;
  Result.ThreadSafe := True;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;
begin
  Result := TMemoryMapAllocator.CreateAnonymous(aReservationSize);
end;

end.
