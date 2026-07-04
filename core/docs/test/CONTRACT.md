# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas`（16 个源文件）
**层级**：L1（依赖 L0: base, text, sync, atomic, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-04
**版本**：6.7

---

## 1. 子模块

| 文件 | 职责 | LOC |
|------|------|-----|
| test.pas | 门面：re-export 所有公共 API | ~309 |
| test.base.pas | 基础类型（TTestEntry, TTestStatus, TBenchContext, ETestSkipped, threadvar） | ~736 |
| test.check.pas | 过程式 Check* 断言 API（30+ 方法） | ~709 |
| test.expect.pas | 流式 IExpectation 接口 + TExpectation 实现 | ~776 |
| test.mock.pas | TMock/TMockState 手动 Mock 框架 | ~881 |
| test.config.pas | TTestConfig record (22 字段) + IOutputSink + 配置解析 | ~563 |
| test.runner.pas | TTestSuite/TTestRunner + 串行/并行执行 + Benchmark | ~1988 |
| test.runner.cli.pas | CLI 参数解析（16 个 flag） | ~374 |
| test.runner.parallel.pas | 并行 worker + timeout watchdog | ~528 |
| test.runner.context.pas | TTestContext (ITestContext) + TTestResultAppender | ~471 |
| test.discovery.pas | RTTI VMT 方法表扫描自动发现测试 | ~153 |
| test.output.pas | ANSI 辅助、glob 匹配、JUnit XML、泄漏报告 | ~1094 |
| test.output.json.pas | JSON 输出格式 | ~185 |
| test.output.tap.pas | TAP v13 输出格式 | ~123 |
| test.helpers.pas | ExpectFail, WithMock, MakeBufferConfig 辅助 | ~95 |
| testing.pas | **DEPRECATED** v1 兼容层（371 外部调用者，待迁移） | ~133 |

---

## 2. 核心接口

### 2.1 IOutputSink

```pascal
IOutputSink = interface
  procedure Write(const AText: string);
  procedure WriteLn(const AText: string);
  procedure Flush;
end;
```

实现：`TStdoutSink`、`TStderrSink`、`TBufferSink`。

### 2.2 IExpectation

```pascal
IExpectation = interface
  function Not_: IExpectation;
  function ToEqual(const AExpected: string): IExpectation;
  function ToEqualInt(const AExpected: Int64): IExpectation;
  function ToEqualBool(AExpected: Boolean): IExpectation;
  function ToBeTrue: IExpectation;
  function ToBeFalse: IExpectation;
  function ToBeNil: IExpectation;
  function ToBeNotNil: IExpectation;
  function ToContain(const ASubstr: string): IExpectation;
  function ToStartWith(const APrefix: string): IExpectation;
  function ToEndWith(const ASuffix: string): IExpectation;
  function ToBeGreaterThan(const AExpected: Int64): IExpectation;
  function ToBeLessThan(const AExpected: Int64): IExpectation;
  function ToBeGreaterOrEqual(const AExpected: Int64): IExpectation;
  function ToBeLessOrEqual(const AExpected: Int64): IExpectation;
  function ToBeInRange(const ALow, AHigh: Int64): IExpectation;
  function ToHaveLength(const AExpected: NativeInt): IExpectation;
  function ToRaise(AExceptionClass: ExceptClass; const AMessage: string = ''): IExpectation;
  function ToNotRaise: IExpectation;
  function ToBeNear(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
  function ToNotBeNear(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
  function ToBeNearRel(const AExpected: Double; const ARelEps: Double = 1e-9): IExpectation;
  function ToNotBeNearRel(const AExpected: Double; const ARelEps: Double = 1e-9): IExpectation;
  function ToBeGreaterThanD(const AExpected: Double): IExpectation;
  function ToBeLessThanD(const AExpected: Double): IExpectation;
  function ToBeGreaterOrEqualD(const AExpected: Double): IExpectation;
  function ToBeLessOrEqualD(const AExpected: Double): IExpectation;
  function ToBeInRangeD(const ALow, AHigh: Double; const AEpsilon: Double = 1e-10): IExpectation;
  function ToContainCI(const ASubstr: string): IExpectation;
  function ToStartWithCI(const APrefix: string): IExpectation;
  function ToEndWithCI(const ASuffix: string): IExpectation;
  function ToBeSame(const AExpected: Pointer): IExpectation;
  function ToEqualPointer(const AExpected: Pointer): IExpectation;
  function ToEqualD(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
end;
```

工厂函数：`Expect(string)`, `ExpectStr`, `ExpectInt`, `ExpectBool`, `ExpectDouble`, `ExpectPtr`, `ExpectProc`。

### 2.3 IMockSetup / IMockVerify

```pascal
IMockSetup = interface
  function Returns(const AValue: string): IMockSetup;
  function ReturnsInt(const AValue: Int64): IMockSetup;
  function ReturnsBool(AValue: Boolean): IMockSetup;
  function ReturnsDouble(const AValue: Double): IMockSetup;
  function InOrder: IMockSetup;
end;

IMockVerify = interface
  procedure CalledExactly(ACount: Integer);
  procedure CalledAtLeast(ACount: Integer);
  procedure CalledAtMost(ACount: Integer);
  procedure CalledNever;
  procedure CalledOnce;
  function  Times(N: Integer): IMockVerify;
  function  CalledBefore(const AOtherMethod: string): IMockVerify;
  function  CalledAfter(const AOtherMethod: string): IMockVerify;
  function  CalledWith(const AArgs: array of string): IMockVerify;
  function  CalledWith(const AArgs: array of TMockValue): IMockVerify;
  function  CalledExactlyWith(ACount: Integer; const AArgs: array of string): IMockVerify;
  function  CalledExactlyWith(ACount: Integer; const AArgs: array of TMockValue): IMockVerify;
end;
```

### 2.4 ITestContext

```pascal
ITestContext = interface
  procedure Run(const AName: string; AProc: TTestProc);
  procedure Run(const AName: string; AProc: TTestClosure);
  procedure Fail(const AMessage: string);
  procedure Skip(const AReason: string = '');
  function  GetTestName: string;
  procedure Log(const AMessage: string);
  procedure OnCleanup(AProc: TTestProc);
  procedure OnCleanup(AProc: TTestClosure);
end;
```

---

## 3. 核心类型

### 3.1 TTestConfig (22 字段)

```pascal
TTestConfig = record
  FilterPattern: string;       { --filter: glob 模式匹配测试名 }
  TagFilter    : string;       { --tag: 逗号分隔标签过滤 }
  TimeoutMs    : UInt64;       { 每个测试的超时 (ms) }
  AnsiMode     : TAnsiMode;    { amAuto/amOn/amOff }
  OutSink      : IOutputSink;  { 标准输出接收器 }
  ErrSink      : IOutputSink;  { 错误输出接收器 }
  RetryCount   : Integer;      { 重试次数 (0=不重试) }
  MaxParallelWorkers: Integer; { 0=无限, >0=批 dispatch 最大并发数 }
  RepeatAllCount: Integer;     { --count=N: 全量重复 N 次 }
  SlowTestCount : Integer;     { 显示最慢 N 个测试 (默认 5) }
  ShuffleSeed   : Integer;     { 0=关闭, -1=随机, >0=指定种子 }
  FailFast      : Boolean;     { --failfast: 首次失败立即停止 }
  ListMode      : Boolean;     { --list: 列出测试名不运行 }
  ShortMode     : Boolean;     { --short: 跳过 ShortSkip 标记的测试 }
  ShowProgress  : Boolean;     { --progress: 显示 [N/Total] 进度 }
  MaxFailures   : Integer;     { --failures-max: 最大失败数 }
  JsonOutput    : Boolean;     { --json: 输出 JSON 报告 }
  VerboseMode   : Boolean;     { --verbose: 显示 [PASS]/[FAIL]/[SKIP] }
  RunTimeoutSec : Integer;     { --timeout: 全局 suite 超时 (秒) }
  BenchEnabled  : Boolean;     { --bench: 运行 benchmark }
  BenchTimeMs   : Integer;     { benchmark 目标时长 (默认 1000ms) }
  BenchMem      : Boolean;     { --benchmem: 报告每次操作内存分配 }
  RunPattern    : string;      { --run: 精确测试名匹配 (大小写无关) }
end;
```

### 3.2 TTestSuite (record, 值类型)

```pascal
TTestSuite = record
  Name      : string;
  Config    : TTestConfig;
  Tests     : specialize TArray<TTestEntry>;
  Setup/SetupClosure: TTestProc / TTestClosure;
  Teardown/TeardownClosure: TTestProc / TTestClosure;
  BeforeEach/BeforeEachClosure: TTestProc / TTestClosure;
  AfterEach/AfterEachClosure: TTestProc / TTestClosure;
  EachCleanups: specialize TArray<TTestClosure>;  { LIFO cleanup }
  StubAllocations/FixtureAllocations: specialize TArray<Integer>;
  LastRunPassed/HasRun/FCleanupDone: Boolean;
  LastPass/LastFail/LastSkip: Integer;
end;
```

**⚠️ With* 方法返回新 record，必须赋值**：`Suite := Suite.WithSetup(Proc);`

### 3.3 TTestRunner (record)

```pascal
TTestRunner = record
  Name     : string;
  Suites   : specialize TArray<TTestSuite>;
  TotalPass/TotalFail/TotalSkip: Integer;
  HasRun   : Boolean;
end;
```

---

## 4. 不变量

- `--filter` 使用 glob 模式匹配（`*` 通配符，大小写无关）
- `--tag` 逗号分隔，任意匹配即通过
- `--timeout` 每个测试独立超时（watchdog 子线程，非轮询）
- `--timeout` 全局 suite 超时（`RunTimeoutSec`）
- `--failfast` 首次失败立即停止当前 suite
- `--failures-max` 总失败数达上限后停止
- `--shuffle` 使用 Fisher-Yates 洗牌
- `--count=N` 全量重复 N 次，每次独立计数
- Benchmark 使用 adaptive N scaling（Go testing.B 算法）
- BeforeEach/AfterEach 在同线程执行（并行模式下每个 worker 线程独立执行）
- EachCleanups 以 LIFO 顺序执行（Go t.Cleanup 等价）
- ShouldFail：proc 抛出任意异常则通过（Rust #[should_panic] 等价）

---

## 5. 线程安全

- `GExecState` 是 threadvar，每线程独立
- 串行模式：主线程执行，GExecState 在 finally 块内 Dispose
- 并行模式：BeginThread 创建 worker，每个 worker 在 finally 块内 Dispose GExecState
- 并行模式 mutex 保护共享输出（SafeRelease 模式）
- `GStubRegistry` / `GFixtureRegistry` 非线程安全（仅主线程操作）
- 并行模式不支持 subtest 和 benchmark（优雅跳过 + EmitParallelSkip）

---

## 6. 内存管理

- IExpectation 通过 COM 引用计数自动释放
- TMock 由调用方手动 Free（WithMock 辅助确保异常时也释放）
- GExecState threadvar：New 分配，Dispose 释放（finally 块内）
- TTestSuite.Test 注册的 closure 由 record 析构时自动释放
- DiscoverTests 分配的 PMethodStub 由 CleanupTableAllocations 释放
- FCleanupDone guard 防止 --count=N 重跑时 double-free
- CleanupTableAllocations 在 RunWithResult/RunParallelWithResult 结束时调用

---

## 7. 输出格式

| 格式 | 触发 | 文件 |
|------|------|------|
| ANSI (默认) | 自动检测 TTY | test.output.pas |
| TAP v13 | `--tap` | test.output.tap.pas |
| JSON | `--json` | test.output.json.pas |
| JUnit XML | `WriteJUnitXML` API | test.output.pas |

---

## 8. 测试覆盖

| 套件 | 测试数 | 覆盖范围 |
|------|--------|----------|
| test_assertions | 108 | Check* 全方法 |
| test_expect | 119 | IExpectation 全方法 + negation |
| test_mock | 75 | TMock/IMockSetup/IMockVerify + typed CalledWith |
| test_lifecycle | 15 | Setup/Teardown/BeforeEach/AfterEach/Cleanup |
| test_diagnostics | 15 | 错误消息质量 + 字符串差异 |
| test_output | 70 | ANSI/glob/JUnit/leak report |
| test_runner | ~60 | CLI/filter/shuffle/retry/timeout/parallel |
| test_parallel | 8 | 并行执行 + timeout |
| test_subtests | ~10 | Run(RunNested + CleanupTableAllocations |
| test_advanced | ~13 | DiscoverTests/TestFixture/ShouldFail/TestTable |
| **总计** | **~500+** | **0 泄漏**（test_assertions 32B 是 FPC artifact） |
