# nextpas.core.sync 代码契约

**模块路径**：`core/src/nextpas.core.sync*.pas`
**层级**：L1
**Owner**：sync lane（`.worktrees/sync`）
**最后更新**：2026-07-20
**版本**：1.3
**权威性**：本文件为 sync 模块契约 SSOT。仓库索引 `docs/contracts/sync.md` 仅作入口，不得维护第二套 API 描述。

---

## 1. 接口契约

### 1.1 源文件

| 文件 | 职责 |
|------|------|
| `nextpas.core.sync.pas` | 门面：工厂 + 类型 re-export |
| `nextpas.core.sync.base.pas` | `TLockState`、`TOnceProc`、`TBarrierWaitResult` |
| `nextpas.core.sync.intf.pas` | 全部公开 interface |
| `nextpas.core.sync.mutex.pas` | `TMutex`、`TFutexMutex` |
| `nextpas.core.sync.rwlock.pas` | `TRWLock` |
| `nextpas.core.sync.condvar.pas` | `TCondVar` |
| `nextpas.core.sync.spinlock.pas` | `TSpinLock` |
| `nextpas.core.sync.waitgroup.pas` | `TWaitGroup` |
| `nextpas.core.sync.once.pas` | `TOnce` |
| `nextpas.core.sync.semaphore.pas` | `TSemaphore` |
| `nextpas.core.sync.barrier.pas` | `TBarrier` |
| `nextpas.core.sync.event.pas` | manual / auto reset Event |
| `nextpas.core.sync.pool.pas` | `TSyncPool`（**实验**；未进门面） |

### 1.2 门面工厂

```pascal
function Mutex: IMutex;
function FutexMutex: IMutex;
function RWLock: IRWLock;
function WaitGroup: IWaitGroup;
function CondVar: ICondVar;
function Once: IOnce;
function SpinLock: ISpinLock;
function Semaphore(const AInitial: Int32 = 1): ISemaphore;
function Barrier(const ACount: Int32): IBarrier;
function Event(const AManualReset: Boolean = True): IEvent;
```

### 1.3 核心接口（live）

```pascal
ILock = interface
  procedure Acquire;
  function TryAcquire: Boolean;
  procedure Release;
  function Lock: ILockGuard;
end;

IMutex = interface(ILock)
  function NativeHandle: Pointer;
end;

IRWLock = interface
  procedure AcquireRead;
  function TryAcquireRead: Boolean;
  procedure AcquireWrite;
  function TryAcquireWrite: Boolean;
  procedure ReleaseRead;
  procedure ReleaseWrite;
  function ReadLock: ILockGuard;
  function WriteLock: ILockGuard;
end;

IWaitGroup = interface
  procedure Add(const ACount: Int32 = 1);
  procedure Done;
  procedure Wait;
end;

ICondVar = interface
  procedure Wait(const AMutex: IMutex);
  function WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
  procedure Signal;
  procedure Broadcast;
end;

IOnce = interface
  procedure Do_(const AProc: TOnceProc);  // 命名冻结：避开关键字 Do
  function Done: Boolean;
end;

ISpinLock = interface(ILock)
end;

ISemaphore = interface
  procedure Acquire;
  function TryAcquire: Boolean;
  function TryAcquireTimeout(const ATimeoutNs: Int64): Boolean;
  procedure Release;
  procedure Release(const ACount: Int32);
  function Available: Int32;
end;

IBarrier = interface
  function Wait: TBarrierWaitResult;
end;

IEvent = interface
  procedure SetEvent;
  procedure Reset;
  procedure Wait;
  function WaitTimeout(const ATimeoutNs: Int64): Boolean;
  function IsSet: Boolean;
end;
```

**已废弃文档名（不得再写）**：`ILockable`、`IRWLockable`、`DoCall`、`WaitFor` / `WaitForTimeout`（毫秒版签名）。

### 1.4 原语语义摘要

| 原语 | 实现要点 | 公开级别 |
|------|----------|----------|
| `TMutex` | `platform_mutex_init(..., PLATFORM_MUTEX_ERRORCHECK)`，**非递归**；实现 `INativeMutex` | stable |
| `TFutexMutex` | CAS 三态 + spin + address-wait；**仅** `IMutex`（不可配 CondVar） | advanced |
| `TRWLock` | platform rwlock；`ReleaseRead`→`rdunlock`，`ReleaseWrite`→`wrunlock` | stable |
| `TCondVar` | platform condvar；**仅**可与标准 `TMutex` 配对 | stable |
| `TSpinLock` | atomic flag + `CpuPause` / `platform_thread_yield` | stable |
| `TWaitGroup` | atomic counter + address-wait | stable |
| `TOnce` | 三态 INIT/RUNNING/DONE；回调异常回滚到 INIT | stable |
| `TSemaphore` | atomic count + address-wait | stable |
| `TBarrier` | generation + address-wait；可复用 | stable |
| `IEvent` | manual：generation 奇偶；auto：单 permit CAS | stable |
| `TSyncPool` | TLS freelist + global `IMutex`；**非门面** | experimental |

### 1.5 CondVar 配对规则

- `ICondVar.Wait` / `WaitTimeout` 参数类型为 **`INativeMutex`**（编译期隔离）
- `NativeHandle` 必须指向完整 `TPlatformMutex`
- `TFutexMutex` 不实现 `INativeMutex`，无法传入 Wait

### 1.6 TSyncPool（实验）

- 单元：`nextpas.core.sync.pool`（**不**由门面 re-export）
- TLS freelist：每线程链表按 pool `Owner` 隔离（**允许多 pool 同线程**）
- 冷路径全局栈：nextpas `IMutex`（`TMutex`）
- `DrainTLS`：线程退出前归还 TLS freelist，避免 heaptrc 假泄漏

---

## 2. 不变量

- **[INV-1]** 默认 `Mutex` 为 **非递归** ERRORCHECK；同线程重入由平台/实现报错，非合法用法
- **[INV-2]** `Once.Do_` 在成功路径上回调恰好执行一次；异常路径不置 DONE，允许重试
- **[INV-3]** `WaitGroup.Done` 次数不得超过 `Add` 总和；超出 raise
- **[INV-4]** `WaitGroup.Add` 要求 `ACount > 0`
- **[INV-5]** 多个读者可并发持有 `IRWLock`；写者排他
- **[INV-6]** `CondVar` 不得与 `TFutexMutex` 配对
- **[INV-7]** 门面不依赖 `sync.pool`
- **[INV-8]** L1 sync 实现（含 `sync.pool`）不直接依赖 FPC 平台同步原语 / 平台单元

---

## 3. 错误处理

| 场景 | 行为 |
|------|------|
| `TMutex` platform init/lock/unlock 失败 | raise `ENextPasError` |
| `WaitGroup.Add` ≤ 0 | raise `ENextPasError` |
| `WaitGroup.Done` 导致计数 < 0 | raise `ENextPasError` |
| `Semaphore` 初始 < 0 | raise `EArgumentError` |
| `Semaphore.Release(count)` count ≤ 0 | raise `EArgumentError` |
| `Barrier` count ≤ 0 | raise `EArgumentError` |
| `CondVar` + 非 `INativeMutex` | **编译期**不可传入（`ICondVar.Wait` 签名） |
| `Once` 回调异常 | 状态回 INIT，异常上抛，可再次 `Do_` |
| `CondVar.Wait` 非持有者 / 错误 handle | 未定义（调用方契约） |
| Destroy 时仍持锁 | **调用方必须先释放**。若 `platform_*_destroy` 返回非 0（POSIX 常为 EBUSY），L1 **raise**；若宿主返回 0 则无 L1 检测。不得依赖「Destroy 自动解锁」 |
| 公开 `RecursiveMutex` | **暂缓** — 默认 ERRORCHECK 非递归；无生产消费者前不扩 API |
| `TSyncPool` 进门面 | **暂缓** — 仍 `sync.pool` experimental |

---

## 4. 线程安全

所有公开同步原语本身设计为多线程安全基础设施。

| 原语 | 并发模型 |
|------|----------|
| `IMutex` / `ISpinLock` | 互斥 |
| `IRWLock` | 多读单写 |
| `ISemaphore` | 最多 N 并发 permit |
| `IEvent` | 等待 / 唤醒 |
| `ICondVar` | 与合法 `IMutex` 配合 |
| `IBarrier` | N 线程汇合 |
| `IOnce` | 单次初始化 |
| `IWaitGroup` | 等待 N 个完成 |
| `TSyncPool` | TLS 无锁热路径 + global `IMutex` 冷路径 |

---

## 5. 内存管理

- 门面原语均为接口（`TInterfacedObject`），引用计数管理生命周期
- `TMutex` / `TRWLock` / `TCondVar` 在构造/析构中 init/destroy 平台句柄
- `ILockGuard` 在析构时 `Release`（Mutex / SpinLock / RWLock 读/写 guard）
- `TSyncPool`：对象生命周期由池拥有；Get 不 Create、Put 不 Free（预分配/工厂模式）

---

## 6. 测试覆盖

| Gate | 路径 | 说明 |
|------|------|------|
| 核心原语 | `core/tests/nextpas.core.sync/test_sync` | 行为 + 关键错误路径 |
| TSyncPool | `core/tests/nextpas.core.sync/test_sync_pool` | TLS / 并发 / Drain |
| 源契约 | `core/tests/nextpas.core.sync/test_sync_source_contracts` | 门面/边界/非递归默认 |

```bash
make -C core/tests/nextpas.core.sync test
```

---

## 7. 依赖关系

**依赖**

- `nextpas.core.platform.sync`（mutex/rwlock/condvar/address-wait）
- `nextpas.core.platform.thread`（SpinLock yield）
- `nextpas.core.atomic`（Event / Once / Semaphore / Barrier）
- `nextpas.core.errors` / `exception`（错误类型）
- `nextpas.core.time.base`（Semaphore 超时 deadline）

**被依赖（典型）**

- http、tls、thread、test.runner、collections.concurrent、net.server、config、tui 等

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-01 | 1.0 | 初始版本（含已过时的递归 Mutex / ILockable 描述） |
| 2026-07-20 | 1.1 | 以 live source 重写 SSOT；标明 FutexMutex/Pool 级别；删除空 posix_fallback 叙述 |
| 2026-07-20 | 1.2 | `TSyncPool` 冷路径改 nextpas `IMutex`；移除 FPC CriticalSection 债 |
| 2026-07-20 | 1.3 | per-pool TLS；INativeMutex；Win compile gate；SCORECARD |
