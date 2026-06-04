# Progress Log: router CONNECT / TRACE convenience surface

## Session

- **Scope:** 补齐 `IHttpRouter` / `THttpRouter` 的 `Connect` / `Trace`
  便利方法，和已公开的 `hmConnect` / `hmTrace` method enum 对齐。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `public interface completeness`
  -> `router CONNECT / TRACE convenience surface`

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

- `IHttpRouter` 新增 `Connect` / `Trace`。
- `THttpRouter` 新增 `Connect` / `Trace`，实现为 `Handle(hmConnect/hmTrace, ...)`。
- `test_http_contract` 锁住 facade/interface 级 public surface。
- `test_http_router` 锁住 concrete router dispatch。
- `docs/http/README.md` 与 `docs/http/API_COVERAGE.md` 已同步。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_contract test`
  - failure: `Identifier idents no member "Connect"` / `"Trace"`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_contract test`
  - `29/29 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_router test`
  - `21/21 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先做仍未闭合的 public contract 小缺口，例如 `EHttpError`
  public error category proof，或进入示例/benchmark 前的文档矩阵清理。
