# Progress Log: net.server kqueue backend wiring

## Session

- **Scope:** 把 `kqueue` 从“底层 wake seam 已就绪”推进到“backend 单元与 facade 注册都已落地”。
- **Status:** verified

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但位于 HTTP / async 范围内的脏文件仍有：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`

## Completed work

- 新增 [src/nextpas.core.net.server.kqueue.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.kqueue.pas:1)。
- [src/nextpas.core.net.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.pas:1)
  现在会在 BSD/macOS 条件下：
  - 引入 `nextpas.core.net.server.kqueue`
  - 注册 `tsbKqueue` builtin factory
- [test_net_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.net.server/test_net_server/test_net_server.lpr:1)
  新增了 `kqueue backend source contract` focused test，直接锁定：
  - `nextpas.core.net.server.kqueue` 文件存在
  - `kqueue` backend 复用 shared readiness owner
  - facade 有 `kqueue` 注册边界
  - Linux 上不会误注册 builtin `kqueue`
- [docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1)
  已同步真实阶段门：`kqueue` wiring 已落地，下一步主目标转为
  BSD/macOS live proof + H1 poll-driven widening。

## Verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `24/24 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 在真实 BSD/macOS 宿主补 `kqueue` compile/runtime proof
- 继续把 HTTP H1 session 往 poll-driven evented runtime 迁，减少“仅 accept evented”
  的剩余形态
