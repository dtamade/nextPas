# nextpas.core.bench — 架构文档

> **最后更新**: 2026-07-21（T1：依赖图与行数对齐实况）

## 模块定位

**Registry**: `tooling` / `focused-runtime`
**分层口径**: 文档历史曾写「纯 L1→L0」；**实况**为 tooling harness，在 L0 之外允许 **已批准的** I/O、并发与容器依赖（见下表）。勿按「严格 L1」做依赖审计。

## 源文件清单

| 文件 | 行数（约，2026-07-21） | 职责 |
|------|-----------|------|
| `bench.base.pas` | ~1100 | 核心类型、常量、GlobMatch、BlackBox、Xoroshiro |
| `bench.intf.pas` | ~900 | 接口（IBenchSuite / IBenchResults≈77 方法 / IBenchContext） |
| `bench.pas` | ~3280 | 门面：TBenchSuite + TBenchResults（**已膨胀，API 冻结**） |
| `bench.runner.pas` | ~1430 | TBenchContext + TBenchRunner；校准/预热/采样 |
| `bench.stats.pas` | ~1250 | Welford、MWU、K-S、OLS、贝叶斯入口 |
| `bench.stats.advanced.pas` | ~1130 | MAD、Bootstrap/BCa、偏度/峰度 |
| `bench.report.pas` | ~1180 | Console/JSON/TSV/HTML/Matrix |
| `bench.baseline.pas` | ~490 | 基线 JSON、时间线 |
| `bench.parallel.pas` | ~300 | TThread 并行基准 |
| `bench.run.pas` | ~310 | TBenchRun 原子结果收集 |
| `bench.memtrack.pas` | ~380 | MemoryManager hook |
| `bench.xlang.pas` | ~570 | Go/Rust/FPC 输出解析 |
| `bench.test_helpers.pas` | ~90 | 测试辅助 |

## 真实依赖（勿再写「仅 L0」）

```
bench.base          ← exception, time.base, io.linewriter
bench.intf          ← bench.base, time.base, exception, io.linewriter
bench.stats         ← bench.base, bench.intf
bench.stats.advanced← bench.base, platform (+ impl atomic)
bench.memtrack      ← system.memmanager
bench.run           ← atomic, platform.thread, bench.*
bench.parallel      ← system.classes (TThread), bench.*, platform
bench.runner        ← bench.*, platform.time, time.base
bench.baseline      ← fs, fs.util, json, json.writer, platform.time, text.*
bench.report        ← bench.* (+ impl fs, json.writer)
bench (facade)      ← bench.* 子单元; impl: fs, json.writer, collections.hashmap, text.*, platform.time
```

**说明**:
- `fs`/`json`：基线与报告落盘
- `atomic`/`platform.thread`：TBenchRun 并发收集
- `system.classes`：并行路径 `TThread`
- `collections.hashmap`：GenerateComparisons O(n) 名称匹配

## 门面策略

- `bench.pas` 是用户唯一入口；TBenchResults 查询/聚合 API 已使门面 >3k 行。
- **2026-07-19 起默认冻结** 向 `IBenchResults`/`IBenchSuite` 新增公共便捷方法。
- 后续增量优先：`bench.report` / `bench.stats` 子单元，或明确 bugfix。
- 分组内部 helper：`ExtractGroupName` / `CollectGroupResults` / `CollectGroupNsPerOp`。

## 数据流

```
TBenchSuite (fluent builder)
  ↓ .Run()
TBenchRunner.Execute()
  ├── CalibrateEntryIterations()
  ├── WarmupEntry()                 ← 自适应预热（Welford CV）
  └── ExecuteSequentialEntry()
        ├── TBenchContext
        ├── entry.Func(ctx) × N
        ├── TBenchStatsAnalyzer.ComputeStats
        └── → TBenchResult
  ↓
TBenchResults
  ↓ PrintToConsole / ToJSON / ToHTML / ToMatrix*
TBenchReportGenerator
```

## 执行路径

1. **Loop** (`AddLoop` / `AddLoopWithContext`): 用户控制循环
2. **普通** (`Add`): 框架控制迭代
3. **并行** (`AddParallel`): 多线程；并行时 memtrack 自动禁用

## 统计流水线

```
原始样本 (Double[])
  ↓ ComputeStats (Welford)
TBenchStats
  ↓ Mann-Whitney U / K-S / Bootstrap
TBenchComparison / CI
```

**注意**: `CompareTwoResults` 用 MWU（需 RawSamples）；`CompareGroups` 仅组均值 + 启发式 p-value，严格性更弱。

## 语义陷阱（读侧）

| API | 含义 |
|-----|------|
| `GetTotalIterations` / `GetTotalOutliers` | 合理求和 |
| `GetTotalOpsPerSec` | 各基准 OpsPerSec **相加**（非「整体吞吐」的严谨定义） |
| `GetTotalBytesPerOp` / `GetTotalAllocsPerOp` | 各基准 per-op 指标 **相加**，**通常无物理意义**；仅作汇总展示 |

## 超时模型

- **suite 级**：`TBenchSuite.SetTimeout(TDuration)` → `TBenchConfig.TimeoutMs`；条目间与条目完成后跳过剩余。
- **无 per-entry Timeout**：`TBenchEntry` 不再含 `TimeoutMs`（B48/T2 删除半成品字段）。
- 采样循环内 `CollectEntrySamples` 仍接受可选截止参数，当前 `RunOne` 传 0。
