# Progress Log: http server expect-continue contract

## Session

- **Scope:** 给 `HttpServer` 补上 `Expect: 100-continue` request-side protocol contract。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side protocol completeness` -> `expect-continue contract`

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

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  在 threaded / poll-driven H1 request parse 路径补上 interim `100 Continue` 发送。
- [src/nextpas.core.http.impl.h1.parser.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.parser.pas)
  增加真实 `HeadersComplete` parser signal，修掉首版实现引入的 partial-follow-up 回归。
- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 focused live contract tests。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `Expect: 100-continue` contract 说明。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `181/181 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先继续补真正的 request-side protocol completeness，不要再回到低价值 parity 平铺。
- 更合理的两个方向是：
  - unsupported `Expect` / 更早的 declared oversize body rejection
  - 或审视 `3/6 H1 正确性加固` 的阶段收口条件，准备衔接更高层的 server/base 架构演进
