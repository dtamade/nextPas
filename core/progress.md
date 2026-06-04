# Progress Log: WebSocket unmasked client-frame rejection

## Session

- **Scope:** 补齐 WebSocket unmasked client frame rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `client mask-required contract`

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

- `test_http_websocket` 新增 `BuildUnmaskedFrame` helper。
- `test_http_websocket` 新增 `UnmaskedClientFrameRejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 client frame MASK bit guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket negative frame mask contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `9 total, 8 passed, 1 failed`
  - failure: `unmasked: server sends close frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket negative coverage：control-frame payload > 125 或 reserved opcode；
  仍保持一刀一个 contract，不跑全量。
