# nextpas.core.bench

基准测试框架模块。提供 Fluent Builder API 的基准测试套件、统计分析、基线管理、跨语言对比和报告生成。

## 模块结构

```
L1 依赖层：仅依赖 L0（base, exception, platform.time）

nextpas.core.bench.base        ← 基本类型、排序（IntroSort）
nextpas.core.bench.intf        ← 接口定义（IBenchSuite/IBenchResults）、异常
nextpas.core.bench.stats       ← 基础统计（Mean/Median/StdDev/t-distribution）
nextpas.core.bench.stats.advanced ← 高级统计（异常值检测/CI/bootstrap/正态性）
nextpas.core.bench             ← 门面：TBenchSuite/TBenchResults
nextpas.core.bench.baseline    ← 基线管理（JSON 序列化/回归检测）
nextpas.core.bench.memtrack    ← 内存追踪（MemoryManager hook + 原子计数）
nextpas.core.bench.parallel    ← 并行基准（TThread + 聚合结果）
nextpas.core.bench.runner      ← 执行器（校准/采样/统计流水线）
nextpas.core.bench.report      ← 报告生成（Console/JSON/TSV/HTML/SVG）
nextpas.core.bench.xlang       ← 跨语言解析（Go/Rust/FPC 输出）
```

## 快速开始

```pascal
uses
  nextpas.core.bench, nextpas.core.time.base;

procedure BenchSort(const ACtx: IBenchContext);
var
  LData: array[0..999] of Integer;
begin
  // 排序操作
end;

var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('MySuite')
    .SetMinDuration(TDuration.FromSeconds(2))
    .SetMinSamples(30)
    .Add('Sort/1000', @BenchSort)
    .Run;

  WriteLn(LResults.PrintToConsole);
  LResults.SaveToJSON('bench-results.json');
end.
```

使用 `{$modeswitch anonymousfunctions}` 时也可以用 lambda：

```pascal
{$modeswitch anonymousfunctions}

LResults := TBenchSuite.Create('MySuite')
  .Add('Sort/1000', procedure(const ACtx: IBenchContext)
    begin
      // 排序操作
    end)
  .Run;
```

## Fluent Builder API

| 方法 | 说明 |
|------|------|
| `Add(Name, Func)` | 添加简单基准 |
| `AddWithSetup(Name, Func, Setup, Teardown)` | 带初始化/清理 |
| `AddWhen(Name, Func, Condition)` | 条件添加 |
| `AddParallel(Name, Func, Threads)` | 并行基准 |
| `AddRange(Name, Func, Params)` | 参数化基准（自动生成子基准） |
| `AddLoop(Name, Func)` | 用户控制循环（见下方限制） |
| `Clear` | 清空所有已注册条目 |
| `RemoveByName(Name)` | 按名称移除条目 |
| `SetMinDuration(Duration)` | 最小持续时间 |
| `SetMaxIterations(N)` | 最大迭代次数 |
| `SetMinSamples(N)` | 最小采样数 |
| `SetWarmupIters(N)` | 热身次数 |
| `EnableMemoryTracking` | 启用内存追踪 |
| `DisableMemoryTracking` | 禁用内存追踪 |
| `CollectRawSamples` | 保存原始样本（用于 BoxPlot） |
| `SetQuiet(Quiet)` | 安静模式 |
| `AddBaseline(Name, NsPerOp)` | 添加基线 |
| `AddBaselines(ArrayOfBaselines)` | 批量添加基线 |
| `LoadBaseline(Path)` | 从文件加载基线 |
| `SetFilter(Pattern)` | 名称过滤 |
| `SetTimeout(Ms)` | 整体超时（超时后跳过剩余基准） |

### IBenchContext 接口

基准函数通过 `IBenchContext` 控制执行：

| 方法 | 说明 |
|------|------|
| `SetBytes(N)` | 设置每操作字节数（计算 MB/s） |
| `SetAllocs(N)` | 设置每操作分配次数 |
| `ResetTimer` | 重置计时器（排除 setup 时间） |
| `StopTimer` | 暂停计时器（保留已累计时间） |
| `StartTimer` | 恢复计时器 |
| `Skip(Reason)` | 跳过当前基准 |
| `Iterations` | 当前迭代次数 |
| `Elapsed` | 当前已用时间 |

> **注意**: `AddLoop` 的回调签名是 `TBenchLoopFunc = procedure(AN: Int64)`，不接收 `IBenchContext`。
> 因此 loop 基准无法使用 `SetBytes`/`SetAllocs`/`Skip`/`ResetTimer`。
> 如需上下文控制，请使用 `Add` 或 `AddWithSetup`。

### IBenchResults 输出方法

| 方法 | 说明 |
|------|------|
| `PrintToConsole` | 返回格式化的控制台表格字符串（纯函数，不写 stdout） |
| `ToBenchstat` | Go benchstat 兼容格式（tab-separated，可直接用 `benchstat` 分析） |
| `ToJSON` | JSON 格式（含环境信息、统计详情） |
| `ToTSV` | TSV 格式（含状态/跳过原因） |
| `ToHTML` | 自包含 HTML（内联 CSS/SVG 图表/箱线图） |
| `SaveToJSON(Path)` | 保存 JSON 到文件 |
| `SaveToHTML(Path)` | 保存 HTML 到文件 |
| `SaveToTSV(Path)` | 保存 TSV 到文件 |
| `CompareTwoResults(A, B)` | 两个结果 Mann-Whitney U 对比 |
| `CompareMultipleBaselines(Baselines)` | 多基线对比矩阵（超越 Go/Rust） |
| `ToMatrixReport(Baselines)` | 多基线矩阵 Console 报告 |
| `ToMatrixHTML(Baselines)` | 多基线矩阵 HTML（含 B/op + allocs/op） |
| `ToMatrixJSON(Baselines)` | 多基线矩阵 JSON（CI 可消费） |
| `SaveBaseline(Path, GitHash)` | 保存当前结果为命名基线 |
| `AppendToTimeline(Path)` | 追加到 JSONL 时间线 |
| `HasRegression(Threshold)` | 检测回归 |

## TBenchRunner 便利 API

对于简单的基准场景，`TBenchRunner` 提供了 `Run` + `Summary` 便利方法：

```pascal
uses
  nextpas.core.bench;

var
  B: TBenchRunner;
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

| 方法 | 说明 |
|------|------|
| `Run(Name, LoopFunc)` | 运行单个基准并累积结果。`LoopFunc: TBenchLoopFunc = procedure(AN: Int64)` |
| `Summary` | 打印所有已累积结果的摘要到控制台 |
| `RunOne(Name, Func)` | 运行单个基准返回 `TBenchResult`（`Func: TBenchFunc`） |
| `RunAll(Entries)` | 批量运行多个 `TBenchEntry` |
| `SetFilter(Pattern)` | 名称过滤（子串匹配） |
| `Config` | 读写 `TBenchConfig` 配置 |

## 统计流水线

```
校准 (CalibrateEntryIterations)
  → 探测迭代次数使总时长 ≥ MinDuration
  → 指数增长：100 → 1000 → 10000 → ...

采样 (CollectEntrySamples)
  → MinSamples 次独立执行
  → 每次记录 TotalNs / Iterations = ns/op

统计 (ComputeStats)
  → KahanSum 均值、t 分布 CI、Tukey 异常值
  → IntroSort 排序 → Percentile/P50/P95/P99

输出 (TBenchResults)
  → Console/JSON/TSV/HTML/SVG/Benchstat
  → 基线对比 (Ratio + Mann-Whitney U / Welch's t-test)
  → 两结果对比 (CompareTwoResults + Mann-Whitney U)
  → 聚合指标 (GeometricMean 几何均值)
```

## 设计决策

### 统计双轨制

- **TBenchStatsAnalyzer** (class/interface): runner 走的主路径，用 KahanSum + 单遍方差 (PF-01)
- **TAdvancedStats** (class): 独立工具，轻量级直接使用

保持两套的理由：不同抽象层、不同算法选择、API 迁移成本高于收益。

### BootstrapCI 固定种子

使用固定种子 12345 保证可复现性。Bootstrap 质量取决于迭代次数（默认 10000），而非种子随机性。参考 `scipy.stats.bootstrap` 的 `random_state` 设计。

### 并行基准限制

并行模式自动禁用内存追踪（MemoryManager hook 全局唯一，无法线程安全地与并行执行共存）。会输出 WARNING 提示。

## 质量保证

| 指标 | 状态 |
|------|------|
| 测试套件 | 15 |
| 框架级测试 | ~296 |
| 框架 | 全部使用 `nextpas.core.test` |
| heaptrc | 15/15 套件全部启用 -gh，零泄漏 |
| NaN 安全 | `SortDoubleArray` 先分区 NaN 再排序 |
| 统计防护 | `Variance`/`Skewness`/`Kurtosis` NaN/Inf guard |
| `GetData` 语义 | 返回 `Copy(FData)` 独立副本 |

## 竞争力矩阵（vs Go/Rust）

| 能力 | nextpas | Go benchstat | Rust criterion |
|------|---------|-------------|----------------|
| Mann-Whitney U | ✅ | ✅ | ✅ |
| 几何均值聚合 | ✅ | ✅ | ❌ |
| OLS 线性回归 | ✅ | ❌ | ✅ |
| StopTimer/StartTimer | ✅ | ✅ | ❌ |
| 多基线对比矩阵 | ✅ | ❌ | ❌ |
| 内存+性能联合报告 | ✅ | 部分 | ❌ |
| 分布直方图 | ✅ | ❌ | ✅ |
| 基线对比图 | ✅ | ❌ | ✅ |
| CI 集成模板 | ✅ | ❌ | ❌ |
| 时间线追踪 | ✅ | ❌ | ✅ |
| 自适应测量 | ✅ | ❌ | ✅ |
| Kahan 求和 | ✅ | ❌ | ❌ |
| Shapiro-Wilk 正态性（启发式） | ✅ | ❌ | ❌ |
| 内存追踪集成 | ✅ | ❌ | ❌ |
| 并行基准 | ✅ | ❌ | ❌ |

## 测试

```bash
# 全量测试（15 个 suite）
make -C core/tests/nextpas.core.bench test

# 运行 bench 模块自身的基准测试
make -C core/tests/nextpas.core.bench bench

# 单个 suite
make -C core/tests/nextpas.core.bench/test_bench_stats clean test
make -C core/tests/nextpas.core.bench/test_bench_stats_advanced clean test
make -C core/tests/nextpas.core.bench/test_bench_runner clean test
make -C core/tests/nextpas.core.bench/test_bench_integration clean test
make -C core/tests/nextpas.core.bench/test_bench_report clean test
make -C core/tests/nextpas.core.bench/test_bench_xlang clean test
make -C core/tests/nextpas.core.bench/test_bench_baseline clean test
make -C core/tests/nextpas.core.bench/test_bench_memtrack clean test
make -C core/tests/nextpas.core.bench/test_bench_parallel clean test
make -C core/tests/nextpas.core.bench/test_bench_parallel_heaptrc clean test
make -C core/tests/nextpas.core.bench/test_bench_parallel_memtrack_heaptrc clean test
make -C core/tests/nextpas.core.bench/test_bench_invalid_parameters_heaptrc clean test
make -C core/tests/nextpas.core.bench/test_bench_matrix clean test
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `NEXTPAS_BENCH_FILTER` | 名称过滤（子串匹配） |
| `NEXTPAS_BENCH_MAX_ITERS` | 最大迭代次数 |
| `NEXTPAS_BENCH_MIN_DURATION` | 最小持续时间（ns） |
| `NEXTPAS_BENCH_MIN_SAMPLES` | 最小采样数 |
| `NEXTPAS_BENCH_WARMUP` | 热身次数 |
| `NEXTPAS_BENCH_QUIET` | 安静模式（=1） |
| `NEXTPAS_BENCH_MEMTRACK` | 内存追踪（=0 禁用，默认启用） |

## 线程安全

`TBenchSuite` 和 `TBenchRunner` **不是线程安全的**。所有方法必须从单个拥有线程调用。

并行基准通过 `AddParallel` 注册，框架内部管理线程池，不需要调用方自行管理线程。

如需并发执行多个套件，每个套件必须拥有独立的 `TBenchSuite` 实例。
