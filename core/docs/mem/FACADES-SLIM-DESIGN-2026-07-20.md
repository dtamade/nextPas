# 门面瘦身设计（F2 · 设计 only）

**日期**: 2026-07-20
**状态**: **Executed batch 1** — 门面 re-export 已收紧（F3）
**执行**: F3 path-limited slice · interface uses **65 → 41**
**关联**: [FACADES-SURFACE.md](FACADES-SURFACE.md) · [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3 · [ROADMAP.md](ROADMAP.md) §4c

---

## 1. 问题

- 门面 `uses` 约 **65** 单元（含 base/utils），产品入口仍像「分配器目录」。
- P-a/P-b 已删 Tier-3 源文件，但 **Tier-1/2 包装器仍几乎全部 re-export**。
- 2026-07-20 扫 `core/src` **非 mem** 直接符号引用：多数诊断包装器 **0** 外部文件；真正有外部引用的主要是 **memory_map / mapped_slab / ring** 等映射族。

目标（Go/Rust 感）：`uses nextpas.core.mem` 默认只拿到 **热堆 + Arena + 错误 + 统计 + 常用池**；冷门包装器 `uses` 子单元。

---

## 2. 爆炸半径

| 指标 | 约计 |
|------|------|
| `uses nextpas.core.mem` 直连（粗） | ~10–80 文件（解析方式敏感） |
| 门面 uses 单元数 | **65** |
| 非 mem 对 logging/sampling/debug_alloc/hotswap/… | **0** |
| 非 mem 对 tracking/sentinel/guard/… | **0**（DEBUG 链在 mem 内部） |
| 非 mem 对 memory_map / mapped_slab / ring | **有**（io.mapped.* / lockfree / tls） |

**结论**: 移出 **纯诊断包装器** re-export 爆炸半径 **低**（测试会破，产品源几乎不破）。
移出 **mapped/ring** 会伤 io/tls — **不要** 第一批动。

---

## 3. 分层提案

### Tier-0 — 必须留在门面（发现面）

| 域 | 单元 / 符号 |
|----|-------------|
| 契约 | `intf` `IAllocator` / Traits；`arena.intf` `IArena` |
| 错误 | `error` EAllocError / FormatAllocErrorMsg |
| 默认双轨 | `default` DefaultHeap / DefaultAllocator / GetMem* / FreeMem* / Try* / GetMemStats |
| DEBUG 开关 | `debug_wrap` 解析入口（可只 re-export 函数，不 re-export 全部包装类型） |
| Arena 工厂 | local / chunked / virtual + Create* |
| 安全 | `secure` |
| 基础 | `base` 对齐 helper |

### Tier-1 — 建议保留（生产诊断/注入）

| 单元 | 理由 |
|------|------|
| tracking / leak_check / sentinel / guard | DEBUG 与测试注入 |
| fallback / rtl / crt / foundation / growing / growing_ia | 后端与默认根 |
| pool.fixed / fixed_slab / sizeclass / blockpool | 高频固定池 |
| allocator.arena | Arena→IAllocator |

### Tier-2 — F3 批 1 建议移出门面（改子单元 uses）

**零外部 prod 引用、纯包装/实验感**：

```text
allocator.logging
allocator.sampling
allocator.debug_alloc
allocator.hotswap
allocator.counting
allocator.zeroed
allocator.fail
allocator.scoped
allocator.batch
allocator.callback
allocator.aligned
allocator.bounded
allocator.stats          # 注意：TStatsAllocator 可能被 DEBUG stats token 测试用 — 测例改 uses
allocator.leak_report
allocator.thread_safe
allocator.pool           # 与 pool.* 产品池区分；确认无 facade-only 类型依赖
budget / oom             # 若仅测试用
pool.slab.concurrent / pool.slab.sharded
blockpool.concurrent / blockpool.sharded   # 可第二批
stack_pool
```

**勿在批 1 移出**（有外部引用）：

```text
memory_map
mapped_slab_pool
ring_buffer          # 名称碰撞多，至少 io/lockfree/tls 有 ring 概念
mimalloc / mmap      # 生产可选后端；可第二批「保留但文档标可选」
```

### Tier-3 — 已删 / 禁止

P-a + P-b 名单；`blockpool.growable` 保留源、**不进门面**。

---

## 4. F3 执行记录（批 1 · done）

1. 从 `nextpas.core.mem.pas` interface `uses` + type re-export 去掉 §3 Tier-2 批 1 名单（含 concurrent/sharded/stack_pool/budget/oom）
2. `CreatePoolAllocator` 保留；`pool.allocator` 仅 implementation uses
3. 更新 [FACADES-SURFACE.md](FACADES-SURFACE.md)
4. `test_mem` 收窄为门面仍 re-export 的烟测；`test_arena_prop` 直接 uses `blockpool.sharded`
5. 验证：`test_mem` / `test_debug_wrap` / `lane-focused` / hygiene
6. **Breaking（re-export only）**：源文件未删

### 批 2（可选，未做）

- mimalloc/mmap 是否降为「仅子单元」
- 防回潮 source-contract（门面不得 uses demoted 名单）

### 禁止（仍有效）

- 与功能修复混 commit
- 一次移出 mapped/ring

---

## 5. 验收（F3 批 1）

| 项 | 标准 | 结果 |
|----|------|------|
| 门面 uses 数 | ≤ 42（目标 ~40） | **41** |
| 产品 `core/src` 非 mem | 无 demoted 类型引用 | **0 hits** |
| DEBUG 链 | `NEXTPAS_MEM_DEBUG` 不变 | debug_wrap 直接 uses 子单元 |
| 文档 | FACADES + ROADMAP 同步 | done |

---

## 6. 结论

- F2 设计 + **F3 批 1 已执行**。
- 调用冷门包装器 / 并发池：`uses nextpas.core.mem.<子单元>`。
