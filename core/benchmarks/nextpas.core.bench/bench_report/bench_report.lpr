program bench_report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{**
 * 报告生成路径基准。
 * 直接构造 TBenchResults，避免「外层采样 × 内层 20 条 suite」嵌套挂死。
 *}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.platform.time;

var
  GResults: array of TBenchResult;
  GBaselines: array of TBaselineData;
  GEnv: TBenchEnvironment;

procedure InitTestResults;
var
  I: Integer;
begin
  SetLength(GResults, 20);
  SetLength(GBaselines, 20);
  for I := 0 to 19 do
  begin
    GResults[I] := Default(TBenchResult);
    GResults[I].Name := 'Bench' + IntToStr(I);
    GResults[I].Executed := True;
    GResults[I].Skipped := False;
    GResults[I].Iterations := 1000 + Random(1000);
    GResults[I].TotalNs := UInt64(100000 + Random(100000));
    GResults[I].NsPerOp := 100.0 + Random * 100.0;
    GResults[I].OpsPerSec := 1000000000.0 / GResults[I].NsPerOp;
    GResults[I].BytesPerOp := 1024;
    GResults[I].AllocsPerOp := 2;
    GResults[I].StdDev := Random * 10.0;
    GResults[I].Median := GResults[I].NsPerOp - 5.0 + Random * 10.0;
    GResults[I].P95 := GResults[I].NsPerOp + 10.0 + Random * 10.0;
    GResults[I].P99 := GResults[I].NsPerOp + 20.0 + Random * 10.0;
    GResults[I].Outliers := Random(5);
    GResults[I].SampleCount := 30;

    GBaselines[I] := Default(TBaselineData);
    GBaselines[I].Name := GResults[I].Name;
    GBaselines[I].NsPerOp := GResults[I].NsPerOp * 1.1;
  end;

  GEnv := Default(TBenchEnvironment);
  GEnv.OS := 'Linux';
  GEnv.CPU := 'x86_64';
  GEnv.Cores := 1;
  GEnv.FPCVersion := '3.3.1';
  GEnv.Timestamp := 'bench';
end;

function MakeResults: IBenchResults;
begin
  Result := TBenchResults.Create(GResults, GEnv, []);
end;

function MakeResultsWithBaselines: IBenchResults;
begin
  Result := TBenchResults.Create(GResults, GEnv, GBaselines);
end;

procedure BenchToConsole(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
  LOut: string;
begin
  LResults := MakeResults;
  LOut := LResults.PrintToConsole;
  ACtx.SetBytes(Length(LOut));
end;

procedure BenchToJSON(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
  LJSON: string;
begin
  LResults := MakeResults;
  LJSON := LResults.ToJSON;
  ACtx.SetBytes(Length(LJSON));
end;

procedure BenchToTSV(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
  LTSV: string;
begin
  LResults := MakeResults;
  LTSV := LResults.ToTSV;
  ACtx.SetBytes(Length(LTSV));
end;

procedure BenchToHTML(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
  LHTML: string;
begin
  LResults := MakeResults;
  LHTML := LResults.ToHTML;
  ACtx.SetBytes(Length(LHTML));
end;

procedure BenchSaveToJSON(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
begin
  ForceDirectories('build');
  LResults := MakeResults;
  LResults.SaveToJSON('build/bench_output.json');
end;

procedure BenchSaveToHTML(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
begin
  ForceDirectories('build');
  LResults := MakeResults;
  LResults.SaveToHTML('build/bench_output.html');
end;

procedure BenchCompareWithBaseline(const ACtx: IBenchContext);
var
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
begin
  LResults := MakeResultsWithBaselines;
  LComparisons := LResults.CompareWithBaseline;
  ACtx.SetBytes(Length(LComparisons) * SizeOf(TBenchComparison));
end;

procedure RunReportBenchmarks;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench.report Benchmarks ===');
  WriteLn;
  WriteLn('Measuring report generation performance:');
  WriteLn;

  InitTestResults;

  LSuite := TBenchSuite.Create('BenchReport');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(50));
  LSuite.SetMaxIterations(500);
  LSuite.SetMinSamples(5);
  LSuite.SetWarmupIters(1);
  LSuite.SetQuiet(False);

  LSuite.Add('ToConsole/20', @BenchToConsole);
  LSuite.Add('ToJSON/20', @BenchToJSON);
  LSuite.Add('ToTSV/20', @BenchToTSV);
  LSuite.Add('ToHTML/20', @BenchToHTML);
  LSuite.Add('SaveToJSON/20', @BenchSaveToJSON);
  LSuite.Add('SaveToHTML/20', @BenchSaveToHTML);
  LSuite.Add('CompareWithBaseline/20', @BenchCompareWithBaseline);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== JSON Output ===');
  WriteLn(LResults.ToJSON);

  LResults := nil;
  LSuite := nil;
end;

begin
  RunReportBenchmarks;
end.
