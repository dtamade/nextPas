# mem 模块维护计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复 mem 模块所有编译失败，清理死代码，补齐测试覆盖到 100% 接口覆盖，使 47 测试套件全绿

**Architecture:** mem 是 L0 内核模块（只依赖 FPC RTL），包含 63 个源文件。Phase 0-7 重构改了 API 但没更新测试，导致 9/24 测试套件编译失败。另有 12 个源文件完全没有测试覆盖。

**Tech Stack:** FPC 3.3.1 trunk, Pascal `{$mode objfpc}`, Makefile 构建

---

## 现状摘要

- 源文件: 63 个 `.pas` 文件
- 测试套件: 24 个目录, 24 个 `.lpr`
- 通过: 15 套件 ✅
- 编译失败: 9 套件 ❌
- 无测试覆盖: ~12 个源文件
- 死代码: 10 个已废弃但未删除的文件
- 源码 bug: `blockpool.growable.pas` 缺少 `pool.base` 依赖

---

## Phase 1: 修复源码 bug (1 task)

### Task 1: 修复 blockpool.growable.pas 缺失依赖

**Files:**
- Modify: `core/src/nextpas.core.mem.blockpool.growable.pas` (uses 子句)

**问题:** `DefaultAcquireN`/`DefaultReleaseN` 定义在 `nextpas.core.mem.pool.base` 中，但 `blockpool.growable.pas` 没有引入该单元。

**Step 1: 修复 uses 子句**

在 interface uses 中加入 `nextpas.core.mem.pool.base`：

```pascal
uses
  nextpas.core.math,
  nextpas.core.mem.base,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.pool.base,      // ← 添加：DefaultAcquireN/DefaultReleaseN
  nextpas.core.mem.intf,
  nextpas.core.mem.error;
```

**Step 2: 验证编译通过**

```bash
make -C core/tests/nextpas.core.mem/test_oom clean test
make -C core/tests/nextpas.core.mem/test_sharded_pools clean test
```

Expected: 两个测试都编译并运行通过

**Step 3: Commit**

```bash
git add core/src/nextpas.core.mem.blockpool.growable.pas
git commit -m "fix(mem): add missing pool.base import in blockpool.growable"
```

---

## Phase 2: 修复编译失败的测试 (7 tasks)

### Task 2: 修复 test_mem — IAllocator 方法重命名

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_mem/test_mem.lpr`

**API 变更映射:**
- `Allocate(size)` → `GetMem(size)`
- `Reallocate(ptr, size)` → `ReallocMem(ptr, size)`
- `Deallocate(ptr)` → `FreeMem(ptr)`

**Step 1: 更新测试代码**

```pascal
  // 旧: LPtr := LAlloc.Allocate(1024);
  LPtr := LAlloc.GetMem(1024);
  Assert(LPtr <> nil, 'GetMem should return non-nil');

  // Write and read
  LIntPtr := PInteger(LPtr);
  LIntPtr^ := 42;
  Assert(LIntPtr^ = 42, 'Should read back written value');

  // 旧: LPtr := LAlloc.Reallocate(LPtr, 2048);
  LPtr := LAlloc.ReallocMem(LPtr, 2048);
  Assert(LPtr <> nil, 'ReallocMem should return non-nil');
  LIntPtr := PInteger(LPtr);
  Assert(LIntPtr^ = 42, 'Value should survive reallocation');

  // 旧: LAlloc.Deallocate(LPtr);
  LAlloc.FreeMem(LPtr);
```

**Step 2: 运行验证**

```bash
make -C core/tests/nextpas.core.mem/test_mem clean test
```

Expected: PASS

**Step 3: Commit**

---

### Task 3: 修复 test_arena — TLocalArena 改为 class API

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_arena/test_arena.lpr`

**API 变更映射:**
- `var A: TLocalArena; A.Init(size)` → `A := TLocalArena.Create(size)`
- `A.Done` → `A.Free`
- `A.Capacity` → `A.TotalSize`
- `A.BytesUsed` → `A.UsedSize`
- `A.BytesRemaining` → `A.RemainingSize`

**Step 1: 重写测试**，将所有 `LP.Init(xxx)` 改为 `LP := TLocalArena.Create(xxx)`，`LP.Done` 改为 `LP.Free`，属性名相应调整。注意 TLocalArena 现在是 class，需要 `var LP: TLocalArena;` 而不是 record。

**Step 2: 运行验证**

```bash
make -C core/tests/nextpas.core.mem/test_arena clean test
```

**Step 3: Commit**

---

### Task 4: 修复 test_arena_class — TArena 别名变更

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_arena_class/test_arena_class.lpr`

**问题:** `TArena` 现在是 `TFixedArena`（来自 blockpool），不再是 `TLocalArena` 的别名。测试应该用 `TLocalArena` 或 `TFixedArena`。

**Step 1:** 将 uses 改为引用 `nextpas.core.mem.arena` 或 `nextpas.core.mem`，使用 `TLocalArena` 替换 `TArena`。如果测试原本测试的是 blockpool 的 arena 实现，则改用 `TFixedArena`。

**Step 2: 运行验证**

```bash
make -C core/tests/nextpas.core.mem/test_arena_class clean test
```

**Step 3: Commit**

---

### Task 5: 修复 test_pool — TLocalBlockPool 改为 class API

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_pool/test_pool.lpr`

**API 变更映射:**
- `LP.Init(bs, count)` → `LP := TLocalBlockPool.Create(bs, count)`
- `LP.Done` → `LP.Free`
- `LP.BlockCount` → `LP.Capacity`
- `LP.AcquiredCount` → `LP.InUse`
- `LP.AvailableCount` → `LP.Available`

**注意:** `TFixedPoolRecordingAllocator` 需要添加 `MemSize` 方法实现。

**Step 1:** 更新所有使用旧 API 的测试过程。

**Step 2:** 运行验证

```bash
make -C core/tests/nextpas.core.mem/test_pool clean test
```

**Step 3: Commit**

---

### Task 6: 修复 test_contracts — 删除对已不存在的 mem.compat 的引用

**Files:**
- Modify or Delete: `core/tests/nextpas.core.mem/test_contracts/test_contracts.lpr`

**问题:** 测试引用了 `nextpas.core.mem.compat`，但该单元已在 Phase 0-7 重构中删除。

**Step 1:** 读取 test_contracts.lpr 内容，确认测试意图，然后更新 uses 和测试逻辑以匹配当前 API。

**Step 2:** 运行验证

```bash
make -C core/tests/nextpas.core.mem/test_contracts clean test
```

**Step 3: Commit**

---

### Task 7: 修复 test_slab_pool — IAllocator 缺少 MemSize 实现

**Files:**
- Modify: `core/tests/nextpas.core.mem/test_slab_pool/test_slab_pool.lpr`

**问题:** 测试中的 mock allocator 类未实现 `MemSize` 方法。

**Step 1:** 为 mock allocator 添加 `MemSize` 实现（返回 0 或正确值）。

**Step 2:** 运行验证

```bash
make -C core/tests/nextpas.core.mem/test_slab_pool clean test
```

**Step 3: Commit**

---

### Task 8: 修复 test_memory_map_compile_gate — platform.sync 编译问题

**Files:**
- 观察性修复：`core/src/nextpas.core.platform.sync.pas` 或 compile gate 测试

**问题:** `platform.sync.pas` 有未解决的 forward declaration（`platform_wait_address64` 等），这不是 mem 模块的问题，而是 platform 模块的问题。该 compile gate 测试用 `-dNEXTPAS_FORCE_HOST_WINDOWS` 交叉编译。

**Step 1:** 确认这是 platform 已知问题还是回归。如果是已知问题，暂时标记为跳过。

**Step 2:** 如果能修，修复 forward declaration。如果是 platform 问题，将此测试标记为 XFAIL 或暂时注释。

---

## Phase 3: 清理死代码 (1 task)

### Task 9: 删除 Phase 0-7 遗留的废弃文件

**Files to delete (10 files):**
- `core/src/nextpas.core.mem.adapter.pas` — 旧适配器
- `core/src/nextpas.core.mem.adapters.pas` — 聚合适配器
- `core/src/nextpas.core.mem.default.pas` — 旧默认分配器（0 引用）
- `core/src/nextpas.core.mem.interfaces.pas` — 旧接口集合
- `core/src/nextpas.core.mem.mem_pool.pas` — 旧内存池
- `core/src/nextpas.core.mem.pool.adapter.pas` — 旧池适配器
- `core/src/nextpas.core.mem.allocator.callback_allocator.pas` — callback allocator 包装
- `core/src/nextpas.core.mem.allocator.crt_allocator.pas` — CRT allocator 包装
- `core/src/nextpas.core.mem.allocator.rtl_allocator.pas` — RTL allocator 包装
- `core/tests/nextpas.core.mem/test_contracts/test_contracts.lpr` — 如果 Task 6 判定为不可修复

**注意:** 删除前必须逐个验证确实没有其他文件引用它们。

**Step 1:** 逐个 grep 确认 0 有效引用

**Step 2:** 删除文件

**Step 3:** 运行全套测试确认无回归

```bash
# 运行所有通过的测试确认无回归
make -C core/tests/nextpas.core.mem/test_blockpool clean test
make -C core/tests/nextpas.core.mem/test_concurrent_wrappers clean test
make -C core/tests/nextpas.core.mem/test_default_allocator clean test
make -C core/tests/nextpas.core.mem/test_pool_allocator clean test
```

**Step 4: Commit**

```bash
git add -u core/src/nextpas.core.mem.*
git commit -m "chore(mem): remove 9 deprecated compatibility units from Phase 0-7"
```

---

## Phase 4: 补齐缺失的测试覆盖 (12 tasks)

### Task 10: test_utils — mem.utils 接口测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_utils/test_utils.lpr`
- Create: `core/tests/nextpas.core.mem/test_utils/Makefile`

**覆盖函数:** `IsPowerOfTwo`, `NextPowerOfTwo`, `AlignUp`, `AlignDown`, `MemCopy`, `MemMove`, `MemSet`, `MemZero`, `MemCompare`, `OverlapCheck`

**测试点:**
- 边界值: 0, 1, MaxValue
- 对齐: 2/4/8/16/64/4096
- 重叠内存区域的 Move 正确性
- 零长度操作
- 比较相同/不同内存

---

### Task 11: test_layout — mem.layout 接口测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_layout/test_layout.lpr`
- Create: `core/tests/nextpas.core.mem/test_layout/Makefile`

**覆盖:** `TMemLayout.Create`, `IsValid`, `Pad`, `Slice`, 对齐规范化

---

### Task 12: test_alloc — mem.alloc 适配器测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_alloc/test_alloc.lpr`
- Create: `core/tests/nextpas.core.mem/test_alloc/Makefile`

**覆盖:** `GetMem/FreeMem/AllocMem/ReallocMem` 适配器封装

---

### Task 13: test_rwlock — mem.rwlock 生命周期测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_rwlock/test_rwlock.lpr`
- Create: `core/tests/nextpas.core.mem/test_rwlock/Makefile`

**覆盖:** `TMemRwLock.Init/Done`, 幂等性, 未初始化守卫, 读写锁语义

---

### Task 14: test_mutex — mem.mutex 生命周期测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_mutex/test_mutex.lpr`
- Create: `core/tests/nextpas.core.mem/test_mutex/Makefile`

**覆盖:** `TMemMutex.Init/Done`, `Acquire/Release`, 幂等性, 未初始化守卫

---

### Task 15: test_arena_growable — growable arena 测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_arena_growable/test_arena_growable.lpr`
- Create: `core/tests/nextpas.core.mem/test_arena_growable/Makefile`

**覆盖:** 容量内分配、超容自动扩容、对齐分配、清零分配、重置、多次扩容

---

### Task 16: test_blockpool_growable — growable blockpool 测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_blockpool_growable/test_blockpool_growable.lpr`
- Create: `core/tests/nextpas.core.mem/test_blockpool_growable/Makefile`

**覆盖:** 基础分配/释放、自动扩容、segment 管理、配置参数、重置

---

### Task 17: test_ring_buffer — 内存 ring buffer 测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_ring_buffer/test_ring_buffer.lpr`
- Create: `core/tests/nextpas.core.mem/test_ring_buffer/Makefile`

**覆盖:** Push/Pop、环绕回卷、TryPush/TryPop、Peek、Clear、批量操作

---

### Task 18: test_fixed_slab — 固定 slab 池测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_fixed_slab/test_fixed_slab.lpr`
- Create: `core/tests/nextpas.core.mem/test_fixed_slab/Makefile`

**覆盖:** `TFixedSlabPool` 的 alloc/release、exhaust、TryAlloc、reset

---

### Task 19: test_stack_scope_helpers — RAII scope guard 测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_stack_scope_helpers/test_stack_scope_helpers.lpr`
- Create: `core/tests/nextpas.core.mem/test_stack_scope_helpers/Makefile`

**覆盖:** `TScopedArena`, `TScopedPool`, scope exit 自动释放

---

### Task 20: test_instrumentation — 分配统计跟踪测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_instrumentation/test_instrumentation.lpr`
- Create: `core/tests/nextpas.core.mem/test_instrumentation/Makefile`

**覆盖:** `TInstrumentedAllocator` 的 Allocate/Deallocate/Reallocate 统计计数

---

### Task 21: test_allocator_foundation — allocator foundation 编译冒烟测试

**Files:**
- Create: `core/tests/nextpas.core.mem/test_allocator_foundation/test_allocator_foundation.lpr`
- Create: `core/tests/nextpas.core.mem/test_allocator_foundation/Makefile`

**覆盖:** `allocator.foundation` 单元编译+基本运行验证

---

## Phase 5: 最终验证 (1 task)

### Task 22: 全套测试运行 + 0 泄漏验证

**Step 1:** 运行所有 36 个测试套件 (24 修复后 + 12 新增)

**Step 2:** 确认全部通过，heaptrc 显示 0 泄漏

**Step 3:** 更新 `core/docs/mem/README.md` 的 Focused Gates 列表

**Step 4: Final Commit**

---

## 执行顺序

```
Phase 1: Task 1 (源码 bug)
Phase 2: Tasks 2-8 (修复 9 个失败测试)
Phase 3: Task 9 (清理死代码)
Phase 4: Tasks 10-21 (补齐 12 个测试)
Phase 5: Task 22 (最终验证)
```

## 总路线图位置

mem 模块处于 L0 内核层。当前任务是维护和补齐，不是新增功能。
完成后 mem 将达到：36 测试套件全绿、0 泄漏、0 死代码、100% 接口覆盖。
