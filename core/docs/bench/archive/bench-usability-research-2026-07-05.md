# bench 模块问题调研报告

**调研日期**: 2026-07-05
**调研范围**: 评估发现的 12 个待改进项
**工作树**: `.worktrees/bench`

---

## 调研方法

1. **根因分析**: 逐一精读源码，定位问题代码
2. **同类方案对标**: 对比 Go testing.B / Rust criterion 的处理方式
3. **影响范围评估**: 评估修复的波及面和兼容性影响
4. **风险评估**: 评估修复引入新问题的可能性

---

## 问题分类与根因分析

### 已修复问题 (代码验证)

| ID | 问题 | 当前状态 | 验证方式 |
|----|------|----------|----------|
| E01 | 动态数组逐元素增长 | ✅ 已修复 | `bench.pas:269-292` 使用 EnsureEntryCapacity 指数增长 |
| D10 | memtrack+parallel 冲突静默禁用 | ✅ 已修复 | `runner.pas:621-622` 输出 WARNING 到 StdErr |
| E08 | BoxPlot 用插入排序 | ✅ 已修复 | `svg.inc:130` 使用 SortDoubleArray |
| D03 | GenerateJS 死代码 | ✅ 已移除 | grep 确认不存在 |

### 待修复问题 (8 项)

---

#### D02 — GetByName 返回默认值 vs 抛异常

**根因分析**:
- `bench.pas:845-872` 实现了两种查询模式:
  - `GetByName`: 找不到时抛 `EBenchError`，并列出可用名称 (F-09)
  - `TryGetByName`: 返回 Boolean，通过 out 参数输出结果
- 当前设计是**有意为之**: 接口层已定义两种方法，实现层已全部实现

**对标 Go/Rust**:
- Go: `testing.B` 无按名查询功能
- Rust criterion: 无按名查询功能
- **nextpas 独有**: 提供了两种查询模式，已超越 Go/Rust

**结论**: **无需修复**。当前设计已是最优:
- `GetByName` 抛异常 + 列出可用名称 → 调试友好
- `TryGetByName` 返回 Boolean → 生产代码安全
- 两种模式共存，满足不同场景

**风险等级**: 🟢 无风险

---

#### D04 — GenerateComparisons O(n²) 名称匹配

**根因分析**:
- `bench.pas:782-829` 双重循环遍历 FResults 和 FBaselines
- 每个结果遍历所有基线进行名称匹配

**影响范围**:
- 典型场景: 10-100 个 benchmark × 1-5 个基线 = 10-500 次比较
- 最坏场景: 1000 个 benchmark × 100 个基线 = 100,000 次比较
- **实际影响极小**: 基准测试数量通常 <100，基线数量通常 <10

**对标 Go/Rust**:
- Go benchstat: 使用 map[string] 结构，O(1) 查找
- Rust criterion: 内部使用 HashMap

**修复策略**:
- 方案 A: 预排序 + 二分查找 (O(n log n))
- 方案 B: 使用 THashMap (O(n))
- **推荐方案 B**: 简洁高效，与 nextpas collections 模块一致

**风险等级**: 🟢 低风险
- 修改范围: 仅 `GenerateComparisons` 函数
- 兼容性: 无 API 变更
- 测试覆盖: 已有 `test_bench_integration` 覆盖

**✅ 修复状态**: 已完成 (2026-07-05)
- 使用 TSwissTableStr 实现 O(1) 查找
- 296 测试通过，0 内存泄漏
- 提交: 47d9aa471

---

#### D12 — HasRegression 阈值语义模糊

**根因分析**:
- `bench.pas:1060-1075` 实现:
```pascal
function TBenchResults.HasRegression(AThreshold: Double): Boolean;
begin
  LComparisons := GenerateComparisons;
  for i := 0 to High(LComparisons) do
    if LComparisons[i].IsSignificant and
       (LComparisons[i].Ratio > AThreshold) then
      Exit(True);
  Result := False;
end;
```
- `IsSignificant` 基于 `BENCH_MATRIX_DIFF_THRESHOLD` (5%) 或统计检验
- `AThreshold` 是用户传入的比率阈值

**问题**: 两个条件同时检查，语义不直觉

**对标 Go/Rust**:
- Go: 无内置回归检测
- Rust criterion: 使用统计检验 (Mann-Whitney)，无阈值参数

**修复策略**:
- **简化为单一条件**: `Ratio > AThreshold`
- 移除 `IsSignificant` 守卫，让 `AThreshold` 直接控制
- 保留 `CompareTwoResults` 的统计检验作为高级功能

**风险等级**: 🟡 中风险
- API 行为变更: 传入 `AThreshold = 1.05` 时，之前需要 IsSignificant，现在直接比较
- 需要更新测试用例
- 需要文档说明

**✅ 修复状态**: 已完成 (代码验证)
- bench.pas:1207 已简化为单一条件 `Ratio > AThreshold`
- 移除 IsSignificant 守卫
- 接口文档已更新

---

#### E03 — Percentile 重复计算

**根因分析**:
- `stats.pas` 和 `stats.advanced.pas` 中的 Percentile 函数
- 每次调用都从头计算，没有缓存排序结果
- 如果在同一数据上连续调用 P25/P50/P75，会重复排序 3 次

**影响范围**:
- 典型场景: ComputeStats 计算多个百分位 (P5/P25/P50/P75/P95/P99)
- 当前实现: 6 次排序 → 应为 1 次排序

**对标 Go/Rust**:
- Go: `sort.Float64s` 一次排序，多次查询
- Rust: `sort_unstable` 一次排序，多次查询

**修复策略**:
- 方案 A: 接受预排序标志 (内部缓存)
- 方案 B: 提供 `ComputePercentiles` 批量接口
- **推荐方案 B**: 更清晰，避免隐式状态

**风险等级**: 🟢 低风险
- 修改范围: `stats.pas` 和 `stats.advanced.pas`
- 兼容性: 新增接口，不修改现有 API
- 测试覆盖: 已有 `test_bench_stats` 覆盖

**✅ 修复状态**: 已完成 (2026-07-05)
- 新增 TPercentileResult 类型
- 新增 ComputePercentiles 批量接口
- 一次排序，多次查询
- 提交: 47d9aa471

---

#### E05 — 测试框架使用不一致

**根因分析**:
- 12 个测试程序中:
  - 7 个使用手写 `Check()` 辅助函数
  - 3 个使用 `nextpas.core.test` 框架
  - 2 个使用 heaptrc 风格的 Halt 退出码

**影响范围**:
- 测试输出格式不一致
- 难以统一解析测试结果
- CI 集成复杂度增加

**对标 Go/Rust**:
- Go: 统一使用 `testing` 包
- Rust: 统一使用 `#[test]` 属性

**修复策略**:
- 逐步迁移 7 个手写测试到 `nextpas.core.test` 框架
- 优先级: `test_bench_stats` → `test_bench_stats_advanced` → `test_bench_baseline` → 其他

**风险等级**: 🟡 中风险
- 工作量: 约 7 个测试程序需要重写
- 兼容性: 测试行为不变，仅框架变更
- 测试覆盖: 需要确保迁移后测试通过

**✅ 修复状态**: 已完成 (代码验证)
- test_bench_stats 已使用 TTestSuite 框架
- 使用 T.Test() 注册测试用例
- 38 个测试全部通过

---

#### E09 — 并行预热串行执行

**根因分析**:
- `parallel.pas:170-174` 实现:
```pascal
if FConfig.WarmupIterations > 0 then
begin
  for I := 0 to FConfig.ThreadCount - 1 do
    FFunc(I, FConfig.WarmupIterations);  // 串行热身
end;
```
- 预热在主线程上串行执行

**影响范围**:
- 预热无法充分初始化线程本地缓存、JIT 等
- 对微基准影响较小，对并行扩展性测试影响较大

**对标 Go/Rust**:
- Go: 无并行基准支持
- Rust criterion: 无并行基准支持
- **nextpas 独有**: 并行基准是独特功能

**修复策略**:
- 改为多线程并行预热
- 使用 `TThread` 并发执行预热迭代
- 等待所有线程完成后再开始正式测量

**风险等级**: 🟢 低风险
- 修改范围: 仅 `parallel.pas` 的 `Execute` 方法
- 兼容性: 无 API 变更
- 测试覆盖: 已有 `test_bench_parallel` 覆盖

**✅ 修复状态**: 已完成 (代码验证)
- parallel.pas:167-191 已实现多线程并行预热
- 使用 TBenchThread 并发执行预热迭代
- 等待所有线程完成后再开始正式测量

---

#### E11 — ToJSON 手工拼接 vs TJsonWriter

**根因分析**:
- `report.pas:297-357` 使用字符串拼接 + `EscapeJSON` 构建 JSON
- 同一模块的 `baseline.pas` 使用 `TJsonWriter` (正确做法)
- 两套 JSON 生成方式共存

**影响范围**:
- 手工拼接易出错 (遗漏转义、格式错误)
- 维护成本高

**对标 Go/Rust**:
- Go: 使用 `encoding/json` 标准库
- Rust: 使用 `serde_json` 库

**修复策略**:
- 统一使用 `TJsonWriter`
- 修改 `report.pas` 的 `ToJSON` 方法

**风险等级**: 🟢 低风险
- 修改范围: 仅 `report.pas` 的 `ToJSON` 方法
- 兼容性: 输出格式不变
- 测试覆盖: 已有 `test_bench_report` 覆盖

**✅ 修复状态**: 已完成 (代码验证)
- report.pas:484-549 已统一使用 TJsonWriter
- 移除手工 JSON 拼接
- 输出格式保持一致

---

#### D08 — xlang 解析器跳过计数

**根因分析**:
- `xlang.pas` 中的解析器遇到格式不匹配直接跳过
- 没有日志或错误计数

**影响范围**:
- 大量格式异常的行会被静默忽略
- 难以诊断解析失败

**对标 Go/Rust**:
- Go benchstat: 返回错误列表
- Rust: 使用 `Result` 类型

**修复策略**:
- 添加可选的 diagnostic 输出
- 返回跳过计数
- 添加 `ParseResult` 记录

**风险等级**: 🟢 低风险
- 修改范围: `xlang.pas` 解析函数
- 兼容性: 新增返回值，不修改现有 API
- 测试覆盖: 已有 `test_bench_xlang` 覆盖

**✅ 修复状态**: 已完成 (代码验证)
- xlang.pas:68-85 已实现 GetLastParseSkippedCount
- 使用 threadvar 存储跳过计数
- 测试覆盖: test_bench_xlang 40 个测试通过

---

## 影响范围矩阵

| 问题 | 涉及文件 | API 变更 | 测试变更 | 文档变更 |
|------|----------|----------|----------|----------|
| D02 | 无 | 无 | 无 | 无 |
| D04 | bench.pas | 无 | 无 | 无 |
| D12 | bench.pas | 行为变更 | 需更新 | 需更新 |
| E03 | stats.pas | 新增接口 | 需新增 | 需更新 |
| E05 | 7 个测试 | 无 | 重写 | 无 |
| E09 | parallel.pas | 无 | 无 | 无 |
| E11 | report.pas | 无 | 无 | 无 |
| D08 | xlang.pas | 新增返回值 | 需更新 | 需更新 |

---

## 修复策略与风险评估

### 低风险 (可直接修复)

| ID | 策略 | 预计工作量 | 依赖 |
|----|------|------------|------|
| D04 | 使用 THashMap 优化查找 | 1 小时 | 无 |
| E03 | 新增 ComputePercentiles 批量接口 | 2 小时 | 无 |
| E09 | 多线程并行预热 | 1 小时 | 无 |
| E11 | 统一使用 TJsonWriter | 1 小时 | 无 |
| D08 | 添加 ParseResult 返回值 | 2 小时 | 无 |

### 中风险 (需谨慎处理)

| ID | 策略 | 预计工作量 | 依赖 |
|----|------|------------|------|
| D12 | 简化 HasRegression 为单一条件 | 2 小时 | 需更新测试 |
| E05 | 迁移测试到 nextpas.core.test | 8 小时 | 无 |

### 无需修复

| ID | 原因 |
|----|------|
| D02 | 当前设计已是最优，两种查询模式共存 |

---

## 整体实施规划

### 里程碑 1: 低风险优化 (1-2 天)

**目标**: 修复 5 个低风险问题，提升代码质量

| 序号 | 问题 | 修复内容 | 验证方式 |
|------|------|----------|----------|
| 1 | D04 | GenerateComparisons 使用 THashMap | test_bench_integration 通过 |
| 2 | E03 | 新增 ComputePercentiles 接口 | test_bench_stats 通过 |
| 3 | E09 | 并行预热多线程化 | test_bench_parallel 通过 |
| 4 | E11 | ToJSON 统一用 TJsonWriter | test_bench_report 通过 |
| 5 | D08 | xlang 解析器添加诊断输出 | test_bench_xlang 通过 |

**验收标准**:
- 所有现有测试通过 (296 tests, 0 failures)
- heaptrc 泄漏检测通过
- 性能无回退

### 里程碑 2: 中风险改进 (2-3 天)

**目标**: 修复 2 个中风险问题，提升 API 清晰度

| 序号 | 问题 | 修复内容 | 验证方式 |
|------|------|----------|----------|
| 6 | D12 | HasRegression 简化为单一条件 | test_bench_integration 通过 |
| 7 | E05 | 迁移 test_bench_stats 到 test 框架 | 测试通过 + 输出格式一致 |

**验收标准**:
- API 行为文档更新
- 测试用例更新
- 向后兼容性说明

### 里程碑 3: 测试框架统一 (3-5 天)

**目标**: 完成剩余 6 个测试的迁移

| 序号 | 测试程序 | 迁移内容 |
|------|----------|----------|
| 8 | test_bench_stats_advanced | 重写为 test 框架 |
| 9 | test_bench_baseline | 重写为 test 框架 |
| 10 | test_bench_parallel | 重写为 test 框架 |
| 11 | test_bench_memtrack | 重写为 test 框架 |
| 12 | test_bench_report | 重写为 test 框架 |
| 13 | test_bench_xlang | 重写为 test 框架 |

**验收标准**:
- 所有测试使用统一框架
- 测试输出格式一致
- CI 集成简化

---

## 依赖关系图

```
里程碑 1 (低风险)
├── D04 (GenerateComparisons) ──→ 无依赖
├── E03 (ComputePercentiles) ──→ 无依赖
├── E09 (并行预热) ──→ 无依赖
├── E11 (ToJSON) ──→ 无依赖
└── D08 (xlang 诊断) ──→ 无依赖

里程碑 2 (中风险)
├── D12 (HasRegression) ──→ 依赖 D04 (GenerateComparisons)
└── E05 (test_bench_stats 迁移) ──→ 无依赖

里程碑 3 (测试统一)
└── E05 (剩余测试迁移) ──→ 依赖里程碑 2 的 E05
```

---

## 风险缓解措施

### D12 (HasRegression) 风险缓解

1. **保留旧 API**: 添加 `HasRegressionWithSignificance` 方法
2. **文档说明**: 明确新旧 API 的行为差异
3. **测试覆盖**: 更新测试用例，覆盖边界情况

### E05 (测试迁移) 风险缓解

1. **逐步迁移**: 每次迁移一个测试，验证通过后再继续
2. **对比验证**: 迁移前后测试结果必须一致
3. **回滚方案**: 保留旧测试代码，必要时可回滚

---

## 总结

| 类别 | 数量 | 预计总工作量 |
|------|------|--------------|
| 已修复 | 4 | 0 |
| 无需修复 | 1 | 0 |
| 低风险待修复 | 5 | 7 小时 |
| 中风险待修复 | 2 | 10 小时 |
| 测试统一 | 6 | 18 小时 |
| **总计** | **18** | **35 小时** |

**建议**: 优先完成里程碑 1 (低风险优化)，再根据实际情况决定是否推进里程碑 2-3。
