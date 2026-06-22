program bench_report;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.platform.time;

var
  GResults: array of TBenchResult;

procedure InitTestResults;
var
  I: Integer;
begin
  SetLength(GResults, 20);
  for I := 0 to 19 do
  begin
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
  end;
end;

procedure BenchToConsole(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('Console');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LResults.ToConsole;
  LResults := nil;
  LSuite := nil;
end;

procedure BenchToJSON(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LJSON: string;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('JSON');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LJSON := LResults.ToJSON;
  ACtx.SetBytes(Length(LJSON));
  LResults := nil;
  LSuite := nil;
end;

procedure BenchToTSV(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTSV: string;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('TSV');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LTSV := LResults.ToTSV;
  ACtx.SetBytes(Length(LTSV));
  LResults := nil;
  LSuite := nil;
end;

procedure BenchToHTML(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('HTML');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LHTML := LResults.ToHTML;
  ACtx.SetBytes(Length(LHTML));
  LResults := nil;
  LSuite := nil;
end;

procedure BenchSaveToJSON(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('SaveJSON');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LResults.SaveToJSON('build/bench_output.json');
  LResults := nil;
  LSuite := nil;
end;

procedure BenchSaveToHTML(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('SaveHTML');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LResults.SaveToHTML('build/bench_output.html');
  LResults := nil;
  LSuite := nil;
end;

procedure BenchCompareWithBaseline(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparisons: TBenchComparisonArray;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('Compare');
  LSuite.SetQuiet(True);
  for I := 0 to High(GResults) do
  begin
    LSuite.Add(GResults[I].Name, procedure(const ACtx2: IBenchContext) begin end);
    LSuite.AddBaseline(GResults[I].Name, GResults[I].NsPerOp * 1.1);
  end;
  LResults := LSuite.Run;
  LComparisons := LResults.CompareWithBaseline;
  ACtx.SetBytes(Length(LComparisons) * SizeOf(TBenchComparison));
  LResults := nil;
  LSuite := nil;
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
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMaxIterations(10000);
  LSuite.SetMinSamples(30);
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
