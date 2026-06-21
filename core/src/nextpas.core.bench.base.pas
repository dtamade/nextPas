unit nextpas.core.bench.base;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

type
  {** 基准结果 - 单个基准测试的完整结果 }
  TBenchResult = record
    Name: string;
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
  end;

  {** 统计摘要 - 完整的统计分析结果 }
  TBenchStats = record
    Mean: Double;
    StdDev: Double;
    Median: Double;
    Min: Double;
    Max: Double;
    P5: Double;
    P25: Double;
    P75: Double;
    P95: Double;
    P99: Double;
    IQR: Double;
    OutlierCount: Integer;
    Confidence95Low: Double;
    Confidence95High: Double;
    Confidence99Low: Double;
    Confidence99High: Double;
    SampleCount: Integer;
  end;

  {** 基线对比 - 与基线性能的对比结果 }
  TBenchComparison = record
    BaselineName: string;
    BaselineNsPerOp: Double;
    CurrentNsPerOp: Double;
    Ratio: Double;
    Significant: Boolean;
    PValue: Double;
  end;

  {** 环境信息 - 运行环境描述 }
  TBenchEnvironment = record
    OS: string;
    CPU: string;
    Cores: Integer;
    FPCVersion: string;
    Timestamp: string;
  end;

  {** 基准配置 - 基准运行参数 }
  TBenchConfig = record
    MinDurationNs: UInt64;
    MaxIterations: Int64;
    MinSamples: Integer;
    WarmupIterations: Integer;
    EnableMemoryTracking: Boolean;
    EnableParallel: Boolean;
    ParallelThreads: Integer;
  end;

  {** 双精度浮点数组 }
  TDoubleArray = array of Double;

  {** 整数数组 }
  TInt64Array = array of Int64;

  {** 基准结果数组 }
  TBenchResultArray = array of TBenchResult;

  {** 基准比较数组 }
  TBenchComparisonArray = array of TBenchComparison;

  {** 基线数据 }
  TBenchBaseline = record
    Name: string;
    NsPerOp: Double;
  end;

  {** 基线数组 }
  TBenchBaselineArray = array of TBenchBaseline;

const
  {** 默认配置值 }
  BENCH_DEFAULT_MIN_DURATION_NS = 1000000000;  // 1 秒
  BENCH_DEFAULT_MAX_ITERATIONS = 1000000;
  BENCH_DEFAULT_MIN_SAMPLES = 30;
  BENCH_DEFAULT_WARMUP_ITERATIONS = 5;
  BENCH_DEFAULT_PARALLEL_THREADS = 4;

  {** 环境变量名 }
  BENCH_ENV_FILTER = 'NEXTPAS_BENCH_FILTER';
  BENCH_ENV_MAX_ITERS = 'NEXTPAS_BENCH_MAX_ITERS';
  BENCH_ENV_MIN_DURATION = 'NEXTPAS_BENCH_MIN_DURATION';
  BENCH_ENV_MIN_SAMPLES = 'NEXTPAS_BENCH_MIN_SAMPLES';
  BENCH_ENV_WARMUP = 'NEXTPAS_BENCH_WARMUP';
  BENCH_ENV_OUTPUT = 'NEXTPAS_BENCH_OUTPUT';
  BENCH_ENV_OUTPUT_DIR = 'NEXTPAS_BENCH_OUTPUT_DIR';
  BENCH_ENV_BASELINE = 'NEXTPAS_BENCH_BASELINE';
  BENCH_ENV_FAIL_ON_REGRESSION = 'NEXTPAS_BENCH_FAIL_ON_REGRESSION';
  BENCH_ENV_QUIET = 'NEXTPAS_BENCH_QUIET';
  BENCH_ENV_NO_MEMTRACK = 'NEXTPAS_BENCH_NO_MEMTRACK';

  {** 统计常量 }
  Z_SCORE_95 = 1.96;
  Z_SCORE_99 = 2.576;
  OUTLIER_MULTIPLIER = 1.5;  // Tukey's Fences

implementation

end.
