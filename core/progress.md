# Progress Log: EHttpError public category proof

## Session

- **Scope:** 补齐 `http.base` 中 `EHttpError` 的 public error category focused
  proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `public interface completeness`
  -> `EHttpError category contract`

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

- `test_http_base` 新增 `EHttpError category` focused proof。
- 直接构造的 `EHttpError` 现在被测试锁住为：
  - 继承 `ENextPasError`
  - 保留 message
  - `Category = ecNetwork`
- `HttpStrToMethod('INVALID')` 抛出的 `EHttpError` 同样锁住 `ecNetwork`。
- `docs/http/API_COVERAGE.md` 已移除 `EHttpError` category next-action。

## Verification

- `make -C tests/nextpas.core.http/test_http_base test`
  - `15/15 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先从 `docs/http/API_COVERAGE.md` 的 remaining next-action 中选择一个
  仍能推进 public API / example / benchmark 完整性的窄切片。
