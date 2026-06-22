# mem 模块全面审查报告

> 扫描时间：2026-06-21
> 分支：feat/arena-allocator
> 范围：core/src/nextpas.core.mem*.pas (51 文件)

---

## 一、架构与依赖

### A-01 ⚠️ Breaking Changes: 11 个 main 上文件被删除

**P1 | 文件：11 个 | 描述：**
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

### A-02 ⚠️ Arena facade 不完整

**P1 | 文件：core/src/nextpas.core.mem.arena.pas**

facade 只导出了 `TVirtualArena_Init`/`TVirtualArena_Release`，但没有导出：
- `TLocalArena.Create`/`TLocalArena.Free`（直接用 local.pas）
- `TChunkedArena.Create`/`TChunkedArena.Free`（直接用 chunked.pas）
- `TArenaStats` 的字段说明
- `ARENA_VIRTUAL_RESERVE`/`ARENA_LARGE_THRESHOLD` 等关键常量

**建议**：facade 应 re-export 所有 Arena 子模块的公共常量和工厂方法。

---

### A-03 ⚠️ pool.memory_pool.pas 孤立接口

**P2 | 文件：core/src/nextpas.core.mem.pool.memory_pool.pas (28 行)**

`IMemoryPool` 接口无任何实现，无外部引用。注释中说"历史原因"，但没有任何消费者。

**建议**：删除或标记为 `@deprecated`。

---

### A-04 ⚠️ ring_buffer.pas 无外部引用

**P2 | 文件：core/src/nextpas.core.mem.ring_buffer.pas (726 行)**

零外部引用，仅内部使用。`io.mapped.ring_buffer` 是独立实现，不依赖此文件。

**建议**：确认是否为死代码。如有用处，应暴露公共 API。

---

### A-05 ⚠️ stack_pool.pas 无外部引用

**P2 | 文件：core/src/nextpas.core.mem.stack_pool.pas (944 行)**

零外部引用。大文件但无消费者。

**建议**：确认是否为死代码。

---

### A-06 ⚠️ manager.* 与 allocator.* 职责重叠

**P2 | 文件：mem.manager.crt/rtl/mimalloc vs mem.allocator.crt/rtl/mimalloc**

`manager.*` 是 FPC MemoryManager 安装器（SetMemoryManager），`allocator.*` 是 IAllocator 实现。职责不同但命名容易混淆。`manager.*` 零外部引用。

**建议**：重命名为 `mem.fpc_mm.*` 或标记 `@deprecated`。

---

### A-07 ⚠️ memory_map / mapped_slab_pool 属于 io 模块

**P3 | 文件：mem.memory_map.pas, mem.mapped_slab_pool.pas**

这两个文件被 `io.mapped` 模块引用（`io.mapped.pas`, `io.mapped.ring_buffer.pas`, `io.mapped.slab_pool.pas`）。它们是 io 模块的底层实现，不属于 mem 分配器范畴。

**建议**：长期应迁移到 `io.mapped` 模块。当前保留不动（外部依赖）。

---

## 二、API 设计

### B-01 ⚠️ 错误处理不一致

**P1 | 文件：所有 Arena 模块**

| 操作 | TLocalArena | TChunkedArena | TVirtualArena |
|------|------------|---------------|---------------|
| 构造/Init | EOutOfMemory | EOutOfMemory | EOutOfMemory |
| Alloc | 返回 nil | 返回 nil | 返回 nil |
| AllocAligned | 返回 nil | 返回 nil | 返回 nil |
| Reset | 无异常 | 无异常 | 无异常 |

构造失败抛异常，分配失败返回 nil。这是**有意设计**（分配失败是预期路径，构造失败是致命错误），但缺少文档说明。

**建议**：在 IArena 接口文档中明确约定错误处理策略。

---

### B-02 ⚠️ AllocUnsafe 不更新统计

**P2 | 文件：core/src/nextpas.core.mem.arena.virtual.pas:330**

`AllocUnsafe` 不更新 `FTotalUsed`/`FPeakUsed`/`FAllocCount`。当混合使用 `Alloc` 和 `AllocUnsafe` 时，`Stats` 返回的统计信息不准确。

**建议**：
- 要么文档明确说明 AllocUnsafe 不保证统计准确
- 要么提供 `AllocUnsafeTracked` 变体

---

### B-03 ⚠️ TVirtualArena.Reset vs ResetHard 语义差异

**P2 | 文件：core/src/nextpas.core.mem.arena.virtual.pas**

- `Reset`：保留已 commit 页面（快，Go 策略）
- `ResetHard`：decommit 所有页面（慢，释放物理内存）

但 `TLocalArena.Reset` 和 `TChunkedArena.Reset` 没有 `ResetHard` 等价物。接口 `IArena` 只定义了 `Reset`，没有 `ResetHard`。

**建议**：在 IArena 文档中说明 Reset 语义差异，或在 IArena 中添加 `ResetHard`。

---

### B-04 ⚠️ IAllocator 与 IArena 方法命名不一致

**P2 | 文件：mem.intf.pas, mem.arena.intf.pas**

| IAllocator | IArena |
|------------|--------|
| `GetMem` | `Alloc` |
| `AllocMem` | `AllocZeroed` |
| `FreeMem` | (无，Reset 释放全部) |

两种接口用不同的动词表示相同概念。

**建议**：文档说明两者的定位差异（IAllocator 是通用分配器，IArena 是线性分配器）。

---

### B-05 ⚠️ TChunkedArena 缺少 AllocUnsafe

**P2 | 文件：core/src/nextpas.core.mem.arena.chunked.pas**

`TVirtualArena` 有 `AllocUnsafe`，但 `TChunkedArena` 和 `TLocalArena` 没有。如果要写泛型 Arena 代码，无法统一调用。

**建议**：在 TLocalArena 和 TChunkedArena 上也添加 `AllocUnsafe`，或在 IArena 接口中添加。

---

### B-06 ⚠️ TVirtualArena 无 IArena 实现

**P2 | 文件：core/src/nextpas.core.mem.arena.virtual.pas**

`TVirtualArena` 是 record，不实现 `IArena` 接口。`TLocalArena` 和 `TChunkedArena` 都实现了 `IArena`。这意味着无法用 `IArena` 统一操作所有 Arena。

**建议**：这是有意设计（record 避免 vtable 开销），但需在文档中明确说明使用策略。

---

## 三、测试覆盖

### C-01 ⚠️ 8 个源文件无对应测试

**P1 | 文件：多个**

| 源文件 | 行数 | 测试状态 |
|--------|------|---------|
| `mem.allocator.callback` | ~100 | ❌ 无测试 |
| `mem.allocator.crt` | ~109 | ❌ 无测试 |
| `mem.allocator.foundation` | ~53 | ❌ 无测试 |
| `mem.manager.mimalloc` | ~133 | ❌ 无测试 |
| `mem.mimalloc.ffi` | ~19 | ❌ 无测试 |
| `mem.mutex` | ~76 | ❌ 无测试 |
| `mem.rwlock` | ~100 | ❌ 无测试 |
| `mem.pool.memory_pool` | ~28 | ❌ 无测试（孤立接口） |

**建议**：优先补充 `allocator.callback`、`mutex`、`rwlock` 的测试。其余可标记为 @deprecated 后删除。

---

### C-02 ⚠️ VirtualArena.Reset 测试不覆盖 ResetHard

**P2 | 文件：core/tests/nextpas.core.mem/test_arena_compiler/**

添加了 `ResetHard` 方法但无对应测试。

**建议**：添加 `TestResetHard` 测试，验证 decommit 后重新 commit 的正确性。

---

### C-03 ⚠️ AllocUnsafe 无测试

**P2 | 文件：core/tests/nextpas.core.mem/test_arena_compiler/**

`AllocUnsafe` 无任何测试。虽然它是"unsafe"的，但至少应测试：
- 基本分配返回正确指针
- 连续分配不重叠
- 与 Alloc 混用不冲突

**建议**：添加 AllocUnsafe 基本测试。

---

### C-04 ⚠️ TBlockPool 缺少并发安全测试

**P2 | 文件：core/tests/nextpas.core.mem/test_concurrent_wrappers/**

`TBlockPoolConcurrent` 有并发测试，但测试只用 8 线程 x 32 迭代。没有压力测试（高竞争场景）。

**建议**：添加高竞争测试（32+ 线程 x 10000+ 迭代），验证无死锁和数据损坏。

---

### C-05 ⚠️ Arena OOM 测试不足

**P3 | 文件：core/tests/nextpas.core.mem/test_oom/**

OOM 测试只有 5 个。未覆盖：
- TVirtualArena 虚拟地址空间耗尽
- TChunkedArena 连续分配直到 OOM
- 大对象 mmap 失败

**建议**：补充 VirtualArena 和 ChunkedArena 的 OOM 场景。

---

### C-06 ⚠️ TArenaConfig 只用于 TChunkedArena

**P3 | 文件：core/src/nextpas.core.mem.arena.base.pas, arena.chunked.pas**

`TArenaConfig` 只被 `TChunkedArena` 使用，`TLocalArena` 和 `TVirtualArena` 不使用。配置接口不统一。

**建议**：要么让所有 Arena 支持 TArenaConfig，要么只在 ChunkedArena 内部使用。

---

### C-07 ⚠️ 三种增长策略枚举定义重复

**P3 | 文件：arena.base.pas, pool.fixed.growable.pas, blockpool.growable.pas**

| 文件 | 枚举名 | 值 |
|------|--------|-----|
| arena.base | TArenaGrowthKind | agkGeometric, agkLinear |
| pool.fixed.growable | TGrowthKind | gkGeometric, gkLinear |
| blockpool.growable | TBlockPoolGrowthKind | bpgkGeometric, bpgkLinear |

三个枚举表示相同概念但各自定义。

**建议**：统一到 `mem.base` 或 `mem.arena.base` 中，其他模块 re-export。

---

## 四、性能

### D-01 ⚠️ TLocalArena.Alloc 每次调用 IsPowerOfTwo

**P2 | 文件：core/src/nextpas.core.mem.arena.local.pas:119**

`AllocAligned` 每次调用 `IsPowerOfTwo(AAlign)`，但对齐值通常不变。可以像 TVirtualArena 一样缓存。

**建议**：添加 `FAlignmentMask` 缓存字段。

---

### D-02 ⚠️ TChunkedArena.Alloc 有多层间接调用

**P2 | 文件：core/src/nextpas.core.mem.arena.chunked.pas**

每次 Alloc 调用链：`Alloc → GetAlignPadding → 检查容量 → 可能 AddSegment`。FPC 对 record 方法的 inline 能力有限。

**建议**：考虑添加 `AllocFast` 跳过对齐计算（默认对齐时）。

---

### D-03 ⚠️ IAllocator dispatch 开销可忽略但文档缺失

**P3 | 文件：mem.intf.pas**

实测 interface dispatch 开销 ~0.08 ns/call，占总分配时间 <1%。但缺少文档说明这一设计决策。

**建议**：在 ARCHITECTURE.md 中记录 interface dispatch 开销测量结果和设计理由。

---

### D-04 ⚠️ TVirtualArena.CommitFrontRegion 非 inline

**P3 | 文件：core/src/nextpas.core.mem.arena.virtual.pas:188**

`CommitFrontRegion` 是 record 方法，FPC 无法 inline。热路径已通过内联 commit 检查优化，但首次 commit 仍有函数调用开销。

**建议**：当前优化已足够，记录为已知限制。

---

## 五、代码质量

### E-01 ⚠️ COMMIT_CHUNK_SIZE 可变常量

**P2 | 文件：core/src/nextpas.core.mem.arena.virtual.pas:190**

```pascal
COMMIT_CHUNK_SIZE: SizeUInt = 2 * 1024 * 1024; { 2MB }
```

这是 typed constant（可变），不是真正的常量。如果被意外修改会导致严重问题。

**建议**：改为 `const COMMIT_CHUNK_SIZE = SizeUInt(2 * 1024 * 1024);` 或用 `{$J-}` 确保不可变。

---

### E-02 ⚠️ GArenaInstanceCount/GArenaTotalMapped 无保护

**P3 | 文件：core/src/nextpas.core.mem.arena.virtual.pas**

`{$IFDEF NEXTPAS_ARENA_LEAK_CHECK}` 下的全局变量用 `InterLockedIncrement` 修改，但读取时无保护。

**建议**：标记为仅供调试使用，不保证多线程一致性。

---

### E-03 ⚠️ TChunkedArena.FSegments 动态数组 Reset 时保留首元素

**P3 | 文件：core/src/nextpas.core.mem.arena.chunked.pas:471**

Reset 时 `SetLength(FSegments, 1)` 保留第一个 segment。但如果第一个 segment 很小（如 64KB），后续大分配仍需 AddSegment。

**建议**：考虑 Reset 时清空所有 segment（包括第一个），让下次分配从 cache 中取最合适的。

---

### E-04 ⚠️ 大对象 FLargeBlocks 数组无上限

**P2 | 文件：core/src/nextpas.core.mem.arena.virtual.pas:43**

`FLargeBlocks: array of TPlatformMappedFile` 每次翻倍扩展（4→8→16→...），但无上限。如果分配大量大对象，数组会持续增长。

**建议**：添加 `FLargeCapacity` 常量或让 Reset 释放大对象数组。

---

## 六、文档

### F-01 ⚠️ ARCHITECTURE.md 过时

**P1 | 文件：core/docs/mem/ARCHITECTURE.md**

未反映最新架构：
- 未提到 `arena.concurrent.pas`
- 未提到 `AllocUnsafe`/`ResetHard`
- 未提到 Phase 1+2 架构清理（47 文件）
- 未提到 `arena.types.pas` 已删除

**建议**：更新 ARCHITECTURE.md 反映当前架构。

---

### F-02 ⚠️ API.md 可能过时

**P2 | 文件：core/docs/mem/API.md**

未验证是否反映最新 API。特别是：
- IArena 接口方法（新增 Stats/SaveMark/RestoreToMark）
- TVirtualArena 新增方法（AllocUnsafe/ResetHard）
- 删除的模块（adapters/aligned 等）

**建议**：验证并更新 API.md。

---

### F-03 ⚠️ 缺少使用指南

**P3 | 文件：core/docs/mem/README.md**

缺少典型使用场景的代码示例：
- 如何选择 Arena 类型
- IAllocator vs IArena 的使用场景
- AllocUnsafe 的安全使用前提
- Reset vs ResetHard 的选择

**建议**：添加 "Quick Start" 和 "Choosing an Arena" 章节。

---

## 七、汇总

### 按优先级统计

| 优先级 | 数量 | 说明 |
|--------|------|------|
| P0 | 0 | 无阻塞性问题 |
| P1 | 3 | Breaking changes + 测试覆盖 + 文档过时 |
| P2 | 14 | API 一致性 + 死代码 + 性能 + 测试缺口 |
| P3 | 6 | 文档 + 代码质量 + 边缘场景 |

### 建议处理顺序

1. **P1-01**：记录 breaking changes，准备合并时的迁移清单
2. **P1-02**：补全 arena facade 导出
3. **P1-06**：更新 ARCHITECTURE.md
4. **P2-01**：统一错误处理文档
5. **P2-05**：添加 AllocUnsafe 到 TLocalArena/TChunkedArena
6. **P2-11**：修复 COMMIT_CHUNK_SIZE 可变常量
7. **P2-14**：补充 allocator.callback/mutex/rwlock 测试
8. **P3 类**：按需处理
