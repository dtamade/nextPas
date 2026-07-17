# Atomic & Lockfree — Horizon-2 执行章程（权威）

> **状态**: **H2 in progress**（2026-07-17）· **Owner**: atomic-lockfree lane
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）
> **本文件是 Horizon-2 推进主线**。R0–R7 + RC Ready 已合入；R8 仍为 opt-in 研究，不进默认主线。
> 冲突时以 **CONTRACT + 本文件 + [`roadmap.md`](roadmap.md)** 为准；Ready 入口见 [`READY.md`](READY.md)。

---

## 0. 为何开 H2（而非 R9）

主线 R0–R7 与 Ready close-out 已完成，T1 / atomic 为 **Ready-for-consumer**。
后续工作不是修 Closed 语义或扩默认门面，而是 **一致性补齐、成熟度诚实、证据制度、真实消费**。
因此新开 **Horizon-2（H2-0…H2-6）** 编号，**不叫 R9**。

| 编号族 | 含义 |
|--------|------|
| **R0–R7 / RC** | 已完成主线 + Ready close-out |
| **R8** | NUMA / TSX / TLA+ 研究（opt-in，默认不推进） |
| **H2-0…H2-6** | **当前执行主线** |

---

## 1. 已锁定决策（2026-07-17）

| # | 决策 | 结果 |
|---|------|------|
| **D1** | 开 Horizon-2 主线（H2-0…H2-6），不叫 R9 | **锁定** |
| **D2** | path-limited land + push 到 `origin/main` | **已授权**（重大变更除外） |
| **D3** | 重大变更先停：改 Closed 语义、扩默认门面 T2、R8 进生产、删 legacy CAS | 先改 roadmap，再问 |
| **D4** | 不默认做 R8（NUMA/TSX/TLA+） | **锁定** |
| **D5** | 小步 commit + focused verify；自主跑完 H2；阶段边界只汇报状态变化 | **锁定** |

---

## 2. 总览

```
R0–R7 + RC Ready  ── DONE ──►  Maintenance baseline
                               │
                               ▼
H2-0  章程与状态切换           docs
H2-1  Deque Try*Ex 补齐        T1 一致性
H2-2  T2 maturity tiers        文档分档（不升门面）
H2-3  atomic preferred path    首选路径强化（不删 API）
H2-4  bench 证据制度           可复现信封
H2-5  formal / stress 加深     证据加深，不污染 T1 契约
H2-6  真实消费者               Close→join→Free 证明
                               │
                               ▼
H2 close-out  READY/roadmap + archive tag
```

| 阶段 | 名称 | 依赖 | 默认推进 |
|------|------|------|----------|
| **H2-0** | 章程与状态切换 | RC Ready | **当前** |
| **H2-1** | Deque Try\*Ex 补齐 | H2-0 | 是 |
| **H2-2** | T2 maturity tiers | H2-0 | 是 |
| **H2-3** | atomic preferred path | H2-0 | 是 |
| **H2-4** | bench 证据制度 | H2-0 | 是 |
| **H2-5** | formal / stress 加深 | H2-0；建议 H2-1 后 | 是 |
| **H2-6** | 真实消费者 | H2-1（T1 API 齐） | 是 |
| **R8** | 研究线 | 独立 | **否** |

---

## 3. 分阶段详情

### H2-0 — 章程与状态切换

| 项 | 内容 |
|----|------|
| **目标** | 把执行状态从 Ready/Maintenance 切到 **H2 in progress**，并写清 H2 边界 |
| **交付** | 本文件；更新 [`roadmap.md`](roadmap.md)、[`READY.md`](READY.md) |
| **不做** | 生产代码 / 契约语义变更 |
| **验收** | 文档一致；path-limited land + push |
| **依赖** | R0–R7 + RC Ready |

### H2-1 — Deque Try\*Ex 补齐（T1 一致性）

| 项 | 内容 |
|----|------|
| **目标** | T1 Deque 与 R4 rings/stack/channel 对齐，可选诊断 `Try*Ex` + `TLockFreeTryError` |
| **交付** | `TWorkStealingDeque`：`TryPushEx` / `TryPopEx` / `TryStealEx`；测试 success / full\|empty / closed；CONTRACT §1.4 表 + api-reference |
| **诚实约束** | `deque_lf` 为 **spin-lock + `TDequeResult`**，progress 模型写清；**不假装 wait-free / lock-free** |
| **不做** | 改 Closed 语义；把 `deque_lf` 升为默认门面；重写算法 |
| **验收** | `make -C core/tests/nextpas.core.lockfree verify-t1` 绿；文档表更新；land + push |
| **依赖** | H2-0；R3 的 `TLockFreeTryError` |

### H2-2 — T2 maturity tiers 文档化

| 项 | 内容 |
|----|------|
| **目标** | 给 T2 容器分档（如 Available / Guarded / Experimental），降低误用 |
| **交付** | CONTRACT / README / selection-guide 分档表；必要时 source-contract |
| **不做** | 把 T2 **升为默认门面**；统一重写 T2 算法 |
| **验收** | 文档可检索、与现状一致；land + push |
| **依赖** | H2-0 |

### H2-3 — atomic preferred path

| 项 | 内容 |
|----|------|
| **目标** | 强化首选 `atomic_*` / `TAtomic*`；legacy CAS 保留但标明非首选 |
| **交付** | atomic CONTRACT §1.4 与 consumer-audit 脚注对齐；测试/文档标明非首选 |
| **不做** | **删除** legacy CAS API |
| **验收** | 首选路径文档清晰；land + push |
| **依赖** | H2-0；R7 基线 |

### H2-4 — bench 证据制度

| 项 | 内容 |
|----|------|
| **目标** | 可复现 bench 信封（平台 / 线程 / 构建 / 热身 / 统计） |
| **交付** | 模块 docs 或现有 bench 约定路径下的脚本/文档 |
| **禁止** | **无信封绝对 Mops 营销数字** |
| **不做** | 对外宣称“打败 X 库”而无信封 |
| **验收** | 信封模板可复现；land + push |
| **依赖** | H2-0 |

### H2-5 — formal / stress 加深

| 项 | 内容 |
|----|------|
| **目标** | 扩展 stress 场景或 TLA 覆盖；仅加深证据 |
| **交付** | 新增/加深 stress 或 formal 模型；失败则修 bug 或诚实记入 CONTRACT 已知限制 |
| **不做** | 污染 T1 契约；把研究模型塞进默认门面 |
| **验收** | `verify-t1` + 相关 stress 绿或已知限制入 CONTRACT；land + push |
| **依赖** | H2-0；建议 H2-1 后 |

### H2-6 — 真实消费者

| 项 | 内容 |
|----|------|
| **目标** | core 内最小真实 consumer，证明 T1 `Close → join → Free` 可用 |
| **交付** | async/thread/http 等已有路径优先的最小消费；更新 [`consumer-audit.md`](consumer-audit.md) |
| **不做** | 无必要的跨模块大改；跨模块须说明原因与额外验证 |
| **验收** | 消费者可编译运行；审计文档更新；land + push |
| **依赖** | H2-1（T1 诊断 API 齐） |

### H2 close-out

| 项 | 内容 |
|----|------|
| **交付** | READY/roadmap 标记 **H2 complete** 或诚实 **partial + 剩余**；archive tag（如 `archive/atomic-lockfree-h2-*-2026…`） |
| **验收** | Ready 报告：分支、worktree、HEAD、文件清单、验证证据、merge 建议 |

---

## 4. 标准验证门

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make hygiene
git diff --check
```

Landing：path-limited candidate + `make landing-check` + ff-only main + push（本 H2 已获用户授权；重大变更除外）。

---

## 5. 全局非目标（H2 继承）

- 宣称「全部 lock-free」或无信封绝对 Mops 营销数字
- 默认推进 R8 / 扩默认门面 T2 / 删 legacy CAS / 改 Closed 语义（均属 D3 重大变更）
- raw merge 长期 lane；未授权 force-push
- 借机重写 T2 算法全集

---

## 6. 工作方式

1. **顺序**：H2-0 → H2-1 → … → H2-6 → close-out（H2-2/3/4 在 H2-0 后可与 H2-1 后序交错，但默认按序）。
2. **小步**：每阶段小步 commit + focused verify；阶段边界汇报状态变化。
3. **文档**：契约先 CONTRACT，再 README / selection-guide / api-reference，最后更新本文件「进度」。
4. **重大变更**：触碰 D3 先停、改本文件与 roadmap，再问。

---

## 7. 进度表

| 阶段 | 状态 | 证据 / 备注 |
|------|------|-------------|
| H2-0 | **in progress** | 本文件 + READY/roadmap 切换 |
| H2-1 | pending | |
| H2-2 | pending | |
| H2-3 | pending | |
| H2-4 | pending | |
| H2-5 | pending | |
| H2-6 | pending | |
| H2 close-out | pending | |

---

## 8. 与 R 线文档关系

| 文档 | 角色 |
|------|------|
| [`roadmap.md`](roadmap.md) | R0–R7 完成记录 + 指向本 H2 主线 |
| **`roadmap-h2.md`（本文件）** | **H2 执行章程** |
| [`READY.md`](READY.md) | Ready / H2 状态入口 |
| [`CONTRACT.md`](CONTRACT.md) | 契约真相 |
| [`long-term-roadmap.md`](long-term-roadmap.md) | = R8 研究线 |
| phase4–8 / optimization-* | 历史归档 |
