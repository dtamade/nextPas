# Test Framework — 改进路线图

> 创建日期: 2026-06-29
> 模块: nextpas.core.test.* + nextpas.core.bench.*
> 当前状态: v6.0, 14 文件, 8724 行, 10 套件, ~234 测试, 0 泄漏

## 已完成

- [x] Phase 1-23: 代码复用优化 (GrowCapacity/WriteTestOutput/RunAllIterLoop 等)
- [x] 工程治理: README.md 分层架构 + 稳定性等级 + 代码契约
- [x] 契约审计: 参数校验 100%, P0+P1 全清
- [x] G1: 测试覆盖补全 — 11 新测试, Stable API 100% 覆盖
- [x] G2: Mock 框架增强 — 3 新测试, 类型路径补全
- [x] G3: 输出格式补全 — 跳过 (64 测试已充分)
- [x] G4: 并行测试加固 — 已有完整覆盖

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

## Phase G2: Mock 框架增强 ✅

**目标**: 补全 mock 框架的边界覆盖

| 完成项 | 优先级 | 结果 |
|--------|--------|------|
| CalledWith 空参数 | P2 | G1 中完成 |
| CalledExactlyWith 边界 | P2 | G1 中完成 |
| RecordCallTyped 全类型 | P2 | str/int/bool/double 4 类型存储验证 |
| GetReturnInt 空字符串 | P2 | '' → 0 |
| GetReturnBool 字符串值 | P2 | true/True/TRUE/false/1/空 6 路径 |

**实际结果**: 3 新测试 (G1 已含 2), test_mock: 53 → 58, 0 泄漏

## Phase G3: 输出格式补全 ⏭️ 跳过

**原因**: test_output 已有 64 测试，TAP/JSON/JUnitXML/ANSI/Filter/Config 全覆盖。无需补测。

## Phase G4: 并行测试加固 ✅ 已有覆盖

**发现**: 4 项全部已在 test_parallel 中覆盖

| 项目 | 状态 | 位置 |
|------|------|------|
| 并行 + ShouldFail | ✅ 已有 | ShouldFailParallel suite (line 476) |
| 并行 + TestTable | ✅ 已有 | TestTableParallelNameUniqueness (line 224) |
| 并行 + Cleanup | ✅ 已有 | CleanupParallel + CleanupExceptParallel (line 563/586) |
| 并行 + MaxParallelWorkers | ✅ 已有 | TestMaxParallelWorkers (line 297) |

## Phase G5: 文档完善 ⏳ P3 延后

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
