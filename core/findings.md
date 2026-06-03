# Findings: nextpas.core.http H1 session context bridge

## Scope

- 这轮不是直接完成 H1 poll-driven session。
- 这轮先补上 `nextpas.core.http.server` bridge 丢失的 foundation context，
  让 H1 transport/session 真正能拿到 `ITcpServerSessionContext` /
  `ITcpServerWorkerHandoff`。

## Confirmed truths

### 1. 之前真正的缺口在 HTTP bridge，不在 TCP runtime

- `nextpas.core.net.server.runtime` 已经会优先调用
  `ITcpServerSessionFactoryWithContext`。
- `threaded` / `epoll` backend 也都已经把 `FSessionContext` 传到了 runtime。
- 但 [src/nextpas.core.http.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.server.pas:1)
  之前只让 `THttpConnHandler` 实现了 legacy `ITcpServerSessionFactory`，
  所以 foundation context 在 HTTP 边界被丢掉了。

### 2. HTTP 现在已经有 context-aware session factory seam

- [src/nextpas.core.http.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.intf.pas:1)
  现在新增：
  - `ITcpServerSessionContext` alias
  - `IHttpServerSessionFactoryWithContext`
- [src/nextpas.core.http.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.pas:1)
  也已 re-export 这两个 seam，contract test 可直接消费。

### 3. `http.server` bridge 现在会优先转发 context-aware session factory

- `THttpConnHandler` 现在同时实现：
  - `ITcpServerSessionFactory`
  - `ITcpServerSessionFactoryWithContext`
- 当 transport 支持 `IHttpServerSessionFactoryWithContext` 时：
  - HTTP bridge 会优先调用这条路径
  - 传入的 `AContext.WorkerHandoff` 也会原样保留下去
- legacy `IHttpServerSessionFactory` 与 `ServeConn` fallback 仍保留。

### 4. H1 transport / session 现在已经能接住 foundation context

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:1)
  现在让 `TH1ServerTransport` 同时实现：
  - `IHttpServerSessionFactory`
  - `IHttpServerSessionFactoryWithContext`
- `TH1ServerConnectionState` 现在新增 `FSessionContext`，
  构造时可以保存来自 foundation 的 session context。

### 5. 当前最大的剩余阻塞点已经更清楚了

- H1 session 现在虽然能拿到 `WorkerHandoff`，但还**没有消费它**。
- 下一步真正困难的不再是“context 怎么传到 H1”，而是：
  - response writer 仍然是 blocking write 语义
  - chunked writer 仍然要求一次调用内写完整个 frame
  - `TBufferedWriter.Flush` 仍然等同于同步写完 socket
  - poll-driven + worker completion 还缺 reactor wakeup / outbound drain 机制

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - 新增 proof：
    - injected server transport 的 context-aware session factory 优先于 legacy path
    - context-aware path 能看到 `WorkerHandoff`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - 新增 proof：
    - `NewH1ServerTransport(...)` 暴露 `IHttpServerSessionFactoryWithContext`
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- `TH1ServerConnectionState` 还没有实现 `ITcpServerPollDrivenSession`。
- `WorkerHandoff` 现在只是“能到 H1”，还不是“已经在 poll-driven path 正确消费”。
- response writer / outbound queue / wakeup path 仍是下一批真正的 correctness 难点。
