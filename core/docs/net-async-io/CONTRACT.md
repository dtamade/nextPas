# nextpas.core.async / nextpas.core.net 代码契约

**模块路径**：`core/src/nextpas.core.async*.pas` + `core/src/nextpas.core.net*.pas`
**层级**：L1-L2（依赖 L0: platform, base, errors）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

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
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |


### OnDiscard / Close
- Heap wraps posted to the loop must provide OnDiscard when Close may discard them.
- Timeout I/O uses ScheduleEx + TimeoutCtxDiscardTimer so Close free TTimeoutCtx.
- TCP async write uses AsyncSend (not positioned AsyncWrite).

### Backpressure (B1)
- `IBackpressureController.OnStateChange` registers a callback; transitions are notified via `TAsyncLoop.PostEx` (not under the controller lock).
- Channel queue backpressure and stream watermarks are separate tools — do not merge types.

### Timeout cancel (B2)
- `Async*Timeout` timer path calls `TPoller.TryCancelByContext(TimeoutCtx)` after user `-ETIMEDOUT`.
- io_uring: real `IORING_OP_ASYNC_CANCEL`; epoll/kqueue: remove pending + internal `-ECANCELED`; IOCP: `CancelIoEx` by context (completion packet still arrives).

### IOCP (B4)
- `TIocpReactor` is a real completion backend (not a stub); `TPoller` wires `pbIocp` on Windows.
- Evidence: `truth=wine-runtime-smoke` via `test_reactor_iocp_wine` + `test_poller_windows_runtime_smoke`; still not native Windows host runtime ready.

### Kqueue (B3)
- `pbKqueue` readiness backend wired into `TPoller` for macOS/FreeBSD (`TKqueueReactor`).
- Evidence: source-contract + `test_async_kqueue_compile_gate` (FORCE_HOST) + `test_async_kqueue_runtime_smoke`.
- **CI L0 (Q11)**: macOS job runs `ASYNC_HOST_GATES=kqueue-runtime` **fail-closed** (must print `kqueue-runtime-smoke=pass`; skip fails on Darwin).
- Linux host: runtime smoke exits skip (not a failure). Still not a claim of full macOS async I/O parity.

### HE-lite dial (Q6)
- `platform_socket_resolve_stream`: getaddrinfo multi-A (cap 16), AF_UNSPEC.
- `NetResolveAll` / `AsyncResolve`: v4-first then v6 list.
- `NetTcpConnect` / `AsyncTcpConnect`: sequential try each address (IPv4+IPv6); **not** concurrent RFC8305 Happy Eyeballs.

### Concurrent Happy Eyeballs (Q7/Q8)
- `AsyncTcpDial` / `AsyncTcpDialAddrs` in `net.async.dial`: staggered concurrent attempts on `TAsyncLoop` (`AsyncConnect` + timers).
- Defaults: ConnectionAttemptDelayMs=250, MaxInFlight=2, **InterleaveFamilies=True** (RFC-style alternate v4/v6).
- Address `Port<>0` honored (else dial port); multi-A first-fail-second-win covered by tests.
- Optional overall deadline + CancellationToken; single user callback; 0 leak.
- Does **not** replace HE-lite sync `AsyncTcpConnect`.

### Parallel DNS + RFC timer knobs (Q9)
- `platform_socket_resolve_stream_family(AHost, AFamily, ...)`: multi-A for AF_INET / AF_INET6 / AF_UNSPEC.
- `AsyncResolveEx` / `DefaultDnsResolveOptions`: parallel A + AAAA workers + **ResolutionDelayMs** (default 50); `AsyncResolve` remains single AF_UNSPEC path.
- Dial options: `FirstAddressFamilyCount` (default 1), `ResolutionDelayMs` (default 50).
- OrderAddresses: optional lead N of preferred family, then interleave or bucket remainder.
- Host evidence: `core/scripts/async-host-matrix.sh` — Linux CI strict; macOS dial/resolve + kqueue L0 fail-closed (Q12).

### DNS-race-while-dialing (Q10)
- `AsyncResolveStream`: parallel A/AAAA; after Resolution Delay gate, posts per-family batches then one terminal `AllDone`.
- `AsyncTcpDial` host path uses Stream: starts HE as soon as first family addresses arrive; late family addresses append/interleave into remaining attempts.
- `MaybeCompleteIfIdle` waits for `FDnsAllDone` before failing empty.
- State machine: stream family batch → first non-empty `StartDialing`+`OrderAddresses` once → late family `AppendAddresses` into untried suffix → complete only after `AllDone` when idle.

### Strict CAD + timing observability (Q11)
- **Connection Attempt Delay** is start-to-start: each successful `AsyncConnect` submit is followed by CAD before the next start; **MaxInFlight only caps concurrency** (no burst-fill while loop).
- `ConnectionAttemptDelayMs=0` allows immediate refill after failure (and 0-delay arm when under MaxInFlight); CAD=0 never arms 0-delay timers while at MaxInFlight (avoids busy-spin).
- Optional observability: `OnAttemptStart` / `OnAttemptStartContext` (tests; default nil).
- Evidence: `StrictCadDoesNotBurstStart`, `CadZeroAllowsImmediateRefill`, `FirstFamilyAttemptOrder` in `test_net_async_dial` (0 leak).

### DNS×SYN lab harness (Q12)
- `IAsyncTcpDialDnsFeed` + `AsyncTcpDialWithDnsFeed`: inject DNS stream events without real getaddrinfo; same `OnDnsStream` state machine as host path.
- `FeedAddresses` / `SignalDnsDone` post onto the loop; feed detaches safely when dial finishes.
- Evidence: `DnsRaceStartsBeforeLateFamily`, `DnsRaceLateFamilyInterleaves`, `DnsRaceEmptyUntilDoneFails`, `DnsRaceWaitsAllDoneWhenAddrsExhausted` (0 leak).
- macOS CI: dial-resolve matrix **fail-closed** (with kqueue L0); still not full macOS async parity.

### Error classification + Dial product default (Q13)
- `ClassifyNetError(ACode)` in `nextpas.core.net.errors` (re-exported from `nextpas.core.net`): maps dial/IO result codes (signed or absolute) to `TNetErrorClass` with `Kind`, `Timeout`, `Temporary`, `Canceled`, `Code`.
- Kind table: ok / canceled / timeout / refused / reset / unreachable / dns / temporary / invalid / unknown.
- Portable codes use `PLATFORM_ERR_*`; cancel uses `NET_ERR_CANCELED` (125, async convention).
- **Recommended dial**: `AsyncTcpDial` / `AsyncTcpDialAddrs` (concurrent HE). `AsyncTcpConnect` remains HE-lite sequential **legacy**.
- Lab-only: `AsyncTcpDialWithDnsFeed`.
- **LocalAddr (Q25)**: `TAsyncTcpDialOptions.LocalAddr` — bind-before-connect when `IP <> ''` and family matches remote attempt (Go `Dialer.LocalAddr` subset). Empty IP = unset. No Control/MPTCP.
- **NoDelay / KeepAlive (Q26)**: applied to the winning stream before the user callback when set true (defaults false; best-effort).
- **OnControl (Q27)**: Go `Dialer.Control` subset — after create/[LocalAddr bind], before connect; `AError<>0` fails that attempt only. Not RawConn.
- **OnResolve (Q28)**: custom resolver hook — when set, host path skips `AsyncResolveStream`; caller injects via `IAsyncTcpDialDnsFeed` (must `SignalDnsDone`). Lab `AsyncTcpDialWithDnsFeed` is the same feed contract without host string.
- **AddressFamily (Q30)**: `dafAny` / `dafIPv4` / `dafIPv6` filters resolved or DialAddrs lists before HE ordering.
- **OnAttemptResult (Q31)**: per-attempt outcome hook (success AError=0 or fail code); Control rejects also report. Loop thread.
- **MPTCP**: deferred (platform/portability); not exposed.
- **native-windows claim**: remain `native-windows-candidate` (Q24B fail-closed suite); full parity not claimed.
- Evidence: `test_net_error_classify`; parity doc `core/docs/net-async-io/GO-RUST-PARITY.md`.

### Cancel vocabulary bridge (Q14)
- **Recommended user token**: `IAsyncCancellationToken` (dial, combinators, TaskGroup).
- **Blocking TCP plumbing**: `INetCancelToken` + optional `INetCancelWaitable` (socketpair wake) via `NewNetCancelToken`.
- Bridge: `NetCancelFromAsync(async)` → `INetCancelController` (waitable on Unix); async Cancel propagates to net Cancel.
- `TcpStreamBindAsyncCancel(stream, async)` / `IAsyncTcpStream.BindCancelToken(async)` installs the bridge on a stream.
- Does **not** delete Net tokens; HTTP adapters remain. Unit: `nextpas.core.net.async.cancel`.
- Evidence: `test_net_cancel_bridge` (propagate, already-cancelled, waitable, blocking read cancel, 0 leak).

### Async UDP (Q15)
- `IAsyncUdpSocket` / `AsyncUdpBind` in `net.async.udp` (IPv4, matches sync `NetUdpBind`).
- `AsyncSendTo` / `AsyncRecvFrom` (+ Timeout) via poller `AsyncSendTo`/`AsyncRecvFrom`.
- Reactors: epoll + kqueue ops; **io_uring backend uses epoll sidecar** for datagram; IOCP via WSASendTo/WSARecvFrom.
- Full-duplex: epoll keeps one IN op and one OUT op per fd (`EPOLLIN|EPOLLOUT`, `data.u64` = fd). Completing one direction re-arms the other and immediately probes (ET+ONESHOT). `AsyncSend`/`AsyncWrite`/`AsyncSendTo` try the syscall first; only EAGAIN/EINTR waits for writable. kqueue keeps independent `EVFILT_READ`/`WRITE` and deletes only the completed filter.

### Write buffer lifetime（C-10）

热路径**零拷贝**：`AsyncWrite` / `AsyncSend` / `AsyncSendTo` 把调用方 `ABuf` 裸指针存进 pending op，**不 memcpy**。提交成功到写回调返回前，调用方必须保持该缓冲有效（短写续发期间同样有效）。读路径对称：`AsyncRead`/`AsyncRecv` 的接收缓冲也须活到回调。

短写语义（与阻塞 `write()` 循环不同，也不同于 sing-box `net.Conn.Write` 写满才返回）：

- 回调 `AResult > 0` = **本次 syscall 实际送达字节**，可能 `< ALen`。
- **不自动续发**；一 op 一回调。剩余字节由调用方再次 `AsyncSend`（EPOLLONESHOT 下须重新提交）。
- `AResult < 0` = `-errno`；`AResult = 0` 对写少见，按失败处理。

对照：sing-box `WriteBuffer` 在阻塞 Write 上转移 `*buf.Buffer` 所有权并 `Release`；Go 标准库 Write 内部循环写满。我们是事件循环 IO 模型，不能在反应器里循环 `send()`（会卡住 loop）。调用方持有 + 短写续发（proxy888 `FTxBuf`）才是热路径正确形态。**不提供默认 `AsyncWriteCopy`**：每发送一次 memcpy 比零拷贝持有更差，短包握手由调用方字段持有即可。

Evidence: `test_epoll_reactor` write-buffer source contract + short-write one-shot.
- `IUdpSocketRuntime` exposes native fd for async layer.
- Evidence: `test_net_async_udp` loopback + timeout + same-socket send-while-recv + 0 leak; `test_epoll_reactor` UDP send-while-recv + socketpair EAGAIN full-duplex.
- Not: IPv6 UDP, multicast, connected UDP API.

### Connection pool async acquire (Q16)
- `IConnectionPool.AcquireAsync(host, port, cb, ctx, token?)`: prefer idle; else `AsyncTcpDial` (HE).
- `IConnectionPool.AcquireAsyncEx(host, port, dialOpts, cb, ctx?)` **(Q29)**: same idle path; dial path forwards full `TAsyncTcpDialOptions` (LocalAddr/NoDelay/KeepAlive/Control/Resolve/…). Pool `ConnectTimeout` fills infinite overall deadline only.
- Requires `CreateConnectionPool(Loop[, Config])`; sync-only `CreateConnectionPool` → AcquireAsync returns False after reserving path without loop.
- Idle keyed by host+port; `Release` returns to idle; `Discard` closes.
- `ConnectTimeout` → dial `OverallDeadline`; optional `IAsyncCancellationToken`.
- Evidence: `test_net_async_pool` dial / idle reuse / max connections, 0 leak.

### Platform evidence deepen (Q17)
- `test_async_accept_connect_smoke`: loopback dial via `AsyncTcpDial` on host poller (Linux epoll/io_uring; Darwin/FreeBSD kqueue; Windows skip).
- `test_async_kqueue_runtime_smoke`: on Darwin/FreeBSD also runs accept+connect loopback; prints `kqueue-accept-connect-smoke=pass`.
- `async-host-matrix` includes accept_connect + udp + pool entries.
- Windows native: see `WINDOWS-NATIVE-ASSESSMENT.md` — **not** native-windows claim; wine-runtime-smoke remains IOCP evidence.

### Same-host bench parity (Q18)
- Script: `core/scripts/async-bench-parity.sh` runs `test_async_bench` + Go/Rust peer microbenches.
- Peers: std channel/mutex/timer shapes — **not** TAsyncLoop clones; order-of-magnitude only.
- truth=`same-host-order-of-magnitude`; **not CI-gating**; do not claim “faster than Go/Rust” from this table alone.
- SCORECARD table updated from a 2026-07-20 host run.

### Localhost dial bench (Q19 + Q20)
- `test_net_async_dial_bench`:
  - sequential `AsyncTcpDialAddrs` (one `Run` per dial) → `metric=dial_ops_per_s`
  - concurrent single-`Run`, W in-flight `AsyncTcpDialAddrs` → `metric=dial_concurrent_ops_per_s`
- Go peers:
  - sequential: `core/scripts/async-bench-parity/go-dial` (`net.DialTimeout`)
  - concurrent: `core/scripts/async-bench-parity/go-dial-concurrent` (W-semaphore goroutines)
- Included in `async-bench-parity.sh` (opt-in, not CI-gating).
- truth=`localhost-sequential-dial` / `localhost-concurrent-dial` — **not** public DNS / dual-stack HE RTT matrix.
- Concurrent path is single-loop pipelined dials; listener accept is not required for SYN-complete success on localhost backlog (client closes immediately).

### Public DNS HE stats (Q21 / Q23)
- Suite: `test_net_async_dial_public_he` — multi-host matrix:
  - `one.one.one.one:443`, `dns.google:443`, `cloudflare.com:443`
  - per-host metrics: ok/fail/mean_ms/attempts_mean/attempt_v6_ratio/winner_v6_ratio
  - aggregate: `metric=public_he_aggregate`
- **Opt-in only**: `NEXTPAS_PUBLIC_DNS_HE=1` (wrapper: `bash core/scripts/async-public-he-stats.sh`).
- Env: `NEXTPAS_PUBLIC_DNS_HE_ROUNDS` (default 2, clamp 1..5);
  `NEXTPAS_PUBLIC_DNS_HE_V6PREF=1` runs a second pass with `PreferIPv6First`.
- Default: skip (exit 0). All-fail rounds print soft-fail metrics; **never** CI-gating.
- truth=`public-dns-he-multihost-opt-in; flaky; not-ci-gating; sample-not-sla`.

### Windows native async smoke (Q22 / Q24A / **Q24B**)
- Script: `core/scripts/async-windows-native-smoke.sh` (compile gate + contract + poller/IOCP + accept/connect).
- CI: `test-windows-runtime` step **fail-closed** (`ASYNC_WINDOWS_STRICT=1`; no `continue-on-error`).
- Streak observer: `bash core/scripts/async-windows-smoke-streak.sh`.
- truth: **native-windows-candidate** on bare-metal Windows host (suite-limited; not full host parity).
- Soft escape: `NEXTPAS_ASYNC_WINDOWS_BEST_EFFORT=1` (local only; not default in CI).
- Do **not** treat Wine green as full `truth=native-windows`.
