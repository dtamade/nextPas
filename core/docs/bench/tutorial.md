# nextpas.core.bench 交互式教程

欢迎使用 nextpas.core.bench 基准测试框架！本教程将带你从入门到精通。

## 目录

1. [5 分钟入门](#1-5-分钟入门)
2. [统计解读](#2-统计解读)
3. [基线对比](#3-基线对比)
4. [并行基准](#4-并行基准)
5. [CI 集成](#5-ci-集成)
6. [性能调优](#6-性能调优)
7. [高级统计](#7-高级统计)
8. [最佳实践](#8-最佳实践)

---

## 1. 5 分钟入门

### 安装

bench 是 `nextpas.core` 的一部分，无需额外安装。
**模块作者请先看 [consumer-guide.md](consumer-guide.md)**；可运行示例：`core/examples/bench/quick_start.pas`。

### 第一个基准

```pascal
program my_first_bench;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base;

procedure BenchStringConcat(const ACtx: IBenchContext);
var
  S: string;
  I: Integer;
begin
  S := '';
  for I := 1 to 1000 do
    S := S + 'x';
end;

var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('MyFirstBench')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetMinSamples(10)
    .Add('StringConcat/1000', @BenchStringConcat)
    .Run;

  WriteLn(LResults.PrintToConsole);
end.
```

> 宿主 FPC 编译时不需要 `SysUtils` 仅为 WriteLn；优先依赖 `nextpas.core.*`。

### 输出解读

```
┌─────────────────────┬───────────┬───────────┬───────────┬───────────┐
│ Name                │    Mean   │   StdDev  │    P95    │    P99    │
├─────────────────────┼───────────┼───────────┼───────────┼───────────┤
│ StringConcat/1000   │  123.45us │   12.34us │  145.67us │  156.78us │
└─────────────────────┴───────────┴───────────┴───────────┴───────────┘
```

- **Mean**: 平均执行时间
- **StdDev**: 标准差（越小越稳定）
- **P95/P99**: 第 95/99 百分位数（长尾延迟）

### 练习 1.1

创建一个基准，测量以下函数的性能：

```pascal
procedure BenchArrayCopy(const ACtx: IBenchContext);
var
  Src, Dst: array[0..999] of Integer;
  I: Integer;
begin
  for I := 0 to 999 do
    Src[I] := I;
  Dst := Src;
end;
```

<details>
<summary>答案</summary>

```pascal
LResults := TBenchSuite.Create('ArrayCopy')
  .Add('ArrayCopy/1000', @BenchArrayCopy)
  .Run;
```

</details>

---

## 2. 统计解读

### 核心指标

| 指标 | 含义 | 何时关注 |
|------|------|----------|
| Mean | 平均值 | 总体性能水平 |
| Median | 中位数 | 抗异常值，更稳健 |
| StdDev | 标准差 | 稳定性，越小越好 |
| P95 | 第 95 百分位 | 长尾延迟 |
| P99 | 第 99 百分位 | 极端情况 |
| Min/Max | 最小/最大值 | 边界情况 |

### 置信区间

```pascal
LResults := TBenchSuite.Create('Stats')
  .SetConfidenceLevel(0.95)  { 95% 置信区间 }
  .Add('Benchmark', @BenchFunc)
  .Run;

WriteLn(Format('Mean: %.2f ± %.2f ns/op', [
  LEntry.MeanNs,
  LEntry.ConfidenceInterval
]));
```

### 正态性检验

```pascal
uses nextpas.core.bench.stats.advanced;

var
  LResult: TNormalityResult;
begin
  LResult := TestNormality(LEntry.RawSamples);

  if LResult.IsNormal then
    WriteLn('数据服从正态分布，可用 t 检验')
  else
    WriteLn('数据不服从正态分布，用 Mann-Whitney U');
end;
```

### 练习 2.1

解释以下输出：

```
Benchmark: 100.00 ± 5.00 ns/op (95% CI)
StdDev: 12.34 ns
P95: 120.00 ns
P99: 150.00 ns
```

<details>
<summary>答案</summary>

- 平均值 100ns，95% 置信区间 [95, 105]ns
- 标准差 12.34ns，表示数据有一定波动
- P95 为 120ns，95% 的执行在 120ns 内完成
- P99 为 150ns，存在长尾延迟（可能由 GC、缓存未命中引起）

</details>

---

## 3. 基线对比

### 创建基线

```pascal
{ 第一次运行：保存基线 }
LResults := TBenchSuite.Create('Baseline')
  .Add('HashMap.Put', @BenchPut)
  .Run;

LResults.SaveToJSON('baseline-v1.0.json');
```

### 加载基线并对比

```pascal
{ 后续运行：与基线对比 }
var
  LBaseline: IBenchResults;
begin
  LBaseline := TBenchResults.LoadFromJSON('baseline-v1.0.json');

  LResults := TBenchSuite.Create('Current')
    .LoadBaseline('baseline-v1.0.json')
    .Add('HashMap.Put', @BenchPut)
    .Run;

  WriteLn(LResults.PrintToConsole);
  { 输出会显示 Ratio 列：与基线的比值 }
end;
```

### 回归检测

```pascal
if LResults.HasRegression(5.0) then  { 5% 阈值 }
  WriteLn('WARNING: Performance regression detected!')
else
  WriteLn('No regression.');
```

### 练习 3.1

设计一个工作流，自动检测 PR 是否引入性能回归。

<details>
<summary>答案</summary>

```bash
# CI 脚本
1. 从 main 分支加载基线: baseline-main.json
2. 运行当前 PR 的基准测试
3. 比较结果，阈值 5%
4. 如果回归，CI 失败并输出详细报告
```

</details>

---

## 4. 并行基准

### 基本并行

```pascal
LResults := TBenchSuite.Create('Parallel')
  .AddParallel('AtomicOp', @BenchAtomicOp, 4)  { 4 线程 }
  .Run;
```

### 线程安全验证

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

  WriteLn(Format('Expected: %d, Actual: %d', [
    LResults.GetByName('AtomicIncrement').Iterations,
    GCounter.Load
  ]));
end;
```

### 可伸缩性测试

```pascal
var
  LThreadCounts: array of Integer = [1, 2, 4, 8];
begin
  for var LThreads in LThreadCounts do
  begin
    LResults := TBenchSuite.Create(Format('Scalability/T=%d', [LThreads]))
      .AddParallel('Benchmark', @BenchFunc, LThreads)
      .Run;

    WriteLn(Format('Threads=%d: %s', [
      LThreads,
      LResults.GetByName('Benchmark').MeanStr
    ]));
  end;
end;
```

### 练习 4.1

为什么并行基准会自动禁用内存追踪？

<details>
<summary>答案</summary>

内存追踪通过 MemoryManager hook 实现，这是全局唯一的。多线程同时访问会导致数据竞争，因此框架自动禁用并输出警告。

</details>

---

## 5. CI 集成

### GitHub Actions 示例

```yaml
name: Performance Benchmark

on: [push, pull_request]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Free Pascal
        run: sudo apt-get install fpc

      - name: Run Benchmarks
        run: |
          fpc -MObjFPC core/examples/bench/ci_integration.pas
          ./ci_integration --generate-baseline
          ./ci_integration

      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: bench-ci-report.json
```

### 退出码

- `0`: 无回归
- `1`: 检测到回归

### 报告格式

```json
{
  "name": "CICurrent",
  "timestamp": "2026-07-07T04:40:00Z",
  "entries": [
    {
      "name": "HashMap.Put",
      "mean_ns": 1234.56,
      "stddev_ns": 123.45,
      "p95_ns": 1456.78,
      "p99_ns": 1567.89
    }
  ]
}
```

### 练习 5.1

如何在 CI 中自动更新基线？

<details>
<summary>答案</summary>

```bash
# 只在 main 分支更新基线
if [ "$BRANCH" = "main" ]; then
  ./ci_integration --generate-baseline
  git add bench-baseline.json
  git commit -m "chore: update benchmark baseline"
fi
```

</details>

---

## 6. 性能调优

### 避免测量偏差

```pascal
{ 错误：Setup 时间被计入 }
procedure BenchBad(const ACtx: IBenchContext);
begin
  SetupData;  { 应该在计时器外 }
  DoWork;
end;

{ 正确：使用 ResetTimer }
procedure BenchGood(const ACtx: IBenchContext);
begin
  SetupData;
  ACtx.ResetTimer;  { 重置计时器 }
  DoWork;
end;

{ 最佳：使用 AddWithSetup }
LResults := TBenchSuite.Create('Tuned')
  .AddWithSetup('Benchmark', @BenchFunc, @Setup, @Teardown)
  .Run;
```

### 缓存预热

```pascal
LResults := TBenchSuite.Create('Cache')
  .SetWarmupIters(100)  { 预热 100 次 }
  .Add('Benchmark', @BenchFunc)
  .Run;
```

### 分支预测优化

```pascal
{ 难以预测的分支：50% true }
for I := 0 to 9999 do
  if Random < 0.5 then  { 分支预测失败率高 }
    Inc(LSum);

{ 容易预测的分支：1% true }
for I := 0 to 9999 do
  if Random < 0.01 then  { 分支预测成功率高 }
    Inc(LSum);
```

### 练习 6.1

解释为什么顺序访问比随机访问快。

<details>
<summary>答案</summary>

1. **缓存局部性**: 顺序访问利用 CPU 缓存行（通常 64 字节），一次加载多个元素
2. **预取优化**: CPU 硬件预取器识别顺序模式，提前加载数据
3. **TLB 命中**: 顺序访问减少 TLB（Translation Lookaside Buffer）未命中

</details>

---

## 7. 高级统计

### 异常值检测

```pascal
uses nextpas.core.bench.stats.advanced;

var
  LOutliers: TOutlierResult;
begin
  LOutliers := DetectOutliers(LEntry.RawSamples);

  WriteLn(Format('Outliers: %d/%d', [LOutliers.Count, Length(LEntry.RawSamples)]));
  WriteLn(Format('Method: %s', [LOutliers.Method]));
end;
```

### Bootstrap 置信区间

```pascal
var
  LCI: TBootstrapResult;
begin
  LCI := BootstrapCI(LEntry.RawSamples, 0.95, 10000);

  WriteLn(Format('95%% CI: [%.2f, %.2f]', [LCI.Lower, LCI.Upper]));
end;
```

### Mann-Whitney U 检验

```pascal
var
  LResult: TMannWhitneyResult;
begin
  LResult := MannWhitneyU(LBaseline.RawSamples, LCurrent.RawSamples);

  if LResult.IsSignificant then
    WriteLn(Format('Significant difference (p=%.6f)', [LResult.PValue]))
  else
    WriteLn('No significant difference');
end;
```

### 线性回归

```pascal
var
  LResult: TLinearRegressionResult;
begin
  LResult := LinearRegression(LX, LY);

  WriteLn(Format('time = %.4f * N + %.2f (R²=%.4f)', [
    LResult.Slope,
    LResult.Intercept,
    LResult.RSquared
  ]));
end;
```

### 练习 7.1

何时使用 Mann-Whitney U 而非 t 检验？

<details>
<summary>答案</summary>

1. **数据非正态**: Mann-Whitney U 不要求正态分布
2. **小样本**: 样本量 < 30 时，t 检验的正态性假设可能不成立
3. **异常值**: Mann-Whitney U 基于秩，对异常值更稳健
4. **序数数据**: 数据只有顺序关系时

</details>

---

## 8. 最佳实践

### DO ✅

1. **设置最小持续时间**: `SetMinDuration(TDuration.FromSeconds(1))`
2. **设置最小采样数**: `SetMinSamples(30)`
3. **使用预热**: `SetWarmupIters(10)`
4. **分离 Setup**: 使用 `AddWithSetup` 或 `ResetTimer`
5. **检查置信区间**: 不要只看 Mean
6. **使用基线对比**: 每次发布前保存基线
7. **并行测试线程安全**: 使用 `AddParallel` 验证

### DON'T ❌

1. **不要测量 Setup 时间**: 会引入偏差
2. **不要忽略异常值**: 检查 P95/P99
3. **不要只运行一次**: 至少 10 个样本
4. **不要忽略预热**: 冷启动会慢 10-100x
5. **不要在虚拟机中基准**: 结果不稳定
6. **不要并行运行独立基准**: 会相互干扰
7. **不要忽略环境变量**: CPU 频率、温度会影响结果

### 环境控制

```bash
# Linux: 设置性能模式
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 禁用 Turbo Boost（可选）
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# 固定 CPU 频率（可选）
sudo cpupower frequency-set -f 3.0GHz
```

### 练习 8.1

设计一个基准测试套件，验证 HashMap 的 Put/Get/Remove 性能。

<details>
<summary>答案</summary>

```pascal
LResults := TBenchSuite.Create('HashMap')
  .SetMinDuration(TDuration.FromSeconds(2))
  .SetMinSamples(30)
  .SetWarmupIters(100)
  .Add('Put/N=100000', @BenchPut)
  .Add('Get/Hit/N=100000', @BenchGetHit)
  .Add('Get/Miss/N=100000', @BenchGetMiss)
  .Add('Remove/N=100000', @BenchRemove)
  .AddWithSetup('Put/PreFilled', @BenchPutPreFilled,
    @SetupPreFilledMap, nil)
  .Run;
```

</details>

---

## 下一步

- 查看 `core/examples/bench/` 目录中的完整示例
- 阅读 [API 参考文档](../../docs/bench/README.md)
- 加入社区讨论：[GitHub Discussions](https://github.com/nextpas/nextpas/discussions)

---

## 附录：常见问题

### Q: 为什么我的基准结果不稳定？

A: 可能的原因：
1. 没有设置性能模式
2. 虚拟机环境
3. 后台进程干扰
4. 样本数太少
5. 没有预热

### Q: 如何比较两个不同算法？

A: 使用 `Add` 注册两个算法，框架会自动计算统计差异：

```pascal
LResults := TBenchSuite.Create('Comparison')
  .Add('AlgorithmA', @BenchA)
  .Add('AlgorithmB', @BenchB)
  .Run;

WriteLn(LResults.PrintToConsole);
{ 输出会显示两个算法的详细对比 }
```

### Q: 如何测试内存分配性能？

A: 启用内存追踪：

```pascal
LResults := TBenchSuite.Create('Memory')
  .EnableMemoryTracking
  .Add('Alloc', @BenchAlloc)
  .Run;

WriteLn(Format('B/op: %d', [LEntry.BytesPerOp]));
WriteLn(Format('allocs/op: %d', [LEntry.AllocsPerOp]));
```
