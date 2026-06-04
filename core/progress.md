# Progress Log: net.server readiness runtime owner extraction

## Session

- **Scope:** 新增 shared readiness runtime owner，并让 Linux `epoll` backend
  退成薄包装；目标是继续把 future `kqueue` 需要复用的骨架从 Linux 专属单元里抽出。
- **Status:** committed

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但位于 HTTP 范围内的脏文件仍有：
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`

## Completed work

- 新增 [src/nextpas.core.net.server.readiness.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.readiness.pas:1)。
- readiness owner 现在统一承载：
  - listener readiness / accept loop
  - poll-driven session 注册
  - worker completion queue + reactor re-entry
  - deadline wake / timeout poll 计算
  - shutdown wake / self-connect fallback
- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:1)
  现在退成 Linux backend 命名入口，直接包装 readiness owner。
- [test_net_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.net.server/test_net_server/test_net_server.lpr:1)
  新增了 direct readiness owner proof：worker completion 后会唤醒 reactor 并继续推进 poll-driven session。
- [docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1)
  已同步真实 owner 边界。

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `23/23 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `173/173 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- readiness-family 下一刀最自然的是补 BSD/macOS `platform_poller` 的 wake seam：
  - `platform_poller_enable_wake`
  - `platform_poller_wake`
  - `platform_poller_drain_wake`
- 这块补上后，就可以把 `net.server.kqueue` 落成对 readiness owner 的真正注册/包装，
  而不是再复制一份 backend 主循环。
