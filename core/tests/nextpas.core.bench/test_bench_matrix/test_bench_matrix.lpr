program test_bench_matrix;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.report,
  nextpas.core.text.conv,
  nextpas.core.test;

type
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  TBaselineData = nextpas.core.bench.base.TBaselineData;
  TBenchResults = nextpas.core.bench.TBenchResults;

{ 构造 TBenchResult 用于测试（不实际运行 benchmark） }
function MakeResult(const AName: string; ANsPerOp: Double;
  ASampleCount: Integer = 0): TBenchResult;
begin
  Result := Default(TBenchResult);
  Result.Name := AName;
  Result.Executed := True;
  Result.Skipped := False;
  Result.NsPerOp := ANsPerOp;
  Result.OpsPerSec := 1e9 / ANsPerOp;
  Result.StdDev := ANsPerOp * 0.05;
  Result.Median := ANsPerOp;
  Result.P95 := ANsPerOp * 1.1;
  Result.P99 := ANsPerOp * 1.2;
  Result.Iterations := 1000;
  Result.SampleCount := ASampleCount;
end;

{ 构造 TBaselineData }
function MakeBaseline(const AName: string; ANsPerOp: Double): TBaselineData;
begin
  Result := Default(TBaselineData);
  Result.Name := AName;
  Result.NsPerOp := ANsPerOp;
end;

{ --- 基础矩阵测试 --- }

procedure TestMatrix_Basic3Baselines;
var
  LResults: array[0..1] of TBenchResult;
  LBaselines: array[0..5] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  { 两个当前结果 }
  LResults[0] := MakeResult('Sort', 100.0);
  LResults[1] := MakeResult('Hash', 200.0);

  { 三个历史基线版本 × 两个 benchmark = 6 条基线 }
  LBaselines[0] := MakeBaseline('Sort', 120.0);   { Sort v1.0 }
  LBaselines[1] := MakeBaseline('Hash', 250.0);   { Hash v1.0 }
  LBaselines[2] := MakeBaseline('Sort', 95.0);    { Sort v1.1 }
  LBaselines[3] := MakeBaseline('Hash', 180.0);   { Hash v1.1 }
  LBaselines[4] := MakeBaseline('Sort', 100.0);   { Sort v2.0 }
  LBaselines[5] := MakeBaseline('Hash', 200.0);   { Hash v2.0 }

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    { 验证维度: 6 列 (3 版本 × 2 benchmark), 2 行 }
    Check(Length(LMatrix.BaselineNames) = 6, 'Matrix has 6 baseline columns');
    Check(Length(LMatrix.Rows) = 2, 'Matrix has 2 rows');
    Check(Length(LMatrix.GeometricMeanRatios) = 6, 'GeoMean has 6 values');

    { 验证 Sort 行: current=100, 匹配 Sort 基线 }
    Check(LMatrix.Rows[0].Name = 'Sort', 'Row 0 name = Sort');
    Check(Abs(LMatrix.Rows[0].CurrentNsPerOp - 100.0) < 0.01, 'Sort current = 100');
    { Sort/Sort@120 = 0.833 }
    Check(Abs(LMatrix.Rows[0].Cells[0].Ratio - 100.0/120.0) < 0.001,
      'Sort/Sort@120 ratio = 0.833');
    { Hash 基线不匹配 Sort → ratio=1.0 }
    Check(Abs(LMatrix.Rows[0].Cells[1].Ratio - 1.0) < 0.001,
      'Sort/Hash@250 ratio = 1.0 (no match)');

    { 验证 Hash 行: current=200, 匹配 Hash 基线 }
    Check(LMatrix.Rows[1].Name = 'Hash', 'Row 1 name = Hash');
    { Sort 基线不匹配 Hash → ratio=1.0 }
    Check(Abs(LMatrix.Rows[1].Cells[0].Ratio - 1.0) < 0.001,
      'Hash/Sort@120 ratio = 1.0 (no match)');
    { Hash/Hash@250 = 0.8 }
    Check(Abs(LMatrix.Rows[1].Cells[1].Ratio - 200.0/250.0) < 0.001,
      'Hash/Hash@250 ratio = 0.8');
  finally
    LRes.Free;
  end;
end;

{ --- 单基线退化为普通对比 --- }

procedure TestMatrix_SingleBaseline;
var
  LResults: array[0..0] of TBenchResult;
  LBaselines: array[0..0] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  LResults[0] := MakeResult('Fast', 50.0);
  LBaselines[0] := MakeBaseline('Fast', 100.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    Check(Length(LMatrix.BaselineNames) = 1, 'Single baseline: 1 column');
    Check(Length(LMatrix.Rows) = 1, 'Single baseline: 1 row');
    Check(Abs(LMatrix.Rows[0].Cells[0].Ratio - 0.5) < 0.001, 'Ratio = 0.5 (2x faster)');
    Check(Abs(LMatrix.GeometricMeanRatios[0] - 0.5) < 0.001, 'GeoMean = 0.5');
  finally
    LRes.Free;
  end;
end;

{ --- 零基线 --- }

procedure TestMatrix_EmptyBaselines;
var
  LResults: array[0..0] of TBenchResult;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  LResults[0] := MakeResult('Solo', 75.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), []);
  try
    LMatrix := LRes.CompareMultipleBaselines([]);

    Check(Length(LMatrix.BaselineNames) = 0, 'Empty baselines: 0 columns');
    Check(Length(LMatrix.Rows) = 1, 'Empty baselines: still 1 row');
    Check(Length(LMatrix.GeometricMeanRatios) = 0, 'Empty baselines: 0 geomean');
  finally
    LRes.Free;
  end;
end;

{ --- 跳过的 benchmark 不应出现在矩阵中 --- }

procedure TestMatrix_SkippedResultsFiltered;
var
  LResults: array[0..1] of TBenchResult;
  LBaselines: array[0..0] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  LResults[0] := MakeResult('Active', 100.0);
  LResults[1] := MakeResult('Skipped', 200.0);
  LResults[1].Skipped := True;

  LBaselines[0] := MakeBaseline('Active', 100.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    Check(Length(LMatrix.Rows) = 1, 'Skipped result filtered out');
    Check(LMatrix.Rows[0].Name = 'Active', 'Only active result remains');
  finally
    LRes.Free;
  end;
end;

{ --- 几何均值验证 --- }

procedure TestMatrix_GeometricMeanAccuracy;
var
  LResults: array[0..2] of TBenchResult;
  LBaselines: array[0..2] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
  LExpected: Double;
begin
  { 三个 benchmark，每个基线 100ns }
  LResults[0] := MakeResult('A', 80.0);   { ratio 0.8 }
  LResults[1] := MakeResult('B', 100.0);  { ratio 1.0 }
  LResults[2] := MakeResult('C', 125.0);  { ratio 1.25 }

  LBaselines[0] := MakeBaseline('A', 100.0);
  LBaselines[1] := MakeBaseline('B', 100.0);
  LBaselines[2] := MakeBaseline('C', 100.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    { 每列只有一个匹配: A→0.8, B→1.0, C→1.25 }
    Check(Abs(LMatrix.GeometricMeanRatios[0] - 0.8) < 0.001, 'GeoMean A = 0.8');
    Check(Abs(LMatrix.GeometricMeanRatios[1] - 1.0) < 0.001, 'GeoMean B = 1.0');
    Check(Abs(LMatrix.GeometricMeanRatios[2] - 1.25) < 0.001, 'GeoMean C = 1.25');
  finally
    LRes.Free;
  end;
end;

{ --- 2 列 x 3 行矩阵 --- }

procedure TestMatrix_2x3;
var
  LResults: array[0..2] of TBenchResult;
  LBaselines: array[0..5] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  LResults[0] := MakeResult('Bench1', 100.0);
  LResults[1] := MakeResult('Bench2', 200.0);
  LResults[2] := MakeResult('Bench3', 300.0);

  { 2 个版本 × 3 个 benchmark = 6 条基线 }
  LBaselines[0] := MakeBaseline('Bench1', 150.0);  { old }
  LBaselines[1] := MakeBaseline('Bench2', 250.0);  { old }
  LBaselines[2] := MakeBaseline('Bench3', 350.0);  { old }
  LBaselines[3] := MakeBaseline('Bench1', 180.0);  { new }
  LBaselines[4] := MakeBaseline('Bench2', 180.0);  { new }
  LBaselines[5] := MakeBaseline('Bench3', 280.0);  { new }

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    Check(Length(LMatrix.Rows) = 3, '3 rows');
    Check(Length(LMatrix.BaselineNames) = 6, '6 columns');
    Check(Length(LMatrix.Rows[0].Cells) = 6, 'Each row has 6 cells');

    { Bench1/old = 100/150 = 0.667 }
    Check(Abs(LMatrix.Rows[0].Cells[0].Ratio - 100.0/150.0) < 0.001, 'Bench1/old');
    { Bench2/new = 200/180 = 1.111 }
    Check(Abs(LMatrix.Rows[1].Cells[4].Ratio - 200.0/180.0) < 0.001, 'Bench2/new');
  finally
    LRes.Free;
  end;
end;

{ --- 基线 nsPerOp = 0 不导致除零 --- }

procedure TestMatrix_ZeroBaseline;
var
  LResults: array[0..0] of TBenchResult;
  LBaselines: array[0..0] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
begin
  LResults[0] := MakeResult('Bench', 100.0);
  LBaselines[0] := MakeBaseline('Bench', 0.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    Check(Abs(LMatrix.Rows[0].Cells[0].Ratio - 1.0) < 0.001,
      'Zero baseline -> ratio defaults to 1.0');
    Check(not LMatrix.Rows[0].Cells[0].IsSignificant,
      'Zero baseline -> not significant');
  finally
    LRes.Free;
  end;
end;

{ --- Console 报告生成 --- }

procedure TestMatrix_ConsoleReport;
var
  LResults: array[0..1] of TBenchResult;
  LBaselines: array[0..3] of TBaselineData;
  LRes: TBenchResults;
  LReport: string;
begin
  LResults[0] := MakeResult('Sort', 100.0);
  LResults[1] := MakeResult('Hash', 200.0);
  LBaselines[0] := MakeBaseline('Sort', 120.0);
  LBaselines[1] := MakeBaseline('Hash', 250.0);
  LBaselines[2] := MakeBaseline('Sort', 90.0);
  LBaselines[3] := MakeBaseline('Hash', 180.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LReport := LRes.ToMatrixReport(LBaselines);

    Check(Length(LReport) > 0, 'Report not empty');
    Check(Pos('Multi-Baseline', LReport) > 0, 'Report contains title');
    Check(Pos('Sort', LReport) > 0, 'Report contains Sort');
    Check(Pos('Hash', LReport) > 0, 'Report contains Hash');
    Check(Pos('Geometric Mean', LReport) > 0, 'Report has geometric mean row');
  finally
    LRes.Free;
  end;
end;

{ --- HTML 报告生成 --- }

procedure TestMatrix_HTMLReport;
var
  LResults: array[0..0] of TBenchResult;
  LBaselines: array[0..1] of TBaselineData;
  LRes: TBenchResults;
  LHTML: string;
begin
  LResults[0] := MakeResult('Sort', 100.0);
  LBaselines[0] := MakeBaseline('Sort', 120.0);
  LBaselines[1] := MakeBaseline('Sort', 80.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LHTML := LRes.ToMatrixHTML(LBaselines);

    Check(Length(LHTML) > 0, 'HTML not empty');
    Check(Pos('<table', LHTML) > 0, 'HTML has table');
    Check(Pos('Multi-Baseline', LHTML) > 0, 'HTML has title');
    Check(Pos('Sort', LHTML) > 0, 'HTML has Sort');
    Check(Pos('Geometric Mean', LHTML) > 0, 'HTML has geo mean row');
    Check(Pos('class="faster"', LHTML) > 0, 'HTML has faster class (100/120=0.833)');
    Check(Pos('class="slower"', LHTML) > 0, 'HTML has slower class (100/80=1.25)');
  finally
    LRes.Free;
  end;
end;

{ --- 大量基线（10 列）压力测试 --- }

procedure TestMatrix_ManyBaselines;
var
  LResults: array[0..0] of TBenchResult;
  LBaselines: array[0..9] of TBaselineData;
  LRes: TBenchResults;
  LMatrix: TMatrixResult;
  I: Integer;
begin
  LResults[0] := MakeResult('Bench', 100.0);
  for I := 0 to 9 do
    LBaselines[I] := MakeBaseline('Bench', 80.0 + I * 5.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LMatrix := LRes.CompareMultipleBaselines(LBaselines);

    Check(Length(LMatrix.BaselineNames) = 10, '10 baseline columns');
    Check(Length(LMatrix.Rows[0].Cells) = 10, '10 cells per row');
    Check(Length(LMatrix.GeometricMeanRatios) = 10, '10 geomean values');

    { v0=80: ratio = 100/80 = 1.25 }
    Check(Abs(LMatrix.Rows[0].Cells[0].Ratio - 1.25) < 0.001, 'v0 ratio');
    { v9=125: ratio = 100/125 = 0.8 }
    Check(Abs(LMatrix.Rows[0].Cells[9].Ratio - 0.8) < 0.001, 'v9 ratio');
  finally
    LRes.Free;
  end;
end;

{ --- P2-3: 分布直方图 --- }

procedure TestDistributionChart;
var
  LGen: TBenchReportGenerator;
  LSamples: TDoubleArray;
  LSVG: string;
  I: Integer;
begin
  LGen := TBenchReportGenerator.Create;
  try
    { 生成正态分布样本 }
    RandSeed := 42;
    SetLength(LSamples, 100);
    for I := 0 to 99 do
      LSamples[I] := 100.0 + (Random - 0.5) * 20.0;

    LSVG := LGen.GenerateDistributionChart(LSamples, 'Sort');

    Check(Length(LSVG) > 0, 'Distribution chart not empty');
    Check(Pos('<svg', LSVG) > 0, 'Has SVG tag');
    Check(Pos('Sort', LSVG) > 0, 'Has benchmark name');
    Check(Pos('100 samples', LSVG) > 0, 'Has sample count');
    Check(Pos('distribution', LSVG) > 0, 'Has distribution label');
  finally
    LGen.Free;
  end;
end;

{ 空样本返回空字符串 }
procedure TestDistributionChart_Empty;
var
  LGen: TBenchReportGenerator;
  LSamples: TDoubleArray;
  LSVG: string;
begin
  LGen := TBenchReportGenerator.Create;
  try
    SetLength(LSamples, 0);
    LSVG := LGen.GenerateDistributionChart(LSamples, 'Empty');
    Check(LSVG = '', 'Empty samples returns empty SVG');

    SetLength(LSamples, 1);
    LSamples[0] := 100.0;
    LSVG := LGen.GenerateDistributionChart(LSamples, 'Single');
    Check(LSVG = '', 'Single sample returns empty SVG');
  finally
    LGen.Free;
  end;
end;

{ --- P2-3: 基线对比图 --- }

procedure TestComparisonChart;
var
  LGen: TBenchReportGenerator;
  LComparisons: array[0..2] of TBenchComparison;
  LSVG: string;
begin
  LGen := TBenchReportGenerator.Create;
  try
    LComparisons[0] := Default(TBenchComparison);
    LComparisons[0].BaselineName := 'v1.0';
    LComparisons[0].CurrentNsPerOp := 100.0;
    LComparisons[0].BaselineNsPerOp := 120.0;
    LComparisons[0].Ratio := 0.833;

    LComparisons[1] := Default(TBenchComparison);
    LComparisons[1].BaselineName := 'v1.1';
    LComparisons[1].CurrentNsPerOp := 100.0;
    LComparisons[1].BaselineNsPerOp := 95.0;
    LComparisons[1].Ratio := 1.053;

    LComparisons[2] := Default(TBenchComparison);
    LComparisons[2].BaselineName := 'v2.0';
    LComparisons[2].CurrentNsPerOp := 100.0;
    LComparisons[2].BaselineNsPerOp := 100.0;
    LComparisons[2].Ratio := 1.0;

    LSVG := LGen.GenerateComparisonChart(LComparisons);

    Check(Length(LSVG) > 0, 'Comparison chart not empty');
    Check(Pos('<svg', LSVG) > 0, 'Has SVG tag');
    Check(Pos('Current', LSVG) > 0, 'Has Current legend');
    Check(Pos('Baseline', LSVG) > 0, 'Has Baseline legend');
    Check(Pos('v1.0', LSVG) > 0, 'Has v1.0 label');
    Check(Pos('v1.1', LSVG) > 0, 'Has v1.1 label');
    Check(Pos('v2.0', LSVG) > 0, 'Has v2.0 label');
    Check(Pos('0.83x', LSVG) > 0, 'Has v1.0 ratio');
  finally
    LGen.Free;
  end;
end;

{ 空对比返回空字符串 }
procedure TestComparisonChart_Empty;
var
  LGen: TBenchReportGenerator;
  LSVG: string;
begin
  LGen := TBenchReportGenerator.Create;
  try
    LSVG := LGen.GenerateComparisonChart([]);
    Check(LSVG = '', 'Empty comparisons returns empty SVG');
  finally
    LGen.Free;
  end;
end;

{ --- P2 polish: JSON 矩阵导出 --- }

procedure TestMatrix_JSON;
var
  LResults: array[0..1] of TBenchResult;
  LBaselines: array[0..3] of TBaselineData;
  LRes: TBenchResults;
  LJSON: string;
begin
  LResults[0] := MakeResult('Sort', 100.0);
  LResults[1] := MakeResult('Hash', 200.0);
  LBaselines[0] := MakeBaseline('Sort', 120.0);
  LBaselines[1] := MakeBaseline('Hash', 250.0);
  LBaselines[2] := MakeBaseline('Sort', 90.0);
  LBaselines[3] := MakeBaseline('Hash', 180.0);

  LRes := TBenchResults.Create(LResults, Default(TBenchEnvironment), LBaselines);
  try
    LJSON := LRes.ToMatrixJSON(LBaselines);

    Check(Length(LJSON) > 0, 'JSON not empty');
    Check(Pos('"baselines"', LJSON) > 0, 'Has baselines key');
    Check(Pos('"rows"', LJSON) > 0, 'Has rows key');
    Check(Pos('"geometricMeanRatios"', LJSON) > 0, 'Has geomean key');
    Check(Pos('"Sort"', LJSON) > 0, 'Has Sort entry');
    Check(Pos('"Hash"', LJSON) > 0, 'Has Hash entry');
    Check(Pos('"ratios"', LJSON) > 0, 'Has ratios array');
    Check(Pos('"nsPerOp"', LJSON) > 0, 'Has nsPerOp');
    Check(Pos('"bytesPerOp"', LJSON) > 0, 'Has bytesPerOp');
    Check(Pos('"allocsPerOp"', LJSON) > 0, 'Has allocsPerOp');
  finally
    LRes.Free;
  end;
end;

var
  T: TTestSuite;
begin
  WriteLn('=== test_bench_matrix ===');
  WriteLn;

  T := TTestSuite.Create('nextpas.core.bench.matrix');

  T.Test('Basic3Baselines', @TestMatrix_Basic3Baselines);
  T.Test('SingleBaseline', @TestMatrix_SingleBaseline);
  T.Test('EmptyBaselines', @TestMatrix_EmptyBaselines);
  T.Test('SkippedResultsFiltered', @TestMatrix_SkippedResultsFiltered);
  T.Test('GeometricMeanAccuracy', @TestMatrix_GeometricMeanAccuracy);
  T.Test('2x3', @TestMatrix_2x3);
  T.Test('ZeroBaseline', @TestMatrix_ZeroBaseline);
  T.Test('ConsoleReport', @TestMatrix_ConsoleReport);
  T.Test('HTMLReport', @TestMatrix_HTMLReport);
  T.Test('ManyBaselines', @TestMatrix_ManyBaselines);
  T.Test('DistributionChart', @TestDistributionChart);
  T.Test('DistributionChart_Empty', @TestDistributionChart_Empty);
  T.Test('ComparisonChart', @TestComparisonChart);
  T.Test('ComparisonChart_Empty', @TestComparisonChart_Empty);
  T.Test('MatrixJSON', @TestMatrix_JSON);

  T.Run;
  T.Summary;
end.
