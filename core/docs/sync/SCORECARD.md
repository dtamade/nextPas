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

**contended 2T wall-clock**（warmup=1, samples=7, 2×200k ops, **median**）:

| ID | name | median ns/op | p95 | CV | notes |
|----|------|-------------:|----:|---:|-------|
| SC9 | Mutex/Contended2T | 250.6 | 250.7 | ~0% | TInstant wall; timer quantize-ish |
| SC10 | FutexMutex/Contended2T | 250.7 | 250.7 | ~0% | 与 SC9 同量级（争用主导） |

命令：`make -C core/benchmarks/nextpas.core.sync/bench_sync clean run`

---

## 决策（1.5–1.6）

| 议题 | 决定 | 证据 |
|------|------|------|
| 公开 `RecursiveMutex` | **已上线** | `test_sync` reentry + CondVar 配对 |
| `TSyncPool` 门面化 | **advanced** + 强制 `TPoolItem` | Pool facade + 负向测试 |
| Channel / Latch / Notify / Scoped | **已上线** | `test_sync` 67 cases |
| Channel 超时 | **`csrTimeout`/`crrTimeout`** | Channel timeout distinct |
| CondVar WaitTimeout 错误 | TIMEDOUT→False，其它 raise | CONTRACT 1.6 |
| 删除 `Do_` | **禁止** | `DoOnce(TSyncProc)` 重载 |

**SC9/SC10 噪声**：2T wall-clock 受调度/计时量化影响大，CV 与绝对值仅作趋势，非 CI 硬门。

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-20 | 初版 SC1–SC6 基线 |
| 2026-07-20 | SC7/SC8 正确性；SC9/SC10 单次 wall |
| 2026-07-20 | SC9/SC10 multi-sample median/p95；Destroy error surface |
