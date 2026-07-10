{
    nextpas.core.mem.allocator.freelist
    -----------------------------------
    General-purpose freelist allocator.

    Maintains freelists for different size classes. When memory is
    freed, the block is placed on the appropriate freelist. When
    memory is requested, the freelist is checked first.

    Unlike TRecyclingAllocator, this stores the exact size in a
    header, enabling proper freelist binning on free.
}

unit nextpas.core.mem.allocator.freelist;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  FREELIST_BINS = 16;
  FREELIST_HEADER_SIZE = SizeOf(SizeUInt);

type
  TFreelistStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    HitCount: UInt64;
    MissCount: UInt64;
    TotalBytes: UInt64;
  end;

  TFreelistAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FBins: array[0..FREELIST_BINS - 1] of Pointer;
    FBinSizes: array[0..FREELIST_BINS - 1] of SizeUInt;
    FStats: TFreelistStats;
    procedure InitBins;
    function FindBin(ASize: SizeUInt): Integer;
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    procedure Drain;
    function GetStats: TFreelistStats;
  end;

implementation

uses
  nextpas.core.base;

{ TFreelistAllocator }

constructor TFreelistAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FillChar(FStats, SizeOf(FStats), 0);
  InitBins;
end;

destructor TFreelistAllocator.Destroy;
begin
  Drain;
  inherited Destroy;
end;

procedure TFreelistAllocator.InitBins;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FREELIST_BINS - 1 do
  begin
    FBins[LIdx] := nil;
    FBinSizes[LIdx] := 8 shl LIdx; // 8, 16, 32, 64, ..., 262144
  end;
end;

function TFreelistAllocator.FindBin(ASize: SizeUInt): Integer;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FREELIST_BINS - 1 do
    if ASize <= FBinSizes[LIdx] then
      Exit(LIdx);
  Result := -1;
end;

function TFreelistAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LBin: Integer;
  LTotal: SizeUInt;
  LHeader: PSizeUInt;
begin
  if ASize = 0 then
    Exit(nil);
  LBin := FindBin(ASize);
  if (LBin >= 0) and (FBins[LBin] <> nil) then
  begin
    // Freelist hit
    LHeader := PSizeUInt(FBins[LBin]);
    FBins[LBin] := PPointer(LHeader)^;
    LHeader^ := ASize; // restore size (freelist overwrote it with next ptr)
    Inc(FStats.HitCount);
    Exit(Pointer(PByte(LHeader) + FREELIST_HEADER_SIZE));
  end;

  // Freelist miss
  if LBin >= 0 then
    LTotal := FBinSizes[LBin] + FREELIST_HEADER_SIZE
  else
    LTotal := ASize + FREELIST_HEADER_SIZE;

  LHeader := PSizeUInt(FInner.GetMem(LTotal));
  if LHeader = nil then
    Exit(nil);

  LHeader^ := ASize;
  Inc(FStats.MissCount);
  Inc(FStats.AllocCount);
  Inc(FStats.TotalBytes, ASize);
  Result := Pointer(PByte(LHeader) + FREELIST_HEADER_SIZE);
end;

function TFreelistAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TFreelistAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  LOldSize := PSizeUInt(PByte(APtr) - FREELIST_HEADER_SIZE)^;
  if ASize <= LOldSize then
    Exit(APtr);

  Result := GetMem(ASize);
  if Result <> nil then
  begin
    Move(APtr^, Result^, LOldSize);
    FreeMem(APtr);
  end;
end;

procedure TFreelistAllocator.FreeMem(APtr: Pointer); inline;
var
  LHeader: PSizeUInt;
  LOldSize: SizeUInt;
  LBin: Integer;
begin
  if APtr = nil then
    Exit;

  LHeader := PSizeUInt(PByte(APtr) - FREELIST_HEADER_SIZE);
  LOldSize := LHeader^;
  LBin := FindBin(LOldSize);

  if LBin >= 0 then
  begin
    PPointer(LHeader)^ := FBins[LBin];
    FBins[LBin] := LHeader;
  end
  else
    FInner.FreeMem(LHeader);

  Inc(FStats.FreeCount);
end;

function TFreelistAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := True;
end;

procedure TFreelistAllocator.Drain;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  for LIdx := 0 to FREELIST_BINS - 1 do
  begin
    while FBins[LIdx] <> nil do
    begin
      LPtr := FBins[LIdx];
      FBins[LIdx] := PPointer(LPtr)^;
      FInner.FreeMem(LPtr);
    end;
  end;
end;

function TFreelistAllocator.GetStats: TFreelistStats;
begin
  Result := FStats;
end;

end.
