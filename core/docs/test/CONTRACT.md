# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas`（17 个 .pas + 4 个 .inc）
**层级**：L0-L4（分层架构，详见 README.md）
**Owner**：test lane（`.worktrees/test`）
**最后更新**：2026-07-20
**版本**：v8.12b

---

## 1. 子模块

| 文件 | 职责 | LOC |
|------|------|-----|
| test.pas | 门面：re-export 所有公共 API | ~580 |
| test.base.pas | 基础类型（TTestEntry, TTestStatus, TBenchContext, ETestSkipped, threadvar） | ~913 |
| test.check.pas | 过程式 Check* 断言 API（50+ 方法, 含 OneOf/InstanceOf/Snapshot） | ~1734 |
| test.expect.pas | 流式 IExpectation + TExpectation（40+ 方法 + InstanceOf/MatchSnapshot） | ~1768 |
| test.mock.pas | TMock/TMockState + TMockCaptor + 线程断言 | ~1814 |
| test.config.pas | TTestConfig record（28 字段含 Version）+ IOutputSink + TTestCache + TBufferSink | ~1214 |
| test.runner.pas | TTestSuite/TSuiteRunner + 串行/并行执行 + retry/shuffle/failfast | ~2269 |
| test.runner.cli.pas | CLI 参数解析（--filter, --bench, --cache 等） | ~408 |
| test.runner.parallel.pas | 并行 worker + timeout watchdog | ~580 |
| test.runner.context.pas | TTestContext (ITestContext) + TTestResultAppender + SetEnv/UnsetEnv | ~620 |
| test.discovery.pas | RTTI VMT 方法表扫描自动发现测试 | ~179 |
| test.output.pas | ANSI 辅助、glob 匹配、JUnit XML、泄漏报告 | ~1273 |
| test.output.json.pas | JSON 输出格式 | ~185 |
| test.output.tap.pas | TAP v13 输出格式 | ~123 |
| test.prop.pas | 属性测试 + 模糊测试 + 语料库 + shrinking | ~2928 |
| test.helpers.pas | ExpectFail, WithMock, MakeBufferConfig, WithTempDir, WithTempFile, IntOverflowCheck | ~281 |
| test.bench.pas | 测试框架与 bench 模块集成 | ~206 |

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
  function ToBeNearRel(const AExpected: Double; const ARelEps: Double = 1e-9): IExpectation;
  function ToNotBeNearRel(const AExpected: Double; const ARelEps: Double = 1e-9): IExpectation;
  function ToBeNaN: IExpectation;
  function ToBeNotNaN: IExpectation;
  function ToBeInf: IExpectation;
  function ToBeNotInf: IExpectation;
  function ToBeFinite: IExpectation;
  function ToEqualBytes(const AExpected: TBytes): IExpectation;
  function ToEqualIntArray(const AExpected: array of Int64): IExpectation;
  function ToEqualStrArray(const AExpected: array of string): IExpectation;
  function ToContainInt(const AValue: Int64): IExpectation;
  function ToContainStr(const AValue: string): IExpectation;
  function ToContain(const AValue: Byte): IExpectation;
  function ToBeEmpty: IExpectation;
  function ToBeNotEmpty: IExpectation;
  function ToBeSorted: IExpectation;
  function ToBeOneOf(const AValues: array of string): IExpectation;
  function ToBeOneOfInt(const AValues: array of Int64): IExpectation;
  function ToBeOneOfBool(const AValues: array of Boolean): IExpectation;
  function ToBeInstanceOf(AClass: TClass): IExpectation;
  function ToMatchSnapshot(const ASnapshotDir, ASnapshotName: string): IExpectation;
  function ToMatch(const APattern: string): IExpectation;
  function WithMessage(const AMessage: string): IExpectation;
  procedure ToFailUnexpected(const AMessage: string = '');
end;
```

工厂函数：`Expect(string)`, `ExpectStr`, `ExpectInt`, `ExpectBool`, `ExpectDouble`, `ExpectPtr`, `ExpectProc`, `ExpectObj`, `ExpectBytes`, `ExpectArrayOfInt`, `ExpectArrayOfStr`。

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
  function  Count: Integer;
  function  CalledInOrder(const AMethods: array of string): IMockVerify;
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
  procedure LogF(const AFormat: string; const AArgs: array of const);
  procedure OnCleanup(AProc: TTestProc);
  procedure OnCleanup(AProc: TTestClosure);
  function  GetTempDir: string;
  property  TempDir: string read GetTempDir;
  procedure SetEnv(const AName, AValue: string);
  procedure UnsetEnv(const AName: string);
end;
```

---

## 3. 核心类型

### 3.1 TTestConfig (28 字段)

```pascal
TTestConfig = record
  Version       : Integer;     { 序列化版本号 (0=v8, 1=v9+); 向前兼容 }
  FilterPattern : string;      { --filter: glob 模式匹配测试名 }
  TagFilter     : string;      { --tag: 逗号分隔标签过滤 }
  TimeoutMs     : UInt64;      { 每个测试的超时 (ms) }
  AnsiMode      : TAnsiMode;   { amAuto/amOn/amOff }
  OutSink       : IOutputSink; { 标准输出接收器 }
  ErrSink       : IOutputSink; { 错误输出接收器 }
  RetryCount    : Integer;     { 重试次数 (0=不重试) }
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
  BenchSaveFile : string;      { --benchsave=<file>: 保存 benchmark 结果到 JSON }
  BenchCompareFile: string;    { --benchcompare=<file>: 与基线 JSON 比较 }
  CacheEnabled  : Boolean;     { --cache: 使用测试结果缓存 }
  CacheDir      : string;      { 缓存目录 (默认 .nextpas/test-cache/) }
end;
```

**字段清单（28）**：`Version`, `FilterPattern`, `TagFilter`, `TimeoutMs`, `AnsiMode`,
`OutSink`, `ErrSink`, `RetryCount`, `MaxParallelWorkers`, `RepeatAllCount`,
`SlowTestCount`, `ShuffleSeed`, `FailFast`, `ListMode`, `ShortMode`, `ShowProgress`,
`MaxFailures`, `JsonOutput`, `VerboseMode`, `RunTimeoutSec`, `BenchEnabled`,
`BenchTimeMs`, `BenchMem`, `RunPattern`, `BenchSaveFile`, `BenchCompareFile`,
`CacheEnabled`, `CacheDir`。

**VerboseMode，不是 OutputLevel**：`TTestConfig` **没有** `OutputLevel` 字段。
输出详细程度只由布尔字段 `VerboseMode`（CLI `--verbose`）控制。

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

### 3.3 Cleanup 语义（三层）

框架提供三层清理钩子，作用域和触发时机不同：

| 层 | API | 作用域 | 触发时机 |
|----|-----|--------|----------|
| Suite Cleanup | `Suite.Cleanup(proc)` | suite 级 | **每个**测试结束后运行（等价 Go `t.Cleanup()` 在 suite 上的注册） |
| Test Cleanup | `Ctx.OnCleanup(proc)` | 测试级 | 在测试体内注册，**该测试结束时**运行（LIFO） |
| Setup / Teardown | `SetSetup` / `SetTeardown` | suite 级 | Setup **全部测试前一次**；Teardown **全部测试后一次** |

补充：

- `EachCleanups`（`Suite.Cleanup` 注册）与 `Ctx.OnCleanup` 均按 **LIFO** 执行。
- `BeforeEach` / `AfterEach` 仍是「每个测试前后」钩子；Cleanup 层用于资源释放，
  不要和 Setup/Teardown 的「整 suite 一次」语义混淆。
- 并行模式下，测试级 `OnCleanup` 在各自 worker 线程内执行；
  suite 级 Setup/Teardown 仍在主线程串行执行。

### 3.4 TestTable vs TestSubtest

| API | 用途 | 上下文 | 典型场景 |
|-----|------|--------|----------|
| `TestTable(name, cases, proc)` | 数据驱动：同一 `proc`，不同输入 | **没有** `ITestContext`；回调拿到 `TTestCase` | 大量输入/输出对、表驱动断言 |
| `TestSubtest(name, subtests, proc)` | 命名子测试：每条独立上下文 | 每个 subtest 有独立 `ITestContext` | 分步骤场景、嵌套 `Run`/`RunNested` |

**推荐**：多数测试优先 `Test()` + 闭包。仅在「很多输入/输出对、同一逻辑」时用
`TestTable`；需要逐步命名子结果或嵌套子测试时用 `TestSubtest` /
`ITestContext.Run`。

### 3.5 TSuiteRunner (record)

```pascal
TSuiteRunner = record
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

### 5.1 并行用户责任清单

使用 `Suite.Parallel()` / `RunParallel` 时，**同一进程内共享地址空间**，调用方必须自行保证安全：

1. **禁止无同步的全局可变状态**：并行测试不得读写未加锁的全局/单元级可变变量。
2. **`GStubRegistry` / `GFixtureRegistry` 非线程安全**：只在 `Setup()`（主线程、串行）中注册 stub/fixture；不要在 `Parallel` 测试体内注册。
3. **输出已有 mutex 保护**（框架保证写 stdout/stderr 安全），但**测试本地状态不共享保护**；每个测试应使用局部变量或自备同步。
4. **BeforeEach / AfterEach** 会在多个 worker 上并发调用，同样不得依赖未同步的共享可变状态。
5. **Subtest / Benchmark** 在并行模式下不支持；需要它们时用串行 `Run`。

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

## 8. 浮点比较速查表

| 场景 | Check API | Expect API | 说明 |
|------|-----------|------------|------|
| 小值精确比较 | `CheckEqual(a, b)` | `ToEqualD(a)` | 默认 ε=1e-10 |
| 大值比较 (1e15+) | `CheckNearRel(a, b)` | `ToBeNearRel(a)` | 相对容差 |
| 自定义容差 | `CheckNear(a, b, eps)` | `ToBeNear(a, eps)` | 绝对容差 |
| NaN 检查 | `CheckNaN(v)` / `CheckNotNaN(v)` | `ToBeNaN` / `ToBeNotNaN` | |
| Infinity 检查 | `CheckInf(v)` / `CheckNotInf(v)` | `ToBeInf` / `ToBeNotInf` | ±Inf |
| 有限性检查 | `CheckFinite(v)` | `ToBeFinite` | 非 NaN 且非 Inf |
| 范围检查 | `CheckInRangeD(v, lo, hi)` | `ToBeInRangeD(lo, hi)` | |

**⚠️ 常见陷阱**：
- `CheckEqual(1e15, 1e15 + 1)` 默认会失败！用 `CheckNearRel` 或增大 epsilon
- `ToBeOneOf([])` 空数组始终失败——值不可能是空集的成员

---

## 10. 测试覆盖

> 门禁：`make -C core/tests/nextpas.core.test clean test` → **16/16 suites passed**（2026-07-19）。
> 「测试过程」= 主 suite 报告的 process 数；multi-suite 程序标 multi。不含 stress 内 10K 空测试展开。

| 套件 | 测试过程 | 覆盖范围 |
|------|---------|----------|
| test_assertions | 188 | Check* 全方法 + OneOf/InstanceOf/Snapshot |
| test_expect | 198 | IExpectation + Inf/Finite + InstanceOf + MatchSnapshot + negation |
| test_mock | 112 | TMock + TMockCaptor + 线程断言 |
| test_output | 81 | ANSI/glob/JUnit/TAP/JSON + colored diff + Error vs Failure |
| test_config | 38 | TTestConfig / Builder / TBufferSink |
| test_discovery | 8 | DiscoverTests + TTestFixture hooks |
| test_runner | multi | CLI/filter/shuffle/retry/timeout/cache/summary |
| test_lifecycle | 17 | Setup/Teardown/BeforeEach/AfterEach/Cleanup/TestTable |
| test_prop | ~50 | 属性测试 + 模糊测试 + 语料库 + shrinking |
| test_bench | 22 | RunBenchTest/Suite + CheckBenchPerformance/Throughput |
| test_advanced | 13 | DiscoverTests/TestFixture/ShouldFail/JSON |
| test_diagnostics | 15 | 错误消息质量 + 字符串差异 |
| test_parallel | multi | 并行执行 + timeout + table parallel + lifecycle |
| test_subtests | 15 | Run/RunNested + CleanupCallbacks + SinkPropagation |
| test_stress | 10 | 10K 空测试 + 大字符串 + glob 性能 + 100K 行输出 |
| test_perf_bench | microbench | Expect/Check/Mock 性能回归门禁 |
| test_api_source_contracts | gate | 公开 Check*/To* 必须在自测中出现（Go/Rust 零裸奔） |
| **总计** | **~960+** | **17/17 green**（2026-07-19 v8.8a）；FPC heaptrc 时序伪影见下 |

> **FPC heaptrc 时序说明**：test_lifecycle / test_parallel / test_runner 偶发报告未释放块。
> 经调查为 FPC 编译器管理的记录副本（`TTestSuite`、`TTestRunResult` 等），由动态数组持有；
> 隐式析构在 heaptrc DumpHeap 之后执行。**不是真实泄漏**。

## 10.1 Deferred / Backlog

| 项 | 状态 | 说明 |
|----|------|------|
| `IExpectation` 按类型拆分（`IStringExpectation` / `INumericExpectation` 等） | **暂缓 (P3)** | 向后兼容风险高；`RequireKind` 运行时检查已覆盖类型误用。触发：v9 major 或显式 breaking 窗口，需迁移指南 + consumer 扫描。 |
| 本版本不实现接口拆分 | — | v8.7 仅文档落档，无代码变更 |

## 11. 变更日志

### v8.12b (2026-07-20) — 报告可观测 + 门禁 ≥2000

- **JUnit golden**：Duration=0 固定 fixture + CheckSnapshot
- **TAP formal**：version 13 / plan / YAML / footer totals
- **scale report**：默认 SCALE_MIN=2000；打印 fail-path 启发式占比

### v8.12a (2026-07-20) — 薄套件 + 边界收口

- **Discovery**：fail run、empty run、hooks on fail、双实例、Cleanup 幂等
- **Advanced**：Discover+fail、JSON error、TAP error severity、retry message
- **Assertions**：CheckEqual/NotEqual Double NaN + epsilon 恰界
- **Filter**：hierarchical A/B/C、Test*/Sub、brace 路径边角

### v8.11c (2026-07-20) — 可观测规模与报告

- **Scale report**：`test_scale_report` 自动汇总可计数过程，门禁 ≥1800
- **规模**：diagnostics/expect 有意义负路径表扩张（禁 stress 灌水）
- **Golden**：JSON/TAP Duration=0 固定 fixture + CheckSnapshot
- **Prop shrink**：min 边界、字符串缩短、向 0 收缩

### v8.11b (2026-07-20) — Runner/Lifecycle 深度

- **CLI**：`HasArgFlag` / `ExtractArgValue` / `ExtractArgIntValue` 经 runner 白盒导出；filter/short/shuffle/timeout 表驱动
- **Lifecycle**：Setup fail 体不跑 + `[setup]` tsError；Setup `ETestSkipped` 非失败；Teardown 异常不拖垮 suite；BeforeEach fail 仍跑 AfterEach
- **Parallel subtest**：混合 suite 正常用例 pass + subtest skip 计数与消息

### v8.11a (2026-07-20) — 危险并发契约钉死

- **Mock**：跨线程 `RecordCall` / `GetReturn` / `Verify` 均失败，消息含 `not thread-safe`；`RecordCallTyped` 补 `CheckThread`
- **RegisterStub / RegisterFixture**：非主线程调用 raise，消息含 `main thread`；主线程 RegisterStub OK
- 文档：并行用户责任与自测交叉引用（见 go-rust-parity）

### v8.10 (2026-07-20) — Mock 并行隔离 + Perf 宽松阈值 + Output 深契约

- **Mock**：跨线程 `RecordCall` 必须失败，消息含 `not thread-safe`；同线程仍 pass
- **Perf**：`test_perf_bench` 支持 `--save-baseline` / `--baseline` / `--threshold`（默认 ratio 1.30 = +30%）；`make regression` 可选门禁（非默认 test 硬失败）
- **Output**：JUnit 空/skip/failure 消息；JSON status 枚举；TAP `1..N`；XmlEscape 特殊字符；ANSI off 无 CSI

### v8.9 (2026-07-19) — Go/Rust 第二波：规模 + Helper 语义 + runner 门禁

**v8.9a 规模**：
- `test_output`：64 filter 契约表（约半负路径）
- `test_diagnostics`：+80 fail-path `CheckEqual` 消息契约
- `test_mock`：+10 Verify/Setup 边界与失败路径
- 可计数过程 **≥1500**（排除 stress 10K 空注册）

**v8.9b 语义**：
- **Check/Fail = Fatal**（raise 中止当前测试；无 SoftFail）
- `IsFrameworkFrame` 文档化为 Go `t.Helper` 意图（按 `nextpas.core.test.*` 单元前缀过滤）

**v8.9c 门禁**：
- `test_runner_source_contracts`：TestSeq/RunParallel/CLI/报告等公共名必须出现在自测

### v8.8d (2026-07-19) — Go `-race` 意图：竞态与压力

**并行竞态契约**（`test_parallel`）：
- 8 线程 × 1000 `InterlockedIncrement` → 计数精确 8000
- `TestSeq` 先于并行批完成（`GSeqDone` 可见性）
- 4 线程 Expect/Check 风暴（各 500 次）全 pass
- `RunParallelWithResult` 聚合：Passed+Failed+Skipped = 注册数

**压力**（`test_stress`）：
- 并行 12×2000 `CheckEqual`；并行 8×300 Expect 链（有断言，非空跑）

### v8.8c (2026-07-19) — Go/Rust 规模爬升 ≥1200 可计数过程

**规模**：
- `test_prop`：50 个场景改为 `TTestSuite.Test` 可计数（Shrink 改直接测 API，避免 Prop FailTest/Halt）
- `test_diagnostics`：+150 identity `TestTable`
- `test_config`：+400 identity `TestTable`
- `test_discovery`：+5 元数据过程
- 可计数过程合计 **≥1200**（不含 stress 10K 空测试展开）

### v8.8b (2026-07-19) — Go/Rust 诊断质量：Snapshot 契约 + Diff 消息

**Snapshot 契约**（对齐 insta 更新/严格模式）：
- `NEXTPAS_SNAPSHOT_FAIL_ON_CREATE=1`：缺失快照失败（CI 严格）
- `NEXTPAS_UPDATE_SNAPSHOTS=1`：失配时写回快照
- mismatch 消息改走 `ColorDiff`（与 `CheckEqual(string)` 同一套 position/expected/actual 契约）

**自测**：
- assertions：fail-on-create / update / mismatch diff markers / multiline string equal
- diagnostics：string/int/snapshot 失败消息稳定子串契约

### v8.8a (2026-07-19) — Go/Rust 质量：零裸奔公开 API

**质量门禁**：
- 新增 `test_api_source_contracts`：每个公开 `Check*` / `To*` / `Fail` / `Skip` 必须在自测中出现
- 对标 Go/Rust「导出符号有测试」工程标准（见 `go-rust-parity.md`）

**测试补齐**（v8.7 已合 API 但缺自测）：
- `CheckOneOf` / `CheckOneOfInt` / `CheckOneOfBool`：pass/fail/空集/消息
- `CheckInstanceOf`：pass/类型错/nil 对象/nil 类/消息
- `ToMatchSnapshot`：create+match / mismatch / 类型错

**套件**：16 → **17**（+ source-contract）；`test_assertions` 188→201，`test_expect` 198→201

### v8.7 (2026-07-19) — M1–M4 + 文档收口

**代码（lane 已合入，本版本文档对齐）**：
- **M1**：`ExpectObj` 走对象池；`CheckRaises` 文档澄清（不捕获 `ETestSkipped`）
- **M2**：`CheckOneOf` / `CheckOneOfInt` / `CheckOneOfBool`；`CheckInstanceOf`；`ToMatchSnapshot`
- **M3**：Snapshot fail-on-create（严格模式）；Mock 线程断言
- **M4**：容量增长优化 — 消除 grow-then-truncate 双重 `SetLength`（base/mock/runner）
- 另：StringDiff 边界省略号误导修复；v8.6 后续 P0 审查修复

**文档**：
- README / CONTRACT 版本对齐 v8.7；覆盖表补全 16 套件（含 config/discovery/perf_bench）
- 统计刷新：~930 测试过程；2026-07-19 全量 16/16 绿
- Deferred：`IExpectation` 类型拆分明确暂缓
- `test-findings.md` 历史 banner + 过时对标项状态更新

### v8.6 (2026-07-12) — F2：Expect Inf/Finite API 补齐

**新增**：
- `IExpectation.ToBeInf` / `ToBeNotInf` / `ToBeFinite`：与 `CheckInf`/`CheckNotInf`/`CheckFinite` 对称
- `IntOverflowCheck(AValue, AOp, AOperand)`：helpers 工具，检测 Int64 加减乘是否会溢出（非断言）
- `test_expect` 自测：Inf/NotInf/Finite pass/fail + `Not_.ToBeInf`/`Not_.ToBeFinite` + IntOverflowCheck

**更新**：
- CONTRACT §2.2 IExpectation 接口列表
- §8 浮点速查表 Expect 列不再「待补」

### v8.5 (2026-07-12) — 可用性文档缺口 F3/F4/F5

**文档**：
- `TTestConfig` 字段数 23 → **28**，列出完整字段；明确 **无 `OutputLevel`**，仅 `VerboseMode`
- 补充 Cleanup 三层语义：`Suite.Cleanup` / `Ctx.OnCleanup` / `Setup`·`Teardown`
- 补充并行用户责任清单（全局状态、`GStubRegistry`/`GFixtureRegistry`、输出 mutex）
- 补充 `TestTable` vs `TestSubtest` 选用指南

### v8.4 (2026-07-11) — M4 heaptrc 时序调查 + 文档更新

**调查结论**：
- test_lifecycle(5 blocks/896B)、test_parallel(75 blocks/14KB)、test_runner(17 blocks/3KB) 报告未释放块
- 根因：FPC 编译器管理的记录副本（TTestSuite=272B、TTestRunResult=40B），由动态数组 `TSuiteRunner.Suites: TArray<TTestSuite>` 持有
- 编译器隐式析构在 heaptrc DumpHeap 之后执行，`Default()` 提前归零不能减少计数
- 结论：非真实泄漏，是 FPC heaptrc 时序伪影

### v8.3 (2026-07-11) — API 一致性补齐 + 测试覆盖 + 边界条件

**新增**：
- `CheckEmpty`/`CheckNotEmpty`：字符串和字节数组空值检查（4 个重载 + 4 个带消息重载）
- `CheckInf`/`CheckNotInf`/`CheckFinite`：浮点无穷大和有限性检查
- `ToBeSorted`：IExpectation 排序检查（支持 Int64 数组和字符串数组）
- `test_config` 测试套件（38 tests）：完整覆盖 TTestConfig 默认值、TTestConfigBuilder 全部 22 个 With* 方法、TBufferSink、MakeBufferConfig
- `test_discovery` 测试套件（8 tests）：完整覆盖 DiscoverTests + TTestFixture BeforeEach/AfterEach
- `test_assertions` 新增 19 个测试：CheckEmpty/NotEmpty + CheckInf/NotInf/Finite
- `test_expect` 新增 9 个测试：ToBeSorted Int64/字符串通过/失败/空/单元素/相等/否定

**更新**：
- CONTRACT.md 版本 v8.2 → v8.3
- README.md API 参考表新增 CheckEmpty/CheckNotEmpty/CheckInf/CheckFinite/CheckSorted/CheckIsNil/CheckIsNotNil
- 测试套件数 13 → 15

### v8.2 (2026-07-11) — test.bench 测试覆盖 + helpers 增强

**新增**：
- `test_bench` 测试套件（22 tests / 53 assertions）：完整覆盖 `nextpas.core.test.bench` 全部公共 API
  - `DefaultBenchTestConfig` 5 个默认值验证
  - `RunBenchTest` 6 个测试（执行/名称/NsPerOp/OpsPerSec/迭代数/MaxIterations）
  - `RunBenchSuite` 3 个测试（多条目/全执行/空套件）
  - `CheckBenchPerformance` 3 个测试（通过/失败/未执行）
  - `CheckBenchThroughput` 3 个测试（通过/失败/未执行）
  - 自定义消息转发 2 个测试
- `WithTempFile` 辅助函数：创建临时文件、执行回调、自动清理（与 `WithTempDir` 对称）

**更新**：
- CONTRACT.md 测试覆盖表从 ~500+ 更新为 819 测试过程 / 2276 断言（精确计数）
- `test.helpers.pas` 行数更新 ~178 → ~195

### v8.1 (2026-07-11) — 第二轮深度审查

**P2 整改项**：
- **P2-3**: TTestConfig 添加 `Version` 字段（向前兼容序列化）+ `GetConfigVersion` 访问器
- **P2-4**: `MatchesGlob` brace expansion 使用 `BuildAlt` 单次分配替代 `Copy+Copy+Copy`
- **P2-5**: `GTempDirCounter` 类型从 `Integer` 修正为 `LongInt`（匹配 `InterlockedIncrement` 签名）
- **P2-6**: `MatchingCallCount` 添加 `ArgHash` 预计算，O(n×m) → O(n) 常见情况
- **P2-7**: 所有 `Shrink*` 递归函数添加 `ADepth > 100` 迭代上限保护

**新增改进**：
- 提取 `CheckArrayContainsStr`/`CheckArrayContainsInt` 公共函数，消除重复的列表构建逻辑
- `CheckEqual`/`CheckNotEqual` 的 Pointer/UInt64/TBytes 重载补全 `AMessage` 参数
- `GTempDirCounter` 注释澄清原子语义
