# Progress Log: WebSocket reserved opcode rejection

## Session

- **Scope:** 补齐 WebSocket reserved opcode rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `reserved opcode rejection`

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

- `test_http_websocket` 新增 `ReservedOpcodeRejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 opcode validity guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket reserved opcode rejection contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `11 total, 10 passed, 1 failed`
  - failure: `reserved-opcode: got close response`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `11 total, 11 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket negative coverage：fragmented control frame 或 invalid close code；
  benchmark 仍后置，不跑全量。
