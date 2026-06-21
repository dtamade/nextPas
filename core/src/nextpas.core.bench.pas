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
  TBenchBaseline = nextpas.core.bench.base.TBenchBaseline;

  IBenchContext = nextpas.core.bench.intf.IBenchContext;
  IBenchSuite = nextpas.core.bench.intf.IBenchSuite;
  IBenchResults = nextpas.core.bench.intf.IBenchResults;
  IBenchStatsAnalyzer = nextpas.core.bench.intf.IBenchStatsAnalyzer;

  TBenchFunc = nextpas.core.bench.intf.TBenchFunc;
  TBenchSetupFunc = nextpas.core.bench.intf.TBenchSetupFunc;
  TBenchTeardownFunc = nextpas.core.bench.intf.TBenchTeardownFunc;
  TBenchEntry = nextpas.core.bench.intf.TBenchEntry;

  {** 基准套件 - Fluent Builder 实现 }
  TBenchSuite = class(TInterfacedObject, IBenchSuite)
  private
    FEntries: array of TBenchEntry;
    FEntryCount: Integer;
    FConfig: TBenchConfig;
    FFilter: string;
    FBaselines: array of TBenchBaseline;
    FBaselineCount: Integer;
    FRunner: TBenchRunner;
    FReportGenerator: TBenchReportGenerator;

    {** 检查依赖是否满足 }
    function CheckDependencies(const AEntry: TBenchEntry): Boolean;

    {** 拓扑排序 }
    function TopologicalSort: TInt64Array;

    {** 获取环境信息 }
    function GetEnvironment: TBenchEnvironment;

  public
    constructor Create(const ASuiteName: string);
    destructor Destroy; override;

    {** IBenchSuite 实现 }
    function Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
    function AddWithSetup(const AName: string; AFunc: TBenchFunc;
      ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
    function AddWhen(const AName: string; AFunc: TBenchFunc;
      ACondition: Boolean): IBenchSuite;
    function AddParallel(const AName: string; AFunc: TBenchFunc;
      AThreads: Integer): IBenchSuite;
    function SetMinDuration(ADuration: TDuration): IBenchSuite;
    function SetMaxIterations(AIters: Int64): IBenchSuite;
    function SetMinSamples(ACount: Integer): IBenchSuite;
    function SetWarmupIters(ACount: Integer): IBenchSuite;
    function EnableMemoryTracking: IBenchSuite;
    function DisableMemoryTracking: IBenchSuite;
    function AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
    function LoadBaseline(const APath: string): IBenchSuite;
    function SetFilter(const AFilter: string): IBenchSuite;
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

  public
    constructor Create(const AResults: array of TBenchResult;
      const AEnvironment: TBenchEnvironment;
      const ABaselines: array of TBenchBaseline);
    destructor Destroy; override;

    {** IBenchResults 实现 }
    function GetAll: TBenchResultArray;
    function GetByName(const AName: string): TBenchResult;
    function GetCount: Integer;
    function ToConsole: string;
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
  SysUtils, Classes,
  nextpas.core.bench.baseline;

{ TBenchSuite }

constructor TBenchSuite.Create(const ASuiteName: string);
begin
  inherited Create;
  FEntryCount := 0;
  SetLength(FEntries, 0);
  FBaselineCount := 0;
  SetLength(FBaselines, 0);

  // 初始化默认配置
  FConfig.MinDurationNs := BENCH_DEFAULT_MIN_DURATION_NS;
  FConfig.MaxIterations := BENCH_DEFAULT_MAX_ITERATIONS;
  FConfig.MinSamples := BENCH_DEFAULT_MIN_SAMPLES;
  FConfig.WarmupIterations := BENCH_DEFAULT_WARMUP_ITERATIONS;
  FConfig.EnableMemoryTracking := True;
  FConfig.EnableParallel := False;
  FConfig.ParallelThreads := BENCH_DEFAULT_PARALLEL_THREADS;

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

function TBenchSuite.CheckDependencies(const AEntry: TBenchEntry): Boolean;
var
  i, j: Integer;
  LFound: Boolean;
begin
  if Length(AEntry.DependsOn) = 0 then
    Exit(True);

  for i := 0 to High(AEntry.DependsOn) do
  begin
    LFound := False;
    for j := 0 to FEntryCount - 1 do
    begin
      if FEntries[j].Name = AEntry.DependsOn[i] then
      begin
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
      Exit(False);
  end;

  Result := True;
end;

function TBenchSuite.TopologicalSort: TInt64Array;
var
  LVisited: array of Boolean;
  LSorted: TInt64Array;
  LSortedCount: Integer;

  procedure Visit(AIndex: Integer);
  var
    I, J: Integer;
  begin
    if LVisited[AIndex] then Exit;
    LVisited[AIndex] := True;

    // 先访问所有依赖
    for I := 0 to High(FEntries[AIndex].DependsOn) do
    begin
      for J := 0 to FEntryCount - 1 do
      begin
        if FEntries[J].Name = FEntries[AIndex].DependsOn[I] then
        begin
          Visit(J);
          Break;
        end;
      end;
    end;

    // 添加到排序结果
    SetLength(LSorted, LSortedCount + 1);
    LSorted[LSortedCount] := AIndex;
    Inc(LSortedCount);
  end;

var
  I: Integer;
begin
  SetLength(LVisited, FEntryCount);
  for I := 0 to FEntryCount - 1 do
    LVisited[I] := False;

  LSortedCount := 0;
  SetLength(LSorted, 0);

  for I := 0 to FEntryCount - 1 do
    Visit(I);

  Result := LSorted;
end;

function TBenchSuite.GetEnvironment: TBenchEnvironment;
begin
  Result.OS := {$I %FPCTARGETOS%};
  Result.CPU := {$I %FPCTARGETCPU%};
  Result.Cores := 4; // 默认值，后续可通过 SysUtils 获取
  Result.FPCVersion := {$I %FPCVERSION%};
  Result.Timestamp := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
end;

function TBenchSuite.Add(const AName: string; AFunc: TBenchFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := nil;
  LEntry.Teardown := nil;
  LEntry.Condition := True;
  SetLength(LEntry.DependsOn, 0);

  Inc(FEntryCount);
  SetLength(FEntries, FEntryCount);
  FEntries[FEntryCount - 1] := LEntry;

  Result := Self;
end;

function TBenchSuite.AddWithSetup(const AName: string; AFunc: TBenchFunc;
  ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := ASetup;
  LEntry.Teardown := ATeardown;
  LEntry.Condition := True;
  SetLength(LEntry.DependsOn, 0);

  Inc(FEntryCount);
  SetLength(FEntries, FEntryCount);
  FEntries[FEntryCount - 1] := LEntry;

  Result := Self;
end;

function TBenchSuite.AddWhen(const AName: string; AFunc: TBenchFunc;
  ACondition: Boolean): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := nil;
  LEntry.Teardown := nil;
  LEntry.Condition := ACondition;
  SetLength(LEntry.DependsOn, 0);

  Inc(FEntryCount);
  SetLength(FEntries, FEntryCount);
  FEntries[FEntryCount - 1] := LEntry;

  Result := Self;
end;

function TBenchSuite.AddParallel(const AName: string; AFunc: TBenchFunc;
  AThreads: Integer): IBenchSuite;
var
  LEntry: TBenchEntry;
begin
  LEntry.Name := AName;
  LEntry.Func := AFunc;
  LEntry.Setup := nil;
  LEntry.Teardown := nil;
  LEntry.Condition := True;
  SetLength(LEntry.DependsOn, 0);

  // 将并行配置绑定到单个 entry
  LEntry.EnableParallel := True;
  LEntry.ParallelThreads := AThreads;

  Inc(FEntryCount);
  SetLength(FEntries, FEntryCount);
  FEntries[FEntryCount - 1] := LEntry;

  Result := Self;
end;

function TBenchSuite.SetMinDuration(ADuration: TDuration): IBenchSuite;
begin
  FConfig.MinDurationNs := ADuration.AsNanoseconds;
  Result := Self;
end;

function TBenchSuite.SetMaxIterations(AIters: Int64): IBenchSuite;
begin
  FConfig.MaxIterations := AIters;
  Result := Self;
end;

function TBenchSuite.SetMinSamples(ACount: Integer): IBenchSuite;
begin
  FConfig.MinSamples := ACount;
  Result := Self;
end;

function TBenchSuite.SetWarmupIters(ACount: Integer): IBenchSuite;
begin
  FConfig.WarmupIterations := ACount;
  Result := Self;
end;

function TBenchSuite.EnableMemoryTracking: IBenchSuite;
begin
  FConfig.EnableMemoryTracking := True;
  Result := Self;
end;

function TBenchSuite.DisableMemoryTracking: IBenchSuite;
begin
  FConfig.EnableMemoryTracking := False;
  Result := Self;
end;

function TBenchSuite.AddBaseline(const AName: string; ANsPerOp: Double): IBenchSuite;
begin
  Inc(FBaselineCount);
  SetLength(FBaselines, FBaselineCount);
  FBaselines[FBaselineCount - 1].Name := AName;
  FBaselines[FBaselineCount - 1].NsPerOp := ANsPerOp;

  Result := Self;
end;

function TBenchSuite.LoadBaseline(const APath: string): IBenchSuite;
var
  LManager: TBaselineManager;
  LBaselines: TBaselineArray;
  I: Integer;
begin
  LManager := TBaselineManager.Create;
  try
    LManager.LoadFromFile(APath);
    LBaselines := LManager.GetAllBaselines;

    // 将加载的基线添加到 suite
    for I := 0 to High(LBaselines) do
    begin
      SetLength(FBaselines, FBaselineCount + 1);
      FBaselines[FBaselineCount].Name := LBaselines[I].Name;
      FBaselines[FBaselineCount].NsPerOp := LBaselines[I].NsPerOp;
      Inc(FBaselineCount);
    end;
  except
    on E: Exception do
      WriteLn('Warning: Failed to load baseline from ', APath, ': ', E.Message);
  end;

  Result := Self;
end;

function TBenchSuite.SetFilter(const AFilter: string): IBenchSuite;
begin
  FFilter := AFilter;
  Result := Self;
end;

function TBenchSuite.Run: IBenchResults;
var
  LResults: array of TBenchResult;
  LResultCount: Integer;
  LEnvironment: TBenchEnvironment;
  LSortedIndices: TInt64Array;
  i, LIdx: Integer;
begin
  // 配置运行器
  FRunner.SetConfig(FConfig);
  FRunner.SetFilter(FFilter);

  // 使用拓扑排序确保依赖顺序
  LSortedIndices := TopologicalSort;

  // 运行所有基准
  LResultCount := 0;
  SetLength(LResults, 0);

  for i := 0 to High(LSortedIndices) do
  begin
    LIdx := LSortedIndices[i];
    if FEntries[LIdx].Condition and CheckDependencies(FEntries[LIdx]) then
    begin
      Inc(LResultCount);
      SetLength(LResults, LResultCount);
      LResults[LResultCount - 1] := FRunner.RunOne(FEntries[LIdx].Name, FEntries[LIdx].Func);
    end;
  end;

  // 获取环境信息
  LEnvironment := GetEnvironment;

  // 创建结果对象
  Result := TBenchResults.Create(LResults, LEnvironment, FBaselines);
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
  LStatsAnalyzer: IBenchStatsAnalyzer;
  i, j: Integer;
  LCurrentStats, LBaselineStats: TBenchStats;
begin
  LStatsAnalyzer := TBenchStatsAnalyzer.Create;

  SetLength(LComparisons, 0);

  for i := 0 to FResultCount - 1 do
  begin
    for j := 0 to FBaselineCount - 1 do
    begin
      if FResults[i].Name = FBaselines[j].Name then
      begin
        SetLength(LComparisons, Length(LComparisons) + 1);
        LComparisons[High(LComparisons)].BaselineName := FBaselines[j].Name;
        LComparisons[High(LComparisons)].BaselineNsPerOp := FBaselines[j].NsPerOp;
        LComparisons[High(LComparisons)].CurrentNsPerOp := FResults[i].NsPerOp;

        if FBaselines[j].NsPerOp > 0 then
          LComparisons[High(LComparisons)].Ratio := FBaselines[j].NsPerOp / FResults[i].NsPerOp
        else
          LComparisons[High(LComparisons)].Ratio := 1.0;

        // TODO: 实现真正的统计显著性检验
        LComparisons[High(LComparisons)].Significant := Abs(LComparisons[High(LComparisons)].Ratio - 1.0) > 0.05;
        LComparisons[High(LComparisons)].PValue := 0.05;  // 占位

        Break;
      end;
    end;
  end;

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
  FillChar(Result, SizeOf(Result), 0);
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

function TBenchResults.GetCount: Integer;
begin
  Result := FResultCount;
end;

function TBenchResults.ToConsole: string;
begin
  FReportGenerator.SetResults(FResults);
  FReportGenerator.SetEnvironment(FEnvironment);
  Result := FReportGenerator.ToConsole;
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

procedure TBenchResults.SaveToJSON(const APath: string);
var
  LFile: TextFile;
begin
  AssignFile(LFile, APath);
  try
    Rewrite(LFile);
    WriteLn(LFile, ToJSON);
  finally
    CloseFile(LFile);
  end;
end;

procedure TBenchResults.SaveToHTML(const APath: string);
var
  LFile: TextFile;
begin
  AssignFile(LFile, APath);
  try
    Rewrite(LFile);
    WriteLn(LFile, ToHTML);
  finally
    CloseFile(LFile);
  end;
end;

procedure TBenchResults.SaveToTSV(const APath: string);
var
  LFile: TextFile;
begin
  AssignFile(LFile, APath);
  try
    Rewrite(LFile);
    WriteLn(LFile, ToTSV);
  finally
    CloseFile(LFile);
  end;
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
    if LComparisons[i].Significant and (LComparisons[i].Ratio < AThreshold) then
      Exit(True);
  end;

  Result := False;
end;

function TBenchResults.GetEnvironment: TBenchEnvironment;
begin
  Result := FEnvironment;
end;

end.
