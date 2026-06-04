# Progress Log: HTTP server benchmark result snapshot

## Session

- **Scope:** 记录 HTTP server keep-alive benchmark 本机 snapshot，并补充 benchmark 文档。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `HTTP server keep-alive local snapshot`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮只做 path-limited HTTP benchmark docs。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `../findings.md`
  - `../progress.md`
  - `../task_plan.md`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- 运行 `capture_server_comparison_snapshot.sh --requests 20000 --threads 4`。
- 新增 `docs/http/BENCHMARKS.md`，记录运行方法、环境、结果和解释边界。
- `docs/http/README.md` 现在链接 benchmark 文档。
- `docs/http/API_COVERAGE.md` 已记录 `20000 / 4` snapshot。

## Verification

- Snapshot run:
  - `benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh --requests 20000 --threads 4 --output build/projects/nextpas.core.http/server_comparison/snapshot-2026-06-05.md`
  - nextPas: `completed=20000`, `ns/op=12396`, `req/s=80665`
  - Go `net/http`: `completed=20000`, `ns/op=49096`, `req/s=20367`
  - Rust std-only: `completed=20000`, `ns/op=9854`, `req/s=101471`
- Focused gate:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `5 total, 5 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 如果继续 benchmark 路线，下一刀建议补 Hyper/Tokio comparator，避免 Rust 对照停留在 std-only microbaseline。
