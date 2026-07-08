{
    nextpas.core.mem.allocator.group
    --------------------------------
    Group allocator — batch ownership.

    All allocations belong to a group. When the group is destroyed
    or Reset is called, all allocations are freed at once.

    No individual free support. Uses bump allocation internally.
    Multiple groups can be created with different IDs.
}

unit nextpas.core.mem.allocator.group;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  GROUP_DEFAULT_SIZE = 65536;
  GROUP_MAX_GROUPS = 16;

type
  TGroupStats = record
    AllocCount: UInt64;
    TotalBytes: UInt64;
    ResetCount: UInt64;
    GroupCount: UInt64;
  end;

  TGroupAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRegions: array[0..GROUP_MAX_GROUPS - 1] of PByte;
    FSizes: array[0..GROUP_MAX_GROUPS - 1] of SizeUInt;
    FOffsets: array[0..GROUP_MAX_GROUPS - 1] of SizeUInt;
    FRegionCount: Integer;
    FActiveGroup: Integer;
    FGroupSize: SizeUInt;
    FStats: TGroupStats;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;

    function Traits: TAllocatorTraits; inline;
    constructor Create(AInner: IAllocator; AGroupSize: SizeUInt = GROUP_DEFAULT_SIZE);
    destructor Destroy; override;
    function CreateGroup: Integer;
    procedure SetActiveGroup(AIndex: Integer);
    procedure ResetGroup(AIndex: Integer);
    procedure ResetAll;
    function GetStats: TGroupStats;
    function ActiveGroup: Integer;
    function GroupCount: Integer;
  end;

implementation

uses
  nextpas.core.base;

{ TGroupAllocator }

constructor TGroupAllocator.Create(AInner: IAllocator; AGroupSize: SizeUInt);
var
  LIdx: Integer;
begin
  inherited Create;
  FInner := AInner;
  FGroupSize := AGroupSize;
  FRegionCount := 0;
  FActiveGroup := -1;
  FillChar(FStats, SizeOf(FStats), 0);

  for LIdx := 0 to GROUP_MAX_GROUPS - 1 do
  begin
    FRegions[LIdx] := nil;
    FSizes[LIdx] := 0;
    FOffsets[LIdx] := 0;
  end;

  // Create first group
  CreateGroup;
end;

destructor TGroupAllocator.Destroy;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FRegionCount - 1 do
    if FRegions[LIdx] <> nil then
      FInner.FreeMem(FRegions[LIdx]);
  inherited Destroy;
end;

function TGroupAllocator.CreateGroup: Integer;
begin
  if FRegionCount >= GROUP_MAX_GROUPS then
    Exit(-1);

  FRegions[FRegionCount] := PByte(FInner.GetMem(FGroupSize));
  if FRegions[FRegionCount] = nil then
    Exit(-1);

  FSizes[FRegionCount] := FGroupSize;
  FOffsets[FRegionCount] := 0;
  FActiveGroup := FRegionCount;
  Inc(FRegionCount);
  Inc(FStats.GroupCount);
  Result := FActiveGroup;
end;

procedure TGroupAllocator.SetActiveGroup(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FRegionCount) then
    FActiveGroup := AIndex;
end;

function TGroupAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LAligned: SizeUInt;
begin
  if FActiveGroup < 0 then
    Exit(nil);

  LAligned := (ASize + 7) and not SizeUInt(7);
  if FOffsets[FActiveGroup] + LAligned > FSizes[FActiveGroup] then
    Exit(nil);

  Result := FRegions[FActiveGroup] + FOffsets[FActiveGroup];
  Inc(FOffsets[FActiveGroup], LAligned);
  Inc(FStats.AllocCount);
  Inc(FStats.TotalBytes, ASize);
end;

function TGroupAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TGroupAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);
  Result := GetMem(ASize);
end;

procedure TGroupAllocator.FreeMem(APtr: Pointer); inline;
begin
  // No-op — group doesn't support individual free
end;

procedure TGroupAllocator.ResetGroup(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FRegionCount) then
  begin
    FOffsets[AIndex] := 0;
    Inc(FStats.ResetCount);
  end;
end;

procedure TGroupAllocator.ResetAll;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FRegionCount - 1 do
    FOffsets[LIdx] := 0;
  Inc(FStats.ResetCount);
end;

function TGroupAllocator.GetStats: TGroupStats;
begin
  Result := FStats;
end;

function TGroupAllocator.ActiveGroup: Integer;
begin
  Result := FActiveGroup;
end;

function TGroupAllocator.GroupCount: Integer;
begin
  Result := FRegionCount;
end;


function TGroupAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
end;

end.
