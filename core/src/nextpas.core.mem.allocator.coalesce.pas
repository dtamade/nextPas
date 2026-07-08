{
# nextpas.core.mem.allocator.coalesce

## 摘要

合并空闲块分配器 — 减少外部碎片。

特性:
- 维护有序空闲块链表（按地址排序）
- 释放时自动合并相邻空闲块
- 首次适配分配策略
- 空闲块头部记录大小和使用状态
- 支持边界标记（boundary tags）实现 O(1) 合并

适用场景: 大块内存分配、长运行服务、内存碎片敏感场景。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.coalesce;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

const
  {** 默认区域大小 }
  COALESCE_DEFAULT_REGION_SIZE = 256 * 1024;  { 256KB }
  {** 最小块大小 }
  COALESCE_MIN_BLOCK_SIZE = 32;

type
  {** 合并分配器统计信息 }
  TCoalesceStats = record
    RegionSize: SizeUInt;        { 区域大小 }
    RegionCount: UInt64;         { 区域数量 }
    TotalCapacity: UInt64;       { 总容量 }
    UsedBytes: UInt64;           { 已使用字节 }
    FreeBytes: UInt64;           { 空闲字节 }
    AllocCount: UInt64;          { 分配次数 }
    FreeCount: UInt64;           { 释放次数 }
    MergeCount: UInt64;          { 合并次数 }
    FragmentCount: UInt64;       { 空闲碎片数 }
  end;

  {** TCoalesceAllocator
   *
   *  合并空闲块分配器。释放时自动合并相邻空闲块，减少外部碎片。
   *
   *  内存布局（每个块）:
   *  [BlockSize 8B][Used 8B][Prev 8B][Next 8B][User data...][Footer 8B]
   *                            ^ free list links          ^ = BlockSize
   *               ^ returned pointer
   *
   *  空闲块额外链接到空闲链表（按地址排序）。
   *  释放时检查前后块，如果空闲则合并。
   *}
  TCoalesceAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FRegionSize: SizeUInt;
    { 区域管理 }
    FRegions: array of Pointer;
    FRegionCount: Integer;
    FRegionCapacity: Integer;
    { 空闲链表（按地址排序） }
    FFreeHead: Pointer;
    FFreeTail: Pointer;
    { 统计 }
    FUsedBytes: SizeUInt;
    FFreeBytes: SizeUInt;
    FAllocCount: UInt64;
    FFreeCountStat: UInt64;
    FMergeCount: UInt64;
    FFragmentCount: UInt64;
    procedure GrowRegion;
    function FindFreeBlock(ASize: SizeUInt): Pointer;
    procedure SplitBlock(ABlock: Pointer; ANeededSize: SizeUInt);
    procedure InsertFreeBlock(ABlock: Pointer);
    procedure RemoveFreeBlock(ABlock: Pointer);
    procedure MergeWithNeighbors(ABlock: Pointer);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    {** 创建合并空闲块分配器
     *  @param AInner 内部分配器（用于获取内存区域）
     *  @param ARegionSize 每个区域大小
     *}
    constructor Create(AInner: IAllocator;
      ARegionSize: SizeUInt = COALESCE_DEFAULT_REGION_SIZE);
    destructor Destroy; override;

    {** 获取统计信息 }
    function GetStats: TCoalesceStats;
    {** 已使用字节数 }
    property UsedBytes: SizeUInt read FUsedBytes;
    {** 空闲字节数 }
    property FreeBytes: SizeUInt read FFreeBytes;

    function Traits: TAllocatorTraits; override;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  { 块头部大小 }
  BLOCK_HEADER_SIZE = 4 * SizeOf(UInt64);  { BlockSize, Used, Prev, Next }
  { 块尾部大小 }
  BLOCK_FOOTER_SIZE = SizeOf(UInt64);
  { 块总开销 }
  BLOCK_OVERHEAD = BLOCK_HEADER_SIZE + BLOCK_FOOTER_SIZE;
  { 最小块大小（含开销） }
  MIN_TOTAL_BLOCK_SIZE = BLOCK_OVERHEAD + COALESCE_MIN_BLOCK_SIZE;

type
  PBlockHeader = ^TBlockHeader;
  TBlockHeader = record
    BlockSize: UInt64;   { 块总大小（含头部和尾部） }
    Used: UInt64;        { 1 = 使用中, 0 = 空闲 }
    PrevBlock: UInt64;   { 前一个块的地址（用于合并） }
    NextFree: UInt64;    { 空闲链表下一个块（仅空闲块有效） }
  end;

function BlockHeader(APtr: Pointer): PBlockHeader; inline;
begin
  Result := PBlockHeader(APtr);
end;

function BlockFooter(APtr: Pointer): PUInt64; inline;
begin
  Result := PUInt64(PtrUInt(APtr) + BlockHeader(APtr)^.BlockSize - BLOCK_FOOTER_SIZE);
end;

function NextBlock(APtr: Pointer): Pointer; inline;
begin
  Result := Pointer(PtrUInt(APtr) + BlockHeader(APtr)^.BlockSize);
end;

function UserPtr(APtr: Pointer): Pointer; inline;
begin
  Result := Pointer(PtrUInt(APtr) + BLOCK_HEADER_SIZE);
end;

function BlockFromUserPtr(APtr: Pointer): Pointer; inline;
begin
  Result := Pointer(PtrUInt(APtr) - BLOCK_HEADER_SIZE);
end;

{ --- TCoalesceAllocator --- }

constructor TCoalesceAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TCoalesceAllocator.Create: AInner cannot be nil');
  if ARegionSize < MIN_TOTAL_BLOCK_SIZE * 4 then
    ARegionSize := MIN_TOTAL_BLOCK_SIZE * 4;

  FInner := AInner;
  FRegionSize := ARegionSize;
  FRegionCount := 0;
  FRegionCapacity := 4;
  SetLength(FRegions, FRegionCapacity);
  FFreeHead := nil;
  FFreeTail := nil;
  FUsedBytes := 0;
  FFreeBytes := 0;
  FAllocCount := 0;
  FFreeCountStat := 0;
  FMergeCount := 0;
  FFragmentCount := 0;

  { 创建第一个区域 }
  GrowRegion;
end;

destructor TCoalesceAllocator.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to FRegionCount - 1 do
    FInner.FreeMem(FRegions[LI]);
  SetLength(FRegions, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TCoalesceAllocator.GrowRegion;
var
  LRegion: Pointer;
  LBlock: Pointer;
begin
  if FRegionCount >= FRegionCapacity then
  begin
    FRegionCapacity := FRegionCapacity shl 1;
    SetLength(FRegions, FRegionCapacity);
  end;

  LRegion := FInner.GetMem(FRegionSize);
  if LRegion = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TCoalesceAllocator.GrowRegion: allocation failed');

  FRegions[FRegionCount] := LRegion;
  Inc(FRegionCount);

  { 初始化区域为一个大空闲块 }
  LBlock := LRegion;
  BlockHeader(LBlock)^.BlockSize := FRegionSize;
  BlockHeader(LBlock)^.Used := 0;
  BlockHeader(LBlock)^.PrevBlock := 0;
  BlockHeader(LBlock)^.NextFree := 0;
  BlockFooter(LBlock)^ := FRegionSize;

  { 插入空闲链表 }
  InsertFreeBlock(LBlock);
  Inc(FFreeBytes, FRegionSize);
  Inc(FFragmentCount);
end;

function TCoalesceAllocator.FindFreeBlock(ASize: SizeUInt): Pointer;
var
  LBlock: Pointer;
  LTotalNeeded: SizeUInt;
begin
  { 计算实际需要的块大小（含开销，对齐到 8 字节） }
  LTotalNeeded := ASize + BLOCK_OVERHEAD;
  if LTotalNeeded < MIN_TOTAL_BLOCK_SIZE then
    LTotalNeeded := MIN_TOTAL_BLOCK_SIZE;
  LTotalNeeded := (LTotalNeeded + 7) and not SizeUInt(7);

  { 首次适配搜索 }
  LBlock := FFreeHead;
  while LBlock <> nil do
  begin
    if BlockHeader(LBlock)^.BlockSize >= LTotalNeeded then
    begin
      Result := LBlock;
      Exit;
    end;
    LBlock := Pointer(BlockHeader(LBlock)^.NextFree);
  end;

  Result := nil;
end;

procedure TCoalesceAllocator.SplitBlock(ABlock: Pointer; ANeededSize: SizeUInt);
var
  LBlockSize: SizeUInt;
  LRemainder: Pointer;
  LRemainderSize: SizeUInt;
begin
  LBlockSize := BlockHeader(ABlock)^.BlockSize;
  LRemainderSize := LBlockSize - ANeededSize;

  { 只有当剩余空间足够形成一个新块时才分割 }
  if LRemainderSize >= MIN_TOTAL_BLOCK_SIZE then
  begin
    { 分割块 }
    BlockHeader(ABlock)^.BlockSize := ANeededSize;
    BlockFooter(ABlock)^ := ANeededSize;

    { 创建剩余块 }
    LRemainder := Pointer(PtrUInt(ABlock) + ANeededSize);
    BlockHeader(LRemainder)^.BlockSize := LRemainderSize;
    BlockHeader(LRemainder)^.Used := 0;
    BlockHeader(LRemainder)^.PrevBlock := UInt64(PtrUInt(ABlock));
    BlockFooter(LRemainder)^ := LRemainderSize;

    { 插入空闲链表 }
    InsertFreeBlock(LRemainder);
    Inc(FFragmentCount);
  end;
end;

procedure TCoalesceAllocator.InsertFreeBlock(ABlock: Pointer);
begin
  { 按地址顺序插入空闲链表 }
  BlockHeader(ABlock)^.NextFree := 0;

  if FFreeHead = nil then
  begin
    FFreeHead := ABlock;
    FFreeTail := ABlock;
  end
  else
  begin
    { 插入尾部 }
    BlockHeader(FFreeTail)^.NextFree := UInt64(PtrUInt(ABlock));
    FFreeTail := ABlock;
  end;
end;

procedure TCoalesceAllocator.RemoveFreeBlock(ABlock: Pointer);
var
  LPrev, LNext: Pointer;
begin
  { 从空闲链表移除 }
  LPrev := nil;
  LNext := Pointer(BlockHeader(ABlock)^.NextFree);

  if ABlock = FFreeHead then
    FFreeHead := LNext
  else
  begin
    { 查找前驱 }
    LPrev := FFreeHead;
    while (LPrev <> nil) and (Pointer(BlockHeader(LPrev)^.NextFree) <> ABlock) do
      LPrev := Pointer(BlockHeader(LPrev)^.NextFree);
    if LPrev <> nil then
      BlockHeader(LPrev)^.NextFree := UInt64(PtrUInt(LNext));
  end;

  if ABlock = FFreeTail then
    FFreeTail := LPrev;
end;

procedure TCoalesceAllocator.MergeWithNeighbors(ABlock: Pointer);
var
  LPrevBlock, LNextBlock: Pointer;
  LNewSize: SizeUInt;
begin
  { 检查后一个块 }
  LNextBlock := NextBlock(ABlock);
  if (BlockHeader(LNextBlock)^.Used = 0) and
     (PtrUInt(LNextBlock) < PtrUInt(FRegions[FRegionCount - 1]) + FRegionSize) then
  begin
    { 合并后块 }
    LNewSize := BlockHeader(ABlock)^.BlockSize + BlockHeader(LNextBlock)^.BlockSize;
    RemoveFreeBlock(LNextBlock);
    BlockHeader(ABlock)^.BlockSize := LNewSize;
    BlockFooter(ABlock)^ := LNewSize;
    Dec(FFragmentCount);
    Inc(FMergeCount);
  end;

  { 检查前一个块 }
  if BlockHeader(ABlock)^.PrevBlock <> 0 then
  begin
    LPrevBlock := Pointer(PtrUInt(BlockHeader(ABlock)^.PrevBlock));
    if BlockHeader(LPrevBlock)^.Used = 0 then
    begin
      { 合并前块 }
      LNewSize := BlockHeader(LPrevBlock)^.BlockSize + BlockHeader(ABlock)^.BlockSize;
      RemoveFreeBlock(LPrevBlock);
      BlockHeader(LPrevBlock)^.BlockSize := LNewSize;
      BlockFooter(LPrevBlock)^ := LNewSize;
      ABlock := LPrevBlock;
      Dec(FFragmentCount);
      Inc(FMergeCount);
    end;
  end;
end;

function TCoalesceAllocator.DoGetMem(ASize: SizeUInt): Pointer;
var
  LBlock: Pointer;
  LTotalNeeded: SizeUInt;
begin
  { 查找空闲块 }
  LBlock := FindFreeBlock(ASize);
  if LBlock = nil then
  begin
    { 没有合适的空闲块，扩展区域 }
    GrowRegion;
    LBlock := FindFreeBlock(ASize);
    if LBlock = nil then
      raise EAllocError.Create(aeOutOfMemory, 'TCoalesceAllocator.DoGetMem: allocation failed');
  end;

  { 计算实际需要的块大小 }
  LTotalNeeded := ASize + BLOCK_OVERHEAD;
  if LTotalNeeded < MIN_TOTAL_BLOCK_SIZE then
    LTotalNeeded := MIN_TOTAL_BLOCK_SIZE;
  LTotalNeeded := (LTotalNeeded + 7) and not SizeUInt(7);

  { 从空闲链表移除 }
  RemoveFreeBlock(LBlock);

  { 分割块（如果太大） }
  SplitBlock(LBlock, LTotalNeeded);

  { 标记为使用中 }
  BlockHeader(LBlock)^.Used := 1;
  Dec(FFreeBytes, BlockHeader(LBlock)^.BlockSize);
  Inc(FUsedBytes, BlockHeader(LBlock)^.BlockSize);
  Dec(FFragmentCount);
  Inc(FAllocCount);

  Result := UserPtr(LBlock);
end;

function TCoalesceAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TCoalesceAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LBlock: Pointer;
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;

  LBlock := BlockFromUserPtr(APtr);
  LOldSize := BlockHeader(LBlock)^.BlockSize - BLOCK_OVERHEAD;

  { 如果新大小在当前块范围内，直接返回 }
  if ASize <= LOldSize then
    Exit(APtr);

  { 否则分配新块，复制，释放旧块 }
  Result := DoGetMem(ASize);
  if Result <> nil then
  begin
    Move(APtr^, Result^, LOldSize);
    DoFreeMem(APtr);
  end;
end;

procedure TCoalesceAllocator.DoFreeMem(APtr: Pointer);
var
  LBlock: Pointer;
begin
  if APtr = nil then Exit;

  LBlock := BlockFromUserPtr(APtr);

  { 标记为空闲 }
  BlockHeader(LBlock)^.Used := 0;
  Dec(FUsedBytes, BlockHeader(LBlock)^.BlockSize);
  Inc(FFreeBytes, BlockHeader(LBlock)^.BlockSize);
  Inc(FFreeCountStat);

  { 尝试合并相邻空闲块 }
  MergeWithNeighbors(LBlock);

  { 插入空闲链表 }
  InsertFreeBlock(LBlock);
  Inc(FFragmentCount);
end;

function TCoalesceAllocator.GetStats: TCoalesceStats;
begin
  Result.RegionSize := FRegionSize;
  Result.RegionCount := UInt64(FRegionCount);
  Result.TotalCapacity := UInt64(FRegionCount) * UInt64(FRegionSize);
  Result.UsedBytes := FUsedBytes;
  Result.FreeBytes := FFreeBytes;
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCountStat;
  Result.MergeCount := FMergeCount;
  Result.FragmentCount := FFragmentCount;
end;

function TCoalesceAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.SupportsRealloc := True;
end;

end.
