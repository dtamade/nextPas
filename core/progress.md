# Progress Log: http H1 poll-driven mid-request IdleTimeout proof

## Session

- **Scope:** 把 poll-driven request-side `IdleTimeout` focused proof 从
  “pre-first-byte idle wait” 扩到 mid-request stalls。
- **Status:** verified

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr:1)
  现在补了两条新的 request-side timeout focused proof：
  - partial fixed-length body stall
  - partial chunked trailer stall
- 同一批 focused tests 还直接锁定了一个更细的 current truth：
  - partial request progress 不会 re-arm read deadline
  - timeout close 后 `WakeDeadline` 会清回 infinite
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:1)
  已同步这条 request-side `IdleTimeout` mid-request proof，并把下一步路线图切回
  malformed raw-wire security 主线。

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `176/176 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 回到 malformed raw-wire chunked request security proof
- 优先找还没有被 server/security 两层一起锁死的异常 chunk framing / safe-close 分支
- 只有当 live socket 或 backend parity 再暴露 request-side timeout 真缺口时，
  才重新扩这条 synthetic timeout coverage
