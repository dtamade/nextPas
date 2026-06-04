# Progress Log: http epoll chunked-not-final security parity

## Session

- **Scope:** 给 `Transfer-Encoding: chunked, gzip` 补上 epoll backend live raw-wire `400` proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `malformed raw-wire security tightening` -> `epoll chunked-not-final parity`

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
  新增 focused/live proof：
  `Chunked must be final transfer coding -> 400 with epoll backend`。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 `chunked`-must-be-final transfer-coding 的 epoll live parity 说明。

## Verification

- `make -C tests/nextpas.core.http/test_http_security test`
  - `118/118 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续保持窄批次，不要回到大而散的治理节奏。
- 更合理的两个方向是：
  - 继续找还没被直接分类的真正 runtime / malformed 边角
  - 或开始审视 `3/6 H1 正确性加固` 的阶段收口条件，避免继续低价值复制
