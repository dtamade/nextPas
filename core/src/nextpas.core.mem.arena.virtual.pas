unit nextpas.core.mem.arena.virtual;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.platform.mmap,
  nextpas.core.platform.memory;

type
  {** TVirtualArena
   *
   *  预留虚拟地址空间的 bump 分配器，使用 mmap 预分配虚拟地址空间。
   *  适用于编译器热路径等需要极低开销分配的场景。
   *
   *  关键优化：
   *  1. 预分配虚拟地址空间（避免动态数组扩展拷贝）
   *  2. 双向 bump pointer（含指针对象从前往后，无指针对象从后往前）
   *  3. 增量更新统计信息（避免每次分配重新计算）
   *
   *  非线程安全。多线程环境请自行加锁。
   *}
  TVirtualArena = record
  private
    { 预分配的虚拟地址空间 }
    FReservedBase: Pointer;
    FReservedSize: SizeUInt;
    FFrontCommittedSize: SizeUInt;  { committed from front (base → base+size) }
    FBackCommittedSize: SizeUInt;   { committed from back (end-size → end) }

    { 双向 bump pointer }
    FFrontPtr: PByte;
    FFrontEnd: PByte;
    FBackPtr: PByte;
    FBackBase: PByte;

    { 大对象独立跟踪 }
    FLargeBlocks: array of TPlatformMappedFile;
    FLargeCount: SizeInt;

    { 配置 }
    FAlignment: SizeUInt;

    { 统计信息（增量更新） }
    FTotalAllocated: SizeUInt;
    FTotalUsed: SizeUInt;
    FLargeUsed: SizeUInt;
    FPeakUsed: SizeUInt;
    FAllocCount: SizeUInt;

    function CommitFrontRegion(aSize: SizeUInt): Boolean;
    function CommitBackRegion(aSize: SizeUInt): Boolean;
    function TrackLargeBlock(const AMap: TPlatformMappedFile): Pointer;
  public
    {** 分配 ASize 字节（含指针对象），返回对齐后的指针；失败返回 nil }
    function Alloc(aSize: SizeUInt): Pointer;
    {** 分配 ASize 字节（无指针对象），返回对齐后的指针；失败返回 nil }
    function AllocNoPointer(aSize: SizeUInt): Pointer;
    {** 分配 ASize 字节，按 AAlignment 对齐；对齐必须是 2 的幂 }
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    {** 分配 ASize 字节并清零 }
    function AllocZeroed(aSize: SizeUInt): Pointer;
    {** 保存当前分配位置 }
    function SaveMark: TArenaMark;
    {** 恢复到标记位置 }
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena（保留虚拟地址空间，从头开始分配） }
    procedure Reset;
    {** 释放所有资源 }
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

{** 初始化 TVirtualArena }
procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
{** 释放 TVirtualArena 所有资源 }
procedure TVirtualArena_Release(var AArena: TVirtualArena);

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in arena internals

{$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
var
  GArenaInstanceCount: Integer;
  GArenaTotalMapped: SizeUInt;
{$ENDIF}

procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt);
begin
  if (AAlignment = 0) or (not IsPowerOfTwo(AAlignment)) then
    AArena.FAlignment := DEFAULT_ALIGNMENT
  else if AAlignment < SizeOf(Pointer) then
    AArena.FAlignment := SizeOf(Pointer)
  else
    AArena.FAlignment := AAlignment;

  AArena.FReservedBase := platform_virtual_reserve(ARENA_VIRTUAL_RESERVE);
  if AArena.FReservedBase = nil then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TVirtualArena_Init: failed to reserve virtual address space');

  AArena.FReservedSize := ARENA_VIRTUAL_RESERVE;
  AArena.FFrontCommittedSize := 0;
  AArena.FBackCommittedSize := 0;

  AArena.FFrontPtr := PByte(AArena.FReservedBase);
  AArena.FFrontEnd := PByte(PtrUInt(AArena.FReservedBase) + PtrUInt(ARENA_VIRTUAL_RESERVE));
  AArena.FBackPtr := PByte(PtrUInt(AArena.FReservedBase) + PtrUInt(ARENA_VIRTUAL_RESERVE));
  AArena.FBackBase := PByte(AArena.FReservedBase);

  AArena.FLargeBlocks := nil;
  AArena.FLargeCount := 0;

  AArena.FTotalAllocated := ARENA_VIRTUAL_RESERVE;
  AArena.FTotalUsed := 0;
  AArena.FLargeUsed := 0;
  AArena.FPeakUsed := 0;
  AArena.FAllocCount := 0;

  {$IFDEF NEXTPAS_ARENA_LEAK_CHECK}
  InterLockedIncrement(GArenaInstanceCount);
  Inc(GArenaTotalMapped, ARENA_VIRTUAL_RESERVE);
  {$ENDIF}
end;

procedure TVirtualArena_Release(var AArena: TVirtualArena);
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

  if AArena.FReservedBase <> nil then
  begin
    platform_virtual_release(AArena.FReservedBase, AArena.FReservedSize);
    AArena.FReservedBase := nil;
  end;

  for I := 0 to AArena.FLargeCount - 1 do
    platform_mmap_close(AArena.FLargeBlocks[I]);
  AArena.FLargeBlocks := nil;
  AArena.FLargeCount := 0;

  AArena.FReservedSize := 0;
  AArena.FFrontCommittedSize := 0;
  AArena.FBackCommittedSize := 0;
  AArena.FFrontPtr := nil;
  AArena.FFrontEnd := nil;
  AArena.FBackPtr := nil;
  AArena.FBackBase := nil;
  AArena.FTotalAllocated := 0;
  AArena.FTotalUsed := 0;
  AArena.FLargeUsed := 0;
  AArena.FPeakUsed := 0;
  AArena.FAllocCount := 0;
end;

const
  { Minimum commit chunk size to amortize mmap syscall overhead }
  COMMIT_CHUNK_SIZE: SizeUInt = 2 * 1024 * 1024; { 2MB }

function TVirtualArena.CommitFrontRegion(aSize: SizeUInt): Boolean;
var
  LCommitSize: SizeUInt;
  LCommitPtr: PByte;
  LMaxCommit: SizeUInt;
begin
  Result := False;

  { Round up to page boundary }
  LCommitSize := (aSize + MEM_PAGE_SIZE - 1) and not (MEM_PAGE_SIZE - 1);
  { Commit at least COMMIT_CHUNK_SIZE to amortize syscall overhead }
  if LCommitSize < COMMIT_CHUNK_SIZE then
    LCommitSize := COMMIT_CHUNK_SIZE;

  LMaxCommit := FReservedSize - FBackCommittedSize;
  if (FFrontCommittedSize + LCommitSize) > LMaxCommit then
  begin
    { Fallback: try exact size if chunk exceeds available }
    LCommitSize := (aSize + MEM_PAGE_SIZE - 1) and not (MEM_PAGE_SIZE - 1);
    if (FFrontCommittedSize + LCommitSize) > LMaxCommit then
      Exit;
  end;

  LCommitPtr := PByte(PtrUInt(FReservedBase) + FFrontCommittedSize);
  if not platform_virtual_commit(LCommitPtr, LCommitSize) then
    Exit;

  { Advise THP for large commits (>= 2MB) }
  if LCommitSize >= SizeUInt(2 * 1024 * 1024) then
    platform_madvise_thp(LCommitPtr, LCommitSize);

  FFrontCommittedSize := FFrontCommittedSize + LCommitSize;
  Result := True;
end;

function TVirtualArena.CommitBackRegion(aSize: SizeUInt): Boolean;
var
  LCommitSize: SizeUInt;
  LCommitPtr: PByte;
  LMaxCommit: SizeUInt;
begin
  Result := False;

  { Round up to page boundary }
  LCommitSize := (aSize + MEM_PAGE_SIZE - 1) and not (MEM_PAGE_SIZE - 1);
  { Commit at least COMMIT_CHUNK_SIZE to amortize syscall overhead }
  if LCommitSize < COMMIT_CHUNK_SIZE then
    LCommitSize := COMMIT_CHUNK_SIZE;

  LMaxCommit := FReservedSize - FFrontCommittedSize;
  if (FBackCommittedSize + LCommitSize) > LMaxCommit then
  begin
    { Fallback: try exact size if chunk exceeds available }
    LCommitSize := (aSize + MEM_PAGE_SIZE - 1) and not (MEM_PAGE_SIZE - 1);
    if (FBackCommittedSize + LCommitSize) > LMaxCommit then
      Exit;
  end;

  { Commit from the end of the reservation backward }
  LCommitPtr := PByte(PtrUInt(FReservedBase) + FReservedSize - FBackCommittedSize - LCommitSize);
  if not platform_virtual_commit(LCommitPtr, LCommitSize) then
    Exit;

  { Advise THP for large commits (>= 2MB) }
  if LCommitSize >= SizeUInt(2 * 1024 * 1024) then
    platform_madvise_thp(LCommitPtr, LCommitSize);

  FBackCommittedSize := FBackCommittedSize + LCommitSize;
  Result := True;
end;

function TVirtualArena.TrackLargeBlock(const AMap: TPlatformMappedFile): Pointer;
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
  Result := AMap.Addr;
end;

function TVirtualArena.Alloc(aSize: SizeUInt): Pointer;
var
  LAligned: PtrUInt;
  LMask: PtrUInt;
  LNeedCommit: SizeUInt;
  LMap: TPlatformMappedFile;
begin
  Result := nil;
  if aSize = 0 then
    Exit;

  if aSize >= ARENA_LARGE_THRESHOLD then
  begin
    if platform_mmap_create_anonymous(UInt64(aSize), pmaReadWrite, [pmfPrivate], LMap) <> 0 then
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

  { Fast path: default alignment (already guaranteed aligned by Init) }
  LAligned := PtrUInt(FFrontPtr);
  if FAlignment > SizeOf(Pointer) then
  begin
    LMask := PtrUInt(FAlignment - 1);
    LAligned := (LAligned + LMask) and not LMask;
  end;

  LNeedCommit := (LAligned + PtrUInt(aSize)) - PtrUInt(FReservedBase);
  if LNeedCommit > FFrontCommittedSize then
  begin
    if not CommitFrontRegion(LNeedCommit - FFrontCommittedSize) then
      Exit;
  end;

  if (LAligned + PtrUInt(aSize)) > PtrUInt(FFrontEnd) then
    Exit;

  FFrontPtr := PByte(LAligned + PtrUInt(aSize));
  Inc(FTotalUsed, aSize);
  if FTotalUsed > FPeakUsed then
    FPeakUsed := FTotalUsed;
  Inc(FAllocCount);
  Result := Pointer(LAligned);
end;

function TVirtualArena.AllocNoPointer(aSize: SizeUInt): Pointer;
var
  LAligned: PtrUInt;
  LMask: PtrUInt;
  LNeedCommit: SizeUInt;
  LMap: TPlatformMappedFile;
begin
  Result := nil;
  if aSize = 0 then
    Exit;

  if aSize >= ARENA_LARGE_THRESHOLD then
  begin
    if platform_mmap_create_anonymous(UInt64(aSize), pmaReadWrite, [pmfPrivate], LMap) <> 0 then
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

  LMask := PtrUInt(FAlignment - 1);
  FBackPtr := PByte(PtrUInt(FBackPtr) - PtrUInt(aSize));
  LAligned := PtrUInt(FBackPtr) and not LMask;

  LNeedCommit := PtrUInt(FReservedBase) + FReservedSize - LAligned;
  if LNeedCommit > FBackCommittedSize then
  begin
    if not CommitBackRegion(LNeedCommit - FBackCommittedSize) then
    begin
      FBackPtr := PByte(PtrUInt(FBackPtr) + PtrUInt(aSize));
      Exit;
    end;
  end;

  if LAligned < PtrUInt(FFrontPtr) then
  begin
    FBackPtr := PByte(PtrUInt(FBackPtr) + PtrUInt(aSize));
    Exit;
  end;

  Inc(FTotalUsed, aSize);
  if FTotalUsed > FPeakUsed then
    FPeakUsed := FTotalUsed;
  Inc(FAllocCount);
  Result := Pointer(LAligned);
end;

function TVirtualArena.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LAligned: PtrUInt;
  LMask: PtrUInt;
  LNeedCommit: SizeUInt;
  LMap: TPlatformMappedFile;
begin
  Result := nil;
  if aSize = 0 then
    Exit;
  if (aAlignment = 0) or (not IsPowerOfTwo(aAlignment)) then
    Exit;
  if aAlignment < SizeOf(Pointer) then
    aAlignment := SizeOf(Pointer);

  if aSize >= ARENA_LARGE_THRESHOLD then
  begin
    if platform_mmap_create_anonymous(UInt64(aSize), pmaReadWrite, [pmfPrivate], LMap) <> 0 then
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

  LMask := PtrUInt(aAlignment - 1);
  LAligned := (PtrUInt(FFrontPtr) + LMask) and not LMask;

  LNeedCommit := (LAligned + PtrUInt(aSize)) - PtrUInt(FReservedBase);
  if LNeedCommit > FFrontCommittedSize then
  begin
    if not CommitFrontRegion(LNeedCommit - FFrontCommittedSize) then
      Exit;
  end;

  if (LAligned + PtrUInt(aSize)) > PtrUInt(FFrontEnd) then
    Exit;

  FFrontPtr := PByte(LAligned + PtrUInt(aSize));
  Inc(FTotalUsed, aSize);
  if FTotalUsed > FPeakUsed then
    FPeakUsed := FTotalUsed;
  Inc(FAllocCount);
  Result := Pointer(LAligned);
end;

function TVirtualArena.AllocZeroed(aSize: SizeUInt): Pointer;
begin
  Result := Alloc(aSize);
  if Result <> nil then
    FillChar(Result^, aSize, 0);
end;

function TVirtualArena.SaveMark: TArenaMark;
begin
  Result.FrontOffset := SizeUInt(PtrUInt(FFrontPtr) - PtrUInt(FReservedBase));
  Result.BackOffset := SizeUInt(PtrUInt(FBackPtr) - PtrUInt(FReservedBase));
  Result.TotalUsed := FTotalUsed;
end;

procedure TVirtualArena.RestoreToMark(AMark: TArenaMark);
var
  LNewFront: PByte;
  LNewBack: PByte;
begin
  LNewFront := PByte(PtrUInt(FReservedBase) + AMark.FrontOffset);
  LNewBack := PByte(PtrUInt(FReservedBase) + AMark.BackOffset);

  FFrontPtr := LNewFront;
  FBackPtr := LNewBack;
  FTotalUsed := AMark.TotalUsed;
end;

procedure TVirtualArena.Reset;
begin
  { Decommit physical pages; virtual address space stays reserved }
  if FFrontCommittedSize > 0 then
    platform_virtual_decommit(FReservedBase, FFrontCommittedSize);
  if FBackCommittedSize > 0 then
    platform_virtual_decommit(
      Pointer(PtrUInt(FReservedBase) + FReservedSize - FBackCommittedSize),
      FBackCommittedSize);
  FFrontCommittedSize := 0;
  FBackCommittedSize := 0;

  FFrontPtr := PByte(FReservedBase);
  FBackPtr := PByte(PtrUInt(FReservedBase) + PtrUInt(FReservedSize));

  FTotalUsed := FLargeUsed;
  FAllocCount := 0;
end;

procedure TVirtualArena.Release;
begin
  TVirtualArena_Release(Self);
end;

function TVirtualArena.TotalAllocated: SizeUInt;
begin
  Result := FTotalAllocated;
end;

function TVirtualArena.TotalUsed: SizeUInt;
begin
  Result := FTotalUsed;
end;

function TVirtualArena.PeakUsed: SizeUInt;
begin
  Result := FPeakUsed;
end;

function TVirtualArena.AllocCount: SizeUInt;
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
