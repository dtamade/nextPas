# Progress Log: HTTP server benchmark snapshot capture

## Session

- **Scope:** 补齐 HTTP server keep-alive benchmark Markdown snapshot capture，并清理 benchmark 编译噪音。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `HTTP server keep-alive snapshot capture`

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

- 新增 `benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh`。
- snapshot capture 记录 `git_head`、OS、FPC、Go、Rust 版本、参数与 raw comparison output。
- `test_http_benchmarks` 现在锁住 snapshot 文件内容和三路指标。
- `test_http_benchmarks` 现在还锁住 snapshot 不含 FPC `Warning:` / `Note:`。
- `bench_http_server` 已清理当前 warning/note 来源。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录 snapshot 用法。

## Verification

- RED 1:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `5 total, 4 passed, 1 failed`
  - failure: `server comparison snapshot runner exists`
  - heaptrc: `0 unfreed memory blocks`
- RED 2:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `5 total, 4 passed, 1 failed`
  - failure: snapshot contained FPC `Warning:`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `5 total, 5 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议在当前 clean HTTP benchmark commit 之后，运行一次较大规模 snapshot capture，并把结果作为报告材料或 docs 附录记录。
- 如果继续提高 Rust 对照质量，应新增 Hyper/Tokio comparator，并把当前 std-only comparator 保留为零依赖 microbaseline。
- correctness 方向若重启，应先找真实 runtime RED，不再铺低价值 parity 覆盖。
