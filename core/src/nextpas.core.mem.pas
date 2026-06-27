unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.mutex,
  nextpas.core.mem.rwlock,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.arena.thread,
  nextpas.core.mem.arena.concurrent,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.callback,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check,
  nextpas.core.mem.allocator.fallback,
  nextpas.core.mem.allocator.mmap,
  nextpas.core.mem.allocator.mimalloc,
  nextpas.core.mem.pool.sizeclass,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.pool.slab.concurrent,
  nextpas.core.mem.pool.slab.sharded,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.concurrent,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.ring_buffer,
  nextpas.core.mem.memory_map,
  nextpas.core.mem.mapped_slab_pool,
  nextpas.core.mem.secure,
  nextpas.core.mem.pool;

type
  // === 基础类型 ===
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TAllocError = nextpas.core.mem.error.TAllocError;
  EAllocError = nextpas.core.mem.error.EAllocError;
  EOutOfMemory = nextpas.core.mem.error.EOutOfMemory;
  EInvalidLayout = nextpas.core.mem.error.EInvalidLayout;
  EInvalidPointer = nextpas.core.mem.error.EInvalidPointer;
  EDoubleFree = nextpas.core.mem.error.EDoubleFree;

  // === 同步原语 ===
  TMemMutex = nextpas.core.mem.mutex.TMemMutex;
  TMemRwLock = nextpas.core.mem.rwlock.TMemRwLock;

  // === Arena 子系统 ===
  IArena = nextpas.core.mem.arena.intf.IArena;
  TArenaMark = nextpas.core.mem.arena.base.TArenaMark;
  TArenaGrowthKind = nextpas.core.mem.arena.base.TArenaGrowthKind;
  TArenaStats = nextpas.core.mem.arena.base.TArenaStats;
  TArenaConfig = nextpas.core.mem.arena.base.TArenaConfig;
  TLocalArena = nextpas.core.mem.arena.local.TLocalArena;
  TChunkedArena = nextpas.core.mem.arena.chunked.TChunkedArena;
  TVirtualArena = nextpas.core.mem.arena.virtual.TVirtualArena;
  TVirtualArenaAllocFailure = nextpas.core.mem.arena.virtual.TVirtualArenaAllocFailure;
  TArenaConcurrent = nextpas.core.mem.arena.concurrent.TArenaConcurrent;

  // === Thread-Local Arena ===
  TThreadArenaConfig = nextpas.core.mem.arena.thread.TThreadArenaConfig;
  TThreadArenaManager = nextpas.core.mem.arena.thread.TThreadArenaManager;
  TThreadArena = nextpas.core.mem.arena.thread.TThreadArena;

  // === 分配器包装 ===
  TVirtualArenaAllocator = nextpas.core.mem.allocator.arena.TVirtualArenaAllocator;
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  TCallbackAllocator = nextpas.core.mem.allocator.callback.TCallbackAllocator;
  TGuardAllocator = nextpas.core.mem.allocator.guard.TGuardAllocator;
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
  TFallbackAllocator = nextpas.core.mem.allocator.fallback.TFallbackAllocator;
  TFallbackArena = nextpas.core.mem.allocator.fallback.TFallbackArena;
  TMemoryMapAllocator = nextpas.core.mem.allocator.mmap.TMemoryMapAllocator;
  TMimallocAllocator = nextpas.core.mem.allocator.mimalloc.TMimallocAllocator;

  // === Pool 子系统 ===
  IMemoryPool = nextpas.core.mem.pool.memory_pool.IMemoryPool;
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
  TPool = nextpas.core.mem.pool.TPool;
  TSizeClassPool = nextpas.core.mem.pool.sizeclass.TSizeClassPool;
  IBlockPool = nextpas.core.mem.blockpool.IBlockPool;
  IBlockPoolBatch = nextpas.core.mem.blockpool.IBlockPoolBatch;
  TBlockPool = nextpas.core.mem.blockpool.TBlockPool;
  TBlockPoolConcurrent = nextpas.core.mem.blockpool.concurrent.TBlockPoolConcurrent;
  TShardedBlockPool = nextpas.core.mem.blockpool.sharded.TShardedBlockPool;
  TStackPool = nextpas.core.mem.stack_pool.TStackPool;
  TFixedPool = nextpas.core.mem.pool.fixed.TFixedPool;
  TFixedPoolConcurrent = nextpas.core.mem.pool.fixed.TFixedPoolConcurrent;
  TSlabPool = nextpas.core.mem.pool.slab.TSlabPool;
  TSlabConfig = nextpas.core.mem.pool.slab.TSlabConfig;
  TSlabPoolConcurrent = nextpas.core.mem.pool.slab.concurrent.TSlabPoolConcurrent;
  TSlabPoolSharded = nextpas.core.mem.pool.slab.sharded.TSlabPoolSharded;

  // === 容器 ===
  TRingBuffer = nextpas.core.mem.ring_buffer.TRingBuffer;

  // === 内存映射 ===
  TMemoryMap = nextpas.core.mem.memory_map.TMemoryMap;
  TSharedMemory = nextpas.core.mem.memory_map.TSharedMemory;
  TMappedSlabAllocator = nextpas.core.mem.mapped_slab_pool.TMappedSlabAllocator;

function DefaultAllocator: IAllocator; inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt); inline;
procedure SecureZeroBytes(var AData: TBytes); inline;
procedure SecureZeroString(var AStr: AnsiString); inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
begin
  Result := AAllocator.AllocMem(ASize);
end;

function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
var
  LTotal: SizeUInt;
begin
  if (ACount = 0) or (AElemSize = 0) then Exit(nil);
  LTotal := ACount * AElemSize;
  if (LTotal div AElemSize) <> ACount then
    raise EOutOfMemory.Create(aeOutOfMemory, 'AllocArray: size overflow');
  Result := AAllocator.AllocMem(LTotal);
end;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt);
begin
  nextpas.core.mem.secure.SecureZeroMemory(ABuffer, ASize);
end;

procedure SecureZeroBytes(var AData: TBytes);
begin
  nextpas.core.mem.secure.SecureZeroBytes(AData);
end;

procedure SecureZeroString(var AStr: AnsiString);
begin
  nextpas.core.mem.secure.SecureZeroString(AStr);
end;

end.
