# nextpas.core.bench 最佳实践指南

本指南提供基准测试的最佳实践，帮助你编写可靠、可复现、有意义的基准测试。

## 核心原则

### 1. 测量什么，优化什么

基准测试的目标是指导优化决策。确保你测量的是真正重要的指标：

```pascal
{ 错误：测量微秒级操作，但实际瓶颈在毫秒级 }
procedure BenchMicroOp(const ACtx: IBenchContext);
begin
  // 太快了，测量误差占比太大
  Inc(GCounter);
end;

{ 正确：测量实际瓶颈 }
procedure BenchActualBottleneck(const ACtx: IBenchContext);
begin
  // 这才是真正的性能问题
  ProcessLargeDataset(GData);
end;
```

### 2. 避免测量偏差

#### Setup/Teardown 分离

```pascal
{ 错误：Setup 时间被计入 }
procedure BenchBad(const ACtx: IBenchContext);
var
  LData: array of Integer;
begin
  SetLength(LData, 100000);  { 这部分被计时 }
  for var I := 0 to High(LData) do
    LData[I] := Random;
  
  SortArray(LData);  { 只想测这个 }
end;

{ 正确：使用 AddWithSetup }
procedure SetupData;
begin
  SetLength(GData, 100000);
  for var I := 0 to High(GData) do
    GData[I] := Random;
end;

procedure BenchGood(const ACtx: IBenchContext);
begin
  SortArray(GData);  { 只测排序 }
end;

{ 使用 }
LResults := TBenchSuite.Create('Sort')
  .AddWithSetup('QuickSort', @BenchGood, @SetupData, nil)
  .Run;
```

#### ResetTimer 使用

```pascal
procedure BenchWithMixedWork(const ACtx: IBenchContext);
begin
  { 不想测量的部分 }
  LoadDataFromDisk;
  
  ACtx.ResetTimer;  { 重置计时器 }
  
  { 想测量的部分 }
  ProcessData;
end;
```

#### StopTimer/StartTimer 使用

```pascal
procedure BenchWithPauses(const ACtx: IBenchContext);
begin
  { 想测量的部分 A }
  ProcessPartA;
  
  ACtx.StopTimer;  { 暂停计时 }
  
  { 不想测量的部分 }
  WaitForIO;
  
  ACtx.StartTimer;  { 恢复计时 }
  
  { 想测量的部分 B }
  ProcessPartB;
end;
```

### 3. 统计显著性

#### 最小采样数

```pascal
{ 错误：样本太少 }
LResults := TBenchSuite.Create('Bad')
  .SetMinSamples(3)  { 只有 3 个样本，统计不可靠 }
  .Add('Benchmark', @BenchFunc)
  .Run;

{ 正确：足够样本 }
LResults := TBenchSuite.Create('Good')
  .SetMinSamples(30)  { 至少 30 个样本 }
  .Add('Benchmark', @BenchFunc)
  .Run;
```

#### 最小持续时间

```pascal
{ 错误：时间太短 }
LResults := TBenchSuite.Create('Bad')
  .SetMinDuration(TDuration.FromMilliseconds(100))  { 只有 100ms }
  .Add('Benchmark', @BenchFunc)
  .Run;

{ 正确：足够时间 }
LResults := TBenchSuite.Create('Good')
  .SetMinDuration(TDuration.FromSeconds(2))  { 至少 2 秒 }
  .Add('Benchmark', @BenchFunc)
  .Run;
```

#### 置信区间检查

```pascal
var
  LEntry: TBenchEntryResult;
begin
  LEntry := LResults.GetByName('Benchmark');
  
  { 错误：只看均值 }
  WriteLn(Format('Mean: %.2f ns', [LEntry.MeanNs]));
  
  { 正确：检查置信区间 }
  WriteLn(Format('Mean: %.2f ± %.2f ns (95%% CI)', [
    LEntry.MeanNs,
    LEntry.ConfidenceInterval
  ]));
  
  { 如果置信区间太大，说明结果不稳定 }
  if LEntry.ConfidenceInterval > LEntry.MeanNs * 0.1 then
    WriteLn('WARNING: High variance, increase sample size');
end;
```

### 4. 预热策略

#### 为什么需要预热

```pascal
{ 冷启动：首次运行可能慢 10-100x }
procedure BenchColdStart;
var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('Cold')
    .SetWarmupIters(0)  { 不预热 }
    .Add('Benchmark', @BenchFunc)
    .Run;
  
  WriteLn(Format('Cold: %s', [LResults.GetByName('Benchmark').MeanStr]));
end;

{ 热启动：预热后稳定 }
procedure BenchWarmStart;
var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('Warm')
    .SetWarmupIters(100)  { 预热 100 次 }
    .Add('Benchmark', @BenchFunc)
    .Run;
  
  WriteLn(Format('Warm: %s', [LResults.GetByName('Benchmark').MeanStr]));
end;
```

#### 预热次数选择

```pascal
{ 根据操作复杂度选择预热次数 }
LResults := TBenchSuite.Create('Warmup')
  .SetWarmupIters(10)    { 简单操作：10 次 }
  .Add('SimpleOp', @BenchSimple)
  .SetWarmupIters(100)   { 中等操作：100 次 }
  .Add('MediumOp', @BenchMedium)
  .SetWarmupIters(1000)  { 复杂操作：1000 次 }
  .Add('ComplexOp', @BenchComplex)
  .Run;
```

### 5. 环境控制

#### CPU 频率锁定

```bash
# Linux: 设置性能模式
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 禁用 Turbo Boost（可选，减少变异性）
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# 固定 CPU 频率（可选）
sudo cpupower frequency-set -f 3.0GHz
```

#### 避免后台干扰

```bash
# 关闭不必要的服务
sudo systemctl stop cron
sudo systemctl stop unattended-upgrades

# 绑定到特定 CPU 核心
taskset -c 0 ./benchmark
```

#### 虚拟机注意事项

```pascal
{ 在虚拟机中运行基准测试时，添加警告 }
if IsRunningInVM then
  WriteLn('WARNING: Running in VM, results may vary');
```

### 6. 结果解读

#### 统计指标含义

| 指标 | 含义 | 何时关注 |
|------|------|----------|
| Mean | 平均值 | 总体性能水平 |
| Median | 中位数 | 抗异常值，更稳健 |
| StdDev | 标准差 | 稳定性，越小越好 |
| P95 | 第 95 百分位 | 长尾延迟 |
| P99 | 第 99 百分位 | 极端情况 |
| Min/Max | 最小/最大值 | 边界情况 |

#### 回归检测

```pascal
{ 使用 Mann-Whitney U 检测统计显著差异 }
var
  LResult: TMannWhitneyResult;
begin
  LResult := MannWhitneyU(LBaseline.RawSamples, LCurrent.RawSamples);
  
  if LResult.IsSignificant then
  begin
    if LResult.EffectSize > 0.2 then  { 中等效应 }
      WriteLn('Significant regression detected')
    else
      WriteLn('Statistically significant but small effect');
  end
  else
    WriteLn('No significant difference');
end;
```

#### 几何均值聚合

```pascal
{ 多个基准的总体性能变化 }
var
  LRatios: array of Double;
begin
  for var I := 0 to LResults.Count - 1 do
    LRatios[I] := LResults[I].RatioToBaseline;
  
  WriteLn(Format('Overall: %.2fx', [GeometricMean(LRatios)]));
end;
```

### 7. 并行基准

#### 线程安全验证

```pascal
var
  GCounter: TAtomicInt64;

procedure BenchAtomicIncrement(const ACtx: IBenchContext);
begin
  GCounter.Increment;
end;

begin
  GCounter.Store(0);
  
  LResults := TBenchSuite.Create('ThreadSafety')
    .AddParallel('AtomicIncrement', @BenchAtomicIncrement, 8)
    .Run;
  
  { 验证最终值等于迭代次数 }
  Assert(GCounter.Load = LResults.GetByName('AtomicIncrement').Iterations);
end;
```

#### 可伸缩性测试

```pascal
var
  LThreadCounts: array of Integer = [1, 2, 4, 8];
begin
  for var LThreads in LThreadCounts do
  begin
    LResults := TBenchSuite.Create(Format('Scalability/T=%d', [LThreads]))
      .AddParallel('Benchmark', @BenchFunc, LThreads)
      .Run;
    
    WriteLn(Format('Threads=%d: %s (%.2fx vs single)', [
      LThreads,
      LResults.GetByName('Benchmark').MeanStr,
      LResults.GetByName('Benchmark').RatioToBaseline
    ]));
  end;
end;
```

### 8. CI 集成

#### 基线管理

```pascal
{ 只在 main 分支更新基线 }
if IsMainBranch then
begin
  LResults := TBenchSuite.Create('Baseline')
    .Add('Benchmark', @BenchFunc)
    .Run;
  
  LResults.SaveToJSON('bench-baseline.json');
end;

{ 在 PR 中检测回归 }
if IsPullRequest then
begin
  LResults := TBenchSuite.Create('PR')
    .LoadBaseline('bench-baseline.json')
    .Add('Benchmark', @BenchFunc)
    .Run;
  
  if LResults.HasRegression(5.0) then  { 5% 阈值 }
    ExitCode := 1;
end;
```

#### 退出码

```pascal
{ 0: 无回归，1: 检测到回归 }
if LResults.HasRegression(5.0) then
begin
  WriteLn('CI FAILED: Performance regression detected');
  ExitCode := 1;
end
else
begin
  WriteLn('CI PASSED: No regression');
  ExitCode := 0;
end;
```

### 9. 报告生成

#### 多格式输出

```pascal
{ 控制台输出（人类可读） }
WriteLn(LResults.PrintToConsole);

{ JSON 输出（CI 可消费） }
LResults.SaveToJSON('bench-results.json');

{ HTML 输出（可视化） }
LResults.SaveToHTML('bench-results.html');

{ TSV 输出（Excel 可导入） }
LResults.SaveToTSV('bench-results.tsv');

{ Benchstat 格式（Go 生态兼容） }
WriteLn(LResults.ToBenchstat);
```

#### 时间线追踪

```pascal
{ 追踪性能变化趋势 }
LResults.AppendToTimeline('bench-timeline.jsonl');

{ 分析趋势 }
var
  LTimeline: TBenchTimeline;
begin
  LTimeline := TBenchTimeline.LoadFromJSONL('bench-timeline.jsonl');
  
  WriteLn(Format('Trend: %.2f%% per commit', [LTimeline.TrendPercent]));
end;
```

### 10. 常见陷阱

#### 陷阱 1：编译器优化

```pascal
{ 错误：编译器可能优化掉计算 }
procedure BenchDeadCode(const ACtx: IBenchContext);
begin
  ComputeResult;  { 结果未使用，可能被优化掉 }
end;

{ 正确：确保结果被使用 }
procedure BenchGood(const ACtx: IBenchContext);
var
  LResult: Integer;
begin
  LResult := ComputeResult;
  if LResult < 0 then  { 使用结果，防止优化 }
    WriteLn('Impossible');
end;
```

#### 陷阱 2：缓存效应

```pascal
{ 错误：数据集太小，完全在缓存中 }
procedure BenchSmallData(const ACtx: IBenchContext);
begin
  ProcessArray(SmallArray);  { 1KB，完全在 L1 缓存 }
end;

{ 正确：使用真实数据大小 }
procedure BenchRealistic(const ACtx: IBenchContext);
begin
  ProcessArray(LargeArray);  { 1MB，模拟真实场景 }
end;
```

#### 陷阱 3：内存分配

```pascal
{ 错误：每次迭代都分配内存 }
procedure BenchAllocEveryIter(const ACtx: IBenchContext);
var
  LData: array of Integer;
begin
  SetLength(LData, 10000);  { 每次都分配 }
  ProcessData(LData);
end;

{ 正确：预分配 }
var
  GData: array of Integer;

procedure SetupData;
begin
  SetLength(GData, 10000);  { 只分配一次 }
end;

procedure BenchGood(const ACtx: IBenchContext);
begin
  ProcessData(GData);  { 复用内存 }
end;
```

#### 陷阱 4：分支预测

```pascal
{ 错误：随机分支，预测失败率高 }
procedure BenchRandomBranch(const ACtx: IBenchContext);
begin
  for var I := 0 to 9999 do
    if Random < 0.5 then  { 50% true，难以预测 }
      Inc(LSum);
end;

{ 正确：可预测分支 }
procedure BenchPredictableBranch(const ACtx: IBenchContext);
begin
  for var I := 0 to 9999 do
    if I mod 100 = 0 then  { 1% true，容易预测 }
      Inc(LSum);
end;
```

---

## 检查清单

### 基准测试编写

- [ ] 使用 `AddWithSetup` 或 `ResetTimer` 分离 Setup
- [ ] 设置 `SetMinSamples(30)` 或更多
- [ ] 设置 `SetMinDuration(TDuration.FromSeconds(2))` 或更长
- [ ] 设置 `SetWarmupIters(10)` 或更多
- [ ] 确保结果被使用，防止编译器优化
- [ ] 使用真实数据大小
- [ ] 预分配内存

### 结果分析

- [ ] 检查置信区间，不只是均值
- [ ] 使用 Mann-Whitney U 检测统计显著差异
- [ ] 检查 P95/P99，识别长尾延迟
- [ ] 使用几何均值聚合多个基准

### CI 集成

- [ ] 保存基线到版本控制
- [ ] 只在 main 分支更新基线
- [ ] 在 PR 中检测回归
- [ ] 使用退出码表示结果
- [ ] 生成人类可读和机器可读的报告

### 环境控制

- [ ] 设置 CPU 性能模式
- [ ] 关闭不必要的后台服务
- [ ] 绑定到特定 CPU 核心（可选）
- [ ] 在虚拟机中添加警告

---

## 参考资源

- [nextpas.core.bench API 参考](README.md)
- [交互式教程](tutorial.md)
- [Go testing/bench 文档](https://pkg.go.dev/testing#hdr-Benchmarks)
- [Rust criterion 文档](https://bheisler.github.io/criterion.rs/book/)
- [Google Benchmark 最佳实践](https://github.com/google/benchmark#best-practices)
