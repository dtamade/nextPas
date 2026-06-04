# Progress Log: Middleware nil-input contract

## Session

- **Scope:** 补齐 `MiddlewareFunc` / `TMiddlewareChain` / `Chain` 的 nil 输入拒绝契约。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `public interface completeness`
  -> `middleware nil-input contract`

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

- `test_http_middleware` 新增 `Middleware factories reject nil inputs` focused proof。
- `nextpas.core.http.middleware.MiddlewareFunc` 增加 nil callback guard。
- `TMiddlewareChain.Create` / `Use` 增加 nil guard。
- `Chain` 增加异常路径释放，避免 nil middleware entry 抛出时泄漏中间 chain。
- `docs/http/API_COVERAGE.md` 已记录 middleware nil 输入边界。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_middleware test`
  - `11 total, 10 passed, 1 failed`
  - failure: `nil middleware wrap callback raises EHttpError`
  - heaptrc: `0 unfreed memory blocks`
- First GREEN exposed leak:
  - `11 total, 11 passed, 0 failed`
  - heaptrc: `2 unfreed memory blocks : 120`
- Final GREEN:
  - `make -C tests/nextpas.core.http/test_http_middleware test`
  - `11 total, 11 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先从 API coverage 的剩余 next-action 中选择真实 gap；如果没有 public API
  contract gap，转向 runnable examples 或 benchmark 准备，而不是机械复制同型 parity case。
