# Progress Log: HandlerFunc nil-callback contract

## Session

- **Scope:** 补齐 `HandlerFunc` nil closure / method / procedure callback 的
  显式拒绝契约。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `public interface completeness`
  -> `HandlerFunc nil-callback contract`

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

- `test_http_middleware` 新增 `HandlerFunc rejects nil callbacks` focused proof。
- `nextpas.core.http.middleware.HandlerFunc` 三个 overload 均增加 nil guard。
- nil closure / method / procedure callback 现在都会立即抛 `EHttpError`。
- `docs/http/API_COVERAGE.md` 已移除 HandlerFunc nil-callback next-action。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_middleware test`
  - `10 total, 9 passed, 1 failed`
  - failure: `nil handler closure raises EHttpError`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_middleware test`
  - `10/10 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先从 `docs/http/API_COVERAGE.md` 的 remaining next-action 中选择一个
  仍能推进 public API / example / benchmark 完整性的窄切片。
