# Progress Log: H1 parser adapter materialization breakdown

## Session

- **Scope:** H1 parser adapter materialization breakdown benchmark rows.
- **Status:** complete; path-limited commit prepared for this batch.
- **Roadmap Position:** `6/6 benchmark/performance` -> `parser/adapter cost localization`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 H1 parser
  benchmark/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public HTTP facade API 变化。
- 本轮不跑全量测试；只跑 `test_http_benchmarks` 和局部 `bench_h1parser` sanity。

## Completed work

- 子代理只读巡检完成：Pascal raw llhttp gap 真实，但当前更大成本是 adapter/materialization。
- 本地初读确认 adapter 热点在 `AppendSpan` string、`FHeaders.Add`、body `Move`。
- 新增 `bench_h1parser` adapter materialization breakdown rows。
- `test_http_benchmarks` 现在锁住 breakdown rows 必须存在。

## Verification

- RED:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - failed as expected: H1 parser benchmark span/header/body breakdown row markers missing。
- First GREEN attempt:
  - failed to build `bench_h1parser`: `Identifier not found "TBytes"`。
  - fixed by adding `nextpas.core.base` to benchmark uses.
- Focused benchmark gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark sanity:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - output includes `bench_max_iters=100000`
  - representative rows: raw 10 headers `753.6 ns/op`, noop 10 headers `786.6 ns/op`,
    adapter span append 10 headers `801.1 ns/op`, adapter header add 10 headers `1220.9 ns/op`,
    adapter body copy 1KB `33.1 ns/op`, full adapter 10 headers `3378.2 ns/op`,
    fast 10 headers `1381.5 ns/op`

## Current conclusion

方向没有走偏：本轮直接服务性能追平目标，先把 full adapter 慢点拆开；不再增加重复
correctness parity，也不跑全量测试。

本轮证据显示下一批最佳生产优化方向是减少 header/string materialization，body copy 暂不优先，
Pascal llhttp raw gap 保留为 profile/codegen 专项。

## Commit scope

- Only stage this batch's benchmark/test/docs/control files.
- Planned commit message: `bench(http): split h1 adapter materialization costs`.

## Next step

- GREEN 后基于 breakdown rows 决定下一批生产优化目标。
- 若 header/string 成本最高，优先做 lazy/span-backed 或 header-policy-specific 优化；若 body copy
  成本异常，再看 body reader/ownership。
