# Progress Log: net.server epoll reactor wakeup seam

## Session

- **Scope:** 给 `nextpas.core.net.server` 的 poll-driven foundation 补上
  worker-completion -> reactor wakeup 基础能力，为 H1 poll-driven runtime 铺路，
  但不在本轮直接改 H1 response writer。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- `platform.io` 现在已经有 Linux `eventfd` wake seam。
- `net.server.epoll` 现在已经能把 worker completion 送回 reactor，再继续推进 poll-driven session。
- H1 poll-driven runtime 仍未落地，但当前缺口已经从“context/wakeup 基础设施”收窄到
  “outbound drain / writer would-block 语义”。

## Completed work

- 审阅并确认当前缺口：
  - foundation context bridge 上一批已打通
  - 当前缺的是 reactor self-wakeup 与 completion 回 reactor
  - 这批不需要扩 HTTP public API
- 先写 RED：
  - `test_platform_io`：wake/drain readiness
  - `test_net_server`：worker completion 唤醒 reactor 并重入 poll-driven session
- 在 `src/nextpas.core.platform.io.base.pas` /
  `src/nextpas.core.platform.io.pas` 落地：
  - Linux `WakeFd`
  - `platform_poller_enable_wake / wake / drain_wake`
- 在 `src/nextpas.core.net.server.epoll.pas` 落地：
  - per-connection `TTcpEpollSessionContext`
  - wrapped `TTcpEpollWorkerHandoff`
  - queued completion + reactor drain
  - empty socket interest 等待语义
  - shutdown 优先走 poller wake，self-connect 仅保留 fallback
- 在 focused tests 落地：
  - `tests/nextpas.core.platform.io/test_platform_io`
  - `tests/nextpas.core.net.server/test_net_server`
- 在架构文档落地：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`

## Verification

- `make -C tests/nextpas.core.platform.io/test_platform_io clean test`
  - `8/8 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `21/21 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 直接进入 H1 poll-driven runtime 的剩余硬骨头：
  - response writer 改成 outbound queue / resumable drain model
  - chunked writer / buffered writer 引入 would-block 友好语义
  - `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`
