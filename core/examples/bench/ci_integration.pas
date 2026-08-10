{*
 * nextpas.core.bench - CI Integration Example
 *
 * 展示 CI/CD 集成：基线保存、报告生成。
 *}

program bench_ci_integration;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.bench.base;

{*
 * 模拟待测函数
 *}
procedure BenchHashMapPut(const ACtx: IBenchContext);
var
  LMap: array of Integer;
  I: Integer;
begin
  SetLength(LMap, 100000);
  for I := 0 to High(LMap) do
    LMap[I] := I;
end;

procedure BenchHashMapGet(const ACtx: IBenchContext);
var
  LMap: array of Integer;
  LSum: Integer;
  I: Integer;
begin
  SetLength(LMap, 100000);
  for I := 0 to High(LMap) do
    LMap[I] := I;

  LSum := 0;
  for I := 0 to High(LMap) do
    Inc(LSum, LMap[I]);

  BenchBlackBoxInt64(LSum);
end;

{*
 * 生成基线文件
 *}
procedure GenerateBaseline(const APath: string);
var
  LResults: IBenchResults;
begin
  WriteLn('Generating baseline: ', APath);

  LResults := TBenchSuite.Create('CIBaseline')
    .SetMinDuration(TDuration.FromSeconds(2))
    .SetMinSamples(30)
    .Add('HashMap.Put/N=100000', @BenchHashMapPut)
    .Add('HashMap.Get/N=100000', @BenchHashMapGet)
    .Run;

  { SaveBaseline 写 baselines schema(与 TryLoadBaseline 配对);
    SaveToJSON 是完整报告格式,LoadFromFile 解析不出基线 }
  LResults.SaveBaseline(APath);
  WriteLn('  Saved.');
end;

{*
 * 生成 CI 报告
 *}
procedure GenerateCIReport(const ACurrent: IBenchResults;
  const AReportPath: string);
var
  LReport: string;
  LFile: TextFile;
begin
  WriteLn('Generating CI report: ', AReportPath);

  { JSON 格式报告（可被 CI 系统解析） }
  LReport := ACurrent.ToJSON;
  AssignFile(LFile, AReportPath);
  Rewrite(LFile);
  WriteLn(LFile, LReport);
  CloseFile(LFile);

  { 控制台输出（人类可读） }
  WriteLn;
  WriteLn('=== CI Report ===');
  WriteLn(ACurrent.PrintToConsole);
end;

{*
 * 主程序：演示 CI 集成流程
 *
 * 用法:
 *   ci_integration --generate-baseline [baseline.json]   生成基线
 *   ci_integration [baseline.json [report.json]]         跑当前并与基线对比
 *}
var
  LBaselinePath, LReportPath: string;
  LSuite: IBenchSuite;
  LCurrent: IBenchResults;
  LRegression: TBenchRegressionReport;
  LHaveBaseline: Boolean;
begin
  WriteLn('=== nextpas.core.bench CI Integration ===');
  WriteLn;

  LBaselinePath := 'bench-baseline.json';
  LReportPath := 'bench-ci-report.json';

  { 1. 生成基线（首次运行或手动触发） }
  if (ParamCount >= 1) and (ParamStr(1) = '--generate-baseline') then
  begin
    if ParamCount >= 2 then
      LBaselinePath := ParamStr(2);
    GenerateBaseline(LBaselinePath);
    Exit;
  end;

  { 2. 对比模式：位置参数覆盖默认路径 }
  if ParamCount >= 1 then
    LBaselinePath := ParamStr(1);
  if ParamCount >= 2 then
    LReportPath := ParamStr(2);

  LSuite := TBenchSuite.Create('CICurrent')
    .SetMinDuration(TDuration.FromSeconds(2))
    .SetMinSamples(30)
    .Add('HashMap.Put/N=100000', @BenchHashMapPut)
    .Add('HashMap.Get/N=100000', @BenchHashMapGet);

  LHaveBaseline := LSuite.TryLoadBaseline(LBaselinePath);
  if not LHaveBaseline then
    WriteLn('No baseline loaded (', LBaselinePath, '); running without regression gate.');

  WriteLn('Running current tests...');
  LCurrent := LSuite.Run;

  { 3. 生成报告 }
  GenerateCIReport(LCurrent, LReportPath);

  { 4. 回归门：ratio = current/baseline，1.05 = 容忍 5% 劣化 }
  if LHaveBaseline then
  begin
    LRegression := LCurrent.GetRegressionReport(1.05);
    WriteLn;
    WriteLn('Regression gate: ', LRegression.RegressedCount, ' regressed / ',
      LRegression.ImprovedCount, ' improved / ',
      LRegression.UnchangedCount, ' unchanged  (',
      LRegression.TotalComparisons, ' compared, threshold ',
      LRegression.Threshold:0:2, ')');
    { 基线加载成功却零对比 = schema/名称漂移,静默通过比回归更危险 }
    if LRegression.TotalComparisons = 0 then
    begin
      WriteLn('CI FAILED: baseline loaded but 0 benchmarks compared (schema or name drift?)');
      ExitCode := 1;
      Exit;
    end;
    if LRegression.HasRegression then
    begin
      WriteLn('CI FAILED: worst regression ', LRegression.WorstRegressName,
        ' ratio ', LRegression.WorstRegressRatio:0:3);
      ExitCode := 1;
      Exit;
    end;
  end;

  WriteLn;
  WriteLn('CI PASSED: Benchmark completed successfully.');
  ExitCode := 0;
end.
