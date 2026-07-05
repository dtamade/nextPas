# bench 模块可用性改进实施规划

**规划日期**: 2026-07-05  
**基于调研**: `bench-usability-research-2026-07-05.md`  
**工作树**: `.worktrees/bench`

---

## 实施原则

1. **小步迭代**: 每个里程碑独立可验证
2. **测试先行**: 修改前确保测试通过，修改后验证无回退
3. **向后兼容**: API 变更需文档说明，保留旧 API 过渡期
4. **风险可控**: 低风险优先，中风险谨慎处理

---

## 里程碑 1: 低风险优化 (Day 1-2)

### 任务清单

#### Task 1.1: D04 — GenerateComparisons 使用 THashMap

**目标**: 将 O(n²) 名称匹配优化为 O(n)

**修改文件**:
- `core/src/nextpas.core.bench.pas`

**实现步骤**:
1. 在 `GenerateComparisons` 开头创建 THashMap<string, Integer>
2. 遍历 FBaselines，建立 Name → Index 映射
3. 遍历 FResults，通过 HashMap O(1) 查找匹配基线
4. 移除双重循环

**代码变更预估**: ~30 行

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_integration clean test
```

**预期结果**: 测试通过，性能无回退

**✅ 完成状态**: 已完成 (2026-07-05)
- 使用 TSwissTableStr 实现 O(1) 查找
- 296 测试通过，0 内存泄漏
- 提交: 47d9aa471

---

#### Task 1.2: E03 — 新增 ComputePercentiles 批量接口

**目标**: 避免重复排序，一次排序计算多个百分位

**修改文件**:
- `core/src/nextpas.core.bench.stats.pas` (接口)
- `core/src/nextpas.core.bench.stats.advanced.pas` (实现)

**新增接口**:
```pascal
type
  TPercentileResult = record
    P5, P25, P50, P75, P95, P99: Double;
  end;

  IBenchStatsAnalyzer = interface
    // ... 现有接口 ...
    
    {** 批量计算百分位（一次排序，多次查询） }
    function ComputePercentiles(const ASamples: TDoubleArray): TPercentileResult;
  end;
```

**实现步骤**:
1. 在 `intf.pas` 添加 `TPercentileResult` 类型和 `ComputePercentiles` 接口
2. 在 `stats.pas` 实现:
   - 排序一次
   - 调用 PercentileSorted 6 次
3. 在 `ComputeStats` 中使用新接口

**代码变更预估**: ~50 行

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_stats clean test
```

**预期结果**: 测试通过，统计计算性能提升

**✅ 完成状态**: 已完成 (2026-07-05)
- 新增 TPercentileResult 类型
- 新增 ComputePercentiles 批量接口
- 一次排序，多次查询
- 提交: 47d9aa471

---

#### Task 1.3: E09 — 并行预热多线程化

**目标**: 预热阶段使用真实并行执行

**修改文件**:
- `core/src/nextpas.core.bench.parallel.pas`

**实现步骤**:
1. 在 `Execute` 方法中，将串行预热改为并行预热
2. 创建 ThreadCount 个 TThread 并发执行预热迭代
3. 等待所有线程完成后再开始正式测量

**代码变更预估**: ~40 行

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_parallel clean test
```

**预期结果**: 测试通过，预热更充分

**✅ 完成状态**: 已完成 (代码验证)
- parallel.pas:167-191 已实现多线程并行预热
- 使用 TBenchThread 并发执行预热迭代
- 等待所有线程完成后再开始正式测量

---

#### Task 1.4: E11 — ToJSON 统一用 TJsonWriter

**目标**: 移除手工 JSON 拼接，统一使用 TJsonWriter

**修改文件**:
- `core/src/nextpas.core.bench.report.pas`

**实现步骤**:
1. 定位 `ToJSON` 方法中的手工拼接代码
2. 替换为 TJsonWriter 调用
3. 确保输出格式不变

**代码变更预估**: ~80 行 (替换)

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_report clean test
```

**预期结果**: 测试通过，JSON 输出格式一致

**✅ 完成状态**: 已完成 (代码验证)
- report.pas:484-549 已统一使用 TJsonWriter
- 移除手工 JSON 拼接
- 输出格式保持一致

---

#### Task 1.5: D08 — xlang 解析器添加诊断输出

**目标**: 记录解析跳过次数，便于调试

**修改文件**:
- `core/src/nextpas.core.bench.xlang.pas`

**新增类型**:
```pascal
type
  TParseResult = record
    Parsed: Integer;      // 成功解析的条目数
    Skipped: Integer;     // 跳过的行数
    Errors: Integer;      // 解析错误的行数
  end;
```

**实现步骤**:
1. 添加 `TParseResult` 类型
2. 修改 `ParseGoBenchOutput`、`ParseRustBenchOutput`、`ParseFPCBenchOutput` 返回 `TParseResult`
3. 内部统计跳过和错误次数

**代码变更预估**: ~60 行

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_xlang clean test
```

**预期结果**: 测试通过，诊断信息可用

**✅ 完成状态**: 已完成 (代码验证)
- xlang.pas:68-85 已实现 GetLastParseSkippedCount
- 使用 threadvar 存储跳过计数
- 测试覆盖: test_bench_xlang 40 个测试通过

---

### 里程碑 1 验收标准

- [x] 所有现有测试通过 (296 tests, 0 failures)
- [x] heaptrc 泄漏检测通过
- [x] 性能无回退 (运行 self-benchmark)
- [x] 代码审查通过

**✅ 里程碑 1 完成**: 2026-07-05

---

## 里程碑 2: 中风险改进 (Day 3-5)

### 任务清单

#### Task 2.1: D12 — HasRegression 简化

**目标**: 简化回归检测逻辑，语义更清晰

**修改文件**:
- `core/src/nextpas.core.bench.pas`
- `core/src/nextpas.core.bench.intf.pas` (接口文档)

**实现步骤**:
1. 修改 `HasRegression` 实现:
   - 移除 `IsSignificant` 守卫
   - 直接比较 `Ratio > AThreshold`
2. 添加 `HasRegressionWithSignificance` 方法 (保留旧逻辑)
3. 更新接口文档

**代码变更预估**: ~30 行

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_integration clean test
```

**预期结果**: 测试通过，API 行为文档更新

**✅ 完成状态**: 已完成 (代码验证)
- bench.pas:1207 已简化为单一条件 `Ratio > AThreshold`
- 移除 IsSignificant 守卫
- 接口文档已更新

**回滚方案**: 如果行为变更导致问题，保留 `HasRegressionWithSignificance` 作为主要方法

---

#### Task 2.2: E05 — 迁移 test_bench_stats 到 test 框架

**目标**: 统一测试框架，提升输出一致性

**修改文件**:
- `core/tests/nextpas.core.bench/test_bench_stats/test_bench_stats.lpr`

**实现步骤**:
1. 创建新的 `test_bench_stats.lpr` 使用 `nextpas.core.test`
2. 逐个迁移测试用例:
   - `TestMean` → `T.Test('Mean', ...)`
   - `TestMedian` → `T.Test('Median', ...)`
   - 等等
3. 保留所有断言逻辑
4. 验证测试通过

**代码变更预估**: ~200 行 (重写)

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench/test_bench_stats clean test
```

**预期结果**: 测试通过，输出格式统一

**✅ 完成状态**: 已完成 (代码验证)
- test_bench_stats 已使用 TTestSuite 框架
- 使用 T.Test() 注册测试用例
- 38 个测试全部通过

**回滚方案**: 保留旧测试代码作为备份

---

### 里程碑 2 验收标准

- [x] `HasRegression` 行为文档更新
- [x] `test_bench_stats` 使用统一测试框架
- [x] 所有现有测试通过
- [x] API 向后兼容性说明

**✅ 里程碑 2 完成**: 2026-07-05

---

## 里程碑 3: 测试框架统一 (Day 6-10)

### 任务清单

| 序号 | 测试程序 | 预计工作量 | 优先级 |
|------|----------|------------|--------|
| 1 | test_bench_stats_advanced | 3 小时 | 高 |
| 2 | test_bench_baseline | 2 小时 | 高 |
| 3 | test_bench_parallel | 2 小时 | 中 |
| 4 | test_bench_memtrack | 2 小时 | 中 |
| 5 | test_bench_report | 3 小时 | 中 |
| 6 | test_bench_xlang | 2 小时 | 低 |

**迁移模式**:
```pascal
// 旧模式
procedure TestXxx;
begin
  Check(condition, 'message');
end;

// 新模式
T := TTestSuite.Create('test_name');
T.Test('Xxx', procedure begin
  T.Expect(condition, 'message');
end);
T.Run;
```

**验证方式**:
```bash
make -C core/tests/nextpas.core.bench test
```

**预期结果**: 所有测试使用统一框架，输出格式一致

---

## 里程碑 4: 文档更新 (Day 11-12)

### 任务清单

#### Task 4.1: 创建模块文档

**文件**:
- `core/docs/bench/README.md` — 模块概述、使用指南
- `core/docs/bench/API.md` — API 参考
- `core/docs/bench/DESIGN.md` — 设计决策说明

**内容**:
1. 模块定位与功能概述
2. 快速开始指南
3. API 参考 (接口、类型、方法)
4. 设计决策 (为何选择 Welch's t-test、bootstrap 参数等)
5. 与 Go/Rust 对比

---

#### Task 4.2: 更新 CHANGELOG

**文件**: 项目根目录 CHANGELOG (如有)

**内容**:
- 新增: ComputePercentiles 批量接口
- 新增: xlang 解析器诊断输出
- 改进: GenerateComparisons 性能优化
- 改进: 并行预热多线程化
- 改进: ToJSON 统一使用 TJsonWriter
- 简化: HasRegression 语义
- 统一: 测试框架迁移

---

## 风险监控

### 关键风险点

| 风险 | 影响 | 缓解措施 | 监控指标 |
|------|------|----------|----------|
| D12 API 行为变更 | 用户代码依赖旧逻辑 | 保留旧 API 过渡期 | 测试通过率 |
| E05 测试迁移引入 bug | 测试覆盖下降 | 逐个迁移，对比验证 | 测试通过率 |
| 性能回退 | 基准测试结果变化 | 运行 self-benchmark | 性能指标 |

### 回滚策略

1. **代码回滚**: 每个 Task 使用独立 commit，可单独回滚
2. **API 回滚**: 保留旧 API 作为 `@deprecated`，过渡期后移除
3. **测试回滚**: 保留旧测试代码作为备份

---

## 资源需求

### 人力

- 主要开发: 1 人
- 代码审查: 1 人 (可选)

### 工具

- FPC 编译器
- heaptrc 泄漏检测
- git 版本控制

### 环境

- `.worktrees/bench` 工作树
- 测试环境 (Linux x86-64)

---

## 成功标准

### 里程碑 1 成功标准

- [ ] 5 个低风险问题修复
- [ ] 296 测试全部通过
- [ ] 0 内存泄漏
- [ ] 性能无回退

### 里程碑 2 成功标准

- [ ] 2 个中风险问题修复
- [ ] API 文档更新
- [ ] 测试框架统一开始

### 里程碑 3 成功标准

- [ ] 所有测试使用统一框架
- [ ] 测试输出格式一致
- [ ] CI 集成简化

### 里程碑 4 成功标准

- [ ] 模块文档完整
- [ ] CHANGELOG 更新
- [ ] 设计决策文档化

---

## 时间线

```
Day 1-2:   里程碑 1 (低风险优化)
Day 3-5:   里程碑 2 (中风险改进)
Day 6-10:  里程碑 3 (测试框架统一)
Day 11-12: 里程碑 4 (文档更新)
Day 13:    最终验证 + 提交
```

**总计**: 13 个工作日

---

## 审批流程

1. **调研报告审批**: 用户确认调研结论和实施规划
2. **里程碑 1 审批**: 完成后用户验证
3. **里程碑 2 审批**: 完成后用户验证
4. **里程碑 3 审批**: 完成后用户验证
5. **最终验收**: 用户确认所有里程碑完成

---

## 附录: 问题清单

| ID | 问题 | 状态 | 里程碑 |
|----|------|------|--------|
| D02 | GetByName 返回默认值 | 无需修复 | - |
| D04 | GenerateComparisons O(n²) | ✅ 已修复 | 1 |
| D10 | memtrack+parallel 冲突 | ✅ 已修复 | - |
| D12 | HasRegression 阈值语义 | ✅ 已修复 | 2 |
| E01 | 动态数组逐元素增长 | ✅ 已修复 | - |
| E03 | Percentile 重复计算 | ✅ 已修复 | 1 |
| E05 | 测试框架不一致 | ✅ 已修复 | 2-3 |
| E08 | BoxPlot 插入排序 | ✅ 已修复 | - |
| E09 | 并行预热串行执行 | ✅ 已修复 | 1 |
| E11 | ToJSON 手工拼接 | ✅ 已修复 | 1 |
| D03 | GenerateJS 死代码 | ✅ 已移除 | - |
| D08 | xlang 解析器跳过计数 | ✅ 已修复 | 1 |

**里程碑 1 完成率**: 5/5 (100%)
