# Progress Log: net.server poll-driven deadline wake seam

## Session

- **Scope:** 给 `nextpas.core.net.server` 的 poll-driven foundation 补上
  deadline wake 能力，作为 future H1 poll-driven runtime 的前置基础，
  但本轮不直接迁 H1 state machine。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- foundation 现在已经不只有 socket readiness / worker completion 两类 wake source；
  poll-driven session 也可以通过 deadline 被 reactor 主动重入。
- HTTP 当前运行真相仍以 worker-driven H1 session 为主，
  但 future timeout-correct poll-driven H1 的基础缺口已进一步缩小。

## Completed work

- 审阅并确认当前缺口：
  - wakeup foundation 已有，但 timer wake 还没有
  - 直接硬迁 H1 poll-driven 会丢 `IdleTimeout/WriteTimeout` 正确性
  - 这批先做 foundation，不先做半成品 H1 poll-driven
- 先承接 RED：
  - `test_net_server` 先锁缺少 deadline seam
  - 先红在 `ITcpServerPollDrivenSessionWithDeadline`
- 在 `src/nextpas.core.net.server.intf.pas` /
  `src/nextpas.core.net.server.pas` 落地：
  - `ITcpServerPollDrivenSessionWithDeadline`
- 在 `src/nextpas.core.net.server.epoll.pas` 落地：
  - poll target deadline tracking
  - nearest-deadline wait timeout
  - expired-deadline synthetic re-entry
  - initial no-socket-interest + finite deadline 注册语义
- 在 focused tests 落地：
  - `tests/nextpas.core.net.server/test_net_server`
    - epoll deadline wake proof
- 在文档落地：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 直接进入 H1 poll-driven runtime 的下一块硬骨头：
  - 让 `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`
  - 把 `WorkerHandoff`、`IH1OutboundBuffer.TryDrainTo`、`WakeDeadline` 接进同一状态机
  - 再决定 bounded outbound queue 的高水位策略
