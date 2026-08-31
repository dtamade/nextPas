# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas`（17 个 .pas + 4 个 .inc）
**层级**：L0-L4（分层架构，详见 README.md）
**Owner**：test lane（`.worktrees/test`）
**最后更新**：2026-08-31
**版本**：v8.31
**路线图**：`quality-scale-roadmap.md`（v8.26+ 质量/规模全权序列）
**审计 remediation**：`v8.31-findings-remediation-plan.md` / `findings.md`

---

## 0. SoftFail / SoftCheck* 能力矩阵（v8.27）

| API | 状态 | 诊断 | 说明 |
|-----|------|------|------|
| `SoftFail(msg)` | **done** | 原文 join（`; `） | outside context → raise |
| `SoftCheckTrue` / `SoftCheckFalse` | **done** | 默认文案 | |
| `SoftCheckEqual(Int64)` | **done** | expected/actual 一行 | |
| `SoftCheckEqual(string)` | **done** | **ColorDiff**（与 CheckEqual 同契约） | v8.23 |
| `SoftCheckEqual(Boolean)` | **done** | expected/actual | v8.23 高频 |
| `SoftCheckEqual(TBytes)` | **done** | length / index + hex | v8.23 高频 |
| `SoftCheckNear(Double)` | **done** | epsilon + diff / NaN | v8.23 高频 |
| `SoftCheckContains` | **done** | needle/haystack | |
| `SoftCheckNil` / `SoftCheckNotNil` | **done** | 与 CheckNil/NotNil 同 detail | v8.27 |
| `SoftCheckEmpty(string)` | **done** | length char(s) | v8.27 |
| `SoftCheckContainsCI` | **done** | ci needle/haystack | v8.27 |
| Soft 消息 join + ColorDiff 换行 | **done** | 段间仍 `; `；ColorDiff 内可含 `#10` | v8.27 B59 |
| Soft × MaxFailures / FailFast | **done** | Soft-only 不 FailFast 停；计 MaxFailures | v8.27 B58 |
| SoftCheck* 全镜像 Check* | **不做** | — | 仅高频子集；其余用 SoftFail |
| SoftExpect fluent | **暂缓** | — | 见 v9 / M7 |
| Nested SoftFail Push/Pop | **done** | leaf/parent 分层 | v8.21 |

---

## 1. 子模块

| 文件 | 职责 | LOC |
|------|------|-----|
| test.pas | 门面：re-export 所有公共 API | ~625 |
| test.base.pas | 基础类型（TTestEntry, TTestStatus, TBenchContext, ETestSkipped, threadvar） | ~1129 |
| test.diff.pas | ColorDiff 共享着色 diff（L0, v8.31 F-01） | ~112 |
| test.check.pas | 过程式 Check* 断言 API（50+ 方法, 含 OneOf/InstanceOf/Snapshot） | ~1897 |
| test.expect.pas | 流式 IExpectation + TExpectation（40+ 方法 + InstanceOf/MatchSnapshot） | ~1768 |
| test.snapshot.pas | CheckSnapshot 共享实现（L1, v8.31 F-02） | ~92 |
| test.mock.pas | TMock/TMockState + TMockCaptor + 线程断言 | ~1824 |
| test.config.pas | TTestConfig record（28 字段含 Version）+ IOutputSink + TTestCache + TBufferSink | ~1238 |
| test.runner.pas | TTestSuite 注册 + 串行/并行执行 + retry/shuffle/failfast | ~1994 |
| test.runner.multi.pas | TSuiteRunner 多 suite 编排 + banner/list/summary（v8.33 拆分） | ~402 |
| test.runner.cli.pas | CLI 参数解析（--filter, --bench, --cache 等） | ~430 |
| test.runner.parallel.pas | 并行 worker + timeout watchdog | ~598 |
| test.runner.context.pas | TTestContext (ITestContext) + TTestResultAppender + SetEnv/UnsetEnv | ~667 |
| test.discovery.pas | RTTI VMT 方法表扫描自动发现测试 | ~285 |
| test.output.pas | ANSI 辅助、glob 匹配、JUnit XML、泄漏报告 | ~1260 |
| test.output.json.pas | JSON 输出格式 | ~185 |
| test.output.tap.pas | TAP v13 输出格式 | ~123 |
| test.prop.gen.pas | 生成器接口/工厂/组合器（v8.32 F-03 拆分） | ~1368 |
| test.prop.pas | Prop 注册 + shrink 执行循环 | ~457 |
| test.fuzz.pas | 模糊测试 + 语料库 + 覆盖追踪 + 多策略（v8.32 F-03 拆分） | ~1175 |
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
| CLI 可注入 argv（`ApplyCLIArgsFrom`） | **done (v8.13)** | 与 ParamStr 解耦，表驱动可测 |
| perf 跨机硬门禁入库 | **不做** | 仅软策略：`PERF_SKIP` / host baseline；跨 OS 数字不作默认 CI fail |
| SoftFail / SoftCheck* | **done (v8.16)** | opt-in Go t.Error；Check*/Fail 仍 Fatal |
| `IExpectation` 按类型拆分 | **暂缓 (v9)** | 兼容风险高；`RequireKind` 已覆盖类型误用 |
| TSAN | **阻塞** | 无 FPC 一体化 ThreadSanitizer 路径；靠契约测与原子压力 |
| 编译器 coverage 插桩 | **阻塞** | 等 nextpas 编译器；现有 fuzz 软覆盖点非源码覆盖 |

## 11. 变更日志

### v8.41 (2026-07-26) — mock 双轨匹配修复 + verify/matching/dispatch 契约表（B78 tranche 8）

- **产品修复：`MatchingCallCount` 跨轨 hash 门错杀**（mock.pas）。
  string-domain 查询的 hash 用 `MockValueHash(MockStr(...))` 计算，却与
  记录时按 **typed kind** 域算出的 `ArgHash` 比较——kind 参与 hash
  （`MockStr('5')`=32 vs `MockInt(5)`=67 恒不等）→ 提前 `Continue`，
  后续 legacy `Args` 字段比较永远不达。后果：`RecordCallTyped('M',[MockInt(5)])`
  后 `CalledWith(['5'])` 必失败，而 `TestRecordCallTypedPreservesLegacyArgs`
  证明 legacy Args 渲染是既定契约——P2 #6 hash 加速引入的真回归。
  修复：`TMockCall` 增设 `StrArgHash` 双 hash 字段（RecordCall 两域同值；
  RecordCallTyped 按 `MockStr(渲染串)` 补算），string 查询门改比 `StrArgHash`。
  typed 轨（`MatchingCallCountTyped`）仍比 `ArgHash`，kind-strict 语义不变
- **文档矛盾修复**：test_mock.lpr 头注释宣称 Verify 走 `CompareText`
  （case-insensitive）；probe 实证 `CallCount` 是精确 `=` 比较（case-SENSITIVE），
  注释改为与实现一致（行为不动）
- **test_mock 四张契约表（54 行，其中 22 行 fail-path）**，全部消息 exact：
  - `verify count-message matrix`（14 行，8 fp）：qualifier 词汇
    exactly/at least/at most；CalledNever=exactly 0、Times=CalledExactly 同义；
    **detail 三态**——有调用列 `calls to <m>:`、方法未调用列
    `all recorded calls:`（帮抓 typo）、零调用无 detail
  - `CalledWith dual-rail matrix`（16 行，7 fp）：**b-bridge-int/bool 两行
    直接锁本次修复**（typed 记录 → string 验证经 legacy Args 桥接）；
    typed 轨 kind-strict（`MockStr("5")`≠`MockInt(5)`）；消息不对称——
    string 轨带 `(first actual call: ...)`、typed 轨仅 `(total calls: N)`；
    CalledExactlyWith 措辞 `times`（含 "1 times"）+ `xw0` never-with 惯用法；
    first-actual 渲染 arity-blind（列首个同名调用全参）
  - `call-order matrix`（12 行，7 fp）：Before/After 三失败态带 exact index
    （self-never 先判）；首次出现语义；同名退化边 `A was called at index 0
    (after A at index 0)`；CalledInOrder 贪心子序列（空数组恒过、重名消耗、
    I=0 前驱名 `<start>`）
  - `When/Returns dispatch + reset`（12 行）：后注册 When 胜出
    （High downto 0）；When miss 回退默认 Returns（无默认=''）；
    GetReturnInt64 kind 回退经字符串解析（bool 'true'→0）；GetReturnBool
    `SameText`；Returns 原位覆盖；Reset 保 setup 清 calls、ResetAll 全清
- probe 先行实证 27 场景（/tmp/mock_probe，不入库）；54 行零修正一次全绿
  （第 7 个连续 tranche）
- heaptrc unfreed 4182 vs 基线 4020：+162 = 3 块/行 × 54 行，
  与 v8.35 记录的表注册数据线性模式一致，非新泄漏
- scale：countable 8085 → **8140**（test_mock 1430→1485）；
  fail-path 80.7% / low-signal 0% / non-table 1736

### v8.40 (2026-07-26) — FuzzMinimize 公开化 + minimize 契约表（B78 tranche 7）

- **架构收口：`FuzzMinimize` 公开化**（fuzz.pas interface + 门面 re-export）。
  此前它是 fuzz 家族唯一私有的核心算法，且只在 Fuzz/FuzzWithCorpus/
  FuzzMultiStrategy 的失败路径被调用——**算法自身零测试覆盖**（正确性只能
  透过 fuzz 失败消息间接观察）。公开签名：
  `function FuzzMinimize(const AData: TBytes; ATest: TFuzzBytesTest): TBytes`
- **公开语义（interface 注释 + 表锁定）**：确定性两阶段贪心收缩——
  phase 1 反复保留前 ceil(n/2) 字节（首个 pass 前缀即停，不试更细粒度，
  非 ddmin）；phase 2 从左到右单字节删除，删除被接受后重试同一 index。
  **只认 EAssertionFailed 为"仍失败"**，其他异常穿透传播；非失败输入
  原样返回；结果是单字节删除意义下的 1-minimal，非全局最小
- **test_prop 三张契约表（35 行，其中 22 行 fail-path）**：
  - `minimize exact result`（17 行）：输出 hex + probe 次数 exact；
    **空/单字节输入 0 probe 原样返回**（输入本身从不被复验）；
    失败但已 1-minimal 的输入（m-sum10-min：sum≥10 的 `0505`）也原样返回；
    `m-boom` 行锁非 EAssertionFailed 异常穿透（`Exception: kaboom`，1 probe）
  - `minimize probe sequence`（10 行）：谓词收到的**完整探测序列 exact**
    （','-join hex）——锁两阶段顺序：先对半前缀链、后单字节删除；
    被拒绝的删除探测出现在序列中但结果被丢弃
  - `minimize len-threshold matrix`（8 行，len≥k × k=2..9 固定 8 字节输入）：
    锁两阶段交互——k>4 时幸存者是原串**最后 k 字节**（phase 1 未收缩、
    phase 2 从前修剪）；k≤4 时是对半链前缀残余；k=8 探测全部删除但
    无法收缩；k=9 永不失败原样返回
- 表行 flag 自校验：'0' ⟺ 发生收缩（wantOut≠wantIn）；escape 行强制 '0'
- 已知陷阱记录：`make test` 二次调用（FPC 增量读回 PPU）触发 ICE——
  基线复现确认为既有 FPC 陷阱非本版引入；clean 路径恒绿
- scale：countable 8050 → **8085**（test_prop 421→456）；
  fail-path 81.2% / low-signal 0% / non-table 1681

### v8.39 (2026-07-26) — B78 密度 tranche 6：subtest 聚合/收集/env 隔离契约表

- **test_subtests 四张契约表（48 行，其中 27 行 fail-path）**，spec 驱动树构建
  （token：p/f/s/e/l/m 叶 + A/B 嵌套节点；`TSubtestProc` 为普通过程指针 →
  嵌套节点用全局 spec + 静态 proc，叶用 `Ctx.Run` 闭包）：
  - `subtest aggregate message`（14 行，11 fp）：聚合消息 exact——
    `N subtest(s) failed in <parent>: <名单>`；名单为**全路径**、`', '` join、执行序；
    **嵌套失败逐层折叠为直接子节点名**（深链 root/a/b/f1 →
    "failed in root/a/b: root/a/b/f1" → "failed in root/a: root/a/b" →
    "failed in root: root/a"）；error 叶消息 `ClassName: Message` 计入名单
  - `subtest result collection`（13 行，9 fp）：**pass 的 subtest 节点不进 Results**
    （仅 fail/error/skip 叶与失败节点收集）；post-order（叶先于其父）；
    root 条目恒在 Results[0]；CapturedLog 仅 fail/error 复制；
    **root 失败条目携带最后一个失败叶的 log 残留**（已锁为契约）
  - `subtest suite counters`（9 行，5 fp）：subtest 内部 pass/skip 对 suite 级
    Passed/Skipped **不可见**；整条 TestSubtest 失败恰计 1 Failed（与叶数无关）；
    与 plain Test 混排计数正交
  - `subtest env isolation`（12 行，2 fp）：**SetEnv/UnsetEnv 此前零测试覆盖**
    （公开 API 裸奔收口）。RestoreEnvVars **逆序恢复**——double-set 恢复
    **原始值**（非中间值）；`platform_env_exists` 区分 empty 与 missing
    （'~'=空串 / '-'=不存在哨兵）；**测试失败后仍完整恢复**（restore-after-fail）；
    missing/empty/orig × set/unset/double-set 全矩阵
- 「sibling pass 计数丢失」经 probe 实证**非外部可见 bug**：叶结果经 FOnResult
  即时推送，父层 FSubPass 仅内部聚合用——记录为设计事实而非缺陷
- 表行 flag 自校验：A/C 表 wantOk='F' ⟺ '0'；B 表 status∈{1,3} ⟺ '0'；
  D 表 inFail='F' ⟺ '0'
- scale：countable 7997 → **8050**（test_subtests 93→146）；
  fail-path 81.3% / low-signal 0% / non-table 1646

### v8.38 (2026-07-26) — B78 密度 tranche 5：bench/discovery 契约表 + %.0f 尾点修复

- **修复（跨模块 text.format）**：`FormatFloat` 在小数位数 0 时无条件追加 `'.'`——
  `TextFormat('%.0f', [5.0])` 渲染 `"5."`（C printf 语义应为 `"5"`；巨值分支走
  `Str(:0:0)` 无尾点，行为自相矛盾坐实 bug）。修复后 `%.0f` → 无小数点；
  `%.1f`/`%f` 不受影响。影响面：全仓 `%.0f` 消费者仅 `bench.report` + `test.bench`
  （无 golden/exact 断言依赖尾点；text_conv 此前无任何 `%.0f` 用例）。
  回归绑定：`b-t-below` 行消息 exact（修复前为 `"25. ops/s"` 必红）
- **test_bench 两张契约表（35 行，其中 16 行 fail-path）**：
  - `CheckBench decision matrix`（22 行，合成 `TBenchTestResult` 记录、零计时依赖）：
    **Executed=False 时指标达标也必败**（且默认消息仍是误导性的 "exceeds/below"——
    消息本身即锁定契约）；**Skipped 字段被判定完全忽略**（skip+executed 可 pass）；
    `<=`/`>=` 闭边界（metric=threshold → pass）；自定义消息完全覆盖默认（含
    NotExecuted 场景）；失败消息 exact（`%.1f`/`%.0f` 渲染）；舍入陷阱行
    `b-t-round-half`：49.5 经 `%.0f` half-away 渲染为 `"50"`，消息读作
    "50 ops/s below threshold 50 ops/s" 而数值比较仍败——渲染与判定分离已锁
  - `bench structure contract`（13 行）：`DefaultBenchTestConfig` 五字段 exact
    （100/5/0/5000/1）；`RunBenchSuite` 空条目 → nil（len 0）；双条目保序 +
    Name 传播（alpha/beta）；`RunBenchTest` Name 回传 + Executed/Skipped 旗标
- **test_discovery 两张契约表（22 行，其中 9 行 fail-path）**：
  - `discover filter matrix`（12 行，spec 驱动 crafted backend）：
    **`Name=''` 或 `CodeAddr=nil` 条目静默跳过**（过滤保序 + 原位置号：
    `v,e,n,v` → `M1,M4`）；backend 枚举失败（False）→ 空套件；
    套件名 `''` → ClassName 回退 / 显式名覆盖
  - `VMT backend enumeration`(10 行)：nil class → False；无 published
    （TObject/TTestFixture/TEmptyFixture）→ True+空枚举；**名序=声明序**
    （TSimpleFixture/THooksFixture/TFailFixture exact）；`SetDiscoveryBackend(nil)`
    → 重置为 FPC VMT；枚举产物地址全非 nil
- 表行 flag 自校验：CheckBench '0' ⟺ 失败行；structure/discovery '0' ⟺ 空/零值行
- scale：countable 7938 → **7997**（test_bench 71→106、test_discovery 113→134；
  fp +25：16+9）；fail-path 81.7% / low-signal 0% / non-table 1593

### v8.37 (2026-07-26) — B78 密度 tranche 4：retry/repeat 执行语义 + fuzz 可观测契约

- **修复**：`FuzzGenString` 字符域 off-by-one——`NextIntRange(0,95)`（闭区间）可产
  Char(127)=DEL，与 "printable ASCII" 注释矛盾；改为 `(0,94)` → 32..126。
  回归绑定：`g-str-printable` 行（4096 长度全字符 ∈[32,126]，修复前必红）
- **test_advanced 两张矩阵表（36 行，其中 19 行 fail-path）**，锁定 runner 执行语义：
  - `retry execution matrix`（26 行）：三个此前未文档化的契约——
    1. **entry RetryCount=0 视为未设置**，回退 `config.RetryCount`（0 无法显式禁用）；
    2. **负 RetryCount 是唯一 opt-out**：非 0 不回退 config 且首轮后立即停止；
    3. retry 循环仅对 tsPassed/tsSkipped 提前 Break——**tsError 也重试**；
    skip 首轮即停不重试；执行次数 exact（fail-always + R 重试 = 1+R 次）
  - `repeat execution matrix`（10 行）：fail 不中断轮次、**报告最后一轮结果**
    （首轮败末轮过 → passed）、`TestRepeat` entry.RetryCount 恒 0 →
    config.RetryCount 每轮内嵌套生效（execs = N × (1 + configR)，3×(1+2)=9 已锁）；
    skip/error 同样不中断轮次
- **test_prop 两张契约表（33 行，其中 8 行 fail-path）**：
  - `coverage tracker state machine`（24 行）：ops 微语言（`h<id>`/`r` 序列）——
    **TotalHits 与 CoverageCount 分离**（Hit 先计 hits 再做 [0..32767] 范围检查，
    越界计 hits 不计 count 也不置 new）、bitset byte/bit 边界（7/8/15/32767）、
    Reset 后重复 Hit 不置 new、越界后有效 id 继续正常计数
  - `fuzzgen length contract`（9 行）：产物长度 = 入参 exact（0 → 空）；
    printable 范围行绑 DEL 修复；**负长度 = FPC SetLength RTE 201**（非异常路径，
    调用方责任，不表驱动——实验确认，文档即契约）
- 表行 flag 自校验：retry/repeat '0' ⟺ 非 pass 结果；coverage '0' ⟺ 零覆盖；
  fuzzgen '0' ⟺ 空产物——防标签灌水
- scale：countable 7867 → **7938**（test_advanced 68→104、test_prop 388→421；
  fp +27：19+8）；fail-path 81.9% / low-signal 0% / non-table 1534

### v8.36 (2026-07-26) — B78 密度 tranche 3：prop.gen shrink 精确序列 + Name 词汇表

- **test_prop 四张契约表（85 行，其中 31 行 fail-path）**，全部绑 prop.gen 真实算法
  （区别于 B71 的性质断言——本批断言**精确候选序列**）：
  - `int-shrink exact-sequence`（28 行）：`[target, mid, step, quarter]` 序列 +
    域夹紧/去重剪枝；域外输入 → 单边界候选；value=target → 空序列；
    **跨零域重复候选为锁定行为**（`Shrink(1)=[0,0,0]`：mid/step 不与 target 查重）；
    负数 `div` 向零截断语义（`-999997 div 2 = -499998`）
  - `string-shrink exact-sequence`（16 行）：8 策略序列（empty/half/drop-last/
    all-a/drop-first/drop-middle/shorter-a/half-a）逐一受 FMinLen 门控；
    域外 pad 'a' 或截断；all-a 恒在域内（len=minlen 时唯一候选）
  - `bytes-shrink exact-sequence`（12 行）：**仅 3 策略**（empty/half/drop-last，
    无 all-a 类似物）；`len=FMinLen` → 零候选（string 系有 all-a 兜底而 bytes 无）；
    域外低 → FillChar 零填充、域外高 → 截断
  - `generator meta contract`（29 行）：16 个生成器 Name 词汇表（含嵌套组合名
    `MapIntToStr(GenInt(0..5))`、单参重载默认 min=0、`GenOneOfString(1 generators)`
    单复数不分）+ bool shrink 恒 `[False]`（False 不动点仍产出候选）+
    choice shrink 保数组序过滤 `< input`（域外输入全集通过、最简值空序列）+
    filter shrink 对源序列施谓词（可滤至空）
- 表行 flag 自校验：'0' 行强制 ≤1 候选/边界 kind，'1' 行强制完整序列——防标签灌水
- scale：countable 7781 → **7867**（test_prop 302→388，fp 244→275）；
  fail-path 82.3% / low-signal 0% / non-table 1463；SCALE_MIN 维持 7500（9000 待密度达标）

### v8.35 (2026-07-26) — B78 密度 tranche 2：output 转义/结构 fail-path

- **test_output 四张契约表（92 行，其中 51 行 fail-path）**，全部绑 formatter 真实行为：
  - `junit xml-escape fail-path`（26 行）：XmlEscape 五实体（`&amp;/&lt;/&gt;/&quot;/&apos;`）、
    双重转义（`&amp;`→`&amp;amp;`）、控制字符折叠为空格（#9/#10/#13 除外，穿透）、
    failure `message=` 属性无条件输出（含空串）；notwant 断言原始未转义形不得出现
  - `json-escape fail-path`（24 行）：JsonEscape 短转义（`\"` `\\` `\b` `\t` `\n` `\f` `\r`）、
    其余 ctrl<32 → `\u00XX` 大写十六进制、`/` 与 #127 穿透；
    `message` 字段仅非空输出、name 无条件输出
  - `tap structure fail-path`（20 行）：plan `1..N`（含 `1..0`）、ok/not ok 编号、
    YAML failure block（`---`/message/`severity: fail|error`/`...`）、skip directive
    （`# skip <msg>`）、footer 计数——**footer 读 suite 计数字段而非遍历
    Results[].Status，`# passed` 为推导值（total−failed−skipped），tsError 按
    IncByStatus 语义计入 Failed**（合成结果须双轨维护 Status + 计数字段）
  - `format-duration contract`（22 行）：`<1s`→`Nms`、整秒→`Ns`、`N.Ds`/`N.DDs`
    截断非四舍五入（1234→`1.23s`、1999→`1.99s`）、负值穿透（-1→`-1ms`）
- scale：countable 7686 → **7781**（test_output 151→246，fp 17→68）；
  fail-path 82.9% / low-signal 0% / non-table 1377；SCALE_MIN 维持 7500（9000 待密度达标）

### v8.34 (2026-07-26) — F-12 COW lint + runner.multi 编排契约密度

- **F-12 收口**：`test_runner_source_contracts` 新增 COW lint —— 静态检测
  「`Runner.Add(Suite)` 之后继续在原 suite 上注册/改配置且未 re-Add」的丢改陷阱
  （TTestSuite 是 record，Add 深拷贝快照）；扫描 tests + examples 全部 `.lpr/.pas`；
  故意的契约测试用 `{ cow-lint-ok }` 行内注释豁免；整记录重赋值视为新副本
- **TSuiteRunner 编排契约**（test_runner M1–M3，绑 v8.33 拆出的 runner.multi）：
  - M1a–M1e 定点契约：初始状态零值；空 runner RunAll；**Add 深拷贝快照**
    （F-12 正向契约：Add 后注册的测试不进 runner，原 suite 自身仍可运行全部）；
    ListMode 只列出不执行、不置 HasRun；`AllPassed` 惰性触发 RunAll 且缓存；
    Summary 输出格式（`=== Summary ===`/`Suites: N`/pass-rate/`=== Failures ===` 明细）；
    LastResults/TotalDuration=各 suite Duration 之和；**config 取第一个 suite**（RunnerConfig）
  - M2 聚合矩阵 54 行 fail-path：p/f/s 三 suite 组合 × n∈{1,2}，断言 RunAll 布尔值、
    TotalPass/Fail/Skip 聚合、结果数组长度、执行计数
  - M3 停止矩阵 12 行 fail-path：FailFast / MaxFailures∈{1,2} × 失败位掩码，
    断言**实际执行的 suite 数**（stop 语义读第一个 suite 的 config）
- scale：countable 7609 → **7686**（test_runner 313→390，fp 143→209）；
  fail-path 83.2% / low-signal 0% / non-table 1282；SCALE_MIN 维持 7500（9000 待密度达标）

### v8.33 (2026-07-26) — runner god-unit 拆分 + F-20 测试语义修正

- **runner 拆分**：`test.runner.pas`（2369 行）拆出 `test.runner.multi.pas`（~402）—
  `TSuiteRunner` 多 suite 编排 + `WriteRunnerBanner`/`WriteListMode`/`RunnerConfig`；
  runner.pas 收敛为 TTestSuite 注册 + 执行引擎（~1994）
- 依赖方向：`runner ← runner.multi`（multi 消费 TTestSuite 公共 API，无反向依赖）
- 门面 API **不变**：`TSuiteRunner` 别名重定向到 `runner.multi`；直接 uses
  `nextpas.core.test.runner` 拿 TSuiteRunner 的消费者需改 uses（仓内 0 个：全部经门面）
- **F-20 遗留修正**：test_parallel 的 R6-54/B10 两测试仍断言旧「静默 skip」语义，
  与 v8.31 F-20「配置期 fail-fast」冲突（**v8.31 起即红**，被 heaptrc 噪声掩盖）；
  改为断言 config failure（Passed=0 / Failed≥1 / AllPassed=False）

### v8.32 (2026-07-26) — prop god-unit 拆分（F-03 收口）

- **F-03**：`test.prop.pas`（2938 行）拆为三个单一职责单元：
  - `test.prop.gen.pas`（~1368）— 生成器接口/工厂/组合器；各生成器自持 `TRandomGen`，无全局态
  - `test.prop.pas`（~457）— Prop 注册 + shrink 执行循环
  - `test.fuzz.pas`（~1175）— Fuzz/Corpus/Coverage/Structured/MultiStrategy + `GFuzzRng` threadvar
- 依赖方向：`prop.gen ← prop`、`prop.gen ← fuzz`（均 L4 内）；fs/config 依赖收敛到 fuzz
- 门面 API **不变**：`nextpas.core.test` 别名/转发重定向到新单元；外部消费者零改动
- **F-07 残余收口**：门面补 `FuzzMultiStrategy` re-export（此前只导出 deprecated 的 `FuzzParallel`）；
  test_prop 新增门面限定的规范名测试，deprecated 别名保留回归测

### v8.31 (2026-07-26) — Findings 全量 remediation（F-01…F-25 可落地项）

- **F-01/F-02**：`test.diff`（ColorDiff L0）+ `test.snapshot`（共享 CheckSnapshot）；check 不再依赖 output；expect 不再依赖 check
- **F-05/F-11**：移除默认 `GetFPCHeapStatus`；`SetHeapProbe`/`NoteHeapBaseline` 可选 delta 泄漏警告
- **F-06**：Coverage 警告改 ErrSink（无 `WriteLn(StdErr)`）
- **F-07**：`FuzzParallel` 标注 **NOT parallel** → `FuzzMultiStrategy`
- **F-08**：`GFuzzRng` threadvar + in-place 更新（修 record 拷贝失效）
- **F-10**：`TMock.GetCallHistory` CheckThread
- **F-13**：scale `MIN_NON_TABLE`；advanced/bench fail-path 表
- **F-15/F-16**：`docs/contracts/test.md` 改为指针；Double=`CheckNear`
- **F-19**：Discovery 固定名表 stub 测
- **F-20**：`RunParallel` 遇 TestSubtest **配置期失败**（非静默 skip）
- **F-03 分期**：prop 大拆分 backlog；本版仅 RNG/文档

### v8.30 (2026-07-26) — Prop/Fuzz/Snapshot 工程密度 + SCALE≥7500（B71–B75）

- **B71**：shrink 确定性表（int/str/bytes）+ PropWithResult 反例边界 + PropFail ExpectFail 针
- **B72**：corpus 空/缺目录/空 bin/junk/OOB/roundtrip/dup 边界表（80）
- **B73**：Snapshot match/mismatch/ColorDiff/fail_create/update 表（100）
- **B74**：`SCALE_MIN=7500`，`LOW_SIGNAL_MAX_RATIO=0.25`
- **B75**：消费者 `table_driven_demo`（TestTable + SoftCheck + TestSubtest）

### v8.29 (2026-07-26) — 并行竞态与 Mock 误用密度（B66–B70）+ G1 治理

- **B66**：parallel hard-fail/Expect/Soft fail-path 表（120）+ Expect storm 全员失败计数 exact
- **B67**：Mock 跨线程 ops 扩 Setup/VerifyInOrder/CalledAtLeast/ResetCalls；产品侧 `CheckThread` 补齐；CalledExactly/InOrder 负路径表
- **B68**：RegisterStub/Fixture 非主线程消息 **exact prefix** + `tid=`/`expected=` 表（80）
- **B69**：TimeoutWorkerLeaks 只读契约（serial+parallel 清零）；**不**模拟 stuck worker（防 flaky CI）
- **B70**：双 `TestSeq` marker + 结果名在 `RunParallelWithResult` 可见
- **G1**：`contracts` 默认门禁文档；`lane_gate` + `make lane-focused LANE=test`；禁止新迷你 runner

### v8.28 (2026-07-21) — Runner / Subtest / CLI ≈ Go testing（B61–B65）

- **B61**：≥3 层 `RunNested` SoftFail 分层 exact（leaf 独立；parent 不吞 leaf 文案）
- **B61 fix**：`ApplySoftFails` 在 also-soft 路径也返回 True；failed nested `RunNested` 一律进 `RunWithResult.Results`
- **B62**：hierarchical filter 负路径表（`Parent/Sub/*`、brace、glob 段）
- **B63**：CLI `--short`/`--failfast`/`--failures-max`/`--count` 交叉表
- **B64**：`IsFrameworkFrame` 导出 + 单元前缀契约表（Go t.Helper 意图）
- **B65**：parallel `TestTable` Skip 计数 exact；ShortSkip+Table 计数 exact

### v8.27 (2026-07-21) — Soft 第二波 + 诊断 golden（B56–B60）

- **Soft API**：`SoftCheckNil` / `SoftCheckNotNil` / `SoftCheckEmpty(string)` / `SoftCheckContainsCI`
- **golden**：`softfail_wave2.tap` / `.json`（wave2 默认消息 join）
- **契约**：Soft × MaxFailures/FailFast 串行再钉；并行 SoftCheck 全员仍跑；ColorDiff 换行下 join 仍用 `; `
- **demo**：`softfail_demo` 扩 SoftCheck Bool/Near

### v8.26 (2026-07-21) — 规模质量跃迁（B51–B55）

- **灭 identity**：`test_config` 400 identity → **500 config fingerprint fail-path**；`test_diagnostics` 去掉 identity 表
- **fail-path 加厚**：diagnostics equal 1800 + notequal 500；assertions Soft 250；lifecycle B30 160
- **门禁**：`SCALE_MIN=6500`、`FAIL_PATH_MIN_RATIO=0.35`、`LOW_SIGNAL_MAX_RATIO=0.40`
- **可观测**：scale 报告 per-suite total/fail-path/low-signal breakdown

### v8.25 (2026-07-21) — 并行可观测 + scale 质量（M5–M6）

- **TimeoutWorkerLeaks**：`TTestRunResult.TimeoutWorkerLeaks` = 本 suite 内 stuck timeout worker 增量
- **API**：`GetTimeoutWorkerLeakCount` / `ResetTimeoutWorkerLeakCount`；并行/串行 suite 结束非零时 WARNING
- **scale 质量**：`LOW_SIGNAL_MAX_RATIO` 默认 **0.55**；identity/meta 表无 fail-path 关键字计为 low-signal
- **契约**：runner must_have 锁 TimeoutWorkerLeaks + Get/Reset

### v8.24 (2026-07-21) — 编译器透明边角（可用性 M4）

- **Sink IO**：`TStdoutSink` / `TStderrSink` 经 `platform_console_write`（fd 1/2），**禁止** `System.Write*`
- **Discovery**：`ITestDiscoveryBackend` + `CreateFpcVmtDiscoveryBackend`；`SetDiscoveryBackend` / `ResetDiscoveryBackend` 可注入 nextpas/测试双
- **契约**：runner source-contract 锁无 System.Write*、platform_console_write、backend API + 自测 inject/reset
- **FPC VMT**：仍为默认 backend 实现（布局绑定隔离在 `TFpcVmtDiscoveryBackend`）

### v8.23 (2026-07-21) — Soft 诊断对齐 + Soft 高频扩面（可用性 M0–M3）

- **文档**：README 纠正无 SysUtils 直连；经 `nextpas.core.system` + `nextpas.core.*`；§0 Soft 能力矩阵
- **Soft 诊断**：`SoftCheckEqual(string)` 复用 `ColorDiff`（position / expected / actual，与 hard 路径一致）
- **Soft 高频**：`SoftCheckEqual(Boolean)`、`SoftCheckEqual(TBytes)`、`SoftCheckNear`
- **契约**：api/runner source-contract 纳入 `SoftCheckNear`；ComputeKey 字段名单 source-contract（ShuffleSeed/FailFast/MaxFailures/…）
- **规模**：`SCALE_MIN` 仍 **5500**（本批不灌水抬门）

### v8.22 (2026-07-20) — Cache key 诚实化 + SoftFail 回归 + SCALE≥5500

- **产品**：`TTestCache.ComputeKey` 纳入 `MaxFailures` / `FailFast` / **ShuffleSeed 整值**（旧 key 自然 miss）
- **ComputeKey 字段（进 key）**：ShuffleSeed、FailFast、MaxFailures、ShortMode、VerboseMode、RetryCount、TimeoutMs、FilterPattern、TagFilter、RunPattern、SuiteName、compiler、sources
- **故意不进 key（当前）**：BenchMem、BenchTimeMs、CacheDir、AnsiMode 等纯展示/输出配置
- **SoftFail**：outside context exact；parallel multi exact；Push/Pop 锁在 runner.context
- **消费者**：`nested_softfail_demo`（parent+leaf 分层消息）
- **规模**：`SCALE_MIN` 默认 **5500**

### v8.21 (2026-07-20) — Nested SoftFail 分层 + Cache 指纹 + SCALE≥5000

- **产品**：nested SoftFail 对齐 Go `t.Run` — `PushSoftFailState`/`PopSoftFailState`；leaf SoftFail 写 leaf result；parent soft 不再被 `SetTestContext` 抹掉
- **规则 R1–R5**：进入 nested 保存 parent soft → leaf 独立 ApplySoftFails → 恢复 parent soft；不把 leaf soft 文本双记进 parent SoftFail join
- **Cache**：配置指纹表（filter/tag/shuffle/maxfail/failfast/timeout）+ hit/miss/invalidate exact
- **薄套件**：discovery 名表 90；advanced SoftFail exact；bench not-executed fail
- **规模**：`SCALE_MIN` 默认 **5000**

### v8.20 (2026-07-20) — 契约密度：subtest SoftFail + CLI/MaxFailures + SCALE≥4500

- **Subtest SoftFail exact**：top-level join；leaf SoftFail 挂到 parent（nested 前 soft 被 reset 为契约）
- **B34**：SoftFail 计入 MaxFailures；FailFast+Soft 仍受 MaxFailures；CLI unknown 忽略；`--failures-max` 表
- **runner contracts**：must_have 锁 SoftFail / SoftCheckTrue / SoftCheckEqual / SoftFailOnly
- **消费者**：`core/examples/nextpas.core.test/softfail_demo`（exit 1 + join 消息为预期）
- **规模**：`SCALE_MIN` 默认 **4500**

### v8.19 (2026-07-20) — SoftFail 诊断 + 薄套件 fail-path + 规模≥4000

- **SoftFail exact**：join `msg1; msg2`、默认 SoftCheck 文案、`(+N more soft fails)` cap、hard+soft 注解 exact
- **golden**：`test_output/goldens/softfail.{tap,json}`；FAIL_ON_CREATE=1 覆盖
- **薄套件**：lifecycle AfterEach+soft/hard 表 60；parallel SoftFail 表 48；prop gen ExpectFail 表 64
- **规模**：`SCALE_MIN` 默认 **4000**（fail-path 仍 ≥30%）
- **tooling（跨模块最小）**：`test_tls13_e2e_openssl` Makefile 暴露 `clean`（tooling 不 expand include）

### v8.18 (2026-07-20) — 规模≥3000 + fail-path 硬门禁 + 消费者示例

- **规模**：`SCALE_MIN` 默认 **3000**；diagnostics/mock/expect 表加厚；discovery 名契约表 +40
- **fail-path 硬门禁**：`FAIL_PATH_MIN_RATIO` 默认 **0.30**（启发式 ExpectFail / negative 表 / Append*Case '0'）
- **薄套件**：advanced SoftFail+TAP multi；bench MaxIterations/阈值边界
- **消费者示例**：`core/examples/nextpas.core.test/smoke_suite`（Check*/Soft*/TestTable/TestSubtest）

### v8.17 (2026-07-20) — SoftFail 完成度

- **全消息**：最多 32 条 soft 消息 join 进 result（超出 `+N more`）
- **Parallel / Subtest**：SoftFail 硬契约
- **FailFast**：仅 soft 失败不 stop 套件
- **SoftCheck**：Equal(string)、Contains、False
- **HardFailed**：InternalFail 与 Soft 分离

### v8.16 (2026-07-20) — SoftFail opt-in（Go t.Error）

- **API**：`SoftFail` / `SoftCheckTrue` / `SoftCheckEqual`（不 raise）
- **Check*/Fail/Expect**：仍 Fatal
- **Runner**：测试结束 `ApplySoftFails` → tsFailed + 消息（首条 + more count）
- **IExpectation 拆分**：仍 v9

### v8.15 (2026-07-20) — CI 严格 golden + contracts 门禁

- **golden**：`FAIL_ON_CREATE=1` 下仓内 goldens 仍比对通过（CI 模式）
- **Makefile**：`make -C core/tests/nextpas.core.test contracts`（api + runner + scale）
- **CI 提示**：`NEXTPAS_SNAPSHOT_FAIL_ON_CREATE=1` 禁止新建 snapshot

### v8.14 (2026-07-20) — 门禁诚实 + golden 入库 + subtests 深度

- **scale**：TestSubtest 计入；规则/breakdown 打印
- **golden**：`test_output/goldens/{report.json,report.tap,report.xml}` 仓内比对
- **subtests**：失败/skip/sink/cleanup 元契约改为 `Suite.Test` 外壳（对标 t.Run）
- **docs/findings**：数字与 FIXED 状态对齐

### v8.13 (2026-07-20) — CLI 可注入 argv + perf 软跨机策略

- **ApplyCLIArgsFrom**：argv 与 ParamStr 解耦；表驱动可测；`ApplyCLIArgs` 包装进程参数
- **perf**：`PERF_BASELINE` / `PERF_HOST_TAG` / `PERF_SKIP`；跨 OS 不设默认硬门禁
- **deferred 维持**：SoftFail（需拍板）、IExpectation 拆分（v9）、TSAN、compiler coverage

### v8.12c (2026-07-20) — shrink 第二波 + 规模 ≥2500

- **Prop**：bytes/filter/choice shrink 边界
- **规模**：mock CalledExactly 负路径表 +300；合计 ≥2500
- **perf**：可选 CI、+30% 阈值、跨机不强制入库（见 test_perf_bench 脚本头注释）

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
- **Check/Fail = Fatal**（raise 中止当前测试）；**SoftFail** opt-in 不 raise、结束时记 fail
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
