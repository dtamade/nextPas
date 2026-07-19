# nextpas.core.async / nextpas.core.net 架构设计

## 概述

本文档描述 nextpas.core 异步框架和网络模块的架构设计。
异步框架提供事件循环、定时器和异步任务抽象；
网络层提供 TCP/UDP 传输和服务器框架；
I/O 轮询器提供跨平台的异步 I/O 抽象。

## 分层架构

```
L1: async.* (异步框架)
├── async.base              ← 基础类型（回调、定时器句柄、任务状态）
├── async.timer             ← 定时器堆（最小堆实现）
├── async.loop              ← 事件循环（跨线程唤醒、定时器、I/O）
├── async.task              ← 异步任务（状态机、完成回调）
└── async.pas               ← 门面（re-exports）

L2: io.* (I/O 抽象)
├── io.poller               ← I/O 轮询器（后端检测、操作代理）
├── io.reactor.pas          ← io_uring 反应器
├── io.reactor.epoll.pas    ← epoll 反应器
└── io.reactor.iocp.pas     ← IOCP 反应器

L2: net.* (网络层)
├── net.base                ← 基础类型（TNetAddress）
├── net.intf                ← 接口定义（ITcpStream, ITcpListener, IUdpSocket）
├── net.tcp                 ← TCP 实现（TTcpStream, TTcpListener）
├── net.udp                 ← UDP 实现（TUdpSocket）
├── net.resolve             ← DNS 解析
├── net.server.*            ← 服务器框架（epoll/kqueue/threaded）
└── net.pas                 ← 门面（re-exports）
```

## 核心组件

### 1. 事件循环 (TAsyncLoop)

#### 1.1 职责
- 跨线程任务调度
- 定时器管理
- I/O 事件分发
- 事件循环控制

#### 1.2 内部结构
```pascal
TAsyncLoop = record
  FPoller: TPoller;                    // I/O 轮询器
  FWakePoller: TPlatformPoller;        // 唤醒轮询器
  FWakeReady: Boolean;                 // 唤醒就绪标志
  FTimers: TTimerHeap;                 // 定时器堆
  FRunning: Int32;                     // 运行状态
  FPendingQueue: array of TAsyncPendingItem;  // 待处理队列
  FPendingCount: UInt32;               // 待处理数量
  FPendingCap: UInt32;                 // 队列容量
  FPendingLock: TPlatformMutex;        // 队列锁
  FPendingReady: Boolean;              // 队列就绪标志
end;
```

#### 1.3 待处理项类型
```pascal
TAsyncPendingItem = record
  Callback: TAsyncCallback;            // 普通过程回调
  Ref: TAsyncCallbackRef;              // 匿名过程引用
  Method: TAsyncCallbackMethod;        // 方法指针
  Context: Pointer;                    // 上下文
  procedure Invoke;                    // 调用回调
  function IsEmpty: Boolean;           // 是否为空
end;
```

#### 1.4 工作流程
```
┌─────────────────────────────────────────────────────────────┐
│                      TAsyncLoop.Run                         │
├─────────────────────────────────────────────────────────────┤
│  1. DrainWake: 清除唤醒信号                                  │
│  2. DrainPending: 处理待处理队列                              │
│  3. FireExpired: 触发到期定时器                               │
│  4. CheckRunning: 检查是否停止                                │
│  5. Flush: 提交待处理 I/O 操作                                │
│  6. Poll: 轮询 I/O 事件                                      │
│  7. WaitForWake: 等待唤醒或超时                               │
└─────────────────────────────────────────────────────────────┘
```

#### 1.5 线程安全
- **Post/PostRef/PostMethod**: 线程安全（使用 FPendingLock）
- **Wake**: 线程安全（使用 platform_poller_wake）
- **其他操作**: 仅限事件循环线程

### 2. 定时器堆 (TTimerHeap)

#### 2.1 职责
- 定时器调度
- 定时器取消
- 到期检测

#### 2.2 内部结构
```pascal
TTimerEntry = record
  Deadline: TDeadline;                 // 到期时间
  Callback: TAsyncCallback;            // 普通过程回调
  Ref: TAsyncCallbackRef;              // 匿名过程引用
  Method: TAsyncCallbackMethod;        // 方法指针
  Context: Pointer;                    // 上下文
  Gen: UInt32;                         // 代数（防止 ABA 问题）
  Cancelled: Boolean;                  // 取消标志
  NextFree: Int32;                     // 空闲链表
  procedure Invoke;                    // 调用回调
  function IsEmpty: Boolean;           // 是否为空
end;

TTimerHeap = record
  FEntries: array of TTimerEntry;      // 条目数组
  FHeap: array of UInt32;              // 堆索引数组
  FHeapCount: UInt32;                  // 堆大小
  FEntryCap: UInt32;                   // 条目容量
  FEntryCount: UInt32;                 // 条目数量
  FFreeHead: Int32;                    // 空闲链表头
  FNextGen: UInt32;                    // 下一代数
end;
```

#### 2.3 堆操作
- **插入**: O(log n) - SiftUp
- **删除**: O(log n) - SiftDown
- **获取最小值**: O(1)
- **取消**: O(1) - 标记为已取消

#### 2.4 代数机制
- 每个条目有唯一代数 (Gen)
- 句柄包含 Id + Gen
- 取消时检查代数是否匹配
- 防止 ABA 问题（句柄复用）

### 3. 异步任务 (TAsyncTask)

#### 3.1 职责
- 异步操作状态管理
- 完成回调调度

#### 3.2 状态机
```
┌─────────┐
│  Idle   │
└────┬────┘
     │
     ▼
┌─────────┐
│ Pending │
└────┬────┘
     │
     ├──────────┬──────────┬──────────┐
     ▼          ▼          ▼          ▼
┌─────────┐┌─────────┐┌─────────┐┌─────────┐
│Completed││ Failed  ││TimedOut ││Cancelled│
└─────────┘└─────────┘└─────────┘└─────────┘
```

#### 3.3 回调存储
```pascal
TAsyncCallbackStorage = record
  Regular: TAsyncCallback;             // 普通过程
  Ref: TAsyncCallbackRef;              // 匿名过程
  Method: TAsyncCallbackMethod;        // 方法指针
  Context: Pointer;                    // 上下文
  procedure Invoke;                    // 调用回调
  function IsEmpty: Boolean;           // 是否为空
end;
```

### 4. I/O 轮询器 (TPoller)

#### 4.1 职责
- 后端检测
- I/O 操作代理
- 事件轮询

#### 4.2 后端检测
```pascal
function PollerDetectBackend: TPollerBackend;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := pbIocp;
  {$ELSEIF defined(NEXTPAS_LINUX)}
  Result := pbEpoll;
  if TryIoUringProbe then
    Result := pbIoUring;
  {$ELSE}
  Result := pbUnsupported;
  {$ENDIF}
end;
```

#### 4.3 后端模型
```pascal
function PollerBackendModel(ABackend: TPollerBackend): TPollerBackendModel;
begin
  case ABackend of
    pbIoUring: Result := pbmCompletionQueue;  // 完成队列模型
    pbIocp: Result := pbmCompletionQueue;     // 完成队列模型
    pbEpoll: Result := pbmReadiness;          // 就绪模型
  else
    Result := pbmUnsupported;
  end;
end;
```

#### 4.4 操作类型
- **完成队列模型** (io_uring/IOCP): 提交操作 → 等待完成事件
- **就绪模型** (epoll): 等待就绪 → 执行操作

### 5. 网络层

#### 5.1 TCP 流 (TTcpStream)

```pascal
TTcpStream = class(TInterfacedObject, IReader, IWriter, IReadWriteCloser,
  ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
private
  FSocket: TPlatformSocket;            // 底层 socket
  FLocal: TNetAddress;                 // 本地地址
  FRemote: TNetAddress;                // 远程地址
  FClosed: Boolean;                    // 关闭标志
  FReadDeadline: TDeadline;            // 读超时
  FWriteDeadline: TDeadline;           // 写超时
end;
```

**特性**:
- 继承 IReadWriteCloser（Read + Write + Close）
- 支持 SetNoDelay (Nagle 算法)
- 支持 SetKeepAlive
- 支持读写超时
- 支持 Shutdown（半关闭）

#### 5.2 TCP 监听器 (TTcpListener)

```pascal
TTcpListener = class(TInterfacedObject, ITcpListener, ITcpSocketRuntime,
  ITcpListenerRuntime)
private
  FSocket: TPlatformSocket;            // 底层 socket
  FLocal: TNetAddress;                 // 本地地址
  FClosed: Boolean;                    // 关闭标志
end;
```

**特性**:
- Accept 阻塞等待连接
- 支持非阻塞模式
- 默认启用 SO_REUSEADDR

#### 5.3 UDP Socket (TUdpSocket)

```pascal
TUdpSocket = class(TInterfacedObject, IUdpSocket)
private
  FSocket: TPlatformSocket;            // 底层 socket
  FLocal: TNetAddress;                 // 本地地址
  FClosed: Boolean;                    // 关闭标志
end;
```

**特性**:
- 无连接通信
- SendTo/RecvFrom 指定地址
- 支持广播

#### 5.4 服务器框架 (net.server.*)

```
net.server.pas          ← 门面
net.server.base.pas     ← 基础类型
net.server.intf.pas     ← 接口定义
net.server.readiness.pas ← 就绪模型服务器
net.server.threaded.pas ← 线程模型服务器
net.server.epoll.pas    ← epoll 后端
net.server.kqueue.pas   ← kqueue 后端
net.server.runtime.pas  ← 运行时管理
```

**后端选择**:
- Linux: epoll (默认) 或 threaded
- macOS/FreeBSD: kqueue 或 threaded
- Windows: IOCP 或 threaded

### 6. 异步回调类型

#### 6.1 普通过程回调
```pascal
TAsyncCallback = procedure(AContext: Pointer);
```
- 最简单的回调类型
- 无状态，无上下文绑定
- 适用于简单场景

#### 6.2 匿名过程引用
```pascal
TAsyncCallbackRef = reference to procedure(AContext: Pointer);
```
- 支持闭包捕获
- 引用计数管理生命周期
- 适用于需要捕获上下文的场景

#### 6.3 方法指针
```pascal
TAsyncCallbackMethod = procedure(AContext: Pointer) of object;
```
- 绑定到对象实例
- 对象生命周期由调用方管理
- 适用于面向对象场景

#### 6.4 I/O 完成回调
```pascal
TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
TIoCompletionRef = reference to procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
```
- I/O 操作完成时调用
- AUserData: 用户数据（通常是文件描述符）
- AResult: 操作结果（字节数或错误码）
- AContext: 上下文指针

## 并发模型

### 1. 线程角色

```
┌─────────────────────────────────────────────────────────────┐
│                      应用线程                                │
├─────────────────────────────────────────────────────────────┤
│  - 调用 Post/PostRef/PostMethod 提交任务                     │
│  - 调用 Wake 唤醒事件循环                                     │
│  - 不直接操作事件循环内部状态                                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      事件循环线程                             │
├─────────────────────────────────────────────────────────────┤
│  - 运行 TAsyncLoop.Run                                      │
│  - 处理待处理队列                                             │
│  - 触发到期定时器                                             │
│  - 轮询 I/O 事件                                             │
│  - 执行回调                                                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      I/O 线程池                              │
├─────────────────────────────────────────────────────────────┤
│  - 执行阻塞 I/O 操作                                         │
│  - 完成后唤醒事件循环                                         │
│  - 由 net.server 管理                                        │
└─────────────────────────────────────────────────────────────┘
```

### 2. 锁策略

| 组件 | 锁 | 用途 |
|------|-----|------|
| TAsyncLoop.FPendingLock | TPlatformMutex | 保护待处理队列 |
| TAsyncLoop.FWakePoller | platform_poller_wake | 跨线程唤醒 |
| TPoller 内部锁 | 平台相关 | 保护 I/O 操作 |

### 3. 线程安全规则

1. **Post/PostRef/PostMethod**: 线程安全，可从任意线程调用
2. **Wake**: 线程安全，可从任意线程调用
3. **其他操作**: 仅限事件循环线程
4. **TAsyncTask**: 调用方负责同步
5. **网络接口**: 同一连接不可并发操作

## 性能特征

### 1. 复杂度

| 操作 | 复杂度 | 说明 |
|------|--------|------|
| Post | O(1) | 加锁入队 |
| Schedule | O(log n) | 堆插入 |
| CancelTimer | O(1) | 标记取消 |
| FireExpired | O(k log n) | k 个到期定时器 |
| Poll | O(m) | m 个就绪事件 |

### 2. 内存使用

| 组件 | 内存 | 说明 |
|------|------|------|
| TAsyncLoop | ~1KB | 基础结构 |
| TTimerHeap | ~16KB | 初始容量 16 |
| TPoller | ~4KB | 基础结构 |
| 每个定时器 | ~64B | TTimerEntry |
| 每个待处理项 | ~32B | TAsyncPendingItem |

### 3. 优化点

1. **批量提交**: io_uring 支持批量提交 I/O 操作
2. **零拷贝**: io_uring 支持零拷贝 I/O
3. **连接池**: TCP 连接复用，减少握手开销
4. **SIMD 快速路径**: HTTP 解析使用 SIMD 优化
5. **引用计数**: 匿名过程使用引用计数，避免堆分配

## 扩展点

### 1. 自定义后端

```pascal
// 实现自定义反应器
TIoReactor = record
  // 实现 AsyncRead/AsyncWrite/AsyncAccept 等
end;

// 注册到轮询器
TPoller.Create(AQueueDepth);
```

### 2. 自定义定时器

```pascal
// 使用 TTimerHeap
var
  LHeap: TTimerHeap;
begin
  LHeap := TTimerHeap.Create;
  LHeap.Schedule(TDeadline.After(TDuration.FromSeconds(1)), @MyCallback, nil);
end;
```

### 3. 自定义服务器

```pascal
// 实现自定义服务器
TMyServer = class
  procedure HandleConnection(AConn: ITcpStream);
end;

// 使用服务器框架
var
  LServer: ITcpListener;
begin
  LServer := TcpListen('0.0.0.0', 8080);
  while True do
  begin
    LConn := LServer.Accept;
    // 处理连接
  end;
end;
```

## 平台差异

### 1. Linux

- **I/O 后端**: io_uring (优先) 或 epoll
- **服务器后端**: epoll (默认) 或 threaded
- **特性**: 支持 io_uring 零拷贝、批量提交

### 2. macOS/FreeBSD

- **I/O 后端**: kqueue
- **服务器后端**: kqueue 或 threaded
- **特性**: 支持 EVFILT_READ/EVFILT_WRITE

### 3. Windows

- **I/O 后端**: IOCP
- **服务器后端**: IOCP 或 threaded
- **特性**: 支持 AcceptEx、ConnectEx

## 测试策略

### 1. 单元测试

- 每个模块独立测试
- 覆盖所有公共接口
- 边界条件测试

### 2. 集成测试

- 模块间交互测试
- 端到端测试
- 并发测试

### 3. 压力测试

- 高并发测试
- 长时间运行测试
- 资源泄漏测试

### 4. 平台测试

- 跨平台编译测试
- 平台特定功能测试
- 兼容性测试

## 未来演进

### 1. 短期 (1-2 月)

- 完善异步 DNS 解析
- 添加连接池抽象
- 实现背压控制

### 2. 中期 (3-6 月)

- 实现异步文件 I/O
- 添加 TLS 异步握手
- 实现 HTTP/2 异步流

### 3. 长期 (6-12 月)

- 实现 QUIC 支持
- 添加 HTTP/3 支持
- 性能优化和基准测试

---

*本文档描述 nextpas.core.async / nextpas.core.net 的架构设计，*
*基于 platform 和 http 模块的开发实践，*
*旨在指导模块的持续改进和演进。*
