# mem 模块路线图 v7.0

## 当前位置

```
Round 1-13: 打磨 + Bug 修复 + 测试 + 合并 main     ✅
当前位置:  → Phase D (测试覆盖 100% + 文档 + 基准)
```

## 当前状态

- 28 suites / 430 tests / 0 leaks
- 57 类型 re-export (facade 完整)
- 0 个 SysUtils 引用 (source + tests)
- 所有 Critical/Major 审计发现已清零

---

## Phase D: 测试覆盖 100% (本轮)

目标: 每个公共 API 都有直接单元测试，0 泄漏。

### D-1: 新测试套件 (3 个新项目)

| ID | 测试项目 | 覆盖目标 | 预估测试数 |
|----|----------|----------|-----------|
| D-1a | `test_growing_fixed_pool` | TGrowingFixedPool 正常路径 (Acquire/Release/Reset/ShrinkTo/Config) + 异常路径 | ~12 |
| D-1b | `test_growing_block_pool` | TGrowingBlockPool 正常路径 (Acquire/Release/Reset/ShrinkTo) + 增长策略 | ~10 |
| D-1c | `test_shared_memory` | TSharedMemory Create/Open/Read/Write/Flush/Close + 边界 | ~8 |

### D-2: 现有测试补充 (4 个文件)

| ID | 目标 | 内容 |
|----|------|------|
| D-2a | `test_allocator_foundation` | +TryGetRtlAllocator 测试 |
| D-2b | `test_contracts` | +MimallocUsableSizeAvailable/TryGetMimallocUsableSize 测试 |
| D-2c | `test_mem_utils` | +mem.base 函数直接测试 (IsPowerOfTwo/NextPowerOfTwo/AlignUp/NormalizeAlignment 边界值) |
| D-2d | `test_concurrent_wrappers` | +TMemRwLock 写锁竞争测试 (4 线程 writer + reader 交替) |

### D-3: 验收

- 全量回归 ≥460 tests / 0 failures / 0 leaks
- self-host 双编译器验证
- git commit

---

## Phase E: 文档注释 (下轮)

目标: 核心公共 API 的 `{** @desc *}` 覆盖率从 ~30% 提升到 80%+。

### E-1: 方法级文档 (高优先级)

| 文件 | 当前 | 目标 | 方法数 |
|------|------|------|--------|
| `blockpool.pas` | 0% | 80%+ | 18 methods |
| `pool.fixed.pas` | 0% | 80%+ | 25 methods |
| `pool.slab.pas` | 0% | 80%+ | 26 methods |
| `ring_buffer.pas` | 38% | 80%+ | ~20 undocumented |
| `stack_pool.pas` | 47% | 80%+ | ~25 undocumented |

### E-2: 类型级文档补全

| 文件 | 缺失类型 |
|------|----------|
| `pool.slab.pas` | TSlabPerfCounters, TSlabPoolStats, TSlabConfig, TSlabFallbackAlloc |
| `pool.fixed.pas` | TFixedPoolConfig |
| `stack_pool.pas` | TStackPoolConfig, TStackMemoryMapEntry |

---

## Phase F: 基准测试 (最后一轮)

目标: 核心热路径有 nextpas.core.bench 基准 + Go/Rust/FPC RTL 对照。

### F-1: 修复现有基准 (3 个项目迁移到 nextpas.core.bench)

| 项目 | 当前 | 目标 |
|------|------|------|
| `bench_alloc` | 手动计时 | nextpas.core.bench |
| `bench_arena_go_rust` | 手动计时 | nextpas.core.bench (保留 Go/Rust 对照) |
| `bench_new_components` | 手动计时 | nextpas.core.bench |

### F-2: 新增基准 (核心热路径)

| 基准项目 | 覆盖 | 对照 |
|----------|------|------|
| `bench_pool_fixed` | TBlockPool Acquire/Release | Go sync.Pool, Rust slab |
| `bench_pool_slab` | TSlabPool GetMem/FreeMem | jemalloc, Rust slab |
| `bench_ring_buffer` | TRingBuffer Push/Pop | Go chan, Rust ringbuf |
| `bench_stack_pool` | TStackPool Alloc/Reset | alloca, Rust bumpalo |

---

## 里程碑

| Phase | 完成条件 | 预估轮次 |
|-------|----------|----------|
| **D** | ≥460 tests / 0 leaks / 100% API 覆盖 | 1-2 轮 |
| **E** | 80%+ 方法级文档 | 1-2 轮 |
| **F** | 核心热路径基准 + Go/Rust 对照 | 2-3 轮 |
