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

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

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
   *  内存布局（每个块）:
   *  [NextPtr 8B][User data...]
   *               ^ returned pointer
   *
   *  @warning 不支持 ReallocMem（固定大小块无法调整大小）
   *}
  TPoolAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FBlockSize: SizeUInt;
    FActualBlockSize: SizeUInt;  { 含 NextPtr 的实际块大小 }
    FFreeHead: Pointer;          { 空闲链表头 }
    FFreeCount: UInt64;
    FTotalBlocks: UInt64;
    { 统计 }
    FAllocCount: UInt64;
    FFreeCountStat: UInt64;
    FGrowCount: UInt64;
    { 池内存块管理（用于释放） }
    FPoolChunks: array of Pointer;
    FPoolChunkSizes: array of SizeUInt;
    FPoolChunkCount: Integer;
    procedure GrowPool(AGrowCount: UInt64);
    function PopFree: Pointer;
    procedure PushFree(APtr: Pointer);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    {** 创建固定大小块池分配器
     *  @param AInner 内部分配器（用于批量获取内存）
     *  @param ABlockSize 每个块的用户数据大小
     *  @param AInitialCount 初始块数
     *}
    constructor Create(AInner: IAllocator; ABlockSize: SizeUInt;
      AInitialCount: UInt64 = POOL_DEFAULT_INITIAL_COUNT);
    destructor Destroy; override;

    {** 获取池统计信息 }
    function GetStats: TPoolStats;
    {** 块大小 }
    property BlockSize: SizeUInt read FBlockSize;
    {** 空闲块数 }
    property FreeBlockCount: UInt64 read FFreeCount;
    {** 总块数 }
    property TotalBlockCount: UInt64 read FTotalBlocks;

    function Traits: TAllocatorTraits; override;
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
    raise EAllocError.Create(aeInvalidLayout, 'TPoolAllocator.Create: AInner cannot be nil');
  if ABlockSize < MIN_BLOCK_SIZE then
    raise EAllocError.Create(aeInvalidLayout, 'TPoolAllocator.Create: block size too small');
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
    raise EAllocError.Create(aeOutOfMemory, 'TPoolAllocator.GrowPool: size overflow');

  { 从内部分配器获取大块内存 }
  LChunk := FInner.GetMem(LChunkSize);
  if LChunk = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TPoolAllocator.GrowPool: allocation failed');

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

function TPoolAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  { 忽略 ASize，使用固定块大小 }
  if FFreeHead = nil then
    GrowPool(POOL_DEFAULT_GROW_COUNT);
  Result := PopFree;
  if Result <> nil then
    Inc(FAllocCount);
end;

function TPoolAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DoGetMem(ASize);
  if Result <> nil then
    FillChar(Result^, FBlockSize, 0);
end;

function TPoolAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  { 固定大小块不支持 Realloc }
  raise EAllocError.Create(aeInvalidLayout,
    'TPoolAllocator.ReallocMem: not supported for fixed-size pool');
  Result := nil;
end;

procedure TPoolAllocator.DoFreeMem(APtr: Pointer);
begin
  if APtr = nil then Exit;
  PushFree(APtr);
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

function TPoolAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.SupportsRealloc := False;
end;

end.
