unit nextpas.core.mem.pool.fixed_slab;

{$I nextpas.core.settings.inc}
{.$define NEXTPAS_SLAB_TESTGUARD} // enable when diagnosing

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in slab internals

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.allocator,
  nextpas.core.mem.intf,
  nextpas.core.base.utils,
  nextpas.core.mem.utils,
  nextpas.core.mem.error,
  nextpas.core.mem.secure,

  nextpas.core.mem.pool.fixed_slab.nginx;

type
  {$IFDEF NEXTPAS_CORE_SLAB_STATS}
  TFixedSlabSlotStat = record
    total: SizeUInt;
    used: SizeUInt;
    reqs: SizeUInt;
    fails: SizeUInt;
  end;
  TFixedSlabStats = record
    TotalPages: SizeUInt;
    FreePages: SizeUInt;
    SlotCount: SizeUInt;
  end;
  {$ENDIF}

  IFixedSlabPool = interface(IMemoryPool)
    ['{0C89D0E7-601B-49E1-92B0-6ED38E319A11}']

    function GetCapacity: SizeUInt;
    function GetUsed: SizeUInt;
    {$IFDEF NEXTPAS_CORE_SLAB_STATS}
    function GetStats: TFixedSlabStats;
    function GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
    {$ENDIF}

    property Capacity: SizeUInt read GetCapacity;
    property Used: SizeUInt read GetUsed;
  end;

  TFixedSlabPool = class(TInterfacedObject, IFixedSlabPool, IMemoryPool, IAllocator)
  private
    FAllocator: IAllocator;
    FRaw: Pointer;
    FBase: PByte;
    FRegionEnd: PByte;
    FSize: SizeUInt;
    FMinShift: SizeUInt;
    FCore: Pointer;
    FOwnKeys: array of PtrUInt;
    FOwnStates: array of Byte;
    FOwnSizes: array of SizeUInt;
    FOwnMask: SizeUInt;
    FOwnFill: SizeUInt;
    FAlignedFallbackPtrs: array of Pointer;
    FAlignedFallbackRawPtrs: array of Pointer;
    FAlignedFallbackStates: array of Byte;

    {$IFDEF NEXTPAS_CORE_SLAB_STATS}
    function GetStats: TFixedSlabStats; inline;
    function GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat; inline;
    function BuildStats: TFixedSlabStats;
    function BuildSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
    {$ENDIF}
    function ChunkSizeOf(APtr: Pointer): SizeUInt;
    function IsLiveChunkStart(APtr: Pointer; out AChunkSize: SizeUInt): Boolean;
    procedure OwnershipInit(AMinCapacity: SizeUInt);
    procedure OwnershipClear;
    procedure OwnershipRehash(ANewCapacity: SizeUInt);
    procedure OwnershipGrowIfNeeded;
    function OwnershipLookup(AKey: PtrUInt; out AIndex: SizeUInt): Boolean;
    procedure TrackAllocated(APtr: Pointer; ASize: SizeUInt);
    procedure ValidateTrackedLivePointer(APtr: Pointer; const AOperation: string; out ASize: SizeUInt);
    function AlignedFallbackIndexOf(APtr: Pointer): Integer;
    procedure TrackAlignedFallback(APtr, ARawPtr: Pointer);
    function ValidateAlignedFallbackPointer(APtr: Pointer; const AOperation: string): Integer;
    procedure FreeActiveAlignedFallbacks;

  public
    constructor Create(ACapacity: SizeUInt; AAllocator: IAllocator = nil; AMinShift: SizeUInt = 3);
    destructor Destroy; override;

    function Acquire(out AUnit: Pointer): Boolean;
    function TryAcquire(out AUnit: Pointer): Boolean; inline;
    function AcquireN(out AUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(AUnit: Pointer);
    procedure ReleaseN(const AUnits: array of Pointer; aCount: Integer);
    procedure Reset;

    function GetCapacity: SizeUInt;
    function GetUsed: SizeUInt;

    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    procedure SecureFree(APtr: Pointer);
    function MemSizeOf(APtr: Pointer): SizeUInt;

    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);

    function Traits: TAllocatorTraits;

    function Owns(APtr: Pointer): Boolean;
    function PageShift: SizeUInt; inline;
    function RegionStart: PByte; inline;
    function RegionEnd: PByte; inline;

    property Capacity: SizeUInt read GetCapacity;
    property Used: SizeUInt read GetUsed;
  end;


implementation

const
  FIXED_SLAB_OWNERSHIP_MIN_CAP = 64;
  FIXED_SLAB_OWNERSHIP_ACTIVE = Byte(1);
  FIXED_SLAB_OWNERSHIP_RELEASED = Byte(2);
  FIXED_SLAB_ALIGNED_ACTIVE = Byte(1);
  FIXED_SLAB_ALIGNED_RELEASED = Byte(2);

{$IFDEF NEXTPAS_SLAB_TESTGUARD}
procedure SlabDbg(const s: AnsiString);
var f: Text;
begin
  {$I-}
  AssignFile(f, 'slab_debug.log');
  Append(f);
  if IOResult <> 0 then Rewrite(f);
  Writeln(f, s);
  CloseFile(f);
  {$I+}
end;

function NumU(u: PtrUInt): AnsiString;
var t: AnsiString;
begin
  Str(u, t);
  Result := t;
end;
{$ENDIF}

{ TFixedSlabPool }

constructor TFixedSlabPool.Create(ACapacity: SizeUInt; AAllocator: IAllocator; AMinShift: SizeUInt);
var
  n: SizeUInt;
  desired_pages: SizeUInt;
  overhead_base: SizeUInt;
  per_page_cost: SizeUInt;
  page_payload_cost: SizeUInt;
  allocation_size: SizeUInt;
  ownership_capacity: SizeUInt;
  total_size: SizeUInt;
begin
  inherited Create;

  if AAllocator = nil then
    FAllocator := nextpas.core.mem.allocator.GetRtlAllocator
  else
    FAllocator := AAllocator;

  if ACapacity = 0 then
    Exit;

  FMinShift := AMinShift;
  ngx_slab_sizes_init;

  n := NGX_SLAB_PAGE_SHIFT - FMinShift;
  if ACapacity > High(SizeUInt) - (NGX_SLAB_PAGE_SIZE - 1) then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: capacity overflow (' + IntToStr(ACapacity) + ')');
  desired_pages := (ACapacity + NGX_SLAB_PAGE_SIZE - 1) div NGX_SLAB_PAGE_SIZE;
  overhead_base := SizeOf(ngx_slab_pool_t) + n * (SizeOf(ngx_slab_page_t) + SizeOf(ngx_slab_stat_t));
  per_page_cost := SizeOf(ngx_slab_page_t) + NGX_SLAB_PAGE_SIZE;
  if (desired_pages <> 0) and (per_page_cost > High(SizeUInt) div desired_pages) then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: region size overflow (' + IntToStr(desired_pages) + ' * ' + IntToStr(per_page_cost) + ')');
  page_payload_cost := desired_pages * per_page_cost;
  if overhead_base > High(SizeUInt) - page_payload_cost then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: region size overflow (' + IntToStr(overhead_base) + ' + ' + IntToStr(page_payload_cost) + ')');
  total_size := overhead_base + page_payload_cost;
  if total_size > High(SizeUInt) - NGX_SLAB_PAGE_SIZE then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: region size overflow (' + IntToStr(total_size) + ')');
  total_size := total_size + NGX_SLAB_PAGE_SIZE;
  if total_size > High(SizeUInt) - (NGX_SLAB_PAGE_SIZE - 1) then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: allocation size overflow (' + IntToStr(total_size) + ')');
  allocation_size := total_size + (NGX_SLAB_PAGE_SIZE - 1);
  if desired_pages > High(SizeUInt) div 16 then
    raise EAllocError.Create(aeInvalidLayout,
      'TFixedSlabPool.Create: ownership index overflow (' + IntToStr(desired_pages) + ')');
  ownership_capacity := desired_pages * 16;

  FRaw := FAllocator.GetMem(allocation_size);
  if FRaw = nil then Exit;

  FBase := ngx_align_ptr(PByte(FRaw), NGX_SLAB_PAGE_SIZE);
  FCore := FBase;

  Pngx_slab_pool_t(FCore)^.min_shift := FMinShift;
  FRegionEnd := FBase + total_size;
  Pngx_slab_pool_t(FCore)^.endp := FRegionEnd;

  ngx_slab_init(Pngx_slab_pool_t(FCore));

  FSize := PtrUInt(Pngx_slab_pool_t(FCore)^.endp) - PtrUInt(Pngx_slab_pool_t(FCore)^.start);
  OwnershipInit(ownership_capacity);
end;

destructor TFixedSlabPool.Destroy;
begin
  FreeActiveAlignedFallbacks;
  SetLength(FAlignedFallbackPtrs, 0);
  SetLength(FAlignedFallbackRawPtrs, 0);
  SetLength(FAlignedFallbackStates, 0);
  if FRaw <> nil then
    FAllocator.FreeMem(FRaw);
  SetLength(FOwnKeys, 0);
  SetLength(FOwnStates, 0);
  SetLength(FOwnSizes, 0);
  FOwnMask := 0;
  FOwnFill := 0;
  FCore := nil;
  FBase := nil;
  inherited Destroy;
end;

function TFixedSlabPool.Acquire(out AUnit: Pointer): Boolean;
var
  LUnitSize: SizeUInt;
begin
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  AUnit := GetMem(LUnitSize);
  Result := AUnit <> nil;
end;

function TFixedSlabPool.TryAcquire(out AUnit: Pointer): Boolean;
begin
  Result := Acquire(AUnit);
end;

function TFixedSlabPool.AcquireN(out AUnits: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
  LUnitSize: SizeUInt;
begin
  Result := 0;
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(AUnits) then
      Break;
    LPtr := GetMem(LUnitSize);
    if LPtr = nil then
      Break;
    AUnits[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TFixedSlabPool.Release(AUnit: Pointer);
begin
  FreeMem(AUnit);
end;

procedure TFixedSlabPool.ReleaseN(const AUnits: array of Pointer; aCount: Integer);
var i: Integer;
begin
  if aCount <= 0 then Exit;
  for i := 0 to aCount-1 do
  begin
    if i > High(AUnits) then
      Break;
    FreeMem(AUnits[i]);
  end;
end;

function TFixedSlabPool.ChunkSizeOf(APtr: Pointer): SizeUInt;
begin
  if not IsLiveChunkStart(APtr, Result) then
    Result := 0;
end;

function TFixedSlabPool.IsLiveChunkStart(APtr: Pointer; out AChunkSize: SizeUInt): Boolean;
var
  pool: Pngx_slab_pool_t;
  n, page_type, shift, chunk, word_index, map: SizeUInt;
  slab, m: PtrUInt;
  bitmap: PPtrUInt;
  page: Pngx_slab_page_t;
begin
  AChunkSize := 0;
  Result := False;
  if (APtr = nil) or (FCore = nil) then Exit(False);

  pool := Pngx_slab_pool_t(FCore);

  if (PByte(APtr) < pool^.start) or (PByte(APtr) >= pool^.endp) then
    Exit(False);

  n := (PtrUInt(APtr) - PtrUInt(pool^.start)) shr ngx_pagesize_shift;
  page := @pool^.pages[n];
  slab := page^.slab;
  page_type := ngx_slab_page_type(page);

  case page_type of
    NGX_SLAB_SMALL:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      AChunkSize := SizeUInt(1) shl shift;
      if (PtrUInt(APtr) and (AChunkSize - 1)) <> 0 then
        Exit(False);

      chunk := (PtrUInt(APtr) and (ngx_pagesize - 1)) shr shift;
      n := (ngx_pagesize shr shift) div (AChunkSize * 8);
      if n = 0 then n := 1;
      if chunk < n then
        Exit(False);

      map := (ngx_pagesize shr shift) div (8 * SizeOf(PtrUInt));
      word_index := chunk div (8 * SizeOf(PtrUInt));
      if word_index >= map then
        Exit(False);

      m := PtrUInt(1) shl (chunk mod (8 * SizeOf(PtrUInt)));
      bitmap := PPtrUInt(ngx_slab_page_addr(pool, page));
      Result := (bitmap[word_index] and m) <> 0;
      if not Result then
        AChunkSize := 0;
    end;

    NGX_SLAB_EXACT:
    begin
      AChunkSize := ngx_slab_exact_size;
      if (PtrUInt(APtr) and (AChunkSize - 1)) <> 0 then
        Exit(False);
      chunk := (PtrUInt(APtr) and (ngx_pagesize - 1)) shr ngx_slab_exact_shift;
      if chunk >= (8 * SizeOf(PtrUInt)) then
        Exit(False);
      m := PtrUInt(1) shl chunk;
      Result := (slab and m) <> 0;
      if not Result then
        AChunkSize := 0;
    end;

    NGX_SLAB_BIG:
    begin
      shift := slab and NGX_SLAB_SHIFT_MASK;
      AChunkSize := SizeUInt(1) shl shift;
      if (PtrUInt(APtr) and (AChunkSize - 1)) <> 0 then
        Exit(False);
      chunk := (PtrUInt(APtr) and (ngx_pagesize - 1)) shr shift;
      if chunk >= (ngx_pagesize shr shift) then
        Exit(False);
      m := PtrUInt(1) shl (chunk + NGX_SLAB_MAP_SHIFT);
      Result := (slab and m) <> 0;
      if not Result then
        AChunkSize := 0;
    end;

    NGX_SLAB_PAGE:
    begin
      if (PtrUInt(APtr) and (ngx_pagesize - 1)) <> 0 then
        Exit(False);
      if (slab and NGX_SLAB_PAGE_START) = 0 then
        Exit(False);
      if slab = NGX_SLAB_PAGE_BUSY then
        Exit(False);
      AChunkSize := (slab and not NGX_SLAB_PAGE_START) shl ngx_pagesize_shift;
      Result := AChunkSize > 0;
    end;

    else
      AChunkSize := 0;
  end;
end;

procedure TFixedSlabPool.OwnershipInit(AMinCapacity: SizeUInt);
var
  LCap: SizeUInt;
begin
  LCap := FIXED_SLAB_OWNERSHIP_MIN_CAP;
  while LCap < AMinCapacity do
    LCap := LCap shl 1;
  SetLength(FOwnKeys, LCap);
  SetLength(FOwnStates, LCap);
  SetLength(FOwnSizes, LCap);
  FOwnMask := LCap - 1;
  FOwnFill := 0;
end;

procedure TFixedSlabPool.OwnershipClear;
var
  LIndex: SizeUInt;
begin
  if Length(FOwnKeys) = 0 then
    Exit;

  for LIndex := 0 to FOwnMask do
  begin
    FOwnKeys[LIndex] := 0;
    FOwnStates[LIndex] := 0;
    FOwnSizes[LIndex] := 0;
  end;
  FOwnFill := 0;
end;

procedure TFixedSlabPool.OwnershipRehash(ANewCapacity: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldStates: array of Byte;
  LOldSizes: array of SizeUInt;
  LOldCap, LIndex, LPos: SizeUInt;
  LKey: PtrUInt;
begin
  LOldKeys := FOwnKeys;
  LOldStates := FOwnStates;
  LOldSizes := FOwnSizes;
  LOldCap := Length(LOldKeys);

  SetLength(FOwnKeys, ANewCapacity);
  SetLength(FOwnStates, ANewCapacity);
  SetLength(FOwnSizes, ANewCapacity);
  FOwnMask := ANewCapacity - 1;
  FOwnFill := 0;

  for LIndex := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIndex];
    if LKey = 0 then
      Continue;
    LPos := FixedSlabHash(LKey) and FOwnMask;
    while FOwnKeys[LPos] <> 0 do
      LPos := (LPos + 1) and FOwnMask;
    FOwnKeys[LPos] := LKey;
    FOwnStates[LPos] := LOldStates[LIndex];
    FOwnSizes[LPos] := LOldSizes[LIndex];
    Inc(FOwnFill);
  end;
end;

procedure TFixedSlabPool.OwnershipGrowIfNeeded;
begin
  if Length(FOwnKeys) = 0 then
    OwnershipInit(FIXED_SLAB_OWNERSHIP_MIN_CAP);
  if (FOwnFill + 1) * 2 >= SizeUInt(Length(FOwnKeys)) then
    OwnershipRehash(SizeUInt(Length(FOwnKeys)) shl 1);
end;

function TFixedSlabPool.OwnershipLookup(AKey: PtrUInt; out AIndex: SizeUInt): Boolean;
var
  LIndex: SizeUInt;
begin
  Result := False;
  AIndex := 0;
  if (AKey = 0) or (Length(FOwnKeys) = 0) then
    Exit;

  LIndex := FixedSlabHash(AKey) and FOwnMask;
  while True do
  begin
    if FOwnKeys[LIndex] = 0 then
      Exit(False);
    if FOwnKeys[LIndex] = AKey then
    begin
      AIndex := LIndex;
      Exit(True);
    end;
    LIndex := (LIndex + 1) and FOwnMask;
  end;
end;

procedure TFixedSlabPool.TrackAllocated(APtr: Pointer; ASize: SizeUInt);
var
  LIndex, LPos: SizeUInt;
  LKey: PtrUInt;
begin
  if APtr = nil then
    Exit;
  LKey := PtrUInt(APtr);
  if OwnershipLookup(LKey, LIndex) then
  begin
    FOwnStates[LIndex] := FIXED_SLAB_OWNERSHIP_ACTIVE;
    FOwnSizes[LIndex] := ASize;
    Exit;
  end;

  OwnershipGrowIfNeeded;
  LPos := FixedSlabHash(LKey) and FOwnMask;
  while FOwnKeys[LPos] <> 0 do
    LPos := (LPos + 1) and FOwnMask;
  FOwnKeys[LPos] := LKey;
  FOwnStates[LPos] := FIXED_SLAB_OWNERSHIP_ACTIVE;
  FOwnSizes[LPos] := ASize;
  Inc(FOwnFill);
end;

procedure TFixedSlabPool.ValidateTrackedLivePointer(APtr: Pointer; const AOperation: string; out ASize: SizeUInt);
var
  LIndex: SizeUInt;
  LLiveSize: SizeUInt;
begin
  ASize := 0;
  if APtr = nil then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer cannot be nil');

  if not OwnershipLookup(PtrUInt(APtr), LIndex) then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer is not tracked');

  if FOwnStates[LIndex] = FIXED_SLAB_OWNERSHIP_RELEASED then
    raise EAllocError.Create(aeDoubleFree, 'TFixedSlabPool.' + AOperation + ': double free detected');

  if (FOwnStates[LIndex] <> FIXED_SLAB_OWNERSHIP_ACTIVE) or
     (not IsLiveChunkStart(APtr, LLiveSize)) then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer is not a live block');

  ASize := FOwnSizes[LIndex];
  if ASize = 0 then
    ASize := LLiveSize;
end;

function TFixedSlabPool.AlignedFallbackIndexOf(APtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FAlignedFallbackPtrs) do
    if FAlignedFallbackPtrs[LIndex] = APtr then
      Exit(LIndex);
  Result := -1;
end;

procedure TFixedSlabPool.TrackAlignedFallback(APtr, ARawPtr: Pointer);
var
  LIndex: Integer;
  LCount: Integer;
begin
  if APtr = nil then
    Exit;

  LIndex := AlignedFallbackIndexOf(APtr);
  if LIndex >= 0 then
  begin
    FAlignedFallbackStates[LIndex] := FIXED_SLAB_ALIGNED_ACTIVE;
    FAlignedFallbackRawPtrs[LIndex] := ARawPtr;
    Exit;
  end;

  LCount := Length(FAlignedFallbackPtrs);
  SetLength(FAlignedFallbackPtrs, LCount + 1);
  SetLength(FAlignedFallbackRawPtrs, LCount + 1);
  SetLength(FAlignedFallbackStates, LCount + 1);
  FAlignedFallbackPtrs[LCount] := APtr;
  FAlignedFallbackRawPtrs[LCount] := ARawPtr;
  FAlignedFallbackStates[LCount] := FIXED_SLAB_ALIGNED_ACTIVE;
end;

function TFixedSlabPool.ValidateAlignedFallbackPointer(APtr: Pointer; const AOperation: string): Integer;
begin
  if APtr = nil then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer cannot be nil');

  Result := AlignedFallbackIndexOf(APtr);
  if Result < 0 then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer is not tracked');

  if FAlignedFallbackStates[Result] = FIXED_SLAB_ALIGNED_RELEASED then
    raise EAllocError.Create(aeDoubleFree, 'TFixedSlabPool.' + AOperation + ': double free detected');

  if FAlignedFallbackStates[Result] <> FIXED_SLAB_ALIGNED_ACTIVE then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.' + AOperation + ': pointer is not active');
end;

procedure TFixedSlabPool.FreeActiveAlignedFallbacks;
var
  LIndex: Integer;
begin
  if FAllocator = nil then
    Exit;

  for LIndex := 0 to High(FAlignedFallbackPtrs) do
    if (FAlignedFallbackPtrs[LIndex] <> nil) and
       (FAlignedFallbackStates[LIndex] = FIXED_SLAB_ALIGNED_ACTIVE) then
    begin
      FAllocator.FreeMem(FAlignedFallbackRawPtrs[LIndex]);
      FAlignedFallbackStates[LIndex] := FIXED_SLAB_ALIGNED_RELEASED;
    end;
end;

procedure TFixedSlabPool.Reset;
begin
  FreeActiveAlignedFallbacks;
  SetLength(FAlignedFallbackPtrs, 0);
  SetLength(FAlignedFallbackRawPtrs, 0);
  SetLength(FAlignedFallbackStates, 0);
  if (FBase <> nil) and (FCore <> nil) and (FRegionEnd <> nil) then
  begin
    Pngx_slab_pool_t(FCore)^.min_shift := FMinShift;
    Pngx_slab_pool_t(FCore)^.endp := FRegionEnd;
    ngx_slab_init(Pngx_slab_pool_t(FCore));
    FSize := PtrUInt(Pngx_slab_pool_t(FCore)^.endp) - PtrUInt(Pngx_slab_pool_t(FCore)^.start);
    OwnershipClear;
  end;
end;

{$IFDEF NEXTPAS_CORE_SLAB_STATS}
function TFixedSlabPool.GetStats: TFixedSlabStats;
begin
  Result := BuildStats;
end;

function TFixedSlabPool.GetSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
begin
  Result := BuildSlotStat(Index);
end;

function TFixedSlabPool.BuildStats: TFixedSlabStats;
var
  core: Pngx_slab_pool_t;
  totalPages: SizeUInt;
begin
  core := Pngx_slab_pool_t(FCore);
  if core = nil then
  begin
    Result.TotalPages := 0;
    Result.FreePages := 0;
    Result.SlotCount := 0;
    Exit;
  end;
  totalPages := SizeUInt(core^.last - core^.pages);
  Result.TotalPages := totalPages;
  Result.FreePages := core^.pfree;
  Result.SlotCount := NGX_SLAB_PAGE_SHIFT - core^.min_shift;
end;

function TFixedSlabPool.BuildSlotStat(Index: SizeUInt): TFixedSlabSlotStat;
var
  core: Pngx_slab_pool_t;
  n: SizeUInt;
begin
  core := Pngx_slab_pool_t(FCore);
  if core = nil then
  begin
    ZeroMem(Result, SizeOf(Result));
    Exit;
  end;
  n := NGX_SLAB_PAGE_SHIFT - core^.min_shift;
  if Index >= n then
  begin
    ZeroMem(Result, SizeOf(Result));
    Exit;
  end;
  Result.total := core^.stats[Index].total;
  Result.used  := core^.stats[Index].used;
  Result.reqs  := core^.stats[Index].reqs;
  Result.fails := core^.stats[Index].fails;
end;
{$ENDIF}

function TFixedSlabPool.GetCapacity: SizeUInt;
begin
  Result := FSize;
end;
function TFixedSlabPool.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := True;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

function TFixedSlabPool.MemSizeOf(APtr: Pointer): SizeUInt;
begin
  Result := ChunkSizeOf(APtr);
end;

function TFixedSlabPool.Owns(APtr: Pointer): Boolean;
var
  LSize: SizeUInt;
begin
  Result := IsLiveChunkStart(APtr, LSize);
end;

function TFixedSlabPool.PageShift: SizeUInt;
begin
  Result := NGX_SLAB_PAGE_SHIFT;
end;

function TFixedSlabPool.RegionStart: PByte; inline;
begin
  if FCore=nil then Exit(nil);
  Result := Pngx_slab_pool_t(FCore)^.start;
end;

function TFixedSlabPool.RegionEnd: PByte; inline;
begin
  if FCore=nil then Exit(nil);
  Result := Pngx_slab_pool_t(FCore)^.endp;
end;

function TFixedSlabPool.GetUsed: SizeUInt;
var
  pool: Pngx_slab_pool_t;
  total_pages, data_size: SizeUInt;
begin
  if FCore <> nil then
  begin
    pool := Pngx_slab_pool_t(FCore);
    data_size := PtrUInt(pool^.endp) - PtrUInt(pool^.start);
    total_pages := data_size shr NGX_SLAB_PAGE_SHIFT;

    if pool^.pfree <= total_pages then
      Result := (total_pages - pool^.pfree) shl NGX_SLAB_PAGE_SHIFT
    else
      Result := 0;
  end
  else
    Result := 0;
end;

function TFixedSlabPool.GetMem(ASize: SizeUInt): Pointer;
var
  LChunkSize: SizeUInt;
begin
  if ASize = 0 then Exit(nil);
  if FCore = nil then Exit(nil);
  OwnershipGrowIfNeeded;
  Result := ngx_slab_alloc_locked(Pngx_slab_pool_t(FCore), ASize);
  if Result = nil then
    Exit;
  if not IsLiveChunkStart(Result, LChunkSize) then
  begin
    ngx_slab_free_locked(Pngx_slab_pool_t(FCore), Result);
    raise EAllocError.Create(aeInternalError, 'TFixedSlabPool.GetMem: allocated pointer is not a live block');
  end;
  TrackAllocated(Result, LChunkSize);
end;

function TFixedSlabPool.AllocMem(ASize: SizeUInt): Pointer;
var
  LActualSize: SizeUInt;
begin
  Result := GetMem(ASize);
  if Result <> nil then
  begin
    LActualSize := MemSizeOf(Result);
    if LActualSize > 0 then
      SecureZeroMemory(Result, LActualSize)
    else
      SecureZeroMemory(Result, ASize);
  end;
end;

function TFixedSlabPool.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  p: Pointer;
  oldSize, copySize: SizeUInt;
begin
  if APtr = nil then Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  ValidateTrackedLivePointer(APtr, 'ReallocMem', oldSize);
  p := GetMem(ASize);
  if p = nil then Exit(nil);

  if oldSize > ASize then copySize := ASize else copySize := oldSize;

  {$IFDEF NEXTPAS_SLAB_TESTGUARD}
  WriteLn('[Realloc] APtr=', PtrUInt(APtr):16, ', ASize=', ASize, ', oldSize=', oldSize, ', copySize=', copySize);
  {$ENDIF}

  if copySize > 0 then
    CopyMem(p, APtr, copySize);

  FreeMem(APtr);
  Result := p;
end;

procedure TFixedSlabPool.FreeMem(APtr: Pointer);
var
  LIndex: SizeUInt;
  LSize: SizeUInt;
begin
  if APtr = nil then Exit;
  if FCore = nil then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.FreeMem: pool is not initialized');
  ValidateTrackedLivePointer(APtr, 'FreeMem', LSize);
  ngx_slab_free_locked(Pngx_slab_pool_t(FCore), APtr);
  if OwnershipLookup(PtrUInt(APtr), LIndex) then
  begin
    FOwnStates[LIndex] := FIXED_SLAB_OWNERSHIP_RELEASED;
    FOwnSizes[LIndex] := LSize;
  end;
end;

procedure TFixedSlabPool.SecureFree(APtr: Pointer);
var
  LIndex: SizeUInt;
  LSize: SizeUInt;
begin
  if APtr = nil then Exit;
  if FCore = nil then
    raise EAllocError.Create(aeInvalidPointer, 'TFixedSlabPool.SecureFree: pool is not initialized');
  ValidateTrackedLivePointer(APtr, 'SecureFree', LSize);
  SecureZeroMemory(APtr, LSize);
  ngx_slab_free_locked(Pngx_slab_pool_t(FCore), APtr);
  if OwnershipLookup(PtrUInt(APtr), LIndex) then
  begin
    FOwnStates[LIndex] := FIXED_SLAB_OWNERSHIP_RELEASED;
    FOwnSizes[LIndex] := LSize;
  end;
end;

function TFixedSlabPool.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
  LExtra: SizeUInt;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if (AAlignment <= 8) or (AAlignment <= ASize) then
    Result := GetMem(ASize)
  else if FAllocator <> nil then
  begin
    if (ASize = 0) or (AAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(AAlignment)) then
      Exit(nil);
    LAlignMask := AAlignment - 1;
    LExtra := LAlignMask + SizeOf(Pointer);
    if LExtra < LAlignMask then Exit(nil);
    LNeeded := ASize + LExtra;
    if LNeeded < ASize then Exit(nil);
    LRaw := FAllocator.GetMem(LNeeded);
    if LRaw = nil then Exit(nil);
    Result := AlignUpUnChecked(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), AAlignment);
    LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
    LHeaderPtr^ := LRaw;
    TrackAlignedFallback(Result, LRaw);
  end
  else
    Result := nil;
end;

procedure TFixedSlabPool.FreeAligned(APtr: Pointer);
var
  LIndex: Integer;
  LSize: SizeUInt;
  LHeaderPtr: PPointer;
  LRaw: Pointer;
begin
  if APtr = nil then Exit;
  if Owns(APtr) then
    FreeMem(APtr)
  else
  begin
    if AlignedFallbackIndexOf(APtr) < 0 then
      ValidateTrackedLivePointer(APtr, 'FreeAligned', LSize);
    LIndex := ValidateAlignedFallbackPointer(APtr, 'FreeAligned');
    LRaw := FAlignedFallbackRawPtrs[LIndex];
    if LRaw <> nil then
      FAllocator.FreeMem(LRaw)
    else
    begin
      LHeaderPtr := PPointer(PtrUInt(APtr) - SizeOf(Pointer));
      LRaw := LHeaderPtr^;
      FAllocator.FreeMem(LRaw);
    end;
    FAlignedFallbackStates[LIndex] := FIXED_SLAB_ALIGNED_RELEASED;
  end;
end;

{$POP}

end.
