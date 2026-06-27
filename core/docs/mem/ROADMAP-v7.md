# mem 模块路线图 v7.0

## 当前位置

```
Round 1-13: 打磨 + Bug 修复 + 测试 + 合并 main     ✅
Phase D:    测试覆盖 100%                             ✅
Phase E:    文档注释 80%+                              ✅ 本轮
当前位置:  → Phase F (基准测试 + Go/Rust 对照)
```

## 当前状态

- 31 suites / 465 tests / 0 leaks
- 9 文件 150+ 处方法级文档注释
- 57 类型 re-export (facade 完整)
- 0 个 SysUtils 引用 (source + tests)

---

## Phase D: 测试覆盖 100% ✅

目标: 每个公共 API 都有直接单元测试，0 泄漏。

**完成**: 31 suites / 465 tests / 0 leaks。3 新套件 (growing_fixed_pool / growing_block_pool / shared_memory) + 35 新测试。

---

## Phase E: 文档注释 ✅

目标: 核心公共 API 的 `{** @desc *}` 覆盖率从 ~30% 提升到 80%+。

**完成**: 9 文件 / 150+ 处方法级文档注释，中文 `{** @desc *}` 格式。

| 文件 | 覆盖 | 新增文档数 |
|------|------|-----------|
| `blockpool.pas` | 100% | 25 |
| `pool.fixed.pas` | 100% | 44 |
| `pool.fixed.growable.pas` | 100% | 14 |
| `pool.slab.pas` | 93% | 36 |
| `ring_buffer.pas` | 100% | 42 |
| `stack_pool.pas` | 86% | 62 |
| `blockpool.concurrent.pas` | +13 | 13 |
| `mapped_slab_pool.pas` | +8 | 8 |
| `allocator.fallback.pas` | +21 | 21 |

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

| Phase | 完成条件 | 状态 |
|-------|----------|------|
| **D** | ≥460 tests / 0 leaks / 100% API 覆盖 | ✅ 完成 |
| **E** | 80%+ 方法级文档 | ✅ 完成 |
| **F** | 核心热路径基准 + Go/Rust 对照 | → 下轮 |
