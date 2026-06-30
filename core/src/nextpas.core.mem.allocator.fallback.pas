{******************************************************************************
  nextpas.core.mem.allocator.fallback — Fallback Allocator Chain

  当主分配器 OOM 时自动降级到后备分配器。
  适用于: Arena 处理大文件、编译器处理超大编译单元等需要 graceful degradation 的场景。

  TFallbackAllocator:
    TAllocator 子类, try primary → EOutOfMemory → fallback
    FreeMem: 记录来源, 从正确的分配器释放

  TFallbackArena:
    IArena 包装器, Arena OOM (返回 nil) → 降级到 TAllocator
    Reset: 只重置 Arena, 不重置 fallback 分配的内存

  设计约束:
    - 非线程安全 (外部保护)
    - FreeMem 需要 O(1) 查找来源 — 使用 pointer → source map
    - map 开销: 每次 fallback 分配 ~32 bytes 额外元数据
******************************************************************************}
unit nextpas.core.mem.allocator.fallback;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf;

type
  {** Fallback 来源标记 *}
  TFallbackSource = (fsPrimary, fsFallback);

  {** Fallback 分配记录 — 跟踪每个 fallback 分配的来源 *}
  PFallbackEntry = ^TFallbackEntry;
  TFallbackEntry = record
    Ptr: Pointer;
    Source: TFallbackSource;
    Size: SizeUInt;
  end;

  TFallbackAllocator = class(TAllocator)
  private
    FPrimary: TAllocator;
    FFallback: TAllocator;
    FEntries: array of TFallbackEntry;
    FEntryCount: SizeInt;
    FTotalFallbacks: SizeUInt;

    procedure TrackFallback(APtr: Pointer; ASize: SizeUInt);
    function FindEntry(APtr: Pointer): PFallbackEntry;
    procedure RemoveEntry(APtr: Pointer);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    constructor Create(APrimary, AFallback: TAllocator);
    destructor Destroy; override;

    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; override;
    function Traits: TAllocatorTraits; override;

    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

  TFallbackArena = class(TInterfacedObject, IArena)
  private
    FArena: IArena;
    FFallback: TAllocator;
    FFallbackPtrs: array of Pointer;
    FFallbackSizes: array of SizeUInt;
    FFallbackCount: SizeInt;
    FTotalFallbacks: SizeUInt;
    procedure TrackFallback(APtr: Pointer; ASize: SizeUInt);
  public
    constructor Create(AArena: IArena; AFallback: TAllocator);
    destructor Destroy; override;

    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    procedure FreeFallbacks;
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

implementation

{ ---------------------------------------------------------------------------
  TFallbackAllocator
  --------------------------------------------------------------------------- }

constructor TFallbackAllocator.Create(APrimary, AFallback: TAllocator);
begin
  inherited Create;
  FPrimary := APrimary;
  FFallback := AFallback;
  FEntries := nil;
  FEntryCount := 0;
  FTotalFallbacks := 0;
end;

destructor TFallbackAllocator.Destroy;
begin
  FEntries := nil;
  inherited Destroy;
end;

procedure TFallbackAllocator.TrackFallback(APtr: Pointer; ASize: SizeUInt);
begin
  if FEntryCount >= Length(FEntries) then begin
    if Length(FEntries) = 0 then
      SetLength(FEntries, 16)
    else
      SetLength(FEntries, Length(FEntries) * 2);
  end;
  FEntries[FEntryCount].Ptr := APtr;
  FEntries[FEntryCount].Source := fsFallback;
  FEntries[FEntryCount].Size := ASize;
  Inc(FEntryCount);
  Inc(FTotalFallbacks);
end;

function TFallbackAllocator.FindEntry(APtr: Pointer): PFallbackEntry;
var
  I: SizeInt;
begin
  for I := 0 to FEntryCount - 1 do
    if FEntries[I].Ptr = APtr then
      Exit(@FEntries[I]);
  Result := nil;
end;

procedure TFallbackAllocator.RemoveEntry(APtr: Pointer);
var
  I: SizeInt;
begin
  for I := 0 to FEntryCount - 1 do
    if FEntries[I].Ptr = APtr then begin
      FEntries[I] := FEntries[FEntryCount - 1];
      Dec(FEntryCount);
      Exit;
    end;
end;

function TFallbackAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FPrimary.GetMem(ASize);
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FPrimary.AllocMem(ASize);
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LEntry: PFallbackEntry;
begin
  LEntry := FindEntry(ADst);
  if LEntry <> nil then begin
    Result := FFallback.ReallocMem(ADst, LEntry^.Size, ASize);
    if Result <> nil then begin
      LEntry^.Ptr := Result;
      LEntry^.Size := ASize;
    end;
  end
  else
    Result := FPrimary.ReallocMem(ADst, 0, ASize);
end;

procedure TFallbackAllocator.DoFreeMem(ADst: Pointer);
var
  LEntry: PFallbackEntry;
begin
  LEntry := FindEntry(ADst);
  if LEntry <> nil then begin
    FFallback.FreeMem(ADst, LEntry^.Size);
    RemoveEntry(ADst);
  end
  else
    FPrimary.FreeMem(ADst, 0);
end;

function TFallbackAllocator.ReallocMem(APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer;
var
  LEntry: PFallbackEntry;
begin
  if (APtr = nil) or (ANewSize = 0) then
    Exit(inherited ReallocMem(APtr, AOldSize, ANewSize));
  LEntry := FindEntry(APtr);
  if LEntry <> nil then begin
    Result := FFallback.ReallocMem(APtr, LEntry^.Size, ANewSize);
    if Result <> nil then begin
      LEntry^.Ptr := Result;
      LEntry^.Size := ANewSize;
    end;
  end
  else
    Result := FPrimary.ReallocMem(APtr, AOldSize, ANewSize);
end;

function TFallbackAllocator.Traits: TAllocatorTraits;
var
  LFallbackTraits: TAllocatorTraits;
begin
  Result := FPrimary.Traits;
  LFallbackTraits := FFallback.Traits;
  if LFallbackTraits.SupportsAligned then
    Result.SupportsAligned := True;
  if LFallbackTraits.ZeroInitialized then
    Result.ZeroInitialized := True;
end;

{ ---------------------------------------------------------------------------
  TFallbackArena
  --------------------------------------------------------------------------- }

constructor TFallbackArena.Create(AArena: IArena; AFallback: TAllocator);
begin
  inherited Create;
  FArena := AArena;
  FFallback := AFallback;
  FFallbackPtrs := nil;
  FFallbackSizes := nil;
  FFallbackCount := 0;
  FTotalFallbacks := 0;
end;

destructor TFallbackArena.Destroy;
begin
  FreeFallbacks;
  inherited Destroy;
end;

procedure TFallbackArena.TrackFallback(APtr: Pointer; ASize: SizeUInt);
begin
  if FFallbackCount >= Length(FFallbackPtrs) then begin
    if Length(FFallbackPtrs) = 0 then begin
      SetLength(FFallbackPtrs, 16);
      SetLength(FFallbackSizes, 16);
    end else begin
      SetLength(FFallbackPtrs, Length(FFallbackPtrs) * 2);
      SetLength(FFallbackSizes, Length(FFallbackSizes) * 2);
    end;
  end;
  FFallbackPtrs[FFallbackCount] := APtr;
  FFallbackSizes[FFallbackCount] := ASize;
  Inc(FFallbackCount);
  Inc(FTotalFallbacks);
end;

function TFallbackArena.Alloc(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
  if Result = nil then begin
    Result := FFallback.AllocAligned(ASize, AAlign);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackArena.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackArena.SaveMark: TArenaMark;
begin
  Result := FArena.SaveMark;
end;

procedure TFallbackArena.RestoreToMark(AMark: TArenaMark);
begin
  FArena.RestoreToMark(AMark);
end;

procedure TFallbackArena.Reset;
begin
  FArena.Reset;
end;

function TFallbackArena.UsedSize: SizeUInt;
begin
  Result := FArena.UsedSize;
end;

function TFallbackArena.RemainingSize: SizeUInt;
begin
  Result := FArena.RemainingSize;
end;

function TFallbackArena.Stats: TArenaStats;
begin
  Result := FArena.Stats;
end;

procedure TFallbackArena.FreeFallbacks;
var
  I: SizeInt;
begin
  for I := 0 to FFallbackCount - 1 do
    FFallback.FreeMem(FFallbackPtrs[I], FFallbackSizes[I]);
  FFallbackCount := 0;
end;

end.
