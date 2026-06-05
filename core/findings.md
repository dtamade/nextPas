# Findings: HTTP benchmark runner max iterations

## Scope

本轮只改 benchmark 基础设施和 benchmark smoke，不改 HTTP public facade API，不改 wire
contract。目标是让 parser/C comparator 数据更可信，避免旧 `MAX_ITERS = 1000` 对
sub-microsecond rows 造成过强噪声。

## RED evidence

新增 focused smoke 后先跑：

```sh
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
```

失败点：

```text
FAIL: H1 parser benchmark max iterations env - bench_max_iters=2000 marker missing
FAIL: C llhttp comparator max iterations env when configured - bench_max_iters=2000 marker missing
```

失败输出同时显示 Pascal/C rows 仍是 `1000 iters`，证明旧上限不可配置。

## Implemented change

- `TBenchRunner` 默认 max iterations 改为 `100000`。
- `TBenchRunner` 读取 `NEXTPAS_BENCH_MAX_ITERS`；空值、非法值、`<100` 回退默认。
- `TBenchRunner.Summary` 输出 `bench_max_iters=<effective>`。
- C llhttp comparator 使用同名 env 和同样默认值，并在 summary 输出 effective value。
- `test_http_benchmarks` 新增 env override smoke：
  - Pascal `bench_h1parser` 用 `NEXTPAS_BENCH_MAX_ITERS=2000` 运行并检查 marker。
  - C llhttp comparator 在 `NEXTPAS_LLHTTP_ROOT` 已配置时做同样检查。

## Verification

- Focused benchmark gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Benchmark sanity

Pascal parser benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Evidence:

- `bench_max_iters=100000`
- raw llhttp simple GET: `215.3 ns/op`
- raw llhttp 10 headers: `776.0 ns/op`
- llhttp adapter 10 headers: `3458.0 ns/op`
- fast simple GET: `350.1 ns/op`
- fast 10 headers: `1432.8 ns/op`

C llhttp comparator:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
```

Evidence:

- `bench_max_iters=100000`
- C raw simple GET: `152.4 ns/op`
- C raw 10 headers: `535.1 ns/op`
- C raw POST 1KB: `300.9 ns/op`
- C raw pipeline: `1443.6 ns/op`

## Current conclusion

方向没有走偏：这不是生产 hot-path 修复，而是为了让后续“追 Go/Rust 标准”的性能决策有更可信
数据。默认 `100000` 控制了日常 benchmark 成本；正式 snapshot 可以显式提高 env。

## Remaining gaps / risks

- Pascal `TBenchRunner` 的 calibration 仍容易让多行撞到 max cap；下一步如果继续做 formal
  benchmark，需要进一步改善 calibration 算法，而不仅是提高 cap。
- 目前 C comparator 行为更接近 target time，Pascal runner 的 cap 策略仍偏保守；后续可统一
  成更接近 C comparator 的校准逻辑。
- 本轮不声明任何新的 server throughput 提升。
