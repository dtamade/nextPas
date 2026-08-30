# nextpas.core.async 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas`（17 个源文件）
**层级**：L1（依赖 L0: base, sync）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：3.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| async.base | 基础类型 (TAsyncCallback, TAsyncTimerHandle) |
| async.timer | TTimerHeap (定时器堆) |
| async.loop | TAsyncLoop (**class** 事件循环) |
| async.task | TAsyncTask (异步任务状态机) |
| async.taskgroup | IAsyncTaskGroup (结构化并发) |
| async.shutdown | IAsyncShutdown (优雅关闭管理器) |
| async.timeout | IAsyncTimeout (通用超时包装器) |
| async.combinators | WhenAll/WhenAny 组合器 |
| async.retry | RetryWithBackoff 异步重试 |
| async.signal | IAsyncSignalHandler (异步信号处理) |
| async.buffer | IAsyncBufferPool (缓冲区池) |
| async.mutex | IAsyncMutex (异步互斥锁) |
| async.semaphore | IAsyncSemaphore (异步信号量) |
| async.channel | IAsyncChannel (异步通道) |
| async.condvar | IAsyncCondVar (异步条件变量) |
| async.cancellation | IAsyncCancellationToken (取消令牌/父子传播) |
| async.pas | 门面 (re-exports) |

### 1.2 核心类型

```pascal
{ 回调类型 }
TAsyncCallback = procedure(AContext: Pointer);
TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

{ TAsyncLoop — heap-owned class. Dependents store object refs (not owned).
  Create / Close / Free: Free→Destroy calls Close (Destroy does not re-raise).
  Close is idempotent; may re-raise poller abort-callback failures. }
TAsyncLoop = class
  constructor Create(AQueueDepth: UInt32 = 64);
  destructor Destroy; override;
  procedure Close;
  function IsValid: Boolean;
  procedure Run;
  procedure Stop;
  function Poll: Int32;
  function Schedule(const ADelay: TDuration; ACallback: TAsyncCallback; AContext: Pointer = nil): TAsyncTimerHandle;
  procedure Post(ACallback: TAsyncCallback; AContext: Pointer = nil);
  procedure Wake;
  // + PostEx/ScheduleEx OnDiscard, AsyncRead/Write/Accept/Recv/Send variants
end;

{ TAsyncTask }
TAsyncTask = record
  procedure Complete(AResult: Int32);
  procedure Fail(AResult: Int32);
  procedure Cancel;
  procedure Timeout;
  function IsDone: Boolean;
  function Status: TAsyncTaskStatus;
  procedure OnComplete(ACallback: TAsyncCallback; AContext: Pointer);
end;

{ IAsyncTaskGroup }
IAsyncTaskGroup = interface
  procedure RunTask(ACallback: TAsyncCallback; AContext: Pointer; const AOptions: TAsyncTaskGroupOptions);
  procedure CancelAll;
  procedure Drain(ADrainTimeoutMs: UInt32);
  procedure WaitAll;
  function ActiveCount: Integer;
  function CompletedCount: Integer;
  function IsDone: Boolean;
  function State: TAsyncTaskGroupState;
end;

{ IAsyncShutdown }
IAsyncShutdown = interface
  procedure RequestShutdown(ACode: Int32; const AReason: String);
  procedure OnShutdown(ACallback: TAsyncCallback; AContext: Pointer);
  procedure ForceClose;
  function Phase: TAsyncShutdownPhase;
  function Options: TAsyncShutdownOptions;
end;

{ IAsyncTimeout }
IAsyncTimeout = interface
  procedure Cancel;
  function IsDone: Boolean;
  function GetResult: Int32;
  function Status: TAsyncTimeoutResult;
  procedure OnComplete(ACallback: TAsyncCallback; AContext: Pointer);
end;
```

---

## 2. 不变量

- **[INV-1]** TAsyncLoop 是单线程的：所有回调在 loop 线程执行
- **[INV-2]** Post/Wake 是线程安全的：可从任意线程调用
- **[INV-3]** TAsyncTask 状态转换是单向的：idle→pending→completed/failed/cancelled/timedout
- **[INV-4]** IAsyncTaskGroup.ActiveCount 在最后一个任务完成时变为 0
- **[INV-5]** IAsyncShutdown 状态转换：Running→Draining→Closed/ForceClose
- **[INV-6]** IAsyncTimeout 超时回调和完成回调只触发一个（原子 CAS 保护）
- **[INV-7]** TAsyncLoop.Close 幂等；Destroy 调 Close 且不向外抛异常
- **[INV-8]** 依赖对象（mutex/channel/shutdown/…）存 `TAsyncLoop` 引用且**不拥有**；loop 必须活过依赖；释放顺序：先 nil 接口/依赖，再 `Loop.Free`
- **[INV-9]** 禁止 `FLoop := @ALoop` / `PAsyncLoop` 作为公共存储模式

---

## 3. 错误处理

| 场景 | 处理 |
|------|------|
| TaskGroup 任务失败 | 状态变为 agsFailed，可设置 agoFailFast 取消全部 |
| Shutdown 超时 | 状态变为 spForceClose |
| Timeout 超时 | 状态变为 atrTimedOut |
| Retry 达到最大重试次数 | 回调 arrMaxRetries |
| WhenAll 超时 | 触发 AOnComplete 回调 |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| TAsyncLoop | ❌ 单线程 | 所有回调在 loop 线程执行 |
| Post/Wake | ✅ | 可从任意线程调用 |
| IAsyncTaskGroup | ✅ | 内部使用 mutex |
| IAsyncShutdown | ✅ | 内部使用 mutex |
| IAsyncMutex | ✅ | 异步互斥锁 |
| IAsyncSemaphore | ✅ | 异步信号量 |
| IAsyncChannel | ✅ | 异步通道 |

---

## 5. 内存管理

- TFuture 内部引用计数，最后一个引用释放时清理
- TPromise 拥有结果槽位
- TTask 的 Proc 通过闭包捕获

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_async | 基本事件循环测试 (43 tests) |
| test_async_advanced | TaskGroup + Shutdown 高级模式 (12 tests) |
| test_async_bench | 性能基准测试 (4 tests) |
| test_async_combinators | WhenAll/WhenAny 组合器 (7 tests) |
| test_async_integration | 集成测试 (4 tests) |
| test_async_primitives | Timer + Loop + Mutex/Sem/Channel/CondVar 基础操作 (11→14+ tests) |
| test_async_retry | 异步重试机制 (5 tests) |
| test_async_stress | 压力测试 (13 tests) |
| test_async_timeout | 超时机制测试 (18 tests) |
| test_async_vectored_io | Vectored I/O scatter/gather (33 tests) |
| test_async_signal | 异步信号处理 (40 tests) |
| test_async_buffer | 缓冲区池 (43 tests) |
| **合计** | **12 个测试目录，233 tests** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-19 | 3.2 | Timeout 内核 cancel（TryCancelByContext） | Claude |
| 2026-07-19 | 3.1 | TAsyncLoop record→class；生命周期/Destroy 契约 | Claude |
| 2026-07-11 | 3.0 | 添加 Combinators/Retry/SyncPrimitives | Claude |
| 2026-07-11 | 2.0 | 添加 TaskGroup/Shutdown/Timeout 高级模式 | Claude |
| 2026-07-01 | 1.0 | 初始版本 | Claude |


### Close discard contract
- Unfired MPSC items: invoke `OnDiscard(Context)` if set, else free PostRef heap wrap only.
- Abandoned timers: Close/Recycle runs `OnDiscard` then clears entry.
- `CancelTimer` does not run OnDiscard.
- Dependents must release before `Loop.Free` (or ensure they never touch a closed loop).

### Channel backpressure (B1)
| API | Full channel behavior |
|-----|------------------------|
| `Send` / `TrySend` | Returns False immediately (try semantics) |
| `SendAsync` / `SendAsyncRef` | Copies payload into send-waiter queue; completes when space exists (or Close wakes waiter — check `IsClosed`) |
| `TryReceive` | Dequeues bytes then `DrainSenders` |
| `Receive` / `ReceiveRef` | Notify only; still call `TryReceive` for data |

- **Channel** = message/byte-chunk queue backpressure
- **IBackpressureController** (`net.async.backpressure`) = stream buffer + high/low watermarks + `OnStateChange` (Post on loop)

### Timeout I/O cancel (B2)
| Backend | Timer wins |
|---------|------------|
| io_uring | `TryCancelByContext` → `IORING_OP_ASYNC_CANCEL`; late CQE discarded by CAS |
| epoll | Drop pending op + internal `-ECANCELED` to release `TimeoutCtx` (not kernel cancel) |
| kqueue | Same best-effort as epoll (pending drop + internal `-ECANCELED`) |
| IOCP | `TryCancelByContext` → `CancelIoEx`; late GQCS packet (often aborted) discarded by CAS |

User still sees exactly one completion. `HasPendingIo` should clear after cancel drain (Poll).

### CancellationToken 贯通 (Q1)
- `IAsyncCancellationToken` 已存在父子传播；Q1 消费端：
  - `TCombinatorOptions.Token` → WhenAll/WhenAny 取消完成（一次 OnComplete）
  - `CreateTaskGroup(..., AToken)` → token Cancel → `CancelAll`
  - `AsyncRecvTimeoutEx` / `AsyncSendTimeoutEx` / `AsyncReadTimeoutEx` / `AsyncWriteTimeoutEx` → token Cancel → 用户完成 `-ECANCELED`（125），与 timer/I/O CAS 三方竞态
- 默认 `Token=nil` 保持旧行为
- 非宣称 Go context 全 API 覆盖；Accept/Read 等 Ex 可后续扩展

### Kqueue poller (B3)
- `pbKqueue` readiness backend on macOS/FreeBSD; wired through `TPoller` / `TKqueueReactor`
- Not host-runtime proven on this Linux worktree; forced-compile gate is the evidence
