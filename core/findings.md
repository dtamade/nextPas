# Findings: http h1 poll-driven phase2 step2

## Scope

- 这轮继续停留在 H1 poll-driven phase 2 主线，不回去补碎片化 malformed case。
- 目标是把 successful response drain 从 worker 内同步 socket write，
  收窄到 reactor-owned nonblocking drain。

## Confirmed truths

### 1. 上一轮的 poll path 仍然把 successful response drain 留在 worker 内同步 `Write`

- 新增 RED 用 runtime-only stream 直接卡死同步 `Write` 路径：
  - request handler 仍然会被 handoff 执行
  - 但第一次请求完成后，worker 内已经发生了 `SyncWriteCalls = 1`
  - 说明 poll path 还没有把 successful response 保留到 reactor drain

### 2. `WriteTimeout = 0` 的 poll path 现在已经能 produce-then-drain

- `TH1ServerConnectionState` 现在新增 poll response state：
  - `FPollOutbound`
  - `FPollResponsePending`
- poll-driven 路径现在会：
  - worker 只负责把 response 生产到 `IH1OutboundBuffer`
  - completion wake 回到 reactor 后先尝试一次 `TryDrainTo`
  - 若 `would-block`，则注册 `peWritable`
  - writable wake 到来后继续 drain
  - drain 完成后，若 keep-alive 且 `FPending` 已有 follow-up request，
    会继续 parse / submit，不等新的 readability

### 3. 为了不把 deadline 语义做成半成品，这轮只切了 `WriteTimeout = 0` 的 drain

- `WriteTimeout > 0` 的 poll path 目前仍保留旧的 worker-owned blocking drain。
- 这样现有 real-socket stalled-peer / backpressure / safe-close proof 不会被这轮半途打坏。
- 所以 H1 现在的真实状态是：
  - read/parse 已经 reactor-owned
  - `WriteTimeout = 0` 的 successful response drain 也已经 reactor-owned
  - timed drain / `WakeDeadline` 还没有

### 4. 现有兼容性和既有快路径都守住了

- per-request handoff proof 仍保持成立。
- `epoll` backend 现有 stalled-peer / write-timeout regression 没回归。
- 无 `ITcpStreamRuntime` 时仍保留旧的 whole-run fallback。
- worker 执行 request 前仍会把 socket 设回 blocking，
  这样 hijack / WebSocket / timed drain 老路径不被破坏。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `115/115 passed`
  - 新增 proof：
    - H1 poll-driven session drains response via writable events
  - threaded / epoll 既有 contract 未回归：
    - keep-alive / pipelining
    - malformed ingress / trailer / size-limit rejection
    - committed response / hijack / write-timeout / backpressure safety
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 当前 successful response drain 只在 `WriteTimeout = 0` 时进入 reactor；
  timed drain 仍不是最终形态。
- `WakeDeadline` 还没有接进 H1 生产路径，
  `WriteTimeout` 在 poll-driven phase 2 下仍不是最终设计。
- 下一批最值得做的是：
  - 把 `WakeDeadline` / `WriteTimeout` 接进 poll-driven drain
  - 决定 deadline 到期时的 safe-close / no-follow-up-consume 语义
  - 再决定 bounded outbound queue / multi-response ordering contract
