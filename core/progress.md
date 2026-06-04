# Progress Log: WebSocket echo runnable example

## Session

- **Scope:** 补齐 HTTP module 的 WebSocket runnable example 与 focused smoke。
- **Status:** verified
- **Roadmap Position:** `5/6 docs/examples` -> `WebSocket runnable example coverage`

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

- `test_http_examples` 新增 WebSocket echo demo build/run/raw-wire echo smoke。
- 新增 `examples/nextpas.core.http/http_websocket_echo_demo`。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录新 runnable example。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_examples test`
  - `3 total, 2 passed, 1 failed`
  - failure:
    - `websocket echo demo serves documented endpoint - unable to resolve core root from current directory or executable path`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_examples test`
  - `3 total, 3 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议继续 `HttpServer 完成` 主线：优先找 remaining server runtime gap 或补 benchmark 规划前的 example/docs 缺口。
- WebSocket negative API 面当前不应继续铺同路径 parity；只有发现真实 RED 再回到 WebSocket。
