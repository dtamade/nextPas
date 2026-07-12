unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *
 * @note 选择指南：
 *   - 通用场景 → DefaultAllocator (IAllocator)
 *   - 请求/帧级生命周期 → CreateDefaultArena (IArena)，用 Reset 一次性释放
 *   - 需要 IAllocator 接口的 Arena → CreateArenaAllocator（仅分配不释放）
 *   - 高频固定大小对象 → CreateFixedSlabPool / TFixedSlabPool / TLocalBlockPool
 *     （Acquire/Release API，O(1) 分配释放，位图 double-free 检测）
 *   - 高频可变大小对象 → TSlabPool / TSizeClassPool
 *     （GetMem/FreeMem API，size-class 路由，O(1) 分配释放）
 *   - 并发场景 → TSlabPoolConcurrent / TSlabPoolSharded / TBlockPoolConcurrent
 *   - 测试泄漏检测 → TTrackingAllocator 包装任意 IAllocator
 *
 * @note 固定大小 vs 通用 API：
 *   - Acquire/Release — 固定大小槽位池（IPool/IBlockPool），不关心具体大小
 *   - GetMem/FreeMem — 通用分配器（IAllocator），按请求大小路由
 *   - 两者是不同范式，不要混用。详见 pool.base.pas 接口决策树。
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
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check,
  nextpas.core.mem.allocator.fallback,
  nextpas.core.mem.allocator.mmap,
  nextpas.core.mem.allocator.mimalloc,
  nextpas.core.mem.pool.sizeclass,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.fixed_slab,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.pool.slab.concurrent,
  nextpas.core.mem.pool.slab.sharded,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.concurrent,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.ring_buffer,
  nextpas.core.mem.memory_map,
  nextpas.core.mem.mapped_slab_pool,
  nextpas.core.mem.secure,
  nextpas.core.mem.pool,
  nextpas.core.mem.pool.allocator,
  nextpas.core.mem.span,
  nextpas.core.mem.central,
  nextpas.core.mem.stats,
  nextpas.core.mem.oom,
  nextpas.core.mem.registry,
  nextpas.core.mem.allocator.compact,
  nextpas.core.mem.allocator.callback,
  nextpas.core.mem.allocator.bump,
  nextpas.core.mem.allocator.cascade,
  nextpas.core.mem.allocator.bitmap,
  nextpas.core.mem.allocator.batch,
  nextpas.core.mem.allocator.sentinel,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.leak_report,
  nextpas.core.mem.allocator.logging,
  nextpas.core.mem.allocator.debug_alloc,
  nextpas.core.mem.allocator.watermark,
  nextpas.core.mem.allocator.sampling,
  nextpas.core.mem.allocator.prefix,
  nextpas.core.mem.allocator.prediction,
  nextpas.core.mem.allocator.replay,
  nextpas.core.mem.allocator.numa,
  nextpas.core.mem.allocator.aligned,
  nextpas.core.mem.allocator.arena2,
  nextpas.core.mem.allocator.arena_group,
  nextpas.core.mem.allocator.bounded,
  nextpas.core.mem.allocator.coalesce,
  nextpas.core.mem.allocator.counting,
  nextpas.core.mem.allocator.cow,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.dual,
  nextpas.core.mem.allocator.fail,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.freelist,
  nextpas.core.mem.allocator.group,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.hotswap,
  nextpas.core.mem.allocator.huge_page,
  nextpas.core.mem.allocator.mapped_file,
  nextpas.core.mem.allocator.page,
  nextpas.core.mem.allocator.pool,
  nextpas.core.mem.allocator.pool2,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.scoped,
  nextpas.core.mem.allocator.size_class,
  nextpas.core.mem.allocator.slab,
  nextpas.core.mem.allocator.sliding,
  nextpas.core.mem.allocator.stack,
  nextpas.core.mem.allocator.stats,
  nextpas.core.mem.allocator.thread_cache,
  nextpas.core.mem.allocator.thread_safe,
  nextpas.core.mem.allocator.zeroed,
  nextpas.core.mem.budget;

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
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TVirtualArenaAdapter = nextpas.core.mem.allocator.arena.TVirtualArenaAdapter;
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
  TFallbackAllocator = nextpas.core.mem.allocator.fallback.TFallbackAllocator;
  TFallbackArena = nextpas.core.mem.allocator.fallback.TFallbackArena;
  TMemoryMapAllocator = nextpas.core.mem.allocator.mmap.TMemoryMapAllocator;
  TMimallocAllocator = nextpas.core.mem.allocator.mimalloc.TMimallocAllocator;

  // === Pool 子系统 ===
  IMemoryPool = nextpas.core.mem.pool.base.IMemoryPool;
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
  IFixedSlabPool = nextpas.core.mem.pool.fixed_slab.IFixedSlabPool;
  TFixedSlabPool = nextpas.core.mem.pool.fixed_slab.TFixedSlabPool;
  TSlabPool = nextpas.core.mem.pool.slab.TSlabPool;
  TSlabConfig = nextpas.core.mem.pool.slab.TSlabConfig;
  TSlabPoolConcurrent = nextpas.core.mem.pool.slab.concurrent.TSlabPoolConcurrent;
  TSlabPoolSharded = nextpas.core.mem.pool.slab.sharded.TSlabPoolSharded;

  // === 容器 ===
  TRingBuffer = nextpas.core.mem.ring_buffer.TRingBuffer;

  // === Span/Central (高级构建块) ===
  TSpan = nextpas.core.mem.span.TSpan;
  TCentralPool = nextpas.core.mem.central.TCentralPool;
  TCentralSpanEntry = nextpas.core.mem.central.TCentralSpanEntry;

  // === 内存映射 ===
  TMemoryMap = nextpas.core.mem.memory_map.TMemoryMap;
  TSharedMemory = nextpas.core.mem.memory_map.TSharedMemory;
  TMappedSlabAllocator = nextpas.core.mem.mapped_slab_pool.TMappedSlabAllocator;

  // === 统计/监控 ===
  TAllocSnapshot = nextpas.core.mem.stats.TAllocSnapshot;
  TAllocHistogram = nextpas.core.mem.stats.TAllocHistogram;
  TAllocStatsCollector = nextpas.core.mem.stats.TAllocStatsCollector;
  TAllocStatsAllocator = nextpas.core.mem.stats.TAllocStatsAllocator;

  // === OOM 处理 ===
  TOomEvent = nextpas.core.mem.oom.TOomEvent;
  TOomHandler = nextpas.core.mem.oom.TOomHandler;

  // === 注册表 ===
  TAllocatorRegistry = nextpas.core.mem.registry.TAllocatorRegistry;

  // === 碎片整理 ===
  TCompactAllocator = nextpas.core.mem.allocator.compact.TCompactAllocator;
  TCompactStats = nextpas.core.mem.allocator.compact.TCompactStats;

  // === OOM 分配器 ===
  TOomAllocator = nextpas.core.mem.oom.TOomAllocator;

  // === 回调分配器 ===
  TGetMemCallback = nextpas.core.mem.allocator.callback.TGetMemCallback;
  TAllocMemCallback = nextpas.core.mem.allocator.callback.TAllocMemCallback;
  TReallocMemCallback = nextpas.core.mem.allocator.callback.TReallocMemCallback;
  TFreeMemCallback = nextpas.core.mem.allocator.callback.TFreeMemCallback;

  // === 高性能分配器 ===
  TBumpAllocator = nextpas.core.mem.allocator.bump.TBumpAllocator;
  TCascadeAllocator = nextpas.core.mem.allocator.cascade.TCascadeAllocator;
  TBitmapAllocator = nextpas.core.mem.allocator.bitmap.TBitmapAllocator;
  TBatchAllocator = nextpas.core.mem.allocator.batch.TBatchAllocator;

  // === 调试/监控分配器 ===
  TSentinelAllocator = nextpas.core.mem.allocator.sentinel.TSentinelAllocator;
  TGuardAllocator = nextpas.core.mem.allocator.guard.TGuardAllocator;
  TLeakReportAllocator = nextpas.core.mem.allocator.leak_report.TLeakReportAllocator;
  TLeakEntry = nextpas.core.mem.allocator.leak_report.TLeakEntry;
  TLeakReportResult = nextpas.core.mem.allocator.leak_report.TLeakReportResult;
  TLoggingAllocator = nextpas.core.mem.allocator.logging.TLoggingAllocator;
  TDebugAllocator = nextpas.core.mem.allocator.debug_alloc.TDebugAllocator;
  TWatermarkAllocator = nextpas.core.mem.allocator.watermark.TWatermarkAllocator;
  TSamplingAllocator = nextpas.core.mem.allocator.sampling.TSamplingAllocator;
  TSampleEntry = nextpas.core.mem.allocator.sampling.TSampleEntry;
  TPrefixAllocator = nextpas.core.mem.allocator.prefix.TPrefixAllocator;
  TPredictionAllocator = nextpas.core.mem.allocator.prediction.TPredictionAllocator;
  TPredictionEntry = nextpas.core.mem.allocator.prediction.TPredictionEntry;
  TPredictionResult = nextpas.core.mem.allocator.prediction.TPredictionResult;
  TReplayAllocator = nextpas.core.mem.allocator.replay.TReplayAllocator;
  TNumaAllocator = nextpas.core.mem.allocator.numa.TNumaAllocator;

  // === 通用分配器 ===
  TAlignedAllocator = nextpas.core.mem.allocator.aligned.TAlignedAllocator;
  TAlignedStats = nextpas.core.mem.allocator.aligned.TAlignedStats;
  TArena2Allocator = nextpas.core.mem.allocator.arena2.TArena2Allocator;
  TArena2Stats = nextpas.core.mem.allocator.arena2.TArena2Stats;
  TArenaGroupAllocator = nextpas.core.mem.allocator.arena_group.TArenaGroupAllocator;
  TArenaGroupStats = nextpas.core.mem.allocator.arena_group.TArenaGroupStats;
  TBoundedAllocator = nextpas.core.mem.allocator.bounded.TBoundedAllocator;
  TBoundedStats = nextpas.core.mem.allocator.bounded.TBoundedStats;
  TCoalesceAllocator = nextpas.core.mem.allocator.coalesce.TCoalesceAllocator;
  TCoalesceStats = nextpas.core.mem.allocator.coalesce.TCoalesceStats;
  TCountingAllocator = nextpas.core.mem.allocator.counting.TCountingAllocator;
  TCountingStats = nextpas.core.mem.allocator.counting.TCountingStats;
  TCowAllocator = nextpas.core.mem.allocator.cow.TCowAllocator;
  TCowStats = nextpas.core.mem.allocator.cow.TCowStats;
  TCrtAllocator = nextpas.core.mem.allocator.crt.TCrtAllocator;
  TDualAllocator = nextpas.core.mem.allocator.dual.TDualAllocator;
  TDualStats = nextpas.core.mem.allocator.dual.TDualStats;
  TFailAllocator = nextpas.core.mem.allocator.fail.TFailAllocator;
  TFailStats = nextpas.core.mem.allocator.fail.TFailStats;
  TFreelistAllocator = nextpas.core.mem.allocator.freelist.TFreelistAllocator;
  TFreelistStats = nextpas.core.mem.allocator.freelist.TFreelistStats;
  TGroupAllocator = nextpas.core.mem.allocator.group.TGroupAllocator;
  TGroupStats = nextpas.core.mem.allocator.group.TGroupStats;
  TGrowingAllocator = nextpas.core.mem.allocator.growing.TGrowingAllocator;
  THotswapAllocator = nextpas.core.mem.allocator.hotswap.THotswapAllocator;
  THugePageAllocator = nextpas.core.mem.allocator.huge_page.THugePageAllocator;
  THugePageStats = nextpas.core.mem.allocator.huge_page.THugePageStats;
  THugePageSize = nextpas.core.mem.allocator.huge_page.THugePageSize;
  TMappedFileAllocator = nextpas.core.mem.allocator.mapped_file.TMappedFileAllocator;
  TMappedFileStats = nextpas.core.mem.allocator.mapped_file.TMappedFileStats;
  TPageAllocator = nextpas.core.mem.allocator.page.TPageAllocator;
  TPageStats = nextpas.core.mem.allocator.page.TPageStats;
  TPoolAllocator = nextpas.core.mem.allocator.pool.TPoolAllocator;
  TPoolStats = nextpas.core.mem.allocator.pool.TPoolStats;
  TPool2Allocator = nextpas.core.mem.allocator.pool2.TPool2Allocator;
  TPool2Stats = nextpas.core.mem.allocator.pool2.TPool2Stats;
  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  TScopedAllocator = nextpas.core.mem.allocator.scoped.TScopedAllocator;
  TSizeClassAllocator = nextpas.core.mem.allocator.size_class.TSizeClassAllocator;
  TSizeClassStats = nextpas.core.mem.allocator.size_class.TSizeClassStats;
  TSlabAllocator = nextpas.core.mem.allocator.slab.TSlabAllocator;
  TSlabStats = nextpas.core.mem.allocator.slab.TSlabStats;
  TSlidingAllocator = nextpas.core.mem.allocator.sliding.TSlidingAllocator;
  TSlidingStats = nextpas.core.mem.allocator.sliding.TSlidingStats;
  TStackAllocator = nextpas.core.mem.allocator.stack.TStackAllocator;
  TStackStats = nextpas.core.mem.allocator.stack.TStackStats;
  TStackMark = nextpas.core.mem.allocator.stack.TStackMark;
  TStatsAllocator = nextpas.core.mem.allocator.stats.TStatsAllocator;
  TAllocatorStats = nextpas.core.mem.allocator.stats.TAllocatorStats;
  TThreadCacheAllocator = nextpas.core.mem.allocator.thread_cache.TThreadCacheAllocator;
  TThreadCacheStats = nextpas.core.mem.allocator.thread_cache.TThreadCacheStats;
  TThreadSafeAllocator = nextpas.core.mem.allocator.thread_safe.TThreadSafeAllocator;
  TZeroedAllocator = nextpas.core.mem.allocator.zeroed.TZeroedAllocator;

  // === 预算管理 ===
  TMemoryBudget = nextpas.core.mem.budget.TMemoryBudget;
  TBudgetAllocator = nextpas.core.mem.budget.TBudgetAllocator;

function DefaultAllocator: IAllocator; inline;

{** 全局分配函数 - 直接调用 DefaultAllocator **}
function GetMem(ASize: SizeUInt): Pointer; inline;
function AllocMem(ASize: SizeUInt): Pointer; inline;
function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
procedure FreeMem(APtr: Pointer); inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

function CreateFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool; inline;
function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator = nil): IAllocator; inline;

{** 创建默认 Arena（TLocalArena，指定容量） }
function CreateDefaultArena(ACapacity: SizeUInt): IArena;
{** 创建可增长 Arena（TChunkedArena，指定初始容量和最大容量） }
function CreateChunkedArena(AInitialSize: SizeUInt; AMaxSize: SizeUInt = 0): IArena;
{** 创建 Arena 包装的 IAllocator（TLocalArena 后端，仅分配不释放） }
function CreateArenaAllocator(ACapacity: SizeUInt): IAllocator;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt); inline;
procedure SecureZeroBytes(var AData: TBytes); inline;
procedure SecureZeroString(var AStr: AnsiString); inline;
procedure SecureZeroUnicodeString(var AStr: UnicodeString); inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

function GetMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.GetMem(ASize);
end;

function AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.AllocMem(ASize);
end;

function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.ReallocMem(APtr, ASize);
end;

procedure FreeMem(APtr: Pointer);
begin
  DefaultAllocator.FreeMem(APtr);
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
  { 乘法前溢出检查：ACount * AElemSize > High(SizeUInt) 时拒绝 }
  if ACount > (High(SizeUInt) div AElemSize) then
    raise EOutOfMemory.Create(aeOutOfMemory, 'AllocArray: size overflow');
  LTotal := ACount * AElemSize;
  Result := AAllocator.AllocMem(LTotal);
end;

function CreateFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool;
begin
  Result := nextpas.core.mem.pool.CreateFixedSlabPool(ACapacity);
end;

function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator): IAllocator;
begin
  Result := nextpas.core.mem.pool.allocator.CreatePoolAllocator(ABlockSize, ACapacity, AFallback);
end;

function CreateDefaultArena(ACapacity: SizeUInt): IArena;
begin
  Result := TLocalArena.Create(ACapacity);
end;

function CreateChunkedArena(AInitialSize: SizeUInt; AMaxSize: SizeUInt): IArena;
begin
  Result := TChunkedArena.Create(AInitialSize, AMaxSize);
end;

function CreateArenaAllocator(ACapacity: SizeUInt): IAllocator;
begin
  Result := TArenaAllocator.Create(ACapacity);
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

procedure SecureZeroUnicodeString(var AStr: UnicodeString);
begin
  nextpas.core.mem.secure.SecureZeroUnicodeString(AStr);
end;

end.
