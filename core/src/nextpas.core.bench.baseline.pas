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
  SysUtils,
  Classes,
  nextpas.core.bench.base;

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
    Timestamp: TDateTime;
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

uses
  StrUtils;

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
  LBaseline.Timestamp := Now;
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
    raise Exception.CreateFmt('Baseline not found: %s', [AName]);
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
var
  LJSON: string;
  LFile: TextFile;
  LLine: string;
begin
  LJSON := '';
  AssignFile(LFile, AFileName);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LJSON := LJSON + LLine;
    end;
  finally
    CloseFile(LFile);
  end;
  LoadFromJSON(LJSON);
end;

function TBaselineManager.ToJSON: string;
var
  I: Integer;
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Add('{"baselines":[');
    for I := 0 to High(FBaselines) do
    begin
      if I > 0 then
        LLines.Add(',');
      LLines.Add('{');
      LLines.Add('"name":"' + FBaselines[I].Name + '",');
      LLines.Add('"nsPerOp":' + FloatToStr(FBaselines[I].NsPerOp) + ',');
      LLines.Add('"bytesPerOp":' + IntToStr(FBaselines[I].BytesPerOp) + ',');
      LLines.Add('"allocsPerOp":' + IntToStr(FBaselines[I].AllocsPerOp) + ',');
      LLines.Add('"timestamp":' + FloatToStr(FBaselines[I].Timestamp) + ',');
      LLines.Add('"gitHash":"' + FBaselines[I].GitHash + '",');
      LLines.Add('"compilerVersion":"' + FBaselines[I].CompilerVersion + '",');
      LLines.Add('"notes":"' + FBaselines[I].Notes + '"');
      LLines.Add('}');
    end;
    LLines.Add(']}');
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

procedure TBaselineManager.LoadFromJSON(const AJSON: string);
var
  LLines: TStringList;
  LLine: string;
  LTrimmedLine: string;
  LPos: Integer;
  LName: string;
  LNsPerOp: Double;
  LBytesPerOp: Int64;
  LAllocsPerOp: Int64;
  LGitHash: string;
  LNotes: string;
  LBaseline: TBaselineData;
begin
  ClearBaselines;

  // 简单的 JSON 解析 - 提取 baselines 数组中的对象
  LLines := TStringList.Create;
  try
    LLines.Text := AJSON;

    for LLine in LLines do
    begin
      LTrimmedLine := Trim(LLine);

      // 查找 name 字段
      if Pos('"name":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"name":', LTrimmedLine);
        LName := Copy(LTrimmedLine, LPos + 7, MaxInt);
        LName := Trim(LName);
        // 移除引号和逗号
        if (Length(LName) > 0) and (LName[1] = '"') then
          Delete(LName, 1, 1);
        LPos := Pos('"', LName);
        if LPos > 0 then
          LName := Copy(LName, 1, LPos - 1);

        // 初始化默认值
        LNsPerOp := 0;
        LBytesPerOp := 0;
        LAllocsPerOp := 0;
        LGitHash := '';
        LNotes := '';
      end

      // 查找 nsPerOp 字段
      else if Pos('"nsPerOp":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"nsPerOp":', LTrimmedLine);
        LNsPerOp := StrToFloatDef(Copy(LTrimmedLine, LPos + 10, MaxInt), 0);
      end

      // 查找 bytesPerOp 字段
      else if Pos('"bytesPerOp":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"bytesPerOp":', LTrimmedLine);
        LBytesPerOp := StrToInt64Def(Copy(LTrimmedLine, LPos + 13, MaxInt), 0);
      end

      // 查找 allocsPerOp 字段
      else if Pos('"allocsPerOp":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"allocsPerOp":', LTrimmedLine);
        LAllocsPerOp := StrToInt64Def(Copy(LTrimmedLine, LPos + 14, MaxInt), 0);
      end

      // 查找 gitHash 字段
      else if Pos('"gitHash":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"gitHash":', LTrimmedLine);
        LGitHash := Copy(LTrimmedLine, LPos + 10, MaxInt);
        LGitHash := Trim(LGitHash);
        if (Length(LGitHash) > 0) and (LGitHash[1] = '"') then
          Delete(LGitHash, 1, 1);
        LPos := Pos('"', LGitHash);
        if LPos > 0 then
          LGitHash := Copy(LGitHash, 1, LPos - 1);
      end

      // 查找 notes 字段
      else if Pos('"notes":', LTrimmedLine) > 0 then
      begin
        LPos := Pos('"notes":', LTrimmedLine);
        LNotes := Copy(LTrimmedLine, LPos + 8, MaxInt);
        LNotes := Trim(LNotes);
        if (Length(LNotes) > 0) and (LNotes[1] = '"') then
          Delete(LNotes, 1, 1);
        LPos := Pos('"', LNotes);
        if LPos > 0 then
          LNotes := Copy(LNotes, 1, LPos - 1);
      end

      // 遇到 } 时保存基线
      else if LTrimmedLine = '}' then
      begin
        if LName <> '' then
        begin
          LBaseline.Name := LName;
          LBaseline.NsPerOp := LNsPerOp;
          LBaseline.BytesPerOp := LBytesPerOp;
          LBaseline.AllocsPerOp := LAllocsPerOp;
          LBaseline.Timestamp := Now;
          LBaseline.GitHash := LGitHash;
          LBaseline.CompilerVersion := 'FPC ' + {$I %FPCVERSION%};
          LBaseline.Notes := LNotes;
          AddBaseline(LBaseline);
          LName := '';
        end;
      end;
    end;
  finally
    LLines.Free;
  end;
end;

end.
