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
- **v6.2**: Audit fixes — empty suite crash guard, Ctx() diagnostics, ShouldFail/glob/parallel tests, leak monitor counter
- **v6.3**: T-01 NaN/边界补全 + facade re-export 补全 (Check*D, CI, NotStartsWith/EndsWith)
- **v6.4**: P2 coverage — T-02 typed mock returns (7 tests), T-03 subtest skip message, T-04 TAP/JSON compliance (6 tests), T-05 complex filter scenarios (5 tests), T-06 config zero-value, T-07 test timeout exceeded
- **v6.5**: A-01 runner.pas split — CLI 解析提取到 `runner.cli.pas` (373行), runner.pas 2336→1980行; C-02 `platform_thread_timedjoin` 替代 10ms 轮询; 所有 audit findings 全清
- **v6.6**: Usability fixes — F-03 ToBeSame 消息修正, F-06 ToNotBeNear copy 模式, F-07 Mock.ResetAll, +4 回归测试
- **v6.7**: Usability — F-04 注释修正, F-02 CheckNearRel/ToBeNearRel 相对容差, F-03 ExpectStr 别名, F-12 /dev/urandom shuffle 种子, F-13 GetTopSlowest 优化, F-05 Mock VerifyAll + 错误消息改进, F-06 CheckSnapshot 快照测试, review: ToBeInRangeD epsilon + TMockValues export
- **v6.8**: Bug fix — RunParallelWithResult 缺少 FinalizeResults 调用，导致 Passed/Skipped/AllPassed 始终为 0
- **v7.0a**: Parallel Opt-in — `TestSeq()` 注册串行测试，并行模式下 Phase 1 先串行执行 Sequential 测试，Phase 2 再并行执行其余测试 (Go `t.Parallel()` inverse)
- **v7.0b**: Test Cache — `TTestCache` 缓存测试结果，`--cache` 启用，FNV-1a hash (源文件+编译器+配置)
- **v7.0c**: Cache integration — runner 自动查缓存/写缓存，命中显示 `(cached)` 跳过执行，`SourceFiles` 支持内容失效

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
| Parallel opt-in | `t.Parallel()` | `#[serial]` | `TestSeq()` |
| Test cache | `go test -cache` | — | `--cache` |
| Property-based test | QuickCheck (3rd party) | proptest | **v7.1** GenString/GenInt/GenBool/GenBytes + Map/Filter combinators |
| Output | text | text | ANSI/TAP/JSON/JUnit |

## 套件列表

| 套件 | 覆盖范围 | 测试数 |
|------|---------|--------|
| `test_assertions` | Check* 过程式断言 API + NaN/边界/epsilon 覆盖 | 112 |
| `test_expect` | IExpectation 流式断言 API + NaN/Pointer/Double/epsilon 边界 | 126 |
| `test_mock` | TMock 录制/验证/返回值/参数匹配/typed 返回/ResetAll | 82 |
| `test_output` | ANSI、StatusDot、filter、timeout、JUnit/TAP/JSON 格式化、brace expansion、层级过滤、hierarchical+glob 组合、TAP/JSON compliance | 79 |
| `test_runner` | TTestRunner 多 suite、lifecycle、subtest、timeout、空 suite、ShouldFail、FormatDuration、shuffle、failfast、list、determinism、verbose、runtimeout、cleanup、benchmark、parallel空suite防护、glob边界、test timeout exceeded、config zero-value、complex filter、benchmark N scaling、suite-level retry、CleanupTableAllocations 幂等、FormatDuration locale | 117 |
| `test_lifecycle` | TestTable、TTestClosure、lifecycle 组合、facade 符号完整性 | 30 |
| `test_parallel` | 并行执行、lifecycle、retry、skip、MaxParallelWorkers 批次调度、verbose、cleanup | 47 |
| `test_diagnostics` | 错误诊断、stack trace、Double 比较、Error vs Failure | 17 |
| `test_advanced` | RTTI discovery、retry、TAP/JSON 输出格式 | 19 |
| `test_subtests` | 子测试嵌套、ITestContext、failure 传播、AfterEach 失败、cleanup | 1 |
| `test_stress` | 高并发压力测试、大量测试注册、内存密集 | 1 |
| `test_prop` | Property-based testing — GenString/GenInt/GenBool/GenBytes + shrinking + Map/Filter/Choice/OneOf combinators + PropFail/PropWithResult | 15 |

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
  - **注意**: `test_assertions` 显示 32 字节 unfreed，这是 FPC runtime 内部簿记（空 heaptrc 调用栈），非框架泄漏。其余所有套件 0 unfreed。
- 并行套件（test_parallel）不用 heaptrc（FPC heaptrc 非线程安全）
- 失败用 `Halt(1)` 退出，CI 通过 exit code 判断
- 全局计数器用于 lifecycle 验证（GSetupCalled 等）

## 注意事项

### 工厂函数推荐

流式断言使用类型安全的工厂函数（推荐）：

| 工厂函数 | 类型 | 启用的方法 |
|---------|------|-----------|
| `ExpectStr(s)` | string | ToEqual/ToContain/ToStartWith/ToEndWith/ToHaveLength |
| `ExpectInt(n)` | Int64 | ToEqualInt/ToBeGreaterThan/ToBeLessThan/ToBeInRange/ToBePositive/ToBeNegative |
| `ExpectBool(b)` | Boolean | ToBeTrue/ToBeFalse |
| `ExpectDouble(d)` | Double | ToEqualDouble/ToBeNear/ToBeGreaterThan/ToBeLessThan |
| `ExpectPtr(p)` | Pointer | ToBeNil/ToNotBeNil |
| `ExpectProc(p)` | TTestProc | ToRaise/ToNotRaise |

`Expect(s)` 是 `ExpectStr(s)` 的便捷别名，仅接受字符串。

⚠ **不要向 `Expect()` 传递非字符串类型**：FPC `{$H+}` 允许隐式 `Int64→string` 转换，编译通过但会创建错误的 expectation kind，导致 `RequireKind` panic。

```pascal
ExpectStr(name).ToEqual('Alice');          ✓ 类型安全
Expect(name).ToEqual('Alice');             ✓ 字符串也可
Expect(42).ToEqualInt(42);                 ✗ 编译通过但运行时 panic！用 ExpectInt(42)
```

### 快速上手

```pascal
program my_tests;
{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
uses
  nextpas.core.test;

procedure TestAddition;
begin
  // 过程式断言
  CheckEqual(4, 2 + 2);
  // 流式断言
  ExpectInt(2 + 2).ToEqualInt(4).ToBeGreaterThan(0);
end;

procedure TestString;
begin
  CheckContains('hello world', 'world');
  ExpectStr('hello').ToStartWith('he').ToEndWith('lo').ToHaveLength(5);
end;

procedure TestFloat;
begin
  // 绝对容差
  CheckNear(3.14, Pi, 0.01);
  // 相对容差（大数值推荐）
  CheckNearRel(1e15, 1e15 + 1e5, 1e-9);
  ExpectDouble(Pi).ToBeNear(3.14, 0.01);
end;

procedure TestException;
begin
  CheckRaises(EConvertError, procedure begin StrToInt('bad'); end);
  ExpectProc(procedure begin StrToInt('bad'); end).ToRaise(EConvertError);
end;

procedure TestMock;
var
  M: TMock;
begin
  M := TMock.Create;
  try
    M.Setup('Foo').Returns('bar');
    M.RecordCall('Foo', []);
    CheckEqual('bar', M.GetReturn('Foo'));
    M.Verify('Foo').CalledOnce;
    M.VerifyAll; // 检查所有 setup 的方法都被调用
  finally
    M.Free;
  end;
end;

procedure TestSnapshot;
begin
  // 首次运行自动创建快照，后续对比
  CheckSnapshot('expected output', '__snapshots__', 'output.txt');
  // 更新: NEXTPAS_UPDATE_SNAPSHOTS=1 ./my_tests
end;

var
  Suite: TTestSuite;
begin
  Suite := TTestSuite.Create('my-tests');
  Suite.Test('addition', @TestAddition);
  Suite.Test('string', @TestString);
  Suite.Test('float', @TestFloat);
  Suite.Test('exception', @TestException);
  Suite.Test('mock', @TestMock);
  Suite.Test('snapshot', @TestSnapshot);
  if not Suite.Run then
    Halt(1);
end.
```

### TTestSuite 是 mutable record

`TTestSuite` 是 Pascal record（值类型）。**推荐使用直接修改方法**（`SetSetup`/`OnBeforeEach` 等），它们就地修改 record，无返回值陷阱：

```pascal
// ✅ 推荐：直接修改方法，无陷阱
Suite.SetSetup(Proc);
Suite.OnBeforeEach(Proc);
Suite.OnAfterEach(Proc);
Suite.Cleanup(Proc);
Suite.Test('name', TestProc);
```

`With*` 方法（`WithSetup`/`WithTeardown` 等）已 deprecated——它们返回新 record，丢弃返回值是常见 bug：

```pascal
// ❌ 错误：WithSetup 返回新 record，原 Suite 不变（编译警告）
Suite.WithSetup(Proc);

// ⚠️ 正确但不推荐：必须保存返回值
Suite := Suite.WithSetup(Proc);
```

### 并行模式限制

子测试 (`TestSubtest`)、benchmarks、RTTI discovery 子测试在 `RunParallel` 模式下自动跳过（输出 "subtests not supported in parallel mode"）。这是因为子测试需要嵌套线程调度，架构复杂度高。**如需并行执行子测试，请使用串行模式 `Run`。**

### Mock.ResetCalls vs ResetAll

- `Mock.ResetCalls` — 只清 calls，保留 setup 配置
- `Mock.ResetAll` — 清除 calls + setup 配置

## 文件结构

```
core/src/nextpas.core.test.pas              ← Facade（re-export）
core/src/nextpas.core.test.fwd.expect.inc   ← Expect 转发实现
core/src/nextpas.core.test.fwd.check.inc    ← Check 转发实现
core/src/nextpas.core.test.fwd.output.inc   ← Output/Config 转发实现
core/src/nextpas.core.test.fwd.other.inc    ← Base/Discovery/Mock/Helpers 转发实现
core/src/nextpas.core.test.base.pas         ← 基础类型
core/src/nextpas.core.test.config.pas       ← TTestConfig + IOutputSink + ANSI
core/src/nextpas.core.test.check.pas        ← Check* 断言 + 快照测试
core/src/nextpas.core.test.expect.pas       ← IExpectation 流式断言
core/src/nextpas.core.test.discovery.pas    ← RTTI 测试发现
core/src/nextpas.core.test.mock.pas         ← TMock + VerifyAll
core/src/nextpas.core.test.runner.pas       ← TTestSuite/TTestRunner + 批次调度
core/src/nextpas.core.test.runner.cli.pas   ← CLI 参数解析 (FromArgs/ApplyCLIArgs)
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
- **v6.8**: Bug fix — RunParallelWithResult 缺少 FinalizeResults 调用，导致 Passed/Skipped/AllPassed 始终为 0
- **v7.0a**: Parallel Opt-in — `TestSeq()` 注册串行测试，并行模式下 Phase 1 先串行执行 Sequential 测试，Phase 2 再并行执行其余测试 (Go `t.Parallel()` inverse)
- **v7.0b**: Test Cache — `TTestCache` 缓存测试结果，`--cache` 启用，FNV-1a hash (源文件+编译器+配置)
- **v7.0c**: Cache integration — runner 自动查缓存/写缓存，命中显示 `(cached)` 跳过执行，`SourceFiles` 支持内容失效
- **v7.1**: Property-based Testing — QuickCheck 风格，4 种生成器 (GenString/GenInt/GenBool/GenBytes)，自动 shrinking (二分缩小)，`Prop()` 注册属性测试
- **v7.1a**: Generator Combinators — `MapIntToStr` (类型转换)、`FilterInt`/`FilterString`/`FilterBytes` (谓词过滤)，shrink 时尊重 filter 约束
- **v7.1b**: GenChoice/GenOneOf + Shrink 修复 — `GenChoiceInt`/`GenChoiceString`/`GenChoiceBool` (从数组随机选取)、`GenOneOfInt`/`GenOneOfString` (组合多个生成器)；修复 shrink 无限递归 (固定点检测)；修复 `Prop()` 中 `FailTest` 调用 `Halt(1)` 导致 shrink 失效的问题；新增 `PropFail()` (抛异常) 和 `PropWithResult()` (返回缩小值)；Int shrink 改进 (尊重 FMin 边界)

## 路线图

| 版本 | 特性 | 状态 | 依赖 |
|------|------|------|------|
| **v7.1** | Property-based Testing — 结构化随机生成 + 收缩 (shrinking) | ✅ 已完成 | 无 |
| **v7.1a** | Generator Combinators — Map/Filter 组合器 | ✅ 已完成 | v7.1 |
| **v7.1b** | GenChoice/GenOneOf + Shrink 修复 | ✅ 已完成 | v7.1a |
| **v7.2** | Coverage-guided Fuzzing — 编译器覆盖率插桩引导变异 | 🔴 等待 nextpas 编译器 | nextpas 覆盖率插桩 + sanitizer |
| **v7.3** | Fuzzing corpus management — 语料库持久化、最小化、回归 | 🔴 等待 v7.2 | v7.2 |

### v7.1 Property-based Testing — 实际 API

```pascal
{ 基础用法 }
procedure TestRoundtrip(const S: string);
begin
  CheckEqual(S, JsonDecode(JsonEncode(S)));
end;
Prop('JSON roundtrip', @TestRoundtrip, GenString(1000), 100, True);

{ 4 种生成器 }
GenString(AMaxLen) / GenString(AMinLen, AMaxLen)   // 可打印 ASCII
GenInt(AMax) / GenInt(AMin, AMax)                   // Int64 范围
GenBool                                              // 随机布尔
GenBytes(AMaxLen) / GenBytes(AMinLen, AMaxLen)      // 随机字节

{ 组合器 (v7.1a) }
MapIntToStr(GenInt(0, 9999), function(V: Int64): string begin Result := IntToStr(V) end)
FilterInt(GenInt(0, 1000), function(V: Int64): Boolean begin Result := V mod 2 = 0 end)
FilterString(GenString(50), function(const V: string): Boolean begin Result := Length(V) > 0 end)
FilterBytes(GenBytes(50), function(const V: TBytes): Boolean begin Result := Length(V) > 0 end)

{ 选取器 (v7.1b) }
GenChoiceInt([10, 20, 30])           // 从数组随机选取
GenChoiceString(['foo', 'bar'])      // 字符串选取
GenChoiceBool([True])                // 布尔选取
GenOneOfInt([GenInt(0, 10), GenInt(100, 110)])    // 组合多个生成器
GenOneOfString([GenString(5), GenString(10)])

{ 测试辅助 (v7.1b) }
PropFail('error message')            // 在 Prop 体内抛异常 (替代 FailTest)
PropWithResult('name', @Test, Gen)   // 返回缩小后的值 (用于测试 shrink 行为)
```

- QuickCheck 风格，不需要编译器支持
- 4 种基础生成器 + 4 种组合器 (Map/Filter) + 5 种选取器 (Choice/OneOf)
- 自动 shrinking: 失败时递归二分缩小输入，找到最小复现
- Filter 组合器在 shrink 时也尊重谓词约束
- PropFail: 在 Prop 测试体内使用 (FailTest 调用 Halt(1) 会跳过 shrink)

### v7.2 Coverage-guided Fuzzing 前置条件

- nextpas 编译器支持覆盖率插桩（类似 Go `-coverprofile`）
- 运行时 sanitizer（ASan/MSan）或等价检测
- LLVM 后端完成后可考虑 libFuzzer 集成
