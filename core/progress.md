# Progress Log: HTTP H1 outbound drain benchmark contract

## Session

- **Scope:** HTTP H1 outbound buffer drain benchmark output contract.
- **Status:** focused RED/GREEN completed, `bench_h1outbound` write+drain row
  landed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `request dispatch / response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `bench_h1outbound` live row。

## Completed work

- `test_http_benchmarks` 新增 `bench_h1outbound drain smoke`。
- 新增 `benchmarks/nextpas.core.http/bench_h1outbound`。
- `bench_h1outbound` 输出 `operation=http.h1outbound.drain` marker。
- `bench_h1outbound` 新增 `buffer write+drain 1KB` row，测量 internal outbound
  buffer 1 KiB write + `DrainAllTo` 固定内存 writer。
- `bench_h1outbound` final build 已清理 FPC `Note:` 输出。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 H1 outbound benchmark 契约和 fresh live evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `25 total, 24 passed, 1 failed`，失败原因是 `bench_h1outbound` 入口不存在，
  heaptrc `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `25 total, 25 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' make -C benchmarks/nextpas.core.http/bench_h1outbound clean run`
  -> `buffer write+drain 1KB: 303.0 ns/op`, `3300665 ops/s`，final build output
  没有 FPC `Warning:` / `Note:`。

## Direction review

方向没有走偏：本轮继续把 full-chain server gap 拆到 response-side outbound drain 层，
且没有改生产 HTTP 行为。与上一批 fixed `200 OK` writer row `1441.1 ns/op` 相比，
outbound buffer 1 KiB write+drain 只有 `303.0 ns/op`，当前更可能的优化点仍在 writer
allocation / header materialization / full-chain normalization。

## Next step

继续 `6/6 benchmark/performance`。下一批建议把 `bench_fullchain` 整理成 normalized
output，或针对 H1 writer allocation/header materialization 做生产优化前的更细拆分。
