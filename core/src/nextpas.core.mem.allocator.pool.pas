{
# nextpas.core.mem.allocator.pool

## 摘要

固定大小块池分配器 — O(1) 分配/释放，零外部碎片。

特性:
- 预分配固定大小内存块池
- 使用空闲链表管理释放的块
- 分配: 从空闲链表弹出 (O(1))
- 释放: 压入空闲链表 (O(1))
- 零外部碎片（所有块大小相同）
- 可选自动扩展池容量

适用场景: 高频同尺寸对象分配（如网络包、事件对象、AST 节点）。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 默认初始块数 }
  POOL_DEFAULT_INITIAL_COUNT = 256;
  {** 默认扩展增量 }
  POOL_DEFAULT_GROW_COUNT = 128;

type
  {** 池统计信息 }
  TPoolStats = record
    BlockSize: SizeUInt;        { 每个块的大小 }
    TotalBlocks: UInt64;        { 总块数（已分配+空闲） }
    FreeBlocks: UInt64;         { 空闲块数 }
    UsedBlocks: UInt64;         { 使用中的块数 }
    AllocCount: UInt64;         { 总分配次数 }
    FreeCount: UInt64;          { 总释放次数 }
    GrowCount: UInt64;          { 池扩展次数 }
  end;

  {** TPoolAllocator
   *
   *  固定大小块池分配器。
   *  所有块大小相同，使用空闲链表管理，O(1) 分配/释放。
   *  零外部碎片，适合高频同尺寸对象分配。
   *
   *  块布局: 返回指针即块基址；空闲时用户区前 8 字节复用为
   *  freelist Next 指针（intrusive freelist，无独立头部）。
   *
   *  FreeMem 路由: 指针落在任一池 chunk 范围内 → 池块回收；
   *  否则视为超限 fallback 块原样归还内部分配器。禁止依赖
   *  块外字节做类型判定（chunk 可落在 mmap 映射基址,[-1] 不可读）。
   *
   *  @warning 不支持 ReallocMem（固定大小块无法调整大小）
   *}
  TPoolAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FBlockSize: SizeUInt;
    FActualBlockSize: SizeUInt;  { 含 freelist 指针预留的实际块大小 }
    FFreeHead: Pointer;          { 空闲链表头 }
    FFreeCount: UInt64;
    FTotalBlocks: UInt64;
    { 统计 }
    FAllocCount: UInt64;
    FFreeCountStat: UInt64;
    FGrowCount: UInt64;
    { 池内存块管理（用于释放 + FreeMem 范围路由） }
    FPoolChunks: array of Pointer;
    FPoolChunkSizes: array of SizeUInt;
    FPoolChunkCount: Integer;
    FLastHitChunk: Integer;      { MRU: 上次范围命中的 chunk 索引 }
    procedure GrowPool(AGrowCount: UInt64);
    function PopFree: Pointer;
    procedure PushFree(APtr: Pointer);
    function OwnsBlock(APtr: Pointer): Boolean;
  public
    {** 创建固定大小块池分配器
     *  @param AInner 内部分配器（用于批量获取内存）
     *  @param ABlockSize 每个块的用户数据大小
     *  @param AInitialCount 初始块数
     *}
    constructor Create(AInner: IAllocator; ABlockSize: SizeUInt;
      AInitialCount: UInt64 = POOL_DEFAULT_INITIAL_COUNT);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 获取池统计信息 }
    function GetStats: TPoolStats;
    {** 块大小 }
    property BlockSize: SizeUInt read FBlockSize;
    {** 空闲块数 }
    property FreeBlockCount: UInt64 read FFreeCount;
    {** 总块数 }
    property TotalBlockCount: UInt64 read FTotalBlocks;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  { 空闲链表节点大小（一个指针） }
  FREE_NODE_SIZE = SizeOf(Pointer);
  { 最小块大小（至少能容纳一个指针） }
  MIN_BLOCK_SIZE = FREE_NODE_SIZE;

{ --- TPoolAllocator --- }

constructor TPoolAllocator.Create(AInner: IAllocator; ABlockSize: SizeUInt;
  AInitialCount: UInt64);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TPoolAllocator', 'Create', 'AInner cannot be nil'));
  if ABlockSize < MIN_BLOCK_SIZE then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TPoolAllocator', 'Create', 'block size too small'));
  if AInitialCount = 0 then
    AInitialCount := POOL_DEFAULT_INITIAL_COUNT;

  FInner := AInner;
  FBlockSize := ABlockSize;
  FActualBlockSize := ABlockSize + FREE_NODE_SIZE;
  FFreeHead := nil;
  FFreeCount := 0;
  FTotalBlocks := 0;
  FAllocCount := 0;
  FFreeCountStat := 0;
  FGrowCount := 0;
  FPoolChunkCount := 0;
  FLastHitChunk := 0;

  { 初始扩展池 }
  GrowPool(AInitialCount);
end;

destructor TPoolAllocator.Destroy;
var
  LI: Integer;
begin
  { 释放所有池内存块 }
  for LI := 0 to FPoolChunkCount - 1 do
    FInner.FreeMem(FPoolChunks[LI]);
  SetLength(FPoolChunks, 0);
  SetLength(FPoolChunkSizes, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TPoolAllocator.GrowPool(AGrowCount: UInt64);
var
  LChunkSize: UInt64;
  LChunk: Pointer;
  LI: UInt64;
  LPtr: Pointer;
begin
  if AGrowCount = 0 then Exit;

  { 计算总内存大小 }
  LChunkSize := AGrowCount * FActualBlockSize;
  if LChunkSize div FActualBlockSize <> AGrowCount then
    raise EAllocError.Create(aeOutOfMemory, FormatAllocErrorMsg('TPoolAllocator', 'GrowPool', 'size overflow'));

  { 从内部分配器获取大块内存 }
  LChunk := FInner.GetMem(LChunkSize);
  if LChunk = nil then
    raise EAllocError.Create(aeOutOfMemory, FormatAllocErrorMsg('TPoolAllocator', 'GrowPool', 'allocation failed'));

  { 记录池内存块（用于析构时释放） }
  if FPoolChunkCount >= Length(FPoolChunks) then
  begin
    SetLength(FPoolChunks, FPoolChunkCount + 8);
    SetLength(FPoolChunkSizes, FPoolChunkCount + 8);
  end;
  FPoolChunks[FPoolChunkCount] := LChunk;
  FPoolChunkSizes[FPoolChunkCount] := LChunkSize;
  Inc(FPoolChunkCount);

  { 将大块切分为小块，串入空闲链表 }
  LPtr := LChunk;
  for LI := 0 to AGrowCount - 1 do
  begin
    PushFree(LPtr);
    LPtr := Pointer(PtrUInt(LPtr) + FActualBlockSize);
  end;

  Inc(FTotalBlocks, AGrowCount);
  Inc(FGrowCount);
end;

function TPoolAllocator.PopFree: Pointer;
begin
  if FFreeHead = nil then
    Exit(nil);
  Result := FFreeHead;
  { 读取 Next 指针 }
  FFreeHead := PPointer(FFreeHead)^;
  Dec(FFreeCount);
end;

procedure TPoolAllocator.PushFree(APtr: Pointer);
begin
  { 写入 Next 指针 }
  PPointer(APtr)^ := FFreeHead;
  FFreeHead := APtr;
  Inc(FFreeCount);
end;

function TPoolAllocator.OwnsBlock(APtr: Pointer): Boolean;
var
  LI: Integer;
  LBase: PtrUInt;
begin
  { 热路径释放通常连续命中同一 chunk,先查 MRU 摊销成 O(1) }
  if FLastHitChunk < FPoolChunkCount then
  begin
    LBase := PtrUInt(FPoolChunks[FLastHitChunk]);
    if (PtrUInt(APtr) >= LBase) and
       (PtrUInt(APtr) - LBase < FPoolChunkSizes[FLastHitChunk]) then
      Exit(True);
  end;
  for LI := 0 to FPoolChunkCount - 1 do
  begin
    LBase := PtrUInt(FPoolChunks[LI]);
    if (PtrUInt(APtr) >= LBase) and
       (PtrUInt(APtr) - LBase < FPoolChunkSizes[LI]) then
    begin
      FLastHitChunk := LI;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TPoolAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then
    Exit(nil);
  { 超过固定块大小的请求，fallback 到内部分配器。
    原样透传（不加头部字节）,保留内部分配器的对齐保证；
    FreeMem 用 chunk 范围判定路由,无需 in-band 标记。 }
  if ASize > FBlockSize then
  begin
    Result := FInner.GetMem(ASize);
    if Result <> nil then
      Inc(FAllocCount);
    Exit;
  end;
  if FFreeHead = nil then
    GrowPool(POOL_DEFAULT_GROW_COUNT);
  Result := PopFree;
  if Result <> nil then
    Inc(FAllocCount);
end;

function TPoolAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  { 按请求大小清零：fallback 块可大于 FBlockSize,清 FBlockSize 会漏尾部 }
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TPoolAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  { 固定大小块不支持 Realloc }
  raise EAllocError.Create(aeInvalidLayout,
    FormatAllocErrorMsg('TPoolAllocator', 'ReallocMem', 'not supported for fixed-size pool'));
  Result := nil;
end;

procedure TPoolAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then Exit;
  if OwnsBlock(APtr) then
    PushFree(APtr)
  else
    { 非池内指针 → 必是超限 fallback 块,原样归还内部分配器 }
    FInner.FreeMem(APtr);
  Inc(FFreeCountStat);
end;

function TPoolAllocator.GetStats: TPoolStats;
begin
  Result.BlockSize := FBlockSize;
  Result.TotalBlocks := FTotalBlocks;
  Result.FreeBlocks := FFreeCount;
  Result.UsedBlocks := FTotalBlocks - FFreeCount;
  Result.AllocCount := FAllocCount;
  Result.FreeCount := FFreeCountStat;
  Result.GrowCount := FGrowCount;
end;

function TPoolAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := False;
end;

end.
