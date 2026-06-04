# Progress Log: WebSocket high-bit 64-bit payload length rejection

## Session

- **Scope:** 补齐 WebSocket 64-bit payload length high-bit rejection。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket negative frame coverage`
  -> `extended payload length validation`

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

- `test_http_websocket` 新增 `HighBitPayloadLength64Rejected` focused proof。
- `nextpas.core.http.websocket.ReadFrame` 增加 64-bit extended length high-bit guard。
- `docs/http/API_COVERAGE.md` 已记录 WebSocket high-bit payload length rejection contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `21 total, 20 passed, 1 failed`
  - failure: `high-bit-length64: fail-fast reason`
  - expected: `WebSocket: invalid 64-bit payload length`
  - got: `WebSocket: control frame payload too large`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `21 total, 21 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先继续 WebSocket negative coverage：invalid fragmented final UTF-8；也可以先设计
  bounded frame/message size policy，再针对超大合法 63-bit length 做安全 RED。
