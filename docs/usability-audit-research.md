# bench 模块可用性改进调研报告

**日期**: 2026-07-05
**范围**: F-01 ~ F-19 共 19 个 findings
**方法**: 逐项根因分析 + Go/Rust 同类方案对标 + 修复策略评估

---

## 问题分类总览

| 类别 | 数量 | Findings |
|------|------|----------|
| 接口语义缺陷 | 3 | F-01, F-02, F-03 |
| API 冗余/不一致 | 4 | F-04, F-05, F-06, F-07 |
| 统计精度/语义 | 3 | F-08, F-12, F-13 |
| 错误提示优化 | 2 | F-09, F-10 |
| 执行引擎缺陷 | 2 | F-11, F-16 |
| 测试覆盖缺口 | 2 | F-14, F-15 |
| 性能/内存优化 | 3 | F-17, F-18, F-19 |

---

## 逐项调研

### F-01: TBenchLoopFunc 不支持 IBenchContext

**根因**: `TBenchLoopFunc = procedure(AN: Int64)` 是早期设计，当时认为 loop 模式只需要迭代次数。后来 `IBenchContext` 引入了 `SetBytes`/`SetAllocs`/`Skip`/`ResetTimer` 等能力，但 loop 签名无法扩展。

**影响**: 用户在 loop 模式下无法报告吞吐量（bytes/op）、内存分配（allocs/op），也无法跳过或重置计时器。`runner.pas:547` 已有注释标注此限制。

**Go 对标**: Go `testing.B` 的 `b.N` 是唯一的循环控制变量，但 `b.SetBytes()`/`b.ReportAllocs()` 仍然可用——因为 Go 的 benchmark 函数签名是 `func(b *testing.B)`，context 和循环控制统一在 `b` 上。

**Rust 对标**: Rust criterion 的 `Bencher` 提供 `iter(|| ...)` 闭包，内部自动控制迭代，但 `Bencher` 也提供 `bytes` 设置。

**修复策略**: 保持 `TBenchLoopFunc` 不变（向后兼容），新增 `TBenchLoopContextFunc = procedure(ACtx: IBenchContext; AN: Int64)` 签名，通过 `AddLoopWithContext` 方法注册。loop 模式内部根据函数类型选择调用路径。

**风险**: 低。新增 API，不修改现有行为。

**工作量**: 1h (intf.pas 类型定义 + bench.pas AddLoopWithContext + runner.pas ExecuteLoopEntry 分支 + 测试)

---

### F-02: CompareTwoResults 返回语义不对称

**根因**: `bench.pas:920` 中 `Result.BaselineName := ANameB`，但方法签名是 `CompareTwoResults(ANameA, ANameB)`，直觉上 A 是 "current"、B 是 "baseline"，但 `BaselineName` 设置为 B 是正确的——只是调用方需要记住参数顺序。

**影响**: 低。功能正确，但调用方可能混淆参数顺序。

**Go 对标**: Go benchstat 的 `Compare(baseline, current)` 明确命名。

**Rust 对标**: Rust criterion 的 `BenchmarkGroup::bench_function` 不直接比较两个结果。

**修复策略**: 在 `IBenchResults.CompareTwoResults` 的文档中明确标注 "ANameA = current, ANameB = baseline"。不修改签名（向后兼容）。

**风险**: 无。纯文档修正。

**工作量**: 0.5h

---

### F-03: TBenchBaseline 类型别名

**根因**: `intf.pas:37` 定义 `TBenchBaseline = TBaselineData`，是为了兼容早期 API（原名 `TBenchBaseline`，后改为 `TBaselineData` 以与 `base.pas` 一致）。

**影响**: 两个名字指同一类型，增加认知负担。

**修复策略**: 在 `intf.pas` 中添加 `{** @deprecated Use TBaselineData instead }` 注释，引导使用 `TBaselineData`。不删除别名（向后兼容）。

**风险**: 无。纯注释。

**工作量**: 0.25h

---

### F-04: 基线 API 冗余（5 种添加方式）

**根因**: 迭代积累的结果：
1. `AddBaseline(Name, Double)` — 最初版本
2. `AddBaseline(Name, TDuration)` — ST-05 便利重载
3. `AddBaselineData(TBaselineData)` — F-08 完整数据
4. `AddBaselines(array of TBaselineData)` — ST-06 批量
5. `LoadBaseline(path)` — 从文件加载

**影响**: 用户面对 5 种选择，不知道该用哪个。特别是 `AddBaseline(Name, Double)` 和 `AddBaselineData` 功能重叠。

**Go 对标**: Go 无 baseline API（用 benchstat 工具对比两个 `.txt` 文件）。

**Rust 对标**: Rust criterion 用 `BenchmarkGroup::bench_function` 单一入口，baseline 存储在 `.cargo/benchmarks/` 目录。

**修复策略**:
1. 保留 `AddBaseline(Name, Double)` 和 `AddBaseline(Name, TDuration)` 作为简单入口
2. 保留 `AddBaselineData(TBaselineData)` 作为完整入口
3. 保留 `AddBaselines(array)` 作为批量入口
4. 保留 `LoadBaseline(path)` 作为文件入口
5. 在每个方法的文档中说明使用场景

**风险**: 无。纯文档优化。

**工作量**: 0.5h

---

### F-05: SetTimeout 参数类型不一致

**根因**: `SetTimeout(ATimeoutMs: Cardinal)` 使用 `Cardinal`（32 位无符号），但 `TBenchEntry.TimeoutMs: Int64` 使用 `Int64`（64 位有符号）。两处都表示毫秒超时，但类型不同。

**影响**: 低。`Cardinal` 最大 ~4.3 billion ms ≈ 49.7 天，实际不会超过。但类型不一致增加认知负担。

**修复策略**: 统一为 `Int64`。`SetTimeout` 签名改为 `SetTimeout(ATimeoutMs: Int64)`。内部 `TBenchConfig.TimeoutMs` 也改为 `Int64`。

**风险**: 低。`Cardinal` → `Int64` 是放宽约束，向后兼容。

**工作量**: 0.5h (intf.pas + bench.pas + base.pas)

---

### F-06: SetFilter 未说明 glob 支持

**根因**: `runner.pas:934` 实现了 glob 匹配（`*` 和 `?`），但 `SetFilter` 接口文档没有说明。

**影响**: 用户不知道可以用 `SetFilter('Sort*')` 过滤所有以 Sort 开头的 benchmark。

**Go 对标**: Go `-run` 参数用正则表达式，文档明确说明。

**修复策略**: 在 `IBenchSuite.SetFilter` 和 `IBenchResults` 相关文档中添加 glob 支持说明。

**风险**: 无。纯文档。

**工作量**: 0.25h

---

### F-07: SetTimeout 参数类型与 TBenchEntry.TimeoutMs 不一致

**根因**: 同 F-05。

**修复策略**: 同 F-05，合并处理。

---

### F-08: ComputeApproximatePValue 精度语义不明确

**根因**: `stats.pas:365-374` 已有文档标注"启发式评级，非精确 p-value"，但方法名 `ComputeApproximatePValue` 中的 "Approximate" 不够醒目。

**影响**: 用户可能误认为这是精确的 p-value，用于严肃的统计决策。

**Rust 对标**: Rust criterion 用 Mann-Whitney U 作为默认检验，文档明确说明。

**修复策略**: 已有文档标注，无需修改代码。可选：在 `ComputeStats` 返回的 `TBenchStats` 中增加 `PValueMethod: string` 字段标注方法。

**风险**: 无。

**工作量**: 0h（已有文档）或 0.5h（增加方法字段）

---

### F-09: GetByName 异常消息不列出可用名称

**根因**: `bench.pas:833` 的异常消息 `'Benchmark result not found: "%s"'` 没有列出可用名称，因为遍历所有名称会增加字符串拼接开销。

**影响**: 调试时需要手动查看所有结果名称。

**修复策略**: 在异常消息中添加 "Available: [name1, name2, ...]"（最多列出前 5 个）。仅在异常路径执行，不影响正常性能。

**风险**: 无。

**工作量**: 0.25h

---

### F-10: 空 entries 时只警告不抛异常

**根因**: `bench.pas:636` 用 `WriteLn(StdErr, 'WARNING: ...')` 而非抛异常，是设计选择——空 entries 不一定是错误（可能是条件过滤的结果）。

**Go 对标**: Go 空 benchmark 不警告也不报错。

**修复策略**: 保持警告行为（不抛异常），但增加 `IBenchResults.HasWarnings` 方法，让调用方可以程序化检查。

**风险**: 低。

**工作量**: 0.5h

---

### F-11: CollectEntrySamples 内部无 timeout 机制

**根因**: `runner.pas:833-904` 的 `CollectEntrySamples` 循环中没有检查 timeout。`RunOne` 的 timeout 检查在校准后、采样前（`runner.pas:996-1003`），但采样阶段本身可能耗时很长。

**影响**: 如果单次采样耗时超过 timeout（例如用户函数阻塞），benchmark 会超时完成但不会被标记为 skipped。

**Go 对标**: Go `testing.B` 用 `-benchtime` 控制总时间，没有 per-benchmark timeout 概念。

**Rust 对标**: Rust criterion 用 `measurement_time` 控制测量时间，但不中断正在执行的测量。

**修复策略**: 在 `CollectEntrySamples` 的每次 `ExecuteEntry` 后增加 timeout 检查。如果超时，截断采样数组并标记结果为 skipped。

**风险**: 低。只增加检查点，不修改核心逻辑。

**工作量**: 0.5h

---

### F-12: BootstrapCI PRNG 种子碰撞

**根因**: `stats.advanced.pas:576-579` 用 `platform_monotonic_ns` 作为种子，快速连续调用时可能产生相同种子。

**影响**: 低。Bootstrap CI 在 benchmark 场景中通常只调用一次，且即使种子相同，结果也只是略微偏差。

**修复策略**: 增加全局计数器作为种子的一部分：`LSeed := platform_monotonic_ns xor (GBootstrapCallCount shl 32)`。

**风险**: 无。

**工作量**: 0.25h

---

### F-13: GeometricMean 非正 ratio 返回 0.0

**根因**: `stats.pas:673` 返回 `0.0` 作为哨兵值，但调用方（`bench.pas:1108`）没有检查。

**影响**: 矩阵报告中显示 "0.00x" 而非更明确的错误标记。

**修复策略**: 改为返回 `NaN` 而非 `0.0`。`NaN` 在浮点运算中自然传播，报告层已有 `IsDoubleNaN` 检查。

**风险**: 低。需同步检查所有 `GeometricMean` 调用方。

**工作量**: 0.25h

---

### F-14: 无 timeout 组合测试

**根因**: `test_bench_integration` 有 `TestTBenchSuite_Timeout` 测试 suite-level timeout，但没有测试 per-benchmark timeout 和 suite-level timeout 的组合行为。

**影响**: 无法验证 timeout 机制在边界条件下的正确性。

**修复策略**: 新增 `TestTimeout_Combined` 测试：同时设置 suite timeout 和 per-benchmark timeout，验证行为正确。

**风险**: 无。纯测试。

**工作量**: 1h

---

### F-15: 无 ThreadCount=1 退化测试

**根因**: `test_bench_parallel` 测试了 `ThreadCount=2` 和 `ThreadCount=4`，但没有测试 `ThreadCount=1` 的退化路径。

**影响**: 无法验证 `ThreadCount=1` 时并行逻辑正确退化为串行。

**修复策略**: 在 `test_bench_parallel` 中新增 `TestThreadCount1` 测试。

**风险**: 无。纯测试。

**工作量**: 0.5h

---

### F-16: GBridgeRunner 全局变量并发不安全

**根因**: `runner.pas:201` 的 `GBridgeRunner` 全局变量 + `ParallelBenchBridge` 回调，是因为 `RunParallelBench` 的回调签名不支持用户数据参数。当前文档约束 "NOT thread-safe"（`runner.pas:70-83`）。

**影响**: 如果两个 `TBenchSuite` 并发 `Run()`，`GBridgeRunner` 会被覆盖，导致数据竞争。

**Go 对标**: Go `testing.B` 每个 benchmark 独立状态，无全局变量。

**修复策略**: 在 `TBenchRunner.RunOne` 入口增加并发断言：用 `InterlockedCompareExchange` 检查 `GBridgeRunner` 是否已被占用，如果是则抛异常。

**风险**: 低。只增加检查，不修改核心逻辑。

**工作量**: 0.5h

---

### F-17: ComputeStats 百分位数 O(7 log n) 可优化为 O(n)

**根因**: `stats.pas:278-285` 对排序后数据调用 7 次 `Percentile`（P5, P25, P50, P75, P95, P99 + IQR），每次 O(log n) 二分查找。

**影响**: 对于典型 benchmark 数据（30-1000 样本），O(7 log n) ≈ O(35-70)，与 O(n) 差距不大。但理论上可以优化。

**Rust 对标**: Rust criterion 用 `rayon` 并行排序+采样。

**修复策略**: 新增 `ComputePercentiles` 函数，单遍扫描计算所有百分位数。对小数组（<100）效果不明显，对大数组（>1000）有 ~2x 提升。

**风险**: 低。新增函数，不修改现有逻辑。

**工作量**: 1h

---

### F-18: TBaselineManager record 浅拷贝

**根因**: `baseline.pas:48-50` 的 `TBaselineManager` 是 record 含动态数组，赋值是浅拷贝。F-012 注释已标注。

**影响**: 如果用户 `var B := manager` 后修改 B，A 也会被改。但这是 Pascal record 的标准行为，用户应有预期。

**Rust 对标**: Rust 的所有权系统天然防止此问题。

**修复策略**: 已有注释标注。可选：增加 `Clone` 方法做深拷贝。

**风险**: 无。

**工作量**: 0.5h

---

### F-19: AtomicInc64 CAS 循环

**根因**: `memtrack.pas:115-137` 用 CAS 循环实现原子加减，是因为 FPC 没有直接的 `InterlockedAdd64` 内置函数。

**影响**: 在高争用场景下 CAS 可能重试多次，但 benchmark 场景通常不会高争用。

**Go 对标**: Go 用 `atomic.AddInt64`，底层是 CPU 原子指令。

**修复策略**: 检查 FPC 是否有 `InterlockedAdd64`（FPC trunk 可能有）。如果有，替换 CAS 循环。如果没有，保持现状。

**风险**: 低。需确认 FPC 版本支持。

**工作量**: 0.5h（含调研 FPC 支持）

---

## 风险矩阵

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| API 签名变更破坏向后兼容 | **中** | P2-5/P2-6 只放宽约束（Cardinal→Int64），不收紧 |
| Timeout 机制变更影响现有行为 | **低** | 只增加检查点，不修改核心校准/采样逻辑 |
| 新增测试发现隐藏 bug | **低** | 新增测试是验证正确性，不是修改行为 |
| GeometricMean 返回 NaN 影响报告 | **低** | 报告层已有 NaN 检查，改为显示 "N/A" 而非 "0.00x" |

---

## 修复策略总结

### 策略 A: 最小修改（只修 P2，P3 按需）

- 工作量: ~5h
- 风险: 低
- 覆盖: 7/19 findings

### 策略 B: 全面修复（P2 + P3 全修）

- 工作量: ~8h
- 风险: 低-中
- 覆盖: 19/19 findings

### 策略 C: 分阶段修复（P2 先行，P3 随使用场景驱动）

- 工作量: ~5h + 按需
- 风险: 低
- 覆盖: 7/19 findings + 按需

**建议**: 策略 B（全面修复），因为所有 findings 风险都低，且改动范围清晰。
