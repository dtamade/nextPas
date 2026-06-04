# Progress Log: WebSocket bounded frame/message size options

## Session

- **Scope:** 补齐 WebSocket `TWebSocketOptions` 与 bounded frame/message size enforcement。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket API/safety boundary`
  -> `bounded frame/message size policy`

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

- `test_http_websocket` 新增 `WebSocketMaxFrameSizeRejectsDeclaredOversizeFrame` focused proof。
- `test_http_websocket` 新增 `WebSocketMaxMessageSizeRejectsFragmentedMessage` focused proof。
- `nextpas.core.http.websocket` 新增 `TWebSocketOptions`、默认 frame/message limits、三参数 upgrade overload。
- `nextpas.core.http` facade re-export 新 options/default constants/overload。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录新公开契约。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - compile failed as expected
  - `Identifier not found "TWebSocketOptions"`
  - `Wrong number of parameters specified for call to "UpgradeWebSocket"`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `23 total, 23 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先做 WebSocket negative coverage 中仍有价值的边界：invalid fragmented final UTF-8
  或 binary fragmented size parity；如果继续 API completeness，则评估 streaming frame/message reader
  是否需要进入路线图。
