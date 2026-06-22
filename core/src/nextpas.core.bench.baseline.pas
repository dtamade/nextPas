{**
 * @desc 基准测试基线管理器
 *
 * 提供基准测试基线的保存、加载和比较功能，
 * 用于性能回归检测和版本间对比。
 *}
unit nextpas.core.bench.baseline;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.platform.time,
  nextpas.core.fs.util,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.json,
  nextpas.core.json.writer,
  nextpas.core.text.builder;

type
  {** 从 base 模块 re-export 数组类型 }
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  {**
   * 基线数据
   *}
  TBaselineData = record
    Name: string;
    NsPerOp: Double;
    BytesPerOp: Int64;
    AllocsPerOp: Int64;
    TimestampNs: UInt64;
    GitHash: string;
    CompilerVersion: string;
    Notes: string;
  end;

  {**
   * 基线数组
   *}
  TBaselineArray = array of TBaselineData;

  {**
   * 基线比较结果
   *}
  TBaselineComparison = record
    Baseline: TBaselineData;
    Current: TBenchResult;
    Ratio: Double;            // Current / Baseline
    IsRegression: Boolean;    // Ratio > threshold
    IsImprovement: Boolean;   // Ratio < 1/threshold
    PercentChange: Double;    // (Current - Baseline) / Baseline * 100
  end;

  {**
   * 基线数组
   *}
  TBaselineComparisonArray = array of TBaselineComparison;

  {**
   * 基线管理器
   *}
  TBaselineManager = record
  private
    FBaselines: TBaselineArray;
    FRegressionThreshold: Double; // e.g., 1.1 for 10% regression
    function FindBaseline(const AName: string): Integer;
  public
    {**
     * 创建基线管理器
     *}
    class function Create(ARegressionThreshold: Double = 1.1): TBaselineManager; static;

    {**
     * 添加基线
     *}
    procedure AddBaseline(const ABaseline: TBaselineData);

    {**
     * 添加基准结果作为基线
     *}
    procedure AddBaselineFromResult(const AResult: TBenchResult;
                                   const AGitHash: string = '';
                                   const ANotes: string = '');

    {**
     * 获取基线
     *}
    function GetBaseline(const AName: string): TBaselineData;

    {**
     * 获取所有基线
     *}
    function GetAllBaselines: TBaselineArray;

    {**
     * 检查是否存在基线
     *}
    function HasBaseline(const AName: string): Boolean;

    {**
     * 删除基线
     *}
    procedure RemoveBaseline(const AName: string);

    {**
     * 清除所有基线
     *}
    procedure ClearBaselines;

    {**
     * 比较当前结果与基线
     *}
    function CompareWithBaseline(const AResult: TBenchResult): TBaselineComparison;

    {**
     * 比较多个结果与基线
     *}
    function CompareAllWithBaselines(const AResults: TBenchResultArray): TBaselineComparisonArray;

    {**
     * 检查是否有回归
     *}
    function HasRegression(const AResults: TBenchResultArray): Boolean;

    {**
     * 保存基线到文件
     *}
    procedure SaveToFile(const AFileName: string);

    {**
     * 从文件加载基线
     *}
    procedure LoadFromFile(const AFileName: string);

    {**
     * 导出为JSON
     *}
    function ToJSON: string;

    {**
     * 从JSON导入
     *}
    procedure LoadFromJSON(const AJSON: string);
  end;

implementation

{ TBaselineManager }

class function TBaselineManager.Create(ARegressionThreshold: Double): TBaselineManager;
begin
  Result.FBaselines := nil;
  Result.FRegressionThreshold := ARegressionThreshold;
end;

function TBaselineManager.FindBaseline(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FBaselines) do
    if FBaselines[I].Name = AName then
      Exit(I);
  Result := -1;
end;

procedure TBaselineManager.AddBaseline(const ABaseline: TBaselineData);
var
  LIdx: Integer;
begin
  LIdx := FindBaseline(ABaseline.Name);
  if LIdx >= 0 then
    FBaselines[LIdx] := ABaseline
  else
  begin
    SetLength(FBaselines, Length(FBaselines) + 1);
    FBaselines[High(FBaselines)] := ABaseline;
  end;
end;

procedure TBaselineManager.AddBaselineFromResult(const AResult: TBenchResult;
                                                const AGitHash: string;
                                                const ANotes: string);
var
  LBaseline: TBaselineData;
begin
  LBaseline.Name := AResult.Name;
  LBaseline.NsPerOp := AResult.NsPerOp;
  LBaseline.BytesPerOp := AResult.BytesPerOp;
  LBaseline.AllocsPerOp := AResult.AllocsPerOp;
  LBaseline.TimestampNs := UInt64(platform_realtime_ns);
  LBaseline.GitHash := AGitHash;
  LBaseline.CompilerVersion := 'FPC ' + {$I %FPCVERSION%};
  LBaseline.Notes := ANotes;
  AddBaseline(LBaseline);
end;

function TBaselineManager.GetBaseline(const AName: string): TBaselineData;
var
  LIdx: Integer;
begin
  LIdx := FindBaseline(AName);
  if LIdx >= 0 then
    Result := FBaselines[LIdx]
  else
    raise EBenchBaselineNotFound.CreateFmt('Baseline not found: %s', [AName]);
end;

function TBaselineManager.GetAllBaselines: TBaselineArray;
begin
  Result := FBaselines;
end;

function TBaselineManager.HasBaseline(const AName: string): Boolean;
begin
  Result := FindBaseline(AName) >= 0;
end;

procedure TBaselineManager.RemoveBaseline(const AName: string);
var
  LIdx: Integer;
  I: Integer;
begin
  LIdx := FindBaseline(AName);
  if LIdx >= 0 then
  begin
    for I := LIdx to High(FBaselines) - 1 do
      FBaselines[I] := FBaselines[I + 1];
    SetLength(FBaselines, Length(FBaselines) - 1);
  end;
end;

procedure TBaselineManager.ClearBaselines;
begin
  FBaselines := nil;
end;

function TBaselineManager.CompareWithBaseline(const AResult: TBenchResult): TBaselineComparison;
var
  LBaseline: TBaselineData;
begin
  LBaseline := GetBaseline(AResult.Name);

  Result.Baseline := LBaseline;
  Result.Current := AResult;

  if LBaseline.NsPerOp > 0 then
    Result.Ratio := AResult.NsPerOp / LBaseline.NsPerOp
  else
    Result.Ratio := 1;

  Result.IsRegression := Result.Ratio > FRegressionThreshold;
  Result.IsImprovement := Result.Ratio < (1 / FRegressionThreshold);

  if LBaseline.NsPerOp > 0 then
    Result.PercentChange := ((AResult.NsPerOp - LBaseline.NsPerOp) / LBaseline.NsPerOp) * 100
  else
    Result.PercentChange := 0;
end;

function TBaselineManager.CompareAllWithBaselines(const AResults: TBenchResultArray): TBaselineComparisonArray;
var
  I: Integer;
  LResults: array of TBaselineComparison;
begin
  LResults := nil;
  for I := 0 to High(AResults) do
  begin
    if HasBaseline(AResults[I].Name) then
    begin
      SetLength(LResults, Length(LResults) + 1);
      LResults[High(LResults)] := CompareWithBaseline(AResults[I]);
    end;
  end;
  Result := LResults;
end;

function TBaselineManager.HasRegression(const AResults: TBenchResultArray): Boolean;
var
  LComparisons: TBaselineComparisonArray;
  I: Integer;
begin
  LComparisons := CompareAllWithBaselines(AResults);
  for I := 0 to High(LComparisons) do
    if LComparisons[I].IsRegression then
      Exit(True);
  Result := False;
end;

procedure TBaselineManager.SaveToFile(const AFileName: string);
var
  LJSON: string;
  LFile: TextFile;
begin
  LJSON := ToJSON;
  AssignFile(LFile, AFileName);
  Rewrite(LFile);
  try
    Write(LFile, LJSON);
  finally
    CloseFile(LFile);
  end;
end;

procedure TBaselineManager.LoadFromFile(const AFileName: string);
begin
  LoadFromJSON(FsReadFileText(AFileName));
end;

function TBaselineManager.ToJSON: string;
var
  I: Integer;
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  LBuilder.Init(128 + Length(FBaselines) * 128);
  try
    LWriter.Init(LBuilder);
    LWriter.BeginObject;
    LWriter.Key('baselines');
    LWriter.BeginArray;
    for I := 0 to High(FBaselines) do
    begin
      LWriter.BeginObject;
      LWriter.Key('name');
      LWriter.Str(FBaselines[I].Name);
      LWriter.Key('nsPerOp');
      LWriter.Float(FBaselines[I].NsPerOp);
      LWriter.Key('bytesPerOp');
      LWriter.Int(FBaselines[I].BytesPerOp);
      LWriter.Key('allocsPerOp');
      LWriter.Int(FBaselines[I].AllocsPerOp);
      LWriter.Key('timestampNs');
      LWriter.Int(FBaselines[I].TimestampNs);
      LWriter.Key('gitHash');
      LWriter.Str(FBaselines[I].GitHash);
      LWriter.Key('compilerVersion');
      LWriter.Str(FBaselines[I].CompilerVersion);
      LWriter.Key('notes');
      LWriter.Str(FBaselines[I].Notes);
      LWriter.EndObject;
    end;
    LWriter.EndArray;
    LWriter.EndObject;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

procedure TBaselineManager.LoadFromJSON(const AJSON: string);
var
  LDocument: IJsonDocument;
  LRoot: TJsonValue;
  LBaselines: TJsonValue;
  LItem: TJsonValue;
  LField: TJsonValue;
  LBaseline: TBaselineData;
  I: UInt32;
begin
  ClearBaselines;

  if Trim(AJSON) = '' then
    Exit;

  LDocument := JsonParse(AJSON);
  if (LDocument = nil) or LDocument.HasError then
    raise Exception.Create('Invalid baseline JSON');

  LRoot := LDocument.Root;
  LBaselines := LRoot.ObjectGet('baselines');
  if not LBaselines.IsArray then
    Exit;

  for I := 0 to LBaselines.ArrayLen - 1 do
  begin
    LItem := LBaselines.ArrayGet(I);
    if not LItem.IsObject then
      Continue;

    LBaseline := Default(TBaselineData);

    LField := LItem.ObjectGet('name');
    if LField.IsStr then
      LBaseline.Name := LField.AsStr.ToString;

    LField := LItem.ObjectGet('nsPerOp');
    LBaseline.NsPerOp := LField.AsFloat;

    LField := LItem.ObjectGet('bytesPerOp');
    LBaseline.BytesPerOp := LField.AsInt;

    LField := LItem.ObjectGet('allocsPerOp');
    LBaseline.AllocsPerOp := LField.AsInt;

    LField := LItem.ObjectGet('timestampNs');
    if LField.IsInt then
      LBaseline.TimestampNs := UInt64(LField.AsInt)
    else
    begin
      LField := LItem.ObjectGet('timestamp');
      LBaseline.TimestampNs := 0;
    end;

    LField := LItem.ObjectGet('gitHash');
    if LField.IsStr then
      LBaseline.GitHash := LField.AsStr.ToString;

    LField := LItem.ObjectGet('compilerVersion');
    if LField.IsStr then
      LBaseline.CompilerVersion := LField.AsStr.ToString;

    LField := LItem.ObjectGet('notes');
    if LField.IsStr then
      LBaseline.Notes := LField.AsStr.ToString;

    AddBaseline(LBaseline);
  end;
end;

end.
