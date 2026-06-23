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

  IBenchContext = nextpas.core.bench.intf.IBenchContext;
  IBenchSuite = nextpas.core.bench.intf.IBenchSuite;
  IBenchResults = nextpas.core.bench.intf.IBenchResults;
  IBenchStatsAnalyzer = nextpas.core.bench.intf.IBenchStatsAnalyzer;

  TBenchFunc = nextpas.core.bench.intf.TBenchFunc;
  TBenchParamFunc = nextpas.core.bench.intf.TBenchParamFunc;
  TBenchLoopFunc = nextpas.core.bench.intf.TBenchLoopFunc;
  TBenchSetupFunc = nextpas.core.bench.intf.TBenchSetupFunc;
  TBenchTeardownFunc = nextpas.core.bench.intf.TBenchTeardownFunc;
  TBenchEntry = nextpas.core.bench.intf.TBenchEntry;

  {** ST-12: 重新导出跨语言报告类型 }
  TCrossLangEntry = nextpas.core.bench.report.TCrossLangEntry;

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

    {** 获取环境信息 }
    function GetEnvironment: TBenchEnvironment;

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
    FBaselineCapacity: Integer;
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
    procedure SaveToJSON(const APath: string);
    procedure SaveToHTML(const APath: string);
    procedure SaveToTSV(const APath: string);
    function CompareWithBaseline: TBenchComparisonArray;
    function HasRegression(AThreshold: Double): Boolean;
    function GetEnvironment: TBenchEnvironment;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.time.format,
  nextpas.core.time.offsetdatetime,
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
  FConfig.MinDurationNs := BENCH_DEFAULT_MIN_DURATION_NS;
  FConfig.MaxIterations := BENCH_DEFAULT_MAX_ITERATIONS;
  FConfig.MinSamples := BENCH_DEFAULT_MIN_SAMPLES;
  FConfig.WarmupIterations := BENCH_DEFAULT_WARMUP_ITERATIONS;
  FConfig.EnableMemoryTracking := True;
  FConfig.EnableParallel := False;
  FConfig.ParallelThreads := BENCH_DEFAULT_PARALLEL_THREADS;
  FConfig.CollectRawSamples := False;
  FConfig.Quiet := False;

  FRunner := TBenchRunner.Create;
  FReportGenerator := TBenchReportGenerator.Create;
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

function TBenchSuite.Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := True;

  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddWithSetup(const AName: string; AFunc: TBenchFunc;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := ASetup;
  LEntry.Teardown := ATeardown;
  LEntry.Condition := True;

  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddWhen(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := ACondition;

  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddParallel(const AName: string; AFunc: TBenchFunc;
  AThreads: Integer): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  Result := Self;
  if AThreads <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.AddParallel: thread count must be > 0');

  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := True;
  LEntry.EnableParallel := True;
  LEntry.ParallelThreads := AThreads;

  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddRange(const AName: string; AFunc: TBenchParamFunc;
  const AParams: array of Int64): IBenchSuite;
var
  LEntry: TBenchEntry;
  LIndex: Integer;
begin
  Result := Self;
  for LIndex := 0 to High(AParams) do
  begin
    LEntry := Default(TBenchEntry);
    LEntry.Name := AName + '/' + IntToStr(AParams[LIndex]);
    LEntry.ParamFunc := AFunc;
    LEntry.ParamValue := AParams[LIndex];
    LEntry.Condition := True;

    if FEntryCount >= FEntryCapacity then
    begin
      if FEntryCapacity = 0 then FEntryCapacity := 8
      else FEntryCapacity := FEntryCapacity * 2;
      SetLength(FEntries, FEntryCapacity);
    end;
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

    if FEntryCount >= FEntryCapacity then
    begin
      if FEntryCapacity = 0 then FEntryCapacity := 8
      else FEntryCapacity := FEntryCapacity * 2;
      SetLength(FEntries, FEntryCapacity);
    end;
    FEntries[FEntryCount] := LEntry;
    Inc(FEntryCount);
  end;
end;

function TBenchSuite.AddLoop(const AName: string; AFunc: TBenchLoopFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Condition := True;
  LEntry.IsLoop := True;
  LEntry.LoopFunc := AFunc;

  if FEntryCount >= FEntryCapacity then
  begin
    if FEntryCapacity = 0 then
      FEntryCapacity := 8
    else
      FEntryCapacity := FEntryCapacity * 2;
    SetLength(FEntries, FEntryCapacity);
  end;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.Clear: IBenchSuite;
begin
  Result := Self;
  FEntryCount := 0;
  SetLength(FEntries, 0);
  FEntryCapacity := 0;
end;

function TBenchSuite.RemoveByName(const AName: string): IBenchSuite;
var
  I, J: Integer;
begin
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
  Result := Self;
  if ADuration.AsNanoseconds <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMinDuration: duration must be > 0');
  FConfig.MinDurationNs := ADuration.AsNanoseconds;
end;

function TBenchSuite.SetMaxIterations(AIters: Int64): IBenchSuite;
begin
  Result := Self;
  if AIters <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMaxIterations: iterations must be > 0');
  FConfig.MaxIterations := AIters;
end;

function TBenchSuite.SetMinSamples(ACount: Integer): IBenchSuite;
begin
  Result := Self;
  if ACount <= 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetMinSamples: sample count must be > 0');
  FConfig.MinSamples := ACount;
end;

function TBenchSuite.SetWarmupIters(ACount: Integer): IBenchSuite;
begin
  Result := Self;
  if ACount < 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetWarmupIters: warmup count must be >= 0');
  FConfig.WarmupIterations := ACount;
end;

function TBenchSuite.EnableMemoryTracking: IBenchSuite;
begin
  Result := Self;
  FConfig.EnableMemoryTracking := True;
end;

function TBenchSuite.DisableMemoryTracking: IBenchSuite;
begin
  Result := Self;
  FConfig.EnableMemoryTracking := False;
end;

function TBenchSuite.CollectRawSamples: IBenchSuite;
begin
  Result := Self;
  FConfig.CollectRawSamples := True;
end;

function TBenchSuite.SetQuiet(AQuiet: Boolean): IBenchSuite;
begin
  Result := Self;
  FConfig.Quiet := AQuiet;
end;

function TBenchSuite.AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
begin
  Result := Self;
  if FBaselineCount >= FBaselineCapacity then
  begin
    if FBaselineCapacity = 0 then
      FBaselineCapacity := 8
    else
      FBaselineCapacity := FBaselineCapacity * 2;
    SetLength(FBaselines, FBaselineCapacity);
  end;
  FBaselines[FBaselineCount].Name := AName;
  FBaselines[FBaselineCount].NsPerOp := ANsPerOp;
  Inc(FBaselineCount);
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
  begin
    if FBaselineCount >= FBaselineCapacity then
    begin
      if FBaselineCapacity = 0 then
        FBaselineCapacity := 8
      else
        FBaselineCapacity := FBaselineCapacity * 2;
      SetLength(FBaselines, FBaselineCapacity);
    end;
    FBaselines[FBaselineCount].Name := LBaselines[I].Name;
    FBaselines[FBaselineCount].NsPerOp := LBaselines[I].NsPerOp;
    Inc(FBaselineCount);
  end;
end;

function TBenchSuite.SetFilter(const AFilter: string): IBenchSuite;
begin
  Result := Self;
  FFilter := AFilter;
end;

function TBenchSuite.SetTimeout(ATimeoutMs: Cardinal): IBenchSuite;
begin
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
  i: Integer;
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

  for i := 0 to FEntryCount - 1 do
  begin
    if not FEntries[i].Condition then
      Continue;

    // ST-04: 条目间超时检查
    if (LTimeoutNs > 0) and (platform_monotonic_ns - LStartNs >= LTimeoutNs) then
    begin
      // 剩余条目标记为 skipped
      LRunResult := Default(TBenchResult);
      LRunResult.Name := FEntries[i].Name;
      LRunResult.Executed := True;
      LRunResult.Skipped := True;
      LRunResult.SkipReason := 'Timeout exceeded';
      LResults[LResultCount] := LRunResult;
      Inc(LResultCount);
      Continue;
    end;

    LRunResult := FRunner.RunOne(FEntries[i]);
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
end;

{ TBenchResults }

constructor TBenchResults.Create(const AResults: array of TBenchResult;
  const AEnvironment: TBenchEnvironment;
  const ABaselines: array of TBenchBaseline);
var
  i: Integer;
begin
  inherited Create;

  FResultCount := Length(AResults);
  SetLength(FResults, FResultCount);
  for i := 0 to FResultCount - 1 do
    FResults[i] := AResults[i];

  FEnvironment := AEnvironment;

  FBaselineCount := Length(ABaselines);
  SetLength(FBaselines, FBaselineCount);
  for i := 0 to FBaselineCount - 1 do
  begin
    FBaselines[i].Name := ABaselines[i].Name;
    FBaselines[i].NsPerOp := ABaselines[i].NsPerOp;
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
  i, j: Integer;
begin
  // 预分配最大可能长度（结果数和基线数的较小值）
  if FResultCount < FBaselineCount then
    SetLength(LComparisons, FResultCount)
  else
    SetLength(LComparisons, FBaselineCount);
  LCount := 0;

  for i := 0 to FResultCount - 1 do
  begin
    for j := 0 to FBaselineCount - 1 do
    begin
      if FResults[i].Name = FBaselines[j].Name then
      begin
        LIdx := LCount;
        LComparisons[LIdx].BaselineName := FBaselines[j].Name;
        LComparisons[LIdx].BaselineNsPerOp := FBaselines[j].NsPerOp;
        LComparisons[LIdx].CurrentNsPerOp := FResults[i].NsPerOp;

        if FBaselines[j].NsPerOp > 0 then
          LComparisons[LIdx].Ratio := FResults[i].NsPerOp / FBaselines[j].NsPerOp
        else
          LComparisons[LIdx].Ratio := 1.0;

        LComparisons[LIdx].HasStatisticalTest := False;
        LComparisons[LIdx].IsSignificant :=
          Abs(LComparisons[LIdx].Ratio - 1.0) > 0.05;
        LComparisons[LIdx].ApproximatePValue := 0.05;

        Inc(LCount);
        Break;
      end;
    end;
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
  i: Integer;
begin
  Result := Default(TBenchResult);
  Result.Name := AName;

  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Name = AName then
    begin
      Result := FResults[i];
      Exit;
    end;
  end;
end;

function TBenchResults.TryGetByName(const AName: string; out AResult: TBenchResult): Boolean;
var
  i: Integer;
begin
  for i := 0 to FResultCount - 1 do
  begin
    if FResults[i].Name = AName then
    begin
      AResult := FResults[i];
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

procedure TBenchResults.SaveStringToFile(const APath, AContent, AFormat: string);
var
  LFile: TextFile;
  LOpened: Boolean;
begin
  LOpened := False;
  AssignFile(LFile, APath);
  try
    try
      Rewrite(LFile);
      LOpened := True;
      WriteLn(LFile, AContent);
    except
      on E: Exception do
        raise EBenchError.CreateFmt('Failed to save %s to "%s": %s', [AFormat, APath, E.Message]);
    end;
  finally
    if LOpened then
      CloseFile(LFile);
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

function TBenchResults.HasRegression(AThreshold: Double): Boolean;
var
  LComparisons: array of TBenchComparison;
  i: Integer;
begin
  LComparisons := GenerateComparisons;

  for i := 0 to High(LComparisons) do
  begin
    if LComparisons[i].Ratio > AThreshold then
      Exit(True);
  end;

  Result := False;
end;

function TBenchResults.GetEnvironment: TBenchEnvironment;
begin
  Result := FEnvironment;
end;

end.
