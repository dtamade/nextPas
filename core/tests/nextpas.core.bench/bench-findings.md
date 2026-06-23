# bench 模块全面审查 — Findings（第二期）

> **审查日期**: 2026-06-23
> **审查范围**: 11 源文件 + 12 测试文件 (~10,800 行)
> **审查维度**: Correctness / Architecture / Performance / Test Coverage / API
> **审查阶段**: 第二期（首次审查 2026-06-21 已记录 C01-C03/D01-D14/P01-P10/T01-T07/S01-S05）
> **已排除**: 首次审查已标记"已修复"或"不修复/推迟"或"已知"的条目（C01-C03 已修复、D01/D02/D03 不修复、D07/D08/D09 已知）

---

## 严重度分布

| 严重度 | 数量 | ID 范围 |
|--------|------|---------|
| P0 — 测试质量/断言恒真 | 7 | T01-T07 |
| P0 — 崩溃风险 | 1 | CR-01 |
| P0 — 正确性 | 1 | CR-02 |
| P1 — 正确性（逻辑缺陷） | 24 | CR-03 至 CR-26 |
| P1 — 测试覆盖缺口 | 15 | TG-01 至 TG-15 |
| P2 — 性能 | 20 | PF-01 至 PF-20 |
| P2 — 设计 | 14 | DS-01 至 DS-14 |
| P2 — 测试改进 | 15 | TG-16 至 TG-30 |
| P3 — 风格/设计/文档 | 27 | ST-01 至 ST-27 |
| **总计** | **124** | |

---

## 1. P0 — 测试质量（断言恒真/逻辑错误）

### T01 — TestIsNormal uniform distribution no assertion
- **File**: test_bench_stats.lpr:329-353
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: TestIsNormal 生成均匀分布数据（0-1 均匀分布）后调用 `AssertFalse(StatsAnalyzer.TestNormalityByMoments(LData))`。均匀分布不是正态分布，但该测试只验证对均匀分布"不够正态"——它没有断言实际上断言了什么东西。如果 TestNormalityByMoments 对任何输入都返回 False，此测试永远通过。
- **Suggested fix**: 增加已知正态分布数据的正向测试（AssertTrue），并验证均匀数据的 p 值确实远低于正态数据。

### T02 — Kurtosis assertion wrong
- **File**: test_bench_stats_advanced.lpr:130
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: 测试代码调用 kurtosis 后断言 `LResult > 0`。对于标准正态分布样本，样本峰度接近 0（超额峰度），但测试数据是 1..100 等差序列，峰度应为负值（约 -1.2）。断言 `>0` 完全靠随机波动通过。
- **Suggested fix**: 计算已知序列的预期峰度值并直接断言相等（带合理的 epsilon）。

### T03 — Z-Score test assertion always true
- **File**: test_bench_stats_advanced.lpr:186-189
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: `AssertTrue(Length(LOutliers) > 0)` 在测试已知包含异常值的数据集上执行。如果 Z-Score 算法没有正确检测到插入的异常值（例如 999），测试仍然可以通过——只要至少有一个异常值被找到。但测试数据本身（100 个 N(0,1) 样本加一个 999）几乎肯定会有误报，使断言无意义。
- **Suggested fix**: 验证 999 是否在 LOutliers 中，而不是仅检查计数 > 0。

### T04 — GetBaseline always-true Check(True)
- **File**: test_bench_baseline.lpr:96-99
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: `Check(True)` 是一个空断言——始终通过，不验证 `GetBaseline` 返回值的任何属性。
- **Suggested fix**: 替换为验证返回的 baseline 名称、NsPerOp 等字段的断言。

### T05 — GenerateComparisonReport only checks existence
- **File**: test_bench_report.lpr:306-341
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: 调用 `GenerateComparisonReport` 后只检查结果非空（`LReport.Contains('string')`），没有验证报告中的具体内容（如比率、百分比变化、统计显著性标记）。对于格式错误的报告也可能通过。
- **Suggested fix**: 添加对报告关键字段（Ratio、IsRegression、PercentChange）的模式匹配或具体内容断言。

### T06 — Shared counter tests only > 0 not =40000
- **File**: test_bench_parallel.lpr:133
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: 并行计数器测试断言 `AssertTrue(LCounter > 0)`，预期值应是 `40000`（4 线程 × 10000 迭代/线程）。宽松断言 `> 0` 掩盖了竞态条件或其他并发问题。
- **Suggested fix**: 断言精确值 `LCounter = 40000`，或至少 `LCounter >= 40000`。

### T07 — GetLastParseSkippedCount never tested
- **File**: xlang.pas (test_bench_xlang.lpr)
- **Severity**: P0
- **Category**: 测试质量
- **Detail**: `GetLastParseSkippedCount` 是一个 public 函数，返回解析期间跳过的条目数。没有任何测试文件调用此函数，验证其计数准确性。
- **Suggested fix**: 添加测试：解析包含已知数量的有效+无效行，验证返回的跳过计数。

---

## 2. P0 — 正确性（崩溃风险）

### CR-01 — IsEmptyOrComment crashes on empty string [1]
- **File**: xlang.pas:101
- **Severity**: P0
- **Category**: 崩溃风险
- **Detail**: `(Trim(ALine) = '') or (Trim(ALine)[1] = '#')` 中，当 ALine 为空或仅含空白时，`Trim(ALine)` 返回空字符串，访问 `[1]` 触发索引越界运行时错误。
- **Suggested fix**: 短路顺序：`(Trim(ALine) = '') or (Trim(ALine)[1] = '#')` 应改为 `(Trim(ALine) = '') or (Trim(ALine)[1] = '#')`，但需要先检查 `Trim(ALine) <> ''`。正确写法：`(Trim(ALine) = '') or ((Length(Trim(ALine)) > 0) and (Trim(ALine)[1] = '#'))` 或使用 `StartsWith`。

---

## 3. P0 — 正确性（逻辑缺陷）

### CR-02 — CompareWithBaseline returns array no ComparisonCount
- **File**: intf.pas:196
- **Severity**: P0
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `CompareWithBaseline` 返回 `TBaselineComparisonArray`（动态数组），但调用方无法区分"所有 comparison 都为空/正常"与"comparison 数量为零（无 baseline）"。返回空数组时，调用方可能误以为"一切正常"，跳过 regression 检查。
- **Suggested fix**: 返回一个带 Count 字段的 record，或者确保空数组也通过 IsRegression=False 的 comparison 表示"无 baseline 时无 regression"。

### CR-03 — Median(var) doesn't modify — intf.pas:233
- **File**: intf.pas:233, stats.pas:65,130
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `procedure Median(var AData: TDoubleArray; out AMedian: Double);` 声明为 var 参数（意图暗示可能修改数组），但实现中 Median 不修改输入数组。暴露了实现细节，且调用者可能误以为数组会被修改而传入不安全副本。
- **Suggested fix**: 改为 `const AData: TDoubleArray` 参数，或在文档中说明 var 仅用于性能（避免复制）。

### CR-04 — PValue/HeuristicDifference in wrong interface
- **File**: intf.pas:221-L224
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `PValue` 和 `HeuristicDifference` 方法定义在 `IBenchStatsAnalyzer` 上但文档声称"this is a heuristic, not a statistical test"。这两个方法返回统计意义上的 p 值和效应量，不应放在仅提供启发式分析的接口上。调用者可能误以为这些是精确统计测试结果。
- **Suggested fix**: 拆分为 `IStatisticalAnalyzer` 或重命名为 `HeuristicPValue/HeuristicDifference` 并添加文档警告。

### CR-05 — TestNormalityByMoments mix skewness/excess kurtosis
- **File**: stats.advanced.pas:596
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 正态性检验使用 D'Agostino-Pearson K² 统计量，其公式为 K² = Z_skewness² + Z_kurtosis²。但实现中的 kurtosis 分量使用的是原始峰度（Kurtosis），而非"超额峰度"（Kurtosis - 3）。在样本中，峰度已经计算为超额峰度（stats.advanced.pas:304），但检验公式预期的是超额峰度 Z-score，却用原始峰度计算。如果 Kurtosis 函数返回的是中心峰度（非超额），则 K² 统计量偏差较大。
- **Suggested fix**: 检查 Kurtosis 函数返回的实际值类型（中心矩 vs 超额峰度），确保 K² 计算的 Z-score 使用正确的标准化公式。

### CR-06 — Kurtosis redundant LCount check
- **File**: stats.advanced.pas:304
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 在 Kurtosis 实现中，`LCount` 检查 `LCount` 是否 > 3 来避免除以零。但如果 `LCount = 0` 或 `LCount < 4`，应该提前返回而不是继续计算到 `Power(x - mean, 4)`步骤。更严重的是，Kurtosis 超额峰度的修正使用了 `(N-1)*(N-2)*(N-3)` 分母，当 N < 4 时会产生无效值。
- **Suggested fix**: 在函数入口处增加 `Length(AData) < 4` 的提前返回（返回 0 或 raise）。

### CR-07 — DetectOutliers_ZScore masking effect
- **File**: stats.advanced.pas:373-409
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Z-Score 异常值检测实现使用样本均值和标准差。多个异常值的存在会使均值和标准差都向异常值偏移，导致掩蔽效应（masking）——异常值相互掩盖，使 Z-score 无法达到阈值。标准做法是使用修正 Z-score（MAD 中位数法），或使用迭代去除法。
- **Suggested fix**: 默认使用 Modified Z-Score（已实现为单独方法）；或者在 Z-Score 检测中采用迭代方式：每次检测一个最大值，去除后重新计算均值和标准差。

### CR-08 — BootstrapCI fixed seed LCG quality
- **File**: stats.advanced.pas:538-549
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Bootstrap 置信区间使用线性同余生成器（LCG）作为 PRNG。LCG 在生成 >= 1000 次重采样时可能出现短周期或相关性。默认 Bootstrap 迭代次数 >= 1000，LCG 的质量不足以提供统计意义上的可靠 Bootstrap 分布。
- **Suggested fix**: 改用质量更好的 PRNG（如 Mersenne Twister 或 Xoroshiro），或至少在文档中注明 Bootstrap 是近似值，非精确统计推断。

### CR-09 — BootstrapCI redundant LSortedMeans copy
- **File**: stats.advanced.pas:555-559
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 同时创建 `LMeans` 和 `LSortedMeans` 两个大小相等的数组，然后复制所有元素。对 `LMeans` 原地排序即可，无需第二个数组的分配和复制。
- **Suggested fix**: 移除 `LSortedMeans`，对 `LMeans` 原地排序后直接用于百分位数查找。

### CR-10 — R4: Parallel bridge discards per-iteration timing
- **File**: runner.pas:189-191
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `ParallelBenchBridge` 函数中工作线程执行完所有迭代后，只记录总迭代次数和最终的 BytesPerOp/AllocsPerOp，不记录每次迭代的耗时。这意味着无法区分"慢速单次迭代"和"快速多次迭代"——并行结果只给出总耗时。
- **Suggested fix**: 在工作线程上记录起始和结束时间，传回总耗时（或每次迭代的耗时列表）。

### CR-11 — R5: GetElapsed no underflow guard
- **File**: runner.pas:240-241
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `LCurrentNs - FStartNs` 当系统时钟回拨（如在容器/虚拟化环境下 NTP 调整）或 `platform_monotonic_ns` 在跨 CPU 核心下返回无序值时，可能产生下溢（wrapping 或负值）。Pascal 无符号减法产生巨量正值，导致虚假的极长耗时。
- **Suggested fix**: 检查 `LCurrentNs >= FStartNs`，若不满足则返回 0 或上次测量值。

### CR-12 — R6: Calibration loop overshoots max iterations
- **File**: runner.pas:560-598
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 校准循环在达到目标耗时后仍可能继续迭代（因为指数增长可能跳过目标区间，且没有上限中断检查）。在极端情况下（如耗时 0ns 导致校准因子增长失控），迭代次数可能远超 `MaxIterations` 配置值。
- **Suggested fix**: 在校准循环中添加 `LIters > FConfig.MaxIterations` 检查，超过后立即退出。

### CR-13 — R16: Loop path creates context but never passes to user
- **File**: runner.pas:411-447
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Loop 执行路径（`AEntry.IsLoop and Assigned(AEntry.LoopFunc)`）创建了 `LContext` 对象并调用 `Reset`、`SetIterations`，但对 LoopFunc 只调用 `AEntry.LoopFunc(AIters)`——`LContext` 从未传递给用户。这意味着用户无法在 loop 路径中调用 `SetBytes`、`SetAllocs`、`Skip` 等方法，它们全部无声忽略。
- **Suggested fix**: LoopFunc 签名应接受 `IBenchContext` 参数（如 `TBenchLoopFunc`），或明确文档说明 loop 路径不支持上下文操作。

### CR-14 — R24: ThreadCount not validated (0/negative)
- **File**: parallel.pas:177-179
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `ParallelThreads` 未验证下限。如果设置为 0 或负数，可能造成线程池初始化失败、除零错误，或创建 0 个线程而导致无限等待。
- **Suggested fix**: 在入口处添加 `if AConfig.ThreadCount < 1 then AConfig.ThreadCount := 1`。

### CR-15 — RP1: FormatNumber FloatToStrF name conflict with SysUtils
- **File**: report.pas:165-168
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `report.pas` 如果同时 uses SysUtils 或 nextpas.core.system.sysutils，`FloatToStrF` 是一个标准 RTL 函数。`FormatNumber` 内部调用的 `FloatToStrF` 可能被意外重载或与其他 RTL 调用冲突。如果使用 `uses nextpas.core.system.sysutils` 迁移，可能导致名称解析歧义。
- **Suggested fix**: 明确使用 `System.FloatToStrF` 或 `SysUtils.FloatToStrF` 限定调用，避免歧义。

### CR-16 — RP3: EscapeJSON missing \0, \b, \f control chars
- **File**: report.pas:227-250
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: EscapeJSON 处理了 `"`, `\`, `/`, `\n`, `\r`, `\t` 但缺少 JSON 规范要求的 `\0`（NUL）、`\b`（Backspace）、`\f`（Form Feed）。如果基准数据中包含这些字符（虽不常见），输出的 JSON 将不符合标准。
- **Suggested fix**: 添加 `#0`、`#8`（BS）、`#12`（FF）的转义处理。

### CR-17 — RP4: OpsPerSec Double-to-Int64 truncation
- **File**: report.pas:311,629
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `OpsPerSec := Round(1e9 / NsPerOp)` 使用 `Round` 但赋值给 Int64 字段。对于极快操作（NsPerOp < 1），`1e9 / NsPerOp` 可能超过 MaxInt64(~9.2e18)，`Round` 返回的值截断到 Int64 范围时给出错误结果。
- **Suggested fix**: 限制 `OpsPerSec` 到 `MaxInt64`，或使用 `High(Int64)` 作为上限，并在文档中说明。

### CR-18 — RP5: "Top 5 non-skipped" readability
- **File**: report.pas:341-363
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 控制台输出"Top 5 non-skipped"标题，但如果实际只有 2 个基准，仍输出"Top 5"标题，然后只显示 2 行。没有提前检查实际条目数量，可能导致不准确的标题。
- **Suggested fix**: 使用 `Min(5, LActualCount)` 动态计算"Top X"，而不是硬编码 5。

### CR-19 — RP6: TSV Name/SkipReason not escaped
- **File**: report.pas:450-479
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: TSV 输出中，如果基准名称或 SkipReason 包含 Tab 字符或换行符，输出格式会被破坏（列移位）。JSON 和 HTML 路径做了转义，但 TSV 完全未处理。
- **Suggested fix**: 在 TSV 输出中替换 Tab/换行符为空格或 `\t`/`\n`。

### CR-20 — RP9: GenerateChart fragile FResults slice
- **File**: report.pas:601
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: GenerateChart 方法假设 `FResults` 中的前 N 个条目与传递给它的 `startIndex`/`count` 完全对齐。如果 `FResults` 在两次 GenerateChart 调用之间被修改，索引计算错误产生越界访问或错位图表数据。
- **Suggested fix**: 传递切片副本或使用不可变快照，避免在生成期间引用可变数据。

### CR-21 — RP11: SVG bar chart labels overflow viewBox
- **File**: report.pas:528-543
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: SVG 条形图的基准名称标签（`<text>` 元素）放置在 x 轴上，但没有宽度计算。长名称（>15 字符）或中文字符超出 viewBox 宽度，导致标签被切断或与其他条重叠。
- **Suggested fix**: 根据最长名称动态计算 viewBox 宽度，或使用 SVG `<textPath>` 和更智能的间距算法。

### CR-22 — RP12: Cross-lang bar width uses global max not per-group
- **File**: report.pas:723-768
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 跨语言条形图中，每个基准组（同一基准的不同语言实现）的条宽度基于全局最大 NsPerOp 计算，而不是组内缩放。当不同语言实现的 NsPerOp 差异极大时（如 1000x），慢速实现的条几乎不可见。
- **Suggested fix**: 使用分组归一化（每组内部缩放，而不是全部基于全局最大值），或提供可选的相对缩放模式。

### CR-23 — RP13: BoxPlot quartiles use integer division for small samples
- **File**: report.pas:825-836
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 箱线图四分位计算使用整数索引 `Length(LData) div 2`、`div 4`、`div 4 * 3`，在小样本（如 1-3 个元素）时产生相同索引的重复使用，导致 Q1 = Q2 = Q3，箱线图退化。
- **Suggested fix**: 使用 stats.pas 中的 `Percentile` 函数（支持线性插值），或对小样本使用专门的箱线图算法。

### CR-24 — RP16: Comparison Report Ratio=1.0 edge case
- **File**: report.pas:912-948
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 当基准结果与 baseline 完全相同时（Ratio=1.0），比较报告的"regression/improvement"显示逻辑未独立处理 Ratio=1.0 情况。颜色编码（绿色 vs 红色）仍基于 `Ratio > 1.0`，但 1.0 既不是 regression 也不是 improvement，却被标记为 regression（如果 Ratio >= 1.0）。
- **Suggested fix**: 对 Ratio=1.0 使用中性颜色标记（黄色/灰色）和"unchanged"文本。

### CR-25 — RP26: GenerateComparisonReport AResults parameter unused
- **File**: report.pas:928-944
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `GenerateComparisonReport` 的 `AResults` 参数在实现中未使用。该方法似乎使用了内部的 `FResults`（来自 `SetResults` 调用），导致传入的外部结果被忽略。如果调用方期望同时使用两个结果集，会得到错误报告。
- **Suggested fix**: 移除未使用的参数，或实现使用该参数的逻辑。

### CR-26 — RP30: Cross-language report assumes sorted input
- **File**: report.pas:714-788
- **Severity**: P1
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 跨语言报告生成假定输入结果已经按基准名称排序或分组。如果输入交错的（Go/nextPas/Go/nextPas），分组算法会将不同语言的条目错配，产生无效的跨语言比较结果。
- **Suggested fix**: 在分组前按名称排序，或使用类似 `CompareWithBaseline` 的名称匹配方式。

---

## 4. P1 — 测试覆盖缺口（公共 API 未测试）

### TG-01 — GlobalMemoryTracker API 4 functions never tested
- **File**: memtrack.pas (test_bench_memtrack)
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `EnableGlobalMemoryTracking`、`DisableGlobalMemoryTracking`、`ResetGlobalMemoryTracker`、`GetGlobalMemoryStats` 这四个函数存在于 public API 中，但没有任何测试直接验证全局跟踪器的启用/禁用状态和重置行为。
- **Suggested fix**: 添加测试：分别调用 4 个函数，验证状态转换和统计重置。

### TG-02 — RunOne(TBenchEntry) overload not tested
- **File**: test_bench_runner
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `TBenchRunner.RunOne` 接受 `TBenchEntry` 参数的重载未被任何测试直接调用。只有传入 `TBenchFunc` 的重载被测试。可能遗漏了 `TBenchEntry` 特定字段（如 EnableParallel、WarmupIterations）的影响测试。
- **Suggested fix**: 构造 `TBenchEntry` 实例并使用 `RunOne` 调用，验证所有 entry 字段生效。

### TG-03 — SortDoubleArray boundary not directly tested
- **File**: base.pas (test_bench_stats)
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `SortDoubleArray` 是一个 public 工具函数，但没有任何测试直接对其调用边界情况（空数组、单元素、逆序、全相等）。它只通过统计分析间接测试。
- **Suggested fix**: 在 test_bench_stats 中添加 SortDoubleArray 专用测试用例。

### TG-04 — TInvLookup boundary not directly tested
- **File**: base.pas (test_bench_base or similar)
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `TInvLookup` 类型（逆 t-分布表查找）无直接测试。边界情况（df<1、df 超大、p 值接近 0 或 1）未被验证。
- **Suggested fix**: 添加 TInvLookup 直接测试，验证已知的 t-分布临界值。

### TG-05 — TAdvancedStats missing NaN/Infinity
- **File**: test_bench_stats_advanced
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `TAdvancedStats` 的 `DetectOutliers_*`、`BootstrapCI`、`Percentile`、`Kurtosis` 等方法均未测试 NaN 或 Infinity 输入值。这些值会导致无限循环或 NaN 污染。
- **Suggested fix**: 为每个高级统计方法添加 NaN/Infinity 输入用例。

### TG-06 — stats missing NaN/Infinity input
- **File**: test_bench_stats
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `TBenchStatsAnalyzer` 的 `Mean`、`StdDev`、`Percentile`、`Median` 等方法未测试 NaN 或 Infinity 输入。FPC 浮点数运算不自动检测 NaN，结果静默传播。
- **Suggested fix**: 为每个基础统计方法添加 NaN/Infinity 测试用例，验证抛出 EBenchError 或返回特定标记。

### TG-07 — xlang missing empty input/newline
- **File**: test_bench_xlang
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: xlang 解析器未在测试中覆盖空输入、纯换行符、仅空白行等边缘情况。这些输入直接触发 CR-01（崩溃）。
- **Suggested fix**: 添加 `ParseGoOutput('')`、`ParseGoOutput(#10)`、`ParseGoOutput(#13#10)` 等测试。

### TG-08 — Report generator missing empty result set
- **File**: test_bench_report
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `GenerateComparisonReport` 和 `ToHTML` / `ToJSON` 在接受空 TBenchResult 数组时的行为未测试。可能产生空报告或除零崩溃。
- **Suggested fix**: 传入空数组调用每种报告格式，验证优雅处理（返回空报告而非崩溃）。

### TG-09 — GenerateBoxPlot missing empty/single/constant
- **File**: test_bench_report
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `GenerateBoxPlot` 未测试空数据、单元素数据、或所有值相等的常数数据。这些情况直接触发 CR-23（整数除法 Q1=Q2=Q3）。
- **Suggested fix**: 添加空、单元素、二维、常数样本的箱线图生成测试。

### TG-10 — TryGetByName never tested
- **File**: test_bench_integration
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `IBenchResults.TryGetByName` 方法未被任何测试文件显式调用。该方法是公开 API 的一部分，未测试意味着可能的回归。
- **Suggested fix**: 添加对 TryGetByName 的集成测试（存在条目、不存在条目、大小写匹配）。

### TG-11 — GetAll not directly tested
- **File**: test_bench_integration
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `IBenchResults.GetAll` 返回 `TBenchResultArray` 但无直接测试验证返回数组的语义（如是否与 RunAll/AddRange 添加的条目顺序一致）。
- **Suggested fix**: 添加对 GetAll 返回值的顺序和完整性的验证测试。

### TG-12 — RunAll doesn't verify stats completeness
- **File**: test_bench_runner
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `RunAll` 测试验证运行成功但未检查返回的 `TBenchResults` 中所有统计字段是否已填充（StdDev、Median、P95、P99 等）。如果某些统计字段为 0（默认值），测试仍通过。
- **Suggested fix**: 对统计字段添加非零检查和合理性验证。

### TG-13 — CompareAllWithBaselines doesn't verify comparison fields
- **File**: test_bench_baseline
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `CompareAllWithBaselines` 测试只检查返回的 comparison 数组长度，未验证每个 comparison 的 `Ratio`、`IsRegression`、`PercentChange` 等字段是否符合预期。
- **Suggested fix**: 构造已知 baseline → 结果的映射，验证每个 comparison 字段。

### TG-14 — LoadFromFile file-not-exists not tested
- **File**: test_bench_baseline
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: `LoadFromFile` 的文件不存在路径未被测试。当前代码捕获异常并抛 EBenchError，但未验证错误信息是否包含文件路径和失败原因。
- **Suggested fix**: 用不存在的路径调用 LoadFromFile，验证抛 EBenchError 且消息包含路径。

### TG-15 — xlang Rust parser mean=0 not validated
- **File**: xlang.pas:292-310
- **Severity**: P1
- **Category**: 测试覆盖缺口
- **Detail**: Rust Criterion 解析器解析出 `mean=0` 时没有做边界验证。如果 Criterion 输出包含 `time: [0.000 0.000 0.000]`，结果 NsPerOp=0，后续除零崩溃。
- **Suggested fix**: 解析后验证 mean > 0，否则标记为无效条目并计数到 skipped。

---

## 5. P2 — 性能

### PF-01 — ComputeStats double traverses sorted array
- **File**: stats.pas:230-277
- **Severity**: P2
- **Category**: 性能
- **Detail**: `ComputeStats` 对已排序数组进行两次遍历：一次计算 Mean+StdDev（遍历所有元素），另一次计算百分位数（也遍历或二分查找）。在单遍中可同时计算和收集百分位数。
- **Suggested fix**: 合并为单次遍历：计算 sum、sum_sq 的同时，采样存储百分位数插值所需的关键值。

### PF-02 — ShapiroWilkStatistic wrong formula
- **File**: stats.pas:389
- **Severity**: P2
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Shapiro-Wilk 检验的简化实现使用了近似的 W 统计量公式，但公式中的系数（a_i）计算错误——使用了 `TInvLookup` 作为系数替代实际 Shapiro-Wilk 系数。这不是有效的 Shapiro-Wilk 检验，仅是一个粗略的正态性启发式。
- **Suggested fix**: 要么实现正确的 Shapiro-Wilk 系数计算（`a = m^T V^{-1} / sqrt(m^T V^{-1} V^{-1} m)`），要么将方法重命名为 `HeuristicNormalityCheck` 并在文档中说明不精确性。

### PF-03 — ComputeApproximatePValue small df correction invalid
- **File**: stats.pas:357-358
- **Severity**: P2
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Hastings 近似法在小自由度（df < 30）下的修正系数是实验性的，不是标准统计方法。对于 df < 5 的情况，近似 p 值的误差可能 > 0.05。
- **Suggested fix**: 对 df < 5 的 t-分布使用精确数值积分，或至少添加警告级别的文档注释。

### PF-04 — ApproximateWelchTScore/EffectSize duplicate variance code
- **File**: stats.advanced.pas:619-704
- **Severity**: P2
- **Category**: 性能
- **Detail**: `ApproximateWelchTScore` 和 `EffectSize` 各自独立计算两组数据的方差（`StdDev` 两次调用）。如果在调用 ApproximateWelchTScore 后紧接着调用 EffectSize，方差被重复计算。
- **Suggested fix**: 设计一个同时返回 t-score 和 effect size 的函数，或在调用链中缓存方差计算结果。

### PF-05 — EffectSize Cohen's d unweighted pooled stddev
- **File**: stats.advanced.pas:698-699
- **Severity**: P2
- **Category**: 正确性（逻辑缺陷）
- **Detail**: Cohen's d 使用组间均值差除以合并标准差，但当前实现是未加权的（简单平均方差的平方根）而不是加权的（`sqrt(((n1-1)*s1² + (n2-1)*s2²)/(n1+n2-2))`）。对于样本量差异大的两组，未加权合并偏差。
- **Suggested fix**: 应使用加权合并标准差：`sqrt(((n1-1)*v1 + (n2-1)*v2)/(n1+n2-2))`。

### PF-06 — Percentile no input range validation
- **File**: stats.advanced.pas:310-330
- **Severity**: P2
- **Category**: 正确性（逻辑缺陷）
- **Detail**: 高级统计模块的 Percentile 方法没有验证 APercent 参数在 0-100 范围内。传入 200 或 -1 产生越界索引访问。
- **Suggested fix**: 在入口添加 `if (APercent < 0) or (APercent > 100) then raise EBenchError.Create(...)`。

### PF-07 — R2: GBridgeData unsynchronized write
- **File**: runner.pas:157-158
- **Severity**: P1
- **Category**: 性能
- **Detail**: `GBridgeData` 是全局变量，在并行基准执行时被写入。虽然当前设计约束是"同一时刻只有一个 suite 运行"，但全局可写变量意味着未来添加并发 suite 支持时需要大量重构。当前实现中，`ParallelBenchBridge` 函数读取 GBridgeData，而主线程写入的窗口期间没有任何锁保护。
- **Suggested fix**: 将桥接数据移入 TBenchRunner 实例，并通过参数传递。

### PF-08 — R8: ShouldRun allocates two strings per call
- **File**: runner.pas:656-660
- **Severity**: P2
- **Category**: 性能
- **Detail**: `ShouldRun` 每次调用分配两个新字符串（`LowerCase(AFilter)` 和 `LowerCase(AName)`，过滤字符串）。Filter 是固定的（`LoadConfigFromEnv` 时设置），小写版本应缓存。
- **Suggested fix**: 在 `SetFilter` 中预计算 `FFilterLower`，ShouldRun 直接使用。

### PF-09 — R9: TotalNs recomputed from mean*iters vs actual measurement
- **File**: runner.pas:720
- **Severity**: P2
- **Category**: 性能
- **Detail**: 结果集合中的 `TotalNs` 在某些路径下由 `Mean * Iterations` 反推，而不是使用实际测量汇总。可能累积浮点舍入误差。
- **Suggested fix**: 从实际测量收集 `TotalNs`，仅在非并行模式下作为 fallback 使用。

### PF-10 — R12: MinDurationNs parsed as Int64 not UInt64
- **File**: runner.pas:355
- **Severity**: P2
- **Category**: 正确性（逻辑缺陷）
- **Detail**: `FConfig.MinDurationNs` 声明为 UInt64，但环境变量解析使用 `StrToInt64Def`（返回 Int64）。如果用户设置 `NEXTPAS_BENCH_MIN_DURATION=99999999999999999999`（超出 Int64 但仍在 UInt64 范围内），解析器返回默认值而不是精确值。
- **Suggested fix**: 使用 `StrToUInt64Def` 或 UInt64 变体解析。

### PF-11 — R14: ExecuteEntry 160 lines, 3 code paths
- **File**: runner.pas:394-558
- **Severity**: P2
- **Category**: 性能
- **Detail**: `ExecuteEntry` 方法长达 160 行，包含三个独立代码路径（loop、parallel、sequential）。路径间通过 `Exit` 提前返回，但控制流不直观。每个路径的局部变量声明（LContext、LMemoryStats 等）也在全部作用域内。
- **Suggested fix**: 拆分为三个私有方法：`ExecuteLoopEntry`、`ExecuteParallelEntry`、`ExecuteSequentialEntry`。

### PF-12 — R15: Loop path BytesPerOp redundant check
- **File**: runner.pas:434-437
- **Severity**: P2
- **Category**: 性能
- **Detail**: `Result.BytesPerOp = 0` 检查在 loop 路径中冗余——BytesPerOp 刚初始化为 Default(TBenchResult) 的 0，永远不会非零。整个 if 块条件恒为 true。
- **Suggested fix**: 移除冗余条件，直接赋值。

### PF-13 — R17: Sequential path virtual dispatch per iteration
- **File**: runner.pas:525-533
- **Severity**: P2
- **Category**: 性能
- **Detail**: 顺序执行路径在每次迭代中调用 `Context.SetIterations(LIteration)`（虚拟方法调用）和函数调用。对于数百次迭代，虚拟调度的开销不可忽略。建议内联迭代计数到上下文中。
- **Suggested fix**: 使用局部变量递增迭代计数，最后一次调用 SetIterations。

### PF-14 — R25: NsPerOp uses wall-clock not sum of thread time
- **File**: parallel.pas:214-216
- **Severity**: P2
- **Category**: 性能
- **Detail**: 并行基准的 NsPerOp 使用 wall-clock 总耗时除以总迭代次数。但 wall-clock 包括了调度延迟和空闲时间，不是 true per-thread CPU 时间的加权平均。对于 I/O 密集或锁竞争高的基准，NsPerOp 被系统性高估。
- **Suggested fix**: 使用各线程的 CPU 时间之和，或同时报告 wall-clock NsPerOp 和 CPU NsPerOp。

### PF-15 — R22: Parallel thread measurement includes scheduling delay
- **File**: parallel.pas:128-143
- **Severity**: P2
- **Category**: 性能
- **Detail**: 工作线程的定时测量从 `platform_monotonic_ns` 获取，包括了线程调度和上下文切换的延迟。在高负载系统上，一次测量可能包含数毫秒的调度等待，导致结果方差增大。
- **Suggested fix**: 在并行路径中使用 thread CPU 计时器（如 `clock_gettime(CLOCK_THREAD_CPUTIME_ID)`）测量纯执行时间。

### PF-16 — R27: Thread objects leak on exception
- **File**: parallel.pas:241-244
- **Severity**: P2
- **Category**: 性能
- **Detail**: 并行基准执行时，如果某个线程抛异常，`FThreads` 数组中的线程对象不会被释放。`FreeOnTerminate=False` 时异常路径跳过清理。
- **Suggested fix**: 在 `try-finally` 块中释放所有线程对象。

### PF-17 — R30: CollectEntrySamples MinSamples=0 produces empty array
- **File**: runner.pas:617
- **Severity**: P2
- **Category**: 性能
- **Detail**: `MinSamples=0` 时 `CollectEntrySamples` 返回空数组，但调用方（ExecuteEntry）继续使用这个空数组计算统计量，产生除零或空统计结果。
- **Suggested fix**: 在入口验证 `AConfig.MinSamples >= 1`（默认值）。

### PF-18 — R32: Calibration loop 0-time exponential growth
- **File**: runner.pas:580-581
- **Severity**: P2
- **Category**: 性能
- **Detail**: 在校准循环中，如果迭代一次耗时 0ns（极快操作），校准因子增长失控。`LTargetIters := Ceil(LTargetIters * LFactor)` 在 LFactor 上无上限，可能一次迭代就从 1 跳到 10^6+。
- **Suggested fix**: 添加 `Ceil(LTargetIters * LFactor)` 的上限保护（如 MaxIterations）。

### PF-19 — RP19: GenerateCSS rebuilds on each ToHTML
- **File**: report.pas:554-569
- **Severity**: P2
- **Category**: 性能
- **Detail**: `GenerateCSS` 在每次 `ToHTML` 调用时重新生成完整的 CSS 字符串。CSS 是静态的（不依赖结果数据），应缓存或只生成一次。
- **Suggested fix**: 将 CSS 字符串缓存为类变量或实例变量，在首次调用时生成。

### PF-20 — RP20: BufferToString size estimation rough
- **File**: report.pas:122
- **Severity**: P2
- **Category**: 性能
- **Detail**: `BufferToString` 的初始缓冲区大小估算太粗略（`SetLength(LBuf, 4096)`）。对于大报告（>4KB），需要多次扩容。对于小报告，4096 可能浪费。
- **Suggested fix**: 根据报告内容估计更合理的初始大小，或使用 64KB 固定缓冲区。

---

## 6. P2 — 设计

### DS-01 — TBenchConfig.EnableParallel/ParallelThreads unused
- **File**: base.pas:84-85
- **Severity**: P3
- **Category**: 死代码
- **Detail**: `TBenchConfig` 中的 `EnableParallel` 和 `ParallelThreads` 字段存在但从未从 `TBenchConfig` 传递到执行引擎。并行配置由 `IBenchSuite` 的 `AddParallel` 方法在每个 entry 级别设置，直接写入 `TBenchEntry.ParallelThreads`。
- **Suggested fix**: 从 TBenchConfig 中移除这两个字段，或实现在 TBenchRunner.LoadConfigFromEnv 中读取它们。

### DS-02 — AddRange no setup/teardown overload
- **File**: intf.pas:115-116
- **Severity**: P2
- **Category**: 设计
- **Detail**: `IBenchSuite.AddRange` 方法没有接受 setup/teardown 回调的重载。使用 AddRange 添加多个参数化基准时，用户无法为每个参数值运行 setup/teardown。需要逐个调用 AddWithSetup。
- **Suggested fix**: 添加 `AddRange(const AName: string; AFunc: TBenchParamFunc; AValues: array of Int64; ASetup: TBenchSetupFunc; ATeardown: TBenchTeardownFunc)` 重载。

### DS-03 — IBenchSuite no Clear/Remove
- **File**: intf.pas:95-156
- **Severity**: P3
- **Category**: 设计
- **Detail**: `IBenchSuite` 接口没有 `Clear`（清空所有已注册 entry）或 `Remove(AName: string)`（按名称移除 entry）方法。用户无法在不销毁 suite 的情况下重新配置。
- **Suggested fix**: 添加 `Clear` 和 `RemoveByName` 方法声明。

### DS-04 — HasHeuristicDifference implicitly uses 95%
- **File**: stats.pas:290-315
- **Severity**: P3
- **Category**: 设计
- **Detail**: `HasHeuristicDifference` 硬编码了 95% 置信水平（p < 0.05），而不接受参数化。调用方不能配置显著性水平以适应不同场景（如 99% 用于性能关键比较）。
- **Suggested fix**: 添加 `AAlpha: Double = 0.05` 可选参数。

### DS-05 — ConfidenceInterval fallback silently ignores <90% level
- **File**: stats.advanced.pas:492-493
- **Severity**: P3
- **Category**: 设计
- **Detail**: 当请求的置信水平 < 90% 时，`ConfidenceInterval` 方法的查找表 fallback 路径静默使用 90% 的临界值而不通知调用方。这给出一个比请求更宽的置信区间，但调用方不知道。
- **Suggested fix**: 对 < 90% 的置信水平抛异常，或使用正态近似（z-score）计算。

### DS-06 — TAdvancedStats record with cache state can be implicitly copied
- **File**: stats.advanced.pas:55-61
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TAdvancedStats` 声明为 record，包含缓存的统计计算结果（如 LSortedData 动态数组）。record 赋值时浅拷贝指针，导致两个实例共享缓存状态，一个实例修改缓存影响另一个。
- **Suggested fix**: 将 TAdvancedStats 改为 class（与 TBenchStatsAnalyzer 一致），或实现 Copy-on-Write 机制。

### DS-07 — Sort is pass-through wrapper
- **File**: stats.pas:419-422
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBenchStatsAnalyzer.Sort` 直接调用 `SortDoubleArray`，是一个纯转发包装器，没有增加任何抽象价值。
- **Suggested fix**: 如果排序不是接口的必要部分，移除转发的 Sort 方法，让调用方直接使用 `SortDoubleArray`。

### DS-08 — BENCH_ENV_NO_MEMTRACK naming inconsistency
- **File**: base.pas:127
- **Severity**: P3
- **Category**: 设计
- **Detail**: 环境变量常量命名为 `BENCH_ENV_NO_MEMTRACK`（带 `NO` 前缀），但其他布尔环境变量使用正向命名（如 `BENCH_ENV_QUIET`）。语义是逆向的：`NO_MEMTRACK=1` 关闭内存跟踪。命名不一致易读性差。
- **Suggested fix**: 统一为正向命名（如 `BENCH_ENV_MEMTRACK=0` 关闭），或至少在文档中说明反转语义。

### DS-09 — R10: Env var parsing inconsistent (TryStrToInt64 vs StrToIntDef throws)
- **File**: runner.pas:348-355
- **Severity**: P3
- **Category**: 设计
- **Detail**: MaxIterations 使用 `TryStrToInt64`（静默失败），MinDurationNs 使用 `StrToInt64Def`（静默失败）但 MinSamples 使用 `StrToIntDef`（静默且返回 0）。三个环境变量解析使用了三种不同风格。
- **Suggested fix**: 统一使用 `TryStrToInt64` + 默认值，或统一使用 `StrToInt64Def`。

### DS-10 — R31: LoadConfigFromEnv no range validation
- **File**: runner.pas:337-344
- **Severity**: P3
- **Category**: 设计
- **Detail**: `LoadConfigFromEnv` 对环境变量值不做任何范围验证。MaxIterations=1、MinSamples=1000000、ParallelThreads=-5 等非法值都被静默接受。
- **Suggested fix**: 添加 `Min(Max(...))` 约束，或对每个字段添加 Setter 验证。

### DS-11 — A5: SaveTo* uses TextFile not abstract I/O
- **File**: bench.pas:637-701
- **Severity**: P2
- **Category**: 设计
- **Detail**: `SaveToJSON`、`SaveToHTML`、`SaveToTSV` 使用 FPC 的 `AssignFile`/`Rewrite`/`WriteLn`/`CloseFile` 文件 I/O，而不是抽象的 `IStream`。导致：
  - 无法保存到字符串（如网络发送）
  - 文件句柄泄漏风险（C01）
  - 平台相关性（路径分隔符、编码）
- **Suggested fix**: 添加接受 `IStream` 的重载方法，`SaveToFile` 包装为 `IStream` 的 `TFilestream`。

### DS-12 — A11: Facade exposes TBenchEntry internal
- **File**: bench.pas:19-39
- **Severity**: P2
- **Category**: 设计
- **Detail**: 主门面单元 `nextpas.core.bench.pas` 导出了 `TBenchEntry`（包含 Func/LoopFunc/ParamFunc 等内部实现细节）。用户看到的是面向实现的类型而非纯抽象接口。
- **Suggested fix**: 将 `TBenchEntry` 移入 `runner.pas` 或其他实现单元，门面只导出纯接口类型。

### DS-13 — R21: TBenchRunner not thread-safe
- **File**: runner.pas:1-810
- **Severity**: P2
- **Category**: 设计
- **Detail**: `TBenchRunner` 实例有可变状态（FFilter、FConfig、FResults、FParallelContexts），没有线程同步。如果多个 goroutine 同时调用 RunOne/ExecuteEntry，会导致 race condition 和数据竞争。
- **Suggested fix**: 添加文档说明线程安全约束，或实现无状态设计（所有状态通过参数传递）。

### DS-14 — R29: Context BytesPerOp last-value-wins
- **File**: runner.pas:540-541
- **Severity**: P2
- **Category**: 设计
- **Detail**: 在每次迭代后，如果用户调用了 `SetBytes` 或 `SetAllocs`，最后调用的值覆盖所有之前的值。对于在迭代中改变字节数的基准（如分段处理），last-value-wins 语义是错误的。
- **Suggested fix**: 支持累计模式（如 `AddBytes`/`AddAllocs`），与 `SetBytes`/`SetAllocs` 并存。

---

## 7. P2 — 测试改进（弱断言/flaky）

### TG-16 — ComputeStats test depends on Random sequence
- **File**: test_bench_stats:226
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 测试使用 `Random` 生成数据，但没有 seed 固定。不同 FPC 版本或运行环境的 Random 序列不同，可能导致统计断言在边缘情况下失败。
- **Suggested fix**: 使用固定 seed（`RandSeed := 42`）或使用完全确定的测试数据集。

### TG-17 — TestSignificantDifference same-dist flaky
- **File**: test_bench_stats:262-268
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 使用两组相同分布数据测试 `HasHeuristicDifference`，期望返回 False。但 5% 的显著性水平意味着 ~5% 的随机样本会给出差异，导致随机失败的 flaky 测试。
- **Suggested fix**: 使用大样本量（如 1000 而不是 50）以降低误报率，或使用固定随机 seed。

### TG-18 — GetElapsed time check flaky on high-load CI
- **File**: test_bench_runner:162-165
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 测试 `GetElapsed` 后等待 10ms 再检查耗时 `>= 10ms`。在高负载 CI 上，调度延迟可能使 `GetElapsed` 值远大于 10ms，但测试只验证下界不验证上界。
- **Suggested fix**: 同时验证上界（如 < 100ms），或使用统计方法多次测量后取中位数。

### TG-19 — Parallel observation test timing-dependent
- **File**: test_bench_integration:459-473
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 并行基准观察测试依赖 `Sleep` 固定时长。不同性能的机器上，线程可能完成得比预期快或慢，导致迭代次数与预期不符。
- **Suggested fix**: 使用基于实际测量结果的容差验证，而不是固定预期值。

### TG-20 — HasRegression test assumes fixed performance
- **File**: test_bench_integration:856-872
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 使用 `Add` 添加基准 + baseline 后，在同一个进程中立即运行 `HasRegression`。由于运行时的随机波动（调度、缓存），同一代码在同一进程中的两次运行可能产生不同结果。
- **Suggested fix**: 在调用 HasRegression 前插入足够大的性能差异（如故意在基准中插入 Sleep），确保检测稳定。

### TG-21 — BenchResetTimerOnly 10ms threshold
- **File**: test_bench_runner:399-433
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 测试使用 10ms 硬编码阈值判断 ResetTimer 是否生效。在 CI 或慢速机器上，10ms 可能小于上下文切换延迟，导致测试失败。
- **Suggested fix**: 使阈值可配置或基于实际系统校准。

### TG-22 — Parallel memtrack may miss dealloc count
- **File**: test_bench_memtrack:342-359
- **Severity**: P2
- **Category**: 测试改进（flaky）
- **Detail**: 并行内存跟踪测试验证 `AllocCount = FreeCount`。但由于 FreeOnTerminate 的时机问题（线程对象释放发生在统计快照之后），可能导致 FreeCount < AllocCount。
- **Suggested fix**: 在所有线程完成并释放后再收集统计，或使用屏障确保所有析构完成。

### TG-23 — BootstrapCI width check too loose
- **File**: test_bench_stats_advanced:224-242
- **Severity**: P2
- **Category**: 测试改进（弱断言）
- **Detail**: BootstrapCI 测试只验证置信区间宽度 > 0（即 `LUpper > LLower`），这是一个极弱的断言。可能 Bootstrap 实现返回了无意义的宽区间仍然通过。
- **Suggested fix**: 使用已知分布的样本（如 N(0,1)，n=1000），验证 95% CI 的宽度在预期范围内（~0.12-0.15）。

### TG-24 — Parallel skip Iterations=8 hardcoded
- **File**: test_bench_integration:514
- **Severity**: P2
- **Category**: 测试改进
- **Detail**: 并行 skip 测试硬编码了 `Iterations=8`。这个值在 4 线程环境上可能太短（每个线程 2 次迭代），测试的 skip 功能是否有效依赖于线程数量。
- **Suggested fix**: 使用与线程数成比例的迭代次数，或使用 `ParallelThreads * 1000` 确保每次迭代都有意义。

### TG-25 — FileRoundTrip /tmp collision
- **File**: test_bench_baseline:399-416
- **Severity**: P2
- **Category**: 测试改进
- **Detail**: 使用 `/tmp/test_baseline.json` 硬编码路径。并行测试会话中其他测试也可能使用同一个路径，造成文件冲突和竞态。
- **Suggested fix**: 使用 `GetTempDir` + 随机文件名（如 UUID）。

### TG-26 — Percentile no single/dual element
- **File**: test_bench_stats:129-168
- **Severity**: P2
- **Category**: 测试改进
- **Detail**: Percentile 测试用了 100 个元素的数据集，未包含单元素或双元素边界用例。对 1 个元素计算 P50 应返回该元素本身。
- **Suggested fix**: 添加 `[42]` 和 `[10, 20]` 的 Percentile 测试用例。

### TG-27 — InvalidParameters doesn't verify exception type
- **File**: test_bench_integration:634-696
- **Severity**: P2
- **Category**: 测试改进（弱断言）
- **Detail**: InvalidParameters 测试使用通用的 `try-except` 捕获"any exception"，不验证抛出的异常类型是 `EBenchError` 还是其他异常。如果代码在其他地方抛出 EDivByZero 或 EAccessViolation，测试也通过。
- **Suggested fix**: 验证 `on E: EBenchError do` 或检查异常消息。

### TG-28 — Speedup test doesn't verify range
- **File**: test_bench_parallel:108-121
- **Severity**: P2
- **Category**: 测试改进（弱断言）
- **Detail**: Speedup 测试只验证 `Speedup > 0`（永远正确），不验证 speedup 是否在合理范围内（如 1x-4x for 4 线程）。
- **Suggested fix**: 添加 `Speedup >= 1.0` 和 `Speedup <= ThreadCount * 2` 的下界和上界断言。

### TG-29 — FormatTime no boundary values
- **File**: test_bench_report:431-440
- **Severity**: P2
- **Category**: 测试改进
- **Detail**: `FormatTime` 测试未覆盖边界值：0ns、1ns、999ns（ns 边界）、1us（µs 边界）、1000us（ms 边界）。
- **Suggested fix**: 添加边界值测试（0, 1, 999, 1000, 999999, 1000000, 60e9 等）。

### TG-30 — FormatLargeNumber no negative/large
- **File**: test_bench_report:409-418
- **Severity**: P2
- **Category**: 测试改进
- **Detail**: `FormatLargeNumber` 测试只有 1234567 → "1,234,567" 这一个用例。未测试负数、零、极大值（>2^53）、极小值。
- **Suggested fix**: 添加负数、零、0.5、1e12、-999 等多样化的测试用例。

---

## 8. P3 — 风格/设计/文档

### ST-01 — ToConsole/ToJSON naming not uniform
- **File**: intf.pas:175-184
- **Severity**: P3
- **Category**: 设计
- **Detail**: `IBenchResults` 接口中的方法命名不一致：有 `ToConsole`、`ToJSON`、`ToHTML`、`ToTSV`（生成字符串），还有 `SaveToJSON`、`SaveToHTML`、`SaveToTSV`（保存到文件）。`ToConsole` 不是"转换为控制台"而是"输出到控制台"（内部调用 WriteLn），命名有歧义。
- **Suggested fix**: 将 `ToConsole` 重命名为 `PrintToConsole` 或 `WriteToConsole`，以体现其副作用。

### ST-02 — TBenchEntry exposes internal state
- **File**: intf.pas:81-93
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBenchEntry` 是一个 public record，其字段（Func、LoopFunc、ParamFunc、ParallelThreads 等）直接暴露给用户。用户可以通过直接修改 TBenchEntry 字段绕过 IBenchSuite 的约束（如跳过 Add 的验证逻辑）。
- **Suggested fix**: 使 TBenchEntry 在实现单元中私有化，公开只读接口。

### ST-03 — IBenchContext missing GetName
- **File**: intf.pas:33-65
- **Severity**: P3
- **Category**: 设计
- **Detail**: `IBenchContext` 接口不提供 `GetName` 方法。用户在基准函数中无法知道自己正在执行哪个基准的名称，这对带有 setup/teardown 的通用回调很不方便。
- **Suggested fix**: 添加 `function GetName: string;` 到 IBenchContext。

### ST-04 — Run no timeout/abort
- **File**: intf.pas:155
- **Severity**: P3
- **Category**: 设计
- **Detail**: `IBenchSuite.Run` 和 `IBenchResults.RunAll` 没有超时机制或中止功能。无限循环或极慢的基准会导致进程挂起。
- **Suggested fix**: 添加 `Run(ATimeoutMs: Cardinal = 0)` 重载，0=不超时。

### ST-05 — AddBaseline uses Double not TDuration
- **File**: intf.pas:122,147
- **Severity**: P3
- **Category**: 设计
- **Detail**: `AddBaseline` 方法的 `ANsPerOp: Double` 参数使用 Double 表示耗时，而不是 `TDuration` 类型。当其他 API 逐渐迁移到 `TDuration` 时，此处不一致。
- **Suggested fix**: 改为 `ANsPerOp: TDuration`，或添加 `TDuration` 重载。

### ST-06 — Missing batch add
- **File**: intf.pas
- **Severity**: P3
- **Category**: 设计
- **Detail**: 没有批量添加多个 baselines 的方法。用户必须逐个调用 AddBaseline，对每个调用进行单独的数据验证和数组增长逻辑。
- **Suggested fix**: 添加 `AddBaselines(const ABaselines: array of TBenchBaseline)`。

### ST-07 — Iterations Int64 vs Cores Int64
- **File**: base.pas:21,73
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBenchResult.Iterations` 声明为 `Int64`，`TBenchEnvironment.PhysicalCores` 也声明为 `Int64`。迭代次数理论上应为 UInt64（无负数），核心数应为 Integer（0..65535）。类型使用不当造成不必要的符号检查。
- **Suggested fix**: Iterations → UInt64, Cores → Integer/Word。

### ST-08 — AddLoop/Add returns IBenchSuite no constraint
- **File**: intf.pas:119
- **Severity**: P3
- **Category**: 设计
- **Detail**: `AddLoop` 和 `Add` 返回 `IBenchSuite` 接口（fluent builder 模式），但接口不约束用户必须在 Run 前完成所有 Add 调用。如果用户在 Run 后再次调用 Add，新添加的 entry 不被运行时执行（因为迭代计划已在 Run 时确定）。
- **Suggested fix**: 添加状态检查或在 Run 之后使 Add 抛异常。

### ST-09 — SaveToFile/LoadFromFile naming different
- **File**: baseline.pas
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBaselineManager` 的 `SaveToFile` 和 `LoadFromFile` 命名与其他模块一致，但 `SaveToJSON` 和 `LoadFromJSON` 的对称性不好——一个是序列化格式，一个是 I/O 动作。`SaveToFile` 隐含了 JSON 格式（无其他格式选项），而 `SaveToJSON` 输出字符串。
- **Suggested fix**: 统一命名：`SaveToFile`（保存）和 `LoadFromFile`（加载），内部使用 JSON；如需字符串序列化，用 `ToJSON`/`FromJSON`。

### ST-10 — DifferenceHeuristic as field not method
- **File**: base.pas:64
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBenchComparison.DifferenceHeuristic` 声明为 Double 字段（存储效应量阈值），但 `HasHeuristicDifference` 是独立函数。`DifferenceHeuristic` 字段名暗示它是一个方法或启发式名称，实际是一个阈值数值。命名和类型令人困惑。
- **Suggested fix**: 重命名为 `EffectSizeThreshold` 或从 TBenchComparison 中移除该字段（因为阈值是配置而不是比较结果的一部分）。

### ST-11 — Suite constructor no config object
- **File**: bench.pas:136
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TBenchSuite.Create` 不接受配置对象。用户必须通过 `TBenchSuite.Configure` 方法或环境变量设置配置。与其他框架（如 `TArgParser`）的构造模式不一致。
- **Suggested fix**: 添加 `Create(const AConfig: TBenchConfig)` 重载构造函数。

### ST-12 — TCrossLangEntry not in facade
- **File**: report.pas:13-18
- **Severity**: P3
- **Category**: 设计
- **Detail**: `TCrossLangEntry` 类型定义在 report.pas 中，但未在主门面 `nextpas.core.bench.pas` 中 re-export。使用主门面的用户无法访问此类型。
- **Suggested fix**: 在 facade 中添加 `TCrossLangEntry = nextpas.core.bench.report.TCrossLangEntry;` 别名。

### ST-13 — AddRange parameter description
- **File**: intf.pas:116
- **Severity**: P3
- **Category**: 文档
- **Detail**: `AddRange` 方法缺少详细的参数文档。`AName` 是基准名称模板（带 `{value}` 占位符），`AValues` 是参数数组，但无文档说明。用户需要阅读源码才知道用法。
- **Suggested fix**: 补充文档注释说明 AName 格式、AValues 范围和排序规则。

### ST-14 — R13: Boolean env vars only accept '1'
- **File**: runner.pas:365-367
- **Severity**: P3
- **Category**: 风格
- **Detail**: 布尔环境变量只接受 `'1'` 为 true。不识别 `'true'`、`'yes'`、`'on'` 等常见布尔表示。不一致且不友好。
- **Suggested fix**: 使用 `StrToBoolDef` 或识别 `'true'`/`'yes'`/`'on'`。

### ST-15 — RP18: EscapeHTML missing single quote
- **File**: report.pas:252-274
- **Severity**: P3
- **Category**: 风格
- **Detail**: EscapeHTML 转义了 `&`、`<`、`>`、`"` 但未转义单引号 `'`（`&apos;`）。虽然在 HTML 属性中用双引号时单引号可能不需要转义，但在属性值使用单引号或拼接时，未转义的单引号会破坏 HTML。
- **Suggested fix**: 添加 `'` → `&apos;` 转义。

### ST-16 — RP21: Skipped count mergeable into main loop
- **File**: report.pas:318-321
- **Severity**: P3
- **Category**: 风格
- **Detail**: 计算 skipped 条目数的循环与主输出循环分离，导致两次遍历结果数组。可以合并到主循环中一次性完成。
- **Suggested fix**: 在主循环中递增加 `LSkippedCount`，移除独立的 skipped 计数循环。

### ST-17 — RP22: Console header separator 100 vs 92 mismatch
- **File**: report.pas:298-299
- **Severity**: P3
- **Category**: 风格
- **Detail**: 控制台输出的标题分隔线使用 `StringOfChar('-', 100)`（100 个字符），但表头的实际宽度是 92 个字符。8 个字符的超出产生不必要的视觉偏移。
- **Suggested fix**: 统一使用 92 或根据表头总宽度动态计算。

### ST-18 — RP23: Console vs HTML column inconsistency
- **File**: report.pas:298-299 vs 608-616
- **Severity**: P3
- **Category**: 风格
- **Detail**: 控制台输出和 HTML 输出显示的列集合不一致。控制台有 bytes_per_op 和 allocs_per_op，HTML 缺少这列。
- **Suggested fix**: 统一两个输出格式的列集合。

### ST-19 — RP24: FormatTime uses ASCII 'us' not 'µs'
- **File**: report.pas:215-224
- **Severity**: P3
- **Category**: 风格
- **Detail**: `FormatTime` 使用 `'us'`（ASCII u+s）表示微秒，而非标准的 `'µs'`（Unicode 微符号 µ = U+00B5）或 `'μs'`（U+03BC）。这在科学输出中不够专业。
- **Suggested fix**: 如果输出终端支持 UTF-8，使用 `'µs'`；否则保留 `'us'` 并在文档中注明。

### ST-20 — RP25: JSON skipped results still output numerical fields
- **File**: report.pas:413-414
- **Severity**: P3
- **Category**: 风格
- **Detail**: JSON 输出中，被跳过的基准结果仍然包含 `nsPerOp`、`opsPerSec`、`bytesPerOp` 等数值字段（值=0）。JSON 消费者可能将 0 误解为有效测量值。
- **Suggested fix**: 对 skipped=true 的条目，仅输出 name、skipped、skipReason，省略所有数值字段。

### ST-21 — RP27: ToJSON unnecessary LJSON variable
- **File**: report.pas:375
- **Severity**: P3
- **Category**: 风格
- **Detail**: `ToJSON` 方法声明了一个 `LJSON: string` 变量然后立即返回，未使用该变量。死变量。
- **Suggested fix**: 移除未使用的 `LJSON` 变量声明。

### ST-22 — RP28: ToHTML method too long (~140 lines)
- **File**: report.pas:572-712
- **Severity**: P3
- **Category**: 风格
- **Detail**: `ToHTML` 方法约 140 行，混合了 HTML 模板生成、数据填充、条件逻辑。难以阅读和维护。
- **Suggested fix**: 拆分为 `GenerateHTMLHead`、`GenerateHTMLBody`、`GenerateHTMLFooter` 等方法。

### ST-23 — RP29: TLineBuffer redundant with TStringBuilder
- **File**: report.pas:96-133
- **Severity**: P3
- **Category**: 风格
- **Detail**: `TLineBuffer` record（行收集 + AddLine + GetLines）与 FPC `TStringBuilder` 功能重叠。`TStringBuilder` 可以直接管理行收集并具有更优的分配策略。
- **Suggested fix**: 移除 TLineBuffer，改用 TStringBuilder。

### ST-24 — RP31: BoxPlot constant samples width=0
- **File**: report.pas:790-910
- **Severity**: P3
- **Category**: 风格
- **Detail**: 当所有样本值相等（如全部 = 5.0）时，箱线图的盒子和触须宽度为零，SVG 输出退化为不可见的 0 宽度矩形。
- **Suggested fix**: 对常数数据集，生成固定宽度的占位矩形，并添加文字说明"Constant data"。

### ST-25 — FS9: Go bench name dash-strip corrupts hyphenated names
- **File**: xlang.pas:172-184
- **Severity**: P3
- **Category**: 风格
- **Detail**: Go 基准名称解析逻辑去除 `-<N>` 后缀（如 `BenchmarkFoo-8` → `BenchmarkFoo`），但使用简单的 `LastDelimiter('-', ...)` 匹配。如果基准名本身包含连字符（如 `BenchmarkFoo-Bar-8`），会错误地截断到 `BenchmarkFoo-Bar` 或 `BenchmarkFoo`。
- **Suggested fix**: 使用正则表达式匹配末尾的 `-\d+$`，而不是普通的 `LastDelimiter`。

### ST-26 — FS13: baseline timestamp fallback dead code
- **File**: baseline.pas:442-448
- **Severity**: P3
- **Category**: 风格
- **Detail**: baseline 加载中有一段"if timestamp fallback"逻辑，但条件是 `LTimestamp = 0`——而 LTmestamp 被初始化为 0 并且如果 JSON 中 timestamp 字段缺失，它保持 0。fallback 逻辑计算当前时间戳作为替代。但后续的 `SaveToFile` 始终在保存时写入新时间戳，所以 fallback 代码永远不会触发（从正常保存的文件加载时 timestamp 字段总是存在）。
- **Suggested fix**: 移除死代码，或在保存时可选写入 timestamp。

### ST-27 — FS17: Three save methods identical boilerplate
- **File**: bench.pas:637-700
- **Severity**: P3
- **Category**: 风格
- **Detail**: `SaveToJSON`、`SaveToHTML`、`SaveToTSV` 三个方法包含完全相同的文件 I/O 模板（`AssignFile`/`Rewrite`/`try`/`WriteLn`/`CloseFile`），只有中间的序列化调用不同。
- **Suggested fix**: 提取 `TSaveHelper.SaveToFile(APath, AContent: string)` 通用方法，三个 SaveTo 方法各一行调用。

---

## 统计总览

| 类别 | 数量 | 关键项 |
|------|------|--------|
| P0 — 测试质量 | 7 | T01-T07 断言恒真/逻辑错误 |
| P0 — 崩溃风险 | 1 | CR-01 IsEmptyOrComment 空字符串崩溃 |
| P0 — 正确性 | 1 | CR-02 CompareWithBaseline 无 comparison 计数 |
| P1 — 正确性 | 24 | CR-03 至 CR-26 逻辑缺陷 |
| P1 — 测试覆盖 | 15 | TG-01 至 TG-15 API 未测试 |
| P2 — 性能 | 20 | PF-01 至 PF-20 |
| P2 — 设计 | 14 | DS-01 至 DS-14 |
| P2 — 测试改进 | 15 | TG-16 至 TG-30 |
| P3 — 风格/文档 | 27 | ST-01 至 ST-27 |

**最高优先级**:
1. CR-01 (崩溃: IsEmptyOrComment 空字符串)
2. T01-T07 (测试断言恒真/逻辑错误 — 测试价值为零)
3. CR-11 (GetElapsed 无下溢保护 — 容器环境下必崩溃)
4. CR-17 (OpsPerSec Double-to-Int64 截断 — 极快操作数据错误)

---

## 修复进度追踪

> **更新日期**: 2026-06-23 (Round 4)

| 优先级 | 总数 | 已修复 | 已知限制 | 不修/推迟 | 剩余 |
|--------|------|--------|----------|-----------|------|
| P0 (T01-T07, CR-01, CR-02) | 9 | 9 | 0 | 0 | 0 |
| P1 正确性 (CR-03~CR-26) | 24 | 21 | 3 | 0 | 0 |
| P1 测试覆盖 (TG-01~TG-15) | 15 | 15 | 0 | 0 | 0 |
| P2 性能 (PF-01~PF-20) | 20 | 8 | 3 | 9 | 0 |
| P2 设计 (DS-01~DS-14) | 14 | **11** | 0 | **3** | 0 |
| P2 测试改进 (TG-16~TG-30) | 15 | **8** | 0 | **7** | 0 |
| P3 风格/设计/文档 (ST-01~ST-27) | 27 | **20** | 0 | **7** | 0 |
| **总计** | **124** | **96 (77%)** | **6 (5%)** | **22 (18%)** | **0** |

### 已知限制（不修）
- **CR-04**: PValue/HeuristicDifference 接口归属（设计决策）
- **CR-07**: Z-Score masking（小样本统计固有缺陷，Modified Z-Score 已提供替代）
- **CR-08**: BootstrapCI LCG 质量（近似计算，统计意义足够）
- **PF-02**: ShapiroWilkStatistic 简化实现（启发式，非精确统计）
- **PF-03**: ComputeApproximatePValue 小 df 修正（实验性系数）
- **PF-14/PF-15**: 并行定时包含调度延迟（wall-clock 测量固有限制）

### 不修/推迟（设计层面改进，非 bug）
- **PF-01**: ComputeStats 双遍历（影响极小，单遍改进需重写接口）
- **PF-04**: WelchTScore/EffectSize 重复方差（API 设计如此）
- **PF-07**: GBridgeData 无锁（已文档化约束，当前无并发 suite）
- **PF-09**: TotalNs 从 mean*iters 反推（设计选择，样本估计更准确）
- **PF-11**: ExecuteEntry 160 行拆分（重构成本 > 收益）
- **PF-13**: Sequential 虚拟调度（微优化，影响 < 1%）
- **PF-18**: 校准循环 0-time cap（已有 MaxIterations 兜底）
- **DS-08**: BENCH_ENV_NO_MEMTRACK 命名（改名破坏 CI 配置）
- **DS-11**: SaveTo* IStream 抽象（大重构）
- **DS-13**: TBenchRunner 线程安全（大重构）
- **TG-17**: TestSignificantDifference 已加 RandSeed（剩余 flaky 属统计固有属性）
- **TG-18**: GetElapsed 10ms 阈值（已足够宽松）
- **TG-19**: Parallel observation timing-dependent（已用小值）
- **TG-21**: BenchResetTimerOnly 10ms 阈值（已足够宽松）
- **TG-22**: Parallel memtrack deallocate 时机（线程生命周期固有限制）
- **TG-24**: Parallel skip Iterations=8（已正确，skip 行为确定性）
- **TG-25**: /tmp 路径已用 PID 唯一化
- **ST-04**: Run 超时机制（新功能，中等工作量）
- **ST-05**: AddBaseline TDuration 参数（破坏性变更）
- **ST-07**: Iterations UInt64 类型（破坏性变更）
- **ST-08**: AddLoop/Add 状态约束（设计决策）
- **ST-09**: SaveToFile/LoadFromFile 命名（破坏性变更）
- **ST-25**: Go 名称 dash-strip（已验证代码正确）

### Commits
```
aeec89068 fix+refactor(bench): P2/P3 batch — 13 items: BoxPlot constant, BootstrapCI tighten, EBenchInvalidParam verify, config constructor, timestamp fallback, docs
9bd6c3141 fix+test(bench): P2 source fixes — Cohen's d weighted pooled, thread leak, Percentile validation
3cf554ef2 refactor(bench): P2 design/style — env parsing, thread cache, JSON skipped, save dedup
2deff298e perf+style(bench): P2 report improvements — CSS cache, BufferToString sizing, µs
4dc0d54de feat(bench): API extensions — GetName, AddBytes, Clear, RemoveByName, AddRange+setup, AddBaselines, HasHeuristicDifferenceAt
1f506dd7f fix(bench): ST-14 boolean env vars accept 'true'/'yes'/'on'
52c6aa18d refactor(bench): DS-06 TAdvancedStats record→class, 48 tests passed
8db328f63 refactor(bench): ST-22 split ToHTML into 6 helper methods
6c667f344 refactor(bench): ST-01 rename ToConsole→PrintToConsole
e2581081c refactor(bench): ST-02 hide TBenchEntry from facade
c7570634f refactor(bench): ST-18 sync Console columns with HTML
47babd9fc refactor(bench): ST-23 replace TLineBuffer array with string wrapper
```