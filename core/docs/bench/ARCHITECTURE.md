# nextpas.core.bench — 架构文档

> **最后更新**: 2026-07-19（Round 62 + 审计收敛）

## 模块定位

L1 层基准测试框架，仅依赖 L0（base, exception, platform.time）。

## 源文件清单

| 文件 | 行数（约） | 职责 |
|------|-----------|------|
| `bench.base.pas` | ~1050 | 核心类型（TBenchResult/TBenchStats/TBenchConfig）、常量、工具函数 |
| `bench.intf.pas` | ~900 | 接口定义（IBenchSuite/IBenchResults/IBenchContext/…） |
| `bench.pas` | ~3240 | 门面：TBenchSuite fluent builder + TBenchResults（**已膨胀，见下**） |
| `bench.runner.pas` | ~1430 | TBenchContext + TBenchRunner。校准、自适应预热、执行路径 |
| `bench.stats.pas` | ~1250 | TBenchStatsAnalyzer。Welford、MWU、K-S、OLS、贝叶斯 |
| `bench.stats.advanced.pas` | ~1130 | TAdvancedStats。MAD、Bootstrap/BCa、Fisher、偏度/峰度 |
| `bench.report.pas` | ~1180 | TBenchReportGenerator。Console/JSON/TSV/HTML/Matrix |
| `bench.baseline.pas` | ~490 | TBaselineManager。JSON 序列化、时间线追加 |
| `bench.parallel.pas` | ~300 | TParallelBenchmark。TThread 工作线程 |
| `bench.run.pas` | ~310 | TBenchRun 线程安全执行器 |
| `bench.memtrack.pas` | ~380 | TMemoryTracker。MemoryManager hook |
| `bench.xlang.pas` | ~570 | Go/Rust/FPC 跨语言输出解析 |
| `bench.test_helpers.pas` | ~90 | 测试辅助 |

## 门面策略

- `bench.pas` 是用户唯一入口，但 TBenchResults 查询/聚合 API 已使门面 >3k 行。
- **2026-07-19 起默认冻结** 向 `IBenchResults`/`IBenchSuite` 新增公共便捷方法。
- 后续增量优先：`bench.report` / `bench.stats` 子单元，或明确 bugfix。
- 分组相关内部 helper：`ExtractGroupName` / `CollectGroupResults` / `CollectGroupNsPerOp`
  （GetGroups、GetGroupStats、CompareGroups、`To*_Grouped` 共用）。

## 数据流

```
TBenchSuite (fluent builder)
  ↓ .Run()
TBenchRunner.Execute()
  ├── CalibrateEntryIterations()    ← 找到稳定迭代数
  ├── WarmupEntry()                 ← 自适应预热（Welford CV 收敛）
  └── ExecuteSequentialEntry()      ← 采样循环
        ├── TBenchContext.Create
        ├── entry.Func(ctx) × N iterations
        ├── TBenchStatsAnalyzer.ComputeStats(samples)
        └── → TBenchResult
  ↓
TBenchResults (聚合所有结果)
  ↓ .PrintToConsole / .ToJSON / .ToHTML / .ToMatrixReport
TBenchReportGenerator
```

## 执行路径

1. **Loop 基准** (`AddLoop`): 用户控制循环，`TBenchLoopFunc(AN: Int64)`
2. **普通基准** (`Add`): 框架控制迭代，`TBenchFunc(ctx: IBenchContext)`
3. **并行基准** (`AddParallel`): 多线程执行，结果聚合

## 统计流水线

```
原始样本 (Double[])
  ↓ ComputeStats (Welford 单遍)
TBenchStats { Mean, StdDev, Min, Max, Median, CV, N }
  ↓ Mann-Whitney U / K-S 检验
TBenchComparison { PValue, Significant, ChangePercent }
  ↓ Bootstrap CI / BCa
ConfidenceInterval { Lower, Upper, Level }
```

## 依赖关系

```
bench.base ← (L0: base, errors)
bench.intf ← bench.base
bench.stats ← bench.base, bench.intf
bench.stats.advanced ← bench.base
bench.memtrack ← bench.base
bench.run ← bench.base, bench.intf
bench.parallel ← bench.base, bench.intf
bench.runner ← bench.base, bench.intf, bench.stats, bench.memtrack, bench.parallel
bench.baseline ← bench.base, bench.intf
bench.report ← bench.base, bench.intf, bench.stats
bench ← ALL (门面)
```
