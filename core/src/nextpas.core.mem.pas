unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.arena.thread,
  nextpas.core.mem.arena.concurrent,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check,
  nextpas.core.mem.allocator.fallback,
  nextpas.core.mem.pool.sizeclass,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.pool;

type
  // === 基础类型 ===
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TArenaMarker = nextpas.core.mem.base.TArenaMarker; // deprecated: use TArenaMark
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TAllocError = nextpas.core.mem.error.TAllocError;
  EAllocError = nextpas.core.mem.error.EAllocError;
  EOutOfMemory = nextpas.core.mem.error.EOutOfMemory;

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
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
  TFallbackAllocator = nextpas.core.mem.allocator.fallback.TFallbackAllocator;
  TFallbackArena = nextpas.core.mem.allocator.fallback.TFallbackArena;

  // === Pool 子系统 ===
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
  TPool = nextpas.core.mem.pool.TPool;
  TSizeClassPool = nextpas.core.mem.pool.sizeclass.TSizeClassPool;
  IBlockPool = nextpas.core.mem.blockpool.IBlockPool;
  IBlockPoolBatch = nextpas.core.mem.blockpool.IBlockPoolBatch;
  TBlockPool = nextpas.core.mem.blockpool.TBlockPool;
  TShardedBlockPool = nextpas.core.mem.blockpool.sharded.TShardedBlockPool;
  TStackPool = nextpas.core.mem.stack_pool.TStackPool;

function DefaultAllocator: IAllocator; inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
begin
  Result := AAllocator.GetMem(ASize);
  if Result <> nil then
    ZeroMem(Result, ASize);
end;

function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
var
  LTotal: SizeUInt;
begin
  if (ACount = 0) or (AElemSize = 0) then Exit(nil);
  LTotal := ACount * AElemSize;
  if (LTotal div AElemSize) <> ACount then
    raise EOutOfMemory.Create(aeOutOfMemory, 'AllocArray: size overflow');
  Result := AAllocator.GetMem(LTotal);
  if Result <> nil then
    ZeroMem(Result, LTotal);
end;

end.
