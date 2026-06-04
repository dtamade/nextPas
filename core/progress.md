# Progress Log: WebSocket non-canonical payload length rejection

## Session

- **Scope:** 补齐 WebSocket non-canonical payload length rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `payload length canonical encoding` -> `16-bit non-canonical rejection`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- `test_http_websocket` 新增 `NonCanonicalPayloadLengthRejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 16-bit non-canonical payload length guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket 16-bit non-canonical payload length rejection contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `18 total, 17 passed, 1 failed`
  - failure: `non-canonical-length: server sends close frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket payload length canonical coverage：64-bit non-canonical length 或 high-bit set rejection；benchmark 仍后置，不跑全量。
