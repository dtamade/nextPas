# nextpas.core.async / nextpas.core.net 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas` + `core/src/nextpas.core.net*.pas`
**层级**：L1-L2（依赖 L0: platform, base, errors）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

```
async.base           ← TAsyncCallback, TAsyncCallbackRef, TAsyncCallbackMethod,
                       TIoCompletion, TIoCompletionRef, TAsyncTimerHandle,
                       TAsyncTaskState/Status
async.timer          ← TTimerHeap (定时器堆)
async.loop           ← TAsyncLoop (事件循环)
async.task           ← TAsyncTask (异步任务)
async.taskgroup      ← IAsyncTaskGroup (结构化并发)
async.shutdown       ← IAsyncShutdown (优雅关闭管理器)
async.timeout        ← IAsyncTimeout (通用超时包装器)
async.pas            ← 门面 (re-exports)

net.base             ← TNetAddress, NET_DEFAULT_BACKLOG, NET_DEFAULT_BUFFER_SIZE
net.intf             ← ITcpStream, ITcpListener, IUdpSocket,
                       ITcpSocketRuntime, ITcpStreamRuntime, ITcpListenerRuntime
net.tcp              ← TTcpStream, TTcpListener (TCP 实现)
net.udp              ← TUdpSocket (UDP 实现)
net.resolve          ← DNS 解析
net.server.*         ← 服务器框架 (epoll/kqueue/threaded)
net.pas              ← 门面 (re-exports)

io.poller            ← TPoller, TIoCompletion (I/O 轮询器)
io.reactor.*         ← io_uring/epoll/IOCP 反应器
```

### 1.2 核心接口

#### 异步框架

```pascal
{ 回调类型 }
TAsyncCallback = procedure(AContext: Pointer);
TAsyncCallbackRef = reference to procedure(AContext: Pointer);
TAsyncCallbackMethod = procedure(AContext: Pointer) of object;
TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
TIoCompletionRef = reference to procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

{ 定时器句柄 }
TAsyncTimerHandle = record
  FId: UInt32;
  FGen: UInt32;
  class function None: TAsyncTimerHandle; static;
  function IsValid: Boolean;
end;

{ 异步任务状态 }
TAsyncTaskState = (atsIdle, atsPending, atsCompleted, atsFailed, atsTimedOut, atsCancelled);

{ 事件循环 — class，堆拥有；依赖存对象引用且不拥有 }
TAsyncLoop = class
  constructor Create(AQueueDepth: UInt32 = 64);
  destructor Destroy; override;
  procedure Close;
  function IsValid: Boolean;

  { 跨线程唤醒 }
  procedure Post(ACallback: TAsyncCallback; AContext: Pointer = nil);
  procedure PostRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
  procedure PostMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer = nil);
  procedure Wake;

  { 定时器调度 }
  function Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
    AContext: Pointer = nil): TAsyncTimerHandle;
  function ScheduleRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
    AContext: Pointer = nil): TAsyncTimerHandle;
  function ScheduleMethod(const ADelay: TDuration; ACallback: TAsyncCallbackMethod;
    AContext: Pointer = nil): TAsyncTimerHandle;
  function CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;

  { I/O 操作 }
  function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncRecvRef(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
  function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

  { 带超时的 I/O }
  function AsyncRecvTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

  { 异步睡眠 }
  function AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
    AContext: Pointer = nil): TAsyncTimerHandle;
  function AsyncSleepRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
    AContext: Pointer = nil): TAsyncTimerHandle;

  { 事件循环 }
  function Poll: Int32;
  procedure Run;
  procedure RunOnce;
  procedure Stop;
end;

{ 异步任务 }
TAsyncTask = record
  class function Create: TAsyncTask; static;
  procedure Complete(AResult: Int32);
  procedure Fail(AResult: Int32);
  procedure Timeout;
  procedure Cancel;
  function Status: TAsyncTaskStatus;
  function IsCompleted: Boolean;
  function IsDone: Boolean;
  function GetResult: Int32;
  procedure OnComplete(ACallback: TAsyncCallback; AContext: Pointer);
  procedure OnCompleteRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
  procedure OnCompleteMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
end;
```

#### 网络层

```pascal
{ 网络地址 }
TNetAddress = record
  IP: string;
  Port: UInt16;
  IsIPv6: Boolean;
  function ToString: string;
  class function Create(const AIP: string; APort: UInt16): TNetAddress; static;
  class function IPv4(const AIP: string; APort: UInt16): TNetAddress; static;
  class function IPv6(const AIP: string; APort: UInt16): TNetAddress; static;
  class function Loopback(APort: UInt16): TNetAddress; static;
  class function Any(APort: UInt16): TNetAddress; static;
end;

{ TCP 流接口 }
ITcpStream = interface(IReadWriteCloser)
  function LocalAddr: TNetAddress;
  function RemoteAddr: TNetAddress;
  procedure Shutdown;
  procedure SetNoDelay(const AValue: Boolean);
  procedure SetKeepAlive(const AValue: Boolean);
  procedure SetReadDeadline(const ADeadline: TDeadline);
  procedure SetWriteDeadline(const ADeadline: TDeadline);
end;

{ TCP 监听器接口 }
ITcpListener = interface
  function Accept: ITcpStream;
  function LocalAddr: TNetAddress;
  procedure Close;
end;

{ UDP Socket 接口 }
IUdpSocket = interface
  function SendTo(const ABuf; const ACount: SizeUInt;
    const AAddr: TNetAddress): SizeUInt;
  function RecvFrom(var ABuf; const ACount: SizeUInt;
    out AAddr: TNetAddress): SizeUInt;
  function LocalAddr: TNetAddress;
  procedure Close;
end;

{ 便捷函数 }
function TcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
function TcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
function UdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
function Resolve(const AHost: string): TNetAddress;
```

#### I/O 轮询器

```pascal
{ 轮询器后端 }
TPollerBackend = (pbIoUring, pbEpoll, pbIocp, pbUnsupported);
TPollerBackendModel = (pbmCompletionQueue, pbmReadiness, pbmUnsupported);

{ 轮询器 }
TPoller = record
  class function Create(AQueueDepth: UInt32 = 64): TPoller; static;
  procedure Close;
  function IsValid: Boolean;
  function Backend: TPollerBackend;

  { 异步 I/O 操作 }
  function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
    ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

  { 轮询操作 }
  function Poll: Int32;
  function PollOne: Boolean;
  procedure Run;
  procedure Stop;
  function Flush: Int32;
  function HasPending: Boolean;
end;
```

### 1.3 常量

```pascal
{ 网络常量 }
NET_DEFAULT_BACKLOG = 128;
NET_DEFAULT_BUFFER_SIZE = 65536;

{ 异步任务状态 }
atsIdle: TAsyncTaskStatus = 0;
atsPending: TAsyncTaskStatus = 1;
atsCompleted: TAsyncTaskStatus = 2;
atsFailed: TAsyncTaskStatus = 3;
atsTimedOut: TAsyncTaskStatus = 4;
atsCancelled: TAsyncTaskStatus = 5;
```

---

## 2. 不变量

### 2.1 异步框架

- **[INV-1]** TAsyncTimerHandle 的 FId = High(UInt32) 表示无效句柄
- **[INV-2]** TAsyncTask 状态只能单向转换：Idle → Pending → Completed/Failed/TimedOut/Cancelled
- **[INV-3]** TAsyncLoop.Post/PostEx/PostRef/PostMethod 是线程安全的（T1 MPSC）
- **[INV-4]** TTimerHeap 的定时器按到期时间排序（最小堆）
- **[INV-5]** 匿名过程引用 (TAsyncCallbackRef) 通过引用计数管理生命周期
- **[INV-6]** 方法指针 (TAsyncCallbackMethod) 绑定到对象实例

### 2.2 网络层

- **[INV-7]** TNetAddress 的 Port 范围是 0-65535
- **[INV-8]** ITcpStream 继承 IReadWriteCloser，不支持 Seek/Size/Position
- **[INV-9]** ITcpListener.Accept 在无连接时阻塞（除非设置非阻塞）
- **[INV-10]** IUdpSocket.SendTo/RecvFrom 是无连接的
- **[INV-11]** TCP socket 默认启用 SO_REUSEADDR
- **[INV-12]** TCP 连接支持 SetNoDelay (Nagle 算法) 和 SetKeepAlive

### 2.3 I/O 轮询器

- **[INV-13]** TPoller 后端检测顺序：io_uring → epoll → IOCP → Unsupported
- **[INV-14]** io_uring 和 IOCP 使用完成队列模型
- **[INV-15]** epoll 使用就绪模型
- **[INV-16]** TPoller.Async* 操作是线程安全的

---

## 3. 错误处理

### 3.1 异步框架

| 场景 | 处理方式 | 消息模式 |
|------|----------|----------|
| 事件循环关闭后操作 | 抛出 EInvalidOperationError | 'async loop: operation after close' |
| 定时器句柄无效 | 返回 False | — |
| 任务已完成时设置回调 | 立即调用回调 | — |

### 3.2 网络层

| 场景 | 处理方式 | 消息模式 |
|------|----------|----------|
| 连接失败 | 抛出 ENetError | 'connect failed: ' + host + ':' + port |
| 绑定失败 | 抛出 ENetError | 'bind failed: ' + addr + ':' + port |
| 监听失败 | 抛出 ENetError | 'listen failed: ' + addr + ':' + port |
| 接受失败 | 抛出 ENetError | 'accept failed: ' + msg |
| 发送/接收超时 | 返回 tsiorTimeout | — |
| 连接关闭 | 返回 tsiorClosed | — |

### 3.3 I/O 轮询器

| 场景 | 处理方式 | 消息模式 |
|------|----------|----------|
| 轮询器创建失败 | 抛出 EInvalidOperationError | 'poller creation failed' |
| 不支持的后端 | 返回 pbUnsupported | — |
| I/O 操作失败 | 返回 False | — |

---

## 4. 线程安全

### 4.1 异步框架

| 组件 | 线程安全 | 机制 |
|------|----------|------|
| TAsyncLoop.Post/PostEx/PostRef/PostMethod | ✅ | T1 MPSC pending queue (H3-1) |
| TAsyncLoop.Wake | ✅ | platform_poller_wake |
| TAsyncLoop.Schedule* | ❌ | 仅限事件循环线程 |
| TAsyncLoop.Async* | ❌ | 仅限事件循环线程 |
| TAsyncLoop.Run | ❌ | 仅限事件循环线程 |
| TTimerHeap | ❌ | 仅限事件循环线程 |
| TAsyncTask | ❌ | 调用方负责同步 |

### 4.2 网络层

| 组件 | 线程安全 | 机制 |
|------|----------|----------|
| ITcpStream | ❌ | 同一连接不可并发读写 |
| ITcpListener | ❌ | Accept 不可并发 |
| IUdpSocket | ❌ | 同一 socket 不可并发 |
| TcpListen/TcpConnect/UdpBind | ✅ | 无状态工厂函数 |

### 4.3 I/O 轮询器

| 组件 | 线程安全 | 机制 |
|------|----------|----------|
| TPoller.Async* | ✅ | 内部锁 |
| TPoller.Poll | ❌ | 仅限事件循环线程 |
| TPoller.Run | ❌ | 仅限事件循环线程 |

---

## 5. 内存管理

### 5.1 异步框架

- **TAsyncLoop**: **class**，内部管理 FPoller、FTimers、FPending MPSC；`Free`/`Close` 释放
- **TTimerHeap**: 值类型，内部管理 FEntries、FHeap
- **TAsyncTask**: 值类型，调用方管理生命周期
- **匿名过程引用**: 引用计数，自动释放
- **方法指针**: 绑定到对象，对象生命周期由调用方管理
- **依赖 outlive**: mutex/channel/shutdown/net.async 等存 loop 引用但不拥有

### 5.2 网络层

- **ITcpStream**: 引用计数，连接关闭时自动释放
- **ITcpListener**: 引用计数，监听器关闭时自动释放
- **IUdpSocket**: 引用计数，socket 关闭时自动释放
- **TNetAddress**: 值类型，字符串字段引用计数

### 5.3 I/O 轮询器

- **TPoller**: 值类型，内部管理反应器
- **TIoCompletion 回调**: 无状态，上下文由调用方管理

---

## 6. 性能特征

### 6.1 异步框架

- **定时器堆**: O(log n) 插入/删除，O(1) 获取最小值
- **事件循环**: O(1) 唤醒，O(n) 轮询（n = 就绪事件数）
- **待处理队列**: O(1) 入队，O(n) 出队（n = 待处理数）
- **匿名过程**: 引用计数开销，无堆分配（编译器优化）

### 6.2 网络层

- **TCP 连接**: 系统调用开销，连接池复用
- **DNS 解析**: 系统调用开销，缓存可选
- **地址解析**: O(1) 字符串操作

### 6.3 I/O 轮询器

- **io_uring**: 零拷贝，批量提交，内核态轮询
- **epoll**: O(1) 就绪通知，O(n) 事件分发
- **IOCP**: 完成端口，异步 I/O，线程池

---

## 7. 测试覆盖

### 7.1 异步框架测试

| 套件 | 模块 | 测试数 |
|------|------|--------|
| test_async | async.base/timer/loop/task | 42+ |
| test_async_stress | 压力测试 | 5+ |
| test_async_timeout | 超时测试 | 8+ |
| test_async_windows_contract | Windows 契约 | 3+ |
| test_async_windows_compile_gate | Windows 编译门禁 | 2+ |

### 7.2 网络层测试

| 套件 | 模块 | 测试数 |
|------|------|--------|
| test_net | net.base/intf/tcp/udp | 15+ |
| test_net_deep | 深度测试 | 20+ |
| test_net_server | net.server.* | 10+ |
| test_platform_net | platform.socket | 16+ |

### 7.3 质量门禁

- **heaptrc**: 所有测试构建启用，0 unfreed
- **nil guard**: 所有指针检查
- **边界值**: 0/nil/MAX_INT/-1
- **跨平台**: Linux/macOS/Windows

---

## 8. 平台支持

| 平台 | 异步框架 | 网络层 | I/O 轮询器 |
|------|----------|--------|------------|
| Linux x86_64 | ✅ | ✅ | ✅ (io_uring/epoll) |
| Linux aarch64 | ✅ | ✅ | ✅ (epoll) |
| macOS x86_64 | ✅ | ✅ | ✅ (kqueue) |
| Windows x86_64 | ✅ | ✅ | ✅ (IOCP) |
| FreeBSD | ✅ | ✅ | ✅ (kqueue) |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-19 | 1.1 | TAsyncLoop class 生命周期 | Claude |
| 2026-07-11 | 1.0 | 初始版本 | Claude |


### OnDiscard / Close
- Heap wraps posted to the loop must provide OnDiscard when Close may discard them.
- Timeout I/O uses ScheduleEx + TimeoutCtxDiscardTimer so Close free TTimeoutCtx.
- TCP async write uses AsyncSend (not positioned AsyncWrite).

### Backpressure (B1)
- `IBackpressureController.OnStateChange` registers a callback; transitions are notified via `TAsyncLoop.PostEx` (not under the controller lock).
- Channel queue backpressure and stream watermarks are separate tools — do not merge types.

### Timeout cancel (B2)
- `Async*Timeout` timer path calls `TPoller.TryCancelByContext(TimeoutCtx)` after user `-ETIMEDOUT`.
- io_uring: real `IORING_OP_ASYNC_CANCEL`; epoll: remove pending + internal `-ECANCELED`; IOCP: not guaranteed.
