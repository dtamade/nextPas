# Progress Log: net.server readiness driver extraction step1

## Session

- **Scope:** 把 `epoll` 私有的 poll-driven session target/helper 收回
  `nextpas.core.net.server.runtime`，让 readiness-family foundation 真正开始服务
  future `kqueue` 复用。
- **Status:** in verification

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 这轮之前，`epoll` 已经是唯一真正消费 poll-driven session seam 的 backend，
  但 target/helper 仍滞留在 `epoll` 私有实现里。

## Completed work

- 在 `src/nextpas.core.net.server.runtime.pas` 新增：
  - `TTcpServerPollSessionTarget`
  - `TryCreateTcpServerPollSessionTarget`
- 在 `src/nextpas.core.net.server.epoll.pas` 删除私有
  `TTcpEpollPollSessionTarget`，改为消费 foundation helper。
- 在 [docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md)
  同步了 runtime helper 的真实边界。

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `22/22 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- readiness-family 下一步合理顺序是继续抽：
  - completion queue / wake wrapper
  - poll-driven session context wrapper
- 这样 future `kqueue` backend 才不会复制 `epoll` 的 completion/wake glue。
