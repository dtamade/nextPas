# nextpas.core.net server runtime 架构

最近更新：2026-06-03

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

## 当前源码真相

截至 2026-06-03，相关源码边界已经收口到下面这个形态：

- [src/nextpas.core.net.server.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.base.pas:1)
  已固定 backend 枚举：`tsbThreaded`、`tsbEpoll`、`tsbKqueue`、`tsbIocp`。
- [src/nextpas.core.net.server.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.intf.pas:1)
  已固定 foundation contract：`ITcpServer` / `ITcpServerHandler`。
- [src/nextpas.core.net.server.threaded.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.threaded.pas:1)
  是当前唯一已落地 backend，负责 listen / accept / shutdown / detach ownership。
- [src/nextpas.core.http.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.server.pas:1)
  现在只是 HTTP facade，真实 runtime ownership 已下沉到 `ITcpServer`。
- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:104)
  已有 `TH1ServerConnectionState`，说明 HTTP 单连接协议状态与 runtime entrypoint 已开始分离。

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
- `nextpas.core.http.server` 这类上层 facade 只能做编排，不再重复实现 accept loop。
- 上层模块可以保留同步 handler surface；evented backend 必须在内部做 worker handoff，不能把任意 handler 直接跑在 reactor 线程。

## 模块形态

目标结构固定为：

```text
nextpas.core.net.server.base
nextpas.core.net.server.intf
nextpas.core.net.server.threaded
nextpas.core.net.server.epoll
nextpas.core.net.server.kqueue
nextpas.core.net.server.iocp
```

这里不走深继承 `BaseServer` 大类路线。
`nextPas` 更适合窄接口 + 可替换 backend 单元，而不是一个不断膨胀的基类层次。

## backend 语义规则

### threaded

- 允许单连接 worker inline 执行 handler。
- 当前 correctness 基线由它提供。

### evented

- runtime 驱动协议 state object。
- 不能在 reactor 线程直接执行无界 handler 逻辑。
- 必须有明确 worker handoff 或 bounded execution 策略。

### Windows

- 长期目标是 `IOCP`。
- 不能把 `WSAPoll` 作为最终设计终点。

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

### Phase 3

- 增加 `net.server.epoll`
- 证明同一 HTTP contract 可由 evented backend 驱动

### Phase 4

- 增加 `net.server.kqueue`

### Phase 5

- 增加 `net.server.iocp`

### Phase 6

- 再进入 buffer pool、streaming body、spill / spool、write coalescing、
  `io_uring` 评估、基准对照这些性能阶段

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
