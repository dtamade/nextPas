{
# nextpas.core.mem.allocator.stack

## 摘要

栈式分配器 — LIFO 顺序分配/释放，零碎片。

特性:
- 线性内存区域，按栈方式分配
- 仅支持 LIFO 顺序释放（最后分配的最先释放）
- 零外部碎片（空闲空间总是连续的）
- 可选自动扩展（通过内部分配器获取新区域）
- Mark/Restore 机制：保存栈状态，批量回滚

适用场景: 临时计算缓冲、解析器临时数据、表达式求值。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.stack;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 默认栈区域大小 }
  STACK_DEFAULT_REGION_SIZE = 64 * 1024;  { 64KB }
  {** 最大保存的标记数 }
  STACK_MAX_MARKS = 32;

type
  {** 栈标记（用于 Restore 回滚） }
  TStackMark = record
    RegionIndex: Integer;   { 当前区域索引 }
    Offset: SizeUInt;       { 区域内偏移 }
    TotalUsed: SizeUInt;    { 总使用量 }
  end;

  {** 栈统计信息 }
  TStackStats = record
    RegionSize: SizeUInt;       { 每个区域大小 }
    RegionCount: UInt64;        { 区域数量 }
    TotalCapacity: UInt64;      { 总容量 }
    UsedBytes: UInt64;          { 已使用字节 }
    AllocCount: UInt64;         { 分配次数 }
    MarkCount: UInt64;          { 标记次数 }
    RestoreCount: UInt64;       { 回滚次数 }
  end;

  {** TStackAllocator
   *
   *  栈式分配器。LIFO 顺序分配/释放，零碎片。
   *  支持 Mark/Restore 机制批量回滚。
   *
   *  内存布局:
   *  [Region 0: 64KB][Region 1: 64KB][Region 2: 64KB]...
   *                    ^ current region
   *
   *  每个区域内:
   *  [used bytes...][free bytes...]
   *                  ^ next alloc position
   *}
  TStackAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FRegionSize: SizeUInt;
    { 区域管理 }
    FRegions: array of Pointer;
    FRegionCount: Integer;
    FRegionCapacity: Integer;
    { 当前分配位置 }
    FCurrentRegion: Integer;
    FCurrentOffset: SizeUInt;
    FTotalUsed: SizeUInt;
    { 标记栈 }
    FMarks: array[0..STACK_MAX_MARKS - 1] of TStackMark;
    FMarkCount: Integer;
    { 统计 }
    FAllocCount: UInt64;
    FMarkCountStat: UInt64;
    FRestoreCountStat: UInt64;
    procedure GrowRegion;
    function InternalAlloc(ASize: SizeUInt): Pointer;
  public
    {** 创建栈式分配器
     *  @param AInner 内部分配器（用于获取内存区域）
     *  @param ARegionSize 每个区域大小
     *}
    constructor Create(AInner: IAllocator;
      ARegionSize: SizeUInt = STACK_DEFAULT_REGION_SIZE);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;

    {** 保存当前栈状态 }
    function Mark: TStackMark;
    {** 恢复到指定标记（释放标记之后的所有分配） }
    procedure Restore(const AMark: TStackMark);
    {** 重置到初始状态（释放所有区域） }
    procedure Reset;
    {** 获取统计信息 }
    function GetStats: TStackStats;
    {** 已使用字节数 }
    property UsedBytes: SizeUInt read FTotalUsed;
    {** 区域数量 }
    property RegionCount: Integer read FRegionCount;
  end;

implementation

uses
  nextpas.core.mem.error;

{ --- TStackAllocator --- }

constructor TStackAllocator.Create(AInner: IAllocator; ARegionSize: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TStackAllocator.Create: AInner cannot be nil');
  if ARegionSize < 1024 then
    ARegionSize := 1024;  { 最小 1KB }

  FInner := AInner;
  FRegionSize := ARegionSize;
  FRegionCount := 0;
  FRegionCapacity := 4;
  SetLength(FRegions, FRegionCapacity);
  FCurrentRegion := -1;
  FCurrentOffset := 0;
  FTotalUsed := 0;
  FMarkCount := 0;
  FAllocCount := 0;
  FMarkCountStat := 0;
  FRestoreCountStat := 0;

  { 创建第一个区域 }
  GrowRegion;
end;

destructor TStackAllocator.Destroy;
begin
  Reset;
  SetLength(FRegions, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TStackAllocator.GrowRegion;
var
  LRegion: Pointer;
begin
  { 扩展区域数组 }
  if FRegionCount >= FRegionCapacity then
  begin
    FRegionCapacity := FRegionCapacity shl 1;
    SetLength(FRegions, FRegionCapacity);
  end;

  { 从内部分配器获取新区域 }
  LRegion := FInner.GetMem(FRegionSize);
  if LRegion = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TStackAllocator.GrowRegion: region allocation failed');

  FRegions[FRegionCount] := LRegion;
  Inc(FRegionCount);
  FCurrentRegion := FRegionCount - 1;
  FCurrentOffset := 0;
end;

function TStackAllocator.InternalAlloc(ASize: SizeUInt): Pointer;
var
  LAlignedSize: SizeUInt;
begin
  { 对齐到 8 字节 }
  LAlignedSize := (ASize + 7) and not SizeUInt(7);

  { 检查当前区域是否有足够空间 }
  if FCurrentOffset + LAlignedSize > FRegionSize then
  begin
    { 当前区域空间不足，需要新区域 }
    if LAlignedSize > FRegionSize then
      raise EAllocError.Create(aeOutOfMemory,
        'TStackAllocator.InternalAlloc: allocation size exceeds region size');
    GrowRegion;
  end;

  { 从当前区域分配 }
  Result := Pointer(PtrUInt(FRegions[FCurrentRegion]) + FCurrentOffset);
  Inc(FCurrentOffset, LAlignedSize);
  Inc(FTotalUsed, LAlignedSize);
  Inc(FAllocCount);
end;

function TStackAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := InternalAlloc(ASize);
end;

function TStackAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := InternalAlloc(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TStackAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  { 栈式分配器不支持真正的 Realloc }
  { 简单实现：分配新块，复制旧数据 }
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);

  Result := GetMem(ASize);
  if Result <> nil then
    Move(APtr^, Result^, ASize);  { 保守复制 }
  { 注意：旧内存不会被释放（栈式分配器不支持单独释放） }
end;

procedure TStackAllocator.FreeMem(APtr: Pointer); inline;
begin
  { 栈式分配器不支持单独释放 }
  { 只能通过 Mark/Restore 或 Reset 回滚 }
  { 忽略调用 }
end;

function TStackAllocator.Mark: TStackMark;
begin
  if FMarkCount >= STACK_MAX_MARKS then
    raise EAllocError.Create(aeOutOfMemory, 'TStackAllocator.Mark: too many marks');

  Result.RegionIndex := FCurrentRegion;
  Result.Offset := FCurrentOffset;
  Result.TotalUsed := FTotalUsed;

  FMarks[FMarkCount] := Result;
  Inc(FMarkCount);
  Inc(FMarkCountStat);
end;

procedure TStackAllocator.Restore(const AMark: TStackMark);
var
  LI: Integer;
begin
  { 释放标记之后的区域 }
  for LI := FRegionCount - 1 downto AMark.RegionIndex + 1 do
  begin
    FInner.FreeMem(FRegions[LI]);
    FRegions[LI] := nil;
    Dec(FRegionCount);
  end;

  { 恢复到标记位置 }
  FCurrentRegion := AMark.RegionIndex;
  FCurrentOffset := AMark.Offset;
  FTotalUsed := AMark.TotalUsed;

  { 更新标记栈 }
  while (FMarkCount > 0) and
        ((FMarks[FMarkCount - 1].RegionIndex > AMark.RegionIndex) or
         ((FMarks[FMarkCount - 1].RegionIndex = AMark.RegionIndex) and
          (FMarks[FMarkCount - 1].Offset > AMark.Offset))) do
    Dec(FMarkCount);

  Inc(FRestoreCountStat);
end;

procedure TStackAllocator.Reset;
var
  LI: Integer;
begin
  { 释放所有区域（保留第一个） }
  for LI := FRegionCount - 1 downto 1 do
  begin
    FInner.FreeMem(FRegions[LI]);
    FRegions[LI] := nil;
  end;
  FRegionCount := 1;
  FCurrentRegion := 0;
  FCurrentOffset := 0;
  FTotalUsed := 0;
  FMarkCount := 0;
end;

function TStackAllocator.GetStats: TStackStats;
begin
  Result.RegionSize := FRegionSize;
  Result.RegionCount := UInt64(FRegionCount);
  Result.TotalCapacity := UInt64(FRegionCount) * UInt64(FRegionSize);
  Result.UsedBytes := FTotalUsed;
  Result.AllocCount := FAllocCount;
  Result.MarkCount := FMarkCountStat;
  Result.RestoreCount := FRestoreCountStat;
end;

function TStackAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := False;
end;

end.
