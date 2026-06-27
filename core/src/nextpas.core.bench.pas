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
  nextpas.core.bench.report,
  nextpas.core.time.base,
  nextpas.core.platform.time;

type
  {** 重新导出类型 }
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchStats = nextpas.core.bench.base.TBenchStats;
  TBenchComparison = nextpas.core.bench.base.TBenchComparison;
  TBenchEnvironment = nextpas.core.bench.base.TBenchEnvironment;
  TBenchConfig = nextpas.core.bench.base.TBenchConfig;
  TDoubleArray = nextpas.core.bench.base.TDoubleArray;
  TBenchBaseline = nextpas.core.bench.base.TBaselineData;
  TMatrixCell = nextpas.core.bench.base.TMatrixCell;
  TMatrixRow = nextpas.core.bench.base.TMatrixRow;
  TMatrixResult = nextpas.core.bench.base.TMatrixResult;

  IBenchContext = nextpas.core.bench.intf.IBenchContext;
  IBenchSuite = nextpas.core.bench.intf.IBenchSuite;
  IBenchResults = nextpas.core.bench.intf.IBenchResults;
  IBenchStatsAnalyzer = nextpas.core.bench.intf.IBenchStatsAnalyzer;

  TBenchFunc = nextpas.core.bench.intf.TBenchFunc;
  TBenchParamFunc = nextpas.core.bench.intf.TBenchParamFunc;
  TBenchLoopFunc = nextpas.core.bench.intf.TBenchLoopFunc;
  TBenchSetupFunc = nextpas.core.bench.intf.TBenchSetupFunc;
  TBenchTeardownFunc = nextpas.core.bench.intf.TBenchTeardownFunc;

  {** ST-12: 重新导出跨语言报告类型 }
  TCrossLangEntry = nextpas.core.bench.report.TCrossLangEntry;

  {** 重新导出执行器（旧 API 兼容：TBenchRunner.Run + Summary） }
  TBenchRunner = nextpas.core.bench.runner.TBenchRunner;

  {** 基准套件 - Fluent Builder 实现 }
  TBenchSuite = class(TInterfacedObject, IBenchSuite)
  private
    FEntries: array of TBenchEntry;
    FEntryCount: Integer;
    FEntryCapacity: Integer;
    FConfig: TBenchConfig;
    FFilter: string;
    FBaselines: array of TBenchBaseline;
    FBaselineCount: Integer;
    FBaselineCapacity: Integer;
    FRunner: TBenchRunner;
    FReportGenerator: TBenchReportGenerator;
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

  public
    constructor Create(const ASuiteName: string);
    {** ST-11: 使用自定义配置创建基准套件 }
    constructor CreateWithConfig(const ASuiteName: string; const AConfig: TBenchConfig);
    destructor Destroy; override;

    {** IBenchSuite 实现 }
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
    {** 用户控制循环 — TBenchLoopFunc 不支持 IBenchContext }
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
    function AddBaselines(const ABaselines: array of TBenchBaseline): IBenchSuite;
    function LoadBaseline(const APath: string): IBenchSuite;
    function SetFilter(const AFilter: string): IBenchSuite;
    function SetTimeout(ATimeoutMs: Cardinal): IBenchSuite;
    function Run: IBenchResults;
  end;

  {** 基准结果集合 - 实现 }
  TBenchResults = class(TInterfacedObject, IBenchResults)
  private
    FResults: array of TBenchResult;
    FResultCount: Integer;
    FEnvironment: TBenchEnvironment;
    FBaselines: array of TBenchBaseline;
    FBaselineCount: Integer;
    FReportGenerator: TBenchReportGenerator;

    {** 生成基线对比 }
    function GenerateComparisons: TBenchComparisonArray;

    {** ST-27: 通用文件保存辅助方法 }
    procedure SaveStringToFile(const APath, AContent, AFormat: string);

  public
    constructor Create(const AResults: array of TBenchResult;
      const AEnvironment: TBenchEnvironment;
      const ABaselines: array of TBenchBaseline);
    destructor Destroy; override;

    {** IBenchResults 实现 }
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
    function ToMatrixReport(
      const ABaselines: array of TBenchBaseline): string;
    function ToMatrixHTML(
      const ABaselines: array of TBenchBaseline): string;
    function ToMatrixJSON(
      const ABaselines: array of TBenchBaseline): string;
    function HasRegression(AThreshold: Double): Boolean;
    function GetEnvironment: TBenchEnvironment;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.time.format,
  nextpas.core.time.offsetdatetime,
  nextpas.core.json.writer,
  nextpas.core.bench.baseline,
  nextpas.core.simd.cpuinfo;

{ TBenchSuite }

constructor TBenchSuite.Create(const ASuiteName: string);
begin
  inherited Create;
  FEntryCount := 0;
  FEntryCapacity := 0;
  SetLength(FEntries, 0);
  FBaselineCount := 0;
  FBaselineCapacity := 0;
  SetLength(FBaselines, 0);

  // 初始化默认配置
  FConfig := DefaultBenchConfig;
  FConfig.SuiteName := ASuiteName;

  FRunner := TBenchRunner.Create;
  FReportGenerator := TBenchReportGenerator.Create;
  FHasRun := False;
end;

{** ST-11: 使用自定义配置创建，跳过环境变量加载 }
constructor TBenchSuite.CreateWithConfig(const ASuiteName: string; const AConfig: TBenchConfig);
begin
  inherited Create;
  FEntryCount := 0;
  FEntryCapacity := 0;
  SetLength(FEntries, 0);
  FBaselineCount := 0;
  FBaselineCapacity := 0;
  SetLength(FBaselines, 0);

  FConfig := AConfig;
  FConfig.SuiteName := ASuiteName;

  FRunner := TBenchRunner.Create;
  FReportGenerator := TBenchReportGenerator.Create;
  FHasRun := False;
end;

destructor TBenchSuite.Destroy;
begin
  SetLength(FEntries, 0);
  SetLength(FBaselines, 0);
  FRunner.Free;
  FReportGenerator.Free;
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
  Result.Timestamp := FormatDateTime('yyyy-mm-ddThh:nn:ss', TOffsetDateTime.Now);
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

function TBenchSuite.Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := True;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddWithSetup(const AName: string; AFunc: TBenchFunc;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := ASetup;
  LEntry.Teardown := ATeardown;
  LEntry.Condition := True;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddWhen(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := ACondition;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddParallel(const AName: string; AFunc: TBenchFunc;
  AThreads: Integer): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  Result := Self;
  if AThreads <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.AddParallel: thread count must be > 0');

  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := True;
  LEntry.EnableParallel := True;
  LEntry.ParallelThreads := AThreads;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddRange(const AName: string; AFunc: TBenchParamFunc;
  const AParams: array of Int64): IBenchSuite;
var
  LEntry: TBenchEntry;
  LIndex: Integer;
begin
  GuardNotRun;
  Result := Self;
  for LIndex := 0 to High(AParams) do
  begin
    LEntry := Default(TBenchEntry);
    LEntry.Name := AName + '/' + IntToStr(AParams[LIndex]);
    LEntry.ParamFunc := AFunc;
    LEntry.ParamValue := AParams[LIndex];
    LEntry.Condition := True;

    EnsureEntryCapacity;
    FEntries[FEntryCount] := LEntry;
    Inc(FEntryCount);
  end;
end;

function TBenchSuite.AddRange(const AName: string; AFunc: TBenchParamFunc;
  const AParams: array of Int64;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
  LIndex: Integer;
begin
  GuardNotRun;
  Result := Self;
  for LIndex := 0 to High(AParams) do
  begin
    LEntry := Default(TBenchEntry);
    LEntry.Name := AName + '/' + IntToStr(AParams[LIndex]);
    LEntry.ParamFunc := AFunc;
    LEntry.ParamValue := AParams[LIndex];
    LEntry.Setup := ASetup;
    LEntry.Teardown := ATeardown;
    LEntry.Condition := True;

    EnsureEntryCapacity;
    FEntries[FEntryCount] := LEntry;
    Inc(FEntryCount);
  end;
end;

function TBenchSuite.AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Condition := True;
  LEntry.IsLoop := True;
  LEntry.LoopFunc := AFunc;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
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
  I, J: Integer;
begin
  GuardNotRun;
  Result := Self;
  for I := 0 to FEntryCount - 1 do
  begin
    if FEntries[I].Name = AName then
    begin
      // shift remaining entries left
      for J := I to FEntryCount - 2 do
        FEntries[J] := FEntries[J + 1];
      Dec(FEntryCount);
      Exit;
    end;
  end;
end;

function TBenchSuite.SetMinDuration(ADuration: TDuration): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ADuration.AsNanoseconds <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMinDuration: duration must be > 0');
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

function TBenchSuite.AddBaselines(const ABaselines: array of TBenchBaseline): IBenchSuite;
var
  I: Integer;
begin
  Result := Self;
  for I := 0 to High(ABaselines) do
    AddBaseline(ABaselines[I].Name, ABaselines[I].NsPerOp);
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
  try
    LManager.LoadFromFile(APath);
  except
    on E: Exception do
      raise EBenchError.CreateFmt('Failed to load baseline from "%s": %s', [APath, E.Message]);
  end;
  LBaselines := LManager.GetAllBaselines;

  // 将加载的基线添加到 suite
  for I := 0 to High(LBaselines) do
    AddBaseline(LBaselines[I].Name, LBaselines[I].NsPerOp);
end;

function TBenchSuite.SetFilter(const AFilter: string): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FFilter := AFilter;
end;

function TBenchSuite.SetTimeout(ATimeoutMs: Cardinal): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FConfig.TimeoutMs := ATimeoutMs;
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

  // ST-04: 超时检查初始化
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
    if not FEntries[I].Condition then
      Continue;

    // ST-04: 条目间超时检查
    if (LTimeoutNs > 0) and (platform_monotonic_ns - LStartNs >= LTimeoutNs) then
    begin
      // 剩余条目标记为 skipped
      LRunResult := Default(TBenchResult);
      LRunResult.Name := FEntries[I].Name;
      LRunResult.Executed := True;
      LRunResult.Skipped := True;
      LRunResult.SkipReason := 'Timeout exceeded';
      LResults[LResultCount] := LRunResult;
      Inc(LResultCount);
      Continue;
    end;

    LRunResult := FRunner.RunOne(FEntries[I]);
    if LRunResult.Executed then
    begin
      LResults[LResultCount] := LRunResult;
      Inc(LResultCount);
    end;
  end;

  // 截断到实际长度
  SetLength(LResults, LResultCount);

  // 获取环境信息
  LEnvironment := GetEnvironment;

  // 创建结果对象
  Result := TBenchResults.Create(LResults, LEnvironment, Copy(FBaselines, 0, FBaselineCount));
  { ST-08: mark suite as having been run }
  FHasRun := True;
end;

{ TBenchResults }

constructor TBenchResults.Create(const AResults: array of TBenchResult;
  const AEnvironment: TBenchEnvironment;
  const ABaselines: array of TBenchBaseline);
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
    FBaselines[I].Name := ABaselines[I].Name;
    FBaselines[I].NsPerOp := ABaselines[I].NsPerOp;
  end;

  FReportGenerator := TBenchReportGenerator.Create;
end;

destructor TBenchResults.Destroy;
begin
  SetLength(FResults, 0);
  SetLength(FBaselines, 0);
  FReportGenerator.Free;
  inherited Destroy;
end;

function TBenchResults.GenerateComparisons: TBenchComparisonArray;
var
  LComparisons: array of TBenchComparison;
  LCount: Integer;
  LIdx: Integer;
  LAnalyzer: TBenchStatsAnalyzer;
  LBaseStats, LCurrStats: TBenchStats;
  LPValue: Double;
  I, J: Integer;
begin
  // 预分配最大可能长度（结果数和基线数的较小值）
  if FResultCount < FBaselineCount then
    SetLength(LComparisons, FResultCount)
  else
    SetLength(LComparisons, FBaselineCount);
  LCount := 0;

  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    for I := 0 to FResultCount - 1 do
    begin
      for j := 0 to FBaselineCount - 1 do
      begin
        if FResults[I].Name = FBaselines[J].Name then
        begin
          LIdx := LCount;
          LComparisons[LIdx].BaselineName := FBaselines[J].Name;
          LComparisons[LIdx].BaselineNsPerOp := FBaselines[J].NsPerOp;
          LComparisons[LIdx].CurrentNsPerOp := FResults[I].NsPerOp;

          if FBaselines[J].NsPerOp > 0 then
            LComparisons[LIdx].Ratio := FResults[I].NsPerOp / FBaselines[J].NsPerOp
          else
            LComparisons[LIdx].Ratio := 1.0;

          { Welch's t-test: 用当前结果的采样统计量与基线做对比 }
          if (FResults[I].SampleCount > 1) and (FResults[I].StdDev > 0) then
          begin
            LCurrStats := Default(TBenchStats);
            LCurrStats.Mean := FResults[I].NsPerOp;
            LCurrStats.StdDev := FResults[I].StdDev;
            LCurrStats.SampleCount := FResults[I].SampleCount;

            LBaseStats := Default(TBenchStats);
            LBaseStats.Mean := FBaselines[J].NsPerOp;
            { 基线没有 StdDev/SampleCount，使用当前结果的作为保守估计 }
            LBaseStats.StdDev := FResults[I].StdDev;
            LBaseStats.SampleCount := FResults[I].SampleCount;

            LPValue := LAnalyzer.ComputeApproximatePValue(LCurrStats, LBaseStats);
            LComparisons[LIdx].HasStatisticalTest := True;
            LComparisons[LIdx].ApproximatePValue := LPValue;
            LComparisons[LIdx].IsSignificant := LPValue < 0.05;
          end
          else
          begin
            { 采样不足，退回启发式判断 }
            LComparisons[LIdx].HasStatisticalTest := False;
            LComparisons[LIdx].IsSignificant :=
              Abs(LComparisons[LIdx].Ratio - 1.0) > 0.05;
            LComparisons[LIdx].ApproximatePValue := 0.05;
          end;

          Inc(LCount);
          Break;
        end;
      end;
    end;
  finally
    LAnalyzer.Free;
  end;

  // 截断到实际长度
  SetLength(LComparisons, LCount);
  Result := LComparisons;
end;

function TBenchResults.GetAll: TBenchResultArray;
begin
  Result := FResults;
end;

function TBenchResults.GetByName(const AName: string): TBenchResult;
var
  I: Integer;
begin
  Result := Default(TBenchResult);
  Result.Name := AName;

  for I := 0 to FResultCount - 1 do
  begin
    if FResults[I].Name = AName then
    begin
      Result := FResults[I];
      Exit;
    end;
  end;
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

function TBenchResults.PrintToConsole: string;
begin
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  Result := FReportGenerator.PrintToConsole;
end;

function TBenchResults.ToJSON: string;
begin
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  Result := FReportGenerator.ToJSON;
end;

function TBenchResults.ToTSV: string;
begin
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  Result := FReportGenerator.ToTSV;
end;

function TBenchResults.ToHTML: string;
begin
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  Result := FReportGenerator.ToHTML;
end;

function TBenchResults.ToBenchstat: string;
begin
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.ToBenchstat;
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

function TBenchResults.CompareWithBaseline: TBenchComparisonArray;
begin
  Result := GenerateComparisons;
end;

function TBenchResults.CompareTwoResults(const ANameA, ANameB: string): TBenchComparison;
var
  LA, LB: TBenchResult;
  LFoundA, LFoundB: Boolean;
  LAnalyzer: TBenchStatsAnalyzer;
  LPValue: Double;
begin
  Result := Default(TBenchComparison);
  Result.BaselineName := ANameB;
  Result.Ratio := 1.0;

  LFoundA := TryGetByName(ANameA, LA);
  LFoundB := TryGetByName(ANameB, LB);

  if (not LFoundA) or (not LFoundB) then
    Exit;

  Result.BaselineNsPerOp := LB.NsPerOp;
  Result.CurrentNsPerOp := LA.NsPerOp;

  if LB.NsPerOp > 0 then
    Result.Ratio := LA.NsPerOp / LB.NsPerOp
  else
    Result.Ratio := 1.0;

  { Mann-Whitney U 检验：需要两组原始样本 }
  if (Length(LA.RawSamples) > 1) and (Length(LB.RawSamples) > 1) then
  begin
    LAnalyzer := TBenchStatsAnalyzer.Create;
    try
      LPValue := LAnalyzer.ComputeMannWhitneyPValue(LA.RawSamples, LB.RawSamples);
      Result.HasStatisticalTest := True;
      Result.ApproximatePValue := LPValue;
      Result.IsSignificant := LPValue < 0.05;
    finally
      LAnalyzer.Free;
    end;
  end
  else
  begin
    { 无原始样本，退回启发式 }
    Result.HasStatisticalTest := False;
    Result.IsSignificant := Abs(Result.Ratio - 1.0) > 0.05;
    Result.ApproximatePValue := 0.05;
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
  LLine: string;
begin
  for I := 0 to FResultCount - 1 do
  begin
    if not (FResults[I].Executed and (not FResults[I].Skipped)) then
      Continue;

    LBuilder.Init(256);
    try
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
      LLine := LBuilder.ToString;
    finally
      LBuilder.Done;
    end;

    { 追加一行 JSON 到文件 }
    try
      AppendFileText(APath, LLine + LineEnding);
    except
      { 文件不存在时创建 }
      WriteFileText(APath, LLine + LineEnding, PermDefault);
    end;
  end;
end;

{ P2-1: 多基线对比矩阵 }

function TBenchResults.CompareMultipleBaselines(
  const ABaselines: array of TBenchBaseline): TMatrixResult;
var
  LAnalyzer: TBenchStatsAnalyzer;
  LNCols: Integer;
  LIdx: Integer;
  LRow: TMatrixRow;
  LCell: TMatrixCell;
  LRatios: array of TDoubleArray;
  I, J: Integer;
begin
  LNCols := Length(ABaselines);
  Result := Default(TMatrixResult);

  { 初始化基线名称列 }
  SetLength(Result.BaselineNames, LNCols);
  for I := 0 to LNCols - 1 do
    Result.BaselineNames[I] := ABaselines[I].Name;

  { 为每个基线列初始化比率收集器 }
  SetLength(LRatios, LNCols);
  for J := 0 to LNCols - 1 do
    SetLength(LRatios[J], 0);

  LAnalyzer := TBenchStatsAnalyzer.Create;
  try
    { 对每个当前结果，查找匹配的基线并计算 ratio }
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

      for J := 0 to LNCols - 1 do
      begin
        LCell := Default(TMatrixCell);
        if ABaselines[J].NsPerOp > 0 then
        begin
          LCell.BaselineNsPerOp := ABaselines[J].NsPerOp;
          LCell.Ratio := FResults[I].NsPerOp / ABaselines[J].NsPerOp;
          { 基线无原始样本，无法做 Mann-Whitney U，用 ratio 启发式 }
          LCell.IsSignificant := Abs(LCell.Ratio - 1.0) > 0.05;
          LCell.PValue := 0.05;
        end
        else
        begin
          LCell.Ratio := 1.0;
          LCell.IsSignificant := False;
          LCell.PValue := 1.0;
        end;

        LRow.Cells[J] := LCell;

        { 收集 ratio 用于计算几何均值 }
        SetLength(LRatios[J], Length(LRatios[J]) + 1);
        LRatios[J][High(LRatios[J])] := LCell.Ratio;
      end;

      Result.Rows[LIdx] := LRow;
      Inc(LIdx);
    end;
    SetLength(Result.Rows, LIdx);

    { 计算每列的几何均值 }
    SetLength(Result.GeometricMeanRatios, LNCols);
    for J := 0 to LNCols - 1 do
    begin
      if Length(LRatios[J]) > 0 then
        Result.GeometricMeanRatios[J] := LAnalyzer.GeometricMean(LRatios[J])
      else
        Result.GeometricMeanRatios[J] := 1.0;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

function TBenchResults.ToMatrixReport(
  const ABaselines: array of TBenchBaseline): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.GenerateMatrixReport(LMatrix);
end;

function TBenchResults.ToMatrixHTML(
  const ABaselines: array of TBenchBaseline): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.GenerateMatrixHTML(LMatrix);
end;

function TBenchResults.ToMatrixJSON(
  const ABaselines: array of TBenchBaseline): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.GenerateMatrixJSON(LMatrix);
end;

function TBenchResults.HasRegression(AThreshold: Double): Boolean;
var
  LComparisons: array of TBenchComparison;
  I: Integer;
begin
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

end.
