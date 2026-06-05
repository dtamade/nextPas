# Progress Log: Pascal llhttp raw-gap diagnosis

## Session

- **Scope:** H1 parser raw Pascal llhttp vs C llhttp focused diagnosis.
- **Status:** evidence gathered; docs/control update in progress; final focused
  smoke, diff check, and commit pending.
- **Roadmap Position:** `6/6 benchmark/performance` -> `Pascal-translated llhttp raw-gap track`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP
  benchmark docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量测试；只跑 filtered benchmark rows 和 single-row flag matrix。

## Completed work

- 复测 Pascal raw 10-header row：`766.5 ns/op`。
- 复测 C raw 10-header row：`525.0 ns/op`。
- 跑 focused flag matrix：Pascal extra opts 最好约 `750.6 ns/op`，C native 约
  `524.5 ns/op`，flags 不能追平。
- 检查 generated Pascal/C llhttp 结构：当前更像 generator/codegen/register-pressure
  问题，不是简单 SIMD flag 问题。
- 确认本机 `perf` 不可用：`perf_event_paranoid=3`，无法采集 hardware counters。
- 已完成只读 `gpt-5.5 xhigh` 子代理 `Fermat` 第二视角审计，结论与本地判断一致：
  不手改 generated llhttp，先固定 perf/codegen 诊断路线。

## Verification So Far

- `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - `raw llhttp: 10 headers (~400B) = 766.5 ns/op`
- `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - `C raw llhttp: 10 headers (~400B) = 525.0 ns/op`
- `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --no-perf`
  - `pascal-default = 854.9 ns/op`
  - `pascal-coreavx2 = 769.7 ns/op`
  - `pascal-extra-opts = 750.6 ns/op`
  - `c-default = 526.0 ns/op`
  - `c-native = 524.5 ns/op`

## Current conclusion

方向没有走偏：用户指出的 Pascal llhttp raw 性能问题存在，但本轮证据不支持直接改
generated llhttp。性能追平 Go/Rust 的主线仍应分两条推进：

- 短期：继续削 adapter/server materialization 中已证明的高倍数成本。
- 中期：在 perf 可用环境或 compiler/codegen 审计下处理 Pascal raw state-machine gap。

## Commit scope

- Only stage this batch's HTTP benchmark docs/control files.
- Planned commit message: `docs(http): classify pascal llhttp raw gap`

## Next step

- 提交本轮诊断文档。
- 下一批优先继续 H1 adapter materialization：URL parse/cache 或 body reader copy/ownership，
  仍按 focused RED/GREEN + narrow benchmark row 推进。
