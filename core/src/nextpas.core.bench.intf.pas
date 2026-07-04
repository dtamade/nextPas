{**
 * @desc 基准测试接口定义
 *
 * 定义 IBenchSuite、IBenchResults、IBenchContext、
 * IBenchStatsAnalyzer、IBenchReportGenerator 等核心接口。
 *}
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
  TBenchBaseline = nextpas.core.bench.base.TBaselineData;

  {** 从 base 模块 re-export 多基线矩阵类型 }
  TMatrixCell = nextpas.core.bench.base.TMatrixCell;
  TMatrixRow = nextpas.core.bench.base.TMatrixRow;
  TMatrixResult = nextpas.core.bench.base.TMatrixResult;

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

    {** 暂停计时器（排除 setup/teardown 时间，保留已累计时间） }
    procedure StopTimer;

    {** 恢复计时器（扣除暂停期间的时间） }
    procedure StartTimer;

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

  {** 基准条目 - 单个基准测试的定义
   *  F-015: 为所有字段添加文档 }
  TBenchEntry = record
    Name: string;            {< 基准测试名称，用于报告和过滤 }
    Func: TBenchFunc;        {< 标准基准函数（框架控制迭代） }
    ParamFunc: TBenchParamFunc; {< 参数化基准函数 }
    ParamValue: Int64;       {< 传递给 ParamFunc 的参数值 }
    IsLoop: Boolean;         {< true = 用户控制循环（LoopFunc），false = 框架控制 }
    LoopFunc: TBenchLoopFunc; {< 用户控制循环的基准函数 }
    Setup: TBenchSetupFunc;  {< 每次迭代前调用，返回上下文数据 }
    Teardown: TBenchTeardownFunc; {< 每次迭代后调用，释放 Setup 返回的数据 }
    Condition: Boolean;      {< false 时跳过此条目（用于条件基准） }
    EnableParallel: Boolean; {< true 时使用 ParallelThreads 个线程并行执行 }
    ParallelThreads: Integer; {< 并行线程数，0 = 使用默认值 (CPU 核心数) }
    TimeoutMs: Int64;        {< F-017: per-benchmark 超时(毫秒)，0 = 使用 suite 级超时 }
  end;

  {** 基准套件接口 - Fluent Builder }
  IBenchSuite = interface
    ['{A1B2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']

    {** 添加基准测试（简单版本）
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;

    {** 添加基准测试（带 setup/teardown）
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function AddWithSetup(const AName: string; AFunc: TBenchFunc;
      ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;

    {** 条件添加基准测试（仅当条件为真时执行）
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function AddWhen(const AName: string; AFunc: TBenchFunc;
      ACondition: Boolean): IBenchSuite;

    {** 添加并行基准测试
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
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

    {** 添加用户控制循环的基准测试 — TBenchLoopFunc 不支持 IBenchContext
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
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

    {** 启用内存跟踪。
     *  注意：此操作替换进程级 MemoryManager，影响所有线程的内存分配。
     *  不可在多个 TBenchSuite 实例间并发调用。 }
    function EnableMemoryTracking: IBenchSuite;

    {** 禁用内存跟踪 }
    function DisableMemoryTracking: IBenchSuite;

    {** 启用原始样本收集 }
    function CollectRawSamples: IBenchSuite;

    {** 设置安静模式 }
    function SetQuiet(AQuiet: Boolean): IBenchSuite;

    {** 添加基线（ns/op，Double 精度） }
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;

    {** 添加基线（TDuration 便利重载，ST-05）。
     *  内部转换为 Double ns/op，与 Double 版本共存。 }
    function AddBaseline(const AName: string; ANsPerOp: TDuration): IBenchSuite;

    {** 批量添加基线 (ST-06) }
    function AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;

    {** 加载基线文件
     *  @raises EBenchBaselineNotFound 当文件不存在时
     *  @raises EBenchError 当文件格式错误时 }
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

    {** 获取单个结果（按名称）。
     *  @raises EBenchError 当名称不存在时。安全替代方案：TryGetByName。 }
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

    {** 生成 benchstat 兼容格式 (Go benchstat 工具可直接解析) }
    function ToBenchstat: string;

    {** 导出到 JSON 文件 }
    procedure SaveToJSON(const APath: string);

    {** 导出到 HTML 文件 }
    procedure SaveToHTML(const APath: string);

    {** 导出到 TSV 文件 }
    procedure SaveToTSV(const APath: string);

    {** 与基线对比 }
    function CompareWithBaseline: TBenchComparisonArray;

    {** 两个结果对比（Mann-Whitney U 检验，需 RawSamples）。
     *  @raises EBenchError 当任一名称不存在时。 }
    function CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;

    {** 保存当前结果为命名基线文件
     *  @raises EBenchError 当保存失败时 }
    procedure SaveBaseline(const APath: string; const AGitHash: string = '');

    {** 追加当前结果到时间线 JSONL 文件 (P1-5) }
    procedure AppendToTimeline(const APath: string);

    {** 多基线对比矩阵 (P2-1)：当前结果 vs N 个基线，返回矩阵 }
    function CompareMultipleBaselines(
      const ABaselines: array of TBenchBaseline): TMatrixResult;

    {** 多基线对比矩阵 — Console 报告 (P2-1) }
    function ToMatrixReport(
      const ABaselines: array of TBenchBaseline): string;

    {** 多基线对比矩阵 — HTML 报告 (P2-1) }
    function ToMatrixHTML(
      const ABaselines: array of TBenchBaseline): string;

    {** 多基线对比矩阵 — JSON 报告 (CI 消费) }
    function ToMatrixJSON(
      const ABaselines: array of TBenchBaseline): string;

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

    {** 计算统计摘要
     *  @edge ASamples 为空时返回 Default(TBenchStats)；
     *        样本数=1 时 StdDev=0, 置信区间退化为 [mean, mean] }
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

    {** Mann-Whitney U 检验 p-value（非参数，适用于右偏基准数据） }
    function ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;

    {** 几何均值（多 benchmark ratio 聚合的正确方法）
     *  @edge 空数组返回 1.0；非正 ratio 返回 0.0（哨兵值，表示非法输入） }
    function GeometricMean(const ARatios: TDoubleArray): Double;
  end;

  {** 报告生成器接口
   *
   *  提供多种格式的基准结果输出。
   *  所有方法均为纯函数（不写 stdout），返回格式化字符串。 }
  IBenchReportGenerator = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}']

    {** 设置结果数据 }
    procedure SetResults(const AResults: array of TBenchResult);

    {** 设置环境信息 }
    procedure SetEnvironment(const AEnvironment: TBenchEnvironment);

    {** 设置统计详情最大显示数量 }
    procedure SetMaxDetailCount(ACount: Integer);

    {** 格式化的控制台表格字符串（纯函数，不写 stdout） }
    function PrintToConsole: string;

    {** Go benchstat 兼容格式 }
    function ToBenchstat: string;

    {** JSON 格式（含环境信息、统计详情） }
    function ToJSON: string;

    {** TSV 格式（含状态/跳过原因） }
    function ToTSV: string;

    {** 自包含 HTML（内联 CSS/SVG 图表/箱线图） }
    function ToHTML: string;

    {** 多基线矩阵 Console 报告 }
    function GenerateMatrixReport(const AMatrix: TMatrixResult): string;

    {** 多基线矩阵 HTML（含 B/op + allocs/op） }
    function GenerateMatrixHTML(const AMatrix: TMatrixResult): string;

    {** 多基线矩阵 JSON（CI 可消费） }
    function GenerateMatrixJSON(const AMatrix: TMatrixResult): string;
  end;

implementation

end.
