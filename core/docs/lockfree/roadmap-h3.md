# Atomic & Lockfree — Horizon-3 章程

> **状态**: **H3-2 COMPLETE**（2026-07-17）— H3-0e + H3-1 + **H3-2 done**；H3-3…H3-4 **未授权**
> **Owner**: atomic-lockfree lane（`.worktrees/atomic-lockfree`）
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）+ consumer `async.loop` + T2 bag/multimap
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
| **H3 Wave-1** | H3-0e + H3-1（async Post → T1 MPSC） | **DONE** — main `710ddd7ab` |
| **H3-2** | T2 Guarded 生产子集（bag + multimap） | **DONE** — CONTRACT §0.3 |
| **H3-3…H3-4** | consumer 门 / 证据卫生 | **未授权** |

**R8 保持研究线**，不因 H3 章程而自动生产化。

---

## 1. 阶段表

| 阶段 | 名称 | 交付 | 状态 |
|------|------|------|------|
| **H3-0** | 章程与状态 | 本文件 + READY 指针 | **done** |
| **H3-0e** | Wave-1 状态切换 | READY → H3 in progress → Maintenance | **done** |
| **H3-1** | 跨模块真实接入 | **async.loop Post → T1 MPSC**；`Close → discard → Free`；loop 外 join producers | **done** (`8d99b07ab` / land `710ddd7ab`) |
| **H3-2** | T2 Guarded 生产契约子集 | **bag + multimap**：Close / managed / progress；**不进**默认门面 | **done** |
| **H3-3** | Consumer regression 门 | focused gate 或 source-contract，覆盖跨模块消费者 | **未授权** |
| **H3-4** | 证据与文档卫生 | bench envelope 同步；api-ref 与契约对齐 | **未授权** |

```
H2 complete / Maintenance
         │
         ▼
H3-0  章程 landed
         │
         ▼
H3-0e + H3-1  Wave-1  ── DONE（async.loop → lockfree.mpsc）
         │
         ▼
H3-2  T2 Guarded subset  ── DONE（bag + multimap, CONTRACT §0.3）
         │
         ▼
Maintenance  ── 当前默认
         │
         ▼
H3-3 … H3-4  ── 未授权
```

### H3-1 选型（Wave-1 锁定 / 已交付）

| 项 | 选择 |
|----|------|
| 接入点 | `TAsyncLoop` 跨线程 `Post` / `DrainPending` |
| 原语 | `specialize TMpscQueueImpl<TAsyncPendingItem>`（`lockfree.mpsc`） |
| Close 语义 | `FPendingReady := False` → `Close` → discard without fire → `Free` |
| 不做 | 替换 poller/timer；有界 Channel；thread.pool.worksteal 全量改写 |
| 依赖方向 | async → lockfree；**禁止** lockfree → async |

### H3-1 证据

| 面 | 路径 / SHA |
|----|------------|
| 实现 | `core/src/nextpas.core.async.loop.pas` |
| 测试 | `core/tests/nextpas.core.async/test_async` — `AsyncLoopPendingQueueMpscSourceContract` |
| 审计 | [`consumer-audit.md`](consumer-audit.md) §2.1 |
| Land | path-limited `landing/atomic-lockfree-h3-1-20260717` → main `710ddd7ab` |
| Feat | `8d99b07ab` feat(async,lockfree): H3-1 TAsyncLoop Post uses T1 MPSC |

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

1. **H3-1 与 H3-2 已交付**。后续 H3-3…H3-4 **仍须单独授权**，不因 H3-2 完成而自动推进。
2. 启动 H3-3+ 必须有 **单独授权**（总控或用户显式指令），并建议：
   - path-limited land；`verify-t1` 保绿；跨模块须额外 consumer 验证
3. 在未授权前，默认继续 **Maintenance**（见 [`READY.md`](READY.md) post-H3-2 checklist）。
4. 重大变更（Closed、默认门面 T2、R8 生产化、删 legacy）仍属 stop-and-ask，不因 H3 编号自动放行。

---

## 4. 与现有文档关系

| 文档 | 角色 |
|------|------|
| [`READY.md`](READY.md) | 状态入口；**Maintenance**；H3-1 + H3-2 done |
| [`roadmap.md`](roadmap.md) | R 线记录 + Maintenance；指向 H3 |
| [`roadmap-h2.md`](roadmap-h2.md) | H2 完成记录；successor 指针 → 本文件 |
| [`r8-research-status.md`](r8-research-status.md) | R8 诚实研究状态（非 H3 交付） |
| [`CONTRACT.md`](CONTRACT.md) | 契约真相；**§0.3 = H3-2 bag/multimap** |
| [`consumer-audit.md`](consumer-audit.md) | H3-1 async.loop 消费者已登记 |

---

## 5. 验收

### H3-0 / 章程 — **done**

| 项 | 内容 |
|----|------|
| **交付** | 本文件入仓；READY / roadmap 指向 H3 |
| **通过标准** | 边界与非目标固定；R8 不静默升级 |

### H3-1 / Wave-1 — **done**

| 项 | 内容 |
|----|------|
| **交付** | `async.loop` Post 队列 = T1 MPSC；Close discard；source-contract 测试；consumer-audit |
| **不做** | poller/timer 替换；T2 升门面；R8 生产化 |
| **通过标准** | path-limited land 到 main；`verify-t1` + async focused gate 绿（land 时证据）；文档一致写 **Wave-1 complete / Maintenance** |

### H3-2 / T2 Guarded 子集 — **done**

| 项 | 内容 |
|----|------|
| **交付** | **bag + multimap** 统一生产契约：progress 诚实、managed 守卫、Close 生命周期；CONTRACT §0.3；单元头注释；测试 H3-2 source-contract pins；multimap `Destroy` 先 `Close` |
| **不做** | T2 进默认门面；全量 T2 契约化；算法重写；改 T1 Closed 语义；R8 生产化 |
| **通过标准** | bag/multimap focused tests 绿；门面无 bag/multimap re-export；READY/roadmap 写 **H3-2 done / Maintenance**；H3-3… 仍未授权 |
