program bench_stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.bench,
  nextpas.core.bench.stats,
  nextpas.core.bench.intf,
  nextpas.core.bench.base,
  nextpas.core.time.base,
  nextpas.core.platform.time;

var
  GAnalyzer: IBenchStatsAnalyzer;
  GData100: TDoubleArray;
  GData1000: TDoubleArray;
  GData10000: TDoubleArray;

procedure InitTestData;
var
  I: Integer;
begin
  SetLength(GData100, 100);
  SetLength(GData1000, 1000);
  SetLength(GData10000, 10000);

  for I := 0 to 99 do
    GData100[I] := 100.0 + Random * 10.0;
  for I := 0 to 999 do
    GData1000[I] := 100.0 + Random * 10.0;
  for I := 0 to 9999 do
    GData10000[I] := 100.0 + Random * 10.0;
end;

procedure BenchMean100(const ACtx: IBenchContext);
begin
  GAnalyzer.Mean(GData100);
end;

procedure BenchMean1000(const ACtx: IBenchContext);
begin
  GAnalyzer.Mean(GData1000);
end;

procedure BenchMean10000(const ACtx: IBenchContext);
begin
  GAnalyzer.Mean(GData10000);
end;

procedure BenchMedian100(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData100);
  GAnalyzer.Median(LData);
end;

procedure BenchMedian1000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData1000);
  GAnalyzer.Median(LData);
end;

procedure BenchMedian10000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData10000);
  GAnalyzer.Median(LData);
end;

procedure BenchStdDev100(const ACtx: IBenchContext);
begin
  GAnalyzer.StdDev(GData100);
end;

procedure BenchStdDev1000(const ACtx: IBenchContext);
begin
  GAnalyzer.StdDev(GData1000);
end;

procedure BenchStdDev10000(const ACtx: IBenchContext);
begin
  GAnalyzer.StdDev(GData10000);
end;

procedure BenchSort100(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData100);
  GAnalyzer.Sort(LData);
end;

procedure BenchSort1000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData1000);
  GAnalyzer.Sort(LData);
end;

procedure BenchSort10000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData10000);
  GAnalyzer.Sort(LData);
end;

procedure BenchComputeStats100(const ACtx: IBenchContext);
begin
  GAnalyzer.ComputeStats(GData100);
end;

procedure BenchComputeStats1000(const ACtx: IBenchContext);
begin
  GAnalyzer.ComputeStats(GData1000);
end;

procedure BenchComputeStats10000(const ACtx: IBenchContext);
begin
  GAnalyzer.ComputeStats(GData10000);
end;

procedure BenchPercentile100(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData100);
  GAnalyzer.Sort(LData);
  GAnalyzer.Percentile(LData, 25);
  GAnalyzer.Percentile(LData, 50);
  GAnalyzer.Percentile(LData, 75);
  GAnalyzer.Percentile(LData, 95);
end;

procedure BenchPercentile1000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData1000);
  GAnalyzer.Sort(LData);
  GAnalyzer.Percentile(LData, 25);
  GAnalyzer.Percentile(LData, 50);
  GAnalyzer.Percentile(LData, 75);
  GAnalyzer.Percentile(LData, 95);
end;

procedure BenchPercentile10000(const ACtx: IBenchContext);
var
  LData: TDoubleArray;
begin
  LData := Copy(GData10000);
  GAnalyzer.Sort(LData);
  GAnalyzer.Percentile(LData, 25);
  GAnalyzer.Percentile(LData, 50);
  GAnalyzer.Percentile(LData, 75);
  GAnalyzer.Percentile(LData, 95);
end;

procedure RunStatsBenchmarks;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench.stats Benchmarks ===');
  WriteLn;
  WriteLn('Measuring stats computation performance:');
  WriteLn;

  GAnalyzer := TBenchStatsAnalyzer.Create;
  InitTestData;

  LSuite := TBenchSuite.Create('BenchStats');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMaxIterations(100000);
  LSuite.SetMinSamples(30);
  LSuite.SetQuiet(False);

  LSuite.Add('Mean/100', @BenchMean100);
  LSuite.Add('Mean/1000', @BenchMean1000);
  LSuite.Add('Mean/10000', @BenchMean10000);

  LSuite.Add('Median/100', @BenchMedian100);
  LSuite.Add('Median/1000', @BenchMedian1000);
  LSuite.Add('Median/10000', @BenchMedian10000);

  LSuite.Add('StdDev/100', @BenchStdDev100);
  LSuite.Add('StdDev/1000', @BenchStdDev1000);
  LSuite.Add('StdDev/10000', @BenchStdDev10000);

  LSuite.Add('Sort/100', @BenchSort100);
  LSuite.Add('Sort/1000', @BenchSort1000);
  LSuite.Add('Sort/10000', @BenchSort10000);

  LSuite.Add('ComputeStats/100', @BenchComputeStats100);
  LSuite.Add('ComputeStats/1000', @BenchComputeStats1000);
  LSuite.Add('ComputeStats/10000', @BenchComputeStats10000);

  LSuite.Add('Percentile/100', @BenchPercentile100);
  LSuite.Add('Percentile/1000', @BenchPercentile1000);
  LSuite.Add('Percentile/10000', @BenchPercentile10000);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== JSON Output ===');
  WriteLn(LResults.ToJSON);

  LResults := nil;
  LSuite := nil;
end;

begin
  RunStatsBenchmarks;
end.
