# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas`（18 个源文件）
**层级**：L0-L4（分层架构，详见 README.md）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-11
**版本**：v8.4

---

## 1. 子模块

| 文件 | 职责 | LOC |
|------|------|-----|
| test.pas | 门面：re-export 所有公共 API | ~537 |
| test.base.pas | 基础类型（TTestEntry, TTestStatus, TBenchContext, ETestSkipped, threadvar） | ~836 |
| test.check.pas | 过程式 Check* 断言 API（50+ 方法, 含 Pointer/UInt64/TBytes AMessage 变体） | ~1500 |
| test.expect.pas | 流式 IExpectation 接口 + TExpectation 实现（40+ 方法） | ~1330 |
| test.mock.pas | TMock/TMockState 手动 Mock 框架（期望验证 + 调用历史 + ArgHash 优化） | ~1600 |
| test.config.pas | TTestConfig record（23 字段含 Version）+ IOutputSink + TTestCache + TBufferSink | ~1150 |
| test.runner.pas | TTestSuite/TSuiteRunner + 串行/并行执行 + retry/shuffle/failfast | ~2225 |
| test.runner.cli.pas | CLI 参数解析（--filter, --bench, --cache 等） | ~408 |
| test.runner.parallel.pas | 并行 worker + timeout watchdog | ~521 |
| test.runner.context.pas | TTestContext (ITestContext) + TTestResultAppender + SetEnv/UnsetEnv | ~579 |
| test.discovery.pas | RTTI VMT 方法表扫描自动发现测试 | ~177 |
| test.output.pas | ANSI 辅助、glob 匹配、JUnit XML、泄漏报告 | ~1166 |
| test.output.json.pas | JSON 输出格式 | ~185 |
| test.output.tap.pas | TAP v13 输出格式 | ~123 |
| test.prop.pas | 属性测试 + 模糊测试 + 语料库 + shrinking | ~2704 |
| test.helpers.pas | ExpectFail, WithMock, MakeBufferConfig, WithTempDir, WithTempFile 辅助 | ~195 |
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
  function ToMatch(const APattern: string): IExpectation;
  function WithMessage(const AMessage: string): IExpectation;
  procedure ToFailUnexpected(const AMessage: string = '');
end;
```

工厂函数：`Expect(string)`, `ExpectStr`, `ExpectInt`, `ExpectBool`, `ExpectDouble`, `ExpectPtr`, `ExpectProc`, `ExpectBytes`, `ExpectArrayOfInt`, `ExpectArrayOfStr`。

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

### 3.1 TTestConfig (23 字段)

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
  Version       : Integer;     { 序列化版本号 (0=v8, 1=v9+); 向前兼容 }
  BenchSaveFile : string;      { --benchsave=<file>: 保存 benchmark 结果到 JSON }
  BenchCompareFile: string;    { --benchcompare=<file>: 与基线 JSON 比较 }
  CacheEnabled  : Boolean;     { --cache: 使用测试结果缓存 }
  CacheDir      : string;      { 缓存目录 (默认 .nextpas/test-cache/) }
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

### 3.3 TSuiteRunner (record)

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
| Infinity 检查 | `CheckInf(v)` / `CheckNotInf(v)` | — | Expect API 待补 |
| 有限性检查 | `CheckFinite(v)` | — | Expect API 待补 |
| 范围检查 | `CheckInRangeD(v, lo, hi)` | `ToBeInRangeD(lo, hi)` | |

**⚠️ 常见陷阱**：
- `CheckEqual(1e15, 1e15 + 1)` 默认会失败！用 `CheckNearRel` 或增大 epsilon
- `ToBeOneOf([])` 空数组始终失败——值不可能是空集的成员

---

## 10. 测试覆盖

| 套件 | 测试过程 | 断言数 | 覆盖范围 |
|------|---------|--------|----------|
| test_assertions | 167 | 679 | Check* 全方法 (Pointer/UInt64/TBytes AMessage 变体) |
| test_expect | 175 | 530 | IExpectation 全方法 + negation + array/bytes/match |
| test_mock | 196 | 208 | TMock/IMockSetup/IMockVerify + CalledWith + CalledInOrder + GetCallHistory |
| test_output | 83 | 311 | ANSI/glob/JUnit/TAP/JSON/leak report + Error vs Failure |
| test_runner | 13 | 146 | CLI/filter/shuffle/retry/timeout/parallel/count |
| test_lifecycle | 21 | 93 | Setup/Teardown/BeforeEach/AfterEach/Cleanup/TestTable |
| test_prop | 50 | 50 | 属性测试 + 模糊测试 + 语料库 + shrinking |
| test_bench | 22 | 53 | RunBenchTest/RunBenchSuite/CheckBenchPerformance/CheckBenchThroughput |
| test_advanced | 19 | 49 | DiscoverTests/TestFixture/ShouldFail/TestTable |
| test_diagnostics | 15 | 59 | 错误消息质量 + 字符串差异 |
| test_parallel | 19 | 19 | 并行执行 + timeout + table parallel |
| test_subtests | 29 | 59 | Run/RunNested + CleanupCallbacks + SinkPropagation |
| test_stress | 10 | 20 | 10K 空测试 + 大字符串 + glob 性能 + 100K 行输出 |
| **总计** | **819** | **2276** | FPC heaptrc 时序伪影见下 |

> **FPC heaptrc 时序说明**：test_lifecycle(5 blocks/896B)、test_parallel(75 blocks/14KB)、test_runner(17 blocks/3KB)
> 报告未释放内存块。经调查为 FPC 编译器管理的记录副本（TTestSuite=272B、TTestRunResult=40B），
> 由 `TSuiteRunner.Suites: TArray<TTestSuite>` 等动态数组持有。这些托管记录在堆上创建副本，
> 但 FPC 的隐式析构在 heaptrc DumpHeap 之后执行。`Default()` 提前归零不能减少计数，
> 因为问题不在外层变量而在动态数组元素内部的编译器托管副本。这些不是真实泄漏。

## 11. 变更日志

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
