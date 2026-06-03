# Findings: http h1 poll-driven phase2 step1

## Scope

- 这轮不再继续补碎片化 malformed case。
- 这轮直接推进 H1 poll-driven runtime：先把 request-side read/parse 拉回 reactor，
  再把 worker handoff 粒度从“整连接”收窄到“单 request”。

## Confirmed truths

### 1. 上一轮的 H1 poll-driven 实现确实还是 whole-connection bridge

- 新增 RED 前，context-aware H1 session 虽然已经暴露
  `ITcpServerPollDrivenSession`，
  但同连接里两个已完成请求仍会在第一次 handoff 里一起跑完。
- focused RED 明确抓到这一点：
  - 第一次 `Advance([peReadable])`
  - handler 已经被调用两次
  - 说明还是整连接一次 worker `Run`

### 2. 这轮已把 request-side ownership 真正拉回 reactor

- `TH1ServerConnectionState` 现在新增了 poll-path 自己的 request parse 状态：
  - `FStreamRuntime`
  - `FParseTotalRead`
  - `FParseHeadersDone`
  - `FPollWorkerPending`
- poll-driven 路径现在会：
  - 直接用 `ITcpStreamRuntime.TryRead` 读 socket
  - 直接驱动 `IH1Parser`
  - parser 完成一个 request 后只 handoff 这一个 request
  - worker completion 回到 reactor 后，如果 `FPending` 已经有 follow-up request，
    会立刻继续 parse / submit，不等下一次 readability

### 3. 当前 phase 2 还没完成，剩余缺口已经更清楚

- 这轮仍然保留 worker-owned blocking drain：
  - request handler 执行
  - `TH1ResponseWriter` flush
  - outbound buffer drain 到 socket
- `WakeDeadline` 仍然是 `Infinite`。
- 所以 H1 现在的真实状态是：
  - read/parse 已经 reactor-owned
  - write/drain / deadline 还不是

### 4. 兼容性关键点目前守住了

- 无 `ITcpStreamRuntime` 时仍保留旧的 whole-run fallback。
- worker 执行单 request 前仍会把 socket 设回 blocking，
  这样 hijack / WebSocket 这类 worker-owned 路径不被 nonblocking 语义打坏。
- request 完成且连接仍归 server 持有时，reactor 会把 socket 再设回 nonblocking，
  继续 keep-alive follow-up request。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `114/114 passed`
  - 新增 proof：
    - H1 poll-driven session hands off per completed request
  - threaded / epoll 既有 contract 未回归：
    - keep-alive / pipelining
    - malformed ingress / trailer / size-limit rejection
    - committed response / hijack / write-timeout / backpressure safety
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 当前 request-side per-request handoff 已经落地，但 outbound drain 还没有进入 reactor；
  这意味着性能形态还不是目标终态。
- `WakeDeadline` 还没有接进 H1 生产路径，`IdleTimeout` / `WriteTimeout` 在 poll-driven phase 2 下仍不是最终设计。
- 下一批最值得做的是：
  - 把 `IH1OutboundBuffer.TryDrainTo` 接进 poll-driven H1
  - 让 `peWritable` / would-block / write deadline 真正进入状态机
  - 再决定 bounded outbound queue 与 backpressure contract
