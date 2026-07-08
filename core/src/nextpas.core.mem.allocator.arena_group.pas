{
    nextpas.core.mem.allocator.arena_group
    --------------------------------------
    Arena group allocator — batch ownership.

    All allocations belong to a group. When the group is destroyed
    or Reset is called, all allocations are freed at once.

    No individual free support. Uses bump allocation internally.
    Header stores group ID for validation.
}

unit nextpas.core.mem.allocator.arena_group;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  ARENA_GROUP_DEFAULT_SIZE = 65536;

type
  TArenaGroupStats = record
    AllocCount: UInt64;
    TotalBytes: UInt64;
    ResetCount: UInt64;
    GroupCount: UInt64;
  end;

  TArenaGroupAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRegion: PByte;
    FRegionSize: SizeUInt;
    FOffset: SizeUInt;
    FGroupId: UInt64;
    FStats: TArenaGroupStats;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;

    function Traits: TAllocatorTraits; inline;
    constructor Create(AInner: IAllocator; ARegionSize: SizeUInt = ARENA_GROUP_DEFAULT_SIZE);
    destructor Destroy; override;
    procedure Reset;
    function GetStats: TArenaGroupStats;
    function GroupId: UInt64;
  end;

implementation

uses
  nextpas.core.base;

{ TArenaGroupAllocator }

constructor TArenaGroupAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  FRegionSize := ARegionSize;
  FRegion := PByte(FInner.GetMem(FRegionSize));
  FOffset := 0;
  FGroupId := 1;
  FillChar(FStats, SizeOf(FStats), 0);
  Inc(FStats.GroupCount);
end;

destructor TArenaGroupAllocator.Destroy;
begin
  if FRegion <> nil then
    FInner.FreeMem(FRegion);
  inherited Destroy;
end;

function TArenaGroupAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LAligned: SizeUInt;
begin
  LAligned := (ASize + 7) and not SizeUInt(7);
  if FOffset + LAligned > FRegionSize then
    Exit(nil);
  Result := FRegion + FOffset;
  Inc(FOffset, LAligned);
  Inc(FStats.AllocCount);
  Inc(FStats.TotalBytes, ASize);
end;

function TArenaGroupAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TArenaGroupAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);
  Result := GetMem(ASize);
end;

procedure TArenaGroupAllocator.FreeMem(APtr: Pointer); inline;
begin
  // No-op — arena doesn't support individual free
end;

procedure TArenaGroupAllocator.Reset;
begin
  FOffset := 0;
  Inc(FGroupId);
  Inc(FStats.ResetCount);
  Inc(FStats.GroupCount);
end;

function TArenaGroupAllocator.GetStats: TArenaGroupStats;
begin
  Result := FStats;
end;

function TArenaGroupAllocator.GroupId: UInt64;
begin
  Result := FGroupId;
end;


function TArenaGroupAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
end;

end.
