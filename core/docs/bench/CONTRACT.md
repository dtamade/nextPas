# nextpas.core.bench 代码契约

**模块路径**：`core/src/nextpas.core.bench*.pas`（11 个源文件）
**层级**：L1（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| bench.base | TBaselineComparison, TBaselineManager, EBenchError 基础类型 |
| bench.intf | IBenchResults, IBenchContext 接口定义 |
| bench.runner | TParallelBenchmark, TBenchThread 基准测试运行器 |
| bench.parallel | TParallelBenchConfig 并行基准配置 |
| bench.stats | 统计计算（均值/中位数/标准差） |
| bench.stats.advanced | 高级统计（百分位/自举） |
| bench.baseline | 基线管理（保存/对比） |
| bench.memtrack | 内存跟踪 |
| bench.report | 报告生成 |
| bench.pas | 门面 re-export |

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
  function SetTimeout(ATimeoutMs: Cardinal): IBenchSuite;
  function Run: IBenchResults;
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
    const ABaselines: array of TBenchBaseline): TMatrixResult;
  function ToMatrixReport(const ABaselines: array of TBenchBaseline): string;
  function ToMatrixHTML(const ABaselines: array of TBenchBaseline): string;
  function ToMatrixJSON(const ABaselines: array of TBenchBaseline): string;
  function HasRegression(AThreshold: Double): Boolean;
  function GetEnvironment: TBenchEnvironment;
  property Count: Integer read GetCount;
  property Environment: TBenchEnvironment read GetEnvironment;
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

- `test_bench`: Runner/Stats/Baseline/Parallel/Memtrack/Report
