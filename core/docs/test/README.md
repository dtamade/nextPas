# nextpas.core.test — Advanced Pascal Unit Testing Framework

## Overview

`nextpas.core.test` is a modern, production-grade unit testing framework for Free Pascal, designed to be the most advanced Pascal testing framework available.

### Features

- **Dual API**: Procedural `Check*` assertions + fluent `IExpectation` chain interface
- **Parallel execution**: Direct thread-based parallel test dispatch (bypasses FPC closure capture limitations)
- **Subtests**: Go-style nested subtests via `ITestContext.Run`
- **ANSI colored output**: Auto-detected terminal color support
- **Memory leak detection**: Built-in heap trace integration (`-gh` flag)
- **Full lifecycle**: Setup/Teardown, BeforeEach/AfterEach hooks
- **Multi-suite runner**: `TTestRunner` aggregates multiple suites
- **Zero external dependencies**: Only uses `nextpas.core.*` modules

## Quick Start

```pascal
program my_tests;
{$mode objfpc}{$H+}
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
| `CheckContains(haystack, needle)` | Assert string contains |
| `CheckStartsWith(str, prefix)` | Assert string starts with |
| `CheckEndsWith(str, suffix)` | Assert string ends with |
| `CheckSame(expected, actual)` | Assert same pointer |
| `CheckInRange(value, low, high)` | Assert integer in range |
| `CheckLength(value, expected)` | Assert length |
| `CheckRaises(class, proc, msg)` | Assert exception raised |
| `CheckNoRaise(proc, msg)` | Assert no exception |
| `Fail(msg)` | Unconditional failure |
| `Skip(reason)` | Skip current test |

### Fluent API (IExpectation)

```pascal
Expect('hello').ToEqual('hello');
Expect('hello').Not_.ToEqual('world');
ExpectInt(42).ToBeGreaterThan(10).ToBeInRange(0, 100);
ExpectBool(True).ToBeTrue;
ExpectPtr(nil).ToBeNil;
ExpectProc(@Boom).ToRaise(EConvertError);
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
| `Not_` | All (negates next assertion) |
| `ToEqual` | string |
| `ToEqualInt` | Int64 |
| `ToEqualBool` | Boolean |
| `ToBeTrue/ToBeFalse` | Boolean |
| `ToBeNil/ToBeNotNil` | Pointer |
| `ToContain` | string |
| `ToStartWith/ToEndWith` | string |
| `ToBeGreaterThan/ToBeLessThan` | Int64 |
| `ToBeInRange(low, high)` | Int64 |
| `ToHaveLength` | string |
| `ToRaise(class, msg)` | proc |

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
  LSuite.Run;          { Serial }
  LSuite.RunParallel(nil);  { Parallel (direct threads) }
end;
```

### TTestRunner (multi-suite)

```pascal
var
  LRunner: TTestRunner;
begin
  LRunner := TTestRunner.Create('All Tests');
  LRunner.Add(LSuite1);
  LRunner.Add(LSuite2);
  LRunner.RunAll;
end;
```

### Subtests

```pascal
procedure TestDatabase(constref Ctx: ITestContext);
begin
  Ctx.Run('connect',
    procedure begin CheckTrue(DB.Connected); end);
  Ctx.Run('query',
    procedure begin CheckEqual('result', DB.Query('SELECT 1')); end);
end;
```

## Parallel Execution

`RunParallel` spawns one OS thread per test via `platform_thread_create`.
Results are collected thread-safely using a mutex.

**Note**: FPC's `heaptrc` (`-gh`) is not thread-safe. Omit `-gh` when running
parallel tests, or run serial tests with `-gh` and parallel tests without.

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
nextpas.core.test.pas           ← Single-unit framework
  ├── TTestStatus               ← tsPassed/tsFailed/tsSkipped/tsError
  ├── TTestEntry                ← Name + Proc + Kind
  ├── TTestSuite                ← Suite with lifecycle hooks
  ├── TTestRunner               ← Multi-suite aggregator
  ├── ITestContext              ← Subtest context interface
  ├── IExpectation              ← Fluent assertion interface
  ├── TExpectation              ← Implementation class
  ├── Check* procedures         ← 18 assertion procedures
  ├── Expect* functions         ← 5 factory functions
  └── ParallelWorkerProc        ← Unit-level thread entry
```

## Test Coverage

| Test Suite | Tests | Coverage |
|-----------|-------|----------|
| test_assertions | 19 | All Check* procedures |
| test_expect | 18 | IExpectation + Not_ + failure paths |
| test_runner | 4+2 skip | TTestRunner + lifecycle + subtests |
| test_parallel | 8 | Parallel thread execution |
| test_subtests | 6 (12 sub) | Nested subtests + ITestContext |
