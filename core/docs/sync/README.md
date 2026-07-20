# nextpas.core.sync

L1 同步原语门面：为 nextpas.core 与上层模块提供稳定、可组合的线程同步词汇表。

**契约**：[CONTRACT.md](CONTRACT.md)
**目标树**：[GOAL_TREE.md](GOAL_TREE.md)
**Scorecard**：[SCORECARD.md](SCORECARD.md)
**层级**：L1（依赖 L0 `platform.sync` / `platform.thread`，以及 L1 `atomic`、`errors`、`time`）
**状态**：Maintenance + 契约硬化（接管基线进行中）

---

## 模块定位

`nextpas.core.sync` 拥有**应用级**同步原语的公开 API 与语义：

| 表面 | 单元 | 说明 |
|------|------|------|
| 门面 | `nextpas.core.sync` | 工厂函数 + 接口 re-export |
| 接口 | `nextpas.core.sync.intf` | `ILock` / `IMutex` / `IRWLock` / … |
| 基本类型 | `nextpas.core.sync.base` | `TOnceProc`、`TBarrierWaitResult` 等 |
| 实现 | `mutex` / `rwlock` / `condvar` / `spinlock` / `waitgroup` / `once` / `semaphore` / `barrier` / `event` | 各原语实现 |
| 实验旁路 | `nextpas.core.sync.pool` | `TSyncPool`（**未**进门面） |

宿主 ABI（pthread / SRWLOCK / futex / address-wait）由 **L0 `platform.sync`** 拥有；本模块只消费其统一函数层。

---

## Owner 边界

| 能力 | Owner | 本模块 stance |
|------|-------|----------------|
| mutex / rwlock / condvar / address-wait ABI | `platform.sync` | 只调用 `platform_*` |
| 原子 load/CAS/fence | `atomic` | Event / Once / Semaphore / Barrier 等用户态原语 |
| 线程创建 / yield | `thread` / `platform.thread` | SpinLock backoff yield |
| 应用级 Mutex / RWLock / WaitGroup / … | **`sync`（本 lane）** | 公开门面 |
| async 内 Mutex / Channel / CondVar | `async` | 不同事件循环语义，不混用 |
| thread pool / worksteal | `thread` | 可消费 sync 原语 |
| `TSyncPool` | `sync.pool` | 实验表面；**per-pool TLS**；冷路径 nextpas `IMutex` |

**禁止**

- 在 L1 sync 实现中直接 `uses` FPC `Windows` / `BaseUnix` / `PThreads`（应走 `platform.sync`）
- 把 platform 层语义缺陷用 L1 临时 workaround 永久掩盖（优先修 L0 契约）
- 未经契约更新就改变公开工厂/接口签名

---

## 公开工厂（门面）

```pascal
function Mutex: INativeMutex;           // platform ERRORCHECK，非递归；可配 CondVar
function FutexMutex: IMutex;            // 高级：CAS + address-wait；不可配 CondVar
function RWLock: IRWLock;
function WaitGroup: IWaitGroup;
function CondVar: ICondVar;             // Wait 需要 INativeMutex
function Once: IOnce;
function SpinLock: ISpinLock;
function Semaphore(AInitial: Int32 = 1): ISemaphore;
function Barrier(ACount: Int32): IBarrier;
function Event(AManualReset: Boolean = True): IEvent;
```

超时参数在 live API 中为 **纳秒**（`WaitTimeout` / `TryAcquireTimeout`）。

---

## 测试入口

```bash
# 推荐：模块聚合
make -C core/tests/nextpas.core.sync test

# 或 focused
make focused FOCUS=core/tests/nextpas.core.sync/test_sync
make focused FOCUS=core/tests/nextpas.core.sync/test_sync_pool
make focused FOCUS=core/tests/nextpas.core.sync/test_sync_source_contracts
```

| Gate | 路径 | 说明 |
|------|------|------|
| 原语行为 | `test_sync` | Mutex / Futex / RWLock / CondVar / Once / … |
| 对象池 | `test_sync_pool` | `TSyncPool` TLS freelist |
| 源契约 | `test_sync_source_contracts` | 门面/接口/边界防漂移 |
| Win compile | `test_sync_windows_compile_gate` | `-dNEXTPAS_FORCE_HOST_WINDOWS` -Cn |
| Darwin compile | `test_sync_darwin_compile_gate` | `-dNEXTPAS_FORCE_HOST_DARWIN` -Cn |
| FreeBSD compile | `test_sync_freebsd_compile_gate` | `-dNEXTPAS_FORCE_HOST_FREEBSD` -Cn |

Benchmark：`core/benchmarks/nextpas.core.sync/bench_sync/`

---

## 与相关模块

- **platform.sync**：L0 宿主同步基板；设计约定见 `core/docs/design-conventions.md` § platform.sync
- **atomic**：用户态无锁原语与内存序
- **async**：单线程事件循环上的异步同步原语（不同模型）
- **thread**：线程与池；消费本模块锁，不反向拥有同步词汇表

---

## 变更纪律

1. 改公开 API 或错误语义 → 同步更新 [CONTRACT.md](CONTRACT.md) + 行为/源契约测试
2. 跨 `platform.sync` 修改 → Ready 报告列出 cross-module 文件、理由与额外验证
3. 活动计划放 `core/docs/plans/` 或本 GOAL_TREE；不要把临时 task 文件带入主线
