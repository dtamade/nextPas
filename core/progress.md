# Progress Log: HTTP benchmark runner max iterations

## Session

- **Scope:** benchmark max-iteration configurability for Pascal `TBenchRunner` and C llhttp comparator.
- **Status:** complete; path-limited commit prepared for this batch.
- **Roadmap Position:** `6/6 benchmark/performance` -> `benchmark evidence quality`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 benchmark
  runner/C comparator/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public HTTP facade API 变化。
- 本轮不跑全量测试；只跑 `test_http_benchmarks` 和局部 parser/C comparator sanity。

## Completed work

- 新增 benchmark max-iters env focused RED。
- `src/nextpas.core.bench.pas` 现在默认 `bench_max_iters=100000`，并支持
  `NEXTPAS_BENCH_MAX_ITERS`。
- C llhttp comparator 同步支持 `NEXTPAS_BENCH_MAX_ITERS`。
- 两个 runner 都在 summary 中输出 effective `bench_max_iters`，方便 benchmark snapshot
  追溯。

## Verification

- RED:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - failed as expected: Pascal/C max-iters marker missing and rows still used `1000 iters`。
- Focused benchmark gate:
  - same command after implementation
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - fresh pre-commit rerun on 2026-06-05:
    `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - fresh result: `9 total, 9 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
- Benchmark sanity:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - output includes `bench_max_iters=100000`
  - representative rows: raw simple GET `215.3 ns/op`, raw 10 headers `776.0 ns/op`,
    adapter 10 headers `3458.0 ns/op`, fast 10 headers `1432.8 ns/op`
  - `make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - output includes `bench_max_iters=100000`
  - representative C rows: raw simple GET `152.4 ns/op`, raw 10 headers `535.1 ns/op`,
    raw POST 1KB `300.9 ns/op`, raw pipeline `1443.6 ns/op`

## Current conclusion

方向没有走偏：本轮提升 benchmark 证据质量，避免继续基于 `1000` 迭代的短样本做性能决策。
这对后续追 Go/Rust 标准是必要基础，但不是生产吞吐提升。

## Commit scope

- Only stage this batch's benchmark/control files.
- Commit message: `bench(http): make parser iteration cap configurable`.

## Next step

- 下一批继续 parser adapter materialization，优先看 `TH1Parser` request metadata/header string
  materialization 是否还能减少。
- 如果要做正式对标 snapshot，先把 Pascal runner calibration 进一步调到更接近 C comparator
  的 target-time 行为，再跑 Go/Rust/nextPas 对照。
