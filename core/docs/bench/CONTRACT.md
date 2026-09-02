# nextpas.core.bench 代码契约

**模块路径**：`core/src/nextpas.core.bench*.pas`
**层级**：tooling harness（registry `tooling`）；**非**「纯 L1→L0」。真实依赖见 [ARCHITECTURE.md](ARCHITECTURE.md)（fs/json/atomic/platform.thread/system.memmanager 等）。
**最后更新**：2026-08-31（audit 闭环：统计诚实、timeout 采样中断、platform parallel、memtrack）
**权威状态**：`goal-tree.md`；API 冻结见 README；truth = focused-runtime

### 0.0 统计与超时契约（2026-07-26）

| 项 | 契约 |
|----|------|
| `CompareGroups.HasStatisticalTest` | **始终 False**（组均值启发式） |
| `CompareTwoResults` 无 RawSamples | `HasStatisticalTest=False`，`IsSignificant=False` |
| `GetTotalOpsPerSec` 等 | 各 entry **算术相加**，非整体吞吐 |
| `SetTimeout` | suite 级；**传入采样循环**；单 entry 超时中止 |
| parallel | `platform.thread` only；**禁止** `system.classes`/`TThread` |
| memtrack | 进程级 MM hook；`TryEnable*`；heaptrc 下 soft-skip；单 suite/进程 |

### 0.0b Advanced 路径

- `TBenchRunner` / `TBenchRun`：**非默认**；新代码优先 `TBenchSuite`。
- EBR×BenchRun：**明确不实现**（见 ebr-benchrun-design-note.md）。

### 0.1 测量辅助（base / 门面 re-export）

| 符号 | 说明 |
|------|------|
| `BenchBlackBoxInt64` | 防 DCE；热路径末尾混入全局 sink |
| `BenchBlackBoxPtr` | 指针 sink |
| `BenchBlackBoxBytes` | 字节块 sink |
| `BenchBlackBoxSink` / `BenchBlackBoxReset` | 测试读/清 sink |

### 0.2 错误消息约定

- 参数非法：`EBenchInvalidParam`，消息形如 `TBenchSuite.SetMinSamples: sample count must be > 0`
- 基线缺失：`EBenchBaselineNotFound`
- 其它：`EBenchError`（含路径 IO 包装）
- **不**新增公开 ErrorCode 枚举（Idle / API 冻结）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bench.base | 类型/常量/GlobMatch/Xoroshiro 等 |
| bench.intf | IBenchSuite / IBenchResults / IBenchContext |
| bench.runner | TBenchContext + TBenchRunner |
| bench.parallel | 并行基准 |
| bench.stats / stats.advanced | 统计与高级统计 |
| bench.baseline | 基线 JSON / 时间线 |
| bench.memtrack | 内存追踪 |
| bench.report | 报告生成 |
| bench.xlang | 跨语言输出解析 |
| bench.run | 线程安全执行器 |
| bench.pas | 门面（TBenchSuite / TBenchResults） |

**符号纪律**：名称匹配必须用 `bench.base.GlobMatch`；字符串工具优先 `text.conv.*` 限定，避免与 `fs.GlobMatch` 等冲突。

### 1.2 核心接口

```pascal
IBenchContext = interface
  ['{B7A3D2E1-4C5F-6A7B-8C9D-0E1F2A3B4C5D}']
  procedure SetBytes(ABytes: Int64);
  procedure SetAllocs(AAllocs: Int64);
  procedure AddBytes(ABytes: Int64);
  procedure AddAllocs(AAllocs: Int64);
  procedure ResetTimer;
  procedure StopTimer;
  procedure StartTimer;
  procedure Skip(const AReason: string);
  function GetIterations: Int64;
  function GetElapsed: TDuration;
  function GetBytesPerOp: Int64;
  function GetAllocsPerOp: Int64;
  function GetName: string;
  property Iterations: Int64 read GetIterations;
  property Elapsed: TDuration read GetElapsed;
  property BytesPerOp: Int64 read GetBytesPerOp;
  property AllocsPerOp: Int64 read GetAllocsPerOp;
  property Name: string read GetName;
end;

IBenchSuite = interface
  ['{A1B2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
  function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
  function AddWithSetup(const AName: string; AFunc: TBenchFunc;
    ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
  function AddWhen(const AName: string; AFunc: TBenchFunc;
    ACondition: Boolean): IBenchSuite;
  function AddParallel(const AName: string; AFunc: TBenchFunc;
    AThreads: Integer): IBenchSuite;
  function AddRange(const AName: string; AFunc: TBenchParamFunc;
    const AParams: array of Int64): IBenchSuite;
  function AddRange(const AName: string; AFunc: TBenchParamFunc;
    const AParams: array of Int64;
    ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
  function AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;
  function AddLoopWithContext(const AName: string; AFunc: TBenchLoopContextFunc): IBenchSuite;
  function Clear: IBenchSuite;
  function RemoveByName(const AName: string): IBenchSuite;
  function SetMinDuration(ADuration: TDuration): IBenchSuite;
  function SetMaxIterations(AIters: Int64): IBenchSuite;
  function SetMinSamples(ACount: Integer): IBenchSuite;
  function SetWarmupIters(ACount: Integer): IBenchSuite;
  function EnableMemoryTracking: IBenchSuite;
  function DisableMemoryTracking: IBenchSuite;
  function CollectRawSamples: IBenchSuite;
  function SetQuiet(AQuiet: Boolean): IBenchSuite;
  function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
  function AddBaseline(const AName: string; ANsPerOp: TDuration): IBenchSuite;
  function AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;
  function LoadBaseline(const APath: string): IBenchSuite;
  function SetFilter(const AFilter: string): IBenchSuite;
  { 真实签名为 TDuration（非 Cardinal 毫秒） }
  function SetTimeout(ADuration: TDuration): IBenchSuite;
  function Run: IBenchResults;
  { 另有：AddSimple / TryRemoveByName / TryLoadBaseline / RunParallel /
    SetAdaptiveWarmup / SetOnProgress / SetOutput / SetEntryCollectRawSamples 等 — 见 intf }
end;

IBenchResults = interface
  ['{C5D6E7F8-9A0B-1C2D-3E4F-5A6B7C8D9E0F}']
  function GetAll: TBenchResultArray;
  function GetByName(const AName: string): TBenchResult;
  function TryGetByName(const AName: string; out AResult: TBenchResult): Boolean;
  function GetCount: Integer;
  function PrintToConsole: string;
  function ToJSON: string;
  function ToTSV: string;
  function ToHTML: string;
  function ToBenchstat: string;
  procedure SaveToJSON(const APath: string);
  procedure SaveToHTML(const APath: string);
  procedure SaveToTSV(const APath: string);
  function CompareWithBaseline: TBenchComparisonArray;
  function CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;
  procedure SaveBaseline(const APath: string; const AGitHash: string = '');
  procedure AppendToTimeline(const APath: string);
  function CompareMultipleBaselines(
    const ABaselines: array of TBaselineData): TMatrixResult;
  function ToMatrixReport(const ABaselines: array of TBaselineData): string;
  function ToMatrixHTML(const ABaselines: array of TBaselineData): string;
  function ToMatrixJSON(const ABaselines: array of TBaselineData): string;
  function HasRegression(AThreshold: Double): Boolean;
  function GetEnvironment: TBenchEnvironment;
  property Count: Integer read GetCount;
  property Environment: TBenchEnvironment read GetEnvironment;
  { 完整接口约 77 方法 — 以 bench.intf 为准；测试: test_bench_results_api
    查询/过滤: GetSkipped/GetExecuted/FilterBy*/SortBy*/GetFastest/Slowest/TopN
    聚合: GetSummaryStats/GetPercentileStats/GetOutlierSummary/GetTotal*
    分组: GetGroups/GetGroupStats/CompareGroups(启发式)/GetGroupRegressionReport/To*_Grouped
    矩阵/导出: ToCSV/ToMarkdown/ToSummary/ToMatrixCSV/SaveToMatrix*
    注意: GetTotalBytesPerOp/GetTotalAllocsPerOp 为 per-op 指标求和，通常无物理意义
    对比: CompareTwoResults = MWU(需 RawSamples)；CompareGroups = 组均值启发式
  }
end;

IBenchStatsAnalyzer = interface
  ['{D4E5F6A7-B8C9-0D1E-2F3A-4B5C6D7E8F9A}']
  function ComputeStats(const ASamples: TDoubleArray): TBenchStats;
  function CountOutliers(const ASorted: TDoubleArray;
    AQ1, AQ3, AMultiplier: Double): Integer;
  function HasHeuristicDifference(const A, B: TBenchStats): Boolean;
  function HasHeuristicDifferenceAt(const A, B: TBenchStats; AAlpha: Double): Boolean;
  function ComputeApproximatePValue(const A, B: TBenchStats): Double;
  function LooksNormalHeuristic(const ASamples: TDoubleArray): Boolean;
  function Mean(const AData: TDoubleArray): Double;
  function Median(const AData: TDoubleArray): Double;
  function StdDev(const AData: TDoubleArray): Double;
  function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;
  function ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;
  function GeometricMean(const ARatios: TDoubleArray): Double;
end;

IBenchReportGenerator = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}']
  procedure SetResults(const AResults: array of TBenchResult);
  procedure SetEnvironment(const AEnvironment: TBenchEnvironment);
  procedure SetMaxDetailCount(ACount: Integer);
  function PrintToConsole: string;
  function ToBenchstat: string;
  function ToJSON: string;
  function ToTSV: string;
  function ToHTML: string;
  function GenerateMatrixReport(const AMatrix: TMatrixResult): string;
  function GenerateMatrixHTML(const AMatrix: TMatrixResult): string;
  function GenerateMatrixJSON(const AMatrix: TMatrixResult): string;
end;
```

### 1.3 核心类型

```pascal
TBenchResult = record
  Name: string;
  Executed: Boolean;
  Skipped: Boolean;
  SkipReason: string;
  Iterations: Int64;
  TotalNs: UInt64;
  NsPerOp: Double;
  OpsPerSec: Double;
  BytesPerOp: Int64;
  AllocsPerOp: Int64;
  StdDev: Double;
  Median: Double;
  P95: Double;
  P99: Double;
  Outliers: Integer;
  SampleCount: Integer;
  RawSamples: TDoubleArray;
end;

TBenchStats = record
  Mean, StdDev, Median, Min, Max: Double;
  P5, P25, P75, P95, P99: Double;
  IQR: Double;
  OutlierCount: Integer;
  Confidence95Low, Confidence95High: Double;
  Confidence99Low, Confidence99High: Double;
  SampleCount: Integer;
end;

TBenchConfig = record
  MinDurationNs: UInt64;
  MaxIterations: Int64;
  MinSamples: Integer;
  WarmupIterations: Integer;
  EnableMemoryTracking: Boolean;
  EnableParallel: Boolean;
  ParallelThreads: Integer;
  CollectRawSamples: Boolean;
  Quiet: Boolean;
  MaxDetailCount: Integer;
  SuiteName: string;
  TimeoutMs: Cardinal;
end;

TBenchEntry = record
  Name: string;
  Func: TBenchFunc;
  ParamFunc: TBenchParamFunc;
  ParamValue: Int64;
  IsLoop: Boolean;
  LoopFunc: TBenchLoopFunc;
  Setup: TBenchSetupFunc;
  Teardown: TBenchTeardownFunc;
  Condition: Boolean;
  EnableParallel: Boolean;
  ParallelThreads: Integer;
end;

TMatrixCell = record
  BaselineNsPerOp: Double;
  Ratio: Double;
  IsSignificant: Boolean;
  PValue: Double;
end;

TMatrixRow = record
  Name: string;
  CurrentNsPerOp: Double;
  CurrentStdDev: Double;
  CurrentBytesPerOp: Int64;
  CurrentAllocsPerOp: Int64;
  Cells: array of TMatrixCell;
end;

TMatrixResult = record
  BaselineNames: array of string;
  Rows: array of TMatrixRow;
  GeometricMeanRatios: array of Double;
end;
```

---

## 2. 不变量

- 自适应 N：运行时间不低于 `Duration`
- 统计计算至少 3 次迭代
- 百分位 P50/P95/P99 有效

---

## 3. 错误处理

- `EBenchInvalidParam` 参数无效
- `EBenchBaselineNotFound` 基线不存在

---

## 4. 线程安全

- TParallelBenchmark 使用工作线程并行执行
- IBenchContext 在各自线程中独立使用

---

## 5. 内存管理

- memtrack 跟踪堆分配，报告 AllocsPerOp
- IBenchResults 通过引用计数自动释放

---

## 6. 测试覆盖

- 默认 gate：`make bench-module-test` → **22** PROJECTS（见 `goal-tree.md` 测试套件分布）
- `nextpas.core.test.bench` 桥接测试在 **test lane**：`core/tests/nextpas.core.test/test_bench`
- 结果 API 专项：`test_bench_results_api`
- 契约脚本：`scripts/bench-contract-check.sh`（含 examples RTL 禁扫、PROJECTS=22、LANE-DUTY）

## 7. FPC RTL 隔离

- 生产 `nextpas.core.bench*`：**不得** `uses SysUtils/Classes/...`；线程经 `system.classes`，mem 经 `system.memmanager`
- 官方示例 `core/examples/bench`、`core/examples/nextpas.core.bench`：同样禁止直连 RTL；`WriteLn` 属 System 允许
- 契约门禁 C5 扫描 examples
