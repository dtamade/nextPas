unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *
 * @note 选择指南：
 *   - 通用场景 → DefaultAllocator (IAllocator)
 *   - 请求/帧级生命周期 → CreateDefaultArena (IArena)，用 Reset 一次性释放
 *   - 需要 IAllocator 接口的 Arena → CreateArenaAllocator（仅分配不释放）
 *   - 高频固定大小对象 → MakeFixedSlabPool / TFixedSlabPool / TLocalBlockPool
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
  nextpas.core.text,
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
  nextpas.core.mem.pool.memory_pool,
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
  nextpas.core.mem.central;

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
  IArenaCapacity = nextpas.core.mem.arena.intf.IArenaCapacity;
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

function DefaultAllocator: IAllocator; inline;

{** 全局分配函数 - 直接调用 DefaultAllocator **}
function GetMem(ASize: SizeUInt): Pointer; inline;
function AllocMem(ASize: SizeUInt): Pointer; inline;
function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; inline;
procedure FreeMem(ADst: Pointer); inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

function MakeFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool; inline;
function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
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

function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.ReallocMem(ADst, ASize);
end;

procedure FreeMem(ADst: Pointer);
begin
  DefaultAllocator.FreeMem(ADst);
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
    raise EOutOfMemory.Create(aeOutOfMemory,
      'AllocArray: size overflow (' + IntToStr(ACount) + ' * ' + IntToStr(AElemSize) + ')');
  LTotal := ACount * AElemSize;
  Result := AAllocator.AllocMem(LTotal);
end;

function MakeFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool;
begin
  Result := nextpas.core.mem.pool.MakeFixedSlabPool(ACapacity);
end;

function MakePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator): IAllocator;
begin
  Result := nextpas.core.mem.pool.allocator.MakePoolAllocator(ABlockSize, ACapacity, AFallback);
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
