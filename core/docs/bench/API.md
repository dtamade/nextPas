# nextpas.core.bench — API 参考

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
| `Add` | `(Name: string; Func: TBenchFunc): IBenchSuite` | 添加简单基准 |
| `AddWithSetup` | `(Name: string; Func: TBenchFunc; Setup, Teardown: TProc): IBenchSuite` | 带初始化/清理 |
| `AddWhen` | `(Name: string; Func: TBenchFunc; Condition: Boolean): IBenchSuite` | 条件添加 |
| `AddParallel` | `(Name: string; Func: TBenchFunc; Threads: Integer): IBenchSuite` | 并行基准 |
| `AddRange` | `(Name: string; Func: TBenchParamFunc; Params: array of Int64): IBenchSuite` | 参数化基准 |
| `AddLoop` | `(Name: string; Func: TBenchLoopFunc): IBenchSuite` | 用户控制循环 |
| `AddLoopWithContext` | `(Name: string; Func: TBenchLoopContextFunc): IBenchSuite` | 带上下文的循环 |
| `Clear` | `: IBenchSuite` | 清空所有条目 |
| `RemoveByName` | `(Name: string): IBenchSuite` | 按名称移除 |

#### 配置方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `SetMinDuration` | `(Duration: TDuration): IBenchSuite` | 最小持续时间 |
| `SetMaxIterations` | `(N: Int64): IBenchSuite` | 最大迭代次数 |
| `SetMinSamples` | `(N: Integer): IBenchSuite` | 最小采样数 |
| `SetWarmupIters` | `(N: Integer): IBenchSuite` | 热身次数 |
| `EnableMemoryTracking` | `: IBenchSuite` | 启用内存追踪 |
| `DisableMemoryTracking` | `: IBenchSuite` | 禁用内存追踪 |
| `CollectRawSamples` | `: IBenchSuite` | 保存原始样本 |
| `SetQuiet` | `(Quiet: Boolean): IBenchSuite` | 安静模式 |
| `SetFilter` | `(Pattern: string): IBenchSuite` | 名称过滤（支持 `*` 和 `?`） |
| `SetTimeout` | `(Duration: TDuration): IBenchSuite` | 整体超时 |
| `SetAdaptiveWarmup` | `(Enabled: Boolean; CVThreshold, MaxIterations): IBenchSuite` | 自适应预热 |

#### 基线方法

| 方法 | 签名 | 说明 |
|------|------|------|
| `AddBaseline` | `(Name: string; NsPerOp: Double): IBenchSuite` | 添加基线 |
| `AddBaselines` | `(Baselines: array of TBaselineData): IBenchSuite` | 批量添加 |
| `LoadBaseline` | `(Path: string): IBenchSuite` | 从文件加载 |

#### 执行

| 方法 | 签名 | 说明 |
|------|------|------|
| `Run` | `: IBenchResults` | 执行所有基准并返回结果 |

### IBenchContext

基准函数通过此接口控制执行。

| 方法 | 签名 | 说明 |
|------|------|------|
| `SetBytes` | `(N: Int64)` | 设置每操作字节数（计算 MB/s） |
| `SetAllocs` | `(N: Int64)` | 设置每操作分配次数 |
| `ResetTimer` | | 重置计时器（排除 setup 时间） |
| `StopTimer` | | 暂停计时器 |
| `StartTimer` | | 恢复计时器 |
| `Skip` | `(Reason: string)` | 跳过当前基准 |
| `Iterations` | `: Int64` | 当前迭代次数 |
| `Elapsed` | `: UInt64` | 当前已用时间（ns） |

### IBenchResults

完整签名以 `nextpas.core.bench.intf` 为准。常用子集：

| 类别 | 方法 |
|------|------|
| 报告 | `PrintToConsole`, `ToJSON/TSV/HTML/CSV/Benchstat/Summary`, `SaveTo*` |
| 矩阵 | `CompareMultipleBaselines`, `ToMatrixReport/HTML/JSON/CSV`, `SaveToMatrix*` |
| 基线 | `SaveBaseline`, `AppendToTimeline`, `HasRegression`, `GetRegressionReport` |
| 对比 | `CompareTwoResults`（MWU on RawSamples）, `CompareGroups`（组内 NsPerOp 启发式） |
| 过滤/排序 | `FilterBy*`, `SortBy*`, `GetFastest/Slowest/TopN`, `GetStable/UnstableResults` |
| 聚合 | `GetSummaryStats`, `GetTotal*`, `GetPercentileStats`, `GetOutlierSummary` |
| 分组 | `GetGroups`, `GetGroupStats`, `To*_Grouped`, `SaveTo*_Grouped`, `GetGroupRegressionReport` |

**分组规则**：首个 `/` 前为组名；无 `/` 时整名为组名（与 `GetGroups` 一致）。

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
end.
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
TBenchParamFunc = procedure(const ACtx: IBenchContext; AValue: Int64);
TBenchLoopFunc = procedure(AN: Int64);
TBenchLoopContextFunc = procedure(AN: Int64; const ACtx: IBenchContext);
TBenchSimpleFunc = procedure;
```
