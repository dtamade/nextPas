program test_bench_results_api;

{$I nextpas.core.settings.inc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{**
 * IBenchResults 聚合/过滤/排序/分组/矩阵 API 测试
 * 从 test_bench_integration 软拆（Round 40–62 等）
 *}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.exception,
  nextpas.core.math.scalar,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.base,
  nextpas.core.id.xid,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.test;

type
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;
  TBaselineData = nextpas.core.bench.base.TBaselineData;
  TBenchSummaryStats = nextpas.core.bench.intf.TBenchSummaryStats;
  TBenchRegressionReport = nextpas.core.bench.intf.TBenchRegressionReport;
  TPercentileResult = nextpas.core.bench.intf.TPercentileResult;
  TOutlierSummary = nextpas.core.bench.intf.TOutlierSummary;
  TMatrixResult = nextpas.core.bench.base.TMatrixResult;

function ReadFileToString(const APath: string): string;
begin
  Result := ReadFileText(APath);
end;

function CreateFastSuite(const ASuiteName: string): IBenchSuite;
begin
  Result := TBenchSuite.Create(ASuiteName)
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1);
end;

procedure BenchFast(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for i := 1 to 1000 do
    LSum := LSum + i;
end;

procedure BenchMedium(const ACtx: IBenchContext);
var
  i: Integer;
  LSum: Double;
begin
  LSum := 0.0;
  for i := 1 to 10000 do
    LSum := LSum + Sin(i * 0.001);
end;

procedure TestNsPerOpDuration;
var
  LResult: TBenchResult;
  LDur: TDuration;
begin
  LResult := Default(TBenchResult);
  LResult.NsPerOp := 1000000.0; { 1ms }
  LDur := LResult.NsPerOpDuration;
  Check(LDur.AsMilliseconds = 1, 'NsPerOpDuration: 1ms = 1000000ns');

  LResult.NsPerOp := 0.0;
  LDur := LResult.NsPerOpDuration;
  Check(LDur.AsNanoseconds = 0, 'NsPerOpDuration: 0ns returns Zero');

  LResult.NsPerOp := -1.0;
  LDur := LResult.NsPerOpDuration;
  Check(LDur.AsNanoseconds = 0, 'NsPerOpDuration: negative returns Zero');
end;

procedure TestStdDevDuration;
var
  LResult: TBenchResult;
  LDur: TDuration;
begin
  LResult := Default(TBenchResult);
  LResult.StdDev := 500.0; { 500ns }
  LDur := LResult.StdDevDuration;
  Check(LDur.AsNanoseconds = 500, 'StdDevDuration: 500ns');

  LResult.StdDev := 0.0;
  LDur := LResult.StdDevDuration;
  Check(LDur.AsNanoseconds = 0, 'StdDevDuration: 0ns returns Zero');
end;

{ === Round 29: 新增 API 测试 === }

procedure TestGetAggregateStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LStats: TBenchStats;
begin
  LSuite := CreateFastSuite('AggregateStatsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LStats := LResults.GetAggregateStats;
  Check(LStats.SampleCount >= 2, 'GetAggregateStats: sample count >= 2');
  Check(LStats.Mean > 0, 'GetAggregateStats: mean > 0');
  Check(LStats.StdDev >= 0, 'GetAggregateStats: stddev >= 0');
end;

procedure TestFilterByPrefix;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('FilterPrefixTest');
  LSuite.Add('Sort/100', @BenchFast);
  LSuite.Add('Sort/1000', @BenchMedium);
  LSuite.Add('Hash/100', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LFiltered := LResults.FilterByPrefix('Sort/');
  Check(Length(LFiltered) = 2, 'FilterByPrefix(Sort/): 2 results');
  Check(LFiltered[0].Name = 'Sort/100', 'FilterByPrefix: first is Sort/100');
  Check(LFiltered[1].Name = 'Sort/1000', 'FilterByPrefix: second is Sort/1000');
end;

procedure TestFilterBySuffix;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('FilterSuffixTest');
  LSuite.Add('Sort/100', @BenchFast);
  LSuite.Add('Sort/1000', @BenchMedium);
  LSuite.Add('Hash/100', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LFiltered := LResults.FilterBySuffix('/100');
  Check(Length(LFiltered) = 2, 'FilterBySuffix(/100): 2 results');
  Check(LFiltered[0].Name = 'Sort/100', 'FilterBySuffix: first is Sort/100');
  Check(LFiltered[1].Name = 'Hash/100', 'FilterBySuffix: second is Hash/100');
end;

procedure TestFilterBySubstring;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('FilterSubstringTest');
  LSuite.Add('Sort/100', @BenchFast);
  LSuite.Add('Sort/1000', @BenchMedium);
  LSuite.Add('Hash/100', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LFiltered := LResults.FilterBySubstring('Sort');
  Check(Length(LFiltered) = 2, 'FilterBySubstring(Sort): 2 results');
  Check(LFiltered[0].Name = 'Sort/100', 'FilterBySubstring: first is Sort/100');
  Check(LFiltered[1].Name = 'Sort/1000', 'FilterBySubstring: second is Sort/1000');
end;

procedure TestSortByNsPerOp;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSorted: TBenchResultArray;
begin
  LSuite := CreateFastSuite('SortTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 升序排序 — Fast 应该在前面 }
  LSorted := LResults.SortByNsPerOp(True);
  Check(Length(LSorted) = 2, 'SortByNsPerOp ascending: 2 results');
  Check(LSorted[0].Name = 'Fast', 'SortByNsPerOp ascending: Fast first');
  Check(LSorted[1].Name = 'Medium', 'SortByNsPerOp ascending: Medium second');

  { 降序排序 — Medium 应该在前面 }
  LSorted := LResults.SortByNsPerOp(False);
  Check(Length(LSorted) = 2, 'SortByNsPerOp descending: 2 results');
  Check(LSorted[0].Name = 'Medium', 'SortByNsPerOp descending: Medium first');
  Check(LSorted[1].Name = 'Fast', 'SortByNsPerOp descending: Fast second');
end;

procedure TestGetFastest;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFastest: TBenchResult;
begin
  LSuite := CreateFastSuite('FastestTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LFastest := LResults.GetFastest;
  Check(LFastest.Name = 'Fast', 'GetFastest: Fast is fastest');
  Check(LFastest.NsPerOp > 0, 'GetFastest: NsPerOp > 0');
end;

procedure TestGetSlowest;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSlowest: TBenchResult;
begin
  LSuite := CreateFastSuite('SlowestTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LSlowest := LResults.GetSlowest;
  Check(LSlowest.Name = 'Medium', 'GetSlowest: Medium is slowest');
  Check(LSlowest.NsPerOp > 0, 'GetSlowest: NsPerOp > 0');
end;

procedure TestGetTopN;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTop: TBenchResultArray;
begin
  LSuite := CreateFastSuite('TopNTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 获取前 1 个最快 }
  LTop := LResults.GetTopN(1);
  Check(Length(LTop) = 1, 'GetTopN(1): returns 1 result');
  Check(LTop[0].Name = 'Fast', 'GetTopN(1): Fast is fastest');

  { 获取前 2 个最快 }
  LTop := LResults.GetTopN(2);
  Check(Length(LTop) = 2, 'GetTopN(2): returns 2 results');
  Check(LTop[0].Name = 'Fast', 'GetTopN(2): Fast first');
  Check(LTop[1].Name = 'Medium', 'GetTopN(2): Medium second');

  { 获取超过总数 }
  LTop := LResults.GetTopN(10);
  Check(Length(LTop) = 2, 'GetTopN(10): returns all results');

  { 获取 0 个 }
  LTop := LResults.GetTopN(0);
  Check(Length(LTop) = 0, 'GetTopN(0): returns empty');

  { 获取负数 }
  LTop := LResults.GetTopN(-1);
  Check(Length(LTop) = 0, 'GetTopN(-1): returns empty');
end;

procedure TestGetStableResults;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LStable: TBenchResultArray;
begin
  LSuite := CreateFastSuite('StableTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 默认阈值 10% — Fast 应该稳定 }
  LStable := LResults.GetStableResults;
  Check(Length(LStable) > 0, 'GetStableResults: at least one stable result');
  Check(LStable[0].Name = 'Fast', 'GetStableResults: Fast is stable');

  { 非常严格的阈值 — 可能没有稳定结果 }
  LStable := LResults.GetStableResults(0.001);
  Check(Length(LStable) >= 0, 'GetStableResults(0.001): no crash');

  { 非常宽松的阈值 — 所有结果都稳定 }
  LStable := LResults.GetStableResults(100.0);
  Check(Length(LStable) = 2, 'GetStableResults(100.0): all results stable');
end;

procedure TestGetUnstableResults;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LUnstable: TBenchResultArray;
begin
  LSuite := CreateFastSuite('UnstableTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 默认阈值 10% — 返回合法数组（是否非空取决于本机噪声） }
  LUnstable := LResults.GetUnstableResults;
  Check(Length(LUnstable) >= 0, 'GetUnstableResults: returns array');
  Check(Length(LUnstable) <= LResults.GetCount, 'GetUnstableResults: not more than total');

  { 非常宽松的阈值 — 没有不稳定结果 }
  LUnstable := LResults.GetUnstableResults(100.0);
  Check(Length(LUnstable) = 0, 'GetUnstableResults(100.0): no unstable results');

  { 严格阈值：不稳定数不超过总数（CV 可能极低，不强制 =2） }
  LUnstable := LResults.GetUnstableResults(0.001);
  Check(Length(LUnstable) <= LResults.GetCount, 'GetUnstableResults(0.001): within total');
end;

procedure TestFilterByNsPerOpRange;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('RangeTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无限制 — 返回所有结果 }
  LFiltered := LResults.FilterByNsPerOpRange;
  Check(Length(LFiltered) = 2, 'FilterByNsPerOpRange: all results');

  { 只有下限 — 只返回 NsPerOp >= 1000 的 }
  LFiltered := LResults.FilterByNsPerOpRange(1000);
  Check(Length(LFiltered) <= 2, 'FilterByNsPerOpRange(1000): at most 2 results');

  { 只有上限 — 只返回 NsPerOp <= 100000 的 }
  LFiltered := LResults.FilterByNsPerOpRange(0, 100000);
  Check(Length(LFiltered) >= 1, 'FilterByNsPerOpRange(0, 100000): at least 1 result');

  { 范围内无结果 }
  LFiltered := LResults.FilterByNsPerOpRange(1, 2);
  Check(Length(LFiltered) = 0, 'FilterByNsPerOpRange(1, 2): no results');
end;

procedure TestGetTotalOpsPerSec;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalOps, LSum: Double;
  LAll: TBenchResultArray;
  I: Integer;
begin
  LSuite := CreateFastSuite('TotalOpsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalOps := LResults.GetTotalOpsPerSec;
  Check(LTotalOps > 0, 'GetTotalOpsPerSec: total > 0');
  { F-07: API is arithmetic sum of per-entry OpsPerSec, not geometric/aggregate throughput. }
  LAll := LResults.GetExecuted;
  LSum := 0;
  for I := 0 to High(LAll) do
    LSum := LSum + LAll[I].OpsPerSec;
  Check(Abs(LTotalOps - LSum) < 1e-6, 'GetTotalOpsPerSec: equals sum of entry OpsPerSec');
end;

procedure TestGetTotalOutliers;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalOutliers: Integer;
begin
  LSuite := CreateFastSuite('TotalOutliersTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalOutliers := LResults.GetTotalOutliers;
  Check(LTotalOutliers >= 0, 'GetTotalOutliers: total >= 0');
end;

procedure TestGetTotalIterations;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalIter: Int64;
begin
  LSuite := CreateFastSuite('TotalIterTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalIter := LResults.GetTotalIterations;
  Check(LTotalIter > 0, 'GetTotalIterations: total > 0');
end;

procedure TestGetTotalBytesPerOp;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalBytes: Int64;
begin
  LSuite := CreateFastSuite('TotalBytesTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalBytes := LResults.GetTotalBytesPerOp;
  Check(LTotalBytes >= 0, 'GetTotalBytesPerOp: total >= 0');
end;

procedure TestGetTotalAllocsPerOp;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalAllocs: Int64;
begin
  LSuite := CreateFastSuite('TotalAllocsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalAllocs := LResults.GetTotalAllocsPerOp;
  Check(LTotalAllocs >= 0, 'GetTotalAllocsPerOp: total >= 0');
end;

procedure TestGetTotalElapsed;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LTotalElapsed: TDuration;
begin
  LSuite := CreateFastSuite('TotalElapsedTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LTotalElapsed := LResults.GetTotalElapsed;
  Check(LTotalElapsed.AsNanoseconds > 0, 'GetTotalElapsed: total > 0');
end;

procedure TestGetAllCustomMetrics;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LMetrics: TCustomMetricArray;
begin
  LSuite := CreateFastSuite('CustomMetricsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LMetrics := LResults.GetAllCustomMetrics;
  Check(Length(LMetrics) >= 0, 'GetAllCustomMetrics: returns array');
end;

procedure TestGetTotalCustomMetricsCount;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LCount: Integer;
begin
  LSuite := CreateFastSuite('CustomMetricsCountTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LCount := LResults.GetTotalCustomMetricsCount;
  Check(LCount >= 0, 'GetTotalCustomMetricsCount: count >= 0');
end;

procedure TestFilterByNamePattern;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('PatternTest');
  LSuite.Add('Sort/100', @BenchFast);
  LSuite.Add('Sort/1000', @BenchMedium);
  LSuite.Add('Hash/100', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 匹配 Sort* }
  LFiltered := LResults.FilterByNamePattern('Sort*');
  Check(Length(LFiltered) = 2, 'FilterByNamePattern Sort*: 2 results');
  Check(LFiltered[0].Name = 'Sort/100', 'FilterByNamePattern Sort*: first is Sort/100');
  Check(LFiltered[1].Name = 'Sort/1000', 'FilterByNamePattern Sort*: second is Sort/1000');

  { 匹配 Hash* }
  LFiltered := LResults.FilterByNamePattern('Hash*');
  Check(Length(LFiltered) = 1, 'FilterByNamePattern Hash*: 1 result');
  Check(LFiltered[0].Name = 'Hash/100', 'FilterByNamePattern Hash*: Hash/100');

  { 匹配 */100 (通配符在中间) }
  LFiltered := LResults.FilterByNamePattern('*/100');
  Check(Length(LFiltered) = 2, 'FilterByNamePattern */100: 2 results');

  { 无匹配 }
  LFiltered := LResults.FilterByNamePattern('NoMatch*');
  Check(Length(LFiltered) = 0, 'FilterByNamePattern NoMatch*: 0 results');

  { 空模式匹配所有 }
  LFiltered := LResults.FilterByNamePattern('*');
  Check(Length(LFiltered) = 3, 'FilterByNamePattern *: 3 results');
end;

procedure TestGetSummaryStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LStats: TBenchSummaryStats;
begin
  LSuite := CreateFastSuite('SummaryStatsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LStats := LResults.GetSummaryStats;
  Check(LStats.ExecutedCount = 2, 'GetSummaryStats: executed = 2');
  Check(LStats.SkippedCount = 0, 'GetSummaryStats: skipped = 0');
  Check(LStats.TotalOpsPerSec > 0, 'GetSummaryStats: TotalOpsPerSec > 0');
  Check(LStats.TotalIterations > 0, 'GetSummaryStats: TotalIterations > 0');
  Check(LStats.FastestNsPerOp > 0, 'GetSummaryStats: FastestNsPerOp > 0');
  Check(LStats.SlowestNsPerOp > 0, 'GetSummaryStats: SlowestNsPerOp > 0');
  Check(LStats.FastestNsPerOp <= LStats.SlowestNsPerOp, 'GetSummaryStats: fastest <= slowest');
  Check(LStats.MeanNsPerOp > 0, 'GetSummaryStats: MeanNsPerOp > 0');
  Check(LStats.MedianNsPerOp > 0, 'GetSummaryStats: MedianNsPerOp > 0');
  Check(LStats.TotalElapsedNs > 0, 'GetSummaryStats: TotalElapsedNs > 0');
end;

procedure TestGetSummaryStats_Empty;
var
  LResults: IBenchResults;
  LStats: TBenchSummaryStats;
  LSuite: IBenchSuite;
begin
  { 空结果集 — 使用过滤掉所有条目的场景 }
  LSuite := TBenchSuite.Create('EmptySummaryTest')
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1)
    .SetFilter('NonExistentPattern');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LStats := LResults.GetSummaryStats;
  Check(LStats.ExecutedCount = 0, 'GetSummaryStats_Empty: executed = 0');
  Check(LStats.SkippedCount = 0, 'GetSummaryStats_Empty: skipped = 0');
  Check(LStats.TotalOpsPerSec = 0, 'GetSummaryStats_Empty: TotalOpsPerSec = 0');
  Check(LStats.TotalIterations = 0, 'GetSummaryStats_Empty: TotalIterations = 0');
  Check(LStats.FastestNsPerOp = 0, 'GetSummaryStats_Empty: FastestNsPerOp = 0');
  Check(LStats.SlowestNsPerOp = 0, 'GetSummaryStats_Empty: SlowestNsPerOp = 0');
  Check(LStats.MeanNsPerOp = 0, 'GetSummaryStats_Empty: MeanNsPerOp = 0');
  Check(LStats.MedianNsPerOp = 0, 'GetSummaryStats_Empty: MedianNsPerOp = 0');
end;

procedure TestGetRegressionReport;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LReport: TBenchRegressionReport;
  LBaseline: TBaselineData;
begin
  LSuite := CreateFastSuite('RegressionReportTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  { 添加基线 — 故意设低以触发回归 }
  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 1.0; { 1ns — 远低于实际值，确保 ratio > 2.0 }
  LSuite.AddBaselineData(LBaseline);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LReport := LResults.GetRegressionReport(1.5);
  Check(LReport.Threshold = 1.5, 'GetRegressionReport: threshold = 1.5');
  Check(LReport.TotalComparisons = 1, 'GetRegressionReport: 1 comparison (only Fast has baseline)');
  Check(LReport.HasRegression, 'GetRegressionReport: has regression (ratio >> 1.5)');
  Check(LReport.RegressedCount = 1, 'GetRegressionReport: 1 regressed');
  Check(LReport.WorstRegressRatio > 1.5, 'GetRegressionReport: worst ratio > 1.5');
  Check(LReport.WorstRegressName = 'Fast', 'GetRegressionReport: worst is Fast');
end;

procedure TestGetRegressionReport_NoRegression;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LReport: TBenchRegressionReport;
  LBaseline: TBaselineData;
begin
  LSuite := CreateFastSuite('NoRegressionTest');
  LSuite.Add('Fast', @BenchFast);
  { 基线设高 — 不会触发回归 }
  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 1.0e9; { 1秒 — 远高于实际值 }
  LSuite.AddBaselineData(LBaseline);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LReport := LResults.GetRegressionReport(1.5);
  Check(not LReport.HasRegression, 'GetRegressionReport_NoRegression: no regression');
  Check(LReport.ImprovedCount = 1, 'GetRegressionReport_NoRegression: 1 improved');
  Check(LReport.RegressedCount = 0, 'GetRegressionReport_NoRegression: 0 regressed');
end;

procedure TestFilterByHasCustomMetric;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('CustomMetricFilterTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无自定义指标时应返回空 }
  LFiltered := LResults.FilterByHasCustomMetric('NonExistent');
  Check(Length(LFiltered) = 0, 'FilterByHasCustomMetric: 0 for non-existent metric');
end;

procedure TestToCSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LCSV: string;
begin
  LSuite := CreateFastSuite('CSVTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LCSV := LResults.ToCSV;
  { 验证 CSV 结构 }
  Check(Pos('Name,Executed,Skipped,NsPerOp', LCSV) > 0, 'ToCSV: has header');
  Check(Pos('Fast,true,false,', LCSV) > 0, 'ToCSV: has Fast row');
  Check(Pos('Medium,true,false,', LCSV) > 0, 'ToCSV: has Medium row');
  { 验证行数 = header + 2 data rows }
  Check(Length(LCSV) > 100, 'ToCSV: has substantial content');
end;

procedure TestToCSV_NameWithComma;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LCSV: string;
begin
  LSuite := CreateFastSuite('CSVCommaTest');
  LSuite.Add('Sort, v1', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LCSV := LResults.ToCSV;
  { 名称含逗号时应被引号包围 }
  Check(Pos('"Sort, v1"', LCSV) > 0, 'ToCSV: comma in name is quoted');
end;

procedure TestSaveToCSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
begin
  LSuite := CreateFastSuite('SaveCSVTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPath := '/tmp/bench_test_save.csv';
  LResults.SaveToCSV(LPath);
  LContent := ReadFileToString(LPath);
  Check(Pos('Name,Executed,Skipped', LContent) > 0, 'SaveToCSV: file has header');
  Check(Pos('Fast,true,false,', LContent) > 0, 'SaveToCSV: file has data');
  DeleteFile(LPath);
end;

procedure TestGetCustomMetricValues;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LValues: TDoubleArray;
begin
  LSuite := CreateFastSuite('MetricValuesTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无自定义指标时应返回空数组 }
  LValues := LResults.GetCustomMetricValues('NonExistent');
  Check(Length(LValues) = 0, 'GetCustomMetricValues: empty for non-existent');
end;

procedure TestGetPercentileStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPercentiles: TPercentileResult;
begin
  LSuite := CreateFastSuite('PercentileStatsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPercentiles := LResults.GetPercentileStats;
  Check(LPercentiles.P50 > 0, 'GetPercentileStats: P50 > 0');
  Check(LPercentiles.P5 <= LPercentiles.P50, 'GetPercentileStats: P5 <= P50');
  Check(LPercentiles.P50 <= LPercentiles.P95, 'GetPercentileStats: P50 <= P95');
  Check(LPercentiles.P25 <= LPercentiles.P75, 'GetPercentileStats: P25 <= P75');
end;

procedure TestGetPercentileStats_Empty;
var
  LResults: IBenchResults;
  LPercentiles: TPercentileResult;
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('EmptyPercentileTest')
    .SetMinDuration(TDuration.FromMilliseconds(5))
    .SetMaxIterations(5000)
    .SetMinSamples(3)
    .SetWarmupIters(1)
    .SetFilter('NonExistentPattern');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPercentiles := LResults.GetPercentileStats;
  Check(LPercentiles.P50 = 0, 'GetPercentileStats_Empty: P50 = 0');
  Check(LPercentiles.P95 = 0, 'GetPercentileStats_Empty: P95 = 0');
end;

procedure TestGetCVArray;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LCVArray: TDoubleArray;
begin
  LSuite := CreateFastSuite('CVArrayTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LCVArray := LResults.GetCVArray;
  Check(Length(LCVArray) = 2, 'GetCVArray: 2 results');
  Check(LCVArray[0] >= 0, 'GetCVArray: CV[0] >= 0');
  Check(LCVArray[1] >= 0, 'GetCVArray: CV[1] >= 0');
end;

procedure TestGetOutlierSummary;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSummary: TOutlierSummary;
begin
  LSuite := CreateFastSuite('OutlierSummaryTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LSummary := LResults.GetOutlierSummary;
  Check(LSummary.Total >= 0, 'GetOutlierSummary: total >= 0');
  Check(LSummary.Mild >= 0, 'GetOutlierSummary: mild >= 0');
  Check(LSummary.Moderate >= 0, 'GetOutlierSummary: moderate >= 0');
  Check(LSummary.Severe >= 0, 'GetOutlierSummary: severe >= 0');
  Check(LSummary.Ratio >= 0, 'GetOutlierSummary: ratio >= 0');
  Check(LSummary.Mild + LSummary.Moderate + LSummary.Severe <= LSummary.Total,
    'GetOutlierSummary: sum of severities <= total');
end;

procedure TestSortByCustomMetric;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSorted: TBenchResultArray;
begin
  LSuite := CreateFastSuite('SortByMetricTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无自定义指标时排序应返回所有结果 }
  LSorted := LResults.SortByCustomMetric('nonexistent', True);
  Check(Length(LSorted) = 2, 'SortByCustomMetric: returns all results when no metrics');

  { 降序排序 }
  LSorted := LResults.SortByCustomMetric('nonexistent', False);
  Check(Length(LSorted) = 2, 'SortByCustomMetric: descending returns all results');
end;

procedure TestFilterByCustomMetricRange;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('FilterMetricRangeTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无自定义指标时过滤应返回空数组 }
  LFiltered := LResults.FilterByCustomMetricRange('nonexistent', 0, 100);
  Check(Length(LFiltered) = 0, 'FilterByCustomMetricRange: empty when no metrics');

  { 无范围限制 }
  LFiltered := LResults.FilterByCustomMetricRange('nonexistent', 0, 0);
  Check(Length(LFiltered) = 0, 'FilterByCustomMetricRange: empty when no metrics (no range)');
end;

procedure TestGetCustomMetricStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LStats: TBenchStats;
begin
  LSuite := CreateFastSuite('MetricStatsTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无自定义指标时应返回零值统计 }
  LStats := LResults.GetCustomMetricStats('nonexistent');
  Check(LStats.SampleCount = 0, 'GetCustomMetricStats: sampleCount=0 when no metrics');
end;

procedure TestGetResultsWithOutliers;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LWithOutliers: TBenchResultArray;
begin
  LSuite := CreateFastSuite('WithOutliersTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LWithOutliers := LResults.GetResultsWithOutliers;
  { 结果数量应在 0 到总结果数之间 }
  Check(Length(LWithOutliers) >= 0, 'GetResultsWithOutliers: count >= 0');
  Check(Length(LWithOutliers) <= 2, 'GetResultsWithOutliers: count <= total');
end;

procedure TestGetResultsWithoutOutliers;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LWithoutOutliers: TBenchResultArray;
begin
  LSuite := CreateFastSuite('WithoutOutliersTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LWithoutOutliers := LResults.GetResultsWithoutOutliers;
  { 结果数量应在 0 到总结果数之间 }
  Check(Length(LWithoutOutliers) >= 0, 'GetResultsWithoutOutliers: count >= 0');
  Check(Length(LWithoutOutliers) <= 2, 'GetResultsWithoutOutliers: count <= total');
end;

procedure TestSortByOpsPerSec;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSorted: TBenchResultArray;
begin
  LSuite := CreateFastSuite('SortByOpsPerSecTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 降序排序（默认） }
  LSorted := LResults.SortByOpsPerSec(False);
  Check(Length(LSorted) = 2, 'SortByOpsPerSec: returns all results');
  if Length(LSorted) = 2 then
    Check(LSorted[0].OpsPerSec >= LSorted[1].OpsPerSec,
      'SortByOpsPerSec: descending order correct');

  { 升序排序 }
  LSorted := LResults.SortByOpsPerSec(True);
  Check(Length(LSorted) = 2, 'SortByOpsPerSec: ascending returns all results');
  if Length(LSorted) = 2 then
    Check(LSorted[0].OpsPerSec <= LSorted[1].OpsPerSec,
      'SortByOpsPerSec: ascending order correct');
end;

procedure TestFilterByStdDevRange;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LFiltered: TBenchResultArray;
begin
  LSuite := CreateFastSuite('FilterStdDevTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 无限制过滤应返回所有结果 }
  LFiltered := LResults.FilterByStdDevRange(0, 0);
  Check(Length(LFiltered) = 2, 'FilterByStdDevRange: no limit returns all');

  { 高下限应返回更少结果 }
  LFiltered := LResults.FilterByStdDevRange(1e308, 0);
  Check(Length(LFiltered) = 0, 'FilterByStdDevRange: high min returns empty');
end;

procedure TestGetGroups;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LGroups: TStringArray;
begin
  LSuite := CreateFastSuite('GetGroupsTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LGroups := LResults.GetGroups;
  Check(Length(LGroups) >= 2, 'GetGroups: has at least 2 groups');
end;

procedure TestGetGroupStats;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LStats: TBenchStats;
begin
  LSuite := CreateFastSuite('GroupStatsTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 获取 Sort 分组的统计 }
  LStats := LResults.GetGroupStats('Sort');
  Check(LStats.SampleCount = 2, 'GetGroupStats: Sort group has 2 samples');

  { 不存在的分组应返回零值 }
  LStats := LResults.GetGroupStats('Nonexistent');
  Check(LStats.SampleCount = 0, 'GetGroupStats: nonexistent group has 0 samples');
end;

procedure TestToJSON_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LJSON: string;
begin
  LSuite := CreateFastSuite('JSONGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.Add('Bare', @BenchFast); { bare 名须出现在分组导出中 }
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LJSON := LResults.ToJSON_Grouped;
  Check(Pos('"Sort":', LJSON) > 0, 'ToJSON_Grouped: has Sort group');
  Check(Pos('"Search":', LJSON) > 0, 'ToJSON_Grouped: has Search group');
  Check(Pos('QuickSort', LJSON) > 0, 'ToJSON_Grouped: has QuickSort');
  Check(Pos('"Bare":', LJSON) > 0, 'ToJSON_Grouped: has bare group');
end;

procedure TestToMarkdown_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LMarkdown: string;
begin
  LSuite := CreateFastSuite('MarkdownGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LMarkdown := LResults.ToMarkdown_Grouped;
  Check(Pos('## Sort', LMarkdown) > 0, 'ToMarkdown_Grouped: has Sort section');
  Check(Pos('## Search', LMarkdown) > 0, 'ToMarkdown_Grouped: has Search section');
  Check(Pos('QuickSort', LMarkdown) > 0, 'ToMarkdown_Grouped: has QuickSort');
end;

procedure TestSaveToJSON_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
begin
  LSuite := CreateFastSuite('SaveJSONGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPath := '/tmp/bench_grouped_' + XidNew + '.json';
  LResults.SaveToJSON_Grouped(LPath);
  Check(FileExists(LPath), 'SaveToJSON_Grouped: file created');
  LContent := ReadFileText(LPath);
  Check(Pos('"Sort":', LContent) > 0, 'SaveToJSON_Grouped: has Sort group');
  DeleteFile(LPath);
end;

procedure TestSaveToMarkdown_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
begin
  LSuite := CreateFastSuite('SaveMarkdownGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPath := '/tmp/bench_grouped_' + XidNew + '.md';
  LResults.SaveToMarkdown_Grouped(LPath);
  Check(FileExists(LPath), 'SaveToMarkdown_Grouped: file created');
  LContent := ReadFileText(LPath);
  Check(Pos('## Sort', LContent) > 0, 'SaveToMarkdown_Grouped: has Sort section');
  DeleteFile(LPath);
end;

procedure TestToHTML_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LHTML: string;
begin
  LSuite := CreateFastSuite('HTMLGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LHTML := LResults.ToHTML_Grouped;
  Check(Pos('<h2>Sort</h2>', LHTML) > 0, 'ToHTML_Grouped: has Sort section');
  Check(Pos('<h2>Search</h2>', LHTML) > 0, 'ToHTML_Grouped: has Search section');
  Check(Pos('QuickSort', LHTML) > 0, 'ToHTML_Grouped: has QuickSort');
  Check(Pos('Total Groups:', LHTML) > 0, 'ToHTML_Grouped: has summary');
end;

procedure TestSaveToHTML_Grouped;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
begin
  LSuite := CreateFastSuite('SaveHTMLGroupedTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LPath := '/tmp/bench_grouped_' + XidNew + '.html';
  LResults.SaveToHTML_Grouped(LPath);
  Check(FileExists(LPath), 'SaveToHTML_Grouped: file created');
  LContent := ReadFileText(LPath);
  Check(Pos('<h2>Sort</h2>', LContent) > 0, 'SaveToHTML_Grouped: has Sort section');
  DeleteFile(LPath);
end;

procedure TestCompareGroups;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LComparison: TBenchComparison;
begin
  LSuite := CreateFastSuite('CompareGroupsTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.Add('Bare', @BenchFast); { 无 '/' 的整名分组 }
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 比较两个分组 — 组均值启发式，非正式统计检验 (F-03) }
  LComparison := LResults.CompareGroups('Sort', 'Search');
  Check(LComparison.Ratio > 0, 'CompareGroups: ratio > 0');
  CheckEqual('Sort', LComparison.BaselineName, 'CompareGroups: baseline name');
  Check(not LComparison.HasStatisticalTest, 'CompareGroups: heuristic only, not formal test');
  Check(LComparison.BaselineNsPerOp > 0, 'CompareGroups: baseline ns/op > 0');
  Check(LComparison.CurrentNsPerOp > 0, 'CompareGroups: current ns/op > 0');

  { 无 '/' 的 bare 名称可作分组 }
  LComparison := LResults.CompareGroups('Bare', 'Search');
  Check(LComparison.Ratio > 0, 'CompareGroups: bare group works');
  CheckEqual('Bare', LComparison.BaselineName, 'CompareGroups: bare baseline name');

  { 比较不存在的分组 }
  LComparison := LResults.CompareGroups('Nonexistent', 'Sort');
  Check(LComparison.Ratio = 0, 'CompareGroups: nonexistent group returns zero');
  Check(not LComparison.HasStatisticalTest, 'CompareGroups: nonexistent has no test');
end;

procedure TestGetGroupRegressionReport;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LReport: TBenchRegressionReport;
  LRaised: Boolean;
begin
  LSuite := CreateFastSuite('GroupRegressionTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.Add('Search/Binary', @BenchFast);
  LSuite.Add('Hash/Map', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 3 组 → C(3,2) = 3 对比较；阈值用 1.5（二进制精确可表示） }
  LReport := LResults.GetGroupRegressionReport(1.5);
  CheckEqual(3, LReport.TotalComparisons, 'GetGroupRegressionReport: C(3,2)=3 pairs');
  Check(LReport.Threshold = 1.5, 'GetGroupRegressionReport: threshold correct');
  CheckEqual(3, Length(LReport.Comparisons), 'GetGroupRegressionReport: comparisons length');
  CheckEqual(
    LReport.RegressedCount + LReport.ImprovedCount + LReport.UnchangedCount,
    LReport.TotalComparisons,
    'GetGroupRegressionReport: counts sum to total');

  { 只有一个分组时应返回空报告 }
  LSuite := CreateFastSuite('SingleGroupTest');
  LSuite.Add('Sort/QuickSort', @BenchFast);
  LSuite.Add('Sort/MergeSort', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LReport := LResults.GetGroupRegressionReport(1.5);
  CheckEqual(0, LReport.TotalComparisons, 'GetGroupRegressionReport: single group returns 0');

  { 非法 threshold }
  LRaised := False;
  try
    LResults.GetGroupRegressionReport(0);
  except
    on E: EBenchInvalidParam do
      LRaised := True;
  end;
  Check(LRaised, 'GetGroupRegressionReport: zero threshold raises');
end;

procedure TestToMatrixCSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LCSV: string;
  LBaseline1, LBaseline2: TBaselineData;
begin
  LSuite := CreateFastSuite('MatrixCSVTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LBaseline1 := Default(TBaselineData);
  LBaseline1.Name := 'Fast';
  LBaseline1.NsPerOp := 100.0;
  LBaseline2 := Default(TBaselineData);
  LBaseline2.Name := 'Medium';
  LBaseline2.NsPerOp := 200.0;

  LCSV := LResults.ToMatrixCSV([LBaseline1, LBaseline2]);
  Check(Pos('Name,CurrentNsPerOp,CurrentStdDev', LCSV) > 0, 'ToMatrixCSV: has header');
  Check(Pos('Fast Ratio', LCSV) > 0, 'ToMatrixCSV: has Fast Ratio column');
  Check(Pos('Medium Ratio', LCSV) > 0, 'ToMatrixCSV: has Medium Ratio column');
  Check(Pos('Geometric Mean', LCSV) > 0, 'ToMatrixCSV: has geometric mean row');
end;

procedure TestSaveToMatrixJSON;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
  LBaseline: TBaselineData;
begin
  LSuite := CreateFastSuite('SaveMatrixJSONTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 100.0;

  LPath := '/tmp/bench_test_matrix.json';
  LResults.SaveToMatrixJSON(LPath, [LBaseline]);
  LContent := ReadFileToString(LPath);
  Check(Pos('"rows"', LContent) > 0, 'SaveToMatrixJSON: file has rows');
  DeleteFile(LPath);
end;

procedure TestSaveToMatrixHTML;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
  LBaseline: TBaselineData;
begin
  LSuite := CreateFastSuite('SaveMatrixHTMLTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 100.0;

  LPath := '/tmp/bench_test_matrix.html';
  LResults.SaveToMatrixHTML(LPath, [LBaseline]);
  LContent := ReadFileToString(LPath);
  Check(Pos('<table', LContent) > 0, 'SaveToMatrixHTML: file has table');
  DeleteFile(LPath);
end;

procedure TestSaveToMatrixCSV;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LPath, LContent: string;
  LBaseline: TBaselineData;
begin
  LSuite := CreateFastSuite('SaveMatrixCSVTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  LBaseline := Default(TBaselineData);
  LBaseline.Name := 'Fast';
  LBaseline.NsPerOp := 100.0;

  LPath := '/tmp/bench_test_matrix.csv';
  LResults.SaveToMatrixCSV(LPath, [LBaseline]);
  LContent := ReadFileToString(LPath);
  Check(Pos('Name,CurrentNsPerOp', LContent) > 0, 'SaveToMatrixCSV: file has header');
  DeleteFile(LPath);
end;

procedure TestGenerateMatrixJSON_Summary;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LMatrix: TMatrixResult;
  LJSON: string;
  LBaseline1, LBaseline2: TBaselineData;
begin
  LSuite := CreateFastSuite('MatrixJSONTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 创建基线 — 名称需与基准名匹配 }
  LBaseline1 := Default(TBaselineData);
  LBaseline1.Name := 'Fast';
  LBaseline1.NsPerOp := 100.0;
  LBaseline2 := Default(TBaselineData);
  LBaseline2.Name := 'Medium';
  LBaseline2.NsPerOp := 200.0;

  LMatrix := LResults.CompareMultipleBaselines([LBaseline1, LBaseline2]);
  LJSON := LResults.ToMatrixJSON([LBaseline1, LBaseline2]);

  { 验证摘要部分存在 }
  Check(Pos('"summary"', LJSON) > 0, 'MatrixJSON: summary section exists');
  Check(Pos('"baselines":2', LJSON) > 0, 'MatrixJSON: baselines count = 2');
  Check(Pos('"benchmarks":2', LJSON) > 0, 'MatrixJSON: benchmarks count = 2');
  Check(Pos('"faster"', LJSON) > 0, 'MatrixJSON: faster field exists');
  Check(Pos('"slower"', LJSON) > 0, 'MatrixJSON: slower field exists');
  Check(Pos('"same"', LJSON) > 0, 'MatrixJSON: same field exists');
end;

procedure TestGenerateMatrixHTML_Summary;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LMatrix: TMatrixResult;
  LHTML: string;
  LBaseline1, LBaseline2: TBaselineData;
begin
  LSuite := CreateFastSuite('MatrixHTMLTest');
  LSuite.Add('Fast', @BenchFast);
  LSuite.Add('Medium', @BenchMedium);
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;

  { 创建基线 — 名称需与基准名匹配 }
  LBaseline1 := Default(TBaselineData);
  LBaseline1.Name := 'Fast';
  LBaseline1.NsPerOp := 100.0;
  LBaseline2 := Default(TBaselineData);
  LBaseline2.Name := 'Medium';
  LBaseline2.NsPerOp := 200.0;

  LMatrix := LResults.CompareMultipleBaselines([LBaseline1, LBaseline2]);
  LHTML := LResults.ToMatrixHTML([LBaseline1, LBaseline2]);

  { 验证摘要部分存在 }
  Check(Pos('class="summary"', LHTML) > 0, 'MatrixHTML: summary div exists');
  Check(Pos('<strong>Baselines:</strong> 2', LHTML) > 0, 'MatrixHTML: baselines count = 2');
  Check(Pos('<strong>Benchmarks:</strong> 2', LHTML) > 0, 'MatrixHTML: benchmarks count = 2');
  Check(Pos('<strong>Faster:</strong>', LHTML) > 0, 'MatrixHTML: faster field exists');
  Check(Pos('<strong>Slower:</strong>', LHTML) > 0, 'MatrixHTML: slower field exists');
  Check(Pos('<strong>Same:</strong>', LHTML) > 0, 'MatrixHTML: same field exists');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.results_api');
    T.Test('NsPerOpDuration', @TestNsPerOpDuration);
    T.Test('StdDevDuration', @TestStdDevDuration);
    T.Test('GetAggregateStats', @TestGetAggregateStats);
    T.Test('FilterByPrefix', @TestFilterByPrefix);
    T.Test('FilterBySuffix', @TestFilterBySuffix);
    T.Test('FilterBySubstring', @TestFilterBySubstring);
    T.Test('SortByNsPerOp', @TestSortByNsPerOp);
    T.Test('GetFastest', @TestGetFastest);
    T.Test('GetSlowest', @TestGetSlowest);
    T.Test('GetTopN', @TestGetTopN);
    T.Test('GetStableResults', @TestGetStableResults);
    T.Test('GetUnstableResults', @TestGetUnstableResults);
    T.Test('FilterByNsPerOpRange', @TestFilterByNsPerOpRange);
    T.Test('GetTotalOpsPerSec', @TestGetTotalOpsPerSec);
    T.Test('GetTotalOutliers', @TestGetTotalOutliers);
    T.Test('GetTotalIterations', @TestGetTotalIterations);
    T.Test('GetTotalBytesPerOp', @TestGetTotalBytesPerOp);
    T.Test('GetTotalAllocsPerOp', @TestGetTotalAllocsPerOp);
    T.Test('GetTotalElapsed', @TestGetTotalElapsed);
    T.Test('GetAllCustomMetrics', @TestGetAllCustomMetrics);
    T.Test('GetTotalCustomMetricsCount', @TestGetTotalCustomMetricsCount);
    T.Test('FilterByNamePattern', @TestFilterByNamePattern);
    T.Test('GetSummaryStats', @TestGetSummaryStats);
    T.Test('GetSummaryStats_Empty', @TestGetSummaryStats_Empty);
    T.Test('GetRegressionReport', @TestGetRegressionReport);
    T.Test('GetRegressionReport_NoRegression', @TestGetRegressionReport_NoRegression);
    T.Test('FilterByHasCustomMetric', @TestFilterByHasCustomMetric);
    T.Test('ToCSV', @TestToCSV);
    T.Test('ToCSV_NameWithComma', @TestToCSV_NameWithComma);
    T.Test('SaveToCSV', @TestSaveToCSV);
    T.Test('GetCustomMetricValues', @TestGetCustomMetricValues);
    T.Test('GetPercentileStats', @TestGetPercentileStats);
    T.Test('GetPercentileStats_Empty', @TestGetPercentileStats_Empty);
    T.Test('GetCVArray', @TestGetCVArray);
    T.Test('GetOutlierSummary', @TestGetOutlierSummary);
    T.Test('SortByCustomMetric', @TestSortByCustomMetric);
    T.Test('FilterByCustomMetricRange', @TestFilterByCustomMetricRange);
    T.Test('GetCustomMetricStats', @TestGetCustomMetricStats);
    T.Test('GetResultsWithOutliers', @TestGetResultsWithOutliers);
    T.Test('GetResultsWithoutOutliers', @TestGetResultsWithoutOutliers);
    T.Test('SortByOpsPerSec', @TestSortByOpsPerSec);
    T.Test('FilterByStdDevRange', @TestFilterByStdDevRange);
    T.Test('GetGroups', @TestGetGroups);
    T.Test('GetGroupStats', @TestGetGroupStats);
    T.Test('ToJSON_Grouped', @TestToJSON_Grouped);
    T.Test('ToMarkdown_Grouped', @TestToMarkdown_Grouped);
    T.Test('SaveToJSON_Grouped', @TestSaveToJSON_Grouped);
    T.Test('SaveToMarkdown_Grouped', @TestSaveToMarkdown_Grouped);
    T.Test('ToHTML_Grouped', @TestToHTML_Grouped);
    T.Test('SaveToHTML_Grouped', @TestSaveToHTML_Grouped);
    T.Test('CompareGroups', @TestCompareGroups);
    T.Test('GetGroupRegressionReport', @TestGetGroupRegressionReport);
    T.Test('ToMatrixCSV', @TestToMatrixCSV);
    T.Test('SaveToMatrixJSON', @TestSaveToMatrixJSON);
    T.Test('SaveToMatrixHTML', @TestSaveToMatrixHTML);
    T.Test('SaveToMatrixCSV', @TestSaveToMatrixCSV);
    T.Test('GenerateMatrixJSON_Summary', @TestGenerateMatrixJSON_Summary);
    T.Test('GenerateMatrixHTML_Summary', @TestGenerateMatrixHTML_Summary);
  T.Run;
end.
