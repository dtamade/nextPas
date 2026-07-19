# Atomic & Lockfree — Horizon-2 执行章程（权威）

> **状态**: **H2 complete**（2026-07-17）· **Owner**: atomic-lockfree lane
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）
> **本文件是 Horizon-2 章程与完成记录**。R0–R7 + RC Ready 已合入；H2-0…H2-6 已 path-limited land；R8 仍为 opt-in 研究，不进默认主线。
> 冲突时以 **CONTRACT + 本文件 + [`roadmap.md`](roadmap.md)** 为准；状态入口见 [`READY.md`](READY.md)。

---

## 0. 为何开 H2（而非 R9）

主线 R0–R7 与 Ready close-out 已完成，T1 / atomic 为 **Ready-for-consumer**。
后续工作不是修 Closed 语义或扩默认门面，而是 **一致性补齐、成熟度诚实、证据制度、真实消费**。
因此新开 **Horizon-2（H2-0…H2-6）** 编号，**不叫 R9**。

| 编号族 | 含义 |
|--------|------|
| **R0–R7 / RC** | 已完成主线 + Ready close-out |
| **R8** | NUMA / TSX / TLA+ 研究（opt-in，默认不推进） |
| **H2-0…H2-6** | **已完成**（一致性 / 证据 / 消费者） |

---

## 1. 已锁定决策（2026-07-17）

| # | 决策 | 结果 |
|---|------|------|
| **D1** | 开 Horizon-2 主线（H2-0…H2-6），不叫 R9 | **锁定 · DONE** |
| **D2** | path-limited land + push 到 `origin/main` | **已授权 · 已执行** |
| **D3** | 重大变更先停：改 Closed 语义、扩默认门面 T2、R8 进生产、删 legacy CAS | 先改 roadmap，再问 |
| **D4** | 不默认做 R8（NUMA/TSX/TLA+） | **锁定** |
| **D5** | 小步 commit + focused verify；自主跑完 H2；阶段边界只汇报状态变化 | **锁定 · DONE** |

---

## 2. 总览

```
R0–R7 + RC Ready  ── DONE ──►  Maintenance baseline
                               │
                               ▼
H2-0  章程与状态切换           docs          DONE
H2-1  Deque Try*Ex 补齐        T1 一致性     DONE
H2-2  T2 maturity tiers        文档分档      DONE
H2-3  atomic preferred path    首选路径      DONE
H2-4  bench 证据制度           可复现信封    DONE
H2-5  formal / stress 加深     证据加深      DONE
H2-6  真实消费者               Close→join→Free DONE
                               │
                               ▼
H2 close-out  READY/roadmap + archive tag  DONE
                               │
                               ▼
Maintenance  （默认） / R8 research（opt-in）
```

| 阶段 | 名称 | 依赖 | 默认推进 |
|------|------|------|----------|
| **H2-0** | 章程与状态切换 | RC Ready | **done** |
| **H2-1** | Deque Try\*Ex 补齐 | H2-0 | **done** |
| **H2-2** | T2 maturity tiers | H2-0 | **done** |
| **H2-3** | atomic preferred path | H2-0 | **done** |
| **H2-4** | bench 证据制度 | H2-0 | **done** |
| **H2-5** | formal / stress 加深 | H2-0；建议 H2-1 后 | **done** |
| **H2-6** | 真实消费者 | H2-1（T1 API 齐） | **done** |
| **R8** | 研究线 | 独立 | **否** |

---

## 3. 分阶段详情

### H2-0 — 章程与状态切换 — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | 把执行状态从 Ready/Maintenance 切到 **H2 in progress**，并写清 H2 边界 |
| **交付** | 本文件；更新 [`roadmap.md`](roadmap.md)、[`READY.md`](READY.md) |
| **不做** | 生产代码 / 契约语义变更 |
| **验收** | 文档一致；path-limited land + push |
| **依赖** | R0–R7 + RC Ready |
| **证据** | `03086c0c3` · `archive/atomic-lockfree-h2-0-landed-20260717` |

### H2-1 — Deque Try\*Ex 补齐（T1 一致性） — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | T1 Deque 与 R4 rings/stack/channel 对齐，可选诊断 `Try*Ex` + `TLockFreeTryError` |
| **交付** | `TWorkStealingDeque`：`TryPushEx` / `TryPopEx` / `TryStealEx`；测试 success / full\|empty / closed；CONTRACT §1.4 表 + api-reference |
| **诚实约束** | `deque_lf` 为 **spin-lock + `TDequeResult`**，progress 模型写清；**不假装 wait-free / lock-free** |
| **不做** | 改 Closed 语义；把 `deque_lf` 升为默认门面；重写算法 |
| **验收** | `make -C core/tests/nextpas.core.lockfree verify-t1` 绿；文档表更新；land + push |
| **依赖** | H2-0；R3 的 `TLockFreeTryError` |
| **证据** | `042145f1e` |

### H2-2 — T2 maturity tiers 文档化 — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | 给 T2 容器分档（如 Available / Guarded / Experimental），降低误用 |
| **交付** | CONTRACT / README / selection-guide 分档表 |
| **不做** | 把 T2 **升为默认门面**；统一重写 T2 算法 |
| **验收** | 文档可检索、与现状一致；land + push |
| **依赖** | H2-0 |
| **证据** | 文档合入 H2-1 land 表面（`042145f1e` 一带 CONTRACT/README/selection-guide）；无独立生产代码变更 |

### H2-3 — atomic preferred path — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | 强化首选 `atomic_*` / `TAtomic*`；legacy CAS 保留但标明非首选 |
| **交付** | atomic CONTRACT §1.4 与 consumer-audit 脚注对齐；测试/文档标明非首选 |
| **不做** | **删除** legacy CAS API |
| **验收** | 首选路径文档清晰；land + push |
| **依赖** | H2-0；R7 基线 |
| **证据** | `0b023f687` |

### H2-4 — bench 证据制度 — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | 可复现 bench 信封（平台 / 线程 / 构建 / 热身 / 统计） |
| **交付** | [`bench-envelope.md`](bench-envelope.md) + `scripts/print-bench-envelope.sh` + bench Makefile 目标 |
| **禁止** | **无信封绝对 Mops 营销数字** |
| **不做** | 对外宣称“打败 X 库”而无信封 |
| **验收** | 信封模板可复现；land + push |
| **依赖** | H2-0 |
| **证据** | `0e1b86268` |

### H2-5 — formal / stress 加深 — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | 扩展 stress 场景或 TLA 覆盖；仅加深证据 |
| **交付** | Channel Close→join→Free stress；formal 模型表记为研究证据 |
| **不做** | 污染 T1 契约；把研究模型塞进默认门面 |
| **验收** | `verify-t1` + 相关 stress 绿或已知限制入 CONTRACT；land + push |
| **依赖** | H2-0；建议 H2-1 后 |
| **证据** | `bce90f2cb` |

### H2-6 — 真实消费者 — **DONE**

| 项 | 内容 |
|----|------|
| **目标** | core 内最小真实 consumer，证明 T1 `Close → join → Free` 可用 |
| **交付** | `core/examples/nextpas.core.lockfree/t1_close_join_free/`；更新 [`consumer-audit.md`](consumer-audit.md) |
| **不做** | 无必要的跨模块大改；跨模块须说明原因与额外验证 |
| **验收** | 消费者可编译运行；审计文档更新；land + push |
| **依赖** | H2-1（T1 诊断 API 齐） |
| **证据** | `d93780c27` · `archive/atomic-lockfree-h2-complete-20260717` |

### H2 close-out — **DONE**

| 项 | 内容 |
|----|------|
| **交付** | READY/roadmap 标记 **H2 complete**；archive tags |
| **验收** | Ready 报告：分支、worktree、HEAD、文件清单、验证证据、merge 建议 |
| **证据** | `archive/atomic-lockfree-h2-closeout-20260717`；状态见 [`READY.md`](READY.md) |

---

## 4. 标准验证门

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make hygiene
git diff --check
```

Landing：path-limited candidate + `make landing-check` + ff-only main + push（H2 期间已获用户授权）。

---

## 5. 全局非目标（H2 继承 → Maintenance）

- 宣称「全部 lock-free」或无信封绝对 Mops 营销数字
- 默认推进 R8 / 扩默认门面 T2 / 删 legacy CAS / 改 Closed 语义（均属 D3 重大变更）
- raw merge 长期 lane；未授权 force-push
- 借机重写 T2 算法全集

---

## 6. 工作方式（历史；H2 已完成）

1. **顺序**：H2-0 → H2-1 → … → H2-6 → close-out（H2-2/3/4 在 H2-0 后可与 H2-1 后序交错）。
2. **小步**：每阶段小步 commit + focused verify；阶段边界汇报状态变化。
3. **文档**：契约先 CONTRACT，再 README / selection-guide / api-reference，最后更新本文件「进度」。
4. **重大变更**：触碰 D3 先停、改本文件与 roadmap，再问。

---

## 7. 进度表 — **全部 done**

| 阶段 | 状态 | 证据 / 备注 |
|------|------|-------------|
| H2-0 | **done** | `03086c0c3` · `archive/atomic-lockfree-h2-0-landed-20260717` |
| H2-1 | **done** | `042145f1e` · Deque Try\*Ex + tests + CONTRACT |
| H2-2 | **done** | T2 maturity tiers 文档（合入 H2-1 land 表面） |
| H2-3 | **done** | `0b023f687` · atomic preferred path |
| H2-4 | **done** | `0e1b86268` · bench-envelope + print script |
| H2-5 | **done** | `bce90f2cb` · stress Channel Close-join-Free |
| H2-6 | **done** | `d93780c27` · `t1_close_join_free` + `archive/atomic-lockfree-h2-complete-20260717` |
| H2 close-out | **done** | READY/roadmap → H2 complete · `archive/atomic-lockfree-h2-closeout-20260717` |

---

## 8. 与 R 线文档关系

| 文档 | 角色 |
|------|------|
| [`roadmap.md`](roadmap.md) | R0–R7 完成记录 + 指向 H2 complete / Maintenance |
| **`roadmap-h2.md`（本文件）** | **H2 章程与完成记录** |
| [`READY.md`](READY.md) | Ready / H2 complete / Maintenance 状态入口 |
| [`CONTRACT.md`](CONTRACT.md) | 契约真相 |
| [`long-term-roadmap.md`](long-term-roadmap.md) | = R8 研究线（历史计划） |
| [`r8-research-status.md`](r8-research-status.md) | R8 诚实状态（opt-in） |
| [`roadmap-h3.md`](roadmap-h3.md) | **successor 章程 only**（H3；**未开工 / 不自动执行**） |
| phase4–8 / optimization-* | 历史归档 |

> **Successor 脚注**：H2 complete 之后的下一编号 horizon 是 **H3**（[`roadmap-h3.md`](roadmap-h3.md)），**仅章程**，不是本文件的延续执行，也**不叫 R9**。默认主线仍为 Maintenance；H3-1… 需单独授权。
