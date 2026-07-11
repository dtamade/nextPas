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
- ✅ 43 测试通过
- ⚠️ 1 测试预期失败 (AsyncStressUsesCthreadsSourceContract - 平台限制)
- ✅ 0 内存泄漏

## 改进计划

### Phase 1: 基础修复与文档 (1-2天) ✅
- [x] 修复测试编译问题
- [x] 添加匿名过程和方法引用回调支持
- [x] 创建模块契约文档
- [x] 创建架构文档

### Phase 2: 架构增强 (3-5天)
- [ ] 增强 AsyncLoop 与 Net 集成
- [ ] 添加异步 DNS 解析
- [ ] 完善连接池抽象
- [ ] 添加背压控制机制

### Phase 3: 高级特性 (5-7天)
- [ ] 实现异步文件 I/O
- [ ] 添加 TLS 异步握手
- [ ] 实现 HTTP/2 异步流
- [ ] 性能基准测试

### Phase 4: 质量加固 (2-3天)
- [ ] 压力测试套件
- [ ] 内存泄漏检测
- [ ] 线程安全审计
- [ ] API 稳定性评估

## 成功标准
- ✅ 所有测试编译通过
- ✅ 模块文档完整
- [ ] 接口一致性检查通过
- [ ] 性能基准测试建立
