# Progress Log: HTTP H1 writer serialization benchmark contract

## Session

- **Scope:** HTTP H1 writer serialization benchmark output contract.
- **Status:** focused RED/GREEN completed, `bench_h1writer` fixed response row
  landed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `request dispatch / response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `bench_h1writer` live row。

## Completed work

- `test_http_benchmarks` 新增 `bench_h1writer response serialization smoke`。
- 新增 `benchmarks/nextpas.core.http/bench_h1writer`。
- `bench_h1writer` 输出 `operation=http.h1writer.serialize` marker。
- `bench_h1writer` 新增 `fixed 200 13B` row，测量固定 `200 OK` + 13B body 写入固定
  内存 writer。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 H1 writer benchmark 契约和 fresh live evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `24 total, 23 passed, 1 failed`，失败原因是 `bench_h1writer` 入口不存在，
  heaptrc `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `24 total, 24 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='fixed 200 13B' make -C benchmarks/nextpas.core.http/bench_h1writer clean run`
  -> `fixed 200 13B: 1441.1 ns/op`, `693895 ops/s`，final build output 没有
  FPC `Warning:` / `Note:`。

## Direction review

方向没有走偏：本轮继续把 full-chain server gap 拆到 response serialization 层，
且没有改生产 HTTP 行为。与上一批 router dispatch `508.1 ns/op` 相比，固定小响应
writer row 更重，下一步应继续拆 writer allocation/header materialization/outbound drain。

## Next step

继续 `6/6 benchmark/performance`。下一批建议把 `bench_fullchain` 整理成 normalized
output，或补 outbound buffer / drain-side microbenchmark，再决定是否进入生产优化。
