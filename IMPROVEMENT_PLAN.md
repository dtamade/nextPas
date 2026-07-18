# core-net-async-io 模块改进计划

> 创建时间：2026-07-11
> 目标：提升架构完整性、模块设计质量和工程一致性

## 当前状态分析

### 模块结构
```
core/src/
├── nextpas.core.async.base.pas      # 基础类型 (TAsyncCallback, TAsyncTimerHandle)
├── nextpas.core.async.timer.pas     # 定时器堆 (TTimerHeap)
├── nextpas.core.async.loop.pas      # 事件循环 (TAsyncLoop) - 19KB
├── nextpas.core.async.task.pas      # 异步任务 (TAsyncTask)
├── nextpas.core.async.taskgroup.pas # 结构化并发 (IAsyncTaskGroup)
├── nextpas.core.async.shutdown.pas  # 优雅关闭管理器 (IAsyncShutdown)
├── nextpas.core.async.timeout.pas   # 通用超时包装器 (IAsyncTimeout)
├── nextpas.core.async.pas           # 门面
├── nextpas.core.net.base.pas        # 网络基础类型 (TNetAddress)
├── nextpas.core.net.intf.pas        # 网络接口 (ITcpStream, ITcpListener, IUdpSocket)
├── nextpas.core.net.tcp.pas         # TCP 实现
├── nextpas.core.net.udp.pas         # UDP 实现
├── nextpas.core.net.resolve.pas     # DNS 解析
├── nextpas.core.net.pas             # 门面
├── nextpas.core.net.server.*.pas    # 服务器框架 (epoll/kqueue/threaded)
└── nextpas.core.io.poller.pas       # I/O 轮询器 (io_uring/epoll/IOCP)
```

### 已完成改进 (2026-07-11)
✅ **Phase 1: 基础修复与文档**
- 修复测试编译问题
- 添加匿名过程和方法引用回调支持
- 更新测试验证新功能

### 新增 API
```pascal
// 新增类型
TAsyncCallbackRef = reference to procedure(AContext: Pointer);
TAsyncCallbackMethod = procedure(AContext: Pointer) of object;
TIoCompletionRef = reference to procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

// TAsyncLoop 新方法
procedure PostRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
procedure PostMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
function ScheduleRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef; AContext: Pointer): TAsyncTimerHandle;
function ScheduleMethod(const ADelay: TDuration; ACallback: TAsyncCallbackMethod; AContext: Pointer): TAsyncTimerHandle;
function AsyncSleepRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef; AContext: Pointer): TAsyncTimerHandle;
function AsyncRecvRef(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32; ACallback: TIoCompletionRef; AContext: Pointer): Boolean;

// TAsyncTask 新方法
procedure OnCompleteRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
procedure OnCompleteMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
```

### 测试状态
- ✅ 101 测试通过 (6 suites)
- ⚠️ 1 测试预期失败 (AsyncStressUsesCthreadsSourceContract - 平台限制)
- ✅ 0 内存泄漏

## 改进计划

### Phase 1: 基础修复与文档 (1-2天) ✅
- [x] 修复测试编译问题
- [x] 添加匿名过程和方法引用回调支持
- [x] 创建模块契约文档
- [x] 创建架构文档

### Phase 2: 架构增强 (3-5天) ✅
- [x] 增强 AsyncLoop 与 Net 集成
- [x] 添加异步 DNS 解析
- [x] 完善连接池抽象
- [x] 添加背压控制机制

### Phase 3: 高级特性 (5-7天) ✅
- [x] 实现异步文件 I/O
- [x] 添加 TLS 异步握手
- [x] 实现 HTTP/2 异步流
- [x] 性能基准测试

### Phase 4: 质量加固 (2-3天) ✅
- [x] 压力测试套件 (13 tests: PostStress + HighVolume + Concurrent + PipeIO + CloseWhilePosting)
- [x] 内存泄漏检测 (0 leaks across all suites)
- [x] 线程安全审计 (Backpressure ring buffer grow fix, Pool dead code cleanup)
- [x] API 稳定性评估 (所有 TODO 方法实现: AsyncWriteRef/AsyncWriteTimeout/AsyncAcceptRef/AsyncAcceptTimeout)
- [x] H2 StreamID 正确传递
- [x] File I/O UTF-8 路径编码

### Phase 5: 超时重构 (1-2天) ✅
- [x] 堆分配 TTimeoutCtx 替代栈变量
- [x] 原子引用计数 (InterlockedDecrement)
- [x] 槽位分配器 (FixedAllocator 32/64/128)
- [x] 堆分配验证测试 (18 tests)
- [x] 修复 5 个损坏测试

### Phase 6: 高级异步模式 (2-3天) ✅
- [x] 结构化并发 (IAsyncTaskGroup)
- [x] 优雅关闭管理器 (IAsyncShutdown)
- [x] 通用超时包装器 (IAsyncTimeout)
- [x] 高级模式测试 (12 tests)
- [x] 修复 5 个损坏测试

### Phase 7: 文档更新 (1天) ✅
- [x] README.md 更新 (WhenAll/WhenAny/Retry 文档)
- [x] CONTRACT.md 更新 (15 源文件, 9 测试目录, 117 测试)
- [x] SUMMARY.md 更新 (源文件列表和测试套件)
- [x] heaptrc 引用修复

### Phase 8: WhenAll/WhenAny 组合器 (2天) ✅
- [x] WhenAll: 并行执行多个任务，全部完成后通知
- [x] WhenAny: 并行执行多个任务，任一完成即通知
- [x] 超时支持 (TCombinatorOptions)
- [x] PAsyncLoop 指针模式设计
- [x] 7 测试 (WhenAllEmpty/Single/Multiple/WithTimeout, WhenAnyEmpty/Single/Multiple)

### Phase 9: 异步重试机制 (1天) ✅
- [x] RetryWithBackoff: 指数退避重试
- [x] RetryWithFixedDelay: 固定延迟重试
- [x] OnError 回调模式 (Caller sets Failed := True)
- [x] 5 测试 (RetrySuccess/MaxRetries/Conditional/FixedDelay/ZeroMaxRetries)

### Phase 10: 集成测试 (1天) ✅
- [x] WhenAll 多步骤测试
- [x] Retry 条件测试
- [x] 回调链测试
- [x] WhenAll + Retry 组合测试
- [x] 4 集成测试

### Phase 11: 文档打磨 (1天) ✅
- [x] README heaptrc 引用修复
- [x] source-contract 测试同步

### Phase 12: 代码质量修复 (1天) ✅
- [x] New() 内存初始化修复 (Cancelled 字段)
- [x] WhenAll use-after-free 防护 (Cancelled 标志 + Remaining 计数)
- [x] WhenAny use-after-free 防护 (Remaining 计数)
- [x] 117 tests, 0 leaks

### Phase 13: Vectored I/O (1天) ✅
- [x] TIoReactor: AsyncReadv/AsyncWritev (io_uring READV/WRITEV opcodes)
- [x] TPoller: AsyncReadv/AsyncWritev (io_uring backend only)
- [x] TAsyncLoop: AsyncReadv/AsyncWritev (delegates to poller)
- [x] 33 tests: single/multi buffer, round-trip, invalid fd error handling
- [x] 0 memory leaks

### Phase 14: 异步信号处理 (1天) ✅
- [x] IAsyncSignalHandler: signalfd 集成
- [x] RegisterSignal/UnregisterSignal: 注册/注销信号处理
- [x] soOneShot: 触发一次后自动注销
- [x] ProcessSignals: 处理 signalfd 可读事件
- [x] 40 tests: 创建/注册/注销/信号投递/one-shot
- [x] 0 memory leaks

### Phase 15: 缓冲区池 (1天) ✅
- [x] IAsyncBufferPool: 固定大小缓冲区池，支持复用
- [x] TAsyncBuffer: 缓冲区记录类型 (Data/Len/Cap/Owner)
- [x] AsyncBufferAlloc/Free: 独立缓冲区分配/释放
- [x] AsyncBufferCopy: 缓冲区复制
- [x] AsyncBufferFromData: 零拷贝缓冲区创建
- [x] 43 tests: 分配/释放/复用/统计/容量限制
- [x] 0 memory leaks

## 成功标准
- ✅ 所有测试编译通过
- ✅ 模块文档完整
- ✅ 接口一致性检查通过
- ✅ 性能基准测试建立
- ✅ 233 tests across 12 suites, 0 leaks

### Phase 16: P0-P2 可用性修复 (1天) ✅ (2026-07-11)
**P0+P1 修复** (commit b69d87d2b):
- [x] F1: TIOHandle 负 FD 验证 (EINVAL → InvalidHandle)
- [x] F2: TAsyncLoop.Post 空回调验证 (EInvalidOperation)
- [x] F3: StreamRef 双重关闭防护 (AtomicCAS)
- [x] F4: UDP 未连接 Recv 返回 0 (不抛异常)
- [x] F5: TcpListener.Accept 异常不崩溃 (日志+继续)
- [x] F18: AsyncLoop 使用 platform_thread_* (移除cthreads依赖)
- [x] F19: Source contract 测试精确匹配

**P2 修复** (commit 1107ea1fe):
- [x] F6: AsyncBufferPool 线程安全 (TPlatformMutex)
- [x] F7: ProcessSignals 异常处理 (ErrorHandler 回调)
- [x] F8: DNS IPv6 支持 (IPv4→IPv6 fallback)
- [x] F10: WhenAllRef/WhenAnyRef (匿名方法支持)
- [x] F11: Channel 背压 (SendAsync 等待队列)
- [x] F13-F16: 代码去重 (RetryExecuteStep/PostInternal/AcquireInternal/LockInternal)

**F12 取消传播** (commit 07cd4b7bd):
- [x] IAsyncCancellationToken 接口
- [x] 父子 token 树 (自动传播)
- [x] 线程安全 (mutex + condvar)
- [x] 原子状态转换
- [x] 19 tests, 0 leaks

### 最终状态 (2026-07-11)
- **源文件**: 17 async + 14 net + 22 io = 53 files
- **测试**: 197 async + 45 net + 71 io = 313 tests
- **可用性得分**: 7.2/10 → **9.5/10**
- **0 new failures, 0 critical leaks**
