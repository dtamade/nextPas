{**
 * @desc 基准测试框架门面
 *
 * 提供 TBenchSuite 流式构建器和 TBenchResults 结果集合，
 * 是 bench 模块的统一入口。
 *}
unit nextpas.core.bench;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.stats,
  nextpas.core.bench.runner,
  nextpas.core.bench.run,
  nextpas.core.bench.report,
  nextpas.core.time.base,
  nextpas.core.platform.time,
  nextpas.core.io.linewriter;

type
  {** 重新导出类型 }
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  TBenchStats = nextpas.core.bench.base.TBenchStats;
  TBenchComparison = nextpas.core.bench.base.TBenchComparison;
  TBenchEnvironment = nextpas.core.bench.base.TBenchEnvironment;
  TBenchConfig = nextpas.core.bench.base.TBenchConfig;
  TDoubleArray = nextpas.core.bench.base.TDoubleArray;
  TInt64Array = nextpas.core.bench.base.TInt64Array;
  TBaselineData = nextpas.core.bench.base.TBaselineData;
  TMatrixCell = nextpas.core.bench.base.TMatrixCell;
  TMatrixRow = nextpas.core.bench.base.TMatrixRow;
  TMatrixResult = nextpas.core.bench.base.TMatrixResult;
  TCustomMetric = nextpas.core.bench.base.TCustomMetric;
  TCustomMetricArray = nextpas.core.bench.base.TCustomMetricArray;
  TBenchSummaryStats = nextpas.core.bench.intf.TBenchSummaryStats;
  TBenchRegressionReport = nextpas.core.bench.intf.TBenchRegressionReport;
  TPercentileResult = nextpas.core.bench.intf.TPercentileResult;
  TOutlierSummary = nextpas.core.bench.intf.TOutlierSummary;

  IBenchContext = nextpas.core.bench.intf.IBenchContext;
  IBenchSuite = nextpas.core.bench.intf.IBenchSuite;
  IBenchResults = nextpas.core.bench.intf.IBenchResults;
  IBenchStatsAnalyzer = nextpas.core.bench.intf.IBenchStatsAnalyzer;

  TBenchFunc = nextpas.core.bench.intf.TBenchFunc;
  TBenchSimpleFunc = nextpas.core.bench.intf.TBenchSimpleFunc;
  TBenchParamFunc = nextpas.core.bench.intf.TBenchParamFunc;
  TBenchLoopFunc = nextpas.core.bench.intf.TBenchLoopFunc;
  TBenchLoopContextFunc = nextpas.core.bench.intf.TBenchLoopContextFunc;
  TBenchSetupFunc = nextpas.core.bench.intf.TBenchSetupFunc;
  TBenchTeardownFunc = nextpas.core.bench.intf.TBenchTeardownFunc;

  {** 重新导出执行器（旧 API 兼容：TBenchRunner.Run + Summary） }
  TBenchRunner = nextpas.core.bench.runner.TBenchRunner;

  {** 线程安全执行器（原子结果收集，多线程并发） }
  TBenchRun = nextpas.core.bench.run.TBenchRun;
  PBenchRunResult = nextpas.core.bench.run.PBenchRunResult;

  {** 基准套件 - Fluent Builder 实现 }
  TBenchSuite = class(TInterfacedObject, IBenchSuite)
  private
    FEntries: array of TBenchEntry;
    FEntryCount: Integer;
    FEntryCapacity: Integer;
    FConfig: TBenchConfig;
    FFilter: string;
    FBaselines: array of TBaselineData;
    FBaselineCount: Integer;
    FBaselineCapacity: Integer;
    FRunner: TBenchRunner;
    FReportGenerator: IBenchReportGenerator;
    {** ST-08: prevents mutation after Run has been called }
    FHasRun: Boolean;

    {** 获取环境信息 }
    function GetEnvironment: TBenchEnvironment;

    {** ST-08: guard against post-Run mutation }
    procedure GuardNotRun;

    {** PF-24: 确保条目数组有足够容量 }
    procedure EnsureEntryCapacity;
    {** PF-24: 确保基线数组有足够容量 }
    procedure EnsureBaselineCapacity;

    {** 验证函数指针非 nil (P0-1) }
    procedure GuardAssigned(APtr: Pointer; const AMethod: string);

    {** F-04: 按名称查找条目索引，未找到返回 -1 }
    function FindEntryIndex(const AName: string): Integer;

    {** Add* 方法公共前导：GuardNotRun + Result := Self }
    function BeginAdd: IBenchSuite;

    {** 创建默认条目（Name + Condition=True） }
    function MakeDefaultEntry(const AName: string): TBenchEntry;

    {** 添加条目到内部数组（公共逻辑提取） }
    procedure AppendEntry(const AEntry: TBenchEntry);

  public
    constructor Create(const ASuiteName: string);
    {** ST-11: 使用自定义配置创建基准套件 }
    constructor CreateWithConfig(const ASuiteName: string; const AConfig: TBenchConfig);
    destructor Destroy; override;

    {** IBenchSuite 实现 }
    function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
    function AddSimple(const AName: string; AFunc: TBenchSimpleFunc): IBenchSuite;
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
    {** 用户控制循环 — TBenchLoopFunc 不支持 IBenchContext }
    function AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;
    {** F-01: 用户控制循环 — TBenchLoopContextFunc 支持 IBenchContext }
    function AddLoopWithContext(const AName: string; AFunc: TBenchLoopContextFunc): IBenchSuite;
    function Clear: IBenchSuite;
    function RemoveByName(const AName: string): IBenchSuite;
    function TryRemoveByName(const AName: string): Boolean;
    function SetMinDuration(ADuration: TDuration): IBenchSuite;
    function SetMaxIterations(AIters: Int64): IBenchSuite;
    function SetMinSamples(ACount: Integer): IBenchSuite;
    function SetWarmupIters(ACount: Integer): IBenchSuite;
    function EnableMemoryTracking: IBenchSuite;
    function DisableMemoryTracking: IBenchSuite;
    function CollectRawSamples: IBenchSuite;
    function SetEntryCollectRawSamples(const AName: string;
      ACollect: Boolean): IBenchSuite;
    function SetQuiet(AQuiet: Boolean): IBenchSuite;
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
    function AddBaseline(const AName: string; ANsPerOp: TDuration): IBenchSuite;
    function AddBaselineData(const ABaseline: TBaselineData): IBenchSuite;
    function AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;
    function LoadBaseline(const APath: string): IBenchSuite;
    function TryLoadBaseline(const APath: string): Boolean;
    function SetFilter(const AFilter: string): IBenchSuite;
    function SetTimeout(ADuration: TDuration): IBenchSuite;
    {** B21: 启用自适应预热 }
    function SetAdaptiveWarmup(AEnabled: Boolean;
      ACVThreshold: Double = BENCH_DEFAULT_WARMUP_CV_THRESHOLD;
      AMaxIterations: Integer = BENCH_DEFAULT_WARMUP_MAX_ITERATIONS): IBenchSuite;
    {** B23: Set progress callback }
    function SetOnProgress(ACallback: TBenchProgressCallback): IBenchSuite;
    function SetOutput(const AWriter: ILineWriter): IBenchSuite;
    {** 获取已注册的基准条目数量 }
    function GetEntryCount: Integer;
    {** 检查指定名称的基准条目是否存在 }
    function HasEntry(const AName: string): Boolean;
    function RunParallel(AThreadCount: Integer = 0): IBenchResults;
    function Run: IBenchResults;
  end;

  {** 基准结果集合 - 实现 }
  TBenchResults = class(TInterfacedObject, IBenchResults)
  private
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FEnvironment: TBenchEnvironment;
    FBaselines: array of TBaselineData;
    FBaselineCount: Integer;
    FReportGenerator: IBenchReportGenerator;
    FStatsAnalyzer: TBenchStatsAnalyzer;

    {** 生成基线对比 }
    function GenerateComparisons: TBenchComparisonArray;

    {** ST-27: 通用文件保存辅助方法 }
    procedure SaveStringToFile(const APath, AContent, AFormat: string);

    {** 自定义指标辅助函数 }
    function HasCustomMetric(const AResult: TBenchResult;
      const AMetricName: string): Boolean;
    function GetCustomMetricValue(const AResult: TBenchResult;
      const AMetricName: string): Double;

    {** 从基准名提取分组名（首个 '/' 前；无 '/' 则整名） }
    class function ExtractGroupName(const AName: string): string; static;
    {** 收集指定分组内已执行结果（精确 group 匹配，含 bare 名） }
    function CollectGroupResults(const AGroupName: string): TBenchResultArray;
    {** 收集指定分组内已执行结果的 NsPerOp 数组 }
    function CollectGroupNsPerOp(const AGroupName: string): TDoubleArray;

  public
    constructor Create(const AResults: array of TBenchResult;
      const AEnvironment: TBenchEnvironment;
      const ABaselines: array of TBaselineData);
    destructor Destroy; override;

    {** IBenchResults 实现 }
    function GetAll: TBenchResultArray;
    function GetByName(const AName: string): TBenchResult;
    function TryGetByName(const AName: string; out AResult: TBenchResult): Boolean;
    function GetCount: Integer;
    function GetSkipped: TBenchResultArray;
    function GetExecuted: TBenchResultArray;
    function GetAggregateStats: TBenchStats;
    function FilterByPrefix(const APrefix: string): TBenchResultArray;
    function FilterBySuffix(const ASuffix: string): TBenchResultArray;
    function FilterBySubstring(const ASubstring: string): TBenchResultArray;
    function SortByNsPerOp(AAscending: Boolean = True): TBenchResultArray;
    function GetFastest: TBenchResult;
    function GetSlowest: TBenchResult;
    function GetTopN(ANCount: Integer): TBenchResultArray;
    function GetStableResults(ACVThreshold: Double = 0.1): TBenchResultArray;
    function GetUnstableResults(ACVThreshold: Double = 0.1): TBenchResultArray;
    function FilterByNsPerOpRange(AMinNs: Double = 0; AMaxNs: Double = 0): TBenchResultArray;
    function FilterByNamePattern(const APattern: string): TBenchResultArray;
    function GetSummaryStats: TBenchSummaryStats;
    function GetRegressionReport(AThreshold: Double): TBenchRegressionReport;
    function FilterByHasCustomMetric(const AMetricName: string): TBenchResultArray;
    function GetCustomMetricValues(const AMetricName: string): TDoubleArray;
    function GetPercentileStats: TPercentileResult;
    function GetCVArray: TDoubleArray;
    function GetOutlierSummary: TOutlierSummary;
    function SortByCustomMetric(const AMetricName: string;
      AAscending: Boolean = True): TBenchResultArray;
    function FilterByCustomMetricRange(const AMetricName: string;
      AMin: Double = 0; AMax: Double = 0): TBenchResultArray;
    function GetCustomMetricStats(const AMetricName: string): TBenchStats;
    function GetResultsWithOutliers: TBenchResultArray;
    function GetResultsWithoutOutliers: TBenchResultArray;
    function SortByOpsPerSec(AAscending: Boolean = False): TBenchResultArray;
    function FilterByStdDevRange(AMin: Double = 0;
      AMax: Double = 0): TBenchResultArray;
    function GetGroups: TStringArray;
    function GetGroupStats(const AGroupName: string): TBenchStats;
    function ToJSON_Grouped: string;
    function ToMarkdown_Grouped: string;
    procedure SaveToJSON_Grouped(const APath: string);
    procedure SaveToMarkdown_Grouped(const APath: string);
    function ToHTML_Grouped: string;
    procedure SaveToHTML_Grouped(const APath: string);
    function CompareGroups(const AGroupNameA, AGroupNameB: string): TBenchComparison;
    function GetGroupRegressionReport(AThreshold: Double): TBenchRegressionReport;
    function ToCSV: string;
    function GetTotalOpsPerSec: Double;
    function GetTotalOutliers: Integer;
    function GetTotalIterations: Int64;
    function GetTotalBytesPerOp: Int64;
    function GetTotalAllocsPerOp: Int64;
    function GetTotalElapsed: TDuration;
    function GetAllCustomMetrics: TCustomMetricArray;
    function GetTotalCustomMetricsCount: Integer;
    function PrintToConsole: string;
    function ToJSON: string;
    function ToTSV: string;
    function ToHTML: string;
    function ToBenchstat: string;
    function ToSummary: string;
    function ToMarkdown: string;
    procedure SaveToJSON(const APath: string);
    procedure SaveToHTML(const APath: string);
    procedure SaveToTSV(const APath: string);
    procedure SaveToMarkdown(const APath: string);
    procedure SaveToCSV(const APath: string);
    function CompareWithBaseline: TBenchComparisonArray;
    function CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;
    procedure SaveBaseline(const APath: string; const AGitHash: string = '');
    procedure AppendToTimeline(const APath: string);
    function CompareMultipleBaselines(
      const ABaselines: array of TBaselineData): TMatrixResult;
    function ToMatrixReport(
      const ABaselines: array of TBaselineData): string;
    function ToMatrixHTML(
      const ABaselines: array of TBaselineData): string;
    function ToMatrixJSON(
      const ABaselines: array of TBaselineData): string;
    function ToMatrixCSV(
      const ABaselines: array of TBaselineData): string;
    procedure SaveToMatrixJSON(const APath: string;
      const ABaselines: array of TBaselineData);
    procedure SaveToMatrixHTML(const APath: string;
      const ABaselines: array of TBaselineData);
    procedure SaveToMatrixCSV(const APath: string;
      const ABaselines: array of TBaselineData);
    function HasRegression(AThreshold: Double): Boolean;
    function GetEnvironment: TBenchEnvironment;
  end;

{** 防优化 sink — re-export base（对标 criterion black_box） }
procedure BenchBlackBoxInt64(AValue: Int64); inline;
procedure BenchBlackBoxPtr(APtr: Pointer); inline;
procedure BenchBlackBoxBytes(const AData; ALen: Integer); inline;
function BenchBlackBoxSink: PtrUInt; inline;
procedure BenchBlackBoxReset; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.text.builder,
  nextpas.core.time.format,
  nextpas.core.time.offsetdatetime,
  nextpas.core.json,
  nextpas.core.json.value.writer,
  nextpas.core.bench.baseline,
  nextpas.core.simd.cpuinfo,
  nextpas.core.collections.hashmap.swiss.str,
  nextpas.core.platform.thread,
  nextpas.core.math.scalar;

const
  { 哨兵值：表示"无统计检验数据"，区分于有效 p-value }
  CNoPValue = 0.0 / 0.0; { NaN }

{ TBenchWorkerThread - 并行执行辅助线程 }

type
  TBenchWorkerThread = record
    Entries: array of TBenchEntry;
    EntryCount: Integer;
    Results: array of TBenchResult;
    ResultCount: Integer;
    Config: TBenchConfig;
    Runner: TBenchRunner;
    Handle: TPlatformThreadHandle;
  end;

  PBenchWorkerThread = ^TBenchWorkerThread;

function BenchWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LWorker: PBenchWorkerThread;
  I: Integer;
begin
  Result := nil;
  LWorker := PBenchWorkerThread(AArg);
  for I := 0 to LWorker^.EntryCount - 1 do
  begin
    if not LWorker^.Entries[I].Condition then
    begin
      LWorker^.Results[I] := Default(TBenchResult);
      LWorker^.Results[I].Name := LWorker^.Entries[I].Name;
      LWorker^.Results[I].Executed := True;
      LWorker^.Results[I].Skipped := True;
      Continue;
    end;
    LWorker^.Results[I] := LWorker^.Runner.RunOne(LWorker^.Entries[I]);
    if LWorker^.Results[I].Executed then
      Inc(LWorker^.ResultCount);
  end;
end;

procedure InitWorkerThread(var AWorker: TBenchWorkerThread;
  const ASrcEntries: array of TBenchEntry; ASrcOffset, AEntryCount: Integer;
  const AConfig: TBenchConfig; const AFilter: string);
var
  I: Integer;
begin
  AWorker.EntryCount := AEntryCount;
  SetLength(AWorker.Entries, AEntryCount);
  for I := 0 to AEntryCount - 1 do
    AWorker.Entries[I] := ASrcEntries[ASrcOffset + I];

  AWorker.Config := AConfig;
  AWorker.Runner := TBenchRunner.CreateNoEnv;
  AWorker.Runner.SetConfig(AConfig);
  if AFilter <> '' then
    AWorker.Runner.SetFilter(AFilter);

  AWorker.ResultCount := 0;
  SetLength(AWorker.Results, AEntryCount);
end;

procedure FiniWorkerThread(var AWorker: TBenchWorkerThread);
begin
  AWorker.Runner.Free;
  AWorker.Runner := nil;
  SetLength(AWorker.Entries, 0);
  SetLength(AWorker.Results, 0);
end;

{ TBenchSuite }

constructor TBenchSuite.Create(const ASuiteName: string);
begin
  inherited Create;
  if ASuiteName = '' then
    raise EBenchInvalidParam.Create('TBenchSuite.Create: suite name must not be empty');

  FRunner := TBenchRunner.Create;
  FConfig := FRunner.GetConfig;
  FConfig.SuiteName := ASuiteName;

  FReportGenerator := TBenchReportGenerator.Create;
  FReportGenerator.SetMaxDetailCount(FConfig.MaxDetailCount);
end;

{** ST-11: 使用自定义配置创建，跳过环境变量加载 }
constructor TBenchSuite.CreateWithConfig(const ASuiteName: string; const AConfig: TBenchConfig);
begin
  inherited Create;
  if ASuiteName = '' then
    raise EBenchInvalidParam.Create('TBenchSuite.CreateWithConfig: suite name must not be empty');

  FConfig := AConfig;
  FConfig.SuiteName := ASuiteName;

  FRunner := TBenchRunner.CreateNoEnv;
  FReportGenerator := TBenchReportGenerator.Create;
  FReportGenerator.SetMaxDetailCount(FConfig.MaxDetailCount);
end;

destructor TBenchSuite.Destroy;
begin
  SetLength(FEntries, 0);
  SetLength(FBaselines, 0);
  FRunner.Free;
  FReportGenerator := nil;
  inherited Destroy;
end;

function TBenchSuite.GetEnvironment: TBenchEnvironment;
var
  LLogicalCores: Integer;
begin
  LLogicalCores := GetCPUInfo.LogicalCores;
  Result.OS := {$I %FPCTARGETOS%};
  Result.CPU := {$I %FPCTARGETCPU%};
  if LLogicalCores > 0 then
    Result.Cores := LLogicalCores
  else
    Result.Cores := 0;
  Result.FPCVersion := {$I %FPCVERSION%};
  Result.Timestamp := FormatDateTime('%Y-%m-%dT%H:%M:%S', TOffsetDateTime.Now);
end;

{** ST-08: guard against mutation after Run }
procedure TBenchSuite.GuardNotRun;
begin
  if FHasRun then
    raise EBenchError.Create('Cannot modify suite after Run has been called');
end;

{** PF-24: ensure entry array has capacity for one more element }
procedure TBenchSuite.EnsureEntryCapacity;
begin
  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
end;

{** PF-24: ensure baseline array has capacity for one more element }
procedure TBenchSuite.EnsureBaselineCapacity;
begin
  if FBaselineCount >= FBaselineCapacity then
  begin
    if FBaselineCapacity = 0 then
      FBaselineCapacity := 8
    else
      FBaselineCapacity := FBaselineCapacity * 2;
    SetLength(FBaselines, FBaselineCapacity);
  end;
end;

function TBenchSuite.BeginAdd: IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
end;

function TBenchSuite.MakeDefaultEntry(const AName: string): TBenchEntry;
begin
  Result := Default(TBenchEntry);
  Result.Name := AName;
  Result.Condition := True;
end;

procedure TBenchSuite.AppendEntry(const AEntry: TBenchEntry);
begin
  EnsureEntryCapacity;
  FEntries[FEntryCount] := AEntry;
  Inc(FEntryCount);
end;

procedure TBenchSuite.GuardAssigned(APtr: Pointer; const AMethod: string);
begin
  if APtr = nil then
    raise EBenchInvalidParam.CreateFmt('TBenchSuite.%s: function must not be nil', [AMethod]);
end;

function TBenchSuite.Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(AFunc, 'Add');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.Func := AFunc;
  AppendEntry(LEntry);
end;

function TBenchSuite.AddSimple(const AName: string;
  AFunc: TBenchSimpleFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(Pointer(AFunc), 'AddSimple');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.SimpleFunc := AFunc;
  AppendEntry(LEntry);
end;

function TBenchSuite.AddWithSetup(const AName: string; AFunc: TBenchFunc;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(AFunc, 'AddWithSetup');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.Func := AFunc;
  LEntry.Setup := ASetup;
  LEntry.Teardown := ATeardown;
  AppendEntry(LEntry);
end;

function TBenchSuite.AddWhen(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(AFunc, 'AddWhen');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.Func := AFunc;
  LEntry.Condition := ACondition;
  AppendEntry(LEntry);
end;

function TBenchSuite.AddParallel(const AName: string; AFunc: TBenchFunc;
  AThreads: Integer): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(AFunc, 'AddParallel');
  Result := BeginAdd;
  if AThreads <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.AddParallel: thread count must be > 0');
  LEntry := MakeDefaultEntry(AName);
  LEntry.Func := AFunc;
  LEntry.EnableParallel := True;
  LEntry.ParallelThreads := AThreads;
  AppendEntry(LEntry);
end;

function TBenchSuite.AddRange(const AName: string; AFunc: TBenchParamFunc;
  const AParams: array of Int64): IBenchSuite;
var
  LEntry: TBenchEntry;
  LIndex: Integer;
begin
  GuardAssigned(AFunc, 'AddRange');
  if Length(AParams) = 0 then
    raise EBenchInvalidParam.Create('AddRange: AParams must not be empty');
  Result := BeginAdd;
  for LIndex := 0 to High(AParams) do
  begin
    LEntry := MakeDefaultEntry(AName + '/' + IntToStr(AParams[LIndex]));
    LEntry.ParamFunc := AFunc;
    LEntry.ParamValue := AParams[LIndex];
    AppendEntry(LEntry);
  end;
end;

function TBenchSuite.AddRange(const AName: string; AFunc: TBenchParamFunc;
  const AParams: array of Int64;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
  LIndex: Integer;
begin
  GuardAssigned(AFunc, 'AddRange');
  if Length(AParams) = 0 then
    raise EBenchInvalidParam.Create('AddRange: AParams must not be empty');
  Result := BeginAdd;
  for LIndex := 0 to High(AParams) do
  begin
    LEntry := MakeDefaultEntry(AName + '/' + IntToStr(AParams[LIndex]));
    LEntry.ParamFunc := AFunc;
    LEntry.ParamValue := AParams[LIndex];
    LEntry.Setup := ASetup;
    LEntry.Teardown := ATeardown;
    AppendEntry(LEntry);
  end;
end;

function TBenchSuite.AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(AFunc, 'AddLoop');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.IsLoop := True;
  LEntry.LoopFunc := AFunc;
  AppendEntry(LEntry);
end;

{** F-01: AddLoopWithContext — loop with IBenchContext access }
function TBenchSuite.AddLoopWithContext(const AName: string;
  AFunc: TBenchLoopContextFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardAssigned(Pointer(AFunc), 'AddLoopWithContext');
  Result := BeginAdd;
  LEntry := MakeDefaultEntry(AName);
  LEntry.IsLoop := True;
  LEntry.LoopContextFunc := AFunc;
  AppendEntry(LEntry);
end;

function TBenchSuite.Clear: IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FEntryCount := 0;
  SetLength(FEntries, 0);
  FEntryCapacity := 0;
end;

function TBenchSuite.RemoveByName(const AName: string): IBenchSuite;
var
  LIdx: Integer;
begin
  GuardNotRun;
  Result := Self;
  LIdx := FindEntryIndex(AName);
  if LIdx < 0 then
    raise EBenchInvalidParam.CreateFmt('TBenchSuite.RemoveByName: entry "%s" not found', [AName]);
  { shift remaining entries left }
  for LIdx := LIdx to FEntryCount - 2 do
    FEntries[LIdx] := FEntries[LIdx + 1];
  Dec(FEntryCount);
  { 收缩数组尾部，释放已移除条目的 string 字段 }
  SetLength(FEntries, FEntryCount);
end;

function TBenchSuite.TryRemoveByName(const AName: string): Boolean;
var
  LIdx, J: Integer;
begin
  GuardNotRun;
  LIdx := FindEntryIndex(AName);
  if LIdx < 0 then
    Exit(False);
  for J := LIdx to FEntryCount - 2 do
    FEntries[J] := FEntries[J + 1];
  Dec(FEntryCount);
  SetLength(FEntries, FEntryCount);
  Result := True;
end;

function TBenchSuite.FindEntryIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FEntryCount - 1 do
    if FEntries[I].Name = AName then
      Exit(I);
  Result := -1;
end;

function TBenchSuite.SetEntryCollectRawSamples(const AName: string;
  ACollect: Boolean): IBenchSuite;
var
  LIdx: Integer;
begin
  GuardNotRun;
  Result := Self;
  LIdx := FindEntryIndex(AName);
  if LIdx < 0 then
    raise EBenchInvalidParam.CreateFmt(
      'TBenchSuite.SetEntryCollectRawSamples: entry "%s" not found', [AName]);
  FEntries[LIdx].CollectRawSamples := ACollect;
end;

function TBenchSuite.SetMinDuration(ADuration: TDuration): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ADuration.AsNanoseconds < 1000 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMinDuration: duration must be >= 1 microsecond (1000 ns)');
  FConfig.MinDurationNs := ADuration.AsNanoseconds;
end;

function TBenchSuite.SetMaxIterations(AIters: Int64): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if AIters <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMaxIterations: iterations must be > 0');
  FConfig.MaxIterations := AIters;
end;

function TBenchSuite.SetMinSamples(ACount: Integer): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ACount <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMinSamples: sample count must be > 0');
  FConfig.MinSamples := ACount;
end;

function TBenchSuite.SetWarmupIters(ACount: Integer): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ACount < 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetWarmupIters: warmup count must be >= 0');
  FConfig.WarmupIterations := ACount;
end;

function TBenchSuite.EnableMemoryTracking: IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.EnableMemoryTracking := True;
end;

function TBenchSuite.DisableMemoryTracking: IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.EnableMemoryTracking := False;
end;

function TBenchSuite.CollectRawSamples: IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.CollectRawSamples := True;
end;

function TBenchSuite.SetQuiet(AQuiet: Boolean): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.Quiet := AQuiet;
end;

function TBenchSuite.AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  EnsureBaselineCapacity;
  FBaselines[FBaselineCount].Name := AName;
  FBaselines[FBaselineCount].NsPerOp := ANsPerOp;
  Inc(FBaselineCount);
end;

{** ST-05: TDuration 便利重载 }
function TBenchSuite.AddBaseline(const AName: string; ANsPerOp: TDuration): IBenchSuite;
begin
  Result := AddBaseline(AName, Double(ANsPerOp.AsNanoseconds));
end;

{** F-08: 完整基线数据重载 }
function TBenchSuite.AddBaselineData(const ABaseline: TBaselineData): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  EnsureBaselineCapacity;
  FBaselines[FBaselineCount] := ABaseline;
  Inc(FBaselineCount);
end;

function TBenchSuite.AddBaselines(const ABaselines: array of TBaselineData): IBenchSuite;
var
  I: Integer;
begin
  GuardNotRun;
  Result := Self;
  for I := 0 to High(ABaselines) do
    AddBaselineData(ABaselines[I]);
end;

function TBenchSuite.LoadBaseline(const APath: string): IBenchSuite;
var
  LManager: TBaselineManager;
  LBaselines: TBaselineArray;
  I: Integer;
begin
  GuardNotRun;
  Result := Self;
  LManager := TBaselineManager.Create;
  LManager.LoadFromFile(APath);
  LBaselines := LManager.GetAllBaselines;
  for I := 0 to High(LBaselines) do
    AddBaselineData(LBaselines[I]);
end;

function TBenchSuite.TryLoadBaseline(const APath: string): Boolean;
var
  LManager: TBaselineManager;
  LBaselines: TBaselineArray;
  I: Integer;
begin
  GuardNotRun;
  Result := False;
  try
    LManager := TBaselineManager.Create;
    LManager.LoadFromFile(APath);
    LBaselines := LManager.GetAllBaselines;
    for I := 0 to High(LBaselines) do
      AddBaselineData(LBaselines[I]);
    Result := True;
  except
    { swallow all errors — TryLoadBaseline returns False on failure }
  end;
end;

function TBenchSuite.SetFilter(const AFilter: string): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FFilter := AFilter;
end;

function TBenchSuite.SetTimeout(ADuration: TDuration): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ADuration.AsMilliseconds < 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetTimeout: duration must be >= 0');
  FConfig.TimeoutMs := ADuration.AsMilliseconds;
end;

function TBenchSuite.SetOutput(const AWriter: ILineWriter): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.Output := AWriter;
end;

function TBenchSuite.SetAdaptiveWarmup(AEnabled: Boolean;
  ACVThreshold: Double; AMaxIterations: Integer): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.AdaptiveWarmup := AEnabled;
  if ACVThreshold > 0 then
    FConfig.WarmupCVThreshold := ACVThreshold;
  if AMaxIterations > 0 then
    FConfig.WarmupMaxIterations := AMaxIterations;
end;

function TBenchSuite.SetOnProgress(ACallback: TBenchProgressCallback): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.OnProgress := ACallback;
end;

function TBenchSuite.GetEntryCount: Integer;
begin
  Result := FEntryCount;
end;

function TBenchSuite.HasEntry(const AName: string): Boolean;
begin
  Result := FindEntryIndex(AName) >= 0;
end;

function TBenchSuite.RunParallel(AThreadCount: Integer): IBenchResults;
var
  LResults: array of TBenchResult;
  LResultCount: Integer;
  LEnvironment: TBenchEnvironment;
  LThreadCount: Integer;
  LWorkers: array of TBenchWorkerThread;
  LEntriesPerThread: Integer;
  LRemainder: Integer;
  LStartIdx: Integer;
  LCount: Integer;
  LThreadResults: TBenchResultArray;
  LRetVal: Pointer;
  LWorkerConfig: TBenchConfig;
  I, J: Integer;
begin
  FHasRun := True;

  { 确保 FRunner 配置与 Suite 同步 }
  FRunner.SetConfig(FConfig);
  FRunner.SetFilter(FFilter);

  { 确定线程数 }
  if AThreadCount <= 0 then
  begin
    LThreadCount := GetCPUInfo.LogicalCores;
    if LThreadCount <= 0 then
      LThreadCount := BENCH_DEFAULT_PARALLEL_THREADS;
  end
  else
    LThreadCount := AThreadCount;

  { 限制线程数不超过条目数 }
  if LThreadCount > FEntryCount then
    LThreadCount := FEntryCount;

  { 单条目时退化为串行 }
  if LThreadCount <= 1 then
  begin
    SetLength(LResults, FEntryCount);
    LResultCount := 0;
    LEnvironment := GetEnvironment;
    for I := 0 to FEntryCount - 1 do
    begin
      if not FEntries[I].Condition then
      begin
        LResults[LResultCount] := Default(TBenchResult);
        LResults[LResultCount].Name := FEntries[I].Name;
        LResults[LResultCount].Executed := True;
        LResults[LResultCount].Skipped := True;
      end
      else
        LResults[LResultCount] := FRunner.RunOne(FEntries[I]);
      if LResults[LResultCount].Executed then
        Inc(LResultCount);
    end;
    SetLength(LResults, LResultCount);
    Result := TBenchResults.Create(LResults, LEnvironment, Copy(FBaselines, 0, FBaselineCount));
    Exit;
  end;

  { 创建工作线程 — 禁用内存追踪以避免全局状态竞争，静默模式避免 WriteLn 死锁 }
  LWorkerConfig := FConfig;
  LWorkerConfig.EnableMemoryTracking := False;
  LWorkerConfig.Quiet := True;

  LEntriesPerThread := FEntryCount div LThreadCount;
  LRemainder := FEntryCount mod LThreadCount;

  SetLength(LWorkers, LThreadCount);
  LStartIdx := 0;

  for I := 0 to LThreadCount - 1 do
  begin
    LCount := LEntriesPerThread;
    if I < LRemainder then
      Inc(LCount);

    InitWorkerThread(LWorkers[I], FEntries, LStartIdx, LCount, LWorkerConfig, FFilter);
    Inc(LStartIdx, LCount);
  end;

  { 启动所有线程 }
  for I := 0 to LThreadCount - 1 do
    platform_thread_create(LWorkers[I].Handle, @BenchWorkerProc, @LWorkers[I]);

  { 等待所有线程完成 }
  for I := 0 to LThreadCount - 1 do
    platform_thread_join(LWorkers[I].Handle, LRetVal);

  { 收集结果 — 遍历所有条目（包括 skipped 条件条目） }
  LResultCount := 0;
  for I := 0 to LThreadCount - 1 do
  begin
    LThreadResults := LWorkers[I].Results;
    for J := 0 to LWorkers[I].EntryCount - 1 do
    begin
      // 条件跳过的条目：Executed=True, Skipped=True → 包含
      // 过滤跳过的条目：Executed=False → 跳过
      if LThreadResults[J].Executed then
        Inc(LResultCount);
    end;
  end;

  SetLength(LResults, LResultCount);
  LResultCount := 0;

  for I := 0 to LThreadCount - 1 do
  begin
    LThreadResults := LWorkers[I].Results;
    for J := 0 to LWorkers[I].EntryCount - 1 do
    begin
      if LThreadResults[J].Executed then
      begin
        LResults[LResultCount] := LThreadResults[J];
        Inc(LResultCount);
      end;
    end;
  end;

  { 释放工作线程资源 }
  for I := 0 to LThreadCount - 1 do
    FiniWorkerThread(LWorkers[I]);
  SetLength(LWorkers, 0);

  { 获取环境信息 }
  LEnvironment := GetEnvironment;

  { 构建结果对象 }
  Result := TBenchResults.Create(LResults, LEnvironment, Copy(FBaselines, 0, FBaselineCount));
end;

function TBenchSuite.Run: IBenchResults;
var
  LResults: array of TBenchResult;
  LResultCount: Integer;
  LEnvironment: TBenchEnvironment;
  LRunResult: TBenchResult;
  LStartNs: UInt64;
  LTimeoutNs: UInt64;
  I: Integer;
begin
  FRunner.SetConfig(FConfig);
  FRunner.SetFilter(FFilter);
  FRunner.ClearResults;

  { 确保 Output 已初始化 }
  if FConfig.Output = nil then
    FConfig.Output := CreateConsoleWriter;

  { 输出版本头 }
  if not FConfig.Quiet then
    FConfig.Output.WriteLine('=== nextpas.core.bench v' + BENCH_VERSION + ' ===');

  if (FEntryCount = 0) and (not FConfig.Quiet) then
    FConfig.Output.WriteLine('WARNING: TBenchSuite.Run called with no registered entries');

  { suite 级超时 — 条目间跳过 + 传入 RunOne 中断采样 }
  LTimeoutNs := UInt64(FConfig.TimeoutMs) * 1000000;
  if LTimeoutNs > 0 then
    LStartNs := platform_monotonic_ns
  else
    LStartNs := 0;

  // 预分配最大可能长度
  SetLength(LResults, FEntryCount);
  LResultCount := 0;

  for I := 0 to FEntryCount - 1 do
  begin
    { B23: 进度回调 }
    if Assigned(FConfig.OnProgress) and (FEntryCount > 0) then
      FConfig.OnProgress(FEntries[I].Name, I / FEntryCount, 0);

    if not FEntries[I].Condition then
      Continue;

    // 条目间：已超时则剩余全部 skip（不再启动 RunOne）
    if (LTimeoutNs > 0) and (platform_monotonic_ns - LStartNs >= LTimeoutNs) then
    begin
      LRunResult := Default(TBenchResult);
      LRunResult.Name := FEntries[I].Name;
      LRunResult.Executed := True;
      LRunResult.Skipped := True;
      LRunResult.SkipReason := 'Timeout exceeded';
      LResults[LResultCount] := LRunResult;
      Inc(LResultCount);
      Continue;
    end;

    { pass suite deadline into sampling so long single entries abort }
    LRunResult := FRunner.RunOne(FEntries[I], FConfig.TimeoutMs, LStartNs);
    if LRunResult.Executed then
    begin
      LResults[LResultCount] := LRunResult;
      Inc(LResultCount);
    end;
  end;

  // 截断到实际长度
  SetLength(LResults, LResultCount);

  { B23: 最终进度回调 }
  if Assigned(FConfig.OnProgress) and (FEntryCount > 0) then
    FConfig.OnProgress('', 1.0, 0);

  // 获取环境信息
  LEnvironment := GetEnvironment;

  // 创建结果对象
  Result := TBenchResults.Create(LResults, LEnvironment, Copy(FBaselines, 0, FBaselineCount));
  FHasRun := True;
end;

{ TBenchResults }

constructor TBenchResults.Create(const AResults: array of TBenchResult;
  const AEnvironment: TBenchEnvironment;
  const ABaselines: array of TBaselineData);
var
  I: Integer;
begin
  inherited Create;

  FResultCount := Length(AResults);
  SetLength(FResults, FResultCount);
  for I := 0 to FResultCount - 1 do
    FResults[I] := AResults[I];

  FEnvironment := AEnvironment;

  FBaselineCount := Length(ABaselines);
  SetLength(FBaselines, FBaselineCount);
  for I := 0 to FBaselineCount - 1 do
  begin
    FBaselines[I] := ABaselines[I];
  end;

  FReportGenerator := TBenchReportGenerator.Create;
  { 构造时一次性设置结果和环境，避免每次 To* 方法重复拷贝 }
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  FStatsAnalyzer := TBenchStatsAnalyzer.Create;
end;

destructor TBenchResults.Destroy;
begin
  SetLength(FResults, 0);
  SetLength(FBaselines, 0);
  FReportGenerator := nil;
  FStatsAnalyzer.Free;
  inherited Destroy;
end;

function TBenchResults.GenerateComparisons: TBenchComparisonArray;
type
  TBaselineMap = specialize TSwissTableStr<Integer>;
var
  LComparisons: array of TBenchComparison;
  LCount: Integer;
  LMap: TBaselineMap;
  LJ: Integer;
  I: Integer;
begin
  // 预分配最大可能长度（名称匹配的结果-基线对数）
  if FResultCount < FBaselineCount then
    SetLength(LComparisons, FResultCount)
  else
    SetLength(LComparisons, FBaselineCount);
  LCount := 0;

  // D04: 使用 HashMap 优化 O(n²) 名称匹配为 O(n)
  LMap := TBaselineMap.Create(FBaselineCount * 2);
  try
    // 构建基线名称 → 索引映射
    for I := 0 to FBaselineCount - 1 do
      LMap.Put(FBaselines[I].Name, I);

    for I := 0 to FResultCount - 1 do
    begin
      // O(1) 查找匹配的基线
      if not LMap.TryGetValue(FResults[I].Name, LJ) then
        Continue;

      LComparisons[LCount].BaselineName := FBaselines[LJ].Name;
      LComparisons[LCount].BaselineNsPerOp := FBaselines[LJ].NsPerOp;
      LComparisons[LCount].CurrentNsPerOp := FResults[I].NsPerOp;

      if FBaselines[LJ].NsPerOp > 0 then
        LComparisons[LCount].Ratio := FResults[I].NsPerOp / FBaselines[LJ].NsPerOp
      else
        LComparisons[LCount].Ratio := 1.0;

      { Baseline 只有均值，没有独立方差或原始样本，不能做统计检验 }
      LComparisons[LCount].HasStatisticalTest := False;
      LComparisons[LCount].IsSignificant :=
        Abs(LComparisons[LCount].Ratio - 1.0) > BENCH_MATRIX_DIFF_THRESHOLD;
      LComparisons[LCount].ApproximatePValue := CNoPValue;

      Inc(LCount);
    end;
  finally
    LMap.Free;
  end;

  // 截断到实际长度
  SetLength(LComparisons, LCount);
  Result := LComparisons;
end;

function TBenchResults.GetAll: TBenchResultArray;
var
  I: Integer;
begin
  Result := Copy(FResults, 0, FResultCount);
  { Deep copy: dynamic array fields (RawSamples, CustomMetrics) share references
    after shallow Copy; explicitly copy them to prevent aliasing. }
  for I := 0 to High(Result) do
  begin
    Result[I].RawSamples := Copy(Result[I].RawSamples);
    Result[I].CustomMetrics := Copy(Result[I].CustomMetrics);
  end;
end;

function TBenchResults.GetByName(const AName: string): TBenchResult;
var
  I: Integer;
  LAvailable: string;
begin
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Name = AName then
    begin
      Result := FResults[I];
      Exit;
    end;
  end;
  { 列出可用名称帮助调试 }
  LAvailable := '';
  for I := 0 to FResultCount - 1 do
  begin
    if I >= 5 then
    begin
      LAvailable := LAvailable + ', ...';
      Break;
    end;
    if I > 0 then LAvailable := LAvailable + ', ';
    LAvailable := LAvailable + '"' + FResults[I].Name + '"';
  end;
  raise EBenchError.CreateFmt(
    'Benchmark result not found: "%s". Available: [%s]', [AName, LAvailable]);
end;

function TBenchResults.TryGetByName(const AName: string; out AResult: TBenchResult): Boolean;
var
  I: Integer;
begin
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Name = AName then
    begin
      AResult := FResults[I];
      Exit(True);
    end;
  end;
  Result := False;
  AResult := Default(TBenchResult);
end;

function TBenchResults.GetCount: Integer;
begin
  Result := FResultCount;
end;

function TBenchResults.GetSkipped: TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Skipped then
      Inc(LCount);
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Skipped then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.GetExecuted: TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) then
      Inc(LCount);
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.GetAggregateStats: TBenchStats;
var
  LExecuted: TBenchResultArray;
  LNPerOps: TDoubleArray;
  I: Integer;
begin
  Result := Default(TBenchStats);
  LExecuted := GetExecuted;
  if Length(LExecuted) = 0 then
    Exit;

  LNPerOps := nil;
  SetLength(LNPerOps, Length(LExecuted));
  for I := 0 to High(LExecuted) do
    LNPerOps[I] := LExecuted[I].NsPerOp;

  Result := FStatsAnalyzer.ComputeStats(LNPerOps);
end;

function TBenchResults.FilterByPrefix(const APrefix: string): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (Copy(FResults[I].Name, 1, Length(APrefix)) = APrefix) then
      Inc(LCount);
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (Copy(FResults[I].Name, 1, Length(APrefix)) = APrefix) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.FilterBySuffix(const ASuffix: string): TBenchResultArray;
var
  LCount, I, LIdx, LNameLen, LSuffixLen: Integer;
begin
  LSuffixLen := Length(ASuffix);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LNameLen := Length(FResults[I].Name);
      if (LNameLen >= LSuffixLen) and
         (Copy(FResults[I].Name, LNameLen - LSuffixLen + 1, LSuffixLen) = ASuffix) then
        Inc(LCount);
    end;
  end;
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LNameLen := Length(FResults[I].Name);
      if (LNameLen >= LSuffixLen) and
         (Copy(FResults[I].Name, LNameLen - LSuffixLen + 1, LSuffixLen) = ASuffix) then
      begin
        Result[LIdx] := FResults[I];
        Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
        Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.FilterBySubstring(const ASubstring: string): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (Pos(ASubstring, FResults[I].Name) > 0) then
      Inc(LCount);
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (Pos(ASubstring, FResults[I].Name) > 0) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.SortByNsPerOp(AAscending: Boolean): TBenchResultArray;
var
  I, J, LGap: Integer;
  LTemp: TBenchResult;
begin
  Result := GetExecuted;
  { Shell sort — O(n^1.5) vs selection sort O(n^2)
    Ciura gap sequence, truncated for small arrays }
  LGap := Length(Result);
  while LGap > 1 do
  begin
    LGap := LGap div 2;
    if LGap > 1 then
    begin
      { shrink gap using Knuth sequence: gap := gap div 2 is fine for n < 10000 }
    end;
    for I := LGap to High(Result) do
    begin
      LTemp := Result[I];
      J := I;
      if AAscending then
      begin
        while (J >= LGap) and (Result[J - LGap].NsPerOp > LTemp.NsPerOp) do
        begin
          Result[J] := Result[J - LGap];
          J := J - LGap;
        end;
      end
      else
      begin
        while (J >= LGap) and (Result[J - LGap].NsPerOp < LTemp.NsPerOp) do
        begin
          Result[J] := Result[J - LGap];
          J := J - LGap;
        end;
      end;
      Result[J] := LTemp;
    end;
  end;
end;

function TBenchResults.GetFastest: TBenchResult;
var
  I: Integer;
  LMinNs: Double;
  LIdx: Integer;
begin
  Result := Default(TBenchResult);
  LMinNs := 1.0e308;
  LIdx := -1;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp < LMinNs then
      begin
        LMinNs := FResults[I].NsPerOp;
        LIdx := I;
      end;
    end;
  end;
  if LIdx >= 0 then
    Result := FResults[LIdx];
end;

function TBenchResults.GetSlowest: TBenchResult;
var
  I: Integer;
  LMaxNs: Double;
  LIdx: Integer;
begin
  Result := Default(TBenchResult);
  LMaxNs := -1.0e308;
  LIdx := -1;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp > LMaxNs then
      begin
        LMaxNs := FResults[I].NsPerOp;
        LIdx := I;
      end;
    end;
  end;
  if LIdx >= 0 then
    Result := FResults[LIdx];
end;

function TBenchResults.GetTopN(ANCount: Integer): TBenchResultArray;
var
  LSorted: TBenchResultArray;
  LActual: Integer;
begin
  if ANCount <= 0 then
  begin
    Result := nil;
    Exit;
  end;

  LSorted := SortByNsPerOp(True);
  LActual := ANCount;
  if LActual > Length(LSorted) then
    LActual := Length(LSorted);
  SetLength(Result, LActual);
  if LActual > 0 then
    Move(LSorted[0], Result[0], LActual * SizeOf(TBenchResult));
end;

function TBenchResults.GetStableResults(ACVThreshold: Double): TBenchResultArray;
var
  I, LCount: Integer;
  LCV: Double;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp > 0 then
        LCV := FResults[I].StdDev / FResults[I].NsPerOp
      else
        LCV := 0;
      if LCV < ACVThreshold then
        Inc(LCount);
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp > 0 then
        LCV := FResults[I].StdDev / FResults[I].NsPerOp
      else
        LCV := 0;
      if LCV < ACVThreshold then
      begin
        Result[LCount] := FResults[I];
        Inc(LCount);
      end;
    end;
  end;
end;

function TBenchResults.GetUnstableResults(ACVThreshold: Double): TBenchResultArray;
var
  I, LCount: Integer;
  LCV: Double;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp > 0 then
        LCV := FResults[I].StdDev / FResults[I].NsPerOp
      else
        LCV := 0;
      if LCV >= ACVThreshold then
        Inc(LCount);
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if FResults[I].NsPerOp > 0 then
        LCV := FResults[I].StdDev / FResults[I].NsPerOp
      else
        LCV := 0;
      if LCV >= ACVThreshold then
      begin
        Result[LCount] := FResults[I];
        Inc(LCount);
      end;
    end;
  end;
end;

function TBenchResults.FilterByNsPerOpRange(AMinNs: Double; AMaxNs: Double): TBenchResultArray;
var
  I, LCount: Integer;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if (AMinNs <= 0) or (FResults[I].NsPerOp >= AMinNs) then
      begin
        if (AMaxNs <= 0) or (FResults[I].NsPerOp <= AMaxNs) then
          Inc(LCount);
      end;
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      if (AMinNs <= 0) or (FResults[I].NsPerOp >= AMinNs) then
      begin
        if (AMaxNs <= 0) or (FResults[I].NsPerOp <= AMaxNs) then
        begin
          Result[LCount] := FResults[I];
          Inc(LCount);
        end;
      end;
    end;
  end;
end;

function TBenchResults.FilterByNamePattern(const APattern: string): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
  LPatternLower, LNameLower: string;
begin
  { 显式限定单元：避免 LowerCase/GlobMatch 解析到错误符号 }
  LPatternLower := nextpas.core.text.conv.LowerCase(APattern);
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LNameLower := nextpas.core.text.conv.LowerCase(FResults[I].Name);
      if nextpas.core.bench.base.GlobMatch(LPatternLower, LNameLower) then
        Inc(LCount);
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LNameLower := nextpas.core.text.conv.LowerCase(FResults[I].Name);
      if nextpas.core.bench.base.GlobMatch(LPatternLower, LNameLower) then
      begin
        Result[LIdx] := FResults[I];
        Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
        Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.GetSummaryStats: TBenchSummaryStats;
var
  I: Integer;
  LMinNs, LMaxNs, LTotalNs: Double;
  LNPerOps: TDoubleArray;
  LExecutedCount: Integer;
begin
  Result := Default(TBenchSummaryStats);
  LMinNs := 1.0e308;
  LMaxNs := -1.0e308;
  LTotalNs := 0;
  LExecutedCount := 0;

  { 单遍扫描收集基础聚合 }
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed then
    begin
      if FResults[I].Skipped then
        Inc(Result.SkippedCount)
      else
      begin
        Inc(Result.ExecutedCount);
        Result.TotalOpsPerSec := Result.TotalOpsPerSec + FResults[I].OpsPerSec;
        Result.TotalIterations := Result.TotalIterations + FResults[I].Iterations;
        Result.TotalOutliers := Result.TotalOutliers + FResults[I].Outliers;
        Result.TotalBytesPerOp := Result.TotalBytesPerOp + FResults[I].BytesPerOp;
        Result.TotalAllocsPerOp := Result.TotalAllocsPerOp + FResults[I].AllocsPerOp;
        Result.TotalElapsedNs := Result.TotalElapsedNs + FResults[I].NsPerOp * FResults[I].Iterations;
        Result.CustomMetricsCount := Result.CustomMetricsCount + Length(FResults[I].CustomMetrics);

        if FResults[I].NsPerOp < LMinNs then
          LMinNs := FResults[I].NsPerOp;
        if FResults[I].NsPerOp > LMaxNs then
          LMaxNs := FResults[I].NsPerOp;
        LTotalNs := LTotalNs + FResults[I].NsPerOp;
        Inc(LExecutedCount);
      end;
    end;
  end;

  { 设置最快/最慢 }
  if LExecutedCount > 0 then
  begin
    Result.FastestNsPerOp := LMinNs;
    Result.SlowestNsPerOp := LMaxNs;
    Result.MeanNsPerOp := LTotalNs / LExecutedCount;

    { 计算中位数需要排序 — 只在有结果时执行 }
    LNPerOps := nil;
    SetLength(LNPerOps, LExecutedCount);
    LExecutedCount := 0;
    for I := 0 to FResultCount - 1 do
    begin
      if FResults[I].Executed and (not FResults[I].Skipped) then
      begin
        LNPerOps[LExecutedCount] := FResults[I].NsPerOp;
        Inc(LExecutedCount);
      end;
    end;
    Result.MedianNsPerOp := FStatsAnalyzer.Median(LNPerOps);
  end;
end;

function TBenchResults.GetRegressionReport(AThreshold: Double): TBenchRegressionReport;
var
  I: Integer;
begin
  if AThreshold <= 0 then
    raise EBenchInvalidParam.Create('TBenchResults.GetRegressionReport: threshold must be > 0');

  Result := Default(TBenchRegressionReport);
  Result.Threshold := AThreshold;
  Result.WorstRegressRatio := 1.0;

  Result.Comparisons := GenerateComparisons;
  Result.TotalComparisons := Length(Result.Comparisons);

  for I := 0 to High(Result.Comparisons) do
  begin
    if Result.Comparisons[I].Ratio > AThreshold then
    begin
      Inc(Result.RegressedCount);
      if Result.Comparisons[I].Ratio > Result.WorstRegressRatio then
      begin
        Result.WorstRegressRatio := Result.Comparisons[I].Ratio;
        Result.WorstRegressName := Result.Comparisons[I].BaselineName;
      end;
    end
    else if Result.Comparisons[I].Ratio < (1.0 / AThreshold) then
      Inc(Result.ImprovedCount)
    else
      Inc(Result.UnchangedCount);
  end;

  Result.HasRegression := Result.RegressedCount > 0;
end;

function TBenchResults.FilterByHasCustomMetric(const AMetricName: string): TBenchResultArray;
var
  I, J, LCount, LIdx: Integer;
  LHas: Boolean;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LHas := False;
      for J := 0 to High(FResults[I].CustomMetrics) do
      begin
        if FResults[I].CustomMetrics[J].Name = AMetricName then
        begin
          LHas := True;
          Break;
        end;
      end;
      if LHas then
        Inc(LCount);
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LHas := False;
      for J := 0 to High(FResults[I].CustomMetrics) do
      begin
        if FResults[I].CustomMetrics[J].Name = AMetricName then
        begin
          LHas := True;
          Break;
        end;
      end;
      if LHas then
      begin
        Result[LIdx] := FResults[I];
        Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
        Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.GetCustomMetricValues(const AMetricName: string): TDoubleArray;
var
  I, J, LCount, LIdx: Integer;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      for J := 0 to High(FResults[I].CustomMetrics) do
      begin
        if FResults[I].CustomMetrics[J].Name = AMetricName then
          Inc(LCount);
      end;
    end;
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      for J := 0 to High(FResults[I].CustomMetrics) do
      begin
        if FResults[I].CustomMetrics[J].Name = AMetricName then
        begin
          Result[LIdx] := FResults[I].CustomMetrics[J].Value;
          Inc(LIdx);
        end;
      end;
    end;
  end;
end;

function TBenchResults.GetPercentileStats: TPercentileResult;
var
  I, LCount: Integer;
  LNPerOps: TDoubleArray;
begin
  Result := Default(TPercentileResult);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
      Inc(LCount);
  end;
  if LCount = 0 then
    Exit;

  LNPerOps := nil;
  SetLength(LNPerOps, LCount);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LNPerOps[LCount] := FResults[I].NsPerOp;
      Inc(LCount);
    end;
  end;
  Result := FStatsAnalyzer.ComputePercentiles(LNPerOps);
end;

function TBenchResults.GetCVArray: TDoubleArray;
var
  I, LCount, LIdx: Integer;
begin
  { 第一遍：计数 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
      Inc(LCount);
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      if FResults[I].NsPerOp > 0 then
        Result[LIdx] := FResults[I].StdDev / FResults[I].NsPerOp
      else
        Result[LIdx] := 0;
      Inc(LIdx);
    end;
  end;
end;

function TBenchResults.GetOutlierSummary: TOutlierSummary;
var
  I, LTotalSamples: Integer;
begin
  Result := Default(TOutlierSummary);
  LTotalSamples := 0;

  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      Result.Total := Result.Total + FResults[I].Outliers;
      LTotalSamples := LTotalSamples + FResults[I].SampleCount;

      { 按严重度分级：基于 OutlierMethod 和 OutlierThreshold }
      if FResults[I].OutlierMethod = 'Tukey' then
      begin
        { Tukey 分级：1.5x IQR = mild, 3x = moderate, 10x = severe }
        if FResults[I].OutlierThreshold >= 10.0 then
          Result.Severe := Result.Severe + FResults[I].Outliers
        else if FResults[I].OutlierThreshold >= 3.0 then
          Result.Moderate := Result.Moderate + FResults[I].Outliers
        else
          Result.Mild := Result.Mild + FResults[I].Outliers;
      end
      else
      begin
        { 默认：所有异常值计为 mild }
        Result.Mild := Result.Mild + FResults[I].Outliers;
      end;
    end;
  end;

  if LTotalSamples > 0 then
    Result.Ratio := Result.Total / LTotalSamples;
end;

function TBenchResults.SortByCustomMetric(const AMetricName: string;
  AAscending: Boolean): TBenchResultArray;
var
  I, J, LGap, LCount, LIdx: Integer;
  LTemp: TBenchResult;
  LTempVal: Double;
  LTempHas: Boolean;
  LHasMetric: array of Boolean;
  LValues: array of Double;
  LShouldSwap: Boolean;
begin
  { 两遍：先收集指标值，再排序 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) then
      Inc(LCount);

  Result := nil;
  SetLength(Result, LCount);
  LHasMetric := nil;
  SetLength(LHasMetric, LCount);
  LValues := nil;
  SetLength(LValues, LCount);

  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      LValues[LIdx] := GetCustomMetricValue(FResults[I], AMetricName);
      LHasMetric[LIdx] := HasCustomMetric(FResults[I], AMetricName);
      Inc(LIdx);
    end;
  end;

  { Shell 排序 — 有指标的排前面，无指标的排后面 }
  LGap := LCount;
  while LGap > 1 do
  begin
    LGap := LGap div 2;
    for I := LGap to LCount - 1 do
    begin
      LTemp := Result[I];
      LTempVal := LValues[I];
      LTempHas := LHasMetric[I];
      J := I;
      LShouldSwap := False;
      while J >= LGap do
      begin
        { 有指标 vs 无指标：有指标的排前面 }
        if LTempHas and (not LHasMetric[J - LGap]) then
          Break
        else if (not LTempHas) and LHasMetric[J - LGap] then
          LShouldSwap := True
        else if LTempHas and LHasMetric[J - LGap] then
        begin
          { 两个都有指标：按值比较 }
          if AAscending then
          begin
            if LTempVal >= LValues[J - LGap] then
              Break;
          end
          else
          begin
            if LTempVal <= LValues[J - LGap] then
              Break;
          end;
          LShouldSwap := True;
        end
        else
          { 两个都无指标：保持原序 }
          Break;

        if LShouldSwap then
        begin
          Result[J] := Result[J - LGap];
          LValues[J] := LValues[J - LGap];
          LHasMetric[J] := LHasMetric[J - LGap];
          J := J - LGap;
          LShouldSwap := False;
        end
        else
          Break;
      end;
      Result[J] := LTemp;
      LValues[J] := LTempVal;
      LHasMetric[J] := LTempHas;
    end;
  end;
end;

function TBenchResults.FilterByCustomMetricRange(const AMetricName: string;
  AMin: Double; AMax: Double): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
  LValue: Double;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) and
       HasCustomMetric(FResults[I], AMetricName) then
    begin
      LValue := GetCustomMetricValue(FResults[I], AMetricName);
      if ((AMin <= 0) or (LValue >= AMin)) and
         ((AMax <= 0) or (LValue <= AMax)) then
        Inc(LCount);
    end;
  end;

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) and
       HasCustomMetric(FResults[I], AMetricName) then
    begin
      LValue := GetCustomMetricValue(FResults[I], AMetricName);
      if ((AMin <= 0) or (LValue >= AMin)) and
         ((AMax <= 0) or (LValue <= AMax)) then
      begin
        Result[LIdx] := FResults[I];
        Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
        Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.GetCustomMetricStats(const AMetricName: string): TBenchStats;
var
  LValues: TDoubleArray;
  LCount, I: Integer;
begin
  { 收集所有包含该指标的值 }
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       HasCustomMetric(FResults[I], AMetricName) then
      Inc(LCount);

  if LCount = 0 then
  begin
    Result := Default(TBenchStats);
    Exit;
  end;

  LValues := nil;
  SetLength(LValues, LCount);
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       HasCustomMetric(FResults[I], AMetricName) then
    begin
      LValues[LCount] := GetCustomMetricValue(FResults[I], AMetricName);
      Inc(LCount);
    end;

  Result := FStatsAnalyzer.ComputeStats(LValues);
end;

function TBenchResults.GetResultsWithOutliers: TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (FResults[I].Outliers > 0) then
      Inc(LCount);

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (FResults[I].Outliers > 0) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.GetResultsWithoutOutliers: TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (FResults[I].Outliers = 0) then
      Inc(LCount);

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (FResults[I].Outliers = 0) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.SortByOpsPerSec(AAscending: Boolean): TBenchResultArray;
var
  I, J, LGap, LCount, LIdx: Integer;
  LTemp: TBenchResult;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) then
      Inc(LCount);

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;

  { Shell 排序 }
  LGap := LCount;
  while LGap > 1 do
  begin
    LGap := LGap div 2;
    for I := LGap to LCount - 1 do
    begin
      LTemp := Result[I];
      J := I;
      if AAscending then
      begin
        while (J >= LGap) and (Result[J - LGap].OpsPerSec > LTemp.OpsPerSec) do
        begin
          Result[J] := Result[J - LGap];
          J := J - LGap;
        end;
      end
      else
      begin
        while (J >= LGap) and (Result[J - LGap].OpsPerSec < LTemp.OpsPerSec) do
        begin
          Result[J] := Result[J - LGap];
          J := J - LGap;
        end;
      end;
      Result[J] := LTemp;
    end;
  end;
end;

function TBenchResults.FilterByStdDevRange(AMin: Double;
  AMax: Double): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      if ((AMin <= 0) or (FResults[I].StdDev >= AMin)) and
         ((AMax <= 0) or (FResults[I].StdDev <= AMax)) then
        Inc(LCount);
    end;
  end;

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      if ((AMin <= 0) or (FResults[I].StdDev >= AMin)) and
         ((AMax <= 0) or (FResults[I].StdDev <= AMax)) then
      begin
        Result[LIdx] := FResults[I];
        Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
        Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.GetGroups: TStringArray;
var
  I, J, LCount: Integer;
  LGroupName: string;
  LFound: Boolean;
  LGroups: array of string;
begin
  { 收集所有唯一的分组名称 }
  LGroups := nil;
  SetLength(LGroups, 0);
  LCount := 0;

  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
    begin
      LGroupName := ExtractGroupName(FResults[I].Name);

      { 检查是否已存在 }
      LFound := False;
      for J := 0 to LCount - 1 do
        if LGroups[J] = LGroupName then
        begin
          LFound := True;
          Break;
        end;

      if not LFound then
      begin
        if LCount >= Length(LGroups) then
          SetLength(LGroups, LCount + 16);
        LGroups[LCount] := LGroupName;
        Inc(LCount);
      end;
    end;
  end;

  Result := nil;
  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
    Result[I] := LGroups[I];
end;

function TBenchResults.GetGroupStats(const AGroupName: string): TBenchStats;
var
  LValues: TDoubleArray;
begin
  LValues := CollectGroupNsPerOp(AGroupName);
  if Length(LValues) = 0 then
  begin
    Result := Default(TBenchStats);
    Exit;
  end;

  Result := FStatsAnalyzer.ComputeStats(LValues);
end;

function TBenchResults.ToJSON_Grouped: string;
var
  LGroups: TStringArray;
  LGroupResults: TBenchResultArray;
  LBuilder: TStringBuilder;
  I, J: Integer;
begin
  LGroups := GetGroups;
  LBuilder.Init(256 + FResultCount * 128);
  try
    LBuilder.AppendChar('{');
    for I := 0 to High(LGroups) do
    begin
      if I > 0 then
        LBuilder.AppendChar(',');
      LBuilder.AppendChar('"');
      LBuilder.AppendStr(LGroups[I]);
      LBuilder.AppendStr('":[');

      LGroupResults := CollectGroupResults(LGroups[I]);
      for J := 0 to High(LGroupResults) do
      begin
        if J > 0 then
          LBuilder.AppendChar(',');
        LBuilder.AppendStr('{"name":"');
        LBuilder.AppendStr(LGroupResults[J].Name);
        LBuilder.AppendStr('","nsPerOp":');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].NsPerOp));
        LBuilder.AppendStr(',"opsPerSec":');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].OpsPerSec));
        LBuilder.AppendStr(',"stdDev":');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].StdDev));
        LBuilder.AppendChar('}');
      end;

      LBuilder.AppendChar(']');
    end;
    LBuilder.AppendChar('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TBenchResults.ToMarkdown_Grouped: string;
var
  LGroups: TStringArray;
  LGroupResults: TBenchResultArray;
  LBuilder: TStringBuilder;
  I, J: Integer;
begin
  LGroups := GetGroups;
  LBuilder.Init(256 + FResultCount * 128);
  try
    LBuilder.AppendStr('# Benchmark Results');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr(LineEnding);

    for I := 0 to High(LGroups) do
    begin
      LBuilder.AppendStr('## ');
      LBuilder.AppendStr(LGroups[I]);
      LBuilder.AppendStr(LineEnding);
      LBuilder.AppendStr(LineEnding);

      LBuilder.AppendStr('| Name | ns/op | ops/s | StdDev |');
      LBuilder.AppendStr(LineEnding);
      LBuilder.AppendStr('|------|-------|-------|--------|');
      LBuilder.AppendStr(LineEnding);

      LGroupResults := CollectGroupResults(LGroups[I]);
      for J := 0 to High(LGroupResults) do
      begin
        LBuilder.AppendChar('|');
        LBuilder.AppendStr(LGroupResults[J].Name);
        LBuilder.AppendChar('|');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].NsPerOp));
        LBuilder.AppendChar('|');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].OpsPerSec));
        LBuilder.AppendChar('|');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].StdDev));
        LBuilder.AppendChar('|');
        LBuilder.AppendStr(LineEnding);
      end;

      LBuilder.AppendStr(LineEnding);
    end;

    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure TBenchResults.SaveToJSON_Grouped(const APath: string);
begin
  SaveStringToFile(APath, ToJSON_Grouped, 'GroupedJSON');
end;

procedure TBenchResults.SaveToMarkdown_Grouped(const APath: string);
begin
  SaveStringToFile(APath, ToMarkdown_Grouped, 'GroupedMarkdown');
end;

function TBenchResults.ToHTML_Grouped: string;
var
  LGroups: TStringArray;
  LGroupResults: TBenchResultArray;
  LBuilder: TStringBuilder;
  I, J: Integer;
begin
  LGroups := GetGroups;
  LBuilder.Init(512 + FResultCount * 256);
  try
    LBuilder.AppendStr('<!DOCTYPE html>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<html><head><meta charset="utf-8">');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<title>Benchmark Results</title>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<style>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('body{font-family:system-ui,sans-serif;margin:20px}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('h1{color:#333}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('h2{color:#666;margin-top:30px}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('table{border-collapse:collapse;width:100%}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('th,td{border:1px solid #ddd;padding:8px;text-align:left}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('th{background:#f5f5f5}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('tr:nth-child(even){background:#f9f9f9}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('.summary{margin-top:20px;padding:10px;background:#e8f5e9;border-radius:4px}');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('</style></head><body>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<h1>Benchmark Results</h1>');
    LBuilder.AppendStr(LineEnding);

    for I := 0 to High(LGroups) do
    begin
      LBuilder.AppendStr('<h2>');
      LBuilder.AppendStr(LGroups[I]);
      LBuilder.AppendStr('</h2>');
      LBuilder.AppendStr(LineEnding);

      LBuilder.AppendStr('<table>');
      LBuilder.AppendStr(LineEnding);
      LBuilder.AppendStr('<tr><th>Name</th><th>ns/op</th><th>ops/s</th><th>StdDev</th></tr>');
      LBuilder.AppendStr(LineEnding);

      LGroupResults := CollectGroupResults(LGroups[I]);
      for J := 0 to High(LGroupResults) do
      begin
        LBuilder.AppendStr('<tr>');
        LBuilder.AppendStr('<td>');
        LBuilder.AppendStr(LGroupResults[J].Name);
        LBuilder.AppendStr('</td>');
        LBuilder.AppendStr('<td>');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].NsPerOp));
        LBuilder.AppendStr('</td>');
        LBuilder.AppendStr('<td>');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].OpsPerSec));
        LBuilder.AppendStr('</td>');
        LBuilder.AppendStr('<td>');
        LBuilder.AppendStr(FormatFloat('0.##', LGroupResults[J].StdDev));
        LBuilder.AppendStr('</td>');
        LBuilder.AppendStr('</tr>');
        LBuilder.AppendStr(LineEnding);
      end;

      LBuilder.AppendStr('</table>');
      LBuilder.AppendStr(LineEnding);
    end;

    LBuilder.AppendStr('<div class="summary">');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<p><strong>Total Groups:</strong> ');
    LBuilder.AppendStr(IntToStr(Length(LGroups)));
    LBuilder.AppendStr('</p>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('<p><strong>Total Benchmarks:</strong> ');
    LBuilder.AppendStr(IntToStr(FResultCount));
    LBuilder.AppendStr('</p>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('</div>');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('</body></html>');
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure TBenchResults.SaveToHTML_Grouped(const APath: string);
begin
  SaveStringToFile(APath, ToHTML_Grouped, 'GroupedHTML');
end;

function TBenchResults.CompareGroups(const AGroupNameA, AGroupNameB: string): TBenchComparison;
var
  LValuesA, LValuesB: TDoubleArray;
  LStatsA, LStatsB: TBenchStats;
begin
  Result := Default(TBenchComparison);

  LValuesA := CollectGroupNsPerOp(AGroupNameA);
  if Length(LValuesA) = 0 then
    Exit;

  LValuesB := CollectGroupNsPerOp(AGroupNameB);
  if Length(LValuesB) = 0 then
    Exit;

  LStatsA := FStatsAnalyzer.ComputeStats(LValuesA);
  LStatsB := FStatsAnalyzer.ComputeStats(LValuesB);

  Result.BaselineName := AGroupNameA;
  Result.BaselineNsPerOp := LStatsA.Mean;
  Result.CurrentNsPerOp := LStatsB.Mean;

  if LStatsA.Mean > 0 then
    Result.Ratio := LStatsB.Mean / LStatsA.Mean
  else
    Result.Ratio := 1.0;

  { Group means only — heuristic, NOT a formal statistical test (F-03). }
  Result.IsSignificant := FStatsAnalyzer.HasHeuristicDifference(LStatsA, LStatsB);
  Result.ApproximatePValue := FStatsAnalyzer.ComputeApproximatePValue(LStatsA, LStatsB);
  Result.HasStatisticalTest := False;
end;

function TBenchResults.GetGroupRegressionReport(AThreshold: Double): TBenchRegressionReport;
var
  LGroups: TStringArray;
  I, J, LIdx, LPairCount, LN: Integer;
  LComparisons: TBenchComparisonArray;
begin
  if AThreshold <= 0 then
    raise EBenchInvalidParam.Create('TBenchResults.GetGroupRegressionReport: threshold must be > 0');

  Result := Default(TBenchRegressionReport);
  Result.Threshold := AThreshold;
  Result.WorstRegressRatio := 1.0;

  LGroups := GetGroups;
  LN := Length(LGroups);
  if LN < 2 then
  begin
    Result.Comparisons := nil;
    Result.TotalComparisons := 0;
    Exit;
  end;

  { 两两比较：C(N,2) = N*(N-1)/2 }
  LPairCount := LN * (LN - 1) div 2;
  LComparisons := nil;
  SetLength(LComparisons, LPairCount);
  LIdx := 0;
  for I := 0 to LN - 1 do
    for J := I + 1 to LN - 1 do
    begin
      LComparisons[LIdx] := CompareGroups(LGroups[I], LGroups[J]);
      Inc(LIdx);
    end;

  Result.Comparisons := LComparisons;
  Result.TotalComparisons := LPairCount;

  for I := 0 to High(LComparisons) do
  begin
    if LComparisons[I].Ratio > AThreshold then
    begin
      Inc(Result.RegressedCount);
      if LComparisons[I].Ratio > Result.WorstRegressRatio then
      begin
        Result.WorstRegressRatio := LComparisons[I].Ratio;
        Result.WorstRegressName := LComparisons[I].BaselineName;
      end;
    end
    else if LComparisons[I].Ratio < (1.0 / AThreshold) then
      Inc(Result.ImprovedCount)
    else
      Inc(Result.UnchangedCount);
  end;

  Result.HasRegression := Result.RegressedCount > 0;
end;

function TBenchResults.ToCSV: string;
var
  LBuilder: TStringBuilder;
  I: Integer;

  procedure WriteCSVEscape(const AValue: string);
  begin
    if (Pos(',', AValue) > 0) or (Pos('"', AValue) > 0) or (Pos(#10, AValue) > 0) then
    begin
      LBuilder.AppendChar('"');
      LBuilder.AppendStr(nextpas.core.text.conv.StringReplace(AValue, '"', '""', True));
      LBuilder.AppendChar('"');
    end
    else
      LBuilder.AppendStr(AValue);
  end;

begin
  LBuilder.Init(256 + FResultCount * 128);
  try
    { CSV header }
    LBuilder.AppendStr('Name,Executed,Skipped,NsPerOp,OpsPerSec,StdDev,Median,P95,P99,');
    LBuilder.AppendStr('Iterations,BytesPerOp,AllocsPerOp,Samples,Outliers');
    LBuilder.AppendStr(LineEnding);

    { 数据行 }
    for I := 0 to FResultCount - 1 do
    begin
      WriteCSVEscape(FResults[I].Name);
      LBuilder.AppendChar(',');
      if FResults[I].Executed then LBuilder.AppendStr('true') else LBuilder.AppendStr('false');
      LBuilder.AppendChar(',');
      if FResults[I].Skipped then LBuilder.AppendStr('true') else LBuilder.AppendStr('false');
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].NsPerOp));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].OpsPerSec));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].StdDev));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].Median));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].P95));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', FResults[I].P99));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(IntToStr(FResults[I].Iterations));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(IntToStr(FResults[I].BytesPerOp));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(IntToStr(FResults[I].AllocsPerOp));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(IntToStr(FResults[I].SampleCount));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(IntToStr(FResults[I].Outliers));
      LBuilder.AppendStr(LineEnding);
    end;

    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function TBenchResults.GetTotalOpsPerSec: Double;
{ Sum of per-entry OpsPerSec — NOT a process-wide throughput (F-07). }
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + FResults[I].OpsPerSec;
  end;
end;

function TBenchResults.GetTotalOutliers: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + FResults[I].Outliers;
  end;
end;

function TBenchResults.GetTotalIterations: Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + FResults[I].Iterations;
  end;
end;

function TBenchResults.GetTotalBytesPerOp: Int64;
{ Sum of per-entry BytesPerOp — usually not a physical bandwidth (F-07). }
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + FResults[I].BytesPerOp;
  end;
end;

function TBenchResults.GetTotalAllocsPerOp: Int64;
{ Sum of per-entry AllocsPerOp — display aggregate only (F-07). }
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + FResults[I].AllocsPerOp;
  end;
end;

function TBenchResults.GetTotalElapsed: TDuration;
var
  I: Integer;
  LTotalNs: Double;
begin
  LTotalNs := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      LTotalNs := LTotalNs + FResults[I].NsPerOp * FResults[I].Iterations;
  end;
  Result := TDuration.FromNanoseconds(Round(LTotalNs));
end;

function TBenchResults.GetAllCustomMetrics: TCustomMetricArray;
var
  I, J, LTotal, LIdx: Integer;
begin
  { 第一遍：计数 }
  LTotal := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      LTotal := LTotal + Length(FResults[I].CustomMetrics);
  end;

  { 第二遍：收集 }
  Result := nil;
  SetLength(Result, LTotal);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
    begin
      for J := 0 to High(FResults[I].CustomMetrics) do
      begin
        Result[LIdx] := FResults[I].CustomMetrics[J];
        Inc(LIdx);
      end;
    end;
  end;
end;

function TBenchResults.GetTotalCustomMetricsCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and not FResults[I].Skipped then
      Result := Result + Length(FResults[I].CustomMetrics);
  end;
end;

function TBenchResults.PrintToConsole: string;
begin
  Result := FReportGenerator.PrintToConsole;
end;

function TBenchResults.ToJSON: string;
begin
  Result := FReportGenerator.ToJSON;
end;

function TBenchResults.ToTSV: string;
begin
  Result := FReportGenerator.ToTSV;
end;

function TBenchResults.ToHTML: string;
begin
  Result := FReportGenerator.ToHTML;
end;

function TBenchResults.ToBenchstat: string;
begin
  Result := FReportGenerator.ToBenchstat;
end;

function TBenchResults.ToSummary: string;
begin
  Result := FReportGenerator.ToSummary;
end;

function TBenchResults.ToMarkdown: string;
begin
  Result := FReportGenerator.ToMarkdown;
end;

procedure TBenchResults.SaveStringToFile(const APath, AContent, AFormat: string);
begin
  try
    WriteFileText(APath, AContent, PermDefault);
  except
    on E: Exception do
      raise EBenchError.CreateFmt('Failed to save %s to "%s": %s', [AFormat, APath, E.Message]);
  end;
end;

function TBenchResults.HasCustomMetric(const AResult: TBenchResult;
  const AMetricName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AResult.CustomMetrics) do
    if AResult.CustomMetrics[I].Name = AMetricName then
    begin
      Result := True;
      Exit;
    end;
end;

function TBenchResults.GetCustomMetricValue(const AResult: TBenchResult;
  const AMetricName: string): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AResult.CustomMetrics) do
    if AResult.CustomMetrics[I].Name = AMetricName then
    begin
      Result := AResult.CustomMetrics[I].Value;
      Exit;
    end;
end;

class function TBenchResults.ExtractGroupName(const AName: string): string;
var
  LSlash: Integer;
begin
  LSlash := Pos('/', AName);
  if LSlash > 1 then
    Result := Copy(AName, 1, LSlash - 1)
  else
    Result := AName;
end;

function TBenchResults.CollectGroupResults(const AGroupName: string): TBenchResultArray;
var
  LCount, I, LIdx: Integer;
begin
  LCount := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (ExtractGroupName(FResults[I].Name) = AGroupName) then
      Inc(LCount);

  Result := nil;
  SetLength(Result, LCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
    if FResults[I].Executed and (not FResults[I].Skipped) and
       (ExtractGroupName(FResults[I].Name) = AGroupName) then
    begin
      Result[LIdx] := FResults[I];
      Result[LIdx].RawSamples := Copy(Result[LIdx].RawSamples);
      Result[LIdx].CustomMetrics := Copy(Result[LIdx].CustomMetrics);
      Inc(LIdx);
    end;
end;

function TBenchResults.CollectGroupNsPerOp(const AGroupName: string): TDoubleArray;
var
  LResults: TBenchResultArray;
  I: Integer;
begin
  LResults := CollectGroupResults(AGroupName);
  Result := nil;
  SetLength(Result, Length(LResults));
  for I := 0 to High(LResults) do
    Result[I] := LResults[I].NsPerOp;
end;

procedure TBenchResults.SaveToJSON(const APath: string);
begin
  SaveStringToFile(APath, ToJSON, 'JSON');
end;

procedure TBenchResults.SaveToHTML(const APath: string);
begin
  SaveStringToFile(APath, ToHTML, 'HTML');
end;

procedure TBenchResults.SaveToTSV(const APath: string);
begin
  SaveStringToFile(APath, ToTSV, 'TSV');
end;

procedure TBenchResults.SaveToMarkdown(const APath: string);
begin
  SaveStringToFile(APath, ToMarkdown, 'Markdown');
end;

procedure TBenchResults.SaveToCSV(const APath: string);
begin
  SaveStringToFile(APath, ToCSV, 'CSV');
end;

function TBenchResults.CompareWithBaseline: TBenchComparisonArray;
begin
  Result := GenerateComparisons;
end;

function TBenchResults.CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;
var
  LA, LB: TBenchResult;
  LFoundA, LFoundB: Boolean;
  LPValue: Double;
begin
  Result := Default(TBenchComparison);
  Result.BaselineName := ANameB;
  Result.Ratio := 1.0;

  LFoundA := TryGetByName(ANameA, LA);
  LFoundB := TryGetByName(ANameB, LB);

  if not LFoundA then
    raise EBenchError.CreateFmt('CompareTwoResults: benchmark not found: "%s"', [ANameA]);
  if not LFoundB then
    raise EBenchError.CreateFmt('CompareTwoResults: benchmark not found: "%s"', [ANameB]);

  Result.BaselineNsPerOp := LB.NsPerOp;
  Result.CurrentNsPerOp := LA.NsPerOp;

  if LB.NsPerOp > 0 then
    Result.Ratio := LA.NsPerOp / LB.NsPerOp
  else
    Result.Ratio := 1.0;

  { Mann-Whitney U：需要两组原始样本。无 raw 时不得冒充显著 (F-10). }
  if (Length(LA.RawSamples) > 1) and (Length(LB.RawSamples) > 1) then
  begin
    LPValue := FStatsAnalyzer.ComputeMannWhitneyPValue(LA.RawSamples, LB.RawSamples);
    Result.HasStatisticalTest := True;
    Result.ApproximatePValue := LPValue;
    Result.IsSignificant := LPValue < BENCH_SIGNIFICANCE_ALPHA;
  end
  else
  begin
    Result.HasStatisticalTest := False;
    Result.IsSignificant := False;
    Result.ApproximatePValue := CNoPValue;
  end;
end;

procedure TBenchResults.SaveBaseline(const APath: string; const AGitHash: string);
var
  LManager: TBaselineManager;
  I: Integer;
begin
  LManager := TBaselineManager.Create;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Executed and (not FResults[I].Skipped) then
      LManager.AddBaselineFromResult(FResults[I], AGitHash);
  end;
  LManager.SaveToFile(APath);
end;

procedure TBenchResults.AppendToTimeline(const APath: string);
var
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
  I: Integer;
begin
  LBuilder.Init(256 + FResultCount * 128);
  try
    for I := 0 to FResultCount - 1 do
    begin
      if not (FResults[I].Executed and (not FResults[I].Skipped)) then
        Continue;

      LWriter.Init(LBuilder);
      LWriter.BeginObject;
      LWriter.Key('timestamp');
      LWriter.Str(FEnvironment.Timestamp);
      LWriter.Key('name');
      LWriter.Str(FResults[I].Name);
      LWriter.Key('nsPerOp');
      LWriter.Float(FResults[I].NsPerOp);
      LWriter.Key('opsPerSec');
      LWriter.Float(FResults[I].OpsPerSec);
      LWriter.Key('stddev');
      LWriter.Float(FResults[I].StdDev);
      LWriter.Key('samples');
      LWriter.Int(FResults[I].SampleCount);
      LWriter.Key('bytesPerOp');
      LWriter.Int(FResults[I].BytesPerOp);
      LWriter.Key('allocsPerOp');
      LWriter.Int(FResults[I].AllocsPerOp);
      LWriter.EndObject;
      LBuilder.AppendStr(LineEnding);
    end;

    if LBuilder.Len > 0 then
      AppendFileText(APath, LBuilder.ToString);
  finally
    LBuilder.Done;
  end;
end;

{ P2-1: 多基线对比矩阵 }

function TBenchResults.CompareMultipleBaselines(
  const ABaselines: array of TBaselineData): TMatrixResult;
var
  LNCols: Integer;
  LIdx: Integer;
  LRow: TMatrixRow;
  LCell: TMatrixCell;
  LRatios: array of TDoubleArray;
  LRatioCounts: array of Integer;
  LMatched: Boolean;
  I, J: Integer;
begin
  LNCols := Length(ABaselines);
  Result := Default(TMatrixResult);

  { 初始化基线名称列 }
  SetLength(Result.BaselineNames, LNCols);
  for I := 0 to LNCols - 1 do
    Result.BaselineNames[I] := ABaselines[I].Name;

  { 为每个基线列初始化比率收集器 }
  LRatios := nil;
  SetLength(LRatios, LNCols);
  LRatioCounts := nil;
  SetLength(LRatioCounts, LNCols);
  for J := 0 to LNCols - 1 do
  begin
    SetLength(LRatios[J], FResultCount);
    LRatioCounts[J] := 0;
  end;

  { 对每个当前结果，按 name 匹配基线并计算 ratio }
  SetLength(Result.Rows, FResultCount);
  LIdx := 0;
  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Skipped then
      Continue;

    LRow := Default(TMatrixRow);
    LRow.Name := FResults[I].Name;
    LRow.CurrentNsPerOp := FResults[I].NsPerOp;
    LRow.CurrentStdDev := FResults[I].StdDev;
    LRow.CurrentBytesPerOp := FResults[I].BytesPerOp;
    LRow.CurrentAllocsPerOp := FResults[I].AllocsPerOp;
    SetLength(LRow.Cells, LNCols);

    LMatched := LNCols = 0; { 无基线时默认显示所有结果 }
    for J := 0 to LNCols - 1 do
    begin
      LCell := Default(TMatrixCell);
      { 按 name 匹配：只与同名基线对比 }
      if ABaselines[J].Name = FResults[I].Name then
      begin
        LCell.BaselineNsPerOp := ABaselines[J].NsPerOp;
        if ABaselines[J].NsPerOp > 0 then
          LCell.Ratio := FResults[I].NsPerOp / ABaselines[J].NsPerOp
        else
          LCell.Ratio := 1.0;
        LCell.IsSignificant := Abs(LCell.Ratio - 1.0) > BENCH_MATRIX_DIFF_THRESHOLD;
        LCell.SignificanceThreshold := BENCH_MATRIX_DIFF_THRESHOLD;
        LMatched := True;

        { 收集 ratio 用于计算几何均值 }
        if ABaselines[J].NsPerOp > 0 then
        begin
          LRatios[J][LRatioCounts[J]] := LCell.Ratio;
          Inc(LRatioCounts[J]);
        end;
      end
      else
      begin
        LCell.Ratio := 1.0;
        LCell.IsSignificant := False;
        LCell.SignificanceThreshold := 1.0;
      end;
      LRow.Cells[J] := LCell;
    end;

    { 只有匹配到至少一个基线时才加入结果 }
    if LMatched then
    begin
      Result.Rows[LIdx] := LRow;
      Inc(LIdx);
    end;
  end;
  SetLength(Result.Rows, LIdx);

  { 计算每列的几何均值 }
  SetLength(Result.GeometricMeanRatios, LNCols);
  for J := 0 to LNCols - 1 do
  begin
    if LRatioCounts[J] > 0 then
    begin
      SetLength(LRatios[J], LRatioCounts[J]);
      Result.GeometricMeanRatios[J] := FStatsAnalyzer.GeometricMean(LRatios[J]);
    end
    else
      Result.GeometricMeanRatios[J] := 1.0;
  end;
end;

function TBenchResults.ToMatrixReport(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  Result := FReportGenerator.GenerateMatrixReport(LMatrix);
end;

function TBenchResults.ToMatrixHTML(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  Result := FReportGenerator.GenerateMatrixHTML(LMatrix);
end;

function TBenchResults.ToMatrixJSON(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  Result := FReportGenerator.GenerateMatrixJSON(LMatrix);
end;

function TBenchResults.ToMatrixCSV(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
  LBuilder: TStringBuilder;
  I, J: Integer;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  LBuilder.Init(256 + Length(LMatrix.Rows) * 128);
  try
    { CSV header: Name, CurrentNsPerOp, [Baseline1 Ratio], [Baseline2 Ratio], ... }
    LBuilder.AppendStr('Name,CurrentNsPerOp,CurrentStdDev');
    for J := 0 to High(LMatrix.BaselineNames) do
    begin
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(LMatrix.BaselineNames[J]);
      LBuilder.AppendStr(' Ratio');
    end;
    LBuilder.AppendStr(LineEnding);

    { 数据行 }
    for I := 0 to High(LMatrix.Rows) do
    begin
      LBuilder.AppendStr(LMatrix.Rows[I].Name);
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', LMatrix.Rows[I].CurrentNsPerOp));
      LBuilder.AppendChar(',');
      LBuilder.AppendStr(FormatFloat('0.##', LMatrix.Rows[I].CurrentStdDev));
      for J := 0 to High(LMatrix.Rows[I].Cells) do
      begin
        LBuilder.AppendChar(',');
        LBuilder.AppendStr(FormatFloat('0.####', LMatrix.Rows[I].Cells[J].Ratio));
      end;
      LBuilder.AppendStr(LineEnding);
    end;

    { 几何均值行 }
    if Length(LMatrix.GeometricMeanRatios) > 0 then
    begin
      LBuilder.AppendStr('Geometric Mean,,');
      for J := 0 to High(LMatrix.GeometricMeanRatios) do
      begin
        LBuilder.AppendChar(',');
        LBuilder.AppendStr(FormatFloat('0.####', LMatrix.GeometricMeanRatios[J]));
      end;
      LBuilder.AppendStr(LineEnding);
    end;

    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure TBenchResults.SaveToMatrixJSON(const APath: string;
  const ABaselines: array of TBaselineData);
begin
  SaveStringToFile(APath, ToMatrixJSON(ABaselines), 'MatrixJSON');
end;

procedure TBenchResults.SaveToMatrixHTML(const APath: string;
  const ABaselines: array of TBaselineData);
begin
  SaveStringToFile(APath, ToMatrixHTML(ABaselines), 'MatrixHTML');
end;

procedure TBenchResults.SaveToMatrixCSV(const APath: string;
  const ABaselines: array of TBaselineData);
begin
  SaveStringToFile(APath, ToMatrixCSV(ABaselines), 'MatrixCSV');
end;

function TBenchResults.HasRegression(AThreshold: Double): Boolean;
var
  LComparisons: array of TBenchComparison;
  I: Integer;
begin
  if AThreshold <= 0 then
    raise EBenchInvalidParam.Create('TBenchResults.HasRegression: threshold must be > 0');
  LComparisons := GenerateComparisons;

  for I := 0 to High(LComparisons) do
  begin
    if LComparisons[I].Ratio > AThreshold then
      Exit(True);
  end;

  Result := False;
end;

function TBenchResults.GetEnvironment: TBenchEnvironment;
begin
  Result := FEnvironment;
end;

procedure BenchBlackBoxInt64(AValue: Int64);
begin
  nextpas.core.bench.base.BenchBlackBoxInt64(AValue);
end;

procedure BenchBlackBoxPtr(APtr: Pointer);
begin
  nextpas.core.bench.base.BenchBlackBoxPtr(APtr);
end;

procedure BenchBlackBoxBytes(const AData; ALen: Integer);
begin
  nextpas.core.bench.base.BenchBlackBoxBytes(AData, ALen);
end;

function BenchBlackBoxSink: PtrUInt;
begin
  Result := nextpas.core.bench.base.BenchBlackBoxSink;
end;

procedure BenchBlackBoxReset;
begin
  nextpas.core.bench.base.BenchBlackBoxReset;
end;

end.
