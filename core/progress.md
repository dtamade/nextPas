# Progress Log: http server fixed-length partial follow-up headers bridge

## Session

- **Scope:** 把 fixed-length keep-alive partial follow-up headers 从 half-close current truth 收成更具体的 bridge proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `fixed-length partial follow-up headers bridge`

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
  - threaded / epoll fixed-length partial follow-up headers can complete later
  - 两条路径都锁住首个请求先完成、follow-up headers 后续可补齐成合法第二请求
  - 首个 handler 仍只读到声明的 body `hello`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已把 `IHttpServer` 的 fixed-length partial follow-up headers 从 current truth 提升成 bridge proof。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `214/214 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 最自然的后续是继续补：
  - plain chunked partial follow-up headers bridge
  - trailer-complete chunked partial follow-up headers bridge
