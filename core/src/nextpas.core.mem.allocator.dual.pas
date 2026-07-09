{
    nextpas.core.mem.allocator.dual
    --------------------------------
    Dual allocator — size-based strategy switching.

    Routes allocations to different allocators based on size.
    Small allocations go to one allocator, large to another.
    Uses a header to track which allocator was used for each allocation.
}

unit nextpas.core.mem.allocator.dual;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  DUAL_DEFAULT_THRESHOLD = 4096;
  DUAL_HEADER_SIZE = SizeOf(Byte);

type
  TDualStats = record
    SmallAllocCount: UInt64;
    LargeAllocCount: UInt64;
    SmallFreeCount: UInt64;
    LargeFreeCount: UInt64;
  end;

  TDualAllocator = class(TInterfacedObject, IAllocator)
  private
    FSmall: IAllocator;
    FLarge: IAllocator;
    FThreshold: SizeUInt;
    FStats: TDualStats;
    function IsSmall(ASize: SizeUInt): Boolean;
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;

    function Traits: TAllocatorTraits; inline;
    constructor Create(ASmall, ALarge: IAllocator;
      AThreshold: SizeUInt = DUAL_DEFAULT_THRESHOLD);
    function GetStats: TDualStats;
  end;

implementation

uses
  nextpas.core.base;

const
  DUAL_TAG_SMALL = 0;
  DUAL_TAG_LARGE = 1;

{ TDualAllocator }

constructor TDualAllocator.Create(ASmall, ALarge: IAllocator;
  AThreshold: SizeUInt);
begin
  inherited Create;
  FSmall := ASmall;
  FLarge := ALarge;
  FThreshold := AThreshold;
  FillChar(FStats, SizeOf(FStats), 0);
end;

function TDualAllocator.IsSmall(ASize: SizeUInt): Boolean;
begin
  Result := ASize <= FThreshold;
end;

function TDualAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LHeader: PByte;
begin
  if IsSmall(ASize) then
  begin
    LHeader := PByte(FSmall.GetMem(ASize + DUAL_HEADER_SIZE));
    if LHeader = nil then
      Exit(nil);
    LHeader^ := DUAL_TAG_SMALL;
    Inc(FStats.SmallAllocCount);
    Result := Pointer(LHeader + DUAL_HEADER_SIZE);
  end
  else
  begin
    LHeader := PByte(FLarge.GetMem(ASize + DUAL_HEADER_SIZE));
    if LHeader = nil then
      Exit(nil);
    LHeader^ := DUAL_TAG_LARGE;
    Inc(FStats.LargeAllocCount);
    Result := Pointer(LHeader + DUAL_HEADER_SIZE);
  end;
end;

function TDualAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TDualAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LHeader: PByte;
  LOldTag: Byte;
  LOldAllocator: IAllocator;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  LHeader := PByte(APtr) - DUAL_HEADER_SIZE;
  LOldTag := LHeader^;

  // If same category, try in-place realloc
  if (LOldTag = DUAL_TAG_SMALL) and IsSmall(ASize) then
  begin
    if LOldTag = DUAL_TAG_SMALL then
      LOldAllocator := FSmall
    else
      LOldAllocator := FLarge;
    // For simplicity, allocate new and copy
  end;

  Result := GetMem(ASize);
  if Result <> nil then
  begin
    Move(APtr^, Result^, ASize);
    FreeMem(APtr);
  end;
end;

procedure TDualAllocator.FreeMem(APtr: Pointer); inline;
var
  LHeader: PByte;
  LOldTag: Byte;
begin
  if APtr = nil then
    Exit;

  LHeader := PByte(APtr) - DUAL_HEADER_SIZE;
  LOldTag := LHeader^;

  if LOldTag = DUAL_TAG_SMALL then
  begin
    FSmall.FreeMem(LHeader);
    Inc(FStats.SmallFreeCount);
  end
  else
  begin
    FLarge.FreeMem(LHeader);
    Inc(FStats.LargeFreeCount);
  end;
end;

function TDualAllocator.GetStats: TDualStats;
begin
  Result := FStats;
end;


function TDualAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
end;

end.
