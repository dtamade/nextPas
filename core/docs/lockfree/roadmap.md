# Atomic & Lockfree 可执行路线图（权威）

> **状态**: **Mainline complete · Ready/Maintenance**（2026-07-17）· **Owner**: atomic-lockfree lane
> **范围**: `nextpas.core.atomic`（L0）+ `nextpas.core.lockfree`（L1）
> **本文件是推进主线**。历史 phase 笔记与研究材料降级为附录引用，冲突时以 **CONTRACT + 本路线图** 为准。
> **已锁定**: Q1 R4–R7 主线 / Q2 R5 倾向修 cap=1 / Q3 rings+MPSC 优先 Stack 次之 / Q4 Makefile 证据 / Q5 phase 归档保留。
> **Ready 声明**: [`READY.md`](READY.md)（验收清单、维护策略、exclude-from-land）。

---

## 0. 文档地图（整理后）

| 文档 | 角色 | 权威等级 |
|------|------|----------|
| [`CONTRACT.md`](CONTRACT.md) | 运行时/API 契约（Closed、managed、RTL isolation、Try\*Ex） | **契约真相** |
| [`README.md`](README.md) | 模块入口、T1 矩阵、生命周期、如何用 | **产品真相** |
| **`roadmap.md`（本文件）** | 分阶段目标、交付、依赖、优先级、验收 | **推进主线** |
| [`READY.md`](READY.md) | **Ready 声明**、验收清单、维护策略 | **Ready / Maintenance 状态** |
| [`consumer-audit.md`](consumer-audit.md) | R7 core 内 uses 消费者审计 | 证据 / 维护参考 |
| [`selection-guide.md`](selection-guide.md) | 选型决策树 | 用户向 |
| [`api-reference.md`](api-reference.md) | API 摘要（易漂移，改 API 必须同步） | 参考，次于 CONTRACT |
| [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) / [`../atomic/README.md`](../atomic/README.md) | atomic 契约与入口 | 契约/入口 |
| `long-term-roadmap.md` | NUMA / TSX / TLA+ **研究**线 | 研究，非默认推进 |
| `optimization-roadmap-2026-07-06.md`、`phase4-plan.md`…`phase8-*.md` | 历史切片 | **归档**，不单独推进 |
| `benchmark-comparison-*.md` | 历史对照数据（需平台信封） | 证据附件 |
| `formal/tla/*` | 形式化模型 | 研究 |

**原则**：新工作只挂到本路线图的 **R 阶段编号**；不要再开无编号的「Phase N」平行文档，除非重大修订讨论后新增。无维护期默认不新增 R 编号。

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
| **RC** Ready close-out | [`READY.md`](READY.md) 验收清单 + Maintenance 策略 | 本文件 / READY |

### 1.3 成熟度（诚实）

| 面 | 状态 | 说明 |
|----|------|------|
| **T1 消费面** | **Ready-for-consumer** | unmanaged + `Close→join→Free`；契约与测试对齐 |
| **atomic** | **Ready-for-consumer** | 双 API 文档化；legacy 仍在 |
| **T2 容器** | **可用但非统一生产契约** | 多数有 managed 守卫或 AnsiString 例外表；progress 多为 lock-based |
| **T3 / 研究** | 实验 | RTM/NUMA/TLA 等，不默认门面 |
| **文档卫生** | **已整理** | 主文档以 CONTRACT + README + roadmap + READY 为准；旧「全无锁」宣称**已废止**；历史 phase 为归档 |

### 1.4 已知缺口 / 剩余（按优先级）

| 优先级 | 缺口 | 对应阶段 |
|--------|------|----------|
| — | 主线 R0–R7 | **DONE** |
| 研究（仅 opt-in） | NUMA 亲和 / TSX 扩展 / TLA+ 扩模型 | **R8**（非默认，不自动推进） |

### 1.5 标准验证门（所有 R* 验收默认集）

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
R0–R3 已完成
    │
    ▼
R4  Try*Ex 扩面（T1 有界队列/栈）     P1  ──┐
R5  Channel capacity=1 / 语义硬化       P1  ──┼──► R6 工程卫生
R6  证据固化 + 文档漂移清零             P2  ──┘
    │
    ▼
R7  消费者审计 + legacy/命名            P3
    │
    ▼
R8  研究线（NUMA/TSX/TLA）              可选，重大变更需讨论
```

| 阶段 | 名称 | 优先级 | 依赖 | 默认是否自动推进 |
|------|------|--------|------|------------------|
| R0–R3 | 基线 + Wave1–3 | — | — | 已完成 |
| **R4** | Try\*Ex 扩至 T1 rings | **P1** | R3 | **已完成** |
| **R5** | Channel cap=1 语义 | **P1** | R3；可与 R4 并行评估 | **已完成** |
| **R6** | 证据与文档卫生 | **P2** | R4 或并行小切片 | **已完成** |
| **R7** | 消费者 + legacy | **P3** | R6 | **已完成** |
| **R8** | 研究扩展 | 研究 | 独立 | **否**，重大变更先讨论 |

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

见 [`long-term-roadmap.md`](long-term-roadmap.md)：NUMA 亲和、TSX 扩展、TLA+ 扩覆盖。

| 项 | 内容 |
|----|------|
| **触发** | 性能/正确性研究需求或总控点名 |
| **验收** | 独立研究结论 + 不污染 T1 契约；进门面需单独 ADR/讨论 |

---

## 4. 非目标（全局）

- 宣称「全部 lock-free」或替代 Rust/Go 全套并发库
- 无信封绝对 Mops 对外营销数字
- raw merge 长期 lane；未授权 force-push
- 借机重写 T2 算法全集

---

## 5. 工作方式（确认后生效）

1. **主线**：按 R4 →（R5 并行/穿插）→ R6 → R7 推进；每阶段小步 commit + focused 验证。
2. **自主**：阶段内不因琐事打断；**重大变更**（改 Closed 语义、扩门面 T2、R8 进生产、删 legacy）先修订本文件再动手。
3. **文档**：改契约先 CONTRACT，再 README/selection-guide/api-reference，最后更新本文件「已交付」表。
4. **Landing**：path-limited；push 遵循用户/总控授权。

---

## 6. 已锁定决策（2026-07-17）

| # | 决策 | 结果 |
|---|------|------|
| Q1 | R4→R7 默认主线，R8 仅研究 | **确认** |
| Q2 | R5 Channel cap=1：优先实现修复 (A)，过贵则 B | **确认** |
| Q3 | R4：rings+MPSC 优先，Stack 次之，Deque 可选 | **确认** |
| Q4 | R6：优先模块 Makefile 目标 | **确认** |
| Q5 | 旧 phase 归档横幅保留 | **确认** |

**当前执行**: **none / maintenance**（主线 R0–R7 完成；**R8 仅研究 opt-in**，默认不推进；无 R9）。

### RC Ready close-out — **DONE**

正式 Ready 声明与验收清单见 [`READY.md`](READY.md)：

- 状态 **Ready / Maintenance**
- 模块成熟度表（T1/atomic Ready-for-consumer；T2 非统一生产契约）
- 验收项：ClosedPublishPolicy、managed guards、RTL isolation、Try\*Ex T1、Channel cap=1、verify-t1、consumer-audit
- 维护策略：bugfix only；不擅自开 R9
- 验证：`make -C core/tests/nextpas.core.lockfree verify-t1`
- 归档标签 R4–R7 + `archive/atomic-lockfree-ready-20260717`
- 禁止入仓：`.playwright-mcp/`、一次性 migrate 脚本

---

## 7. 历史归档索引（不执行）

| 文件 | 原用途 | 现状 |
|------|--------|------|
| `roadmap.md` 2026-07-06 版 | 总表 + 性能史 | **已由本文件替换** |
| `optimization-roadmap-2026-07-06.md` | 优化 phase | 归档 |
| `phase4-plan.md` … `phase8-conclusion.md` | 单阶段计划 | 归档 |
| `long-term-roadmap.md` | NUMA/TSX/TLA | 研究线 = R8 |
| `optimization-research.md` | 调研笔记 | 归档 |

历史「C0–C6 / Phase 1–5 / 2026-07 性能波」成果已吸收进 R0 与代码；细节以 git 与 CONTRACT 为准，不再作为待办清单。
