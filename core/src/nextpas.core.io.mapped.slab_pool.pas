unit nextpas.core.io.mapped.slab_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.memory_map;

type
  TMappedSlabCreateMode = (
    mscFile,
    mscShared
  );

  {**
   * TMappedSlabPool — file-backed or shared-memory slab pool
   *
   * For ephemeral / anonymous slab allocation, use
   * TMappedSlabAllocator from nextpas.core.mem.mapped_slab_pool.
   *}
  TMappedSlabPool = class
  private
    FMemoryMap: TMemoryMap;
    FSharedMemory: TSharedMemory;
    FIsFile: Boolean;
    FIsCreator: Boolean;

    FHeader: Pointer;
    FPoolSize: UInt64;
    FPageSize: UInt32;
    FMaxSizeClass: UInt32;
    FPages: Pointer;
    FDataArea: Pointer;

    function GetPageDescriptor(aPageIndex: UInt32): Pointer;
    function DataOffsetToPointer(aOffset: UInt64): Pointer;
    function PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
    function PageUsableSize(aPageIndex: UInt32): UInt32;
    function CalculateRequiredSize(aPoolSize: UInt64): UInt64;
    procedure InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
    function ValidateHeader: Boolean;
    procedure InitializeSlabStructures;

  public
    constructor Create;
    destructor Destroy; override;

    function CreateFile(const aFileName: string; aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048): Boolean;
    function OpenFile(const aFileName: string): Boolean;
    function CreateShared(const aName: string; aPoolSize: UInt64;
      aPageSize: UInt32 = 4096; aMaxSizeClass: UInt32 = 2048): Boolean;
    function OpenShared(const aName: string): Boolean;

    procedure Close;

    function Alloc(aSize: UInt64): Pointer;
    procedure FreeBlock(aPtr: Pointer);

    procedure GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
      out aUsedPages, aTotalPages: UInt32);
    procedure Reset;
    function IsValid: Boolean;

    property PoolSize: UInt64 read FPoolSize;
    property PageSize: UInt32 read FPageSize;
    property MaxSizeClass: UInt32 read FMaxSizeClass;
    property IsCreator: Boolean read FIsCreator;
  end;

implementation

uses
  SysUtils,
  nextpas.core.mem.error,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

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

{ TMappedSlabPool }

constructor TMappedSlabPool.Create;
begin
  inherited Create;
  FMemoryMap := nil;
  FSharedMemory := nil;
  FIsFile := False;
  FIsCreator := False;
  FHeader := nil;
  FPoolSize := 0;
  FPageSize := 4096;
  FMaxSizeClass := 2048;
  FPages := nil;
  FDataArea := nil;
end;

destructor TMappedSlabPool.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMappedSlabPool.GetPageDescriptor(aPageIndex: UInt32): Pointer;
begin
  Result := Pointer(PByte(FPages) + SizeUInt(aPageIndex) * SizeOf(TMappedSlabPage));
end;

function TMappedSlabPool.DataOffsetToPointer(aOffset: UInt64): Pointer;
begin
  Result := Pointer(PByte(FDataArea) + SizeUInt(aOffset));
end;

function TMappedSlabPool.PointerToDataOffset(aPtr: Pointer; out aOffset: UInt64): Boolean;
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

function TMappedSlabPool.PageUsableSize(aPageIndex: UInt32): UInt32;
var
  LPageStart: UInt64;
  LRemaining: UInt64;
begin
  LPageStart := UInt64(aPageIndex) * UInt64(FPageSize);
  if LPageStart >= FPoolSize then Exit(0);
  LRemaining := FPoolSize - LPageStart;
  if LRemaining > FPageSize then Result := FPageSize else Result := UInt32(LRemaining);
end;

function TMappedSlabPool.CalculateRequiredSize(aPoolSize: UInt64): UInt64;
var
  LPageCount, LPageDescriptorSize: UInt64;
begin
  LPageCount := (aPoolSize + FPageSize - 1) div FPageSize;
  LPageDescriptorSize := LPageCount * SizeOf(TMappedSlabPage);
  Result := HEADER_SIZE + LPageDescriptorSize + aPoolSize;
  Result := ((Result + FPageSize - 1) div FPageSize) * FPageSize;
end;

procedure TMappedSlabPool.InitializeHeader(aPoolSize: UInt64; aPageSize: UInt32; aMaxSizeClass: UInt32);
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

function TMappedSlabPool.ValidateHeader: Boolean;
var
  LHeader: PMappedSlabHeader;
begin
  Result := False;
  if FHeader = nil then Exit;
  LHeader := PMappedSlabHeader(FHeader);
  if (LHeader^.Magic <> SLAB_MAGIC) or (LHeader^.Version <> SLAB_VERSION) then Exit;
  FPoolSize := LHeader^.PoolSize;
  FPageSize := LHeader^.PageSize;
  FMaxSizeClass := LHeader^.MaxSizeClass;
  Result := True;
end;

procedure TMappedSlabPool.InitializeSlabStructures;
var
  LPageCount, LPageDescriptorSize: UInt64;
begin
  LPageCount := (FPoolSize + FPageSize - 1) div FPageSize;
  LPageDescriptorSize := LPageCount * SizeOf(TMappedSlabPage);
  FPages := Pointer(PByte(FHeader) + HEADER_SIZE);
  FDataArea := Pointer(PByte(FPages) + LPageDescriptorSize);
  if FIsCreator then
    FillChar(FPages^, LPageDescriptorSize, 0);
end;

function TMappedSlabPool.CreateFile(const aFileName: string; aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
  LFileHandle: TPlatformFileHandle;
  LStat: TPlatformFileStat;
begin
  Result := False;
  Close;
  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);
  FMemoryMap := TMemoryMap.Create;
  try
    if platform_file_stat(PAnsiChar(aFileName), LStat) = 0 then
    begin
      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;
      FIsCreator := False;
    end
    else
    begin
      if platform_file_open(PAnsiChar(aFileName), fomReadWrite, fcmCreateAlways, LFileHandle) <> 0 then Exit;
      platform_file_truncate(LFileHandle, LRequiredSize);
      platform_file_close(LFileHandle);
      if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;
      FIsCreator := True;
    end;
    FIsFile := True;
    FHeader := FMemoryMap.BaseAddress;
    if FIsCreator then
      InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass)
    else if not ValidateHeader then Exit;
    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;

function TMappedSlabPool.OpenFile(const aFileName: string): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := False;
  Close;
  if platform_file_stat(PAnsiChar(aFileName), LStat) <> 0 then Exit;
  FMemoryMap := TMemoryMap.Create;
  try
    if not FMemoryMap.OpenFile(aFileName, mmaReadWrite) then Exit;
    FIsFile := True;
    FIsCreator := False;
    FHeader := FMemoryMap.BaseAddress;
    if not ValidateHeader then Exit;
    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FMemoryMap);
  end;
end;

function TMappedSlabPool.CreateShared(const aName: string; aPoolSize: UInt64;
  aPageSize: UInt32; aMaxSizeClass: UInt32): Boolean;
var
  LRequiredSize: UInt64;
begin
  Result := False;
  Close;
  FPageSize := aPageSize;
  FMaxSizeClass := aMaxSizeClass;
  LRequiredSize := CalculateRequiredSize(aPoolSize);
  FSharedMemory := TSharedMemory.Create;
  try
    if FSharedMemory.CreateShared(aName, LRequiredSize, mmaReadWrite) then
      FIsCreator := FSharedMemory.IsCreator
    else if not FSharedMemory.OpenShared(aName, mmaReadWrite) then Exit
    else FIsCreator := False;
    FIsFile := False;
    FHeader := FSharedMemory.BaseAddress;
    if FIsCreator then
      InitializeHeader(aPoolSize, aPageSize, aMaxSizeClass)
    else if not ValidateHeader then Exit;
    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;

function TMappedSlabPool.OpenShared(const aName: string): Boolean;
begin
  Result := False;
  Close;
  FSharedMemory := TSharedMemory.Create;
  try
    if not FSharedMemory.OpenShared(aName, mmaReadWrite) then Exit;
    FIsFile := False;
    FIsCreator := False;
    FHeader := FSharedMemory.BaseAddress;
    if not ValidateHeader then Exit;
    InitializeSlabStructures;
    Result := True;
  except
    FreeAndNil(FSharedMemory);
  end;
end;

procedure TMappedSlabPool.Close;
begin
  FHeader := nil;
  FPages := nil;
  FDataArea := nil;
  FPoolSize := 0;
  FIsCreator := False;
  if Assigned(FMemoryMap) then
    FreeAndNil(FMemoryMap);
  if Assigned(FSharedMemory) then
    FreeAndNil(FSharedMemory);
end;

function TMappedSlabPool.Alloc(aSize: UInt64): Pointer;
var
  LHeader: PMappedSlabHeader;
  LBlockSize, LBlockBytes, LPageIndex, LChosenPageIndex, LPageUsable: UInt32;
  LPage, LChosenPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
  LBlockOffset, LPageStart: UInt64;
  LFound: Boolean;
begin
  Result := nil;
  if not IsValid then Exit;
  LHeader := PMappedSlabHeader(FHeader);
  if (aSize = 0) or (aSize > FMaxSizeClass) or
     (aSize > UInt64(High(UInt32)) - SizeOf(TMappedSlabBlockHeader) - 7) then
  begin
    Inc(LHeader^.FailedAllocs); Exit;
  end;
  LBlockSize := UInt32((aSize + 7) and not UInt64(7));
  LBlockBytes := LBlockSize + SizeOf(TMappedSlabBlockHeader);
  LFound := False; LChosenPage := nil; LChosenPageIndex := 0;
  for LPageIndex := 0 to LHeader^.TotalPages - 1 do
  begin
    LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
    LPageUsable := PageUsableSize(LPageIndex);
    if (LPage^.BlockSize = LBlockSize) and
       ((LPage^.FreeHeadOffset <> NO_FREE_OFFSET) or
        (UInt64(LPage^.BumpOffset) + LBlockBytes <= LPageUsable)) then
    begin LChosenPage := LPage; LChosenPageIndex := LPageIndex; LFound := True; Break; end;
    if (not LFound) and (LChosenPage = nil) and (LPage^.BlockSize = 0) and
       (LBlockBytes <= LPageUsable) then
    begin LChosenPage := LPage; LChosenPageIndex := LPageIndex; end;
  end;
  if LChosenPage = nil then begin Inc(LHeader^.FailedAllocs); Exit; end;
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
    if (LBlock^.Magic <> BLOCK_MAGIC) or (LBlock^.PageIndex <> LChosenPageIndex) or
       (LBlock^.BlockSize <> LBlockSize) or (LBlock^.State <> BLOCK_STATE_FREE) or
       (LBlock^.Generation <> LChosenPage^.Generation) then
    begin Inc(LHeader^.FailedAllocs); Exit; end;
    LChosenPage^.FreeHeadOffset := LBlock^.NextFreeOffset;
    Dec(LChosenPage^.FreeCount);
  end
  else
  begin
    LPageUsable := PageUsableSize(LChosenPageIndex);
    if UInt64(LChosenPage^.BumpOffset) + LBlockBytes > LPageUsable then
    begin Inc(LHeader^.FailedAllocs); Exit; end;
    LPageStart := UInt64(LChosenPageIndex) * UInt64(FPageSize);
    LBlockOffset := LPageStart + LChosenPage^.BumpOffset;
    LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
    Inc(LChosenPage^.BumpOffset, LBlockBytes);
  end;
  LBlock^.Magic := BLOCK_MAGIC; LBlock^.PageIndex := LChosenPageIndex;
  LBlock^.BlockSize := LBlockSize; LBlock^.RequestedSize := UInt32(aSize);
  LBlock^.State := BLOCK_STATE_USED; LBlock^.Generation := LChosenPage^.Generation;
  LBlock^.NextFreeOffset := NO_FREE_OFFSET;
  Inc(LChosenPage^.AllocatedCount); Inc(LHeader^.TotalAllocs);
  Result := Pointer(PByte(LBlock) + SizeOf(TMappedSlabBlockHeader));
end;

procedure TMappedSlabPool.FreeBlock(aPtr: Pointer);
var
  LHeader: PMappedSlabHeader;
  LPayloadOffset, LBlockOffset, LPageStart: UInt64;
  LPageIndex: UInt32;
  LWithinPage, LBlockStride: UInt64;
  LPage: PMappedSlabPage;
  LBlock: PMappedSlabBlockHeader;
begin
  if aPtr = nil then Exit;
  if not IsValid then
    raise EAllocError.Create(aePoolClosed, 'TMappedSlabPool.FreeBlock: pool is not valid');
  LHeader := PMappedSlabHeader(FHeader);
  if (not PointerToDataOffset(aPtr, LPayloadOffset)) or
     (LPayloadOffset < SizeOf(TMappedSlabBlockHeader)) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: pointer is not from this pool');
  LBlockOffset := LPayloadOffset - SizeOf(TMappedSlabBlockHeader);
  LPageIndex := LBlockOffset div FPageSize;
  if LPageIndex >= LHeader^.TotalPages then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: page index out of range');
  LPage := PMappedSlabPage(GetPageDescriptor(LPageIndex));
  if (LPage^.BlockSize = 0) or (LPage^.Generation <> LHeader^.ResetGeneration) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: stale or unowned pointer');
  LPageStart := UInt64(LPageIndex) * UInt64(FPageSize);
  LBlockStride := LPage^.BlockSize + SizeOf(TMappedSlabBlockHeader);
  LWithinPage := LBlockOffset - LPageStart;
  if (LBlockStride = 0) or (LWithinPage mod LBlockStride <> 0) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: pointer is not a block payload');
  LBlock := PMappedSlabBlockHeader(DataOffsetToPointer(LBlockOffset));
  if (LBlock^.Magic <> BLOCK_MAGIC) or (LBlock^.PageIndex <> LPageIndex) or
     (LBlock^.BlockSize <> LPage^.BlockSize) or (LBlock^.Generation <> LPage^.Generation) then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: invalid block header');
  if LBlock^.State = BLOCK_STATE_FREE then
    raise EAllocError.Create(aeDoubleFree, 'TMappedSlabPool.FreeBlock: double free detected');
  if LBlock^.State <> BLOCK_STATE_USED then
    raise EAllocError.Create(aeInvalidPointer, 'TMappedSlabPool.FreeBlock: invalid block state');
  LBlock^.State := BLOCK_STATE_FREE; LBlock^.NextFreeOffset := LPage^.FreeHeadOffset;
  LPage^.FreeHeadOffset := LBlockOffset; Inc(LPage^.FreeCount);
  if LPage^.AllocatedCount > 0 then Dec(LPage^.AllocatedCount);
  Inc(LHeader^.TotalFrees);
end;

procedure TMappedSlabPool.GetStats(out aTotalAllocs, aTotalFrees, aFailedAllocs: UInt64;
  out aUsedPages, aTotalPages: UInt32);
var
  LHeader: PMappedSlabHeader;
begin
  if IsValid then
  begin
    LHeader := PMappedSlabHeader(FHeader);
    aTotalAllocs := LHeader^.TotalAllocs; aTotalFrees := LHeader^.TotalFrees;
    aFailedAllocs := LHeader^.FailedAllocs;
    aUsedPages := LHeader^.UsedPages; aTotalPages := LHeader^.TotalPages;
  end
  else begin aTotalAllocs := 0; aTotalFrees := 0; aFailedAllocs := 0;
    aUsedPages := 0; aTotalPages := 0; end;
end;

procedure TMappedSlabPool.Reset;
var
  LHeader: PMappedSlabHeader;
  LPageDescriptorSize: UInt64;
begin
  if not IsValid then Exit;
  LHeader := PMappedSlabHeader(FHeader);
  LHeader^.UsedPages := 0; LHeader^.TotalAllocs := 0;
  LHeader^.TotalFrees := 0; LHeader^.FailedAllocs := 0;
  Inc(LHeader^.ResetGeneration);
  if LHeader^.ResetGeneration = 0 then LHeader^.ResetGeneration := 1;
  if FPages <> nil then
  begin
    LPageDescriptorSize := UInt64(LHeader^.TotalPages) * SizeOf(TMappedSlabPage);
    FillChar(FPages^, LPageDescriptorSize, 0);
  end;
end;

function TMappedSlabPool.IsValid: Boolean;
begin
  Result := (FHeader <> nil) and (FDataArea <> nil) and (FPoolSize > 0) and
            ((FMemoryMap <> nil) or (FSharedMemory <> nil));
end;

end.
