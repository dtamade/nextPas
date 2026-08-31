# nextpas.core.sync 代码契约

**模块路径**：`core/src/nextpas.core.sync*.pas`
**层级**：L1
**Owner**：sync lane（`.worktrees/sync`）
**最后更新**：2026-08-31
**版本**：1.6.2
**权威性**：本文件为 sync 模块契约 SSOT。仓库索引 `docs/contracts/sync.md` 仅作入口，不得维护第二套 API 描述。

---

## 1. 接口契约

### 1.1 源文件

| 文件 | 职责 |
|------|------|
| `nextpas.core.sync.pas` | 门面：工厂 + 类型 re-export |
| `nextpas.core.sync.base.pas` | `TLockState`、`TOnceProc`、`TSyncProc`、`TBarrierWaitResult`、Channel 结果枚举 |
| `nextpas.core.sync.intf.pas` | 全部公开 interface |
| `nextpas.core.sync.errors.pas` | 内部错误映射（`SyncRaise*`）；**不**进门面 re-export |
| `nextpas.core.sync.mutex.pas` | `TMutex`、`TFutexMutex` |
| `nextpas.core.sync.rwlock.pas` | `TRWLock` |
| `nextpas.core.sync.condvar.pas` | `TCondVar` |
| `nextpas.core.sync.spinlock.pas` | `TSpinLock` |
| `nextpas.core.sync.waitgroup.pas` | `TWaitGroup` |
| `nextpas.core.sync.once.pas` | `TOnce` |
| `nextpas.core.sync.semaphore.pas` | `TSemaphore` |
| `nextpas.core.sync.barrier.pas` | `TBarrier` |
| `nextpas.core.sync.event.pas` | manual / auto reset Event |
| `nextpas.core.sync.latch.pas` | one-shot countdown Latch |
| `nextpas.core.sync.notify.pas` | sticky NotifyOne / NotifyAll |
| `nextpas.core.sync.channel.pas` | bounded MPMC `Pointer` channel |
| `nextpas.core.sync.scoped.pas` | `WithLock` / `WithReadLock` / `WithWriteLock` / Guard |
| `nextpas.core.sync.pool.pas` | `TSyncPool`（**advanced**；门面 re-export） |

### 1.2 门面工厂

```pascal
function Mutex: INativeMutex;
function RecursiveMutex: INativeMutex;
function FutexMutex: IMutex;
function RWLock: IRWLock;
function WaitGroup: IWaitGroup;
function CondVar: ICondVar;
function Once: IOnce;
function SpinLock: ISpinLock;
function Semaphore(const AInitial: Int32 = 1): ISemaphore;
function Barrier(const ACount: Int32): IBarrier;
function Event(const AManualReset: Boolean = True): IEvent;
function Latch(const ACount: Int32): ILatch;
function Notify: INotify;
function Channel(const ACapacity: SizeInt): IChannel;  // capacity >= 1
function CreateSyncPool(AFactory: TPoolFactory): TSyncPool;

procedure WithLock(const ALock: ILock; const AProc: TSyncProc);
procedure WithReadLock(const ARW: IRWLock; const AProc: TSyncProc);
procedure WithWriteLock(const ARW: IRWLock; const AProc: TSyncProc);
function Guard(const ALock: ILock): ILockGuard;
function ReadGuard(const ARW: IRWLock): ILockGuard;
function WriteGuard(const ARW: IRWLock): ILockGuard;
```

### 1.3 核心接口（live）

```pascal
ILock = interface
  procedure Acquire;
  function TryAcquire: Boolean;
  procedure Release;
  function Lock: ILockGuard;
end;

{ Application mutex — no native handle escape hatch. }
IMutex = interface(ILock)
end;

{ Platform-backed mutex: NativeHandle → TPlatformMutex.
  Required partner for ICondVar.Wait / WaitTimeout. }
INativeMutex = interface(IMutex)
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
  function WaitTimeout(const ATimeoutNs: Int64): Boolean;
  function WaitTimeout(const ATimeout: TDuration): Boolean;
end;

ICondVar = interface
  procedure Wait(const AMutex: INativeMutex);
  function WaitTimeout(const AMutex: INativeMutex; const ATimeoutNs: Int64): Boolean;
  function WaitTimeout(const AMutex: INativeMutex; const ATimeout: TDuration): Boolean;
  procedure Signal;
  procedure Broadcast;
end;

IOnce = interface
  procedure Do_(const AProc: TOnceProc);      // 命名冻结：避开关键字 Do
  procedure DoOnce(const AProc: TOnceProc);   // 别名 ≡ Do_
  procedure DoOnce(const AProc: TSyncProc); // 闭包重载
  function Done: Boolean;
end;

ISpinLock = interface(ILock)
end;

ISemaphore = interface
  procedure Acquire;
  function TryAcquire: Boolean;
  function TryAcquireTimeout(const ATimeoutNs: Int64): Boolean;
  function TryAcquireTimeout(const ATimeout: TDuration): Boolean;
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
  function WaitTimeout(const ATimeout: TDuration): Boolean;
  function IsSet: Boolean;
end;

ILatch = interface
  procedure CountDown(const ACount: Int32 = 1);
  procedure Wait;
  function WaitTimeout(const ATimeoutNs: Int64): Boolean;
  function WaitTimeout(const ATimeout: TDuration): Boolean;
  function TryWait: Boolean;
  function Remaining: Int32;
end;

INotify = interface
  procedure NotifyOne;
  procedure NotifyAll;
  procedure Wait;
  function WaitTimeout(const ATimeoutNs: Int64): Boolean;
  function WaitTimeout(const ATimeout: TDuration): Boolean;
end;

IChannel = interface
  function TrySend(AItem: Pointer): TChannelSendResult;
  function Send(AItem: Pointer): Boolean;
  function TryRecv(out AItem: Pointer): TChannelRecvResult;
  function Recv(out AItem: Pointer): Boolean;
  function SendTimeout(...): TChannelSendResult;
  function RecvTimeout(...): TChannelRecvResult;
  procedure Close;
  function IsClosed: Boolean;
  function Len: SizeInt;
  function Cap: SizeInt;
end;

{ Channel result enums (nextpas.core.sync.base; uses that unit for csr*/crr* symbols) }
TChannelSendResult = (csrOk, csrClosed, csrFull, csrTimeout);
TChannelRecvResult = (crrOk, crrClosed, crrEmpty, crrTimeout);
```

**超时约定**

- 纳秒重载：`ATimeoutNs` 为 `Int64`（ns）
- `TDuration` 重载：转发到 `.AsNanoseconds`（与 `nextpas.core.time.base` 对齐）
- 多数 `WaitTimeout`：`Boolean` — `True` = 成功/未超时，`False` = 超时
- **Channel**：超时**不得**折叠为 Full/Empty — 使用 `csrTimeout` / `crrTimeout`

**Channel 结果矩阵**

| 操作 | 成功 | 关闭 | 满/空 | 超时 |
|------|------|------|-------|------|
| `TrySend` | `csrOk` | `csrClosed` | `csrFull` | — |
| `SendTimeout` | `csrOk` | `csrClosed` | (wait) | `csrTimeout` |
| `TryRecv` | `crrOk` | `crrClosed` | `crrEmpty` | — |
| `RecvTimeout` | `crrOk` | `crrClosed` | (wait) | `crrTimeout` |
| `Send`/`Recv` | `True` | `False`（Recv 排空后） | 阻塞 | — |

**决议（1.6.1 / F-R1）**：阻塞 `Send`/`Recv` **保持 `Boolean`**（成功 vs 关闭/失败），与 Go channel 一致；满/空只体现在阻塞或 `Try*`/`*Timeout` 枚举。**不**将 `Send`/`Recv` 改为枚举返回（破坏面 > 收益）。

**枚举符号可见性**：FPC 门面 type alias **不**导入 `csrOk` 等成员。消费者请 `uses nextpas.core.sync, nextpas.core.sync.base`。

**已废弃文档名（不得再写）**：`ILockable`、`IRWLockable`、`DoCall`、`WaitFor` / `WaitForTimeout`（毫秒版签名）、`IMutex.NativeHandle`（已迁至 `INativeMutex`）。
**冻结**：`IOnce.Do_` 公开名不删除；`DoOnce` 为别名 + `TSyncProc` 重载。

### 1.4 原语语义摘要

| 原语 | 实现要点 | 公开级别 |
|------|----------|----------|
| `TMutex` | `PLATFORM_MUTEX_ERRORCHECK`，**非递归**；`INativeMutex`；`FHandle` private | stable |
| `TRecursiveMutex` | `PLATFORM_MUTEX_RECURSIVE`；`INativeMutex`（可配 CondVar） | stable |
| `TFutexMutex` | CAS 三态 + address-wait；**仅** `IMutex` | advanced |
| `TRWLock` | platform rwlock；`FHandle` private；`Release*` 忽略 unlock 返回值 | stable |
| `TCondVar` | 仅配对 `INativeMutex`；`WaitTimeout`：TIMEDOUT→False，其它非 0→raise | stable |
| `TSpinLock` | atomic flag + yield | stable |
| `TWaitGroup` | 可动态 `Add`；`WaitTimeout` | stable |
| `TOnce` | `Do_` / `DoOnce(TOnceProc|TSyncProc)`；异常回 INIT | stable |
| `TSemaphore` | atomic + address-wait | stable |
| `TBarrier` | 可复用 generation | stable |
| `IEvent` | manual（默认）/ auto；默认 `Event(True)` = manual | stable |
| `ILatch` | **一次性**；`CountDown` 会使剩余为负 → raise；到 0 后 no-op | stable |
| `INotify` | `NotifyOne` 粘性 permit；`NotifyAll` = 清 permit + epoch（只醒当前 waiter，非粘性广播） | stable |
| `IChannel` | 有界 MPMC `Pointer`；`csrTimeout`/`crrTimeout` 独立 | stable |
| Scoped | `WithLock`/`WithReadLock`/`WithWriteLock` + `Guard*` | stable |
| `TSyncPool` | TLS freelist；**强制** `TPoolItem`；门面 advanced | **advanced** |

### 1.5 CondVar 配对规则

- `ICondVar.Wait` / `WaitTimeout` 参数类型为 **`INativeMutex`**（编译期隔离）
- `NativeHandle` 必须指向完整 `TPlatformMutex`（仅经接口方法暴露，不公开字段）
- `TFutexMutex` 不实现 `INativeMutex`，无法传入 Wait
- `WaitTimeout`：`0` → True；`PLATFORM_ERR_TIMEDOUT` → False；**其它** → `EInvalidOperationError`

### 1.6 TSyncPool（advanced）

- 单元：`nextpas.core.sync.pool`；门面 re-export `TSyncPool` / `CreateSyncPool` / builder 类型
- 工厂返回值与 `Put` 参数必须是 **`TPoolItem` 实例**（`TObject is TPoolItem`）；否则 `EArgumentError`
- TLS freelist：按 pool `Owner` 隔离；冷路径 nextpas `IMutex`
- `DrainTLS`：线程退出前归还 TLS freelist

### 1.6b Notify 语义（对齐 tokio `Notify`）

- `NotifyOne`：存款 sticky permit + wake one；无 waiter 时后续 `Wait` 立即返回
- `NotifyAll`：清空 permits，bump epoch，wake all **当前** waiter；**不**给迟到 `Wait` 粘性广播
- 需要粘性全员可见信号 → 使用 `Event(manual)`

### 1.7 Latch vs WaitGroup vs Barrier

| | Latch | WaitGroup | Barrier |
|--|-------|-----------|---------|
| 可复用 | 否 | 是（Add 再次） | 是（generation） |
| 动态增加 | 否 | `Add` | 否 |
| 典型用途 | 启动门闩 | 任务完成汇合 | 阶段同步 |

### 1.8 通道选型（sync / thread / lockfree / async）

| 需求 | 选用 |
|------|------|
| L1 有界 `Pointer` 同步 MPMC | **`sync.Channel`** |
| 类型安全线程间队列 | **`thread.IChannel<T>`** |
| 无锁/高性能通道 | **`lockfree.channel`** |
| 事件循环回调式 | **`async.IAsyncChannel`** |

| | `sync.Channel` | `async.IAsyncChannel` |
|--|----------------|------------------------|
| 模型 | 阻塞 / try / 超时 | 事件循环回调 |
| 载荷 | `Pointer` | 原始字节块 |
| Owner | L1 sync | L2/L3 async |

### 1.9 消费者线程模型

- 测试 / 示例 / 本模块 bench **禁止**直接 `uses SysUtils` / `Classes` / `SyncObjs`
- 多线程任务使用 `nextpas.core.thread.base.TWorkerThread`（或模块内薄包装），不使用 FPC `TThread`

---

## 2. 不变量

- **[INV-1]** 默认 `Mutex` 为 **非递归** ERRORCHECK；`RecursiveMutex` 显式递归
- **[INV-2]** `Once.Do_` / `DoOnce` 成功路径回调恰好一次；异常路径不置 DONE
- **[INV-3]** `WaitGroup.Done` 不得超过 `Add` 总和 → `EInvalidOperationError`
- **[INV-4]** `WaitGroup.Add` / `Latch.CountDown` 要求正计数；否则 `EArgumentError`（Latch 过量 → `EInvalidOperationError`）
- **[INV-5]** 多个读者可并发持有 `IRWLock`；写者排他
- **[INV-6]** `CondVar` 不得与 `TFutexMutex` 配对
- **[INV-7]** 门面 re-export pool（advanced）；**不** re-export `sync.errors`
- **[INV-8]** L1 sync 实现不直接依赖 FPC 平台单元 / `SysUtils` / `Classes` / `SyncObjs`
- **[INV-9]** `FHandle` **private**；仅 `INativeMutex.NativeHandle` 暴露 mutex 指针
- **[INV-10]** `Channel` capacity ≥ 1；`Close` 后 `Send` 失败，`Recv` 排空后返回 False
- **[INV-11]** `Latch` 不可复用；`Remaining` 到 0 后 `CountDown` 为 no-op

---

## 3. 错误处理

统一通过 `nextpas.core.sync.errors` 抛出 `nextpas.core.errors` 类型（非 FPC `SysUtils.Exception` 专用路径）：

| 场景 | 行为 |
|------|------|
| `TMutex` / `TRWLock` / `TCondVar` platform init/lock/destroy 失败 | `EInvalidOperationError`，消息含 op 名 + 平台码名 |
| `TCondVar.WaitTimeout` | `TIMEDOUT` → False；其它非 0 → raise |
| `TRWLock.ReleaseRead/Write` | **忽略** unlock 返回值（平台常为 0；与 Acquire 不对称，有意） |
| `WaitGroup.Add` ≤ 0 | `EArgumentError` |
| `WaitGroup.Done` 导致计数 < 0 | `EInvalidOperationError` |
| `Semaphore` 初始 < 0 | `EArgumentError` |
| `Semaphore.Release(count)` count ≤ 0 | `EArgumentError` |
| `Barrier` count ≤ 0 | `EArgumentError` |
| `CondVar` + 非 `INativeMutex` | **编译期**不可传入 |
| `Once` 回调异常 | 状态回 INIT，异常上抛，可再次 `Do_` / `DoOnce` |
| `CondVar.Wait` 非持有者 / 错误 handle | 未定义（调用方契约） |
| Destroy 时仍持锁 | **调用方必须先释放**。若 `platform_*_destroy` 返回非 0，L1 **raise** |
| `TSyncPool` 非 `TPoolItem` | `EArgumentError` |
| `Channel` 无界 / 泛型载荷 | **暂缓** |
| 无缓冲 rendezvous channel | **暂缓** |
| 公开 API 重命名 `Do_` | **禁止** |

---

## 4. 线程安全

所有公开同步原语本身设计为多线程安全基础设施。

| 原语 | 并发模型 |
|------|----------|
| `IMutex` / `ISpinLock` | 互斥 |
| `IRWLock` | 多读单写 |
| `ISemaphore` | 最多 N 并发 permit |
| `IEvent` | 等待 / 唤醒 |
| `ICondVar` | 与合法 `INativeMutex` 配合 |
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
| 核心原语 | `core/tests/nextpas.core.sync/test_sync` | 行为 + Channel timeout 区分 + Notify/Once/Pool 负向；`TWorkerThread` |
| TSyncPool | `core/tests/nextpas.core.sync/test_sync_pool` | TLS / 并发 / Drain；`TWorkerThread` |
| 源契约 | `core/tests/nextpas.core.sync/test_sync_source_contracts` | 门面/边界/RTL 隔离/非递归默认 |

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
- `nextpas.core.time.base`（`TDuration` 超时重载）
- `nextpas.core.base`（`IntToStr` 等基础工具，经 errors 使用）

**被依赖（典型）**

- http、tls、thread、test.runner、collections.concurrent、net.server、config、tui 等

**禁止依赖（实现 / 本模块测试与示例）**

- FPC `SysUtils`、`Classes`、`SyncObjs`、`Windows`、`BaseUnix`、`PThreads`（应走 platform / thread）

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-01 | 1.0 | 初始版本（含已过时的递归 Mutex / ILockable 描述） |
| 2026-07-20 | 1.1 | 以 live source 重写 SSOT；标明 FutexMutex/Pool 级别；删除空 posix_fallback 叙述 |
| 2026-07-20 | 1.2 | `TSyncPool` 冷路径改 nextpas `IMutex`；移除 FPC CriticalSection 债 |
| 2026-07-20 | 1.3 | per-pool TLS；INativeMutex；Win compile gate；SCORECARD |
| 2026-07-20 | 1.4 | `WaitTimeout`/`TryAcquireTimeout` `TDuration` 重载；`DoOnce` 别名；`WaitGroup.WaitTimeout`；`sync.errors` 统一错误；`FHandle` private；测试/示例/bench 禁用 SysUtils/Classes/SyncObjs，改 `TWorkerThread` |
| 2026-07-20 | 1.5 | `RecursiveMutex`；`ILatch`/`INotify`/`IChannel`；Scoped 组合器；`TSyncPool` 门面 advanced re-export；`Do_` 仍冻结 |
| 2026-07-21 | 1.6 | Channel `csrTimeout`/`crrTimeout`；CondVar WaitTimeout 区分 TIMEDOUT/raise；NotifyAll 清 permit；`DoOnce(TSyncProc)`；Pool 强制 `TPoolItem` |
| 2026-07-21 | 1.6.1 | 文档决议：Send/Recv 保持 Boolean；通道选型表；N1 竞态/异常回归测试 |
| 2026-08-31 | 1.6.2 | 文档时效刷新 | Claude |
