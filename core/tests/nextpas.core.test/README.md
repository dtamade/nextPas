# nextpas.core.test — 测试框架

## 概述

nextPas 项目自研的轻量级测试框架，支持串行/并行执行、子测试、参数化测试、超时、retry、expected failure、层级过滤、TAP/JSON/JUnit 输出。

## 版本

- v3.8: dead import cleanup + header standardization
- **v3.9**: ShouldFail + hierarchical filter + --count=N + slow test report
- **v3.10**: shuffle + failfast + list mode
- **v3.11**: quality hardening — LCG overflow fix, facade exports, test coverage audit
- **v3.12**: audit — config sentinel fix, table-test error handling, CLI dedup
- **v4.0**: --short + --progress + --failures-max + --json + parallel ShortSkip fix
- **v5.0**: --verbose + --timeout + Cleanup() + parallel verbose/cleanup
- **v6.0**: Benchmark — adaptive N scaling, ns/op, --bench/--benchtime/--benchmem
- **v6.1**: R3 quality — NaN guards (11 methods), locale-independent FloatToStr, ToBeSame/ToEqualD API, P3 edge-case coverage

## 竞品对比

| 特性 | Go testing | Rust test | nextpas.core.test |
|------|-----------|-----------|-------------------|
| Subtests | `t.Run()` | — | `TestSubtest` |
| 层级过滤 | `-run Foo/Bar` | — | `--filter=Parent/Sub` |
| Expected fail | — | `#[should_panic]` | `ShouldFail` |
| Short mode | `-short` | — | `--short` |
| 全局 repeat | `-count N` | `--repeat` | `--count=N` |
| Shuffle | `-shuffle` | `--shuffle` | `--shuffle[-seed=N]` |
| FailFast | `-failfast` | `--fail-fast` | `--failfast` |
| Max failures | — | — | `--failures-max=N` |
| Progress | — | — | `--progress` |
| Verbose | `-v` | `--show-output` | `--verbose` |
| Global timeout | — | — | `--timeout=N` |
| Cleanup | `t.Cleanup()` | — | `Suite.Cleanup()` |
| Benchmark | `BenchmarkXxx` | — | `Bench()` + `--bench` |
| JSON output | `-json` | — | `--json` |
| List mode | — | `--list` | `--list` |
| Tags | — | — | `--tag=` |
| Retry | — | — | `Test(name, proc, N)` |
| Mock | — | — | TMock fluent API |
| Output | text | text | ANSI/TAP/JSON/JUnit |

## 套件列表

| 套件 | 覆盖范围 | 测试数 |
|------|---------|--------|
| `test_assertions` | Check* 过程式断言 API + NaN/边界覆盖 | 95 |
| `test_expect` | IExpectation 流式断言 API + NaN/Pointer/Double equality | 110 |
| `test_mock` | TMock 录制/验证/返回值/参数匹配 | 53 |
| `test_output` | ANSI、StatusDot、filter、timeout、JUnit/TAP/JSON 格式化、brace expansion、层级过滤、hierarchical+glob 组合 | 64 |
| `test_runner` | TTestRunner 多 suite、lifecycle、subtest、timeout、空 suite、ShouldFail、FormatDuration、shuffle、failfast、list、determinism、verbose、runtimeout、cleanup、benchmark | 49+1x |
| `test_lifecycle` | TestTable、TTestClosure、lifecycle 组合、facade 符号完整性 | 15 |
| `test_parallel` | 并行执行、lifecycle、retry、skip、MaxParallelWorkers 批次调度、verbose、cleanup | 10 |
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
- **v3.9**: ShouldFail (expected failure)、层级过滤 (`--filter=Parent/Sub`)、`--count=N`、慢测试报告、FormatDuration
- **v3.10**: Fisher-Yates shuffle (`--shuffle[-seed=N]`)、FailFast 双级 (`--failfast`)、List mode (`--list`)
- **v3.11**: 质量加固 — LCG `Abs` 溢出修复、`ekShouldFail` facade 导出、runner 重构 (`ApplyCLIArgs`/`WriteListMode`)、table test 异常处理、15+ 新测试 (FormatDuration 边界/ShouldFail closure/Skip/ shuffle 确定性/种子边界/hierarchical+glob 组合)

## 版本历史 (续)

- **v3.12**: audit — config sentinel fix, table-test error handling, CLI dedup
- **v4.0**: 差异化碾压特性:
  - `--short` 模式: `ShortSkip` 标记慢测试，开发时跳过 (对标 Go `-short`)
  - `--progress` 进度计数: `[N/Total]` 前缀，串行+并行均支持
  - `--failures-max=N` 全局失败上限: 非首次失败即停，跨 suite 累计
  - `--json` CLI 输出: 机器可读 JSON 报告直出 stdout
  - 并行 ShortSkip: batch 调度正确跳过 ShortSkip 测试 (P0 修复)
  - 新增 8 个测试覆盖全部新特性
- **v5.0**: 差异化碾压特性:
  - `--verbose` 逐测试详情: `[PASS]/[FAIL]/[SKIP]` + 耗时，串行+并行均支持 (Go `-v` 更好)
  - `--timeout=N` 全局运行超时: 整个 suite 运行超时保护，秒级精度 (**Go/Rust 独有**)
  - `Suite.Cleanup()` 保证清理: LIFO 清理回调，失败/成功均执行，串行+并行 (Go `t.Cleanup()` 等价)
  - 新增 5 个测试 (verbose + timeout + cleanup 串行/并行)
- **v6.0**: Benchmark — Go `testing.B` 等价:
  - `Bench(name, proc)`: 注册 benchmark，`TBenchProc` 接收 `PBenchContext` 控制 N 次迭代
  - 自适应 N 缩放: 从 N=1 开始，按目标时间自动缩放至稳定 (Go 算法)
  - `--bench[=pattern]`: 启用 benchmark，支持 pattern 匹配
  - `--benchtime=Nms/Ns`: 设置每个 benchmark 目标时间 (默认 1s)
  - `--benchmem`: 显示每次操作的内存分配 (B/op, allocs/op)
  - `FormatBenchLine`: ANSI 着色输出 `name N ns/op`
  - 新增 1 个 benchmark 测试 (Addition + StringConcat)
