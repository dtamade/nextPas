unit np_allocator;

{$mode objfpc}{$H+}
{$UNITPATH ../base}

interface

uses
  SysUtils, np_base_types;

type
  TCoreAllocator = class abstract
  public
    function TryAllocate(
      const ASize: NativeUInt;
      const AAlignment: NativeUInt;
      out APtr: Pointer
    ): TCoreResult; virtual; abstract;
    procedure Reset; virtual; abstract;
  end;

  TBumpArenaBlock = record
    Memory: Pointer;
    Capacity: NativeUInt;
    Used: NativeUInt;
  end;

  TBumpArena = class(TCoreAllocator)
  private
    FBlocks: array of TBumpArenaBlock;
    FInitialBlockSize: NativeUInt;
    FReservedBytes: QWord;
    FCommittedBytes: QWord;
    function LastBlockIndex: LongInt;
    function ReserveBlock(const ACapacity: NativeUInt): TCoreResult;
  public
    constructor Create(const AInitialBlockSize: NativeUInt = 4096);
    destructor Destroy; override;
    function TryAllocate(
      const ASize: NativeUInt;
      const AAlignment: NativeUInt;
      out APtr: Pointer
    ): TCoreResult; override;
    function AllocateOrNil(
      const ASize: NativeUInt;
      const AAlignment: NativeUInt = SizeOf(Pointer)
    ): Pointer;
    procedure Reset; override;
    function BlockCount: LongInt;
    function ReservedBytes: QWord;
    function CommittedBytes: QWord;
  end;

implementation

function MaxUInt(const ALeft: NativeUInt; const ARight: NativeUInt): NativeUInt;
begin
  if ALeft >= ARight then
    Result := ALeft
  else
    Result := ARight;
end;

function IsPowerOfTwo(const AValue: NativeUInt): Boolean;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function AlignUp(const AValue: PtrUInt; const AAlignment: NativeUInt): PtrUInt;
begin
  Result := (AValue + PtrUInt(AAlignment - 1)) and not PtrUInt(AAlignment - 1);
end;

constructor TBumpArena.Create(const AInitialBlockSize: NativeUInt);
begin
  inherited Create;
  if AInitialBlockSize = 0 then
    FInitialBlockSize := 4096
  else
    FInitialBlockSize := AInitialBlockSize;
  SetLength(FBlocks, 0);
  FReservedBytes := 0;
  FCommittedBytes := 0;
end;

destructor TBumpArena.Destroy;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FBlocks) - 1 do
    if FBlocks[Index].Memory <> nil then
      FreeMem(FBlocks[Index].Memory);
  inherited Destroy;
end;

function TBumpArena.LastBlockIndex: LongInt;
begin
  if Length(FBlocks) = 0 then
    Exit(-1);

  Result := High(FBlocks);
end;

function TBumpArena.ReserveBlock(const ACapacity: NativeUInt): TCoreResult;
var
  BlockIndex: SizeInt;
  BlockMemory: Pointer;
begin
  try
    GetMem(BlockMemory, ACapacity);
  except
    on EOutOfMemory do
      Exit(BuildCoreResult(crcOutOfMemory, 'arena block allocation failed'));
  end;

  BlockIndex := Length(FBlocks);
  SetLength(FBlocks, BlockIndex + 1);
  FBlocks[BlockIndex].Memory := BlockMemory;
  FBlocks[BlockIndex].Capacity := ACapacity;
  FBlocks[BlockIndex].Used := 0;
  FReservedBytes := FReservedBytes + ACapacity;
  Result := BuildCoreOkResult;
end;

function TBumpArena.TryAllocate(
  const ASize: NativeUInt;
  const AAlignment: NativeUInt;
  out APtr: Pointer
): TCoreResult;
var
  BlockIndex: LongInt;
  RawAddress: PtrUInt;
  AlignedAddress: PtrUInt;
  Padding: NativeUInt;
  RequiredCapacity: NativeUInt;
begin
  APtr := nil;

  if ASize = 0 then
    Exit(BuildCoreResult(crcInvalidArgument, 'allocation size must be greater than zero'));

  if not IsPowerOfTwo(AAlignment) then
    Exit(BuildCoreResult(crcInvalidArgument, 'alignment must be a non-zero power of two'));

  RequiredCapacity := ASize + AAlignment - 1;
  BlockIndex := LastBlockIndex;
  if BlockIndex < 0 then
  begin
    Result := ReserveBlock(MaxUInt(FInitialBlockSize, RequiredCapacity));
    if not CoreResultIsOk(Result) then
      Exit;
    BlockIndex := LastBlockIndex;
  end;

  RawAddress := PtrUInt(FBlocks[BlockIndex].Memory) + PtrUInt(FBlocks[BlockIndex].Used);
  AlignedAddress := AlignUp(RawAddress, AAlignment);
  Padding := AlignedAddress - RawAddress;

  if FBlocks[BlockIndex].Used + Padding + ASize > FBlocks[BlockIndex].Capacity then
  begin
    Result := ReserveBlock(MaxUInt(FInitialBlockSize, RequiredCapacity));
    if not CoreResultIsOk(Result) then
      Exit;
    BlockIndex := LastBlockIndex;
    RawAddress := PtrUInt(FBlocks[BlockIndex].Memory) + PtrUInt(FBlocks[BlockIndex].Used);
    AlignedAddress := AlignUp(RawAddress, AAlignment);
    Padding := AlignedAddress - RawAddress;
  end;

  FBlocks[BlockIndex].Used := FBlocks[BlockIndex].Used + Padding + ASize;
  FCommittedBytes := FCommittedBytes + Padding + ASize;
  APtr := Pointer(AlignedAddress);
  Result := BuildCoreOkResult;
end;

function TBumpArena.AllocateOrNil(
  const ASize: NativeUInt;
  const AAlignment: NativeUInt
): Pointer;
var
  AllocationResult: TCoreResult;
begin
  AllocationResult := TryAllocate(ASize, AAlignment, Result);
  if not CoreResultIsOk(AllocationResult) then
    Result := nil;
end;

procedure TBumpArena.Reset;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FBlocks) - 1 do
    FBlocks[Index].Used := 0;
  FCommittedBytes := 0;
end;

function TBumpArena.BlockCount: LongInt;
begin
  Result := Length(FBlocks);
end;

function TBumpArena.ReservedBytes: QWord;
begin
  Result := FReservedBytes;
end;

function TBumpArena.CommittedBytes: QWord;
begin
  Result := FCommittedBytes;
end;

end.
