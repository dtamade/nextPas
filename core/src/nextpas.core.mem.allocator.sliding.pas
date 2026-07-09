{
    nextpas.core.mem.allocator.sliding
    ----------------------------------
    Sliding allocator — LIFO stack-based allocation.

    Allocates from a pre-allocated region. Supports pushing
    checkpoints and popping back to them. All allocations after
    a checkpoint are invalidated on pop.

    Extremely fast for scoped allocations (parsing, request handling).
}

unit nextpas.core.mem.allocator.sliding;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  SLIDING_DEFAULT_SIZE = 65536;
  SLIDING_MAX_MARKS = 32;

type
  TSlidingStats = record
    AllocCount: UInt64;
    TotalBytes: UInt64;
    PushCount: UInt64;
    PopCount: UInt64;
  end;

  TSlidingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRegion: PByte;
    FRegionSize: SizeUInt;
    FOffset: SizeUInt;
    FMarks: array[0..SLIDING_MAX_MARKS - 1] of SizeUInt;
    FMarkCount: Integer;
    FStats: TSlidingStats;
  public
    constructor Create(AInner: IAllocator; ARegionSize: SizeUInt = SLIDING_DEFAULT_SIZE);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    function Push: Boolean;
    procedure Pop;
    function GetStats: TSlidingStats;
  end;

implementation

uses
  nextpas.core.base;

{ TSlidingAllocator }

constructor TSlidingAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  FRegionSize := ARegionSize;
  FRegion := PByte(FInner.GetMem(FRegionSize));
  FOffset := 0;
  FMarkCount := 0;
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TSlidingAllocator.Destroy;
begin
  if FRegion <> nil then
    FInner.FreeMem(FRegion);
  inherited Destroy;
end;

function TSlidingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
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

function TSlidingAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TSlidingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);
  Result := GetMem(ASize);
end;

procedure TSlidingAllocator.FreeMem(APtr: Pointer); inline;
begin
  // No-op — sliding allocator doesn't support individual free
end;

function TSlidingAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := False;
end;

function TSlidingAllocator.Push: Boolean;
begin
  if FMarkCount >= SLIDING_MAX_MARKS then
    Exit(False);
  FMarks[FMarkCount] := FOffset;
  Inc(FMarkCount);
  Inc(FStats.PushCount);
  Result := True;
end;

procedure TSlidingAllocator.Pop;
begin
  if FMarkCount <= 0 then
    Exit;
  Dec(FMarkCount);
  FOffset := FMarks[FMarkCount];
  Inc(FStats.PopCount);
end;

function TSlidingAllocator.GetStats: TSlidingStats;
begin
  Result := FStats;
end;

end.
