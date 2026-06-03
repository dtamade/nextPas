# Findings: http h1 poll-driven phase2 step3

## Scope

- 这轮继续停留在 H1 poll-driven phase 2 主线，不回去补碎片化 malformed case。
- 目标是把 `WriteTimeout` / `WakeDeadline` 真正接进 poll-driven response drain。

## Confirmed truths

### 1. 上一轮只收了 `WriteTimeout = 0` 的 response drain，timed drain 仍留在旧路径

- 新增 RED 继续用 runtime-only stream 直接卡死同步 `Write` 路径：
  - request handler 仍然会被 handoff 执行
  - 但 `WriteTimeout > 0` 时第一次请求完成后，worker 内仍会发生 `SyncWriteCalls = 1`
  - 说明 timed drain 还没真正进 poll state machine

### 2. 现在所有 poll-path response drain 都已经进入 reactor-owned state

- `TH1ServerConnectionState` 现在新增 poll response state：
  - `FPollOutbound`
  - `FPollResponsePending`
- `FPollWriteDeadline`
- poll-driven 路径现在会：
  - worker 只负责把 response 生产到 `IH1OutboundBuffer`
  - completion wake 回到 reactor 后先尝试一次 `TryDrainTo`
  - 若 `would-block`，则注册 `peWritable`
  - writable wake 到来后继续 drain
  - `WriteTimeout > 0` 时会暴露有限 `WakeDeadline`
  - deadline 到期时会安全结束 session，不做额外写重试
  - drain 完成后，若 keep-alive 且 `FPending` 已有 follow-up request，会继续 parse / submit，不等新的 readability

### 3. epoll deadline wake 的真实触发模型已经被锁进 H1

- foundation 的 deadline wake 是 `Advance([], ...)`，不是带 `peWritable` 的 readiness。
- 这轮 H1 timed-drain RED/GREEN 直接按这个真实模型建立，
  避免把 timeout 收口写成错误的事件驱动假设。

### 4. 现有兼容性和既有回归都守住了

- per-request handoff proof 仍保持成立。
- writable-drain proof 仍保持成立。
- `epoll` backend 现有 stalled-peer / write-timeout regression 没回归。
- 无 `ITcpStreamRuntime` 时仍保留旧的 whole-run fallback。
- worker 执行 request 前仍会把 socket 设回 blocking，
  这样 hijack / WebSocket 路径不被破坏。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `116/116 passed`
  - 新增 proof：
    - H1 poll-driven session times out stalled drain on deadline wake
  - threaded / epoll 既有 contract 未回归：
    - keep-alive / pipelining
    - malformed ingress / trailer / size-limit rejection
    - committed response / hijack / write-timeout / backpressure safety
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- timed drain 已经进了 poll-driven state machine，
  但还没有做 bounded outbound queue / multi-response fairness。
- 当前 close semantics 仍然偏 correctness-first，性能和队列策略还没进入最终优化阶段。
- 下一批最值得做的是：
  - 设计 bounded outbound queue / multi-response ordering contract
  - 细化 stalled-peer timing / close-observation characterization
  - 再进入 benchmark / Go-Rust 对标
