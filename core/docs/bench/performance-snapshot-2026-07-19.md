# nextpas.core.bench 性能快照

| 项 | 值 |
|----|-----|
| 日期 | 2026-07-19 |
| 机器 | Linux x86_64, 44 cores |
| 编译器 | FPC 3.3.1 `-O2` |
| 验证 | `make -C core/benchmarks/nextpas.core.bench clean test` ≈ **27s** 全绿 |

## Harness 驯服说明

| 问题 | 处理 |
|------|------|
| `bench_overhead` `Add(nil)` | 改为 `@NoOpBench` |
| `SuiteRunCycle/100` 嵌套挂死 | 改为 `/10` + 内层 tiny config |
| `bench_report` 外层×内层 20 suite | 改为直接 `TBenchResults.Create` 测报告路径 |
| 外层采样过重 | MinDuration=50ms, MinSamples=5, MaxIterations 收紧 |

## 1. 框架 self-bench（`test_bench_self_bench`）

| 基准 | 约 ns/op |
|------|----------|
| SortDoubleArray/1000 | 82 µs |
| ComputeStats/1000 | 114 µs |
| ToJSON/10results | 34 µs |
| ToHTML/10results | 474 µs |
| noop | ~6.5 ns |

## 2. Overhead（驯服后）

| 基准 | 约 ns/op |
|------|----------|
| SuiteCreateDestroy/100 | 291 µs |
| SuiteAddEntry/1000 | 147 µs |
| SuiteFluentChain | 2.68 µs |
| SuiteRunEmpty | 5.41 µs |
| SuiteRunSingleFast | 969 µs |
| SuiteRunMultiple | 4.25 ms |
| SuiteRunCycle/10 | 8.60 ms |
| ContextGetElapsed/10000 | 255 µs |

## 3. Stats

| 基准 | 约 ns/op |
|------|----------|
| Mean/100 | 1.21 µs |
| Mean/1000 | 10.6 µs |
| Mean/10000 | 112 µs |
| Sort/1000 | 47.1 µs |
| Sort/10000 | 886 µs |
| ComputeStats/1000 | 68.7 µs |
| ComputeStats/10000 | 1.10 ms |

## 4. Report（20 条合成结果）

| 基准 | 约 ns/op |
|------|----------|
| ToConsole/20 | 123 µs |
| ToJSON/20 | 41 µs |
| ToTSV/20 | 65 µs |
| ToHTML/20 | 207 µs |
| SaveToJSON/20 | 114 µs |
| SaveToHTML/20 | 284 µs |
| CompareWithBaseline/20 | 10.4 µs |

## 5. 跨语言 scorecard

`bench/SCORECARD.md`：**未全量刷新**（保留 2026-07-02 基线）。全量 60+ tracks 成本高、产物脏；本轮只保证框架 harness 可绿。

## 结论

- 模块 benchmarks 可在约半分钟内稳定跑完，适合作为 focused 质量门。
- HTML 报告约为 JSON 的 5×（20 results），与 self-bench 量级一致。
- 空基准框架下限仍约 6–7 ns；suite 注册/链式配置开销在 µs 级。
