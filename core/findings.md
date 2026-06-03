# Findings: nextpas.core.net/http server runtime foundation

## Scope

- 当前目标是固定 `nextpas.core.net.server` 的长期 runtime 方向，并校准
  `nextpas.core.http` 对这层 foundation 的依赖真相。
- 本轮只看 `nextpas.core.net.server*`、`nextpas.core.http*`、相关 tests 与文档，
  不扩到全仓规范审计。

## Baseline truths

- 当前共享工作树是脏的，存在大量与本轮无关的 modified / untracked 文件；只能做
  path-limited 变更与提交。
- 当前相关未提交代码并不是“纯规划”，而是已经包含：
  - foundation runtime helper 抽取：`src/nextpas.core.net.server.runtime.pas`
  - Linux `epoll` phase-1 backend：`src/nextpas.core.net.server.epoll.pas`
  - threaded backend 复用 runtime helper
  - `test_net_server` / `test_http_server` 的 `epoll` focused proof

## Confirmed decisions

### 1. 公共 server 编程模型保持同步、Go 风格

- `IHttpServer` / `IHttpHandler` / `IHttpRequest` / `IHttpResponseWriter` 不改成 callback-first
  或 event-loop-first public surface。
- runtime/backend 演进发生在 `nextpas.core.net.server` foundation 内部，而不是把复杂度抬到
  HTTP facade。

### 2. runtime foundation 应放在 `nextpas.core.net.server`，不是大继承 `TBaseServer`

- 可复用的共享问题是 listener / accept / backend selection / shutdown / ownership /
  worker handoff。
- 这些职责天然属于 foundation module；如果做成深继承 `TBaseServer`，后续 `epoll` /
  `kqueue` / `IOCP` 与协议特有语义会互相污染。

### 3. 当前 Linux `epoll` 只落到 phase 1，不应被误判成完整版 evented runtime

- 当前 `epoll` backend 已经是真实可运行 backend，不再只是规划。
- 但它的语义仍然是：
  - `epoll` 驱动 listener readiness 与 `TryAccept`
  - accepted connection 交给 foundation worker 执行同步 session / handler
- 也就是说，它是“evented accept + threaded connection execution”，还不是
  “runtime 直接驱动单连接协议状态对象”的最终形态。

### 4. 下一阶段不是再争论选型，而是把 `TryRead/TryWrite` 接进 per-connection driver

- `ITcpListenerRuntime.TryAccept`、`ITcpStreamRuntime.TryRead/TryWrite` 已经在 foundation
  seam 中。
- session/context/handoff seam 也已经存在并被 threaded/epoll 共同复用。
- 真正的下一道架构门，是把这组 seam 用到 connection-state-driven runtime，再扩
  `kqueue` / `IOCP`。

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `15 total, 15 passed, 0 failed`
  - 包含 `Epoll server echo`、`shutdown without clients`、`prefers context session factory`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `88 total, 88 passed, 0 failed`
  - 包含 `Simple GET 200 with epoll backend`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- Linux `epoll` 当前只证明了 phase-1 foundation parity；还没有把 keep-alive / pipelining /
  hijack / backpressure 做成独立的 backend-differential matrix。
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- 当前还没有 benchmark 结论，性能判断必须后置到 correctness 和 backend contract 进一步稳定之后。

## Commit intent

- 这批改动应该和 `nextpas.core.net.server` foundation 收口一起提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
