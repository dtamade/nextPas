# Progress Log: http server expect-417 error-path coverage

## Session

- **Scope:** 给 `HttpServer` 补齐 `417 Expectation Failed` 在 generic error-path 上的 focused proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `expect-417 error-path coverage`

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
  新增一组 `417` focused proofs，覆盖：
  - poll-driven queued follow-up wire order
  - poll-driven standalone writable-drain
  - poll-driven standalone partial-timeout preserve-status
  - threaded direct error write-timeout / partial-timeout
  - threaded / epoll real-socket queued follow-up wire order
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `417` generic error-path coverage 说明。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `192/192 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先继续补真正的 request-side protocol completeness，不要回到低价值 parity 平铺。
- 更合理的两个方向是：
  - 继续收紧 `Expect` 组合/优先级语义
  - 或审视 `3/6 H1 正确性加固` 的阶段收口条件，准备衔接更高层的 server/base 架构演进
