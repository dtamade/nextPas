# Atomic & Lockfree 可执行路线图（权威）

> **状态**: **H2 complete / Maintenance**（2026-07-17）· R0–R7 + RC Ready + H2-0…H2-6 **已完成** · **Owner**: atomic-lockfree lane
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）
> **当前执行主线**: **Maintenance**（T1/atomic 缺陷修复、契约修订、验证门保绿）。H2 记录见 [`roadmap-h2.md`](roadmap-h2.md)。
> **H3**: 章程 only — [`roadmap-h3.md`](roadmap-h3.md)；**未开工 / 不自动执行**。
> **R8**: 研究 pack 诚实收口（opt-in docs）— [`r8-research-status.md`](r8-research-status.md)；**不**默认生产化。
> 冲突时以 **CONTRACT + [`roadmap-h2.md`](roadmap-h2.md) + 本路线图** 为准。
> **已锁定 (R 线)**: Q1 R4–R7 / Q2 R5 修 cap=1 / Q3 rings+MPSC 优先 / Q4 Makefile 证据 / Q5 phase 归档。
> **已锁定 (H2)**: D1–D5 见 [`roadmap-h2.md`](roadmap-h2.md)；**不叫 R9**；R8 仍为 opt-in 研究。
> **状态入口**: [`READY.md`](READY.md)。

---

## 0. 文档地图（整理后）

| 文档 | 角色 | 权威等级 |
|------|------|----------|
| [`CONTRACT.md`](CONTRACT.md) | 运行时/API 契约（Closed、managed、RTL isolation、Try\*Ex） | **契约真相** |
| [`README.md`](README.md) | 模块入口、T1 矩阵、生命周期、如何用 | **产品真相** |
| **[`roadmap-h2.md`](roadmap-h2.md)** | Horizon-2（H2-0…H2-6）章程与完成记录 | **H2 完成记录** |
| **[`roadmap-h3.md`](roadmap-h3.md)** | Horizon-3 章程（H3-0…H3-4） | **H3 charter only**（未开工） |
| **`roadmap.md`（本文件）** | R0–R7 完成记录、全局非目标、历史索引 | **R 线记录 + 指针** |
| [`READY.md`](READY.md) | 状态入口、验收清单、Maintenance 策略 | **Ready / H2 complete / Maintenance** |
| [`r8-research-status.md`](r8-research-status.md) | R8（NUMA/RTM/TLA）诚实状态与 research pack 收口 | 研究，opt-in |
| [`formal/README.md`](formal/README.md) | TLA+ 如何跑 / 无 TLC 时 model-only | 研究 |
| [`consumer-audit.md`](consumer-audit.md) | R7 core 内 uses 消费者审计 | 证据 / 维护参考 |
| [`selection-guide.md`](selection-guide.md) | 选型决策树 | 用户向 |
| [`api-reference.md`](api-reference.md) | API 摘要（易漂移，改 API 必须同步） | 参考，次于 CONTRACT |
| [`bench-envelope.md`](bench-envelope.md) | H2-4 可复现 bench 信封 | 证据制度 |
| [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) / [`../atomic/README.md`](../atomic/README.md) | atomic 契约与入口 | 契约/入口 |
| [`long-term-roadmap.md`](long-term-roadmap.md) | NUMA / TSX / TLA+ **研究**历史计划 | 研究；现状以 r8-research-status 为准 |
| `optimization-roadmap-2026-07-06.md`、`phase4-plan.md`…`phase8-*.md` | 历史切片 | **归档**，不单独推进 |
| `benchmark-comparison-*.md` | 历史对照数据（需平台信封） | 证据附件 |
| `formal/tla/*` | 形式化模型 | 研究 |

**原则**：R 线与 H2 已完成；**默认进入 Maintenance**。不要再开无名编号的「Phase N」或擅自开 R9。R8 仅研究 opt-in（pack 文档可收口，**不**生产化）。H3 仅有章程，**不自动执行**。

---

## 1. 现状盘点（2026-07-17）

### 1.1 模块定位

| 模块 | 层 | 职责 |
|------|----|------|
| `nextpas.core.atomic` | L0 | 原子原语、内存序、wait/notify、`TAtomic*` |
| `nextpas.core.lockfree` | L1 | 并发结构；**默认门面仅 T1**；T2/T3 直 import |

**硬约束（编译器无关）**：仅 `nextpas.core.system*` 可直接 `uses` FPC RTL；atomic/lockfree 生产、测试、示例走框架抽象。

### 1.2 已交付（已合入 main / origin）

| ID | 交付 | 证据摘要 |
|----|------|----------|
| **R0** 历史基线 | T1 队列/栈/deque、EBR/Hazard、Channel、Selector、分片 HashMap；atomic 全表面 | 历史 phase + 主测试门 |
| **R1** 可用性 Wave-1 | ClosedPublishPolicy；SegQueue closed raise；MSQueue Destroy Close+drain；生产+主测试 RTL isolation；大量 T2 `IsManagedType` | `eeaa7c840` 一带；lockfree~168、atomic 45 |
| **R2** 可用性 Wave-2 | 剩余 generic 守卫（btree/trie/selector.impl）；SegQueue Destroy Close；bench 去 RTL 符号；CONTRACT 例外表；api-ref `moSeqCst` | `334a61a69` |
| **R3** 诊断 API 试点 | `TLockFreeTryError` + Channel/ChannelSPSC/SegQueue `Try*Ex` | `373f86896`；lockfree **171** |
| **R4** Try\*Ex 扩面 | SPSC/MPMC/SPMC/MPSC/Stack `Try*Ex`；CONTRACT §1.4 | 已完成；lockfree **177**（R4 落地时 176；R5 +1） |
| **R5** Channel cap=1 | MPMC Channel empty/full sequence 编码（方案 A）；`TestChannelCapacityOneFullEmpty`；CONTRACT §1.5 | 已合入；lockfree **177** |
| **R6** 工程卫生 | 模块 `verify-t1` Makefile；CONTRACT §3.1 managed 文案模板；api-ref EN `moSeqCst` 对齐 | 已合入 |
| **R7** 消费者 + legacy | [`consumer-audit.md`](consumer-audit.md)；atomic CONTRACT §1.4 legacy CAS 偏好；T2 命名诚实脚注扩充 | 已合入 |
| **RC** Ready close-out | [`READY.md`](READY.md) 验收清单 | Ready 基线 |
| **H2-0…H2-6** | Horizon-2 | 见 [`roadmap-h2.md`](roadmap-h2.md)；tag `archive/atomic-lockfree-h2-complete-20260717` (`d93780c27`) |
| **H2 close-out** | READY/roadmap → complete | `archive/atomic-lockfree-h2-closeout-20260717` |

### 1.3 成熟度（诚实）

| 面 | 状态 | 说明 |
|----|------|------|
| **T1 消费面** | **Ready-for-consumer** | unmanaged + `Close→join→Free`；契约与测试对齐；Deque Try\*Ex 齐 |
| **atomic** | **Ready-for-consumer** | 双 API 文档化；legacy 仍在，非首选 |
| **T2 容器** | **可用但非统一生产契约** | H2-2 分档；多数有 managed 守卫或 AnsiString 例外表；progress 多为 lock-based |
| **T3 / 研究** | 实验 | RTM/NUMA/TLA 等，不默认门面 |
| **文档卫生** | **已整理** | 主文档以 CONTRACT + README + roadmap + READY 为准；旧「全无锁」宣称**已废止**；历史 phase 为归档 |

### 1.4 已知缺口 / 剩余（按优先级）

| 优先级 | 缺口 | 对应阶段 |
|--------|------|----------|
| — | 主线 R0–R7 + RC Ready | **DONE** |
| — | Horizon-2（Deque Try\*Ex、T2 分档、atomic 首选路径、bench 信封、stress、真实消费者） | **H2-0…H2-6 DONE** |
| **P0 当前** | Maintenance：T1/atomic 缺陷、契约修订、`verify-t1` 保绿 | **Maintenance** |
| 文档（opt-in 收口） | R8 研究 pack 诚实状态；H3 章程（不自动执行） | **docs** — [`r8-research-status.md`](r8-research-status.md)、[`roadmap-h3.md`](roadmap-h3.md) |
| 研究（仅 opt-in） | NUMA Phase-3 亲和 residual / TSX / TLA+（有 TLC 时加深） | **R8**（非默认，不自动推进；见 r8-research-status） |
| 生产向（需授权） | 跨模块接入 / T2 Guarded 子集 / consumer regression 门 | **H3-1…**（章程 only；**未授权不实施**） |

### 1.5 标准验证门（所有阶段验收默认集）

一键 T1（推荐）：

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
# 日志默认: core/build/verify-lockfree/verify-t1.log
```

等价分步：

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.atomic/test_atomic clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test   # 建议 ×3
make hygiene
git diff --check
```

Landing：path-limited candidate + `make landing-check` + ff-only main；push 仅授权时。

---

## 2. 路线图总览

```
R0–R7 + RC Ready  ── DONE
    │
    ▼
H2-0…H2-6  Horizon-2  ── DONE  →  roadmap-h2.md
    │
    ▼
Maintenance  ── 当前默认（生产执行主线）
    │
    ├─(opt-in)──► R8 research pack done（docs + verify-r8）
    │                → r8-research-status.md；不生产化
    │
    └─(opt-in)──► H3 charter only（roadmap-h3.md）
                     NOT auto exec；H3-1 需单独授权
```

| 阶段 | 名称 | 优先级 | 依赖 | 默认是否自动推进 |
|------|------|--------|------|------------------|
| R0–R3 | 基线 + Wave1–3 | — | — | 已完成 |
| **R4** | Try\*Ex 扩至 T1 rings | **P1** | R3 | **已完成** |
| **R5** | Channel cap=1 语义 | **P1** | R3；可与 R4 并行评估 | **已完成** |
| **R6** | 证据与文档卫生 | **P2** | R4 或并行小切片 | **已完成** |
| **R7** | 消费者 + legacy | **P3** | R6 | **已完成** |
| **RC** | Ready close-out | — | R7 | **已完成** |
| **H2-0…H2-6** | Horizon-2 | **P0** | RC Ready | **已完成** — [`roadmap-h2.md`](roadmap-h2.md) |
| **Maintenance** | 缺陷 / 契约 / 门 | **P0 当前** | H2 complete | **是** |
| **R8** | 研究扩展 / pack 收口 | 研究 | 独立 | **否**；docs opt-in；生产化需重大讨论 |
| **H3-0…H3-4** | Horizon-3 | 生产向（未来） | Maintenance | **否** — 章程 only，见 [`roadmap-h3.md`](roadmap-h3.md) |

---

## 3. 分阶段详情

### R4 — Try\*Ex 扩面（T1）

**目标**：有界 T1 发布/消费路径均可区分 full / empty / closed，且 Boolean 热路径不变。

| 项 | 内容 |
|----|------|
| **交付物** | `TryEnqueueEx`/`TryDequeueEx`（或对应命名）于 SPSC、MPMC、SPMC、MPSC、Stack（及 Deque push 侧若自然）；CONTRACT §1.4 扩表；测试矩阵 |
| **不做** | 改算法；强制替换 Boolean API；T2 全量 |
| **依赖** | R3 的 `TLockFreeTryError` |
| **优先级** | P1 |
| **验收** | 默认验证门绿；每种结构至少：success / full 或 empty / closed；文档表更新；path-limited 可 land |

### R5 — Channel capacity=1 语义硬化 — **DONE（方案 A）**

**目标**：MPMC Channel 在 capacity=1 时 full 与 empty 可区分（或文档明确「最小推荐 cap≥2」+ source-contract）。

| 项 | 内容 |
|----|------|
| **交付物** | **方案 A**：Channel 采用与 `TMpmcQueue` 相同的 empty/full sequence 编码；`TestChannelCapacityOneFullEmpty`；`TestChannelTryExDiagnostics` 改用 `Create(1)`；CONTRACT §1.5 |
| **依赖** | 理解现有 sequence 协议；可与 R4 并行调研 |
| **优先级** | P1 |
| **验收** | cap=1 下 `TrySendEx`/`TryReceiveEx` 语义与 CONTRACT 一致；主门绿 |
| **决策** | **A**（实现修复）：`EmptySequence(pos)=pos*2` / `FullSequence(pos)=pos*2+1`；非 B |

### R6 — 工程卫生与证据 — **DONE**

**目标**：可复现验证与文档零关键漂移。

| 项 | 内容 |
|----|------|
| **交付物** | （1）`core/tests/nextpas.core.lockfree/Makefile` 的 `verify-t1`（atomic+lockfree+stress，日志 `core/build/verify-lockfree/verify-t1.log`）；（2）CONTRACT §3.1 managed 拒绝文案推荐模板（不强制全量改名）；（3）api-reference EN 清除 `moSequentiallyConsistent` → `moSeqCst`；日期对齐 |
| **依赖** | 无硬依赖；建议在 R4 后或穿插 |
| **优先级** | P2 |
| **验收** | 新人 `make -C core/tests/nextpas.core.lockfree verify-t1` 可复现绿；grep 无 `moSequentiallyConsistent` 陈旧主名；CONTRACT/README/roadmap 日期一致 |

### R7 — 消费者审计与长期清理 — **DONE**

**目标**：降低误用与 API 学习成本。

| 项 | 内容 |
|----|------|
| **交付物** | [`consumer-audit.md`](consumer-audit.md)；atomic [`CONTRACT.md`](../atomic/CONTRACT.md) §1.4 legacy CAS 偏好（**不删 API**）；CONTRACT/README T2 命名诚实脚注扩充 |
| **代码修复** | 无（扫描未发现需一刀切的 Close/Destroy 跨模块误用；lockfree 无生产跨模块容器消费者） |
| **依赖** | R6 |
| **优先级** | P3 |
| **验收** | 审计文档入仓；legacy 有明确首选路径；roadmap 标记完成 |

### R8 — 研究线（非默认）

**当前诚实状态**（优先读）：[`r8-research-status.md`](r8-research-status.md)。
历史计划：[`long-term-roadmap.md`](long-term-roadmap.md)。形式化入口：[`formal/README.md`](formal/README.md)。

| 项 | 内容 |
|----|------|
| **触发** | 性能/正确性研究需求或总控点名 |
| **验收** | 独立研究结论 + 不污染 T1 契约；进门面需单独 ADR/讨论 |
| **收口（docs）** | NUMA/RTM/formal 状态表 + 可选 `verify-r8`；**不**升 T1 |

### H3 — Horizon-3 章程（非自动执行）

见 [`roadmap-h3.md`](roadmap-h3.md)。H3-0 为章程文档；**H3-1… 实现需单独授权**。

---

## 4. 非目标（全局）

- 宣称「全部 lock-free」或替代 Rust/Go 全套并发库
- 无信封绝对 Mops 对外营销数字
- raw merge 长期 lane；未授权 force-push
- 借机重写 T2 算法全集

---

## 5. 工作方式

1. **当前主线**：**Maintenance**；H2 记录见 [`roadmap-h2.md`](roadmap-h2.md)。新功能波次需显式章程，不要静默续编 H2 编号。
2. **H3 实现**：即使 [`roadmap-h3.md`](roadmap-h3.md) 已存在，**也不**自动开工 H3-1…；必须单独授权（建议独立 worktree）。
3. **自主**：阶段内不因琐事打断；**重大变更**（改 Closed 语义、扩门面 T2、R8 进生产、删 legacy）先修订 roadmap 再问。
4. **文档**：改契约先 CONTRACT，再 README/selection-guide/api-reference，最后更新 READY 进度。
5. **Landing**：path-limited；push 仅在授权时。

---

## 6. 已锁定决策

### R 线（2026-07-17）— 已完成

| # | 决策 | 结果 |
|---|------|------|
| Q1 | R4→R7 默认主线，R8 仅研究 | **确认 · DONE** |
| Q2 | R5 Channel cap=1：优先实现修复 (A)，过贵则 B | **确认 · DONE** |
| Q3 | R4：rings+MPSC 优先，Stack 次之，Deque 可选 | **确认 · DONE** |
| Q4 | R6：优先模块 Makefile 目标 | **确认 · DONE** |
| Q5 | 旧 phase 归档横幅保留 | **确认** |

### H2 线（2026-07-17）— **已完成**

| # | 决策 | 结果 |
|---|------|------|
| D1 | 开 Horizon-2（H2-0…H2-6），不叫 R9 | **锁定 · DONE** |
| D2 | path-limited land + push origin/main | **已授权 · 已执行** |
| D3 | 重大变更先停再问 | **锁定** |
| D4 | 不默认做 R8 | **锁定** |
| D5 | 小步 commit + focused verify；自主跑完 H2 | **锁定 · DONE** |

**当前执行**: **Maintenance** — H2 complete 详情 [`roadmap-h2.md`](roadmap-h2.md)。R0–R7 + RC Ready + H2 基线保留；**R8 仅研究 opt-in**（pack 收口见 [`r8-research-status.md`](r8-research-status.md)）。**H3 章程 only**（[`roadmap-h3.md`](roadmap-h3.md)），**未开工**。

### RC Ready close-out — **DONE**（H2 基线）

正式验收清单见 [`READY.md`](READY.md)（R0–R7 与 H2 项均为 Done；状态为 H2 complete / Maintenance）：

- 模块成熟度表（T1/atomic Ready-for-consumer；T2 非统一生产契约）
- 验收项：ClosedPublishPolicy、managed guards、RTL isolation、Try\*Ex T1（含 Deque）、Channel cap=1、verify-t1、consumer-audit
- 验证：`make -C core/tests/nextpas.core.lockfree verify-t1`
- 归档标签 R4–R7 + Ready + H2 complete + H2 close-out
- 禁止入仓：`.playwright-mcp/`、一次性 migrate 脚本、临时 land helpers

---

## 7. 历史归档索引（不执行）

| 文件 | 原用途 | 现状 |
|------|--------|------|
| `roadmap.md` 2026-07-06 版 | 总表 + 性能史 | **已由本文件替换** |
| `optimization-roadmap-2026-07-06.md` | 优化 phase | 归档 |
| `phase4-plan.md` … `phase8-conclusion.md` | 单阶段计划 | 归档 |
| `long-term-roadmap.md` | NUMA/TSX/TLA 历史计划 | 研究线 = R8；现状 → r8-research-status |
| `r8-research-status.md` | R8 诚实收口 | 研究，opt-in |
| `roadmap-h3.md` | H3 章程 | charter only，非执行 |
| `optimization-research.md` | 调研笔记 | 归档 |

历史「C0–C6 / Phase 1–5 / 2026-07 性能波」成果已吸收进 R0 与代码；细节以 git 与 CONTRACT 为准，不再作为待办清单。
