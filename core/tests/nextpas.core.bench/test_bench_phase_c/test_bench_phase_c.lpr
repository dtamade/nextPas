{**
 * @desc Phase C 贝叶斯估计测试
 *
 * 测试正态-正态共轭模型、可信区间、先验融合
 *}
program test_bench_phase_c;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.stats;

{ ===== 正态-正态共轭模型测试 ===== }

procedure Test_BayesianEstimate_Basic;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
  LI: Integer;
begin
  { 数据: N(100, 10) 的样本 }
  SetLength(LData, 50);
  for LI := 0 to 49 do
    LData[LI] := 100.0 + (LI mod 20) - 10;

  LStats := TBenchStatsAnalyzer.Create;
  try
    LEstimate := LStats.BayesianEstimate(LData, 90.0, 15.0);

    { 后验均值应该在先验均值和样本均值之间 }
    Check(LEstimate.PosteriorMean > 90.0, 'Posterior mean should be > prior mean');
    Check(LEstimate.PosteriorMean < 110.0, 'Posterior mean should be < 110');

    { 后验标准差应该小于先验标准差（数据减少了不确定性） }
    Check(LEstimate.PosteriorStdDev < 15.0, 'Posterior std should be < prior std');

    { 样本大小应该正确 }
    Check(LEstimate.SampleSize = 50, 'Sample size should be 50');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_StrongPrior;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
  LI: Integer;
begin
  { 数据: 样本均值 ~100 }
  SetLength(LData, 10);
  for LI := 0 to 9 do
    LData[LI] := 100.0 + LI;

  LStats := TBenchStatsAnalyzer.Create;
  try
    { 强先验: 均值 90，标准差 1（非常确定） }
    LEstimate := LStats.BayesianEstimate(LData, 90.0, 1.0, 10.0);

    { 强先验应该把后验拉向先验 }
    Check(LEstimate.PosteriorMean < 100.0,
      'Strong prior should pull posterior toward prior mean');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_WeakPrior;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
  LI: Integer;
begin
  { 数据: 样本均值 ~100 }
  SetLength(LData, 50);
  for LI := 0 to 49 do
    LData[LI] := 100.0 + (LI mod 10);

  LStats := TBenchStatsAnalyzer.Create;
  try
    { 弱先验: 均值 90，标准差 100（非常不确定） }
    LEstimate := LStats.BayesianEstimate(LData, 90.0, 100.0);

    { 弱先验 + 大样本：后验应该接近样本均值 }
    Check(Abs(LEstimate.PosteriorMean - LEstimate.SampleMean) < 5.0,
      'Weak prior + large sample: posterior should be close to sample mean');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_EmptyData;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
begin
  SetLength(LData, 0);

  LStats := TBenchStatsAnalyzer.Create;
  try
    LEstimate := LStats.BayesianEstimate(LData, 100.0, 10.0);

    { 无数据：后验 = 先验 }
    Check(LEstimate.PosteriorMean = 100.0, 'Empty data: posterior mean = prior mean');
    Check(LEstimate.PosteriorStdDev = 10.0, 'Empty data: posterior std = prior std');
    Check(LEstimate.SampleSize = 0, 'Empty data: sample size = 0');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_SingleData;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
begin
  SetLength(LData, 1);
  LData[0] := 100.0;

  LStats := TBenchStatsAnalyzer.Create;
  try
    { 使用已知 sigma = 10 }
    LEstimate := LStats.BayesianEstimate(LData, 90.0, 10.0, 10.0);

    { 单个数据点：后验应该在先验和数据之间 }
    Check(LEstimate.PosteriorMean > 90.0, 'Single data: posterior > prior');
    Check(LEstimate.PosteriorMean < 100.0, 'Single data: posterior < data');
    Check(LEstimate.SampleSize = 1, 'Single data: sample size = 1');
  finally
    LStats.Free;
  end;
end;

{ ===== 可信区间测试 ===== }

procedure Test_BayesianCredibleInterval_95;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
  LI: Integer;
begin
  SetLength(LData, 50);
  for LI := 0 to 49 do
    LData[LI] := 100.0 + (LI mod 20) - 10;

  LStats := TBenchStatsAnalyzer.Create;
  try
    LCI := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.95, 10.0);

    Check(LCI.Lower < LCI.Upper, 'Lower should be < Upper');
    Check(Abs(LCI.Level - 0.95) < 0.001, 'Level should be 0.95');

    { 可信区间应该包含真实均值 }
    Check(LCI.Lower < 100.0, 'Lower should be < 100');
    Check(LCI.Upper > 100.0, 'Upper should be > 100');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianCredibleInterval_99;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LCI95, LCI99: TConfidenceInterval;
  LI: Integer;
begin
  SetLength(LData, 50);
  for LI := 0 to 49 do
    LData[LI] := 100.0 + (LI mod 20) - 10;

  LStats := TBenchStatsAnalyzer.Create;
  try
    LCI95 := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.95);
    LCI99 := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.99);

    { 99% 可信区间应该比 95% 更宽 }
    Check(LCI99.Upper - LCI99.Lower > LCI95.Upper - LCI95.Lower,
      '99% CI should be wider than 95% CI');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianCredibleInterval_EmptyData;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LCI: TConfidenceInterval;
begin
  SetLength(LData, 0);

  LStats := TBenchStatsAnalyzer.Create;
  try
    LCI := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.95);

    { 无数据：可信区间基于先验 }
    Check(LCI.Lower < 100.0, 'Empty data: lower < prior mean');
    Check(LCI.Upper > 100.0, 'Empty data: upper > prior mean');
  finally
    LStats.Free;
  end;
end;

{ ===== 先验融合测试 ===== }

procedure Test_BayesianEstimate_PriorFusion;
var
  LStats: TBenchStatsAnalyzer;
  LData1, LData2: TDoubleArray;
  LEstimate1, LEstimate2: TBayesianEstimate;
  LI: Integer;
begin
  { 第一批数据: 均值 ~104.5 }
  SetLength(LData1, 30);
  for LI := 0 to 29 do
    LData1[LI] := 100.0 + (LI mod 10);

  { 第二批数据: 均值 ~106.5 }
  SetLength(LData2, 30);
  for LI := 0 to 29 do
    LData2[LI] := 102.0 + (LI mod 10);

  LStats := TBenchStatsAnalyzer.Create;
  try
    { 第一次估计：使用无信息先验 }
    LEstimate1 := LStats.BayesianEstimate(LData1, 100.0, 100.0, 10.0);

    { 第二次估计：使用第一次的后验作为先验 }
    LEstimate2 := LStats.BayesianEstimate(LData2,
      LEstimate1.PosteriorMean, LEstimate1.PosteriorStdDev, 10.0);

    { 融合后的估计应该更精确（标准差更小） }
    Check(LEstimate2.PosteriorStdDev < LEstimate1.PosteriorStdDev,
      'Fused posterior should be more precise');

    { 融合后的均值应该在两批数据之间 }
    Check(LEstimate2.PosteriorMean > 100.0, 'Fused mean should be > 100');
    Check(LEstimate2.PosteriorMean < 110.0, 'Fused mean should be < 110');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_Convergence;
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
  LI: Integer;
  LPriorMean, LPriorStdDev: Double;
begin
  LStats := TBenchStatsAnalyzer.Create;
  try
    { 逐步添加数据，观察后验收敛 }
    LPriorMean := 90.0;
    LPriorStdDev := 100.0;

    for LI := 1 to 10 do
    begin
      SetLength(LData, 1);
      LData[0] := 100.0 + (LI mod 5);

      LEstimate := LStats.BayesianEstimate(LData, LPriorMean, LPriorStdDev);

      { 更新先验为后验 }
      LPriorMean := LEstimate.PosteriorMean;
      LPriorStdDev := LEstimate.PosteriorStdDev;
    end;

    { 经过多次更新，后验应该接近真实值 }
    Check(Abs(LPriorMean - 100.0) < 10.0,
      'After多次更新，后验应该接近真实值');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianCredibleInterval_80;
{ F-08: 验证非标准水平（80%）使用 NormalQuantile 而非硬编码 z 值 }
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LCI95, LCI80: TConfidenceInterval;
  LI: Integer;
begin
  SetLength(LData, 50);
  for LI := 0 to 49 do
    LData[LI] := 100.0 + (LI mod 10);

  LStats := TBenchStatsAnalyzer.Create;
  try
    LCI95 := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.95);
    LCI80 := LStats.BayesianCredibleInterval(LData, 100.0, 10.0, 0.80);

    { 80% 区间应比 95% 区间窄 }
    Check(LCI80.Upper - LCI80.Lower < LCI95.Upper - LCI95.Lower,
      '80% CI should be narrower than 95% CI');
    Check(Abs(LCI80.Level - 0.80) < 0.001, 'Level should be 0.80');
  finally
    LStats.Free;
  end;
end;

{ ===== F-18: sigma=0 路径测试 ===== }

procedure Test_BayesianEstimate_SigmaZero;
{ F-18: 验证 ASigma=0 时使用样本标准差 }
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimateWithSigma, LEstimateSigmaZero: TBayesianEstimate;
  LI: Integer;
begin
  { 数据: 样本 stddev ~5.77 }
  SetLength(LData, 30);
  for LI := 0 to 29 do
    LData[LI] := 100.0 + (LI mod 10);

  LStats := TBenchStatsAnalyzer.Create;
  try
    { sigma=0: 使用样本标准差 }
    LEstimateSigmaZero := LStats.BayesianEstimate(LData, 100.0, 10.0, 0);

    { sigma=显式值: 使用样本标准差的近似值 }
    LEstimateWithSigma := LStats.BayesianEstimate(LData, 100.0, 10.0, 5.77);

    { 两者后验均值应接近 }
    Check(Abs(LEstimateSigmaZero.PosteriorMean - LEstimateWithSigma.PosteriorMean) < 1.0,
      'sigma=0 should use sample stddev, giving similar result');

    { 后验标准差应小于先验 }
    Check(LEstimateSigmaZero.PosteriorStdDev < 10.0,
      'Posterior std should be < prior std');

    { 样本大小应正确 }
    Check(LEstimateSigmaZero.SampleSize = 30, 'Sample size should be 30');
  finally
    LStats.Free;
  end;
end;

procedure Test_BayesianEstimate_SigmaZeroConstant;
{ F-18: 验证常量数据时 sigma=0 的退化行为 }
var
  LStats: TBenchStatsAnalyzer;
  LData: TDoubleArray;
  LEstimate: TBayesianEstimate;
  LI: Integer;
begin
  { 常量数据: stddev=0, 应退化为 1e-10 }
  SetLength(LData, 20);
  for LI := 0 to 19 do
    LData[LI] := 100.0;

  LStats := TBenchStatsAnalyzer.Create;
  try
    LEstimate := LStats.BayesianEstimate(LData, 100.0, 10.0, 0);

    { 常量数据：后验均值应接近 100 }
    Check(Abs(LEstimate.PosteriorMean - 100.0) < 0.01,
      'Constant data: posterior mean should be ~100');

    { 后验应存在（不崩溃） }
    Check(LEstimate.PosteriorStdDev > 0, 'Posterior std should be positive');
    Check(LEstimate.SampleSize = 20, 'Sample size should be 20');
  finally
    LStats.Free;
  end;
end;

{ ===== 注册测试 ===== }

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('bench-phase-c');

  { 正态-正态共轭模型 }
  T.Test('BayesianEstimate_Basic', @Test_BayesianEstimate_Basic);
  T.Test('BayesianEstimate_StrongPrior', @Test_BayesianEstimate_StrongPrior);
  T.Test('BayesianEstimate_WeakPrior', @Test_BayesianEstimate_WeakPrior);
  T.Test('BayesianEstimate_EmptyData', @Test_BayesianEstimate_EmptyData);
  T.Test('BayesianEstimate_SingleData', @Test_BayesianEstimate_SingleData);

  { 可信区间 }
  T.Test('BayesianCredibleInterval_95', @Test_BayesianCredibleInterval_95);
  T.Test('BayesianCredibleInterval_99', @Test_BayesianCredibleInterval_99);
  T.Test('BayesianCredibleInterval_80', @Test_BayesianCredibleInterval_80);
  T.Test('BayesianCredibleInterval_EmptyData', @Test_BayesianCredibleInterval_EmptyData);

  { 先验融合 }
  T.Test('BayesianEstimate_PriorFusion', @Test_BayesianEstimate_PriorFusion);
  T.Test('BayesianEstimate_Convergence', @Test_BayesianEstimate_Convergence);

  { F-18: sigma=0 路径 }
  T.Test('BayesianEstimate_SigmaZero', @Test_BayesianEstimate_SigmaZero);
  T.Test('BayesianEstimate_SigmaZeroConstant', @Test_BayesianEstimate_SigmaZeroConstant);

  T.Run;
  T.Summary;
end.
