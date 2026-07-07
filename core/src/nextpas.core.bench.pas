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
  TBaselineData = nextpas.core.bench.base.TBaselineData;
  {** @deprecated Use TBaselineData instead. }
  TBenchBaseline = nextpas.core.bench.base.TBaselineData;
  TMatrixCell = nextpas.core.bench.base.TMatrixCell;
  TMatrixRow = nextpas.core.bench.base.TMatrixRow;
  TMatrixResult = nextpas.core.bench.base.TMatrixResult;

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
    procedure GuardFuncAssigned(AFunc: TBenchFunc; const AMethod: string);
    procedure GuardParamFuncAssigned(AFunc: TBenchParamFunc; const AMethod: string);
    procedure GuardLoopFuncAssigned(AFunc: TBenchLoopFunc; const AMethod: string);

    {** F-04: 按名称查找条目索引，未找到返回 -1 }
    function FindEntryIndex(const AName: string): Integer;

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
    function SetTimeout(ATimeoutMs: Int64): IBenchSuite;
    function SetTimeout(ADuration: TDuration): IBenchSuite;
    function EnableObjectPool(AEnabled: Boolean = True): IBenchSuite;
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

    {** 生成基线对比 }
    function GenerateComparisons: TBenchComparisonArray;

    {** ST-27: 通用文件保存辅助方法 }
    procedure SaveStringToFile(const APath, AContent, AFormat: string);

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
    function ToMatrixReport(
      const ABaselines: array of TBaselineData): string;
    function ToMatrixHTML(
      const ABaselines: array of TBaselineData): string;
    function ToMatrixJSON(
      const ABaselines: array of TBaselineData): string;
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
  nextpas.core.simd.cpuinfo,
  nextpas.core.collections.hashmap.swiss.str;

{ TBenchSuite }

constructor TBenchSuite.Create(const ASuiteName: string);
begin
  inherited Create;
  if ASuiteName = '' then
    raise EBenchInvalidParam.Create('TBenchSuite.Create: suite name must not be empty');
  FEntryCount := 0;
  FEntryCapacity := 0;
  SetLength(FEntries, 0);
  FBaselineCount := 0;
  FBaselineCapacity := 0;
  SetLength(FBaselines, 0);

  FRunner := TBenchRunner.Create;
  FConfig := FRunner.GetConfig;
  FConfig.SuiteName := ASuiteName;

  FReportGenerator := TBenchReportGenerator.Create;
  FReportGenerator.SetMaxDetailCount(FConfig.MaxDetailCount);
  FHasRun := False;
end;

{** ST-11: 使用自定义配置创建，跳过环境变量加载 }
constructor TBenchSuite.CreateWithConfig(const ASuiteName: string; const AConfig: TBenchConfig);
begin
  inherited Create;
  if ASuiteName = '' then
    raise EBenchInvalidParam.Create('TBenchSuite.CreateWithConfig: suite name must not be empty');
  FEntryCount := 0;
  FEntryCapacity := 0;
  SetLength(FEntries, 0);
  FBaselineCount := 0;
  FBaselineCapacity := 0;
  SetLength(FBaselines, 0);

  FConfig := AConfig;
  FConfig.SuiteName := ASuiteName;

  FRunner := TBenchRunner.CreateNoEnv;
  FReportGenerator := TBenchReportGenerator.Create;
  FReportGenerator.SetMaxDetailCount(FConfig.MaxDetailCount);
  FHasRun := False;
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

procedure TBenchSuite.GuardFuncAssigned(AFunc: TBenchFunc; const AMethod: string);
begin
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.CreateFmt('TBenchSuite.%s: function must not be nil', [AMethod]);
end;

procedure TBenchSuite.GuardParamFuncAssigned(AFunc: TBenchParamFunc; const AMethod: string);
begin
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.CreateFmt('TBenchSuite.%s: function must not be nil', [AMethod]);
end;

procedure TBenchSuite.GuardLoopFuncAssigned(AFunc: TBenchLoopFunc; const AMethod: string);
begin
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.CreateFmt('TBenchSuite.%s: function must not be nil', [AMethod]);
end;

function TBenchSuite.Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  GuardFuncAssigned(AFunc, 'Add');
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Condition := True;

  EnsureEntryCapacity;
  FEntries[FEntryCount] := LEntry;
  Inc(FEntryCount);
end;

function TBenchSuite.AddSimple(const AName: string;
  AFunc: TBenchSimpleFunc): IBenchSuite;
{ F-03: 存储 SimpleFunc，runner 直接调用 }
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.Create('TBenchSuite.AddSimple: AFunc must not be nil');
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.SimpleFunc := AFunc;
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
  GuardFuncAssigned(AFunc, 'AddWithSetup');
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
  GuardFuncAssigned(AFunc, 'AddWhen');
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
  GuardFuncAssigned(AFunc, 'AddParallel');
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
  GuardParamFuncAssigned(AFunc, 'AddRange');
  if Length(AParams) = 0 then
    raise EBenchInvalidParam.Create('AddRange: AParams must not be empty');
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
  GuardParamFuncAssigned(AFunc, 'AddRange');
  if Length(AParams) = 0 then
    raise EBenchInvalidParam.Create('AddRange: AParams must not be empty');
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
  GuardLoopFuncAssigned(AFunc, 'AddLoop');
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

{** F-01: AddLoopWithContext — loop with IBenchContext access }
function TBenchSuite.AddLoopWithContext(const AName: string;
  AFunc: TBenchLoopContextFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  GuardNotRun;
  if not Assigned(AFunc) then
    raise EBenchInvalidParam.Create('TBenchSuite.AddLoopWithContext: function must not be nil');
  Result := Self;
  LEntry := Default(TBenchEntry);
  LEntry.Name := AName;
  LEntry.Condition := True;
  LEntry.IsLoop := True;
  LEntry.LoopContextFunc := AFunc;

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
  raise EBenchInvalidParam.CreateFmt('TBenchSuite.RemoveByName: entry "%s" not found', [AName]);
end;

function TBenchSuite.TryRemoveByName(const AName: string): Boolean;
var
  I, J: Integer;
begin
  GuardNotRun;
  for I := 0 to FEntryCount - 1 do
  begin
    if FEntries[I].Name = AName then
    begin
      for J := I to FEntryCount - 2 do
        FEntries[J] := FEntries[J + 1];
      Dec(FEntryCount);
      Exit(True);
    end;
  end;
  Result := False;
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
  try
    LManager.LoadFromFile(APath);
  except
    on E: EBenchBaselineNotFound do
      raise;
    on E: Exception do
      raise EBenchError.CreateFmt('Failed to load baseline from "%s": %s', [APath, E.Message]);
  end;
  LBaselines := LManager.GetAllBaselines;

  // 将加载的基线添加到 suite（F-08: 保留完整字段）
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
    try
      LManager.LoadFromFile(APath);
    except
      Exit;
    end;
    LBaselines := LManager.GetAllBaselines;
    for I := 0 to High(LBaselines) do
      AddBaselineData(LBaselines[I]);
    Result := True;
  except
    Exit;
  end;
end;

function TBenchSuite.SetFilter(const AFilter: string): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FFilter := AFilter;
end;

function TBenchSuite.SetTimeout(ATimeoutMs: Int64): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ATimeoutMs < 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetTimeout: timeout must be >= 0');
  FConfig.TimeoutMs := ATimeoutMs;
end;

function TBenchSuite.SetTimeout(ADuration: TDuration): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  if ADuration.AsMilliseconds < 0 then
    raise EBenchInvalidParam.Create('TBenchSuite.SetTimeout: duration must be >= 0');
  FConfig.TimeoutMs := ADuration.AsMilliseconds;
end;

function TBenchSuite.EnableObjectPool(AEnabled: Boolean): IBenchSuite;
begin
  GuardNotRun;
  Result := Self;
  FRunner.EnableObjectPool(AEnabled);
end;

function TBenchSuite.Run: IBenchResults;
var
  LResults: array of TBenchResult;
  LResultCount: Integer;
  LEnvironment: TBenchEnvironment;
  LRunResult: TBenchResult;
  LStartNs: UInt64;
  LTimeoutNs: UInt64;
  LEntryStartNs: UInt64; { F-017 }
  I: Integer;
begin
  FRunner.SetConfig(FConfig);
  FRunner.SetFilter(FFilter);
  FRunner.ClearResults;

  if (FEntryCount = 0) and (not FConfig.Quiet) then
    WriteLn(StdErr, 'WARNING: TBenchSuite.Run called with no registered entries');

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

    // ST-04: 条目间超时检查 (suite-level)
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

    { F-017: per-benchmark timeout check }
    if FEntries[I].TimeoutMs > 0 then
    begin
      LEntryStartNs := platform_monotonic_ns;
      LRunResult := FRunner.RunOne(FEntries[I]);
      if platform_monotonic_ns - LEntryStartNs >= UInt64(FEntries[I].TimeoutMs) * 1000000 then
      begin
        LRunResult.Skipped := True;
        LRunResult.SkipReason := 'Per-benchmark timeout exceeded';
      end;
    end
    else
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
  { F-18: 构造时一次性设置结果和环境，避免每次 To* 方法重复拷贝 }
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
end;

destructor TBenchResults.Destroy;
begin
  SetLength(FResults, 0);
  SetLength(FBaselines, 0);
  FReportGenerator := nil;
  inherited Destroy;
end;

function TBenchResults.GenerateComparisons: TBenchComparisonArray;
type
  TBaselineMap = specialize TSwissTableStr<Integer>;
var
  LComparisons: array of TBenchComparison;
  LCount: Integer;
  LIdx: Integer;
  LAnalyzer: TBenchStatsAnalyzer;
  LBaseStats, LCurrStats: TBenchStats;
  LPValue: Double;
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

    LAnalyzer := TBenchStatsAnalyzer.Create;
    try
      for I := 0 to FResultCount - 1 do
      begin
        // O(1) 查找匹配的基线
        if not LMap.TryGetValue(FResults[I].Name, LJ) then
          Continue;

        LIdx := LCount;
        LComparisons[LIdx].BaselineName := FBaselines[LJ].Name;
        LComparisons[LIdx].BaselineNsPerOp := FBaselines[LJ].NsPerOp;
        LComparisons[LIdx].CurrentNsPerOp := FResults[I].NsPerOp;

        if FBaselines[LJ].NsPerOp > 0 then
          LComparisons[LIdx].Ratio := FResults[I].NsPerOp / FBaselines[LJ].NsPerOp
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
          LBaseStats.Mean := FBaselines[LJ].NsPerOp;
          { 基线没有 StdDev/SampleCount，使用当前结果的作为保守估计 }
          LBaseStats.StdDev := FResults[I].StdDev;
          LBaseStats.SampleCount := FResults[I].SampleCount;

          LPValue := LAnalyzer.ComputeApproximatePValue(LCurrStats, LBaseStats);
          LComparisons[LIdx].HasStatisticalTest := True;
          LComparisons[LIdx].ApproximatePValue := LPValue;
          LComparisons[LIdx].IsSignificant := LPValue < BENCH_SIGNIFICANCE_ALPHA;
        end
        else
        begin
          { 采样不足，退回启发式判断 }
          LComparisons[LIdx].HasStatisticalTest := False;
          LComparisons[LIdx].IsSignificant :=
            Abs(LComparisons[LIdx].Ratio - 1.0) > BENCH_MATRIX_DIFF_THRESHOLD;
          LComparisons[LIdx].ApproximatePValue := BENCH_MATRIX_DIFF_THRESHOLD;
        end;

        Inc(LCount);
      end;
    finally
      LAnalyzer.Free;
    end;
  finally
    LMap.Free;
  end;

  // 截断到实际长度
  SetLength(LComparisons, LCount);
  Result := LComparisons;
end;

function TBenchResults.GetAll: TBenchResultArray;
begin
  Result := Copy(FResults, 0, FResultCount);
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
  { F-09: 列出可用名称帮助调试 }
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

  { Mann-Whitney U 检验：需要两组原始样本 }
  if (Length(LA.RawSamples) > 1) and (Length(LB.RawSamples) > 1) then
  begin
    LAnalyzer := TBenchStatsAnalyzer.Create;
    try
      LPValue := LAnalyzer.ComputeMannWhitneyPValue(LA.RawSamples, LB.RawSamples);
      Result.HasStatisticalTest := True;
      Result.ApproximatePValue := LPValue;
      Result.IsSignificant := LPValue < BENCH_SIGNIFICANCE_ALPHA;
    finally
      LAnalyzer.Free;
    end;
  end
  else
  begin
    { 无原始样本，退回启发式 }
    Result.HasStatisticalTest := False;
    Result.IsSignificant := Abs(Result.Ratio - 1.0) > BENCH_MATRIX_DIFF_THRESHOLD;
    Result.ApproximatePValue := BENCH_MATRIX_DIFF_THRESHOLD;
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
  try
    LManager.SaveToFile(APath);
  except
    on E: Exception do
      raise EBenchError.CreateFmt('Failed to save baseline to "%s": %s', [APath, E.Message]);
  end;
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
  LAnalyzer: TBenchStatsAnalyzer;
  LNCols: Integer;
  LIdx: Integer;
  LRow: TMatrixRow;
  LCell: TMatrixCell;
  LRatios: array of TDoubleArray;
  LRatioCounts: array of Integer;
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
  SetLength(LRatioCounts, LNCols);
  for J := 0 to LNCols - 1 do
  begin
    SetLength(LRatios[J], FResultCount);
    LRatioCounts[J] := 0;
  end;

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
          { R3-04: baseline 无原始样本，用 ratio 阈值替代统计检验 }
          LCell.IsSignificant := Abs(LCell.Ratio - 1.0) > BENCH_MATRIX_DIFF_THRESHOLD;
          LCell.SignificanceThreshold := BENCH_MATRIX_DIFF_THRESHOLD;
        end
        else
        begin
          LCell.Ratio := 1.0;
          LCell.IsSignificant := False;
          LCell.SignificanceThreshold := 1.0;
        end;

        LRow.Cells[J] := LCell;

        { 收集 ratio 用于计算几何均值 }
        LRatios[J][LRatioCounts[J]] := LCell.Ratio;
        Inc(LRatioCounts[J]);
      end;

      Result.Rows[LIdx] := LRow;
      Inc(LIdx);
    end;
    SetLength(Result.Rows, LIdx);

    { 计算每列的几何均值 }
    SetLength(Result.GeometricMeanRatios, LNCols);
    for J := 0 to LNCols - 1 do
    begin
      if LRatioCounts[J] > 0 then
      begin
        SetLength(LRatios[J], LRatioCounts[J]);
        Result.GeometricMeanRatios[J] := LAnalyzer.GeometricMean(LRatios[J]);
      end
      else
        Result.GeometricMeanRatios[J] := 1.0;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

function TBenchResults.ToMatrixReport(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.GenerateMatrixReport(LMatrix);
end;

function TBenchResults.ToMatrixHTML(
  const ABaselines: array of TBaselineData): string;
var
  LMatrix: TMatrixResult;
begin
  LMatrix := CompareMultipleBaselines(ABaselines);
  FReportGenerator.SetResults(FResults);
  Result := FReportGenerator.GenerateMatrixHTML(LMatrix);
end;

function TBenchResults.ToMatrixJSON(
  const ABaselines: array of TBaselineData): string;
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

end.
