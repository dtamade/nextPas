{
# nextpas.core.mem.allocator.slab

## 摘要

内核风格 slab 分配器 — 多 size class 对象池。

特性:
- 预定义多个 size class（8, 16, 32, 64, 128, 256, 512, 1024 字节）
- 每个 size class 维护独立的空闲链表
- 小对象分配: 选择合适的 size class，从对应 slab 分配 (O(1))
- 大对象分配: 直接委托给内部分配器
- 自动扩展: slab 耗尽时自动向内部分配器申请新页

适用场景: 通用内存分配，替代 malloc 的高性能方案。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.slab;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** Size class 数量 }
  SLAB_SIZE_CLASS_COUNT = 8;
  {** 最大 slab 对象大小 }
  SLAB_MAX_OBJECT_SIZE = 1024;
  {** 每个 slab 页的对象数 }
  SLAB_OBJECTS_PER_SLAB = 64;

type
  {** Size class 信息 }
  TSlabSizeClass = record
    ObjectSize: SizeUInt;    { 用户对象大小 }
    ActualSize: SizeUInt;    { 含头部的实际大小 }
    ObjectsPerSlab: UInt32;  { 每个 slab 页的对象数 }
  end;

  {** Slab 统计信息 }
  TSlabStats = record
    SmallAllocCount: UInt64;   { 小对象分配次数 }
    LargeAllocCount: UInt64;   { 大对象分配次数 }
    SmallFreeCount: UInt64;    { 小对象释放次数 }
    LargeFreeCount: UInt64;    { 大对象释放次数 }
    SlabPageCount: UInt64;     { slab 页总数 }
    FreeObjectCount: UInt64;   { 空闲对象总数 }
  end;

  {** TSlabAllocator
   *
   *  内核风格 slab 分配器。
   *  小对象（≤1024B）从预分配的 slab 页分配，O(1) 速度。
   *  大对象（>1024B）直接委托给内部分配器。
   *
   *  内存布局（slab 页内每个对象）:
   *  [ClassIndex 4B][NextPtr 8B][User data...]
   *                              ^ returned pointer
   *
   *  释放时通过 ClassIndex 头部确定 size class。
   *}
  TSlabAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    { Size class 表 }
    FSizeClasses: array[0..SLAB_SIZE_CLASS_COUNT - 1] of TSlabSizeClass;
    { 每个 size class 的空闲链表头 }
    FFreeHeads: array[0..SLAB_SIZE_CLASS_COUNT - 1] of Pointer;
    { 每个 size class 的空闲对象计数 }
    FFreeCounts: array[0..SLAB_SIZE_CLASS_COUNT - 1] of UInt64;
    { 每个 size class 的 slab 页列表（用于析构释放） }
    FSlabPages: array[0..SLAB_SIZE_CLASS_COUNT - 1] of array of Pointer;
    FSlabPageCounts: array[0..SLAB_SIZE_CLASS_COUNT - 1] of Integer;
    { 统计 }
    FSmallAllocCount: UInt64;
    FLargeAllocCount: UInt64;
    FSmallFreeCount: UInt64;
    FLargeFreeCount: UInt64;
    procedure InitSizeClasses;
    function FindSizeClass(ASize: SizeUInt): Int32;
    procedure GrowSlab(AClassIndex: Int32);
  public
    {** 创建 slab 分配器
     *  @param AInner 内部分配器（用于批量获取 slab 页和大对象）
     *}
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;

    {** 获取 slab 统计信息 }
    function GetStats: TSlabStats;
    {** 是否为 slab 管理的小对象 }
    function IsSmallObject(APtr: Pointer): Boolean;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  { Size class 定义 }
  SLAB_SIZES: array[0..SLAB_SIZE_CLASS_COUNT - 1] of SizeUInt = (
    8, 16, 32, 64, 128, 256, 512, 1024
  );
  { 头部存储 size class 索引（Int32），然后是 NextPtr (自由链表用) }
  SLAB_HEADER_SIZE = SizeOf(Int32);  { 4 bytes: size class index }

{ --- TSlabAllocator --- }

constructor TSlabAllocator.Create(AInner: IAllocator);
var
  LI: Int32;
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TSlabAllocator.Create: AInner cannot be nil');

  FInner := AInner;
  FSmallAllocCount := 0;
  FLargeAllocCount := 0;
  FSmallFreeCount := 0;
  FLargeFreeCount := 0;

  { 初始化 size class 表 }
  InitSizeClasses;

  { 初始化空闲链表 }
  for LI := 0 to SLAB_SIZE_CLASS_COUNT - 1 do
  begin
    FFreeHeads[LI] := nil;
    FFreeCounts[LI] := 0;
    FSlabPageCounts[LI] := 0;
    SetLength(FSlabPages[LI], 0);
  end;
end;

destructor TSlabAllocator.Destroy;
var
  LI, LJ: Int32;
begin
  { 释放所有 slab 页 }
  for LI := 0 to SLAB_SIZE_CLASS_COUNT - 1 do
  begin
    for LJ := 0 to FSlabPageCounts[LI] - 1 do
      FInner.FreeMem(FSlabPages[LI][LJ]);
    SetLength(FSlabPages[LI], 0);
  end;
  FInner := nil;
  inherited Destroy;
end;

procedure TSlabAllocator.InitSizeClasses;
var
  LI: Int32;
  LHeaderTotal: SizeUInt;
begin
  { 头部 = ClassIndex(4) + NextPtr(8) = 12, 向上对齐到 8 }
  LHeaderTotal := SLAB_HEADER_SIZE + SizeOf(Pointer);
  if LHeaderTotal mod 8 <> 0 then
    LHeaderTotal := LHeaderTotal + (8 - LHeaderTotal mod 8);
  for LI := 0 to SLAB_SIZE_CLASS_COUNT - 1 do
  begin
    FSizeClasses[LI].ObjectSize := SLAB_SIZES[LI];
    FSizeClasses[LI].ActualSize := LHeaderTotal + SLAB_SIZES[LI];
    FSizeClasses[LI].ObjectsPerSlab := SLAB_OBJECTS_PER_SLAB;
  end;
end;

function TSlabAllocator.FindSizeClass(ASize: SizeUInt): Int32;
var
  LI: Int32;
begin
  { 查找第一个 >= ASize 的 size class }
  for LI := 0 to SLAB_SIZE_CLASS_COUNT - 1 do
  begin
    if ASize <= FSizeClasses[LI].ObjectSize then
      Exit(LI);
  end;
  { 超出 slab 范围 }
  Result := -1;
end;

procedure TSlabAllocator.GrowSlab(AClassIndex: Int32);
var
  LSlabSize: UInt64;
  LSlab: Pointer;
  LI: UInt32;
  LPtr: Pointer;
begin
  { 计算 slab 页大小 }
  LSlabSize := UInt64(FSizeClasses[AClassIndex].ActualSize) *
    UInt64(FSizeClasses[AClassIndex].ObjectsPerSlab);

  { 从内部分配器获取 slab 页 }
  LSlab := FInner.GetMem(LSlabSize);
  if LSlab = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TSlabAllocator.GrowSlab: slab page allocation failed');

  { 记录 slab 页 }
  if FSlabPageCounts[AClassIndex] >= Length(FSlabPages[AClassIndex]) then
    SetLength(FSlabPages[AClassIndex], FSlabPageCounts[AClassIndex] + 8);
  FSlabPages[AClassIndex][FSlabPageCounts[AClassIndex]] := LSlab;
  Inc(FSlabPageCounts[AClassIndex]);

  { 将 slab 页切分为对象，串入空闲链表 }
  { 布局: [ClassIndex 4B][NextPtr 8B][User data...] }
  LPtr := LSlab;
  for LI := 0 to FSizeClasses[AClassIndex].ObjectsPerSlab - 1 do
  begin
    { 存储 ClassIndex 到头部 }
    PInt32(LPtr)^ := AClassIndex;
    { NextPtr 从头部偏移 SLAB_HEADER_SIZE 开始 }
    PPointer(PtrUInt(LPtr) + SLAB_HEADER_SIZE)^ := FFreeHeads[AClassIndex];
    FFreeHeads[AClassIndex] := LPtr;
    LPtr := Pointer(PtrUInt(LPtr) + FSizeClasses[AClassIndex].ActualSize);
  end;
  Inc(FFreeCounts[AClassIndex], FSizeClasses[AClassIndex].ObjectsPerSlab);
end;

function TSlabAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LClassIdx: Int32;
  LBlock: Pointer;
begin
  { 查找合适的 size class }
  LClassIdx := FindSizeClass(ASize);

  if LClassIdx >= 0 then
  begin
    { 小对象: 从 slab 分配 }
    if FFreeHeads[LClassIdx] = nil then
      GrowSlab(LClassIdx);
    LBlock := FFreeHeads[LClassIdx];
    FFreeHeads[LClassIdx] := PPointer(PtrUInt(LBlock) + SLAB_HEADER_SIZE)^;
    Dec(FFreeCounts[LClassIdx]);
    Inc(FSmallAllocCount);
    { 返回用户指针（跳过头部） }
    Result := Pointer(PtrUInt(LBlock) + SLAB_HEADER_SIZE + SizeOf(Pointer));
  end
  else
  begin
    { 大对象: 委托给内部分配器，添加头部以便 FreeMem 正确识别 }
    LBlock := FInner.GetMem(SLAB_HEADER_SIZE + SizeOf(Pointer) + ASize);
    if LBlock = nil then
      Exit(nil);
    PInt32(LBlock)^ := SLAB_SIZE_CLASS_COUNT;  { 哨兵值：标记为大对象 }
    Result := Pointer(PtrUInt(LBlock) + SLAB_HEADER_SIZE + SizeOf(Pointer));
    Inc(FLargeAllocCount);
  end;
end;

function TSlabAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TSlabAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LBlock: Pointer;
  LClassIdx: Int32;
  LOldSize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  { 查找旧块的 size class }
  LBlock := Pointer(PtrUInt(APtr) - SLAB_HEADER_SIZE - SizeOf(Pointer));
  LClassIdx := PInt32(LBlock)^;

  if (LClassIdx >= 0) and (LClassIdx < SLAB_SIZE_CLASS_COUNT) then
    LOldSize := FSizeClasses[LClassIdx].ObjectSize
  else
    LOldSize := ASize;  { 大对象: 保守假设 }

  { 如果新大小在旧块范围内，直接返回 }
  if ASize <= LOldSize then
    Exit(APtr);

  { 否则分配新块，复制，释放旧块 }
  Result := GetMem(ASize);
  if Result <> nil then
  begin
    Move(APtr^, Result^, LOldSize);
    FreeMem(APtr);
  end;
end;

procedure TSlabAllocator.FreeMem(APtr: Pointer); inline;
var
  LBlock: Pointer;
  LClassIdx: Int32;
begin
  if APtr = nil then Exit;

  { 回退到块起始位置（跳过用户指针前面的 NextPtr + ClassIndex） }
  LBlock := Pointer(PtrUInt(APtr) - SLAB_HEADER_SIZE - SizeOf(Pointer));
  LClassIdx := PInt32(LBlock)^;

  if (LClassIdx >= 0) and (LClassIdx < SLAB_SIZE_CLASS_COUNT) then
  begin
    { 小对象: 串回对应 size class 的空闲链表 }
    PPointer(PtrUInt(LBlock) + SLAB_HEADER_SIZE)^ := FFreeHeads[LClassIdx];
    FFreeHeads[LClassIdx] := LBlock;
    Inc(FFreeCounts[LClassIdx]);
    Inc(FSmallFreeCount);
  end
  else
  begin
    { 大对象: 委托给内部分配器（释放带头部的原始块） }
    FInner.FreeMem(LBlock);
    Inc(FLargeFreeCount);
  end;
end;

function TSlabAllocator.GetStats: TSlabStats;
var
  LI: Int32;
begin
  Result.SmallAllocCount := FSmallAllocCount;
  Result.LargeAllocCount := FLargeAllocCount;
  Result.SmallFreeCount := FSmallFreeCount;
  Result.LargeFreeCount := FLargeFreeCount;
  Result.SlabPageCount := 0;
  Result.FreeObjectCount := 0;
  for LI := 0 to SLAB_SIZE_CLASS_COUNT - 1 do
  begin
    Inc(Result.SlabPageCount, UInt64(FSlabPageCounts[LI]));
    Inc(Result.FreeObjectCount, FFreeCounts[LI]);
  end;
end;

function TSlabAllocator.IsSmallObject(APtr: Pointer): Boolean;
var
  LBlock: Pointer;
  LClassIdx: Int32;
begin
  LBlock := Pointer(PtrUInt(APtr) - SLAB_HEADER_SIZE - SizeOf(Pointer));
  LClassIdx := PInt32(LBlock)^;
  Result := (LClassIdx >= 0) and (LClassIdx < SLAB_SIZE_CLASS_COUNT);
end;

function TSlabAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := True;
end;

end.
