# Atomic & Lockfree — Horizon-3 章程

> **状态**: **H3 COMPLETE**（2026-07-19）— H3-0e + H3-1…**H3-5 done** → **Maintenance**
> **Owner**: atomic-lockfree lane（`.worktrees/atomic-lockfree`）
> **范围**: atomic + lockfree + async.loop + bag/multimap + consumer gate + 证据卫生 + thread worksteal
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
| **H3-3** | consumer regression 门 | **DONE** — `verify-h3-consumers` |
| **H3-4** | 证据与文档卫生 | **DONE** — 2026-07-19 |
| **H3-5** | thread worksteal 接入 | **DONE** — §6 选项 A；2026-07-19 |

**R8 保持研究线**，不因 H3 章程而自动生产化。

---

## 1. 阶段表

| 阶段 | 名称 | 交付 | 状态 |
|------|------|------|------|
| **H3-0** | 章程与状态 | 本文件 + READY 指针 | **done** |
| **H3-0e** | Wave-1 状态切换 | READY → H3 in progress → Maintenance | **done** |
| **H3-1** | 跨模块真实接入 | **async.loop Post → T1 MPSC**；`Close → discard → Free`；loop 外 join producers | **done** (`8d99b07ab` / land `710ddd7ab`) |
| **H3-2** | T2 Guarded 生产契约子集 | **bag + multimap**：Close / managed / progress；**不进**默认门面 | **done** |
| **H3-3** | Consumer regression 门 | `verify-h3-consumers`：async + bag + multimap + t1_close_join_free | **done** |
| **H3-4** | 证据与文档卫生 | bench envelope 同步；api-ref 与契约对齐 | **done** |
| **H3-5** | thread worksteal 接入 | 见 §6 选项 A | **done** |

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
H3-3  Consumer regression gate  ── DONE（verify-h3-consumers）
         │
         ▼
H3-4  证据 / api-ref 卫生  ── DONE（2026-07-19）
         │
         ▼
H3-5  thread worksteal → T1 deque  ── DONE（2026-07-19）
         │
         ▼
Maintenance  ── 当前默认（H3 生产序列完成）
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

### H3-3 选型（Consumer regression 门 / 已交付）

| 项 | 选择 |
|----|------|
| 门入口 | `make -C core/tests/nextpas.core.lockfree verify-h3-consumers` |
| 覆盖 | `test_async`（H3-1 source-contract + 行为）、`test_lockfree_bag`、`test_lockfree_multimap`、`t1_close_join_free` 示例 |
| 与 verify-t1 关系 | **不替代** `verify-t1`；Maintenance 推荐 **两者都跑** |
| 日志 | `core/build/verify-lockfree/verify-h3-consumers.log` |
| 不做 | 改 Closed 语义；扩 T2 门面；接 thread/http；R8 生产化 |

---

## 2. 全局非目标

- **默认推进 R8 生产化**（NUMA/RTM/formal 升默认门面或 T1）
- **全量 T2 算法重写**
- **删除 legacy CAS** / **改变 Closed 语义**
- **发明 R9**
- 无 bench 信封的绝对 Mops 营销数字
- 把 T2 升为默认 `uses nextpas.core.lockfree` 门面
- 未授权前 **自动**推进 H3-5 之外的新 horizon 实现

---

## 3. 执行策略（硬规则）

1. **H3-1…H3-5 已交付**。默认 **Maintenance**（见 [`READY.md`](READY.md) post-H3-5 checklist）。
2. 回归门：`verify-t1` + `verify-h3-consumers`；触碰 worksteal 时加 `test_worksteal`。
3. 重大变更（Closed、默认门面 T2、R8 生产化、删 legacy）仍属 stop-and-ask。
4. 新生产波次须新章程；**不 invent R9**。

---

## 4. 与现有文档关系

| 文档 | 角色 |
|------|------|
| [`READY.md`](READY.md) | 状态入口；**Maintenance**；H3-1…H3-5 done |
| [`roadmap.md`](roadmap.md) | R 线记录 + Maintenance；指向 H3 |
| [`roadmap-h2.md`](roadmap-h2.md) | H2 完成记录；successor 指针 → 本文件 |
| [`r8-research-status.md`](r8-research-status.md) | R8 诚实研究状态（非 H3 交付） |
| [`CONTRACT.md`](CONTRACT.md) | 契约真相；**§0.3 = H3-2 bag/multimap** |
| [`consumer-audit.md`](consumer-audit.md) | H3-1 async.loop + H3-3 门证据 |

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
| **通过标准** | bag/multimap focused tests 绿；门面无 bag/multimap re-export；READY/roadmap 写 **H3-2 done** |

### H3-3 / Consumer regression 门 — **done**

| 项 | 内容 |
|----|------|
| **交付** | `verify-h3-consumers` Makefile 目标；串联 async / bag / multimap / t1_close_join_free；READY / roadmap 状态切换；consumer-audit 登记门入口 |
| **不做** | 替换 `verify-t1`；新跨模块接入；H3-4 全量文档卫生；thread worksteal 改码 |
| **通过标准** | `make -C core/tests/nextpas.core.lockfree verify-h3-consumers` 绿；日志落 `core/build/verify-lockfree/verify-h3-consumers.log`；文档写 **H3-3 done / Maintenance** |

### H3-4 / 证据与 api-ref 卫生 — **done**

| 项 | 内容 |
|----|------|
| **交付** | 活跃入口（README / selection-guide）去掉无信封绝对 Mops；历史 comparison/optimization/phase 文档加 **historical only** 横幅；api-ref ZH bag/multimap 对齐 CONTRACT §0.3；EN 补 Stack/Deque/H3-2 指针；bench envelope 工具确认可用 |
| **不做** | 重跑全量跨语言对照并刷新所有历史数字；改生产语义；实施 H3-5 |
| **通过标准** | 活跃入口无无信封绝对倍数；api-ref 与 CONTRACT 关键面一致；`print-bench-envelope.sh` 可运行；READY 写 **H3-4 done** |

---

## 6. H3-5 — thread worksteal 接入（**done**）

> 选项 A 已实现（2026-07-19）。以下为交付规格与验收记录。

### 6.1 现状（审计 2026-07-18）

| 实现 | 路径 | 队列模型 | 线程模型 | 进度 |
|------|------|----------|----------|------|
| **lockfree.workstealing** | `nextpas.core.lockfree.workstealing` | 每 worker 一个 `TWorkStealingDeque`（真 lock-free owner/thief） | **不**自建 OS 线程；只提供 Submit/Steal/Close | lock-free deque + 轻量 owner spin |
| **thread.pool.worksteal** | `nextpas.core.thread.pool.worksteal` | 每 worker 固定数组环 + **全局 IMutex** | 自建 platform 线程 + CondVar | **lock-based**；SubmitBatch/SignalWorkers 已在 main |

关键差距：

1. **同名不同物**：两边都叫 `TWorkStealingPool`，API 与生命周期完全不同。
2. **thread 池未消费 T1 deque**：窃取在全局锁内改 Head/Tail/Count，不是 `TrySteal`。
3. **lockfree.workstealing 不跑 worker**：是调度原语，不是 `IThreadPool`。
4. **任务类型**：thread 用 managed `TThreadTask`（reference to procedure）；lockfree 用 unmanaged `procedure(AData: Pointer)` + Data 指针。T1 容器 **拒绝 managed 元素**，因此 **不能**把 `TThreadTask` 直接塞进 `TWorkStealingDeque<TThreadTask>`。

### 6.2 推荐接入策略（授权后执行）

| 选项 | 描述 | 评价 |
|------|------|------|
| **A（推荐）** | thread 池内部：每 worker 一个 `TWorkStealingDequeImpl<TQueuedTaskSlot>`，slot 存 **unmanaged 句柄**（指针到堆上任务描述 / 索引到 slot pool）；外层仍实现 `IThreadPool` | 保留公开 API；真正吃 T1 deque；符合 managed 纪律 |
| B | 把 `lockfree.workstealing` 包一层 `IThreadPool` adapter | 需补 OS 线程/停机/WaitAll；与现 thread 池功能重叠大 |
| C | 删除一侧 | 破坏面大；不作为首切片 |

### 6.3 硬约束（授权后仍适用）

- 依赖方向：`thread` → `lockfree`；**禁止** lockfree → thread
- 任务载荷：deque 元素必须 unmanaged；managed 闭包放在 **间接层**（slot pool / 堆节点 + 引用计数）
- 生命周期：`Shutdown/Close` → join workers → drain/Free deques；不得只靠 `Destroy`
- 单切片：只改 `thread.pool.worksteal` + 其 focused 测试；不顺手改 net/http
- 验证：`verify-t1` + `verify-h3-consumers` + `test_worksteal`（及现有 thread pool 门）
- 进度声明：线程池整体仍可标 **work-stealing concurrent**；deque 热路径才是 lock-free

### 6.4 非目标（H3-5）

- 不改 `thread.channel` 为 lockfree Channel（语义差异大，另开章程）
- 不把 `lockfree.workstealing` 升 T1 默认门面
- 不删除 legacy CAS
- 不做 R8 生产化

### 6.5 验收草案（授权后）

| 项 | 标准 |
|----|------|
| 实现 | `thread.pool.worksteal` 用 T1 deque（或经 unmanaged slot 间接） |
| 测试 | `test_worksteal` 绿；新增 source-contract：`uses nextpas.core.lockfree.deque` |
| 回归 | `verify-t1` + `verify-h3-consumers` 绿 |
| 文档 | consumer-audit 登记 thread 为跨模块消费者；READY 写 H3-5 done |

### 6.6 交付证据（2026-07-19）

| 项 | 路径 / 结果 |
|----|-------------|
| 实现 | `core/src/nextpas.core.thread.pool.worksteal.pas` — `TWorkStealingDequeImpl<TDequeSlot>` + 堆 `TTaskNode` |
| 测试 | `core/tests/nextpas.core.thread/test_worksteal` — 7 passed（含 H3-5 source-contract） |
| 审计 | [`consumer-audit.md`](consumer-audit.md) §2.6 |
| 依赖 | `thread` → `lockfree.deque` only |

**当前状态**：**done** → 回到 Maintenance。
