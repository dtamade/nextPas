# nextpas.core.test — Advanced Pascal Unit Testing Framework

> 模块负责人: test lane (worktree `.worktrees/test`) — 全权对标 Go/Rust 质量与规模
> 最后更新: 2026-07-20
> 治理状态: v8.19, 17 源文件 (.pas) + 4 .inc, 19 测试套件, ≥4000 可计数过程 + fail-path≥30% + SoftFail golden + 双 source-contract 门禁

## Overview

`nextpas.core.test` is a modern, production-grade unit testing framework for Free Pascal, designed to be the most advanced Pascal testing framework available.

### Features

- **Dual API**: Procedural `Check*` assertions + fluent `IExpectation` chain interface
- **SoftFail**: Go-style `t.Error` — `SoftFail` / `SoftCheck*` continue; `Check*`/`Fail` stay Fatal
- **Parallel execution**: Direct thread-based parallel test dispatch (bypasses FPC closure capture limitations)
- **Subtests**: Go-style nested subtests via `ITestContext.Run` / `RunNested`
- **Parameterized tests**: `TestTable` for data-driven test cases
- **ANSI colored output**: Auto-detected terminal color support
- **Memory leak detection**: Built-in heap trace integration (serial mode only)
- **Full lifecycle**: Setup/Teardown, BeforeEach/AfterEach hooks (both proc and closure overloads)
- **Multi-suite runner**: `TSuiteRunner` aggregates multiple suites
- **JUnit XML export**: `JUnitXML` / `WriteJUnitXML` for CI integration
- **TAP v13 export**: `TAPReport` for CI integration
- **JSON export**: `JSONReport` for CI integration
- **Test filtering**: `SetTestFilter` pattern-based test selection + hierarchical (`--filter=Parent/Sub`)
- **Tag filtering**: `SetTagFilter` comma-separated tag filter
- **Test timeout**: `SetTestTimeout` global timeout configuration
- **Retry**: `RetryCount` per-test or global retry
- **Shuffle**: `SetDefaultShuffleSeed` deterministic test shuffling
- **FailFast**: `SetDefaultFailFast` stop on first failure
- **Short mode**: `ShortSkip` for Go-style `--short` mode
- **Verbose mode**: `SetDefaultVerboseMode` / `VerboseMode` per-test [PASS]/[FAIL]/[SKIP] output (there is **no** `OutputLevel` field)
- **Progress**: `SetDefaultShowProgress` [N/Total] progress counter
- **Mock framework**: `TMock` with setup/verify/typed values/call ordering
- **RTTI discovery**: `DiscoverTests` auto-discovers published methods
- **Benchmarking**: `Bench` + adaptive N scaling (Go testing.B equivalent)
- **Property testing**: QuickCheck-style `Prop()` with generators, coverage-guided fuzzing, automatic shrinking
- **Structured results**: `RunWithResult` / `RunAllWithResult` for programmatic result access
- **Test caching**: `TTestCache` FNV-1a hash-based result caching (`--cache` CLI flag)
- **Sequential opt-in**: `TestSeq()` for tests that must run serially (Go `t.Parallel()` inverse)
- **Minimal dependencies**: Only uses FPC RTL (`SysUtils`) + `nextpas.core.*` modules

## Quick Start

```pascal
program my_tests;
{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
uses nextpas.core.test;

procedure TestMath;
begin
  CheckEqual(Int64(4), Int64(2 + 2));
end;

var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('My Tests');
  LSuite.Test('basic math', @TestMath);
  if not LSuite.Run then
    Halt(1);
end.
```

**Required modeswitches**: `{$modeswitch anonymousfunctions}` and
`{$modeswitch functionreferences}` are needed for:
- Anonymous procedure syntax in `ExpectProc(procedure begin ... end)`
- `TSubtestProc` callback registration via `TestSubtest`
- Lifecycle hook lambdas (`SetSetup(procedure begin ... end)`)
- Closure-based test registration (`Test(name, closure)`)

Without these modeswitches, you must use named procedures with `@Proc` syntax.

## API Reference

### Procedural API (Check*)

| Procedure | Description |
|-----------|-------------|
| `Check(cond, msg)` | Assert boolean condition |
| `CheckEqual(expected, actual)` | Assert equality (string/Int64/Boolean/Pointer/Double) |
| `CheckNotEqual(expected, actual)` | Assert inequality (string/Int64/Boolean/Pointer/Double) |
| `CheckTrue(value, msg)` | Assert True |
| `CheckFalse(value, msg)` | Assert False |
| `CheckNil(ptr, msg)` | Assert nil pointer |
| `CheckNotNil(ptr, msg)` | Assert non-nil pointer |
| `CheckContains(haystack, needle)` | Assert string contains (empty needle matches everything) |
| `CheckStartsWith(str, prefix)` | Assert string starts with (empty prefix matches everything) |
| `CheckEndsWith(str, suffix)` | Assert string ends with (empty suffix matches everything) |
| `CheckSame(expected, actual, msg)` | Assert same pointer identity |
| `CheckInRange(value, low, high)` | Assert integer in inclusive range |
| `CheckLength(actual, expected)` | Assert length equality |
| `CheckRaises(class, proc, msg)` | Assert expected exception raised |
| `CheckNoRaise(proc, msg)` | Assert no exception raised |
| `CheckNear(expected, actual, epsilon, msg)` | Assert floating-point nearness (absolute epsilon) |
| `CheckNotNear(expected, actual, epsilon, msg)` | Assert floating-point not near |
| `CheckApprox(expected, actual, epsilon, msg)` | Assert floating-point nearness (relative epsilon) |
| `CheckEmpty(value)` | Assert string/bytes is empty (length = 0) |
| `CheckNotEmpty(value)` | Assert string/bytes is not empty (length > 0) |
| `CheckSorted(array)` | Assert array is sorted in non-decreasing order |
| `CheckIsNil(intf, msg)` | Assert interface reference is nil |
| `CheckIsNotNil(intf, msg)` | Assert interface reference is not nil |
| `CheckOneOf(value, values)` | Assert value is one of the given set (string/Int64/Boolean overloads) |
| `CheckInstanceOf(obj, class)` | Assert object is instance of class (nil fails) |
| `CheckSnapshot(actual, dir, name)` | Assert string matches snapshot file; create-on-miss fails under strict mode |
| `Fail(msg)` | Unconditional failure |
| `Skip(reason)` | Skip current test (raises `ETestSkipped`) |

**Note on Double comparisons**:
- `CheckEqual(Double)` performs IEEE 754 **exact comparison** (`=` operator). NaN != NaN, -0.0 = +0.0.
- `CheckNear(Double)` performs **tolerance comparison** with absolute epsilon.
- `CheckApprox(Double)` performs **tolerance comparison** with relative epsilon (better for magnitude-spanning comparisons).
- For floating-point tolerance, use `CheckNear` or `CheckApprox` instead of `CheckEqual`.

### Fluent API (IExpectation)

```pascal
{ Named procedure syntax }
Expect('hello').ToEqual('hello');
ExpectInt(42).ToBeGreaterThan(10).ToBeInRange(0, 100);
ExpectBool(True).ToBeTrue;
ExpectDouble(3.14).ToBeNear(3.14159, 0.01);
ExpectPtr(nil).ToBeNil;
ExpectProc(@MyProc).ToRaise(EConvertError);

{ Negation }
Expect('hello').Not_.ToEqual('world');
ExpectInt(42).Not_.ToEqualInt(99);

{ Anonymous function syntax (requires modeswitches) }
ExpectProc(procedure begin StrToInt('bad'); end)
  .ToRaise(EConvertError, 'invalid');
```

| Factory | Returns |
|---------|---------|
| `Expect(string)` | IExpectation (string) |
| `ExpectInt(Int64)` | IExpectation (integer) |
| `ExpectBool(Boolean)` | IExpectation (boolean) |
| `ExpectDouble(Double)` | IExpectation (double) |
| `ExpectPtr(Pointer)` | IExpectation (pointer) |
| `ExpectProc(TTestProc)` | IExpectation (proc) |
| `ExpectObj(TObject)` | IExpectation (object; for `ToBeInstanceOf`) |

| Method | Applies to |
|--------|-----------|
| `Not_` | All (negates next assertion, auto-resets after each `To*` call) |
| `ToEqual` | string |
| `ToEqualInt` | Int64 |
| `ToEqualBool` | Boolean |
| `ToEqualD(expected, epsilon)` | Double (tolerance comparison within epsilon) |
| `ToBeTrue/ToBeFalse` | Boolean |
| `ToBeNil/ToBeNotNil` | Pointer |
| `ToContain` | string (empty substring matches everything) |
| `ToStartWith/ToEndWith` | string (empty prefix/suffix matches everything) |
| `ToBeGreaterThan/ToBeLessThan` | Int64 |
| `ToBeInRange(low, high)` | Int64 |
| `ToHaveLength` | string |
| `ToBeNear(expected, epsilon)` | Double (floating-point nearness) |
| `ToNotBeNear(expected, epsilon)` | Double (negated nearness) |
| `ToBeSame(expected)` | Pointer (identity comparison) |
| `ToEqualPointer(expected)` | Pointer (alias for ToBeSame) |
| `ToBeInstanceOf(class)` | object (`ExpectObj`) |
| `ToMatchSnapshot(dir, name)` | string (fluent snapshot compare) |
| `ToBeOneOf` / `ToBeOneOfInt` / `ToBeOneOfBool` | membership (empty set always fails) |
| `ToRaise(class, msg)` | proc |
| `ToNotRaise` | proc (fails if any exception raised) |

**Note**: `CheckRaises`, `ToRaise`, and `ToNotRaise` intentionally do NOT catch `ETestSkipped` --
`Skip()` is flow control, not a testable exception. See [Error Handling](#error-handling).

### Parameterized Tests (TestTable)

```pascal
procedure TestAdd(const AC: TTestCase);
begin
  { AC.Name is the case name, AC.Data holds string data }
  CheckEqual(AC.Name, ...);
end;

var
  LCases: specialize TArray<TTestCase>;
begin
  SetLength(LCases, 3);
  LCases[0].Name := '2+2'; LCases[0].Data := '4';
  LCases[1].Name := '0+0'; LCases[1].Data := '0';
  LCases[2].Name := '1+1'; LCases[2].Data := '2';
  LSuite.TestTable('addition', LCases, @TestAdd);
end;
```

Each case runs as a separate test entry (`ekTableTest`), with its own pass/fail status.
`TTestCase.Name` appears in the test output; `TTestCase.Data` is a string for the caller to parse.

### TestTable vs TestSubtest

| API | Role | Context | When to use |
|-----|------|---------|-------------|
| `TestTable(name, cases, proc)` | Data-driven: same `proc`, different inputs | **No** `ITestContext`; callback gets `TTestCase` | Many input/output pairs, table-driven checks |
| `TestSubtest(name, subtests, proc)` | Named subtests with independent context | Each subtest has its own `ITestContext` | Stepwise scenarios, nested `Run` / `RunNested` |

**Recommendation**: Most tests prefer `Test()` + closure. Use `TestTable` when you have many input/output pairs. Use `TestSubtest` / `ITestContext.Run` when you need named sub-results or nesting.

### Cleanup (three layers)

| Layer | API | Scope | When it runs |
|-------|-----|-------|--------------|
| Suite Cleanup | `Suite.Cleanup(proc)` | suite-level | After **each** test (like Go `t.Cleanup()` registered on the suite) |
| Test Cleanup | `Ctx.OnCleanup(proc)` | test-level | Registered inside the test body; runs when **that** test ends (LIFO) |
| Setup / Teardown | `SetSetup` / `SetTeardown` | suite-level | Setup once before all tests; Teardown once after all tests |

Notes:

- Suite Cleanup and `Ctx.OnCleanup` both run LIFO.
- `BeforeEach` / `AfterEach` still run around every test; Cleanup is for resource release, not suite-wide init/fini.
- In parallel mode, test-level `OnCleanup` runs on the worker thread; Setup/Teardown stay serial on the main thread.

### VerboseMode (not OutputLevel)

`TTestConfig` has **no** `OutputLevel` field. Verbosity is only the Boolean `VerboseMode`
(`SetDefaultVerboseMode` / CLI `--verbose`), which prints per-test `[PASS]`/`[FAIL]`/`[SKIP]`.

### TTestStatus Semantic Table

| Status | Value | Meaning | When set |
|--------|-------|---------|----------|
| `tsPassed` | 0 | All assertions passed | Test body completes without exception |
| `tsFailed` | 1 | `EAssertionFailed` raised | `Check*` / `Fail` / `Expect.*To*` assertion failure |
| `tsSkipped` | 2 | `ETestSkipped` raised | `Skip()` called explicitly |
| `tsError` | 3 | Unexpected exception | Any non-assertion, non-skip exception (e.g. `EConvertError`) |

`tsError` and `tsFailed` are both counted as failures in `LastFail`/`TotalFail`.

### Execution Behavior

**Continue on failure**: When a test fails, the suite continues executing the remaining tests.
All tests run regardless of prior failures. The `Run`/`RunParallel` method returns `False` if
any test failed, `True` if all passed. There is no stop-on-first-failure mode -- this is
intentional to maximize information from each test run.

**Lifecycle hooks**: `BeforeEach`/`AfterEach` run for every non-skipped test. If `BeforeEach`
raises, the test is marked `tsError` and `AfterEach` still runs (best-effort). If `Setup`
raises, all tests in the suite are skipped.

### TTestSuite

```pascal
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('My Suite');

  { Lifecycle hooks — both proc and closure overloads available }
  LSuite.SetSetup(@GlobalSetup);
  LSuite.SetSetup(procedure begin ... end);          { closure overload }
  LSuite.SetTeardown(@GlobalTeardown);
  LSuite.OnBeforeEach(@BeforeEachTest);
  LSuite.OnAfterEach(@AfterEachTest);

  { Register tests }
  LSuite.Test('name', @TestProc);                    { proc pointer }
  LSuite.Test('name', procedure begin ... end);       { closure }
  LSuite.Skip('name', 'reason');

  { Subtests }
  LSuite.TestSubtest('name', @SubtestProc);

  { Parameterized tests }
  LSuite.TestTable('name', ACases, @TestCaseProc);

  { Run }
  LSuite.Run;                                     { Serial }
  LSuite.RunWithResult(LResult);                  { Serial + structured results }
  LSuite.RunParallel(nil);                        { Parallel (direct threads) }
  LSuite.RunParallelWithResult(nil, LResult);     { Parallel + structured results }

  { Results }
  LSuite.Summary;       { Print pass/fail/skip counts }
  LSuite.AllPassed;     { Returns True if all passed; auto-runs if not yet run }

  { Programmatic result access }
  WriteLn(LResult.Passed, '/', LResult.Passed + LResult.Failed);
end;
```

#### TTestSuite is a Record (COW semantics)

`TTestSuite` is a Pascal **record**, not a class. This has important implications:

```pascal
{ WRONG -- modifications after Add are lost (copy-on-write) }
LRunner.Add(LSuite);
LSuite.Test('late test', @LateTest);  { not reflected in runner }

{ CORRECT -- register all tests before Add }
LSuite.Test('test 1', @Test1);
LSuite.Test('test 2', @Test2);
LRunner.Add(LSuite);  { runner gets a snapshot }
```

`TSuiteRunner.Add` takes `var ASuite: TTestSuite` and copies it. Any modifications
to the original `LSuite` variable after `Add` are NOT reflected in the runner.

#### AllPassed Lazy Execution

`TTestSuite.AllPassed` has lazy execution semantics:

- If `Run` or `RunParallel` has already been called, returns the cached result.
- If the suite has NOT been run yet, automatically calls `Run` (serial mode) first.

This means `AllPassed` is safe to call as the sole entry point, but be aware it
triggers a serial run if needed. For parallel results, call `RunParallel` explicitly
before checking `AllPassed`.

### TSuiteRunner (multi-suite)

```pascal
var
  LRunner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
begin
  LRunner := TSuiteRunner.Create('All Tests');
  LRunner.Add(LSuite1);
  LRunner.Add(LSuite2);
  LRunner.RunAll;                             { Serial: runs each suite sequentially }
  LRunner.RunAllWithResult(LResults);         { Serial + structured results }
  LRunner.RunAllParallel(nil);                { Parallel: each suite uses RunParallel }
  LRunner.RunAllParallelWithResult(nil, LResults);  { Parallel + structured results }
  LRunner.Summary;                            { Print aggregated pass/fail/skip }
end;
```

### Subtests

```pascal
{ Simple subtest -- test body runs inline }
procedure TestDatabase(constref Ctx: ITestContext);
begin
  Ctx.Run('connect',
    procedure begin CheckTrue(DB.Connected); end);
  Ctx.Run('query',
    procedure begin CheckEqual('result', DB.Query('SELECT 1')); end);
end;

{ Nested subtest -- child has its own subtests }
procedure TestLevel1(constref Ctx: ITestContext);
begin
  Ctx.RunNested('child', @TestLevel2);
end;
```

Subtest failures propagate to the parent: if any sub-subtest fails, the parent
subtest is also marked as failed. This propagation is recursive through arbitrary
nesting depth.

#### ITestContext API

| Method | Description |
|--------|-------------|
| `Run(name, proc)` | Register and run a simple subtest |
| `RunNested(name, proc)` | Register a subtest that has its own nested subtests |
| `Fail(msg)` | Unconditionally fail the current test |
| `Skip(reason)` | Skip the current test (raises ETestSkipped) |
| `TestName` | Name of the currently executing test |

### Test Filtering

```pascal
SetTestFilter('math');         { Only run tests whose name contains 'math' }
WriteLn(GetTestFilter);       { Read current filter }
SetTestFilter('');             { Clear filter (run all) }
```

Filter matching is case-sensitive substring match on the test name.

### Test Timeout

```pascal
SetTestTimeout(5000);         { 5 second timeout per test }
WriteLn(GetTestTimeout);      { Read current timeout (ms), 0 = disabled }
```

Timeout is enforced by a dedicated worker thread in `runner.parallel`.

### JUnit XML Export

```pascal
var
  LResults: specialize TArray<TTestRunResult>;
begin
  LRunner.RunAllWithResult(LResults);
  { Generate XML string }
  WriteLn(JUnitXML(LResults, 'MySuite'));
  { Write directly to file }
  WriteJUnitXML(LResults, 'test-results.xml', 'MySuite');
end;
```

## Error Handling

### ETestSkipped -- Flow Control Exception

`ETestSkipped = class(EAbort)` is used as **flow control**, not as a testable
exception. This is a deliberate design choice:

- `Skip('reason')` raises `ETestSkipped` to abort the current test.
- `CheckRaises` and `CheckNoRaise` **re-raise** `ETestSkipped` -- they never
  catch it. This means `Skip()` inside a `CheckRaises`/`CheckNoRaise` proc
  correctly skips the test rather than being treated as a caught exception.
- `ETestSkipped` inherits from `EAbort` (which doesn't display an error dialog
  in GUI contexts and is silently caught by FPC's default exception handler).

### Assertion Failures

`EAssertionFailed` (defined in the framework) is raised by:
- All `Check*` procedures when the assertion fails
- All `IExpectation.To*` methods when the assertion fails
- `Fail(msg)` unconditionally

### Global State Model (threadvar)

The framework uses a single `threadvar` for thread-local execution state:

```pascal
threadvar
  GExecState: PTestExecState;  { heap-allocated, nil = uninitialized }
```

`GExecState` tracks:
- `SuiteName`, `TestName` -- current test context
- `Failed` -- whether current test has failed
- `SkipReason` -- reason if current test was skipped

`InternalFail` sets `GExecState^.Failed := True` before raising `EAssertionFailed`.
`InternalSkip` sets `GExecState^.SkipReason` before raising `ETestSkipped`.

The state is allocated on first `SetTestContext` call and disposed in `finalization`.
Being `threadvar`, each thread has its own independent state -- no data races in parallel mode.

## Parallel Execution

`RunParallel` spawns one OS thread per test via `platform_thread_create`.
Results are collected thread-safely using a mutex.

**Note**: FPC's `heaptrc` (`-gh`) is not thread-safe. Omit `-gh` when running
parallel tests, or run serial tests with `-gh` and parallel tests without.

### APool Parameter

`RunParallel(APool: IThreadPool)` -- the `APool` parameter is **reserved for
future use**. Currently pass `nil`. The parallel mode uses direct
`platform_thread_create` for each test, not a thread pool. This design choice
was made because FPC closures capture variables by reference, making it unsafe
to reuse threads across test boundaries.

### Thread Safety Requirements

When using `RunParallel` / `Suite.Parallel()`:

- **BeforeEach / AfterEach** must be thread-safe -- they are called concurrently
  from multiple threads. Avoid shared mutable state or protect with a mutex.
- **Setup / Teardown** run serially (before/after all parallel tests) and are
  safe to use shared state. If Setup fails, all tests are skipped and the suite
  reports `LastFail = 1`, `HasRun = True`.
- **Check\* assertions** work correctly in parallel tests -- each thread catches
  its own exceptions locally.
- **Subtests** (`ITestContext.Run` / `RunNested`) are a serial-only feature.
  Do not use `TestSubtest` entries with `RunParallel`.
- **Thread-local context** (`GExecState`) is `threadvar` -- each thread has
  independent state, no data races.

### Parallel user responsibility checklist

Parallel tests share one process. Callers own concurrency safety:

1. **No unsynchronized global mutable state** in parallel test bodies.
2. **`GStubRegistry` / `GFixtureRegistry` are not thread-safe** -- register stubs/fixtures in `Setup()`, never inside parallel tests.
3. **Output is mutex-protected** (safe to write from workers); **test-local state is not** shared or protected for you.
4. Keep **BeforeEach / AfterEach** free of unsynchronized shared mutables.
5. Prefer serial `Run` when you need **subtests** or **benchmarks** (skipped under parallel).

## Memory Leak Detection

When compiled with `-gh` (heaptrc), the framework reports leaked memory blocks
after each test in serial mode.

### Limitations

- **Serial mode only**: Leak detection uses `GetFPCHeapStatus.CurrHeapUsed`
  after each test. This is not thread-safe and is disabled in parallel mode.
- **Absolute value check**: Reports leaks when `CurrHeapUsed > 0` after a
  passed test -- not a before/after delta. This means any non-zero heap usage
  (including framework-internal allocations) triggers a warning. False positives
  are possible; treat the warning as a prompt to investigate with `-gh`.
- **Per-test granularity**: Leak detection is per-test, not per-assertion.
  A leak in a subtest is attributed to the parent test.
- **heaptrc itself**: FPC's `heaptrc` unit adds overhead and is not compatible
  with multi-threaded code. Use it for serial leak checks only.

## Build & Test

```bash
# Single test suite
make -C core/tests/nextpas.core.test/test_assertions clean test

# All test framework suites
for d in core/tests/nextpas.core.test/test_*; do
  make -C "$d" clean test
done

# List all test suites
ls core/tests/nextpas.core.test/
```

## Architecture

```
test.pas (facade, 537 lines) — 纯 re-export, 无逻辑
  ├── test.base (836)      — L0: 类型, 异常, GExecState, InternalFail/Skip
  ├── test.config (1099)   — L0: TTestConfig, IOutputSink, TTestCache, TBufferSink
  ├── test.check (1414)    — L1: 40+ Check*/Fail/Skip procedures (含 CI/Double/Array 变体)
  ├── test.expect (1330)   — L1: IExpectation + 6 工厂 + 40+ To* methods (含 CI/Double 变体)
  ├── test.output (1166)   — L2: ANSI + 过滤 + JUnit XML + 泄漏报告
  ├── test.output.json (185)  — L2: JSON 输出
  ├── test.output.tap (123)   — L2: TAP v13 输出
  ├── test.runner (2225)   — L3: TTestSuite + TSuiteRunner + retry/shuffle/failfast
  ├── test.runner.cli (408)   — L3: CLI 参数解析 (--filter, --bench, --cache 等)
  ├── test.discovery (177) — L4: RTTI 自动发现
  ├── test.mock (1529)     — L4: Mock 框架 (TMock + 期望验证 + 调用历史)
  ├── test.prop (2704)     — L4: 属性测试 + 模糊测试 + 语料库 + shrinking
  ├── test.helpers (195)   — L4: ExpectFail, WithMock, MakeBufferConfig, WithTempDir, WithTempFile 辅助
  └── test.bench (206)     — L4: 测试框架与 bench 模块集成

内部模块 (不在 facade re-export):
  ├── test.runner.context (579)   — 子测试上下文 (TTestContext + SetEnv/UnsetEnv)
  └── test.runner.parallel (521)  — 并行执行 (ParallelWorkerProc + timeout watchdog)

Dependency graph:
  L0: base ← config (独立, 互不依赖)
  L1: check ← base, text.conv
      expect ← base, text.conv
  L2: output ← base, config, text.conv, text.builder, fs
      output.json ← base, output, text.conv
      output.tap ← base, output, text.conv
  L3: runner ← base, check, config, output, atomic, sync, thread.*, platform.*, time.cpu
      runner.cli ← config, output, text.conv
      runner.context ← base, config, output
      runner.parallel ← base, config, output
  L4: discovery ← base, runner
      mock ← base, text.conv
      prop ← base, text.conv
      helpers ← base, config, mock
      bench ← base, bench (nextpas.core.bench)
  门面: test ← all above

## Dependencies

| Dependency | Module | Usage |
|-----------|--------|-------|
| `SysUtils` | All | `ExceptClass`, `EAbort`, `EAssertionFailed` — FPC built-in, irreplaceable |
| `nextpas.core.text.conv` | check, expect, output, mock, discovery | String conversion utilities |
| `nextpas.core.text.builder` | output | StringBuilder for JUnit XML |
| `nextpas.core.fs` | output | File I/O for WriteJUnitXML |
| `nextpas.core.atomic` | runner | Atomic operations for thread-safe counters |
| `nextpas.core.sync` | runner | Mutex for parallel result collection |
| `nextpas.core.thread.base` / `.intf` | runner | Thread abstractions |
| `nextpas.core.collections.base` | runner | Array types |
| `nextpas.core.platform.thread` | runner | `platform_thread_create` for parallel dispatch |
| `nextpas.core.time.cpu` | runner | CPU time measurement |

Note: `Classes` is NOT a dependency. The framework uses `specialize TArray<T>` from
`nextpas.core.collections.base` instead of `TList`.

## Test Coverage

> 实测：`make -C core/tests/nextpas.core.test clean test` → **16/16 suites passed**（2026-07-19）。
> 下表「Tests」列为各套件主 suite 报告的测试过程数；multi-suite 程序取主路径合计近似值。不含 stress 内 10K 空测试展开。

| Test Suite | Tests | Coverage |
|-----------|-------|----------|
| test_assertions | 188 | All Check* + Skip/Fail + OneOf/InstanceOf/Snapshot + Double/Array/CI |
| test_expect | 198 | IExpectation To* + Inf/Finite + InstanceOf + MatchSnapshot + negation |
| test_mock | 112 | TMock setup/verify, typed values, ordering, TMockCaptor, thread asserts |
| test_output | 81 | ANSI, JUnit/JSON/TAP, Error vs Failure, colored diff |
| test_config | 38 | TTestConfig defaults, builder With*, TBufferSink, MakeBufferConfig |
| test_discovery | 8 | DiscoverTests + TTestFixture BeforeEach/AfterEach |
| test_runner | multi (~150 entries) | CLI/filter/shuffle/retry/timeout/parallel/cache/summary |
| test_prop | ~50 | Property generators, fuzzing, corpus, shrinking |
| test_lifecycle | 17 | Setup/Teardown, BeforeEach/AfterEach, Cleanup, TestTable |
| test_bench | 22 | RunBenchTest/Suite, CheckBenchPerformance/Throughput |
| test_advanced | 13 | DiscoverTests, TestFixture, ShouldFail, JSON escape |
| test_diagnostics | 15 | Error vs failure, diagnostic message quality |
| test_parallel | multi | Parallel execution, timeout, table parallel, lifecycle |
| test_subtests | 15 | Nested subtests, RunNested, CleanupCallbacks, SinkPropagation |
| test_stress | 10 | 10K empty, large strings, glob perf, 100K output |
| test_perf_bench | microbench | Expect/Check/Mock 性能回归门禁（非单元计数） |
| **Total** | **~930** | **16/16 green**；heaptrc 时序伪影见 CONTRACT §10 |

---

## Engineering Governance

### 分层架构

```
L0 基础层:  base.pas, config.pas
            ↓ 不依赖任何 test.* 模块
L1 断言层:  check.pas, expect.pas
            ↓ 只依赖 L0
L2 输出层:  output.pas, output.json.pas, output.tap.pas
            ↓ 依赖 L0
L3 执行层:  runner.pas, runner.cli.pas, runner.context.pas, runner.parallel.pas
            ↓ 依赖 L0-L2
L4 扩展层:  discovery.pas, mock.pas, prop.pas, helpers.pas, bench.pas
            ↓ 依赖 L0 + L3
门面:       test.pas — 纯 re-export，无逻辑
```

### 依赖规则

1. **只向下依赖**: L0 不依赖 L1-L4, L1 不依赖 L2-L4
2. **禁止循环依赖**: check.pas 和 expect.pas 不能互相引用
3. **门面无逻辑**: test.pas 只做 re-export, 不含任何实现
4. **internal 模块不从 facade re-export**: runner.context, runner.parallel

### 稳定性等级

| 等级 | 含义 | 规则 |
|------|------|------|
| **Stable** | 可以放心使用 | 变更需向后兼容 |
| **Experimental** | 可能变化 | 变更需文档说明 |
| **Internal** | 框架内部 | 不在 facade re-export, 禁止外部使用 |

#### L0: base.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `TTestProc`, `TTestClosure`, `TSubtestProc` | Stable | 核心过程类型 |
| `ITestContext` | Stable | 子测试上下文接口 |
| `TTestCase`, `TTestCaseProc` | Stable | 表驱动测试类型 |
| `TTestStatus`, `TTestResult`, `TTestRunResult` | Stable | 结果类型 |
| `ETestSkipped` | Stable | 跳过异常 |
| `TBenchContext`, `TBenchResult` | Stable | 基准测试类型 |
| `TTestEntry` | **Internal** | 测试条目 (runner 内部) |
| `MakeTestResult`, `MakeBenchResult` | Stable | 构造辅助 |
| `GetTopSlowest`, `ShuffleEntries` | Stable | 结果处理 |
| `GrowCapacity`, `GrowCleanups` | **Internal** | 数组增长原语 |
| `RunShouldFailEntry` | **Internal** | ShouldFail 执行 |
| `InternalFail`, `InternalSkip` | **Internal** | 断言/跳过 |
| `SetTestContext`, `GetLastTestTrace` | **Internal** | 执行上下文 |

#### L0: config.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `TTestConfig` | Stable | 配置记录 |
| `IOutputSink`, `TStdoutSink`, `TStderrSink`, `TBufferSink` | Stable | 输出接收器 |
| `TAnsiMode` | Stable | ANSI 模式枚举 |
| `DefaultConfig`, `ResolveConfig` | Stable | 配置解析 |
| `SetDefault*`, `Get*` | Stable | 配置访问器 |
| `ResetDefaultConfig` | Stable | 重置配置 |

#### L1: check.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `Check`, `CheckEqual`, `CheckNotEqual` | Stable | 核心断言 |
| `CheckTrue/False`, `CheckNil/NotNil` | Stable | 布尔/指针断言 |
| `CheckContains/NotContains`, `CheckStartsWith/EndsWith` | Stable | 字符串断言 |
| `CheckSame`, `CheckInRange`, `CheckLength` | Stable | 指针/范围/长度 |
| `CheckGreaterThan/LessThan`, `CheckGreaterOrEqual/LessOrEqual` | Stable | 比较断言 |
| `CheckRaises`, `CheckNoRaise` | Stable | 异常断言 |
| `CheckNear`, `CheckNotNear` | Stable | 浮点近似 |
| `Fail`, `FailUnexpected`, `Skip` | Stable | 流程控制 |

#### L1: expect.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `IExpectation` | Stable | fluent 断言接口 |
| `Expect`, `ExpectInt`, `ExpectBool`, `ExpectDouble`, `ExpectPtr`, `ExpectProc` | Stable | 工厂函数 |
| `Not_`, `ToEqual`, `ToEqualInt`, `ToEqualBool` | Stable | 值比较 |
| `ToBeTrue/False`, `ToBeNil/NotNil` | Stable | 状态断言 |
| `ToContain`, `ToStartWith`, `ToEndWith` | Stable | 字符串匹配 |
| `ToBeGreaterThan/LessThan`, `ToBeGreaterOrEqual/LessOrEqual` | Stable | 整数比较 |
| `ToBeInRange`, `ToHaveLength` | Stable | 范围/长度 |
| `ToRaise`, `ToNotRaise` | Stable | 异常断言 |
| `ToBeNear`, `ToNotBeNear` | Stable | 浮点近似 |
| `ToBeGreaterThanD/LessThanD`, `ToBeGreaterOrEqualD/LessOrEqualD`, `ToBeInRangeD` | Stable | Double 比较 |
| `ToContainCI`, `ToStartWithCI`, `ToEndWithCI` | Stable | 不敏感字符串匹配 |

#### L2: output.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `AnsiBold/Green/Red/Yellow/Cyan/Dim` | Stable | ANSI 颜色 |
| `SetAnsiEnabled` | Stable | 控制 ANSI |
| `StatusDot`, `FormatStatusLine` | Stable | 状态格式化 |
| `WriteTestOutput` | Stable | 统一测试输出 |
| `FormatDuration`, `FormatBenchLine` | Stable | 格式化 |
| `SetTestFilter/GetTestFilter`, `SetTagFilter/GetTagFilter` | Stable | 过滤器 |
| `SetTestTimeout/GetTestTimeout` | Stable | 超时配置 |
| `MatchesFilter` | Stable | 过滤匹配 |
| `ReportLeakIfAny` | Stable | 泄漏报告 |
| `JUnitXML`, `WriteJUnitXML` | Stable | JUnit 输出 |
| `FailTest`, `PassTest`, `SectionHeader` | Stable | 元测试辅助 |
| `WriteRetryHint`, `WriteWarning` | **Internal** | 诊断输出 |
| `WriteSuiteHeader`, `WriteSlowTests` | **Internal** | 套件输出 |

#### L3: runner.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `TTestSuite` (record + 所有 public 方法) | Stable | 测试套件 |
| `TSuiteRunner` (record + 所有 public 方法) | Stable | 多套件 runner |
| `Ctx` | Stable | 当前测试上下文 |
| `RegisterStub`, `RegisterFixture` | **Internal** | 注册辅助 |
| `ParseFilter`, `ParseTag` | **Internal** | CLI 解析 |

#### L4: discovery.pas + mock.pas + prop.pas + helpers.pas + bench.pas

| 符号 | 稳定性 | 说明 |
|------|--------|------|
| `TTestFixture`, `TTestFixtureClass` | Stable | fixture 基类 |
| `DiscoverTests` | Stable | RTTI 发现 |
| `TMock`, `TMockState` | Stable | Mock 对象 |
| `TMockValue`, `MockStr/Int/Bool/Double` | Stable | Mock 值 |
| `IMockSetup`, `IMockVerify` | Stable | Mock 接口 |
| `Prop`, `PropInt`, `PropString`, `PropBytes` | Stable | 属性测试入口 |
| `GenInt`, `GenString`, `GenBytes`, `GenArray`, `GenOneOf` | Stable | 生成器工厂 |
| `IPropTracker`, `IFuzzCorpus` | Stable | 覆盖跟踪 + 语料库 |
| `ExpectFail`, `WithMock`, `ExpectFailWithMock` | Stable | 测试辅助 |

### 工程代码契约

#### 1. 参数校验

| 规则 | 说明 |
|------|------|
| nil 指针 | `CheckNil(nil)` 合法; `CheckRaises(nil, ...)` 必须报错 |
| 空字符串 | `CheckContains(s, '')` 匹配一切; `CheckStartsWith(s, '')` 匹配一切 |
| 边界值 | `CheckInRange(v, 5, 3)` 必须报错 (low > high) |
| ExceptClass | `CheckRaises(nil, proc)` → `InternalFail` |

#### 2. 异常处理

| 异常 | 行为 | 说明 |
|------|------|------|
| `ETestSkipped` | re-raise | 流程控制，不是错误 |
| `EAssertionFailed` | 记录 tsFailed, 继续 | 断言失败 |
| `Exception` | 记录 tsError, 继续 | 意外错误 |
| `EAbort` (非 ETestSkipped) | 不捕获, 传播 | 用户主动中止 |

#### 3. 内存管理

| 规则 | 说明 |
|------|------|
| heaptrc 兼容 | 所有测试 0 unfreed |
| threadvar 隔离 | 并行测试不共享可变状态 |
| LIFO 清理 | EachCleanups 按注册逆序执行 |
| FCleanupDone 守卫 | 防止 --count=N 重复释放 |
| 深拷贝 | `TSuiteRunner.Add` 深拷贝 Tests 数组 |

#### 4. 并行安全

| 共享资源 | 保护方式 |
|----------|----------|
| `GExecState` | threadvar, 天然隔离 |
| `GStubRegistry` | 仅主线程访问 |
| `GFixtureRegistry` | 仅主线程访问 |
| `GAnsiEnabled` | 初始化后只读 |
| `GDefaultConfig` | 初始化后只读 |

### 文件清单

| 文件 | 行数 | 层 | 职责 |
|------|------|----|------|
| test.base.pas | 913 | L0 | 基础类型、异常、内部状态 |
| test.config.pas | 1214 | L0 | TTestConfig、IOutputSink、TTestCache、TBufferSink |
| test.check.pas | 1734 | L1 | Check* 断言 API (50+ 方法, 含 OneOf/InstanceOf/Snapshot) |
| test.expect.pas | 1768 | L1 | IExpectation fluent API (40+ 方法 + InstanceOf/MatchSnapshot) |
| test.output.pas | 1273 | L2 | ANSI、过滤、JUnit XML、泄漏报告 |
| test.output.json.pas | 185 | L2 | JSON 输出 |
| test.output.tap.pas | 123 | L2 | TAP v13 输出 |
| test.runner.pas | 2269 | L3 | TTestSuite、TSuiteRunner、retry/shuffle/failfast |
| test.runner.cli.pas | 408 | L3 | CLI 参数解析 |
| test.runner.context.pas | 620 | L3 | 子测试上下文、TTestResultAppender |
| test.runner.parallel.pas | 580 | L3 | 并行执行、timeout watchdog |
| test.discovery.pas | 179 | L4 | RTTI 自动发现 |
| test.mock.pas | 1814 | L4 | Mock 框架 + TMockCaptor |
| test.prop.pas | 2928 | L4 | 属性测试、模糊测试、语料库 |
| test.helpers.pas | 281 | L4 | ExpectFail, WithMock, WithTempDir/File, IntOverflowCheck |
| test.bench.pas | 206 | L4 | 测试框架与 bench 模块集成 |
| test.pas | 580 | 门面 | 纯 re-export |
| **总计** | **~17075** (.pas) | | 另有 4 个 fwd*.inc |

### 测试覆盖矩阵

| 套件 | 模块覆盖 | 测试数 |
|------|----------|--------|
| test_assertions | check.pas | 188 |
| test_expect | expect.pas | 198 |
| test_mock | mock.pas | 112 |
| test_output | output*.pas | 81 |
| test_config | config.pas | 38 |
| test_discovery | discovery.pas | 8 |
| test_runner | runner*.pas | multi |
| test_prop | prop.pas | ~50 |
| test_lifecycle | runner (lifecycle) | 17 |
| test_bench | bench.pas | 22 |
| test_advanced | runner (advanced) | 13 |
| test_parallel | runner.parallel.pas | multi |
| test_diagnostics | diagnostics | 15 |
| test_subtests | runner.context | 15 |
| test_stress | stress | 10 |
| test_perf_bench | perf regression | microbench |
| **总计** | 16 suites | **~930** (2026-07-19 全绿) |

### Deferred / Backlog

| 项 | 状态 | 原因 / 触发条件 |
|----|------|----------------|
| `IExpectation` 按类型拆分（`IStringExpectation` / `INumericExpectation` 等） | **暂缓 (P3)** | 破坏性 API；当前 `RequireKind` 运行时检查足够。触发：v9 major 或显式 breaking 窗口 + 全仓库 consumer 迁移指南 |
| 接口拆分以外的 P3 锦上添花 | 视需求 | 不阻塞 v8.7 landing |

### 文档索引

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 模块总览、API 参考、架构 |
| [CONTRACT.md](CONTRACT.md) | 代码契约（权威版本与覆盖表） |
| [benchmark-comparison.md](benchmark-comparison.md) | 竞品对比 |
| [property-testing-guide.md](property-testing-guide.md) | 属性测试指南 |
| [test-suite-version-history.md](test-suite-version-history.md) | 测试套件版本历史 |

**历史文档** (审计快照；**数字与状态以 CONTRACT/README 为准**):

| 文档 | 说明 |
|------|------|
| [contract-audit.md](contract-audit.md) | 契约审计报告 |
| [test-findings.md](test-findings.md) | 2026-06-29 审计发现（部分对标项已过时，见文内 banner） |
| [test-framework-plan.md](test-framework-plan.md) | 框架实施方案 |
| [usability-research-report.md](usability-research-report.md) | 可用性研究报告 |
| [usability-implementation-plan.md](usability-implementation-plan.md) | 可用性实施计划 |
| [v7.0-research.md](v7.0-research.md) | v7.0 研究报告 |
| [research-report-2026-07-03.md](research-report-2026-07-03.md) | 2026-07-03 研究报告 |
