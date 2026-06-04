# Progress Log: WebSocket standalone continuation rejection

## Session

- **Scope:** 补齐 WebSocket standalone continuation rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `fragmented data-frame policy` -> `standalone continuation rejection`

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

- `test_http_websocket` 新增 `StandaloneContinuationFrameRejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 continuation state guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket standalone continuation rejection contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `16 total, 15 passed, 1 failed`
  - failure: `standalone-continuation: server sends close frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `16 total, 16 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket fragmented data-frame policy：interleaved data-frame rejection 或 valid fragmented sequence state proof；benchmark 仍后置，不跑全量。
