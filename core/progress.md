# Progress Log: HTTP server benchmark comparison runner

## Session

- **Scope:** 补齐 HTTP server keep-alive benchmark comparison runner 与报告写入。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `HTTP server keep-alive comparison runner`

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

- 新增 `benchmarks/nextpas.core.http/run_server_comparison.sh`。
- runner 统一 build/run nextPas、Go、Rust 三路 keep-alive benchmark。
- runner 支持 `--requests`、`--threads`、`--output`。
- `test_http_benchmarks` 现在锁住 runner stdout 与 report file 的三路指标输出。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录 runner 用法。

## Verification

- RED 1:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `4 total, 3 passed, 1 failed`
  - failure: `server comparison runner exists`
  - heaptrc: `0 unfreed memory blocks`
- RED 2:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `4 total, 3 passed, 1 failed`
  - failure: `unknown argument: --output`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `4 total, 4 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议补正式 benchmark result snapshot：记录硬件/OS/toolchain 信息、运行参数、nextPas/Go/Rust 三路输出，并明确“不作为性能排名”的当前解释边界。
- 如果继续提高 Rust 对照质量，应新增 Hyper/Tokio comparator，并把当前 std-only comparator 保留为零依赖 microbaseline。
- correctness 方向若重启，应先找真实 runtime RED，不再铺低价值 parity 覆盖。
