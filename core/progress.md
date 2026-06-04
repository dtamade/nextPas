# Progress Log: header field over max-header explicit 431

## Session

- **Scope:** 把普通 header field over `MaxHeaderSize` 从 broad safe-handling
  收成 explicit `431` proof，并补 server/security 两层 threaded / Linux
  `epoll` 证据。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `malformed/runtime 邻接缺口` -> `header field over MaxHeaderSize explicit 431`

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

- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增两条 focused proofs：
  - threaded `Header field over MaxHeaderSize -> explicit 431`
  - epoll `Header field over MaxHeaderSize -> explicit 431`
  - 两条都锁住 handler 不进入
- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增两条 focused proofs：
  - threaded `Header field over MaxHeaderSize -> explicit 431`
  - epoll `Header field over MaxHeaderSize -> explicit 431`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已把普通 header field over `MaxHeaderSize` 口径补进 explicit `431`
  contract，并记录 server/security 双层证据。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明这是 current truth 收口，而不是修复。

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `219/219 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `132/132 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 最自然的后续是继续补：
  - oversize trailer `431 or safe-close` 是否也能收紧成 explicit `431`
  - 或其他仍未分类完的 malformed/runtime 小缺口
