# nextpas.core.async 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas`（15 个源文件）
**层级**：L1（依赖 L0: base, sync）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-11
**版本**：3.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| async.base | 基础类型 (TAsyncCallback, TAsyncTimerHandle) |
| async.timer | TTimerHeap (定时器堆) |
| async.loop | TAsyncLoop (事件循环) |
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
| async.pas | 门面 (re-exports) |

### 1.2 核心类型

```pascal
{ 回调类型 }
TAsyncCallback = procedure(AContext: Pointer);
TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

{ TAsyncLoop }
TAsyncLoop = record
  function Create(AQueueDepth: Integer = 64): TAsyncLoop;
  procedure Close;
  procedure Run;
  procedure Stop;
  procedure Poll;
  function Schedule(ADelay: TDuration; ACallback: TAsyncCallback; AContext: Pointer): TAsyncTimerHandle;
  procedure Post(ACallback: TAsyncCallback; AContext: Pointer);
  procedure Wake;
  // + AsyncRead/Write/Accept/Recv/Send variants
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
- **[INV-7]** 所有 Record 类型的 Close 方法是幂等的

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
| test_async_primitives | Timer + Loop 基础操作 (11 tests) |
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
| 2026-07-11 | 3.0 | 添加 Combinators/Retry/SyncPrimitives | Claude |
| 2026-07-11 | 2.0 | 添加 TaskGroup/Shutdown/Timeout 高级模式 | Claude |
| 2026-07-01 | 1.0 | 初始版本 | Claude |


### Close discard contract
- Unfired MPSC items: invoke `OnDiscard(Context)` if set, else free PostRef heap wrap only.
- Abandoned timers: Close/Recycle runs `OnDiscard` then clears entry.
- `CancelTimer` does not run OnDiscard.
