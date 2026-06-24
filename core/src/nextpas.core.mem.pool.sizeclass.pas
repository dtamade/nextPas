{******************************************************************************
  nextpas.core.mem.pool.sizeclass — 大小类 Slab 分配器

  7 个大小类: 8/16/32/64/128/256/512 字节
  每类维护 intrusive free list, O(1) 分配释放。
  页级后备: 4KB 页从 GetMem 获取, 切分为固定大小 slots。

  性能目标:
    - Alloc: ~5ns (pop from free list)
    - Free:  ~3ns (push to free list)
    - 对标 jemalloc/tcmalloc 小对象优化

  设计约束:
    - 非线程安全 (外部使用 TSlabPoolConcurrent 或 TThreadArena 保护)
    - Free 必须传入正确 size class (调用方负责)
    - 不支持 realloc (arena 模式: 只分配不释放或整体重置)
******************************************************************************}
unit nextpas.core.mem.pool.sizeclass;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error;

const
  { 大小类数量 }
  SIZE_CLASS_COUNT = 7;
  { 页大小 }
  SC_PAGE_SIZE = 4096;

type
  {** 大小类索引 (0=8B, 1=16B, 2=32B, 3=64B, 4=128B, 5=256B, 6=512B) }
  TSizeClassIndex = 0..SIZE_CLASS_COUNT - 1;

  {** 大小类 Slab 池 }
  TSizeClassPool = class
  private
    { 每个大小类的状态 }
    FFreeHeads: array[TSizeClassIndex] of Pointer;   { free list 头 }
    FSlotSizes: array[TSizeClassIndex] of SizeUInt;  { 实际 slot 大小 (>= 8) }
    FClassCounts: array[TSizeClassIndex] of SizeUInt; { 当前 free slot 数 }
    FTotalAllocs: array[TSizeClassIndex] of SizeUInt; { 累计分配次数 }
    { 页管理 }
    FPages: array[TSizeClassIndex] of array of Pointer; { 已分配页 }
    FPageCounts: array[TSizeClassIndex] of SizeInt;     { 页计数 }
    { 统计 }
    FTotalSlots: SizeUInt;
    FTotalPages: SizeUInt;

    procedure AllocatePage(AClass: TSizeClassIndex);
    function ClassIndexForSize(ASize: SizeUInt): TSizeClassIndex;
  public
    constructor Create;
    destructor Destroy; override;

    {** 分配至少 ASize 字节的内存块。返回 nil 表示分配失败。 }
    function Alloc(ASize: SizeUInt): Pointer;
    {** 释放之前分配的内存块。APtr 必须来自 Alloc，ASize 必须与分配时相同。 }
    procedure Release(APtr: Pointer; ASize: SizeUInt);
    {** 重置所有 free list (不释放页, 所有 slot 回到 free list) }
    procedure Reset;

    {** 统计: 指定大小类的空闲 slot 数 }
    function FreeCount(AClass: TSizeClassIndex): SizeUInt;
    {** 统计: 指定大小类的 slot 大小 }
    function SlotSize(AClass: TSizeClassIndex): SizeUInt;
    {** 统计: 已分配页总数 }
    function PageCount: SizeUInt;
    {** 统计: 累计分配次数 }
    function TotalAllocCount: SizeUInt;
  end;

{** 根据字节数返回对应的大小类索引。超出 512B 返回 -1。 }
function SizeClassIndex(ASize: SizeUInt): Integer;

const
  { 大小类表: 8/16/32/64/128/256/512 字节 }
  SIZE_CLASSES: array[TSizeClassIndex] of SizeUInt = (8, 16, 32, 64, 128, 256, 512);

implementation

function SizeClassIndex(ASize: SizeUInt): Integer;
begin
  if ASize <= 8 then Exit(0);
  if ASize <= 16 then Exit(1);
  if ASize <= 32 then Exit(2);
  if ASize <= 64 then Exit(3);
  if ASize <= 128 then Exit(4);
  if ASize <= 256 then Exit(5);
  if ASize <= 512 then Exit(6);
  Result := -1;
end;

{ ---------------------------------------------------------------------------
  TSizeClassPool
  --------------------------------------------------------------------------- }

constructor TSizeClassPool.Create;
var
  I: TSizeClassIndex;
begin
  inherited Create;
  for I := Low(TSizeClassIndex) to High(TSizeClassIndex) do
  begin
    FSlotSizes[I] := SIZE_CLASSES[I];
    FFreeHeads[I] := nil;
    FClassCounts[I] := 0;
    FTotalAllocs[I] := 0;
    FPages[I] := nil;
    FPageCounts[I] := 0;
  end;
  FTotalSlots := 0;
  FTotalPages := 0;
end;

destructor TSizeClassPool.Destroy;
var
  I: TSizeClassIndex;
  J: Integer;
begin
  for I := Low(TSizeClassIndex) to High(TSizeClassIndex) do
  begin
    for J := 0 to FPageCounts[I] - 1 do
      FreeMem(FPages[I][J]);
    FPages[I] := nil;
    FPageCounts[I] := 0;
  end;
  inherited Destroy;
end;

procedure TSizeClassPool.AllocatePage(AClass: TSizeClassIndex);
var
  LPage: Pointer;
  LSlotSize: SizeUInt;
  LCount: SizeUInt;
  LPtr: PPointer;
  I: SizeUInt;
begin
  LSlotSize := FSlotSizes[AClass];
  { 每页能容纳的 slot 数 (至少 1) }
  LCount := SC_PAGE_SIZE div LSlotSize;
  if LCount = 0 then
    LCount := 1;

  LPage := GetMem(LSlotSize * LCount);
  if LPage = nil then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TSizeClassPool.AllocatePage: out of memory');

  { 记录页 }
  if FPageCounts[AClass] >= Length(FPages[AClass]) then
  begin
    if Length(FPages[AClass]) = 0 then
      SetLength(FPages[AClass], 4)
    else
      SetLength(FPages[AClass], Length(FPages[AClass]) * 2);
  end;
  FPages[AClass][FPageCounts[AClass]] := LPage;
  Inc(FPageCounts[AClass]);
  Inc(FTotalPages);

  { 将页切分为 slots, 串入 free list }
  for I := 0 to LCount - 1 do
  begin
    LPtr := PPointer(PtrUInt(LPage) + I * LSlotSize);
    LPtr^ := FFreeHeads[AClass];
    FFreeHeads[AClass] := LPtr;
  end;
  Inc(FClassCounts[AClass], LCount);
  Inc(FTotalSlots, LCount);
end;

function TSizeClassPool.ClassIndexForSize(ASize: SizeUInt): TSizeClassIndex;
var
  LIdx: Integer;
begin
  LIdx := SizeClassIndex(ASize);
  if LIdx < 0 then
    raise EOutOfMemory.Create(aeOutOfMemory,
      'TSizeClassPool: size exceeds max size class (512)');
  Result := TSizeClassIndex(LIdx);
end;

function TSizeClassPool.Alloc(ASize: SizeUInt): Pointer;
var
  LClass: TSizeClassIndex;
begin
  if ASize = 0 then
    Exit(nil);

  LClass := ClassIndexForSize(ASize);

  { 如果 free list 为空, 分配新页 }
  if FFreeHeads[LClass] = nil then
    AllocatePage(LClass);

  { Pop from free list }
  Result := FFreeHeads[LClass];
  FFreeHeads[LClass] := PPointer(Result)^;
  Dec(FClassCounts[LClass]);
  Inc(FTotalAllocs[LClass]);
end;

procedure TSizeClassPool.Release(APtr: Pointer; ASize: SizeUInt);
var
  LClass: TSizeClassIndex;
  LPtr: PPointer;
begin
  if APtr = nil then
    Exit;
  if ASize = 0 then
    Exit;

  LClass := ClassIndexForSize(ASize);
  LPtr := PPointer(APtr);
  LPtr^ := FFreeHeads[LClass];
  FFreeHeads[LClass] := APtr;
  Inc(FClassCounts[LClass]);
end;

procedure TSizeClassPool.Reset;
var
  I: TSizeClassIndex;
  J: Integer;
  LSlotSize: SizeUInt;
  LCount: SizeUInt;
  LPtr: PPointer;
begin
  for I := Low(TSizeClassIndex) to High(TSizeClassIndex) do
  begin
    LSlotSize := FSlotSizes[I];
    FFreeHeads[I] := nil;
    FClassCounts[I] := 0;

    { 重建所有页的 free list }
    for J := 0 to FPageCounts[I] - 1 do
    begin
      LCount := SC_PAGE_SIZE div LSlotSize;
      if LCount = 0 then
        LCount := 1;

      { 从页尾向前串入 free list }
      while LCount > 0 do begin
        Dec(LCount);
        LPtr := PPointer(PtrUInt(FPages[I][J]) + LCount * LSlotSize);
        LPtr^ := FFreeHeads[I];
        FFreeHeads[I] := LPtr;
      end;
      Inc(FClassCounts[I], SC_PAGE_SIZE div LSlotSize);
    end;
  end;
end;

function TSizeClassPool.FreeCount(AClass: TSizeClassIndex): SizeUInt;
begin
  Result := FClassCounts[AClass];
end;

function TSizeClassPool.SlotSize(AClass: TSizeClassIndex): SizeUInt;
begin
  Result := FSlotSizes[AClass];
end;

function TSizeClassPool.PageCount: SizeUInt;
begin
  Result := FTotalPages;
end;

function TSizeClassPool.TotalAllocCount: SizeUInt;
var
  I: TSizeClassIndex;
begin
  Result := 0;
  for I := Low(TSizeClassIndex) to High(TSizeClassIndex) do
    Inc(Result, FTotalAllocs[I]);
end;

end.
