# nextpas.core.test 代码契约

**模块路径**：`core/src/nextpas.core.test*.pas` + `nextpas.core.testing.pas`（16 个源文件）
**层级**：L1（依赖 L0: base, text, system, time, atomic, sync, thread, collections, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-04
**版本**：6.6

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| test.base | 基础类型 (TTestEntry, TTestStatus, TBenchContext)、threadvar 状态、栈追踪 |
| test.config | TTestConfig 配置记录、IOutputSink 接口、TBufferSink |
| test.check | Check* 过程式断言 API (30+ 方法) |
| test.expect | IExpectation 流式断言 API (Not_ + 30+ 方法) |
| test.mock | TMock 手动 mock 框架 (Setup/Verify/RecordCall) |
| test.discovery | RTTI VMT 方法表自动测试发现 |
| test.helpers | 便捷辅助 (ExpectFail, WithMock, MakeBufferConfig) |
| test.output | ANSI 着色、filter 匹配 (glob+hierarchical)、JUnit XML、leak 报告 |
| test.output.tap | TAP v13 格式输出 |
| test.output.json | JSON 格式输出 |
| test.runner | TTestSuite/TTestRunner 串行/并行运行器、benchmark |
| test.runner.cli | CLI 参数解析 (--filter, --bench, --timeout 等 16 个 flags) |
| test.runner.context | TTestContext 子测试执行上下文 (ITestContext 实现) |
| test.runner.parallel | 超时 worker + 并行线程 worker |
| testing.pas | **DEPRECATED** v1 兼容层 (仅保留 Check/CheckEqual/Fail) |
| test.pas | Facade re-export 门面 |

### 1.2 核心接口

```pascal
IOutputSink = interface
  procedure Write(const AText: string);
  procedure WriteLn(const AText: string);
  procedure Flush;
end;

ITestContext = interface
  procedure Run(const AName: string; AProc: TTestProc);
  procedure Run(const AName: string; AProc: TTestClosure);
  procedure RunNested(const AName: string; AProc: Pointer);
  procedure Fail(const AMessage: string);
  procedure Skip(const AReason: string = '');
  function  GetTestName: string;
  property  TestName: string read GetTestName;
  procedure Log(const AMessage: string);
  procedure LogF(const AFormat: string; const AArgs: array of const);
  procedure OnCleanup(AProc: TTestProc);
  procedure OnCleanup(AProc: TTestClosure);
end;

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
  function ToBeInRange(const ALow, AHigh: Int64): IExpectation;
  function ToHaveLength(const AExpected: NativeInt): IExpectation;
  function ToRaise(AExceptionClass: ExceptClass; const AMessage: string = ''): IExpectation;
  function ToNotRaise: IExpectation;
  function ToBeNear(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
  function ToNotBeNear(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
  function ToBeGreaterThanD(const AExpected: Double): IExpectation;
  function ToBeLessThanD(const AExpected: Double): IExpectation;
  function ToBeInRangeD(const ALow, AHigh: Double): IExpectation;
  function ToContainCI(const ASubstr: string): IExpectation;
  function ToStartWithCI(const APrefix: string): IExpectation;
  function ToEndWithCI(const ASuffix: string): IExpectation;
  function ToBeSame(const AExpected: Pointer): IExpectation;
  function ToEqualPointer(const AExpected: Pointer): IExpectation;
  function ToEqualD(const AExpected: Double; const AEpsilon: Double = 1e-10): IExpectation;
end;

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
  function  CalledExactlyWith(ACount: Integer; const AArgs: array of string): IMockVerify;
end;
```

### 1.3 核心类型

```pascal
TTestStatus = (tsPassed, tsFailed, tsSkipped, tsError);

TTestConfig = record
  FilterPattern: string;
  TagFilter: string;
  TimeoutMs: UInt64;
  AnsiMode: TAnsiMode;          // amAuto, amOn, amOff
  OutSink: IOutputSink;
  ErrSink: IOutputSink;
  RetryCount: Integer;
  MaxParallelWorkers: Integer;  // 0=unlimited, >0=max threads
  RepeatAllCount: Integer;      // --count=N
  SlowTestCount: Integer;       // top N slowest (default=5)
  ShuffleSeed: Integer;         // 0=off, -1=random, >0=deterministic
  FailFast: Boolean;
  ListMode: Boolean;
  ShortMode: Boolean;           // --short
  ShowProgress: Boolean;        // [N/Total] prefix
  MaxFailures: Integer;         // 0=unlimited
  JsonOutput: Boolean;
  VerboseMode: Boolean;         // --verbose
  RunTimeoutSec: Integer;       // global suite timeout
  BenchEnabled: Boolean;
  BenchTimeMs: Integer;         // default 1000ms
  BenchMem: Boolean;
  RunPattern: string;           // --run: exact name match
end;

TTestEntryKind = (ekTest, ekSubtest, ekSkipped, ekTableTest, ekShouldFail, ekBench);
TMockValueKind = (mvUnset, mvString, mvInt64, mvBool, mvDouble);
```

### 1.4 TTestSuite API 摘要

```pascal
// ⚠️ With* methods return a NEW record — must assign: Suite := Suite.WithSetup(Proc);
function WithConfig/WithSetup/WithTeardown/WithBeforeEach/WithAfterEach/WithEachCleanup: TTestSuite;

// In-place registration (no return value needed):
procedure Test(AName, AProc);                    // 10 overloads: Proc/Closure + Retry + Tags + DisplayName
procedure TestRepeat(AName, AProc, ARepeatCount);
procedure TestSubtest(AName, ASubtestProc);
procedure TestTable(AName, ACases, AProc);
procedure ShouldFail(AName, AProc, AMsg = '');   // Rust #[should_panic]
procedure ShortSkip(AName, AProc);               // Go -short
procedure Bench(AName, ABenchProc);
procedure Skip(AName, AReason = '');
procedure Cleanup(AProc);                        // LIFO cleanup (Go t.Cleanup)
procedure SetSetup/SetTeardown/OnBeforeEach/OnAfterEach(AProc);

// Execution:
function Run: Boolean;
function RunParallel(APool: IThreadPool): Boolean;
function RunBenchmarks(out AResults: TBenchResults): Boolean;
```

---

## 2. 不变量

- `--filter` 支持 glob (`*`, `?`)、brace expansion (`{a,b}`)、hierarchical (`Parent/Sub`)、逗号分隔多模式
- `--run` 精确名称匹配 (case-insensitive)，优先级高于 `--filter`
- `--tag` 逗号分隔 tag 过滤 (OR 语义)
- `--timeout` 超时后标记 tsError（使用 platform_thread_timedjoin，零 CPU 浪费）
- `--failfast` 首次失败立即停止（suite 级 + test 级双级）
- `--failures-max=N` 跨 suite 累计 N 次失败后停止
- `--shuffle` Fisher-Yates 随机（种子 -1=random，>0=deterministic）
- `--count=N` 全部测试重复 N 次
- `--short` 跳过 ShortSkip 标记的测试
- `--progress` 显示 [N/Total] 进度
- `--verbose` 显示 [PASS]/[FAIL]/[SKIP] + 耗时
- `--bench[=pattern]` 启用 benchmark（自适应 N 缩放，Go 算法等价）
- `--benchtime=Nms/Ns` 每个 benchmark 目标时间（默认 1s）
- `--benchmem` 显示 B/op + allocs/op
- `--json` stdout 输出 JSON 报告
- `--list` 列出测试名不运行
- BeforeEach/AfterEach 在串行模式与 test 同线程；并行模式每 worker 独立执行
- EachCleanups LIFO 顺序执行，失败/成功均执行
- NaN 在 Check*/Expect* 中统一视为不等于任何值（包括自身）
- ShouldFail 测试：抛任何 Exception → tsPassed，不抛 → tsFailed
- Subtests/Benchmarks 在 RunParallel 模式下自动跳过

---

## 3. 错误处理

- 测试失败抛 `EAssertionFailed`（由 Check*/Expect* 内部抛出）
- 测试跳过抛 `ETestSkipped`（继承 EAbort，不被 CheckRaises 捕获）
- 其他异常分类为 tsError（unexpected exception）
- 配置解析：CLI 参数缺失/格式错误静默使用默认值（无 ETestConfigError）
- Mock 验证失败抛 `EAssertionFailed`
- 栈追踪：ExceptProc hook 过滤框架帧，仅保留用户代码的 file:line

---

## 4. 线程安全

- TTestSuite/TTestRunner 的 Run/RunParallel 从主线程调用
- 并行模式：每个 worker 独立 TTestContext，GExecState 为 threadvar
- GStubRegistry/GFixtureRegistry：NOT thread-safe，仅主线程访问
- 并行输出通过 IMutex 保护 stdout
- 超时 worker 使用 platform_thread_timedjoin（非轮询）
- 真正卡死的 worker 通过 platform_thread_detach 释放，LRec 泄漏并计入 GTimeoutLeakCount

---

## 5. 内存管理

- IExpectation/TMock 通过引用计数自动释放（TInterfacedObject）
- TTestEntry 的 TableCase/TableProc 通过 New/Dispose 管理（FCleanupDone 防重）
- DiscoverTests 的 MethodStub 通过 New/GStubRegistry 管理
- DiscoverTests 的 Fixture 对象通过 GFixtureRegistry 管理（finalization 安全网）
- GExecState threadvar 在 finalization 中 Dispose
- heaptrc 模式下 ReportLeakIfAny 检测并报告未释放内存

---

## 6. 测试覆盖

10 个套件，~550+ 测试：

| 套件 | 覆盖范围 | 测试数 |
|------|---------|--------|
| test_assertions | Check* 断言 + NaN/边界/epsilon | ~103 |
| test_expect | IExpectation 流式 API + NaN/Pointer/Double | ~115 |
| test_mock | TMock 录制/验证/返回值/typed/ResetAll | ~67 |
| test_output | ANSI/filter/glob/hierarchical/JUnit/TAP/JSON | ~70 |
| test_runner | 全特性集成: lifecycle/timeout/shuffle/failfast/bench/parallel | ~101 |
| test_lifecycle | TestTable/TTestClosure/facade 完整性 | ~15 |
| test_parallel | 并行执行/lifecycle/retry/skip/batch | ~10 |
| test_diagnostics | 错误诊断/stack trace/Double/Error vs Failure | ~15 |
| test_advanced | RTTI discovery/retry/TAP/JSON | ~13 |
| test_subtests | 嵌套子测试/ITestContext/failure 传播/cleanup | ~15 |
