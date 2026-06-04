# Progress Log: http idle-timeout chunk-size-line characterization

## Session

- **Scope:** 给 request-side `IdleTimeout` 补上 `partial chunk-size-line stall` 的 focused + live proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-timeout truth tightening` -> `chunk-size-line idle-timeout characterization`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `src/nextpas.core.process.pipe.pas`
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 poll-driven focused proof：
  `H1 poll-driven session times out partial chunk-size line read wait`。
- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增 live-socket proof：
  - threaded：`Partial chunk-size line idle-timeout closes connection`
  - epoll：`Partial chunk-size line idle-timeout closes connection with epoll backend`
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 request-side `IdleTimeout` 对 chunk-size-line stall 的新证据。

## Verification

- `make -C tests/nextpas.core.http/test_http_server test`
  - `177/177 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_security test`
  - `117/117 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续保持窄批次，不要回到大而散的治理节奏。
- 更合理的两个方向是：
  - 找出还没被 live proof 覆盖的真正 runtime / malformed 边角
  - 或开始审视 `3/6 H1 正确性加固` 的阶段收口条件，避免继续低价值复制
