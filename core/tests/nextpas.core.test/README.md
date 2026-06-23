# nextpas.core.test — 测试框架

## 概述

nextPas 项目自研的轻量级测试框架，支持串行/并行执行、子测试、参数化测试、超时、retry、TAP/JSON/JUnit 输出。

## 套件列表

| 套件 | 覆盖范围 | 测试数 |
|------|---------|--------|
| `test_assertions` | Check* 过程式断言 API | 31 |
| `test_expect` | IExpectation 流式断言 API | 75 |
| `test_runner` | TTestRunner 多 suite、lifecycle、subtest、timeout、空 suite | ~25 |
| `test_lifecycle` | TestTable、TTestClosure、lifecycle 组合、facade 符号完整性 | 13 |
| `test_advanced` | RTTI discovery、retry、TAP/JSON 输出格式 | 12 |
| `test_mock` | TMock 录制/验证/返回值 | 22 |
| `test_output` | ANSI、StatusDot、filter、timeout、JUnit/TAP/JSON 格式化 | 39 |
| `test_parallel` | 并行执行、并行 lifecycle、并行 retry、并行 skip | ~15 |
| `test_subtests` | 子测试嵌套、ITestContext、failure 传播、AfterEach 失败 | 12 |

## 运行方式

```bash
# 单个套件
make -C core/tests/nextpas.core.test/<suite_name> test

# 例：运行 test_runner
make -C core/tests/nextpas.core.test/test_runner test
```

## 约定

- 编译模式：`{$mode objfpc}{$H+}`，使用 `{$modeswitch anonymousfunctions}`
- 串行套件启用 heaptrc（`-gh`），必须 0 unfreed blocks
- 并行套件（test_parallel）不用 heaptrc（FPC heaptrc 非线程安全）
- 失败用 `Halt(1)` 退出，CI 通过 exit code 判断
- 全局计数器用于 lifecycle 验证（GSetupCalled 等）

## 文件结构

```
core/src/nextpas.core.test.pas              ← Facade（re-export）
core/src/nextpas.core.test.base.pas         ← 基础类型
core/src/nextpas.core.test.check.pas        ← Check* 断言
core/src/nextpas.core.test.expect.pas       ← IExpectation 流式断言
core/src/nextpas.core.test.discovery.pas    ← RTTI 测试发现
core/src/nextpas.core.test.mock.pas         ← TMock
core/src/nextpas.core.test.runner.pas       ← TTestSuite/TTestRunner
core/src/nextpas.core.test.runner.parallel.pas ← 超时+并行 worker
core/src/nextpas.core.test.runner.context.pas  ← 子测试 ITestContext
core/src/nextpas.core.test.output.pas       ← ANSI/filter/JUnit
core/src/nextpas.core.test.output.tap.pas   ← TAP v13 输出
core/src/nextpas.core.test.output.json.pas  ← JSON 输出
core/src/nextpas.core.testing.pas           ← v1 兼容层（deprecated）
```

## 审计记录

`test-findings.md` 记录了 R1-R4 四轮审计发现及修复状态。
