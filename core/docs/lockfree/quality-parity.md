# Atomic / Lockfree — Q 线（Quality / Parity）

> **状态**: **Q0 done** → **Q1 next**
> **日期**: 2026-07-19
> **Owner**: atomic-lockfree lane（全权）
> **目标**: 对标 Go/Rust 的 **质量与可用规模**，并保持清洁
> **编号**: **Q0–Q5**（**不是** R9；R8 仍为研究 opt-in）

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
| **Q1** | Atomic 首选路径与质量加固 | pending |
| **Q2** | T1 深度（Close/Try\*Ex/stress） | pending |
| **Q3** | Map/Channel 体验对标 | pending |
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
