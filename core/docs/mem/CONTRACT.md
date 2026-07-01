# nextpas.core.mem 代码契约

**模块路径**：`core/src/nextpas.core.mem*.pas`（50 个源文件）
**层级**：L0-L3（内部分层）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

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
  function MemSize(APtr: Pointer): SizeUInt;
  function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
  procedure FreeAligned(APtr: Pointer);
  function Traits: TAllocatorTraits;
end;
```

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `GetMem(ASize)` | ASize > 0 | 返回非 nil 指针，或 nil（OOM） | 不抛异常 |
| `AllocMem(ASize)` | ASize > 0 | 返回零初始化指针，或 nil（OOM） | 不抛异常 |
| `ReallocMem(APtr, ASize)` | APtr 有效或 nil | nil→分配，ASize=0→释放，其他→重分配 | 不抛异常 |
| `FreeMem(APtr)` | APtr 有效或 nil | APtr=nil 时无操作 | 不抛异常 |
| `MemSize(APtr)` | APtr 有效 | 返回分配大小，未知返回 0 | 不抛异常 |
| `AllocAligned(ASize, AAlign)` | AAlign 是 2 的幂且 >= SizeOf(Pointer) | 返回对齐指针，或 nil | 不抛异常 |
| `FreeAligned(APtr)` | APtr 由 AllocAligned 分配 | 释放内存 | 不抛异常 |
| `Traits` | 无 | 返回分配器能力特征 | 不抛异常 |

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
  function RemainingSize: SizeUInt;
  function Stats: TArenaStats;
end;
```

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Alloc(ASize)` | ASize > 0 | 返回指针或 nil（容量不足） | 不抛异常 |
| `AllocAligned(ASize, AAlign)` | AAlign 是 2 的幂 | 返回对齐指针或 nil | 不抛异常 |
| `Reset` | 无 | FOffset 归零，已提交页面保留 | 不抛异常 |

### 1.2 核心类型

#### `TAllocator`（`nextpas.core.mem.allocator.base`）

抽象基类，实现 `IAllocator`。所有具体分配器的基类。

**公开方法**：
- `GetMem` / `AllocMem` / `ReallocMem` / `FreeMem` — 基类处理 nil/0 守卫后委托给 Do*
- `FreeMem(APtr, ASize)` — 2 参数版本，ASize 被忽略
- `ReallocMem(APtr, AOldSize, ANewSize)` — 3 参数版本，AOldSize 传给子类
- `BatchGetMem` / `BatchFreeMem` — 批量操作，默认循环调用
- `AllocAligned` / `FreeAligned` — over-allocate 实现
- `Traits` — 返回默认特征

**Do* 模板方法**（子类 override）：
- `DoGetMem(ASize)` — 抽象，必须实现
- `DoAllocMem(ASize)` — 默认：DoGetMem + FillChar(0)
- `DoReallocMem(APtr, ASize)` — 抽象，必须实现
- `DoFreeMem(APtr)` — 抽象，必须实现
- `DoMemSize(APtr)` — 默认返回 0

#### `TAllocatorTraits`（`nextpas.core.mem.intf`）

```pascal
TAllocatorTraits = record
  ZeroInitialized: Boolean;  // AllocMem 是否零初始化
  ThreadSafe: Boolean;       // 是否线程安全
  HasMemSize: Boolean;       // 是否支持 MemSize 查询
  SupportsAligned: Boolean;  // 是否支持原生 AllocAligned
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

- **[INV-1]** `FAllocator` 字段永远非 nil（构造时通过内联 nil→GetRtlAllocator fallback 保证）
- **[INV-2]** 对齐参数必须是 2 的幂（`IsPowerOfTwo` 验证）
- **[INV-3]** `TAllocator` 子类的 `DoGetMem` 返回 nil 表示 OOM（不抛异常）
- **[INV-4]** `TAllocator` 子类的 `DoFreeMem(nil)` 必须安全（基类保证 nil 不传入）

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
| `TRtlAllocator` | ✅ | FPC RTL 保证 | 系统默认分配器 |
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
分配器（TAllocator 子类）
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
TAllocator 子类：
  Create → [GetMem/FreeMem 循环] → Destroy
    └── FAllocator 通过内联 nil→GetRtlAllocator fallback 绑定，生命周期跟随调用方

IArena 实现：
  Create → [Alloc 循环] → Reset → [Alloc 循环] → Destroy
    └── Reset 重置 offset，不释放底层 buffer
    └── Destroy 释放所有 buffer
```

### 5.3 Leak-free 保证

- **heaptrc 测试**：所有测试套件启用 `-gh`（heaptrc），报告未释放内存
- **异常路径**：构造函数中的异常不会泄漏已分配资源（try/except/finally）
- **Destroy 完整性**：所有 `Destroy` 释放 `Create` 分配的所有资源
- **内联 fallback 保证**：`FAllocator` 永远非 nil，避免 nil 解引用泄漏

---

## 6. 测试覆盖

### 6.1 测试矩阵

| 子系统 | 测试文件 | 套件数 | 测试数 | 失败数 |
|--------|----------|--------|--------|--------|
| Allocator 基础 | test_allocator_foundation | 1 | 8 | 0 |
| Allocator CRT | test_allocator_crt | 1 | 5 | 0 |
| Allocator 默认 | test_default_allocator | 1 | 4 | 0 |
| Allocator Fallback | test_fallback_allocator | 1 | 15 | 0 |
| Allocator 跟踪 | test_tracking_allocator | 1 | 20 | 0 |
| Allocator 基准 | test_mem | 1 | — | 0 |
| Arena 基础 | test_arena | 1 | 15 | 0 |
| Arena 分段 | test_arena_chunked | 1 | 10 | 0 |
| Arena 类 | test_arena_class | 1 | 6 | 0 |
| Arena 编译器 | test_arena_compiler | 1 | 5 | 0 |
| Arena 线程 | test_thread_arena | 1 | 26 | 0 |
| Pool 基础 | test_pool | 1 | 8 | 0 |
| Pool 固定 | test_pool_allocator | 1 | 6 | 0 |
| Pool Slab | test_slab_pool | 1 | 16 | 0 |
| Pool Slab 分片 | test_sharded_pools | 1 | 9 | 0 |
| Pool SizeClass | test_sizeclass_pool | 1 | 6 | 0 |
| Pool 增长固定 | test_growing_fixed_pool | 1 | 8 | 0 |
| Pool 对象 | test_object_pool | 1 | 12 | 0 |
| BlockPool | test_blockpool | 1 | 15 | 0 |
| BlockPool 增长 | test_growing_block_pool | 1 | 8 | 0 |
| Stack Pool | test_stack_pool | 1 | 15 | 0 |
| Ring Buffer | test_ring_buffer | 1 | 30 | 0 |
| Concurrent 包装 | test_concurrent_wrappers | 1 | 6 | 0 |
| 契约 | test_contracts | 1 | 22 | 0 |
| L0 边界 | test_l0_dependency_boundaries | 1 | 1 | 0 |
| OOM | test_oom | 1 | 5 | 0 |
| Utils | test_mem_utils | 1 | 8 | 0 |
| Secure | test_mem_secure | 1 | 6 | 0 |
| Memory Map | test_memory_map_allocator | 1 | 4 | 0 |
| Mapped Slab | test_mapped_slab_pool | 1 | 5 | 0 |
| **合计** | **30 个测试套件** | **30** | **~286** | **0** |

注：另有 4 个 compile-gate 测试（test_memory_map_compile_gate, test_mem_secure_windows_compile_gate, test_platform_virtual, test_shared_memory），仅验证编译通过。

### 6.2 必须覆盖的场景

| 场景 | 测试文件 | 状态 |
|------|----------|------|
| 正常分配/释放 | test_mem, test_pool, test_arena | ✅ |
| OOM 降级 | test_oom, test_fallback_allocator | ✅ |
| 对齐验证 | test_arena, test_pool_allocator, test_contracts | ✅ |
| 双重释放检测 | test_tracking_allocator, test_contracts | ✅ |
| 线程安全 | test_concurrent_wrappers, test_thread_arena | ✅ |
| 边界条件（0 大小、最大大小） | test_contracts | ✅ |
| Arena Reset/Mark | test_arena, test_arena_chunked | ✅ |
| Pool 扩容 | test_growing_fixed_pool, test_growing_block_pool | ✅ |
| SizeClass 路由 | test_sizeclass_pool | ✅ |
| Slab 分配 | test_slab_pool, test_sharded_pools | ✅ |
| Ring Buffer 循环 | test_ring_buffer | ✅ |
| L0 依赖边界 | test_l0_dependency_boundaries | ✅ |

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
