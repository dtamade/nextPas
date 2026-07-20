# nextpas.core.sync Scorecard

**状态**: 初版基线（SC1–SC6）
**日期**: 2026-07-20
**环境**: Linux x86_64, 44 cores, FPC 3.3.1
**权威入口（正确性）**: `make -C core/tests/nextpas.core.sync test`
**微基准入口**: `make -C core/benchmarks/nextpas.core.sync/bench_sync run`

数字为单机 uncontended 快照，**不是** CI 硬门；改热路径后应刷新本表。

---

## 运行

```bash
# 正确性（优先）
make -C core/tests/nextpas.core.sync test

# uncontended 原语微基准
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
| SC7 | FutexMutex 2T contention | `test_sync` FutexMutex contention | 正确性（无死锁/漏递增） |
| SC8 | Event multi-waiter / auto single-winner | `test_sync` Event manual/auto multi | 正确性 |

规则：

- 正确性 gate 红则禁止用 SCORECARD 宣称提升。
- 热路径改动至少刷新 SC1–SC3；RWLock 改动刷新 SC4–SC5；pool 改动刷新 SC6。
- 不与 Go/Rust 绑死阈值；对标仅作人工旁注。

---

## 基线快照（2026-07-20）

**bench_sync**（MinDuration 50ms, MinSamples 5, 1M iters/sample）:

| ID | name | ns/op | ops/s | notes |
|----|------|------:|------:|-------|
| SC1 | Mutex/LockUnlock | 22.4 | 44.6M | ERRORCHECK platform mutex |
| SC2 | FutexMutex/LockUnlock | 22.8 | 43.9M | uncontended CAS path |
| SC3 | SpinLock/LockUnlock | 24.0 | 41.7M | |
| SC4 | RWLock/Read | 27.6 | 36.2M | |
| SC5 | RWLock/Write | 40.4 | 24.8M | |
| — | Mutex/TryAcquire | 23.7 | 42.2M | supplemental |

**pool**（test_sync_pool Get/Put）:

| ID | subject | result |
|----|---------|--------|
| SC6 | 1M Get/Put single-thread | ~37M ops/s（本机一次：27ms） |

**contended / multi-waiter（正确性门，2026-07-20 基线 a304e5b09）**:

| ID | result |
|----|--------|
| SC7 | `FutexMutex contention` pass（阻塞→释放后 counter=1） |
| SC8 | manual multi-waiter 全醒；auto single-winner 恰好 1 |

数值型 contended ns/op 待后续 `bench_sync` 扩展；本批以 correctness 为准。

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-20 | 初版 SC1–SC6 基线 |
| 2026-07-20 | SC7/SC8 正确性 contended 场景 |
