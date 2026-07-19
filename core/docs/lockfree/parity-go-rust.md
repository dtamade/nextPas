# Atomic / Lockfree — 对标 Go / Rust（权威目标）

> **Owner**: atomic-lockfree lane（全权）
> **日期**: 2026-07-19
> **地位**: 质量与规模 **目标真相**；实现契约仍以 [`CONTRACT.md`](CONTRACT.md) / [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) 为准
> **执行主线**: [`quality-parity.md`](quality-parity.md)（Q 线；**不是 R9**）

本文件回答：**「对标 Go/Rust 的 atomic 和 lockfree 质量和规模」具体指什么。**

---

## 0. 原则

| 原则 | 含义 |
|------|------|
| **质量优先于文件数** | 契约硬、测试硬、progress 诚实 > 再堆 T2 算法 |
| **规模 = 生产工具箱完整** | 写 runtime / 框架够用，不是替代整个 crates.io |
| **诚实对标** | 标「覆盖 / 超越 / 缺口 / 非目标」；不写无信封「快过 Go」 |
| **清洁** | T1 默认门面精；T2 直 import；T3/R8 研究隔离 |

**不宣称**：完整替代 Go runtime 调度器、Rust async 生态、或所有第三方无锁库。

---

## 1. Atomic — 对标 `sync/atomic` + `std::sync::atomic`

### 1.1 覆盖矩阵

| 能力 | Go `sync/atomic` | Rust `std::sync::atomic` | nextpas.core.atomic | 判定 |
|------|------------------|--------------------------|---------------------|------|
| 32/64-bit load/store/swap/CAS | ✅ | ✅ | ✅ `atomic_*` + `TAtomic*` | **对标** |
| fetch_add/sub/and/or/xor | ✅ | ✅ | ✅ | **对标** |
| fetch_max/min/nand | 部分/无 | ✅（部分） | ✅ | **≥ Go** |
| memory order 参数 | 有限（Go model） | 完整 enum | ✅ `mo_*` / PascalCase 别名 | **对标 Rust 面** |
| fence | ✅ | ✅ | ✅ thread/signal fence | **对标** |
| AtomicBool / Flag | ✅ | ✅ | ✅ `TAtomicBool` / `TAtomicFlag` | **对标** |
| AtomicPtr | ✅ | ✅ | ✅ `TAtomicPtr<T>` | **对标** |
| pointer-sized isize/usize | ✅ | ✅ | ✅ `TAtomicISize`/`USize` | **对标** |
| wait / notify | runtime 其他路径 | `Atomic*::wait` (nightly/std 演进) | ✅ 32/64-bit address wait | **≥ Go std 原子面** |
| typed refcount 纪律 | 手工 | `Arc` 内建 | ✅ `TAtomicRefCount`（无 Store） | **专用增强** |
| tagged pointer（ABA） | 手工 | 库/手工 | ✅ `atomic_tagged_ptr_*` | **增强** |
| legacy PascalCase / 观测值 CAS | n/a | n/a | ✅ 保留不删 | **兼容债**（非首选） |

### 1.2 质量目标（Go/Rust 级）

1. **首选路径唯一叙事**：新代码 `atomic_*`+`mo_*` 或 `TAtomic*`；见 atomic CONTRACT §1.4
2. **测试面**：边界 memory order、wrap、alignment、wait/notify、refcount 竞态 — **已大体具备**（`test_atomic` ~7k 行）
3. **消费者纪律**：core 内 ~1200 PascalCase + ~200 观测值 CAS → **分批**迁首选路径，禁止全库 sed
4. **文档**：本矩阵 + README；无 silent UB 承诺

### 1.3 Atomic 规模结论

**功能规模已达或超过 Go `sync/atomic` 公开面，并接近 Rust std atomic + 实用扩展（wait、tagged、refcount）。**
剩余工作是 **一致性与清洁**（首选 API、消费者迁移、证据信封），不是补齐基础原语。

---

## 2. Lockfree — 对标 Go 并发原语 + Rust 常用无锁工具箱

### 2.1 运行时核心（T1）— 对标「能写 runtime」

| 场景 | Go | Rust 生态习惯 | nextpas T1 | 判定 |
|------|-----|---------------|------------|------|
| SPSC 有界队列 | 无 std 专用 | crossbeam ArrayQueue / 手写 | `TSpscQueue` | **≥ Go std** |
| MPMC 有界 | buffered `chan` | crossbeam / flume | `TMpmcQueue` | **对标** |
| MPSC 无界 | `chan` | crossbeam SegQueue 类 | `TMpscQueue` | **对标** |
| SPMC / SegQueue / MSQueue | 无 std | 库 | ✅ | **增强** |
| Stack | 无 std | 库 | `TLockFreeStack` | **增强** |
| Work-stealing deque | runtime 内部 | crossbeam deque | `TWorkStealingDeque` | **对标** |
| Channel + close | `chan` + close | flume/async_channel | `TLockFreeChannel` (+ SPSC 变体) | **对标**（语义差见文档） |
| select | `select` | 库/手写 | `TLockFreeSelector` | **部分对标**（同类型 T；无 default 分支） |
| 并发 map | `sync.Map` | dashmap | `TShardedHashMap`（**分片锁**） | **对标精神**（诚实非 LF） |
| 内存回收 | GC | crossbeam epoch 等 | EBR + Hazard | **对标 Rust 无 GC 路径** |
| 生命周期 | GC + channel close | Drop/ownership | **Close → join → Free** | **硬契约**（必须教） |

### 2.2 已接入真实消费者（规模证明）

| 消费者 | 原语 | 状态 |
|--------|------|------|
| `async.loop` Post | T1 MPSC | H3-1 done |
| `thread.pool.worksteal` | T1 deque | H3-5 done |
| bag / multimap | T2 生产子集 | H3-2 done |

### 2.3 T2 — 规模策略（精炼，不膨胀）

| 档 | 策略 |
|----|------|
| **H3-2 生产子集** | bag + multimap：统一 Close/managed/progress |
| **Guarded / Available** | 可直 import；progress 诚实；不进默认门面 |
| **Experimental / R8** | RTM/NUMA/formal：研究隔离 |

**禁止**用 100+ 单元文件数对外宣称「已对标 Rust 生态」；对外只保证 **T1 + 文档化生产子集**。

### 2.4 Lockfree 质量目标

1. Progress 矩阵诚实（LF vs 分片锁 vs spin）
2. unmanaged 元素 + Close 纪律
3. Try\*Ex 诊断面
4. `verify-t1` + `verify-h3-consumers` + worksteal 常绿
5. 有信封的同机 Go/Rust bench（Q5）

### 2.5 Lockfree 规模结论

**T1 工具箱在「队列/通道/窃取/回收/分片 map」上已达写 runtime 的 Go/Rust 常用规模，部分超过 Go std。**
缺口主要在：**select 完整度、T2 可导航性、API 命名一致性、可复现跨语言证据** — 由 Q2–Q5 推进。

---

## 3. 成功标准（可验收）

| # | 标准 | 证据 |
|---|------|------|
| 1 | Atomic 首选路径文档 + 测试绿 | CONTRACT + `test_atomic` + `verify-t1` |
| 2 | T1 门面稳定、progress 诚实 | README 矩阵 + CONTRACT |
| 3 | 至少 2 个跨模块真实消费者 | async + thread worksteal |
| 4 | T2 生产推荐 ≤ 一页 | selection-guide + H3-2 |
| 5 | 无无信封绝对 Mops 营销 | bench-envelope + H3-4 |
| 6 | 清洁：hygiene、无产物、门面不膨胀 | `make hygiene` |

---

## 4. 非目标

- 替代 Go scheduler / goroutine
- 替代 Tokio / async Rust 全栈
- 把 T2 全量升默认门面
- invent R9；R8 静默生产化
- 无信封宣称吞吐碾压 Go/Rust

---

## 5. 执行入口

| 文档 | 角色 |
|------|------|
| [`quality-parity.md`](quality-parity.md) | Q0–Q5 执行阶段 |
| [`READY.md`](READY.md) | 状态入口 |
| [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) | atomic 契约 |
| [`CONTRACT.md`](CONTRACT.md) | lockfree 契约 |
| [`selection-guide.md`](selection-guide.md) | 选型（生产导航） |
