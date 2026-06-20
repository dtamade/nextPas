unit nextpas.core.bench.intf;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.time.base;

type
  {** 前向声明 }
  IBenchResults = interface;

  {** 数组类型别名 }
  TBenchResultArray = array of TBenchResult;
  TBenchComparisonArray = array of TBenchComparison;

  {** 基准上下文 - 传递给基准函数的控制接口 }
  IBenchContext = interface
    ['{B7A3D2E1-4C5F-6A7B-8C9D-0E1F2A3B4C5D}']

    {** 设置每操作字节数（计算吞吐量 MB/s） }
    procedure SetBytes(ABytes: Int64);

    {** 设置每操作内存分配次数 }
    procedure SetAllocs(AAllocs: Int64);

    {** 重置计时器（排除 setup 时间） }
    procedure ResetTimer;

    {** 跳过当前基准 }
    procedure Skip(const AReason: string);

    {** 获取当前迭代次数 }
    function GetIterations: Int64;

    {** 获取当前已用时间 }
    function GetElapsed: TDuration;

    {** 获取每操作字节数 }
    function GetBytesPerOp: Int64;

    {** 获取每操作内存分配次数 }
    function GetAllocsPerOp: Int64;

    {** 属性访问 }
    property Iterations: Int64 read GetIterations;
    property Elapsed: TDuration read GetElapsed;
    property BytesPerOp: Int64 read GetBytesPerOp;
    property AllocsPerOp: Int64 read GetAllocsPerOp;
  end;

  {** 基准函数类型 - 简单版本 }
  TBenchFunc = procedure(const ACtx: IBenchContext);

  {** 基准函数类型 - 带 setup/teardown }
  TBenchSetupFunc = function: Pointer;
  TBenchTeardownFunc = procedure(AData: Pointer);

  {** 基准条目 - 单个基准测试的定义 }
  TBenchEntry = record
    Name: string;
    Func: TBenchFunc;
    Setup: TBenchSetupFunc;
    Teardown: TBenchTeardownFunc;
    Condition: Boolean;
    DependsOn: array of string;
  end;

  {** 基准套件接口 - Fluent Builder }
  IBenchSuite = interface
    ['{A1B2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']

    {** 添加基准测试（简单版本） }
    function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;

    {** 添加基准测试（带 setup/teardown） }
    function AddWithSetup(const AName: string; AFunc: TBenchFunc;
      ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;

    {** 条件添加基准测试（仅当条件为真时执行） }
    function AddWhen(const AName: string; AFunc: TBenchFunc;
      ACondition: Boolean): IBenchSuite;

    {** 添加并行基准测试 }
    function AddParallel(const AName: string; AFunc: TBenchFunc;
      AThreads: Integer): IBenchSuite;

    {** 设置最小基准持续时间 }
    function SetMinDuration(ADuration: TDuration): IBenchSuite;

    {** 设置最大迭代次数 }
    function SetMaxIterations(AIters: Int64): IBenchSuite;

    {** 设置最小采样数 }
    function SetMinSamples(ACount: Integer): IBenchSuite;

    {** 设置热身迭代次数 }
    function SetWarmupIters(ACount: Integer): IBenchSuite;

    {** 启用内存跟踪 }
    function EnableMemoryTracking: IBenchSuite;

    {** 禁用内存跟踪 }
    function DisableMemoryTracking: IBenchSuite;

    {** 添加基线（用于对比） }
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;

    {** 加载基线文件 }
    function LoadBaseline(const APath: string): IBenchSuite;

    {** 设置过滤条件 }
    function SetFilter(const AFilter: string): IBenchSuite;

    {** 运行基准测试 }
    function Run: IBenchResults;
  end;

  {** 基准结果集合接口 }
  IBenchResults = interface
    ['{C5D6E7F8-9A0B-1C2D-3E4F-5A6B7C8D9E0F}']

    {** 获取所有结果 }
    function GetAll: TBenchResultArray;

    {** 获取单个结果（按名称） }
    function GetByName(const AName: string): TBenchResult;

    {** 获取结果数量 }
    function GetCount: Integer;

    {** 生成控制台报告 }
    function ToConsole: string;

    {** 生成 JSON 报告 }
    function ToJSON: string;

    {** 生成 TSV 报告 }
    function ToTSV: string;

    {** 生成 HTML 报告 }
    function ToHTML: string;

    {** 导出到 JSON 文件 }
    procedure SaveToJSON(const APath: string);

    {** 导出到 HTML 文件 }
    procedure SaveToHTML(const APath: string);

    {** 导出到 TSV 文件 }
    procedure SaveToTSV(const APath: string);

    {** 与基线对比 }
    function CompareWithBaseline: TBenchComparisonArray;

    {** 检测回归（返回 true 表示有回归） }
    function HasRegression(AThreshold: Double): Boolean;

    {** 获取环境信息 }
    function GetEnvironment: TBenchEnvironment;

    {** 属性访问 }
    property Count: Integer read GetCount;
    property Environment: TBenchEnvironment read GetEnvironment;
  end;

  {** 统计分析器接口 }
  IBenchStatsAnalyzer = interface
    ['{D4E5F6A7-B8C9-0D1E-2F3A-4B5C6D7E8F9A}']

    {** 计算统计摘要 }
    function ComputeStats(const ASamples: TDoubleArray): TBenchStats;

    {** 检测异常值 }
    function CountOutliers(const ASorted: TDoubleArray;
      AQ1, AQ3, AMultiplier: Double): Integer;

    {** 检测回归（两个分布是否有显著差异） }
    function IsSignificantDifference(const A, B: TBenchStats): Boolean;

    {** 计算 p-value }
    function ComputePValue(const A, B: TBenchStats): Double;

    {** 正态性检验（Shapiro-Wilk） }
    function IsNormal(const ASamples: TDoubleArray): Boolean;

    {** 计算均值 }
    function Mean(const AData: TDoubleArray): Double;

    {** 计算中位数 }
    function Median(var AData: TDoubleArray): Double;

    {** 计算标准差 }
    function StdDev(const AData: TDoubleArray): Double;

    {** 计算百分位数 }
    function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;

    {** 排序数组 }
    procedure Sort(var AData: TDoubleArray);
  end;

implementation

end.
