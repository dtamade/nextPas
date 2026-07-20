# nextpas.core.sync Scorecard

**状态**: SC1–SC10（uncontended + correctness contended + 2T wall ns/op）
**日期**: 2026-07-20
**环境**: Linux x86_64, 44 cores, FPC 3.3.1
**权威入口（正确性）**: `make -C core/tests/nextpas.core.sync test`
**微基准入口**: `make -C core/benchmarks/nextpas.core.sync/bench_sync run`

数字为单机快照，**不是** CI 硬门；改热路径后应刷新本表。

---

## 运行

```bash
# 正确性（优先）
make -C core/tests/nextpas.core.sync test

# uncontended + 2T contended wall-clock
make -C core/benchmarks/nextpas.core.sync/bench_sync clean run

# pool 单线程吞吐（test 内嵌）
make focused FOCUS=core/tests/nextpas.core.sync/test_sync_pool
```

---

## 场景

| ID | 场景 | 命令/来源 | 指标 |
|----|------|-----------|------|
| SC1 | Mutex uncontended lock/unlock | `bench_sync` | ns/op, ops/s |
| SC2 | FutexMutex uncontended | `bench_sync` | ns/op, ops/s |
| SC3 | SpinLock uncontended | `bench_sync` | ns/op, ops/s |
| SC4 | RWLock read uncontended | `bench_sync` | ns/op, ops/s |
| SC5 | RWLock write uncontended | `bench_sync` | ns/op, ops/s |
| SC6 | TSyncPool Get/Put 单线程 1M | `test_sync_pool` | Mops/s |
| SC7 | FutexMutex 2T contention | `test_sync` | 正确性 |
| SC8 | Event multi-waiter / auto single-winner | `test_sync` | 正确性 |
| SC9 | Mutex 2T contended | `bench_sync` Contended2T | wall ns/op |
| SC10 | FutexMutex 2T contended | `bench_sync` Contended2T | wall ns/op |

规则：

- 正确性 gate 红则禁止用 SCORECARD 宣称提升。
- 热路径改动至少刷新 SC1–SC3；RWLock 改动刷新 SC4–SC5；pool 改动刷新 SC6；锁热路径改动刷新 SC9–SC10。
- SC9/SC10 为 wall-clock 粗测（2 线程 × 200k），噪声大，只作趋势对照。

---

## 基线快照（2026-07-20 · HEAD 对齐 main 后重跑）

**bench_sync uncontended**（MinDuration 50ms, MinSamples 5, 1M iters/sample）:

| ID | name | ns/op | ops/s | notes |
|----|------|------:|------:|-------|
| SC1 | Mutex/LockUnlock | 22.5 | 44.5M | ERRORCHECK platform mutex |
| SC2 | FutexMutex/LockUnlock | 22.4 | 44.7M | uncontended CAS path |
| SC3 | SpinLock/LockUnlock | 23.5 | 42.6M | |
| SC4 | RWLock/Read | 27.8 | 36.0M | |
| SC5 | RWLock/Write | 39.2 | 25.5M | |
| — | Mutex/TryAcquire | 22.9 | 43.6M | supplemental |

**pool**（test_sync_pool Get/Put）:

| ID | subject | result |
|----|---------|--------|
| SC6 | 1M Get/Put single-thread | ~37M ops/s（历史快照） |

**contended 正确性**:

| ID | result |
|----|--------|
| SC7 | `FutexMutex contention` pass |
| SC8 | manual multi-waiter 全醒；auto single-winner 恰好 1 |

**contended 2T wall-clock**（2×200k ops）:

| ID | name | ns/op | notes |
|----|------|------:|-------|
| SC9 | Mutex/Contended2T | ~250 | wall, not per-thread CPU |
| SC10 | FutexMutex/Contended2T | ~252 | wall; 与 SC9 同量级（争用主导） |

---

## 决策（暂缓）

| 议题 | 决定 |
|------|------|
| 公开 `RecursiveMutex` | **暂缓** — 默认 ERRORCHECK 非递归；无硬消费者前不扩 API |
| `TSyncPool` 门面化 | **暂缓** — 仍 experimental 旁路单元 |

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-20 | 初版 SC1–SC6 基线 |
| 2026-07-20 | SC7/SC8 正确性 contended |
| 2026-07-20 | bench 2T Contended2T；SC9/SC10 数值；决策表 |
