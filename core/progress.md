# Progress Log: platform.io kqueue wake seam

## Session

- **Scope:** 补齐 BSD/macOS `kqueue` poller wake seam，继续推进
  `nextpas.core.net.server` readiness-family foundation。
- **Status:** verified

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但位于 HTTP / async 范围内的脏文件仍有：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`

## Completed work

- [src/nextpas.core.platform.io.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.platform.io.base.pas:1)
  为 BSD/macOS poller 增加了 `WakeReadFd` / `WakeWriteFd`。
- [src/nextpas.core.platform.io.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.platform.io.pas:1)
  在 `kqueue` 分支落地了：
  - self-pipe wake source
  - nonblocking / close-on-exec fd 初始化
  - `platform_poller_close` 的 wake fd 释放
  - `platform_poller_enable_wake`
  - `platform_poller_wake`
  - `platform_poller_drain_wake`
- [test_platform_io.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.platform.io/test_platform_io/test_platform_io.lpr:1)
  新增了 `kqueue wake source contract` focused test，直接锁定 BSD/macOS
  wake seam 不再是 stub，并要求 helper/close path 真实存在。
- [docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1)
  已同步真实阶段门：host wake seam 已补齐，下一步主目标转为
  `net.server.kqueue` backend wiring + BSD/macOS live proof。

## Verification

- `make -C tests/nextpas.core.platform.io/test_platform_io clean test`
  - `9/9 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `23/23 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 让 `net.server.kqueue` 真正包装 `nextpas.core.net.server.readiness`
  并接上 backend factory / registration seam
- 在真实 BSD/macOS 宿主补 compile/runtime proof，而不是停留在 source-contract
