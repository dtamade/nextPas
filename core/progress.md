# Progress Log: WebSocket outgoing text UTF-8 validation

## Session

- **Scope:** 补齐 WebSocket outgoing `WriteText` UTF-8 validation。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket public API safety`
  -> `outgoing text payload semantic validation`

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

- `test_http_websocket` 新增 `OutgoingTextInvalidUtf8Rejected` focused proof。
- `nextpas.core.http.websocket` 现在在 `WriteText` 写出前复用 text payload validation。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录新公开契约。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `28 total, 27 passed, 1 failed`
  - failure:
    - `outgoing-text-invalid-utf8: fail-fast reason: expected "WebSocket: invalid text payload encoding", got "�"`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `28 total, 28 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- WebSocket negative surface 已基本收口到真实 RED；下一刀建议转向 HttpServer examples/docs 或 remaining server runtime gaps。
- 若继续 WebSocket，应先证明真实 RED，避免 `Pong` oversize 这类同路径 parity 覆盖。
