unit nextpas.core.bench.intf;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.time.base,
  nextpas.core.exception;

type
  {** 基准框架异常基类 }
  EBenchError = class(ENextPasError);

  {** 参数无效异常 }
  EBenchInvalidParam = class(EBenchError);

  {** 基线未找到异常 }
  EBenchBaselineNotFound = class(EBenchError);

  {** 前向声明 }
  IBenchResults = interface;

  {** 从 base 模块 re-export 数组类型 }
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  TBenchComparisonArray = nextpas.core.bench.base.TBenchComparisonArray;

  {** 基准上下文 - 传递给基准函数的控制接口 }
  IBenchContext = interface
    ['{B7A3D2E1-4C5F-6A7B-8C9D-0E1F2A3B4C5D}']

    {** 设置每操作字节数（计算吞吐量 MB/s） }
    procedure SetBytes(ABytes: Int64);

    {** 设置每操作内存分配次数 }
    procedure SetAllocs(AAllocs: Int64);

    {** 累加每操作字节数（多次迭代分段报告场景） }
    procedure AddBytes(ABytes: Int64);

    {** 累加每操作内存分配次数 }
    procedure AddAllocs(AAllocs: Int64);

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

    {** 获取当前基准名称 (ST-03) }
    function GetName: string;

    {** 属性访问 }
    property Iterations: Int64 read GetIterations;
    property Elapsed: TDuration read GetElapsed;
    property BytesPerOp: Int64 read GetBytesPerOp;
    property AllocsPerOp: Int64 read GetAllocsPerOp;
    property Name: string read GetName;
  end;

  {** 基准函数类型 - 简单版本 }
  TBenchFunc = procedure(const ACtx: IBenchContext);

  {** 参数化基准函数类型 }
  TBenchParamFunc = procedure(const ACtx: IBenchContext; AParam: Int64);

  {** 用户控制循环的基准函数类型 }
  TBenchLoopFunc = procedure(AN: Int64);

  {** 基准函数类型 - 带 setup/teardown }
  TBenchSetupFunc = function: Pointer;
  TBenchTeardownFunc = procedure(AData: Pointer);

  {** 基准条目 - 单个基准测试的定义 }
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

    {** 添加参数化基准测试（自动生成多个子基准）。
     *  AName: 基准名称模板，参数值自动追加为 "/<value>" 后缀。
     *         例如 AName='Sort' + AParams=[100,1000] → 条目 "Sort/100", "Sort/1000"。
     *  AFunc: 参数化基准函数，接收上下文和当前参数值。
     *  AParams: 参数值数组，每个值生成一个独立的基准条目。 }
    function AddRange(const AName: string; AFunc: TBenchParamFunc;
      const AParams: array of Int64): IBenchSuite;

    {** 添加参数化基准测试（带 setup/teardown） (DS-02)。
     *  与 AddRange 相同，但每个参数化条目共享同一对 setup/teardown 回调。
     *  Setup 在校准和采样前调用，Teardown 在采样后调用。 }
    function AddRange(const AName: string; AFunc: TBenchParamFunc;
      const AParams: array of Int64;
      ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;

    {** 添加用户控制循环的基准测试 }
    function AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;

    {** 清空所有已注册条目 (DS-03) }
    function Clear: IBenchSuite;

    {** 按名称移除条目 (DS-03) }
    function RemoveByName(const AName: string): IBenchSuite;

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

    {** 启用原始样本收集 }
    function CollectRawSamples: IBenchSuite;

    {** 设置安静模式 }
    function SetQuiet(AQuiet: Boolean): IBenchSuite;

    {** 添加基线（用于对比） }
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;

    {** 批量添加基线 (ST-06) }
    function AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;

    {** 加载基线文件 }
    function LoadBaseline(const APath: string): IBenchSuite;

    {** 设置过滤条件 }
    function SetFilter(const AFilter: string): IBenchSuite;

    {** 设置整体超时（毫秒），超时后跳过剩余 benchmark (ST-04)。
     *  0 = 不超时（默认）。超时在 benchmark 条目之间检查，不中断正在执行的条目。 }
    function SetTimeout(ATimeoutMs: Cardinal): IBenchSuite;

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

    {** 尝试获取单个结果（按名称），返回是否找到 }
    function TryGetByName(const AName: string; out AResult: TBenchResult): Boolean;

    {** 获取结果数量 }
    function GetCount: Integer;

    {** 生成控制台报告 }
    function PrintToConsole: string;

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

    {** 检测回归启发式（不是正式显著性检验） }
    function HasHeuristicDifference(const A, B: TBenchStats): Boolean;

    {** 检测回归启发式（自定义显著性水平） (DS-04) }
    function HasHeuristicDifferenceAt(const A, B: TBenchStats; AAlpha: Double): Boolean;

    {** 计算近似 p-value（启发式） }
    function ComputeApproximatePValue(const A, B: TBenchStats): Double;

    {** 正态性启发式（近似 Shapiro-Wilk） }
    function LooksNormalHeuristic(const ASamples: TDoubleArray): Boolean;

    {** 计算均值 }
    function Mean(const AData: TDoubleArray): Double;

    {** 计算中位数 }
    function Median(const AData: TDoubleArray): Double;

    {** 计算标准差 }
    function StdDev(const AData: TDoubleArray): Double;

    {** 计算百分位数 }
    function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;
  end;

implementation

end.
