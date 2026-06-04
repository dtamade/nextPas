# Progress Log: security request-target over max-header explicit 431

## Session

- **Scope:** 把 `test_http_security` 里 `request-target over MaxHeaderSize`
  从 broad safe-handling 收成 raw-wire explicit `431` proof，并补 threaded /
  Linux `epoll` 两条路径。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `malformed/runtime 邻接缺口` -> `request-target over MaxHeaderSize explicit 431`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增两条 focused proofs：
  - threaded `Request-target over MaxHeaderSize -> explicit 431`
  - epoll `Request-target over MaxHeaderSize -> explicit 431`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已把 `test_http_security` 从 long-request-line broad safe-handling 口径收紧成
  request-target over `MaxHeaderSize` 的 explicit `431` 口径。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明这是 current truth 收口，而不是修复。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `130/130 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 最自然的后续是继续补：
  - 仍停留在 broad safe-handling 的 request/header budget 邻接分支
  - 或其他仍未分类完的 malformed/runtime 小缺口
