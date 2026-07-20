# nextpas.core.bench

基准测试框架模块。提供 Fluent Builder API 的基准测试套件、统计分析、基线管理、跨语言对比和报告生成。

> **Lane 状态：Maintenance Idle（2026-07-20 · B43；B44 卫生包）**
>
> - API 冻结；消费 checklist **22** 模块 C1–C5 全绿；scorecard 子集 **11** track
> - 默认 gate：**22** suites（`core/tests/nextpas.core.bench/Makefile` PROJECTS）
> - 日常：只响应回归、明确授权的小修（文档/卫生/契约口径可做）
> - **不**默认排期：EBR `BenchRun`（见 [ebr-benchrun-design-note.md](ebr-benchrun-design-note.md)）、全量 SCORECARD、门面大拆
> - **值班 / Landing 纪律**（含 **FF 后必 push**）：[LANE-DUTY.md](LANE-DUTY.md)
> - **B45**：Canonical API、`BenchBlackBox*`、官方示例无 SysUtils
> - **B46**：`core/benchmarks/nextpas.core.*` 去掉直连 FPC RTL（白名单：platform-comparison）

## Canonical API（唯一推荐路径）

**默认只用** `TBenchSuite` Fluent Builder：

```pascal
uses nextpas.core.bench, nextpas.core.time.base;

procedure Hot(const ACtx: IBenchContext);
var L: Int64; I: Integer;
begin
  L := 0;
  for I := 1 to 1000 do Inc(L, I);
  BenchBlackBoxInt64(L);  { 防优化；对标 criterion black_box }
end;

var R: IBenchResults;
begin
  R := TBenchSuite.Create('MyMod')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('MyMod/Hot', @Hot)
    .Run;
  WriteLn(R.PrintToConsole);  { System.WriteLn；勿 uses SysUtils }
end.
```

| 场景 | 用 | 勿用 |
|------|----|------|
| 常规基准 | `Add` / `AddWithSetup` / `AddRange` | 裸 `GetTickCount` 循环 |
| 用户控制 N 次循环且要 bytes/skip | **`AddLoopWithContext`** | 无 context 的 `AddLoop`（无法 SetBytes/Skip） |
| 并行吞吐 | `AddParallel` | 并行时期望 memtrack（会自动禁用 + WARNING） |
| 防优化 | `BenchBlackBoxInt64/Ptr/Bytes` | 假 `WriteLn` 副作用 |
| 目录/文件 | `nextpas.core.fs.ForceDirectories` + `SaveToJSON('build/...')` | `uses SysUtils` |

**Advanced（非默认）**：`TBenchRunner`（便利单测）、`TBenchRun`（原子多线程收集）。新代码默认不要选这两条，除非明确需要。

**错误消息约定**：参数类异常类型为 `EBenchInvalidParam`，消息含 `TBenchSuite.*` / `TBenchResults.*` 前缀，便于 CI 文本匹配（不另加 ErrorCode 枚举，避 API 膨胀）。

## 消费侧（写模块 bench 的人）

- **[consumer-guide.md](consumer-guide.md)** — 最小配方、命名、`IBenchResults` 读侧、仓库布局
- **[consumer-checklist.md](consumer-checklist.md)** — 模块 bench 抽检表（**22** 模块；C3 Quiet/短时/JSON 模板）
- **[LANE-DUTY.md](LANE-DUTY.md)** — lane 值班边界、Landing 硬纪律、回归证据怎么记
- 示例：`core/examples/bench/`、`core/examples/nextpas.core.bench/`
- 模块 bench 样例：`core/benchmarks/nextpas.core.*/`
- 跨语言子集：`scorecard-subset-2026-07-19.md`（**11** track，含 binsearch/lookup）
- EBR×BenchRun：**未立项** — [ebr-benchrun-design-note.md](ebr-benchrun-design-note.md)
- 历史文档索引：[archive/README.md](archive/README.md)

### 仓库一键入口

```bash
# 框架全部 focused suites（22 个 PROJECTS）
make bench-module-test

# 轻量 scorecard smoke（inttohex；需 fpc + go）
make bench-scorecard-smoke

# 子集脚本（可 --tracks a,b 或 --summary）
bash core/docs/bench/scripts/run-scorecard-subset.sh --list
bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks inttohex --summary

# checklist 模块样例（产物进 core/build/projects/...，JSON 在工程目录 build/）
make -C core/benchmarks/nextpas.core.hash/bench_hash run
```

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
nextpas.core.bench.run         ← 线程安全执行器（原子结果收集，EBR 就绪）
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
| `AddLoop(Name, Func)` | 用户控制循环（**无** IBenchContext；优先 `AddLoopWithContext`） |
| `AddLoopWithContext(Name, Func)` | 用户控制循环且可 SetBytes/Skip/ResetTimer |
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
| `SetTimeout(Duration)` | 整体超时（TDuration，超时后跳过剩余基准） |

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
| `ToJSON` / `ToTSV` / `ToHTML` / `ToCSV` / `ToSummary` | 各格式报告字符串 |
| `SaveToJSON/HTML/TSV/CSV/Markdown(Path)` | 保存到文件 |
| `CompareTwoResults(A, B)` | 两个结果 Mann-Whitney U 对比（RawSamples） |
| `CompareMultipleBaselines(Baselines)` | 多基线对比矩阵 |
| `ToMatrixReport/HTML/JSON/CSV(Baselines)` | 多基线矩阵报告 |
| `SaveToMatrixJSON/HTML/CSV(Path, Baselines)` | 矩阵报告落盘 |
| `SaveBaseline(Path, GitHash)` | 保存当前结果为命名基线 |
| `AppendToTimeline(Path)` | 追加到 JSONL 时间线 |
| `HasRegression(Threshold)` / `GetRegressionReport(Threshold)` | 回归检测与报告 |

### IBenchResults 结果查询 / 聚合（Round 40–62）

分组规则：名称中**首个 `/` 前**为组名；无 `/` 时整名为组名。

| 方法 | 说明 |
|------|------|
| `GetFastest` / `GetSlowest` / `GetTopN` | 极值与 TopN |
| `GetStableResults` / `GetUnstableResults` | 按 CV 阈值筛选 |
| `FilterByPrefix/Suffix/Substring/NamePattern` | 名称过滤 |
| `FilterByNsPerOpRange` / `FilterByStdDevRange` | 数值范围过滤 |
| `SortByNsPerOp` / `SortByOpsPerSec` / `SortByCustomMetric` | 排序 |
| `GetSummaryStats` / `GetPercentileStats` / `GetOutlierSummary` | 摘要统计 |
| `GetTotalOpsPerSec` / `GetTotalIterations` / `GetTotalElapsed` 等 | 跨结果聚合 |
| `GetGroups` / `GetGroupStats` | 分组枚举与组内聚合 |
| `ToJSON/Markdown/HTML_Grouped` + `SaveTo*_Grouped` | 分组导出 |
| `CompareGroups(A, B)` | 两组 NsPerOp 启发式对比（非 MWU） |
| `GetGroupRegressionReport(Threshold)` | 分组两两回归报告 |

> **API 冻结（2026-07-19）**：默认不再向 `IBenchResults` / `IBenchSuite` 堆叠便捷方法；
> 后续增量优先落在 report/stats 子单元或文档化的明确缺口修复。

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

## TBenchRun 线程安全执行器

`TBenchRun` 是 `TBenchRunner` 的线程安全替代品，使用原子计数器实现无锁结果收集。

```pascal
uses
  nextpas.core.bench;

var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
begin
  LRun := TBenchRun.Create;
  try
    LResults := LRun.RunAll([Entry1, Entry2, Entry3], 4); // 4 工作线程
  finally
    LRun.Free;
  end;
end.
```

| 方法 | 说明 |
|------|------|
| `Create` | 创建执行器（默认配置） |
| `Create(Config)` | 创建执行器（自定义配置） |
| `RunAll(Entries, ThreadCount)` | 并发运行所有基准，返回结果数组 |
| `SubmitResult(Ptr)` | 无锁提交堆分配结果 |
| `CollectResults(out Results)` | 收集所有已提交结果 |
| `Count` | 当前已提交结果数 |

**与 TBenchRunner 的区别**:
- `TBenchRun` 线程安全：多线程可并发提交结果
- `TBenchRunner` 非线程安全：单线程使用

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
| 测试套件 | **22**（Makefile PROJECTS；见 goal-tree） |
| 框架级测试 | **~504** |
| 框架 | 全部使用 `nextpas.core.test` |
| heaptrc | **22/22** 套件全部启用 -gh，零泄漏 |
| NaN 安全 | `SortDoubleArray` 先分区 NaN 再排序 |
| 统计防护 | `Variance`/`Skewness`/`Kurtosis` NaN/Inf guard |
| `GetData` 语义 | 返回 `Copy(FData)` 独立副本 |
| 自适应预热 | `AdaptiveWarmup` 根据 CV 阈值自动停止预热 |

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

## 示例

查看 `core/examples/bench/` 目录中的完整示例：

- `quick_start.pas` - 5 分钟入门
- `advanced_stats.pas` - 高级统计
- `parallel_benchmark.pas` - 并行基准
- `ci_integration.pas` - CI 集成
- `custom_metrics.pas` - 自定义指标
- `performance_tuning.pas` - 性能调优

## 教程

- [交互式教程](tutorial.md) - 从入门到精通
- [最佳实践指南](best-practices.md) - 编写可靠的基准测试

## CI 集成

### GitHub Actions

项目已配置 GitHub Actions 自动化基准测试：

- **主分支**: 自动生成基线并上传
- **PR**: 自动与基线比较，检测回归
- **报告**: 自动生成 benchmark 报告并评论 PR

### 本地 CI 脚本

```bash
# 运行所有测试
./scripts/bench-ci.sh test

# 生成基线
./scripts/bench-ci.sh baseline

# 与基线比较
./scripts/bench-ci.sh compare

# 自定义基线文件
./scripts/bench-ci.sh baseline my-baseline.json
./scripts/bench-ci.sh compare my-baseline.json
```

### 回归检测

```bash
# 自动检测 5% 回归
./scripts/bench-ci.sh compare bench-baseline.json

# 如果检测到回归，脚本会：
# 1. 输出详细的比较结果
# 2. 返回非零退出码
# 3. 生成 JSON 报告供 CI 系统解析
```

## 测试

```bash
# 全量测试（22 个 PROJECTS，见 goal-tree.md）
make -C core/tests/nextpas.core.bench clean test

# 模块自身 micro-bench
make -C core/tests/nextpas.core.bench bench
# 或：make -C core/benchmarks/nextpas.core.bench clean test

# 常用 suite
make -C core/tests/nextpas.core.bench/test_bench_stats clean test
make -C core/tests/nextpas.core.bench/test_bench_runner clean test
make -C core/tests/nextpas.core.bench/test_bench_integration clean test
make -C core/tests/nextpas.core.bench/test_bench_results_api clean test
make -C core/tests/nextpas.core.bench/test_bench_report clean test
make -C core/tests/nextpas.core.bench/test_bench_xlang clean test
make -C core/tests/nextpas.core.bench/test_bench_baseline clean test
```

权威状态见 `goal-tree.md`（B0–B27）。历史调研文档（`bench-usability-*`、`FINAL_REPORT.md`）仅作归档，不以之为当前测试计数。

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

## 跨语言基准对照

`benchmarks/` 目录包含 Go/Rust/C/Pascal 四语言基准测试：

```bash
# 运行所有语言基准测试并生成对比表格
cd benchmarks && ./run_all.sh

# 单独运行
cd benchmarks/go && go run main.go
cd benchmarks/rust && cargo run --release
cd benchmarks/c && gcc -O2 main.c -lm && ./a.out
cd benchmarks/pascal && fpc -O2 bench_cross_language.lpr && ./bench_cross_language
```

对比结果见 `benchmarks/COMPARISON.md`。

## 线程安全

`TBenchSuite` 和 `TBenchRunner` **不是线程安全的**。所有方法必须从单个拥有线程调用。

并行基准通过 `AddParallel` 注册，框架内部管理线程池，不需要调用方自行管理线程。

如需并发执行多个套件，每个套件必须拥有独立的 `TBenchSuite` 实例。
