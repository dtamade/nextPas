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

**仍保留且禁止进门面**：

```text
nextpas.core.mem.blockpool.growable   # used by blockpool.sharded; not facade
```

**P-a 已删除（2026-07-19）** — 不得复活：

```text
allocator.bump / dual / freelist / thread_cache / size_class / slab
allocator.arena2 / arena_group / page / stack
```

**P-b 已删除（2026-07-19，E5）** — 不得复活：

```text
allocator.prediction / numa / replay / huge_page / watermark / sliding
allocator.mapped_file / bitmap / cascade / coalesce / compact / cow
allocator.group / pool2 / prefix
```

（完整清单以源码树 `core/src/nextpas.core.mem.allocator.*` 为准；guardrails 仍 forbid 已删名进门面。）

---

## 3. 默认产品表面（必须可从门面发现）

| 表面 | API |
|------|-----|
| 热堆 | `DefaultHeap` / `GetMem` / `FreeMem(ptr,size)` / `TryBlockSize` |
| 注入 | `DefaultAllocator` / `ResolveAllocator` / `FreeMemOf` / `TryFreeMemOf` / `ReallocMemOf` / `TryReallocMemOf` |
| Arena | `CreateDefaultArena` / `CreateArenaAllocator` / `CreateVirtualArenaAllocator` |
| 诊断 | `GetMemStats` / `FormatMemStats` / `FormatMemDebugProfile` / `IsMemHeapDebugEnabled` / `IsMemHeapSafetyEnabled` / `IsMemArenaStrictEnabled` / `MemDebugCoverageGap` |
| 错误 | `FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg` / `EAllocError` |
| Try* | `TryGetMem` / `TryFreeMem` / `TryArenaAlloc` … |

---

## 4. 变更纪律

1. 向门面 **新增** uses = 更新本文件 + README「门面与 Tier」+ `check_usability_docs.sh`。
2. 把 Tier-3 拉进门面 = **禁止**（source-contract 失败）。
3. 收紧（删除）既有 Tier-1/2 re-export = 独立 breaking slice，不混入可用性修修补补。

相关：[README.md](README.md) · [API-GUIDE.md](API-GUIDE.md) · [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) · [USABILITY-FIX-PLAN.md](USABILITY-FIX-PLAN.md)
