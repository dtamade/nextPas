# bench 模块全面审查 — Findings

> 审查日期: 2026-06-21（第二轮追加）
> 审查范围: 9 个源单元 + 12 个测试程序（全部逐一精读）
> 工作树: `.worktrees/bench-framework`

---

## 模块概览

| 单元 | 行数 | 职责 |
|------|------|------|
| `nextpas.core.bench.base` | 231 | 基本类型、排序 |
| `nextpas.core.bench.intf` | 244 | 接口定义、异常 |
| `nextpas.core.bench.stats` | 467 | 基础统计、t-distribution |
| `nextpas.core.bench.stats.advanced` | 662 | 高级统计、异常值检测 |
| `nextpas.core.bench` | 619 | 门面、Suite/Results |
| `nextpas.core.bench.baseline` | 424 | 基线管理 |
| `nextpas.core.bench.memtrack` | 332 | 内存追踪 |
| `nextpas.core.bench.parallel` | 266 | 并行基准 |
| `nextpas.core.bench.runner` | 793 | 校准、执行、采样 |
| `nextpas.core.bench.report` | 916 | 控制台/JSON/HTML/TSV 报告 |
| `nextpas.core.bench.xlang` | 395 | Go/Rust/FPC 输出解析 |
| **总计** | **~5,349** | |

测试: 12 个测试程序，覆盖 stats/stats.advanced/runner/integration/report/xlang/baseline/memtrack/parallel + heaptrc 泄漏检测 + 参数校验

---

## 严重程度分级

- 🔴 **P0 — 正确性/安全**: 会导致错误结果、崩溃或数据损坏
- 🟡 **P1 — 设计/API**: 不符合规范、API 不一致、死代码
- 🟢 **P2 — 性能/风格**: 微优化、代码风格改进

---

## 🔴 P0 — 正确性与安全

### C01. IntroSort 深度限制是 O(n) 而非 O(log n)

**文件**: `nextpas.core.bench.base.pas:~160`

IntroSort 的核心思想是在 QuickSort 退化时切换到堆排序。深度限制应该是 `2 * floor(log2(n))`，但当前实现使用 `2 * LLen`（线性）：

```pascal
LDepthLimit := 2 * LLen;  // ← O(n)，应为 O(log n)
```

**影响**: 大数组上退化的 QuickSort 不会被堆排序挽救，最坏情况 O(n²) 时间。虽然当前只用于统计排序（数据量通常不大），但算法实现与声称的 IntroSort 不符。

**建议**: 改为 `2 * FloorLog2(LLen)` 或引入 `DepthLimit := 2 * IntLog2(LLen)`。

---

### C02. ConfidenceInterval 使用 Z 值而非 t 分布

**文件**: `nextpas.core.bench.stats.advanced.pas:~320-340`

```pascal
// 95% → 1.96, 99% → 2.576 — 这是 Z 值（正态分布）
```

对于 n < 30 的小样本，必须使用 t 分布。`stats.pas` 中已有 `TINV_TABLE` 查找表，但 `stats.advanced.pas` 未使用它。

**影响**: 小样本（bench 常见场景：10-20 次采样）的置信区间会偏窄，高估精度。

**建议**: 使用 `stats.pas` 的 `TINV_TABLE` 或从 `TBenchStatsAnalyzer` 委托。

---

### C03. BootstrapCI 使用固定种子 12345

**文件**: `nextpas.core.bench.stats.advanced.pas:~370`

```pascal
procedure BootstrapCI(...; ASeed: UInt32 = 12345);
```

Bootstrap 重采样的意义在于随机性。固定种子意味着每次调用结果完全相同——等价于对同一组子样本反复计算，不是真正的 bootstrap。

**影响**: 无法反映采样变异，置信区间是伪随机的确定性值。

**建议**: 默认使用 `GetTickCount64` 或 `rdtsc` 作为种子；固定种子仅作测试用选项。

---

### C04. GlobalMemoryTracker 懒初始化非线程安全

**文件**: `nextpas.core.bench.memtrack.pas:~30-50`

```pascal
if not GGlobalTrackerInitialized then  // ← 非原子检查
begin
  GGlobalMemoryTracker.Create(True);
  GGlobalTrackerInitialized := True;
end;
```

`GGlobalTrackerInitialized` 的检查和赋值之间存在 TOCTOU 竞态。如果两个线程同时首次调用，可能导致 double-init 或读到半初始化状态。

**影响**: 多线程首次使用时可能崩溃或数据损坏。memtrack 测试中的 `Test_ParallelThreadSafety` 测试了记录操作的线程安全，但未覆盖懒初始化路径。

**建议**: 使用 `InterlockedCompareExchange` 或 `TOnce` 保护初始化。

---

### C05. GBridgeData 全局变量非线程安全

**文件**: `nextpas.core.bench.runner.pas:~50`

```pascal
var
  GBridgeData: record ... end;  // 全局单例
```

`ParallelBenchBridge` 通过全局 `GBridgeData` 传递数据给线程。如果两个 suite 同时并行运行（理论上可能），会产生竞态。

**影响**: 当前实际使用中 suite 顺序执行，但 API 不阻止并发调用。

**建议**: 将 bridge 数据嵌入到 suite 执行上下文中，或加锁保护。

---

### C06. GetBaseline 未抛出预期异常类型

**文件**: `nextpas.core.bench.baseline.pas:~120`

```pascal
raise Exception.CreateFmt('Baseline not found: %s', [AName]);
// 应为: raise EBenchBaselineNotFound.Create(...)
```

接口 `intf.pas` 定义了 `EBenchBaselineNotFound`，但 `GetBaseline` 抛的是裸 `Exception`。

**影响**: 调用方无法精确捕获 `EBenchBaselineNotFound`，只能 catch 通用 Exception 然后字符串匹配。

---

### C07. TestNormalityHeuristic 过于简化

**文件**: `nextpas.core.bench.stats.advanced.pas:~400`

仅基于偏度+峰度的简单阈值判断，不是 Shapiro-Wilk 或 Anderson-Darling。名称暗示了 Shapiro-Wilk 但实现不是。

**影响**: 对非正态但偏度/峰度接近正态的分布会产生误判。

**建议**: 改名为 `LooksNormalByMoments` 以反映实际算法，或实现真正的 Shapiro-Wilk。

---

### C08. ComputeApproximatePValue 仅有 4 个离散阈值

**文件**: `nextpas.core.bench.stats.pas:~300`

```pascal
if LS < 1.0 then Result := 0.5
else if LS < 2.0 then Result := 0.1
else if LS < 2.5 then Result := 0.05
else if LS < 3.0 then Result := 0.01
else Result := 0.001;
```

只有 5 个离散值，连续统计量映射到阶梯函数。这不是近似而是粗暴截断。

**影响**: p-value 精度极差，无法区分 t=1.01 和 t=1.99 的显著性差异。

**建议**: 使用 t 分布 CDF 的数值近似（如 Abramowitz & Stegun 公式），或至少用线性插值。

---

## 🟡 P1 — 设计与 API

### D01. 统计功能重复：TBenchStats/TBenchStatsAnalyzer vs TAdvancedStats

`stats.pas` 中有 `TBenchStats`（record）和 `TBenchStatsAnalyzer`（interface），`stats.advanced.pas` 中有 `TAdvancedStats`（record）。两者都实现 Mean/Median/StdDev/Percentile/OutlierDetection，但算法不同。

**影响**: 维护两套统计代码，行为不一致（如 CI 用 Z vs t）。

**建议**: 统一到一个实现，让 advanced 成为 analyzer 的扩展。

---

### D02. GetByName 返回默认值而非指示"未找到"

**文件**: `nextpas.core.bench.pas` — `TBenchResults.GetByName`

当名称不存在时返回 Default(TBenchResult) 并设置其 Name 字段为查询名。调用方无法区分"找到一个名为 X 但全零的结果"和"未找到 X"。

**建议**: 返回 `Boolean` 并通过 var/out 参数输出结果，或使用 `TryGetByName` 模式。

---

### D03. GenerateJS 返回空字符串（死代码）

**文件**: `nextpas.core.bench.report.pas`

```pascal
function TBenchReportGenerator.GenerateJS: string;
begin
  Result := '';  // stub
end;
```

未完成的功能不应出现在公开 API 中。

**建议**: 移除或标记为 `{$NOTE}` 待实现。

---

### D04. GenerateComparisons O(n²) 名称匹配

**文件**: `nextpas.core.bench.pas` — `GenerateComparisons`

对每个结果遍历所有基线进行名称匹配。当结果和基线数量增长时性能下降。

**影响**: 当前规模（通常 <100 个 bench）影响不大，但设计不优雅。

**建议**: 使用排序+二分或 HashMap 查找。

---

### D05. TBenchSuite.LoadBaseline 无错误处理

**文件**: `nextpas.core.bench.pas`

```pascal
LText := FsReadFileText(AFile);
```

如果文件不存在，`FsReadFileText` 会抛出 IO 异常，但没有被包装成 bench 领域异常。

**建议**: 捕获 IO 异常并抛出 `EBenchError` 或返回 Boolean。

---

### D06. TBenchConfig.Defaults 缺少全局配置集成

**文件**: `nextpas.core.bench.base.pas` — `TBenchConfig.Defaults`

返回硬编码默认值，不读取 `nextpas.core.config` 模块。

**建议**: 未来版本应支持从 `~/.config/nextpas/bench.toml` 读取默认配置。

---

### D07. 报告功能与门面耦合

**文件**: `nextpas.core.bench.report.pas`（916 行）

报告生成器直接调用 `TBenchConfig.Defaults.FormatLocale` 和 `TBenchConfig.Defaults.FormatPrecision` 等全局状态。应该通过构造函数注入。

---

### D08. xlang 解析器缺少错误恢复

**文件**: `nextpas.core.bench.xlang.pas`

`ParseGoBenchLine` / `ParseRustBenchLine` / `ParseFPCBenchLine` 遇到格式不匹配直接跳过，没有日志或错误计数。大量格式异常的行会被静默忽略。

**建议**: 添加可选的 diagnostic 输出或返回跳过计数。

---

## 🟢 P2 — 性能与风格

### E01. 动态数组逐元素增长

**涉及多文件**: `bench.pas`（AddResult）、`baseline.pas`（AddBaseline）、`report.pas`（AddLine）

使用 `SetLength(FResults, Length(FResults) + 1)` 逐个追加。每次追加可能触发整个数组的重新分配和复制。

**建议**: 使用指数增长策略（capacity doubling），或引入 `TArrayList<T>` / `TVec<T>`。

---

### E02. EnsureSorted 逐元素复制

**文件**: `nextpas.core.bench.stats.advanced.pas:~50`

```pascal
SetLength(Result, Length(AData));
for I := 0 to High(AData) do
  Result[I] := AData[I];
```

应直接 `Result := Copy(AData)`。

---

### E03. Percentile 重复计算

**文件**: `stats.pas` 和 `stats.advanced.pas`

每次调用 Percentile 都从头计算，没有缓存排序结果。如果在同一数据上连续调用多个百分位（P25/P50/P75），会重复排序。

**建议**: 接受预排序标志，或内部缓存排序结果。

---

### E04. BootstrapCI 分配两个全尺寸数组

**文件**: `nextpas.core.bench.stats.advanced.pas:~380`

每次 bootstrap 迭代分配 `LResamples` 和 `LBootstrapMeans` 两个完整数组。

**建议**: 预分配一次，迭代中复用。

---

### E05. 测试框架使用不一致

12 个测试中：
- 7 个使用手写 `Check()` 辅助函数（stats/stats_advanced/baseline/parallel/memtrack/report/xlang）
- 3 个使用 `nextpas.core.test` 框架（runner/integration 中部分）
- 2 个使用 heaptrc 风格的 Halt 退出码（parallel_heaptrc/parallel_memtrack_heaptrc）
- 1 个使用异常 + Halt 退出码（invalid_parameters_heaptrc）

**建议**: 统一使用 `nextpas.core.test` 框架，保持测试输出格式一致。

---

### E06. 度量单位注释

`base.pas` 中 `TBenchResult.NsPerOp` 注释为"纳秒/操作"，但未在 record 定义处标注，需在注释或文档中明确约定。

---

### E07. xlang 测试缺少边界用例

`test_bench_xlang.lpr` 测试了基本解析，但缺少：
- 非 UTF-8 输入
- 超长行
- 数字溢出（如 `ops/sec` 超出 Int64 范围）

---

### C09. 基线对比报告状态标签反转 🔴 新发现

**文件**: `nextpas.core.bench.report.pas:892-895`

```pascal
if ABaselines[i].Ratio > 1.0 then
  LStatus := '✓ faster'    // ← 错误！Ratio > 1.0 表示当前更慢
else
  LStatus := '✗ slower';   // ← 错误！Ratio < 1.0 表示当前更快
```

`Ratio = CurrentNsPerOp / BaselineNsPerOp`。Ratio > 1.0 意味着当前花费更多时间，应该是 **更慢**（回归），但代码显示为"✓ faster"。

**影响**: 用户看到的对比结果完全颠倒——回归显示为"加速"，优化显示为"退化"。这是一个严重的 UX 误导 bug。

**建议**: 交换标签：
```pascal
if ABaselines[i].Ratio > 1.0 then
  LStatus := '✗ slower'
else if ABaselines[i].Ratio < 1.0 then
  LStatus := '✓ faster'
else
  LStatus := '≈ same';
```

---

### C10. StdDev 单遍算法数值不稳定 🟡 新发现

**文件**: `nextpas.core.bench.stats.pas:180-198`

```pascal
// 单次遍历计算均值和方差
LSum := 0;
LSumSq := 0;
for I := 0 to High(AData) do
begin
  LVal := AData[I];
  LSum += LVal;
  LSumSq += LVal * LVal;
end;
LMean := LSum / LLen;
LVariance := (LSumSq - LLen * LMean * LMean) / (LLen - 1);
```

这是 sum-of-squares 方法（也称 textbook formula），不是 Welford 的单遍算法。当数据方差小但均值大时（如 `1e9 + small_variation`），`LSumSq - LLen * LMean * LMean` 会产生灾难性抵消（catastrophic cancellation），导致负方差。

代码加了 `if LVariance < 0 then LVariance := 0` 的保护，但这掩盖了问题——方差被静默截断为 0，标准差永远正确显示为 0。

同一文件中 `ComputeVariance`（:148-161）使用两遍算法（先算 Mean 再算方差），是数值稳定的。两套算法共存。

**影响**: 大数值基准测试（如吞吐量 1e9+ ops/s）的标准差可能计算错误。

**建议**: 统一使用 Welford 单遍算法，或统一使用两遍算法（先 Mean 后方差）。移除 `LVariance < 0` 的静默截断。

---

### C11. Rust criterion 解析器假设每个值都带单位 🟡 新发现

**文件**: `nextpas.core.bench.xlang.pas:258-267`

```pascal
// Format: ["1.234", "us", "1.256", "us", "1.279", "us"]
LParts := StringsSplit(LTimeStr, ' ', True);
if Length(LParts) < 6 then
  raise EParseError.CreateFmt('Invalid Rust bench time range: %s', [LTimeStr]);

LLower := StrToFloatDef(LParts[0], 0);
LUnit := LParts[1];   // ← 假设 Parts[1] 是 mean 的单位
LMean := StrToFloatDef(LParts[2], 0);
LUpper := StrToFloatDef(LParts[4], 0);
```

代码假设格式是 `[lower unit mean unit upper unit]`（6 个 token）。但 criterion 的实际输出格式是：

```
time:   [1.234 us 1.256 us 1.279 us]    // 6 tokens — 兼容
time:   [1234.5 ns 1256.0 ns 1279.0 ns]  // 6 tokens — 兼容
time:   [1.234 1.256 1.279 us]           // 4 tokens — 不兼容！
```

如果 criterion 输出省略重复单位（只在最后一个值后标注），解析器会抛 `EParseError` 或误解析。

**影响**: 部分 criterion 输出格式无法解析。当前测试中用的 mock 格式恰好是 6 token 格式，所以测试通过。

**建议**: 支持两种格式，先尝试 6-token，失败后尝试 `[value value value unit]` 的 4-token 格式。

---

### C12. Skewness/Kurtosis 使用有偏估计器 🟡 新发现

**文件**: `nextpas.core.bench.stats.advanced.pas:236-276`

```pascal
// Skewness — 除以 LCount（有偏）
Result := LSum / LCount;

// Kurtosis — 除以 LCount（有偏）
Result := (LSum / LCount) - 3;
```

样本偏度和峰度应该使用无偏估计器（除以 n 而不是 n-1 对偏度的影响较小，但峰度的偏差更显著）。标准公式：
- 偏度无偏: `g1 * sqrt(n*(n-1)) / (n-2)` （Fisher's g1）
- 峰度无偏: 更复杂的校正公式

**影响**: 小样本（n < 20）时偏度和峰度被低估，影响正态性检验的准确性。当前 `TestNormalityHeuristic` 的阈值是经验值（>0.8 判正态），所以偏差可能被阈值吸收了。

---

### D09. ComputeVariance 重复计算均值 🟡 新发现

**文件**: `nextpas.core.bench.stats.pas:148-161`

```pascal
function TBenchStatsAnalyzer.ComputeVariance(const AData: TDoubleArray; AMean: Double): Double;
```

虽然接受 `AMean` 参数避免重复计算，但 `StdDev` 方法（:168-198）和 `Variance` 方法（:216-234）各自独立计算均值。`ComputeStats`（:245）传入了已算好的 Mean，但 `TBenchStatsAnalyzer.StdDev`（:168）没有——它重新计算了均值和方差。

`stats.advanced.pas` 中的 `TAdvancedStats.Variance`（:221-234）调用 `Mean` 但不缓存结果。

---

### D10. 配置默认值隐含冲突 🟡 新发现

**文件**: `nextpas.core.bench.pas:141-149`

```pascal
FConfig.EnableMemoryTracking := True;   // 默认开
FConfig.EnableParallel := False;        // 默认关
```

如果用户同时 `EnableMemoryTracking` 和 `AddParallel`，执行时会：
```pascal
// runner.pas:444
ATrackMemory := False;  // 并行基准自动跳过内存跟踪（不抛出异常）
```

没有警告或日志。用户以为内存跟踪已开启，但实际上被静默禁用。

**建议**: 当 parallel + memtrack 同时设置时，输出警告或在 `Run` 时抛 `EBenchInvalidParam`。

---

### D11. LoadFromJSON 对缺失字段不验证 🟡 新发现

**文件**: `nextpas.core.bench.baseline.pas:390-394`

```pascal
LField := LItem.ObjectGet('nsPerOp');
LBaseline.NsPerOp := LField.AsFloat;   // ← 不检查 LField 是否存在

LField := LItem.ObjectGet('bytesPerOp');
LBaseline.BytesPerOp := LField.AsInt;   // ← 不检查 LField 是否存在
```

如果 JSON 缺失 `nsPerOp` 等字段，`ObjectGet` 返回 nil/null，`AsFloat`/`AsInt` 可能返回 0 或抛异常（取决于 JSON 实现）。`name` 字段做了 `IsStr` 检查，但数值字段没有。

**建议**: 对 `nsPerOp` 等必需字段做 `IsFloat` / `IsInt` 存在性检查。

---

### D12. HasRegression 阈值语义模糊 🟡 新发现

**文件**: `nextpas.core.bench.pas:598-612`

```pascal
function TBenchResults.HasRegression(AThreshold: Double): Boolean;
begin
  LComparisons := GenerateComparisons;
  for i := 0 to High(LComparisons) do
    if LComparisons[i].DifferenceHeuristic and
       (LComparisons[i].Ratio > AThreshold) then
      Exit(True);
```

`DifferenceHeuristic` 是 5% 阈值（`Abs(Ratio - 1.0) > 0.05`），而 `AThreshold` 是另一个比率阈值。两个条件必须同时满足。但 `DifferenceHeuristic` 的硬编码 5% 与传入的 `AThreshold` 无关。

**影响**: 传入 `AThreshold = 1.5` 时，只有当 Ratio > 1.5 **且** Ratio 与 1.0 差距 > 5% 时才触发。后者总是满足（因为 1.5 > 1.05），所以实际上只检查 `Ratio > AThreshold`。但传入 `AThreshold = 1.01` 时，`DifferenceHeuristic` 成为额外的守卫——语义不直觉。

**建议**: 移除 `DifferenceHeuristic` 条件或让 `AThreshold` 直接控制。

---

## 🟢 P2 — 新发现

### E08. BoxPlot 使用插入排序 🟢 新发现

**文件**: `nextpas.core.bench.report.pas:765-775`

```pascal
for LIndex := 1 to LCount - 1 do
begin
  LKey := LSorted[LIndex];
  LInnerIndex := LIndex - 1;
  while (LInnerIndex >= 0) and (LSorted[LInnerIndex] > LKey) do
  begin
    LSorted[LInnerIndex + 1] := LSorted[LInnerIndex];
    Dec(LInnerIndex);
  end;
  LSorted[LInnerIndex + 1] := LKey;
end;
```

手写插入排序，未使用 `SortDoubleArray`。当样本数增多（如 CollectRawSamples 收集数千个样本时），O(n²) 排序会成为瓶颈。

**建议**: 改用 `SortDoubleArray(LSorted)`。

---

### E09. Warmup 在并行模式下串行执行 🟢 新发现

**文件**: `nextpas.core.bench.parallel.pas:170-174`

```pascal
// Warmup
if FConfig.WarmupIterations > 0 then
begin
  for I := 0 to FConfig.ThreadCount - 1 do
    FFunc(I, FConfig.WarmupIterations);   // ← 串行热身
end;
```

并行基准的预热在主线程上串行执行，不代表真实的并行执行环境。

**影响**: 预热可能无法充分初始化线程本地缓存、JIT 等。对微基准影响较小。

---

### E10. TSV 输出未转义制表符 🟢 新发现

**文件**: `nextpas.core.bench.report.pas:372-384`

```pascal
FResults[i].Name + #9 + ...
```

如果基准名称包含 `#9`（Tab），TSV 格式会被破坏。虽然正常情况下名称不含 Tab，但防御性编程应处理。

---

### E11. ToJSON 手工拼接 vs 使用 TJsonWriter 🟢 新发现

**文件**: `nextpas.core.bench.report.pas:297-357`

报告的 `ToJSON` 使用字符串拼接 + `EscapeJSON` 构建 JSON。同一模块的 `baseline.pas:ToJSON` 使用 `TJsonWriter`（正确做法）。

**建议**: 统一使用 `TJsonWriter`，减少手工转义的出错风险。

---

## 文档缺口

### DOC01. 无模块 README

`core/docs/` 下无 bench 相关文档。需创建：
- `core/docs/bench/README.md` — 模块概述、使用指南
- 设计决策说明（为何选择 Welch's t-test、bootstrap 参数等）

---

## 构建卫生

### HYG01. core/src/ 下有 208 个 .o/.ppu 文件

```
core/src/*.o    — 编译产物散落在源码目录
core/src/*.ppu  — FPC 单元缓存散落在源码目录
```

违反 CLAUDE.md 的"构建产物卫生"规则。应落入 `build/` 目录。

---

## 测试覆盖评估

| 源单元 | 测试程序 | 覆盖评估 |
|--------|----------|----------|
| base (types/sort) | test_bench_stats (Sort 测试) | ✅ 基本覆盖 |
| intf | test_bench_integration (间接) | ✅ 通过 runner 覆盖 |
| stats | test_bench_stats | ✅ 良好覆盖 |
| stats.advanced | test_bench_stats_advanced | ✅ 良好覆盖 |
| bench (facade) | test_bench_integration | ✅ 全面覆盖 |
| baseline | test_bench_baseline | ✅ 全面覆盖 |
| memtrack | test_bench_memtrack | ✅ 含并行线程安全测试 |
| parallel | test_bench_parallel | ✅ 基本覆盖 |
| runner | test_bench_runner | ✅ 校准+执行+配置 |
| report | test_bench_report | ✅ 全格式输出+转义 |
| xlang | test_bench_xlang | ⚠️ 缺边界用例 |

**缺失**: heaptrc 泄漏检测仅覆盖 parallel 和 memtrack 场景，stats/runner/report 无 heaptrc 测试。

---

## 建议优先级

### 立即修复 (P0 → 下一轮)
1. **C09** 基线对比状态标签反转 — 一行修复，**最严重 UX 误导**
2. **C01** IntroSort 深度限制 — 一行修复
3. **C06** GetBaseline 异常类型 — 一行修复
4. **C04** GlobalMemoryTracker 线程安全 — 小改动，InterlockedCompareExchange
5. **H01** 清理构建产物 — `make clean` 或 gitignore 调整

### 下一迭代 (P1)
6. **C10** StdDev 数值稳定性 — 改为 Welford 或两遍算法
7. **C02** ConfidenceInterval 用 t 分布 — 中等改动
8. **C03** BootstrapCI 随机种子 — 一行改动
9. **C11** Rust criterion 解析器兼容性 — 补充 4-token 格式
10. **D01** 统计功能去重 — 需要重构
11. **D02** GetByName 返回值语义 — API 变更，需评估影响
12. **D10** memtrack + parallel 配置冲突警告
13. **D11** LoadFromJSON 字段验证

### 未来优化 (P2)
14. **E01** 动态数组增长策略
15. **D03** 移除 GenerateJS 死代码
16. **E05** 测试框架统一
17. **E08** BoxPlot 改用 SortDoubleArray
18. **E11** ToJSON 统一用 TJsonWriter
19. **DOC01** 编写模块文档

### 统计计数
| 严重程度 | 第一轮 | 第二轮 | 总计 |
|----------|--------|--------|------|
| 🔴 P0 | 8 | 1 (C09) | 9 |
| 🟡 P1 | 8 | 5 (C10-C12, D09-D12) | 13 |
| 🟢 P2 | 7 | 4 (E08-E11) | 11 |
| **总计** | **23** | **10** | **33** |
