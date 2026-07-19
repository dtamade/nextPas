# core-net-async-io 模块总结

> 最后更新：2026-07-19
> 版本：M3 TAsyncLoop class landed

## 模块概览

nextpas.core.async 是单线程异步事件循环框架，支持跨平台 I/O 后端。

## 架构

```
+------------------+
|   TAsyncLoop     |  (integrates all components)
+--------+---------+
         |
    +----+----+----------+----------+
    |         |          |          |
+---v---+ +---v----+ +---v------+ +---v------+
| TPoller| |TTimerHeap| | platform | |Post queue|
| (I/O)  | | (timers) | | wake    | |(x-thread)|
+---------+ +----------+ +----------+ +----------+
    |
    +--- io_uring (TIoReactor) — pbmCompletionQueue
    |
    +--- epoll (TEpollReactor) — pbmReadiness

+-----------------------------------------------------------+
|  Higher-level primitives                                  |
|  IAsyncTaskGroup  IAsyncShutdown  IAsyncTimeout           |
|  WhenAll/WhenAny  RetryWithBackoff                        |
|  IAsyncMutex  IAsyncSemaphore  IAsyncChannel  IAsyncCondVar|
+-----------------------------------------------------------+
```

## 源文件

| 文件 | 职责 | 行数 |
|------|------|------|
| async.base.pas | 基础类型 (TAsyncCallback, TAsyncTimerHandle) | ~50 |
| async.timer.pas | TTimerHeap (定时器堆) | ~400 |
| async.loop.pas | TAsyncLoop (事件循环) | ~780 |
| async.task.pas | TAsyncTask (异步任务状态机) | ~160 |
| async.taskgroup.pas | IAsyncTaskGroup (结构化并发) | ~400 |
| async.shutdown.pas | IAsyncShutdown (优雅关闭管理器) | ~260 |
| async.timeout.pas | IAsyncTimeout (通用超时包装器) | ~235 |
| async.combinators.pas | WhenAll/WhenAny 组合器 | ~280 |
| async.retry.pas | RetryWithBackoff 异步重试 | ~300 |
| async.signal.pas | IAsyncSignalHandler (异步信号处理) | ~300 |
| async.buffer.pas | IAsyncBufferPool (缓冲区池) | ~280 |
| async.mutex.pas | IAsyncMutex (异步互斥锁) | ~226 |
| async.semaphore.pas | IAsyncSemaphore (异步信号量) | ~224 |
| async.channel.pas | IAsyncChannel (异步通道) | ~356 |
| async.condvar.pas | IAsyncCondVar (异步条件变量) | ~196 |
| async.pas | 门面 (re-exports) | ~80 |

## 核心 API

### TAsyncLoop

| 方法 | 说明 |
|------|------|
| `Create(AQueueDepth)` | 创建事件循环 |
| `Run` | 运行直到 Stop |
| `Stop` | 停止循环 |
| `Schedule(ADelay, ACallback, AContext)` | 定时器 |
| `Post(ACallback, AContext)` | 跨线程投递 |
| `AsyncRead/Write/Accept/Recv/Send` | 异步 I/O |
| `AsyncReadv/Writev` | Vectored I/O (scatter/gather) |

### IAsyncTaskGroup

| 方法 | 说明 |
|------|------|
| `RunTask(ACallback, AContext, AOptions)` | 添加任务 |
| `CancelAll` | 取消所有任务 |
| `Drain(ADrainTimeoutMs)` | 等待任务完成 |
| `WaitAll` | 阻塞等待所有任务 |
| `ActiveCount` | 活跃任务数 |
| `CompletedCount` | 已完成任务数 |

### IAsyncShutdown

| 方法 | 说明 |
|------|------|
| `RequestShutdown(ACode, AReason)` | 请求关闭 |
| `OnShutdown(ACallback, AContext)` | 注册通知回调 |
| `ForceClose` | 强制关闭 |
| `Phase` | 当前阶段 |

### IAsyncTimeout

| 方法 | 说明 |
|------|------|
| `AsyncRunWithTimeout(ACallback, AContext, ATimeoutMs)` | 带超时执行 |
| `Cancel` | 取消操作 |
| `Status` | 状态 (Pending/Completed/TimedOut/Cancelled) |
| `GetResult` | 获取结果 |

## 测试套件

| 测试 | 测试数 | 说明 |
|------|--------|------|
| test_async | 43 | 基本事件循环测试 |
| test_async_advanced | 12 | TaskGroup + Shutdown 高级模式 |
| test_async_bench | 4 | 性能基准测试 |
| test_async_combinators | 7 | WhenAll/WhenAny 组合器 |
| test_async_integration | 4 | 集成测试 |
| test_async_primitives | 11 | Timer + Loop 基础操作 |
| test_async_retry | 5 | 异步重试机制 |
| test_async_stress | 13 | 压力测试 |
| test_async_timeout | 18 | 超时机制测试 |
| test_async_vectored_io | 33 | Vectored I/O scatter/gather |
| test_async_signal | 40 | 异步信号处理 |
| test_async_buffer | 43 | 缓冲区池 |
| **合计** | **233** | **0 leaks, 1 expected failure** |

## 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Linux | ✅ | io_uring + epoll (自动检测) |
| macOS | ❌ | 无 kqueue 后端 |
| Windows | ❌ | IOCP 编译桩，无运行时 |
| FreeBSD | ❌ | 无 kqueue 后端 |

## 线程安全

- **TAsyncLoop**: 单线程，所有回调在 loop 线程执行
- **Post/Wake**: 线程安全，可从任意线程调用
- **Schedule/AsyncRead 等**: 非线程安全，只能从 loop 线程调用

## 关键设计决策

1. **单线程模型**: 避免锁竞争，简化状态管理
2. **回调驱动**: 无 Future/Promise，纯回调模式
3. **TAsyncLoop = class**: 引用语义，消除 `@ALoop` 栈悬空；依赖不拥有 loop
4. **Close / Free**: Close 幂等释放资源；Free→Destroy 调 Close 且不抛异常
5. **平台检测**: 运行时自动选择最佳后端

## 未来方向

1. **macOS/FreeBSD**: 添加 kqueue 后端
2. **Windows**: 完善 IOCP 运行时支持
3. **性能优化**: 批量 I/O 操作
4. **Channel 有界异步等待** + 与 net.async.backpressure 打通

## 相关文档

- [README.md](README.md) - 用户文档
- [CONTRACT.md](CONTRACT.md) - 代码契约
- [ARCHITECTURE.md](../net-async-io/ARCHITECTURE.md) - 架构设计
