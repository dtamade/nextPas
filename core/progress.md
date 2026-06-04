# Progress Log: WebSocket invalid UTF-8 text-frame rejection

## Session

- **Scope:** 补齐 WebSocket invalid UTF-8 text-frame rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `invalid UTF-8 text-frame rejection`

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

- `test_http_websocket` 新增 `InvalidUtf8TextFrameRejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 text payload UTF-8 guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket invalid UTF-8 text-frame rejection contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `14 total, 13 passed, 1 failed`
  - failure: `invalid-utf8-text: server sends close frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `14 total, 14 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket negative coverage：close-reason UTF-8 或 fragmented data-frame policy；benchmark 仍后置，不跑全量。
