# Progress Log: WebSocket outgoing control-frame payload limits

## Session

- **Scope:** 补齐 WebSocket outgoing `Ping` / `Close` control-frame payload limit。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket public API safety`
  -> `outgoing control-frame payload limits`

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

- `test_http_websocket` 新增 `OutgoingPingPayloadTooLargeRejected` focused proof。
- `test_http_websocket` 新增 `OutgoingClosePayloadTooLargeRejected` focused proof。
- `nextpas.core.http.websocket` 新增 write-side control payload guard。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录新公开契约。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `25 total, 23 passed, 2 failed`
  - failures:
    - `outgoing-ping-oversize: server sends close frame`
    - `outgoing-close-oversize: server sends text frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `25 total, 25 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀建议优先复查 WebSocket 是否还存在真实 RED 的 public API gap；候选是 `Pong(126 bytes)`
  parity 或 invalid fragmented final UTF-8。如果都只是同路径 PASS，应转回 HttpServer examples/docs
  或 H1/server remaining public gaps。
