# nextpas.core.mem 代码契约

**模块路径**：`core/src/nextpas.core.mem*.pas`（77 个源文件；以 `core/src/nextpas.core.mem*.pas` glob 为准）
**层级**：仓库 L0；mem 内部分层见 ARCHITECTURE（M0–M3）
**最后更新**：2026-08-23
**版本**：1.9
**堆后端**：`System.*` 堆原语仅允许在 `nextpas.core.system.heap`；mem 使用 `NpSystem*`（见 [HEAP-BACKEND-OWNER.md](HEAP-BACKEND-OWNER.md)）

**关联冻结策略**：[ERROR-POLICY.md](ERROR-POLICY.md)（nil vs raise）
**默认双轨**：[README.md](README.md) — 热路径 `DefaultHeap` / 插件面 `DefaultAllocator`

---

## 0. 默认双轨（契约级）

| API | 后端 | 契约角色 |
|-----|------|----------|
| `DefaultHeap` / 过程式 `GetMem`·`FreeMem`·`AllocMem`·`ReallocMem` | `TGrowingAllocator` | **热路径默认堆** |
| `DefaultAllocator: IAllocator` | Growing IAllocator 根 ± `NEXTPAS_MEM_DEBUG` | **注入/诊断面**，非热路径；**同进程堆** |
| `GetRtlAllocator` | `TRtlAllocator` | 显式 RTL 后端 / bootstrap |

- Growing 原生 free：`FreeMem(ptr, size)`；单参 `FreeMem(ptr)` 为兼容路径（span 扫描；非 size-class 块可回落 `NpSystemFreeMem`）。
- 过程式 `TryBlockSize(ptr, out size)`：查询 `DefaultHeap` 是否拥有该 size-class 块；True 时 `size` 为 size-class 容量（≥ 原请求）。nil / huge / 外源指针 → False。
- **同堆互释（S5）**：`DefaultHeap` 与未包装 `DefaultAllocator`（`GetGrowingIAllocator`）分配的 size-class 块可互相释放；DEBUG wrap 链上的块必须经同一 wrap 链释放（除非 HEAP_DEBUG 把过程式也并入链）。`FreeMemOf` 仅在 wrap 关闭时短路 sized DefaultHeap free，避免绕过 tracking。
- 双轨税证据：Scorecard **SC9**（`hot_heap` vs `plugin_ia`）。
- `ResolveAllocator(nil)` → `GetGrowingIAllocator`（非 RTL）。
- `NEXTPAS_MEM_DEBUG` **不得**改变 `DefaultHeap` 语义或性能。

---

## 1. 接口契约

### 1.1 核心接口

#### `IAllocator`（`nextpas.core.mem.intf`）

通用分配器接口，40+ 模块引用。

```pascal
IAllocator = interface
  function GetMem(ASize: SizeUInt): Pointer;
  function AllocMem(ASize: SizeUInt): Pointer;
  function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
  procedure FreeMem(ADst: Pointer);
  function Traits: TAllocatorTraits;
end;
```

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `GetMem(ASize)` | ASize >= 0 | ASize=0→nil；否则返回非 nil 指针或 nil（OOM） | 不抛异常 |
| `AllocMem(ASize)` | ASize >= 0 | ASize=0→nil；否则返回零初始化指针或 nil（OOM） | 不抛异常 |
| `ReallocMem(APtr, ASize)` | APtr 有效或 nil | nil→分配；ASize=0→释放；nil+0→nil；其他→重分配 | 不抛异常 |
| `FreeMem(APtr)` | APtr 有效或 nil | APtr=nil 时无操作（静默返回） | 不抛异常 |
| `Traits` | 无 | 返回分配器能力特征 | 不抛异常 |

**nil/0 契约（全局统一）**：
- `GetMem(0)` / `AllocMem(0)` → 返回 nil
- `FreeMem(nil)` → 静默返回，无操作
- `ReallocMem(nil, Size)` → 等价于 `GetMem(Size)`
- `ReallocMem(Ptr, 0)` → 等价于 `FreeMem(Ptr)`
- `ReallocMem(nil, 0)` → 无操作，返回 nil

注：`STRICT_NULL_FREE` 调试模式下 `FreeMem(nil)` 会抛异常，仅用于检测调用方 bug，不影响 `ReallocMem` 路径。

#### `IArena`（`nextpas.core.mem.arena.intf`）

线性分配器接口。

```pascal
IArena = interface
  function Alloc(ASize: SizeUInt): Pointer;
  function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
  function AllocZeroed(ASize: SizeUInt): Pointer;
  function SaveMark: TArenaMark;
  procedure RestoreToMark(AMark: TArenaMark);
  procedure Reset;
  function UsedSize: SizeUInt;
  function Stats: TArenaStats;
end;
```

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Alloc(ASize)` | ASize > 0 | 返回指针或 nil（容量不足） | 不抛异常 |
| `AllocAligned(ASize, AAlign)` | AAlign 是 2 的幂 | 返回对齐指针或 nil | 不抛异常 |
| `Reset` | 无 | FOffset 归零，已提交页面保留 | 不抛异常 |

### 1.2 核心类型

#### `IAllocator`（`nextpas.core.mem.intf`）

接口定义，所有具体分配器实现此接口。

**公开方法**：
- `GetMem` / `AllocMem` / `ReallocMem` / `FreeMem` — 分配器直接实现
- `Traits` — 返回分配器特征

**实现模式**：
- 所有分配器继承 `TInterfacedObject` 并实现 `IAllocator`
- 热路径方法标记 `inline`，直接调用时零开销
- 通过接口调用时走 vtable（2 次间接跳转）

#### `TAllocatorTraits`（`nextpas.core.mem.intf`）

```pascal
TAllocatorTraits = record
  ZeroInitialized: Boolean;  // AllocMem 是否零初始化
  ThreadSafe: Boolean;       // 是否线程安全
  SupportsRealloc: Boolean;  // ReallocMem 可用；False 时 ReallocMem 会抛 aeReallocNotSupported
end;
```

### 1.3 分配器解析模式

构造函数中 nil→默认分配器使用内联 fallback：

```pascal
// 典型模式（构造函数中）：
if AAllocator <> nil then
  FAllocator := AAllocator
else
  FAllocator := GetRtlAllocator;
// INV-1: FAllocator 永远非 nil
```

`GetRtlAllocator`（`nextpas.core.mem.allocator.rtl`）：返回全局 `TRtlAllocator` 单例。

### 1.4 对齐验证模式

对齐验证使用内联 `IsPowerOfTwo`，不引入独立辅助函数：

```pascal
// Arena 路径（bump allocator，无 header，接受任意 2 的幂对齐）：
if not IsPowerOfTwo(AAlign) then Exit;

// Allocator 路径（over-allocate with pointer-sized header，要求 >= SizeOf(Pointer)）：
if (AAlign = 0) or (AAlign < SizeOf(Pointer)) or not IsPowerOfTwo(AAlign) then
  raise EAllocError.Create(aeAlignmentNotSupported, ...);
```

#### `EOutOfMemory.CreateMsg`（`nextpas.core.mem.error`）

```pascal
constructor EOutOfMemory.CreateMsg(const aMsg: string);
// 前置：无
// 后置：FError := aeOutOfMemory，消息 = aMsg + ': Out of memory'
// 用途：OOM 异常快捷构造
```

---

## 2. 不变量

### 全局不变量

- **[INV-1]** `FAllocator` 字段永远非 nil（构造时通过内联 nil→GetGrowingIAllocator / ResolveAllocator fallback 保证）
- **[INV-2]** 对齐参数必须是 2 的幂（`IsPowerOfTwo` 验证）
- **[INV-3]** `IAllocator` 实现的 `GetMem` 返回 nil 表示 OOM（不抛异常）
- **[INV-4]** `IAllocator` 实现的 `FreeMem(nil)` 必须安全（调用方保证 nil 不传入）

### Arena 不变量

- **[INV-A1]** `TLocalArena.FOffset <= FCapacity`
- **[INV-A2]** `TVirtualArena.FFrontCommittedSize <= FReservedSize`
- **[INV-A3]** `TChunkedArena` 的每个 segment 的 `Used <= Size`

### Pool 不变量

- **[INV-P1]** `TFixedPool.FBlockSize` 是 8 的倍数且 >= SizeOf(Pointer)
- **[INV-P2]** `TFixedPool.FAlignment` 是 2 的幂且 >= MEM_DEFAULT_ALIGN
- **[INV-P3]** `TFixedPool.FBlockSize mod FAlignment = 0`
- **[INV-P4]** `TSlabPool.FAllocator <> nil`（内联 fallback 保证）
- **[INV-P5]** `TPoolAllocator.FBlockSize` 是 8 的倍数

### 安全不变量

- **[INV-S1]** 双重释放检测：`TFixedPool.FIsFree` 位图、`TTrackingAllocator` 记录表
- **[INV-S2]** 越界检测：`TLocalArena` 的 `FOffset > FCapacity` 检查
- **[INV-S3]** 悬垂指针检测：`TTrackingAllocator` 的 `FindRecordIndex` 检查

---

## 3. 错误处理

### 3.1 异常层级

```
Exception
  └── nextpas.core.exception.EInvalidArgument
       └── EAllocError (FError: TAllocError)
            ├── EOutOfMemory (FError = aeOutOfMemory)
            ├── EInvalidLayout (FError = aeInvalidLayout)
            ├── EDoubleFree (FError = aeDoubleFree)
            └── EMemFixedPoolError (FError = aeAlignmentNotSupported)
```

注意：`EOutOfMemory` 同时继承自 `nextpas.core.exception.EOutOfMemory`，保持 catch chain 兼容。

### 3.2 错误码

| 错误码 | 含义 | 使用场景 |
|--------|------|----------|
| `aeNone` | 无效码（禁止使用） | Assert 检查 |
| `aeOutOfMemory` | 内存不足 | GetMem/AllocMem 失败 |
| `aeInvalidLayout` | 布局/大小非法 | 块大小溢出、容量超限 |
| `aeAlignmentNotSupported` | 对齐不支持 | 非 2 的幂、不满足最小对齐 |
| `aeSizeMismatch` | 大小不匹配 | ReallocMem 大小不兼容 |
| `aeInvalidPointer` | 无效指针 | FreeMem 传入非池指针 |
| `aeDoubleFree` | 双重释放 | 重复 FreeMem |
| `aePoolClosed` | 池已关闭 | Destroy 后操作 |
| `aeReallocNotSupported` | 不支持重分配 | 固定大小池的 ReallocMem |
| `aeInternalError` | 内部错误 | 不应发生的逻辑错误 |

### 3.3 Graceful degradation

| 场景 | 策略 |
|------|------|
| GetMem/AllocMem 失败 | 返回 nil，不抛异常 |
| Arena 容量不足 | 返回 nil，不抛异常 |
| 构造时 OOM | 抛 EOutOfMemory |
| 对齐参数非法 | Allocator: raise EAllocError; Arena: 返回 nil |
| 双重释放 | 抛 EDoubleFree（TTrackingAllocator）或 Assert（TFixedPool） |

---

## 4. 线程安全

### 4.1 并发模型

| 类型 | 线程安全 | 机制 | 说明 |
|------|----------|------|------|
| `TRtlAllocator` | ✅ | FPC RTL 保证 | 显式 `GetRtlAllocator`；`DefaultAllocator` 根是 Growing IAllocator |
| `TGrowingIAllocator` | ✅ | Growing 适配 | `DefaultAllocator` / `ResolveAllocator(nil)` 根 |
| `TGrowingAllocator` | ✅ | TLS cache + central lock | 核心分配器 |
| `TTrackingAllocator` | ✅ | 内部 TMemMutex | 测试用 |
| `TFallbackAllocator` | ❌ | 无 | 调用方负责同步 |
| `TPoolAllocator` | ❌ | 无 | 调用方负责同步 |
| `TLocalArena` | ❌ | 无 | 单线程使用 |
| `TVirtualArena` | ❌ | 无 | 单线程使用 |
| `TChunkedArena` | ❌ | 无 | 单线程使用 |
| `TArenaConcurrent` | ✅ | mutex 包装 IArena | 任意 IArena 的线程安全包装 |
| `TSlabPool` | ❌ | 无 | 调用方负责同步 |
| `TSlabPoolConcurrent` | ✅ | 单锁 | TSlabPool 的线程安全包装 |
| `TFixedPool` | ❌ | 无 | 调用方负责同步 |
| `TFixedPoolConcurrent` | ✅ | 单锁 | TFixedPool 的线程安全包装 |

### 4.2 锁策略

- **TGrowingAllocator**：TLS cache（无锁热路径）→ central pool（TMemMutex 冷路径）
- **TArenaConcurrent**：单锁保护所有 IArena 操作
- **TSlabPoolConcurrent**：单锁保护所有 TSlabPool 操作
- **TTrackingAllocator**：TMemMutex 保护记录表

### 4.3 Thread-exit cleanup

- **TGrowingAllocator**：UNIX 用 pthread_key_create destructor，Windows 用 FlsAlloc callback
- 线程退出时 flush TLS cache 回 central pool，防止泄漏

---

## 5. 内存管理

### 5.1 所有权模型

```
分配器（IAllocator 实现）
  ├── 拥有：内部 buffer、pool、segment
  ├── 调用方拥有：GetMem/AllocMem 返回的内存块
  └── 调用方负责：FreeMem 释放

Arena（IArena 实现）
  ├── 拥有：底层 buffer / segment
  ├── 调用方拥有：Alloc 返回的内存块
  └── 调用方不释放：Arena Reset/Destroy 统一回收
```

### 5.2 生命周期

```
IAllocator 实现：
  Create → [GetMem/FreeMem 循环] → Destroy
    └── FAllocator 通过内联 nil→ResolveAllocator/GetGrowingIAllocator fallback 绑定，生命周期跟随调用方

IArena 实现：
  Create → [Alloc 循环] → Reset → [Alloc 循环] → Destroy
    └── Reset 重置 offset，不释放底层 buffer
    └── Destroy 释放所有 buffer
```

### 5.3 Leak-free 保证

- **heaptrc 测试**：测试套件经 `tests/common.mk` 默认以 `-gh`（heaptrc）
  fail-closed 门禁运行，报告未释放内存；唯一文档化例外
  `test_boundary_cases`（其 RTL 尺寸边界探测与 heaptrc 的块簿记在
  SizeUInt 上回绕冲突，见该套件 Makefile 注释）
- **异常路径**：构造函数中的异常不会泄漏已分配资源（try/except/finally）
- **Destroy 完整性**：所有 `Destroy` 释放 `Create` 分配的所有资源
- **内联 fallback 保证**：`FAllocator` 永远非 nil，避免 nil 解引用泄漏

---

## 6. 测试覆盖

### 6.1 测试清单

共 113 个测试目录（含 3 个 compile-gate；2026-08-23 同步补登 test_cross_thread_free /
test_mt_fuzz）。完整列表：

```
test_aligned test_aligned_allocator test_alignment_guarantee test_allocator_crt
test_allocator_foundation test_allocator_mimalloc test_arena test_arena_chunked
test_arena_class test_arena_compiler test_arena_prop test_arena_stress test_base
test_batch test_batch_allocator test_blockpool test_boundary_cases test_bounded
test_bounded_allocator test_budget test_callback test_callback_allocator
test_central test_composition test_concurrent test_concurrent_wrappers
test_contract_matrix test_contracts test_counting test_cross_thread_free
test_crt test_crt_allocator
test_debug test_debug_alloc test_debug_allocator test_debug_wrap
test_default_allocator test_double_free test_error test_fail test_fail_allocator
test_fallback test_fallback_allocator test_fixed_slab test_foundation
test_fragmentation test_fuzz test_get_mem_stats test_growing
test_growing_allocator test_growing_block_pool test_guard
test_heap_safety_profile test_hotswap test_l0_dependency_boundaries
test_leak_check_allocator test_leak_report test_logging test_mapped_slab_pool
test_mem test_mem_cross_os_compile_gate test_memory_map_allocator
test_memory_map_compile_gate test_mem_secure
test_mem_secure_windows_compile_gate test_mem_stats test_mem_utils test_mimalloc
test_mmap_allocator test_mt_fuzz test_mutex test_oom test_oom_edge test_platform_virtual
test_pool test_pool_allocator test_pool_edge test_realloc_edge test_ring_buffer
test_rtl test_rwlock test_sampling test_sampling_allocator test_scavenger
test_scoped test_scoped_allocator test_sentinel test_sentinel_allocator
test_sharded_pools test_shared_memory test_shuffle test_sizeclass
test_sizeclass_pool test_slab_pool test_slab_thread_safety test_soak test_span
test_stability test_stack_guard test_stack_pool test_stats test_stats_alloc
test_stats_allocator test_stdlib_integration test_thread_arena test_thread_safe
test_thread_safe_allocator test_threadsafe_concurrent test_tracking
test_tracking_allocator test_usability_guardrails test_zeroed
test_zeroed_allocator
```

### 6.2 必须覆盖的场景

| 场景 | 测试文件 | 状态 |
|------|----------|------|
| 正常分配/释放 | test_mem, test_pool, test_arena | ✅ |
| OOM 降级 | test_oom, test_fallback_allocator | ✅ |
| 对齐验证 | test_arena, test_pool_allocator, test_contracts | ✅ |
| 双重释放检测 | test_tracking_allocator, test_contracts | ✅ |
| 线程安全 | test_concurrent, test_concurrent_wrappers, test_thread_arena, test_thread_safe | ✅ |
| 边界条件（0 大小、最大大小） | test_contracts, test_stability | ✅ |
| 内存泄漏检测 | test_stability（heaptrc） | ✅ |
| Arena Reset/Mark | test_arena, test_arena_chunked | ✅ |
| Pool 扩容 | test_growing, test_growing_block_pool, test_growing_allocator | ✅ |
| SizeClass 路由 | test_sizeclass, test_sizeclass_pool | ✅ |
| Slab 分配 | test_slab_pool, test_sharded_pools | ✅ |
| Ring Buffer 循环 | test_ring_buffer | ✅ |
| L0 依赖边界 | test_l0_dependency_boundaries | ✅ |
| 分片 | test_sharded_pools | ✅ |
| 碎片化 | test_fragmentation | ✅ |
| Central 分配器 | test_central | ✅ |
| 段回收 (TrimIdleSegments) | test_sharded_pools | ✅ |
| 并发压力测试 | test_sharded_pools (16T x 500 iter) | ✅ |

### 6.3 覆盖率目标

- [x] 公开 API：100% 调用覆盖
- [x] 错误路径：100% 触发覆盖
- [x] 边界条件：核心场景覆盖
- [x] 内存泄漏：heaptrc 0 unfreed

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
| 2026-07-01 | 1.1 | 修正：移除不存在的辅助函数引用、修正测试矩阵匹配实际代码 | Claude |
| 2026-07-01 | 1.2 | 同步 main：57 源文件 + 39 测试套件 | Claude |
| 2026-07-03 | 1.3 | 可用性审计修复：IAllocator 定义同步、nil/0 契约文档化、TAllocatorTraits 精简、IArenaCapacity 扩展接口 | Claude |
| 2026-07-06 | 1.4 | 测试矩阵同步：44 suites / 639 tests，反映实际测试状态 | Claude |
| 2026-07-08 | 1.5 | 演化路线图完成：106 源文件 / 58 测试目录 / 688 测试，新增 IBatchAllocator 接口 | Claude |
| 2026-07-12 | 1.6 | 契约门禁修复：IAllocator 精简为 5 方法、IArena 移除 RemainingSize、测试清单同步 143 目录、源文件数 105 | Claude |
| 2026-08-23 | 1.9 | 门禁对账同步：源文件精确计数 77（glob 口径）、测试目录 113（补声明 test_cross_thread_free ← 2e5b63742 / test_mt_fuzz ← 08bda5710）；mem-contract-check C2/C6 警告清零 | Grok |
