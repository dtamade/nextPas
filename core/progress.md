# Progress Log: HTTP H1 writer 200 OK status-line fast path

## Session

- **Scope:** H1 writer `HTTP_STATUS_OK` status-line micro-optimization.
- **Status:** production fast path landed locally, focused gates passed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP writer/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_h1writer`、`test_http_benchmarks`
  和两条 focused `bench_h1writer` live rows。

## Completed work

- `TH1ResponseWriter.WriteStatusLine` 新增 `HTTP_STATUS_OK` fixed status-line
  fast path。
- 非 200 status 仍走旧泛化路径，因此 `404`、`100/103`、`101`、`204`、`304`
  等 status-line contract 未改。
- `docs/http/API_COVERAGE.md` 与 `docs/http/BENCHMARKS.md` 已同步生产优化和 fresh
  local evidence。

## Verification

- Baseline before change:
  `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  -> `29 total, 29 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Writer gate after change:
  `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  -> `29 total, 29 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Benchmark gate:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='headers only 200' make -C benchmarks/nextpas.core.http/bench_h1writer clean run`
  -> `headers only 200: 1284.0 ns/op`, `778840 ops/s`，clean build 没有 FPC
  `Warning:` / `Note:`。
- Fresh comparison row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='fixed 200 13B' make -C benchmarks/nextpas.core.http/bench_h1writer run`
  -> `fixed 200 13B: 1261.1 ns/op`, `792973 ops/s`。

## Direction review

方向没有走偏：本轮从上一批 benchmark split 得出的热点继续推进，落了一个极小、
wire-contract 受控、可 benchmark 证明的 production optimization。当前收益只声明在
H1 writer narrowed rows，不上升为 full-chain server throughput 结论。

## Next step

继续 `6/6 benchmark/performance`。下一批建议评估 `WriteAllHeaders` 的 header line
materialization：在不改变 `IHttpHeaders.ForEach` public surface、header order、
normalization、repeated headers 与 short-write retry 的前提下，尝试减少每个 header 的
多段小写入。
