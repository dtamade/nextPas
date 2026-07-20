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

  LResults.SaveToJSON(APath);
  WriteLn('  Saved.');
end;

{*
 * 模拟当前测试结果
 *}
function RunCurrentTests: IBenchResults;
begin
  WriteLn('Running current tests...');

  Result := TBenchSuite.Create('CICurrent')
    .SetMinDuration(TDuration.FromSeconds(2))
    .SetMinSamples(30)
    .Add('HashMap.Put/N=100000', @BenchHashMapPut)
    .Add('HashMap.Get/N=100000', @BenchHashMapGet)
    .Run;
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
 *}
var
  LBaselinePath, LReportPath: string;
  LCurrent: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench CI Integration ===');
  WriteLn;

  LBaselinePath := 'bench-baseline.json';
  LReportPath := 'bench-ci-report.json';

  { 1. 生成基线（首次运行或手动触发） }
  if (ParamCount > 0) and (ParamStr(1) = '--generate-baseline') then
  begin
    GenerateBaseline(LBaselinePath);
    Exit;
  end;

  { 2. 运行当前测试 }
  LCurrent := RunCurrentTests;

  { 3. 生成报告 }
  GenerateCIReport(LCurrent, LReportPath);

  { 4. 返回退出码 }
  WriteLn;
  WriteLn('CI PASSED: Benchmark completed successfully.');
  ExitCode := 0;
end.
