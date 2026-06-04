# Progress Log: http server request-target over MaxHeaderSize contract

## Session

- **Scope:** 把 long-request-line 的 broad safe-handling 收成更具体的 server-layer `MaxHeaderSize` 契约：oversized request-target 直接 `431`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-line/header budget enforcement` -> `request-target over MaxHeaderSize`

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
  - threaded / epoll request-target over `MaxHeaderSize`
  - 两条路径都直接返回 `431`
  - handler 不会被调用
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 request-target over `MaxHeaderSize` current truth。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `212/212 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 更合理的方向是继续把其余 runtime / malformed current truth 收成更窄、更可依赖的 server contract。
