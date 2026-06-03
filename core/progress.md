# Progress Log: net.server readiness driver extraction step2

## Session

- **Scope:** 把 `epoll` 私有的 queued completion / poll worker handoff /
  poll session context wrapper 收回 `nextpas.core.net.server.runtime`，
  继续把 readiness-family glue 从 backend 私有实现里抽离。
- **Status:** in verification

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 上一轮已经把 poll-session target 收口到 foundation；
  这轮之前 `epoll` 里还残留 bridge/context glue。

## Completed work

- 在 `src/nextpas.core.net.server.runtime.pas` 新增：
  - `TTcpServerPollQueuedCompletion`
  - `TTcpServerPollWorkerHandoff`
  - `TTcpServerPollSessionContext`
- 在 `src/nextpas.core.net.server.epoll.pas` 删除私有：
  - `TTcpEpollQueuedCompletion`
  - `TTcpEpollWorkerHandoff`
  - `TTcpEpollSessionContext`
- `epoll` 现在改为消费 foundation bridge/context helper。
- 在 [docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md)
  同步了 readiness-family helper 的真实边界。

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- readiness-family 下一步合理顺序是继续抽：
  - pending completion queue storage/driver helper
  - poll target registry helper
- 抽完这两层后，再进 `net.server.kqueue` 会更顺，不会复制 `epoll` glue。
