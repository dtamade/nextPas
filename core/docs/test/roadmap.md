# Test Framework — 改进路线图

> 创建日期: 2026-06-29
> 模块: nextpas.core.test.* + nextpas.core.bench.*
> 当前状态: v6.0, 14 文件, 8724 行, 10 套件, ~234 测试, 0 泄漏

## 已完成

- [x] Phase 1-23: 代码复用优化 (GrowCapacity/WriteTestOutput/RunAllIterLoop 等)
- [x] 工程治理: README.md 分层架构 + 稳定性等级 + 代码契约
- [x] 契约审计: 参数校验 100%, P0+P1 全清

## Phase G1: 测试覆盖补全

**目标**: 每个 Stable 公共 API 至少有 1 个直接测试

| 待补 | 优先级 | 说明 |
|------|--------|------|
| CheckNotNil 边界 | P2 | 测试 nil → pass, non-nil → fail |
| CheckSame 边界 | P2 | 测试相同指针 → pass, 不同 → fail |
| CheckNotContains 边界 | P2 | 测试包含 → fail, 不包含 → pass |
| TestRepeat 多次 | P2 | 测试 RepeatCount > 1 的多次执行 |
| RunBenchmarks 边界 | P2 | 测试无基准/单基准/多基准 |
| WithConfig 组合 | P2 | 测试 fluent 配置链 |

**验收标准**: test_assertions 从 48 → 55+, test_runner 从 33 → 40+

## Phase G2: Mock 框架增强

**目标**: 补全 mock 框架的边界覆盖

| 待补 | 优先级 | 说明 |
|------|--------|------|
| CalledWith 空参数 | P2 | 测试 `CalledWith([])` 匹配无参调用 |
| CalledExactlyWith 边界 | P2 | 测试 0 次/1 次/多次匹配 |
| RecordCallTyped 边界 | P2 | 测试各种 TMockValue 类型 |
| GetReturnInt/GetReturnBool | P2 | 测试 typed 返回值路径 |

**验收标准**: test_mock 从 ~20 → 30+

## Phase G3: 输出格式补全

**目标**: 确保所有输出格式有完整测试

| 待补 | 优先级 | 说明 |
|------|--------|------|
| TAPReport 边界 | P2 | 测试空结果/单结果/多结果/跳过/错误 |
| JSONReport 边界 | P2 | 测试空结果/特殊字符转义 |
| JUnitXML 边界 | P2 | 测试空结果/CapturedLog/错误类型 |
| FormatBenchLine 边界 | P2 | 测试各种 ns/op 单位 |

**验收标准**: test_output 从 ~10 → 20+

## Phase G4: 并行测试加固

**目标**: 提升并行测试的覆盖面和稳定性

| 待补 | 优先级 | 说明 |
|------|--------|------|
| 并行 + ShouldFail | P2 | 测试并行模式下的 ShouldFail |
| 并行 + TestTable | P2 | 测试并行模式下的表驱动测试 |
| 并行 + Cleanup | P2 | 测试并行模式下的 LIFO 清理 |
| 并行 + MaxParallelWorkers | P2 | 测试批分派限制 |

**验收标准**: test_parallel 从 24 → 35+

## Phase G5: 文档完善

**目标**: 每个模块有内联文档

| 待补 | 优先级 | 说明 |
|------|--------|------|
| base.pas 行内注释 | P3 | 关键类型和函数的用途说明 |
| config.pas 行内注释 | P3 | TTestConfig 每个字段的含义 |
| runner.pas 行内注释 | P3 | RunWithResult 的执行流程图 |
| output.pas 行内注释 | P3 | MatchesGlob 算法说明 |

**验收标准**: 每个 Stable 公共 API 有 1 行 doc comment

## 优先级说明

| 等级 | 含义 | 时间线 |
|------|------|--------|
| P0 | 立即修复 (契约违反/崩溃) | 当天 |
| P1 | 尽快补全 (测试缺口) | 本周 |
| P2 | 计划补全 (覆盖增强) | 本月 |
| P3 | 有空再做 (文档完善) | 随时 |

## 执行原则

1. **测试先行**: 先写测试，再改代码
2. **最小修改**: 只改完成当前任务必需的代码
3. **0 泄漏**: 所有改动必须 heaptrc 0 unfreed
4. **全量验证**: 每次改动后运行全部 10 个套件
5. **有意义提交**: 每个 commit 说明改了什么、为什么改
