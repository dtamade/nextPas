# nextpas.core.test — Advanced Pascal Unit Testing Framework

## Overview

`nextpas.core.test` is a modern, production-grade unit testing framework for Free Pascal, designed to be the most advanced Pascal testing framework available.

### Features

- **Dual API**: Procedural `Check*` assertions + fluent `IExpectation` chain interface
- **Parallel execution**: Direct thread-based parallel test dispatch (bypasses FPC closure capture limitations)
- **Subtests**: Go-style nested subtests via `ITestContext.Run` / `RunNested`
- **ANSI colored output**: Auto-detected terminal color support
- **Memory leak detection**: Built-in heap trace integration (serial mode only)
- **Full lifecycle**: Setup/Teardown, BeforeEach/AfterEach hooks
- **Multi-suite runner**: `TTestRunner` aggregates multiple suites
- **Minimal dependencies**: Only uses FPC RTL (`SysUtils`, `Classes`) + `nextpas.core.*` modules

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
  LSuite.Run;
end.
```

**Required modeswitches**: `{$modeswitch anonymousfunctions}` and
`{$modeswitch functionreferences}` are needed for:
- Anonymous procedure syntax in `ExpectProc(procedure begin ... end)`
- `TSubtestProc` callback registration via `TestSubtest`
- Lifecycle hook lambdas (`SetSetup(procedure begin ... end)`)

Without these modeswitches, you must use named procedures with `@Proc` syntax.

## API Reference

### Procedural API (Check*)

| Procedure | Description |
|-----------|-------------|
| `Check(cond, msg)` | Assert boolean condition |
| `CheckEqual(expected, actual)` | Assert equality (string/Int64/Boolean/Pointer) |
| `CheckNotEqual(expected, actual)` | Assert inequality (string/Int64) |
| `CheckTrue(value, msg)` | Assert True |
| `CheckFalse(value, msg)` | Assert False |
| `CheckNil(ptr, msg)` | Assert nil pointer |
| `CheckNotNil(ptr, msg)` | Assert non-nil pointer |
| `CheckContains(haystack, needle)` | Assert string contains (empty needle matches everything) |
| `CheckStartsWith(str, prefix)` | Assert string starts with (empty prefix matches everything) |
| `CheckEndsWith(str, suffix)` | Assert string ends with (empty suffix matches everything) |
| `CheckSame(expected, actual)` | Assert same pointer identity |
| `CheckInRange(value, low, high)` | Assert integer in inclusive range |
| `CheckLength(actual, expected)` | Assert length equality |
| `CheckRaises(class, proc, msg)` | Assert expected exception raised |
| `CheckNoRaise(proc, msg)` | Assert no exception raised |
| `Fail(msg)` | Unconditional failure |
| `Skip(reason)` | Skip current test (raises `ETestSkipped`) |

### Fluent API (IExpectation)

```pascal
{ Named procedure syntax }
Expect('hello').ToEqual('hello');
ExpectInt(42).ToBeGreaterThan(10).ToBeInRange(0, 100);
ExpectBool(True).ToBeTrue;
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
| `ExpectPtr(Pointer)` | IExpectation (pointer) |
| `ExpectProc(TTestProc)` | IExpectation (proc) |

| Method | Applies to |
|--------|-----------|
| `Not_` | All (negates next assertion, auto-resets after each `To*` call) |
| `ToEqual` | string |
| `ToEqualInt` | Int64 |
| `ToEqualBool` | Boolean |
| `ToBeTrue/ToBeFalse` | Boolean |
| `ToBeNil/ToBeNotNil` | Pointer |
| `ToContain` | string (empty substring matches everything) |
| `ToStartWith/ToEndWith` | string (empty prefix/suffix matches everything) |
| `ToBeGreaterThan/ToBeLessThan` | Int64 |
| `ToBeInRange(low, high)` | Int64 |
| `ToHaveLength` | string |
| `ToRaise(class, msg)` | proc |
| `ToNotRaise` | proc (fails if any exception raised) |

**Note**: `CheckRaises`, `ToRaise`, and `ToNotRaise` intentionally do NOT catch `ETestSkipped` —
`Skip()` is flow control, not a testable exception. See [Error Handling](#error-handling).

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
any test failed, `True` if all passed. There is no stop-on-first-failure mode — this is
intentional to maximize information from each test run.

**Lifecycle hooks**: `BeforeEach`/`AfterEach` run for every non-skipped test. If `BeforeEach`
raises, the test is marked `tsError` and `AfterEach` still runs (best-effort). If `Setup`
raises, all tests in the suite are skipped.

### TTestSuite

```pascal
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('My Suite');

  { Lifecycle hooks }
  LSuite.SetSetup(@GlobalSetup);
  LSuite.SetTeardown(@GlobalTeardown);
  LSuite.OnBeforeEach(@BeforeEachTest);
  LSuite.OnAfterEach(@AfterEachTest);

  { Register tests }
  LSuite.Test('name', @TestProc);
  LSuite.Skip('name', 'reason');

  { Subtests }
  LSuite.TestSubtest('name', @SubtestProc);

  { Run }
  LSuite.Run;               { Serial }
  LSuite.RunParallel(nil);  { Parallel (direct threads) }

  { Results }
  LSuite.Summary;       { Print pass/fail/skip counts }
  LSuite.AllPassed;     { Returns True if all passed; auto-runs if not yet run }

  { Programmatic result access (Phase 2) }
  var LResult: TTestRunResult;
  LSuite.RunWithResult(LResult);  { Run + collect structured results }
  WriteLn(LResult.Passed, '/', LResult.Passed + LResult.Failed);
end;
```

#### TTestSuite is a Record (COW semantics)

`TTestSuite` is a Pascal **record**, not a class. This has important implications:

```pascal
{ WRONG — modifications after Add are lost (copy-on-write) }
LRunner.Add(LSuite);
LSuite.Test('late test', @LateTest);  { ← not reflected in runner }

{ CORRECT — register all tests before Add }
LSuite.Test('test 1', @Test1);
LSuite.Test('test 2', @Test2);
LRunner.Add(LSuite);  { runner gets a snapshot }
```

`TTestRunner.Add` takes `var ASuite: TTestSuite` and copies it. Any modifications
to the original `LSuite` variable after `Add` are NOT reflected in the runner.

#### AllPassed Lazy Execution

`TTestSuite.AllPassed` has lazy execution semantics:

- If `Run` or `RunParallel` has already been called, returns the cached result.
- If the suite has NOT been run yet, automatically calls `Run` (serial mode) first.

This means `AllPassed` is safe to call as the sole entry point, but be aware it
triggers a serial run if needed. For parallel results, call `RunParallel` explicitly
before checking `AllPassed`.

### TTestRunner (multi-suite)

```pascal
var
  LRunner: TTestRunner;
begin
  LRunner := TTestRunner.Create('All Tests');
  LRunner.Add(LSuite1);
  LRunner.Add(LSuite2);
  LRunner.RunAll;           { Serial: runs each suite sequentially }
  LRunner.RunAllParallel(nil);  { Parallel: each suite uses RunParallel }
  LRunner.Summary;          { Print aggregated pass/fail/skip }
end;
```

### Subtests

```pascal
{ Simple subtest — test body runs inline }
procedure TestDatabase(constref Ctx: ITestContext);
begin
  Ctx.Run('connect',
    procedure begin CheckTrue(DB.Connected); end);
  Ctx.Run('query',
    procedure begin CheckEqual('result', DB.Query('SELECT 1')); end);
end;

{ Nested subtest — child has its own subtests }
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

## Error Handling

### ETestSkipped — Flow Control Exception

`ETestSkipped = class(EAbort)` is used as **flow control**, not as a testable
exception. This is a deliberate design choice:

- `Skip('reason')` raises `ETestSkipped` to abort the current test.
- `CheckRaises` and `CheckNoRaise` **re-raise** `ETestSkipped` — they never
  catch it. This means `Skip()` inside a `CheckRaises`/`CheckNoRaise` proc
  correctly skips the test rather than being treated as a caught exception.
- `ETestSkipped` inherits from `EAbort` (which doesn't display an error dialog
  in GUI contexts and is silently caught by FPC's default exception handler).

### Assertion Failures

`EAssertionFailed` (defined in the framework) is raised by:
- All `Check*` procedures when the assertion fails
- All `IExpectation.To*` methods when the assertion fails
- `Fail(msg)` unconditionally

In serial mode, `InternalFail` also sets the global `GTestFailed := True` flag
(which can be read by `{$IFDEF HASHEAPTRACE}` integration).

### Parallel Mode Global State

When `RunParallel` is active, the framework sets `GParallelMode := True`.
In parallel mode, `InternalFail` and `InternalSkip` skip writing to global
variables (`GTestFailed`, `GTestSkipped`, `GSkipReason`) to avoid data races.
Each thread tracks its own failure status locally via `TTestStatus`.

## Parallel Execution

`RunParallel` spawns one OS thread per test via `platform_thread_create`.
Results are collected thread-safely using a mutex.

**Note**: FPC's `heaptrc` (`-gh`) is not thread-safe. Omit `-gh` when running
parallel tests, or run serial tests with `-gh` and parallel tests without.

### APool Parameter

`RunParallel(APool: IThreadPool)` — the `APool` parameter is **reserved for
future use**. Currently pass `nil`. The parallel mode uses direct
`platform_thread_create` for each test, not a thread pool. This design choice
was made because FPC closures capture variables by reference, making it unsafe
to reuse threads across test boundaries.

### Thread Safety Requirements

When using `RunParallel`:

- **BeforeEach / AfterEach** must be thread-safe — they are called concurrently
  from multiple threads. Avoid shared mutable state or protect with a mutex.
- **Setup / Teardown** run serially (before/after all parallel tests) and are
  safe to use shared state. If Setup fails, all tests are skipped and the suite
  reports `LastFail = 1`, `HasRun = True`.
- **Check\* assertions** work correctly in parallel tests — each thread catches
  its own exceptions locally.
- **Subtests** (`ITestContext.Run` / `RunNested`) are a serial-only feature.
  Do not use `TestSubtest` entries with `RunParallel`.
- **Global test context** (`GActiveTestName` etc.) is intentionally NOT set in
  parallel mode to avoid data races. Test names are passed via `TThreadRec`.

## Memory Leak Detection

When compiled with `-gh` (heaptrc), the framework reports leaked memory blocks
after each test in serial mode.

### Limitations

- **Serial mode only**: Leak detection uses `GetFPCHeapStatus.CurrHeapUsed`
  after each test. This is not thread-safe and is disabled in parallel mode.
- **Absolute value check**: Reports leaks when `CurrHeapUsed > 0` after a
  passed test — not a before/after delta. This means any non-zero heap usage
  (including framework-internal allocations) triggers a warning. False positives
  are possible; treat the warning as a prompt to investigate with `-gh`.
- **Per-test granularity**: Leak detection is per-test, not per-assertion.
  A leak in a subtest is attributed to the parent test.
- **heaptrc itself**: FPC's `heaptrc` unit adds overhead and is not compatible
  with multi-threaded code. Use it for serial leak checks only.

## Build & Test

```bash
# Single test
make -C core/tests/nextpas.core.test/test_assertions clean test

# All nextpas.core.test tests
for t in test_assertions test_expect test_runner test_parallel test_subtests; do
  make -C core/tests/nextpas.core.test/$t clean test
done
```

## Architecture

```
nextpas.core.test.pas           ← Single-unit framework (~1870 lines)
  ├── TTestStatus               ← tsPassed/tsFailed/tsSkipped/tsError
  ├── TTestEntry                ← Name + Proc/SubtestProc + Kind
  ├── TTestSuite                ← Suite with lifecycle hooks (record)
  ├── TTestRunner               ← Multi-suite aggregator (record)
  ├── ITestContext              ← Subtest context interface (Run/RunNested/Fail)
  ├── IExpectation              ← Fluent assertion interface (15 To* methods)
  ├── TExpectation              ← Implementation class (TInterfacedObject)
  ├── Check* procedures         ← 17 assertion procedures (21 overloads)
  ├── Expect* functions         ← 5 factory functions
  ├── ETestSkipped              ← class(EAbort) — flow control exception
  ├── EAssertionFailed          ← Assertion failure exception
  └── ParallelWorkerProc        ← Unit-level thread entry (direct thread create)
```

## Test Coverage

| Test Suite | Tests | Coverage |
|-----------|-------|----------|
| test_assertions | 22 | All Check* procedures + Skip/Fail + empty pattern edge cases |
| test_expect | 45 | IExpectation (15 To* × 4 dimensions: success/fail/Not\_/Not\_fail) |
| test_runner | 8 suite + 7 verify | Lifecycle hooks, failure paths, RunAll, AllPassed cache, Summary |
| test_subtests | 8 suite + 2 verify | Nested subtests, RunNested API, 3-level failure propagation |
| test_parallel | 8 + 3 verify | Parallel execution, failure/skip in threads, RunAllParallel |
| **Total** | **~105** | **100% public API path coverage** |
