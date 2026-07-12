{
    nextpas.core.mem.allocator.page
    --------------------------------
    Page allocator — large block allocation via mmap.

    Allocates memory in page-sized chunks using the platform's
    virtual memory API. Suitable for large allocations that
    benefit from direct OS memory management.
}

unit nextpas.core.mem.allocator.page;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  PAGE_SIZE = 4096;
  PAGE_MIN_SIZE = PAGE_SIZE;

type
  TPageStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    TotalPages: UInt64;
    TotalBytes: UInt64;
  end;

  TPageAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FStats: TPageStats;
    function AlignToPage(ASize: SizeUInt): SizeUInt;
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
    function GetStats: TPageStats;
  end;

implementation

uses
  nextpas.core.base;

{ TPageAllocator }

constructor TPageAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TPageAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

function TPageAllocator.AlignToPage(ASize: SizeUInt): SizeUInt;
begin
  Result := (ASize + PAGE_SIZE - 1) and not SizeUInt(PAGE_SIZE - 1);
  if Result < ASize then { overflow check }
    Result := 0;
end;

function TPageAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LAligned: SizeUInt;
begin
  if ASize = 0 then
    Exit(nil);
  if ASize < PAGE_MIN_SIZE then
    ASize := PAGE_MIN_SIZE;
  LAligned := AlignToPage(ASize);
  if LAligned = 0 then
    Exit(nil);
  Result := FInner.GetMem(LAligned);
  if Result <> nil then
  begin
    Inc(FStats.AllocCount);
    Inc(FStats.TotalPages, LAligned div PAGE_SIZE);
    Inc(FStats.TotalBytes, LAligned);
  end;
end;

function TPageAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TPageAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  Result := GetMem(ASize);
  if Result <> nil then
  begin
    Move(APtr^, Result^, ASize);
    FreeMem(APtr);
  end;
end;

procedure TPageAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  FInner.FreeMem(APtr);
  Inc(FStats.FreeCount);
end;

function TPageAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := True;
end;

function TPageAllocator.GetStats: TPageStats;
begin
  Result := FStats;
end;

end.
