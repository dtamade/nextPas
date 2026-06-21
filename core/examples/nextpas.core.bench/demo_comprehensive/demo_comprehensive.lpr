program demo_comprehensive;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.xlang,
  nextpas.core.bench.memtrack,
  nextpas.core.bench.baseline,
  nextpas.core.bench.stats.advanced;

{ Benchmark functions - with context parameter }

procedure BenchStringConcat(const ACtx: IBenchContext);
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 1 to 1000 do
    S := S + 'a';
end;

procedure BenchStringBuilder(const ACtx: IBenchContext);
var
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 1 to 1000 do
      SB.Append('a');
  finally
    SB.Free;
  end;
end;

procedure BenchArraySum(const ACtx: IBenchContext);
var
  I: Integer;
  Arr: array[0..999] of Integer;
  Sum: Integer;
begin
  for I := 0 to 999 do
    Arr[I] := I;
  Sum := 0;
  for I := 0 to 999 do
    Sum := Sum + Arr[I];
end;

procedure BenchMathOperations(const ACtx: IBenchContext);
var
  I: Integer;
  X: Double;
begin
  X := 1.0;
  for I := 1 to 1000 do
    X := X * 1.001 + 0.001;
end;

{ Main demo }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LGoResults: TBenchResultArray;
  LManager: TBaselineManager;
  LStats: TAdvancedStats;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
  LOutliers: TOutlierDetection;
  LTracker: TMemoryTracker;
  I: Integer;
begin
  WriteLn('=== nextpas.core.bench Comprehensive Demo ===');
  WriteLn('');

  // Create benchmark suite
  LSuite := TBenchSuite.Create('Comprehensive Demo')
    .SetMinSamples(30)
    .SetWarmupIters(3);

  // Add benchmarks
  LSuite
    .Add('String Concat', @BenchStringConcat)
    .Add('String Builder', @BenchStringBuilder)
    .Add('Array Sum', @BenchArraySum)
    .Add('Math Operations', @BenchMathOperations);

  // Run benchmarks
  WriteLn('Running benchmarks...');
  LResults := LSuite.Run;

  // Display results
  WriteLn('');
  WriteLn('=== Benchmark Results ===');
  LResults.ToConsole;

  // Export to different formats
  WriteLn('');
  WriteLn('=== Export Formats ===');
  WriteLn('JSON: ', Copy(LResults.ToJSON, 1, 100), '...');
  WriteLn('TSV:');
  WriteLn(LResults.ToTSV);

  // Parse Go benchmark output
  WriteLn('');
  WriteLn('=== Cross-Language Comparison ===');
  LGoResults := ParseGoBenchOutput(
    'BenchmarkSort-8   1000000   1234 ns/op' + #10 +
    'BenchmarkHash-4    500000   2345 ns/op   456 B/op   7 allocs/op'
  );
  WriteLn('Parsed ', Length(LGoResults), ' Go benchmarks');

  // Baseline management
  WriteLn('');
  WriteLn('=== Baseline Management ===');
  LManager := TBaselineManager.Create(1.1);

  // Add baselines
  if LResults.GetCount > 0 then
  begin
    LManager.AddBaselineFromResult(LResults.GetAll[0], 'abc123', 'Initial baseline');
    WriteLn('Added baseline: ', LResults.GetAll[0].Name);

    // Compare with baseline
    if LResults.GetCount > 1 then
    begin
      WriteLn('Comparison available for: ', LResults.GetAll[1].Name);
    end;
  end;

  // Advanced statistics
  WriteLn('');
  WriteLn('=== Advanced Statistics ===');
  if LResults.GetCount > 0 then
  begin
    // Create sample data
    SetLength(LData, 30);
    for I := 0 to 29 do
      LData[I] := LResults.GetAll[0].NsPerOp + (I mod 10) * 0.1;

    LStats := TAdvancedStats.Create(LData);
    WriteLn('Mean: ', LStats.Mean:0:2);
    WriteLn('StdDev: ', LStats.StdDev:0:2);
    WriteLn('Skewness: ', LStats.Skewness:0:2);
    WriteLn('Kurtosis: ', LStats.Kurtosis:0:2);

    LCI := LStats.ConfidenceInterval(0.95);
    WriteLn('95% CI: [', LCI.Lower:0:2, ', ', LCI.Upper:0:2, ']');

    LOutliers := LStats.DetectOutliers_Tukey;
    WriteLn('Outliers detected: ', Length(LOutliers.Outliers));
  end;

  // Memory tracking demo
  WriteLn('');
  WriteLn('=== Memory Tracking ===');
  LTracker := TMemoryTracker.Create(True);
  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.RecordFree(100);
  WriteLn('Allocations: ', LTracker.GetStats.AllocCount);
  WriteLn('Current bytes: ', LTracker.GetStats.CurrentBytes);
  WriteLn('Peak bytes: ', LTracker.GetStats.PeakBytes);

  WriteLn('');
  WriteLn('=== Demo Complete ===');
  WriteLn('');
  WriteLn('This demo showcased:');
  WriteLn('  1. Basic benchmarking with fluent API');
  WriteLn('  2. Statistical analysis (mean, stddev, percentiles)');
  WriteLn('  3. Multiple output formats (Console, JSON, TSV)');
  WriteLn('  4. Cross-language benchmark parsing');
  WriteLn('  5. Baseline management and regression detection');
  WriteLn('  6. Advanced statistics (skewness, kurtosis, CI)');
  WriteLn('  7. Memory tracking');
end.
