# mem 模块全面审查报告

> 扫描时间：2026-06-21
> 分支：feat/arena-allocator
> 范围：core/src/nextpas.core.mem*.pas (51 文件)
> 来源：人工扫描 + 3 个专项 agent（架构/性能/安全）

---

## 一、架构与依赖

### A-01 ⚠️ Breaking Changes: 11 个 main 上文件被删除

**P1 | 文件：11 个**

feat-arena-allocator 删除了 main 上存在的 11 个文件，其中 4 个有外部引用（测试/契约）。

| 被删文件 | main 外部引用 | 影响 |
|----------|-------------|------|
| `mem.adapters.pas` | 0 | 无 |
| `mem.aligned.pas` | 1 (test_contracts) | 测试需更新 |
| `mem.allocator.instrumentation.pas` | 0 | 无 |
| `mem.allocator.numa.pas` | 1 (test_numa_allocator) | 测试已删 |
| `mem.interfaces.pas` | 0 | 无 |
| `mem.mapped_ring_buffer.pas` | 4 (2 tests + 2 contracts) | 测试/契约需更新 |
| `mem.mapped_ring_buffer.sharded.pas` | 3 (1 test + 2 contracts) | 测试/契约需更新 |
| `mem.mem_pool.pas` | 0 | 无 |
| `mem.pool.adapter.pas` | 0 | 无 |
| `mem.stack_scope_helpers.pas` | 0 | 无 |
| `mem.stats.pas` | 0 | 无 |

**建议**：合并 main 时需同步更新 test_contracts、architecture_contract_registry.json、check_core_architecture_contracts.sh。

---

### A-02 ⚠️ 门面导出严重不完整

**P1 | 文件：core/src/nextpas.core.mem.pas**

门面仅导出 16 个类型别名，但子模块中存在约 100+ 公开类型。
- **已 uses 但未 re-export** (19 个类型): `TAllocatorTraits`, `TAllocError`, `EAllocError`, `EOutOfMemory`, `IBlockPool`, `IBlockPoolBatch`, `TBlockPool`, `IPool`, `IMemoryPool`, `IFixedSlabPool` 等
- **完全未引用的子模块** (37 个): 整个 pool 子系统、blockpool 子系统、具体分配器、并发原语、utility

**建议**：明确门面设计策略——只暴露核心 Arena + 默认分配器，在门面头部注释中说明"高级子模块需直接 uses 对应单元"。

---

### A-03 ⚠️ 双重 mimalloc 实现

**P1 | 文件：mem.mimalloc.pas + mem.allocator.mimalloc.pas**

- `mem.mimalloc.pas`：简单版，直接 FFI 绑定，单例模式，**全仓库零引用**（死代码）
- `mem.allocator.mimalloc.pas`：完整版，动态加载/静态链接/路径搜索，被 facade 引用
- `mem.mimalloc.ffi.pas` 也只被旧版引用，同样是孤立的

**建议**：删除 `mem.mimalloc.pas` 和 `mem.mimalloc.ffi.pas`。

---

### A-04 ⚠️ L2 层依赖违规 — mimalloc 引用跨层模块

**P1 | 文件：core/src/nextpas.core.mem.allocator.mimalloc.pas**

`mem` 模块属于 L1，但 `allocator.mimalloc` 引用了：
- `nextpas.core.os.env` (L1，间接依赖 L2 text)
- `nextpas.core.path` (**死导入**，从未调用)
- `nextpas.core.errors` (L0，OK)

**建议**：移除 `nextpas.core.path` 死导入。`os.env` 可考虑改用 FPC `SysUtils.GetEnvironmentVariable`。

---

### A-05 ⚠️ pool.memory_pool.pas 孤立接口

**P2 | 文件：core/src/nextpas.core.mem.pool.memory_pool.pas (28 行)**

`IMemoryPool` 接口无任何实现，无外部引用。

**建议**：删除或标记 `deprecated`。

---

### A-06 ⚠️ ring_buffer.pas / stack_pool.pas 无外部引用

**P2 | 文件：ring_buffer.pas (726 行), stack_pool.pas (944 行)**

两个大文件零外部引用，仅内部使用。

**建议**：确认是否为死代码。如有用处，应暴露公共 API。

---

### A-07 ⚠️ TLocalBlockPool 与 TBlockPool 职责重叠

**P2 | 文件：pool.pas vs blockpool.pas**

两个类实现几乎完全相同的功能（固定大小块池、位图、freelist），但 `TLocalBlockPool` 不实现 `IBlockPool` 接口。门面只导出 `TLocalBlockPool`。

**建议**：评估是否可以统一为一个实现。

---

### A-08 ⚠️ manager.* 与 allocator.* 职责重叠

**P2 | 文件：mem.manager.crt/rtl/mimalloc vs mem.allocator.crt/rtl/mimalloc**

`manager.*` 是 FPC MemoryManager 安装器，`allocator.*` 是 IAllocator 实现。`manager.*` 零外部引用。

**建议**：重命名为 `mem.fpc_mm.*` 或标记 `deprecated`。

---

### A-09 ⚠️ TArenaMarker vs TArenaMark 名称混淆

**P2 | 文件：mem.base.pas:25 vs mem.arena.base.pas:12**

- `TArenaMarker = SizeUInt`（简单别名，全仓库零引用）
- `TArenaMark = record`（含 FrontOffset/BackOffset/TotalUsed，广泛使用）

**建议**：删除 `TArenaMarker`（死类型）。

---

### A-10 ⚠️ IPool vs IBlockPool 接口签名冲突

**P2 | 文件：pool.base.pas vs blockpool.pas**

- `IPool.Acquire(out aPtr: Pointer): Boolean` — out 参数 + Boolean
- `IBlockPool.Acquire: Pointer` — 直接返回 Pointer

两种"获取"操作用完全不同的签名模式。

**建议**：在架构文档中说明设计区分理由。

---

### A-11 ⚠️ mem 模块零编译器引用

**P2 | 描述**

整个 `compiler/` 目录中没有任何文件引用 `nextpas.core.mem.*`。编译器必须使用 `nextpas.core.*`，但当前完全未使用 mem 模块。

**建议**：确认编译器的内存管理策略。

---

### A-12 ⚠️ memory_map / mapped_slab_pool 属于 io 模块

**P3 | 文件：mem.memory_map.pas, mem.mapped_slab_pool.pas**

被 `io.mapped` 模块引用，不属于 mem 分配器范畴。

**建议**：长期迁移到 `io.mapped` 模块。当前保留不动。

---

### A-13 ⚠️ SysUtils 直接依赖

**P3 | 文件：allocator.mimalloc, allocator.tracking, pool.fixed**

3 个文件在 implementation uses 中直接引用 FPC SysUtils。根据 R6 迁移策略应逐步替换。

**建议**：记录到技术债清单。

---

### A-14 ⚠️ mutex/rwlock 极薄包装

**P3 | 文件：mem.mutex.pas, mem.rwlock.pas**

几乎是 `platform.sync` 的 1:1 包装。`TMemMutex` 仅 1 个外部引用，`TMemRwLock` 零外部引用。

**建议**：考虑直接使用 `TPlatformMutex`/`TPlatformRwLock`。

---

### A-15 ⚠️ 文件名下划线 vs 点号不一致

**P3 | 8 个文件使用下划线**

`allocator.leak_check`, `mapped_slab_pool`, `memory_map`, `pool.fixed_slab`, `pool.memory_pool`, `pool.object_pool`, `ring_buffer`, `stack_pool`

**建议**：低优先级，可留待批量治理。

---

## 二、API 设计

### B-01 ⚠️ 错误处理不一致

**P1 | 文件：所有 Arena 模块**

构造失败抛异常，分配失败返回 nil。有意设计但缺少文档说明。

**建议**：在 IArena 接口文档中明确约定。

---

### B-02 ⚠️ AllocUnsafe 不更新统计 + 不保证对齐

**P2 | 文件：arena.virtual.pas:330**

- 不更新 `FTotalUsed`/`FPeakUsed`/`FAllocCount`
- 不保证对齐（如果前一次 aSize 不是 FAlignment 倍数）

**建议**：文档明确说明安全使用前提：aSize 必须是 FAlignment 倍数，统计不保证准确。

---

### B-03 ⚠️ TVirtualArena.Reset 不释放大对象

**P1 | 文件：arena.virtual.pas:457-468**

`Reset` 设置 `FTotalUsed := FLargeUsed`，但不释放 FLargeBlocks 中的 mmap 映射。大对象只有 `Release` 才会清理。`SaveMark/RestoreToMark` 同样不管理大对象生命周期。

**建议**：在 API 中明确标注"大对象不受 Reset 影响，需调用 Release 释放"。

---

### B-04 ⚠️ TVirtualArena.Reset vs ResetHard 语义差异

**P2 | 文件：arena.virtual.pas**

IArena 只定义 `Reset`，没有 `ResetHard`。三种 Arena 的 Reset 语义不同。

**建议**：在 IArena 文档中说明差异。

---

### B-05 ⚠️ IAllocator 与 IArena 方法命名不一致

**P2 | 文件：mem.intf.pas, mem.arena.intf.pas**

两种接口用不同动词表示相同概念（GetMem vs Alloc, AllocMem vs AllocZeroed）。

**建议**：文档说明定位差异。

---

### B-06 ⚠️ TChunkedArena 缺少 AllocUnsafe

**P2 | 文件：arena.chunked.pas**

TVirtualArena 有 AllocUnsafe，但 TChunkedArena 和 TLocalArena 没有。无法统一调用。

**建议**：添加 AllocUnsafe 或在文档中说明使用策略。

---

### B-07 ⚠️ TVirtualArena 无 IArena 实现

**P2 | 文件：arena.virtual.pas**

record 类型不实现接口，无法用 IArena 统一操作所有 Arena。

**建议**：文档说明有意设计（record 避免 vtable 开销）。

---

### B-08 ⚠️ 接口参数命名不一致

**P3 | 多个文件**

- IArena 用大写 `A` 前缀，其他接口用小写 `a`
- `AllocAligned` 参数名 `AAlign` vs `aAlignment`
- `FreeMem(aDst)` vs `FreeAligned(aPtr)` 参数名混用

**建议**：统一为小写 `a` 前缀 + 完整参数名。

---

## 三、安全（P0）

### S-01 🔴 AllocFast 无边界检查，可越界写入

**P0 | 文件：arena.local.pas:154-171**

`AllocFast` 和 `AllocAlignedFast` 完全跳过所有检查。如果 Arena 容量已满或 FBacking 为 nil：
- 对 nil 指针做偏移运算并返回非法地址
- 越界写入后备内存后方
- 未定义行为/段错误

**建议**：至少在 DEBUG 模式下加入 Assert。Release 模式保留零开销。

---

### S-02 🔴 AllocAlignedFast AAlign=0 掩码溢出

**P0 | 文件：arena.local.pas:160-171`

`AllocAlignedFast` 计算 `LMask := AAlign - 1`。AAlign=0 时 LMask = High(SizeUInt)，后续计算产生错误结果，`Inc(FOffset)` 可能溢出导致 FOffset 指向非法位置。

**建议**：添加 `Assert(AAlign > 0)` 或文档要求 AAlign >= 1。

---

## 四、竞态条件

### R-01 ⚠️ TArenaConcurrent 读方法无锁

**P1 | 文件：arena.concurrent.pas:161-169**

`UsedSize` 和 `RemainingSize` 无锁读取，但所有写入路径持锁。与 `Stats`（有锁）形成不一致的锁策略。

**建议**：加锁或文档化为"近似值"。

---

### R-02 ⚠️ TBlockPoolConcurrent 读方法无锁

**P2 | 文件：blockpool.concurrent.pas:171-189`

`Available` 和 `InUse` 涉及热路径中频繁修改的字段，高并发下可能返回过期值。

**建议**：加读锁或标注为"近似值"。

---

### R-03 ⚠️ TShardedBlockPool Reset 与 Acquire 潜在死锁

**P2 | 文件：blockpool.sharded.pas:1219-1260**

Reset 先锁所有 shard 再锁路由写锁，Acquire 先锁单个 shard 再调含路由写锁的函数。两者锁顺序一致但 Reset 持有多个 shard 锁时可能形成循环等待。

**建议**：Reset 应先获取路由写锁，再获取 shard 锁。

---

### R-04 ⚠️ TMemMutex.Init 不是线程安全的

**P2 | 文件：mem.mutex.pas:32-43`

`Init` 检查 `FInitialized` 然后初始化——两个线程可能同时看到 False 然后都初始化。TMemMutex 是 record 类型，无构造函数保证。

**建议**：文档说明 Init 必须在单线程上下文中调用。

---

## 五、内存安全

### M-01 ⚠️ TVirtualArena.SaveMark/RestoreToMark 不管理大对象

**P1 | 文件：arena.virtual.pas:437-455`

SaveMark 后分配的大对象在 RestoreToMark 时不会被释放，导致 mmap 泄漏。

**建议**：在 RestoreToMark 中释放超出标记的大对象，或文档明确说明。

---

### M-02 ⚠️ AllocNoPointer 向下减法可能下溢

**P2 | 文件：arena.virtual.pas:328-372`

`LNewBack := PtrUInt(FBackPtr) - PtrUInt(aSize)`。当 aSize > FBackPtr - FBackBase 时，LNewBack 会 wrap around 成巨大地址，可能绕过 `LAligned < FFrontPtr` 检查。

**建议**：在减法前添加 `if aSize > PtrUInt(FBackPtr) - PtrUInt(FBackBase) then Exit`。

---

### M-03 ⚠️ TShardedBlockPool thread cache 内存泄漏

**P2 | 文件：blockpool.sharded.pas:850-908`

`GetThreadCacheNode` 通过 GetMem 分配节点链入 threadvar 链表。线程退出时 threadvar 自动清零，节点永不释放。当前 FThreadCacheCapacity=0 禁用了此路径，但代码仍存在。

**建议**：彻底移除 thread cache 分配路径直到有清理机制。

---

### M-04 ⚠️ TSlabPool.PageKeyOf 无条件访问 FSegments[0]

**P2 | 文件：pool.slab.pas:745-748`

直接访问 `TFixedSlabPool(FSegments[0]).PageShift`，不检查 FSegments 是否为空。

**建议**：入口检查 `Length(FSegments) > 0` 或存储 FPageShift 独立字段。

---

## 六、测试覆盖

### T-01 ⚠️ 8 个源文件无对应测试

**P1 | 多个文件**

allocator.callback, allocator.crt, allocator.foundation, manager.mimalloc, mimalloc.ffi, mutex, rwlock, pool.memory_pool

**建议**：优先补充 allocator.callback、mutex、rwlock 测试。

---

### T-02 ⚠️ ResetHard / AllocUnsafe 无测试

**P2 | 文件：test_arena_compiler/**

新增的 ResetHard 和 AllocUnsafe 方法无任何测试。

**建议**：添加基本测试覆盖。

---

### T-03 ⚠️ TBlockPool 缺少高竞争并发测试

**P2 | 文件：test_concurrent_wrappers/**

当前只用 8 线程 x 32 迭代。无压力测试。

**建议**：添加 32+ 线程 x 10000+ 迭代测试。

---

### T-04 ⚠️ Arena OOM 测试不足

**P3 | 文件：test_oom/**

未覆盖 VirtualArena 虚拟地址空间耗尽、ChunkedArena OOM、大对象 mmap 失败。

---

## 七、性能

### P-01 ⚠️ TChunkedArena.FSegments 频繁 SetLength

**P2 | 文件：arena.chunked.pas:288-294`

AddSegment 每次增长 FSegments 只加 1，频繁触发 realloc。

**建议**：采用几何增长策略（`SetLength(FSegments, Max(LIdx+1, Length*2))`）。

---

### P-02 ⚠️ TChunkedArena.Stats.AllocCount 截断 QWord 到 SizeUInt

**P2 | 文件：arena.chunked.pas:684`

`FTotalAllocs` 是 QWord，但 Stats 返回 `SizeUInt(FTotalAllocs)`。32 位平台上会截断。

**建议**：TArenaStats.AllocCount 改为 QWord 或饱和处理。

---

### P-03 ⚠️ TLocalArena.AllocAligned 每次调用 IsPowerOfTwo

**P2 | 文件：arena.local.pas:119`

**建议**：添加 FAlignmentMask 缓存字段。

---

### P-04 ⚠️ TRingBuffer mod 运算未使用快速路径

**P3 | 文件：ring_buffer.pas:374,429,444,604,664`

批量方法中使用 `mod FCapacity`，未复用 `GetNextIndex` 的 2 幂位与优化。

---

### P-05 ⚠️ TVirtualArena.CommitFrontRegion 非 inline

**P3 | 文件：arena.virtual.pas:188`

record 方法无法 inline。热路径已优化。记录为已知限制。

---

## 八、代码质量

### Q-01 ⚠️ COMMIT_CHUNK_SIZE 可变常量

**P2 | 文件：arena.virtual.pas:190`

typed constant（可变），应改为真正的 const。

---

### Q-02 ⚠️ 大对象 FLargeBlocks 数组无上限

**P2 | 文件：arena.virtual.pas:43`

每次翻倍扩展，无上限。

---

### Q-03 ⚠️ TRingBuffer.Resize 中 mod FCapacity 潜在除零

**P2 | 文件：ring_buffer.pas:529`

极端情况下 FCapacity 可能为 0。

---

### Q-04 ⚠️ AllocUnsafe 未对齐

**P2 | 文件：arena.virtual.pas:428-435`

直接 bump pointer，不保证对齐。ARM 上可能触发硬件异常。

**建议**：文档说明 aSize 必须是 FAlignment 倍数。

---

### Q-05 ⚠️ mmap 失败时无错误码

**P2 | 文件：arena.virtual.pas:292-293`

大对象 mmap 失败返回 nil，调用方无法区分容量不足还是 syscall 失败。

---

### Q-06 ⚠️ GArenaInstanceCount/GArenaTotalMapped 无保护

**P3 | 文件：arena.virtual.pas`

调试变量，读取时无保护。

---

### Q-07 ⚠️ TBlockPoolBase 标记废弃但无 deprecated 关键字

**P3 | 文件：blockpool.pas:154`

注释说"已废弃"，但类型声明没有 `deprecated`。

---

## 九、文档

### D-01 ⚠️ ARCHITECTURE.md 过时

**P1 | 文件：core/docs/mem/ARCHITECTURE.md**

未反映最新架构（arena.concurrent、AllocUnsafe、ResetHard、47 文件结构）。

---

### D-02 ⚠️ API.md 可能过时

**P2 | 文件：core/docs/mem/API.md**

---

### D-03 ⚠️ 缺少使用指南

**P3 | 文件：core/docs/mem/README.md**

缺少 Arena 选择指南、IAllocator vs IArena 使用场景、AllocUnsafe 安全前提。

---

## 十、汇总

### 按优先级统计

| 优先级 | 数量 | 关键问题 |
|--------|------|---------|
| **P0** | **2** | AllocFast 越界写入、AllocAlignedFast 掩码溢出 |
| **P1** | **10** | Breaking changes、facade 不完整、mimalloc 重复、大对象生命周期、并发读无锁、测试覆盖 |
| **P2** | **22** | API 一致性、死代码、性能、竞态条件、内存安全 |
| **P3** | **12** | 命名规范、文档、边缘场景 |

### 建议处理顺序

1. **🔴 P0-01/02**：AllocFast/AllocAlignedFast 添加 DEBUG Assert（安全漏洞）
2. **P1-03/04**：删除 mimalloc 死代码 + 移除死导入
3. **P1-01**：记录 breaking changes，准备合并迁移清单
4. **P1-02**：补全 facade 导出 + 添加设计说明注释
5. **P1-03**：VirtualArena 大对象生命周期文档
6. **R-01**：TArenaConcurrent 读方法加锁
7. **P2 类**：按影响面逐个处理
8. **P3 类**：按需处理
