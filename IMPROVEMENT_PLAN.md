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

### 已发现问题
1. **测试编译失败** - 依赖链问题需修复
2. **Async/Net 集成不完整** - 事件循环与网络层未深度整合
3. **文档缺失** - 无模块设计文档
4. **接口一致性** - 部分接口命名和模式不统一

## 改进计划

### Phase 1: 基础修复与文档 (1-2天)
- [ ] 修复测试编译问题
- [ ] 创建模块设计文档 `core/docs/net-async-io/README.md`
- [ ] 统一接口命名规范

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
- 所有测试编译通过
- 模块文档完整
- 接口一致性检查通过
- 性能基准测试建立
