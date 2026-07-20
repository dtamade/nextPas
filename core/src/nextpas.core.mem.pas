unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *
 * @note 选择指南（Tier-0 标准路径优先）：
 *   - 通用堆热路径 → DefaultHeap / GetMem·FreeMem(size)（Growing 原生，无 IAllocator）
 *   - IAllocator 注入/组合 → DefaultAllocator（Growing IAllocator 根；可选 NEXTPAS_MEM_DEBUG 包装）
 *   - 请求/帧级生命周期 → CreateDefaultArena (IArena)，用 Reset 一次性释放
 *   - 需要 IAllocator 接口的 Arena → CreateArenaAllocator（仅分配不释放）
 *   - 高频固定大小对象 → CreateFixedSlabPool / TFixedSlabPool / TLocalBlockPool
 *   - 高频可变大小对象 → TSlabPool / TSizeClassPool
 *   - 并发池变体 → uses nextpas.core.mem.pool.slab.concurrent / .sharded
 *                     / blockpool.concurrent / .sharded（F3 不进门面）
 *   - 测试泄漏检测 → TTrackingAllocator 包装任意 IAllocator
 *   - 冷门包装器（logging/sampling/hotswap/…）→ 直接 uses 对应子单元
 *   - 可选后端 mimalloc / mmap 分配器 → uses allocator.mimalloc / .mmap（F3 批 2 / G2）
 *
 * @note 双轨硬规则：
 *   - NEXTPAS_MEM_DEBUG 只叠 DefaultAllocator，不观察过程式 GetMem。
 *   - 错误模型见 core/docs/mem/ERROR-POLICY.md（资源不足=nil；编程错误=raise）。
 *
 * @note 门面 re-export Tier-0/1 热路径 + 生产诊断（tracking/sentinel/guard）。
 *       冷门包装器与并发池变体请直接 uses 子单元（F3 批 1）。
 *       Experimental (Tier-3) 亦直接 uses 子单元。
 *       分层与迁移见 core/docs/mem/STDLIB-QUALITY-PLAN.md · FACADES-SLIM-DESIGN。
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
  nextpas.core.mem.debug_wrap,
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
  nextpas.core.mem.pool.sizeclass,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.fixed_slab,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.ring_buffer,
  nextpas.core.mem.memory_map,
  nextpas.core.mem.mapped_slab_pool,
  nextpas.core.mem.secure,
  nextpas.core.mem.pool,
  nextpas.core.mem.stats,
  nextpas.core.mem.allocator.sentinel,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.allocator.rtl;

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
  TGrowingHeapStats = nextpas.core.mem.allocator.growing.TGrowingHeapStats;
  TMemStats = nextpas.core.mem.default.TMemStats;
  TRtlAllocator = nextpas.core.mem.allocator.rtl.TRtlAllocator;
  TCrtAllocator = nextpas.core.mem.allocator.crt.TCrtAllocator;

  { --- Tier-0: Arena ↔ Allocator 桥 --- }
  TLocalArenaAllocator = nextpas.core.mem.allocator.arena.TLocalArenaAllocator;
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TVirtualArenaAllocator = nextpas.core.mem.allocator.arena.TVirtualArenaAllocator;
  TVirtualArenaAdapter = nextpas.core.mem.allocator.arena.TVirtualArenaAdapter;

  { --- Tier-0: Pool / BlockPool（并发/分片变体请 uses 子单元） --- }
  IMemoryPool = nextpas.core.mem.pool.base.IMemoryPool;
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
  TPool = nextpas.core.mem.pool.TPool;
  TSizeClassPool = nextpas.core.mem.pool.sizeclass.TSizeClassPool;
  IBlockPool = nextpas.core.mem.blockpool.IBlockPool;
  IBlockPoolBatch = nextpas.core.mem.blockpool.IBlockPoolBatch;
  TBlockPool = nextpas.core.mem.blockpool.TBlockPool;
  TFixedPool = nextpas.core.mem.pool.fixed.TFixedPool;
  TFixedPoolConcurrent = nextpas.core.mem.pool.fixed.TFixedPoolConcurrent;
  IFixedSlabPool = nextpas.core.mem.pool.fixed_slab.IFixedSlabPool;
  TFixedSlabPool = nextpas.core.mem.pool.fixed_slab.TFixedSlabPool;
  TSlabPool = nextpas.core.mem.pool.slab.TSlabPool;
  TSlabConfig = nextpas.core.mem.pool.slab.TSlabConfig;

  { --- Tier-0: 映射 / 容器 / 过程统计 --- }
  TRingBuffer = nextpas.core.mem.ring_buffer.TRingBuffer;
  TMemoryMap = nextpas.core.mem.memory_map.TMemoryMap;
  TSharedMemory = nextpas.core.mem.memory_map.TSharedMemory;
  TMappedSlabAllocator = nextpas.core.mem.mapped_slab_pool.TMappedSlabAllocator;
  TAllocSnapshot = nextpas.core.mem.stats.TAllocSnapshot;
  TAllocHistogram = nextpas.core.mem.stats.TAllocHistogram;
  TAllocStatsCollector = nextpas.core.mem.stats.TAllocStatsCollector;
  TAllocStatsAllocator = nextpas.core.mem.stats.TAllocStatsAllocator;

  { --- Tier-1: 生产组合器（热路径保留） --- }
  TFallbackAllocator = nextpas.core.mem.allocator.fallback.TFallbackAllocator;
  TFallbackArena = nextpas.core.mem.allocator.fallback.TFallbackArena;

  { --- Tier-1/2: 生产诊断（DEBUG 与测试注入） --- }
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
  TSentinelAllocator = nextpas.core.mem.allocator.sentinel.TSentinelAllocator;
  TGuardAllocator = nextpas.core.mem.allocator.guard.TGuardAllocator;

{** IAllocator plug-in default (Growing IAllocator root, optional NEXTPAS_MEM_DEBUG wraps).
    Same process heap as DefaultHeap; still not the zero-vtable hot path. }
function DefaultAllocator: IAllocator; inline;

{** Process hot-path heap (Growing singleton, concrete type). }
function DefaultHeap: TGrowingAllocator; inline;
function DefaultGrowingAllocator: TGrowingAllocator; inline;

{** Process IAllocator default root (unwrapped Growing adapter; used by DefaultAllocator). }
function GetGrowingIAllocator: IAllocator; inline;
{** Explicit FPC RTL IAllocator backend (bootstrap / explicit opt-in). }
function GetRtlAllocator: IAllocator; inline;
{** nil → process default heap IAllocator; else identity. }
function ResolveAllocator(const AAllocator: IAllocator): IAllocator; inline;

{** Process MemStats: DefaultHeap retention + optional DEBUG wrap counters. }
procedure GetMemStats(out AStats: TMemStats); inline;
function GetMemStats: TMemStats; inline;
{** One-line process MemStats for logs/tests (not a hot path).
 *  Includes heap_debug/debug flags; DEBUG wrap adds debug_active_*/debug_allocs. }
function FormatMemStats(const AStats: TMemStats): string; inline;
function FormatMemStats: string; inline;
{** One-line env/debug profile (flags only) for doctor/logs. }
function FormatMemDebugProfile(const AStats: TMemStats): string; inline;
function FormatMemDebugProfile: string; inline;

{** True when HEAP_DEBUG or HEAP_SAFETY routes process GetMem → DefaultAllocator. }
function IsMemHeapDebugEnabled: Boolean; inline;
function IsMemHeapSafetyEnabled: Boolean; inline;
function IsMemArenaStrictEnabled: Boolean; inline;
{** Pure helper: DEBUG wrap on but process heap not observed (false-negative). }
function MemDebugCoverageGap(const AStats: TMemStats): Boolean; inline;

{** Canonical raise-site message stem Type.Method: reason (see ERROR-POLICY). }
function FormatAllocErrorMsg(const ATypeName, AMethod, AReason: string): string; inline;
function IsWellFormedAllocErrorMsg(const AMsg: string): Boolean; inline;

{** 全局分配函数 — 默认走 DefaultHeap（Growing 原生）。
 *  当 HEAP_DEBUG / HEAP_SAFETY 显式开启时，改走 DefaultAllocator（可被
 *  NEXTPAS_MEM_DEBUG 包装观察；慢路径，生产勿开）。DefaultHeap 本体永不受影响。 }
function GetMem(ASize: SizeUInt): Pointer; inline;
function AllocMem(ASize: SizeUInt): Pointer; inline;
function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
procedure FreeMem(APtr: Pointer); inline;
{** Hot free when size is known (preferred over FreeMem(ptr)).
 *  HEAP_DEBUG 开启时 size 被忽略（经 IAllocator.FreeMem，以保留 tracking）。 }
procedure FreeMem(APtr: Pointer; ASize: SizeUInt); inline;
{** Hot realloc when old size is known.
 *  HEAP_DEBUG 开启时走 IAllocator.ReallocMem(ptr, new)（old size 忽略）。 }
function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; inline;
{** Lookup size-class capacity for a block owned by DefaultHeap (Growing).
 *  True + size-class size for size-class blocks; False for nil / huge / foreign.
 *  Use when size was lost and FreeMem(ptr,size) is still preferred after lookup.
 *  Single-arg FreeMem(ptr) already does this scan internally — prefer keeping size. }
function TryBlockSize(APtr: Pointer; out ASize: SizeUInt): Boolean; inline;

{** Sized free for an IAllocator surface when the block is on DefaultHeap (S5).
 *  Uses DefaultHeap.FreeMem(ptr, classSize) when TryBlockSize succeeds and
 *  neither process route (HEAP_DEBUG/SAFETY) nor NEXTPAS_MEM_DEBUG wrap is on;
 *  otherwise AAllocator.FreeMem(ptr) so plugin tracking still observes free.
 *  Keeps IAllocator five-method freeze; prefer this over bare FreeMem(ptr). }
procedure FreeMemOf(const AAllocator: IAllocator; APtr: Pointer; ASize: SizeUInt); inline;
function TryFreeMemOf(const AAllocator: IAllocator; APtr: Pointer;
  ASize: SizeUInt): Boolean; inline;
{** Sized realloc for IAllocator surface (S5). Same DEBUG-wrap gate as FreeMemOf:
 *  bare same-heap → DefaultHeap.ReallocMem(ptr, classSize, new); else
 *  AAllocator.ReallocMem(ptr, new) so plugin tracking observes. }
function ReallocMemOf(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer; inline;
function TryReallocMemOf(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt; out ANewPtr: Pointer): Boolean; inline;

{** ERROR-POLICY actionable forms: resource failure = False + nil, never raise.
 *  Same backends as GetMem/AllocMem/ReallocMem (DefaultHeap / HEAP_DEBUG path). }
function TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;
function TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean; inline;
function TryReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt;
  out ANewPtr: Pointer): Boolean; inline;
function TryReallocMem(APtr: Pointer; ANewSize: SizeUInt;
  out ANewPtr: Pointer): Boolean; inline;
{** Free a DefaultHeap-owned block after TryBlockSize recovery.
 *  True if freed; False for nil / foreign / unrecoverable size. Prefer FreeMem(ptr,size). }
function TryFreeMem(APtr: Pointer): Boolean; inline;
{** Arena Alloc with Boolean outcome (nil capacity = False). }
function TryArenaAlloc(const AArena: IArena; ASize: SizeUInt;
  out APtr: Pointer): Boolean; inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

function CreateFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool; inline;
function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator = nil): IAllocator; inline;

{** 创建默认 Arena（TLocalArena，指定容量） }
function CreateDefaultArena(ACapacity: SizeUInt): IArena;
{** 创建可增长 Arena（TChunkedArena，指定初始容量和最大容量） }
function CreateChunkedArena(AInitialSize: SizeUInt; AMaxSize: SizeUInt = 0): IArena;
{** 创建容量有界 Arena 包装的 IAllocator（TLocalArena 后端，FreeMem no-op） }
function CreateArenaAllocator(ACapacity: SizeUInt): IAllocator;
{** 创建 VirtualArena 包装的 IAllocator（编译单元 / 大 AST；FreeMem no-op，Reset 回收） }
function CreateVirtualArenaAllocator(AAlignment: SizeUInt = 0): IAllocator;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt); inline;
procedure SecureZeroBytes(var AData: TBytes); inline;
procedure SecureZeroString(var AStr: AnsiString); inline;
procedure SecureZeroUnicodeString(var AStr: UnicodeString); inline;

implementation

uses
  nextpas.core.mem.pool.allocator;

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

function GetGrowingIAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.growing_ia.GetGrowingIAllocator;
end;

function GetRtlAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl.GetRtlAllocator;
end;

function ResolveAllocator(const AAllocator: IAllocator): IAllocator;
begin
  Result := nextpas.core.mem.allocator.rtl.ResolveAllocator(AAllocator);
end;

procedure GetMemStats(out AStats: TMemStats);
begin
  nextpas.core.mem.default.GetMemStats(AStats);
end;

function GetMemStats: TMemStats;
begin
  Result := nextpas.core.mem.default.GetMemStats;
end;

function FormatMemStats(const AStats: TMemStats): string;
begin
  Result := nextpas.core.mem.default.FormatMemStats(AStats);
end;

function FormatMemStats: string;
begin
  Result := nextpas.core.mem.default.FormatMemStats;
end;

function FormatMemDebugProfile(const AStats: TMemStats): string;
begin
  Result := nextpas.core.mem.default.FormatMemDebugProfile(AStats);
end;

function FormatMemDebugProfile: string;
begin
  Result := nextpas.core.mem.default.FormatMemDebugProfile;
end;

function IsMemHeapDebugEnabled: Boolean;
begin
  Result := nextpas.core.mem.default.IsMemHeapDebugEnabled;
end;

function IsMemHeapSafetyEnabled: Boolean;
begin
  Result := nextpas.core.mem.default.IsMemHeapSafetyEnabled;
end;

function IsMemArenaStrictEnabled: Boolean;
begin
  Result := nextpas.core.mem.default.IsMemArenaStrictEnabled;
end;

function MemDebugCoverageGap(const AStats: TMemStats): Boolean;
begin
  Result := nextpas.core.mem.default.MemDebugCoverageGap(AStats);
end;

function FormatAllocErrorMsg(const ATypeName, AMethod, AReason: string): string;
begin
  Result := nextpas.core.mem.error.FormatAllocErrorMsg(ATypeName, AMethod, AReason);
end;

function IsWellFormedAllocErrorMsg(const AMsg: string): Boolean;
begin
  Result := nextpas.core.mem.error.IsWellFormedAllocErrorMsg(AMsg);
end;

function GetMem(ASize: SizeUInt): Pointer;
begin
  if IsMemHeapDebugEnabled then
    Result := DefaultAllocator.GetMem(ASize)
  else
    Result := DefaultHeap.GetMem(ASize);
end;

function AllocMem(ASize: SizeUInt): Pointer;
begin
  if IsMemHeapDebugEnabled then
    Result := DefaultAllocator.AllocMem(ASize)
  else
    Result := DefaultHeap.AllocMem(ASize);
end;

function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if IsMemHeapDebugEnabled then
    Result := DefaultAllocator.ReallocMem(APtr, ASize)
  else
    Result := DefaultHeap.ReallocMem(APtr, ASize);
end;

procedure FreeMem(APtr: Pointer);
begin
  if IsMemHeapDebugEnabled then
    DefaultAllocator.FreeMem(APtr)
  else
    DefaultHeap.FreeMem(APtr);
end;

procedure FreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  if IsMemHeapDebugEnabled then
    DefaultAllocator.FreeMem(APtr)
  else
    DefaultHeap.FreeMem(APtr, ASize);
end;

function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer;
begin
  if IsMemHeapDebugEnabled then
    Result := DefaultAllocator.ReallocMem(APtr, ANewSize)
  else
    Result := DefaultHeap.ReallocMem(APtr, AOldSize, ANewSize);
end;

function TryBlockSize(APtr: Pointer; out ASize: SizeUInt): Boolean;
begin
  { Always query DefaultHeap ownership — HEAP_DEBUG still allocates from the
    same Growing heap (via growing_ia); size-class blocks remain visible. }
  Result := DefaultHeap.TryBlockSize(APtr, ASize);
end;

function FreeMemOfAllowsSizedHeapFree: Boolean; inline;
begin
  { Sized DefaultHeap free must not run when any DEBUG wrap is live — otherwise
    FreeMemOf bypasses tracking/sentinel Free and ActiveAllocCount goes stale. }
  Result := (not IsMemHeapDebugEnabled) and (not GetDebugWrapConfig.Enabled);
end;

procedure FreeMemOf(const AAllocator: IAllocator; APtr: Pointer; ASize: SizeUInt);
var
  LClassSize: SizeUInt;
begin
  if APtr = nil then
    Exit;
  if (ASize > 0) and FreeMemOfAllowsSizedHeapFree and
    TryBlockSize(APtr, LClassSize) then
  begin
    DefaultHeap.FreeMem(APtr, LClassSize);
    Exit;
  end;
  if AAllocator <> nil then
    AAllocator.FreeMem(APtr)
  else
    FreeMem(APtr);
end;

function TryFreeMemOf(const AAllocator: IAllocator; APtr: Pointer;
  ASize: SizeUInt): Boolean;
var
  LClassSize: SizeUInt;
begin
  if APtr = nil then
    Exit(False);
  if (ASize > 0) and FreeMemOfAllowsSizedHeapFree and
    TryBlockSize(APtr, LClassSize) then
  begin
    DefaultHeap.FreeMem(APtr, LClassSize);
    Exit(True);
  end;
  if AAllocator <> nil then
  begin
    AAllocator.FreeMem(APtr);
    Exit(True);
  end;
  { U1: nil allocator — free only when DefaultHeap owns the block (safe),
    via process FreeMem so HEAP_DEBUG still tracks. Foreign → False (no UB).
    FreeMemOf(nil, foreign) still falls through to process FreeMem (UB);
    Try stays the fail-closed form. }
  if not TryBlockSize(APtr, LClassSize) then
    Exit(False);
  FreeMem(APtr);
  Result := True;
end;

function ReallocMemOf(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer;
var
  LClassSize: SizeUInt;
begin
  if APtr = nil then
  begin
    if AAllocator <> nil then
      Exit(AAllocator.GetMem(ANewSize));
    Exit(GetMem(ANewSize));
  end;
  if (AOldSize > 0) and FreeMemOfAllowsSizedHeapFree and
    TryBlockSize(APtr, LClassSize) then
    Exit(DefaultHeap.ReallocMem(APtr, LClassSize, ANewSize));
  if AAllocator <> nil then
    Exit(AAllocator.ReallocMem(APtr, ANewSize));
  Result := ReallocMem(APtr, ANewSize);
end;

function TryReallocMemOf(const AAllocator: IAllocator; APtr: Pointer;
  AOldSize, ANewSize: SizeUInt; out ANewPtr: Pointer): Boolean;
begin
  { Same success semantics as ReallocMemOf + Boolean: no extra rejects.
    nil allocator + nil ptr + size>0 falls back to process GetMem (S1). }
  ANewPtr := ReallocMemOf(AAllocator, APtr, AOldSize, ANewSize);
  Result := (ANewPtr <> nil) or (ANewSize = 0);
end;

function TryGetMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := GetMem(ASize);
  Result := APtr <> nil;
end;

function TryAllocMem(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := AllocMem(ASize);
  Result := APtr <> nil;
end;

function TryReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt;
  out ANewPtr: Pointer): Boolean;
begin
  ANewPtr := ReallocMem(APtr, AOldSize, ANewSize);
  Result := (ANewPtr <> nil) or (ANewSize = 0);
end;

function TryReallocMem(APtr: Pointer; ANewSize: SizeUInt;
  out ANewPtr: Pointer): Boolean;
begin
  ANewPtr := ReallocMem(APtr, ANewSize);
  Result := (ANewPtr <> nil) or (ANewSize = 0);
end;

function TryFreeMem(APtr: Pointer): Boolean;
var
  LSize: SizeUInt;
begin
  if APtr = nil then
    Exit(False);
  if not TryBlockSize(APtr, LSize) then
    Exit(False);
  FreeMem(APtr, LSize);
  Result := True;
end;

function TryArenaAlloc(const AArena: IArena; ASize: SizeUInt;
  out APtr: Pointer): Boolean;
begin
  if AArena = nil then
  begin
    APtr := nil;
    Exit(False);
  end;
  APtr := AArena.Alloc(ASize);
  Result := APtr <> nil;
end;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
begin
  { T3: nil → process default heap (S5 ResolveAllocator), never AV. }
  Result := ResolveAllocator(AAllocator).AllocMem(ASize);
end;

function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
var
  LTotal: SizeUInt;
begin
  if (ACount = 0) or (AElemSize = 0) then Exit(nil);
  { T2: count*elemSize overflow is a programming error (ERROR-POLICY), not OOM. }
  if ACount > (High(SizeUInt) div AElemSize) then
    raise EAllocError.Create(aeInvalidLayout,
      FormatAllocErrorMsg('AllocArray', 'AllocArray', 'count*elemSize overflow'));
  LTotal := ACount * AElemSize;
  { T3: nil allocator → process default heap. }
  Result := ResolveAllocator(AAllocator).AllocMem(LTotal);
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
  Result := TLocalArenaAllocator.Create(ACapacity);
end;

function CreateVirtualArenaAllocator(AAlignment: SizeUInt): IAllocator;
begin
  if AAlignment = 0 then
    Result := TVirtualArenaAllocator.Create
  else
    Result := TVirtualArenaAllocator.Create(AAlignment);
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
