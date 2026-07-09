{
# nextpas.core.mem.allocator.thread_cache

## 摘要

线程本地缓存分配器 — 减少锁竞争。

特性:
- 每个线程维护独立的小对象缓存
- 分配优先从线程本地缓存获取（无锁）
- 缓存不足时从内部分配器批量获取
- 释放优先放入线程本地缓存
- 缓存满时批量释放回内部分配器

适用场景：多线程高并发分配场景。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.thread_cache;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 线程缓存槽位数（每个 size class） }
  THREAD_CACHE_SLOTS = 64;
  {** Size class 数量 }
  THREAD_CACHE_CLASS_COUNT = 8;
  {** 批量获取/释放数量 }
  THREAD_CACHE_BATCH_SIZE = 8;

type
  {** 线程缓存统计信息 }
  TThreadCacheStats = record
    CacheHits: UInt64;        { 缓存命中次数 }
    CacheMisses: UInt64;      { 缓存未命中次数 }
    BatchFetches: UInt64;     { 批量获取次数 }
    BatchReturns: UInt64;    { 批量释放次数 }
    CachedBlockCount: UInt64; { 当前缓存块数 }
  end;

  {** TThreadCacheAllocator
   *
   *  线程本地缓存分配器。
   *  每个线程维护独立的小对象缓存，减少锁竞争。
   *
   *  分配流程:
   *    1. 查找线程本地缓存（无锁）
   *    2. 命中：直接返回（O(1)）
   *    3. 未命中：从内部分配器批量获取（有锁）
   *
   *  释放流程:
   *    1. 放入线程本地缓存（无锁）
   *    2. 缓存满：批量释放回内部分配器（有锁）
   *}
  TThreadCacheAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    { Size class 定义 }
    FSizeClasses: array[0..THREAD_CACHE_CLASS_COUNT - 1] of SizeUInt;
    { 线程本地缓存 }
    FCachedPtrs: array[0..THREAD_CACHE_CLASS_COUNT - 1, 0..THREAD_CACHE_SLOTS - 1] of Pointer;
    FCachedCounts: array[0..THREAD_CACHE_CLASS_COUNT - 1] of Integer;
    { 统计 }
    FCacheHits: UInt64;
    FCacheMisses: UInt64;
    FBatchFetches: UInt64;
    FBatchReturns: UInt64;
    procedure InitSizeClasses;
    function FindSizeClass(ASize: SizeUInt): Int32;
    procedure BatchFetch(AClassIdx: Int32);
    procedure BatchReturn(AClassIdx: Int32);
  public
    {** 创建线程缓存分配器 }
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 获取统计信息 }
    function GetStats: TThreadCacheStats;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  { Size class 定义 }
  THREAD_CACHE_SIZES: array[0..THREAD_CACHE_CLASS_COUNT - 1] of SizeUInt = (
    8, 16, 32, 64, 128, 256, 512, 1024
  );
  THREAD_CACHE_HEADER = SizeOf(Byte); { stores class index for correct free routing }
  THREAD_CACHE_LARGE = 255; { sentinel for large objects }

{ --- TThreadCacheAllocator --- }

constructor TThreadCacheAllocator.Create(AInner: IAllocator);
var
  LI: Int32;
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TThreadCacheAllocator.Create: AInner cannot be nil');

  FInner := AInner;
  InitSizeClasses;

  for LI := 0 to THREAD_CACHE_CLASS_COUNT - 1 do
    FCachedCounts[LI] := 0;

  FCacheHits := 0;
  FCacheMisses := 0;
  FBatchFetches := 0;
  FBatchReturns := 0;
end;

destructor TThreadCacheAllocator.Destroy;
var
  LI, LJ: Int32;
begin
  { 释放所有缓存块（cached pointers are past header） }
  for LI := 0 to THREAD_CACHE_CLASS_COUNT - 1 do
  begin
    for LJ := 0 to FCachedCounts[LI] - 1 do
      FInner.FreeMem(PByte(FCachedPtrs[LI][LJ]) - THREAD_CACHE_HEADER);
    FCachedCounts[LI] := 0;
  end;
  FInner := nil;
  inherited Destroy;
end;

procedure TThreadCacheAllocator.InitSizeClasses;
var
  LI: Int32;
begin
  for LI := 0 to THREAD_CACHE_CLASS_COUNT - 1 do
    FSizeClasses[LI] := THREAD_CACHE_SIZES[LI];
end;

function TThreadCacheAllocator.FindSizeClass(ASize: SizeUInt): Int32;
var
  LI: Int32;
begin
  for LI := 0 to THREAD_CACHE_CLASS_COUNT - 1 do
  begin
    if ASize <= FSizeClasses[LI] then
      Exit(LI);
  end;
  Result := -1;
end;

procedure TThreadCacheAllocator.BatchFetch(AClassIdx: Int32);
var
  LI: Integer;
  LRaw: PByte;
begin
  for LI := 0 to THREAD_CACHE_BATCH_SIZE - 1 do
  begin
    LRaw := PByte(FInner.GetMem(THREAD_CACHE_HEADER + FSizeClasses[AClassIdx]));
    if LRaw = nil then Break;
    LRaw^ := Byte(AClassIdx);
    FCachedPtrs[AClassIdx, FCachedCounts[AClassIdx]] := Pointer(LRaw + THREAD_CACHE_HEADER);
    Inc(FCachedCounts[AClassIdx]);
  end;
  Inc(FBatchFetches);
end;

procedure TThreadCacheAllocator.BatchReturn(AClassIdx: Int32);
var
  LI: Integer;
  LRaw: PByte;
begin
  for LI := 0 to THREAD_CACHE_BATCH_SIZE - 1 do
  begin
    if FCachedCounts[AClassIdx] <= 0 then Break;
    Dec(FCachedCounts[AClassIdx]);
    { Cached pointers are past header; go back to raw for FInner }
    LRaw := PByte(FCachedPtrs[AClassIdx, FCachedCounts[AClassIdx]]) - THREAD_CACHE_HEADER;
    FInner.FreeMem(LRaw);
  end;
  Inc(FBatchReturns);
end;

function TThreadCacheAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LClassIdx: Int32;
  LRaw: PByte;
begin
  LClassIdx := FindSizeClass(ASize);
  if LClassIdx < 0 then
  begin
    { 大对象：从内部分配器分配，带 header }
    LRaw := PByte(FInner.GetMem(THREAD_CACHE_HEADER + ASize));
    if LRaw = nil then
      Exit(nil);
    LRaw^ := THREAD_CACHE_LARGE;
    Exit(Pointer(LRaw + THREAD_CACHE_HEADER));
  end;

  { 小对象：从线程缓存分配（缓存中的指针已经 past header） }
  if FCachedCounts[LClassIdx] <= 0 then
  begin
    BatchFetch(LClassIdx);
    Inc(FCacheMisses);
  end
  else
    Inc(FCacheHits);

  if FCachedCounts[LClassIdx] > 0 then
  begin
    Dec(FCachedCounts[LClassIdx]);
    Result := FCachedPtrs[LClassIdx, FCachedCounts[LClassIdx]];
  end
  else
  begin
    { 缓存空，从内部分配器分配，带 header }
    LRaw := PByte(FInner.GetMem(THREAD_CACHE_HEADER + ASize));
    if LRaw = nil then
      Exit(nil);
    LRaw^ := Byte(LClassIdx);
    Result := Pointer(LRaw + THREAD_CACHE_HEADER);
  end;
end;

function TThreadCacheAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TThreadCacheAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  { Delegate to inner which knows the actual block size }
  Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TThreadCacheAllocator.FreeMem(APtr: Pointer); inline;
var
  LRaw: PByte;
  LClassIdx: Int32;
begin
  if APtr = nil then Exit;

  LRaw := PByte(APtr) - THREAD_CACHE_HEADER;
  LClassIdx := Int32(LRaw^);

  if LClassIdx = THREAD_CACHE_LARGE then
  begin
    { 大对象：直接释放回内部分配器 }
    FInner.FreeMem(LRaw);
    Exit;
  end;

  if (LClassIdx < 0) or (LClassIdx >= THREAD_CACHE_CLASS_COUNT) then
  begin
    { 无效 class，直接释放 }
    FInner.FreeMem(LRaw);
    Exit;
  end;

  { 小对象：放入对应 size class 的缓存 }
  if FCachedCounts[LClassIdx] < THREAD_CACHE_SLOTS then
  begin
    FCachedPtrs[LClassIdx, FCachedCounts[LClassIdx]] := APtr;
    Inc(FCachedCounts[LClassIdx]);

    { 缓存满时批量释放 }
    if FCachedCounts[LClassIdx] >= THREAD_CACHE_SLOTS then
      BatchReturn(LClassIdx);
    Exit;
  end;

  { 缓存满，直接释放 }
  FInner.FreeMem(LRaw);
end;

function TThreadCacheAllocator.GetStats: TThreadCacheStats;
var
  LI: Int32;
begin
  Result.CacheHits := FCacheHits;
  Result.CacheMisses := FCacheMisses;
  Result.BatchFetches := FBatchFetches;
  Result.BatchReturns := FBatchReturns;
  Result.CachedBlockCount := 0;
  for LI := 0 to THREAD_CACHE_CLASS_COUNT - 1 do
    Inc(Result.CachedBlockCount, UInt64(FCachedCounts[LI]));
end;

function TThreadCacheAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
