{******************************************************************************
  nextpas.core.mem.allocator.fallback — Fallback Allocator Chain

  当主分配器 OOM 时自动降级到后备分配器。
  适用于: Arena 处理大文件、编译器处理超大编译单元等需要 graceful degradation 的场景。

  TFallbackAllocator:
    TMemAllocator 包装器, try primary → EOutOfMemory → fallback
    FreeMem/LFreeMem: 记录来源, 从正确的分配器释放

  TFallbackArena:
    IArena 包装器, Arena OOM (返回 nil) → 降级到 TMemAllocator
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
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.allocator.base;

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
  TFallbackAllocator = class(TAllocator)
  private
    FPrimary: TMemAllocator;
    FFallback: TMemAllocator;
    { 记录 fallback 分配的来源 (简化: 用动态数组, 线性搜索) }
    FEntries: array of TFallbackEntry;
    FEntryCount: SizeInt;
    FTotalFallbacks: SizeUInt;

    procedure TrackFallback(APtr: Pointer; ASize: SizeUInt);
    function FindEntry(APtr: Pointer): PFallbackEntry;
    procedure RemoveEntry(APtr: Pointer);
  public
    {** 创建 fallback 分配器，指定主分配器和后备分配器 *}
    constructor Create(APrimary, AFallback: TMemAllocator);
    {** 销毁 fallback 分配器（不释放已分配内存，由调用方负责） *}
    destructor Destroy; override;

    { TMemAllocator }
    {** 分配内存，主分配器 OOM 时自动降级到后备 *}
    function GetMem(ASize: SizeUInt): Pointer; override;
    {** 分配零初始化内存，主分配器 OOM 时降级 *}
    function AllocMem(ASize: SizeUInt): Pointer; override;
    {** 重新分配内存，自动跟踪来源并从正确的分配器操作 *}
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    {** 释放内存，自动判断来源并从正确的分配器释放 *}
    procedure FreeMem(APtr: Pointer); override;
    {** 释放对齐内存，自动判断来源 *}
    procedure FreeAligned(APtr: Pointer); override;
    {** 查询指针所属分配器的内存块大小 *}
    function MemSize(APtr: Pointer): SizeUInt; override;
    {** 分配对齐内存，主分配器 OOM 时降级 *}
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer; override;
    {** 返回合并后的分配器特性（任一支持则组合支持） *}
    function Traits: TAllocatorTraits; override;

    {** 已降级到 fallback 的分配次数 *}
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

  // Fallback Arena — Arena OOM 时降级到 TMemAllocator
  //
  // Arena 分配返回 nil 时, 自动尝试 TMemAllocator 分配。
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
    FFallback: TMemAllocator;
    { 记录 fallback 分配 }
    FFallbackPtrs: array of Pointer;
    FFallbackCount: SizeInt;
    FTotalFallbacks: SizeUInt;
    procedure TrackFallback(APtr: Pointer);
  public
    {** 创建 fallback Arena，指定主 Arena 和后备分配器 *}
    constructor Create(AArena: IArena; AFallback: TMemAllocator);
    {** 销毁 Arena，自动释放所有 fallback 分配的内存 *}
    destructor Destroy; override;

    { IArena }
    {** Arena 分配，Arena OOM 时降级到后备分配器 *}
    function Alloc(ASize: SizeUInt): Pointer;
    {** Arena 对齐分配，Arena OOM 时降级 *}
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer; override;
    {** Arena 零初始化分配，Arena OOM 时降级 *}
    function AllocZeroed(ASize: SizeUInt): Pointer;
    {** 保存 Arena 当前状态标记（仅委托主 Arena） *}
    function SaveMark: TArenaMark;
    {** 恢复 Arena 到指定标记（仅委托主 Arena） *}
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena，仅重置主 Arena 部分，fallback 内存不受影响 *}
    procedure Reset;
    {** 返回主 Arena 的已用大小 *}
    function UsedSize: SizeUInt;
    {** 返回主 Arena 的剩余可用大小 *}
    function RemainingSize: SizeUInt;
    {** 返回主 Arena 的统计信息 *}
    function Stats: TArenaStats;

    {** 释放所有 fallback 分配的内存 *}
    procedure FreeFallbacks;
    {** 已降级到 fallback 的分配次数 *}
    property TotalFallbacks: SizeUInt read FTotalFallbacks;
  end;

implementation

{ ---------------------------------------------------------------------------
  TFallbackAllocator
  --------------------------------------------------------------------------- }

constructor TFallbackAllocator.Create(APrimary, AFallback: TMemAllocator);
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

  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  LEntry := FindEntry(APtr);
  if LEntry <> nil then
  begin
    { 来自 fallback — Realloc 后更新记录 }
    Result := FFallback.ReallocMem(APtr, ASize);
    if Result <> nil then
    begin
      LEntry^.Ptr := Result;
      LEntry^.Size := ASize;
    end
    { ReallocMem 失败时 Result = nil，原指针仍有效，保留原记录 }
  end
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
var
  LFallbackTraits: TAllocatorTraits;
begin
  Result := FPrimary.Traits;
  LFallbackTraits := FFallback.Traits;
  { 合并 primary + fallback 能力：任一支持则组合支持 }
  if LFallbackTraits.SupportsAligned then
    Result.SupportsAligned := True;
  if LFallbackTraits.ZeroInitialized then
    Result.ZeroInitialized := True;
end;

{ ---------------------------------------------------------------------------
  TFallbackArena
  --------------------------------------------------------------------------- }

constructor TFallbackArena.Create(AArena: IArena; AFallback: TMemAllocator);
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

function TFallbackArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
  if Result = nil then begin
    Result := FFallback.AllocAligned(ASize, AAlign);
    if Result <> nil then
      TrackFallback(Result);
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
