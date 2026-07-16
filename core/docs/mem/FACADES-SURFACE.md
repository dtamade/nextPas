# mem 门面表面冻结（F6）

**状态**: Frozen
**权威**: 本文件 + `nextpas.core.mem.pas` uses 列表
**门禁**: `test_usability_guardrails/check_usability_docs.sh`（禁止门面 uses Tier-3）

本文件冻结 **`nextpas.core.mem` 门面允许 re-export 的单元范围**。
目标：可发现性与长期兼容；禁止再把门面当「分配器博物馆」。

---

## 1. 规则

| 规则 | 含义 |
|------|------|
| **允许** | Tier-0 默认路径 + 已文档化的 Tier-1/2 策略/诊断/池 |
| **禁止新增** | 向 `nextpas.core.mem` uses 增加未列入本文件的单元 |
| **Tier-3** | 不得进入门面；调用方 `uses` 子单元，无兼容承诺 |
| **删除** | 本批不大规模删除既有 Tier-2 re-export（兼容）；删除 = 显式 breaking |

---

## 2. Tier 定义（产品视角）

| Tier | 用途 | 发现路径 |
|------|------|----------|
| **0** | 热堆、过程式 API、Arena、固定池、统计 | 门面 + README 决策树 |
| **1** | 策略包装 / 诊断注入（tracking、sentinel、stats…） | 门面或子单元 |
| **2** | 生产可选后端 / 专用池（mimalloc、mmap、slab concurrent…） | 门面或子单元 |
| **3 Experimental** | 预测、NUMA、replay、研究型分配器 | **仅**子单元 |

### Tier-3 黑名单（不得出现在 `nextpas.core.mem` uses）

```text
nextpas.core.mem.allocator.prediction
nextpas.core.mem.allocator.numa
nextpas.core.mem.allocator.replay
nextpas.core.mem.allocator.huge_page
nextpas.core.mem.allocator.watermark
nextpas.core.mem.allocator.sliding
nextpas.core.mem.allocator.thread_cache
nextpas.core.mem.allocator.mapped_file
nextpas.core.mem.allocator.arena2
nextpas.core.mem.allocator.arena_group
nextpas.core.mem.allocator.bitmap
nextpas.core.mem.allocator.bump
nextpas.core.mem.allocator.cascade
nextpas.core.mem.allocator.coalesce
nextpas.core.mem.allocator.compact
nextpas.core.mem.allocator.cow
nextpas.core.mem.allocator.dual
nextpas.core.mem.allocator.freelist
nextpas.core.mem.allocator.group
nextpas.core.mem.allocator.page
nextpas.core.mem.allocator.pool2
nextpas.core.mem.allocator.prefix
nextpas.core.mem.allocator.size_class
nextpas.core.mem.allocator.slab
nextpas.core.mem.allocator.stack
nextpas.core.mem.blockpool.growable
```

（完整实验清单以源码树 `core/src/nextpas.core.mem.allocator.*` 为准；上表为门面冻结时已确认出门面者。）

---

## 3. 默认产品表面（必须可从门面发现）

| 表面 | API |
|------|-----|
| 热堆 | `DefaultHeap` / `GetMem` / `FreeMem(ptr,size)` / `TryBlockSize` |
| 注入 | `DefaultAllocator` / `ResolveAllocator` / `FreeMemOf` / `TryFreeMemOf` |
| Arena | `CreateDefaultArena` / `CreateArenaAllocator` / `CreateVirtualArenaAllocator` |
| 诊断 | `GetMemStats` / `FormatMemStats` / `IsMemHeapDebugEnabled` / `IsMemHeapSafetyEnabled` / `IsMemArenaStrictEnabled` / `MemDebugCoverageGap` |
| 错误 | `FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg` / `EAllocError` |
| Try* | `TryGetMem` / `TryFreeMem` / `TryArenaAlloc` … |

---

## 4. 变更纪律

1. 向门面 **新增** uses = 更新本文件 + README「门面与 Tier」+ `check_usability_docs.sh`。
2. 把 Tier-3 拉进门面 = **禁止**（source-contract 失败）。
3. 收紧（删除）既有 Tier-1/2 re-export = 独立 breaking slice，不混入可用性修修补补。

相关：[README.md](README.md) · [API-GUIDE.md](API-GUIDE.md) · [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) · [USABILITY-FIX-PLAN.md](USABILITY-FIX-PLAN.md)
