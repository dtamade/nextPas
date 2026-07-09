# nextpas.core.bench — 架构文档

## 模块定位

L1 层基准测试框架，仅依赖 L0（base, exception, platform.time）。

## 源文件清单

| 文件 | 行数 | 职责 |
|------|------|------|
| `bench.base.pas` | ~980 | 核心类型（TBenchResult/TBenchStats/TBenchConfig）、常量、工具函数（IntroSort/NormalCDF/Xoroshiro128+） |
| `bench.intf.pas` | ~530 | 接口定义（IBenchSuite/IBenchResults/IBenchContext/IBenchStatsAnalyzer/IBenchReportGenerator） |
| `bench.pas` | ~1480 | 门面：TBenchSuite fluent builder + TBenchResults。用户唯一入口 |
| `bench.runner.pas` | ~1310 | TBenchContext + TBenchRunner。校准、自适应预热、三执行路径（loop/parallel/sequential） |
| `bench.stats.pas` | ~1210 | TBenchStatsAnalyzer。Welford 单遍统计、Mann-Whitney U、K-S 检验、OLS 回归、贝叶斯估计 |
| `bench.stats.advanced.pas` | ~1130 | TAdvancedStats。MAD O(N)、Bootstrap CI/BCa、Fisher 置换、偏度/峰度、Cohen's d |
| `bench.report.pas` | ~880 | TBenchReportGenerator。Console/JSON/TSV/HTML/Matrix/Benchstat 输出 |
| `bench.baseline.pas` | ~480 | TBaselineManager。JSON 序列化、时间线追加 |
| `bench.parallel.pas` | ~300 | TParallelBenchmark。TThread 工作线程、加速比/效率计算 |
| `bench.run.pas` | ~290 | TBenchRun 线程安全执行器。原子计数、AllocBenchResult/FreeBenchResult |
| `bench.memtrack.pas` | ~380 | TMemoryTracker。原子 CAS、全局 MemoryManager hook |
| `bench.test_helpers.pas` | ~70 | 测试辅助：NoOpBench/BusyBench/AllocBench/MakeBenchEntry |

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
