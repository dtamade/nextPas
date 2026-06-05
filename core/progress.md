# Progress Log: HTTP full-chain benchmark client read correction

## Session

- **Scope:** full-chain benchmark client read correction.
- **Status:** benchmark harness buffered read landed locally, focused gate passed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `full-chain benchmark quality and server comparison calibration`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks`、`bench_fullchain plaintext`
  和一个 `run_server_comparison --workload no_url` live row。

## Completed work

- 复核 live performance：server comparison `no_url` 当前 nextPas `107002 req/s`，
  Rust std-only `104418 req/s`，Go `21163 req/s`。
- 定位 `bench_fullchain` 低分来源：client `ReadResponse` 逐字节 socket read + string concat。
- `test_http_benchmarks` 新增 focused RED：fullchain smoke 必须输出
  `client_read_mode=buffered`。
- `bench_fullchain.ReadResponse` 改为 buffered chunk read，并保留按 header boundary +
  `Content-Length` 判断完整 response。
- `docs/http/API_COVERAGE.md` 与 `docs/http/BENCHMARKS.md` 已同步 fresh local evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 25 passed, 1 failed`，失败为 missing `client_read_mode=buffered`，
  heaptrc `0 unfreed memory blocks`。
- Benchmark gate after change:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh fullchain row:
  `NEXTPAS_BENCH_MAX_ITERS=1000 NEXTPAS_BENCH_FILTER=plaintext make -C benchmarks/nextpas.core.http/bench_fullchain clean run`
  -> `client_read_mode=buffered`，`plaintext: 42132.4 ns/op`, `23735 req/s`。
- Fullchain all-scenario smoke:
  `NEXTPAS_BENCH_MAX_ITERS=128 make -C benchmarks/nextpas.core.http/bench_fullchain run`
  -> `plaintext/json/echo_1k/sink_16k/param_route` 均 `128/128 completed`。
- Fresh server comparison row:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url`
  -> nextPas `9345 ns/op`, `107002 req/s`; Rust std-only `9576 ns/op`, `104418 req/s`;
  Go `47251 ns/op`, `21163 req/s`。

## Direction review

方向没有走偏：本轮把“性能低”拆成 benchmark harness 与 production server 两条证据线。
没有碰生产 server，也没有把单连接 fullchain row 当成 Rust/Go 对标结论。下一步应以
multi-client comparison median 和 workload 分解驱动优化。

## Next step

继续 `6/6 benchmark/performance`。下一批建议跑/记录 `--runs 3` 的
`no_url`、`adapter_no_url`、`url_path`、`response_1k` median snapshot；若某个 workload
落后 Rust std-only，再针对对应 seam 写 focused RED/GREEN。
