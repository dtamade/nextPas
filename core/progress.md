# Progress Log: HTTP adapter_no_url fast-gate optimization

## Session

- **Scope:** `adapter_no_url` narrowed benchmark + H1 fast-gate optimization.
- **Status:** production fast-gate change implemented; focused benchmark/server gates passed.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `fast-gate hot path cleanup and comparator calibration`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP source/tests/bench/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 仍是无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量仓库测试；只跑变更面 focused gates 与两条 live comparison rows。

## Completed work

- 子代理并行完成 3 个只读调查：
  adapter path 双重解析、URL materialization、benchmark fairness。
- `bench_h1parser` 增加 `adapter no-url` narrowed rows，量化 old double parse /
  direct llhttp / fast parse / metadata 成本。
- `TFastParseResult` 增加 connection-policy flags。
- H1 server fast gate 现在允许 HTTP/1.1 no-body `Connection: keep-alive`
  使用 fast snapshot；`close` / `upgrade` / unsupported token 仍回退 llhttp。
- fast parser touched helper 函数加了 `inline`，范围限定在当前热路径。
- docs/control files 已同步公平性边界和本轮验证证据。

## Verification

- RED:
  `NEXTPAS_BENCH_MAX_ITERS=2000 NEXTPAS_BENCH_FILTER='adapter no-url' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  -> filtered summary 没有 matching adapter no-url rows。
- RED:
  `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  -> 编译失败，缺 `ConnectionKeepAlive` / `ConnectionClose` /
  `ConnectionUnsupported` 字段。
- GREEN benchmark:
  `NEXTPAS_BENCH_MAX_ITERS=2000 NEXTPAS_BENCH_FILTER='adapter no-url' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  -> `fast reject + llhttp 2084.3 ns/op`，`llhttp direct only 1494.0 ns/op`，
  `fast parse only 629.3 ns/op`，`metadata 3 headers 372.2 ns/op`。
- Fast parser gate:
  `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  -> `22 total, 22 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Benchmark smoke gate:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Server contract gate:
  `make -C tests/nextpas.core.http/test_http_server clean test`
  -> `275 total, 275 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Live adapter row:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload adapter_no_url --runs 3`
  -> nextPas median `11022 ns/op`, `90720 req/s`。
- Live no-url row:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url --runs 3`
  -> nextPas median `10948 ns/op`, `91335 req/s`。

## Direction review

方向没有走偏：当前目标是追 Go/Rust 级性能，但本轮没有把不公平 comparator row 当最终结论。
`adapter_no_url` 被重新定位为 nextPas 内部 fast-gate differential；生产改动只消除明确的
double-parse tax，并保留 `close` / `upgrade` 等协议敏感 token 的 llhttp fallback。

## Next step

继续 `6/6 benchmark/performance`。下一批建议先加强 harness correctness：
`run_server_comparison.sh` / smoke tests 应断言 `completed == requests`，并让 nextPas benchmark
输出明确 request-path marker；之后再做 `url_path` path-only URL materialization narrowed RED/GREEN。
