unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *
 * @note 选择指南（Tier-0 标准路径优先）：
 *   - 通用堆热路径 → DefaultHeap / GetMem·FreeMem（Growing 原生，无 IAllocator）
 *   - IAllocator 注入/组合 → DefaultAllocator（当前 RTL；包装器后端）
 *   - 请求/帧级生命周期 → CreateDefaultArena (IArena)，用 Reset 一次性释放
 *   - 需要 IAllocator 接口的 Arena → CreateArenaAllocator（仅分配不释放）
 *   - 高频固定大小对象 → CreateFixedSlabPool / TFixedSlabPool / TLocalBlockPool
 *   - 高频可变大小对象 → TSlabPool / TSizeClassPool
 *   - 并发场景 → TSlabPoolConcurrent / TSlabPoolSharded / TBlockPoolConcurrent
 *   - 测试泄漏检测 → TTrackingAllocator 包装任意 IAllocator
 *
 * @note 门面只 re-export Tier-0/1/2。Experimental (Tier-3) 请直接 uses 子单元。
 *       分层与迁移见 core/docs/mem/STDLIB-QUALITY-PLAN.md。
 *
 * @note 固定大小 vs 通用 API：
 *   - Acquire/Release — 固定大小槽位池（IPool/IBlockPool），不关心具体大小
 *   - GetMem/FreeMem — 过程式默认堆（DefaultHeap/Growing），按请求大小路由
 *   - IAllocator.GetMem/FreeMem — 可替换后端契约（间接调用，非热路径）
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
  nextpas.core.mem.stats,
  nextpas.core.mem.oom,
  nextpas.core.mem.allocator.callback,
  nextpas.core.mem.allocator.batch,
  nextpas.core.mem.allocator.sentinel,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.leak_report,
  nextpas.core.mem.allocator.logging,
  nextpas.core.mem.allocator.debug_alloc,
  nextpas.core.mem.allocator.sampling,
  nextpas.core.mem.allocator.aligned,
  nextpas.core.mem.allocator.bounded,
  nextpas.core.mem.allocator.counting,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.fail,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.hotswap,
  nextpas.core.mem.allocator.pool,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.scoped,
  nextpas.core.mem.allocator.stats,
  nextpas.core.mem.allocator.thread_safe,
  nextpas.core.mem.allocator.zeroed,
  nextpas.core.mem.budget;

type
  { --- Tier-0: 契约与基础 --- }
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TAllocError = nextpas.core.mem.error.TAllocError;
  EAllocError = nextpas.core.mem.error.EAllocError;
  EOutOfMemory = nextpas.core.mem.error.EOutOfMemory;
  EInvalidLayout = nextpas.core.mem.error.EInvalidLayout;
  EInvalidPointer = nextpas.core.mem.error.EInvalidPointer;
  EDoubleFree = nextpas.core.mem.error.EDoubleFree;

  TMemMutex = nextpas.core.mem.mutex.TMemMutex;
  TMemRwLock = nextpas.core.mem.rwlock.TMemRwLock;

  { --- Tier-0: Arena --- }
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
  TThreadArenaConfig = nextpas.core.mem.arena.thread.TThreadArenaConfig;
  TThreadArenaManager = nextpas.core.mem.arena.thread.TThreadArenaManager;
  TThreadArena = nextpas.core.mem.arena.thread.TThreadArena;

  { --- Tier-0: 默认堆与后端 --- }
  TGrowingAllocator = nextpas.core.mem.allocator.growing.TGrowingAllocator;
  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  TCrtAllocator = nextpas.core.mem.allocator.crt.TCrtAllocator;
  TMimallocAllocator = nextpas.core.mem.allocator.mimalloc.TMimallocAllocator;
  TMemoryMapAllocator = nextpas.core.mem.allocator.mmap.TMemoryMapAllocator;

  { --- Tier-0: Arena ↔ Allocator 桥 --- }
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TVirtualArenaAdapter = nextpas.core.mem.allocator.arena.TVirtualArenaAdapter;

  { --- Tier-0: Pool / BlockPool --- }
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

  { --- Tier-0: 映射 / 容器 / 运行时 --- }
  TRingBuffer = nextpas.core.mem.ring_buffer.TRingBuffer;
  TMemoryMap = nextpas.core.mem.memory_map.TMemoryMap;
  TSharedMemory = nextpas.core.mem.memory_map.TSharedMemory;
  TMappedSlabAllocator = nextpas.core.mem.mapped_slab_pool.TMappedSlabAllocator;
  TAllocSnapshot = nextpas.core.mem.stats.TAllocSnapshot;
  TAllocHistogram = nextpas.core.mem.stats.TAllocHistogram;
  TAllocStatsCollector = nextpas.core.mem.stats.TAllocStatsCollector;
  TAllocStatsAllocator = nextpas.core.mem.stats.TAllocStatsAllocator;
  TOomEvent = nextpas.core.mem.oom.TOomEvent;
  TOomHandler = nextpas.core.mem.oom.TOomHandler;
  TOomAllocator = nextpas.core.mem.oom.TOomAllocator;
  TMemoryBudget = nextpas.core.mem.budget.TMemoryBudget;
  TBudgetAllocator = nextpas.core.mem.budget.TBudgetAllocator;

  { --- Tier-1: 生产组合器 --- }
  TFallbackAllocator = nextpas.core.mem.allocator.fallback.TFallbackAllocator;
  TFallbackArena = nextpas.core.mem.allocator.fallback.TFallbackArena;
  TBoundedAllocator = nextpas.core.mem.allocator.bounded.TBoundedAllocator;
  TBoundedStats = nextpas.core.mem.allocator.bounded.TBoundedStats;
  TThreadSafeAllocator = nextpas.core.mem.allocator.thread_safe.TThreadSafeAllocator;
  TScopedAllocator = nextpas.core.mem.allocator.scoped.TScopedAllocator;
  TAlignedAllocator = nextpas.core.mem.allocator.aligned.TAlignedAllocator;
  TAlignedStats = nextpas.core.mem.allocator.aligned.TAlignedStats;
  TZeroedAllocator = nextpas.core.mem.allocator.zeroed.TZeroedAllocator;
  TStatsAllocator = nextpas.core.mem.allocator.stats.TStatsAllocator;
  TAllocatorStats = nextpas.core.mem.allocator.stats.TAllocatorStats;
  THotswapAllocator = nextpas.core.mem.allocator.hotswap.THotswapAllocator;
  TPoolAllocator = nextpas.core.mem.allocator.pool.TPoolAllocator;
  TPoolStats = nextpas.core.mem.allocator.pool.TPoolStats;
  TBatchAllocator = nextpas.core.mem.allocator.batch.TBatchAllocator;
  TGetMemCallback = nextpas.core.mem.allocator.callback.TGetMemCallback;
  TAllocMemCallback = nextpas.core.mem.allocator.callback.TAllocMemCallback;
  TReallocMemCallback = nextpas.core.mem.allocator.callback.TReallocMemCallback;
  TFreeMemCallback = nextpas.core.mem.allocator.callback.TFreeMemCallback;

  { --- Tier-2: 诊断与故障注入 --- }
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
  TSentinelAllocator = nextpas.core.mem.allocator.sentinel.TSentinelAllocator;
  TGuardAllocator = nextpas.core.mem.allocator.guard.TGuardAllocator;
  TLeakReportAllocator = nextpas.core.mem.allocator.leak_report.TLeakReportAllocator;
  TLeakEntry = nextpas.core.mem.allocator.leak_report.TLeakEntry;
  TLeakReportResult = nextpas.core.mem.allocator.leak_report.TLeakReportResult;
  TDebugAllocator = nextpas.core.mem.allocator.debug_alloc.TDebugAllocator;
  TFailAllocator = nextpas.core.mem.allocator.fail.TFailAllocator;
  TFailStats = nextpas.core.mem.allocator.fail.TFailStats;
  TLoggingAllocator = nextpas.core.mem.allocator.logging.TLoggingAllocator;
  TSamplingAllocator = nextpas.core.mem.allocator.sampling.TSamplingAllocator;
  TSampleEntry = nextpas.core.mem.allocator.sampling.TSampleEntry;
  TCountingAllocator = nextpas.core.mem.allocator.counting.TCountingAllocator;
  TCountingStats = nextpas.core.mem.allocator.counting.TCountingStats;

{** IAllocator plug-in default (RTL). For composers/diagnostics injection. }
function DefaultAllocator: IAllocator; inline;

{** Process hot-path heap (Growing singleton, concrete type). }
function DefaultHeap: TGrowingAllocator; inline;
function DefaultGrowingAllocator: TGrowingAllocator; inline;

{** 全局分配函数 — 走 DefaultHeap（Growing 原生，无 interface 间接调用） }
function GetMem(ASize: SizeUInt): Pointer; inline;
function AllocMem(ASize: SizeUInt): Pointer; inline;
function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
procedure FreeMem(APtr: Pointer); inline;
{** Hot free when size is known (preferred over FreeMem(ptr)). }
procedure FreeMem(APtr: Pointer; ASize: SizeUInt); inline;
{** Hot realloc when old size is known. }
function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; inline;

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

function DefaultHeap: TGrowingAllocator;
begin
  Result := nextpas.core.mem.default.DefaultHeap;
end;

function DefaultGrowingAllocator: TGrowingAllocator;
begin
  Result := nextpas.core.mem.default.DefaultGrowingAllocator;
end;

function GetMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultHeap.GetMem(ASize);
end;

function AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultHeap.AllocMem(ASize);
end;

function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := DefaultHeap.ReallocMem(APtr, ASize);
end;

procedure FreeMem(APtr: Pointer);
begin
  DefaultHeap.FreeMem(APtr);
end;

procedure FreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  DefaultHeap.FreeMem(APtr, ASize);
end;

function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer;
begin
  Result := DefaultHeap.ReallocMem(APtr, AOldSize, ANewSize);
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
