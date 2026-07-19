# Atomic / Lockfree — Q 线（Quality / Parity）

> **状态**: **Q0–Q2 done** · **Q3-a in progress** · Q3-b/c pending
> **日期**: 2026-07-20
> **Owner**: atomic-lockfree lane（全权）
> **目标**: 对标 Go/Rust 的 **质量与可用规模**，并保持清洁
> **编号**: **Q0–Q5**（**不是** R9；R8 仍为研究 opt-in）
> **对标矩阵**: [`parity-go-rust.md`](parity-go-rust.md)

权威契约仍是 [`CONTRACT.md`](CONTRACT.md)。状态入口 [`READY.md`](READY.md)。

---

## 0. 对标定义

| 维度 | 含义 |
|------|------|
| **质量** | 契约诚实、测试硬、首选 API 清晰、生命周期可教 |
| **规模** | T1「写 runtime 够用」+ T2 精炼可导航；**不是**源文件最多 |
| **清洁** | 门面精、progress 诚实、有信封证据、无产物污染、小步 commit |

**对标面**（精神，非抄 API）：

- Go：`sync/atomic`、buffered `chan`、`select`、`sync.Map` 级工具箱
- Rust：`std::sync::atomic`、channel/flume 精神、dashmap 级分片 map

---

## 1. 阶段

| 阶段 | 名称 | 状态 |
|------|------|------|
| **Q0** | 清洁基线 + reconverge 评估 | **done** |
| **Q1** | Atomic 首选路径与质量加固 | **Q1-a done**；Q1-b/c pending |
| **Q2** | T1 深度（首选路径 + stress） | **done** — T1 preferred path 全量；verify-t1 绿；已 land main |
| **Q3** | Map/Channel 体验对标 | **Q3-a** Selector 语义/测试；Q3-b Channel；Q3-c HashMap |
| **Q4** | T2 精炼（审计 / 降档 / 可选生产子集） | pending |
| **Q5** | 有信封 Go/Rust 同机对照常青 | pending |

```
H3 complete → Q0 → Q1 → Q2 → Q3 → Q4 → Q5 → Maintenance 循环
```

### Q0 通过标准

- `verify-t1` + `verify-h3-consumers` + `test_worksteal` 绿
- `make hygiene` 绿
- reconverge 评估写入本文件 §2
- READY/roadmap 指向 Q 线

### 非目标（全 Q 线）

- invent **R9**
- R8 生产化 / T2 默认门面 / 删 legacy CAS / 改 Closed 语义
- 无信封绝对 Mops 营销
- 为「文件数」堆 T2 算法

---

## 2. Reconverge 评估（Q0）

| 项 | 值（2026-07-19） |
|----|------------------|
| HEAD | `e4761b7fc` |
| vs `origin/main` | 领先 13 / 落后 63 |
| main 触及 atomic/lockfree 源 | **无**（路径空） |
| main 触及 async 消费者 | **有**（PostEx/OnDiscard 等） |
| main 触及 thread.worksteal | **无** |

**结论**：atomic/lockfree 本体与 main 无直接冲突面；已 **merge origin/main**（Q0），post-merge `verify-h3-consumers` + `test_worksteal` + hygiene 绿。

---

## 3. 验证入口

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make -C core/tests/nextpas.core.lockfree verify-h3-consumers
make -C core/tests/nextpas.core.thread/test_worksteal clean test
make hygiene
```

Bench 信封：[`bench-envelope.md`](bench-envelope.md)。

---

## 4. 进度记录

| 日期 | 事件 |
|------|------|
| 2026-07-19 | Q 线章程入仓；Q0 门绿；merge origin/main；post-merge 门绿 → **Q0 done** |
| 2026-07-19 | **Q1-a** legacy 消费者扫描入仓（§5）；不删 API；迁移按热点分批 |
| 2026-07-19 | **parity-go-rust.md** 入仓；`lockfree.wait` 迁 `atomic_*`+`mo_*` 示范 |
| 2026-07-19 | **Q2-a**：`lockfree.ebr` 全量迁 preferred path（Boolean CAS + mo_*）；test_lockfree 178 绿 |
| 2026-07-19 | **Q2-a**：`lockfree.stack` 迁 preferred path；source-contract 同步 |
| 2026-07-19 | **Q2-a**：`lockfree.deque` 迁 preferred path（seq_cst 仲裁保留）；source-contract 同步 |
| 2026-07-19 | **Q2-a**：`lockfree.spsc` 迁 preferred path（load/store） |
| 2026-07-19 | **Q2-a**：`lockfree.mpmc` 迁 preferred path（active enqueue + pos CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.spmc` 迁 preferred path（单产 + 多消 CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.mpsc` 迁 preferred path（节点指针 helpers 保留，标量用 atomic_*） |
| 2026-07-19 | **Q2-a**：`lockfree.channel` + `channel.spsc` 迁 preferred path（notifier 锁 + sequence CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.hazard` + `segqueue` 迁 preferred path（回收域 / 无界 segment） |
| 2026-07-20 | **Q2-a**：`lockfree.msqueue` + `hashmap` 迁 preferred path（MS 无界队列 / 分片锁 map） |
| 2026-07-20 | **Q2-b**：`verify-t1` 全门绿（atomic + main + stress 17） |
| 2026-07-20 | **Land** H3-4/H3-5 + Q0–Q2 → main `1e535bfb4`；archive tag |
| 2026-07-20 | **Q3-a**：Selector preferred atomics；TrySelect≡default；Add 序；wait 文档修正；钉测试 |

### Q3-a checklist

- [x] `selector.impl` → `atomic_*`+`mo_*`
- [x] 头注释 / CONTRACT §1.2a / api-ref / README / selection-guide 语义一致
- [x] 测试：case 序、TrySelect-as-default、closed-empty recv
- [x] source-contract：preferred atomics + LockFreeWaitData；禁 legacy AtomicLoad32/FetchAdd32

---

## 5. Q1-a — Legacy atomic 消费者扫描（2026-07-19）

### 方法

`rg` 扫描 `core/src/**/*.pas`，排除 `nextpas.core.atomic*` 自身实现。

### 结果摘要

| 模式 | 约略规模 | 含义 |
|------|----------|------|
| `AtomicCompareExchange32/64/Ptr` | **~200** 次（core 生产源，不含 atomic 单元） | legacy **返回观测值** CAS；与 `atomic_compare_exchange_*` Boolean 语义不同 |
| PascalCase `AtomicLoad/Store/Fetch*` | **~1200** 次 | 兼容 wrapper；功能正确，但非首选命名 |

### T1 热路径观察

| 单元 | 倾向 |
|------|------|
| spsc / mpmc / mpsc / stack / deque / ebr | 大量 `AtomicLoad*` / `AtomicStore*` / `AtomicCompareExchange*`（PascalCase） |
| channel / msqueue / hazard | 同上 + 自旋锁 CAS |
| 多数 T2 | 自旋锁 `AtomicCompareExchange32(FLock, 0, 1)` |

**对标 Go/Rust**：语义面已够用；差距在 **API 一致性与可读性**，不是缺 CAS。

### 策略（Q1 后续，自主分批）

1. **不删** legacy / PascalCase API（H2-3 锁定）。
2. **新代码** 只写 `atomic_*` + `mo_*` 或 `TAtomic*`。
3. **迁移优先级**（高→低）：
   - 新改动的 T1 文件顺手改为本文件内一致风格（同一 PR 不混无关文件）
   - 文档/示例/测试先示范首选路径
   - 禁止一次「全库 sed」式迁移（风险高、diff 不可审）
4. **CAS 迁移注意**：`AtomicCompareExchange*` 返回 **old**；`atomic_compare_exchange_strong` 返回 **Boolean** 且写回 `var Expected` — 必须逐点改，不能机械替换。

### Q1-b/c（下一步）

- Q1-b：atomic 测试边界抽检（alignment / GetMut / wait）— 缺则补
- Q1-c：atomic README ↔ consumer-audit 交叉链接 + 本表指针
