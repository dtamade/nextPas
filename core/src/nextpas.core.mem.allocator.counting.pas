{
    nextpas.core.mem.allocator.counting
    -----------------------------------
    Counting allocator wrapper.

    Tracks the number of active (non-freed) allocations. Useful for
    detecting leaks at shutdown — if ActiveCount > 0, something leaked.

    No headers added — uses atomic operations on internal counters.
}

unit nextpas.core.mem.allocator.counting;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  TCountingStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    ReallocCount: UInt64;
    ActiveCount: Int64;
    PeakActiveCount: Int64;
  end;

  TCountingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FStats: TCountingStats;
    procedure IncActive;
    procedure DecActive;
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function GetStats: TCountingStats;
    function ActiveCount: Int64;
    function PeakActiveCount: Int64;
    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.base;

{ TCountingAllocator }

constructor TCountingAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('TCountingAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TCountingAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

procedure TCountingAllocator.IncActive;
begin
  Inc(FStats.AllocCount);
  Inc(FStats.ActiveCount);
  if FStats.ActiveCount > FStats.PeakActiveCount then
    FStats.PeakActiveCount := FStats.ActiveCount;
end;

procedure TCountingAllocator.DecActive;
begin
  Inc(FStats.FreeCount);
  Dec(FStats.ActiveCount);
end;

function TCountingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    IncActive;
end;

function TCountingAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    IncActive;
end;

function TCountingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  Inc(FStats.ReallocCount);
  Result := FInner.ReallocMem(APtr, ASize);
  // ActiveCount unchanged: one alloc + one free = net zero
end;

procedure TCountingAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  FInner.FreeMem(APtr);
  DecActive;
end;

function TCountingAllocator.GetStats: TCountingStats;
begin
  Result := FStats;
end;

function TCountingAllocator.ActiveCount: Int64;
begin
  Result := FStats.ActiveCount;
end;

function TCountingAllocator.PeakActiveCount: Int64;
begin
  Result := FStats.PeakActiveCount;
end;

function TCountingAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
