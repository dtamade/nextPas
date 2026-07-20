# mem 门面表面冻结

**状态**: Frozen · **F3 批 1 applied 2026-07-20**
**权威**: 本文件 + `nextpas.core.mem.pas` uses 列表
**门禁**: `test_usability_guardrails/check_usability_docs.sh`（禁止门面 uses Tier-3）
**设计**: [FACADES-SLIM-DESIGN-2026-07-20.md](FACADES-SLIM-DESIGN-2026-07-20.md)

本文件冻结 **`nextpas.core.mem` 门面允许 re-export 的单元范围**。
目标：可发现性与长期兼容；禁止再把门面当「分配器博物馆」。

---

## 1. 规则

| 规则 | 含义 |
|------|------|
| **允许** | Tier-0 热路径 + 已文档化的生产诊断 / 后端 / 池 |
| **禁止新增** | 向 `nextpas.core.mem` uses 增加未列入本文件的单元 |
| **Tier-3** | 不得进入门面；调用方 `uses` 子单元，无兼容承诺 |
| **收紧** | 删除 re-export = 显式 **breaking** slice（F3）；源文件可保留 |

**当前 interface uses 计数**: **41**（含 base/utils；F3 前 65）。

---

## 2. Tier 定义（产品视角）

| Tier | 用途 | 发现路径 |
|------|------|----------|
| **0** | 热堆、过程式 API、Arena、固定池、过程统计 | **门面** |
| **1** | 生产诊断注入（tracking、sentinel、guard）+ fallback | **门面** |
| **2 demoted** | 冷门包装器 / 并发池变体 / budget·oom | **仅子单元**（F3） |
| **2 optional backend** | mapped / ring（有外部 consumer） | **门面** |
| **2 demoted backend** | mimalloc / mmap 分配器类型 | **仅子单元**（G2） |
| **3 Experimental** | growable 等研究型 | **仅子单元** |

### Tier-3 黑名单（不得出现在 `nextpas.core.mem` uses）

**仍保留且禁止进门面**：

```text
nextpas.core.mem.blockpool.growable   # used by blockpool.sharded; not facade
```

**P-a / P-b 已删除** — 不得复活（见历史清单；guardrails forbid 已删名）。

---

## 3. 默认产品表面（必须可从门面发现）

| 表面 | API |
|------|-----|
| 热堆 | `DefaultHeap` / `GetMem` / `FreeMem(ptr,size)` / `TryBlockSize` |
| 注入 | `DefaultAllocator` / `ResolveAllocator` / `FreeMemOf` / `TryFreeMemOf` / `ReallocMemOf` / `TryReallocMemOf` |
| Arena | `CreateDefaultArena` / `CreateArenaAllocator` / `CreateVirtualArenaAllocator` |
| 池工厂 | `CreateFixedSlabPool` / `CreatePoolAllocator` |
| 诊断 | `GetMemStats` / `FormatMemStats` / `FormatMemDebugProfile` / `IsMemHeapDebugEnabled` / `IsMemHeapSafetyEnabled` / `IsMemArenaStrictEnabled` / `MemDebugCoverageGap` |
| 错误 | `FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg` / `EAllocError` |
| Try* | `TryGetMem` / `TryFreeMem` / `TryArenaAlloc` … |
| 生产诊断类型 | `TTrackingAllocator` / `TSentinelAllocator` / `TGuardAllocator` |
| 组合 | `TFallbackAllocator` / `TFallbackArena` |

---

## 4. 门面 interface uses 白名单（F3 后）

```text
nextpas.core.base
nextpas.core.base.utils
nextpas.core.mem.base
nextpas.core.mem.intf
nextpas.core.mem.error
nextpas.core.mem.default
nextpas.core.mem.debug_wrap
nextpas.core.mem.mutex
nextpas.core.mem.rwlock
nextpas.core.mem.arena.base / .intf / .local / .chunked / .virtual / .thread / .concurrent
nextpas.core.mem.allocator.arena
nextpas.core.mem.allocator.tracking
nextpas.core.mem.allocator.leak_check
nextpas.core.mem.allocator.fallback
nextpas.core.mem.pool.sizeclass / .fixed / .fixed_slab / .slab / .base / pool
nextpas.core.mem.blockpool
nextpas.core.mem.ring_buffer
nextpas.core.mem.memory_map
nextpas.core.mem.mapped_slab_pool
nextpas.core.mem.secure
nextpas.core.mem.stats
nextpas.core.mem.allocator.sentinel / .guard
nextpas.core.mem.allocator.crt / .foundation / .growing / .growing_ia / .rtl
```

`CreatePoolAllocator` 实现 uses（非 interface re-export）：`nextpas.core.mem.pool.allocator`。

---

## 5. F3 批 1 已移出门面（源保留 · 直接 uses 子单元）

```text
allocator.logging / sampling / debug_alloc / hotswap / counting
allocator.zeroed / fail / scoped / batch / callback
allocator.aligned / bounded / stats / leak_report / thread_safe / pool
allocator.mimalloc / allocator.mmap   # G2 批 2：可选后端，0 非 mem 产品引用
budget / oom
pool.slab.concurrent / pool.slab.sharded
blockpool.concurrent / blockpool.sharded
stack_pool
```

**示例**:

```pascal
uses nextpas.core.mem.allocator.logging;  // TLoggingAllocator
uses nextpas.core.mem.pool.slab.concurrent; // TSlabPoolConcurrent
```

---

## 6. 变更纪律

1. 向门面 **新增** uses = 更新本文件 + README「门面与 Tier」+ guardrails。
2. 把 Tier-3 或 §5 demoted 名单拉回门面 = **禁止**（除非独立 breaking 设计）。
3. 再收紧 = 新 breaking slice，不混功能修复。

相关：[README.md](README.md) · [API-GUIDE.md](API-GUIDE.md) · [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) · [FACADES-SLIM-DESIGN-2026-07-20.md](FACADES-SLIM-DESIGN-2026-07-20.md)
