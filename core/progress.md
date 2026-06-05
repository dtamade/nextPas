# Progress Log: HTTP H1 writer header-only benchmark split

## Session

- **Scope:** H1 writer header/status serialization benchmark split.
- **Status:** focused RED/GREEN completed, `bench_h1writer` header-only row landed,
  docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和两条 focused
  `bench_h1writer` live rows。

## Completed work

- `test_http_benchmarks` 的 H1 writer smoke 现在验证 `headers only 200`。
- 新增 `CheckBenchmarkRunRow`，避免 `bench_filter=` 或 summary 行误判为真实
  benchmark run row。
- `bench_h1writer` 新增 `headers only 200` row。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 H1 writer header-only benchmark 契约和 fresh live evidence。
- sidecar 子代理完成只读审计，确认下一步生产优化候选应在 `WriteStatusLine` /
  header materialization，而不是 header API 或 chunked/body path。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 25 passed, 1 failed`，失败原因是 `bench_h1writer` 缺少真实
  `headers only 200` run row，heaptrc `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='headers only 200' make -C benchmarks/nextpas.core.http/bench_h1writer clean run`
  -> `headers only 200: 1414.6 ns/op`, `706917 ops/s`，clean build 没有 FPC
  `Warning:` / `Note:`。
- Fresh comparison row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='fixed 200 13B' make -C benchmarks/nextpas.core.http/bench_h1writer run`
  -> `fixed 200 13B: 1389.1 ns/op`, `719869 ops/s`。

## Direction review

方向没有走偏：本轮继续把 full-chain server gap 拆到 response serialization 层，
没有改生产 HTTP 行为。新证据显示小响应 body write 与 header-only path 同量级，
下一批更应验证 status-line/header materialization 的生产优化，而不是继续堆 broad
benchmark 或改 outbound buffer。

## Next step

继续 `6/6 benchmark/performance`。下一批建议做 `TH1ResponseWriter.WriteStatusLine`
的 `HTTP_STATUS_OK` fixed string fast path，先用 `test_http_h1writer` 保护 wire bytes，
再用 `test_http_benchmarks` 和 `bench_h1writer` filtered rows 看收益。
