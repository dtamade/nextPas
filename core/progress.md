# Progress Log: http server unsupported expect early 417

## Session

- **Scope:** 给 `HttpServer` 补上 unsupported `Expect` 的 headers-stage early `417`。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `unsupported expect early final rejection`

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

- [src/nextpas.core.http.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.base.pas), [src/nextpas.core.http.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.pas)
  补上 `HTTP_STATUS_EXPECTATION_FAILED = 417` 与状态文本/门面转发。
- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  在 threaded / poll-driven H1 request parse 路径补上 unsupported `Expect`
   的 headers-stage early `417` short-circuit。
- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 focused live contract tests，直接锁定 unsupported
  `Expect` 不会误发 `100 Continue`。
- [tests/nextpas.core.http/test_http_base/test_http_base.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_base/test_http_base.lpr), [tests/nextpas.core.http/test_http_contract/test_http_contract.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_contract/test_http_contract.lpr)
  补上 `417 Expectation Failed` 的 base / facade focused proof。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 unsupported `Expect` early final `417` contract 说明。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `185/185 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_base test`
  - `14/14 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_contract test`
  - `29/29 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先继续补真正的 request-side protocol completeness，不要回到低价值 parity 平铺。
- 更合理的两个方向是：
  - 继续收紧 `Expect` 组合/优先级语义
  - 或审视 `3/6 H1 正确性加固` 的阶段收口条件，准备衔接更高层的 server/base 架构演进
