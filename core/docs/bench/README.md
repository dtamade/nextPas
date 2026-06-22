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

  WriteLn(LResults.ToConsole);
  LResults.SaveToJSON('bench-results.json');
end.
```

## Fluent Builder API

| 方法 | 说明 |
|------|------|
| `Add(Name, Func)` | 添加简单基准 |
| `AddWithSetup(Name, Func, Setup, Teardown)` | 带初始化/清理 |
| `AddWhen(Name, Func, Condition)` | 条件添加 |
| `AddParallel(Name, Func, Threads)` | 并行基准 |
| `AddRange(Name, Func, Params)` | 参数化基准（自动生成子基准） |
| `AddLoop(Name, Func)` | 用户控制循环 |
| `SetMinDuration(Duration)` | 最小持续时间 |
| `MaxIterations(N)` | 最大迭代次数 |
| `MinSamples(N)` | 最小采样数 |
| `WarmupIters(N)` | 热身次数 |
| `EnableMemoryTracking` | 启用内存追踪 |
| `CollectRawSamples` | 保存原始样本（用于 BoxPlot） |
| `AddBaseline(Name, NsPerOp)` | 添加基线 |
| `LoadBaseline(Path)` | 从文件加载基线 |
| `SetFilter(Pattern)` | 名称过滤 |

## IBenchContext 接口

基准函数通过 `IBenchContext` 控制执行：

| 方法 | 说明 |
|------|------|
| `SetBytes(N)` | 设置每操作字节数（计算 MB/s） |
| `SetAllocs(N)` | 设置每操作分配次数 |
| `ResetTimer` | 重置计时器（排除 setup 时间） |
| `Skip(Reason)` | 跳过当前基准 |
| `Iterations` | 当前迭代次数 |
| `Elapsed` | 当前已用时间 |

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
  → Console/JSON/TSV/HTML/SVG
  → 基线对比 (Ratio + Welch's t-test)
```

## 设计决策

### 统计双轨制

- **TBenchStatsAnalyzer** (class/interface): runner 走的主路径，用 KahanSum + 两遍方差
- **TAdvancedStats** (record): 独立工具，轻量级直接使用

保持两套的理由：不同抽象层、不同算法选择、API 迁移成本高于收益。

### BootstrapCI 固定种子

使用固定种子 12345 保证可复现性。Bootstrap 质量取决于迭代次数（默认 10000），而非种子随机性。参考 `scipy.stats.bootstrap` 的 `random_state` 设计。

### 并行基准限制

并行模式自动禁用内存追踪（MemoryManager hook 全局唯一，无法线程安全地与并行执行共存）。会输出 WARNING 提示。

## 测试

```bash
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
| `NEXTPAS_BENCH_NO_MEMTRACK` | 禁用内存追踪（=1） |
