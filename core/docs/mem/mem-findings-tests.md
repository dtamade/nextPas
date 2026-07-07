# mem-findings: 测试覆盖 + 文档

## 统计
- 总发现: 18
- major: 5, minor: 8, suggestion: 5

## 测试状态总览

| 状态 | 数量 | 测试项目 |
|------|------|----------|
| ✅ 通过 | 27 | test_mem, test_pool, test_arena, test_arena_class, test_slab_pool, test_blockpool, test_stack_pool, test_pool_allocator, test_contracts, test_concurrent_wrappers, test_default_allocator, test_mapped_ring_buffer, test_mapped_ring_buffer_sharded, test_mapped_slab_pool, test_mem_secure, test_memory_map_allocator, test_numa_allocator, test_memory_manager_rtl, test_memory_manager_crt_compile_gate, test_sharded_pools, test_oom, test_tracking_allocator, test_arena_compiler, test_allocator_mmap, test_allocator_virtual_arena, test_allocator_numa, test_mem_utils |
| ✅ 编译通过 | 2 | test_memory_map_compile_gate, test_mem_secure_windows_compile_gate |
| ❌ 编译失败 | 0 | — |
| ⚠️ Makefile 缺失 | 0 | — |

## 测试覆盖矩阵

| 源文件 | 测试文件 | 覆盖评估 |
|--------|----------|----------|
| mem.pas (门面) | test_mem | ✅ 基本导出验证 |
| mem.intf.pas (IAllocator) | test_contracts | ✅ 契约验证 |
| mem.base.pas | — | ⚠️ 间接测试，无直接测试 NextPowerOfTwo/AlignUp 边界 |
| mem.error.pas | test_contracts | ✅ 异常类型验证 |
| mem.allocator.*.pas (8 文件) | test_default_allocator, test_pool_allocator | ⚠️ 只测了 RTL 和 Pool 分配器，callback/crt/mmap/mimalloc/numa/instrumentation 无直接测试 |
| mem.arena.pas | test_arena, test_arena_class | ✅ 充分 |
| mem.arena.growable.pas | test_arena | ✅ 充分 |
| mem.blockpool.pas | test_blockpool | ✅ 充分 |
| mem.blockpool.growable.pas | test_sharded_pools | ✅ 编译运行通过 |
| mem.blockpool.concurrent.pas | test_concurrent_wrappers | ✅ 基本覆盖 |
| mem.blockpool.sharded.pas | test_sharded_pools | ✅ 9 tests 竞争/路由/诊断 |
| mem.pool.fixed.pas | test_pool | ✅ 充分 |
| mem.pool.fixed.growable.pas | test_pool | ✅ 基本覆盖 |
| mem.pool.fixed_slab.pas | test_contracts | ⚠️ 通过 contracts 间接测试，无直接 slab 算法测试 |
| mem.pool.slab.pas | test_slab_pool | ✅ 充分 |
| mem.pool.slab.concurrent.pas | test_concurrent_wrappers | ✅ 基本覆盖 |
| mem.pool.slab.sharded.pas | test_sharded_pools | ✅ 8 threads 竞争/诊断 |
| mem.pool.object_pool.pas | test_object_pool | ✅ 12 tests (泛型实例化/Create/Destroy/复用/OOM) |
| mem.pool.adapter.pas | — | ⚠️ 已知限制（compat 代码，依赖已删除 layout） |
| mem.pool.allocator.pas | test_pool_allocator | ✅ 充分 |
| mem.stack_pool.pas | test_stack_pool | ✅ 充分 |
| mem.ring_buffer.pas | test_ring_buffer | ✅ 30 tests (Push/Pop/批量/容量/AdvanceIndex) |
| mem.memory_map.pas | test_memory_map_allocator | ✅ 基本覆盖 |
| mem.mapped_slab_pool.pas | test_mapped_slab_pool | ✅ 基本覆盖 |
| mem.utils.pas (1313行) | test_mem_utils | ✅ 36 tests (Copy/Fill/Zero/Compare/AlignUp/IsOverlap) |
| mem.stats.pas | — | ⚠️ 无专门测试（通过 pool 间接验证） |
| mem.mutex.pas, mem.rwlock.pas | — | ⚠️ 通过 concurrent wrappers 间接测试 |
| mem.secure.pas | test_mem_secure | ✅ 充分 |
| mem.adapters.pas | — | ❌ 无测试 |
| mem.manager.*.pas (3 文件) | test_memory_manager_rtl, test_memory_manager_crt_compile_gate | ⚠️ RTL 有运行测试，mimalloc 无测试 |

---

## Findings

### [TC-001] 3 个核心池因编译错误完全无测试覆盖 — ✅ 已修复
- **严重度**: major → 已关闭
- **维度**: coverage
- **文件**: `blockpool.growable.pas`, `blockpool.sharded.pas`, `pool.slab.sharded.pas`
- **描述**: `test_sharded_pools` 和 `test_oom` 编译失败。
- **状态**: 已修复。test_sharded_pools 9/9 通过，test_oom 8/8 通过。3,396 行并发代码已有测试覆盖。

### [TC-002] mem.utils.pas 1313 行 / 71 个函数无直接测试 — ✅ 已修复
- **严重度**: major → 已关闭
- **维度**: coverage
- **状态**: test_mem_utils 已存在，36 tests 覆盖 Copy/Fill/Zero/Compare/AlignUp/IsOverlap 等。

### [TC-003] IObjectPool 泛型接口完全没有测试 — ✅ 已修复
- **严重度**: major → 已关闭
- **维度**: coverage
- **状态**: test_object_pool 已存在，12 tests 覆盖泛型实例化/Create/Destroy/复用/OOM。

### [TC-004] pool.adapter.pas 桥接适配器无测试 — ✅ 已关闭
- **严重度**: major → 已关闭
- **维度**: coverage
- **文件**: `nextpas.core.mem.pool.adapter.pas`
- **状态**: 已关闭 — adapter.pas 已删除，v1 兼容层已移除，测试问题自然消除。

### [TC-005] mem.stats.pas 统计收集器无测试 — ⏳ 低优先级
- **严重度**: major → minor (降级)
- **维度**: coverage
- **描述**: TSlabPoolStats 等统计类无专门测试，但通过 test_slab_pool 和 test_contracts 间接验证。
- **状态**: 低优先级，通过间接测试覆盖。

### [TC-006] 测试使用 FPC SysUtils/Classes — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: quality
- **文件**: 6 个测试 .lpr 文件
- **描述**: 6 个测试 import SysUtils 或 Classes（IntToStr/Sleep/GetTickCount64/未使用 import）。
- **状态**: 已修复 — IntToStr→text.conv.IntToStr, Sleep→SleepMs, GetTickCount64→time.cpu.GetTickCount64, 未使用 import 已删除。SysUtils/Classes 残留清零。

### [TC-007] 测试不使用 nextpas.core.test 框架 — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: quality
- **文件**: 所有测试 .lpr 文件
- **描述**: 44/47 个测试已使用 nextpas.core.test 框架。仅剩 1 个功能测试（test_fragmentation）和 2 个 compile gate 未使用框架，符合预期。
- **状态**: 已修复。test_fragmentation 是特殊的功能测试（RSS 测量），compile gate 不需要运行时框架。

### [TC-008] ring_buffer.pas 无直接测试 — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: coverage
- **状态**: test_ring_buffer 已存在，30 tests 覆盖 Push/Pop/批量操作/容量边界/AdvanceIndex。

### [TC-009] TFixedSlabPool (ngx slab) 算法缺少专门测试 — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: coverage
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas`
- **描述**: 缺少 size class 边界、AllocMem 零初始化、SecureFree、大对象回退、容量耗尽等测试。
- **状态**: 已修复。新建 `test_fixed_slab/test_fixed_slab.lpr`，13 tests 全通过，0 leaks。

### [TC-010] mem.adapters.pas 适配器无测试 — stale
- **严重度**: minor → 已关闭
- **维度**: coverage
- **描述**: `mem.adapters.pas` 不存在于源码树中（grep 0 命中），finding 引用的文件已被移除或从未创建。
- **状态**: stale — 文件不存在，无测试目标。

### [TC-011] 缺少 OOM（内存耗尽）测试 — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: coverage
- **描述**: test_oom 编译运行通过，8/8 测试覆盖 EOutOfMemory 异常、blockpool 溢出、growable OOM、allocator OOM、virtual arena reserve/commit/mmap 失败。
- **状态**: 已修复。test_oom 8/8 通过。

### [TC-012] 并发测试缺少竞争压力测试 — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: coverage
- **描述**: test_concurrent_wrappers 已包含全面的并发测试：
  - 8 线程 × 32/128 iterations
  - Stress test: ArenaResetVsAllocContention, ArenaMarkVsAllocContention
  - 高竞争: MemMutexHighContention, RwLockWriteContention, RwLockMixedReaderWriterContention
  - 边界测试: MutexReleaseWithoutLock, RwLockMultipleReaders, MutexRecursiveAcquire
- **状态**: 已修复。并发测试覆盖充分。

### [TC-013] test_mapped_ring_buffer_compile_gate Makefile 缺少 clean target
- **严重度**: minor
- **维度**: infrastructure
- **文件**: `test_mapped_ring_buffer_compile_gate/Makefile`
- **描述**: Makefile 可能缺少 `clean` target（make clean 报错"没有规则可制作目标"）。
- **影响**: 无法清理构建产物。
- **建议**: 添加 clean target。

### [TC-014] 缺少模块级顶层 Makefile — ✅ 已修复
- **严重度**: minor → 已关闭
- **维度**: infrastructure
- **描述**: `core/tests/nextpas.core.mem/` 没有顶层 Makefile。
- **状态**: 已创建。支持 `make test` (34 suites)、`make test-fast` (28 suites)、`make clean`、`make list`。修复于 2026-06-29。

### [TC-015] L0 边界检查脚本说明 — ✅ 已基本澄清
- **严重度**: suggestion → 已关闭
- **维度**: infrastructure
- **文件**: `check_mem_l0_dependencies.sh`
- **描述**: README 已明确解释 mem.mutex / mem.rwlock 作为 L0 mem-local sync seam 的设计理由，无需强行把同样说明复制进脚本。
- **状态**: 已基本澄清，无需代码改动。

### [TC-016] benchmark 基线 — ✅ 已修复
- **严重度**: suggestion → 已关闭
- **维度**: coverage
- **描述**: `bench_alloc` 已迁移到当前 IAllocator API（GetMem/FreeMem）+ platform.time，消除编译错误和 API 漂移。
- **状态**: 已修复，benchmark 可编译运行。

### [TC-017] deprecated API 迁移测试 — ⏳ 低优先级
- **严重度**: suggestion
- **维度**: coverage
- **描述**: `nextpas.core.io.mapped.ring_buffer` 已有 compile gate，但 mem 侧运行测试仍主要覆盖 deprecated 的 `nextpas.core.mem.mapped_ring_buffer` 包装层。
- **状态**: 新 owner surface 已有 compile truth，但缺少 runtime owner-surface coverage；后续可补 io 侧运行测试，当前无需插队处理。

### [TC-018] README 架构图 — ⏳ 纯文档增强项
- **严重度**: suggestion
- **维度**: docs
- **文件**: `core/docs/mem/README.md`
- **描述**: README 文档质量已显著提升（Stable Surface、Boundary Truth、Follow-Up Route），但仍可补一张简洁的接口继承/owner 关系图。
- **状态**: 纯文档增强项，可在下次文档整理时添加。
