# Progress Log: HTTP server benchmark comparators

## Session

- **Scope:** 补齐 HTTP server keep-alive benchmark 的 Go/Rust comparator smoke。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `HTTP server keep-alive comparator harness`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮只做 path-limited HTTP benchmark 变更。
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

- `test_http_benchmarks` 现在 smoke nextPas / Go / Rust 三条 server benchmark。
- `bench_http_server` 新增 `impl=nextpas`，和 comparator 输出对齐。
- 新增 Go `net/http` keep-alive comparator。
- 新增 Rust std-only HTTP/1.1 keep-alive comparator。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录 comparator harness。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `3 total, 0 passed, 3 failed`
  - failures:
    - `impl=nextpas` missing
    - Go comparator path missing
    - Rust comparator path missing
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `3 total, 3 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议补正式 benchmark runner / result capture，把 nextPas、Go、Rust 的同字段输出写成可重复采集报告。
- 如果继续提高 Rust 对照质量，应新增 Hyper/Tokio comparator，并把当前 std-only comparator 明确保留为零依赖 microbaseline。
- correctness 方向若重启，应先找真实 runtime RED，不再铺低价值 parity 覆盖。
