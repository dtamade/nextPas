# Findings: net.server epoll reactor wakeup seam

## Scope

- 这轮不是直接改 H1 response writer / outbound queue。
- 这轮先把 `nextpas.core.net.server` 缺失的 reactor self-wakeup foundation 补齐，
  让 future H1 poll-driven session 真正能安全等待 worker completion，
  再回 reactor 线程继续推进协议状态机。

## Confirmed truths

### 1. 当前真正需要固定的不是新的 HTTP 接口，而是 runtime wakeup 基础能力

- H1 context bridge 上一批已经打通；本轮不需要再扩 HTTP contract。
- 真正阻塞 H1 poll-driven runtime 的，是：
  worker completion 现在没有可靠的 reactor wakeup / re-entry 路径。
- 因此本轮正确落点是 `platform.io` + `net.server.epoll`，
  不是再给 HTTP 层加一个临时 public seam。

### 2. `platform.io` 现在正式拥有 poller wake seam

- [src/nextpas.core.platform.io.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.platform.io.pas:1)
  现在新增：
  - `platform_poller_enable_wake`
  - `platform_poller_wake`
  - `platform_poller_drain_wake`
- Linux 实现选型固定为 `eventfd`，不走 self-pipe。
- 这条 seam 是 reusable foundation，不是 HTTP 特例。

### 3. `epoll` backend 现在会把 worker completion 拉回 reactor 线程

- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:1)
  现在引入：
  - per-connection session context wrapper
  - wrapped worker handoff
  - queued completion drain
  - wake-driven synthetic re-entry
- worker 线程执行 `ITcpServerWork.Execute`；
  `ITcpServerWorkCompletion.Complete` 不再直接在 worker 线程推进 poll-driven session。
- completion 会先排队，再唤醒 reactor，由 reactor 线程调用 completion 并继续推进 session。

### 4. poll-driven session 现在可以合法暂时没有 socket interest

- 之前 `epoll` runtime 会把 `ANextEvents = []` 当成错误。
- 现在这条约束已收紧成更准确的 foundation contract：
  当 session 在等待 worker completion 等 foundation-owned wake source 时，
  可以临时返回空 socket interest。
- backend 负责移除 fd 关注，并在 wake 后 synthetic re-entry。

### 5. H1 剩余阻塞点进一步收窄了

- H1 现在不再缺 context bridge，也不再缺 foundation wakeup。
- 下一步真正困难的只剩：
  - `TH1ResponseWriter` / `TChunkedWriter` / `TBufferedWriter.Flush`
    的 blocking write 语义
  - outbound queue / resumable drain state machine
  - `TH1ServerConnectionState` 真正实现 poll-driven connection driver

## Verification evidence

- `make -C tests/nextpas.core.platform.io/test_platform_io clean test`
  - `8/8 passed`
  - 新增 proof：
    - wake event 会唤醒 poller
    - wake userdata 会保留
    - `drain_wake` 后 readiness 会被清空
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `21/21 passed`
  - 新增 proof：
    - epoll poll-driven session 可提交 worker work
    - session 可在等待 worker completion 时返回空 socket interest
    - worker completion 会回 reactor 线程
    - reactor 会被 wake 并继续推进同一 session
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- `TH1ServerConnectionState` 还没有真正迁到 `ITcpServerPollDrivenSession`。
- `TH1ResponseWriter` / chunked writer / buffered flush 仍是假定 blocking socket。
- 这轮只先把 Linux `eventfd` 路径做实；`kqueue` / `IOCP` 还要各自接上等价 wake 机制。
