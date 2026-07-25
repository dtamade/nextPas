# nextpas.core.bench — API 参考

> **最后更新**: 2026-07-21（T1：签名与 intf 对齐）
> 完整签名以 `core/src/nextpas.core.bench.intf.pas` 为准。

## 门面入口

### TBenchSuite

Fluent builder，用户唯一需要直接构造的类。

```pascal
uses nextpas.core.bench, nextpas.core.time.base;

var LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('MySuite')
    .SetMinDuration(TDuration.FromSeconds(2))
    .SetMinSamples(30)
    .Add('Sort/1000', @BenchSort)
    .AddParallel('Sort/Parallel', @BenchSort, 4)
    .Run;

  WriteLn(LResults.PrintToConsole);
end.
```

#### 构建方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `Add` | `(Name; Func: TBenchFunc): IBenchSuite` | 框架控制迭代 |
| `AddSimple` | `(Name; Func: TBenchSimpleFunc): IBenchSuite` | 无 context 的最简回调 |
| `AddWithSetup` | `(Name; Func; Setup: TBenchSetupFunc; Teardown: TBenchTeardownFunc)` | Setup 返回 `Pointer`，Teardown 释放 |
| `AddWhen` | `(Name; Func; Condition: Boolean)` | 条件添加 |
| `AddParallel` | `(Name; Func; Threads: Integer)` | 并行（memtrack 自动禁用） |
| `AddRange` | `(Name; ParamFunc; Params: array of Int64)` | 参数化 |
| `AddLoop` | `(Name; Func: TBenchLoopFunc)` | 用户循环，**无** context |
| `AddLoopWithContext` | `(Name; Func: TBenchLoopContextFunc)` | 用户循环 + SetBytes/Skip |
| `Clear` / `RemoveByName` / `TryRemoveByName` | | 管理条目 |

#### 配置方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `SetMinDuration` | `(Duration: TDuration)` | 最小持续时间 |
| `SetMaxIterations` | `(N: Int64)` | 最大迭代 |
| `SetMinSamples` | `(N: Integer)` | 最小采样 |
| `SetWarmupIters` | `(N: Integer)` | 固定热身 |
| `SetAdaptiveWarmup` | `(Enabled; CVThreshold; MaxIterations)` | 自适应预热 |
| `EnableMemoryTracking` / `DisableMemoryTracking` | | 内存追踪 |
| `CollectRawSamples` / `SetEntryCollectRawSamples` | | 原始样本 |
| `SetQuiet` / `SetFilter` / `SetOutput` / `SetOnProgress` | | 输出与过滤 |
| `SetTimeout` | `(Duration: TDuration)` | **suite 级**超时（非 Cardinal ms） |

#### 基线方法

| 方法 | 说明 |
|------|------|
| `AddBaseline` / `AddBaselineData` / `AddBaselines` | 内存基线 |
| `LoadBaseline` / `TryLoadBaseline` | 从文件加载 |

#### 执行

| 方法 | 说明 |
|------|------|
| `Run` | 顺序执行（默认） |
| `RunParallel` | 独立基准多线程跑（非 entry 内并行） |

### IBenchContext

| 方法 | 说明 |
|------|------|
| `SetBytes` / `AddBytes` | 每操作字节（吞吐） |
| `SetAllocs` / `AddAllocs` | 每操作分配 |
| `ResetTimer` / `StopTimer` / `StartTimer` | 计时控制 |
| `Skip` | 跳过当前基准 |
| `SetCustomMetric` / `GetCustomMetrics` | 自定义指标 |
| `Iterations` / `Elapsed` / `Name` | 只读属性；`Elapsed` 为 `TDuration` |

### IBenchResults

约 **77** 方法。常用子集：

| 类别 | 方法 |
|------|------|
| 报告 | `PrintToConsole`, `ToJSON/TSV/HTML/CSV/Benchstat/Summary/Markdown`, `SaveTo*` |
| 矩阵 | `CompareMultipleBaselines`, `ToMatrix*`, `SaveToMatrix*`（基线类型 `TBaselineData`） |
| 基线 | `SaveBaseline`, `AppendToTimeline`, `HasRegression`, `GetRegressionReport` |
| 对比 | `CompareTwoResults`（**MWU**，需 RawSamples）, `CompareGroups`（**启发式**，更弱） |
| 过滤/排序 | `FilterBy*`, `SortBy*`, `GetFastest/Slowest/TopN`, `GetStable/UnstableResults` |
| 聚合 | `GetSummaryStats`, `GetTotal*`, `GetPercentileStats`, `GetOutlierSummary` |
| 分组 | `GetGroups`, `GetGroupStats`, `To*_Grouped`, `GetGroupRegressionReport` |

**`GetTotal*` 语义**：
- `GetTotalIterations` / `GetTotalOutliers` / `GetTotalElapsed`：合理汇总
- `GetTotalOpsPerSec`：各基准 OpsPerSec **相加**（展示用，非严谨整体吞吐）
- `GetTotalBytesPerOp` / `GetTotalAllocsPerOp`：各基准 per-op **相加**，**通常无物理意义**

**分组规则**：首个 `/` 前为组名；无 `/` 时整名为组名。

**API 冻结（2026-07-19）**：默认不再向 `IBenchResults`/`IBenchSuite` 新增便捷 API。

## 核心类型

### TBenchResult

```pascal
TBenchResult = record
  Name: string;
  NsPerOp: Double;
  BytesPerOp: Int64;
  AllocsPerOp: Int64;
  MBPerSec: Double;
  StdDev: Double;
  Median: Double;
  Min, Max: Double;
  Samples: Integer;
  RawSamples: TDoubleArray;
  CustomMetrics: TCustomMetricArray;
  Executed: Boolean;
  Skipped: Boolean;
  SkipReason: string;
  Speedup: Double;
  Efficiency: Double;
end;
```

### TBenchStats

```pascal
TBenchStats = record
  Mean, StdDev, Median, Min, Max: Double;
  N: Integer;
  CV: Double;          // 变异系数 = StdDev / Mean
  Skewness, Kurtosis: Double;
  CI95Lower, CI95Upper: Double;
end;
```

### TBenchConfig

```pascal
TBenchConfig = record
  MinDurationNs: UInt64;
  MaxIterations: Int64;
  MinSamples: Integer;
  WarmupIters: Integer;
  TimeoutMs: Int64;
  TrackMemory: Boolean;
  Quiet: Boolean;
  AdaptiveWarmup: Boolean;
  WarmupCVThreshold: Double;
  WarmupMaxIterations: Integer;
end;
```

## 统计函数

### TBenchStatsAnalyzer

```pascal
var A: TBenchStatsAnalyzer;
begin
  A := TBenchStatsAnalyzer.Create;
  try
    LStats := A.ComputeStats(LSamples);
    LComparison := A.MannWhitneyU(LOldSamples, LNewSamples);
    LComparison := A.KolmogorovSmirnov(LOldSamples, LNewSamples);
    LPValue := A.WelchTTest(LOldSamples, LNewSamples);
  finally
    A.Free;
  end;
end;
```

### TAdvancedStats

```pascal
var A: TAdvancedStats;
begin
  A := TAdvancedStats.Create;
  try
    LMAD := A.MAD(LSamples);
    LCI := A.BootstrapCI(LSamples, 0.95, 10000);
    LCI := A.BCaBootstrapCI(LSamples, 0.95, 10000);
    LPValue := A.FisherPermutationTest(LOld, LNew, 10000);
    LD := A.CohenD(LOld, LNew);
  finally
    A.Free;
  end;
end;
```

## TBenchRunner 便利 API

```pascal
var B: TBenchRunner;
begin
  B := TBenchRunner.Create;
  try
    B.Run('HashMap.Put/N=100000', @BenchPut);
    B.Run('HashMap.Get(hit)/N=100000', @BenchGetHit);
    B.Summary;
  finally
    B.Free;
  end;
end.
```

## 类型回调签名

```pascal
TBenchFunc = procedure(const ACtx: IBenchContext);
TBenchParamFunc = procedure(const ACtx: IBenchContext; AParam: Int64);
TBenchLoopFunc = procedure(AN: Int64);
TBenchLoopContextFunc = procedure(const ACtx: IBenchContext; AN: Int64);
TBenchSimpleFunc = procedure;
TBenchSetupFunc = function: Pointer;
TBenchTeardownFunc = procedure(AData: Pointer);
```
