# Test Framework — 改进路线图

> 创建日期: 2026-06-29
> 模块: nextpas.core.test.* + nextpas.core.bench.*
> 当前状态: v6.0, 14 文件, 8724 行, 10 套件, ~234 测试, 0 泄漏

## 已完成

- [x] Phase 1-23: 代码复用优化 (GrowCapacity/WriteTestOutput/RunAllIterLoop 等)
- [x] 工程治理: README.md 分层架构 + 稳定性等级 + 代码契约
- [x] 契约审计: 参数校验 100%, P0+P1 全清
- [x] G1: 测试覆盖补全 — 11 新测试, Stable API 100% 覆盖

## Phase G1: 测试覆盖补全 ✅

**目标**: 每个 Stable 公共 API 至少有 1 个直接测试

| 完成项 | 优先级 | 结果 |
|--------|--------|------|
| CheckNotContains 边界 | P2 | +1 pass + 1 fail |
| FailUnexpected 格式 | P2 | +1 "unexpected ClassName: msg" |
| Not_.ToBeLessOrEqual (Int64) | P2 | +1 pass + 1 fail |
| Not_.ToBeGreaterOrEqualD | P2 | +1 pass + 1 fail |
| Not_.ToBeLessOrEqualD | P2 | +1 pass + 1 fail |
| Not_.ToBeInRangeD | P2 | +1 pass + 1 fail |
| Not_.ToContainCI | P2 | +1 pass + 1 fail |
| Not_.ToStartWithCI | P2 | +1 pass + 1 fail |
| Not_.ToEndWithCI | P2 | +1 pass + 1 fail |
| CalledWith 空参数 | P2 | +1 pass |
| CalledExactlyWith 0-times | P2 | +1 pass + 1 fail |
| RunAllBenchmarks runner level | P2 | +1 multi-suite aggregation |
| AllPassed auto-run | P2 | +1 lazy run trigger |
| RunAllParallelWithResult | P2 | +1 result array populated |

**实际结果**: 11 新测试, 5 套件全绿, 0 泄漏
- test_assertions: 48 → 50
- test_expect: 93 → 100
- test_mock: 53 → 55
- test_runner: +2 inline tests
- test_parallel: +1 inline test

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
