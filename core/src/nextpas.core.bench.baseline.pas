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
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.platform.time,
  nextpas.core.fs.util,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.writer,
  nextpas.core.text.builder;

type
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
   *
   * F-012: record 类型（值语义），包含动态数组。
   * 赋值时是浅拷贝（共享动态数组引用），不要同时修改两个拷贝。
   * 如果需要独立拷贝，使用 Create 新建后 AddBaseline 逐条复制。
   *}
  TBaselineManager = record
  private
    FBaselines: TBaselineArray;
    FBaselineCount: Integer;
    FBaselineCapacity: Integer;
    FRegressionThreshold: Double; // e.g., 1.1 for 10% regression
    function FindBaseline(const AName: string): Integer;
  public
    {**
     * 创建基线管理器
     *}
    class function Create(ARegressionThreshold: Double = 1.1): TBaselineManager; static;

    {** F-18: 深拷贝（独立副本，修改不影响原对象） }
    function Clone: TBaselineManager;

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

    {** ST-09: 保存基线到 JSON 文件 }
    procedure SaveToFile(const AFileName: string);

    {** ST-09: 从 JSON 文件加载基线 }
    procedure LoadFromFile(const AFileName: string);

    {** 导出为 JSON 字符串 }
    function ToJSON: string;

    {** 从 JSON 字符串导入 }
    procedure LoadFromJSON(const AJSON: string);
  end;

implementation

{ TBaselineManager }

class function TBaselineManager.Create(ARegressionThreshold: Double): TBaselineManager;
begin
  Result.FBaselines := nil;
  Result.FBaselineCount := 0;
  Result.FBaselineCapacity := 0;
  Result.FRegressionThreshold := ARegressionThreshold;
end;

{** F-18: 深拷贝 — 独立的动态数组副本 }
function TBaselineManager.Clone: TBaselineManager;
var
  I: Integer;
begin
  Result.FRegressionThreshold := FRegressionThreshold;
  Result.FBaselineCount := FBaselineCount;
  Result.FBaselineCapacity := FBaselineCount;
  if FBaselineCount > 0 then
  begin
    SetLength(Result.FBaselines, FBaselineCount);
    for I := 0 to FBaselineCount - 1 do
      Result.FBaselines[I] := FBaselines[I];
  end
  else
  begin
    Result.FBaselines := nil;
    Result.FBaselineCapacity := 0;
  end;
end;

function TBaselineManager.FindBaseline(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FBaselineCount - 1 do
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
    if FBaselineCount >= FBaselineCapacity then
    begin
      if FBaselineCapacity = 0 then
        FBaselineCapacity := 8
      else
        FBaselineCapacity := FBaselineCapacity * 2;
      SetLength(FBaselines, FBaselineCapacity);
    end;
    FBaselines[FBaselineCount] := ABaseline;
    Inc(FBaselineCount);
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
var
  I: Integer;
begin
  if FBaselineCount = 0 then
    Exit(nil);
  SetLength(Result, FBaselineCount);
  for I := 0 to FBaselineCount - 1 do
    Result[I] := FBaselines[I];
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
    for I := LIdx to FBaselineCount - 2 do
      FBaselines[I] := FBaselines[I + 1];
    Dec(FBaselineCount);
  end;
end;

procedure TBaselineManager.ClearBaselines;
begin
  FBaselines := nil;
  FBaselineCount := 0;
  FBaselineCapacity := 0;
end;

function TBaselineManager.CompareWithBaseline(const AResult: TBenchResult): TBaselineComparison;
var
  LIdx: Integer;
begin
  LIdx := FindBaseline(AResult.Name);
  if LIdx < 0 then
  begin
    Result := Default(TBaselineComparison);
    Result.Current := AResult;
    Result.Ratio := 1.0;
    Result.Baseline.Name := AResult.Name;
    Result.Baseline.NsPerOp := AResult.NsPerOp;
    Exit;
  end;

  Result.Baseline := FBaselines[LIdx];
  Result.Current := AResult;

  if FBaselines[LIdx].NsPerOp > 0 then
    Result.Ratio := AResult.NsPerOp / FBaselines[LIdx].NsPerOp
  else
    Result.Ratio := 1;

  Result.IsRegression := Result.Ratio > FRegressionThreshold;
  Result.IsImprovement := Result.Ratio < (1 / FRegressionThreshold);

  if FBaselines[LIdx].NsPerOp > 0 then
    Result.PercentChange := ((AResult.NsPerOp - FBaselines[LIdx].NsPerOp) / FBaselines[LIdx].NsPerOp) * 100
  else
    Result.PercentChange := 0;
end;

function TBaselineManager.CompareAllWithBaselines(const AResults: TBenchResultArray): TBaselineComparisonArray;
var
  I: Integer;
  LCount: Integer;
  LResults: array of TBaselineComparison;
begin
  LResults := nil;
  LCount := 0;
  for I := 0 to High(AResults) do
  begin
    if FindBaseline(AResults[I].Name) >= 0 then
    begin
      if LCount >= Length(LResults) then
      begin
        if LCount = 0 then
          SetLength(LResults, 8)
        else
          SetLength(LResults, LCount * 2);
      end;
      LResults[LCount] := CompareWithBaseline(AResults[I]);
      Inc(LCount);
    end;
  end;
  SetLength(LResults, LCount);
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
begin
  try
    WriteFileText(AFileName, ToJSON, PermDefault);
  except
    on E: Exception do
      raise EBenchError.CreateFmt('Failed to save baseline to "%s": %s', [AFileName, E.Message]);
  end;
end;

procedure TBaselineManager.LoadFromFile(const AFileName: string);
begin
  if not FileExists(AFileName) then
    raise EBenchBaselineNotFound.CreateFmt('Baseline file not found: %s', [AFileName]);
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
    for I := 0 to FBaselineCount - 1 do
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
  LBaselinesArray: array of TBaselineData;
  LCount: UInt32;
  I: UInt32;
begin
  if nextpas.core.text.conv.Trim(AJSON) = '' then
  begin
    ClearBaselines;
    Exit;
  end;

  LDocument := JsonParse(AJSON);
  if (LDocument = nil) or LDocument.HasError then
    raise EBenchError.Create('Invalid baseline JSON');

  LRoot := LDocument.Root;
  LBaselines := LRoot.ObjectGet('baselines');
  if not LBaselines.IsArray then
  begin
    ClearBaselines;
    Exit;
  end;

  LCount := LBaselines.ArrayLen;
  SetLength(LBaselinesArray, LCount);

  for I := 0 to LCount - 1 do
  begin
    LItem := LBaselines.ArrayGet(I);
    if not LItem.IsObject then
      Continue;

    LBaseline := Default(TBaselineData);

    LField := LItem.ObjectGet('name');
    if LField.IsStr then
      LBaseline.Name := LField.AsStr.ToString;

    LField := LItem.ObjectGet('nsPerOp');
    if LField.IsReal then
      LBaseline.NsPerOp := LField.AsFloat
    else if LField.IsInt then
      LBaseline.NsPerOp := LField.AsInt
    else
      LBaseline.NsPerOp := 0;

    LField := LItem.ObjectGet('bytesPerOp');
    if LField.IsInt then
      LBaseline.BytesPerOp := LField.AsInt
    else
      LBaseline.BytesPerOp := 0;

    LField := LItem.ObjectGet('allocsPerOp');
    if LField.IsInt then
      LBaseline.AllocsPerOp := LField.AsInt
    else
      LBaseline.AllocsPerOp := 0;

    LField := LItem.ObjectGet('timestampNs');
    if LField.IsInt then
      LBaseline.TimestampNs := UInt64(LField.AsInt)
    else
    begin
      // ST-26: fallback to legacy "timestamp" field (seconds → nanoseconds)
      LField := LItem.ObjectGet('timestamp');
      if LField.IsInt then
        LBaseline.TimestampNs := UInt64(LField.AsInt) * NANOSECONDS_PER_SECOND
      else
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

    LBaselinesArray[I] := LBaseline;
  end;

  { Strong exception safety: only replace baselines on full success }
  ClearBaselines;
  for I := 0 to High(LBaselinesArray) do
    AddBaseline(LBaselinesArray[I]);
end;

end.
