unit nextpas.core.mem.arena.compiler;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.platform.mmap;

const
  {** 初始 chunk 大小 (64KB) }
  ARENA_INITIAL_CHUNK_SIZE = 64 * 1024;
  {** 大对象阈值 (64KB)：>= 此值的对象直接 mmap }
  ARENA_LARGE_THRESHOLD = 64 * 1024;

{$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
var
  GArenaInstanceCount: Integer;
  GArenaTotalMapped: SizeUInt;
{$ENDIF}

type
  {** Arena 标记：用于 SaveMark/RestoreToMark }
  TArenaMark = record
    ChunkIndex: SizeInt;
    Offset: SizeUInt;
  end;

  {** TArena chunk：mmap 映射信息 }
  TArenaChunk = record
    Map: TPlatformMappedFile;
    Used: SizeUInt;
  end;

  {** TArena
   *
   *  零虚分发的 bump 分配器，使用 mmap 作为后备存储。
   *  适用于编译器热路径等需要极低开销分配的场景。
   *
   *  非线程安全。多线程环境请自行加锁。
   *
   *  使用方式：
   *    var LArena: TArena;
   *    TArena_Init(LArena, DEFAULT_ALIGNMENT);
   *    try
   *      LP := LArena.Alloc(64);
   *      // ...
   *    finally
   *      TArena_Release(LArena);
   *    end; }
  TArena = record
  private
    FChunks: array of TArenaChunk;
    FChunkCount: SizeInt;
    FCurrentBase: PByte;
    FCurrentEnd: PByte;
    FCurrentPtr: PByte;
    FAlignment: SizeUInt;
    FLargeBlocks: array of TPlatformMappedFile;
    FLargeCount: SizeInt;
    FTotalAllocated: SizeUInt;
    FTotalUsed: SizeUInt;
    FLargeUsed: SizeUInt;
    FPeakUsed: SizeUInt;
    FAllocCount: SizeUInt;
    function AllocChunk(aMinSize: SizeUInt): Boolean;
    procedure TrackLargeBlock(const AMap: TPlatformMappedFile);
    procedure UpdateUsedFromChunks;
    function InternalAlloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
  public
    {** 分配 ASize 字节，返回对齐后的指针；失败返回 nil }
    function Alloc(aSize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    {** 分配 ASize 字节，按 AAlignment 对齐；对齐必须是 2 的幂 }
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    {** 分配 ASize 字节并清零 }
    function AllocZeroed(aSize: SizeUInt): Pointer;
    {** 保存当前分配位置 }
    function SaveMark: TArenaMark;
    {** 恢复到标记位置 }
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena（保留 mmap 映射，从头开始分配） }
    procedure Reset;
    {** 释放所有 mmap 映射 }
    procedure Release;
    {** 总 mmap 分配字节数 }
    function TotalAllocated: SizeUInt;
    {** 实际使用字节数 }
    function TotalUsed: SizeUInt;
    {** 峰值使用字节数 }
    function PeakUsed: SizeUInt;
    {** 分配次数 }
    function AllocCount: SizeUInt;
  end;

{** 初始化 TArena }
procedure TArena_Init(var AArena: TArena; AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
{** 释放 TArena 所有资源 }
procedure TArena_Release(var AArena: TArena);

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in arena internals

procedure TArena_Init(var AArena: TArena; AAlignment: SizeUInt);
begin
  AArena.FChunks := nil;
  AArena.FChunkCount := 0;
  AArena.FCurrentBase := nil;
  AArena.FCurrentEnd := nil;
  AArena.FCurrentPtr := nil;
  if (AAlignment = 0) or (not IsPowerOfTwo(AAlignment)) then
    AArena.FAlignment := DEFAULT_ALIGNMENT
  else if AAlignment < SizeOf(Pointer) then
    AArena.FAlignment := SizeOf(Pointer)
  else
    AArena.FAlignment := AAlignment;
  AArena.FLargeBlocks := nil;
  AArena.FLargeCount := 0;
  AArena.FTotalAllocated := 0;
  AArena.FTotalUsed := 0;
  AArena.FLargeUsed := 0;
  AArena.FPeakUsed := 0;
  AArena.FAllocCount := 0;
  {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
  InterLockedIncrement(GArenaInstanceCount);
  {$ENDIF}
end;

procedure TArena_Release(var AArena: TArena);
var
  I: SizeInt;
begin
  {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
  InterLockedDecrement(GArenaInstanceCount);
  if GArenaTotalMapped >= AArena.FTotalAllocated then
    Dec(GArenaTotalMapped, AArena.FTotalAllocated)
  else
    GArenaTotalMapped := 0;
  {$ENDIF}

  for I := 0 to AArena.FChunkCount - 1 do
    platform_mmap_close(AArena.FChunks[I].Map);
  AArena.FChunks := nil;
  AArena.FChunkCount := 0;

  for I := 0 to AArena.FLargeCount - 1 do
    platform_mmap_close(AArena.FLargeBlocks[I]);
  AArena.FLargeBlocks := nil;
  AArena.FLargeCount := 0;

  AArena.FCurrentBase := nil;
  AArena.FCurrentEnd := nil;
  AArena.FCurrentPtr := nil;
  AArena.FTotalAllocated := 0;
  AArena.FTotalUsed := 0;
  AArena.FLargeUsed := 0;
  AArena.FPeakUsed := 0;
  AArena.FAllocCount := 0;
end;

{ TArena }

function TArena.AllocChunk(aMinSize: SizeUInt): Boolean;
var
  LChunkSize: SizeUInt;
  LNewCapacity: SizeInt;
  LMap: TPlatformMappedFile;
  LErr: Int32;
begin
  Result := False;

  { 几何增长：2x }
  if FChunkCount > 0 then
  begin
    LChunkSize := FChunks[FChunkCount - 1].Map.Size;
    while LChunkSize < aMinSize do
    begin
      if LChunkSize > High(SizeUInt) div 2 then
      begin
        LChunkSize := aMinSize;
        Break;
      end;
      LChunkSize := LChunkSize * 2;
    end;
  end
  else
  begin
    LChunkSize := ARENA_INITIAL_CHUNK_SIZE;
    if LChunkSize < aMinSize then
      LChunkSize := aMinSize;
  end;

  { 溢出保护 }
  if LChunkSize < aMinSize then
    Exit;

  LErr := platform_mmap_create_anonymous(UInt64(LChunkSize), pmaReadWrite, [pmfPrivate], LMap);
  if LErr <> 0 then
    Exit;

  { 扩展 chunks 数组 }
  if FChunkCount >= Length(FChunks) then
  begin
    if Length(FChunks) = 0 then
      LNewCapacity := 4
    else
      LNewCapacity := Length(FChunks) * 2;
    SetLength(FChunks, LNewCapacity);
  end;

  FChunks[FChunkCount].Map := LMap;
  FChunks[FChunkCount].Used := 0;
  Inc(FChunkCount);

  FCurrentBase := PByte(LMap.Addr);
  FCurrentEnd := PByte(PtrUInt(LMap.Addr) + PtrUInt(LMap.Size));
  FCurrentPtr := FCurrentBase;
  Inc(FTotalAllocated, LMap.Size);
  {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
  Inc(GArenaTotalMapped, LMap.Size);
  {$ENDIF}
  Result := True;
end;

procedure TArena.TrackLargeBlock(const AMap: TPlatformMappedFile);
var
  LNewCapacity: SizeInt;
begin
  if FLargeCount >= Length(FLargeBlocks) then
  begin
    if Length(FLargeBlocks) = 0 then
      LNewCapacity := 4
    else
      LNewCapacity := Length(FLargeBlocks) * 2;
    SetLength(FLargeBlocks, LNewCapacity);
  end;
  FLargeBlocks[FLargeCount] := AMap;
  Inc(FLargeCount);
end;

procedure TArena.UpdateUsedFromChunks;
var
  I: SizeInt;
begin
  FTotalUsed := FLargeUsed;
  for I := 0 to FChunkCount - 1 do
    Inc(FTotalUsed, FChunks[I].Used);
end;

function TArena.InternalAlloc(aSize: SizeUInt; aAlignment: SizeUInt): Pointer;
var
  LAligned: PtrUInt;
  LMask: PtrUInt;
  LChunkNeed: SizeUInt;
  LMap: TPlatformMappedFile;
  LErr: Int32;
  LPrevUsed: SizeUInt;
begin
  Result := nil;
  if aSize = 0 then
    Exit;

  { 大对象：直接 mmap }
  if aSize >= ARENA_LARGE_THRESHOLD then
  begin
    LErr := platform_mmap_create_anonymous(UInt64(aSize), pmaReadWrite, [pmfPrivate], LMap);
    if LErr <> 0 then
      Exit;
    TrackLargeBlock(LMap);
    Inc(FTotalAllocated, aSize);
    Inc(FLargeUsed, aSize);
    Inc(FTotalUsed, aSize);
    if FTotalUsed > FPeakUsed then
      FPeakUsed := FTotalUsed;
    Inc(FAllocCount);
    {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
    Inc(GArenaTotalMapped, aSize);
    {$ENDIF}
    Exit(LMap.Addr);
  end;

  { 快速路径：当前 chunk 有足够空间 }
  if FCurrentPtr <> nil then
  begin
    LMask := PtrUInt(aAlignment - 1);
    LAligned := (PtrUInt(FCurrentPtr) + LMask) and not LMask;
    if LAligned < PtrUInt(FCurrentPtr) then
      Exit(nil);
    { 检查对齐后的指针加上 size 是否仍在 chunk 内 }
    if (LAligned + PtrUInt(aSize)) <= PtrUInt(FCurrentEnd) then
    begin
      LPrevUsed := FChunks[FChunkCount - 1].Used;
      FCurrentPtr := PByte(LAligned + PtrUInt(aSize));
      FChunks[FChunkCount - 1].Used := SizeUInt(PtrUInt(FCurrentPtr) - PtrUInt(FCurrentBase));
      Inc(FTotalUsed, FChunks[FChunkCount - 1].Used - LPrevUsed);
      if FTotalUsed > FPeakUsed then
        FPeakUsed := FTotalUsed;
      Inc(FAllocCount);
      Exit(Pointer(LAligned));
    end;
  end;

  { 慢路径：分配新 chunk }
  LChunkNeed := aSize + aAlignment - 1;
  if LChunkNeed < aSize then
    Exit(nil);
  if not AllocChunk(LChunkNeed) then
    Exit(nil);

  { 在新 chunk 中分配 }
  LMask := PtrUInt(aAlignment - 1);
  LAligned := (PtrUInt(FCurrentPtr) + LMask) and not LMask;
  if LAligned < PtrUInt(FCurrentPtr) then
    Exit(nil);
  if (LAligned + PtrUInt(aSize)) > PtrUInt(FCurrentEnd) then
    Exit(nil);

  FCurrentPtr := PByte(LAligned + PtrUInt(aSize));
  FChunks[FChunkCount - 1].Used := SizeUInt(PtrUInt(FCurrentPtr) - PtrUInt(FCurrentBase));
  Inc(FTotalUsed, FChunks[FChunkCount - 1].Used);
  if FTotalUsed > FPeakUsed then
    FPeakUsed := FTotalUsed;
  Inc(FAllocCount);
  Result := Pointer(LAligned);
end;

function TArena.Alloc(aSize: SizeUInt): Pointer;
begin
  Result := InternalAlloc(aSize, FAlignment);
end;

function TArena.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  if (aAlignment = 0) or (not IsPowerOfTwo(aAlignment)) then
    Exit(nil);
  if aAlignment < SizeOf(Pointer) then
    aAlignment := SizeOf(Pointer);
  Result := InternalAlloc(aSize, aAlignment);
end;

function TArena.AllocZeroed(aSize: SizeUInt): Pointer;
begin
  Result := Alloc(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TArena.SaveMark: TArenaMark;
begin
  if FChunkCount > 0 then
  begin
    Result.ChunkIndex := FChunkCount - 1;
    Result.Offset := FChunks[FChunkCount - 1].Used;
  end
  else
  begin
    Result.ChunkIndex := 0;
    Result.Offset := 0;
  end;
end;

procedure TArena.RestoreToMark(AMark: TArenaMark);
var
  I: SizeInt;
begin
  if AMark.ChunkIndex >= FChunkCount then
    Exit;

  { 关闭标记之后的 chunks }
  for I := FChunkCount - 1 downto AMark.ChunkIndex + 1 do
  begin
    Dec(FTotalAllocated, FChunks[I].Map.Size);
    platform_mmap_close(FChunks[I].Map);
  end;
  FChunkCount := AMark.ChunkIndex + 1;

  { 恢复当前 chunk }
  FChunks[AMark.ChunkIndex].Used := AMark.Offset;

  FCurrentBase := PByte(FChunks[AMark.ChunkIndex].Map.Addr);
  FCurrentEnd := PByte(PtrUInt(FChunks[AMark.ChunkIndex].Map.Addr) + PtrUInt(FChunks[AMark.ChunkIndex].Map.Size));
  FCurrentPtr := PByte(PtrUInt(FCurrentBase) + PtrUInt(AMark.Offset));

  { 重新计算 TotalUsed 以保持一致性 }
  UpdateUsedFromChunks;
end;

procedure TArena.Reset;
var
  I: SizeInt;
begin
  for I := 0 to FChunkCount - 1 do
    FChunks[I].Used := 0;
  if FChunkCount > 0 then
  begin
    FCurrentBase := PByte(FChunks[0].Map.Addr);
    FCurrentEnd := PByte(PtrUInt(FChunks[0].Map.Addr) + PtrUInt(FChunks[0].Map.Size));
    FCurrentPtr := FCurrentBase;
  end;
  FTotalUsed := FLargeUsed;
end;

procedure TArena.Release;
begin
  TArena_Release(Self);
end;

function TArena.TotalAllocated: SizeUInt;
begin
  Result := FTotalAllocated;
end;

function TArena.TotalUsed: SizeUInt;
begin
  Result := FTotalUsed;
end;

function TArena.PeakUsed: SizeUInt;
begin
  Result := FPeakUsed;
end;

function TArena.AllocCount: SizeUInt;
begin
  Result := FAllocCount;
end;

{$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
initialization
  GArenaInstanceCount := 0;
  GArenaTotalMapped := 0;
finalization
  if GArenaInstanceCount <> 0 then
    WriteLn(stderr, 'WARNING: Arena leak detected: ', GArenaInstanceCount,
      ' instance(s) not released, ', GArenaTotalMapped, ' bytes mapped');
{$ENDIF}

{$POP}

end.
