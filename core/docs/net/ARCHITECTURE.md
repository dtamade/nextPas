# nextpas.core.net server runtime 架构

最近更新：2026-06-04

这份文档固定 `nextpas.core.net.server` 的长期职责与演进方向。
如果 `docs/plans/2026-06-03-http-server-runtime-foundation.md` 与这里冲突，以本文为准。

## 目标

`nextpas.core.net.server` 是可复用的 TCP server runtime foundation。
它服务于 `nextpas.core.http`，也服务于未来其他基于 TCP 的协议模块。

这层的目标不是把今天的 thread-per-connection 实现永远做下去，而是先稳定公共边界，
再让同一个 foundation 承载：

- threaded backend
- Linux `epoll` backend
- macOS / FreeBSD `kqueue` backend
- Windows `IOCP` backend

## 固定选型

### 1. 公共编程模型保持 Go 风格

- 对应用层继续暴露简单、同步、直线型的 server / handler API。
- `nextpas.core.http` 不改成 callback-first 或 event-loop-first 的 public facade。
- 先保 public contract 稳定，再演进内部 runtime。

### 2. 内部 ownership split 采用 Tokio / Hyper 风格

- runtime backend 负责 listener、accept、连接注册、shutdown、worker handoff。
- 协议模块负责单连接协议状态机，例如 HTTP 的解析、序列化、keep-alive、hijack。
- 一个连接对应一个协议 state object，由 runtime 驱动，而不是让协议层自己拥有线程模型。

### 3. 后端策略采用 libuv 风格

- Linux 目标后端：`epoll`
- macOS / FreeBSD 目标后端：`kqueue`
- Windows 目标后端：`IOCP`

`threaded` 是当前已落地的基线后端，不是最终唯一形态。
Windows 长期目标明确是 `IOCP`，不是 `WSAPoll` 兼容路线。

## 主流范式对照与结论

这轮把“参考谁”也固定下来，避免后续再把不同层的问题混在一起：

- Go `net/http` 值得学的是 public model：
  handler 简单、同步、直线型；消费方不需要理解 event loop。
- Tokio / Hyper 值得学的是 internal ownership split：
  runtime 驱动 connection state object，协议层不拥有线程模型。
- libuv 值得学的是 backend discipline：
  Linux 走 `epoll`，BSD/macOS 走 `kqueue`，Windows 走 `IOCP`。

nextPas 不复制其中任何一个的整套实现，而是固定成混合选型：

- public surface：Go-like
- protocol/runtime split：Tokio / Hyper-like
- backend policy：libuv-like

这也是对“线程驱动是不是过时”的正式回答：

- 仅有 thread-per-connection，当然不够现代。
- 但只追求 event loop 外观，同样会把 public API 和协议层一起拖复杂。
- 正确做法是把“同步 public contract”和“可替换 runtime backend”分层固定，
  让线程模型、reactor 模型、未来 `IOCP` 模型都能挂到同一 foundation 上。

这里还要再固定一条实现纪律，避免后面把不同 I/O 家族混成一锅：

- `epoll` / `kqueue` 属于 readiness family，可以共享同一条 poll-driven session 设计。
- `IOCP` 属于 completion / proactor family，不能靠“伪造 readable / writable 事件”硬塞进
  readiness-only driver。
- 因此 future Windows backend 要共享的是 foundation ownership / session / handoff contract，
  不一定是逐字复用今天的 `PollEvents + Advance(...)` 低层 driver 形状。

## 当前源码真相

截至 2026-06-03，相关源码边界已经收口到下面这个形态：

- [src/nextpas.core.net.server.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.base.pas:1)
  已固定 backend 枚举：`tsbThreaded`、`tsbEpoll`、`tsbKqueue`、`tsbIocp`。
- [src/nextpas.core.net.server.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.intf.pas:1)
  已固定 foundation contract：`ITcpServer` / `ITcpServerHandler`，并已收进
  `ITcpServerSession`、`ITcpServerWorkerHandoff`、`ITcpServerSessionContext`、
  `ITcpServerSessionFactoryWithContext`、`ITcpServerPollDrivenSession`
  这些后续 backend 必需的 seam。
- [src/nextpas.core.net.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.pas:1)
  现在已经有 backend factory registry seam：`RegisterTcpServerFactory` /
  `TryGetTcpServerFactory` / `ResolveTcpServer`；`NewTcpServer(...)` 不再把 backend 选择写死在
  facade 的 `case` 里。
- [src/nextpas.core.net.server.runtime.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.runtime.pas:1)
  已把通用的 worker handoff、session context、connection close 语义收成 foundation
  runtime helper，避免 threaded / evented backend 重复复制这层逻辑。
- [src/nextpas.core.net.server.threaded.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.threaded.pas:1)
  是当前 correctness 基线 backend，负责 listen / accept / shutdown / detach ownership，
  并先用 foundation-owned worker handoff 证明 session/context/handoff contract 成立。
- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:1)
  现在同时承载两条路径：
  - phase-1：`epoll` 负责 listener readiness 与 nonblocking `TryAccept`，
    blocking session 继续交给 foundation worker 执行
  - phase-2 seam：若 session 同时实现 `ITcpServerPollDrivenSession`，
    `epoll` 可直接驱动该 per-connection session
- [src/nextpas.core.net.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.intf.pas:1)
  现在提供了 `ITcpSocketRuntime`、`ITcpListenerRuntime.TryAccept`、
  `ITcpStreamRuntime.TryRead/TryWrite` 这组 runtime-only seam，用来暴露 native socket
  handle、blocking control 与 nonblocking I/O 结果。
- [src/nextpas.core.net.tcp.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.tcp.pas:1)
  已让 `TTcpStream` / `TTcpListener` 实现上面这组 runtime seam，把 evented backend 的前置条件
  收进 foundation，而不是继续依赖具体实现类强转。
- [src/nextpas.core.http.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.server.pas:1)
  现在只是 HTTP facade，真实 runtime ownership 已下沉到 `ITcpServer`。
- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:104)
  已有 `TH1ServerConnectionState`，说明 HTTP 单连接协议状态与 runtime entrypoint 已开始分离。

## 当前真实执行模型

当前 repo 不是“纯线程驱动”，但也还不是“完整 event-driven connection runtime”：

- `threaded` backend：
  `accept` 后由连接 worker 同步执行协议 session；这是 correctness baseline。
- `epoll` phase 1 backend：
  只有 listener / accept 一定是 evented 的；blocking session 仍交给 worker 执行同步 session。
- `epoll` poll-driven session path：
  foundation 已能直接驱动实现 `ITcpServerPollDrivenSession` 的 session，
  并且现在已经具备 worker-completion -> reactor 的 wakeup / re-entry 基础能力；
  但这条能力目前还只是 foundation runtime seam，尚未被 H1 server 消费为默认路径。
- HTTP H1：
  `TH1ServerConnectionState` 已经是独立的 per-connection protocol state object，
  只是当前仍由 threaded worker 或 `epoll` handoff worker 去跑它的 `Run`。

所以今天的真实结论必须分两句说：

- 并发模型已经不是“HTTP 自己起线程”，而是 `net.server` foundation 统一拥有 runtime。
- 但高连接数场景下最关键的“per-connection read/write 调度”还没进入 phase-2 evented driver。

## 当前阶段门

当前需要固定的真相不是“还没开始做 evented backend”，而是：

- nonblocking runtime I/O seam 已经落地
- backend provider / registry seam 已经落地
- Linux `epoll` 第一阶段 backend 已经落地
- Linux `epoll` 的 poll-driven session seam 已经落地
- Linux `epoll` 的 reactor self-wakeup seam 也已落地：
  session 可以在等待 foundation-owned wake source 时暂时没有 socket interest，
  backend 再把 completion/wake 拉回 reactor 继续推进同一 state object
- 还没落地的是“HTTP H1 等真实协议 state object 全量迁入这条 evented driver”的完整版执行

原因很直接：

- 只有 `TryAccept/TryRead/TryWrite` 这类 would-block-friendly seam 先稳定，reactor / proactor
  runtime 才能把“暂时没数据/暂时不能写”当作正常调度分支处理。
- 但如果 backend 只是拿这条 seam 做 accept，再把整连接继续交给阻塞式 handler，
  那它仍然只是“accept 侧 evented”，还不是“connection state 侧 evented”。
- 所以后续仍然要把 `TryRead/TryWrite` 真正接入 per-connection runtime driver。

所以当前固定的阶段门是：

- blocking public API 继续保留：
  - `ITcpListener.Accept`
  - `ITcpStream.Read`
  - `ITcpStream.Write`
- runtime-only seam 同时保留并持续扩用：
  - `ITcpListenerRuntime.TryAccept`
  - `ITcpStreamRuntime.TryRead`
  - `ITcpStreamRuntime.TryWrite`
- would-block 是正常返回值，不是异常路径
- 真错误仍抛 `ENetworkError`
- Linux `epoll` 第一阶段 backend 可以先只消费 `TryAccept`
- 真正的 reactor / proactor per-connection backend 必须进一步消费 `TryRead/TryWrite`
  来驱动协议 state object
- 对 BSD/macOS 的 `kqueue`，这条 readiness seam 可以直接复用。
- 对 Windows `IOCP`，必须在同一 public contract 下补 completion-aware driver 语义，
  而不是把 overlapped completion 假装成普通 readiness edge。

当前 repo 真相进一步收口为：

- `ITcpServerSession` / `ITcpServerSessionFactory` 已进入 foundation contract，
  runtime 不必再只依赖整连接阻塞式 `ServeConn`
- `ITcpServerSessionFactoryWithContext` + `ITcpServerSessionContext` +
  `ITcpServerWorkerHandoff` 也已进入 foundation contract，用来表达
  “runtime 提供 handoff，协议 session 自主决定是否把工作转交给 worker”
- threaded backend 已先消费这条 seam，证明 accepted / failed / shutting-down handoff
  语义可以被 focused tests 锁定
- epoll backend 也已经复用同一条 seam，证明 evented listener 侧不需要再复制一套独立
  session/context/handoff 模型
- `platform.io` poller 现在也有 wake seam；Linux 先用 `eventfd` 落地。
- `epoll` backend 现在会把 poll-driven session 的 worker completion 先排队回 reactor，
  再在 reactor 线程执行 completion，并用 synthetic re-entry 继续推进该 session。
- `epoll` backend 现在也已具备 poll-driven session deadline wake seam：
  session 可选暴露 wake deadline，reactor 会按最近 deadline 缩短 `poller_wait`，
  并在到期时以 `Advance([])` synthetic re-entry 再次推进该 session。
- `IHttpServerTransport.ServeConn(const AConn: ITcpStream; ...)` 仍然保留，作为 HTTP public facade
  继续同步、兼容旧 transport seam 的刻意选择
- `TH1ServerConnectionState` 现在已经通过 `ITcpServerSession` 接上 foundation，
  说明 HTTP 单连接协议状态与 runtime entrypoint 的 split 不再只是内部草稿

所以当前固定的后续顺序是：

1. 守住 threaded 与 `epoll` phase-1 的 public contract parity
2. 让 future evented backend 直接复用已落地的 factory/session/context/handoff seam
3. 用同一条 worker handoff contract 保证业务 handler 不落到 reactor 线程
4. 让 H1 等真实协议 session 消费这条带 wakeup 的 poll-driven driver
5. 然后再扩 `net.server.kqueue` / `iocp`

## 性能与并发 posture

这部分也需要固定，不然后续容易把“现在可用”和“最终目标”说混：

- 当前 `threaded` 默认后端：
  适合先把 correctness、ownership、shutdown、hijack、backpressure 契约做实；
  对中低到中等并发是可用的，但不是最终高连接密度路线。
- 当前 `epoll` phase 1：
  已经降低了 listener / accept 侧的阻塞与 wakeup 粗糙度，也证明了 foundation seam
  可以承载 evented backend；但它还没有解决“每个连接都靠同步 worker 驱动”的最终扩展性问题。
- 目标 evented phase 2：
  真正提升大规模 keep-alive、慢连接、backpressure、空闲连接密度的上限，
  依赖的是 runtime 直接驱动 protocol state object，而不是只把 accept 做成 evented。

因此这里不把“性能好吗”写成空泛口号，而是固定成工程判断：

- 现在：correctness-first，可用，但不是终局性能形态。
- 目标：foundation 不变，backend 从 threaded / accept-evented 演进到 per-connection evented。
- 原则：任何性能演进都不能倒逼 public HTTP contract 改成 callback-first。

## 分层边界

### `nextpas.core.net.server` 负责什么

- listen / bind / accept
- runtime backend 选择
- 连接生命周期与 shutdown
- 单连接 ownership 语义
- detach / hijack-friendly handoff
- evented backend 的 worker handoff seam
- Windows / epoll / kqueue / IOCP 这类 runtime-specific I/O 策略

### 协议模块负责什么

以 `nextpas.core.http` 为例，协议层负责：

- request parsing
- response serialization
- keep-alive 语义
- pipelining / request-tail isolation
- protocol-level ownership transfer
- per-connection protocol state object

协议层不负责：

- 线程创建
- reactor / proactor backend 选择
- `epoll` / `kqueue` / `IOCP` 细节
- 跨平台监听与 accept runtime

## 公开 contract 约束

这些规则现在固定，除非以后有显式架构评审替换：

- `ITcpServer` 是协议模块消费的统一 runtime seam。
- `ITcpServerHandler.ServeConn` 返回 ownership，server 与 handler 的连接责任要显式可证明。
- `ITcpServerSession` 是 foundation-owned “单连接协议状态对象” seam。
- `ITcpServerSessionFactoryWithContext` 允许 runtime 把 `ITcpServerSessionContext`
  明确传给 session，而不是让协议层偷看 runtime 实现类。
- `ITcpServerWorkerHandoff.Submit` 的 accepted / rejected / shutting-down 语义必须稳定；
  accepted 后由 executor 负责最终调用 completion 一次，failed work 统一回落到
  `server-owned close` 语义。
- `ITcpServerPollDrivenSession` 当前是 readiness-family driver seam：
  它服务于 `threaded` fallback、Linux `epoll` 与 future `kqueue` 这条线路；
  不能把它误解成“所有 backend 必须伪装成 poll events”。
- 对 poll-driven session，worker completion 不应直接在 worker 线程里推进协议状态机；
  foundation backend 必须把 completion 送回 reactor / owning runtime thread。
- `ITcpServerPollDrivenSession.Advance(...)` 可以合法返回 `ANextEvents := []`，
  表示“当前没有 socket interest，等待 foundation-owned wake source”，
  backend 负责在 wake 后以 synthetic re-entry 再次推进该 session。
- `ITcpServerPollDrivenSessionWithDeadline.WakeDeadline(...)` 是可选 opt-in seam：
  返回 `Infinite` 表示当前不需要 timer wake；返回 finite deadline 时，
  backend 必须把它纳入 wait timeout 计算，并在到期后以 `Advance([])` 重入该 session。
- `ITcpSocketRuntime` 是 lower-level runtime seam：普通业务代码可以忽略它，evented backend 可以通过
  `Supports(...)` 取得 native handle 与 blocking control，而不需要偷看具体实现类。
- `ITcpListenerRuntime` / `ITcpStreamRuntime` 是更窄的 runtime-only I/O seam：
  would-block 必须作为正常结果返回，不能重新编码成异常。
- future `IOCP` backend 若需要 sibling completion-driven driver 或 generalized runtime-driver
  contract，允许在 foundation 层新增；但必须保持 `ITcpServer` / `ITcpServerSession` /
  `ITcpServerSessionContext` / `ITcpServerWorkerHandoff` 这组 ownership 边界不变。
- completion-based backend 必须按“操作完成”而不是“socket 就绪”推进状态机；
  per-connection state object 必须自己关联 outstanding accept/read/write operation 与 buffer
  生命周期，不能假设 completion dequeue 顺序天然等于 submit 顺序。
- “一个连接 = 一个协议 state object” 必须进入 foundation seam，而不是长期停留在
  `http.impl.h1` 这种实现细节里。
- 旧的 `ServeConn` 可以为了兼容继续保留，但新 backend 不应再只依赖整连接阻塞 entrypoint。
- `nextpas.core.http.server` 这类上层 facade 只能做编排，不再重复实现 accept loop。
- 上层模块可以保留同步 handler surface；evented backend 必须在内部做 worker handoff，不能把任意 handler 直接跑在 reactor 线程。

## 模块形态

目标结构固定为：

```text
nextpas.core.net.server.base
nextpas.core.net.server.intf
nextpas.core.net.server.runtime
nextpas.core.net.server.threaded
nextpas.core.net.server.epoll
nextpas.core.net.server.kqueue
nextpas.core.net.server.iocp
```

这里不走深继承 `BaseServer` 大类路线。
`nextPas` 更适合窄接口 + 可替换 backend 单元，而不是一个不断膨胀的基类层次。

## 为什么不是 `TBaseServer`

这个问题必须在 foundation 层一次答清楚，否则后续每个 TCP server 都会重复争论。

共享问题确实在 server runtime 层，但共享的不是“一个越来越大的公共父类”，而是下面这些职责：

- listener / accept loop
- backend 选择与运行时驱动
- 连接 ownership / detach / shutdown
- worker handoff
- cross-platform I/O strategy

这些职责天然属于 `nextpas.core.net.server` 这个 foundation 模块，而不属于某个协议特定的
`TBaseServer` 对象模型。

如果走深继承路线，通常会出现三类退化：

- 基类开始吸收协议差异，最后把 HTTP/SMTP/WebSocket/自定义二进制协议的语义都做成 hook。
- evented backend 与 `IOCP` 这类运行时语义会把“线程驱动父类”扭曲成条件分支堆。
- hijack、pipeline、半关闭、backpressure 这类协议相关行为会被错误地下沉到基类，破坏职责边界。

这里固定的结论是：

- 共享 runtime 走模块化 foundation：`ITcpServer` + backend units。
- 协议差异走组合：protocol handler + per-connection state object。
- “基类”概念只保留在模块层和 contract 层，不引入一个主导一切的大继承树。

如果以后为了复用配置或默认装配想引入某种“server convenience class”，也只能是薄 facade：

- 可以包装 `ITcpServer` / options / default wiring
- 不能重新拥有 accept loop / backend policy / reactor policy
- 不能把协议特有语义重新吸回一个共享父类

这同样适用于未来别的 TCP server，不只是 HTTP。
后续 `redis`、`smtp`、自定义 RPC 等 server 都应该复用同一 foundation，而不是各自再造
一棵 `BaseServer` 派生树。

## backend 语义规则

### threaded

- 允许单连接 worker inline 执行 handler。
- 当前 correctness 基线由它提供。
- 当前也负责 first proof：session context 可见、worker handoff 可用、shutdown 后 handoff
  会拒绝新任务。

### epoll phase 1

- 这是“evented accept + threaded connection execution”，不是最终完整版 evented runtime。
- `epoll` 线程负责 listener readiness 与 `TryAccept`。
- accepted connection 会被交给 foundation worker，再按同步协议 contract 执行 handler / session。
- 当前 focused proof 主要锁定：
  - backend 选择有效
  - simple request contract 与 threaded 一致
  - session context / worker handoff seam 可复用

### evented phase 2

- runtime 直接驱动协议 state object。
- 不能在 reactor 线程直接执行无界 handler 逻辑。
- 必须有明确 worker handoff 或 bounded execution 策略。
- reactor 必须具备 self-wakeup 能力，worker completion 需要先回 reactor，
  再继续推进 poll-driven session。
- `TryRead/TryWrite` 会成为真正的调度 seam，而不再只是 lower-level 预留接口。
- 这一步完成后，`threaded` / `epoll` / `kqueue` / `IOCP` 才能算真正共享同一条 session driver 设计。

### Windows

- 长期目标是 `IOCP`。
- 不能把 `WSAPoll` 作为最终设计终点。
- Windows backend 的语义目标是与其他 backend 保持同一 public contract，
  不是强行伪装成 readiness-only 模型。
- IOCP completion packet 是 completion queue 语义，不是 `epoll` 式 readiness 边沿；
  foundation 设计必须显式承认这一点。
- IOCP packet queue / runnable thread release 也有自己的调度语义；
  协议顺序必须由 connection state object 维护，不能偷懒依赖 runtime dequeue 顺序。

## 非目标

这一轮不在 foundation 里同时解决下面这些问题：

- 改 public HTTP API 为 async
- 重新设计 `IHttpRequest.Body` contract
- 把 spool / spill / buffer pool 和 runtime foundation 混成一批
- 直接把 `io_uring` 绑死成唯一 Linux server backend

这些都属于 foundation 稳定后的后续阶段。

## 演进顺序

### Phase 1

- foundation base / intf / threaded backend 先落地
- 先让 HTTP runtime ownership 下沉到 `net.server`

### Phase 2

- 继续把 `http.server` 收到 facade / composition 角色
- 让协议状态对象边界更清晰
- 收口 foundation runtime helper 与 session/context/handoff seam

### Phase 3

- 完成 nonblocking runtime I/O seam proof
- 复用已落地的 connection session + worker handoff seam
- 落地 Linux `epoll` 第一阶段 backend
- 证明同一 HTTP contract 可由非 threaded backend 驱动

### Phase 4

- 落地 reactor self-wakeup / completion re-entry foundation
- 让 poll-driven session 可以在等待 worker completion 时暂时没有 socket interest
- 让 poll-driven session 可以在等待 deadline 时不依赖 socket readiness 被主动重入
- 把 `TryRead/TryWrite` 接进 per-connection runtime driver
- 让 Linux evented backend 从 phase 1 升级到真正的 connection-state-driven backend

### Phase 5

- 增加 `net.server.kqueue`

### Phase 6

- 在 foundation 层抽出 completion-aware runtime driver 语义，
  但不改变 `ITcpServer` / session / handoff public boundary

### Phase 7

- 增加 `net.server.iocp`

### Phase 8

- 再进入 buffer pool、streaming body、spill / spool、write coalescing、
  `io_uring` 评估、基准对照这些性能阶段

## 当前阶段判断

截至 2026-06-03，这条架构线已经不是纯讨论状态，而是进入“方向已固定、实现继续收口”的阶段：

- foundation seam 已存在：`base` / `intf` / `runtime` / `threaded`
- connection session / worker handoff seam 已经进入 foundation contract
- Linux `epoll` phase-1 backend 已经存在，并有 focused tests 证明它能跑通 foundation + HTTP 基线
- HTTP facade 已开始依赖 `ITcpServer`
- backend 选择与 server lifecycle 已经进入 public contract

因此后续工作重点不是再反复选型，而是沿这条线继续把职责收干净：

- `http.server` 继续收成 facade / composition
- 协议状态继续收进 connection state object
- correctness proof 先补齐，再把 Linux backend 从 accept-evented 升到 connection-evented
- 然后再扩 `kqueue` / `IOCP`

## 验收门槛

每个 runtime/backend 阶段都必须满足：

- changed-surface focused tests
- heaptrc `0 unfreed memory blocks`
- shutdown 语义清晰可证
- keep-alive / malformed request / hijack ownership / pipelining contract 不回退

对 evented backend 还要额外证明：

- reactor 线程不会直接承担无界业务 handler
- worker handoff 语义可测试
- backend 差异不会改变 public HTTP contract
