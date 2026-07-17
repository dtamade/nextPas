# Atomic & Lockfree — Horizon-3 章程

> **状态**: **H3 charter only**（2026-07-17）— **NOT in progress** / **NOT auto-started**
> **Owner**: atomic-lockfree lane（或 successor worktree）
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）
> **本文件仅是 H3 章程**。不授权 H3-1… 实现；需单独授权后方可开工。
> 冲突时以 **CONTRACT + [`roadmap.md`](roadmap.md) + 本文件** 为准；状态入口见 [`READY.md`](READY.md)。

---

## 0. 为何是 H3（而非 R9）

主线 R0–R7 + RC Ready + **H2 complete** 已合入；默认执行主线为 **Maintenance**。
后续若做生产向工作（跨模块真实接入、T2 生产契约子集、consumer regression 门），需要新的编号 horizon，**不叫 R9**。

| 编号族 | 含义 | 当前 |
|--------|------|------|
| **R0–R7 / RC** | 已完成主线 + Ready close-out | DONE |
| **H2-0…H2-6** | 一致性 / 证据 / 消费者 | DONE — [`roadmap-h2.md`](roadmap-h2.md) |
| **R8** | NUMA / TSX / TLA+ **研究** | opt-in；诚实状态见 [`r8-research-status.md`](r8-research-status.md) |
| **H3-0…H3-4** | 生产向下一 horizon | **仅章程**；未开工 |

**R8 保持研究线**，不因 H3 章程而自动生产化。

---

## 1. 阶段表

| 阶段 | 名称 | 交付 | 状态 |
|------|------|------|------|
| **H3-0** | 章程与状态 | 本文件 + READY 指针 | **charter done when landed**（文档；非执行授权） |
| **H3-1** | 跨模块真实接入 | async/thread/net 等**已有**路径上的最小 T1 队列/Channel；`Close → join → Free` | **未授权** |
| **H3-2** | T2 Guarded 生产契约子集 | 1–2 个类型：Close / managed / progress 文档与契约；**不进**默认门面 | **未授权** |
| **H3-3** | Consumer regression 门 | focused gate 或 source-contract，覆盖跨模块消费者 | **未授权** |
| **H3-4** | 证据与文档卫生 | bench envelope 同步；api-ref 与契约对齐 | **未授权** |

```
H2 complete / Maintenance  ── 当前默认
         │
         │  (opt-in docs) R8 research pack close-out
         │
         ▼
H3-0  章程（本文件）── charter only；NOT auto-start
         │
         │  ★ 需单独授权 ★
         ▼
H3-1 … H3-4  ── 未开工
```

---

## 2. 全局非目标

- **默认推进 R8 生产化**（NUMA/RTM/formal 升默认门面或 T1）
- **全量 T2 算法重写**
- **删除 legacy CAS** / **改变 Closed 语义**
- **发明 R9**
- 无 bench 信封的绝对 Mops 营销数字
- 把 T2 升为默认 `uses nextpas.core.lockfree` 门面

---

## 3. 执行策略（硬规则）

1. **本章程不授权 H3-1…H3-4 实现**。仅固定边界、阶段名与非目标。
2. 启动 H3-1 必须有 **单独授权**（总控或用户显式指令），并建议：
   - 新 worktree：`atomic-lockfree-h3` 或 `codex/core-lockfree-h3`
   - path-limited land；`verify-t1` 保绿；跨模块须额外 consumer 验证
3. 在未授权前，默认继续 **Maintenance**（见 [`READY.md`](READY.md) Post-H2 checklist）。
4. 重大变更（Closed、默认门面 T2、R8 生产化、删 legacy）仍属 stop-and-ask，不因 H3 编号自动放行。

---

## 4. 与现有文档关系

| 文档 | 角色 |
|------|------|
| [`READY.md`](READY.md) | 状态入口；**H3 not started** |
| [`roadmap.md`](roadmap.md) | R 线记录 + Maintenance；指向 H3 charter |
| [`roadmap-h2.md`](roadmap-h2.md) | H2 完成记录；successor 指针 → 本文件 |
| [`r8-research-status.md`](r8-research-status.md) | R8 诚实研究状态（非 H3 交付） |
| [`CONTRACT.md`](CONTRACT.md) | 契约真相；H3-2 若开工须先改此处 |

---

## 5. 验收（仅 H3-0 / 章程）

| 项 | 内容 |
|----|------|
| **交付** | 本文件入仓；READY / roadmap 指向 H3 charter only |
| **不做** | 生产 Pascal API 变更；跨模块 wiring；T2 升门面 |
| **通过标准** | 文档一致写明 **H3 not started** / **not auto-started**；Maintenance 仍为默认主线 |
