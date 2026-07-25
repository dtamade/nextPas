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
  nextpas.core.exception,
  nextpas.core.io.linewriter;

type
  {** 双精度浮点数组 }
  TDoubleArray = nextpas.core.bench.base.TDoubleArray;

  {** 字符串数组 }
  TStringArray = nextpas.core.bench.base.TStringArray;

  {** 批量百分位计算结果 (E03: 避免重复排序) }
  TPercentileResult = record
    P5: Double;
    P25: Double;
    P50: Double;
    P75: Double;
    P95: Double;
    P99: Double;
  end;

  {** 聚合摘要统计 — 一次调用获取所有关键指标
   *  用于 CI/CD 快速摘要、仪表盘展示等场景。 }
  TBenchSummaryStats = record
    ExecutedCount: Integer;   {< 已执行（非跳过）的结果数 }
    SkippedCount: Integer;    {< 被跳过的结果数 }
    TotalOpsPerSec: Double;   {< 总操作数/秒 }
    TotalIterations: Int64;   {< 总迭代次数 }
    TotalOutliers: Integer;   {< 总异常值数 }
    TotalBytesPerOp: Int64;   {< 总字节数/操作 }
    TotalAllocsPerOp: Int64;  {< 总分配次数/操作 }
    TotalElapsedNs: Double;   {< 总耗时（纳秒） }
    FastestNsPerOp: Double;   {< 最快基准的 ns/op }
    SlowestNsPerOp: Double;   {< 最慢基准的 ns/op }
    MeanNsPerOp: Double;      {< 均值 ns/op }
    MedianNsPerOp: Double;    {< 中位数 ns/op }
    CustomMetricsCount: Integer; {< 自定义指标总数 }
  end;

  {** 回归检测报告 — CI/CD 消费的结构化结果
   *  组合 HasRegression 与详细对比数据，一次调用获取完整回归信息。 }
  TBenchRegressionReport = record
    HasRegression: Boolean;          {< 是否存在回归 }
    Threshold: Double;               {< 使用的回归阈值 }
    TotalComparisons: Integer;       {< 总对比数 }
    RegressedCount: Integer;         {< 回归数量 }
    ImprovedCount: Integer;          {< 改进数量 }
    UnchangedCount: Integer;         {< 无变化数量 }
    Comparisons: TBenchComparisonArray; {< 详细对比数据 }
    WorstRegressRatio: Double;       {< 最严重回归的 ratio }
    WorstRegressName: string;        {< 最严重回归的名称 }
  end;

  {** 异常值摘要 — 按严重度分级统计 }
  TOutlierSummary = record
    Total: Integer;        {< 总异常值数 }
    Mild: Integer;         {< 轻度异常值 (1.5-3x IQR) }
    Moderate: Integer;     {< 中度异常值 (3-10x IQR) }
    Severe: Integer;       {< 严重异常值 (>10x IQR) }
    Ratio: Double;         {< 异常值比例 (Total / SampleCount) }
  end;

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

  {** OLS 线性回归结果 — 从 base 模块 re-export }
  TOLSRegression = nextpas.core.bench.base.TOLSRegression;
  {** 从 base 模块 re-export 基线数据类型 }
  TBaselineData = nextpas.core.bench.base.TBaselineData;

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

    {** 设置自定义指标 }
    procedure SetCustomMetric(const AName: string; AValue: Double);

    {** 获取自定义指标数组 }
    function GetCustomMetrics: TCustomMetricArray;

    {** 属性访问 }
    property Iterations: Int64 read GetIterations;
    property Elapsed: TDuration read GetElapsed;
    property BytesPerOp: Int64 read GetBytesPerOp;
    property AllocsPerOp: Int64 read GetAllocsPerOp;
    property Name: string read GetName;
  end;

  {** 基准函数类型 - 简单版本（框架控制循环） }
  TBenchFunc = procedure(const ACtx: IBenchContext);

  {** 基准函数类型 - 最简版本（无参数，框架控制循环）
   *  F-03: 降低认知负担，类似 Go testing.B 的 func(b *B) }
  TBenchSimpleFunc = procedure;

  {** 参数化基准函数类型 }
  TBenchParamFunc = procedure(const ACtx: IBenchContext; AParam: Int64);

  {** 用户控制循环的基准函数类型（不支持 IBenchContext） }
  TBenchLoopFunc = procedure(AN: Int64);

  {** 用户控制循环的基准函数类型（支持 IBenchContext，可设置 bytes/allocs/skip） }
  TBenchLoopContextFunc = procedure(const ACtx: IBenchContext; AN: Int64);

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
    IsLoop: Boolean;         {< true = 用户控制循环（LoopFunc/LoopContextFunc），false = 框架控制 }
    LoopFunc: TBenchLoopFunc; {< 用户控制循环的基准函数（无 context） }
    LoopContextFunc: TBenchLoopContextFunc; {< F-01: 用户控制循环的基准函数（有 context） }
    Setup: TBenchSetupFunc;  {< 每次基准运行前调用（所有迭代共享同一 context 数据） }
    Teardown: TBenchTeardownFunc; {< 基准运行结束后调用，释放 Setup 返回的数据 }
    Condition: Boolean;      {< false 时跳过此条目（用于条件基准） }
    EnableParallel: Boolean; {< true 时使用 ParallelThreads 个线程并行执行 }
    ParallelThreads: Integer; {< 并行线程数，0 = 使用默认值 (CPU 核心数) }
    CollectRawSamples: Boolean; {< F-04: 强制收集原始样本，覆盖 config 级别设置 }
    SimpleFunc: TBenchSimpleFunc; {< F-03: 最简版本函数（框架控制循环） }
  end;

  {** 基准套件接口 - Fluent Builder }
  IBenchSuite = interface
    ['{A1B2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']

    {** 添加基准测试（简单版本）
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;

    {** 添加基准测试（最简版本，无参数）
     *  F-03: 降低认知负担，框架控制循环，类似 Go testing.B
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function AddSimple(const AName: string; AFunc: TBenchSimpleFunc): IBenchSuite;

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

    {** F-01: 添加用户控制循环的基准测试（带 IBenchContext）。
     *  与 AddLoop 相同，但回调可访问 IBenchContext 以设置 bytes/allocs/skip。
     *  @raises EBenchInvalidParam 当 AFunc 为 nil 时 }
    function AddLoopWithContext(const AName: string; AFunc: TBenchLoopContextFunc): IBenchSuite;

    {** 清空所有已注册条目 (DS-03) }
    function Clear: IBenchSuite;

    {** 按名称移除条目 (DS-03)
     *  @raises EBenchInvalidParam 当条目不存在时 }
    function RemoveByName(const AName: string): IBenchSuite;

    {** 安全移除条目（按名称），返回是否找到并移除
     *  F-10: 与 TryGetByName 风格一致的安全版本 }
    function TryRemoveByName(const AName: string): Boolean;

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

    {** 设置指定条目的原始样本收集（覆盖 config 级别设置）
     *  @raises EBenchInvalidParam 当条目不存在时 }
    function SetEntryCollectRawSamples(const AName: string;
      ACollect: Boolean): IBenchSuite;

    {** 设置安静模式 }
    function SetQuiet(AQuiet: Boolean): IBenchSuite;

    {** 添加基线（ns/op，Double 精度）。
     *  适用场景：已有外部工具（如 benchstat）导出的 ns/op 数据。
     *  对比时只能使用 ratio 启发式（无 StdDev/SampleCount）。 }
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;

    {** 添加基线（TDuration 便利重载，ST-05）。
     *  内部转换为 Double ns/op，与 Double 版本共存。 }
    function AddBaseline(const AName: string; ANsPerOp: TDuration): IBenchSuite;

    {** 添加完整基线数据（包含 BytesPerOp/AllocsPerOp/GitHash 等）。
     *  适用场景：从 SaveBaseline 导出的 JSON 加载，或手动构建完整基线。 }
    function AddBaselineData(const ABaseline: TBaselineData): IBenchSuite;

    {** 批量添加基线 (ST-06)。
     *  适用场景：一次加载多个基线进行矩阵对比。 }
    function AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;

    {** 加载基线文件（JSON 格式）。
     *  适用场景：从 CI 产物加载历史基线。
     *  @raises EBenchBaselineNotFound 当文件不存在时
     *  @raises EBenchError 当文件格式错误时 }
    function LoadBaseline(const APath: string): IBenchSuite;

    {** 安全加载基线文件，文件不存在或格式错误时返回 False
     *  F-10: 与 TryGetByName 风格一致的安全版本 }
    function TryLoadBaseline(const APath: string): Boolean;

    {** 设置过滤条件（子串匹配或 glob 模式）。
     *  包含 * 或 ? 时使用 glob 匹配（如 'Sort*'、'Hash??'），
     *  否则使用子串匹配（如 'Sort' 匹配所有含 'Sort' 的名称）。
     *  匹配不区分大小写。 }
    function SetFilter(const AFilter: string): IBenchSuite;

    {** 设置整体超时（TDuration 便利重载）。
     *  内部转换为毫秒存储。0 = 不超时（默认）。
     *  @raises EBenchInvalidParam 当 ADuration 为负值时 }
    function SetTimeout(ADuration: TDuration): IBenchSuite;

    {** 设置输出写入器 — 替代裸 WriteLn，允许调用方重定向输出。
     *  nil 时自动创建控制台写入器（默认行为）。 }
    function SetOutput(const AWriter: ILineWriter): IBenchSuite;

    {** 启用自适应预热：当最近窗口的 CV < 阈值时提前停止预热。 }
    function SetAdaptiveWarmup(AEnabled: Boolean;
      ACVThreshold: Double = BENCH_DEFAULT_WARMUP_CV_THRESHOLD;
      AMaxIterations: Integer = BENCH_DEFAULT_WARMUP_MAX_ITERATIONS): IBenchSuite;

    {** 设置进度回调（每个基准开始/完成时调用）。 }
    function SetOnProgress(ACallback: TBenchProgressCallback): IBenchSuite;

    {** 获取已注册的基准条目数量（包括 Condition=False 的条目）。
     *  可在 Run 之前调用，用于检查是否注册了任何基准。 }
    function GetEntryCount: Integer;

    {** 检查指定名称的基准条目是否存在。
     *  @returns True 如果存在名为 AName 的条目 }
    function HasEntry(const AName: string): Boolean;

    {** Phase 3: 批量并行运行独立基准。
     *  独立基准（非并行基准）可以在多个线程中同时运行。
     *  AThreadCount: 并行线程数，默认为 CPU 核心数。
     *  注意：并行运行的基准不能使用内存追踪。 }
    function RunParallel(AThreadCount: Integer = 0): IBenchResults;

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

    {** 获取已跳过的结果（Skipped=True）。
     *  用于快速过滤出被跳过的基准，无需遍历 GetAll。 }
    function GetSkipped: TBenchResultArray;

    {** 获取已执行的结果（Executed=True 且 Skipped=False）。
     *  用于快速获取有效测量结果，排除跳过和过滤的条目。 }
    function GetExecuted: TBenchResultArray;

    {** 获取聚合统计（跨所有已执行结果）。
     *  返回 TBenchStats，包含均值、中位数、p95、总 ops/s 等聚合指标。
     *  当无已执行结果时返回零值 TBenchStats。 }
    function GetAggregateStats: TBenchStats;

    {** 按名称前缀过滤结果。
     *  返回所有 Name 以 APrefix 开头的已执行结果（区分大小写）。
     *  示例: FilterByPrefix('Sort/') 返回所有排序基准。 }
    function FilterByPrefix(const APrefix: string): TBenchResultArray;

    {** 按名称后缀过滤结果。
     *  返回所有 Name 以 ASuffix 结尾的已执行结果（区分大小写）。
     *  示例: FilterBySuffix('/1000') 返回所有参数为1000的基准。 }
    function FilterBySuffix(const ASuffix: string): TBenchResultArray;

    {** 按名称子串过滤结果。
     *  返回所有 Name 包含 ASubstring 的已执行结果（区分大小写）。
     *  示例: FilterBySubstring('Sort') 返回所有包含 'Sort' 的基准。 }
    function FilterBySubstring(const ASubstring: string): TBenchResultArray;

    {** 按 NsPerOp 升序排序已执行结果。
     *  返回排序后的副本，不修改原始结果集。
     *  用于快速找出最快/最慢的基准。 }
    function SortByNsPerOp(AAscending: Boolean = True): TBenchResultArray;

    {** 获取最快的基准结果（NsPerOp 最小）。
     *  当无已执行结果时返回零值 TBenchResult。 }
    function GetFastest: TBenchResult;

    {** 获取最慢的基准结果（NsPerOp 最大）。
     *  当无已执行结果时返回零值 TBenchResult。 }
    function GetSlowest: TBenchResult;

    {** 获取最快的 N 个基准结果（按 NsPerOp 升序）。
     *  ANCount: 返回的结果数量，0 或负数返回空数组。
     *  当 ANCount > 已执行结果数时返回所有已执行结果。
     *  返回排序后的副本，不修改原始结果集。 }
    function GetTopN(ANCount: Integer): TBenchResultArray;

    {** 获取稳定的结果（CV < 阈值）。
     *  ACVThreshold: 变异系数阈值，默认 10% (0.1)。
     *  CV = StdDev / NsPerOp，越小越稳定。
     *  返回已执行结果中 CV < ACVThreshold 的结果。 }
    function GetStableResults(ACVThreshold: Double = 0.1): TBenchResultArray;

    {** 获取不稳定的结果（CV >= 阈值）。
     *  ACVThreshold: 变异系数阈值，默认 10% (0.1)。
     *  返回已执行结果中 CV >= ACVThreshold 的结果。
     *  用于快速识别需要关注的高波动基准。 }
    function GetUnstableResults(ACVThreshold: Double = 0.1): TBenchResultArray;

    {** 按 NsPerOp 范围过滤结果。
     *  AMinNs: 最小 NsPerOp（包含），0 表示无下限。
     *  AMaxNs: 最大 NsPerOp（包含），0 表示无上限。
     *  返回已执行结果中 NsPerOp 在 [AMinNs, AMaxNs] 范围内的结果。
     *  用于快速筛选特定性能区间的基准。 }
    function FilterByNsPerOpRange(AMinNs: Double = 0; AMaxNs: Double = 0): TBenchResultArray;

    {** 按 glob 模式过滤结果名称。
     *  支持 * (任意字符序列) 和 ? (单个字符) 通配符。
     *  匹配不区分大小写。
     *  示例: FilterByNamePattern('Sort*') 返回所有以 Sort 开头的基准。
     *        FilterByNamePattern('Hash??') 返回 Hash 后跟两个字符的基准。 }
    function FilterByNamePattern(const APattern: string): TBenchResultArray;

    {** 获取聚合摘要统计（一次调用获取所有关键指标）。
     *  返回 TBenchSummaryStats 记录，包含计数、总和、最快/最慢、均值/中位数等。
     *  当无已执行结果时返回零值记录。 }
    function GetSummaryStats: TBenchSummaryStats;

    {** 获取回归检测报告（CI/CD 消费的结构化结果）。
     *  组合 HasRegression 与详细对比数据，一次调用获取完整回归信息。
     *  AThreshold: 回归阈值（ratio > AThreshold 视为回归）。
     *  当无基线数据时返回空报告。 }
    function GetRegressionReport(AThreshold: Double): TBenchRegressionReport;

    {** 按自定义指标名称过滤结果。
     *  返回所有已执行结果中包含名为 AMetricName 的自定义指标的结果。
     *  用于快速筛选有特定自定义指标的基准。 }
    function FilterByHasCustomMetric(const AMetricName: string): TBenchResultArray;

    {** 生成 CSV 格式报告（含逗号转义和引号保护）。
     *  与 TSV 不同，CSV 正确处理名称中的逗号和引号。 }
    function ToCSV: string;

    {** 获取总操作数/秒（所有已执行结果的 OpsPerSec 之和）。
     *  用于评估整体吞吐量。 }
    function GetTotalOpsPerSec: Double;

    {** 获取总异常值数量（所有已执行结果的 Outliers 之和）。
     *  用于评估整体稳定性。 }
    function GetTotalOutliers: Integer;

    {** 获取总迭代次数（所有已执行结果的 Iterations 之和）。
     *  用于评估整体测试覆盖度。 }
    function GetTotalIterations: Int64;

    {** 获取总字节数/操作（所有已执行结果的 BytesPerOp 之和）。
     *  用于评估整体内存带宽。 }
    function GetTotalBytesPerOp: Int64;

    {** 获取总分配次数/操作（所有已执行结果的 AllocsPerOp 之和）。
     *  用于评估整体内存分配压力。 }
    function GetTotalAllocsPerOp: Int64;

    {** 获取总耗时（所有已执行结果的总运行时间）。
     *  返回 TDuration 类型，用于评估整体测试时间。 }
    function GetTotalElapsed: TDuration;

    {** 获取所有自定义指标（跨所有已执行结果）。
     *  返回扁平化的 TCustomMetricArray，包含所有结果的自定义指标。
     *  用于分析跨基准的自定义指标。 }
    function GetAllCustomMetrics: TCustomMetricArray;

    {** 获取自定义指标总数（跨所有已执行结果）。
     *  返回所有已执行结果的 CustomMetrics 数组长度之和。 }
    function GetTotalCustomMetricsCount: Integer;

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

    {** 生成简洁摘要报告（适合 CI/CD） }
    function ToSummary: string;

    {** 生成 Markdown 报告（适合 GitHub PR/CI 注释）。
     *  包含表格、统计摘要和环境信息，可直接粘贴到 issue/PR 中。 }
    function ToMarkdown: string;

    {** 导出到 JSON 文件 }
    procedure SaveToJSON(const APath: string);

    {** 导出到 HTML 文件 }
    procedure SaveToHTML(const APath: string);

    {** 导出到 TSV 文件 }
    procedure SaveToTSV(const APath: string);

    {** 导出到 Markdown 文件 }
    procedure SaveToMarkdown(const APath: string);

    {** 导出到 CSV 文件 }
    procedure SaveToCSV(const APath: string);

    {** 获取指定自定义指标的所有值。
     *  返回所有已执行结果中名为 AMetricName 的自定义指标的值数组。
     *  用于分析跨基准的特定指标趋势。
     *  当无匹配指标时返回空数组。 }
    function GetCustomMetricValues(const AMetricName: string): TDoubleArray;

    {** 获取所有已执行结果的百分位统计。
     *  返回 TPercentileResult，包含 P5/P25/P50/P75/P95/P99。
     *  基于所有已执行结果的 NsPerOp 值计算。
     *  当无已执行结果时返回零值记录。 }
    function GetPercentileStats: TPercentileResult;

    {** 获取所有已执行结果的变异系数 (CV) 数组。
     *  CV = StdDev / NsPerOp，越小越稳定。
     *  返回与 GetExecuted 顺序一致的 CV 值数组。
     *  用于批量稳定性分析。 }
    function GetCVArray: TDoubleArray;

    {** 获取异常值摘要（按严重度分级统计）。
     *  返回 TOutlierSummary，包含总异常值数、轻度/中度/严重计数和比例。
     *  基于所有已执行结果的 OutlierMethod/OutlierThreshold 分级。
     *  当无已执行结果时返回零值记录。 }
    function GetOutlierSummary: TOutlierSummary;

    {** 按自定义指标值排序结果。
     *  按指定自定义指标的值排序（升序/降序）。
     *  不包含指定指标的结果排在末尾。
     *  用于分析跨基准的特定指标趋势。 }
    function SortByCustomMetric(const AMetricName: string;
      AAscending: Boolean = True): TBenchResultArray;

    {** 按自定义指标值范围过滤结果。
     *  返回包含指定指标且值在 [AMin, AMax] 范围内的已执行结果。
     *  AMin/AMax <= 0 表示无限制。
     *  两遍扫描（计数+收集），深拷贝防别名。 }
    function FilterByCustomMetricRange(const AMetricName: string;
      AMin: Double = 0; AMax: Double = 0): TBenchResultArray;

    {** 获取指定自定义指标的聚合统计。
     *  跨所有包含该指标的已执行结果计算统计量。
     *  返回 TBenchStats（均值、标准差、中位数、百分位数等）。
     *  当无结果包含该指标时返回零值记录。 }
    function GetCustomMetricStats(const AMetricName: string): TBenchStats;

    {** 获取有异常值的结果。
     *  返回 Outliers > 0 的已执行结果。
     *  用于识别不稳定的基准。 }
    function GetResultsWithOutliers: TBenchResultArray;

    {** 获取无异常值的结果。
     *  返回 Outliers = 0 的已执行结果。
     *  用于筛选稳定的基准。 }
    function GetResultsWithoutOutliers: TBenchResultArray;

    {** 按吞吐量排序结果（ops/sec 降序）。
     *  高吞吐量的排在前面。
     *  用于快速识别最快的操作。 }
    function SortByOpsPerSec(AAscending: Boolean = False): TBenchResultArray;

    {** 按标准差范围过滤结果。
     *  返回 StdDev 在 [AMin, AMax] 范围内的已执行结果。
     *  AMin/AMax <= 0 表示无限制。
     *  用于筛选特定稳定性水平的基准。 }
    function FilterByStdDevRange(AMin: Double = 0;
      AMax: Double = 0): TBenchResultArray;

    {** 获取所有唯一的分组名称（按前缀 "/" 分割）。
     *  例如 "Sort/QuickSort", "Sort/MergeSort" → "Sort"。
     *  返回去重后的分组名称数组。 }
    function GetGroups: TStringArray;

    {** 获取指定分组的聚合统计。
     *  按前缀 "/" 分割名称，聚合同组结果的统计量。
     *  返回 TBenchStats（均值、标准差、中位数、百分位数等）。
     *  当无结果属于该分组时返回零值记录。 }
    function GetGroupStats(const AGroupName: string): TBenchStats;

    {** 按分组输出 JSON（按前缀 "/" 分组）。
     *  返回 JSON 对象，键为分组名，值为该组结果数组。
     *  用于仪表盘和分组分析。 }
    function ToJSON_Grouped: string;

    {** 按分组输出 Markdown（按前缀 "/" 分组）。
     *  返回 Markdown 文档，按分组分节显示结果。
     *  用于 PR 注释和文档。 }
    function ToMarkdown_Grouped: string;

    {** 导出分组 JSON 到文件 }
    procedure SaveToJSON_Grouped(const APath: string);

    {** 导出分组 Markdown 到文件 }
    procedure SaveToMarkdown_Grouped(const APath: string);

    {** 按分组输出 HTML（按前缀 "/" 分组）。
     *  返回 HTML 文档，按分组分节显示结果。
     *  用于仪表盘和报告。 }
    function ToHTML_Grouped: string;

    {** 导出分组 HTML 到文件 }
    procedure SaveToHTML_Grouped(const APath: string);

    {** 比较两个分组的统计差异。
     *  分组规则与 GetGroups/GetGroupStats 一致：名称中首个 '/' 前为组名，
     *  无 '/' 时整名为组名。对组内各基准的 NsPerOp 做聚合统计，再用
     *  启发式差异检验 + 近似 p-value（Welch 风格），不是 Mann-Whitney。
     *  返回 TBenchComparison（ratio / p-value / 显著性等）。
     *  当任一分组无结果时返回零值记录（Ratio=0）。 }
    function CompareGroups(const AGroupNameA, AGroupNameB: string): TBenchComparison;

    {** 获取分组回归报告。
     *  对所有分组做两两 CompareGroups，按 AThreshold 分类回归/改进/不变。
     *  AThreshold 必须 > 0，否则抛 EBenchInvalidParam。
     *  分组数 < 2 时返回空报告（TotalComparisons=0）。 }
    function GetGroupRegressionReport(AThreshold: Double): TBenchRegressionReport;

    {** 多基线对比矩阵 — CSV 报告（适合 Excel/Google Sheets）。
     *  与 ToMatrixJSON/ToMatrixHTML 同源，输出 CSV 格式。 }
    function ToMatrixCSV(
      const ABaselines: array of TBaselineData): string;

    {** 导出多基线矩阵 JSON 到文件 }
    procedure SaveToMatrixJSON(const APath: string;
      const ABaselines: array of TBaselineData);

    {** 导出多基线矩阵 HTML 到文件 }
    procedure SaveToMatrixHTML(const APath: string;
      const ABaselines: array of TBaselineData);

    {** 导出多基线矩阵 CSV 到文件 }
    procedure SaveToMatrixCSV(const APath: string;
      const ABaselines: array of TBaselineData);

    {** 与基线对比 }
    function CompareWithBaseline: TBenchComparisonArray;

    {** 两个结果对比（Mann-Whitney U 检验，需 RawSamples）。
     *  ANameA = current（当前结果），ANameB = baseline（基线结果）。
     *  @raises EBenchError 当任一名称不存在时。 }
    function CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;

    {** 保存当前结果为命名基线文件
     *  @raises EBenchError 当保存失败时 }
    procedure SaveBaseline(const APath: string; const AGitHash: string = '');

    {** 追加当前结果到时间线 JSONL 文件 (P1-5) }
    procedure AppendToTimeline(const APath: string);

    {** 多基线对比矩阵 (P2-1)：当前结果 vs N 个基线，返回矩阵 }
    function CompareMultipleBaselines(
      const ABaselines: array of TBaselineData): TMatrixResult;

    {** 多基线对比矩阵 — Console 报告 (P2-1) }
    function ToMatrixReport(
      const ABaselines: array of TBaselineData): string;

    {** 多基线对比矩阵 — HTML 报告 (P2-1) }
    function ToMatrixHTML(
      const ABaselines: array of TBaselineData): string;

    {** 多基线对比矩阵 — JSON 报告 (CI 消费) }
    function ToMatrixJSON(
      const ABaselines: array of TBaselineData): string;

    {** 检测回归（返回 true 表示有回归） }
    function HasRegression(AThreshold: Double): Boolean;

    {** 获取环境信息 }
    function GetEnvironment: TBenchEnvironment;

    {** 属性访问 }
    property Count: Integer read GetCount;
    property Environment: TBenchEnvironment read GetEnvironment;
  end;

  {** 统计分析器接口
   *
   *  功能分组:
   *    基础统计: ComputeStats, Mean, Median, StdDev, Percentile, ComputePercentiles
   *    异常值检测: CountOutliers
   *    假设检验: HasHeuristicDifference*, ComputeApproximatePValue, ComputeMannWhitneyPValue,
   *              KolmogorovSmirnov*, BootstrapTestDifference
   *    贝叶斯估计: BayesianEstimate, BayesianCredibleInterval
   *    聚合: GeometricMean
   *    正态性: LooksNormalHeuristic
   *}
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

    {** 变异系数 CV = StdDev / Mean（用于自适应预热收敛判断）
     *  @returns CV 值；Mean <= 0 时返回 0 }
    function CoefficientOfVariation(const AData: TDoubleArray): Double;

    {** 计算百分位数 }
    function Percentile(const ASorted: TDoubleArray; APercent: Double): Double;

    {** Mann-Whitney U 检验 p-value（非参数，适用于右偏基准数据） }
    function ComputeMannWhitneyPValue(const A, B: TDoubleArray): Double;

    {** 几何均值（多 benchmark ratio 聚合的正确方法）
     *  @edge 空数组返回 1.0；非正 ratio 返回 NaN（调用方应检查 IsDoubleNaN） }
    function GeometricMean(const ARatios: TDoubleArray): Double;

    {** 批量计算百分位（一次排序，多次查询）
     *  E03: 避免在同一数据上重复排序 }
    function ComputePercentiles(const ASamples: TDoubleArray): TPercentileResult;

    {** 单样本 K-S 检验：检验数据是否来自正态分布 N(AMean, AStdDev²)
     *  @edge 空数组返回 D=0, p=1；样本数=1 时 D=0, p=1 }
    function KolmogorovSmirnovNormalTest(const AData: TDoubleArray;
      AMean, AStdDev: Double): TKSTestResult;

    {** 两样本 K-S 检验：检验两个样本是否来自同一分布
     *  @edge 任一数组为空返回 D=0, p=1；任一数组大小=1 时使用近似 }
    function KolmogorovSmirnovTwoSampleTest(const A, B: TDoubleArray): TKSTestResult;

    {** Bootstrap 假设检验 (Phase B.3)
     *  检验两组数据的均值是否有显著差异（Fisher 置换检验）
     *  @param A 第一组数据
     *  @param B 第二组数据
     *  @param AIterations 重采样次数（默认 10000）
     *  @param ASeed PRNG 种子（默认 0 = 使用 monotonic time） }
    function BootstrapTestDifference(const A, B: TDoubleArray;
      AIterations: Integer = 10000; ASeed: UInt64 = 0): TBootstrapTestResult;

    {** 贝叶斯估计 (Phase C.1)
     *  正态-正态共轭模型：给定先验和数据，计算后验分布
     *  @param AData 观测数据
     *  @param APriorMean 先验均值
     *  @param APriorStdDev 先验标准差
     *  @param ASigma 已知的总体标准差（默认 0 = 使用样本标准差） }
    function BayesianEstimate(const AData: TDoubleArray;
      APriorMean, APriorStdDev: Double;
      ASigma: Double = 0): TBayesianEstimate;

    {** 贝叶斯可信区间 (Phase C.2)
     *  计算贝叶斯可信区间（比频率学派置信区间更直观）
     *  @param AData 观测数据
     *  @param APriorMean 先验均值
     *  @param APriorStdDev 先验标准差
     *  @param ALevel 可信水平（默认 0.95）
     *  @param ASigma 已知的总体标准差（默认 0 = 使用样本标准差） }
    function BayesianCredibleInterval(const AData: TDoubleArray;
      APriorMean, APriorStdDev: Double;
      ALevel: Double = 0.95; ASigma: Double = 0): TConfidenceInterval;

    {** 截尾均值（Trimmed Mean）— 去掉两端各 ATrimPct% 后取均值
     *  Go benchstat 使用 20% 截尾均值，基准测试中的鲁棒统计量
     *  @param AData 未排序数据（内部会排序后截取）
     *  @param ATrimPct 每端截取百分比，范围 [0, 50)，默认 20
     *  @edge 空数组返回 0.0；ATrimPct=0 时退化为普通均值 }
    function TrimmedMean(const AData: TDoubleArray;
      ATrimPct: Double = 20.0): Double;

    {** Cohen's d 效应量 — 标准化均值差异
     *  d = (MeanA - MeanB) / PooledStdDev
     *  |d| < 0.2 小，0.2-0.8 中，> 0.8 大
     *  @edge 任一数组为空返回 0.0；合并标准差为 0 时返回 0.0 }
    function CohenD(const A, B: TDoubleArray): Double;

    {** OLS 线性回归: time = intercept + slope * N
     *  用于分离每次迭代的固定开销和可变开销。
     *  在多个迭代次数 N 上运行 benchmark，回归 total_time = α + β*N，
     *  β 就是每次迭代的真实时间，α 是固定开销。
     *  @param AIterCounts 迭代次数数组
     *  @param ATimes 对应的总时间数组
     *  @returns TOLSRegression 包含 Slope、Intercept、RSquared、Valid }
    function ComputeOLSRegression(const AIterCounts, ATimes: TDoubleArray): TOLSRegression;
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

    {** 紧凑摘要（一行结果，适合快速检查） }
    function ToSummary: string;

    {** Markdown 报告（适合 GitHub PR/CI 注释） }
    function ToMarkdown: string;

    {** 保存 Markdown 到文件 }
    procedure SaveToMarkdown(const APath: string);

    {** 多基线矩阵 Console 报告 }
    function GenerateMatrixReport(const AMatrix: TMatrixResult): string;

    {** 多基线矩阵 HTML（含 B/op + allocs/op） }
    function GenerateMatrixHTML(const AMatrix: TMatrixResult): string;

    {** 多基线矩阵 JSON（CI 可消费） }
    function GenerateMatrixJSON(const AMatrix: TMatrixResult): string;
  end;

implementation

end.
