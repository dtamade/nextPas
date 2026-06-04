# Progress Log: WebSocket outgoing close validation

## Session

- **Scope:** 补齐 WebSocket outgoing `Close` close code / reason validation。
- **Status:** verified
- **Roadmap Position:** `3/6 H1/WebSocket correctness hardening` -> `WebSocket public API safety`
  -> `outgoing close payload semantic validation`

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

- `test_http_websocket` 新增 `OutgoingCloseInvalidCodeRejected` focused proof。
- `test_http_websocket` 新增 `OutgoingCloseInvalidUtf8ReasonRejected` focused proof。
- `nextpas.core.http.websocket` 现在在 `Close` 写出前复用 close payload validation。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录新公开契约。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `27 total, 25 passed, 2 failed`
  - failures:
    - `outgoing-close-invalid-code: server sends text frame`
    - `outgoing-close-invalid-utf8: server sends text frame`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - `27 total, 27 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议优先评估 `WriteText` outbound UTF-8 validation 是否应成为 public contract。
- 如果选择继续 WebSocket，先 RED；如果用例已 PASS 或只是同路径 parity，则转向 HttpServer examples/docs
  或 server runtime gap，不再复制低价值同型覆盖。
