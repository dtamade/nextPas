# nextpas.core.test — 测试框架

## 概述

nextPas 项目自研的轻量级测试框架，支持串行/并行执行、子测试、参数化测试、超时、retry、expected failure、层级过滤、TAP/JSON/JUnit 输出。

## 版本

- v3.8: dead import cleanup + header standardization
- **v3.9**: ShouldFail + hierarchical filter + --count=N + slow test report

## 竞品对比

| 特性 | Go testing | Rust test | nextpas.core.test |
|------|-----------|-----------|-------------------|
| Subtests | `t.Run()` | — | `TestSubtest` |
| 层级过滤 | `-run Foo/Bar` | — | `--filter=Parent/Sub` |
| Expected fail | — | `#[should_panic]` | `ShouldFail` |
| 全局 repeat | `-count N` | `--repeat` | `--count=N` |
| 耗时报告 | `-v` | `--show-output` | Slow test report |
| Tags | — | — | `--tag=` |
| Retry | — | — | `Test(name, proc, N)` |
| Mock | — | — | TMock fluent API |
| Output | text | text | ANSI/TAP/JSON/JUnit |

## 套件列表

| 套件 | 覆盖范围 | 测试数 |
|------|---------|--------|
| `test_assertions` | Check* 过程式断言 API | 47 |
| `test_expect` | IExpectation 流式断言 API | 92 |
| `test_mock` | TMock 录制/验证/返回值/参数匹配 | 53 |
| `test_output` | ANSI、StatusDot、filter、timeout、JUnit/TAP/JSON 格式化、brace expansion、层级过滤 | 64 |
| `test_runner` | TTestRunner 多 suite、lifecycle、subtest、timeout、空 suite、ShouldFail、FormatDuration | 37+1x |
| `test_lifecycle` | TestTable、TTestClosure、lifecycle 组合、facade 符号完整性 | 15 |
| `test_parallel` | 并行执行、lifecycle、retry、skip、MaxParallelWorkers 批次调度 | 8 |
| `test_diagnostics` | 错误诊断、stack trace、Double 比较、Error vs Failure | 15 |
| `test_advanced` | RTTI discovery、retry、TAP/JSON 输出格式 | 13 |
| `test_subtests` | 子测试嵌套、ITestContext、failure 传播、AfterEach 失败、cleanup | 15 |

## 运行方式

```bash
# 单个套件
make -C core/tests/nextpas.core.test/<suite_name> test

# 例：运行 test_runner
make -C core/tests/nextpas.core.test/test_runner test
```

## 约定

- 编译模式：`{$mode objfpc}{$H+}{$J-}`，使用 `{$modeswitch anonymousfunctions}`
- 串行套件启用 heaptrc（`-gh`），必须 0 unfreed blocks
- 并行套件（test_parallel）不用 heaptrc（FPC heaptrc 非线程安全）
- 失败用 `Halt(1)` 退出，CI 通过 exit code 判断
- 全局计数器用于 lifecycle 验证（GSetupCalled 等）

## 文件结构

```
core/src/nextpas.core.test.pas              ← Facade（re-export）
core/src/nextpas.core.test.base.pas         ← 基础类型
core/src/nextpas.core.test.config.pas       ← TTestConfig + IOutputSink + ANSI
core/src/nextpas.core.test.check.pas        ← Check* 断言
core/src/nextpas.core.test.expect.pas       ← IExpectation 流式断言
core/src/nextpas.core.test.discovery.pas    ← RTTI 测试发现
core/src/nextpas.core.test.mock.pas         ← TMock
core/src/nextpas.core.test.runner.pas       ← TTestSuite/TTestRunner + 批次调度
core/src/nextpas.core.test.runner.parallel.pas ← 超时+并行 worker
core/src/nextpas.core.test.runner.context.pas  ← 子测试 ITestContext
core/src/nextpas.core.test.output.pas       ← ANSI/filter/JUnit
core/src/nextpas.core.test.output.tap.pas   ← TAP v13 输出
core/src/nextpas.core.test.output.json.pas  ← JSON 输出
core/src/nextpas.core.testing.pas           ← v1 兼容层（deprecated）
```

## 版本历史

- **v3.0**: 基础框架 — 14 文件、505 测试、3-phase polish
- **v3.1**: 批次调度 (`MaxParallelWorkers`)、Expect API 扩展（Double 比较、大小写不敏感）、Mock 参数验证
- **v3.2**: CheckTrue/False 消息改进、空 filter 边界测试
- **v3.4**: Brace expansion、ANSI TTY 检测、Before/AfterEach 文档
- **v3.5**: CheckNotContains、FailUnexpected、CheckContains 统一替换、ResolveOutSink 缓存
- **v3.6**: 编译器指令标准化 (`{$J-}`)、WriteLn header 统一、test_advanced 输出规范化
- **v3.7**: Facade 补全 (`ResetDefaultConfig`/`SetDefaultErrSink`/`TMockValueKind`)、测试文件 import 简化、移除脆弱手动计数器
- **v3.8**: 死代码导入清理 (`test_output`/`test_advanced` → facade-only)、头注释统一化
