{$CODEPAGE UTF8}
unit nextpas.core.mem.mapped_slab_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils, nextpas.core.mem.memory_map;

type
  {**
   * TMappedSlabAllocator
   *
   * @desc 基于匿名映射的 Slab 分配器
   *       结合了 TMemoryMap 的高效内存管理和 Slab 的快速分配算法
   *       支持大块匿名映射内存的分配/释放/重置
   *}
  TMappedSlabAllocator = class
  private
    FMemoryMap: TMemoryMap;
    FHeader: Pointer;
    FSlabData: Pointer;
    FPoolSize: UInt64;
    FPageSize: UInt32;
    FMaxSizeClass: UInt32;
    FPages: Pointer;
    FDataArea: Pointer;

    function GetPageDescriptor(aPageIndex: UInt32): Pointer;
    function GetBaseAddress: Pointer;
    function DataOffsetToPointer(aOffset: UInt64): Pointer;
    function PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
    function PageUsableSize(aPageIndex: UInt32): UInt32;
    function CalculateRequiredSize(aPoolSize: UInt64): UInt64;
    procedure InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
    function ValidateHeader: Boolean;
    procedure InitializeSlabStructures;

  public
    constructor CreateAnonymous(aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048);
    destructor Destroy; override;

    procedure Close;

    procedure FreeBlock(aPtr: Pointer);
    function Alloc(aSize: UInt64): Pointer;

    procedure GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
      out aUsedPages, aTotalPages: UInt32);
    procedure Reset;
    function IsValid: Boolean;

    property PoolSize: UInt64 read FPoolSize;
    property PageSize: UInt32 read FPageSize;
    property MaxSizeClass: UInt32 read FMaxSizeClass;
    property BaseAddress: Pointer read GetBaseAddress;
  end;

  { TMappedSlabPool is deprecated: use TMappedSlabAllocator }
  TMappedSlabPool = TMappedSlabAllocator;
  {$WARNING 'TMappedSlabPool is deprecated: use TMappedSlabAllocator'}

implementation

uses
  nextpas.core.mem.error;

const
  HEADER_SIZE = 128;
  SLAB_MAGIC = $534C4142;
  SLAB_VERSION = 2;
  BLOCK_MAGIC = $4D53424C;
  BLOCK_STATE_FREE = 0;
  BLOCK_STATE_USED = 1;
  NO_FREE_OFFSET = High(UInt64);

type
  PMappedSlabHeader = ^TMappedSlabHeader;
  TMappedSlabHeader = packed record
    Magic: UInt32;
    Version: UInt32;
    PoolSize: UInt64;
    PageSize: UInt32;
    MaxSizeClass: UInt32;
    TotalPages: UInt32;
    UsedPages: UInt32;
    TotalAllocs: UInt64;
    TotalFrees: UInt64;
    FailedAllocs: UInt64;
    ResetGeneration: UInt32;
    Reserved: array[0..27] of Byte;
  end;

  PMappedSlabPage = ^TMappedSlabPage;
  TMappedSlabPage = packed record
    BlockSize: UInt32;
    BlockCapacity: UInt32;
    AllocatedCount: UInt32;
    FreeCount: UInt32;
    FreeHeadOffset: UInt64;
    BumpOffset: UInt32;
    Generation: UInt32;
  end;

  PMappedSlabBlockHeader = ^TMappedSlabBlockHeader;
  TMappedSlabBlockHeader = packed record
    Magic: UInt32;
    PageIndex: UInt32;
    BlockSize: UInt32;
    RequestedSize: UInt32;
    State: UInt32;
    Generation: UInt32;
    NextFreeOffset: UInt64;
  end;

{ TMappedSlabAllocator }

constructor TMappedSlabAllocator.CreateAnonymous(aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32);
var
  LRequiredSize: UInt64;
begin
  inherited Create;
  FMemoryMap := nil;
  FHeader := nil;
  FSlabData := nil;
  FPoolSize := 0;
  FPageSize := 4096;
  FMaxSizeClass := 2048;
  FPages := nil;
  FDataArea := nil;

  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);

  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.CreateAnonymous(LRequiredSize, mmaReadWrite) then
    begin
      FMemoryMap.Free;
      FMemoryMap := nil;
      Exit;
    end;

    FHeader := FMemoryMap.BaseAddress;
    InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass);
    InitializeSlabStructures;
  except
    FMemoryMap.Free;
    FMemoryMap := nil;
    raise;
  end;
end;

destructor TMappedSlabAllocator.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMappedSlabAllocator.GetBaseAddress: Pointer;
begin
  if FMemoryMap <> nil then
    Result := FMemoryMap.BaseAddress
  else
    Result := nil;
end;

function TMappedSlabAllocator.GetPageDescriptor(aPageIndex: UInt32): Pointer;
begin
  Result := Pointer(PByte(FPages) + SizeUInt(aPageIndex) * SizeOf(TMappedSlabPage));
end;

function TMappedSlabAllocator.DataOffsetToPointer(aOffset: UInt64): Pointer;
begin
  Result := Pointer(PByte(FDataArea) + SizeUInt(aOffset));
end;

function TMappedSlabAllocator.PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
var
  LBase: PtrUInt;
  LPtr: PtrUInt;
begin
  Result := False;
  aOffset := 0;
  if (aPtr = nil) or (FDataArea = nil) then Exit;
  LBase := PtrUInt(FDataArea);
  LPtr := PtrUInt(aPtr);
  if LPtr < LBase then Exit;
  aOffset := UInt64(LPtr - LBase);
  Result := aOffset < FPoolSize;
end;

function TMappedSlabAllocator.PageUsableSize(aPageIndex: UInt32): UInt32;
var
  LPageStart: UInt64;
  LRemaining: UInt64;
begin
  LPageStart := UInt64(aPageIndex) * UInt64(FPageSize);
  if LPageStart >= FPoolSize then
    Exit(0);
  LRemaining := FPoolSize - LPageStart;
  if LRemaining > FPageSize then
    Result := FPageSize
  else
    Result := UInt32(LRemaining);
end;

function TMappedSlabAllocator.CalculateRequiredSize(aPoolSize: UInt64): UInt64;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
begin
  LPageCount := (aPoolSize + FPageSize - 1) div FPageSize;
  LPageDescriptorSize := LPageCount * SizeOf(TMappedSlabPage);
  Result := HEADER_SIZE + LPageDescriptorSize + aPoolSize;
  Result := ((Result + FPageSize - 1) div FPageSize) * FPageSize;
end;

procedure TMappedSlabAllocator.InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  FPoolSize := aPoolSize;
  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;

  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.Magic := SLAB_MAGIC;
  LHeader^.Version := SLAB_VERSION;
  LHeader^.PoolSize := aPoolSize;
  LHeader^.PageSize := aPageSize;
  LHeader^.MaxSizeClass := aMaxSizeClass;
  LHeader^.TotalPages := (aPoolSize + aPageSize - 1) div aPageSize;
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;
  LHeader^.ResetGeneration := 1;
  FillChar(LHeader^.Reserved, SizeOf(LHeader^.Reserved), 0);
end;

function TMappedSlabAllocator.ValidateHeader: Boolean;
var
  LHeader: PMappedSlabHeader;
begin
  Result := False;
  if FHeader = nil then Exit;
  LHeader := PMappedSlabHeader(FHeader);
  if (LHeader^.Magic <> SLAB_MAGIC) or (LHeader^.Version <> SLAB_VERSION) then
    Exit;
  FPoolSize := LHeader^.PoolSize;
  FPageSize := LHeader^.PageSize;
  FMaxSizeClass := LHeader^.MaxSizeClass;
  Result := True;
end;

procedure TMappedSlabAllocator.InitializeSlabStructures;
var
  LPageCount: UInt64;
  LPageDescriptorSize: UInt64;
begin
  LPageCount := (FPoolSize + FPageSize - 1) div FPageSize;
  LPageDescriptorSize := LPageCount * SizeOf(TMappedSlabPage);
  FPages := Pointer(PByte(FHeader) + HEADER_SIZE);
  FDataArea := Pointer(PByte(FPages) + LPageDescriptorSize);
  FSlabData := FDataArea;
  FillChar(FPages^, LPageDescriptorSize, 0);
end;

procedure TMappedSlabAllocator.Close;
begin
  FHeader := nil;
  FSlabData := nil;
  FPages := nil;
  FDataArea := nil;
  FPoolSize := 0;

  if Assigned(FMemoryMap) then
  begin
    FMemoryMap.Free;
    FMemoryMap := nil;
  end;
end;

function TMappedSlabAllocator.Alloc(aSize: UInt64): Pointer;
var
  LHeader: PMappedSlabHeader;
  LBlockSize: UInt32;
  LBlockBytes: UInt32;
  LPageIndex: UInt32;
  LChosenPageIndex: UInt32;
  LPage: PMappedSlabPage;
  LChosenPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
  LBlockOffset: UInt64;
  LPageStart: UInt64;
  LPageUsable: UInt32;
  LFound: Boolean;
begin
  Result := nil;
  if not IsValid then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  if (aSize = 0) or (aSize > FMaxSizeClass) or
     (aSize > UInt64(High(UInt32)) - SizeOf(TMappedSlabBlockHeader) - 7) then
  begin
    Inc(LHeader^.FailedAllocs);
    Exit;
  end;

  LBlockSize := UInt32((aSize + 7) and not UInt64(7));
  LBlockBytes := LBlockSize + SizeOf(TMappedSlabBlockHeader);

  LFound := False;
  LChosenPage := nil;
  LChosenPageIndex := 0;

  for LPageIndex := 0 to LHeader^.TotalPages - 1 do
  begin
    LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
    LPageUsable := PageUsableSize(LPageIndex);

    if (LPage^.BlockSize = LBlockSize) and
       ((LPage^.FreeHeadOffset <> NO_FREE_OFFSET) or
        (UInt64(LPage^.BumpOffset) + LBlockBytes <= LPageUsable)) then
    begin
      LChosenPage := LPage;
      LChosenPageIndex := LPageIndex;
      LFound := True;
      Break;
    end;

    if (not LFound) and (LChosenPage = nil) and (LPage^.BlockSize = 0) and
       (LBlockBytes <= LPageUsable) then
    begin
      LChosenPage := LPage;
      LChosenPageIndex := LPageIndex;
    end;
  end;

  if LChosenPage = nil then
  begin
    Inc(LHeader^.FailedAllocs);
    Exit;
  end;

  if not LFound then
  begin
    LPageUsable := PageUsableSize(LChosenPageIndex);
    FillChar(LChosenPage^, SizeOf(TMappedSlabPage), 0);
    LChosenPage^.BlockSize := LBlockSize;
    LChosenPage^.BlockCapacity := LPageUsable div LBlockBytes;
    LChosenPage^.FreeHeadOffset := NO_FREE_OFFSET;
    LChosenPage^.Generation := LHeader^.ResetGeneration;
    Inc(LHeader^.UsedPages);
  end;

  if LChosenPage^.FreeHeadOffset <> NO_FREE_OFFSET then
  begin
    LBlockOffset := LChosenPage^.FreeHeadOffset;
    LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
    if (LBlock^.Magic <> BLOCK_MAGIC) or
       (LBlock^.PageIndex <> LChosenPageIndex) or
       (LBlock^.BlockSize <> LBlockSize) or
       (LBlock^.State <> BLOCK_STATE_FREE) or
       (LBlock^.Generation <> LChosenPage^.Generation) then
    begin
      Inc(LHeader^.FailedAllocs);
      Exit;
    end;
    LChosenPage^.FreeHeadOffset := LBlock^.NextFreeOffset;
    Dec(LChosenPage^.FreeCount);
  end
  else
  begin
    LPageUsable := PageUsableSize(LChosenPageIndex);
    if UInt64(LChosenPage^.BumpOffset) + LBlockBytes > LPageUsable then
    begin
      Inc(LHeader^.FailedAllocs);
      Exit;
    end;

    LPageStart := UInt64(LChosenPageIndex) * UInt64(FPageSize);
    LBlockOffset := LPageStart + LChosenPage^.BumpOffset;
    LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
    Inc(LChosenPage^.BumpOffset, LBlockBytes);
  end;

  LBlock^.Magic := BLOCK_MAGIC;
  LBlock^.PageIndex := LChosenPageIndex;
  LBlock^.BlockSize := LBlockSize;
  LBlock^.RequestedSize := UInt32(aSize);
  LBlock^.State := BLOCK_STATE_USED;
  LBlock^.Generation := LChosenPage^.Generation;
  LBlock^.NextFreeOffset := NO_FREE_OFFSET;

  Inc(LChosenPage^.AllocatedCount);
  Inc(LHeader^.TotalAllocs);
  Result := Pointer(PByte(LBlock) + SizeOf(TMappedSlabBlockHeader));
end;

procedure TMappedSlabAllocator.FreeBlock(aPtr: Pointer);
var
  LHeader: PMappedSlabHeader;
  LPayloadOffset: UInt64;
  LBlockOffset: UInt64;
  LPageIndex: UInt32;
  LPageStart: UInt64;
  LWithinPage: UInt64;
  LBlockStride: UInt32;
  LPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
begin
  if aPtr = nil then Exit;
  if not IsValid then
    raise EAllocError.Create(aePoolClosed, 'TMappedSlabAllocator.FreeBlock: pool is not valid');

  LHeader := PMappedSlabHeader(FHeader);
  if (not PointerToDataOffset(aPtr, LPayloadOffset)) or
     (LPayloadOffset < SizeOf(TMappedSlabBlockHeader)) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: pointer is not from this pool');

  LBlockOffset := LPayloadOffset - SizeOf(TMappedSlabBlockHeader);
  LPageIndex := LBlockOffset div FPageSize;
  if LPageIndex >= LHeader^.TotalPages then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: page index out of range');

  LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
  if (LPage^.BlockSize = 0) or (LPage^.Generation <> LHeader^.ResetGeneration) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: stale or unowned pointer');

  LPageStart := UInt64(LPageIndex) * UInt64(FPageSize);
  LBlockStride := LPage^.BlockSize + SizeOf(TMappedSlabBlockHeader);
  LWithinPage := LBlockOffset - LPageStart;
  if (LBlockStride = 0) or (LWithinPage mod LBlockStride <> 0) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: pointer is not a block payload');

  LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
  if (LBlock^.Magic <> BLOCK_MAGIC) or
     (LBlock^.PageIndex <> LPageIndex) or
     (LBlock^.BlockSize <> LPage^.BlockSize) or
     (LBlock^.Generation <> LPage^.Generation) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: invalid block header');

  if LBlock^.State = BLOCK_STATE_FREE then
    raise EAllocError.Create(aeDoubleFree, 'TMappedSlabAllocator.FreeBlock: double free detected');
  if LBlock^.State <> BLOCK_STATE_USED then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabAllocator.FreeBlock: invalid block state');

  LBlock^.State := BLOCK_STATE_FREE;
  LBlock^.NextFreeOffset := LPage^.FreeHeadOffset;
  LPage^.FreeHeadOffset := LBlockOffset;
  Inc(LPage^.FreeCount);
  if LPage^.AllocatedCount > 0 then
    Dec(LPage^.AllocatedCount);
  Inc(LHeader^.TotalFrees);
end;

procedure TMappedSlabAllocator.GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
  out aUsedPages, aTotalPages: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  if IsValid then
  begin
    LHeader := PMappedSlabHeader(FHeader);
    aTotalAllocs := LHeader^.TotalAllocs;
    aTotalFrees := LHeader^.TotalFrees;
    aFailedAllocs := LHeader^.FailedAllocs;
    aUsedPages := LHeader^.UsedPages;
    aTotalPages := LHeader^.TotalPages;
  end
  else
  begin
    aTotalAllocs := 0;
    aTotalFrees := 0;
    aFailedAllocs := 0;
    aUsedPages := 0;
    aTotalPages := 0;
  end;
end;

procedure TMappedSlabAllocator.Reset;
var
  LHeader: PMappedSlabHeader;
  LPageDescriptorSize: UInt64;
begin
  if not IsValid then Exit;

  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.UsedPages := 0;
  LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0;
  LHeader^.FailedAllocs := 0;
  Inc(LHeader^.ResetGeneration);
  if LHeader^.ResetGeneration = 0 then
    LHeader^.ResetGeneration := 1;

  if FPages <> nil then
  begin
    LPageDescriptorSize := UInt64(LHeader^.TotalPages) * SizeOf(TMappedSlabPage);
    FillChar(FPages^, LPageDescriptorSize, 0);
  end;
end;

function TMappedSlabAllocator.IsValid: Boolean;
begin
  Result := (FHeader <> nil) and (FDataArea <> nil) and
            (FPoolSize > 0) and (FMemoryMap <> nil);
end;

end.
