# Progress Log: WebSocket fragmented UTF-8 text sequence acceptance

## Session

- **Scope:** 补齐 WebSocket fragmented UTF-8 text sequence acceptance。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `fragmented data-frame policy` -> `valid fragmented UTF-8 text sequence`

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

- `test_http_websocket` 新增 `FragmentedTextUtf8SequenceAccepted` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 fragmented text 累计 UTF-8 校验。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket valid fragmented UTF-8 text sequence contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `17 total, 16 passed, 1 failed`
  - failure: `fragmented-utf8: server sends text frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `17 total, 17 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket fragmented data-frame policy：invalid fragmented final UTF-8 或 interleaved data-frame rejection；benchmark 仍后置，不跑全量。
