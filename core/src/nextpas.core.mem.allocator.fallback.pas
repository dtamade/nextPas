{******************************************************************************
  nextpas.core.mem.allocator.fallback — Fallback Allocator Chain

  当主分配器 OOM 时自动降级到后备分配器。
  适用于: Arena 处理大文件、编译器处理超大编译单元等需要 graceful degradation 的场景。

  TFallbackAllocator:
    IAllocator 包装器, try primary → EOutOfMemory → fallback
    FreeMem/LFreeMem: 记录来源, 从正确的分配器释放

  TFallbackArena:
    IArena 包装器, Arena OOM (返回 nil) → 降级到 IAllocator
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
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf;

type
  {** Fallback 来源标记 }
  TFallbackSource = (fsPrimary, fsFallback);

  {** Fallback 分配记录 — 跟踪每个 fallback 分配的来源 }
  PFallbackEntry = ^TFallbackEntry;
  TFallbackEntry = record
    Ptr: Pointer;
    Source: TFallbackSource;
    Size: SizeUInt;
  end;

  // Fallback Allocator — 主分配器 OOM 时降级到后备
  //
  // 使用模式:
  //   var LFall: TFallbackAllocator;
  //   LFall := TFallbackAllocator.Create(LArenaAllocator, LRtlAllocator);
  //   LP := LFall.GetMem(1024);  // arena 优先, OOM 时降级到 RTL
  //   LFall.FreeMem(LP);         // 自动从正确的分配器释放
  TFallbackAllocator = class(TInterfacedObject, IAllocator)
  private
    FPrimary: IAllocator;
    FFallback: IAllocator;
    { 记录 fallback 分配的来源 (简化: 用动态数组, 线性搜索) }
    FEntries: array of TFallbackEntry;
    FEntryCount: SizeInt;
    FTotalFallbacks: SizeUInt;

    procedure TrackFallback(APtr: Pointer; ASize: SizeUInt);
    function FindEntry(APtr: Pointer): PFallbackEntry;
    procedure RemoveEntry(APtr: Pointer);
  public
    constructor Create(APrimary, AFallback: IAllocator);
    destructor Destroy; override;

    { IAllocator }
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    procedure FreeAligned(APtr: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function Traits: TAllocatorTraits;

    {** 已降级到 fallback 的分配次数 }
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

  // Fallback Arena — Arena OOM 时降级到 IAllocator
  //
  // Arena 分配返回 nil 时, 自动尝试 IAllocator 分配。
  // Reset 只重置 Arena, fallback 分配的内存不重置 (需手动释放)。
  //
  // 使用模式:
  //   var LFall: TFallbackArena;
  //   LFall := TFallbackArena.Create(LArena, LRtlAllocator);
  //   LP := LFall.Alloc(1024);  // arena 优先, nil 时降级
  //   LFall.Reset;              // 只重置 arena 部分
  TFallbackArena = class(TInterfacedObject, IArena)
  private
    FArena: IArena;
    FFallback: IAllocator;
    { 记录 fallback 分配 }
    FFallbackPtrs: array of Pointer;
    FFallbackCount: SizeInt;
    FTotalFallbacks: SizeUInt;
  public
    constructor Create(AArena: IArena; AFallback: IAllocator);
    destructor Destroy; override;

    { IArena }
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;

    {** 释放所有 fallback 分配的内存 }
    procedure FreeFallbacks;
    {** 已降级到 fallback 的分配次数 }
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

implementation

{ ---------------------------------------------------------------------------
  TFallbackAllocator
  --------------------------------------------------------------------------- }

constructor TFallbackAllocator.Create(APrimary, AFallback: IAllocator);
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
  { entries 只是跟踪, 不释放内存 (由调用方负责) }
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

function TFallbackAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  Result := FPrimary.GetMem(ASize);
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FPrimary.AllocMem(ASize);
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LEntry: PFallbackEntry;
begin
  if APtr = nil then
    Exit(GetMem(ASize));

  LEntry := FindEntry(APtr);
  if LEntry <> nil then
    { 来自 fallback }
    Result := FFallback.ReallocMem(APtr, ASize)
  else
    Result := FPrimary.ReallocMem(APtr, ASize);
end;

procedure TFallbackAllocator.FreeMem(APtr: Pointer);
var
  LEntry: PFallbackEntry;
begin
  if APtr = nil then
    Exit;

  LEntry := FindEntry(APtr);
  if LEntry <> nil then begin
    FFallback.FreeMem(APtr);
    RemoveEntry(APtr);
  end
  else
    FPrimary.FreeMem(APtr);
end;

procedure TFallbackAllocator.FreeAligned(APtr: Pointer);
var
  LEntry: PFallbackEntry;
begin
  if APtr = nil then
    Exit;

  LEntry := FindEntry(APtr);
  if LEntry <> nil then begin
    FFallback.FreeAligned(APtr);
    RemoveEntry(APtr);
  end
  else
    FPrimary.FreeAligned(APtr);
end;

function TFallbackAllocator.MemSize(APtr: Pointer): SizeUInt;
var
  LEntry: PFallbackEntry;
begin
  LEntry := FindEntry(APtr);
  if LEntry <> nil then
    Result := FFallback.MemSize(APtr)
  else
    Result := FPrimary.MemSize(APtr);
end;

function TFallbackAllocator.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FPrimary.AllocAligned(ASize, AAlign);
  if Result = nil then begin
    Result := FFallback.AllocAligned(ASize, AAlign);
    if Result <> nil then
      TrackFallback(Result, ASize);
  end;
end;

function TFallbackAllocator.Traits: TAllocatorTraits;
begin
  Result := FPrimary.Traits;
end;

{ ---------------------------------------------------------------------------
  TFallbackArena
  --------------------------------------------------------------------------- }

constructor TFallbackArena.Create(AArena: IArena; AFallback: IAllocator);
begin
  inherited Create;
  FArena := AArena;
  FFallback := AFallback;
  FFallbackPtrs := nil;
  FFallbackCount := 0;
  FTotalFallbacks := 0;
end;

destructor TFallbackArena.Destroy;
begin
  FreeFallbacks;
  inherited Destroy;
end;

function TFallbackArena.Alloc(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then begin
      if FFallbackCount >= Length(FFallbackPtrs) then begin
        if Length(FFallbackPtrs) = 0 then
          SetLength(FFallbackPtrs, 16)
        else
          SetLength(FFallbackPtrs, Length(FFallbackPtrs) * 2);
      end;
      FFallbackPtrs[FFallbackCount] := Result;
      Inc(FFallbackCount);
      Inc(FTotalFallbacks);
    end;
  end;
end;

function TFallbackArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
  if Result = nil then begin
    Result := FFallback.AllocAligned(ASize, AAlign);
    if Result <> nil then begin
      if FFallbackCount >= Length(FFallbackPtrs) then begin
        if Length(FFallbackPtrs) = 0 then
          SetLength(FFallbackPtrs, 16)
        else
          SetLength(FFallbackPtrs, Length(FFallbackPtrs) * 2);
      end;
      FFallbackPtrs[FFallbackCount] := Result;
      Inc(FFallbackCount);
      Inc(FTotalFallbacks);
    end;
  end;
end;

function TFallbackArena.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then begin
      if FFallbackCount >= Length(FFallbackPtrs) then begin
        if Length(FFallbackPtrs) = 0 then
          SetLength(FFallbackPtrs, 16)
        else
          SetLength(FFallbackPtrs, Length(FFallbackPtrs) * 2);
      end;
      FFallbackPtrs[FFallbackCount] := Result;
      Inc(FFallbackCount);
      Inc(FTotalFallbacks);
    end;
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
    FFallback.FreeMem(FFallbackPtrs[I]);
  FFallbackCount := 0;
end;

end.
