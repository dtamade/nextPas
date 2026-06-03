# Progress Log: nextpas.core.net.server backend provider seam

## Session

- **Scope:** 把 `nextpas.core.net.server` 的 backend 解析升级为 provider seam，
  但不重开 HTTP public contract，也不直接进入 phase-2 evented driver。
- **Status:** completed

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- provider seam 已经落地到 `src/nextpas.core.net.server.pas`。
- builtin backend 已改为初始化注册：
  - `threaded`
  - Linux `epoll`
- 当前没有改 `nextpas.core.http.impl.h1`。

## Completed work

- 审阅并确认现有测试入口：
  - `tests/nextpas.core.net.server/test_net_server`
  - `tests/nextpas.core.http/test_http_registry`
- 先写 RED：
  - threaded factory 已注册
  - custom backend factory 可覆盖解析
  - missing backend factory 仍抛 `ENotSupportedError`
- 在 `src/nextpas.core.net.server.pas` 落地：
  - `TTcpServerFactory`
  - `RegisterTcpServerFactory`
  - `UnregisterTcpServerFactory`
  - `HasTcpServerFactory`
  - `TryGetTcpServerFactory`
  - `ResolveTcpServer`
- 把 `NewTcpServer(...)` 改成走 registry/provider seam。
- 把 builtin `threaded` / Linux `epoll` 改成 initialization 注册。
- 在 `test_net_server` 新增 focused proof。
- 跑 `test_http_registry`，确认 HTTP 构造路径未被误伤。
- 同步更新：
  - `docs/net/ARCHITECTURE.md`
  - `docs/net/README.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `18/18 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_registry clean test`
  - `4/4 passed`
  - heaptrc：`0 unfreed memory blocks`
- `git diff --check -- src/nextpas.core.net.server.pas tests/nextpas.core.net.server/test_net_server/test_net_server.lpr`
  - clean

## Next step

- 做 path-limited commit。
- 下一批如果继续 runtime 主线，应直接进入 shared phase-2 per-connection evented driver 设计/落地，
  而不是继续在 backend 选择层重复打转。
