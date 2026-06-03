# Task Plan: http h1 initial poll-driven bridge

## Goal

把 `nextpas.core.http` 的 H1 server runtime 再往前推进一格：

- 让 `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`
- 先把 H1 接到 poll-driven foundation / `WorkerHandoff` 这条主干上
- 在不破坏现有 HTTP contract 的前提下，为后续 reactor-owned H1 state machine 铺桥
- 用 focused HTTP suite 锁住这条 bridge 语义

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅 `docs/design-conventions.md`、`docs/http/ARCHITECTURE.md`、
  `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`
- [x] 先补 RED：
  - `test_http_server` 锁 context-aware H1 session 现在必须暴露 `ITcpServerPollDrivenSession`
- [x] GREEN：
  - `TH1ServerConnectionState` 实现 `ITcpServerPollDrivenSession`
  - bridge 先在首次 readability 后通过 `WorkerHandoff` 提交整连接 `Run`
  - epoll backend 现在会优先走 H1 poll-driven session seam，而不是只停留在 blocking session factory
- [x] 跑 focused `test_http_server` 验证与 heaptrc

## Scope

- 这轮只做 H1 initial poll-driven bridge。
- 不直接把 request parse / response drain 细化成 reactor-owned state machine。
- 不改 `nextpas.core.http` public API。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- H1 现在已经不是“只有 `Run`、完全不懂 poll-driven foundation”的状态
- epoll runtime 能通过 session seam 驱动 H1，并把整连接执行安全挂到 worker
- 当前剩余主线进一步收窄为：
  - 把 `Run` bridge 拆成真正的 reactor-owned H1 read/write state machine
  - 把 `IH1OutboundBuffer.TryDrainTo` 与 `WakeDeadline` 接进生产路径
  - bounded outbound queue / backpressure 策略
