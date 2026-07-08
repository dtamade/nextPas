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
  {** Fallback 来源标记 *}
  TFallbackSource = (fsPrimary, fsFallback);

  {** Fallback 分配记录 — 跟踪每个 fallback 分配的来源 *}
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
    { Open-addressing hash map: Ptr → (Source, Size).
      50% load factor triggers grow. No maximum capacity limit —
      growth is bounded by actual fallback allocation count, which is
      rare (only triggered on primary OOM). If fallback frequency is
      unexpectedly high, consider increasing primary arena capacity. }
    FKeys: array of PtrUInt;       { 0 = empty, 1 = tombstone }
    FSources: array of TFallbackSource;
    FSizes: array of SizeUInt;
    FMask: SizeUInt;
    FHighShift: SizeUInt;
    FEntryCount: SizeUInt;
    FFill: SizeUInt;
    FTotalFallbacks: SizeUInt;

    procedure MapInit(aMinCapacity: SizeUInt);
    procedure MapClear;
    procedure MapGrow;
    function MapLookup(aKey: PtrUInt; out aSource: TFallbackSource; out aSize: SizeUInt): Boolean;
    procedure MapInsert(aKey: PtrUInt; aSource: TFallbackSource; aSize: SizeUInt);
    function MapDelete(aKey: PtrUInt; out aSource: TFallbackSource; out aSize: SizeUInt): Boolean;
  public
    {** 创建 fallback 分配器，指定主分配器和后备分配器 *}
    constructor Create(APrimary, AFallback: IAllocator);
    {** 销毁 fallback 分配器（不释放已分配内存，由调用方负责） *}
    destructor Destroy; override;

    { IAllocator }
    {** 分配内存，主分配器 OOM 时自动降级到后备 *}
    function GetMem(ASize: SizeUInt): Pointer;
    {** 分配零初始化内存，主分配器 OOM 时降级 *}
    function AllocMem(ASize: SizeUInt): Pointer;
    {** 重新分配内存，自动跟踪来源并从正确的分配器操作 *}
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    {** 释放内存，自动判断来源并从正确的分配器释放 *}
    procedure FreeMem(APtr: Pointer);
    {** 返回合并后的分配器特性（任一支持则组合支持） *}
    function Traits: TAllocatorTraits;

    {** 已降级到 fallback 的分配次数 *}
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
    procedure TrackFallback(APtr: Pointer);
  public
    {** 创建 fallback Arena，指定主 Arena 和后备分配器 *}
    constructor Create(AArena: IArena; AFallback: IAllocator);
    {** 销毁 Arena，自动释放所有 fallback 分配的内存 *}
    destructor Destroy; override;

    { IArena }
    {** Arena 分配，Arena OOM 时降级到后备分配器 *}
    function Alloc(ASize: SizeUInt): Pointer;
    {** Arena 对齐分配，Arena OOM 时降级 *}
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    {** Arena 零初始化分配，Arena OOM 时降级 *}
    function AllocZeroed(ASize: SizeUInt): Pointer;
    {** 保存 Arena 当前状态标记（仅委托主 Arena） *}
    function SaveMark: TArenaMark;
    {** 恢复 Arena 到指定标记（仅委托主 Arena） *}
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena，仅重置主 Arena 部分，fallback 内存不受影响 *}
    procedure Reset;
    {** 重置 Arena 并释放所有 fallback 分配的内存 *}
    procedure ResetAll;
    {** 返回主 Arena 的已用大小 *}
    function UsedSize: SizeUInt;
    {** 返回主 Arena 的统计信息 *}
    function Stats: TArenaStats;

    {** 释放所有 fallback 分配的内存 *}
    procedure FreeFallbacks;
    {** 已降级到 fallback 的分配次数 *}
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

implementation

uses
  nextpas.core.mem.utils;

const
  FB_MAP_MIN_CAP = 32;
  FB_TOMBSTONE = PtrUInt(1);

{ ---------------------------------------------------------------------------
  TFallbackAllocator
  --------------------------------------------------------------------------- }

constructor TFallbackAllocator.Create(APrimary, AFallback: IAllocator);
begin
  inherited Create;
  FPrimary := APrimary;
  FFallback := AFallback;
  FTotalFallbacks := 0;
  MapInit(FB_MAP_MIN_CAP);
end;

destructor TFallbackAllocator.Destroy;
begin
  MapClear;
  inherited Destroy;
end;

{ --- Hash map internals --- }

procedure TFallbackAllocator.MapInit(aMinCapacity: SizeUInt);
var
  LCap: SizeUInt;
  LIdx: SizeUInt;
begin
  LCap := FB_MAP_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FKeys, LCap);
  SetLength(FSources, LCap);
  SetLength(FSizes, LCap);
  for LIdx := 0 to LCap - 1 do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
  end;
  FMask := LCap - 1;
  FHighShift := SizeUInt(64 - Log2UInt(LCap));
  FEntryCount := 0;
  FFill := 0;
end;

procedure TFallbackAllocator.MapClear;
var
  LIdx: SizeUInt;
begin
  if Length(FKeys) = 0 then Exit;
  for LIdx := 0 to FMask do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
  end;
  FEntryCount := 0;
  FFill := 0;
end;

procedure TFallbackAllocator.MapGrow;
var
  LOldKeys: array of PtrUInt;
  LOldSources: array of TFallbackSource;
  LOldSizes: array of SizeUInt;
  LOldCap: SizeUInt;
  LIdx: SizeUInt;
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  LOldCap := FMask + 1;
  if LOldCap > High(SizeUInt) shr 1 then
    raise EOutOfMemory.Create(aeOutOfMemory,
      'TFallbackAllocator.MapGrow: capacity overflow (current=' + IntToStr(Int64(LOldCap)) + ')');
  LOldKeys := FKeys;
  LOldSources := FSources;
  LOldSizes := FSizes;

  SetLength(FKeys, LOldCap shl 1);
  SetLength(FSources, LOldCap shl 1);
  SetLength(FSizes, LOldCap shl 1);
  FMask := (LOldCap shl 1) - 1;
  FHighShift := SizeUInt(64 - Log2UInt(FMask + 1));

  for LIdx := 0 to FMask do
  begin
    FKeys[LIdx] := 0;
    FSizes[LIdx] := 0;
  end;
  FEntryCount := 0;
  FFill := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if (LKey <> 0) and (LKey <> FB_TOMBSTONE) then
    begin
      LHash := MulHash64(LKey);
      LPos := (LHash shr FHighShift) and FMask;
      while FKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FMask;
      FKeys[LPos] := LKey;
      FSources[LPos] := LOldSources[LIdx];
      FSizes[LPos] := LOldSizes[LIdx];
      Inc(FEntryCount);
      Inc(FFill);
    end;
  end;
end;

function TFallbackAllocator.MapLookup(aKey: PtrUInt; out aSource: TFallbackSource; out aSize: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  aSource := fsPrimary;
  aSize := 0;
  if (aKey = 0) or (aKey = FB_TOMBSTONE) then Exit(False);
  if Length(FKeys) = 0 then Exit(False);
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  while True do
  begin
    if FKeys[LPos] = 0 then Exit(False);
    if FKeys[LPos] = aKey then
    begin
      aSource := FSources[LPos];
      aSize := FSizes[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FMask;
  end;
end;

procedure TFallbackAllocator.MapInsert(aKey: PtrUInt; aSource: TFallbackSource; aSize: SizeUInt);
var
  LPos: SizeUInt;
  LHash: QWord;
  LTomb: SizeUInt;
begin
  if (aKey = 0) or (aKey = FB_TOMBSTONE) then Exit;
  if (FFill + 1) > ((FMask + 1) shr 1) then
    MapGrow;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  LTomb := High(SizeUInt);
  while True do
  begin
    if FKeys[LPos] = 0 then Break;
    if FKeys[LPos] = aKey then
    begin
      FSources[LPos] := aSource;
      FSizes[LPos] := aSize;
      Exit;
    end;
    if (LTomb = High(SizeUInt)) and (FKeys[LPos] = FB_TOMBSTONE) then
      LTomb := LPos;
    LPos := (LPos + 1) and FMask;
  end;
  if LTomb <> High(SizeUInt) then
    LPos := LTomb
  else
    Inc(FFill);
  FKeys[LPos] := aKey;
  FSources[LPos] := aSource;
  FSizes[LPos] := aSize;
  Inc(FEntryCount);
end;

function TFallbackAllocator.MapDelete(aKey: PtrUInt; out aSource: TFallbackSource; out aSize: SizeUInt): Boolean;
var
  LPos: SizeUInt;
  LHash: QWord;
begin
  aSource := fsPrimary;
  aSize := 0;
  Result := False;
  if (aKey = 0) or (aKey = FB_TOMBSTONE) then Exit;
  if Length(FKeys) = 0 then Exit;
  LHash := MulHash64(aKey);
  LPos := (LHash shr FHighShift) and FMask;
  while True do
  begin
    if FKeys[LPos] = 0 then Exit;
    if FKeys[LPos] = aKey then
    begin
      aSource := FSources[LPos];
      aSize := FSizes[LPos];
      FKeys[LPos] := FB_TOMBSTONE;
      FSizes[LPos] := 0;
      if FEntryCount > 0 then Dec(FEntryCount);
      Exit(True);
    end;
    LPos := (LPos + 1) and FMask;
  end;
end;

{ --- IAllocator implementation --- }

function TFallbackAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  try
    Result := FPrimary.GetMem(ASize);
  except
    on E: EOutOfMemory do
      Result := nil;
  end;
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then
    begin
      MapInsert(PtrUInt(Result), fsFallback, ASize);
      Inc(FTotalFallbacks);
    end;
  end;
end;

function TFallbackAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  try
    Result := FPrimary.AllocMem(ASize);
  except
    on E: EOutOfMemory do
      Result := nil;
  end;
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then
    begin
      MapInsert(PtrUInt(Result), fsFallback, ASize);
      Inc(FTotalFallbacks);
    end;
  end;
end;

function TFallbackAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LSource: TFallbackSource;
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));

  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  if MapLookup(PtrUInt(APtr), LSource, LSize) and (LSource = fsFallback) then
  begin
    { 来自 fallback — Realloc 后更新记录 }
    Result := FFallback.ReallocMem(APtr, ASize);
    if Result <> nil then
    begin
      MapDelete(PtrUInt(APtr), LSource, LSize);
      MapInsert(PtrUInt(Result), fsFallback, ASize);
    end
    { ReallocMem 失败时 Result = nil，原指针仍有效，保留原记录 }
  end
  else
  begin
    try
      Result := FPrimary.ReallocMem(APtr, ASize);
    except
      on E: EOutOfMemory do
        Result := nil;
    end;
  end;
end;

procedure TFallbackAllocator.FreeMem(APtr: Pointer);
var
  LSource: TFallbackSource;
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit;

  if MapDelete(PtrUInt(APtr), LSource, LSize) and (LSource = fsFallback) then
    FFallback.FreeMem(APtr)
  else
    FPrimary.FreeMem(APtr);
end;

function TFallbackAllocator.Traits: TAllocatorTraits;
var
  LFallbackTraits: TAllocatorTraits;
begin
  Result := FPrimary.Traits;
  LFallbackTraits := FFallback.Traits;
  { 合并 primary + fallback 能力：任一支持则组合支持 }
  if LFallbackTraits.ZeroInitialized then
    Result.ZeroInitialized := True;
  if LFallbackTraits.SupportsRealloc then
    Result.SupportsRealloc := True;
  { ThreadSafe 继承基类默认 False（内部 hash map 无同步保护） }
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

procedure TFallbackArena.TrackFallback(APtr: Pointer);
begin
  if FFallbackCount >= Length(FFallbackPtrs) then begin
    if Length(FFallbackPtrs) = 0 then
      SetLength(FFallbackPtrs, 16)
    else
      SetLength(FFallbackPtrs, Length(FFallbackPtrs) * 2);
  end;
  FFallbackPtrs[FFallbackCount] := APtr;
  Inc(FFallbackCount);
  Inc(FTotalFallbacks);
end;

function TFallbackArena.Alloc(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
  if Result = nil then begin
    Result := FFallback.GetMem(ASize);
    if Result <> nil then
      TrackFallback(Result);
  end;
end;

{**
 * AllocAligned - 对齐分配（支持 fallback 降级）
 *
 * @desc 先尝试从 Arena 分配，失败则通过 fallback 分配器 over-allocate + 手动对齐。
 *
 * @note fallback 路径约束：
 *   - 必须通过 FreeFallbacks 释放，不支持单个释放
 *   - 对齐要求过大时（如 4096），over-allocation 浪费可达 AAlign + SizeOf(Pointer) 字节
 *   - 原始指针存储在 Result - SizeOf(Pointer) 处，用于 FreeFallbacks 正确释放
 *}
function TFallbackArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LAlignMask: SizeUInt;
  LExtra: SizeUInt;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
  if Result = nil then begin
    // Over-allocate via FFallback.GetMem + manual alignment
    if (ASize = 0) or (AAlign < SizeOf(Pointer)) or (not IsPowerOfTwo(AAlign)) then
      Exit(nil);
    LAlignMask := AAlign - 1;
    LExtra := LAlignMask + SizeOf(Pointer);
    if LExtra < LAlignMask then Exit(nil);
    LNeeded := ASize + LExtra;
    if LNeeded < ASize then Exit(nil);
    LRaw := FFallback.GetMem(LNeeded);
    if LRaw = nil then Exit(nil);
    Result := Pointer((PtrUInt(LRaw) + SizeOf(Pointer) + LAlignMask) and not LAlignMask);
    LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
    LHeaderPtr^ := LRaw;
    if LRaw <> nil then
      TrackFallback(LRaw);
  end;
end;

function TFallbackArena.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
  if Result = nil then begin
    Result := FFallback.AllocMem(ASize);
    if Result <> nil then
      TrackFallback(Result);
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

procedure TFallbackArena.ResetAll;
begin
  FreeFallbacks;
  FArena.Reset;
end;

function TFallbackArena.UsedSize: SizeUInt;
begin
  Result := FArena.UsedSize;
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
