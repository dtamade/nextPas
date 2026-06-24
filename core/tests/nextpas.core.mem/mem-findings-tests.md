# mem-findings: 测试覆盖 + 文档

## 统计
- 总发现: 18
- major: 5, minor: 8, suggestion: 5

## 测试状态总览

| 状态 | 数量 | 测试项目 |
|------|------|----------|
| ✅ 通过 | 19 | test_mem, test_pool, test_arena, test_arena_class, test_slab_pool, test_blockpool, test_stack_pool, test_pool_allocator, test_contracts, test_concurrent_wrappers, test_default_allocator, test_mapped_ring_buffer, test_mapped_ring_buffer_sharded, test_mapped_slab_pool, test_mem_secure, test_memory_map_allocator, test_numa_allocator, test_memory_manager_rtl, test_memory_manager_crt_compile_gate |
| ✅ 编译通过 | 2 | test_memory_map_compile_gate, test_mem_secure_windows_compile_gate |
| ❌ 编译失败 | 2 | test_sharded_pools, test_oom (DefaultAcquireN 缺失) |
| ⚠️ Makefile 缺失 | 1 | test_mapped_ring_buffer_compile_gate (无 clean target) |

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
| mem.blockpool.growable.pas | test_sharded_pools (❌编译失败) | ❌ 无可用测试 |
| mem.blockpool.concurrent.pas | test_concurrent_wrappers | ✅ 基本覆盖 |
| mem.blockpool.sharded.pas | test_sharded_pools (❌编译失败) | ❌ 无可用测试 |
| mem.pool.fixed.pas | test_pool | ✅ 充分 |
| mem.pool.fixed.growable.pas | test_pool | ✅ 基本覆盖 |
| mem.pool.fixed_slab.pas | test_contracts | ⚠️ 通过 contracts 间接测试，无直接 slab 算法测试 |
| mem.pool.slab.pas | test_slab_pool | ✅ 充分 |
| mem.pool.slab.concurrent.pas | test_concurrent_wrappers | ✅ 基本覆盖 |
| mem.pool.slab.sharded.pas | test_sharded_pools (❌编译失败) | ❌ 无可用测试 |
| mem.pool.object_pool.pas | — | ❌ 无测试 |
| mem.pool.adapter.pas | — | ❌ 无测试 |
| mem.pool.allocator.pas | test_pool_allocator | ✅ 充分 |
| mem.stack_pool.pas | test_stack_pool | ✅ 充分 |
| mem.ring_buffer.pas | — | ⚠️ 只有 mapped 版本的测试 |
| mem.memory_map.pas | test_memory_map_allocator | ✅ 基本覆盖 |
| mem.mapped_slab_pool.pas | test_mapped_slab_pool | ✅ 基本覆盖 |
| mem.utils.pas (1313行) | — | ❌ 无直接测试（通过其他模块间接） |
| mem.stats.pas | — | ❌ 无测试 |
| mem.mutex.pas, mem.rwlock.pas | — | ⚠️ 通过 concurrent wrappers 间接测试 |
| mem.secure.pas | test_mem_secure | ✅ 充分 |
| mem.adapters.pas | — | ❌ 无测试 |
| mem.manager.*.pas (3 文件) | test_memory_manager_rtl, test_memory_manager_crt_compile_gate | ⚠️ RTL 有运行测试，mimalloc 无测试 |

---

## Findings

### [TC-001] 3 个核心池因编译错误完全无测试覆盖
- **严重度**: major
- **维度**: coverage
- **文件**: `blockpool.growable.pas`, `blockpool.sharded.pas`, `pool.slab.sharded.pas`
- **描述**: `test_sharded_pools` 和 `test_oom` 因 `DefaultAcquireN` 缺失编译失败。这导致 `TGrowingBlockPool`（793 行）、`TShardedBlockPool`（1424 行）、`TSlabPoolSharded`（1079 行）三个核心并发池完全没有测试。合计 3,396 行代码零覆盖。
- **影响**: 模块中最复杂的并发代码（分片、路由、GC 队列）没有测试保护。
- **建议**: 修复 CS-001（添加 pool.base uses）后立即恢复测试。

### [TC-002] mem.utils.pas 1313 行 / 71 个函数无直接测试
- **严重度**: major
- **维度**: coverage
- **文件**: `nextpas.core.mem.utils.pas`
- **描述**: utils.pas 提供 Copy/Fill/Zero/Compare/AlignUp/IsOverlap/IsPowerOfTwo 等 71 个内存操作函数，但没有专门的 test_utils 测试项目。只通过其他模块间接使用。
- **影响**: 如果某个 utils 函数有 bug（例如 Fill64 在特定对齐条件下出错），只能通过下游测试的间歇性失败发现。
- **建议**: 创建 `test_mem_utils` 测试项目，覆盖每个公共函数的正常和边界情况。

### [TC-003] IObjectPool 泛型接口完全没有测试
- **严重度**: major
- **维度**: coverage
- **文件**: `nextpas.core.mem.pool.object_pool.pas` (527 行)
- **描述**: `IObjectPool<T>` 和 `TObjectPool<T>` 是泛型对象池，但无任何测试。包括 Create/Destroy 生命周期、对象复用、池耗尽行为。
- **影响**: 泛型实例化可能有隐藏 bug（FPC 泛型的已知问题）。
- **建议**: 创建 `test_object_pool` 测试项目。

### [TC-004] pool.adapter.pas 桥接适配器无测试 — ⚠️ 已知限制
- **严重度**: major → 已知限制 (降级)
- **维度**: coverage
- **文件**: `nextpas.core.mem.pool.adapter.pas` (426 行)
- **描述**: `test_pool_adapter` 目前是占位 SKIP 记录，不构成测试闭环。pool.adapter 依赖已删除的 `nextpas.core.mem.layout`，且 `TStackPoolToArenaAdapter` 还在实现旧形态的 `IArena`（签名 `Alloc(TMemLayout): TAllocResult`），而当前 `IArena` 已经是 `Alloc(SizeUInt): Pointer` / `AllocAligned(...)`。
- **状态**: 已知限制 / 过期 compat 代码未闭环。需要决定 pool.adapter 是否值得继续维护，或应标记为 deprecated。

### [TC-005] mem.stats.pas 统计收集器无测试
- **严重度**: major
- **维度**: coverage
- **文件**: `nextpas.core.mem.stats.pas` (124 行)
- **描述**: TSlabPoolStats, TBlockPoolStats 等统计收集类无测试。这些类用于监控和调试。
- **影响**: 统计数据可能不准确而不被发现。
- **建议**: 创建 `test_mem_stats` 或在现有 pool 测试中添加统计验证。

### [TC-006] 测试几乎全部使用 FPC SysUtils 而非框架模块
- **严重度**: minor
- **维度**: quality
- **文件**: 19 个测试 .lpr 文件
- **描述**: 19 个测试 import SysUtils（用于 Format/IntToStr/Writeln），3 个 import Classes（用于 TStringList）。bench 模块审查时已将同类问题全部修复（改用 nextpas.core.text.conv 等）。
- **影响**: 测试在 sysroot/musl 环境下无法编译。
- **建议**: 批量替换为框架等价物（与 QA-002 重叠）。

### [TC-007] 测试不使用 nextpas.core.test 框架
- **严重度**: minor
- **维度**: quality
- **文件**: 所有测试 .lpr 文件
- **描述**: 测试全部使用手写 Assert + Writeln 模式，不使用 `nextpas.core.test` 框架。这与 bench 模块审查后的规范不一致。
- **影响**: 测试输出格式不统一，缺少结构化断言、测试计数、失败详情。
- **建议**: 逐步迁移到 nextpas.core.test 框架（优先级低于功能测试）。

### [TC-008] ring_buffer.pas 无直接测试
- **严重度**: minor
- **维度**: coverage
- **文件**: `nextpas.core.mem.ring_buffer.pas` (726 行)
- **描述**: 非映射版本的 ring buffer 只有 mapped 版本的测试（test_mapped_ring_buffer）。纯内存 ring buffer 的 Push/Pop/批量操作/容量边界没有测试。
- **影响**: 726 行代码无直接测试。
- **建议**: 创建 `test_ring_buffer` 或在现有测试中添加。

### [TC-009] TFixedSlabPool (ngx slab) 算法缺少专门测试
- **严重度**: minor
- **维度**: coverage
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` (1687 行)
- **描述**: 通过 test_contracts 间接测试了基本分配/释放。但缺少：不同 size class 的分配、页面分裂/合并、碎片化场景、slab 扩容。
- **影响**: 复杂的 slab 算法（nginx 移植）可能有隐藏 bug。
- **建议**: 创建 `test_fixed_slab` 测试，覆盖所有 size class 边界。

### [TC-010] mem.adapters.pas 适配器无测试
- **严重度**: minor
- **维度**: coverage
- **文件**: `nextpas.core.mem.adapters.pas` (197 行)
- **描述**: TSlabPoolToAllocator 等适配器类无测试。
- **建议**: 在现有 slab_pool 测试中添加适配器验证。

### [TC-011] 缺少 OOM（内存耗尽）测试
- **严重度**: minor
- **维度**: coverage
- **描述**: test_oom 因编译错误无法运行。即使修复后，OOM 测试的覆盖范围也需要评估——当前的 OOM 测试可能只测了基本的异常抛出。
- **影响**: 在真实 OOM 场景下的行为未验证。
- **建议**: 修复编译后审查 test_oom 覆盖范围。

### [TC-012] 并发测试缺少竞争压力测试
- **严重度**: minor
- **维度**: coverage
- **描述**: test_concurrent_wrappers 通过了基本并发操作，但缺少：高竞争压力测试（8+ 线程同时分配/释放）、长时运行稳定性测试、线程退出时的资源回收测试。
- **影响**: 并发 bug 可能在高负载下才显现。
- **建议**: 添加 stress test 变体（类似 bench 模块的 parallel 测试模式）。

### [TC-013] test_mapped_ring_buffer_compile_gate Makefile 缺少 clean target
- **严重度**: minor
- **维度**: infrastructure
- **文件**: `test_mapped_ring_buffer_compile_gate/Makefile`
- **描述**: Makefile 可能缺少 `clean` target（make clean 报错"没有规则可制作目标"）。
- **影响**: 无法清理构建产物。
- **建议**: 添加 clean target。

### [TC-014] 缺少模块级顶层 Makefile
- **严重度**: minor
- **维度**: infrastructure
- **描述**: `core/tests/nextpas.core.mem/` 没有顶层 Makefile，不能用 `make -C core/tests/nextpas.core.mem test` 一键运行所有测试。需要逐个手动运行 25 个子项目。
- **影响**: CI 和开发者运行全量测试不方便。
- **建议**: 创建顶层 Makefile，遍历所有子项目。

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
