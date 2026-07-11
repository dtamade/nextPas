# nextpas.core.mem API 参考

## 分配器选择指南

### 决策树

```
需要分配内存？
├─ 通用场景 (malloc 替代) → DefaultAllocator (IAllocator)
│  └─ 需要跟踪/泄漏检测 → TTrackingAllocator 包装
│  └─ 需要增强泄漏报告 → TLeakReportAllocator（调用栈+时间戳+标签聚合）
│  └─ 需要哨兵守卫 → TSentinelAllocator（双端哨兵+延迟释放+校验和）
│
├─ 请求/帧级生命周期 → CreateDefaultArena (IArena)
│  ├─ 固定容量 → TLocalArena
│  ├─ 可增长 → TChunkedArena
│  └─ 虚拟内存 → TVirtualArena (record, 不实现 IArena)
│
├─ 高频小对象 (8B-512B)
│  ├─ 单线程 → TSizeClassPool / TFixedSlabPool
│  └─ 多线程 → TSlabPoolConcurrent / TSlabPoolSharded
│
├─ 固定大小块池
│  ├─ 单线程 → TBlockPool / TFixedPool
│  └─ 多线程 → TBlockPoolConcurrent / TShardedBlockPool
│
└─ 特殊场景
   ├─ 需要 IAllocator 接口的 Arena → CreateArenaAllocator
   ├─ 需要 fallback 链 → TFallbackAllocator
   ├─ 需要 mmap 匿名映射 → TMemoryMapAllocator
   ├─ 需要 mimalloc → TMimallocAllocator (动态库)
   ├─ 需要 NUMA 感知 → TNumaAllocator（拓扑检测+节点路由）
   ├─ 需要分配预测 → TPredictionAllocator（频率跟踪+预分配）
   └─ 需要批量分配 → IBatchAllocator 接口
```

### 性能特征

| 分配器 | 64B ns/op | 线程安全 | 适用场景 |
|--------|-----------|----------|----------|
| DefaultAllocator | 16 | ✅ | 通用 |
| TLocalArena | 5 | ❌ | 帧分配 |
| TChunkedArena | 26 | ❌ | 可增长帧分配 |
| TVirtualArena | 44 | ❌ | 编译器热路径 |
| TSizeClassPool | 8 | ❌ | 小对象池 |
| TSlabPoolConcurrent | 4 | ✅ | 并发小对象 |
| TBlockPool | 12 | ❌ | 固定大小块 |
| TBlockPoolConcurrent | 8 | ✅ | 并发固定块 |

### 常见场景示例

**场景 1: 通用分配**
```pascal
uses nextpas.core.mem;

var
  LPtr: Pointer;
begin
  LPtr := DefaultAllocator.GetMem(1024);
  try
    // 使用内存...
  finally
    DefaultAllocator.FreeMem(LPtr);
  end;
end;
```

**场景 2: 请求级 Arena**
```pascal
uses nextpas.core.mem;

var
  LArena: IArena;
  LPtr: Pointer;
begin
  LArena := CreateDefaultArena(64 * 1024);  // 64KB
  try
    LPtr := LArena.Alloc(1024);
    // 使用内存...不需要单独 Free
  finally
    LArena.Reset;  // 一次性释放全部
  end;
end;
```

**场景 3: 高频小对象**
```pascal
uses nextpas.core.mem;

var
  LPool: TSizeClassPool;
  LPtr: Pointer;
begin
  LPool := TSizeClassPool.Create;
  try
    LPtr := LPool.Alloc(64);
    try
      // 使用内存...
    finally
      LPool.Release(LPtr, 64);
    end;
  finally
    LPool.Free;
  end;
end;
```

**场景 4: 并发分配**
```pascal
uses nextpas.core.mem;

var
  LPool: TSlabPoolConcurrent;
  LPtr: Pointer;
begin
  LPool := TSlabPoolConcurrent.Create(4096);
  try
    LPtr := LPool.GetMem(64);
    try
      // 使用内存...
    finally
      LPool.FreeMem(LPtr);
    end;
  finally
    LPool.Free;
  end;
end;
```

**场景 5: 泄漏检测**
```pascal
uses nextpas.core.mem;

var
  LTracker: TTrackingAllocator;
  LPtr: Pointer;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);
  try
    LPtr := LTracker.GetMem(1024);
    try
      // 使用内存...
    finally
      LTracker.FreeMem(LPtr);
    end;
    
    if LTracker.HasLeaks then
      WriteLn(LTracker.ReportLeaks);
  finally
    LTracker.Free;
  end;
end;
```

---

## 先看这两个核心契约

### `IArena`

`IArena` 是 class-based arena 的最小公共接口。当前实现方是 `TLocalArena`、`TChunkedArena`，以及包装器 `TArenaConcurrent`。

```pascal
type
  IArena = interface
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;
  end;
```

要点：

- 构造或初始化失败走异常，例如 `EOutOfMemory`、`EAllocError`
- `Alloc*` 失败返回 `nil`
- `IArena` 故意不暴露 `TotalSize`；总容量和底层保留字节数是实现细节

### `IAllocator`

`IAllocator` 是更稳定的通用分配器接口。`nextpas.core.mem` 的默认分配器、tracking wrapper、fallback wrapper、arena allocator 都围绕它工作。

```pascal
type
  IAllocator = interface
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function Traits: TAllocatorTraits;
  end;
```

要点：

- 核心 5 方法：GetMem/AllocMem/ReallocMem/FreeMem + Traits
- `AllocMem` 语义是 zero-initialized allocation
- `FreeMem` 当前是 `procedure`，不返回释放字节数
- `MemSize` 和 `AllocAligned`/`FreeAligned` 已移至更专门的接口（`IMemoryPool.MemSizeOf` 和 `IArena.AllocAligned`）
- `FreeMem(nil)` 静默返回（无操作）；`GetMem(0)` 返回 nil

## 共享 arena 类型

### `TArenaMark`

```pascal
type
  TArenaMark = record
    FrontOffset: SizeUInt;  // 含指针对象的偏移
    BackOffset: SizeUInt;   // 无指针对象的偏移
    TotalUsed: SizeUInt;    // 标记时的 TotalUsed
    LargeUsed: SizeUInt;    // 仅 TVirtualArena 使用：标记时仍存活的大对象字节数
    AllocCount: QWord;      // 标记时的分配计数（用于 RestoreToMark 回退）
  end;
```

`SaveMark` / `RestoreToMark` 通过这个记录表达”回退到某个分配位置”。

注意：`LargeUsed` 和 `AllocCount` 是扩展字段，仅 `TVirtualArena` 有效使用；其他 Arena 实现填 0。

### `TArenaStats`

```pascal
type
  TArenaStats = record
    TotalAllocated: SizeUInt;
    TotalUsed: SizeUInt;
    PeakUsed: SizeUInt;
    AllocCount: QWord;
  end;
```

### `TArenaConfig`

```pascal
type
  TArenaConfig = record
    InitialSize: SizeUInt;
    MaxSize: SizeUInt;
    GrowthKind: TArenaGrowthKind;
    GrowthFactor: Double;
    GrowthStep: SizeUInt;
    Alignment: SizeUInt;
    KeepSegments: Boolean;

    class function Default(AInitialSize: SizeUInt): TArenaConfig; static;
  end;
```

这套配置目前只给 `TChunkedArena` 使用。

## `TLocalArena`

`TLocalArena` 是固定容量、class-based 的 bump arena，实现了 `IArena`。

### 构造函数

```pascal
constructor Create(const ACapacity: SizeUInt); overload;
constructor Create(const ACapacity: SizeUInt; const AAllocator: IAllocator); overload;
```

### 公开方法

```pascal
function Alloc(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
function UsedSize: SizeUInt;
function RemainingSize: SizeUInt;
function Stats: TArenaStats;

function AllocFast(ASize: SizeUInt): Pointer;
function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
```

### 诊断属性

- `Capacity`
- `PeakUsed`
- `TotalAllocCount`

### 行为说明

- `Reset` 只把 offset 归零，不释放后备 buffer
- `AllocFast` / `AllocAlignedFast` 只适合调用方已经证明边界安全的热路径

## `TChunkedArena`

`TChunkedArena` 是分段增长的 class-based arena，实现了 `IArena`。

### 构造函数

```pascal
constructor Create(const AConfig: TArenaConfig); overload;
constructor Create(AInitialSize: SizeUInt; AMaxSize: SizeUInt = 0); overload;
```

### 公开方法

`TChunkedArena` 完整实现 `IArena`，并额外提供：

```pascal
function SegmentCount: SizeUInt;
property PeakUsed: SizeUInt;
property TotalAllocCount: QWord;
property Alignment: SizeUInt;
```

### 行为说明

- `GrowthKind` 支持几何增长和线性增长
- `KeepSegments=True` 时，`Reset` 保留现有 segments
- `KeepSegments=False` 时，`Reset` 会把多余 segments 放进 chunk cache，后续再复用

## `TLocalBlockPool`

`TLocalBlockPool` 是最小化的 class-based 固定块池。

公开方法：

```pascal
constructor Create(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
function Acquire: Pointer;
function TryAcquire(out APtr: Pointer): Boolean;
procedure Release(const APtr: Pointer);
procedure Reset;
function BlockSize: SizeUInt;
function Capacity: SizeUInt;
function Available: SizeUInt;
function InUse: SizeUInt;
function IsFull: Boolean;
function IsEmpty: Boolean;
function Owns(const APtr: Pointer): Boolean;
```

选择建议：

- 单线程、单 owner、不会跨模块暴露 pool contract：优先 `TLocalBlockPool`
- 只需要最直接的固定块 acquire/release，不需要 interface、批量 API 或自定义对齐：优先 `TLocalBlockPool`

## `IBlockPool`、`IBlockPoolBatch` 和 `TBlockPool`

`TBlockPool` 是带 interface contract 的固定块池实现，public surface 比 `TLocalBlockPool` 更完整。

核心 contract：

```pascal
type
  IBlockPool = interface
    function Acquire: Pointer;
    function TryAcquire(out APtr: Pointer): Boolean;
    procedure Release(APtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;
  end;

  IBlockPoolBatch = interface(IBlockPool)
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);
  end;
```

`TBlockPool` 额外提供：

- `Alignment`
- `AcquireUnchecked` / `ReleaseUnchecked`
- `Owns`
- `GetRange`
- `AcquireN` / `ReleaseN`

选择建议：

- 需要 `IBlockPool` / `IBlockPoolBatch` 作为模块边界 contract：选 `TBlockPool`
- 需要显式对齐、批量接口、ownership/range 诊断：选 `TBlockPool`
- 未来要平滑切到 `TShardedBlockPool`、并发包装器或其他 interface consumer：选 `TBlockPool`

## `TVirtualArena`

`TVirtualArena` 是 record-based arena，不实现 `IArena`。它直接暴露更低层、更偏性能导向的 API。

### 初始化和释放

```pascal
procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
procedure TVirtualArena_Release(var AArena: TVirtualArena);
```

### 公开方法

```pascal
function Alloc(ASize: SizeUInt): Pointer;
function AllocNoPointer(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function AllocFast(ASize: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
procedure ResetHard;
procedure Release;
function TotalAllocated: SizeUInt;
function TotalUsed: SizeUInt;
function PeakUsed: SizeUInt;
function AllocCount: SizeUInt;
```

### 行为说明

- `Alloc` 从前向 bump pointer 分配
- `AllocNoPointer` 从后向 bump pointer 分配，适合 pointer-free payload
- `AllocFast` 跳过安全检查，不更新统计，也不保证对齐
- `Reset` 保留 reserved range 和已经 committed 的页面
- `ResetHard` 会 decommit 已提交页面，但保留 reserved virtual address range
- 大对象（`>= ARENA_LARGE_THRESHOLD`）走独立 mmap，`Reset` / `RestoreToMark` 不回收，只有 `Release` 才统一释放

## `TVirtualArenaAllocator`、`TFastArenaAllocator` 和 `TArenaAllocator`

`TVirtualArenaAllocator` 把 `TVirtualArena` 包成 `IAllocator`。

```pascal
type
  TVirtualArenaAllocator = class(TInterfacedObject, IAllocator)
  public
    constructor Create(AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    procedure Reset;
    property Arena: TVirtualArena read FArena;
  end;

  TFastArenaAllocator = TVirtualArenaAllocator;
```

在门面 `nextpas.core.mem` 里，`TArenaAllocator` 也是同一个兼容别名链：

```pascal
TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
```

行为说明：

- `GetMem` / `AllocMem` 最终走 `TVirtualArena`
- 单块 `FreeMem` 不会真正回收 arena 内存
- `Reset` 一次性回退整个 arena

## 线程本地 arena surface

### `TThreadArenaConfig`

```pascal
type
  TThreadArenaConfig = record
    ArenaCapacity: SizeUInt;
    MaxPoolSize: Integer;
  end;
```

### `TThreadArenaManager`

```pascal
constructor Create(const AConfig: TThreadArenaConfig);
function Get: TLocalArena;
procedure DrainTLS;
function HasArena: Boolean;
function PoolSize: Integer;
function TotalCreated: Integer;
function TotalRecycled: Integer;
```

### `TThreadArena`

```pascal
class function Create(AArena: TLocalArena): TThreadArena; static;
function Alloc(ASize: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
function AllocFast(ASize: SizeUInt): Pointer;
function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
function UsedSize: SizeUInt;
function PeakUsed: SizeUInt;
function Stats: TArenaStats;
property Arena: TLocalArena read FArena;
```

行为说明：

- 当前实现通过 `threadvar` 缓存每线程 arena
- 线程结束前需要显式调用 `DrainTLS`
- 当前代码没有自动 threadvar cleanup hook

**使用示例**:
```pascal
var
  LArena: TLocalArena;
  LThread: TThreadArena;
  LPtr: Pointer;
begin
  LArena := TLocalArena.Create(64 * 1024);
  LThread := TThreadArena.Create(LArena);
  LPtr := LThread.Alloc(256);
  // 帧级重置
  LThread.Reset;
end;
```

## 门面 helper

门面 `nextpas.core.mem` 提供这几个常用 helper：

```pascal
function DefaultAllocator: IAllocator;
function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;

function CreateFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool;
function CreatePoolAllocator(ABlockSize: SizeUInt; ACapacity: Integer;
  AFallback: IAllocator = nil): IAllocator;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt);
procedure SecureZeroBytes(var AData: TBytes);
procedure SecureZeroString(var AStr: AnsiString);
```

- `SecureZero*` 使用平台安全清零 API（不会被编译器优化掉）

## 错误类型

门面 re-export 的错误类型（来自 `nextpas.core.mem.error`）：

```pascal
type
  TAllocatorKind = (akCustom, akRTL, akCRT, akMMap, akMimalloc, akArena, akGuard);
  EAllocError = class(Exception) ... end;
  EOutOfMemory = class(EAllocError) ... end;
  EInvalidLayout = class(EAllocError) ... end;
  EInvalidPointer = class(EAllocError) ... end;
  EDoubleFree = class(EAllocError) ... end;
```

## 同步原语

门面 re-export 的 mem-local 同步包装（来自 `nextpas.core.mem.mutex` / `rwlock`）：

```pascal
type
  TMemMutex = record ... end;    // 递归安全互斥锁
  TMemRwLock = record ... end;   // 读写锁
```

## Allocator 包装

### `TTrackingAllocator`

跟踪包装器，统计分配次数/字节数，支持回调通知。

```pascal
constructor Create(AInner: IAllocator);
property TotalAllocs: QWord;
property TotalFrees: QWord;
property TotalBytesAllocated: QWord;
property TotalBytesFreed: QWord;
property ActiveAllocations: QWord;
property ActiveBytes: QWord;
procedure ResetStats;
```

### `TFallbackAllocator` / `TFallbackArena`

多后端 fallback 链，主分配器失败时自动尝试备用。

```pascal
constructor Create(APrimary: IAllocator; AFallback: IAllocator);
```

**使用示例**:
```pascal
var
  LPrimary, LFallback, LAllocator: IAllocator;
begin
  LPrimary := GetRtlAllocator;
  LFallback := CreateAnonymousMemoryMapAllocator(64 * 1024 * 1024);
  LAllocator := TFallbackAllocator.Create(LPrimary, LFallback);
  // 如果 LPrimary.GetMem 返回 nil（OOM），自动尝试 LFallback
end;
```

**TFallbackArena**: 包装 IArena 的 fallback 版本，Reset 时同时重置主 arena 和 fallback arena。

### `TMimallocAllocator`

mimalloc 动态加载后端。需要运行时可找到 mimalloc 共享库。

```pascal
function GetMimallocAllocator: IAllocator;
function TryGetMimallocAllocator(out A: IAllocator): Boolean;
```

### `TMemoryMapAllocator`

基于 mmap 的匿名映射分配器。

```pascal
function CreateAnonymousMemoryMapAllocator(AReservationSize: UInt64): IAllocator;
```

## 高性能分配器

### `TBumpAllocator`

线性分配器，分配 O(1) 无锁。适合请求/帧级生命周期。

```pascal
constructor Create(AInner: IAllocator; AChunkSize: SizeUInt);
```

### `TCascadeAllocator`

级联 fallback 链，按优先级尝试多个分配器。

```pascal
constructor Create(const AAllocators: array of IAllocator);
```

### `TBitmapAllocator`

位图管理的固定大小槽位池，O(1) 分配释放。

```pascal
constructor Create(AInner: IAllocator; ABlockSize: SizeUInt; ACapacity: Integer);
```

### `TBatchAllocator`

批量分配包装器，减少锁频率。

```pascal
constructor Create(AInner: IAllocator);
```

## 调试/监控分配器

### `TSentinelAllocator`

哨兵守卫分配器，双端哨兵 + 延迟释放 + 校验和，检测越界写入和 double-free。

```pascal
constructor Create(AInner: IAllocator);
```

### `TGuardAllocator`

Guard page 分配器，每次分配用未映射页包围，越界写入立即 SIGSEGV。

```pascal
constructor Create;
```

### `TLeakReportAllocator`

泄漏报告分配器，记录分配调用栈、时间戳、标签聚合。

```pascal
constructor Create(AInner: IAllocator);
function Report: TLeakReportResult;
```

### `TLoggingAllocator`

分配日志分配器，记录所有分配/释放操作。

```pascal
constructor Create(AInner: IAllocator);
```

### `TDebugAllocator`

调试分配器，毒化释放内存 ($DE) 和新分配内存 ($AB)，检测 use-after-free 和未初始化读取。

```pascal
constructor Create(AInner: IAllocator);
```

### `TWatermarkAllocator`

高水位线分配器，跟踪峰值内存使用。

```pascal
constructor Create(AInner: IAllocator);
property HighWaterMark: SizeUInt;
```

### `TSamplingAllocator`

采样分配器，按概率采样分配调用栈，用于性能分析。

```pascal
constructor Create(AInner: IAllocator);
```

### `TPrefixAllocator`

前缀分配器，为每次分配添加元数据头。

```pascal
constructor Create(AInner: IAllocator);
```

### `TPredictionAllocator`

预测分配器，跟踪分配频率，预分配高频大小。

```pascal
constructor Create(AInner: IAllocator);
```

### `TReplayAllocator`

重放分配器，记录分配序列，可重放到目标分配器。

```pascal
constructor Create(AInner: IAllocator);
procedure Replay(ATarget: IAllocator);
```

### `TNumaAllocator`

NUMA 感知分配器，拓扑检测 + 节点路由。

```pascal
constructor Create(ADefault: IAllocator);
procedure SetNodeAllocator(ANode: Integer; AAlloc: IAllocator);
```

## Pool 类型

### `IPool`

池的最小接口（来自 `nextpas.core.mem.pool.base`）。

### `TSizeClassPool`

大小类池，自动根据请求大小选择最优 slab。

### `TFixedPool` / `TFixedPoolConcurrent`

固定大小对象池。Concurrent 变体线程安全。

### `TSlabPool` / `TSlabPoolConcurrent` / `TSlabPoolSharded`

页级 slab 池。三种变体：基础、并发、分片。

### `TBlockPoolConcurrent` / `TShardedBlockPool`

并发/分片块池。`TShardedBlockPool` 按线程分片减少争用。

**关键方法**:
- `Acquire: Pointer` — 获取一个块
- `Release(aPtr: Pointer)` — 归还一个块
- `TrimIdleSegments: SizeInt` — 回收空闲段内存（段尾全空闲的段会被释放）
- `FlushThreadCache` — 刷新当前线程缓存（短线程生命周期优化）

**DEBUG 模式特性**:
- 释放后内存被 `$DE` 毒化（use-after-free 检测）
- 新分配内存被 `$AB` 毒化（未初始化读取检测）

### `TStackPool`

LIFO 栈池，适合确定性生命周期的临时对象。

### `IMemoryPool`

内存池接口（定义在 `nextpas.core.mem.pool.base`，继承自 `IPool`）。

## 容器

### `TRingBuffer`

环形缓冲区。对标 Go chan，基准测试中 2x 快于 Go chan。

## 内存映射

### `TMemoryMap` / `TSharedMemory`

平台 mmap 包装。`TSharedMemory` 支持命名共享内存。

### `TMappedSlabAllocator`

大块匿名映射上的 slab 分配器。

## 选择建议

- 需要固定容量、最简单的 `IArena`：`TLocalArena`
- 需要增长能力、又想保留 `IArena` 接口：`TChunkedArena`
- 需要预留大块虚拟地址空间、前后双向 bump、手工控制 `Reset` / `ResetHard`：`TVirtualArena`
- 需要把 `TVirtualArena` 接到 `IAllocator` consumer 上：`TVirtualArenaAllocator` / `TFastArenaAllocator`
- 需要每线程零锁热路径：`TThreadArenaManager` + `TThreadArena`
