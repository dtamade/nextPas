# Progress Log: Static MIME case-insensitive contract

## Session

- **Scope:** 补齐 static serving MIME 大小写不敏感和 fallback contract。
- **Status:** verified
- **Roadmap Position:** `4/6 HTTP examples/static helper polish` -> `static serving`
  -> `MIME case-insensitive contract`

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

- `test_http_static` 新增 `ServeDir MIME case-insensitive and fallback` focused proof。
- `SetupTmpDir` 增加 `.JSON` 与 unknown extension fixture。
- `nextpas.core.http.static.MimeTypeFromExt` 改为 lowercase 后匹配 MIME table。
- `docs/http/API_COVERAGE.md` 已记录 static helper-level MIME contract。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_static test`
  - `10 total, 9 passed, 1 failed`
  - failure: `uppercase JSON extension maps to application/json`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_static test`
  - `10 total, 10 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后继续 `HttpServer 完成` 主线。
- 下一刀优先在 examples / docs / benchmark readiness 和仍缺 direct proof 的真实 runtime
  gap 之间选择；benchmark 仍后置，不为了刷量重复 malformed parity。
