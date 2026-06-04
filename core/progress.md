# Progress Log: HTTP server benchmark smoke

## Session

- **Scope:** 收紧 HTTP server benchmark 的小规模 smoke 与标准化输出。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `HTTP server keep-alive benchmark smoke`

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

- 新增 `test_http_benchmarks` focused benchmark smoke。
- `bench_http_server` 现在支持 `--requests` / `--threads`。
- `bench_http_server` 现在输出 `operation`、`iterations`、`threads`、`ns/op`、`req/s` 等稳定字段。
- `docs/http/API_COVERAGE.md` 与 `docs/http/README.md` 已记录 benchmark smoke。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `1 total, 0 passed, 1 failed`
  - failure:
    - `operation marker missing from output: operation=http.server.keepalive`
  - heaptrc: `0 unfreed memory blocks`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_benchmarks test`
  - `1 total, 1 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀建议补 Go/Rust/FPC RTL 对照 runner 或结果文档，沿用当前 `operation/iterations/ns/op/req/s` 字段。
- 如果回到 correctness，应先找真实 runtime RED，不再铺低价值 parity 覆盖。
